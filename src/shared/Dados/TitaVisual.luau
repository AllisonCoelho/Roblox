-- GERADO por assets/evento/source/generate_tita.py. Não editar à mão.
-- Peças do Titã de Borracha: malhas (base e brilho), junta no espaço do Titã (pés no chão,
-- frente = -Z do Roblox) e o papel de cada peça na animação.
return {
	{
		nome = "pernaD",
		junta = { 2.600, 7.500, 0.000 },
		camadas = { { malha = "tita_pernaD", material = "SmoothPlastic" } },
	},
	{
		nome = "pernaE",
		junta = { -2.600, 7.500, 0.000 },
		camadas = { { malha = "tita_pernaE", material = "SmoothPlastic" } },
	},
	{
		nome = "tronco",
		junta = { 0.000, 7.500, 0.000 },
		camadas = {
			{ malha = "tita_tronco", material = "SmoothPlastic" },
			{ malha = "tita_tronco_brilho", material = "Neon" },
		},
	},
	{
		nome = "cabeca",
		junta = { 0.000, 17.200, 0.000 },
		camadas = {
			{ malha = "tita_cabeca", material = "SmoothPlastic" },
			{ malha = "tita_cabeca_brilho", material = "Neon" },
		},
	},
	{
		nome = "cabelo",
		junta = { 0.000, 17.200, 0.000 },
		camadas = { { malha = "tita_cabelo", material = "SmoothPlastic" } },
	},
	{
		nome = "halo",
		junta = { 0.000, 21.200, -0.300 },
		camadas = { { malha = "tita_halo_brilho", material = "Neon" } },
	},
	{
		nome = "bracoD",
		junta = { 5.200, 15.200, 0.000 },
		camadas = { { malha = "tita_bracoD", material = "SmoothPlastic" } },
	},
	{
		nome = "bracoE",
		junta = { -5.200, 15.200, 0.000 },
		camadas = { { malha = "tita_bracoE", material = "SmoothPlastic" } },
	},
}
