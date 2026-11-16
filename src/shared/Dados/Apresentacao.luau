-- Escala de apresentação do giro "Ritual + Ruptura" por raridade (lógica pura, testada).
-- As cinco etapas: Chamado -> Ressonância -> Instabilidade -> Ruptura -> Revelação.
-- Tudo aqui é parâmetro de UX para ajustar depois do playtest; NÃO altera probabilidades.
-- A categoria é escolhida pela chance REAL da aura que o servidor já sorteou.
local Apresentacao = {}

export type Categoria = {
	id: string,
	nome: string,
	minimo: number, -- vale para auras com chance "1 em minimo" ou mais raras
	-- Duração de cada etapa, em segundos
	chamado: number,
	ressonancia: number,
	instabilidade: number,
	ruptura: number,
	silencio: number, -- pausa dentro da ruptura, logo antes do estouro
	cartao: number, -- tempo do cartão de revelação na tela (0 = só o texto rápido do HUD)
	-- Intensidade
	aneis: number, -- anéis orbitando o núcleo
	nucleo: number, -- diâmetro do núcleo, em studs
	pulsos: number, -- batidas da instabilidade (cada uma abre uma rachadura)
	rachaduras: number,
	onda: number, -- diâmetro final da onda de choque
	tremor: number, -- amplitude do tremor de câmera (só para quem girou)
	circulo: boolean, -- círculo rúnico no chão
	rompe: boolean, -- os anéis se partem na ruptura
	coluna: boolean, -- coluna de luz
	flutua: boolean, -- o avatar sobe do chão
	camera: boolean, -- câmera cinematográfica para quem girou
	ceu: boolean, -- o céu escurece por instantes para o servidor
	alheios: boolean, -- os outros jogadores veem a versão abreviada
}

-- Ordem: da mais comum para a mais rara
Apresentacao.Categorias = {
	{
		id = "baixa",
		nome = "Baixa",
		minimo = 1,
		chamado = 0.08,
		ressonancia = 0.27,
		instabilidade = 0,
		ruptura = 0.12,
		silencio = 0,
		cartao = 0,
		aneis = 1,
		nucleo = 0.6,
		pulsos = 0,
		rachaduras = 0,
		onda = 7,
		tremor = 0,
		circulo = false,
		rompe = false,
		coluna = false,
		flutua = false,
		camera = false,
		ceu = false,
		alheios = false,
	},
	{
		id = "moderada",
		nome = "Moderada",
		minimo = 50,
		chamado = 0.12,
		ressonancia = 0.58,
		instabilidade = 0.1,
		ruptura = 0.18,
		silencio = 0,
		cartao = 0,
		aneis = 2,
		nucleo = 0.8,
		pulsos = 1,
		rachaduras = 0,
		onda = 12,
		tremor = 0,
		circulo = true,
		rompe = false,
		coluna = false,
		flutua = false,
		camera = false,
		ceu = false,
		alheios = false,
	},
	{
		id = "alta",
		nome = "Alta",
		minimo = 1000,
		chamado = 0.2,
		ressonancia = 0.8,
		instabilidade = 0.5,
		ruptura = 0.3,
		silencio = 0,
		cartao = 2.2,
		aneis = 3,
		nucleo = 1,
		pulsos = 4,
		rachaduras = 3,
		onda = 26,
		tremor = 0.05,
		circulo = true,
		rompe = true,
		coluna = true,
		flutua = false,
		camera = false,
		ceu = false,
		alheios = true,
	},
	{
		id = "muito_alta",
		nome = "Muito alta",
		minimo = 10000,
		chamado = 0.25,
		ressonancia = 1,
		instabilidade = 0.9,
		ruptura = 0.4,
		silencio = 0.06,
		cartao = 2.8,
		aneis = 4,
		nucleo = 1.2,
		pulsos = 7,
		rachaduras = 5,
		onda = 40,
		tremor = 0.1,
		circulo = true,
		rompe = true,
		coluna = true,
		flutua = true,
		camera = true,
		ceu = false,
		alheios = true,
	},
	{
		id = "extrema",
		nome = "Extrema",
		minimo = 100000,
		chamado = 0.3,
		ressonancia = 1.2,
		instabilidade = 1.4,
		ruptura = 0.65,
		silencio = 0.18,
		cartao = 3.4,
		aneis = 5,
		nucleo = 1.4,
		pulsos = 10,
		rachaduras = 7,
		onda = 60,
		tremor = 0.16,
		circulo = true,
		rompe = true,
		coluna = true,
		flutua = true,
		camera = true,
		ceu = false,
		alheios = true,
	},
	{
		id = "absoluta",
		nome = "Absoluta",
		minimo = 1000000,
		chamado = 0.4,
		ressonancia = 1.6,
		instabilidade = 2,
		ruptura = 1,
		silencio = 0.35,
		cartao = 4.5,
		aneis = 6,
		nucleo = 1.7,
		pulsos = 14,
		rachaduras = 9,
		onda = 90,
		tremor = 0.22,
		circulo = true,
		rompe = true,
		coluna = true,
		flutua = true,
		camera = true,
		ceu = true,
		alheios = true,
	},
} :: { Categoria }

-- Versão que os outros jogadores veem: ritual curto, mas com o estouro da categoria real
Apresentacao.ALHEIO = { chamado = 0.1, ressonancia = 0.45, instabilidade = 0.25, ruptura = 0.2 }

function Apresentacao.indiceDe(chance: number): number
	local resultado = 1
	for i, c in Apresentacao.Categorias do
		if chance >= c.minimo then
			resultado = i
		end
	end
	return resultado
end

function Apresentacao.de(chance: number): Categoria
	return Apresentacao.Categorias[Apresentacao.indiceDe(chance)]
end

-- Tempo do clique até a aura ser revelada
function Apresentacao.tempoAteRevelacao(c: Categoria): number
	return c.chamado + c.ressonancia + c.instabilidade + c.ruptura
end

-- Categoria usada quando o jogador pede para pular animações de auras repetidas.
-- Só muda a encenação: resultado, cooldown e anúncios continuam iguais.
function Apresentacao.abreviada(): Categoria
	return Apresentacao.Categorias[1]
end

return Apresentacao
