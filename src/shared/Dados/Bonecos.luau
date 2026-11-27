-- NPCs no estilo dos bonecos do Roblox (só dados e regras puras, testadas em testes/logica.luau).
--
-- Engenharia reversa dos NPCs dos jogos mais jogados (Blox Fruits, simuladores, RNGs): quase todos
-- usam o MESMO corpo de boneco dos jogadores (R6 clássico em blocos: tronco 2×2×1, braços e pernas
-- 1×2×1, cabeça arredondada), com rosto simples, cabelo e um ou dois acessórios marcantes. Chefes
-- são o mesmo boneco em escala gigante. Isso faz o NPC "parecer do Roblox" ao lado dos jogadores.
--
-- Aqui ficam as proporções, a aparência de cada NPC e as poses procedurais (sem animações
-- enviadas). O cliente (Mundo/Boneco) monta as peças com Parts comuns + malhas do Blender só para a
-- cabeça arredondada e os cabelos.
local Bonecos = {}

-- ============================================================ corpo (studs, escala 1, pés em y = 0)

export type Membro = {
	nome: string,
	tamanho: { number }, -- x, y, z
	junta: { number }, -- ponto de giro no corpo (pés em y = 0, frente = -z)
	centro: { number }, -- centro da peça relativo à junta
	cor: "pele" | "camisa" | "calca",
}

Bonecos.MEMBROS = {
	{
		nome = "pernaD",
		tamanho = { 1, 2, 1 },
		junta = { 0.5, 2, 0 },
		centro = { 0, -1, 0 },
		cor = "calca",
	},
	{
		nome = "pernaE",
		tamanho = { 1, 2, 1 },
		junta = { -0.5, 2, 0 },
		centro = { 0, -1, 0 },
		cor = "calca",
	},
	{
		nome = "tronco",
		tamanho = { 2, 2, 1 },
		junta = { 0, 2, 0 },
		centro = { 0, 1, 0 },
		cor = "camisa",
	},
	{
		nome = "bracoD",
		tamanho = { 1, 2, 1 },
		junta = { 1.5, 3.5, 0 },
		centro = { 0, -0.5, 0 },
		cor = "pele",
	},
	{
		nome = "bracoE",
		tamanho = { 1, 2, 1 },
		junta = { -1.5, 3.5, 0 },
		centro = { 0, -0.5, 0 },
		cor = "pele",
	},
} :: { Membro }

-- A cabeça é a malha "boneco_cabeca" (cubo arredondado 1.2) com o centro aqui
Bonecos.CABECA = { junta = { 0, 4, 0 }, centro = { 0, 0.6, 0 }, tamanho = 1.2 }
Bonecos.ALTURA = 5.2

-- ============================================================ aparência de cada NPC

export type Rosto = {
	olhos: "redondos" | "aneis" | "felizes", -- aneis = olhos com anel dourado (Gear 5)
	boca: "sorriso" | "sorrisao" | "aberta",
	bochechas: boolean?,
	corOlhos: string?,
	corSobrancelha: string?,
	cilios: boolean?,
}
export type Acessorio = {
	malha: string?, -- malha do Blender presa na cabeça (cabelo)
	material: string?,
	peca: string?, -- peça feita de Parts no cliente ("faixa", "gola", "auréola"...)
	cor: string?,
}
export type Definicao = {
	nome: string,
	escala: number,
	pele: string,
	camisa: string,
	calca: string,
	rosto: Rosto,
	acessorios: { Acessorio },
	-- Detalhamento (como nos jogos grandes):
	corpoMalha: boolean?, -- tronco/braços/pernas com a roupa "pintada" do Blender (boneco_<id>_<membro>)
	efeitos: { string }?, -- partículas e luz: "vapor", "faiscas", "luz"
	placa: { titulo: string, subtitulo: string?, cor: string }?, -- nome flutuando
	estatua: boolean?, -- estátua: corpo de blocos no material abaixo (sem roupa pintada)
	material: string?, -- material do corpo e da cabeça (ex.: "Marble")
}

-- O que cada NPC detalhado precisa ter (testado): roupa pintada, rosto com sobrancelha e brilho
-- nos olhos, cabelo e pelo menos 2 acessórios.
Bonecos.MEMBROS_MALHA = { "tronco", "bracoD", "bracoE", "pernaD", "pernaE" }
function Bonecos.malhaDoMembro(id: string, membro: string): string
	return "boneco_" .. id .. "_" .. membro
end

Bonecos.NPCS = {
	-- Chefe do evento Despertar do Sol: um boneco gigante todo branco, cabelo de nuvem, olhos com
	-- anéis dourados, sorrisão e auréola de sol (personagem original).
	tita = {
		nome = "Titã de Borracha",
		escala = 5,
		pele = "FFF6E8",
		camisa = "FFFFFF",
		calca = "FFFFFF",
		rosto = {
			olhos = "aneis",
			boca = "sorrisao",
			bochechas = true,
			corOlhos = "FFD54A",
			corSobrancelha = "C9B79A",
		},
		corpoMalha = true,
		efeitos = { "vapor", "faiscas", "luz" },
		placa = { titulo = "TITÃ DE BORRACHA", subtitulo = "Chefe do Evento", cor = "FFD54A" },
		acessorios = {
			{ malha = "boneco_cabelo_nuvem", material = "SmoothPlastic" },
			{ peca = "faixa", cor = "FFB52E" },
			{ peca = "gola", cor = "FFFFFF" },
			{ peca = "aureola", cor = "FFD54A" },
		},
	},
	-- Guia do tutorial: menina guardiã com cabelo lilás comprido e uma estrela flutuando.
	lume = {
		nome = "Lume",
		escala = 1,
		pele = "FFDCC4",
		camisa = "C0ADFF",
		calca = "F7F2EC",
		rosto = {
			olhos = "redondos",
			boca = "sorriso",
			bochechas = true,
			corOlhos = "5B3FB0",
			corSobrancelha = "6A52B8",
			cilios = true,
		},
		corpoMalha = true,
		acessorios = {
			{ malha = "boneco_cabelo_longo", material = "SmoothPlastic" },
			{ peca = "capa", cor = "8F7BE0" },
			{ peca = "estrela", cor = "B7FFD9" },
		},
	},
	-- Estátua da Gear 5 na praça (Dados/PrimeirosMinutos): mármore branco com detalhes dourados,
	-- cabelo de nuvem e auréola de sol, braço erguido em vitória. Mostra o prêmio do evento.
	estatua = {
		nome = "Estátua da Gear 5",
		escala = 2.2,
		pele = "F2EEE6",
		camisa = "F7F4EE",
		calca = "ECE6DA",
		rosto = {
			olhos = "aneis",
			boca = "sorrisao",
			corOlhos = "FFD54A",
			corSobrancelha = "D8CFBF",
		},
		estatua = true,
		material = "Marble",
		efeitos = { "faiscas", "luz" },
		acessorios = {
			{ malha = "boneco_cabelo_nuvem", material = "SmoothPlastic" },
			{ peca = "faixa", cor = "FFC23A" },
			{ peca = "gola", cor = "FFFFFF" },
			{ peca = "aureola", cor = "FFD54A" },
		},
	},
} :: { [string]: Definicao }

-- ============================================================ poses procedurais

export type Pose = {
	pescoco: { number }, -- ângulos x, y, z (radianos)
	tronco: { number },
	bracoD: { number },
	bracoE: { number },
	pernaD: { number },
	pernaE: { number },
	altura: number, -- deslocamento do corpo todo (studs, escala 1)
	esticaBracos: number, -- 1 = normal (o Titã estica como borracha)
	achata: number, -- 0 = normal; > 0 achata (squash), < 0 estica
}

local function zero(): { number }
	return { 0, 0, 0 }
end

function Bonecos.poseNeutra(): Pose
	return {
		pescoco = zero(),
		tronco = zero(),
		bracoD = zero(),
		bracoE = zero(),
		pernaD = zero(),
		pernaE = zero(),
		altura = 0,
		esticaBracos = 1,
		achata = 0,
	}
end

-- Ângulos no espaço do corpo (frente = -z): x positivo leva o braço para a frente/cima; z positivo
-- abre o braço direito para o lado (e o esquerdo com z negativo).
-- Pose no tempo `t` (segundos). `fase` é 0..1 dentro de ações com duração (golpe, aceno).
--   parado   respira, braços balançam de leve, cabeça olha em volta
--   falar    parado + cabeça acenando e um braço gesticulando
--   acenar   braço direito para cima, mão balançando
--   erguer   braços esticados para cima (preparando o golpe)
--   bater    braços descem com força, corpo achata
--   comemorar pulinhos com os dois braços para cima
function Bonecos.pose(estado: string, t: number, fase: number?): Pose
	local p = Bonecos.poseNeutra()
	local r = math.sin(t * 2.4)
	-- base comum: respiração
	p.altura = 0.04 * r
	p.tronco = { 0.02 * r, 0, 0 }
	p.pescoco = { 0.04 * math.sin(t * 1.1), 0.25 * math.sin(t * 0.6), 0.05 * math.sin(t * 1.6) }
	p.bracoD = { 0.08 * r, 0, 0.08 + 0.03 * math.sin(t * 1.7) }
	p.bracoE = { -0.08 * r, 0, -0.08 - 0.03 * math.sin(t * 1.7) }
	local f = math.clamp(fase or 0, 0, 1)
	if estado == "falar" then
		p.pescoco[1] = 0.12 * math.abs(math.sin(t * 6))
		p.bracoD = { 0.9 + 0.25 * math.sin(t * 4), 0, 0.25 }
	elseif estado == "acenar" then
		p.bracoD = { 0, 0, 2.6 + 0.35 * math.sin(t * 10) }
		p.pescoco[3] = 0.12
	elseif estado == "erguer" then
		-- os braços sobem pela frente até ficar acima da cabeça e esticam
		local a = 2.9 * f
		p.bracoD = { a, 0, 0.12 }
		p.bracoE = { a, 0, -0.12 }
		p.esticaBracos = 1 + 0.8 * f
		p.achata = -0.08 * f
		p.pescoco[1] = -0.3 * f
	elseif estado == "bater" then
		-- do alto até à frente, num instante; o corpo achata e volta
		local desce = math.clamp(f / 0.25, 0, 1)
		local a = 2.9 * (1 - desce) + 1.2 * desce
		p.bracoD = { a, 0, 0.12 }
		p.bracoE = { a, 0, -0.12 }
		p.esticaBracos = 1.8 - 0.8 * f
		p.achata = 0.18 * math.sin(f * math.pi)
		p.pescoco[1] = 0.2 * desce
	elseif estado == "vitoria" then
		-- pose de estátua: punho direito erguido, mão esquerda na cintura, queixo para cima
		p.altura = 0
		p.tronco = { -0.05, 0.15, 0 }
		p.bracoD = { 0.25, 0, 2.75 }
		p.bracoE = { -0.35, 0, -0.75 }
		p.pescoco = { -0.18, 0.2, 0 }
		p.pernaD = { 0, 0, 0.12 }
		p.pernaE = { 0, 0, -0.12 }
	elseif estado == "comemorar" then
		local pulo = math.abs(math.sin(t * 6))
		p.altura = 0.6 * pulo
		p.bracoD = { 0, 0, 2.7 + 0.2 * pulo }
		p.bracoE = { 0, 0, -2.7 - 0.2 * pulo }
		p.pernaD = { 0.15 * pulo, 0, 0 }
		p.pernaE = { -0.15 * pulo, 0, 0 }
	end
	return p
end

return Bonecos
