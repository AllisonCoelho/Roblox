-- Coroa e título do Rei do Servidor (só visual). O servidor publica quem é o Rei no atributo
-- "ReiDoServidor" do Workspace (UserId; 0 = o trono está com o Primeiro Soberano). Aqui cada
-- cliente põe a coroa feita no Blender (Dados/CoroaVisual) flutuando e girando sobre a cabeça do
-- Rei e o título "REI DO SERVIDOR" acima dela.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Visual = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("CoroaVisual")
)
local Malha = require(script.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))

local Coroa = {}

type Camada = { parte: MeshPart, centro: Vector3, tamanho: Vector3 }

local camadas: { Camada } = {}
local titulo: BillboardGui
local pasta: Folder
local LARGURA_CABECA = 1.2 -- a coroa foi feita para uma cabeça R15 blocada

local function montar()
	local prontas: Malha.Cache = {}
	for _, m in Visual :: { any } do
		local ok, parte, centro = pcall(Malha.criar, m.malha, prontas)
		if ok then
			parte.Material = (Enum.Material :: any)[m.material] or Enum.Material.Metal
			parte.CastShadow = false
			parte.Parent = pasta
			table.insert(camadas, { parte = parte, centro = centro, tamanho = parte.Size })
		end
	end
	titulo = Instance.new("BillboardGui")
	titulo.Name = "TituloRei"
	titulo.Size = UDim2.fromOffset(220, 40)
	titulo.StudsOffset = Vector3.new(0, 3.6, 0)
	titulo.MaxDistance = 140
	titulo.LightInfluence = 0
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.fromScale(1, 1)
	texto.Font = Enum.Font.GothamBlack
	texto.TextScaled = true
	texto.Text = "👑 REI DO SERVIDOR"
	texto.TextColor3 = Color3.fromHex("FFD66B")
	texto.TextStrokeColor3 = Color3.fromHex("3A2200")
	texto.TextStrokeTransparency = 0.2
	texto.Parent = titulo
	titulo.Parent = pasta
end

local function cabecaDoRei(): BasePart?
	local id = Workspace:GetAttribute("ReiDoServidor")
	if type(id) ~= "number" or id == 0 then
		return nil
	end
	local rei = Players:GetPlayerByUserId(id)
	local personagem = rei and rei.Character
	local cabeca = personagem and personagem:FindFirstChild("Head")
	return if cabeca and cabeca:IsA("BasePart") then cabeca else nil
end

function Coroa.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "CoroaDoRei"
	pasta.Parent = Workspace
	montar()
	RunService:BindToRenderStep("CoroaDoRei", Enum.RenderPriority.Character.Value + 3, function()
		local cabeca = cabecaDoRei()
		if not cabeca then
			for _, c in camadas do
				c.parte.LocalTransparencyModifier = 1
			end
			titulo.Adornee = nil :: any
			titulo.Enabled = false
			return
		end
		local t = os.clock()
		local escala = cabeca.Size.X / LARGURA_CABECA
		local base = CFrame.new(cabeca.Position)
			* CFrame.new(0, cabeca.Size.Y / 2 + 0.6 * escala + math.sin(t * 2) * 0.06, 0)
			* CFrame.Angles(0, t * 0.9, 0)
		for _, c in camadas do
			local tamanho = c.tamanho * escala
			if c.parte.Size ~= tamanho then
				c.parte.Size = tamanho
			end
			c.parte.CFrame = base * CFrame.new(c.centro * escala)
			c.parte.LocalTransparencyModifier = cabeca.LocalTransparencyModifier
		end
		titulo.Adornee = cabeca
		titulo.Enabled = cabeca.LocalTransparencyModifier < 0.5
	end)
end

return Coroa
