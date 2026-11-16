-- Animação de "despertar" no personagem de quem tirou uma aura rara.
-- Roda em TODOS os clientes (o servidor avisa pelo remote "Despertou"), então todo mundo vê.
-- A pose é feita por código: deslocamos o C0 das juntas (Motor6D) por cima da animação normal,
-- sem precisar enviar nenhuma animação. Tudo criado aqui é local e é limpo no final.
--
-- Linha do tempo (Épico para cima), igual ao storyboard:
--   0,0-0,6 CARGA     partículas sugadas, cabeça baixa
--   0,6-1,6 TENSÃO    flutua, anéis pulsam subindo de cor até a raridade sorteada
--   1,6-2,0 EXPLOSÃO  braços abrem, onda de choque, pilar de luz
--   2,0-fim TÍTULO    segura a pose e volta ao normal no último meio segundo
-- Raro: só a explosão (0,6 s). Mítico/Divino: 5 s e o céu escurece.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Auras = require(ReplicatedStorage.Shared.Dados.Auras)

local Despertar = {}

Despertar.CARGA = 0.6
Despertar.TENSAO = 1.6
Despertar.EXPLOSAO = 2.0
Despertar.TIER_RARO = 3
Despertar.TIER_CUTSCENE = 4 -- Épico
Despertar.TIER_CEU = 6 -- Mítico

local TEXTURA_BRILHO = "rbxasset://textures/particles/sparkles_main.dds"

-- Duração total da animação para uma aura (0 = sem animação)
function Despertar.duracao(aura: Auras.Aura): number
	if aura.tier >= Despertar.TIER_CEU then
		return 5
	elseif aura.tier >= Despertar.TIER_CUTSCENE then
		return 3.5
	elseif aura.tier >= Despertar.TIER_RARO then
		return 0.6
	end
	return 0
end

-- Poses alvo (deslocamentos do C0) para avatares R15. Ajuste os ângulos aqui se precisar.
local POSES = {
	Root = {
		carga = CFrame.new(),
		tensao = CFrame.new(0, 1.6, 0),
		explosao = CFrame.new(0, 2.2, 0),
	},
	Neck = {
		carga = CFrame.Angles(math.rad(-22), 0, 0),
		tensao = CFrame.Angles(math.rad(-10), 0, 0),
		explosao = CFrame.Angles(math.rad(18), 0, 0),
	},
	Waist = {
		carga = CFrame.Angles(math.rad(-12), 0, 0),
		tensao = CFrame.new(),
		explosao = CFrame.Angles(math.rad(10), 0, 0),
	},
	RightShoulder = {
		carga = CFrame.Angles(0, 0, math.rad(-10)),
		tensao = CFrame.Angles(0, 0, math.rad(35)),
		explosao = CFrame.Angles(0, 0, math.rad(105)),
	},
	LeftShoulder = {
		carga = CFrame.Angles(0, 0, math.rad(10)),
		tensao = CFrame.Angles(0, 0, math.rad(-35)),
		explosao = CFrame.Angles(0, 0, math.rad(-105)),
	},
}

type Junta = { motor: Motor6D, original: CFrame, pose: { [string]: CFrame } }

-- Uma animação ativa por personagem: a nova cancela a anterior
local ativos: { [Model]: () -> () } = {}

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function coletarJuntas(personagem: Model): { Junta }
	local juntas = {}
	for nome, pose in POSES do
		local motor = personagem:FindFirstChild(nome, true)
		if motor and motor:IsA("Motor6D") then
			table.insert(juntas, { motor = motor, original = motor.C0, pose = pose })
		end
	end
	return juntas
end

local function peca(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

-- Cilindro deitado (anel no chão). O eixo do cilindro no Roblox é o X.
local function anelChao(pasta: Instance, cor: Color3): Part
	return peca({
		Name = "Anel",
		Shape = Enum.PartType.Cylinder,
		Color = cor,
		Transparency = 0.4,
		Size = Vector3.new(0.15, 6, 6),
		Parent = pasta,
	})
end

function Despertar.tocar(personagem: Model, aura: Auras.Aura)
	local duracao = Despertar.duracao(aura)
	if duracao <= 0 then
		return
	end
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if not raiz or not raiz:IsA("BasePart") or not humanoide then
		return
	end
	if ativos[personagem] then
		ativos[personagem]()
	end

	local completo = aura.tier >= Despertar.TIER_CUTSCENE
	-- Tempos da linha do tempo (o Raro pula direto para a explosão)
	local tCarga = if completo then Despertar.CARGA else 0
	local tTensao = if completo then Despertar.TENSAO else 0
	local tExplosao = if completo then Despertar.EXPLOSAO else 0.15
	local tVolta = duracao - 0.5

	local cor = Color3.fromHex(Auras.Tiers[aura.tier].cor)
	local corAura = Color3.fromHex(aura.cores[1])
	local juntas = coletarJuntas(personagem)
	local pasta = Instance.new("Folder")
	pasta.Name = "EfeitoDespertar"
	pasta.Parent = workspace

	local alturaPes = raiz.Size.Y / 2
		+ (if humanoide.RigType == Enum.HumanoidRigType.R15 then humanoide.HipHeight else 2)

	-- Partículas sugadas para o personagem (Épico+): esfera emitindo para dentro
	local esfera: Part? = nil
	if completo then
		local e = peca({
			Name = "Implosao",
			Shape = Enum.PartType.Ball,
			Transparency = 1,
			Size = Vector3.new(14, 14, 14),
			Parent = pasta,
		})
		local emissor = Instance.new("ParticleEmitter")
		emissor.Texture = TEXTURA_BRILHO
		emissor.Color = ColorSequence.new(corAura, cor)
		emissor.LightEmission = 1
		emissor.Size = NumberSequence.new(0.5, 0.1)
		emissor.Lifetime = NumberRange.new(0.5, 0.7)
		emissor.Speed = NumberRange.new(10, 14)
		emissor.Rate = 70
		emissor.Shape = Enum.ParticleEmitterShape.Sphere
		emissor.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		emissor.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		emissor.Parent = e
		esfera = e
	end

	-- Anéis nos pés (pulsam na tensão)
	local anel1 = anelChao(pasta, Color3.fromHex(Auras.Tiers[Despertar.TIER_RARO].cor))
	local anel2 = anelChao(pasta, cor)
	anel1.Transparency, anel2.Transparency = 1, 1

	-- Explosão: partículas, onda de choque e (Épico+) pilar de luz
	local anexo = Instance.new("Attachment")
	anexo.Name = "EfeitoDespertar"
	anexo.Parent = raiz
	local estouro = Instance.new("ParticleEmitter")
	estouro.Texture = TEXTURA_BRILHO
	estouro.Color = ColorSequence.new(cor, corAura)
	estouro.LightEmission = 1
	estouro.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	estouro.Lifetime = NumberRange.new(0.6, 1.1)
	estouro.Speed = NumberRange.new(18, 30)
	estouro.SpreadAngle = Vector2.new(180, 180)
	estouro.Drag = 4
	estouro.Rate = 0
	estouro.Parent = anexo
	local onda = anelChao(pasta, cor)
	onda.Transparency = 1
	local pilar: Part? = nil
	if completo then
		local p = peca({
			Name = "Pilar",
			Shape = Enum.PartType.Cylinder,
			Color = cor,
			Transparency = 1,
			Size = Vector3.new(400, 5, 5),
			Parent = pasta,
		})
		local luz = Instance.new("PointLight")
		luz.Color = cor
		luz.Range = 30
		luz.Brightness = 4
		luz.Parent = p
		pilar = p
	end

	-- Céu escurece para todos (Mítico/Divino)
	local ceu: ColorCorrectionEffect? = nil
	if aura.tier >= Despertar.TIER_CEU then
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "CeuDespertar"
		c.Parent = Lighting
		ceu = c
	end

	-- Escada de cores da tensão: Raro -> ... -> raridade sorteada
	local escada = {}
	for t = Despertar.TIER_RARO, aura.tier do
		table.insert(escada, Color3.fromHex(Auras.Tiers[t].cor))
	end

	local inicio = os.clock()
	local explodiu = false
	local conexao: RBXScriptConnection

	local function finalizar()
		if ativos[personagem] ~= finalizar then
			return
		end
		ativos[personagem] = nil
		conexao:Disconnect()
		for _, j in juntas do
			if j.motor.Parent then
				j.motor.C0 = j.original
			end
		end
		pasta:Destroy()
		anexo:Destroy()
		if ceu then
			ceu:Destroy()
		end
	end
	ativos[personagem] = finalizar

	local function aplicarPose(nome: string, peso: number, de: string?)
		for _, j in juntas do
			local alvo = j.pose[nome] or CFrame.new()
			local origem = if de then j.pose[de] or CFrame.new() else CFrame.new()
			j.motor.C0 = j.original * origem:Lerp(alvo, peso)
		end
	end

	conexao = RunService.Heartbeat:Connect(function()
		if not raiz.Parent then
			finalizar()
			return
		end
		local t = os.clock() - inicio
		if t >= duracao then
			finalizar()
			return
		end
		local pes = raiz.Position - Vector3.new(0, alturaPes - 0.1, 0)
		local deitado = CFrame.Angles(0, 0, math.rad(90))

		-- Pose
		if t < tCarga then
			aplicarPose("carga", suave(t / tCarga))
		elseif t < tTensao then
			aplicarPose("tensao", suave((t - tCarga) / (tTensao - tCarga)), "carga")
		elseif t < tVolta then
			local de = if completo then "tensao" else nil
			aplicarPose("explosao", suave((t - tTensao) / 0.18), de)
		else
			local volta = 1 - suave((t - tVolta) / 0.5)
			aplicarPose("explosao", volta)
		end

		-- Implosão acompanha o personagem e para na explosão
		if esfera then
			esfera.CFrame = raiz.CFrame
			local emissor = esfera:FindFirstChildOfClass("ParticleEmitter")
			if emissor then
				emissor.Enabled = t < tTensao
			end
		end

		-- Anéis da tensão: pulsam e sobem de cor
		if completo and t >= tCarga and t < tExplosao then
			local f = (t - tCarga) / (tTensao - tCarga)
			local indice = math.clamp(math.floor(f * #escada) + 1, 1, #escada)
			local pulso = 0.5 + 0.5 * math.sin(t * 18)
			anel1.Color = escada[indice]
			anel1.Transparency = 0.3 + 0.3 * pulso
			anel1.Size = Vector3.new(0.15, 5 + pulso * 1.5, 5 + pulso * 1.5)
			anel1.CFrame = CFrame.new(pes) * deitado
			anel2.Color = escada[indice]
			anel2.Transparency = 0.5
			anel2.Size = Vector3.new(0.15, 8 + f * 4, 8 + f * 4)
			anel2.CFrame = CFrame.new(pes + Vector3.new(0, 0.05, 0)) * deitado
		else
			anel1.Transparency, anel2.Transparency = 1, 1
		end

		-- Explosão
		if t >= tTensao and not explodiu then
			explodiu = true
			estouro:Emit(if completo then 90 else 45)
		end
		if t >= tTensao then
			local f = math.clamp((t - tTensao) / 0.6, 0, 1)
			local diametro = 4 + f * (if completo then 40 else 18)
			onda.Transparency = 0.15 + 0.85 * f
			onda.Size = Vector3.new(0.15, diametro, diametro)
			onda.CFrame = CFrame.new(pes) * deitado
			if pilar then
				local g = math.clamp((t - tTensao) / (duracao - tTensao), 0, 1)
				pilar.Transparency = 0.25 + 0.75 * g
				pilar.CFrame = CFrame.new(raiz.Position + Vector3.new(0, 190, 0)) * deitado
			end
		end

		-- Céu: escurece na tensão, volta no final
		if ceu then
			local escuro = if t < tVolta then suave(t / tTensao) else 1 - suave((t - tVolta) / 0.5)
			ceu.Brightness = -0.35 * escuro
			ceu.Saturation = -0.3 * escuro
			ceu.TintColor = Color3.new(1, 1, 1):Lerp(cor, 0.35 * escuro)
		end
	end)
end

-- Cancela a animação de um personagem (ex.: o dono pulou a cena)
function Despertar.cancelar(personagem: Model)
	local fn = ativos[personagem]
	if fn then
		fn()
	end
end

return Despertar
