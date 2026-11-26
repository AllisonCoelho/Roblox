-- Poderes do ataque automático da aura (só regras puras, testadas em testes/logica.luau).
--
-- Engenharia reversa dos jogos de anime/tower defense do Roblox (Anime Defenders, Anime Last
-- Stand, All Star TD, Universal TD): cada unidade ataca de um jeito — projétil, linha, cone,
-- círculo, corrente que pula entre inimigos, chuva do céu — e muitas aplicam um efeito (queimar,
-- congelar, sangrar, lentidão, crítico, vários golpes). Aqui cada FAMÍLIA de aura vira um poder
-- com forma e efeito próprios. O servidor resolve os acertos com este módulo; o cliente só
-- desenha (Mundo/AtaquesAura) a partir do que o servidor mandou.
--
-- Balanço: no alvo principal todos ficam perto de 100–130% do dano base, trocando força
-- imediata por área, alvos extras, tempo ou sorte. A Pontuação continua sendo o que mais pesa.
local AtaquesAura = {}

export type Forma = "projetil" | "linha" | "cone" | "circulo" | "corrente" | "ceu" | "chao" | "giro"

export type Poder = {
	id: string,
	nome: string,
	descricao: string,
	forma: Forma,
	principal: number, -- fração do dano base no alvo
	golpes: number?, -- divide o principal em N acertos seguidos
	intervalo: number?, -- segundos entre esses acertos
	area: { raio: number, fracao: number }?, -- respingo em volta do alvo
	alvos: { raio: number, fracoes: { number } }?, -- corrente: pula para outros alvos
	linha: { comprimento: number, largura: number, fracao: number }?, -- atravessa quem está atrás
	queimar: { fracao: number, duracao: number }?, -- dano extra ao longo do tempo
	lentidao: { fator: number, duracao: number }?, -- o alvo ataca mais devagar
	critico: { chance: number, mult: number }?,
	cadaN: { n: number, mult: number }?, -- a cada N golpes, um golpe muito forte
}

AtaquesAura.PODERES = {
	estilhaco = {
		id = "estilhaco",
		nome = "Estilhaço de Cristal",
		descricao = "Lança de cristal que explode em estilhaços em volta do alvo.",
		forma = "projetil",
		principal = 1,
		area = { raio = 8, fracao = 0.3 },
	},
	vinhas = {
		id = "vinhas",
		nome = "Prisão de Vinhas",
		descricao = "Vinhas brotam do chão, prendem e deixam o alvo lento.",
		forma = "chao",
		principal = 1.05,
		lentidao = { fator = 1.4, duracao = 2.5 },
	},
	mare = {
		id = "mare",
		nome = "Jato da Maré",
		descricao = "Jato de água em linha que atravessa quem estiver atrás.",
		forma = "linha",
		principal = 0.95,
		linha = { comprimento = 14, largura = 5, fracao = 0.6 },
	},
	brasa = {
		id = "brasa",
		nome = "Bola de Brasa",
		descricao = "Bola de fogo que deixa o alvo queimando.",
		forma = "projetil",
		principal = 0.85,
		queimar = { fracao = 0.45, duracao = 3 },
	},
	corrente = {
		id = "corrente",
		nome = "Raio em Cadeia",
		descricao = "Relâmpago que pula para mais dois inimigos.",
		forma = "corrente",
		principal = 0.95,
		alvos = { raio = 12, fracoes = { 0.65, 0.4 } },
	},
	geada = {
		id = "geada",
		nome = "Lança de Geada",
		descricao = "Lança de gelo que congela: o alvo ataca bem mais devagar.",
		forma = "projetil",
		principal = 1,
		lentidao = { fator = 1.8, duracao = 3 },
	},
	espiritos = {
		id = "espiritos",
		nome = "Revoada de Espíritos",
		descricao = "Três espíritos teleguiados acertam um depois do outro.",
		forma = "giro",
		principal = 1.2,
		golpes = 3,
		intervalo = 0.15,
	},
	eco = {
		id = "eco",
		nome = "Eco Sônico",
		descricao = "Onda de som em cone que acerta todos à frente.",
		forma = "cone",
		principal = 1,
		area = { raio = 10, fracao = 0.45 },
	},
	meteoro = {
		id = "meteoro",
		nome = "Chuva de Estrelas",
		descricao = "Estrelas caem do céu; a cada 3 golpes, um meteoro enorme.",
		forma = "ceu",
		principal = 0.9,
		cadaN = { n = 3, mult = 2.6 },
	},
	vazio = {
		id = "vazio",
		nome = "Implosão do Vazio",
		descricao = "Esfera negra que puxa e explode em área.",
		forma = "circulo",
		principal = 0.85,
		area = { raio = 11, fracao = 0.55 },
	},
	runas = {
		id = "runas",
		nome = "Lâminas Rúnicas",
		descricao = "Duas lâminas de runa giram e cortam; podem acertar crítico.",
		forma = "giro",
		principal = 1,
		golpes = 2,
		intervalo = 0.18,
		critico = { chance = 0.2, mult = 2 },
	},
	garras = {
		id = "garras",
		nome = "Garras da Fera",
		descricao = "Três cortes em X; um quarto das vezes, crítico.",
		forma = "projetil",
		principal = 1,
		golpes = 3,
		intervalo = 0.09,
		critico = { chance = 0.25, mult = 2 },
	},
	espada = {
		id = "espada",
		nome = "Lâmina do Soberano",
		descricao = "Espada de luz gigante desce do céu e abre o chão.",
		forma = "ceu",
		principal = 1.2,
		area = { raio = 10, fracao = 0.4 },
	},
	punho = {
		id = "punho",
		nome = "Punho de Borracha Gigante",
		descricao = "O punho cresce até ficar gigante e esmaga tudo em volta.",
		forma = "projetil",
		principal = 1.3,
		area = { raio = 10, fracao = 0.5 },
	},
} :: { [string]: Poder }

-- Família do catálogo -> poder
AtaquesAura.POR_FAMILIA = {
	Cristal = "estilhaco",
	Mineral = "estilhaco",
	Reflexo = "estilhaco",
	Natureza = "vinhas",
	Floral = "vinhas",
	Oceano = "mare",
	Forja = "brasa",
	["Fênix"] = "brasa",
	Tempestade = "corrente",
	["Mecânico"] = "corrente",
	Metal = "corrente",
	Geada = "geada",
	["Espírito"] = "espiritos",
	Bruma = "espiritos",
	Som = "eco",
	["Cósmico"] = "meteoro",
	Abismo = "vazio",
	Fenda = "vazio",
	["Relíquia"] = "runas",
	Artefato = "runas",
	Arcano = "runas",
	Temporal = "runas",
	Fera = "garras",
	Deserto = "garras",
	Soberano = "espada",
} :: { [string]: string }

-- Auras com poder próprio (exclusivas e de anime)
AtaquesAura.POR_AURA = {
	gear5 = "punho",
} :: { [string]: string }

AtaquesAura.PADRAO = "estilhaco"

function AtaquesAura.poderDe(auraId: string?, familia: string?): Poder
	local id = (auraId and AtaquesAura.POR_AURA[auraId])
		or (familia and AtaquesAura.POR_FAMILIA[familia])
		or AtaquesAura.PADRAO
	return AtaquesAura.PODERES[id] or AtaquesAura.PODERES[AtaquesAura.PADRAO]
end

-- Raridade aumenta o alcance das áreas/correntes (só um pouco)
function AtaquesAura.raio(base: number, tier: number): number
	return base + math.clamp(tier - 1, 0, 6) * 0.5
end

-- ============================================================ resolver os acertos

export type Alvo = { id: number, x: number, z: number }
export type Acerto = {
	id: number,
	dano: number,
	atraso: number, -- segundos até aplicar
	critico: boolean?,
	tipo: string, -- "principal" | "area" | "corrente" | "linha" | "queimar"
}
export type Resultado = {
	acertos: { Acerto },
	lentidao: { fator: number, duracao: number }?,
	forte: boolean, -- golpe especial (cadaN)
}

local function inteiro(v: number): number
	return math.max(1, math.floor(v + 0.5))
end

-- `origem` = posição do jogador (x, z); `alvo` = alvo principal; `outros` = outros alvos vivos.
-- `contador` = quantos golpes o jogador já deu (para o cadaN). `aleatorio` devolve [0, 1).
function AtaquesAura.resolver(
	poder: Poder,
	danoBase: number,
	tier: number,
	origem: { x: number, z: number },
	alvo: Alvo,
	outros: { Alvo },
	contador: number,
	aleatorio: () -> number
): Resultado
	local acertos: { Acerto } = {}
	local base = math.max(danoBase, 0)
	local mult = poder.principal
	local forte = false
	if poder.cadaN and contador > 0 and contador % poder.cadaN.n == 0 then
		mult *= poder.cadaN.mult
		forte = true
	end
	-- alvo principal (em um ou vários golpes)
	local golpes = poder.golpes or 1
	for g = 1, golpes do
		local critico = poder.critico ~= nil and aleatorio() < poder.critico.chance
		local d = base
			* mult
			/ golpes
			* (if critico and poder.critico then poder.critico.mult else 1)
		table.insert(acertos, {
			id = alvo.id,
			dano = inteiro(d),
			atraso = (g - 1) * (poder.intervalo or 0),
			critico = critico or nil,
			tipo = "principal",
		})
	end
	-- área em volta do alvo
	if poder.area then
		local r = AtaquesAura.raio(poder.area.raio, tier)
		for _, o in outros do
			if o.id ~= alvo.id and (o.x - alvo.x) ^ 2 + (o.z - alvo.z) ^ 2 <= r * r then
				table.insert(acertos, {
					id = o.id,
					dano = inteiro(base * poder.area.fracao),
					atraso = 0.05,
					tipo = "area",
				})
			end
		end
	end
	-- corrente: pula para o mais perto ainda não atingido
	if poder.alvos then
		local r = AtaquesAura.raio(poder.alvos.raio, tier)
		local atual = alvo
		local usados = { [alvo.id] = true }
		for salto, fracao in poder.alvos.fracoes do
			local melhor, melhorD = nil, r * r
			for _, o in outros do
				local d = (o.x - atual.x) ^ 2 + (o.z - atual.z) ^ 2
				if not usados[o.id] and d <= melhorD then
					melhor, melhorD = o, d
				end
			end
			if not melhor then
				break
			end
			usados[melhor.id] = true
			table.insert(acertos, {
				id = melhor.id,
				dano = inteiro(base * fracao),
				atraso = salto * 0.08,
				tipo = "corrente",
			})
			atual = melhor
		end
	end
	-- linha: quem estiver no caminho, depois do alvo
	if poder.linha then
		local dx, dz = alvo.x - origem.x, alvo.z - origem.z
		local tam = math.sqrt(dx * dx + dz * dz)
		if tam > 0.01 then
			dx, dz = dx / tam, dz / tam
			for _, o in outros do
				if o.id ~= alvo.id then
					local ox, oz = o.x - alvo.x, o.z - alvo.z
					local ao_longo = ox * dx + oz * dz
					local lado = math.abs(ox * -dz + oz * dx)
					if
						ao_longo > 0
						and ao_longo <= poder.linha.comprimento
						and lado <= poder.linha.largura / 2
					then
						table.insert(acertos, {
							id = o.id,
							dano = inteiro(base * poder.linha.fracao),
							atraso = 0.05 + ao_longo * 0.01,
							tipo = "linha",
						})
					end
				end
			end
		end
	end
	-- queimadura: 3 pulsos ao longo da duração
	if poder.queimar then
		local pulsos = 3
		for k = 1, pulsos do
			table.insert(acertos, {
				id = alvo.id,
				dano = inteiro(base * poder.queimar.fracao / pulsos),
				atraso = poder.queimar.duracao * k / pulsos,
				tipo = "queimar",
			})
		end
	end
	return { acertos = acertos, lentidao = poder.lentidao, forte = forte }
end

-- Multiplicador esperado no alvo único (para o chefe do evento e para conferir o balanço)
function AtaquesAura.esperadoAlvoUnico(poder: Poder): number
	local m = poder.principal
	if poder.critico then
		m *= 1 + poder.critico.chance * (poder.critico.mult - 1)
	end
	if poder.cadaN then
		m *= 1 + (poder.cadaN.mult - 1) / poder.cadaN.n
	end
	if poder.queimar then
		m += poder.queimar.fracao
	end
	return m
end

return AtaquesAura
