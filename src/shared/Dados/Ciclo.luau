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
-- Quadros-chave por hora do relógio. O cliente mistura os dois vizinhos.
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

-- Valores perto do padrão do Roblox (Brightness ~2, sem exposição extra, ambiente baixo): a
-- iluminação antiga tinha exposição levantada e ambiente alto e deixava tudo lavado e brilhante.
local function luz(t: { [string]: any }): Luz
	return t :: any
end

local NOITE: Luz = luz({
	brilho = 1.5,
	exposicao = 0,
	ambiente = c("3A3550"),
	externo = c("5A5482"),
	topo = c("8E82C8"),
	baixo = c("241E3A"),
	nevoa = c("5A4F8E"),
	decaimento = c("140C26"),
	densidade = 0.32,
	bruma = 1.6,
	brilhoSol = 0,
	tinta = c("FFFFFF"),
	saturacao = 0.05,
	estrelas = 1,
	astros = false,
})

Ciclo.QUADROS = {
	{ hora = 0, luz = NOITE },
	{
		hora = 5,
		luz = luz({
			brilho = 1.5,
			exposicao = 0,
			ambiente = c("3A3550"),
			externo = c("5A5482"),
			topo = c("9A86C8"),
			baixo = c("241E3A"),
			nevoa = c("6A5596"),
			decaimento = c("22142E"),
			densidade = 0.32,
			bruma = 1.6,
			brilhoSol = 0,
			tinta = c("FFF8FB"),
			saturacao = 0.05,
			estrelas = 0.8,
			astros = false,
		}),
	},
	{
		-- aurora: céu rosado e dourado, as estrelas somem
		hora = 6,
		luz = luz({
			brilho = 1.7,
			exposicao = -0.05,
			ambiente = c("4A3E56"),
			externo = c("7A6684"),
			topo = c("E8AE98"),
			baixo = c("3A2A4A"),
			nevoa = c("C894A6"),
			decaimento = c("5A3260"),
			densidade = 0.33,
			bruma = 1.4,
			brilhoSol = 0.4,
			tinta = c("FFF3EE"),
			saturacao = 0.08,
			estrelas = 0.25,
			astros = true,
		}),
	},
	{
		-- dia: claro sem estourar, levemente lilás para manter a identidade do Nexo
		hora = 9,
		luz = luz({
			brilho = 2,
			exposicao = -0.1,
			ambiente = c("55526A"),
			externo = c("807C98"),
			topo = c("F2E6D6"),
			baixo = c("4A4266"),
			nevoa = c("A89ED0"),
			decaimento = c("6E5CA4"),
			densidade = 0.28,
			bruma = 0.8,
			brilhoSol = 0.2,
			tinta = c("FFFFFF"),
			saturacao = 0.05,
			estrelas = 0,
			astros = true,
		}),
	},
	{
		hora = 15,
		luz = luz({
			brilho = 2,
			exposicao = -0.1,
			ambiente = c("55526A"),
			externo = c("807C98"),
			topo = c("F2E2CC"),
			baixo = c("4A4266"),
			nevoa = c("A89ED0"),
			decaimento = c("6E5CA4"),
			densidade = 0.28,
			bruma = 0.8,
			brilhoSol = 0.2,
			tinta = c("FFFFFF"),
			saturacao = 0.05,
			estrelas = 0,
			astros = true,
		}),
	},
	{
		-- crepúsculo: laranja e magenta
		hora = 18,
		luz = luz({
			brilho = 1.7,
			exposicao = -0.05,
			ambiente = c("4A3A52"),
			externo = c("7C5C70"),
			topo = c("E89A70"),
			baixo = c("3A2448"),
			nevoa = c("C8806E"),
			decaimento = c("6A2852"),
			densidade = 0.34,
			bruma = 1.5,
			brilhoSol = 0.5,
			tinta = c("FFEFE6"),
			saturacao = 0.08,
			estrelas = 0.3,
			astros = true,
		}),
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
