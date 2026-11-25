-- Ciclo de dia e noite do Nexo. Só regras puras (sem Roblox), testadas em testes/logica.luau.
--
-- O ciclo segue o relógio do servidor (Workspace:GetServerTimeNow, que é o horário Unix): todos
-- os servidores e clientes estão na mesma fase sem precisar replicar nada. Um deslocamento
-- (atributo "CicloDeslocamento" do Workspace, só pelo Painel Dev) permite pular fases no teste.
--
-- 20 minutos por volta:  aurora 2 min · dia 8 min · crepúsculo 2 min · noite 8 min
-- A noite é o visual de sempre do Nexo (céu violeta estrelado). À noite os drops do mapa
-- aparecem duas vezes mais rápido e surgem as Estrelas Cadentes (ver Dados/DropsMapa).
local Ciclo = {}

Ciclo.DURACAO = 20 * 60

export type Fase = "aurora" | "dia" | "crepusculo" | "noite"
export type Estado = {
	fase: Fase,
	progresso: number, -- 0..1 dentro da fase
	restante: number, -- segundos até a próxima fase
	relogio: number, -- hora do Lighting.ClockTime (0..24)
}

-- Cada fase: fração da volta e o intervalo de horas do relógio do Lighting que ela cobre
Ciclo.FASES = {
	{ id = "aurora" :: Fase, nome = "Aurora", fracao = 0.1, de = 5, ate = 7 },
	{ id = "dia" :: Fase, nome = "Dia", fracao = 0.4, de = 7, ate = 17 },
	{ id = "crepusculo" :: Fase, nome = "Crepúsculo", fracao = 0.1, de = 17, ate = 19 },
	{ id = "noite" :: Fase, nome = "Noite", fracao = 0.4, de = 19, ate = 29 },
}
Ciclo.NOMES = {
	aurora = "Aurora",
	dia = "Dia",
	crepusculo = "Crepúsculo",
	noite = "Noite",
}

function Ciclo.estado(segundos: number): Estado
	local f = (segundos % Ciclo.DURACAO) / Ciclo.DURACAO
	local inicio = 0
	for _, fase in Ciclo.FASES do
		if f < inicio + fase.fracao or fase.id == "noite" then
			local p = math.clamp((f - inicio) / fase.fracao, 0, 1)
			return {
				fase = fase.id,
				progresso = p,
				restante = (1 - p) * fase.fracao * Ciclo.DURACAO,
				relogio = (fase.de + (fase.ate - fase.de) * p) % 24,
			}
		end
		inicio += fase.fracao
	end
	error("inalcançável")
end

-- Segundos (dentro da volta) em que uma fase começa
function Ciclo.inicioDa(fase: Fase): number
	local inicio = 0
	for _, f in Ciclo.FASES do
		if f.id == fase then
			return inicio * Ciclo.DURACAO
		end
		inicio += f.fracao
	end
	return 0
end

function Ciclo.ehNoite(segundos: number): boolean
	return Ciclo.estado(segundos).fase == "noite"
end

-- ============================================================ iluminação
-- Quadros-chave por hora do relógio. O cliente mistura os dois vizinhos. A noite (0 h, 22 h)
-- é exatamente a iluminação que o Nexo sempre teve.
export type Luz = {
	brilho: number,
	exposicao: number,
	ambiente: Color3,
	externo: Color3,
	topo: Color3,
	baixo: Color3,
	nevoa: Color3, -- Atmosphere.Color
	decaimento: Color3, -- Atmosphere.Decay
	densidade: number,
	bruma: number, -- Atmosphere.Haze
	brilhoSol: number, -- Atmosphere.Glare
	tinta: Color3, -- ColorCorrection.TintColor
	saturacao: number,
	estrelas: number, -- 0..1 (Sky.StarCount)
	astros: boolean, -- sol e lua à mostra
}

local function c(hex: string): Color3
	return Color3.fromHex(hex)
end

local NOITE: Luz = {
	brilho = 2.4,
	exposicao = 0.35,
	ambiente = c("5E5584"),
	externo = c("7C74B4"),
	topo = c("A898F0"),
	baixo = c("3A3060"),
	nevoa = c("6C5FA8"),
	decaimento = c("1A1030"),
	densidade = 0.3,
	bruma = 2,
	brilhoSol = 0,
	tinta = c("FFFFFF"),
	saturacao = 0.12,
	estrelas = 1,
	astros = false,
}

Ciclo.QUADROS = {
	{ hora = 0, luz = NOITE },
	{
		hora = 5,
		luz = {
			brilho = 2.4,
			exposicao = 0.3,
			ambiente = c("5E5584"),
			externo = c("7C74B4"),
			topo = c("B39AF0"),
			baixo = c("3A3060"),
			nevoa = c("7A64B0"),
			decaimento = c("2A1838"),
			densidade = 0.3,
			bruma = 2,
			brilhoSol = 0,
			tinta = c("FFF6FB"),
			saturacao = 0.12,
			estrelas = 0.8,
			astros = false,
		},
	},
	{
		-- aurora: céu rosado e dourado, as estrelas somem
		hora = 6,
		luz = {
			brilho = 2.6,
			exposicao = 0.2,
			ambiente = c("7A6488"),
			externo = c("A98AB4"),
			topo = c("FFC2A8"),
			baixo = c("4A3460"),
			nevoa = c("E9A6B8"),
			decaimento = c("6A3A70"),
			densidade = 0.32,
			bruma = 1.6,
			brilhoSol = 0.6,
			tinta = c("FFEFE8"),
			saturacao = 0.16,
			estrelas = 0.25,
			astros = true,
		},
	},
	{
		-- dia: claro, levemente lilás para manter a identidade do Nexo
		hora = 9,
		luz = {
			brilho = 3,
			exposicao = 0.05,
			ambiente = c("8C86A8"),
			externo = c("B4AED0"),
			topo = c("FFF1DC"),
			baixo = c("6A5E8C"),
			nevoa = c("C8BCF0"),
			decaimento = c("8E78C8"),
			densidade = 0.26,
			bruma = 1,
			brilhoSol = 0.3,
			tinta = c("FFFFFF"),
			saturacao = 0.1,
			estrelas = 0,
			astros = true,
		},
	},
	{
		hora = 15,
		luz = {
			brilho = 3,
			exposicao = 0.05,
			ambiente = c("8C86A8"),
			externo = c("B4AED0"),
			topo = c("FFEBD0"),
			baixo = c("6A5E8C"),
			nevoa = c("C8BCF0"),
			decaimento = c("8E78C8"),
			densidade = 0.26,
			bruma = 1,
			brilhoSol = 0.3,
			tinta = c("FFFFFF"),
			saturacao = 0.1,
			estrelas = 0,
			astros = true,
		},
	},
	{
		-- crepúsculo: laranja e magenta
		hora = 18,
		luz = {
			brilho = 2.6,
			exposicao = 0.2,
			ambiente = c("7A5E7E"),
			externo = c("B08494"),
			topo = c("FFAE7A"),
			baixo = c("4A2C58"),
			nevoa = c("F09A88"),
			decaimento = c("7A2E60"),
			densidade = 0.34,
			bruma = 1.8,
			brilhoSol = 0.8,
			tinta = c("FFE9DC"),
			saturacao = 0.18,
			estrelas = 0.3,
			astros = true,
		},
	},
	{ hora = 20, luz = NOITE },
	{ hora = 24, luz = NOITE },
}

local function misturaCor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- Iluminação na hora do relógio (0..24)
function Ciclo.luz(relogio: number): Luz
	local h = relogio % 24
	local quadros = Ciclo.QUADROS
	for i = 1, #quadros - 1 do
		local a, b = quadros[i], quadros[i + 1]
		if h >= a.hora and h <= b.hora then
			local t = if b.hora > a.hora then (h - a.hora) / (b.hora - a.hora) else 0
			-- suaviza a passagem
			t = t * t * (3 - 2 * t)
			local la, lb = a.luz, b.luz
			return {
				brilho = la.brilho + (lb.brilho - la.brilho) * t,
				exposicao = la.exposicao + (lb.exposicao - la.exposicao) * t,
				ambiente = misturaCor(la.ambiente, lb.ambiente, t),
				externo = misturaCor(la.externo, lb.externo, t),
				topo = misturaCor(la.topo, lb.topo, t),
				baixo = misturaCor(la.baixo, lb.baixo, t),
				nevoa = misturaCor(la.nevoa, lb.nevoa, t),
				decaimento = misturaCor(la.decaimento, lb.decaimento, t),
				densidade = la.densidade + (lb.densidade - la.densidade) * t,
				bruma = la.bruma + (lb.bruma - la.bruma) * t,
				brilhoSol = la.brilhoSol + (lb.brilhoSol - la.brilhoSol) * t,
				tinta = misturaCor(la.tinta, lb.tinta, t),
				saturacao = la.saturacao + (lb.saturacao - la.saturacao) * t,
				estrelas = la.estrelas + (lb.estrelas - la.estrelas) * t,
				astros = if t < 0.5 then la.astros else lb.astros,
			}
		end
	end
	return NOITE
end

-- "3:12" (minutos:segundos)
function Ciclo.tempo(segundos: number): string
	local s = math.max(0, math.floor(segundos))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Ciclo
