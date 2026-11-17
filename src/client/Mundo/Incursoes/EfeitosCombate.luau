-- Efeitos do combate das Incursões (só visual, neste cliente). O servidor manda o evento
-- ("combate": técnica, esquiva, guarda, acerto...) e aqui se desenha. Tudo anima num único laço
-- de quadro; cada efeito vive frações de segundo e se destrói sozinho.
--
-- Kit genérico: pintado com a cor da aura (arcos de corte, esfera, onda, coluna do Despertar).
-- Gear 5: braços de borracha que esticam de verdade, Pistola com recuo, Gatling de punhos,
-- Punho do Trovão Gigante com raios e nuvens.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EfeitosCombate = {}

local BRANCO = Color3.new(1, 1, 1)
local BORRACHA = Color3.fromHex("F4F1FF") -- Gear 5: o corpo fica branco
local CONTORNO = Color3.fromHex("8F7BFF")
local RAIO = Color3.fromHex("FFF4B0")
local FAISCA = "rbxasset://textures/particles/sparkles_main.dds"
local FUMACA = "rbxasset://textures/particles/smoke_main.dds"

local MalhaNuvem = require(script.Parent.Parent:WaitForChild("Auras"):WaitForChild("MalhaNuvem"))
local Poses = require(script.Parent.Poses)

-- Malhas 3D dos efeitos (assets/combate, geradas no Blender; montadas no cliente sem importação)
local MALHAS = { "fx_corte", "fx_punho", "fx_esfera", "fx_onda", "fx_impacto" }
local malhasOk = true
local tamanhoBase: { [string]: Vector3 } = {}

type Efeito = { inicio: number, duracao: number, passo: (alfa: number) -> (), fim: (() -> ())? }

local ativos: { Efeito } = {}
local pasta: Folder
local escudos: { [number]: BasePart } = {}
local brilhos: { [number]: { Instance } } = {}
local reduzido = false
local baixa = false

local function novaPeca(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = pasta
	return p
end

-- Uma cópia da malha de efeito (nil se o EditableMesh não estiver disponível: cai nas peças simples)
local function malha(nome: string, cor: Color3, material: Enum.Material?): MeshPart?
	if not malhasOk then
		return nil
	end
	local ok, parte = pcall(function(): MeshPart
		local m = MalhaNuvem.criar(nome, false)
		return m
	end)
	if not ok or not parte then
		malhasOk = false
		warn(
			"[Combate] malhas de efeito indisponíveis, usando peças simples: " .. tostring(parte)
		)
		return nil
	end
	local m = parte :: MeshPart
	if not tamanhoBase[nome] then
		tamanhoBase[nome] = m.Size
	end
	m.Color = cor
	m.Material = material or Enum.Material.Neon
	m.Transparency = 0
	m.Parent = pasta
	return m
end

local function escalar(m: MeshPart, nome: string, fator: number)
	m.Size = (tamanhoBase[nome] or m.Size) * math.max(fator, 0.01)
end

local function animar(duracao: number, passo: (number) -> (), fim: (() -> ())?)
	local e = { inicio = os.clock(), duracao = duracao, passo = passo, fim = fim }
	passo(0)
	table.insert(ativos, e)
end

local function suave(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function rajada(
	pos: Vector3,
	cor: Color3,
	quantidade: number,
	velocidade: number,
	textura: string?,
	tamanho: number?
)
	if baixa then
		quantidade = math.ceil(quantidade / 3)
	end
	local a = novaPeca({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos) })
	local e = Instance.new("ParticleEmitter")
	e.Texture = textura or FAISCA
	e.Color = ColorSequence.new(cor, BRANCO)
	e.LightEmission = 1
	e.Size = NumberSequence.new(tamanho or 0.6, 0)
	e.Lifetime = NumberRange.new(0.25, 0.55)
	e.Speed = NumberRange.new(velocidade * 0.5, velocidade)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = a
	e:Emit(quantidade)
	task.delay(0.8, function()
		a:Destroy()
	end)
end

local function anel(centro: CFrame, raio: number, cor: Color3, duracao: number, espessura: number?)
	local p = novaPeca({ Shape = Enum.PartType.Cylinder, Color = cor, Transparency = 0.15 })
	animar(duracao, function(t)
		local r = raio * suave(t)
		p.Size = Vector3.new(espessura or 0.25, r * 2 + 0.5, r * 2 + 0.5)
		p.CFrame = centro * CFrame.Angles(0, 0, math.rad(90))
		p.Transparency = 0.15 + 0.85 * t
	end, function()
		p:Destroy()
	end)
end

local function esfera(
	pos: Vector3,
	raio: number,
	cor: Color3,
	duracao: number,
	material: Enum.Material?
)
	local p = novaPeca({
		Shape = Enum.PartType.Ball,
		Color = cor,
		Material = material or Enum.Material.Neon,
	})
	animar(duracao, function(t)
		p.Size = Vector3.one * (raio * 2 * suave(t) + 0.3)
		p.CFrame = CFrame.new(pos)
		p.Transparency = 0.2 + 0.8 * t
	end, function()
		p:Destroy()
	end)
end

-- Arco de corte (Beam curvo) na frente do corpo
local function corte(base: CFrame, raio: number, cor: Color3, inclinacao: number, largura: number)
	local suporte = novaPeca({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = base })
	local a0 = Instance.new("Attachment")
	local a1 = Instance.new("Attachment")
	local giro = CFrame.Angles(0, 0, inclinacao)
	a0.CFrame = giro * CFrame.new(-raio, 0, -raio * 0.35)
	a1.CFrame = giro * CFrame.new(raio, 0, -raio * 0.35)
	a0.Parent, a1.Parent = suporte, suporte
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.CurveSize0 = -raio * 1.1
	b.CurveSize1 = raio * 1.1
	b.FaceCamera = true
	b.LightEmission = 1
	b.Color = ColorSequence.new(BRANCO, cor)
	b.Width0, b.Width1 = largura * 0.2, largura
	b.Segments = 24
	b.Parent = suporte
	animar(0.22, function(t)
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(math.clamp(0.15 + t * 0.6, 0.02, 0.97), 0.05 + 0.9 * t),
			NumberSequenceKeypoint.new(1, 0.3 + 0.7 * t),
		})
	end, function()
		suporte:Destroy()
	end)
end

-- Raio em zigue-zague entre dois pontos
local function relampago(a: Vector3, b: Vector3, cor: Color3, duracao: number, espessura: number?)
	local partes = {}
	local n = 7
	local anterior = a
	for k = 1, n do
		local t = k / n
		local alvo = a:Lerp(b, t)
		if k < n then
			alvo += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (
				a - b
			).Magnitude * 0.12
		end
		local comp = (alvo - anterior).Magnitude
		table.insert(
			partes,
			novaPeca({
				Size = Vector3.new(espessura or 0.35, espessura or 0.35, comp),
				CFrame = CFrame.lookAt((anterior + alvo) / 2, alvo),
				Color = cor,
			})
		)
		anterior = alvo
	end
	animar(duracao, function(t)
		for _, p in partes do
			p.Transparency = if t < 0.5 then 0 else (t - 0.5) * 2
		end
	end, function()
		for _, p in partes do
			p:Destroy()
		end
	end)
end

local function corpoDe(userId: number?): (BasePart?, Model?)
	if not userId then
		return nil, nil
	end
	local p = Players:GetPlayerByUserId(userId)
	local c = p and p.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		return r, c
	end
	return nil, nil
end

local function ombro(personagem: Model?, raiz: BasePart, direito: boolean): Vector3
	local nome = if direito then "RightUpperArm" else "LeftUpperArm"
	local p = personagem
		and (
			personagem:FindFirstChild(nome)
			or personagem:FindFirstChild(if direito then "Right Arm" else "Left Arm")
		)
	if p and p:IsA("BasePart") then
		return (p.CFrame * CFrame.new(0, p.Size.Y * 0.35, 0)).Position
	end
	return (raiz.CFrame * CFrame.new(if direito then 1.5 else -1.5, 0.8, 0)).Position
end

local function mao(personagem: Model?, raiz: BasePart, direito: boolean): Vector3
	local p = personagem
		and (
			personagem:FindFirstChild(if direito then "RightHand" else "LeftHand")
			or personagem:FindFirstChild(if direito then "Right Arm" else "Left Arm")
		)
	if p and p:IsA("BasePart") then
		return (p.CFrame * CFrame.new(0, -p.Size.Y * 0.4, 0)).Position
	end
	return (raiz.CFrame * CFrame.new(if direito then 1.5 else -1.5, -0.6, -1)).Position
end

-- Estrela de impacto de desenho virada para a câmera
local function impacto(pos: Vector3, cor: Color3, tamanho: number)
	local m = malha("fx_impacto", cor)
	if not m then
		return
	end
	local giro = math.random() * math.pi * 2
	animar(0.22, function(t)
		local cam = Workspace.CurrentCamera
		local olho = if cam then cam.CFrame.Position else pos + Vector3.zAxis
		escalar(m, "fx_impacto", tamanho * (0.4 + 0.9 * suave(math.min(t * 2, 1))))
		m.CFrame = CFrame.lookAt(pos, olho) * CFrame.Angles(0, 0, giro)
		m.Transparency = if t < 0.5 then 0 else (t - 0.5) * 2
	end, function()
		m:Destroy()
	end)
end

-- ====================================================================== Gear 5

-- Braço de borracha: estica do ombro até o alvo e volta (com punho na ponta)
local function bracoElastico(
	de: () -> Vector3,
	ate: Vector3,
	grossura: number,
	punho: number,
	ida: number,
	volta: number,
	espera: number?
)
	local braco = novaPeca({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.SmoothPlastic,
		Color = BORRACHA,
	})
	local punho3d = malha("fx_punho", BORRACHA, Enum.Material.SmoothPlastic)
	local mao = punho3d
		or novaPeca({
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.SmoothPlastic,
			Color = BORRACHA,
		})
	local contorno = novaPeca({ Shape = Enum.PartType.Ball, Color = CONTORNO, Transparency = 0.6 })
	local total = ida + (espera or 0) + volta
	animar(total, function(t)
		local s = t * total
		local f = if s < ida
			then suave(s / ida)
			elseif s < ida + (espera or 0) then 1
			else 1 - suave((s - ida - (espera or 0)) / volta)
		local o = de()
		local ponta = o:Lerp(ate, f)
		local comp = math.max((ponta - o).Magnitude, 0.2)
		local fino = grossura * (1 - 0.45 * f) -- estica e afina
		braco.Size = Vector3.new(comp, fino, fino)
		braco.CFrame = CFrame.lookAt((o + ponta) / 2, ponta) * CFrame.Angles(0, math.rad(90), 0)
		local rumo = if (ate - o).Magnitude > 0.1 then (ate - o).Unit else Vector3.zAxis
		if punho3d then
			escalar(punho3d, "fx_punho", punho / 1.1)
			punho3d.CFrame = CFrame.lookAt(ponta, ponta + rumo)
			contorno.Size = Vector3.one * (punho * 0.4)
			contorno.CFrame = CFrame.new(ponta - rumo * punho * 0.3)
			contorno.Transparency = 1
		else
			mao.Size = Vector3.one * punho
			mao.CFrame = CFrame.new(ponta)
			contorno.Size = Vector3.one * (punho * 1.25)
			contorno.CFrame = mao.CFrame
		end
	end, function()
		braco:Destroy()
		mao:Destroy()
		contorno:Destroy()
	end)
end

local function nuvem(pos: Vector3, tamanho: number)
	for _ = 1, if baixa then 2 else 5 do
		local o = Vector3.new(math.random() - 0.5, math.random() * 0.5, math.random() - 0.5)
			* tamanho
		esfera(
			pos + o,
			tamanho * (0.3 + math.random() * 0.25),
			BORRACHA,
			0.6,
			Enum.Material.SmoothPlastic
		)
	end
end

local function gear5(d: { [string]: any })
	local raiz, personagem = corpoDe(d.userId)
	local origem: Vector3 = d.origem
	local dir: Vector3 = d.dir
	local cf = CFrame.lookAt(origem, origem + dir)
	local function ombroAgora(direito: boolean): () -> Vector3
		return function()
			if raiz and raiz.Parent then
				return ombro(personagem, raiz, direito)
			end
			return (cf * CFrame.new(if direito then 1.5 else -1.5, 0.8, 0)).Position
		end
	end
	if d.tecnica == "golpe" then
		local alcance = 13
		local direito = (d.combo or 1) % 2 == 1
		local alvo = (cf * CFrame.new(0, 0.6, -alcance)).Position
		bracoElastico(ombroAgora(direito), alvo, 0.9, 1.5, 0.09, 0.14)
		if d.combo == 3 then
			bracoElastico(
				ombroAgora(not direito),
				alvo + cf.RightVector * 0.8,
				0.9,
				1.5,
				0.09,
				0.14
			)
			task.delay(0.09, function()
				anel(CFrame.new(alvo, alvo + dir), 4, CONTORNO, 0.3)
				rajada(alvo, BRANCO, 14, 18)
			end)
		end
	elseif d.tecnica == "tecnica1" then
		-- Pistola: puxa o braço bem para trás (0,22 s) e solta
		local atras = (cf * CFrame.new(0.8, 0.8, 7)).Position
		bracoElastico(ombroAgora(true), atras, 1.0, 1.8, 0.18, 0.04)
		task.delay(0.22, function()
			local alvo = (cf * CFrame.new(0, 0.6, -42)).Position
			bracoElastico(ombroAgora(true), alvo, 1.1, 3.2, 0.12, 0.22, 0.06)
			task.delay(0.12, function()
				anel(CFrame.new(alvo, alvo + dir), 6, CONTORNO, 0.35, 0.5)
				esfera(alvo, 4, BRANCO, 0.3)
				rajada(alvo, CONTORNO, 22, 26)
			end)
			-- linhas de velocidade
			for k = 1, if baixa then 2 else 6 do
				local lado = (math.random() - 0.5) * 3
				local alto = (math.random() - 0.5) * 2
				local p = novaPeca({ Color = BRANCO, Size = Vector3.new(0.12, 0.12, 8) })
				local inicio = cf * CFrame.new(lado, 0.6 + alto, -3 - k * 4)
				animar(0.25, function(t)
					p.CFrame = inicio * CFrame.new(0, 0, -t * 20)
					p.Transparency = t
				end, function()
					p:Destroy()
				end)
			end
		end)
	elseif d.tecnica == "tecnica2" then
		-- Gatling: punhos para todo lado dentro do cone, por quase um segundo
		local n = if baixa then 10 else 26
		for k = 1, n do
			task.delay(0.1 + k * 0.034, function()
				local a = math.rad((math.random() - 0.5) * 60)
				local dist = 9 + math.random() * 8
				local alvo = (cf * CFrame.Angles(0, a, 0) * CFrame.new(
					0,
					0.2 + (math.random() - 0.3) * 2.5,
					-dist
				)).Position
				bracoElastico(ombroAgora(k % 2 == 0), alvo, 0.7, 1.3, 0.05, 0.07)
				if k % 4 == 0 then
					rajada(alvo, BRANCO, 5, 10)
				end
			end)
		end
	elseif d.tecnica == "despertar" then
		-- Punho do Trovão: nuvens, vento puxando, punho gigante sobe, raios, desce
		nuvem(origem + Vector3.new(0, 3, 0), 5)
		for k = 1, if baixa then 4 else 12 do
			local a = k / 12 * math.pi * 2
			local fora = origem + Vector3.new(math.cos(a), 0, math.sin(a)) * 24
			local p =
				novaPeca({ Color = BRANCO, Size = Vector3.new(0.15, 0.15, 6), Transparency = 0.3 })
			animar(0.6, function(t)
				local pos = fora:Lerp(origem, suave(t))
				p.CFrame = CFrame.lookAt(pos, origem)
				p.Transparency = 0.3 + 0.7 * t
			end, function()
				p:Destroy()
			end)
		end
		local alto = origem + Vector3.new(0, 26, 0)
		local impacto = (cf * CFrame.new(0, -2.6, -8)).Position
		local gigante = malha("fx_punho", BORRACHA, Enum.Material.SmoothPlastic)
		local punho = gigante
			or novaPeca({
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.SmoothPlastic,
				Color = BORRACHA,
			})
		local contorno =
			novaPeca({ Shape = Enum.PartType.Ball, Color = CONTORNO, Transparency = 0.55 })
		local antebraco = novaPeca({
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.SmoothPlastic,
			Color = BORRACHA,
		})
		animar(1.25, function(t)
			local s = t * 1.25
			local pos: Vector3
			local tam: number
			if s < 0.75 then -- sobe crescendo
				local f = suave(s / 0.75)
				pos = origem:Lerp(alto, f)
				tam = 2 + 12 * f
			elseif s < 0.9 then -- desce de uma vez
				local f = (s - 0.75) / 0.15
				pos = alto:Lerp(impacto + Vector3.new(0, 6, 0), f * f)
				tam = 14
			else
				pos = impacto + Vector3.new(0, 6, 0)
				tam = 14 * (1 - (s - 0.9) / 0.35)
			end
			if gigante then
				escalar(gigante, "fx_punho", tam / 1.1)
				gigante.CFrame = CFrame.lookAt(pos, pos - Vector3.yAxis, dir) -- punho para baixo
			else
				punho.Size = Vector3.one * tam
				punho.CFrame = CFrame.new(pos)
			end
			contorno.Size = Vector3.one * tam * 1.12
			contorno.CFrame = punho.CFrame
			local base = pos + Vector3.new(0, tam * 0.6, 0)
			antebraco.Size = Vector3.new(tam * 1.4, tam * 0.55, tam * 0.55)
			antebraco.CFrame = CFrame.lookAt(
				(pos + base) / 2 + Vector3.new(0, tam * 0.5, 0),
				base + Vector3.new(0, tam, 0)
			) * CFrame.Angles(0, math.rad(90), 0)
			antebraco.Transparency = if s > 0.9 then (s - 0.9) / 0.35 else 0
			punho.Transparency = antebraco.Transparency
		end, function()
			punho:Destroy()
			contorno:Destroy()
			antebraco:Destroy()
		end)
		for k = 1, if baixa then 2 else 5 do
			task.delay(0.15 * k, function()
				local de = alto
					+ Vector3.new((math.random() - 0.5) * 30, 25, (math.random() - 0.5) * 30)
				relampago(de, alto + Vector3.new(0, 4, 0), RAIO, 0.25, 0.5)
			end)
		end
		task.delay(0.9, function()
			anel(CFrame.new(impacto), 24, BRANCO, 0.5, 0.8)
			anel(CFrame.new(impacto), 16, CONTORNO, 0.4, 1.2)
			esfera(impacto, 9, RAIO, 0.35)
			nuvem(impacto + Vector3.new(0, 2, 0), 10)
			rajada(impacto, RAIO, 40, 40, nil, 1.2)
			for k = 1, if baixa then 3 else 8 do
				local a = k / 8 * math.pi * 2
				relampago(
					impacto,
					impacto + Vector3.new(math.cos(a) * 20, 1, math.sin(a) * 20),
					RAIO,
					0.3,
					0.4
				)
			end
		end)
	end
end

-- ====================================================================== kit genérico

-- Malhas 3D do kit genérico: saem do corpo (mão, peito) e somam aos efeitos de peça
local function genericoMalhas(d: { [string]: any }, cf: CFrame, cor: Color3)
	local raiz, personagem = corpoDe(d.userId)
	local function daMao(direito: boolean): Vector3
		if raiz and raiz.Parent then
			return mao(personagem, raiz, direito)
		end
		return (cf * CFrame.new(if direito then 1.5 else -1.5, -0.6, -1)).Position
	end
	if d.tecnica == "golpe" then
		local k = d.combo or 1
		local m = malha("fx_corte", cor)
		if m then
			local de, ate, incl = math.rad(55), math.rad(-55), math.rad(-20)
			if k == 2 then
				de, ate, incl = math.rad(-55), math.rad(55), math.rad(20)
			elseif k == 3 then
				de, ate, incl = math.rad(70), math.rad(-70), math.rad(80)
			end
			local escala = if k == 3 then 1.35 else 1
			animar(0.26, function(t)
				local a = de + (ate - de) * suave(math.min(t * 1.6, 1))
				escalar(m, "fx_corte", escala * (0.7 + 0.3 * t))
				m.CFrame = cf
					* CFrame.new(0, 0.4, -0.5)
					* CFrame.Angles(0, 0, incl)
					* CFrame.Angles(0, a, 0)
				m.Transparency = if t < 0.45 then 0.05 else (t - 0.45) / 0.55
			end, function()
				m:Destroy()
			end)
		end
		local p = daMao(k ~= 2)
		esfera(p, 0.8, cor, 0.15)
	elseif d.tecnica == "tecnica1" then
		-- a esfera nasce na mão direita, gira carregando e sai voando
		local m = malha("fx_esfera", cor)
		if m then
			local giro = 0
			animar(0.5, function(t)
				local s = t * 0.5
				giro += 0.35
				local pos: Vector3
				local tam: number
				if s < 0.12 then
					pos = daMao(true)
					tam = 0.3 + 0.6 * s / 0.12
				else
					local inicio = daMao(true)
					pos = inicio + cf.LookVector * 44 * suave((s - 0.12) / 0.38)
					tam = 0.9
				end
				escalar(m, "fx_esfera", tam)
				m.CFrame = CFrame.new(pos) * CFrame.Angles(giro, giro * 0.7, 0)
			end, function()
				local fim = m.Position
				m:Destroy()
				impacto(fim, cor, 3.5)
			end)
		end
	elseif d.tecnica == "tecnica2" then
		for k = 0, 1 do
			task.delay(0.16 + k * 0.08, function()
				local m = malha("fx_onda", cor)
				if not m then
					return
				end
				local base = cf * CFrame.new(0, 0.6, -1.5)
				animar(0.4, function(t)
					local f = suave(t)
					escalar(m, "fx_onda", 0.6 + 2.2 * f)
					m.CFrame = base * CFrame.new(0, 0, -3 - 10 * f)
					m.Transparency = 0.1 + 0.9 * t
				end, function()
					m:Destroy()
				end)
			end)
		end
	elseif d.tecnica == "despertar" then
		local m = malha("fx_onda", cor)
		if m then
			-- cone de energia subindo do chão em volta do corpo
			local chao = CFrame.new(d.origem - Vector3.new(0, 2.8, 0))
				* CFrame.Angles(math.rad(90), 0, 0)
			animar(0.7, function(t)
				escalar(m, "fx_onda", 1 + 2.5 * suave(t))
				m.CFrame = chao * CFrame.Angles(0, 0, t * 4)
				m.Transparency = 0.1 + 0.9 * t
			end, function()
				m:Destroy()
			end)
		end
		task.delay(0.45, function()
			local e = malha("fx_esfera", cor)
			if e then
				animar(0.45, function(t)
					escalar(e, "fx_esfera", 1 + 8 * suave(t))
					e.CFrame = CFrame.new(d.origem) * CFrame.Angles(t * 2, t * 3, 0)
					e.Transparency = 0.2 + 0.8 * t
				end, function()
					e:Destroy()
				end)
			end
		end)
	end
end

local function generico(d: { [string]: any })
	local cor: Color3 = if typeof(d.cor) == "Color3" then d.cor else Color3.fromHex("C9B8FF")
	local origem: Vector3 = d.origem
	local dir: Vector3 = d.dir
	local cf = CFrame.lookAt(origem, origem + dir)
	genericoMalhas(d, cf, cor)
	if d.tecnica == "golpe" then
		local k = d.combo or 1
		local incl = ({ math.rad(-25), math.rad(25), math.rad(0) })[k] or 0
		corte(
			cf * CFrame.new(0, 0.3, -2.5),
			if k == 3 then 5 else 4,
			cor,
			incl,
			if k == 3 then 2.6 else 1.6
		)
		if k == 3 then
			anel(cf * CFrame.new(0, 0.3, -5) * CFrame.Angles(math.rad(90), 0, 0), 4, cor, 0.25)
			rajada((cf * CFrame.new(0, 0.3, -5)).Position, cor, 12, 16)
		end
	elseif d.tecnica == "tecnica1" then
		-- Esfera de Aura: carrega na mão e voa reto
		local bola = novaPeca({ Shape = Enum.PartType.Ball, Color = cor })
		local nucleo = novaPeca({ Shape = Enum.PartType.Ball, Color = BRANCO })
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.9, 0), Vector3.new(0, -0.9, 0)
		a0.Parent, a1.Parent = bola, bola
		local rastro = Instance.new("Trail")
		rastro.Attachment0, rastro.Attachment1 = a0, a1
		rastro.Color = ColorSequence.new(cor)
		rastro.LightEmission = 1
		rastro.Lifetime = 0.25
		rastro.Transparency = NumberSequence.new(0.2, 1)
		rastro.Parent = bola
		local inicio = cf * CFrame.new(0.8, 0.6, -2)
		animar(0.5, function(t)
			local s = t * 0.5
			local pos: Vector3
			if s < 0.12 then
				pos = inicio.Position
				bola.Size = Vector3.one * (0.5 + 2 * s / 0.12)
			else
				pos = (inicio * CFrame.new(0, 0, -44 * suave((s - 0.12) / 0.38))).Position
				bola.Size = Vector3.one * 2.5
			end
			bola.CFrame = CFrame.new(pos)
			nucleo.CFrame = bola.CFrame
			nucleo.Size = bola.Size * 0.5
		end, function()
			local fim = bola.Position
			bola:Destroy()
			nucleo:Destroy()
			esfera(fim, 3.5, cor, 0.3)
			rajada(fim, cor, 16, 20)
		end)
	elseif d.tecnica == "tecnica2" then
		-- Onda Ressonante: três arcos que avançam e abrem em leque
		for k = 0, 2 do
			task.delay(0.18 + k * 0.06, function()
				local suporte = cf * CFrame.new(0, 0.2 - k * 0.4, -1)
				local p = novaPeca({ Color = cor, Transparency = 0.2 })
				animar(0.35, function(t)
					local dist = 2 + 15 * suave(t)
					p.Size = Vector3.new(dist * 1.6, 0.6 + k * 0.2, 0.5)
					p.CFrame = suporte * CFrame.new(0, 0, -dist)
					p.Transparency = 0.2 + 0.8 * t
				end, function()
					p:Destroy()
				end)
			end)
		end
		task.delay(0.2, function()
			rajada((cf * CFrame.new(0, 0, -8)).Position, cor, 24, 24, FUMACA, 1.4)
		end)
	elseif d.tecnica == "despertar" then
		-- Despertar: coluna de luz, anéis convergindo, explosão
		local coluna = novaPeca({ Shape = Enum.PartType.Cylinder, Color = cor })
		animar(0.75, function(t)
			local larg = if t < 0.6 then 1 + 5 * t else 4 * (1 - (t - 0.6) / 0.4)
			coluna.Size = Vector3.new(60, larg, larg)
			coluna.CFrame = CFrame.new(origem + Vector3.new(0, 27, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			coluna.Transparency = 0.2 + 0.6 * t
		end, function()
			coluna:Destroy()
		end)
		for k = 1, 3 do
			local p = novaPeca({ Shape = Enum.PartType.Cylinder, Color = BRANCO })
			animar(0.45, function(t)
				local r = 18 * (1 - suave(t)) + 1
				p.Size = Vector3.new(0.3, r * 2, r * 2)
				p.CFrame = CFrame.new(origem + Vector3.new(0, -2.4 + k * 1.5, 0))
					* CFrame.Angles(0, 0, math.rad(90))
				p.Transparency = 0.3 + 0.5 * t
			end, function()
				p:Destroy()
			end)
		end
		task.delay(0.45, function()
			esfera(origem, 18, cor, 0.45)
			anel(CFrame.new(origem - Vector3.new(0, 2.6, 0)), 22, BRANCO, 0.5, 0.6)
			rajada(origem, cor, 50, 45, nil, 1.1)
		end)
	end
end

-- Brilho de Despertado em volta do personagem enquanto durar
local function despertado(userId: number, cor: Color3, duracao: number)
	local raiz = corpoDe(userId)
	if not raiz then
		return
	end
	for _, i in (brilhos[userId] or {}) :: { Instance } do
		i:Destroy()
	end
	local luz = Instance.new("PointLight")
	luz.Color = cor
	luz.Range = 12
	luz.Brightness = 2
	luz.Parent = raiz
	local e = Instance.new("ParticleEmitter")
	e.Texture = FAISCA
	e.Color = ColorSequence.new(cor, BRANCO)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Rate = if baixa then 6 else 22
	e.Speed = NumberRange.new(2, 5)
	e.Acceleration = Vector3.new(0, 6, 0)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = raiz
	brilhos[userId] = { luz, e }
	task.delay(duracao, function()
		if brilhos[userId] and brilhos[userId][1] == luz then
			luz:Destroy()
			e:Destroy()
			brilhos[userId] = nil
		end
	end)
end

-- ====================================================================== entrada

function EfeitosCombate.evento(d: { [string]: any }, kitDuracao: (string) -> number)
	if not pasta then
		return
	end
	local acao = d.acao
	if acao == "tecnica" and typeof(d.origem) == "Vector3" and typeof(d.dir) == "Vector3" then
		-- o corpo se mexe junto (Gear 5: o braço real some enquanto o de borracha estica)
		local g5 = d.kit == "gear5"
		if d.tecnica == "golpe" then
			local k = d.combo or 1
			local lado = if k == 2 then "esquerdo" elseif k == 3 then "ambos" else "direito"
			Poses.tocar(
				d.userId,
				"golpe" .. k,
				if k == 3 then 0.42 else 0.3,
				if g5 then lado else nil
			)
		elseif d.tecnica == "tecnica1" then
			Poses.tocar(d.userId, "carga", if g5 then 0.75 else 0.55, if g5 then "direito" else nil)
		elseif d.tecnica == "tecnica2" then
			Poses.tocar(
				d.userId,
				if g5 then "rajada" else "varrer",
				if g5 then 1.05 else 0.5,
				if g5 then "ambos" else nil
			)
		elseif d.tecnica == "despertar" then
			Poses.tocar(d.userId, "despertar", if g5 then 1.3 else 0.9)
		end
		if d.kit == "gear5" then
			gear5(d)
		else
			generico(d)
		end
		if d.tecnica == "despertar" and type(d.userId) == "number" then
			local cor = if d.kit == "gear5"
				then BORRACHA
				elseif typeof(d.cor) == "Color3" then d.cor
				else BRANCO
			despertado(d.userId, cor, kitDuracao(d.kit))
		end
	elseif acao == "acerto" and type(d.alvos) == "table" then
		local cor = if d.kit == "gear5"
			then BRANCO
			elseif typeof(d.cor) == "Color3" then d.cor
			else BRANCO
		for _, pos in d.alvos do
			if typeof(pos) == "Vector3" then
				local centro = pos + Vector3.new(0, 2.5, 0)
				esfera(centro, if d.tecnica == "despertar" then 3 else 1.6, cor, 0.18)
				rajada(centro, cor, if d.tecnica == "golpe" then 4 else 8, 12)
				impacto(
					centro,
					if d.kit == "gear5" then RAIO else cor,
					if d.tecnica == "golpe" then 2.2 else 3.2
				)
			end
		end
	elseif acao == "esquiva" and typeof(d.origem) == "Vector3" and typeof(d.dir) == "Vector3" then
		Poses.tocar(d.userId, "esquiva", 0.3)
		local cor = if d.kit == "gear5"
			then BORRACHA
			elseif typeof(d.cor) == "Color3" then d.cor
			else BRANCO
		local cf = CFrame.lookAt(d.origem, d.origem + d.dir)
		-- três imagens que ficam para trás
		for k = 0, 2 do
			local p = novaPeca({ Color = cor, Size = Vector3.new(2, 4.6, 1), Transparency = 0.4 })
			local pos = cf * CFrame.new(0, 0, k * 2.2)
			animar(0.3 + k * 0.05, function(t)
				p.CFrame = pos
				p.Transparency = 0.45 + 0.55 * t
			end, function()
				p:Destroy()
			end)
		end
		if d.kit == "gear5" then
			anel(CFrame.new(d.origem - Vector3.new(0, 2.6, 0)), 5, CONTORNO, 0.3)
			nuvem(d.origem - Vector3.new(0, 2, 0), 3)
		else
			rajada(d.origem - Vector3.new(0, 2.4, 0), cor, 10, 8, FUMACA, 1)
		end
	elseif acao == "guarda" and type(d.userId) == "number" then
		Poses.manter(d.userId, "guarda", d.ligada == true)
		local antigo = escudos[d.userId]
		if antigo then
			antigo:Destroy()
			escudos[d.userId] = nil
		end
		if d.ligada then
			local raiz = corpoDe(d.userId)
			if raiz then
				local cor = if typeof(d.cor) == "Color3" then d.cor else BRANCO
				local p = novaPeca({
					Shape = Enum.PartType.Ball,
					Material = Enum.Material.ForceField,
					Color = cor,
					Size = Vector3.new(6, 6, 6),
				})
				p.Anchored = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				p.CFrame = raiz.CFrame * CFrame.new(0, 0.3, -1)
				w.Part0, w.Part1 = p, raiz
				w.Parent = p
				escudos[d.userId] = p
			end
		end
	elseif acao == "guardaQuebrou" and typeof(d.origem) == "Vector3" then
		rajada(d.origem, BRANCO, 18, 16)
		anel(CFrame.new(d.origem), 5, Color3.fromHex("FF6B6B"), 0.3)
	elseif acao == "aparou" and typeof(d.origem) == "Vector3" then
		rajada(
			d.origem + Vector3.new(0, 1, 0),
			if typeof(d.cor) == "Color3" then d.cor else BRANCO,
			8,
			12
		)
	elseif acao == "esquivou" and typeof(d.origem) == "Vector3" then
		anel(CFrame.new(d.origem), 3, BRANCO, 0.25)
	elseif acao == "critico" and typeof(d.origem) == "Vector3" and not reduzido then
		local suporte = novaPeca({
			Size = Vector3.one * 0.2,
			Transparency = 1,
			CFrame = CFrame.new(d.origem + Vector3.new(0, 5, 0)),
		})
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 50)
		bb.AlwaysOnTop = true
		bb.Parent = suporte
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.fromHex("FFD36B")
		t.TextStrokeTransparency = 0.2
		t.Text = string.format("CRÍTICO %d", tonumber(d.valor) or 0)
		t.Parent = bb
		animar(0.7, function(a)
			suporte.CFrame = CFrame.new(d.origem + Vector3.new(0, 5 + 2 * a, 0))
			t.TextTransparency = math.max(0, (a - 0.5) * 2)
		end, function()
			suporte:Destroy()
		end)
	end
end

function EfeitosCombate.definirQualidade(qualidadeBaixa: boolean, movimentoReduzido: boolean)
	baixa = qualidadeBaixa
	reduzido = movimentoReduzido
end

function EfeitosCombate.limpar()
	Poses.limpar()
	for _, e in ativos do
		if e.fim then
			e.fim()
		end
	end
	table.clear(ativos)
	for k, p in escudos do
		p:Destroy()
		escudos[k] = nil
	end
	for k, lista in brilhos do
		for _, i in lista do
			i:Destroy()
		end
		brilhos[k] = nil
	end
end

function EfeitosCombate.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "EfeitosCombate"
	pasta.Parent = Workspace
	Poses.iniciar()
	-- converte as malhas uma vez já na entrada (a primeira conversão espera um pouco)
	task.spawn(function()
		for _, nome in MALHAS do
			local m = malha(nome, BRANCO)
			if m then
				m:Destroy()
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local agora = os.clock()
		for i = #ativos, 1, -1 do
			local e = ativos[i]
			local t = math.clamp((agora - e.inicio) / e.duracao, 0, 1)
			e.passo(t)
			if t >= 1 then
				table.remove(ativos, i)
				if e.fim then
					e.fim()
				end
			end
		end
	end)
end

return EfeitosCombate
