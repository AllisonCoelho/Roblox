local Movimento = {}

local TEMPO_PARADO = 4.8

local function suave(t: number): number
	return t * t * (3 - 2 * t)
end

-- Segura a silhueta de cada pose antes de passar para a outra.
function Movimento.parado(tempo: number): (number, number)
	local t = tempo % TEMPO_PARADO
	local relaxado = suave(math.clamp((t - 1.55) / 0.72, 0, 1))
		* (1 - suave(math.clamp((t - 3.89) / 0.80, 0, 1)))
	local flutuar = 0.075 * math.sin(2 * math.pi * t / TEMPO_PARADO * 3)
	return relaxado, flutuar
end

function Movimento.passo(fase: number, dt: number, velocidade: number): (number, string?)
	if velocidade <= 0 then
		return fase, nil
	end
	local ciclosPorSegundo = math.clamp(0.41 + velocidade * 0.052, 0.47, 1.48)
	local total = fase + dt * ciclosPorSegundo
	local meiosPassos = math.floor(total * 2)
	local contato = if meiosPassos > math.floor(fase * 2)
		then (if meiosPassos % 2 == 0 then "D" else "E")
		else nil
	return total % 1, contato
end

-- Em cada meio passo: toca o chão, dobra o joelho, ganha altura e troca o pé de apoio.
-- A altura acompanha os mesmos quadros que mudam os braços e as pernas.
function Movimento.corrida(fase: number): (boolean, number, number, number)
	local esquerda = fase >= 0.5
	local t = (fase * 2) % 1
	if t < 0.19 then
		local peso = suave(t / 0.19)
		return esquerda, 1, peso, -0.19 * peso
	elseif t < 0.63 then
		local peso = suave((t - 0.19) / 0.44)
		return esquerda, 2, peso, -0.19 + 0.77 * peso
	else
		local peso = suave((t - 0.63) / 0.37)
		return esquerda, 3, peso, 0.58 * (1 - peso)
	end
end

return Movimento
