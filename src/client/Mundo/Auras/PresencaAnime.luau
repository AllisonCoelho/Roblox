-- Presenca das auras de anime: linguagem corporal e resposta do cenario.
-- Primeira identidade: Gear 5. Efeitos puramente locais, sem mudar colisao, terrain ou save.
-- Um unico laço de animação (PreSimulation) e um de VFX (PreRender), geridos pelo Controlador.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Poses = require(script.Parent.Parent.Incursoes.Poses)
local Movimento = require(script.Parent.Gear5Movimento)

local Presenca = {}

type Junta = Motor6D | AnimationConstraint
type Vinculo = {
	junta: Junta,
	baseR6: CFrame,
	anterior: CFrame?,
	aplicado: CFrame?,
}

type Ativa = {
	raiz: BasePart,
	humanoide: Humanoid,
	fase: number,
	misturaIdle: number,
	contatoIdle: boolean,
	juntas: { [string]: Vinculo },
	relerJuntas: boolean,
	conexoes: { RBXScriptConnection },
	noAr: boolean,
	velocidadeQueda: number,
	proximoPasso: number,
	ultimoImpacto: number,
	visivel: boolean,
}

type Mancha = {
	miolo: Part,
	borda: Part?,
	base: CFrame,
	intensidade: number,
	inicio: number,
	duracao: number,
}

local ativas: { [Model]: Ativa } = {}
local manchas: { Mancha } = {}
local pasta: Folder? = nil
local qualidadeBaixa = false
local movimentoReduzido = false

local LIMITE_MANCHAS = 14
local DISTANCIA_POSE = 90
local DISTANCIA_EFEITO = 85

local function pastaVisual(): Folder
	if pasta and pasta.Parent then
		return pasta
	end
	local f = Instance.new("Folder")
	f.Name = "AnimeAmbienteLocal"
	f.Parent = Workspace
	pasta = f
	return f
end

local function criarParte(cor: Color3, transparencia: number): Part
	local parte = Instance.new("Part")
	parte.Name = "BorrachaGear5"
	parte.Shape = Enum.PartType.Ball
	parte.Material = Enum.Material.SmoothPlastic
	parte.Color = cor
	parte.Transparency = transparencia
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	parte.CanQuery = false
	parte.CastShadow = false
	parte.Parent = pastaVisual()
	return parte
end

local function destruirMancha(m: Mancha)
	m.miolo:Destroy()
	if m.borda then
		m.borda:Destroy()
	end
end

local function baseNoChao(posicao: Vector3, normal: Vector3): CFrame
	local referencia = if math.abs(normal:Dot(Vector3.zAxis)) > 0.95
		then Vector3.xAxis
		else Vector3.zAxis
	local direita = normal:Cross(referencia).Unit
	local tras = direita:Cross(normal).Unit
	return CFrame.fromMatrix(posicao, direita, normal, tras)
end

local function marcarChao(a: Ativa, intensidade: number, camera: Vector3)
	if (a.raiz.Position - camera).Magnitude > DISTANCIA_EFEITO then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluir: { Instance } = { a.personagem }
	if pasta then
		table.insert(excluir, pasta)
	end
	params.FilterDescendantsInstances = excluir
	local hit =
		Workspace:Raycast(a.raiz.Position + Vector3.new(0, 1, 0), Vector3.new(0, -9, 0), params)
	if not hit or hit.Normal.Y < 0.6 then
		return
	end
	while #manchas >= LIMITE_MANCHAS do
		destruirMancha(table.remove(manchas, 1) :: Mancha)
	end
	local corBase = if hit.Instance:IsA("BasePart")
		then hit.Instance.Color
		else Color3.fromRGB(115, 112, 135)
	local cor = corBase:Lerp(Color3.fromRGB(243, 239, 255), 0.48)
	local miolo = criarParte(cor, 0.22)
	local borda = if qualidadeBaixa then nil else criarParte(Color3.fromRGB(238, 229, 255), 0.68)
	local plano = baseNoChao(hit.Position + hit.Normal * 0.07, hit.Normal)
	table.insert(manchas, {
		miolo = miolo,
		borda = borda,
		base = plano,
		intensidade = intensidade,
		inicio = os.clock(),
		duracao = if movimentoReduzido then 0.48 else 1.05,
	})
end

local function animarChao()
	local agora = os.clock()
	for i = #manchas, 1, -1 do
		local m = manchas[i]
		local t = (agora - m.inicio) / m.duracao
		if t >= 1 then
			destruirMancha(m)
			table.remove(manchas, i)
		else
			local esmagar = math.sin(math.min(t / 0.55, 1) * math.pi)
			local r = (1.8 + 3.3 * t) * m.intensidade
			local altura = (0.13 + 0.57 * esmagar) * m.intensidade
			-- Calota local que amassa e recupera; nao modifica a colisao do piso.
			m.miolo.Size = Vector3.new(r * 1.6, math.max(0.08, altura), r * 1.6)
			m.miolo.CFrame = m.base * CFrame.new(0, altura * 0.32, 0)
			m.miolo.Transparency = 0.22 + t * 0.78
			if m.borda then
				local rb = r * (1.05 + 0.45 * t)
				m.borda.Size = Vector3.new(rb * 2, 0.10, rb * 2)
				m.borda.CFrame = m.base * CFrame.new(0, 0.03, 0)
				m.borda.Transparency = 0.67 + t * 0.33
			end
		end
	end
end

local NOMES_JUNTAS: { [string]: string } = {
	Root = "raiz",
	RootJoint = "raiz",
	Waist = "cintura",
	Neck = "pescoco",
	RightShoulder = "ombroD",
	["Right Shoulder"] = "ombroD",
	LeftShoulder = "ombroE",
	["Left Shoulder"] = "ombroE",
	RightElbow = "cotoveloD",
	LeftElbow = "cotoveloE",
	RightHip = "quadrilD",
	["Right Hip"] = "quadrilD",
	LeftHip = "quadrilE",
	["Left Hip"] = "quadrilE",
	RightKnee = "joelhoD",
	LeftKnee = "joelhoE",
}

local function lerJuntas(personagem: Model, a: Ativa)
	local r6 = a.humanoide.RigType == Enum.HumanoidRigType.R6
	table.clear(a.juntas)
	for _, obj in personagem:GetDescendants() do
		local nome = NOMES_JUNTAS[obj.Name]
		if nome and (obj:IsA("Motor6D") or obj:IsA("AnimationConstraint")) then
			a.juntas[nome] = {
				junta = obj,
				baseR6 = if r6 and obj:IsA("Motor6D") then obj.C1.Rotation else CFrame.identity,
			}
		end
	end
	a.relerJuntas = false
end

local function restaurar(a: Ativa)
	for _, vinculo in a.juntas do
		local junta = vinculo.junta
		local anterior, aplicado = vinculo.anterior, vinculo.aplicado
		if junta.Parent and anterior and aplicado and junta.Transform:FuzzyEq(aplicado, 0.0001) then
			junta.Transform = anterior
		end
		vinculo.anterior = nil
		vinculo.aplicado = nil
	end
end

-- O Animator nem sempre escreve todas as juntas. Retire a nossa pose antes
-- da próxima avaliação para não misturá-la com ela própria ou deixá-la presa.
function Presenca.antesDaAnimacao()
	for _, a in ativas do
		restaurar(a)
	end
end

local function posar(
	vinculo: Vinculo?,
	x: number,
	y: number,
	z: number,
	peso: number,
	altura: number?
)
	if not vinculo or not vinculo.junta.Parent then
		return
	end
	local junta = vinculo.junta
	local pose = CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
	local baseR6 = vinculo.baseR6
	local anterior = junta.Transform
	local orientacao = anterior:Lerp(baseR6:Inverse() * pose * baseR6, peso)
	local aplicado = CFrame.new(anterior.Position + Vector3.new(0, altura or 0, 0))
		* orientacao.Rotation
	junta.Transform = aplicado
	vinculo.anterior = anterior
	vinculo.aplicado = aplicado
end

function Presenca.simular(dt: number)
	for personagem, a in ativas do
		local jogador = Players:GetPlayerFromCharacter(personagem)
		if
			not a.visivel
			or not a.raiz.Parent
			or a.humanoide.Health <= 0
			or a.humanoide.Sit
			or (jogador and jogador:GetAttribute("EmDueloArena"))
			or Poses.ocupada(personagem)
		then
			a.fase = 0
			a.misturaIdle = 0
			a.contatoIdle = false
			continue
		end
		if a.relerJuntas then
			lerJuntas(personagem, a)
		end

		local velocidade = a.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(velocidade.X, 0, velocidade.Z).Magnitude
		local noChao = a.humanoide.FloorMaterial ~= Enum.Material.Air
		local parado = noChao and rapidez < 2 and a.humanoide.MoveDirection.Magnitude < 0.1
		local escala = if movimentoReduzido then 0.24 else 1
		local mistura = 1 - math.exp(-14 * dt)
		local alvoIdle = if parado then 1 else 0
		a.misturaIdle += (alvoIdle - a.misturaIdle) * mistura

		if parado and not movimentoReduzido then
			local proxima, contato = Movimento.avancar(a.fase, dt)
			a.fase = proxima
			a.contatoIdle = (a.contatoIdle or contato) and a.juntas.raiz ~= nil
		elseif a.misturaIdle < 0.02 or movimentoReduzido then
			a.fase = 0
		end

		local altura, compressao = Movimento.amostrar(a.fase)
		local suspenso = math.max(0, altura)
		local idle = a.misturaIdle
		local voo = if noChao then 0 else 1
		local peso = math.max(idle, 0.48 + 0.26 * voo)
		local oscilar = math.sin(os.clock() * 8)
		local mover = (1 - idle) * (1 - voo)
		local salto = (1 - idle) * voo
		local quique = if noChao and not movimentoReduzido then altura * idle else 0
		local abaixar = if movimentoReduzido then 0 else compressao
		local juntas = a.juntas
		local tronco = (-21 + 27 * abaixar) * idle - 15 * salto + 8 * mover

		posar(
			juntas.raiz,
			tronco * (if juntas.cintura then 0.28 else 0.78),
			0,
			-8 * idle,
			peso * escala,
			quique
		)
		posar(juntas.cintura, tronco, -9 * idle, -10 * idle, peso * escala)
		posar(juntas.pescoco, (-8 + 15 * abaixar) * idle, 7 * idle, 10 * idle, peso * escala)
		-- Mão direita sobre a testa, braço esquerdo aberto e pernas assimétricas.
		posar(
			juntas.ombroD,
			(114 + 17 * suspenso - 16 * abaixar) * idle + 32 * salto + 34 * mover,
			0,
			-22 * idle + 28 * salto,
			peso * escala
		)
		posar(
			juntas.ombroE,
			(20 + 12 * abaixar) * idle + 35 * salto - 22 * oscilar * mover,
			0,
			(-60 - 15 * suspenso) * idle - 42 * salto - 18 * mover,
			peso * escala
		)
		posar(juntas.cotoveloD, -48 * idle - 35 * salto - 40 * mover, 0, 0, peso * escala)
		posar(juntas.cotoveloE, -18 * idle - 16 * salto - 15 * mover, 0, 0, peso * escala)
		-- Na corrida, mantenha a passada do Animator. Dê forma às pernas no quique e no ar.
		local pesoPernas = (idle + salto * 0.65) * escala
		if pesoPernas > 0.02 then
			posar(
				juntas.quadrilD,
				(-20 - 44 * abaixar - 22 * suspenso) * idle - 34 * salto,
				0,
				10 * idle,
				pesoPernas
			)
			posar(
				juntas.quadrilE,
				(11 - 42 * abaixar - 29 * suspenso) * idle + 12 * salto,
				0,
				-12 * idle,
				pesoPernas
			)
			posar(
				juntas.joelhoD,
				(20 + 68 * abaixar + 40 * suspenso) * idle + 46 * salto,
				0,
				0,
				pesoPernas
			)
			posar(
				juntas.joelhoE,
				(14 + 62 * abaixar + 46 * suspenso) * idle + 62 * salto,
				0,
				0,
				pesoPernas
			)
		end
	end
end

function Presenca.remover(personagem: Model)
	local a = ativas[personagem]
	if a then
		restaurar(a)
		for _, conexao in a.conexoes do
			conexao:Disconnect()
		end
		ativas[personagem] = nil
	end
end

function Presenca.definir(personagem: Model, id: string?)
	if id ~= "gear5" then
		Presenca.remover(personagem)
		return
	end
	if ativas[personagem] then
		return
	end
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if not raiz or not raiz:IsA("BasePart") or not humanoide then
		return
	end
	local a: Ativa = {
		raiz = raiz,
		humanoide = humanoide,
		fase = 0,
		misturaIdle = 0,
		contatoIdle = false,
		juntas = {},
		relerJuntas = true,
		conexoes = {},
		noAr = humanoide.FloorMaterial == Enum.Material.Air,
		velocidadeQueda = 0,
		proximoPasso = os.clock() + 0.25,
		ultimoImpacto = 0,
		visivel = true,
	}
	ativas[personagem] = a
	local function invalidar(obj: Instance)
		if NOMES_JUNTAS[obj.Name] and (obj:IsA("Motor6D") or obj:IsA("AnimationConstraint")) then
			a.relerJuntas = true
		end
	end
	a.conexoes = {
		personagem.DescendantAdded:Connect(invalidar),
		personagem.DescendantRemoving:Connect(invalidar),
	}
end

function Presenca.definirQualidade(baixa: boolean, reduzido: boolean)
	qualidadeBaixa = baixa
	movimentoReduzido = reduzido
end

function Presenca.atualizar(_dt: number, camera: Vector3)
	local agora = os.clock()
	for personagem, a in ativas do
		if not personagem.Parent or not a.raiz.Parent or a.humanoide.Health <= 0 then
			Presenca.remover(personagem)
			continue
		end
		local jogador = Players:GetPlayerFromCharacter(personagem)
		local distancia = (a.raiz.Position - camera).Magnitude
		a.visivel = distancia <= DISTANCIA_POSE
		local ar = a.humanoide.FloorMaterial == Enum.Material.Air
		local v = a.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local contatoIdle = a.contatoIdle
		a.contatoIdle = false

		if
			not a.visivel
			or a.humanoide.Sit
			or (jogador and jogador:GetAttribute("EmDueloArena"))
		then
			a.noAr = ar
			a.velocidadeQueda = 0
			continue
		end

		local pousou = a.noAr and not ar
		if ar then
			a.velocidadeQueda = if a.noAr then math.min(a.velocidadeQueda, v.Y) else v.Y
		elseif pousou and a.velocidadeQueda < -8 and agora - a.ultimoImpacto > 0.35 then
			marcarChao(a, math.clamp(-a.velocidadeQueda / 32, 0.6, 1.7), camera)
			a.ultimoImpacto = agora
		end
		a.noAr = ar

		if ar or pousou or movimentoReduzido or qualidadeBaixa or Poses.ocupada(personagem) then
			continue
		end
		if contatoIdle and rapidez < 2 and agora - a.ultimoImpacto > 0.35 then
			marcarChao(a, 0.8, camera)
			a.ultimoImpacto = agora
		elseif rapidez > 5 and agora >= a.proximoPasso then
			marcarChao(a, 0.42, camera)
			a.proximoPasso = agora + 0.65
		end
	end
	animarChao()
end

return Presenca
