-- Política do painel, avaliada no servidor com os IDs informados pelo Roblox.
local PermissaoDev = {}

local UNIVERSO_TESTE = 10771776655
local LUGAR_TESTE = 112360499723635

function PermissaoDev.experienciaPrivada(universo: number, lugar: number): boolean
	return universo == UNIVERSO_TESTE and lugar == LUGAR_TESTE
end

function PermissaoDev.copiaLocal(universo: number, lugar: number, studioTeste: boolean): boolean
	return studioTeste and universo == 0 and lugar == 0
end

function PermissaoDev.autoriza(
	universo: number,
	lugar: number,
	studioTeste: boolean,
	dono: number?,
	jogador: number,
	contaDev: number?
): boolean
	if PermissaoDev.copiaLocal(universo, lugar, studioTeste) then
		-- O primeiro cliente do teste local usa -1. O Play Solo pode usar a conta do Studio.
		return jogador == -1 or jogador > 0
	end
	if not PermissaoDev.experienciaPrivada(universo, lugar) then
		return false
	end
	return (jogador > 0 and (jogador == dono or jogador == contaDev))
		or (studioTeste and jogador == -1)
end

return PermissaoDev
