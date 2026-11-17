-- Poses procedurais do combate: o corpo do personagem se mexe com cada técnica (soco, carga,
-- varredura, braços para cima, guarda cruzada). Sem asset de animação: depois que o Animator
-- aplica a animação normal do quadro, misturamos a pose nas juntas (Motor6D.Transform).
-- Funciona em R15 e R6; vale para todos os jogadores visíveis (só neste cliente).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Poses = {}

-- Uma pose-chave: braços (frente = ergue para a frente, abrir = afasta do corpo), cintura e tronco
type Braco = { number }? -- { frente graus, abrir graus }
type Chave = { t: number, d: Braco, e: Braco, giro: number?, inclinar: number? }
type Ativa = {
	chaves: { Chave },
	inicio: number,
	duracao: number,
	esconder: { string }?, -- partes do braço escondidas (Gear 5: o braço de borracha sai do ombro)
	manter: boolean?,
}

local Z: Braco = { 0, 0 }

-- d = braço direito, e = esquerdo. t em 0..1 da duração.
Poses.BIBLIOTECA = {
	golpe1 = { -- jab direito
		{ t = 0, d = Z, e = Z, giro = 0 },
		{ t = 0.25, d = { 95, 5 }, e = { 30, -10 }, giro = -28, inclinar = -8 },
		{ t = 0.6, d = { 90, 5 }, e = { 30, -10 }, giro = -24, inclinar = -6 },
		{ t = 1, d = Z, e = Z, giro = 0 },
	},
	golpe2 = { -- jab esquerdo
		{ t = 0, d = Z, e = Z, giro = 0 },
		{ t = 0.25, d = { 30, -10 }, e = { 95, 5 }, giro = 28, inclinar = -8 },
		{ t = 0.6, d = { 30, -10 }, e = { 90, 5 }, giro = 24, inclinar = -6 },
		{ t = 1, d = Z, e = Z, giro = 0 },
	},
	golpe3 = { -- gancho com os dois braços
		{ t = 0, d = Z, e = Z },
		{ t = 0.2, d = { -20, 20 }, e = { -20, 20 }, inclinar = 10 },
		{ t = 0.45, d = { 150, 10 }, e = { 150, 10 }, inclinar = -14 },
		{ t = 0.7, d = { 130, 10 }, e = { 130, 10 }, inclinar = -10 },
		{ t = 1, d = Z, e = Z },
	},
	carga = { -- puxa a mão para trás e solta para a frente (Esfera / Pistola)
		{ t = 0, d = Z, e = Z },
		{ t = 0.3, d = { -35, 25 }, e = { 40, 20 }, giro = 35, inclinar = 6 },
		{ t = 0.45, d = { 95, 0 }, e = { 20, 10 }, giro = -30, inclinar = -12 },
		{ t = 0.8, d = { 90, 0 }, e = { 20, 10 }, giro = -25, inclinar = -10 },
		{ t = 1, d = Z, e = Z },
	},
	varrer = { -- cruza os braços e abre em leque (Onda)
		{ t = 0, d = Z, e = Z },
		{ t = 0.3, d = { 80, -60 }, e = { 80, -60 }, inclinar = 8 },
		{ t = 0.55, d = { 85, 70 }, e = { 85, 70 }, inclinar = -12 },
		{ t = 0.85, d = { 80, 65 }, e = { 80, 65 }, inclinar = -8 },
		{ t = 1, d = Z, e = Z },
	},
	rajada = { -- Gatling: braços alternando rápido à frente
		{ t = 0, d = Z, e = Z },
		{ t = 0.1, d = { 90, 0 }, e = { 60, 0 }, inclinar = -10 },
		{ t = 0.2, d = { 60, 0 }, e = { 90, 0 }, inclinar = -10 },
		{ t = 0.3, d = { 90, 0 }, e = { 60, 0 }, inclinar = -10 },
		{ t = 0.4, d = { 60, 0 }, e = { 90, 0 }, inclinar = -10 },
		{ t = 0.5, d = { 90, 0 }, e = { 60, 0 }, inclinar = -10 },
		{ t = 0.6, d = { 60, 0 }, e = { 90, 0 }, inclinar = -10 },
		{ t = 0.7, d = { 90, 0 }, e = { 60, 0 }, inclinar = -10 },
		{ t = 0.85, d = { 70, 0 }, e = { 80, 0 }, inclinar = -8 },
		{ t = 1, d = Z, e = Z },
	},
	despertar = { -- braços ao céu, depois desce com tudo
		{ t = 0, d = Z, e = Z },
		{ t = 0.35, d = { 170, 25 }, e = { 170, 25 }, inclinar = 14 },
		{ t = 0.65, d = { 175, 15 }, e = { 175, 15 }, inclinar = 16 },
		{ t = 0.78, d = { 60, 10 }, e = { 60, 10 }, inclinar = -25 },
		{ t = 1, d = Z, e = Z },
	},
	esquiva = {
		{ t = 0, d = Z, e = Z },
		{ t = 0.3, d = { -40, 15 }, e = { -40, 15 }, inclinar = -28 },
		{ t = 1, d = Z, e = Z },
	},
	guarda = { -- braços cruzados na frente (mantida enquanto segura F)
		{ t = 0, d = { 85, -55 }, e = { 85, -55 }, inclinar = -6 },
		{ t = 1, d = { 85, -55 }, e = { 85, -55 }, inclinar = -6 },
	},
} :: { [string]: { Chave } }

local ativas: { [Model]: Ativa } = {}
local escondidas: { [Model]: { BasePart } } = {}

local function suave(t: number): number
	return t * t * (3 - 2 * t)
end

local function amostra(chaves: { Chave }, t: number): (Braco, Braco, number, number)
	local a, b = chaves[1], chaves[#chaves]
	for i = 1, #chaves - 1 do
		if t >= chaves[i].t and t <= chaves[i + 1].t then
			a, b = chaves[i], chaves[i + 1]
			break
		end
	end
	local f = if b.t > a.t then suave((t - a.t) / (b.t - a.t)) else 1
	local function braco(x: Braco, y: Braco): Braco
		local p, q = x or Z, y or Z
		return { p[1] + (q[1] - p[1]) * f, p[2] + (q[2] - p[2]) * f }
	end
	local giro = (a.giro or 0) + ((b.giro or 0) - (a.giro or 0)) * f
	local incl = (a.inclinar or 0) + ((b.inclinar or 0) - (a.inclinar or 0)) * f
	return braco(a.d, b.d), braco(a.e, b.e), giro, incl
end

local function motor(pai: Instance?, nome: string): Motor6D?
	local m = pai and pai:FindFirstChild(nome)
	return if m and m:IsA("Motor6D") then m else nil
end

local function mostrar(personagem: Model)
	for _, p in (escondidas[personagem] or {}) :: { BasePart } do
		p.LocalTransparencyModifier = 0
	end
	escondidas[personagem] = nil
end

local function aplicar(personagem: Model, d: Braco, e: Braco, giro: number, incl: number)
	local dd, ee = d or Z, e or Z
	local r15 = personagem:FindFirstChild("UpperTorso")
	if r15 then
		local od = motor(personagem:FindFirstChild("RightUpperArm"), "RightShoulder")
		local oe = motor(personagem:FindFirstChild("LeftUpperArm"), "LeftShoulder")
		local cintura = motor(r15, "Waist")
		if od then
			od.Transform = CFrame.Angles(math.rad(dd[1]), 0, math.rad(dd[2]))
		end
		if oe then
			oe.Transform = CFrame.Angles(math.rad(ee[1]), 0, -math.rad(ee[2]))
		end
		if cintura then
			cintura.Transform = CFrame.Angles(math.rad(incl), math.rad(giro), 0)
		end
	else
		local torso = personagem:FindFirstChild("Torso")
		local od = motor(torso, "Right Shoulder")
		local oe = motor(torso, "Left Shoulder")
		if od then
			od.Transform = CFrame.Angles(math.rad(-dd[2]), 0, math.rad(dd[1]))
		end
		if oe then
			oe.Transform = CFrame.Angles(math.rad(-ee[2]), 0, -math.rad(ee[1]))
		end
		local raiz = personagem:FindFirstChild("HumanoidRootPart")
		local rj = motor(raiz, "RootJoint")
		if rj then
			rj.Transform = CFrame.Angles(math.rad(-incl), 0, math.rad(giro))
		end
	end
end

local BRACO_R15 = {
	direito = { "RightUpperArm", "RightLowerArm", "RightHand" },
	esquerdo = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
}
local BRACO_R6 = { direito = { "Right Arm" }, esquerdo = { "Left Arm" } }

-- Toca uma pose no personagem de userId. esconder: "direito" | "esquerdo" | "ambos" (Gear 5)
function Poses.tocar(userId: number?, nome: string, duracao: number, esconder: string?)
	local jogador = userId and Players:GetPlayerByUserId(userId)
	local personagem = jogador and jogador.Character
	local chaves = Poses.BIBLIOTECA[nome]
	if not personagem or not chaves then
		return
	end
	mostrar(personagem)
	local lista: { string }? = nil
	if esconder then
		local mapa = if personagem:FindFirstChild("UpperTorso") then BRACO_R15 else BRACO_R6
		lista = {}
		for _, lado in
			(if esconder == "ambos" then { "direito", "esquerdo" } else { esconder }) :: { string }
		do
			for _, n in mapa[lado] do
				table.insert(lista :: { string }, n)
			end
		end
	end
	ativas[personagem] =
		{ chaves = chaves, inicio = os.clock(), duracao = duracao, esconder = lista }
end

-- Pose mantida (guarda): liga e desliga
function Poses.manter(userId: number?, nome: string, ligada: boolean)
	local jogador = userId and Players:GetPlayerByUserId(userId)
	local personagem = jogador and jogador.Character
	if not personagem then
		return
	end
	local a = ativas[personagem]
	if ligada then
		ativas[personagem] =
			{ chaves = Poses.BIBLIOTECA[nome], inicio = os.clock(), duracao = 1, manter = true }
	elseif a and a.manter then
		ativas[personagem] = nil
	end
end

-- Outras animacoes (idle anime) nao devem disputar as juntas com golpes/guarda.
function Poses.ocupada(personagem: Model): boolean
	local a = ativas[personagem]
	return a ~= nil and (a.manter == true or os.clock() - a.inicio < a.duracao)
end

function Poses.limpar()
	for personagem in ativas do
		mostrar(personagem)
	end
	table.clear(ativas)
end

function Poses.iniciar()
	-- PreSimulation: depois que o Animator escreveu o quadro, antes da física
	RunService.PreSimulation:Connect(function()
		local agora = os.clock()
		for personagem, a in ativas do
			if not personagem.Parent then
				ativas[personagem] = nil
				escondidas[personagem] = nil
				continue
			end
			local t = if a.manter then 0.5 else (agora - a.inicio) / a.duracao
			if t >= 1 then
				ativas[personagem] = nil
				mostrar(personagem)
				continue
			end
			local d, e, giro, incl = amostra(a.chaves, t)
			aplicar(personagem, d, e, giro, incl)
			if a.esconder and not escondidas[personagem] then
				local partes = {}
				for _, n in a.esconder do
					local p = personagem:FindFirstChild(n)
					if p and p:IsA("BasePart") then
						p.LocalTransparencyModifier = 1
						table.insert(partes, p)
					end
				end
				escondidas[personagem] = partes
			end
		end
	end)
end

return Poses
