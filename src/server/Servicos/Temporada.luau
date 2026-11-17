-- Passe de Temporada no servidor (regras em Shared/Dados/Temporada). O XP entra junto com a
-- mudança que o gerou (giro, andar, vitória), na mesma chamada de Dados.alterar.
-- O resgate confere nível, trilha e o passe "passeTemporada" aqui, nunca no cliente.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmeticos = require(Shared.Dados.Cosmeticos)
local Temporada = require(Shared.Dados.Temporada)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)
local Passes = require(script.Parent.Passes)

local Servico = {}

local function dia(): number
	return os.time() // 86400
end

-- Chamar DENTRO de um Dados.alterar. Devolve o XP que entrou de fato.
function Servico.creditar(player: Player, estado: any, fonte: string): number
	if not Temporada.ativa(os.time()) then
		return 0
	end
	estado.temporada = Temporada.de(estado.temporada)
	return Temporada.ganhar(estado.temporada, fonte, dia(), Passes.tem(player, "vip"))
end

local function resgatar(player: Player, nivel: any, trilha: any): (boolean, string?)
	if
		type(nivel) ~= "number"
		or nivel ~= math.floor(nivel)
		or nivel < 1
		or nivel > Temporada.NIVEIS
		or (trilha ~= "gratis" and trilha ~= "premium")
	then
		return false, "Pedido inválido"
	end
	local premium = Passes.tem(player, "passeTemporada")
	local recebido: string? = nil
	local ok, msg = Dados.alterar(player, function(estado)
		estado.temporada = Temporada.de(estado.temporada)
		local id, motivo = Temporada.resgatavel(estado.temporada, nivel, trilha, premium)
		if not id then
			return false, motivo
		end
		estado.temporada.resgates[trilha][tostring(nivel)] = true
		estado.cosmeticos = estado.cosmeticos or Cosmeticos.padrao()
		Cosmeticos.conceder(estado.cosmeticos, { id })
		recebido = id
		return true
	end)
	if not ok then
		return false, msg
	end
	local item = Cosmeticos.porId[recebido :: string]
	return true, "Recompensa recebida: " .. item.nome
end

function Servico.iniciar()
	Acoes.registrar("ResgatarTemporada", resgatar)
end

return Servico
