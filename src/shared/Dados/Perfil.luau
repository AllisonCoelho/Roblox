-- Esquema dos dados salvos de cada jogador (DataStore Despertar_v1) e regras puras sobre eles.
-- O store Despertar_v1 é independente da experiência anterior.
local Perfil = {}

export type Estado = {
	versao: number,
	giros: number,
	auras: { [string]: number }, -- id da aura -> quantas vezes saiu
	equipada: string?,
	configuracoes: { [string]: boolean },
}

Perfil.VERSAO = 1

-- Configurações que o cliente pode alterar (todas booleanas)
Perfil.CONFIGURACOES = {
	giroAutomatico = true,
	anuncios = true,
	equiparAutomatico = true, -- equipar sozinho quando sair uma aura mais rara que a atual
	sons = true,
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
			movimentoReduzido = false,
			qualidadeBaixa = false,
			ocultarEfeitosAlheios = false,
			pularRepetidas = false,
		},
	}
end

-- Conta um giro e guarda a aura sorteada na coleção
function Perfil.registrarGiro(estado: Estado, auraId: string)
	estado.giros += 1
	estado.auras[auraId] = (estado.auras[auraId] or 0) + 1
end

function Perfil.possui(estado: Estado, auraId: string): boolean
	local qtd = estado.auras[auraId]
	return type(qtd) == "number" and qtd > 0
end

return Perfil
