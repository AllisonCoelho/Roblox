-- Corpo do jogador no duelo da Arena: postura de luta, corrida até o Soberano, golpes, guarda,
-- reações aos golpes recebidos, vitória e derrota. Tudo por código (sem asset de animação):
-- depois que o Animator escreve o quadro, a pose do clipe substitui as juntas (Motor6D.Transform).
--
-- Quem está em duelo e qual clipe tocar vem dos atributos do Player (o servidor escreve
-- ArenaAnim e ArenaAnimEm). Assim, quem assiste vê o mesmo movimento do desafiante.
-- R15 completo; o R6 usa braços, tronco e quadris (não tem cotovelo nem joelho).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Animacoes = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("ArenaAnimacoes")
)

local ArenaCorpo = {}

export type Preferencias = { movimentoReduzido: boolean }
local prefs: Preferencias = { movimentoReduzido = false }

function ArenaCorpo.definir(novas: Preferencias)
	prefs = novas
end

type Juntas = {
	r15: boolean,
	raiz: Motor6D?,
	cintura: Motor6D?,
	pescoco: Motor6D?,
	ombroD: Motor6D?,
	cotoveloD: Motor6D?,
	ombroE: Motor6D?,
	cotoveloE: Motor6D?,
	quadrilD: Motor6D?,
	joelhoD: Motor6D?,
	quadrilE: Motor6D?,
	joelhoE: Motor6D?,
}

type Ativo = {
	personagem: Model,
	juntas: Juntas,
	pose: Animacoes.Pose?, -- pose mostrada no quadro anterior (para suavizar)
	inicio: number, -- os.clock() de quando o duelo começou neste cliente
}

local ativos: { [Player]: Ativo } = {}
local DISTANCIA = 260

local function motor(personagem: Model, parte: string, nome: string): Motor6D?
	local p = personagem:FindFirstChild(parte)
	local m = p and p:FindFirstChild(nome)
	return if m and m:IsA("Motor6D") then m else nil
end

local function lerJuntas(personagem: Model): Juntas
	if personagem:FindFirstChild("UpperTorso") then
		return {
			r15 = true,
			raiz = motor(personagem, "LowerTorso", "Root"),
			cintura = motor(personagem, "UpperTorso", "Waist"),
			pescoco = motor(personagem, "Head", "Neck"),
			ombroD = motor(personagem, "RightUpperArm", "RightShoulder"),
			cotoveloD = motor(personagem, "RightLowerArm", "RightElbow"),
			ombroE = motor(personagem, "LeftUpperArm", "LeftShoulder"),
			cotoveloE = motor(personagem, "LeftLowerArm", "LeftElbow"),
			quadrilD = motor(personagem, "RightUpperLeg", "RightHip"),
			joelhoD = motor(personagem, "RightLowerLeg", "RightKnee"),
			quadrilE = motor(personagem, "LeftUpperLeg", "LeftHip"),
			joelhoE = motor(personagem, "LeftLowerLeg", "LeftKnee"),
		}
	end
	return {
		r15 = false,
		raiz = motor(personagem, "HumanoidRootPart", "RootJoint"),
		pescoco = motor(personagem, "Torso", "Neck"),
		ombroD = motor(personagem, "Torso", "Right Shoulder"),
		ombroE = motor(personagem, "Torso", "Left Shoulder"),
		quadrilD = motor(personagem, "Torso", "Right Hip"),
		quadrilE = motor(personagem, "Torso", "Left Hip"),
	}
end

local rad = math.rad

local function giro(p: Animacoes.Pose, nome: string): CFrame
	return CFrame.Angles(
		rad(p[nome .. "1"] or 0),
		rad(p[nome .. "2"] or 0),
		rad(p[nome .. "3"] or 0)
	)
end

local function escrever(m: Motor6D?, cf: CFrame)
	if m then
		m.Transform = cf
	end
end

local function aplicarR15(j: Juntas, p: Animacoes.Pose)
	escrever(
		j.raiz,
		CFrame.new(p.raiz1 or 0, p.raiz2 or 0, p.raiz3 or 0)
			* CFrame.Angles(rad(p.raiz4 or 0), rad(p.raiz5 or 0), rad(p.raiz6 or 0))
	)
	escrever(j.cintura, giro(p, "cintura"))
	escrever(j.pescoco, giro(p, "pescoco"))
	escrever(j.ombroD, giro(p, "ombroD"))
	escrever(j.cotoveloD, giro(p, "cotoveloD"))
	escrever(j.ombroE, giro(p, "ombroE"))
	escrever(j.cotoveloE, giro(p, "cotoveloE"))
	escrever(j.quadrilD, CFrame.Angles(rad(p.quadrilD1 or 0), 0, rad(p.abrirD1 or 0)))
	escrever(j.joelhoD, CFrame.Angles(rad(p.joelhoD1 or 0), 0, 0))
	escrever(j.quadrilE, CFrame.Angles(rad(p.quadrilE1 or 0), 0, rad(p.abrirE1 or 0)))
	escrever(j.joelhoE, CFrame.Angles(rad(p.joelhoE1 or 0), 0, 0))
end

-- R6: as juntas têm outra orientação (mesma conversão de Incursoes/Poses). Sem joelho, a perna
-- usa o ângulo médio da coxa e da canela, e o corpo desce menos para os pés não afundarem.
local function aplicarR6(j: Juntas, p: Animacoes.Pose)
	local dy = math.max(p.raiz2 or 0, -0.15)
	local x = rad((p.raiz4 or 0) + (p.cintura1 or 0))
	local y = rad((p.raiz5 or 0) + (p.cintura2 or 0))
	local z = rad((p.raiz6 or 0) + (p.cintura3 or 0))
	escrever(j.raiz, CFrame.new(-(p.raiz1 or 0), p.raiz3 or 0, dy) * CFrame.Angles(-x, z, y))
	escrever(
		j.pescoco,
		CFrame.Angles(-rad(p.pescoco1 or 0), rad(p.pescoco3 or 0), rad(p.pescoco2 or 0))
	)
	local function membro(m: Motor6D?, frente: number, abrir: number, direito: boolean)
		if direito then
			escrever(m, CFrame.Angles(-rad(abrir), 0, rad(frente)))
		else
			escrever(m, CFrame.Angles(rad(abrir), 0, -rad(frente)))
		end
	end
	membro(j.ombroD, (p.ombroD1 or 0) + (p.cotoveloD1 or 0) * 0.4, p.ombroD3 or 0, true)
	membro(j.ombroE, (p.ombroE1 or 0) + (p.cotoveloE1 or 0) * 0.4, p.ombroE3 or 0, false)
	membro(j.quadrilD, (p.quadrilD1 or 0) + (p.joelhoD1 or 0) * 0.5, p.abrirD1 or 0, true)
	membro(j.quadrilE, (p.quadrilE1 or 0) + (p.joelhoE1 or 0) * 0.5, p.abrirE1 or 0, false)
end

-- Pose deste quadro: o clipe pedido pelo servidor (se já começou) ou a postura de luta
local function poseAlvo(jogador: Player, a: Ativo): (Animacoes.Pose, boolean)
	local agora = Workspace:GetServerTimeNow()
	local nome = jogador:GetAttribute("ArenaAnim")
	local em = jogador:GetAttribute("ArenaAnimEm")
	local clipe = if type(nome) == "string" then Animacoes.JOGADOR[nome] else nil
	if clipe and type(em) == "number" and agora >= em then
		local t = agora - em
		if t < clipe.duracao or clipe.segurar then
			return Animacoes.amostrar(clipe, t), true
		end
	end
	-- antes de o clipe começar (reação marcada para o impacto) ou depois de terminar
	local postura = Animacoes.JOGADOR.postura
	return Animacoes.amostrar(postura, os.clock() - a.inicio), false
end

local function reduzir(p: Animacoes.Pose): Animacoes.Pose
	-- movimento reduzido: sem giros completos nem saltos; amplitudes pela metade
	local r = table.clone(p)
	for nome, v in p do
		if nome == "raiz5" then
			r[nome] = v % 360
			if r[nome] > 180 then
				r[nome] -= 360
			end
			r[nome] *= 0.4
		elseif nome:sub(1, 4) == "raiz" then
			r[nome] = v * 0.5
		end
	end
	return r
end

local function atualizar(dt: number)
	local camera = Workspace.CurrentCamera
	for jogador, a in ativos do
		local personagem = jogador.Character
		if not personagem or personagem ~= a.personagem or not personagem.Parent then
			ativos[jogador] = nil
			continue
		end
		local raiz = personagem:FindFirstChild("HumanoidRootPart")
		if
			camera
			and raiz
			and raiz:IsA("BasePart")
			and (camera.CFrame.Position - raiz.Position).Magnitude > DISTANCIA
		then
			continue
		end
		local alvo, emClipe = poseAlvo(jogador, a)
		if prefs.movimentoReduzido then
			alvo = reduzir(alvo)
		end
		-- suavização curta: troca de clipe e chegada da reação sem estalo
		local anterior = a.pose
		local pose = if anterior
			then Animacoes.misturar(
				anterior,
				alvo,
				1 - math.exp(-dt * (if emClipe then 30 else 10))
			)
			else alvo
		a.pose = pose
		local final =
			Animacoes.resolverPernas(table.clone(pose), Animacoes.PERNA_R15, Animacoes.PERNA_R15)
		if a.juntas.r15 then
			aplicarR15(a.juntas, final)
		else
			aplicarR6(a.juntas, final)
		end
	end
end

local function acompanhar(jogador: Player)
	local function revisar()
		local personagem = jogador.Character
		if jogador:GetAttribute("EmDueloArena") and personagem then
			local a = ativos[jogador]
			if not a or a.personagem ~= personagem then
				ativos[jogador] = {
					personagem = personagem,
					juntas = lerJuntas(personagem),
					pose = nil,
					inicio = os.clock(),
				}
			end
		else
			ativos[jogador] = nil
		end
	end
	jogador:GetAttributeChangedSignal("EmDueloArena"):Connect(revisar)
	jogador.CharacterAdded:Connect(function()
		ativos[jogador] = nil
		task.defer(revisar)
	end)
	revisar()
end

function ArenaCorpo.iniciar()
	for _, jogador in Players:GetPlayers() do
		acompanhar(jogador)
	end
	Players.PlayerAdded:Connect(acompanhar)
	Players.PlayerRemoving:Connect(function(jogador)
		ativos[jogador] = nil
	end)
	-- PreSimulation: depois que o Animator escreveu o quadro, antes da física
	RunService.PreSimulation:Connect(atualizar)
end

return ArenaCorpo
