-- HUD da Órbita do Nexo (v2). Mantém a identidade original (fundo escuro, placas chanfradas,
-- lilás) e organiza como os jogos de aventura do Roblox: cartão do jogador com barras no topo
-- esquerdo, menu lateral de ícones, moedas e últimos despertares à direita e uma barra de
-- atalhos numerada em volta do botão DESPERTAR. O centro fica livre para o avatar e o cenário.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Icones = require(Shared.Dados.Icones)
local Itens = require(Shared.Dados.Itens)
local Perfil = require(Shared.Dados.Perfil)
local Temporada = require(Shared.Dados.Temporada)
local PontosAura = require(Shared.Dados.PontosAura)
local Ciclo = require(Shared.Dados.Ciclo)
local Cores = require(Shared.Tema).Orbita
local Escala = require(script.Parent.Parent.Escala)
local Kit = require(script.Parent.Parent.Kit)
local IconeImagem = require(script.Parent.Parent.IconeImagem)
local Navegacao = require(script.Parent.Parent.Navegacao)

local HUD = {}
local RECENTES = 3

-- Um destaque por atalho (borda e ícone), sobre o mesmo fundo escuro da Órbita
local DESTAQUE = {
	Loja = Color3.fromHex("FFC83D"),
	Bolsa = Color3.fromHex("FF9A6A"),
	Indice = Color3.fromHex("7FD8FF"),
	Passe = Color3.fromHex("FF8BD8"),
	Ajustes = Cores.Lilas,
	Giros = Color3.fromHex("FFD36B"),
	Fragmentos = Color3.fromHex("C9A2FF"),
	Evoluir = Color3.fromHex("B7FFD9"),
}
local ICONE_PONTOS = 31

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
	aoAbrirEvoluir: (() -> ())?,
	aoAbrirEcos: (() -> ())?,
	aoAbrirEquipamento: (() -> ())?,
}

local function corTier(aura: Auras.Aura): Color3
	return Color3.fromHex(Auras.Tiers[aura.tier].cor)
end

-- Leve aumento ao passar o mouse e "afundar" ao tocar (resposta imediata ao toque)
local function animarToque(alvo: GuiObject, botao: GuiButton)
	local escala = Kit.novo("UIScale", { Parent = alvo })
	local function para(v: number)
		TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = v })
			:Play()
	end
	botao.MouseEnter:Connect(function()
		para(1.04)
	end)
	botao.MouseLeave:Connect(function()
		para(1)
	end)
	botao.MouseButton1Down:Connect(function()
		para(0.94)
	end)
	botao.MouseButton1Up:Connect(function()
		para(1.04)
	end)
end

local function texto(pai: Instance, props: { [string]: any }): TextLabel
	props.Parent = pai
	return Kit.texto(props)
end

local function barra(pai: Instance, cor: Color3, posicao: UDim2, tamanho: UDim2): Frame
	local fundo = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Elevado,
		BorderSizePixel = 0,
		Position = posicao,
		Size = tamanho,
		Parent = pai,
	})
	local cheio = Kit.novo("Frame", {
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = fundo,
	})
	return cheio
end

-- Selo com o número do atalho (teclas 1–4)
local function selo(pai: Instance, numero: string)
	local p = Kit.placa({
		tamanho = UDim2.fromOffset(22, 22),
		posicao = UDim2.fromOffset(-6, -6),
		fundo = Cores.Fundo,
		borda = Cores.Lilas,
		corte = 5,
		z = 5,
		pai = pai,
	})
	texto(
		p.conteudo,
		{ fonte = "mono", Text = numero, TextSize = 13, Size = UDim2.fromScale(1, 1) }
	)
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
		tamanho = UDim2.fromOffset(336, 92),
		posicao = UDim2.fromOffset(22, 16),
		corte = 12,
		pai = hud,
	})
	local moldura = Kit.circulo({
		BackgroundColor3 = Cores.Elevado,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(72, 72),
		Parent = cartao.conteudo,
	})
	Kit.novo("UIStroke", { Color = Cores.Lilas, Thickness = 2, Parent = moldura })
	local avatar = Kit.novo("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.94),
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
	local selTrans = Kit.placa({
		tamanho = UDim2.fromOffset(40, 22),
		posicao = UDim2.fromOffset(52, 64),
		fundo = Cores.Lilas,
		borda = Cores.Lilas,
		corte = 5,
		z = 4,
		pai = cartao.conteudo,
	})
	local textoTrans = texto(selTrans.conteudo, {
		fonte = "mono",
		Text = "T0",
		TextSize = 13,
		TextColor3 = Cores.Fundo,
		Size = UDim2.fromScale(1, 1),
	})
	texto(cartao.conteudo, {
		fonte = "titulo",
		Text = Players.LocalPlayer.DisplayName,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(96, 8),
		Size = UDim2.new(1, -106, 0, 28),
	})
	local textoTemporada = texto(cartao.conteudo, {
		Text = "PASSE · NV 0",
		TextSize = 14,
		TextColor3 = DESTAQUE.Passe,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(96, 40),
		Size = UDim2.new(1, -106, 0, 18),
	})
	local barraTemporada =
		barra(cartao.conteudo, DESTAQUE.Passe, UDim2.fromOffset(96, 62), UDim2.new(1, -110, 0, 8))
	local alvoCartao = Kit.alvo(cartao.quadro, "Passe de Temporada", function()
		(op.aoAbrirTemporada or op.aoAbrirLoja)()
	end)
	animarToque(cartao.quadro, alvoCartao)

	-- Moedas logo abaixo do cartão (como dinheiro e fragmentos nos jogos de aventura)
	local moedas = Kit.novo("Frame", {
		Name = "Moedas",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 116),
		Size = UDim2.fromOffset(336, 40),
		Parent = hud,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = moedas,
	})
	local placasMoeda: { Kit.Placa } = {}
	local function moeda(ordem: number, simbolo: number, nome: string, cor: Color3): TextLabel
		local p = Kit.placa({
			tamanho = UDim2.fromOffset(164, 40),
			ordem = ordem,
			corte = 8,
			pai = moedas,
		})
		table.insert(placasMoeda, p)
		IconeImagem.criar(p.conteudo, simbolo, UDim2.fromOffset(8, 9), UDim2.fromOffset(22, 22))
		texto(p.conteudo, {
			Text = nome,
			TextSize = 12,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(36, 0),
			Size = UDim2.new(0, 44, 1, 0),
		})
		local valor = texto(p.conteudo, {
			fonte = "mono",
			Text = "0",
			TextSize = 18,
			TextColor3 = cor,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextScaled = true,
			Position = UDim2.fromOffset(83, 0),
			Size = UDim2.new(1, -91, 1, 0),
		})
		Kit.novo("UITextSizeConstraint", { MinTextSize = 8, MaxTextSize = 18, Parent = valor })
		return valor
	end
	local giros = moeda(1, Icones.MENU.Giros, "GIROS", DESTAQUE.Giros)
	local fragmentos = moeda(2, Icones.MENU.Fragmentos, "FRAGM.", DESTAQUE.Fragmentos)

	-- ================================================================ Pontos de Aura
	-- No topo, no centro: o número que sobe sem parar (como nos jogos de treino do Roblox).
	-- O servidor escreve o saldo a cada segundo; aqui o contador anda entre um e outro.
	local painelPontos = Kit.placa({
		nome = "PontosAura",
		tamanho = UDim2.fromOffset(320, 62),
		ancora = Vector2.new(0.5, 0),
		posicao = UDim2.new(0.5, 0, 0, 14),
		borda = DESTAQUE.Evoluir,
		corte = 12,
		pai = hud,
	})
	IconeImagem.criar(
		painelPontos.conteudo,
		ICONE_PONTOS,
		UDim2.fromOffset(10, 10),
		UDim2.fromOffset(40, 40)
	)
	local valorPontos = texto(painelPontos.conteudo, {
		fonte = "titulo",
		Text = "0",
		TextSize = 28,
		TextColor3 = DESTAQUE.Evoluir,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.new(1, -150, 0, 32),
	})
	Kit.novo("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = 28, Parent = valorPontos })
	local ganhoPontos = texto(painelPontos.conteudo, {
		fonte = "mono",
		Text = "+0/s",
		TextSize = 14,
		TextColor3 = Cores.Menta,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(58, 36),
		Size = UDim2.new(1, -150, 0, 18),
	})
	texto(painelPontos.conteudo, {
		Text = "PONTUAÇÃO",
		TextSize = 11,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -96, 0, 8),
		Size = UDim2.fromOffset(86, 14),
	})
	local valorPontuacao = texto(painelPontos.conteudo, {
		fonte = "mono",
		Text = "0",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -96, 0, 22),
		Size = UDim2.fromOffset(86, 20),
	})
	local valorSorte = texto(painelPontos.conteudo, {
		fonte = "mono",
		Text = "Sorte 1,0x",
		TextSize = 12,
		TextColor3 = Color3.fromHex("7BF0A0"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -96, 0, 42),
		Size = UDim2.fromOffset(86, 14),
	})
	local alvoPontos = Kit.alvo(painelPontos.quadro, "Evoluir Aura", function()
		(op.aoAbrirEvoluir or op.aoAbrirIndice)()
	end)
	animarToque(painelPontos.quadro, alvoPontos)
	do
		local eu = Players.LocalPlayer
		local base, baseEm = 0, os.clock()
		local function grande(n: number): string
			return if n < 1000000 then Formato.inteiro(math.floor(n)) else Formato.curto(n)
		end
		local function ler()
			base = tonumber(eu:GetAttribute("PontosAura")) or 0
			baseEm = os.clock()
			local g = tonumber(eu:GetAttribute("GanhoAura")) or 0
			local bonus = (tonumber(eu:GetAttribute("BonusAuraAte")) or 0)
				> workspace:GetServerTimeNow()
			ganhoPontos.Text = "+"
				.. (string.format("%.1f", g):gsub("%.", ","))
				.. "/s"
				.. (if bonus then "  ×2 COMBATE" else "")
			ganhoPontos.TextColor3 = if bonus then Color3.fromHex("FFC83D") else Cores.Menta
			valorPontuacao.Text = grande(tonumber(eu:GetAttribute("Pontuacao")) or 0)
			valorSorte.Text = "Sorte "
				.. (string
					.format("%.1f", tonumber(eu:GetAttribute("SorteTotal")) or 1)
					:gsub("%.", ","))
				.. "x"
		end
		for _, nome in { "PontosAura", "GanhoAura", "Pontuacao", "SorteTotal", "BonusAuraAte" } do
			eu:GetAttributeChangedSignal(nome):Connect(ler)
		end
		ler()
		task.spawn(function()
			while hud.Parent do
				local g = tonumber(eu:GetAttribute("GanhoAura")) or 0
				-- o contador anda no ritmo do ganho até o próximo valor do servidor (no máx. 1 s)
				local estimado = base + g * math.min(os.clock() - baseEm, 1)
				valorPontos.Text = grande(estimado)
				task.wait(0.1)
			end
		end)
	end

	-- ================================================================ ciclo de dia e noite
	-- Logo abaixo dos Pontos: a fase, quanto falta para a próxima e a Bênção Estelar
	local chipCiclo = Kit.placa({
		nome = "Ciclo",
		tamanho = UDim2.fromOffset(320, 26),
		ancora = Vector2.new(0.5, 0),
		posicao = UDim2.new(0.5, 0, 0, 82),
		corte = 8,
		pai = hud,
	})
	local textoCiclo = texto(chipCiclo.conteudo, {
		RichText = true,
		Text = "",
		TextSize = 13,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
	})
	local ICONE_FASE = { aurora = "◐", dia = "☀", crepusculo = "◑", noite = "☾" }
	local COR_FASE = {
		aurora = "FFB8C8",
		dia = "FFE27A",
		crepusculo = "FF9A6A",
		noite = "C0ADFF",
	}
	task.spawn(function()
		local eu = Players.LocalPlayer
		while hud.Parent do
			local agora = workspace:GetServerTimeNow()
			local e =
				Ciclo.estado(agora + (tonumber(workspace:GetAttribute("CicloDeslocamento")) or 0))
			local partes = {
				string.format(
					'<font color="#%s"><b>%s %s</b></font> · %s',
					COR_FASE[e.fase],
					ICONE_FASE[e.fase],
					Ciclo.NOMES[e.fase],
					Ciclo.tempo(e.restante)
				),
			}
			if e.fase == "noite" then
				table.insert(partes, '<font color="#FFE27A">drops ×2 · estrelas</font>')
			end
			local bencao = (tonumber(eu:GetAttribute("BencaoEstelarAte")) or 0) - agora
			if bencao > 0 then
				table.insert(
					partes,
					string.format('<font color="#FFE27A">★ +25%% %s</font>', Ciclo.tempo(bencao))
				)
			end
			textoCiclo.Text = table.concat(partes, "   ")
			task.wait(0.5)
		end
	end)

	-- ================================================================ menu lateral
	local menu = Kit.novo("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 40),
		Size = UDim2.fromOffset(80, 450),
		Parent = hud,
	})
	local listaMenu = Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local placasMenu: { Kit.Placa } = {}
	local botoesMenu: { TextButton } = {}
	local function atalho(
		ordem: number,
		nome: string,
		simbolo: number,
		cor: Color3,
		acao: () -> ()
	): TextButton
		local p = Kit.placa({
			nome = nome,
			tamanho = UDim2.fromOffset(78, 78),
			borda = cor,
			corte = 12,
			ordem = ordem,
			pai = menu,
		})
		-- faixa de cor no pé do botão: identifica o atalho de longe
		Kit.novo("Frame", {
			BackgroundColor3 = cor,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -2),
			Size = UDim2.new(1, -4, 0, 24),
			Parent = p.conteudo,
		})
		local imagem = IconeImagem.criar(
			p.conteudo,
			simbolo,
			UDim2.new(0.5, 0, 0, 5),
			UDim2.new(0, 34, 1, -28)
		)
		imagem.AnchorPoint = Vector2.new(0.5, 0)
		texto(p.conteudo, {
			fonte = "titulo",
			Text = string.upper(nome),
			TextSize = 12,
			TextColor3 = Kit.corLegivel(cor),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -4, 0, 20),
		})
		local b = Kit.alvo(p.quadro, nome, acao)
		animarToque(p.quadro, b)
		table.insert(placasMenu, p)
		table.insert(botoesMenu, b)
		return b
	end
	atalho(1, "Loja", Icones.MENU.Loja, DESTAQUE.Loja, op.aoAbrirLoja)
	atalho(2, "Bolsa", Icones.MENU.Bolsa, DESTAQUE.Bolsa, op.aoAbrirInventario)
	-- o Índice continua no espaço 3 da barra de baixo; o menu ganha o Equipamento
	atalho(3, "Equipar", 24, Color3.fromHex("FFC83D"), op.aoAbrirEquipamento or op.aoAbrirIndice)
	-- o Passe continua no cartão do jogador; o menu ganha Evoluir (o centro do jogo agora)
	atalho(4, "Evoluir", ICONE_PONTOS, DESTAQUE.Evoluir, op.aoAbrirEvoluir or op.aoAbrirIndice)
	atalho(5, "Ecos", 28, Color3.fromHex("FF9AD5"), op.aoAbrirEcos or op.aoAbrirIndice)
	local ajustesBotao =
		atalho(6, "Ajustes", Icones.MENU.Ajustes, DESTAQUE.Ajustes, op.aoAbrirAjustes)

	-- ================================================================ últimos despertares
	local feed = Kit.placa({
		nome = "Recentes",
		tamanho = UDim2.fromOffset(258, 140),
		ancora = Vector2.new(1, 0),
		posicao = UDim2.new(1, -22, 0, 16),
		pai = hud,
	})
	feed.quadro.Visible = false
	texto(feed.conteudo, {
		Text = "ÚLTIMOS DESPERTARES",
		TextSize = 14,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 28),
	})
	type Linha = { quadro: Frame, nome: TextLabel, chance: TextLabel, marca: Frame }
	local linhas: { Linha } = {}
	local recentes: { { aura: Auras.Aura, chance: number } } = {}
	local recentesTeste: { { aura: Auras.Aura, chance: number } } = {}
	local emTeste = false
	for i = 1, RECENTES do
		local quadro = Kit.novo("Frame", {
			Name = "Giro" .. i,
			BackgroundColor3 = Cores.Elevado,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 28 + (i - 1) * 36),
			Size = UDim2.new(1, -16, 0, 32),
			Visible = false,
			Parent = feed.conteudo,
		})
		local marca = IconeImagem.criar(
			quadro,
			Icones.STATUS.Despertar,
			UDim2.fromOffset(4, 8),
			UDim2.fromOffset(16, 16)
		)
		local nome = texto(quadro, {
			fonte = "titulo",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -100, 1, 0),
		})
		local chance = texto(quadro, {
			fonte = "mono",
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -74, 0, 0),
			Size = UDim2.new(0, 66, 1, 0),
		})
		linhas[i] = { quadro = quadro, nome = nome, chance = chance, marca = marca }
	end

	-- ================================================================ barra de atalhos
	local barraAcoes = Kit.novo("Frame", {
		Name = "Acoes",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(600, 160),
		Parent = hud,
	})
	local escalaBarra = Kit.novo("UIScale", { Parent = barraAcoes })

	type Espaco = {
		placa: Kit.Placa,
		simbolo: Frame,
		titulo: TextLabel,
		valor: TextLabel,
		botao: TextButton,
	}
	local function espaco(
		numero: string,
		x: number,
		titulo: string,
		simbolo: number,
		acao: () -> ()
	): Espaco
		local p = Kit.placa({
			nome = "Espaco" .. numero,
			tamanho = UDim2.fromOffset(100, 108),
			ancora = Vector2.new(0.5, 1),
			posicao = UDim2.new(0.5, x, 1, 0),
			corte = 12,
			pai = barraAcoes,
		})
		local simb = IconeImagem.criar(
			p.conteudo,
			simbolo,
			UDim2.new(0.5, 0, 0, 9),
			UDim2.fromOffset(38, 38)
		)
		simb.AnchorPoint = Vector2.new(0.5, 0)
		local tit = texto(p.conteudo, {
			Text = titulo,
			TextSize = 12,
			TextColor3 = Cores.TextoSuave,
			Position = UDim2.fromOffset(4, 52),
			Size = UDim2.new(1, -8, 0, 16),
		})
		local val = texto(p.conteudo, {
			fonte = "titulo",
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(4, 70),
			Size = UDim2.new(1, -8, 0, 22),
		})
		selo(p.quadro, numero)
		local b = Kit.alvo(p.quadro, titulo, acao)
		animarToque(p.quadro, b)
		return { placa = p, simbolo = simb, titulo = tit, valor = val, botao = b }
	end
	local espAura = espaco("1", -246, "AURA", Icones.MENU.Aura, op.aoAbrirIndice)
	local espAuto = espaco("2", -136, "AUTO", Icones.MENU.Auto, op.aoAlternarAuto)
	local espIndice = espaco("3", 136, "ÍNDICE", Icones.MENU.Indice, op.aoAbrirIndice)
	local espArtefato = espaco("4", 246, "ARTEFATO", Icones.MENU.Artefato, op.aoAbrirInventario)
	espIndice.placa.definirCor(Cores.Painel, DESTAQUE.Indice)
	local progresso = barra(
		espIndice.placa.conteudo,
		Cores.Lilas,
		UDim2.new(0, 10, 1, -9),
		UDim2.new(1, -20, 0, 3)
	)

	-- Botão DESPERTAR (a órbita original: anel de recarga em volta do cristal)
	local giro = Kit.novo("Frame", {
		Name = "Despertar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(134, 160),
		Parent = barraAcoes,
	})
	local orbita = Kit.novo("Frame", {
		Name = "Orbita",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(126, 126),
		Parent = giro,
	})
	local anel = Kit.anel(orbita, 126, Cores.Lilas, Cores.Borda, 1)
	local disco = Kit.circulo({
		BackgroundColor3 = Cores.Fundo,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(116, 116),
		ZIndex = 2,
		Parent = orbita,
	})
	Kit.novo("UIStroke", { Color = Cores.Elevado, Thickness = 1, Parent = disco })
	for i = 0, 7 do
		local graus = 45 * i
		local rad = math.rad(graus)
		Kit.novo("Frame", {
			BackgroundColor3 = if i % 2 == 0 then Cores.Lilas else Cores.Borda,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(63 + 60 * math.sin(rad), 63 - 60 * math.cos(rad)),
			Size = UDim2.fromOffset(2, if i % 2 == 0 then 11 else 6),
			Rotation = graus,
			ZIndex = 3,
			Parent = orbita,
		})
	end
	local cristal, centro = Kit.cristal(disco, 64, Cores.Lilas)
	cristal.AnchorPoint = Vector2.new(0.5, 0.5)
	cristal.Position = UDim2.fromScale(0.5, 0.46)
	local carga = texto(disco, {
		fonte = "mono",
		TextSize = 18,
		TextColor3 = Cores.Menta,
		Position = UDim2.new(0, 0, 1, -36),
		Size = UDim2.new(1, 0, 0, 24),
	})
	local etiqueta = Kit.placa({
		tamanho = UDim2.new(1, 0, 0, 40),
		fundo = Cores.Elevado,
		borda = Cores.Lilas,
		ancora = Vector2.new(0, 1),
		posicao = UDim2.fromScale(0, 1),
		z = 3,
		pai = giro,
	})
	local rotuloGiro = texto(etiqueta.conteudo, {
		fonte = "titulo",
		Text = "DESPERTAR",
		TextSize = 26,
		TextWrapped = true,
		Position = UDim2.fromOffset(5, 0),
		Size = UDim2.new(1, -10, 1, 0),
	})
	local tecla = Kit.placa({
		nome = "Atalho",
		tamanho = UDim2.fromOffset(28, 28),
		posicao = UDim2.new(1, -8, 0, 0),
		corte = 5,
		z = 4,
		pai = giro,
	})
	texto(
		tecla.conteudo,
		{ fonte = "mono", Text = "E", TextSize = 16, Size = UDim2.fromScale(1, 1) }
	)
	local giroBotao = Kit.alvo(giro, "Despertar", op.aoDespertar)
	animarToque(orbita, giroBotao)
	giroBotao.NextSelectionLeft = espAuto.botao
	giroBotao.NextSelectionRight = espIndice.botao
	espAura.botao.NextSelectionRight = espAuto.botao
	espAura.botao.NextSelectionLeft = ajustesBotao
	espAuto.botao.NextSelectionLeft = espAura.botao
	espAuto.botao.NextSelectionRight = giroBotao
	espIndice.botao.NextSelectionLeft = giroBotao
	espIndice.botao.NextSelectionRight = espArtefato.botao
	espArtefato.botao.NextSelectionLeft = espIndice.botao

	-- Teclas 1–4 (Alt continua reservado aos testes do Studio)
	UserInputService.InputBegan:Connect(function(input, processado)
		if
			processado
			or not hud.Visible
			or Navegacao.aberto()
			or UserInputService:GetFocusedTextBox()
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
		then
			return
		end
		local acao = ({
			[Enum.KeyCode.One] = op.aoAbrirIndice,
			[Enum.KeyCode.Two] = op.aoAlternarAuto,
			[Enum.KeyCode.Three] = op.aoAbrirIndice,
			[Enum.KeyCode.Four] = op.aoAbrirInventario,
		} :: { [Enum.KeyCode]: () -> () })[input.KeyCode]
		if acao then
			acao()
		end
	end)

	-- ================================================================ resultado do giro
	local resultado = Kit.placa({
		nome = "Resultado",
		tamanho = UDim2.fromOffset(446, 52),
		ancora = Vector2.new(0.5, 1),
		posicao = UDim2.new(0.5, 0, 0, -16),
		pai = barraAcoes,
	})
	resultado.quadro.Visible = false
	local textoResultado = texto(resultado.conteudo, {
		fonte = "titulo",
		TextSize = 21,
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
		feed.quadro.Size = UDim2.fromOffset(258, 32 + 36 * #lista)
		for i, linha in linhas do
			local g = lista[i]
			linha.quadro.Visible = g ~= nil
			if g then
				linha.nome.Text = g.aura.nome
				linha.chance.Text = "1/" .. Formato.chanceCurta(g.chance)
				IconeImagem.definir(linha.marca, Icones.STATUS.Despertar, corTier(g.aura))
			end
		end
	end

	local function ajustarRotuloGiro()
		local longo = estadoGiro == "perfil" or estadoGiro == "pedido"
		rotuloGiro.TextSize = if longo then 16 elseif Escala.compacto then 22 else 26
	end

	Escala.aoMudar(function()
		local compacto = Escala.compacto
		local tela = Escala.tamanho
		local estreito = tela.X < 760
		local horizontal = estreito or tela.Y < 610
		local escalaMaxima = if estreito then 0.7 elseif compacto then 0.85 else 1
		escalaBarra.Scale = math.min(escalaMaxima, math.max(0.25, (tela.X - 24) / 600))
		local margem = if Escala.toque then 26 else 22
		barraAcoes.Position =
			UDim2.new(0.5, if Escala.toque and not estreito then -60 else 0, 1, -margem)
		local lado = if horizontal
			then math.min(56, math.floor((tela.X - 44) / #placasMenu))
			elseif compacto then 60
			else 78
		local folga = if horizontal or compacto then 5 else 8
		local total = (lado + folga) * #placasMenu - folga
		for _, p in placasMenu do
			p.quadro.Size = UDim2.fromOffset(lado, lado)
		end
		listaMenu.FillDirection = if horizontal
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		listaMenu.Padding = UDim.new(0, folga)
		menu.AnchorPoint = Vector2.new(0, if horizontal then 0 else 0.5)
		menu.Size = if horizontal
			then UDim2.fromOffset(total, lado)
			else UDim2.fromOffset(lado + 2, total)
		menu.Position = if horizontal
			then UDim2.fromOffset(12, if compacto then 154 else 162)
			else UDim2.new(0, if compacto then 12 else 22, 0.5, 64)
		for i, b in botoesMenu do
			b.NextSelectionUp = if horizontal then nil else botoesMenu[i - 1]
			b.NextSelectionDown = if horizontal then nil else botoesMenu[i + 1]
			b.NextSelectionLeft = if horizontal then botoesMenu[i - 1] else nil
			b.NextSelectionRight = if horizontal then botoesMenu[i + 1] else nil
		end
		-- em tela estreita o painel de pontos desce para debaixo das moedas
		painelPontos.quadro.Size =
			UDim2.fromOffset(if estreito then math.min(300, tela.X - 24) else 320, 62)
		painelPontos.quadro.AnchorPoint = if estreito
			then Vector2.new(0, 0)
			else Vector2.new(0.5, 0)
		painelPontos.quadro.Position = if estreito
			then UDim2.fromOffset(12, if compacto then 154 + 62 else 162 + 62)
			else UDim2.new(0.5, 0, 0, if compacto then 10 else 14)
		local largura = if estreito then math.min(250, tela.X - 24) else 336
		moedas.Size = UDim2.fromOffset(largura, 40)
		cartao.quadro.Size = UDim2.fromOffset(largura, 92)
		cartao.quadro.Position =
			UDim2.fromOffset(if compacto then 12 else 22, if compacto then 10 else 16)
		moedas.Position =
			UDim2.fromOffset(if compacto then 12 else 22, if compacto then 108 else 116)
		for _, p in placasMoeda do
			p.quadro.Size = UDim2.fromOffset((largura - 8) / 2, 40)
		end
		tecla.quadro.Visible = Escala.teclado and (estadoGiro == "pronto" or estadoGiro == "pular")
		ajustarRotuloGiro()
		atualizarFeed()
	end)

	return {
		quadro = hud,
		definirGiro = function(fracao: number, falta: number, estado: EstadoGiro)
			local carregando = estado == "recarregando"
			local disponivel = estado == "pronto" or estado == "pular"
			anel.definir(
				fracao,
				if carregando then Cores.Menta elseif disponivel then Cores.Lilas else Cores.Borda
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
				elseif estado == "pular" then "Pular ritual"
				else "DESPERTAR"
			rotuloGiro.Text = titulo
			giroBotao.Text = titulo
			giroBotao.Interactable = disponivel
			tecla.quadro.Visible = Escala.teclado and disponivel
			centro.BackgroundColor3 = if disponivel or carregando then Cores.Lilas else Cores.Borda
			etiqueta.definirCor(
				if disponivel then Cores.Lilas else Cores.Elevado,
				if disponivel then Cores.Lilas else Cores.Borda
			)
			rotuloGiro.TextColor3 = if disponivel then Cores.Fundo else Cores.Texto
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
			-- Fragmentos do Corredor dos Perdidos (compram pets); os das Incursões ficam guardados
			local corredor = (estado :: any).corredor
			local frag = if type(corredor) == "table" then corredor.fragmentos or 0 else 0
			fragmentos.Text = if frag < 1000000 then Formato.inteiro(frag) else Formato.curto(frag)
			textoTrans.Text = "T" .. estado.transcendencia.nivel

			local bruto = (estado :: any).temporada
			local t = Temporada.de(if type(bruto) == "table" then table.clone(bruto) else nil)
			local nivel = Temporada.nivel(t.xp)
			textoTemporada.Text = string.format("PASSE DE TEMPORADA · NV %d", nivel)
			barraTemporada.Size = UDim2.fromScale(
				if nivel >= Temporada.NIVEIS
					then 1
					else (t.xp - nivel * Temporada.XP_POR_NIVEL) / Temporada.XP_POR_NIVEL,
				1
			)

			-- 1 · aura equipada (borda e nome na cor da raridade)
			local aura = if estado.equipada then Auras.porId[estado.equipada] else nil
			if aura then
				local cor = corTier(aura)
				espAura.placa.definirCor(Cores.Painel, cor)
				IconeImagem.definir(espAura.simbolo, Icones.aura(aura.estilo))
				espAura.valor.Text = aura.nome
				espAura.valor.TextColor3 = Kit.corLegivel(cor)
				espAura.titulo.Text = "1 em "
					.. Formato.chanceCurta(Auras.chanceEfetiva(aura, PontosAura.sorteTotal(estado)))
			else
				espAura.placa.definirCor(Cores.Painel, Cores.Borda)
				IconeImagem.definir(espAura.simbolo, Icones.MENU.Aura)
				espAura.valor.Text = "Nenhuma"
				espAura.valor.TextColor3 = Cores.TextoSuave
				espAura.titulo.Text = "AURA"
			end

			-- 2 · giro automático (menta quando ligado, como no HUD original)
			local ligado = estado.configuracoes.giroAutomatico == true
			espAuto.placa.definirCor(
				if ligado then Cores.Ativo else Cores.Painel,
				if ligado then Cores.Menta else Cores.Borda
			)
			espAuto.valor.Text = if ligado then "Ligado" else "Desligado"
			espAuto.valor.TextColor3 = if ligado then Cores.Menta else Cores.Texto
			espAuto.botao.Text = "Giro automático · " .. espAuto.valor.Text

			-- 3 · índice
			local descobertas = Auras.contarDescobertas(estado.auras)
			espIndice.valor.Text = string.format("%d / %d", descobertas, #Auras.lista)
			progresso.Size = UDim2.fromScale(descobertas / #Auras.lista, 1)

			-- 4 · artefato equipado
			local artefato = estado.inventario.equipados.artefato
			local item = if artefato then Itens.porId[artefato] else nil
			if item then
				local cor = Color3.fromHex(Itens.Tiers[item.raridade].cor)
				espArtefato.placa.definirCor(Cores.Painel, cor)
				IconeImagem.definir(
					espArtefato.simbolo,
					Icones.item(artefato :: string, item.categoria)
				)
				espArtefato.valor.Text = item.nome
				espArtefato.valor.TextColor3 = Kit.corLegivel(cor)
			else
				espArtefato.placa.definirCor(Cores.Painel, Cores.Borda)
				IconeImagem.definir(espArtefato.simbolo, Icones.MENU.Artefato)
				espArtefato.valor.Text = "Vazio"
				espArtefato.valor.TextColor3 = Cores.TextoSuave
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
				if nova then "Nova · " else "",
				aura.nome,
				Formato.chance(chance)
			)
			resultado.definirCor(Cores.Painel, corTier(aura))
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
