-- Quadros do quique no lugar: contato, impulso, ápice e extensão antes do próximo contato.
local Movimento = {}

local DURACAO = 0.92

function Movimento.avancar(fase: number, dt: number): (number, boolean)
	local total = fase + dt / DURACAO
	return total % 1, total >= 1
end

local function suavizar(t: number): number
	return t * t * (3 - 2 * t)
end

-- Altura em studs e compressão de 0 a 1. O marcador de contato é o início do ciclo.
function Movimento.amostrar(fase: number): (number, number)
	if fase < 0.17 then
		local t = suavizar(fase / 0.17)
		return -0.30 + 0.30 * t, 1 - t
	elseif fase < 0.81 then
		local t = (fase - 0.17) / 0.64
		return 0.92 * math.sin(math.pi * t), 0
	else
		local t = suavizar((fase - 0.81) / 0.19)
		return -0.30 * t, t
	end
end

return Movimento
