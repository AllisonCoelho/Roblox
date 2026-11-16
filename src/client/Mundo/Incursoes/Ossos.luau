-- Animação por código dos inimigos IMPORTADOS no Studio (modelos riggados do Blender com Bones).
-- Não precisa publicar animações: cada osso conhecido recebe um Transform calculado aqui.
-- Os nomes dos ossos vêm do gerador (assets/incursoes/inimigos): Raiz, Quadril, Tronco, Peito,
-- Cabeca, Braco.L/R, Antebraco.L/R, Coxa.L/R, Canela.L/R, Cauda1..3, Asa.L/R.
local Ossos = {}

export type Rig = { ossos: { [string]: Bone }, fase: number, t: number }

function Ossos.ligar(modelo: Model): Rig?
	local ossos: { [string]: Bone } = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("Bone") then
			ossos[d.Name] = d
		end
	end
	if next(ossos) == nil then
		return nil
	end
	return { ossos = ossos, fase = math.random() * 10, t = math.random() * 10 }
end

local function girar(rig: Rig, nome: string, x: number, y: number, z: number)
	local o = rig.ossos[nome]
	if o then
		o.Transform = CFrame.Angles(x, y, z)
	end
end

local function mover(rig: Rig, nome: string, p: Vector3, x: number, y: number, z: number)
	local o = rig.ossos[nome]
	if o then
		o.Transform = CFrame.new(p) * CFrame.Angles(x, y, z)
	end
end

-- passo: 0 parado .. 1 correndo; desdeAtaque: segundos desde o último ataque; morte: segundos
function Ossos.animar(rig: Rig, dt: number, passo: number, desdeAtaque: number, morte: number?)
	rig.t += dt
	rig.fase += dt * (2 + 7 * passo)
	local t, f = rig.t, rig.fase
	local resp = math.sin(t * 1.8)
	local perna = math.sin(f) * 0.7 * passo
	local ataque = if desdeAtaque < 0.45 then math.sin(desdeAtaque / 0.45 * math.pi) else 0
	local queda = if morte then math.clamp(morte / 0.5, 0, 1) else 0

	mover(
		rig,
		"Quadril",
		Vector3.new(0, math.abs(math.sin(f)) * 0.2 * passo, 0),
		0,
		0,
		math.sin(f) * 0.05 * passo
	)
	girar(
		rig,
		"Tronco",
		0.08 * resp * (1 - passo) + 0.18 * passo - 0.35 * ataque + 0.9 * queda,
		math.sin(f) * 0.1 * passo,
		0
	)
	girar(rig, "Peito", 0.05 * resp, 0, 0)
	girar(rig, "Cabeca", -0.1 * passo + 0.08 * math.sin(t * 0.7), 0.25 * math.sin(t * 0.4), 0)
	girar(rig, "Coxa.L", perna, 0, 0)
	girar(rig, "Coxa.R", -perna, 0, 0)
	girar(rig, "Canela.L", math.max(0, -math.cos(f)) * 0.9 * passo, 0, 0)
	girar(rig, "Canela.R", math.max(0, math.cos(f)) * 0.9 * passo, 0, 0)
	girar(rig, "Braco.L", -perna * 0.8 - 1.4 * ataque, 0, -0.1 - 0.05 * resp)
	girar(rig, "Braco.R", perna * 0.8 - 1.6 * ataque, 0, 0.1 + 0.05 * resp)
	girar(rig, "Antebraco.L", -0.3 - 0.6 * ataque, 0, 0)
	girar(rig, "Antebraco.R", -0.3 - 0.8 * ataque, 0, 0)
	for k = 1, 3 do
		girar(rig, "Cauda" .. k, 0.1 * math.sin(t * 2 - k), 0.3 * math.sin(t * 1.6 - k * 0.8), 0)
	end
	girar(rig, "Asa.L", 0, 0.2 * math.sin(t * 1.4), 0.15 * math.sin(t * 1.4))
	girar(rig, "Asa.R", 0, -0.2 * math.sin(t * 1.4), -0.15 * math.sin(t * 1.4))
end

return Ossos
