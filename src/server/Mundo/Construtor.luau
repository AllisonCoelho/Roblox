-- Constrói o mundo a partir da planta (Shared/Dados/Mapa.luau).
-- Tudo é criado por código porque o deploy recria o jogo inteiro a partir do repositório:
-- nada feito à mão no Studio sobreviveria ao próximo merge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Mapa = require(Shared.Dados.Mapa)
local Esteira = require(Shared.Dados.Esteira)

local Cores = Tema.Cores
local Construtor = {}

local function peca(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- Cilindro em pé: no Roblox o cilindro fica deitado no eixo X
local function cilindro(
	props: { [string]: any },
	centro: CFrame,
	altura: number,
	diametro: number
): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(altura, diametro, diametro)
	props.CFrame = centro * CFrame.Angles(0, 0, math.rad(90))
	return peca(props)
end

-- Placa flutuante com texto estilo da interface (fonte, contorno)
function Construtor.placa(
	pai: Instance,
	texto: string,
	op: { [string]: any }?
): (BillboardGui, TextLabel, TextLabel)
	local o = op or {}
	local gui = Instance.new("BillboardGui")
	gui.Name = o.nome or "Placa"
	gui.Size = o.tamanho or UDim2.fromOffset(260, 80)
	gui.StudsOffset = o.deslocamento or Vector3.new(0, 4, 0)
	gui.MaxDistance = o.distancia or 120
	gui.AlwaysOnTop = o.sempreVisivel == true
	gui.LightInfluence = 0
	local titulo = Instance.new("TextLabel")
	titulo.Name = "Titulo"
	titulo.BackgroundTransparency = 1
	titulo.Size = UDim2.fromScale(1, 0.6)
	titulo.Font = Tema.Fonte
	titulo.TextScaled = true
	titulo.TextColor3 = o.cor or Cores.Branco
	titulo.Text = texto
	local contorno = Instance.new("UIStroke")
	contorno.Color = Cores.Contorno
	contorno.Thickness = 2
	contorno.Parent = titulo
	titulo.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Font = Tema.Fonte
	sub.TextScaled = true
	sub.TextColor3 = o.corSub or Cores.OuroClaro
	sub.Text = o.sub or ""
	local contornoSub = contorno:Clone()
	contornoSub.Parent = sub
	sub.Parent = gui
	gui.Parent = pai
	return gui, titulo, sub
end

local function pirulito(pai: Instance, base: Vector3, altura: number, cor: Color3)
	cilindro(
		{ Color = Cores.Branco, Parent = pai, CanCollide = true },
		CFrame.new(base + Vector3.new(0, altura / 2, 0)),
		altura,
		1.2
	)
	local topo = peca({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (altura * 0.45),
		Color = cor,
		Material = Enum.Material.Glass,
		Position = base + Vector3.new(0, altura, 0),
		Parent = pai,
	})
	topo.Transparency = 0.1
end

local function construirFabrica(pasta: Folder)
	local f = Mapa.Fabrica
	local c = f.centro + Vector3.new(0, f.tamanho.Y / 2, 0)
	local corpo = peca({
		Name = "Fabrica",
		Size = f.tamanho,
		Position = c,
		Color = Cores.Rosa,
		Parent = pasta,
	})
	-- Toldo listrado na frente
	local listras = 11
	local larguraListra = f.tamanho.X / listras
	for i = 0, listras - 1 do
		peca({
			Size = Vector3.new(larguraListra, 2, 6),
			Position = Vector3.new(
				f.centro.X - f.tamanho.X / 2 + larguraListra * (i + 0.5),
				f.tamanho.Y + 1,
				f.centro.Z + f.tamanho.Z / 2 - 2
			),
			Color = if i % 2 == 0 then Cores.Branco else Cores.Rosa,
			Parent = pasta,
		})
	end
	-- Porta escura por onde a esteira sai
	peca({
		Size = Vector3.new(Mapa.Esteira.largura + 4, 12, 1),
		Position = Vector3.new(Mapa.Esteira.inicio.X, 6, f.centro.Z + f.tamanho.Z / 2 + 0.3),
		Color = Cores.Contorno,
		Parent = pasta,
	})
	for _, x in { -14, 14 } do
		cilindro(
			{ Color = Cores.CinzaClaro, Parent = pasta },
			CFrame.new(f.centro.X + x, f.tamanho.Y + 6, f.centro.Z - 3),
			12,
			4
		)
	end
	Construtor.placa(corpo, "Fábrica de Docinhos", {
		tamanho = UDim2.fromOffset(420, 110),
		deslocamento = Vector3.new(0, f.tamanho.Y / 2 + 8, 0),
		sub = "os Docinhos saem daqui",
		distancia = 250,
	})
end

local function construirEsteira(pasta: Folder)
	local e = Mapa.Esteira
	local comprimento = Esteira.comprimento()
	local meio = (e.inicio + e.fim) / 2
	local cf = CFrame.lookAt(meio, meio + (e.fim - e.inicio).Unit)
	peca({
		Name = "Esteira",
		Size = Vector3.new(e.largura, 1, comprimento),
		CFrame = cf + Vector3.new(0, e.altura - 0.5, 0),
		Color = Color3.fromHex("4A3D5C"),
		Parent = pasta,
	})
	-- Corrimões e pés
	for _, lado in { -1, 1 } do
		peca({
			Size = Vector3.new(0.8, 1.6, comprimento),
			CFrame = cf * CFrame.new(lado * (e.largura / 2 + 0.4), e.altura - 0.2, 0),
			Color = Cores.CinzaClaro,
			Parent = pasta,
		})
		for z = -comprimento / 2 + 4, comprimento / 2 - 4, 12 do
			peca({
				Size = Vector3.new(1, e.altura - 1, 1),
				CFrame = cf * CFrame.new(lado * (e.largura / 2 - 1), (e.altura - 1) / 2, z),
				Color = Cores.Contorno,
				Parent = pasta,
			})
		end
	end
	-- Faixas claras na esteira (mostram o sentido)
	for z = -comprimento / 2 + 3, comprimento / 2 - 3, 6 do
		peca({
			Size = Vector3.new(e.largura - 2, 0.1, 0.6),
			CFrame = cf * CFrame.new(0, e.altura + 0.02, z),
			Color = Color3.fromHex("6B5C80"),
			CanCollide = false,
			Parent = pasta,
		})
	end
	-- Funil no fim, onde os Docinhos não comprados somem
	peca({
		Size = Vector3.new(e.largura + 4, e.altura + 2, 4),
		Position = e.fim + Vector3.new(0, (e.altura + 2) / 2, 3),
		Color = Cores.Uva,
		Parent = pasta,
	})
end

local function construirLote(pasta: Folder, indice: number): Model
	local W, D = Mapa.LoteLargura, Mapa.LoteProfundidade
	local base = Mapa.cframeLote(indice)
	local modelo = Instance.new("Model")
	modelo.Name = "Vitrine" .. indice
	modelo:SetAttribute("Indice", indice)
	modelo:SetAttribute("Dono", 0)

	local chao = peca({
		Name = "Chao",
		Size = Vector3.new(W, 0.4, D),
		CFrame = base + Vector3.new(0, 0.2, 0),
		Color = Color3.fromHex("FFD6EC"),
		Parent = modelo,
	})
	peca({
		Name = "Fundo",
		Size = Vector3.new(W, 12, 1),
		CFrame = base * CFrame.new(0, 6, D / 2),
		Color = Cores.Creme,
		Parent = modelo,
	})
	for _, lado in { -1, 1 } do
		-- Altas o bastante para não pular por cima (o pulo padrão chega a ~7 studs)
		peca({
			Size = Vector3.new(1, 10, D),
			CFrame = base * CFrame.new(lado * W / 2, 5, 0),
			Color = Cores.Creme,
			Parent = modelo,
		})
	end
	-- Toldo listrado no alto da parede do fundo
	local listras = 8
	for i = 0, listras - 1 do
		peca({
			Size = Vector3.new(W / listras, 1.4, 5),
			CFrame = base * CFrame.new(-W / 2 + W / listras * (i + 0.5), 12.4, D / 2 - 2),
			Color = if i % 2 == 0 then Cores.Rosa else Cores.Branco,
			Parent = modelo,
		})
	end
	local placa = peca({
		Name = "Placa",
		Size = Vector3.new(16, 4, 1),
		CFrame = base * CFrame.new(0, 15, D / 2),
		Color = Cores.Ouro,
		Parent = modelo,
	})
	Construtor.placa(placa, "Vitrine livre", {
		nome = "Letreiro",
		tamanho = UDim2.fromOffset(320, 90),
		deslocamento = Vector3.new(0, 4, 0),
		sub = "",
		distancia = 200,
	})

	local pedestais = Instance.new("Folder")
	pedestais.Name = "Pedestais"
	pedestais.Parent = modelo
	for i = 1, Mapa.PedestalColunas * Mapa.PedestalLinhas do
		local p = cilindro({
			Name = "Pedestal" .. i,
			Color = Cores.CinzaClaro,
			Transparency = 1,
			CanCollide = false,
			Parent = pedestais,
		}, base * CFrame.new(Mapa.pedestalLocal(i) + Vector3.new(0, 0.9, 0)), 1, 3.4)
		p:SetAttribute("Indice", i)
	end

	local caixa = cilindro(
		{ Name = "Caixa", Color = Cores.Menta, Material = Enum.Material.Neon, Parent = modelo },
		base * CFrame.new(Mapa.CaixaLocal + Vector3.new(0, 0.6, 0)),
		0.4,
		6
	)
	caixa.CanCollide = false
	Construtor.placa(
		caixa,
		"COLETAR",
		{ nome = "Rotulo", deslocamento = Vector3.new(0, 4, 0), sub = "🪙 0", distancia = 60 }
	)
	local escudo = cilindro(
		{ Name = "Escudo", Color = Cores.Ceu, Material = Enum.Material.Neon, Parent = modelo },
		base * CFrame.new(Mapa.EscudoLocal + Vector3.new(0, 0.6, 0)),
		0.4,
		6
	)
	escudo.CanCollide = false
	Construtor.placa(
		escudo,
		"🛡️ ESCUDO",
		{ nome = "Rotulo", deslocamento = Vector3.new(0, 4, 0), sub = "desligado", distancia = 60 }
	)

	-- Portão de laser: com o escudo ligado aparece e bloqueia todos menos o dono (Servicos/Lotes.luau)
	peca({
		Name = "Portao",
		Size = Vector3.new(W - 2, 10, 0.6),
		CFrame = base * CFrame.new(0, 5, -D / 2),
		Color = Cores.Ceu,
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		Parent = modelo,
	})
	peca({
		Name = "Entrada",
		Size = Vector3.new(4, 1, 4),
		CFrame = base
			* CFrame.new(Mapa.EntradaLocal + Vector3.new(0, 0.5, 0))
			* CFrame.Angles(0, math.rad(180), 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = modelo,
	})

	local docinhos = Instance.new("Folder")
	docinhos.Name = "Docinhos"
	docinhos.Parent = modelo

	modelo.PrimaryPart = chao
	modelo.WorldPivot = base
	modelo.Parent = pasta
	return modelo
end

local function construirPraca(pasta: Folder)
	peca({
		Name = "Praca",
		Size = Vector3.new(150, 0.2, 30),
		Position = Vector3.new(0, 0.1, Mapa.Nascimento.Z),
		Color = Color3.fromHex("FFE7A3"),
		CanCollide = true,
		Parent = pasta,
	})
	for _, p in Mapa.Praca do
		local tam = Mapa.PredioTamanho
		local par = Tema.Botoes[p.cor] or Tema.Botoes.rosa
		local predio = peca({
			Name = p.id,
			Size = tam,
			Position = p.centro + Vector3.new(0, tam.Y / 2, 0),
			Color = par[2],
			Parent = pasta,
		})
		peca({
			Size = Vector3.new(tam.X + 2, 1.5, tam.Z + 2),
			Position = p.centro + Vector3.new(0, tam.Y + 0.75, 0),
			Color = par[1],
			Parent = pasta,
		})
		Construtor.placa(predio, p.icone .. " " .. p.nome, {
			tamanho = UDim2.fromOffset(300, 90),
			deslocamento = Vector3.new(0, tam.Y / 2 + 4, 0),
			sub = if p.tela then "chegue perto e aperte E" else "Chuva de Doces · sábado 15h",
			distancia = 160,
		})
		if p.tela then
			-- Ponto de toque na frente do prédio (virada para o norte, onde o jogador chega)
			local ponto = peca({
				Name = "Toque",
				Size = Vector3.new(4, 4, 1),
				Position = p.centro + Vector3.new(0, 3, -tam.Z / 2 - 0.6),
				Transparency = 1,
				CanCollide = false,
				Parent = predio,
			})
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Abrir"
			prompt.ObjectText = p.nome
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Tela", p.tela)
			prompt.Parent = ponto
		end
	end
end

local function decorar(pasta: Folder)
	local cores = { Cores.Rosa, Cores.Ceu, Cores.Menta, Cores.Uva, Cores.Ouro }
	local pontos = {
		Vector3.new(-105, 0, -105),
		Vector3.new(105, 0, -105),
		Vector3.new(-105, 0, 70),
		Vector3.new(105, 0, 70),
		Vector3.new(-30, 0, -100),
		Vector3.new(30, 0, -100),
		Vector3.new(-100, 0, 110),
		Vector3.new(100, 0, 110),
	}
	for i, ponto in pontos do
		pirulito(pasta, ponto, 14 + (i % 3) * 4, cores[(i - 1) % #cores + 1])
	end
end

-- Cria o mundo. Devolve a pasta das vitrines (workspace.Vitrines).
function Construtor.construir(): Folder
	local antigo = workspace:FindFirstChild("Mapa")
	if antigo then
		antigo:Destroy()
	end
	local mapa = Instance.new("Folder")
	mapa.Name = "Mapa"
	construirFabrica(mapa)
	construirEsteira(mapa)
	construirPraca(mapa)
	decorar(mapa)
	mapa.Parent = workspace

	local vitrines = workspace:FindFirstChild("Vitrines") or Instance.new("Folder")
	vitrines.Name = "Vitrines"
	vitrines:ClearAllChildren()
	for i = 1, #Mapa.Lotes do
		construirLote(vitrines :: Folder, i)
	end
	vitrines.Parent = workspace

	local itens = workspace:FindFirstChild("Esteira") or Instance.new("Folder")
	itens.Name = "Esteira"
	itens:ClearAllChildren()
	itens.Parent = workspace

	local chuva = workspace:FindFirstChild("Chuva") or Instance.new("Folder")
	chuva.Name = "Chuva"
	chuva:ClearAllChildren()
	chuva.Parent = workspace

	Lighting.ClockTime = 14
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 190)
	return vitrines :: Folder
end

return Construtor
