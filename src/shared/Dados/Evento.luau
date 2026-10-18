-- Agenda da Chuva de Doces: todo sábado às 15h (Brasília), por 10 minutos
local Evento = {}

Evento.Nome = "Chuva de Doces"
Evento.DiaDaSemana = 6 -- 0 = domingo ... 6 = sábado
Evento.HoraUTC = 18 -- 15h em Brasília
Evento.Duracao = 10 * 60

local SEMANA = 7 * 86400

-- 1/1/1970 foi uma quinta-feira (dia 4)
local function inicioDaSemana(agora: number): number
	local dias = math.floor(agora / 86400)
	local diaDaSemana = (dias + 4) % 7
	return (dias - diaDaSemana) * 86400
end

-- Devolve se o evento está ativo e quantos segundos faltam (para acabar ou para começar)
function Evento.estado(agora: number): (boolean, number)
	local inicio = inicioDaSemana(agora) + Evento.DiaDaSemana * 86400 + Evento.HoraUTC * 3600
	if agora >= inicio + Evento.Duracao then
		inicio += SEMANA
	end
	if agora >= inicio then
		return true, inicio + Evento.Duracao - agora
	end
	return false, inicio - agora
end

return Evento
