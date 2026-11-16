-- Monta um andar de Incursão num "espaço" reservado longe do Nexo (cada grupo tem o seu).
-- O servidor cria o chão, a parede invisível e caixas com as medidas de cada peça do kit
-- (Shared/Dados/IncursoesKit.luau): elas colidem e servem de reserva visual; cada cliente põe a
-- malha 3D por cima (Mundo/Incursoes/Visual). Disposição sorteada no servidor (Random.new).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Incursoes = require(Shared.Dados.Incursoes)
local Kit = require(Shared.Dados.IncursoesKit)

local Mapa = {}

local RAIO = Kit.raioAndar
local TOPO = 0.35 -- altura das lajes do kit: é onde se pisa

export type Andar = {
	pasta: Folder,
	origem: CFrame, -- centro do andar, no topo do chão
	spawn: CFrame,
	saida: CFrame, -- onde a fenda abre
	nucleos: { BasePart },
	pontosSombra: { Vector3 },
	centroGuardiao: Vector3,
	raio: number,
}

local CORES_PEDRA = {
	cinzas = Color3.fromHex("3D2723"),
	mare = Color3.fromHex("2C3B47"),
	umbral = Color3.fromHex("2F2540"),
}

-- Cria a caixa de uma peça do kit com o pé em `pivo`
function Mapa.peca(pai: Instance, nome: string, pivo: CFrame, escala: number, cor: Color3?): Part
	local d = Kit.pecas[nome]
	assert(d, "peça desconhecida: " .. nome)
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(d.tamanho[1], d.tamanho[2], d.tamanho[3]) * escala
	p.CFrame = pivo * CFrame.new(Vector3.new(d.centro[1], d.centro[2], d.centro[3]) * escala)
	p.CanCollide = d.colide
	p.CanQuery = d.colide
	p.CanTouch = false
	p.Material = (Enum.Material :: any)[d.material] or Enum.Material.Slate
	p.Color = cor or Color3.fromHex("3A3546")
	p:SetAttribute("Kit", nome)
	p:SetAttribute("Escala", escala)
	p.Parent = pai
	return p
end

local function parede(pai: Instance, origem: CFrame)
	local n = 28
	for i = 1, n do
		local a = 2 * math.pi * i / n
		local d = Vector3.new(math.sin(a), 0, math.cos(a))
		local p = Instance.new("Part")
		p.Name = "Limite"
		p.Anchored = true
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(2 * math.pi * (RAIO + 2) / n + 2, 60, 2)
		p.CFrame = CFrame.lookAt(
			origem.Position + d * (RAIO + 2) + Vector3.new(0, 26, 0),
			origem.Position + Vector3.new(0, 26, 0)
		)
		p.Parent = pai
	end
end

-- Monta o andar `n` do universo em `origem` (centro, no chão). seed: sorteio da disposição.
function Mapa.construir(
	pai: Instance,
	universo: string,
	n: number,
	origem: CFrame,
	seed: number
): Andar
	local u = Incursoes.porId[universo]
	local rng = Random.new(seed)
	local pasta = Instance.new("Folder")
	pasta.Name = string.format("Andar%d", n)
	local corPedra = CORES_PEDRA[universo] or Color3.fromHex("3A3546")
	local corVeio = Color3.fromHex(u.corVeio)

	-- chão que colide (o kit do piso é só visual)
	local chao = Instance.new("Part")
	chao.Name = "Chao"
	chao.Anchored = true
	chao.Shape = Enum.PartType.Cylinder
	chao.Size = Vector3.new(4, RAIO * 2 + 2, RAIO * 2 + 2)
	chao.CFrame = origem * CFrame.new(0, TOPO - 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	chao.Material = Enum.Material.Slate
	chao.Color = corPedra
	chao.Parent = pasta
	local piso = Mapa.peca(pasta, "inc_" .. universo .. "_piso", origem, 1, corPedra)
	piso:SetAttribute("CorLuz", corVeio)
	parede(pasta, origem)

	local spawn = origem * CFrame.new(0, TOPO + 3, RAIO - 12) * CFrame.Angles(0, 0, 0)
	spawn = CFrame.lookAt(spawn.Position, origem.Position + Vector3.new(0, TOPO + 3, 0))
	local saida = origem * CFrame.new(0, TOPO, -(RAIO - 14))

	-- Núcleos num anel, com folga entre eles
	local cfg = Incursoes.andar(universo, n, 1)
	local nucleos: { BasePart } = {}
	local ocupados: { Vector3 } = { spawn.Position, saida.Position }
	local giroBase = rng:NextNumber(0, math.pi * 2)
	for k = 1, cfg.nucleos do
		local a = giroBase + 2 * math.pi * (k - 1) / cfg.nucleos + rng:NextNumber(-0.25, 0.25)
		local r = rng:NextNumber(20, 34)
		local pivo = origem * CFrame.new(math.sin(a) * r, TOPO, math.cos(a) * r)
		local base = Mapa.peca(pasta, "inc_" .. universo .. "_nucleo", pivo, 1, corPedra)
		base:SetAttribute("Nucleo", true)
		base:SetAttribute("Progresso", 0)
		base:SetAttribute("CorLuz", Color3.fromHex(u.cor))
		table.insert(nucleos, base)
		table.insert(ocupados, pivo.Position)
	end

	-- Ruínas: longe do spawn, da saída e dos núcleos
	local nomes = { "pilar", "muro", "rocha", "pilar", "rocha" }
	local colocadas, tentativas = 0, 0
	while colocadas < 13 and tentativas < 300 do
		tentativas += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(14, RAIO - 8)
		local p = origem * CFrame.new(math.sin(a) * r, TOPO, math.cos(a) * r)
		local longe = true
		for _, o in ocupados do
			if (o - p.Position).Magnitude < 13 then
				longe = false
				break
			end
		end
		if longe then
			local nome = nomes[rng:NextInteger(1, #nomes)]
			Mapa.peca(
				pasta,
				"inc_" .. universo .. "_" .. nome,
				CFrame.new(p.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				rng:NextNumber(0.85, 1.25),
				corPedra
			)
			table.insert(ocupados, p.Position)
			colocadas += 1
		end
	end

	-- Onde as Sombras nascem: na borda, longe do spawn
	local pontos: { Vector3 } = {}
	for k = 1, 10 do
		local a = 2 * math.pi * k / 10
		local p = (origem * CFrame.new(math.sin(a) * (RAIO - 6), TOPO, math.cos(a) * (RAIO - 6))).Position
		if (p - spawn.Position).Magnitude > 28 then
			table.insert(pontos, p)
		end
	end

	pasta.Parent = pai
	return {
		pasta = pasta,
		origem = origem * CFrame.new(0, TOPO, 0),
		spawn = spawn,
		saida = saida,
		nucleos = nucleos,
		pontosSombra = pontos,
		centroGuardiao = (origem * CFrame.new(0, TOPO, -16)).Position,
		raio = RAIO,
	}
end

return Mapa
