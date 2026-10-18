-- Ajustes: modo celular, códigos, tutorial e versão
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Config = require(Shared.Config)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Escala = require(UI.Escala)
local Navegacao = require(UI.Navegacao)
local Tutorial = require(UI.Popups.Tutorial)

local Cores = Tema.Cores
local Ajustes = {}

local MODOS = {
	{ id = "auto", texto = "Automático" },
	{ id = "sim", texto = "Celular" },
	{ id = "nao", texto = "Computador" },
}

function Ajustes.montar()
	local painel =
		Navegacao.criarPainel("Ajustes", { titulo = "Ajustes", icone = "⚙️", cor = "ardosia" })

	local coluna = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(620, 520),
		Position = UDim2.new(0.5, 0, 0, 30),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = painel.conteudo,
	})
	C.lista(coluna, Enum.FillDirection.Vertical, 18, Enum.HorizontalAlignment.Center)

	C.textoEscuro({
		Text = "Tamanho da tela",
		Font = Tema.Fonte,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 1,
		Parent = coluna,
	})
	local linhaModos = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 70),
		LayoutOrder = 2,
		Parent = coluna,
	})
	C.lista(linhaModos, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	local botoes = {}
	local function pintar()
		for id, b in botoes do
			b.definirCor(if Escala.modoCompacto == id then "roxo" else "cinza")
		end
	end
	for i, modo in MODOS do
		botoes[modo.id] = C.botao({
			cor = "cinza",
			texto = modo.texto,
			tamanho = UDim2.fromOffset(196, 60),
			tamanhoTexto = 22,
			ordem = i,
			pai = linhaModos,
			aoClicar = function()
				Escala.definirModo(modo.id)
				pintar()
			end,
		})
	end
	pintar()

	C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1, 10),
		LayoutOrder = 3,
		Parent = coluna,
	})
	C.botao({
		cor = "azul",
		icone = "🎁",
		texto = "CÓDIGOS",
		tamanho = UDim2.fromOffset(420, 64),
		ordem = 4,
		pai = coluna,
		aoClicar = function()
			Navegacao.abrir("Codigos")
		end,
	})
	C.botao({
		cor = "laranja",
		icone = "📖",
		texto = "VER TUTORIAL",
		tamanho = UDim2.fromOffset(420, 64),
		ordem = 5,
		pai = coluna,
		aoClicar = function()
			Navegacao.fechar()
			Tutorial.mostrar()
		end,
	})
	C.textoEscuro({
		Text = string.format("%s · versão %s", Config.Title, Config.Version),
		TextSize = 18,
		TextColor3 = Cores.TextoSuave,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 6,
		Parent = coluna,
	})
end

return Ajustes
