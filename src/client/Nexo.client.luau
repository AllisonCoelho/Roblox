-- Vida do mapa no cliente: anima o Núcleo do Despertar (flutua, pulsa, anéis orbitais) e
-- trata as interações por proximidade. Só visual e navegação de interface.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Remotos = require(Shared.Remotos)
local UI = script.Parent:WaitForChild("UI")
local Navegacao = require(UI:WaitForChild("Navegacao"))
local Avisos = require(UI:WaitForChild("Telas"):WaitForChild("Avisos"))

local K_CIRCULO = 0.5523 -- fator de Bézier para 4 arcos formarem um círculo

local nexo = workspace:WaitForChild("Nexo")
local nucleo = nexo:WaitForChild("Nucleo")
local coracao = nucleo:WaitForChild("Coracao") :: BasePart
local casca = nucleo:WaitForChild("Casca") :: BasePart
local luz = coracao:FindFirstChildOfClass("PointLight")
local centro = coracao.Position
local tamanho = coracao.Size.X
local corBase = coracao.Color

-- Anel de energia feito com 4 Beams curvos em volta de uma peça invisível
local function criarAnel(raio: number, largura: number, cor: Color3): Part
	local base = Instance.new("Part")
	base.Name = "AnelNucleo"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.Transparency = 1
	base.Size = Vector3.new(0.2, 0.2, 0.2)
	local anexos = {}
	for k = 1, 4 do
		local a = (k - 1) * math.pi / 2
		local anexo = Instance.new("Attachment")
		anexo.CFrame = CFrame.fromMatrix(
			Vector3.new(math.cos(a) * raio, 0, math.sin(a) * raio),
			Vector3.new(-math.sin(a), 0, math.cos(a)),
			Vector3.yAxis
		)
		anexo.Parent = base
		anexos[k] = anexo
	end
	for k = 1, 3 do -- 3 arcos: a abertura deixa a rotação visível
		local feixe = Instance.new("Beam")
		feixe.Attachment0 = anexos[k]
		feixe.Attachment1 = anexos[k % 4 + 1]
		feixe.CurveSize0 = K_CIRCULO * raio
		feixe.CurveSize1 = K_CIRCULO * raio
		feixe.Width0, feixe.Width1 = largura, largura
		feixe.Color = ColorSequence.new(cor)
		feixe.Transparency = NumberSequence.new(0.15)
		feixe.LightEmission = 1
		feixe.LightInfluence = 0
		feixe.FaceCamera = true
		feixe.Segments = 14
		feixe.Parent = base
	end
	base.Parent = nucleo
	return base
end

local aneis = {
	{
		parte = criarAnel(7, 0.35, corBase),
		inclinacao = CFrame.Angles(math.rad(70), 0, 0),
		velocidade = 0.5,
	},
	{
		parte = criarAnel(9, 0.25, Color3.fromHex("A855F7")),
		inclinacao = CFrame.Angles(math.rad(40), 0, math.rad(55)),
		velocidade = -0.35,
	},
	{
		parte = criarAnel(11, 0.2, Color3.fromHex("FFC83D")),
		inclinacao = CFrame.Angles(math.rad(-25), 0, math.rad(-60)),
		velocidade = 0.22,
	},
}

-- O Núcleo reage quando alguém do servidor desperta uma aura rara
local agitadoAte = 0
local corAgitada = corBase
Remotos.evento("Despertou").OnClientEvent:Connect(function(dados: any)
	local aura = if type(dados) == "table" and type(dados.aura) == "string"
		then Auras.porId[dados.aura]
		else nil
	-- Mesmo limiar do anúncio, independentemente de quando o servidor dispara o evento
	if aura and aura.chance >= Auras.ANUNCIO_MINIMO then
		agitadoAte = os.clock() + 4
		corAgitada = Color3.fromHex(Auras.Tiers[aura.tier].cor)
	end
end)

local angulos = { 0, 0, 0 }
local ultimo = os.clock()
RunService.Heartbeat:Connect(function()
	local agora = os.clock()
	local dt = agora - ultimo
	ultimo = agora
	local agitacao = math.clamp((agitadoAte - agora) / 4, 0, 1)
	local posicao = centro + Vector3.new(0, math.sin(agora * 0.8) * 0.8, 0)
	local pulso = 1
		+ 0.05 * math.sin(agora * 2.2)
		+ 0.25 * agitacao * (0.5 + 0.5 * math.sin(agora * 14))
	coracao.CFrame = CFrame.new(posicao)
	coracao.Size = Vector3.one * tamanho * pulso
	coracao.Color = corBase:Lerp(corAgitada, agitacao)
	casca.CFrame = CFrame.new(posicao) * CFrame.Angles(0, agora * 0.3, 0)
	if luz then
		luz.Brightness = 2.5 + 3 * agitacao
		luz.Color = coracao.Color
	end
	for i, anel in aneis do
		angulos[i] += dt * anel.velocidade * (1 + 5 * agitacao)
		anel.parte.CFrame = CFrame.new(posicao)
			* CFrame.Angles(0, agora * 0.1, 0)
			* anel.inclinacao
			* CFrame.Angles(0, angulos[i], 0)
	end
end)

-- Interações do mapa
ProximityPromptService.PromptTriggered:Connect(function(prompt, jogador)
	if jogador ~= Players.LocalPlayer then
		return
	end
	local acao = prompt:GetAttribute("Acao")
	if acao == "indice" then
		Navegacao.abrir("Indice")
	elseif acao == "em_construcao" or acao == "eco" then
		local texto = prompt:GetAttribute("Texto")
		if type(texto) == "string" then
			-- A interface pode ainda estar carregando no primeiro segundo de jogo
			pcall(Avisos.toast, texto)
		end
	end
end)
