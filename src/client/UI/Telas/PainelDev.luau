-- Ferramentas de desenvolvimento no mesmo visual das demais telas do Despertar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local AurasVfx = require(Shared.Dados.AurasVfx)
local Formato = require(Shared.Formato)
local Incursoes = require(Shared.Dados.Incursoes)
local Tema = require(Shared.Tema)
local Cores = Tema.Orbita
local Escala = require(script.Parent.Parent.Escala)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Avisos = require(script.Parent.Avisos)

local PainelDev = {}
local NOME = "PainelDev"
local ABAS = { "Sessão", "Auras", "VFX", "Rituais", "Mapa", "Incursões" }
local DESTINOS = {
	{ "praca", "Praça do Núcleo" },
	{ "arquivo", "Arquivo dos Ecos" },
	{ "obelisco", "Obelisco das Lendas" },
	{ "jardim", "Jardim dos Fragmentos" },
	{ "altar", "Altar da Ressonância" },
	{ "portais", "Portais Fragmentados" },
	{ "arena", "Arena do Trono" },
	{ "bastiao", "Bastião das Incursões" },
}
local NOMES_VFX = {
	gear5 = "Gear 5",
	monarca = "Monarca das Sombras",
	naruto_seis = "Modo Sábio dos Seis Caminhos",
}

type Opcoes = {
	podeAbrir: () -> boolean,
	aoRitual: (string, { [string]: any }) -> (),
}

local ocupado = false

function PainelDev.pendente(): boolean
	return ocupado
end

local function texto(pai: Instance, valor: string, tamanho: number?): TextLabel
	return Kit.texto({
		Text = valor,
		TextSize = tamanho or 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #pai:GetChildren(),
		Parent = pai,
	})
end

local function botao(
	pai: Instance,
	rotulo: string,
	clicar: () -> (),
	ordem: number?,
	tom: Kit.Tom?
): Kit.BotaoPlaca
	return Kit.botaoPlaca({
		texto = rotulo,
		tamanho = UDim2.new(1, -10, 0, 64),
		tamanhoTexto = 19,
		tom = tom,
		pai = pai,
		ordem = ordem or #pai:GetChildren(),
		aoClicar = clicar,
	})
end

local function entrada(pai: Instance, dica: string): TextBox
	local caixa = Kit.novo("TextBox", {
		Text = "",
		PlaceholderText = dica,
		PlaceholderColor3 = Cores.TextoSuave,
		TextColor3 = Cores.Texto,
		FontFace = Tema.FonteCorpo,
		TextSize = 18,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = Cores.Elevado,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -10, 0, 64),
		LayoutOrder = #pai:GetChildren(),
		Parent = pai,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(0, 6), Parent = caixa })
	Kit.novo("UIStroke", {
		Color = Cores.Borda,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = caixa,
	})
	Kit.novo(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = caixa }
	)
	return caixa
end

local function grade(pai: Instance, maximo: number): (Frame, () -> ())
	local quadro = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 0, 0),
		LayoutOrder = #pai:GetChildren(),
		Parent = pai,
	})
	local organizacao = Kit.novo("UIGridLayout", {
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = quadro,
	})
	local function ajustar()
		local largura = math.floor(quadro.AbsoluteSize.X / Escala.escala)
		if largura <= 0 then
			return
		end
		local colunas = math.clamp(math.floor((largura + 8) / 174), 1, maximo)
		local altura = 70
		local larguraCelula = math.floor((largura - (colunas - 1) * 8) / colunas)
		organizacao.FillDirectionMaxCells = colunas
		organizacao.CellSize = UDim2.fromOffset(larguraCelula, altura)
		local visiveis = 0
		for _, item in quadro:GetChildren() do
			if item:IsA("GuiObject") and item.Visible then
				visiveis += 1
			end
		end
		local linhas = math.ceil(visiveis / colunas)
		quadro.Size = UDim2.new(1, -10, 0, math.max(0, linhas * (altura + 8) - 8))
	end
	quadro:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustar)
	Escala.aoMudar(ajustar)
	return quadro, ajustar
end

local function nomeVfx(id: string): string
	local caudas = string.match(id, "^naruto_(%d+)$")
	return NOMES_VFX[id] or (if caudas then "Naruto · " .. caudas .. " caudas" else id)
end

local function montar(paiHud: Frame, op: Opcoes)
	local jogador = Players.LocalPlayer
	local painel = Navegacao.criarPainel(NOME, { titulo = "Painel Dev", icone = "◆" })
	local function alternar()
		if Navegacao.aberto() == NOME then
			Navegacao.fechar()
		elseif op.podeAbrir() then
			Navegacao.abrir(NOME)
		end
	end
	local acesso = botao(paiHud, "DEV", alternar)
	acesso.placa.quadro.AnchorPoint = Vector2.new(1, 0)
	acesso.placa.quadro.Size = UDim2.fromOffset(118, 64)
	acesso.placa.quadro.Position = UDim2.new(1, -86, 0, 10)
	acesso.botao.Text = "Abrir painel dev"

	local abas = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 64),
		Parent = painel.conteudo,
	})
	local sessao = texto(painel.conteudo, "", 16)
	sessao.Position = UDim2.fromOffset(12, 73)
	sessao.Size = UDim2.new(1, -24, 0, 34)
	sessao.AutomaticSize = Enum.AutomaticSize.None
	local function atualizarSessao()
		local teste = jogador:GetAttribute("PerfilDeTeste") == true
		acesso.rotulo.Text = if teste then "DEV · TESTE" else "DEV"
		acesso.definirTom(if teste then "menta" else "neutro")
		sessao.Text = if teste then "TESTE · progresso temporário" else "PERFIL REAL"
		sessao.TextColor3 = if teste then Cores.Menta else Cores.TextoSuave
	end
	jogador:GetAttributeChangedSignal("PerfilDeTeste"):Connect(atualizarSessao)
	atualizarSessao()

	local paginas: { ScrollingFrame } = {}
	local botoes: { Kit.BotaoPlaca } = {}
	local function abrirPagina(indice: number)
		for i, pagina in paginas do
			pagina.Visible = i == indice
			botoes[i].definirTom(if i == indice then "lilas" else "neutro")
		end
	end
	for i, nome in ABAS do
		local guia = botao(abas, nome, function()
			abrirPagina(i)
		end)
		botoes[i] = guia

		local pagina = Kit.rolagem(painel.conteudo)
		pagina.Position = UDim2.fromOffset(12, 111)
		pagina.Size = UDim2.new(1, -24, 1, -119)
		Kit.novo("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = pagina,
		})
		paginas[i] = pagina
	end
	Escala.aoMudar(function()
		local porLinha = if Escala.tamanho.X < 664 then 3 else #ABAS
		local altura = 68 * math.ceil(#ABAS / porLinha)
		abas.Size = UDim2.new(1, -24, 0, altura)
		for i, b in botoes do
			local linha = math.floor((i - 1) / porLinha)
			local coluna = (i - 1) % porLinha
			b.placa.quadro.Position = UDim2.new(coluna / porLinha, 2, 0, linha * 68)
			b.placa.quadro.Size = UDim2.new(1 / porLinha, -4, 0, 64)
		end
		sessao.Position = UDim2.fromOffset(12, altura + 5)
		for _, pagina in paginas do
			pagina.Position = UDim2.fromOffset(12, altura + 43)
			pagina.Size = UDim2.new(1, -24, 1, -altura - 51)
		end
	end)

	local function pedir(comando: string, ...: any)
		if ocupado then
			return
		end
		ocupado = true
		local argumentos = table.pack(...)
		task.spawn(function()
			local ok, resposta, dados =
				Estado.pedir("PainelDev", comando, table.unpack(argumentos, 1, argumentos.n))
			if ok and (comando == "ritual" or comando == "girar") and resposta and dados then
				Navegacao.fechar()
				op.aoRitual(resposta, dados)
			elseif resposta then
				if ok and comando == "ir" and Navegacao.aberto() == NOME then
					Navegacao.fechar()
				end
				Avisos.toast(resposta)
			end
			ocupado = false
		end)
	end

	local perfil = paginas[1]
	texto(perfil, "Use a sessão de teste para liberar auras, universos e relíquias.")
	local modos, ajustarModos = grade(perfil, 2)
	botao(modos, "Liberar tudo", function()
		pedir("perfil", "completo")
	end, 1, "lilas")
	botao(modos, "Copiar minha conta", function()
		pedir("perfil", "copia")
	end, 2)
	botao(modos, "Conta nova de teste", function()
		pedir("perfil", "novo")
	end, 3)
	botao(modos, "Voltar ao perfil real", function()
		pedir("perfil", "real")
	end, 4)
	botao(modos, "Abrir Índice", function()
		Navegacao.abrir("Indice")
	end, 5)
	botao(modos, "Abrir Ajustes", function()
		Navegacao.abrir("Ajustes")
	end, 6)
	ajustarModos()
	local giros = entrada(perfil, "Número de giros de teste")
	botao(perfil, "Definir giros", function()
		local valor = tonumber(giros.Text)
		if valor then
			pedir("giros", valor)
		else
			Avisos.toast("Digite o número de giros")
		end
	end)

	local auras = paginas[2]
	local selecionada = Auras.lista[#Auras.lista]
	local selecao = texto(auras, "")
	local acoesAura, ajustarAcoes = grade(auras, 3)
	botao(acoesAura, "Equipar", function()
		pedir("equipar", selecionada.id)
	end, 1, "lilas")
	botao(acoesAura, "Forçar este giro", function()
		pedir("girar", selecionada.id)
	end, 2)
	botao(acoesAura, "Desequipar", function()
		pedir("equipar", "")
	end, 3)
	ajustarAcoes()
	local copias = entrada(auras, "Quantidade de cópias")
	botao(auras, "Definir quantidade", function()
		local valor = tonumber(copias.Text)
		if valor then
			pedir("quantidade", selecionada.id, valor)
		else
			Avisos.toast("Digite a quantidade de cópias")
		end
	end)
	local busca = entrada(auras, "Buscar aura pelo nome ou ID")
	local catalogo, ajustarCatalogo = grade(auras, 4)
	local escolhas: { [string]: Kit.BotaoPlaca } = {}
	local function atualizarAura()
		local tier = Auras.Tiers[selecionada.tier]
		local estado = Estado.atual
		local total = if estado then estado.auras[selecionada.id] or 0 else 0
		selecao.Text = string.format(
			"%s · %s · 1 em %s",
			selecionada.nome,
			tier.nome,
			Formato.chance(selecionada.chance)
		)
		selecao.TextColor3 = Kit.corLegivel(Color3.fromHex(tier.cor))
		copias.PlaceholderText = "Cópias atuais • " .. Formato.inteiro(total)
	end
	for _, aura in Auras.lista do
		escolhas[aura.id] = botao(catalogo, aura.nome, function()
			escolhas[selecionada.id].definirTom("neutro")
			selecionada = aura
			escolhas[aura.id].definirTom("lilas")
			copias.Text = ""
			busca:ReleaseFocus()
			atualizarAura()
			auras.CanvasPosition = Vector2.zero
		end, aura.ordem)
	end
	escolhas[selecionada.id].definirTom("lilas")
	busca:GetPropertyChangedSignal("Text"):Connect(function()
		local termo = string.lower(busca.Text):gsub("^%s+", ""):gsub("%s+$", "")
		for _, aura in Auras.lista do
			local textoBusca = string.lower(aura.nome) .. " " .. aura.id
			escolhas[aura.id].placa.quadro.Visible = string.find(textoBusca, termo, 1, true) ~= nil
		end
		ajustarCatalogo()
	end)
	Estado.aoMudar(atualizarAura)
	atualizarAura()
	ajustarCatalogo()

	local vfx = paginas[3]
	texto(
		vfx,
		"Aplique um efeito 3D ao seu personagem. Outros clientes podem vê-lo durante o teste."
	)
	botao(vfx, "Encerrar prévia", function()
		pedir("previa", "")
	end)
	local efeitos, ajustarEfeitos = grade(vfx, 3)
	local ids: { string } = {}
	for id, disponivel in AurasVfx do
		if disponivel then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for i, id in ids do
		botao(efeitos, nomeVfx(id), function()
			pedir("previa", id)
		end, i)
	end
	ajustarEfeitos()

	local rituais = paginas[4]
	botao(rituais, "Giro aleatório de teste", function()
		pedir("girar")
	end, nil, "lilas")
	texto(rituais, "Prévia por categoria. O ritual roda sem adicionar a aura à coleção.")
	local categorias, ajustarCategorias = grade(rituais, 3)
	for i, categoria in Apresentacao.Categorias do
		botao(categorias, categoria.nome, function()
			pedir("ritual", i)
		end, i)
	end
	ajustarCategorias()

	local mapa = paginas[5]
	local diagnostico = texto(mapa, "Versão " .. game.PlaceVersion)
	diagnostico.TextColor3 = Cores.TextoSuave
	local lugares, ajustarLugares = grade(mapa, 2)
	for i, destino in DESTINOS do
		botao(lugares, destino[2], function()
			pedir("ir", destino[1])
		end, i)
	end
	ajustarLugares()
	botao(mapa, "Renascer personagem", function()
		pedir("renascer")
	end)
	local tempo, quadros = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if Navegacao.aberto() ~= NOME or not mapa.Visible then
			tempo, quadros = 0, 0
			return
		end
		tempo += dt
		quadros += 1
		if tempo >= 0.6 then
			local nexo = workspace:FindFirstChild("Nexo")
			local estadoKit = if nexo then nexo:GetAttribute("EstadoKit3D") else nil
			diagnostico.Text = string.format(
				"Versão %d · %d FPS · kit 3D %s",
				game.PlaceVersion,
				math.round(quadros / tempo),
				tostring(estadoKit or "aguardando")
			)
			tempo, quadros = 0, 0
		end
	end)

	local inc = paginas[6]
	texto(inc, "Escolha um universo e o andar para começar uma Incursão solo de teste.")
	local andar =
		entrada(inc, string.format("Andar inicial de 1 a %d (padrão 1)", Incursoes.ANDARES))
	local universos, ajustarUniversos = grade(inc, 3)
	for i, universo in Incursoes.UNIVERSOS do
		botao(universos, universo.nome, function()
			local numero = if andar.Text == "" then 1 else tonumber(andar.Text)
			if numero then
				pedir("incursao", universo.id, numero)
			else
				Avisos.toast("Digite o número do andar")
			end
		end, i, "lilas")
	end
	ajustarUniversos()
	local saldo = entrada(inc, "Fragmentos de teste")
	botao(inc, "Definir fragmentos", function()
		local total = tonumber(saldo.Text)
		if total then
			pedir("fragmentos", total)
		else
			Avisos.toast("Digite a quantidade de fragmentos")
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.F8 then
			alternar()
		end
	end)
	abrirPagina(1)
	Navegacao.ajustar()
end

function PainelDev.iniciar(paiHud: Frame, op: Opcoes)
	local jogador = Players.LocalPlayer
	local montou = false
	local function verificar()
		if not montou and jogador:GetAttribute("PainelDev") == true then
			montou = true
			montar(paiHud, op)
		end
	end
	jogador:GetAttributeChangedSignal("PainelDev"):Connect(verificar)
	verificar()
end

return PainelDev
