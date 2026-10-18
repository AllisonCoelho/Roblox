-- Peças visuais reutilizáveis da interface (ver docs/design/01-identidade.png).
-- Tudo é criado por código: o repositório é a fonte da verdade e o deploy recria o jogo inteiro.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tema = require(ReplicatedStorage.Shared.Tema)

local Cores = Tema.Cores
local C = {}

-- Cria uma instância com propriedades e filhos: C.novo("Frame", { Size = ... }, { filho1, filho2 })
function C.novo(classe: string, props: { [string]: any }?, filhos: { Instance }?): any
	local inst = Instance.new(classe)
	local pai = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				pai = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if filhos then
		for _, f in filhos do
			f.Parent = inst
		end
	end
	if pai then
		inst.Parent = pai
	end
	return inst
end

function C.cantos(pai: Instance, raio: number?): UICorner
	return C.novo("UICorner", { CornerRadius = UDim.new(0, raio or Tema.Canto), Parent = pai })
end

function C.cantosRedondos(pai: Instance): UICorner
	return C.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pai })
end

function C.contorno(pai: Instance, espessura: number?, cor: Color3?): UIStroke
	return C.novo("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = espessura or Tema.Contorno,
		Color = cor or Cores.Contorno,
		Parent = pai,
	})
end

function C.degrade(pai: Instance, claro: Color3, base: Color3): UIGradient
	return C.novo("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(claro, base),
		Parent = pai,
	})
end

function C.padding(pai: Instance, px: number, py: number?): UIPadding
	local y = py or px
	return C.novo("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		Parent = pai,
	})
end

function C.lista(
	pai: Instance,
	direcao: Enum.FillDirection,
	espaco: number,
	alinhH: Enum.HorizontalAlignment?,
	alinhV: Enum.VerticalAlignment?
): UIListLayout
	return C.novo("UIListLayout", {
		FillDirection = direcao,
		Padding = UDim.new(0, espaco),
		HorizontalAlignment = alinhH or Enum.HorizontalAlignment.Left,
		VerticalAlignment = alinhV or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pai,
	})
end

-- Texto branco com contorno escuro (estilo Roblox)
function C.texto(props: { [string]: any }): TextLabel
	local label = C.novo("TextLabel", {
		BackgroundTransparency = 1,
		Font = Tema.Fonte,
		TextColor3 = Cores.Branco,
		TextSize = 24,
		Text = "",
	})
	local contorno = props.contorno
	props.contorno = nil
	for k, v in props do
		if k ~= "Parent" then
			(label :: any)[k] = v
		end
	end
	if contorno ~= false then
		C.novo("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = Cores.Contorno,
			Thickness = if type(contorno) == "number" then contorno else 2.5,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- Texto escuro sem contorno (para fundos claros)
function C.textoEscuro(props: { [string]: any }): TextLabel
	props.contorno = false
	props.TextColor3 = props.TextColor3 or Cores.Contorno
	props.Font = props.Font or Tema.FonteTexto
	return C.texto(props)
end

function C.emoji(texto: string, tamanho: number, props: { [string]: any }?): TextLabel
	local p = props or {}
	p.Text = texto
	p.TextSize = tamanho
	p.contorno = false
	p.Font = Enum.Font.SourceSans
	p.Size = p.Size or UDim2.fromOffset(tamanho * 1.3, tamanho * 1.3)
	return C.texto(p)
end

export type Botao = {
	quadro: Frame,
	botao: TextButton,
	rotulo: TextLabel?,
	icone: TextLabel?,
	definirTexto: (texto: string) -> (),
	definirCor: (cor: string) -> (),
}

export type OpcoesBotao = {
	cor: string?, -- chave de Tema.Botoes
	texto: string?,
	icone: string?,
	tamanho: UDim2?,
	tamanhoTexto: number?,
	tamanhoIcone: number?,
	vertical: boolean?, -- ícone em cima, texto embaixo (botões do menu)
	posicao: UDim2?,
	ancora: Vector2?,
	ordem: number?,
	aoClicar: (() -> ())?,
	pai: Instance?,
	sombra: number?,
}

-- Botão "gordinho": UICorner + UIStroke + UIGradient + sombra (frame deslocado) + brilho no topo
function C.botao(op: OpcoesBotao): Botao
	local sombraPx = op.sombra or Tema.Sombra
	local quadro = C.novo("Frame", {
		Name = "Botao",
		BackgroundTransparency = 1,
		Size = op.tamanho or UDim2.fromOffset(220, 64),
		Position = op.posicao or UDim2.new(),
		AnchorPoint = op.ancora or Vector2.zero,
		LayoutOrder = op.ordem or 0,
	})
	local sombra = C.novo("Frame", {
		Name = "Sombra",
		BackgroundColor3 = Cores.Contorno,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, sombraPx),
		ZIndex = 1,
		Parent = quadro,
	})
	C.cantos(sombra)
	local botao = C.novo("TextButton", {
		Name = "Clique",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Cores.Branco,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = quadro,
	})
	C.cantos(botao)
	C.contorno(botao)
	local cores = Tema.Botoes[op.cor or "verde"] or Tema.Botoes.verde
	local degrade = C.degrade(botao, cores[1], cores[2])
	local brilho = C.novo("Frame", {
		Name = "Brilho",
		BackgroundColor3 = Cores.Branco,
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, -12, 0.38, 0),
		Position = UDim2.fromOffset(6, 4),
		Parent = botao,
	})
	C.cantos(brilho, 12)

	local conteudo = C.novo("Frame", {
		Name = "Conteudo",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = botao,
	})
	C.lista(
		conteudo,
		if op.vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		if op.vertical then 0 else 8,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	local tamanhoTexto = op.tamanhoTexto or 28
	local icone, rotulo
	if op.icone then
		local t = op.tamanhoIcone or math.floor(tamanhoTexto * 1.1)
		icone =
			C.emoji(op.icone, t, { Name = "Icone", LayoutOrder = 1, ZIndex = 2, Parent = conteudo })
	end
	if op.texto then
		rotulo = C.texto({
			Name = "Texto",
			Text = op.texto,
			TextSize = tamanhoTexto,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, tamanhoTexto + 4),
			LayoutOrder = 2,
			ZIndex = 2,
			Parent = conteudo,
		})
	end

	-- Animação de apertar: o botão desce até a sombra
	local info = TweenInfo.new(0.07, Enum.EasingStyle.Quad)
	local baixo = TweenService:Create(botao, info, { Position = UDim2.fromOffset(0, sombraPx - 2) })
	local cima = TweenService:Create(botao, info, { Position = UDim2.new() })
	botao.MouseButton1Down:Connect(function()
		baixo:Play()
	end)
	botao.MouseButton1Up:Connect(function()
		cima:Play()
	end)
	botao.MouseLeave:Connect(function()
		cima:Play()
	end)
	if op.aoClicar then
		botao.Activated:Connect(op.aoClicar)
	end
	if op.pai then
		quadro.Parent = op.pai
	end

	return {
		quadro = quadro,
		botao = botao,
		rotulo = rotulo,
		icone = icone,
		definirTexto = function(texto: string)
			if rotulo then
				rotulo.Text = texto
			end
		end,
		definirCor = function(cor: string)
			local par = Tema.Botoes[cor] or Tema.Botoes.verde
			degrade.Color = ColorSequence.new(par[1], par[2])
		end,
	}
end

export type Pilula = {
	quadro: Frame,
	valor: TextLabel,
	extra: TextLabel,
	mais: TextButton?,
}

-- Contador de moeda: círculo com ícone + valor (+ texto extra e botão "+" opcionais)
function C.pilula(op: {
	icone: string,
	corIcone: { Color3 },
	largura: number?,
	altura: number?,
	mais: boolean?,
	pai: Instance?,
	ordem: number?,
}): Pilula
	local altura = op.altura or 64
	local quadro = C.novo("Frame", {
		Name = "Pilula",
		BackgroundColor3 = Cores.Contorno,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(op.largura or 270, altura),
		LayoutOrder = op.ordem or 0,
	})
	C.cantosRedondos(quadro)
	C.contorno(quadro)
	local circulo = C.novo("Frame", {
		Name = "Icone",
		BackgroundColor3 = Cores.Branco,
		Size = UDim2.fromOffset(altura + 8, altura + 8),
		Position = UDim2.new(0, -10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = quadro,
	})
	C.cantosRedondos(circulo)
	C.contorno(circulo)
	C.degrade(circulo, op.corIcone[1], op.corIcone[2])
	C.emoji(op.icone, math.floor(altura * 0.55), {
		Size = UDim2.fromScale(1, 1),
		Parent = circulo,
	})
	local valor = C.texto({
		Name = "Valor",
		Text = "0",
		TextSize = math.floor(altura * 0.53),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -(altura + 12), 1, 0),
		Position = UDim2.fromOffset(altura + 10, 0),
		Parent = quadro,
	})
	local extra = C.texto({
		Name = "Extra",
		Text = "",
		TextSize = math.floor(altura * 0.29),
		TextColor3 = Cores.Menta,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -16, 1, 0),
		contorno = 1.5,
		Parent = quadro,
	})
	local mais
	if op.mais then
		mais = C.novo("TextButton", {
			Name = "Mais",
			Text = "+",
			Font = Tema.Fonte,
			TextSize = 30,
			TextColor3 = Cores.Branco,
			BackgroundColor3 = Cores.Menta,
			AutoButtonColor = true,
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = quadro,
		})
		C.cantos(mais, 12)
		C.contorno(mais, 3)
	end
	if op.pai then
		quadro.Parent = op.pai
	end
	return { quadro = quadro, valor = valor, extra = extra, mais = mais }
end

C.CorIconeMoeda = { Color3.fromHex("FFF3B0"), Cores.OuroEscuro }
C.CorIconeGranulado = { Color3.fromHex("FFD0E6"), Cores.RosaEscuro }

-- Caixa escura translúcida (cartões do HUD)
function C.cartaoEscuro(props: { [string]: any }): Frame
	props.BackgroundColor3 = Cores.Contorno
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	local f = C.novo("Frame", props)
	C.cantos(f, 20)
	C.contorno(f)
	return f
end

-- Caixa clara com contorno (cartões dentro de painéis)
function C.cartaoClaro(props: { [string]: any }, raio: number?): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Cores.Branco
	local f = C.novo("Frame", props)
	C.cantos(f, raio or 20)
	C.contorno(f)
	return f
end

export type Barra = {
	quadro: Frame,
	definir: (fracao: number, texto: string?) -> (),
}

function C.barra(op: {
	tamanho: UDim2,
	cores: { Color3 }?,
	tamanhoTexto: number?,
	pai: Instance?,
	posicao: UDim2?,
	ordem: number?,
}): Barra
	local quadro = C.novo("Frame", {
		Name = "Barra",
		BackgroundColor3 = Cores.Fundo,
		Size = op.tamanho,
		Position = op.posicao or UDim2.new(),
		LayoutOrder = op.ordem or 0,
		ClipsDescendants = true,
	})
	C.cantosRedondos(quadro)
	C.contorno(quadro, 3)
	local cores = op.cores or { Cores.MentaClaro, Cores.Menta }
	local preenchimento = C.novo("Frame", {
		Name = "Preenchimento",
		BackgroundColor3 = Cores.Branco,
		Size = UDim2.fromScale(0, 1),
		Parent = quadro,
	})
	C.cantosRedondos(preenchimento)
	C.degrade(preenchimento, cores[1], cores[2])
	local rotulo = C.texto({
		Name = "Texto",
		TextSize = op.tamanhoTexto or 17,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		contorno = 2,
		Parent = quadro,
	})
	if op.pai then
		quadro.Parent = op.pai
	end
	return {
		quadro = quadro,
		definir = function(fracao: number, texto: string?)
			preenchimento.Size = UDim2.fromScale(math.clamp(fracao, 0, 1), 1)
			rotulo.Text = texto or ""
		end,
	}
end

-- Etiqueta arredondada (raridade, "POPULAR", etc.)
function C.etiqueta(
	texto: string,
	cor: Color3,
	tamanhoTexto: number?,
	props: { [string]: any }?
): Frame
	local t = tamanhoTexto or 16
	local p = props or {}
	p.Name = p.Name or "Etiqueta"
	p.BackgroundColor3 = cor
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, t + 10)
	local f = C.novo("Frame", p)
	C.cantosRedondos(f)
	C.contorno(f, 3)
	C.padding(f, 12, 0)
	C.texto({
		Name = "Texto",
		Text = texto,
		TextSize = t,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		contorno = 2,
		Parent = f,
	})
	return f
end

-- Bolinha vermelha de aviso no canto de um botão
-- Devolve o quadro (para mostrar/esconder) e o texto (para trocar o número)
function C.notificacao(pai: Instance): (Frame, TextLabel)
	local bolinha = C.novo("Frame", {
		Name = "Notificacao",
		BackgroundColor3 = Cores.Vermelho,
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, 12, 0, -12),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 5,
		Visible = false,
		Parent = pai,
	})
	C.cantosRedondos(bolinha)
	C.contorno(bolinha, 4)
	local texto = C.texto({
		Text = "!",
		TextSize = 20,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		contorno = 2,
		Parent = bolinha,
	})
	return bolinha, texto
end

-- Fundo com degradê de raridade (cartões de Docinho)
function C.fundoRaridade(pai: Instance, brilho: Color3, cor: Color3)
	C.degrade(pai, brilho, cor).Rotation = 90
end

return C
