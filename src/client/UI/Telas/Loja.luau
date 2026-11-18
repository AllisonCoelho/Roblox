-- Loja do Nexo no estilo das lojas dos jogos de aventura do Roblox: abas laterais com ícone,
-- cartões em grade com preço em Robux, trilha horizontal do Passe de Temporada e coleção de
-- cosméticos (os que faltam aparecem bloqueados com a origem). Compra, resgate e equipar são
-- pedidos ao servidor; aqui só mostramos o estado.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmeticos = require(Shared.Dados.Cosmeticos)
local Icones = require(Shared.Dados.Icones)
local Monetizacao = require(Shared.Dados.Monetizacao)
local Temporada = require(Shared.Dados.Temporada)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local IconeImagem = require(script.Parent.Parent.IconeImagem)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Loja = {}

type Opcoes = {
	aviso: (string) -> (),
	oferecer: (string) -> (),
	temPasse: (string) -> boolean,
}

local ABAS = { "Temporada", "Pacotes", "Cosméticos" }
local ICONE_ABA =
	{ Temporada = Icones.MENU.Temporada, Pacotes = Icones.MENU.Loja, ["Cosméticos"] = 33 }
local COR_ABA = {
	Temporada = Color3.fromHex("FF8BD8"),
	Pacotes = Color3.fromHex("FFC83D"),
	["Cosméticos"] = Color3.fromHex("7FD8FF"),
}
local NOMES_TIPO = { titulo = "Título", distintivo = "Distintivo", rastro = "Rastro" }
local FILTROS = { "Todos", "Títulos", "Distintivos", "Rastros" }
local FILTRO_TIPO = { ["Títulos"] = "titulo", Distintivos = "distintivo", Rastros = "rastro" }

-- Vitrine dos pacotes: ícone, selo e cor de cada produto
local PACOTES = {
	{ id = "iniciante", icone = 28, etiqueta = "INICIANTE", cor = Color3.fromHex("7BF0A0") },
	{ id = "vip", icone = 33, etiqueta = "MAIS POPULAR", cor = Color3.fromHex("FFD36B") },
	{
		id = "passeTemporada",
		icone = Icones.MENU.Temporada,
		etiqueta = "PREMIUM",
		cor = Color3.fromHex("FF8BD8"),
	},
}

local op: Opcoes
local aba = "Temporada"
local filtro = "Todos"
local estrutura: Cartoes.Estrutura
local abas: { [string]: Cartoes.Aba } = {}
local ordem = 0
local ocupado = false

-- nível e trilha da Temporada que entregam cada cosmético (para mostrar a origem)
local origemTemporada: { [string]: { nivel: number, trilha: string } } = {}
for n, r in Temporada.RECOMPENSAS do
	for trilha, id in r :: any do
		origemTemporada[id] = { nivel = n, trilha = trilha }
	end
end

local function proxima(): number
	ordem += 1
	return ordem
end

local function pedir(acao: string, ...: any)
	if ocupado then
		return
	end
	ocupado = true
	local args = table.pack(...)
	task.spawn(function()
		local _, msg = Estado.pedir(acao, table.unpack(args, 1, args.n))
		ocupado = false
		if msg then
			op.aviso(msg)
		end
	end)
end

local function iconeCosmetico(item: Cosmeticos.Item): number
	return Icones.DISTINTIVOS[item.id]
		or (if item.origem == "vip" then 33 else nil)
		or (if item.tipo == "titulo" then 18 elseif item.tipo == "rastro" then 35 else 36)
end

local function origemTexto(item: Cosmeticos.Item): string
	local t = origemTemporada[item.id]
	if t then
		return string.format(
			"Temporada · Nv %d%s",
			t.nivel,
			if t.trilha == "premium" then " · Premium" else ""
		)
	end
	local produto = Monetizacao.porId[item.origem]
	return if produto then produto.nome else "Evento"
end

local function texto(pai: Instance, props: { [string]: any }): TextLabel
	props.Parent = pai
	return Kit.texto(props)
end

-- ===================================================================== Temporada

local function tileRecompensa(
	pai: Instance,
	y: number,
	id: string,
	premium: boolean,
	estado: string,
	aoClicar: () -> ()
)
	local item = Cosmeticos.porId[id]
	local cor = if premium then Cartoes.OURO else Cores.Lilas
	local resgatado = estado == "resgatado"
	local pode = estado == "resgatar"
	local p = Kit.placa({
		tamanho = UDim2.fromOffset(112, 112),
		posicao = UDim2.fromOffset(9, y),
		fundo = if pode then cor:Lerp(Cores.Painel, 0.7) else Cores.Painel,
		borda = if pode or resgatado then cor else Cores.Borda,
		corte = 10,
		pai = pai,
	})
	local imagem = IconeImagem.criar(
		p.conteudo,
		iconeCosmetico(item),
		UDim2.new(0.5, -28, 0, 8),
		UDim2.fromOffset(56, 56)
	)
	if estado == "bloqueado" or estado == "futuro" then
		imagem.ImageTransparency = 0.5
	end
	texto(p.conteudo, {
		Text = item.nome,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Color3.fromHex(item.cor),
		Position = UDim2.fromOffset(4, 64),
		Size = UDim2.new(1, -8, 0, 28),
	})
	local rodape = if resgatado
		then "✓"
		elseif estado == "bloqueado" then "PREMIUM"
		elseif pode then "RESGATAR"
		else ""
	texto(p.conteudo, {
		fonte = "titulo",
		Text = rodape,
		TextSize = 13,
		TextColor3 = if resgatado then Cores.Menta elseif pode then cor else Cartoes.OURO,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 16),
	})
	if resgatado then
		IconeImagem.criar(p.conteudo, 12, UDim2.new(1, -28, 0, 4), UDim2.fromOffset(24, 24))
	elseif estado == "bloqueado" then
		IconeImagem.criar(p.conteudo, 11, UDim2.new(1, -28, 0, 4), UDim2.fromOffset(24, 24))
	end
	local alvo = Kit.alvo(p.quadro, item.nome, aoClicar)
	Cartoes.animarToque(p.quadro, alvo)
end

local function mostrarTemporada(estado: any)
	local lista = estrutura.lista
	local t = Temporada.de(estado.temporada and table.clone(estado.temporada) or nil)
	local premium = op.temPasse("passeTemporada")
	local agora = Estado.agora()
	local nivel = Temporada.nivel(t.xp)
	local maximo = nivel >= Temporada.NIVEIS
	local resto = t.xp - nivel * Temporada.XP_POR_NIVEL
	local prazo = if Temporada.ativa(agora)
		then string.format(
			"Termina em %d dias",
			math.max(0, math.ceil((Temporada.FIM - agora) / 86400))
		)
		elseif agora < Temporada.INICIO then "Começa em breve"
		else "Encerrada: resgate o que já alcançou"
	local produto = Monetizacao.porId.passeTemporada
	local banner = Cartoes.banner({
		pai = lista,
		ordem = proxima(),
		cor = COR_ABA.Temporada,
		icone = Icones.MENU.Temporada,
		titulo = Temporada.NOME,
		texto = string.format(
			"<b>Nível %d / %d</b>  ·  %s<br/>%s",
			nivel,
			Temporada.NIVEIS,
			if maximo
				then "completo!"
				else string.format("%d / %d XP", math.floor(resto), Temporada.XP_POR_NIVEL),
			prazo
		),
		botao = if premium then "Premium ✓" else Cartoes.ROBUX .. " " .. produto.preco,
		corBotao = if premium then Cores.Menta else Cartoes.OURO,
		aoClicar = if premium
			then nil
			else function()
				op.oferecer("passeTemporada")
			end,
		altura = 132,
	})
	Cartoes.barra(
		banner.conteudo,
		COR_ABA.Temporada,
		if maximo then 1 else resto / Temporada.XP_POR_NIVEL,
		UDim2.new(0, 118, 1, -22),
		UDim2.new(1, -366, 0, 10)
	)

	-- Trilha: uma coluna por nível com recompensa (grátis em cima, premium embaixo)
	Cartoes.secao(lista, proxima(), "Recompensas", "Grátis em cima · Premium embaixo")
	local niveis = {}
	for n in Temporada.RECOMPENSAS do
		table.insert(niveis, n)
	end
	table.sort(niveis)
	local trilha = Kit.rolagem(lista)
	trilha.Position = UDim2.new()
	trilha.Size = UDim2.new(1, 0, 0, 312)
	trilha.LayoutOrder = proxima()
	trilha.ScrollingDirection = Enum.ScrollingDirection.X
	trilha.AutomaticCanvasSize = Enum.AutomaticSize.X
	trilha.ScrollBarThickness = 8
	local linhaTrilha = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, -10),
		Parent = trilha,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = linhaTrilha,
	})
	local primeiroPendente: number? = nil
	for i, n in niveis do
		local r = Temporada.RECOMPENSAS[n] :: any
		local alcancado = nivel >= n
		local coluna = Kit.novo("Frame", {
			BackgroundColor3 = if alcancado then Cores.Elevado else Cores.Fundo,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(130, 300),
			LayoutOrder = i,
			Parent = linhaTrilha,
		})
		local selo = Kit.circulo({
			BackgroundColor3 = if alcancado then COR_ABA.Temporada else Cores.Elevado,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.fromOffset(44, 44),
			Parent = coluna,
		})
		Kit.novo("UIStroke", { Color = Cores.Borda, Thickness = 2, Parent = selo })
		texto(selo, {
			fonte = "mono",
			Text = tostring(n),
			TextSize = 18,
			TextColor3 = if alcancado then Cores.Fundo else Cores.TextoSuave,
			Size = UDim2.fromScale(1, 1),
		})
		for _, info in { { "gratis", 58 }, { "premium", 180 } } do
			local nomeTrilha, y = info[1], info[2]
			local id = r[nomeTrilha]
			if id then
				local resgatado = t.resgates[nomeTrilha][tostring(n)] == true
				local bloqueado = nomeTrilha == "premium" and not premium
				local estadoTile = if resgatado
					then "resgatado"
					elseif bloqueado then "bloqueado"
					elseif alcancado then "resgatar"
					else "futuro"
				if estadoTile == "resgatar" and not primeiroPendente then
					primeiroPendente = i
				end
				tileRecompensa(coluna, y, id, nomeTrilha == "premium", estadoTile, function()
					if bloqueado then
						op.oferecer("passeTemporada")
					elseif estadoTile == "resgatar" then
						pedir("ResgatarTemporada", n, nomeTrilha)
					else
						op.aviso(string.format("Alcance o nível %d da Temporada.", n))
					end
				end)
			end
		end
	end
	-- começa mostrando a primeira recompensa para resgatar (ou o nível atual)
	local foco = primeiroPendente or 1
	for i, n in niveis do
		if not primeiroPendente and n <= nivel then
			foco = i
		end
	end
	trilha.CanvasPosition = Vector2.new(math.max(0, (foco - 2) * 136), 0)

	Cartoes.secao(lista, proxima(), "Como ganhar XP")
	texto(lista, {
		Text = string.format(
			"Giro de aura <b>+%d</b> (até %d por dia)   ·   Andar de Incursão <b>+%d</b>   ·   Vitória <b>+%d</b>%s",
			Temporada.XP.giro,
			Temporada.TETO_GIRO_DIA,
			Temporada.XP.andar,
			Temporada.XP.vitoria,
			if op.temPasse("vip") then "   ·   VIP <b>+10%</b>" else ""
		),
		RichText = true,
		TextSize = 16,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = proxima(),
	})
end

-- ===================================================================== Pacotes

local function mostrarPacotes()
	local lista = estrutura.lista
	Cartoes.secao(lista, proxima(), "Pacotes", "Só aparência: nada muda chance de aura nem poder")
	local grade = Cartoes.grade(lista, proxima(), Vector2.new(276, 330))
	for i, info in PACOTES do
		local produto = Monetizacao.porId[info.id]
		local tem = op.temPasse(info.id)
		local linhas = {}
		for _, itemId in Cosmeticos.PACOTES[info.id] or {} do
			local item = Cosmeticos.porId[itemId]
			table.insert(linhas, string.format('<font color="#%s">%s</font>', item.cor, item.nome))
		end
		if info.id == "vip" then
			table.insert(linhas, "Nome dourado no chat")
			table.insert(linhas, "+10% de XP da Temporada")
		elseif info.id == "passeTemporada" then
			table.insert(linhas, "Trilha premium da Temporada 1")
			table.insert(linhas, "14 cosméticos exclusivos")
			table.insert(linhas, "Resgate até o fim da temporada")
		end
		Cartoes.cartao({
			pai = grade,
			ordem = i,
			cor = info.cor,
			icone = info.icone,
			titulo = produto.nome,
			etiqueta = info.etiqueta,
			linhas = linhas,
			preco = produto.preco,
			estado = if tem then "possui" else "comprar",
			aoClicar = if tem
				then nil
				else function()
					op.oferecer(info.id)
				end,
		})
	end
end

-- ===================================================================== Cosméticos

local function mostrarCosmeticos(estado: any)
	local lista = estrutura.lista
	local c = estado.cosmeticos or Cosmeticos.padrao()
	local possui = c.possui or {}
	local equipados = c.equipados or {}
	local total, meus = 0, 0
	for _, item in Cosmeticos.ITENS do
		total += 1
		if possui[item.id] then
			meus += 1
		end
	end
	Cartoes.secao(
		lista,
		proxima(),
		"Coleção",
		string.format("%d / %d desbloqueados", meus, total)
	)
	Cartoes.fichas(lista, proxima(), FILTROS, filtro, function(nome)
		filtro = nome
		Loja.atualizar()
	end)
	local itens = {}
	for _, item in Cosmeticos.ITENS do
		local tipo = FILTRO_TIPO[filtro]
		if not tipo or item.tipo == tipo then
			table.insert(itens, item)
		end
	end
	-- os seus primeiro (equipados no topo); depois os bloqueados
	table.sort(itens, function(a, b)
		local pa, pb = possui[a.id] == true, possui[b.id] == true
		if pa ~= pb then
			return pa
		end
		local ea, eb = equipados[a.tipo] == a.id, equipados[b.tipo] == b.id
		if ea ~= eb then
			return ea
		end
		return a.nome < b.nome
	end)
	local grade = Cartoes.grade(lista, proxima(), Vector2.new(204, 236))
	for i, item in itens do
		local tem = possui[item.id] == true
		local usando = equipados[item.tipo] == item.id
		Cartoes.cartao({
			pai = grade,
			ordem = i,
			cor = Color3.fromHex(item.cor),
			icone = iconeCosmetico(item),
			titulo = item.nome,
			subtitulo = if tem then NOMES_TIPO[item.tipo] else origemTexto(item),
			estado = if not tem then "travado" elseif usando then "equipado" else "equipar",
			textoBotao = if usando
				then "Equipado"
				elseif not tem then NOMES_TIPO[item.tipo]
				else nil,
			aoClicar = function()
				if tem then
					pedir("EquiparCosmetico", item.tipo, if usando then "" else item.id)
				else
					op.aviso(item.nome .. ": " .. origemTexto(item))
				end
			end,
		})
	end
end

-- ===================================================================== painel

function Loja.atualizar()
	if Navegacao.aberto() ~= "Loja" then
		return
	end
	ordem = 0
	local rolagem = estrutura.conteudo
	local antes = rolagem.CanvasPosition
	for _, filho in estrutura.lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	for nome, a in abas do
		a.definirAtiva(nome == aba)
	end
	local estado = Estado.atual
	if not estado then
		texto(
			estrutura.lista,
			{ Text = "Carregando...", TextColor3 = Cores.TextoSuave, Size = UDim2.new(1, 0, 0, 30) }
		)
		return
	end
	if aba == "Temporada" then
		mostrarTemporada(estado)
	elseif aba == "Pacotes" then
		mostrarPacotes()
	else
		mostrarCosmeticos(estado)
	end
	rolagem.CanvasPosition = antes
end

local function trocar(nome: string)
	if aba ~= nome then
		aba = nome
		estrutura.conteudo.CanvasPosition = Vector2.zero
	end
	Loja.atualizar()
end

function Loja.abrir()
	Navegacao.alternar("Loja")
end

-- Abre a Loja já na aba pedida (o cartão do jogador abre o Passe de Temporada)
function Loja.abrirAba(nome: string)
	if table.find(ABAS, nome) then
		aba = nome
		if estrutura then
			estrutura.conteudo.CanvasPosition = Vector2.zero
		end
	end
	if Navegacao.aberto() == "Loja" then
		Loja.atualizar()
	else
		Navegacao.abrir("Loja")
	end
end

function Loja.montar(opcoes: Opcoes)
	op = opcoes
	local painel = Navegacao.criarPainel(
		"Loja",
		{ titulo = "Loja do Nexo", icone = Icones.MENU.Loja },
		Loja.atualizar
	)
	estrutura = Cartoes.estrutura(painel.conteudo)
	for i, nome in ABAS do
		abas[nome] = Cartoes.aba(
			estrutura.lateral,
			i,
			nome,
			ICONE_ABA[nome],
			COR_ABA[nome],
			function()
				trocar(nome)
			end
		)
	end
	Estado.aoMudar(function()
		Loja.atualizar()
	end)
	Players.LocalPlayer.AttributeChanged:Connect(function(nome)
		if string.sub(nome, 1, 6) == "Passe_" then
			Loja.atualizar()
		end
	end)
end

return Loja
