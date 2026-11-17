-- Catálogo independente das auras. IDs são parte do formato do save.
local Itens = {}

export type Estoque = { [string]: number }
export type Item = {
	id: string,
	nome: string,
	raridade: number,
	categoria: string,
	origem: string,
	descricao: string,
	uso: string,
	limitePilha: number,
}

Itens.Tiers = {
	{ nome = "Comum", cor = "B8C1CC", icone = "○" },
	{ nome = "Incomum", cor = "5BE37D", icone = "◇" },
	{ nome = "Raro", cor = "4CC9F0", icone = "△" },
	{ nome = "Épico", cor = "A855F7", icone = "✧" },
	{ nome = "Lendário", cor = "FFC83D", icone = "◆" },
	{ nome = "Mítico", cor = "FF3B6B", icone = "✦" },
	{ nome = "Divino", cor = "FFFFFF", icone = "★" },
}

local function item(
	nome: string,
	raridade: number,
	categoria: string,
	origem: string,
	descricao: string,
	uso: string
): Item
	return {
		id = "",
		nome = nome,
		raridade = raridade,
		categoria = categoria,
		origem = origem,
		descricao = descricao,
		uso = uso,
		limitePilha = if categoria == "Artefatos" then 1 else 999999,
	}
end

Itens.porId = {
	estilhaco_bruto = item(
		"Estilhaço Bruto",
		1,
		"Materiais",
		"Andares de incursão",
		"Pedra de uma dimensão partida.",
		"Recurso básico da Forja."
	),
	cinza_persistente = item(
		"Cinza Persistente",
		1,
		"Materiais",
		"Incursão de Cinzas",
		"Cinza que carrega o calor da fenda.",
		"Coração da Ressonância."
	),
	sal_mare_morta = item(
		"Sal da Maré Morta",
		1,
		"Materiais",
		"Maré Morta",
		"Cristais de sal de uma maré extinta.",
		"Receitas da Maré Morta."
	),
	po_umbral = item(
		"Pó do Ocaso",
		1,
		"Materiais",
		"Crepúsculo Umbral",
		"Poeira acumulada no limite da sombra.",
		"Receitas de Umbral."
	),
	lasca_estavel = item(
		"Lasca Estável",
		2,
		"Materiais",
		"Forja e incursões",
		"Uma faceta estabilizada pela ressonância.",
		"Coração da Fenda e outras receitas."
	),
	selo_purificacao = item(
		"Selo de Purificação",
		2,
		"Materiais",
		"Purificar um andar",
		"A marca deixada por um Núcleo purificado.",
		"Coração da Fenda."
	),
	fragmento_instavel = item(
		"Fragmento Instável",
		2,
		"Materiais",
		"Andares avançados",
		"Matéria que pulsa fora de ritmo.",
		"Receitas de artefatos."
	),
	brasa_arauto = item(
		"Brasa do Arauto",
		3,
		"Materiais",
		"Guardião de Cinzas",
		"A última brasa do Arauto.",
		"Forja avançada e Transcendência."
	),
	perola_abissal = item(
		"Pérola Abissal",
		3,
		"Materiais",
		"Guardiã da Maré Morta",
		"O brilho preservado nas profundezas.",
		"Forja avançada e Transcendência."
	),
	veu_ocaso = item(
		"Véu do Ocaso",
		3,
		"Materiais",
		"Guardião de Umbral",
		"Um fio do manto do crepúsculo.",
		"Forja avançada e Transcendência."
	),
	coracao_fenda = item(
		"Coração da Fenda",
		4,
		"Materiais",
		"Forja no Altar",
		"Uma fenda contida dentro de um núcleo.",
		"Ingrediente do Coração da Ressonância."
	),
	emblema_guardiao = item(
		"Emblema do Guardião",
		4,
		"Artefatos",
		"Forja avançada",
		"Uma insígnia forjada com marcas de guardiões.",
		"Equipar para melhorar a defesa em incursões."
	),
	coracao_ressonancia = item(
		"Coração da Ressonância",
		5,
		"Consumíveis",
		"Forja no Altar",
		"Um núcleo pronto para ser oferecido ao Altar.",
		"Consumido ao Transcender."
	),
	lamina_nexo = item(
		"Lâmina do Nexo",
		5,
		"Artefatos",
		"Forja avançada",
		"Uma lâmina cerimonial de energia concentrada.",
		"Visual cosmético ao equipar."
	),
	essencia_primordial = item(
		"Essência Primordial",
		6,
		"Materiais",
		"Conteúdo avançado futuro",
		"Vestígio de um universo anterior ao Nexo.",
		"Receita avançada futura."
	),
	semente_absoluto = item(
		"Semente do Absoluto",
		7,
		"Materiais",
		"Evento futuro",
		"O início de um universo preso numa semente.",
		"Troféu colecionável."
	),
} :: { [string]: Item }

for id, dado in Itens.porId do
	dado.id = id
	table.freeze(dado)
end
table.freeze(Itens.porId)

local function inteiroPositivo(qtd: any): boolean
	return type(qtd) == "number" and qtd >= 1 and qtd < math.huge and qtd % 1 == 0
end

function Itens.sanitizar(estoque: any): Estoque
	local valido: Estoque = {}
	if type(estoque) == "table" then
		for id, dado in Itens.porId do
			local qtd = estoque[id]
			if inteiroPositivo(qtd) then
				valido[id] = math.min(qtd, dado.limitePilha)
			end
		end
	end
	return valido
end

function Itens.normalizarInventario(
	inventario: any
): { itens: Estoque, equipados: { artefato: string? } }
	local itens = Itens.sanitizar(if type(inventario) == "table" then inventario.itens else nil)
	local equipados = if type(inventario) == "table"
			and type(inventario.equipados) == "table"
		then inventario.equipados
		else {}
	local artefato = equipados.artefato
	local dado = if type(artefato) == "string" then Itens.porId[artefato] else nil
	return {
		itens = itens,
		equipados = {
			artefato = if dado
					and dado.categoria == "Artefatos"
					and itens[dado.id]
				then dado.id
				else nil,
		},
	}
end

function Itens.possui(estoque: Estoque, id: string, qtd: number): boolean
	return Itens.porId[id] ~= nil and inteiroPositivo(qtd) and (estoque[id] or 0) >= qtd
end

-- Retorna a quantidade efetivamente creditada. Pilha cheia nunca excede o limite.
function Itens.conceder(estoque: Estoque, id: string, qtd: number): number
	local dado = Itens.porId[id]
	if not dado or not inteiroPositivo(qtd) then
		return 0
	end
	local antes = estoque[id] or 0
	local ganho = math.min(qtd, dado.limitePilha - antes)
	if ganho > 0 then
		estoque[id] = antes + ganho
	end
	return ganho
end

function Itens.consumir(estoque: Estoque, id: string, qtd: number): boolean
	if not Itens.possui(estoque, id, qtd) then
		return false
	end
	local saldo = estoque[id] - qtd
	estoque[id] = if saldo > 0 then saldo else nil
	return true
end

return Itens
