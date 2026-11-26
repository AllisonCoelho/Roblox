-- Animações do duelo da Arena (jogador e Primeiro Soberano), feitas por código e sem asset.
-- Aqui só ficam números: tempos de cada golpe (o servidor usa para encenar), quadros-chave e
-- a amostragem com as pernas resolvidas por cinemática inversa (os pés ficam no chão).
-- O cliente lê a pose amostrada e escreve nas juntas (ArenaCorpo / NPCs/PrimeiroSoberano).
--
-- Convenções (personagem olhando para -Z, como no Roblox):
--   juntas em graus { x, y, z }. Em x positivo, o braço ou a perna vai para a frente, o tronco e
--   a cabeça vão para trás e o joelho dobra para a frente. Em y positivo, gira para a esquerda.
--   Em z positivo, o braço direito abre (o esquerdo usa o sinal oposto).
--   raiz = { x, y, z, rx, ry, rz }: deslocamento (studs) e giro do corpo inteiro.
--   peD / peE = { altura, frente }: onde fica o pé. Frente negativa = à frente do corpo.
--   Os pés são medidos no referencial do posto (o mesmo da raiz), então a raiz pode avançar e o
--   pé que ficou para trás continua plantado.
local Animacoes = {}

export type Pose = { [string]: number }
export type Chave = { t: number, pose: Pose, curva: string? }
export type Clipe = { duracao: number, chaves: { Chave }, laco: boolean?, segurar: boolean? }

-- Duração da entrada do Soberano (salto do trono até o ringue) antes do primeiro turno
Animacoes.INTRODUCAO = 2.6

-- Os instantes de cada acerto ficam em Dados/Duelo (ACOES[id].acertos): cada clipe foi feito
-- para bater com eles (os testes conferem que os acertos cabem no clipe).

---------------------------------------------------------------------------------------------
-- Montagem das poses

-- Cada canal vira um número com nome "junta1", "junta2"... (fácil de interpolar)
local function achatar(base: Pose, mudancas: { [string]: { number } }?): Pose
	local p = table.clone(base)
	local lista: { [string]: { number } } = mudancas or {}
	for nome, valores in lista do
		for i, v in valores do
			p[nome .. i] = v
		end
	end
	return p
end
Animacoes.achatar = achatar

local function k(t: number, pose: Pose, curva: string?): Chave
	return { t = t, pose = pose, curva = curva }
end

---------------------------------------------------------------------------------------------
-- Jogador (R15; o R6 aproveita braços, tronco e quadris)

local NEUTRO_J = achatar({}, {
	raiz = { 0, 0, 0, 0, 0, 0 },
	cintura = { 0, 0, 0 },
	pescoco = { 0, 0, 0 },
	ombroD = { 0, 0, 0 },
	cotoveloD = { 0, 0, 0 },
	ombroE = { 0, 0, 0 },
	cotoveloE = { 0, 0, 0 },
	peD = { 0, 0 },
	peE = { 0, 0 },
	abrirD = { 0 },
	abrirE = { 0 },
})

-- Postura de luta: base baixa, pé esquerdo à frente, punhos na altura do queixo
local POSTURA = achatar(NEUTRO_J, {
	raiz = { 0, -0.35, 0, 0, 14, 0 },
	cintura = { -6, 8, 0 },
	pescoco = { 4, -18, 0 },
	ombroD = { 52, 0, 16 },
	cotoveloD = { 92, 0, 0 },
	ombroE = { 66, 0, -10 },
	cotoveloE = { 82, 0, 0 },
	peD = { 0, 0.5 },
	peE = { 0, -0.55 },
	abrirD = { 6 },
	abrirE = { -6 },
})

local function J(mudancas: { [string]: { number } }): Pose
	return achatar(POSTURA, mudancas)
end

local GUARDA_J = J({
	raiz = { 0, -0.6, 0, 0, 6, 0 },
	cintura = { -10, 0, 0 },
	pescoco = { -6, -6, 0 },
	ombroD = { 96, 0, -34 },
	cotoveloD = { 62, 0, 0 },
	ombroE = { 96, 0, 34 },
	cotoveloE = { 62, 0, 0 },
})

-- Descarga do Despertar (os braços empurram a energia) e o recolher entre as descargas
local DESCARGA_1 = 0.96
local DESCARGA = J({
	raiz = { 0, 0.7, 0, 0, 0, 0 },
	cintura = { -24, 0, 0 },
	pescoco = { -4, 0, 0 },
	ombroD = { 92, 0, -6 },
	cotoveloD = { 0, 0, 0 },
	ombroE = { 92, 0, 6 },
	cotoveloE = { 0, 0, 0 },
	peD = { 0.6, 0.6 },
	peE = { 0.5, -0.3 },
})
local RECARGA = J({
	raiz = { 0, 0.55, 0.15, 0, 0, 0 },
	cintura = { -8, 0, 0 },
	ombroD = { 60, 0, -20 },
	cotoveloD = { 80, 0, 0 },
	ombroE = { 60, 0, 20 },
	cotoveloE = { 80, 0, 0 },
	peD = { 0.5, 0.6 },
	peE = { 0.45, -0.3 },
})

Animacoes.JOGADOR = {
	-- respiração da postura (fica tocando entre as ações)
	postura = {
		duracao = 1.3,
		laco = true,
		chaves = {
			k(0, POSTURA),
			k(
				0.65,
				J({
					raiz = { 0, -0.44, 0, 0, 14, 0 },
					ombroD = { 50, 0, 16 },
					ombroE = { 62, 0, -10 },
				})
			),
			k(1.3, POSTURA),
		},
	},
	entrada = {
		duracao = 0.6,
		chaves = {
			k(0, NEUTRO_J),
			-- Pisa à frente e fecha a guarda, com o rosto voltado ao adversário.
			k(
				0.22,
				J({
					raiz = { 0.14, -0.15, 0, 0, 22, 0 },
					cintura = { 5, 12, 0 },
					pescoco = { 0, -28, 0 },
					ombroD = { 26, 0, 24 },
					ombroE = { 34, 0, -20 },
					peD = { 0, 0.35 },
					peE = { 0.45, -0.35 },
				})
			),
			k(
				0.38,
				J({
					raiz = { -0.08, -0.48, -0.12, 0, 12, 0 },
					cintura = { -11, 4, 0 },
					ombroE = { 76, 0, -12 },
					peD = { 0, 0.5 },
					peE = { 0, -0.65 },
				}),
				"entrada"
			),
			k(0.6, POSTURA),
		},
	},
	-- corre até o Soberano e solta um direto
	ataque = {
		duracao = 0.9,
		chaves = {
			k(0, POSTURA),
			k(
				0.08,
				J({
					raiz = { 0, -0.5, 0, 0, 10, 0 },
					cintura = { -26, 0, 0 },
					ombroD = { -40, 0, 16 },
					cotoveloD = { 95, 0, 0 },
					ombroE = { 55, 0, -8 },
					peD = { 0, 0.8 },
					peE = { 0.7, -0.6 },
				})
			),
			k(
				0.22,
				J({
					raiz = { 0, -0.42, 0, 0, 20, 0 },
					cintura = { -24, 0, 0 },
					ombroD = { -45, 0, 20 },
					cotoveloD = { 95, 0, 0 },
					ombroE = { 70, 0, -8 },
					peD = { 0.8, -0.5 },
					peE = { 0, 0.7 },
				})
			),
			k(
				0.33,
				J({
					raiz = { 0, -0.5, 0, 0, 34, 0 },
					cintura = { -12, 20, 0 },
					ombroD = { -30, 0, 22 },
					cotoveloD = { 100, 0, 0 },
					peD = { 0, 0.7 },
					peE = { 0, -0.9 },
				})
			),
			k(
				0.39,
				J({
					raiz = { 0, -0.58, 0, 0, -12, 0 },
					cintura = { -16, -30, 0 },
					pescoco = { 2, 10, 0 },
					ombroD = { 92, 0, 2 },
					cotoveloD = { 4, 0, 0 },
					ombroE = { 34, 0, -22 },
					cotoveloE = { 105, 0, 0 },
					peD = { 0, 0.9 },
					peE = { 0, -1.05 },
				}),
				"saida"
			),
			k(
				0.56,
				J({
					raiz = { 0, -0.55, 0, 0, -10, 0 },
					cintura = { -14, -26, 0 },
					ombroD = { 88, 0, 4 },
					cotoveloD = { 10, 0, 0 },
					ombroE = { 34, 0, -22 },
					cotoveloE = { 105, 0, 0 },
					peD = { 0, 0.9 },
					peE = { 0, -1.05 },
				})
			),
			-- salto para trás de volta ao posto
			k(
				0.68,
				J({
					raiz = { 0, 0.55, 0, 10, 8, 0 },
					cintura = { 6, 0, 0 },
					ombroD = { 30, 0, 30 },
					ombroE = { 30, 0, -30 },
					peD = { 1.0, 0.5 },
					peE = { 1.1, -0.1 },
				}),
				"saida"
			),
			k(0.8, J({ raiz = { 0, -0.6, 0, 0, 14, 0 }, cintura = { -12, 8, 0 } }), "entrada"),
			k(0.9, POSTURA),
		},
	},
	-- Corte de Ressonância: salta e gira no 1º golpe (0,5 s) e volta com um corte de revés (0,86 s)
	corte = {
		duracao = 1.3,
		chaves = {
			k(0, POSTURA),
			k(
				0.12,
				J({
					raiz = { 0, -0.62, 0, 0, 40, 0 },
					cintura = { -28, 24, 0 },
					ombroD = { 20, 0, 70 },
					cotoveloD = { 25, 0, 0 },
					ombroE = { 40, 0, -40 },
					peD = { 0, 0.8 },
					peE = { 0.7, -0.5 },
				})
			),
			k(
				0.3,
				J({
					raiz = { 0, -0.55, 0, 0, 50, 0 },
					cintura = { -26, 28, 0 },
					ombroD = { 15, 0, 75 },
					cotoveloD = { 25, 0, 0 },
					ombroE = { 40, 0, -40 },
					peD = { 0.8, -0.4 },
					peE = { 0, 0.6 },
				})
			),
			k(
				0.42,
				J({
					raiz = { 0, 0.8, 0, 0, 62, 0 },
					cintura = { -10, 30, 0 },
					ombroD = { 10, 0, 85 },
					cotoveloD = { 10, 0, 0 },
					ombroE = { 30, 0, -60 },
					peD = { 1.2, 0.3 },
					peE = { 1.4, -0.3 },
				}),
				"saida"
			),
			-- 1º golpe: giro no ar com o braço esticado
			k(
				0.5,
				J({
					raiz = { 0, 0.5, 0, 0, -250, 0 },
					cintura = { -14, -10, 0 },
					ombroD = { 30, 0, 92 },
					cotoveloD = { 2, 0, 0 },
					ombroE = { 20, 0, -70 },
					peD = { 1.0, 0.4 },
					peE = { 1.1, -0.4 },
				})
			),
			-- pousa e arma o revés
			k(
				0.66,
				J({
					raiz = { 0, -0.8, 0, 0, -320, 0 },
					cintura = { -20, 40, 0 },
					ombroD = { 40, 0, -30 },
					cotoveloD = { 70, 0, 0 },
					ombroE = { 30, 0, -40 },
					peD = { 0, 0.9 },
					peE = { 0, -0.9 },
					abrirD = { 14 },
					abrirE = { -14 },
				}),
				"entrada"
			),
			-- 2º golpe: revés com o braço aberto
			k(
				0.86,
				J({
					raiz = { 0, -0.6, 0, 0, -386, 0 },
					cintura = { -20, -34, 0 },
					ombroD = { 88, 0, 46 },
					cotoveloD = { 2, 0, 0 },
					ombroE = { 34, 0, -40 },
					peD = { 0, 0.9 },
					peE = { 0, -1.0 },
					abrirD = { 14 },
					abrirE = { -14 },
				}),
				"saida"
			),
			k(
				1.02,
				J({
					raiz = { 0, -0.65, 0, 0, -380, 0 },
					cintura = { -18, -28, 0 },
					ombroD = { 80, 0, 40 },
					cotoveloD = { 8, 0, 0 },
					peD = { 0, 0.9 },
					peE = { 0, -1.0 },
				})
			),
			k(1.3, J({ raiz = { 0, -0.35, 0, 0, -346, 0 } })),
		},
	},
	-- base aberta, as duas palmas empurram o selo
	selo = {
		duracao = 1.08,
		chaves = {
			k(0, POSTURA),
			k(
				0.26,
				J({
					raiz = { 0, -0.72, 0, 0, 0, 0 },
					cintura = { 6, 0, 0 },
					pescoco = { -4, 0, 0 },
					ombroD = { -26, 0, 22 },
					cotoveloD = { 92, 0, 0 },
					ombroE = { -26, 0, -22 },
					cotoveloE = { 92, 0, 0 },
					peD = { 0, 0.55 },
					peE = { 0, -0.5 },
					abrirD = { 20 },
					abrirE = { -20 },
				})
			),
			k(
				0.48,
				J({
					raiz = { 0, -0.78, 0, 0, 0, 0 },
					cintura = { -16, 0, 0 },
					pescoco = { -2, 0, 0 },
					ombroD = { 90, 0, -10 },
					cotoveloD = { 0, 0, 0 },
					ombroE = { 90, 0, 10 },
					cotoveloE = { 0, 0, 0 },
					peD = { 0, 0.75 },
					peE = { 0, -0.75 },
					abrirD = { 20 },
					abrirE = { -20 },
				}),
				"saida"
			),
			k(
				0.76,
				J({
					raiz = { 0, -0.74, 0, 0, 0, 0 },
					cintura = { -12, 0, 0 },
					ombroD = { 86, 0, -10 },
					cotoveloD = { 6, 0, 0 },
					ombroE = { 86, 0, 10 },
					cotoveloE = { 6, 0, 0 },
					peD = { 0, 0.75 },
					peE = { 0, -0.75 },
					abrirD = { 20 },
					abrirE = { -20 },
				})
			),
			k(1.08, POSTURA),
		},
	},
	-- braços cruzados; fica assim até o golpe do Soberano chegar
	guarda = {
		duracao = 0.3,
		segurar = true,
		chaves = { k(0, POSTURA), k(0.3, GUARDA_J, "saida") },
	},
	-- junta a energia agachado, sobe com os braços ao céu e descarrega três vezes à frente
	-- (0,96 s, 1,26 s e 1,56 s; a última é a maior)
	despertar = {
		duracao = 2.2,
		chaves = {
			k(0, POSTURA),
			k(
				0.32,
				J({
					raiz = { 0, -0.85, 0, 0, 0, 0 },
					cintura = { 14, 0, 0 },
					pescoco = { -16, 0, 0 },
					ombroD = { -12, 0, 36 },
					cotoveloD = { 22, 0, 0 },
					ombroE = { -12, 0, -36 },
					cotoveloE = { 22, 0, 0 },
					peD = { 0, 0.4 },
					peE = { 0, -0.4 },
					abrirD = { 18 },
					abrirE = { -18 },
				})
			),
			k(
				0.72,
				J({
					raiz = { 0, 1.3, 0, 0, 0, 0 },
					cintura = { 12, 0, 0 },
					pescoco = { 18, 0, 0 },
					ombroD = { 168, 0, 24 },
					cotoveloD = { 6, 0, 0 },
					ombroE = { 168, 0, -24 },
					cotoveloE = { 6, 0, 0 },
					peD = { 1.15, 0.35 },
					peE = { 1.25, -0.1 },
				}),
				"saida"
			),
			-- Primeira palma com a esquerda. A mão direita fica carregada junto ao peito.
			k(
				DESCARGA_1,
				achatar(DESCARGA, {
					cintura = { -18, 24, -5 },
					pescoco = { 0, -18, 0 },
					ombroD = { 28, 0, 16 },
					cotoveloD = { 94, 0, 0 },
					ombroE = { 100, 0, 8 },
				}),
				"saida"
			),
			k(1.11, RECARGA),
			-- Gira o tronco para disparar com a direita antes da descarga com as duas mãos.
			k(
				1.26,
				achatar(DESCARGA, {
					cintura = { -20, -26, 5 },
					pescoco = { 0, 18, 0 },
					ombroE = { 28, 0, -16 },
					cotoveloE = { 94, 0, 0 },
					ombroD = { 100, 0, -8 },
				}),
				"saida"
			),
			k(1.41, RECARGA),
			k(
				1.56,
				J({
					raiz = { 0, 0.4, -0.4, 0, 0, 0 },
					cintura = { -30, 0, 0 },
					pescoco = { -6, 0, 0 },
					ombroD = { 96, 0, -8 },
					cotoveloD = { 0, 0, 0 },
					ombroE = { 96, 0, 8 },
					cotoveloE = { 0, 0, 0 },
					peD = { 0.3, 0.7 },
					peE = { 0.2, -0.5 },
				}),
				"saida"
			),
			k(
				1.82,
				J({
					raiz = { 0, -0.7, 0, 0, 0, 0 },
					cintura = { -18, 0, 0 },
					ombroD = { 80, 0, -4 },
					cotoveloD = { 8, 0, 0 },
					ombroE = { 80, 0, 4 },
					cotoveloE = { 8, 0, 0 },
					peD = { 0, 0.7 },
					peE = { 0, -0.7 },
					abrirD = { 14 },
					abrirE = { -14 },
				}),
				"entrada"
			),
			k(2.2, POSTURA),
		},
	},
	-- segurou a guarda: desliza para trás com o impacto
	defender = {
		duracao = 0.65,
		chaves = {
			k(0, GUARDA_J),
			k(
				0.08,
				achatar(GUARDA_J, {
					raiz = { 0, -0.75, 0.7, 6, 6, 0 },
					cintura = { 4, 0, 0 },
					peD = { 0, 0.9 },
					peE = { 0, 0.1 },
				}),
				"saida"
			),
			k(
				0.36,
				achatar(
					GUARDA_J,
					{ raiz = { 0, -0.65, 0.5, 0, 6, 0 }, peD = { 0, 0.9 }, peE = { 0, 0 } }
				)
			),
			k(0.65, POSTURA),
		},
	},
	atingido = {
		duracao = 0.55,
		chaves = {
			k(0, POSTURA),
			k(
				0.07,
				J({
					raiz = { 0, -0.25, 0.55, 8, 4, 0 },
					cintura = { 18, -14, 0 },
					pescoco = { 22, 0, 0 },
					ombroD = { 30, 0, 42 },
					cotoveloD = { 30, 0, 0 },
					ombroE = { 30, 0, -42 },
					cotoveloE = { 30, 0, 0 },
				}),
				"saida"
			),
			k(0.28, J({ raiz = { 0, -0.45, 0.3, 0, 10, 0 }, cintura = { -2, 0, 0 } })),
			k(0.55, POSTURA),
		},
	},
	-- arremessado para trás, cai sobre um joelho e levanta
	atingidoForte = {
		duracao = 1.05,
		chaves = {
			k(0, POSTURA),
			k(
				0.09,
				J({
					raiz = { 0, 0.6, 1.9, 18, 0, 0 },
					cintura = { 26, 0, 0 },
					pescoco = { 26, 0, 0 },
					ombroD = { 40, 0, 70 },
					cotoveloD = { 20, 0, 0 },
					ombroE = { 40, 0, -70 },
					cotoveloE = { 20, 0, 0 },
					peD = { 0.8, 1.5 },
					peE = { 1.0, 0.9 },
				}),
				"saida"
			),
			k(
				0.34,
				J({
					raiz = { 0, -1.05, 2.4, 0, 6, 0 },
					cintura = { -26, 0, 0 },
					pescoco = { -10, 0, 0 },
					ombroD = { 20, 0, 30 },
					cotoveloD = { 30, 0, 0 },
					ombroE = { 50, 0, -20 },
					cotoveloE = { 40, 0, 0 },
					peD = { 0, 3.2 },
					peE = { 0, 1.8 },
				}),
				"entrada"
			),
			k(
				0.7,
				J({
					raiz = { 0, -0.6, 1.2, 0, 10, 0 },
					cintura = { -14, 4, 0 },
					peD = { 0, 1.6 },
					peE = { 0, 0.6 },
				})
			),
			k(1.05, POSTURA),
		},
	},
	vitoria = {
		duracao = 0.6,
		segurar = true,
		chaves = {
			k(0, POSTURA),
			k(
				0.6,
				J({
					raiz = { 0, 0, 0, 0, 0, 0 },
					cintura = { 8, 0, 0 },
					pescoco = { 10, 0, 0 },
					ombroD = { 172, 0, 10 },
					cotoveloD = { 12, 0, 0 },
					ombroE = { 18, 0, -12 },
					cotoveloE = { 40, 0, 0 },
					peD = { 0, 0.3 },
					peE = { 0, -0.3 },
					abrirD = { 4 },
					abrirE = { -4 },
				}),
				"saida"
			),
		},
	},
	derrota = {
		duracao = 0.7,
		segurar = true,
		chaves = {
			k(0, POSTURA),
			k(0.2, J({ raiz = { 0, -0.3, 0.6, 10, 0, 0 }, cintura = { 16, 0, 0 } })),
			k(
				0.7,
				J({
					raiz = { 0, -1.3, 0, 0, 0, 0 },
					cintura = { -30, 0, 0 },
					pescoco = { -26, 0, 0 },
					ombroD = { 14, 0, 10 },
					cotoveloD = { 10, 0, 0 },
					ombroE = { 40, 0, -6 },
					cotoveloE = { 60, 0, 0 },
					peD = { 0, 1.1 },
					peE = { 0, -0.6 },
				}),
				"entrada"
			),
		},
	},
} :: { [string]: Clipe }

---------------------------------------------------------------------------------------------
-- Primeiro Soberano (peças da armadura; espaço do NPC, olhando para -Z)

local NEUTRO_S = achatar({}, {
	raiz = { 0, 0, 0, 0, 0, 0 },
	quadril = { 0, 0, 0 },
	torso = { 0, 0, 0 },
	cabeca = { 0, 0, 0 },
	bracoD = { 0, 0, 0 },
	antebracoD = { 0, 0, 0 },
	bracoE = { 0, 0, 0 },
	antebracoE = { 0, 0, 0 },
	peD = { 0, 0 },
	peE = { 0, 0 },
	-- só a entrada usa: 0..1 do trono até o ringue e 0..1 de sentado a em pé
	viagem = { 0 },
	erguer = { 1 },
})

-- Em pé com o espadão, a base um pouco baixa
local GUARDA_S = achatar(NEUTRO_S, {
	raiz = { 0, -0.25, 0, 0, 0, 0 },
	torso = { -6, 0, 0 },
	cabeca = { -6, 0, 0 },
	bracoD = { 37, 0, 18 },
	antebracoD = { 16, 0, 0 },
	bracoE = { 46, 0, -14 },
	antebracoE = { 18, 0, 0 },
	viagem = { 1 },
})

local function S(mudancas: { [string]: { number } }): Pose
	return achatar(GUARDA_S, mudancas)
end

-- Avisos do próximo golpe (mostrados enquanto o jogador escolhe)
local AVISO_PESADO = S({
	raiz = { 0, -0.35, 0, 0, 0, 0 },
	torso = { 8, 0, 0 },
	cabeca = { 4, 0, 0 },
	bracoD = { 150, 0, 8 },
	antebracoD = { -8, 0, 0 },
	bracoE = { 142, 0, -14 },
	antebracoE = { -4, 0, 0 },
	peD = { 0, 0.5 },
	peE = { 0, -0.5 },
})
local AVISO_INVESTIDA = S({
	raiz = { 0, -0.4, 0, 0, 0, 0 },
	torso = { -8, -16, 0 },
	cabeca = { -6, 14, 0 },
	bracoD = { 86, 0, -4 },
	antebracoD = { 0, 0, 0 },
	bracoE = { 30, 0, -30 },
	peD = { 0, 0.55 },
	peE = { 0, -0.55 },
})
-- A Fúria Tripla começa com a lâmina aberta ao lado, pronta para varrer o ringue.
local AVISO_TRINCA = S({
	raiz = { 0, -0.58, 0, 0, 0, 0 },
	torso = { -10, 27, 0 },
	cabeca = { -4, -22, 0 },
	bracoD = { -14, 0, 56 },
	antebracoD = { 38, 0, 0 },
	bracoE = { 58, 0, -18 },
	peD = { 0, 0.7 },
	peE = { 0, -0.65 },
})
local AVISO_BALUARTE = S({
	raiz = { 0, -0.5, 0, 0, 0, 0 },
	torso = { -4, 0, 0 },
	bracoD = { 72, 0, -24 },
	antebracoD = { 56, 0, 0 },
	bracoE = { 70, 0, 26 },
	antebracoE = { 56, 0, 0 },
	peD = { 0, 0.4 },
	peE = { 0, -0.4 },
})

local function laco(base: Pose, respira: { [string]: { number } }): Clipe
	return {
		duracao = 1.6,
		laco = true,
		chaves = { k(0, base), k(0.8, achatar(base, respira)), k(1.6, base) },
	}
end

Animacoes.SOBERANO = {
	espera = laco(GUARDA_S, { raiz = { 0, -0.32, 0, 0, 0, 0 }, torso = { -4, 0, 0 } }),
	avisoPesado = laco(AVISO_PESADO, { raiz = { 0, -0.42, 0, 0, 0, 0 }, bracoD = { 154, 0, 8 } }),
	avisoInvestida = laco(
		AVISO_INVESTIDA,
		{ raiz = { 0, -0.46, 0, 0, 0, 0 }, torso = { -10, -18, 0 } }
	),
	avisoTrinca = laco(AVISO_TRINCA, { torso = { -14, 32, 0 }, bracoD = { -18, 0, 60 } }),
	avisoBaluarte = laco(AVISO_BALUARTE, { raiz = { 0, -0.56, 0, 0, 0, 0 } }),
	-- levanta do trono, se agacha, salta até o ringue e pousa com o espadão no chão
	entrada = {
		duracao = 2.4,
		chaves = {
			k(0, achatar(NEUTRO_S, { erguer = { 0 }, bracoD = { 0, 0, 0 } })),
			k(
				0.34,
				achatar(NEUTRO_S, {
					erguer = { 1 },
					bracoD = { 37, 0, 18 },
					antebracoD = { 16, 0, 0 },
					bracoE = { 46, 0, -14 },
					antebracoE = { 18, 0, 0 },
				})
			),
			k(
				0.62,
				achatar(NEUTRO_S, {
					raiz = { 0, -0.95, 0, 0, 0, 0 },
					torso = { -22, 0, 0 },
					cabeca = { 10, 0, 0 },
					bracoD = { -32, 0, 26 },
					antebracoD = { 20, 0, 0 },
					bracoE = { -32, 0, -26 },
					antebracoE = { 20, 0, 0 },
					peD = { 0, 0.35 },
					peE = { 0, -0.35 },
				})
			),
			k(
				0.76,
				achatar(NEUTRO_S, {
					raiz = { 0, 0.4, 0, 0, 0, 0 },
					torso = { -6, 0, 0 },
					bracoD = { 120, 0, 20 },
					antebracoD = { 10, 0, 0 },
					bracoE = { 110, 0, -20 },
					antebracoE = { 10, 0, 0 },
					peD = { 0.2, 0.4 },
					peE = { 0.1, -0.3 },
					viagem = { 0.03 },
				})
			),
			k(
				1.1,
				achatar(NEUTRO_S, {
					raiz = { 0, 6.2, 0, 0, 0, 0 },
					torso = { -14, 0, 0 },
					bracoD = { 150, 0, 10 },
					antebracoD = { -6, 0, 0 },
					bracoE = { 70, 0, -50 },
					antebracoE = { 10, 0, 0 },
					peD = { 7.6, 0.2 },
					peE = { 7.2, -0.6 },
					viagem = { 0.5 },
				}),
				"saida"
			),
			k(
				1.5,
				achatar(NEUTRO_S, {
					raiz = { 0, -1.15, 0, 0, 0, 0 },
					torso = { -30, 0, 0 },
					cabeca = { 12, 0, 0 },
					bracoD = { 30, 0, 8 },
					antebracoD = { 0, 0, 0 },
					bracoE = { 40, 0, -50 },
					antebracoE = { 20, 0, 0 },
					peD = { 0, 0.7 },
					peE = { 0, -0.7 },
					viagem = { 1 },
				}),
				"entrada"
			),
			k(
				1.9,
				S({ raiz = { 0, -0.7, 0, 0, 0, 0 }, torso = { -16, 0, 0 }, bracoD = { 34, 0, 14 } })
			),
			k(2.4, GUARDA_S),
		},
	},
	-- se torce, arranca e corta de lado
	investida = {
		duracao = 1.02,
		chaves = {
			k(0, AVISO_INVESTIDA),
			k(
				0.2,
				S({
					raiz = { 0, -0.65, 0, 0, 0, 0 },
					torso = { -10, 34, 0 },
					cabeca = { -6, -26, 0 },
					bracoD = { -20, 0, 46 },
					antebracoD = { 40, 0, 0 },
					bracoE = { 60, 0, -20 },
					peD = { 0, 0.55 },
					peE = { 0, -0.55 },
				})
			),
			k(
				0.32,
				S({
					raiz = { 0, -0.3, -3.2, 0, 0, 0 },
					torso = { -18, 10, 0 },
					bracoD = { -10, 0, 50 },
					antebracoD = { 40, 0, 0 },
					bracoE = { 50, 0, -26 },
					peD = { 0, -1.6 },
					peE = { 1.3, -3.9 },
				})
			),
			k(
				0.42,
				S({
					raiz = { 0, -0.85, -6.3, 0, 0, 0 },
					torso = { -26, -32, 0 },
					cabeca = { -4, 24, 0 },
					bracoD = { 88, 0, -36 },
					antebracoD = { 4, 0, 0 },
					bracoE = { 18, 0, -42 },
					antebracoE = { 10, 0, 0 },
					peD = { 0, -4.7 },
					peE = { 0, -7.7 },
				}),
				"saida"
			),
			k(
				0.62,
				S({
					raiz = { 0, -0.8, -6.3, 0, 0, 0 },
					torso = { -22, -30, 0 },
					bracoD = { 82, 0, -36 },
					antebracoD = { 6, 0, 0 },
					bracoE = { 18, 0, -42 },
					peD = { 0, -4.7 },
					peE = { 0, -7.7 },
				})
			),
			k(
				0.82,
				S({
					raiz = { 0, -0.2, -2.8, 0, 0, 0 },
					torso = { -8, -8, 0 },
					peD = { 0, -2.0 },
					peE = { 1.1, -3.6 },
				})
			),
			k(1.02, GUARDA_S),
		},
	},
	-- espadão acima da cabeça, salto e golpe que racha o chão
	pesado = {
		duracao = 1.57,
		chaves = {
			k(0, AVISO_PESADO),
			k(
				0.36,
				S({
					raiz = { 0, -1.05, 0, 0, 0, 0 },
					torso = { 12, 0, 0 },
					cabeca = { 6, 0, 0 },
					bracoD = { 166, 0, 6 },
					antebracoD = { -10, 0, 0 },
					bracoE = { 160, 0, -12 },
					antebracoE = { -6, 0, 0 },
					peD = { 0, 0.55 },
					peE = { 0, -0.55 },
				})
			),
			k(
				0.54,
				S({
					raiz = { 0, 3.4, -4.2, 0, 0, 0 },
					torso = { 6, 0, 0 },
					bracoD = { 172, 0, 4 },
					antebracoD = { -12, 0, 0 },
					bracoE = { 166, 0, -10 },
					peD = { 4.4, -3.8 },
					peE = { 4.0, -4.8 },
				}),
				"saida"
			),
			k(
				0.72,
				S({
					raiz = { 0, -1.1, -7.7, 0, 0, 0 },
					torso = { -42, 0, 0 },
					cabeca = { 14, 0, 0 },
					bracoD = { 42, 0, 2 },
					antebracoD = { 0, 0, 0 },
					bracoE = { 44, 0, -4 },
					antebracoE = { 0, 0, 0 },
					peD = { 0, -6.8 },
					peE = { 0, -8.6 },
				}),
				"entrada"
			),
			k(
				0.98,
				S({
					raiz = { 0, -1.0, -7.7, 0, 0, 0 },
					torso = { -38, 0, 0 },
					bracoD = { 40, 0, 4 },
					antebracoD = { 2, 0, 0 },
					bracoE = { 42, 0, -6 },
					peD = { 0, -6.8 },
					peE = { 0, -8.6 },
				})
			),
			k(
				1.25,
				S({
					raiz = { 0, -0.2, -3.6, 0, 0, 0 },
					torso = { -10, 0, 0 },
					peD = { 1.1, -4.0 },
					peE = { 0, -4.2 },
				})
			),
			k(1.57, GUARDA_S),
		},
	},
	baluarte = {
		duracao = 0.86,
		chaves = {
			k(0, AVISO_BALUARTE),
			k(
				0.22,
				S({
					raiz = { 0, -0.95, 0, 0, 0, 0 },
					torso = { -8, 0, 0 },
					cabeca = { -8, 0, 0 },
					bracoD = { 80, 0, -30 },
					antebracoD = { 62, 0, 0 },
					bracoE = { 80, 0, 32 },
					antebracoE = { 62, 0, 0 },
					peD = { 0, 0.7 },
					peE = { 0, -0.75 },
				}),
				"saida"
			),
			k(
				0.6,
				S({
					raiz = { 0, -0.9, 0, 0, 0, 0 },
					torso = { -8, 0, 0 },
					bracoD = { 78, 0, -30 },
					antebracoD = { 60, 0, 0 },
					bracoE = { 78, 0, 32 },
					antebracoE = { 60, 0, 0 },
					peD = { 0, 0.7 },
					peE = { 0, -0.75 },
				})
			),
			k(0.86, GUARDA_S),
		},
	},
	atingido = {
		duracao = 0.5,
		chaves = {
			k(0, GUARDA_S),
			k(
				0.06,
				S({
					raiz = { 0, -0.35, 0.6, 0, 0, 0 },
					torso = { 14, -10, 0 },
					cabeca = { 16, 0, 0 },
					bracoD = { 30, 0, 30 },
					bracoE = { 40, 0, -26 },
					peD = { 0, 0.6 },
					peE = { 0, 0 },
				}),
				"saida"
			),
			k(0.5, GUARDA_S),
		},
	},
	atingidoForte = {
		duracao = 0.95,
		chaves = {
			k(0, GUARDA_S),
			k(
				0.08,
				S({
					raiz = { 0, 0.3, 1.8, 0, 0, 0 },
					torso = { 22, -14, 6 },
					cabeca = { 22, 0, 0 },
					bracoD = { 30, 0, 56 },
					antebracoD = { 20, 0, 0 },
					bracoE = { 30, 0, -56 },
					peD = { 0, 1.2 },
					peE = { 1.2, 0.6 },
				}),
				"saida"
			),
			k(
				0.36,
				S({
					raiz = { 0, -0.8, 2.3, 0, 0, 0 },
					torso = { -14, 0, 0 },
					bracoD = { 40, 0, 20 },
					peD = { 0, 2.8 },
					peE = { 0, 1.6 },
				}),
				"entrada"
			),
			k(0.95, GUARDA_S),
		},
	},
	derrota = {
		duracao = 1.2,
		segurar = true,
		chaves = {
			k(0, GUARDA_S),
			k(
				0.25,
				S({
					raiz = { 0, -0.3, 1.0, 0, 0, 0 },
					torso = { 20, 0, 0 },
					cabeca = { 18, 0, 0 },
					peD = { 0, 1.1 },
				})
			),
			k(
				0.75,
				S({
					raiz = { 0, -1.7, 0.6, 0, 0, 0 },
					torso = { -26, 0, 8 },
					cabeca = { -26, 0, 0 },
					bracoD = { 30, 0, 10 },
					antebracoD = { 50, 0, 0 },
					bracoE = { -10, 0, -10 },
					antebracoE = { 10, 0, 0 },
					peD = { 0, 1.8 },
					peE = { 0, -0.4 },
				}),
				"entrada"
			),
			k(
				1.2,
				S({
					raiz = { 0, -1.65, 0.6, 0, 0, 0 },
					torso = { -24, 0, 8 },
					cabeca = { -28, 0, 0 },
					bracoD = { 30, 0, 10 },
					antebracoD = { 50, 0, 0 },
					bracoE = { -10, 0, -10 },
					antebracoE = { 10, 0, 0 },
					peD = { 0, 1.8 },
					peE = { 0, -0.4 },
				})
			),
		},
	},
	vitoria = {
		duracao = 0.8,
		segurar = true,
		chaves = {
			k(0, GUARDA_S),
			k(
				0.8,
				S({
					raiz = { 0, 0, 0, 0, 0, 0 },
					torso = { 6, 0, 0 },
					cabeca = { 10, 0, 0 },
					bracoD = { 172, 0, 6 },
					antebracoD = { 4, 0, 0 },
					bracoE = { 20, 0, -18 },
				}),
				"saida"
			),
		},
	},
} :: { [string]: Clipe }

---------------------------------------------------------------------------------------------
-- Combate reativo (Dados/Duelo): defesas, contra-ataque, concentrar e Ruptura

-- Esquiva: passo rápido para o lado e para trás, o corpo inclinado
Animacoes.JOGADOR.esquiva = {
	duracao = 0.55,
	chaves = {
		k(0, POSTURA),
		k(
			0.08,
			J({
				raiz = { 1.7, -0.7, 0.5, 0, 18, 0 },
				cintura = { 4, 6, -20 },
				pescoco = { 0, -10, 10 },
				ombroD = { 72, 0, 14 },
				cotoveloD = { 104, 0, 0 },
				ombroE = { 76, 0, -12 },
				cotoveloE = { 100, 0, 0 },
				peD = { 0, 0.9 },
				peE = { 0, -0.2 },
				abrirD = { 14 },
				abrirE = { -4 },
			}),
			"saida"
		),
		k(
			0.3,
			J({
				raiz = { 1.5, -0.65, 0.45, 0, 16, 0 },
				cintura = { 2, 6, -14 },
				ombroD = { 66, 0, 14 },
				cotoveloD = { 100, 0, 0 },
				ombroE = { 70, 0, -12 },
				cotoveloE = { 96, 0, 0 },
				peD = { 0, 0.9 },
				peE = { 0, -0.2 },
				abrirD = { 12 },
			})
		),
		k(0.55, POSTURA, "entrada"),
	},
}

-- Aparar: os antebraços batem de frente no golpe e recuam um pouco
Animacoes.JOGADOR.aparar = {
	duracao = 0.45,
	chaves = {
		k(0, POSTURA),
		k(
			0.05,
			J({
				raiz = { 0, -0.55, -0.2, 0, 0, 0 },
				cintura = { -14, 0, 0 },
				pescoco = { -6, 0, 0 },
				ombroD = { 104, 0, -24 },
				cotoveloD = { 46, 0, 0 },
				ombroE = { 98, 0, 30 },
				cotoveloE = { 52, 0, 0 },
				peD = { 0, 0.8 },
				peE = { 0, -0.6 },
			}),
			"saida"
		),
		k(
			0.18,
			J({
				raiz = { 0, -0.6, 0.25, 4, 0, 0 },
				cintura = { -6, 0, 0 },
				ombroD = { 96, 0, -30 },
				cotoveloD = { 58, 0, 0 },
				ombroE = { 92, 0, 34 },
				cotoveloE = { 60, 0, 0 },
				peD = { 0, 0.9 },
				peE = { 0, -0.5 },
			})
		),
		k(0.45, POSTURA),
	},
}

-- Contra-ataque: depois de aparar tudo, arranca e acerta um gancho (acerto aos 0,3 s)
Animacoes.JOGADOR.contra = {
	duracao = 0.8,
	chaves = {
		k(0, GUARDA_J),
		k(
			0.12,
			J({
				raiz = { 0, -0.6, 0, 0, 30, 0 },
				cintura = { -24, 24, 0 },
				ombroD = { -30, 0, 30 },
				cotoveloD = { 110, 0, 0 },
				ombroE = { 70, 0, -10 },
				peD = { 0.6, -0.4 },
				peE = { 0, 0.6 },
			})
		),
		k(
			0.3,
			J({
				raiz = { 0, 0.2, 0, -6, -20, 0 },
				cintura = { -20, -34, 0 },
				pescoco = { 6, 16, 0 },
				ombroD = { 150, 0, 10 },
				cotoveloD = { 30, 0, 0 },
				ombroE = { 30, 0, -30 },
				cotoveloE = { 100, 0, 0 },
				peD = { 0.5, 0.6 },
				peE = { 0, -1.0 },
			}),
			"saida"
		),
		k(
			0.5,
			J({
				raiz = { 0, 0.55, 0, 10, 8, 0 },
				ombroD = { 30, 0, 30 },
				ombroE = { 30, 0, -30 },
				peD = { 1.0, 0.5 },
				peE = { 1.1, -0.1 },
			}),
			"saida"
		),
		k(0.64, J({ raiz = { 0, -0.6, 0, 0, 14, 0 }, cintura = { -12, 8, 0 } }), "entrada"),
		k(0.8, POSTURA),
	},
}

-- Concentrar: junta as mãos no peito, respira e abre os braços com a aura
Animacoes.JOGADOR.concentrar = {
	duracao = 1.1,
	chaves = {
		k(0, POSTURA),
		k(
			0.3,
			J({
				raiz = { 0, -0.8, 0, 0, 0, 0 },
				cintura = { 10, 0, 0 },
				pescoco = { 16, 0, 0 },
				ombroD = { 60, 0, -36 },
				cotoveloD = { 110, 0, 0 },
				ombroE = { 60, 0, 36 },
				cotoveloE = { 110, 0, 0 },
				peD = { 0, 0.5 },
				peE = { 0, -0.5 },
			})
		),
		k(
			0.75,
			J({
				raiz = { 0, 0.1, 0, 0, 0, 0 },
				cintura = { -6, 0, 0 },
				pescoco = { -10, 0, 0 },
				ombroD = { 40, 0, 70 },
				cotoveloD = { 10, 0, 0 },
				ombroE = { 40, 0, -70 },
				cotoveloE = { 10, 0, 0 },
				peD = { 0, 0.5 },
				peE = { 0, -0.5 },
				abrirD = { 12 },
				abrirE = { -12 },
			}),
			"saida"
		),
		k(1.1, POSTURA),
	},
}

-- Rompido: curvado e tonto até a próxima vez
Animacoes.JOGADOR.rompido = {
	duracao = 0.35,
	segurar = true,
	chaves = {
		k(0, POSTURA),
		k(
			0.35,
			J({
				raiz = { 0, -1.0, 0.4, 0, 0, 6 },
				cintura = { 34, 0, 8 },
				pescoco = { 26, 0, 12 },
				ombroD = { 14, 0, 18 },
				cotoveloD = { 20, 0, 0 },
				ombroE = { 10, 0, -18 },
				cotoveloE = { 24, 0, 0 },
				peD = { 0, 0.6 },
				peE = { 0, -0.4 },
			}),
			"entrada"
		),
	},
}

-- Fúria Tripla: arranca e corta de um lado (0,5 s), do outro (0,9 s) e de cima (1,3 s)
Animacoes.SOBERANO.trinca = {
	duracao = 2.1,
	chaves = {
		k(0, AVISO_TRINCA),
		k(
			0.25,
			S({
				raiz = { 0, -0.5, -3.0, 0, 0, 0 },
				torso = { -14, 30, 0 },
				cabeca = { -6, -24, 0 },
				bracoD = { -16, 0, 50 },
				antebracoD = { 40, 0, 0 },
				bracoE = { 56, 0, -22 },
				peD = { 0, -1.6 },
				peE = { 1.2, -3.8 },
			})
		),
		k(
			0.5,
			S({
				raiz = { 0, -0.85, -6.3, 0, 0, 0 },
				torso = { -26, -32, 0 },
				cabeca = { -4, 24, 0 },
				bracoD = { 88, 0, -36 },
				antebracoD = { 4, 0, 0 },
				bracoE = { 18, 0, -42 },
				peD = { 0, -4.7 },
				peE = { 0, -7.7 },
			}),
			"saida"
		),
		k(
			0.7,
			S({
				raiz = { 0, -0.7, -6.3, 0, 0, 0 },
				torso = { -18, -38, 0 },
				cabeca = { -4, 26, 0 },
				bracoD = { 96, 0, -45 },
				antebracoD = { 36, 0, 0 },
				bracoE = { 50, 0, -20 },
				peD = { 0, -4.7 },
				peE = { 0, -7.7 },
			})
		),
		k(
			0.9,
			S({
				raiz = { 0, -0.85, -6.5, 0, 0, 0 },
				torso = { -24, 32, 0 },
				cabeca = { -4, -22, 0 },
				bracoD = { 52, 0, 62 },
				antebracoD = { 6, 0, 0 },
				bracoE = { 20, 0, -40 },
				peD = { 0, -4.9 },
				peE = { 0, -7.9 },
			}),
			"saida"
		),
		k(
			1.1,
			S({
				raiz = { 0, -0.4, -6.4, 0, 0, 0 },
				torso = { 10, 0, 0 },
				cabeca = { 6, 0, 0 },
				bracoD = { 164, 0, 6 },
				antebracoD = { -10, 0, 0 },
				bracoE = { 156, 0, -12 },
				peD = { 0, -4.8 },
				peE = { 0, -7.8 },
			})
		),
		k(
			1.3,
			S({
				raiz = { 0, -1.1, -7.2, 0, 0, 0 },
				torso = { -40, 0, 0 },
				cabeca = { 12, 0, 0 },
				bracoD = { 42, 0, 2 },
				antebracoD = { 0, 0, 0 },
				bracoE = { 44, 0, -4 },
				peD = { 0, -6.4 },
				peE = { 0, -8.2 },
			}),
			"entrada"
		),
		k(
			1.6,
			S({
				raiz = { 0, -1.0, -7.2, 0, 0, 0 },
				torso = { -36, 0, 0 },
				bracoD = { 40, 0, 4 },
				bracoE = { 42, 0, -6 },
				peD = { 0, -6.4 },
				peE = { 0, -8.2 },
			})
		),
		k(1.85, S({ raiz = { 0, -0.2, -3.2, 0, 0, 0 }, peD = { 1.1, -3.6 }, peE = { 0, -3.8 } })),
		k(2.1, GUARDA_S),
	},
}

-- Lâmina Hesitante: ameaça o golpe pesado, para no meio (a finta), e ataca duas vezes depois
Animacoes.SOBERANO.finta = {
	duracao = 2.3,
	chaves = {
		k(0, AVISO_PESADO),
		k(
			0.35,
			S({
				raiz = { 0, -1.0, 0, 0, 0, 0 },
				torso = { 12, 0, 0 },
				bracoD = { 166, 0, 6 },
				antebracoD = { -10, 0, 0 },
				bracoE = { 160, 0, -12 },
				peD = { 0, 0.55 },
				peE = { 0, -0.55 },
			})
		),
		-- a finta: avança um passo como se fosse descer a espada... e segura
		k(
			0.58,
			S({
				raiz = { 0, -0.5, -2.2, 0, 0, 0 },
				torso = { -10, 0, 0 },
				bracoD = { 120, 0, 6 },
				antebracoD = { -4, 0, 0 },
				bracoE = { 116, 0, -12 },
				peD = { 0, -1.4 },
				peE = { 0, -3.0 },
			})
		),
		k(
			0.85,
			S({
				raiz = { 0, -0.55, -2.0, 0, 0, 0 },
				torso = { -4, 14, 0 },
				cabeca = { -4, -10, 0 },
				bracoD = { -14, 0, 50 },
				antebracoD = { 40, 0, 0 },
				bracoE = { 56, 0, -22 },
				peD = { 0, -1.4 },
				peE = { 0, -3.0 },
			})
		),
		k(
			1.0,
			S({
				raiz = { 0, -0.6, -4.0, 0, 0, 0 },
				torso = { -12, 32, 0 },
				bracoD = { -16, 0, 52 },
				antebracoD = { 40, 0, 0 },
				peD = { 0, -2.6 },
				peE = { 1.0, -4.6 },
			})
		),
		k(
			1.15,
			S({
				raiz = { 0, -0.85, -6.3, 0, 0, 0 },
				torso = { -26, -32, 0 },
				cabeca = { -4, 24, 0 },
				bracoD = { 88, 0, -36 },
				antebracoD = { 4, 0, 0 },
				bracoE = { 18, 0, -42 },
				peD = { 0, -4.7 },
				peE = { 0, -7.7 },
			}),
			"saida"
		),
		k(
			1.3,
			S({
				raiz = { 0, -0.75, -6.3, 0, 0, 0 },
				torso = { -18, 34, 0 },
				bracoD = { -10, 0, 56 },
				antebracoD = { 36, 0, 0 },
				peD = { 0, -4.7 },
				peE = { 0, -7.7 },
			})
		),
		k(
			1.45,
			S({
				raiz = { 0, -0.85, -6.5, 0, 0, 0 },
				torso = { -24, -30, 0 },
				bracoD = { 92, 0, -30 },
				antebracoD = { 6, 0, 0 },
				bracoE = { 20, 0, -40 },
				peD = { 0, -4.9 },
				peE = { 0, -7.9 },
			}),
			"saida"
		),
		k(
			1.75,
			S({
				raiz = { 0, -0.8, -6.4, 0, 0, 0 },
				torso = { -20, -26, 0 },
				peD = { 0, -4.8 },
				peE = { 0, -7.8 },
			})
		),
		k(2.05, S({ raiz = { 0, -0.2, -2.8, 0, 0, 0 }, peD = { 1.1, -3.4 }, peE = { 0, -3.6 } })),
		k(2.3, GUARDA_S),
	},
}

-- Rompido: ajoelha com a espada fincada, tonto, até a próxima vez
Animacoes.SOBERANO.rompido = {
	duracao = 0.5,
	segurar = true,
	chaves = {
		k(0, GUARDA_S),
		k(
			0.5,
			S({
				raiz = { 0, -1.3, 0.5, 0, 0, 4 },
				torso = { -22, 0, 8 },
				cabeca = { -24, 10, 0 },
				bracoD = { 34, 0, 12 },
				antebracoD = { 44, 0, 0 },
				bracoE = { 0, 0, -14 },
				antebracoE = { 14, 0, 0 },
				peD = { 0, 1.4 },
				peE = { 0, -0.4 },
			}),
			"entrada"
		),
	},
}

-- Instantes (em segundos do clipe) em que algo bate no chão: o cliente solta a onda de poeira
Animacoes.POUSOS = {
	entrada = { 1.5 },
	pesado = { 0.72 },
	trinca = { 1.3 },
} :: { [string]: { number } }

---------------------------------------------------------------------------------------------
-- Amostragem

local function suave(x: number): number
	return x * x * (3 - 2 * x)
end

local function curvar(f: number, curva: string?): number
	if curva == "linear" then
		return f
	elseif curva == "saida" then -- rápido no começo, freia no fim
		return 1 - (1 - f) * (1 - f)
	elseif curva == "entrada" then -- acelera até o fim (queda)
		return f * f
	end
	return suave(f)
end

-- Pose do clipe no instante t (segundos). Fora da duração: a última pose (ou o laço).
function Animacoes.amostrar(clipe: Clipe, t: number): Pose
	local chaves = clipe.chaves
	if clipe.laco then
		t %= clipe.duracao
	end
	if t <= chaves[1].t then
		return table.clone(chaves[1].pose)
	end
	for i = 1, #chaves - 1 do
		local a, b = chaves[i], chaves[i + 1]
		if t <= b.t then
			local f = curvar((t - a.t) / math.max(b.t - a.t, 1e-6), b.curva)
			local p: Pose = {}
			for nome, va in a.pose do
				local vb = b.pose[nome] or va
				p[nome] = va + (vb - va) * f
			end
			for nome, vb in b.pose do
				if p[nome] == nil then
					p[nome] = vb
				end
			end
			return p
		end
	end
	return table.clone(chaves[#chaves].pose)
end

-- Mistura duas poses (peso 0 = a, 1 = b)
function Animacoes.misturar(a: Pose, b: Pose, peso: number): Pose
	local p = table.clone(a)
	for nome, vb in b do
		local va = a[nome] or vb
		p[nome] = va + (vb - va) * peso
	end
	return p
end

---------------------------------------------------------------------------------------------
-- Cinemática inversa das pernas (no plano lateral: altura y e frente z)

export type Perna = { quadril: { number }, joelho: { number }, tornozelo: { number } }

local function angulo(y: number, z: number): number
	return math.atan2(z, y)
end

local function diferenca(a: number, b: number): number
	local d = (a - b) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end

-- Ângulos (radianos, giro em X) da coxa e da canela para o tornozelo ir de onde está em
-- repouso até repouso + (0, altura, frente) - deslocamento da raiz (dy, dz).
-- O joelho dobra sempre para a frente (-Z).
local function resolver(
	perna: Perna,
	altura: number,
	frente: number,
	dy: number,
	dz: number
): (number, number)
	local q, j, t = perna.quadril, perna.joelho, perna.tornozelo
	local uy, uz = j[2] - q[2], j[3] - q[3]
	local vy, vz = t[2] - j[2], t[3] - j[3]
	local l1 = math.sqrt(uy * uy + uz * uz)
	local l2 = math.sqrt(vy * vy + vz * vz)
	-- alvo do tornozelo em relação ao quadril, já descontando quanto a raiz andou
	local ay = t[2] + altura - dy - q[2]
	local az = t[3] + frente - dz - q[3]
	local d = math.sqrt(ay * ay + az * az)
	local alcance = (l1 + l2) * 0.99995
	if d > alcance then
		ay *= alcance / d
		az *= alcance / d
		d = alcance
	end
	d = math.max(d, math.abs(l1 - l2) + 1e-3)
	-- ângulo no quadril entre a linha quadril→tornozelo e a coxa (lei dos cossenos)
	local cosA = math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
	local base = angulo(ay, az)
	-- duas soluções: fica a que põe o joelho do lado da frente (-Z) da linha quadril→tornozelo
	local abertura = math.acos(cosA)
	local coxa = base - abertura
	local function lado(ang: number): number
		return ay * math.sin(ang) - az * math.cos(ang)
	end
	if lado(coxa) < lado(base + abertura) then
		coxa = base + abertura
	end
	local jy, jz = math.cos(coxa) * l1, math.sin(coxa) * l1
	local giroCoxa = diferenca(coxa, angulo(uy, uz))
	local giroCanela = diferenca(angulo(ay - jy, az - jz) - angulo(vy, vz) - giroCoxa, 0)
	return giroCoxa, giroCanela
end

-- O repouso também passa pelo mesmo cálculo (a perna reta encosta no limite do alcance e o
-- modelo pode ter o joelho levemente para trás): subtrair esse resultado deixa o repouso em zero.
local repouso: { [Perna]: { number } } = {}
function Animacoes.perna(
	perna: Perna,
	altura: number,
	frente: number,
	dy: number,
	dz: number
): (number, number)
	local r = repouso[perna]
	if not r then
		local c0, j0 = resolver(perna, 0, 0, 0, 0)
		r = { c0, j0 }
		repouso[perna] = r
	end
	local c, j = resolver(perna, altura, frente, dy, dz)
	return c - r[1], j - r[2]
end

-- Perna do R15 em repouso (quadril na origem, perna reta para baixo)
Animacoes.PERNA_R15 = {
	quadril = { 0, 0, 0 },
	joelho = { 0, -1.2, 0 },
	tornozelo = { 0, -2.4, 0 },
} :: Perna

-- Completa a pose com os ângulos das pernas (graus): quadrilD/joelhoD, quadrilE/joelhoE
function Animacoes.resolverPernas(pose: Pose, dir: Perna, esq: Perna): Pose
	local dy, dz = pose.raiz2 or 0, pose.raiz3 or 0
	local c, j = Animacoes.perna(dir, pose.peD1 or 0, pose.peD2 or 0, dy, dz)
	pose.quadrilD1, pose.joelhoD1 = math.deg(c), math.deg(j)
	c, j = Animacoes.perna(esq, pose.peE1 or 0, pose.peE2 or 0, dy, dz)
	pose.quadrilE1, pose.joelhoE1 = math.deg(c), math.deg(j)
	return pose
end

return Animacoes
