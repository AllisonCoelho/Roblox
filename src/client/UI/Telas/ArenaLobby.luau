-- Painel da Arena (abre no "Trono e Rankeada" perto do Primeiro Soberano, tecla G):
--   Trono     quem é o Rei do Servidor, há quanto tempo, o buff, se você já provou o valor contra
--             o Soberano e o botão de desafiar o Rei (fila)
--   Rankeada  seu rating e divisão, vitórias e derrotas, entrar ou sair da fila
--   Ranking   o top 50 global (ReplicatedStorage.RankingGlobal, publicado pelo servidor)
-- E o aviso para o Rei quando alguém o desafia (Lutar agora ou Entregar o trono).
-- O servidor confere tudo; aqui só mostra e pede.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local ArenaPvP = require(Shared.Dados.ArenaPvP)
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local Cores = require(Shared.Tema).Orbita
local Cartoes = require(script.Parent.Parent.Cartoes)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Tela = {}
local NOME = "ArenaLobby"
local OURO = Color3.fromHex("FFC83D")
local RUBRO = Color3.fromHex("FF735D")

local estrutura: Cartoes.Estrutura
local abas: { [string]: Cartoes.Aba } = {}
local aba = "Trono"
local aviso: (string) -> ()
local pedindo = false

local function arena(): ArenaPvP.Perfil
	local e = Estado.atual :: any
	return ArenaPvP.normalizar(e and e.arena)
end

local function pedir(acao: string, ...: any)
	if pedindo then
		return
	end
	pedindo = true
	local args = table.pack(...)
	task.spawn(function()
		local _, msg = Estado.pedir(acao, table.unpack(args, 1, args.n))
		pedindo = false
		if msg then
			aviso(msg)
		end
		Tela.desenhar()
	end)
end

local function tempo(segundos: number): string
	local s = math.max(0, math.floor(segundos))
	if s >= 3600 then
		return string.format("%dh %02dmin", s // 3600, (s % 3600) // 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

local function paragrafo(ordem: number, texto: string, cor: Color3?)
	Kit.texto({
		RichText = true,
		Text = texto,
		TextSize = 17,
		TextColor3 = cor or Cores.Texto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = ordem,
		Parent = estrutura.lista,
	})
end

local function botao(ordem: number, texto: string, tom: Kit.Tom, acao: () -> ())
	local linha = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = ordem,
		Parent = estrutura.lista,
	})
	Kit.botaoPlaca({
		texto = texto,
		tamanho = UDim2.fromOffset(300, 50),
		tamanhoTexto = 19,
		tom = tom,
		pai = linha,
		aoClicar = acao,
	})
end

-- ===================================================================== Trono

local function abaTrono()
	local eu = Players.LocalPlayer
	local reiId = tonumber(Workspace:GetAttribute("ReiDoServidor")) or 0
	local reiNome = tostring(Workspace:GetAttribute("ReiNome") or "Primeiro Soberano")
	local desde = tonumber(Workspace:GetAttribute("ReiDesde")) or 0
	local souRei = reiId == eu.UserId
	local a = arena()
	local texto
	if reiId == 0 then
		texto =
			"O trono está com o <b>Primeiro Soberano</b>. Derrote-o no duelo do trono para virar o Rei do Servidor."
	else
		texto = string.format(
			"<b>%s</b> reina há %s.%s",
			reiNome,
			tempo(Workspace:GetServerTimeNow() - desde),
			if souRei then " <b>É você!</b>" else ""
		)
	end
	Cartoes.banner({
		pai = estrutura.lista,
		ordem = 1,
		cor = OURO,
		icone = 33,
		titulo = "Rei do Servidor",
		texto = texto
			.. '<br/><font color="#B7FFD9">O Rei ganha +25% de Pontos de Aura e +10% de sorte enquanto reinar, além da coroa.</font>',
		altura = 126,
	})
	Cartoes.secao(estrutura.lista, 2, "Como funciona", "Duelos sem rating, só pelo trono")
	paragrafo(
		3,
		"1. Derrote o <b>Primeiro Soberano</b> (fale com ele e escolha Desafiar). Isso prova o seu valor para sempre.\n"
			.. "2. Se o trono estiver com o Soberano, você vira o Rei.\n"
			.. "3. Se já houver um Rei, desafie-o aqui. Quem vencer o 1x1 fica com o trono.\n"
			.. "4. Se o Rei sair do servidor, o trono volta ao Soberano.",
		Cores.TextoSuave
	)
	Cartoes.secao(estrutura.lista, 4, "Você", "")
	local fila = eu:GetAttribute("TronoFila")
	paragrafo(
		5,
		string.format(
			"Prova do Soberano: %s · Reinados: <b>%d</b> · Reinado mais longo: <b>%s</b>",
			if a.monarca > 0
				then string.format('<font color="#B7FFD9">feita (%d vitórias)</font>', a.monarca)
				else '<font color="#FF735D">ainda não</font>',
			a.reinados,
			tempo(a.maiorReinado)
		)
	)
	if souRei then
		paragrafo(
			6,
			"Você é o Rei. Quando alguém desafiar, você terá alguns segundos para Lutar ou Entregar o trono.",
			OURO
		)
	elseif reiId == 0 then
		paragrafo(
			6,
			"Vá até o Primeiro Soberano e escolha Desafiar para disputar o trono.",
			Cores.Menta
		)
	elseif a.monarca <= 0 then
		paragrafo(6, "Derrote o Primeiro Soberano primeiro para poder desafiar o Rei.", RUBRO)
	elseif type(fila) == "number" then
		paragrafo(
			7,
			string.format("Você está na fila do trono: posição <b>%d</b>.", fila),
			Cores.Menta
		)
		botao(8, "Sair da fila", "neutro", function()
			pedir("TronoSairFila")
		end)
	else
		botao(8, "Desafiar o Rei " .. reiNome, "lilas", function()
			pedir("TronoDesafiar")
		end)
	end
end

-- ===================================================================== Rankeada

local function abaRankeada()
	local eu = Players.LocalPlayer
	local a = arena()
	local div = ArenaPvP.divisao(a.rating)
	local total = a.vitorias + a.derrotas
	Cartoes.banner({
		pai = estrutura.lista,
		ordem = 1,
		cor = Color3.fromHex(div.cor),
		icone = 36,
		titulo = string.format("%s · %d", div.nome, a.rating),
		texto = string.format(
			"Vitórias <b>%d</b> · Derrotas <b>%d</b> · Aproveitamento <b>%s</b>",
			a.vitorias,
			a.derrotas,
			if total > 0
				then string.format("%d%%", math.floor(a.vitorias / total * 100 + 0.5))
				else "—"
		)
			.. '<br/><font color="#C9C7D6">Vencer quem tem rating maior vale mais. Sair do duelo conta como derrota.</font>',
		altura = 118,
	})
	Cartoes.secao(estrutura.lista, 2, "Fila", "Oponentes deste servidor com rating parecido")
	if eu:GetAttribute("RankeadaFila") then
		paragrafo(
			3,
			"Procurando um oponente... A busca aceita ratings mais distantes quanto mais você espera.",
			Cores.Menta
		)
		botao(4, "Sair da fila", "neutro", function()
			pedir("RankeadaSair")
		end)
	else
		botao(4, "Entrar na fila da Rankeada", "lilas", function()
			pedir("RankeadaEntrar")
		end)
	end
	Cartoes.secao(estrutura.lista, 5, "Divisões", "")
	local partes = {}
	for _, d in ArenaPvP.DIVISOES do
		table.insert(
			partes,
			string.format('<font color="#%s"><b>%s</b></font> %d+', d.cor, d.nome, d.minimo)
		)
	end
	paragrafo(6, table.concat(partes, "   ·   "))
	paragrafo(
		7,
		"Os dois escolhem a ação ao mesmo tempo. O dano segue a Pontuação de Aura: o mais forte leva vantagem, mas entre auras parecidas cada turno decide.",
		Cores.TextoSuave
	)
end

-- ===================================================================== Ranking global

local function abaRanking()
	local valor = ReplicatedStorage:FindFirstChild("RankingGlobal")
	local ok, dados = pcall(function()
		return HttpService:JSONDecode(
			if valor and valor:IsA("StringValue") then valor.Value else "{}"
		)
	end)
	local lista = if ok
			and type(dados) == "table"
			and type(dados.lista) == "table"
		then dados.lista
		else {}
	local global = ok and type(dados) == "table" and dados.global == true
	Cartoes.secao(
		estrutura.lista,
		1,
		"Ranking global",
		if global
			then "Top 50 de todos os servidores · atualiza a cada minuto"
			else "Só este servidor (teste no Studio)"
	)
	if #lista == 0 then
		paragrafo(2, "Ninguém jogou a Rankeada ainda. Seja o primeiro!", Cores.TextoSuave)
		return
	end
	local eu = Players.LocalPlayer.UserId
	for i, l in lista do
		local div = ArenaPvP.divisao(tonumber(l.rating) or 0)
		local linha = Kit.novo("Frame", {
			BackgroundColor3 = if l.id == eu then Cores.Elevado else Cores.Painel,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 1 + i,
			Parent = estrutura.lista,
		})
		Kit.novo("UICorner", { CornerRadius = UDim.new(0, 6), Parent = linha })
		Kit.texto({
			fonte = "titulo",
			Text = string.format("#%d", i),
			TextSize = 17,
			TextColor3 = if i <= 3 then OURO else Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(0, 50, 1, 0),
			Parent = linha,
		})
		Kit.texto({
			Text = tostring(l.nome),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(64, 0),
			Size = UDim2.new(1, -280, 1, 0),
			Parent = linha,
		})
		Kit.texto({
			RichText = true,
			fonte = "mono",
			Text = string.format(
				'<font color="#%s">%s</font>  %s',
				div.cor,
				div.nome,
				Formato.inteiro(tonumber(l.rating) or 0)
			),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.fromOffset(210, 34),
			Parent = linha,
		})
	end
end

-- ===================================================================== desenho

function Tela.desenhar()
	if Navegacao.aberto() ~= NOME or not Estado.atual then
		return
	end
	for nome, a in abas do
		a.definirAtiva(nome == aba)
	end
	for _, filho in estrutura.lista:GetChildren() do
		if filho:IsA("GuiObject") then
			filho:Destroy()
		end
	end
	local ok, erro = pcall(
		if aba == "Trono" then abaTrono elseif aba == "Rankeada" then abaRankeada else abaRanking
	)
	if not ok then
		warn("[ArenaLobby] " .. tostring(erro))
	end
end

function Tela.abrir()
	Navegacao.alternar(NOME)
end

-- ===================================================================== aviso do Rei

local function montarDesafio(raiz: Frame)
	local placa = Kit.placa({
		nome = "DesafioDoTrono",
		tamanho = UDim2.fromOffset(460, 150),
		ancora = Vector2.new(0.5, 0),
		posicao = UDim2.new(0.5, 0, 0, 120),
		borda = OURO,
		corte = 14,
		z = 30,
		pai = raiz,
	})
	placa.quadro.Visible = false
	local texto = Kit.texto({
		RichText = true,
		Text = "",
		TextSize = 19,
		TextWrapped = true,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 70),
		Parent = placa.conteudo,
	})
	local prazo = 0
	local de = ""
	local function responder(r: string)
		placa.quadro.Visible = false
		task.spawn(function()
			local _, msg = Estado.pedir("TronoResponder", r)
			if msg then
				aviso(msg)
			end
		end)
	end
	local lutar = Kit.botaoPlaca({
		texto = "Lutar agora",
		tamanho = UDim2.fromOffset(200, 46),
		tamanhoTexto = 18,
		tom = "lilas",
		pai = placa.conteudo,
		aoClicar = function()
			responder("lutar")
		end,
	})
	lutar.placa.quadro.Position = UDim2.new(0, 16, 1, -58)
	local entregar = Kit.botaoPlaca({
		texto = "Entregar o trono",
		tamanho = UDim2.fromOffset(200, 46),
		tamanhoTexto = 18,
		tom = "neutro",
		pai = placa.conteudo,
		aoClicar = function()
			responder("entregar")
		end,
	})
	entregar.placa.quadro.AnchorPoint = Vector2.new(1, 0)
	entregar.placa.quadro.Position = UDim2.new(1, -16, 1, -58)
	Remotos.evento("Trono").OnClientEvent:Connect(function(dados)
		if type(dados) ~= "table" or dados.tipo ~= "desafio" then
			return
		end
		prazo = tonumber(dados.prazo) or 0
		de = tostring(dados.de)
		placa.quadro.Visible = true
	end)
	RunService.Heartbeat:Connect(function()
		if not placa.quadro.Visible then
			return
		end
		local falta = prazo - Workspace:GetServerTimeNow()
		if falta <= 0 or Players.LocalPlayer:GetAttribute("EmDueloArena") then
			placa.quadro.Visible = false
			return
		end
		texto.Text = string.format(
			"👑 <b>%s</b> desafiou você pelo trono!<br/>O duelo começa sozinho em <b>%d s</b>.",
			de,
			math.ceil(falta)
		)
	end)
end

function Tela.montar(raiz: Frame, aoAviso: (string) -> ())
	aviso = aoAviso
	local painel = Navegacao.criarPainel(NOME, { titulo = "Arena do Trono", icone = 33 }, function()
		Tela.desenhar()
	end)
	estrutura = Cartoes.estrutura(painel.conteudo)
	local lista = {
		{ "Trono", 33, OURO },
		{ "Rankeada", 36, Cores.Lilas },
		{ "Ranking", 3, Cores.Menta },
	}
	for i, d in lista do
		abas[d[1]] = Cartoes.aba(estrutura.lateral, i, d[1], d[2], d[3], function()
			aba = d[1]
			estrutura.conteudo.CanvasPosition = Vector2.zero
			Tela.desenhar()
		end)
	end
	montarDesafio(raiz)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "PainelArena" then
			Navegacao.abrir(NOME)
		end
	end)
	-- redesenha quando algo muda (Rei, fila, perfil, ranking)
	local eu = Players.LocalPlayer
	for _, nome in { "ReiDoServidor", "ReiDesde" } do
		Workspace:GetAttributeChangedSignal(nome):Connect(Tela.desenhar)
	end
	for _, nome in { "TronoFila", "RankeadaFila", "RatingArena" } do
		eu:GetAttributeChangedSignal(nome):Connect(Tela.desenhar)
	end
	task.spawn(function()
		local valor = ReplicatedStorage:WaitForChild("RankingGlobal", 30)
		if valor and valor:IsA("StringValue") then
			valor.Changed:Connect(function()
				if aba == "Ranking" then
					Tela.desenhar()
				end
			end)
		end
	end)
	Estado.aoMudar(function()
		Tela.desenhar()
	end)
end

return Tela
