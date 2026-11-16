-- Incursões no servidor: fila no Bastião, partidas (cada grupo num espaço só dele, longe do Nexo),
-- andares, Núcleos, Sombras, Guardião, vidas do grupo e recompensas salvas no perfil.
-- O servidor decide tudo; o cliente só pede (fila, Pulso, sair, relíquia) e recebe o estado pelo
-- remote "Incursao". Nada aqui toca no sorteio de auras: a aura mais rara só vira Ressonância.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Incursoes = require(Shared.Dados.Incursoes)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent:WaitForChild("Servicos")
local Acoes = require(Servicos:WaitForChild("Acoes"))
local Dados = require(Servicos:WaitForChild("Dados"))
local Inimigos = require(script.Parent.Inimigos)
local Mapa = require(script.Parent.Mapa)

local Servico = {}

local SLOTS = 8 -- partidas ao mesmo tempo neste servidor
local PASSO = 1 / 15
local DISTANCIA_BASTIAO = 55 -- para entrar e continuar na fila
local RAIO_CANAL = 11 -- purificar: perto do Núcleo
local RAIO_CONTESTO = 9 -- Sombra perto do Núcleo: a purificação para e volta um pouco
local RAIO_FENDA = 7
local ESPERA_AVANCO = 4
local ESPERA_REFORCO = 2.2
local ESPERA_VOLTA = 5 -- depois do fim, até voltar ao Bastião

type Membro = {
	ressonancia: number,
	proximoPulso: number,
	reviver: boolean,
	conexoes: { RBXScriptConnection },
}

type Run = {
	slot: number,
	universo: string,
	andar: number,
	andaresConcluidos: number,
	vidas: number,
	estado: string, -- "andar" | "fim"
	membros: { [Player]: Membro },
	pasta: Folder,
	origem: CFrame,
	seed: number,
	mapa: Mapa.Andar?,
	cfg: Incursoes.Andar,
	inimigos: { Inimigos.Inimigo },
	restantes: number,
	proximoReforco: number,
	guardiao: Inimigos.Inimigo?,
	fenda: BasePart?,
	avancoEm: number?,
	ultimoEnvio: number,
}

local runs: { [number]: Run } = {}
local daRun: { [Player]: Run } = {}
local filas: { [string]: { jogadores: { Player }, fim: number? } } = {}
local naFila: { [Player]: string } = {}
local raiz: Folder

local function evento(): RemoteEvent
	return Remotos.evento("Incursao")
end

local function enviar(player: Player, dados: { [string]: any })
	evento():FireClient(player, dados)
end

local function paraRun(run: Run, dados: { [string]: any })
	for player in run.membros do
		enviar(player, dados)
	end
end

local function corpo(player: Player): (BasePart?, Humanoid?)
	local personagem = player.Character
	if not personagem then
		return nil, nil
	end
	local r = personagem:FindFirstChild("HumanoidRootPart")
	local h = personagem:FindFirstChildOfClass("Humanoid")
	if r and r:IsA("BasePart") and h then
		return r, h
	end
	return nil, nil
end

local function bastiao(): Vector3
	local nexo = Workspace:FindFirstChild("Nexo")
	local base = nexo and nexo:FindFirstChild("BastiaoBase")
	if base and base:IsA("BasePart") then
		return Vector3.new(base.Position.X, 0, base.Position.Z)
	end
	local a = math.rad(157)
	return Vector3.new(math.sin(a), 0, -math.cos(a)) * 173
end

local function perto(player: Player, ponto: Vector3, raioMax: number): boolean
	local r = corpo(player)
	if not r then
		return false
	end
	return Vector3.new(r.Position.X - ponto.X, 0, r.Position.Z - ponto.Z).Magnitude <= raioMax
end

local function levar(player: Player, cf: CFrame)
	-- com Streaming ligado, pede ao jogo para carregar o lugar antes de levar o personagem
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 2)
	end)
	local personagem = player.Character
	if personagem then
		personagem:PivotTo(cf)
	end
end

local function voltaAoBastiao(player: Player, k: number?)
	local b = bastiao()
	local frente = (-b).Unit
	local lado = Vector3.new(-frente.Z, 0, frente.X)
	local p = b + frente * 10 + lado * (((k or 1) - 2.5) * 3) + Vector3.new(0, 4, 0)
	levar(player, CFrame.lookAt(p, p + frente))
end

local function definirVida(player: Player, maximo: number)
	local _, h = corpo(player)
	if h then
		h.MaxHealth = maximo
		h.Health = maximo
	end
end

local function progressoDe(player: Player): any
	local estado = Dados.de(player)
	return if estado and type(estado.incursoes) == "table"
		then estado.incursoes
		else Incursoes.padrao()
end

local function ressonanciaDe(player: Player): number
	local estado = Dados.de(player)
	local melhor = if estado then Auras.melhorDe(estado.auras) else nil
	return Incursoes.ressonancia(if melhor then melhor.chance else nil)
end

-- ===================================================================== recompensas

local function premiar(player: Player, run: Run, venceu: boolean): number
	local ganho = 0
	Dados.alterar(player, function(estado)
		if type(estado.incursoes) ~= "table" then
			estado.incursoes = Incursoes.padrao()
		end
		local inc = estado.incursoes
		inc.melhor = inc.melhor or {}
		inc.concluidas = inc.concluidas or {}
		local u = run.universo
		local primeira = venceu and (inc.concluidas[u] or 0) == 0
		ganho = Incursoes.recompensa(u, run.andaresConcluidos, venceu, primeira)
		inc.fragmentos = (inc.fragmentos or 0) + ganho
		local alcancado = if venceu then Incursoes.ANDARES else run.andar
		inc.melhor[u] = math.max(inc.melhor[u] or 0, alcancado)
		if venceu then
			inc.concluidas[u] = (inc.concluidas[u] or 0) + 1
		end
		return true
	end)
	return ganho
end

-- ===================================================================== partidas

local function limparAndar(run: Run)
	for _, i in run.inimigos do
		i.parte:Destroy()
	end
	table.clear(run.inimigos)
	run.guardiao = nil
	run.fenda = nil
	run.avancoEm = nil
	if run.mapa then
		run.mapa.pasta:Destroy()
		run.mapa = nil
	end
end

local function encerrar(run: Run)
	limparAndar(run)
	run.pasta:Destroy()
	runs[run.slot] = nil
end

local function desligar(player: Player, run: Run)
	local m = run.membros[player]
	if m then
		for _, c in m.conexoes do
			c:Disconnect()
		end
	end
	run.membros[player] = nil
	daRun[player] = nil
end

-- Um jogador sai da partida (saiu, caiu sem vidas ou desconectou): leva o que já ganhou
local function sair(run: Run, player: Player, motivo: string)
	if not run.membros[player] then
		return
	end
	local ganho = premiar(player, run, false)
	desligar(player, run)
	if motivo ~= "desconectou" then
		definirVida(player, Incursoes.VIDA_BASE)
		voltaAoBastiao(player)
		enviar(player, {
			tipo = "fim",
			universo = run.universo,
			venceu = false,
			andares = run.andaresConcluidos,
			fragmentos = ganho,
			motivo = motivo,
		})
	end
	if next(run.membros) == nil and run.estado ~= "fim" then
		run.estado = "fim"
		encerrar(run)
	end
end

local function terminar(run: Run, venceu: boolean)
	if run.estado == "fim" then
		return
	end
	run.estado = "fim"
	for _, i in run.inimigos do
		Inimigos.ferir(i, math.huge)
	end
	local lista = {}
	for player in run.membros do
		table.insert(lista, player)
	end
	for k, player in lista do
		local ganho = premiar(player, run, venceu)
		enviar(player, {
			tipo = "fim",
			universo = run.universo,
			venceu = venceu,
			andares = run.andaresConcluidos,
			fragmentos = ganho,
			motivo = if venceu then "vitoria" else "derrota",
		})
		task.delay(ESPERA_VOLTA, function()
			definirVida(player, Incursoes.VIDA_BASE)
			if player.Parent then
				voltaAoBastiao(player, k)
			end
		end)
	end
	task.delay(ESPERA_VOLTA + 0.5, function()
		for _, player in lista do
			desligar(player, run)
		end
		encerrar(run)
	end)
end

local function ativos(run: Run): number
	local n = 0
	for _ in run.membros do
		n += 1
	end
	return n
end

local function novoInimigo(run: Run, pos: Vector3, guardiao: boolean): Inimigos.Inimigo?
	local mapa = run.mapa
	if not mapa then
		return nil
	end
	local i = Inimigos.novo(mapa.pasta, run.universo, pos, run.cfg, guardiao)
	table.insert(run.inimigos, i)
	return i
end

local function iniciarAndar(run: Run, n: number)
	limparAndar(run)
	run.andar = n
	run.cfg = Incursoes.andar(run.universo, n, ativos(run))
	run.mapa = Mapa.construir(run.pasta, run.universo, n, run.origem, run.seed + n * 101)
	local mapa = run.mapa :: Mapa.Andar
	run.restantes = run.cfg.sombras + run.cfg.reforcos
	run.proximoReforco = os.clock() + 3
	-- primeiras Sombras já no andar (longe do spawn)
	local iniciais = math.min(
		if run.cfg.guardiao then run.cfg.sombras else math.ceil(run.cfg.sombras / 2),
		run.restantes
	)
	for k = 1, iniciais do
		local p = mapa.pontosSombra[(k - 1) % #mapa.pontosSombra + 1]
		novoInimigo(run, p, false)
		run.restantes -= 1
	end
	if run.cfg.guardiao then
		run.guardiao = novoInimigo(run, mapa.centroGuardiao, true)
		run.restantes = 0
	end
	local k = 0
	for player in run.membros do
		k += 1
		local m = run.membros[player]
		m.reviver = false
		levar(player, mapa.spawn * CFrame.new((k - 2.5) * 3, 0, 0))
	end
	local u = Incursoes.porId[run.universo]
	paraRun(run, {
		tipo = "andar",
		universo = run.universo,
		andar = n,
		andares = Incursoes.ANDARES,
		titulo = if run.cfg.guardiao then u.guardiao else nil,
	})
end

local function abrirFenda(run: Run)
	local mapa = run.mapa
	if not mapa or run.fenda then
		return
	end
	local u = Incursoes.porId[run.universo]
	local fenda = Mapa.peca(mapa.pasta, "inc_" .. run.universo .. "_portal", mapa.saida, 1)
	fenda:SetAttribute("CorLuz", Color3.fromHex(u.corVeio))
	fenda:SetAttribute("Fenda", true)
	run.fenda = fenda
	run.andaresConcluidos = math.max(run.andaresConcluidos, run.andar)
	for _, i in run.inimigos do
		Inimigos.ferir(i, math.huge) -- as Sombras se desfazem quando o andar é purificado
	end
	paraRun(
		run,
		{ tipo = "aviso", texto = "Andar purificado! A fenda abriu: entre nela para descer." }
	)
end

local function aoMorrer(run: Run, player: Player)
	if run.estado == "fim" or not run.membros[player] then
		return
	end
	if run.vidas > 0 then
		run.vidas -= 1
		run.membros[player].reviver = true
		enviar(player, {
			tipo = "aviso",
			texto = string.format(
				"Você caiu! Volta ao andar em instantes. Vidas do grupo: %d",
				run.vidas
			),
		})
	else
		enviar(player, { tipo = "aviso", texto = "Sem vidas no grupo: você volta ao Nexo." })
		task.delay(2, function()
			sair(run, player, "caiu")
		end)
	end
end

local function ligarPersonagem(run: Run, player: Player, personagem: Model)
	local h = personagem:WaitForChild("Humanoid", 10) :: Humanoid?
	if not h or run.estado == "fim" or daRun[player] ~= run then
		return
	end
	local m = run.membros[player]
	table.insert(
		m.conexoes,
		h.Died:Connect(function()
			aoMorrer(run, player)
		end)
	)
	if m.reviver and run.mapa then
		m.reviver = false
		personagem:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		definirVida(player, Incursoes.vidaMax(progressoDe(player)))
		levar(player, run.mapa.spawn)
	end
end

local function lancar(universo: string, jogadores: { Player }): boolean
	local slot: number? = nil
	for s = 1, SLOTS do
		if not runs[s] then
			slot = s
			break
		end
	end
	if not slot then
		return false
	end
	local pasta = Instance.new("Folder")
	pasta.Name = string.format("Partida%d", slot)
	pasta.Parent = raiz
	local run: Run = {
		slot = slot,
		universo = universo,
		andar = 0,
		andaresConcluidos = 0,
		vidas = Incursoes.vidas(#jogadores),
		estado = "andar",
		membros = {},
		pasta = pasta,
		-- cada partida num espaço só dela, longe do Nexo (que termina no raio 238)
		origem = CFrame.new(5000 + slot * 400, 600, 0),
		seed = Random.new():NextInteger(1, 2 ^ 30),
		mapa = nil,
		cfg = Incursoes.andar(universo, 1, #jogadores),
		inimigos = {},
		restantes = 0,
		proximoReforco = 0,
		guardiao = nil,
		fenda = nil,
		avancoEm = nil,
		ultimoEnvio = 0,
	}
	runs[slot] = run
	for _, player in jogadores do
		local m: Membro = {
			ressonancia = ressonanciaDe(player),
			proximoPulso = 0,
			reviver = false,
			conexoes = {},
		}
		run.membros[player] = m
		daRun[player] = run
		table.insert(
			m.conexoes,
			player.CharacterAdded:Connect(function(personagem)
				ligarPersonagem(run, player, personagem)
			end)
		)
		if player.Character then
			task.spawn(ligarPersonagem, run, player, player.Character)
		end
		definirVida(player, Incursoes.vidaMax(progressoDe(player)))
	end
	paraRun(run, {
		tipo = "inicio",
		universo = universo,
		vidas = run.vidas,
		jogadores = #jogadores,
	})
	iniciarAndar(run, 1)
	return true
end

-- ===================================================================== laço das partidas

local function enviarEstado(run: Run)
	local mapa = run.mapa
	local feitos, total = 0, 0
	if mapa then
		for _, nucleo in mapa.nucleos do
			total += 1
			if (nucleo:GetAttribute("Progresso") or 0) >= 1 then
				feitos += 1
			end
		end
	end
	local g = run.guardiao
	paraRun(run, {
		tipo = "estado",
		universo = run.universo,
		andar = run.andar,
		andares = Incursoes.ANDARES,
		vidas = run.vidas,
		nucleos = feitos,
		nucleosTotal = total,
		sombras = #run.inimigos,
		fenda = run.fenda ~= nil,
		avanco = if run.avancoEm then math.max(0, math.ceil(run.avancoEm - os.clock())) else nil,
		guardiao = if g
			then {
				nome = Incursoes.porId[run.universo].guardiao,
				vida = math.ceil(g.vida),
				vidaMax = g.vidaMax,
			}
			else nil,
	})
end

local function passoRun(run: Run, dt: number)
	local mapa = run.mapa
	if run.estado ~= "andar" or not mapa then
		return
	end
	local agora = os.clock()
	local alvos: { Inimigos.Alvo } = {}
	local vivos: { [Player]: BasePart } = {}
	for player in run.membros do
		local r, h = corpo(player)
		if r and h and h.Health > 0 and (r.Position - mapa.origem.Position).Magnitude < 200 then
			table.insert(alvos, { raiz = r, humanoide = h })
			vivos[player] = r
			if r.Position.Y < mapa.origem.Position.Y - 30 then
				levar(player, mapa.spawn) -- caiu do andar
			end
		end
	end

	local centro = mapa.origem.Position
	Inimigos.passo(run.inimigos, dt, alvos, centro, mapa.raio, function(pos)
		novoInimigo(run, pos, false)
	end)

	-- reforços enquanto houver Núcleos para purificar
	if not run.cfg.guardiao and not run.fenda then
		if
			#run.inimigos < run.cfg.sombras
			and run.restantes > 0
			and agora >= run.proximoReforco
		then
			local pontos = mapa.pontosSombra
			novoInimigo(run, pontos[math.random(1, #pontos)], false)
			run.restantes -= 1
			run.proximoReforco = agora + ESPERA_REFORCO
		end
	end

	-- purificação dos Núcleos
	local todos = #mapa.nucleos > 0
	for _, nucleo in mapa.nucleos do
		local prog = nucleo:GetAttribute("Progresso") or 0
		if prog < 1 then
			local pos = nucleo.Position
			local soma, n = 0, 0
			for player, r in vivos do
				if
					Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude
					<= RAIO_CANAL
				then
					soma += Incursoes.canal(progressoDe(player), run.membros[player].ressonancia)
					n += 1
				end
			end
			local contestado = false
			for _, i in run.inimigos do
				if Vector3.new(i.pos.X - pos.X, 0, i.pos.Z - pos.Z).Magnitude <= RAIO_CONTESTO then
					contestado = true
					break
				end
			end
			local novo = prog
			if contestado then
				novo = math.max(prog - dt * 0.03, 0)
			elseif n > 0 then
				novo = math.min(prog + dt * soma * Incursoes.bonusGrupo(n) / n, 1)
			end
			if math.abs(novo - prog) > 0.004 or (novo >= 1 and prog < 1) then
				nucleo:SetAttribute("Progresso", novo)
				nucleo:SetAttribute("Contestado", contestado)
				if novo >= 1 then
					paraRun(run, { tipo = "aviso", texto = "Núcleo purificado!" })
				end
			end
			if novo < 1 then
				todos = false
			end
		end
	end
	if todos and not run.cfg.guardiao and not run.fenda then
		abrirFenda(run)
	end

	-- fenda: o primeiro que entra puxa todo o grupo para o próximo andar
	local fenda = run.fenda
	if fenda and not run.avancoEm then
		for _, r in vivos do
			if
				Vector3.new(r.Position.X - fenda.Position.X, 0, r.Position.Z - fenda.Position.Z).Magnitude
				<= RAIO_FENDA
			then
				run.avancoEm = agora + ESPERA_AVANCO
				paraRun(run, { tipo = "aviso", texto = "Descendo para o próximo andar..." })
				break
			end
		end
	end
	if run.avancoEm and agora >= run.avancoEm then
		iniciarAndar(run, run.andar + 1)
		return
	end

	-- Guardião derrotado: vitória
	local g = run.guardiao
	if g and g.vida <= 0 then
		run.andaresConcluidos = Incursoes.ANDARES
		paraRun(run, { tipo = "aviso", texto = Incursoes.porId[run.universo].guardiao .. " caiu!" })
		terminar(run, true)
		return
	end

	if agora - run.ultimoEnvio >= 0.25 then
		run.ultimoEnvio = agora
		enviarEstado(run)
	end
end

-- ===================================================================== fila

local function enviarFila(universo: string)
	local f = filas[universo]
	if not f then
		return
	end
	for _, player in f.jogadores do
		enviar(player, {
			tipo = "fila",
			universo = universo,
			jogadores = #f.jogadores,
			falta = if f.fim then math.max(0, math.ceil(f.fim - os.clock())) else nil,
		})
	end
end

local function tirarDaFila(player: Player)
	local u = naFila[player]
	if not u then
		return
	end
	naFila[player] = nil
	local f = filas[u]
	if f then
		local i = table.find(f.jogadores, player)
		if i then
			table.remove(f.jogadores, i)
		end
		if #f.jogadores == 0 then
			filas[u] = nil
		end
	end
	enviar(player, { tipo = "fila", universo = nil })
	enviarFila(u)
end

local function passoFilas()
	local b = bastiao()
	for universo, f in filas do
		-- quem saiu de perto do Bastião sai da fila
		for k = #f.jogadores, 1, -1 do
			local p = f.jogadores[k]
			if not p.Parent or not perto(p, b, DISTANCIA_BASTIAO + 10) or daRun[p] then
				tirarDaFila(p)
			end
		end
		f = filas[universo]
		if f and #f.jogadores > 0 then
			f.fim = f.fim or (os.clock() + Incursoes.ESPERA_FILA)
			if os.clock() >= f.fim or #f.jogadores >= Incursoes.MAX_JOGADORES then
				local grupo = table.clone(f.jogadores)
				if lancar(universo, grupo) then
					for _, p in grupo do
						naFila[p] = nil
					end
					filas[universo] = nil
				else
					for _, p in f.jogadores do
						enviar(p, {
							tipo = "aviso",
							texto = "Todas as fendas estão ocupadas. Esperando uma abrir...",
						})
					end
					f.fim = os.clock() + 5
				end
			else
				enviarFila(universo)
			end
		end
	end
end

-- ===================================================================== ações

local function acaoFila(player: Player, universo: any): (boolean, string?)
	if universo == "" or universo == nil then
		tirarDaFila(player)
		return true, "Você saiu da fila."
	end
	if type(universo) ~= "string" or not Incursoes.porId[universo] then
		return false, "Universo inválido."
	end
	if daRun[player] then
		return false, "Você já está numa incursão."
	end
	if not perto(player, bastiao(), DISTANCIA_BASTIAO) then
		return false, "Vá até o Bastião das Incursões para entrar na fila."
	end
	if not Incursoes.liberado(progressoDe(player), universo) then
		return false, "Conclua o universo anterior para abrir este."
	end
	if naFila[player] == universo then
		return true, nil
	end
	tirarDaFila(player)
	local f = filas[universo]
	if not f then
		f = { jogadores = {}, fim = nil }
		filas[universo] = f
	end
	if #f.jogadores >= Incursoes.MAX_JOGADORES then
		return false, "Esta fila está cheia. Espere a próxima partida."
	end
	table.insert(f.jogadores, player)
	naFila[player] = universo
	enviarFila(universo)
	return true, "Na fila: " .. Incursoes.porId[universo].nome
end

local function acaoSair(player: Player): (boolean, string?)
	local run = daRun[player]
	if run then
		sair(run, player, "saiu")
		return true, nil
	end
	if naFila[player] then
		tirarDaFila(player)
		return true, "Você saiu da fila."
	end
	return false, nil
end

local function acaoPulso(player: Player): (boolean, string?)
	local run = daRun[player]
	if not run or run.estado ~= "andar" then
		return false, nil
	end
	local m = run.membros[player]
	local agora = os.clock()
	if not m or agora < m.proximoPulso then
		return false, nil
	end
	local r, h = corpo(player)
	if not r or not h or h.Health <= 0 then
		return false, nil
	end
	m.proximoPulso = agora + Incursoes.PULSO_ESPERA
	local p = progressoDe(player)
	local dano = Incursoes.danoPulso(p, m.ressonancia)
	local raio = Incursoes.raioPulso(p)
	for _, i in table.clone(run.inimigos) do
		local d = Vector3.new(i.pos.X - r.Position.X, 0, i.pos.Z - r.Position.Z).Magnitude
		if d <= raio + i.raio then
			Inimigos.ferir(i, dano)
		end
	end
	paraRun(run, { tipo = "pulso", origem = r.Position, raio = raio, userId = player.UserId })
	return true, nil
end

local function acaoReliquia(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" or not Incursoes.reliquiaPorId[id] then
		return false, "Relíquia inválida."
	end
	return Dados.alterar(player, function(estado)
		if type(estado.incursoes) ~= "table" then
			estado.incursoes = Incursoes.padrao()
		end
		local inc = estado.incursoes
		inc.reliquias = inc.reliquias or {}
		local custo = Incursoes.custo(inc, id)
		if not custo then
			return false, "Esta relíquia já está no nível máximo."
		end
		if (inc.fragmentos or 0) < custo then
			return false, string.format("Faltam %d fragmentos.", custo - (inc.fragmentos or 0))
		end
		inc.fragmentos -= custo
		inc.reliquias[id] = Incursoes.nivel(inc, id) + 1
		return true, Incursoes.reliquiaPorId[id].nome .. " melhorada!"
	end)
end

function Servico.iniciar()
	raiz = Instance.new("Folder")
	raiz.Name = "Incursoes"
	raiz.Parent = Workspace

	Acoes.registrar("IncursaoFila", acaoFila)
	Acoes.registrar("IncursaoSair", acaoSair)
	Acoes.registrar("IncursaoPulso", acaoPulso)
	Acoes.registrar("IncursaoReliquia", acaoReliquia)

	Players.PlayerRemoving:Connect(function(player)
		tirarDaFila(player)
		local run = daRun[player]
		if run then
			sair(run, player, "desconectou")
		end
	end)

	local acumulado = 0
	RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if acumulado < PASSO then
			return
		end
		local passo = math.min(acumulado, 0.2)
		acumulado = 0
		for _, run in runs do
			local ok, erro = pcall(passoRun, run, passo)
			if not ok then
				warn("[Incursoes] erro na partida " .. run.slot .. ": " .. tostring(erro))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, erro = pcall(passoFilas)
			if not ok then
				warn("[Incursoes] erro na fila: " .. tostring(erro))
			end
		end
	end)
end

return Servico
