-- Evento Despertar do Sol no mundo (só visual; regras em Shared/Dados/EventoSol e o chefe no
-- servidor). O servidor cria uma peça invisível "Tita" em Workspace.EventoSol com os atributos
-- Vida, VidaMax, SurgiuEm, AtingidoEm, AtaqueEm, Derrotado e FimEm. Aqui cada cliente monta o
-- Titã de Borracha feito no Blender (Dados/TitaVisual) em cima dela e anima:
--   chegada    cai do céu e quica, com onda de choque
--   parado     respira, balança, a auréola gira (esticado como borracha)
--   golpe      achata e estica quando leva dano; orbes saem de quem bateu
--   onda       ergue os braços esticados (1 s de aviso) e bate no chão: anel dourado
--   derrota    gira, encolhe e vira uma chuva de luz
-- Também põe o sol sorridente e as nuvens no céu enquanto o evento dura (Ciclo.fatorEvento).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visual = require(Shared:WaitForChild("Dados"):WaitForChild("TitaVisual"))
local Remotos = require(Shared:WaitForChild("Remotos"))
local Malha = require(script.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))
local Ciclo = require(script.Parent:WaitForChild("Ciclo"))
local Sons = require(script.Parent:WaitForChild("Sons"))

local Mundo = {}

type Peca = {
	nome: string,
	junta: Vector3,
	camadas: { { parte: MeshPart, centro: Vector3, tamanho: Vector3 } },
}

local OURO = Color3.fromHex("FFD54A")
local BRANCO = Color3.fromHex("FFFFFF")
local ALTURA = 26 -- altura da peça do servidor (os pés ficam na base dela)

local pasta: Folder
local modelo: Model? = nil
local pecas: { [string]: Peca } = {}
local contorno: Highlight? = nil
local tita: BasePart? = nil
local movimentoReduzido = false

-- ============================================================ montagem do Titã

local function montar(): boolean
	if modelo then
		return true
	end
	local prontas: Malha.Cache = {}
	local m = Instance.new("Model")
	m.Name = "TitaDeBorracha"
	for _, p in Visual :: { any } do
		local peca: Peca = {
			nome = p.nome,
			junta = Vector3.new(p.junta[1], p.junta[2], p.junta[3]),
			camadas = {},
		}
		for _, c in p.camadas do
			local ok, parte, centro = pcall(Malha.criar, c.malha, prontas)
			if ok then
				parte.Material = (Enum.Material :: any)[c.material] or Enum.Material.SmoothPlastic
				parte.Anchored = true
				parte.CanCollide = false
				parte.CanQuery = false
				parte.CanTouch = false
				parte.CastShadow = c.material ~= "Neon"
				parte.Parent = m
				table.insert(peca.camadas, { parte = parte, centro = centro, tamanho = parte.Size })
			else
				warn("[EventoSol] malha " .. tostring(c.malha) .. ": " .. tostring(parte))
			end
		end
		pecas[p.nome] = peca
	end
	if next(m:GetChildren()) == nil then
		m:Destroy()
		return false
	end
	local h = Instance.new("Highlight")
	h.FillTransparency = 1
	h.OutlineColor = OURO
	h.OutlineTransparency = 0.15
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = m
	contorno = h
	m.Parent = pasta
	modelo = m
	return true
end

local function esconder()
	if modelo then
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end
		if contorno then
			contorno.Enabled = false
		end
	end
end

-- Põe a peça no lugar: `base` = pés do Titã; `escala` estica o corpo todo como borracha
local function posicionar(
	nome: string,
	base: CFrame,
	escala: Vector3,
	giro: CFrame,
	esticar: number?,
	alpha: number
)
	local peca = pecas[nome]
	if not peca then
		return
	end
	local junta = peca.junta * escala
	local estica = esticar or 1
	for _, c in peca.camadas do
		local tamanho = c.tamanho * escala * Vector3.new(1, estica, 1)
		if (c.parte.Size - tamanho).Magnitude > 0.01 then
			c.parte.Size = tamanho
		end
		c.parte.CFrame = base
			* CFrame.new(junta)
			* giro
			* CFrame.new(c.centro * escala * Vector3.new(1, estica, 1))
		c.parte.LocalTransparencyModifier = alpha
	end
end

-- ============================================================ efeitos

local function anel(centro: Vector3, raio: number, cor: Color3, duracao: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = cor
	p.Transparency = 0.15
	p.Size = Vector3.new(0.6, 4, 4)
	p.CFrame = CFrame.new(centro + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = pasta
	local tw = TweenService:Create(
		p,
		TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.3, raio * 2, raio * 2), Transparency = 1 }
	)
	tw:Play()
	tw.Completed:Once(function()
		p:Destroy()
	end)
end

local function faiscas(centro: Vector3, quantidade: number, cor: Color3)
	local a = Instance.new("Attachment")
	a.WorldPosition = centro
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(cor, BRANCO)
	e.LightEmission = 1
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(20, 45)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Enabled = false
	e.Parent = a
	e:Emit(quantidade)
	task.delay(2, function()
		a:Destroy()
	end)
end

-- Orbe de aura que sai de quem bateu e voa até o Titã, com o número do dano
local orbesAtivos = 0
local function orbe(de: Player?, alvo: Vector3, dano: number, meu: boolean)
	if orbesAtivos > 24 then
		return
	end
	local origem = alvo + Vector3.new(math.random(-20, 20), 4, 24)
	local personagem = de and de.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		origem = raiz.Position
	end
	orbesAtivos += 1
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = if meu then OURO else Color3.fromHex("FFF3C4")
	p.Size = Vector3.one * (if meu then 1.8 else 1.1)
	p.Parent = pasta
	local destino = alvo + Vector3.new(math.random(-4, 4), math.random(-4, 6), math.random(-2, 2))
	local inicio = os.clock()
	local duracao = 0.35
	local con
	con = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - inicio) / duracao, 0, 1)
		local arco = Vector3.new(0, math.sin(t * math.pi) * 6, 0)
		p.Position = origem:Lerp(destino, t) + arco
		if t >= 1 then
			con:Disconnect()
			p:Destroy()
			orbesAtivos -= 1
			if meu then
				faiscas(destino, 8, OURO)
			end
		end
	end)
	-- número do dano (só o meu, grande; os outros pequenos e com menos frequência)
	if meu or math.random() < 0.3 then
		local ponto = Instance.new("Attachment")
		ponto.WorldPosition = destino
		ponto.Parent = Workspace.Terrain
		local b = Instance.new("BillboardGui")
		b.Size = UDim2.fromOffset(if meu then 160 else 90, if meu then 48 else 28)
		b.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
		b.AlwaysOnTop = true
		b.LightInfluence = 0
		b.MaxDistance = 220
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = "-" .. tostring(math.floor(dano))
		t.TextColor3 = if meu then OURO else BRANCO
		t.TextStrokeColor3 = Color3.fromHex("5A3200")
		t.TextStrokeTransparency = 0.1
		t.Parent = b
		b.Parent = ponto
		local tw = TweenService:Create(
			b,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ StudsOffsetWorldSpace = Vector3.new(math.random(-3, 3), 9, 0) }
		)
		tw:Play()
		TweenService
			:Create(t, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
		task.delay(0.95, function()
			ponto:Destroy()
		end)
	end
end

-- Tremor de câmera de quem está perto (respeita "movimento reduzido")
local tremorAte = 0
local tremorForca = 0
local function tremer(forca: number, duracao: number)
	if movimentoReduzido then
		return
	end
	tremorForca = math.max(tremorForca, forca)
	tremorAte = math.max(tremorAte, os.clock() + duracao)
end

-- ============================================================ céu do evento

local ceu: Folder? = nil
local nuvens: { { parte: BasePart, base: Vector3, fase: number } } = {}
local sol: BillboardGui? = nil
local raios: Frame? = nil

local function bola(pai: Instance, pos: Vector3, tamanho: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = BRANCO
	p.Size = Vector3.one * tamanho
	p.Position = pos
	p.Parent = pai
	return p
end

local function circulo(pai: Instance, tamanho: UDim2, pos: UDim2, cor: Color3): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = tamanho
	f.Position = pos
	f.BackgroundColor3 = cor
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = pai
	return f
end

local function montarCeu()
	local f = Instance.new("Folder")
	f.Name = "CeuDoSol"
	-- nuvens fofas em volta da praça
	local g = Random.new(7)
	for i = 1, 14 do
		local ang = (i / 14) * math.pi * 2 + g:NextNumber(-0.2, 0.2)
		local raio = g:NextNumber(150, 260)
		local centro =
			Vector3.new(math.sin(ang) * raio, g:NextNumber(110, 170), -math.cos(ang) * raio)
		for _ = 1, 5 do
			local off = Vector3.new(g:NextNumber(-14, 14), g:NextNumber(-3, 5), g:NextNumber(-8, 8))
			local p = bola(f, centro + off, g:NextNumber(12, 22))
			table.insert(nuvens, { parte = p, base = centro + off, fase = ang })
		end
	end
	-- sol sorridente bem alto, de frente para a praça
	local ancora = Instance.new("Part")
	ancora.Anchored = true
	ancora.CanCollide = false
	ancora.CanQuery = false
	ancora.CanTouch = false
	ancora.Transparency = 1
	ancora.Size = Vector3.one
	ancora.Position = Vector3.new(0, 230, -380)
	ancora.Parent = f
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromScale(150, 150)
	b.LightInfluence = 0
	b.MaxDistance = 5000
	b.Adornee = ancora
	b.Parent = ancora
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.fromScale(0.5, 0.5)
	r.Size = UDim2.fromScale(1, 1)
	r.Parent = b
	for k = 0, 11 do
		local raio = Instance.new("Frame")
		raio.AnchorPoint = Vector2.new(0.5, 0.5)
		raio.Position = UDim2.fromScale(0.5, 0.5)
		raio.Size = UDim2.fromScale(0.08, if k % 2 == 0 then 1 else 0.85)
		raio.Rotation = k * 15
		raio.BackgroundColor3 = Color3.fromHex("FFE07A")
		raio.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = raio
		raio.Parent = r
	end
	raios = r
	local rosto = circulo(b, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.5, 0.5), OURO)
	local borda = Instance.new("UIStroke")
	borda.Color = BRANCO
	borda.Thickness = 6
	borda.Parent = rosto
	circulo(
		rosto,
		UDim2.fromScale(0.13, 0.2),
		UDim2.fromScale(0.34, 0.38),
		Color3.fromHex("3A2200")
	)
	circulo(
		rosto,
		UDim2.fromScale(0.13, 0.2),
		UDim2.fromScale(0.66, 0.38),
		Color3.fromHex("3A2200")
	)
	circulo(rosto, UDim2.fromScale(0.16, 0.1), UDim2.fromScale(0.2, 0.58), Color3.fromHex("FF9E8A"))
	circulo(rosto, UDim2.fromScale(0.16, 0.1), UDim2.fromScale(0.8, 0.58), Color3.fromHex("FF9E8A"))
	local boca = circulo(
		rosto,
		UDim2.fromScale(0.5, 0.26),
		UDim2.fromScale(0.5, 0.66),
		Color3.fromHex("6A1E1E")
	)
	-- só a metade de baixo do círculo aparece: um sorrisão
	local tampa = Instance.new("Frame")
	tampa.Size = UDim2.fromScale(1.1, 0.5)
	tampa.Position = UDim2.fromScale(-0.05, -0.02)
	tampa.BackgroundColor3 = OURO
	tampa.BorderSizePixel = 0
	tampa.Parent = boca
	sol = b
	f.Parent = pasta
	ceu = f
end

local function atualizarCeu(k: number, agora: number)
	if k <= 0.01 then
		if ceu then
			ceu.Parent = nil
		end
		return
	end
	if not ceu then
		montarCeu()
	end
	local c = ceu :: Folder
	if c.Parent ~= pasta then
		c.Parent = pasta
	end
	local alpha = 1 - k
	for _, n in nuvens do
		local deriva =
			Vector3.new(math.sin(agora * 0.05 + n.fase) * 8, math.sin(agora * 0.3 + n.fase) * 2, 0)
		n.parte.Position = n.base + deriva + Vector3.new(0, (1 - k) * 60, 0)
		n.parte.LocalTransparencyModifier = alpha
	end
	if sol then
		sol.Enabled = k > 0.2
		sol.Size = UDim2.fromScale(150 * (0.6 + 0.4 * k), 150 * (0.6 + 0.4 * k))
	end
	if raios and not movimentoReduzido then
		raios.Rotation = agora * 12
	end
end

-- ============================================================ animação do Titã

local function atributo(t: BasePart, nome: string): number
	return tonumber(t:GetAttribute(nome)) or 0
end

local ultimoAtaque = 0
local ultimaChegada = 0
local derrotaVista = 0

local montando = false
-- Converter as malhas espera na fila do Malha: fora do RenderStep. Começa já no aviso, para o
-- Titã estar pronto quando cair do céu.
local function prepararModelo()
	if not modelo then
		if not montando then
			montando = true
			task.spawn(function()
				local ok, erro = pcall(montar)
				if not ok then
					warn("[EventoSol] montagem: " .. tostring(erro))
				end
				task.wait(5)
				montando = false
			end)
		end
	end
end

local function animar(t: BasePart, agora: number, servidor: number)
	if not modelo then
		prepararModelo()
		return
	end
	if contorno then
		contorno.Enabled = true
	end
	local surgiu = atributo(t, "SurgiuEm")
	local atingido = atributo(t, "AtingidoEm")
	local ataque = atributo(t, "AtaqueEm")
	local fimEm = atributo(t, "FimEm")
	local derrotado = t:GetAttribute("Derrotado") == true

	local pes = t.CFrame * CFrame.new(0, -ALTURA / 2, 0)
	local escala = Vector3.one
	local alpha = 0
	local queda = 0
	local giroCorpo = CFrame.identity
	local bracoD, bracoE = CFrame.Angles(0, 0, math.rad(-12)), CFrame.Angles(0, 0, math.rad(12))
	local esticaBraco = 1

	-- chegada: cai do céu e quica
	local dChegada = servidor - surgiu
	if dChegada < 1.4 then
		local q = math.clamp(dChegada / 0.7, 0, 1)
		queda = (1 - q * q) * 90
		if dChegada > 0.7 then
			local b = (dChegada - 0.7) / 0.7
			local quique = math.sin(b * math.pi * 2.5) * (1 - b)
			escala = Vector3.new(1 + 0.25 * quique, 1 - 0.3 * quique, 1 + 0.25 * quique)
			if ultimaChegada ~= surgiu then
				ultimaChegada = surgiu
				anel(pes.Position, 46, OURO, 0.9)
				anel(pes.Position, 30, BRANCO, 0.6)
				faiscas(pes.Position + Vector3.new(0, 4, 0), 40, OURO)
				Sons.tocar("ruptura", t, 0.6, 0.9)
				tremer(1.2, 0.6)
			end
		end
	else
		-- respirando, balançando como borracha
		local r = math.sin(agora * 2.4)
		escala = Vector3.new(1 + 0.03 * r, 1 - 0.04 * r, 1 + 0.03 * r)
		giroCorpo = CFrame.Angles(0, math.sin(agora * 0.7) * 0.18, math.sin(agora * 1.2) * 0.05)
		bracoD = CFrame.Angles(
			math.sin(agora * 2.4) * 0.25,
			0,
			math.rad(-14) + math.sin(agora * 1.7) * 0.12
		)
		bracoE = CFrame.Angles(
			-math.sin(agora * 2.4) * 0.25,
			0,
			math.rad(14) - math.sin(agora * 1.7) * 0.12
		)
	end

	-- levou golpe: achata e volta (borracha)
	local dGolpe = servidor - atingido
	if dGolpe >= 0 and dGolpe < 0.35 and not movimentoReduzido then
		local s = math.sin(dGolpe / 0.35 * math.pi) * 0.12
		escala *= Vector3.new(1 + s, 1 - s, 1 + s)
	end

	-- onda: 1 s erguendo os braços esticados, depois bate no chão
	local dAtaque = servidor - ataque
	if dAtaque > -1 and dAtaque < 0.6 then
		if dAtaque < 0 then
			local p = 1 + dAtaque -- 0..1
			local sobe = math.rad(170) * p
			bracoD = CFrame.Angles(sobe, 0, math.rad(-10))
			bracoE = CFrame.Angles(sobe, 0, math.rad(10))
			esticaBraco = 1 + 0.8 * p
			escala *= Vector3.new(1 - 0.06 * p, 1 + 0.1 * p, 1 - 0.06 * p)
		else
			local p = math.clamp(dAtaque / 0.15, 0, 1)
			local desce = math.rad(170) * (1 - p) + math.rad(40) * p
			bracoD = CFrame.Angles(desce, 0, math.rad(-10))
			bracoE = CFrame.Angles(desce, 0, math.rad(10))
			esticaBraco = 1.8 - 0.8 * math.clamp(dAtaque / 0.6, 0, 1)
			escala *= Vector3.new(1.1, 0.88, 1.1)
		end
		if dAtaque >= 0 and ultimoAtaque ~= ataque then
			ultimoAtaque = ataque
			anel(pes.Position, 22, OURO, 0.7)
			anel(pes.Position, 14, BRANCO, 0.45)
			faiscas(pes.Position + Vector3.new(0, 2, -6), 30, BRANCO)
			Sons.tocar("ruptura", t, 0.8, 1)
			local raiz = Players.LocalPlayer.Character
				and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") and (raiz.Position - pes.Position).Magnitude < 45 then
				tremer(1.6, 0.5)
			end
		elseif dAtaque < 0 and dAtaque > -0.05 then
			Sons.tocar("instavel", t, 0.7, 0.8)
		end
	end

	-- derrota: gira, encolhe e some numa chuva de luz
	if derrotado and fimEm > 0 then
		local d = math.clamp((servidor - fimEm) / 2.5, 0, 1)
		giroCorpo = CFrame.Angles(0, d * math.pi * 6, 0)
		escala *= (1 - d * 0.9)
		alpha = d
		if derrotaVista ~= fimEm then
			derrotaVista = fimEm
			faiscas(pes.Position + Vector3.new(0, 14, 0), 120, OURO)
			anel(pes.Position, 60, OURO, 1.4)
			anel(pes.Position, 40, BRANCO, 1)
			Sons.tocar("estilhaco", t, 0.7, 1)
			Sons.tocar("revelacao", t, 0.8, 1)
			tremer(1.4, 0.8)
		end
	elseif fimEm > 0 then
		-- escapou: sobe de volta para o céu
		local d = math.clamp((servidor - fimEm) / 2, 0, 1)
		queda = d * d * 120
		alpha = d
	end

	local base = pes * CFrame.new(0, queda, 0) * giroCorpo
	local pulo =
		Vector3.new(0, math.abs(math.sin(agora * 2.4)) * 0.6 * (if dChegada > 1.4 then 1 else 0), 0)
	base *= CFrame.new(pulo)
	local cabecaGiro = CFrame.Angles(
		math.sin(agora * 1.1) * 0.06,
		math.sin(agora * 0.8) * 0.15,
		math.sin(agora * 1.6) * 0.08
	)
	posicionar(
		"pernaD",
		base,
		escala,
		CFrame.Angles(math.sin(agora * 2.4) * 0.08, 0, 0),
		nil,
		alpha
	)
	posicionar(
		"pernaE",
		base,
		escala,
		CFrame.Angles(-math.sin(agora * 2.4) * 0.08, 0, 0),
		nil,
		alpha
	)
	posicionar("tronco", base, escala, CFrame.identity, nil, alpha)
	posicionar("cabeca", base, escala, cabecaGiro, nil, alpha)
	posicionar(
		"cabelo",
		base,
		escala,
		cabecaGiro * CFrame.Angles(0, 0, math.sin(agora * 3) * 0.04),
		nil,
		alpha
	)
	local halo = pecas.halo
	if halo then
		-- a auréola gira em volta do centro da cabeça
		local giroHalo = cabecaGiro
			* CFrame.Angles(0, 0, if movimentoReduzido then 0 else agora * 0.8)
		posicionar("halo", base, escala, giroHalo, nil, alpha)
	end
	posicionar("bracoD", base, escala, bracoD, esticaBraco, alpha)
	posicionar("bracoE", base, escala, bracoE, esticaBraco, alpha)
end

-- ============================================================ ciclo

function Mundo.definir(prefs: { movimentoReduzido: boolean })
	movimentoReduzido = prefs.movimentoReduzido
end

local avisoErro = 0

function Mundo.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "EventoSolVisual"
	pasta.Parent = Workspace
	local servidorPasta = Workspace:WaitForChild("EventoSol", 30)

	Remotos.evento("Evento").OnClientEvent:Connect(function(dados: any)
		if type(dados) ~= "table" or dados.tipo ~= "golpes" or type(dados.lista) ~= "table" then
			return
		end
		local t = tita
		if not t then
			return
		end
		local eu = Players.LocalPlayer.UserId
		for i, g in dados.lista do
			if i > 30 then
				break
			end
			if type(g) == "table" and type(g.de) == "number" and type(g.dano) == "number" then
				orbe(
					Players:GetPlayerByUserId(g.de),
					t.Position + Vector3.new(0, 2, 0),
					g.dano,
					g.de == eu
				)
			end
		end
		Sons.tocar("batida", t, 0.8 + math.random() * 0.4, 0.35)
	end)

	RunService:BindToRenderStep("EventoSol", Enum.RenderPriority.Camera.Value + 2, function()
		local agora = os.clock()
		local servidor = Workspace:GetServerTimeNow()
		local ok, erro = pcall(function()
			local k = Ciclo.fatorEvento()
			atualizarCeu(k, agora)
			if k > 0 then
				prepararModelo()
			end
			local t = servidorPasta and servidorPasta:FindFirstChild("Tita")
			tita = if t and t:IsA("BasePart") then t else nil
			if tita then
				animar(tita, agora, servidor)
			else
				esconder()
			end
			-- tremor de câmera
			if agora < tremorAte then
				local camera = Workspace.CurrentCamera
				local f = tremorForca * (tremorAte - agora)
				camera.CFrame *= CFrame.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, 0)
			else
				tremorForca = 0
			end
		end)
		if not ok and agora > avisoErro then
			avisoErro = agora + 10
			warn("[EventoSol] " .. tostring(erro))
		end
	end)
end

return Mundo
