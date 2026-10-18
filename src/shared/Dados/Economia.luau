-- Formato dos dados do jogador e regras derivadas deles.
-- Fica em Shared para o servidor (que manda) e a interface (que mostra) calcularem igual.
local Catalogo = require(script.Parent.Catalogo)

local Economia = {}

export type DocinhoNaVitrine = {
	id: string,
	variante: string,
}

export type EntradaAlbum = {
	qtd: number,
	desde: number,
	dourado: boolean,
	arcoiris: boolean,
}

export type MissaoDoDia = {
	id: string,
	progresso: number,
	resgatada: boolean,
}

export type Carga = {
	id: string,
	variante: string,
	preco: number, -- moedas pagas (0 no resgate)
	origem: number?,
}

export type Estado = {
	versao: number,
	moedas: number,
	granulados: number,
	caixa: number, -- moedas geradas pela vitrine esperando coleta
	vitrine: { DocinhoNaVitrine },
	album: { [string]: EntradaAlbum },
	melhorias: { [string]: number },
	boosts: { [string]: number }, -- id -> horário (os.time) em que acaba
	passes: { [string]: boolean },
	escudoAte: number,
	escudoProntoEm: number,
	presente: { ultimoDia: number, sequencia: number },
	missoes: { dia: number, lista: { MissaoDoDia } },
	codigos: { [string]: boolean },
	tutorialFeito: boolean,
	premios: { [string]: boolean }, -- prêmios únicos já pegos (ex.: álbum completo)
	renascimentos: number,
	config: { [string]: boolean }, -- preferências (sons, música)
	ultimaVez: number,
	-- Docinho comprado na esteira e ainda não entregue na vitrine (nil quando não há).
	-- Fica salvo: se o jogador sair ou cair carregando, recebe as moedas de volta.
	-- origem = UserId do dono quando o Docinho foi resgatado da vitrine de outro jogador.
	carregando: Carga?,
}

Economia.VERSAO = 1
Economia.EspacosBase = 8
Economia.EspacosPorNivel = 4
Economia.EscudoBase = 60
Economia.EscudoPorNivel = 15
Economia.EscudoRecarga = 30
Economia.CaixaHorasBase = 2
Economia.CaixaHorasPorNivel = 2
Economia.VelocidadeBase = 16
Economia.VelocidadeCarregando = 11
Economia.VelocidadePorNivelTenis = 1.5

function Economia.padrao(): Estado
	return {
		versao = Economia.VERSAO,
		moedas = 100,
		granulados = 0,
		caixa = 0,
		vitrine = {},
		album = {},
		melhorias = { vitrine = 0, escudo = 0, tenis = 0, caixa = 0 },
		boosts = {},
		passes = {},
		escudoAte = 0,
		escudoProntoEm = 0,
		presente = { ultimoDia = -1, sequencia = 0 },
		missoes = { dia = -1, lista = {} },
		codigos = {},
		tutorialFeito = false,
		premios = {},
		renascimentos = 0,
		config = { sons = true, musica = true },
		ultimaVez = 0,
	}
end

Economia.PremioAlbumGranulados = 500

-- Todos os Docinhos do catálogo já foram descobertos? (variantes não contam)
function Economia.albumCompleto(estado: Estado): boolean
	for _, d in Catalogo.Lista do
		if not estado.album[d.id] then
			return false
		end
	end
	return true
end

function Economia.nivel(estado: Estado, melhoria: string): number
	return estado.melhorias[melhoria] or 0
end

function Economia.capacidadeVitrine(estado: Estado): number
	return Economia.EspacosBase + Economia.EspacosPorNivel * Economia.nivel(estado, "vitrine")
end

function Economia.duracaoEscudo(estado: Estado): number
	return Economia.EscudoBase + Economia.EscudoPorNivel * Economia.nivel(estado, "escudo")
end

function Economia.limiteCaixaSegundos(estado: Estado): number
	return (Economia.CaixaHorasBase + Economia.CaixaHorasPorNivel * Economia.nivel(estado, "caixa"))
		* 3600
end

function Economia.boostAtivo(estado: Estado, id: string, agora: number): boolean
	return (estado.boosts[id] or 0) > agora
end

-- Renascer: zera moedas, caixa e melhorias (menos o tamanho da vitrine) e dá renda extra
-- para sempre. Os Docinhos e o álbum continuam (perder Docinhos frustraria as crianças).
Economia.RenascerCustoBase = 1000000
Economia.RenascerCustoFator = 4
Economia.RenascerBonus = 0.25 -- +25% de renda por renascimento
Economia.RenascerGranulados = 50 -- vezes o número do renascimento

function Economia.custoRenascer(feitos: number): number
	return Economia.RenascerCustoBase * Economia.RenascerCustoFator ^ feitos
end

function Economia.multiplicadorRenascer(feitos: number): number
	return 1 + Economia.RenascerBonus * feitos
end

function Economia.multiplicadorMoedas(estado: Estado, agora: number): number
	local m = Economia.multiplicadorRenascer(estado.renascimentos or 0)
	if estado.passes.vip then
		m *= 2
	end
	if Economia.boostAtivo(estado, "moedas2x", agora) then
		m *= 2
	end
	return m
end

-- Moedas por segundo de toda a vitrine, já com VIP e boosts
function Economia.rendaPorSegundo(estado: Estado, agora: number): number
	local total = 0
	for _, d in estado.vitrine do
		total += Catalogo.rendaDe(d.id, d.variante)
	end
	return total * Economia.multiplicadorMoedas(estado, agora)
end

return Economia
