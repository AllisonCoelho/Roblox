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

-- ===================================================================== Haki do Rei
-- O haki estoura em quadros fixos da animação parada, alternando ciclos:
-- no auge da risada (pose 1) vem o estouro forte; no meio do repouso (pose 2), só faíscas.
Movimento.TEMPO_PARADO = TEMPO_PARADO
Movimento.HAKI_RISADA = 0.35
Movimento.HAKI_RELAXADO = 3.0
Movimento.HAKI_PASSOS = 8 -- na corrida, faísca a cada N pisadas

local function cruzou(antes: number, depois: number, marca: number): number?
	if depois < marca then
		return nil
	end
	local a = math.floor((antes - marca) / TEMPO_PARADO)
	local d = math.floor((depois - marca) / TEMPO_PARADO)
	return if d > a then d else nil
end

-- Devolve "forte", "fraco" ou nil para o intervalo de tempo parado (antes, depois]
function Movimento.hakiParado(antes: number, depois: number): string?
	local ciclo = cruzou(antes, depois, Movimento.HAKI_RISADA)
	if ciclo and ciclo % 2 == 1 then
		return "forte"
	end
	ciclo = cruzou(antes, depois, Movimento.HAKI_RELAXADO)
	if ciclo and ciclo % 2 == 0 then
		return "fraco"
	end
	return nil
end

-- Pouso: intensidade do haki pela velocidade de queda (nil = queda baixa, só a borracha)
function Movimento.hakiPouso(velocidadeQueda: number): number?
	if velocidadeQueda > -30 then
		return nil
	end
	return math.clamp(-velocidadeQueda / 45, 0.8, 1.6)
end

return Movimento
