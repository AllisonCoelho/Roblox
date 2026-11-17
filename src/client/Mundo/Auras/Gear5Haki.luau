-- Haki do Rei da Gear 5: raios negros com brilho vermelho saindo do corpo, onda de pressão,
-- rachaduras no chão e um "apagão" curto da tela para quem é o dono da aura.
-- Malhas próprias geradas no Blender (assets/gear5/source/generate_haki.py), lidas por MalhaNuvem.
-- Tudo local, sem colisão e com autodestruição. Quem decide QUANDO estoura é a PresencaAnime,
-- nos quadros da animação (auge da risada, meio do repouso, pisadas e pousos).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MalhaNuvem = require(script.Parent.MalhaNuvem)

local Haki = {}

local PRETO = Color3.fromRGB(10, 3, 8)
local VERMELHO = Color3.fromRGB(255, 22, 52)
local RAIOS = { "haki_raio_a", "haki_raio_b", "haki_raio_c" }
local COMPRIMENTO_MALHA = 4 -- o raio foi modelado com 4 studs ao longo de +X
local LIMITE_ESTOUROS = 3

local qualidadeBaixa = false
local movimentoReduzido = false
local ativos = 0
local pasta: Folder? = nil
local rng = Random.new()

type Molde = { parte: BasePart, tamanho: Vector3 }
local moldes: { [string]: Molde } = {}

local function pastaVisual(): Folder
	if pasta and pasta.Parent then
		return pasta
	end
	local f = Instance.new("Folder")
	f.Name = "HakiDoRei"
	f.Parent = Workspace
	pasta = f
	return f
end

-- Peça reserva sem EditableMesh: um bloco fino (o raio ainda aparece, só sem o zigue-zague)
local function reserva(nome: string): Molde
	local p = Instance.new("Part")
	p.Material = Enum.Material.SmoothPlastic
	p.Size = if string.find(nome, "raio")
		then Vector3.new(4, 0.15, 0.15)
		elseif nome == "haki_onda" then Vector3.new(2.3, 0.06, 2.3)
		else Vector3.new(2.2, 0.04, 2.2)
	return { parte = p, tamanho = p.Size }
end

local function molde(nome: string): Molde
	local m = moldes[nome]
	if m then
		return m
	end
	local ok, parte = pcall(function()
		local p = MalhaNuvem.criar(nome, false)
		return p
	end)
	m = if ok and parte then { parte = parte, tamanho = parte.Size } else reserva(nome)
	m.parte.Anchored = true
	m.parte.CanCollide = false
	m.parte.CanQuery = false
	m.parte.CanTouch = false
	m.parte.CastShadow = false
	moldes[nome] = m
	return m
end

-- Converte as malhas cedo (a primeira conversão pode esperar)
task.spawn(function()
	for _, nome in { "haki_raio_a", "haki_raio_b", "haki_raio_c", "haki_onda", "haki_rachadura" } do
		molde(nome)
	end
end)

local function peca(
	nome: string,
	cor: Color3,
	neon: boolean,
	transparencia: number
): (BasePart, Vector3)
	local m = molde(nome)
	local p = m.parte:Clone()
	p.Color = cor
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = transparencia
	p.Parent = pastaVisual()
	return p, m.tamanho
end

local function sumir(partes: { BasePart }, atraso: number, duracao: number)
	task.delay(atraso, function()
		for _, p in partes do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(duracao), { Transparency = 1 }):Play()
			end
		end
		task.delay(duracao + 0.05, function()
			for _, p in partes do
				p:Destroy()
			end
		end)
	end)
end

-- Um raio: núcleo preto + casca vermelha neon, do ponto "origem" na direção "dir"
local function raio(
	origem: Vector3,
	dir: Vector3,
	comprimento: number,
	espessura: number
): { BasePart }
	local nome = RAIOS[rng:NextInteger(1, #RAIOS)]
	local nucleo, tam = peca(nome, PRETO, false, 0)
	local brilho = peca(nome, VERMELHO, true, 0.25)
	local escala = comprimento / COMPRIMENTO_MALHA
	nucleo.Size = Vector3.new(tam.X * escala, tam.Y * espessura, tam.Z * espessura)
	brilho.Size =
		Vector3.new(tam.X * escala * 1.02, tam.Y * espessura * 1.9, tam.Z * espessura * 1.9)
	-- +X da malha aponta para "dir"; o giro em X varia o zigue-zague de cada raio
	local cf = CFrame.lookAt(origem, origem + dir)
		* CFrame.Angles(0, math.pi / 2, 0)
		* CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)
		* CFrame.new(comprimento / 2, 0, 0)
	nucleo.CFrame = cf
	brilho.CFrame = cf
	return { nucleo, brilho }
end

local function direcaoAleatoria(paraBaixo: boolean): Vector3
	local ang = rng:NextNumber(0, math.pi * 2)
	local y = if paraBaixo then rng:NextNumber(-0.9, -0.35) else rng:NextNumber(-0.25, 0.7)
	return Vector3.new(math.cos(ang), y, math.sin(ang)).Unit
end

-- Raios que piscam: três sorteios rápidos (o "estalo" do haki) e depois apagam
local function tempestade(centro: Vector3, quantidade: number, alcance: number)
	local quadros = if movimentoReduzido then 1 else 3
	for q = 0, quadros - 1 do
		task.delay(q * 0.08, function()
			local partes = {}
			for i = 1, quantidade do
				local origem = centro
					+ Vector3.new(
						rng:NextNumber(-0.6, 0.6),
						rng:NextNumber(-0.8, 0.9),
						rng:NextNumber(-0.6, 0.6)
					)
				local dir = direcaoAleatoria(i % 3 == 0)
				for _, p in
					raio(origem, dir, alcance * rng:NextNumber(0.6, 1.1), rng:NextNumber(0.8, 1.3))
				do
					table.insert(partes, p)
				end
			end
			-- cada quadro some rápido; o último demora um pouco mais
			sumir(
				partes,
				if q == quadros - 1 then 0.12 else 0.06,
				if q == quadros - 1 then 0.25 else 0.03
			)
		end)
	end
end

local function chao(raiz: BasePart, personagem: Model): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { personagem, pastaVisual() }
	local hit = Workspace:Raycast(raiz.Position, Vector3.new(0, -9, 0), params)
	return if hit and hit.Normal.Y > 0.6 then hit else nil
end

local function ondaERachadura(hit: RaycastResult, intensidade: number)
	local plano = CFrame.lookAt(hit.Position, hit.Position + hit.Normal)
		* CFrame.Angles(-math.pi / 2, 0, 0)
	-- Onda de pressão: anel serrilhado que abre rápido e apaga
	local onda, tamOnda = peca("haki_onda", Color3.fromRGB(120, 0, 28), true, 0.15)
	local raioFinal = 13 * intensidade
	local inicio = 1.2
	onda.Size = Vector3.new(tamOnda.X * inicio / 1.1, tamOnda.Y, tamOnda.Z * inicio / 1.1)
	onda.CFrame = plano * CFrame.new(0, 0.6, 0)
	TweenService
		:Create(onda, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = Vector3.new(tamOnda.X * raioFinal / 1.1, tamOnda.Y, tamOnda.Z * raioFinal / 1.1),
			Transparency = 1,
		})
		:Play()
	task.delay(0.6, function()
		onda:Destroy()
	end)
	if qualidadeBaixa then
		return
	end
	-- Rachaduras: preto no chão com brilho vermelho por baixo; somem devagar
	local r = 4.5 * intensidade
	local giro = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local fenda, tam = peca("haki_rachadura", PRETO, false, 0.05)
	local luz = peca("haki_rachadura", VERMELHO, true, 0.2)
	fenda.Size = Vector3.new(tam.X * r, tam.Y, tam.Z * r)
	luz.Size = Vector3.new(tam.X * r * 1.06, tam.Y, tam.Z * r * 1.06)
	fenda.CFrame = plano * giro * CFrame.new(0, 0.05, 0)
	luz.CFrame = plano * giro * CFrame.new(0, 0.03, 0)
	sumir({ fenda, luz }, 0.9, 0.9)
end

-- Silhueta escura com contorno vermelho por um instante (o corpo "carrega" o haki)
local function silhueta(personagem: Model, duracao: number)
	local h = Instance.new("Highlight")
	h.Name = "HakiDoRei"
	h.FillColor = PRETO
	h.FillTransparency = 0.55
	h.OutlineColor = VERMELHO
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = personagem
	TweenService
		:Create(h, TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			FillTransparency = 1,
			OutlineTransparency = 1,
		})
		:Play()
	task.delay(duracao + 0.05, function()
		h:Destroy()
	end)
end

-- Só para o dono da aura: a tela perde cor e puxa para o vermelho, com um tremor curto
local function tela(intensidade: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HakiDoRei"
	cc.Saturation = -0.7 * intensidade
	cc.Contrast = 0.35 * intensidade
	cc.TintColor = Color3.fromRGB(255, 205, 210)
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
		Saturation = 0,
		Contrast = 0,
		TintColor = Color3.new(1, 1, 1),
	}):Play()
	task.delay(0.75, function()
		cc:Destroy()
	end)
	if movimentoReduzido then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	task.spawn(function()
		local fim = os.clock() + 0.28
		while os.clock() < fim do
			local f = (fim - os.clock()) / 0.28 * 0.18 * intensidade
			camera.CFrame *= CFrame.new(rng:NextNumber(-f, f), rng:NextNumber(-f, f), 0)
			task.wait()
		end
	end)
end

export type Tipo = "forte" | "fraco" | "passo" | "pouso"

-- Dispara o haki no personagem. "intensidade" escala o alcance (pouso usa a queda).
function Haki.disparar(personagem: Model, raiz: BasePart, tipo: Tipo, intensidade: number?)
	if ativos >= LIMITE_ESTOUROS then
		return
	end
	ativos += 1
	task.delay(1.2, function()
		ativos -= 1
	end)
	local forca = intensidade or 1
	local centro = raiz.Position + Vector3.new(0, 0.6, 0)
	local dono = personagem == (Players.LocalPlayer and Players.LocalPlayer.Character)
	task.spawn(function()
		if tipo == "fraco" or tipo == "passo" then
			-- faíscas: poucos raios curtos em volta do corpo
			tempestade(centro, if qualidadeBaixa then 2 else 4, 2.6 * forca)
			return
		end
		silhueta(personagem, 0.45)
		tempestade(centro, if qualidadeBaixa then 4 else 9, 6.5 * forca)
		local hit = chao(raiz, personagem)
		if hit then
			ondaERachadura(hit, forca)
		end
		if dono then
			tela(math.clamp(forca, 0.6, 1.2))
		end
	end)
end

function Haki.definirQualidade(baixa: boolean, reduzido: boolean)
	qualidadeBaixa = baixa
	movimentoReduzido = reduzido
end

return Haki
