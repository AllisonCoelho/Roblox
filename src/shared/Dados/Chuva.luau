-- Chuva de Doces (evento de sábado): Docinhos caem do céu em pontos livres do mapa
-- e quem encosta primeiro leva de graça para a vitrine. Contas puras e testáveis.
local Mapa = require(script.Parent.Mapa)

local Chuva = {}

Chuva.Intervalo = 1.2 -- segundos entre dois Docinhos caindo
Chuva.MaximoNoChao = 25 -- limite de Docinhos esperando no chão
Chuva.Queda = 2 -- segundos caindo
Chuva.AlturaQueda = 60 -- de onde caem (studs acima do chão)
Chuva.TempoNoChao = 20 -- quanto tempo ficam no chão antes de sumir
Chuva.DistanciaPegar = 5 -- encostar a esta distância pega o Docinho
Chuva.GranuladosSeCheia = 5 -- prêmio no lugar do Docinho se a vitrine estiver cheia
-- O Secreto só existe na chuva: peso 0,15 (perto de 0,13% por Docinho, ~1 a cada sábado)
Chuva.PesoSecreto = 0.15
Chuva.Area = 110 -- metade do quadrado onde podem cair
Chuva.Folga = 3 -- distância mínima das construções

-- O ponto (X, Z) está livre? (fora da fábrica, esteira, vitrines e prédios da praça)
function Chuva.pontoLivre(x: number, z: number): boolean
	if math.abs(x) > Chuva.Area or math.abs(z) > Chuva.Area then
		return false
	end
	for _, r in Mapa.retangulos() do
		if
			x >= r.minX - Chuva.Folga
			and x <= r.maxX + Chuva.Folga
			and z >= r.minZ - Chuva.Folga
			and z <= r.maxZ + Chuva.Folga
		then
			return false
		end
	end
	return true
end

-- Sorteia um ponto livre. "aleatorio" devolve um número em [0, 1). nil se não achar.
function Chuva.sortearPonto(aleatorio: () -> number): Vector3?
	for _ = 1, 50 do
		local x = (aleatorio() * 2 - 1) * Chuva.Area
		local z = (aleatorio() * 2 - 1) * Chuva.Area
		if Chuva.pontoLivre(x, z) then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

-- Altura extra (acima do ponto de pouso) de um Docinho que começou a cair em "inicio"
function Chuva.alturaNoAr(inicio: number, agora: number): number
	local t = math.clamp((agora - inicio) / Chuva.Queda, 0, 1)
	-- Começa devagar e acelera, como uma queda de verdade
	return Chuva.AlturaQueda * (1 - t * t)
end

-- Já pousou? (só dá para pegar depois de chegar ao chão)
function Chuva.pousou(inicio: number, agora: number): boolean
	return agora - inicio >= Chuva.Queda
end

return Chuva
