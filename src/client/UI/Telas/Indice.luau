-- Coleção de auras, com as chances e raridades reais do catálogo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Perfil = require(Shared.Dados.Perfil)
local Cores = require(Shared.Tema).Orbita
local Escala = require(script.Parent.Parent.Escala)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Indice = {}

function Indice.montar(aoAviso: (string) -> ())
	local painel = Navegacao.criarPainel(
		"Indice",
		{ titulo = "Índice de Auras", icone = "◆", reserva = 110 }
	)
	local contador = Kit.texto({
		Name = "Descobertas",
		fonte = "mono",
		Text = "0 / " .. #Auras.lista,
		TextSize = 16,
		TextColor3 = Cores.Lilas,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -88, 0.5, -1),
		Size = UDim2.fromOffset(104, 26),
		Parent = painel.cabecalho,
	})
	local trilho = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Borda,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -88, 0.5, 16),
		Size = UDim2.fromOffset(90, 3),
		Parent = painel.cabecalho,
	})
	local progresso = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Lilas,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = trilho,
	})

	local rolagem = Kit.rolagem(painel.conteudo)
	local grade = Kit.novo("UIGridLayout", {
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rolagem,
	})

	local function ajustarGrade()
		local largura = math.max(1, math.floor(rolagem.AbsoluteSize.X / Escala.escala) - 18)
		local maximo = if Escala.compacto then 2 else 4
		local colunas = math.clamp(math.floor((largura + 12) / 232), 1, maximo)
		grade.FillDirectionMaxCells = colunas
		grade.CellSize = UDim2.fromOffset(math.floor((largura - (colunas - 1) * 12) / colunas), 190)
	end
	rolagem:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarGrade)
	Escala.aoMudar(ajustarGrade)

	type Cartao = {
		placa: Kit.Placa,
		botao: TextButton,
		nome: TextLabel,
		quantidade: TextLabel,
		situacao: TextLabel,
		gema: Frame,
		oculta: TextLabel,
		cor: Color3,
	}
	local cartoes: { [string]: Cartao } = {}
	for _, aura in Auras.lista do
		local tier = Auras.Tiers[aura.tier]
		local cor = Color3.fromHex(tier.cor)
		local placa = Kit.placa({
			nome = aura.id,
			tamanho = UDim2.fromOffset(226, 190),
			ordem = aura.ordem,
			pai = rolagem,
		})
		local conteudo = placa.conteudo
		Kit.texto({
			Text = string.upper(tier.nome),
			TextSize = 14,
			TextColor3 = Kit.corLegivel(cor),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 24),
			Parent = conteudo,
		})
		local cristal, gema = Kit.cristal(conteudo, 48, Cores.Borda)
		cristal.AnchorPoint = Vector2.new(0.5, 0)
		cristal.Position = UDim2.new(0.5, 0, 0, 30)
		local oculta = Kit.texto({
			fonte = "titulo",
			Text = "?",
			TextSize = 18,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = cristal,
		})
		local nome = Kit.texto({
			Name = "Nome",
			fonte = "titulo",
			Text = "???",
			TextSize = 22,
			TextWrapped = true,
			Position = UDim2.fromOffset(10, 80),
			Size = UDim2.new(1, -20, 0, 53),
			Parent = conteudo,
		})
		Kit.texto({
			Name = "Chance",
			fonte = "mono",
			Text = "1 em " .. Formato.chance(aura.chance),
			TextSize = 16,
			TextColor3 = Cores.TextoSuave,
			Position = UDim2.fromOffset(10, 131),
			Size = UDim2.new(1, -20, 0, 24),
			Parent = conteudo,
		})
		local quantidade = Kit.texto({
			Name = "Quantidade",
			fonte = "mono",
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 12, 1, -31),
			Size = UDim2.new(0.45, -10, 0, 25),
			Parent = conteudo,
		})
		local situacao = Kit.texto({
			Name = "Estado",
			fonte = "titulo",
			Text = "A descobrir",
			TextSize = 17,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 1, -31),
			Size = UDim2.new(0.55, -10, 0, 25),
			Parent = conteudo,
		})
		local botao = Kit.alvo(placa.quadro, "Aura a descobrir", function()
			local estado = Estado.atual
			if not estado then
				aoAviso("Aguardando perfil")
				return
			end
			if not Perfil.possui(estado, aura.id) then
				aoAviso("Desperte essa aura para poder equipá-la.")
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
			placa = placa,
			botao = botao,
			nome = nome,
			quantidade = quantidade,
			situacao = situacao,
			gema = gema,
			oculta = oculta,
			cor = cor,
		}
	end

	Estado.aoMudar(function(estado)
		local descobertas = Auras.contarDescobertas(estado.auras)
		contador.Text = string.format("%d / %d", descobertas, #Auras.lista)
		progresso.Size = UDim2.fromScale(descobertas / #Auras.lista, 1)
		for _, aura in Auras.lista do
			local c = cartoes[aura.id]
			local tem = Perfil.possui(estado, aura.id)
			local equipada = tem and estado.equipada == aura.id
			local cor = if tem then c.cor else Cores.Borda
			c.placa.definirCor(
				if tem then Cores.Painel:Lerp(c.cor, 0.09) else Cores.Painel,
				if equipada then Cores.Menta else cor
			)
			c.nome.Text = if tem then aura.nome else "???"
			c.quantidade.Text = if tem then "×" .. Formato.curto(estado.auras[aura.id]) else ""
			c.situacao.Text = if equipada then "Equipada" elseif tem then "Equipar" else "A descobrir"
			c.situacao.TextColor3 = if equipada
				then Cores.Menta
				elseif tem then Cores.Lilas
				else Cores.TextoSuave
			c.gema.BackgroundColor3 = cor
			c.oculta.Visible = not tem
			c.botao.Text = if tem
				then (if equipada then "Desequipar " else "Equipar ") .. aura.nome
				else "Aura a descobrir"
		end
	end)
end

function Indice.abrir()
	Navegacao.alternar("Indice")
end

return Indice
