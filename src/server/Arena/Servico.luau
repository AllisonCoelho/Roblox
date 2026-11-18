-- Um duelo de cada vez no palco compartilhado. O cliente só informa a ação escolhida.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Dados.Arena)
local Cena = require(Shared.Dados.ArenaCena)
local Auras = require(Shared.Dados.Auras)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent.Servicos
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local Incursoes = require(script.Parent.Parent.Incursoes.Servico)

local Servico = {}
local INTRODUCAO = 1.8
local MOSTRAR_RESULTADO = 5
local DISTANCIA = 16
local FOLGA_DISTANCIA = 3
local TEMPO_DIALOGO = 30
local INTERVALO_INTERACAO = 0.8
local INTERVALO_ALERTA = 25

type Duelo = {
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
	estado: Arena.Estado,
	fase: string,
	prazo: number?,
	aura: Auras.Aura?,
	conexoes: { RBXScriptConnection },
	tween: Tween?,
}

local atual: Duelo? = nil
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

local function enviar(d: Duelo, tipo: string, dados: { [string]: any }?)
	if d.player.Parent ~= Players then
		return
	end
	local pacote = dados or {}
	pacote.id = d.id
	pacote.tipo = tipo
	Remotos.evento("Arena"):FireClient(d.player, pacote)
end

local function encerrar(d: Duelo)
	if atual ~= d then
		return
	end
	atual = nil
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
	d.soberano:SetAttribute("DueloGolpe", nil)
	d.soberano:SetAttribute("DueloIntencao", nil)
	d.soberano:SetAttribute("DueloInicio", nil)
	d.soberano:SetAttribute("Estado", "NPC_OCUPANTE")
	d.prompt.Enabled = true
	d.player:SetAttribute("EmDueloArena", nil)
	enviar(d, "fechar")
end

local function terminar(d: Duelo, resultado: string)
	if atual ~= d then
		return
	end
	d.fase = "fim"
	d.prazo = nil
	if resultado == "vitoria" then
		d.soberano:SetAttribute("DueloGolpe", "derrota")
		d.soberano:SetAttribute("DueloGolpeEm", workspace:GetServerTimeNow())
	end
	enviar(d, "fim", { resultado = resultado, estado = d.estado })
	task.delay(MOSTRAR_RESULTADO, encerrar, d)
end

local function abrirTurno(d: Duelo)
	if atual ~= d then
		return
	end
	d.fase = "escolha"
	d.soberano:SetAttribute("DueloGolpe", nil)
	d.soberano:SetAttribute("DueloIntencao", Arena.intencao(d.estado.rodada).id)
	local prazo = workspace:GetServerTimeNow() + Arena.ESPERA_TURNO
	d.prazo = prazo
	enviar(d, "turno", { estado = d.estado, prazo = prazo })
	task.delay(Arena.ESPERA_TURNO, function()
		if atual == d and d.fase == "escolha" and d.prazo == prazo then
			terminar(d, "tempo")
		end
	end)
end

local function mover(d: Duelo, alvo: CFrame, duracao: number, estilo: Enum.EasingStyle)
	if d.tween then
		d.tween:Cancel()
	end
	local tween = TweenService:Create(d.corpo, TweenInfo.new(duracao, estilo), { CFrame = alvo })
	d.tween = tween
	tween:Play()
end

local function encenar(d: Duelo, resolucao: Arena.Resolucao)
	for _, golpe in resolucao.golpes do
		if atual ~= d then
			return
		end
		local preparacao = if golpe.especial then 0.46 else 0.27
		local retorno = if golpe.especial then 0.62 else 0.42
		local quando = workspace:GetServerTimeNow()
		d.soberano:SetAttribute("DueloIntencao", nil)
		if golpe.ator == "soberano" then
			d.soberano:SetAttribute("DueloGolpeEm", quando)
			d.soberano:SetAttribute("DueloGolpe", golpe.id)
		end
		enviar(d, "golpe", {
			golpe = golpe,
			impacto = quando + preparacao,
			fim = quando + preparacao + retorno,
		})
		local avancou = golpe.ator == "jogador" and (golpe.id == "ataque" or golpe.id == "corte")
		if avancou then
			mover(d, d.posto * CFrame.new(0, 0, -9), preparacao, Enum.EasingStyle.Quad)
		end
		task.wait(preparacao)
		if atual ~= d then
			return
		end
		d.estado = golpe.estado
		if avancou then
			mover(d, d.posto, retorno - 0.08, Enum.EasingStyle.Sine)
		end
		task.wait(retorno)
	end
	if atual ~= d then
		return
	end
	d.soberano:SetAttribute("DueloGolpe", nil)
	d.estado = resolucao.estado
	if resolucao.resultado then
		terminar(d, resolucao.resultado)
	else
		abrirTurno(d)
	end
end

local function agir(player: Player, id: any, rodada: any, acao: any): (boolean, string?)
	local d = atual
	if not d or d.player ~= player or d.id ~= id then
		return false, "Você não está neste duelo."
	end
	if d.fase ~= "escolha" or d.estado.rodada ~= rodada then
		return false, "Aguarde o seu próximo turno."
	end
	if not d.prazo or workspace:GetServerTimeNow() >= d.prazo then
		terminar(d, "tempo")
		return false, "O tempo acabou."
	end
	if type(acao) ~= "string" then
		return false, "Ação inválida."
	end
	local resolucao, erro = Arena.resolver(d.estado, acao)
	if not resolucao then
		return false, erro
	end
	d.fase = "resolvendo"
	d.prazo = nil
	task.spawn(function()
		local ok, erroCena = pcall(encenar, d, resolucao)
		if not ok then
			warn("[Arena] " .. tostring(erroCena))
			encerrar(d)
		end
	end)
	return true, nil
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

	local ultimoAlerta = -math.huge
	prompt.Triggered:Connect(function(player)
		local personagem = personagemPerto(player, ponto)
		if atual or not prompt.Enabled or not personagem then
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

		if atual or not prompt.Enabled then
			return false, "O Soberano já está em duelo. Aguarde a Arena ficar livre."
		end
		local perfil = Dados.de(player)
		if not perfil then
			return false, "Aguarde seu perfil carregar para desafiar o Soberano."
		end

		local d: Duelo = {
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
			estado = Arena.novo(),
			fase = "entrada",
			conexoes = {},
		}
		atual = d
		player:SetAttribute("EmDueloArena", true)
		prompt.Enabled = false
		corpo.Anchored = true
		personagem:PivotTo(d.posto * corpo.CFrame:ToObjectSpace(d.original))
		soberano:SetAttribute("DueloGolpe", nil)
		soberano:SetAttribute("DueloIntencao", nil)
		soberano:SetAttribute("DueloInicio", workspace:GetServerTimeNow())
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
			estado = d.estado,
			nome = player.DisplayName,
			aura = if d.aura then d.aura.nome else nil,
			cor = if d.aura then d.aura.cores[1] else nil,
			estilo = if d.aura then d.aura.estilo else nil,
		})
		task.delay(INTRODUCAO, abrirTurno, d)
		return true, nil
	end)
end

return Servico
