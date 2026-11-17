-- Sombras e Guardiões das Incursões. Tudo no servidor: posição, vida, ataque. Cada inimigo é uma
-- caixa (sem colisão) com as medidas da malha do kit; os clientes põem a malha por cima e seguem a
-- caixa (atributo "Movel"). Movimento simples em linha reta até o jogador vivo mais perto (o chão
-- é plano); as Sombras atravessam as ruínas — são sombras.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Incursoes = require(Shared.Dados.Incursoes)
local Mapa = require(script.Parent.Mapa)

local Inimigos = {}

export type Inimigo = {
	parte: Part,
	vida: number,
	vidaMax: number,
	dano: number,
	velocidade: number,
	alcance: number, -- distância de ataque (do centro)
	raio: number, -- tamanho do corpo (para o Pulso acertar)
	guardiao: boolean,
	proximoAtaque: number,
	pos: Vector3, -- pé no chão
	deslocamento: Vector3, -- do pé até o centro da caixa (no espaço do inimigo)
	-- só do Guardião
	proximoGolpe: number,
	golpeEm: number?,
	invocou: number,
}

export type Alvo = { raiz: BasePart, humanoide: Humanoid }

local ESPERA_ATAQUE = 1.1
local GOLPE_AVISO = 1.3 -- segundos entre o aviso (círculo no chão) e o impacto
local GOLPE_RAIO = 15
local GOLPE_INTERVALO = 7

function Inimigos.novo(
	pai: Instance,
	universo: string,
	pos: Vector3,
	cfg: Incursoes.Andar,
	guardiao: boolean
): Inimigo
	local u = Incursoes.porId[universo]
	local nome = "inc_" .. universo .. (if guardiao then "_guardiao" else "_sombra")
	local escala = if guardiao then 1 else 1.05
	local parte = Mapa.peca(pai, nome, CFrame.new(pos), escala, Color3.fromHex("100C14"))
	parte.CanCollide = false
	parte.CanQuery = false
	parte:SetAttribute("Movel", true)
	parte:SetAttribute("CorLuz", Color3.fromHex(u.corVeio))
	local vida = if guardiao then cfg.vidaGuardiao else cfg.vidaSombra
	parte:SetAttribute("Vida", vida)
	parte:SetAttribute("VidaMax", vida)
	if guardiao then
		parte:SetAttribute("Guardiao", u.guardiao)
	end
	return {
		parte = parte,
		vida = vida,
		vidaMax = vida,
		dano = if guardiao then cfg.danoSombra * 2 else cfg.danoSombra,
		velocidade = if guardiao then cfg.velocidadeSombra * 0.55 else cfg.velocidadeSombra,
		alcance = if guardiao then 7.5 else 3.6,
		raio = if guardiao then 4.5 else 1.4,
		guardiao = guardiao,
		proximoAtaque = os.clock() + 1,
		pos = pos,
		deslocamento = parte.Position - pos,
		proximoGolpe = os.clock() + 4,
		golpeEm = nil,
		invocou = 0,
	}
end

-- Aplica dano; devolve true se morreu (a peça some aqui)
function Inimigos.ferir(i: Inimigo, dano: number): boolean
	if i.vida <= 0 then
		return false
	end
	i.vida = math.max(i.vida - dano, 0)
	i.parte:SetAttribute("Vida", math.ceil(i.vida))
	i.parte:SetAttribute("Ferido", Workspace:GetServerTimeNow())
	if i.vida <= 0 then
		i.parte:SetAttribute("Morreu", Workspace:GetServerTimeNow())
		local parte = i.parte
		task.delay(0.6, function()
			parte:Destroy()
		end)
		return true
	end
	return false
end

-- Um passo de todos. invocar(pos) é chamado quando o Guardião chama reforços.
function Inimigos.passo(
	lista: { Inimigo },
	dt: number,
	alvos: { Alvo },
	centro: Vector3,
	raioAndar: number,
	invocar: (Vector3) -> ()
)
	local agora = os.clock()
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
		local olhar = i.pos + Vector3.new(0, 0, -1)
		if melhor then
			local para =
				Vector3.new(melhor.raiz.Position.X - i.pos.X, 0, melhor.raiz.Position.Z - i.pos.Z)
			local dist = para.Magnitude
			if dist > 0.1 then
				olhar = i.pos + para
			end
			if dist > i.alcance * 0.8 and not i.golpeEm then
				i.pos += para.Unit * math.min(i.velocidade * dt, dist - i.alcance * 0.8)
			end
			if dist <= i.alcance and agora >= i.proximoAtaque and not i.golpeEm then
				i.proximoAtaque = agora + ESPERA_ATAQUE * (if i.guardiao then 1.5 else 1)
				melhor.humanoide:TakeDamage(i.dano)
				i.parte:SetAttribute("Ataque", Workspace:GetServerTimeNow())
			end
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
					i.proximoGolpe = agora + GOLPE_INTERVALO
					for _, a in alvos do
						local d =
							Vector3.new(a.raiz.Position.X - i.pos.X, 0, a.raiz.Position.Z - i.pos.Z)
						if a.humanoide.Health > 0 and d.Magnitude <= GOLPE_RAIO then
							a.humanoide:TakeDamage(i.dano * 1.6)
						end
					end
					i.parte:SetAttribute("Impacto", Workspace:GetServerTimeNow())
				end
			elseif agora >= i.proximoGolpe and melhor and menor < GOLPE_RAIO * 1.4 then
				i.golpeEm = agora + GOLPE_AVISO
				i.parte:SetAttribute("Golpe", Workspace:GetServerTimeNow() + GOLPE_AVISO)
				i.parte:SetAttribute("GolpeRaio", GOLPE_RAIO)
			end
			local fracao = i.vida / i.vidaMax
			if (i.invocou == 0 and fracao < 0.66) or (i.invocou == 1 and fracao < 0.33) then
				i.invocou += 1
				for k = 1, 3 do
					local a = 2 * math.pi * k / 3
					invocar(i.pos + Vector3.new(math.sin(a) * 8, 0, math.cos(a) * 8))
				end
			end
		end

		-- a malha olha para +Y no Blender = -Z no Roblox, que é a frente de CFrame.lookAt
		i.parte.CFrame = CFrame.lookAt(i.pos, Vector3.new(olhar.X, i.pos.Y, olhar.Z))
			* CFrame.new(i.deslocamento)
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
