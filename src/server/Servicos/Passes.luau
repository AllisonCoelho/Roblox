-- Game Passes do Despertar (catálogo em Shared/Dados/Monetizacao). O servidor é quem diz se o
-- jogador tem o passe: consulta o Roblox (UserOwnsGamePassAsync), guarda em cache e liga o
-- atributo "Passe_<id>" no jogador para o cliente mostrar a interface certa.
--
-- Sem gamePassId no catálogo (passe ainda não criado no Creator Hub), ninguém tem o passe —
-- exceto os devs autorizados na experiência de teste e no Studio (PermissaoDev), para testar.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Monetizacao = require(Shared.Dados.Monetizacao)
local PermissaoDev = require(script.Parent.PermissaoDev)

local Passes = {}

local studioTeste = RunService:IsStudio() and Config.ModoTeste
local dono: number? = if game.CreatorType == Enum.CreatorType.User then game.CreatorId else nil
local cache: { [Player]: { [string]: boolean } } = {}
local ouvintes: { (Player) -> () } = {}

local function dev(player: Player): boolean
	return PermissaoDev.autoriza(
		game.GameId,
		game.PlaceId,
		studioTeste,
		dono,
		player.UserId,
		PermissaoDev.contaDeTeste(player.Name, player.UserId)
	)
end

local function definir(player: Player, id: string, tem: boolean)
	cache[player] = cache[player] or {}
	cache[player][id] = tem
	if player.Parent == Players then
		player:SetAttribute(Monetizacao.atributo(id), tem)
	end
end

local function avisar(player: Player)
	for _, fn in ouvintes do
		task.spawn(fn, player)
	end
end

-- Consulta todos os passes ativos do jogador (assíncrono)
function Passes.atualizar(player: Player)
	for _, produto in Monetizacao.ativos() do
		if produto.tipo == "passe" then
			local tem = dev(player)
			if not tem and produto.gamePassId then
				local ok, possui = pcall(
					MarketplaceService.UserOwnsGamePassAsync,
					MarketplaceService,
					player.UserId,
					produto.gamePassId
				)
				tem = ok and possui == true
			end
			definir(player, produto.id, tem)
		elseif produto.tipo == "assinatura" then
			-- Assinatura do Nexo: status mensal consultado no Roblox
			local tem = dev(player)
			if not tem and produto.subscriptionId then
				local ok, status = pcall(
					MarketplaceService.GetUserSubscriptionStatusAsync,
					MarketplaceService,
					player,
					produto.subscriptionId
				)
				tem = ok and type(status) == "table" and status.IsSubscribed == true
			end
			definir(player, produto.id, tem)
		end
	end
	avisar(player)
end

function Passes.tem(player: Player, id: string): boolean
	local c = cache[player]
	return c ~= nil and c[id] == true
end

-- Já consultamos o Roblox para este jogador?
function Passes.verificado(player: Player): boolean
	return cache[player] ~= nil
end

-- Chamado depois de cada verificação ou compra (ex.: o Sorteio corrige configurações pagas)
function Passes.aoMudar(fn: (Player) -> ())
	table.insert(ouvintes, fn)
end

function Passes.iniciar()
	Players.PlayerAdded:Connect(function(player)
		Passes.atualizar(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(Passes.atualizar, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
	-- Assinou ou cancelou: consulta de novo
	Players.UserSubscriptionStatusChanged:Connect(function(player)
		Passes.atualizar(player)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, comprou)
		if not comprou then
			return
		end
		for _, produto in Monetizacao.ativos() do
			if produto.gamePassId == gamePassId then
				definir(player, produto.id, true)
				avisar(player)
			end
		end
	end)
end

return Passes
