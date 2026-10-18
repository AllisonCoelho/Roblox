-- Ajusta o tamanho da interface à tela.
-- As telas são desenhadas em "pixels de design" (referência 1600x900); um UIScale converte.
-- Em celular deitado (tela baixa e toque) usamos o layout compacto do design 06.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = require(ReplicatedStorage.Shared.Tema)

local Escala = {}

Escala.escala = 1
Escala.compacto = false
Escala.tamanho = Tema.Referencia -- tamanho da raiz em pixels de design
-- "auto" decide pelo aparelho; "sim"/"nao" forçam (opção em Ajustes, útil para testar no PC)
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
	local toque = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local compacto = if Escala.modoCompacto == "auto"
		then (toque and real.Y < 560)
		else Escala.modoCompacto == "sim"
	local s
	if compacto then
		s = math.clamp(real.Y / 700, 0.45, 1)
	else
		s = math.clamp(math.min(real.X / Tema.Referencia.X, real.Y / Tema.Referencia.Y), 0.55, 1.4)
	end
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
