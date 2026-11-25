-- Pontos de Aura: a aura equipada gera pontos por segundo enquanto o jogador está no jogo. Os
-- pontos compram três evoluções (Nível, Fluxo e Sorte). A Pontuação de Aura resume a força do
-- jogador (Arena, ranking, portões do Corredor). Só números e regras puras: o servidor decide
-- tudo com este módulo, o cliente só mostra. Testado em testes/logica.luau.
--
-- Decisões do dono (nov/2026): sorte pode mexer no giro, com as auras mais raras quase
-- impossíveis no começo e mais fáceis com a evolução, mas nunca fáceis (teto total de sorte).
local Auras = require(script.Parent.Auras)
local Probabilidades = require(script.Parent.Probabilidades)
local Transcendencia = require(script.Parent.Transcendencia)

local PontosAura = {}

export type Progresso = {
	pontos: number, -- saldo para gastar
	total: number, -- tudo o que já gerou (ranking e conquistas)
	nivel: number,
	fluxo: number,
	sorte: number,
}

export type Evolucao = {
	id: string,
	nome: string,
	descricao: string,
	custoBase: number,
	crescimento: number, -- custo do nível n = custoBase * crescimento ^ n
	maximo: number,
}

-- Sem aura equipada a pessoa ainda gera um pouco (o primeiro giro é grátis de qualquer jeito)
PontosAura.SEM_AURA = 0.5
-- Teto total da sorte (evolução x Transcendência x pets). Ver Probabilidades.MAX_SORTE.
PontosAura.SORTE_MAXIMA = Probabilidades.MAX_SORTE
PontosAura.SORTE_POR_NIVEL = 0.2 -- +0,2x por nível da evolução Sorte
PontosAura.FLUXO_POR_NIVEL = 0.1 -- +10% de pontos por segundo por nível de Fluxo
PontosAura.NIVEL_POR_NIVEL = 0.25 -- +25% de Pontuação por nível

PontosAura.EVOLUCOES = {
	{
		id = "nivel",
		nome = "Nível de Aura",
		descricao = "+25% de Pontuação de Aura",
		custoBase = 25,
		crescimento = 1.12,
		maximo = 500,
	},
	{
		id = "fluxo",
		nome = "Fluxo",
		descricao = "+10% de Pontos de Aura por segundo",
		custoBase = 60,
		crescimento = 1.17,
		maximo = 120,
	},
	{
		id = "sorte",
		nome = "Sorte",
		descricao = "+0,2x de sorte no giro",
		custoBase = 200,
		crescimento = 1.16,
		maximo = 95,
	},
} :: { Evolucao }

PontosAura.porId = {} :: { [string]: Evolucao }
for _, e in PontosAura.EVOLUCOES do
	PontosAura.porId[e.id] = e
end

local function numero(v: any): number
	return if type(v) == "number" and v == v and v >= 0 and v < math.huge then v else 0
end

local function inteiro(v: any, maximo: number): number
	return math.clamp(math.floor(numero(v)), 0, maximo)
end

function PontosAura.padrao(): Progresso
	return { pontos = 0, total = 0, nivel = 0, fluxo = 0, sorte = 0 }
end

-- Corrige dados salvos estranhos (negativos, NaN, acima do máximo)
function PontosAura.normalizar(p: any): Progresso
	local t = if type(p) == "table" then p else {}
	return {
		pontos = numero(t.pontos),
		total = numero(t.total),
		nivel = inteiro(t.nivel, PontosAura.porId.nivel.maximo),
		fluxo = inteiro(t.fluxo, PontosAura.porId.fluxo.maximo),
		sorte = inteiro(t.sorte, PontosAura.porId.sorte.maximo),
	}
end

-- Força da aura: cresce com a raridade, suavizada (raiz quarta da chance "1 em N").
-- 1 em 2 → ~1,2/s; 1 em 1.000 → ~5,6/s; 1 em 1 milhão → ~32/s; 1 em 100 milhões → 100/s.
function PontosAura.forcaDaAura(auraId: string?): number
	local aura = if auraId then Auras.porId[auraId] else nil
	if not aura then
		return PontosAura.SEM_AURA
	end
	return math.max(1, aura.chance) ^ 0.25
end

-- Pontos por segundo. `extra` = multiplicadores de fora (pets, passes, bônus de combate).
function PontosAura.ganhoPorSegundo(p: Progresso, auraId: string?, extra: number?): number
	local m = numero(extra)
	return PontosAura.forcaDaAura(auraId)
		* (1 + PontosAura.FLUXO_POR_NIVEL * p.fluxo)
		* (if m > 0 then m else 1)
end

-- Pontuação de Aura: força da aura equipada x nível (x bônus de pets, quando existirem)
function PontosAura.pontuacao(p: Progresso, auraId: string?, extra: number?): number
	local m = numero(extra)
	return math.floor(
		10
			* PontosAura.forcaDaAura(auraId)
			* (1 + PontosAura.NIVEL_POR_NIVEL * p.nivel)
			* (if m > 0 then m else 1)
	)
end

function PontosAura.custo(id: string, nivelAtual: number): number?
	local e = PontosAura.porId[id]
	if not e or nivelAtual >= e.maximo then
		return nil
	end
	return math.floor(e.custoBase * e.crescimento ^ nivelAtual)
end

-- Compra um nível de `id`. Devolve (ok, mensagem). Muda `p` só quando dá certo.
function PontosAura.evoluir(p: Progresso, id: any): (boolean, string?)
	if type(id) ~= "string" or not PontosAura.porId[id] then
		return false, "Evolução desconhecida."
	end
	local niveis = p :: any
	local atual = niveis[id] :: number
	local custo = PontosAura.custo(id, atual)
	if not custo then
		return false, "Esta evolução já está no máximo."
	end
	if p.pontos < custo then
		return false, "Pontos de Aura insuficientes."
	end
	p.pontos -= custo
	niveis[id] = atual + 1
	return true, nil
end

-- Sorte só da evolução (1x no começo)
function PontosAura.sorteEvolucao(p: Progresso): number
	return 1 + PontosAura.SORTE_POR_NIVEL * p.sorte
end

-- Sorte total do giro: evolução x Transcendência x extra (pets), limitada ao teto
function PontosAura.sorteTotal(estado: any, extra: number?): number
	local p = PontosAura.normalizar(if type(estado) == "table" then estado.poder else nil)
	local nivelT = if type(estado) == "table" and type(estado.transcendencia) == "table"
		then estado.transcendencia.nivel
		else 0
	local m = numero(extra)
	local s = PontosAura.sorteEvolucao(p) * Transcendencia.sorte(nivelT) * (if m > 0 then m else 1)
	return math.clamp(s, 1, PontosAura.SORTE_MAXIMA)
end

return PontosAura
