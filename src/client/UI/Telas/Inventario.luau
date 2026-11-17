local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formato = require(Shared.Formato)
local Artefatos = require(Shared.Dados.Artefatos)
local Icones = require(Shared.Dados.Icones)
local Itens = require(Shared.Dados.Itens)
local Receitas = require(Shared.Dados.Receitas)
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
local aviso: (string) -> ()
local equipado: string? = nil
local equipando = false
local posicaoLista = 0

local function proximaPosicao(): number
	posicaoLista += 1
	return posicaoLista
end

local function linha(texto: string, pai: Instance, cor: Color3?)
	return Kit.texto({
		Text = texto,
		TextColor3 = cor or Cores.Texto,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -12, 0, 0),
		LayoutOrder = proximaPosicao(),
		Parent = pai,
	})
end

local function atualizar()
	if Navegacao.aberto() ~= "Inventario" then
		return
	end
	posicaoLista = 0
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
	-- Grade de ícones (cor da raridade, símbolo do item e quantidade)
	local grade = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -12, 0, 0),
		LayoutOrder = proximaPosicao(),
		Parent = lista,
	})
	Kit.novo("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 116),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grade,
	})
	for ordemItem, id in ids do
		local item = Itens.porId[id]
		local tier = Itens.Tiers[item.raridade]
		local cor = Color3.fromHex(tier.cor)
		local placa =
			Kit.placa({ tamanho = UDim2.new(), corte = 16, ordem = ordemItem, pai = grade })
		placa.definirCor(
			Color3.new(1, 1, 1),
			if selecionado == id then Color3.new(1, 1, 1) else Cores.Borda
		)
		local grad = placa.quadro:FindFirstChildOfClass("UIGradient")
		if grad then
			grad.Color = ColorSequence.new(cor:Lerp(Cores.Painel, 0.25), cor:Lerp(Cores.Borda, 0.6))
		end
		Kit.texto({
			Text = Icones.item(id, item.categoria),
			TextSize = 40,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 40),
			Size = UDim2.fromOffset(70, 50),
			ZIndex = 4,
			Parent = placa.conteudo,
		})
		Kit.texto({
			fonte = "titulo",
			Text = item.nome,
			TextSize = 13,
			TextWrapped = true,
			Position = UDim2.new(0, 4, 1, -38),
			Size = UDim2.new(1, -8, 0, 34),
			ZIndex = 4,
			Parent = placa.conteudo,
		})
		Kit.texto({
			fonte = "mono",
			Text = "×" .. Formato.curto(anterior[id]),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0, 0, 0, 4),
			Size = UDim2.new(1, -8, 0, 18),
			ZIndex = 5,
			Parent = placa.conteudo,
		})
		if equipado == id then
			Kit.texto({
				Text = "✅",
				TextSize = 16,
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.fromOffset(20, 20),
				ZIndex = 5,
				Parent = placa.conteudo,
			})
		end
		local alvo = Kit.alvo(placa.quadro, item.nome, function()
			selecionado = if selecionado == id then nil else id
			atualizar()
		end)
		Kit.animarToque(placa.quadro, alvo)
	end
	for _, id in ids do
		local item = Itens.porId[id]
		local tier = Itens.Tiers[item.raridade]
		local cor = Color3.fromHex(tier.cor)
		if selecionado == id then
			linha(
				string.format(
					"%s  %s  ·  %s  ×%d",
					Icones.item(id, item.categoria),
					item.nome,
					tier.nome,
					anterior[id]
				),
				lista,
				Kit.corLegivel(cor)
			)
			linha(item.descricao, lista)
			linha(
				"Origem  ·  " .. item.origem .. "\nUso  ·  " .. item.uso,
				lista,
				Cores.TextoSuave
			)
			local receitas: { string } = {}
			for _, receitaId in Receitas.ordem do
				local receita = Receitas.porId[receitaId]
				if receita.custo[id] then
					table.insert(receitas, Itens.porId[receita.resultado].nome)
				end
			end
			if #receitas > 0 then
				linha("Receitas  ·  " .. table.concat(receitas, " · "), lista, Cores.TextoSuave)
			end
			if Artefatos.porId[id] then
				Kit.botaoPlaca({
					texto = if equipado == id then "Desequipar artefato" else "Equipar artefato",
					tamanho = UDim2.fromOffset(180, 44),
					tamanhoTexto = 16,
					pai = lista,
					ordem = proximaPosicao(),
					tom = "lilas",
					aoClicar = function()
						if equipando then
							return
						end
						equipando = true
						local alvo = if equipado == id then "" else id
						task.spawn(function()
							local _, mensagem = Estado.pedir("EquiparArtefato", alvo)
							equipando = false
							if mensagem then
								aviso(mensagem)
							end
						end)
					end,
				})
			end
			Kit.botaoPlaca({
				texto = if favoritos[id] then "Remover favorito" else "Favoritar",
				tamanho = UDim2.fromOffset(180, 42),
				tamanhoTexto = 16,
				pai = lista,
				ordem = proximaPosicao(),
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

function Inventario.montar(aoAviso: (string) -> ())
	aviso = aoAviso
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
	Kit.novo(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lista }
	)

	Estado.aoMudar(function(estado)
		local novo = estado.inventario.itens
		local artefato = estado.inventario.equipados.artefato
		local mudou = artefato ~= equipado
		equipado = artefato
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
