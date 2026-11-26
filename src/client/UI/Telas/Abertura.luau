-- Abertura de 8 segundos para quem nunca girou (Dados/PrimeirosMinutos). A câmera voa por cima
-- do Nexo, passa pela estátua da Gear 5 e volta para o jogador, com faixas de cinema, o título
-- e a promessa do jogo. Dá para pular. Depois dela o tutorial guiado da Lume começa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local PrimeirosMinutos = require(Shared.Dados.PrimeirosMinutos)
local ImagensUI = require(Shared.Dados.ImagensUI)
local Sons = require(script.Parent.Parent.Parent.Mundo.Sons)

local Abertura = {}

local tocando = false
local jaTocou = false

function Abertura.ativa(): boolean
	return tocando
end

local function suave(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Quadros-chave da câmera: { tempo, posição, para onde olha }
local function quadros(): { { number | Vector3 } }
	local e = PrimeirosMinutos.ESTATUA
	local estatua = Vector3.new(e.x, 12, e.z)
	return {
		{ 0, Vector3.new(0, 95, 130), Vector3.new(0, 12, 0) },
		{ 2.6, Vector3.new(70, 40, 70), Vector3.new(0, 14, 0) },
		{ 5.2, Vector3.new(e.x - 22, 14, e.z + 14), estatua },
		{ 8, Vector3.new(e.x - 30, 10, e.z - 6), estatua },
	}
end

local function texto(pai: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextTransparency = 1
	t.TextStrokeTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = pai
	return t
end

function Abertura.tocar()
	if tocando then
		return
	end
	tocando = true
	jaTocou = true
	local camera = Workspace.CurrentCamera
	local gui = Instance.new("ScreenGui")
	gui.Name = "Abertura"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- faixas de cinema
	local cima = Instance.new("Frame")
	cima.BackgroundColor3 = Color3.new(0, 0, 0)
	cima.BorderSizePixel = 0
	cima.Size = UDim2.new(1, 0, 0.12, 0)
	cima.Parent = gui
	local baixo = cima:Clone()
	baixo.AnchorPoint = Vector2.new(0, 1)
	baixo.Position = UDim2.fromScale(0, 1)
	baixo.Parent = gui
	local preto = Instance.new("Frame")
	preto.BackgroundColor3 = Color3.new(0, 0, 0)
	preto.BorderSizePixel = 0
	preto.Size = UDim2.fromScale(1, 1)
	preto.ZIndex = 5
	preto.Parent = gui
	TweenService:Create(preto, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	local titulo = texto(gui, {
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.7, 0.16),
		Text = "DESPERTAR",
		TextStrokeColor3 = Color3.fromHex("3A2A6A"),
		ZIndex = 3,
	})
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("C0ADFF")),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHex("FFD54A")),
	})
	grad.Parent = titulo
	local sub = texto(gui, {
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.4, 0.05),
		Text = "AURA RNG",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromHex("B7FFD9"),
		ZIndex = 3,
	})
	local promessa = texto(gui, {
		Position = UDim2.fromScale(0.5, 0.82),
		Size = UDim2.fromScale(0.8, 0.055),
		Text = "Gire. Desperte. Conquiste a GEAR 5.",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromHex("FFF1B0"),
		ZIndex = 3,
	})
	-- Logo e frase em imagem (Dados/ImagensUI) quando o dono já enviou; sem ID fica o texto
	local function imagem(id: string, pos: UDim2, tamanho: UDim2, proporcao: number): ImageLabel?
		if id == "" then
			return nil
		end
		local i = Instance.new("ImageLabel")
		i.BackgroundTransparency = 1
		i.Image = id
		i.ImageTransparency = 1
		i.AnchorPoint = Vector2.new(0.5, 0.5)
		i.Position = pos
		i.Size = tamanho
		i.ScaleType = Enum.ScaleType.Fit
		i.ZIndex = 3
		local r = Instance.new("UIAspectRatioConstraint")
		r.AspectRatio = proporcao
		r.Parent = i
		local esc = Instance.new("UIScale")
		esc.Scale = 0.85
		esc.Parent = i
		i.Parent = gui
		return i
	end
	local logo = imagem(
		ImagensUI.logoAbertura,
		UDim2.fromScale(0.5, 0.45),
		UDim2.fromScale(0.72, 0.5),
		1774 / 713
	)
	local frase = imagem(
		ImagensUI.fraseAbertura,
		UDim2.fromScale(0.5, 0.82),
		UDim2.fromScale(0.78, 0.09),
		1673 / 174
	)
	if logo then
		titulo.Visible = false
		sub.Visible = false
	end
	if frase then
		promessa.Visible = false
	end
	local pular = Instance.new("TextButton")
	pular.AnchorPoint = Vector2.new(1, 1)
	pular.Position = UDim2.new(1, -24, 1, -18)
	pular.Size = UDim2.fromOffset(130, 42)
	pular.BackgroundColor3 = Color3.fromHex("211C37")
	pular.BackgroundTransparency = 0.2
	pular.Font = Enum.Font.GothamBold
	pular.TextSize = 20
	pular.TextColor3 = Color3.new(1, 1, 1)
	pular.Text = "Pular  ›"
	pular.ZIndex = 6
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, 10)
	canto.Parent = pular
	pular.Parent = gui

	local function aparecer(t: TextLabel, visivel: boolean, dur: number)
		TweenService:Create(t, TweenInfo.new(dur), {
			TextTransparency = if visivel then 0 else 1,
			TextStrokeTransparency = if visivel then 0.2 else 1,
		}):Play()
	end
	-- imagem: aparece crescendo com um quique; some encolhendo de leve
	local function aparecerImagem(i: ImageLabel?, visivel: boolean, dur: number)
		if not i then
			return
		end
		TweenService:Create(i, TweenInfo.new(dur), { ImageTransparency = if visivel then 0 else 1 })
			:Play()
		local esc = i:FindFirstChildOfClass("UIScale")
		if esc then
			TweenService:Create(
				esc,
				TweenInfo.new(
					if visivel then dur * 1.4 else dur,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				),
				{ Scale = if visivel then 1 else 0.92 }
			):Play()
		end
	end

	local inicio = os.clock()
	local fim = false
	local function encerrar()
		if fim then
			return
		end
		fim = true
		RunService:UnbindFromRenderStep("Abertura")
		camera.CameraType = Enum.CameraType.Custom
		local humanoide = Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoide then
			camera.CameraSubject = humanoide
		end
		TweenService:Create(cima, TweenInfo.new(0.4), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		TweenService:Create(baixo, TweenInfo.new(0.4), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		aparecer(titulo, false, 0.3)
		aparecer(sub, false, 0.3)
		aparecer(promessa, false, 0.3)
		aparecerImagem(logo, false, 0.3)
		aparecerImagem(frase, false, 0.3)
		task.delay(0.45, function()
			gui:Destroy()
			tocando = false
		end)
	end
	pular.Activated:Connect(encerrar)

	local qs = quadros()
	local eventos = {
		{
			0.9,
			function()
				aparecer(titulo, true, 0.5)
				aparecerImagem(logo, true, 0.5)
				Sons.tocar("revelacao", camera, 0.8, 0.6)
			end,
		},
		{
			1.4,
			function()
				aparecer(sub, true, 0.5)
			end,
		},
		{
			3.6,
			function()
				aparecer(titulo, false, 0.6)
				aparecer(sub, false, 0.6)
				aparecerImagem(logo, false, 0.6)
			end,
		},
		{
			4.6,
			function()
				aparecer(promessa, true, 0.5)
				aparecerImagem(frase, true, 0.5)
				Sons.tocar("chamado", camera, 1.2, 0.5)
			end,
		},
	}
	local proximo = 1
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("Abertura", Enum.RenderPriority.Camera.Value + 10, function()
		local t = os.clock() - inicio
		grad.Offset = Vector2.new(math.sin(t * 1.6) * 0.5, 0)
		while eventos[proximo] and t >= (eventos[proximo][1] :: number) do
			(eventos[proximo][2] :: any)()
			proximo += 1
		end
		if t >= PrimeirosMinutos.ABERTURA then
			encerrar()
			return
		end
		-- interpola entre os quadros-chave
		for i = 1, #qs - 1 do
			local a, b = qs[i], qs[i + 1]
			if t <= (b[1] :: number) then
				local k = suave((t - (a[1] :: number)) / ((b[1] :: number) - (a[1] :: number)))
				local pos = (a[2] :: Vector3):Lerp(b[2] :: Vector3, k)
				local olhar = (a[3] :: Vector3):Lerp(b[3] :: Vector3, k)
				camera.CFrame = CFrame.lookAt(pos, olhar)
				break
			end
		end
	end)
end

-- Chamado quando o estado chega: toca uma vez por sessão para quem nunca girou
function Abertura.talvez(estado: any)
	if jaTocou or tocando then
		return
	end
	if PrimeirosMinutos.deveAbrir(estado) then
		Abertura.tocar()
	else
		jaTocou = true
	end
end

return Abertura
