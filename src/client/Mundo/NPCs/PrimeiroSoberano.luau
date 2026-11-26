-- Visual do Primeiro Soberano neste cliente: monta a armadura de placas articulada (peças do
-- Blender em Nexo3D/Dados/soberano_*) sobre o NPC que o SERVIDOR criou e anima o repouso.
-- Tudo o que é compartilhado (quem ele olha, quando reage, o gesto no trono) vem dos atributos
-- da peça "Raiz" do servidor. Aqui é só imagem: nada de regra de jogo.
--
-- Não é malha com pele/ossos: cada peça é rígida e gira em volta da sua junta (SoberanoPecas).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Dados = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados")
local Pecas = require(Dados:WaitForChild("SoberanoPecas"))
local ArenaCena = require(Dados:WaitForChild("ArenaCena"))
local Animacoes = require(Dados:WaitForChild("ArenaAnimacoes"))
local Malha = require(script.Parent.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))

local PrimeiroSoberano = {}

export type Preferencias = { qualidadeBaixa: boolean, movimentoReduzido: boolean }

local COR_LUZ = Color3.fromHex("FF735D")
local COR_OLHOS_ACESOS = Color3.fromHex("FFC79A")
local DURACAO_REACAO = 0.55
local DURACAO_ALERTA = 1.6
local DISTANCIA_ANIMAR = 220

type Peca = {
	parte: BasePart,
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

-- O duelo usa o relógio replicado: quem passa pela Arena vê a mesma entrada e os mesmos golpes.
-- Devolve a pose do quadro, se ela é de um golpe (brilho), o nome do clipe e o tempo dentro dele.
local AVISOS = {
	pesado = "avisoPesado",
	investida = "avisoInvestida",
	baluarte = "avisoBaluarte",
	trinca = "avisoTrinca",
	finta = "avisoPesado", -- a finta começa igual ao golpe pesado (é o truque)
}
local ATAQUES = { investida = true, pesado = true, baluarte = true, trinca = true, finta = true }

local function poseDuelo(raiz: BasePart): (Animacoes.Pose?, number, string?, number, number)
	local agora = Workspace:GetServerTimeNow()
	local inicio = raiz:GetAttribute("DueloInicio")
	if raiz:GetAttribute("Estado") ~= "DESAFIO_EM_ANDAMENTO" or type(inicio) ~= "number" then
		return nil, 0, nil, 0, 0
	end
	local t = agora - inicio
	local nome = raiz:GetAttribute("DueloAnim")
	local em = raiz:GetAttribute("DueloAnimEm")
	local clipe = if type(nome) == "string" then Animacoes.SOBERANO[nome] else nil
	if clipe and type(em) == "number" and agora >= em then
		local tc = agora - em
		if tc < clipe.duracao or clipe.segurar then
			local brilho = if ATAQUES[nome]
				then math.sin(math.min(tc / clipe.duracao, 1) * math.pi)
				else 0
			return Animacoes.amostrar(clipe, tc), brilho, nome, tc, t
		end
	end
	local entrada = Animacoes.SOBERANO.entrada
	if t < entrada.duracao then
		return Animacoes.amostrar(entrada, t), 0, "entrada", t, t
	end
	local intencao = raiz:GetAttribute("DueloIntencao")
	local aviso = if type(intencao) == "string" then AVISOS[intencao] else nil
	local laco = Animacoes.SOBERANO[aviso or "espera"]
	return Animacoes.amostrar(laco, t), if intencao == "pesado" then 0.5 else 0, nil, 0, t
end

local PERNAS = { "quadril_duelo", "coxa_dir", "coxa_esq", "canela_dir", "canela_esq" }
local DUELO: { [string]: boolean } = {}
for _, d in Pecas.duelo :: { { [string]: any } } do
	DUELO[d.nome] = true
end

-- Usa os mesmos centros e pivôs das malhas. Assim a espada acompanha o antebraço
-- mesmo enquanto o cliente carrega a armadura, ou se faltar memória para EditableMesh.
local dadosMalhas = script.Parent.Parent.Nexo3D.Dados
local function criarBloco(nome: string): (BasePart, Vector3)
	local d = require(dadosMalhas:FindFirstChild(nome) :: ModuleScript) :: Malha.Dados
	local tamanho = Vector3.new(d.tamanho[1], d.tamanho[2], d.tamanho[3])
	local centro = Vector3.new(d.minimo[1], d.minimo[2], d.minimo[3]) + tamanho / 2
	local parte = Instance.new("Part")
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	parte.CanQuery = false
	parte.Color = Color3.fromHex("393447")
	parte.Size = tamanho * 0.8
	if nome == "soberano_lamina_duelo" or nome == "soberano_espada" then
		parte.Size = tamanho * Vector3.new(0.38, 1, 0.72)
		parte.Color = Color3.fromHex("B8A787")
	elseif nome == "soberano_olhos" or nome == "soberano_nucleo" then
		centro -= Vector3.new(0, 0, 0.16)
	elseif nome == "soberano_capa_dir" or nome == "soberano_capa_esq" then
		parte.Size = tamanho * Vector3.new(0.6, 0.95, 0.16)
		parte.Color = Color3.fromHex("482C40")
		centro += Vector3.new(0, 0, 1.1)
	end
	return parte, centro
end

local function montar(
	modelo: Model,
	raiz: BasePart,
	detalhado: boolean
): ({ [string]: Peca }, Folder)
	local prontas: Malha.Cache = {}
	local pasta = Instance.new("Folder")
	pasta.Name = "Armadura"
	local pecas: { [string]: Peca } = {}
	local ok, erro = pcall(function()
		local descricoes = table.clone(Pecas.pecas) :: { { [string]: any } }
		for _, d in Pecas.duelo :: { { [string]: any } } do
			table.insert(descricoes, d)
		end
		for _, d in descricoes do
			local parte: BasePart, centro: Vector3
			if detalhado then
				parte, centro = Malha.criar(d.malha, prontas)
			else
				parte, centro = criarBloco(d.malha)
			end
			parte.Name = d.nome
			parte.Material = (Enum.Material :: any)[d.material] or Enum.Material.Metal
			parte.CastShadow = d.material ~= "Neon"
			if d.material == "Neon" then
				parte.Color = COR_LUZ -- as peças de luz são brancas nos vértices: a cor vem daqui
			end
			if DUELO[d.nome] then
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
	return pecas, pasta
end

function PrimeiroSoberano.iniciar()
	local nexo = Workspace:WaitForChild("Nexo")
	local modelo = nexo:WaitForChild("PrimeiroSoberano", 30) :: Model?
	if not modelo then
		return
	end
	local raiz = modelo:WaitForChild("Raiz") :: BasePart
	local pecas, blocos = montar(modelo, raiz, false)
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

	-- estado do duelo neste cliente
	local poseAnterior: Animacoes.Pose? = nil
	local ultimoClipe: string? = nil
	local ultimoTempoClipe = 0

	-- anel de poeira e luz que corre pelo piso quando ele bate no chão
	local function pousar(onde: CFrame, forte: boolean)
		if prefs.qualidadeBaixa then
			return
		end
		local chao = onde * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90))
		for i, cor in { COR_LUZ, Color3.fromHex("8C8296") } do
			local anel = Instance.new("Part")
			anel.Name = "PousoSoberano"
			anel.Shape = Enum.PartType.Cylinder
			anel.Material = if i == 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			anel.Color = cor
			anel.Anchored = true
			anel.CanCollide = false
			anel.CanQuery = false
			anel.CanTouch = false
			anel.CastShadow = false
			anel.Transparency = if i == 1 then 0.35 else 0.55
			anel.Size = Vector3.new(0.05, 2, 2)
			anel.CFrame = chao
			anel.Parent = modelo
			local raio = (if forte then 22 else 15) * (if i == 1 then 1 else 0.7)
			local duracao = if i == 1 then 0.5 else 0.8
			TweenService
				:Create(
					anel,
					TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Size = Vector3.new(0.05, raio, raio),
						Transparency = 1,
					}
				)
				:Play()
			Debris:AddItem(anel, duracao + 0.1)
		end
	end

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

		-- duelo: a pose do clipe substitui o repouso; o tronco passa a ser filho do quadril
		local pose, intensidade, clipeNome, tClipe, tDuelo = poseDuelo(raiz)
		local referencial = origem
		local emPe = false
		local quadrilTotal = CFrame.identity
		if pose then
			if prefs.movimentoReduzido then
				-- sem salto alto: o corpo anda o mesmo trajeto, rente ao chão
				pose.raiz2 = math.min(pose.raiz2 or 0, 0.4)
				pose.peD1 = math.min(pose.peD1 or 0, 0.8)
				pose.peE1 = math.min(pose.peE1 or 0, 0.8)
			end
			local anterior = poseAnterior
			if anterior and clipeNome ~= "entrada" and (not clipeNome or tClipe < 0.09) then
				pose = Animacoes.misturar(
					anterior,
					pose,
					1 - math.exp(-dt * (if clipeNome then 26 else 8))
				)
			end
			-- A capa acompanha a torção do tronco e abre durante o salto.
			if capa > 0 then
				local giro = math.rad(math.clamp(-(pose.torso2 or 0) * 0.42, -20, 20))
				local abrir =
					math.rad(math.clamp((pose.raiz2 or 0) * 4 - (pose.torso1 or 0) * 0.24, 0, 22))
				pecas.capa_dir.giro *= CFrame.Angles(-abrir, giro, abrir * 0.35)
				pecas.capa_esq.giro *= CFrame.Angles(-abrir, giro, -abrir * 0.35)
			end
			poseAnterior = pose
			emPe = tDuelo >= 0.34
			local de = origem * CFrame.new(0, 0, -2.1)
			local base =
				origem:Lerp(de, suave(tDuelo / 0.44)):Lerp(ArenaCena.soberano, pose.viagem1 or 1)
			referencial = base
				* CFrame.new(pose.raiz1 or 0, pose.raiz2 or 0, pose.raiz3 or 0)
				* CFrame.Angles(
					math.rad(pose.raiz4 or 0),
					math.rad(pose.raiz5 or 0),
					math.rad(pose.raiz6 or 0)
				)
			local function g(nome: string): CFrame
				return CFrame.Angles(
					math.rad(pose[nome .. "1"] or 0),
					math.rad(pose[nome .. "2"] or 0),
					math.rad(pose[nome .. "3"] or 0)
				)
			end
			pecas.torso.giro = if emPe
				then g("torso") * CFrame.Angles(math.rad(0.7) * respira * amp, 0, 0)
				else CFrame.new(0, 1.35 * suave(math.clamp(pose.erguer1 or 1, 0, 1)), 0)
			pecas.cabeca.giro = g("cabeca")
			pecas.braco_dir.giro = g("bracoD")
			pecas.antebraco_dir.giro = g("antebracoD")
			pecas.braco_esq.giro = g("bracoE")
			pecas.antebraco_esq.giro = g("antebracoE")
			if emPe then
				-- pernas: cinemática inversa a partir dos pés do clipe (ficam plantados no chão)
				local pernas =
					Animacoes.resolverPernas(table.clone(pose), Pecas.pernas.dir, Pecas.pernas.esq)
				local q = pecas.quadril_duelo
				local jq = q.junta :: Vector3
				q.total = CFrame.new(jq) * g("quadril") * CFrame.new(-jq)
				quadrilTotal = q.total * CFrame.new(0, 1.35, 0)
				for _, lado in { { "dir", "D" }, { "esq", "E" } } do
					local coxa = pecas["coxa_" .. lado[1]]
					local canela = pecas["canela_" .. lado[1]]
					local jc, jj = coxa.junta :: Vector3, canela.junta :: Vector3
					coxa.total = q.total
						* CFrame.new(jc)
						* CFrame.Angles(math.rad(pernas["quadril" .. lado[2] .. "1"] or 0), 0, 0)
						* CFrame.new(-jc)
					canela.total = coxa.total
						* CFrame.new(jj)
						* CFrame.Angles(math.rad(pernas["joelho" .. lado[2] .. "1"] or 0), 0, 0)
						* CFrame.new(-jj)
				end
			end
			-- poeira no pouso do salto e no golpe que racha o chão
			if clipeNome then
				for _, instante in Animacoes.POUSOS[clipeNome] or {} do
					if
						tClipe >= instante
						and ultimoTempoClipe < instante
						and ultimoClipe == clipeNome
					then
						pousar(
							base * CFrame.new(pose.raiz1 or 0, 0, pose.raiz3 or 0),
							clipeNome == "pesado"
						)
					end
				end
			end
			ultimoClipe, ultimoTempoClipe = clipeNome, tClipe
		else
			poseAnterior = nil
			ultimoClipe = nil
		end
		local guardiao = raiz:GetAttribute("Estado") == "DESAFIO_EM_ANDAMENTO"
		for _, p in ordem do
			local base = if p.pai
				then p.pai.total
				elseif emPe and p == pecas.torso then quadrilTotal
				else CFrame.identity
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
		for nome in DUELO do
			pecas[nome].parte.Transparency = if emPe then 0 else 1
		end
		if emPe then
			for _, nome in PERNAS do
				local p = pecas[nome]
				p.parte.CFrame = referencial * p.total * CFrame.new(p.centro)
			end
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

	-- O render já está ativo. Só troca a geometria quando todas as peças ficam prontas.
	for tentativa, espera in { 0, 3, 8, 20 } do
		if espera > 0 then
			task.wait(espera)
		end
		if not modelo.Parent then
			return
		end
		local ok, detalhadas, pasta = pcall(montar, modelo, raiz, true)
		if ok then
			if not modelo.Parent then
				pasta:Destroy()
				return
			end
			luz.Parent = detalhadas.nucleo.parte
			for nome, atual in pecas do
				local nova = detalhadas[nome]
				nova.parte.CFrame = atual.parte.CFrame * CFrame.new(nova.centro - atual.centro)
				nova.parte.Transparency = atual.parte.Transparency
				atual.parte = nova.parte
				atual.centro = nova.centro
			end
			blocos:Destroy()
			modelo:SetAttribute("ErroArmadura", nil)
			return
		end
		modelo:SetAttribute("ErroArmadura", tostring(detalhadas))
		warn(
			string.format(
				"[Soberano] armadura 3D, tentativa %d: %s",
				tentativa,
				tostring(detalhadas)
			)
		)
	end
end

return PrimeiroSoberano
