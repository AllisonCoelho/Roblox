-- Meus Docinhos: o que está na vitrine, o caixa e a venda
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local EsteiraDados = require(Shared.Dados.Esteira)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Visual = require(UI.Visual)
local Avisos = require(UI.Popups.Avisos)

local Cores = Tema.Cores
local MeusDocinhos = {}

function MeusDocinhos.montar()
	local painel = Navegacao.criarPainel(
		"MeusDocinhos",
		{ titulo = "Meus Docinhos", icone = "🍬", cor = "roxo" }
	)

	local capacidade = C.texto({
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.new(0, 340, 0.5, -15),
		Parent = painel.cabecalho,
	})

	-- Faixa do caixa
	local faixa = C.cartaoClaro({
		BackgroundColor3 = Cores.OuroClaro,
		Size = UDim2.new(1, -48, 0, 92),
		Position = UDim2.fromOffset(24, 18),
		Parent = painel.conteudo,
	}, 20)
	C.emoji(
		"🏪",
		46,
		{ Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = faixa }
	)
	local caixaTexto = C.textoEscuro({
		Font = Tema.Fonte,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, 0, 0, 34),
		Position = UDim2.fromOffset(86, 14),
		Parent = faixa,
	})
	local rendaTexto = C.textoEscuro({
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.5, 0, 0, 24),
		Position = UDim2.fromOffset(86, 52),
		Parent = faixa,
	})
	C.botao({
		cor = "verde",
		icone = "🪙",
		texto = "COLETAR",
		tamanho = UDim2.fromOffset(240, 60),
		posicao = UDim2.new(1, -18, 0.5, -3),
		ancora = Vector2.new(1, 0.5),
		pai = faixa,
		aoClicar = function()
			local ok, msg = Estado.pedir("Coletar")
			Avisos.resultado(ok, msg or (if ok then "Moedas coletadas!" else nil))
		end,
	})

	local grade = C.novo("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 1, -130),
		Position = UDim2.fromOffset(12, 124),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Cores.Contorno,
		Parent = painel.conteudo,
	})
	C.padding(grade, 14, 14)
	C.novo("UIGridLayout", {
		CellSize = UDim2.fromOffset(196, 262),
		CellPadding = UDim2.fromOffset(16, 22),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grade,
	})

	-- Vender pede confirmação (segundo toque em 3 s), para ninguém vender um raro sem querer
	local confirmando: number? = nil

	local function desenhar()
		for _, f in grade:GetChildren() do
			if f:IsA("Frame") then
				f:Destroy()
			end
		end
		local estado = Estado.atual
		if not estado then
			return
		end
		local cap = Economia.capacidadeVitrine(estado)
		capacidade.Text = #estado.vitrine .. " / " .. cap .. " espaços"
		for i = 1, cap do
			local item = estado.vitrine[i]
			local celula = C.cartaoClaro({ LayoutOrder = i, Parent = grade }, 20)
			if not item then
				celula.BackgroundColor3 = Color3.fromHex("F3EDF8")
				local s = celula:FindFirstChildOfClass("UIStroke") :: UIStroke
				s.Transparency = 0.6
				C.texto({
					Text = "+",
					TextSize = 64,
					TextColor3 = Cores.CinzaClaro,
					contorno = false,
					Size = UDim2.new(1, 0, 0, 150),
					Parent = celula,
				})
				C.textoEscuro({
					Text = "Compre na esteira",
					TextSize = 16,
					TextColor3 = Cores.Cinza,
					Size = UDim2.new(1, 0, 0, 24),
					Position = UDim2.fromOffset(0, 150),
					Parent = celula,
				})
				continue
			end
			local d = Catalogo.docinho(item.id)
			local r = Catalogo.raridadeDe(item.id)
			if not d or not r then
				continue
			end
			local foto = C.novo("Frame", {
				BackgroundColor3 = Cores.Branco,
				Size = UDim2.new(1, -20, 0, 120),
				Position = UDim2.fromOffset(10, 10),
				Parent = celula,
			})
			C.cantos(foto, 14)
			C.degrade(foto, r.brilho, r.cor)
			Visual.docinho(
				item.id,
				{ variante = item.variante, tamanho = UDim2.fromScale(1, 1), pai = foto }
			)
			local variante = Catalogo.Variantes[item.variante]
			C.textoEscuro({
				Text = d.nome
					.. (if variante and variante.id ~= "normal" then " " .. variante.nome else ""),
				Font = Tema.Fonte,
				TextSize = 16,
				TextWrapped = true,
				Size = UDim2.new(1, -12, 0, 38),
				Position = UDim2.fromOffset(6, 132),
				Parent = celula,
			})
			C.textoEscuro({
				Text = "🪙 +" .. Formato.curto(Catalogo.rendaDe(item.id, item.variante)) .. "/s",
				TextSize = 16,
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.fromOffset(0, 170),
				Parent = celula,
			})
			local valor = EsteiraDados.valorVenda(item.id, item.variante)
			local vender
			vender = C.botao({
				cor = if confirmando == i then "vermelho" else "cinza",
				texto = if confirmando == i then "CERTEZA?" else "Vender " .. Formato.curto(valor),
				tamanho = UDim2.new(1, -20, 0, 44),
				posicao = UDim2.new(0, 10, 1, -56),
				tamanhoTexto = 18,
				sombra = 4,
				pai = celula,
				aoClicar = function()
					if confirmando == i then
						confirmando = nil
						Avisos.resultado(Estado.pedir("VenderDocinho", i, item.id, item.variante))
					else
						confirmando = i
						vender.definirCor("vermelho")
						vender.definirTexto("CERTEZA?")
						task.delay(3, function()
							if confirmando == i then
								confirmando = nil
								desenhar()
							end
						end)
					end
				end,
			})
		end
	end

	local function atualizarCaixa()
		local estado = Estado.atual
		caixaTexto.Text = "Caixa: 🪙 " .. Formato.inteiro(Estado.caixa())
		if estado then
			rendaTexto.Text = "Sua vitrine rende 🪙 "
				.. Formato.curto(Economia.rendaPorSegundo(estado, Estado.agora()))
				.. " por segundo"
		end
	end
	Players.LocalPlayer:GetAttributeChangedSignal("Caixa"):Connect(atualizarCaixa)

	Estado.aoMudar(function()
		if Navegacao.aberto() == "MeusDocinhos" then
			confirmando = nil
			desenhar()
			atualizarCaixa()
		end
	end)
	Navegacao.aoTrocar(function(nome)
		if nome == "MeusDocinhos" then
			confirmando = nil
			desenhar()
			atualizarCaixa()
		end
	end)
end

return MeusDocinhos
