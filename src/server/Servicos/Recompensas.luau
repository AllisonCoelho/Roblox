-- Presente diário e códigos
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Presentes = require(Shared.Dados.Presentes)
local LojaDados = require(Shared.Dados.Loja)
local Dados = require(script.Parent.Dados)
local Acoes = require(script.Parent.Acoes)
local Missoes = require(script.Parent.Missoes)
local Vitrine = require(script.Parent.Vitrine)

local Recompensas = {}

-- Códigos ficam só no servidor para ninguém descobrir lendo o jogo.
-- Para criar um código novo, adicione uma linha aqui (sempre em MAIÚSCULAS).
local CODIGOS: { [string]: { moedas: number?, granulados: number? } } = {
	DOCINHOS = { moedas = 1000 },
	BRIGADEIRO = { granulados = 25 },
	["1MILVISITAS"] = { granulados = 100 },
}

local function aplicarMoedasGranulados(estado, premio: { moedas: number?, granulados: number? })
	estado.moedas += premio.moedas or 0
	estado.granulados += premio.granulados or 0
end

function Recompensas.iniciar()
	Acoes.registrar("PegarPresente", function(player)
		local docinhoDoDia: string? = nil
		local ok, msg = Dados.alterar(player, function(estado)
			local hoje = Presentes.diaAtual(os.time())
			local p = estado.presente
			if p.ultimoDia == hoje then
				return false, "Volte amanhã para o próximo presente!"
			end
			p.sequencia = if p.ultimoDia == hoje - 1 then p.sequencia + 1 else 1
			p.ultimoDia = hoje
			local premio = Presentes.Dias[(p.sequencia - 1) % #Presentes.Dias + 1]
			aplicarMoedasGranulados(estado, premio)
			if premio.boost then
				local boost = LojaDados.boost(premio.boost)
				if boost then
					local agora = os.time()
					estado.boosts[boost.id] = math.max(estado.boosts[boost.id] or 0, agora)
						+ boost.duracao
				end
			end
			docinhoDoDia = premio.docinho
			return true, premio.texto .. "!"
		end)
		if ok then
			if docinhoDoDia and not Vitrine.adicionarDocinho(player, docinhoDoDia) then
				-- Vitrine cheia: troca o Docinho por granulados para não perder o prêmio
				Dados.alterar(player, function(estado)
					estado.granulados += 100
					return true
				end)
				msg = "Vitrine cheia! Você ganhou 100 granulados no lugar."
			end
			Missoes.progredir(player, "presente_diario", 1)
		end
		return ok, msg
	end)

	Acoes.registrar("ResgatarCodigo", function(player, texto: any)
		if type(texto) ~= "string" or #texto > 30 then
			return false, "Código inválido"
		end
		local codigo = string.upper((string.gsub(texto, "%s", "")))
		local premio = CODIGOS[codigo]
		if not premio then
			return false, "Esse código não existe"
		end
		local ok, msg = Dados.alterar(player, function(estado)
			if estado.codigos[codigo] then
				return false, "Você já usou esse código"
			end
			estado.codigos[codigo] = true
			aplicarMoedasGranulados(estado, premio)
			local partes = {}
			if premio.granulados then
				table.insert(partes, "+" .. premio.granulados .. " granulados")
			end
			if premio.moedas then
				table.insert(partes, "+" .. premio.moedas .. " moedas")
			end
			return true, table.concat(partes, " e ") .. "! Código resgatado."
		end)
		if ok then
			Missoes.progredir(player, "resgatar_codigo", 1)
		end
		return ok, msg
	end)
end

return Recompensas
