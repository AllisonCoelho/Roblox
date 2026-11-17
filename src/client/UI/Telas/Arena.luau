local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Arena = require(Shared.Dados.Arena)
local Remotos = require(Shared.Remotos)
local Cores = require(Shared.Tema).Orbita
local Escala = require(script.Parent.Parent.Escala)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Cena = require(script.Parent.Parent.Parent.Mundo.Arena)

local Tela = {}
local RUBRO = Color3.fromHex("FF735D")
local NORMAL = { "ataque", "tecnicas", "guarda", "despertar" }
local TECNICAS = { "corte", "selo", "voltar" }
local SAIDAS = {
	vitoria = { "Vitória", "Você derrotou o Primeiro Soberano." },
	derrota = { "Derrota", "O Primeiro Soberano venceu o duelo." },
	tempo = { "Tempo esgotado", "O duelo terminou por inatividade." },
}

local function quadro(pai: Instance, nome: string): Frame
	return Kit.novo("Frame", {
		Name = nome,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = pai,
	})
end

local function etiqueta(pai: Instance, fonte: string, tamanho: number, ordem: number): TextLabel
	return Kit.texto({
		fonte = fonte,
		Position = UDim2.fromOffset(12, ordem),
		Size = UDim2.new(1, -24, 0, tamanho + 3),
		TextSize = tamanho,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = pai,
	})
end

local function barra(pai: Instance, cor: Color3, y: number): Frame
	local pista = Kit.novo("Frame", {
		Size = UDim2.new(1, -24, 0, 7),
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
	})
end

local function cartao(pai: Frame, titulo: string, cor: Color3, comEnergia: boolean)
	local placa = Kit.placa({ tamanho = UDim2.new(), pai = pai })
	local nome = etiqueta(placa.conteudo, "titulo", 24, 5)
	nome.Text = titulo
	local pv = etiqueta(placa.conteudo, "mono", 17, 32)
	local vida = barra(placa.conteudo, cor, 54)
	local energia = if comEnergia then etiqueta(placa.conteudo, "mono", 16, 65) else nil
	local carga = if comEnergia then barra(placa.conteudo, Cores.Lilas, 87) else nil
	return {
		quadro = placa.quadro,
		nome = nome,
		atualizar = function(atual: number, acumulada: number)
			pv.Text = string.format("PV  %d / %d", atual, Arena.VIDA)
			vida.Size = UDim2.fromScale(atual / Arena.VIDA, 1)
			if energia and carga then
				energia.Text = string.format("Energia  %d%%", acumulada)
				carga.Size = UDim2.fromScale(acumulada / Arena.CARGA, 1)
			end
		end,
	}
end

type Botao = {
	item: Kit.BotaoPlaca,
	detalhe: TextLabel,
}

function Tela.montar(raiz: Frame, aoAviso: (string) -> (), aoMudar: (boolean) -> ())
	local camada = quadro(raiz, "Arena")
	camada.Visible = false
	local jogador = cartao(camada, "Desafiante", Cores.Menta, true)
	local soberano = cartao(camada, "Primeiro Soberano", RUBRO, false)
	local centro = Kit.placa({ tamanho = UDim2.new(), pai = camada })
	local rodada = etiqueta(centro.conteudo, "titulo", 22, 4)
	rodada.TextXAlignment = Enum.TextXAlignment.Center
	local cronometro = etiqueta(centro.conteudo, "mono", 16, 29)
	cronometro.TextXAlignment = Enum.TextXAlignment.Center

	local aviso = Kit.placa({ tamanho = UDim2.new(), pai = camada })
	local titulo = etiqueta(aviso.conteudo, "titulo", 26, 6)
	local detalhe = etiqueta(aviso.conteudo, "corpo", 19, 37)
	detalhe.Size = UDim2.new(1, -24, 1, -43)
	detalhe.TextTruncate = Enum.TextTruncate.None
	detalhe.TextWrapped = true
	detalhe.TextYAlignment = Enum.TextYAlignment.Top
	local comandos = quadro(camada, "Comandos")
	local impacto = Kit.placa({ tamanho = UDim2.new(), pai = camada })
	local golpeTexto = etiqueta(impacto.conteudo, "titulo", 27, 4)
	golpeTexto.TextXAlignment = Enum.TextXAlignment.Center
	local dano = etiqueta(impacto.conteudo, "mono", 20, 37)
	dano.TextXAlignment = Enum.TextXAlignment.Center

	local id = 0
	local estado = Arena.novo()
	local prazo = 0
	local fase = ""
	local pendente = false
	local menuTecnicas = false
	local aura: string? = nil
	local cena: Cena.Controle? = nil
	local token = 0
	local botoes: { Botao } = {}
	local clicar: (number) -> ()

	local sair = Kit.botaoPlaca({
		texto = "Sair",
		tamanho = UDim2.fromOffset(86, 46),
		tamanhoTexto = 20,
		pai = camada,
		aoClicar = function()
			local pedido = id
			task.spawn(function()
				local ok, msg = Estado.pedir("ArenaSair", pedido)
				if not ok and camada.Visible and id == pedido and msg then
					aoAviso(msg)
				end
			end)
		end,
	})

	for i = 1, 4 do
		local item = Kit.botaoPlaca({
			texto = "",
			tamanho = UDim2.new(),
			tamanhoTexto = 23,
			pai = comandos,
			aoClicar = function()
				clicar(i)
			end,
		})
		item.rotulo.Position = UDim2.fromOffset(5, 3)
		item.rotulo.Size = UDim2.new(1, -10, 0, 27)
		item.rotulo.TextTruncate = Enum.TextTruncate.AtEnd
		item.rotulo.TextWrapped = false
		local linha = etiqueta(item.placa.conteudo, "corpo", 16, 31)
		linha.TextXAlignment = Enum.TextXAlignment.Center
		linha.TextWrapped = true
		linha.TextTruncate = Enum.TextTruncate.None
		linha.Size = UDim2.new(1, -14, 1, -33)
		linha.Position = UDim2.fromOffset(7, 29)
		table.insert(botoes, { item = item, detalhe = linha })
	end

	local function atualizarEstado()
		jogador.atualizar(estado.vida, estado.energia)
		soberano.atualizar(estado.soberano, 0)
		rodada.Text = "Rodada " .. estado.rodada
	end

	local function atualizarBotoes()
		local opcoes = if menuTecnicas then TECNICAS else NORMAL
		for i, botao in botoes do
			local acao = opcoes[i]
			local dados = acao and Arena.Acoes[acao]
			local item = botao.item
			item.placa.quadro.Visible = acao ~= nil
			local bloqueio = if dados and acao then Arena.validar(estado, acao) else nil
			local nome, sub = "", ""
			if acao == "tecnicas" then
				nome, sub = "Técnicas", "Escolher golpe"
			elseif acao == "voltar" then
				nome = "Voltar"
			elseif dados and acao then
				nome = dados.nome
				if acao == "despertar" then
					sub = if bloqueio then "Requer 100% de energia" else aura or "Energia completa"
				elseif acao == "ataque" then
					sub = "+25% de energia"
				elseif acao == "guarda" then
					sub = "Reduz o dano recebido"
				elseif bloqueio then
					local espera = Arena.restante(estado, acao)
					sub = string.format(
						"Recarga · %d %s",
						espera,
						if espera == 1 then "rodada" else "rodadas"
					)
				else
					sub = dados.descricao or ""
				end
			end
			item.botao.Text = nome
			item.rotulo.Text = nome
			botao.detalhe.Text = sub
			local ativo = acao ~= nil and fase == "escolha" and not pendente and bloqueio == nil
			local emFoco = ativo and (acao == "ataque" or acao == "despertar")
			item.definirTom(if emFoco then "lilas" else "neutro")
			if not ativo then
				item.rotulo.TextColor3 = Cores.TextoSuave
			end
			botao.detalhe.TextColor3 = if emFoco then Cores.Fundo else Cores.TextoSuave
			item.botao.Interactable = ativo
			item.botao.Selectable = ativo
		end
		local escolhido = GuiService.SelectedObject
		local semFoco = escolhido == nil
			or (escolhido:IsA("GuiButton") and not escolhido.Selectable)
		if fase == "escolha" and not pendente and Escala.controle and semFoco then
			for _, botao in botoes do
				if botao.item.botao.Selectable then
					GuiService.SelectedObject = botao.item.botao
					break
				end
			end
		end
	end

	local function alinhar()
		local w = Escala.tamanho.X
		local estreito = w < Escala.tamanho.Y * 1.25
		local margem = if w < 700 then 8 else 18
		local larguraCard = if estreito then (w - 3 * margem) / 2 else math.min(345, w * 0.34)
		jogador.quadro.Position = UDim2.fromOffset(margem, margem)
		jogador.quadro.Size = UDim2.fromOffset(larguraCard, 100)
		soberano.quadro.AnchorPoint = Vector2.new(1, 0)
		soberano.quadro.Position = UDim2.new(1, -margem, 0, margem)
		soberano.quadro.Size = UDim2.fromOffset(larguraCard, 68)
		sair.placa.quadro.AnchorPoint = Vector2.new(1, 0)
		sair.placa.quadro.Position = UDim2.new(1, -margem, 0, margem + 74)
		centro.quadro.AnchorPoint = Vector2.new(0.5, 0)
		centro.quadro.Position = UDim2.new(0.5, 0, 0, if estreito then margem + 106 else margem)
		centro.quadro.Size = UDim2.fromOffset(if estreito then 150 else math.min(160, w * 0.23), 55)
		local cmdLargura = if estreito then w - 2 * margem else math.min(610, w * 0.55)
		local cmdAltura = 151
		comandos.AnchorPoint = Vector2.new(1, 1)
		comandos.Position = UDim2.new(1, -margem, 1, -margem)
		comandos.Size = UDim2.fromOffset(cmdLargura, cmdAltura)
		for i, botao in botoes do
			local molde = botao.item.placa.quadro
			molde.Position = UDim2.new(
				(i - 1) % 2 * 0.5,
				if i % 2 == 0 then 4 else 0,
				math.floor((i - 1) / 2) * 0.5,
				0
			)
			molde.Size = UDim2.new(0.5, -4, 0.5, -4)
		end
		aviso.quadro.AnchorPoint = Vector2.new(0, 1)
		aviso.quadro.Position = UDim2.new(
			0,
			margem,
			1,
			-margem - (if estreito and comandos.Visible then cmdAltura + 4 else 0)
		)
		aviso.quadro.Size = UDim2.fromOffset(
			if estreito then w - 2 * margem else math.min(510, w - cmdLargura - 3 * margem),
			104
		)
		impacto.quadro.AnchorPoint = Vector2.new(0.5, 1)
		impacto.quadro.Position = UDim2.new(0.5, 0, 1, -margem)
		impacto.quadro.Size = UDim2.fromOffset(math.min(410, w - 2 * margem), 65)
	end

	clicar = function(indice)
		local acao = (if menuTecnicas then TECNICAS else NORMAL)[indice]
		if not acao or fase ~= "escolha" or pendente then
			return
		end
		if acao == "tecnicas" or acao == "voltar" then
			menuTecnicas = acao == "tecnicas"
			atualizarBotoes()
			return
		end
		if Arena.validar(estado, acao) then
			return
		end
		local pedidoId, pedidoRodada = id, estado.rodada
		pendente = true
		atualizarBotoes()
		task.spawn(function()
			local ok, msg = Estado.pedir("ArenaAgir", pedidoId, pedidoRodada, acao)
			if
				not ok
				and camada.Visible
				and id == pedidoId
				and estado.rodada == pedidoRodada
				and fase == "escolha"
			then
				pendente = false
				atualizarBotoes()
				if msg then
					aoAviso(msg)
				end
			end
		end)
	end

	local function fechar()
		if not camada.Visible then
			return
		end
		token += 1
		fase = ""
		prazo = 0
		if cena then
			cena.encerrar()
			cena = nil
		end
		local selecao = GuiService.SelectedObject
		if selecao and selecao:IsDescendantOf(camada) then
			GuiService.SelectedObject = nil
		end
		camada.Visible = false
		aoMudar(false)
	end

	Players.LocalPlayer.CharacterRemoving:Connect(fechar)
	Escala.aoMudar(alinhar)
	UserInputService.InputBegan:Connect(function(input, processado)
		if not camada.Visible or processado then
			return
		end
		local indice = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		if indice >= 1 and indice <= 4 then
			clicar(indice)
		end
	end)
	RunService.Heartbeat:Connect(function()
		if fase == "escolha" then
			cronometro.Text = tostring(math.max(0, math.ceil(prazo - workspace:GetServerTimeNow())))
				.. " s"
		end
	end)

	Remotos.evento("Arena").OnClientEvent:Connect(function(pacote)
		if pacote.tipo == "abrir" and pacote.id > id then
			fechar()
			id = pacote.id
			estado = pacote.estado
			aura = pacote.aura
			fase = "entrada"
			sair.rotulo.Text = "Sair"
			sair.botao.Text = "Sair"
			jogador.nome.Text = pacote.nome
			prazo = 0
			cronometro.Text = ""
			titulo.Text = "Duelo pelo Trono"
			detalhe.Text = "O Soberano aceita o desafio."
			comandos.Visible = false
			aviso.quadro.Visible = true
			impacto.quadro.Visible = false
			aoMudar(true)
			local perfil = Estado.atual
			local prefs = if perfil then perfil.configuracoes else {}
			cena = Cena.iniciar({
				movimentoReduzido = prefs.movimentoReduzido == true,
				qualidadeBaixa = prefs.qualidadeBaixa == true,
				cor = if pacote.cor then Color3.fromHex(pacote.cor) else Cores.Lilas,
				estilo = pacote.estilo,
			})
			camada.Visible = true
			atualizarEstado()
			alinhar()
		elseif pacote.id ~= id or not camada.Visible then
			return
		elseif pacote.tipo == "turno" then
			token += 1
			estado = pacote.estado
			prazo = pacote.prazo
			fase = "escolha"
			pendente = false
			menuTecnicas = false
			titulo.Text = "Seu turno"
			detalhe.Text = Arena.intencao(estado.rodada).aviso
			if estado.selado then
				detalhe.Text ..= " Selo ativo."
			end
			comandos.Visible = true
			aviso.quadro.Visible = true
			impacto.quadro.Visible = false
			atualizarEstado()
			atualizarBotoes()
			alinhar()
		elseif pacote.tipo == "golpe" then
			token += 1
			local meuToken = token
			local golpe: Arena.Golpe = pacote.golpe
			fase = "resolvendo"
			comandos.Visible = false
			aviso.quadro.Visible = false
			impacto.quadro.Visible = true
			cronometro.Text = ""
			golpeTexto.Text = if golpe.id == "despertar" and aura
				then "Despertar · " .. aura
				else golpe.nome
			dano.Text = ""
			dano.TextColor3 = if golpe.ator == "jogador" then Cores.Lilas else RUBRO
			if cena then
				cena.tocar(golpe, pacote.impacto, pacote.fim)
			end
			task.delay(math.max(0, pacote.impacto - workspace:GetServerTimeNow()), function()
				if meuToken == token then
					estado = golpe.estado
					atualizarEstado()
					dano.Text = if golpe.dano > 0 then "−" .. golpe.dano .. " PV" else "Guarda"
				end
			end)
		elseif pacote.tipo == "fim" then
			token += 1
			fase = "fim"
			estado = pacote.estado
			comandos.Visible = false
			aviso.quadro.Visible = true
			impacto.quadro.Visible = false
			cronometro.Text = ""
			local resultado = SAIDAS[pacote.resultado]
			titulo.Text, detalhe.Text = resultado[1], resultado[2]
			sair.rotulo.Text = "Voltar"
			sair.botao.Text = "Voltar"
			atualizarEstado()
			alinhar()
		elseif pacote.tipo == "fechar" then
			fechar()
		end
	end)
end

return Tela
