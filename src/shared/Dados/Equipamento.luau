-- Equipamento (RPG): elmo, armadura, manoplas, botas e arma. Cada peça dá bônus (Pontos de
-- Aura, Sorte, Dano, Vida ou Fragmentos), aparece no personagem e pode ser ocultada (o "olho":
-- some o visual, os bônus continuam). Peças do mesmo conjunto somam um bônus extra com 3 e
-- com 5 peças. Elas caem das criaturas do Corredor dos Perdidos (cada mundo, um conjunto) e
-- sobem de nível gastando Fragmentos. Só regras puras (sem Roblox): o servidor decide tudo com
-- este módulo. Testado em testes/logica.luau. O visual vem de Dados/EquipamentoVisual.
local Equipamento = {}

export type Atributos = {
	ganho: number?,
	sorte: number?,
	dano: number?,
	vida: number?,
	fragmentos: number?,
} -- em %
export type Conjunto = {
	id: string,
	fase: number,
	nome: string,
	cor: string,
	raridade: number, -- índice em Equipamento.RARIDADES
	bonus3: Atributos,
	bonus5: Atributos,
	nomes: { [string]: string }, -- espaço -> nome da peça
}
export type Item = {
	id: string,
	conjunto: string,
	espaco: string,
	nome: string,
	raridade: number,
	atributos: Atributos,
}
export type Guardado = { item: string, nivel: number, desde: number }
export type Colecao = {
	lista: { [string]: Guardado },
	equipados: { [string]: string }, -- espaço -> uid
	ocultos: { [string]: boolean }, -- espaço -> visual escondido
	contador: number,
}

Equipamento.ESPACOS = { "elmo", "armadura", "manoplas", "botas", "arma" }
Equipamento.NOMES_ESPACOS = {
	elmo = "Elmo",
	armadura = "Armadura",
	manoplas = "Manoplas",
	botas = "Botas",
	arma = "Arma",
}
Equipamento.ATRIBUTOS = { "ganho", "sorte", "dano", "vida", "fragmentos" }
Equipamento.NOMES_ATRIBUTOS = {
	ganho = "Pontos de Aura",
	sorte = "Sorte",
	dano = "Dano",
	vida = "Vida",
	fragmentos = "Fragmentos",
}
Equipamento.RARIDADES = {
	{ nome = "Comum", cor = "B8C1CC" },
	{ nome = "Incomum", cor = "5BE37D" },
	{ nome = "Raro", cor = "4CC9F0" },
	{ nome = "Épico", cor = "A855F7" },
	{ nome = "Lendário", cor = "FFC83D" },
	{ nome = "Mítico", cor = "FF3B6B" },
}

Equipamento.CAPACIDADE = 80
Equipamento.NIVEL_MAXIMO = 10
Equipamento.POR_NIVEL = 0.12 -- +12% nos atributos da peça por nível
Equipamento.DROP_CHEFE = 0.35 -- chance de cada ajudante ganhar uma peça ao derrubar o chefe
Equipamento.DROP_LACAIO = 0.03

-- Atributo principal de cada espaço, no conjunto do mundo 1 (os outros multiplicam)
local BASE: { [string]: Atributos } = {
	elmo = { sorte = 4 },
	armadura = { vida = 15, ganho = 4 },
	manoplas = { dano = 8 },
	botas = { ganho = 10 },
	arma = { dano = 14 },
}
local FORCA_MUNDO = { 1, 2, 3.5, 6, 10, 16 }

Equipamento.CONJUNTOS = {
	{
		id = "limiar",
		fase = 1,
		nome = "Limiar",
		cor = "C0ADFF",
		raridade = 1,
		bonus3 = { sorte = 5 },
		bonus5 = { sorte = 12, ganho = 10 },
		nomes = {
			elmo = "Elmo do Limiar",
			armadura = "Couraça Lascada",
			manoplas = "Manoplas de Cristal",
			botas = "Botas de Pedra Viva",
			arma = "Espada de Cristal",
		},
	},
	{
		id = "bosque",
		fase = 2,
		nome = "Bosque",
		cor = "5AF5CC",
		raridade = 2,
		bonus3 = { ganho = 15 },
		bonus5 = { ganho = 40, fragmentos = 10 },
		nomes = {
			elmo = "Coroa de Folhas de Vidro",
			armadura = "Casca do Ancião",
			manoplas = "Luvas de Galho",
			botas = "Botas de Raiz",
			arma = "Cajado do Bosque",
		},
	},
	{
		id = "dunas",
		fase = 3,
		nome = "Dunas",
		cor = "FF8A3D",
		raridade = 3,
		bonus3 = { dano = 20 },
		bonus5 = { dano = 50, vida = 25 },
		nomes = {
			elmo = "Elmo Chifrudo de Obsidiana",
			armadura = "Peitoral de Brasa",
			manoplas = "Punhos de Magma",
			botas = "Botas de Cinza",
			arma = "Machado de Brasa",
		},
	},
	{
		id = "mare",
		fase = 4,
		nome = "Maré",
		cor = "5CE1FF",
		raridade = 4,
		bonus3 = { vida = 40 },
		bonus5 = { vida = 80, sorte = 20 },
		nomes = {
			elmo = "Elmo de Concha",
			armadura = "Couraça de Coral",
			manoplas = "Manoplas da Maré",
			botas = "Botas Abissais",
			arma = "Tridente da Maré",
		},
	},
	{
		id = "catedral",
		fase = 5,
		nome = "Catedral",
		cor = "FFC83D",
		raridade = 5,
		bonus3 = { fragmentos = 25 },
		bonus5 = { fragmentos = 50, ganho = 80 },
		nomes = {
			elmo = "Elmo Alado",
			armadura = "Armadura do Arcanjo",
			manoplas = "Manoplas de Ouro",
			botas = "Botas de Mármore",
			arma = "Martelo de Luz",
		},
	},
	{
		id = "vazio",
		fase = 6,
		nome = "Vazio",
		cor = "EE5CFF",
		raridade = 6,
		bonus3 = { ganho = 60, sorte = 15 },
		bonus5 = { ganho = 150, sorte = 35, dano = 60 },
		nomes = {
			elmo = "Coroa Estelar",
			armadura = "Manto do Devorador",
			manoplas = "Garras do Vazio",
			botas = "Passos do Vazio",
			arma = "Foice Estelar",
		},
	},
} :: { Conjunto }

Equipamento.porConjunto = {} :: { [string]: Conjunto }
Equipamento.ITENS = {} :: { Item }
Equipamento.porId = {} :: { [string]: Item }
for _, c in Equipamento.CONJUNTOS do
	Equipamento.porConjunto[c.id] = c
	for _, espaco in Equipamento.ESPACOS do
		local atributos: Atributos = {}
		for nome, v in BASE[espaco] do
			(atributos :: any)[nome] = math.floor(v * FORCA_MUNDO[c.fase] + 0.5)
		end
		local item: Item = {
			id = c.id .. "_" .. espaco,
			conjunto = c.id,
			espaco = espaco,
			nome = c.nomes[espaco],
			raridade = c.raridade,
			atributos = atributos,
		}
		table.insert(Equipamento.ITENS, item)
		Equipamento.porId[item.id] = item
	end
end

local function numero(v: any): number
	return if type(v) == "number" and v == v and v >= 0 and v < math.huge then v else 0
end

function Equipamento.padrao(): Colecao
	return { lista = {}, equipados = {}, ocultos = {}, contador = 0 }
end

function Equipamento.normalizar(c: any): Colecao
	local t = if type(c) == "table" then c else {}
	local saida = Equipamento.padrao()
	saida.contador = math.floor(numero(t.contador))
	local n = 0
	if type(t.lista) == "table" then
		for uid, g in t.lista do
			if
				type(uid) == "string"
				and type(g) == "table"
				and type(g.item) == "string"
				and Equipamento.porId[g.item]
				and n < Equipamento.CAPACIDADE
			then
				saida.lista[uid] = {
					item = g.item,
					nivel = math.clamp(math.floor(numero(g.nivel)), 0, Equipamento.NIVEL_MAXIMO),
					desde = numero(g.desde),
				}
				n += 1
			end
		end
	end
	for _, espaco in Equipamento.ESPACOS do
		local uid = if type(t.equipados) == "table" then t.equipados[espaco] else nil
		local g = if type(uid) == "string" then saida.lista[uid] else nil
		if g and Equipamento.porId[g.item].espaco == espaco then
			saida.equipados[espaco] = uid
		end
		if type(t.ocultos) == "table" and t.ocultos[espaco] == true then
			saida.ocultos[espaco] = true
		end
	end
	return saida
end

function Equipamento.quantidade(c: Colecao): number
	local n = 0
	for _ in c.lista do
		n += 1
	end
	return n
end

function Equipamento.adicionar(c: Colecao, item: string, agora: number): string?
	if not Equipamento.porId[item] or Equipamento.quantidade(c) >= Equipamento.CAPACIDADE then
		return nil
	end
	c.contador += 1
	local uid = "q" .. c.contador
	c.lista[uid] = { item = item, nivel = 0, desde = agora }
	return uid
end

-- Atributos de uma peça guardada (com o nível)
function Equipamento.atributos(g: Guardado): Atributos
	local item = Equipamento.porId[g.item]
	local saida: Atributos = {}
	if not item then
		return saida
	end
	local m = 1 + Equipamento.POR_NIVEL * g.nivel
	for nome, v in item.atributos do
		(saida :: any)[nome] = math.floor(v * m + 0.5)
	end
	return saida
end

function Equipamento.equipar(c: Colecao, uid: any, ligar: boolean): (boolean, string?)
	if type(uid) ~= "string" or not c.lista[uid] then
		return false, "Peça desconhecida."
	end
	local espaco = Equipamento.porId[c.lista[uid].item].espaco
	if ligar then
		c.equipados[espaco] = uid
	elseif c.equipados[espaco] == uid then
		c.equipados[espaco] = nil
	end
	return true, nil
end

function Equipamento.ocultar(c: Colecao, espaco: any, oculto: boolean): (boolean, string?)
	if type(espaco) ~= "string" or not Equipamento.NOMES_ESPACOS[espaco] then
		return false, "Espaço desconhecido."
	end
	local ocultos = c.ocultos :: { [string]: any }
	ocultos[espaco] = if oculto then true else nil
	return true, nil
end

-- Fragmentos para subir a peça do nível atual para o próximo (nil no máximo)
function Equipamento.custoAprimorar(g: Guardado): number?
	local item = Equipamento.porId[g.item]
	if not item or g.nivel >= Equipamento.NIVEL_MAXIMO then
		return nil
	end
	local fase = Equipamento.porConjunto[item.conjunto].fase
	return math.floor(5 * 2 ^ (fase - 1) * 1.45 ^ g.nivel + 0.5)
end

-- Fragmentos de volta ao desmontar
function Equipamento.valorDesmontar(g: Guardado): number
	local item = Equipamento.porId[g.item]
	if not item then
		return 0
	end
	local fase = Equipamento.porConjunto[item.conjunto].fase
	return math.floor(3 * 2 ^ (fase - 1) * (1 + 0.5 * g.nivel) + 0.5)
end

function Equipamento.equipado(c: Colecao, uid: string): boolean
	for _, u in c.equipados do
		if u == uid then
			return true
		end
	end
	return false
end

-- Quantas peças equipadas de cada conjunto
function Equipamento.pecasPorConjunto(c: Colecao): { [string]: number }
	local saida: { [string]: number } = {}
	for _, uid in c.equipados do
		local g = c.lista[uid]
		local item = g and Equipamento.porId[g.item]
		if item then
			saida[item.conjunto] = (saida[item.conjunto] or 0) + 1
		end
	end
	return saida
end

-- Soma dos atributos (%) das peças equipadas e dos bônus de conjunto
function Equipamento.total(c: Colecao): { [string]: number }
	local soma: { [string]: number } = {}
	for _, nome in Equipamento.ATRIBUTOS do
		soma[nome] = 0
	end
	for _, uid in c.equipados do
		local g = c.lista[uid]
		if g then
			for nome, v in Equipamento.atributos(g) do
				soma[nome] += v
			end
		end
	end
	for id, n in Equipamento.pecasPorConjunto(c) do
		local conjunto = Equipamento.porConjunto[id]
		if n >= 3 then
			for nome, v in conjunto.bonus3 do
				soma[nome] += v
			end
		end
		if n >= 5 then
			for nome, v in conjunto.bonus5 do
				soma[nome] += v
			end
		end
	end
	return soma
end

-- Multiplicadores (1 = sem bônus) para ganho, sorte, dano, vida e fragmentos
function Equipamento.multiplicadores(c: Colecao): { [string]: number }
	local saida: { [string]: number } = {}
	for nome, v in Equipamento.total(c) do
		saida[nome] = 1 + v / 100
	end
	return saida
end

-- Peça que cai de uma criatura (nil = nada). `aleatorio` devolve [0, 1) (Random do servidor).
function Equipamento.sortearDrop(fase: number, tipo: string, aleatorio: () -> number): string?
	local conjunto = Equipamento.CONJUNTOS[fase]
	if not conjunto then
		return nil
	end
	local chance = if tipo == "chefe" then Equipamento.DROP_CHEFE else Equipamento.DROP_LACAIO
	if aleatorio() >= chance then
		return nil
	end
	local k =
		math.clamp(math.floor(aleatorio() * #Equipamento.ESPACOS) + 1, 1, #Equipamento.ESPACOS)
	return conjunto.id .. "_" .. Equipamento.ESPACOS[k]
end

-- Texto curto dos atributos ("+14% Dano · +4% Pontos de Aura")
function Equipamento.texto(atributos: Atributos): string
	local partes = {}
	for _, nome in Equipamento.ATRIBUTOS do
		local v = (atributos :: any)[nome]
		if v and v > 0 then
			table.insert(partes, string.format("+%d%% %s", v, Equipamento.NOMES_ATRIBUTOS[nome]))
		end
	end
	return table.concat(partes, " · ")
end

return Equipamento
