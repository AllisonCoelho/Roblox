-- Catálogo de monetização do Despertar (lógica pura, testada). Fonte única de preços e status.
-- Desenvolvemos 1 por 1: "ativo" = já vendido no jogo; "planejado" = na fila.
--
-- IDs: o Game Pass é criado pelo dono no Creator Hub (Monetização → Passes). Enquanto o campo
-- gamePassId estiver nil, o recurso fica bloqueado para quem não é dev e a compra aparece como
-- "em breve". NUNCA inventar ID: copie o número real do Creator Hub para cá.
--
-- Regras: só cosmético e conveniência. Nada que mude chance de aura, poder em combate ou
-- recompensa das Incursões (o jogo não vende vantagem).
local Monetizacao = {}

export type Produto = {
	id: string,
	nome: string,
	preco: number, -- Robux (preço inicial; faixas usam o menor valor)
	precoTexto: string, -- como aparece no catálogo ("39–79", "99/mês")
	tipo: string, -- "passe" | "produto" | "assinatura" | "servidor"
	beneficio: string,
	prioridade: string, -- "altissima" | "alta" | "media" | "baixa"
	status: string, -- "ativo" | "planejado"
	gamePassId: number?, -- só passes ativos; nil até o dono criar no Creator Hub
}

local function p(dados: { [string]: any }): Produto
	return dados :: any
end

Monetizacao.PRODUTOS = {
	-- ===== ativos (vendidos já nesta versão)
	p({
		id = "autoGiro",
		nome = "Giro Automático",
		preco = 49,
		precoTexto = "49",
		tipo = "passe",
		beneficio = "Liga o giro automático de auras.",
		prioridade = "altissima",
		status = "ativo",
		gamePassId = nil,
	}),
	p({
		id = "pularAnimacao",
		nome = "Pular Animação",
		preco = 39,
		precoTexto = "39",
		tipo = "passe",
		beneficio = "Pular o ritual do giro, desligar animações e encurtar auras repetidas.",
		prioridade = "altissima",
		status = "ativo",
		gamePassId = nil,
	}),
	-- ===== planejados (catálogo; desenvolvidos um por um)
	p({
		id = "iniciante",
		nome = "Pacote do Iniciante",
		preco = 49,
		precoTexto = "49",
		tipo = "passe",
		beneficio = "Cosméticos iniciais permanentes e distintivo.",
		prioridade = "altissima",
		status = "planejado",
	}),
	p({
		id = "autoInteligente",
		nome = "Auto Inteligente",
		preco = 79,
		precoTexto = "79",
		tipo = "passe",
		beneficio = "Configurações avançadas para o giro automático.",
		prioridade = "altissima",
		status = "planejado",
	}),
	p({
		id = "presets",
		nome = "Presets de Auras",
		preco = 49,
		precoTexto = "49",
		tipo = "passe",
		beneficio = "Salvar combinações de apresentação e aura.",
		prioridade = "alta",
		status = "planejado",
	}),
	p({
		id = "ritualPersonalizado",
		nome = "Ritual Personalizado",
		preco = 99,
		precoTexto = "99",
		tipo = "passe",
		beneficio = "Novo efeito visual para o despertar.",
		prioridade = "altissima",
		status = "planejado",
	}),
	p({
		id = "vip",
		nome = "VIP do Nexo",
		preco = 199,
		precoTexto = "199",
		tipo = "passe",
		beneficio = "Título, identificação e cosméticos exclusivos.",
		prioridade = "altissima",
		status = "planejado",
	}),
	p({
		id = "fundador",
		nome = "Pacote Fundador",
		preco = 149,
		precoTexto = "149",
		tipo = "passe",
		beneficio = "Cosméticos comemorativos e distintivo permanente.",
		prioridade = "alta",
		status = "planejado",
	}),
	p({
		id = "titulos",
		nome = "Títulos Especiais",
		preco = 39,
		precoTexto = "39–79",
		tipo = "produto",
		beneficio = "Títulos visíveis no mundo.",
		prioridade = "media",
		status = "planejado",
	}),
	p({
		id = "trilhas",
		nome = "Trilhas de Movimento",
		preco = 49,
		precoTexto = "49–99",
		tipo = "produto",
		beneficio = "Efeitos visuais ao correr e saltar.",
		prioridade = "media",
		status = "planejado",
	}),
	p({
		id = "aparenciaAlternativa",
		nome = "Aura: Aparência Alternativa",
		preco = 99,
		precoTexto = "99–199",
		tipo = "produto",
		beneficio = "Variação cosmética de uma aura obtida.",
		prioridade = "altissima",
		status = "planejado",
	}),
	p({
		id = "emotesVitoria",
		nome = "Emotes de Vitória",
		preco = 49,
		precoTexto = "49–99",
		tipo = "produto",
		beneficio = "Celebrações na Arena.",
		prioridade = "media",
		status = "planejado",
	}),
	p({
		id = "finalizacoes",
		nome = "Finalizações Especiais",
		preco = 99,
		precoTexto = "99–149",
		tipo = "produto",
		beneficio = "Animação visual de vitória na Arena.",
		prioridade = "media",
		status = "planejado",
	}),
	p({
		id = "passeTemporada",
		nome = "Passe de Temporada",
		preco = 299,
		precoTexto = "299",
		tipo = "passe",
		beneficio = "Trilha premium com recompensas definidas.",
		prioridade = "alta",
		status = "planejado",
	}),
	p({
		id = "assinatura",
		nome = "Assinatura do Nexo",
		preco = 99,
		precoTexto = "99/mês",
		tipo = "assinatura",
		beneficio = "Cosméticos mensais e conveniência.",
		prioridade = "baixa",
		status = "planejado",
	}),
	p({
		id = "servidorPrivado",
		nome = "Servidor Privado",
		preco = 49,
		precoTexto = "49/mês",
		tipo = "servidor",
		beneficio = "Espaço para jogar com amigos.",
		prioridade = "media",
		status = "planejado",
	}),
} :: { Produto }

Monetizacao.porId = {} :: { [string]: Produto }
for _, produto in Monetizacao.PRODUTOS do
	Monetizacao.porId[produto.id] = produto
end

-- Atributo do jogador que o servidor liga quando ele tem o passe (o cliente só lê)
function Monetizacao.atributo(id: string): string
	return "Passe_" .. id
end

-- Configurações do perfil que exigem passe para serem LIGADAS (ou desligadas, para animações)
-- chave -> { passe, valor que exige o passe }
Monetizacao.CONFIGURACOES_PAGAS = {
	giroAutomatico = { passe = "autoGiro", exige = true },
	animacoes = { passe = "pularAnimacao", exige = false }, -- desligar animações = pular
	pularRepetidas = { passe = "pularAnimacao", exige = true },
} :: { [string]: { passe: string, exige: boolean } }

-- A configuração pedida precisa de um passe que o jogador não tem? Devolve o id do passe.
function Monetizacao.passeNecessario(
	chave: string,
	valor: boolean,
	tem: (string) -> boolean
): string?
	local regra = Monetizacao.CONFIGURACOES_PAGAS[chave]
	if regra and valor == regra.exige and not tem(regra.passe) then
		return regra.passe
	end
	return nil
end

function Monetizacao.ativos(): { Produto }
	local lista = {}
	for _, produto in Monetizacao.PRODUTOS do
		if produto.status == "ativo" then
			table.insert(lista, produto)
		end
	end
	return lista
end

return Monetizacao
