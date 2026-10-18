-- Painel da Loja (ver docs/design/08-loja.png)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local LojaDados = require(Shared.Dados.Loja)
local Economia = require(Shared.Dados.Economia)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Avisos = require(UI.Popups.Avisos)

local Cores = Tema.Cores
local Loja = {}

local ABAS = {
	{ id = "melhorias", texto = "Melhorias", icone = "⬆️", cor = "laranja" },
	{ id = "boosts", texto = "Boosts", icone = "⚡", cor = "roxo" },
	{ id = "granulados", texto = "Granulados", icone = "✨", cor = "rosa" },
	{ id = "passes", texto = "Passes", icone = "⭐", cor = "ouro" },
}

-- Aba pedida por outro lugar (ex.: o "+" dos granulados no HUD) antes de abrir a Loja
local abaPedida: string? = nil

function Loja.irPara(aba: string)
	abaPedida = aba
	Navegacao.abrir("Loja")
end

function Loja.montar()
	local painel = Navegacao.criarPainel("Loja", { titulo = "Loja", icone = "🛒", cor = "rosa" })

	-- Carteira no cabeçalho
	local carteira = C.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 50),
		Position = UDim2.new(0, 190, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = painel.cabecalho,
	})
	C.lista(
		carteira,
		Enum.FillDirection.Horizontal,
		22,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	local pMoedas = C.pilula({
		icone = "🪙",
		corIcone = C.CorIconeMoeda,
		largura = 190,
		altura = 46,
		ordem = 1,
		pai = carteira,
	})
	local pGran = C.pilula({
		icone = "✨",
		corIcone = C.CorIconeGranulado,
		largura = 150,
		altura = 46,
		ordem = 2,
		pai = carteira,
	})

	-- Abas à esquerda
	local lateral = C.novo("Frame", {
		Name = "Abas",
		BackgroundColor3 = Cores.Lilas,
		Size = UDim2.new(0, 230, 1, 0),
		Parent = painel.conteudo,
	})
	C.novo("Frame", {
		BackgroundColor3 = Cores.Contorno,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 5, 1, 0),
		Position = UDim2.new(1, -5, 0, 0),
		Parent = lateral,
	})
	C.padding(lateral, 16, 20)
	C.lista(lateral, Enum.FillDirection.Vertical, 14)

	local area = C.novo("ScrollingFrame", {
		Name = "Itens",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -230, 1, 0),
		Position = UDim2.fromOffset(230, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Cores.Contorno,
		Parent = painel.conteudo,
	})
	C.padding(area, 22, 22)
	C.novo("UIGridLayout", {
		CellSize = UDim2.fromOffset(340, 220),
		CellPadding = UDim2.fromOffset(20, 26),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = area,
	})

	local abaAtual = "melhorias"
	local botoesAba: { [string]: any } = {}
	local desenhar: () -> ()

	for i, aba in ABAS do
		botoesAba[aba.id] = C.botao({
			cor = aba.cor,
			icone = aba.icone,
			texto = aba.texto,
			tamanho = UDim2.new(1, 0, 0, 60),
			tamanhoTexto = 22,
			ordem = i,
			sombra = 4,
			pai = lateral,
			aoClicar = function()
				abaAtual = aba.id
				desenhar()
			end,
		})
	end

	local function cartao(
		ordem: number,
		icone: string,
		cor: string,
		nome: string,
		descricao: string
	): Frame
		local f = C.cartaoClaro({ LayoutOrder = ordem, Parent = area }, 22)
		local caixaIcone = C.novo("Frame", {
			BackgroundColor3 = Cores.Branco,
			Size = UDim2.fromOffset(86, 86),
			Position = UDim2.fromOffset(14, 14),
			Parent = f,
		})
		C.cantos(caixaIcone, 18)
		C.contorno(caixaIcone)
		local par = Tema.Botoes[cor] or Tema.Botoes.rosa
		C.degrade(caixaIcone, par[1], par[2])
		C.emoji(icone, 44, { Size = UDim2.fromScale(1, 1), Parent = caixaIcone })
		C.textoEscuro({
			Text = nome,
			Font = Tema.Fonte,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, -128, 0, 28),
			Position = UDim2.fromOffset(114, 16),
			Parent = f,
		})
		C.textoEscuro({
			Text = descricao,
			TextSize = 16,
			TextColor3 = Color3.fromHex("5A4A6C"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Size = UDim2.new(1, -128, 0, 50),
			Position = UDim2.fromOffset(114, 46),
			Parent = f,
		})
		return f
	end

	local function niveis(f: Frame, atual: number, maximo: number)
		local linha = C.novo("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -28, 0, 14),
			Position = UDim2.fromOffset(14, 114),
			Parent = f,
		})
		C.novo("UIGridLayout", {
			CellSize = UDim2.new(1 / maximo, -6, 1, 0),
			CellPadding = UDim2.fromOffset(6, 0),
			Parent = linha,
		})
		for i = 1, maximo do
			local seg = C.novo("Frame", {
				BackgroundColor3 = if i <= atual then Cores.Laranja else Color3.fromHex("E9E1F2"),
				Parent = linha,
			})
			C.cantos(seg, 6)
			C.contorno(seg, 2)
		end
	end

	local function botaoCompra(f: Frame, cor: string, icone: string?, texto: string, fn: () -> ())
		C.botao({
			cor = cor,
			icone = icone,
			texto = texto,
			tamanho = UDim2.new(1, -28, 0, 54),
			posicao = UDim2.new(0, 14, 1, -72),
			tamanhoTexto = 22,
			pai = f,
			aoClicar = fn,
		})
	end

	local function pedir(acao: string, id: string)
		Avisos.resultado(Estado.pedir(acao, id))
	end

	desenhar = function()
		for _, f in area:GetChildren() do
			if f:IsA("Frame") then
				f:Destroy()
			end
		end
		for id, b in botoesAba do
			b.quadro.Size = if id == abaAtual
				then UDim2.new(1, 0, 0, 60)
				else UDim2.new(1, -16, 0, 60)
		end
		local estado = Estado.atual
		if not estado then
			return
		end
		pMoedas.valor.Text = Formato.curto(estado.moedas)
		pGran.valor.Text = Formato.inteiro(estado.granulados)
		local agora = Estado.agora()

		if abaAtual == "melhorias" then
			for i, m in LojaDados.Melhorias do
				local nivel = Economia.nivel(estado, m.id)
				local f = cartao(i, m.icone, m.cor, m.nome, m.descricao)
				niveis(f, nivel, #m.custos)
				local custo = LojaDados.proximoCusto(m.id, nivel)
				if custo then
					local cor = if estado.moedas >= custo then "laranja" else "cinza"
					botaoCompra(f, cor, "🪙", Formato.curto(custo), function()
						pedir("ComprarMelhoria", m.id)
					end)
				else
					botaoCompra(f, "verde", nil, "MÁXIMO", function() end)
				end
			end
		elseif abaAtual == "boosts" then
			for i, b in LojaDados.Boosts do
				local f = cartao(i, b.icone, b.cor, b.nome, b.descricao)
				if b.popular then
					local tag = C.etiqueta("POPULAR", Cores.Vermelho, 15, {
						Position = UDim2.new(1, -14, 0, -12),
						AnchorPoint = Vector2.new(1, 0),
						ZIndex = 3,
					})
					tag.Parent = f
				end
				local fim = estado.boosts[b.id] or 0
				if fim > agora then
					C.texto({
						Text = "ativo · " .. Formato.tempo(fim - agora),
						TextSize = 18,
						TextColor3 = Cores.MentaEscuro,
						contorno = false,
						Size = UDim2.new(1, -28, 0, 22),
						Position = UDim2.fromOffset(14, 110),
						Parent = f,
					})
				end
				local cor = if estado.granulados >= b.custoGranulados then "rosa" else "cinza"
				botaoCompra(f, cor, "✨", tostring(b.custoGranulados), function()
					pedir("ComprarBoost", b.id)
				end)
			end
		elseif abaAtual == "granulados" then
			for i, p in LojaDados.Pacotes do
				local f = cartao(i, p.icone, "rosa", p.nome, p.descricao)
				if p.etiqueta then
					local corTag = if p.etiqueta == "POPULAR" then Cores.Vermelho else Cores.Ouro
					local tag = C.etiqueta(p.etiqueta, corTag, 15, {
						Position = UDim2.new(1, -14, 0, -12),
						AnchorPoint = Vector2.new(1, 0),
						ZIndex = 3,
					})
					tag.Parent = f
				end
				botaoCompra(f, "ouro", nil, p.precoRobux .. " Robux", function()
					pedir("ComprarPacote", p.id)
				end)
			end
		else
			for i, p in LojaDados.Passes do
				local f = cartao(i, p.icone, "roxo", p.nome, p.descricao)
				if estado.passes[p.id] then
					botaoCompra(f, "verde", "✓", "JÁ É SEU", function() end)
				else
					botaoCompra(f, "ouro", nil, p.precoRobux .. " Robux", function()
						pedir("ComprarPasse", p.id)
					end)
				end
			end
		end
	end

	Estado.aoMudar(function()
		if Navegacao.aberto() == "Loja" then
			desenhar()
		end
	end)
	Navegacao.aoTrocar(function(nome)
		if nome == "Loja" then
			if abaPedida then
				abaAtual = abaPedida
				abaPedida = nil
			end
			desenhar()
		end
	end)
end

return Loja
