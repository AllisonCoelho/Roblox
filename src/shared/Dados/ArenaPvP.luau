-- Duelo 1x1 entre jogadores na Arena (Trono do Servidor e Rankeada). Só regras puras (sem
-- Roblox), testadas em testes/logica.luau. O servidor decide tudo com este módulo.
--
-- Os dois escolhem a ação ao mesmo tempo (mesmas ações do duelo contra o Soberano: Ataque,
-- Corte, Selo, Guarda e Despertar) e as duas acontecem juntas. O dano de cada um é escalado
-- pela Pontuação de Aura: o mais forte vence sempre, mas entre auras parecidas cada turno importa
-- (Guarda na hora certa, guardar energia para o Despertar, o Selo antes do golpe pesado).
--
-- Rankeada: rating Elo (começa em 1000) e divisões. Trono: sem rating, quem vence fica com o
-- trono do servidor.
local Arena = require(script.Parent.Arena)

local ArenaPvP = {}

ArenaPvP.VIDA = Arena.VIDA
ArenaPvP.CARGA = Arena.CARGA
ArenaPvP.ESPERA_TURNO = 20 -- segundos para escolher (sem escolha = Guarda)
ArenaPvP.EXPOENTE = 0.6 -- quanto a diferença de Pontuação pesa no dano
ArenaPvP.MULT_MIN = 0.35
ArenaPvP.MULT_MAX = 2.8
ArenaPvP.RODADAS_MAX = 20 -- depois disso, vence quem tiver mais vida (empate: mais forte)

ArenaPvP.RATING_INICIAL = 1000
ArenaPvP.K = 32

export type Lado = {
	vida: number,
	energia: number,
	recargas: { [string]: number },
	selado: boolean,
	mult: number, -- multiplicador de dano pela Pontuação
	pontuacao: number,
}
export type Estado = { rodada: number, a: Lado, b: Lado }
export type Golpe = {
	id: string,
	nome: string,
	lado: string, -- "a" ou "b" (quem golpeia)
	dano: number,
	especial: boolean,
	estado: Estado, -- depois deste golpe
}
export type Resolucao = { golpes: { Golpe }, estado: Estado, vencedor: string? }

-- Multiplicadores de dano de A e de B pela Pontuação
function ArenaPvP.multiplicadores(pa: number, pb: number): (number, number)
	local a, b = math.max(pa, 1), math.max(pb, 1)
	local razao = (a / b) ^ ArenaPvP.EXPOENTE
	return math.clamp(razao, ArenaPvP.MULT_MIN, ArenaPvP.MULT_MAX),
		math.clamp(1 / razao, ArenaPvP.MULT_MIN, ArenaPvP.MULT_MAX)
end

local function lado(pontuacao: number, mult: number): Lado
	return {
		vida = ArenaPvP.VIDA,
		energia = 0,
		recargas = {},
		selado = false,
		mult = mult,
		pontuacao = pontuacao,
	}
end

function ArenaPvP.novo(pa: number, pb: number): Estado
	local ma, mb = ArenaPvP.multiplicadores(pa, pb)
	return { rodada = 1, a = lado(pa, ma), b = lado(pb, mb) }
end

local function copiar(e: Estado): Estado
	local function c(l: Lado): Lado
		local n = table.clone(l)
		n.recargas = table.clone(l.recargas)
		return n
	end
	return { rodada = e.rodada, a = c(e.a), b = c(e.b) }
end

function ArenaPvP.restante(l: Lado, rodada: number, id: string): number
	return math.max(0, (l.recargas[id] or 0) - rodada)
end

-- Problema com a ação (nil = pode)
function ArenaPvP.validar(e: Estado, qual: string, id: any): string?
	local l = if qual == "a" then e.a else e.b
	if e.a.vida <= 0 or e.b.vida <= 0 then
		return "O duelo terminou."
	elseif type(id) ~= "string" or not Arena.Acoes[id] then
		return "Ação desconhecida."
	elseif ArenaPvP.restante(l, e.rodada, id) > 0 then
		return "Esta técnica está recarregando."
	elseif id == "despertar" and l.energia < ArenaPvP.CARGA then
		return "Encha a barra de energia para despertar."
	end
	return nil
end

-- Ação válida ou Guarda (quem não escolheu a tempo ou mandou algo inválido)
function ArenaPvP.ouGuarda(e: Estado, qual: string, id: any): string
	return if ArenaPvP.validar(e, qual, id) == nil then id else "guarda"
end

-- Dano que `atacante` causa em `defensor` com a ação `id`, sabendo a ação do defensor
local function danoDe(id: string, atacante: Lado, defensor: Lado, acaoDefensor: string): number
	local base = Arena.Acoes[id].dano
	if base <= 0 then
		return 0
	end
	local d = base * atacante.mult
	if acaoDefensor == "guarda" then
		d *= 0.35
	end
	return math.floor(d + 0.5)
end

-- Quem vence quando os dois caem juntos ou o duelo chega no limite de rodadas
local function desempate(e: Estado): string
	if e.a.vida ~= e.b.vida then
		return if e.a.vida > e.b.vida then "a" else "b"
	end
	return if e.a.pontuacao >= e.b.pontuacao then "a" else "b"
end

-- Resolve a rodada com as duas ações (já válidas: use ouGuarda antes)
function ArenaPvP.resolver(e: Estado, acaoA: string, acaoB: string): Resolucao
	local s = copiar(e)
	local danos = {
		a = danoDe(acaoA, s.a, s.b, acaoB),
		b = danoDe(acaoB, s.b, s.a, acaoA),
	}
	-- energia, recargas e selo de cada um
	for _, par in { { s.a, acaoA }, { s.b, acaoB } } do
		local l, id = par[1], par[2]
		local acao = Arena.Acoes[id]
		if acao.recarga > 0 then
			l.recargas[id] = s.rodada + acao.recarga + 1
		end
		l.energia = math.clamp(l.energia + acao.energia, 0, ArenaPvP.CARGA)
		-- o Selo já protege nesta rodada (como no duelo contra o Soberano)
		if id == "selo" then
			l.selado = true
		end
	end
	local golpes: { Golpe } = {}
	-- os dois golpes acontecem juntos; na tela, a Guarda aparece primeiro (para o golpe do outro
	-- já encontrar a defesa) e, fora isso, primeiro A e depois B
	local ordem = if acaoB == "guarda" and acaoA ~= "guarda" then { "b", "a" } else { "a", "b" }
	for _, qual in ordem do
		local id = if qual == "a" then acaoA else acaoB
		local defensor = if qual == "a" then s.b else s.a
		local dano = danos[qual]
		if defensor.selado and dano > 0 then
			dano = math.floor(dano * 0.5)
			defensor.selado = false
		end
		dano = math.min(defensor.vida, dano)
		defensor.vida -= dano
		table.insert(golpes, {
			id = id,
			nome = Arena.Acoes[id].nome,
			lado = qual,
			dano = dano,
			especial = Arena.Acoes[id].especial == true,
			estado = copiar(s),
		})
	end
	local vencedor: string? = nil
	if s.a.vida <= 0 or s.b.vida <= 0 then
		vencedor = if s.a.vida <= 0 and s.b.vida <= 0
			then desempate(s)
			elseif s.a.vida <= 0 then "b"
			else "a"
	elseif s.rodada >= ArenaPvP.RODADAS_MAX then
		vencedor = desempate(s)
	end
	local final = copiar(s)
	if not vencedor then
		final.rodada += 1
	end
	return { golpes = golpes, estado = final, vencedor = vencedor }
end

-- O estado do ponto de vista de um dos lados, no formato do duelo contra o Soberano
-- (a tela do duelo é a mesma): vida = a sua, soberano = a do oponente
function ArenaPvP.visao(e: Estado, qual: string): { [string]: any }
	local eu = if qual == "a" then e.a else e.b
	local outro = if qual == "a" then e.b else e.a
	return {
		rodada = e.rodada,
		vida = eu.vida,
		soberano = outro.vida,
		energia = eu.energia,
		recargas = eu.recargas,
		selado = eu.selado,
		energiaOponente = outro.energia,
		mult = eu.mult,
		multOponente = outro.mult,
	}
end

-- ============================================================ rating e divisões

function ArenaPvP.esperado(ra: number, rb: number): number
	return 1 / (1 + 10 ^ ((rb - ra) / 400))
end

-- Novos ratings depois de uma partida (vencedor primeiro)
function ArenaPvP.elo(vencedor: number, perdedor: number): (number, number)
	local e = ArenaPvP.esperado(vencedor, perdedor)
	local ganho = math.max(1, math.floor(ArenaPvP.K * (1 - e) + 0.5))
	return vencedor + ganho, math.max(0, perdedor - ganho)
end

ArenaPvP.DIVISOES = {
	{ nome = "Bronze", minimo = 0, cor = "C8875A" },
	{ nome = "Prata", minimo = 1100, cor = "C9CED8" },
	{ nome = "Ouro", minimo = 1250, cor = "FFC83D" },
	{ nome = "Platina", minimo = 1400, cor = "5CE1FF" },
	{ nome = "Diamante", minimo = 1600, cor = "A78BFA" },
	{ nome = "Mestre", minimo = 1850, cor = "FF5C8A" },
}

function ArenaPvP.divisao(rating: number): { nome: string, minimo: number, cor: string }
	local atual = ArenaPvP.DIVISOES[1]
	for _, d in ArenaPvP.DIVISOES do
		if rating >= d.minimo then
			atual = d
		end
	end
	return atual
end

-- Janela de rating aceita para parear na fila (cresce com a espera)
function ArenaPvP.janela(segundosNaFila: number): number
	return 100 + 50 * math.floor(math.max(segundosNaFila, 0) / 10)
end

-- ============================================================ perfil

export type Perfil = {
	rating: number,
	vitorias: number,
	derrotas: number,
	monarca: number, -- vezes que derrotou o Primeiro Soberano (a prova do trono)
	reinados: number, -- vezes que virou Rei do Servidor
	maiorReinado: number, -- segundos do reinado mais longo
}

function ArenaPvP.padrao(): Perfil
	return {
		rating = ArenaPvP.RATING_INICIAL,
		vitorias = 0,
		derrotas = 0,
		monarca = 0,
		reinados = 0,
		maiorReinado = 0,
	}
end

local function numero(v: any, padrao: number): number
	return if type(v) == "number"
			and v == v
			and v >= 0
			and v < math.huge
		then math.floor(v)
		else padrao
end

function ArenaPvP.normalizar(p: any): Perfil
	local t = if type(p) == "table" then p else {}
	return {
		rating = numero(t.rating, ArenaPvP.RATING_INICIAL),
		vitorias = numero(t.vitorias, 0),
		derrotas = numero(t.derrotas, 0),
		monarca = numero(t.monarca, 0),
		reinados = numero(t.reinados, 0),
		maiorReinado = numero(t.maiorReinado, 0),
	}
end

-- ============================================================ Rei do Servidor

ArenaPvP.REI_GANHO = 1.25 -- +25% de Pontos de Aura enquanto for o Rei
ArenaPvP.REI_SORTE = 1.1 -- +10% de sorte (dentro do teto de sorte do giro)
ArenaPvP.PROTECAO_REI = 30 -- segundos sem desafios depois de defender o trono
ArenaPvP.AVISO_REI = 12 -- segundos que o Rei tem para responder ao desafio

return ArenaPvP
