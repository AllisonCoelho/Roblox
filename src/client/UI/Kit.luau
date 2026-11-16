-- Componentes da interface Órbita do Nexo. Todas as formas usam instâncias nativas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = require(ReplicatedStorage.Shared.Tema)
local Cores = Tema.Orbita
local Kit = {}

local function novo(classe: string, props: { [string]: any }): any
	local inst = Instance.new(classe)
	local pai = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = pai
	return inst
end
Kit.novo = novo

function Kit.texto(props: { [string]: any }): TextLabel
	local fonte = props.fonte
	props.fonte = nil
	props.BackgroundTransparency = 1
	props.FontFace = if fonte == "titulo"
		then Tema.FonteNegrito
		elseif fonte == "mono" then Tema.FonteNumeros
		else Tema.FonteCorpo
	props.TextColor3 = props.TextColor3 or Cores.Texto
	props.TextSize = props.TextSize or 18
	props.Text = props.Text or ""
	return novo("TextLabel", props)
end

function Kit.corLegivel(cor: Color3): Color3
	return cor:Lerp(Cores.Texto, 0.38)
end

local function bloco(
	pai: Instance,
	cor: Color3,
	tamanho: UDim2,
	posicao: UDim2,
	ancora: Vector2?
): Frame
	return novo("Frame", {
		AnchorPoint = ancora or Vector2.zero,
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		Position = posicao,
		Size = tamanho,
		Parent = pai,
	})
end

-- Dois cantos chanfrados. As faixas centrais acompanham o tamanho da placa.
local function superficie(pai: Frame, cor: Color3, corte: number): { Frame }
	local meio = bloco(pai, cor, UDim2.new(1, 0, 1, -2 * corte), UDim2.fromOffset(0, corte))
	local topo = bloco(pai, cor, UDim2.new(1, -corte, 0, corte), UDim2.new())
	local base = bloco(pai, cor, UDim2.new(1, -corte, 0, corte), UDim2.new(0, corte, 1, -corte))
	local superior = bloco(pai, cor, UDim2.fromOffset(corte, corte), UDim2.new(1, -corte, 0, 0))
	local inferior = bloco(pai, cor, UDim2.fromOffset(corte, corte), UDim2.new(0, 0, 1, -corte))
	local recorte = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.495, 0),
		NumberSequenceKeypoint.new(0.505, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	novo("UIGradient", { Rotation = -45, Transparency = recorte, Parent = superior })
	novo("UIGradient", { Rotation = 135, Transparency = recorte, Parent = inferior })
	return { meio, topo, base, superior, inferior }
end

export type Placa = {
	quadro: Frame,
	conteudo: Frame,
	definirCor: (fundo: Color3, borda: Color3?) -> (),
}

function Kit.placa(op: {
	nome: string?,
	tamanho: UDim2,
	fundo: Color3?,
	borda: Color3?,
	corte: number?,
	pai: Instance?,
	posicao: UDim2?,
	ancora: Vector2?,
	ordem: number?,
	z: number?,
}): Placa
	local corte = op.corte or 10
	local quadro = novo("Frame", {
		Name = op.nome or "Placa",
		BackgroundTransparency = 1,
		Size = op.tamanho,
		Position = op.posicao or UDim2.new(),
		AnchorPoint = op.ancora or Vector2.zero,
		LayoutOrder = op.ordem or 0,
		ZIndex = op.z or 1,
		Parent = op.pai,
	})
	local bordas = superficie(quadro, op.borda or Cores.Borda, corte)
	local interior = novo("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 2,
		Parent = quadro,
	})
	local miolo = superficie(interior, op.fundo or Cores.Painel, corte - 1)
	local conteudo = novo("Frame", {
		Name = "Conteudo",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = quadro,
	})
	return {
		quadro = quadro,
		conteudo = conteudo,
		definirCor = function(fundo: Color3, borda: Color3?)
			for _, f in miolo do
				f.BackgroundColor3 = fundo
			end
			if borda then
				for _, f in bordas do
					f.BackgroundColor3 = borda
				end
			end
		end,
	}
end

function Kit.alvo(pai: GuiObject, nome: string, aoClicar: () -> ()): TextButton
	local botao = novo("TextButton", {
		Name = "Acao",
		Text = nome,
		TextTransparency = 1,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Selectable = true,
		ZIndex = 4,
		Parent = pai,
	})
	local foco = novo("Frame", {
		Name = "Foco",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = botao,
	})
	local contorno =
		novo("UIStroke", { Color = Cores.Foco, Thickness = 2, Enabled = false, Parent = foco })
	local vazio = novo("ImageLabel", {
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = botao,
	})
	botao.SelectionImageObject = vazio
	botao.SelectionGained:Connect(function()
		contorno.Enabled = true
	end)
	botao.SelectionLost:Connect(function()
		contorno.Enabled = false
	end)

	local pressionado = bloco(botao, Cores.Fundo, UDim2.fromScale(1, 1), UDim2.new())
	pressionado.BackgroundTransparency = 1
	local token = 0
	botao.Activated:Connect(function()
		if not botao.Interactable then
			return
		end
		token += 1
		local meu = token
		pressionado.BackgroundTransparency = 0.77
		task.delay(0.09, function()
			if token == meu then
				pressionado.BackgroundTransparency = 1
			end
		end)
		aoClicar()
	end)
	return botao
end

export type Tom = "lilas" | "menta" | "neutro"
export type BotaoPlaca = {
	placa: Placa,
	botao: TextButton,
	rotulo: TextLabel,
	definirTom: (tom: Tom) -> (),
}

function Kit.botaoPlaca(op: {
	texto: string,
	tamanho: UDim2,
	tamanhoTexto: number?,
	tom: Tom?,
	pai: Instance?,
	ordem: number?,
	aoClicar: () -> (),
}): BotaoPlaca
	local placa = Kit.placa({ tamanho = op.tamanho, pai = op.pai, ordem = op.ordem })
	local rotulo = Kit.texto({
		fonte = "titulo",
		Text = op.texto,
		TextSize = op.tamanhoTexto or 22,
		TextWrapped = true,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		Parent = placa.conteudo,
	})
	local function definirTom(tom: Tom)
		local primario = tom == "lilas"
		local ativo = tom == "menta"
		placa.definirCor(
			if primario then Cores.Lilas elseif ativo then Cores.Ativo else Cores.Painel,
			if primario then Cores.Lilas elseif ativo then Cores.Menta else Cores.Borda
		)
		rotulo.TextColor3 = if primario
			then Cores.Fundo
			elseif ativo then Cores.Menta
			else Cores.Texto
	end
	definirTom(op.tom or "neutro")
	return {
		placa = placa,
		botao = Kit.alvo(placa.quadro, op.texto, op.aoClicar),
		rotulo = rotulo,
		definirTom = definirTom,
	}
end

function Kit.rolagem(pai: Instance): ScrollingFrame
	return novo("ScrollingFrame", {
		Name = "Lista",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Cores.Lilas,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = pai,
	})
end

function Kit.cristal(pai: Instance, largura: number, cor: Color3): (Frame, Frame)
	local quadro = novo("Frame", {
		Name = "Cristal",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(largura, largura),
		Parent = pai,
	})
	local diamante = bloco(
		quadro,
		Cores.Elevado,
		UDim2.fromScale(0.68, 0.68),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5)
	)
	diamante.Rotation = 45
	novo("UIStroke", { Color = Cores.Borda, Thickness = 1, Parent = diamante })
	local centro = bloco(
		quadro,
		cor,
		UDim2.fromScale(0.38, 0.38),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5)
	)
	centro.Rotation = 45
	novo("UIGradient", {
		Rotation = -45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Cores.Texto),
			ColorSequenceKeypoint.new(0.495, Cores.Texto),
			ColorSequenceKeypoint.new(0.505, Cores.Borda),
			ColorSequenceKeypoint.new(1, Cores.Borda),
		}),
		Parent = centro,
	})
	return quadro, centro
end

function Kit.circulo(props: { [string]: any }): Frame
	local f = novo("Frame", props)
	novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	return f
end

export type Anel = { quadro: Frame, definir: (fracao: number, cor: Color3?) -> () }

-- Anel de progresso circular (técnica das duas metades com UIGradient).
-- Preenche no sentido horário a partir do topo.
function Kit.anel(pai: Instance, tamanho: number, cor: Color3, fundo: Color3, z: number): Anel
	local quadro = Kit.circulo({
		Name = "Anel",
		BackgroundColor3 = fundo,
		Size = UDim2.fromOffset(tamanho, tamanho),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Parent = pai,
	})
	local discos: { Frame } = {}
	local function metade(direita: boolean): UIGradient
		local recorte = novo("Frame", {
			Name = if direita then "Direita" else "Esquerda",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(if direita then 0.5 else 0, 0),
			ZIndex = z,
			Parent = quadro,
		})
		local disco = Kit.circulo({
			BackgroundColor3 = cor,
			Size = UDim2.fromScale(2, 1),
			Position = UDim2.fromScale(if direita then -1 else 0, 0),
			ZIndex = z,
			Parent = recorte,
		})
		table.insert(discos, disco)
		-- Metade direita: lado esquerdo do disco opaco, que gira para dentro do recorte
		local a, b = if direita then 0 else 1, if direita then 1 else 0
		return novo("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, a),
				NumberSequenceKeypoint.new(0.5, a),
				NumberSequenceKeypoint.new(0.501, b),
				NumberSequenceKeypoint.new(1, b),
			}),
			Parent = disco,
		})
	end
	local direita = metade(true)
	local esquerda = metade(false)
	local corAtual = cor
	local fracaoAtual = -1
	local function definir(fracao: number, novaCor: Color3?)
		if novaCor and novaCor ~= corAtual then
			corAtual = novaCor
			for _, disco in discos do
				disco.BackgroundColor3 = novaCor
			end
		end
		if fracao == fracaoAtual then
			return
		end
		fracaoAtual = fracao
		local graus = math.clamp(fracao, 0, 1) * 360
		direita.Rotation = math.clamp(graus, 0, 180)
		esquerda.Rotation = math.clamp(graus - 180, 0, 180)
	end
	definir(1)
	return { quadro = quadro, definir = definir }
end

return Kit
