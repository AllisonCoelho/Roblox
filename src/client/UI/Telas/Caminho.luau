-- Trilha do caminho no HUD (regras em Dados/PrimeirosMinutos): GIRAR → EVOLUIR → CORREDOR →
-- ARENA → EVENTO. O que já foi feito fica verde, o próximo passo pulsa em dourado e o resto fica
-- apagado. Tocar numa etapa mostra o que fazer e abre o painel certo. Some quando tudo foi feito.
-- O tutorial da Lume destaca esta trilha (nome "Caminho" no HUD).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local PrimeirosMinutos = require(Shared.Dados.PrimeirosMinutos)
local Cores = require(Shared.Tema).Orbita
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)

local Caminho = {}

local FEITO = Color3.fromHex("5BE37D")
local ATUAL = Color3.fromHex("FFD54A")
local APAGADO = Color3.fromHex("605682")

export type Acoes = { [string]: (() -> ())? }

function Caminho.montar(hud: GuiObject, aviso: (string) -> (), acoes: Acoes)
	local etapas = PrimeirosMinutos.ETAPAS
	local quadro = Kit.placa({
		nome = "Caminho",
		tamanho = UDim2.fromOffset(336, 46),
		posicao = UDim2.fromOffset(22, 116),
		corte = 10,
		pai = hud,
	})
	local lista = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		Parent = quadro.conteudo,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = lista,
	})
	type Item = { botao: TextButton, ponto: Frame, rotulo: TextLabel, escala: UIScale }
	local itens: { Item } = {}
	for i, e in etapas do
		if i > 1 then
			Kit.texto({
				Text = "›",
				TextSize = 16,
				TextColor3 = Cores.TextoSuave,
				Size = UDim2.fromOffset(8, 30),
				LayoutOrder = i * 2 - 1,
				Parent = lista,
			})
		end
		local botao = Kit.novo("TextButton", {
			Name = "Etapa_" .. e.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(58, 34),
			LayoutOrder = i * 2,
			Parent = lista,
		}) :: TextButton
		local escala = Kit.novo("UIScale", { Parent = botao }) :: UIScale
		local ponto = Kit.novo("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 1),
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = APAGADO,
			Parent = botao,
		}) :: Frame
		Kit.novo("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = ponto })
		local rotulo = Kit.texto({
			fonte = "titulo",
			Text = e.nome,
			TextSize = 12,
			TextColor3 = APAGADO,
			Position = UDim2.fromOffset(0, 15),
			Size = UDim2.new(1, 0, 0, 18),
			Parent = botao,
		})
		botao.Activated:Connect(function()
			aviso(string.format("%s: %s", e.nome, e.dica))
			local acao = acoes[e.id]
			if acao then
				acao()
			end
		end)
		itens[i] = { botao = botao, ponto = ponto, rotulo = rotulo, escala = escala }
	end

	local progresso = PrimeirosMinutos.progresso(nil)
	local function atualizar(estado: any)
		progresso = PrimeirosMinutos.progresso(estado)
		quadro.quadro.Visible = not progresso.completo
		for i, item in itens do
			local cor = if progresso.feitas[i]
				then FEITO
				elseif progresso.atual == i then ATUAL
				else APAGADO
			item.ponto.BackgroundColor3 = cor
			item.rotulo.TextColor3 = if progresso.feitas[i]
				then FEITO
				elseif progresso.atual == i then Color3.new(1, 1, 1)
				else APAGADO
		end
	end
	Estado.aoMudar(atualizar)
	-- o próximo passo pulsa
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for i, item in itens do
			item.escala.Scale = if progresso.atual == i then 1 + 0.08 * math.sin(t * 5) else 1
		end
	end)
end

return Caminho
