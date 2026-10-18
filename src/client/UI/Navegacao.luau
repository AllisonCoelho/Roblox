-- Abre e fecha os painéis (Loja, Álbum, etc.): só um aberto por vez, com fundo escurecido
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Tema = require(ReplicatedStorage.Shared.Tema)
local C = require(script.Parent.Componentes)
local Escala = require(script.Parent.Escala)

local Cores = Tema.Cores
local Navegacao = {}

local LARGURA_MAX = 1340
local ALTURA_MAX = 780

type Registro = { painel: Frame, escala: UIScale, aoAbrir: (() -> ())? }

local registros: { [string]: Registro } = {}
local aberto: string? = nil
local fundo: TextButton
local camada: Frame
local ouvintes: { (string?) -> () } = {}

function Navegacao.aoTrocar(fn: (string?) -> ())
	table.insert(ouvintes, fn)
end

function Navegacao.aberto(): string?
	return aberto
end

export type Painel = {
	quadro: Frame,
	cabecalho: Frame,
	conteudo: Frame,
	fechar: () -> (),
}

-- Cria o painel padrão: creme, contorno grosso, cabeçalho colorido, X vermelho
function Navegacao.criarPainel(
	nome: string,
	op: { titulo: string, icone: string, cor: string },
	aoAbrir: (() -> ())?
): Painel
	local quadro = C.novo("Frame", {
		Name = "Painel_" .. nome,
		BackgroundColor3 = Cores.Creme,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LARGURA_MAX, ALTURA_MAX),
		Visible = false,
		ClipsDescendants = true,
		Parent = camada,
	})
	C.cantos(quadro, 28)
	C.contorno(quadro, 5)
	local escala = C.novo("UIScale", { Parent = quadro })

	-- Fundo do cabeçalho: ClipsDescendants não recorta cantos arredondados, então o fundo
	-- tem cantos próprios em cima e um complemento reto embaixo (com o mesmo degradê)
	local cores = Tema.Botoes[op.cor] or Tema.Botoes.rosa
	local ALTURA, RETO = 76, 30
	local fundoCabecalho = C.novo("Frame", {
		Name = "FundoCabecalho",
		BackgroundColor3 = Cores.Branco,
		Size = UDim2.new(1, 0, 0, ALTURA),
		ZIndex = 1,
		Parent = quadro,
	})
	C.cantos(fundoCabecalho, 24)
	C.degrade(fundoCabecalho, cores[1], cores[2])
	local complemento = C.novo("Frame", {
		Name = "FundoCabecalhoReto",
		BackgroundColor3 = Cores.Branco,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, RETO),
		Position = UDim2.fromOffset(0, ALTURA - RETO),
		ZIndex = 1,
		Parent = quadro,
	})
	C.degrade(complemento, cores[1]:Lerp(cores[2], (ALTURA - RETO) / ALTURA), cores[2])
	local cabecalho = C.novo("Frame", {
		Name = "Cabecalho",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ALTURA),
		ZIndex = 2,
		Parent = quadro,
	})
	C.novo("Frame", {
		Name = "Linha",
		BackgroundColor3 = Cores.Contorno,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 5),
		Position = UDim2.new(0, 0, 1, 0),
		Parent = cabecalho,
	})
	C.emoji(op.icone, 38, {
		Position = UDim2.new(0, 18, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = cabecalho,
	})
	C.texto({
		Name = "Titulo",
		Text = op.titulo,
		TextSize = 36,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		Position = UDim2.new(0, 74, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cabecalho,
	})
	local fecharBotao = C.botao({
		cor = "vermelho",
		texto = "✕",
		tamanho = UDim2.fromOffset(56, 56),
		tamanhoTexto = 30,
		posicao = UDim2.new(1, -16, 0.5, -3),
		ancora = Vector2.new(1, 0.5),
		sombra = 4,
		pai = cabecalho,
		aoClicar = function()
			Navegacao.fechar()
		end,
	})
	fecharBotao.quadro.ZIndex = 3

	local conteudo = C.novo("Frame", {
		Name = "Conteudo",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -81),
		Position = UDim2.fromOffset(0, 81),
		Parent = quadro,
	})

	registros[nome] = { painel = quadro, escala = escala, aoAbrir = aoAbrir }
	return { quadro = quadro, cabecalho = cabecalho, conteudo = conteudo, fechar = Navegacao.fechar }
end

function Navegacao.abrir(nome: string)
	local r = registros[nome]
	if not r then
		return
	end
	if aberto and aberto ~= nome then
		registros[aberto].painel.Visible = false
	end
	aberto = nome
	fundo.Visible = true
	r.painel.Visible = true
	r.escala.Scale = 0.85
	TweenService:Create(r.escala, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if r.aoAbrir then
		task.spawn(r.aoAbrir)
	end
	for _, fn in ouvintes do
		task.spawn(fn, aberto)
	end
end

function Navegacao.alternar(nome: string)
	if aberto == nome then
		Navegacao.fechar()
	else
		Navegacao.abrir(nome)
	end
end

function Navegacao.fechar()
	if not aberto then
		return
	end
	registros[aberto].painel.Visible = false
	aberto = nil
	fundo.Visible = false
	for _, fn in ouvintes do
		task.spawn(fn, nil)
	end
end

-- Painéis encolhem em telas pequenas (celular) para caber
local function ajustarTamanhos()
	local w = math.min(LARGURA_MAX, Escala.tamanho.X - 40)
	local h = math.min(ALTURA_MAX, Escala.tamanho.Y - 30)
	for _, r in registros do
		r.painel.Size = UDim2.fromOffset(w, h)
	end
end

function Navegacao.montar(raiz: Frame)
	fundo = C.novo("TextButton", {
		Name = "FundoEscuro",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = raiz,
	})
	fundo.Activated:Connect(Navegacao.fechar)
	camada = C.novo("Frame", {
		Name = "Paineis",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 21,
		Parent = raiz,
	})
	Escala.aoMudar(ajustarTamanhos)
	UserInputService.InputBegan:Connect(function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.Escape then
			Navegacao.fechar()
		end
	end)
end

-- Chamado depois que todos os painéis foram criados
function Navegacao.ajustar()
	ajustarTamanhos()
end

return Navegacao
