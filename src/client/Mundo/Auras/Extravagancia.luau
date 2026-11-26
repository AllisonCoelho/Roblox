-- Camada extravagante de efeitos em TODAS as auras (regras em Shared/Dados/Extravagancia).
-- O servidor só publica qual aura está equipada (atributos "AuraId" e "AuraIdEm" no personagem);
-- cada cliente monta os efeitos por cima do efeito próprio da aura:
--   brilho · anel no chão · orbes com rastro · tema (chama/névoa/brilho) · fitas em espiral ·
--   pulso · pilar de luz · título flutuante · portal acima da cabeça · raios · contorno ·
--   cores ciclando · coroa de estrelas · chuva de luz
-- e a manifestação ao equipar (anéis, faíscas, flash, tremor e tela tingida para o dono).
-- Respeita "qualidade baixa", "movimento reduzido", "ocultar efeitos alheios" e reduz os
-- detalhes de quem está longe da câmera.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared:WaitForChild("Dados"):WaitForChild("Auras"))
local Regras = require(Shared:WaitForChild("Dados"):WaitForChild("Extravagancia"))

local Mod = {}

export type Preferencias = {
	qualidadeBaixa: boolean,
	movimentoReduzido: boolean,
	ocultarEfeitosAlheios: boolean,
}

local function textura(nome: string): string
	return "rbxasset://textures/particles/" .. nome .. ".dds"
end

type Orbe = { parte: BasePart, fase: number }
type Inst = {
	personagem: Model,
	jogador: Player,
	raiz: BasePart,
	aura: any,
	tier: number,
	c1: Color3,
	c2: Color3,
	pes: number, -- distância da raiz até os pés
	pasta: Folder, -- peças ancoradas (orbes, portal, coroa)
	anexos: { Attachment },
	emissores: { ParticleEmitter },
	pesados: { Instance }, -- desligam com a distância
	beams: { Beam },
	espiral: { { a0: Attachment, a1: Attachment, fase: number } },
	orbes: { Orbe },
	coroa: { Orbe },
	portal: { BasePart },
	luz: PointLight?,
	contorno: Highlight?,
	titulo: BillboardGui?,
	gradiente: UIGradient?,
	pulso: ParticleEmitter?,
	anelPulso: ParticleEmitter?,
	proximoPulso: number,
	proximoRaio: number,
	detalhe: number,
	cromatico: boolean,
	raios: boolean,
}

local prefs: Preferencias =
	{ qualidadeBaixa = false, movimentoReduzido = false, ocultarEfeitosAlheios = false }
local ativos: { [Model]: Inst } = {}
local observados: { [Player]: { RBXScriptConnection } } = {}
local pastaGeral: Folder

-- ============================================================ peças

local function emissor(pai: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = pai
	return e
end

local function anexo(raiz: BasePart, pos: Vector3, nome: string): Attachment
	local a = Instance.new("Attachment")
	a.Name = nome
	a.Position = pos
	a.Parent = raiz
	return a
end

local function neon(pai: Instance, forma: Enum.PartType, tamanho: Vector3, cor: Color3): Part
	local p = Instance.new("Part")
	p.Shape = forma
	p.Size = tamanho
	p.Color = cor
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = pai
	return p
end

local function sequencia(c1: Color3, c2: Color3): ColorSequence
	return ColorSequence.new(c1, c2)
end

local function some(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- ============================================================ montagem

local function montar(jogador: Player, personagem: Model, id: string): Inst?
	local aura = Auras.porId[id]
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if not aura or not raiz or not raiz:IsA("BasePart") or not humanoide then
		return nil
	end
	local tier = if aura.exclusiva then #Auras.Tiers else aura.tier
	local corAparencia = personagem:GetAttribute("AuraCor")
	local c1 =
		Color3.fromHex(if type(corAparencia) == "string" then corAparencia else aura.cores[1])
	local c2 = Color3.fromHex(aura.cores[2] or aura.cores[1])
	local pes = if humanoide.RigType == Enum.HumanoidRigType.R15
		then humanoide.HipHeight + raiz.Size.Y / 2
		else 3
	local pasta = Instance.new("Folder")
	pasta.Name = "Ext_" .. jogador.Name
	pasta.Parent = pastaGeral
	local inst: Inst = {
		personagem = personagem,
		jogador = jogador,
		raiz = raiz,
		aura = aura,
		tier = tier,
		c1 = c1,
		c2 = c2,
		pes = pes,
		pasta = pasta,
		anexos = {},
		emissores = {},
		pesados = {},
		beams = {},
		espiral = {},
		orbes = {},
		coroa = {},
		portal = {},
		proximoPulso = os.clock() + 1,
		proximoRaio = 0,
		detalhe = 2,
		cromatico = false,
		raios = false,
	}
	local baixa = prefs.qualidadeBaixa
	local base = anexo(raiz, Vector3.zero, "ExtBase")
	local chao = anexo(raiz, Vector3.new(0, -pes + 0.2, 0), "ExtChao")
	table.insert(inst.anexos, base)
	table.insert(inst.anexos, chao)
	local function reg(e: ParticleEmitter, pesado: boolean?): ParticleEmitter
		table.insert(inst.emissores, e)
		if pesado then
			table.insert(inst.pesados, e)
		end
		return e
	end

	for _, camada in Regras.camadas(tier, baixa) do
		if camada == "brilho" then
			local luz = Instance.new("PointLight")
			luz.Name = "ExtLuz"
			luz.Color = c1
			luz.Range = Regras.alcanceLuz(tier)
			luz.Brightness = 1 + tier * 0.15
			luz.Shadows = false
			luz.Parent = raiz
			inst.luz = luz
			reg(emissor(base, {
				Name = "ExtFaiscas",
				Texture = textura("sparkles_main"),
				Color = sequencia(c1, c2),
				Size = some(0.35 + tier * 0.05, 0),
				Lifetime = NumberRange.new(0.8, 1.4),
				Rate = 3 + tier * 2,
				Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(180, 180),
				Drag = 1,
			}))
		elseif camada == "anelChao" then
			-- anéis que nascem no chão, sobem e abrem (o efeito mais comum dos jogos de RNG)
			reg(emissor(chao, {
				Name = "ExtAnel",
				Texture = textura("explosion01_shockwave_main"),
				Color = sequencia(c1, c2),
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				EmissionDirection = Enum.NormalId.Top,
				Size = some(1.5, 6 + tier * 0.6),
				Transparency = some(0.15, 1),
				Lifetime = NumberRange.new(1.3, 1.5),
				Rate = 0.6 + tier * 0.15,
				Speed = NumberRange.new(1.5, 2.5),
			}))
		elseif camada == "orbes" then
			for i = 1, Regras.orbes(tier) do
				local p = neon(
					pasta,
					Enum.PartType.Ball,
					Vector3.one * (0.45 + tier * 0.04),
					if i % 2 == 0 then c2 else c1
				)
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.18, 0)
				a0.Parent = p
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -0.18, 0)
				a1.Parent = p
				local rastro = Instance.new("Trail")
				rastro.Attachment0 = a0
				rastro.Attachment1 = a1
				rastro.Color = sequencia(p.Color, Color3.new(1, 1, 1))
				rastro.Transparency = some(0.1, 1)
				rastro.Lifetime = 0.35
				rastro.LightEmission = 1
				rastro.FaceCamera = true
				rastro.Parent = p
				table.insert(
					inst.orbes,
					{ parte = p, fase = (i - 1) / Regras.orbes(tier) * math.pi * 2 }
				)
			end
		elseif camada == "tema" then
			local t = Regras.tema(aura.estilo)
			reg(emissor(chao, {
				Name = "ExtTema",
				Texture = textura(t.textura),
				Color = sequencia(c1, c2),
				LightEmission = t.brilho,
				Size = some(t.tamanho[1], t.tamanho[2]),
				Transparency = some(0.2, 1),
				Lifetime = NumberRange.new(0.9, 1.6),
				Rate = t.taxa,
				Speed = NumberRange.new(t.sobe * 0.7, t.sobe),
				SpreadAngle = Vector2.new(35, 35),
				RotSpeed = NumberRange.new(-60, 60),
				Rotation = NumberRange.new(0, 360),
				EmissionDirection = Enum.NormalId.Top,
			}))
		elseif camada == "espiral" then
			for i = 1, Regras.fitas(tier) do
				local a0 = anexo(raiz, Vector3.zero, "ExtFitaA")
				local a1 = anexo(raiz, Vector3.zero, "ExtFitaB")
				table.insert(inst.anexos, a0)
				table.insert(inst.anexos, a1)
				local b = Instance.new("Beam")
				b.Attachment0 = a0
				b.Attachment1 = a1
				b.Texture = textura("sparkles_main")
				b.TextureMode = Enum.TextureMode.Wrap
				b.TextureLength = 2
				b.TextureSpeed = 1.5
				b.Color = sequencia(c1, c2)
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Transparency = some(0.2, 0.7)
				b.Width0 = 0.5
				b.Width1 = 0.15
				b.CurveSize0 = 3
				b.CurveSize1 = -3
				b.FaceCamera = true
				b.Segments = 16
				b.Parent = raiz
				table.insert(inst.beams, b)
				table.insert(inst.pesados, b)
				table.insert(
					inst.espiral,
					{ a0 = a0, a1 = a1, fase = (i - 1) / Regras.fitas(tier) * math.pi * 2 }
				)
			end
		elseif camada == "pulso" then
			inst.pulso = reg(emissor(chao, {
				Name = "ExtPulso",
				Texture = textura("sparkles_main"),
				Color = sequencia(Color3.new(1, 1, 1), c1),
				Size = some(0.8, 0),
				Lifetime = NumberRange.new(0.6, 1),
				Rate = 0,
				Speed = NumberRange.new(10, 18),
				SpreadAngle = Vector2.new(60, 60),
				EmissionDirection = Enum.NormalId.Top,
				Drag = 3,
			}))
			inst.anelPulso = reg(emissor(chao, {
				Name = "ExtPulsoAnel",
				Texture = textura("explosion01_shockwave_main"),
				Color = sequencia(Color3.new(1, 1, 1), c2),
				Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
				EmissionDirection = Enum.NormalId.Top,
				Size = some(1, 12 + tier),
				Transparency = some(0, 1),
				Lifetime = NumberRange.new(0.6, 0.6),
				Rate = 0,
				Speed = NumberRange.new(0.1, 0.1),
			}))
		elseif camada == "pilar" then
			local topo = anexo(raiz, Vector3.new(0, 45, 0), "ExtPilar")
			table.insert(inst.anexos, topo)
			local b = Instance.new("Beam")
			b.Attachment0 = chao
			b.Attachment1 = topo
			b.Texture = textura("forcefield_glow_main")
			b.TextureSpeed = 0.4
			b.Color = sequencia(c1, c2)
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Transparency = some(0.55, 1)
			b.Width0 = 3.2
			b.Width1 = 1.2
			b.FaceCamera = true
			b.Parent = raiz
			table.insert(inst.beams, b)
			table.insert(inst.pesados, b)
		elseif camada == "titulo" then
			local cabeca = personagem:FindFirstChild("Head")
			if cabeca and cabeca:IsA("BasePart") then
				local g = Instance.new("BillboardGui")
				g.Name = "ExtTitulo"
				g.Size = UDim2.fromOffset(220, 46)
				g.StudsOffset = Vector3.new(0, 3.1, 0)
				g.LightInfluence = 0
				g.MaxDistance = 90
				g.Adornee = cabeca
				local nome = Instance.new("TextLabel")
				nome.BackgroundTransparency = 1
				nome.Size = UDim2.fromScale(1, 0.64)
				nome.Font = Enum.Font.GothamBlack
				nome.TextScaled = true
				nome.Text = string.upper(aura.nome)
				nome.TextColor3 = Color3.new(1, 1, 1)
				nome.TextStrokeTransparency = 0.3
				nome.Parent = g
				local grad = Instance.new("UIGradient")
				grad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, c1),
					ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, c2),
				})
				grad.Parent = nome
				inst.gradiente = grad
				local raridade = Instance.new("TextLabel")
				raridade.BackgroundTransparency = 1
				raridade.Position = UDim2.fromScale(0, 0.64)
				raridade.Size = UDim2.fromScale(1, 0.36)
				raridade.Font = Enum.Font.GothamBold
				raridade.TextScaled = true
				raridade.Text = string.format("%s · 1 em %s", aura.tierNome, tostring(aura.chance))
				raridade.TextColor3 =
					Color3.fromHex(Auras.Tiers[math.clamp(aura.tier, 1, #Auras.Tiers)].cor)
				raridade.TextStrokeTransparency = 0.3
				raridade.Parent = g
				g.Parent = pasta
				inst.titulo = g
			end
		elseif camada == "portal" then
			local anel = neon(pasta, Enum.PartType.Cylinder, Vector3.new(0.12, 5, 5), c1)
			anel.Transparency = 0.45
			local miolo = neon(pasta, Enum.PartType.Cylinder, Vector3.new(0.14, 3.6, 3.6), c2)
			miolo.Transparency = 0.25
			inst.portal = { anel, miolo }
			for k = 1, 8 do
				local p = neon(
					pasta,
					Enum.PartType.Block,
					Vector3.one * 0.35,
					if k % 2 == 0 then c1 else c2
				)
				p:SetAttribute("Indice", k)
				table.insert(inst.portal, p)
			end
			local alvo = Instance.new("Attachment")
			alvo.Parent = anel
			for _, lado in { -1, 1 } do
				local ombro = anexo(raiz, Vector3.new(lado * 1.1, 1.4, 0), "ExtOmbro")
				table.insert(inst.anexos, ombro)
				local b = Instance.new("Beam")
				b.Attachment0 = ombro
				b.Attachment1 = alvo
				b.Texture = textura("sparkles_main")
				b.TextureSpeed = 2
				b.Color = sequencia(c1, c2)
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Transparency = some(0.2, 0.5)
				b.Width0 = 0.4
				b.Width1 = 0.8
				b.CurveSize0 = lado * 2
				b.FaceCamera = true
				b.Parent = raiz
				table.insert(inst.beams, b)
				table.insert(inst.pesados, b)
			end
		elseif camada == "raios" then
			inst.raios = true
		elseif camada == "contorno" then
			local h = Instance.new("Highlight")
			h.Name = "ExtContorno"
			h.OutlineColor = c1
			h.FillColor = c2
			h.FillTransparency = 0.88
			h.OutlineTransparency = 0.15
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Adornee = personagem
			h.Parent = pasta
			inst.contorno = h
		elseif camada == "cromatico" then
			inst.cromatico = true
		elseif camada == "coroa" then
			for k = 1, 6 do
				local estrela = neon(
					pasta,
					Enum.PartType.Block,
					Vector3.new(0.4, 0.4, 0.1),
					Color3.new(1, 1, 1)
				)
				table.insert(inst.coroa, { parte = estrela, fase = (k - 1) / 6 * math.pi * 2 })
			end
		elseif camada == "chuva" then
			local ceu = anexo(raiz, Vector3.new(0, 16, 0), "ExtChuva")
			table.insert(inst.anexos, ceu)
			reg(
				emissor(ceu, {
					Name = "ExtChuva",
					Texture = textura("sparkles_main"),
					Color = sequencia(c1, c2),
					Size = some(0.35, 0.1),
					Lifetime = NumberRange.new(1.4, 1.8),
					Rate = 26,
					Speed = NumberRange.new(9, 12),
					SpreadAngle = Vector2.new(55, 55),
					EmissionDirection = Enum.NormalId.Bottom,
				}),
				true
			)
		end
	end
	return inst
end

local function destruir(inst: Inst)
	for _, a in inst.anexos do
		a:Destroy()
	end
	for _, b in inst.beams do
		b:Destroy()
	end
	if inst.luz then
		inst.luz:Destroy()
	end
	inst.pasta:Destroy()
end

-- ============================================================ manifestação (ao equipar)

local tremorAte, tremorForca = 0, 0

local function manifestar(inst: Inst)
	local m = Regras.manifestacao(inst.tier)
	local raiz = inst.raiz
	local chao = raiz.Position - Vector3.new(0, inst.pes - 0.2, 0)
	local a = Instance.new("Attachment")
	a.WorldPosition = chao
	a.Parent = Workspace.Terrain
	local aneis = emissor(a, {
		Texture = textura("explosion01_shockwave_main"),
		Color = sequencia(Color3.new(1, 1, 1), inst.c1),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = some(2, 18 + inst.tier * 2),
		Transparency = some(0, 1),
		Lifetime = NumberRange.new(0.7, 1.1),
		Rate = 0,
		Speed = NumberRange.new(0.1, 4),
	})
	local faiscas = emissor(a, {
		Texture = textura("sparkles_main"),
		Color = sequencia(inst.c1, inst.c2),
		Size = some(1.2, 0),
		Lifetime = NumberRange.new(0.8, 1.6),
		Rate = 0,
		Speed = NumberRange.new(14, 30),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 2.5,
	})
	local nucleo = emissor(a, {
		Texture = textura("explosion01_core_main"),
		Color = sequencia(Color3.new(1, 1, 1), inst.c1),
		Size = some(3, 10 + inst.tier),
		Transparency = some(0.1, 1),
		Lifetime = NumberRange.new(0.5, 0.5),
		Rate = 0,
		Speed = NumberRange.new(0, 0),
	})
	task.spawn(function()
		nucleo:Emit(1)
		for _ = 1, m.aneis do
			aneis:Emit(1)
			task.wait(0.15)
		end
	end)
	faiscas:Emit(m.faiscas)
	Debris:AddItem(a, 3)
	if inst.luz then
		local luz = inst.luz
		local normal = luz.Brightness
		luz.Brightness = normal * 6
		TweenService:Create(luz, TweenInfo.new(m.duracao), { Brightness = normal }):Play()
	end
	-- só para o dono: tremor, flash e tela tingida
	if inst.jogador ~= Players.LocalPlayer then
		return
	end
	if m.tremor > 0 and not prefs.movimentoReduzido then
		tremorForca = m.tremor
		tremorAte = os.clock() + m.duracao * 0.6
	end
	if m.flash > 0 or m.tingir then
		local cor = Instance.new("ColorCorrectionEffect")
		cor.Name = "ExtManifestacao"
		cor.Brightness = m.flash
		cor.TintColor = if m.tingir
			then inst.c1:Lerp(Color3.new(1, 1, 1), 0.5)
			else Color3.new(1, 1, 1)
		cor.Parent = Lighting
		local tw = TweenService:Create(
			cor,
			TweenInfo.new(m.duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0, TintColor = Color3.new(1, 1, 1) }
		)
		tw:Play()
		Debris:AddItem(cor, m.duracao + 0.2)
	end
end

-- ============================================================ quadro a quadro

local function raio(inst: Inst)
	local raiz = inst.raiz
	local ang = math.random() * math.pi * 2
	local de = raiz.Position
		+ Vector3.new(math.cos(ang) * 2.6, -inst.pes + 0.5, math.sin(ang) * 2.6)
	local ate = raiz.Position + Vector3.new(math.cos(ang + 0.8) * 3, 3, math.sin(ang + 0.8) * 3)
	local anterior = de
	local cor = if math.random() < 0.5 then inst.c1 else Color3.new(1, 1, 1)
	for k = 1, 5 do
		local alvo = de:Lerp(ate, k / 5)
			+ (
				if k < 5
					then Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.4
					else Vector3.zero
			)
		local d = (alvo - anterior).Magnitude
		local p = neon(inst.pasta, Enum.PartType.Block, Vector3.new(0.14, 0.14, d), cor)
		p.CFrame = CFrame.lookAt((anterior + alvo) / 2, alvo)
		Debris:AddItem(p, 0.12)
		anterior = alvo
	end
end

local function cor(inst: Inst, agora: number): (Color3, Color3)
	if not inst.cromatico then
		return inst.c1, inst.c2
	end
	return Color3.fromHSV(Regras.matiz(agora), 0.65, 1),
		Color3.fromHSV(Regras.matiz(agora, 0.35), 0.65, 1)
end

local function atualizar(inst: Inst, agora: number, camera: Vector3)
	local raiz = inst.raiz
	local pos = raiz.Position
	local proprio = inst.jogador == Players.LocalPlayer
	local detalhe = Regras.detalhe((pos - camera).Magnitude, proprio)
	if detalhe ~= inst.detalhe then
		inst.detalhe = detalhe
		for _, e in inst.emissores do
			e.Enabled = detalhe >= 1
		end
		for _, p in inst.pesados do
			(p :: any).Enabled = detalhe >= 2
		end
		inst.pasta.Parent = if detalhe >= 1 then pastaGeral else nil
	end
	if detalhe == 0 then
		return
	end
	local reduz = prefs.movimentoReduzido
	local giro = if reduz then 0 else agora
	local c1, c2 = cor(inst, agora)
	if inst.cromatico then
		local seq = ColorSequence.new(c1, c2)
		for _, e in inst.emissores do
			e.Color = seq
		end
		for _, b in inst.beams do
			b.Color = seq
		end
		if inst.luz then
			inst.luz.Color = c1
		end
		if inst.contorno then
			inst.contorno.OutlineColor = c1
			inst.contorno.FillColor = c2
		end
	end
	-- orbes girando com rastro
	for i, o in inst.orbes do
		local a = giro * 2 + o.fase
		local r = 2.8 + math.sin(giro * 1.3 + i) * 0.3
		o.parte.CFrame = CFrame.new(
			pos + Vector3.new(math.cos(a) * r, math.sin(giro * 2 + i) * 1.1 + 0.4, math.sin(a) * r)
		)
		if inst.cromatico then
			o.parte.Color = if i % 2 == 0 then c2 else c1
		end
	end
	-- fitas em espiral subindo pelo corpo
	for _, f in inst.espiral do
		local a = giro * 1.4 + f.fase
		f.a0.Position = Vector3.new(math.cos(a) * 1.8, -inst.pes + 0.3, math.sin(a) * 1.8)
		f.a1.Position = Vector3.new(math.cos(a + math.pi) * 1.4, 2.6, math.sin(a + math.pi) * 1.4)
	end
	-- portal acima da cabeça
	if #inst.portal > 0 then
		local centro = CFrame.new(pos + Vector3.new(0, 5 + math.sin(agora * 1.5) * 0.2, 0))
		inst.portal[1].CFrame = centro * CFrame.Angles(0, giro * 0.8, math.rad(90))
		inst.portal[2].CFrame = centro * CFrame.Angles(0, -giro * 1.2, math.rad(90))
		for k = 3, #inst.portal do
			local a = giro * 1.6 + (k - 3) / 8 * math.pi * 2
			inst.portal[k].CFrame = centro
				* CFrame.new(math.cos(a) * 2.9, 0, math.sin(a) * 2.9)
				* CFrame.Angles(giro * 3, giro * 2, 0)
		end
		if inst.cromatico then
			inst.portal[1].Color = c1
			inst.portal[2].Color = c2
		end
	end
	-- coroa de estrelas
	for i, o in inst.coroa do
		local a = giro * 1.1 + o.fase
		o.parte.CFrame = CFrame.new(
			pos
				+ Vector3.new(
					math.cos(a) * 1.3,
					3.1 + math.sin(agora * 3 + i) * 0.12,
					math.sin(a) * 1.3
				)
		) * CFrame.Angles(0, -a, math.rad(45))
		o.parte.Color = if inst.cromatico
			then c1:Lerp(Color3.new(1, 1, 1), 0.4)
			else Color3.new(1, 1, 1)
	end
	-- título com brilho correndo
	if inst.gradiente then
		inst.gradiente.Offset = Vector2.new(math.sin(agora * 1.6) * 0.6, 0)
	end
	-- pulso na base
	if inst.pulso and agora >= inst.proximoPulso then
		inst.proximoPulso = agora + Regras.intervaloPulso(inst.tier)
		inst.pulso:Emit(10 + inst.tier * 4)
		if inst.anelPulso then
			inst.anelPulso:Emit(1)
		end
		if inst.luz then
			inst.luz.Brightness = (1 + inst.tier * 0.15) * 2.5
		end
	end
	if inst.luz then
		local normal = 1 + inst.tier * 0.15
		inst.luz.Brightness += (normal - inst.luz.Brightness) * 0.1
	end
	-- raios em volta
	if inst.raios and detalhe >= 2 and agora >= inst.proximoRaio then
		inst.proximoRaio = agora + 0.25 + math.random() * 0.35
		raio(inst)
	end
end

-- ============================================================ quem tem o quê

local function permitido(jogador: Player): boolean
	return jogador == Players.LocalPlayer or not prefs.ocultarEfeitosAlheios
end

local function sincronizar(jogador: Player, personagem: Model)
	local atual = ativos[personagem]
	local id = personagem:GetAttribute("AuraId")
	local querido = if type(id) == "string"
			and Auras.porId[id]
			and permitido(jogador)
		then id
		else nil
	if atual and atual.aura.id == querido and atual.raiz.Parent then
		return
	end
	if atual then
		destruir(atual)
		ativos[personagem] = nil
	end
	if not querido then
		return
	end
	task.spawn(function()
		personagem:WaitForChild("HumanoidRootPart", 10)
		personagem:WaitForChild("Humanoid", 10)
		if
			personagem.Parent == nil
			or personagem:GetAttribute("AuraId") ~= querido
			or ativos[personagem]
		then
			return
		end
		local ok, inst = pcall(montar, jogador, personagem, querido :: string)
		if not ok then
			warn("[Extravagancia] " .. tostring(inst))
			return
		end
		if not inst then
			return
		end
		ativos[personagem] = inst
		local em = personagem:GetAttribute("AuraIdEm")
		if type(em) == "number" and Workspace:GetServerTimeNow() - em < 2.5 then
			pcall(manifestar, inst)
		end
	end)
end

local function observar(jogador: Player)
	local lista: { RBXScriptConnection } = {}
	local function ligar(personagem: Model)
		sincronizar(jogador, personagem)
		table.insert(
			lista,
			personagem:GetAttributeChangedSignal("AuraId"):Connect(function()
				sincronizar(jogador, personagem)
			end)
		)
		table.insert(
			lista,
			personagem:GetAttributeChangedSignal("AuraCor"):Connect(function()
				local a = ativos[personagem]
				if a then
					destruir(a)
					ativos[personagem] = nil
				end
				sincronizar(jogador, personagem)
			end)
		)
	end
	table.insert(lista, jogador.CharacterAdded:Connect(ligar))
	if jogador.Character then
		ligar(jogador.Character)
	end
	observados[jogador] = lista
end

local function refazerTodos()
	for personagem, a in ativos do
		destruir(a)
		ativos[personagem] = nil
	end
	for _, jogador in Players:GetPlayers() do
		if jogador.Character then
			sincronizar(jogador, jogador.Character)
		end
	end
end

function Mod.definir(novas: Preferencias)
	local mudou = novas.qualidadeBaixa ~= prefs.qualidadeBaixa
		or novas.ocultarEfeitosAlheios ~= prefs.ocultarEfeitosAlheios
	prefs = novas
	if mudou then
		refazerTodos()
	end
end

function Mod.iniciar()
	pastaGeral = Instance.new("Folder")
	pastaGeral.Name = "AurasExtravagantes"
	pastaGeral.Parent = Workspace
	Players.PlayerAdded:Connect(observar)
	for _, jogador in Players:GetPlayers() do
		observar(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		for _, c in (observados[jogador] or {}) :: { RBXScriptConnection } do
			c:Disconnect()
		end
		observados[jogador] = nil
		if jogador.Character and ativos[jogador.Character] then
			destruir(ativos[jogador.Character])
			ativos[jogador.Character] = nil
		end
	end)
	local avisoAte = 0
	RunService:BindToRenderStep(
		"AurasExtravagantes",
		Enum.RenderPriority.Camera.Value + 1,
		function()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			local agora = os.clock()
			local posCamera = camera.CFrame.Position
			for personagem, inst in ativos do
				if personagem.Parent == nil or inst.raiz.Parent == nil then
					destruir(inst)
					ativos[personagem] = nil
					continue
				end
				local ok, erro = pcall(atualizar, inst, agora, posCamera)
				if not ok and agora > avisoAte then
					avisoAte = agora + 10
					warn("[Extravagancia] " .. tostring(erro))
				end
			end
			if agora < tremorAte then
				local f = tremorForca * (tremorAte - agora)
				camera.CFrame *= CFrame.new((math.random() - 0.5) * f, (math.random() - 0.5) * f, 0)
			end
		end
	)
end

return Mod
