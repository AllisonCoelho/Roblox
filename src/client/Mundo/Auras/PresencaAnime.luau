-- Presenca das auras de anime: linguagem corporal e resposta do cenario.
-- Primeira identidade: Gear 5. Efeitos puramente locais, sem mudar colisao, terrain ou save.
-- Um unico laço de animação (PreSimulation) e um de VFX (PreRender), geridos pelo Controlador.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Poses = require(script.Parent.Parent.Incursoes.Poses)
local Haki = require(script.Parent.Gear5Haki)
local Movimento = require(script.Parent.Gear5Movimento)
local Quadros = require(script.Parent.Gear5Poses)

local Presenca = {}

type Junta = Motor6D | AnimationConstraint
type Vinculo = {
	junta: Junta,
	baseR6: CFrame,
	canal: string,
	anterior: CFrame?,
	aplicado: CFrame?,
}

type Ativa = {
	personagem: Model,
	raiz: BasePart,
	humanoide: Humanoid,
	fasePasso: number,
	tempoIdle: number,
	misturaPasso: number,
	misturaAr: number,
	contatoPasso: string?,
	juntas: { [string]: Vinculo },
	relerJuntas: boolean,
	conexoes: { RBXScriptConnection },
	noAr: boolean,
	velocidadeQueda: number,
	ultimoImpacto: number,
	visivel: boolean,
	hakiPendente: string?, -- quadro da animação parada que pede o Haki do Rei
	passos: number, -- pisadas desde o último haki da corrida
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

local function marcarChao(a: Ativa, intensidade: number, camera: Vector3, pe: BasePart?)
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
	local origem = if pe then pe.Position else a.raiz.Position
	local hit = Workspace:Raycast(origem + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), params)
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
	RightAnkle = "tornozeloD",
	LeftAnkle = "tornozeloE",
}

local function lerJuntas(personagem: Model, a: Ativa)
	local r6 = a.humanoide.RigType == Enum.HumanoidRigType.R6
	table.clear(a.juntas)
	for _, obj in personagem:GetDescendants() do
		local nome = NOMES_JUNTAS[obj.Name]
		if nome and (obj:IsA("Motor6D") or obj:IsA("AnimationConstraint")) then
			a.juntas[nome] = {
				junta = obj,
				canal = if r6 and Quadros.risada[nome .. "R6"] then nome .. "R6" else nome,
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

local function posar(vinculo: Vinculo, pose: CFrame, peso: number, altura: number)
	local junta = vinculo.junta
	if not junta.Parent then
		return
	end
	local baseR6 = vinculo.baseR6
	local anterior = junta.Transform
	local orientacao = anterior:Lerp(baseR6:Inverse() * pose * baseR6, peso)
	local aplicado = CFrame.new(anterior.Position + Vector3.new(0, altura, 0)) * orientacao.Rotation
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
			a.misturaPasso = 0
			a.misturaAr = 0
			a.contatoPasso = nil
			continue
		end
		if a.relerJuntas then
			lerJuntas(personagem, a)
		end

		local v = a.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local noChao = a.humanoide.FloorMaterial ~= Enum.Material.Air
		local andando = noChao and rapidez > 0.65
		local mistura = 1 - math.exp(-12 * dt)
		local alvoPasso = if andando then 1 else 0
		local alvoAr = if noChao then 0 else 1
		a.misturaPasso += (alvoPasso - a.misturaPasso) * mistura
		a.misturaAr += (alvoAr - a.misturaAr) * mistura
		if andando then
			local fase, pe = Movimento.passo(a.fasePasso, dt, rapidez)
			a.fasePasso = fase
			a.contatoPasso = pe or a.contatoPasso
			if a.misturaPasso > 0.95 then
				a.tempoIdle = 0
			end
		elseif noChao then
			local antes = a.tempoIdle
			a.tempoIdle += dt
			-- Haki do Rei sincronizado com a pose: auge da risada ou meio do repouso
			a.hakiPendente = Movimento.hakiParado(antes, a.tempoIdle) or a.hakiPendente
		end

		local relaxar, flutuar = Movimento.parado(a.tempoIdle)
		local esquerda, indice, t, quique = Movimento.corrida(a.fasePasso)
		local passos = if esquerda then Quadros.passoE else Quadros.passoD
		local escala = if movimentoReduzido then 0.26 else 1
		local alturaIdle = 0.21 + 0.14 * relaxar + flutuar
		local alturaPasso = quique * math.clamp(0.62 + rapidez * 0.025, 0.62, 1)
		local altura = (alturaIdle + (alturaPasso - alturaIdle) * a.misturaPasso)
			* (1 - a.misturaAr)
			* escala

		for nome, vinculo in a.juntas do
			local canal = vinculo.canal
			local idle = Quadros.risada[canal]:Lerp(Quadros.relaxado[canal], relaxar)
			local passo = passos[indice][canal]:Lerp(passos[indice + 1][canal], t)
			local pose = idle:Lerp(passo, a.misturaPasso):Lerp(Quadros.salto[canal], a.misturaAr)
			posar(vinculo, pose, escala, if nome == "raiz" then altura else 0)
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
		personagem = personagem,
		raiz = raiz,
		humanoide = humanoide,
		fasePasso = 0,
		tempoIdle = 0,
		misturaPasso = 0,
		misturaAr = 0,
		juntas = {},
		relerJuntas = true,
		conexoes = {},
		noAr = humanoide.FloorMaterial == Enum.Material.Air,
		velocidadeQueda = 0,
		ultimoImpacto = 0,
		visivel = true,
		passos = 0,
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
	Haki.definirQualidade(baixa, reduzido)
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
		local contatoPasso = a.contatoPasso
		a.contatoPasso = nil

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
			local forca = Movimento.hakiPouso(a.velocidadeQueda)
			if forca and not Poses.ocupada(personagem) then
				Haki.disparar(personagem, a.raiz, "pouso", forca)
			end
		end
		a.noAr = ar

		local pendente = a.hakiPendente
		a.hakiPendente = nil
		if pendente and not ar and not Poses.ocupada(personagem) then
			Haki.disparar(personagem, a.raiz, pendente :: any)
		end

		if ar or pousou or movimentoReduzido or qualidadeBaixa or Poses.ocupada(personagem) then
			continue
		end
		if contatoPasso and agora - a.ultimoImpacto > 0.14 then
			local nome = if contatoPasso == "D" then "Right" else "Left"
			local pe = personagem:FindFirstChild(nome .. "Foot")
				or personagem:FindFirstChild(nome .. " Leg")
			marcarChao(a, 0.64, camera, if pe and pe:IsA("BasePart") then pe else nil)
			a.ultimoImpacto = agora
			a.passos += 1
			if a.passos >= Movimento.HAKI_PASSOS then
				a.passos = 0
				Haki.disparar(personagem, a.raiz, "passo", 0.8)
			end
		end
	end
	animarChao()
end

return Presenca
