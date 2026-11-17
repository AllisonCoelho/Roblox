-- GERADO por assets/npcs/primeiro_soberano/source/generate_soberano.py. Não editar à mão.
-- Primeiro Soberano: onde fica (espaço local da Arena, igual ao do trono) e as peças
-- articuladas. junta = ponto em torno do qual a peça gira (espaço do NPC, studs do Roblox).
return {
	arena = { graus = 180, dist = 156 },
	trono = { 0, 2.1, 19.4 }, -- origem do NPC no espaço local da Arena (pé do trono)
	cabeca = { 0.000, 5.950, 0.200 }, -- centro do elmo (para onde os olhos ficam)
	pecas = {
		{ nome = "base", malha = "soberano_base", material = "Metal" },
		{ nome = "espada", malha = "soberano_espada", material = "Metal" },
		{
			nome = "torso",
			malha = "soberano_torso",
			material = "Metal",
			junta = { 0.000, 2.750, 0.250 },
		},
		{
			nome = "nucleo",
			malha = "soberano_nucleo",
			material = "Neon",
			junta = { 0.000, 2.750, 0.250 },
			pai = "torso",
		},
		{
			nome = "fissuras",
			malha = "soberano_fissuras",
			material = "Neon",
			junta = { 0.000, 2.750, 0.250 },
			pai = "torso",
		},
		{
			nome = "cabeca",
			malha = "soberano_cabeca",
			material = "Metal",
			junta = { 0.000, 5.350, 0.300 },
			pai = "torso",
		},
		{
			nome = "olhos",
			malha = "soberano_olhos",
			material = "Neon",
			junta = { 0.000, 5.350, 0.300 },
			pai = "cabeca",
		},
		{
			nome = "braco_dir",
			malha = "soberano_braco_dir",
			material = "Metal",
			junta = { 1.750, 4.950, 0.350 },
			pai = "torso",
		},
		{
			nome = "braco_esq",
			malha = "soberano_braco_esq",
			material = "Metal",
			junta = { -1.750, 4.950, 0.350 },
			pai = "torso",
		},
		{
			nome = "antebraco_dir",
			malha = "soberano_antebraco_dir",
			material = "Metal",
			junta = { 2.850, 3.950, -0.000 },
			pai = "braco_dir",
		},
		{
			nome = "antebraco_esq",
			malha = "soberano_antebraco_esq",
			material = "Metal",
			junta = { -2.850, 3.950, -0.000 },
			pai = "braco_esq",
		},
		{
			nome = "capa_dir",
			malha = "soberano_capa_dir",
			material = "Fabric",
			junta = { 1.750, 5.200, 0.900 },
			pai = "torso",
		},
		{
			nome = "capa_esq",
			malha = "soberano_capa_esq",
			material = "Fabric",
			junta = { -1.750, 5.200, 0.900 },
			pai = "torso",
		},
	},
}
