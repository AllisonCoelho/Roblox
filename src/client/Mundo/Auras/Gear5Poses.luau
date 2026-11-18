-- Palco do rig em repouso: +X para a direita, +Y para cima, -Z para a frente.
-- As direções braço/antebraço definem primeiro a silhueta e depois a flexão do cotovelo.
type Rotacoes = { [string]: Vector3 }
type Quadro = { [string]: CFrame }

local Poses = {}

local function braco(ombro: Vector3, antebraco: Vector3): (CFrame, CFrame, CFrame)
	local a, b = ombro.Unit, antebraco.Unit
	local y = -a
	local z = -(b - a * a:Dot(b)).Unit
	local rotacao = CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
	local flexao = CFrame.Angles(math.acos(math.clamp(a:Dot(b), -1, 1)), 0, 0)
	-- O R6 tem um braço rígido. A direção da mão continua distinguindo a testa do repouso.
	local r6Y = -(a + b * 0.70).Unit
	local r6X = r6Y:Cross(z).Unit
	local r6 = CFrame.fromMatrix(Vector3.zero, r6X, r6Y, r6X:Cross(r6Y))
	return rotacao, flexao, r6
end

local function quadro(
	angulos: Rotacoes,
	ombroD: Vector3,
	antebracoD: Vector3,
	ombroE: Vector3,
	antebracoE: Vector3
): Quadro
	local pose: Quadro = {}
	for nome, v in angulos do
		pose[nome] = CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
	end
	pose.ombroD, pose.cotoveloD, pose.ombroDR6 = braco(ombroD, antebracoD)
	pose.ombroE, pose.cotoveloE, pose.ombroER6 = braco(ombroE, antebracoE)
	-- O tronco único do R6 carrega também a inclinação da cintura.
	pose.raizR6 = pose.raiz:Lerp(pose.raiz * pose.cintura, 0.72)
	return pose
end

local v = Vector3.new

-- Imagem 1: mão direita na testa, esquerda sobre o abdômen e uma perna mais alta.
Poses.risada = quadro({
	raiz = v(7, -5, -8),
	cintura = v(13, -4, -7),
	pescoco = v(9, 4, 8),
	quadrilD = v(28, -12, 20),
	quadrilE = v(72, 10, -18),
	joelhoD = v(-25, 0, 0),
	joelhoE = v(-18, 0, 0),
	tornozeloD = v(-8, 0, 0),
	tornozeloE = v(15, 0, 0),
}, v(0.82, 0.55, -0.15), v(-0.95, 0.22, -0.42), v(-0.43, -0.83, -0.25), v(0.88, 0.16, -0.42))

-- Imagem 3: mãos atrás da cabeça, cotovelos abertos e tronco reclinado.
Poses.relaxado = quadro({
	raiz = v(15, 7, -13),
	cintura = v(18, 6, -9),
	pescoco = v(-14, -8, 4),
	quadrilD = v(62, -5, 15),
	quadrilE = v(43, 8, -25),
	joelhoD = v(-19, 0, 0),
	joelhoE = v(-14, 0, 0),
	tornozeloD = v(16, 0, 0),
	tornozeloE = v(3, 0, 0),
}, v(0.79, 0.58, 0.12), v(-0.70, 0.40, 0.43), v(-0.82, 0.56, 0.13), v(0.69, 0.42, 0.46))

local contato = quadro({
	raiz = v(-6, -6, 5),
	cintura = v(-12, -15, 6),
	pescoco = v(9, 15, -6),
	quadrilD = v(40, 0, 8),
	quadrilE = v(-31, 0, -8),
	joelhoD = v(-14, 0, 0),
	joelhoE = v(-71, 0, 0),
	tornozeloD = v(11, 0, 0),
	tornozeloE = v(-19, 0, 0),
}, v(0.68, -0.36, 0.51), v(0.22, 0.34, -0.82), v(-0.75, 0.37, -0.51), v(0.10, 0.87, -0.43))

local compressao = quadro({
	raiz = v(-9, -2, 7),
	cintura = v(-15, -7, 6),
	pescoco = v(11, 7, -6),
	quadrilD = v(26, 0, 5),
	quadrilE = v(-8, 0, -6),
	joelhoD = v(-39, 0, 0),
	joelhoE = v(-94, 0, 0),
	tornozeloD = v(13, 0, 0),
	tornozeloE = v(-18, 0, 0),
}, v(0.63, -0.65, 0.36), v(0.39, 0.08, -0.83), v(-0.68, -0.14, -0.61), v(0.15, 0.72, -0.57))

-- Imagem 2: punho da frente alto, outro braço aberto para trás e pernas afastadas no ar.
local voo = quadro({
	raiz = v(-9, 8, -8),
	cintura = v(-16, 16, -7),
	pescoco = v(11, -15, 6),
	quadrilD = v(-38, 0, 9),
	quadrilE = v(58, 0, -11),
	joelhoD = v(-83, 0, 0),
	joelhoE = v(-22, 0, 0),
	tornozeloD = v(-17, 0, 0),
	tornozeloE = v(16, 0, 0),
}, v(0.70, 0.36, -0.60), v(-0.26, 0.93, -0.28), v(-0.83, -0.05, 0.53), v(-0.28, -0.56, -0.58))

local function espelhar(pose: Quadro): Quadro
	local outra: Quadro = {}
	for nome, rotacao in pose do
		local x, y, z = rotacao:ToEulerAnglesXYZ()
		local oposto = nome:gsub("D(R6)$", "E%1"):gsub("D$", "E")
		if oposto == nome then
			oposto = nome:gsub("E(R6)$", "D%1"):gsub("E$", "D")
		end
		outra[oposto] = CFrame.Angles(x, -y, -z)
	end
	return outra
end

local contatoE = espelhar(contato)
Poses.passoD = { contato, compressao, voo, contatoE }
Poses.passoE = { contatoE, espelhar(compressao), espelhar(voo), contato }
Poses.salto = voo

return Poses
