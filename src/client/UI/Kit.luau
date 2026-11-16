-- Peças visuais da identidade "Tinta e Selo".
-- O Roblox não inclina (skew) elementos de UI, então as placas inclinadas são feitas
-- com fatias horizontais finas, cada uma deslocada um pouco: de longe vira um paralelogramo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = require(ReplicatedStorage.Shared.Tema)

local Cores = Tema.Cores
local Kit = {}

local INCLINACAO = math.tan(math.rad(12))

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

-- Texto sem fundo. fonte: "negrito" (padrão) | "media" | "pincel"
function Kit.texto(props: { [string]: any }): TextLabel
	local fonte = props.fonte
	props.fonte = nil
	props.BackgroundTransparency = 1
	props.FontFace = if fonte == "pincel"
		then Tema.FontePincel
		elseif fonte == "media" then Tema.FonteMedia
		else Tema.FonteNegrito
	props.TextColor3 = props.TextColor3 or Cores.Papel
	props.TextSize = props.TextSize or 24
	props.Text = props.Text or ""
	return novo("TextLabel", props)
end

-- Uma camada de fatias formando um paralelogramo dentro de `pai`
local function fatias(
	pai: Instance,
	largura: number,
	altura: number,
	deslocX: number,
	deslocY: number,
	cor: Color3,
	nome: string,
	z: number
): { Frame }
	local passo = 3
	local n = math.ceil(altura / passo)
	local lista = {}
	for i = 0, n - 1 do
		local y = i * passo
		local h = math.min(passo, altura - y)
		-- Quanto mais para baixo, mais à esquerda (inclinação para a direita)
		local x = (altura - y - h / 2) * INCLINACAO
		table.insert(
			lista,
			novo("Frame", {
				Name = nome,
				BackgroundColor3 = cor,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(x + deslocX, y + deslocY),
				Size = UDim2.fromOffset(largura - altura * INCLINACAO, h),
				ZIndex = z,
				Parent = pai,
			})
		)
	end
	return lista
end

export type Placa = {
	quadro: Frame,
	conteudo: Frame,
	definirCor: (fundo: Color3, borda: Color3?) -> (),
}

-- Placa inclinada com borda e sombra deslocada. O conteúdo fica num Frame reto por cima.
function Kit.placa(op: {
	largura: number,
	altura: number,
	fundo: Color3,
	borda: Color3?,
	espessura: number?,
	sombra: Color3?,
	pai: Instance?,
	posicao: UDim2?,
	ancora: Vector2?,
	ordem: number?,
	z: number?,
}): Placa
	local z = op.z or 1
	local e = op.espessura or 0
	local quadro = novo("Frame", {
		Name = "Placa",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(op.largura, op.altura),
		Position = op.posicao or UDim2.new(),
		AnchorPoint = op.ancora or Vector2.zero,
		LayoutOrder = op.ordem or 0,
		ZIndex = z,
	})
	if op.sombra then
		fatias(quadro, op.largura, op.altura, 6, 6, op.sombra, "Sombra", z)
	end
	local camadaBorda = if op.borda and e > 0
		then fatias(quadro, op.largura, op.altura, 0, 0, op.borda, "Borda", z + 1)
		else {}
	local miolo =
		fatias(quadro, op.largura - e * 2, op.altura - e * 2, e, e, op.fundo, "Fundo", z + 2)
	local conteudo = novo("Frame", {
		Name = "Conteudo",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 3,
		Parent = quadro,
	})
	if op.pai then
		quadro.Parent = op.pai
	end
	return {
		quadro = quadro,
		conteudo = conteudo,
		definirCor = function(fundo: Color3, borda: Color3?)
			for _, f in miolo do
				f.BackgroundColor3 = fundo
			end
			if borda then
				for _, f in camadaBorda do
					f.BackgroundColor3 = borda
				end
			end
		end,
	}
end

export type BotaoPlaca = {
	placa: Placa,
	botao: TextButton,
	rotulo: TextLabel,
	definirTexto: (texto: string) -> (),
	definirAtivo: (ativo: boolean) -> (),
}

-- Botão inclinado (AUTO, ÍNDICE). ativo = fundo papel com texto tinta.
function Kit.botaoPlaca(op: {
	texto: string,
	largura: number,
	altura: number,
	tamanhoTexto: number,
	sombra: Color3,
	pai: Instance?,
	ordem: number?,
	aoClicar: () -> (),
}): BotaoPlaca
	local placa = Kit.placa({
		largura = op.largura,
		altura = op.altura,
		fundo = Cores.Tinta,
		borda = Cores.Papel,
		espessura = 3,
		sombra = op.sombra,
		ordem = op.ordem,
		pai = op.pai,
	})
	local rotulo = Kit.texto({
		Text = op.texto,
		TextSize = op.tamanhoTexto,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = placa.conteudo,
	})
	local botao = novo("TextButton", {
		Name = "Clique",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = placa.quadro,
	})
	botao.Activated:Connect(op.aoClicar)
	return {
		placa = placa,
		botao = botao,
		rotulo = rotulo,
		definirTexto = function(texto: string)
			rotulo.Text = texto
		end,
		definirAtivo = function(ativo: boolean)
			placa.definirCor(if ativo then Cores.Papel else Cores.Tinta)
			rotulo.TextColor3 = if ativo then Cores.Tinta else Cores.Papel
		end,
	}
end

function Kit.circulo(props: { [string]: any }): Frame
	local f = novo("Frame", props)
	novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	return f
end

export type Anel = { quadro: Frame, definir: (fracao: number) -> () }

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
	local function definir(fracao: number)
		local graus = math.clamp(fracao, 0, 1) * 360
		direita.Rotation = math.clamp(graus, 0, 180)
		esquerda.Rotation = math.clamp(graus - 180, 0, 180)
	end
	definir(1)
	return { quadro = quadro, definir = definir }
end

-- Ícone do olho se abrindo (selo do botão DESPERTAR)
function Kit.olho(pai: Instance, largura: number, cor: Color3, z: number): Frame
	local quadro = novo("Frame", {
		Name = "Olho",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(largura, largura * 0.55),
		ZIndex = z,
		Parent = pai,
	})
	local contorno = Kit.circulo({
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.7),
		Position = UDim2.fromScale(0.5, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Parent = quadro,
	})
	novo("UIStroke", { Color = cor, Thickness = 3.5, Parent = contorno })
	Kit.circulo({
		BackgroundColor3 = cor,
		Size = UDim2.fromOffset(largura * 0.24, largura * 0.24),
		Position = UDim2.fromScale(0.5, 0.6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z,
		Parent = quadro,
	})
	-- Raios acima do olho
	for i, angulo in { -35, 0, 35 } do
		novo("Frame", {
			Name = "Raio" .. i,
			BackgroundColor3 = cor,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(3, largura * 0.12),
			Position = UDim2.new(0.5 + angulo / 140, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Rotation = angulo,
			ZIndex = z,
			Parent = quadro,
		})
	end
	return quadro
end

return Kit
