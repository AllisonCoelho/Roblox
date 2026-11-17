-- HUD da Órbita do Nexo. O centro fica livre para o avatar e para o cenário.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Perfil = require(Shared.Dados.Perfil)
local Transcendencia = require(Shared.Dados.Transcendencia)
local Cores = require(Shared.Tema).Orbita
local Escala = require(script.Parent.Parent.Escala)
local Kit = require(script.Parent.Parent.Kit)

local HUD = {}
local RECENTES = 3

export type EstadoGiro = "perfil" | "pedido" | "recarregando" | "pular" | "pronto"

export type Api = {
	quadro: Frame,
	definirGiro: (fracao: number, falta: number, estado: EstadoGiro) -> (),
	definirVisivel: (visivel: boolean) -> (),
	definirPerfilTeste: (ativo: boolean) -> (),
	atualizar: (estado: Perfil.Estado) -> (),
	registrarResultado: (aura: Auras.Aura, nova: boolean, simulado: boolean, chance: number) -> (),
}

type Opcoes = {
	aoDespertar: () -> (),
	aoAlternarAuto: () -> (),
	aoAbrirIndice: () -> (),
	aoAbrirInventario: () -> (),
	aoAbrirLoja: () -> (),
	aoAbrirAjustes: () -> (),
}

local function corTier(aura: Auras.Aura): Color3
	return Color3.fromHex(Auras.Tiers[aura.tier].cor)
end

function HUD.montar(raiz: Frame, op: Opcoes): Api
	local hud = Kit.novo("Frame", {
		Name = "HUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = raiz,
	})

	local placaGiros = Kit.placa({
		nome = "Giros",
		tamanho = UDim2.fromOffset(216, 52),
		posicao = UDim2.fromOffset(22, 16),
		pai = hud,
	})
	Kit.texto({
		Text = "GIROS",
		TextSize = 14,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0, 56, 1, 0),
		Parent = placaGiros.conteudo,
	})
	local giros = Kit.texto({
		fonte = "mono",
		Text = "0",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(65, 0),
		Size = UDim2.new(1, -77, 1, 0),
		Parent = placaGiros.conteudo,
	})

	local feed = Kit.placa({
		nome = "Recentes",
		tamanho = UDim2.fromOffset(258, 140),
		posicao = UDim2.fromOffset(22, 76),
		pai = hud,
	})
	feed.quadro.Visible = false
	Kit.texto({
		Text = "ÚLTIMOS DESPERTARES",
		TextSize = 14,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 28),
		Parent = feed.conteudo,
	})
	type Linha = { quadro: Frame, nome: TextLabel, chance: TextLabel, marca: TextLabel }
	local linhas: { Linha } = {}
	local recentes: { { aura: Auras.Aura, chance: number } } = {}
	local recentesTeste: { { aura: Auras.Aura, chance: number } } = {}
	local emTeste = false
	for i = 1, RECENTES do
		local quadro = Kit.novo("Frame", {
			Name = "Giro" .. i,
			BackgroundColor3 = Cores.Elevado,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 28 + (i - 1) * 36),
			Size = UDim2.new(1, -16, 0, 32),
			Visible = false,
			Parent = feed.conteudo,
		})
		local marca = Kit.texto({
			Text = "◆",
			TextSize = 12,
			Size = UDim2.new(0, 22, 1, 0),
			Parent = quadro,
		})
		local nome = Kit.texto({
			fonte = "titulo",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -100, 1, 0),
			Parent = quadro,
		})
		local chance = Kit.texto({
			fonte = "mono",
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -74, 0, 0),
			Size = UDim2.new(0, 66, 1, 0),
			Parent = quadro,
		})
		linhas[i] = { quadro = quadro, nome = nome, chance = chance, marca = marca }
	end

	local ajustes = Kit.botaoPlaca({
		texto = "⚙",
		tamanho = UDim2.fromOffset(64, 64),
		tamanhoTexto = 28,
		pai = hud,
		aoClicar = op.aoAbrirAjustes,
	})
	ajustes.rotulo.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	ajustes.placa.quadro.AnchorPoint = Vector2.new(1, 0)
	ajustes.placa.quadro.Position = UDim2.new(1, -22, 0, 16)
	ajustes.botao.Text = "Ajustes"

	local inventario = Kit.botaoPlaca({
		texto = "Inventário",
		tamanho = UDim2.fromOffset(146, 50),
		tamanhoTexto = 18,
		pai = hud,
		aoClicar = op.aoAbrirInventario,
	})
	inventario.placa.quadro.AnchorPoint = Vector2.new(1, 0)

	local loja = Kit.botaoPlaca({
		texto = "✦ Loja",
		tamanho = UDim2.fromOffset(146, 50),
		tamanhoTexto = 18,
		tom = "lilas",
		pai = hud,
		aoClicar = op.aoAbrirLoja,
	})
	loja.placa.quadro.AnchorPoint = Vector2.new(1, 0)
	loja.botao.Text = "Loja"

	local placaAura = Kit.placa({
		nome = "AuraEquipada",
		tamanho = UDim2.fromOffset(292, 96),
		posicao = UDim2.new(1, -22, 0, 88),
		ancora = Vector2.new(1, 0),
		pai = hud,
	})
	local iconeAura, centroAura = Kit.cristal(placaAura.conteudo, 48, Cores.Borda)
	iconeAura.AnchorPoint = Vector2.new(0, 0.5)
	iconeAura.Position = UDim2.new(0, 12, 0.5, 0)
	local tituloAura = Kit.texto({
		Text = "AURA EQUIPADA",
		TextSize = 14,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(70, 8),
		Size = UDim2.new(1, -78, 0, 20),
		Parent = placaAura.conteudo,
	})
	local nomeEquipada = Kit.texto({
		fonte = "titulo",
		Text = "Nenhuma",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Position = UDim2.fromOffset(70, 26),
		Size = UDim2.new(1, -80, 1, -51),
		Parent = placaAura.conteudo,
	})
	local raridade = Kit.texto({
		fonte = "mono",
		Text = "Desperte uma aura",
		TextSize = 14,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Position = UDim2.new(0, 70, 1, -25),
		Size = UDim2.new(1, -80, 0, 20),
		Parent = placaAura.conteudo,
	})

	local barra = Kit.novo("Frame", {
		Name = "Acoes",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(464, 156),
		Parent = hud,
	})
	local auto = Kit.placa({
		nome = "Auto",
		tamanho = UDim2.fromOffset(154, 68),
		ancora = Vector2.new(0, 1),
		posicao = UDim2.fromScale(0, 1),
		pai = barra,
	})
	local indice = Kit.placa({
		nome = "Indice",
		tamanho = UDim2.fromOffset(154, 68),
		ancora = Vector2.new(1, 1),
		posicao = UDim2.fromScale(1, 1),
		pai = barra,
	})

	local function rotulos(placa: Kit.Placa, titulo: string, valor: string): TextLabel
		Kit.texto({
			Text = titulo,
			TextSize = 14,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 7),
			Size = UDim2.new(1, -24, 0, 20),
			Parent = placa.conteudo,
		})
		return Kit.texto({
			fonte = "mono",
			Text = valor,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(12, 27),
			Size = UDim2.new(1, -24, 0, 29),
			Parent = placa.conteudo,
		})
	end

	local valorAuto = rotulos(auto, "AUTO", "Desligado")
	local valorIndice = rotulos(indice, "ÍNDICE", "0 / " .. #Auras.lista)
	local estadoAuto = Kit.texto({
		Text = "○",
		TextColor3 = Cores.TextoSuave,
		TextSize = 16,
		Position = UDim2.new(1, -26, 0, 4),
		Size = UDim2.fromOffset(18, 18),
		Parent = auto.conteudo,
	})
	local trilho = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Elevado,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 1, -9),
		Size = UDim2.new(1, -24, 0, 3),
		Parent = indice.conteudo,
	})
	local progresso = Kit.novo("Frame", {
		BackgroundColor3 = Cores.Lilas,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = trilho,
	})
	local autoBotao = Kit.alvo(auto.quadro, "Giro automático", op.aoAlternarAuto)
	local indiceBotao = Kit.alvo(indice.quadro, "Índice de auras", op.aoAbrirIndice)

	local giro = Kit.novo("Frame", {
		Name = "Despertar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(134, 156),
		Parent = barra,
	})
	local orbita = Kit.novo("Frame", {
		Name = "Orbita",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(126, 126),
		Parent = giro,
	})
	local orbitaEscala = Kit.novo("UIScale", { Parent = orbita })
	local anel = Kit.anel(orbita, 126, Cores.Lilas, Cores.Borda, 1)
	local disco = Kit.circulo({
		BackgroundColor3 = Cores.Fundo,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(118, 118),
		ZIndex = 2,
		Parent = orbita,
	})
	Kit.novo("UIStroke", { Color = Cores.Elevado, Thickness = 1, Parent = disco })
	for i = 0, 7 do
		local graus = 45 * i
		local rad = math.rad(graus)
		Kit.novo("Frame", {
			BackgroundColor3 = if i % 2 == 0 then Cores.Lilas else Cores.Borda,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(63 + 60 * math.sin(rad), 63 - 60 * math.cos(rad)),
			Size = UDim2.fromOffset(2, if i % 2 == 0 then 11 else 6),
			Rotation = graus,
			ZIndex = 3,
			Parent = orbita,
		})
	end

	local cristal, centro = Kit.cristal(disco, 66, Cores.Lilas)
	cristal.AnchorPoint = Vector2.new(0.5, 0.5)
	cristal.Position = UDim2.fromScale(0.5, 0.48)
	local carga = Kit.texto({
		fonte = "mono",
		TextSize = 18,
		TextColor3 = Cores.Menta,
		Position = UDim2.new(0, 0, 1, -36),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = disco,
	})
	local etiqueta = Kit.placa({
		tamanho = UDim2.new(1, 0, 0, 40),
		fundo = Cores.Elevado,
		borda = Cores.Lilas,
		ancora = Vector2.new(0, 1),
		posicao = UDim2.fromScale(0, 1),
		z = 3,
		pai = giro,
	})
	local rotuloGiro = Kit.texto({
		fonte = "titulo",
		Text = "DESPERTAR",
		TextSize = 26,
		TextWrapped = true,
		Position = UDim2.fromOffset(5, 0),
		Size = UDim2.new(1, -10, 1, 0),
		Parent = etiqueta.conteudo,
	})
	local tecla = Kit.placa({
		nome = "Atalho",
		tamanho = UDim2.fromOffset(28, 28),
		posicao = UDim2.new(1, 4, 0, 55),
		corte = 5,
		z = 4,
		pai = giro,
	})
	Kit.texto({
		fonte = "mono",
		Text = "E",
		TextSize = 16,
		Size = UDim2.fromScale(1, 1),
		Parent = tecla.conteudo,
	})
	local giroBotao = Kit.alvo(giro, "Despertar", op.aoDespertar)
	giroBotao.NextSelectionLeft = autoBotao
	giroBotao.NextSelectionRight = indiceBotao
	autoBotao.NextSelectionRight = giroBotao
	indiceBotao.NextSelectionLeft = giroBotao
	indiceBotao.NextSelectionUp = ajustes.botao
	ajustes.botao.NextSelectionDown = indiceBotao

	local resultado = Kit.placa({
		nome = "Resultado",
		tamanho = UDim2.fromOffset(446, 52),
		ancora = Vector2.new(0.5, 1),
		posicao = UDim2.new(0.5, 0, 0, -18),
		pai = barra,
	})
	resultado.quadro.Visible = false
	local textoResultado = Kit.texto({
		fonte = "titulo",
		TextSize = 21,
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Parent = resultado.conteudo,
	})
	local resultadoToken = 0
	local resultadoSimulado = false
	local estadoGiro: EstadoGiro? = nil
	local tempoMostrado = ""

	local function atualizarFeed()
		local lista = if emTeste then recentesTeste else recentes
		feed.quadro.Visible = not Escala.compacto and #lista > 0
		feed.quadro.Size = UDim2.fromOffset(258, 32 + 36 * #lista)
		for i, linha in linhas do
			local giro = lista[i]
			linha.quadro.Visible = giro ~= nil
			if giro then
				linha.nome.Text = giro.aura.nome
				linha.chance.Text = "1/" .. Formato.chanceCurta(giro.chance)
				linha.marca.TextColor3 = corTier(giro.aura)
			end
		end
	end

	local function ajustarRotuloGiro()
		local tamanho = if Escala.compacto then 22 else 26
		local aguardando = estadoGiro == "perfil" or estadoGiro == "pedido"
		rotuloGiro.TextSize = if aguardando then tamanho - 5 else tamanho
		etiqueta.quadro.Size = UDim2.new(1, 0, 0, if aguardando then 48 else 40)
	end

	Escala.aoMudar(function()
		local compacto = Escala.compacto
		local estreito = Escala.tamanho.X < 600
		local largura = math.min(if compacto then 390 else 464, Escala.tamanho.X - 28)
		local larguraGiro = if compacto then 106 else 134
		local lateral = math.floor((largura - larguraGiro) / 2 - 9)
		local altura = if compacto then 118 else 156
		local ladoDireito = math.clamp((Escala.tamanho.X - largura) * 0.5 - 160, 0, 112)
		local deslocamento = if Escala.toque then ladoDireito else 0
		local margem = if Escala.toque and ladoDireito == 0 then 126 else 22
		barra.Size = UDim2.fromOffset(largura, altura)
		barra.Position = UDim2.new(0.5, deslocamento, 1, -margem)
		giro.Size = UDim2.fromOffset(larguraGiro, altura)
		orbitaEscala.Scale = if compacto then 86 / 126 else 1
		auto.quadro.Size = UDim2.fromOffset(lateral, 68)
		indice.quadro.Size = UDim2.fromOffset(lateral, 68)
		ajustes.placa.quadro.Position = UDim2.new(1, -14, 0, 10)
		local larguraAura = if estreito then 202 elseif compacto then 230 else 292
		placaAura.quadro.Size = UDim2.fromOffset(larguraAura, if compacto then 112 else 96)
		placaAura.quadro.Position = UDim2.new(1, -14, 0, 84)
		inventario.placa.quadro.Position = UDim2.new(1, -14, 0, if compacto then 202 else 186)
		loja.placa.quadro.Position = UDim2.new(1, -14, 0, if compacto then 258 else 242)
		local textoX = if estreito then 46 else 70
		iconeAura.Size = UDim2.fromOffset(if estreito then 30 else 48, if estreito then 30 else 48)
		iconeAura.Position = UDim2.new(0, 10, 0.5, 0)
		tituloAura.Position = UDim2.fromOffset(textoX, 8)
		tituloAura.Size = UDim2.new(1, -textoX - 8, 0, 20)
		nomeEquipada.Position = UDim2.fromOffset(textoX, 26)
		nomeEquipada.Size = UDim2.new(1, -textoX - 8, 1, if compacto then -70 else -51)
		nomeEquipada.TextSize = if compacto then 20 else 24
		raridade.Position = UDim2.new(0, textoX, 1, if compacto then -41 else -24)
		raridade.Size = UDim2.new(1, -textoX - 8, 0, if compacto then 37 else 20)
		placaGiros.quadro.Size = UDim2.fromOffset(if compacto then 158 else 216, 52)
		placaGiros.quadro.Position = UDim2.fromOffset(if compacto then 14 else 22, 16)
		giros.TextSize = if compacto then 18 else 22
		ajustarRotuloGiro()
		tecla.quadro.Position = UDim2.new(1, 4, 0, if compacto then 18 else 55)
		tecla.quadro.Visible = Escala.teclado and (estadoGiro == "pronto" or estadoGiro == "pular")
		resultado.quadro.Size = UDim2.fromOffset(math.min(largura, 446), 52)
		atualizarFeed()
	end)

	return {
		quadro = hud,
		definirGiro = function(fracao: number, falta: number, estado: EstadoGiro)
			local carregando = estado == "recarregando"
			local disponivel = estado == "pronto" or estado == "pular"
			anel.definir(
				fracao,
				if carregando then Cores.Menta elseif disponivel then Cores.Lilas else Cores.Borda
			)
			local tempo = if carregando
				then string.format("%.1f s", math.ceil(falta * 10) / 10)
				else ""
			if tempo ~= tempoMostrado then
				tempoMostrado = tempo
				carga.Text = tempo:gsub("%.", ",")
			end
			if estadoGiro == estado then
				return
			end
			estadoGiro = estado
			ajustarRotuloGiro()
			local titulo = if estado == "perfil"
				then "Aguardando perfil"
				elseif estado == "pedido" then "Despertando…"
				elseif estado == "pular" then "Pular ritual"
				else "DESPERTAR"
			rotuloGiro.Text = titulo
			giroBotao.Text = titulo
			giroBotao.Interactable = disponivel
			tecla.quadro.Visible = Escala.teclado and disponivel
			centro.BackgroundColor3 = if disponivel or carregando then Cores.Lilas else Cores.Borda
			etiqueta.definirCor(Cores.Elevado, if disponivel then Cores.Lilas else Cores.Borda)
		end,
		definirVisivel = function(visivel: boolean)
			hud.Visible = visivel
		end,
		definirPerfilTeste = function(ativo: boolean)
			emTeste = ativo
			if not ativo then
				table.clear(recentesTeste)
				if resultadoSimulado then
					resultadoToken += 1
					resultado.quadro.Visible = false
				end
			end
			atualizarFeed()
		end,
		atualizar = function(estado: Perfil.Estado)
			giros.Text = if estado.giros < 1000000
				then Formato.inteiro(estado.giros)
				else Formato.curto(estado.giros)
			local aura = if estado.equipada then Auras.porId[estado.equipada] else nil
			nomeEquipada.Text = if aura then aura.nome else "Nenhuma"
			local cor = if aura then corTier(aura) else Cores.Borda
			centroAura.BackgroundColor3 = cor
			raridade.Text = if aura
				then string.format(
					"%s · 1 em %s",
					Auras.Tiers[aura.tier].nome,
					Formato.chance(
						Auras.chanceEfetiva(aura, Transcendencia.sorte(estado.transcendencia.nivel))
					)
				)
				else "Desperte uma aura"
			raridade.TextColor3 = if aura then Kit.corLegivel(cor) else Cores.TextoSuave

			local ligado = estado.configuracoes.giroAutomatico == true
			valorAuto.Text = if ligado then "Ligado" else "Desligado"
			valorAuto.TextColor3 = if ligado then Cores.Menta else Cores.Texto
			estadoAuto.Text = if ligado then "●" else "○"
			estadoAuto.TextColor3 = if ligado then Cores.Menta else Cores.TextoSuave
			auto.definirCor(
				if ligado then Cores.Ativo else Cores.Painel,
				if ligado then Cores.Menta else Cores.Borda
			)
			autoBotao.Text = "Giro automático · " .. valorAuto.Text
			local descobertas = Auras.contarDescobertas(estado.auras)
			valorIndice.Text = string.format("%d / %d", descobertas, #Auras.lista)
			progresso.Size = UDim2.fromScale(descobertas / #Auras.lista, 1)
		end,
		registrarResultado = function(
			aura: Auras.Aura,
			nova: boolean,
			simulado: boolean,
			chance: number
		)
			local lista = if simulado then recentesTeste else recentes
			table.insert(lista, 1, { aura = aura, chance = chance })
			if #lista > RECENTES then
				table.remove(lista)
			end
			atualizarFeed()
			resultadoSimulado = simulado
			resultadoToken += 1
			local meu = resultadoToken
			textoResultado.Text = string.format(
				"%s%s%s · 1 em %s",
				if simulado then "Teste · " else "",
				if nova then "Nova · " else "",
				aura.nome,
				Formato.chance(chance)
			)
			resultado.definirCor(Cores.Painel, corTier(aura))
			resultado.quadro.Visible = true
			task.delay(1.45, function()
				if resultadoToken == meu then
					resultado.quadro.Visible = false
				end
			end)
		end,
	}
end

return HUD
