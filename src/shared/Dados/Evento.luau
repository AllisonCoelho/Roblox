-- Agenda da chuva. A Chuva de Doces grande é todo sábado às 15h (Brasília), por 10 minutos,
-- e é a única com o Docinho Secreto. Entre uma e outra, um Chuvisco curto a cada 20 minutos
-- (no mesmo horário em todos os servidores) dá motivo para ficar de olho no céu.
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

Evento.NomeChuvisco = "Chuvisco de Doces"
Evento.ChuviscoIntervalo = 20 * 60
Evento.ChuviscoDuracao = 60

-- Chuva agora ou a próxima: (ativo, segundos para acabar ou para começar, é a grande?)
function Evento.chuva(agora: number): (boolean, number, boolean)
	local ativo, falta = Evento.estado(agora)
	if ativo then
		return true, falta, true
	end
	local fase = agora % Evento.ChuviscoIntervalo
	if fase < Evento.ChuviscoDuracao then
		local fim = Evento.ChuviscoDuracao - fase
		-- Se a grande começa no meio do chuvisco, ele acaba quando ela começa
		return true, math.min(fim, falta), false
	end
	local proximo = Evento.ChuviscoIntervalo - fase
	if falta <= proximo then
		return false, falta, true
	end
	return false, proximo, false
end

return Evento
