-- GERADO por assets/auras/senbonzakura/source/generate_senbonzakura.py — edite lá e rode de novo.
-- Templates (MeshParts importados no Studio) e a coreografia da Senbonzakura.
-- tamanho: caixa da malha em studs (eixos Roblox); centro: do pivô até o centro da caixa.
-- Órbitas relativas ao HumanoidRootPart (frente = -Z); ângulo 0 = direita, -pi/2 = frente.
local Pecas = {}

Pecas.REVISAO = 1

Pecas.TEMPLATES = {
	senbon_petal_a = {
		tamanho = Vector3.new(0.1907, 0.058, 0.7),
		centro = Vector3.new(0, 0.0095, -0.035),
	},
	senbon_petal_b = {
		tamanho = Vector3.new(0.0774, 0.0579, 0.748),
		centro = Vector3.new(-0.0006, 0.0103, -0.0374),
	},
	senbon_cluster_a = {
		tamanho = Vector3.new(1.3284, 1.2422, 2.4581),
		centro = Vector3.new(0.1999, 0.1158, -0.0222),
	},
	senbon_cluster_b = {
		tamanho = Vector3.new(0.9439, 1.4413, 3.0196),
		centro = Vector3.new(0.0865, 0.0173, 0.1293),
	},
	senbon_cluster_c = {
		tamanho = Vector3.new(0.7579, 1.6326, 2.3305),
		centro = Vector3.new(-0.2796, 0.1567, -0.1633),
	},
	senbon_lance_a = {
		tamanho = Vector3.new(0.4, 2.6, 0.0465),
		centro = Vector3.new(0, 1.3, 0.0058),
	},
	senbon_lance_b = {
		tamanho = Vector3.new(0.7761, 2.9569, 0.0407),
		centro = Vector3.new(0.2689, 1.4641, 0.0051),
	},
	senbon_arco_a = {
		tamanho = Vector3.new(3.2254, 0.3538, 3.0161),
		centro = Vector3.new(1.4676, 0.0519, -1.5081),
	},
	senbon_arco_b = {
		tamanho = Vector3.new(2.44, 0.455, 2.7486),
		centro = Vector3.new(1.4648, -0.0525, -1.3743),
	},
	senbon_selo = {
		tamanho = Vector3.new(6.9701, 0.034, 6.724),
		centro = Vector3.new(-0.0392, 0.0066, -0.2931),
	},
}

Pecas.ORBITAS = {
	{
		template = "senbon_cluster_a",
		rx = 2.9,
		rz = 2.6,
		altura = 0.35,
		angulo = 0.3,
		vel = 0.42,
		inclinacao = 0.28,
		escala = 1,
		rigidez = 46,
		atraso = 0.55,
		giro = 12,
	},
	{
		template = "senbon_cluster_b",
		rx = 3.3,
		rz = 2.9,
		altura = 1,
		angulo = 2.4,
		vel = 0.36,
		inclinacao = -0.35,
		escala = 1,
		rigidez = 38,
		atraso = 0.7,
		giro = 9,
	},
	{
		template = "senbon_cluster_c",
		rx = 2.7,
		rz = 2.4,
		altura = 1.65,
		angulo = 4.2,
		vel = 0.55,
		inclinacao = 0.22,
		escala = 0.9,
		rigidez = 58,
		atraso = 0.45,
		giro = 15,
	},
	{
		template = "senbon_cluster_a",
		rx = 3.5,
		rz = 3.1,
		altura = -0.5,
		angulo = 3.6,
		vel = -0.3,
		inclinacao = 0.45,
		escala = 1.15,
		rigidez = 30,
		atraso = 0.85,
		giro = 8,
	},
	{
		template = "senbon_cluster_b",
		rx = 3,
		rz = 2.7,
		altura = 0.2,
		angulo = 5.4,
		vel = 0.48,
		inclinacao = -0.2,
		escala = 0.85,
		rigidez = 50,
		atraso = 0.6,
		giro = 14,
	},
	{
		template = "senbon_cluster_c",
		rx = 3.6,
		rz = 3.2,
		altura = 2,
		angulo = 1.2,
		vel = -0.27,
		inclinacao = 0.3,
		escala = 1.1,
		rigidez = 26,
		atraso = 0.9,
		giro = 10,
	},
	{
		template = "senbon_cluster_a",
		rx = 2.6,
		rz = 2.3,
		altura = -0.95,
		angulo = 0.9,
		vel = 0.6,
		inclinacao = 0.15,
		escala = 0.75,
		rigidez = 64,
		atraso = 0.4,
		giro = 18,
	},
}
Pecas.ORBITAS_BAIXA = 5
Pecas.ORBITAS_MEDIO = 4

Pecas.LANCAS = {
	{ template = "senbon_lance_a", graus = 180, raio = 2.9, altura = 1.15 },
	{ template = "senbon_lance_b", graus = 150, raio = 3.2, altura = 1 },
	{ template = "senbon_lance_a", graus = -150, raio = 3.1, altura = 1.05 },
	{ template = "senbon_lance_b", graus = 120, raio = 2.8, altura = 0.9 },
	{ template = "senbon_lance_a", graus = -120, raio = 2.9, altura = 0.95 },
	{ template = "senbon_lance_b", graus = 95, raio = 3.4, altura = 0.8 },
	{ template = "senbon_lance_a", graus = -95, raio = 3.3, altura = 0.85 },
	{ template = "senbon_lance_b", graus = 165, raio = 3.7, altura = 0.75 },
	{ template = "senbon_lance_a", graus = -165, raio = 3.6, altura = 0.9 },
}

-- Parâmetros da tabela 5.2 do briefing (ajustáveis em playtest)
Pecas.PARAMETROS = {
	respiracao = 0.05, -- fração do raio (3%–7%)
	periodoRespiracao = 6, -- s (4–8)
	balanco = 0.16, -- studs de sobe/desce (0,08–0,28)
	intervaloPico = { 12, 20 }, -- s
	duracaoPico = 1.8, -- s (1,5–2,0)
	duracaoManifestar = 1.55, -- s (1,3–1,7)
	duracaoSaida = 0.28, -- s (0,22–0,35)
	lodDetalhe = 80,
	lodOculto = 140,
}

return Pecas
