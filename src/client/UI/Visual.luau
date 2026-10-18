-- Mostra um Docinho 3D dentro da interface (ViewportFrame).
-- Usa o modelo feito com a IA do Roblox quando existir, senão o provisório.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modelos = require(ReplicatedStorage.Shared.Dados.Modelos)

local Visual = {}

local CAMPO_DE_VISAO = 30
local DOURADO = Color3.fromRGB(255, 214, 90)

type Giro = { modelo: Model, base: CFrame, angulo: number }
local girando: { [ViewportFrame]: Giro } = setmetatable({}, { __mode = "k" }) :: any
local arcoIris: { [ViewportFrame]: boolean } = setmetatable({}, { __mode = "k" }) :: any

export type Opcoes = {
	variante: string?,
	silhueta: boolean?, -- ainda não descoberto: só a sombra preta
	girar: boolean?,
	tamanho: UDim2?,
	posicao: UDim2?,
	ancora: Vector2?,
	ordem: number?,
	pai: Instance?,
}

local function enquadrar(vp: ViewportFrame, modelo: Model)
	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMPO_DE_VISAO
	camera.Parent = vp
	vp.CurrentCamera = camera
	local caixa, tamanho = modelo:GetBoundingBox()
	local frente = Modelos.frente(modelo)
	local raio = math.max(tamanho.X, tamanho.Y, tamanho.Z) / 2
	local distancia = raio / math.tan(math.rad(CAMPO_DE_VISAO / 2)) * 1.35
	local centro = caixa.Position
	camera.CFrame =
		CFrame.lookAt(centro + frente * distancia + Vector3.new(0, tamanho.Y * 0.15, 0), centro)
end

function Visual.docinho(id: string, op: Opcoes?): ViewportFrame
	local o = op or {}
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Docinho_" .. id
	vp.BackgroundTransparency = 1
	vp.Size = o.tamanho or UDim2.fromOffset(160, 160)
	vp.Position = o.posicao or UDim2.new()
	vp.AnchorPoint = o.ancora or Vector2.zero
	vp.LayoutOrder = o.ordem or 0
	vp.Ambient = Color3.fromRGB(200, 190, 210)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)

	local modelo = Modelos.criar(id)
	modelo.Parent = vp
	enquadrar(vp, modelo)

	if o.silhueta then
		vp.ImageColor3 = Color3.new(0, 0, 0)
		vp.ImageTransparency = 0.65
	elseif o.variante == "dourado" then
		vp.ImageColor3 = DOURADO
	elseif o.variante == "arcoiris" then
		arcoIris[vp] = true
	end
	if o.girar then
		girando[vp] = { modelo = modelo, base = modelo:GetPivot(), angulo = 0 }
	end
	if o.pai then
		vp.Parent = o.pai
	end
	return vp
end

function Visual.iniciar()
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for vp, g in girando do
			if vp.Parent and vp.Visible then
				g.angulo += dt * 0.9
				-- Balança de um lado para o outro (o rosto continua quase sempre de frente)
				g.modelo:PivotTo(g.base * CFrame.Angles(0, math.sin(g.angulo) * 0.6, 0))
			end
		end
		for vp in arcoIris do
			if vp.Parent then
				vp.ImageColor3 = Color3.fromHSV((t * 0.25) % 1, 0.45, 1)
			end
		end
	end)
end

return Visual
