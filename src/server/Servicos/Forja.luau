local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Receitas = require(Shared.Dados.Receitas)
local Transcendencia = require(Shared.Dados.Transcendencia)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)
local Incursoes = require(script.Parent.Parent.Incursoes.Servico)

local Forja = {}
local ultimoPedido: { [Player]: number } = {}

local function validar(player: Player): (boolean, string?)
	if Incursoes.ocupado(player) then
		return false, "Saia da fila ou termine sua incursão antes de usar o Altar."
	end
	local nexo = workspace:FindFirstChild("Nexo")
	local altar = if nexo then nexo:FindFirstChild("AltarMesa", true) else nil
	local personagem = player.Character
	local raiz = if personagem then personagem:FindFirstChild("HumanoidRootPart") else nil
	local vida = if personagem then personagem:FindFirstChildOfClass("Humanoid") else nil
	if
		not (
			altar
			and altar:IsA("BasePart")
			and raiz
			and raiz:IsA("BasePart")
			and vida
			and vida.Health > 0
		) or not ((altar.Position - raiz.Position).Magnitude <= 16)
	then
		return false, "Aproxime-se do Altar da Ressonância."
	end
	local agora = os.clock()
	local ultimo = ultimoPedido[player]
	if ultimo and agora - ultimo < 0.55 then
		return false, "Aguarde antes de confirmar outra operação."
	end
	ultimoPedido[player] = agora
	return true, nil
end

local function fabricar(player: Player, receitaId: any): (boolean, string?)
	if type(receitaId) ~= "string" or #receitaId > 64 or not Receitas.porId[receitaId] then
		return false, "Receita desconhecida."
	end
	local ok, msg = validar(player)
	if not ok then
		return false, msg
	end
	return Dados.alterarConfirmado(player, function(estado)
		return Receitas.fabricar(estado.inventario.itens, receitaId)
	end)
end

local function transcender(player: Player): (boolean, string?, { [string]: any }?)
	local ok, msg = validar(player)
	if not ok then
		return false, msg
	end
	local nivel = 0
	ok, msg = Dados.alterarConfirmado(player, function(estado)
		local mudou, motivo =
			Transcendencia.oferecer(estado.inventario.itens, estado.transcendencia)
		nivel = estado.transcendencia.nivel
		return mudou, motivo
	end)
	if not ok then
		return false, msg
	end
	return true, nil, { nivel = nivel }
end

function Forja.iniciar()
	Acoes.registrar("FabricarItem", fabricar)
	Acoes.registrar("Transcender", transcender)
	Players.PlayerRemoving:Connect(function(player)
		ultimoPedido[player] = nil
	end)
end

return Forja
