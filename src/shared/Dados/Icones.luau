-- Células do atlas da Órbita, numeradas por linha da esquerda para a direita.
local Icones = {}

Icones.COLUNAS = 6
Icones.TOTAL = 36
Icones.DESCONHECIDO = 32

Icones.ITENS = {
	estilhaco_bruto = 13,
	cinza_persistente = 14,
	sal_mare_morta = 15,
	po_umbral = 16,
	lasca_estavel = 17,
	selo_purificacao = 18,
	fragmento_instavel = 19,
	brasa_arauto = 20,
	perola_abissal = 21,
	veu_ocaso = 22,
	coracao_fenda = 23,
	emblema_guardiao = 24,
	coracao_ressonancia = 25,
	lamina_nexo = 26,
	essencia_primordial = 27,
	semente_absoluto = 28,
}

Icones.CATEGORIAS = {
	Materiais = 8,
	Artefatos = 10,
	["Consumíveis"] = 29,
}

Icones.AURAS = {
	brilho = 31,
	chama = 20,
	nevoa = 30,
}

Icones.MENU = {
	Loja = 1,
	Bolsa = 2,
	Indice = 3,
	Temporada = 4,
	Ajustes = 5,
	Auto = 6,
	Giros = 7,
	Fragmentos = 8,
	Aura = 9,
	Artefato = 10,
}

Icones.STATUS = { Cadeado = 11, Concluido = 12, Despertar = 36 }
Icones.DISTINTIVOS = {
	dis_broto = 28,
	dis_coroa = 33,
	dis_estrela = 36,
	dis_lua = 22,
	dis_cometa = 35,
	dis_olho = 34,
	dis_coracao = 25,
}

function Icones.item(id: string, categoria: string?): number
	return Icones.ITENS[id] or (categoria and Icones.CATEGORIAS[categoria]) or Icones.DESCONHECIDO
end

function Icones.aura(estilo: string?): number
	return (estilo and Icones.AURAS[estilo]) or Icones.AURAS.brilho
end

return Icones
