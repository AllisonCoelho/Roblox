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
