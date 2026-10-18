-- Conquistas do jogador. Cada uma pode virar um emblema (badge) do Roblox: crie o emblema
-- no Creator Hub (Engajamento > Emblemas) e cole o id em badgeId. Com badgeId 0 a
-- conquista fica registrada só dentro do jogo e o emblema é dado quando o id for colocado.
local Catalogo = require(script.Parent.Catalogo)
local Economia = require(script.Parent.Economia)

local Conquistas = {}

export type Conquista = {
	id: string,
	nome: string,
	descricao: string,
	icone: string,
	badgeId: number,
	silenciosa: boolean?, -- não mostra aviso no jogo (ex.: a de boas-vindas)
}

-- Lendário ou mais raro
local ORDEM_LENDARIO = 5
local MILHAO = 1000000

Conquistas.Lista = {
	{
		id = "bemVindo",
		nome = "Bem-vindo à Fábrica",
		descricao = "Entrou no Docinhos pela primeira vez",
		icone = "🏭",
		badgeId = 0,
		silenciosa = true,
	},
	{
		id = "primeiroDocinho",
		nome = "Primeiro Docinho",
		descricao = "Colocou o primeiro Docinho na vitrine",
		icone = "🍬",
		badgeId = 0,
	},
	{
		id = "dourado",
		nome = "Toque de Ouro",
		descricao = "Conseguiu um Docinho Dourado",
		icone = "🌟",
		badgeId = 0,
	},
	{
		id = "lendario",
		nome = "Que Sorte!",
		descricao = "Conseguiu um Docinho Lendário ou mais raro",
		icone = "🍀",
		badgeId = 0,
	},
	{
		id = "chuva",
		nome = "Caiu do Céu",
		descricao = "Pegou um Docinho na Chuva de Doces",
		icone = "🌧️",
		badgeId = 0,
	},
	{
		id = "guardiao",
		nome = "Guardião da Vitrine",
		descricao = "Alcançou quem levava seu Docinho e trouxe ele de volta",
		icone = "🛡️",
		badgeId = 0,
	},
	{
		id = "milionario",
		nome = "Milionário",
		descricao = "Juntou 1 milhão de moedas",
		icone = "💰",
		badgeId = 0,
	},
	{
		id = "albumCompleto",
		nome = "Álbum Completo",
		descricao = "Encontrou todos os Docinhos do álbum",
		icone = "📖",
		badgeId = 0,
	},
	{
		id = "renascer",
		nome = "Renascido",
		descricao = "Renasceu pela primeira vez",
		icone = "🔄",
		badgeId = 0,
	},
} :: { Conquista }

local porId: { [string]: Conquista } = {}
for _, c in Conquistas.Lista do
	porId[c.id] = c
end

function Conquistas.conquista(id: string): Conquista?
	return porId[id]
end

-- Conquistas que o próprio estado já comprova (as outras vêm de eventos: chuva, guardião)
function Conquistas.doEstado(estado: Economia.Estado): { string }
	local ids = { "bemVindo" }
	local temDocinho, temDourado, temLendario = false, false, false
	for id, entrada in estado.album do
		temDocinho = true
		if entrada.dourado then
			temDourado = true
		end
		local r = Catalogo.raridadeDe(id)
		if r and r.ordem >= ORDEM_LENDARIO then
			temLendario = true
		end
	end
	if temDocinho then
		table.insert(ids, "primeiroDocinho")
	end
	if temDourado then
		table.insert(ids, "dourado")
	end
	if temLendario then
		table.insert(ids, "lendario")
	end
	if estado.moedas >= MILHAO then
		table.insert(ids, "milionario")
	end
	if Economia.albumCompleto(estado) then
		table.insert(ids, "albumCompleto")
	end
	if estado.renascimentos >= 1 then
		table.insert(ids, "renascer")
	end
	return ids
end

return Conquistas
