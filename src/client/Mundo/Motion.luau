-- Poses do personagem durante o giro, feitas por código: cada pose é um conjunto de rotações
-- aplicadas por cima da animação normal, deslocando o C0 das juntas (Motor6D) do R15.
-- Nenhum asset de animação é necessário. Avatares R6 não têm estas juntas: ficam sem pose.
--
-- Eixos do R15 (personagem olhando para -Z): girar o ombro em X positivo leva o braço para a
-- frente; em Z positivo leva o braço direito para fora (o esquerdo usa o sinal oposto).
-- CFrame.Angles(x, y, z): o giro em Z acontece primeiro, depois o em X.
local Motion = {}

local function graus(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- Pose = junta -> rotação. Junta ausente = sem mudança.
Motion.Poses = {
	neutra = {},

	-- Raridades comuns: uma mão chama a energia
	gesto = {
		RightShoulder = graus(78, 0, -6),
		RightElbow = graus(12, 0, 0),
		Neck = graus(-6, 0, 0),
		Waist = graus(-3, 0, 0),
	},
	impulso = {
		RightShoulder = graus(35, 0, 38),
		RightElbow = graus(5, 0, 0),
		Neck = graus(8, 0, 0),
	},
	gestoDuplo = {
		RightShoulder = graus(75, 0, -12),
		LeftShoulder = graus(75, 0, 12),
		RightElbow = graus(15, 0, 0),
		LeftElbow = graus(15, 0, 0),
		Neck = graus(-8, 0, 0),
		Waist = graus(-4, 0, 0),
	},
	impulsoDuplo = {
		RightShoulder = graus(30, 0, 42),
		LeftShoulder = graus(30, 0, -42),
		Neck = graus(10, 0, 0),
		Waist = graus(4, 0, 0),
	},

	-- Raridades altas: rasgar a ruptura do mundo
	alcancar = { -- estende as duas mãos até a energia
		RightShoulder = graus(80, 0, -16),
		LeftShoulder = graus(80, 0, 16),
		RightElbow = graus(10, 0, 0),
		LeftElbow = graus(10, 0, 0),
		Neck = graus(-14, 0, 0),
		Waist = graus(-8, 0, 0),
	},
	agarrar = { -- mãos juntas, cotovelos dobrados, corpo inclinado
		RightShoulder = graus(72, 0, -20),
		LeftShoulder = graus(72, 0, 20),
		RightElbow = graus(35, 0, 0),
		LeftElbow = graus(35, 0, 0),
		Neck = graus(-18, 0, 0),
		Waist = graus(-12, 0, 0),
		RightHip = graus(0, 0, 10),
		LeftHip = graus(0, 0, -10),
	},
	forcar = { -- pernas firmes, braços começando a abrir a fresta
		RightShoulder = graus(78, 0, 8),
		LeftShoulder = graus(78, 0, -8),
		RightElbow = graus(25, 0, 0),
		LeftElbow = graus(25, 0, 0),
		Neck = graus(-8, 0, 0),
		Waist = graus(-4, 0, 0),
		RightHip = graus(15, 0, 12),
		LeftHip = graus(-15, 0, -12),
		RightKnee = graus(-15, 0, 0),
		LeftKnee = graus(-10, 0, 0),
	},
	rasgar = { -- braços abertos de uma vez, peito para a frente, cabeça para trás
		RightShoulder = graus(-12, 0, 102),
		LeftShoulder = graus(-12, 0, -102),
		RightElbow = graus(8, 0, 0),
		LeftElbow = graus(8, 0, 0),
		Neck = graus(20, 0, 0),
		Waist = graus(14, 0, 0),
		RightHip = graus(0, 0, 14),
		LeftHip = graus(0, 0, -14),
	},
} :: { [string]: { [string]: CFrame } }

local JUNTAS = {
	"Root",
	"Waist",
	"Neck",
	"RightShoulder",
	"LeftShoulder",
	"RightElbow",
	"LeftElbow",
	"RightHip",
	"LeftHip",
	"RightKnee",
	"LeftKnee",
}
local IDENTIDADE = CFrame.new()
local TREME = { RightShoulder = 1, LeftShoulder = -1, Neck = 0.4 }

export type Controle = {
	-- Mistura duas poses (peso 0 = de, 1 = para), sobe o corpo `altura` studs e treme os braços
	aplicar: (
		de: string,
		para: string,
		peso: number,
		altura: number,
		tremor: number,
		t: number
	) -> (),
	-- Devolve as juntas ao que eram. Sempre chamar ao terminar.
	restaurar: () -> (),
}

function Motion.criar(personagem: Model): Controle
	local juntas: { { nome: string, motor: Motor6D, original: CFrame } } = {}
	for _, nome in JUNTAS do
		local motor = personagem:FindFirstChild(nome, true)
		if motor and motor:IsA("Motor6D") then
			table.insert(juntas, { nome = nome, motor = motor, original = motor.C0 })
		end
	end
	local restaurado = false
	return {
		aplicar = function(
			de: string,
			para: string,
			peso: number,
			altura: number,
			tremor: number,
			t: number
		)
			if restaurado then
				return
			end
			local poseDe = Motion.Poses[de] or Motion.Poses.neutra
			local posePara = Motion.Poses[para] or Motion.Poses.neutra
			for _, j in juntas do
				local a = poseDe[j.nome] or IDENTIDADE
				local b = posePara[j.nome] or IDENTIDADE
				local c = a:Lerp(b, peso)
				local treme = TREME[j.nome]
				if treme and tremor > 0 then
					c *= CFrame.Angles(
						math.sin(t * 52) * tremor * treme,
						0,
						math.sin(t * 37 + 1) * tremor * 0.5
					)
				end
				if j.nome == "Root" then
					c = CFrame.new(0, altura, 0) * c
				end
				j.motor.C0 = j.original * c
			end
		end,
		restaurar = function()
			if restaurado then
				return
			end
			restaurado = true
			for _, j in juntas do
				if j.motor.Parent then
					j.motor.C0 = j.original
				end
			end
		end,
	}
end

return Motion
