-- Missões diárias: troca as missões quando o dia vira e conta o progresso
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MissoesDados = require(Shared.Dados.Missoes)
local Presentes = require(Shared.Dados.Presentes)
local Economia = require(Shared.Dados.Economia)
local Dados = require(script.Parent.Dados)
local Acoes = require(script.Parent.Acoes)

local Missoes = {}

-- Garante que a lista é a do dia de hoje (chamado antes de ler ou mudar missões)
function Missoes.garantirDia(estado: Economia.Estado)
	local hoje = Presentes.diaAtual(os.time())
	if estado.missoes.dia == hoje then
		return
	end
	local lista = {}
	for _, id in MissoesDados.doDia(hoje) do
		table.insert(lista, { id = id, progresso = 0, resgatada = false })
	end
	estado.missoes = { dia = hoje, lista = lista }
end

-- Chamado pelos outros serviços quando algo acontece (ex.: "ligar_escudo")
function Missoes.progredir(player: Player, tipo: string, quantidade: number?)
	Dados.alterar(player, function(estado)
		Missoes.garantirDia(estado)
		local mudou = false
		for _, m in estado.missoes.lista do
			local def = MissoesDados.missao(m.id)
			if def and def.tipo == tipo and m.progresso < def.meta then
				m.progresso = math.min(def.meta, m.progresso + (quantidade or 1))
				mudou = true
			end
		end
		return mudou
	end)
end

function Missoes.iniciar()
	Dados.quandoCarregar(function(player: Player)
		Dados.alterar(player, function(estado)
			Missoes.garantirDia(estado)
			return true
		end)
	end)

	Acoes.registrar("ResgatarMissao", function(player, id: any)
		if type(id) ~= "string" then
			return false, "Missão inválida"
		end
		return Dados.alterar(player, function(estado)
			Missoes.garantirDia(estado)
			for _, m in estado.missoes.lista do
				if m.id == id then
					local def = MissoesDados.missao(id)
					if not def then
						return false, "Missão inválida"
					end
					if m.resgatada then
						return false, "Prêmio já resgatado"
					end
					if m.progresso < def.meta then
						return false, "Missão ainda não terminou"
					end
					m.resgatada = true
					estado.granulados += def.granulados
					return true, string.format("+%d granulados!", def.granulados)
				end
			end
			return false, "Essa missão não é de hoje"
		end)
	end)
end

return Missoes
