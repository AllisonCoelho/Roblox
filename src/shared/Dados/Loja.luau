-- Itens da Loja (ver docs/design/08-loja.png)
-- Melhorias custam moedas e têm níveis; boosts custam granulados; pacotes de granulados
-- e passes custam Robux (ver docs/design/11-loja-granulados.png).
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

export type Pacote = {
	id: string,
	nome: string,
	descricao: string,
	icone: string,
	granulados: number,
	productId: number, -- 0 = ainda não criado no Roblox (Developer Product)
	precoRobux: number,
	etiqueta: string?, -- "POPULAR", "MELHOR VALOR"...
}

Loja.Melhorias = {
	{
		id = "vitrine",
		nome = "Vitrine Maior",
		descricao = "+4 espaços para Docinhos",
		icone = "🏪",
		cor = "ouro",
		-- Ajustado pela simulação (testes/simulacao.luau): nível máximo perto de 1 h de jogo
		custos = { 5000, 25000, 150000, 750000, 4000000 },
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
		descricao = "2x moedas para sempre · coroa VIP no personagem · +10 ✨ no presente diário",
		icone = "👑",
		gamePassId = 0,
		precoRobux = 199,
	},
} :: { Passe }

-- Developer Products: podem ser comprados várias vezes. Crie cada um no Creator Hub
-- (Monetização > Produtos de desenvolvedor) e cole o id em productId.
Loja.Pacotes = {
	{
		id = "punhado",
		nome = "120 granulados",
		descricao = "Um punhadinho de granulados",
		icone = "✨",
		granulados = 120,
		productId = 0,
		precoRobux = 25,
	},
	{
		id = "potinho",
		nome = "400 granulados",
		descricao = "Um potinho cheio (+20% de bônus)",
		icone = "🧁",
		granulados = 400,
		productId = 0,
		precoRobux = 69,
		etiqueta = "POPULAR",
	},
	{
		id = "lata",
		nome = "1.100 granulados",
		descricao = "Uma lata de granulados (+35% de bônus)",
		icone = "🍰",
		granulados = 1100,
		productId = 0,
		precoRobux = 169,
	},
	{
		id = "caminhao",
		nome = "3.000 granulados",
		descricao = "Um caminhão de granulados (+60% de bônus)",
		icone = "🎂",
		granulados = 3000,
		productId = 0,
		precoRobux = 389,
		etiqueta = "MELHOR VALOR",
	},
} :: { Pacote }

-- Granulados a mais no presente diário para quem tem o VIP
Loja.BonusPresenteVip = 10

-- Quantas compras recentes guardamos para não entregar a mesma duas vezes
Loja.MaxRecibos = 50

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
local pacotePorId: { [string]: Pacote } = {}
local pacotePorProduto: { [number]: Pacote } = {}
for _, p in Loja.Pacotes do
	pacotePorId[p.id] = p
	if p.productId ~= 0 then
		pacotePorProduto[p.productId] = p
	end
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

function Loja.pacote(id: string): Pacote?
	return pacotePorId[id]
end

function Loja.pacoteDoProduto(productId: number): Pacote?
	return pacotePorProduto[productId]
end

-- Entrega uma compra de Robux (ProcessReceipt) no estado do jogador
-- (pacote = Loja.pacoteDoProduto(ProductId)).
-- Devolve "entregue" (granulados somados agora), "repetida" (esta compra já foi entregue)
-- ou "invalida" (produto desconhecido). A lista de recibos evita entregar duas vezes
-- quando o Roblox chama de novo (ex.: o salvamento anterior falhou).
function Loja.aplicarRecibo(
	estado: { granulados: number, recibos: { string } },
	compraId: string,
	pacote: Pacote?
): string
	if table.find(estado.recibos, compraId) then
		return "repetida"
	end
	if not pacote then
		return "invalida"
	end
	estado.granulados += pacote.granulados
	table.insert(estado.recibos, compraId)
	while #estado.recibos > Loja.MaxRecibos do
		table.remove(estado.recibos, 1)
	end
	return "entregue"
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
