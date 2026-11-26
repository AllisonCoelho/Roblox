-- Estátua da Gear 5 na praça (só visual; o pedestal e a interação são do servidor, em
-- Servicos/Estatua). Um boneco de mármore gigante (Dados/Bonecos "estatua") com o punho erguido,
-- auréola de sol girando, faíscas, um pilar de luz e uma placa com a contagem do próximo evento
-- Despertar do Sol: o prêmio do jogo fica à vista desde o primeiro segundo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bonecos = require(Shared:WaitForChild("Dados"):WaitForChild("Bonecos"))
local PrimeirosMinutos = require(Shared:WaitForChild("Dados"):WaitForChild("PrimeirosMinutos"))
local Boneco = require(script.Parent:WaitForChild("Boneco"))

local Mundo = {}

local OURO = Color3.fromHex("FFD54A")

local function placa(corpo: BasePart): TextLabel
	local g = Instance.new("BillboardGui")
	g.Name = "PlacaEstatua"
	g.Size = UDim2.fromOffset(300, 96)
	g.StudsOffset = Vector3.new(0, 10.5, 0)
	g.LightInfluence = 0
	g.MaxDistance = 220
	g.Adornee = corpo
	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Size = UDim2.fromScale(1, 0.42)
	titulo.Font = Enum.Font.GothamBlack
	titulo.TextScaled = true
	titulo.Text = "☀ AURA GEAR 5 ☀"
	titulo.TextColor3 = Color3.new(1, 1, 1)
	titulo.TextStrokeColor3 = Color3.fromHex("6A4200")
	titulo.TextStrokeTransparency = 0
	titulo.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, OURO),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, OURO),
	})
	grad.Parent = titulo
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.42)
	sub.Size = UDim2.fromScale(1, 0.26)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.Text = "Só no baú do evento Despertar do Sol"
	sub.TextColor3 = Color3.fromHex("FFF1B0")
	sub.TextStrokeTransparency = 0.2
	sub.Parent = g
	local contagem = Instance.new("TextLabel")
	contagem.BackgroundTransparency = 1
	contagem.Position = UDim2.fromScale(0, 0.7)
	contagem.Size = UDim2.fromScale(1, 0.3)
	contagem.Font = Enum.Font.GothamBlack
	contagem.TextScaled = true
	contagem.TextColor3 = Color3.fromHex("B7FFD9")
	contagem.TextStrokeTransparency = 0.2
	contagem.Parent = g
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.spawn(function()
		while g.Parent do
			grad.Offset = Vector2.new(math.sin(os.clock() * 1.5) * 0.6, 0)
			task.wait(0.05)
		end
	end)
	return contagem
end

local function pilar(corpo: BasePart, base: Vector3)
	local chao = Instance.new("Attachment")
	chao.WorldPosition = base
	chao.Parent = Workspace.Terrain
	local ceu = Instance.new("Attachment")
	ceu.WorldPosition = base + Vector3.new(0, 70, 0)
	ceu.Parent = Workspace.Terrain
	local b = Instance.new("Beam")
	b.Attachment0 = chao
	b.Attachment1 = ceu
	b.Texture = "rbxasset://textures/particles/forcefield_glow_main.dds"
	b.TextureSpeed = 0.4
	b.Color = ColorSequence.new(OURO, Color3.new(1, 1, 1))
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Transparency = NumberSequence.new(0.55, 1)
	b.Width0 = 7
	b.Width1 = 2
	b.FaceCamera = true
	b.Parent = corpo
	-- anéis dourados subindo do pedestal
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
	e.Color = ColorSequence.new(OURO)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.EmissionDirection = Enum.NormalId.Top
	e.Size = NumberSequence.new(4, 14)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(2, 2.4)
	e.Rate = 0.8
	e.Speed = NumberRange.new(2, 3)
	e.Parent = chao
end

function Mundo.iniciar()
	local modelo = Workspace:WaitForChild("EstatuaGear5", 60)
	local corpo = modelo and modelo:WaitForChild("Corpo", 10)
	if not corpo or not corpo:IsA("BasePart") then
		return
	end
	local base = corpo:GetAttribute("Base")
	if typeof(base) ~= "Vector3" then
		base = corpo.Position - Vector3.new(0, corpo.Size.Y / 2, 0)
	end
	local pes = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
	local pasta = Instance.new("Folder")
	pasta.Name = "EstatuaVisual"
	pasta.Parent = Workspace
	local estatua = Boneco.criar("estatua", pasta)
	pilar(corpo, base)
	local contagem = placa(corpo)
	local pose = Bonecos.pose("vitoria", 0)
	local ultimo = 0
	RunService.Heartbeat:Connect(function()
		local agora = os.clock()
		-- a estátua não respira: só a auréola gira e brilha
		estatua:posicionar(pes, pose, { giro = agora * 0.5 })
		if agora - ultimo > 0.25 then
			ultimo = agora
			local fim = tonumber(Workspace:GetAttribute("EventoFim")) or 0
			local fase = Workspace:GetAttribute("EventoFase")
			contagem.Text = PrimeirosMinutos.textoEstatua(
				if type(fase) == "string" then fase else nil,
				fim - Workspace:GetServerTimeNow()
			)
		end
	end)
end

return Mundo
