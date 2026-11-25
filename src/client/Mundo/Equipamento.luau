-- Equipamento visível no personagem (só visual). O servidor publica no atributo "Equipamento"
-- de cada Player as peças que estão à mostra; aqui cada cliente monta as peças do kit
-- (Dados/EquipamentoVisual, feitas no Blender) e as prende ao corpo de cada jogador.
--
-- As peças foram modeladas no tamanho de um R15 blocado de referência e são escaladas pela
-- largura da parte do corpo de cada um: funciona em R15 de qualquer escala e em R6. As peças
-- ficam ancoradas e seguem o corpo a cada quadro (sem física nem Weld no personagem alheio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visual = require(Shared:WaitForChild("Dados"):WaitForChild("EquipamentoVisual"))
local EquipamentoDados = require(Shared.Dados:WaitForChild("Equipamento"))
local Malha = require(script.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))

local Equipamento = {}

-- Onde cada peça encaixa: parte do corpo (R15 / R6), largura de referência da parte e o ponto
-- de apoio na parte (fração do tamanho, -0,5 = base). `giro` inclina a peça (arma).
type Encaixe = {
	r15: string,
	r6: string,
	largura: number,
	apoioR15: Vector3,
	apoioR6: Vector3,
	deslocar: Vector3?, -- em studs da referência, depois de escalar
	giro: CFrame?,
}
local ENCAIXES: { [string]: Encaixe } = {
	elmo = {
		r15 = "Head",
		r6 = "Head",
		largura = 1.2,
		apoioR15 = Vector3.zero,
		apoioR6 = Vector3.zero,
	},
	armadura = {
		r15 = "UpperTorso",
		r6 = "Torso",
		largura = 2,
		apoioR15 = Vector3.zero,
		apoioR6 = Vector3.new(0, 0.1, 0),
	},
	manopla_d = {
		r15 = "RightLowerArm",
		r6 = "Right Arm",
		largura = 1,
		apoioR15 = Vector3.zero,
		apoioR6 = Vector3.new(0, -0.22, 0),
	},
	manopla_e = {
		r15 = "LeftLowerArm",
		r6 = "Left Arm",
		largura = 1,
		apoioR15 = Vector3.zero,
		apoioR6 = Vector3.new(0, -0.22, 0),
	},
	bota_d = {
		r15 = "RightFoot",
		r6 = "Right Leg",
		largura = 1,
		apoioR15 = Vector3.new(0, -0.5, 0),
		apoioR6 = Vector3.new(0, -0.5, 0),
	},
	bota_e = {
		r15 = "LeftFoot",
		r6 = "Left Leg",
		largura = 1,
		apoioR15 = Vector3.new(0, -0.5, 0),
		apoioR6 = Vector3.new(0, -0.5, 0),
	},
	arma = {
		r15 = "RightHand",
		r6 = "Right Arm",
		largura = 1,
		apoioR15 = Vector3.zero,
		apoioR6 = Vector3.new(0, -0.45, 0),
		giro = CFrame.Angles(math.rad(35), 0, 0),
	},
}
-- espaço do jogo -> peças do kit
local PECAS = {
	elmo = { "elmo" },
	armadura = { "armadura" },
	manoplas = { "manopla_d", "manopla_e" },
	botas = { "bota_d", "bota_e" },
	arma = { "arma" },
}

type Camada = { parte: MeshPart, centro: Vector3, encaixe: Encaixe }
type Vestido = { texto: string, camadas: { Camada }, personagem: Model? }

local prontas: Malha.Cache = {}
local vestidos: { [Player]: Vestido } = {}
local pasta: Folder
local DISTANCIA = 200

local tamanhoOriginal: { [MeshPart]: Vector3 } = {}

local function limpar(jogador: Player)
	local v = vestidos[jogador]
	if v then
		for _, c in v.camadas do
			tamanhoOriginal[c.parte] = nil
			c.parte:Destroy()
		end
	end
	vestidos[jogador] = nil
end

local function montar(jogador: Player)
	local texto = jogador:GetAttribute("Equipamento")
	texto = if type(texto) == "string" then texto else ""
	local atual = vestidos[jogador]
	if atual and atual.texto == texto then
		return
	end
	limpar(jogador)
	local v: Vestido = { texto = texto, camadas = {}, personagem = nil }
	vestidos[jogador] = v
	for item in string.gmatch(texto, "[^;]+") do
		local espaco, id = string.match(item, "^(%a+):([%w_]+):%d+$")
		local dados = id and EquipamentoDados.porId[id]
		if not espaco or not dados or not PECAS[espaco] then
			continue
		end
		local conjunto = (Visual :: any)[dados.conjunto]
		for _, peca in PECAS[espaco] do
			for _, m in (conjunto and conjunto[peca] or {}) do
				local ok, parte, centro = pcall(Malha.criar, m.malha, prontas)
				if not ok then
					continue
				end
				if vestidos[jogador] ~= v then
					parte:Destroy()
					return
				end
				parte.Material = (Enum.Material :: any)[m.material] or Enum.Material.SmoothPlastic
				parte.CastShadow = m.material ~= "Neon"
				parte.Parent = pasta
				table.insert(
					v.camadas,
					{ parte = parte, centro = centro, encaixe = ENCAIXES[peca] }
				)
			end
		end
	end
end

-- (tamanhoOriginal guarda o tamanho de cada malha antes de escalar)

local function posicionar(jogador: Player, v: Vestido, olho: Vector3)
	local personagem = jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local longe = not raiz
		or not raiz:IsA("BasePart")
		or (raiz.Position - olho).Magnitude > DISTANCIA
	local r15 = personagem ~= nil and personagem:FindFirstChild("UpperTorso") ~= nil
	for _, c in v.camadas do
		local nome = if r15 then c.encaixe.r15 else c.encaixe.r6
		local corpo = personagem and personagem:FindFirstChild(nome)
		if longe or not corpo or not corpo:IsA("BasePart") then
			c.parte.LocalTransparencyModifier = 1
			continue
		end
		local apoio = if r15 then c.encaixe.apoioR15 else c.encaixe.apoioR6
		-- R6: a cabeça é uma caixa 2×1×1, mas a cabeça visível tem ~1,25 de largura
		local largura = if not r15 and nome == "Head" then corpo.Size.Y * 1.2 else corpo.Size.X
		local escala = largura / c.encaixe.largura
		local original = tamanhoOriginal[c.parte]
		if not original then
			original = c.parte.Size
			tamanhoOriginal[c.parte] = original
		end
		local tamanho = original * escala
		if c.parte.Size ~= tamanho then
			c.parte.Size = tamanho
		end
		local base = corpo.CFrame
			* CFrame.new(corpo.Size * apoio)
			* (c.encaixe.giro or CFrame.identity)
		c.parte.CFrame = base * CFrame.new(c.centro * escala)
		c.parte.LocalTransparencyModifier = corpo.LocalTransparencyModifier
	end
end

local function acompanhar(jogador: Player)
	jogador:GetAttributeChangedSignal("Equipamento"):Connect(function()
		task.spawn(montar, jogador)
	end)
	task.spawn(montar, jogador)
end

function Equipamento.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "EquipamentoVisivel"
	pasta.Parent = Workspace
	for _, jogador in Players:GetPlayers() do
		acompanhar(jogador)
	end
	Players.PlayerAdded:Connect(acompanhar)
	Players.PlayerRemoving:Connect(limpar)
	-- depois das animações do quadro: a peça acompanha o membro já animado
	RunService:BindToRenderStep(
		"EquipamentoVisivel",
		Enum.RenderPriority.Character.Value + 2,
		function()
			local camera = Workspace.CurrentCamera
			local olho = if camera then camera.CFrame.Position else Vector3.zero
			for jogador, v in vestidos do
				posicionar(jogador, v, olho)
			end
		end
	)
end

return Equipamento
