-- Ecos no mundo (só visual): os Ecos equipados de cada jogador seguem o dono, voando ou
-- andando, com as asas batendo; os prismáticos brilham em arco-íris. Os seis Núcleos orbitam o
-- Cristal do Nexo, onde são despertados. Também monta modelos para as telas (ViewportFrame).
-- Os modelos vêm do Blender (assets/pets) no mesmo formato do kit do Nexo (Nexo3D/Malha).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Dados = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados")
local Visual = require(Dados:WaitForChild("PetsVisual"))
local Malha = require(script.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))

local Ecos = {}

export type Preferencias = { qualidadeBaixa: boolean, movimentoReduzido: boolean }
local prefs: Preferencias = { qualidadeBaixa = false, movimentoReduzido = false }

function Ecos.definir(novas: Preferencias)
	prefs = novas
end

type Peca = { parte: MeshPart, centro: Vector3, junta: Vector3?, bater: number?, lado: number }
export type Modelo = { modelo: Model, pecas: { Peca }, voa: boolean, altura: number, prisma: boolean }

-- Conteúdo das malhas criado uma vez e clonado para cada Eco (nunca destruído)
local prontas: Malha.Cache = {}
local DISTANCIA = 180

local function montar(partes: { { [string]: any } }, nome: string): (Model, { Peca })
	local modelo = Instance.new("Model")
	modelo.Name = nome
	local pecas: { Peca } = {}
	for _, d in partes do
		local parte, centro = Malha.criar(d.malha, prontas)
		parte.Material = (Enum.Material :: any)[d.material] or Enum.Material.SmoothPlastic
		parte.Transparency = d.transparencia or 0
		parte.CastShadow = d.material ~= "Neon" and d.material ~= "Glass"
		parte.Parent = modelo
		local junta = if d.junta then Vector3.new(d.junta[1], d.junta[2], d.junta[3]) else nil
		table.insert(pecas, {
			parte = parte,
			centro = centro,
			junta = junta,
			bater = d.bater,
			lado = if d.nome == "asa_e" then -1 else 1,
		})
	end
	return modelo, pecas
end

-- Modelo de um Eco (origem no chão). Pode levar alguns quadros na primeira vez.
function Ecos.modelo(eco: string, prisma: boolean?): Modelo?
	local v = (Visual.ecos :: any)[eco]
	if not v then
		return nil
	end
	local ok, modelo, pecas = pcall(montar, v.partes, eco)
	if not ok then
		warn("[Ecos] não deu para montar " .. eco .. ": " .. tostring(modelo))
		return nil
	end
	return {
		modelo = modelo,
		pecas = pecas,
		voa = v.voa,
		altura = v.altura,
		prisma = prisma == true,
	}
end

function Ecos.modeloNucleo(numero: number): Modelo?
	local partes = (Visual.nucleos :: any)[numero]
	if not partes then
		return nil
	end
	local ok, modelo, pecas = pcall(montar, partes, "Nucleo" .. numero)
	if not ok then
		return nil
	end
	return { modelo = modelo, pecas = pecas, voa = true, altura = 2.8, prisma = false }
end

-- Coloca as peças do modelo a partir da base (asas batem com `t`)
function Ecos.posar(m: Modelo, base: CFrame, t: number)
	for _, p in m.pecas do
		if p.junta and p.bater then
			local angulo = math.rad(p.bater) * math.sin(t * 9) * p.lado
			p.parte.CFrame = base
				* CFrame.new(p.junta)
				* CFrame.Angles(0, 0, angulo)
				* CFrame.new(p.centro - p.junta)
		else
			p.parte.CFrame = base * CFrame.new(p.centro)
		end
	end
end

-- Arco-íris dos prismáticos: contorno que muda de cor e faíscas
local function prismatizar(m: Modelo)
	local destaque = Instance.new("Highlight")
	destaque.Name = "Prisma"
	destaque.FillTransparency = 0.85
	destaque.OutlineTransparency = 0.1
	destaque.DepthMode = Enum.HighlightDepthMode.Occluded
	destaque.Parent = m.modelo
	local principal = m.pecas[1] and m.pecas[1].parte
	if principal then
		local faiscas = Instance.new("ParticleEmitter")
		faiscas.Name = "Faiscas"
		faiscas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		faiscas.Rate = 6
		faiscas.Lifetime = NumberRange.new(0.6, 1.1)
		faiscas.Speed = NumberRange.new(0.5, 1.5)
		faiscas.Size = NumberSequence.new(0.35, 0)
		faiscas.LightEmission = 1
		faiscas.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("FF7BB9")),
			ColorSequenceKeypoint.new(0.5, Color3.fromHex("7FD8FF")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("FFE27A")),
		})
		faiscas.Parent = principal
	end
end

-- ===================================================================== Ecos seguindo os donos

type Seguidor = { m: Modelo, pos: Vector3, rumo: Vector3, fase: number }
local seguidores: { [Player]: { texto: string, lista: { Seguidor } } } = {}
local pasta: Folder

local function limpar(jogador: Player)
	local s = seguidores[jogador]
	if s then
		for _, f in s.lista do
			f.m.modelo:Destroy()
		end
	end
	seguidores[jogador] = nil
end

local function ler(jogador: Player)
	local texto = jogador:GetAttribute("Ecos")
	texto = if type(texto) == "string" then texto else ""
	local atual = seguidores[jogador]
	if atual and atual.texto == texto then
		return
	end
	limpar(jogador)
	if texto == "" then
		return
	end
	local lista: { Seguidor } = {}
	seguidores[jogador] = { texto = texto, lista = lista }
	task.spawn(function()
		for item in string.gmatch(texto, "[^;]+") do
			local eco, prisma = string.match(item, "^([%w_]+):([01])$")
			if eco then
				local m = Ecos.modelo(eco, prisma == "1")
				if not m then
					continue
				end
				if seguidores[jogador] == nil or seguidores[jogador].lista ~= lista then
					m.modelo:Destroy()
					return
				end
				if m.prisma and not prefs.qualidadeBaixa then
					prismatizar(m)
				end
				m.modelo.Parent = pasta
				table.insert(lista, {
					m = m,
					pos = Vector3.zero,
					rumo = Vector3.new(0, 0, -1),
					fase = math.random() * 10,
				})
			end
		end
	end)
end

local function acompanhar(jogador: Player)
	jogador:GetAttributeChangedSignal("Ecos"):Connect(function()
		ler(jogador)
	end)
	ler(jogador)
end

local function atualizarSeguidores(dt: number, t: number)
	local camera = Workspace.CurrentCamera
	local olho = if camera then camera.CFrame.Position else Vector3.zero
	for jogador, s in seguidores do
		local personagem = jogador.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		local longe = not raiz or (raiz.Position - olho).Magnitude > DISTANCIA
		for _, f in s.lista do
			f.m.modelo.Parent = if longe then nil else pasta
		end
		if longe or not raiz or not humanoide then
			continue
		end
		local n = #s.lista
		local pe = raiz.Position.Y - humanoide.HipHeight - raiz.Size.Y / 2
		local velocidade =
			Vector3.new(raiz.AssemblyLinearVelocity.X, 0, raiz.AssemblyLinearVelocity.Z)
		local andando = velocidade.Magnitude > 2
		for k, f in s.lista do
			-- em leque atrás do dono
			local x = (k - (n + 1) / 2) * 3.4
			local alvo = (raiz.CFrame * CFrame.new(x, 0, 4.2 + math.abs(x) * 0.25)).Position
			if f.pos == Vector3.zero or (f.pos - alvo).Magnitude > 40 then
				f.pos = alvo
			end
			f.pos = f.pos:Lerp(alvo, 1 - math.exp(-dt * 7))
			if andando then
				f.rumo = f.rumo:Lerp(velocidade.Unit, 1 - math.exp(-dt * 6))
			else
				local olhar = Vector3.new(raiz.CFrame.LookVector.X, 0, raiz.CFrame.LookVector.Z)
				f.rumo = f.rumo:Lerp(olhar, 1 - math.exp(-dt * 3))
			end
			local reduzido = prefs.movimentoReduzido
			local altura = pe
			if f.m.voa then
				altura += 2.4 + (if reduzido then 0 else math.sin(t * 2 + f.fase) * 0.35)
			elseif andando and not reduzido then
				altura += math.abs(math.sin(t * 9 + f.fase)) * 0.45
			end
			local base = CFrame.lookAt(
				Vector3.new(f.pos.X, altura, f.pos.Z),
				Vector3.new(f.pos.X, altura, f.pos.Z)
					+ (if f.rumo.Magnitude > 0.01 then f.rumo.Unit else Vector3.new(0, 0, -1))
			)
			Ecos.posar(f.m, base, if reduzido then 0 else t + f.fase)
			local destaque = f.m.modelo:FindFirstChild("Prisma") :: Highlight?
			if destaque then
				destaque.OutlineColor = Color3.fromHSV((t * 0.25 + f.fase) % 1, 0.7, 1)
			end
		end
	end
end

-- ===================================================================== Núcleos no Cristal

local NUCLEO_RAIO = 12.5
local NUCLEO_ALTURA = 6.5
local nucleos: { Modelo } = {}
local liberados: { [number]: boolean } = {}

function Ecos.definirLiberados(lista: { [number]: boolean })
	liberados = lista
	for i, m in nucleos do
		for _, p in m.pecas do
			p.parte.LocalTransparencyModifier = if liberados[i] then 0 else 0.55
		end
	end
end

local function atualizarNucleos(t: number)
	for i, m in nucleos do
		-- os seis do Corredor num anel; os exclusivos (7 em diante) num anel menor, mais alto,
		-- girando ao contrário
		local exclusivo = i > 6
		local a = if exclusivo
			then -t * 0.18 + (i - 7) * math.pi * 2 / 3
			else t * 0.12 + (i - 1) * math.pi / 3
		local raio = if exclusivo then NUCLEO_RAIO * 0.62 else NUCLEO_RAIO
		local altura = if exclusivo then NUCLEO_ALTURA + 4.5 else NUCLEO_ALTURA
		local pos = Vector3.new(
			math.cos(a) * raio,
			altura + math.sin(t * 0.8 + i) * 0.4,
			math.sin(a) * raio
		)
		local base = CFrame.new(pos) * CFrame.Angles(0, t * 0.6 + i, 0) * CFrame.new(0, -1.3, 0)
		Ecos.posar(m, base, 0)
	end
end

function Ecos.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "Ecos"
	pasta.Parent = Workspace
	for _, jogador in Players:GetPlayers() do
		acompanhar(jogador)
	end
	Players.PlayerAdded:Connect(acompanhar)
	Players.PlayerRemoving:Connect(limpar)
	task.spawn(function()
		local pastaNucleos = Instance.new("Folder")
		pastaNucleos.Name = "Nucleos"
		for i = 1, #Visual.nucleos do
			local m = Ecos.modeloNucleo(i)
			if m then
				m.modelo.Parent = pastaNucleos
				table.insert(nucleos, m)
			end
		end
		pastaNucleos.Parent = pasta
		Ecos.definirLiberados(liberados)
	end)
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		atualizarSeguidores(dt, t)
		local camera = Workspace.CurrentCamera
		if camera and camera.CFrame.Position.Magnitude < 160 then
			atualizarNucleos(if prefs.movimentoReduzido then 0 else t)
		end
	end)
end

return Ecos
