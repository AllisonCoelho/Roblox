-- Combate das Incursões no servidor (fase 1). O cliente só pede "usei a técnica X na direção Y",
-- "esquivei" ou "estou guardando"; aqui se confere recarga, posição e medidor, se calcula quem foi
-- acertado (Shared/Dados/Combate) e se aplica o dano. Sem PvP: só inimigos são acertados.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dados = require(Shared.Dados.Combate)
local Inimigos = require(script.Parent.Inimigos)

local Combate = {}

-- O que o Serviço das Incursões entrega a cada pedido
export type Contexto = {
	raiz: BasePart,
	humanoide: Humanoid,
	inimigos: { Inimigos.Inimigo },
	ressonancia: number,
	paraRun: ({ [string]: any }) -> (),
	enviar: ({ [string]: any }) -> (),
}

type Estado = {
	kit: Dados.Kit,
	cor: Color3,
	recargas: { [string]: number },
	combo: number,
	comboAte: number,
	medidor: number,
	despertarAte: number,
	guardando: boolean,
	guardaDesde: number,
	guardaBloqueadaAte: number,
	velocidadeNormal: number?,
	invulneravelAte: number,
	proximoDash: number,
	ctx: Contexto?,
}

local estados: { [Player]: Estado } = {}
local rng = Random.new()

local function porHumanoide(h: Humanoid): (Player?, Estado?)
	local p = Players:GetPlayerFromCharacter(h.Parent)
	if p then
		return p, estados[p]
	end
	return nil, nil
end

local function tempoServidor(): number
	return Workspace:GetServerTimeNow()
end

local function enviarEstado(e: Estado)
	local ctx = e.ctx
	if ctx then
		ctx.enviar({
			tipo = "combateEstado",
			kit = e.kit.id,
			medidor = math.floor(e.medidor),
			despertarAte = if e.despertarAte > os.clock()
				then tempoServidor() + (e.despertarAte - os.clock())
				else 0,
		})
	end
end

local function ganhar(e: Estado, valor: number)
	local antes = math.floor(e.medidor)
	e.medidor = math.min(Dados.MEDIDOR_MAX, e.medidor + valor)
	if math.floor(e.medidor) ~= antes then
		enviarEstado(e)
	end
end

-- Entra/sai do modo de combate (início e fim de cada partida)
function Combate.entrar(player: Player, auraVfx: any, cor: Color3)
	estados[player] = {
		kit = Dados.kitDe(auraVfx),
		cor = cor,
		recargas = {},
		combo = 0,
		comboAte = 0,
		medidor = 0,
		despertarAte = 0,
		guardando = false,
		guardaDesde = 0,
		guardaBloqueadaAte = 0,
		velocidadeNormal = nil,
		invulneravelAte = 0,
		proximoDash = 0,
		ctx = nil,
	}
end

local function soltarGuarda(e: Estado)
	if not e.guardando then
		return
	end
	e.guardando = false
	local ctx = e.ctx
	if ctx and e.velocidadeNormal and ctx.humanoide.Parent then
		ctx.humanoide.WalkSpeed = e.velocidadeNormal
	end
	e.velocidadeNormal = nil
end

function Combate.sair(player: Player)
	local e = estados[player]
	if e then
		soltarGuarda(e)
	end
	estados[player] = nil
end

-- A prévia da Gear 5 pode ligar/desligar no meio da partida: o kit acompanha
function Combate.atualizarKit(player: Player, auraVfx: any)
	local e = estados[player]
	if e then
		local kit = Dados.kitDe(auraVfx)
		if kit ~= e.kit then
			e.kit = kit
			e.recargas = {}
			e.combo = 0
			enviarEstado(e)
		end
	end
end

function Combate.kit(player: Player): string?
	local e = estados[player]
	return if e then e.kit.id else nil
end

-- A cada passo da partida: a guarda segurada demais quebra
function Combate.passo()
	local agora = os.clock()
	for _, e in estados do
		if e.guardando and agora - e.guardaDesde > Dados.GUARDA_MAX then
			soltarGuarda(e)
			e.guardaBloqueadaAte = agora + Dados.GUARDA_QUEBRA
			if e.ctx then
				e.ctx.enviar({ tipo = "guardaQuebrou" })
				e.ctx.paraRun({
					tipo = "combate",
					acao = "guardaQuebrou",
					origem = e.ctx.raiz.Position,
				})
			end
		end
	end
end

local function direcaoValida(dir: any): Vector3?
	if typeof(dir) ~= "Vector3" then
		return nil
	end
	local plano = Vector3.new(dir.X, 0, dir.Z)
	local m = plano.Magnitude
	if m ~= m or m < 1e-3 or m > 1e6 then -- NaN, zero ou absurdo
		return nil
	end
	return plano.Unit
end

local folgaCache: { [Dados.Tecnica]: Dados.Tecnica } = {}
local function comFolga(t: Dados.Tecnica): Dados.Tecnica
	local c = folgaCache[t]
	if not c then
		c = table.clone(t) :: any
		c.alcance += Dados.ALCANCE_FOLGA
		if c.largura then
			c.largura += 0.6
		end
		folgaCache[t] = c
	end
	return c :: Dados.Tecnica
end

-- Aplica um acerto em quem estiver na área agora; devolve as posições acertadas (para o efeito)
local function acertar(
	player: Player,
	e: Estado,
	tecnica: Dados.Tecnica,
	origem: Vector3,
	dir: Vector3,
	mult: number
): { Vector3 }
	local ctx = e.ctx
	if not ctx then
		return {}
	end
	local alvos = {}
	local geo = comFolga(tecnica)
	local bonus = if os.clock() < e.despertarAte then 1 + e.kit.despertar.bonus else 1
	local total = 0
	for _, i in table.clone(ctx.inimigos) do
		if i.vida > 0 and Dados.acerta(geo, origem, dir, i.pos, i.raio) then
			local critico = rng:NextNumber() < Dados.CRITICO_CHANCE
			local dano = Dados.dano(tecnica.dano, ctx.ressonancia, mult * bonus, critico)
			local rel = Vector3.new(i.pos.X - origem.X, 0, i.pos.Z - origem.Z)
			local fora = if rel.Magnitude > 0.1 then rel.Unit else dir
			if tecnica.empurrar or tecnica.atordoar then
				Inimigos.empurrar(i, fora * (tecnica.empurrar or 0), tecnica.atordoar)
			end
			Inimigos.ferir(i, dano)
			total += dano
			table.insert(alvos, i.pos)
			if critico then
				ctx.paraRun({ tipo = "combate", acao = "critico", origem = i.pos, valor = dano })
			end
		end
	end
	if total > 0 then
		ganhar(e, Dados.ganhoMedidor(total))
	end
	local _ = player
	return alvos
end

-- Pedido: técnica (golpe, tecnica1, tecnica2, despertar) na direção dir
function Combate.tecnica(player: Player, id: any, dir: any, ctx: Contexto): (boolean, string?)
	local e = estados[player]
	if not e or type(id) ~= "string" then
		return false, nil
	end
	local tecnica = e.kit.tecnicas[id]
	local direcao = direcaoValida(dir)
	if not tecnica or not direcao or ctx.humanoide.Health <= 0 then
		return false, nil
	end
	e.ctx = ctx
	local agora = os.clock()
	if agora < (e.recargas[id] or 0) then
		return false, nil
	end
	if id == "despertar" then
		if e.medidor < Dados.MEDIDOR_MAX then
			return false, "O Despertar ainda não carregou."
		end
		e.medidor = 0
		e.despertarAte = agora + e.kit.despertar.duracao
	end
	e.recargas[id] = agora + tecnica.recarga
	soltarGuarda(e)

	local mult = 1
	local combo = 0
	if id == "golpe" then
		combo = if agora <= e.comboAte then e.combo % #e.kit.combo + 1 else 1
		e.combo = combo
		e.comboAte = agora + Dados.COMBO_JANELA
		mult = e.kit.combo[combo]
		-- o último golpe do combo empurra mais
		if combo == #e.kit.combo then
			tecnica = table.clone(tecnica) :: any
			tecnica.empurrar = (tecnica.empurrar or 0) * 4
			tecnica.atordoar = 0.35
		end
	end

	local origem = ctx.raiz.Position
	ctx.paraRun({
		tipo = "combate",
		acao = "tecnica",
		userId = player.UserId,
		kit = e.kit.id,
		tecnica = id,
		combo = combo,
		origem = origem,
		dir = direcao,
		cor = e.cor,
		despertado = os.clock() < e.despertarAte,
	})

	if tecnica.puxar then
		-- Gear 5: puxa todos para perto antes do punho gigante descer
		for _, i in ctx.inimigos do
			local rel = Vector3.new(origem.X - i.pos.X, 0, origem.Z - i.pos.Z)
			if i.vida > 0 and rel.Magnitude <= tecnica.alcance * 1.4 and rel.Magnitude > 5 then
				Inimigos.empurrar(i, rel.Unit * (rel.Magnitude - 5), tecnica.atraso)
			end
		end
	end

	local acertos = tecnica.acertos or 1
	local function disparar(k: number)
		if not estados[player] or ctx.humanoide.Health <= 0 or not ctx.raiz.Parent then
			return
		end
		-- técnicas com atraso partem de onde o jogador está quando soltam
		local o = if (tecnica.atraso or 0) > 0 then ctx.raiz.Position else origem
		local alvos = acertar(player, e, tecnica, o, direcao, mult)
		if #alvos > 0 then
			ctx.paraRun({
				tipo = "combate",
				acao = "acerto",
				tecnica = id,
				kit = e.kit.id,
				alvos = alvos,
				k = k,
				cor = e.cor,
			})
		end
	end
	for k = 1, acertos do
		local quando = (tecnica.atraso or 0) + (k - 1) * (tecnica.intervalo or 0)
		if quando <= 0 then
			disparar(k)
		else
			task.delay(quando, disparar, k)
		end
	end
	if id == "despertar" then
		enviarEstado(e)
	end
	return true, nil
end

-- Pedido: esquiva (o cliente move o personagem; aqui só a invulnerabilidade e a recarga)
function Combate.esquiva(player: Player, dir: any, ctx: Contexto): (boolean, string?)
	local e = estados[player]
	local direcao = direcaoValida(dir)
	if not e or not direcao or ctx.humanoide.Health <= 0 then
		return false, nil
	end
	e.ctx = ctx
	local agora = os.clock()
	if agora < e.proximoDash then
		return false, nil
	end
	e.proximoDash = agora + Dados.DASH_RECARGA
	e.invulneravelAte = agora + e.kit.dash.invulneravel
	soltarGuarda(e)
	ctx.paraRun({
		tipo = "combate",
		acao = "esquiva",
		userId = player.UserId,
		kit = e.kit.id,
		origem = ctx.raiz.Position,
		dir = direcao,
		cor = e.cor,
	})
	return true, nil
end

-- Pedido: guarda (segurar F)
function Combate.guarda(player: Player, ligar: any, ctx: Contexto): (boolean, string?)
	local e = estados[player]
	if not e or type(ligar) ~= "boolean" then
		return false, nil
	end
	e.ctx = ctx
	local agora = os.clock()
	if ligar then
		if e.guardando or agora < e.guardaBloqueadaAte or ctx.humanoide.Health <= 0 then
			return false, nil
		end
		e.guardando = true
		e.guardaDesde = agora
		e.velocidadeNormal = ctx.humanoide.WalkSpeed
		ctx.humanoide.WalkSpeed = math.min(ctx.humanoide.WalkSpeed, Dados.GUARDA_VELOCIDADE)
	else
		soltarGuarda(e)
	end
	ctx.paraRun({
		tipo = "combate",
		acao = "guarda",
		userId = player.UserId,
		ligada = e.guardando,
		cor = e.cor,
	})
	return true, nil
end

-- Defesa: todo dano de inimigo em jogador passa por aqui (ligado em Inimigos.defesa)
function Combate.defesa(h: Humanoid, dano: number, origem: Vector3, inimigo: any): number
	local _, e = porHumanoide(h)
	if not e or not e.ctx then
		return dano
	end
	local agora = os.clock()
	local raiz = e.ctx.raiz
	local invulneravel = agora < e.invulneravelAte
	local deFrente = Dados.deFrente(raiz.Position, raiz.CFrame.LookVector, origem)
	local final = Dados.danoRecebido(dano, e.kit, e.guardando, deFrente, invulneravel)
	if invulneravel then
		ganhar(e, Dados.MEDIDOR_ESQUIVA)
		e.ctx.paraRun({ tipo = "combate", acao = "esquivou", origem = raiz.Position })
	elseif final < dano then
		ganhar(e, Dados.MEDIDOR_GUARDA)
		e.ctx.paraRun({ tipo = "combate", acao = "aparou", origem = raiz.Position, cor = e.cor })
		-- Gear 5: o corpo de borracha devolve parte do golpe
		if e.kit.guarda.rebote > 0 and inimigo and inimigo.vida and inimigo.vida > 0 then
			Inimigos.ferir(inimigo, math.floor(dano * e.kit.guarda.rebote + 0.5))
		end
	end
	return final
end

function Combate.iniciar()
	Inimigos.defesa = Combate.defesa
	Players.PlayerRemoving:Connect(function(p)
		estados[p] = nil
	end)
end

return Combate
