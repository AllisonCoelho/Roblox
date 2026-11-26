-- Música ambiente procedural (só regras puras, testadas em testes/logica.luau). Não usa nenhuma
-- faixa de áudio: o cliente (Mundo/Musica) toca as notas com os sons que já vêm com o Roblox
-- (rbxasset), mudando o tom (PlaybackSpeed = 2^(semitons/12)). Assim o jogo nunca fica mudo e
-- não depende de áudio enviado nem de terceiros.
--
--   calmo   78 bpm: baixo no começo do compasso e uma melodia suave, sorteada nas notas do
--           acorde (progressão I–vi–IV–V)
--   aviso  120 bpm: o evento vai começar — bumbo, chimbal e uma nota que sobe a cada compasso
--   evento 132 bpm: tambores completos e arpejo rápido brilhante
local Musica = {}

export type Modo = "calmo" | "aviso" | "evento"
export type Nota = { som: "ping" | "baixo" | "batida", semitons: number, volume: number }

Musica.PASSOS = 8 -- colcheias por compasso
Musica.BPM = { calmo = 78, aviso = 120, evento = 132 } :: { [string]: number }

-- Progressão I–vi–IV–V (semitons da tônica) e as notas de cada acorde
Musica.PROGRESSAO = { 0, -3, -7, -5 }
Musica.ACORDES = {
	{ 0, 4, 7 },
	{ 0, 3, 7 },
	{ 0, 4, 7 },
	{ 0, 4, 7 },
}
Musica.PENTATONICA = { 0, 2, 4, 7, 9 }

-- Segundos de uma colcheia
function Musica.duracaoPasso(modo: string): number
	local bpm = Musica.BPM[modo] or Musica.BPM.calmo
	return 60 / bpm / 2
end

-- Modo da música pela fase do evento (atributo EventoFase do Workspace)
function Musica.modo(fase: any): Modo
	if fase == "aviso" then
		return "aviso"
	elseif fase == "luta" then
		return "evento"
	end
	return "calmo"
end

-- PlaybackSpeed de uma nota
function Musica.tom(semitons: number): number
	return 2 ^ (semitons / 12)
end

-- Notas do passo `passo` (contado desde o começo; 8 por compasso). `aleatorio` devolve [0, 1)
function Musica.notas(modo: string, passo: number, aleatorio: () -> number): { Nota }
	local compasso = passo // Musica.PASSOS
	local dentro = passo % Musica.PASSOS
	local i = compasso % #Musica.PROGRESSAO + 1
	local raiz = Musica.PROGRESSAO[i]
	local acorde = Musica.ACORDES[i]
	local saida: { Nota } = {}
	local function nota(som, semitons, volume)
		table.insert(saida, { som = som, semitons = semitons, volume = volume })
	end
	if modo == "calmo" then
		if dentro == 0 then
			nota("baixo", raiz - 12, 0.16)
		elseif dentro == 4 and aleatorio() < 0.5 then
			nota("baixo", raiz - 12 + 7, 0.1)
		end
		-- melodia esparsa: mais provável nos tempos fortes
		local chance = if dentro % 2 == 0 then 0.55 else 0.2
		if aleatorio() < chance then
			local t = acorde[math.floor(aleatorio() * #acorde) + 1]
			local oitava = if aleatorio() < 0.3 then 24 else 12
			nota("ping", raiz + t + oitava, 0.05 + aleatorio() * 0.04)
		end
	elseif modo == "aviso" then
		if dentro == 0 or dentro == 4 then
			nota("baixo", -12, 0.28)
		end
		nota("batida", 12, if dentro % 2 == 1 then 0.08 else 0.04)
		if dentro == 0 then
			-- sobe meio tom a cada compasso: a tensão crescendo até o Titã chegar
			nota("ping", 12 + compasso % 12, 0.12)
		end
	else
		if dentro == 0 or dentro == 3 or dentro == 4 then
			nota("baixo", raiz - 12, 0.3)
		end
		if dentro == 2 or dentro == 6 then
			nota("batida", -4, 0.18)
		end
		nota("batida", 14, 0.05)
		-- arpejo brilhante: sobe e desce nas notas do acorde
		local arpejo = { 0, 1, 2, 3, 2, 1, 2, 3 }
		local grau = arpejo[dentro + 1]
		local t = if grau == 3 then 12 else acorde[grau + 1]
		nota("ping", raiz + t + 12, 0.07)
	end
	return saida
end

return Musica
