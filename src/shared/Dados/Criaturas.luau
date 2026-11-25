-- Criaturas do Corredor dos Perdidos: um lacaio e um chefe por fase. Toque numa criatura para
-- mirar; a sua aura ataca sozinha enquanto você estiver perto (e ataca a mais próxima se você não
-- escolher). Elas ficam no lugar, viram para quem chega e batem em quem fica perto.
-- Vencer o chefe da fase é o que abre o Portão. Só números e regras puras: o servidor decide
-- tudo com este módulo. Testado em testes/logica.luau. O visual vem de Dados/CriaturasVisual.
local Corredor = require(script.Parent.Corredor)

local Criaturas = {}

export type Fase = {
	lacaio: string,
	chefe: string,
	nomeLacaio: string,
	nomeChefe: string,
	fragmentosLacaio: number,
}

Criaturas.FASES = {
	{
		lacaio = "lasca_errante",
		chefe = "sentinela_limiar",
		nomeLacaio = "Lasca Errante",
		nomeChefe = "Sentinela do Limiar",
		fragmentosLacaio = 1,
	},
	{
		lacaio = "broto_vidro",
		chefe = "anciao_bosque",
		nomeLacaio = "Broto de Vidro",
		nomeChefe = "Ancião do Bosque",
		fragmentosLacaio = 1,
	},
	{
		lacaio = "cinzento",
		chefe = "senhor_brasas",
		nomeLacaio = "Cinzento",
		nomeChefe = "Senhor das Brasas",
		fragmentosLacaio = 2,
	},
	{
		lacaio = "marujo_afogado",
		chefe = "capitao_abissal",
		nomeLacaio = "Marujo Afogado",
		nomeChefe = "Capitão Abissal",
		fragmentosLacaio = 3,
	},
	{
		lacaio = "estatua_viva",
		chefe = "arcanjo_partido",
		nomeLacaio = "Estátua Viva",
		nomeChefe = "Arcanjo Partido",
		fragmentosLacaio = 5,
	},
	{
		lacaio = "eco_vazio",
		chefe = "devorador_estrelas",
		nomeLacaio = "Eco do Vazio",
		nomeChefe = "Devorador de Estrelas",
		fragmentosLacaio = 8,
	},
} :: { Fase }

-- Onde cada criatura nasce, no espaço local da ilha (o mesmo do gerador do Corredor: x para o
-- lado, y ao longo da trilha de -75 a +75; o Portão fica em +72). Lacaios nos três pedaços da
-- ilha, longe da trilha; o chefe fica no último pedaço, guardando o Portão.
Criaturas.POSICOES = {
	{ tipo = "lacaio", x = -9, y = -48 },
	{ tipo = "lacaio", x = 10, y = -38 },
	{ tipo = "lacaio", x = -11, y = -6 },
	{ tipo = "lacaio", x = 9, y = 6 },
	{ tipo = "lacaio", x = -8, y = 16 },
	{ tipo = "lacaio", x = 11, y = 34 },
	{ tipo = "chefe", x = 0, y = 52 },
}

Criaturas.ALCANCE_AURA = 30 -- studs: até onde a aura do jogador alcança o alvo
Criaturas.AUTO_MIRA = 14 -- sem alvo escolhido, a aura ataca a criatura mais próxima até aqui
Criaturas.ESPERA_GOLPE = 0.8 -- segundos entre golpes da aura
Criaturas.LACAIO = { alcance = 8, espera = 1.6, dano = 7, renasce = 20, golpes = 6, pontos = 12 }
Criaturas.CHEFE = { alcance = 17, espera = 2.4, dano = 18, renasce = 40, golpes = 40, pontos = 90 }
Criaturas.CHANCE_FRAGMENTO = 0.25 -- chance de um lacaio soltar Fragmentos

-- Dano de um golpe da aura, pela Pontuação de Aura de quem ataca
function Criaturas.danoJogador(pontuacao: number): number
	local p = if type(pontuacao) == "number"
			and pontuacao == pontuacao
			and pontuacao > 0
		then pontuacao
		else 0
	return math.floor(5 + p * 0.5)
end

-- Vida pensada para quem tem a Pontuação mínima da fase: o lacaio cai em ~6 golpes e o chefe
-- em ~40 (menos para quem é mais forte ou com ajuda de outros jogadores)
function Criaturas.vida(fase: number, tipo: string): number
	local f = Corredor.FASES[fase]
	local referencia = math.max(f and f.requisito or 0, 12)
	local golpes = if tipo == "chefe" then Criaturas.CHEFE.golpes else Criaturas.LACAIO.golpes
	return Criaturas.danoJogador(referencia) * golpes
end

function Criaturas.regras(tipo: string): { [string]: number }
	return if tipo == "chefe" then Criaturas.CHEFE else Criaturas.LACAIO
end

-- Ponto local da ilha (x, y do gerador) -> mundo do Roblox, com o centro e o giro da ilha
function Criaturas.paraMundo(
	centro: { number },
	giro: number,
	x: number,
	y: number
): (number, number, number)
	local lx, lz = x, -y
	local t = math.rad(giro)
	return centro[1] + lx * math.cos(t) + lz * math.sin(t),
		centro[2],
		centro[3] - lx * math.sin(t) + lz * math.cos(t)
end

-- Recompensa de quem ajudou a derrubar: segundos de Pontos de Aura e Fragmentos (com o sorteio
-- do lacaio já feito fora, pelo servidor)
function Criaturas.recompensa(
	fase: number,
	tipo: string,
	ganhoPorSegundo: number,
	sorteioFragmento: number,
	multiplicadorFragmentos: number?
): (number, number)
	local regras = Criaturas.regras(tipo)
	local pontos = math.floor(math.max(ganhoPorSegundo, 0) * regras.pontos)
	local fragmentos = 0
	if tipo == "lacaio" and sorteioFragmento < Criaturas.CHANCE_FRAGMENTO then
		local f = Criaturas.FASES[fase]
		local m = multiplicadorFragmentos or 1
		fragmentos = math.max(1, math.floor((f and f.fragmentosLacaio or 1) * m + 0.5))
	end
	return pontos, fragmentos
end

return Criaturas
