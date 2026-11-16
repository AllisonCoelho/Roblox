-- HUD "Tinta e Selo": placas de giros e aura equipada, selo DESPERTAR com anel de carga,
-- AUTO e ÍNDICE inclinados e o feed "Últimos despertares".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Perfil = require(Shared.Dados.Perfil)
local Tema = require(Shared.Tema)
local Escala = require(script.Parent.Parent.Escala)
local Kit = require(script.Parent.Parent.Kit)

local Cores = Tema.Cores
local HUD = {}

local RECENTES = 4

export type Opcoes = {
	aoDespertar: () -> (),
	aoAlternarAuto: () -> (),
	aoAbrirIndice: () -> (),
	aoAlternarAnuncios: () -> (),
}

export type Api = {
	definirCarga: (fracao: number) -> (),
	definirVisivel: (visivel: boolean) -> (),
	atualizar: (estado: Perfil.Estado) -> (),
	registrarResultado: (aura: Auras.Aura) -> (),
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

	-- Placa de giros (papel com sombra vermelha)
	local placaGiros = Kit.placa({
		largura = 300,
		altura = 66,
		fundo = Cores.Papel,
		sombra = Cores.Selo,
		posicao = UDim2.fromOffset(-16, 28),
		pai = hud,
	})
	Kit.novo("UIPadding", { PaddingLeft = UDim.new(0, 44), Parent = placaGiros.conteudo })
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = placaGiros.conteudo,
	})
	Kit.texto({
		fonte = "media",
		Text = "GIROS",
		TextSize = 18,
		TextColor3 = Cores.Tinta,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		LayoutOrder = 1,
		Parent = placaGiros.conteudo,
	})
	local giros = Kit.texto({
		Text = "0",
		TextSize = 44,
		TextColor3 = Cores.Tinta,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 50),
		LayoutOrder = 2,
		Parent = placaGiros.conteudo,
	})

	-- Placa da aura equipada (tinta, com faixa na cor da raridade)
	local placaAura = Kit.placa({
		largura = 380,
		altura = 106,
		fundo = Cores.Tinta,
		borda = Cores.Borda,
		espessura = 2,
		posicao = UDim2.fromOffset(-16, 106),
		pai = hud,
	})
	local faixaTier = Kit.placa({
		largura = 44,
		altura = 106,
		fundo = Cores.Borda,
		posicao = UDim2.fromOffset(-16, 106),
		z = 6,
		pai = hud,
	})
	Kit.texto({
		fonte = "media",
		Text = "AURA EQUIPADA",
		TextSize = 15,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(52, 8),
		Size = UDim2.new(1, -60, 0, 20),
		Parent = placaAura.conteudo,
	})
	local nomeEquipada = Kit.texto({
		Text = "Nenhuma",
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(48, 28),
		Size = UDim2.new(1, -60, 0, 40),
		Parent = placaAura.conteudo,
	})
	local raridade = Kit.texto({
		fonte = "pincel",
		Text = "Clique em DESPERTAR",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(44, 70),
		Size = UDim2.new(1, -60, 0, 26),
		Parent = placaAura.conteudo,
	})

	-- Sino dos anúncios
	local sino = Kit.circulo({
		Name = "Anuncios",
		BackgroundColor3 = Cores.TintaClara,
		Position = UDim2.fromOffset(24, 230),
		Size = UDim2.fromOffset(52, 52),
		Parent = hud,
	})
	local sinoContorno = Kit.novo("UIStroke", { Color = Cores.Borda, Thickness = 2, Parent = sino })
	local sinoTexto = Kit.texto({
		Text = "🔔",
		TextSize = 26,
		Size = UDim2.fromScale(1, 1),
		Parent = sino,
	})
	sinoTexto.FontFace = Font.fromEnum(Enum.Font.SourceSans)
	local sinoBotao = Kit.novo("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = sino,
	})
	sinoBotao.Activated:Connect(op.aoAlternarAnuncios)

	-- Feed "Últimos despertares" (direita)
	local feed = Kit.novo("Frame", {
		Name = "Recentes",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 240),
		Size = UDim2.fromOffset(230, 200),
		Parent = hud,
	})
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = feed,
	})
	Kit.texto({
		fonte = "media",
		Text = "ÚLTIMOS DESPERTARES",
		TextSize = 14,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
		Parent = feed,
	})
	type Linha = { quadro: Frame, nome: TextLabel, chance: TextLabel, faixa: Frame }
	local linhas: { Linha } = {}
	for i = 1, RECENTES do
		local quadro = Kit.novo("Frame", {
			Name = "Linha" .. i,
			BackgroundColor3 = Cores.TintaClara,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = i,
			Visible = false,
			Parent = feed,
		})
		local faixa = Kit.novo("Frame", {
			BackgroundColor3 = Cores.Borda,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 6, 1, 0),
			Parent = quadro,
		})
		local nome = Kit.texto({
			fonte = "media",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -90, 1, 0),
			Parent = quadro,
		})
		local chance = Kit.texto({
			fonte = "media",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -86, 0, 0),
			Size = UDim2.new(0, 70, 1, 0),
			Parent = quadro,
		})
		linhas[i] = { quadro = quadro, nome = nome, chance = chance, faixa = faixa }
	end
	local recentes: { Auras.Aura } = {}

	-- Barra inferior: AUTO | selo DESPERTAR | ÍNDICE
	local barra = Kit.novo("Frame", {
		Name = "Acoes",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(700, 200),
		Parent = hud,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 28),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = barra,
	})
	local auto = Kit.botaoPlaca({
		texto = "AUTO",
		largura = 190,
		altura = 66,
		tamanhoTexto = 26,
		sombra = Color3.new(0, 0, 0),
		ordem = 1,
		pai = barra,
		aoClicar = op.aoAlternarAuto,
	})

	local seloQuadro = Kit.circulo({
		Name = "Despertar",
		BackgroundColor3 = Cores.Papel,
		Size = UDim2.fromOffset(196, 196),
		LayoutOrder = 2,
		Parent = barra,
	})
	local seloEscala = Kit.novo("UIScale", { Parent = seloQuadro })
	local anel = Kit.anel(seloQuadro, 180, Cores.Selo, Cores.SeloEscuro, 2)
	local miolo = Kit.circulo({
		Name = "Miolo",
		BackgroundColor3 = Cores.Selo,
		Size = UDim2.fromOffset(156, 156),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 4,
		Parent = seloQuadro,
	})
	Kit.novo("UIStroke", { Color = Cores.Tinta, Thickness = 4, Parent = miolo })
	local olho = Kit.olho(miolo, 58, Cores.Papel, 5)
	olho.AnchorPoint = Vector2.new(0.5, 0)
	olho.Position = UDim2.new(0.5, 0, 0, 30)
	Kit.texto({
		Text = "DESPERTAR",
		TextSize = 25,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 5,
		Parent = miolo,
	})
	local seloBotao = Kit.novo("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = seloQuadro,
	})
	seloBotao.MouseButton1Down:Connect(function()
		seloEscala.Scale = 0.94
	end)
	seloBotao.MouseButton1Up:Connect(function()
		seloEscala.Scale = 1
	end)
	seloBotao.MouseLeave:Connect(function()
		seloEscala.Scale = 1
	end)
	seloBotao.Activated:Connect(op.aoDespertar)

	local indice = Kit.botaoPlaca({
		texto = "ÍNDICE",
		largura = 190,
		altura = 66,
		tamanhoTexto = 26,
		sombra = Cores.Selo,
		ordem = 3,
		pai = barra,
		aoClicar = op.aoAbrirIndice,
	})

	-- Resultado rápido acima do botão (todas as raridades)
	local resultado = Kit.texto({
		Name = "Resultado",
		TextSize = 30,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -240),
		Size = UDim2.fromOffset(700, 40),
		TextTransparency = 1,
		Parent = hud,
	})
	local resultadoContorno = Kit.novo("UIStroke", {
		Color = Cores.Tinta,
		Thickness = 3,
		Transparency = 1,
		Parent = resultado,
	})
	local resultadoToken = 0

	Escala.aoMudar(function()
		feed.Visible = not Escala.compacto
	end)

	return {
		definirCarga = function(fracao: number)
			anel.definir(fracao)
			miolo.BackgroundColor3 = if fracao >= 1
				then Cores.Selo
				else Cores.Selo:Lerp(Cores.SeloEscuro, 0.35)
		end,
		definirVisivel = function(visivel: boolean)
			hud.Visible = visivel
		end,
		atualizar = function(estado: Perfil.Estado)
			giros.Text = Formato.inteiro(estado.giros)
			local aura = if estado.equipada then Auras.porId[estado.equipada] else nil
			if aura then
				local cor = corTier(aura)
				nomeEquipada.Text = aura.nome
				nomeEquipada.TextColor3 = cor
				raridade.Text = string.format(
					"%s · 1 em %s",
					Auras.Tiers[aura.tier].nome,
					Formato.chance(aura.chance)
				)
				faixaTier.definirCor(cor)
			else
				nomeEquipada.Text = "Nenhuma"
				nomeEquipada.TextColor3 = Cores.Papel
				raridade.Text = "Clique em DESPERTAR"
				faixaTier.definirCor(Cores.Borda)
			end
			auto.definirAtivo(estado.configuracoes.giroAutomatico == true)
			local anuncios = estado.configuracoes.anuncios ~= false
			sinoTexto.TextTransparency = if anuncios then 0 else 0.6
			sinoContorno.Color = if anuncios then Cores.Papel else Cores.Borda
			local descobertas = Auras.contarDescobertas(estado.auras)
			indice.definirTexto(string.format("ÍNDICE %d/%d", descobertas, #Auras.lista))
		end,
		registrarResultado = function(aura: Auras.Aura)
			table.insert(recentes, 1, aura)
			if #recentes > RECENTES then
				table.remove(recentes)
			end
			for i, linha in linhas do
				local a = recentes[i]
				linha.quadro.Visible = a ~= nil
				if a then
					local cor = corTier(a)
					linha.nome.Text = a.nome
					linha.chance.Text = "1/" .. Formato.chanceCurta(a.chance)
					linha.chance.TextColor3 = cor
					linha.faixa.BackgroundColor3 = cor
					linha.quadro.BackgroundTransparency = (i - 1) * 0.15
				end
			end
			-- Nome acima do botão
			resultadoToken += 1
			local meu = resultadoToken
			resultado.Text = string.format("%s · 1 em %s", aura.nome, Formato.chance(aura.chance))
			resultado.TextColor3 = corTier(aura)
			resultado.TextTransparency = 0
			resultadoContorno.Transparency = 0
			task.delay(1.1, function()
				if resultadoToken == meu then
					local info = TweenInfo.new(0.3)
					TweenService:Create(resultado, info, { TextTransparency = 1 }):Play()
					TweenService:Create(resultadoContorno, info, { Transparency = 1 }):Play()
				end
			end)
		end,
	}
end

return HUD
