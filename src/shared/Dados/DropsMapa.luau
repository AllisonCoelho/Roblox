-- Drops aleatórios espalhados pelo Nexo. Só regras puras (sem Roblox), testadas em
-- testes/logica.luau. O servidor sorteia com o seu Random, escolhe o lugar e confere a coleta
-- (quem encosta primeiro leva).
--
--   Orbe de Aura         Pontos de Aura (alguns segundos do seu ganho)
--   Lasca de Fragmento   Fragmentos (mais para quem foi mais longe no Corredor)
--   Estrela Cadente      só à noite: muitos Pontos de Aura e a Bênção Estelar
--                        (+25% de Pontos de Aura por 2 minutos)
--
-- À noite os drops aparecem duas vezes mais rápido (ver Dados/Ciclo).
local DropsMapa = {}

export type Tipo = {
	id: string,
	nome: string,
	cor: string,
	peso: { dia: number, noite: number },
}

DropsMapa.TIPOS = {
	{ id = "orbe", nome = "Orbe de Aura", cor = "B7FFD9", peso = { dia = 72, noite = 52 } },
	{ id = "lasca", nome = "Lasca de Fragmento", cor = "C9A2FF", peso = { dia = 28, noite = 30 } },
	{ id = "estrela", nome = "Estrela Cadente", cor = "FFE27A", peso = { dia = 0, noite = 18 } },
} :: { Tipo }
DropsMapa.porId = {} :: { [string]: Tipo }
for _, t in DropsMapa.TIPOS do
	DropsMapa.porId[t.id] = t
end

DropsMapa.INTERVALO_DIA = 5 -- segundos entre um drop e outro
DropsMapa.INTERVALO_NOITE = 2.5
DropsMapa.VIDA = 120 -- segundos até sumir
DropsMapa.RAIO_COLETA = 6 -- studs da raiz do personagem
DropsMapa.BENCAO = 120 -- segundos de Bênção Estelar
DropsMapa.BENCAO_GANHO = 1.25
DropsMapa.SEGUNDOS_ORBE = 15 -- o orbe vale 15 s do ganho de Pontos de Aura
DropsMapa.SEGUNDOS_ESTRELA = 60
DropsMapa.MINIMO_PONTOS = 5

-- Quantos drops podem existir ao mesmo tempo (mais jogadores, mais drops)
function DropsMapa.maximo(jogadores: number): number
	return math.clamp(8 + 3 * math.max(jogadores, 0), 8, 40)
end

function DropsMapa.intervalo(noite: boolean): number
	return if noite then DropsMapa.INTERVALO_NOITE else DropsMapa.INTERVALO_DIA
end

-- Tipo sorteado. `aleatorio` devolve [0, 1) (Random do servidor)
function DropsMapa.sortear(noite: boolean, aleatorio: () -> number): string
	local soma = 0
	for _, t in DropsMapa.TIPOS do
		soma += if noite then t.peso.noite else t.peso.dia
	end
	local r = aleatorio() * soma
	for _, t in DropsMapa.TIPOS do
		local p = if noite then t.peso.noite else t.peso.dia
		if r < p then
			return t.id
		end
		r -= p
	end
	return DropsMapa.TIPOS[1].id
end

-- Maior fase do Corredor já concluída (0 = nenhuma)
function DropsMapa.faseMaxima(concluidas: { [string]: number }?): number
	local maior = 0
	if not concluidas then
		return 0
	end
	for k, n in concluidas do
		local f = tonumber(k)
		if f and n > 0 and f > maior then
			maior = f
		end
	end
	return maior
end

export type Premio = { pontos: number, fragmentos: number, bencao: boolean }

-- Prêmio de um drop. `ganho` = Pontos de Aura por segundo do jogador; `fase` = maior fase do
-- Corredor concluída; `multFrag` = bônus de Fragmentos (Ecos e equipamento)
function DropsMapa.premio(tipo: string, ganho: number, fase: number, multFrag: number?): Premio
	local g = math.max(ganho, 0)
	if tipo == "orbe" then
		return {
			pontos = math.max(DropsMapa.MINIMO_PONTOS, math.floor(g * DropsMapa.SEGUNDOS_ORBE)),
			fragmentos = 0,
			bencao = false,
		}
	elseif tipo == "lasca" then
		return {
			pontos = 0,
			fragmentos = math.floor((1 + math.clamp(fase, 0, 6)) * (multFrag or 1) + 0.5),
			bencao = false,
		}
	elseif tipo == "estrela" then
		return {
			pontos = math.max(
				DropsMapa.MINIMO_PONTOS * 4,
				math.floor(g * DropsMapa.SEGUNDOS_ESTRELA)
			),
			fragmentos = 0,
			bencao = true,
		}
	end
	return { pontos = 0, fragmentos = 0, bencao = false }
end

-- Ponto aleatório no anel em que os drops aparecem (fora da praça, dentro do limite), em
-- coordenadas do mundo (x, z). Raio sorteado pela área (pontos espalhados por igual).
DropsMapa.RAIO_MIN = 30
DropsMapa.RAIO_MAX = 222
function DropsMapa.pontoNoAnel(a: number, b: number): (number, number)
	local r2 = DropsMapa.RAIO_MIN ^ 2 + a * (DropsMapa.RAIO_MAX ^ 2 - DropsMapa.RAIO_MIN ^ 2)
	local r = math.sqrt(r2)
	local angulo = b * 2 * math.pi
	return r * math.sin(angulo), -r * math.cos(angulo)
end

-- Texto do aviso de coleta
function DropsMapa.texto(tipo: string, p: Premio): string
	local partes = {}
	if p.pontos > 0 then
		table.insert(partes, string.format("+%d Pontos de Aura", p.pontos))
	end
	if p.fragmentos > 0 then
		table.insert(partes, string.format("+%d Fragmentos", p.fragmentos))
	end
	if p.bencao then
		table.insert(partes, "Bênção Estelar: +25% Pontos de Aura por 2 min")
	end
	local t = DropsMapa.porId[tipo]
	return (if t then t.nome .. "! " else "") .. table.concat(partes, " · ")
end

return DropsMapa
