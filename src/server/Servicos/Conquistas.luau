-- Dá as conquistas (Shared/Dados/Conquistas.luau) e os emblemas do Roblox ligados a elas.
-- A conquista fica salva em estado.conquistas; o emblema é conferido a cada entrada, então
-- quem conquistou antes de o emblema existir recebe assim que o badgeId for configurado.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ConquistasDados = require(Shared.Dados.Conquistas)
local Remotos = require(Shared.Remotos)
local Dados = require(script.Parent.Dados)

local Conquistas = {}

-- Entrega no Roblox os emblemas que o jogador ainda não tem (uma consulta para todos)
local function darEmblemas(player: Player, ids: { string })
	local emblemas = {}
	for _, id in ids do
		local c = ConquistasDados.conquista(id)
		if c and c.badgeId ~= 0 then
			table.insert(emblemas, c.badgeId)
		end
	end
	if #emblemas == 0 then
		return
	end
	task.spawn(function()
		local possui: { [number]: boolean } = {}
		local ok, lista =
			pcall(BadgeService.CheckUserBadgesAsync, BadgeService, player.UserId, emblemas)
		if ok and type(lista) == "table" then
			for _, b in lista do
				possui[b] = true
			end
		end
		for _, b in emblemas do
			if not possui[b] and player.Parent then
				local okDar, erro = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, b)
				if not okDar then
					warn("[Conquistas] emblema " .. b .. ": " .. tostring(erro))
				end
			end
		end
	end)
end

function Conquistas.dar(player: Player, id: string)
	local c = ConquistasDados.conquista(id)
	if not c then
		return
	end
	local nova = false
	Dados.alterar(player, function(estado)
		if estado.conquistas[id] then
			return false
		end
		estado.conquistas[id] = true
		nova = true
		return true
	end)
	if not nova then
		return
	end
	if not c.silenciosa then
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "sucesso",
			texto = c.icone .. " Conquista: " .. c.nome .. "!",
		})
	end
	darEmblemas(player, { id })
end

function Conquistas.iniciar()
	Dados.quandoCarregar(function(player, estado)
		local ganhas = {}
		for id, sim in estado.conquistas do
			if sim then
				table.insert(ganhas, id)
			end
		end
		darEmblemas(player, ganhas)
	end)
	-- A cada mudança confere as conquistas que o estado comprova
	Dados.quandoMudar(function(player, estado)
		for _, id in ConquistasDados.doEstado(estado) do
			if not estado.conquistas[id] then
				Conquistas.dar(player, id)
			end
		end
	end)
end

return Conquistas
