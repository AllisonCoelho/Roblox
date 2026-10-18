-- Catálogo dos Docinhos, raridades e variantes (ver docs/design/02-docinhos.png)
-- Renda e preço são valores iniciais para balancear depois.
local Catalogo = {}

export type Raridade = {
	id: string,
	nome: string,
	ordem: number,
	cor: Color3,
	brilho: Color3,
}

export type Docinho = {
	id: string,
	nome: string,
	raridade: string,
	renda: number, -- moedas por segundo
	preco: number, -- preço na esteira
	descricao: string,
}

export type Variante = {
	id: string,
	nome: string,
	multiplicador: number,
	chance: number, -- 1 em N
}

local function raridade(id, nome, ordem, cor, brilho): Raridade
	return {
		id = id,
		nome = nome,
		ordem = ordem,
		cor = Color3.fromHex(cor),
		brilho = Color3.fromHex(brilho),
	}
end

Catalogo.Raridades = {
	comum = raridade("comum", "Comum", 1, "B3A68F", "F3EDE2"),
	incomum = raridade("incomum", "Incomum", 2, "3DDC97", "C9F7E2"),
	raro = raridade("raro", "Raro", 3, "4CC9F0", "D2F2FC"),
	epico = raridade("epico", "Épico", 4, "8B5CF6", "E3D5FF"),
	lendario = raridade("lendario", "Lendário", 5, "FFC83D", "FFF1C2"),
	mitico = raridade("mitico", "Mítico", 6, "FF4F7B", "FFD3DF"),
	secreto = raridade("secreto", "Secreto", 7, "1A1026", "5B4A7A"),
} :: { [string]: Raridade }

Catalogo.Variantes = {
	normal = { id = "normal", nome = "Normal", multiplicador = 1, chance = 1 },
	dourado = { id = "dourado", nome = "Dourado", multiplicador = 2, chance = 20 },
	arcoiris = { id = "arcoiris", nome = "Arco-íris", multiplicador = 5, chance = 200 },
} :: { [string]: Variante }

-- Ordem do álbum
Catalogo.Lista = {
	{
		id = "balaDeCoco",
		nome = "Bala de Coco",
		raridade = "comum",
		renda = 1,
		preco = 25,
		descricao = "Docinha e enroladinha no papel.",
	},
	{
		id = "beijinho",
		nome = "Beijinho Fofinho",
		raridade = "comum",
		renda = 2,
		preco = 60,
		descricao = "Sempre de olhinhos fechados e feliz.",
	},
	{
		id = "pacoca",
		nome = "Paçoca Ninja",
		raridade = "incomum",
		renda = 8,
		preco = 400,
		descricao = "Esfarela os inimigos. E a si mesma.",
	},
	{
		id = "peDeMoleque",
		nome = "Pé-de-Moleque Skatista",
		raridade = "incomum",
		renda = 12,
		preco = 750,
		descricao = "Manobra radical com amendoim.",
	},
	{
		id = "cocada",
		nome = "Cocada Surfista",
		raridade = "raro",
		renda = 45,
		preco = 5000,
		descricao = "Pega onda no mar de leite condensado.",
	},
	{
		id = "quindim",
		nome = "Quindim Cantor",
		raridade = "raro",
		renda = 70,
		preco = 9000,
		descricao = "Canta tão bem que brilha.",
	},
	{
		id = "brigadeiro",
		nome = "Brigadeiro Turbo",
		raridade = "epico",
		renda = 300,
		preco = 80000,
		descricao = "O docinho mais rápido de qualquer festa.",
	},
	{
		id = "pudim",
		nome = "Pudim Astronauta",
		raridade = "lendario",
		renda = 1500,
		preco = 1200000,
		descricao = "Já foi à Lua e voltou sem derreter.",
	},
	{
		id = "boloDeRolo",
		nome = "Bolo de Rolo Mago",
		raridade = "mitico",
		renda = 9000,
		preco = 15000000,
		descricao = "Cada camada guarda um feitiço.",
	},
	{
		id = "coxinha",
		nome = "Coxinha Doce Misteriosa",
		raridade = "secreto",
		renda = 60000,
		preco = 0,
		descricao = "Ninguém sabe de onde ela veio.",
	},
} :: { Docinho }

local porId: { [string]: Docinho } = {}
for _, d in Catalogo.Lista do
	porId[d.id] = d
end

function Catalogo.docinho(id: string): Docinho?
	return porId[id]
end

function Catalogo.raridadeDe(id: string): Raridade?
	local d = porId[id]
	return d and Catalogo.Raridades[d.raridade]
end

function Catalogo.rendaDe(id: string, variante: string?): number
	local d = porId[id]
	if not d then
		return 0
	end
	local v = Catalogo.Variantes[variante or "normal"] or Catalogo.Variantes.normal
	return d.renda * v.multiplicador
end

return Catalogo
