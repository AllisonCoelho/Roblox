-- GERADO por assets/pets/source/generate_pets.py. Não editar à mão.
-- Como montar cada Eco e cada Núcleo: peças (malha, material, transparência) e, nas asas,
-- a junta (studs, espaço do Eco, origem no chão) e quanto batem (graus).
return {
	ecos = {
		lasquinho = {
			voa = false,
			altura = 2.924,
			largura = 1.329,
			partes = {
				{
					nome = "corpo",
					malha = "pet_lasquinho_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
			},
		},
		mariposa_vitral = {
			voa = true,
			altura = 2.580,
			largura = 3.246,
			partes = {
				{
					nome = "corpo",
					malha = "pet_mariposa_vitral_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_mariposa_vitral_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
				{
					nome = "asa_e",
					malha = "pet_mariposa_vitral_asa_e",
					material = "Glass",
					transparencia = 0.10,
					junta = { -0.22, 0.05, -1.6 },
					bater = 38,
				},
				{
					nome = "asa_d",
					malha = "pet_mariposa_vitral_asa_d",
					material = "Glass",
					transparencia = 0.10,
					junta = { 0.22, 0.05, -1.6 },
					bater = 38,
				},
			},
		},
		lanterneiro = {
			voa = false,
			altura = 2.300,
			largura = 1.713,
			partes = {
				{
					nome = "corpo",
					malha = "pet_lanterneiro_corpo",
					material = "Slate",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_lanterneiro_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
			},
		},
		sininho_vidro = {
			voa = true,
			altura = 2.089,
			largura = 1.640,
			partes = {
				{
					nome = "corpo",
					malha = "pet_sininho_vidro_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "vidro",
					malha = "pet_sininho_vidro_vidro",
					material = "Glass",
					transparencia = 0.25,
				},
				{
					nome = "brilho",
					malha = "pet_sininho_vidro_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
			},
		},
		raposa_prisma = {
			voa = false,
			altura = 2.450,
			largura = 2.908,
			partes = {
				{
					nome = "corpo",
					malha = "pet_raposa_prisma_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "vidro",
					malha = "pet_raposa_prisma_vidro",
					material = "Glass",
					transparencia = 0.10,
				},
			},
		},
		cervo_cantor = {
			voa = false,
			altura = 3.750,
			largura = 2.020,
			partes = {
				{
					nome = "corpo",
					malha = "pet_cervo_cantor_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_cervo_cantor_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
			},
		},
		fagulha = {
			voa = true,
			altura = 2.350,
			largura = 1.511,
			partes = {
				{
					nome = "corpo",
					malha = "pet_fagulha_corpo",
					material = "Metal",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_fagulha_brilho",
					material = "Neon",
					transparencia = 0.05,
				},
			},
		},
		escaravelho_solar = {
			voa = false,
			altura = 1.770,
			largura = 2.279,
			partes = {
				{
					nome = "corpo",
					malha = "pet_escaravelho_solar_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_escaravelho_solar_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
			},
		},
		salamandra_obsidiana = {
			voa = false,
			altura = 1.058,
			largura = 3.230,
			partes = {
				{
					nome = "corpo",
					malha = "pet_salamandra_obsidiana_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_salamandra_obsidiana_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
			},
		},
		peixe_bolha = {
			voa = true,
			altura = 2.680,
			largura = 1.900,
			partes = {
				{
					nome = "corpo",
					malha = "pet_peixe_bolha_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "vidro",
					malha = "pet_peixe_bolha_vidro",
					material = "Glass",
					transparencia = 0.55,
				},
				{
					nome = "brilho",
					malha = "pet_peixe_bolha_brilho",
					material = "Neon",
					transparencia = 0.30,
				},
			},
		},
		aguaviva_lanterna = {
			voa = true,
			altura = 2.300,
			largura = 1.900,
			partes = {
				{
					nome = "corpo",
					malha = "pet_aguaviva_lanterna_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "vidro",
					malha = "pet_aguaviva_lanterna_vidro",
					material = "Glass",
					transparencia = 0.35,
				},
				{
					nome = "brilho",
					malha = "pet_aguaviva_lanterna_brilho",
					material = "Neon",
					transparencia = 0.15,
				},
			},
		},
		baleia_celeste = {
			voa = true,
			altura = 2.430,
			largura = 2.921,
			partes = {
				{
					nome = "corpo",
					malha = "pet_baleia_celeste_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_baleia_celeste_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
				{
					nome = "asa_e",
					malha = "pet_baleia_celeste_asa_e",
					material = "SmoothPlastic",
					transparencia = 0.00,
					junta = { -0.55, 1, -0.3 },
					bater = 18,
				},
				{
					nome = "asa_d",
					malha = "pet_baleia_celeste_asa_d",
					material = "SmoothPlastic",
					transparencia = 0.00,
					junta = { 0.55, 1, -0.3 },
					bater = 18,
				},
			},
		},
		sino_alado = {
			voa = true,
			altura = 2.548,
			largura = 2.718,
			partes = {
				{
					nome = "corpo",
					malha = "pet_sino_alado_corpo",
					material = "Metal",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_sino_alado_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
				{
					nome = "asa_e",
					malha = "pet_sino_alado_asa_e",
					material = "SmoothPlastic",
					transparencia = 0.00,
					junta = { -0.45, 1.4, 0 },
					bater = 28,
				},
				{
					nome = "asa_d",
					malha = "pet_sino_alado_asa_d",
					material = "SmoothPlastic",
					transparencia = 0.00,
					junta = { 0.45, 1.4, 0 },
					bater = 28,
				},
			},
		},
		coruja_vitral = {
			voa = true,
			altura = 2.350,
			largura = 2.839,
			partes = {
				{
					nome = "corpo",
					malha = "pet_coruja_vitral_corpo",
					material = "Marble",
					transparencia = 0.00,
				},
				{
					nome = "vidro",
					malha = "pet_coruja_vitral_vidro",
					material = "Glass",
					transparencia = 0.05,
				},
				{
					nome = "asa_e",
					malha = "pet_coruja_vitral_asa_e",
					material = "Marble",
					transparencia = 0.00,
					junta = { -0.65, 1.3, 0.05 },
					bater = 22,
				},
				{
					nome = "asa_d",
					malha = "pet_coruja_vitral_asa_d",
					material = "Marble",
					transparencia = 0.00,
					junta = { 0.65, 1.3, 0.05 },
					bater = 22,
				},
			},
		},
		querubim_partido = {
			voa = true,
			altura = 2.615,
			largura = 2.514,
			partes = {
				{
					nome = "corpo",
					malha = "pet_querubim_partido_corpo",
					material = "Marble",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_querubim_partido_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
				{
					nome = "asa_e",
					malha = "pet_querubim_partido_asa_e",
					material = "SmoothPlastic",
					transparencia = 0.00,
					junta = { -0.55, 1.3, 0.35 },
					bater = 20,
				},
				{
					nome = "asa_d",
					malha = "pet_querubim_partido_asa_d",
					material = "SmoothPlastic",
					transparencia = 0.00,
					junta = { 0.55, 1.3, 0.35 },
					bater = 20,
				},
			},
		},
		olho_errante = {
			voa = true,
			altura = 2.358,
			largura = 2.171,
			partes = {
				{
					nome = "corpo",
					malha = "pet_olho_errante_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_olho_errante_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
			},
		},
		gato_constelacao = {
			voa = false,
			altura = 2.040,
			largura = 2.030,
			partes = {
				{
					nome = "corpo",
					malha = "pet_gato_constelacao_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_gato_constelacao_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
			},
		},
		dragao_estelar = {
			voa = true,
			altura = 2.729,
			largura = 3.465,
			partes = {
				{
					nome = "corpo",
					malha = "pet_dragao_estelar_corpo",
					material = "SmoothPlastic",
					transparencia = 0.00,
				},
				{
					nome = "brilho",
					malha = "pet_dragao_estelar_brilho",
					material = "Neon",
					transparencia = 0.00,
				},
				{
					nome = "asa_e",
					malha = "pet_dragao_estelar_asa_e",
					material = "Glass",
					transparencia = 0.10,
					junta = { -0.3, 1.8, -0.3 },
					bater = 16,
				},
				{
					nome = "asa_d",
					malha = "pet_dragao_estelar_asa_d",
					material = "Glass",
					transparencia = 0.10,
					junta = { 0.3, 1.8, -0.3 },
					bater = 16,
				},
			},
		},
	},
	nucleos = {
		{
			{ nome = "corpo", malha = "nucleo_1_corpo", material = "Metal", transparencia = 0.00 },
			{ nome = "vidro", malha = "nucleo_1_vidro", material = "Glass", transparencia = 0.35 },
			{ nome = "brilho", malha = "nucleo_1_brilho", material = "Neon", transparencia = 0.00 },
		},
		{
			{ nome = "corpo", malha = "nucleo_2_corpo", material = "Metal", transparencia = 0.00 },
			{ nome = "vidro", malha = "nucleo_2_vidro", material = "Glass", transparencia = 0.35 },
			{ nome = "brilho", malha = "nucleo_2_brilho", material = "Neon", transparencia = 0.00 },
		},
		{
			{ nome = "corpo", malha = "nucleo_3_corpo", material = "Metal", transparencia = 0.00 },
			{ nome = "vidro", malha = "nucleo_3_vidro", material = "Glass", transparencia = 0.35 },
			{ nome = "brilho", malha = "nucleo_3_brilho", material = "Neon", transparencia = 0.00 },
		},
		{
			{ nome = "corpo", malha = "nucleo_4_corpo", material = "Metal", transparencia = 0.00 },
			{ nome = "vidro", malha = "nucleo_4_vidro", material = "Glass", transparencia = 0.35 },
			{ nome = "brilho", malha = "nucleo_4_brilho", material = "Neon", transparencia = 0.00 },
		},
		{
			{ nome = "corpo", malha = "nucleo_5_corpo", material = "Metal", transparencia = 0.00 },
			{ nome = "vidro", malha = "nucleo_5_vidro", material = "Glass", transparencia = 0.35 },
			{ nome = "brilho", malha = "nucleo_5_brilho", material = "Neon", transparencia = 0.00 },
		},
		{
			{ nome = "corpo", malha = "nucleo_6_corpo", material = "Metal", transparencia = 0.00 },
			{ nome = "vidro", malha = "nucleo_6_vidro", material = "Glass", transparencia = 0.35 },
			{ nome = "brilho", malha = "nucleo_6_brilho", material = "Neon", transparencia = 0.00 },
		},
	},
}
