-- Bolsa (inventário) no estilo das mochilas dos jogos de aventura do Roblox: categorias na
-- lateral, grade de cartões com ícone, raridade e quantidade, e o item escolhido em destaque
-- no topo com descrição, receitas e o botão de equipar (artefatos).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Artefatos = require(Shared.Dados.Artefatos)
local Formato = require(Shared.Formato)
local Icones = require(Shared.Dados.Icones)
local Itens = require(Shared.Dados.Itens)
local Receitas = require(Shared.Dados.Receitas)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Inventario = {}
local FILTROS = { "Todos", "Materiais", "Artefatos", "Consumíveis", "Favoritos" }
local ICONE_FILTRO = {
	Todos = Icones.MENU.Bolsa,
	Materiais = 8,
	Artefatos = 10,
	["Consumíveis"] = 29,
	Favoritos = 27,
}
local COR_FILTRO = {
	Todos = Color3.fromHex("FF9A6A"),
	Materiais = Color3.fromHex("7FD8FF"),
	Artefatos = Color3.fromHex("C9A2FF"),
	["Consumíveis"] = Color3.fromHex("7BF0A0"),
	Favoritos = Color3.fromHex("FFD36B"),
}

local filtro = "Todos"
local porRecente = false
local selecionado: string? = nil
local favoritos: { [string]: boolean } = {}
local ordemRecente: { [string]: number } = {}
local ultimo = 0
local anterior: Itens.Estoque = {}
local estrutura: Cartoes.Estrutura
local abas: { [string]: Cartoes.Aba } = {}
local ordenar: Kit.BotaoPlaca
local aviso: (string) -> ()
local equipado: string? = nil
local equipando = false
local posicao = 0

local function proxima(): number
	posicao += 1
	return posicao
end

local function atualizar()
	if Navegacao.aberto() ~= "Inventario" then
		return
	end
	posicao = 0
	local lista = estrutura.lista
	for _, filho in lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	for nome, a in abas do
		a.definirAtiva(nome == filtro)
	end
	ordenar.rotulo.Text = if porRecente then "Mais recentes" else "Por raridade"

	-- item escolhido em destaque
	local sel = if selecionado and anterior[selecionado] then Itens.porId[selecionado] else nil
	if sel and selecionado then
		local id = selecionado
		local tier = Itens.Tiers[sel.raridade]
		local receitas: { string } = {}
		for _, receitaId in Receitas.ordem do
			local receita = Receitas.porId[receitaId]
			if receita.custo[id] then
				table.insert(receitas, Itens.porId[receita.resultado].nome)
			end
		end
		local ehArtefato = Artefatos.porId[id] ~= nil
		local corTier = Color3.fromHex(tier.cor)
		Cartoes.banner({
			pai = lista,
			ordem = proxima(),
			cor = corTier,
			icone = Icones.item(id, sel.categoria),
			titulo = string.format("%s  ×%s", sel.nome, Formato.curto(anterior[id])),
			texto = string.format(
				'<font color="#%s"><b>%s</b></font> · %s<br/>%s<br/><font color="#C9C7D6">Origem: %s · Uso: %s%s</font>',
				tier.cor,
				tier.nome,
				sel.categoria,
				sel.descricao,
				sel.origem,
				sel.uso,
				if #receitas > 0 then "<br/>Receitas: " .. table.concat(receitas, " · ") else ""
			),
			botao = if ehArtefato
				then (if equipado == id then "Desequipar" else "Equipar")
				else nil,
			corBotao = if equipado == id then Cores.Elevado else Cores.Lilas,
			aoClicar = if ehArtefato
				then function()
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
				end
				else nil,
			altura = 150,
		})
		local fav = Kit.botaoPlaca({
			texto = if favoritos[id] then "★ Remover favorito" else "☆ Favoritar",
			tamanho = UDim2.fromOffset(200, 38),
			tamanhoTexto = 15,
			pai = lista,
			ordem = proxima(),
			aoClicar = function()
				favoritos[id] = not favoritos[id]
				atualizar()
			end,
		})
		Cartoes.animarToque(fav.placa.quadro, fav.botao)
	end

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
		if porRecente and (ordemRecente[a] or 0) ~= (ordemRecente[b] or 0) then
			return (ordemRecente[a] or 0) > (ordemRecente[b] or 0)
		end
		local x, y = Itens.porId[a], Itens.porId[b]
		if x.raridade == y.raridade then
			return x.nome < y.nome
		end
		return x.raridade > y.raridade
	end)
	Cartoes.secao(lista, proxima(), filtro, string.format("%d itens", #ids))
	if #ids == 0 then
		Kit.texto({
			Text = if next(anterior) == nil
				then "Sua bolsa está vazia. Conclua andares de incursão no Bastião para receber seus primeiros materiais."
				else "Nenhum item nesta categoria.",
			TextSize = 18,
			TextColor3 = Cores.TextoSuave,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = proxima(),
			Parent = lista,
		})
		return
	end
	local grade = Cartoes.grade(lista, proxima(), Vector2.new(160, 206))
	for i, id in ids do
		local item = Itens.porId[id]
		local tier = Itens.Tiers[item.raridade]
		Cartoes.cartao({
			pai = grade,
			ordem = i,
			cor = Color3.fromHex(tier.cor),
			icone = Icones.item(id, item.categoria),
			titulo = item.nome,
			subtitulo = tier.nome,
			etiqueta = if equipado == id then "EQUIPADO" elseif favoritos[id] then "★" else nil,
			estado = if selecionado == id then "equipado" else "info",
			textoBotao = "×" .. Formato.curto(anterior[id]),
			aoClicar = function()
				selecionado = if selecionado == id then nil else id
				atualizar()
				if selecionado then
					estrutura.conteudo.CanvasPosition = Vector2.zero
				end
			end,
		})
	end
end

function Inventario.abrir()
	Navegacao.alternar("Inventario")
end

function Inventario.montar(aoAviso: (string) -> ())
	aviso = aoAviso
	local painel = Navegacao.criarPainel(
		"Inventario",
		{ titulo = "Bolsa", icone = Icones.MENU.Bolsa },
		atualizar
	)
	estrutura = Cartoes.estrutura(painel.conteudo)
	for i, nome in FILTROS do
		abas[nome] = Cartoes.aba(
			estrutura.lateral,
			i,
			nome,
			ICONE_FILTRO[nome],
			COR_FILTRO[nome],
			function()
				filtro = nome
				estrutura.conteudo.CanvasPosition = Vector2.zero
				atualizar()
			end
		)
	end
	ordenar = Kit.botaoPlaca({
		texto = "Por raridade",
		tamanho = UDim2.new(1, 0, 0, 42),
		tamanhoTexto = 15,
		pai = estrutura.lateral,
		ordem = #FILTROS + 1,
		aoClicar = function()
			porRecente = not porRecente
			atualizar()
		end,
	})

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
					ordemRecente[id] = ultimo
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
