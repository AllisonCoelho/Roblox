-- Esquema inicial do novo jogo. Sorteios e auras serão implementados na V1.
-- O store Despertar_v1 é independente da experiência anterior.
local Perfil = {}

export type Estado = {
	versao: number,
	giros: number,
	auras: { [string]: number },
	equipada: string?,
	configuracoes: { [string]: boolean },
}

Perfil.VERSAO = 1

function Perfil.padrao(): Estado
	return {
		versao = Perfil.VERSAO,
		giros = 0,
		auras = {},
		equipada = nil,
		configuracoes = { giroAutomatico = false, anuncios = true },
	}
end

return Perfil
