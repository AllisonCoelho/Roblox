-- Tutorial do primeiro acesso: 4 passos curtos, com ícones grandes (funciona sem chat)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tema = require(ReplicatedStorage.Shared.Tema)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)

local Cores = Tema.Cores
local Tutorial = {}

local PASSOS = {
	{ icones = { "🍬", "👆" }, texto = "Toque num Docinho na esteira para comprar" },
	{ icones = { "🍬", "➡️", "🏠" }, texto = "Leve até a sua vitrine" },
	{ icones = { "🏪", "🪙" }, texto = "A vitrine gera moedas. Pise no caixa para coletar!" },
	{ icones = { "🛡️" }, texto = "Ligue o escudo para proteger seus Docinhos" },
}

local quadro: Frame
local escala: UIScale
local linhaIcones: Frame
local texto: TextLabel
local pontos: { Frame } = {}
local proximoBotao: any
local passo = 1
local pedido = false

local function desenhar()
	for _, f in linhaIcones:GetChildren() do
		if f:IsA("TextLabel") then
			f:Destroy()
		end
	end
	local p = PASSOS[passo]
	for i, icone in p.icones do
		C.emoji(icone, 44, { LayoutOrder = i, Parent = linhaIcones })
	end
	texto.Text = p.texto
	for i, ponto in pontos do
		ponto.Size = if i == passo then UDim2.fromOffset(36, 16) else UDim2.fromOffset(16, 16)
		ponto.BackgroundColor3 = if i == passo then Cores.Ouro else Cores.CinzaClaro
	end
	proximoBotao.definirTexto(if passo == #PASSOS then "BORA!" else "PRÓXIMO")
	escala.Scale = 0.9
	TweenService:Create(escala, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function concluir()
	quadro.Visible = false
	task.spawn(Estado.pedir, "ConcluirTutorial")
end

function Tutorial.mostrar()
	passo = 1
	quadro.Visible = true
	desenhar()
end

function Tutorial.montar(raiz: Frame)
	quadro = C.novo("Frame", {
		Name = "Tutorial",
		BackgroundColor3 = Cores.Branco,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(620, 250),
		Visible = false,
		ZIndex = 44,
		Parent = raiz,
	})
	escala = C.novo("UIScale", { Parent = quadro })
	C.cantos(quadro, 24)
	C.contorno(quadro, 5)
	linhaIcones = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.fromOffset(0, 14),
		Parent = quadro,
	})
	C.lista(
		linhaIcones,
		Enum.FillDirection.Horizontal,
		10,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	texto = C.textoEscuro({
		Font = Tema.Fonte,
		TextSize = 28,
		TextWrapped = true,
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 80),
		Parent = quadro,
	})
	local linhaPontos = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 0, 20),
		Position = UDim2.new(0, 24, 1, -48),
		Parent = quadro,
	})
	C.lista(
		linhaPontos,
		Enum.FillDirection.Horizontal,
		8,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	for i = 1, #PASSOS do
		local ponto = C.novo("Frame", {
			BackgroundColor3 = Cores.CinzaClaro,
			Size = UDim2.fromOffset(16, 16),
			LayoutOrder = i,
			Parent = linhaPontos,
		})
		C.cantosRedondos(ponto)
		C.contorno(ponto, 3)
		table.insert(pontos, ponto)
	end
	C.botao({
		cor = "cinza",
		texto = "PULAR",
		tamanho = UDim2.fromOffset(130, 52),
		tamanhoTexto = 22,
		posicao = UDim2.new(1, -196, 1, -70),
		ancora = Vector2.new(1, 0),
		sombra = 4,
		pai = quadro,
		aoClicar = concluir,
	})
	proximoBotao = C.botao({
		cor = "verde",
		texto = "PRÓXIMO",
		tamanho = UDim2.fromOffset(170, 52),
		tamanhoTexto = 22,
		posicao = UDim2.new(1, -18, 1, -70),
		ancora = Vector2.new(1, 0),
		sombra = 4,
		pai = quadro,
		aoClicar = function()
			if passo >= #PASSOS then
				concluir()
			else
				passo += 1
				desenhar()
			end
		end,
	})

	-- Primeiro acesso: abre sozinho uma vez
	Estado.aoMudar(function(estado)
		if not pedido and not estado.tutorialFeito then
			pedido = true
			Tutorial.mostrar()
		end
	end)
end

return Tutorial
