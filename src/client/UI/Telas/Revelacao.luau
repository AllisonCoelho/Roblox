-- Cartão de revelação das auras raras. A apresentação continua dirigida por Mundo/Despertar.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Cores = require(Shared.Tema).Orbita
local Escala = require(script.Parent.Parent.Escala)
local Kit = require(script.Parent.Parent.Kit)

local Revelacao = {}

export type Info = { quantidade: number, equipada: boolean, teste: boolean }
export type Opcoes = {
	aoEquipar: (auraId: string) -> (),
	aoPular: () -> (),
	aoMudar: (ativa: boolean) -> (),
}

local camada: Frame
local fundo: TextButton
local barraCima: Frame
local barraBaixo: Frame
local grupo: CanvasGroup
local cartao: Kit.Placa
local gema: Frame
local nome: TextLabel
local tierTexto: TextLabel
local chance: TextLabel
local situacao: TextLabel
local equipar: Kit.BotaoPlaca
local continuar: Kit.BotaoPlaca
local pular: Kit.BotaoPlaca

local opcoes: Opcoes
local ativa = false
local cartaoAberto = false
local auraAtual: Auras.Aura? = nil
local focoAnterior: GuiObject? = nil
local token = 0
local transicao = 0

Revelacao.fimEm = 0

function Revelacao.ativa(): boolean
	return ativa
end

function Revelacao.fechar()
	if not ativa then
		return
	end
	local selecionado = GuiService.SelectedObject
	ativa = false
	cartaoAberto = false
	auraAtual = nil
	token += 1
	Revelacao.fimEm = os.clock()
	camada.Visible = false
	opcoes.aoPular()
	opcoes.aoMudar(false)
	if selecionado and selecionado:IsDescendantOf(camada) then
		GuiService.SelectedObject = if focoAnterior and focoAnterior.Parent then focoAnterior else nil
	end
	focoAnterior = nil
end

function Revelacao.cena(comBarras: boolean, duracaoTransicao: number)
	token += 1
	if not ativa then
		focoAnterior = GuiService.SelectedObject
	end
	ativa = true
	cartaoAberto = false
	transicao = duracaoTransicao
	camada.Visible = true
	grupo.Visible = false
	fundo.BackgroundTransparency = 1
	pular.placa.quadro.Visible = transicao > 0
	local altura = if comBarras then 66 else 0
	barraCima.Size = UDim2.new(1, 0, 0, altura)
	barraBaixo.Size = UDim2.new(1, 0, 0, altura)
	opcoes.aoMudar(true)
	if pular.placa.quadro.Visible and (Escala.controle or focoAnterior) then
		GuiService.SelectedObject = pular.botao
	end
end

function Revelacao.mostrar(aura: Auras.Aura, cat: Apresentacao.Categoria, info: Info)
	if not ativa then
		return
	end
	token += 1
	local meu = token
	cartaoAberto = true
	auraAtual = aura
	pular.placa.quadro.Visible = false

	local tier = Auras.Tiers[aura.tier]
	local cor = Color3.fromHex(tier.cor)
	cartao.definirCor(Cores.Painel, cor)
	gema.BackgroundColor3 = cor
	nome.Text = aura.nome
	tierTexto.Text = tier.nome
	tierTexto.TextColor3 = Kit.corLegivel(cor)
	chance.Text = "1 em " .. Formato.chance(aura.chance)

	if info.teste then
		situacao.Text = "Teste visual"
	elseif info.quantidade <= 1 then
		situacao.Text = "Nova descoberta"
	else
		situacao.Text = "Você já tem ×" .. Formato.inteiro(info.quantidade)
	end
	situacao.TextColor3 = if info.quantidade <= 1 and not info.teste
		then Kit.corLegivel(cor)
		else Cores.TextoSuave

	equipar.placa.quadro.Visible = not info.teste and not info.equipada
	fundo.BackgroundTransparency = 0.76
	grupo.GroupTransparency = if transicao > 0 then 1 else 0
	grupo.Visible = true
	if transicao > 0 then
		TweenService:Create(grupo, TweenInfo.new(transicao), { GroupTransparency = 0 }):Play()
	end
	if Escala.controle or focoAnterior then
		GuiService.SelectedObject = continuar.botao
	end
	task.delay(cat.cartao, function()
		if token == meu then
			Revelacao.fechar()
		end
	end)
end

local function faixa(pai: Frame, y: number): Frame
	return Kit.novo("Frame", {
		BackgroundColor3 = Cores.Fundo,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, y),
		Position = UDim2.fromScale(0, y),
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 2,
		Parent = pai,
	})
end

function Revelacao.montar(raiz: Frame, op: Opcoes)
	opcoes = op
	camada = Kit.novo("Frame", {
		Name = "Revelacao",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
		SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
		SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		ZIndex = 30,
		Parent = raiz,
	})
	fundo = Kit.novo("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = camada,
	})
	fundo.Activated:Connect(function()
		if ativa and not cartaoAberto then
			opcoes.aoPular()
		end
	end)
	barraCima = faixa(camada, 0)
	barraBaixo = faixa(camada, 1)
	grupo = Kit.novo("CanvasGroup", {
		Name = "Cartao",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(660, 286),
		Visible = false,
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = camada,
	})
	cartao = Kit.placa({ tamanho = UDim2.fromScale(1, 1), pai = grupo, corte = 16 })
	local conteudo = cartao.conteudo

	local cristal
	cristal, gema = Kit.cristal(conteudo, 48, Cores.Lilas)
	cristal.AnchorPoint = Vector2.new(0.5, 0)
	cristal.Position = UDim2.new(0.5, 0, 0, 10)
	situacao = Kit.texto({
		TextSize = 16,
		TextColor3 = Cores.TextoSuave,
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 0, 26),
		Parent = conteudo,
	})
	nome = Kit.texto({
		fonte = "titulo",
		TextSize = 48,
		TextWrapped = true,
		Position = UDim2.fromOffset(12, 84),
		Size = UDim2.new(1, -24, 1, -196),
		Parent = conteudo,
	})
	tierTexto = Kit.texto({
		fonte = "titulo",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0, 8, 1, -111),
		Size = UDim2.new(0.5, -19, 0, 29),
		Parent = conteudo,
	})
	chance = Kit.texto({
		fonte = "mono",
		TextSize = 18,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0.5, 11, 1, -111),
		Size = UDim2.new(0.5, -19, 0, 29),
		Parent = conteudo,
	})

	local acoes = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, 64),
		Parent = conteudo,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = acoes,
	})
	continuar = Kit.botaoPlaca({
		texto = "Continuar",
		tamanho = UDim2.fromOffset(174, 64),
		ordem = 1,
		pai = acoes,
		aoClicar = Revelacao.fechar,
	})
	equipar = Kit.botaoPlaca({
		texto = "Equipar",
		tamanho = UDim2.fromOffset(174, 64),
		tom = "lilas",
		ordem = 2,
		pai = acoes,
		aoClicar = function()
			local aura = auraAtual
			Revelacao.fechar()
			if aura then
				opcoes.aoEquipar(aura.id)
			end
		end,
	})
	pular = Kit.botaoPlaca({
		texto = "Pular ritual",
		tamanho = UDim2.fromOffset(164, 64),
		pai = camada,
		aoClicar = opcoes.aoPular,
	})
	pular.placa.quadro.AnchorPoint = Vector2.new(1, 1)
	pular.placa.quadro.ZIndex = 3

	Escala.aoMudar(function()
		local w = math.min(660, Escala.tamanho.X - 36)
		local h = if Escala.compacto then 254 else 286
		grupo.Size = UDim2.fromOffset(w, h)
		nome.TextSize = if Escala.compacto then 32 else 48
		local larguraBotao = math.min(174, math.floor((w - 40) * 0.5))
		continuar.placa.quadro.Size = UDim2.fromOffset(larguraBotao, 64)
		equipar.placa.quadro.Size = UDim2.fromOffset(larguraBotao, 64)
		pular.placa.quadro.Position = UDim2.new(1, -18, 1, if Escala.toque then -112 else -26)
		pular.rotulo.Text = if Escala.teclado then "Pular ritual [E]" else "Pular ritual"
	end)
	UserInputService.InputBegan:Connect(function(input, tratado)
		if not tratado and ativa and input.KeyCode == Enum.KeyCode.ButtonB then
			if cartaoAberto then
				Revelacao.fechar()
			else
				opcoes.aoPular()
			end
		end
	end)
end

return Revelacao
