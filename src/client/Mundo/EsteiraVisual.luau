-- Anima os Docinhos da esteira no cliente.
-- O servidor deixa cada Docinho parado no começo da esteira com o atributo "Inicio";
-- aqui calculamos a posição pelo tempo (mesma conta do servidor), sem gastar rede.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EsteiraDados = require(ReplicatedStorage.Shared.Dados.Esteira)

local EsteiraVisual = {}

local player = Players.LocalPlayer

-- Enquanto carrega um Docinho, os "aperte E" da esteira somem (só dá para levar um por vez)
local function atualizarPrompts(pasta: Instance)
	local carregando = player:GetAttribute("Carregando") ~= nil
	for _, prompt in pasta:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = not carregando
		end
	end
end

function EsteiraVisual.iniciar()
	local pasta = workspace:WaitForChild("Esteira")
	player:GetAttributeChangedSignal("Carregando"):Connect(function()
		atualizarPrompts(pasta)
	end)
	pasta.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			d.Enabled = player:GetAttribute("Carregando") == nil
		end
	end)
	atualizarPrompts(pasta)

	RunService.RenderStepped:Connect(function()
		local agora = workspace:GetServerTimeNow()
		local camera = workspace.CurrentCamera
		for _, modelo in pasta:GetChildren() do
			if not modelo:IsA("Model") then
				continue
			end
			local inicio = modelo:GetAttribute("Inicio")
			local alturaBase = modelo:GetAttribute("AlturaBase")
			if type(inicio) ~= "number" or type(alturaBase) ~= "number" then
				continue
			end
			local posicao = EsteiraDados.posicao(inicio, agora) + Vector3.new(0, alturaBase, 0)
			-- O Docinho olha para a câmera (gira só no eixo vertical)
			local alvo = if camera
				then Vector3.new(camera.CFrame.Position.X, posicao.Y, camera.CFrame.Position.Z)
				else posicao + Vector3.new(1, 0, 0)
			local cf = if (alvo - posicao).Magnitude > 0.1
				then CFrame.lookAt(posicao, alvo)
				else CFrame.new(posicao)
			local giro = modelo:GetAttribute("GiroY")
			if type(giro) == "number" then
				cf *= CFrame.Angles(0, -math.rad(giro), 0)
			end
			modelo:PivotTo(cf)
		end
	end)
end

return EsteiraVisual
