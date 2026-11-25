-- Inimigos das Incursões. Tudo no servidor: posição, vida, ataque. Cada inimigo é uma caixa (sem
-- colisão) com as medidas da malha do kit; os clientes põem a malha por cima e seguem a caixa
-- (atributo "Movel"). Movimento simples em linha reta até o jogador vivo mais perto (o chão é
-- plano); as Sombras atravessam as ruínas — são sombras.
--
-- Tipos (Shared/Dados/IncursoesRun): Sombra, Corredor (rápido), Atirador (dispara de longe com
-- aviso — dá para desviar), Explosivo (acende o pavio perto do alvo), Escudeiro (aguenta de
-- frente). Elites: mais vida, coroa e afixos (Veloz, Blindado, Vampírico, Instável).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Incursoes = require(Shared.Dados.Incursoes)
local Run = require(Shared.Dados.IncursoesRun)
local Mapa = require(script.Parent.Mapa)

local Inimigos = {}

export type Inimigo = {
	parte: Part,
	vida: number,
	vidaMax: number,
	dano: number,
	velocidade: number,
	alcance: number, -- distância de ataque (do centro)
	raio: number, -- tamanho do corpo (para os golpes acertarem)
	guardiao: boolean,
	tipo: string,
	elite: boolean,
	afixos: { [string]: boolean },
	frente: number?, -- Escudeiro: fração do dano que passa quando acertado de frente
	alcanceTiro: number?, -- Atirador
	explode: boolean,
	proximoAtaque: number,
	pos: Vector3, -- pé no chão
	olhar: Vector3, -- para onde está virado (plano)
	deslocamento: Vector3, -- do pé até o centro da caixa (no espaço do inimigo)
	pavioEm: number?, -- Explosivo: quando explode
	tiro: { para: Vector3, em: number }?, -- Atirador: disparo a caminho
	-- só do Guardião
	universo: string,
	fase: number, -- 1, 2, 3 (muda aos 66% e 33% da vida)
	enfurecido: boolean,
	enfurecerEm: number,
	proximaMecanica: number,
	proximoGolpe: number,
	golpeEm: number?,
	invocou: number,
	atordoadoAte: number, -- combate: sem andar nem atacar até este instante
}

export type Alvo = { raiz: BasePart, humanoide: Humanoid }

local ESPERA_ATAQUE = 1.1
local GOLPE_AVISO = 1.3 -- segundos entre o aviso (círculo no chão) e o impacto
local GOLPE_RAIO = 15
local GOLPE_INTERVALO = 7
local PAVIO = 0.9 -- Explosivo: do aviso à explosão
local RAIO_EXPLOSAO = 7
local TIRO_ESPERA = 2.6
local TIRO_AVISO = 0.65 -- o risco no chão aparece antes do disparo
local TIRO_RAIO = 3.2 -- quem estiver a essa distância do ponto mirado toma o tiro
local DISTANCIA_SEGURA = 13 -- o Atirador recua se o jogador chegar mais perto

-- Dano nos jogadores passa por aqui: o combate (guarda, dash, bênçãos) pode reduzir ou anular.
-- (humanoide, dano, posição de quem atacou, inimigo) -> dano final
Inimigos.defesa = nil :: ((Humanoid, number, Vector3, any) -> number)?

-- Explosões e zonas de ataque pendentes: resolvidas no passo da partida que estiver perto delas
-- (cada partida fica num espaço próprio; a posição diz a qual partida pertence)
type Zona = { pos: Vector3, raio: number, interno: number, em: number, dano: number }
local zonas: { Zona } = {}
local sorte = Random.new()

-- Área de ataque com aviso: tudo entre interno e raio leva dano quando o tempo acabar
local function zona(
	pos: Vector3,
	raio: number,
	interno: number,
	atraso: number,
	dano: number,
	avisar: (({ [string]: any }) -> ())?
)
	table.insert(
		zonas,
		{ pos = pos, raio = raio, interno = interno, em = os.clock() + atraso, dano = dano }
	)
	if avisar then
		avisar({ tipo = "zona", pos = pos, raio = raio, interno = interno, tempo = atraso })
	end
end

local function ferirJogador(a: Alvo, dano: number, origem: Vector3, i: any)
	local final = dano
	local defesa = Inimigos.defesa
	if defesa then
		final = defesa(a.humanoide, dano, origem, i)
	end
	if final > 0 then
		a.humanoide:TakeDamage(final)
		if i and i.afixos and i.afixos.vampirico and i.vida > 0 then
			i.vida = math.min(i.vidaMax, i.vida + final * 0.25)
			i.parte:SetAttribute("Vida", math.ceil(i.vida))
		end
	end
end

local function agoraServidor(): number
	return Workspace:GetServerTimeNow()
end

function Inimigos.novo(
	pai: Instance,
	universo: string,
	pos: Vector3,
	cfg: Incursoes.Andar,
	guardiao: boolean,
	tipo: string?,
	afixos: { string }?
): Inimigo
	local u = Incursoes.porId[universo]
	local arq = Run.ARQUETIPOS[tipo or "sombra"] or Run.ARQUETIPOS.sombra
	local elite = afixos ~= nil and #afixos > 0
	local nome = "inc_" .. universo .. (if guardiao then "_guardiao" else "_sombra")
	local escala = if guardiao then 1 else arq.escala * (if elite then Run.ELITE_ESCALA else 1)
	local parte = Mapa.peca(pai, nome, CFrame.new(pos), escala, Color3.fromHex("100C14"))
	parte.CanCollide = false
	parte.CanQuery = false
	parte:SetAttribute("Movel", true)
	local cor = if elite then "FFD36B" elseif arq.cor ~= "" then arq.cor else u.corVeio
	parte:SetAttribute("CorLuz", Color3.fromHex(cor))
	local vida = if guardiao
		then cfg.vidaGuardiao
		else math.floor(
			cfg.vidaSombra * arq.vida * (if elite then Run.ELITE_VIDA else 1) + 0.5
		)
	parte:SetAttribute("Vida", vida)
	parte:SetAttribute("VidaMax", vida)
	local mapaAfixos = {}
	local nomes = {}
	for _, id in (afixos or {}) :: { string } do
		mapaAfixos[id] = true
		table.insert(nomes, Run.AFIXOS[id].nome)
	end
	if guardiao then
		parte:SetAttribute("Guardiao", u.guardiao)
	elseif elite then
		parte:SetAttribute("Elite", true)
		parte:SetAttribute("Rotulo", "ELITE · " .. table.concat(nomes, " · "))
	elseif arq.id ~= "sombra" then
		parte:SetAttribute("Rotulo", arq.nome)
	end
	parte:SetAttribute("Tipo", arq.id)
	local velocidade = if guardiao
		then cfg.velocidadeSombra * 0.55
		else cfg.velocidadeSombra * arq.velocidade * (if mapaAfixos.veloz then 1.45 else 1)
	return {
		parte = parte,
		vida = vida,
		vidaMax = vida,
		dano = if guardiao
			then cfg.danoSombra * 2
			else cfg.danoSombra * arq.dano * (if elite then Run.ELITE_DANO else 1),
		velocidade = velocidade,
		alcance = if guardiao then 7.5 else 3.6 * math.max(1, escala),
		raio = if guardiao then 4.5 else 1.4 * escala,
		guardiao = guardiao,
		tipo = arq.id,
		elite = elite,
		afixos = mapaAfixos,
		frente = arq.frente,
		alcanceTiro = arq.alcance,
		explode = arq.explode == true or mapaAfixos.explosivo == true,
		proximoAtaque = os.clock() + 1,
		pos = pos,
		olhar = Vector3.new(0, 0, -1),
		deslocamento = parte.Position - pos,
		pavioEm = nil,
		tiro = nil,
		universo = universo,
		fase = 1,
		enfurecido = false,
		enfurecerEm = os.clock() + Run.ENFURECE_EM,
		proximaMecanica = os.clock() + 6,
		proximoGolpe = os.clock() + 4,
		golpeEm = nil,
		invocou = 0,
		atordoadoAte = 0,
	}
end

-- Combate: empurra (no plano) e/ou atordoa. O Guardião e as Elites sentem menos.
function Inimigos.empurrar(i: Inimigo, vetor: Vector3, atordoar: number?)
	if i.vida <= 0 then
		return
	end
	local fator = if i.guardiao then 0.25 elseif i.elite or i.tipo == "escudeiro" then 0.5 else 1
	i.pos += Vector3.new(vetor.X, 0, vetor.Z) * fator
	if atordoar and atordoar > 0 then
		local agora = os.clock()
		i.atordoadoAte =
			math.max(i.atordoadoAte, agora + atordoar * (if i.guardiao then 0.4 else fator))
		i.parte:SetAttribute("Atordoado", agoraServidor() + atordoar)
	end
end

local function morrer(i: Inimigo)
	i.parte:SetAttribute("Morreu", agoraServidor())
	if i.explode and not i.guardiao then
		-- Explosivo/Instável: aviso curto e explode onde caiu
		i.parte:SetAttribute("GolpeRaio", RAIO_EXPLOSAO)
		i.parte:SetAttribute("Golpe", agoraServidor() + 0.5)
		zona(i.pos, RAIO_EXPLOSAO, 0, 0.5, i.dano, nil)
	end
	local parte = i.parte
	task.delay(if i.explode then 0.7 else 0.6, function()
		if i.explode then
			parte:SetAttribute("Impacto", agoraServidor())
		end
		task.delay(0.1, function()
			parte:Destroy()
		end)
	end)
end

-- Aplica dano; devolve true se morreu. origem: de onde veio o golpe (Escudeiro bloqueia de frente).
function Inimigos.ferir(i: Inimigo, dano: number, origem: Vector3?): boolean
	if i.vida <= 0 then
		return false
	end
	if dano < math.huge then
		if i.afixos.blindado then
			dano *= 0.65
		end
		if i.frente and origem then
			local rel = Vector3.new(origem.X - i.pos.X, 0, origem.Z - i.pos.Z)
			if rel.Magnitude > 0.1 and rel.Unit:Dot(i.olhar) > 0.35 then
				dano *= i.frente
				i.parte:SetAttribute("Bloqueou", agoraServidor())
			end
		end
	end
	i.vida = math.max(i.vida - dano, 0)
	i.parte:SetAttribute("Vida", math.ceil(i.vida))
	i.parte:SetAttribute("Ferido", agoraServidor())
	if i.vida <= 0 then
		morrer(i)
		return true
	end
	return false
end

-- Some sem explodir (andar purificado, fim da partida)
function Inimigos.dissolver(i: Inimigo)
	if i.vida <= 0 then
		return
	end
	i.explode = false
	i.vida = 0
	i.parte:SetAttribute("Morreu", agoraServidor())
	local parte = i.parte
	task.delay(0.6, function()
		parte:Destroy()
	end)
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Um passo de todos. invocar(pos) é chamado quando o Guardião chama reforços.
function Inimigos.passo(
	lista: { Inimigo },
	dt: number,
	alvos: { Alvo },
	centro: Vector3,
	raioAndar: number,
	invocar: (Vector3) -> (),
	avisar: (({ [string]: any }) -> ())?
)
	local agora = os.clock()
	-- explosões e zonas pendentes desta partida
	for k = #zonas, 1, -1 do
		local z = zonas[k]
		if agora >= z.em and horizontal(z.pos, centro) <= raioAndar + 20 then
			table.remove(zonas, k)
			for _, a in alvos do
				local d = horizontal(a.raiz.Position, z.pos)
				if a.humanoide.Health > 0 and d <= z.raio and d >= z.interno then
					ferirJogador(a, z.dano, z.pos, nil)
				end
			end
		elseif agora >= z.em + 5 then
			table.remove(zonas, k) -- a partida já acabou
		end
	end
	for idx, i in lista do
		if i.vida <= 0 then
			continue
		end
		-- alvo: o vivo mais perto
		local melhor: Alvo? = nil
		local menor = math.huge
		for _, a in alvos do
			if a.humanoide.Health > 0 then
				local d = (a.raiz.Position - i.pos).Magnitude
				if d < menor then
					menor = d
					melhor = a
				end
			end
		end
		local atordoado = agora < i.atordoadoAte
		local olhar = i.pos + i.olhar
		if melhor then
			local para =
				Vector3.new(melhor.raiz.Position.X - i.pos.X, 0, melhor.raiz.Position.Z - i.pos.Z)
			local dist = para.Magnitude
			if dist > 0.1 then
				olhar = i.pos + para
			end
			local livre = not i.golpeEm and not atordoado and not i.pavioEm

			if i.alcanceTiro then
				-- Atirador: fica na distância boa e dispara com aviso
				if livre and dist > 0.1 then
					if dist < DISTANCIA_SEGURA then
						i.pos -= para.Unit * math.min(i.velocidade * dt, DISTANCIA_SEGURA - dist)
					elseif dist > i.alcanceTiro * 0.85 then
						i.pos += para.Unit * math.min(i.velocidade * dt, dist - i.alcanceTiro * 0.8)
					end
				end
				local tiro = i.tiro
				if tiro then
					if agora >= tiro.em then
						i.tiro = nil
						for _, a in alvos do
							if
								a.humanoide.Health > 0
								and horizontal(a.raiz.Position, tiro.para) <= TIRO_RAIO
							then
								ferirJogador(a, i.dano, i.pos, i)
							end
						end
						i.parte:SetAttribute("Ataque", agoraServidor())
					end
				elseif livre and dist <= i.alcanceTiro and agora >= i.proximoAtaque then
					i.proximoAtaque = agora + TIRO_ESPERA
					local alvoPos = melhor.raiz.Position
					i.tiro = { para = alvoPos, em = agora + TIRO_AVISO }
					i.parte:SetAttribute("Mira", alvoPos)
					i.parte:SetAttribute("MiraEm", agoraServidor() + TIRO_AVISO)
				end
			else
				if dist > i.alcance * 0.8 and livre then
					i.pos += para.Unit * math.min(i.velocidade * dt, dist - i.alcance * 0.8)
				end
				if i.tipo == "explosivo" then
					-- acende o pavio quando chega perto; depois explode no lugar
					if not i.pavioEm and not atordoado and dist <= i.alcance + 1.5 then
						i.pavioEm = agora + PAVIO
						i.parte:SetAttribute("GolpeRaio", RAIO_EXPLOSAO)
						i.parte:SetAttribute("Golpe", agoraServidor() + PAVIO)
					end
				elseif dist <= i.alcance and agora >= i.proximoAtaque and livre then
					i.proximoAtaque = agora + ESPERA_ATAQUE * (if i.guardiao then 1.5 else 1)
					ferirJogador(melhor, i.dano, i.pos, i)
					i.parte:SetAttribute("Ataque", agoraServidor())
				end
			end
		end
		-- Explosivo: o pavio acabou
		if i.pavioEm and agora >= i.pavioEm then
			i.pavioEm = nil
			for _, a in alvos do
				if
					a.humanoide.Health > 0
					and horizontal(a.raiz.Position, i.pos) <= RAIO_EXPLOSAO
				then
					ferirJogador(a, i.dano, i.pos, i)
				end
			end
			i.explode = false -- já explodiu
			i.vida = 0
			i.parte:SetAttribute("Vida", 0)
			i.parte:SetAttribute("Impacto", agoraServidor())
			i.parte:SetAttribute("Morreu", agoraServidor())
			local parte = i.parte
			task.delay(0.4, function()
				parte:Destroy()
			end)
			continue
		end
		-- empurra para longe das outras (não empilham)
		for j, o in lista do
			if j ~= idx and o.vida > 0 then
				local d = Vector3.new(i.pos.X - o.pos.X, 0, i.pos.Z - o.pos.Z)
				local minimo = i.raio + o.raio
				if d.Magnitude < minimo and d.Magnitude > 0.01 then
					i.pos += d.Unit * (minimo - d.Magnitude) * 0.5
				end
			end
		end
		-- dentro do andar
		local rel = Vector3.new(i.pos.X - centro.X, 0, i.pos.Z - centro.Z)
		if rel.Magnitude > raioAndar - 3 then
			i.pos = Vector3.new(centro.X, i.pos.Y, centro.Z) + rel.Unit * (raioAndar - 3)
		end

		-- Guardião: golpe em área com aviso, e reforços aos 66% e 33% da vida
		if i.guardiao then
			if i.golpeEm then
				if agora >= i.golpeEm then
					i.golpeEm = nil
					i.proximoGolpe = agora + GOLPE_INTERVALO * (if i.enfurecido then 0.6 else 1)
					for _, a in alvos do
						if
							a.humanoide.Health > 0
							and horizontal(a.raiz.Position, i.pos) <= GOLPE_RAIO
						then
							ferirJogador(a, i.dano * 1.6, i.pos, i)
						end
					end
					i.parte:SetAttribute("Impacto", agoraServidor())
				end
			elseif agora >= i.proximoGolpe and melhor and menor < GOLPE_RAIO * 1.4 then
				i.golpeEm = agora + GOLPE_AVISO
				i.parte:SetAttribute("Golpe", agoraServidor() + GOLPE_AVISO)
				i.parte:SetAttribute("GolpeRaio", GOLPE_RAIO)
			end
			local fracao = i.vida / i.vidaMax
			local fase = if fracao < Run.FASES_GUARDIAO[2]
				then 3
				elseif fracao < Run.FASES_GUARDIAO[1] then 2
				else 1
			if fase > i.fase then
				-- muda de fase: onda de choque, reforços e a mecânica do universo começa
				i.fase = fase
				i.invocou += 1
				i.parte:SetAttribute("Fase", fase)
				i.parte:SetAttribute("GolpeRaio", 12)
				i.parte:SetAttribute("Impacto", agoraServidor())
				i.proximaMecanica = agora + 2.5
				for k = 1, 3 do
					local a = 2 * math.pi * k / 3
					invocar(i.pos + Vector3.new(math.sin(a) * 8, 0, math.cos(a) * 8))
				end
				if avisar then
					avisar({ tipo = "faseGuardiao", fase = fase })
				end
			end
			if not i.enfurecido and agora >= i.enfurecerEm then
				i.enfurecido = true
				i.dano *= 1.6
				i.velocidade *= 1.4
				i.parte:SetAttribute("Enfurecido", true)
				if avisar then
					avisar({ tipo = "enfurecido" })
				end
			end
			if i.fase >= 2 and agora >= i.proximaMecanica and not i.golpeEm then
				local f3 = i.fase >= 3
				if i.universo == "cinzas" then
					-- Chuva de Brasas: círculos de fogo caem em cima dos jogadores
					for _ = 1, if f3 then 7 else 4 do
						local a = alvos[sorte:NextInteger(1, math.max(#alvos, 1))]
						local base = if a then a.raiz.Position else i.pos
						local p = base
							+ Vector3.new(sorte:NextNumber(-5, 5), 0, sorte:NextNumber(-5, 5))
						zona(Vector3.new(p.X, i.pos.Y, p.Z), 5, 0, 1.3, i.dano * 1.2, avisar)
					end
					i.proximaMecanica = agora + (if f3 then 3 else 4.5)
				elseif i.universo == "mare" then
					-- Maré Alta: onda em anel; o único lugar seguro é colado no Cavaleiro
					zona(i.pos, 26, 6.5, 1.8, i.dano * 1.8, avisar)
					i.proximaMecanica = agora + (if f3 then 5.5 else 8)
				else
					-- Eclipse: o Espectro some e reaparece; onde estava, a sombra explode
					local antes = i.pos
					zona(antes, 8, 0, 0.9, i.dano * 1.3, avisar)
					local ang = sorte:NextNumber(0, math.pi * 2)
					local dist = sorte:NextNumber(0, raioAndar * 0.55)
					i.pos = Vector3.new(
						centro.X + math.cos(ang) * dist,
						i.pos.Y,
						centro.Z + math.sin(ang) * dist
					)
					i.parte:SetAttribute("Piscou", agoraServidor())
					if f3 then
						invocar(antes)
					end
					i.proximaMecanica = agora + (if f3 then 4.5 else 7)
				end
			end
		end

		-- a malha olha para +Y no Blender = -Z no Roblox, que é a frente de CFrame.lookAt
		local f = Vector3.new(olhar.X - i.pos.X, 0, olhar.Z - i.pos.Z)
		if f.Magnitude > 0.05 then
			i.olhar = f.Unit
		end
		i.parte.CFrame = CFrame.lookAt(i.pos, i.pos + i.olhar) * CFrame.new(i.deslocamento)
	end
	-- tira os mortos da lista
	for k = #lista, 1, -1 do
		if lista[k].vida <= 0 then
			table.remove(lista, k)
		end
	end
end

Inimigos.GOLPE_RAIO = GOLPE_RAIO

return Inimigos
