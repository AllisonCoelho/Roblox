-- Combate das Incursões (fase 1): números e geometria de acerto, sem APIs do Roblox além de Vector3
-- (só nas funções de acerto, que recebem vetores). O servidor decide tudo; o cliente só usa estes
-- números para prever recargas e desenhar o HUD.
--
-- Kits: todas as auras usam o kit "generico" (pintado com as cores da aura). Só a Gear 5 tem kit
-- próprio enquanto o sistema de dano e técnicas não estiver validado em playtest.
local Combate = {}

export type Tecnica = {
	id: string,
	nome: string,
	tecla: string,
	forma: string, -- "cone" | "linha" | "area"
	alcance: number, -- studs
	angulo: number?, -- cone: abertura total em graus
	largura: number?, -- linha: meia-largura
	dano: number, -- por acerto
	acertos: number?, -- quantas vezes acerta (rajadas)
	intervalo: number?, -- segundos entre os acertos da rajada
	atraso: number?, -- segundos até o primeiro acerto (o efeito "carrega")
	recarga: number,
	empurrar: number?, -- studs
	atordoar: number?, -- segundos
	puxar: boolean?, -- traz os inimigos para perto antes do acerto
}

export type Kit = {
	id: string,
	nome: string,
	tecnicas: { [string]: Tecnica }, -- golpe, tecnica1, tecnica2, despertar
	combo: { number }, -- multiplicador de cada golpe do combo M1
	despertar: { duracao: number, bonus: number },
	dash: { distancia: number, invulneravel: number },
	guarda: { reducao: number, rebote: number },
}

Combate.TECNICAS = { "golpe", "tecnica1", "tecnica2", "despertar" }
Combate.COMBO_JANELA = 0.9 -- segundos para emendar o próximo golpe do combo
Combate.DASH_RECARGA = 3
Combate.GUARDA_MAX = 3 -- segurando mais que isso a guarda quebra
Combate.GUARDA_QUEBRA = 2 -- segundos sem poder guardar depois de quebrar
Combate.GUARDA_VELOCIDADE = 7 -- WalkSpeed enquanto guarda
Combate.MEDIDOR_MAX = 100
Combate.MEDIDOR_POR_DANO = 0.18 -- por ponto de dano causado
Combate.MEDIDOR_GUARDA = 6 -- por golpe aparado
Combate.MEDIDOR_ESQUIVA = 5 -- por golpe esquivado
Combate.RESSONANCIA_MAX = 1.6
Combate.CRITICO_CHANCE = 0.05
Combate.CRITICO_MULT = 1.5
Combate.ALCANCE_FOLGA = 4 -- tolerância de rede no alcance (servidor)

local function t(dados: { [string]: any }): Tecnica
	return dados :: any
end

Combate.KITS = {
	generico = {
		id = "generico",
		nome = "Ressonância",
		combo = { 1, 1.1, 1.6 },
		despertar = { duracao = 8, bonus = 0.3 },
		dash = { distancia = 20, invulneravel = 0.35 },
		guarda = { reducao = 0.7, rebote = 0 },
		tecnicas = {
			golpe = t({
				id = "golpe",
				nome = "Golpe de Aura",
				tecla = "M1",
				forma = "cone",
				alcance = 8,
				angulo = 90,
				dano = 14,
				recarga = 0.34,
				empurrar = 1.5,
			}),
			tecnica1 = t({
				id = "tecnica1",
				nome = "Esfera de Aura",
				tecla = "1",
				forma = "linha",
				alcance = 46,
				largura = 2.6,
				dano = 36,
				atraso = 0.12,
				recarga = 6,
				empurrar = 6,
			}),
			tecnica2 = t({
				id = "tecnica2",
				nome = "Onda Ressonante",
				tecla = "2",
				forma = "cone",
				alcance = 16,
				angulo = 110,
				dano = 50,
				atraso = 0.18,
				recarga = 10,
				empurrar = 12,
				atordoar = 0.8,
			}),
			despertar = t({
				id = "despertar",
				nome = "Despertar da Aura",
				tecla = "R",
				forma = "area",
				alcance = 18,
				dano = 110,
				atraso = 0.45,
				recarga = 1,
				empurrar = 16,
				atordoar = 1.2,
			}),
		},
	},
	gear5 = {
		id = "gear5",
		nome = "Gear 5",
		combo = { 1, 1.05, 1.7 },
		despertar = { duracao = 9, bonus = 0.35 },
		dash = { distancia = 26, invulneravel = 0.45 }, -- quica como borracha
		guarda = { reducao = 0.8, rebote = 0.5 }, -- o corpo de borracha devolve metade
		tecnicas = {
			golpe = t({
				id = "golpe",
				nome = "Soco Elástico",
				tecla = "M1",
				forma = "linha",
				alcance = 13, -- o braço estica: mais longe que o golpe genérico
				largura = 2.2,
				dano = 14,
				recarga = 0.36,
				empurrar = 2.5,
			}),
			tecnica1 = t({
				id = "tecnica1",
				nome = "Pistola de Borracha",
				tecla = "1",
				forma = "linha",
				alcance = 42,
				largura = 3.4,
				dano = 40,
				atraso = 0.22, -- puxa o braço para trás antes de soltar
				recarga = 5.5,
				empurrar = 18,
				atordoar = 0.5,
			}),
			tecnica2 = t({
				id = "tecnica2",
				nome = "Gatling Elástica",
				tecla = "2",
				forma = "cone",
				alcance = 17,
				angulo = 70,
				dano = 9,
				acertos = 8,
				intervalo = 0.11,
				atraso = 0.1,
				recarga = 9,
				empurrar = 1,
			}),
			despertar = t({
				id = "despertar",
				nome = "Punho do Trovão Gigante",
				tecla = "R",
				forma = "area",
				alcance = 24,
				dano = 150,
				atraso = 0.9, -- puxa todos, ergue o punho gigante, desce com o trovão
				recarga = 1,
				empurrar = 20,
				atordoar = 1.5,
				puxar = true,
			}),
		},
	},
} :: { [string]: Kit }

-- Kit pelo VFX de aura do personagem (atributo "AuraVfx", definido pelo servidor)
function Combate.kitDe(auraVfx: any): Kit
	if auraVfx == "gear5" then
		return Combate.KITS.gear5
	end
	return Combate.KITS.generico
end

-- Dano final de um acerto (o sorteio do crítico vem de fora: só o servidor tem o Random)
function Combate.dano(
	base: number,
	ressonancia: number,
	multiplicador: number?,
	critico: boolean?
): number
	local r = math.clamp(ressonancia, 1, Combate.RESSONANCIA_MAX)
	local d = base * r * (multiplicador or 1)
	if critico then
		d *= Combate.CRITICO_MULT
	end
	return math.floor(d + 0.5)
end

-- Quanto de medidor um acerto rende
function Combate.ganhoMedidor(danoCausado: number): number
	return danoCausado * Combate.MEDIDOR_POR_DANO
end

-- Dano recebido depois da defesa (guarda só vale de frente; dash = invulnerável)
function Combate.danoRecebido(
	dano: number,
	kit: Kit,
	guardando: boolean,
	deFrente: boolean,
	invulneravel: boolean
): number
	if invulneravel then
		return 0
	end
	if guardando and deFrente then
		return dano * (1 - kit.guarda.reducao)
	end
	return dano
end

-- ---------------------------------------------------------------- geometria (plano XZ)

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- O alvo (centro + raio do corpo) está dentro da técnica disparada de origem na direção dir?
function Combate.acerta(
	tecnica: Tecnica,
	origem: Vector3,
	dir: Vector3,
	alvo: Vector3,
	raioAlvo: number
): boolean
	local rel = plano(alvo - origem)
	local d = rel.Magnitude
	if tecnica.forma == "area" then
		return d <= tecnica.alcance + raioAlvo
	end
	local f = plano(dir)
	if f.Magnitude < 1e-4 then
		return false
	end
	f = f.Unit
	local frente = rel:Dot(f)
	if tecnica.forma == "linha" then
		if frente < -raioAlvo or frente > tecnica.alcance + raioAlvo then
			return false
		end
		local lateral = (rel - f * frente).Magnitude
		return lateral <= (tecnica.largura or 2) + raioAlvo
	end
	-- cone
	if d > tecnica.alcance + raioAlvo then
		return false
	end
	if d <= raioAlvo + 1 then
		return true -- colado no corpo: sempre acerta
	end
	local cosMeio = math.cos(math.rad((tecnica.angulo or 90) / 2))
	return frente / d >= cosMeio - raioAlvo / d
end

-- O golpe veio de frente para quem está olhando em 'olhar'? (guarda frontal de 140°)
function Combate.deFrente(posDefensor: Vector3, olhar: Vector3, posAtacante: Vector3): boolean
	local rel = plano(posAtacante - posDefensor)
	local f = plano(olhar)
	if rel.Magnitude < 0.5 or f.Magnitude < 1e-4 then
		return true
	end
	return rel.Unit:Dot(f.Unit) >= math.cos(math.rad(70))
end

return Combate
