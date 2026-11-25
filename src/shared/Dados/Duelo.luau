-- Combate de turno REATIVO da Arena (contra o Primeiro Soberano, pelo Trono e na Rankeada).
-- Só regras puras (sem Roblox), testadas em testes/logica.luau. O servidor decide tudo com elas.
--
-- Base: o combate de Clair Obscur: Expedition 33 (turno + reação em tempo real), com poucas
-- mudanças para o nosso jogo (1 contra 1, Concentrar, Pontuação de Aura no PvP):
--   * Turnos alternados. Na sua vez você escolhe uma ação: Ataque (ganha 1 PA), uma Habilidade
--     (gasta PA) ou Concentrar (ganha 2 PA e amplia as janelas de defesa até a sua próxima vez).
--   * Golpe no tempo certo: durante o seu golpe aparece um anel; tocar no tempo certo dá
--     Perfeito (×1,35 e mais Ruptura) ou Bom (×1); errar ou não tocar dá ×0,7.
--   * Defesa reativa: no golpe do oponente, cada acerto pode ser Esquivado (janela maior, sem
--     dano) ou Aparado (janela curta, sem dano e +1 PA). Aparar TODOS os acertos de um golpe
--     solta um Contra-ataque automático. Golpes absolutos (Sentença do Soberano e Despertar)
--     não podem ser aparados: só esquivados.
--   * Ruptura: dano, golpes perfeitos, aparadas e o Selo enchem a barra de Ruptura do alvo. Cheia,
--     o alvo fica Rompido: perde a próxima vez e recebe +50% de dano até lá.
local Duelo = {}

Duelo.VIDA = 1000
Duelo.PA_INICIAL = 1
Duelo.PA_MAX = 9
Duelo.RUPTURA_MAX = 100
Duelo.RODADAS_MAX = 40 -- vezes no total; depois vence quem tiver mais vida
Duelo.ESPERA_ESCOLHA = 30 -- segundos para escolher a ação
Duelo.ANTECEDENCIA = 0.55 -- o golpe começa este tempo depois de anunciado (todos se preparam)

-- Janelas de tempo (segundos, para mais ou para menos do instante do acerto)
Duelo.JANELA = {
	perfeito = 0.08,
	bom = 0.18,
	aparar = 0.12,
	esquivar = 0.2,
	foco = 1.5, -- Concentrar multiplica as janelas de defesa
	-- um toque só conta para o acerto se vier nesta faixa (antes, depois)
	antes = 0.45,
	depois = 0.25,
}

Duelo.MULT_QTE = { perfeito = 1.35, bom = 1, erro = 0.7 }
Duelo.RUPTURA = {
	porDano = 0.12, -- de cada ponto de dano
	perfeito = 6,
	aparado = 8, -- quem golpeia e é aparado enche a própria barra
	contra = 15,
	selo = 30,
}
Duelo.ROMPIDO_DANO = 1.5
Duelo.BALUARTE = 0.55 -- dano recebido pelo Soberano depois do Baluarte

export type Acao = {
	id: string,
	nome: string,
	custo: number, -- PA gastos
	ganho: number, -- PA ganhos ao usar
	acertos: { number }, -- instantes de cada acerto (s desde o começo do golpe)
	dano: { number }, -- dano base de cada acerto
	marcas: { number }?, -- acertos com anel de tempo (cada acerto usa a última marca até ele)
	absoluto: boolean?, -- não pode ser aparado
	avanco: number?, -- studs que corre até o alvo
	efeito: string?, -- "selo", "concentrar", "baluarte"
	descricao: string,
	jogador: boolean?, -- o jogador pode escolher
}

local function a(t: Acao): Acao
	return t
end

Duelo.ACOES = {
	-- jogador
	ataque = a({
		id = "ataque",
		nome = "Ataque",
		custo = 0,
		ganho = 1,
		acertos = { 0.39 },
		dano = { 85 },
		marcas = { 1 },
		avanco = 9,
		descricao = "+1 PA",
		jogador = true,
	}),
	corte = a({
		id = "corte",
		nome = "Corte de Ressonância",
		custo = 2,
		ganho = 0,
		acertos = { 0.5, 0.86 },
		dano = { 75, 75 },
		marcas = { 1, 2 },
		avanco = 8,
		descricao = "2 golpes",
		jogador = true,
	}),
	selo = a({
		id = "selo",
		nome = "Selo de Ruptura",
		custo = 2,
		ganho = 0,
		acertos = { 0.48 },
		dano = { 50 },
		marcas = { 1 },
		efeito = "selo",
		descricao = "Enche a Ruptura · metade do próximo golpe",
		jogador = true,
	}),
	despertar = a({
		id = "despertar",
		nome = "Despertar",
		custo = 5,
		ganho = 0,
		acertos = { 0.96, 1.26, 1.56 },
		dano = { 100, 100, 140 },
		marcas = { 1 },
		absoluto = true,
		descricao = "3 golpes · só dá para esquivar",
		jogador = true,
	}),
	concentrar = a({
		id = "concentrar",
		nome = "Concentrar",
		custo = 0,
		ganho = 2,
		acertos = {},
		dano = {},
		efeito = "concentrar",
		descricao = "+2 PA · defesa mais fácil",
		jogador = true,
	}),
	-- contra-ataque automático (depois de aparar todos os acertos)
	contra = a({
		id = "contra",
		nome = "Contra-ataque",
		custo = 0,
		ganho = 0,
		acertos = { 0.3 },
		dano = { 120 },
		avanco = 9,
		descricao = "",
	}),
	-- Primeiro Soberano
	investida = a({
		id = "investida",
		nome = "Investida do Trono",
		custo = 0,
		ganho = 0,
		acertos = { 0.42 },
		dano = { 110 },
		descricao = "1 golpe",
	}),
	trinca = a({
		id = "trinca",
		nome = "Fúria Tripla",
		custo = 0,
		ganho = 0,
		acertos = { 0.5, 0.9, 1.3 },
		dano = { 60, 60, 75 },
		descricao = "3 golpes seguidos",
	}),
	finta = a({
		id = "finta",
		nome = "Lâmina Hesitante",
		custo = 0,
		ganho = 0,
		acertos = { 1.15, 1.45 },
		dano = { 90, 90 },
		descricao = "finge o golpe e ataca depois",
	}),
	pesado = a({
		id = "pesado",
		nome = "Sentença do Trono",
		custo = 0,
		ganho = 0,
		acertos = { 0.72 },
		dano = { 240 },
		absoluto = true,
		descricao = "golpe absoluto: só dá para esquivar",
	}),
	baluarte = a({
		id = "baluarte",
		nome = "Baluarte",
		custo = 0,
		ganho = 0,
		acertos = {},
		dano = {},
		efeito = "baluarte",
		descricao = "reduz o dano do seu próximo golpe",
	}),
}

Duelo.MENU = { "ataque", "corte", "selo", "despertar", "concentrar" }

-- O Soberano segue um ciclo (como antes), agora com combos para esquivar e aparar
local PADRAO_SOBERANO =
	{ "investida", "trinca", "baluarte", "finta", "pesado", "trinca", "investida", "pesado" }

function Duelo.intencao(vezSoberano: number): string
	return PADRAO_SOBERANO[(vezSoberano - 1) % #PADRAO_SOBERANO + 1]
end

export type Lado = {
	vida: number,
	pa: number,
	ruptura: number,
	rompido: boolean, -- perde a próxima vez
	selado: boolean, -- metade do próximo acerto recebido
	foco: boolean, -- Concentrar: janelas de defesa maiores até a próxima vez
	baluarte: boolean, -- recebe menos dano até a próxima vez
	mult: number, -- multiplicador de dano (Pontuação no PvP; 1 contra o Soberano)
	pontuacao: number,
}
export type Estado = { vez: number, quem: string, a: Lado, b: Lado, vezesB: number }

local function lado(mult: number, pontuacao: number): Lado
	return {
		vida = Duelo.VIDA,
		pa = Duelo.PA_INICIAL,
		ruptura = 0,
		rompido = false,
		selado = false,
		foco = false,
		baluarte = false,
		mult = mult,
		pontuacao = pontuacao,
	}
end

-- `quem` começa (o desafiante, "a")
function Duelo.novo(multA: number?, multB: number?, pontA: number?, pontB: number?): Estado
	return {
		vez = 1,
		quem = "a",
		a = lado(multA or 1, pontA or 0),
		b = lado(multB or 1, pontB or 0),
		vezesB = 0,
	}
end

function Duelo.outro(q: string): string
	return if q == "a" then "b" else "a"
end

function Duelo.copiar(e: Estado): Estado
	return {
		vez = e.vez,
		quem = e.quem,
		a = table.clone(e.a),
		b = table.clone(e.b),
		vezesB = e.vezesB,
	}
end

-- Problema com a ação do jogador (nil = pode)
function Duelo.validar(e: Estado, q: string, id: any): string?
	local l = if q == "a" then e.a else e.b
	local acao = if type(id) == "string" then Duelo.ACOES[id] else nil
	if e.a.vida <= 0 or e.b.vida <= 0 then
		return "O duelo terminou."
	elseif e.quem ~= q then
		return "Não é a sua vez."
	elseif not acao or not acao.jogador then
		return "Ação desconhecida."
	elseif l.pa < acao.custo then
		return string.format("Faltam %d PA.", acao.custo - l.pa)
	end
	return nil
end

-- ============================================================ tempo

-- Nota do toque no anel do próprio golpe
function Duelo.notaQte(desvio: number?): string
	if desvio == nil then
		return "erro"
	end
	local d = math.abs(desvio)
	if d <= Duelo.JANELA.perfeito then
		return "perfeito"
	elseif d <= Duelo.JANELA.bom then
		return "bom"
	end
	return "erro"
end

-- Resultado da defesa num acerto: "aparado", "esquivado" ou "atingido"
function Duelo.notaDefesa(tipo: string?, desvio: number?, absoluto: boolean, foco: boolean): string
	if tipo == nil or desvio == nil then
		return "atingido"
	end
	local d = math.abs(desvio)
	local f = if foco then Duelo.JANELA.foco else 1
	if tipo == "aparar" then
		if not absoluto and d <= Duelo.JANELA.aparar * f then
			return "aparado"
		end
		return "atingido"
	elseif tipo == "esquivar" and d <= Duelo.JANELA.esquivar * f then
		return "esquivado"
	end
	return "atingido"
end

-- Nota que vale para o acerto i (a última marca até ele)
function Duelo.notaDoAcerto(acao: Acao, notas: { [number]: string }, i: number): string
	local nota = "erro"
	local marcas = acao.marcas
	if not marcas then
		return "bom" -- golpe sem anel (Soberano, contra-ataque): dano normal
	end
	for _, m in marcas do
		if m <= i then
			nota = notas[m] or "erro"
		end
	end
	return nota
end

-- ============================================================ resolução

local function encherRuptura(l: Lado, quanto: number)
	if l.rompido then
		return
	end
	l.ruptura = math.min(Duelo.RUPTURA_MAX, l.ruptura + quanto)
	if l.ruptura >= Duelo.RUPTURA_MAX then
		l.rompido = true
		l.ruptura = 0
	end
end

export type Acerto = {
	indice: number,
	dano: number,
	nota: string, -- nota do anel de quem golpeou
	defesa: string, -- "aparado", "esquivado", "atingido"
	rompeu: boolean, -- o alvo ficou Rompido com este acerto
}

-- Começo do golpe: paga o custo e aplica o que vale já (Concentrar, Baluarte)
function Duelo.iniciarAcao(e: Estado, q: string, id: string)
	local acao = Duelo.ACOES[id]
	local l = if q == "a" then e.a else e.b
	l.pa = math.clamp(l.pa - acao.custo, 0, Duelo.PA_MAX)
	-- a defesa reforçada e o Baluarte valem até a próxima vez de quem usou
	l.foco = acao.efeito == "concentrar"
	l.baluarte = acao.efeito == "baluarte"
	if q == "b" then
		e.vezesB += 1
	end
end

-- Um acerto do golpe `id` de q no outro lado
function Duelo.acerto(
	e: Estado,
	q: string,
	id: string,
	i: number,
	nota: string,
	defesa: string
): Acerto
	local acao = Duelo.ACOES[id]
	local atk = if q == "a" then e.a else e.b
	local alvo = if q == "a" then e.b else e.a
	local dano = 0
	local estavaRompido = alvo.rompido
	if defesa == "atingido" then
		local d = (acao.dano[i] or 0) * atk.mult * (Duelo.MULT_QTE[nota] or 1)
		if alvo.rompido then
			d *= Duelo.ROMPIDO_DANO
		end
		if alvo.baluarte then
			d *= Duelo.BALUARTE
		end
		if alvo.selado and d > 0 then
			d *= 0.5
			alvo.selado = false
		end
		dano = math.min(alvo.vida, math.floor(d + 0.5))
		alvo.vida -= dano
		encherRuptura(
			alvo,
			dano * Duelo.RUPTURA.porDano
				+ (if nota == "perfeito" then Duelo.RUPTURA.perfeito else 0)
		)
	elseif defesa == "aparado" then
		alvo.pa = math.min(Duelo.PA_MAX, alvo.pa + 1)
		encherRuptura(atk, Duelo.RUPTURA.aparado)
	end
	return {
		indice = i,
		dano = dano,
		nota = nota,
		defesa = defesa,
		rompeu = alvo.rompido and not estavaRompido,
	}
end

-- Todos os acertos foram aparados? Então o alvo contra-ataca
function Duelo.contraAtaca(acao: Acao, defesas: { string }): boolean
	if #acao.acertos == 0 or acao.absoluto then
		return false
	end
	for i = 1, #acao.acertos do
		if defesas[i] ~= "aparado" then
			return false
		end
	end
	return true
end

-- Fim do golpe: ganho de PA, Selo, Ruptura extra do Selo
function Duelo.terminarAcao(e: Estado, q: string, id: string, algumAcerto: boolean)
	local acao = Duelo.ACOES[id]
	local l = if q == "a" then e.a else e.b
	local alvo = if q == "a" then e.b else e.a
	l.pa = math.clamp(l.pa + acao.ganho, 0, Duelo.PA_MAX)
	if acao.efeito == "selo" then
		l.selado = true
		if algumAcerto then
			encherRuptura(alvo, Duelo.RUPTURA.selo)
		end
	end
end

-- Vencedor (nil = ninguém ainda)
function Duelo.vencedor(e: Estado): string?
	if e.a.vida <= 0 or e.b.vida <= 0 then
		if e.a.vida <= 0 and e.b.vida <= 0 then
			return if e.a.pontuacao >= e.b.pontuacao then "a" else "b"
		end
		return if e.a.vida <= 0 then "b" else "a"
	end
	if e.vez > Duelo.RODADAS_MAX then
		if e.a.vida ~= e.b.vida then
			return if e.a.vida > e.b.vida then "a" else "b"
		end
		return if e.a.pontuacao >= e.b.pontuacao then "a" else "b"
	end
	return nil
end

-- Passa a vez. Quem está Rompido perde a vez (e sai do Rompido). Devolve quem perdeu a vez.
function Duelo.passarVez(e: Estado): string?
	e.vez += 1
	local proximo = Duelo.outro(e.quem)
	local l = if proximo == "a" then e.a else e.b
	if l.rompido then
		l.rompido = false
		l.foco = false
		l.baluarte = false
		e.vez += 1
		-- quem perdeu a vez não gasta a vez do Soberano no ciclo de intenções
		return proximo
	end
	e.quem = proximo
	return nil
end

-- O estado do ponto de vista de um lado (para a tela)
function Duelo.visao(e: Estado, q: string): { [string]: any }
	local eu = if q == "a" then e.a else e.b
	local outro = if q == "a" then e.b else e.a
	return {
		vez = e.vez,
		vezesB = e.vezesB, -- para a tela mostrar o próximo golpe do Soberano
		minhaVez = e.quem == q,
		vida = eu.vida,
		pa = eu.pa,
		ruptura = eu.ruptura,
		rompido = eu.rompido,
		selado = eu.selado,
		foco = eu.foco,
		mult = eu.mult,
		oponente = {
			vida = outro.vida,
			pa = outro.pa,
			ruptura = outro.ruptura,
			rompido = outro.rompido,
			baluarte = outro.baluarte,
			mult = outro.mult,
		},
	}
end

return Duelo
