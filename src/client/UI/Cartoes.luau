-- Componentes das telas internas no estilo das lojas de jogos de aventura do Roblox:
-- abas laterais com ícone, cartões em grade (faixa de cor, ícone grande, nome, preço e botão),
-- faixa de destaque (banner) e fichas de filtro. Mantém a identidade da Órbita (placas
-- chanfradas, fundo escuro, lilás) e usa o atlas de ícones (IconeImagem).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Cores = require(ReplicatedStorage.Shared.Tema).Orbita
local Kit = require(script.Parent.Kit)
local IconeImagem = require(script.Parent.IconeImagem)

local Cartoes = {}

Cartoes.ROBUX = utf8.char(0xE002) -- símbolo do Robux nas fontes do Roblox
Cartoes.VERDE = Color3.fromHex("3DDC84")
Cartoes.OURO = Color3.fromHex("FFC83D")

local BRANCO = Color3.new(1, 1, 1)

-- Leve aumento ao passar o mouse e "afundar" ao tocar
function Cartoes.animarToque(alvo: GuiObject, botao: GuiButton)
	local escala = alvo:FindFirstChildOfClass("UIScale") or Kit.novo("UIScale", { Parent = alvo })
	local function para(v: number)
		TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = v })
			:Play()
	end
	botao.MouseEnter:Connect(function()
		para(1.03)
	end)
	botao.MouseLeave:Connect(function()
		para(1)
	end)
	botao.MouseButton1Down:Connect(function()
		para(0.96)
	end)
	botao.MouseButton1Up:Connect(function()
		para(1.03)
	end)
end

local function degrade(alvo: GuiObject, topo: Color3, base: Color3, rotacao: number?)
	Kit.novo("UIGradient", {
		Rotation = rotacao or 90,
		Color = ColorSequence.new(topo, base),
		Parent = alvo,
	})
end

-- ===================================================================== estrutura

export type Estrutura = { lateral: Frame, conteudo: ScrollingFrame, lista: Frame }

-- Divide o painel: coluna de abas à esquerda e área rolável à direita
function Cartoes.estrutura(pai: Instance, larguraLateral: number?): Estrutura
	local w = larguraLateral or 196
	local lateral = Kit.novo("Frame", {
		Name = "Abas",
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(0, w, 1, -10),
		Parent = pai,
	})
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = lateral,
	})
	Kit.novo("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = lateral,
	})
	local rolagem = Kit.rolagem(pai)
	rolagem.Position = UDim2.fromOffset(w + 24, 4)
	rolagem.Size = UDim2.new(1, -(w + 36), 1, -10)
	local lista = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -12, 0, 0),
		Parent = rolagem,
	})
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = lista,
	})
	return { lateral = lateral, conteudo = rolagem, lista = lista }
end

export type Aba = { definirAtiva: (ativa: boolean) -> (), placa: Kit.Placa }

-- Aba lateral: ícone + nome, faixa de cor à esquerda quando ativa
function Cartoes.aba(
	pai: Instance,
	ordem: number,
	nome: string,
	icone: number,
	cor: Color3,
	aoClicar: () -> ()
): Aba
	local p = Kit.placa({ tamanho = UDim2.new(1, 0, 0, 60), ordem = ordem, corte = 10, pai = pai })
	local faixa = Kit.novo("Frame", {
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 8),
		Size = UDim2.new(0, 4, 1, -16),
		Parent = p.conteudo,
	})
	IconeImagem.criar(p.conteudo, icone, UDim2.fromOffset(14, 12), UDim2.fromOffset(36, 36))
	local rotulo = Kit.texto({
		fonte = "titulo",
		Text = nome,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, -66, 1, 0),
		Parent = p.conteudo,
	})
	local b = Kit.alvo(p.quadro, nome, aoClicar)
	Cartoes.animarToque(p.quadro, b)
	local function definirAtiva(ativa: boolean)
		p.definirCor(
			if ativa then Cores.Elevado else Cores.Painel,
			if ativa then cor else Cores.Borda
		)
		faixa.Visible = ativa
		rotulo.TextColor3 = if ativa then Kit.corLegivel(cor) else Cores.TextoSuave
	end
	definirAtiva(false)
	return { definirAtiva = definirAtiva, placa = p }
end

-- Título de seção ("PACOTES", "TÍTULOS"...)
function Cartoes.secao(pai: Instance, ordem: number, texto: string, detalhe: string?)
	local f = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = ordem,
		Parent = pai,
	})
	Kit.texto({
		fonte = "titulo",
		Text = string.upper(texto),
		TextSize = 22,
		TextColor3 = Cores.Lilas,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Parent = f,
	})
	if detalhe then
		Kit.texto({
			Text = detalhe,
			TextSize = 14,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(1, 1),
			Parent = f,
		})
	end
end

-- Grade de cartões com largura fixa por célula
function Cartoes.grade(pai: Instance, ordem: number, celula: Vector2): Frame
	local g = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = ordem,
		Parent = pai,
	})
	Kit.novo("UIGridLayout", {
		CellSize = UDim2.fromOffset(celula.X, celula.Y),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = g,
	})
	return g
end

-- Fichas de filtro em linha
function Cartoes.fichas(
	pai: Instance,
	ordem: number,
	nomes: { string },
	ativa: string,
	aoEscolher: (string) -> ()
)
	local f = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = ordem,
		Parent = pai,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = f,
	})
	for i, nome in nomes do
		local b = Kit.botaoPlaca({
			texto = nome,
			tamanho = UDim2.fromOffset(math.max(96, #nome * 11 + 30), 38),
			tamanhoTexto = 15,
			tom = if nome == ativa then "lilas" else "neutro",
			pai = f,
			ordem = i,
			aoClicar = function()
				aoEscolher(nome)
			end,
		})
		Cartoes.animarToque(b.placa.quadro, b.botao)
	end
end

-- ===================================================================== cartão

export type EstadoBotao =
	"comprar"
	| "possui"
	| "equipar"
	| "equipado"
	| "resgatar"
	| "bloqueado"
	| "travado"
	| "info"

export type OpcoesCartao = {
	pai: Instance,
	ordem: number?,
	cor: Color3, -- cor da raridade/produto (faixa, borda, brilho do ícone)
	icone: number,
	titulo: string,
	subtitulo: string?,
	linhas: { string }?, -- benefícios (•)
	etiqueta: string?, -- selo no canto ("NOVO", "MAIS VENDIDO", "PREMIUM")
	preco: number?,
	estado: EstadoBotao,
	textoBotao: string?, -- substitui o texto padrão do estado
	aoClicar: (() -> ())?,
}

local function textoPadrao(op: OpcoesCartao): string
	local e = op.estado
	return if op.textoBotao
		then op.textoBotao
		elseif e == "comprar" then Cartoes.ROBUX .. " " .. tostring(op.preco or 0)
		elseif e == "possui" then "Possui"
		elseif e == "equipar" then "Equipar"
		elseif e == "equipado" then "Equipado"
		elseif e == "resgatar" then "Resgatar"
		elseif e == "bloqueado" then "Premium"
		elseif e == "info" then ""
		else "Bloqueado"
end

-- Cartão de item da loja/coleção. Ocupa toda a célula da grade.
function Cartoes.cartao(op: OpcoesCartao): Kit.Placa
	local apagado = op.estado == "travado"
	local p = Kit.placa({
		tamanho = UDim2.new(),
		borda = if apagado then Cores.Borda else op.cor,
		ordem = op.ordem,
		corte = 14,
		pai = op.pai,
	})
	-- faixa de cor no topo com o brilho atrás do ícone
	local topo = Kit.novo("Frame", {
		BackgroundColor3 = BRANCO,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 0, 104),
		Parent = p.conteudo,
	})
	degrade(topo, (if apagado then Cores.Borda else op.cor):Lerp(Cores.Painel, 0.45), Cores.Painel)
	local brilho = Kit.circulo({
		BackgroundColor3 = if apagado then Cores.Borda else op.cor,
		BackgroundTransparency = 0.72,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(86, 86),
		Parent = p.conteudo,
	})
	degrade(brilho, BRANCO, Cores.Painel)
	local imagem = IconeImagem.criar(
		p.conteudo,
		op.icone,
		UDim2.new(0.5, -34, 0, 22),
		UDim2.fromOffset(68, 68)
	)
	if apagado then
		imagem.ImageTransparency = 0.55
		IconeImagem.criar(p.conteudo, 11, UDim2.new(1, -36, 0, 10), UDim2.fromOffset(26, 26))
	end
	if op.etiqueta then
		local selo = Kit.placa({
			tamanho = UDim2.fromOffset(#op.etiqueta * 8 + 20, 22),
			posicao = UDim2.fromOffset(8, 8),
			fundo = op.cor,
			borda = op.cor,
			corte = 5,
			z = 4,
			pai = p.conteudo,
		})
		Kit.texto({
			fonte = "titulo",
			Text = op.etiqueta,
			TextSize = 13,
			TextColor3 = Cores.Fundo,
			Size = UDim2.fromScale(1, 1),
			Parent = selo.conteudo,
		})
	end
	local y = 108
	Kit.texto({
		fonte = "titulo",
		Text = op.titulo,
		TextSize = 20,
		TextColor3 = if apagado then Cores.TextoSuave else Kit.corLegivel(op.cor),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, 26),
		Parent = p.conteudo,
	})
	y += 26
	if op.subtitulo then
		Kit.texto({
			Text = op.subtitulo,
			TextSize = 14,
			TextColor3 = Cores.TextoSuave,
			TextWrapped = true,
			Position = UDim2.fromOffset(8, y),
			Size = UDim2.new(1, -16, 0, 18),
			Parent = p.conteudo,
		})
		y += 20
	end
	if op.linhas then
		for _, l in op.linhas do
			Kit.texto({
				Text = "•  " .. l,
				TextSize = 14,
				RichText = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Position = UDim2.fromOffset(14, y),
				Size = UDim2.new(1, -24, 0, 18),
				Parent = p.conteudo,
			})
			y += 19
		end
	end

	-- botão do rodapé
	local e = op.estado
	local corBotao = if e == "comprar"
		then Cartoes.VERDE
		elseif e == "resgatar" then Cores.Lilas
		elseif e == "equipar" then Cores.Lilas
		elseif e == "bloqueado" then Cartoes.OURO
		else Cores.Elevado
	local ativo = e == "possui" or e == "equipado"
	local botao = Kit.placa({
		tamanho = UDim2.new(1, -16, 0, 40),
		ancora = Vector2.new(0.5, 1),
		posicao = UDim2.new(0.5, 0, 1, -8),
		fundo = if ativo then Cores.Ativo else corBotao,
		borda = if ativo then Cores.Menta else corBotao,
		corte = 8,
		z = 4,
		pai = p.conteudo,
	})
	local claro = e == "comprar" or e == "resgatar" or e == "equipar" or e == "bloqueado"
	if ativo then
		IconeImagem.criar(botao.conteudo, 12, UDim2.new(0, 10, 0.5, -11), UDim2.fromOffset(22, 22))
	elseif e == "bloqueado" or e == "travado" then
		IconeImagem.criar(botao.conteudo, 11, UDim2.new(0, 10, 0.5, -11), UDim2.fromOffset(22, 22))
	end
	Kit.texto({
		fonte = "titulo",
		Text = textoPadrao(op),
		TextSize = 19,
		TextColor3 = if claro
			then Cores.Fundo
			elseif ativo then Cores.Menta
			elseif e == "info" then Cores.Texto
			else Cores.TextoSuave,
		Size = UDim2.fromScale(1, 1),
		Parent = botao.conteudo,
	})
	if op.aoClicar then
		local alvo = Kit.alvo(p.quadro, op.titulo .. " · " .. textoPadrao(op), op.aoClicar)
		Cartoes.animarToque(p.quadro, alvo)
	end
	return p
end

-- ===================================================================== destaque

-- Faixa larga de destaque (banner) com ícone, textos e um botão à direita
function Cartoes.banner(op: {
	pai: Instance,
	ordem: number,
	cor: Color3,
	icone: number,
	titulo: string,
	texto: string,
	botao: string?,
	corBotao: Color3?,
	aoClicar: (() -> ())?,
	altura: number?,
}): Kit.Placa
	local p = Kit.placa({
		tamanho = UDim2.new(1, 0, 0, op.altura or 120),
		borda = op.cor,
		ordem = op.ordem,
		corte = 16,
		pai = op.pai,
	})
	local fundo = Kit.novo("Frame", {
		BackgroundColor3 = BRANCO,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		Parent = p.conteudo,
	})
	degrade(fundo, op.cor:Lerp(Cores.Painel, 0.35), Cores.Painel, 0)
	IconeImagem.criar(p.conteudo, op.icone, UDim2.new(0, 18, 0.5, -42), UDim2.fromOffset(84, 84))
	local direita = if op.botao then 230 else 20
	Kit.texto({
		fonte = "titulo",
		Text = op.titulo,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(118, 14),
		Size = UDim2.new(1, -118 - direita, 0, 38),
		Parent = p.conteudo,
	})
	Kit.texto({
		Text = op.texto,
		TextSize = 16,
		RichText = true,
		TextColor3 = Cores.Texto,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.fromOffset(118, 54),
		Size = UDim2.new(1, -118 - direita, 1, -60),
		Parent = p.conteudo,
	})
	if op.botao then
		local cor = op.corBotao or Cartoes.VERDE
		local b = Kit.placa({
			tamanho = UDim2.fromOffset(196, 52),
			ancora = Vector2.new(1, 0.5),
			posicao = UDim2.new(1, -18, 0.5, 0),
			fundo = cor,
			borda = cor,
			corte = 10,
			z = 4,
			pai = p.conteudo,
		})
		Kit.texto({
			fonte = "titulo",
			Text = op.botao,
			TextSize = 22,
			TextColor3 = Cores.Fundo,
			Size = UDim2.fromScale(1, 1),
			Parent = b.conteudo,
		})
		if op.aoClicar then
			local alvo = Kit.alvo(b.quadro, op.botao, op.aoClicar)
			Cartoes.animarToque(b.quadro, alvo)
		end
	end
	return p
end

-- Barra de progresso fina
function Cartoes.barra(
	pai: Instance,
	cor: Color3,
	fracao: number,
	posicao: UDim2,
	tamanho: UDim2
): Frame
	local fundo = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Fundo,
		BorderSizePixel = 0,
		Position = posicao,
		Size = tamanho,
		Parent = pai,
	})
	Kit.novo("UIStroke", { Color = Cores.Borda, Thickness = 1, Parent = fundo })
	local cheio = Kit.novo("Frame", {
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(math.clamp(fracao, 0, 1), 1),
		Parent = fundo,
	})
	return cheio
end

return Cartoes
