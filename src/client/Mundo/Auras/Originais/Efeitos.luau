-- Efeitos (partículas, rastro, luz) das 67 auras originais v2, montados só neste cliente.
-- A receita de cada aura está em Shared/Dados/EfeitosOriginais.luau: 2–5 camadas de presets
-- com as cores da aura. Cada camada emite de uma peça invisível (forma e área próprias) que segue
-- o corpo; nada é criado por quadro. Pico/manifestação: rajadas. Correndo: rastro e mais emissão.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dados = require(Shared:WaitForChild("Dados"):WaitForChild("EfeitosOriginais")) :: any

local Efeitos = {}

local ARCO_IRIS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF7A7A")),
	ColorSequenceKeypoint.new(0.25, Color3.fromHex("FFD36B")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("7BF0A0")),
	ColorSequenceKeypoint.new(0.75, Color3.fromHex("77C8FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("D49BFF")),
})

export type Efeito = {
	atualizar: (
		self: Efeito,
		dt: number,
		base: CFrame,
		rapidez: number,
		nivel: number,
		opacidade: number
	) -> (),
	rajada: (self: Efeito, forca: number) -> (),
	definirQualidade: (self: Efeito, baixa: boolean, reduzido: boolean) -> (),
	destruir: (self: Efeito) -> (),
}

type Camada = {
	preset: { [string]: any },
	emissor: ParticleEmitter,
	suporte: Part,
	taxa: number,
	deslocar: Vector3,
	relogio: number,
	angulo: number,
}

local function par(t: { number }?, padrao: number): NumberRange
	if not t then
		return NumberRange.new(padrao)
	end
	return NumberRange.new(math.min(t[1], t[2]), math.max(t[1], t[2]))
end

function Efeitos.tem(id: string): boolean
	return Dados.AURAS[id] ~= nil
end

function Efeitos.criar(
	id: string,
	raiz: BasePart,
	escala: number,
	cores: { Color3 },
	pasta: Instance
): Efeito?
	local receita = Dados.AURAS[id]
	if not receita then
		return nil
	end
	local camadas: { Camada } = {}
	for indice, c in receita.camadas do
		local p = Dados.PRESETS[c[1]]
		local cor = cores[c[2]] or cores[1]
		local tam = c[4] * escala
		local suporte = Instance.new("Part")
		suporte.Name = "Efeito_" .. c[1]
		suporte.Anchored = true
		suporte.CanCollide = false
		suporte.CanTouch = false
		suporte.CanQuery = false
		suporte.CastShadow = false
		suporte.Transparency = 1
		suporte.Size = Vector3.new(p.area[1], p.area[2], p.area[3]) * escala
		suporte.Parent = pasta
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/" .. p.textura .. ".dds"
		e.Color = if p.arcoiris
			then ARCO_IRIS
			else ColorSequence.new(cor, cor:Lerp(Color3.new(1, 1, 1), 0.35))
		e.LightEmission = p.brilho or 0.8
		e.LightInfluence = 0
		local t = p.tam
		e.Size = if #t == 3
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, t[1] * tam),
				NumberSequenceKeypoint.new(0.5, t[2] * tam),
				NumberSequenceKeypoint.new(1, t[3] * tam),
			})
			else NumberSequence.new(t[1] * tam, t[2] * tam)
		local tr = p.transp or { 0, 1 }
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.max(tr[1], 0.05) + 0.3),
			NumberSequenceKeypoint.new(0.15, tr[1]),
			NumberSequenceKeypoint.new(1, tr[2]),
		})
		e.Lifetime = par(p.vida, 1)
		e.Speed = NumberRange.new(p.vel[1] * escala, p.vel[2] * escala)
		local sp = p.spread or { 180, 180 }
		e.SpreadAngle = Vector2.new(sp[1], sp[2])
		local ac = p.acel or { 0, 0, 0 }
		e.Acceleration = Vector3.new(ac[1], ac[2], ac[3]) * escala
		e.Drag = p.arrasto or 0
		e.Rotation = par(p.rot, 0)
		e.RotSpeed = par(p.rotVel, 0)
		e.Squash = if p.squash
			then NumberSequence.new(p.squash[1], p.squash[2])
			else NumberSequence.new(0)
		e.Shape = (Enum.ParticleEmitterShape :: any)[p.forma]
		e.ShapeStyle = (Enum.ParticleEmitterShapeStyle :: any)[p.estilo or "Volume"]
		e.EmissionDirection = (Enum.NormalId :: any)[p.direcao or "Top"]
		e.Orientation = (Enum.ParticleOrientation :: any)[p.orientacao or "FacingCamera"]
		e.LockedToPart = p.preso == true
		e.ZOffset = indice * 0.05
		e.Rate = 0
		e.Parent = suporte
		local d = p.deslocar or { 0, 0, 0 }
		table.insert(camadas, {
			preset = p,
			emissor = e,
			suporte = suporte,
			taxa = (p.taxa or 0) * c[3],
			deslocar = Vector3.new(d[1], d[2], d[3]) * escala,
			relogio = (indice - 1) * 0.7,
			angulo = indice * 2.1,
		})
	end

	-- rastro (Raro para cima) e luz (Incomum para cima)
	local trilha: Trail? = nil
	local a0, a1
	if receita.rastro then
		a0 = Instance.new("Attachment")
		a0.Name = "AuraOriginalRastro0"
		a0.Position = Vector3.new(0, 1.2, 0.4) * escala
		a1 = Instance.new("Attachment")
		a1.Name = "AuraOriginalRastro1"
		a1.Position = Vector3.new(0, -1.4, 0.4) * escala
		a0.Parent, a1.Parent = raiz, raiz
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(cores[1], cores[2])
		tr.Transparency = NumberSequence.new(0.35, 1)
		tr.LightEmission = 1
		tr.Lifetime = 0.35
		tr.MinLength = 0.2
		tr.FaceCamera = true
		tr.Enabled = false
		tr.Parent = raiz
		trilha = tr
	end
	local luz: PointLight? = nil
	if receita.luz then
		local l = Instance.new("PointLight")
		l.Name = "AuraOriginalLuz"
		l.Color = cores[1]
		l.Range = 8 * escala
		l.Brightness = 0.7
		l.Shadows = false
		l.Parent = raiz
		luz = l
	end

	local baixa, reduzido = false, false
	local tempo = 0
	local efeito = {} :: any

	function efeito.definirQualidade(_self, b: boolean, r: boolean)
		baixa, reduzido = b, r
	end

	function efeito.rajada(_self, forca: number)
		if baixa then
			return
		end
		for _, c in camadas do
			c.emissor:Emit(math.floor((c.preset.rajada or 6) * forca + 0.5))
		end
	end

	function efeito.atualizar(
		_self,
		dt: number,
		base: CFrame,
		rapidez: number,
		nivel: number,
		opacidade: number
	)
		tempo += dt
		local movendo = math.clamp(rapidez / 16, 0, 1)
		for i, c in camadas do
			local p = c.preset
			-- qualidade baixa: só a primeira camada, a meia taxa; longe: nada
			local ligada = nivel == 2 and opacidade > 0.05 and (not baixa or i == 1)
			local cf = base * CFrame.new(c.deslocar)
			if p.espiral then
				c.angulo += dt * 2.2
				cf *= CFrame.Angles(0, c.angulo, 0)
			elseif p.orbitar then
				c.angulo += dt * 1.6
				cf = base * CFrame.Angles(0, c.angulo, 0) * CFrame.new(c.deslocar)
			end
			c.suporte.CFrame = cf
			local taxa = if ligada
				then c.taxa * (1 + 0.6 * movendo) * (if baixa then 0.5 else 1)
				else 0
			c.emissor.Rate = taxa * opacidade
			if ligada and p.periodo and not reduzido then
				c.relogio += dt
				if c.relogio >= p.periodo then
					c.relogio -= p.periodo
					c.emissor:Emit(p.rajada or 1)
				end
			end
		end
		if trilha then
			trilha.Enabled = nivel == 2 and not baixa and rapidez > 6 and opacidade > 0.3
		end
		if luz then
			luz.Enabled = nivel == 2 and not baixa
			luz.Brightness = (0.6 + (if reduzido then 0 else 0.25 * math.sin(tempo * 2)))
				* opacidade
		end
	end

	function efeito.destruir(_self)
		for _, c in camadas do
			c.suporte:Destroy()
		end
		table.clear(camadas)
		if trilha then
			trilha:Destroy()
		end
		if a0 then
			a0:Destroy()
			a1:Destroy()
		end
		if luz then
			luz:Destroy()
		end
	end

	local _ = Workspace
	return efeito :: Efeito
end

return Efeitos
