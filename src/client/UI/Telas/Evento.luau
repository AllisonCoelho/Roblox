-- Interface do evento Despertar do Sol (regras em Shared/Dados/EventoSol; o servidor decide).
--   faixa do topo   espera: "☀ Despertar do Sol em 12:40" + botão dos baús
--                   aviso:  faixa dourada pulsando com a contagem e "vá para a praça"
--                   luta:   barra de vida grande do Titã de Borracha, tempo e o seu dano
--                   fim:    resultado
--   ranking         top 5 de dano durante a luta (canto direito)
--   painel Baús     os dois baús, chances, garantia da Gear 5 e a abertura com roleta
--   anúncio         quando alguém do servidor tira a Gear 5, todo mundo vê a faixa
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EventoSol = require(Shared.Dados.EventoSol)
local Remotos = require(Shared.Remotos)
local Cores = require(Shared.Tema).Orbita
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Sons = require(script.Parent.Parent.Parent.Mundo.Sons)

local Tela = {}

local OURO = Color3.fromHex("FFD54A")
local OURO_CLARO = Color3.fromHex("FFF1B0")
local OURO_ESCURO = Color3.fromHex("8A5A00")
local BRANCO = Color3.new(1, 1, 1)
local MARROM = Color3.fromHex("3A2200")

-- Como cada prêmio aparece na roleta e no resultado
local PREMIOS = {
	gear5 = { nome = "AURA GEAR 5", cor = BRANCO, fundo = OURO, marca = "☀" },
	ras_nuvem_sol = {
		nome = "Rastro Nuvem do Sol",
		cor = MARROM,
		fundo = Color3.fromHex("FFF6DA"),
		marca = "~",
	},
	tit_libertado = {
		nome = "Título Libertado",
		cor = MARROM,
		fundo = Color3.fromHex("FFE8A0"),
		marca = "★",
	},
	pontos = { nome = "Pontos de Aura", cor = Cores.Fundo, fundo = Cores.Menta, marca = "+" },
	fragmentos = { nome = "Fragmentos", cor = Cores.Fundo, fundo = Cores.Lilas, marca = "+" },
} :: { [string]: { nome: string, cor: Color3, fundo: Color3, marca: string } }

local raiz: Frame
local hudQuadro: GuiObject
local aviso: (string) -> ()

local function som(nome: string, tom: number?, volume: number?)
	local camera = Workspace.CurrentCamera
	if camera then
		Sons.tocar(nome, camera, tom, volume)
	end
end

local function cantos(pai: Instance, raio: number?)
	Kit.novo("UICorner", { CornerRadius = UDim.new(0, raio or 10), Parent = pai })
end

local function borda(pai: Instance, cor: Color3, espessura: number): UIStroke
	return Kit.novo("UIStroke", {
		Color = cor,
		Thickness = espessura,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = pai,
	})
end

local function degradeOuro(pai: Instance): UIGradient
	return Kit.novo("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("FFB52E")),
			ColorSequenceKeypoint.new(0.5, OURO_CLARO),
			ColorSequenceKeypoint.new(1, Color3.fromHex("FFB52E")),
		}),
		Parent = pai,
	})
end

local function contornoTexto(rotulo: TextLabel, cor: Color3, espessura: number)
	Kit.novo("UIStroke", {
		Color = cor,
		Thickness = espessura,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = rotulo,
	})
end

-- ============================================================ faixa do topo

local faixa: Frame
local faixaGradiente: UIGradient
local faixaTitulo: TextLabel
local faixaSub: TextLabel
local barraFundo: Frame
local barraVida: Frame
local barraTexto: TextLabel
local chipEspera: Frame
local chipTexto: TextLabel
local botaoBaus: TextButton
local botaoBausTexto: TextLabel
local ranking: Frame
local linhasRanking: { TextLabel } = {}
local meuDano = 0
local cicloDoMeuDano = -1

local function montarFaixa()
	-- espera: chip discreto + botão dos baús
	chipEspera = Kit.novo("Frame", {
		Name = "EventoEspera",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 116),
		Size = UDim2.fromOffset(320, 30),
		BackgroundColor3 = Color3.fromHex("2A2110"),
		Parent = hudQuadro,
	})
	cantos(chipEspera, 15)
	borda(chipEspera, OURO, 1.5)
	chipTexto = Kit.texto({
		fonte = "titulo",
		RichText = true,
		TextSize = 15,
		TextColor3 = OURO_CLARO,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Parent = chipEspera,
	})
	Kit.alvo(chipEspera, "Evento", function()
		Navegacao.abrir("Baus")
	end)

	botaoBaus = Kit.novo("TextButton", {
		Name = "Baus",
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, 168, 0, 116),
		Size = UDim2.fromOffset(118, 30),
		BackgroundColor3 = OURO,
		Visible = false,
		Parent = hudQuadro,
	})
	cantos(botaoBaus, 15)
	borda(botaoBaus, BRANCO, 2)
	degradeOuro(botaoBaus)
	botaoBausTexto = Kit.texto({
		fonte = "titulo",
		TextSize = 15,
		TextColor3 = MARROM,
		Size = UDim2.fromScale(1, 1),
		Parent = botaoBaus,
	})
	botaoBaus.Activated:Connect(function()
		Navegacao.abrir("Baus")
	end)

	-- aviso / luta / fim: faixa grande dourada
	faixa = Kit.novo("Frame", {
		Name = "EventoFaixa",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 114),
		Size = UDim2.fromOffset(560, 84),
		BackgroundColor3 = OURO,
		Visible = false,
		Parent = hudQuadro,
	})
	cantos(faixa, 14)
	borda(faixa, BRANCO, 3)
	faixaGradiente = degradeOuro(faixa)
	faixaTitulo = Kit.texto({
		fonte = "titulo",
		TextSize = 30,
		TextColor3 = BRANCO,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 38),
		Parent = faixa,
	})
	contornoTexto(faixaTitulo, OURO_ESCURO, 2.5)
	faixaSub = Kit.texto({
		fonte = "titulo",
		TextSize = 17,
		TextColor3 = MARROM,
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 0, 30),
		Parent = faixa,
	})
	barraFundo = Kit.novo("Frame", {
		Name = "Vida",
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, 26),
		BackgroundColor3 = Color3.fromHex("5A3A06"),
		Visible = false,
		Parent = faixa,
	})
	cantos(barraFundo, 13)
	borda(barraFundo, BRANCO, 2)
	barraVida = Kit.novo("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BRANCO,
		Parent = barraFundo,
	})
	cantos(barraVida, 13)
	Kit.novo("UIGradient", {
		Color = ColorSequence.new(Color3.fromHex("FFFFFF"), Color3.fromHex("FFE27A")),
		Rotation = 90,
		Parent = barraVida,
	})
	barraTexto = Kit.texto({
		fonte = "titulo",
		TextSize = 16,
		TextColor3 = MARROM,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = barraFundo,
	})

	-- ranking (canto direito)
	ranking = Kit.novo("Frame", {
		Name = "EventoRanking",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 170),
		Size = UDim2.fromOffset(250, 186),
		BackgroundColor3 = Color3.fromHex("1E170A"),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = hudQuadro,
	})
	cantos(ranking, 12)
	borda(ranking, OURO, 2)
	local titulo = Kit.texto({
		fonte = "titulo",
		Text = "☀ QUEM MAIS BATEU",
		TextSize = 16,
		TextColor3 = OURO,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = ranking,
	})
	titulo.Name = "Titulo"
	for i = 1, 6 do
		local l = Kit.texto({
			RichText = true,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(12, 6 + i * 25),
			Size = UDim2.new(1, -24, 0, 22),
			Parent = ranking,
		})
		linhasRanking[i] = l
	end
end

local function numero(n: number): string
	local s = tostring(math.floor(n))
	local formatado = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (formatado:gsub("^%.", ""))
end

local function lerRanking(): { { id: number, nome: string, dano: number } }
	local bruto = Workspace:GetAttribute("EventoRanking")
	if type(bruto) ~= "string" or bruto == "" then
		return {}
	end
	local ok, lista = pcall(HttpService.JSONDecode, HttpService, bruto)
	return if ok and type(lista) == "table" then lista else {}
end

local function atualizarRanking(visivel: boolean)
	ranking.Visible = visivel
	if not visivel then
		return
	end
	local eu = Players.LocalPlayer.UserId
	local lista = lerRanking()
	local estou = false
	for i = 1, 5 do
		local l = lista[i]
		local rotulo = linhasRanking[i]
		if l and type(l.dano) == "number" then
			local meu = l.id == eu
			estou = estou or meu
			local cor = if i <= EventoSol.TOP_DOURADO then "#FFD54A" else "#F7F2EC"
			rotulo.Text = string.format(
				'<font color="%s"><b>%d.</b></font> %s%s  <font color="#C9C7D6">%s</font>',
				cor,
				i,
				if meu then "<b>" else "",
				tostring(l.nome or "?") .. (if meu then "</b>" else ""),
				numero(l.dano)
			)
		else
			rotulo.Text = ""
		end
	end
	linhasRanking[6].Text = if estou
		then '<font color="#B7FFD9">Você está no top! Top 3 ganha o Baú Dourado</font>'
		else string.format('<font color="#B7FFD9">Seu dano: %s</font>', numero(meuDano))
end

local function tita(): BasePart?
	local pasta = Workspace:FindFirstChild("EventoSol")
	local t = pasta and pasta:FindFirstChild("Tita")
	return if t and t:IsA("BasePart") then t else nil
end

local function atualizarFaixa(agora: number)
	local fase = Workspace:GetAttribute("EventoFase")
	local fim = tonumber(Workspace:GetAttribute("EventoFim")) or 0
	local resta = math.max(0, fim - Workspace:GetServerTimeNow())
	local estado = Estado.atual :: any
	local ev = estado and estado.evento
	local baus = if ev then (ev.sol or 0) + (ev.dourado or 0) else 0

	botaoBaus.Visible = baus > 0 and fase ~= "luta"
	botaoBausTexto.Text = string.format("ABRIR BAÚS (%d)", baus)
	botaoBaus.Rotation = if baus > 0 then math.sin(agora * 6) * 2 else 0

	if fase == "aviso" or fase == "luta" or fase == "fim" then
		chipEspera.Visible = false
		faixa.Visible = true
		faixaGradiente.Offset = Vector2.new(math.sin(agora * 1.5) * 0.4, 0)
		if fase == "aviso" then
			local pulso = 1 + 0.04 * math.sin(agora * 8)
			faixa.Size = UDim2.fromOffset(560 * pulso, 84 * pulso)
			faixaTitulo.Text = "☀ O SOL ESTÁ DESPERTANDO " .. EventoSol.tempo(resta)
			faixaSub.Text = "O Titã de Borracha vai cair na praça! Corra para lá"
			faixaSub.Visible = true
			barraFundo.Visible = false
		elseif fase == "luta" then
			faixa.Size = UDim2.fromOffset(560, 84)
			local t = tita()
			local vida = t and tonumber(t:GetAttribute("Vida")) or 0
			local max = t and tonumber(t:GetAttribute("VidaMax")) or 1
			local fracao = math.clamp(vida / math.max(max, 1), 0, 1)
			faixaTitulo.Text = "TITÃ DE BORRACHA · " .. EventoSol.tempo(resta)
			faixaSub.Visible = false
			barraFundo.Visible = true
			barraVida.Size = UDim2.fromScale(fracao, 1)
			barraTexto.Text = string.format("%s / %s", numero(vida), numero(max))
		else
			faixa.Size = UDim2.fromOffset(560, 84)
			barraFundo.Visible = false
			faixaSub.Visible = true
			if Workspace:GetAttribute("EventoResultado") == "derrotado" then
				faixaTitulo.Text = "☀ TITÃ DERROTADO!"
				faixaSub.Text = "Quem ajudou ganhou um Baú do Sol. Top 3: Baú Dourado!"
			else
				faixaTitulo.Text = "O Titã escapou..."
				faixaSub.Text = "Quem ajudou ainda ganhou um Baú do Sol. Volte em 30 minutos!"
			end
		end
	else
		faixa.Visible = false
		chipEspera.Visible = true
		chipTexto.Text = string.format(
			'☀ Despertar do Sol em <font color="#FFFFFF">%s</font>  ·  baú com Gear 5',
			EventoSol.tempo(resta)
		)
	end
	atualizarRanking(fase == "luta" or fase == "fim")
end

-- ============================================================ anúncio da Gear 5

local function anunciarGear5(nome: string, eu: boolean)
	local f = Kit.novo("Frame", {
		Name = "AnuncioGear5",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = BRANCO,
		ZIndex = 60,
		Parent = raiz,
	})
	local g = degradeOuro(f)
	local t = Kit.texto({
		fonte = "titulo",
		Text = if eu
			then "☀ VOCÊ DESPERTOU A GEAR 5! ☀"
			else string.format("☀ %s DESPERTOU A GEAR 5! ☀", string.upper(nome)),
		TextSize = 44,
		TextColor3 = BRANCO,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 61,
		Parent = f,
	})
	contornoTexto(t, OURO_ESCURO, 3)
	TweenService:Create(
		f,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, 0, 0, 96) }
	):Play()
	som("revelacao", 1, 0.8)
	som("ruptura", 1.2, 0.5)
	local inicio = os.clock()
	local con = RunService.RenderStepped:Connect(function()
		g.Offset = Vector2.new(math.sin((os.clock() - inicio) * 4) * 0.5, 0)
	end)
	task.delay(5.5, function()
		local tw = TweenService:Create(f, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) })
		tw:Play()
		tw.Completed:Wait()
		con:Disconnect()
		f:Destroy()
	end)
end

-- ============================================================ painel dos baús

local painel: Navegacao.Painel
type Cartao = { quantidade: TextLabel, botao: TextButton, rotulo: TextLabel }
local cartoes: { [string]: Cartao } = {}
local garantia: TextLabel
local abrindo = false
local palco: Frame -- área da roleta e do resultado

local function cartaoBau(tipo: string, x: number)
	local bau = EventoSol.BAUS[tipo]
	local dourado = tipo == "dourado"
	local c = Kit.novo("Frame", {
		Name = "Bau_" .. tipo,
		Position = UDim2.new(x, if x == 0 then 0 else 10, 0, 0),
		Size = UDim2.new(0.5, -10, 0, 300),
		BackgroundColor3 = if dourado then Color3.fromHex("3A2A08") else Color3.fromHex("2A2210"),
		Parent = painel.conteudo,
	})
	cantos(c, 12)
	borda(c, if dourado then BRANCO else OURO, 2)
	-- baú desenhado com quadros (tampa, corpo, fecho)
	local icone = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(84, 72),
		Parent = c,
	})
	local corpo = Kit.novo("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.fromOffset(84, 42),
		BackgroundColor3 = if dourado then OURO else Color3.fromHex("C07A2A"),
		Parent = icone,
	})
	cantos(corpo, 6)
	borda(corpo, MARROM, 2)
	local tampa = Kit.novo("Frame", {
		Position = UDim2.fromOffset(-2, 8),
		Size = UDim2.fromOffset(88, 26),
		BackgroundColor3 = if dourado then BRANCO else OURO,
		Parent = icone,
	})
	cantos(tampa, 10)
	borda(tampa, MARROM, 2)
	local fecho = Kit.novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(42, 34),
		Size = UDim2.fromOffset(16, 18),
		BackgroundColor3 = if dourado then Color3.fromHex("FFB52E") else BRANCO,
		ZIndex = 2,
		Parent = icone,
	})
	cantos(fecho, 4)
	Kit.texto({
		fonte = "titulo",
		Text = string.upper(bau.nome),
		TextSize = 24,
		TextColor3 = if dourado then BRANCO else OURO,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(114, 16),
		Size = UDim2.new(1, -124, 0, 30),
		Parent = c,
	})
	local quantidade = Kit.texto({
		TextSize = 17,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(114, 48),
		Size = UDim2.new(1, -124, 0, 24),
		Parent = c,
	})
	Kit.texto({
		TextSize = 14,
		TextColor3 = Cores.TextoSuave,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = if dourado
			then "Para os 3 que mais batem no Titã (se ele cair)."
			else "Para todo mundo que ajuda no evento.",
		Position = UDim2.fromOffset(114, 72),
		Size = UDim2.new(1, -124, 0, 22),
		Parent = c,
	})
	-- chances
	local chances = EventoSol.chances(tipo)
	for i, it in bau.itens do
		local visual = PREMIOS[it.id]
		local linha = Kit.texto({
			RichText = true,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format(
				'<font color="#%s"><b>%s</b></font>  <font color="#FFFFFF">%s%%</font>',
				if it.id == "gear5" then "FFD54A" else "F7F2EC",
				visual.nome,
				tostring(math.floor(chances[it.id] * 1000 + 0.5) / 10)
			),
			Position = UDim2.fromOffset(18, 100 + (i - 1) * 26),
			Size = UDim2.new(1, -36, 0, 24),
			Parent = c,
		})
		linha.Name = it.id
	end
	local botao = Kit.novo("TextButton", {
		Name = "Abrir",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -32, 0, 44),
		BackgroundColor3 = OURO,
		Parent = c,
	})
	cantos(botao, 10)
	borda(botao, BRANCO, 2)
	degradeOuro(botao)
	local rotulo = Kit.texto({
		fonte = "titulo",
		Text = "ABRIR",
		TextSize = 22,
		TextColor3 = MARROM,
		Size = UDim2.fromScale(1, 1),
		Parent = botao,
	})
	cartoes[tipo] = { quantidade = quantidade, botao = botao, rotulo = rotulo }
	return botao
end

local function atualizarPainel()
	local estado = Estado.atual :: any
	local ev = estado and estado.evento or EventoSol.padrao()
	for tipo, c in cartoes do
		local n = ev[tipo] or 0
		c.quantidade.Text = string.format("Você tem %d", n)
		c.rotulo.Text = if n > 0 then "ABRIR" else "GANHE NO EVENTO"
		c.botao.AutoButtonColor = n > 0
	end
	garantia.Text = string.format(
		'☀ Gear 5 garantida em no máximo <font color="#FFD54A"><b>%d</b></font> baús  ·  baús abertos: %d  ·  Gear 5 que você já tirou: %d',
		EventoSol.faltaGarantia(EventoSol.normalizar(ev)),
		ev.abertos or 0,
		ev.gear5 or 0
	)
end

-- Ladrilho da roleta
local LADRILHO = 132
local LARGURA_JANELA = 900 - 48 - 20 -- painel menos margens (pixels de design)
local function ladrilho(pai: Instance, premio: string, i: number): Frame
	local v = PREMIOS[premio] or PREMIOS.pontos
	local f = Kit.novo("Frame", {
		Position = UDim2.fromOffset((i - 1) * LADRILHO, 6),
		Size = UDim2.fromOffset(LADRILHO - 10, 108),
		BackgroundColor3 = v.fundo,
		Parent = pai,
	})
	cantos(f, 10)
	borda(f, if premio == "gear5" then BRANCO else MARROM, if premio == "gear5" then 3 else 1)
	Kit.texto({
		fonte = "titulo",
		Text = v.marca,
		TextSize = 40,
		TextColor3 = v.cor,
		Size = UDim2.new(1, 0, 0, 56),
		Parent = f,
	})
	Kit.texto({
		fonte = "titulo",
		Text = v.nome,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = v.cor,
		Position = UDim2.fromOffset(4, 54),
		Size = UDim2.new(1, -8, 0, 48),
		Parent = f,
	})
	return f
end

local function sortearFiller(tipo: string): string
	local bau = EventoSol.BAUS[tipo]
	local total = 0
	for _, it in bau.itens do
		-- na roleta a Gear 5 aparece mais (só enfeite: o prêmio vem do servidor)
		total += if it.id == "gear5" then 8 else it.peso
	end
	local r = math.random() * total
	for _, it in bau.itens do
		local p = if it.id == "gear5" then 8 else it.peso
		if r < p then
			return it.id
		end
		r -= p
	end
	return "pontos"
end

local function texto(dados: { [string]: any }): string
	local v = PREMIOS[dados.premio] or PREMIOS.pontos
	if dados.premio == "pontos" then
		return string.format("+%s Pontos de Aura", numero(tonumber(dados.quantidade) or 0))
	elseif dados.premio == "fragmentos" then
		return string.format("+%s Fragmentos", numero(tonumber(dados.quantidade) or 0))
	elseif dados.premio == "gear5" then
		return "AURA GEAR 5! Equipe no seu Inventário"
	end
	return v.nome .. " (equipe no Inventário)"
end

-- Roleta: os ladrilhos passam e param no prêmio que o servidor já decidiu
local function roleta(tipo: string, dados: { [string]: any })
	for _, f in palco:GetChildren() do
		if not f:IsA("UICorner") and not f:IsA("UIStroke") then
			f:Destroy()
		end
	end
	palco.Visible = true
	local janela = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 120),
		Parent = palco,
	})
	local fita = Kit.novo(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = janela }
	)
	local ALVO = 34
	for i = 1, ALVO + 4 do
		ladrilho(fita, if i == ALVO then dados.premio else sortearFiller(tipo), i)
	end
	-- marcador no meio
	local marcador = Kit.novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(4, 120),
		BackgroundColor3 = BRANCO,
		ZIndex = 5,
		Parent = janela,
	})
	borda(marcador, OURO, 2)
	local resultado = Kit.texto({
		fonte = "titulo",
		Text = "",
		TextSize = 26,
		TextColor3 = OURO,
		Position = UDim2.fromOffset(10, 132),
		Size = UDim2.new(1, -20, 0, 34),
		Parent = palco,
	})
	local largura = LARGURA_JANELA
	local desvio = math.random(-40, 40)
	local final = -((ALVO - 1) * LADRILHO + (LADRILHO - 10) / 2 - largura / 2 + desvio)
	local duracao = if dados.premio == "gear5" then 5 else 3.6
	local inicio = os.clock()
	local ultimoLadrilho = 0
	while true do
		local t = math.clamp((os.clock() - inicio) / duracao, 0, 1)
		local e = 1 - (1 - t) ^ 4
		local x = final * e
		fita.Position = UDim2.fromOffset(x, 0)
		local passou = math.floor(-x / LADRILHO)
		if passou ~= ultimoLadrilho then
			ultimoLadrilho = passou
			som("batida", 1.4, 0.25)
		end
		if t >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	-- encaixa exatamente no prêmio e revela
	local ajuste = -((ALVO - 1) * LADRILHO + (LADRILHO - 10) / 2 - largura / 2)
	TweenService:Create(fita, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Position = UDim2.fromOffset(ajuste, 0),
	}):Play()
	task.wait(0.3)
	local flash = Kit.novo("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BRANCO,
		ZIndex = 20,
		Parent = palco,
	})
	cantos(flash, 12)
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.delay(0.65, function()
		flash:Destroy()
	end)
	resultado.Text = texto(dados)
	resultado.TextColor3 = if dados.premio == "gear5" then BRANCO else OURO
	som("revelacao", if dados.premio == "gear5" then 0.9 else 1.2, 0.6)
	if dados.premio ~= "gear5" then
		som("chamado", 1.3, 0.4)
	end
end

local function abrir(tipo: string)
	if abrindo then
		return
	end
	local estado = Estado.atual :: any
	local ev = estado and estado.evento
	if not ev or (ev[tipo] or 0) <= 0 then
		aviso("Ganhe baús batendo no Titã de Borracha no evento Despertar do Sol!")
		return
	end
	abrindo = true
	-- o baú treme enquanto o servidor sorteia
	local c = cartoes[tipo]
	local original = c.botao.Position
	som("instavel", 1.2, 0.4)
	local ok, msg, dados = Estado.pedir("AbrirBau", tipo)
	for i = 1, 6 do
		c.botao.Position = original + UDim2.fromOffset(if i % 2 == 0 then 4 else -4, 0)
		task.wait(0.04)
	end
	c.botao.Position = original
	if not ok or not dados then
		abrindo = false
		aviso(msg or "Não deu para abrir o baú.")
		return
	end
	local okRoleta, erro = pcall(roleta, tipo, dados)
	if not okRoleta then
		warn("[Evento] roleta: " .. tostring(erro))
		aviso(texto(dados))
	end
	abrindo = false
	atualizarPainel()
end

local function montarPainel()
	painel = Navegacao.criarPainel("Baus", {
		titulo = "Baús do Sol",
		icone = "☀",
		dimensoes = Vector2.new(900, 640),
	}, atualizarPainel)
	painel.conteudo.Position = UDim2.fromOffset(24, 100)
	painel.conteudo.Size = UDim2.new(1, -48, 1, -120)
	cartaoBau("sol", 0).Activated:Connect(function()
		task.spawn(abrir, "sol")
	end)
	cartaoBau("dourado", 0.5).Activated:Connect(function()
		task.spawn(abrir, "dourado")
	end)
	garantia = Kit.texto({
		RichText = true,
		TextSize = 15,
		TextColor3 = Cores.TextoSuave,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 306),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = painel.conteudo,
	})
	palco = Kit.novo("Frame", {
		Name = "Roleta",
		Position = UDim2.fromOffset(0, 336),
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundColor3 = Color3.fromHex("1E170A"),
		Visible = false,
		Parent = painel.conteudo,
	})
	cantos(palco, 12)
	borda(palco, OURO, 2)
	atualizarPainel()
end

-- ============================================================ montagem

function Tela.montar(raizUI: Frame, hud: GuiObject, avisar: (string) -> ())
	raiz = raizUI
	hudQuadro = hud
	aviso = avisar
	montarFaixa()
	montarPainel()
	Estado.aoMudar(function()
		atualizarPainel()
	end)
	Remotos.evento("Evento").OnClientEvent:Connect(function(dados: any)
		if type(dados) ~= "table" then
			return
		end
		local eu = Players.LocalPlayer.UserId
		if dados.tipo == "golpes" and type(dados.lista) == "table" then
			local ciclo = math.floor(Workspace:GetServerTimeNow() / EventoSol.PERIODO)
			if ciclo ~= cicloDoMeuDano then
				cicloDoMeuDano = ciclo
				meuDano = 0
			end
			for _, g in dados.lista do
				if type(g) == "table" and g.de == eu and type(g.dano) == "number" then
					meuDano += g.dano
				end
			end
		elseif dados.tipo == "premio" and type(dados.texto) == "string" then
			aviso("☀ " .. dados.texto .. " Toque em ABRIR BAÚS!")
			som("revelacao", 1.1, 0.6)
		elseif dados.tipo == "gear5" and type(dados.nome) == "string" then
			anunciarGear5(dados.nome, dados.de == eu)
		end
	end)
	local ultimo = 0
	RunService.RenderStepped:Connect(function()
		local agora = os.clock()
		if agora - ultimo < 0.1 then
			return
		end
		ultimo = agora
		local ok, erro = pcall(atualizarFaixa, agora)
		if not ok then
			warn("[Evento] " .. tostring(erro))
			ultimo = agora + 10
		end
	end)
end

function Tela.abrir()
	Navegacao.abrir("Baus")
end

return Tela
