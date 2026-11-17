-- Janelas da Órbita do Nexo, com cabeçalho fixo e uma janela ativa por vez.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Cores = require(ReplicatedStorage.Shared.Tema).Orbita
local Escala = require(script.Parent.Escala)
local Kit = require(script.Parent.Kit)

local Navegacao = {}
local aberto: string? = nil
local focoAnterior: GuiObject? = nil
local fundo: TextButton
local camada: Frame
local ouvintes: { (string?) -> () } = {}

export type Painel = {
	quadro: Frame,
	cabecalho: Frame,
	conteudo: Frame,
	fechar: () -> (),
}

type Registro = {
	painel: Painel,
	foco: TextButton,
	titulo: TextLabel,
	icone: TextLabel,
	aoAbrir: (() -> ())?,
	reserva: number,
	dimensoes: Vector2,
}

local registros: { [string]: Registro } = {}

function Navegacao.aoTrocar(fn: (string?) -> ())
	table.insert(ouvintes, fn)
end

function Navegacao.aberto(): string?
	return aberto
end

function Navegacao.fechar()
	local nome = aberto
	if not nome then
		return
	end
	local registro = registros[nome]
	local selecionado = GuiService.SelectedObject
	registro.painel.quadro.Visible = false
	aberto = nil
	fundo.Visible = false
	if selecionado and selecionado:IsDescendantOf(registro.painel.quadro) then
		GuiService.SelectedObject = if focoAnterior and focoAnterior.Parent
			then focoAnterior
			else nil
	end
	focoAnterior = nil
	for _, fn in ouvintes do
		task.spawn(fn, nil)
	end
end

function Navegacao.criarPainel(
	nome: string,
	op: {
		titulo: string,
		icone: string,
		reserva: number?,
		dimensoes: Vector2?,
	},
	aoAbrir: (() -> ())?
): Painel
	local dimensoes = op.dimensoes or Vector2.new(1120, 650)
	local placa = Kit.placa({
		nome = "Painel_" .. nome,
		tamanho = UDim2.fromOffset(dimensoes.X, dimensoes.Y),
		posicao = UDim2.fromScale(0.5, 0.5),
		ancora = Vector2.new(0.5, 0.5),
		corte = 16,
		pai = camada,
	})
	local quadro = placa.quadro
	quadro.Active = true
	quadro.Visible = false
	quadro.SelectionGroup = true
	quadro.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	quadro.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	quadro.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	quadro.SelectionBehaviorRight = Enum.SelectionBehavior.Stop

	local cabecalho = Kit.novo("Frame", {
		Name = "Cabecalho",
		BackgroundColor3 = Cores.Elevado,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(1, 10),
		Size = UDim2.new(1, -2, 0, 74),
		Parent = placa.conteudo,
	})
	Kit.novo("Frame", {
		BackgroundColor3 = Cores.Borda,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = cabecalho,
	})
	local icone = Kit.texto({
		Text = op.icone,
		TextColor3 = Cores.Lilas,
		TextSize = 26,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0, 30, 1, 0),
		Parent = cabecalho,
	})
	local titulo = Kit.texto({
		fonte = "titulo",
		Text = op.titulo,
		TextSize = 42,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(56, 0),
		Parent = cabecalho,
	})
	local fechar = Kit.botaoPlaca({
		texto = "×",
		tamanho = UDim2.fromOffset(66, 64),
		tamanhoTexto = 30,
		pai = cabecalho,
		aoClicar = Navegacao.fechar,
	})
	fechar.placa.quadro.AnchorPoint = Vector2.new(1, 0.5)
	fechar.placa.quadro.Position = UDim2.new(1, -10, 0.5, 0)
	fechar.botao.Text = "Fechar"

	local conteudo = Kit.novo("Frame", {
		Name = "Conteudo",
		BackgroundTransparency = 1,
		Parent = placa.conteudo,
	})
	local painel: Painel = {
		quadro = quadro,
		cabecalho = cabecalho,
		conteudo = conteudo,
		fechar = Navegacao.fechar,
	}
	registros[nome] = {
		painel = painel,
		foco = fechar.botao,
		titulo = titulo,
		icone = icone,
		aoAbrir = aoAbrir,
		reserva = op.reserva or 0,
		dimensoes = dimensoes,
	}
	return painel
end

function Navegacao.abrir(nome: string)
	local r = registros[nome]
	if not r or aberto == nome then
		return
	end
	local selecionado = GuiService.SelectedObject
	if aberto then
		registros[aberto].painel.quadro.Visible = false
	else
		focoAnterior = selecionado
	end
	aberto = nome
	fundo.Visible = true
	r.painel.quadro.Visible = true
	if Escala.controle or selecionado then
		GuiService.SelectedObject = r.foco
	end
	if r.aoAbrir then
		task.spawn(r.aoAbrir)
	end
	for _, fn in ouvintes do
		task.spawn(fn, nome)
	end
end

function Navegacao.alternar(nome: string)
	if aberto == nome then
		Navegacao.fechar()
	else
		Navegacao.abrir(nome)
	end
end

function Navegacao.ajustar()
	local compacto = Escala.compacto
	local altura = if compacto then 70 else 82
	for _, r in registros do
		local w = math.min(r.dimensoes.X, Escala.tamanho.X - 24)
		local h = math.min(r.dimensoes.Y, Escala.tamanho.Y - 24)
		local estreito = w < 520
		local x = if estreito then 16 else 56
		local painel = r.painel
		painel.quadro.Size = UDim2.fromOffset(w, h)
		painel.cabecalho.Size = UDim2.new(1, -2, 0, altura)
		painel.conteudo.Position = UDim2.fromOffset(0, altura + 10)
		painel.conteudo.Size = UDim2.new(1, 0, 1, -altura - 16)
		r.icone.Visible = not estreito
		r.titulo.Position = UDim2.fromOffset(x, 0)
		r.titulo.TextSize = if estreito then 26 elseif compacto then 30 else 42
		r.titulo.Size = UDim2.new(1, -(x + 86 + r.reserva), 1, 0)
	end
end

function Navegacao.montar(raiz: Frame)
	fundo = Kit.novo("TextButton", {
		Name = "FundoEscuro",
		Text = "",
		Selectable = false,
		AutoButtonColor = false,
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 0.34,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = raiz,
	})
	fundo.Activated:Connect(Navegacao.fechar)
	camada = Kit.novo("Frame", {
		Name = "Paineis",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 21,
		Parent = raiz,
	})
	Escala.aoMudar(function()
		Navegacao.ajustar()
		if aberto and Escala.controle and not GuiService.SelectedObject then
			GuiService.SelectedObject = registros[aberto].foco
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processado)
		local tecla = input.KeyCode
		if not processado and (tecla == Enum.KeyCode.Escape or tecla == Enum.KeyCode.ButtonB) then
			Navegacao.fechar()
		end
	end)
end

return Navegacao
