-- Itens da Loja (ver docs/design/08-loja.png)
-- Melhorias custam moedas e têm níveis; boosts custam granulados; passes custam Robux.
local Loja = {}

export type Melhoria = {
	id: string,
	nome: string,
	descricao: string,
	icone: string,
	cor: string, -- chave de Tema.Botoes
	custos: { number }, -- custo de cada nível (o tamanho define o nível máximo)
}

export type Boost = {
	id: string,
	nome: string,
	descricao: string,
	icone: string,
	cor: string,
	custoGranulados: number,
	duracao: number, -- segundos
	popular: boolean?,
}

export type Passe = {
	id: string,
	nome: string,
	descricao: string,
	icone: string,
	gamePassId: number, -- 0 = ainda não criado no Roblox
	precoRobux: number,
}

Loja.Melhorias = {
	{
		id = "vitrine",
		nome = "Vitrine Maior",
		descricao = "+4 espaços para Docinhos",
		icone = "🏪",
		cor = "ouro",
		custos = { 5000, 20000, 50000, 200000, 1000000 },
	},
	{
		id = "escudo",
		nome = "Escudo Reforçado",
		descricao = "Escudo dura +15 segundos",
		icone = "🛡️",
		cor = "azul",
		custos = { 8000, 30000, 100000, 400000, 1500000 },
	},
	{
		id = "tenis",
		nome = "Tênis Rápido",
		descricao = "Anda mais rápido carregando Docinhos",
		icone = "👟",
		cor = "verde",
		custos = { 5000, 20000, 80000, 300000, 1000000 },
	},
	{
		id = "caixa",
		nome = "Caixa Maior",
		descricao = "Guarda moedas offline por mais 2 horas",
		icone = "⏱️",
		cor = "laranja",
		custos = { 120000, 600000, 3000000 },
	},
} :: { Melhoria }

Loja.Boosts = {
	{
		id = "sorte",
		nome = "Esteira da Sorte",
		descricao = "2x chance de Raro na esteira por 15 min",
		icone = "🍀",
		cor = "roxo",
		custoGranulados = 40,
		duracao = 15 * 60,
		popular = true,
	},
	{
		id = "moedas2x",
		nome = "Moedas em Dobro",
		descricao = "Sua vitrine rende 2x por 15 min",
		icone = "🪙",
		cor = "ouro",
		custoGranulados = 60,
		duracao = 15 * 60,
	},
} :: { Boost }

Loja.Passes = {
	{
		id = "vip",
		nome = "Confeiteiro VIP",
		descricao = "2x moedas para sempre · etiqueta VIP · 1 Docinho exclusivo",
		icone = "👑",
		gamePassId = 0,
		precoRobux = 199,
	},
} :: { Passe }

local melhoriaPorId: { [string]: Melhoria } = {}
for _, m in Loja.Melhorias do
	melhoriaPorId[m.id] = m
end
local boostPorId: { [string]: Boost } = {}
for _, b in Loja.Boosts do
	boostPorId[b.id] = b
end
local passePorId: { [string]: Passe } = {}
for _, p in Loja.Passes do
	passePorId[p.id] = p
end

function Loja.melhoria(id: string): Melhoria?
	return melhoriaPorId[id]
end

function Loja.boost(id: string): Boost?
	return boostPorId[id]
end

function Loja.passe(id: string): Passe?
	return passePorId[id]
end

-- Custo para subir do nível atual para o próximo; nil se já está no máximo
function Loja.proximoCusto(id: string, nivelAtual: number): number?
	local m = melhoriaPorId[id]
	if not m then
		return nil
	end
	return m.custos[nivelAtual + 1]
end

return Loja
