-- Motor das auras originais v2 (lote inicial). VFX montado só neste cliente.
-- Pipeline v2: clona os MeshParts importados no Studio de ReplicatedStorage.AurasOriginais.<id>
-- (assets/roblox/auras_originais/<id>.rbxm); NADA de EditableMesh nem MeshId em runtime.
-- O comportamento de cada peça vem de Definicoes.luau (gerado pelo Blender):
--   ancora  = ponto fixo no corpo (balança, gira, oscila);  orbita = elipse inclinada em volta do corpo;
--   pendulo = arco atrás do avatar, indo e voltando (o leviatã nadando).
-- Correndo, cada peça vai para "correr"; no pico (12–20 s) e na manifestação, "abrir" + efeito especial.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Gear5 = require(script.Parent.Parent.Gear5) -- só tipos (contrato comum das auras)
local Definicoes = require(script.Parent.Definicoes) :: { [string]: any }
local Efeitos = require(script.Parent.Efeitos)
local Catalogo = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("AurasOriginaisV2")
) :: any

local Motor = {}

local CABECA_PADRAO = 1.5
local LOD_DETALHE, LOD_OCULTO = 80, 140
local DURACAO_MANIFESTAR, DURACAO_PICO, DURACAO_SAIDA = 1.4, 1.6, 0.25
local ARCO_IRIS = { "FF7A7A", "FFC46B", "FBE09A", "7BF0A0", "77C8FF", "C4B6FF" }

local avisados: { [string]: boolean } = {}

local function v3(t: { number }?): Vector3
	if not t then
		return Vector3.zero
	end
	return Vector3.new(t[1], t[2], t[3])
end

local function graus(t: { number }?): CFrame
	if not t then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(t[1]), math.rad(t[2]), math.rad(t[3]))
end

local function easeOutBack(t: number): number
	local c1 = 1.4
	local u = t - 1
	return 1 + (c1 + 1) * u * u * u + c1 * u * u
end

-- Valida ReplicatedStorage.AurasOriginais.<id>; devolve os templates ou nil + motivo
function Motor.templates(id: string, espera: number?): ({ [string]: MeshPart }?, string?)
	local def = Definicoes[id]
	if not def then
		return nil, "aura sem definição: " .. id
	end
	local raiz = ReplicatedStorage:FindFirstChild("AurasOriginais")
		or (espera and ReplicatedStorage:WaitForChild("AurasOriginais", espera))
	local modelo = raiz and raiz:FindFirstChild(id)
	if not modelo then
		return nil,
			"ReplicatedStorage.AurasOriginais."
				.. id
				.. " não existe (importe e salve "
				.. id
				.. ".rbxm)"
	end
	local achados = {}
	for nome in def.templates do
		local t = modelo:FindFirstChild(nome, true)
		if not t or not t:IsA("MeshPart") or t.MeshId == "" then
			return nil, id .. "." .. nome .. " ausente, não é MeshPart ou sem MeshId"
		end
		achados[nome] = t
	end
	return achados
end

type Peca = {
	cfg: { [string]: any },
	parte: MeshPart,
	tamanho: Vector3,
	centro: Vector3,
	pos: Vector3,
	vel: Vector3,
	angulo: number,
	fase: number,
	transp: number,
	ordem: number,
}

function Motor.criar(id: string, personagem: Model, opcoes: Gear5.Opcoes): Gear5.Instancia?
	local raiz = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return nil
	end
	local aura = Catalogo.porId[id]
	if not aura then
		return nil
	end
	-- malhas 3D só quando o template importado existe; os efeitos aparecem sempre
	local templates: { [string]: MeshPart }? = nil
	local def = Definicoes[id]
	if def then
		local motivo
		templates, motivo = Motor.templates(id, if avisados[id] then nil else 1)
		if not templates and not avisados[id] then
			avisados[id] = true
			warn("[AurasOriginais] " .. tostring(motivo) .. " — mostrando só os efeitos.")
		end
	end
	local cabeca = personagem:FindFirstChild("Head") :: BasePart?
	local escala = 1
	if cabeca then
		escala = math.clamp((cabeca.Position - raiz.Position).Y / CABECA_PADRAO, 0.6, 2.5)
	end
	local cores = { Color3.fromHex(aura.cores[1]), Color3.fromHex(aura.cores[2]) }
	local aleatorio = Random.new() -- só cosmético
	local pasta = Instance.new("Folder")
	pasta.Name = "AuraOriginal_" .. id .. "_" .. personagem.Name

	local function clonar(nome: string, cfg: { [string]: any }): (MeshPart, Vector3, Vector3)
		local parte = (templates :: { [string]: MeshPart })[nome]:Clone()
		parte.Anchored = true
		parte.CanCollide = false
		parte.CanTouch = false
		parte.CanQuery = false
		parte.CastShadow = false
		parte.Massless = true
		parte.Color = cores[(cfg.cor or 0) + 1]
		parte.Material = (Enum.Material :: any)[cfg.material or "SmoothPlastic"]
		parte.Transparency = 1
		parte.Parent = pasta
		local t = def.templates[nome]
		return parte, v3(t.tamanho), v3(t.centro)
	end

	local pecas: { Peca } = {}
	local esp = if def and templates then def.especial else { n = 0 }
	for i, cfg in (if def and templates then def.pecas else {}) :: { any } do
		local parte, tamanho, centro = clonar(cfg.template, cfg)
		table.insert(pecas, {
			cfg = cfg,
			parte = parte,
			tamanho = tamanho,
			centro = centro,
			pos = raiz.Position,
			vel = Vector3.zero,
			angulo = cfg.ang or 0,
			fase = aleatorio:NextNumber(0, math.pi * 2),
			transp = cfg.transp or 0,
			ordem = i,
		})
	end
	local especiais: { { parte: MeshPart, tamanho: Vector3, centro: Vector3 } } = {}
	for k = 1, esp.n do
		local parte, tamanho, centro = clonar(esp.template, esp)
		if esp.arco_iris then
			parte.Color = Color3.fromHex(ARCO_IRIS[(k - 1) % #ARCO_IRIS + 1])
		end
		table.insert(especiais, { parte = parte, tamanho = tamanho, centro = centro })
	end

	local efeitos = Efeitos.criar(id, raiz, escala, cores, pasta)
	if efeitos then
		efeitos:definirQualidade(opcoes.qualidadeBaixa, opcoes.movimentoReduzido)
	end
	local brilho = Instance.new("ParticleEmitter")
	brilho.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	brilho.Color = ColorSequence.new(cores[1], cores[2])
	brilho.LightEmission = 1
	brilho.Size = NumberSequence.new(0.14 * escala, 0)
	brilho.Lifetime = NumberRange.new(0.4, 0.8)
	brilho.Rate = 0
	brilho.Speed = NumberRange.new(1, 3)
	brilho.SpreadAngle = Vector2.new(180, 180)
	brilho.Parent = raiz

	local baixa, reduzido = opcoes.qualidadeBaixa, opcoes.movimentoReduzido
	local tempo = 0
	local manifestando: number? = if opcoes.manifestar then 0 else nil
	local pico: number? = nil
	local proximoPico = aleatorio:NextNumber(12, 20)
	local saindo: number? = nil
	local nivel = 2
	local acumulado = 0
	local destruida = false
	local inst = {} :: any

	local function destruir()
		destruida = true
		pasta:Destroy()
		brilho:Destroy()
		if efeitos then
			efeitos:destruir()
		end
	end

	local function ativa(p: Peca): boolean
		if nivel == 1 then
			return p.ordem <= 3
		end
		return not (baixa and p.cfg.detalhe)
	end

	function inst.definirQualidade(_self, b: boolean, r: boolean)
		baixa, reduzido = b, r
		if efeitos then
			efeitos:definirQualidade(b, r)
		end
		if b or r then
			pico = nil
		end
	end
	function inst.manifestar(_self)
		manifestando = 0
	end
	function inst.encerrar(_self, imediato: boolean?)
		if imediato then
			if not destruida then
				destruir()
			end
		elseif not saindo then
			saindo = 0
		end
	end

	function inst.atualizar(_self, dt: number, camera: Vector3): boolean
		if destruida then
			return false
		end
		if not raiz.Parent or not personagem.Parent then
			destruir()
			return false
		end
		dt = math.min(dt, 1 / 20)
		tempo += dt
		local distancia = (camera - raiz.Position).Magnitude
		local novo = if distancia >= LOD_OCULTO then 0 elseif distancia >= LOD_DETALHE then 1 else 2
		if novo ~= nivel then
			nivel = novo
			pasta.Parent = if nivel > 0 then Workspace else nil
		end
		if nivel == 0 then
			if saindo then
				destruir()
				return false
			end
			return true
		end
		if nivel == 1 then
			acumulado += dt
			if acumulado < 0.1 then
				return true
			end
			dt, acumulado = math.min(acumulado, 0.1), 0
		end

		local opacidade = 1
		if saindo then
			saindo += dt
			opacidade = 1 - math.min(saindo / DURACAO_SAIDA, 1)
			if saindo >= DURACAO_SAIDA then
				destruir()
				return false
			end
		end

		local cf0 = raiz.CFrame
		local olhar = cf0.LookVector
		local base = CFrame.lookAt(cf0.Position, cf0.Position + Vector3.new(olhar.X, 0, olhar.Z))
		local velocidade = raiz.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocidade.X, 0, velocidade.Z)
		local rapidez = horizontal.Magnitude
		local andar = math.clamp(rapidez / 12, 0, 1)
		local corrida = math.clamp((rapidez - 8) / 12, 0, 1)
		local dirLocal = if rapidez > 1
			then base:VectorToObjectSpace(horizontal.Unit)
			else Vector3.zero
		local amp = if reduzido then 0.4 else 1

		-- pico cosmético (fase própria por jogador); nunca em qualidade baixa ou movimento reduzido
		local abrir = 0
		if pico then
			pico += dt
			abrir = math.sin(math.min(pico / DURACAO_PICO, 1) * math.pi)
			if pico >= DURACAO_PICO then
				pico = nil
				proximoPico = tempo + aleatorio:NextNumber(12, 20)
			end
		elseif tempo >= proximoPico then
			if nivel == 2 and not baixa and not reduzido and not manifestando and not saindo then
				pico = 0
				brilho:Emit(10)
				if efeitos then
					efeitos:rajada(1)
				end
			else
				proximoPico = tempo + 4
			end
		end
		local especial = 0 -- 0..1: força do efeito especial (manifestação inteira, pico a 60%)
		local fracEspecial = 0
		if manifestando then
			fracEspecial = manifestando / DURACAO_MANIFESTAR
			especial = math.sin(math.min(fracEspecial, 1) * math.pi)
			abrir = math.max(abrir, especial * 0.7)
			if manifestando == 0 and not reduzido then
				brilho:Emit(14)
				if efeitos then
					efeitos:rajada(1.5)
				end
			end
			manifestando += dt
			if manifestando >= DURACAO_MANIFESTAR then
				manifestando = nil
			end
		elseif pico then
			fracEspecial = pico / DURACAO_PICO
			especial = abrir * 0.6
		end

		for _, p in pecas do
			local cfg = p.cfg
			if not ativa(p) then
				p.parte.Transparency = 1
				continue
			end
			local crescer = 1
			if manifestando then
				local t = math.clamp((manifestando - 0.08 * (p.ordem - 1)) / 0.45, 0, 1)
				crescer = if t <= 0 then 0 else easeOutBack(t)
			end
			local off: Vector3
			local rotacao = graus(cfg.rot)
			if cfg.modo == "orbita" then
				p.angulo += cfg.vel * dt * amp
				local a = p.angulo
				local r = 1 + 0.35 * abrir
				off = Vector3.new(
					math.cos(a) * cfg.rx * r,
					cfg.altura + cfg.inclinacao * math.sin(a + 0.8),
					math.sin(a) * cfg.rz * r
				)
				local tangente = Vector3.new(-math.sin(a) * cfg.rx, 0, math.cos(a) * cfg.rz)
					* (if cfg.vel >= 0 then 1 else -1)
				rotacao = CFrame.lookAt(Vector3.zero, tangente).Rotation * rotacao
			elseif cfg.modo == "pendulo" then
				local s = math.sin(tempo * cfg.vel * amp + p.fase)
				local a = math.pi / 2 + cfg.abertura * s -- sempre atrás (+Z)
				off = Vector3.new(
					math.cos(a) * cfg.raio,
					cfg.altura + 0.4 * math.sin(tempo * 0.7),
					math.sin(a) * cfg.raio
				)
				local sentido = if math.cos(tempo * cfg.vel * amp + p.fase) >= 0 then 1 else -1
				local tangente = Vector3.new(-math.sin(a), 0.08 * s, math.cos(a)) * sentido
				rotacao = CFrame.lookAt(Vector3.zero, tangente).Rotation * rotacao
			else
				off = v3(cfg.pos)
			end
			off += v3(cfg.abrir) * abrir
			if cfg.bob then
				off += Vector3.new(0, cfg.bob * amp * math.sin(tempo * 1.3 + p.fase), 0)
			end
			if cfg.correr and corrida > 0 then
				off = off:Lerp(v3(cfg.correr), corrida)
			end
			-- giro contínuo + oscilação + abertura + inclinação na corrida
			local g = v3(cfg.giro) * tempo * amp
			if cfg.osc then
				local eixo, ampOsc, freq = cfg.osc[1], cfg.osc[2], cfg.osc[3]
				local o = ampOsc * amp * math.sin(tempo * freq * math.pi * 2 + p.fase)
				g += Vector3.new(
					if eixo == 0 then o else 0,
					if eixo == 1 then o else 0,
					if eixo == 2 then o else 0
				)
			end
			if cfg.abrirGiro then
				g += v3(cfg.abrirGiro) * abrir
			end
			local extra = CFrame.Angles(math.rad(g.X), math.rad(g.Y), math.rad(g.Z))
			if cfg.correrRot and corrida > 0 then
				rotacao = rotacao:Lerp(graus(cfg.correrRot), corrida)
			end
			if cfg.apontar and rapidez > 1 then
				local eixo = Vector3.yAxis:Cross(dirLocal)
				if eixo.Magnitude > 1e-3 then
					rotacao = CFrame.fromAxisAngle(eixo.Unit, 0.6 * andar) * rotacao
				end
			end

			-- mola: segue o corpo com atraso e reage ao pulo; limite contra teleporte
			local alvo = base:PointToWorldSpace(off * escala)
			local k = cfg.rigidez or 40
			local amortecer = 2 * 0.6 * math.sqrt(k)
			p.vel += ((alvo - p.pos) * k - p.vel * amortecer) * dt
			p.pos += p.vel * dt
			local maxAtraso = (cfg.atraso or 0.6) * escala * (1 + corrida)
			local atraso = p.pos - alvo
			if atraso.Magnitude > maxAtraso * 4 or crescer <= 0 then
				p.pos, p.vel = alvo, Vector3.zero
			elseif atraso.Magnitude > maxAtraso then
				p.pos = alvo + atraso.Unit * maxAtraso
			end

			local pulso = 1 + (cfg.pulso or 0) * math.sin(tempo * 3 + p.fase)
			local s = escala
				* (cfg.escala or 1)
				* crescer
				* pulso
				* (1 + (cfg.abrirEscala or 0) * abrir)
			if crescer > 0.02 then
				local espelho = if cfg.espelhar then -1 else 1
				p.parte.Size = p.tamanho * s
				local cf = CFrame.new(p.pos) * base.Rotation * rotacao * extra
				p.parte.CFrame = cf * CFrame.new(p.centro * s * Vector3.new(espelho, 1, 1))
				p.parte.Transparency = 1 - (1 - p.transp) * opacidade
			else
				p.parte.Transparency = 1
			end
		end

		-- efeito especial: n cópias saem da origem (radial ou em arco atrás) e voltam
		if efeitos then
			efeitos:atualizar(dt, base, rapidez, nivel, opacidade)
		end
		local origem = base * CFrame.new(v3(esp.origem or { 0, 0, 0 }) * escala)
		for k, e in especiais do
			if especial <= 0.02 or nivel < 2 or (baixa and k > 2) then
				e.parte.Transparency = 1
				continue
			end
			local a = (k - 1) / esp.n * math.pi * 2
			local dir = if esp.arco
				then Vector3.new(
					math.cos(math.pi * (k - 0.5) / esp.n),
					math.sin(math.pi * (k - 0.5) / esp.n) * 0.6,
					0.3
				)
				else Vector3.new(math.cos(a), math.sin(a * 2) * 0.3, math.sin(a))
			local distancia2 = esp.raio * escala * especial
			local s = escala * esp.escala * especial
			local giro = CFrame.Angles(0, -a, 0)
				* CFrame.Angles(0, 0, math.rad(esp.girar or 0) * fracEspecial)
			e.parte.Size = e.tamanho * s
			local cf = (origem * CFrame.new(dir * distancia2)) * giro
			e.parte.CFrame = cf * CFrame.new(e.centro * s)
			e.parte.Transparency = 1 - (0.15 + 0.85 * especial) * opacidade
		end

		-- primeira pessoa: o que estiver perto da lente some só para este jogador
		if opcoes.local_ and cabeca then
			local primeira = (camera - cabeca.Position).Magnitude < 1.5
			for _, p in pecas do
				p.parte.LocalTransparencyModifier = if primeira
						and (p.parte.Position - camera).Magnitude < 3 * escala
					then 1
					else 0
			end
		end
		if pasta.Parent == nil and nivel > 0 then
			pasta.Parent = Workspace
		end
		return true
	end

	local cam = Workspace.CurrentCamera
	inst:atualizar(0, if cam then cam.CFrame.Position else raiz.Position)
	return inst :: Gear5.Instancia
end

-- Um "módulo" no formato que o Controlador espera, para cada aura do lote
function Motor.modulo(id: string)
	return {
		criar = function(personagem: Model, opcoes: Gear5.Opcoes): Gear5.Instancia?
			return Motor.criar(id, personagem, opcoes)
		end,
	}
end

Motor.IDS = {} :: { string }
for id in
	require(
		ReplicatedStorage:WaitForChild("Shared")
			:WaitForChild("Dados")
			:WaitForChild("EfeitosOriginais")
	).AURAS
do
	table.insert(Motor.IDS, id)
end
table.sort(Motor.IDS)

return Motor
