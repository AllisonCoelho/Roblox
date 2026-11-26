-- Visual dos ataques automáticos da aura (regras e poderes em Shared/Dados/AtaquesAura).
-- O servidor decide os acertos; aqui cada poder ganha uma animação própria com as cores da aura
-- de quem atacou, e cada acerto mostra o número de dano (crítico maior e dourado).
--   estilhaço  lança de cristal que explode em estilhaços
--   vinhas     vinhas brotam do chão e prendem o alvo
--   maré       jato de água em linha com espuma
--   brasa      bola de fogo em arco, explosão e chamas da queimadura
--   corrente   relâmpago que pula de alvo em alvo
--   geada      lança de gelo; o alvo fica preso num bloco de gelo que estilhaça
--   espíritos  três espíritos teleguiados, um depois do outro
--   eco        ondas de som abrindo em cone
--   meteoro    estrelas caem do céu; o golpe forte é um meteoro enorme
--   vazio      esfera negra que suga e explode
--   runas      lâminas de runa girando em arco
--   garras     três cortes em X
--   espada     espada de luz gigante desce do céu
--   punho      o braço estica e o punho cresce até ficar gigante
-- Só Parts, partículas e texturas do próprio Roblox. Respeita "movimento reduzido" (sem tremor).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared:WaitForChild("Dados"):WaitForChild("Auras"))

local Fx = {}

export type Acerto = {
	pos: Vector3,
	atraso: number,
	dano: number,
	critico: boolean?,
	tipo: string, -- "principal" | "area" | "corrente" | "linha" | "queimar"
}
export type Pedido = {
	poder: string,
	origem: Vector3, -- peito de quem atacou
	alvo: Vector3, -- alvo principal
	acertos: { Acerto },
	aura: string?,
	tier: number?,
	forte: boolean?,
	meu: boolean, -- fui eu que ataquei (números maiores, tremor)
	raio: number?, -- área do poder (para o anel)
}

local BRANCO = Color3.new(1, 1, 1)
local OURO = Color3.fromHex("FFD54A")
local pasta: Folder? = nil
local movimentoReduzido = false
local ativos = 0
local LIMITE = 60 -- peças de efeito ao mesmo tempo (acima disso, versão simples)

local function pastaFx(): Folder
	if not pasta or not pasta.Parent then
		local f = Instance.new("Folder")
		f.Name = "AtaquesAura"
		f.Parent = Workspace
		pasta = f
	end
	return pasta :: Folder
end

local function textura(nome: string): string
	return "rbxasset://textures/particles/" .. nome .. ".dds"
end

local function peca(
	forma: Enum.PartType?,
	tamanho: Vector3,
	cor: Color3,
	cf: CFrame,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	if forma then
		p.Shape = forma
	end
	p.Size = tamanho
	p.Color = cor
	p.CFrame = cf
	p.Material = material or Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = pastaFx()
	ativos += 1
	p.Destroying:Once(function()
		ativos -= 1
	end)
	return p
end

local function tw(
	inst: Instance,
	t: number,
	props: { [string]: any },
	estilo: Enum.EasingStyle?,
	direcao: Enum.EasingDirection?
): Tween
	local x = TweenService:Create(
		inst,
		TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out),
		props
	)
	x:Play()
	return x
end

local function sumir(p: BasePart, t: number, props: { [string]: any }?)
	local alvo = props or {}
	alvo.Transparency = 1
	tw(p, t, alvo)
	Debris:AddItem(p, t + 0.05)
end

local function voar(
	p: BasePart,
	de: Vector3,
	ate: Vector3,
	t: number,
	arco: number?,
	aoChegar: (() -> ())?
)
	local inicio = os.clock()
	local rot = p.CFrame.Rotation
	local con
	con = RunService.Heartbeat:Connect(function()
		local k = math.clamp((os.clock() - inicio) / t, 0, 1)
		local pos = de:Lerp(ate, k) + Vector3.new(0, math.sin(k * math.pi) * (arco or 0), 0)
		local dir = (ate - de)
		if dir.Magnitude > 0.01 then
			p.CFrame = CFrame.lookAt(pos, pos + dir) * rot
		else
			p.Position = pos
		end
		if k >= 1 or not p.Parent then
			con:Disconnect()
			if p.Parent and aoChegar then
				aoChegar()
			end
		end
	end)
end

-- Explosão de partículas num ponto
local function estouro(
	pos: Vector3,
	cor: Color3,
	quantidade: number,
	nome: string?,
	velocidade: number?,
	tamanho: number?
)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = textura(nome or "sparkles_main")
	e.Color = ColorSequence.new(cor, BRANCO)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tamanho or 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new((velocidade or 18) * 0.5, velocidade or 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rate = 0
	e.Parent = a
	e:Emit(quantidade)
	Debris:AddItem(a, 1.2)
end

-- Anel achatado que abre no chão
local function anelChao(pos: Vector3, raio: number, cor: Color3, t: number?)
	local p = peca(
		Enum.PartType.Cylinder,
		Vector3.new(0.2, 1, 1),
		cor,
		CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	)
	p.Transparency = 0.2
	sumir(p, t or 0.45, { Size = Vector3.new(0.05, raio * 2, raio * 2) })
end

-- Clarão esférico rápido
local function clarao(pos: Vector3, tamanho: number, cor: Color3, t: number?)
	local p = peca(Enum.PartType.Ball, Vector3.one * tamanho * 0.3, cor, CFrame.new(pos))
	p.Transparency = 0.1
	sumir(p, t or 0.25, { Size = Vector3.one * tamanho })
end

-- Relâmpago em zigue-zague entre dois pontos
local function relampago(de: Vector3, ate: Vector3, cor: Color3, grossura: number?)
	local anterior = de
	local partes = 6
	for k = 1, partes do
		local alvo = de:Lerp(ate, k / partes)
		if k < partes then
			alvo += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
		end
		local d = (alvo - anterior).Magnitude
		local p = peca(
			nil,
			Vector3.new(grossura or 0.25, grossura or 0.25, d),
			if k % 2 == 0 then BRANCO else cor,
			CFrame.lookAt((anterior + alvo) / 2, alvo)
		)
		sumir(p, 0.18)
		anterior = alvo
	end
end

-- Tremor de câmera curto para quem atacou (golpes fortes)
local tremorAte, tremorForca = 0, 0
local function tremer(forca: number, t: number)
	if movimentoReduzido then
		return
	end
	tremorForca = math.max(tremorForca, forca)
	tremorAte = math.max(tremorAte, os.clock() + t)
end

-- ============================================================ número de dano

local function numero(pos: Vector3, a: Acerto, meu: boolean, cor: Color3)
	local ancora = Instance.new("Attachment")
	ancora.WorldPosition = pos + Vector3.new((math.random() - 0.5) * 2, 1.5, 0)
	ancora.Parent = Workspace.Terrain
	local g = Instance.new("BillboardGui")
	local grande = a.critico or (meu and a.tipo == "principal")
	g.Size = UDim2.fromOffset(if a.critico then 190 else 120, if a.critico then 56 else 38)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 160
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = (if a.critico then "CRÍTICO " else "") .. tostring(a.dano)
	t.TextColor3 = if a.critico
		then OURO
		elseif a.tipo == "queimar" then Color3.fromHex("FF8A4A")
		else cor
	t.TextStrokeColor3 = Color3.fromHex("1A1030")
	t.TextStrokeTransparency = 0
	t.TextTransparency = if grande then 0 elseif meu then 0.1 else 0.35
	t.Parent = g
	local escala = Instance.new("UIScale")
	escala.Scale = if a.critico then 1.6 else (if meu then 1.1 else 0.8)
	escala.Parent = t
	g.Parent = ancora
	tw(
		escala,
		0.25,
		{ Scale = if a.critico then 1 else (if meu then 0.85 else 0.65) },
		Enum.EasingStyle.Back
	)
	tw(g, 0.8, { StudsOffsetWorldSpace = Vector3.new(0, 3, 0) })
	task.delay(0.45, function()
		tw(t, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(ancora, 0.85)
end

-- ============================================================ poderes

type Desenho = (Pedido, Color3, Color3, number) -> ()

local function principais(p: Pedido): { Acerto }
	local l = {}
	for _, a in p.acertos do
		if a.tipo == "principal" then
			table.insert(l, a)
		end
	end
	return l
end

local function outros(p: Pedido, tipo: string): { Acerto }
	local l = {}
	for _, a in p.acertos do
		if a.tipo == tipo then
			table.insert(l, a)
		end
	end
	return l
end

local DESENHOS: { [string]: Desenho } = {}

DESENHOS.estilhaco = function(p, c1, c2, s)
	local lanca = peca(nil, Vector3.new(0.5, 0.5, 2.2) * s, c1, CFrame.lookAt(p.origem, p.alvo))
	voar(lanca, p.origem, p.alvo, 0.2, 0, function()
		lanca:Destroy()
		clarao(p.alvo, 4 * s, BRANCO)
		for k = 1, 8 do
			local ang = k / 8 * math.pi * 2
			local dir = Vector3.new(math.cos(ang), 0.3, math.sin(ang))
			local f = peca(
				nil,
				Vector3.new(0.3, 0.3, 1.1) * s,
				if k % 2 == 0 then c1 else c2,
				CFrame.lookAt(p.alvo, p.alvo + dir)
			)
			sumir(f, 0.35, { Position = p.alvo + dir * (p.raio or 6) })
		end
		anelChao(p.alvo - Vector3.new(0, 2, 0), p.raio or 6, c2)
	end)
end

DESENHOS.vinhas = function(p, c1, c2, s)
	local chao = p.alvo - Vector3.new(0, 2.5, 0)
	-- risco de luz correndo pelo chão até o alvo
	local de = Vector3.new(p.origem.X, chao.Y, p.origem.Z)
	local d = (chao - de).Magnitude
	local risco = peca(nil, Vector3.new(0.4, 0.1, d), c1, CFrame.lookAt((de + chao) / 2, chao))
	sumir(risco, 0.3)
	for k = 1, 6 do
		local ang = k / 6 * math.pi * 2
		local base = chao + Vector3.new(math.cos(ang) * 1.6, 0, math.sin(ang) * 1.6)
		local altura = (4 + math.random() * 3) * s
		local v = peca(
			Enum.PartType.Cylinder,
			Vector3.new(0.2, 0.5 * s, 0.5 * s),
			if k % 2 == 0 then c1 else c2,
			CFrame.new(base) * CFrame.Angles(0, -ang, math.rad(70 + math.random() * 15))
		)
		tw(v, 0.18, {
			Size = Vector3.new(altura, 0.5 * s, 0.5 * s),
			CFrame = v.CFrame * CFrame.new(altura / 2, 0, 0),
		}, Enum.EasingStyle.Back)
		task.delay(0.65, function()
			if v.Parent then
				sumir(v, 0.3)
			end
		end)
	end
	estouro(chao + Vector3.new(0, 1, 0), c1, 12, "sparkles_main", 8)
end

DESENHOS.mare = function(p, c1, c2, s)
	local dir = (p.alvo - p.origem)
	local fim = p.alvo + (if dir.Magnitude > 0.1 then dir.Unit * 12 else Vector3.zero)
	local comp = (fim - p.origem).Magnitude
	local jato = peca(
		Enum.PartType.Cylinder,
		Vector3.new(0.5, 1.6 * s, 1.6 * s),
		c1,
		CFrame.lookAt(p.origem, fim) * CFrame.Angles(0, math.rad(90), 0)
	)
	jato.Transparency = 0.3
	local centro = (p.origem + fim) / 2
	tw(jato, 0.12, {
		Size = Vector3.new(comp, 1.6 * s, 1.6 * s),
		CFrame = CFrame.lookAt(centro, fim) * CFrame.Angles(0, math.rad(90), 0),
	})
	task.delay(0.12, function()
		sumir(jato, 0.3, { Size = Vector3.new(comp, 0.2, 0.2) })
		estouro(p.alvo, c2, 18, "sparkles_main", 14)
		for k = 0, 2 do
			task.delay(k * 0.08, function()
				anelChao(
					p.alvo - Vector3.new(0, 2, 0),
					3 + k * 2,
					if k % 2 == 0 then c1 else BRANCO,
					0.4
				)
			end)
		end
	end)
end

DESENHOS.brasa = function(p, c1, c2, s)
	local bola = peca(Enum.PartType.Ball, Vector3.one * 1.4 * s, c1, CFrame.new(p.origem))
	local a = Instance.new("Attachment")
	a.Parent = bola
	local fogo = Instance.new("ParticleEmitter")
	fogo.Texture = textura("fire_main")
	fogo.Color = ColorSequence.new(c1, c2)
	fogo.LightEmission = 1
	fogo.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	fogo.Lifetime = NumberRange.new(0.25, 0.4)
	fogo.Rate = 80
	fogo.Speed = NumberRange.new(1, 2)
	fogo.Parent = a
	voar(bola, p.origem, p.alvo, 0.3, 3, function()
		bola:Destroy()
		clarao(p.alvo, 6 * s, c1)
		estouro(p.alvo, c1, 25, "fire_main", 14, 1.6)
		anelChao(p.alvo - Vector3.new(0, 2, 0), 5, c2)
	end)
	-- chamas da queimadura nos pulsos
	for _, q in outros(p, "queimar") do
		task.delay(q.atraso, function()
			estouro(q.pos, c1, 8, "fire_main", 5, 1.2)
		end)
	end
end

DESENHOS.corrente = function(p, c1, _c2, s)
	relampago(p.origem, p.alvo, c1, 0.3 * s)
	clarao(p.alvo, 3 * s, BRANCO, 0.15)
	local anterior = p.alvo
	for _, a in outros(p, "corrente") do
		local de = anterior
		task.delay(a.atraso, function()
			relampago(de, a.pos, c1, 0.25 * s)
			clarao(a.pos, 2.5 * s, BRANCO, 0.15)
		end)
		anterior = a.pos
	end
end

DESENHOS.geada = function(p, c1, c2, s)
	local lanca = peca(
		nil,
		Vector3.new(0.4, 0.4, 2.6) * s,
		c1,
		CFrame.lookAt(p.origem, p.alvo),
		Enum.Material.Glass
	)
	lanca.Transparency = 0.2
	voar(lanca, p.origem, p.alvo, 0.2, 0, function()
		lanca:Destroy()
		-- bloco de gelo prendendo o alvo e estilhaçando
		local cristais = {}
		for k = 1, 7 do
			local ang = k / 7 * math.pi * 2
			local c = peca(
				nil,
				Vector3.new(0.9, 2.6 + math.random() * 1.5, 0.9) * s,
				if k % 2 == 0 then c1 else c2,
				CFrame.new(p.alvo + Vector3.new(math.cos(ang), -1, math.sin(ang)) * 1.4)
					* CFrame.Angles(math.cos(ang) * 0.4, 0, math.sin(ang) * 0.4),
				Enum.Material.Glass
			)
			c.Transparency = 0.35
			table.insert(cristais, c)
		end
		task.delay(0.7, function()
			for _, c in cristais do
				if c.Parent then
					sumir(c, 0.25, { Position = c.Position + (c.Position - p.alvo).Unit * 3 })
				end
			end
			estouro(p.alvo, c1, 16, "sparkles_main", 12)
		end)
	end)
end

DESENHOS.espiritos = function(p, c1, c2, s)
	for i, a in principais(p) do
		local lado = (i - 2) * 2.2
		local de = p.origem + Vector3.new(lado, 1.5, 0)
		local alma = peca(
			Enum.PartType.Ball,
			Vector3.one * 0.9 * s,
			if i % 2 == 0 then c2 else c1,
			CFrame.new(de)
		)
		alma.Transparency = 0.15
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.3, 0), Vector3.new(0, -0.3, 0)
		a0.Parent, a1.Parent = alma, alma
		local r = Instance.new("Trail")
		r.Attachment0, r.Attachment1 = a0, a1
		r.Color = ColorSequence.new(alma.Color, BRANCO)
		r.Transparency = NumberSequence.new(0.2, 1)
		r.Lifetime = 0.3
		r.LightEmission = 1
		r.Parent = alma
		task.delay(a.atraso, function()
			voar(alma, de, a.pos, 0.22, 2.5, function()
				alma:Destroy()
				clarao(a.pos, 2.5 * s, c1, 0.2)
			end)
		end)
	end
end

DESENHOS.eco = function(p, c1, c2, s)
	local dir = p.alvo - p.origem
	if dir.Magnitude < 0.1 then
		return
	end
	for k = 0, 2 do
		task.delay(k * 0.07, function()
			local onda = peca(
				Enum.PartType.Cylinder,
				Vector3.new(0.15, 1.5, 1.5),
				if k % 2 == 0 then c1 else c2,
				CFrame.lookAt(p.origem, p.alvo) * CFrame.Angles(0, math.rad(90), 0)
			)
			onda.Transparency = 0.25
			local fim = p.origem:Lerp(p.alvo, 1.05)
			sumir(onda, 0.3, {
				CFrame = CFrame.lookAt(fim, fim + dir) * CFrame.Angles(0, math.rad(90), 0),
				Size = Vector3.new(0.05, 7 * s, 7 * s),
			})
		end)
	end
	task.delay(0.25, function()
		anelChao(p.alvo - Vector3.new(0, 2, 0), p.raio or 8, c1)
	end)
end

DESENHOS.meteoro = function(p, c1, c2, s)
	local forte = p.forte == true
	local tam = (if forte then 4.5 else 1.4) * s
	local de = p.alvo + Vector3.new(-14, 34, 8)
	local estrela = peca(Enum.PartType.Ball, Vector3.one * tam, c1, CFrame.new(de))
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, tam / 2, 0), Vector3.new(0, -tam / 2, 0)
	a0.Parent, a1.Parent = estrela, estrela
	local r = Instance.new("Trail")
	r.Attachment0, r.Attachment1 = a0, a1
	r.Color = ColorSequence.new(BRANCO, c2)
	r.Transparency = NumberSequence.new(0, 1)
	r.Lifetime = 0.35
	r.LightEmission = 1
	r.FaceCamera = true
	r.Parent = estrela
	voar(estrela, de, p.alvo, if forte then 0.45 else 0.28, 0, function()
		estrela:Destroy()
		clarao(p.alvo, (if forte then 16 else 5) * s, BRANCO, 0.3)
		estouro(
			p.alvo,
			c1,
			if forte then 60 else 18,
			"sparkles_main",
			if forte then 30 else 14,
			if forte then 2 else 1
		)
		anelChao(p.alvo - Vector3.new(0, 2, 0), if forte then 16 else 5, c2, 0.6)
		if forte and p.meu then
			tremer(1.2, 0.35)
		end
	end)
end

DESENHOS.vazio = function(p, c1, c2, s)
	local esfera =
		peca(Enum.PartType.Ball, Vector3.one * 5 * s, Color3.fromHex("120A20"), CFrame.new(p.alvo))
	esfera.Material = Enum.Material.ForceField
	esfera.Color = c2
	local nucleo = peca(
		Enum.PartType.Ball,
		Vector3.one * 2 * s,
		Color3.fromHex("05030A"),
		CFrame.new(p.alvo),
		Enum.Material.SmoothPlastic
	)
	estouro(p.alvo, c1, 20, "explosion01_implosion_main", 1, 3)
	tw(esfera, 0.3, { Size = Vector3.one * 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tw(nucleo, 0.3, { Size = Vector3.one * 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.3, function()
		esfera:Destroy()
		nucleo:Destroy()
		clarao(p.alvo, (p.raio or 10) * 1.2, c1, 0.3)
		anelChao(p.alvo - Vector3.new(0, 2, 0), p.raio or 10, c2, 0.5)
		estouro(p.alvo, c2, 30, "sparkles_main", 22)
	end)
end

DESENHOS.runas = function(p, c1, c2, s)
	for i, a in principais(p) do
		local lado = if i % 2 == 0 then 1 else -1
		local de = p.origem + Vector3.new(lado * 2, 0.5, 0)
		local runa = peca(
			Enum.PartType.Cylinder,
			Vector3.new(0.15, 2.2 * s, 2.2 * s),
			if i % 2 == 0 then c2 else c1,
			CFrame.new(de)
		)
		runa.Transparency = 0.15
		for k = 1, 4 do
			local lamina = peca(nil, Vector3.new(0.12, 0.4, 1.6) * s, BRANCO, CFrame.new(de))
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = runa, lamina
			lamina.CFrame = runa.CFrame
				* CFrame.Angles(k * math.pi / 2, 0, 0)
				* CFrame.new(0, 0, 1.2 * s)
			lamina.Parent = runa
		end
		local inicio = os.clock()
		local con = RunService.Heartbeat:Connect(function()
			local giro = (os.clock() - inicio) * 25
			local pos = runa.Position
			runa.CFrame = CFrame.new(pos)
				* CFrame.Angles(0, 0, math.rad(90))
				* CFrame.Angles(giro, 0, 0)
		end)
		task.delay(a.atraso, function()
			voar(runa, de, a.pos, 0.22, lado * 2, function()
				con:Disconnect()
				clarao(a.pos, 3 * s, if a.critico then OURO else c1, 0.2)
				if a.critico then
					estouro(a.pos, OURO, 20, "sparkles_main", 16)
				end
				sumir(runa, 0.15)
			end)
		end)
		Debris:AddItem(runa, 2)
	end
end

DESENHOS.garras = function(p, c1, c2, s)
	local olhar = CFrame.lookAt(p.alvo, p.origem)
	for i, a in principais(p) do
		task.delay(a.atraso, function()
			local ang = ({ 45, -45, 0 })[(i - 1) % 3 + 1]
			local corte = peca(
				nil,
				Vector3.new(0.15, 6 * s, 0.35),
				if a.critico then OURO else (if i % 2 == 0 then c2 else c1),
				olhar * CFrame.new(0, 0, -1) * CFrame.Angles(0, 0, math.rad(ang))
			)
			corte.Size = Vector3.new(0.15, 0.5, 0.35)
			tw(corte, 0.08, { Size = Vector3.new(0.2, 6 * s, 0.35) })
			task.delay(0.1, function()
				sumir(corte, 0.2, { Size = Vector3.new(0.05, 7 * s, 0.1) })
			end)
			if a.critico then
				estouro(a.pos, OURO, 18, "sparkles_main", 16)
			end
		end)
	end
end

DESENHOS.espada = function(p, c1, c2, s)
	local chao = p.alvo - Vector3.new(0, 2, 0)
	local tamanho = 14 * s
	local lamina = peca(
		nil,
		Vector3.new(1.4 * s, tamanho, 0.4 * s),
		c1,
		CFrame.new(chao + Vector3.new(0, 40, 0))
	)
	local guarda = peca(
		nil,
		Vector3.new(4 * s, 0.6 * s, 0.8 * s),
		c2,
		CFrame.new(chao + Vector3.new(0, 40 + tamanho / 2, 0))
	)
	local cabo = peca(
		nil,
		Vector3.new(0.6 * s, 2.5 * s, 0.6 * s),
		c2,
		CFrame.new(chao + Vector3.new(0, 40 + tamanho / 2 + 1.5 * s, 0))
	)
	local desce = Vector3.new(0, 40 - tamanho / 2 + 1, 0)
	for _, x in { lamina, guarda, cabo } do
		tw(
			x,
			0.22,
			{ Position = x.Position - desce },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end
	task.delay(0.22, function()
		clarao(chao + Vector3.new(0, 2, 0), 10 * s, BRANCO, 0.3)
		anelChao(chao, p.raio or 10, c1, 0.6)
		estouro(chao + Vector3.new(0, 1, 0), c1, 40, "sparkles_main", 24, 1.5)
		-- rachaduras de luz no chão
		for k = 1, 6 do
			local ang = k / 6 * math.pi * 2 + math.random() * 0.4
			local fim = chao + Vector3.new(math.cos(ang), 0, math.sin(ang)) * (p.raio or 10)
			local r = peca(
				nil,
				Vector3.new(0.35, 0.1, (fim - chao).Magnitude),
				c2,
				CFrame.lookAt((chao + fim) / 2, fim)
			)
			sumir(r, 0.6)
		end
		if p.meu then
			tremer(0.8, 0.3)
		end
		task.delay(0.35, function()
			for _, x in { lamina, guarda, cabo } do
				if x.Parent then
					sumir(x, 0.3)
				end
			end
		end)
	end)
end

DESENHOS.punho = function(p, c1, c2, s)
	-- o braço estica como borracha e o punho cresce até ficar gigante
	local dir = p.alvo - p.origem
	local comp = dir.Magnitude
	local braco = peca(
		Enum.PartType.Cylinder,
		Vector3.new(0.5, 1.1 * s, 1.1 * s),
		c2,
		CFrame.lookAt(p.origem, p.alvo) * CFrame.Angles(0, math.rad(90), 0),
		Enum.Material.SmoothPlastic
	)
	local punho = peca(
		Enum.PartType.Ball,
		Vector3.one * 1.6 * s,
		BRANCO,
		CFrame.new(p.origem),
		Enum.Material.SmoothPlastic
	)
	local t = 0.18
	tw(braco, t, {
		Size = Vector3.new(comp, 1.1 * s, 1.1 * s),
		CFrame = CFrame.lookAt(p.origem + dir / 2, p.alvo) * CFrame.Angles(0, math.rad(90), 0),
	})
	tw(punho, t, { Position = p.alvo, Size = Vector3.one * 6 * s }, Enum.EasingStyle.Back)
	task.delay(t, function()
		clarao(p.alvo, 9 * s, c1, 0.3)
		anelChao(p.alvo - Vector3.new(0, 2, 0), p.raio or 10, c1, 0.5)
		estouro(p.alvo, c1, 30, "sparkles_main", 22, 1.6)
		if p.meu then
			tremer(0.9, 0.25)
		end
		-- volta como borracha
		tw(braco, 0.15, {
			Size = Vector3.new(0.5, 1.1 * s, 1.1 * s),
			CFrame = CFrame.lookAt(p.origem, p.alvo) * CFrame.Angles(0, math.rad(90), 0),
		})
		tw(punho, 0.15, { Position = p.origem, Size = Vector3.one * 1.2 })
		Debris:AddItem(braco, 0.18)
		Debris:AddItem(punho, 0.18)
	end)
end

-- ============================================================ entrada

function Fx.definir(prefs: { movimentoReduzido: boolean })
	movimentoReduzido = prefs.movimentoReduzido
end

function Fx.cores(auraId: string?): (Color3, Color3)
	local aura = auraId and Auras.porId[auraId]
	if not aura then
		return Color3.fromHex("C0ADFF"), Color3.fromHex("B7FFD9")
	end
	return Color3.fromHex(aura.cores[1]), Color3.fromHex(aura.cores[2] or aura.cores[1])
end

local function simples(p: Pedido, c1: Color3)
	local orbe = peca(Enum.PartType.Ball, Vector3.one * 0.9, c1, CFrame.new(p.origem))
	voar(orbe, p.origem, p.alvo, 0.18, 0, function()
		sumir(orbe, 0.2, { Size = Vector3.one * 3 })
	end)
end

function Fx.tocar(p: Pedido)
	Fx.iniciar()
	local c1, c2 = Fx.cores(p.aura)
	local tier = p.tier or 1
	local s = 0.85 + math.clamp(tier, 1, 7) * 0.08 -- auras raras: ataques maiores
	local desenho = DESENHOS[p.poder]
	-- muitos efeitos na tela (ou de outros jogadores longe): versão simples
	if not desenho or (ativos > LIMITE and not p.meu) then
		simples(p, c1)
	else
		local ok, erro = pcall(desenho, p, c1, c2, s)
		if not ok then
			warn("[AtaquesAura] " .. p.poder .. ": " .. tostring(erro))
			simples(p, c1)
		end
	end
	for _, a in p.acertos do
		task.delay(a.atraso + 0.18, numero, a.pos, a, p.meu, c1)
	end
end

local iniciado = false
function Fx.iniciar()
	if iniciado then
		return
	end
	iniciado = true
	RunService:BindToRenderStep(
		"AtaquesAuraTremor",
		Enum.RenderPriority.Camera.Value + 3,
		function()
			local agora = os.clock()
			if agora < tremorAte then
				local camera = Workspace.CurrentCamera
				local f = tremorForca * (tremorAte - agora)
				camera.CFrame *= CFrame.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, 0)
			else
				tremorForca = 0
			end
		end
	)
end

function Fx.eu(): number
	return Players.LocalPlayer.UserId
end

return Fx
