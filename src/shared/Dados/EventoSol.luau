-- Evento "Despertar do Sol" (tema Gear 5). Só regras puras (sem Roblox), testadas em
-- testes/logica.luau. O servidor decide tudo com este módulo.
--
-- De 30 em 30 minutos (pelo relógio do servidor: todos os servidores juntos) o Nexo vira o
-- palco do evento:
--   aviso  60 s  contagem regressiva, tambores e o céu começando a clarear
--   luta  240 s  o Titã de Borracha (chefe coletivo) aparece na praça; todos batem nele
--   fim    20 s  resultado e entrega dos baús
-- Quem ajudou ganha um Baú do Sol; os 3 que mais causaram dano (se o Titã cair) ganham um Baú do
-- Sol Dourado. Os baús só são ganhos no evento (não são vendidos). Dentro deles pode vir a aura
-- Gear 5 (exclusiva do evento), cosméticos e recursos, com garantia da Gear 5 no 60º baú.
local EventoSol = {}

EventoSol.PERIODO = 30 * 60
EventoSol.AVISO = 60
EventoSol.LUTA = 240
EventoSol.FIM = 20
EventoSol.GARANTIA = 60 -- a Gear 5 vem no máximo neste baú (contando os dois tipos)
EventoSol.GOLPES_DE_VIDA = 150 -- a vida do Titã: este número de golpes de quem está no servidor
EventoSol.VIDA_MINIMA = 3000
EventoSol.ALCANCE = 42 -- studs do Titã até onde a aura alcança
EventoSol.ESPERA_GOLPE = 0.8
EventoSol.TOP_DOURADO = 3

export type Fase = "espera" | "aviso" | "luta" | "fim"
export type Estado = { fase: Fase, inicio: number, restante: number, ciclo: number }

-- Fase do evento no instante `t` (segundos do relógio do servidor)
function EventoSol.estado(t: number): Estado
	local ciclo = math.floor(t / EventoSol.PERIODO)
	local dentro = t - ciclo * EventoSol.PERIODO
	local fimEspera = EventoSol.PERIODO - EventoSol.AVISO
	if dentro < EventoSol.LUTA then
		return {
			fase = "luta",
			inicio = ciclo * EventoSol.PERIODO,
			restante = EventoSol.LUTA - dentro,
			ciclo = ciclo,
		}
	elseif dentro < EventoSol.LUTA + EventoSol.FIM then
		return {
			fase = "fim",
			inicio = ciclo * EventoSol.PERIODO + EventoSol.LUTA,
			restante = EventoSol.LUTA + EventoSol.FIM - dentro,
			ciclo = ciclo,
		}
	elseif dentro < fimEspera then
		return {
			fase = "espera",
			inicio = ciclo * EventoSol.PERIODO + EventoSol.LUTA + EventoSol.FIM,
			restante = fimEspera - dentro,
			ciclo = ciclo,
		}
	end
	return {
		fase = "aviso",
		inicio = ciclo * EventoSol.PERIODO + fimEspera,
		restante = EventoSol.PERIODO - dentro,
		ciclo = ciclo + 1, -- o aviso já é do próximo evento
	}
end

-- Vida do Titã: dá ~2 minutos de luta para quem estiver no servidor, forte ou fraco
function EventoSol.vida(danosPorGolpe: { number }): number
	local soma = 0
	for _, d in danosPorGolpe do
		soma += math.max(d, 0)
	end
	return math.max(EventoSol.VIDA_MINIMA, math.floor(soma * EventoSol.GOLPES_DE_VIDA))
end

export type Linha = { id: number, dano: number }

-- Ranking de dano (maior primeiro; empate: quem chegou antes, pelo id)
function EventoSol.ranking(danos: { [number]: number }): { Linha }
	local lista = {}
	for id, dano in danos do
		if dano > 0 then
			table.insert(lista, { id = id, dano = dano })
		end
	end
	table.sort(lista, function(a, b)
		if a.dano ~= b.dano then
			return a.dano > b.dano
		end
		return a.id < b.id
	end)
	return lista
end

-- Baús de cada participante: { [id] = "sol" | "dourado" }
function EventoSol.premios(danos: { [number]: number }, derrotado: boolean): { [number]: string }
	local saida = {}
	for i, l in EventoSol.ranking(danos) do
		saida[l.id] = if derrotado and i <= EventoSol.TOP_DOURADO then "dourado" else "sol"
	end
	return saida
end

-- ============================================================ baús

export type Premio = { id: string, peso: number, nome: string }
EventoSol.BAUS = {
	sol = {
		nome = "Baú do Sol",
		cor = "FFD54A",
		itens = {
			{ id = "gear5", peso = 1, nome = "Aura Gear 5" },
			{ id = "ras_nuvem_sol", peso = 10, nome = "Rastro Nuvem do Sol" },
			{ id = "tit_libertado", peso = 15, nome = "Título Libertado" },
			{ id = "pontos", peso = 44, nome = "Pontos de Aura" },
			{ id = "fragmentos", peso = 30, nome = "Fragmentos" },
		},
	},
	dourado = {
		nome = "Baú do Sol Dourado",
		cor = "FFFFFF",
		itens = {
			{ id = "gear5", peso = 5, nome = "Aura Gear 5" },
			{ id = "ras_nuvem_sol", peso = 25, nome = "Rastro Nuvem do Sol" },
			{ id = "tit_libertado", peso = 30, nome = "Título Libertado" },
			{ id = "pontos", peso = 25, nome = "Pontos de Aura" },
			{ id = "fragmentos", peso = 15, nome = "Fragmentos" },
		},
	},
} :: { [string]: { nome: string, cor: string, itens: { Premio } } }

-- Chance (0..1) de cada item de um baú, para mostrar na tela
function EventoSol.chances(tipo: string): { [string]: number }
	local bau = EventoSol.BAUS[tipo]
	local total = 0
	for _, it in bau.itens do
		total += it.peso
	end
	local saida = {}
	for _, it in bau.itens do
		saida[it.id] = it.peso / total
	end
	return saida
end

export type Progresso = {
	sol: number, -- baús guardados
	dourado: number,
	abertos: number,
	semGear5: number, -- baús abertos desde a última Gear 5 (garantia)
	gear5: number, -- quantas Gear 5 já vieram
	participacoes: number,
}

function EventoSol.padrao(): Progresso
	return { sol = 0, dourado = 0, abertos = 0, semGear5 = 0, gear5 = 0, participacoes = 0 }
end

local function inteiro(v: any): number
	return if type(v) == "number" and v == v and v >= 0 and v < math.huge then math.floor(v) else 0
end

function EventoSol.normalizar(p: any): Progresso
	local t = if type(p) == "table" then p else {}
	return {
		sol = inteiro(t.sol),
		dourado = inteiro(t.dourado),
		abertos = inteiro(t.abertos),
		semGear5 = inteiro(t.semGear5),
		gear5 = inteiro(t.gear5),
		participacoes = inteiro(t.participacoes),
	}
end

-- Quantos baús faltam para a Gear 5 garantida
function EventoSol.faltaGarantia(p: Progresso): number
	return math.max(1, EventoSol.GARANTIA - p.semGear5)
end

-- Abre um baú. `aleatorio` devolve [0, 1) (Random do servidor); `possui(id)` diz se o jogador
-- já tem o cosmético (repetido vira Pontos de Aura). Devolve o id do prêmio, ou nil + motivo.
function EventoSol.abrir(
	p: Progresso,
	tipo: any,
	aleatorio: () -> number,
	possui: (string) -> boolean
): (string?, string?)
	local bau = if type(tipo) == "string" then EventoSol.BAUS[tipo] else nil
	if not bau then
		return nil, "Baú desconhecido."
	end
	local guardados = if tipo == "sol" then p.sol else p.dourado
	if guardados <= 0 then
		return nil, "Você não tem esse baú."
	end
	if tipo == "sol" then
		p.sol -= 1
	else
		p.dourado -= 1
	end
	p.abertos += 1
	p.semGear5 += 1
	local premio: string
	if p.semGear5 >= EventoSol.GARANTIA then
		premio = "gear5"
	else
		local total = 0
		for _, it in bau.itens do
			total += it.peso
		end
		local r = aleatorio() * total
		premio = bau.itens[#bau.itens].id
		for _, it in bau.itens do
			if r < it.peso then
				premio = it.id
				break
			end
			r -= it.peso
		end
	end
	if premio == "gear5" then
		p.semGear5 = 0
		p.gear5 += 1
	elseif (premio == "ras_nuvem_sol" or premio == "tit_libertado") and possui(premio) then
		premio = "pontos"
	end
	return premio, nil
end

-- Quantidade dos prêmios de recurso
function EventoSol.pontosDoBau(tipo: string, ganhoPorSegundo: number): number
	local base = math.max(200, math.floor(math.max(ganhoPorSegundo, 0) * 120))
	return if tipo == "dourado" then base * 3 else base
end

function EventoSol.fragmentosDoBau(tipo: string, faseCorredor: number): number
	local base = 10 + 5 * math.clamp(faseCorredor, 0, 6)
	return if tipo == "dourado" then base * 3 else base
end

-- "12:40"
function EventoSol.tempo(segundos: number): string
	local s = math.max(0, math.floor(segundos))
	return string.format("%d:%02d", s // 60, s % 60)
end

return EventoSol
