-- Códigos promocionais (ver docs/design/09-popups.png)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = require(ReplicatedStorage.Shared.Tema)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)

local Cores = Tema.Cores
local Codigos = {}

function Codigos.montar()
	local painel =
		Navegacao.criarPainel("Codigos", { titulo = "Códigos", icone = "🎁", cor = "azul" })

	local caixa = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 360),
		Position = UDim2.new(0.5, 0, 0, 40),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = painel.conteudo,
	})
	C.textoEscuro({
		Text = "Digite um código para ganhar prêmios",
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = caixa,
	})
	local campo = C.novo("TextBox", {
		Text = "",
		PlaceholderText = "Digite o código",
		PlaceholderColor3 = Cores.Cinza,
		ClearTextOnFocus = false,
		Font = Tema.Fonte,
		TextSize = 28,
		TextColor3 = Cores.Contorno,
		BackgroundColor3 = Cores.Branco,
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 46),
		Parent = caixa,
	})
	C.cantos(campo, 16)
	C.contorno(campo)
	campo:GetPropertyChangedSignal("Text"):Connect(function()
		if #campo.Text > 30 then
			campo.Text = string.sub(campo.Text, 1, 30)
		end
	end)
	local resultado = C.cartaoClaro({
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 220),
		Visible = false,
		Parent = caixa,
	}, 14)
	local resultadoTexto =
		C.textoEscuro({ TextSize = 20, Size = UDim2.fromScale(1, 1), Parent = resultado })
	local enviando = false
	C.botao({
		cor = "verde",
		texto = "RESGATAR",
		tamanho = UDim2.new(1, 0, 0, 66),
		posicao = UDim2.fromOffset(0, 134),
		pai = caixa,
		aoClicar = function()
			if enviando or campo.Text == "" then
				return
			end
			enviando = true
			local ok, msg = Estado.pedir("ResgatarCodigo", campo.Text)
			enviando = false
			resultado.Visible = true
			resultado.BackgroundColor3 = if ok
				then Color3.fromHex("D7F8E8")
				else Color3.fromHex("FFE0E0")
			resultadoTexto.TextColor3 = if ok
				then Color3.fromHex("0F6B44")
				else Color3.fromHex("A0304F")
			resultadoTexto.Text = (if ok then "✅ " else "⚠️ ") .. (msg or "")
			if ok then
				campo.Text = ""
			end
		end,
	})
	C.textoEscuro({
		Text = "Novos códigos saem em cada atualização e marca de visitas.",
		TextSize = 17,
		TextColor3 = Cores.TextoSuave,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 300),
		Parent = caixa,
	})

	Navegacao.aoTrocar(function(nome)
		if nome == "Codigos" then
			resultado.Visible = false
		end
	end)
end

return Codigos
