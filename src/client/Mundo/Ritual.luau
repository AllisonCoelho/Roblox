-- Encenação 3D do giro "Ritual + Ruptura" em volta de um personagem.
-- Tudo é criado localmente (cada cliente monta o seu) e limpo no final, na morte, no respawn,
-- na saída do jogador ou quando outro ritual começa no mesmo personagem.
--
--   Chamado       um núcleo de energia nasce à frente do peito
--   Ressonância   anéis e satélites orbitam o núcleo, cada vez mais rápido
--   Instabilidade o núcleo vibra em batidas que aceleram; cada batida abre uma rachadura
--   Ruptura       o núcleo se contrai, há um instante de silêncio e os anéis se partem
--   Revelação     chama `aoRevelar` (a interface mostra o nome) e os efeitos somem
--
-- O personagem acompanha (Motion): nas raridades comuns faz um gesto curto; nas altas ele
-- alcança a energia, agarra, força e RASGA uma fenda no ar (Fenda), de onde sai a ruptura.
--
-- Os anéis são Beams curvos (4 arcos de Bézier formam um círculo), então são leves:
-- nenhuma malha, nenhum asset, poucas instâncias.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Trilha = require(Shared.Dados.Trilha)
local Fenda = require(script.Parent.Fenda)
local Motion = require(script.Parent.Motion)
local Sons = require(script.Parent.Sons)

local Ritual = {}

export type Opcoes = {
	categoria: Apresentacao.Categoria,
	completo: boolean, -- true = quem girou; false = versão abreviada para os outros
	qualidadeBaixa: boolean,
	movimentoReduzido: boolean,
	aoRevelar: (() -> ())?,
}

local TEXTURA_BRILHO = "rbxasset://textures/particles/sparkles_main.dds"
local K_CIRCULO = 0.5523 -- fator de Bézier para 4 arcos formarem um círculo
local BRANCO = Color3.new(1, 1, 1)

local ALTURA_FLUTUAR = 1.8

type Anel = {
	base: Part,
	anexos: { Attachment },
	feixes: { Beam },
	raio: number,
	inclinacao: CFrame,
	velocidade: number,
	angulo: number,
	satelites: { Part },
}

local ativos: { [Model]: () -> () } = {}

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
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

local function definirRaio(anel: Anel, raio: number)
	anel.raio = raio
	for k = 1, 4 do
		local a = (k - 1) * math.pi / 2
		local pos = Vector3.new(math.cos(a) * raio, 0, math.sin(a) * raio)
		local tangente = Vector3.new(-math.sin(a), 0, math.cos(a))
		anel.anexos[k].CFrame = CFrame.fromMatrix(pos, tangente, Vector3.yAxis)
	end
	for _, feixe in anel.feixes do
		feixe.CurveSize0 = K_CIRCULO * raio
		feixe.CurveSize1 = K_CIRCULO * raio
	end
end

local function definirTransparencia(anel: Anel, t: number)
	local seq = NumberSequence.new(math.clamp(t, 0, 1))
	for _, feixe in anel.feixes do
		feixe.Transparency = seq
	end
	for _, s in anel.satelites do
		s.Transparency = math.clamp(t, 0, 1)
	end
end

-- arcos: 4 = círculo fechado; 3 = círculo com uma abertura (deixa a rotação visível)
local function criarAnel(
	pasta: Instance,
	cor: ColorSequence,
	largura: number,
	arcos: number,
	segmentos: number
): Anel
	local base =
		peca({ Name = "Anel", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Parent = pasta })
	local anexos = {}
	for k = 1, 4 do
		local a = Instance.new("Attachment")
		a.Parent = base
		anexos[k] = a
	end
	local feixes = {}
	for k = 1, arcos do
		local feixe = Instance.new("Beam")
		feixe.Attachment0 = anexos[k]
		feixe.Attachment1 = anexos[k % 4 + 1]
		feixe.Color = cor
		feixe.Width0 = largura
		feixe.Width1 = largura
		feixe.LightEmission = 1
		feixe.LightInfluence = 0
		feixe.FaceCamera = true
		feixe.Segments = segmentos
		feixe.Parent = base
		feixes[k] = feixe
	end
	local anel: Anel = {
		base = base,
		anexos = anexos,
		feixes = feixes,
		raio = 0,
		inclinacao = CFrame.new(),
		velocidade = 0,
		angulo = 0,
		satelites = {},
	}
	definirRaio(anel, 0.01)
	return anel
end

-- Estouro final: independe do laço do ritual (usa tweens e se limpa sozinho)
local function estourar(
	centro: Vector3,
	pes: Vector3,
	categoria: Apresentacao.Categoria,
	cor: Color3,
	corAura: Color3,
	baixa: boolean
)
	local pasta = Instance.new("Folder")
	pasta.Name = "RupturaDespertar"
	pasta.Parent = workspace
	Debris:AddItem(pasta, 3)
	local deitado = CFrame.Angles(0, 0, math.rad(90))

	-- Onda no chão
	local onda = peca({
		Shape = Enum.PartType.Cylinder,
		Color = cor,
		Transparency = 0.2,
		Size = Vector3.new(0.12, 2, 2),
		CFrame = CFrame.new(pes) * deitado,
		Parent = pasta,
	})
	TweenService
		:Create(onda, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.12, categoria.onda, categoria.onda),
			Transparency = 1,
		})
		:Play()

	-- Esfera de choque
	local esfera = peca({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.ForceField,
		Color = corAura,
		Transparency = 0.1,
		Size = Vector3.one * categoria.nucleo,
		CFrame = CFrame.new(centro),
		Parent = pasta,
	})
	local raioEsfera = math.min(categoria.onda * 0.45, 26)
	TweenService
		:Create(esfera, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * raioEsfera,
			Transparency = 1,
		})
		:Play()

	-- Faíscas
	local anexo = Instance.new("Attachment")
	anexo.Parent = esfera
	local faiscas = Instance.new("ParticleEmitter")
	faiscas.Texture = TEXTURA_BRILHO
	faiscas.Color = ColorSequence.new(corAura, cor)
	faiscas.LightEmission = 1
	faiscas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 + categoria.nucleo * 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	faiscas.Lifetime = NumberRange.new(0.4, 0.9)
	faiscas.Speed = NumberRange.new(categoria.onda * 0.35, categoria.onda * 0.7)
	faiscas.SpreadAngle = Vector2.new(180, 180)
	faiscas.Drag = 5
	faiscas.Rate = 0
	faiscas.Parent = anexo
	faiscas:Emit(math.floor((if baixa then 6 else 14) * categoria.aneis))

	-- Clarão de luz local (limitado: não é um flash de tela)
	local luz = Instance.new("PointLight")
	luz.Color = corAura
	luz.Range = math.min(10 + categoria.onda * 0.4, 40)
	luz.Brightness = 3
	luz.Parent = esfera
	TweenService:Create(luz, TweenInfo.new(0.6), { Brightness = 0 }):Play()

	-- Coluna de luz (auras raras): é o que os outros jogadores enxergam de longe
	if categoria.coluna then
		local largura = 1.5 + categoria.aneis * 0.6
		local coluna = peca({
			Shape = Enum.PartType.Cylinder,
			Color = cor,
			Transparency = 0.25,
			Size = Vector3.new(360, largura, largura),
			CFrame = CFrame.new(pes + Vector3.new(0, 180, 0)) * deitado,
			Parent = pasta,
		})
		TweenService
			:Create(coluna, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = Vector3.new(360, 0.2, 0.2),
				Transparency = 1,
			})
			:Play()
	end
end

-- Toca o ritual no personagem. Devolve uma função que cancela e limpa tudo.
function Ritual.tocar(personagem: Model, aura: Auras.Aura, op: Opcoes): () -> ()
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if not raiz or not raiz:IsA("BasePart") or not humanoide or humanoide.Health <= 0 then
		if op.aoRevelar then
			task.spawn(op.aoRevelar)
		end
		return function() end
	end
	if ativos[personagem] then
		ativos[personagem]()
	end

	local cat = op.categoria
	local baixa = op.qualidadeBaixa
	-- Durações: quem girou vê a escala completa; os outros, uma versão curta
	local tempos = if op.completo then cat else Apresentacao.ALHEIO
	local t1 = tempos.chamado
	local t2 = t1 + tempos.ressonancia
	local t3 = t2 + tempos.instabilidade
	local t4 = t3 + tempos.ruptura
	local silencio = if op.completo then cat.silencio else 0
	local tContrai = t3 + (tempos.ruptura - silencio) * 0.7
	local tEstouro = tContrai + silencio
	local fim = t4 + 0.35

	local corTier = Color3.fromHex(Auras.Tiers[aura.tier].cor)
	local c1 = Color3.fromHex(aura.cores[1])
	local c2 = Color3.fromHex(aura.cores[2])
	-- Toda raridade tem pose: um gesto curto nas comuns e o "rasgar" nas altas
	local comPose = not op.movimentoReduzido
	local rasga = cat.rachaduras > 0
	local tempo: Trilha.Tempos =
		{ t1 = t1, t2 = t2, t3 = t3, tEstouro = tEstouro, t4 = t4, fim = fim }
	local trilha = if rasga then Trilha.rasgar(tempo) else Trilha.gesto(tempo, cat.circulo)
	local flutua = cat.flutua and op.completo and not op.movimentoReduzido

	local pasta = Instance.new("Folder")
	pasta.Name = "RitualDespertar"
	pasta.Parent = workspace

	-- Núcleo
	local nucleo =
		peca({ Name = "Nucleo", Shape = Enum.PartType.Ball, Color = c1, Size = Vector3.one * 0.05 })
	nucleo.Parent = pasta
	local halo = peca({
		Name = "Halo",
		Shape = Enum.PartType.Ball,
		Color = c2,
		Transparency = 0.7,
		Size = Vector3.one * 0.05,
		Parent = pasta,
	})
	local luz = Instance.new("PointLight")
	luz.Color = c1
	luz.Range = 8 + cat.aneis * 2
	luz.Brightness = 0
	luz.Parent = nucleo

	-- Partículas sugadas para o núcleo (a partir da categoria Alta)
	local implosao: ParticleEmitter? = nil
	if cat.rachaduras > 0 and not baixa then
		local casca = peca({
			Name = "Casca",
			Shape = Enum.PartType.Ball,
			Transparency = 1,
			Size = Vector3.one * (6 + cat.aneis),
			Parent = pasta,
		})
		local e = Instance.new("ParticleEmitter")
		e.Texture = TEXTURA_BRILHO
		e.Color = ColorSequence.new(c2, c1)
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.35, 0.05)
		e.Lifetime = NumberRange.new(0.35, 0.5)
		e.Speed = NumberRange.new(7 + cat.aneis, 10 + cat.aneis)
		e.Rate = 10 * cat.aneis
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		e.Enabled = false
		e.Parent = casca
		implosao = e
	end

	-- Anéis orbitais
	local quantidade = if baixa then math.min(cat.aneis, 2) else cat.aneis
	local segmentos = if baixa then 6 else 12
	local aneis: { Anel } = {}
	for i = 1, quantidade do
		local mistura = if quantidade > 1 then (i - 1) / (quantidade - 1) else 0
		local cor = ColorSequence.new(c1:Lerp(c2, mistura), c1:Lerp(BRANCO, 0.4))
		local anel = criarAnel(pasta, cor, 0.1 + cat.nucleo * 0.06, 3, segmentos)
		-- Cada anel tem um plano próprio, espalhado em volta do núcleo
		anel.inclinacao = CFrame.Angles(0, i * 2.4, 0)
			* CFrame.Angles(math.rad(35 + 22 * (i % 3)), 0, math.rad(20 * i))
		anel.velocidade = (if i % 2 == 0 then -1 else 1) * (2.2 + i * 0.5)
		if not baixa or i == 1 then
			-- Satélites: pequenos losangos que percorrem o anel deixando rastro
			for s = 1, 2 do
				local sat = peca({
					Name = "Satelite",
					Color = BRANCO:Lerp(c1, 0.3),
					Size = Vector3.one * (0.16 + cat.nucleo * 0.08),
					Parent = pasta,
				})
				if not baixa then
					local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
					a0.Position, a1.Position = Vector3.new(0, 0.08, 0), Vector3.new(0, -0.08, 0)
					a0.Parent, a1.Parent = sat, sat
					local rastro = Instance.new("Trail")
					rastro.Attachment0, rastro.Attachment1 = a0, a1
					rastro.Lifetime = 0.22
					rastro.Color = ColorSequence.new(c1, c2)
					rastro.Transparency = NumberSequence.new(0.2, 1)
					rastro.LightEmission = 1
					rastro.Parent = sat
				end
				anel.satelites[s] = sat
			end
		end
		aneis[i] = anel
	end

	-- Círculo rúnico no chão: dois anéis e marcas radiais (formas geométricas originais)
	local circulo: { Anel } = {}
	local marcas: Part? = nil
	if cat.circulo then
		local corChao = ColorSequence.new(c1:Lerp(corTier, 0.5))
		circulo[1] = criarAnel(pasta, corChao, 0.14, 4, segmentos)
		circulo[2] = criarAnel(pasta, corChao, 0.08, 3, segmentos)
		if not baixa then
			local m = peca({
				Name = "Marcas",
				Transparency = 1,
				Size = Vector3.new(0.2, 0.2, 0.2),
				Parent = pasta,
			})
			local n = 4 + cat.aneis
			for k = 1, n do
				local a = (k - 1) / n * math.pi * 2
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = dir * 3.1, dir * (if k % 2 == 0 then 3.9 else 4.5)
				a0.Parent, a1.Parent = m, m
				local feixe = Instance.new("Beam")
				feixe.Attachment0, feixe.Attachment1 = a0, a1
				feixe.Color = corChao
				feixe.Width0, feixe.Width1 = 0.16, 0.04
				feixe.LightEmission = 1
				feixe.FaceCamera = true
				feixe.Segments = 1
				feixe.Parent = m
			end
			marcas = m
		end
	end

	-- Rachaduras: linhas quebradas que saem do núcleo, uma por batida da instabilidade
	local rachaduras: { { Beam } } = {}
	local suporteRachaduras: Part? = nil
	if cat.rachaduras > 0 then
		local total = if baixa then math.ceil(cat.rachaduras / 2) else cat.rachaduras
		local suporte = peca({
			Name = "Rachaduras",
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			Parent = pasta,
		})
		local rng = Random.new()
		for j = 1, total do
			-- Direção no plano de frente para quem olha o personagem
			local a = (j - 1) / total * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local dir = Vector3.new(math.cos(a), math.sin(a), 0)
			local lado = Vector3.new(-dir.Y, dir.X, 0)
			local pontos = { dir * (cat.nucleo * 0.4) }
			for s = 1, 3 do
				local passo = dir * rng:NextNumber(0.7, 1.3) + lado * rng:NextNumber(-0.55, 0.55)
				pontos[s + 1] = pontos[s] + passo
			end
			local feixes = {}
			local anterior: Attachment? = nil
			for s, ponto in pontos do
				local anexo = Instance.new("Attachment")
				anexo.Position = ponto
				anexo.Parent = suporte
				if anterior then
					local feixe = Instance.new("Beam")
					feixe.Attachment0, feixe.Attachment1 = anterior, anexo
					feixe.Color = ColorSequence.new(BRANCO, corTier)
					feixe.Width0 = 0.22 - (s - 2) * 0.06
					feixe.Width1 = 0.16 - (s - 2) * 0.06
					feixe.LightEmission = 1
					feixe.FaceCamera = true
					feixe.Segments = 1
					feixe.Enabled = false
					feixe.Parent = suporte
					table.insert(feixes, feixe)
				end
				anterior = anexo
			end
			rachaduras[j] = feixes
		end
		suporteRachaduras = suporte
	end

	-- Pose do personagem e a fenda que ele rasga (raridades altas)
	local motion: Motion.Controle? = if comPose then Motion.criar(personagem) else nil
	local fenda: Fenda.Controle? = nil
	if rasga then
		fenda = Fenda.criar(pasta, corTier, c1, 1.8 + 0.55 * cat.aneis, 5 + 1.3 * cat.aneis)
	end

	local inicio = os.clock()
	local ultimo = inicio
	local batidas = 0
	local ultimaBatida = -1
	local estourou = false
	local revelou = false
	local encerrado = false
	local conexoes: { RBXScriptConnection } = {}

	local function revelar()
		if not revelou then
			revelou = true
			if op.aoRevelar then
				task.spawn(op.aoRevelar)
			end
		end
	end

	local function finalizar()
		if encerrado then
			return
		end
		encerrado = true
		if ativos[personagem] == finalizar then
			ativos[personagem] = nil
		end
		for _, c in conexoes do
			c:Disconnect()
		end
		if motion then
			motion.restaurar()
		end
		pasta:Destroy()
		-- Se foi interrompido antes da hora, quem girou ainda precisa saber o resultado
		revelar()
	end
	ativos[personagem] = finalizar

	Sons.tocar("chamado", nucleo, 0.8 + cat.aneis * 0.08, 0.35)

	table.insert(conexoes, humanoide.Died:Connect(finalizar))
	table.insert(
		conexoes,
		personagem.AncestryChanged:Connect(function(_, pai)
			if not pai then
				finalizar()
			end
		end)
	)
	table.insert(
		conexoes,
		RunService.Heartbeat:Connect(function()
			if not raiz.Parent then
				finalizar()
				return
			end
			local agora = os.clock()
			local t = agora - inicio
			local dt = agora - ultimo
			ultimo = agora
			if t >= fim then
				finalizar()
				return
			end

			-- Progresso das fases
			local carga = math.clamp((t - t1) / math.max(t3 - t1, 0.01), 0, 1) -- ressonância+instabilidade
			local instavel = if t3 > t2 then math.clamp((t - t2) / (t3 - t2), 0, 1) else 0
			local contracao = math.clamp((t - t3) / math.max(tContrai - t3, 0.01), 0, 1)
			local aposEstouro = math.clamp((t - tEstouro) / 0.3, 0, 1)

			-- Batidas da instabilidade: aceleram com o tempo (ritmo, não ruído)
			local batidasAgora = math.floor(cat.pulsos * instavel ^ 1.6 + 0.0001)
			if op.completo and t < t3 and batidasAgora > batidas then
				batidas = batidasAgora
				ultimaBatida = t
				local r = rachaduras[((batidas - 1) % math.max(#rachaduras, 1)) + 1]
				if r then
					for _, feixe in r do
						feixe.Enabled = true
					end
				end
				Sons.tocar("instavel", nucleo, 0.7 + batidas / math.max(cat.pulsos, 1) * 0.9, 0.3)
			elseif not op.completo and instavel > 0 and batidas == 0 then
				batidas = 1
				for _, r in rachaduras do
					for _, feixe in r do
						feixe.Enabled = true
					end
				end
			end
			local impulso = if ultimaBatida >= 0
				then math.max(0, 1 - (t - ultimaBatida) / 0.12)
				else 0

			-- Pose: a trilha diz qual pose vale agora; os braços tremem com o esforço
			if motion then
				local altura = if flutua
					then ALTURA_FLUTUAR * suave(carga) * (1 - suave((t - t4) / 0.35))
					else 0
				local de, para, peso = Trilha.avaliar(trilha, t)
				local tremor = if rasga and t < tEstouro
					then 0.035 * instavel + 0.05 * impulso
					else 0
				motion.aplicar(de, para, peso, altura, tremor, t)
			end

			-- Posição do núcleo: à frente do peito, com vibração crescente
			local base = raiz.CFrame * CFrame.new(0, 0.5, -2.3)
			local vibra = if op.movimentoReduzido
				then 0
				else 0.06 * cat.aneis * instavel * (1 - contracao)
			local centro = (base * CFrame.new(
				math.sin(t * 43) * vibra,
				math.sin(t * 57 + 1) * vibra,
				0
			)).Position

			-- Tamanho e brilho do núcleo
			local tamanho
			if t < t1 then
				tamanho = cat.nucleo * suave(t / math.max(t1, 0.01))
			elseif t < t3 then
				tamanho = cat.nucleo * (1 + 0.06 * math.sin(t * 12) + 0.35 * impulso)
			elseif t < tEstouro then
				tamanho = cat.nucleo * (1 - 0.85 * suave(contracao))
			else
				tamanho = cat.nucleo * (0.15 + 1.2 * aposEstouro)
			end
			local somindo = if t >= tEstouro then aposEstouro else 0
			nucleo.Size = Vector3.one * math.max(tamanho, 0.05)
			nucleo.CFrame = CFrame.new(centro)
			nucleo.Transparency = somindo
			halo.Size = Vector3.one * math.max(tamanho * 1.9, 0.05)
			halo.CFrame = CFrame.new(centro)
			halo.Transparency = 0.7 + 0.3 * somindo
			luz.Brightness = (1 + 2 * carga + 2 * impulso) * (1 - somindo)
			nucleo.Color = c1:Lerp(BRANCO, 0.5 * impulso + 0.6 * contracao * (1 - somindo))

			if implosao then
				implosao.Enabled = t > t1 and t < tContrai
				local casca = implosao.Parent
				if casca and casca:IsA("BasePart") then
					casca.CFrame = CFrame.new(centro)
				end
			end

			-- Anéis: entram um a um, aceleram, encolhem na contração e se partem no estouro
			local aceleracao = 0.5 + 2.6 * carga * carga + 1.5 * instavel
			for i, anel in aneis do
				local entrada = suave((t - t1 * 0.5 - (i - 1) * 0.05) / 0.22)
				local raioBase = cat.nucleo * 1.1 + i * 0.55
				local raio = raioBase
					* entrada
					* (1 + 0.12 * impulso)
					* (1 - 0.6 * suave(contracao))
				local transparencia = 1 - entrada
				if t >= tEstouro then
					if cat.rompe then
						raio = raioBase * (0.4 + 5 * aposEstouro)
					end
					transparencia = aposEstouro
				end
				anel.angulo += dt * anel.velocidade * aceleracao
				definirRaio(anel, math.max(raio, 0.01))
				definirTransparencia(anel, transparencia)
				local cf = CFrame.new(centro)
					* CFrame.Angles(0, t * 0.6, 0)
					* anel.inclinacao
					* CFrame.Angles(0, anel.angulo, 0)
				anel.base.CFrame = cf
				for s, sat in anel.satelites do
					local a = s * math.pi
					sat.CFrame = cf
						* CFrame.new(math.cos(a) * anel.raio, 0, math.sin(a) * anel.raio)
						* CFrame.Angles(math.rad(45), 0, math.rad(45))
				end
			end

			-- Círculo no chão
			if #circulo > 0 then
				local pes = raiz.Position
					- Vector3.new(0, raiz.Size.Y / 2 + humanoide.HipHeight - 0.15, 0)
				local entrada = suave((t - t1) / 0.3)
				local some = if t >= tEstouro then aposEstouro else 0
				for i, anel in circulo do
					definirRaio(anel, (if i == 1 then 5 else 3) * entrada * (1 + 1.5 * some) + 0.01)
					definirTransparencia(anel, math.max(1 - entrada, some))
					anel.base.CFrame = CFrame.new(pes)
						* CFrame.Angles(0, (if i == 1 then 0.5 else -0.9) * t * aceleracao, 0)
				end
				if marcas then
					marcas.CFrame = CFrame.new(pes) * CFrame.Angles(0, -0.35 * t * aceleracao, 0)
					for _, filho in marcas:GetChildren() do
						if filho:IsA("Beam") then
							filho.Transparency = NumberSequence.new(math.max(1 - entrada, some))
						end
					end
				end
			end

			-- A fenda fica onde as mãos estão, virada para a frente do personagem
			if fenda then
				local giro = raiz.CFrame - raiz.CFrame.Position
				fenda.atualizar(
					CFrame.new(centro) * giro,
					Trilha.aberturaFenda(tempo, t, instavel, impulso)
				)
			end

			-- Rachaduras acompanham o núcleo, de frente para a câmera
			if suporteRachaduras then
				local camera = workspace.CurrentCamera
				local olhar = if camera
					then camera.CFrame.Position
					else centro + raiz.CFrame.LookVector
				suporteRachaduras.CFrame = CFrame.lookAt(centro, olhar)
				if t >= tEstouro then
					for _, r in rachaduras do
						for _, feixe in r do
							feixe.Transparency = NumberSequence.new(aposEstouro)
						end
					end
				end
			end

			-- Estouro (uma vez) e revelação
			if t >= tEstouro and not estourou then
				estourou = true
				local pes = raiz.Position
					- Vector3.new(0, raiz.Size.Y / 2 + humanoide.HipHeight - 0.15, 0)
				estourar(centro, pes, cat, corTier, c1, baixa)
				Sons.tocar("ruptura", raiz, 1.3 - cat.aneis * 0.08, 0.25 + cat.aneis * 0.05)
				if cat.rompe then
					Sons.tocar("estilhaco", raiz, 1.1, 0.3)
				end
			end
			if t >= t4 and not revelou then
				revelar()
				Sons.tocar("revelacao", raiz, 0.9, 0.4)
			end
		end)
	)

	return finalizar
end

-- Cancela o ritual de um personagem, se houver
function Ritual.cancelar(personagem: Model)
	local fn = ativos[personagem]
	if fn then
		fn()
	end
end

return Ritual
