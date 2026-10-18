-- Comemoração quando um Docinho (ou variante) é descoberto
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Visual = require(UI.Visual)

local Cores = Tema.Cores
local NovoDocinho = {}

local camada: Frame
local raios: Frame
local raiosEscala: UIScale
local palco: Frame
local titulo: TextLabel
local nome: TextLabel
local etiquetaPai: Frame
local fila: { { id: string, variante: string } } = {}
local mostrando = false

local function proximo()
	local item = table.remove(fila, 1)
	if not item then
		mostrando = false
		camada.Visible = false
		return
	end
	mostrando = true
	local d = Catalogo.docinho(item.id)
	local r = Catalogo.raridadeDe(item.id)
	if not d or not r then
		proximo()
		return
	end
	for _, f in palco:GetChildren() do
		if f:IsA("ViewportFrame") then
			f:Destroy()
		end
	end
	for _, f in etiquetaPai:GetChildren() do
		if f:IsA("Frame") then
			f:Destroy()
		end
	end
	Visual.docinho(item.id, {
		variante = item.variante,
		girar = true,
		tamanho = UDim2.fromScale(0.82, 0.82),
		posicao = UDim2.fromScale(0.5, 0.5),
		ancora = Vector2.new(0.5, 0.5),
		pai = palco,
	})
	titulo.Text = if item.variante == "normal" then "NOVO DOCINHO!" else "NOVA VARIANTE!"
	local nomeVariante = if item.variante == "normal"
		then ""
		else " " .. Catalogo.Variantes[item.variante].nome
	nome.Text = d.nome .. nomeVariante
	local renda = Catalogo.rendaDe(item.id, item.variante)
	C.etiqueta(
		r.nome .. " · +" .. Formato.curto(renda) .. "/s",
		r.cor,
		20,
		{ Parent = etiquetaPai }
	)
	for _, cor in raios:GetChildren() do
		if cor:IsA("Frame") then
			cor.BackgroundColor3 = r.brilho
		end
	end
	camada.Visible = true
	raiosEscala.Scale = 0.3
	TweenService:Create(raiosEscala, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 })
		:Play()
end

function NovoDocinho.mostrar(id: string, variante: string?)
	table.insert(fila, { id = id, variante = variante or "normal" })
	if not mostrando then
		proximo()
	end
end

function NovoDocinho.montar(raiz: Frame)
	camada = C.novo("TextButton", {
		Name = "NovoDocinho",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
		Parent = raiz,
	})
	local centro = C.novo("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(520, 640),
		Parent = camada,
	})
	-- Raios girando atrás do Docinho
	raios = C.novo("Frame", {
		Name = "Raios",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(260, 200),
		Size = UDim2.fromOffset(460, 460),
		Parent = centro,
	})
	raiosEscala = C.novo("UIScale", { Parent = raios })
	for i = 0, 11 do
		local raio = C.novo("Frame", {
			BackgroundColor3 = Cores.Branco,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 34, 1, 0),
			Rotation = i * 15,
			Parent = raios,
		})
		C.cantos(raio, 17)
	end
	palco = C.novo("Frame", {
		Name = "Palco",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(260, 200),
		Size = UDim2.fromOffset(320, 320),
		Parent = centro,
	})
	titulo = C.texto({
		Text = "NOVO DOCINHO!",
		TextSize = 54,
		TextColor3 = Cores.OuroClaro,
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 380),
		contorno = 4,
		Parent = centro,
	})
	nome = C.texto({
		TextSize = 36,
		Size = UDim2.new(1, 0, 0, 42),
		Position = UDim2.fromOffset(0, 440),
		contorno = 3,
		Parent = centro,
	})
	etiquetaPai = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 490),
		Parent = centro,
	})
	C.lista(etiquetaPai, Enum.FillDirection.Horizontal, 0, Enum.HorizontalAlignment.Center)
	C.botao({
		cor = "verde",
		texto = "UHUU!",
		tamanho = UDim2.fromOffset(200, 64),
		posicao = UDim2.fromOffset(260, 545),
		ancora = Vector2.new(0.5, 0),
		pai = centro,
		aoClicar = proximo,
	})

	RunService.RenderStepped:Connect(function(dt)
		if camada.Visible then
			raios.Rotation = (raios.Rotation + dt * 18) % 360
		end
	end)

	Remotos.evento("NovoDocinho").OnClientEvent:Connect(function(dados: any)
		if type(dados) == "table" and type(dados.id) == "string" then
			NovoDocinho.mostrar(dados.id, dados.variante)
		end
	end)
end

return NovoDocinho
