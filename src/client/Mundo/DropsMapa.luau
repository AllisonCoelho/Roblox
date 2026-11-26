-- Drops aleatórios do mapa no cliente (só visual). O servidor cria em Workspace.DropsMapa uma peça
-- invisível por drop (atributos Tipo, Ate e Id); aqui cada uma ganha o modelo feito no Blender
-- (Dados/DropsVisual), flutua e gira. A Estrela Cadente tem um feixe de luz para ser vista de
-- longe. Perto de sumir, o drop pisca. Quando alguém pega (evento "DropsMapa"), o drop voa até
-- quem pegou e, para quem pegou, sobe o texto do prêmio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visual = require(Shared:WaitForChild("Dados"):WaitForChild("DropsVisual"))
local DropsDados = require(Shared.Dados:WaitForChild("DropsMapa"))
local Remotos = require(Shared:WaitForChild("Remotos"))
local Malha = require(script.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))
local Sons = require(script.Parent:WaitForChild("Sons"))

local Mundo = {}

type Camada = { parte: MeshPart, centro: Vector3 }
type Item = {
	alvo: BasePart,
	camadas: { Camada },
	feixe: Part?,
	fase: number,
	ate: number,
	tipo: string,
}

local prontas: Malha.Cache = {}
local itens: { [number]: Item } = {}
local pasta: Folder

local ESCALA = { orbe = 1.15, lasca = 1.2, estrela = 1.3 }

local montando: { [number]: boolean } = {}

local function montar(alvo: Instance)
	if not alvo:IsA("BasePart") then
		return
	end
	local id = alvo:GetAttribute("Id")
	local tipo = alvo:GetAttribute("Tipo")
	if type(id) ~= "number" or type(tipo) ~= "string" or itens[id] or montando[id] then
		return
	end
	-- a conversão das malhas leva alguns quadros: marca para não montar o mesmo drop duas vezes
	montando[id] = true
	local item: Item = {
		alvo = alvo,
		camadas = {},
		feixe = nil,
		fase = math.random() * 6,
		ate = tonumber(alvo:GetAttribute("Ate")) or math.huge,
		tipo = tipo,
	}
	local escala = ESCALA[tipo] or 1
	for _, m in (Visual :: any)[tipo] or {} do
		local ok, parte, centro = pcall(Malha.criar, m.malha, prontas)
		if ok then
			parte.Size *= escala
			parte.Material = (Enum.Material :: any)[m.material] or Enum.Material.SmoothPlastic
			parte.CastShadow = false
			if m.material == "Glass" then
				parte.Transparency = 0.25
			end
			parte.Parent = pasta
			table.insert(item.camadas, { parte = parte, centro = centro * escala })
		end
	end
	local dados = DropsDados.porId[tipo]
	local cor = if dados then Color3.fromHex(dados.cor) else Color3.new(1, 1, 1)
	local primeira = item.camadas[#item.camadas]
	if primeira then
		local luz = Instance.new("PointLight")
		luz.Color = cor
		luz.Range = if tipo == "estrela" then 16 else 9
		luz.Brightness = if tipo == "estrela" then 2.2 else 1.2
		luz.Shadows = false
		luz.Parent = primeira.parte
	end
	if tipo == "estrela" then
		local feixe = Instance.new("Part")
		feixe.Name = "FeixeEstrela"
		feixe.Anchored = true
		feixe.CanCollide = false
		feixe.CanQuery = false
		feixe.CanTouch = false
		feixe.CastShadow = false
		feixe.Material = Enum.Material.Neon
		feixe.Color = cor
		feixe.Transparency = 0.55
		feixe.Shape = Enum.PartType.Cylinder
		feixe.Size = Vector3.new(60, 0.7, 0.7)
		feixe.CFrame = CFrame.new(alvo.Position + Vector3.new(0, 30, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		feixe.Parent = pasta
		item.feixe = feixe
	end
	montando[id] = nil
	-- alguém pegou (ou o drop sumiu) enquanto o modelo era montado
	if not alvo.Parent then
		for _, c in item.camadas do
			c.parte:Destroy()
		end
		if item.feixe then
			item.feixe:Destroy()
		end
		return
	end
	itens[id] = item
end

local function remover(id: number, item: Item)
	itens[id] = nil
	for _, c in item.camadas do
		c.parte:Destroy()
	end
	if item.feixe then
		item.feixe:Destroy()
	end
end

-- Texto do prêmio subindo e sumindo (só para quem pegou)
local function textoFlutuante(pos: Vector3, texto: string, cor: Color3)
	local ancora = Instance.new("Part")
	ancora.Anchored = true
	ancora.CanCollide = false
	ancora.CanQuery = false
	ancora.CanTouch = false
	ancora.Transparency = 1
	ancora.Size = Vector3.one * 0.2
	ancora.Position = pos
	ancora.Parent = pasta
	local quadro = Instance.new("BillboardGui")
	quadro.Size = UDim2.fromOffset(340, 60)
	quadro.StudsOffset = Vector3.new(0, 2, 0)
	quadro.AlwaysOnTop = true
	quadro.LightInfluence = 0
	quadro.Parent = ancora
	local rotulo = Instance.new("TextLabel")
	rotulo.BackgroundTransparency = 1
	rotulo.Size = UDim2.fromScale(1, 1)
	rotulo.Font = Enum.Font.GothamBold
	rotulo.TextScaled = true
	rotulo.TextWrapped = true
	rotulo.TextColor3 = cor
	rotulo.TextStrokeTransparency = 0.35
	rotulo.Text = texto
	rotulo.Parent = quadro
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ancora, info, { Position = pos + Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(rotulo, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.7, function()
		ancora:Destroy()
	end)
end

local function coletado(dados: any)
	if type(dados) ~= "table" or type(dados.id) ~= "number" then
		return
	end
	local item = itens[dados.id]
	if not item then
		return
	end
	itens[dados.id] = nil
	local quem = Players:GetPlayerByUserId(tonumber(dados.de) or 0)
	local raiz = quem and quem.Character and quem.Character:FindFirstChild("HumanoidRootPart")
	local destino = if raiz and raiz:IsA("BasePart") then raiz.Position else nil
	local inicio = if item.camadas[1] then item.camadas[1].parte.Position else Vector3.zero
	local tipo = DropsDados.porId[item.tipo]
	local cor = if tipo then Color3.fromHex(tipo.cor) else Color3.new(1, 1, 1)
	if quem == Players.LocalPlayer then
		Sons.tocar(
			if item.tipo == "estrela" then "revelacao" else "chamado",
			Workspace,
			if item.tipo == "lasca" then 1.3 else 1.6,
			0.35
		)
		if type(dados.texto) == "string" then
			textoFlutuante(inicio, dados.texto, cor)
		end
	end
	if item.feixe then
		item.feixe:Destroy()
		item.feixe = nil
	end
	-- o drop voa até quem pegou e encolhe
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, c in item.camadas do
		TweenService:Create(c.parte, info, {
			Position = destino or (c.parte.Position + Vector3.new(0, 3, 0)),
			Size = c.parte.Size * 0.1,
		}):Play()
	end
	task.delay(0.4, function()
		for _, c in item.camadas do
			c.parte:Destroy()
		end
	end)
end

function Mundo.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "DropsVisiveis"
	pasta.Parent = Workspace
	task.spawn(function()
		local origem = Workspace:WaitForChild("DropsMapa")
		origem.ChildAdded:Connect(function(filho)
			-- os atributos chegam junto com a peça; espera um quadro por garantia
			task.defer(montar, filho)
		end)
		origem.ChildRemoved:Connect(function(filho)
			local id = filho:GetAttribute("Id")
			local item = if type(id) == "number" then itens[id] else nil
			if item then
				-- some sem ninguém pegar (venceu): só encolhe
				task.delay(0.6, function()
					if itens[id] == item then
						remover(id, item)
					end
				end)
			end
		end)
		for _, filho in origem:GetChildren() do
			montar(filho)
		end
	end)
	Remotos.evento("DropsMapa").OnClientEvent:Connect(coletado)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local agora = Workspace:GetServerTimeNow()
		for _, item in itens do
			local base = item.alvo.Position
			local sobe = math.sin(t * 2 + item.fase) * 0.35
			local giro = CFrame.Angles(0, t * 1.4 + item.fase, 0)
			local restante = item.ate - agora
			-- pisca nos últimos 10 segundos
			local some = restante < 10 and math.floor(t * 6) % 2 == 0
			for _, c in item.camadas do
				c.parte.CFrame = CFrame.new(base + Vector3.new(0, sobe, 0))
					* giro
					* CFrame.new(c.centro)
				c.parte.LocalTransparencyModifier = if some then 0.7 else 0
			end
		end
	end)
end

return Mundo
