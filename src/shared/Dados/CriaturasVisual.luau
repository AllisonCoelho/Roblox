-- GERADO por assets/corredor/criaturas/generate_criaturas.py. Não editar à mão.
-- Criaturas do Corredor: peças rígidas (como um R6), juntas (studs, espaço da criatura com
-- origem no chão) e as malhas de cada peça. Com um modelo importado em
-- ReplicatedStorage.CorredorModelos.<id>, o cliente usa as MeshParts dele com estes nomes.
return {
	lasca_errante = {
		fase = 1,
		tipo = "lacaio",
		altura = 6.388,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_lasca_errante_tronco",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_lasca_errante_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 4, 0 },
				malhas = {
					{
						malha = "criatura_lasca_errante_cabeca",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_lasca_errante_cabeca_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
					{
						malha = "criatura_lasca_errante_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_lasca_errante_braco_e",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_lasca_errante_braco_e_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_lasca_errante_braco_d",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_lasca_errante_braco_d_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_lasca_errante_perna_e",
						material = "Slate",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_lasca_errante_perna_d",
						material = "Slate",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	sentinela_limiar = {
		fase = 1,
		tipo = "chefe",
		altura = 15.345,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_sentinela_limiar_tronco",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_sentinela_limiar_tronco_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
					{
						malha = "criatura_sentinela_limiar_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 9.2, -0 },
				malhas = {
					{
						malha = "criatura_sentinela_limiar_cabeca",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_sentinela_limiar_cabeca_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
					{
						malha = "criatura_sentinela_limiar_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -3.634, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_sentinela_limiar_braco_e",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_sentinela_limiar_braco_e_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 3.634, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_sentinela_limiar_braco_d",
						material = "Slate",
						transparencia = 0.00,
					},
					{
						malha = "criatura_sentinela_limiar_braco_d_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -1.438, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_sentinela_limiar_perna_e",
						material = "Slate",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 1.438, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_sentinela_limiar_perna_d",
						material = "Slate",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	broto_vidro = {
		fase = 2,
		tipo = "lacaio",
		altura = 6.687,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_broto_vidro_tronco",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_broto_vidro_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 4, 0 },
				malhas = {
					{
						malha = "criatura_broto_vidro_cabeca",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_broto_vidro_cabeca_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
					{
						malha = "criatura_broto_vidro_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -1.32, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_broto_vidro_braco_e",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_broto_vidro_braco_e_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 1.32, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_broto_vidro_braco_d",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_broto_vidro_braco_d_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_broto_vidro_perna_e",
						material = "Wood",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_broto_vidro_perna_d",
						material = "Wood",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	anciao_bosque = {
		fase = 2,
		tipo = "chefe",
		altura = 14.457,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_anciao_bosque_tronco",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_anciao_bosque_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 9.2, -0 },
				malhas = {
					{
						malha = "criatura_anciao_bosque_cabeca",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_anciao_bosque_cabeca_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
					{
						malha = "criatura_anciao_bosque_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -3.611, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_anciao_bosque_braco_e",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_anciao_bosque_braco_e_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 3.611, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_anciao_bosque_braco_d",
						material = "Wood",
						transparencia = 0.00,
					},
					{
						malha = "criatura_anciao_bosque_braco_d_vidro",
						material = "Glass",
						transparencia = 0.15,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -1.552, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_anciao_bosque_perna_e",
						material = "Wood",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 1.552, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_anciao_bosque_perna_d",
						material = "Wood",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	cinzento = {
		fase = 3,
		tipo = "lacaio",
		altura = 5.660,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_cinzento_tronco",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_cinzento_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 4, 0 },
				malhas = {
					{
						malha = "criatura_cinzento_cabeca",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_cinzento_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_cinzento_braco_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_cinzento_braco_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_cinzento_braco_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_cinzento_perna_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_cinzento_perna_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	senhor_brasas = {
		fase = 3,
		tipo = "chefe",
		altura = 14.134,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_senhor_brasas_tronco",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_senhor_brasas_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 9.2, -0 },
				malhas = {
					{
						malha = "criatura_senhor_brasas_cabeca",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_senhor_brasas_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -4.244, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_senhor_brasas_braco_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_senhor_brasas_braco_e_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 4.244, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_senhor_brasas_braco_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_senhor_brasas_braco_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -1.782, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_senhor_brasas_perna_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 1.782, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_senhor_brasas_perna_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	marujo_afogado = {
		fase = 4,
		tipo = "lacaio",
		altura = 5.670,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_marujo_afogado_tronco",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 4, 0 },
				malhas = {
					{
						malha = "criatura_marujo_afogado_cabeca",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_marujo_afogado_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_marujo_afogado_braco_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_marujo_afogado_braco_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_marujo_afogado_braco_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_marujo_afogado_perna_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_marujo_afogado_perna_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	capitao_abissal = {
		fase = 4,
		tipo = "chefe",
		altura = 13.835,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_capitao_abissal_tronco",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 9.2, -0 },
				malhas = {
					{
						malha = "criatura_capitao_abissal_cabeca",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_capitao_abissal_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -3.749, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_capitao_abissal_braco_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_capitao_abissal_braco_e_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 3.749, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_capitao_abissal_braco_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -1.552, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_capitao_abissal_perna_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 1.552, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_capitao_abissal_perna_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	estatua_viva = {
		fase = 5,
		tipo = "lacaio",
		altura = 5.795,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_estatua_viva_tronco",
						material = "Marble",
						transparencia = 0.00,
					},
					{
						malha = "criatura_estatua_viva_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 4, 0 },
				malhas = {
					{
						malha = "criatura_estatua_viva_cabeca",
						material = "Marble",
						transparencia = 0.00,
					},
					{
						malha = "criatura_estatua_viva_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_estatua_viva_braco_e",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_estatua_viva_braco_d",
						material = "Marble",
						transparencia = 0.00,
					},
					{
						malha = "criatura_estatua_viva_braco_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_estatua_viva_perna_e",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_estatua_viva_perna_d",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	arcanjo_partido = {
		fase = 5,
		tipo = "chefe",
		altura = 13.871,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_arcanjo_partido_tronco",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 9.2, -0 },
				malhas = {
					{
						malha = "criatura_arcanjo_partido_cabeca",
						material = "Marble",
						transparencia = 0.00,
					},
					{
						malha = "criatura_arcanjo_partido_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -3.634, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_arcanjo_partido_braco_e",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 3.634, 8.51, -0 },
				malhas = {
					{
						malha = "criatura_arcanjo_partido_braco_d",
						material = "Marble",
						transparencia = 0.00,
					},
					{
						malha = "criatura_arcanjo_partido_braco_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -1.438, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_arcanjo_partido_perna_e",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 1.438, 4.6, -0 },
				malhas = {
					{
						malha = "criatura_arcanjo_partido_perna_d",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "asa_e",
				pai = "tronco",
				junta = { -1.38, 8.28, 1.265 },
				malhas = {
					{
						malha = "criatura_arcanjo_partido_asa_e",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "asa_d",
				pai = "tronco",
				junta = { 1.38, 8.28, 1.265 },
				malhas = {
					{
						malha = "criatura_arcanjo_partido_asa_d",
						material = "Marble",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	eco_vazio = {
		fase = 6,
		tipo = "lacaio",
		altura = 5.470,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_eco_vazio_tronco",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_eco_vazio_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 4, 0 },
				malhas = {
					{
						malha = "criatura_eco_vazio_cabeca",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_eco_vazio_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_eco_vazio_braco_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_eco_vazio_braco_e_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 1.48, 3.7, 0 },
				malhas = {
					{
						malha = "criatura_eco_vazio_braco_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_eco_vazio_braco_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_eco_vazio_perna_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_eco_vazio_perna_e_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 0.525, 2, 0 },
				malhas = {
					{
						malha = "criatura_eco_vazio_perna_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_eco_vazio_perna_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
		},
	},
	devorador_estrelas = {
		fase = 6,
		tipo = "chefe",
		altura = 14.466,
		partes = {
			{
				nome = "tronco",
				malhas = {
					{
						malha = "criatura_devorador_estrelas_tronco",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_devorador_estrelas_tronco_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "cabeca",
				pai = "tronco",
				junta = { 0, 9.6, -0 },
				malhas = {
					{
						malha = "criatura_devorador_estrelas_cabeca",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_devorador_estrelas_cabeca_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_e",
				pai = "tronco",
				junta = { -4.128, 8.88, -0 },
				malhas = {
					{
						malha = "criatura_devorador_estrelas_braco_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_devorador_estrelas_braco_e_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "braco_d",
				pai = "tronco",
				junta = { 4.128, 8.88, -0 },
				malhas = {
					{
						malha = "criatura_devorador_estrelas_braco_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
					{
						malha = "criatura_devorador_estrelas_braco_d_brilho",
						material = "Neon",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_e",
				pai = "tronco",
				junta = { -1.74, 4.8, -0 },
				malhas = {
					{
						malha = "criatura_devorador_estrelas_perna_e",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
			{
				nome = "perna_d",
				pai = "tronco",
				junta = { 1.74, 4.8, -0 },
				malhas = {
					{
						malha = "criatura_devorador_estrelas_perna_d",
						material = "SmoothPlastic",
						transparencia = 0.00,
					},
				},
			},
		},
	},
}
