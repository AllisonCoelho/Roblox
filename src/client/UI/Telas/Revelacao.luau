-- Revelação da aura para quem girou.
--   Comum/Incomum/Raro: sem cena (o HUD mostra o nome acima do botão e no feed).
--   Épico+: cena de cinema com a câmera no próprio personagem, sincronizada com
--   Mundo/Despertar (a pose e os efeitos que todos veem). Um toque/clique pula.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Tema = require(Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)
local Despertar = require(script.Parent.Parent.Parent.Mundo.Despertar)

local Cores = Tema.Cores
local Revelacao = {}

local camada: Frame
local barraCima: Frame
local barraBaixo: Frame
local clarao: Frame
local faixa: Frame
local faixaNome: TextLabel
local selo: Frame
local seloEscala: UIScale
local seloTier: TextLabel
local seloChance: TextLabel
local seloContorno: UIStroke

local token = 0
local ativa = false
local encerrar: (() -> ())? = nil

local BARRA = 90
local aoMudar: ((boolean) -> ())? = nil

-- Momento em que a última cena terminou (o clique que pula não deve girar de novo)
Revelacao.fimEm = 0

-- fn(true) quando a cena começa, fn(false) quando termina
function Revelacao.aoMudar(fn: (boolean) -> ())
	aoMudar = fn
end

local function tween(
	obj: Instance,
	tempo: number,
	props: { [string]: any },
	estilo: Enum.EasingStyle?
)
	local t = TweenService:Create(obj, TweenInfo.new(tempo, estilo or Enum.EasingStyle.Quad), props)
	t:Play()
	return t
end

function Revelacao.montar(raiz: Frame)
	camada = Kit.novo("Frame", {
		Name = "Revelacao",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = raiz,
	})
	barraCima = Kit.novo("Frame", {
		Name = "BarraCima",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 31,
		Parent = camada,
	})
	barraBaixo = Kit.novo("Frame", {
		Name = "BarraBaixo",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 31,
		Parent = camada,
	})
	clarao = Kit.novo("Frame", {
		Name = "Clarao",
		BackgroundColor3 = Cores.Papel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 32,
		Parent = camada,
	})

	-- Faixa vermelha inclinada com o nome
	faixa = Kit.novo("Frame", {
		Name = "Faixa",
		BackgroundColor3 = Cores.Selo,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.new(1.3, 0, 0, 150),
		Rotation = -6,
		Visible = false,
		ZIndex = 33,
		Parent = camada,
	})
	for _, cima in { true, false } do
		Kit.novo("Frame", {
			BackgroundColor3 = Cores.Papel,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, if cima then 0 else 1),
			Position = UDim2.fromScale(0, if cima then 0 else 1),
			Size = UDim2.new(1, 0, 0, 6),
			ZIndex = 34,
			Parent = faixa,
		})
	end
	faixaNome = Kit.texto({
		Name = "Nome",
		TextSize = 92,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 35,
		Parent = faixa,
	})
	Kit.novo("UIStroke", { Color = Cores.Tinta, Thickness = 4, Parent = faixaNome })

	-- Selo (carimbo) da raridade
	selo = Kit.circulo({
		Name = "Selo",
		BackgroundColor3 = Cores.Tinta,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 400, 0.55, 0),
		Size = UDim2.fromOffset(190, 190),
		Rotation = -14,
		Visible = false,
		ZIndex = 36,
		Parent = camada,
	})
	seloEscala = Kit.novo("UIScale", { Parent = selo })
	seloContorno = Kit.novo("UIStroke", { Thickness = 6, Parent = selo })
	seloTier = Kit.texto({
		fonte = "pincel",
		TextSize = 34,
		Position = UDim2.fromScale(0, 0.28),
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 37,
		Parent = selo,
	})
	seloChance = Kit.texto({
		fonte = "media",
		TextSize = 22,
		Position = UDim2.fromScale(0, 0.55),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 37,
		Parent = selo,
	})

	Kit.texto({
		fonte = "media",
		Text = "toque para pular",
		TextSize = 18,
		TextColor3 = Cores.TextoSuave,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -BARRA - 12),
		Size = UDim2.fromOffset(240, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 37,
		Parent = camada,
	})

	UserInputService.InputBegan:Connect(function(input)
		if not ativa then
			return
		end
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			Revelacao.pular()
		end
	end)
end

function Revelacao.ativa(): boolean
	return ativa
end

function Revelacao.pular()
	if encerrar then
		encerrar()
	end
end

-- Mostra o título (faixa + selo). Usado no fim da cena.
local function mostrarTitulo(aura: Auras.Aura)
	local tier = Auras.Tiers[aura.tier]
	local cor = Color3.fromHex(tier.cor)
	faixaNome.Text = string.upper(aura.nome)
	faixaNome.TextColor3 = Cores.Papel
	faixa.Visible = true
	faixa.Position = UDim2.fromScale(-0.8, 0.7)
	tween(faixa, 0.18, { Position = UDim2.fromScale(0.5, 0.7) }, Enum.EasingStyle.Quart)
	seloTier.Text = string.upper(tier.nome)
	seloTier.TextColor3 = cor
	seloChance.Text = "1 em " .. Formato.inteiro(aura.chance)
	seloContorno.Color = cor
	task.delay(0.2, function()
		if not faixa.Visible then
			return
		end
		selo.Visible = true
		seloEscala.Scale = 2.2
		tween(seloEscala, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

-- Toca a revelação. Devolve true se abriu uma cena (o giro automático espera ela acabar).
function Revelacao.mostrar(aura: Auras.Aura): boolean
	if aura.tier < Despertar.TIER_CUTSCENE then
		return false
	end
	if encerrar then
		encerrar()
	end
	token += 1
	local meu = token

	local jogador = Players.LocalPlayer
	local personagem = jogador.Character
	local raizPersonagem = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	local duracao = Despertar.duracao(aura)
	local cor = Color3.fromHex(Auras.Tiers[aura.tier].cor)

	ativa = true
	if aoMudar then
		task.spawn(aoMudar, true)
	end
	camada.Visible = true
	faixa.Visible = false
	selo.Visible = false
	tween(barraCima, 0.3, { Size = UDim2.new(1, 0, 0, BARRA) })
	tween(barraBaixo, 0.3, { Size = UDim2.new(1, 0, 0, BARRA) })

	-- Mundo mais escuro durante a cena (só para quem girou)
	local correcao = Instance.new("ColorCorrectionEffect")
	correcao.Name = "CenaDespertar"
	correcao.Parent = Lighting
	tween(correcao, Despertar.CARGA, { Brightness = -0.25, Saturation = -0.6 })

	-- Trava o personagem e assume a câmera
	local velocidade, pulo, alturaPulo
	if humanoide then
		velocidade, pulo, alturaPulo =
			humanoide.WalkSpeed, humanoide.JumpPower, humanoide.JumpHeight
		humanoide.WalkSpeed, humanoide.JumpPower, humanoide.JumpHeight = 0, 0, 0
	end
	local conexaoCamera: RBXScriptConnection? = nil
	if raizPersonagem and raizPersonagem:IsA("BasePart") then
		local base = raizPersonagem.CFrame
		local foco = base.Position + Vector3.new(0, 1.5, 0)
		local inicio = os.clock()
		camera.CameraType = Enum.CameraType.Scriptable
		conexaoCamera = RunService.RenderStepped:Connect(function()
			local t = os.clock() - inicio
			local pos: Vector3
			if t < Despertar.TENSAO then
				-- Aproxima de frente, de baixo para cima
				local f = math.clamp(t / Despertar.TENSAO, 0, 1)
				f = 1 - (1 - f) ^ 2
				pos = (base * CFrame.new(0, 0.8 - f * 1.6, -13 + f * 6)).Position
			elseif aura.tier >= Despertar.TIER_CEU and t > Despertar.EXPLOSAO then
				-- Mítico/Divino: volta de 360° em torno do personagem
				local g = math.clamp(
					(t - Despertar.EXPLOSAO) / (duracao - Despertar.EXPLOSAO - 0.4),
					0,
					1
				)
				local giro = CFrame.Angles(0, g * math.pi * 2, 0)
				pos = (base * giro * CFrame.new(0, 1, -9)).Position
			else
				pos = (base * CFrame.new(0, -0.8, -7)).Position
			end
			-- Tremor na explosão
			if t > Despertar.TENSAO and t < Despertar.EXPLOSAO then
				pos += Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.4
			end
			camera.CFrame = CFrame.lookAt(pos, foco + Vector3.new(0, 0.6, 0))
		end)
	end

	-- Tensão: tinta o mundo com a cor da escada de raridade
	task.delay(Despertar.CARGA, function()
		if token == meu then
			tween(correcao, Despertar.TENSAO - Despertar.CARGA, {
				TintColor = Color3.new(1, 1, 1):Lerp(cor, 0.5),
			})
		end
	end)
	-- Explosão: clarão de papel e contraste alto (silhueta de mangá)
	task.delay(Despertar.TENSAO, function()
		if token ~= meu then
			return
		end
		clarao.BackgroundTransparency = 0
		tween(clarao, 0.3, { BackgroundTransparency = 1 })
		correcao.Contrast, correcao.Saturation, correcao.Brightness = 1, -1, 0.1
		task.delay(0.15, function()
			if token == meu then
				tween(correcao, 0.3, { Contrast = 0.1, Saturation = 0, Brightness = 0 })
			end
		end)
	end)
	task.delay(Despertar.EXPLOSAO, function()
		if token == meu then
			mostrarTitulo(aura)
		end
	end)

	local encerrou = false
	local function fim()
		if encerrou then
			return
		end
		encerrou = true
		if token == meu then
			token += 1
		end
		Revelacao.fimEm = os.clock()
		if aoMudar then
			task.spawn(aoMudar, false)
		end
		if encerrar == fim then
			encerrar = nil
		end
		ativa = false
		if conexaoCamera then
			conexaoCamera:Disconnect()
		end
		camera.CameraType = Enum.CameraType.Custom
		if humanoide then
			camera.CameraSubject = humanoide
			humanoide.WalkSpeed, humanoide.JumpPower, humanoide.JumpHeight =
				velocidade, pulo, alturaPulo
		end
		correcao:Destroy()
		faixa.Visible = false
		selo.Visible = false
		clarao.BackgroundTransparency = 1
		tween(barraCima, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
		tween(barraBaixo, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
		task.delay(0.25, function()
			if not ativa then
				camada.Visible = false
			end
		end)
	end
	encerrar = fim
	task.delay(duracao, function()
		if token == meu then
			fim()
		end
	end)
	return true
end

return Revelacao
