-- GERADO por assets/auras/naruto/source/generate_naruto.py. Não editar à mão.
-- Família Naruto: um estágio por aura. Ângulos em graus (exceto onda, em radianos).
return {
	segmentos = {
		{ malha = "naruto_cauda_base", nucleo = "naruto_cauda_base_nucleo", comprimento = 2.3 },
		{ malha = "naruto_cauda_meio1", nucleo = "naruto_cauda_meio1_nucleo", comprimento = 2.2 },
		{ malha = "naruto_cauda_meio2", nucleo = "naruto_cauda_meio2_nucleo", comprimento = 2 },
		{ malha = "naruto_cauda_ponta", nucleo = "naruto_cauda_ponta_nucleo", comprimento = 2.8 },
	},
	avanco = 0.82,
	curvaMalha = 14,
	raiz = { 0, -0.75, 0.55 },
	troncoRef = { 2, 1.6, 1 },
	mangaRef = { 1, 1.17, 1 },
	estagios = {
		naruto_2 = { nome = "Modo 2 Caudas", caudas = 2, abertura = 55, elevacao = 40, elevLados = 28, curva = 32, comprimento = 1, grossura = 1.05, fora = "FF2A12", dentro = "FF9A3A", transpFora = 0.3, onda = 0.2, freq = 2.4, alterna = false, pulso = false, contracao = false, raposa = false, seis = false, manto = "v1", esqueleto = false, cabelo = false },
		naruto_3 = { nome = "Modo 3 Caudas", caudas = 3, abertura = 62, elevacao = 48, elevLados = 24, curva = 32, comprimento = 1, grossura = 1, fora = "FF2A12", dentro = "FF9A3A", transpFora = 0.3, onda = 0.22, freq = 2.5, alterna = false, pulso = false, contracao = false, raposa = false, seis = false, manto = "v1", esqueleto = false, cabelo = false },
		naruto_4 = { nome = "Modo 4 Caudas", caudas = 4, abertura = 70, elevacao = 50, elevLados = 18, curva = 32, comprimento = 1.05, grossura = 1.08, fora = "B3120A", dentro = "FF4A1A", transpFora = 0.22, onda = 0.26, freq = 2.8, alterna = false, pulso = true, contracao = false, raposa = false, seis = false, manto = "v2", esqueleto = false, cabelo = false },
		naruto_5 = { nome = "Modo 5 Caudas", caudas = 5, abertura = 78, elevacao = 52, elevLados = 14, curva = 31, comprimento = 1.08, grossura = 1.12, fora = "B3120A", dentro = "FF4A1A", transpFora = 0.22, onda = 0.26, freq = 2.6, alterna = false, pulso = true, contracao = true, raposa = false, seis = false, manto = "v2", esqueleto = false, cabelo = false },
		naruto_6 = { nome = "Modo 6 Caudas", caudas = 6, abertura = 86, elevacao = 55, elevLados = 10, curva = 30, comprimento = 1.2, grossura = 1.12, fora = "A80F08", dentro = "FF3A14", transpFora = 0.2, onda = 0.3, freq = 2.9, alterna = false, pulso = true, contracao = false, raposa = false, seis = false, manto = "v2", esqueleto = true, cabelo = false },
		naruto_7 = { nome = "Modo 7 Caudas", caudas = 7, abertura = 92, elevacao = 58, elevLados = 6, curva = 30, comprimento = 1.22, grossura = 1.15, fora = "A80F08", dentro = "FF3A14", transpFora = 0.2, onda = 0.28, freq = 2.7, alterna = true, pulso = true, contracao = false, raposa = false, seis = false, manto = "v2", esqueleto = true, cabelo = false },
		naruto_8 = { nome = "Modo 8 Caudas", caudas = 8, abertura = 98, elevacao = 60, elevLados = 4, curva = 29, comprimento = 1.28, grossura = 1.25, fora = "9E0C06", dentro = "FF3A14", transpFora = 0.18, onda = 0.28, freq = 2.6, alterna = true, pulso = true, contracao = false, raposa = false, seis = false, manto = "v2", esqueleto = true, cabelo = false },
		naruto_9 = { nome = "Modo 9 Caudas", caudas = 9, abertura = 104, elevacao = 62, elevLados = 2, curva = 29, comprimento = 1.32, grossura = 1.28, fora = "9E0C06", dentro = "FF5A1A", transpFora = 0.18, onda = 0.3, freq = 2.6, alterna = true, pulso = true, contracao = false, raposa = true, seis = false, manto = "v2", esqueleto = true, cabelo = false },
		naruto_seis = { nome = "Modo Sábio dos Seis Caminhos", caudas = 6, abertura = 100, elevacao = 42, elevLados = 0, curva = 25, comprimento = 1.25, grossura = 0.78, fora = "FFC93A", dentro = "FFF6D0", transpFora = 0.35, onda = 0.12, freq = 1.1, alterna = false, pulso = false, contracao = false, raposa = false, seis = true, manto = "", esqueleto = false, cabelo = true },
	},
}
