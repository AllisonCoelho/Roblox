-- Alerta: alguém está levando um Docinho da sua vitrine
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Remotos = require(Shared.Remotos)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Visual = require(UI.Visual)
local Estado = require(UI.Estado)
local Avisos = require(script.Parent.Avisos)

local Cores = Tema.Cores
local Resgate = {}

local DURACAO = 8

local quadro: Frame
local fotoPai: Frame
local texto: TextLabel
local versao = 0
local irParaVitrine: () -> () = function() end

function Resgate.mostrar(id: string)
	local d = Catalogo.docinho(id)
	local r = Catalogo.raridadeDe(id)
	if not d or not r then
		return
	end
	versao += 1
	local minha = versao
	for _, f in fotoPai:GetChildren() do
		if f:IsA("ViewportFrame") then
			f:Destroy()
		end
	end
	fotoPai.BackgroundColor3 = r.cor
	Visual.docinho(id, { tamanho = UDim2.fromScale(1, 1), pai = fotoPai })
	texto.Text = string.format(
		"O <b>%s</b> está sendo levado! Toque em quem está carregando para trazer de volta.",
		d.nome
	)
	quadro.Visible = true
	task.delay(DURACAO, function()
		if versao == minha then
			quadro.Visible = false
		end
	end)
end

function Resgate.montar(raiz: Frame, irVitrine: () -> ())
	irParaVitrine = irVitrine
	quadro = C.novo("Frame", {
		Name = "Resgate",
		BackgroundColor3 = Cores.Creme,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(440, 300),
		Visible = false,
		ZIndex = 45,
		Parent = raiz,
	})
	C.cantos(quadro, 26)
	C.contorno(quadro, 5)
	local cab = C.novo("Frame", {
		BackgroundColor3 = Cores.Branco,
		Size = UDim2.new(1, 0, 0, 64),
		ZIndex = 2,
		Parent = quadro,
	})
	C.cantos(cab, 22)
	C.degrade(cab, Cores.VermelhoClaro, Cores.Vermelho)
	-- Complemento reto embaixo do cabeçalho (os cantos arredondados são só em cima)
	local reto = C.novo("Frame", {
		BackgroundColor3 = Cores.Branco,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 38),
		ZIndex = 1,
		Parent = quadro,
	})
	C.degrade(reto, Cores.VermelhoClaro:Lerp(Cores.Vermelho, 38 / 64), Cores.Vermelho)
	C.emoji(
		"🚨",
		32,
		{ Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = cab }
	)
	C.texto({
		Text = "Resgate!",
		TextSize = 30,
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(64, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cab,
	})
	fotoPai = C.novo("Frame", {
		BackgroundColor3 = Cores.Uva,
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.fromOffset(18, 80),
		Parent = quadro,
	})
	C.cantos(fotoPai, 16)
	C.contorno(fotoPai)
	texto = C.textoEscuro({
		TextSize = 20,
		RichText = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -160, 0, 110),
		Position = UDim2.fromOffset(142, 80),
		Parent = quadro,
	})
	C.botao({
		cor = "azul",
		icone = "🛡️",
		texto = "ESCUDO",
		tamanho = UDim2.new(0.5, -27, 0, 60),
		posicao = UDim2.new(0, 18, 1, -82),
		tamanhoTexto = 26,
		pai = quadro,
		aoClicar = function()
			Avisos.resultado(Estado.pedir("LigarEscudo"))
			quadro.Visible = false
		end,
	})
	C.botao({
		cor = "verde",
		icone = "🏠",
		texto = "IR",
		tamanho = UDim2.new(0.5, -27, 0, 60),
		posicao = UDim2.new(0.5, 9, 1, -82),
		tamanhoTexto = 26,
		pai = quadro,
		aoClicar = function()
			irParaVitrine()
			quadro.Visible = false
		end,
	})

	Remotos.evento("Resgate").OnClientEvent:Connect(function(dados: any)
		if type(dados) == "table" and type(dados.id) == "string" then
			Resgate.mostrar(dados.id)
		end
	end)
end

return Resgate
