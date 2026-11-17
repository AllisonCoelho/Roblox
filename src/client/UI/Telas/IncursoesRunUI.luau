-- Incursões 2.0 no HUD: banner do andar (tipo + objetivo), nota S/A/B ao concluir, contador de
-- sequência de abates, alerta de Elite e as cartas das Bênçãos da Fenda (1 de 3).
-- Só mostra; quem decide tudo é o servidor (src/server/Incursoes).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tema = require(Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)
local Estado = require(script.Parent.Parent.Estado)

local Cores = Tema.Orbita
local RunUI = {}

local COR_RARIDADE = {
	comum = Color3.fromHex("B8C1CC"),
	rara = Color3.fromHex("4CC9F0"),
	lendaria = Color3.fromHex("FFC83D"),
}
local COR_NOTA =
	{ S = Color3.fromHex("FFD36B"), A = Color3.fromHex("C9B8FF"), B = Color3.fromHex("B8C1CC") }

local banner: Frame
local bannerTitulo: TextLabel
local bannerTexto: TextLabel
local notaRotulo: TextLabel
local notaTexto: TextLabel
local seqQuadro: Frame
local seqNumero: TextLabel
local seqTexto: TextLabel
local eliteRotulo: TextLabel
local cartas: Frame
local bencaosAtivas: TextLabel
local avisoFn: (string) -> () = function() end
local seqAte = 0
local versaoBanner = 0
local versaoNota = 0
local versaoElite = 0

local function sumir(obj: GuiObject, depois: number, versao: () -> number, minha: number)
	task.delay(depois, function()
		if versao() == minha then
			obj.Visible = false
		end
	end)
end

function RunUI.montar(hud: Instance, aoAviso: (string) -> ())
	avisoFn = aoAviso
	-- Banner do andar
	banner = Kit.novo("Frame", {
		Name = "BannerAndar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(640, 110),
		BackgroundColor3 = Cores.Painel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = hud,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(0, 16), Parent = banner })
	Kit.novo("UIStroke", { Color = Cores.Lilas, Thickness = 2, Parent = banner })
	bannerTitulo = Kit.texto({
		fonte = "titulo",
		TextSize = 38,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.fromOffset(0, 6),
		Parent = banner,
	})
	bannerTexto = Kit.texto({
		TextSize = 20,
		TextWrapped = true,
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 60),
		Parent = banner,
	})

	-- Nota S/A/B
	notaRotulo = Kit.texto({
		fonte = "titulo",
		Text = "S",
		TextSize = 150,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(240, 170),
		Visible = false,
		Parent = hud,
	})
	Kit.novo("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Parent = notaRotulo })
	notaTexto = Kit.texto({
		fonte = "titulo",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.38, 90),
		Size = UDim2.fromOffset(600, 34),
		Visible = false,
		Parent = hud,
	})

	-- Sequência de abates
	seqQuadro = Kit.novo("Frame", {
		Name = "Sequencia",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.42, 0),
		Size = UDim2.fromOffset(180, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = hud,
	})
	seqNumero = Kit.texto({
		fonte = "titulo",
		Text = "x1",
		TextSize = 64,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 70),
		Parent = seqQuadro,
	})
	Kit.novo("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Parent = seqNumero })
	seqTexto = Kit.texto({
		fonte = "titulo",
		Text = "SEQUÊNCIA",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Cores.Lilas,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 72),
		Parent = seqQuadro,
	})

	-- Alerta de Elite
	eliteRotulo = Kit.texto({
		fonte = "titulo",
		TextSize = 30,
		TextColor3 = Color3.fromHex("FFD36B"),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 270),
		Size = UDim2.fromOffset(700, 40),
		Visible = false,
		Parent = hud,
	})
	Kit.novo("UIStroke", { Color = Color3.fromHex("5A2A00"), Thickness = 2, Parent = eliteRotulo })

	-- Cartas das Bênçãos
	cartas = Kit.novo("Frame", {
		Name = "Bencaos",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(3 * 250 + 2 * 18, 330),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = hud,
	})
	Kit.texto({
		fonte = "titulo",
		Text = "BÊNÇÃO DA FENDA — escolha uma",
		TextSize = 28,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, -46),
		Parent = cartas,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 18),
		Parent = cartas,
	})

	-- Bênçãos já escolhidas (canto)
	bencaosAtivas = Kit.texto({
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Cores.Lilas,
		Position = UDim2.new(0, 30, 0, 230),
		Size = UDim2.fromOffset(260, 200),
		Text = "",
		Parent = hud,
	})
end

function RunUI.banner(titulo: string, texto: string)
	versaoBanner += 1
	bannerTitulo.Text = string.upper(titulo)
	bannerTexto.Text = texto
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, 120)
	TweenService:Create(
		banner,
		TweenInfo.new(0.35, Enum.EasingStyle.Back),
		{ Position = UDim2.new(0.5, 0, 0, 150) }
	):Play()
	sumir(banner, 4.5, function()
		return versaoBanner
	end, versaoBanner)
end

function RunUI.nota(nota: string, mult: number?, tempo: number?, quedas: number?)
	versaoNota += 1
	notaRotulo.Text = nota
	notaRotulo.TextColor3 = COR_NOTA[nota] or Cores.Texto
	notaRotulo.Visible = true
	notaRotulo.Size = UDim2.fromOffset(480, 340)
	TweenService:Create(
		notaRotulo,
		TweenInfo.new(0.4, Enum.EasingStyle.Back),
		{ Size = UDim2.fromOffset(240, 170) }
	):Play()
	notaTexto.Text = string.format(
		"NOTA %s  ·  %ds  ·  %d queda(s)  ·  Fragmentos x%.1f",
		nota,
		tempo or 0,
		quedas or 0,
		mult or 1
	)
	notaTexto.Visible = true
	local v = versaoNota
	sumir(notaRotulo, 3, function()
		return versaoNota
	end, v)
	sumir(notaTexto, 3, function()
		return versaoNota
	end, v)
end

function RunUI.sequencia(n: number)
	seqNumero.Text = "x" .. n
	seqNumero.TextColor3 = if n >= 20
		then Color3.fromHex("FF6B6B")
		elseif n >= 10 then Color3.fromHex("FFD36B")
		elseif n >= 5 then Cores.Lilas
		else Cores.Texto
	seqTexto.Text = if n >= 20
		then "IMPARÁVEL!"
		elseif n >= 10 then "MASSACRE!"
		elseif n >= 5 then "EM CHAMAS!"
		else "SEQUÊNCIA"
	seqQuadro.Visible = n >= 2
	seqNumero.TextSize = 80
	TweenService:Create(seqNumero, TweenInfo.new(0.2), { TextSize = 64 }):Play()
	seqAte = os.clock() + 3
	local marca = seqAte
	task.delay(3.05, function()
		if seqAte == marca then
			seqQuadro.Visible = false
		end
	end)
end

function RunUI.elite(texto: string)
	versaoElite += 1
	eliteRotulo.Text = "⚠ " .. texto .. " ⚠"
	eliteRotulo.Visible = true
	sumir(eliteRotulo, 3, function()
		return versaoElite
	end, versaoElite)
end

local function fecharCartas()
	cartas.Visible = false
	for _, c in cartas:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
end

function RunUI.bencaos(lista: { any })
	fecharCartas()
	for i, carta in lista do
		if type(carta) ~= "table" or type(carta.id) ~= "string" then
			continue
		end
		local cor = COR_RARIDADE[carta.raridade] or Cores.Borda
		local botao = Kit.novo("TextButton", {
			Name = carta.id,
			Text = "",
			LayoutOrder = i,
			AutoButtonColor = true,
			Size = UDim2.fromOffset(250, 320),
			BackgroundColor3 = Cores.Painel,
			Parent = cartas,
		})
		Kit.novo("UICorner", { CornerRadius = UDim.new(0, 18), Parent = botao })
		Kit.novo("UIStroke", { Color = cor, Thickness = 3, Parent = botao })
		Kit.texto({
			fonte = "titulo",
			Text = string.upper(tostring(carta.raridade or "")),
			TextSize = 16,
			TextColor3 = cor,
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.fromOffset(0, 16),
			Parent = botao,
		})
		Kit.texto({
			fonte = "titulo",
			Text = tostring(carta.nome),
			TextSize = 28,
			TextWrapped = true,
			Size = UDim2.new(1, -24, 0, 80),
			Position = UDim2.fromOffset(12, 50),
			Parent = botao,
		})
		Kit.texto({
			Text = tostring(carta.descricao),
			TextSize = 20,
			TextWrapped = true,
			Size = UDim2.new(1, -28, 0, 130),
			Position = UDim2.fromOffset(14, 140),
			Parent = botao,
		})
		Kit.texto({
			fonte = "titulo",
			Text = "ESCOLHER",
			TextSize = 18,
			TextColor3 = cor,
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 1, -42),
			Parent = botao,
		})
		botao.Activated:Connect(function()
			fecharCartas()
			task.spawn(function()
				local _, msg = Estado.pedir("IncursaoBencao", carta.id)
				if msg then
					avisoFn(msg)
				end
			end)
		end)
	end
	cartas.Visible = true
end

function RunUI.bencaosAtivas(nomes: { string })
	bencaosAtivas.Text = if #nomes > 0
		then "BÊNÇÃOS\n• " .. table.concat(nomes, "\n• ")
		else ""
end

-- Texto do objetivo do andar a partir do estado enviado pelo servidor
function RunUI.objetivo(d: any): string?
	local tipo: string = tostring(d.tipoAndar)
	local ehCofre = tipo == "cofre"
	if d.fenda and not ehCofre then
		return nil
	end
	if tipo == "horda" and type(d.hordaResta) == "number" then
		return string.format("Sobrevivam: %ds", d.hordaResta)
	elseif tipo == "caca" then
		return string.format("Elites restantes %d/%d", d.elites or 0, d.elitesTotal or 0)
	elseif tipo == "escolta" and type(d.escolta) == "number" then
		return string.format("Escolta %d%%", d.escolta)
	elseif ehCofre and type(d.cofre) == "number" then
		return if d.cofre >= 100 then "Cofre aberto!" else string.format("Cofre %d%%", d.cofre)
	end
	return nil
end

function RunUI.limpar()
	fecharCartas()
	banner.Visible = false
	notaRotulo.Visible = false
	notaTexto.Visible = false
	seqQuadro.Visible = false
	eliteRotulo.Visible = false
	bencaosAtivas.Text = ""
end

return RunUI
