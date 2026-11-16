-- Catálogo de auras do Despertar e lógica pura do sorteio (testada em testes/logica.luau).
-- Este módulo não usa APIs do Roblox (cores ficam em hex) para rodar também no luau puro.
--
-- Sorteio "do mais raro para o mais comum": para cada aura, da mais rara à mais comum,
-- tenta acertar 1 em N; a primeira que acertar é a sorteada. Se nenhuma acertar, sai a mais comum.
-- Assim as auras raras saem quase exatamente "1 em N"; as comuns saem um pouco menos que o nominal
-- (veja Auras.probabilidadeReal).
local Auras = {}

export type Aura = {
	id: string,
	nome: string,
	chance: number, -- "1 em chance"
	cores: { string }, -- { principal, secundária } em hex
	estilo: string, -- "brilho" | "chama" | "nevoa"
	tier: number, -- índice em Auras.Tiers
	ordem: number, -- posição no catálogo (1 = mais comum)
}

export type Tier = { nome: string, minimo: number, cor: string }

-- Faixas de raridade pela chance mínima ("1 em minimo")
Auras.Tiers = {
	{ nome = "Comum", minimo = 1, cor = "B8C1CC" },
	{ nome = "Incomum", minimo = 10, cor = "5BE37D" },
	{ nome = "Raro", minimo = 100, cor = "4CC9F0" },
	{ nome = "Épico", minimo = 1000, cor = "A855F7" },
	{ nome = "Lendário", minimo = 10000, cor = "FFC83D" },
	{ nome = "Mítico", minimo = 100000, cor = "FF3B6B" },
	{ nome = "Divino", minimo = 1000000, cor = "FFFFFF" },
} :: { Tier }

-- Auras raras a partir desta chance geram anúncio para o servidor inteiro
Auras.ANUNCIO_MINIMO = 1000

-- Nomes originais (sem referência a obras existentes). Ordem: mais comum -> mais rara.
local DEFINICOES = {
	{ "faisca", "Faísca", 2, "FFF1A8", "FFB13D", "brilho" },
	{ "nevoa", "Névoa", 3, "DDE6F0", "9AA8B8", "nevoa" },
	{ "brasa", "Brasa", 4, "FF9A4D", "D9480F", "chama" },
	{ "orvalho", "Orvalho", 5, "B8F2FF", "4CC9F0", "brilho" },
	{ "folha_dancante", "Folha Dançante", 8, "B6F27A", "3FA34D", "nevoa" },
	{ "pedra_viva", "Pedra Viva", 10, "D8C3A5", "8D6E4C", "nevoa" },
	{ "mare_calma", "Maré Calma", 16, "7FD8FF", "1E6FD9", "nevoa" },
	{ "brasa_sussurrante", "Brasa Sussurrante", 25, "FFC46B", "FF5A1F", "chama" },
	{ "vento_cortante", "Vento Cortante", 40, "E8FFF6", "6FE3C1", "brilho" },
	{ "raiz_antiga", "Raiz Antiga", 50, "C9E39A", "5C7A2E", "nevoa" },
	{ "gelo_fino", "Gelo Fino", 75, "E6FBFF", "7CC4FF", "brilho" },
	{ "trovao_jovem", "Trovão Jovem", 100, "FFF6A0", "F5C400", "brilho" },
	{ "lotus_rubra", "Lótus Rubra", 150, "FF9EC1", "E0245E", "brilho" },
	{ "pluma_celeste", "Pluma Celeste", 250, "FFFFFF", "9FD3FF", "nevoa" },
	{ "chama_azul", "Chama Azul", 400, "9EE7FF", "1F6BFF", "chama" },
	{ "eco_do_vazio", "Eco do Vazio", 500, "B79CFF", "2A0E5C", "nevoa" },
	{ "cristal_lunar", "Cristal Lunar", 750, "F0F4FF", "A3B4FF", "brilho" },
	{ "tempestade_rubra", "Tempestade Rubra", 1000, "FF7A7A", "B3001B", "chama" },
	{ "sombra_gemea", "Sombra Gêmea", 1500, "8A7FA8", "1A1026", "nevoa" },
	{ "sol_nascente", "Sol Nascente", 2500, "FFE7A3", "FF7A00", "chama" },
	{ "dragao_de_jade", "Dragão de Jade", 5000, "A8FFCF", "00A86B", "chama" },
	{ "aurora_boreal", "Aurora Boreal", 7500, "7CFFCB", "8B5CF6", "nevoa" },
	{ "coracao_estelar", "Coração Estelar", 10000, "FFF3B0", "FF5FA2", "brilho" },
	{ "lamina_do_crepusculo", "Lâmina do Crepúsculo", 25000, "FFB38A", "6A1B9A", "brilho" },
	{ "lotus_celestial", "Lótus Celestial", 50000, "FFFFFF", "FFB3E6", "brilho" },
	{ "fenix_eterna", "Fênix Eterna", 100000, "FFE066", "FF3D00", "chama" },
	{ "eclipse_carmesim", "Eclipse Carmesim", 250000, "FF2E4D", "120008", "chama" },
	{ "olho_do_abismo", "Olho do Abismo", 500000, "7DF9FF", "05001A", "nevoa" },
	{ "nebulosa_primordial", "Nebulosa Primordial", 750000, "FF8AF0", "3A0CA3", "nevoa" },
	{ "despertar_absoluto", "Despertar Absoluto", 1000000, "FFFFFF", "FFD700", "brilho" },
}

function Auras.tierDe(chance: number): number
	local resultado = 1
	for i, t in Auras.Tiers do
		if chance >= t.minimo then
			resultado = i
		end
	end
	return resultado
end

Auras.lista = {} :: { Aura }
Auras.porId = {} :: { [string]: Aura }

for i, d in DEFINICOES do
	local aura: Aura = {
		id = d[1],
		nome = d[2],
		chance = d[3],
		cores = { d[4], d[5] },
		estilo = d[6],
		tier = Auras.tierDe(d[3]),
		ordem = i,
	}
	table.insert(Auras.lista, aura)
	Auras.porId[aura.id] = aura
end

-- Sorteia uma aura. aleatorio() devolve um número em [0, 1). sorte multiplica as chances (1 = normal).
function Auras.sortear(aleatorio: () -> number, sorte: number?): Aura
	local s = math.max(1, sorte or 1)
	for i = #Auras.lista, 2, -1 do
		local aura = Auras.lista[i]
		if aleatorio() < s / aura.chance then
			return aura
		end
	end
	return Auras.lista[1]
end

-- Probabilidade real de sair cada aura com o método acima (sorte normal)
function Auras.probabilidadeReal(id: string): number
	local naoSaiu = 1
	for i = #Auras.lista, 1, -1 do
		local aura = Auras.lista[i]
		local p = if i == 1 then 1 else 1 / aura.chance
		if aura.id == id then
			return naoSaiu * p
		end
		naoSaiu *= 1 - p
	end
	return 0
end

-- A aura mais rara de uma coleção { [id] = quantidade }
function Auras.melhorDe(colecao: { [string]: number }): Aura?
	local melhor: Aura? = nil
	for id, qtd in colecao do
		local aura = Auras.porId[id]
		if aura and qtd > 0 and (melhor == nil or aura.chance > melhor.chance) then
			melhor = aura
		end
	end
	return melhor
end

-- Quantas auras diferentes do catálogo a coleção tem
function Auras.contarDescobertas(colecao: { [string]: number }): number
	local n = 0
	for id, qtd in colecao do
		if Auras.porId[id] and qtd > 0 then
			n += 1
		end
	end
	return n
end

return Auras
