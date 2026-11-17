-- Ícones da interface (lógica pura, testada). Sem imagens externas: cada item tem um
-- símbolo (emoji ou glifo) desenhado sobre um quadrado na cor da raridade.
local Icones = {}

Icones.ITENS = {
	estilhaco_bruto = "🪨",
	cinza_persistente = "🌫️",
	sal_mare_morta = "🧂",
	po_umbral = "✨",
	lasca_estavel = "🔷",
	selo_purificacao = "📜",
	fragmento_instavel = "⚡",
	brasa_arauto = "🔥",
	perola_abissal = "🫧",
	veu_ocaso = "🌙",
	coracao_fenda = "💠",
	emblema_guardiao = "🛡️",
	coracao_ressonancia = "💖",
	lamina_nexo = "🗡️",
	essencia_primordial = "🌟",
	semente_absoluto = "🌱",
} :: { [string]: string }

Icones.CATEGORIAS = {
	Materiais = "💎",
	Artefatos = "🔮",
	["Consumíveis"] = "🧪",
} :: { [string]: string }

-- Estilo visual da aura -> símbolo
Icones.AURAS = {
	brilho = "✨",
	chama = "🔥",
	nevoa = "🌀",
} :: { [string]: string }

Icones.MENU = {
	Loja = "🛒",
	Bolsa = "🎒",
	Indice = "📖",
	Temporada = "🏆",
	Ajustes = "⚙️",
	Auto = "🔁",
	Giros = "🎲",
	Fragmentos = "💎",
	Aura = "🌈",
	Artefato = "🔮",
}

function Icones.item(id: string, categoria: string?): string
	return Icones.ITENS[id] or (categoria and Icones.CATEGORIAS[categoria]) or "❔"
end

function Icones.aura(estilo: string?): string
	return (estilo and Icones.AURAS[estilo]) or "✨"
end

return Icones
