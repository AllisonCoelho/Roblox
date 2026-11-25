-- Ecos (pets): o Cristal do Nexo desperta Núcleos em troca de Fragmentos. Duas abas:
--   Núcleos   um cartão por Núcleo com o modelo 3D girando, preço, chances de cada Eco e os
--             botões Abrir 1 / Abrir 3 (o servidor confere tudo e sorteia).
--   Meus Ecos a coleção, com o bônus de cada um, Equipar/Desequipar, Equipar melhores e
--             Libertar (dois toques).
-- Abrir mostra a revelação: o Núcleo treme, racha e o Eco aparece com nome, raridade e bônus.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Formato = require(Shared.Formato)
local Pets = require(Shared.Dados.Pets)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local EcosMundo = require(script.Parent.Parent.Parent.Mundo.Ecos)

local Tela = {}
Tela.ICONE = 28 -- broto (vida que nasce)

local estrutura: Cartoes.Estrutura
local abas: { [string]: Cartoes.Aba } = {}
local aba = "Nucleos"
local aviso: (string) -> ()
local pedindo = false
local libertando: string? = nil
local camada: Frame
type Vitrine = {
	modelo: EcosMundo.Modelo,
	camera: Camera,
	raio: number,
	alvo: Vector3,
	lista: boolean,
}
local girando: { Vitrine } = {}
local naRevelacao = false

local ARCO_IRIS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF7BB9")),
	ColorSequenceKeypoint.new(0.25, Color3.fromHex("FFE27A")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("7BF0A0")),
	ColorSequenceKeypoint.new(0.75, Color3.fromHex("7FD8FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("C0ADFF")),
})

local function corRaridade(r: number): Color3
	return Color3.fromHex(Pets.RARIDADES[r].cor)
end

-- Vitrine 3D: um ViewportFrame com o modelo girando devagar
local function vitrine(
	pai: Instance,
	modelo: EcosMundo.Modelo?,
	posicao: UDim2,
	tamanho: UDim2
): ViewportFrame
	local v = Kit.novo("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromHex("8C82B4"),
		LightColor = Color3.fromHex("FFF4E6"),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Position = posicao,
		Size = tamanho,
		Parent = pai,
	}) :: ViewportFrame
	if not modelo then
		return v
	end
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = v
	v.CurrentCamera = camera
	modelo.modelo.Parent = v
	local h = math.max(modelo.altura, 1.5)
	EcosMundo.posar(modelo, CFrame.new(), 0)
	table.insert(girando, {
		modelo = modelo,
		camera = camera,
		raio = h * 2.3 + 1.5,
		alvo = Vector3.new(0, h * 0.5, 0),
		lista = not naRevelacao,
	})
	return v
end

local function limparLista()
	for i = #girando, 1, -1 do
		if girando[i].lista then
			table.remove(girando, i)
		end
	end
	for _, filho in estrutura.lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
end

local function colecao(): (Pets.Colecao, any)
	local estado = Estado.atual :: any
	return Pets.normalizar(estado and estado.pets), estado and estado.corredor
end

local function pedir(acao: string, ...: any): (boolean, { [string]: any }?)
	if pedindo then
		return false, nil
	end
	pedindo = true
	local ok, msg, dados = Estado.pedir(acao, ...)
	pedindo = false
	if msg then
		aviso(msg)
	end
	return ok, dados
end

-- ===================================================================== revelação

local function revelar(nucleo: Pets.Nucleo, nascidos: { { [string]: any } })
	for _, filho in camada:GetChildren() do
		filho:Destroy()
	end
	naRevelacao = true
	camada.Visible = true
	camada.BackgroundTransparency = 1
	TweenService:Create(camada, TweenInfo.new(0.25), { BackgroundTransparency = 0.3 }):Play()
	local cor = Color3.fromHex(nucleo.cor)
	-- 1) o Núcleo treme e racha
	local nucleoModelo = EcosMundo.modeloNucleo(nucleo.numero)
	local quadroNucleo = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(300, 300),
		Parent = camada,
	})
	vitrine(quadroNucleo, nucleoModelo, UDim2.new(), UDim2.fromScale(1, 1))
	local inicio = os.clock()
	while os.clock() - inicio < 1.1 do
		local f = (os.clock() - inicio) / 1.1
		quadroNucleo.Position = UDim2.new(0.5, math.sin(os.clock() * 60) * 10 * f, 0.45, 0)
		quadroNucleo.Rotation = math.sin(os.clock() * 45) * 8 * f
		task.wait()
	end
	-- 2) clarão
	local clarao = Kit.novo("Frame", {
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = camada,
	})
	quadroNucleo:Destroy()
	TweenService
		:Create(clarao, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		:Play()
	-- 3) os Ecos que nasceram
	local fila = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(#nascidos * 250 - 14, 380),
		Parent = camada,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = fila,
	})
	for i, n in nascidos do
		local eco = Pets.porId[n.eco]
		if not eco then
			continue
		end
		local corEco = corRaridade(eco.raridade)
		local p = Kit.placa({
			tamanho = UDim2.fromOffset(236, 380),
			borda = corEco,
			corte = 14,
			ordem = i,
			pai = fila,
		})
		if n.prisma then
			local brilho = Kit.novo("UIGradient", { Color = ARCO_IRIS, Rotation = 45 })
			for _, f in p.quadro:GetChildren() do
				if f:IsA("Frame") and f.Name ~= "Conteudo" then
					brilho:Clone().Parent = f
				end
			end
		end
		vitrine(
			p.conteudo,
			EcosMundo.modelo(n.eco, n.prisma),
			UDim2.fromOffset(8, 8),
			UDim2.new(1, -16, 0, 200)
		)
		Kit.texto({
			fonte = "titulo",
			Text = (if n.prisma then "PRISMÁTICO · " else "")
				.. string.upper(Pets.RARIDADES[eco.raridade].nome),
			TextSize = 15,
			TextColor3 = if n.prisma then Color3.fromHex("FFE27A") else corEco,
			Position = UDim2.fromOffset(8, 210),
			Size = UDim2.new(1, -16, 0, 20),
			Parent = p.conteudo,
		})
		Kit.texto({
			fonte = "titulo",
			Text = eco.nome,
			TextSize = 24,
			TextColor3 = Kit.corLegivel(corEco),
			TextWrapped = true,
			Position = UDim2.fromOffset(8, 232),
			Size = UDim2.new(1, -16, 0, 30),
			Parent = p.conteudo,
		})
		Kit.texto({
			Text = Pets.textoBonus(eco, n.prisma),
			TextSize = 16,
			TextColor3 = Cores.Menta,
			Position = UDim2.fromOffset(8, 264),
			Size = UDim2.new(1, -16, 0, 22),
			Parent = p.conteudo,
		})
		Kit.texto({
			Text = eco.conceito,
			TextSize = 13,
			TextColor3 = Cores.TextoSuave,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(12, 290),
			Size = UDim2.new(1, -24, 0, 80),
			Parent = p.conteudo,
		})
		local escala = Kit.novo("UIScale", { Scale = 0.2, Parent = p.quadro })
		TweenService:Create(
			escala,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.12 * i),
			{ Scale = 1 }
		):Play()
	end
	local continuar = Kit.botaoPlaca({
		texto = "Continuar",
		tamanho = UDim2.fromOffset(220, 48),
		tom = "lilas",
		pai = camada,
		aoClicar = function()
			camada.Visible = false
			for i = #girando, 1, -1 do
				if not girando[i].lista then
					table.remove(girando, i)
				end
			end
			for _, filho in camada:GetChildren() do
				filho:Destroy()
			end
		end,
	})
	naRevelacao = false
	continuar.placa.quadro.AnchorPoint = Vector2.new(0.5, 0)
	continuar.placa.quadro.Position = UDim2.new(0.5, 0, 0.47, 205)
end

-- ===================================================================== abas

local desenhar: () -> ()

local function abaNucleos()
	local c, corredor = colecao()
	local frag = if type(corredor) == "table" then corredor.fragmentos or 0 else 0
	Cartoes.banner({
		pai = estrutura.lista,
		ordem = 1,
		cor = Cores.Lilas,
		icone = Tela.ICONE,
		titulo = string.format("Cristal do Nexo · %s Fragmentos", Formato.inteiro(frag)),
		texto = string.format(
			"Cada Núcleo guarda um Eco de um mundo do Corredor. Desperte, equipe até <b>%d</b> e ganhe bônus.<br/>"
				.. 'Coleção %d / %d · Ecos vistos %d / %d<br/><font color="#FFE27A">1 em %d nasce PRISMÁTICO: bônus em dobro.</font>',
			Pets.slots(corredor),
			Pets.quantidade(c),
			Pets.CAPACIDADE,
			(function()
				local n = 0
				for _ in c.vistos do
					n += 1
				end
				return n
			end)(),
			#Pets.ECOS,
			math.floor(1 / Pets.PRISMA_CHANCE + 0.5)
		),
		altura = 128,
	})
	Cartoes.secao(estrutura.lista, 2, "Núcleos", "Chances exibidas · pagos só com Fragmentos")
	local grade = Cartoes.grade(estrutura.lista, 3, Vector2.new(250, 420))
	for i, nucleo in Pets.NUCLEOS do
		local liberado = Pets.nucleoLiberado(nucleo, corredor)
		local cor = Color3.fromHex(nucleo.cor)
		local p = Kit.placa({
			tamanho = UDim2.fromScale(1, 1),
			borda = if liberado then cor else Cores.Borda,
			corte = 14,
			ordem = i,
			pai = grade,
		})
		vitrine(
			p.conteudo,
			EcosMundo.modeloNucleo(i),
			UDim2.fromOffset(40, 6),
			UDim2.new(1, -80, 0, 130)
		)
		Kit.texto({
			fonte = "titulo",
			Text = nucleo.nome,
			TextSize = 21,
			TextColor3 = if liberado then Kit.corLegivel(cor) else Cores.TextoSuave,
			Position = UDim2.fromOffset(8, 138),
			Size = UDim2.new(1, -16, 0, 26),
			Parent = p.conteudo,
		})
		Kit.texto({
			fonte = "mono",
			Text = string.format("◆ %d Fragmentos", nucleo.preco),
			TextSize = 15,
			TextColor3 = Color3.fromHex("C9A2FF"),
			Position = UDim2.fromOffset(8, 164),
			Size = UDim2.new(1, -16, 0, 20),
			Parent = p.conteudo,
		})
		for k, ch in Pets.chances(nucleo) do
			local eco = Pets.porId[ch.id]
			local visto = c.vistos[ch.id] == true
			local linha = Kit.texto({
				RichText = true,
				Text = string.format(
					'<font color="#%s">%s</font>  %s',
					Pets.RARIDADES[eco.raridade].cor,
					if visto then eco.nome else "???",
					(string.format("%.0f%%", ch.chance * 100))
				),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(14, 190 + (k - 1) * 40),
				Size = UDim2.new(1, -28, 0, 18),
				Parent = p.conteudo,
			})
			linha.TextTruncate = Enum.TextTruncate.AtEnd
			Kit.texto({
				Text = Pets.textoBonus(eco),
				TextSize = 12,
				TextColor3 = Cores.TextoSuave,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(14, 208 + (k - 1) * 40),
				Size = UDim2.new(1, -28, 0, 16),
				Parent = p.conteudo,
			})
		end
		if not liberado then
			local b = Kit.botaoPlaca({
				texto = string.format("Conclua a fase %d", nucleo.fase),
				tamanho = UDim2.new(1, -16, 0, 44),
				tamanhoTexto = 15,
				tom = "neutro",
				pai = p.conteudo,
				aoClicar = function()
					aviso(
						string.format(
							"Conclua a fase %d do Corredor dos Perdidos para abrir este Núcleo.",
							nucleo.fase
						)
					)
				end,
			})
			b.placa.quadro.Position = UDim2.new(0, 8, 1, -52)
		else
			for k, qtd in { 1, 3 } do
				local b = Kit.botaoPlaca({
					texto = string.format("Abrir %d", qtd),
					tamanho = UDim2.new(0.5, -12, 0, 44),
					tamanhoTexto = 16,
					tom = if frag >= nucleo.preco * qtd then "lilas" else "neutro",
					pai = p.conteudo,
					aoClicar = function()
						task.spawn(function()
							local ok, dados = pedir("AbrirNucleo", i, qtd)
							if ok and dados and type(dados.ecos) == "table" then
								revelar(nucleo, dados.ecos)
							end
						end)
					end,
				})
				b.placa.quadro.Position = UDim2.new((k - 1) * 0.5, 8, 1, -52)
			end
		end
	end
end

local function abaMeus()
	local c, corredor = colecao()
	local slots = Pets.slots(corredor)
	local ganho, sorte, frag = Pets.multiplicadores(c)
	Cartoes.banner({
		pai = estrutura.lista,
		ordem = 1,
		cor = Cores.Menta,
		icone = Tela.ICONE,
		titulo = string.format("Meus Ecos · %d / %d equipados", #c.equipados, slots),
		texto = string.format(
			'Bônus atuais: <font color="#B7FFD9"><b>+%d%% Pontos de Aura</b></font> · <font color="#7BF0A0"><b>+%d%% Sorte</b></font> · <font color="#C9A2FF"><b>+%d%% Fragmentos</b></font><br/>'
				.. '<font color="#C9C7D6">Mais espaços: conclua as fases 3 e 6 do Corredor. Libertar um Eco devolve %d%% do Núcleo.</font>',
			math.floor((ganho - 1) * 100 + 0.5),
			math.floor((sorte - 1) * 100 + 0.5),
			math.floor((frag - 1) * 100 + 0.5),
			math.floor(Pets.DEVOLUCAO * 100)
		),
		botao = "Equipar melhores",
		aoClicar = function()
			task.spawn(pedir, "EquiparMelhoresEcos")
		end,
		altura = 128,
	})
	Cartoes.secao(
		estrutura.lista,
		2,
		"Coleção",
		string.format("%d / %d", Pets.quantidade(c), Pets.CAPACIDADE)
	)
	local uids = {}
	for uid in c.lista do
		table.insert(uids, uid)
	end
	if #uids == 0 then
		Kit.texto({
			Text = "Nenhum Eco ainda. Conclua a fase 1 do Corredor, junte Fragmentos e desperte um Núcleo no Cristal do Nexo.",
			TextSize = 17,
			TextColor3 = Cores.TextoSuave,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 3,
			Parent = estrutura.lista,
		})
		return
	end
	table.sort(uids, function(a, b)
		local ea, eb = Pets.equipado(c, a), Pets.equipado(c, b)
		if ea ~= eb then
			return ea
		end
		local fa, fb = Pets.forca(c.lista[a]), Pets.forca(c.lista[b])
		if fa ~= fb then
			return fa > fb
		end
		return a < b
	end)
	local grade = Cartoes.grade(estrutura.lista, 3, Vector2.new(196, 300))
	for i, uid in uids do
		local g = c.lista[uid]
		local eco = Pets.porId[g.eco]
		local equipado = Pets.equipado(c, uid)
		local cor = corRaridade(eco.raridade)
		local p = Kit.placa({
			tamanho = UDim2.fromScale(1, 1),
			borda = if equipado then Cores.Menta else cor,
			corte = 12,
			ordem = i,
			pai = grade,
		})
		if g.prisma then
			Kit.novo(
				"UIStroke",
				{ Thickness = 2, Color = Color3.new(1, 1, 1), Parent = p.conteudo }
			)
			Kit.novo("UIGradient", {
				Color = ARCO_IRIS,
				Rotation = 45,
				Parent = p.conteudo:FindFirstChildOfClass("UIStroke"),
			})
		end
		vitrine(
			p.conteudo,
			EcosMundo.modelo(g.eco, g.prisma),
			UDim2.fromOffset(6, 6),
			UDim2.new(1, -12, 0, 120)
		)
		Kit.texto({
			fonte = "titulo",
			Text = eco.nome,
			TextSize = 18,
			TextColor3 = Kit.corLegivel(cor),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(6, 128),
			Size = UDim2.new(1, -12, 0, 22),
			Parent = p.conteudo,
		})
		Kit.texto({
			Text = (if g.prisma then "Prismático · " else "")
				.. Pets.RARIDADES[eco.raridade].nome,
			TextSize = 13,
			TextColor3 = if g.prisma then Color3.fromHex("FFE27A") else Cores.TextoSuave,
			Position = UDim2.fromOffset(6, 150),
			Size = UDim2.new(1, -12, 0, 16),
			Parent = p.conteudo,
		})
		Kit.texto({
			Text = Pets.textoBonus(eco, g.prisma),
			TextSize = 15,
			TextColor3 = Cores.Menta,
			Position = UDim2.fromOffset(6, 170),
			Size = UDim2.new(1, -12, 0, 20),
			Parent = p.conteudo,
		})
		local b = Kit.botaoPlaca({
			texto = if equipado then "Desequipar" else "Equipar",
			tamanho = UDim2.new(1, -12, 0, 40),
			tamanhoTexto = 16,
			tom = if equipado then "menta" else "lilas",
			pai = p.conteudo,
			aoClicar = function()
				task.spawn(pedir, "EquiparEco", uid, not equipado)
			end,
		})
		b.placa.quadro.Position = UDim2.new(0, 6, 1, -92)
		local confirmar = libertando == uid
		local l = Kit.botaoPlaca({
			texto = if confirmar
				then string.format(
					"Confirmar (+%d)",
					math.floor(Pets.NUCLEOS[eco.nucleo].preco * Pets.DEVOLUCAO)
				)
				else "Libertar",
			tamanho = UDim2.new(1, -12, 0, 36),
			tamanhoTexto = 14,
			tom = "neutro",
			pai = p.conteudo,
			aoClicar = function()
				if equipado then
					aviso("Desequipe o Eco antes de libertá-lo.")
					return
				end
				if libertando ~= uid then
					libertando = uid
					desenhar()
					return
				end
				libertando = nil
				task.spawn(pedir, "LibertarEco", uid)
			end,
		})
		l.placa.quadro.Position = UDim2.new(0, 6, 1, -46)
	end
end

local desenhando = false
local pendente = false
desenhar = function()
	if Navegacao.aberto() ~= "Ecos" or not Estado.atual then
		return
	end
	-- montar as vitrines pode levar alguns quadros: um desenho por vez, o último pedido vence
	if desenhando then
		pendente = true
		return
	end
	desenhando = true
	for nome, a in abas do
		a.definirAtiva(nome == aba)
	end
	limparLista()
	local ok, erro = pcall(if aba == "Nucleos" then abaNucleos else abaMeus)
	desenhando = false
	if not ok then
		warn("[Ecos] " .. tostring(erro))
	end
	if pendente then
		pendente = false
		desenhar()
	end
end

function Tela.abrir(qual: string?)
	if Navegacao.aberto() == "Ecos" then
		if qual and qual ~= aba then
			aba = qual
			desenhar()
		else
			Navegacao.fechar()
		end
		return
	end
	if qual then
		aba = qual
	end
	Navegacao.abrir("Ecos")
end

function Tela.montar(raiz: Frame, aoAviso: (string) -> ())
	aviso = aoAviso
	local painel = Navegacao.criarPainel(
		"Ecos",
		{ titulo = "Ecos do Nexo", icone = Tela.ICONE },
		function()
			libertando = nil
			desenhar()
		end
	)
	estrutura = Cartoes.estrutura(painel.conteudo)
	for i, d in
		{
			{ "Nucleos", "Núcleos", 9, Color3.fromHex("C0ADFF") },
			{ "Meus", "Meus Ecos", 28, Color3.fromHex("B7FFD9") },
		}
	do
		abas[d[1]] = Cartoes.aba(estrutura.lateral, i, d[2], d[3], d[4], function()
			aba = d[1]
			libertando = nil
			estrutura.conteudo.CanvasPosition = Vector2.zero
			desenhar()
		end)
	end
	-- camada da revelação, por cima de tudo
	camada = Kit.novo("Frame", {
		Name = "RevelacaoEco",
		BackgroundColor3 = Color3.fromHex("0B0915"),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Visible = false,
		Parent = raiz,
	}) :: Frame
	Estado.aoMudar(function()
		desenhar()
	end)
	-- giro das vitrines 3D
	RunService.RenderStepped:Connect(function()
		if #girando == 0 then
			return
		end
		local t = os.clock()
		for i, g in girando do
			local a = t * 0.7 + i
			g.camera.CFrame = CFrame.lookAt(
				g.alvo + Vector3.new(math.sin(a) * g.raio, g.raio * 0.35, math.cos(a) * g.raio),
				g.alvo
			)
			EcosMundo.posar(g.modelo, CFrame.new(), t)
		end
	end)
end

return Tela
