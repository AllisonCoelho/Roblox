-- Duelo contra o Primeiro Soberano (a prova do trono). Um duelo de cada vez no ringue, que é
-- dividido com o 1x1 entre jogadores (Palco). Vencer o Soberano conta no perfil e, com o trono
-- vazio, faz do jogador o Rei do Servidor (Trono). O combate é o reativo (Dados/Duelo e Motor):
-- o cliente só informa a ação escolhida e os toques (golpe no tempo certo, Esquivar, Aparar).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Duelo = require(Shared.Dados.Duelo)
local Animacoes = require(Shared.Dados.ArenaAnimacoes)
local Cena = require(Shared.Dados.ArenaCena)
local Auras = require(Shared.Dados.Auras)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent.Servicos
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local Incursoes = require(script.Parent.Parent.Incursoes.Servico)
local Palco = require(script.Parent.Palco)
local Motor = require(script.Parent.Motor)
local PvP = require(script.Parent.PvP)
local Trono = require(script.Parent.Trono)
local Rankeada = require(script.Parent.Rankeada)

local Servico = {}
local INTRODUCAO = Animacoes.INTRODUCAO
local MOSTRAR_RESULTADO = 5
local DISTANCIA = 16
local FOLGA_DISTANCIA = 3
local TEMPO_DIALOGO = 30
local INTERVALO_INTERACAO = 0.8
local INTERVALO_ALERTA = 25

type Sessao = {
	id: number,
	player: Player,
	personagem: Model,
	corpo: BasePart,
	humanoide: Humanoid,
	original: CFrame,
	posto: CFrame,
	ancorado: boolean,
	soberano: BasePart,
	prompt: ProximityPrompt,
	estado: Duelo.Estado,
	motor: Motor.Duelo?,
	fase: string,
	aura: Auras.Aura?,
	conexoes: { RBXScriptConnection },
	tween: Tween?,
}

local atual: Sessao? = nil
local contador = 0
local convites: { [Player]: { id: number, personagem: Model, venceEm: number } } = {}

local function personagemPerto(player: Player, ponto: BasePart): (Model?, BasePart?, Humanoid?)
	local personagem = player.Character
	local corpo = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if
		not personagem
		or not corpo
		or not corpo:IsA("BasePart")
		or corpo.Anchored
		or not humanoide
		or humanoide.Health <= 0
		or (corpo.Position - ponto.Position).Magnitude > DISTANCIA + FOLGA_DISTANCIA
	then
		return nil, nil, nil
	end
	return personagem, corpo, humanoide
end

local function alturaDoCorpo(personagem: Model, corpo: BasePart, humanoide: Humanoid): number
	local altura = humanoide.HipHeight + corpo.Size.Y / 2
	if humanoide.RigType == Enum.HumanoidRigType.R6 then
		local perna = personagem:FindFirstChild("Left Leg")
		if perna and perna:IsA("BasePart") then
			altura += perna.Size.Y
		end
	end
	return altura
end

local function enviar(d: Sessao, tipo: string, dados: { [string]: any }?)
	if d.player.Parent ~= Players then
		return
	end
	local pacote = dados or {}
	pacote.id = d.id
	pacote.tipo = tipo
	Remotos.evento("Arena"):FireClient(d.player, pacote)
end

-- Animações compartilhadas: todo cliente lê estes atributos e toca o mesmo clipe no mesmo
-- instante do relógio do servidor (o instante pode estar no futuro: a reação ao impacto).
local function animarJogador(d: Sessao, clipe: string?, quando: number)
	d.player:SetAttribute("ArenaAnim", clipe)
	d.player:SetAttribute("ArenaAnimEm", if clipe then quando else nil)
end

local function animarSoberano(d: Sessao, clipe: string?, quando: number)
	d.soberano:SetAttribute("DueloAnim", clipe)
	d.soberano:SetAttribute("DueloAnimEm", if clipe then quando else nil)
end

local function encerrar(d: Sessao)
	if atual ~= d then
		return
	end
	atual = nil
	if d.motor then
		Motor.parar(d.motor)
	end
	for _, conexao in d.conexoes do
		conexao:Disconnect()
	end
	if d.tween then
		d.tween:Cancel()
	end
	if d.corpo.Parent and d.player.Character == d.personagem then
		if d.humanoide.Health > 0 then
			d.personagem:PivotTo(d.original)
			d.corpo.AssemblyLinearVelocity = Vector3.zero
			d.corpo.AssemblyAngularVelocity = Vector3.zero
		end
		d.corpo.Anchored = d.ancorado
	end
	animarSoberano(d, nil, 0)
	d.soberano:SetAttribute("DueloIntencao", nil)
	d.soberano:SetAttribute("DueloInicio", nil)
	d.soberano:SetAttribute("Estado", "NPC_OCUPANTE")
	d.prompt.Enabled = true
	animarJogador(d, nil, 0)
	d.player:SetAttribute("EmDueloArena", nil)
	enviar(d, "fechar")
	Palco.liberar("monarca")
end

local function terminar(d: Sessao, resultado: string)
	if atual ~= d or d.fase == "fim" then
		return
	end
	d.fase = "fim"
	if d.motor then
		Motor.parar(d.motor)
	end
	local agora = workspace:GetServerTimeNow()
	d.soberano:SetAttribute("DueloIntencao", nil)
	if resultado == "vitoria" then
		animarSoberano(d, "derrota", agora)
		animarJogador(d, "vitoria", agora + 0.3)
	elseif resultado == "derrota" then
		animarJogador(d, "derrota", agora)
		animarSoberano(d, "vitoria", agora + 0.3)
	else
		animarSoberano(d, "vitoria", agora)
	end
	enviar(d, "fim", { resultado = resultado, estado = Duelo.visao(d.estado, "a") })
	if resultado == "vitoria" then
		task.spawn(Trono.vencerMonarca, d.player)
	end
	task.delay(MOSTRAR_RESULTADO, encerrar, d)
end

-- Corre até o Soberano e volta: chega no 1º acerto e volta antes do fim do golpe
local function mover(d: Sessao, avanco: number, ida: number, volta: number)
	local agora = workspace:GetServerTimeNow()
	local function tween(alvo: CFrame, duracao: number, estilo: Enum.EasingStyle)
		if atual ~= d or d.fase == "fim" then
			return
		end
		if d.tween then
			d.tween:Cancel()
		end
		local t = TweenService:Create(d.corpo, TweenInfo.new(duracao, estilo), { CFrame = alvo })
		d.tween = t
		t:Play()
	end
	local duracaoIda = math.max(0.1, (ida - agora) * 0.92)
	tween(d.posto * CFrame.new(0, 0, -avanco), duracaoIda, Enum.EasingStyle.Sine)
	task.delay(math.max(0, volta - agora - 0.35), function()
		tween(d.posto, 0.35, Enum.EasingStyle.Quad)
	end)
end

local function comecar(d: Sessao)
	if atual ~= d then
		return
	end
	d.fase = "luta"
	d.motor = Motor.iniciar({
		id = d.id,
		estado = d.estado,
		semEscolha = "derrota",
		a = {
			lado = "a",
			player = d.player,
			nome = d.player.DisplayName,
			animar = function(clipe, quando)
				animarJogador(d, clipe, quando)
			end,
			mover = function(avanco, ida, volta)
				mover(d, avanco, ida, volta)
			end,
		},
		b = {
			lado = "b",
			player = nil,
			nome = "Primeiro Soberano",
			animar = function(clipe, quando)
				animarSoberano(d, clipe, quando)
			end,
		},
		-- na vez do jogador o Soberano mostra o que vai fazer (aviso com o corpo)
		aoTurno = function(quem)
			d.soberano:SetAttribute(
				"DueloIntencao",
				if quem == "a" then Duelo.intencao(d.estado.vezesB + 1) else nil
			)
		end,
		aoFim = function(vencedor, motivo)
			terminar(
				d,
				if motivo == "tempo"
					then "tempo"
					elseif vencedor == "a" then "vitoria"
					else "derrota"
			)
		end,
	})
end

local function agir(player: Player, id: any, vez: any, acao: any): (boolean, string?)
	local d = atual
	if not d or d.player ~= player or d.id ~= id or not d.motor then
		return false, "Você não está neste duelo."
	end
	return Motor.escolher(player, id, vez, acao)
end

local function desistir(player: Player, id: any): (boolean, string?)
	local d = atual
	if not d or d.player ~= player or d.id ~= id then
		return false, "Você não está neste duelo."
	end
	encerrar(d)
	return true, nil
end

function Servico.iniciar()
	Motor.iniciarServico()
	PvP.iniciarServico()
	Trono.iniciar()
	Rankeada.iniciar()
	Acoes.registrar("ArenaAgir", agir)
	Acoes.registrar("ArenaSair", desistir)
	Players.PlayerRemoving:Connect(function(player)
		convites[player] = nil
		if atual and atual.player == player then
			encerrar(atual)
		end
	end)
end

function Servico.montar(soberano: BasePart, ponto: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Desafiar"
	prompt.ActionText = "Desafiar"
	prompt.ObjectText = "Primeiro Soberano"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = DISTANCIA
	prompt.RequiresLineOfSight = false
	prompt.Parent = ponto

	-- Painel da Arena (Trono do Servidor, Rankeada e ranking global): o cliente abre sozinho
	local painel = Instance.new("ProximityPrompt")
	painel.Name = "PainelArena"
	painel.ActionText = "Trono e Rankeada"
	painel.ObjectText = "Arena"
	painel.KeyboardKeyCode = Enum.KeyCode.G
	painel.GamepadKeyCode = Enum.KeyCode.ButtonX
	painel.MaxActivationDistance = DISTANCIA
	painel.RequiresLineOfSight = false
	painel.UIOffset = Vector2.new(0, 72)
	painel.Parent = ponto

	local ultimoAlerta = -math.huge
	prompt.Triggered:Connect(function(player)
		local personagem = personagemPerto(player, ponto)
		if atual or not prompt.Enabled or not personagem then
			return
		end
		if Palco.ocupado() then
			Remotos.evento("Aviso"):FireClient(player, {
				tipo = "info",
				texto = "O ringue está ocupado com um duelo. Aguarde um pouco.",
			})
			return
		end
		local agora = workspace:GetServerTimeNow()
		local anterior = convites[player]
		if anterior and agora < anterior.venceEm - TEMPO_DIALOGO + INTERVALO_INTERACAO then
			return
		end
		contador += 1
		local convite = { id = contador, personagem = personagem, venceEm = agora + TEMPO_DIALOGO }
		convites[player] = convite
		task.delay(TEMPO_DIALOGO, function()
			if convites[player] == convite then
				convites[player] = nil
			end
		end)
		if agora - ultimoAlerta >= INTERVALO_ALERTA then
			ultimoAlerta = agora
			soberano:SetAttribute("Alerta", agora)
		end
		Remotos.evento("Arena"):FireClient(player, {
			tipo = "dialogo",
			id = convite.id,
			prazo = convite.venceEm,
		})
	end)

	Acoes.registrar("ArenaResponder", function(player, id: any, resposta: any): (boolean, string?)
		if type(id) ~= "number" or (resposta ~= "duelar" and resposta ~= "fugir") then
			return false, "Resposta inválida."
		end
		local convite = convites[player]
		if not convite or convite.id ~= id then
			return false, "Fale com o Soberano para responder."
		end
		convites[player] = nil
		local personagem, corpo, humanoide = personagemPerto(player, ponto)
		if
			not personagem
			or not corpo
			or not humanoide
			or personagem ~= convite.personagem
			or workspace:GetServerTimeNow() >= convite.venceEm
		then
			return false, "Aproxime-se do Soberano e abra o diálogo de novo."
		end
		if Incursoes.ocupado(player) then
			return false, "Saia das Incursões antes de responder ao Soberano."
		end

		local altura = alturaDoCorpo(personagem, corpo, humanoide)
		if resposta == "fugir" then
			local destino = Cena.referencia * CFrame.new(0, altura + 0.6, -22)
			personagem:PivotTo(destino * corpo.CFrame:ToObjectSpace(personagem:GetPivot()))
			corpo.AssemblyLinearVelocity = Vector3.zero
			corpo.AssemblyAngularVelocity = Vector3.zero
			return true, nil
		end

		if atual or not prompt.Enabled or Palco.ocupado() then
			return false, "O ringue está ocupado. Aguarde a Arena ficar livre."
		end
		if player:GetAttribute("EmDueloArena") then
			return false, "Termine o duelo atual primeiro."
		end
		local perfil = Dados.de(player)
		if not perfil then
			return false, "Aguarde seu perfil carregar para desafiar o Soberano."
		end
		if not Palco.reservar("monarca") then
			return false, "O ringue está ocupado. Aguarde a Arena ficar livre."
		end

		local d: Sessao = {
			id = convite.id,
			player = player,
			personagem = personagem,
			corpo = corpo,
			humanoide = humanoide,
			original = personagem:GetPivot(),
			posto = Cena.jogador + Vector3.new(0, altura, 0),
			ancorado = corpo.Anchored,
			soberano = soberano,
			prompt = prompt,
			aura = if perfil.equipada then Auras.porId[perfil.equipada] else nil,
			estado = Duelo.novo(),
			fase = "entrada",
			conexoes = {},
		}
		atual = d
		player:SetAttribute("EmDueloArena", true)
		prompt.Enabled = false
		corpo.Anchored = true
		personagem:PivotTo(d.posto * corpo.CFrame:ToObjectSpace(d.original))
		local inicio = workspace:GetServerTimeNow()
		animarSoberano(d, nil, 0)
		soberano:SetAttribute("DueloIntencao", nil)
		soberano:SetAttribute("DueloInicio", inicio)
		animarJogador(d, "entrada", inicio)
		soberano:SetAttribute("Estado", "DESAFIO_EM_ANDAMENTO")

		table.insert(
			d.conexoes,
			humanoide.Died:Connect(function()
				encerrar(d)
			end)
		)
		table.insert(
			d.conexoes,
			player.CharacterRemoving:Connect(function()
				encerrar(d)
			end)
		)
		enviar(d, "abrir", {
			estado = Duelo.visao(d.estado, "a"),
			lado = "a",
			oponente = "Primeiro Soberano",
			titulo = "Duelo pelo Trono",
			nome = player.DisplayName,
			aura = if d.aura then d.aura.nome else nil,
			cor = if d.aura then d.aura.cores[1] else nil,
			estilo = if d.aura then d.aura.estilo else nil,
		})
		task.delay(INTRODUCAO, comecar, d)
		return true, nil
	end)
end

return Servico
