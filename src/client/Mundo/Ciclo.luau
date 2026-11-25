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

local function aplicar()
	local e = Mundo.estado()
	local luz = Ciclo.luz(e.relogio)
	Lighting.ClockTime = e.relogio
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
