-- Criaturas do Corredor no cliente (só visual). O servidor cria uma peça invisível por criatura
-- (workspace.CriaturasCorredor) com atributos; aqui cada uma ganha o modelo blocado e anima:
-- respira, vira para quem chega, ataca, recua quando leva golpe, cai quando morre e volta.
--
-- Modelo: se existir ReplicatedStorage.CorredorModelos.<id> (FBX importado no Studio, ver
-- assets/corredor/criaturas/IMPORTAR_NO_STUDIO.md), usa as MeshParts dele; senão monta pelas
-- malhas do kit (Nexo3D/Malha), que já vêm no repositório.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Visual = require(Shared:WaitForChild("Dados"):WaitForChild("CriaturasVisual"))
local Remotos = require(Shared:WaitForChild("Remotos"))
local Malha = require(script.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))
local AtaquesFx = require(script.Parent:WaitForChild("AtaquesAura"))
local AtaquesAura = require(Shared:WaitForChild("Dados"):WaitForChild("AtaquesAura"))

local Criaturas = {}

export type Preferencias = { qualidadeBaixa: boolean, movimentoReduzido: boolean }
local prefs: Preferencias = { qualidadeBaixa = false, movimentoReduzido = false }

function Criaturas.definir(novas: Preferencias)
	prefs = novas
	AtaquesFx.definir({ movimentoReduzido = novas.movimentoReduzido })
end

type Camada = { parte: BasePart, centro: Vector3, rel: CFrame }
type Peca = {
	nome: string,
	pai: string?,
	junta: Vector3?,
	camadas: { Camada },
	giro: CFrame,
	total: CFrame,
}
type Instancia = {
	parte: BasePart,
	modelo: Model,
	pecas: { Peca },
	porNome: { [string]: Peca },
	altura: number,
	escala: number,
	tipo: string,
	fase: number,
	barra: BillboardGui,
	vida: Frame,
	nascido: number,
	morreu: boolean,
	renascido: number?,
}

local DISTANCIA = 230
local prontas: Malha.Cache = {}
local instancias: { [BasePart]: Instancia } = {}
-- criaturas com o modelo sendo montado agora (a conversão das malhas leva alguns quadros:
-- sem esta marca, cada quadro começava outro modelo e a criatura aparecia duplicada)
local criando: { [BasePart]: boolean } = {}
local pasta: Folder
local meuAlvo: BasePart? = nil

-- ===================================================================== montar

local function montarKit(id: string, visual: any): (Model, { Peca }, number)
	local modelo = Instance.new("Model")
	modelo.Name = id
	local pecas: { Peca } = {}
	for _, p in visual.partes do
		local camadas: { Camada } = {}
		for _, m in p.malhas do
			local parte, centro = Malha.criar(m.malha, prontas)
			parte.Material = (Enum.Material :: any)[m.material] or Enum.Material.SmoothPlastic
			parte.Transparency = m.transparencia or 0
			parte.CastShadow = m.material ~= "Neon"
			parte.Parent = modelo
			table.insert(camadas, { parte = parte, centro = centro, rel = CFrame.identity })
		end
		table.insert(pecas, {
			nome = p.nome,
			pai = p.pai,
			junta = if p.junta then Vector3.new(p.junta[1], p.junta[2], p.junta[3]) else nil,
			camadas = camadas,
			giro = CFrame.identity,
			total = CFrame.identity,
		})
	end
	return modelo, pecas, 1
end

-- Modelo importado: MeshParts com os nomes das peças ("braco_d", "braco_d_brilho"...) e uma
-- peça "Origem" no chão. As posições de repouso saem do próprio modelo.
local function montarImportado(id: string, visual: any, molde: Model): (Model?, { Peca }?, number?)
	local modelo = molde:Clone()
	local origem = modelo:FindFirstChild("Origem", true)
	if not origem or not origem:IsA("BasePart") then
		modelo:Destroy()
		return nil, nil, nil
	end
	local referencia = origem.CFrame * CFrame.new(0, -origem.Size.Y / 2, 0)
	local altura = modelo:GetExtentsSize().Y
	local escala = (tonumber(molde:GetAttribute("Escala")) or 1)
		* altura
		/ math.max(visual.altura, 0.1)
	origem.Transparency = 1
	local pecas: { Peca } = {}
	for _, p in visual.partes do
		local camadas: { Camada } = {}
		for _, sufixo in { "", "_vidro", "_brilho" } do
			local parte = modelo:FindFirstChild(p.nome .. sufixo, true)
			if parte and parte:IsA("BasePart") then
				parte.Anchored = true
				parte.CanCollide = false
				parte.CanQuery = false
				parte.CanTouch = false
				if sufixo == "_brilho" then
					parte.Material = Enum.Material.Neon
				end
				local local_ = referencia:ToObjectSpace(parte.CFrame)
				table.insert(
					camadas,
					{ parte = parte, centro = local_.Position, rel = local_.Rotation }
				)
			end
		end
		table.insert(pecas, {
			nome = p.nome,
			pai = p.pai,
			junta = if p.junta
				then Vector3.new(p.junta[1], p.junta[2], p.junta[3]) * escala
				else nil,
			camadas = camadas,
			giro = CFrame.identity,
			total = CFrame.identity,
		})
	end
	return modelo, pecas, escala
end

local function barraDeVida(
	parte: BasePart,
	altura: number,
	nome: string,
	chefe: boolean
): (BillboardGui, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "VidaCriatura"
	gui.Size = UDim2.fromOffset(if chefe then 240 else 150, if chefe then 46 else 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, altura / 2 + 1.2, 0)
	gui.MaxDistance = if chefe then 120 else 70
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	local rotulo = Instance.new("TextLabel")
	rotulo.BackgroundTransparency = 1
	rotulo.Size = UDim2.new(1, 0, 0, if chefe then 24 else 16)
	rotulo.Font = Enum.Font.Oswald
	rotulo.TextSize = if chefe then 22 else 15
	rotulo.TextColor3 = if chefe then Color3.fromHex("FFC83D") else Color3.fromHex("F7F2EC")
	rotulo.TextStrokeTransparency = 0.3
	-- o nome do chefe já vem maior e dourado (a fonte Oswald não tem símbolos como a coroa)
	rotulo.Text = if chefe then string.upper(nome) else nome
	rotulo.Parent = gui
	local fundo = Instance.new("Frame")
	fundo.BackgroundColor3 = Color3.fromHex("0B0915")
	fundo.BorderSizePixel = 0
	fundo.Position = UDim2.new(0, 0, 1, if chefe then -16 else -12)
	fundo.Size = UDim2.new(1, 0, 0, if chefe then 12 else 8)
	fundo.Parent = gui
	local contorno = Instance.new("UIStroke")
	contorno.Color = Color3.fromHex("605682")
	contorno.Parent = fundo
	local cheio = Instance.new("Frame")
	cheio.BackgroundColor3 = if chefe then Color3.fromHex("FF5C7A") else Color3.fromHex("7BF0A0")
	cheio.BorderSizePixel = 0
	cheio.Size = UDim2.fromScale(1, 1)
	cheio.Parent = fundo
	gui.Adornee = parte
	gui.Parent = parte
	return gui, cheio
end

local function criar(parte: BasePart): Instancia?
	local id = parte:GetAttribute("Criatura")
	local visual = if type(id) == "string" then (Visual :: any)[id] else nil
	if not visual then
		return nil
	end
	local modelo: Model, pecas: { Peca }, escala: number
	local molde = ReplicatedStorage:FindFirstChild("CorredorModelos")
	local importado = molde and molde:FindFirstChild(id)
	local feito = false
	if importado and importado:IsA("Model") then
		local ok, m, p, e = pcall(montarImportado, id, visual, importado)
		if ok and m and p and e then
			modelo, pecas, escala = m, p, e
			feito = true
		end
	end
	if not feito then
		local ok, m, p, e = pcall(montarKit, id, visual)
		if not ok then
			warn("[Criaturas] não deu para montar " .. id .. ": " .. tostring(m))
			return nil
		end
		modelo, pecas, escala = m, p, e
	end
	local porNome: { [string]: Peca } = {}
	for _, p in pecas do
		porNome[p.nome] = p
	end
	local chefe = parte:GetAttribute("Tipo") == "chefe"
	local barra, vida =
		barraDeVida(parte, parte.Size.Y, tostring(parte:GetAttribute("Nome") or ""), chefe)
	modelo.Parent = pasta
	return {
		parte = parte,
		modelo = modelo,
		pecas = pecas,
		porNome = porNome,
		altura = visual.altura * escala,
		escala = escala,
		tipo = if chefe then "chefe" else "lacaio",
		fase = tonumber(parte:GetAttribute("Fase")) or 1,
		barra = barra,
		vida = vida,
		nascido = os.clock(),
		morreu = false,
		renascido = nil,
	}
end

-- ===================================================================== animar

local rad = math.rad

local function recente(parte: BasePart, atributo: string, duracao: number): number?
	local quando = parte:GetAttribute(atributo)
	if type(quando) ~= "number" then
		return nil
	end
	local f = (Workspace:GetServerTimeNow() - quando) / duracao
	return if f >= 0 and f <= 1 then f else nil
end

local function giro(i: Instancia, nome: string, cf: CFrame)
	local p = i.porNome[nome]
	if p then
		p.giro = cf
	end
end

local function animar(i: Instancia, t: number)
	local parte = i.parte
	local chefe = i.tipo == "chefe"
	local amp = if prefs.movimentoReduzido then 0.3 else 1
	local fase = t * (if chefe then 1.4 else 2.2) + i.nascido
	local respira = math.sin(fase) * amp
	-- repouso: respira, balança os braços, cabeça olha em volta devagar
	giro(i, "tronco", CFrame.new(0, respira * 0.06 * i.escala, 0))
	giro(i, "cabeca", CFrame.Angles(rad(3 * respira), rad(8 * math.sin(fase * 0.3) * amp), 0))
	giro(i, "braco_e", CFrame.Angles(rad(4 * respira), 0, rad(-3 - 2 * respira)))
	giro(i, "braco_d", CFrame.Angles(rad(-4 * respira), 0, rad(3 + 2 * respira)))
	giro(i, "perna_e", CFrame.identity)
	giro(i, "perna_d", CFrame.identity)
	giro(i, "asa_e", CFrame.Angles(0, rad(-12 - 10 * math.sin(fase * 1.6)), 0))
	giro(i, "asa_d", CFrame.Angles(0, rad(12 + 10 * math.sin(fase * 1.6)), 0))
	local inclina, recuo = 0, 0
	-- ataque: puxa o braço e desce o golpe (chefe: os dois braços, de cima)
	local a = recente(parte, "AtacouEm", if chefe then 0.9 else 0.7)
	if a then
		local prepara = math.clamp(a / 0.45, 0, 1)
		local desce = math.clamp((a - 0.45) / 0.25, 0, 1)
		local volta = math.clamp((a - 0.7) / 0.3, 0, 1)
		local angulo = (-120 * prepara + 220 * desce) * (1 - volta)
		inclina = (-8 * prepara + 22 * desce) * (1 - volta)
		giro(i, "braco_d", CFrame.Angles(rad(angulo), 0, rad(6)))
		if chefe then
			giro(i, "braco_e", CFrame.Angles(rad(angulo), 0, rad(-6)))
		end
	end
	-- levou golpe: tranco para trás
	local h = recente(parte, "AtingidoEm", 0.3)
	if h then
		local f = math.sin(h * math.pi)
		inclina -= 12 * f * amp
		recuo = 0.4 * f * amp * i.escala
		giro(i, "cabeca", CFrame.Angles(rad(-15 * f), 0, 0))
	end
	-- morreu: cai para trás e afunda; renascer: cresce de volta
	local viva = parte:GetAttribute("Viva") ~= false
	local cair, afundar, surgir = 0, 0, 1
	if not viva then
		local quando = parte:GetAttribute("MorreuEm")
		local d = if type(quando) == "number" then Workspace:GetServerTimeNow() - quando else 9
		cair = math.clamp(d / 0.6, 0, 1)
		afundar = math.clamp((d - 0.8) / 1.2, 0, 1)
		i.morreu = true
	else
		if i.morreu then
			i.morreu = false
			i.renascido = os.clock()
		end
		local inicio = i.renascido
		if inicio then
			surgir = math.clamp((os.clock() - inicio) / 0.5, 0, 1)
			if surgir >= 1 then
				i.renascido = nil
			end
		end
	end
	local pes = parte.CFrame * CFrame.new(0, -parte.Size.Y / 2, 0)
	local base = pes
		* CFrame.new(0, -afundar * i.altura, recuo)
		* CFrame.Angles(rad(-inclina - 85 * cair), 0, 0)
	local transparencia = math.max(afundar, 1 - surgir)
	-- monta as transformações de pai para filho (a lista vem do gerador nessa ordem)
	for _, p in i.pecas do
		local pai = if p.pai then i.porNome[p.pai] else nil
		local antes = if pai then pai.total else CFrame.identity
		local j = p.junta
		p.total = if j then antes * CFrame.new(j) * p.giro * CFrame.new(-j) else antes * p.giro
		for _, c in p.camadas do
			c.parte.CFrame = base * p.total * CFrame.new(c.centro) * c.rel
			c.parte.LocalTransparencyModifier = transparencia
		end
	end
	-- barra de vida
	local vida = tonumber(parte:GetAttribute("Vida")) or 0
	local maximo = math.max(tonumber(parte:GetAttribute("VidaMax")) or 1, 1)
	i.vida.Size = UDim2.fromScale(math.clamp(vida / maximo, 0, 1), 1)
	i.barra.Enabled = viva and (vida < maximo or i.tipo == "chefe" or parte == meuAlvo)
end

-- ===================================================================== golpes da aura

-- Cada aura ataca com o poder da família dela (Dados/AtaquesAura); o visual está em
-- Mundo/AtaquesAura. O servidor manda todos os acertos (principal, área, corrente...).
local function parteDoId(id: any): BasePart?
	for parte in instancias do
		if parte:GetAttribute("Id") == id then
			return parte
		end
	end
	return nil
end

local function golpe(dados: { [string]: any })
	if type(dados) ~= "table" or dados.tipo ~= "golpe" then
		return
	end
	local alvoParte = parteDoId(dados.alvo)
	local jogador = Players:GetPlayerByUserId(tonumber(dados.de) or 0)
	local personagem = jogador and jogador.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not alvoParte or not raiz then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - alvoParte.Position).Magnitude > DISTANCIA then
		return
	end
	local meu = dados.de == Players.LocalPlayer.UserId
	local acertos: { AtaquesFx.Acerto } = {}
	if type(dados.acertos) == "table" then
		for _, a in dados.acertos do
			local parte = if type(a) == "table" then parteDoId(a.alvo) else nil
			if parte and type(a.dano) == "number" then
				table.insert(acertos, {
					pos = parte.Position,
					atraso = math.clamp(tonumber(a.atraso) or 0, 0, 4),
					dano = a.dano,
					critico = a.critico == true,
					tipo = if type(a.tipo) == "string" then a.tipo else "principal",
				})
			end
		end
	end
	if #acertos == 0 and type(dados.dano) == "number" then
		table.insert(
			acertos,
			{ pos = alvoParte.Position, atraso = 0, dano = dados.dano, tipo = "principal" }
		)
	end
	local poderId = if type(dados.poder) == "string" then dados.poder else "estilhaco"
	local poder = AtaquesAura.PODERES[poderId]
	local tier = tonumber(dados.tier) or 1
	local raio = if poder and poder.area then AtaquesAura.raio(poder.area.raio, tier) else nil
	AtaquesFx.tocar({
		poder = poderId,
		origem = raiz.Position + Vector3.new(0, 1.2, 0),
		alvo = alvoParte.Position,
		acertos = acertos,
		aura = if type(dados.aura) == "string" then dados.aura else nil,
		tier = tier,
		forte = dados.forte == true,
		meu = meu,
		raio = raio,
	})
end

-- ===================================================================== ciclo

local function acompanhar(parte: Instance)
	if not parte:IsA("BasePart") then
		return
	end
	local detector = parte:FindFirstChildOfClass("ClickDetector")
	if detector then
		detector.MouseClick:Connect(function()
			meuAlvo = parte
		end)
	end
end

function Criaturas.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "CriaturasVisuais"
	pasta.Parent = Workspace
	task.spawn(function()
		local origem = Workspace:WaitForChild("CriaturasCorredor", 60)
		if not origem then
			return
		end
		for _, p in origem:GetChildren() do
			acompanhar(p)
		end
		origem.ChildAdded:Connect(acompanhar)
		RunService.Heartbeat:Connect(function()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end
			local olho = camera.CFrame.Position
			local t = os.clock()
			for _, parte in origem:GetChildren() do
				if not parte:IsA("BasePart") then
					continue
				end
				local perto = (parte.Position - olho).Magnitude < DISTANCIA
				local i = instancias[parte]
				if perto and not i then
					if not criando[parte] then
						criando[parte] = true
						task.spawn(function()
							local ok, nova = pcall(criar, parte)
							criando[parte] = nil
							if not ok then
								warn("[Criaturas] " .. tostring(nova))
								return
							end
							if nova then
								if instancias[parte] or not parte.Parent then
									nova.modelo:Destroy()
									nova.barra:Destroy()
								else
									instancias[parte] = nova
								end
							end
						end)
					end
				elseif not perto and i then
					i.modelo:Destroy()
					i.barra:Destroy()
					instancias[parte] = nil
					i = nil
				end
				if i then
					animar(i, t)
				end
			end
		end)
	end)
	Remotos.evento("Corredor").OnClientEvent:Connect(golpe)
end

return Criaturas
