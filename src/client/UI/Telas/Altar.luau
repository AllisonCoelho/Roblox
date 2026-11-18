local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Icones = require(Shared.Dados.Icones)
local Itens = require(Shared.Dados.Itens)
local Receitas = require(Shared.Dados.Receitas)
local Transcendencia = require(Shared.Dados.Transcendencia)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local IconeImagem = require(script.Parent.Parent.IconeImagem)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Altar = {}
local camada: CanvasGroup? = nil
local coracao: Part? = nil
local contadorCena = 0

function Altar.ativa(): boolean
	return camada ~= nil and camada.Visible
end

local function fecharCena()
	contadorCena += 1
	if coracao then
		coracao:Destroy()
		coracao = nil
	end
	if camada then
		camada:Destroy()
		camada = nil
	end
end

local function elevarCoracao(meu: number)
	local personagem = Players.LocalPlayer.Character
	local cabeca = if personagem then personagem:FindFirstChild("Head") else nil
	if not cabeca or not cabeca:IsA("BasePart") then
		return
	end
	local nexo = workspace:FindFirstChild("Nexo")
	local nucleo = if nexo then nexo:FindFirstChild("Nucleo") else nil
	local inicio = cabeca.CFrame * CFrame.new(0, 0, -2.6)
	local alto = inicio + Vector3.new(0, 2.5, 0)
	local gema: Part = Kit.novo("Part", {
		Name = "CoracaoDaRessonanciaLocal",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = Color3.fromHex("FFC83D"),
		Size = Vector3.new(0.8, 0.8, 0.8),
		CFrame = inicio * CFrame.Angles(0, math.rad(30), math.rad(45)),
		Parent = workspace,
	})
	coracao = gema
	TweenService:Create(gema, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {
		CFrame = alto * CFrame.Angles(0, math.rad(110), math.rad(45)),
		Color = Color3.fromHex("DD69E9"),
	}):Play()
	task.delay(0.75, function()
		if contadorCena ~= meu then
			return
		end
		local alvo = if nucleo
				and nucleo:IsA("Model")
				and nucleo.Parent
			then nucleo:GetPivot().Position + Vector3.new(0, 4, 0)
			else alto.Position + Vector3.new(0, 4, 0)
		TweenService:Create(gema, TweenInfo.new(0.58, Enum.EasingStyle.Sine), {
			Position = alvo,
			Transparency = 1,
		}):Play()
	end)
end

local function cena(raiz: Frame, nivel: number, reduzido: boolean, qualidadeBaixa: boolean)
	fecharCena()
	local meu = contadorCena
	local grupo: CanvasGroup = Kit.novo("CanvasGroup", {
		Name = "TranscendenciaConfirmada",
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 0.64,
		GroupTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 45,
		Parent = raiz,
	})
	camada = grupo
	local placa = Kit.placa({
		tamanho = UDim2.new(0.88, 0, 0, 238),
		posicao = UDim2.fromScale(0.5, 0.5),
		ancora = Vector2.new(0.5, 0.5),
		borda = Color3.fromHex(Itens.Tiers[5].cor),
		pai = grupo,
	})
	Kit.novo("UISizeConstraint", { MaxSize = Vector2.new(560, 238), Parent = placa.quadro })
	local nucleo = Kit.cristal(placa.conteudo, 58, Color3.fromHex(Itens.Tiers[5].cor))
	nucleo.AnchorPoint = Vector2.new(0.5, 0)
	nucleo.Position = UDim2.new(0.5, 0, 0, 24)
	Kit.texto({
		fonte = "titulo",
		Text = "TRANSCENDÊNCIA "
			.. ({ "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" })[nivel],
		TextSize = 28,
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 94),
		Size = UDim2.new(1, -20, 0, 46),
		Parent = placa.conteudo,
	})
	Kit.texto({
		Text = string.format(
			"+%.0f%% na chance de auras raras ou superiores",
			(Transcendencia.sorte(nivel) - 1) * 100
		),
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 138),
		Size = UDim2.new(1, -20, 0, 38),
		Parent = placa.conteudo,
	})
	local pular = Kit.botaoPlaca({
		texto = "Continuar",
		tamanho = UDim2.fromOffset(150, 42),
		tamanhoTexto = 16,
		pai = placa.conteudo,
		aoClicar = fecharCena,
	})
	pular.placa.quadro.AnchorPoint = Vector2.new(0.5, 1)
	pular.placa.quadro.Position = UDim2.new(0.5, 0, 1, -10)
	if not reduzido then
		local escala: UIScale = Kit.novo("UIScale", { Scale = 0.65, Parent = nucleo })
		TweenService:Create(escala, TweenInfo.new(0.55, Enum.EasingStyle.Sine), { Scale = 1 })
			:Play()
		if not qualidadeBaixa then
			elevarCoracao(meu)
		end
	end
	task.delay(2.2, function()
		if contadorCena == meu then
			fecharCena()
		end
	end)
end

function Altar.montar(raiz: Frame, avisar: (string) -> ())
	local aba = "Forja"
	local armado: string? = nil
	local pendente = false
	local atualizar: () -> ()

	local function pedir(acao: string, id: string?)
		if pendente then
			return
		end
		local chave = id or acao
		if armado ~= chave then
			armado = chave
			atualizar()
			return
		end
		armado = nil
		pendente = true
		atualizar()
		task.spawn(function()
			local ok, msg, dados = Estado.pedir(acao, id)
			pendente = false
			atualizar()
			if msg then
				avisar(msg)
			end
			if ok and acao == "Transcender" and dados and type(dados.nivel) == "number" then
				Navegacao.fechar()
				local estado = Estado.atual
				cena(
					raiz,
					dados.nivel,
					estado ~= nil and estado.configuracoes.movimentoReduzido == true,
					estado ~= nil and estado.configuracoes.qualidadeBaixa == true
				)
			end
		end)
	end

	local estrutura: Cartoes.Estrutura
	local abas: { [string]: Cartoes.Aba } = {}
	local ord = 0
	local function proxima(): number
		ord += 1
		return ord
	end
	local VERDE = Color3.fromHex("7BF0A0")
	local FALTA = Color3.fromHex("FF8298")
	local ROMANOS = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

	local function texto(pai: Instance, props: { [string]: any }): TextLabel
		props.Parent = pai
		return Kit.texto(props)
	end

	-- Ficha de ingrediente: ícone, nome e "tem / precisa" (verde quando basta)
	local function ingrediente(
		pai: Instance,
		ordem: number,
		id: string,
		tem: number,
		precisa: number
	)
		local item = Itens.porId[id]
		local basta = tem >= precisa
		local p = Kit.placa({
			tamanho = UDim2.new(1, 0, 0, 40),
			borda = if basta then VERDE else Cores.Borda,
			ordem = ordem,
			corte = 8,
			pai = pai,
		})
		IconeImagem.criar(
			p.conteudo,
			Icones.item(id, item.categoria),
			UDim2.fromOffset(6, 4),
			UDim2.fromOffset(32, 32)
		)
		texto(p.conteudo, {
			Text = item.nome,
			TextSize = 15,
			TextColor3 = Kit.corLegivel(Color3.fromHex(Itens.Tiers[item.raridade].cor)),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(44, 0),
			Size = UDim2.new(1, -112, 1, 0),
		})
		texto(p.conteudo, {
			fonte = "mono",
			Text = string.format("%d / %d", tem, precisa),
			TextSize = 16,
			TextColor3 = if basta then VERDE else FALTA,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -72, 0, 0),
			Size = UDim2.fromOffset(64, 40),
		})
	end

	local function listaIngredientes(
		pai: Instance,
		estoque: Itens.Estoque,
		custo: Itens.Estoque,
		posicao: UDim2,
		tamanho: UDim2
	)
		local caixa = Kit.novo("Frame", {
			BackgroundTransparency = 1,
			Position = posicao,
			Size = tamanho,
			Parent = pai,
		})
		Kit.novo(
			"UIListLayout",
			{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = caixa }
		)
		local ids: { string } = {}
		for id in custo do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return Itens.porId[a].nome < Itens.porId[b].nome
		end)
		for i, id in ids do
			ingrediente(caixa, i, id, estoque[id] or 0, custo[id])
		end
	end

	-- Botão de ação com confirmação em dois toques (armado = dourado "Confirmar")
	local function botaoAcao(
		pai: Instance,
		chave: string,
		rotulo: string,
		disponivel: boolean,
		aoClicar: () -> ()
	)
		local confirmar = armado == chave
		local cor = if pendente
			then Cores.Elevado
			elseif confirmar then Cartoes.OURO
			elseif disponivel then Cores.Lilas
			else Cores.Elevado
		local p = Kit.placa({
			tamanho = UDim2.new(1, -16, 0, 44),
			ancora = Vector2.new(0.5, 1),
			posicao = UDim2.new(0.5, 0, 1, -8),
			fundo = cor,
			borda = cor,
			corte = 8,
			z = 4,
			pai = pai,
		})
		local claro = not pendente and (confirmar or disponivel)
		texto(p.conteudo, {
			fonte = "titulo",
			Text = if pendente
				then "Aguardando…"
				elseif confirmar then "Confirmar " .. string.lower(rotulo)
				elseif disponivel then rotulo
				else "Faltam materiais",
			TextSize = 19,
			TextColor3 = if claro then Cores.Fundo else Cores.TextoSuave,
			Size = UDim2.fromScale(1, 1),
		})
		local b = Kit.alvo(p.quadro, rotulo, aoClicar)
		b.Interactable = disponivel and not pendente
		Cartoes.animarToque(p.quadro, b)
	end

	local function mostrarForja(estoque: Itens.Estoque)
		local lista = estrutura.lista
		Cartoes.secao(lista, proxima(), "Receitas", "Toque duas vezes para confirmar")
		local maior = 0
		for _, id in Receitas.ordem do
			local n = 0
			for _ in Receitas.porId[id].custo do
				n += 1
			end
			maior = math.max(maior, n)
		end
		local grade =
			Cartoes.grade(lista, proxima(), Vector2.new(424, math.max(250, 96 + maior * 46)))
		for i, id in Receitas.ordem do
			local receita = Receitas.porId[id]
			local resultado = Itens.porId[receita.resultado]
			local tier = Itens.Tiers[resultado.raridade]
			local cor = Color3.fromHex(tier.cor)
			local podeFazer = Receitas.podeFabricar(estoque, receita)
			local p = Kit.placa({
				tamanho = UDim2.new(),
				borda = if podeFazer then cor else Cores.Borda,
				ordem = i,
				corte = 14,
				pai = grade,
			})
			-- coluna do resultado: brilho na cor da raridade e ícone grande
			local lado = Kit.novo("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(1, 1),
				Size = UDim2.new(0, 150, 1, -58),
				Parent = p.conteudo,
			})
			Kit.novo("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(cor:Lerp(Cores.Painel, 0.45), Cores.Painel),
				Parent = lado,
			})
			IconeImagem.criar(
				p.conteudo,
				Icones.item(receita.resultado, resultado.categoria),
				UDim2.fromOffset(37, 14),
				UDim2.fromOffset(76, 76)
			)
			texto(p.conteudo, {
				fonte = "titulo",
				Text = resultado.nome,
				TextSize = 18,
				TextWrapped = true,
				TextColor3 = Kit.corLegivel(cor),
				Position = UDim2.fromOffset(6, 94),
				Size = UDim2.fromOffset(140, 46),
			})
			texto(p.conteudo, {
				Text = tier.nome .. " · " .. resultado.categoria,
				TextSize = 13,
				TextColor3 = Cores.TextoSuave,
				Position = UDim2.fromOffset(6, 140),
				Size = UDim2.fromOffset(140, 18),
			})
			texto(p.conteudo, {
				Text = "MATERIAIS",
				TextSize = 13,
				TextColor3 = Cores.TextoSuave,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(162, 8),
				Size = UDim2.new(1, -170, 0, 16),
			})
			listaIngredientes(
				p.conteudo,
				estoque,
				receita.custo,
				UDim2.fromOffset(162, 28),
				UDim2.new(1, -172, 1, -88)
			)
			botaoAcao(p.conteudo, id, "Fabricar", podeFazer, function()
				pedir("FabricarItem", id)
			end)
		end
	end

	local function mostrarTranscender(estoque: Itens.Estoque, nivel: number)
		local lista = estrutura.lista
		local sorte = Transcendencia.sorte(nivel)
		local dourado = Color3.fromHex(Itens.Tiers[5].cor)
		Cartoes.banner({
			pai = lista,
			ordem = proxima(),
			cor = dourado,
			icone = 9,
			titulo = string.format("Transcendência %s", if nivel > 0 then ROMANOS[nivel] else "0"),
			texto = (
				string.gsub(
					string.format(
						"<b>Sorte atual %.2fx</b>  ·  bônus permanente +%.0f%%<br/>O bônus aumenta a chance de auras raras ou superiores.",
						sorte,
						(sorte - 1) * 100
					),
					"(%d)%.(%d)",
					"%1,%2"
				)
			),
			altura = 120,
		})

		-- Trilha dos níveis I–X: concluídos em dourado, o próximo em lilás
		Cartoes.secao(
			lista,
			proxima(),
			"Níveis",
			string.format("%d / %d", nivel, Transcendencia.MAXIMO)
		)
		local trilha = Kit.novo("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 92),
			LayoutOrder = proxima(),
			Parent = lista,
		})
		Kit.novo("Frame", {
			BackgroundColor3 = Cores.Borda,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 30, 0, 29),
			Size = UDim2.new(1, -60, 0, 4),
			Parent = trilha,
		})
		Kit.novo("Frame", {
			BackgroundColor3 = dourado,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 30, 0, 29),
			Size = UDim2.new(
				(math.max(nivel, 1) - 1) / (Transcendencia.MAXIMO - 1),
				-60 * (math.max(nivel, 1) - 1) / (Transcendencia.MAXIMO - 1),
				0,
				4
			),
			Visible = nivel > 1,
			Parent = trilha,
		})
		for n = 1, Transcendencia.MAXIMO do
			local feito = n <= nivel
			local proximo = n == nivel + 1
			local f = (n - 1) / (Transcendencia.MAXIMO - 1)
			local no = Kit.circulo({
				BackgroundColor3 = if feito
					then dourado
					elseif proximo then Cores.Lilas
					else Cores.Elevado,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(f, 30 - 60 * f, 0, 31),
				Size = UDim2.fromOffset(if proximo then 54 else 46, if proximo then 54 else 46),
				Parent = trilha,
			})
			Kit.novo(
				"UIStroke",
				{ Color = if proximo then Cores.Texto else Cores.Borda, Thickness = 2, Parent = no }
			)
			texto(no, {
				fonte = "titulo",
				Text = ROMANOS[n],
				TextSize = 16,
				TextColor3 = if feito or proximo then Cores.Fundo else Cores.TextoSuave,
				Size = UDim2.fromScale(1, 1),
			})
			texto(trilha, {
				fonte = "mono",
				Text = string.format("+%.0f%%", (Transcendencia.sorte(n) - 1) * 100),
				TextSize = 12,
				TextColor3 = if feito then dourado else Cores.TextoSuave,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(f, 30 - 60 * f, 0, 64),
				Size = UDim2.fromOffset(60, 18),
			})
		end

		local custo = Transcendencia.custo(nivel)
		if not custo then
			Cartoes.secao(lista, proxima(), "Nível máximo alcançado")
			return
		end
		Cartoes.secao(
			lista,
			proxima(),
			string.format("Oferta para o nível %s", ROMANOS[nivel + 1])
		)
		local quantos = 0
		for _ in custo do
			quantos += 1
		end
		local oferta = Kit.placa({
			tamanho = UDim2.new(1, 0, 0, math.max(230, 92 + quantos * 46)),
			borda = Cores.Lilas,
			ordem = proxima(),
			corte = 14,
			pai = lista,
		})
		IconeImagem.criar(oferta.conteudo, 9, UDim2.fromOffset(20, 18), UDim2.fromOffset(96, 96))
		texto(oferta.conteudo, {
			fonte = "titulo",
			Text = string.format("+%.0f%%", (Transcendencia.sorte(nivel + 1) - 1) * 100),
			TextSize = 30,
			TextColor3 = dourado,
			Position = UDim2.fromOffset(10, 118),
			Size = UDim2.fromOffset(116, 36),
		})
		texto(oferta.conteudo, {
			Text = "auras raras ou superiores",
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Cores.TextoSuave,
			Position = UDim2.fromOffset(10, 152),
			Size = UDim2.fromOffset(116, 34),
		})
		texto(oferta.conteudo, {
			Text = "OFERENDA",
			TextSize = 13,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(140, 10),
			Size = UDim2.new(1, -150, 0, 16),
		})
		listaIngredientes(
			oferta.conteudo,
			estoque,
			custo,
			UDim2.fromOffset(140, 30),
			UDim2.new(1, -156, 1, -90)
		)
		botaoAcao(
			oferta.conteudo,
			"Transcender",
			"Transcender",
			Transcendencia.podeOferecer(estoque, custo),
			function()
				pedir("Transcender")
			end
		)
	end

	atualizar = function()
		if Navegacao.aberto() ~= "Altar" then
			return
		end
		local antes = estrutura.conteudo.CanvasPosition
		for _, filho in estrutura.lista:GetChildren() do
			if filho:IsA("GuiObject") then
				filho:Destroy()
			end
		end
		ord = 0
		for nome, a in abas do
			a.definirAtiva(nome == aba)
		end
		local estado = Estado.atual
		if not estado then
			Cartoes.secao(estrutura.lista, 1, "Carregando seu perfil…")
			return
		end
		local estoque = estado.inventario.itens
		if aba == "Forja" then
			mostrarForja(estoque)
		else
			mostrarTranscender(estoque, estado.transcendencia.nivel)
		end
		estrutura.conteudo.CanvasPosition = antes
	end

	local painel = Navegacao.criarPainel(
		"Altar",
		{ titulo = "Altar da Ressonância", icone = 9 },
		function()
			armado = nil
			atualizar()
		end
	)
	estrutura = Cartoes.estrutura(painel.conteudo)
	local ABAS = {
		{ "Forja", 20, Color3.fromHex("FF9A6A") },
		{ "Transcender", 9, Color3.fromHex("FFC83D") },
	}
	for i, info in ABAS do
		local nome = info[1]
		abas[nome] = Cartoes.aba(estrutura.lateral, i, nome, info[2], info[3], function()
			aba = nome
			armado = nil
			estrutura.conteudo.CanvasPosition = Vector2.zero
			atualizar()
		end)
	end
	Estado.aoMudar(atualizar)
	Players.LocalPlayer.CharacterAdded:Connect(fecharCena)
end

return Altar
