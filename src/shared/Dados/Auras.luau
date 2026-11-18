-- Catálogo de auras do Despertar e lógica pura do sorteio (testada em testes/logica.luau).
-- Este módulo não usa APIs do Roblox (cores ficam em hex) para rodar também no luau puro.
--
-- Sorte 1.00 preserva 1/chance; sorte superior usa pesos por raridade normalizados.
-- A primeira aura e reserva: recebe a probabilidade que sobra das demais.
local Catalogo = require(script.Parent.AurasOriginaisV2)
local Probabilidades = require(script.Parent.Probabilidades)
local Auras = {}

export type Aura = {
	id: string,
	nome: string,
	chance: number, -- chance BASE 1 em N (rank e ressonancia)
	pBase: number,
	tierNome: string,
	reserva: boolean,
	cores: { string }, -- { principal, secundária } em hex
	estilo: string, -- "brilho" | "chama" | "nevoa"
	tier: number, -- índice em Auras.Tiers
	ordem: number, -- posição no catálogo (1 = mais comum)
}

export type Tier = { nome: string, minimo: number, cor: string }

-- Faixas de raridade pela chance mínima ("1 em minimo")
Auras.Tiers = {
	{ nome = "Comum", minimo = 1, cor = "B8C1CC" },
	{ nome = "Incomum", minimo = 10, cor = "5BE37D" },
	{ nome = "Raro", minimo = 100, cor = "4CC9F0" },
	{ nome = "Épico", minimo = 1000, cor = "A855F7" },
	{ nome = "Lendário", minimo = 10000, cor = "FFC83D" },
	{ nome = "Mítico", minimo = 100000, cor = "FF3B6B" },
	{ nome = "Divino", minimo = 1000000, cor = "FFFFFF" },
} :: { Tier }

-- Auras raras a partir desta chance geram anúncio para o servidor inteiro
Auras.ANUNCIO_MINIMO = 1000

-- Estilo dos ícones, da arena e dos efeitos genéricos. As malhas usam o motor das originais.
local ESTILO_POR_FAMILIA: { [string]: string } = {
	Forja = "chama",
	["Fênix"] = "chama",
	["Espírito"] = "nevoa",
	Abismo = "nevoa",
	Fenda = "nevoa",
	Oceano = "nevoa",
}

function Auras.tierDe(chance: number): number
	local resultado = 1
	for i, t in Auras.Tiers do
		if chance >= t.minimo then
			resultado = i
		end
	end
	return resultado
end

Auras.lista = {} :: { Aura }
Auras.porId = {} :: { [string]: Aura }

Auras.PROBABILIDADE_RESERVA = Catalogo.PROBABILIDADE_RESERVA

for i, d in Catalogo.lista do
	local tier = Auras.tierDe(d.chance)
	assert(Auras.Tiers[tier].nome == d.tier, "raridade inválida para " .. d.id)
	local aura: Aura = {
		id = d.id,
		nome = d.nome,
		chance = d.chance,
		pBase = if d.id == Catalogo.RESERVA then Catalogo.PROBABILIDADE_RESERVA else 1 / d.chance,
		tierNome = d.tier,
		reserva = d.id == Catalogo.RESERVA,
		cores = d.cores,
		estilo = ESTILO_POR_FAMILIA[d.familia] or "brilho",
		tier = tier,
		ordem = i,
	}
	table.insert(Auras.lista, aura)
	Auras.porId[aura.id] = aura
end

-- Tabelas dos 11 niveis de Transcendencia em cache, montadas uma vez.
-- Fontes futuras de sorte podem usar ate 3.00 sem provocar overflow de probabilidades.
Probabilidades.validarCatalogo(Auras.lista)
local precalculadas: { [number]: { pesos: { number }, total: number } } = {}
for nivel = 0, Probabilidades.MAX_NIVEL do
	local sorte = Probabilidades.sorteTranscendencia(nivel)
	local pesos, total = Probabilidades.distribuicao(Auras.lista, sorte)
	precalculadas[nivel] = { pesos = pesos, total = total }
end

local function pesosPara(sorte: number?): ({ number }, number)
	local s = Probabilidades.sorteValida(sorte)
	local nivel = math.floor((s - 1) / 0.05 + 0.5)
	local pronta = precalculadas[nivel]
	if pronta and math.abs(s - Probabilidades.sorteTranscendencia(nivel)) < 1e-9 then
		return pronta.pesos, pronta.total
	end
	return Probabilidades.distribuicao(Auras.lista, s)
end

function Auras.sorteTranscendencia(nivel: any): number
	return Probabilidades.sorteTranscendencia(nivel)
end

-- Sorte por peso normalizado: 1.00 preserva as chances-base; sorte alta nao satura.
function Auras.sortear(aleatorio: () -> number, sorte: number?): Aura
	local pesos, total = pesosPara(sorte)
	return Probabilidades.sortearPesos(Auras.lista, pesos, total, aleatorio) :: Aura
end

-- A chance BASE e a efetiva usam a mesma distribuicao que o servidor sorteia.
function Auras.probabilidadeReal(id: string, sorte: number?): number
	local aura = Auras.porId[id]
	if not aura then
		return 0
	end
	local pesos, total = pesosPara(sorte)
	return pesos[aura.ordem] / total
end

-- A aura mais rara de uma coleção { [id] = quantidade }
function Auras.melhorDe(colecao: { [string]: number }): Aura?
	local melhor: Aura? = nil
	for id, qtd in colecao do
		local aura = Auras.porId[id]
		if aura and qtd > 0 and (melhor == nil or aura.chance > melhor.chance) then
			melhor = aura
		end
	end
	return melhor
end

-- Quantas auras diferentes do catálogo a coleção tem
function Auras.contarDescobertas(colecao: { [string]: number }): number
	local n = 0
	for id, qtd in colecao do
		if Auras.porId[id] and qtd > 0 then
			n += 1
		end
	end
	return n
end

-- Compatibilidade com as telas de Forja: retorna o denominador efetivo 1 em N.
-- Os sorteios continuam usando apenas a distribuicao normalizada por tier.
function Auras.chanceEfetiva(aura: Aura, sorte: number?): number
	return 1 / Auras.probabilidadeReal(aura.id, sorte)
end

return Auras
