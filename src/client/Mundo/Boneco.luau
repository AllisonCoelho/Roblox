-- Monta e anima os NPCs no estilo boneco do Roblox (dados e poses em Shared/Dados/Bonecos).
-- Corpo de Parts comuns (tronco 2×2×1, braços e pernas 1×2×1), cabeça arredondada e cabelo do
-- Blender (Nexo3D/Malha), rosto de discos e blocos (funciona também dentro de ViewportFrame) e
-- acessórios de Parts. Tudo ancorado e só no cliente: a cada quadro `posicionar` recebe os pés,
-- a pose e o tamanho e coloca cada peça no lugar (como o resto dos visuais do jogo).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bonecos =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("Bonecos"))
local Malha = require(script.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))

local Boneco = {}
Boneco.__index = Boneco

type Grupo = "pernaD" | "pernaE" | "tronco" | "bracoD" | "bracoE" | "cabeca"

type Peca = {
	parte: BasePart,
	grupo: string,
	local_: CFrame, -- relativo à junta do grupo (escala 1; a posição é escalada)
	tamanho: Vector3,
	pivo: Vector3?, -- peças que giram (auréola, estrela) giram em volta deste ponto
	gira: string?, -- "z" ou "y"
	papel: string?, -- "olho", "boca", "membro" (braços esticam)
	transparenciaBase: number,
}

export type Opcoes = {
	escala: number?, -- multiplica a escala da definição
	alpha: number?, -- 0 visível, 1 invisível
	piscando: boolean?,
	falando: boolean?,
	giro: number?, -- ângulo das peças que giram
}

local function cor(h: string): Color3
	return Color3.fromHex(h)
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function novaParte(forma: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	if forma then
		p.Shape = forma
	end
	return p
end

-- frente = -Z; a cara fica em z = -0.61 do centro da cabeça
local FRENTE = -0.615
local DISCO = CFrame.Angles(0, math.rad(90), 0) -- cilindro com a face circular para a frente

function Boneco:_peca(
	grupo: string,
	parte: BasePart,
	local_: CFrame,
	extra: { pivo: Vector3?, gira: string?, papel: string? }?
)
	parte.Parent = self.modelo
	table.insert(self.pecas, {
		parte = parte,
		grupo = grupo,
		local_ = local_,
		tamanho = parte.Size,
		pivo = extra and extra.pivo,
		gira = extra and extra.gira,
		papel = extra and extra.papel,
		transparenciaBase = parte.Transparency,
	})
end

function Boneco:_disco(x: number, y: number, d: number, c: Color3, z: number, papel: string?)
	local p = novaParte(Enum.PartType.Cylinder)
	p.Size = Vector3.new(0.04, d, d)
	p.Color = c
	p.CastShadow = false
	self:_peca("cabeca", p, CFrame.new(x, y, FRENTE + z) * DISCO, { papel = papel })
end

function Boneco:_bloco(
	grupo: string,
	tamanho: Vector3,
	c: Color3,
	local_: CFrame,
	extra: any?,
	material: Enum.Material?
)
	local p = novaParte(nil, material)
	p.Size = tamanho
	p.Color = c
	if material == Enum.Material.Neon then
		p.CastShadow = false
	end
	self:_peca(grupo, p, local_, extra)
	return p
end

function Boneco:_bola(grupo: string, d: number, c: Color3, pos: Vector3)
	local p = novaParte(Enum.PartType.Ball)
	p.Size = Vector3.one * d
	p.Color = c
	self:_peca(grupo, p, CFrame.new(pos))
end

function Boneco:_rosto()
	local r = self.def.rosto
	local escuro = cor("2A1A10")
	local olhos = cor(r.corOlhos or "2A1A10")
	for _, lado in { -1, 1 } do
		if r.olhos == "aneis" then
			self:_disco(lado * 0.25, 0.1, 0.44, olhos, 0.005, "olho")
			self:_disco(lado * 0.25, 0.1, 0.32, Color3.new(1, 1, 1), 0, "olho")
			self:_disco(lado * 0.25, 0.1, 0.16, escuro, -0.005, "olho")
		else
			self:_disco(lado * 0.24, 0.0, 0.3, escuro, 0.004, "olho")
			self:_disco(lado * 0.24, 0.08, 0.26, olhos, 0, "olho")
		end
		self:_disco(lado * 0.24 + 0.05, 0.16, 0.08, Color3.new(1, 1, 1), -0.01, "olho")
		if r.bochechas then
			self:_disco(lado * 0.42, -0.15, 0.16, cor("FF9E9E"), 0)
		end
	end
	local function boca(tamanho: Vector3, c: Color3, y: number, z: number, papel: string?)
		local p = self:_bloco("cabeca", tamanho, c, CFrame.new(0, y, FRENTE + z), { papel = papel })
		p.CastShadow = false
	end
	if r.boca == "sorrisao" then
		boca(Vector3.new(0.52, 0.24, 0.04), cor("6A1E1E"), -0.24, 0, "boca")
		boca(Vector3.new(0.48, 0.07, 0.04), Color3.new(1, 1, 1), -0.15, -0.006)
		boca(Vector3.new(0.26, 0.07, 0.04), cor("FF7A8A"), -0.32, -0.006)
	elseif r.boca == "aberta" then
		boca(Vector3.new(0.3, 0.2, 0.04), cor("6A1E1E"), -0.24, 0, "boca")
	else
		boca(Vector3.new(0.3, 0.06, 0.04), cor("6A1E1E"), -0.24, 0, "boca")
	end
end

function Boneco:_acessorio(a: Bonecos.Acessorio, prontas: Malha.Cache)
	if a.malha then
		local ok, parte, centro = pcall(Malha.criar, a.malha, prontas)
		if ok then
			parte.Material = (Enum.Material :: any)[a.material or "SmoothPlastic"]
				or Enum.Material.SmoothPlastic
			self:_peca("cabeca", parte, CFrame.new(centro))
		else
			warn("[Boneco] " .. tostring(a.malha) .. ": " .. tostring(parte))
		end
		return
	end
	local c = cor(a.cor or "FFFFFF")
	if a.peca == "faixa" then
		-- faixa na cintura (relativa à junta da cintura, y = 2)
		self:_bloco("tronco", Vector3.new(2.08, 0.36, 1.08), c, CFrame.new(0, 0.18, 0))
		self:_bola("tronco", 0.32, c, Vector3.new(0.55, 0.18, -0.56))
		self:_bloco(
			"tronco",
			Vector3.new(0.18, 0.7, 0.06),
			c,
			CFrame.new(0.68, -0.25, -0.56) * CFrame.Angles(0, 0, math.rad(-12))
		)
	elseif a.peca == "gola" then
		-- gola de nuvem em volta do pescoço
		for k = 0, 4 do
			local ang = math.rad(-60 + k * 30)
			self:_bola(
				"tronco",
				0.64,
				c,
				Vector3.new(math.sin(ang) * 0.75, 2.0, -(math.cos(ang) * 0.2 - 0.1))
			)
		end
	elseif a.peca == "aureola" then
		-- disco de sol atrás da cabeça, com raios; gira devagar
		local pivo = Vector3.new(0, 0, 0.7)
		local disco = novaParte(Enum.PartType.Cylinder, Enum.Material.Neon)
		disco.Size = Vector3.new(0.08, 2.6, 2.6)
		disco.Color = c
		disco.CastShadow = false
		self:_peca("cabeca", disco, DISCO, { pivo = pivo, gira = "z" })
		for k = 0, 11 do
			local r = math.rad(k * 30)
			self:_bloco(
				"cabeca",
				Vector3.new(0.22, 0.5, 0.06),
				c,
				CFrame.new(math.cos(r) * 1.5, math.sin(r) * 1.5, 0)
					* CFrame.Angles(0, 0, r - math.pi / 2),
				{ pivo = pivo, gira = "z" },
				Enum.Material.Neon
			)
		end
	elseif a.peca == "capa" then
		self:_bloco("tronco", Vector3.new(2.1, 2.6, 0.12), c, CFrame.new(0, 0.6, 0.58))
	elseif a.peca == "estrela" then
		local pivo = Vector3.new(0, 1.15, 0)
		self:_bloco(
			"cabeca",
			Vector3.new(0.4, 0.4, 0.08),
			c,
			CFrame.Angles(0, 0, math.rad(45)),
			{ pivo = pivo, gira = "y" },
			Enum.Material.Neon
		)
		self:_bloco(
			"cabeca",
			Vector3.new(0.56, 0.12, 0.06),
			c,
			CFrame.identity,
			{ pivo = pivo, gira = "y" },
			Enum.Material.Neon
		)
		self:_bloco(
			"cabeca",
			Vector3.new(0.12, 0.56, 0.06),
			c,
			CFrame.identity,
			{ pivo = pivo, gira = "y" },
			Enum.Material.Neon
		)
	end
end

-- Cria o boneco `id` (Bonecos.NPCS) dentro de `pai`. Pode esperar: as malhas convertem em fila.
function Boneco.criar(id: string, pai: Instance, prontas: Malha.Cache?): any
	local def = Bonecos.NPCS[id]
	assert(def, "Boneco desconhecido: " .. tostring(id))
	local self = setmetatable({}, Boneco)
	self.def = def
	self.pecas = {} :: { Peca }
	self.modelo = Instance.new("Model")
	self.modelo.Name = "Boneco_" .. id
	local cache = prontas or {}
	local cores = { pele = cor(def.pele), camisa = cor(def.camisa), calca = cor(def.calca) }
	for _, m in Bonecos.MEMBROS do
		local p = novaParte()
		p.Size = v3(m.tamanho)
		p.Color = cores[m.cor]
		self:_peca(m.nome, p, CFrame.new(v3(m.centro)), {
			papel = if m.nome == "bracoD" or m.nome == "bracoE" then "membro" else nil,
		})
	end
	-- cabeça: malha arredondada do Blender; se não der, um bloco (a cara continua igual)
	local nomeCabeca = "boneco_cabeca_" .. id
	local ok, cabeca, centro = pcall(Malha.criar, nomeCabeca, cache)
	if ok then
		cabeca.Material = Enum.Material.SmoothPlastic
		self:_peca("cabeca", cabeca, CFrame.new(centro))
	else
		local bloco = novaParte()
		bloco.Size = Vector3.one * Bonecos.CABECA.tamanho
		bloco.Color = cores.pele
		self:_peca("cabeca", bloco, CFrame.identity)
	end
	self:_rosto()
	for _, a in def.acessorios do
		self:_acessorio(a, cache)
	end
	self.modelo.Parent = pai
	return self
end

local ROT = function(t: { number }): CFrame
	return CFrame.Angles(t[1], t[2], t[3])
end

-- Coloca as peças: `pes` = CFrame no chão entre os pés (olhando para a frente do NPC)
function Boneco:posicionar(pes: CFrame, pose: Bonecos.Pose, op: Opcoes?)
	local o = op or {}
	local e = self.def.escala * (o.escala or 1)
	local a = pose.achata
	local S = Vector3.new(1 + a, 1 - a, 1 + a) * e
	local function esc(v: Vector3): Vector3
		return v * S
	end
	local raiz = pes * CFrame.new(0, pose.altura * e, 0)
	local cintura = v3(Bonecos.MEMBROS[3].junta)
	local torso = raiz * CFrame.new(esc(cintura)) * ROT(pose.tronco)
	local grupos: { [string]: CFrame } = { tronco = torso }
	for _, m in Bonecos.MEMBROS do
		if m.nome == "pernaD" or m.nome == "pernaE" then
			grupos[m.nome] = raiz * CFrame.new(esc(v3(m.junta))) * ROT((pose :: any)[m.nome])
		elseif m.nome ~= "tronco" then
			grupos[m.nome] = torso
				* CFrame.new(esc(v3(m.junta) - cintura))
				* ROT((pose :: any)[m.nome])
		end
	end
	grupos.cabeca = torso
		* CFrame.new(esc(v3(Bonecos.CABECA.junta) - cintura))
		* ROT(pose.pescoco)
		* CFrame.new(esc(v3(Bonecos.CABECA.centro)))
	local alpha = o.alpha or 0
	local giro = o.giro or 0
	local estica = pose.esticaBracos
	for _, p in self.pecas do
		local base = grupos[p.grupo]
		local tamanho = p.tamanho * S
		local local_ = p.local_
		if p.papel == "membro" and estica ~= 1 then
			tamanho = Vector3.new(tamanho.X, tamanho.Y * estica, tamanho.Z)
			local_ = CFrame.new(local_.Position * Vector3.new(1, estica, 1)) * local_.Rotation
		elseif p.papel == "olho" and o.piscando then
			tamanho = Vector3.new(tamanho.X, tamanho.Y * 0.15, tamanho.Z)
		elseif p.papel == "boca" and o.falando then
			tamanho = Vector3.new(tamanho.X, tamanho.Y * 2.2, tamanho.Z)
		end
		local cf: CFrame
		if p.pivo then
			local giroCf = if p.gira == "y"
				then CFrame.Angles(0, giro * 2, 0)
				else CFrame.Angles(0, 0, giro)
			local flutua = if p.gira == "y" then math.sin(giro * 3) * 0.08 else 0
			cf = base
				* CFrame.new(esc(p.pivo + Vector3.new(0, flutua, 0)))
				* giroCf
				* CFrame.new(esc(local_.Position))
				* local_.Rotation
		else
			cf = base * CFrame.new(esc(local_.Position)) * local_.Rotation
		end
		if (p.parte.Size - tamanho).Magnitude > 0.001 then
			p.parte.Size = tamanho
		end
		p.parte.CFrame = cf
		p.parte.LocalTransparencyModifier = alpha
	end
end

function Boneco:esconder()
	for _, p in self.pecas do
		p.parte.LocalTransparencyModifier = 1
	end
end

function Boneco:destruir()
	self.modelo:Destroy()
end

return Boneco
