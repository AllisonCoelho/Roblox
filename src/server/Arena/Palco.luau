-- O ringue da Arena é um só: um duelo por vez (contra o Primeiro Soberano, pelo Trono do
-- Servidor ou da Rankeada). Quem quer usar reserva; ao terminar, libera e avisa quem espera.
local Palco = {}

local dono: string? = nil
local ouvintes: { () -> () } = {}

function Palco.ocupado(): boolean
	return dono ~= nil
end

function Palco.dono(): string?
	return dono
end

function Palco.reservar(nome: string): boolean
	if dono then
		return false
	end
	dono = nome
	return true
end

function Palco.liberar(nome: string)
	if dono ~= nome then
		return
	end
	dono = nil
	for _, fn in ouvintes do
		task.spawn(fn)
	end
end

-- Chamado sempre que o ringue fica livre
function Palco.aoLiberar(fn: () -> ())
	table.insert(ouvintes, fn)
end

return Palco
