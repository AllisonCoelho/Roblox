-- Criaturas do Corredor no servidor (regras em Shared/Dados/Criaturas). Cada criatura é uma
-- peça invisível (alvo do toque e posição) com atributos que todo cliente lê para montar e
-- animar o modelo: Criatura, Tipo, Vida, VidaMax, Viva, AtacouEm, AtingidoEm, MorreuEm.
--
-- O jogador escolhe o alvo tocando nela (ClickDetector); sem alvo, a aura ataca a mais próxima.
-- O servidor confere distância, intervalo e fase, calcula o dano pela Pontuação de Aura, aplica
-- o dano das criaturas no Humanoid, dá as recompensas a quem ajudou e guarda quem ajudou a
-- derrubar o chefe (é isso que abre o Portão da fase).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Criaturas = require(Shared.Dados.Criaturas)
local AtaquesAura = require(Shared.Dados.AtaquesAura)
local Auras = require(Shared.Dados.Auras)
local Visual = require(Shared.Dados.CriaturasVisual)
local Mapa = require(Shared.Dados.CorredorMapa)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent.Servicos
local Dados = require(Servicos.Dados)
local PontosAura = require(Servicos.PontosAura)
local PetsServico = require(Servicos.Pets)
local EquipamentoServico = require(Servicos.Equipamento)

local Servico = {}

type Criatura = {
	id: number,
	fase: number,
	tipo: string,
	modelo: string,
	parte: Part,
	base: CFrame,
	vida: number,
	vidaMax: number,
	viva: boolean,
	renasceEm: number,
	ultimoAtaque: number,
	ajudaram: { [Player]: number },
	lentoAte: number?, -- congelada/presa: ataca mais devagar até aqui
	lentoFator: number?,
}

local criaturas: { Criatura } = {}
local porParte: { [BasePart]: Criatura } = {}
local alvo: { [Player]: Criatura } = {}
local ultimoGolpe: { [Player]: number } = {}
local contagemGolpes: { [Player]: number } = {} -- para os poderes "a cada N golpes"
-- Quem ajudou a derrubar o chefe de cada fase (vale até sair da fase)
local credito: { [Player]: { [number]: boolean } } = {}
local rng = Random.new()

-- Em que fase o jogador está (o serviço do Corredor informa)
local faseDe: (Player) -> number? = function()
	return nil
end

function Servico.definirFaseDe(fn: (Player) -> number?)
	faseDe = fn
end

function Servico.venceuChefe(player: Player, fase: number): boolean
	local c = credito[player]
	return c ~= nil and c[fase] == true
end

function Servico.limparCredito(player: Player)
	credito[player] = nil
	alvo[player] = nil
end

local function raizDe(player: Player): (BasePart?, Humanoid?)
	local personagem = player.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not raiz or not raiz:IsA("BasePart") or not humanoide or humanoide.Health <= 0 then
		return nil, nil
	end
	return raiz, humanoide
end

local function distancia(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function avisar(player: Player, texto: string)
	Remotos.evento("Aviso"):FireClient(player, { tipo = "info", texto = texto })
end

local function nome(c: Criatura): string
	local f = Criaturas.FASES[c.fase]
	return if c.tipo == "chefe" then f.nomeChefe else f.nomeLacaio
end

local function morrer(c: Criatura, agora: number)
	c.viva = false
	c.renasceEm = agora + Criaturas.regras(c.tipo).renasce
	c.parte:SetAttribute("Viva", false)
	c.parte:SetAttribute("MorreuEm", Workspace:GetServerTimeNow())
	c.parte:SetAttribute("Vida", 0)
	-- recompensas para todos que ajudaram e ainda estão no jogo
	for player in c.ajudaram do
		if player.Parent ~= Players then
			continue
		end
		local ganho = PontosAura.ganho(player)
		local _, _, multFragPets = PetsServico.multiplicadores(player)
		local multFrag = multFragPets * EquipamentoServico.multiplicadores(player).fragmentos
		local pontos, fragmentos =
			Criaturas.recompensa(c.fase, c.tipo, ganho, rng:NextNumber(), multFrag)
		Dados.alterar(player, function(estado)
			local e = estado :: any
			e.poder.pontos += pontos
			e.poder.total += pontos
			e.corredor.fragmentos += fragmentos
			return true
		end)
		player:SetAttribute("PontosAura", math.floor((Dados.de(player) :: any).poder.pontos))
		EquipamentoServico.darDrop(player, c.fase, c.tipo)
		if c.tipo == "chefe" then
			credito[player] = credito[player] or {}
			credito[player][c.fase] = true
			avisar(
				player,
				string.format(
					"%s derrotado! O Portão está aberto. +%d Pontos de Aura",
					nome(c),
					pontos
				)
			)
		elseif fragmentos > 0 then
			avisar(
				player,
				string.format("+%d Pontos de Aura · +%d Fragmentos", pontos, fragmentos)
			)
		end
	end
	c.ajudaram = {}
	for player, a in alvo do
		if a == c then
			alvo[player] = nil
		end
	end
end

local function renascer(c: Criatura)
	c.viva = true
	c.vida = c.vidaMax
	c.ajudaram = {}
	c.parte.CFrame = c.base
	c.parte:SetAttribute("Viva", true)
	c.parte:SetAttribute("Vida", c.vida)
end

-- Poder do ataque automático pela aura equipada (Dados/AtaquesAura)
local function poderDe(player: Player): (AtaquesAura.Poder, number)
	local estado = Dados.de(player) :: any
	local aura = estado and estado.equipada and Auras.porId[estado.equipada]
	if not aura then
		return AtaquesAura.poderDe(nil, nil), 1
	end
	local tier = if aura.exclusiva then #Auras.Tiers else aura.tier
	return AtaquesAura.poderDe(aura.id, aura.familia), tier
end

local function aplicarDano(player: Player, c: Criatura, dano: number)
	if not c.viva then
		return
	end
	c.vida = math.max(0, c.vida - dano)
	c.ajudaram[player] = (c.ajudaram[player] or 0) + dano
	c.parte:SetAttribute("Vida", c.vida)
	c.parte:SetAttribute("AtingidoEm", Workspace:GetServerTimeNow())
	if c.vida <= 0 then
		morrer(c, os.clock())
	end
end

local function golpear(player: Player, c: Criatura, agora: number)
	ultimoGolpe[player] = agora
	contagemGolpes[player] = (contagemGolpes[player] or 0) + 1
	local danoBase = Criaturas.danoJogador(PontosAura.pontuacao(player))
		* EquipamentoServico.multiplicadores(player).dano
	local poder, tier = poderDe(player)
	local raiz = raizDe(player)
	local origem = if raiz then { x = raiz.Position.X, z = raiz.Position.Z } else { x = 0, z = 0 }
	local outros = {}
	local porId: { [number]: Criatura } = { [c.id] = c }
	for _, o in criaturas do
		if o.viva and o.fase == c.fase and o ~= c then
			table.insert(outros, { id = o.id, x = o.parte.Position.X, z = o.parte.Position.Z })
			porId[o.id] = o
		end
	end
	local r = AtaquesAura.resolver(
		poder,
		danoBase,
		tier,
		origem,
		{ id = c.id, x = c.parte.Position.X, z = c.parte.Position.Z },
		outros,
		contagemGolpes[player],
		function()
			return rng:NextNumber()
		end
	)
	local lista = {}
	for _, a in r.acertos do
		local alvoC = porId[a.id]
		if alvoC then
			table.insert(lista, {
				alvo = a.id,
				dano = a.dano,
				atraso = a.atraso,
				critico = a.critico,
				tipo = a.tipo,
			})
			if a.atraso <= 0 then
				aplicarDano(player, alvoC, a.dano)
			else
				task.delay(a.atraso, aplicarDano, player, alvoC, a.dano)
			end
		end
	end
	if r.lentidao then
		c.lentoAte = agora + r.lentidao.duracao
		c.lentoFator = r.lentidao.fator
		c.parte:SetAttribute("LentoAte", Workspace:GetServerTimeNow() + r.lentidao.duracao)
	end
	Remotos.evento("Corredor"):FireAllClients({
		tipo = "golpe",
		de = player.UserId,
		alvo = c.id,
		dano = if lista[1] then lista[1].dano else 0,
		poder = poder.id,
		tier = tier,
		aura = (Dados.de(player) :: any) and (Dados.de(player) :: any).equipada or nil,
		forte = r.forte,
		acertos = lista,
	})
end

-- Um passo da simulação: golpes da aura, criaturas virando e atacando, renascer
local function passo()
	local agora = os.clock()
	-- jogadores atacam
	for _, player in Players:GetPlayers() do
		local fase = faseDe(player)
		local raiz = raizDe(player)
		if not fase or not raiz then
			alvo[player] = nil
			continue
		end
		if agora - (ultimoGolpe[player] or 0) < Criaturas.ESPERA_GOLPE then
			continue
		end
		local a = alvo[player]
		if a and (not a.viva or a.fase ~= fase) then
			alvo[player] = nil
			a = nil
		end
		if not a then
			-- sem alvo escolhido: a mais próxima ao alcance da mira automática
			local melhor, menor = nil, Criaturas.AUTO_MIRA
			for _, c in criaturas do
				if c.viva and c.fase == fase then
					local d = distancia(c.parte.Position, raiz.Position) - c.parte.Size.X / 2
					if d < menor then
						melhor, menor = c, d
					end
				end
			end
			a = melhor
		end
		if
			a
			and distancia(a.parte.Position, raiz.Position)
				<= Criaturas.ALCANCE_AURA + a.parte.Size.X / 2
		then
			golpear(player, a, agora)
		end
	end
	-- criaturas viram para quem está perto e atacam
	for _, c in criaturas do
		if not c.viva then
			if agora >= c.renasceEm then
				renascer(c)
			end
			continue
		end
		local regras = Criaturas.regras(c.tipo)
		local maisPerto: Player? = nil
		local menor = regras.alcance + c.parte.Size.X / 2 + 6
		for _, player in Players:GetPlayers() do
			if faseDe(player) == c.fase then
				local raiz = raizDe(player)
				if raiz then
					local d = distancia(c.parte.Position, raiz.Position)
					if d < menor then
						maisPerto, menor = player, d
					end
				end
			end
		end
		if maisPerto then
			local raiz, humanoide = raizDe(maisPerto)
			if raiz and humanoide then
				local pos = c.parte.Position
				local olhar = Vector3.new(raiz.Position.X, pos.Y, raiz.Position.Z)
				if (olhar - pos).Magnitude > 0.5 then
					c.parte.CFrame = CFrame.lookAt(pos, olhar)
				end
				if
					menor <= regras.alcance + c.parte.Size.X / 2
					and agora - c.ultimoAtaque
						>= regras.espera * (if c.lentoAte and agora < c.lentoAte
							then c.lentoFator or 1
							else 1)
				then
					c.ultimoAtaque = agora
					c.parte:SetAttribute("AtacouEm", Workspace:GetServerTimeNow())
					-- o golpe acerta no meio da animação
					task.delay(0.35, function()
						local r2, h2 = raizDe(maisPerto :: Player)
						if
							c.viva
							and r2
							and h2
							and distancia(c.parte.Position, r2.Position)
								<= regras.alcance + c.parte.Size.X / 2 + 2
						then
							h2:TakeDamage(regras.dano)
						end
					end)
				end
			end
		end
	end
end

local function criar(pasta: Instance, fase: number, tipo: string, x: number, y: number): Criatura
	local f = (Mapa.fases :: { any })[fase]
	local dados = Criaturas.FASES[fase]
	local modelo = if tipo == "chefe" then dados.chefe else dados.lacaio
	local visual = (Visual :: any)[modelo]
	local altura = if visual then visual.altura else 5
	local largura = if tipo == "chefe" then 7 else 3
	local px, py, pz = Criaturas.paraMundo(f.centro, f.giro, x, y)
	local pos = Vector3.new(px, py + altura / 2, pz)
	-- de frente para o começo da ilha (de onde o jogador vem)
	local ix, _, iz = Criaturas.paraMundo(f.centro, f.giro, x, y - 10)
	local base = CFrame.lookAt(pos, Vector3.new(ix, pos.Y, iz))
	local parte = Instance.new("Part")
	parte.Name = "Criatura"
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	parte.CanQuery = true
	parte.Transparency = 1
	parte.Size = Vector3.new(largura, altura, largura)
	parte.CFrame = base
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = 80
	detector.Parent = parte
	local vida = Criaturas.vida(fase, tipo)
	local c: Criatura = {
		id = #criaturas + 1,
		fase = fase,
		tipo = tipo,
		modelo = modelo,
		parte = parte,
		base = base,
		vida = vida,
		vidaMax = vida,
		viva = true,
		renasceEm = 0,
		ultimoAtaque = 0,
		ajudaram = {},
	}
	parte:SetAttribute("Id", c.id)
	parte:SetAttribute("Criatura", modelo)
	parte:SetAttribute("Nome", if tipo == "chefe" then dados.nomeChefe else dados.nomeLacaio)
	parte:SetAttribute("Tipo", tipo)
	parte:SetAttribute("Fase", fase)
	parte:SetAttribute("Vida", vida)
	parte:SetAttribute("VidaMax", vida)
	parte:SetAttribute("Viva", true)
	parte.Parent = pasta
	detector.MouseClick:Connect(function(player)
		if faseDe(player) ~= c.fase or not c.viva then
			return
		end
		alvo[player] = c
	end)
	table.insert(criaturas, c)
	porParte[parte] = c
	return c
end

function Servico.iniciar()
	local pasta = Instance.new("Folder")
	pasta.Name = "CriaturasCorredor"
	for fase = 1, #Criaturas.FASES do
		for _, p in Criaturas.POSICOES do
			criar(pasta, fase, p.tipo, p.x, p.y)
		end
	end
	pasta.Parent = Workspace
	Players.PlayerRemoving:Connect(function(player)
		alvo[player] = nil
		ultimoGolpe[player] = nil
		contagemGolpes[player] = nil
		credito[player] = nil
		for _, c in criaturas do
			c.ajudaram[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, erro = pcall(passo)
			if not ok then
				warn("[Criaturas] " .. tostring(erro))
			end
		end
	end)
end

return Servico
