-- Esquema dos dados salvos de cada jogador (DataStore Despertar_v1) e regras puras sobre eles.
-- O store Despertar_v1 é independente da experiência anterior.
local Perfil = {}

export type Estado = {
	versao: number,
	giros: number,
	auras: { [string]: number }, -- id da aura -> quantas vezes saiu
	equipada: string?,
	configuracoes: { [string]: boolean },
	-- Incursões (Dados/Incursoes.luau): fragmentos, melhor andar, vitórias e relíquias.
	-- Dados antigos ganham o padrão ao carregar (Dados.completar).
	incursoes: { [string]: any },
	inventario: { itens: { [string]: number }, equipados: { artefato: string? } },
	transcendencia: { nivel: number, totalRealizadas: number },
	-- Loja (Dados/Cosmeticos e Dados/Temporada): só aparência, nunca poder.
	cosmeticos: { possui: { [string]: boolean }, equipados: { [string]: string } },
	temporada: { [string]: any },
	-- Pontos de Aura (Dados/PontosAura.luau): saldo, total gerado e níveis das evoluções
	poder: { pontos: number, total: number, nivel: number, fluxo: number, sorte: number },
	-- Corredor dos Perdidos (Dados/Corredor.luau): Fragmentos, fases concluídas e o bônus
	corredor: { [string]: any },
	-- Ecos (Dados/Pets.luau): coleção, equipados e o índice dos já vistos
	pets: { [string]: any },
	-- Equipamento (Dados/Equipamento.luau): peças, equipadas por espaço e visuais ocultos
	equipamento: { [string]: any },
	-- Arena (Dados/ArenaPvP.luau): rating da Rankeada, vitórias, derrotas, vitórias sobre o
	-- Primeiro Soberano e reinados como Rei do Servidor
	arena: { [string]: any },
	-- Tutorial (Dados/Tutorial.luau): passo atual, concluído e presentes entregues. Fica fora do
	-- padrão de propósito: quem já tinha perfil sem ele e já girou não vê o tutorial
	tutorial: { [string]: any }?,
}

Perfil.VERSAO = 1

-- Configurações que o cliente pode alterar (todas booleanas)
Perfil.CONFIGURACOES = {
	giroAutomatico = true,
	anuncios = true,
	equiparAutomatico = true, -- equipar sozinho quando sair uma aura mais rara que a atual
	sons = true,
	animacoes = true, -- ritual, pose do personagem e câmera do giro
	movimentoReduzido = true, -- sem câmera, tremor nem escurecimento
	qualidadeBaixa = true, -- menos anéis, partículas e rastros
	ocultarEfeitosAlheios = true, -- não mostrar rituais e auras dos outros jogadores
	pularRepetidas = true, -- animação curta para auras que você já tem
}

function Perfil.padrao(): Estado
	return {
		versao = Perfil.VERSAO,
		giros = 0,
		auras = {},
		equipada = nil,
		configuracoes = {
			giroAutomatico = false,
			anuncios = true,
			equiparAutomatico = false,
			sons = true,
			animacoes = true,
			movimentoReduzido = false,
			qualidadeBaixa = false,
			ocultarEfeitosAlheios = false,
			pularRepetidas = false,
		},
		incursoes = { fragmentos = 0, melhor = {}, concluidas = {}, reliquias = {} },
		inventario = { itens = {}, equipados = {} },
		transcendencia = { nivel = 0, totalRealizadas = 0 },
		cosmeticos = { possui = {}, equipados = {} },
		temporada = {
			id = "",
			xp = 0,
			resgates = { gratis = {}, premium = {} },
			giroDia = { dia = 0, xp = 0 },
		},
		poder = { pontos = 0, total = 0, nivel = 0, fluxo = 0, sorte = 0 },
		corredor = { fragmentos = 0, concluidas = {}, ultima = {}, bonusAte = 0 },
		pets = { lista = {}, equipados = {}, contador = 0, vistos = {} },
		equipamento = { lista = {}, equipados = {}, ocultos = {}, contador = 0 },
		arena = {
			rating = 1000,
			vitorias = 0,
			derrotas = 0,
			monarca = 0,
			reinados = 0,
			maiorReinado = 0,
		},
	}
end

-- Os perfis salvos são tabelas serializáveis. Inclui campos aninhados de versões futuras.
local function copiarTabela(origem: { [any]: any }): { [any]: any }
	local copia = table.clone(origem)
	for chave, valor in origem do
		if type(valor) == "table" then
			copia[chave] = copiarTabela(valor)
		end
	end
	return copia
end

function Perfil.copiar(estado: Estado): Estado
	return copiarTabela(estado) :: Estado
end

-- Um destino distinto da mesma raridade, escolhido por proximidade da chance-base.
local AURAS_ANTIGAS: { [string]: string } = {
	faisca = "centelha_do_nexo",
	nevoa = "musgo_luminoso",
	brasa = "fagulha_de_cobre",
	orvalho = "chuvisco_de_vidro",
	folha_dancante = "borboletas_de_cinza",
	pedra_viva = "gelo_de_neon",
	mare_calma = "mare_de_quartzo",
	brasa_sussurrante = "raiz_cintilante",
	vento_cortante = "nevoa_de_amora",
	raiz_antiga = "vento_de_papel",
	gelo_fino = "engrenagem_de_orvalho",
	trovao_jovem = "coroa_de_coral",
	lotus_rubra = "prisma_partilhado",
	pluma_celeste = "fenda_de_porcelana",
	chama_azul = "esporos_de_safira",
	eco_do_vazio = "solsticio_de_areia",
	cristal_lunar = "espelho_de_chuva",
	tempestade_rubra = "arquivista_espectral",
	sombra_gemea = "jardim_das_agulhas",
	sol_nascente = "coracao_de_basalto",
	dragao_de_jade = "navio_de_papel_fantasma",
	aurora_boreal = "catedral_de_sal",
	coracao_estelar = "arquiduque_de_cinzas",
	lamina_do_crepusculo = "trono_de_raios",
	lotus_celestial = "atlas_fragmentado",
	fenix_eterna = "devorador_de_alvoradas",
	eclipse_carmesim = "oceano_sem_fundo",
	olho_do_abismo = "leviata_astral",
	nebulosa_primordial = "labirinto_vivo",
	despertar_absoluto = "alvorecer_dos_titas",
}

local function copiasValidas(valor: any): number
	return if type(valor) == "number" and valor > 0 and valor < math.huge then valor else 0
end

-- Executada depois de adquirir a trava do perfil, antes de expor a coleção ao jogo.
-- Remover os IDs antigos depois de somar suas cópias torna a migração idempotente.
function Perfil.migrarAuras(estado: Estado)
	if type(estado.auras) ~= "table" then
		estado.auras = {}
	end
	local colecao = estado.auras
	for origem, destino in AURAS_ANTIGAS do
		local antigas = copiasValidas(colecao[origem])
		if antigas > 0 then
			colecao[destino] = copiasValidas(colecao[destino]) + antigas
		end
		colecao[origem] = nil
	end
	local equipada = estado.equipada
	local destino = if equipada then AURAS_ANTIGAS[equipada] else nil
	if destino then
		estado.equipada = if copiasValidas(colecao[destino]) > 0 then destino else nil
	end
end

-- Conta um giro e guarda a aura sorteada na coleção
function Perfil.registrarGiro(estado: Estado, auraId: string)
	estado.giros += 1
	estado.auras[auraId] = (estado.auras[auraId] or 0) + 1
end

-- A coleção ainda não tem nenhuma aura (usar ANTES de registrar o giro)
function Perfil.colecaoVazia(estado: Estado): boolean
	for _, qtd in estado.auras do
		if type(qtd) == "number" and qtd > 0 then
			return false
		end
	end
	return true
end

-- Decide se a aura recém-obtida deve ser equipada sozinha. Obter não força a troca:
--   * a primeira aura da coleção é sempre equipada;
--   * depois, só com "equipar automaticamente" ligado e se for mais rara que a atual
--     (chanceAtual nil = nada equipado).
-- Quem desequipou de propósito e deixou o automático desligado continua sem aura.
function Perfil.deveEquipar(
	estado: Estado,
	eraVazia: boolean,
	chanceNova: number,
	chanceAtual: number?
): boolean
	if eraVazia then
		return true
	end
	if estado.configuracoes.equiparAutomatico ~= true then
		return false
	end
	return chanceAtual == nil or chanceNova > chanceAtual
end

function Perfil.possui(estado: Estado, auraId: string): boolean
	local qtd = estado.auras[auraId]
	return type(qtd) == "number" and qtd > 0
end

return Perfil
