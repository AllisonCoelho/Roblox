-- Motor do combate reativo da Arena (regras em Shared/Dados/Duelo). Serve ao duelo contra o
-- Primeiro Soberano (o lado "b" é o NPC) e ao 1x1 entre jogadores (Trono e Rankeada).
--
-- Cada vez: quem joga escolhe a ação (o Soberano segue o seu ciclo). O servidor anuncia o golpe
-- com os instantes de cada acerto (relógio do servidor), toca as animações e espera as entradas:
-- quem golpeia toca no anel (golpe no tempo certo) e quem defende Esquiva ou Apara. As entradas
-- chegam pelo evento "DueloEntrada" com o horário do toque no relógio do servidor; o servidor
-- confere esse horário com o de chegada menos o ping e, se não bater, usa a própria estimativa.
-- Depois da janela de cada acerto o servidor decide o resultado e avisa todos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Duelo = require(Shared.Dados.Duelo)
local Animacoes = require(Shared.Dados.ArenaAnimacoes)
local Remotos = require(Shared.Remotos)

local Motor = {}

local FOLGA_REDE = 0.12 -- espera extra depois da janela de cada acerto
local TOLERANCIA_RELOGIO = 0.3 -- diferença aceita entre o horário do cliente e a estimativa
local PAUSA_SOBERANO = 0.9 -- o Soberano "pensa" antes de golpear

export type Lutador = {
	lado: string,
	player: Player?, -- nil = Primeiro Soberano
	nome: string,
	animar: (clipe: string?, quando: number) -> (),
	-- corre até o alvo e volta (opcional): avanço em studs, chegada no 1º acerto, volta no fim
	mover: ((avanco: number, ida: number, volta: number) -> ())?,
}
export type Opcoes = {
	id: number,
	a: Lutador,
	b: Lutador,
	estado: Duelo.Estado,
	-- sem escolha no prazo: "derrota" (contra o Soberano) ou "concentrar" (no 1x1)
	semEscolha: string,
	aoTurno: ((quem: string) -> ())?, -- avisa quem chama (ex.: a intenção do Soberano)
	aoFim: (vencedor: string?, motivo: string) -> (),
}
type Golpe = {
	quem: string,
	acao: string,
	tempos: { number }, -- instante de cada acerto (relógio do servidor)
	qte: { [number]: number }, -- desvio do toque em cada marca
	defesa: { [number]: { tipo: string, desvio: number } },
}
export type Duelo = {
	op: Opcoes,
	estado: Duelo.Estado,
	ativo: boolean,
	escolha: string?,
	esperando: string?, -- lado que está escolhendo
	golpe: Golpe?,
}

local ativos: { [Player]: Duelo } = {}

local function lutador(d: Duelo, q: string): Lutador
	return if q == "a" then d.op.a else d.op.b
end

local function enviar(d: Duelo, q: string, tipo: string, dados: { [string]: any }?)
	local l = lutador(d, q)
	local p = l.player
	if not p or p.Parent ~= Players then
		return
	end
	local pacote = dados or {}
	pacote.id = d.op.id
	pacote.tipo = tipo
	pacote.lado = q
	pacote.estado = Duelo.visao(d.estado, q)
	Remotos.evento("Arena"):FireClient(p, pacote)
end

local function enviarTodos(d: Duelo, tipo: string, montar: (q: string) -> { [string]: any })
	for _, q in { "a", "b" } do
		enviar(d, q, tipo, montar(q))
	end
end

local function esperarAte(d: Duelo, instante: number): boolean
	while d.ativo do
		local falta = instante - Workspace:GetServerTimeNow()
		if falta <= 0 then
			return true
		end
		task.wait(math.min(falta, 0.05))
	end
	return false
end

local function clipeDe(l: Lutador, id: string): Animacoes.Clipe?
	return if l.player then Animacoes.JOGADOR[id] else Animacoes.SOBERANO[id]
end

local function reacao(l: Lutador, defesa: string, dano: number): string?
	if defesa == "aparado" then
		return if l.player then "aparar" else nil
	elseif defesa == "esquivado" then
		return if l.player then "esquiva" else nil
	elseif dano >= 180 then
		return "atingidoForte"
	elseif dano > 0 then
		return "atingido"
	end
	return nil
end

-- Uma entrada do jogador (toque no anel ou defesa). Vale a primeira para cada acerto.
function Motor.entrada(player: Player, id: any, tipo: any, tempoCliente: any)
	local d = ativos[player]
	local g = d and d.golpe
	if not d or not g or d.op.id ~= id then
		return
	end
	if tipo ~= "qte" and tipo ~= "esquivar" and tipo ~= "aparar" then
		return
	end
	local q = if d.op.a.player == player then "a" else "b"
	local chegada = Workspace:GetServerTimeNow()
	local estimativa = chegada - math.clamp(player:GetNetworkPing(), 0, 0.5)
	local t = estimativa
	if
		type(tempoCliente) == "number"
		and math.abs(tempoCliente - estimativa) <= TOLERANCIA_RELOGIO
	then
		t = tempoCliente
	end
	local acao = Duelo.ACOES[g.acao]
	if q == g.quem then
		if tipo ~= "qte" or not acao.marcas then
			return
		end
		-- a marca mais perto ainda sem toque
		local melhor, menor = nil, math.huge
		for _, m in acao.marcas do
			local desvio = t - g.tempos[m]
			if
				g.qte[m] == nil
				and desvio >= -Duelo.JANELA.antes
				and desvio <= Duelo.JANELA.depois
			then
				if math.abs(desvio) < menor then
					melhor, menor = m, math.abs(desvio)
				end
			end
		end
		if melhor then
			g.qte[melhor] = t - g.tempos[melhor]
		end
	else
		if tipo == "qte" then
			return
		end
		local melhor, menor = nil, math.huge
		for i, tempo in g.tempos do
			local desvio = t - tempo
			if
				g.defesa[i] == nil
				and desvio >= -Duelo.JANELA.antes
				and desvio <= Duelo.JANELA.depois
			then
				if math.abs(desvio) < menor then
					melhor, menor = i, math.abs(desvio)
				end
			end
		end
		if melhor then
			g.defesa[melhor] = { tipo = tipo, desvio = t - g.tempos[melhor] }
		end
	end
end

-- Escolha da ação na vez do jogador
function Motor.escolher(player: Player, id: any, vez: any, acao: any): (boolean, string?)
	local d = ativos[player]
	if not d or d.op.id ~= id then
		return false, "Você não está neste duelo."
	end
	local q = if d.op.a.player == player then "a" else "b"
	if d.esperando ~= q or d.estado.vez ~= vez then
		return false, "Aguarde a sua vez."
	end
	local problema = Duelo.validar(d.estado, q, acao)
	if problema then
		return false, problema
	end
	d.escolha = acao
	return true, nil
end

-- Um golpe completo (anúncio, acertos, efeitos). Devolve as defesas de cada acerto.
local function golpear(d: Duelo, q: string, id: string, inicio: number): { string }
	local e = d.estado
	local acao = Duelo.ACOES[id]
	local atk = lutador(d, q)
	local alvo = lutador(d, Duelo.outro(q))
	local tempos = {}
	for i, t in acao.acertos do
		tempos[i] = inicio + t
	end
	local g: Golpe = { quem = q, acao = id, tempos = tempos, qte = {}, defesa = {} }
	d.golpe = g
	enviarTodos(d, "golpe", function(lado)
		return {
			acao = id,
			nome = acao.nome,
			eu = lado == q,
			inicio = inicio,
			acertos = tempos,
			marcas = acao.marcas,
			absoluto = acao.absoluto == true,
		}
	end)
	atk.animar(id, inicio)
	if acao.avanco and atk.mover and #tempos > 0 then
		local clipe = clipeDe(atk, id)
		atk.mover(acao.avanco, tempos[1], inicio + (if clipe then clipe.duracao else 1) - 0.25)
	end
	local defesas = {}
	local algum = false
	for i, tempo in tempos do
		if not esperarAte(d, tempo + Duelo.JANELA.depois + FOLGA_REDE) then
			return defesas
		end
		local alvoLado = if q == "a" then e.b else e.a
		local nota = if atk.player
			then Duelo.notaDoAcerto(
				acao,
				(function()
					local notas = {}
					for m, desvio in g.qte do
						notas[m] = Duelo.notaQte(desvio)
					end
					return notas
				end)(),
				i
			)
			else "bom"
		local def = g.defesa[i]
		local defesa = if alvo.player and def
			then Duelo.notaDefesa(def.tipo, def.desvio, acao.absoluto == true, alvoLado.foco)
			else "atingido"
		local r = Duelo.acerto(e, q, id, i, nota, defesa)
		defesas[i] = r.defesa
		algum = algum or r.dano > 0
		local agora = Workspace:GetServerTimeNow()
		local anim = reacao(alvo, r.defesa, r.dano)
		if anim and alvoLado.vida > 0 then
			alvo.animar(anim, agora)
		end
		if r.rompeu then
			alvo.animar("rompido", agora + 0.4)
		end
		enviarTodos(d, "acerto", function(lado)
			return {
				acao = id,
				indice = i,
				dano = r.dano,
				nota = r.nota,
				defesa = r.defesa,
				rompeu = r.rompeu,
				meu = lado == q, -- fui eu que golpeei
			}
		end)
		if Duelo.vencedor(e) then
			break
		end
	end
	Duelo.terminarAcao(e, q, id, algum)
	d.golpe = nil
	return defesas
end

local function finalizar(d: Duelo, vencedor: string?, motivo: string)
	if not d.ativo then
		return
	end
	d.ativo = false
	for _, l in { d.op.a, d.op.b } do
		if l.player then
			ativos[l.player] = nil
		end
	end
	d.op.aoFim(vencedor, motivo)
end

local function laco(d: Duelo)
	local e = d.estado
	while d.ativo do
		local q = e.quem
		local atk = lutador(d, q)
		if d.op.aoTurno then
			d.op.aoTurno(q)
		end
		-- escolha
		local id: string
		if not atk.player then
			id = Duelo.intencao(e.vezesB + 1)
			enviarTodos(d, "espera", function()
				return { quem = atk.nome }
			end)
			if not esperarAte(d, Workspace:GetServerTimeNow() + PAUSA_SOBERANO) then
				return
			end
		else
			d.escolha = nil
			d.esperando = q
			local prazo = Workspace:GetServerTimeNow() + Duelo.ESPERA_ESCOLHA
			enviar(d, q, "turno", { prazo = prazo })
			enviar(d, Duelo.outro(q), "espera", { quem = atk.nome, prazo = prazo })
			while d.ativo and not d.escolha and Workspace:GetServerTimeNow() < prazo do
				task.wait(0.05)
			end
			d.esperando = nil
			if not d.ativo then
				return
			end
			if not d.escolha then
				if d.op.semEscolha == "derrota" then
					finalizar(d, Duelo.outro(q), "tempo")
					return
				end
				d.escolha = "concentrar"
			end
			id = d.escolha :: string
		end
		-- golpe
		Duelo.iniciarAcao(e, q, id)
		local inicio = Workspace:GetServerTimeNow() + Duelo.ANTECEDENCIA
		local defesas = golpear(d, q, id, inicio)
		if not d.ativo then
			return
		end
		local clipe = clipeDe(atk, id)
		esperarAte(d, inicio + (if clipe then clipe.duracao else 0.8) + 0.1)
		local vencedor = Duelo.vencedor(e)
		if vencedor then
			finalizar(d, vencedor, "nocaute")
			return
		end
		-- aparou tudo: contra-ataque
		local alvoQ = Duelo.outro(q)
		if Duelo.contraAtaca(Duelo.ACOES[id], defesas) and lutador(d, alvoQ).player then
			enviarTodos(d, "contra", function(lado)
				return { meu = lado == alvoQ }
			end)
			local t = Workspace:GetServerTimeNow() + 0.25
			golpear(d, alvoQ, "contra", t)
			esperarAte(d, t + Animacoes.JOGADOR.contra.duracao + 0.1)
			vencedor = Duelo.vencedor(e)
			if vencedor then
				finalizar(d, vencedor, "nocaute")
				return
			end
		end
		-- próxima vez (quem está Rompido perde a vez)
		local perdeu = Duelo.passarVez(e)
		if perdeu then
			local l = lutador(d, perdeu)
			enviarTodos(d, "perdeuVez", function()
				return { quem = l.nome, lado = perdeu }
			end)
			esperarAte(d, Workspace:GetServerTimeNow() + 1.4)
			l.animar(nil, 0)
		end
		vencedor = Duelo.vencedor(e)
		if vencedor then
			finalizar(d, vencedor, "limite")
			return
		end
	end
end

function Motor.iniciar(op: Opcoes): Duelo
	local d: Duelo =
		{ op = op, estado = op.estado, ativo = true, escolha = nil, esperando = nil, golpe = nil }
	for _, l in { op.a, op.b } do
		if l.player then
			ativos[l.player] = d
		end
	end
	task.spawn(function()
		local ok, erro = pcall(laco, d)
		if not ok then
			warn("[Motor] " .. tostring(erro))
			finalizar(d, nil, "erro")
		end
	end)
	return d
end

-- Encerra de fora (desistência, saída): quem fica vence
function Motor.desistir(d: Duelo, lado: string)
	finalizar(d, Duelo.outro(lado), "desistencia")
end

function Motor.parar(d: Duelo)
	if not d.ativo then
		return
	end
	d.ativo = false
	for _, l in { d.op.a, d.op.b } do
		if l.player then
			ativos[l.player] = nil
		end
	end
end

-- no máximo 20 entradas por segundo por jogador (o resto é ignorado)
local contagem: { [Player]: { inicio: number, n: number } } = {}

function Motor.iniciarServico()
	Remotos.evento("DueloEntrada").OnServerEvent:Connect(function(player, id, tipo, tempo)
		local agora = os.clock()
		local c = contagem[player]
		if not c or agora - c.inicio >= 1 then
			c = { inicio = agora, n = 0 }
			contagem[player] = c
		end
		c.n += 1
		if c.n > 20 then
			return
		end
		Motor.entrada(player, id, tipo, tempo)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ativos[player] = nil
		contagem[player] = nil
	end)
end

return Motor
