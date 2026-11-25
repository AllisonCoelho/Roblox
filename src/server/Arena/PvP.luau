-- Duelo 1x1 entre jogadores no ringue da Arena (regras em Shared/Dados/ArenaPvP). Serve ao Trono
-- do Servidor e à Rankeada: quem chama decide o que acontece no fim (aoFim).
--
-- Os dois escolhem ao mesmo tempo; quem não escolher no prazo faz Guarda. O servidor encena os dois
-- golpes com as mesmas animações do duelo contra o Soberano (atributos ArenaAnim/ArenaAnimEm de cada
-- Player) e manda a cada um a tela do seu ponto de vista pelo evento "Arena" (pvp = true).
-- Sair, morrer, trocar de personagem ou sair do jogo conta como desistência.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaPvP = require(Shared.Dados.ArenaPvP)
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
type Duelo = {
	id: number,
	a: Lutador,
	b: Lutador,
	estado: ArenaPvP.Estado,
	fase: string,
	prazo: number?,
	escolhas: { [string]: string },
	op: Opcoes,
	conexoes: { RBXScriptConnection },
	terminado: boolean,
}

local atual: Duelo? = nil
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

local function outro(d: Duelo, l: Lutador): Lutador
	return if l == d.a then d.b else d.a
end

local function enviar(d: Duelo, l: Lutador, tipo: string, dados: { [string]: any }?)
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

local function encerrar(d: Duelo)
	if atual ~= d then
		return
	end
	atual = nil
	for _, c in d.conexoes do
		c:Disconnect()
	end
	for _, l in { d.a, d.b } do
		devolver(l)
		enviar(d, l, "fechar")
	end
	Palco.liberar(NOME_PALCO)
end

local function terminar(d: Duelo, vencedor: Lutador?, motivo: string)
	if atual ~= d or d.terminado then
		return
	end
	d.terminado = true
	d.fase = "fim"
	d.prazo = nil
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
			estado = ArenaPvP.visao(d.estado, l.lado),
			oponente = outro(d, l).player.DisplayName,
		})
	end
	task.delay(MOSTRAR_RESULTADO, encerrar, d)
end

local resolver: (Duelo) -> ()

local function abrirTurno(d: Duelo)
	if atual ~= d or d.terminado then
		return
	end
	d.fase = "escolha"
	d.escolhas = {}
	local prazo = Workspace:GetServerTimeNow() + ArenaPvP.ESPERA_TURNO
	d.prazo = prazo
	for _, l in { d.a, d.b } do
		enviar(d, l, "turno", { estado = ArenaPvP.visao(d.estado, l.lado), prazo = prazo })
	end
	task.delay(ArenaPvP.ESPERA_TURNO, function()
		if atual == d and d.fase == "escolha" and d.prazo == prazo then
			resolver(d)
		end
	end)
end

local function encenar(d: Duelo, r: ArenaPvP.Resolucao, acoes: { [string]: string })
	for _, golpe in r.golpes do
		if atual ~= d or d.terminado then
			return
		end
		local atacante = if golpe.lado == "a" then d.a else d.b
		local defensor = outro(d, atacante)
		local tempo = Animacoes.tempo(golpe.id)
		local preparacao, retorno = tempo.preparo, tempo.retorno
		local quando = Workspace:GetServerTimeNow()
		local impacto = quando + preparacao
		animar(atacante, golpe.id, quando)
		local vidaDefensor = if defensor.lado == "a"
			then golpe.estado.a.vida
			else golpe.estado.b.vida
		if golpe.id ~= "guarda" and vidaDefensor > 0 then
			local reacao = Animacoes.reacaoJogador(acoes[defensor.lado] == "guarda", golpe.dano)
			if reacao then
				animar(defensor, reacao, impacto)
			end
		end
		for _, l in { d.a, d.b } do
			enviar(d, l, "golpe", {
				golpe = {
					id = golpe.id,
					nome = golpe.nome,
					ator = if l == atacante then "jogador" else "soberano",
					lado = golpe.lado,
					dano = golpe.dano,
					especial = golpe.especial,
					estado = ArenaPvP.visao(golpe.estado, l.lado),
				},
				impacto = impacto,
				fim = impacto + retorno,
			})
		end
		local avanco = Animacoes.AVANCO[golpe.id]
		if avanco then
			mover(
				atacante,
				atacante.posto * CFrame.new(0, 0, -avanco),
				preparacao * 0.92,
				Enum.EasingStyle.Sine
			)
		end
		task.wait(preparacao)
		if atual ~= d or d.terminado then
			return
		end
		if avanco then
			task.wait(retorno * 0.3)
			mover(atacante, atacante.posto, retorno * 0.55, Enum.EasingStyle.Quad)
			task.wait(retorno * 0.7)
		else
			task.wait(retorno)
		end
	end
	if atual ~= d or d.terminado then
		return
	end
	d.estado = r.estado
	if r.vencedor then
		terminar(d, if r.vencedor == "a" then d.a else d.b, "nocaute")
	else
		abrirTurno(d)
	end
end

resolver = function(d: Duelo)
	if atual ~= d or d.fase ~= "escolha" then
		return
	end
	d.fase = "resolvendo"
	d.prazo = nil
	local acoes = {
		a = ArenaPvP.ouGuarda(d.estado, "a", d.escolhas.a),
		b = ArenaPvP.ouGuarda(d.estado, "b", d.escolhas.b),
	}
	local r = ArenaPvP.resolver(d.estado, acoes.a, acoes.b)
	task.spawn(function()
		local ok, erro = pcall(encenar, d, r, acoes)
		if not ok then
			warn("[ArenaPvP] " .. tostring(erro))
			encerrar(d)
		end
	end)
end

local function ladoDe(d: Duelo, player: Player): Lutador?
	return if d.a.player == player then d.a elseif d.b.player == player then d.b else nil
end

local function agir(player: Player, id: any, rodada: any, acao: any): (boolean, string?)
	local d = atual
	local l = if d then ladoDe(d, player) else nil
	if not d or not l or d.id ~= id then
		return false, "Você não está neste duelo."
	end
	if d.fase ~= "escolha" or d.estado.rodada ~= rodada then
		return false, "Aguarde o próximo turno."
	end
	if d.escolhas[l.lado] then
		return false, "Você já escolheu nesta rodada."
	end
	local problema = ArenaPvP.validar(d.estado, l.lado, acao)
	if problema then
		return false, problema
	end
	d.escolhas[l.lado] = acao
	enviar(d, outro(d, l), "escolheu", { rodada = rodada })
	if d.escolhas.a and d.escolhas.b then
		resolver(d)
	end
	return true, nil
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
	local d: Duelo = {
		id = 100000 + contador, -- não colide com os ids do duelo contra o Soberano
		a = a,
		b = b,
		estado = ArenaPvP.novo(PontosAura.pontuacao(pa), PontosAura.pontuacao(pb)),
		fase = "entrada",
		escolhas = {},
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
			estado = ArenaPvP.visao(d.estado, l.lado),
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
	task.delay(Animacoes.INTRODUCAO, abrirTurno, d)
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
