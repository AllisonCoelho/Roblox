local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Itens = require(Shared.Dados.Itens)
local Cores = require(Shared.Tema).Orbita
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Inventario = {}
local FILTROS = { "Todos", "Materiais", "Artefatos", "Consumíveis", "Favoritos" }
local filtro = "Todos"
local porRecente = false
local selecionado: string? = nil
local favoritos: { [string]: boolean } = {}
local ordem: { [string]: number } = {}
local ultimo = 0
local anterior: Itens.Estoque = {}
local lista: Frame
local filtros: { Kit.BotaoPlaca } = {}
local ordenar: Kit.BotaoPlaca

local function linha(texto: string, pai: Instance, cor: Color3?)
	return Kit.texto({
		Text = texto,
		TextColor3 = cor or Cores.Texto,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -12, 0, 0),
		Parent = pai,
	})
end

local function atualizar()
	if Navegacao.aberto() ~= "Inventario" then
		return
	end
	for _, filho in lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	for i, botao in filtros do
		botao.definirTom(if FILTROS[i] == filtro then "lilas" else "neutro")
	end
	ordenar.rotulo.Text = if porRecente then "Mais recentes" else "Por raridade"
	local ids: { string } = {}
	for id in anterior do
		local item = Itens.porId[id]
		if
			item
			and (
				filtro == "Todos"
				or filtro == item.categoria
				or (filtro == "Favoritos" and favoritos[id])
			)
		then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		if porRecente and (ordem[a] or 0) ~= (ordem[b] or 0) then
			return (ordem[a] or 0) > (ordem[b] or 0)
		end
		local x, y = Itens.porId[a], Itens.porId[b]
		if x.raridade == y.raridade then
			return x.nome < y.nome
		end
		return x.raridade > y.raridade
	end)
	if #ids == 0 then
		linha(
			if next(anterior) == nil
				then "Seu inventário está vazio. Conclua andares de incursão no Bastião para receber seus primeiros materiais."
				else "Nenhum item nesta categoria.",
			lista,
			Cores.TextoSuave
		)
		return
	end
	for _, id in ids do
		local item = Itens.porId[id]
		local tier = Itens.Tiers[item.raridade]
		local cor = Color3.fromHex(tier.cor)
		local botao = Kit.botaoPlaca({
			texto = string.format(
				"%s  %s  ·  %s  ×%d",
				tier.icone,
				item.nome,
				tier.nome,
				anterior[id]
			),
			tamanho = UDim2.new(1, -12, 0, 52),
			tamanhoTexto = 16,
			pai = lista,
			aoClicar = function()
				selecionado = if selecionado == id then nil else id
				atualizar()
			end,
		})
		botao.rotulo.TextColor3 = Kit.corLegivel(cor)
		botao.rotulo.TextWrapped = true
		if selecionado == id then
			linha(item.descricao, lista)
			linha(
				"Origem  ·  " .. item.origem .. "\nUso  ·  " .. item.uso,
				lista,
				Cores.TextoSuave
			)
			Kit.botaoPlaca({
				texto = if favoritos[id] then "Remover favorito" else "Favoritar",
				tamanho = UDim2.fromOffset(180, 42),
				tamanhoTexto = 16,
				pai = lista,
				aoClicar = function()
					favoritos[id] = not favoritos[id]
					atualizar()
				end,
			})
		end
	end
end

function Inventario.abrir()
	Navegacao.alternar("Inventario")
end

function Inventario.montar()
	local painel =
		Navegacao.criarPainel("Inventario", { titulo = "Inventário", icone = "◇" }, atualizar)
	local barra: Frame = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 94),
		Parent = painel.conteudo,
	})
	Kit.novo("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -4, 0, 42),
		CellPadding = UDim2.fromOffset(6, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = barra,
	})
	for i, nome in FILTROS do
		local botao = Kit.botaoPlaca({
			texto = nome,
			tamanho = UDim2.new(),
			tamanhoTexto = 16,
			pai = barra,
			aoClicar = function()
				filtro = nome
				atualizar()
			end,
		})
		botao.placa.quadro.LayoutOrder = i
		filtros[i] = botao
	end
	ordenar = Kit.botaoPlaca({
		texto = "Por raridade",
		tamanho = UDim2.new(),
		tamanhoTexto = 16,
		pai = barra,
		aoClicar = function()
			porRecente = not porRecente
			atualizar()
		end,
	})
	ordenar.placa.quadro.LayoutOrder = #FILTROS + 1
	local rolagem = Kit.rolagem(painel.conteudo)
	rolagem.Position = UDim2.fromOffset(12, 106)
	rolagem.Size = UDim2.new(1, -24, 1, -110)
	lista = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = rolagem,
	})
	Kit.novo("UIListLayout", { Padding = UDim.new(0, 6), Parent = lista })

	Estado.aoMudar(function(estado)
		local novo = estado.inventario.itens
		local mudou = false
		for id, qtd in novo do
			if qtd ~= anterior[id] then
				mudou = true
				if qtd > (anterior[id] or 0) then
					ultimo += 1
					ordem[id] = ultimo
				end
			end
		end
		for id in anterior do
			mudou = mudou or novo[id] == nil
		end
		anterior = novo
		if mudou then
			atualizar()
		end
	end)
end

return Inventario
