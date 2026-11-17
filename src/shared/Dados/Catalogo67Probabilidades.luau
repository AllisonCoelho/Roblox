-- Referencia MATEMATICA da colecao original de 67 auras. Nao ativa o catalogo
-- nem substitui os 30 IDs antigos; apenas deixa a distribuicao aprovada testavel.
local Probabilidades = require(script.Parent.Probabilidades)

local DEFINICOES = {
	{ "centelha_do_nexo", 0, "Comum" },
	{ "musgo_luminoso", 6, "Comum" },
	{ "fagulha_de_cobre", 7, "Comum" },
	{ "chuvisco_de_vidro", 9, "Comum" },
	{ "borboletas_de_cinza", 12, "Incomum" },
	{ "gelo_de_neon", 16, "Incomum" },
	{ "mare_de_quartzo", 22, "Incomum" },
	{ "raiz_cintilante", 30, "Incomum" },
	{ "nevoa_de_amora", 42, "Incomum" },
	{ "vento_de_papel", 55, "Incomum" },
	{ "polen_lunar", 70, "Incomum" },
	{ "engrenagem_de_orvalho", 82, "Incomum" },
	{ "trilha_de_vaga_lumes", 90, "Incomum" },
	{ "ambar_vivo", 95, "Incomum" },
	{ "coroa_de_coral", 110, "Raro" },
	{ "relampago_de_giz", 135, "Raro" },
	{ "prisma_partilhado", 160, "Raro" },
	{ "jiboia_de_fumaca", 195, "Raro" },
	{ "fenda_de_porcelana", 240, "Raro" },
	{ "petalas_de_ferrugem", 300, "Raro" },
	{ "sinos_do_crepusculo", 360, "Raro" },
	{ "esporos_de_safira", 440, "Raro" },
	{ "solsticio_de_areia", 520, "Raro" },
	{ "marfim_flutuante", 600, "Raro" },
	{ "lotus_de_gravidade", 680, "Raro" },
	{ "espelho_de_chuva", 760, "Raro" },
	{ "capsula_de_tempestade", 840, "Raro" },
	{ "cauda_de_cometa", 910, "Raro" },
	{ "prisma_do_silencio", 970, "Raro" },
	{ "arquivista_espectral", 1200, "Épico" },
	{ "jardim_das_agulhas", 1500, "Épico" },
	{ "carrossel_de_eclipses", 1900, "Épico" },
	{ "coracao_de_basalto", 2500, "Épico" },
	{ "plumas_de_mercurio", 3200, "Épico" },
	{ "valsa_do_abismo", 4200, "Épico" },
	{ "navio_de_papel_fantasma", 5500, "Épico" },
	{ "duas_luas_partidas", 6500, "Épico" },
	{ "correntes_do_vazio", 7000, "Épico" },
	{ "catedral_de_sal", 7500, "Épico" },
	{ "circulo_dos_predadores", 8000, "Épico" },
	{ "jardim_invertido", 8500, "Épico" },
	{ "guardiao_da_ampulheta", 9000, "Épico" },
	{ "mare_de_vidro_negro", 9500, "Épico" },
	{ "sussurro_das_mascaras", 9900, "Épico" },
	{ "arquiduque_de_cinzas", 12000, "Lendário" },
	{ "aurora_do_mar_profundo", 16000, "Lendário" },
	{ "imperatriz_de_porcelana", 21000, "Lendário" },
	{ "trono_de_raios", 26000, "Lendário" },
	{ "relicario_do_inverno", 33000, "Lendário" },
	{ "coracao_de_fenix", 42000, "Lendário" },
	{ "atlas_fragmentado", 51000, "Lendário" },
	{ "serpente_de_cristal", 60000, "Lendário" },
	{ "horizonte_rasgado", 70000, "Lendário" },
	{ "arauto_dos_mil_sinos", 80000, "Lendário" },
	{ "orquestra_das_estrelas", 90000, "Lendário" },
	{ "majestade_de_cobre", 99000, "Lendário" },
	{ "devorador_de_alvoradas", 130000, "Mítico" },
	{ "coroa_do_fim", 190000, "Mítico" },
	{ "oceano_sem_fundo", 260000, "Mítico" },
	{ "fio_das_parcas", 350000, "Mítico" },
	{ "leviata_astral", 480000, "Mítico" },
	{ "labirinto_vivo", 650000, "Mítico" },
	{ "eclipse_de_mil_olhos", 900000, "Mítico" },
	{ "alvorecer_dos_titas", 1200000, "Divino" },
	{ "divindade_do_prisma", 5000000, "Divino" },
	{ "ultimo_jardim", 20000000, "Divino" },
	{ "soberania_do_vazio", 100000000, "Divino" },
}

local Catalogo = {}
Catalogo.lista = {}
Catalogo.porId = {}
local soma = 0
for i = 2, #DEFINICOES do
	soma += 1 / DEFINICOES[i][2]
end
assert(soma > 0 and soma < 1, "chances explicitas invalidas")
Catalogo.PROBABILIDADE_RESERVA = 1 - soma
for i, d in DEFINICOES do
	local reserva = i == 1
	local pBase = if reserva then Catalogo.PROBABILIDADE_RESERVA else 1 / d[2]
	local aura = { id = d[1], chance = 1 / pBase, tierNome = d[3], pBase = pBase, reserva = reserva }
	table.insert(Catalogo.lista, aura)
	Catalogo.porId[aura.id] = aura
end
Probabilidades.validarCatalogo(Catalogo.lista)
return Catalogo
