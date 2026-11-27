-- Duelo 1x1 entre jogadores no ringue da Arena (regras em Shared/Dados/ArenaPvP). Serve ao Trono
-- do Servidor e à Rankeada: quem chama decide o que acontece no fim (aoFim).
--
-- O combate é o reativo (Dados/Duelo e Motor), o mesmo do duelo contra o Soberano: vez a vez,
-- golpe no tempo certo, Esquivar e Aparar. O dano segue a Pontuação de Aura (ArenaPvP). Quem não
-- escolher no prazo Concentra. As animações vêm dos atributos ArenaAnim/ArenaAnimEm de cada
-- Player e cada um recebe a tela do seu ponto de vista pelo evento "Arena" (pvp = true).
-- Sair, morrer, trocar de personagem ou sair do jogo conta como desistência.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaPvP = require(Shared.Dados.ArenaPvP)
local Duelo = require(Shared.Dados.Duelo)
local Animacoes = require(Shared.Dados.ArenaAnimacoes)
local Cena = require(Shared.Dados.ArenaCena)
local Auras = require(Shared.Dados.Auras)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent.Servicos
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local PontosAura = require(Servicos.PontosAura)
local Incursoes = require(script.Parent.Parent.Incursoes.Servico)
local Corredor = require(script.Parent.Parent.Corredor.Servico)
local Palco = require(script.Parent.Palco)
local Motor = require(script.Parent.Motor)

local PvP = {}

local MOSTRAR_RESULTADO = 5
local NOME_PALCO = "pvp"

type Lutador = {
	player: Player,
	lado: string,
	personagem: Model,
	corpo: BasePart,
	humanoide: Humanoid,
	original: CFrame,
	posto: CFrame,
	ancorado: boolean,
	aura: Auras.Aura?,
	tween: Tween?,
}
export type Fim = (vencedor: Player?, perdedor: Player?, motivo: string) -> { [Player]: string }?
export type Opcoes = { modo: string, titulo: string, aoFim: Fim }
type Sessao = {
	id: number,
	a: Lutador,
	b: Lutador,
	estado: Duelo.Estado,
	motor: Motor.Duelo?,
	op: Opcoes,
	conexoes: { RBXScriptConnection },
	terminado: boolean,
}

local atual: Sessao? = nil
local contador = 0

function PvP.emDuelo(player: Player): boolean
	local d = atual
	return d ~= nil and (d.a.player == player or d.b.player == player)
end

-- O jogador pode ser levado ao ringue agora? (vivo, perfil carregado, livre)
function PvP.disponivel(player: Player): (boolean, string?)
	local personagem = player.Character
	local corpo = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not corpo or not corpo:IsA("BasePart") or not humanoide or humanoide.Health <= 0 then
		return false, "personagem"
	end
	if not Dados.de(player) then
		return false, "perfil"
	end
	if player:GetAttribute("EmDueloArena") or Incursoes.ocupado(player) then
		return false, "ocupado"
	end
	return true, nil
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

local function lutador(player: Player, lado: string): Lutador?
	local personagem = player.Character
	local corpo = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if
		not personagem
		or not corpo
		or not corpo:IsA("BasePart")
		or not humanoide
		or humanoide.Health <= 0
	then
		return nil
	end
	local altura = alturaDoCorpo(personagem, corpo, humanoide)
	local base = if lado == "a" then Cena.jogador else Cena.soberano
	local original = personagem:GetPivot()
	-- quem vinha do Corredor volta para a entrada da Arena (não para a ilha)
	if player:GetAttribute("CorredorFase") then
		Corredor.liberar(player)
		original = Cena.referencia * CFrame.new(0, altura + 0.6, -22)
	end
	local perfil = Dados.de(player)
	return {
		player = player,
		lado = lado,
		personagem = personagem,
		corpo = corpo,
		humanoide = humanoide,
		original = original,
		posto = base + Vector3.new(0, altura, 0),
		ancorado = corpo.Anchored,
		aura = if perfil and perfil.equipada then Auras.porId[perfil.equipada] else nil,
	}
end

local function outro(d: Sessao, l: Lutador): Lutador
	return if l == d.a then d.b else d.a
end

local function enviar(d: Sessao, l: Lutador, tipo: string, dados: { [string]: any }?)
	if l.player.Parent ~= Players then
		return
	end
	local pacote = dados or {}
	pacote.id = d.id
	pacote.tipo = tipo
	pacote.pvp = true
	Remotos.evento("Arena"):FireClient(l.player, pacote)
end

local function animar(l: Lutador, clipe: string?, quando: number)
	l.player:SetAttribute("ArenaAnim", clipe)
	l.player:SetAttribute("ArenaAnimEm", if clipe then quando else nil)
end

local function mover(l: Lutador, alvo: CFrame, duracao: number, estilo: Enum.EasingStyle)
	if l.tween then
		l.tween:Cancel()
	end
	local tween = TweenService:Create(l.corpo, TweenInfo.new(duracao, estilo), { CFrame = alvo })
	l.tween = tween
	tween:Play()
end

local function devolver(l: Lutador)
	if l.tween then
		l.tween:Cancel()
	end
	if l.corpo.Parent and l.player.Character == l.personagem then
		if l.humanoide.Health > 0 then
			l.personagem:PivotTo(l.original)
			l.corpo.AssemblyLinearVelocity = Vector3.zero
			l.corpo.AssemblyAngularVelocity = Vector3.zero
		end
		l.corpo.Anchored = l.ancorado
	end
	animar(l, nil, 0)
	l.player:SetAttribute("EmDueloArena", nil)
end

local function encerrar(d: Sessao)
	if atual ~= d then
		return
	end
	atual = nil
	if d.motor then
		Motor.parar(d.motor)
	end
	for _, c in d.conexoes do
		c:Disconnect()
	end
	for _, l in { d.a, d.b } do
		devolver(l)
		enviar(d, l, "fechar")
	end
	Palco.liberar(NOME_PALCO)
end

local function terminar(d: Sessao, vencedor: Lutador?, motivo: string)
	if atual ~= d or d.terminado then
		return
	end
	d.terminado = true
	if d.motor then
		Motor.parar(d.motor)
	end
	local perdedor = if vencedor then outro(d, vencedor) else nil
	local agora = Workspace:GetServerTimeNow()
	if vencedor and perdedor then
		animar(perdedor, "derrota", agora)
		animar(vencedor, "vitoria", agora + 0.3)
	end
	local ok, detalhes = pcall(
		d.op.aoFim,
		if vencedor then vencedor.player else nil,
		if perdedor then perdedor.player else nil,
		motivo
	)
	if not ok then
		warn("[ArenaPvP] " .. tostring(detalhes))
		detalhes = nil
	end
	for _, l in { d.a, d.b } do
		enviar(d, l, "fim", {
			resultado = if vencedor == l then "vitoria" elseif vencedor then "derrota" else "tempo",
			motivo = motivo,
			detalhe = if detalhes then (detalhes :: any)[l.player] else nil,
			estado = Duelo.visao(d.estado, l.lado),
			oponente = outro(d, l).player.DisplayName,
		})
	end
	task.delay(MOSTRAR_RESULTADO, encerrar, d)
end

local function ladoDe(d: Sessao, player: Player): Lutador?
	return if d.a.player == player then d.a elseif d.b.player == player then d.b else nil
end

local function agir(player: Player, id: any, vez: any, acao: any): (boolean, string?)
	local d = atual
	if not d or not ladoDe(d, player) or d.id ~= id or not d.motor then
		return false, "Você não está neste duelo."
	end
	return Motor.escolher(player, id, vez, acao)
end

local function desistir(player: Player, id: any): (boolean, string?)
	local d = atual
	local l = if d then ladoDe(d, player) else nil
	if not d or not l or d.id ~= id then
		return false, "Você não está neste duelo."
	end
	if d.terminado then
		encerrar(d)
	else
		terminar(d, outro(d, l), "desistencia")
	end
	return true, nil
end

local function comecar(d: Sessao)
	if atual ~= d or d.terminado then
		return
	end
	local function como(l: Lutador): Motor.Lutador
		return {
			lado = l.lado,
			player = l.player,
			nome = l.player.DisplayName,
			animar = function(clipe, quando)
				animar(l, clipe, quando)
			end,
			mover = function(avanco, duracao)
				mover(l, l.posto * CFrame.new(0, 0, -avanco), duracao, Enum.EasingStyle.Sine)
			end,
		}
	end
	d.motor = Motor.iniciar({
		id = d.id,
		estado = d.estado,
		semEscolha = "concentrar",
		a = como(d.a),
		b = como(d.b),
		aoFim = function(vencedor, motivo)
			terminar(
				d,
				if vencedor == "a" then d.a elseif vencedor == "b" then d.b else nil,
				motivo
			)
		end,
	})
end

-- Começa um duelo entre `pa` (lado do desafiante) e `pb`. Falha se o ringue estiver ocupado
-- ou se alguém não puder lutar agora.
function PvP.iniciar(pa: Player, pb: Player, op: Opcoes): (boolean, string?)
	if pa == pb then
		return false, "Duelo inválido."
	end
	for _, p in { pa, pb } do
		local ok, motivo = PvP.disponivel(p)
		if not ok then
			return false, motivo
		end
	end
	if not Palco.reservar(NOME_PALCO) then
		return false, "palco"
	end
	local a, b = lutador(pa, "a"), lutador(pb, "b")
	if not a or not b then
		Palco.liberar(NOME_PALCO)
		return false, "personagem"
	end
	contador += 1
	local pontA, pontB = PontosAura.pontuacao(pa), PontosAura.pontuacao(pb)
	local multA, multB = ArenaPvP.multiplicadores(pontA, pontB)
	local d: Sessao = {
		id = 100000 + contador, -- não colide com os ids do duelo contra o Soberano
		a = a,
		b = b,
		estado = Duelo.novo(multA, multB, pontA, pontB),
		motor = nil,
		op = op,
		conexoes = {},
		terminado = false,
	}
	atual = d
	local inicio = Workspace:GetServerTimeNow()
	for _, l in { a, b } do
		l.player:SetAttribute("EmDueloArena", true)
		l.corpo.Anchored = true
		l.personagem:PivotTo(l.posto * l.corpo.CFrame:ToObjectSpace(l.personagem:GetPivot()))
		animar(l, "entrada", inicio)
		local function cair()
			if atual == d and not d.terminado then
				terminar(d, outro(d, l), "desistencia")
			elseif atual == d then
				encerrar(d)
			end
		end
		table.insert(d.conexoes, l.humanoide.Died:Connect(cair))
		table.insert(d.conexoes, l.player.CharacterRemoving:Connect(cair))
	end
	for _, l in { a, b } do
		local o = outro(d, l)
		enviar(d, l, "abrir", {
			estado = Duelo.visao(d.estado, l.lado),
			nome = l.player.DisplayName,
			oponente = o.player.DisplayName,
			lado = l.lado,
			modo = op.modo,
			titulo = op.titulo,
			aura = if l.aura then l.aura.nome else nil,
			cor = if l.aura then l.aura.cores[1] else nil,
			estilo = if l.aura then l.aura.estilo else nil,
		})
	end
	task.delay(Animacoes.INTRODUCAO, comecar, d)
	return true, nil
end

function PvP.iniciarServico()
	Acoes.registrar("PvPAgir", agir)
	Acoes.registrar("PvPSair", desistir)
	Players.PlayerRemoving:Connect(function(player)
		local d = atual
		local l = if d then ladoDe(d, player) else nil
		if d and l then
			if d.terminado then
				encerrar(d)
			else
				terminar(d, outro(d, l), "desistencia")
			end
		end
	end)
end

return PvP
