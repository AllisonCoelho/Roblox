-- Ranking: placar do Roblox (leaderstats) e ranking global da maior renda por segundo.
-- O global usa um OrderedDataStore e é publicado para os clientes em
-- ReplicatedStorage.Ranking.Global (JSON) a cada poucos minutos.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local Dados = require(script.Parent.Dados)

local Ranking = {}

local NOME_STORE = "RankingRenda_v1"
local INTERVALO_GLOBAL = 120
local TOP = 10

local usarStore = not (RunService:IsStudio() and Config.ModoTeste)
local store = if usarStore then DataStoreService:GetOrderedDataStore(NOME_STORE) else nil
local enviado: { [Player]: number } = {} -- último valor mandado ao ranking global
local nomes: { [number]: string } = {}

-- Sem boosts temporários: um boost de 15 min não pode virar recorde para sempre
local function rendaInteira(estado: Economia.Estado): number
	return math.floor(Economia.rendaPermanente(estado))
end

local function descobertos(estado: Economia.Estado): number
	local n = 0
	for _, d in Catalogo.Lista do
		if estado.album[d.id] then
			n += 1
		end
	end
	return n
end

local function criarPlacar(player: Player)
	local pasta = Instance.new("Folder")
	pasta.Name = "leaderstats"
	local renda = Instance.new("IntValue")
	renda.Name = "Renda/s"
	renda.Parent = pasta
	local album = Instance.new("IntValue")
	album.Name = "Álbum"
	album.Parent = pasta
	local renasc = Instance.new("IntValue")
	renasc.Name = "Renasc."
	renasc.Parent = pasta
	pasta.Parent = player
end

local function atualizarPlacar(player: Player, estado: Economia.Estado)
	local pasta = player:FindFirstChild("leaderstats")
	if not pasta then
		return
	end
	local renda = pasta:FindFirstChild("Renda/s") :: IntValue?
	local album = pasta:FindFirstChild("Álbum") :: IntValue?
	local renasc = pasta:FindFirstChild("Renasc.") :: IntValue?
	if renda then
		renda.Value = rendaInteira(estado)
	end
	if album then
		album.Value = descobertos(estado)
	end
	if renasc then
		renasc.Value = estado.renascimentos or 0
	end
end

local function nomeDe(userId: number): string
	if nomes[userId] then
		return nomes[userId]
	end
	local jogador = Players:GetPlayerByUserId(userId)
	if jogador then
		nomes[userId] = jogador.DisplayName
		return jogador.DisplayName
	end
	local ok, nome = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nomes[userId] = if ok and type(nome) == "string" then nome else "Confeiteiro"
	return nomes[userId]
end

-- Manda a renda de quem está no servidor (só se melhorou: o ranking guarda o recorde)
local function enviarRecordes()
	if not store then
		return
	end
	for _, player in Players:GetPlayers() do
		local estado = Dados.de(player)
		if not estado then
			continue
		end
		local valor = rendaInteira(estado)
		if valor > 0 and valor > (enviado[player] or 0) then
			local ok = pcall(function()
				(store :: OrderedDataStore):UpdateAsync(tostring(player.UserId), function(antigo)
					return math.max(tonumber(antigo) or 0, valor)
				end)
			end)
			if ok then
				enviado[player] = valor
			end
		end
	end
end

local function publicarTop(pasta: Folder)
	local global = pasta:FindFirstChild("Global") :: StringValue
	if not store then
		global.Value = "[]"
		return
	end
	local ok, paginas = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, TOP)
	end)
	if not ok or not paginas then
		return
	end
	local lista = {}
	for _, entrada in (paginas :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entrada.key)
		if userId then
			table.insert(lista, { nome = nomeDe(userId), valor = entrada.value })
		end
	end
	global.Value = HttpService:JSONEncode(lista)
end

function Ranking.iniciar()
	local pasta = Instance.new("Folder")
	pasta.Name = "Ranking"
	local global = Instance.new("StringValue")
	global.Name = "Global"
	global.Value = "[]"
	global.Parent = pasta
	pasta.Parent = ReplicatedStorage

	Players.PlayerAdded:Connect(criarPlacar)
	for _, player in Players:GetPlayers() do
		criarPlacar(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		enviado[player] = nil
	end)
	Dados.quandoMudar(atualizarPlacar)

	-- Renda muda com boosts que acabam: atualiza o placar a cada 5 s
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local estado = Dados.de(player)
				if estado then
					atualizarPlacar(player, estado)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			enviarRecordes()
			publicarTop(pasta)
			task.wait(INTERVALO_GLOBAL)
		end
	end)
end

return Ranking
