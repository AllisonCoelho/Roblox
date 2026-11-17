-- Visual do Primeiro Soberano neste cliente: monta a armadura de placas articulada (peças do
-- Blender em Nexo3D/Dados/soberano_*) sobre o NPC que o SERVIDOR criou e anima o repouso.
-- Tudo o que é compartilhado (quem ele olha, quando reage, o gesto no trono) vem dos atributos
-- da peça "Raiz" do servidor. Aqui é só imagem: nada de regra de jogo.
--
-- Não é malha com pele/ossos: cada peça é rígida e gira em volta da sua junta (SoberanoPecas).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Dados = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados")
local Pecas = require(Dados:WaitForChild("SoberanoPecas"))
local ArenaCena = require(Dados:WaitForChild("ArenaCena"))
local Malha = require(script.Parent.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))

local PrimeiroSoberano = {}

export type Preferencias = { qualidadeBaixa: boolean, movimentoReduzido: boolean }

local COR_LUZ = Color3.fromHex("FF735D")
local COR_OLHOS_ACESOS = Color3.fromHex("FFC79A")
local DURACAO_REACAO = 0.55
local DURACAO_ALERTA = 1.6
local DISTANCIA_ANIMAR = 220

type Peca = {
	parte: MeshPart,
	centro: Vector3, -- centro da malha no espaço do NPC
	junta: Vector3?,
	pai: Peca?,
	giro: CFrame, -- rotação atual em volta da junta
	total: CFrame, -- transformação acumulada (com as dos pais)
}

local prefs: Preferencias = { qualidadeBaixa = false, movimentoReduzido = false }

function PrimeiroSoberano.definir(novas: Preferencias)
	prefs = novas
end

local function suave(x: number): number
	local a = math.clamp(x, 0, 1)
	return a * a * (3 - 2 * a)
end

-- As poses usam o relógio replicado. Quem passa pela Arena vê a mesma entrada e os ataques.
local function poseDuelo(
	p: { [string]: Peca },
	raiz: BasePart,
	origem: CFrame
): (CFrame, boolean, number)
	local agora = Workspace:GetServerTimeNow()
	local inicio = raiz:GetAttribute("DueloInicio")
	if raiz:GetAttribute("Estado") ~= "DESAFIO_EM_ANDAMENTO" or type(inicio) ~= "number" then
		return origem, false, 0
	end

	local t = agora - inicio
	local emPe = t >= 0.34
	local avanco = suave((t - 0.45) / 1.18)
	local de = origem * CFrame.new(0, 0, -2.1)
	local base = origem:Lerp(de, suave(t / 0.44)):Lerp(ArenaCena.soberano, avanco)
	local andar = if avanco > 0 and avanco < 1 then math.sin(avanco * math.pi * 5) else 0
	local altura = if emPe then 1.35 else 1.35 * suave(t / 0.34)
	local arma = raiz:GetAttribute("DueloGolpe")
	local intencao = raiz:GetAttribute("DueloIntencao")
	local quando = raiz:GetAttribute("DueloGolpeEm")
	local preparo, corte, recuo, derrota = 0, 0, 0, 0
	if arma and type(quando) == "number" then
		local f = math.max(0, agora - quando)
		local impacto = if arma == "pesado" then 0.46 else 0.27
		local fim = impacto + (if arma == "pesado" then 0.62 else 0.42)
		if arma == "pesado" or arma == "investida" then
			preparo = 1 - suave(f / impacto)
			corte = suave(f / impacto) * (1 - suave((f - impacto) / (fim - impacto)))
			recuo = corte * (if arma == "pesado" then 7.7 else 6.3)
		elseif arma == "baluarte" then
			preparo = 1 - suave(f / fim)
		elseif arma == "derrota" then
			derrota = suave(f / 0.66)
		end
	elseif intencao == "pesado" or intencao == "baluarte" then
		preparo = if intencao == "pesado" then 0.83 else 0.53
	end

	local rad = math.rad
	if emPe then
		base *= CFrame.new(0, math.abs(andar) * 0.12 - derrota * 0.7, -recuo) * CFrame.Angles(
			rad(-11 * corte - 15 * derrota),
			0,
			rad(21 * derrota)
		)
		p.braco_dir.giro =
			CFrame.Angles(rad(37 + preparo * 82 - corte * 62), 0, rad(18 - corte * 30))
		p.braco_esq.giro = CFrame.Angles(rad(46 - preparo * 38 + corte * 14), 0, rad(-14))
		p.antebraco_dir.giro = CFrame.Angles(rad(16 - preparo * 32), 0, 0)
		p.antebraco_esq.giro = CFrame.Angles(rad(18 - preparo * 35), 0, 0)
		p.cabeca.giro = CFrame.Angles(rad(-6 + derrota * 22), 0, 0)
	end
	p.torso.giro = CFrame.new(0, altura, 0) * CFrame.Angles(rad(-5 * andar - 8 * corte), 0, 0)
	return base, emPe, math.max(preparo * 0.6, corte)
end

local function montar(modelo: Model, raiz: BasePart): { [string]: Peca }
	local prontas: Malha.Cache = {}
	local pasta = Instance.new("Folder")
	pasta.Name = "Armadura"
	local pecas: { [string]: Peca } = {}
	local ok, erro = pcall(function()
		local descricoes = table.clone(Pecas.pecas) :: { { [string]: any } }
		table.insert(
			descricoes,
			{ nome = "base_duelo", malha = "soberano_base_duelo", material = "Metal" }
		)
		table.insert(
			descricoes,
			{ nome = "lamina_duelo", malha = "soberano_lamina_duelo", material = "Metal" }
		)
		for _, d in descricoes do
			local parte, centro = Malha.criar(d.malha, prontas)
			parte.Name = d.nome
			parte.Material = (Enum.Material :: any)[d.material] or Enum.Material.Metal
			parte.CastShadow = d.material ~= "Neon"
			if d.material == "Neon" then
				parte.Color = COR_LUZ -- as peças de luz são brancas nos vértices: a cor vem daqui
			end
			if d.nome == "base_duelo" or d.nome == "lamina_duelo" then
				parte.Transparency = 1
			end
			parte.Parent = pasta
			pecas[d.nome] = {
				parte = parte,
				centro = centro,
				junta = if d.junta then Vector3.new(d.junta[1], d.junta[2], d.junta[3]) else nil,
				pai = if d.pai then pecas[d.pai] else nil,
				giro = CFrame.identity,
				total = CFrame.identity,
			}
		end
	end)
	for _, pronta in prontas do
		pronta.modelo:Destroy()
	end
	if not ok then
		pasta:Destroy()
		error(erro, 0)
	end
	-- posição de repouso antes de aparecer
	for _, p in pecas do
		p.parte.CFrame = raiz.CFrame * CFrame.new(p.centro)
	end
	pasta.Parent = modelo
	return pecas
end

function PrimeiroSoberano.iniciar()
	local nexo = Workspace:WaitForChild("Nexo")
	local modelo = nexo:WaitForChild("PrimeiroSoberano", 30) :: Model?
	if not modelo then
		return
	end
	local raiz = modelo:WaitForChild("Raiz") :: BasePart
	local ok, resultado = pcall(montar, modelo, raiz)
	if not ok then
		warn("[Soberano] armadura 3D indisponível; mantendo a reserva: " .. tostring(resultado))
		return
	end
	local pecas = resultado :: { [string]: Peca }
	for _, inst in modelo:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("ReservaNPC") then
			inst.LocalTransparencyModifier = 1
		end
	end

	local origem = raiz.CFrame
	local centroCabeca = Vector3.new(Pecas.cabeca[1], Pecas.cabeca[2], Pecas.cabeca[3])
	local ordem: { Peca } = {} -- pais antes dos filhos (a lista do gerador já vem nessa ordem)
	for _, d in Pecas.pecas :: { { [string]: any } } do
		table.insert(ordem, pecas[d.nome])
	end

	local luz = Instance.new("PointLight")
	luz.Color = COR_LUZ
	luz.Range = 9
	luz.Brightness = 0.6
	luz.Shadows = false
	luz.Parent = pecas.nucleo.parte

	-- onda de luz no piso (gesto de alerta)
	local onda = Instance.new("Part")
	onda.Name = "OndaTrono"
	onda.Shape = Enum.PartType.Cylinder
	onda.Material = Enum.Material.Neon
	onda.Color = COR_LUZ
	onda.Anchored = true
	onda.CanCollide = false
	onda.CanQuery = false
	onda.CanTouch = false
	onda.CastShadow = false
	onda.Transparency = 1
	onda.Parent = modelo
	local chaoOnda = origem * CFrame.new(0, -1.42, -3) * CFrame.Angles(0, 0, math.rad(90))

	-- estado local da animação
	local aleatorio = Random.new()
	local reacaoAte = 0
	local alertaInicio = -math.huge
	local proximaFissura = os.clock() + aleatorio:NextNumber(4, 9)
	local fissuraInicio = -math.huge
	local olharYaw, olharPitch = 0, 0

	local function horaLocalDe(atributo: string): number?
		local quando = raiz:GetAttribute(atributo)
		if type(quando) ~= "number" or quando <= 0 then
			return nil
		end
		-- só reage se o evento for recente (quem entra depois não vê reação velha)
		if Workspace:GetServerTimeNow() - quando > 3 then
			return nil
		end
		return os.clock()
	end
	raiz:GetAttributeChangedSignal("Reacao"):Connect(function()
		if horaLocalDe("Reacao") then
			reacaoAte = os.clock() + DURACAO_REACAO
		end
	end)
	raiz:GetAttributeChangedSignal("Alerta"):Connect(function()
		local agora = horaLocalDe("Alerta")
		if agora then
			alertaInicio = agora
			reacaoAte = agora + DURACAO_REACAO
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not modelo.Parent then
			return
		end
		local camera = Workspace.CurrentCamera
		if
			not camera
			or (camera.CFrame.Position - origem.Position).Magnitude > DISTANCIA_ANIMAR
		then
			return
		end
		local t = os.clock()
		local reduzido = prefs.movimentoReduzido
		local amp = if reduzido then 0.35 else 1
		local respira = math.sin(t * 1.1)

		-- para onde olhar: o jogador que o servidor indicou; sem ninguém, um olhar lento
		local alvoYaw = math.rad(5) * math.sin(t * 0.23) * amp
		local alvoPitch = math.rad(-4)
		local alvo = raiz:GetAttribute("Alvo")
		if type(alvo) == "number" and alvo ~= 0 then
			local jogador = Players:GetPlayerByUserId(alvo)
			local personagem = jogador and jogador.Character
			local cabeca = personagem and personagem:FindFirstChild("Head")
			if cabeca and cabeca:IsA("BasePart") then
				local l = origem:PointToObjectSpace(cabeca.Position) - centroCabeca
				alvoYaw = math.clamp(math.atan2(-l.X, -l.Z), math.rad(-55), math.rad(55))
				alvoPitch = math.clamp(
					math.atan2(l.Y, math.sqrt(l.X * l.X + l.Z * l.Z)),
					math.rad(-24),
					math.rad(8)
				)
			end
		end
		local k = math.min(dt * 2.2, 1)
		olharYaw += (alvoYaw - olharYaw) * k
		olharPitch += (alvoPitch - olharPitch) * k

		-- gesto de alerta: a mão direita pressiona o braço do trono
		local fa = (t - alertaInicio) / DURACAO_ALERTA
		local pressao = if fa >= 0 and fa <= 1 then math.sin(fa * math.pi) else 0

		pecas.torso.giro = CFrame.new(0, 0.02 * respira * amp, 0)
			* CFrame.Angles(math.rad(0.7) * respira * amp, 0, 0)
		pecas.cabeca.giro = CFrame.Angles(0, olharYaw, 0)
			* CFrame.Angles(olharPitch, 0, math.rad(2.5) * math.sin(t * 0.17) * amp)
		pecas.braco_dir.giro = CFrame.Angles(0, 0, math.rad(0.7) * respira * amp)
		pecas.braco_esq.giro = CFrame.Angles(0, 0, math.rad(-0.7) * respira * amp)
		pecas.antebraco_dir.giro =
			CFrame.Angles(math.rad(0.5) * math.sin(t * 0.37) * amp - math.rad(5) * pressao, 0, 0)
		pecas.antebraco_esq.giro = CFrame.Angles(math.rad(0.5) * math.sin(t * 0.31 + 2) * amp, 0, 0)
		local capa = if reduzido or prefs.qualidadeBaixa then 0 else 1
		pecas.capa_dir.giro = CFrame.Angles(
			math.rad(1.4) * math.sin(t * 0.8) * capa,
			0,
			math.rad(1.1) * math.sin(t * 0.6) * capa
		)
		pecas.capa_esq.giro = CFrame.Angles(
			math.rad(1.4) * math.sin(t * 0.7 + 1.3) * capa,
			0,
			math.rad(-1.1) * math.sin(t * 0.55 + 0.7) * capa
		)

		local referencial, emPe, intensidade = poseDuelo(pecas, raiz, origem)
		local guardiao = raiz:GetAttribute("Estado") == "DESAFIO_EM_ANDAMENTO"
		for _, p in ordem do
			local base = if p.pai then p.pai.total else CFrame.identity
			local junta = p.junta
			if junta then
				p.total = base * CFrame.new(junta) * p.giro * CFrame.new(-junta)
			else
				p.total = base
			end
			p.parte.CFrame = referencial * p.total * CFrame.new(p.centro)
		end

		pecas.base.parte.Transparency = if emPe then 1 else 0
		pecas.espada.parte.Transparency = if emPe then 1 else 0
		pecas.base_duelo.parte.Transparency = if emPe then 0 else 1
		pecas.lamina_duelo.parte.Transparency = if emPe then 0 else 1
		if emPe then
			pecas.base_duelo.parte.CFrame = referencial * CFrame.new(pecas.base_duelo.centro)
			pecas.lamina_duelo.parte.CFrame = referencial
				* pecas.antebraco_dir.total
				* CFrame.new(3.0, 3.75, -2.35)
				* CFrame.Angles(math.rad(-52), 0, math.rad(-17))
				* CFrame.new(pecas.lamina_duelo.centro)
		end

		-- luzes: olhos acendem na reação; uma linha de luz passa pelas fissuras a cada 8–15 s
		local aceso = math.clamp((reacaoAte - t) / DURACAO_REACAO, 0, 1)
		pecas.olhos.parte.Color = COR_LUZ:Lerp(COR_OLHOS_ACESOS, aceso)
		pecas.olhos.parte.Transparency = 0.25 * (1 - aceso)
		if t >= proximaFissura then
			fissuraInicio = t
			proximaFissura = t + aleatorio:NextNumber(8, 15)
		end
		local ff = (t - fissuraInicio) / 1.4
		local onda_f = if ff >= 0 and ff <= 1 then math.sin(ff * math.pi) else 0
		local brilho = math.max(onda_f, aceso, pressao, intensidade)
		pecas.fissuras.parte.Transparency = 0.82 - 0.82 * brilho
		pecas.nucleo.parte.Transparency = 0.3 - 0.08 * respira - 0.2 * brilho
		luz.Brightness = 0.6 + 1.2 * brilho

		-- onda no piso durante o alerta
		if not guardiao and fa >= 0 and fa <= 1 and not prefs.qualidadeBaixa and not reduzido then
			local raio = 3 + 22 * fa
			onda.Size = Vector3.new(0.06, raio * 2, raio * 2)
			onda.CFrame = chaoOnda
			onda.Transparency = 0.78 + 0.22 * fa
		else
			onda.Transparency = 1
		end
	end)
end

return PrimeiroSoberano
