-- Senbonzakura — "Jardim de Mil Lâminas". VFX da aura, montado só neste cliente.
-- Não anima o corpo: os enxames de pétalas-lâmina reagem ao HumanoidRootPart (parado, andando,
-- correndo, pulando, pousando) e, de tempos em tempos, abrem uma flor de lanças (o "pico").
--
-- Pipeline v2: NADA de EditableMesh nem MeshId atribuído em runtime. As malhas vêm do Blender
-- (assets/auras/senbonzakura), são importadas e publicadas no Studio e versionadas como
-- assets/roblox/AuraAssets/Senbonzakura.rbxm; o Rojo põe esse Model em
-- ReplicatedStorage.AuraAssets.Senbonzakura. Aqui só clonamos os MeshParts (uma vez por personagem)
-- e mexemos em CFrame, Size e Transparency. Sem os templates, a aura NÃO é montada (aviso no Output).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Gear5 = require(script.Parent.Gear5) -- só pelos tipos Opcoes/Instancia (contrato comum)
local Pecas = require(script.Parent.SenbonzakuraPecas)

local Senbonzakura = {}

local P = Pecas.PARAMETROS
local COR_LUZ = Color3.fromHex("FF9BDF")
local COR_LANCA = Color3.fromHex("FF9BDF")
local COR_ARCO = Color3.fromHex("CF338F")
local COR_FAISCA = ColorSequence.new(Color3.fromHex("FFE5F8"), Color3.fromHex("F36BC7"))
local CABECA_PADRAO = 1.5 -- altura da cabeça acima da raiz num R15 padrão (escala das malhas)
local NEON = {
	senbon_lance_a = true,
	senbon_lance_b = true,
	senbon_arco_a = true,
	senbon_arco_b = true,
	senbon_selo = true,
}
local SOLTAS = 7 -- pool fixo de pétalas soltas (rastro, desprender, pouso, estilhaços)

-- ---------------------------------------------------------------- templates

type Templates = { [string]: MeshPart }
local cacheTemplates: Templates? = nil
local avisado = false
local jaProcurou = false

local function avisar(msg: string)
	if not avisado then
		avisado = true
		warn("[Senbonzakura] " .. msg .. " — a aura não será montada até o template existir.")
	end
end

-- Procura e valida ReplicatedStorage.AuraAssets.Senbonzakura. Devolve nil + motivo se faltar algo.
function Senbonzakura.templates(espera: number?): (Templates?, string?)
	if cacheTemplates and cacheTemplates.senbon_cluster_a.Parent then
		return cacheTemplates
	end
	local raiz = ReplicatedStorage:FindFirstChild("AuraAssets")
	if not raiz and espera then
		raiz = ReplicatedStorage:WaitForChild("AuraAssets", espera)
	end
	if not raiz then
		return nil,
			"ReplicatedStorage.AuraAssets não existe (importe as malhas e versione Senbonzakura.rbxm)"
	end
	local modelo = raiz:FindFirstChild("Senbonzakura")
	if not modelo and espera then
		modelo = raiz:WaitForChild("Senbonzakura", espera)
	end
	if not modelo then
		return nil,
			"AuraAssets.Senbonzakura não existe (salve o Model como assets/roblox/AuraAssets/Senbonzakura.rbxm)"
	end
	local achados: Templates = {}
	for nome, cfg in Pecas.TEMPLATES do
		local t = modelo:FindFirstChild(nome, true)
		if not t or not t:IsA("MeshPart") then
			return nil, nome .. " ausente ou não é MeshPart (reveja a importação)"
		end
		if t.MeshId == "" then
			return nil, nome .. " sem MeshId (a malha não foi publicada)"
		end
		-- importado girado? compara as proporções da caixa com as do Blender
		local a, b = t.Size.Unit, (cfg.tamanho :: Vector3).Unit
		for _, eixo in { "X", "Y", "Z" } do
			local va, vb = (a :: any)[eixo] :: number, (b :: any)[eixo] :: number
			local maior = math.max(va, vb)
			if maior > 0.08 and math.abs(va - vb) / maior > 0.35 then
				warn(
					string.format(
						"[Senbonzakura] %s: proporções %s diferem do Blender %s — conferir eixo/escala da importação",
						nome,
						tostring(t.Size),
						tostring(cfg.tamanho)
					)
				)
				break
			end
		end
		achados[nome] = t
	end
	cacheTemplates = achados
	return achados
end

-- ---------------------------------------------------------------- utilidades

local function suave(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function easeOutBack(t: number): number
	-- passa ~8% do tamanho final e volta (overshoot moderado)
	local c1 = 1.25
	local c3 = c1 + 1
	local u = t - 1
	return 1 + c3 * u * u * u + c1 * u * u
end

local function limitar(v: Vector3, maximo: number): Vector3
	local m = v.Magnitude
	if m > maximo and m > 1e-6 then
		return v * (maximo / m)
	end
	return v
end

local function olhar(pos: Vector3, frente: Vector3): CFrame
	if frente.Magnitude < 1e-4 then
		frente = Vector3.zAxis
	end
	local f = frente.Unit
	local cima = if math.abs(f.Y) > 0.97 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(pos, pos + f, cima)
end

type Clone = { parte: MeshPart, tamanho: Vector3, centro: Vector3 }

type Orbita = Clone & {
	cfg: { [string]: any },
	angulo: number,
	fase: number,
	pos: Vector3,
	vel: Vector3,
}

type Solta = Clone & {
	ativa: boolean,
	vida: number,
	duracao: number,
	escala: number,
	pos: Vector3,
	vel: Vector3,
	rot: CFrame,
	girar: Vector3,
}

type Lanca = Clone & {
	cfg: { [string]: any },
	inicio: number?, -- relógio da instância em que começou a subir
	quebra: number, -- quando começa a se desfazer
	estilhacou: boolean,
	inclinar: number,
	fase: number,
}

function Senbonzakura.criar(personagem: Model, opcoes: Gear5.Opcoes): Gear5.Instancia?
	local raiz = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return nil
	end
	local templates, motivo = Senbonzakura.templates(if jaProcurou then nil else 3)
	jaProcurou = true
	if not templates then
		avisar(motivo or "templates ausentes")
		return nil
	end
	local cabeca = personagem:FindFirstChild("Head") :: BasePart?

	-- Escala pela altura real (R6, R15, avatares maiores ou menores), uma vez só
	local escala = 1
	if cabeca then
		escala = math.clamp((cabeca.Position - raiz.Position).Y / CABECA_PADRAO, 0.6, 2.5)
	end

	local aleatorio = Random.new() -- só cosmético: cada jogador fica numa fase diferente (nunca RNG de aura)
	local pasta = Instance.new("Folder")
	pasta.Name = "AuraSenbonzakura_" .. personagem.Name
	local grupos: { [string]: Folder } = {}
	for _, nome in
		{ "GrupoOrbitas", "GrupoPetalasSoltas", "GrupoLaminasPico", "GrupoArcos", "GrupoChao" }
	do
		local g = Instance.new("Folder")
		g.Name = nome
		g.Parent = pasta
		grupos[nome] = g
	end
	local todas: { MeshPart } = {}

	local function clonar(nome: string, grupo: string): Clone
		local t = templates[nome]
		local parte = t:Clone()
		parte.Anchored = true
		parte.CanCollide = false
		parte.CanTouch = false
		parte.CanQuery = false
		parte.CastShadow = false
		parte.Massless = true
		parte.Transparency = 1
		if NEON[nome] then
			parte.Material = Enum.Material.Neon
			parte.Color = if nome == "senbon_lance_a" or nome == "senbon_lance_b"
				then COR_LANCA
				else COR_ARCO
			pcall(function()
				parte.TextureID = "" -- Neon com a cor da paleta, não com a textura das pétalas
			end)
		end
		for _, filho in parte:GetDescendants() do
			if filho:IsA("BasePart") then
				filho:Destroy() -- o template é uma peça só; nada de sobras do importador
			end
		end
		parte.Parent = grupos[grupo]
		table.insert(todas, parte)
		local cfg = Pecas.TEMPLATES[nome]
		return { parte = parte, tamanho = cfg.tamanho, centro = cfg.centro }
	end

	local function base(): CFrame
		local cf = raiz.CFrame
		local l = cf.LookVector
		return CFrame.lookAt(cf.Position, cf.Position + Vector3.new(l.X, 0, l.Z))
	end
	local cfBase = base()

	local orbitas: { Orbita } = {}
	for _, cfg in Pecas.ORBITAS :: { { [string]: any } } do
		local c = clonar(cfg.template, "GrupoOrbitas") :: any
		c.cfg = cfg
		c.angulo = cfg.angulo
		c.fase = aleatorio:NextNumber(0, math.pi * 2)
		c.pos = cfBase.Position
		c.vel = Vector3.zero
		table.insert(orbitas, c :: Orbita)
	end
	local soltas: { Solta } = {}
	for i = 1, SOLTAS do
		local c = clonar(
			if i % 2 == 0 then "senbon_petal_a" else "senbon_petal_b",
			"GrupoPetalasSoltas"
		) :: any
		c.ativa = false
		c.vida = 0
		c.duracao = 1
		c.escala = 1
		c.pos = cfBase.Position
		c.vel = Vector3.zero
		c.rot = CFrame.identity
		c.girar = Vector3.zero
		table.insert(soltas, c :: Solta)
	end
	local lancas: { Lanca } = {}
	for _, cfg in Pecas.LANCAS :: { { [string]: any } } do
		local c = clonar(cfg.template, "GrupoLaminasPico") :: any
		c.cfg = cfg
		c.inicio = nil
		c.quebra = 0
		c.estilhacou = false
		c.inclinar = math.rad(aleatorio:NextNumber(4, 9))
		c.fase = aleatorio:NextNumber(0, math.pi * 2)
		table.insert(lancas, c :: Lanca)
	end
	local arcoA = clonar("senbon_arco_a", "GrupoArcos")
	local arcoB = clonar("senbon_arco_b", "GrupoArcos")
	local selo = clonar("senbon_selo", "GrupoChao")

	-- Brilho: uma luz rosa suave e um emissor só (brilhos de aresta e estilhaços em rajadas)
	local anexo = Instance.new("Attachment")
	anexo.Name = "AuraSenbonzakuraLuz"
	anexo.Position = Vector3.new(0, 0.6, 0) * escala
	local luz = Instance.new("PointLight")
	luz.Color = COR_LUZ
	luz.Range = 9 * escala
	luz.Brightness = 0.8
	luz.Shadows = false
	luz.Parent = anexo
	local faiscas = Instance.new("ParticleEmitter")
	faiscas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	faiscas.Color = COR_FAISCA
	faiscas.LightEmission = 1
	faiscas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16 * escala),
		NumberSequenceKeypoint.new(1, 0),
	})
	faiscas.Lifetime = NumberRange.new(0.35, 0.7)
	faiscas.Rate = 1.5
	faiscas.Speed = NumberRange.new(0.5, 1.5)
	faiscas.SpreadAngle = Vector2.new(180, 180)
	faiscas.Shape = Enum.ParticleEmitterShape.Sphere
	faiscas.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	faiscas.Parent = anexo
	anexo.Parent = raiz

	local filtro = RaycastParams.new()
	filtro.FilterType = Enum.RaycastFilterType.Exclude
	filtro.FilterDescendantsInstances = { personagem, pasta }
	local alturaPe = 3 * escala -- da raiz até o chão em pé (medido abaixo)
	do
		local hit = Workspace:Raycast(raiz.Position, Vector3.new(0, -10 * escala, 0), filtro)
		if hit then
			alturaPe = math.clamp(raiz.Position.Y - hit.Position.Y, 1, 8 * escala)
		end
	end

	-- estado
	local baixa = opcoes.qualidadeBaixa
	local reduzido = opcoes.movimentoReduzido
	local tempo = 0
	local manifestando: number? = if opcoes.manifestar then 0 else nil
	local pico: number? = nil
	local proximoPico = aleatorio:NextNumber(P.intervaloPico[1], P.intervaloPico[2])
	local saindo: number? = nil
	local pouso: number? = nil
	local velYAnterior = 0
	local chaoY = raiz.Position.Y - alturaPe
	local noAr = false
	local relogioChao = 0
	local proximaSolta = aleatorio:NextNumber(1.2, 2.6)
	local proximoRastro = 0
	local proximoDestaque = 1.2
	local arcoSetor = aleatorio:NextInteger(0, 2)
	local arcoCiclo = aleatorio:NextNumber(0, 2)
	local flashFeito = false
	local nivel = 2 -- 2 = completo, 1 = médio (80–140), 0 = oculto
	local acumulado = 0
	local visivelPasta = false
	local destruida = false

	local inst = {} :: any

	local function destruir()
		destruida = true
		pasta:Destroy()
		anexo:Destroy()
		table.clear(orbitas)
		table.clear(soltas)
		table.clear(lancas)
		table.clear(todas)
	end

	local function nOrbitas(): number
		if nivel == 1 then
			return Pecas.ORBITAS_MEDIO
		end
		return if baixa then Pecas.ORBITAS_BAIXA else #orbitas
	end

	local function detalheTotal(): boolean
		return nivel == 2 and not baixa
	end

	local function aplicarNivel()
		local completo = detalheTotal()
		luz.Enabled = completo
		faiscas.Enabled = completo and not reduzido
		local n = nOrbitas()
		for i, o in orbitas do
			if i > n then
				o.parte.Transparency = 1
			end
		end
		if not completo then
			for _, s in soltas do
				s.ativa = false
				s.parte.Transparency = 1
			end
			arcoB.parte.Transparency = 1
		end
		if nivel < 2 then
			for _, l in lancas do
				l.inicio = nil
				l.parte.Transparency = 1
			end
			selo.parte.Transparency = 1
		end
	end
	aplicarNivel()

	local function soltar(onde: Vector3, vel: Vector3, duracao: number, tam: number)
		if not detalheTotal() then
			return
		end
		for _, s in soltas do
			if not s.ativa then
				s.ativa = true
				s.vida = 0
				s.duracao = duracao
				s.escala = tam
				s.pos = onde
				s.vel = vel
				s.rot = CFrame.Angles(
					aleatorio:NextNumber(0, 6.28),
					aleatorio:NextNumber(0, 6.28),
					aleatorio:NextNumber(0, 6.28)
				)
				s.girar = Vector3.new(
					aleatorio:NextNumber(-4, 4),
					aleatorio:NextNumber(-6, 6),
					aleatorio:NextNumber(-4, 4)
				)
				return
			end
		end
	end

	-- lanças: sobem do chão em ~0,3 s, balançam 3°–8°, depois se desfazem em pétalas
	local function erguerLancas(quantas: number, atraso: number, quebraEm: number)
		if nivel < 2 then
			return
		end
		for i = 1, math.min(quantas, #lancas) do
			local l = lancas[i]
			l.inicio = tempo + atraso + (i - 1) * 0.035
			l.quebra = tempo + quebraEm + (i - 1) * 0.03
			l.estilhacou = false
		end
	end

	function inst.definirQualidade(_self, novaBaixa: boolean, novoReduzido: boolean)
		baixa = novaBaixa
		reduzido = novoReduzido
		if baixa or reduzido then
			pico = nil
		end
		aplicarNivel()
	end

	function inst.manifestar(_self)
		manifestando = 0
		flashFeito = false
	end

	function inst.encerrar(_self, imediato: boolean?)
		if imediato then
			if not destruida then
				destruir()
			end
			return
		end
		if saindo == nil then
			saindo = 0
			faiscas.Enabled = false
		end
	end

	function inst.atualizar(_self, dt: number, camera: Vector3): boolean
		if destruida then
			return false
		end
		if not raiz.Parent or not personagem.Parent then
			destruir()
			return false
		end
		dt = math.min(dt, 1 / 20)
		tempo += dt

		-- LOD por distância da câmera (80 / 140 studs, mesmo contrato das outras auras)
		local distancia = (camera - raiz.Position).Magnitude
		local novoNivel = if distancia >= P.lodOculto
			then 0
			elseif distancia >= P.lodDetalhe then 1
			else 2
		if novoNivel ~= nivel then
			nivel = novoNivel
			pasta.Parent = if nivel > 0 then Workspace else nil
			visivelPasta = nivel > 0
			aplicarNivel()
		end
		if nivel == 0 then
			if saindo then
				destruir()
				return false
			end
			return true
		end
		if nivel == 1 then
			acumulado += dt
			if acumulado < 0.1 then
				return true
			end
			dt = math.min(acumulado, 0.1)
			acumulado = 0
		end

		-- saída: encolhe para o centro, apaga e limpa tudo
		local opacidade = 1
		local recolher = 0
		if saindo then
			saindo += dt
			recolher = math.min(saindo / P.duracaoSaida, 1)
			opacidade = 1 - recolher
			if saindo >= P.duracaoSaida then
				destruir()
				return false
			end
		end

		local cf = base()
		local velocidade = raiz.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocidade.X, 0, velocidade.Z)
		local rapidez = horizontal.Magnitude
		local andar = math.clamp(rapidez / 12, 0, 1)
		local corrida = math.clamp((rapidez - 12) / 8, 0, 1)
		local dirMundo = if rapidez > 1 then horizontal.Unit else Vector3.zero
		local dirLocal = cf:VectorToObjectSpace(dirMundo)
		local amp = if reduzido then 0.4 else 1

		-- chão (10 Hz): o selo fica no último chão; no ar ele some
		relogioChao -= dt
		if relogioChao <= 0 then
			relogioChao = 0.1
			local hit = Workspace:Raycast(
				raiz.Position,
				Vector3.new(0, -(alturaPe + 2.5 * escala), 0),
				filtro
			)
			if hit then
				chaoY = hit.Position.Y
				noAr = raiz.Position.Y - chaoY > alturaPe + 0.8 * escala
			else
				noAr = true
			end
		end
		local subindo = if noAr then math.clamp(velocidade.Y / 25, 0, 1) else 0
		local caindo = if noAr then math.clamp(-velocidade.Y / 30, 0, 1) else 0

		-- pouso depois de uma queda: pulso radial curto + pétalas saltando
		if velYAnterior < -18 and velocidade.Y > -2 then
			pouso = 0
			if detalheTotal() and not reduzido then
				local pe = Vector3.new(raiz.Position.X, chaoY + 0.3 * escala, raiz.Position.Z)
				for _ = 1, aleatorio:NextInteger(4, 7) do
					local a = aleatorio:NextNumber(0, math.pi * 2)
					local fora = Vector3.new(math.cos(a), 0, math.sin(a))
					soltar(
						pe + fora * 0.8 * escala,
						(
							fora * aleatorio:NextNumber(1.5, 3)
							+ Vector3.new(0, aleatorio:NextNumber(2, 3.5), 0)
						) * escala,
						aleatorio:NextNumber(0.5, 0.8),
						0.9
					)
				end
			end
		end
		velYAnterior = velocidade.Y
		local fatorPouso = 0
		if pouso then
			pouso += dt
			fatorPouso = math.sin(math.min(pouso / 0.3, 1) * math.pi) * amp
			if pouso >= 0.3 then
				pouso = nil
			end
		end

		-- pico de energia (cosmético, fase própria por jogador): contrai, abre a flor, gira uma vez, volta
		local podePico = nivel == 2
			and not baixa
			and not reduzido
			and not manifestando
			and not saindo
		if pico then
			pico += dt
			if pico >= P.duracaoPico then
				pico = nil
				proximoPico = tempo + aleatorio:NextNumber(P.intervaloPico[1], P.intervaloPico[2])
			end
		elseif podePico and tempo >= proximoPico then
			pico = 0
			erguerLancas(#lancas, 0.2, 1.05)
		elseif not podePico and tempo >= proximoPico then
			proximoPico = tempo + 4 -- tenta de novo mais tarde (sem acumular)
		end
		local contrair, abrir, giroPico, brilhoPico = 0, 0, 0, 0
		if pico then
			contrair = math.sin(math.clamp(pico / 0.2, 0, 1) * math.pi / 2)
				* (1 - suave(0.2, 0.45, pico))
			abrir = suave(0.2, 0.55, pico) * (1 - suave(0.95, 1.65, pico))
			giroPico = math.pi * 2 * suave(0.2, 1.45, pico)
			brilhoPico = suave(0.35, 0.5, pico) * (1 - suave(0.65, 0.85, pico))
			if brilhoPico > 0.9 and not flashFeito then
				flashFeito = true
				faiscas:Emit(14)
			end
		elseif not manifestando then
			flashFeito = false
		end

		-- manifestação (~1,55 s): pétalas nos ombros, enxames chegando de trás, lanças, selo, assentar
		local brilhoManif = 0
		if manifestando then
			local m = manifestando
			if m == 0 then
				local ombro = cf * CFrame.new(0, 1.1 * escala, 0)
				for k = 1, if baixa then 0 else 7 do
					local lado = if k % 2 == 0 then 1 else -1
					local p = (ombro * CFrame.new(
						lado * aleatorio:NextNumber(0.9, 1.7) * escala,
						aleatorio:NextNumber(-1.4, 0.3) * escala,
						0
					)).Position
					soltar(
						p,
						Vector3.new(0, 0.8, 0) * escala + cf.LookVector * -0.6 * escala,
						aleatorio:NextNumber(0.5, 0.8),
						0.7
					)
				end
				erguerLancas(if baixa then 4 else 7, 0.55, 1.0)
			end
			brilhoManif = suave(0.5, 0.8, m) * (1 - 0.3 * suave(1.0, 1.4, m))
			if m >= 1.42 and not flashFeito and not reduzido and detalheTotal() then
				flashFeito = true -- um único estalo de brilho nas bordas ao assentar
				faiscas:Emit(10)
			end
			manifestando = m + dt
			if manifestando >= P.duracaoManifestar then
				manifestando = nil
			end
		end
		local brilho = math.max(brilhoPico, brilhoManif * 0.8)

		-- ---------------------------------------------------- enxames em órbita
		local n = nOrbitas()
		local multRaio = (1 - 0.35 * contrair)
			* (1 + 0.6 * abrir)
			* (1 + 0.25 * fatorPouso)
			* (1 - 0.4 * recolher)
		local velMul = if reduzido then 0.6 else 1
		for i = 1, n do
			local o = orbitas[i]
			local cfg = o.cfg
			local sentido = if cfg.vel >= 0 then 1 else -1
			-- passa pela frente rápido e mais longe do rosto; a maior parte do tempo nas laterais/costas
			local frenteAntes = math.max(0, -math.sin(o.angulo)) ^ 2
			o.angulo += cfg.vel * velMul * dt * (1 + 1.4 * frenteAntes)
			local a = o.angulo + giroPico * sentido

			local crescer = 1
			local chegar = 1
			if manifestando then
				local t = math.clamp((manifestando - (0.2 + (i - 1) * 0.05)) / 0.38, 0, 1)
				crescer = if t <= 0 then 0 else easeOutBack(t)
				chegar = 1 - (1 - t) ^ 3
				a -= (1 - chegar) * math.pi * sentido -- chega de trás dando a volta no tronco
			end
			local frente = math.max(0, -math.sin(a)) ^ 2
			local respira = 1
				+ P.respiracao
					* amp
					* math.sin(tempo * math.pi * 2 / P.periodoRespiracao + o.fase)
			local r = respira
				* (1 + 0.3 * frente)
				* multRaio
				* (0.35 + 0.65 * chegar)
				* (1 - 0.15 * caindo)
			local x = math.cos(a) * cfg.rx * r
			local z = math.sin(a) * cfg.rz * r
			local y = cfg.altura * (1 + 0.35 * abrir)
				+ cfg.inclinacao * math.sin(a + 0.8)
				+ P.balanco * amp * math.sin(tempo * 0.9 + o.fase)
				- (if cfg.altura > 1.2 then 0.5 * frente else 0)
				+ subindo * (if cfg.altura < 0.5 then 0.45 else 0.2)
			local off = Vector3.new(x, y, z)
			-- inércia: comprime à frente do movimento e alonga atrás; correndo, vai para trás e para os ombros
			if rapidez > 1 then
				local proj = off:Dot(dirLocal)
				if proj > 0 then
					off -= dirLocal * proj * (0.12 * andar + 0.3 * corrida)
				else
					off += dirLocal * proj * (0.1 * andar + 0.25 * corrida)
				end
				local lateral = off - dirLocal * off:Dot(dirLocal)
				lateral = Vector3.new(lateral.X, 0, lateral.Z)
				off -= lateral * 0.25 * corrida
				off += -dirLocal * 1.4 * corrida + Vector3.new(0, 0.35 * corrida, 0)
			end
			local alvo = cf:PointToWorldSpace(off * escala)

			-- mola amortecida (atraso ~0,1–0,2 s), com limite de distância (sem enxame metros atrás)
			local k = cfg.rigidez
			local amortecer = 2 * 0.6 * math.sqrt(k)
			local passos = if dt > 1 / 60 then 2 else 1
			local h = dt / passos
			for _ = 1, passos do
				local acel = (alvo - o.pos) * k - o.vel * amortecer
				o.vel += acel * h
				o.pos += o.vel * h
			end
			local maxAtraso = cfg.atraso * escala * (1 + 0.6 * corrida)
			local atraso = o.pos - alvo
			if atraso.Magnitude > maxAtraso * 4 or manifestando and crescer <= 0 then
				o.pos = alvo -- teleporte/respawn: não deixa o enxame voando pelo mapa
				o.vel = Vector3.zero
			else
				o.pos = alvo + limitar(atraso, maxAtraso)
			end

			-- o fio aponta na tangente da órbita; correndo, inclina na direção do movimento
			local tangente = cf:VectorToWorldSpace(
				Vector3.new(-math.sin(a) * cfg.rx, 0, math.cos(a) * cfg.rz) * sentido
			)
			local frenteFio = tangente.Unit:Lerp(
				if rapidez > 1 then dirMundo else tangente.Unit,
				0.5 * corrida
			) + Vector3.new(0, 0.6 * caindo, 0)
			local g = math.rad(cfg.giro) * amp
			local giro = CFrame.Angles(
				g * 0.4 * math.sin(tempo * 0.53 + o.fase * 1.3),
				g * 0.3 * math.sin(tempo * 0.37 + o.fase),
				g * math.sin(tempo * 0.7 + o.fase) + abrir * 0.6 * sentido
			)
			local s = escala * cfg.escala * crescer * (1 - 0.3 * recolher) * (1 + 0.12 * abrir)
			local parte = o.parte
			if crescer > 0.02 then
				parte.Size = o.tamanho * s
				parte.CFrame = olhar(o.pos, frenteFio) * giro * CFrame.new(o.centro * s)
				parte.Transparency = 1 - opacidade
			else
				parte.Transparency = 1
			end
		end

		-- ---------------------------------------------------- arcos de corte (nunca um aro inteiro)
		do
			-- arco A: aparece em 1 de 3 setores, ~1,4 s, depois troca de setor
			arcoCiclo += dt
			local cicloTotal = 4.2
			if arcoCiclo >= cicloTotal then
				arcoCiclo -= cicloTotal
				arcoSetor = (arcoSetor + aleatorio:NextInteger(1, 2)) % 3
			end
			local vis = suave(0, 0.35, arcoCiclo) * (1 - suave(1.1, 1.5, arcoCiclo))
			local visA = math.max(vis * 0.55, abrir, brilhoManif * 0.7)
			-- setores: costas-direita, costas, costas-esquerda (o arco nunca corta a frente do rosto)
			local giroA = (0.35 + arcoSetor * 0.95) + arcoCiclo * 0.5 * amp + giroPico
			local alturaA = 0.3 + 0.4 * abrir
			local escalaA = escala * (0.85 + 0.45 * abrir) * (1 - 0.3 * recolher)
			local inclA = 0.12 + 0.25 * abrir
			local pivoA = cf
				* CFrame.new(0, alturaA * escala, 0)
				* CFrame.Angles(inclA, 0, 0.1)
				* CFrame.Angles(0, giroA, 0)
			arcoA.parte.Size = arcoA.tamanho * escalaA
			arcoA.parte.CFrame = pivoA * CFrame.new(arcoA.centro * escalaA)
			arcoA.parte.Transparency = 1
				- (0.15 + 0.75 * visA) * opacidade * math.clamp(visA * 4, 0, 1)

			-- arco B: traço cruzado quando anda/corre e no pico
			if detalheTotal() then
				local visB = math.max(andar * 0.55 * (0.6 + 0.4 * math.sin(tempo * 2.3)), abrir)
				local giroB = math.atan2(-dirLocal.X, -dirLocal.Z) + math.pi * 0.85 - giroPico * 0.7
				local escalaB = escala * (1 + 0.45 * abrir)
				local pivoB = cf
					* CFrame.new(0, (0.1 + 0.6 * abrir) * escala, 0)
					* CFrame.Angles(-0.1 - 0.3 * abrir, 0, 0.18)
					* CFrame.Angles(0, giroB, 0)
				arcoB.parte.Size = arcoB.tamanho * escalaB
				arcoB.parte.CFrame = pivoB * CFrame.new(arcoB.centro * escalaB)
				arcoB.parte.Transparency = if visB < 0.05
					then 1
					else 1 - (0.2 + 0.7 * visB) * opacidade
			end
		end

		-- ---------------------------------------------------- lanças do pico/manifestação
		if nivel == 2 then
			for _, l in lancas do
				local inicio = l.inicio
				if not inicio or tempo < inicio then
					l.parte.Transparency = 1
					continue
				end
				local idade = tempo - inicio
				local subir = 1 - (1 - math.clamp(idade / 0.3, 0, 1)) ^ 3
				local desfazer = math.clamp((tempo - l.quebra) / 0.32, 0, 1)
				if desfazer >= 1 then
					l.inicio = nil
					l.parte.Transparency = 1
					continue
				end
				local cfg = l.cfg
				local graus = math.rad(cfg.graus)
				local dir = Vector3.new(math.sin(graus), 0, math.cos(graus)) -- 0 = frente (-Z local)
				dir = Vector3.new(dir.X, 0, -dir.Z)
				local dirW = cf:VectorToWorldSpace(dir)
				local altura = cfg.altura * escala * (1 - 0.2 * desfazer)
				local comprimento = l.tamanho.Y * altura
				local posBase = cf:PointToWorldSpace(dir * cfg.raio * escala * (1 + 0.15 * abrir))
				posBase = Vector3.new(posBase.X, chaoY - (1 - subir) * comprimento, posBase.Z)
				local balanco = math.rad(3 + 5 * (0.5 + 0.5 * math.sin(l.fase)))
					* math.sin(tempo * 3.1 + l.fase)
					* amp
				local orient = CFrame.fromAxisAngle(
					Vector3.yAxis:Cross(dirW).Unit,
					l.inclinar + balanco
				) * CFrame.lookAt(Vector3.zero, dirW).Rotation
				if desfazer > 0 and not l.estilhacou then
					l.estilhacou = true
					local ponta = posBase + orient.UpVector * comprimento
					soltar(ponta, (dirW * 1.2 + Vector3.new(0, 1, 0)) * escala, 0.6, 0.9)
					soltar(
						posBase + orient.UpVector * comprimento * 0.5,
						(dirW * 0.8 - orient.RightVector) * escala,
						0.5,
						0.8
					)
				end
				local s = altura * (1 - 0.85 * desfazer)
				l.parte.Size = l.tamanho * s
				l.parte.CFrame = CFrame.new(posBase) * orient * CFrame.new(l.centro * s)
				l.parte.Transparency = 1 - (1 - 0.6 * desfazer) * opacidade * (0.85 + 0.15 * brilho)
			end

			-- selo de chão: manifestação e pico, só com o pé no chão (fica no último chão e some no ar)
			if not baixa then
				local visSelo = 0
				if manifestando then
					visSelo = suave(0.55, 0.75, manifestando) * (1 - suave(1.0, 1.3, manifestando))
				elseif pico then
					visSelo = suave(0.2, 0.4, pico) * (1 - suave(1.1, 1.5, pico))
				end
				if noAr then
					visSelo *= 0.3
				end
				if visSelo > 0.02 then
					local centro =
						Vector3.new(raiz.Position.X, chaoY + 0.04 * escala, raiz.Position.Z)
					local s = escala * (0.9 + 0.15 * abrir)
					selo.parte.Size = selo.tamanho * s
					selo.parte.CFrame = CFrame.new(centro)
						* CFrame.Angles(0, tempo * 0.4, 0)
						* CFrame.new(selo.centro * s)
					selo.parte.Transparency = 1 - visSelo * 0.8 * opacidade
				else
					selo.parte.Transparency = 1
				end
			end
		end

		-- ---------------------------------------------------- pétalas soltas (pool fixo)
		if detalheTotal() and not saindo then
			-- desprender de vez em quando (parado ou não)
			proximaSolta -= dt
			if proximaSolta <= 0 then
				proximaSolta = aleatorio:NextNumber(1.2, 2.6)
				local o = orbitas[aleatorio:NextInteger(1, n)]
				local deriva = Vector3.new(
					aleatorio:NextNumber(-0.6, 0.6),
					aleatorio:NextNumber(0.1, 0.6),
					aleatorio:NextNumber(-0.6, 0.6)
				)
				soltar(o.pos, deriva * escala, aleatorio:NextNumber(0.4, 0.9), 0.75)
			end
			-- rastro curto ao andar (2–5 pétalas vivas, vida <= 0,6 s)
			if rapidez > 4 then
				proximoRastro -= dt
				if proximoRastro <= 0 then
					proximoRastro = 0.25 - 0.12 * corrida
					local o = orbitas[aleatorio:NextInteger(1, n)]
					soltar(
						o.pos,
						(-dirMundo * (1 + corrida) + Vector3.new(0, 0.3, 0)) * escala,
						aleatorio:NextNumber(0.4, 0.6),
						0.7
					)
				end
			end
			-- correndo: uma lâmina maior corta perto do corpo por ~0,3 s
			if corrida > 0.5 then
				proximoDestaque -= dt
				if proximoDestaque <= 0 then
					proximoDestaque = aleatorio:NextNumber(1, 1.6)
					local lado = if aleatorio:NextNumber() < 0.5 then -1 else 1
					local p = cf:PointToWorldSpace(Vector3.new(lado * 1.6, 0.5, 0.5) * escala)
					soltar(p, (dirMundo * rapidez * 0.9 + cf.RightVector * -lado * 1.5), 0.3, 1.6)
				end
			end
		end
		for _, s in soltas do
			if s.ativa then
				s.vida += dt
				local t = s.vida / s.duracao
				if t >= 1 or not detalheTotal() then
					s.ativa = false
					s.parte.Transparency = 1
				else
					s.vel *= math.exp(-1.6 * dt)
					s.vel += Vector3.new(0, -0.7 * escala, 0) * dt
					s.pos += s.vel * dt
					s.rot *= CFrame.Angles(s.girar.X * dt, s.girar.Y * dt, s.girar.Z * dt)
					local tam = escala * s.escala * (1 - 0.6 * suave(0.55, 1, t))
					s.parte.Size = s.tamanho * tam
					s.parte.CFrame = CFrame.new(s.pos) * s.rot * CFrame.new(s.centro * tam)
					s.parte.Transparency = 1 - (1 - suave(0.6, 1, t)) * opacidade
				end
			end
		end

		-- luz: suave no idle, sobe só no instante central do pico/manifestação
		if luz.Enabled then
			luz.Brightness = (0.7 + 2.3 * brilho) * opacidade
		end

		-- primeira pessoa: o que estiver perto da lente fica invisível só para este jogador
		if opcoes.local_ and cabeca then
			local primeira = (camera - cabeca.Position).Magnitude < 1.5
			for _, parte in todas do
				parte.LocalTransparencyModifier = if primeira
						and (parte.Position - camera).Magnitude < 3.5 * escala
					then 1
					else 0
			end
		end

		if not visivelPasta then
			visivelPasta = true
			pasta.Parent = Workspace
		end
		return true
	end

	-- primeiro quadro já posicionado fora da tela; só então a pasta entra no Workspace
	nivel = 2
	local cam = Workspace.CurrentCamera
	inst:atualizar(0, if cam then cam.CFrame.Position else raiz.Position)
	return inst :: Gear5.Instancia
end

return Senbonzakura
