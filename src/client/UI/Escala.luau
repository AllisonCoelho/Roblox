-- Ajusta o tamanho da interface à tela.
-- As telas são desenhadas em "pixels de design" (referência 1600x900); um UIScale converte.
-- Toque e telas menores usam as posições e dimensões compactas da Órbita do Nexo.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = require(ReplicatedStorage.Shared.Tema)

local Escala = {}

Escala.escala = 1
Escala.compacto = false
Escala.toque = false
Escala.controle = false
Escala.teclado = true
Escala.tamanho = Tema.Referencia -- tamanho da raiz em pixels de design
-- "auto" decide pela tela e pelo dispositivo de entrada atual.
Escala.modoCompacto = "auto"

local ouvintes: { () -> () } = {}
local raiz: Frame
local uiScale: UIScale
local tela: ScreenGui

function Escala.aoMudar(fn: () -> ())
	table.insert(ouvintes, fn)
	task.spawn(fn)
end

local function recalcular()
	local real = tela.AbsoluteSize
	if real.X <= 0 or real.Y <= 0 then
		return
	end
	local entrada = UserInputService:GetLastInputType()
	local controle = string.sub(entrada.Name, 1, 7) == "Gamepad"
	local toque = UserInputService.TouchEnabled
		and (entrada == Enum.UserInputType.Touch or (not UserInputService.KeyboardEnabled and not controle))
	local compacto = if Escala.modoCompacto == "auto"
		then toque or real.X < 860 or real.Y < 510
		else Escala.modoCompacto == "sim"
	local referencia = if compacto then Vector2.new(1120, 480) else Tema.Referencia
	local s = math.clamp(math.min(real.X / referencia.X, real.Y / referencia.Y), 0.75, 1.35)
	Escala.toque = toque
	Escala.controle = controle
	Escala.teclado = UserInputService.KeyboardEnabled and not toque and not controle
	Escala.escala = s
	Escala.compacto = compacto
	Escala.tamanho = Vector2.new(real.X / s, real.Y / s)
	uiScale.Scale = s
	raiz.Size = UDim2.fromOffset(Escala.tamanho.X, Escala.tamanho.Y)
	for _, fn in ouvintes do
		task.spawn(fn)
	end
end

function Escala.definirModo(modo: string)
	Escala.modoCompacto = modo
	recalcular()
end

-- Cria a raiz escalada dentro da ScreenGui e devolve o Frame onde a interface é montada
function Escala.montar(screenGui: ScreenGui): Frame
	tela = screenGui
	raiz = Instance.new("Frame")
	raiz.Name = "Raiz"
	raiz.BackgroundTransparency = 1
	-- Ancorada no centro: o UIScale cresce/encolhe sem tirar a raiz do lugar
	raiz.AnchorPoint = Vector2.new(0.5, 0.5)
	raiz.Position = UDim2.fromScale(0.5, 0.5)
	raiz.Parent = screenGui
	uiScale = Instance.new("UIScale")
	uiScale.Parent = raiz
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(recalcular)
	UserInputService.LastInputTypeChanged:Connect(recalcular)
	recalcular()
	return raiz
end

return Escala
