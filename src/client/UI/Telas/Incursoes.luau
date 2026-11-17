-- Interface das Incursões: o painel da Mesa dos Cartógrafos (universos, fila e relíquias) e,
-- durante a partida, o HUD (andar, Núcleos, vidas, Guardião), o botão PULSO (tecla Q) e o
-- resultado. O cliente só pede; o servidor (src/server/Incursoes) decide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Itens = require(ReplicatedStorage.Shared.Dados.Itens)
local Dados = require(Shared.Dados.Incursoes)
local Remotos = require(Shared.Remotos)
local Tema = require(Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)
local Escala = require(script.Parent.Parent.Escala)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Estado = require(script.Parent.Parent.Estado)
local Visual = require(
	script.Parent.Parent.Parent
		:WaitForChild("Mundo")
		:WaitForChild("Incursoes")
		:WaitForChild("Visual")
)

local Cores = Tema.Orbita
local IncursoesUI = {}

local aviso: (string) -> () = function() end
local aoPartida: (boolean) -> () = function() end
local naFila: string? = nil
local emPartida: string? = nil
local proximoPulso = 0

local function moldura(pai: Instance, props: { [string]: any }, cor: Color3?): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Cores.Painel
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
			c.botao.rotulo.Text = "Na fila · sair"
			c.botao.definirTom("menta")
		else
			c.botao.rotulo.Text = if Players.LocalPlayer:GetAttribute("PerfilDeTeste") == true
				then "Testar sozinho"
				else "Entrar na fila"
			c.botao.definirTom("neutro")
		end
		c.botao.botao.Text = c.botao.rotulo.Text
	end
	for _, l in linhas do
		local r = l.reliquia
		local nivel = Dados.nivel(inc, r.id)
		l.nivel.Text = string.format("%s   ·   nível %d/%d", r.nome, nivel, #r.custos)
		local custo = Dados.custo(inc, r.id)
		l.botao.rotulo.Text = if custo then string.format("Melhorar · %d", custo) else "Máximo"
		l.botao.botao.Text = l.botao.rotulo.Text
		l.botao.definirTom(if custo and (inc.fragmentos or 0) >= custo then "lilas" else "neutro")
	end
end

local function textoCartao(
	pai: Instance,
	texto: string,
	tamanho: number,
	y: number,
	altura: number,
	cor: Color3?,
	fonte: string?
): TextLabel
	return Kit.texto({
		fonte = fonte,
		Text = texto,
		TextSize = tamanho,
		TextColor3 = cor or Cores.Texto,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, altura),
		Parent = pai,
	})
end

local function coluna(pai: Instance, nome: string): Frame
	local quadro = Kit.novo("Frame", {
		Name = nome,
		BackgroundTransparency = 1,
		Parent = pai,
	})
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = quadro,
	})
	return quadro
end

local function acaoCartao(pai: Instance, texto: string, aoClicar: () -> ()): Kit.BotaoPlaca
	local botao = Kit.botaoPlaca({
		texto = texto,
		tamanho = UDim2.new(1, -24, 0, 64),
		tamanhoTexto = 21,
		pai = pai,
		aoClicar = aoClicar,
	})
	botao.placa.quadro.AnchorPoint = Vector2.new(0, 1)
	botao.placa.quadro.Position = UDim2.new(0, 12, 1, -10)
	return botao
end

local function montarPainel()
	local painel = Navegacao.criarPainel("Incursoes", { titulo = "Incursões", icone = "✦" })
	local c = painel.conteudo
	cabecalho = textoCartao(c, "", 20, 4, 54, Cores.Menta, "mono")
	local rolagem = Kit.rolagem(c)
	rolagem.Position = UDim2.fromOffset(12, 62)
	rolagem.Size = UDim2.new(1, -24, 1, -70)

	local listaUniversos = coluna(rolagem, "Universos")
	local listaReliquias = coluna(rolagem, "Reliquias")
	local alturaUniverso = 222
	local alturaReliquia = 160
	for i, u in Dados.UNIVERSOS do
		local cor = Color3.fromHex(u.cor)
		local cartao = Kit.placa({
			nome = u.id,
			tamanho = UDim2.new(1, 0, 0, alturaUniverso),
			borda = cor,
			pai = listaUniversos,
			ordem = i,
		}).conteudo
		textoCartao(cartao, u.nome, 28, 5, 40, Kit.corLegivel(cor), "titulo")
		textoCartao(cartao, u.descricao, 17, 45, 49, Cores.TextoSuave)
		local info = textoCartao(cartao, "", 16, 94, 46, Cores.TextoSuave)
		local cadeado = textoCartao(
			cartao,
			if u.requisito then "Conclua " .. Dados.porId[u.requisito].nome .. " para abrir" else "",
			17,
			150,
			58,
			Cores.TextoSuave
		)
		local botao = acaoCartao(cartao, "Entrar na fila", function()
			pedir("IncursaoFila", if naFila == u.id then "" else u.id)
		end)
		table.insert(cartoes, { botao = botao, info = info, cadeado = cadeado, universo = u })
	end

	Kit.texto({
		fonte = "titulo",
		Text = "Relíquias",
		TextSize = 28,
		TextColor3 = Cores.Lilas,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = 0,
		Parent = listaReliquias,
	})
	for i, r in Dados.RELIQUIAS do
		local cartao = Kit.placa({
			nome = r.id,
			tamanho = UDim2.new(1, 0, 0, alturaReliquia),
			pai = listaReliquias,
			ordem = i,
		}).conteudo
		local nivel = textoCartao(cartao, r.nome, 21, 6, 34, Cores.Texto, "titulo")
		textoCartao(cartao, r.descricao, 16, 39, 42, Cores.TextoSuave)
		local botao = acaoCartao(cartao, "Melhorar", function()
			pedir("IncursaoReliquia", r.id)
		end)
		table.insert(linhas, { botao = botao, nivel = nivel, reliquia = r })
	end

	Escala.aoMudar(function()
		local compacto = Escala.tamanho.X < 780
		local hUniversos = #Dados.UNIVERSOS * (alturaUniverso + 10) - 10
		local hReliquias = #Dados.RELIQUIAS * (alturaReliquia + 10) + 38
		listaUniversos.Size = UDim2.new(if compacto then 1 else 0.56, -12, 0, hUniversos)
		listaReliquias.Size = UDim2.new(if compacto then 1 else 0.44, -12, 0, hReliquias)
		listaReliquias.Position = if compacto
			then UDim2.fromOffset(0, hUniversos + 12)
			else UDim2.new(0.56, 0, 0, 0)
	end)
	Estado.aoMudar(atualizarPainel)
	atualizarPainel()
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
local anelPulso: Frame

local function montarHud(raiz: Frame)
	filaBanner = Kit.texto({
		Name = "FilaIncursao",
		Text = "",
		TextSize = 24,
		TextColor3 = Cores.Texto,
		BackgroundTransparency = 0.25,
		BackgroundColor3 = Cores.Painel,
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
		fonte = "titulo",
		Text = "",
		TextSize = 30,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 38),
		Parent = topo,
	})
	detalhe = Kit.texto({
		Text = "",
		TextSize = 20,
		TextWrapped = true,
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
	}, Cores.Aviso)
	barraVida = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Aviso,
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
		BackgroundColor3 = Cores.Painel,
		Parent = hud,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pulso })
	Kit.novo("UIStroke", { Color = Cores.Texto, Thickness = 4, Parent = pulso })
	anelPulso = Kit.novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Cores.Lilas,
		BackgroundTransparency = 0.3,
		Parent = pulso,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = anelPulso })
	local textoPulso = Kit.texto({
		fonte = "titulo",
		Text = "PULSO",
		TextSize = 30,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = pulso,
	})
	Kit.alvo(pulso, "Pulso", pulsar)
	local sairBotao = Kit.botaoPlaca({
		texto = "SAIR",
		tamanho = UDim2.fromOffset(114, 64),
		tamanhoTexto = 20,
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
	}, Cores.Menta)
	resultadoTitulo = Kit.texto({
		fonte = "titulo",
		Text = "",
		TextSize = 46,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 56),
		ZIndex = 21,
		Parent = resultado,
	})
	resultadoTexto = Kit.texto({
		Text = "",
		TextSize = 24,
		TextWrapped = true,
		Position = UDim2.fromOffset(20, 72),
		Size = UDim2.new(1, -40, 0, 138),
		ZIndex = 21,
		Parent = resultado,
	})
	local ok = Kit.botaoPlaca({
		texto = "OK",
		tamanho = UDim2.fromOffset(160, 64),
		tamanhoTexto = 22,
		aoClicar = function()
			resultado.Visible = false
		end,
	})
	ok.placa.quadro.AnchorPoint = Vector2.new(0.5, 1)
	ok.placa.quadro.Position = UDim2.new(0.5, 0, 1, -20)
	ok.placa.quadro.Parent = resultado
	Escala.aoMudar(function()
		local compacto = Escala.compacto
		local largura = Escala.tamanho.X
		local borda = largura - 28
		filaBanner.Size = UDim2.fromOffset(math.min(640, borda), 44)
		filaBanner.TextSize = if compacto then 17 else 24
		filaBanner.Position = UDim2.new(0.5, 0, 0, if largura < 880 then 205 else 120)
		topo.Size = UDim2.fromOffset(math.min(620, borda), 96)
		titulo.TextSize = if compacto then 23 else 30
		detalhe.TextSize = if compacto then 16 else 20
		barraGuardiao.Size = UDim2.fromOffset(math.min(720, borda), 46)
		nomeGuardiao.TextSize = if compacto then 16 else 22
		local tamanhoPulso = if compacto then 110 else 150
		pulso.Size = UDim2.fromOffset(tamanhoPulso, tamanhoPulso)
		pulso.Position =
			UDim2.new(1, if Escala.toque then -132 else -24, 1, if Escala.toque then -62 else -24)
		textoPulso.Text = if Escala.teclado then "PULSO [Q]" else "PULSO"
		textoPulso.TextSize = if compacto then 22 else 26
		local ySair = if largura < 980 then 182 else 24
		sairBotao.placa.quadro.Position = UDim2.new(1, -14, 0, ySair)
		resultado.Size = UDim2.fromOffset(math.min(620, borda), 292)
		resultadoTexto.TextSize = if compacto then 15 else 20
		resultadoTitulo.TextSize = if compacto then 32 else 46
	end)
end

local function definirPartida(universo: string?)
	local mudou = (emPartida ~= nil) ~= (universo ~= nil)
	if emPartida ~= universo then
		Visual.clima(universo)
	end
	emPartida = universo
	hud.Visible = universo ~= nil
	if mudou then
		aoPartida(universo ~= nil)
		if universo then
			Navegacao.fechar()
		end
	end
end

local function textoItens(ganhos: any): string
	local nomes = {}
	if type(ganhos) == "table" then
		for id, qtd in ganhos do
			local item = Itens.porId[id]
			if item and type(qtd) == "number" and qtd > 0 then
				local tier = Itens.Tiers[item.raridade]
				table.insert(nomes, string.format("%s +%d %s", tier.icone, qtd, item.nome))
			end
		end
	end
	table.sort(nomes)
	return table.concat(nomes, "  ·  ")
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
		Visual.definirPartida(if type(d.slot) == "number" then d.slot else nil)
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
	elseif d.tipo == "loot" then
		local itens = textoItens(d.itens)
		if itens ~= "" then
			aviso(itens)
		end
	elseif d.tipo == "fim" then
		definirPartida(nil)
		Visual.definirPartida(nil)
		resultado.Visible = true
		local venceu = d.venceu == true
		resultadoTitulo.Text = if venceu
			then "VITÓRIA!"
			else (if d.motivo == "saiu" then "VOCÊ SAIU" else "A INCURSÃO CAIU")
		resultadoTitulo.TextColor3 = if venceu then Cores.Menta else Cores.Aviso
		resultadoTexto.Text = string.format(
			"%s  ·  andares concluídos: %d/%d\n+%d Fragmentos de Incursão\n%s",
			if u then u.nome else "",
			d.andares or 0,
			Dados.ANDARES,
			d.fragmentos or 0,
			textoItens(d.itens)
		)
	end
end

function IncursoesUI.montar(raiz: Frame, aoAviso: (string) -> (), aoMudarPartida: (boolean) -> ())
	aviso = aoAviso
	aoPartida = aoMudarPartida
	montarPainel()
	montarHud(raiz)
	Remotos.evento("Incursao").OnClientEvent:Connect(aoEvento)
	task.spawn(Visual.iniciar)
	UserInputService.InputBegan:Connect(function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.Q then
			pulsar()
		end
	end)
	game:GetService("RunService").RenderStepped:Connect(function()
		local falta = math.clamp((proximoPulso - os.clock()) / Dados.PULSO_ESPERA, 0, 1)
		anelPulso.Size = UDim2.fromScale(1 - falta, 1 - falta)
	end)
end

function IncursoesUI.abrir()
	Navegacao.abrir("Incursoes")
end

return IncursoesUI
