-- Interface das Incursões: o painel da Mesa dos Cartógrafos (universos, fila e relíquias) e,
-- durante a partida, o HUD (andar, Núcleos, vidas, Guardião), o botão PULSO (tecla Q) e o
-- resultado. O cliente só pede; o servidor (src/server/Incursoes) decide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Dados = require(Shared.Dados.Incursoes)
local Remotos = require(Shared.Remotos)
local Tema = require(Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Estado = require(script.Parent.Parent.Estado)
local Visual = require(
	script.Parent.Parent.Parent
		:WaitForChild("Mundo")
		:WaitForChild("Incursoes")
		:WaitForChild("Visual")
)

local Cores = Tema.Cores
local IncursoesUI = {}

local aviso: (string) -> () = function() end
local aoPartida: (boolean) -> () = function() end
local naFila: string? = nil
local emPartida: string? = nil
local proximoPulso = 0

local function moldura(pai: Instance, props: { [string]: any }, cor: Color3?): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Cores.Tinta
	props.BorderSizePixel = 0
	props.Parent = pai
	local f = Kit.novo("Frame", props)
	Kit.novo("UICorner", { CornerRadius = UDim.new(0, 12), Parent = f })
	Kit.novo("UIStroke", { Color = cor or Cores.Borda, Thickness = 2, Parent = f })
	return f
end

local function pedir(acao: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, msg = Estado.pedir(acao, table.unpack(args, 1, args.n))
		if msg then
			aviso(msg)
		elseif not ok and acao ~= "IncursaoPulso" then
			aviso("Não deu certo. Tente de novo.")
		end
	end)
end

local function pulsar()
	if not emPartida or os.clock() < proximoPulso then
		return
	end
	proximoPulso = os.clock() + Dados.PULSO_ESPERA
	task.spawn(function()
		Estado.pedir("IncursaoPulso")
	end)
end

-- ===================================================================== painel

type Cartao = { botao: Kit.BotaoPlaca, info: TextLabel, cadeado: TextLabel, universo: Dados.Universo }
type Linha = { botao: Kit.BotaoPlaca, nivel: TextLabel, reliquia: Dados.Reliquia }

local cartoes: { Cartao } = {}
local linhas: { Linha } = {}
local cabecalho: TextLabel

local function atualizarPainel()
	local estado = Estado.atual
	local inc = if estado and type((estado :: any).incursoes) == "table"
		then (estado :: any).incursoes
		else Dados.padrao()
	local melhor = if estado then Auras.melhorDe(estado.auras) else nil
	cabecalho.Text = string.format(
		"FRAGMENTOS: %d   ·   RESSONÂNCIA: %.2fx (aura mais rara)",
		inc.fragmentos or 0,
		Dados.ressonancia(if melhor then melhor.chance else nil)
	)
	for _, c in cartoes do
		local u = c.universo
		local aberto = Dados.liberado(inc, u.id)
		local m = (inc.melhor or {})[u.id] or 0
		local v = (inc.concluidas or {})[u.id] or 0
		c.info.Text = string.format(
			"Melhor andar: %d/%d   ·   Vitórias: %d   ·   Guardião: %s",
			m,
			Dados.ANDARES,
			v,
			u.guardiao
		)
		c.cadeado.Visible = not aberto
		c.botao.placa.quadro.Visible = aberto
		if naFila == u.id then
			c.botao.definirTexto("NA FILA · SAIR")
			c.botao.definirAtivo(true)
		else
			c.botao.definirTexto("ENTRAR NA FILA")
			c.botao.definirAtivo(false)
		end
	end
	for _, l in linhas do
		local r = l.reliquia
		local nivel = Dados.nivel(inc, r.id)
		l.nivel.Text = string.format("%s   ·   nível %d/%d", r.nome, nivel, #r.custos)
		local custo = Dados.custo(inc, r.id)
		l.botao.definirTexto(if custo then string.format("MELHORAR · %d", custo) else "MÁXIMO")
		l.botao.definirAtivo(custo ~= nil and (inc.fragmentos or 0) >= custo)
	end
end

local function montarPainel()
	local painel =
		Navegacao.criarPainel("Incursoes", { titulo = "Incursões", icone = "✦", cor = "roxo" })
	local c = painel.conteudo
	cabecalho = Kit.texto({
		Text = "",
		TextSize = 24,
		TextColor3 = Cores.Ouro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(28, 8),
		Size = UDim2.new(1, -56, 0, 34),
		Parent = c,
	})
	Kit.texto({
		fonte = "media",
		Text = "Grupo de 1 a 4. Purifique os Núcleos, derrote as Sombras e desça 5 andares até o Guardião. "
			.. "Fragmentos compram relíquias (só valem aqui). Sua aura mais rara dá força: nada muda nas chances do giro.",
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(28, 44),
		Size = UDim2.new(1, -56, 0, 44),
		Parent = c,
	})
	-- universos (esquerda)
	for i, u in Dados.UNIVERSOS do
		local cor = Color3.fromHex(u.cor)
		local f = moldura(c, {
			Name = u.id,
			Position = UDim2.fromOffset(28, 98 + (i - 1) * 182),
			Size = UDim2.new(0.6, -40, 0, 170),
		}, cor)
		Kit.texto({
			Text = string.upper(u.nome),
			TextSize = 34,
			TextColor3 = cor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, 10),
			Size = UDim2.new(1, -40, 0, 40),
			Parent = f,
		})
		Kit.texto({
			fonte = "media",
			Text = u.descricao,
			TextSize = 18,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, 52),
			Size = UDim2.new(1, -40, 0, 46),
			Parent = f,
		})
		local info = Kit.texto({
			fonte = "media",
			Text = "",
			TextSize = 16,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, 100),
			Size = UDim2.new(1, -300, 0, 22),
			Parent = f,
		})
		local cadeado = Kit.texto({
			Text = if u.requisito
				then "🔒 Conclua " .. Dados.porId[u.requisito].nome .. " para abrir"
				else "",
			TextSize = 20,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -20, 1, -14),
			Size = UDim2.fromOffset(420, 30),
			Parent = f,
		})
		local botao = Kit.botaoPlaca({
			texto = "ENTRAR NA FILA",
			largura = 250,
			altura = 50,
			tamanhoTexto = 22,
			sombra = Color3.new(0, 0, 0),
			aoClicar = function()
				pedir("IncursaoFila", if naFila == u.id then "" else u.id)
			end,
		})
		botao.placa.quadro.AnchorPoint = Vector2.new(1, 1)
		botao.placa.quadro.Position = UDim2.new(1, -18, 1, -12)
		botao.placa.quadro.Parent = f
		table.insert(cartoes, { botao = botao, info = info, cadeado = cadeado, universo = u })
	end
	-- relíquias (direita)
	local lado = moldura(c, {
		Name = "Reliquias",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 98),
		Size = UDim2.new(0.4, -24, 0, 534),
	}, Cores.Ouro)
	Kit.texto({
		Text = "RELÍQUIAS",
		TextSize = 30,
		TextColor3 = Cores.Ouro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -40, 0, 36),
		Parent = lado,
	})
	for i, r in Dados.RELIQUIAS do
		local y = 56 + (i - 1) * 118
		local nivel = Kit.texto({
			Text = r.nome,
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, y),
			Size = UDim2.new(1, -40, 0, 28),
			Parent = lado,
		})
		Kit.texto({
			fonte = "media",
			Text = r.descricao,
			TextSize = 16,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, y + 28),
			Size = UDim2.new(1, -40, 0, 22),
			Parent = lado,
		})
		local botao = Kit.botaoPlaca({
			texto = "MELHORAR",
			largura = 230,
			altura = 44,
			tamanhoTexto = 19,
			sombra = Color3.new(0, 0, 0),
			aoClicar = function()
				pedir("IncursaoReliquia", r.id)
			end,
		})
		botao.placa.quadro.Position = UDim2.fromOffset(20, y + 54)
		botao.placa.quadro.Parent = lado
		table.insert(linhas, { botao = botao, nivel = nivel, reliquia = r })
	end
	Estado.aoMudar(atualizarPainel)
end

-- ===================================================================== HUD da partida

local hud: Frame
local filaBanner: TextLabel
local titulo: TextLabel
local detalhe: TextLabel
local barraGuardiao: Frame
local barraVida: Frame
local nomeGuardiao: TextLabel
local resultado: Frame
local resultadoTitulo: TextLabel
local resultadoTexto: TextLabel
local botaoPulso: TextButton
local anelPulso: Frame

local function montarHud(raiz: Frame)
	filaBanner = Kit.texto({
		Name = "FilaIncursao",
		Text = "",
		TextSize = 24,
		TextColor3 = Cores.Papel,
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Cores.Tinta,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(640, 44),
		Visible = false,
		Parent = raiz,
	})
	filaBanner.BackgroundTransparency = 0.25
	Kit.novo("UICorner", { CornerRadius = UDim.new(0, 10), Parent = filaBanner })

	hud = Kit.novo("Frame", {
		Name = "HudIncursao",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = raiz,
	})
	local topo = moldura(hud, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(620, 96),
		BackgroundTransparency = 0.15,
	})
	titulo = Kit.texto({
		Text = "",
		TextSize = 30,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 38),
		Parent = topo,
	})
	detalhe = Kit.texto({
		fonte = "media",
		Text = "",
		TextSize = 20,
		TextColor3 = Cores.TextoSuave,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = topo,
	})
	barraGuardiao = moldura(hud, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 124),
		Size = UDim2.fromOffset(720, 46),
		Visible = false,
	}, Cores.Selo)
	barraVida = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Selo,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		Parent = barraGuardiao,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(0, 8), Parent = barraVida })
	nomeGuardiao = Kit.texto({
		Text = "",
		TextSize = 22,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = barraGuardiao,
	})

	-- Pulso (toque/clique) e Sair
	local pulso = Kit.novo("Frame", {
		Name = "Pulso",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -40, 1, -40),
		Size = UDim2.fromOffset(170, 170),
		BackgroundColor3 = Cores.Tinta,
		Parent = hud,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pulso })
	Kit.novo("UIStroke", { Color = Cores.Papel, Thickness = 4, Parent = pulso })
	anelPulso = Kit.novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Cores.Uva,
		BackgroundTransparency = 0.3,
		Parent = pulso,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = anelPulso })
	botaoPulso = Kit.novo("TextButton", {
		Text = "PULSO\n[Q]",
		FontFace = Tema.FonteNegrito,
		TextSize = 30,
		TextColor3 = Cores.Papel,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = pulso,
	})
	botaoPulso.Activated:Connect(pulsar)
	local sairBotao = Kit.botaoPlaca({
		texto = "SAIR",
		largura = 150,
		altura = 46,
		tamanhoTexto = 20,
		sombra = Color3.new(0, 0, 0),
		aoClicar = function()
			pedir("IncursaoSair")
		end,
	})
	sairBotao.placa.quadro.AnchorPoint = Vector2.new(1, 0)
	sairBotao.placa.quadro.Position = UDim2.new(1, -30, 0, 30)
	sairBotao.placa.quadro.Parent = hud

	resultado = moldura(raiz, {
		Name = "ResultadoIncursao",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(620, 260),
		Visible = false,
		ZIndex = 20,
	}, Cores.Ouro)
	resultadoTitulo = Kit.texto({
		Text = "",
		TextSize = 46,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 56),
		ZIndex = 21,
		Parent = resultado,
	})
	resultadoTexto = Kit.texto({
		fonte = "media",
		Text = "",
		TextSize = 24,
		TextWrapped = true,
		Position = UDim2.fromOffset(30, 90),
		Size = UDim2.new(1, -60, 0, 90),
		ZIndex = 21,
		Parent = resultado,
	})
	local ok = Kit.botaoPlaca({
		texto = "OK",
		largura = 160,
		altura = 48,
		tamanhoTexto = 22,
		sombra = Color3.new(0, 0, 0),
		z = 22,
		aoClicar = function()
			resultado.Visible = false
		end,
	})
	ok.placa.quadro.AnchorPoint = Vector2.new(0.5, 1)
	ok.placa.quadro.Position = UDim2.new(0.5, 0, 1, -20)
	ok.placa.quadro.Parent = resultado
end

local function definirPartida(universo: string?)
	local mudou = (emPartida ~= nil) ~= (universo ~= nil)
	emPartida = universo
	hud.Visible = universo ~= nil
	Visual.clima(universo)
	if mudou then
		aoPartida(universo ~= nil)
		if universo then
			Navegacao.fechar()
		end
	end
end

local function aoEvento(d: any)
	if type(d) ~= "table" then
		return
	end
	local u = if type(d.universo) == "string" then Dados.porId[d.universo] else nil
	if d.tipo == "fila" then
		naFila = if u then u.id else nil
		filaBanner.Visible = u ~= nil
		if u then
			filaBanner.Text = string.format(
				"FILA: %s  ·  %d/%d jogador(es)  ·  %s",
				string.upper(u.nome),
				d.jogadores or 1,
				Dados.MAX_JOGADORES,
				if type(d.falta) == "number"
					then "partida em " .. d.falta .. "s"
					else "esperando..."
			)
		end
		atualizarPainel()
	elseif d.tipo == "inicio" and u then
		naFila = nil
		filaBanner.Visible = false
		resultado.Visible = false
		definirPartida(u.id)
		atualizarPainel()
	elseif d.tipo == "andar" and u then
		definirPartida(u.id)
		local nome = if type(d.titulo) == "string" then d.titulo else nil
		aviso(
			if nome
				then "Andar final: " .. nome .. " espera por vocês!"
				else string.format("%s — andar %d", u.nome, d.andar)
		)
	elseif d.tipo == "estado" and u then
		if not emPartida then
			definirPartida(u.id)
		end
		titulo.Text = string.format(
			"%s  ·  ANDAR %d/%d",
			string.upper(u.nome),
			d.andar or 1,
			d.andares or Dados.ANDARES
		)
		titulo.TextColor3 = Color3.fromHex(u.corVeio)
		local partes = {}
		if (d.nucleosTotal or 0) > 0 then
			table.insert(partes, string.format("Núcleos %d/%d", d.nucleos or 0, d.nucleosTotal))
		end
		table.insert(partes, string.format("Sombras %d", d.sombras or 0))
		table.insert(partes, string.format("Vidas do grupo %d", d.vidas or 0))
		if d.fenda then
			table.insert(
				partes,
				if d.avanco then "Descendo em " .. d.avanco .. "s" else "A FENDA ABRIU!"
			)
		end
		detalhe.Text = table.concat(partes, "   ·   ")
		local g = d.guardiao
		barraGuardiao.Visible = type(g) == "table"
		if
			type(g) == "table"
			and type(g.vida) == "number"
			and type(g.vidaMax) == "number"
			and g.vidaMax > 0
		then
			barraVida.Size = UDim2.new(math.clamp(g.vida / g.vidaMax, 0, 1), -12, 1, -12)
			nomeGuardiao.Text =
				string.format("%s   %d/%d", string.upper(tostring(g.nome)), g.vida, g.vidaMax)
		end
	elseif d.tipo == "pulso" and typeof(d.origem) == "Vector3" and type(d.raio) == "number" then
		Visual.pulso(d.origem, d.raio, emPartida)
	elseif d.tipo == "aviso" and type(d.texto) == "string" then
		aviso(d.texto)
	elseif d.tipo == "fim" then
		definirPartida(nil)
		resultado.Visible = true
		local venceu = d.venceu == true
		resultadoTitulo.Text = if venceu
			then "VITÓRIA!"
			else (if d.motivo == "saiu" then "VOCÊ SAIU" else "A INCURSÃO CAIU")
		resultadoTitulo.TextColor3 = if venceu then Cores.Ouro else Cores.Selo
		resultadoTexto.Text = string.format(
			"%s  ·  andares concluídos: %d/%d\n+%d fragmentos",
			if u then u.nome else "",
			d.andares or 0,
			Dados.ANDARES,
			d.fragmentos or 0
		)
	end
end

function IncursoesUI.montar(raiz: Frame, aoAviso: (string) -> (), aoMudarPartida: (boolean) -> ())
	aviso = aoAviso
	aoPartida = aoMudarPartida
	montarPainel()
	montarHud(raiz)
	Visual.iniciar()
	Remotos.evento("Incursao").OnClientEvent:Connect(aoEvento)
	UserInputService.InputBegan:Connect(function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.Q then
			pulsar()
		end
	end)
	game:GetService("RunService").RenderStepped:Connect(function()
		local falta = math.clamp((proximoPulso - os.clock()) / Dados.PULSO_ESPERA, 0, 1)
		anelPulso.Size = UDim2.fromScale(1 - falta, 1 - falta)
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		-- quem caiu sem vidas volta ao Nexo: o servidor avisa com "fim"
	end)
end

function IncursoesUI.abrir()
	Navegacao.abrir("Incursoes")
end

return IncursoesUI
