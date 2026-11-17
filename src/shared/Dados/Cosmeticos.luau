-- Cosméticos do Despertar (lógica pura, testada). Só aparência: título sobre a cabeça,
-- distintivo ao lado do nome (também no chat) e rastro ao andar. Nada muda poder nem chance.
--
-- Origem de cada item: pacote pago (Iniciante, VIP), trilha da Temporada (grátis ou premium).
-- Salvo em perfil.cosmeticos = { possui = { [id] = true }, equipados = { titulo, distintivo, rastro } }
local Cosmeticos = {}

export type Item = {
	id: string,
	tipo: string, -- "titulo" | "distintivo" | "rastro"
	nome: string,
	texto: string, -- título: o texto; distintivo: o símbolo; rastro: descrição
	cor: string, -- hex
	cor2: string?, -- rastro: segunda cor do degradê
	origem: string, -- "iniciante" | "vip" | "temporada"
}

Cosmeticos.TIPOS = { "titulo", "distintivo", "rastro" }

local function item(id, tipo, nome, texto, cor, origem, cor2): Item
	return {
		id = id,
		tipo = tipo,
		nome = nome,
		texto = texto,
		cor = cor,
		origem = origem,
		cor2 = cor2,
	}
end

Cosmeticos.ITENS = {
	-- Pacote do Iniciante
	item("tit_despertado", "titulo", "Despertado", "Despertado", "B8F2FF", "iniciante"),
	item("dis_broto", "distintivo", "Broto do Nexo", "🌱", "7BF0A0", "iniciante"),
	item(
		"ras_faisca",
		"rastro",
		"Rastro de Faíscas",
		"Faíscas douradas ao correr",
		"FFF1A8",
		"iniciante",
		"FFB13D"
	),
	-- VIP do Nexo
	item("tit_vip", "titulo", "VIP do Nexo", "VIP do Nexo", "FFD36B", "vip"),
	item("dis_coroa", "distintivo", "Coroa do Nexo", "👑", "FFD36B", "vip"),
	item(
		"ras_dourado",
		"rastro",
		"Rastro Real",
		"Ouro e violeta ao correr",
		"FFD36B",
		"vip",
		"B79CFF"
	),
	-- Temporada 1 (trilha grátis)
	item(
		"tit_andarilho",
		"titulo",
		"Andarilho das Fendas",
		"Andarilho das Fendas",
		"C9E39A",
		"temporada"
	),
	item("dis_estrela", "distintivo", "Estrela Errante", "✦", "E8F6FF", "temporada"),
	item(
		"ras_cinza",
		"rastro",
		"Rastro de Cinzas",
		"Cinzas mornas ao correr",
		"D4CDD6",
		"temporada",
		"6B647C"
	),
	item("tit_cacador", "titulo", "Caçador de Ecos", "Caçador de Ecos", "7FD8FF", "temporada"),
	item("dis_lua", "distintivo", "Meia-lua", "☾", "C4B6FF", "temporada"),
	item("tit_veterano", "titulo", "Veterano da T1", "Veterano da T1", "FFC46B", "temporada"),
	-- Temporada 1 (trilha premium)
	item("tit_rompe", "titulo", "Rompe-Fendas", "Rompe-Fendas", "FF9EC1", "temporada"),
	item("dis_cometa", "distintivo", "Cometa", "☄", "FF9A6A", "temporada"),
	item(
		"ras_violeta",
		"rastro",
		"Rastro Violeta",
		"Névoa violeta ao correr",
		"B79CFF",
		"temporada",
		"5E379A"
	),
	item(
		"tit_guardiao",
		"titulo",
		"Algoz de Guardiões",
		"Algoz de Guardiões",
		"FF7A7A",
		"temporada"
	),
	item("dis_olho", "distintivo", "Olho da Fenda", "👁", "FF7BB9", "temporada"),
	item(
		"ras_aurora",
		"rastro",
		"Rastro Aurora",
		"Aurora verde e rosa ao correr",
		"87F3CE",
		"temporada",
		"F8B1F1"
	),
	item(
		"tit_soberano",
		"titulo",
		"Soberano da Temporada",
		"Soberano da Temporada",
		"F4F3FF",
		"temporada"
	),
	item("dis_coracao", "distintivo", "Coração Desperto", "❤", "FF6B6B", "temporada"),
	item(
		"ras_eclipse",
		"rastro",
		"Rastro Eclipse",
		"Sombra e ouro ao correr",
		"160B26",
		"temporada",
		"FFAD4D"
	),
	item("tit_mestre", "titulo", "Mestre da Fenda", "Mestre da Fenda", "FF6BD6", "temporada"),
	item("dis_nexo", "distintivo", "Selo do Nexo", "⟁", "9EE7FF", "temporada"),
	item(
		"ras_prisma",
		"rastro",
		"Rastro Prisma",
		"Arco-íris facetado ao correr",
		"FF7A7A",
		"temporada",
		"77C8FF"
	),
} :: { Item }

Cosmeticos.porId = {} :: { [string]: Item }
for _, i in Cosmeticos.ITENS do
	Cosmeticos.porId[i.id] = i
end

-- Itens que cada pacote pago entrega
Cosmeticos.PACOTES = {
	iniciante = { "tit_despertado", "dis_broto", "ras_faisca" },
	vip = { "tit_vip", "dis_coroa", "ras_dourado" },
} :: { [string]: { string } }

function Cosmeticos.padrao(): { possui: { [string]: boolean }, equipados: { [string]: string } }
	return { possui = {}, equipados = {} }
end

-- Concede itens (idempotente). Devolve os ids que eram novos.
function Cosmeticos.conceder(c: any, ids: { string }): { string }
	c.possui = c.possui or {}
	local novos = {}
	for _, id in ids do
		if Cosmeticos.porId[id] and not c.possui[id] then
			c.possui[id] = true
			table.insert(novos, id)
		end
	end
	return novos
end

-- Pode equipar? (id "" = tirar o item daquele tipo)
function Cosmeticos.podeEquipar(c: any, tipo: string, id: string): boolean
	if not table.find(Cosmeticos.TIPOS, tipo) then
		return false
	end
	if id == "" then
		return true
	end
	local i = Cosmeticos.porId[id]
	return i ~= nil
		and i.tipo == tipo
		and type(c) == "table"
		and type(c.possui) == "table"
		and c.possui[id] == true
end

return Cosmeticos
