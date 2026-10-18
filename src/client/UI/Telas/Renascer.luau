-- Painel do Renascer: troca moedas e melhorias por renda extra para sempre
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Economia = require(Shared.Dados.Economia)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Avisos = require(UI.Popups.Avisos)

local Cores = Tema.Cores
local Renascer = {}

local function porcento(mult: number): string
	return "+" .. math.floor((mult - 1) * 100 + 0.5) .. "%"
end

function Renascer.montar()
	local painel =
		Navegacao.criarPainel("Renascer", { titulo = "Renascer", icone = "✨", cor = "roxo" })

	local coluna = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 1, -30),
		Position = UDim2.fromOffset(30, 20),
		Parent = painel.conteudo,
	})

	-- Linha de cima: bônus agora -> bônus depois
	local topo = C.cartaoClaro(
		{ Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = Cores.Lilas, Parent = coluna },
		22
	)
	local agoraTexto = C.textoEscuro({
		Font = Tema.Fonte,
		TextSize = 54,
		Size = UDim2.new(0.4, 0, 0, 64),
		Position = UDim2.new(0, 0, 0, 22),
		Parent = topo,
	})
	C.textoEscuro({
		Text = "renda agora",
		TextSize = 20,
		TextColor3 = Cores.TextoSuave,
		Size = UDim2.new(0.4, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 92),
		Parent = topo,
	})
	C.texto({
		Text = "➜",
		TextSize = 60,
		TextColor3 = Cores.Uva,
		contorno = false,
		Size = UDim2.new(0.2, 0, 0, 64),
		Position = UDim2.new(0.4, 0, 0, 22),
		Parent = topo,
	})
	local depoisTexto = C.textoEscuro({
		Font = Tema.Fonte,
		TextSize = 54,
		TextColor3 = Cores.Uva,
		Size = UDim2.new(0.4, 0, 0, 64),
		Position = UDim2.new(0.6, 0, 0, 22),
		Parent = topo,
	})
	C.textoEscuro({
		Text = "renda para sempre",
		TextSize = 20,
		TextColor3 = Cores.TextoSuave,
		Size = UDim2.new(0.4, 0, 0, 26),
		Position = UDim2.new(0.6, 0, 0, 92),
		Parent = topo,
	})

	-- Quanto falta
	local barra = C.barra({
		tamanho = UDim2.new(1, 0, 0, 40),
		posicao = UDim2.fromOffset(0, 172),
		cores = { Cores.UvaClaro, Cores.Uva },
		tamanhoTexto = 20,
		pai = coluna,
	})

	-- O que perde e o que fica
	local function caixaLista(titulo: string, itens: string, cor: Color3, x: number)
		local f = C.cartaoClaro({
			Size = UDim2.new(0.5, -10, 0, 170),
			Position = UDim2.new(x, if x > 0 then 10 else 0, 0, 232),
			BackgroundColor3 = cor,
			Parent = coluna,
		}, 18)
		C.textoEscuro({
			Text = titulo,
			Font = Tema.Fonte,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -32, 0, 30),
			Position = UDim2.fromOffset(16, 12),
			Parent = f,
		})
		C.textoEscuro({
			Text = itens,
			TextSize = 19,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -32, 1, -56),
			Position = UDim2.fromOffset(16, 48),
			Parent = f,
		})
	end
	caixaLista(
		"😮 Você perde",
		"• Moedas e caixa\n• Melhorias (escudo, tênis, caixa)",
		Color3.fromHex("FFE0E0"),
		0
	)
	caixaLista(
		"😊 Você mantém",
		"• Todos os seus Docinhos\n• Álbum, granulados e passes\n• O tamanho da vitrine",
		Color3.fromHex("D7F8E8"),
		0.5
	)

	local premio = C.textoEscuro({
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 418),
		Parent = coluna,
	})

	local confirmando = false
	local botao
	botao = C.botao({
		cor = "roxo",
		icone = "✨",
		texto = "RENASCER",
		tamanho = UDim2.fromOffset(360, 72),
		tamanhoTexto = 32,
		posicao = UDim2.new(0.5, 0, 0, 458),
		ancora = Vector2.new(0.5, 0),
		pai = coluna,
		aoClicar = function()
			-- Dois toques: renascer não tem volta
			if not confirmando then
				confirmando = true
				botao.definirCor("vermelho")
				botao.definirTexto("TEM CERTEZA?")
				task.delay(3, function()
					if confirmando then
						confirmando = false
						botao.definirCor("roxo")
						botao.definirTexto("RENASCER")
					end
				end)
				return
			end
			confirmando = false
			botao.definirCor("roxo")
			botao.definirTexto("RENASCER")
			local ok, msg = Estado.pedir("Renascer")
			Avisos.resultado(ok, msg)
			if ok then
				Navegacao.fechar()
			end
		end,
	})

	local function desenhar()
		local estado = Estado.atual
		if not estado then
			return
		end
		local feitos = estado.renascimentos or 0
		local custo = Economia.custoRenascer(feitos)
		agoraTexto.Text = porcento(Economia.multiplicadorRenascer(feitos))
		depoisTexto.Text = porcento(Economia.multiplicadorRenascer(feitos + 1))
		barra.definir(
			estado.moedas / custo,
			"🪙 " .. Formato.curto(estado.moedas) .. " / " .. Formato.curto(custo)
		)
		premio.Text = string.format(
			"Você já renasceu %d %s · prêmio deste: ✨ %d granulados",
			feitos,
			if feitos == 1 then "vez" else "vezes",
			Economia.RenascerGranulados * (feitos + 1)
		)
	end

	Estado.aoMudar(function()
		if Navegacao.aberto() == "Renascer" then
			desenhar()
		end
	end)
	Navegacao.aoTrocar(function(nome)
		if nome == "Renascer" then
			confirmando = false
			desenhar()
		end
	end)
end

return Renascer
