-- Gear 5 — "nuvens vivas". VFX da aura equipada, montado só neste cliente.
-- Não anima o corpo: as nuvens reagem ao personagem (parado, andando, correndo, pulando).
--
-- Peças (Blender, Gear5Pecas.luau): um ARCO aberto e assimétrico atrás e acima da cabeça,
-- dois lobos grandes, duas pontas em caracol, dois rolos nos ombros e dois bancos na cintura.
-- Cada peça segue o corpo por uma mola própria (as pontas e os bancos atrasam mais), respira
-- fora de fase e balança em volta do próprio pivô. Mechas pequenas se soltam no rastro.
local MalhaNuvem = require(script.Parent.MalhaNuvem)
local Pecas = require(script.Parent.Gear5Pecas)

local Gear5 = {}

export type Opcoes = {
	manifestar: boolean, -- entrada de ~1,2 s (só no ato de equipar)
	qualidadeBaixa: boolean,
	movimentoReduzido: boolean,
	local_: boolean, -- personagem deste jogador (esconde em primeira pessoa)
}

export type Instancia = {
	atualizar: (self: Instancia, dt: number, camera: Vector3) -> boolean,
	definirQualidade: (self: Instancia, baixa: boolean, movimentoReduzido: boolean) -> (),
	manifestar: (self: Instancia) -> (),
	encerrar: (self: Instancia, imediato: boolean?) -> (),
}

-- Cores (tabela 2.3 do briefing). A cor do corpo vem dos vértices; a parte fica branca.
local COR_CONTORNO = Color3.fromHex("5C5299")
local COR_BRILHO = Color3.fromHex("DED6FF")

-- Altura da cabeça acima do HumanoidRootPart num R15 padrão (as malhas foram feitas nessa escala)
local CABECA_PADRAO = 1.5

local DURACAO_MANIFESTAR = 1.2
local DURACAO_BURST = 1.5
local DURACAO_SAIDA = 0.22
local LOD_DETALHE = 80 -- além disso: sem contorno, mechas nem brilho; atualização a 10 Hz
local LOD_OCULTO = 140 -- além disso: nada visível

type Peca = {
	cfg: { [string]: any },
	corpo: MeshPart,
	contorno: MeshPart?,
	tamCorpo: Vector3,
	tamContorno: Vector3,
	centroCorpo: Vector3, -- do pivô até o centro da malha (escala 1)
	centroContorno: Vector3,
	pivo: Vector3,
	pos: Vector3, -- posição do pivô no mundo (com a mola)
	vel: Vector3,
	fase: number,
}

type Mecha = { parte: MeshPart, vida: number, deriva: Vector3, ativa: boolean }

local function easeOutBack(t: number): number
	-- passa ~10% do tamanho final e volta (o "overshoot elástico" da manifestação)
	local c1 = 1.70158
	local c3 = c1 + 1
	local u = t - 1
	return 1 + c3 * u * u * u + c1 * u * u
end

local function limitar(v: Vector3, maximo: number): Vector3
	local m = v.Magnitude
	if m > maximo and m > 1e-6 then
		return v * (maximo / m)
	end
	return v
end

function Gear5.criar(personagem: Model, opcoes: Opcoes): Instancia?
	local raiz = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cabeca = personagem:FindFirstChild("Head") :: BasePart?
	if not raiz then
		return nil
	end
	-- Escala pela altura real (R6, R15, avatares maiores ou menores)
	local escala = 1
	if cabeca then
		local alt = (cabeca.Position - raiz.Position).Y
		escala = math.clamp(alt / CABECA_PADRAO, 0.6, 2.5)
	end

	local aleatorio = Random.new() -- só cosmético: cada jogador fica em uma fase diferente
	local pasta = Instance.new("Folder")
	pasta.Name = "AuraGear5"

	local baixa = opcoes.qualidadeBaixa
	local reduzido = opcoes.movimentoReduzido
	local pecas: { Peca } = {}
	local mechas: { Mecha } = {}

	for _, cfg in Pecas :: { { [string]: any } } do
		local pivo = Vector3.new(cfg.pivo[1], cfg.pivo[2], cfg.pivo[3])
		local corpo, centro = MalhaNuvem.criar("gear5_" .. cfg.nome, false)
		corpo.Material = Enum.Material.SmoothPlastic
		corpo.Color = Color3.new(1, 1, 1)
		corpo.Transparency = 1
		corpo.Parent = pasta
		local contorno, centroC = MalhaNuvem.criar("gear5_" .. cfg.nome, true)
		contorno.Material = Enum.Material.SmoothPlastic
		contorno.Color = COR_CONTORNO
		contorno.Transparency = 1
		contorno.Parent = pasta
		table.insert(pecas, {
			cfg = cfg,
			corpo = corpo,
			contorno = contorno,
			tamCorpo = corpo.Size,
			tamContorno = contorno.Size,
			centroCorpo = centro - pivo,
			centroContorno = centroC - pivo,
			pivo = pivo,
			pos = (raiz.CFrame * CFrame.new(pivo * escala)).Position,
			vel = Vector3.zero,
			fase = aleatorio:NextNumber(0, math.pi * 2),
		})
	end
	for _ = 1, 6 do
		local parte = MalhaNuvem.criar("gear5_mecha", false)
		parte.Material = Enum.Material.SmoothPlastic
		parte.Transparency = 1
		parte.Parent = pasta
		table.insert(mechas, { parte = parte, vida = 0, deriva = Vector3.zero, ativa = false })
	end
	local tamMecha = mechas[1].parte.Size

	-- Brilho: luz suave na FRENTE do peito, iluminando a face das nuvens que a câmera vê
	local anexoLuz = Instance.new("Attachment")
	anexoLuz.Name = "AuraGear5Luz"
	anexoLuz.Position = Vector3.new(0, 2.2, -2.2) * escala
	local luz = Instance.new("PointLight")
	luz.Color = COR_BRILHO
	luz.Range = 10 * escala
	luz.Brightness = 1.4
	luz.Shadows = false
	luz.Parent = anexoLuz
	-- Poucas faíscas brancas (nunca a estrutura)
	local faiscas = Instance.new("ParticleEmitter")
	faiscas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	faiscas.Color = ColorSequence.new(Color3.new(1, 1, 1))
	faiscas.LightEmission = 1
	faiscas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18 * escala),
		NumberSequenceKeypoint.new(1, 0),
	})
	faiscas.Lifetime = NumberRange.new(0.5, 0.9)
	faiscas.Rate = 2
	faiscas.Speed = NumberRange.new(0.3, 0.8)
	faiscas.SpreadAngle = Vector2.new(180, 180)
	faiscas.Parent = anexoLuz
	anexoLuz.Parent = raiz
	pasta.Parent = workspace

	-- estado
	local tempo = aleatorio:NextNumber(0, 100)
	local manifestando = if opcoes.manifestar then 0 else nil :: number?
	local proximoBurst = aleatorio:NextNumber(12, 20)
	local burst: number? = nil
	local saindo: number? = nil
	local velYAnterior = 0
	local amasso: number? = nil -- pouso: o alto comprime e volta
	local proximaMecha = 0
	local acumulado = 0
	local detalhe = true
	local visivel = true
	local transpAtual = 1

	local inst = {} :: any
	local destruida = false

	local function destruir()
		destruida = true
		pasta:Destroy()
		anexoLuz:Destroy()
	end

	local function soltarMecha(onde: Vector3, deriva: Vector3)
		for _, m in mechas do
			if not m.ativa then
				m.ativa = true
				m.vida = 0
				m.deriva = deriva
				m.parte.CFrame = CFrame.new(onde)
					* CFrame.Angles(
						0,
						aleatorio:NextNumber(0, math.pi * 2),
						aleatorio:NextNumber(-0.6, 0.6)
					)
				return
			end
		end
	end

	local function mostrarDetalhe(ligado: boolean)
		detalhe = ligado
		luz.Enabled = ligado and not baixa
		faiscas.Enabled = ligado and not baixa
	end
	mostrarDetalhe(true)

	function inst.definirQualidade(_self, novaBaixa: boolean, novoReduzido: boolean)
		baixa = novaBaixa
		reduzido = novoReduzido
		mostrarDetalhe(detalhe)
	end

	function inst.manifestar(_self)
		manifestando = 0
	end

	function inst.encerrar(_self, imediato: boolean?)
		if imediato then
			destruir()
			return
		end
		if saindo == nil then
			saindo = 0
		end
	end

	-- Devolve false quando terminou (e já limpou tudo)
	function inst.atualizar(_self, dt: number, camera: Vector3): boolean
		if destruida then
			return false
		end
		if not raiz.Parent then
			destruir()
			return false
		end
		dt = math.min(dt, 1 / 20)
		tempo += dt

		-- LOD por distância da câmera
		local distancia = (camera - raiz.Position).Magnitude
		local deveVer = distancia < LOD_OCULTO
		if deveVer ~= visivel then
			visivel = deveVer
			pasta.Parent = if deveVer then workspace else nil
		end
		if (distancia < LOD_DETALHE) ~= detalhe then
			mostrarDetalhe(distancia < LOD_DETALHE)
		end
		if not visivel then
			return true
		end
		if not detalhe then
			acumulado += dt
			if acumulado < 0.1 then
				return true
			end
			dt = math.min(acumulado, 1 / 10)
			acumulado = 0
		end

		-- saída: some rápido e limpa
		local opacidade = 1
		if saindo then
			saindo += dt
			opacidade = 1 - math.min(saindo / DURACAO_SAIDA, 1)
			if saindo >= DURACAO_SAIDA then
				destruir()
				return false
			end
		end

		-- base: só a direção para onde o corpo olha (sem inclinar junto)
		local cfRaiz = raiz.CFrame
		local olhar = cfRaiz.LookVector
		local base =
			CFrame.lookAt(cfRaiz.Position, cfRaiz.Position + Vector3.new(olhar.X, 0, olhar.Z))
		local velocidade = raiz.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocidade.X, 0, velocidade.Z)
		local rapidez = horizontal.Magnitude
		local corrida = math.clamp((rapidez - 16) / 10, 0, 1) -- acima da caminhada padrão

		-- pouso depois de uma queda: amassa o alto por um instante
		if velYAnterior < -18 and velocidade.Y > -2 then
			amasso = 0
		end
		velYAnterior = velocidade.Y
		local fatorAmasso = 0
		if amasso then
			amasso += dt
			fatorAmasso = math.sin(math.min(amasso / 0.35, 1) * math.pi)
			if amasso >= 0.35 then
				amasso = nil
			end
		end

		-- burst: de tempos em tempos o arco cresce, as pontas enrolam e tudo volta
		local fatorBurst = 0
		if not baixa and not reduzido and not manifestando then
			if burst then
				burst += dt
				fatorBurst = math.sin(math.min(burst / DURACAO_BURST, 1) * math.pi)
				if burst >= DURACAO_BURST then
					burst = nil
					proximoBurst = tempo + aleatorio:NextNumber(12, 20)
				end
			elseif tempo >= proximoBurst then
				burst = 0
			end
		end

		local transpBase = 1 - opacidade
		local mostrarContorno = detalhe and not baixa
		local amplitude = if reduzido then 0.4 else 1

		for _, p in pecas do
			local cfg = p.cfg
			-- manifestação: cada peça surge na sua vez, cresce e passa um pouco do tamanho
			local crescer = 1
			if manifestando then
				local inicio = cfg.ordem * 0.6
				local t = math.clamp((manifestando - inicio) / 0.55, 0, 1)
				crescer = if t <= 0 then 0 else easeOutBack(t)
			end

			-- mola: o pivô persegue o ponto preso ao corpo; pontas e bancos atrasam mais
			local alvo = (base * CFrame.new(p.pivo * escala)).Position
			local k = cfg.rigidez
			local amortecer = 2 * 0.55 * math.sqrt(k) -- um pouco abaixo do crítico: leve elástico
			local passos = if dt > 1 / 60 then 2 else 1
			local h = dt / passos
			for _ = 1, passos do
				local acel = (alvo - p.pos) * k - p.vel * amortecer
				p.vel += acel * h
				p.pos += p.vel * h
			end
			local maxAtraso = cfg.atraso * escala * (1 + 0.6 * corrida)
			local atraso = p.pos - alvo
			if atraso.Magnitude > maxAtraso * 4 then
				-- teleporte ou respawn: não deixa a nuvem voando pelo mapa
				p.pos = alvo
				p.vel = Vector3.zero
				atraso = Vector3.zero
			else
				atraso = limitar(atraso, maxAtraso)
				p.pos = alvo + atraso
			end
			local atrasoLocal = base:VectorToObjectSpace(atraso) / escala

			-- idle: sobe e desce fora de fase, balança em volta do pivô, respira
			local f = p.fase
			local sobe = (math.sin(tempo * 0.9 + f) * 0.12 + math.sin(tempo * 0.37 + f * 2) * 0.07)
				* escala
				* amplitude
			local g = math.rad(cfg.giro) * amplitude
			local rolar = g * 1.6 * fatorBurst * (if cfg.giro >= 12 then 1 else 0.3)
			local giro = CFrame.Angles(
				g * 0.5 * math.sin(tempo * 0.5 + f) + atrasoLocal.Z * 0.18,
				g * 0.3 * math.sin(tempo * 0.31 + f * 1.3),
				g * 0.6 * math.sin(tempo * 0.43 + f * 1.7) - atrasoLocal.X * 0.18 + rolar
			)
			local respira = cfg.respira * amplitude
			local esticar = math.min(atrasoLocal.Magnitude / math.max(cfg.atraso, 0.1), 1) * 0.22
			local inchar = 1 + 0.12 * fatorBurst * (if cfg.baixo then 1.25 else 1)
			local sx = (1 + respira * math.sin(tempo * 1.1 + f)) * inchar
			local sy = (1 + respira * math.sin(tempo * 0.95 + f + 1)) * inchar
			local sz = (1 + esticar) * inchar
			if not cfg.baixo then
				sy *= 1 - 0.1 * fatorAmasso
			end
			local fator = Vector3.new(sx, sy, sz) * crescer * escala

			local cfPivo = CFrame.new(p.pos + Vector3.new(0, sobe, 0)) * base.Rotation * giro
			local transp = if crescer <= 0.02 then 1 else transpBase
			if crescer > 0.02 then
				p.corpo.Size = p.tamCorpo * fator
				p.corpo.CFrame = cfPivo * CFrame.new(p.centroCorpo * fator)
			end
			p.corpo.Transparency = transp
			local contorno = p.contorno
			if contorno then
				if mostrarContorno and crescer > 0.02 then
					contorno.Size = p.tamContorno * fator
					contorno.CFrame = cfPivo * CFrame.new(p.centroContorno * fator)
					contorno.Transparency = transp
				else
					contorno.Transparency = 1
				end
			end
		end
		transpAtual = transpBase

		-- primeira pessoa: a nuvem do próprio jogador não tampa a tela
		if opcoes.local_ and cabeca then
			local perto = (camera - cabeca.Position).Magnitude < 1.5
			local modificador = if perto then 1 else 0
			for _, p in pecas do
				p.corpo.LocalTransparencyModifier = modificador
				if p.contorno then
					p.contorno.LocalTransparencyModifier = modificador
				end
			end
		end

		-- mechas: soltam no rastro (andando) e nos ombros (manifestação), evaporam em ~0,5 s
		if detalhe and not baixa and not saindo then
			proximaMecha -= dt
			if rapidez > 6 and proximaMecha <= 0 then
				proximaMecha = 0.45 - 0.2 * corrida
				local origem = pecas[aleatorio:NextInteger(#pecas - 3, #pecas)].pos -- pontas/rolos/bancos
				soltarMecha(origem, -horizontal.Unit * (1.5 + 2 * corrida) + Vector3.new(0, 0.6, 0))
			end
		end
		for _, m in mechas do
			if m.ativa then
				m.vida += dt
				local t = m.vida / 0.5
				if t >= 1 then
					m.ativa = false
					m.parte.Transparency = 1
				else
					local s = escala * (1 - 0.65 * t)
					m.parte.Size = tamMecha * s
					m.parte.CFrame = (m.parte.CFrame + m.deriva * dt)
						* CFrame.Angles(0, 0, dt * 2.5)
					m.parte.Transparency = math.max(t * t, transpAtual)
				end
			end
		end

		if manifestando then
			if manifestando == 0 and detalhe and not baixa then
				-- fiapos saem dos ombros antes do arco crescer
				local cima = base * CFrame.new(0, 1.1 * escala, 0.4 * escala)
				soltarMecha(
					(cima * CFrame.new(0.9 * escala, 0, 0)).Position,
					Vector3.new(0, 2.5, 0)
				)
				soltarMecha(
					(cima * CFrame.new(-0.9 * escala, 0, 0)).Position,
					Vector3.new(0, 2.5, 0)
				)
			end
			manifestando += dt
			if manifestando >= DURACAO_MANIFESTAR then
				manifestando = nil
			end
		end
		return true
	end

	-- primeiro quadro já posicionado (sem piscar no lugar errado)
	inst:atualizar(0, workspace.CurrentCamera.CFrame.Position)
	return inst :: Instancia
end

return Gear5
