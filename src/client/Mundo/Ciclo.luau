-- Ciclo de dia e noite no cliente (regras e cores em Shared/Dados/Ciclo). Cada cliente calcula a
-- fase pelo relógio do servidor (todos veem a mesma hora, sem replicar nada) e ajusta o Lighting,
-- o céu, a névoa e a correção de cor que o servidor criou para o Nexo. As mudanças são locais e
-- suaves (a cada 0,1 s); os efeitos temporários de outros sistemas (ritual, câmera) usam as suas
-- próprias ColorCorrection e continuam funcionando por cima.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ciclo =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("Ciclo"))

local Mundo = {}

local ESTRELAS = 5000

function Mundo.segundos(): number
	return Workspace:GetServerTimeNow()
		+ (tonumber(Workspace:GetAttribute("CicloDeslocamento")) or 0)
end

function Mundo.estado(): Ciclo.Estado
	return Ciclo.estado(Mundo.segundos())
end

-- Evento Despertar do Sol (Shared/Dados/EventoSol): durante o aviso o céu vai clareando até o
-- "sol do meio-dia" branco e dourado, que fica durante a luta e se desfaz no fim. 0..1
function Mundo.fatorEvento(): number
	local fase = Workspace:GetAttribute("EventoFase")
	local fim = tonumber(Workspace:GetAttribute("EventoFim")) or 0
	local resta = fim - Workspace:GetServerTimeNow()
	if fase == "aviso" then
		return math.clamp(1 - resta / 60, 0, 1) * 0.85
	elseif fase == "luta" then
		return 1
	elseif fase == "fim" then
		return math.clamp(resta / 20, 0, 1)
	end
	return 0
end

-- Céu do evento: claro, quente e com pouca névoa (sem estourar: brilho e exposição contidos)
local SOL = {
	relogio = 13,
	brilho = 2.2,
	exposicao = -0.05,
	ambiente = Color3.fromHex("B89A6A"),
	externo = Color3.fromHex("C8B088"),
	topo = Color3.fromHex("FFF1C8"),
	baixo = Color3.fromHex("FFD27A"),
	nevoa = Color3.fromHex("FFF0C8"),
	densidade = 0.28,
	bruma = 1.2,
	tinta = Color3.fromHex("FFF6E2"),
	saturacao = 0.18,
}

local function misturar(luz: any, k: number): any
	if k <= 0 then
		return luz
	end
	local m = table.clone(luz)
	for chave, alvo in SOL do
		local v = luz[chave]
		if typeof(v) == "Color3" then
			m[chave] = v:Lerp(alvo, k)
		elseif type(v) == "number" then
			m[chave] = v + (alvo - v) * k
		end
	end
	m.estrelas = luz.estrelas * (1 - k)
	return m
end

local function aplicar()
	local e = Mundo.estado()
	local k = Mundo.fatorEvento()
	local luz = misturar(Ciclo.luz(e.relogio), k)
	Lighting.ClockTime = e.relogio + (SOL.relogio - e.relogio) * k
	Lighting.Brightness = luz.brilho
	Lighting.ExposureCompensation = luz.exposicao
	Lighting.Ambient = luz.ambiente
	Lighting.OutdoorAmbient = luz.externo
	Lighting.ColorShift_Top = luz.topo
	Lighting.ColorShift_Bottom = luz.baixo
	local ceu = Lighting:FindFirstChildOfClass("Sky")
	if ceu then
		ceu.StarCount = math.floor(ESTRELAS * luz.estrelas)
		ceu.CelestialBodiesShown = luz.astros
	end
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosfera then
		atmosfera.Color = luz.nevoa
		atmosfera.Decay = luz.decaimento
		atmosfera.Density = luz.densidade
		atmosfera.Haze = luz.bruma
		atmosfera.Glare = luz.brilhoSol
	end
	local cor = Lighting:FindFirstChild("NexoCor")
	if cor and cor:IsA("ColorCorrectionEffect") then
		cor.TintColor = luz.tinta
		cor.Saturation = luz.saturacao
	end
end

function Mundo.iniciar()
	task.spawn(function()
		while true do
			local ok, erro = pcall(aplicar)
			if not ok then
				warn("[Ciclo] " .. tostring(erro))
			end
			task.wait(0.1)
		end
	end)
end

return Mundo
