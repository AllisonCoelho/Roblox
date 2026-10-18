-- Docinhopédia: álbum de coleção (ver docs/design/07-album.png)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Visual = require(UI.Visual)

local Cores = Tema.Cores
local Album = {}

local ABAS = {
	{ id = "normal", texto = "Mundo 1 · Fábrica" },
	{ id = "dourado", texto = "✨ Dourados" },
	{ id = "arcoiris", texto = "🌈 Arco-íris" },
}

function Album.montar(aoAbrir: () -> ())
	local painel =
		Navegacao.criarPainel("Album", { titulo = "Docinhopédia", icone = "📖", cor = "azul" })

	local progresso = C.barra({
		tamanho = UDim2.fromOffset(260, 30),
		cores = { Cores.OuroClaro, Cores.Ouro },
		tamanhoTexto = 18,
		posicao = UDim2.new(0, 330, 0.5, -15),
		pai = painel.cabecalho,
	})
	C.texto({
		Text = "descobertos",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(160, 30),
		Position = UDim2.new(0, 604, 0.5, -15),
		contorno = 2,
		Parent = painel.cabecalho,
	})

	local abas = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 0, 46),
		Position = UDim2.fromOffset(24, 16),
		Parent = painel.conteudo,
	})
	C.lista(
		abas,
		Enum.FillDirection.Horizontal,
		10,
		Enum.HorizontalAlignment.Left,
		Enum.VerticalAlignment.Bottom
	)

	local grade = C.novo("ScrollingFrame", {
		Name = "Grade",
		BackgroundColor3 = Cores.Branco,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -430, 1, -86),
		Position = UDim2.fromOffset(24, 62),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Cores.Contorno,
		Parent = painel.conteudo,
	})
	C.cantos(grade, 20)
	C.contorno(grade)
	C.padding(grade, 18, 18)
	C.novo("UIGridLayout", {
		CellSize = UDim2.fromOffset(160, 230),
		CellPadding = UDim2.fromOffset(16, 22),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grade,
	})

	-- Detalhe do Docinho selecionado
	local detalhe = C.cartaoClaro({
		Name = "Detalhe",
		Size = UDim2.new(0, 370, 1, -40),
		Position = UDim2.new(1, -24, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		Parent = painel.conteudo,
	})
	local fotoDetalhe = C.novo("Frame", {
		BackgroundColor3 = Cores.Uva,
		Size = UDim2.new(1, -36, 0, 220),
		Position = UDim2.fromOffset(18, 18),
		Parent = detalhe,
	})
	C.cantos(fotoDetalhe, 16)
	C.contorno(fotoDetalhe)
	local degradeDetalhe = C.degrade(fotoDetalhe, Cores.Branco, Cores.Uva)
	local nomeDetalhe = C.textoEscuro({
		Font = Tema.Fonte,
		TextSize = 28,
		TextWrapped = true,
		Size = UDim2.new(1, -36, 0, 36),
		Position = UDim2.fromOffset(18, 248),
		Parent = detalhe,
	})
	local etiquetaDetalhe = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 288),
		Parent = detalhe,
	})
	C.lista(etiquetaDetalhe, Enum.FillDirection.Horizontal, 0, Enum.HorizontalAlignment.Center)
	local linhas = C.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -36, 0, 130),
		Position = UDim2.fromOffset(18, 330),
		Parent = detalhe,
	})
	C.lista(linhas, Enum.FillDirection.Vertical, 4)
	local function linha(ordem: number): (TextLabel, TextLabel)
		local l = C.novo("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = ordem,
			Parent = linhas,
		})
		local a = C.textoEscuro({
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(1, 1),
			Parent = l,
		})
		local b = C.textoEscuro({
			Font = Tema.Fonte,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(1, 1),
			Parent = l,
		})
		return a, b
	end
	local l1a, l1b = linha(1)
	local l2a, l2b = linha(2)
	local l3a, l3b = linha(3)
	local descricao = C.textoEscuro({
		TextSize = 16,
		TextColor3 = Cores.TextoSuave,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -36, 0, 44),
		Position = UDim2.fromOffset(18, 428),
		Parent = detalhe,
	})
	local premio = C.cartaoClaro({
		BackgroundColor3 = Cores.OuroClaro,
		Size = UDim2.new(1, -36, 0, 74),
		Position = UDim2.new(0, 18, 1, -90),
		Parent = detalhe,
	}, 16)
	local premioTexto = C.textoEscuro({
		TextSize = 17,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Parent = premio,
	})

	local abaAtual = "normal"
	local selecionado = "brigadeiro"
	local botoesAba: { [string]: TextButton } = {}
	local desenhar: () -> ()

	for i, aba in ABAS do
		local b = C.novo("TextButton", {
			Text = aba.texto,
			Font = Tema.Fonte,
			TextSize = 20,
			TextColor3 = Cores.Contorno,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 44),
			BackgroundColor3 = Cores.Branco,
			LayoutOrder = i,
			Parent = abas,
		})
		C.cantos(b, 14)
		C.contorno(b)
		C.padding(b, 18, 0)
		b.Activated:Connect(function()
			abaAtual = aba.id
			desenhar()
		end)
		botoesAba[aba.id] = b
	end

	local function desenharDetalhe()
		local estado = Estado.atual
		local d = Catalogo.docinho(selecionado)
		local r = Catalogo.raridadeDe(selecionado)
		if not estado or not d or not r then
			return
		end
		local entrada = estado.album[d.id]
		local conhecido = entrada ~= nil
		for _, f in fotoDetalhe:GetChildren() do
			if f:IsA("ViewportFrame") then
				f:Destroy()
			end
		end
		degradeDetalhe.Color = ColorSequence.new(r.brilho, r.cor)
		local variante = if abaAtual ~= "normal"
				and entrada
				and entrada[abaAtual]
			then abaAtual
			else "normal"
		Visual.docinho(d.id, {
			variante = variante,
			silhueta = not conhecido,
			girar = conhecido,
			tamanho = UDim2.fromScale(1, 1),
			pai = fotoDetalhe,
		})
		for _, f in etiquetaDetalhe:GetChildren() do
			if f:IsA("Frame") then
				f:Destroy()
			end
		end
		if conhecido and entrada then
			nomeDetalhe.Text = d.nome
			C.etiqueta(r.nome, r.cor, 18, { Parent = etiquetaDetalhe })
			l1a.Text, l1b.Text =
				"Renda", "🪙 " .. Formato.curto(Catalogo.rendaDe(d.id, variante)) .. "/s"
			l2a.Text, l2b.Text = "Você já teve", tostring(entrada.qtd)
			l3a.Text, l3b.Text = "Descoberto em", os.date("%d/%m/%Y", entrada.desde)
			descricao.Text = d.descricao
		else
			nomeDetalhe.Text = "???"
			C.etiqueta("Não descoberto", Cores.Cinza, 18, { Parent = etiquetaDetalhe })
			l1a.Text, l1b.Text = "Raridade", r.nome
			l2a.Text, l2b.Text = "", ""
			l3a.Text, l3b.Text = "", ""
			descricao.Text = "Compre na esteira para descobrir!"
		end
	end

	desenhar = function()
		for _, f in grade:GetChildren() do
			if f:IsA("Frame") then
				f:Destroy()
			end
		end
		for id, b in botoesAba do
			b.BackgroundColor3 = if id == abaAtual then Cores.Branco else Color3.fromHex("E9E1F2")
			b.TextColor3 = if id == abaAtual then Cores.Contorno else Cores.TextoSuave
		end
		local estado = Estado.atual
		if not estado then
			return
		end
		local descobertos = 0
		for i, d in Catalogo.Lista do
			local r = Catalogo.Raridades[d.raridade]
			local entrada = estado.album[d.id]
			local conhecido = entrada ~= nil
				and (abaAtual == "normal" or (entrada :: any)[abaAtual] == true)
			if conhecido then
				descobertos += 1
			end
			local celula = C.novo("Frame", {
				BackgroundColor3 = Cores.Branco,
				LayoutOrder = i,
				Parent = grade,
			})
			C.cantos(celula, 18)
			local contorno = C.contorno(celula)
			if conhecido then
				C.degrade(celula, r.brilho, r.cor)
			else
				celula.BackgroundColor3 = Color3.fromHex("E9E1F2")
			end
			if d.id == selecionado then
				contorno.Color = Cores.Ouro
				contorno.Thickness = 6
			end
			Visual.docinho(d.id, {
				variante = if conhecido and abaAtual ~= "normal" then abaAtual else "normal",
				silhueta = not conhecido,
				tamanho = UDim2.fromOffset(130, 130),
				posicao = UDim2.new(0.5, 0, 0, 14),
				ancora = Vector2.new(0.5, 0),
				pai = celula,
			})
			if conhecido and entrada and abaAtual == "normal" then
				local qtd = C.textoEscuro({
					Text = "x" .. entrada.qtd,
					Font = Tema.Fonte,
					TextSize = 15,
					BackgroundColor3 = Cores.Branco,
					BackgroundTransparency = 0.2,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 22),
					Position = UDim2.new(1, -8, 0, 8),
					AnchorPoint = Vector2.new(1, 0),
					Parent = celula,
				})
				C.cantosRedondos(qtd)
				C.padding(qtd, 8, 0)
			end
			C.textoEscuro({
				Text = if conhecido then d.nome else "???",
				Font = Tema.Fonte,
				TextSize = 15,
				TextColor3 = if conhecido then Cores.Contorno else Cores.Cinza,
				TextWrapped = true,
				Size = UDim2.new(1, -12, 0, 36),
				Position = UDim2.new(0, 6, 0, 146),
				Parent = celula,
			})
			local et = C.etiqueta(
				if conhecido then r.nome else "???",
				if conhecido then r.cor else Cores.CinzaClaro,
				13
			)
			et.AnchorPoint = Vector2.new(0.5, 0)
			et.Position = UDim2.new(0.5, 0, 0, 188)
			et.Parent = celula
			local clique = C.novo("TextButton", {
				Text = "",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
				Parent = celula,
			})
			clique.Activated:Connect(function()
				selecionado = d.id
				desenhar()
			end)
		end
		local total = #Catalogo.Lista
		progresso.definir(descobertos / total, descobertos .. " / " .. total)
		local faltam = total - descobertos
		premioTexto.Text = if faltam == 0
			then "<b>Álbum completo!</b> Você é um verdadeiro confeiteiro."
			else string.format(
				"<b>Complete esta página</b>\nFaltam %d Docinho%s",
				faltam,
				if faltam == 1 then "" else "s"
			)
		desenharDetalhe()
	end

	Estado.aoMudar(function()
		if Navegacao.aberto() == "Album" then
			desenhar()
		end
	end)
	Navegacao.aoTrocar(function(nome)
		if nome == "Album" then
			desenhar()
			aoAbrir()
		end
	end)
end

return Album
