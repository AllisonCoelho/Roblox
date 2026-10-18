-- Modelos 3D dos Docinhos.
-- Os modelos feitos com a IA do Roblox ficam em assets/docinhos/<id>.rbxm (pasta
-- ReplicatedStorage.DocinhosModelos). Enquanto um modelo não existir, usamos um
-- provisório feito de peças, para a interface e o jogo funcionarem desde já.
-- Convenção: a frente do Docinho (o rosto) aponta para o LookVector do pivô do modelo.
-- Se um modelo da IA vier virado, coloque nele o atributo numérico "GiroY" (90, 180, -90).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modelos = {}

Modelos.NOME_PASTA = "DocinhosModelos"

type Peca = {
	forma: "Bola" | "Bloco" | "Cilindro",
	tamanho: Vector3,
	cor: Color3,
	pos: Vector3?,
	material: Enum.Material?,
}

local function c(hex: string): Color3
	return Color3.fromHex(hex)
end

local FORMINHA_Y = -0.9

local PROVISORIOS: { [string]: { Peca } } = {
	balaDeCoco = {
		{ forma = "Bloco", tamanho = Vector3.new(2.2, 1.7, 1.7), cor = c("FFFFFF") },
		{
			forma = "Bloco",
			tamanho = Vector3.new(0.6, 1.2, 1.2),
			cor = c("FFD6EC"),
			pos = Vector3.new(-1.4, 0, 0),
		},
		{
			forma = "Bloco",
			tamanho = Vector3.new(0.6, 1.2, 1.2),
			cor = c("FFD6EC"),
			pos = Vector3.new(1.4, 0, 0),
		},
	},
	beijinho = {
		{ forma = "Bola", tamanho = Vector3.new(2, 2, 2), cor = c("FFFAF2") },
		{
			forma = "Cilindro",
			tamanho = Vector3.new(0.8, 1.9, 1.9),
			cor = c("4CC9F0"),
			pos = Vector3.new(0, FORMINHA_Y, 0),
		},
		{
			forma = "Bola",
			tamanho = Vector3.new(0.35, 0.35, 0.35),
			cor = c("7A4A2A"),
			pos = Vector3.new(0, 1.1, 0),
		},
	},
	pacoca = {
		{
			forma = "Bloco",
			tamanho = Vector3.new(2, 2, 2),
			cor = c("E8C48A"),
			material = Enum.Material.Sand,
		},
		{
			forma = "Bloco",
			tamanho = Vector3.new(2.1, 0.35, 2.1),
			cor = c("FF3B3B"),
			pos = Vector3.new(0, 0.55, 0),
		},
	},
	peDeMoleque = {
		{ forma = "Bloco", tamanho = Vector3.new(2.4, 1.6, 1.5), cor = c("C97A2B") },
		{
			forma = "Bloco",
			tamanho = Vector3.new(2.8, 0.2, 1.1),
			cor = c("8B5CF6"),
			pos = Vector3.new(0, -1, 0),
		},
	},
	cocada = {
		{
			forma = "Bola",
			tamanho = Vector3.new(2.3, 1.6, 2.3),
			cor = c("FFF3DC"),
			material = Enum.Material.Sand,
		},
	},
	quindim = {
		{
			forma = "Bola",
			tamanho = Vector3.new(2, 2.1, 2),
			cor = c("FFD23D"),
			material = Enum.Material.Glass,
		},
		{
			forma = "Cilindro",
			tamanho = Vector3.new(0.4, 2.3, 2.3),
			cor = c("E0A800"),
			pos = Vector3.new(0, -0.95, 0),
		},
	},
	brigadeiro = {
		{
			forma = "Bola",
			tamanho = Vector3.new(2, 2, 2),
			cor = c("6B3A22"),
			material = Enum.Material.Sand,
		},
		{
			forma = "Cilindro",
			tamanho = Vector3.new(0.8, 1.9, 1.9),
			cor = c("FF5FA2"),
			pos = Vector3.new(0, FORMINHA_Y, 0),
		},
		{
			forma = "Bloco",
			tamanho = Vector3.new(1.7, 0.3, 0.3),
			cor = c("4CC9F0"),
			pos = Vector3.new(0, 0.7, -0.75),
		},
	},
	pudim = {
		{ forma = "Cilindro", tamanho = Vector3.new(1.8, 2, 2), cor = c("FFE6A8") },
		{
			forma = "Cilindro",
			tamanho = Vector3.new(0.4, 2.05, 2.05),
			cor = c("A8561C"),
			pos = Vector3.new(0, 0.8, 0),
		},
		{
			forma = "Bola",
			tamanho = Vector3.new(3.4, 3.4, 3.4),
			cor = c("BDE9FF"),
			material = Enum.Material.ForceField,
		},
	},
	boloDeRolo = {
		{ forma = "Bloco", tamanho = Vector3.new(2.2, 2, 1.6), cor = c("F6D7A7") },
		{
			forma = "Bloco",
			tamanho = Vector3.new(2.25, 0.15, 1.65),
			cor = c("C0392B"),
			pos = Vector3.new(0, 0.6, 0),
		},
		{
			forma = "Bloco",
			tamanho = Vector3.new(2.25, 0.15, 1.65),
			cor = c("C0392B"),
			pos = Vector3.new(0, -0.6, 0),
		},
		{
			forma = "Bloco",
			tamanho = Vector3.new(1.4, 0.9, 1.4),
			cor = c("8B5CF6"),
			pos = Vector3.new(0, 1.45, 0),
		},
	},
	coxinha = {
		{ forma = "Bola", tamanho = Vector3.new(1.9, 2.5, 1.9), cor = c("1A1026") },
		{
			forma = "Bola",
			tamanho = Vector3.new(0.9, 1.1, 0.9),
			cor = c("1A1026"),
			pos = Vector3.new(0, 1.3, 0),
		},
	},
}

local function criarPeca(p: Peca, pai: Instance): Part
	local parte = Instance.new("Part")
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.CastShadow = false
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Material = p.material or Enum.Material.SmoothPlastic
	parte.Color = p.cor
	parte.Size = p.tamanho
	if p.forma == "Bola" then
		-- SpecialMesh permite bolas achatadas (Shape = Ball só aceita bola perfeita)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = parte
	elseif p.forma == "Cilindro" then
		-- Cilindro do Roblox fica deitado no eixo X; giramos para ficar em pé
		parte.Shape = Enum.PartType.Cylinder
	end
	local cf = CFrame.new(p.pos or Vector3.zero)
	if p.forma == "Cilindro" then
		cf *= CFrame.Angles(0, 0, math.rad(90))
	end
	parte.CFrame = cf
	parte.Parent = pai
	return parte
end

local function olho(pai: Instance, x: number, y: number, z: number, cor: Color3)
	criarPeca({
		forma = "Bola",
		tamanho = Vector3.new(0.28, 0.38, 0.12),
		cor = cor,
		pos = Vector3.new(x, y, z),
	}, pai)
end

local function provisorio(id: string): Model
	local modelo = Instance.new("Model")
	modelo.Name = id
	local pecas = PROVISORIOS[id] or PROVISORIOS.balaDeCoco
	local corpo = pecas[1]
	for _, p in pecas do
		criarPeca(p, modelo)
	end
	-- Rosto na frente (-Z, o LookVector padrão)
	local frente = -corpo.tamanho.Z / 2 - 0.02
	local corOlho = if id == "coxinha" then Color3.fromHex("FFF6A8") else Color3.fromHex("2B1B3D")
	olho(modelo, -0.35, 0.15, frente, corOlho)
	olho(modelo, 0.35, 0.15, frente, corOlho)
	modelo.WorldPivot = CFrame.new()
	return modelo
end

-- Devolve uma cópia nova do modelo do Docinho (o oficial, ou o provisório)
function Modelos.criar(id: string): Model
	local pasta = ReplicatedStorage:FindFirstChild(Modelos.NOME_PASTA)
	local oficial = pasta and pasta:FindFirstChild(id)
	if oficial and oficial:IsA("Model") then
		return oficial:Clone()
	end
	return provisorio(id)
end

-- Direção para onde o rosto do Docinho olha (considera o atributo GiroY)
function Modelos.frente(modelo: Model): Vector3
	local giro = modelo:GetAttribute("GiroY")
	local pivo = modelo:GetPivot()
	if type(giro) == "number" then
		pivo *= CFrame.Angles(0, math.rad(giro), 0)
	end
	return pivo.LookVector
end

function Modelos.temOficial(id: string): boolean
	local pasta = ReplicatedStorage:FindFirstChild(Modelos.NOME_PASTA)
	local oficial = pasta and pasta:FindFirstChild(id)
	return oficial ~= nil and oficial:IsA("Model")
end

return Modelos
