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
	origem: string, -- pacote/passe ("iniciante", "vip", "fundador"...), "temporada" ou grupo de produto
	preco: number?, -- itens avulsos (Developer Product): Robux
	developerProductId: number?, -- nil até o dono criar o produto no Creator Hub. NUNCA inventar.
	exigeAssinatura: boolean?, -- só equipável com a Assinatura do Nexo ativa
}

-- ritual: cores do seu ritual de giro · aparencia: variação de cor da aura equipada
-- emote: celebração ao vencer na Arena · finalizacao: efeito no Soberano derrotado
Cosmeticos.TIPOS =
	{ "titulo", "distintivo", "rastro", "ritual", "aparencia", "emote", "finalizacao" }

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
	-- Evento Despertar do Sol (só nos baús do evento)
	item("tit_libertado", "titulo", "Libertado", "Libertado", "FFF6D0", "evento"),
	item(
		"ras_nuvem_sol",
		"rastro",
		"Rastro Nuvem do Sol",
		"Nuvens brancas e brilho dourado ao correr",
		"FFFFFF",
		"evento",
		"FFD54A"
	),
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
	-- Pacote Fundador
	item("tit_fundador", "titulo", "Fundador do Nexo", "Fundador do Nexo", "FFE08A", "fundador"),
	item("dis_fundador", "distintivo", "Selo Fundador", "✧", "FFE08A", "fundador"),
	item(
		"ras_fundador",
		"rastro",
		"Rastro Fundador",
		"Ouro antigo ao correr",
		"FFE08A",
		"fundador",
		"B07800"
	),
	-- Ritual Personalizado (passe): cores do seu ritual de giro
	item(
		"rit_solar",
		"ritual",
		"Ritual Solar",
		"Ritual em ouro e fogo",
		"FFB13D",
		"ritualPersonalizado",
		"FFF1A8"
	),
	item(
		"rit_abismo",
		"ritual",
		"Ritual do Abismo",
		"Ritual em violeta profundo",
		"8B5CF6",
		"ritualPersonalizado",
		"1E0B3A"
	),
	item(
		"rit_aurora",
		"ritual",
		"Ritual Aurora",
		"Ritual em verde e rosa",
		"87F3CE",
		"ritualPersonalizado",
		"F8B1F1"
	),
	-- Assinatura do Nexo: exclusivo enquanto ativa + um item mensal permanente
	item("tit_membro", "titulo", "Membro do Nexo", "Membro do Nexo", "9EE7FF", "assinatura"),
	item("dis_mes_cristal", "distintivo", "Cristal do Mês", "◆", "9EE7FF", "assinatura"),
	item(
		"ras_mes_neve",
		"rastro",
		"Rastro de Neve",
		"Flocos claros ao correr",
		"FFFFFF",
		"assinatura",
		"9EE7FF"
	),
	item("dis_mes_chama", "distintivo", "Chama do Mês", "🔥", "FF9A6A", "assinatura"),
} :: { Item }

-- Itens avulsos (Developer Products): grupo do catálogo de monetização e preço
local function avulso(id, tipo, nome, texto, cor, grupo, preco, cor2): Item
	local i = item(id, tipo, nome, texto, cor, grupo, cor2)
	i.preco = preco
	i.developerProductId = nil
	return i
end

for _, i in
	{
		-- Títulos Especiais (39–79)
		avulso("tit_lenda", "titulo", "Lenda Viva", "Lenda Viva", "FFC46B", "titulos", 39),
		avulso(
			"tit_tecelao",
			"titulo",
			"Tecelão de Destinos",
			"Tecelão de Destinos",
			"C4B6FF",
			"titulos",
			59
		),
		avulso(
			"tit_abismo",
			"titulo",
			"Olhos do Abismo",
			"Olhos do Abismo",
			"FF7BB9",
			"titulos",
			79
		),
		-- Trilhas de Movimento (49–99)
		avulso(
			"ras_relampago",
			"rastro",
			"Rastro Relâmpago",
			"Raios azuis ao correr",
			"77C8FF",
			"trilhas",
			49,
			"FFFFFF"
		),
		avulso(
			"ras_sakura",
			"rastro",
			"Rastro Sakura",
			"Pétalas rosadas ao correr",
			"FFB7D5",
			"trilhas",
			69,
			"FF6B9E"
		),
		avulso(
			"ras_cosmos",
			"rastro",
			"Rastro Cósmico",
			"Estrelas e nebulosa ao correr",
			"5E379A",
			"trilhas",
			99,
			"77C8FF"
		),
		-- Aura: Aparência Alternativa (99–199): recolore a aura equipada
		avulso(
			"apa_sombra",
			"aparencia",
			"Aparência Sombria",
			"Sua aura em tons de sombra",
			"2A1F3D",
			"aparenciaAlternativa",
			99,
			"8B5CF6"
		),
		avulso(
			"apa_prisma",
			"aparencia",
			"Aparência Prisma",
			"Sua aura em arco-íris",
			"FF7A7A",
			"aparenciaAlternativa",
			149,
			"77C8FF"
		),
		avulso(
			"apa_solar",
			"aparencia",
			"Aparência Solar",
			"Sua aura em ouro radiante",
			"FFD36B",
			"aparenciaAlternativa",
			199,
			"FFF1A8"
		),
		-- Emotes de Vitória (49–99)
		avulso(
			"emo_fogos",
			"emote",
			"Fogos do Nexo",
			"Fogos sobem ao vencer",
			"FFC46B",
			"emotesVitoria",
			49,
			"FF7BB9"
		),
		avulso(
			"emo_coroa",
			"emote",
			"Coroação",
			"Uma coroa de luz ao vencer",
			"FFD36B",
			"emotesVitoria",
			69,
			"FFFFFF"
		),
		avulso(
			"emo_tempestade",
			"emote",
			"Tempestade",
			"Raios em volta ao vencer",
			"77C8FF",
			"emotesVitoria",
			99,
			"B79CFF"
		),
		-- Finalizações Especiais (99–149)
		avulso(
			"fin_estilhaco",
			"finalizacao",
			"Estilhaço",
			"O Soberano se parte em cristais",
			"B8F2FF",
			"finalizacoes",
			99,
			"C0ADFF"
		),
		avulso(
			"fin_eclipse",
			"finalizacao",
			"Eclipse",
			"Um eclipse engole o Soberano",
			"160B26",
			"finalizacoes",
			149,
			"FFAD4D"
		),
	}
do
	table.insert(Cosmeticos.ITENS, i)
end

Cosmeticos.porId = {} :: { [string]: Item }
for _, i in Cosmeticos.ITENS do
	Cosmeticos.porId[i.id] = i
end
-- Exclusivos da assinatura (só equipáveis enquanto ativa)
Cosmeticos.porId.tit_membro.exigeAssinatura = true

-- Item avulso pelo id do Developer Product (só itens com ID preenchido)
function Cosmeticos.porProduto(productId: number): Item?
	for _, i in Cosmeticos.ITENS do
		if i.developerProductId ~= nil and i.developerProductId == productId then
			return i
		end
	end
	return nil
end

-- Itens avulsos de um grupo do catálogo ("titulos", "trilhas"...), em ordem de preço
function Cosmeticos.doGrupo(grupo: string): { Item }
	local lista = {}
	for _, i in Cosmeticos.ITENS do
		if i.preco and i.origem == grupo then
			table.insert(lista, i)
		end
	end
	table.sort(lista, function(a, b)
		return (a.preco :: number) < (b.preco :: number)
	end)
	return lista
end

-- Assinatura: um item permanente por mês (gira pela lista)
Cosmeticos.MENSAIS = { "dis_mes_cristal", "ras_mes_neve", "dis_mes_chama" }
function Cosmeticos.mensal(ano: number, mes: number): string
	local indice = (ano * 12 + mes - 1) % #Cosmeticos.MENSAIS
	return Cosmeticos.MENSAIS[indice + 1]
end

-- Itens que cada pacote pago entrega
Cosmeticos.PACOTES = {
	iniciante = { "tit_despertado", "dis_broto", "ras_faisca" },
	vip = { "tit_vip", "dis_coroa", "ras_dourado" },
	fundador = { "tit_fundador", "dis_fundador", "ras_fundador" },
	ritualPersonalizado = { "rit_solar", "rit_abismo", "rit_aurora" },
	assinatura = { "tit_membro" },
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
