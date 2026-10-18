-- Missões diárias
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local MissoesDados = require(Shared.Dados.Missoes)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Avisos = require(UI.Popups.Avisos)

local Cores = Tema.Cores
local Missoes = {}

function Missoes.montar()
	local painel = Navegacao.criarPainel(
		"Missoes",
		{ titulo = "Missões do Dia", icone = "📜", cor = "laranja" }
	)

	local lista = C.novo("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -48, 1, -80),
		Position = UDim2.fromOffset(24, 18),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Cores.Contorno,
		Parent = painel.conteudo,
	})
	C.padding(lista, 6, 6)
	C.lista(lista, Enum.FillDirection.Vertical, 18)
	local rodape = C.textoEscuro({
		TextSize = 20,
		TextColor3 = Cores.TextoSuave,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -54),
		Parent = painel.conteudo,
	})

	local function desenhar()
		for _, f in lista:GetChildren() do
			if f:IsA("Frame") then
				f:Destroy()
			end
		end
		local estado = Estado.atual
		if not estado then
			return
		end
		for i, m in estado.missoes.lista do
			local def = MissoesDados.missao(m.id)
			if not def then
				continue
			end
			local pronta = m.progresso >= def.meta
			local linha = C.cartaoClaro(
				{ Size = UDim2.new(1, 0, 0, 130), LayoutOrder = i, Parent = lista },
				22
			)
			if m.resgatada then
				linha.BackgroundColor3 = Color3.fromHex("D7F8E8")
			end
			C.emoji(if m.resgatada then "✅" elseif pronta then "🎉" else "📜", 48, {
				Position = UDim2.new(0, 18, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Parent = linha,
			})
			C.textoEscuro({
				Text = def.texto,
				Font = Tema.Fonte,
				TextSize = 26,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -420, 0, 32),
				Position = UDim2.fromOffset(100, 18),
				Parent = linha,
			})
			local barra = C.barra({
				tamanho = UDim2.new(1, -420, 0, 30),
				posicao = UDim2.fromOffset(100, 58),
				tamanhoTexto = 18,
				pai = linha,
			})
			barra.definir(
				m.progresso / def.meta,
				Formato.curto(m.progresso) .. " / " .. Formato.curto(def.meta)
			)
			C.textoEscuro({
				Text = "Prêmio: ✨ " .. def.granulados .. " granulados",
				TextSize = 17,
				TextColor3 = Cores.TextoSuave,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, -420, 0, 22),
				Position = UDim2.fromOffset(100, 96),
				Parent = linha,
			})
			if m.resgatada then
				C.textoEscuro({
					Text = "FEITO ✓",
					Font = Tema.Fonte,
					TextSize = 26,
					TextColor3 = Cores.MentaEscuro,
					Size = UDim2.fromOffset(260, 60),
					Position = UDim2.new(1, -20, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Parent = linha,
				})
			else
				C.botao({
					cor = if pronta then "verde" else "cinza",
					icone = "✨",
					texto = if pronta then "PEGAR" else "EM ANDAMENTO",
					tamanho = UDim2.fromOffset(270, 60),
					tamanhoTexto = if pronta then 26 else 20,
					posicao = UDim2.new(1, -20, 0.5, -3),
					ancora = Vector2.new(1, 0.5),
					pai = linha,
					aoClicar = function()
						if pronta then
							Avisos.resultado(Estado.pedir("ResgatarMissao", m.id))
						else
							Avisos.mostrar("info", "Continue jogando para completar!")
						end
					end,
				})
			end
		end
	end

	local function atualizarRodape()
		-- Missões trocam à meia-noite de Brasília (UTC-3)
		local agora = Estado.agora()
		local faltam = 86400 - ((agora - 3 * 3600) % 86400)
		rodape.Text = "Novas missões em " .. Formato.tempo(faltam)
	end

	Estado.aoMudar(function()
		if Navegacao.aberto() == "Missoes" then
			desenhar()
		end
	end)
	Navegacao.aoTrocar(function(nome)
		if nome == "Missoes" then
			desenhar()
			task.spawn(function()
				while Navegacao.aberto() == "Missoes" do
					atualizarRodape()
					task.wait(1)
				end
			end)
		end
	end)
end

return Missoes
