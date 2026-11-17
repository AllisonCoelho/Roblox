-- Monarca das Sombras. VFX da aura equipada, montado só neste cliente; não anima o corpo.
--
-- Chamas escuras com a borda roxa brilhando (corpo Neon quase preto + casca invertida Neon roxa),
-- cortes em meia-lua girando na cintura e a coroa flutuando sobre a cabeça.
-- A SOMBRA do jogador é uma poça no chão com vários pares de olhos que piscam: o exército lá dentro.
--   * Andando: sombras menores (com olhos) perseguem o jogador pelo chão, em fila.
--   * Parado por ~5,5 s: os soldados das sombras SOBEM da sombra e montam guarda em volta dele,
--     virados para fora. Ao primeiro passo, afundam de volta.
local Workspace = game:GetService("Workspace")

local Gear5 = require(script.Parent.Gear5)
local MalhaNuvem = require(script.Parent.MalhaNuvem)
local Pecas = require(script.Parent.MonarcaPecas)

local Monarca = {}

local COR_SOMBRA = Color3.fromRGB(30, 10, 62) -- corpo das chamas (Neon escuro: roxo quase preto)
local COR_BORDA = Color3.fromHex("8B3DFF") -- borda brilhante
local COR_PONTA = Color3.fromRGB(120, 50, 235) -- roxo vivo das pontas das chamas
local COR_OLHOS = Color3.fromHex("C9A6FF")
local COR_POCA = Color3.fromRGB(8, 3, 16)
local BORDA_CHAMA = 0.06 -- espessura da borda roxa (studs)

local DURACAO_MANIFESTAR = 1.4
local DURACAO_BURST = 1.6
local DURACAO_SAIDA = 0.3
local LOD_DETALHE = 80
local LOD_OCULTO = 140

local ESPERA_SOLDADOS = 5.5 -- segundos parado até os soldados surgirem
local RAIO_GUARDA = 6.5
local SUBIDA = 0.9 -- segundos para um soldado emergir
local DESCIDA = 0.4
local N_PEQUENAS = 12 -- labaredas pequenas em volta do corpo
local N_OLHOS = 12
local N_RASTRO = 5

local PARTES_OSSO: { [string]: { string } } = {
	tronco = { "UpperTorso", "Torso" },
	cabeca = { "Head" },
}

type Chama = {
	cfg: { [string]: any },
	corpo: MeshPart,
	borda: MeshPart,
	pontas: MeshPart?, -- garras e ponta em gancho, em roxo vivo
	tamPontas: Vector3,
	centroPontas: Vector3,
	tamCorpo: Vector3,
	tamBorda: Vector3,
	centroCorpo: Vector3,
	centroBorda: Vector3,
	pivo: Vector3,
	osso: BasePart?,
	relOsso: Vector3,
	pos: Vector3,
	vel: Vector3,
	fase: number,
}
type Dupla = { parte: MeshPart, tam: Vector3, centro: Vector3 } -- malha solta + dados para escalar
type Olho = {
	d: Dupla,
	dx: number,
	dz: number,
	giro: number,
	escala: number,
	pisca: number,
	fechado: number,
}
type Soldado = {
	corpo: Dupla,
	borda: Dupla,
	olhos: Dupla,
	poca: Dupla,
	angulo: number,
	escala: number,
	altura: number, -- quanto precisa subir para sair inteiro da sombra
	flutua: number,
	balanco: number,
	atraso: number,
	nivel: number, -- 0 = dentro da sombra .. 1 = de pé
	cf: CFrame, -- onde está de guarda (pés)
}
type Rastro = { poca: Dupla, olhos: Dupla, pos: Vector3, visivel: number }

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local u = t - 1
	return 1 + (c1 + 1) * u * u * u + c1 * u * u
end

local function limitar(v: Vector3, maximo: number): Vector3
	local m = v.Magnitude
	if m > maximo and m > 1e-6 then
		return v * (maximo / m)
	end
	return v
end

function Monarca.criar(personagem: Model, opcoes: Gear5.Opcoes): Gear5.Instancia?
	local raiz = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cabeca = personagem:FindFirstChild("Head") :: BasePart?
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	if not raiz then
		return nil
	end
	local escala = 1
	if cabeca then
		escala = math.clamp((cabeca.Position - raiz.Position).Y / 1.5, 0.6, 2.5)
	end
	local alturaPe = raiz.Size.Y / 2
		+ (
			if humanoide and humanoide.RigType == Enum.HumanoidRigType.R15
				then humanoide.HipHeight
				else 2
		)

	local aleatorio = Random.new() -- só cosmético
	local pasta = Instance.new("Folder")
	pasta.Name = "AuraMonarca"
	local baixa = opcoes.qualidadeBaixa
	local reduzido = opcoes.movimentoReduzido

	local function neon(parte: MeshPart, cor: Color3)
		parte.Material = Enum.Material.Neon
		parte.Color = cor
		parte.Transparency = 1
		parte.Parent = pasta
	end
	local function dupla(nome: string, cor: Color3, contorno: boolean?, espessura: number?): Dupla
		local parte, centro = MalhaNuvem.criar(nome, contorno == true, espessura)
		neon(parte, cor)
		return { parte = parte, tam = parte.Size, centro = centro }
	end
	-- põe uma malha solta em cf (origem da malha), com escala s; alfa 0 = invisível
	local function por(d: Dupla, cf: CFrame, s: Vector3, transp: number)
		if transp >= 0.98 then
			d.parte.Transparency = 1
			return
		end
		d.parte.Size = d.tam * s
		d.parte.CFrame = cf * CFrame.new(d.centro * s)
		d.parte.Transparency = transp
	end

	-- chamas presas ao corpo
	local function acharOsso(nome: string): BasePart?
		local nomes = PARTES_OSSO[nome]
		if not nomes then
			return nil
		end
		for _, n in nomes do
			local parte = personagem:FindFirstChild(n)
			if parte and parte:IsA("BasePart") then
				return parte
			end
		end
		return nil
	end
	local chamas: { Chama } = {}
	local partesCorpo: { BasePart } = {}
	for _, cfg in Pecas.pecas :: { { [string]: any } } do
		local pivo = Vector3.new(cfg.pivo[1], cfg.pivo[2], cfg.pivo[3])
		local osso = acharOsso(cfg.osso)
		local co = Pecas.ossos[if osso then cfg.osso else "raiz"]
		-- o degradê (raiz escura -> ponta roxo vivo) vem pintado nos vértices e multiplica esta cor
		local corpo, centro = MalhaNuvem.criar("monarca_" .. cfg.nome, false)
		neon(corpo, COR_PONTA)
		local borda, centroB = MalhaNuvem.criar("monarca_" .. cfg.nome, true, BORDA_CHAMA)
		neon(borda, COR_BORDA)
		table.insert(partesCorpo, corpo)
		table.insert(partesCorpo, borda)
		local pontas: MeshPart? = nil
		local tamPontas, centroPontas = Vector3.one, Vector3.zero
		if cfg.pontas == 1 then
			local p, cp = MalhaNuvem.criar("monarca_" .. cfg.nome .. "_pontas", false)
			neon(p, COR_PONTA)
			pontas, tamPontas, centroPontas = p, p.Size, cp - pivo
			table.insert(partesCorpo, p)
		end
		table.insert(chamas, {
			cfg = cfg,
			corpo = corpo,
			borda = borda,
			pontas = pontas,
			tamPontas = tamPontas,
			centroPontas = centroPontas,
			tamCorpo = corpo.Size,
			tamBorda = borda.Size,
			centroCorpo = centro - pivo,
			centroBorda = centroB - pivo,
			pivo = pivo,
			osso = osso,
			relOsso = pivo - Vector3.new(co[1], co[2], co[3]),
			pos = (raiz.CFrame * CFrame.new(pivo * escala)).Position,
			vel = Vector3.zero,
			fase = aleatorio:NextNumber(0, math.pi * 2),
		})
	end

	-- coroa
	local coroa = dupla("monarca_coroa", COR_SOMBRA)
	local coroaBorda = dupla("monarca_coroa", COR_BORDA, true, 0.035)
	local gema = dupla("monarca_coroa_gema", COR_OLHOS)
	table.insert(partesCorpo, coroa.parte)
	table.insert(partesCorpo, coroaBorda.parte)
	table.insert(partesCorpo, gema.parte)

	-- a sombra do jogador: poça + olhos
	local poca = dupla("monarca_poca", COR_POCA)
	local pocaBorda = dupla("monarca_poca", COR_BORDA, true, 0.02)
	local olhos: { Olho } = {}
	for _ = 1, N_OLHOS do
		local a = aleatorio:NextNumber(0, math.pi * 2)
		local d = math.sqrt(aleatorio:NextNumber(0.03, 0.62))
		table.insert(olhos, {
			d = dupla("monarca_olhos_par", COR_OLHOS),
			dx = math.cos(a) * d,
			dz = math.sin(a) * d,
			giro = aleatorio:NextNumber(-0.6, 0.6),
			escala = aleatorio:NextNumber(0.75, 1.2),
			pisca = aleatorio:NextNumber(0.5, 5),
			fechado = 0,
		})
	end

	-- sombras que perseguem o jogador
	local rastros: { Rastro } = {}
	for _ = 1, N_RASTRO do
		table.insert(rastros, {
			poca = dupla("monarca_poca", COR_POCA),
			olhos = dupla("monarca_olhos_par", COR_OLHOS),
			pos = raiz.Position,
			visivel = 0,
		})
	end

	-- soldados das sombras
	local soldados: { Soldado } = {}
	-- quatro tipos, cada um com a própria malha: cavaleiro comandante, gigante de escudo, mago e
	-- rei-formiga. A ordem em volta do jogador é sorteada (só visual).
	local giroInicial = aleatorio:NextInteger(0, 3)
	for k, tipo in Pecas.soldados :: { { [string]: any } } do
		table.insert(soldados, {
			corpo = dupla(tipo.malha, COR_SOMBRA),
			borda = dupla(tipo.malha, COR_BORDA, true, 0.05),
			olhos = dupla(tipo.olhos, COR_OLHOS),
			poca = dupla("monarca_poca", COR_POCA),
			angulo = math.rad(45 + 90 * (k - 1 + giroInicial)) + aleatorio:NextNumber(-0.2, 0.2),
			escala = tipo.escala,
			altura = tipo.altura,
			flutua = tipo.flutua,
			balanco = tipo.balanco,
			atraso = (k - 1) * 0.22,
			nivel = 0,
			cf = CFrame.identity,
		})
	end

	-- labaredas pequenas: nascem em volta do corpo (também na frente, abaixo dos ombros), sobem,
	-- afinam e somem, cada uma no seu ciclo — é o que faz a aura parecer fogo, não escultura
	type Pequena = {
		d: Dupla,
		angulo: number,
		raio: number,
		y: number,
		fase: number,
		ritmo: number,
		giro: number,
	}
	local pequenas: { Pequena } = {}
	for i = 1, N_PEQUENAS do
		local d = dupla("monarca_chama_pequena", COR_PONTA)
		table.insert(partesCorpo, d.parte)
		table.insert(pequenas, {
			d = d,
			angulo = (i / N_PEQUENAS) * math.pi * 2 + aleatorio:NextNumber(-0.25, 0.25),
			raio = aleatorio:NextNumber(1.2, 2.1),
			y = aleatorio:NextNumber(-2.8, 0.2),
			fase = aleatorio:NextNumber(0, 1),
			ritmo = aleatorio:NextNumber(0.7, 1.2),
			giro = aleatorio:NextNumber(0, math.pi * 2),
		})
	end

	-- lascas de sombra que se soltam das chamas
	local mechas: { { d: Dupla, vida: number, cf: CFrame, deriva: Vector3 } } = {}
	for _ = 1, 6 do
		table.insert(mechas, {
			d = dupla("monarca_mecha", COR_BORDA),
			vida = 1,
			cf = CFrame.identity,
			deriva = Vector3.zero,
		})
	end

	local anexoLuz = Instance.new("Attachment")
	anexoLuz.Name = "AuraMonarcaLuz"
	anexoLuz.Position = Vector3.new(0, 0.5, 1.2) * escala
	local luz = Instance.new("PointLight")
	luz.Color = COR_BORDA
	luz.Range = 14 * escala
	luz.Brightness = 1.6
	luz.Shadows = false
	luz.Parent = anexoLuz
	anexoLuz.Parent = raiz
	pasta.Parent = Workspace

	local filtro = RaycastParams.new()
	filtro.FilterType = Enum.RaycastFilterType.Exclude
	filtro.FilterDescendantsInstances = { personagem, pasta }

	-- estado
	local tempo = aleatorio:NextNumber(0, 100)
	local manifestando: number? = if opcoes.manifestar then 0 else nil
	local proximoBurst = aleatorio:NextNumber(12, 20)
	local burst: number? = nil
	local saindo: number? = nil
	local mov = 0
	local parado = 0 -- segundos parado no chão
	local guarda = false -- soldados convocados
	local tempoGuarda = 0
	local chaoY = raiz.Position.Y - alturaPe
	local proximaMecha = 0
	local acumulado = 0
	local detalhe = true
	local visivel = true
	local destruida = false

	local inst = {} :: any

	local function destruir()
		destruida = true
		pasta:Destroy()
		anexoLuz:Destroy()
	end

	function inst.definirQualidade(_self, novaBaixa: boolean, novoReduzido: boolean)
		baixa = novaBaixa
		reduzido = novoReduzido
	end

	function inst.manifestar(_self)
		manifestando = 0
	end

	function inst.encerrar(_self, imediato: boolean?)
		if imediato then
			destruir()
		elseif saindo == nil then
			saindo = 0
		end
	end

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

		local distancia = (camera - raiz.Position).Magnitude
		local deveVer = distancia < LOD_OCULTO
		if deveVer ~= visivel then
			visivel = deveVer
			pasta.Parent = if deveVer then Workspace else nil
		end
		detalhe = distancia < LOD_DETALHE
		luz.Enabled = detalhe and not baixa
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

		local opacidade = 1
		if saindo then
			saindo += dt
			opacidade = 1 - math.min(saindo / DURACAO_SAIDA, 1)
			if saindo >= DURACAO_SAIDA then
				destruir()
				return false
			end
		end
		local some = 1 - opacidade -- transparência base

		local cfRaiz = raiz.CFrame
		local olhar = cfRaiz.LookVector
		local base =
			CFrame.lookAt(cfRaiz.Position, cfRaiz.Position + Vector3.new(olhar.X, 0, olhar.Z))
		local velocidade = raiz.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocidade.X, 0, velocidade.Z)
		local rapidez = horizontal.Magnitude
		mov += (math.clamp(rapidez / 16, 0, 1) - mov) * math.min(dt * 5, 1)

		-- chão embaixo do jogador (a sombra fica no chão mesmo durante o pulo)
		local toque = Workspace:Raycast(cfRaiz.Position, Vector3.new(0, -40, 0), filtro)
		local noChao = false
		if toque then
			chaoY = toque.Position.Y
			noChao = cfRaiz.Position.Y - chaoY < alturaPe + 0.6
		end
		local chao = Vector3.new(cfRaiz.Position.X, chaoY + 0.04, cfRaiz.Position.Z)

		-- explosão de poder
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
		local surgir = if manifestando then math.clamp(manifestando / 0.5, 0, 1) else 1

		-- ---------------------------------------------------------------- chamas
		local amplitude = if reduzido then 0.4 else 1
		local comBorda = not (baixa and not detalhe)
		for _, c in chamas do
			local cfg = c.cfg
			local crescer = 1
			if manifestando then
				local t = math.clamp((manifestando - cfg.ordem * 0.7) / 0.5, 0, 1)
				crescer = if t <= 0 then 0 else easeOutBack(t)
			end
			local osso = c.osso
			local cfOsso = if osso and osso.Parent then osso.CFrame else base
			local rel = if osso and osso.Parent then c.relOsso else c.pivo
			-- cortes: giram devagar em volta do corpo
			local volta = CFrame.Angles(0, cfg.volta * tempo, 0)
			local alvo = (cfOsso * volta * CFrame.new(rel * escala)).Position
			local k = cfg.rigidez
			local amortecer = 2 * 0.6 * math.sqrt(k)
			local passos = if dt > 1 / 60 then 2 else 1
			local h = dt / passos
			for _ = 1, passos do
				c.vel += ((alvo - c.pos) * k - c.vel * amortecer) * h
				c.pos += c.vel * h
			end
			local maxAtraso = cfg.atraso * escala
			local atraso = c.pos - alvo
			if atraso.Magnitude > maxAtraso * 4 then
				c.pos, c.vel, atraso = alvo, Vector3.zero, Vector3.zero
			else
				atraso = limitar(atraso, maxAtraso)
				c.pos = alvo + atraso
			end
			local atrasoLocal = cfOsso:VectorToObjectSpace(atraso) / escala
			local f = c.fase
			-- fogo: treme rápido na altura, balança devagar, inclina para trás ao andar
			local tremor = cfg.tremor * amplitude
			local sy = 1
				+ tremor * (math.sin(tempo * 7 + f) * 0.6 + math.sin(tempo * 11.3 + f * 2) * 0.4)
				+ 0.18 * fatorBurst
			local sx = 1 - tremor * 0.5 * math.sin(tempo * 7 + f) + 0.08 * fatorBurst
			local g = math.rad(cfg.giro) * amplitude
			local giro = CFrame.Angles(
				g * 0.5 * math.sin(tempo * 1.3 + f) + atrasoLocal.Z * 0.25,
				0,
				g * math.sin(tempo * 0.9 + f * 1.7) - atrasoLocal.X * 0.25
			)
			local fator = Vector3.new(sx, sy, sx) * crescer * escala
			local cf = CFrame.new(c.pos) * (cfOsso * volta).Rotation * giro
			if crescer > 0.02 then
				c.corpo.Size = c.tamCorpo * fator
				c.corpo.CFrame = cf * CFrame.new(c.centroCorpo * fator)
				c.corpo.Transparency = some + (1 - some) * 0.08
				if comBorda then
					c.borda.Size = c.tamBorda * fator
					c.borda.CFrame = cf * CFrame.new(c.centroBorda * fator)
					c.borda.Transparency = some + (1 - some) * (0.15 - 0.15 * fatorBurst)
				else
					c.borda.Transparency = 1
				end
			else
				c.corpo.Transparency = 1
				c.borda.Transparency = 1
			end
			local pontas = c.pontas
			if pontas then
				if crescer > 0.02 then
					pontas.Size = c.tamPontas * fator
					pontas.CFrame = cf * CFrame.new(c.centroPontas * fator)
					-- pulsam de leve: a brasa roxa "respira"
					pontas.Transparency = some
						+ (1 - some)
							* (0.12 + 0.1 * math.sin(tempo * 3 + f) - 0.12 * fatorBurst)
				else
					pontas.Transparency = 1
				end
			end
		end

		-- labaredas pequenas: ciclo de nascer, subir e sumir
		local nPequenas = if baixa then 4 elseif detalhe then N_PEQUENAS else 6
		for i, q in pequenas do
			if i > nPequenas or surgir < 1 then
				q.d.parte.Transparency = 1
				continue
			end
			local ciclo = (tempo * 0.9 * q.ritmo + q.fase) % 1
			local tam = math.sin(ciclo * math.pi) ^ 0.6 -- cresce e encolhe
			local a = q.angulo + 0.3 * math.sin(tempo * 0.4 + q.fase * 6)
			local lugar = base
				* CFrame.new(
					math.sin(a) * q.raio * escala,
					(q.y + ciclo * 1.6) * escala,
					math.cos(a) * q.raio * 0.85 * escala - mov * 0.5 * escala
				)
			local s = escala * (0.7 + 0.5 * q.ritmo) * (1 + 0.3 * fatorBurst)
			por(
				q.d,
				lugar * CFrame.Angles(0, q.giro, 0),
				Vector3.new(s * tam, s * (0.6 + 0.8 * ciclo), s * tam),
				some + (1 - some) * (0.1 + 0.75 * ciclo * ciclo)
			)
		end

		-- ---------------------------------------------------------------- coroa
		do
			local cfCabeca = if cabeca and cabeca.Parent
				then cabeca.CFrame
				else base * CFrame.new(0, 1.5 * escala, 0)
			local altura = (if cabeca then cabeca.Size.Y / 2 else 0.6)
				+ (0.75 + 0.08 * math.sin(tempo * 1.6)) * escala
			-- desce sobre a cabeça na manifestação
			local queda = if manifestando
				then (1 - math.clamp((manifestando - 0.5) / 0.6, 0, 1)) ^ 2 * 3 * escala
				else 0
			local cf = CFrame.new((cfCabeca * CFrame.new(0, altura + queda, 0)).Position)
				* base.Rotation
				* CFrame.Angles(0, 0.25 * math.sin(tempo * 0.5), 0)
			local s = Vector3.one * escala * (1 + 0.1 * fatorBurst)
			local t = if manifestando and manifestando < 0.5 then 1 else some
			por(coroa, cf, s, t)
			por(coroaBorda, cf, s, t)
			por(gema, cf, s, t)
		end

		-- ---------------------------------------------------------------- a sombra e os olhos
		local altura = math.max(cfRaiz.Position.Y - chaoY - alturaPe, 0)
		local raioPoca = 3.4 * escala * surgir * (1 + 0.12 * fatorBurst) / (1 + altura * 0.06)
		local cfPoca = CFrame.new(chao) * CFrame.Angles(0, tempo * 0.15, 0)
		local sPoca = Vector3.new(raioPoca, escala, raioPoca)
		por(poca, cfPoca, sPoca, some + (1 - some) * 0.05)
		por(pocaBorda, cfPoca, sPoca, if baixa then 1 else some + (1 - some) * 0.35)
		for _, o in olhos do
			-- piscam cada um na sua hora; na explosão de poder todos abrem
			o.pisca -= dt
			if o.pisca <= 0 then
				o.pisca = aleatorio:NextNumber(1.5, 6)
				o.fechado = 0.22
			end
			o.fechado = math.max(o.fechado - dt, 0)
			local aberto = if fatorBurst > 0.1
				then 1
				else 1 - math.sin(math.clamp(o.fechado / 0.22, 0, 1) * math.pi)
			local cf = CFrame.new(chao + Vector3.new(o.dx * raioPoca, 0.07, o.dz * raioPoca))
				* base.Rotation
				* CFrame.Angles(0, math.pi + o.giro, 0)
			local s = o.escala * escala * (1 + 0.25 * fatorBurst)
			por(
				o.d,
				cf,
				Vector3.new(s, s, s * math.max(aberto, 0.05)),
				if surgir < 1 then 1 else some
			)
		end

		-- ---------------------------------------------------------------- sombras seguindo
		local lider = chao
		local direcao = if rapidez > 0.5 then horizontal.Unit else base.LookVector
		for i, r in rastros do
			local alvoVis = if rapidez > 2 and not baixa and not saindo then 1 else 0
			r.visivel += (alvoVis - r.visivel) * math.min(dt * 4, 1)
			-- persegue o da frente, mantendo distância; os de trás são mais lentos
			local para = lider - r.pos
			para = Vector3.new(para.X, 0, para.Z)
			local folga = (1.9 + 0.5 * i) * escala
			if para.Magnitude > folga * 6 then
				r.pos = lider - direcao * folga
			elseif para.Magnitude > folga then
				r.pos += para.Unit * (para.Magnitude - folga) * math.min(dt * (9 - i), 1)
			elseif alvoVis == 0 then
				r.pos += para * math.min(dt * 3, 1) -- parado: voltam para dentro da sombra do jogador
			end
			r.pos = Vector3.new(r.pos.X, chaoY + 0.03, r.pos.Z)
			local s = (1.25 - 0.13 * i) * escala * r.visivel
			local ondula = 1 + 0.1 * math.sin(tempo * 6 + i)
			local t = if r.visivel < 0.05 then 1 else some + (1 - some) * 0.05
			local frente = if para.Magnitude > 0.05 then para.Unit else direcao
			local cf = CFrame.lookAt(r.pos, r.pos + frente)
			por(r.poca, cf, Vector3.new(s * ondula, escala, s * 1.5 / ondula), t)
			por(
				r.olhos,
				cf * CFrame.new(0, 0.07, -0.3 * s) * CFrame.Angles(0, math.pi, 0),
				Vector3.one * 0.8 * s,
				t
			)
			lider = r.pos
		end

		-- ---------------------------------------------------------------- soldados
		if rapidez < 0.6 and noChao and not saindo then
			parado += dt
		else
			parado = 0
		end
		if parado >= ESPERA_SOLDADOS and not guarda then
			guarda = true
			tempoGuarda = 0
			for _, s in soldados do
				local p = chao
					+ Vector3.new(math.sin(s.angulo), 0, math.cos(s.angulo))
						* RAIO_GUARDA
						* escala
				-- cada soldado acha o próprio chão (escadas, desníveis)
				local t2 =
					Workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), filtro)
				if t2 then
					p = t2.Position
				end
				s.cf = CFrame.lookAt(p, p + Vector3.new(p.X - chao.X, 0, p.Z - chao.Z)) -- de costas para o monarca
			end
		elseif guarda and parado == 0 then
			guarda = false
		end
		tempoGuarda += dt
		local nSoldados = if baixa then 2 else #soldados
		for k, s in soldados do
			local alvo = if guarda and k <= nSoldados and tempoGuarda >= s.atraso then 1 else 0
			local passo = dt / (if alvo == 1 then SUBIDA else DESCIDA)
			s.nivel = math.clamp(s.nivel + (if alvo == 1 then passo else -passo), 0, 1)
			if s.nivel <= 0 then
				s.corpo.parte.Transparency = 1
				s.borda.parte.Transparency = 1
				s.olhos.parte.Transparency = 1
				s.poca.parte.Transparency = 1
				continue
			end
			local n = s.nivel
			local e = s.escala * escala
			-- a poça abre primeiro; o soldado sobe de dentro dela
			local sub = 1 - (1 - math.clamp((n - 0.15) / 0.85, 0, 1)) ^ 3
			local respira = 1 + 0.015 * math.sin(tempo * 1.8 + k)
			-- cada tipo fica de guarda do seu jeito: o mago flutua, a formiga se remexe
			local cf = s.cf
				* CFrame.new(
					0,
					-(1 - sub) * s.altura * e
						+ s.flutua * e * sub * (1 + 0.4 * math.sin(tempo * 1.4 + k)),
					0
				)
				* CFrame.Angles(
					math.rad(s.balanco) * 0.5 * math.sin(tempo * 2.3 + k),
					math.rad(s.balanco) * 2 * math.sin(tempo * 0.9 + k * 2),
					math.rad(s.balanco) * math.sin(tempo * 1.7 + k)
				)
			local sv = Vector3.new(e, e * respira, e)
			local t = some
			por(s.corpo, cf, sv, t + (1 - t) * 0.06)
			por(s.borda, cf, sv, t + (1 - t) * 0.2)
			por(s.olhos, cf, sv, if sub > 0.6 then t else 1)
			local rp = 2.4 * e * math.min(n / 0.25, 1)
			por(s.poca, s.cf * CFrame.new(0, 0.04, 0), Vector3.new(rp, e, rp), t + (1 - t) * 0.05)
		end

		-- ---------------------------------------------------------------- lascas de sombra
		if detalhe and not baixa and not saindo then
			proximaMecha -= dt
			if proximaMecha <= 0 then
				proximaMecha = aleatorio:NextNumber(0.25, 0.6)
				for _, m in mechas do
					if m.vida >= 1 then
						local c = chamas[aleatorio:NextInteger(1, #chamas)]
						m.vida = 0
						m.cf = CFrame.new(
							c.pos
								+ Vector3.new(
										aleatorio:NextNumber(-1, 1),
										aleatorio:NextNumber(1, 3),
										aleatorio:NextNumber(-1, 1)
									)
									* escala
						) * CFrame.Angles(0, aleatorio:NextNumber(0, 6.28), 0)
						m.deriva = Vector3.new(0, 2.2, 0) - horizontal * 0.2
						break
					end
				end
			end
		end
		for _, m in mechas do
			if m.vida < 1 then
				m.vida += dt / 0.7
				m.cf += m.deriva * dt
				local s = escala * (1 - 0.6 * m.vida)
				por(m.d, m.cf, Vector3.one * s, math.max(m.vida, some))
			else
				m.d.parte.Transparency = 1
			end
		end

		-- primeira pessoa: as chamas do próprio jogador não tampam a tela
		if opcoes.local_ and cabeca then
			local modificador = if (camera - cabeca.Position).Magnitude < 1.5 then 1 else 0
			for _, parte in partesCorpo do
				parte.LocalTransparencyModifier = modificador
			end
		end

		if manifestando then
			manifestando += dt
			if manifestando >= DURACAO_MANIFESTAR then
				manifestando = nil
			end
		end
		return true
	end

	local cam = Workspace.CurrentCamera
	inst:atualizar(0, if cam then cam.CFrame.Position else raiz.Position)
	return inst :: Gear5.Instancia
end

return Monarca
