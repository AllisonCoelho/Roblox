-- Cartão de revelação das auras raras (categoria Alta para cima): nome, raridade real,
-- se é uma nova descoberta e as ações EQUIPAR / CONTINUAR.
-- As auras comuns não abrem cartão: o HUD mostra o nome acima do selo e no feed.
-- Durante a cena, um toque fora dos botões pula o ritual e vai direto para o cartão.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Tema = require(Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)

local Cores = Tema.Cores
local Revelacao = {}

export type Info = { quantidade: number, equipada: boolean, teste: boolean }
export type Opcoes = {
	aoEquipar: (auraId: string) -> (),
	aoPular: () -> (), -- pular o ritual/câmera em andamento
	aoMudar: (ativa: boolean) -> (),
}

local BARRA = 90

local camada: Frame
local barraCima: Frame
local barraBaixo: Frame
local faixa: Frame
local faixaNome: TextLabel
local selo: Frame
local seloEscala: UIScale
local seloTier: TextLabel
local seloChance: TextLabel
local seloContorno: UIStroke
local situacao: TextLabel
local botoes: Frame
local botaoEquipar: Kit.BotaoPlaca
local dica: TextLabel

local opcoes: Opcoes
local ativa = false
local cartaoAberto = false
local auraAtual: Auras.Aura? = nil
local token = 0

-- Momento em que a última cena terminou (o toque que fecha não deve virar um giro)
Revelacao.fimEm = 0

local function tween(
	obj: Instance,
	tempo: number,
	props: { [string]: any },
	estilo: Enum.EasingStyle?
)
	TweenService:Create(obj, TweenInfo.new(tempo, estilo or Enum.EasingStyle.Quad), props):Play()
end

function Revelacao.ativa(): boolean
	return ativa
end

function Revelacao.fechar()
	if not ativa then
		return
	end
	ativa = false
	cartaoAberto = false
	auraAtual = nil
	token += 1
	Revelacao.fimEm = os.clock()
	faixa.Visible = false
	selo.Visible = false
	situacao.Visible = false
	botoes.Visible = false
	dica.Visible = false
	tween(barraCima, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
	tween(barraBaixo, 0.25, { Size = UDim2.new(1, 0, 0, 0) })
	local meu = token
	task.delay(0.25, function()
		if token == meu then
			camada.Visible = false
		end
	end)
	opcoes.aoPular()
	task.spawn(opcoes.aoMudar, false)
end

-- Início da cena de uma aura rara: reserva a tela até o cartão fechar.
-- comBarras = câmera cinematográfica ligada (barras de cinema).
function Revelacao.cena(comBarras: boolean)
	token += 1
	ativa = true
	cartaoAberto = false
	camada.Visible = true
	faixa.Visible = false
	selo.Visible = false
	situacao.Visible = false
	botoes.Visible = false
	dica.Visible = true
	local altura = if comBarras then BARRA else 0
	tween(barraCima, 0.3, { Size = UDim2.new(1, 0, 0, altura) })
	tween(barraBaixo, 0.3, { Size = UDim2.new(1, 0, 0, altura) })
	task.spawn(opcoes.aoMudar, true)
end

-- Mostra o cartão no instante da revelação. Fecha sozinho depois de cat.cartao segundos.
function Revelacao.mostrar(aura: Auras.Aura, cat: Apresentacao.Categoria, info: Info)
	if not ativa then
		return
	end
	token += 1
	local meu = token
	cartaoAberto = true
	auraAtual = aura
	dica.Visible = false
	local tier = Auras.Tiers[aura.tier]
	local cor = Color3.fromHex(tier.cor)

	faixaNome.Text = string.upper(aura.nome)
	faixa.Visible = true
	faixa.Position = UDim2.fromScale(-0.8, 0.62)
	tween(faixa, 0.18, { Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Quart)

	seloTier.Text = string.upper(tier.nome)
	seloTier.TextColor3 = cor
	seloChance.Text = "1 em " .. Formato.chance(aura.chance)
	seloContorno.Color = cor
	selo.Visible = true
	seloEscala.Scale = 2.2
	tween(seloEscala, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)

	if info.teste then
		situacao.Text = "TESTE VISUAL · nada foi sorteado nem salvo"
	elseif info.quantidade <= 1 then
		situacao.Text = "NOVA DESCOBERTA!"
	else
		situacao.Text = string.format("Você já tem · x%s", Formato.inteiro(info.quantidade))
	end
	situacao.TextColor3 = if info.quantidade <= 1 and not info.teste
		then Cores.Ouro
		else Cores.Papel
	situacao.Visible = true

	botaoEquipar.placa.quadro.Visible = not info.teste and not info.equipada
	botoes.Visible = true

	task.delay(cat.cartao, function()
		if token == meu then
			Revelacao.fechar()
		end
	end)
end

function Revelacao.montar(raiz: Frame, op: Opcoes)
	opcoes = op
	camada = Kit.novo("Frame", {
		Name = "Revelacao",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = raiz,
	})
	barraCima = Kit.novo("Frame", {
		Name = "BarraCima",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 31,
		Parent = camada,
	})
	barraBaixo = Kit.novo("Frame", {
		Name = "BarraBaixo",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 31,
		Parent = camada,
	})

	-- Faixa vermelha inclinada com o nome
	faixa = Kit.novo("Frame", {
		Name = "Faixa",
		BackgroundColor3 = Cores.Selo,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(1.3, 0, 0, 140),
		Rotation = -6,
		Visible = false,
		ZIndex = 33,
		Parent = camada,
	})
	for _, cima in { true, false } do
		Kit.novo("Frame", {
			BackgroundColor3 = Cores.Papel,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, if cima then 0 else 1),
			Position = UDim2.fromScale(0, if cima then 0 else 1),
			Size = UDim2.new(1, 0, 0, 6),
			ZIndex = 34,
			Parent = faixa,
		})
	end
	faixaNome = Kit.texto({
		Name = "Nome",
		TextSize = 88,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 35,
		Parent = faixa,
	})
	Kit.novo("UIStroke", { Color = Cores.Tinta, Thickness = 4, Parent = faixaNome })

	-- Selo (carimbo) da raridade
	selo = Kit.circulo({
		Name = "Selo",
		BackgroundColor3 = Cores.Tinta,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 400, 0.47, 0),
		Size = UDim2.fromOffset(190, 190),
		Rotation = -14,
		Visible = false,
		ZIndex = 36,
		Parent = camada,
	})
	seloEscala = Kit.novo("UIScale", { Parent = selo })
	seloContorno = Kit.novo("UIStroke", { Thickness = 6, Parent = selo })
	seloTier = Kit.texto({
		fonte = "pincel",
		TextSize = 34,
		Position = UDim2.fromScale(0, 0.28),
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 37,
		Parent = selo,
	})
	seloChance = Kit.texto({
		fonte = "media",
		TextSize = 22,
		Position = UDim2.fromScale(0, 0.55),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 37,
		Parent = selo,
	})

	situacao = Kit.texto({
		Name = "Situacao",
		fonte = "pincel",
		TextSize = 30,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.62, 86),
		Size = UDim2.fromOffset(900, 40),
		Visible = false,
		ZIndex = 36,
		Parent = camada,
	})
	Kit.novo("UIStroke", { Color = Cores.Tinta, Thickness = 3, Parent = situacao })

	botoes = Kit.novo("Frame", {
		Name = "Botoes",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.62, 140),
		Size = UDim2.fromOffset(520, 70),
		Visible = false,
		ZIndex = 36,
		Parent = camada,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 24),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = botoes,
	})
	botaoEquipar = Kit.botaoPlaca({
		texto = "EQUIPAR",
		largura = 230,
		altura = 62,
		tamanhoTexto = 26,
		sombra = Cores.Selo,
		ordem = 1,
		z = 36,
		pai = botoes,
		aoClicar = function()
			local aura = auraAtual
			Revelacao.fechar()
			if aura then
				opcoes.aoEquipar(aura.id)
			end
		end,
	})
	botaoEquipar.definirAtivo(true)
	Kit.botaoPlaca({
		texto = "CONTINUAR",
		largura = 230,
		altura = 62,
		tamanhoTexto = 26,
		sombra = Color3.new(0, 0, 0),
		ordem = 2,
		z = 36,
		pai = botoes,
		aoClicar = Revelacao.fechar,
	})

	dica = Kit.texto({
		fonte = "media",
		Text = "toque para pular",
		TextSize = 18,
		TextColor3 = Cores.TextoSuave,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -BARRA - 12),
		Size = UDim2.fromOffset(240, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		ZIndex = 37,
		Parent = camada,
	})

	-- Toque durante o ritual (antes do cartão): pula direto para a revelação
	UserInputService.InputBegan:Connect(function(input)
		if not ativa or cartaoAberto then
			return
		end
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch then
			opcoes.aoPular()
		end
	end)
end

return Revelacao
