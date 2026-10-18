-- Faixa grande quando a Chuva de Doces começa (sábado)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Evento = require(Shared.Dados.Evento)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Visual = require(UI.Visual)
local Estado = require(UI.Estado)

local Cores = Tema.Cores
local Chuva = {}

local DURACAO = 6
local DECORACAO = { "balaDeCoco", "pacoca", "quindim", "beijinho", "cocada" }

local quadro: Frame
local escala: UIScale
local relogio: TextLabel
local versao = 0

function Chuva.mostrar()
	versao += 1
	local minha = versao
	quadro.Visible = true
	escala.Scale = 0.4
	TweenService:Create(escala, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.spawn(function()
		while versao == minha and quadro.Visible do
			local ativo, falta = Evento.estado(Estado.agora())
			relogio.Text = Formato.tempo(if ativo then falta else Evento.Duracao)
			task.wait(0.5)
		end
	end)
	task.delay(DURACAO, function()
		if versao == minha then
			quadro.Visible = false
		end
	end)
end

function Chuva.montar(raiz: Frame)
	quadro = C.novo("Frame", {
		Name = "ChuvaDeDoces",
		BackgroundColor3 = Cores.Branco,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(560, 380),
		Visible = false,
		ZIndex = 46,
		Parent = raiz,
	})
	escala = C.novo("UIScale", { Parent = quadro })
	C.cantos(quadro, 30)
	C.contorno(quadro, 5)
	C.degrade(quadro, Color3.fromHex("FF9CCB"), Cores.Rosa)
	local posicoes = {
		UDim2.fromOffset(20, 20),
		UDim2.fromOffset(440, 30),
		UDim2.fromOffset(40, 270),
		UDim2.fromOffset(450, 260),
		UDim2.fromOffset(230, -10),
	}
	for i, id in DECORACAO do
		local vp = Visual.docinho(
			id,
			{ tamanho = UDim2.fromOffset(84, 84), posicao = posicoes[i], pai = quadro }
		)
		vp.Rotation = (i % 2 == 0) and 15 or -15
	end
	C.texto({
		Text = "CHUVA DE\nDOCES!",
		TextSize = 60,
		Size = UDim2.new(1, 0, 0, 140),
		Position = UDim2.fromOffset(0, 60),
		contorno = 4,
		Parent = quadro,
	})
	local pilulaRelogio = C.novo("Frame", {
		BackgroundColor3 = Cores.Contorno,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.fromOffset(180, 56),
		Parent = quadro,
	})
	C.cantosRedondos(pilulaRelogio)
	C.contorno(pilulaRelogio, 4, Cores.OuroClaro)
	relogio = C.texto({
		Text = "10:00",
		TextSize = 36,
		TextColor3 = Cores.OuroClaro,
		Size = UDim2.fromScale(1, 1),
		contorno = false,
		Parent = pilulaRelogio,
	})
	C.texto({
		Text = "Docinhos caem do céu. Corra e pegue de graça!",
		TextSize = 22,
		TextWrapped = true,
		Size = UDim2.new(1, -60, 0, 60),
		Position = UDim2.fromOffset(30, 280),
		Parent = quadro,
	})

	-- Mostra a faixa sozinha quando o evento começa
	task.spawn(function()
		local antes = Evento.estado(Estado.agora())
		while true do
			task.wait(1)
			local agora = Evento.estado(Estado.agora())
			if agora and not antes then
				Chuva.mostrar()
			end
			antes = agora
		end
	end)
end

return Chuva
