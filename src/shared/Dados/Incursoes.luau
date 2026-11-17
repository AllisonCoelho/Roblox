-- Incursões: expedições cooperativas (1 a 4 jogadores) a universos destruídos, saindo do Bastião
-- das Incursões. Este módulo só tem DADOS e REGRAS PURAS (sem Roblox): o servidor decide tudo com
-- ele e o cliente só usa para mostrar números. Testado em testes/logica.luau.
--
-- Uma incursão tem 5 andares. Nos andares 1–4 o grupo purifica os Núcleos Corrompidos enquanto as
-- Sombras atacam; com todos purificados, abre a fenda para o próximo andar. No 5º andar espera o
-- Guardião do universo. Fragmentos ganhos por andar compram Relíquias (só valem nas Incursões).
-- A aura mais rara do jogador vira RESSONÂNCIA (força nas Incursões); nada aqui muda as chances
-- do sorteio.
local Incursoes = {}

export type Universo = {
	id: string,
	nome: string,
	descricao: string,
	cor: string, -- cor principal (hex)
	corVeio: string, -- cor das fissuras/energia
	requisito: string?, -- universo que precisa ter sido concluído antes
	nivel: number, -- 1, 2, 3: multiplica vida/dano das sombras e a recompensa
	guardiao: string,
}

Incursoes.ANDARES = 5
Incursoes.MAX_JOGADORES = 4
Incursoes.ESPERA_FILA = 12 -- segundos de contagem depois que o primeiro entra na fila

Incursoes.UNIVERSOS = {
	{
		id = "cinzas",
		nome = "Cinzas",
		descricao = "Um reino que ardeu até a última pedra. As brasas ainda lembram dos reis.",
		cor = "FF5A2A",
		corVeio = "FFB15A",
		requisito = nil,
		nivel = 1,
		guardiao = "Arauto das Brasas",
	},
	{
		id = "mare",
		nome = "Maré Morta",
		descricao = "Um oceano que parou. Templos afundados e um silêncio que respira.",
		cor = "3FA7FF",
		corVeio = "9BE6FF",
		requisito = "cinzas",
		nivel = 2,
		guardiao = "Cavaleiro Afogado",
	},
	{
		id = "umbral",
		nome = "Crepúsculo Umbral",
		descricao = "O último entardecer, preso para sempre. A luz aqui tem fome.",
		cor = "9B4DFF",
		corVeio = "D3A6FF",
		requisito = "mare",
		nivel = 3,
		guardiao = "Espectro do Ocaso",
	},
} :: { Universo }

Incursoes.porId = {} :: { [string]: Universo }
for _, u in Incursoes.UNIVERSOS do
	Incursoes.porId[u.id] = u
end

-- Relíquias: melhorias permanentes que só valem dentro das Incursões
export type Reliquia = { id: string, nome: string, descricao: string, custos: { number } }
Incursoes.RELIQUIAS = {
	{
		id = "pulso",
		nome = "Eco do Pulso",
		descricao = "+12% de dano do Pulso por nível.",
		custos = { 25, 50, 90, 140, 210 },
	},
	{
		id = "vigor",
		nome = "Coração de Brasa",
		descricao = "+15% de vida nas Incursões por nível.",
		custos = { 25, 50, 90, 140, 210 },
	},
	{
		id = "canal",
		nome = "Mãos de Selo",
		descricao = "+12% de velocidade para purificar Núcleos por nível.",
		custos = { 25, 50, 90, 140, 210 },
	},
	{
		id = "alcance",
		nome = "Olho do Vazio",
		descricao = "+8% de alcance do Pulso por nível.",
		custos = { 40, 80, 130 },
	},
} :: { Reliquia }
Incursoes.reliquiaPorId = {} :: { [string]: Reliquia }
for _, r in Incursoes.RELIQUIAS do
	Incursoes.reliquiaPorId[r.id] = r
end

-- Perfil: campo "incursoes" (dados antigos ganham o padrão ao carregar)
export type Progresso = {
	fragmentos: number,
	melhor: { [string]: number }, -- melhor andar alcançado por universo
	concluidas: { [string]: number }, -- vitórias por universo
	reliquias: { [string]: number }, -- nível de cada relíquia
}

function Incursoes.padrao(): Progresso
	return { fragmentos = 0, melhor = {}, concluidas = {}, reliquias = {} }
end

local function progresso(p: any): Progresso
	if type(p) ~= "table" then
		return Incursoes.padrao()
	end
	return p
end

function Incursoes.nivel(p: any, reliquia: string): number
	local n = progresso(p).reliquias[reliquia]
	return if type(n) == "number" then n else 0
end

-- O universo está aberto para este jogador?
function Incursoes.liberado(p: any, universo: string): boolean
	local u = Incursoes.porId[universo]
	if not u then
		return false
	end
	if not u.requisito then
		return true
	end
	local v = progresso(p).concluidas[u.requisito]
	return type(v) == "number" and v > 0
end

-- Custo do próximo nível (nil = já no máximo ou relíquia inexistente)
function Incursoes.custo(p: any, reliquia: string): number?
	local r = Incursoes.reliquiaPorId[reliquia]
	if not r then
		return nil
	end
	return r.custos[Incursoes.nivel(p, reliquia) + 1]
end

-- Ressonância: a aura mais rara (chance "1 em N") vira força. 1 em 1 = 1,0; 1 em 1 milhão ≈ 1,36.
function Incursoes.ressonancia(chanceMelhor: number?): number
	local n = if type(chanceMelhor) == "number" and chanceMelhor > 1 then chanceMelhor else 1
	return 1 + 0.06 * math.log10(n)
end

Incursoes.PULSO_DANO = 22
Incursoes.PULSO_RAIO = 14
Incursoes.PULSO_ESPERA = 1.1 -- segundos
Incursoes.VIDA_BASE = 100

function Incursoes.danoPulso(p: any, ressonancia: number): number
	return Incursoes.PULSO_DANO * (1 + 0.12 * Incursoes.nivel(p, "pulso")) * ressonancia
end

function Incursoes.raioPulso(p: any): number
	return Incursoes.PULSO_RAIO * (1 + 0.08 * Incursoes.nivel(p, "alcance"))
end

function Incursoes.vidaMax(p: any): number
	return math.floor(Incursoes.VIDA_BASE * (1 + 0.15 * Incursoes.nivel(p, "vigor")) + 0.5)
end

-- Quanto do núcleo (0..1) um jogador purifica por segundo
function Incursoes.canal(p: any, ressonancia: number): number
	return (1 / 9) * (1 + 0.12 * Incursoes.nivel(p, "canal")) * ressonancia
end

-- Mais gente purificando ajuda, mas cada pessoa a mais ajuda menos (2 = 1,6x; 4 = 2,4x)
function Incursoes.bonusGrupo(n: number): number
	if n <= 0 then
		return 0
	end
	return 1 + 0.6 * (math.min(n, Incursoes.MAX_JOGADORES) - 1) - 0.07 * math.max(n - 2, 0)
end

export type Andar = {
	nucleos: number,
	sombras: number, -- quantas ao mesmo tempo no andar
	reforcos: number, -- quantas a mais surgem ao longo do andar
	vidaSombra: number,
	danoSombra: number,
	velocidadeSombra: number,
	guardiao: boolean,
	vidaGuardiao: number,
}

-- Configuração de um andar, já ajustada ao tamanho do grupo
function Incursoes.andar(universo: string, n: number, jogadores: number): Andar
	local u = Incursoes.porId[universo]
	local nivel = if u then u.nivel else 1
	local j = math.clamp(jogadores, 1, Incursoes.MAX_JOGADORES)
	local forca = 1 + 0.45 * (nivel - 1) + 0.12 * (n - 1)
	local guardiao = n >= Incursoes.ANDARES
	return {
		nucleos = if guardiao then 0 else math.min(2 + math.floor((n + 1) / 2), 5),
		sombras = (if guardiao then 2 else 3 + n) + 2 * (j - 1),
		reforcos = (if guardiao then 0 else 2 + n) + 2 * (j - 1),
		vidaSombra = math.floor(40 * forca + 0.5),
		danoSombra = math.floor(9 * forca + 0.5),
		velocidadeSombra = 10 + nivel + 0.4 * n,
		guardiao = guardiao,
		vidaGuardiao = if guardiao then math.floor(700 * forca * (1 + 0.55 * (j - 1)) + 0.5) else 0,
	}
end

Incursoes.VIDAS_BASE = 3 -- revivências do grupo (+1 por jogador)

function Incursoes.vidas(jogadores: number): number
	return Incursoes.VIDAS_BASE + math.clamp(jogadores, 1, Incursoes.MAX_JOGADORES)
end

-- Fragmentos por andar concluído (cada andar vale mais) e o bônus de vitória
function Incursoes.fragmentosAndar(universo: string, n: number): number
	local u = Incursoes.porId[universo]
	local nivel = if u then u.nivel else 1
	return (4 + 2 * n) * nivel
end

function Incursoes.bonusVitoria(universo: string, primeira: boolean): number
	local u = Incursoes.porId[universo]
	local nivel = if u then u.nivel else 1
	return 30 * nivel + (if primeira then 50 * nivel else 0)
end

-- Total ganho por quem concluiu `andares` andares (venceu = derrotou o Guardião)
function Incursoes.recompensa(
	universo: string,
	andares: number,
	venceu: boolean,
	primeira: boolean
): number
	local total = 0
	for n = 1, math.clamp(andares, 0, Incursoes.ANDARES) do
		total += Incursoes.fragmentosAndar(universo, n)
	end
	if venceu then
		total += Incursoes.bonusVitoria(universo, primeira)
	end
	return total
end

return Incursoes
