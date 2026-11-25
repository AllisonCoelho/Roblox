-- Tela do duelo da Arena no combate REATIVO (regras em Shared/Dados/Duelo; servidor em
-- Arena/Motor). Vale contra o Primeiro Soberano e no 1x1 (Trono e Rankeada).
--
--   * Na sua vez: menu de ações com o custo em PA (Ataque, Corte, Selo, Despertar, Concentrar).
--   * No seu golpe: um anel dourado fecha sobre o círculo em cada marca; toque (clique, Espaço ou
--     A) quando ele encostar: PERFEITO, BOM ou ERROU.
--   * No golpe do oponente: o anel de cada acerto fecha no círculo (vermelho = golpe absoluto, só
--     esquivar). ESQUIVAR (Q / B) tem janela maior; APARAR (Espaço / E / R1) é mais justo, dá
--     +1 PA e, aparando todos os acertos, solta o contra-ataque.
--   * Cartões com Vida, PA e Ruptura dos dois; avisos de Rompido, Selo, Concentração e Baluarte.
-- O cliente só pede e manda os toques com o horário do servidor; o resultado vem do servidor.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Duelo = require(Shared.Dados.Duelo)
local Remotos = require(Shared.Remotos)
local Cores = require(Shared.Tema).Orbita
local Escala = require(script.Parent.Parent.Escala)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Cena = require(script.Parent.Parent.Parent.Mundo.Arena)

local Tela = {}

local RUBRO = Color3.fromHex("FF735D")
local OURO = Color3.fromHex("FFC83D")
local CIANO = Color3.fromHex("7DF9FF")
local LARANJA = Color3.fromHex("FF9A3D")
local SAIDAS = { vitoria = "Vitória", derrota = "Derrota", tempo = "Tempo esgotado" }
local CIRCULO = 90 -- diâmetro do círculo onde o anel fecha

local function quadro(pai: Instance, nome: string): Frame
	return Kit.novo("Frame", {
		Name = nome,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = pai,
	}) :: Frame
end

local function etiqueta(pai: Instance, fonte: string, tamanho: number, y: number): TextLabel
	return Kit.texto({
		fonte = fonte,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, tamanho + 3),
		TextSize = tamanho,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = pai,
	})
end

local function barra(pai: Instance, cor: Color3, y: number, altura: number): Frame
	local pista = Kit.novo("Frame", {
		Size = UDim2.new(1, -24, 0, altura),
		Position = UDim2.fromOffset(12, y),
		BackgroundColor3 = Cores.Fundo,
		BorderSizePixel = 0,
		Parent = pai,
	})
	return Kit.novo("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = cor,
		BorderSizePixel = 0,
		Parent = pista,
	}) :: Frame
end

-- Cartão de um lutador: nome, Vida, PA (losangos), Ruptura e situação
type Cartao = {
	quadro: Frame,
	nome: TextLabel,
	atualizar: (vida: number, pa: number?, ruptura: number, situacao: string) -> (),
}
local function cartao(pai: Frame, cor: Color3): Cartao
	local placa = Kit.placa({ tamanho = UDim2.new(), pai = pai })
	local nome = etiqueta(placa.conteudo, "titulo", 22, 4)
	local pv = etiqueta(placa.conteudo, "mono", 15, 30)
	local vida = barra(placa.conteudo, cor, 50, 8)
	local pips = {}
	for i = 1, Duelo.PA_MAX do
		table.insert(
			pips,
			Kit.novo("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45,
				Position = UDim2.fromOffset(18 + (i - 1) * 17, 72),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = Cores.Fundo,
				BorderSizePixel = 0,
				Parent = placa.conteudo,
			})
		)
	end
	local paTexto = Kit.texto({
		fonte = "mono",
		TextSize = 13,
		TextColor3 = OURO,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18 + Duelo.PA_MAX * 17, 64),
		Size = UDim2.fromOffset(60, 16),
		Parent = placa.conteudo,
	})
	Kit.texto({
		Text = "RUPTURA",
		TextSize = 11,
		TextColor3 = LARANJA,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 82),
		Size = UDim2.fromOffset(70, 12),
		Parent = placa.conteudo,
	})
	local ruptura = barra(placa.conteudo, LARANJA, 96, 5)
	local situacao = Kit.texto({
		RichText = true,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 80),
		Size = UDim2.new(1, -90, 0, 14),
		Parent = placa.conteudo,
	})
	return {
		quadro = placa.quadro,
		nome = nome,
		atualizar = function(v: number, pa: number?, rup: number, sit: string)
			pv.Text = string.format("PV  %d / %d", v, Duelo.VIDA)
			TweenService:Create(
				vida,
				TweenInfo.new(0.25),
				{ Size = UDim2.fromScale(math.clamp(v / Duelo.VIDA, 0, 1), 1) }
			):Play()
			TweenService:Create(ruptura, TweenInfo.new(0.25), {
				Size = UDim2.fromScale(math.clamp(rup / Duelo.RUPTURA_MAX, 0, 1), 1),
			}):Play()
			for i, p in pips do
				p.Visible = pa ~= nil
				p.BackgroundColor3 = if pa and i <= pa then OURO else Cores.Fundo
			end
			paTexto.Text = if pa then string.format("%d PA", pa) else ""
			situacao.Text = sit
		end,
	}
end

local function situacaoDe(v: { [string]: any }, eu: boolean): string
	local partes = {}
	if v.rompido then
		table.insert(partes, '<font color="#FF9A3D"><b>ROMPIDO</b></font>')
	end
	if eu then
		if v.selado then
			table.insert(partes, '<font color="#C0ADFF">Selo</font>')
		end
		if v.foco then
			table.insert(partes, '<font color="#7DF9FF">Concentrado</font>')
		end
	elseif v.baluarte then
		table.insert(partes, '<font color="#FF735D">Baluarte</font>')
	end
	return table.concat(partes, " · ")
end

type Anel = { inicio: number, alvo: number, quadro: Frame, traco: UIStroke }

function Tela.montar(raiz: Frame, aoAviso: (string) -> (), aoMudar: (boolean) -> ())
	local camada = quadro(raiz, "Arena")
	camada.Visible = false
	local eu = cartao(camada, Cores.Menta)
	local oponente = cartao(camada, RUBRO)
	local centro = Kit.placa({ tamanho = UDim2.new(), pai = camada })
	local vezTexto = etiqueta(centro.conteudo, "titulo", 20, 4)
	vezTexto.TextXAlignment = Enum.TextXAlignment.Center
	local cronometro = etiqueta(centro.conteudo, "mono", 15, 28)
	cronometro.TextXAlignment = Enum.TextXAlignment.Center

	local aviso = Kit.placa({ tamanho = UDim2.new(), pai = camada })
	local titulo = etiqueta(aviso.conteudo, "titulo", 24, 6)
	local detalhe = etiqueta(aviso.conteudo, "corpo", 17, 36)
	detalhe.RichText = true
	detalhe.Size = UDim2.new(1, -24, 1, -42)
	detalhe.TextTruncate = Enum.TextTruncate.None
	detalhe.TextWrapped = true
	detalhe.TextYAlignment = Enum.TextYAlignment.Top

	local comandos = quadro(camada, "Comandos")
	local defesa = quadro(camada, "Defesa")
	local campo = quadro(camada, "Tempo")
	local retorno = Kit.texto({
		fonte = "titulo",
		TextSize = 44,
		TextStrokeTransparency = 1,
		TextTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromOffset(640, 60),
		ZIndex = 20,
		Parent = camada,
	})
	local alvoCirculo = Kit.novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(CIRCULO, CIRCULO),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.75,
		Visible = false,
		Parent = campo,
	}) :: Frame
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = alvoCirculo })
	local traco = Kit.novo("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = 4,
		Transparency = 0.15,
		Parent = alvoCirculo,
	}) :: UIStroke

	local id = 0
	local pvp = false
	local nomeOponente = "Primeiro Soberano"
	local estado: { [string]: any } = Duelo.visao(Duelo.novo(), "a")
	local fase = "" -- "entrada", "escolha", "espera", "golpe", "fim"
	local prazo = 0
	local pendente = false
	local aura: string? = nil
	local cena: Cena.Controle? = nil
	local aneis: { Anel } = {}
	local golpeMeu = false

	local function atualizarCartoes()
		eu.atualizar(estado.vida, estado.pa, estado.ruptura, situacaoDe(estado, true))
		local o = estado.oponente or {}
		oponente.atualizar(
			o.vida or 0,
			if pvp then o.pa else nil,
			o.ruptura or 0,
			situacaoDe(o, false)
		)
		vezTexto.Text = "Vez " .. tostring(estado.vez or 1)
	end

	local function mostrarRetorno(texto: string, cor: Color3)
		retorno.Text = texto
		retorno.TextColor3 = cor
		retorno.TextTransparency = 0
		retorno.TextStrokeTransparency = 0.3
		retorno.Size = UDim2.fromOffset(700, 72)
		TweenService:Create(retorno, TweenInfo.new(0.14, Enum.EasingStyle.Back), {
			Size = UDim2.fromOffset(640, 60),
		}):Play()
		TweenService:Create(
			retorno,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		):Play()
	end

	-- toque no anel (no seu golpe) ou defesa (no golpe do oponente)
	local function tocar(tipo: string)
		if not camada.Visible or fase ~= "golpe" then
			return
		end
		if (tipo == "qte") ~= golpeMeu then
			return
		end
		Remotos.evento("DueloEntrada"):FireServer(id, tipo, Workspace:GetServerTimeNow())
		traco.Color = if tipo == "aparar"
			then CIANO
			elseif tipo == "qte" then OURO
			else Color3.new(1, 1, 1)
		traco.Thickness = 8
	end

	-- ===================================================== botões de ação
	type BotaoAcao = { item: Kit.BotaoPlaca, detalhe: TextLabel, acao: string }
	local botoes: { BotaoAcao } = {}
	local escolher: (string) -> ()
	for _, acaoId in Duelo.MENU do
		local item = Kit.botaoPlaca({
			texto = "",
			tamanho = UDim2.new(),
			tamanhoTexto = 19,
			pai = comandos,
			aoClicar = function()
				escolher(acaoId)
			end,
		})
		item.rotulo.Position = UDim2.fromOffset(5, 3)
		item.rotulo.Size = UDim2.new(1, -10, 0, 24)
		item.rotulo.TextWrapped = false
		item.rotulo.TextTruncate = Enum.TextTruncate.AtEnd
		local linha = etiqueta(item.placa.conteudo, "corpo", 13, 28)
		linha.TextXAlignment = Enum.TextXAlignment.Center
		linha.TextWrapped = true
		linha.TextTruncate = Enum.TextTruncate.None
		linha.Size = UDim2.new(1, -12, 1, -30)
		linha.Position = UDim2.fromOffset(6, 27)
		table.insert(botoes, { item = item, detalhe = linha, acao = acaoId })
	end

	local function atualizarBotoes()
		for i, b in botoes do
			local acao = Duelo.ACOES[b.acao]
			local ativo = fase == "escolha" and not pendente and (estado.pa or 0) >= acao.custo
			local nome = if b.acao == "despertar" and aura
				then "Despertar · " .. aura
				else acao.nome
			b.item.rotulo.Text = string.format("%s  [%d]", nome, i)
			b.item.botao.Text = nome
			b.detalhe.Text = (if acao.custo > 0 then string.format("%d PA · ", acao.custo) else "")
				.. acao.descricao
			local destaque = ativo and (b.acao == "ataque" or b.acao == "despertar")
			b.item.definirTom(if destaque then "lilas" else "neutro")
			if not ativo then
				b.item.rotulo.TextColor3 = Cores.TextoSuave
			end
			b.detalhe.TextColor3 = if destaque then Cores.Fundo else Cores.TextoSuave
			b.item.botao.Interactable = ativo
			b.item.botao.Selectable = ativo
		end
		if fase == "escolha" and not pendente and Escala.controle then
			local sel = GuiService.SelectedObject
			if sel == nil or not sel:IsDescendantOf(comandos) then
				GuiService.SelectedObject = botoes[1].item.botao
			end
		end
	end

	escolher = function(acaoId: string)
		if fase ~= "escolha" or pendente then
			return
		end
		local acao = Duelo.ACOES[acaoId]
		if (estado.pa or 0) < acao.custo then
			aoAviso(string.format("Faltam %d PA.", acao.custo - (estado.pa or 0)))
			return
		end
		pendente = true
		atualizarBotoes()
		local pedidoId, pedidoVez = id, estado.vez
		task.spawn(function()
			local ok, msg =
				Estado.pedir(if pvp then "PvPAgir" else "ArenaAgir", pedidoId, pedidoVez, acaoId)
			if not ok and id == pedidoId and fase == "escolha" then
				pendente = false
				atualizarBotoes()
				if msg then
					aoAviso(msg)
				end
			end
		end)
	end

	-- ===================================================== botões de defesa
	local function botaoDefesa(
		texto: string,
		sub: string,
		tom: Kit.Tom,
		tipo: string
	): Kit.BotaoPlaca
		local b = Kit.botaoPlaca({
			texto = texto,
			tamanho = UDim2.new(),
			tamanhoTexto = 24,
			tom = tom,
			pai = defesa,
			aoClicar = function()
				tocar(tipo)
			end,
		})
		b.rotulo.Position = UDim2.fromOffset(6, 6)
		b.rotulo.Size = UDim2.new(1, -12, 0, 30)
		local l = etiqueta(b.placa.conteudo, "corpo", 13, 40)
		l.Text = sub
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextColor3 = if tom == "lilas" then Cores.Fundo else Cores.TextoSuave
		return b
	end
	local esquivar = botaoDefesa("ESQUIVAR", "Q · janela maior", "neutro", "esquivar")
	local aparar = botaoDefesa("APARAR", "Espaço · +1 PA · contra-ataque", "lilas", "aparar")
	-- no seu golpe, a tela inteira (fora dos cartões) vira o botão do toque
	local golpearAlvo = Kit.novo("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
		Parent = campo,
	}) :: TextButton
	golpearAlvo.Activated:Connect(function()
		tocar("qte")
	end)

	local sair = Kit.botaoPlaca({
		texto = "Sair",
		tamanho = UDim2.fromOffset(86, 42),
		tamanhoTexto = 18,
		pai = camada,
		aoClicar = function()
			local pedido = id
			task.spawn(function()
				local ok, msg = Estado.pedir(if pvp then "PvPSair" else "ArenaSair", pedido)
				if not ok and camada.Visible and id == pedido and msg then
					aoAviso(msg)
				end
			end)
		end,
	})

	local function alinhar()
		local w, h = Escala.tamanho.X, Escala.tamanho.Y
		local estreito = w < h * 1.25
		local margem = if w < 700 then 8 else 16
		local larguraCard = if estreito then (w - 3 * margem) / 2 else math.min(360, w * 0.32)
		eu.quadro.Position = UDim2.fromOffset(margem, margem)
		eu.quadro.Size = UDim2.fromOffset(larguraCard, 106)
		oponente.quadro.AnchorPoint = Vector2.new(1, 0)
		oponente.quadro.Position = UDim2.new(1, -margem, 0, margem)
		oponente.quadro.Size = UDim2.fromOffset(larguraCard, 106)
		sair.placa.quadro.AnchorPoint = Vector2.new(1, 0)
		sair.placa.quadro.Position = UDim2.new(1, -margem, 0, margem + 112)
		centro.quadro.AnchorPoint = Vector2.new(0.5, 0)
		centro.quadro.Position = UDim2.new(0.5, 0, 0, if estreito then margem + 112 else margem)
		centro.quadro.Size = UDim2.fromOffset(140, 50)
		local cmdLargura = if estreito then w - 2 * margem else math.min(640, w * 0.56)
		local cmdAltura = 138
		comandos.AnchorPoint = Vector2.new(1, 1)
		comandos.Position = UDim2.new(1, -margem, 1, -margem)
		comandos.Size = UDim2.fromOffset(cmdLargura, cmdAltura)
		for i, b in botoes do
			local linha = if i <= 3 then 0 else 1
			local col = if i <= 3 then i - 1 else i - 4
			local porLinha = if linha == 0 then 3 else 2
			b.item.placa.quadro.Position = UDim2.new(
				col / porLinha,
				if col > 0 then 4 else 0,
				linha * 0.5,
				if linha == 1 then 4 else 0
			)
			b.item.placa.quadro.Size = UDim2.new(1 / porLinha, -4, 0.5, -4)
		end
		local defLargura = math.min(480, w - 2 * margem)
		defesa.AnchorPoint = Vector2.new(1, 1)
		defesa.Position = UDim2.new(1, -margem, 1, -margem)
		defesa.Size = UDim2.fromOffset(defLargura, 78)
		esquivar.placa.quadro.Position = UDim2.fromScale(0, 0)
		esquivar.placa.quadro.Size = UDim2.new(0.42, -4, 1, 0)
		aparar.placa.quadro.Position = UDim2.new(0.42, 4, 0, 0)
		aparar.placa.quadro.Size = UDim2.new(0.58, -4, 1, 0)
		local ocupado = if comandos.Visible then cmdAltura elseif defesa.Visible then 78 else 0
		aviso.quadro.AnchorPoint = Vector2.new(0, 1)
		aviso.quadro.Position =
			UDim2.new(0, margem, 1, -margem - (if estreito and ocupado > 0 then ocupado + 6 else 0))
		aviso.quadro.Size = UDim2.fromOffset(
			if estreito
				then w - 2 * margem
				else math.min(500, w - math.max(cmdLargura, defLargura) - 3 * margem),
			100
		)
	end

	-- ===================================================== anéis de tempo
	local function novoAnel(alvo: number, cor: Color3, absoluto: boolean)
		local f = Kit.novo("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(CIRCULO * 3, CIRCULO * 3),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = campo,
		}) :: Frame
		Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
		local s =
			Kit.novo("UIStroke", { Color = cor, Thickness = 5, Transparency = 1, Parent = f }) :: UIStroke
		if absoluto then
			Kit.texto({
				fonte = "titulo",
				Text = "!",
				TextSize = 40,
				TextColor3 = RUBRO,
				Size = UDim2.fromScale(1, 1),
				Parent = f,
			})
		end
		table.insert(aneis, { inicio = alvo - 0.7, alvo = alvo, quadro = f, traco = s })
	end

	local function limparAneis()
		for _, a in aneis do
			a.quadro:Destroy()
		end
		table.clear(aneis)
		alvoCirculo.Visible = false
		golpearAlvo.Visible = false
	end

	local function mostrarPainel(qual: string)
		comandos.Visible = qual == "comandos"
		defesa.Visible = qual == "defesa"
		alinhar()
	end

	local function fechar()
		if not camada.Visible then
			return
		end
		fase = ""
		limparAneis()
		if cena then
			cena.encerrar()
			cena = nil
		end
		local sel = GuiService.SelectedObject
		if sel and sel:IsDescendantOf(camada) then
			GuiService.SelectedObject = nil
		end
		camada.Visible = false
		aoMudar(false)
	end

	Players.LocalPlayer.CharacterRemoving:Connect(fechar)
	Escala.aoMudar(alinhar)

	-- teclado e controle
	UserInputService.InputBegan:Connect(function(input, processado)
		if not camada.Visible then
			return
		end
		local k = input.KeyCode
		if fase == "golpe" then
			if golpeMeu then
				if k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.E then
					tocar("qte")
				end
			elseif
				k == Enum.KeyCode.Space
				or k == Enum.KeyCode.E
				or k == Enum.KeyCode.ButtonR1
				or k == Enum.KeyCode.ButtonA
			then
				tocar("aparar")
			elseif
				k == Enum.KeyCode.Q
				or k == Enum.KeyCode.ButtonB
				or k == Enum.KeyCode.ButtonL1
			then
				tocar("esquivar")
			end
			return
		end
		if processado or fase ~= "escolha" then
			return
		end
		local indice = k.Value - Enum.KeyCode.One.Value + 1
		if indice >= 1 and indice <= #Duelo.MENU then
			escolher(Duelo.MENU[indice])
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not camada.Visible then
			return
		end
		local agora = Workspace:GetServerTimeNow()
		cronometro.Text = if (fase == "escolha" or fase == "espera") and prazo > agora
			then tostring(math.ceil(prazo - agora)) .. " s"
			else ""
		-- cada anel fecha do triplo até o círculo no instante do acerto
		for i = #aneis, 1, -1 do
			local a = aneis[i]
			if agora > a.alvo + 0.22 then
				a.quadro:Destroy()
				table.remove(aneis, i)
			else
				local t = (agora - a.inicio) / (a.alvo - a.inicio)
				local escala = 1 + 2 * math.clamp(1 - t, 0, 1)
				a.quadro.Size = UDim2.fromOffset(CIRCULO * escala, CIRCULO * escala)
				a.traco.Transparency = if t < 0 then 1 else math.clamp(0.6 - t * 0.6, 0, 0.6)
			end
		end
		traco.Color = traco.Color:Lerp(Color3.new(1, 1, 1), math.min(1, dt * 6))
		traco.Thickness += (4 - traco.Thickness) * math.min(1, dt * 8)
	end)

	-- ===================================================== eventos do servidor
	Remotos.evento("Arena").OnClientEvent:Connect(function(pacote)
		if pacote.tipo == "abrir" and pacote.id > id then
			fechar()
			id = pacote.id
			pvp = pacote.pvp == true
			nomeOponente = pacote.oponente or "Primeiro Soberano"
			aura = pacote.aura
			estado = pacote.estado
			fase = "entrada"
			pendente = false
			eu.nome.Text = pacote.nome or Players.LocalPlayer.DisplayName
			oponente.nome.Text = nomeOponente
			titulo.Text = pacote.titulo or "Duelo"
			detalhe.Text = if pvp
				then string.format(
					"Você contra <b>%s</b>. O dano segue a Pontuação de Aura.",
					nomeOponente
				)
				else "O Soberano aceita o desafio. Na vez dele, <b>Esquive</b> ou <b>Apare</b> cada golpe!"
			sair.rotulo.Text, sair.botao.Text = "Sair", "Sair"
			mostrarPainel("nenhum")
			aoMudar(true)
			local perfil = Estado.atual
			local prefs = if perfil then perfil.configuracoes else {}
			cena = Cena.iniciar({
				movimentoReduzido = prefs.movimentoReduzido == true,
				qualidadeBaixa = prefs.qualidadeBaixa == true,
				cor = if pacote.cor then Color3.fromHex(pacote.cor) else Cores.Lilas,
				estilo = pacote.estilo,
				lado = pacote.lado,
				pve = not pvp,
			})
			camada.Visible = true
			atualizarCartoes()
			atualizarBotoes()
			alinhar()
			return
		elseif pacote.id ~= id or not camada.Visible then
			return
		end
		if type(pacote.estado) == "table" then
			estado = pacote.estado
			atualizarCartoes()
		end
		local tipo = pacote.tipo
		if tipo == "turno" then
			fase = "escolha"
			prazo = pacote.prazo or 0
			pendente = false
			limparAneis()
			titulo.Text = "Sua vez"
			local dicas = {}
			if not pvp then
				local proxima = Duelo.ACOES[Duelo.intencao((estado.vezesB or 0) + 1)]
				if proxima then
					table.insert(
						dicas,
						string.format(
							"O Soberano prepara <b>%s</b> (%s).",
							proxima.nome,
							proxima.descricao
						)
					)
				end
			end
			if estado.oponente and estado.oponente.rompido then
				table.insert(dicas, '<font color="#FF9A3D">Oponente Rompido: +50% de dano!</font>')
			end
			table.insert(dicas, "Ataque dá +1 PA.")
			detalhe.Text = table.concat(dicas, " ")
			mostrarPainel("comandos")
			atualizarBotoes()
		elseif tipo == "espera" then
			fase = "espera"
			prazo = pacote.prazo or 0
			limparAneis()
			titulo.Text = if pvp then "Vez de " .. tostring(pacote.quem) else "Vez do Soberano"
			detalhe.Text =
				"Prepare-se: <b>Esquive</b> (Q) ou <b>Apare</b> (Espaço) quando o anel fechar no círculo."
			mostrarPainel("defesa")
		elseif tipo == "golpe" then
			fase = "golpe"
			golpeMeu = pacote.eu == true
			limparAneis()
			titulo.Text = if pacote.acao == "despertar"
					and golpeMeu
					and aura
				then "Despertar · " .. aura
				else tostring(pacote.nome)
			local acertos = pacote.acertos or {}
			if golpeMeu then
				detalhe.Text = "Toque quando o anel dourado encostar no círculo!"
				mostrarPainel("nenhum")
				golpearAlvo.Visible = (pacote.marcas and #pacote.marcas > 0) == true
				for _, m in pacote.marcas or {} do
					if acertos[m] then
						novoAnel(acertos[m], OURO, false)
					end
				end
			else
				local n = #acertos
				detalhe.Text = if pacote.absoluto
					then string.format(
						'<font color="#FF735D"><b>Golpe absoluto</b></font> (%d golpe%s): só dá para <b>Esquivar</b>!',
						n,
						if n > 1 then "s" else ""
					)
					else string.format(
						"%d golpe%s: Esquive ou Apare cada um. Apare todos para contra-atacar!",
						n,
						if n > 1 then "s" else ""
					)
				mostrarPainel(if n > 0 then "defesa" else "nenhum")
				for _, t in acertos do
					novoAnel(t, if pacote.absoluto then RUBRO else CIANO, pacote.absoluto == true)
				end
			end
			alvoCirculo.Visible = #aneis > 0
			if cena then
				cena.golpe(pacote.acao, golpeMeu, acertos)
			end
		elseif tipo == "acerto" then
			local meu = pacote.meu == true
			local acao = Duelo.ACOES[pacote.acao]
			if meu then
				if pacote.defesa == "aparado" then
					mostrarRetorno("APARADO", CIANO)
				elseif pacote.defesa == "esquivado" then
					mostrarRetorno("ESQUIVOU", Cores.TextoSuave)
				elseif acao and acao.marcas and table.find(acao.marcas, pacote.indice) then
					local nota = pacote.nota
					mostrarRetorno(
						if nota == "perfeito"
							then "PERFEITO! −" .. pacote.dano
							elseif nota == "bom" then "BOM −" .. pacote.dano
							else "ERROU −" .. pacote.dano,
						if nota == "perfeito"
							then OURO
							elseif nota == "bom" then Cores.Menta
							else Cores.TextoSuave
					)
				end
			elseif pacote.defesa == "aparado" then
				mostrarRetorno("APARADO! +1 PA", CIANO)
			elseif pacote.defesa == "esquivado" then
				mostrarRetorno("ESQUIVOU!", Color3.new(1, 1, 1))
			elseif (pacote.dano or 0) > 0 then
				mostrarRetorno("−" .. pacote.dano, RUBRO)
			end
			if pacote.rompeu then
				task.delay(0.55, function()
					mostrarRetorno(
						if meu then "RUPTURA! Oponente Rompido" else "Você foi Rompido!",
						LARANJA
					)
				end)
			end
			if cena then
				cena.acerto(pacote.acao, meu, pacote.dano or 0, pacote.defesa)
			end
		elseif tipo == "contra" then
			mostrarRetorno(if pacote.meu then "CONTRA-ATAQUE!" else "Contra-ataque!", CIANO)
			titulo.Text = "Contra-ataque"
			detalhe.Text = if pacote.meu
				then "Você aparou todos os golpes!"
				else nomeOponente .. " aparou todos os seus golpes."
		elseif tipo == "perdeuVez" then
			mostrarRetorno(tostring(pacote.quem) .. " está Rompido e perde a vez!", LARANJA)
		elseif tipo == "fim" then
			fase = "fim"
			limparAneis()
			mostrarPainel("nenhum")
			titulo.Text = SAIDAS[pacote.resultado] or "Fim"
			local base = if pacote.resultado == "vitoria"
				then (if pacote.motivo == "desistencia"
					then nomeOponente .. " deixou o duelo."
					else "Você venceu " .. nomeOponente .. ".")
				elseif pacote.resultado == "derrota" then nomeOponente .. " venceu o duelo."
				else "O duelo terminou por inatividade."
			detalhe.Text = base .. (if pacote.detalhe then " " .. pacote.detalhe else "")
			sair.rotulo.Text, sair.botao.Text = "Voltar", "Voltar"
		elseif tipo == "fechar" then
			fechar()
		end
	end)
end

return Tela
