-- Anima a Chuva de Doces no cliente: cada Docinho cai do céu girando até o ponto de pouso
-- (mesma conta do servidor em Shared/Dados/Chuva.luau) e depois fica quicando no chão.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChuvaDados = require(ReplicatedStorage.Shared.Dados.Chuva)

local ChuvaVisual = {}

function ChuvaVisual.iniciar()
	local pasta = workspace:WaitForChild("Chuva")
	RunService.RenderStepped:Connect(function()
		local agora = workspace:GetServerTimeNow()
		for _, modelo in pasta:GetChildren() do
			if not modelo:IsA("Model") then
				continue
			end
			local inicio = modelo:GetAttribute("Inicio")
			local alturaBase = modelo:GetAttribute("AlturaBase")
			local pouso = modelo:GetAttribute("Pouso")
			if
				type(inicio) ~= "number"
				or type(alturaBase) ~= "number"
				or typeof(pouso) ~= "Vector3"
			then
				continue
			end
			local p = pouso :: Vector3
			local altura = ChuvaDados.alturaNoAr(inicio, agora)
			if ChuvaDados.pousou(inicio, agora) then
				-- No chão: quica de leve para chamar atenção
				altura = 0.4 + math.abs(math.sin((agora - inicio) * 3)) * 0.8
			end
			local giro = (agora - inicio) * 2.5
			modelo:PivotTo(
				CFrame.new(p + Vector3.new(0, alturaBase + altura, 0)) * CFrame.Angles(0, giro, 0)
			)
		end
	end)
end

return ChuvaVisual
