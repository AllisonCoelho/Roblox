-- Evento "Despertar do Sol" no servidor (regras em Shared/Dados/EventoSol).
--
-- O relógio do evento é o do servidor (todos os servidores juntos). O estado público fica em
-- atributos do Workspace, que todo cliente lê para o céu, a música e o HUD:
--   EventoFase ("espera" | "aviso" | "luta" | "fim"), EventoFim (hora do servidor em que a fase
--   acaba), EventoDeslocamento (só o Painel Dev mexe), EventoRanking (JSON do top 5) e
--   EventoResultado ("derrotado" | "escapou").
-- O Titã de Borracha é uma peça invisível em Workspace.EventoSol ("Tita") com Vida, VidaMax e
-- AtaqueEm; cada cliente monta e anima o modelo. Os golpes da aura são automáticos para quem estiver
-- perto (como no Corredor), sem remote para falsificar. Os baús entram no perfil e são abertos
-- pela ação "AbrirBau".
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventoSol = require(Shared.Dados.EventoSol)
local Cosmeticos = require(Shared.Dados.Cosmeticos)
local Criaturas = require(Shared.Dados.Criaturas)
local AtaquesAura = require(Shared.Dados.AtaquesAura)
local Auras = require(Shared.Dados.Auras)
local DropsMapa = require(Shared.Dados.DropsMapa)
local Remotos = require(Shared.Remotos)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)
local PontosAura = require(script.Parent.PontosAura)
local Equipamento = require(script.Parent.Equipamento)

local Servico = {}

local POSICAO_TITA = Vector3.new(0, 1, -28) -- lado norte da praça, de frente para quem nasce
local TAMANHO_TITA = Vector3.new(14, 26, 10)
local ESPERA_ONDA = 5 -- segundos entre as ondas do Titã
local RAIO_ONDA = 20
local DANO_ONDA = 0.12 -- fração da vida máxima de quem está perto

local rng = Random.new()
local pasta: Folder
local tita: Part? = nil
local danos: { [number]: number } = {}
local ultimoGolpe: { [Player]: number } = {}
local cicloAtual = -1
local faseAtual = ""
local proximaOnda = 0

local function agora(): number
	return Workspace:GetServerTimeNow()
		+ (tonumber(Workspace:GetAttribute("EventoDeslocamento")) or 0)
end

local function avisarTodos(texto: string)
	Remotos.evento("Aviso"):FireAllClients({ tipo = "info", texto = texto })
end

local function danoDe(player: Player): number
	return math.floor(
		Criaturas.danoJogador(PontosAura.pontuacao(player))
				* Equipamento.multiplicadores(player).dano
			+ 0.5
	)
end

-- Poder do ataque automático (Dados/AtaquesAura): no Titã (alvo único) soma os acertos do poder
-- (golpes seguidos, crítico, queimadura, golpe forte a cada N)
local contagem: { [Player]: number } = {}
local function golpeDoPoder(player: Player): (number, string, boolean, boolean)
	local estado = Dados.de(player) :: any
	local aura = estado and estado.equipada and Auras.porId[estado.equipada]
	local tier = if aura then (if aura.exclusiva then #Auras.Tiers else aura.tier) else 1
	local poder = AtaquesAura.poderDe(aura and aura.id, aura and aura.familia)
	contagem[player] = (contagem[player] or 0) + 1
	local r = AtaquesAura.resolver(
		poder,
		danoDe(player),
		tier,
		{ x = 0, z = 0 },
		{ id = 0, x = 0, z = 1 },
		{},
		contagem[player],
		function()
			return rng:NextNumber()
		end
	)
	local total, critico = 0, false
	for _, a in r.acertos do
		total += a.dano
		critico = critico or a.critico == true
	end
	return total, poder.id, critico, r.forte
end

local function publicarRanking()
	local lista = {}
	for i, l in EventoSol.ranking(danos) do
		if i > 5 then
			break
		end
		local p = Players:GetPlayerByUserId(l.id)
		table.insert(
			lista,
			{ id = l.id, nome = if p then p.DisplayName else "Jogador", dano = l.dano }
		)
	end
	Workspace:SetAttribute("EventoRanking", HttpService:JSONEncode(lista))
end

local function criarTita()
	if tita then
		tita:Destroy()
	end
	local vivos = {}
	for _, p in Players:GetPlayers() do
		if Dados.de(p) then
			table.insert(vivos, danoDe(p))
		end
	end
	local vida = EventoSol.vida(vivos)
	local parte = Instance.new("Part")
	parte.Name = "Tita"
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	parte.CanQuery = true
	parte.Transparency = 1
	parte.Size = TAMANHO_TITA
	parte.CFrame = CFrame.lookAt(
		POSICAO_TITA + Vector3.new(0, TAMANHO_TITA.Y / 2, 0),
		Vector3.new(0, TAMANHO_TITA.Y / 2, 40)
	)
	parte:SetAttribute("Vida", vida)
	parte:SetAttribute("VidaMax", vida)
	parte:SetAttribute("SurgiuEm", Workspace:GetServerTimeNow())
	parte.Parent = pasta
	tita = parte
	table.clear(danos)
	proximaOnda = os.clock() + 6
	publicarRanking()
end

local function darBaus(derrotado: boolean)
	local premios = EventoSol.premios(danos, derrotado)
	for id, tipo in premios do
		local p = Players:GetPlayerByUserId(id)
		if p and Dados.de(p) then
			Dados.alterar(p, function(estado)
				local ev = (estado :: any).evento
				ev[tipo] += 1
				ev.participacoes += 1
				return true
			end)
			Remotos.evento("Evento"):FireClient(p, {
				tipo = "premio",
				bau = tipo,
				texto = string.format("Você ganhou um %s!", EventoSol.BAUS[tipo].nome),
			})
		end
	end
end

local function terminar(derrotado: boolean)
	local t = tita
	if not t then
		return
	end
	tita = nil
	t:SetAttribute("Vida", if derrotado then 0 else t:GetAttribute("Vida"))
	t:SetAttribute("Derrotado", derrotado)
	t:SetAttribute("FimEm", Workspace:GetServerTimeNow())
	Workspace:SetAttribute("EventoResultado", if derrotado then "derrotado" else "escapou")
	publicarRanking()
	darBaus(derrotado)
	avisarTodos(
		if derrotado
			then "☀ O Titã de Borracha caiu! Os 3 que mais bateram ganharam o Baú do Sol Dourado."
			else "O Titã de Borracha escapou rindo! Quem ajudou ganhou um Baú do Sol."
	)
	task.delay(6, function()
		t:Destroy()
	end)
end

-- Golpes da aura de quem está perto e as ondas do Titã
local function lutar()
	local t = tita
	if not t then
		return
	end
	local relogio = os.clock()
	local vida = tonumber(t:GetAttribute("Vida")) or 0
	local golpes = {}
	for _, p in Players:GetPlayers() do
		local personagem = p.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if
			not raiz
			or not raiz:IsA("BasePart")
			or not humanoide
			or humanoide.Health <= 0
			or p:GetAttribute("EmDueloArena")
		then
			continue
		end
		local d =
			Vector3.new(raiz.Position.X - t.Position.X, 0, raiz.Position.Z - t.Position.Z).Magnitude
		if d > EventoSol.ALCANCE or relogio - (ultimoGolpe[p] or 0) < EventoSol.ESPERA_GOLPE then
			continue
		end
		ultimoGolpe[p] = relogio
		local total, poder, critico, forte = golpeDoPoder(p)
		local dano = math.min(vida, total)
		if dano <= 0 then
			continue
		end
		vida -= dano
		danos[p.UserId] = (danos[p.UserId] or 0) + dano
		table.insert(golpes, {
			de = p.UserId,
			dano = dano,
			poder = poder,
			critico = critico,
			forte = forte,
			aura = (Dados.de(p) :: any) and (Dados.de(p) :: any).equipada or nil,
		})
		if vida <= 0 then
			break
		end
	end
	if #golpes > 0 then
		t:SetAttribute("Vida", vida)
		t:SetAttribute("AtingidoEm", Workspace:GetServerTimeNow())
		Remotos.evento("Evento"):FireAllClients({ tipo = "golpes", lista = golpes })
	end
	if vida <= 0 then
		terminar(true)
		return
	end
	-- onda: o Titã estica os braços e bate no chão (aviso de 1 s pelo atributo)
	if relogio >= proximaOnda then
		proximaOnda = relogio + ESPERA_ONDA
		t:SetAttribute("AtaqueEm", Workspace:GetServerTimeNow() + 1)
		task.delay(1, function()
			if tita ~= t then
				return
			end
			for _, p in Players:GetPlayers() do
				local personagem = p.Character
				local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
				local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
				if raiz and raiz:IsA("BasePart") and humanoide and humanoide.Health > 0 then
					local delta = raiz.Position - t.Position
					local plano = Vector3.new(delta.X, 0, delta.Z)
					if plano.Magnitude <= RAIO_ONDA and not p:GetAttribute("EmDueloArena") then
						humanoide:TakeDamage(humanoide.MaxHealth * DANO_ONDA)
						-- o golpe de borracha arremessa para longe (e para cima)
						local direcao = if plano.Magnitude > 0.1
							then plano.Unit
							else Vector3.new(0, 0, 1)
						raiz.AssemblyLinearVelocity = direcao * 70 + Vector3.new(0, 45, 0)
					end
				end
			end
		end)
	end
end

local function passo()
	local e = EventoSol.estado(agora())
	local fimEm = Workspace:GetServerTimeNow() + e.restante
	if e.fase ~= faseAtual or e.ciclo ~= cicloAtual then
		local anterior = faseAtual
		faseAtual = e.fase
		cicloAtual = e.ciclo
		Workspace:SetAttribute("EventoFase", e.fase)
		if e.fase == "aviso" then
			Workspace:SetAttribute("EventoResultado", nil)
			avisarTodos(
				"☀ O SOL ESTÁ DESPERTANDO! O Titã de Borracha chega à praça em 1 minuto!"
			)
		elseif e.fase == "luta" then
			criarTita()
			avisarTodos(
				"☀ O Titã de Borracha chegou! Vá até a praça e bata nele com a sua aura!"
			)
		elseif e.fase == "fim" and anterior == "luta" and tita then
			terminar(false)
		elseif e.fase == "espera" and tita then
			terminar(false)
		end
	end
	Workspace:SetAttribute("EventoFim", fimEm)
	if e.fase == "luta" then
		lutar()
	end
end

-- ============================================================ baús

local function abrirBau(player: Player, tipo: any): (boolean, string?, { [string]: any }?)
	local resultado: string? = nil
	local tipoBau = tipo
	local ganhoAgora = PontosAura.ganho(player)
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		local premio, erro = EventoSol.abrir(e.evento, tipoBau, function()
			return rng:NextNumber()
		end, function(id)
			return e.cosmeticos.possui[id] == true
		end)
		if not premio then
			return false, erro
		end
		resultado = premio
		if premio == "gear5" then
			e.auras.gear5 = (e.auras.gear5 or 0) + 1
		elseif premio == "ras_nuvem_sol" or premio == "tit_libertado" then
			Cosmeticos.conceder(e.cosmeticos, { premio })
		elseif premio == "pontos" then
			local q = EventoSol.pontosDoBau(tipoBau, ganhoAgora)
			e.poder.pontos += q
			e.poder.total += q
		elseif premio == "fragmentos" then
			local fase = DropsMapa.faseMaxima(e.corredor and e.corredor.concluidas)
			e.corredor.fragmentos += EventoSol.fragmentosDoBau(tipoBau, fase)
		end
		return true
	end)
	if not ok then
		return false, msg
	end
	local estado = Dados.de(player) :: any
	player:SetAttribute("PontosAura", math.floor(estado.poder.pontos))
	local premio = resultado :: string
	if premio == "gear5" then
		Remotos.evento("Evento"):FireAllClients({
			tipo = "gear5",
			de = player.UserId,
			nome = player.DisplayName,
		})
	end
	local quantidade = if premio == "pontos"
		then EventoSol.pontosDoBau(tipoBau, ganhoAgora)
		elseif premio == "fragmentos" then EventoSol.fragmentosDoBau(
			tipoBau,
			DropsMapa.faseMaxima(estado.corredor and estado.corredor.concluidas)
		)
		else nil
	return true, nil, { premio = premio, quantidade = quantidade, tipo = tipoBau }
end

-- Painel Dev: pula para o aviso ou para a luta (vale para o servidor todo)
function Servico.irPara(fase: any): (boolean, string?)
	local t = Workspace:GetServerTimeNow()
	local dentro = t % EventoSol.PERIODO
	if fase == "aviso" then
		Workspace:SetAttribute(
			"EventoDeslocamento",
			EventoSol.PERIODO - EventoSol.AVISO - dentro + 0.5
		)
	elseif fase == "luta" then
		Workspace:SetAttribute("EventoDeslocamento", EventoSol.PERIODO - dentro + 0.5)
	elseif fase == "normal" then
		Workspace:SetAttribute("EventoDeslocamento", 0)
	else
		return false, "Fase desconhecida"
	end
	return true, "Evento: " .. tostring(fase)
end

-- Painel Dev (sessão de teste): baús para testar a abertura
function Servico.darBausTeste(player: Player): (boolean, string?)
	return Dados.alterar(player, function(estado)
		local ev = (estado :: any).evento
		ev.sol += 5
		ev.dourado += 2
		return true
	end)
end

function Servico.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "EventoSol"
	pasta.Parent = Workspace
	Acoes.registrar("AbrirBau", abrirBau)
	Players.PlayerRemoving:Connect(function(player)
		ultimoGolpe[player] = nil
		contagem[player] = nil
	end)
	task.spawn(function()
		while true do
			local ok, erro = pcall(passo)
			if not ok then
				warn("[EventoSol] " .. tostring(erro))
			end
			task.wait(0.25)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if tita then
				pcall(publicarRanking)
			end
		end
	end)
end

return Servico
