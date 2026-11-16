-- Índice de auras: todas as auras do catálogo. Obtidas aparecem coloridas e podem ser equipadas;
-- as que faltam aparecem como "???" mostrando só a raridade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Perfil = require(Shared.Dados.Perfil)
local Tema = require(Shared.Tema)
local C = require(script.Parent.Parent.Componentes)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Estado = require(script.Parent.Parent.Estado)

local Cores = Tema.Cores
local Indice = {}

local SILHUETA = Color3.fromHex("3A2E52")

type Cartao = {
	botao: TextButton,
	degrade: UIGradient,
	contorno: UIStroke,
	nome: TextLabel,
	quantidade: TextLabel,
	selo: TextLabel,
}

function Indice.montar(aoAviso: (string) -> ())
	local painel = Navegacao.criarPainel(
		"Indice",
		{ titulo = "Índice de Auras", icone = "📖", cor = "roxo" }
	)
	local contador = C.texto({
		Name = "Contador",
		Text = "0/" .. #Auras.lista,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -90, 0.5, 0),
		Size = UDim2.fromOffset(200, 40),
		ZIndex = 3,
		Parent = painel.cabecalho,
	})

	local rolagem = C.novo("ScrollingFrame", {
		Name = "Lista",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Cores.UvaClaro,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = painel.conteudo,
	})
	C.padding(rolagem, 10)
	C.novo("UIGridLayout", {
		CellSize = UDim2.fromOffset(240, 150),
		CellPadding = UDim2.fromOffset(16, 16),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rolagem,
	})

	local cartoes: { [string]: Cartao } = {}
	for _, aura in Auras.lista do
		local botao = C.novo("TextButton", {
			Name = aura.id,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = Color3.new(1, 1, 1),
			LayoutOrder = aura.ordem,
			Parent = rolagem,
		})
		C.cantos(botao, 16)
		local contorno = C.contorno(botao, 3)
		local degrade = C.degrade(botao, SILHUETA, SILHUETA)
		C.padding(botao, 10, 8)
		local nome = C.texto({
			Name = "Nome",
			TextSize = 24,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 60),
			Parent = botao,
		})
		local tier = Auras.Tiers[aura.tier]
		C.texto({
			Name = "Chance",
			Text = string.format("%s\n1 em %s", tier.nome, Formato.inteiro(aura.chance)),
			TextSize = 18,
			TextColor3 = Color3.fromHex(tier.cor),
			Position = UDim2.fromOffset(0, 62),
			Size = UDim2.new(1, 0, 0, 44),
			Parent = botao,
		})
		local quantidade = C.texto({
			Name = "Quantidade",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(0.5, 0, 0, 22),
			Parent = botao,
		})
		local selo = C.texto({
			Name = "Equipada",
			Text = "EQUIPADA",
			TextSize = 16,
			TextColor3 = Cores.Ouro,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(0.5, 0, 0, 22),
			Visible = false,
			Parent = botao,
		})
		botao.Activated:Connect(function()
			local estado = Estado.atual
			if not estado or not Perfil.possui(estado, aura.id) then
				aoAviso("Desperte essa aura para poder equipá-la!")
				return
			end
			local alvo = if estado.equipada == aura.id then "" else aura.id
			task.spawn(function()
				local ok, msg = Estado.pedir("Equipar", alvo)
				if not ok and msg then
					aoAviso(msg)
				end
			end)
		end)
		cartoes[aura.id] = {
			botao = botao,
			degrade = degrade,
			contorno = contorno,
			nome = nome,
			quantidade = quantidade,
			selo = selo,
		}
	end

	Estado.aoMudar(function(estado)
		contador.Text = string.format("%d/%d", Auras.contarDescobertas(estado.auras), #Auras.lista)
		for _, aura in Auras.lista do
			local cartao = cartoes[aura.id]
			local tem = Perfil.possui(estado, aura.id)
			if tem then
				local c1, c2 = Color3.fromHex(aura.cores[1]), Color3.fromHex(aura.cores[2])
				cartao.degrade.Color =
					ColorSequence.new(c1:Lerp(SILHUETA, 0.55), c2:Lerp(SILHUETA, 0.35))
				cartao.nome.Text = aura.nome
				cartao.quantidade.Text = "x" .. Formato.curto(estado.auras[aura.id])
			else
				cartao.degrade.Color = ColorSequence.new(SILHUETA)
				cartao.nome.Text = "???"
				cartao.quantidade.Text = ""
			end
			local equipada = estado.equipada == aura.id
			cartao.selo.Visible = equipada
			cartao.contorno.Color = if equipada then Cores.Ouro else Cores.Contorno
			cartao.contorno.Thickness = if equipada then 5 else 3
		end
	end)
end

function Indice.abrir()
	Navegacao.alternar("Indice")
end

return Indice
