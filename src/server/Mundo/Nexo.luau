-- Constrói o mapa "Nexo do Despertar" por código (o repositório é a fonte da verdade).
-- Praça central com o Núcleo e seis lugares a ~150 studs, ligados por caminhos, dentro de
-- um anel de penhascos (o mapa é fechado: parede invisível em RAIO_LIMITE).
--   Norte     Obelisco das Lendas   (ranking do servidor)            funcional
--   Noroeste  Arquivo dos Ecos      (abre o índice)                  funcional
--   Sudoeste  Jardim dos Fragmentos (exploração leve, um eco oculto) funcional simples
--   Nordeste  Altar da Ressonância  | Sudeste Portais Fragmentados | Sul Arena do Trono
--   Sul-sudeste (157°, 173) Bastião das Incursões, ligado aos Portais por um ramal
--             -> só cenário, marcados honestamente como "Em construção"/"Em preparação"
-- O servidor monta colisão e partes funcionais; o visual 3D vem do kit de cada cliente
-- (src/client/Mundo/Nexo3D). Tudo ancorado. Norte = -Z.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NexoColisores = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("NexoColisores")
)

local Nexo = {}

local RAIO_MUNDO = 260
local RAIO_PRACA = 46

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

-- Peças que o kit 3D NÃO esconde: funcionais ou que já são o visual final
local KIT_MANTEM = {
	Chao = true,
	Coracao = true,
	Casca = true,
	Feixe = true,
	PainelRanking = true,
	Placa = true,
	PortalVeu = true,
	FragmentoSussurrante = true,
	ParedeLimite = true,
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
		luz(globo, COR.energia, 34, 1.8)
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
	luz(coracao, COR.energia, 70, 3)
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

-- ===================================================================== Locais (fase 2)
-- Cada lugar fica num ângulo e distância (LOCAIS) e é montado no espaço local
-- `olhar = CFrame.lookAt(centro, origem)`: -Z local aponta para a praça.
-- O que se constrói aqui é o ESQUELETO: colisão com as mesmas medidas dos modelos 3D
-- (assets/nexo/source/generate_nexo.py usa os mesmos números) e as partes funcionais
-- (painel do ranking, console do índice, fragmento, véus, mesa do altar e placas).
-- O cliente esconde o esqueleto quando o kit 3D monta; se o kit falhar, ele aparece.

local LOCAIS = {
	obelisco = { graus = 0, dist = 150, borda = 20 },
	altar = { graus = 45, dist = 150, borda = 22 },
	portais = { graus = 135, dist = 150, borda = 23 },
	arena = { graus = 180, dist = 156, borda = 25 },
	jardim = { graus = 225, dist = 150, borda = 33 },
	arquivo = { graus = 315, dist = 150, borda = 22 },
}
local INICIO_CAMINHO = 47
local RAIO_LIMITE = 238 -- parede invisível; os penhascos 3D ficam logo atrás

local function referencia(nome: string): CFrame
	local l = LOCAIS[nome]
	local centro = direcao(l.graus) * l.dist
	return CFrame.lookAt(centro, Vector3.zero)
end

-- Ponto num círculo do lugar, com o ângulo medido a partir da frente (lado da praça)
local function polar(raio: number, graus: number): (number, number)
	local a = math.rad(graus)
	return raio * math.sin(a), -raio * math.cos(a)
end

-- Cilindro em pé com base no ponto local (x, y, z) do lugar
local function cilindroLocal(
	pai: Instance,
	olhar: CFrame,
	x: number,
	y: number,
	z: number,
	raio: number,
	altura: number,
	props: { [string]: any }
): Part
	return cilindro(pai, (olhar * CFrame.new(x, y, z)).Position, raio, altura, props)
end

-- Caixa no espaço local do lugar; `giro` (graus) vira a caixa em torno do Y
local function caixaLocal(
	pai: Instance,
	olhar: CFrame,
	x: number,
	y: number,
	z: number,
	tamanho: Vector3,
	giro: number?,
	props: { [string]: any }?
): Part
	local p = props or {}
	p.Size = tamanho
	p.CFrame = olhar * CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(giro or 0), 0)
	return peca(pai, p)
end

local function construirLimite(pasta: Instance)
	-- Parede invisível em anel: ninguém sai do Nexo, nem pulando
	local n = 64
	local largura = 2 * math.pi * RAIO_LIMITE / n + 1
	for i = 0, n - 1 do
		local a = 360 * i / n
		local d = direcao(a)
		peca(pasta, {
			Name = "ParedeLimite",
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Size = Vector3.new(largura, 400, 4),
			CFrame = CFrame.lookAt(
				d * RAIO_LIMITE + Vector3.new(0, 196, 0),
				Vector3.new(0, 196, 0)
			),
		})
	end
end

-- Borda visível do cenário de reserva: um anel simples e opaco de rocha logo atrás da parede
-- invisível. É provisória: some quando o kit 3D (com os penhascos) carrega no cliente.
local function construirBordaProvisoria(pasta: Instance)
	local n = 48
	local raio = RAIO_LIMITE + 5
	local largura = 2 * math.pi * raio / n + 2
	for i = 0, n - 1 do
		local d = direcao(360 * i / n)
		local altura = if i % 2 == 0 then 110 else 92
		peca(pasta, {
			Name = "BordaProvisoria",
			Material = Enum.Material.Rock,
			Color = COR.pedra,
			CanCollide = false,
			CanQuery = false,
			Size = Vector3.new(largura, altura, 8),
			CFrame = CFrame.lookAt(
				d * raio + Vector3.new(0, altura / 2, 0),
				Vector3.new(0, altura / 2, 0)
			),
		})
	end
end

-- Colisão das peças do kit 3D (arcos, pilares, muros, troncos), criada no servidor para que
-- todos os jogadores colidam igual, com ou sem o kit carregado. Os dados vêm do gerador do
-- Blender (src/shared/Dados/NexoColisores.luau). As caixas são provisórias: aparecem como
-- blocos simples no cenário de reserva e o cliente as esconde quando o kit monta.
local function construirColisoresKit(pasta: Instance)
	for _, c in NexoColisores :: { { [string]: any } } do
		local pos, tam = c.posicao, c.tamanho
		peca(pasta, {
			Name = "ColisorKit",
			Color = COR.pedra,
			CastShadow = false,
			Size = Vector3.new(tam[1], tam[2], tam[3]),
			CFrame = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(0, math.rad(c.giro), 0),
		})
	end
end

local function construirCaminhos(pasta: Instance)
	for _, l in LOCAIS do
		local d = direcao(l.graus)
		local inicio, fim = INICIO_CAMINHO - 1, l.dist - l.borda
		local meio = d * ((inicio + fim) / 2)
		peca(pasta, {
			Name = "Caminho",
			Color = COR.caminho,
			Material = Enum.Material.Cobblestone,
			Size = Vector3.new(12, 0.4, fim - inicio),
			CFrame = CFrame.lookAt(meio + Vector3.new(0, 0.1, 0), Vector3.new(0, 0.1, 0)),
		})
	end
end

local function construirArquivo(pasta: Instance)
	local olhar = referencia("arquivo")
	cilindroLocal(pasta, olhar, 0, 0, 0, 21, 1, { Name = "ArquivoBase", Color = COR.pedraClara })
	cilindroLocal(pasta, olhar, 0, 1, 0, 17, 1, { Name = "ArquivoBase2", Color = COR.pedraClara })
	for i = 1, 9 do
		local x, z = polar(15, 36 * i)
		cilindroLocal(pasta, olhar, x, 2, z, 1.4, 14, { Name = "Coluna", Color = COR.marmore })
	end
	local console =
		cilindroLocal(pasta, olhar, 0, 2, 0, 2, 2.8, { Name = "Console", Color = COR.pedra })
	interacao(console, "indice", "Abrir índice", "Arquivo dos Ecos")
	placa(
		pasta,
		(olhar * CFrame.new(0, 32, 0)).Position,
		"Arquivo dos Ecos",
		"Coleção de auras",
		COR.energia
	)
end

local function construirObelisco(pasta: Instance)
	local olhar = referencia("obelisco")
	for i, lado in { 26, 20, 14 } do
		caixaLocal(pasta, olhar, 0, 0.6 + 1.2 * (i - 1), 0, Vector3.new(lado, 1.2, lado), 0, {
			Name = "ObeliscoBase" .. i,
			Color = COR.pedra,
		})
	end
	caixaLocal(
		pasta,
		olhar,
		0,
		18.6,
		0,
		Vector3.new(5.6, 30, 5.6),
		0,
		{ Name = "Obelisco", Color = COR.pedra }
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			caixaLocal(pasta, olhar, sx * 15.5, 4.3, sz * 15.5, Vector3.new(2.6, 8.6, 2.6), 0, {
				Name = "Pilone",
				Color = COR.pedra,
			})
		end
	end
	-- Moldura de pedra em volta do painel (mesmas medidas da peça 3D)
	for _, sx in { -1, 1 } do
		caixaLocal(
			pasta,
			olhar,
			sx * 7.9,
			5.3,
			-17,
			Vector3.new(1.6, 10.6, 1.6),
			0,
			{ Name = "Moldura" }
		)
	end
	caixaLocal(pasta, olhar, 0, 0.8, -17, Vector3.new(18, 1.6, 2.4), 0, { Name = "MolduraBase" })
	-- Painel do ranking, virado para a praça
	local painel = caixaLocal(pasta, olhar, 0, 6.2, -17.2, Vector3.new(14, 8, 0.6), 0, {
		Name = "PainelRanking",
		Color = Color3.fromHex("0B0A10"),
		Material = Enum.Material.SmoothPlastic,
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
		(olhar * CFrame.new(0, 45, 0)).Position,
		"Obelisco das Lendas",
		"Ranking do servidor",
		COR.ouro
	)
end

local ECOS = {
	'Um sussurro antigo: "Todo poder dorme até ser chamado."',
	'O fragmento vibra: "Nem toda luz que desperta quer ser contida."',
	'Uma voz distante: "O Nexo se lembra de cada ruptura."',
}

local function construirJardim(pasta: Instance)
	local olhar = referencia("jardim")
	cilindroLocal(pasta, olhar, 0, 0, 0, 32, 0.5, {
		Name = "JardimChao",
		Color = Color3.fromHex("1E2A26"),
		Material = Enum.Material.Grass,
	})
	-- Árvores, ruínas e muro: colisão em construirColisoresKit (dados gerados pelo Blender)
	-- Eco oculto atrás do muro em ruínas: só curiosidade, sem recompensa
	local fragmento = peca(
		pasta,
		neon({
			Name = "FragmentoSussurrante",
			Color = COR.ouro,
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = olhar
				* CFrame.new(-6, 1.9, 22.5)
				* CFrame.Angles(math.rad(45), 0, math.rad(45)),
		})
	)
	luz(fragmento, COR.ouro, 16, 2)
	local rng = Random.new(23)
	interacao(fragmento, "eco", "Ouvir", "Fragmento sussurrante", ECOS[rng:NextInteger(1, #ECOS)])
	placa(pasta, (olhar * CFrame.new(0, 18, 0)).Position, "Jardim dos Fragmentos", nil, COR.jade)
end

local function construirAltar(pasta: Instance)
	local olhar = referencia("altar")
	for i, raio in { 16, 12, 8 } do
		cilindroLocal(
			pasta,
			olhar,
			0,
			i - 1,
			0,
			raio,
			1,
			{ Name = "AltarDegrau", Color = COR.pedra }
		)
	end
	for i = 0, 5 do
		local a = 30 + 60 * i
		local x, z = polar(19.5, a)
		caixaLocal(
			pasta,
			olhar,
			x,
			7,
			z,
			Vector3.new(2.7, 14, 1.9),
			-a,
			{ Name = "Monolito", Color = COR.pedra }
		)
	end
	local mesa =
		cilindroLocal(pasta, olhar, 0, 3, 0, 2, 2.8, { Name = "AltarMesa", Color = COR.pedra })
	interacao(
		mesa,
		"em_construcao",
		"Em construção",
		"Altar da Ressonância",
		"O Altar da Ressonância ainda está em construção."
	)
	placa(
		pasta,
		(olhar * CFrame.new(0, 24, 0)).Position,
		"Altar da Ressonância",
		"Em construção",
		COR.violeta
	)
end

local function construirPortais(pasta: Instance)
	local olhar = referencia("portais")
	cilindroLocal(pasta, olhar, 0, 0, 0, 22, 0.8, { Name = "PortaisBase", Color = COR.pedra })
	local cores = { COR.violeta, COR.energia, COR.selo }
	for i, b in { -38, 0, 38 } do
		local quebrado = b == -38
		local x, z = math.sin(math.rad(b)) * 10, math.cos(math.rad(b)) * 10
		-- referencial do portal: frente virada para o centro do lugar
		local portal = olhar * CFrame.new(x, 0.8, z) * CFrame.Angles(0, math.rad(b), 0)
		for _, lado in { -1, 1 } do
			local alto = if quebrado and lado == 1 then 6.5 else 12
			peca(pasta, {
				Name = "PortalPilar",
				Color = COR.pedra,
				Size = Vector3.new(2.4, alto, 2.4),
				CFrame = portal * CFrame.new(lado * 5, alto / 2, 0),
			})
		end
		local veu = peca(pasta, {
			Name = "PortalVeu",
			Material = Enum.Material.ForceField,
			Color = cores[i],
			CanCollide = false,
			CastShadow = false,
			Size = Vector3.new(7.4, if quebrado then 12 else 17.4, 0.3),
			CFrame = portal * CFrame.new(0, if quebrado then 6 else 8.7, 0),
		})
		luz(veu, cores[i], 22, 1.8)
		if b == 0 then
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
		(olhar * CFrame.new(0, 25, 4)).Position,
		"Portais Fragmentados",
		"Em construção",
		COR.violeta
	)
end

local function construirArena(pasta: Instance)
	local olhar = referencia("arena")
	cilindroLocal(pasta, olhar, 0, 0, 0, 24, 0.5, { Name = "ArenaPiso", Color = COR.pedraClara })
	-- Arquibancada em arco de 240 graus, aberta para a praça (mesmas medidas do modelo)
	local segmentos = 16
	for degrau = 1, 3 do
		local r0, r1 = 24.5 + 3 * (degrau - 1), 24.5 + 3 * degrau
		local raio = (r0 + r1) / 2
		for k = 0, segmentos - 1 do
			local a = 60 + 240 * (k + 0.5) / segmentos
			local x, z = polar(raio, a)
			local largura = 2 * math.pi * raio * (240 / 360) / segmentos + 0.4
			caixaLocal(
				pasta,
				olhar,
				x,
				0.7 * degrau,
				z,
				Vector3.new(largura, 1.4 * degrau, 3),
				-a,
				{
					Name = "Arquibancada",
					Color = COR.pedra,
				}
			)
		end
	end
	for k = 0, 7 do
		local x, z = polar(35.5, 67.5 + k * (225 / 7))
		cilindroLocal(pasta, olhar, x, 0, z, 1.4, 14, { Name = "ArenaColuna", Color = COR.marmore })
	end
	-- Arena do Trono: degraus, trono, portão e braseiros têm a colisão em NexoColisores (gerada
	-- junto com os modelos). Aqui ficam só as luzes baixas dos braseiros e a placa.
	for _, a in { 48, 132, 228, 312 } do
		local x, z = polar(21.2, a)
		local ancora = peca(pasta, {
			Name = "LuzBraseiro",
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Size = Vector3.new(1, 1, 1),
			CFrame = olhar * CFrame.new(x, 5, z),
		})
		luz(ancora, COR.selo, 18, 1.4)
	end
	local trono = peca(pasta, {
		Name = "LuzTrono",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Size = Vector3.new(1, 1, 1),
		CFrame = olhar * CFrame.new(0, 9, 15),
	})
	luz(trono, COR.selo, 26, 1.2)
	placa(
		pasta,
		(olhar * CFrame.new(0, 26, 19)).Position,
		"Arena do Trono",
		"Duelos por turnos — em desenvolvimento",
		COR.selo
	)
end

-- Bastião das Incursões: base de preparação para expedições a universos destruídos, entre os
-- Portais e a Arena. Mesmos valores de BASTIAO em assets/nexo/source/generate_nexo.py.
-- A Mesa dos Cartógrafos abre o painel das Incursões (src/server/Incursoes).
local BASTIAO = { graus = 157, dist = 173 }

local function construirBastiao(pasta: Instance)
	local centro = direcao(BASTIAO.graus) * BASTIAO.dist
	local olhar = CFrame.lookAt(centro, Vector3.zero)
	cilindroLocal(pasta, olhar, 0, 0, 0, 20.5, 0.8, { Name = "BastiaoBase", Color = COR.pedra })
	-- ramal que sai da borda dos Portais (reserva visual; o chão já é plano)
	local portais = direcao(LOCAIS.portais.graus) * LOCAIS.portais.dist
	local rumo = (centro - portais).Unit
	local meio = centro - rumo * (21.3 + 11)
	peca(pasta, {
		Name = "Caminho",
		Color = COR.caminho,
		Material = Enum.Material.Cobblestone,
		Size = Vector3.new(10, 0.4, 22),
		CFrame = CFrame.lookAt(meio + Vector3.new(0, 0.1, 0), centro + Vector3.new(0, 0.1, 0)),
	})
	-- luz fria da fenda
	local fenda = peca(pasta, {
		Name = "LuzFenda",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Size = Vector3.new(1, 1, 1),
		CFrame = olhar * CFrame.new(0, 9, 8),
	})
	luz(fenda, COR.energia, 30, 1.6)
	-- Mesa dos Cartógrafos: só informa o que vem (o texto não promete recompensa nem data)
	local mesa = peca(pasta, {
		Name = "MesaCartografos",
		Transparency = 1,
		CanCollide = false,
		Size = Vector3.new(2, 2, 2),
		CFrame = olhar * CFrame.new(0, 3.2, -3),
	})
	interacao(mesa, "incursoes", "Planejar incursão", "Mesa dos Cartógrafos")
	placa(
		pasta,
		(olhar * CFrame.new(0, 29, 11)).Position,
		"Bastião das Incursões",
		"Expedições a universos em ruína",
		COR.energia
	)
end

local function configurarCeu()
	-- Noite estilizada, mas clara: ambiente mais alto e exposição levantada para que o mapa
	-- seja legível sem depender de muitas PointLights (custo baixo no celular)
	Lighting.ClockTime = 0
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.35
	Lighting.Ambient = Color3.fromHex("5E5584")
	Lighting.OutdoorAmbient = Color3.fromHex("7C74B4")
	Lighting.ColorShift_Top = Color3.fromHex("A898F0")
	Lighting.ColorShift_Bottom = Color3.fromHex("3A3060")
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.FogEnd = 100000
	for _, filho in Lighting:GetChildren() do
		if
			filho:IsA("Sky")
			or filho:IsA("Atmosphere")
			or filho.Name == "NexoBloom"
			or filho.Name == "NexoCor"
		then
			filho:Destroy()
		end
	end
	local ceu = Instance.new("Sky")
	ceu.StarCount = 5000
	ceu.CelestialBodiesShown = false
	ceu.Parent = Lighting
	local atmosfera = Instance.new("Atmosphere")
	atmosfera.Density = 0.3
	atmosfera.Offset = 0.2
	atmosfera.Color = Color3.fromHex("6C5FA8")
	atmosfera.Decay = Color3.fromHex("1A1030")
	atmosfera.Glare = 0
	atmosfera.Haze = 2
	atmosfera.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "NexoBloom"
	bloom.Intensity = 0.6
	bloom.Size = 22
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
	-- Leve ganho de brilho e saturação para as cores do mapa não ficarem lavadas
	local cor = Instance.new("ColorCorrectionEffect")
	cor.Name = "NexoCor"
	cor.Brightness = 0.05
	cor.Contrast = 0.08
	cor.Saturation = 0.12
	cor.Parent = Lighting
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
	construirLimite(pasta)
	construirBordaProvisoria(pasta)
	construirPraca(pasta)
	construirNucleo(pasta)
	construirCaminhos(pasta)
	construirObelisco(pasta)
	construirArquivo(pasta)
	construirJardim(pasta)
	construirAltar(pasta)
	construirPortais(pasta)
	construirArena(pasta)
	construirBastiao(pasta)
	construirColisoresKit(pasta)
	-- Tudo o que tem forma básica é PROVISÓRIO: cada cliente monta por cima o kit 3D
	-- (src/client/Mundo/Nexo3D) e esconde estas peças, que continuam servindo de colisão.
	-- Se o kit falhar em algum cliente, elas seguem visíveis (fallback temporário).
	for _, inst in pasta:GetDescendants() do
		if inst:IsA("BasePart") and not KIT_MANTEM[inst.Name] then
			inst:SetAttribute("Provisorio", true)
		end
	end

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
