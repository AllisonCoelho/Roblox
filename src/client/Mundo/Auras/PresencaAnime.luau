-- Presenca das auras de anime: linguagem corporal e resposta do cenario.
-- Primeira identidade: Gear 5. Efeitos puramente locais, sem mudar colisao, terrain ou save.
-- Um unico laço de animação (PreSimulation) e um de VFX (PreRender), geridos pelo Controlador.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Poses = require(script.Parent.Parent.Incursoes.Poses)

local Presenca = {}

type Ativa = {
	personagem: Model,
	raiz: BasePart,
	humanoide: Humanoid,
	fase: number,
	noAr: boolean,
	velocidadeQueda: number,
	proximoIdle: number,
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
local INTERVALO_IDLE = 1.25

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
	local hit = Workspace:Raycast(
		a.raiz.Position + Vector3.new(0, 1, 0),
		Vector3.new(0, -9, 0),
		params
	)
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
	local miolo = criarParte(cor, 0.38)
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
			m.miolo.Transparency = 0.38 + t * 0.62
			if m.borda then
				local rb = r * (1.05 + 0.45 * t)
				m.borda.Size = Vector3.new(rb * 2, 0.10, rb * 2)
				m.borda.CFrame = m.base * CFrame.new(0, 0.03, 0)
				m.borda.Transparency = 0.67 + t * 0.33
			end
		end
	end
end

local function motor(p: Model, r15: string, r6: string?): Motor6D?
	local joint = p:FindFirstChild(r15, true)
	if not joint and r6 then
		joint = p:FindFirstChild(r6, true)
	end
	return if joint and joint:IsA("Motor6D") then joint else nil
end

local function sobrepor(junta: Motor6D?, pose: CFrame)
	if junta then
		-- O Animator ja escreveu Transform neste quadro; adicionamos somente um offset.
		junta.Transform = junta.Transform * pose
	end
end

-- Pose ociosa inspirada na silhueta de risada da Gear 5: mão sobre a cabeça,
-- braço solto, tronco inclinado e pernas quicando. Nunca move o HumanoidRootPart.
-- Aterrissagem usa a pose de braços abertos; movimento tem um balanço mais rápido.
function Presenca.simular(_dt: number)
	local agora = os.clock()
	for personagem, a in ativas do
		local jogador = Players:GetPlayerFromCharacter(personagem)
		if
			not a.visivel
			or a.humanoide.Health <= 0
			or a.humanoide.Sit
			or (jogador and jogador:GetAttribute("EmDueloArena"))
			or Poses.ocupada(personagem)
		then
			continue
		end
		local velocidade = a.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(velocidade.X, 0, velocidade.Z).Magnitude
		local pesoIdle = math.clamp(1 - rapidez / 13, 0, 1)
		local ar = a.humanoide.FloorMaterial == Enum.Material.Air
		local fase = agora * 5.0 + a.fase
		local quique = math.max(0, math.sin(fase))
		local escala = if movimentoReduzido then 0.18 else 1
		local alegria = pesoIdle * escala
		local corrida = (1 - pesoIdle) * escala
		local voo = if ar then escala else 0
		local subir = if ar then 0 else quique * alegria * 0.19
		local girar = math.sin(fase * 0.5) * alegria * 7
		local inclinar = (-10 * alegria + 4 * corrida - 13 * voo)

		local raiz = motor(personagem, "Root", "RootJoint")
		local cintura = motor(personagem, "Waist")
		local pescoco = motor(personagem, "Neck")
		local ombroD = motor(personagem, "RightShoulder", "Right Shoulder")
		local ombroE = motor(personagem, "LeftShoulder", "Left Shoulder")
		local quadrilD = motor(personagem, "RightHip", "Right Hip")
		local quadrilE = motor(personagem, "LeftHip", "Left Hip")

		sobrepor(raiz, CFrame.new(0, subir, 0) * CFrame.Angles(math.rad(inclinar * 0.3), 0, math.rad(girar * 0.3)))
		sobrepor(cintura, CFrame.Angles(math.rad(inclinar), math.rad(girar), math.rad(7 * alegria)))
		sobrepor(pescoco, CFrame.Angles(math.rad(-16 * alegria + 5 * voo), 0, math.rad(-4 * alegria)))
		-- Uma mao sobre a testa, outra para fora: silhueta reconhecivel no idle.
		sobrepor(
			ombroD,
			CFrame.Angles(math.rad(93 * alegria + 25 * voo), 0, math.rad(-27 * alegria))
		)
		sobrepor(
			ombroE,
			CFrame.Angles(math.rad(37 * alegria + 40 * voo), 0, math.rad(55 * alegria))
		)
		sobrepor(
			quadrilD,
			CFrame.Angles(math.rad(22 * alegria + 20 * voo + 9 * math.sin(fase) * corrida), 0, 0)
		)
		sobrepor(
			quadrilE,
			CFrame.Angles(math.rad(-13 * alegria + 15 * voo - 9 * math.sin(fase) * corrida), 0, 0)
		)
	end
end

function Presenca.remover(personagem: Model)
	ativas[personagem] = nil
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
	local agora = os.clock()
	ativas[personagem] = {
		personagem = personagem,
		raiz = raiz,
		humanoide = humanoide,
		fase = math.random() * math.pi * 2,
		noAr = humanoide.FloorMaterial == Enum.Material.Air,
		velocidadeQueda = 0,
		proximoIdle = agora + 0.25,
		proximoPasso = agora + 0.25,
		ultimoImpacto = 0,
		visivel = true,
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
			ativas[personagem] = nil
			continue
		end
		local jogador = Players:GetPlayerFromCharacter(personagem)
		local distancia = (a.raiz.Position - camera).Magnitude
		a.visivel = distancia <= DISTANCIA_POSE
		local ar = a.humanoide.FloorMaterial == Enum.Material.Air
		local v = a.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		if ar then
			a.velocidadeQueda = if a.noAr then math.min(a.velocidadeQueda, v.Y) else v.Y
		elseif a.noAr and a.velocidadeQueda < -8 and agora - a.ultimoImpacto > 0.35 then
			local intensidade = math.clamp(-a.velocidadeQueda / 32, 0.6, 1.7)
			marcarChao(a, intensidade, camera)
			a.ultimoImpacto = agora
		end
		a.noAr = ar
		if
			ar
			or not a.visivel
			or a.humanoide.Sit
			or (jogador and jogador:GetAttribute("EmDueloArena"))
		then
			continue
		end
		-- Pequenos pulsos a cada quiques do idle e ondas deixadas pelo caminho.
		if rapidez < 2 and not movimentoReduzido and agora >= a.proximoIdle then
			if not qualidadeBaixa then
				marcarChao(a, 0.45, camera)
			end
			a.proximoIdle = agora + INTERVALO_IDLE
		elseif rapidez > 5 and not movimentoReduzido and agora >= a.proximoPasso then
			if not qualidadeBaixa then
				marcarChao(a, 0.3, camera)
			end
			a.proximoPasso = agora + 0.65
		end
	end
	animarChao()
end

return Presenca
