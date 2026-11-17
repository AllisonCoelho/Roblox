-- Incursões no servidor: fila no Bastião, partidas (cada grupo num espaço só dele, longe do Nexo),
-- andares, Núcleos, Sombras, Guardião, vidas do grupo e recompensas salvas no perfil.
-- O servidor decide tudo; o cliente só pede (fila, Pulso, sair, relíquia) e recebe o estado pelo
-- remote "Incursao". Nada aqui toca no sorteio de auras: a aura mais rara só vira Ressonância.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Artefatos = require(Shared.Dados.Artefatos)
local Auras = require(Shared.Dados.Auras)
local Incursoes = require(Shared.Dados.Incursoes)
local Run = require(Shared.Dados.IncursoesRun)
local Desafios = require(Shared.Dados.IncursoesDesafios)
local Loot = require(Shared.Dados.LootIncursoes)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent:WaitForChild("Servicos")
local Acoes = require(Servicos:WaitForChild("Acoes"))
local Dados = require(Servicos:WaitForChild("Dados"))
local TemporadaServico = require(Servicos:WaitForChild("Temporada"))
local Combate = require(script.Parent.Combate)
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
	recompensas: Loot.Registro,
	vidaBase: number, -- vida máxima sem as Bênçãos
	vidaMax: number,
	bencaos: { [string]: boolean }, -- Bênçãos da Fenda desta run
	mods: { [string]: number },
	ofertas: { string }?, -- 3 Bênçãos esperando escolha
	sequencia: number, -- abates seguidos
	ultimoAbate: number,
	abates: number, -- nesta run (pontuação da Fenda do Dia)
	desafios: { [string]: number }, -- progresso dos desafios semanais ainda não salvo
	melhorSequencia: number,
	-- reviver colega: abatido espera um aliado perto (ou levanta sozinho depois de um tempo)
	marcaPos: Vector3?,
	abatido: boolean,
	abatidoAte: number,
	reviverProg: number,
	velocidadeAntes: number?,
	rotulo: BillboardGui?,
	ressonancia: number,
	proximoPulso: number,
	reviver: boolean,
	proximoResgate: number, -- vivo fora do andar (respawn no lobby): leva de volta
	conexoes: { RBXScriptConnection },
}

type Run = {
	slot: number,
	universo: string,
	andar: number,
	tipos: { string }, -- tipo de cada andar, sorteado no início (IncursoesRun)
	preparo: Run.Preparo, -- Marcas da Fenda e Pesadelo, escolhidos antes de entrar
	diaria: boolean, -- Fenda do Dia (mesma run para todos no dia)
	inicioRun: number,
	notasS: number,
	tipoAndar: string,
	inicioAndar: number,
	quedasAndar: number,
	notaAndar: string?,
	hordaFim: number?,
	proximaElite: number,
	elites: { Inimigos.Inimigo },
	escolta: { nucleo: BasePart, de: Vector3, ate: Vector3, prog: number }?,
	cofre: BasePart?,
	cofreProg: number,
	cofreAberto: boolean,
	andaresConcluidos: number,
	vidas: number,
	estado: string, -- "andar" | "fim"
	membros: { [Player]: Membro },
	pasta: Folder,
	origem: CFrame,
	seed: number,
	teste: boolean,
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
local filas: { [string]: { jogadores: { Player }, fim: number?, preparo: Run.Preparo } } = {}
local FILA_DIARIA = "diaria" -- chave da fila da Fenda do Dia
-- Ranking da Fenda do Dia neste servidor (zera quando o dia muda)
local rankingDia: { dia: number, pontos: { [number]: { nome: string, pontos: number } } } =
	{ dia = -1, pontos = {} }
local naFila: { [Player]: string } = {}
local embarques: { [Player]: { personagem: Model, destino: CFrame } } = {}
local raiz: Folder
local rng = Random.new()
local function sorteio(): number
	return rng:NextNumber()
end

local function evento(): RemoteEvent
	return Remotos.evento("Incursao")
end

local function enviar(player: Player, dados: { [string]: any })
	if player.Parent == Players then
		evento():FireClient(player, dados)
	end
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
	local r, h = corpo(player)
	return r ~= nil and h ~= nil and h.Health > 0 and (r.Position - ponto).Magnitude <= raioMax
end

local function levar(player: Player, cf: CFrame)
	local personagem = player.Character
	if not personagem or player.Parent ~= Players then
		return
	end
	local anterior = embarques[player]
	if anterior and anterior.personagem == personagem and anterior.destino == cf then
		return
	end
	local pedido = { personagem = personagem, destino = cf }
	embarques[player] = pedido
	-- O streaming não deve suspender a troca de andar nem o laço de combate.
	task.spawn(function()
		if Workspace.StreamingEnabled then
			pcall(player.RequestStreamAroundAsync, player, cf.Position, 2)
		end
		if embarques[player] ~= pedido then
			return
		end
		embarques[player] = nil
		if player.Parent ~= Players or player.Character ~= personagem then
			return
		end
		local r, h = corpo(player)
		if r and h and h.Health > 0 then
			personagem:PivotTo(cf)
			r.AssemblyLinearVelocity = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end
	end)
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

-- Cor do kit genérico de combate: a cor principal da aura equipada
local function corDe(player: Player): Color3
	local estado = Dados.de(player)
	local aura = if estado and estado.equipada then Auras.porId[estado.equipada] else nil
	return if aura then Color3.fromHex(aura.cores[1]) else Color3.fromHex("C9B8FF")
end

local function ressonanciaDe(player: Player): number
	local estado = Dados.de(player)
	local melhor = if estado then Auras.melhorDe(estado.auras) else nil
	return Incursoes.ressonancia(if melhor then melhor.chance else nil)
end

-- ===================================================================== recompensas

-- Desafio semanal: acumula na memória e salva junto com o fim do andar/partida
local function contarDesafio(membro: Membro, id: string, valor: number)
	membro.desafios[id] = (membro.desafios[id] or 0) + valor
end

local function salvarDesafios(player: Player, run: Run, membro: Membro)
	if Dados.emTeste(player) ~= run.teste or not Dados.podeProgredir(player) then
		return
	end
	local pendentes = membro.desafios
	if next(pendentes) == nil and membro.melhorSequencia < 2 then
		return
	end
	membro.desafios = {}
	local concluidos = {}
	Dados.alterar(player, function(estado)
		if type(estado.incursoes) ~= "table" then
			estado.incursoes = Incursoes.padrao()
		end
		local inc = estado.incursoes
		local semana = Desafios.semana(os.time())
		local s = Desafios.semanaDe(inc, semana)
		inc.semana = s
		local function aplicar(id: string, valor: number, maximo: boolean?)
			local premio = Desafios.progredir(s, semana, id, valor, maximo)
			if premio > 0 then
				inc.fragmentos = (inc.fragmentos or 0) + premio
				table.insert(concluidos, Desafios.desafioPorId[id].nome .. " (+" .. premio .. ")")
			end
		end
		for id, valor in pendentes do
			aplicar(id, valor)
		end
		aplicar("sequencia", membro.melhorSequencia, true)
		return true
	end)
	for _, texto in concluidos do
		enviar(player, { tipo = "aviso", texto = "DESAFIO CONCLUÍDO: " .. texto })
	end
end

local function premiar(player: Player, run: Run, membro: Membro, concluiu: boolean, venceu: boolean)
	if Dados.emTeste(player) ~= run.teste or not Dados.podeProgredir(player) then
		return
	end
	local itensAndar = nil
	local ganho = 0
	local ok = Dados.alterar(player, function(estado)
		if type(estado.incursoes) ~= "table" then
			estado.incursoes = Incursoes.padrao()
		end
		local inc = estado.incursoes
		inc.melhor = inc.melhor or {}
		inc.concluidas = inc.concluidas or {}
		local u = run.universo
		if concluiu then
			itensAndar = Loot.creditar(
				membro.recompensas,
				estado.inventario.itens,
				u,
				run.andar,
				function()
					return rng:NextNumber()
				end
			)
			if itensAndar == nil then
				return false
			end
			local mult = (Run.MULT_NOTA[run.notaAndar or "B"] or 1)
				* (1 + (membro.mods.fragmentos or 0))
				* Run.multPreparo(run.preparo)
			ganho = math.floor(Incursoes.fragmentosAndar(u, run.andar) * mult + 0.5)
		end
		if venceu then
			ganho += Incursoes.bonusVitoria(u, (inc.concluidas[u] or 0) == 0) * (if run.preparo.pesadelo
				then Run.PESADELO.recompensa
				else 1)
			inc.concluidas[u] = (inc.concluidas[u] or 0) + 1
		end
		inc.fragmentos = (inc.fragmentos or 0) + ganho
		inc.melhor[u] = math.max(inc.melhor[u] or 0, run.andar)
		membro.recompensas.fragmentos += ganho
		if concluiu then
			TemporadaServico.creditar(player, estado, "andar")
		end
		if venceu then
			TemporadaServico.creditar(player, estado, "vitoria")
		end
		return true
	end)
	if ok and itensAndar and player.Parent then
		enviar(player, { tipo = "loot", itens = itensAndar, fragmentos = ganho })
	end
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
	embarques[player] = nil
	Combate.sair(player)
end

-- Um jogador sai da partida (saiu, caiu sem vidas ou desconectou): leva o que já ganhou
local function sair(run: Run, player: Player, motivo: string)
	local membro = run.membros[player]
	if not membro then
		return
	end
	if run.estado == "fim" then
		-- A conclusão já registrou a recompensa deste jogador.
		if motivo == "desconectou" then
			desligar(player, run)
		end
		return
	end
	premiar(player, run, membro, false, false)
	desligar(player, run)
	if motivo ~= "desconectou" then
		definirVida(player, Incursoes.VIDA_BASE)
		voltaAoBastiao(player)
		enviar(player, {
			tipo = "fim",
			universo = run.universo,
			venceu = false,
			andares = run.andaresConcluidos,
			fragmentos = membro.recompensas.fragmentos,
			itens = membro.recompensas.itens,
			motivo = motivo,
		})
	end
	if next(run.membros) == nil and run.estado ~= "fim" then
		run.estado = "fim"
		encerrar(run)
	end
end

-- Fenda do Dia: pontuação, recorde pessoal, recompensa da 1ª vitória do dia e ranking do servidor
local function rankingAtual(): { { nome: string, pontos: number } }
	local dia = Desafios.dia(os.time())
	if rankingDia.dia ~= dia then
		rankingDia = { dia = dia, pontos = {} }
	end
	local lista = {}
	for _, r in rankingDia.pontos do
		table.insert(lista, r)
	end
	table.sort(lista, function(a, b)
		return a.pontos > b.pontos
	end)
	local top = {}
	for k = 1, math.min(10, #lista) do
		top[k] = lista[k]
	end
	return top
end

local function registrarDiaria(player: Player, run: Run, membro: Membro, venceu: boolean)
	local pontos = Desafios.pontuacao(
		run.andaresConcluidos,
		venceu,
		run.notasS,
		membro.abates,
		os.clock() - run.inicioRun
	)
	local dia = Desafios.dia(os.time())
	rankingAtual()
	local atual = rankingDia.pontos[player.UserId]
	if not atual or pontos > atual.pontos then
		rankingDia.pontos[player.UserId] = { nome = player.DisplayName, pontos = pontos }
	end
	local melhor, bonus = pontos, 0
	if Dados.emTeste(player) == run.teste and Dados.podeProgredir(player) then
		Dados.alterar(player, function(estado)
			if type(estado.incursoes) ~= "table" then
				estado.incursoes = Incursoes.padrao()
			end
			local inc = estado.incursoes
			local d = inc.diaria
			if type(d) ~= "table" or d.dia ~= dia then
				d = { dia = dia, melhor = 0, vitoria = false }
			end
			d.melhor = math.max(d.melhor or 0, pontos)
			melhor = d.melhor
			if venceu and not d.vitoria then
				d.vitoria = true
				bonus = Desafios.recompensaDia(Incursoes.porId[run.universo].nivel)
				inc.fragmentos = (inc.fragmentos or 0) + bonus
			end
			inc.diaria = d
			return true
		end)
	end
	enviar(player, {
		tipo = "diaria",
		pontos = pontos,
		melhor = melhor,
		bonus = bonus,
		ranking = rankingAtual(),
	})
end

local function terminar(run: Run, venceu: boolean)
	if run.estado == "fim" then
		return
	end
	run.estado = "fim"
	for _, i in run.inimigos do
		Inimigos.dissolver(i)
	end
	local lista = {}
	for player in run.membros do
		table.insert(lista, player)
	end
	for _, player in lista do
		local membro = run.membros[player]
		premiar(player, run, membro, venceu, venceu)
		if venceu then
			contarDesafio(membro, "guardioes", 1)
			if run.preparo.pesadelo then
				contarDesafio(membro, "pesadelo", 1)
			end
			local marcas = 0
			for _ in run.preparo.marcas do
				marcas += 1
			end
			if marcas >= 2 then
				contarDesafio(membro, "marcas", 1)
			end
		end
		salvarDesafios(player, run, membro)
		if run.diaria then
			registrarDiaria(player, run, membro, venceu)
		end
		enviar(player, {
			tipo = "fim",
			universo = run.universo,
			venceu = venceu,
			andares = run.andaresConcluidos,
			fragmentos = membro.recompensas.fragmentos,
			itens = membro.recompensas.itens,
			motivo = if venceu then "vitoria" else "derrota",
		})
	end
	task.delay(ESPERA_VOLTA, function()
		for k, player in lista do
			if daRun[player] == run then
				desligar(player, run)
				definirVida(player, Incursoes.VIDA_BASE)
				voltaAoBastiao(player, k)
			end
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

-- Pesadelo e Marcas mexem nos números do andar
local function ajustarCfg(run: Run, cfg: Incursoes.Andar): Incursoes.Andar
	local p = run.preparo
	if p.pesadelo then
		local f = Run.PESADELO.forca
		cfg.vidaSombra = math.floor(cfg.vidaSombra * f + 0.5)
		cfg.danoSombra = math.floor(cfg.danoSombra * f + 0.5)
		cfg.vidaGuardiao = math.floor(cfg.vidaGuardiao * f + 0.5)
		cfg.velocidadeSombra *= Run.PESADELO.velocidade
	end
	if p.marcas.densas then
		cfg.sombras = math.ceil(cfg.sombras * 1.4)
		cfg.reforcos = math.ceil(cfg.reforcos * 1.4)
	end
	if p.marcas.velozes then
		cfg.velocidadeSombra *= 1.3
	end
	return cfg
end

local function novoInimigo(
	run: Run,
	pos: Vector3,
	guardiao: boolean,
	tipo: string?,
	afixos: { string }?
): Inimigos.Inimigo?
	local mapa = run.mapa
	if not mapa then
		return nil
	end
	local t = if guardiao then nil else (tipo or Run.sortearArquetipo(run.andar, sorteio))
	local i = Inimigos.novo(mapa.pasta, run.universo, pos, run.cfg, guardiao, t, afixos)
	table.insert(run.inimigos, i)
	return i
end

-- Elite com 1–2 afixos (coroa, mais vida, loot de sequência)
local function novaElite(run: Run, pos: Vector3, anunciar: boolean): Inimigos.Inimigo?
	local afixos = Run.sortearAfixos(run.andar, sorteio)
	if run.preparo.pesadelo or run.preparo.marcas.coroa then
		-- Pesadelo/Coroa Dupla: mais um afixo
		for _, id in { "veloz", "blindado", "vampirico", "explosivo" } do
			if not table.find(afixos, id) and #afixos < 3 and sorteio() < 0.5 then
				table.insert(afixos, id)
				break
			end
		end
	end
	local i = novoInimigo(run, pos, false, Run.sortearArquetipo(run.andar, sorteio), afixos)
	if i then
		table.insert(run.elites, i)
		if anunciar then
			local nomes = {}
			for _, id in afixos do
				table.insert(nomes, Run.AFIXOS[id].nome)
			end
			paraRun(run, { tipo = "elite", texto = "ELITE · " .. table.concat(nomes, " · ") })
		end
	end
	return i
end

local function elitesVivas(run: Run): number
	local n = 0
	for _, i in run.elites do
		if i.vida > 0 then
			n += 1
		end
	end
	return n
end

-- ===================================================================== reviver colega

local function rotuloAbatido(player: Player, texto: string, membro: Membro)
	local cabeca = player.Character and player.Character:FindFirstChild("Head")
	if not cabeca then
		return
	end
	local bb = membro.rotulo
	if not bb or bb.Parent ~= cabeca then
		if bb then
			bb:Destroy()
		end
		bb = Instance.new("BillboardGui")
		bb.Name = "Abatido"
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(260, 54)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		local t = Instance.new("TextLabel")
		t.Name = "Texto"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.fromHex("FF6B6B")
		t.TextStrokeTransparency = 0.2
		t.Parent = bb
		bb.Parent = cabeca
		membro.rotulo = bb
	end
	local t = bb:FindFirstChild("Texto") :: TextLabel?
	if t then
		t.Text = texto
	end
end

local function reerguer(run: Run, player: Player, membro: Membro, ajudado: boolean)
	if not membro.abatido then
		return
	end
	membro.abatido = false
	membro.reviverProg = 0
	if membro.rotulo then
		membro.rotulo:Destroy()
		membro.rotulo = nil
	end
	local _, h = corpo(player)
	if h then
		h.WalkSpeed = membro.velocidadeAntes or 16
		h.JumpHeight = 7.2
		h.JumpPower = 50
		if h.Health > 0 then
			h.Health = h.MaxHealth * (if ajudado then Desafios.REVIVER_VIDA else 1)
		end
	end
	membro.velocidadeAntes = nil
	paraRun(run, {
		tipo = "aviso",
		texto = if ajudado
			then player.DisplayName .. " foi reerguido!"
			else player.DisplayName .. " se levantou.",
	})
end

-- Renasceu: volta onde caiu, abatido, até um aliado chegar perto (ou o tempo acabar)
local function entrarAbatido(run: Run, player: Player, membro: Membro)
	local mapa = run.mapa
	if not mapa then
		return
	end
	membro.reviver = false
	definirVida(player, membro.vidaMax)
	local destino = mapa.spawn
	local pos = membro.marcaPos
	if pos and (pos - mapa.origem.Position).Magnitude < mapa.raio then
		destino = CFrame.new(pos + Vector3.new(0, 3, 0))
	end
	levar(player, destino)
	local sozinho = ativos(run) <= 1
	if sozinho then
		return -- sozinho não há quem reviva: volta direto ao combate
	end
	local _, h = corpo(player)
	membro.abatido = true
	membro.abatidoAte = os.clock() + Desafios.ABATIDO_ESPERA
	membro.reviverProg = 0
	if h then
		membro.velocidadeAntes = h.WalkSpeed
		h.WalkSpeed = 0
		h.JumpHeight = 0
		h.JumpPower = 0
	end
	enviar(player, {
		tipo = "aviso",
		texto = "ABATIDO: um aliado precisa ficar perto de você para te reerguer.",
	})
end

-- Recalcula os efeitos das Bênçãos (combate, vida máxima)
local function aplicarBencaos(player: Player, membro: Membro, curar: boolean)
	membro.mods = Run.modificadores(membro.bencaos)
	Combate.definirModificadores(player, membro.mods)
	membro.vidaMax =
		math.max(20, math.floor(membro.vidaBase * (1 + (membro.mods.vidaMax or 0)) + 0.5))
	local _, h = corpo(player)
	if h and h.Health > 0 then
		local fracao = h.Health / math.max(h.MaxHealth, 1)
		h.MaxHealth = membro.vidaMax
		h.Health = if curar then membro.vidaMax else math.max(1, membro.vidaMax * fracao)
	end
end

-- Registra a Bênção escolhida (ou sorteada) e avisa o jogador
local function escolherBencao(player: Player, membro: Membro, id: string)
	membro.ofertas = nil
	membro.bencaos[id] = true
	aplicarBencaos(player, membro, id == "vigor")
	local lista = {}
	for bid in membro.bencaos do
		table.insert(lista, bid)
	end
	enviar(player, { tipo = "bencaoAtiva", id = id, lista = lista })
end

local function iniciarAndar(run: Run, n: number)
	limparAndar(run)
	run.andar = n
	run.cfg = ajustarCfg(run, Incursoes.andar(run.universo, n, ativos(run)))
	local tipo = if run.cfg.guardiao then "guardiao" else (run.tipos[n] or "purificacao")
	run.tipoAndar = tipo
	run.inicioAndar = os.clock()
	run.quedasAndar = 0
	run.notaAndar = nil
	run.hordaFim = nil
	run.proximaElite = os.clock() + 14
	run.elites = {}
	run.escolta = nil
	run.cofre = nil
	run.cofreProg = 0
	run.cofreAberto = false
	-- Bênção pendente que ninguém escolheu: sorteia uma para não perder
	for player, membro in run.membros do
		local ofertas = membro.ofertas
		if ofertas and #ofertas > 0 then
			escolherBencao(player, membro, ofertas[rng:NextInteger(1, #ofertas)])
		end
		if membro.abatido then
			reerguer(run, player, membro, false)
		end
	end
	local nucleos = if tipo == "purificacao" or tipo == "guardiao"
		then nil
		elseif tipo == "escolta" then 1
		else 0
	run.mapa = Mapa.construir(run.pasta, run.universo, n, run.origem, run.seed + n * 101, nucleos)
	local mapa = run.mapa :: Mapa.Andar
	run.restantes = run.cfg.sombras + run.cfg.reforcos
	if tipo == "horda" then
		run.hordaFim = os.clock() + Run.HORDA_DURACAO + 5 * n
	elseif tipo == "escolta" then
		run.restantes = math.huge -- reforços até o Núcleo chegar
		local nucleo = mapa.nucleos[1]
		if nucleo then
			local de = mapa.spawn.Position:Lerp(mapa.origem.Position, 0.25)
			de = Vector3.new(de.X, mapa.origem.Position.Y, de.Z)
			nucleo:PivotTo(CFrame.new(de))
			nucleo:SetAttribute("Movel", true) -- o visual do cliente acompanha o Núcleo andando
			run.escolta = { nucleo = nucleo, de = de, ate = mapa.saida.Position, prog = 0 }
		end
	end
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
	elseif tipo == "caca" then
		-- Caçada: Elites espalhadas pelo andar
		local quantas = 3
			+ math.floor((ativos(run) - 1) / 2)
			+ (if run.preparo.marcas.coroa then 2 else 0)
		local pontos = mapa.pontosSombra
		for k = 1, quantas do
			novaElite(run, pontos[(k * 3 - 1) % #pontos + 1], false)
		end
		run.restantes = math.ceil(run.cfg.reforcos / 2)
	end
	local k = 0
	for player, membro in run.membros do
		k += 1
		local _, h = corpo(player)
		if h and h.Health > 0 then
			membro.reviver = false
			levar(player, mapa.spawn * CFrame.new((k - 2.5) * 3, 0, 0))
		end
	end
	local u = Incursoes.porId[run.universo]
	local info = Run.TIPOS[tipo]
	paraRun(run, {
		tipo = "andar",
		universo = run.universo,
		andar = n,
		andares = Incursoes.ANDARES,
		titulo = if run.cfg.guardiao then u.guardiao else nil,
		tipoAndar = tipo,
		nomeAndar = if info then info.nome else "Guardião",
		descricao = if info then info.descricao else "Derrubem o Guardião do universo.",
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
	-- nota do andar (tempo e quedas): multiplica os Fragmentos
	local tempo = os.clock() - run.inicioAndar
	run.notaAndar = Run.nota(run.tipoAndar, tempo, run.quedasAndar)
	paraRun(run, {
		tipo = "nota",
		nota = run.notaAndar,
		tempo = math.floor(tempo),
		quedas = run.quedasAndar,
		mult = Run.MULT_NOTA[run.notaAndar],
	})
	if run.notaAndar == "S" then
		run.notasS += 1
	end
	for player, membro in run.membros do
		premiar(player, run, membro, true, false)
		if run.notaAndar == "S" then
			contarDesafio(membro, "notasS", 1)
		end
		if run.tipoAndar == "horda" then
			contarDesafio(membro, "hordas", 1)
		end
		salvarDesafios(player, run, membro)
	end
	if run.tipoAndar ~= "cofre" then
		for _, i in run.inimigos do
			Inimigos.dissolver(i) -- as Sombras se desfazem quando o andar é concluído
		end
	end
	-- Bênçãos da Fenda: cada um escolhe 1 de 3 para o resto da run
	if run.andar < Incursoes.ANDARES then
		for player, membro in run.membros do
			local ofertas = Run.ofertas(membro.bencaos, sorteio)
			membro.ofertas = ofertas
			local cartas = {}
			for _, id in ofertas do
				local b = Run.bencaoPorId[id]
				table.insert(
					cartas,
					{ id = id, nome = b.nome, descricao = b.descricao, raridade = b.raridade }
				)
			end
			enviar(player, { tipo = "bencaos", cartas = cartas })
		end
	end
	paraRun(run, {
		tipo = "aviso",
		texto = if run.tipoAndar == "cofre"
			then "A fenda está aberta. Abram o Cofre (opcional) ou desçam."
			else "Andar concluído! Escolha uma Bênção e entre na fenda.",
	})
end

local function aoMorrer(run: Run, player: Player)
	if run.estado == "fim" or not run.membros[player] then
		return
	end
	run.quedasAndar += 1
	local membroCaido = run.membros[player]
	if membroCaido then
		membroCaido.sequencia = 0
	end
	if membroCaido then
		local r = corpo(player)
		membroCaido.marcaPos = if r then r.Position else nil
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
	if not h or run.estado == "fim" or daRun[player] ~= run or player.Character ~= personagem then
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
		personagem:WaitForChild("HumanoidRootPart", 10)
		local mapa = run.mapa
		if
			not mapa
			or daRun[player] ~= run
			or run.estado == "fim"
			or player.Character ~= personagem
		then
			return
		end
		entrarAbatido(run, player, m)
	end
end

local function lancar(
	universo: string,
	jogadores: { Player },
	andar: number,
	teste: boolean,
	preparo: Run.Preparo?,
	diaria: boolean?
): boolean
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
		-- Fenda do Dia: mesma sequência de andares e mesmos mapas para todos no dia
		tipos = if diaria
			then Run.sortearAndares(
				Incursoes.ANDARES,
				Desafios.gerador(Desafios.fendaDoDia(Desafios.dia(os.time())).semente)
			)
			else Run.sortearAndares(Incursoes.ANDARES, sorteio),
		preparo = preparo or Run.preparo(nil),
		diaria = diaria == true,
		inicioRun = os.clock(),
		notasS = 0,
		tipoAndar = "purificacao",
		inicioAndar = os.clock(),
		quedasAndar = 0,
		notaAndar = nil,
		hordaFim = nil,
		proximaElite = 0,
		elites = {},
		escolta = nil,
		cofre = nil,
		cofreProg = 0,
		cofreAberto = false,
		andaresConcluidos = 0,
		vidas = if preparo and preparo.marcas.semVidas then 0 else Incursoes.vidas(#jogadores),
		estado = "andar",
		membros = {},
		pasta = pasta,
		-- cada partida num espaço só dela, longe do Nexo (que termina no raio 238)
		origem = CFrame.new(5000 + slot * 400, 600, 0),
		seed = if diaria
			then Desafios.fendaDoDia(Desafios.dia(os.time())).semente
			else rng:NextInteger(1, 2 ^ 30),
		teste = teste,
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
		local estado = Dados.de(player)
		local equipado = if estado then estado.inventario.equipados.artefato else nil
		local vidaMax = math.floor(
			Incursoes.vidaMax(progressoDe(player)) * (1 + Artefatos.bonusVida(equipado)) + 0.5
		)
		if preparo and preparo.marcas.vidro then
			vidaMax = math.floor(vidaMax * 0.7 + 0.5)
		end
		local m: Membro = {
			vidaBase = vidaMax,
			vidaMax = vidaMax,
			bencaos = {},
			mods = {},
			ofertas = nil,
			sequencia = 0,
			ultimoAbate = 0,
			abates = 0,
			desafios = {},
			melhorSequencia = 0,
			marcaPos = nil,
			abatido = false,
			abatidoAte = 0,
			reviverProg = 0,
			velocidadeAntes = nil,
			rotulo = nil,
			recompensas = Loot.novo(),
			ressonancia = ressonanciaDe(player),
			proximoPulso = 0,
			reviver = false,
			proximoResgate = 0,
			conexoes = {},
		}
		run.membros[player] = m
		daRun[player] = run
		Combate.entrar(
			player,
			if player.Character then player.Character:GetAttribute("AuraVfx") else nil,
			corDe(player)
		)
		table.insert(
			m.conexoes,
			player.CharacterAdded:Connect(function(personagem)
				ligarPersonagem(run, player, personagem)
			end)
		)
		if player.Character then
			task.spawn(ligarPersonagem, run, player, player.Character)
		end
		definirVida(player, m.vidaMax)
	end
	paraRun(run, {
		tipo = "inicio",
		preparo = Run.descreverPreparo(run.preparo),
		universo = universo,
		slot = run.slot,
		vidas = run.vidas,
		jogadores = #jogadores,
	})
	iniciarAndar(run, andar)
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
		tipoAndar = run.tipoAndar,
		hordaResta = if run.hordaFim and not run.fenda
			then math.max(0, math.ceil(run.hordaFim - os.clock()))
			else nil,
		elites = elitesVivas(run),
		elitesTotal = #run.elites,
		escolta = if run.escolta then math.floor(run.escolta.prog * 100) else nil,
		cofre = if run.cofre
			then (if run.cofreAberto then 100 else math.floor(run.cofreProg * 100))
			else nil,
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
		if r and h and h.Health > 0 and not embarques[player] then
			local d = r.Position - mapa.origem.Position
			if d.Y < -30 and Vector3.new(d.X, 0, d.Z).Magnitude < 200 then
				levar(player, mapa.spawn)
			elseif d.Magnitude < 200 then
				if not run.membros[player].abatido then
					table.insert(alvos, { raiz = r, humanoide = h })
					vivos[player] = r
				end
			else
				-- Renasceu no lobby (o spawn do Roblox venceu o teleporte do reviver): volta ao andar
				local m = run.membros[player]
				if agora >= m.proximoResgate then
					m.proximoResgate = agora + 1
					if m.reviver then
						entrarAbatido(run, player, m)
					else
						if h.MaxHealth ~= m.vidaMax then
							definirVida(player, m.vidaMax)
						end
						levar(player, mapa.spawn)
					end
				end
			end
		end
	end

	-- reviver colega: aliado perto enche a barra; sem ajuda, levanta sozinho no fim do tempo
	for player, m in run.membros do
		if m.abatido then
			local r = corpo(player)
			if not r then
				continue
			end
			local ajudantes = {}
			for outro, ro in vivos do
				if
					outro ~= player
					and (ro.Position - r.Position).Magnitude <= Desafios.REVIVER_RAIO
				then
					table.insert(ajudantes, outro)
				end
			end
			if #ajudantes > 0 then
				m.reviverProg = math.min(1, m.reviverProg + dt / Desafios.REVIVER_TEMPO)
			end
			if m.reviverProg >= 1 then
				for _, ajudante in ajudantes do
					contarDesafio(run.membros[ajudante], "reviver", 1)
				end
				reerguer(run, player, m, true)
			elseif agora >= m.abatidoAte then
				reerguer(run, player, m, false)
			else
				rotuloAbatido(
					player,
					if #ajudantes > 0
						then string.format("REERGUENDO %d%%", math.floor(m.reviverProg * 100))
						else string.format("ABATIDO · %ds", math.ceil(m.abatidoAte - agora)),
					m
				)
			end
		end
	end

	local centro = mapa.origem.Position
	Inimigos.passo(run.inimigos, dt, alvos, centro, mapa.raio, function(pos)
		novoInimigo(run, pos, false)
	end, function(dados)
		dados.universo = run.universo
		paraRun(run, dados)
	end)

	local tipo = run.tipoAndar
	local pontos = mapa.pontosSombra

	-- Cofre: a fenda abre logo; o Cofre fica no meio, guardado por Elites
	if tipo == "cofre" and not run.fenda then
		abrirFenda(run)
		local u = Incursoes.porId[run.universo]
		local cofre = Mapa.peca(mapa.pasta, "inc_" .. run.universo .. "_nucleo", mapa.origem, 1.3)
		cofre:SetAttribute("Nucleo", true)
		cofre:SetAttribute("Cofre", true)
		cofre:SetAttribute("Progresso", 0)
		cofre:SetAttribute("CorLuz", Color3.fromHex("FFD36B"))
		run.cofre = cofre
		for k = 1, 1 + math.min(ativos(run), 3) do
			local a = 2 * math.pi * k / 4
			novaElite(
				run,
				mapa.origem.Position + Vector3.new(math.sin(a) * 9, 0, math.cos(a) * 9),
				false
			)
		end
		for k = 1, run.cfg.sombras do
			novoInimigo(run, pontos[(k - 1) % #pontos + 1], false)
		end
		local _ = u
	end

	-- reforços: cada tipo de andar tem o seu ritmo
	if not run.cfg.guardiao and not run.fenda then
		local limite = run.cfg.sombras
		local espera = ESPERA_REFORCO
		local ilimitado = false
		if tipo == "horda" and run.hordaFim then
			-- ondas crescentes: mais inimigos ao mesmo tempo e mais rápido
			local passado = agora - run.inicioAndar
			limite = run.cfg.sombras + 2 + math.floor(passado / 9)
			espera = math.max(0.55, 1.5 - passado / 45)
			ilimitado = true
		elseif tipo == "escolta" then
			limite = run.cfg.sombras + 1
			espera = 1.8
			ilimitado = true
		end
		if
			#run.inimigos < limite
			and (ilimitado or run.restantes > 0)
			and agora >= run.proximoReforco
		then
			novoInimigo(run, pontos[rng:NextInteger(1, #pontos)], false)
			if not ilimitado then
				run.restantes -= 1
			end
			run.proximoReforco = agora + espera
		end
		-- Elite de surpresa (a partir do 2º andar, fora da Caçada)
		if run.andar >= 2 and tipo ~= "caca" and agora >= run.proximaElite then
			run.proximaElite = agora
				+ (if tipo == "horda" then 16 else 26)
					* (if run.preparo.marcas.coroa then 0.5 else 1)
			novaElite(run, pontos[rng:NextInteger(1, #pontos)], true)
		end
	end

	-- Horda: sobreviveram até o fim
	if tipo == "horda" and run.hordaFim and agora >= run.hordaFim and not run.fenda then
		abrirFenda(run)
	end
	-- Caçada: todas as Elites caíram
	if tipo == "caca" and not run.fenda and #run.elites > 0 and elitesVivas(run) == 0 then
		abrirFenda(run)
	end
	-- Escolta: o Núcleo anda com alguém perto e sem inimigo encostado
	local esc = run.escolta
	if esc and not run.fenda then
		local pos = esc.nucleo:GetPivot().Position
		local perto = 0
		for _, r in vivos do
			if
				Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude
				<= RAIO_CANAL + 2
			then
				perto += 1
			end
		end
		local contestado = false
		for _, i in run.inimigos do
			if Vector3.new(i.pos.X - pos.X, 0, i.pos.Z - pos.Z).Magnitude <= RAIO_CONTESTO then
				contestado = true
				break
			end
		end
		if esc.nucleo:GetAttribute("Contestado") ~= contestado then
			esc.nucleo:SetAttribute("Contestado", contestado)
		end
		if perto > 0 and not contestado then
			local distancia = math.max((esc.ate - esc.de).Magnitude, 1)
			local velocidade = 2.6 + 0.5 * (perto - 1)
			esc.prog = math.min(1, esc.prog + dt * velocidade / distancia)
			esc.nucleo:PivotTo(CFrame.new(esc.de:Lerp(esc.ate, esc.prog)))
			esc.nucleo:SetAttribute("Progresso", esc.prog)
			if esc.prog >= 1 then
				abrirFenda(run)
			end
		end
	end
	-- Cofre: canalizar perto dele, sem inimigos em volta
	local cofre = run.cofre
	if cofre and not run.cofreAberto then
		local pos = cofre:GetPivot().Position
		local perto = false
		for _, r in vivos do
			if Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude <= 9 then
				perto = true
				break
			end
		end
		local guardado = false
		for _, i in run.inimigos do
			if Vector3.new(i.pos.X - pos.X, 0, i.pos.Z - pos.Z).Magnitude <= 12 then
				guardado = true
				break
			end
		end
		if perto and not guardado then
			run.cofreProg = math.min(1, run.cofreProg + dt / 4)
			cofre:SetAttribute("Progresso", run.cofreProg)
			if run.cofreProg >= 1 then
				run.cofreAberto = true
				cofre:SetAttribute("Aberto", true)
				run.notaAndar = "S" -- o risco paga: loot de andar perfeito outra vez
				for player, membro in run.membros do
					premiar(player, run, membro, true, false)
					contarDesafio(membro, "cofres", 1)
					salvarDesafios(player, run, membro)
				end
				paraRun(run, { tipo = "aviso", texto = "COFRE ABERTO! Loot extra para todos." })
			end
		end
	end

	-- purificação dos Núcleos (só no andar de Purificação)
	local purificar = if tipo == "purificacao" then mapa.nucleos else {}
	local todos = #purificar > 0
	for _, nucleo in purificar do
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
			if nucleo:GetAttribute("Contestado") ~= contestado then
				nucleo:SetAttribute("Contestado", contestado)
			end
			if novo ~= prog then
				nucleo:SetAttribute("Progresso", novo)
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

local function fendaHoje(): Desafios.FendaDoDia
	return Desafios.fendaDoDia(Desafios.dia(os.time()))
end

local function enviarFila(universo: string)
	local f = filas[universo]
	if not f then
		return
	end
	local diaria = universo == FILA_DIARIA
	for _, player in f.jogadores do
		enviar(player, {
			tipo = "fila",
			universo = if diaria then fendaHoje().universo else universo,
			diaria = diaria,
			jogadores = #f.jogadores,
			preparo = Run.descreverPreparo(f.preparo),
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
				local diaria = universo == FILA_DIARIA
				local destino = if diaria then fendaHoje().universo else universo
				if lancar(destino, grupo, 1, false, f.preparo, diaria) then
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

function Servico.ocupado(player: Player): boolean
	return daRun[player] ~= nil or naFila[player] ~= nil or embarques[player] ~= nil
end

function Servico.iniciarTeste(
	player: Player,
	universo: string,
	andar: number,
	preparo: Run.Preparo?,
	diaria: boolean?
): (boolean, string?)
	if player:GetAttribute("EmDueloArena") then
		return false, "Conclua o duelo antes de entrar nas Incursões."
	end
	if not Dados.emTeste(player) or not Incursoes.porId[universo] then
		return false, "Inicie uma sessão de teste primeiro."
	end
	if andar % 1 ~= 0 or andar < 1 or andar > Incursoes.ANDARES then
		return false, "Andar inválido."
	end
	if Servico.ocupado(player) then
		return false, "Saia da fila ou aguarde seu retorno ao Bastião."
	end
	local r, h = corpo(player)
	if not r or not h or h.Health <= 0 then
		return false, "Aguarde seu personagem renascer."
	end
	if not lancar(universo, { player }, andar, true, preparo, diaria) then
		return false, "Todas as fendas estão ocupadas. Tente novamente."
	end
	return true, nil
end

local function acaoFila(player: Player, universo: any, bruto: any): (boolean, string?)
	if universo == "" or universo == nil then
		tirarDaFila(player)
		return true, "Você saiu da fila."
	end
	-- Fenda do Dia: universo e Marcas do dia, iguais para todos
	local chave = universo
	local diaria = universo == FILA_DIARIA
	if diaria then
		local fd = fendaHoje()
		universo = fd.universo
		bruto = { pesadelo = false, marcas = fd.marcas }
	end
	if type(universo) ~= "string" or not Incursoes.porId[universo] then
		return false, "Universo inválido."
	end
	if player:GetAttribute("EmDueloArena") then
		return false, "Conclua o duelo antes de entrar nas Incursões."
	end
	if daRun[player] or embarques[player] then
		return false, "Termine sua incursão ou aguarde o retorno ao Bastião."
	end
	if Dados.emTransacao(player) or not Dados.podeProgredir(player) then
		return false, "Aguarde a confirmação dos seus dados para entrar na fila."
	end
	if not perto(player, bastiao(), DISTANCIA_BASTIAO) then
		return false, "Vá até o Bastião das Incursões para entrar na fila."
	end
	if not Incursoes.liberado(progressoDe(player), universo) then
		return false, "Conclua o universo anterior para abrir este."
	end
	local preparo = Run.preparo(bruto)
	if preparo.pesadelo and ((progressoDe(player).concluidas or {})[universo] or 0) <= 0 then
		return false,
			"Vença " .. Incursoes.porId[universo].nome .. " no normal para liberar o Pesadelo."
	end
	if Dados.emTeste(player) then
		return Servico.iniciarTeste(player, universo, 1, preparo, diaria)
	end
	if naFila[player] == chave then
		return true, nil
	end
	tirarDaFila(player)
	local f = filas[chave]
	if not f then
		f = { jogadores = {}, fim = nil, preparo = preparo } -- quem abre a fila escolhe o preparo
		filas[chave] = f
	end
	if #f.jogadores >= Incursoes.MAX_JOGADORES then
		return false, "Esta fila está cheia. Espere a próxima partida."
	end
	table.insert(f.jogadores, player)
	naFila[player] = chave
	enviarFila(chave)
	return true,
		(if diaria then "Na fila da Fenda do Dia: " else "Na fila: ")
			.. Incursoes.porId[universo].nome
end

local function acaoSair(player: Player): (boolean, string?)
	local run = daRun[player]
	if run then
		if run.estado == "fim" then
			return false, "Aguarde o retorno ao Bastião."
		end
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
	if not m or m.abatido or agora < m.proximoPulso then
		return false, nil
	end
	local r, h = corpo(player)
	local mapa = run.mapa
	if not r or not h or h.Health <= 0 or not mapa or embarques[player] then
		return false, nil
	end
	local distancia = r.Position - mapa.origem.Position
	if distancia.Magnitude >= 200 or math.abs(distancia.Y) > 30 then
		return false, nil
	end
	m.proximoPulso = agora + Incursoes.PULSO_ESPERA
	local p = progressoDe(player)
	local dano = Incursoes.danoPulso(p, m.ressonancia)
		* (1 + (m.mods.pulso or 0) + (m.mods.dano or 0))
	local raio = Incursoes.raioPulso(p) * (1 + (m.mods.raioPulso or 0))
	for _, i in table.clone(run.inimigos) do
		local d = Vector3.new(i.pos.X - r.Position.X, 0, i.pos.Z - r.Position.Z).Magnitude
		if d <= raio + i.raio then
			if Inimigos.ferir(i, dano, r.Position) and Combate.aoAbater then
				Combate.aoAbater(player, i)
			end
		end
	end
	paraRun(run, { tipo = "pulso", origem = r.Position, raio = raio, userId = player.UserId })
	return true, nil
end

-- Contexto de combate: só dentro da partida, vivo, no andar e fora do embarque
local function contextoCombate(player: Player): Combate.Contexto?
	local run = daRun[player]
	if not run or run.estado ~= "andar" then
		return nil
	end
	local m = run.membros[player]
	local r, h = corpo(player)
	local mapa = run.mapa
	if not m or m.abatido or not r or not h or h.Health <= 0 or not mapa or embarques[player] then
		return nil
	end
	local distancia = r.Position - mapa.origem.Position
	if distancia.Magnitude >= 200 or math.abs(distancia.Y) > 30 then
		return nil
	end
	Combate.atualizarKit(player, (player.Character :: Model):GetAttribute("AuraVfx"))
	return {
		raiz = r,
		humanoide = h,
		inimigos = run.inimigos,
		ressonancia = m.ressonancia,
		paraRun = function(dados)
			paraRun(run, dados)
		end,
		enviar = function(dados)
			enviar(player, dados)
		end,
	}
end

local function acaoTecnica(player: Player, id: any, dir: any): (boolean, string?)
	local ctx = contextoCombate(player)
	if not ctx then
		return false, nil
	end
	return Combate.tecnica(player, id, dir, ctx)
end

local function acaoEsquiva(player: Player, dir: any): (boolean, string?)
	local ctx = contextoCombate(player)
	if not ctx then
		return false, nil
	end
	return Combate.esquiva(player, dir, ctx)
end

local function acaoGuarda(player: Player, ligar: any): (boolean, string?)
	local ctx = contextoCombate(player)
	if not ctx then
		return false, nil
	end
	return Combate.guarda(player, ligar, ctx)
end

local function acaoBencao(player: Player, id: any): (boolean, string?)
	local run = daRun[player]
	local membro = run and run.membros[player]
	if not run or not membro or type(id) ~= "string" then
		return false, nil
	end
	local ofertas = membro.ofertas
	if not ofertas or not table.find(ofertas, id) then
		return false, "Essa Bênção não está disponível."
	end
	escolherBencao(player, membro, id)
	return true, Run.bencaoPorId[id].nome .. "!"
end

-- Abate feito por um jogador: sequência, cura da Lâmina Faminta, Elite derrubada
local function aoAbater(player: Player, i: any)
	local run = daRun[player]
	local membro = run and run.membros[player]
	if not run or not membro then
		return
	end
	local agora = os.clock()
	membro.sequencia = if agora - membro.ultimoAbate <= Run.SEQUENCIA_JANELA
		then membro.sequencia + 1
		else 1
	membro.ultimoAbate = agora
	membro.abates += 1
	membro.melhorSequencia = math.max(membro.melhorSequencia, membro.sequencia)
	contarDesafio(membro, "abates", 1)
	if i.elite then
		contarDesafio(membro, "elites", 1)
	end
	enviar(player, { tipo = "sequencia", n = membro.sequencia })
	local cura = membro.mods.curaAbate or 0
	if cura > 0 then
		local _, h = corpo(player)
		if h and h.Health > 0 then
			h.Health = math.min(h.MaxHealth, h.Health + h.MaxHealth * cura)
		end
	end
	if i.elite then
		paraRun(run, { tipo = "aviso", texto = player.DisplayName .. " derrubou uma Elite!" })
	end
end

-- Painel: Fenda do Dia (universo e Marcas) e ranking deste servidor
local function acaoRanking(_player: Player): (boolean, string?, { [string]: any }?)
	local fd = fendaHoje()
	local marcas = {}
	for id in fd.marcas do
		table.insert(marcas, id)
	end
	return true, nil, { universo = fd.universo, marcas = marcas, ranking = rankingAtual() }
end

local function acaoReliquia(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" or not Incursoes.reliquiaPorId[id] then
		return false, "Relíquia inválida."
	end
	if daRun[player] or not perto(player, bastiao(), DISTANCIA_BASTIAO) then
		return false, "Melhore relíquias na Mesa dos Cartógrafos."
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
	Acoes.registrar("IncursaoTecnica", acaoTecnica)
	Acoes.registrar("IncursaoEsquiva", acaoEsquiva)
	Acoes.registrar("IncursaoGuarda", acaoGuarda)
	Acoes.registrar("IncursaoBencao", acaoBencao)
	Acoes.registrar("IncursaoRanking", acaoRanking)
	Combate.aoAbater = aoAbater
	Combate.iniciar()

	Dados.quandoSair(function(player)
		embarques[player] = nil
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
		Combate.passo()
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
