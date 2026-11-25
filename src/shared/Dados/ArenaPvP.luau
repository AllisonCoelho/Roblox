-- Arena entre jogadores (Trono do Servidor e Rankeada): força pela Pontuação de Aura, rating Elo,
-- divisões, perfil da Arena e o buff do Rei. Só regras puras (sem Roblox), testadas em
-- testes/logica.luau. O combate em si é o reativo de Dados/Duelo (o mesmo contra o Soberano);
-- aqui fica o que é só do 1x1: o dano de cada um é escalado pela Pontuação de Aura, então o
-- mais forte vence sempre, mas entre auras parecidas cada turno importa.
local ArenaPvP = {}

ArenaPvP.EXPOENTE = 0.6 -- quanto a diferença de Pontuação pesa no dano
ArenaPvP.MULT_MIN = 0.35
ArenaPvP.MULT_MAX = 2.8

ArenaPvP.RATING_INICIAL = 1000
ArenaPvP.K = 32

-- Multiplicadores de dano de A e de B pela Pontuação
function ArenaPvP.multiplicadores(pa: number, pb: number): (number, number)
	local a, b = math.max(pa, 1), math.max(pb, 1)
	local razao = (a / b) ^ ArenaPvP.EXPOENTE
	return math.clamp(razao, ArenaPvP.MULT_MIN, ArenaPvP.MULT_MAX),
		math.clamp(1 / razao, ArenaPvP.MULT_MIN, ArenaPvP.MULT_MAX)
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
