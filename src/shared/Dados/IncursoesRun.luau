-- Incursões 2.0 (fase A): o que faz cada run ser diferente. Só dados e regras puras (testadas).
--   * tipos de andar sorteados (Purificação, Horda, Caça, Escolta, Cofre; o 5º é sempre o Guardião)
--   * tipos de inimigo (Sombra, Corredor, Atirador, Explosivo, Escudeiro) e Elites com afixos
--   * Bênçãos da Fenda: depois de cada andar, cada jogador escolhe 1 de 3 (valem só na run)
--   * nota S/A/B por andar (tempo e quedas) que multiplica os Fragmentos
-- O sorteio usa uma função de aleatório recebida de fora: só o servidor tem o Random.
local Run = {}

export type TipoAndar = {
	id: string,
	nome: string,
	descricao: string,
	par: number, -- segundos para nota S/A
	minimo: number, -- primeiro andar em que pode aparecer
}

Run.TIPOS = {
	purificacao = {
		id = "purificacao",
		nome = "Purificação",
		descricao = "Fiquem perto dos Núcleos até purificar todos.",
		par = 95,
		minimo = 1,
	},
	horda = {
		id = "horda",
		nome = "Horda",
		descricao = "Sobrevivam até a fenda abrir. As ondas só aumentam.",
		par = 0, -- tempo fixo: a nota vem das quedas
		minimo = 1,
	},
	caca = {
		id = "caca",
		nome = "Caçada",
		descricao = "Derrubem as Elites marcadas com coroa.",
		par = 80,
		minimo = 2,
	},
	escolta = {
		id = "escolta",
		nome = "Escolta",
		descricao = "Levem o Núcleo até a fenda. Ele só anda com alguém perto.",
		par = 90,
		minimo = 2,
	},
	cofre = {
		id = "cofre",
		nome = "Cofre da Fenda",
		descricao = "A fenda já está aberta. Arriscam abrir o Cofre guardado?",
		par = 60,
		minimo = 2,
	},
} :: { [string]: TipoAndar }

Run.HORDA_DURACAO = 45 -- + 5 s por andar

-- Sequência de andares da run: 1..ANDARES-1 sorteados (sem repetir em seguida), o último é o Guardião
function Run.sortearAndares(andares: number, aleatorio: () -> number): { string }
	local lista = {}
	local anterior: string? = nil
	for n = 1, andares - 1 do
		local opcoes = {}
		for _, id in { "purificacao", "horda", "caca", "escolta", "cofre" } do
			local t = Run.TIPOS[id]
			-- o Cofre é raro e nunca no 1º andar
			local peso = if id == "cofre" then 1 else 3
			if n >= t.minimo and id ~= anterior then
				for _ = 1, peso do
					table.insert(opcoes, id)
				end
			end
		end
		local id = opcoes[math.clamp(math.floor(aleatorio() * #opcoes) + 1, 1, #opcoes)]
		table.insert(lista, id)
		anterior = id
	end
	table.insert(lista, "guardiao")
	return lista
end

-- ---------------------------------------------------------------- inimigos

export type Arquetipo = {
	id: string,
	nome: string,
	vida: number, -- multiplicadores sobre a Sombra do andar
	dano: number,
	velocidade: number,
	escala: number,
	cor: string, -- brilho (hex)
	alcance: number?, -- Atirador: dispara de longe
	frente: number?, -- Escudeiro: fração do dano que passa quando acertado de frente
	explode: boolean?,
	minimo: number, -- primeiro andar em que aparece
}

Run.ARQUETIPOS = {
	sombra = {
		id = "sombra",
		nome = "Sombra",
		vida = 1,
		dano = 1,
		velocidade = 1,
		escala = 1.05,
		cor = "",
		minimo = 1,
	},
	corredor = {
		id = "corredor",
		nome = "Corredor",
		vida = 0.55,
		dano = 0.7,
		velocidade = 1.75,
		escala = 0.85,
		cor = "7CF7FF",
		minimo = 1,
	},
	atirador = {
		id = "atirador",
		nome = "Atirador",
		vida = 0.75,
		dano = 0.9,
		velocidade = 0.8,
		escala = 1,
		cor = "B98CFF",
		alcance = 24,
		minimo = 2,
	},
	explosivo = {
		id = "explosivo",
		nome = "Explosivo",
		vida = 0.7,
		dano = 2.2,
		velocidade = 1.25,
		escala = 0.95,
		cor = "FF8A3D",
		explode = true,
		minimo = 2,
	},
	escudeiro = {
		id = "escudeiro",
		nome = "Escudeiro",
		vida = 1.9,
		dano = 1.2,
		velocidade = 0.75,
		escala = 1.3,
		cor = "FFD36B",
		frente = 0.3,
		minimo = 3,
	},
} :: { [string]: Arquetipo }

-- Qual inimigo surge (o andar libera os mais perigosos aos poucos)
function Run.sortearArquetipo(andar: number, aleatorio: () -> number): string
	local tabela = {
		{ "sombra", 5 },
		{ "corredor", 2 },
		{ "atirador", 2 },
		{ "explosivo", 1.5 },
		{ "escudeiro", 1.2 },
	}
	local total = 0
	for _, par in tabela do
		if andar >= Run.ARQUETIPOS[par[1]].minimo then
			total += par[2]
		end
	end
	local x = aleatorio() * total
	for _, par in tabela do
		if andar >= Run.ARQUETIPOS[par[1]].minimo then
			x -= par[2]
			if x <= 0 then
				return par[1]
			end
		end
	end
	return "sombra"
end

export type Afixo = { id: string, nome: string }

Run.AFIXOS = {
	veloz = { id = "veloz", nome = "Veloz" }, -- +45% velocidade
	blindado = { id = "blindado", nome = "Blindado" }, -- recebe 35% menos dano
	vampirico = { id = "vampirico", nome = "Vampírico" }, -- cura 25% do dano que causa
	explosivo = { id = "explosivo", nome = "Instável" }, -- explode ao morrer
} :: { [string]: Afixo }
Run.ELITE_VIDA = 3.5
Run.ELITE_DANO = 1.5
Run.ELITE_ESCALA = 1.4

function Run.sortearAfixos(andar: number, aleatorio: () -> number): { string }
	local ids = { "veloz", "blindado", "vampirico", "explosivo" }
	local n = if andar >= 3 then 2 else 1
	local escolhidos = {}
	while #escolhidos < n do
		local id = ids[math.clamp(math.floor(aleatorio() * #ids) + 1, 1, #ids)]
		if not table.find(escolhidos, id) then
			table.insert(escolhidos, id)
		end
	end
	return escolhidos
end

-- ---------------------------------------------------------------- Bênçãos da Fenda

export type Bencao = {
	id: string,
	nome: string,
	descricao: string,
	raridade: string, -- "comum" | "rara" | "lendaria"
	-- modificadores somados (todos começam em 0)
	mods: { [string]: number },
}

-- mods conhecidos: dano, critico, recargaTecnicas, recargaEsquiva, medidor, danoRecebido,
-- curaAbate, vidaMax, pulso, raioPulso, fragmentos, rastro, ecoCombo
Run.BENCAOS = {
	{
		id = "furia",
		nome = "Ressonância Feroz",
		descricao = "+20% de dano em tudo.",
		raridade = "comum",
		mods = { dano = 0.2 },
	},
	{
		id = "olho",
		nome = "Olho Crítico",
		descricao = "+15% de chance de crítico.",
		raridade = "comum",
		mods = { critico = 0.15 },
	},
	{
		id = "fluxo",
		nome = "Técnicas Fluidas",
		descricao = "Técnicas recarregam 25% mais rápido.",
		raridade = "comum",
		mods = { recargaTecnicas = 0.25 },
	},
	{
		id = "fantasma",
		nome = "Passo Fantasma",
		descricao = "A esquiva recarrega 40% mais rápido.",
		raridade = "comum",
		mods = { recargaEsquiva = 0.4 },
	},
	{
		id = "pedra",
		nome = "Pele de Pedra",
		descricao = "Recebe 20% menos dano.",
		raridade = "comum",
		mods = { danoRecebido = 0.2 },
	},
	{
		id = "vigor",
		nome = "Vigor da Fenda",
		descricao = "+30% de vida máxima e cura total agora.",
		raridade = "comum",
		mods = { vidaMax = 0.3 },
	},
	{
		id = "faminta",
		nome = "Lâmina Faminta",
		descricao = "Cada abate cura 6% da vida.",
		raridade = "rara",
		mods = { curaAbate = 0.06 },
	},
	{
		id = "cadeia",
		nome = "Pulso em Cadeia",
		descricao = "Pulso +40% de dano e +25% de alcance.",
		raridade = "rara",
		mods = { pulso = 0.4, raioPulso = 0.25 },
	},
	{
		id = "despertar",
		nome = "Despertar Ardente",
		descricao = "O medidor do Despertar enche 60% mais rápido.",
		raridade = "rara",
		mods = { medidor = 0.6 },
	},
	{
		id = "eco",
		nome = "Eco do Golpe",
		descricao = "O 3º golpe do combo solta uma onda em volta.",
		raridade = "rara",
		mods = { ecoCombo = 1 },
	},
	{
		id = "brasas",
		nome = "Rastro de Brasas",
		descricao = "A esquiva queima quem estiver no caminho.",
		raridade = "lendaria",
		mods = { rastro = 1 },
	},
	{
		id = "ganancia",
		nome = "Ganância",
		descricao = "+35% de Fragmentos nesta run, mas -15% de vida.",
		raridade = "lendaria",
		mods = { fragmentos = 0.35, vidaMax = -0.15 },
	},
} :: { Bencao }

Run.bencaoPorId = {} :: { [string]: Bencao }
for _, b in Run.BENCAOS do
	Run.bencaoPorId[b.id] = b
end

local PESO_RARIDADE = { comum = 6, rara = 3, lendaria = 1 }

-- 3 ofertas diferentes, sem repetir o que o jogador já tem (lendárias são raras)
function Run.ofertas(
	jaTem: { [string]: boolean },
	aleatorio: () -> number,
	quantas: number?
): { string }
	local n = quantas or 3
	local saida = {}
	for _ = 1, 50 do
		if #saida >= n then
			break
		end
		local total = 0
		for _, b in Run.BENCAOS do
			if not jaTem[b.id] and not table.find(saida, b.id) then
				total += PESO_RARIDADE[b.raridade]
			end
		end
		if total <= 0 then
			break
		end
		local x = aleatorio() * total
		for _, b in Run.BENCAOS do
			if not jaTem[b.id] and not table.find(saida, b.id) then
				x -= PESO_RARIDADE[b.raridade]
				if x <= 0 then
					table.insert(saida, b.id)
					break
				end
			end
		end
	end
	return saida
end

-- Soma os modificadores de todas as bênçãos que o jogador tem
function Run.modificadores(bencaos: { [string]: boolean }): { [string]: number }
	local m = {}
	for id in bencaos do
		local b = Run.bencaoPorId[id]
		if b then
			for k, v in b.mods do
				m[k] = (m[k] or 0) + v
			end
		end
	end
	return m
end

-- ---------------------------------------------------------------- nota do andar

Run.MULT_NOTA = { S = 1.5, A = 1.2, B = 1 }

-- tempo em segundos, quedas = quantas vezes alguém caiu no andar
function Run.nota(tipo: string, tempo: number, quedas: number): string
	local t = Run.TIPOS[tipo]
	local par = if t then t.par else 90
	local rapido = par <= 0 or tempo <= par
	if quedas == 0 and rapido then
		return "S"
	elseif quedas <= 1 and (par <= 0 or tempo <= par * 1.5) then
		return "A"
	end
	return "B"
end

-- Sequência de abates: janela para emendar o próximo
Run.SEQUENCIA_JANELA = 3

-- ---------------------------------------------------------------- fase B: Marcas e Pesadelo

export type Marca = { id: string, nome: string, descricao: string, bonus: number }

-- Modificadores de risco escolhidos antes de entrar: cada um soma Fragmentos
Run.MARCAS = {
	{ id = "densas", nome = "Hordas Densas", descricao = "+40% de inimigos.", bonus = 0.25 },
	{
		id = "velozes",
		nome = "Sombras Velozes",
		descricao = "Inimigos 30% mais rápidos.",
		bonus = 0.2,
	},
	{
		id = "vidro",
		nome = "Corpo de Vidro",
		descricao = "Vocês têm 30% menos vida.",
		bonus = 0.3,
	},
	{
		id = "coroa",
		nome = "Coroa Dupla",
		descricao = "Elites em dobro e com mais afixos.",
		bonus = 0.3,
	},
	{
		id = "semVidas",
		nome = "Sem Reviver",
		descricao = "O grupo não tem vidas extras.",
		bonus = 0.5,
	},
} :: { Marca }

Run.marcaPorId = {} :: { [string]: Marca }
for _, m in Run.MARCAS do
	Run.marcaPorId[m.id] = m
end

-- Pesadelo: liberado depois de vencer o universo no normal
Run.PESADELO = {
	forca = 1.8, -- vida e dano dos inimigos
	velocidade = 1.12,
	recompensa = 2, -- Fragmentos e bônus de vitória
}

export type Preparo = { pesadelo: boolean, marcas: { [string]: boolean } }

-- Valida o que veio do cliente (tipos e ids conhecidos); devolve um preparo limpo
function Run.preparo(bruto: any): Preparo
	local limpo: Preparo = { pesadelo = false, marcas = {} }
	if type(bruto) ~= "table" then
		return limpo
	end
	limpo.pesadelo = bruto.pesadelo == true
	if type(bruto.marcas) == "table" then
		local n = 0
		for k, v in bruto.marcas do
			if type(k) == "string" and v == true and Run.marcaPorId[k] then
				n += 1
				if n > #Run.MARCAS then
					break
				end
				limpo.marcas[k] = true
			end
		end
	end
	return limpo
end

-- Multiplicador de Fragmentos do preparo (Marcas somam; Pesadelo dobra)
function Run.multPreparo(p: Preparo): number
	local soma = 0
	for id in p.marcas do
		local m = Run.marcaPorId[id]
		if m then
			soma += m.bonus
		end
	end
	return (1 + soma) * (if p.pesadelo then Run.PESADELO.recompensa else 1)
end

function Run.descreverPreparo(p: Preparo): string
	local partes = {}
	if p.pesadelo then
		table.insert(partes, "PESADELO")
	end
	for _, m in Run.MARCAS do
		if p.marcas[m.id] then
			table.insert(partes, m.nome)
		end
	end
	return if #partes > 0 then table.concat(partes, " · ") else "Normal"
end

-- Guardião: limiares das fases e quando enfurece
Run.FASES_GUARDIAO = { 0.66, 0.33 }
Run.ENFURECE_EM = 180 -- segundos de luta

return Run
