-- Interface sempre visível (ver docs/design/05-hud-pc.png e 06-hud-celular.png)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local Evento = require(Shared.Dados.Evento)
local Missoes = require(Shared.Dados.Missoes)
local Presentes = require(Shared.Dados.Presentes)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Escala = require(UI.Escala)
local Visual = require(UI.Visual)
local Avisos = require(UI.Popups.Avisos)

local Cores = Tema.Cores
local HUD = {}

local MARGEM = 28
local BOTAO = 104

export type Acoes = {
	abrir: (nome: string) -> (),
	irParaVitrine: () -> (),
	posicaoVitrine: () -> Vector3?,
}

-- Valores grandes encurtam para caber na pílula
local function moedasTexto(n: number): string
	return if n >= 1e6 then Formato.curto(n) else Formato.inteiro(n)
end

function HUD.montar(raiz: Frame, acoes: Acoes)
	local hud = C.novo(
		"Frame",
		{ Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = raiz }
	)

	-- Moedas e granulados ------------------------------------------------------
	local recursos = C.novo("Frame", {
		Name = "Recursos",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = UDim2.fromOffset(MARGEM + 10, MARGEM),
		Parent = hud,
	})
	local listaRecursos = C.lista(recursos, Enum.FillDirection.Vertical, 14)
	local moedas = C.pilula({
		icone = "🪙",
		corIcone = C.CorIconeMoeda,
		largura = 300,
		ordem = 1,
		pai = recursos,
	})
	local granulados = C.pilula({
		icone = "✨",
		corIcone = C.CorIconeGranulado,
		largura = 240,
		mais = true,
		ordem = 2,
		pai = recursos,
	})
	if granulados.mais then
		granulados.mais.Activated:Connect(function()
			acoes.abrir("Loja")
		end)
	end

	-- Menu principal -----------------------------------------------------------
	local menu = C.novo("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(BOTAO * 2 + 18, BOTAO * 4 + 54),
		Position = UDim2.fromOffset(MARGEM, 200),
		Parent = hud,
	})
	C.novo("UIGridLayout", {
		CellSize = UDim2.fromOffset(BOTAO, BOTAO),
		CellPadding = UDim2.fromOffset(18, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	local notificacoes: { [string]: { Frame | TextLabel } } = {}
	local botoesMenu: { [string]: Frame } = {}
	local function botaoMenu(
		nome: string,
		icone: string,
		texto: string,
		cor: string,
		ordem: number,
		fn: () -> ()
	)
		local b = C.botao({
			cor = cor,
			icone = icone,
			texto = texto,
			vertical = true,
			tamanhoTexto = 19,
			tamanhoIcone = 42,
			tamanho = UDim2.fromOffset(BOTAO, BOTAO),
			ordem = ordem,
			pai = menu,
			aoClicar = fn,
		})
		local bolinha, textoBolinha = C.notificacao(b.quadro)
		notificacoes[nome] = { bolinha, textoBolinha }
		botoesMenu[nome] = b.quadro
	end
	botaoMenu("Loja", "🛒", "Loja", "rosa", 1, function()
		acoes.abrir("Loja")
	end)
	botaoMenu("Docinhos", "🍬", "Docinhos", "roxo", 2, function()
		acoes.abrir("MeusDocinhos")
	end)
	botaoMenu("Album", "📖", "Álbum", "azul", 3, function()
		acoes.abrir("Album")
	end)
	botaoMenu("Missoes", "📜", "Missões", "laranja", 4, function()
		acoes.abrir("Missoes")
	end)
	botaoMenu("Presentes", "🎁", "Presentes", "ouro", 5, function()
		acoes.abrir("Presentes")
	end)
	botaoMenu("Vitrine", "🏠", "Vitrine", "verde", 6, acoes.irParaVitrine)
	botaoMenu("Renascer", "✨", "Renascer", "roxo", 7, function()
		acoes.abrir("Renascer")
	end)

	local function marcar(nome: string, quantidade: number | string | nil)
		local n = notificacoes[nome]
		if not n then
			return
		end
		local bolinha = n[1] :: Frame
		local texto = n[2] :: TextLabel
		if quantidade == nil or quantidade == 0 then
			bolinha.Visible = false
		else
			bolinha.Visible = true
			texto.Text = tostring(quantidade)
		end
	end

	-- Evento (topo) ------------------------------------------------------------
	local evento = C.novo("Frame", {
		Name = "Evento",
		BackgroundColor3 = Cores.Branco,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 62),
		Parent = hud,
	})
	C.cantosRedondos(evento)
	C.contorno(evento)
	C.degrade(evento, Cores.Branco, Color3.fromHex("FFE3F1"))
	C.padding(evento, 10, 0)
	C.lista(
		evento,
		Enum.FillDirection.Horizontal,
		12,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	local iconeEvento = C.novo("Frame", {
		BackgroundColor3 = Cores.Rosa,
		Size = UDim2.fromOffset(48, 48),
		LayoutOrder = 1,
		Parent = evento,
	})
	C.cantosRedondos(iconeEvento)
	C.contorno(iconeEvento, 3)
	C.emoji("🌧️", 26, { Size = UDim2.fromScale(1, 1), Parent = iconeEvento })
	C.textoEscuro({
		Text = Evento.Nome,
		Font = Tema.Fonte,
		TextSize = 22,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		LayoutOrder = 2,
		Parent = evento,
	})
	local tempoEvento = C.textoEscuro({
		Font = Tema.Fonte,
		TextSize = 22,
		TextColor3 = Cores.RosaEscuro,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		LayoutOrder = 3,
		Parent = evento,
	})
	C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(4, 1),
		LayoutOrder = 4,
		Parent = evento,
	})

	-- Canto superior direito ----------------------------------------------------
	local topo = C.novo("Frame", {
		Name = "TopoDireito",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGEM, 0, MARGEM),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 72),
		Parent = hud,
	})
	C.lista(topo, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Right)
	local function botaoTopo(icone: string, cor: string, ordem: number, fn: () -> ()): Frame
		local b = C.botao({
			cor = cor,
			icone = icone,
			tamanho = UDim2.fromOffset(72, 72),
			tamanhoIcone = 34,
			ordem = ordem,
			pai = topo,
			aoClicar = fn,
		})
		return b.quadro
	end
	botaoTopo("🏆", "ouro", 1, function()
		acoes.abrir("Ranking")
	end)
	local missoesTopo = botaoTopo("📜", "laranja", 2, function()
		acoes.abrir("Missoes")
	end)
	local bolinhaMissoesTopo, textoMissoesTopo = C.notificacao(missoesTopo)
	local presentesTopo = botaoTopo("🎁", "ouro", 3, function()
		acoes.abrir("Presentes")
	end)
	local bolinhaPresentesTopo, textoPresentesTopo = C.notificacao(presentesTopo)
	botaoTopo("⚙️", "ardosia", 4, function()
		acoes.abrir("Ajustes")
	end)

	-- Missão em destaque --------------------------------------------------------
	local missao = C.cartaoEscuro({
		Name = "Missao",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGEM, 0, 130),
		Size = UDim2.fromOffset(330, 150),
		Parent = hud,
	})
	local missaoBotao = C.novo("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = missao,
	})
	missaoBotao.Activated:Connect(function()
		acoes.abrir("Missoes")
	end)
	C.texto({
		Text = "MISSÃO DIÁRIA",
		TextSize = 21,
		TextColor3 = Cores.Ouro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -36, 0, 26),
		Position = UDim2.fromOffset(18, 14),
		contorno = false,
		Parent = missao,
	})
	local missaoContagem = C.texto({
		TextSize = 17,
		TextColor3 = Cores.LilasTexto,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -36, 0, 26),
		Position = UDim2.fromOffset(18, 14),
		contorno = false,
		Parent = missao,
	})
	local missaoTexto = C.texto({
		TextSize = 21,
		Font = Tema.FonteTexto,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -36, 0, 26),
		Position = UDim2.fromOffset(18, 42),
		contorno = false,
		Parent = missao,
	})
	local missaoBarra = C.barra({
		tamanho = UDim2.new(1, -36, 0, 26),
		posicao = UDim2.fromOffset(18, 76),
		pai = missao,
	})
	local missaoPremio = C.texto({
		TextSize = 18,
		Font = Tema.FonteTexto,
		TextColor3 = Cores.LilasTexto,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -36, 0, 24),
		Position = UDim2.fromOffset(18, 112),
		contorno = false,
		Parent = missao,
	})
	-- Versão compacta (celular): só ícone, barrinha e número
	local missaoChip = C.cartaoEscuro({
		Name = "MissaoChip",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(250, 56),
		Visible = false,
		Parent = hud,
	})
	C.emoji("📜", 28, { Position = UDim2.fromOffset(10, 6), Parent = missaoChip })
	local chipBarra = C.barra({
		tamanho = UDim2.fromOffset(110, 20),
		posicao = UDim2.fromOffset(56, 18),
		pai = missaoChip,
	})
	local chipTexto = C.texto({
		TextSize = 22,
		Size = UDim2.fromOffset(70, 56),
		Position = UDim2.fromOffset(172, 0),
		Parent = missaoChip,
	})
	local chipBotao = C.novo(
		"TextButton",
		{ Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = missaoChip }
	)
	chipBotao.Activated:Connect(function()
		acoes.abrir("Missoes")
	end)

	-- Escudo -------------------------------------------------------------------
	local escudo = C.cartaoEscuro({
		Name = "Escudo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -MARGEM, 0, 300),
		Size = UDim2.fromOffset(330, 76),
		Parent = hud,
	})
	local escudoContorno = escudo:FindFirstChildOfClass("UIStroke") :: UIStroke
	C.emoji(
		"🛡️",
		34,
		{ Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = escudo }
	)
	local escudoTitulo = C.texto({
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -76, 0, 26),
		Position = UDim2.fromOffset(64, 10),
		contorno = false,
		Parent = escudo,
	})
	local escudoSub = C.texto({
		TextSize = 16,
		Font = Tema.FonteTexto,
		TextColor3 = Color3.fromHex("BDEEFF"),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -76, 0, 22),
		Position = UDim2.fromOffset(64, 40),
		contorno = false,
		Parent = escudo,
	})
	local escudoBotao = C.novo(
		"TextButton",
		{ Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = escudo }
	)
	escudoBotao.Activated:Connect(function()
		Avisos.resultado(Estado.pedir("LigarEscudo"))
	end)

	-- Docinho carregado (aparece quando o jogo marca o atributo "Carregando") ------
	local carga = C.cartaoEscuro({
		Name = "Carregando",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 108),
		Visible = false,
		Parent = hud,
	})
	C.padding(carga, 12, 10)
	C.lista(
		carga,
		Enum.FillDirection.Horizontal,
		16,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	local cargaFoto = C.novo("Frame", {
		BackgroundColor3 = Cores.Ouro,
		Size = UDim2.fromOffset(84, 84),
		LayoutOrder = 1,
		Parent = carga,
	})
	C.cantos(cargaFoto, 18)
	C.contorno(cargaFoto)
	local cargaTextos = C.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 70),
		LayoutOrder = 2,
		Parent = carga,
	})
	C.lista(
		cargaTextos,
		Enum.FillDirection.Vertical,
		2,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Center
	)
	local cargaNome = C.texto({
		TextSize = 24,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		Parent = cargaTextos,
	})
	local cargaSub = C.texto({
		TextSize = 18,
		Font = Tema.FonteTexto,
		TextColor3 = Cores.OuroClaro,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		contorno = false,
		Parent = cargaTextos,
	})
	local bussola = C.novo("Frame", {
		BackgroundColor3 = Cores.Menta,
		Size = UDim2.fromOffset(64, 64),
		LayoutOrder = 3,
		Parent = carga,
	})
	C.cantosRedondos(bussola)
	C.contorno(bussola)
	local seta = C.texto({
		Text = "▲",
		TextSize = 34,
		Size = UDim2.fromScale(1, 1),
		contorno = 2,
		Parent = bussola,
	})

	local player = Players.LocalPlayer
	local function atualizarCarga()
		local id = player:GetAttribute("Carregando")
		local d = type(id) == "string" and Catalogo.docinho(id)
		if not d then
			carga.Visible = false
			return
		end
		local r = Catalogo.raridadeDe(d.id)
		for _, f in cargaFoto:GetChildren() do
			if f:IsA("ViewportFrame") then
				f:Destroy()
			end
		end
		Visual.docinho(d.id, { tamanho = UDim2.fromScale(1, 1), pai = cargaFoto })
		cargaFoto.BackgroundColor3 = if r then r.cor else Cores.Ouro
		cargaNome.Text = d.nome
		cargaSub.Text = (if r then r.nome .. " · " else "") .. "leve até a sua vitrine!"
		carga.Visible = true
	end
	player:GetAttributeChangedSignal("Carregando"):Connect(atualizarCarga)
	atualizarCarga()

	-- A seta aponta para a vitrine, relativa para onde a câmera olha
	RunService.RenderStepped:Connect(function()
		if not carga.Visible then
			return
		end
		local alvo = acoes.posicaoVitrine()
		local camera = workspace.CurrentCamera
		if not alvo or not camera then
			seta.Text = "🏠"
			seta.Rotation = 0
			return
		end
		seta.Text = "▲"
		local cf = camera.CFrame
		local direcao = cf:PointToObjectSpace(alvo)
		seta.Rotation = math.deg(math.atan2(direcao.X, -direcao.Z))
	end)

	-- Atualização com o estado ---------------------------------------------------
	local albumVistoAte: number? = nil
	function HUD.marcarAlbumVisto()
		albumVistoAte = Estado.agora()
		marcar("Album", nil)
	end

	local function atualizar()
		local estado = Estado.atual
		if not estado then
			return
		end
		local agora = Estado.agora()
		moedas.valor.Text = moedasTexto(estado.moedas)
		local renda = Economia.rendaPorSegundo(estado, agora)
		moedas.extra.Text = if renda > 0 then "+" .. Formato.curto(renda) .. "/s" else ""
		granulados.valor.Text = Formato.inteiro(estado.granulados)

		-- Bolinhas de aviso
		if not albumVistoAte then
			albumVistoAte = agora
		end
		local novos = 0
		for _, entrada in estado.album do
			if entrada.desde > (albumVistoAte :: number) then
				novos += 1
			end
		end
		marcar("Album", novos)
		marcar(
			"Docinhos",
			if #estado.vitrine >= Economia.capacidadeVitrine(estado) then "!" else nil
		)

		local prontas = 0
		local destaque, destaqueDef = nil, nil
		local feitas = 0
		for _, m in estado.missoes.lista do
			local def = Missoes.missao(m.id)
			if def then
				if m.resgatada then
					feitas += 1
				elseif m.progresso >= def.meta then
					prontas += 1
				end
				if not m.resgatada and not destaque then
					destaque, destaqueDef = m, def
				end
			end
		end
		marcar("Missoes", prontas)
		marcar(
			"Renascer",
			if estado.moedas >= Economia.custoRenascer(estado.renascimentos or 0) then "!" else nil
		)
		bolinhaMissoesTopo.Visible = prontas > 0
		textoMissoesTopo.Text = tostring(prontas)
		local presenteDisponivel = estado.presente.ultimoDia ~= Presentes.diaAtual(agora)
		marcar("Presentes", if presenteDisponivel then 1 else nil)
		bolinhaPresentesTopo.Visible = presenteDisponivel
		textoPresentesTopo.Text = "1"

		local total = #estado.missoes.lista
		missaoContagem.Text = string.format("%d / %d", math.min(feitas + 1, total), total)
		if destaque and destaqueDef then
			missaoTexto.Text = destaqueDef.texto
			local fr = destaque.progresso / destaqueDef.meta
			local txt = Formato.curto(destaque.progresso)
				.. " / "
				.. Formato.curto(destaqueDef.meta)
			missaoBarra.definir(fr, txt)
			chipBarra.definir(fr)
			chipTexto.Text = if destaque.progresso >= destaqueDef.meta
				then "✓"
				else math.floor(fr * 100) .. "%"
			missaoPremio.Text = if destaque.progresso >= destaqueDef.meta
				then "Pronto! Toque para pegar " .. destaqueDef.granulados .. " ✨"
				else "Prêmio: ✨ " .. destaqueDef.granulados .. " granulados"
		else
			missaoTexto.Text = "Tudo feito! Volte amanhã."
			missaoBarra.definir(1, "✓")
			chipBarra.definir(1)
			chipTexto.Text = "✓"
			missaoPremio.Text = ""
		end
	end
	Estado.aoMudar(atualizar)

	-- Relógios (evento e escudo) a cada meio segundo
	local function relogios()
		local estado = Estado.atual
		local agora = Estado.agora()
		local ativo, falta = Evento.estado(agora)
		-- O servidor manda quando a chuva está de fato acontecendo (agenda ou teste)
		local fimChuva = workspace:GetAttribute("ChuvaAte")
		if type(fimChuva) == "number" and fimChuva > agora then
			ativo, falta = true, fimChuva - agora
		end
		tempoEvento.Text = if ativo
			then "acontecendo · " .. Formato.tempo(falta)
			else "sábado · " .. Formato.tempo(falta)
		iconeEvento.BackgroundColor3 = if ativo then Cores.Menta else Cores.Rosa
		if not estado then
			return
		end
		if agora < estado.escudoAte then
			escudoTitulo.Text = "Escudo da vitrine ligado"
			escudoSub.Text = "desliga em " .. Formato.tempo(estado.escudoAte - agora)
			escudoContorno.Color = Cores.Ceu
		elseif agora < estado.escudoProntoEm then
			escudoTitulo.Text = "Escudo recarregando"
			escudoSub.Text = "pronto em " .. Formato.tempo(estado.escudoProntoEm - agora)
			escudoContorno.Color = Cores.Contorno
		else
			escudoTitulo.Text = "Escudo desligado"
			escudoSub.Text = "toque para ligar (" .. Economia.duracaoEscudo(estado) .. "s)"
			escudoContorno.Color = Cores.Vermelho
		end
		local renda = Economia.rendaPorSegundo(estado, agora)
		moedas.extra.Text = if renda > 0 then "+" .. Formato.curto(renda) .. "/s" else ""
	end
	task.spawn(function()
		while hud.Parent do
			relogios()
			task.wait(0.5)
		end
	end)

	-- Layout: PC (design 05) ou celular deitado (design 06) ----------------------
	Escala.aoMudar(function()
		local compacto = Escala.compacto
		listaRecursos.FillDirection = if compacto
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		recursos.Position = if compacto
			then UDim2.fromOffset(MARGEM + 10, 18)
			else UDim2.fromOffset(MARGEM + 10, MARGEM)
		menu.Position = if compacto
			then UDim2.fromOffset(MARGEM, 110)
			else UDim2.fromOffset(MARGEM, 200)
		menu.Size = if compacto
			then UDim2.fromOffset(BOTAO * 2 + 18, BOTAO * 2 + 18)
			else UDim2.fromOffset(BOTAO * 2 + 18, BOTAO * 4 + 54)
		-- No celular, Missões e Presentes sobem para o canto e o menu fica 2x2
		botoesMenu.Missoes.Visible = not compacto
		botoesMenu.Presentes.Visible = not compacto
		-- No celular o Renascer fica dentro de "Meus Docinhos"
		botoesMenu.Renascer.Visible = not compacto
		missoesTopo.Visible = compacto
		presentesTopo.Visible = compacto
		evento.Position = if compacto then UDim2.new(0.5, 0, 0, 100) else UDim2.new(0.5, 0, 0, 24)
		missao.Visible = not compacto
		missaoChip.Visible = compacto
		missaoChip.Position = UDim2.new(1, -MARGEM, 0, 116)
		escudo.Position = if compacto
			then UDim2.new(1, -MARGEM, 0, 186)
			else UDim2.new(1, -MARGEM, 0, 300)
		escudo.Size = if compacto then UDim2.fromOffset(250, 76) else UDim2.fromOffset(330, 76)
	end)
end

return HUD
