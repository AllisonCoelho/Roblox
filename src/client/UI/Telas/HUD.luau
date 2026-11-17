-- HUD "Nexo Vibrante": cartão do jogador (topo esquerdo), moedas (topo direito), menu lateral
-- de atalhos coloridos com ícones, hotbar com espaços numerados e o grande botão DESPERTAR.
-- O centro da tela fica livre para o avatar e o cenário. Só lê o estado; quem age é o App.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Icones = require(Shared.Dados.Icones)
local Itens = require(Shared.Dados.Itens)
local Perfil = require(Shared.Dados.Perfil)
local Temporada = require(Shared.Dados.Temporada)
local Transcendencia = require(Shared.Dados.Transcendencia)
local Tema = require(Shared.Tema)
local Cores = Tema.Orbita
local V = Tema.Vibrante
local Escala = require(script.Parent.Parent.Escala)
local Kit = require(script.Parent.Parent.Kit)

local HUD = {}
local RECENTES = 3
local BRANCO = Color3.new(1, 1, 1)

export type EstadoGiro = "perfil" | "pedido" | "recarregando" | "pular" | "pronto"

export type Api = {
	quadro: Frame,
	definirGiro: (fracao: number, falta: number, estado: EstadoGiro) -> (),
	definirVisivel: (visivel: boolean) -> (),
	definirPerfilTeste: (ativo: boolean) -> (),
	atualizar: (estado: Perfil.Estado) -> (),
	registrarResultado: (aura: Auras.Aura, nova: boolean, simulado: boolean, chance: number) -> (),
}

type Opcoes = {
	aoDespertar: () -> (),
	aoAlternarAuto: () -> (),
	aoAbrirIndice: () -> (),
	aoAbrirInventario: () -> (),
	aoAbrirLoja: () -> (),
	aoAbrirTemporada: (() -> ())?,
	aoAbrirAjustes: () -> (),
}

local function corTier(aura: Auras.Aura): Color3
	return Color3.fromHex(Auras.Tiers[aura.tier].cor)
end

-- Pinta a placa com um degradê de duas cores (o fundo branco deixa o degradê aparecer puro)
local function colorir(placa: Kit.Placa, c1: Color3, c2: Color3)
	placa.definirCor(BRANCO)
	local g = placa.quadro:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(c1, c2)
	end
end

local function icone(
	pai: Instance,
	simbolo: string,
	tamanho: number,
	posicao: UDim2,
	caixa: UDim2
): TextLabel
	return Kit.texto({
		Text = simbolo,
		TextSize = tamanho,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = posicao,
		Size = caixa,
		ZIndex = 4,
		Parent = pai,
	})
end

local function rotulo(
	pai: Instance,
	texto: string,
	tamanho: number,
	props: { [string]: any }?
): TextLabel
	local p = props or {}
	p.fonte = "titulo"
	p.Text = texto
	p.TextSize = tamanho
	p.ZIndex = p.ZIndex or 4
	p.Parent = pai
	return Kit.texto(p)
end

local function barra(pai: Instance, cor: Color3, posicao: UDim2, tamanho: UDim2): Frame
	local fundo = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Borda,
		BorderSizePixel = 0,
		Position = posicao,
		Size = tamanho,
		ZIndex = 4,
		Parent = pai,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fundo })
	local cheio = Kit.novo("Frame", {
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Parent = fundo,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = cheio })
	return cheio
end

-- Selo numérico no canto do espaço da hotbar (atalho de teclado)
local function selo(pai: Instance, texto: string): Frame
	local f = Kit.circulo({
		BackgroundColor3 = Cores.Borda,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 6,
		Parent = pai,
	})
	Kit.texto({
		fonte = "mono",
		Text = texto,
		TextSize = 14,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = f,
	})
	return f
end

function HUD.montar(raiz: Frame, op: Opcoes): Api
	local hud = Kit.novo("Frame", {
		Name = "HUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = raiz,
	})

	-- ================================================================ cartão do jogador
	local cartao = Kit.placa({
		nome = "Jogador",
		tamanho = UDim2.fromOffset(340, 96),
		posicao = UDim2.fromOffset(18, 14),
		corte = 18,
		pai = hud,
	})
	colorir(cartao, Color3.fromHex("3A50B8"), Color3.fromHex("22307A"))
	local moldura = Kit.circulo({
		BackgroundColor3 = V.Giros,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(76, 76),
		ZIndex = 4,
		Parent = cartao.conteudo,
	})
	Kit.novo("UIStroke", { Color = Cores.Borda, Thickness = 3, Parent = moldura })
	local avatar = Kit.novo("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92),
		ZIndex = 5,
		Parent = moldura,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avatar })
	task.spawn(function()
		local ok, imagem = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			Players.LocalPlayer.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
		if ok then
			avatar.Image = imagem
		end
	end)
	local nivelTrans = Kit.placa({
		tamanho = UDim2.fromOffset(46, 24),
		posicao = UDim2.fromOffset(58, 66),
		corte = 8,
		z = 6,
		pai = cartao.conteudo,
	})
	colorir(nivelTrans, Color3.fromHex("FFE066"), Color3.fromHex("FF9D00"))
	local textoTrans = rotulo(nivelTrans.conteudo, "T0", 14, {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
	})
	rotulo(cartao.conteudo, Players.LocalPlayer.DisplayName, 22, {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(98, 8),
		Size = UDim2.new(1, -108, 0, 28),
	})
	local textoTemporada = rotulo(cartao.conteudo, "🏆 Temporada · Nv 0", 15, {
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromHex("FFD6F5"),
		Position = UDim2.fromOffset(98, 40),
		Size = UDim2.new(1, -108, 0, 20),
	})
	local barraTemporada = barra(
		cartao.conteudo,
		Color3.fromHex("FF6FD0"),
		UDim2.fromOffset(98, 66),
		UDim2.new(1, -112, 0, 14)
	)
	local alvoCartao = Kit.alvo(cartao.quadro, "Passe de Temporada", function()
		(op.aoAbrirTemporada or op.aoAbrirLoja)()
	end)
	Kit.animarToque(cartao.quadro, alvoCartao)

	-- ================================================================ moedas
	local moedas = Kit.novo("Frame", {
		Name = "Moedas",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(392, 52),
		Parent = hud,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = moedas,
	})
	local function moeda(ordem: number, simbolo: string, cor: Color3): TextLabel
		local p = Kit.placa({
			tamanho = UDim2.fromOffset(186, 50),
			corte = 25,
			ordem = ordem,
			pai = moedas,
		})
		p.definirCor(Cores.Fundo)
		local bolha = Kit.circulo({
			BackgroundColor3 = cor,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(42, 42),
			ZIndex = 4,
			Parent = p.conteudo,
		})
		Kit.novo("UIStroke", { Color = Cores.Borda, Thickness = 2, Parent = bolha })
		icone(bolha, simbolo, 24, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1))
		return rotulo(p.conteudo, "0", 22, {
			fonte = "mono",
			TextColor3 = cor,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -66, 1, 0),
		})
	end
	local giros = moeda(1, Icones.MENU.Giros, V.Giros)
	local fragmentos = moeda(2, Icones.MENU.Fragmentos, V.Fragmentos)

	-- ================================================================ últimos despertares
	local feed = Kit.placa({
		nome = "Recentes",
		tamanho = UDim2.fromOffset(258, 140),
		ancora = Vector2.new(1, 0),
		posicao = UDim2.new(1, -18, 0, 80),
		corte = 14,
		pai = hud,
	})
	feed.definirCor(Cores.Fundo)
	feed.quadro.BackgroundTransparency = 0.15
	feed.quadro.Visible = false
	rotulo(feed.conteudo, "ÚLTIMOS DESPERTARES", 14, {
		TextColor3 = V.Giros,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 2),
		Size = UDim2.new(1, -24, 0, 26),
	})
	type Linha = { quadro: Frame, nome: TextLabel, chance: TextLabel, marca: Frame }
	local linhas: { Linha } = {}
	local recentes: { { aura: Auras.Aura, chance: number } } = {}
	local recentesTeste: { { aura: Auras.Aura, chance: number } } = {}
	local emTeste = false
	for i = 1, RECENTES do
		local quadro = Kit.novo("Frame", {
			Name = "Giro" .. i,
			BackgroundColor3 = Cores.Painel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 28 + (i - 1) * 36),
			Size = UDim2.new(1, -16, 0, 32),
			Visible = false,
			ZIndex = 4,
			Parent = feed.conteudo,
		})
		Kit.novo("UICorner", { CornerRadius = UDim.new(0, 8), Parent = quadro })
		local marca = Kit.circulo({
			BackgroundColor3 = BRANCO,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 5,
			Parent = quadro,
		})
		Kit.novo("UIStroke", { Color = Cores.Borda, Thickness = 2, Parent = marca })
		local nome = rotulo(quadro, "", 16, {
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -104, 1, 0),
			ZIndex = 5,
		})
		local chance = rotulo(quadro, "", 14, {
			fonte = "mono",
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -74, 0, 0),
			Size = UDim2.new(0, 66, 1, 0),
			ZIndex = 5,
		})
		linhas[i] = { quadro = quadro, nome = nome, chance = chance, marca = marca }
	end

	-- ================================================================ menu lateral
	local menu = Kit.novo("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, 10),
		Size = UDim2.fromOffset(88, 460),
		Parent = hud,
	})
	local listaMenu = Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 10),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local botoesMenu: { TextButton } = {}
	local placasMenu: { Kit.Placa } = {}
	local function atalho(
		ordem: number,
		nome: string,
		simbolo: string,
		cores: { Color3 },
		acao: () -> ()
	)
		local p = Kit.placa({
			nome = nome,
			tamanho = UDim2.fromOffset(84, 84),
			corte = 18,
			ordem = ordem,
			pai = menu,
		})
		colorir(p, cores[1], cores[2])
		icone(p.conteudo, simbolo, 36, UDim2.new(0.5, 0, 0, 32), UDim2.fromOffset(60, 44))
		rotulo(p.conteudo, nome, 15, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -5),
			Size = UDim2.new(1, -6, 0, 20),
		})
		local b = Kit.alvo(p.quadro, nome, acao)
		Kit.animarToque(p.quadro, b)
		table.insert(botoesMenu, b)
		table.insert(placasMenu, p)
		return b
	end
	atalho(1, "Loja", Icones.MENU.Loja, V.Loja, op.aoAbrirLoja)
	atalho(2, "Bolsa", Icones.MENU.Bolsa, V.Bolsa, op.aoAbrirInventario)
	atalho(3, "Índice", Icones.MENU.Indice, V.Indice, op.aoAbrirIndice)
	atalho(4, "Passe", Icones.MENU.Temporada, V.Temporada, op.aoAbrirTemporada or op.aoAbrirLoja)
	local ajustesBotao = atalho(5, "Ajustes", Icones.MENU.Ajustes, V.Ajustes, op.aoAbrirAjustes)
	for i, b in botoesMenu do
		b.NextSelectionUp = botoesMenu[i - 1]
		b.NextSelectionDown = botoesMenu[i + 1]
	end

	-- ================================================================ hotbar
	local hotbar = Kit.novo("Frame", {
		Name = "Acoes",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(600, 170),
		Parent = hud,
	})
	local escalaHotbar = Kit.novo("UIScale", { Parent = hotbar })

	type Espaco = {
		placa: Kit.Placa,
		simbolo: TextLabel,
		titulo: TextLabel,
		valor: TextLabel,
		botao: TextButton,
	}
	local function espaco(
		numero: string,
		x: number,
		titulo: string,
		simbolo: string,
		acao: () -> ()
	): Espaco
		local p = Kit.placa({
			nome = "Espaco" .. numero,
			tamanho = UDim2.fromOffset(96, 112),
			ancora = Vector2.new(0.5, 1),
			posicao = UDim2.new(0.5, x, 1, 0),
			corte = 16,
			pai = hotbar,
		})
		local simb =
			icone(p.conteudo, simbolo, 34, UDim2.new(0.5, 0, 0, 34), UDim2.fromOffset(60, 44))
		local tit = rotulo(p.conteudo, titulo, 13, {
			TextColor3 = Cores.TextoSuave,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 58),
			Size = UDim2.new(1, -8, 0, 16),
		})
		local val = rotulo(p.conteudo, "", 14, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 76),
			Size = UDim2.new(1, -8, 0, 20),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		selo(p.quadro, numero)
		local b = Kit.alvo(p.quadro, titulo, acao)
		Kit.animarToque(p.quadro, b)
		return { placa = p, simbolo = simb, titulo = tit, valor = val, botao = b }
	end
	local espAura = espaco("1", -240, "AURA", Icones.MENU.Aura, op.aoAbrirIndice)
	local espAuto = espaco("2", -130, "AUTO", Icones.MENU.Auto, op.aoAlternarAuto)
	local espIndice = espaco("3", 130, "ÍNDICE", Icones.MENU.Indice, op.aoAbrirIndice)
	local espArtefato = espaco("4", 240, "ARTEFATO", Icones.MENU.Artefato, op.aoAbrirInventario)
	colorir(espIndice.placa, V.Indice[1], V.Indice[2])
	local progresso =
		barra(espIndice.placa.conteudo, V.Giros, UDim2.new(0, 12, 1, -11), UDim2.new(1, -24, 0, 6))

	-- Botão DESPERTAR: disco dourado com anel de recarga
	local giro = Kit.novo("Frame", {
		Name = "Despertar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(140, 170),
		Parent = hotbar,
	})
	local orbita = Kit.novo("Frame", {
		Name = "Orbita",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(136, 136),
		Parent = giro,
	})
	local anel = Kit.anel(orbita, 136, V.Giros, Cores.Borda, 1)
	local disco = Kit.circulo({
		BackgroundColor3 = BRANCO,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
		ZIndex = 2,
		Parent = orbita,
	})
	Kit.novo("UIStroke", { Color = Cores.Borda, Thickness = 4, Parent = disco })
	local gradDisco = Kit.novo("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(V.Despertar[1], V.Despertar[2]),
		Parent = disco,
	})
	local simboloGiro =
		icone(disco, "🎲", 50, UDim2.fromScale(0.5, 0.42), UDim2.fromOffset(80, 60))
	simboloGiro.ZIndex = 3
	local carga = rotulo(disco, "", 18, {
		fonte = "mono",
		Position = UDim2.new(0, 0, 1, -38),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 3,
	})
	local etiqueta = Kit.placa({
		tamanho = UDim2.new(1, 0, 0, 40),
		ancora = Vector2.new(0, 1),
		posicao = UDim2.fromScale(0, 1),
		corte = 20,
		z = 3,
		pai = giro,
	})
	colorir(etiqueta, Color3.fromHex("FF5C8A"), Color3.fromHex("E2233B"))
	local rotuloGiro = rotulo(etiqueta.conteudo, "DESPERTAR", 22, {
		TextWrapped = true,
		Position = UDim2.fromOffset(5, 0),
		Size = UDim2.new(1, -10, 1, 0),
	})
	local tecla = Kit.circulo({
		BackgroundColor3 = Cores.Borda,
		Position = UDim2.new(1, -18, 0, 2),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 6,
		Parent = giro,
	})
	Kit.novo("UIStroke", { Color = BRANCO, Thickness = 2, Parent = tecla })
	Kit.texto({
		fonte = "mono",
		Text = "E",
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = tecla,
	})
	local giroBotao = Kit.alvo(giro, "Despertar", op.aoDespertar)
	Kit.animarToque(orbita, giroBotao)
	giroBotao.NextSelectionLeft = espAuto.botao
	giroBotao.NextSelectionRight = espIndice.botao
	espAuto.botao.NextSelectionRight = giroBotao
	espAuto.botao.NextSelectionLeft = espAura.botao
	espAura.botao.NextSelectionRight = espAuto.botao
	espIndice.botao.NextSelectionLeft = giroBotao
	espIndice.botao.NextSelectionRight = espArtefato.botao
	espArtefato.botao.NextSelectionLeft = espIndice.botao
	espAura.botao.NextSelectionLeft = ajustesBotao

	-- Atalhos 1–4 da hotbar (Alt fica para os testes do Studio)
	UserInputService.InputBegan:Connect(function(input, processado)
		if processado or not hud.Visible or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
			return
		end
		local acoes = {
			[Enum.KeyCode.One] = op.aoAbrirIndice,
			[Enum.KeyCode.Two] = op.aoAlternarAuto,
			[Enum.KeyCode.Three] = op.aoAbrirIndice,
			[Enum.KeyCode.Four] = op.aoAbrirInventario,
		}
		local acao = acoes[input.KeyCode]
		if acao then
			acao()
		end
	end)

	-- ================================================================ resultado do giro
	local resultado = Kit.placa({
		nome = "Resultado",
		tamanho = UDim2.fromOffset(446, 54),
		ancora = Vector2.new(0.5, 1),
		posicao = UDim2.new(0.5, 0, 0, -14),
		corte = 27,
		pai = hotbar,
	})
	resultado.quadro.Visible = false
	local textoResultado = rotulo(resultado.conteudo, "", 21, {
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
	})
	local resultadoToken = 0
	local resultadoSimulado = false
	local estadoGiro: EstadoGiro? = nil
	local tempoMostrado = ""

	local function atualizarFeed()
		local lista = if emTeste then recentesTeste else recentes
		feed.quadro.Visible = not Escala.compacto and #lista > 0
		feed.quadro.Size = UDim2.fromOffset(258, 34 + 36 * #lista)
		for i, linha in linhas do
			local g = lista[i]
			linha.quadro.Visible = g ~= nil
			if g then
				linha.nome.Text = g.aura.nome
				linha.nome.TextColor3 = Kit.corLegivel(corTier(g.aura))
				linha.chance.Text = "1/" .. Formato.chanceCurta(g.chance)
				linha.marca.BackgroundColor3 = corTier(g.aura)
			end
		end
	end

	local function ajustarRotuloGiro()
		local longo = estadoGiro == "perfil" or estadoGiro == "pedido"
		rotuloGiro.TextSize = if longo then 15 else 22
	end

	local function ajustar()
		local compacto = Escala.compacto
		local estreito = Escala.tamanho.X < 760
		escalaHotbar.Scale = if estreito then 0.72 elseif compacto then 0.85 else 1
		local margem = if Escala.toque then 24 else 18
		hotbar.Position =
			UDim2.new(0.5, if Escala.toque and not estreito then -60 else 0, 1, -margem)
		local tile = if compacto then 64 else 84
		for _, p in placasMenu do
			p.quadro.Size = UDim2.fromOffset(tile, tile)
		end
		menu.Size = UDim2.fromOffset(tile + 4, (tile + 10) * #placasMenu)
		listaMenu.Padding = UDim.new(0, if compacto then 6 else 10)
		menu.Position = UDim2.new(0, if compacto then 10 else 18, 0.5, if compacto then 0 else 10)
		cartao.quadro.Size = UDim2.fromOffset(if estreito then 250 else 340, 96)
		cartao.quadro.Position =
			UDim2.fromOffset(if compacto then 10 else 18, if compacto then 8 else 14)
		moedas.Position =
			UDim2.new(1, if compacto then -10 else -18, 0, if compacto then 10 else 16)
		for _, filho in moedas:GetChildren() do
			if filho:IsA("Frame") then
				filho.Size = UDim2.fromOffset(if estreito then 130 else 186, 50)
			end
		end
		tecla.Visible = Escala.teclado and (estadoGiro == "pronto" or estadoGiro == "pular")
		resultado.quadro.Size = UDim2.fromOffset(446, 54)
		ajustarRotuloGiro()
		atualizarFeed()
	end
	Escala.aoMudar(ajustar)

	return {
		quadro = hud,
		definirGiro = function(fracao: number, falta: number, estado: EstadoGiro)
			local carregando = estado == "recarregando"
			local disponivel = estado == "pronto" or estado == "pular"
			anel.definir(
				fracao,
				if carregando then Cores.Menta elseif disponivel then V.Giros else Cores.Borda
			)
			local tempo = if carregando
				then string.format("%.1f s", math.ceil(falta * 10) / 10)
				else ""
			if tempo ~= tempoMostrado then
				tempoMostrado = tempo
				carga.Text = tempo:gsub("%.", ",")
			end
			if estadoGiro == estado then
				return
			end
			estadoGiro = estado
			ajustarRotuloGiro()
			local titulo = if estado == "perfil"
				then "Aguardando perfil"
				elseif estado == "pedido" then "Despertando…"
				elseif estado == "pular" then "PULAR"
				else "DESPERTAR"
			rotuloGiro.Text = titulo
			giroBotao.Text = titulo
			giroBotao.Interactable = disponivel
			tecla.Visible = Escala.teclado and disponivel
			simboloGiro.Text = if estado == "pular" then "⏩" else "🎲"
			-- Disco apagado enquanto recarrega: o anel mostra o progresso
			gradDisco.Color = if disponivel
				then ColorSequence.new(V.Despertar[1], V.Despertar[2])
				else ColorSequence.new(Color3.fromHex("8A93B8"), Color3.fromHex("4B5378"))
		end,
		definirVisivel = function(visivel: boolean)
			hud.Visible = visivel
		end,
		definirPerfilTeste = function(ativo: boolean)
			emTeste = ativo
			if not ativo then
				table.clear(recentesTeste)
				if resultadoSimulado then
					resultadoToken += 1
					resultado.quadro.Visible = false
				end
			end
			atualizarFeed()
		end,
		atualizar = function(estado: Perfil.Estado)
			giros.Text = if estado.giros < 1000000
				then Formato.inteiro(estado.giros)
				else Formato.curto(estado.giros)
			local frag = if type(estado.incursoes) == "table"
				then estado.incursoes.fragmentos or 0
				else 0
			fragmentos.Text = if frag < 1000000 then Formato.inteiro(frag) else Formato.curto(frag)
			textoTrans.Text = "T" .. estado.transcendencia.nivel

			-- Temporada
			local t = Temporada.de(
				if type(estado.temporada) == "table" then table.clone(estado.temporada) else nil
			)
			local nivel = Temporada.nivel(t.xp)
			textoTemporada.Text = string.format("🏆 Temporada · Nv %d", nivel)
			barraTemporada.Size = UDim2.fromScale(
				if nivel >= Temporada.NIVEIS
					then 1
					else (t.xp - nivel * Temporada.XP_POR_NIVEL) / Temporada.XP_POR_NIVEL,
				1
			)

			-- Aura equipada
			local aura = if estado.equipada then Auras.porId[estado.equipada] else nil
			if aura then
				local cor = corTier(aura)
				colorir(espAura.placa, cor, cor:Lerp(Cores.Borda, 0.55))
				espAura.simbolo.Text = Icones.aura(aura.estilo)
				espAura.valor.Text = aura.nome
				espAura.titulo.Text = string.format(
					"1 em %s",
					Formato.chanceCurta(
						Auras.chanceEfetiva(aura, Transcendencia.sorte(estado.transcendencia.nivel))
					)
				)
				espAura.titulo.TextColor3 = BRANCO
			else
				espAura.placa.definirCor(Cores.Elevado)
				local g = espAura.placa.quadro:FindFirstChildOfClass("UIGradient")
				if g then
					g.Color = ColorSequence.new(BRANCO, Color3.fromRGB(190, 190, 205))
				end
				espAura.simbolo.Text = Icones.MENU.Aura
				espAura.valor.Text = "Nenhuma"
				espAura.titulo.Text = "AURA"
				espAura.titulo.TextColor3 = Cores.TextoSuave
			end

			-- Giro automático
			local ligado = estado.configuracoes.giroAutomatico == true
			if ligado then
				colorir(espAuto.placa, V.Auto[1], V.Auto[2])
			else
				colorir(espAuto.placa, V.Ajustes[1], V.Ajustes[2])
			end
			espAuto.valor.Text = if ligado then "LIGADO" else "DESLIGADO"
			espAuto.botao.Text = "Giro automático · " .. espAuto.valor.Text

			-- Índice
			local descobertas = Auras.contarDescobertas(estado.auras)
			espIndice.valor.Text = string.format("%d / %d", descobertas, #Auras.lista)
			progresso.Size = UDim2.fromScale(descobertas / #Auras.lista, 1)

			-- Artefato equipado
			local artefato = estado.inventario.equipados.artefato
			local item = if artefato then Itens.porId[artefato] else nil
			if item then
				local cor = Color3.fromHex(Itens.Tiers[item.raridade].cor)
				colorir(espArtefato.placa, cor, cor:Lerp(Cores.Borda, 0.55))
				espArtefato.simbolo.Text = Icones.item(artefato :: string, item.categoria)
				espArtefato.valor.Text = item.nome
			else
				colorir(espArtefato.placa, V.Temporada[1], V.Temporada[2])
				espArtefato.simbolo.Text = Icones.MENU.Artefato
				espArtefato.valor.Text = "Vazio"
			end
		end,
		registrarResultado = function(
			aura: Auras.Aura,
			nova: boolean,
			simulado: boolean,
			chance: number
		)
			local lista = if simulado then recentesTeste else recentes
			table.insert(lista, 1, { aura = aura, chance = chance })
			if #lista > RECENTES then
				table.remove(lista)
			end
			atualizarFeed()
			resultadoSimulado = simulado
			resultadoToken += 1
			local meu = resultadoToken
			textoResultado.Text = string.format(
				"%s%s%s · 1 em %s",
				if simulado then "Teste · " else "",
				if nova then "✨ NOVA · " else "",
				aura.nome,
				Formato.chance(chance)
			)
			local cor = corTier(aura)
			colorir(resultado, cor:Lerp(Cores.Painel, 0.35), cor:Lerp(Cores.Borda, 0.6))
			resultado.quadro.Visible = true
			task.delay(1.45, function()
				if resultadoToken == meu then
					resultado.quadro.Visible = false
				end
			end)
		end,
	}
end

return HUD
