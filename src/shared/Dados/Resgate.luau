-- Regras do Resgate (levar um Docinho da vitrine de outro jogador).
-- Contas puras: o servidor decide com elas e os testes conferem cada caso.
-- O jogo é para crianças, então o resgate tem várias proteções:
-- escudo, vitrine de iniciante, imunidade depois de ser resgatado, recarga de quem
-- resgata, segurar o botão por um tempo e o dono poder recuperar tocando no outro.
local Resgate = {}

Resgate.SegurarBotao = 1.5 -- segundos segurando E para resgatar (dá tempo do dono reagir)
Resgate.Distancia = 10 -- distância máxima até o pedestal
Resgate.RecargaQuemResgata = 30 -- segundos entre dois resgates do mesmo jogador
Resgate.ImunidadeVitima = 60 -- segundos sem poder ser resgatado de novo
Resgate.MinimoNaVitrine = 3 -- vitrines com menos Docinhos que isso são de iniciante (protegidas)
Resgate.DistanciaRecuperar = 7 -- o dono encosta no outro a esta distância e recupera
-- Na entrega, a viagem desde o resgate tem que caber na velocidade de quem carrega
-- (com folga para pulos e atraso de rede). Mais rápido que isso = teleporte: o Docinho volta.
Resgate.FolgaVelocidade = 1.5
Resgate.MargemStuds = 12

export type Contexto = {
	agora: number,
	mesmoJogador: boolean,
	escudoAte: number, -- escudo da vitrine alvo
	docinhosNaVitrine: number, -- da vítima
	ultimoResgateSofrido: number?, -- quando a vítima foi resgatada pela última vez
	ultimoResgateFeito: number?, -- quando quem resgata fez o último resgate
	carregando: boolean, -- quem resgata já carrega algo
	espacoNaVitrine: boolean, -- quem resgata tem espaço na própria vitrine
	temVitrine: boolean, -- quem resgata tem vitrine neste servidor
	distancia: number, -- de quem resgata até o pedestal
	slotValido: boolean, -- o pedestal tem mesmo um Docinho
}

-- A distância (em linha reta) percorrida em "segundos" é impossível andando a "velocidade"?
function Resgate.rapidoDemais(distancia: number, segundos: number, velocidade: number): boolean
	return distancia
		> velocidade * math.max(segundos, 0) * Resgate.FolgaVelocidade + Resgate.MargemStuds
end

-- Reserva ---------------------------------------------------------------------------
-- O Docinho resgatado NÃO sai da vitrine do dono durante a corrida: ele fica lá, marcado
-- com quem está levando (levadoPor = UserId), sem render e sem aparecer no pedestal.
-- Só na entrega ele muda de vitrine, de uma vez. Se o resgate não terminar (o dono alcança,
-- quem leva cai, sai do jogo, o servidor desliga ou cai), basta tirar a marca: a única cópia
-- do Docinho nunca deixa de existir, mesmo com o dono offline ou a vitrine dele cheia.

type Item = { id: string, variante: string, levadoPor: number? }

-- Docinhos que estão de fato na vitrine (sem os que estão sendo levados)
function Resgate.naVitrine(vitrine: { Item }): number
	local n = 0
	for _, item in vitrine do
		if not item.levadoPor then
			n += 1
		end
	end
	return n
end

-- Marca o Docinho do slot (conferindo que é o mesmo id/variante e que ninguém já leva)
function Resgate.reservar(
	vitrine: { Item },
	slot: number,
	id: string,
	variante: string,
	quemLeva: number
): boolean
	local item = vitrine[slot]
	if not item or item.levadoPor or item.id ~= id or item.variante ~= variante then
		return false
	end
	item.levadoPor = quemLeva
	return true
end

-- Tira a marca de quem leva (o Docinho volta ao pedestal). true se havia reserva dele.
function Resgate.cancelar(vitrine: { Item }, quemLeva: number): boolean
	for _, item in vitrine do
		if item.levadoPor == quemLeva then
			item.levadoPor = nil
			return true
		end
	end
	return false
end

-- Tira todas as marcas (o dono vai sair, ou os dados voltaram depois de uma queda)
function Resgate.limparReservas(vitrine: { Item }): number
	local n = 0
	for _, item in vitrine do
		if item.levadoPor then
			item.levadoPor = nil
			n += 1
		end
	end
	return n
end

-- Entrega: tira o Docinho reservado da vitrine do dono e põe na de quem levou, sem pausa
-- entre os dois passos. Devolve o Docinho movido, ou nil e o motivo ("cheia": quem levou
-- não tem espaço; "sem_reserva": não há Docinho reservado para ele). Sem sucesso, nada muda.
function Resgate.concluir(
	vitrineDono: { Item },
	vitrineQuemLeva: { Item },
	capacidadeQuemLeva: number,
	quemLeva: number
): (Item?, string?)
	if #vitrineQuemLeva >= capacidadeQuemLeva then
		return nil, "cheia"
	end
	for i, item in vitrineDono do
		if item.levadoPor == quemLeva then
			table.remove(vitrineDono, i)
			local movido = { id = item.id, variante = item.variante }
			table.insert(vitrineQuemLeva, movido)
			return movido, nil
		end
	end
	return nil, "sem_reserva"
end

-- Devolve (true) ou (false, motivo para mostrar ao jogador)
function Resgate.pode(c: Contexto): (boolean, string?)
	if c.mesmoJogador then
		return false, "Essa vitrine é sua!"
	end
	if not c.temVitrine then
		return false, "Você ainda não tem uma vitrine neste servidor"
	end
	if c.carregando then
		return false, "Leve primeiro o Docinho que você está carregando"
	end
	if not c.slotValido then
		return false, "Esse Docinho não está mais aqui"
	end
	if c.agora < c.escudoAte then
		return false, "O escudo dessa vitrine está ligado"
	end
	if c.docinhosNaVitrine < Resgate.MinimoNaVitrine then
		return false, "Vitrine de iniciante: protegida"
	end
	if c.ultimoResgateSofrido and c.agora - c.ultimoResgateSofrido < Resgate.ImunidadeVitima then
		return false, "Essa vitrine acabou de ser resgatada. Tente outra!"
	end
	if c.ultimoResgateFeito and c.agora - c.ultimoResgateFeito < Resgate.RecargaQuemResgata then
		local falta = math.ceil(Resgate.RecargaQuemResgata - (c.agora - c.ultimoResgateFeito))
		return false, "Espere " .. falta .. " s para resgatar de novo"
	end
	if c.distancia > Resgate.Distancia then
		return false, "Chegue mais perto do Docinho"
	end
	if not c.espacoNaVitrine then
		return false, "Sua vitrine está cheia!"
	end
	return true, nil
end

return Resgate
