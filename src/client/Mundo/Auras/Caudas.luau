-- Família Naruto (2 a 9 caudas + Modo Sábio dos Seis Caminhos). VFX da aura equipada, montado
-- só neste cliente; não anima o corpo.
--
-- As caudas são chakra vivo, não esculturas: cada cauda é uma corrente de 4 segmentos (malhas do
-- Blender em Dados/naruto_cauda_*) que é dobrada JUNTA A JUNTA todo quadro. Ondas correm da base
-- para a ponta, cada cauda na sua fase e frequência; ao andar elas fecham o leque e são puxadas
-- para trás; ao pular, sobem ou descem; na explosão de poder abrem, esticam e brilham mais.
-- Cada segmento tem duas camadas Neon: casca (vermelha, translúcida) e núcleo (laranja).
-- Os parâmetros de cada estágio estão em CaudasEstagios.luau (gerado junto com as malhas).
local Gear5 = require(script.Parent.Gear5)
local Dados = require(script.Parent.CaudasEstagios)
local MalhaNuvem = require(script.Parent.MalhaNuvem)

local Caudas = {}

type Estagio = { [string]: any }

local DURACAO_MANIFESTAR = 1.5
local DURACAO_BURST = 1.6
local DURACAO_SAIDA = 0.25
local LOD_DETALHE = 80
local LOD_OCULTO = 140
local COR_OLHOS = Color3.fromHex("FFE14A")

type Segmento = {
	fora: MeshPart,
	dentro: MeshPart,
	tamanho: Vector3, -- tamanho original da malha
	centro: Vector3, -- da junta até o centro da malha
	comprimento: number,
}

type Cauda = { segmentos: { Segmento }, fase: number, ritmo: number }

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local u = t - 1
	return 1 + (c1 + 1) * u * u * u + c1 * u * u
end

local function neon(parte: MeshPart, cor: Color3, pasta: Instance)
	parte.Material = Enum.Material.Neon
	parte.Color = cor
	parte.Transparency = 1
	parte.Parent = pasta
end

local function criar(personagem: Model, opcoes: Gear5.Opcoes, est: Estagio): Gear5.Instancia?
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
	-- do centro da raiz até o chão (R15 usa HipHeight; R6 tem pernas de 2 studs)
	local alturaPe = raiz.Size.Y / 2
		+ (
			if humanoide and humanoide.RigType == Enum.HumanoidRigType.R15
				then humanoide.HipHeight
				else 2
		)

	local aleatorio = Random.new()
	local pasta = Instance.new("Folder")
	pasta.Name = "AuraCaudas"
	local corFora = Color3.fromHex(est.fora)
	local corDentro = Color3.fromHex(est.dentro)
	local baixa = opcoes.qualidadeBaixa
	local reduzido = opcoes.movimentoReduzido

	local caudas: { Cauda } = {}
	for i = 1, est.caudas do
		local segmentos: { Segmento } = {}
		for _, seg in Dados.segmentos :: { { [string]: any } } do
			local fora, centro = MalhaNuvem.criar(seg.malha, false)
			neon(fora, corFora, pasta)
			local dentro = MalhaNuvem.criar(seg.malha, false)
			neon(dentro, corDentro, pasta)
			table.insert(segmentos, {
				fora = fora,
				dentro = dentro,
				tamanho = fora.Size,
				centro = centro,
				comprimento = seg.comprimento,
			})
		end
		table.insert(caudas, {
			segmentos = segmentos,
			fase = aleatorio:NextNumber(0, math.pi * 2) + i * 1.7,
			ritmo = aleatorio:NextNumber(0.8, 1.25), -- cada cauda no seu ritmo
		})
	end

	-- Cabeça espectral da raposa (9 caudas)
	local raposa: MeshPart? = nil
	local olhos: MeshPart? = nil
	local centroRaposa, centroOlhos = Vector3.zero, Vector3.zero
	if est.raposa then
		local r, cr = MalhaNuvem.criar("naruto_raposa", false)
		neon(r, corFora, pasta)
		local o, co = MalhaNuvem.criar("naruto_olhos", false)
		neon(o, COR_OLHOS, pasta)
		raposa, olhos = r, o
		centroRaposa, centroOlhos = cr, co
	end
	local tamRaposa = if raposa then raposa.Size else Vector3.one
	local tamOlhos = if olhos then olhos.Size else Vector3.one

	-- Anel no chão (9 caudas e Seis Caminhos) e, nos Seis Caminhos, halo + esferas negras
	local chao: MeshPart? = nil
	local halo: MeshPart? = nil
	local esferas: { Part } = {}
	if est.raposa or est.seis then
		local a = MalhaNuvem.criar("naruto_anel", false)
		neon(a, corFora, pasta)
		chao = a
	end
	local destaque: Highlight? = nil
	if est.seis then
		local h = MalhaNuvem.criar("naruto_anel", false)
		neon(h, corFora, pasta)
		halo = h
		for _ = 1, 9 do
			local e = Instance.new("Part")
			e.Shape = Enum.PartType.Ball
			e.Material = Enum.Material.SmoothPlastic
			e.Color = Color3.fromRGB(8, 8, 10)
			e.Reflectance = 0.15
			e.Anchored = true
			e.CanCollide = false
			e.CanQuery = false
			e.CanTouch = false
			e.CastShadow = false
			e.Size = Vector3.one * 0.96 * escala
			e.Transparency = 1
			e.Parent = pasta
			table.insert(esferas, e)
		end
		-- manto dourado: contorno e brilho no próprio personagem (só neste cliente)
		local d = Instance.new("Highlight")
		d.Name = "AuraCaudasManto"
		d.FillColor = corFora
		d.FillTransparency = 1
		d.OutlineColor = corDentro
		d.OutlineTransparency = 1
		d.DepthMode = Enum.HighlightDepthMode.Occluded
		d.Parent = personagem
		destaque = d
	end
	local tamAnel = if chao then chao.Size elseif halo then halo.Size else Vector3.one

	-- Faíscas de chakra (poucas; nunca a estrutura)
	local anexo = Instance.new("Attachment")
	anexo.Name = "AuraCaudasFaiscas"
	anexo.Position = Vector3.new(0, 0.5, 1.2) * escala
	local faiscas = Instance.new("ParticleEmitter")
	faiscas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	faiscas.Color = ColorSequence.new(corDentro, corFora)
	faiscas.LightEmission = 1
	faiscas.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3 * escala),
		NumberSequenceKeypoint.new(1, 0),
	})
	faiscas.Lifetime = NumberRange.new(0.6, 1.1)
	faiscas.Rate = 3 + est.caudas
	faiscas.Speed = NumberRange.new(2, 5)
	faiscas.SpreadAngle = Vector2.new(70, 70)
	faiscas.EmissionDirection = Enum.NormalId.Top
	faiscas.Acceleration = Vector3.new(0, 4, 0)
	faiscas.Drag = 2
	faiscas.Parent = anexo
	anexo.Parent = raiz
	pasta.Parent = workspace
	local partes: { BasePart } = {}
	for _, parte in pasta:GetChildren() do
		if parte:IsA("BasePart") then
			table.insert(partes, parte)
		end
	end

	-- estado
	local tempo = aleatorio:NextNumber(0, 100)
	local manifestando: number? = if opcoes.manifestar then 0 else nil
	local proximoBurst = aleatorio:NextNumber(8, 14)
	local burst: number? = nil
	local proximaContracao = aleatorio:NextNumber(3, 6)
	local contracao: number? = nil
	local saindo: number? = nil
	local mov = 0 -- 0 parado .. 1 correndo (suavizado)
	local pulo = 0 -- inclinação extra por velocidade vertical (suavizada)
	local intensidadeRaposa = 0
	local acumulado = 0
	local detalhe = true
	local visivel = true
	local destruida = false

	local inst = {} :: any

	local function destruir()
		destruida = true
		pasta:Destroy()
		anexo:Destroy()
		if destaque then
			destaque:Destroy()
		end
	end

	local function mostrarDetalhe(ligado: boolean)
		detalhe = ligado
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

		local opacidade = 1
		if saindo then
			saindo += dt
			opacidade = 1 - math.min(saindo / DURACAO_SAIDA, 1)
			if saindo >= DURACAO_SAIDA then
				destruir()
				return false
			end
		end

		local cfRaiz = raiz.CFrame
		local olhar = cfRaiz.LookVector
		local base =
			CFrame.lookAt(cfRaiz.Position, cfRaiz.Position + Vector3.new(olhar.X, 0, olhar.Z))
		local velocidade = raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(velocidade.X, 0, velocidade.Z).Magnitude
		mov += (math.clamp(rapidez / 24, 0, 1) - mov) * math.min(dt * 4, 1)
		pulo += (math.clamp(-velocidade.Y * 0.012, -0.35, 0.35) - pulo) * math.min(dt * 6, 1)

		-- explosão de poder: o leque abre, as caudas esticam e brilham; na de 9, a raposa aparece
		local fatorBurst = 0
		if not baixa and not reduzido and not manifestando then
			if burst then
				burst += dt
				fatorBurst = math.sin(math.min(burst / DURACAO_BURST, 1) * math.pi)
				if burst >= DURACAO_BURST then
					burst = nil
					proximoBurst = tempo + aleatorio:NextNumber(9, 15)
				end
			elseif tempo >= proximoBurst then
				burst = 0
				if detalhe then
					faiscas:Emit(25)
				end
			end
		end
		-- 5 caudas: de vez em quando tudo se contrai por um instante
		local fatorContracao = 0
		if est.contracao and not reduzido then
			if contracao then
				contracao += dt
				fatorContracao = math.sin(math.min(contracao / 0.7, 1) * math.pi)
				if contracao >= 0.7 then
					contracao = nil
					proximaContracao = tempo + aleatorio:NextNumber(3, 6)
				end
			elseif tempo >= proximaContracao then
				contracao = 0
			end
		end

		local amplitude = (if reduzido then 0.4 else 1) * est.onda
		local raizCaudas = base
			* CFrame.new(Vector3.new(Dados.raiz[1], Dados.raiz[2], Dados.raiz[3]) * escala)
		local transpBase = 1 - opacidade
		local transpFora = transpBase + (1 - transpBase) * est.transpFora * (1 - 0.4 * fatorBurst)
		local mostrarNucleo = detalhe and not baixa
		local n = est.caudas
		local esticar = est.comprimento * (1 + 0.12 * fatorBurst) * (1 - 0.15 * fatorContracao)

		for i, cauda in caudas do
			local u = if n > 1 then (i - 1) / (n - 1) * 2 - 1 else 0
			local fase = cauda.fase + (if est.alterna and i % 2 == 0 then math.pi else 0)
			local w = est.freq * cauda.ritmo
			local phi = math.rad(est.abertura) * u * (1 - 0.45 * mov) * (1 + 0.22 * fatorBurst)
			local elev = math.rad(est.elevacao + (est.elevLados - est.elevacao) * math.abs(u))
					* (1 - 0.55 * mov)
				+ pulo
			local cf = raizCaudas
				* CFrame.Angles(0, phi, 0)
				* CFrame.Angles(math.pi / 2 - elev, 0, 0)
			local pulso = if est.pulso then 1 + 0.1 * math.sin(tempo * 5 + i) ^ 8 else 1

			for k, seg in cauda.segmentos do
				-- manifestação: as caudas crescem da base para a ponta, uma depois da outra
				local crescer = 1
				if manifestando then
					local inicio = (i - 1) * (0.5 / n) + (k - 1) * 0.12
					local t = math.clamp((manifestando - inicio) / 0.3, 0, 1)
					crescer = if t <= 0 then 0 else easeOutBack(t)
				end
				local onda = amplitude
					* (1 + 0.8 * mov)
					* math.sin(w * tempo - (k - 1) * 0.9 + fase)
				local lado = amplitude
						* 0.6
						* math.sin(w * 0.7 * tempo - (k - 1) * 0.7 + fase * 1.3)
					- u * math.rad(12)
				local dobra = math.rad(est.curva) * (1 - 0.6 * mov) * (1 - 0.5 * fatorBurst)
					+ onda
					+ math.rad(14) * fatorContracao
				if k > 1 then
					cf = cf * CFrame.Angles(-dobra, 0, lado)
				end
				local g = est.grossura * escala * pulso * crescer
				local c = esticar * escala * crescer
				local escalaFora = Vector3.new(g, c, g)
				local visivelSeg = crescer > 0.02
				if visivelSeg then
					seg.fora.Size = seg.tamanho * escalaFora
					seg.fora.CFrame = cf * CFrame.new(seg.centro * escalaFora)
				end
				seg.fora.Transparency = if visivelSeg then transpFora else 1
				if mostrarNucleo and visivelSeg then
					local escalaDentro = Vector3.new(g * 0.5, c * 0.96, g * 0.5)
					seg.dentro.Size = seg.tamanho * escalaDentro
					seg.dentro.CFrame = cf * CFrame.new(seg.centro * escalaDentro)
					seg.dentro.Transparency = transpBase
						+ (1 - transpBase) * (0.35 - 0.25 * fatorBurst)
				else
					seg.dentro.Transparency = 1
				end
				cf = cf
					* CFrame.new(0, seg.comprimento * esticar * escala * Dados.avanco * crescer, 0)
			end
		end

		-- raposa espectral: surge na manifestação e nas explosões de poder
		if raposa and olhos then
			local alvo = if (manifestando or fatorBurst > 0.05) and not baixa then 1 else 0
			intensidadeRaposa += (alvo - intensidadeRaposa) * math.min(dt * 3, 1)
			local s = 3 * escala * (0.92 + 0.08 * intensidadeRaposa)
			local cfR = base
				* CFrame.new(0, (3.4 + 0.1 * math.sin(tempo * 1.3)) * escala, 2.6 * escala)
			-- olhos e cabeça usam o mesmo pivô; o centro de cada malha vem do Blender
			raposa.Size = tamRaposa * s
			raposa.CFrame = cfR * CFrame.new(centroRaposa * s)
			olhos.Size = tamOlhos * s
			olhos.CFrame = cfR * CFrame.new(centroOlhos * s)
			raposa.Transparency = 1 - (1 - transpBase) * intensidadeRaposa * 0.55
			olhos.Transparency = 1 - (1 - transpBase) * intensidadeRaposa
		end

		if chao then
			local s = 3.2 * escala * (1 + 0.06 * math.sin(tempo * 2))
			chao.Size = tamAnel * s
			chao.CFrame = base * CFrame.new(0, -alturaPe + 0.05, 0)
			chao.Transparency = transpBase + (1 - transpBase) * 0.2
		end
		if halo then
			local centro = base * CFrame.new(0, 2.6 * escala, 1.6 * escala)
			halo.Size = tamAnel * 3.6 * escala
			halo.CFrame = centro * CFrame.Angles(math.pi / 2, 0, 0)
			halo.Transparency = transpBase + (1 - transpBase) * 0.45
			for k, esfera in esferas do
				local a = tempo * 0.35 + (k - 1) * math.pi * 2 / 9
				local surgir = 1
				if manifestando then
					surgir = math.clamp((manifestando - 0.4 - k * 0.08) / 0.2, 0, 1)
				end
				esfera.CFrame = centro
					* CFrame.new(
						math.cos(a) * 3.6 * escala,
						math.sin(a) * 3.6 * escala + 0.08 * math.sin(tempo * 2 + k),
						0
					)
				esfera.Transparency = if surgir <= 0 then 1 else transpBase
				esfera.Size = Vector3.one * 0.96 * escala * math.max(surgir, 0.01)
			end
			if destaque then
				destaque.FillTransparency = 0.55 + 0.45 * transpBase
				destaque.OutlineTransparency = 0.1 + 0.9 * transpBase
			end
		end

		-- primeira pessoa: as caudas do próprio jogador não tampam a tela
		if opcoes.local_ and cabeca then
			local modificador = if (camera - cabeca.Position).Magnitude < 1.5 then 1 else 0
			for _, parte in partes do
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

	inst:atualizar(0, workspace.CurrentCamera.CFrame.Position)
	return inst :: Gear5.Instancia
end

-- Um "módulo de aura" por estágio, no mesmo formato da Gear 5 (criar(personagem, opcoes))
function Caudas.estagio(id: string)
	local est = Dados.estagios[id]
	assert(est, "estágio desconhecido: " .. id)
	return {
		criar = function(personagem: Model, opcoes: Gear5.Opcoes): Gear5.Instancia?
			return criar(personagem, opcoes, est)
		end,
	}
end

-- Ordem dos estágios (para a prévia do Studio passar de um para o outro)
Caudas.ORDEM = {
	"naruto_2",
	"naruto_3",
	"naruto_4",
	"naruto_5",
	"naruto_6",
	"naruto_7",
	"naruto_8",
	"naruto_9",
	"naruto_seis",
}

return Caudas
