-- Ecos (pets) e Núcleos. Os Ecos são criaturas guardadas nos Núcleos, as sementes de cristal
-- que sobraram de cada mundo do Corredor dos Perdidos. O Cristal do Nexo, no meio da praça,
-- desperta os Núcleos em troca de Fragmentos. Cada Núcleo pede a fase do seu mundo concluída.
--
-- Um Eco equipado dá bônus de Pontos de Aura (ganho), de Sorte do giro ou de Fragmentos.
-- Raro: o Eco pode nascer PRISMÁTICO (bônus em dobro, brilho de arco-íris).
-- Só regras puras (sem Roblox): o servidor decide tudo com este módulo. Testado em
-- testes/logica.luau. O visual de cada Eco fica em Dados/PetsVisual (gerado pelo Blender).
local Pets = {}

export type Bonus = { ganho: number?, sorte: number?, fragmentos: number? } -- em %
export type Eco = {
	id: string,
	nome: string,
	conceito: string,
	raridade: number, -- índice em Pets.RARIDADES
	nucleo: number,
	bonus: Bonus,
	serie: string?, -- Ecos exclusivos (versão anime): de qual obra vem a inspiração
}
export type Nucleo = {
	numero: number,
	nome: string,
	cor: string,
	preco: number, -- Fragmentos por Núcleo
	fase: number, -- fase do Corredor que precisa estar concluída
	ecos: { { id: string, peso: number } },
	exclusivo: boolean?, -- Núcleos exclusivos (versão anime)
	serie: string?,
}
export type Guardado = { eco: string, prisma: boolean, desde: number }
export type Colecao = {
	lista: { [string]: Guardado }, -- uid -> Eco
	equipados: { string }, -- uids
	contador: number, -- próximo uid
	vistos: { [string]: boolean }, -- índice de Ecos já despertados
}

-- Mesmas cores das raridades das auras
Pets.RARIDADES = {
	{ nome = "Comum", cor = "B8C1CC" },
	{ nome = "Incomum", cor = "5BE37D" },
	{ nome = "Raro", cor = "4CC9F0" },
	{ nome = "Épico", cor = "A855F7" },
	{ nome = "Lendário", cor = "FFC83D" },
	{ nome = "Mítico", cor = "FF3B6B" },
	{ nome = "Divino", cor = "FFFFFF" },
}

Pets.CAPACIDADE = 60
Pets.SLOTS_BASE = 3
-- Concluir estas fases do Corredor abre mais um espaço de Eco equipado
Pets.SLOTS_POR_FASE = { 3, 6 }
Pets.PRISMA_CHANCE = 1 / 50
Pets.PRISMA_MULTIPLICADOR = 2
Pets.DEVOLUCAO = 0.25 -- parte do preço do Núcleo que volta ao libertar um Eco
Pets.ABRIR_MAXIMO = 3 -- Núcleos de uma vez

Pets.ECOS = {
	-- 1 · Limiar Partido: pedra viva e cristal violeta
	{
		id = "lasquinho",
		nome = "Lasquinho",
		conceito = "Uma lasca de cristal que aprendeu a andar. Tem um olho só e muita coragem.",
		raridade = 1,
		nucleo = 1,
		bonus = { ganho = 15 },
	},
	{
		id = "mariposa_vitral",
		nome = "Mariposa de Vitral",
		conceito = "Asas de vidro colorido presas por chumbo. Onde pousa, a sorte acorda.",
		raridade = 2,
		nucleo = 1,
		bonus = { sorte = 6 },
	},
	{
		id = "lanterneiro",
		nome = "Lanterneiro",
		conceito = "Um pedaço de pilar que ainda carrega a lanterna de quem guardava o Limiar.",
		raridade = 3,
		nucleo = 1,
		bonus = { ganho = 45 },
	},
	-- 2 · Bosque de Vidro: flora de vidro verde-água
	{
		id = "sininho_vidro",
		nome = "Sininho de Vidro",
		conceito = "Uma flor-sino que toca quando acha Fragmentos no chão.",
		raridade = 2,
		nucleo = 2,
		bonus = { fragmentos = 15 },
	},
	{
		id = "raposa_prisma",
		nome = "Raposa Prisma",
		conceito = "Raposa de facetas com a cauda de uma folha de cristal.",
		raridade = 3,
		nucleo = 2,
		bonus = { ganho = 70 },
	},
	{
		id = "cervo_cantor",
		nome = "Cervo Cantor",
		conceito = "Os chifres de cristal vibram numa nota que só a sorte escuta.",
		raridade = 4,
		nucleo = 2,
		bonus = { sorte = 18 },
	},
	-- 3 · Dunas de Cinza: obsidiana e brasa
	{
		id = "fagulha",
		nome = "Fagulha",
		conceito = "Uma brasa que não apaga, presa numa gaiola de obsidiana.",
		raridade = 3,
		nucleo = 3,
		bonus = { ganho = 110 },
	},
	{
		id = "escaravelho_solar",
		nome = "Escaravelho Solar",
		conceito = "Empurra um pequeno sol pelas dunas e enterra Fragmentos no caminho.",
		raridade = 4,
		nucleo = 3,
		bonus = { fragmentos = 35 },
	},
	{
		id = "salamandra_obsidiana",
		nome = "Salamandra de Obsidiana",
		conceito = "Rachaduras em brasa nas costas: onde passa, a aura ferve.",
		raridade = 5,
		nucleo = 3,
		bonus = { ganho = 260 },
	},
	-- 4 · Maré Suspensa: água presa no ar
	{
		id = "peixe_bolha",
		nome = "Peixe-Bolha",
		conceito = "Carrega o próprio mar numa bolha e nunca deixa cair uma gota.",
		raridade = 3,
		nucleo = 4,
		bonus = { ganho = 170 },
	},
	{
		id = "aguaviva_lanterna",
		nome = "Água-viva Lanterna",
		conceito = "Flutua devagar iluminando caminhos que a sorte esqueceu.",
		raridade = 4,
		nucleo = 4,
		bonus = { sorte = 30 },
	},
	{
		id = "baleia_celeste",
		nome = "Baleia Celeste",
		conceito = "Uma baleia do tamanho de um gato, com nuvens e estrelas nas costas.",
		raridade = 5,
		nucleo = 4,
		bonus = { ganho = 450 },
	},
	-- 5 · Catedral Quebrada: mármore, ouro e vitral
	{
		id = "sino_alado",
		nome = "Sino Alado",
		conceito = "Fugiu da torre da Catedral e ainda toca a cada hora cheia.",
		raridade = 4,
		nucleo = 5,
		bonus = { ganho = 320 },
	},
	{
		id = "coruja_vitral",
		nome = "Coruja Rosácea",
		conceito = "O rosto é uma rosácea de vitral: vê as chances que ninguém vê.",
		raridade = 5,
		nucleo = 5,
		bonus = { sorte = 45 },
	},
	{
		id = "querubim_partido",
		nome = "Querubim Partido",
		conceito = "A cabeça de uma estátua de anjo, rachada em ouro, que ainda sonha.",
		raridade = 6,
		nucleo = 5,
		bonus = { ganho = 900 },
	},
	-- 6 · Coração do Vazio: facetas escuras costuradas por estrelas
	{
		id = "olho_errante",
		nome = "Olho Errante",
		conceito = "Um olho que gira entre dois aros e nunca pisca diante do acaso.",
		raridade = 5,
		nucleo = 6,
		bonus = { sorte = 60 },
	},
	{
		id = "gato_constelacao",
		nome = "Gato Constelação",
		conceito = "Feito de noite e ligado por estrelas. Traz Fragmentos como presente.",
		raridade = 6,
		nucleo = 6,
		bonus = { fragmentos = 80 },
	},
	{
		id = "dragao_estelar",
		nome = "Dragão Estelar",
		conceito = "Uma constelação inteira que decidiu ter forma de dragão.",
		raridade = 7,
		nucleo = 6,
		bonus = { ganho = 2200 },
	},
	-- Exclusivos (versão anime): releituras chibi próprias inspiradas em Naruto, One Piece e
	-- Solo Leveling. Nomes autorizados pelo dono como referência (CLAUDE.md); modelos originais.
	-- 7 · Núcleo da Folha (Naruto)
	{
		id = "sapo_invocado",
		nome = "Sapinho Invocado",
		conceito = "Chega numa nuvem de fumaça com um pergaminho nas costas e pronto para a missão.",
		raridade = 4,
		nucleo = 7,
		bonus = { ganho = 400 },
		serie = "Naruto",
	},
	{
		id = "cao_ninja",
		nome = "Cão Ninja",
		conceito = "De colete e bandana, fareja Fragmentos a quilômetros. Reclama de tudo, mas nunca falha.",
		raridade = 5,
		nucleo = 7,
		bonus = { fragmentos = 60 },
		serie = "Naruto",
	},
	{
		id = "kurama_chibi",
		nome = "Kurama Chibi",
		conceito = "Nove caudas, olhos vermelhos e pouca paciência. Empresta o chakra só para quem merece.",
		raridade = 6,
		nucleo = 7,
		bonus = { ganho = 1500 },
		serie = "Naruto",
	},
	-- 8 · Núcleo do Grand Line (One Piece)
	{
		id = "den_den_mushi",
		nome = "Den Den Mushi",
		conceito = "Um caracol-telefone que sempre atende quando a sorte liga.",
		raridade = 4,
		nucleo = 8,
		bonus = { sorte = 25 },
		serie = "One Piece",
	},
	{
		id = "rena_doutora",
		nome = "Rena Doutora",
		conceito = "Nariz azul, chapéu rosa e um remédio para cada tropeço da sua aura.",
		raridade = 5,
		nucleo = 8,
		bonus = { ganho = 700 },
		serie = "One Piece",
	},
	{
		id = "nika_chibi",
		nome = "Nika Chibi",
		conceito = "Uma nuvem que ri sem parar, de chapéu de palha e cabelo de chama branca.",
		raridade = 6,
		nucleo = 8,
		bonus = { ganho = 2500 },
		serie = "One Piece",
	},
	-- 9 · Núcleo das Sombras (Solo Leveling)
	{
		id = "soldado_sombrio",
		nome = "Soldado Sombrio",
		conceito = "Levantou-se da sombra de um inimigo derrotado e agora só obedece a você.",
		raridade = 4,
		nucleo = 9,
		bonus = { fragmentos = 50 },
		serie = "Solo Leveling",
	},
	{
		id = "beru_chibi",
		nome = "Beru Chibi",
		conceito = "O rei-formiga das sombras, em miniatura e com asas que zunem quando a sorte passa.",
		raridade = 5,
		nucleo = 9,
		bonus = { sorte = 70 },
		serie = "Solo Leveling",
	},
	{
		id = "igris_chibi",
		nome = "Igris Chibi",
		conceito = "O cavaleiro de penacho vermelho. Pequeno, leal e mais forte que tudo no Nexo.",
		raridade = 7,
		nucleo = 9,
		bonus = { ganho = 4000 },
		serie = "Solo Leveling",
	},
} :: { Eco }

Pets.porId = {} :: { [string]: Eco }
for _, e in Pets.ECOS do
	Pets.porId[e.id] = e
end

Pets.NUCLEOS = {
	{
		numero = 1,
		nome = "Núcleo do Limiar",
		cor = "C0ADFF",
		preco = 8,
		fase = 1,
		ecos = {
			{ id = "lasquinho", peso = 72 },
			{ id = "mariposa_vitral", peso = 24 },
			{ id = "lanterneiro", peso = 4 },
		},
	},
	{
		numero = 2,
		nome = "Núcleo do Bosque",
		cor = "5AF5CC",
		preco = 20,
		fase = 2,
		ecos = {
			{ id = "sininho_vidro", peso = 70 },
			{ id = "raposa_prisma", peso = 26 },
			{ id = "cervo_cantor", peso = 4 },
		},
	},
	{
		numero = 3,
		nome = "Núcleo das Dunas",
		cor = "FF8A3D",
		preco = 50,
		fase = 3,
		ecos = {
			{ id = "fagulha", peso = 70 },
			{ id = "escaravelho_solar", peso = 26 },
			{ id = "salamandra_obsidiana", peso = 4 },
		},
	},
	{
		numero = 4,
		nome = "Núcleo da Maré",
		cor = "5CE1FF",
		preco = 120,
		fase = 4,
		ecos = {
			{ id = "peixe_bolha", peso = 70 },
			{ id = "aguaviva_lanterna", peso = 26 },
			{ id = "baleia_celeste", peso = 4 },
		},
	},
	{
		numero = 5,
		nome = "Núcleo da Catedral",
		cor = "FFC83D",
		preco = 300,
		fase = 5,
		ecos = {
			{ id = "sino_alado", peso = 70 },
			{ id = "coruja_vitral", peso = 27 },
			{ id = "querubim_partido", peso = 3 },
		},
	},
	{
		numero = 6,
		nome = "Núcleo do Vazio",
		cor = "EE5CFF",
		preco = 700,
		fase = 6,
		ecos = {
			{ id = "olho_errante", peso = 70 },
			{ id = "gato_constelacao", peso = 27 },
			{ id = "dragao_estelar", peso = 3 },
		},
	},
	-- Exclusivos (versão anime): mais caros e só com Ecos Épicos para cima
	{
		numero = 7,
		nome = "Núcleo da Folha",
		cor = "FF8A1F",
		preco = 150,
		fase = 2,
		exclusivo = true,
		serie = "Naruto",
		ecos = {
			{ id = "sapo_invocado", peso = 70 },
			{ id = "cao_ninja", peso = 27 },
			{ id = "kurama_chibi", peso = 3 },
		},
	},
	{
		numero = 8,
		nome = "Núcleo do Grand Line",
		cor = "4AA8FF",
		preco = 400,
		fase = 4,
		exclusivo = true,
		serie = "One Piece",
		ecos = {
			{ id = "den_den_mushi", peso = 70 },
			{ id = "rena_doutora", peso = 27 },
			{ id = "nika_chibi", peso = 3 },
		},
	},
	{
		numero = 9,
		nome = "Núcleo das Sombras",
		cor = "8C5CFF",
		preco = 900,
		fase = 6,
		exclusivo = true,
		serie = "Solo Leveling",
		ecos = {
			{ id = "soldado_sombrio", peso = 70 },
			{ id = "beru_chibi", peso = 27 },
			{ id = "igris_chibi", peso = 3 },
		},
	},
} :: { Nucleo }

local function numero(v: any): number
	return if type(v) == "number" and v == v and v >= 0 and v < math.huge then v else 0
end

function Pets.padrao(): Colecao
	return { lista = {}, equipados = {}, contador = 0, vistos = {} }
end

function Pets.normalizar(c: any): Colecao
	local t = if type(c) == "table" then c else {}
	local saida = Pets.padrao()
	saida.contador = math.floor(numero(t.contador))
	local n = 0
	if type(t.lista) == "table" then
		for uid, g in t.lista do
			if
				type(uid) == "string"
				and type(g) == "table"
				and type(g.eco) == "string"
				and Pets.porId[g.eco]
				and n < Pets.CAPACIDADE
			then
				saida.lista[uid] =
					{ eco = g.eco, prisma = g.prisma == true, desde = numero(g.desde) }
				n += 1
			end
		end
	end
	if type(t.equipados) == "table" then
		local vistos: { [string]: boolean } = {}
		for _, uid in t.equipados do
			if type(uid) == "string" and saida.lista[uid] and not vistos[uid] then
				table.insert(saida.equipados, uid)
				vistos[uid] = true
			end
		end
	end
	if type(t.vistos) == "table" then
		for id, v in t.vistos do
			if type(id) == "string" and Pets.porId[id] and v == true then
				saida.vistos[id] = true
			end
		end
	end
	for _, g in saida.lista do
		saida.vistos[g.eco] = true
	end
	return saida
end

function Pets.quantidade(c: Colecao): number
	local n = 0
	for _ in c.lista do
		n += 1
	end
	return n
end

-- Espaços de Eco equipado: 3 + um por fase marco do Corredor concluída
function Pets.slots(corredor: any): number
	local n = Pets.SLOTS_BASE
	local concluidas = if type(corredor) == "table"
			and type(corredor.concluidas) == "table"
		then corredor.concluidas
		else {}
	for _, fase in Pets.SLOTS_POR_FASE do
		if (tonumber(concluidas[tostring(fase)]) or 0) > 0 then
			n += 1
		end
	end
	return n
end

-- O Núcleo está aberto para quem concluiu a fase do mundo dele?
function Pets.nucleoLiberado(nucleo: Nucleo, corredor: any): boolean
	local concluidas = if type(corredor) == "table"
			and type(corredor.concluidas) == "table"
		then corredor.concluidas
		else {}
	return (tonumber(concluidas[tostring(nucleo.fase)]) or 0) > 0
end

-- Chance de cada Eco do Núcleo (0..1), na ordem do Núcleo
function Pets.chances(nucleo: Nucleo): { { id: string, chance: number } }
	local total = 0
	for _, e in nucleo.ecos do
		total += e.peso
	end
	local saida = {}
	for _, e in nucleo.ecos do
		table.insert(saida, { id = e.id, chance = e.peso / total })
	end
	return saida
end

-- Sorteia um Eco do Núcleo. `aleatorio` devolve [0, 1) (Random do servidor).
function Pets.sortear(nucleo: Nucleo, aleatorio: () -> number): (string, boolean)
	local total = 0
	for _, e in nucleo.ecos do
		total += e.peso
	end
	local alvo = aleatorio() * total
	local escolhido = nucleo.ecos[#nucleo.ecos].id
	local acumulado = 0
	for _, e in nucleo.ecos do
		acumulado += e.peso
		if alvo < acumulado then
			escolhido = e.id
			break
		end
	end
	return escolhido, aleatorio() < Pets.PRISMA_CHANCE
end

function Pets.adicionar(c: Colecao, eco: string, prisma: boolean, agora: number): string?
	if not Pets.porId[eco] or Pets.quantidade(c) >= Pets.CAPACIDADE then
		return nil
	end
	c.contador += 1
	local uid = "e" .. c.contador
	c.lista[uid] = { eco = eco, prisma = prisma, desde = agora }
	c.vistos[eco] = true
	return uid
end

-- Força de um Eco guardado (soma dos bônus em %, já com o prisma), para ordenar
function Pets.forca(g: Guardado): number
	local e = Pets.porId[g.eco]
	if not e then
		return 0
	end
	local b = e.bonus
	local m = if g.prisma then Pets.PRISMA_MULTIPLICADOR else 1
	-- sorte vale mais por ponto (é mais rara), fragmentos um pouco mais que ganho
	return ((b.ganho or 0) + (b.sorte or 0) * 4 + (b.fragmentos or 0) * 2) * m
end

function Pets.equipado(c: Colecao, uid: string): boolean
	for _, u in c.equipados do
		if u == uid then
			return true
		end
	end
	return false
end

function Pets.equipar(c: Colecao, uid: any, ligar: boolean, slots: number): (boolean, string?)
	if type(uid) ~= "string" or not c.lista[uid] then
		return false, "Eco desconhecido."
	end
	if ligar then
		if Pets.equipado(c, uid) then
			return true, nil
		end
		if #c.equipados >= slots then
			return false, string.format("Você só pode levar %d Ecos por vez.", slots)
		end
		table.insert(c.equipados, uid)
	else
		for i, u in c.equipados do
			if u == uid then
				table.remove(c.equipados, i)
				break
			end
		end
	end
	return true, nil
end

-- Equipa os mais fortes que couberem
function Pets.equiparMelhores(c: Colecao, slots: number)
	local uids = {}
	for uid in c.lista do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		local fa, fb = Pets.forca(c.lista[a]), Pets.forca(c.lista[b])
		if fa == fb then
			return a < b
		end
		return fa > fb
	end)
	c.equipados = {}
	for i = 1, math.min(slots, #uids) do
		table.insert(c.equipados, uids[i])
	end
end

-- Liberta um Eco (some da coleção) e devolve os Fragmentos de volta
function Pets.libertar(c: Colecao, uid: any): (number?, string?)
	if type(uid) ~= "string" or not c.lista[uid] then
		return nil, "Eco desconhecido."
	end
	if Pets.equipado(c, uid) then
		return nil, "Desequipe o Eco antes de libertá-lo."
	end
	local e = Pets.porId[c.lista[uid].eco]
	c.lista[uid] = nil
	local nucleo = Pets.NUCLEOS[e.nucleo]
	return math.floor(nucleo.preco * Pets.DEVOLUCAO), nil
end

-- Multiplicadores dos Ecos equipados: ganho de Pontos, sorte e Fragmentos (1 = sem bônus)
function Pets.multiplicadores(c: Colecao): (number, number, number)
	local ganho, sorte, frag = 0, 0, 0
	for _, uid in c.equipados do
		local g = c.lista[uid]
		local e = g and Pets.porId[g.eco]
		if g and e then
			local m = if g.prisma then Pets.PRISMA_MULTIPLICADOR else 1
			ganho += (e.bonus.ganho or 0) * m
			sorte += (e.bonus.sorte or 0) * m
			frag += (e.bonus.fragmentos or 0) * m
		end
	end
	return 1 + ganho / 100, 1 + sorte / 100, 1 + frag / 100
end

-- Texto curto do bônus ("+45% Pontos", "+6% Sorte", "+15% Fragmentos")
function Pets.textoBonus(eco: Eco, prisma: boolean?): string
	local m = if prisma then Pets.PRISMA_MULTIPLICADOR else 1
	local b = eco.bonus
	if b.sorte then
		return string.format("+%d%% Sorte", b.sorte * m)
	elseif b.fragmentos then
		return string.format("+%d%% Fragmentos", b.fragmentos * m)
	end
	return string.format("+%d%% Pontos de Aura", (b.ganho or 0) * m)
end

return Pets
