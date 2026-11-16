-- Constrói o mapa "Nexo do Despertar" por código (o repositório é a fonte da verdade).
-- Compacto: praça central com o Núcleo e seis lugares a ~95 studs, ligados por caminhos.
--   Norte     Obelisco das Lendas   (ranking do servidor)            funcional
--   Noroeste  Arquivo dos Ecos      (abre o índice)                  funcional
--   Sudoeste  Jardim dos Fragmentos (exploração leve, um eco oculto) funcional simples
--   Nordeste  Altar da Ressonância  | Sudeste Portais Fragmentados | Sul Arena dos Despertos
--             -> só cenário, marcados honestamente como "Em construção"
-- Tudo ancorado, sem malhas nem assets enviados. Norte = -Z.
local Lighting = game:GetService("Lighting")

local Nexo = {}

local RAIO_MUNDO = 150
local RAIO_PRACA = 46
local DISTANCIA = 95

local COR = {
	chao = Color3.fromHex("14121F"),
	pedra = Color3.fromHex("2A2738"),
	pedraClara = Color3.fromHex("4A4660"),
	marmore = Color3.fromHex("D9D2C3"),
	caminho = Color3.fromHex("3A3650"),
	energia = Color3.fromHex("7DF9FF"),
	violeta = Color3.fromHex("A855F7"),
	ouro = Color3.fromHex("FFC83D"),
	selo = Color3.fromHex("E2233B"),
	jade = Color3.fromHex("5BE37D"),
}

local function peca(pai: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Slate
	p.Color = COR.pedra
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = pai
	return p
end

-- Disco/cilindro em pé. `base` é o centro da face de baixo.
local function cilindro(
	pai: Instance,
	base: Vector3,
	raio: number,
	altura: number,
	props: { [string]: any }
): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(altura, raio * 2, raio * 2)
	props.CFrame = CFrame.new(base + Vector3.new(0, altura / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	return peca(pai, props)
end

local function neon(props: { [string]: any }): { [string]: any }
	props.Material = Enum.Material.Neon
	props.CanCollide = false
	props.CastShadow = false
	return props
end

-- Filete de luz no chão: disco neon com um disco escuro um pouco menor por cima
local function filete(
	pai: Instance,
	centro: Vector3,
	raio: number,
	largura: number,
	cor: Color3,
	corMiolo: Color3
)
	cilindro(pai, centro, raio, 0.05, neon({ Name = "Filete", Color = cor }))
	cilindro(pai, centro + Vector3.new(0, 0.03, 0), raio - largura, 0.05, {
		Name = "Miolo",
		Color = corMiolo,
		Material = Enum.Material.Marble,
		CanCollide = false,
		CastShadow = false,
	})
end

local function placa(
	pai: Instance,
	posicao: Vector3,
	titulo: string,
	subtitulo: string?,
	cor: Color3
)
	local ancora = peca(pai, {
		Name = "Placa",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Size = Vector3.new(1, 1, 1),
		Position = posicao,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 70)
	gui.MaxDistance = 140
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local nome = Instance.new("TextLabel")
	nome.BackgroundTransparency = 1
	nome.Size = UDim2.new(1, 0, 0, 40)
	nome.Font = Enum.Font.Oswald
	nome.TextSize = 30
	nome.TextColor3 = cor
	nome.TextStrokeTransparency = 0.3
	nome.Text = string.upper(titulo)
	nome.Parent = gui
	if subtitulo then
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromOffset(0, 40)
		sub.Size = UDim2.new(1, 0, 0, 24)
		sub.Font = Enum.Font.Oswald
		sub.TextSize = 18
		sub.TextColor3 = Color3.fromHex("A9A3B6")
		sub.TextStrokeTransparency = 0.4
		sub.Text = subtitulo
		sub.Parent = gui
	end
	gui.Parent = ancora
end

-- Interação por proximidade; o cliente decide o que fazer pelo atributo "Acao"
local function interacao(
	parte: BasePart,
	acao: string,
	rotulo: string,
	objeto: string,
	texto: string?
)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = rotulo
	prompt.ObjectText = objeto
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Acao", acao)
	if texto then
		prompt:SetAttribute("Texto", texto)
	end
	prompt.Parent = parte
end

local function cristal(
	pai: Instance,
	base: Vector3,
	altura: number,
	cor: Color3,
	inclinacao: CFrame?
)
	local giro = inclinacao or CFrame.new()
	local cf = CFrame.new(base)
		* giro
		* CFrame.new(0, altura / 2, 0)
		* CFrame.Angles(0, math.rad(45), 0)
	peca(pai, {
		Name = "Cristal",
		Material = Enum.Material.Glass,
		Color = cor,
		Transparency = 0.25,
		Size = Vector3.new(altura * 0.28, altura, altura * 0.28),
		CFrame = cf,
	})
	peca(
		pai,
		neon({
			Name = "CristalLuz",
			Color = cor,
			Size = Vector3.new(altura * 0.12, altura * 0.9, altura * 0.12),
			CFrame = cf,
		})
	)
end

local function luz(parte: BasePart, cor: Color3, alcance: number, brilho: number)
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = alcance
	l.Brightness = brilho
	l.Parent = parte
end

local function direcao(graus: number): Vector3
	-- 0° = norte (-Z), sentido horário visto de cima
	local a = math.rad(graus)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

local function construirChao(pasta: Instance)
	cilindro(pasta, Vector3.new(0, -4, 0), RAIO_MUNDO, 4, { Name = "Chao", Color = COR.chao })
	-- Borda de rochas (barreira natural)
	local rng = Random.new(11)
	local n = 44
	for i = 1, n do
		local a = (i / n) * 360
		local d = direcao(a)
		local altura = rng:NextNumber(7, 15)
		peca(pasta, {
			Name = "Rocha",
			Color = COR.pedra:Lerp(COR.chao, rng:NextNumber(0, 0.6)),
			Size = Vector3.new(24, altura, rng:NextNumber(8, 13)),
			CFrame = CFrame.lookAt(
				d * (RAIO_MUNDO - 3) + Vector3.new(0, altura / 2 - 1, 0),
				Vector3.new(0, altura / 2 - 1, 0)
			) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-7, 7))),
		})
	end
end

local function construirPraca(pasta: Instance)
	cilindro(
		pasta,
		Vector3.zero,
		RAIO_PRACA,
		1,
		{ Name = "Praca", Color = COR.pedraClara, Material = Enum.Material.Marble }
	)
	local topo = Vector3.new(0, 1, 0)
	filete(pasta, topo, 44, 0.5, COR.energia, COR.pedraClara)
	filete(pasta, topo + Vector3.new(0, 0.06, 0), 30, 0.35, COR.violeta, COR.pedraClara)
	filete(pasta, topo + Vector3.new(0, 0.12, 0), 16, 0.5, COR.energia, COR.pedra)
	-- Marcas radiais (formas geométricas originais)
	for i = 1, 12 do
		local d = direcao(i * 30)
		peca(
			pasta,
			neon({
				Name = "Marca",
				Color = if i % 3 == 0 then COR.ouro else COR.energia,
				Size = Vector3.new(0.4, 0.06, if i % 3 == 0 then 9 else 5),
				CFrame = CFrame.lookAt(d * 37 + Vector3.new(0, 1.2, 0), Vector3.new(0, 1.2, 0)),
			})
		)
	end
	-- Lanternas em volta da praça
	for i = 1, 8 do
		local d = direcao(i * 45 + 22.5)
		local base = d * (RAIO_PRACA - 3) + Vector3.new(0, 1, 0)
		peca(pasta, {
			Name = "Poste",
			Size = Vector3.new(1.2, 7, 1.2),
			Position = base + Vector3.new(0, 3.5, 0),
		})
		local globo = peca(
			pasta,
			neon({
				Name = "Lanterna",
				Shape = Enum.PartType.Ball,
				Color = COR.energia,
				Size = Vector3.new(1.8, 1.8, 1.8),
				Position = base + Vector3.new(0, 7.8, 0),
			})
		)
		luz(globo, COR.energia, 26, 1.2)
	end
end

local function construirNucleo(pasta: Instance)
	local nucleo = Instance.new("Model")
	nucleo.Name = "Nucleo"
	nucleo.Parent = pasta
	cilindro(nucleo, Vector3.new(0, 1, 0), 8, 1.2, { Name = "Base", Color = COR.pedra })
	cilindro(
		nucleo,
		Vector3.new(0, 2.2, 0),
		5,
		1,
		{ Name = "Base2", Color = COR.pedraClara, Material = Enum.Material.Marble }
	)
	-- Coração de energia (o cliente anima: flutua, pulsa e ganha anéis orbitais)
	local centro = Vector3.new(0, 15, 0)
	local coracao = peca(
		nucleo,
		neon({
			Name = "Coracao",
			Shape = Enum.PartType.Ball,
			Color = COR.energia,
			Size = Vector3.new(5, 5, 5),
			Position = centro,
		})
	)
	luz(coracao, COR.energia, 60, 2.5)
	peca(nucleo, {
		Name = "Casca",
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Color = COR.violeta,
		CanCollide = false,
		CastShadow = false,
		Size = Vector3.new(9, 9, 9),
		Position = centro,
	})
	-- Grande cristal partido em volta do coração
	for i = 1, 6 do
		local d = direcao(i * 60)
		local inclinacao = CFrame.lookAt(Vector3.zero, d) * CFrame.Angles(math.rad(-16), 0, 0)
		local base = centro + d * 4.6 + Vector3.new(0, if i % 2 == 0 then -7 else -4, 0)
		cristal(
			nucleo,
			base,
			if i % 2 == 0 then 14 else 9,
			if i % 2 == 0 then COR.violeta else COR.energia,
			inclinacao
		)
	end
	-- Feixe que sobe do coração
	peca(
		nucleo,
		neon({
			Name = "Feixe",
			Shape = Enum.PartType.Cylinder,
			Color = COR.energia,
			Transparency = 0.75,
			Size = Vector3.new(220, 1.4, 1.4),
			CFrame = CFrame.new(centro + Vector3.new(0, 112, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
		})
	)
	placa(pasta, Vector3.new(0, 30, 0), "Núcleo do Despertar", nil, COR.energia)
end

local function construirCaminhos(pasta: Instance)
	for _, graus in { 0, 45, 135, 180, 225, 315 } do
		local d = direcao(graus)
		local inicio, fim = RAIO_PRACA - 2, DISTANCIA - 16
		local meio = d * ((inicio + fim) / 2)
		peca(pasta, {
			Name = "Caminho",
			Color = COR.caminho,
			Material = Enum.Material.Cobblestone,
			Size = Vector3.new(11, 0.4, fim - inicio),
			CFrame = CFrame.lookAt(meio + Vector3.new(0, 0.1, 0), Vector3.new(0, 0.1, 0)),
		})
		for lado = -1, 1, 2 do
			local lateral = Vector3.new(-d.Z, 0, d.X) * 5.8 * lado
			peca(
				pasta,
				neon({
					Name = "Guia",
					Color = COR.violeta,
					Size = Vector3.new(0.25, 0.1, fim - inicio),
					CFrame = CFrame.lookAt(
						meio + lateral + Vector3.new(0, 0.32, 0),
						lateral + Vector3.new(0, 0.32, 0)
					),
				})
			)
		end
	end
end

local function construirObelisco(pasta: Instance)
	local centro = direcao(0) * DISTANCIA
	local olhar = CFrame.lookAt(centro, Vector3.zero)
	cilindro(
		pasta,
		centro,
		15,
		0.8,
		{ Name = "ObeliscoBase", Color = COR.pedraClara, Material = Enum.Material.Marble }
	)
	cilindro(
		pasta,
		centro + Vector3.new(0, 0.8, 0),
		10,
		0.8,
		{ Name = "ObeliscoBase2", Color = COR.pedra }
	)
	local y = 1.6
	for i, lado in { 7, 5.4, 3.8 } do
		local altura = 13 - i
		peca(pasta, {
			Name = "Obelisco" .. i,
			Color = COR.pedra,
			Material = Enum.Material.Basalt,
			Size = Vector3.new(lado, altura, lado),
			CFrame = olhar * CFrame.new(0, y + altura / 2, 0),
		})
		peca(
			pasta,
			neon({
				Name = "ObeliscoLinha" .. i,
				Color = COR.ouro,
				Size = Vector3.new(lado + 0.1, 0.3, lado + 0.1),
				CFrame = olhar * CFrame.new(0, y + altura, 0),
			})
		)
		y += altura
	end
	local ponta = peca(
		pasta,
		neon({
			Name = "ObeliscoPonta",
			Color = COR.ouro,
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = olhar * CFrame.new(0, y + 2, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		})
	)
	luz(ponta, COR.ouro, 40, 2)
	-- Painel do ranking, virado para a praça
	local painel = peca(pasta, {
		Name = "PainelRanking",
		Color = Color3.fromHex("0B0A10"),
		Material = Enum.Material.SmoothPlastic,
		Size = Vector3.new(14, 8, 0.6),
		CFrame = olhar * CFrame.new(0, 6.2, -9),
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Ranking"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local texto = Instance.new("TextLabel")
	texto.Name = "Texto"
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.fromScale(1, 1)
	texto.Font = Enum.Font.Oswald
	texto.TextSize = 34
	texto.TextColor3 = Color3.fromHex("F2EDE4")
	texto.RichText = true
	texto.TextYAlignment = Enum.TextYAlignment.Top
	texto.Text = "LENDAS DESTE SERVIDOR"
	local margem = Instance.new("UIPadding")
	margem.PaddingTop = UDim.new(0, 16)
	margem.Parent = texto
	texto.Parent = gui
	gui.Parent = painel
	placa(
		pasta,
		centro + Vector3.new(0, y + 8, 0),
		"Obelisco das Lendas",
		"Ranking do servidor",
		COR.ouro
	)
end

local function construirArquivo(pasta: Instance)
	local centro = direcao(315) * DISTANCIA
	cilindro(
		pasta,
		centro,
		17,
		0.8,
		{ Name = "ArquivoBase", Color = COR.pedraClara, Material = Enum.Material.Marble }
	)
	filete(pasta, centro + Vector3.new(0, 0.8, 0), 15, 0.4, COR.energia, COR.pedraClara)
	for i = 1, 8 do
		local d = direcao(i * 45)
		-- deixa a entrada (lado da praça) livre
		if i ~= 3 then
			cilindro(pasta, centro + d * 14 + Vector3.new(0, 0.8, 0), 1.1, 13, {
				Name = "Coluna",
				Color = COR.marmore,
				Material = Enum.Material.Marble,
			})
		end
	end
	cilindro(
		pasta,
		centro + Vector3.new(0, 13.8, 0),
		16.5,
		1,
		{ Name = "Cobertura", Color = COR.pedra }
	)
	cilindro(
		pasta,
		centro + Vector3.new(0, 14.8, 0),
		9,
		1.4,
		{ Name = "Cupula", Color = COR.pedraClara, Material = Enum.Material.Marble }
	)
	-- Console central: abre o índice
	local console = cilindro(
		pasta,
		centro + Vector3.new(0, 0.8, 0),
		2.2,
		3,
		{ Name = "Console", Color = COR.pedra }
	)
	local esfera = peca(
		pasta,
		neon({
			Name = "Eco",
			Shape = Enum.PartType.Ball,
			Color = COR.energia,
			Size = Vector3.new(2.4, 2.4, 2.4),
			Position = centro + Vector3.new(0, 5.6, 0),
		})
	)
	luz(esfera, COR.energia, 30, 1.8)
	interacao(console, "indice", "Abrir índice", "Arquivo dos Ecos")
	-- Projeções: painéis translúcidos em volta (silhuetas de auras por descobrir)
	local cores = { COR.energia, COR.violeta, COR.ouro, COR.jade, COR.selo, COR.violeta }
	for i, cor in cores do
		local d = direcao(i * 60 + 10)
		peca(
			pasta,
			neon({
				Name = "Projecao",
				Color = cor,
				Transparency = 0.6,
				Size = Vector3.new(3, 4.5, 0.15),
				CFrame = CFrame.lookAt(
					centro + d * 8.5 + Vector3.new(0, 6, 0),
					centro + Vector3.new(0, 6, 0)
				),
			})
		)
	end
	placa(
		pasta,
		centro + Vector3.new(0, 20, 0),
		"Arquivo dos Ecos",
		"Coleção de auras",
		COR.energia
	)
end

local ECOS = {
	'Um sussurro antigo: "Todo poder dorme até ser chamado."',
	'O fragmento vibra: "Nem toda luz que desperta quer ser contida."',
	'Uma voz distante: "O Nexo se lembra de cada ruptura."',
}

local function construirJardim(pasta: Instance)
	local centro = direcao(225) * DISTANCIA
	local rng = Random.new(23)
	cilindro(pasta, centro + Vector3.new(0, -0.1, 0), 24, 0.4, {
		Name = "JardimChao",
		Color = Color3.fromHex("1E2A26"),
		Material = Enum.Material.Grass,
	})
	local cores = { COR.jade, COR.energia, COR.violeta }
	for i = 1, 16 do
		local d = direcao(rng:NextNumber(0, 360))
		local base = centro + d * rng:NextNumber(5, 22) + Vector3.new(0, 0.2, 0)
		local inclinacao =
			CFrame.Angles(math.rad(rng:NextNumber(-18, 18)), math.rad(rng:NextNumber(0, 360)), 0)
		cristal(pasta, base, rng:NextNumber(2.5, 8), cores[i % 3 + 1], inclinacao)
	end
	-- Ruínas: arcos quebrados
	for i = 1, 3 do
		local d = direcao(120 * i + 30)
		local base = centro + d * 13
		local olhar = CFrame.lookAt(base, centro)
		peca(pasta, {
			Name = "Ruina",
			Material = Enum.Material.Cobblestone,
			Size = Vector3.new(2, 9, 2),
			CFrame = olhar * CFrame.new(-3.5, 4.5, 0),
		})
		peca(pasta, {
			Name = "Ruina",
			Material = Enum.Material.Cobblestone,
			Size = Vector3.new(2, if i == 2 then 5 else 9, 2),
			CFrame = olhar * CFrame.new(3.5, if i == 2 then 2.5 else 4.5, 0),
		})
		if i ~= 2 then
			peca(pasta, {
				Name = "Ruina",
				Material = Enum.Material.Cobblestone,
				Size = Vector3.new(10, 1.6, 2.2),
				CFrame = olhar * CFrame.new(0, 9.6, 0),
			})
		end
	end
	-- Eco oculto atrás da ruína mais distante: só curiosidade, sem recompensa
	local escondido = centro + direcao(225) * 19 + Vector3.new(0, 1.4, 0)
	local fragmento = peca(
		pasta,
		neon({
			Name = "FragmentoSussurrante",
			Color = COR.ouro,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(escondido) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		})
	)
	luz(fragmento, COR.ouro, 12, 1.5)
	interacao(fragmento, "eco", "Ouvir", "Fragmento sussurrante", ECOS[rng:NextInteger(1, #ECOS)])
	placa(pasta, centro + Vector3.new(0, 14, 0), "Jardim dos Fragmentos", nil, COR.jade)
end

local function construirAltar(pasta: Instance)
	local centro = direcao(45) * DISTANCIA
	for i, raio in { 14, 10.5, 7 } do
		cilindro(pasta, centro + Vector3.new(0, (i - 1) * 0.9, 0), raio, 0.9, {
			Name = "AltarDegrau",
			Color = if i == 3 then COR.pedraClara else COR.pedra,
			Material = if i == 3 then Enum.Material.Marble else Enum.Material.Slate,
		})
	end
	filete(pasta, centro + Vector3.new(0, 2.7, 0), 6, 0.35, COR.violeta, COR.pedraClara)
	for i = 1, 3 do
		local d = direcao(i * 120)
		peca(pasta, {
			Name = "Monolito",
			Material = Enum.Material.Basalt,
			Size = Vector3.new(2.4, 11, 1.4),
			CFrame = CFrame.lookAt(
				centro + d * 9 + Vector3.new(0, 7.3, 0),
				centro + Vector3.new(0, 7.3, 0)
			),
		})
	end
	local mesa = cilindro(
		pasta,
		centro + Vector3.new(0, 2.7, 0),
		1.6,
		2.2,
		{ Name = "AltarMesa", Color = COR.pedra }
	)
	interacao(
		mesa,
		"em_construcao",
		"Em construção",
		"Altar da Ressonância",
		"O Altar da Ressonância ainda está em construção."
	)
	placa(
		pasta,
		centro + Vector3.new(0, 17, 0),
		"Altar da Ressonância",
		"Em construção",
		COR.violeta
	)
end

local function construirPortais(pasta: Instance)
	local centro = direcao(135) * DISTANCIA
	cilindro(pasta, centro, 16, 0.6, { Name = "PortaisBase", Color = COR.pedra })
	local cores = { COR.violeta, COR.energia, COR.selo }
	for i = 1, 3 do
		local d = direcao(135 + (i - 2) * 38)
		local base = centro + d * 9 + direcao(135) * 2
		local olhar = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
		peca(pasta, {
			Name = "PortalPilar",
			Material = Enum.Material.Basalt,
			Size = Vector3.new(1.8, 13, 1.8),
			CFrame = olhar * CFrame.new(-3.6, 7, 0) * CFrame.Angles(0, 0, math.rad(-4)),
		})
		peca(pasta, {
			Name = "PortalPilar",
			Material = Enum.Material.Basalt,
			Size = Vector3.new(1.8, if i == 3 then 8 else 13, 1.8),
			CFrame = olhar
				* CFrame.new(3.6, if i == 3 then 4.5 else 7, 0)
				* CFrame.Angles(0, 0, math.rad(4)),
		})
		if i ~= 3 then
			peca(pasta, {
				Name = "PortalVerga",
				Material = Enum.Material.Basalt,
				Size = Vector3.new(10, 1.6, 2),
				CFrame = olhar * CFrame.new(0, 14, 0),
			})
		end
		local veu = peca(pasta, {
			Name = "PortalVeu",
			Material = Enum.Material.ForceField,
			Color = cores[i],
			CanCollide = false,
			CastShadow = false,
			Size = Vector3.new(5.6, 11, 0.3),
			CFrame = olhar * CFrame.new(0, 6.8, 0),
		})
		luz(veu, cores[i], 16, 1.2)
		if i == 2 then
			interacao(
				veu,
				"em_construcao",
				"Em construção",
				"Portais Fragmentados",
				"Os portais ainda não levam a lugar nenhum."
			)
		end
	end
	placa(
		pasta,
		centro + Vector3.new(0, 19, 0),
		"Portais Fragmentados",
		"Em construção",
		COR.violeta
	)
end

local function construirArena(pasta: Instance)
	local centro = direcao(180) * (DISTANCIA + 4)
	cilindro(
		pasta,
		centro,
		22,
		0.5,
		{ Name = "ArenaPiso", Color = COR.pedraClara, Material = Enum.Material.Marble }
	)
	filete(pasta, centro + Vector3.new(0, 0.5, 0), 12, 0.4, COR.selo, COR.pedraClara)
	-- Arquibancada em arco (aberta para a praça)
	for degrau = 1, 3 do
		for i = -5, 5 do
			local d = direcao(180 + i * 15)
			local raio = 20 + degrau * 3
			peca(pasta, {
				Name = "Arquibancada",
				Size = Vector3.new(6.4, degrau * 1.4, 3),
				CFrame = CFrame.lookAt(
					centro + d * raio + Vector3.new(0, degrau * 0.7, 0),
					centro + Vector3.new(0, degrau * 0.7, 0)
				),
			})
		end
	end
	placa(pasta, centro + Vector3.new(0, 12, 0), "Arena dos Despertos", "Em construção", COR.selo)
end

local function construirIlhas(pasta: Instance)
	local rng = Random.new(5)
	for i = 1, 7 do
		local d = direcao(i * 51 + 12)
		local centro = d * rng:NextNumber(210, 290) + Vector3.new(0, rng:NextNumber(25, 95), 0)
		local largura = rng:NextNumber(26, 48)
		peca(pasta, {
			Name = "Ilha",
			Color = COR.pedra,
			Size = Vector3.new(largura, 7, largura * 0.8),
			CFrame = CFrame.new(centro) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
		})
		peca(pasta, {
			Name = "IlhaBase",
			Color = COR.chao,
			Size = Vector3.new(largura * 0.6, 9, largura * 0.5),
			CFrame = CFrame.new(centro - Vector3.new(0, 7, 0))
				* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
		})
		cristal(
			pasta,
			centro + Vector3.new(0, 3.5, 0),
			rng:NextNumber(10, 20),
			if i % 2 == 0 then COR.violeta else COR.energia,
			CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), 0, 0)
		)
	end
end

local function configurarCeu()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromHex("3A3350")
	Lighting.OutdoorAmbient = Color3.fromHex("4A4470")
	Lighting.ColorShift_Top = Color3.fromHex("8B7BD8")
	Lighting.FogEnd = 100000
	for _, filho in Lighting:GetChildren() do
		if filho:IsA("Sky") or filho:IsA("Atmosphere") or filho.Name == "NexoBloom" then
			filho:Destroy()
		end
	end
	local ceu = Instance.new("Sky")
	ceu.StarCount = 5000
	ceu.CelestialBodiesShown = false
	ceu.Parent = Lighting
	local atmosfera = Instance.new("Atmosphere")
	atmosfera.Density = 0.32
	atmosfera.Offset = 0.2
	atmosfera.Color = Color3.fromHex("6C5FA8")
	atmosfera.Decay = Color3.fromHex("1A1030")
	atmosfera.Glare = 0
	atmosfera.Haze = 1.6
	atmosfera.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "NexoBloom"
	bloom.Intensity = 0.6
	bloom.Size = 22
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
end

-- Monta o mapa (uma vez). Devolve a pasta criada.
function Nexo.construir(): Folder
	local existente = workspace:FindFirstChild("Nexo")
	if existente then
		existente:Destroy()
	end
	local pasta = Instance.new("Folder")
	pasta.Name = "Nexo"

	construirChao(pasta)
	construirPraca(pasta)
	construirNucleo(pasta)
	construirCaminhos(pasta)
	construirObelisco(pasta)
	construirArquivo(pasta)
	construirJardim(pasta)
	construirAltar(pasta)
	construirPortais(pasta)
	construirArena(pasta)
	construirIlhas(pasta)

	-- Spawn ao sul da praça, já olhando para o Núcleo
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 1.5, 34), Vector3.new(0, 1.5, 0))
	spawn.Parent = pasta

	pasta.Parent = workspace
	configurarCeu()
	return pasta
end

return Nexo
