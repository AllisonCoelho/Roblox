local total, falhas = 0, 0
local function igual(nome, obtido, esperado)
	total += 1
	if obtido ~= esperado then
		falhas += 1
		print(string.format("FALHOU %s: %s != %s", nome, tostring(obtido), tostring(esperado)))
	end
end

local Formato = req("Formato")
igual("inteiro", Formato.inteiro(12450), "12.450")
igual("negativo", Formato.inteiro(-1500), "-1.500")
igual("abreviado", Formato.curto(15000), "15 mil")
igual("tempo", Formato.tempo(42), "0:42")

-- Catálogo das 67 auras originais (separado do sorteio em uso)
do
	local V2 = req("AurasOriginaisV2")
	local AurasAtuais = req("Auras")
	igual("v2: 67 auras", #V2.lista, 67)
	local ids, contagem, colide = 0, {}, 0
	for i, a in V2.lista do
		igual("v2: numeração " .. a.id, a.numero, i)
		if V2.porId[a.id] == a then
			ids += 1
		end
		contagem[a.tier] = (contagem[a.tier] or 0) + 1
		if AurasAtuais.porId[a.id] then
			colide += 1
		end
		local tier = AurasAtuais.Tiers[AurasAtuais.tierDe(math.floor(a.chance))].nome
		igual("v2: raridade bate com a chance " .. a.id, a.tier, tier)
		if i > 1 then
			igual("v2: ordem crescente " .. a.id, a.chance > V2.lista[i - 1].chance, true)
		end
	end
	igual("v2: ids únicos", ids, 67)
	igual("v2: nenhum id igual ao catálogo atual", colide, 0)
	for tier, n in
		{
			Comum = 4,
			Incomum = 10,
			Raro = 15,
			["Épico"] = 15,
			["Lendário"] = 12,
			["Mítico"] = 7,
			Divino = 4,
		}
	do
		igual("v2: quantidade " .. tier, contagem[tier], n)
	end
	igual("v2: soma das explícitas", math.abs(V2.SOMA_EXPLICITAS - 0.823367) < 1e-6, true)
	igual("v2: reserva ~1 em 5,66", math.floor(V2.porId.centelha_do_nexo.chance * 100), 566)
	local total = 0
	for _, a in V2.lista do
		total += 1 / a.chance
	end
	igual("v2: probabilidades somam 100%", math.abs(total - 1) < 1e-9, true)
	igual("v2: lote inicial existe", #V2.LOTE_INICIAL, 7)
	for _, id in V2.LOTE_INICIAL do
		igual("v2: lote " .. id, V2.porId[id] ~= nil, true)
	end
end

local Perfil = req("Perfil")
local p = Perfil.padrao()
igual("versao", p.versao, 1)
igual("giros iniciais", p.giros, 0)
igual("colecao vazia", next(p.auras), nil)
igual("equipada vazia", p.equipada, nil)
igual("auto desligado", p.configuracoes.giroAutomatico, false)
igual("perfis independentes", Perfil.padrao().auras ~= Perfil.padrao().auras, true)

local salvarReal = Perfil.padrao()
salvarReal.auras.faisca = 3
salvarReal.progressoExtra = { andares = { 1 } }
local perfilTeste = Perfil.copiar(salvarReal)
Perfil.registrarGiro(perfilTeste, "faisca")
perfilTeste.configuracoes.animacoes = false
perfilTeste.progressoExtra.andares[1] = 5
igual("cópia preserva as auras reais", salvarReal.auras.faisca, 3)
igual("cópia preserva os giros reais", salvarReal.giros, 0)
igual("cópia preserva as configurações reais", salvarReal.configuracoes.animacoes, true)
igual("cópia isola dados aninhados", salvarReal.progressoExtra.andares[1], 1)
perfilTeste.incursoes.fragmentos = 800
perfilTeste.incursoes.concluidas.cinzas = 1
igual("cópia isola saldo de fragmentos", salvarReal.incursoes.fragmentos, 0)
igual("cópia isola vitórias das incursões", salvarReal.incursoes.concluidas.cinzas, nil)

local Dev = req("PermissaoDev")
local universoTeste, lugarTeste = 10771776655, 112360499723635
igual("dev dono do teste privado", Dev.autoriza(universoTeste, lugarTeste, false, 42, 42), true)
igual(
	"dev visitante do teste privado",
	Dev.autoriza(universoTeste, lugarTeste, false, 42, 43),
	false
)
igual("dev rejeita outro lugar", Dev.autoriza(universoTeste, 730, false, 42, 42), false)
igual("dev rejeita outro universo", Dev.autoriza(730, lugarTeste, true, 42, 42), false)
igual(
	"dev rejeita identidade ausente",
	Dev.autoriza(universoTeste, lugarTeste, false, nil, 42),
	false
)
igual(
	"dev rejeita ID de simulação publicado",
	Dev.autoriza(universoTeste, lugarTeste, false, 42, -1),
	false
)
igual("dev primeiro cliente do Studio", Dev.autoriza(0, 0, true, nil, -1), true)
igual("dev segundo cliente do Studio", Dev.autoriza(0, 0, true, nil, -2), false)
igual("dev IDs vazios fora do Studio", Dev.autoriza(0, 0, false, nil, 42), false)
igual(
	"dev conta designada no Roblox Player",
	Dev.autoriza(universoTeste, lugarTeste, false, 42, 43, 43),
	true
)
igual(
	"dev visitante com conta designada cadastrada",
	Dev.autoriza(universoTeste, lugarTeste, false, 42, 44, 43),
	false
)
igual(
	"dev conta designada em outro lugar",
	Dev.autoriza(universoTeste, 730, false, 42, 43, 43),
	false
)

local Sessao = req("Sessao")
local t = 1000
local r = Sessao.travar(nil, "A", t)
igual("trava A", r and r.sessao.jobId, "A")
igual("B bloqueado", (Sessao.travar(r, "B", t + 1)), nil)
local salvo = Sessao.salvar(r, "A", t + 2, { giros = 5 }, false)
igual("save A", salvo and salvo.dados.giros, 5)
local liberado = Sessao.salvar(salvo, "A", t + 3, { giros = 6 }, true)
igual("liberado", liberado and liberado.sessao, nil)
local novo = Sessao.travar(liberado, "B", t + 4)
igual("trava B", novo and novo.sessao.jobId, "B")
igual("dados B", novo and novo.dados.giros, 6)
igual("save A recusado", (Sessao.salvar(novo, "A", t + 5, { giros = 0 }, false)), nil)

p = Perfil.padrao()
Perfil.registrarGiro(p, "faisca")
Perfil.registrarGiro(p, "faisca")
igual("giros contados", p.giros, 2)
igual("aura contada", p.auras.faisca, 2)
igual("possui", Perfil.possui(p, "faisca"), true)
igual("nao possui", Perfil.possui(p, "brasa"), false)

local Auras = req("Auras")
igual("30 auras", #Auras.lista, 30)
local ids, crescente = {}, true
for i, a in Auras.lista do
	igual("id unico " .. a.id, ids[a.id], nil)
	ids[a.id] = true
	if i > 1 and a.chance <= Auras.lista[i - 1].chance then
		crescente = false
	end
end
igual("chances crescentes", crescente, true)
igual("mais rara", Auras.lista[30].chance, 1000000)
igual("tier comum", Auras.porId.faisca.tier, 1)
igual("tier divino", Auras.porId.despertar_absoluto.tier, 7)
igual("tier epico", Auras.tierDe(1000), 4)
igual(
	"rng 0 = mais rara",
	Auras.sortear(function()
		return 0
	end).id,
	"despertar_absoluto"
)
igual(
	"rng alto = reserva",
	Auras.sortear(function()
		return 0.9999
	end).id,
	"faisca"
)

-- A chance exibida ("1 em N") é a probabilidade real de cada aura, inclusive a de reserva
local soma = 0
local todasExatas = true
for _, a in Auras.lista do
	local p = Auras.probabilidadeReal(a.id)
	soma += p
	if math.abs(p - 1 / a.chance) > 1e-12 then
		todasExatas = false
		print("chance divergente: " .. a.id)
	end
end
igual("probabilidades somam 1", math.abs(soma - 1) < 1e-9, true)
igual("chance exibida = chance real (todas)", todasExatas, true)
igual(
	"reserva continua a mais comum",
	Auras.probabilidadeReal("faisca") > Auras.probabilidadeReal("nevoa"),
	true
)

-- O texto mostrado ao jogador (Formato.chance) bate com a frequência efetiva do sorteio
local function lerTexto(texto: string): number
	return tonumber((texto:gsub("%.", ""):gsub(",", "."))) :: number
end
math.randomseed(42)
local N, contagem = 400000, {}
for _ = 1, N do
	local a = Auras.sortear(math.random)
	contagem[a.id] = (contagem[a.id] or 0) + 1
end
for _, id in { "faisca", "nevoa", "brasa", "pedra_viva", "trovao_jovem" } do
	local exibido = lerTexto(Formato.chance(Auras.porId[id].chance))
	local efetivo = N / (contagem[id] or 1)
	igual(
		"exibido x efetivo "
			.. id
			.. " (1 em "
			.. exibido
			.. " vs "
			.. string.format("%.2f", efetivo)
			.. ")",
		math.abs(efetivo - exibido) / exibido < 0.05,
		true
	)
end
igual("texto reserva", Formato.chance(Auras.porId.faisca.chance), "4,2")
igual("texto inteiro", Formato.chance(1000), "1.000")
igual("texto curto", Formato.chanceCurta(25000), "25 mil")
igual("texto curto pequeno", Formato.chanceCurta(4.26), "4,3")
igual(
	"melhor da colecao",
	Auras.melhorDe({ faisca = 3, chama_azul = 1, inexistente = 9 }).id,
	"chama_azul"
)
igual("colecao vazia sem melhor", Auras.melhorDe({}), nil)
igual("descobertas", Auras.contarDescobertas({ faisca = 1, brasa = 0, x = 2 }), 1)
-- Apresentação do giro: categorias pela chance real e durações dentro das faixas do design
local Apresentacao = req("Apresentacao")
igual("6 categorias", #Apresentacao.Categorias, 6)
igual("faisca = baixa", Apresentacao.de(Auras.porId.faisca.chance).id, "baixa")
igual("1 em 49 = baixa", Apresentacao.de(49).id, "baixa")
igual("1 em 50 = moderada", Apresentacao.de(50).id, "moderada")
igual("1 em 999 = moderada", Apresentacao.de(999).id, "moderada")
igual("1 em 1.000 = alta", Apresentacao.de(1000).id, "alta")
igual("1 em 10.000 = muito alta", Apresentacao.de(10000).id, "muito_alta")
igual("1 em 100.000 = extrema", Apresentacao.de(100000).id, "extrema")
igual("1 em 1.000.000 = absoluta", Apresentacao.de(1000000).id, "absoluta")
local faixas = { { 0.4, 0.6 }, { 0.8, 1.2 }, { 1.5, 2 }, { 2, 3 }, { 3, 4 }, { 4, 6 } }
local anterior = 0
for i, c in Apresentacao.Categorias do
	local d = Apresentacao.tempoAteRevelacao(c)
	igual("duracao " .. c.id .. " na faixa", d >= faixas[i][1] and d <= faixas[i][2], true)
	igual("duracao cresce " .. c.id, d > anterior, true)
	igual("silencio cabe na ruptura " .. c.id, c.silencio < c.ruptura, true)
	anterior = d
end
igual(
	"anuncio e versao alheia no mesmo limiar",
	Apresentacao.de(Auras.ANUNCIO_MINIMO).alheios,
	true
)
igual("comuns nao aparecem para os outros", Apresentacao.de(999).alheios, false)
igual("abreviada = baixa", Apresentacao.abreviada().id, "baixa")
local semCategoria = 0
for i = 1, #Apresentacao.Categorias do
	local tem = false
	for _, a in Auras.lista do
		if Apresentacao.indiceDe(a.chance) == i then
			tem = true
		end
	end
	if not tem then
		semCategoria += 1
	end
end
igual("toda categoria tem aura (teste visual)", semCategoria, 0)
igual("config nova tem padrao", Perfil.padrao().configuracoes.equiparAutomatico, false)
local faltando = 0
for chave in Perfil.CONFIGURACOES do
	if Perfil.padrao().configuracoes[chave] == nil then
		faltando += 1
	end
end
igual("toda configuracao tem padrao", faltando, 0)
-- Obter não força equipar
local pe = Perfil.padrao()
igual("colecao vazia no inicio", Perfil.colecaoVazia(pe), true)
igual("primeira aura equipa", Perfil.deveEquipar(pe, true, 5, nil), true)
Perfil.registrarGiro(pe, "nevoa")
igual("colecao com itens", Perfil.colecaoVazia(pe), false)
pe.equipada = nil -- jogador desequipou pelo índice
igual(
	"desequipada + auto desligado: nao equipa",
	Perfil.deveEquipar(pe, false, 1000000, nil),
	false
)
pe.equipada = "nevoa"
igual("auto desligado: mais rara nao troca", Perfil.deveEquipar(pe, false, 1000, 5), false)
pe.configuracoes.equiparAutomatico = true
igual("auto ligado: mais rara troca", Perfil.deveEquipar(pe, false, 1000, 5), true)
igual("auto ligado: mais comum nao troca", Perfil.deveEquipar(pe, false, 5, 1000), false)
igual("auto ligado: igual nao troca", Perfil.deveEquipar(pe, false, 5, 5), false)
igual("auto ligado e nada equipado: equipa", Perfil.deveEquipar(pe, false, 5, nil), true)
pe.auras = { nevoa = 0 }
igual("contagem zerada conta como vazia", Perfil.colecaoVazia(pe), true)
-- Trilhas de pose: o personagem rasga a fenda nas raridades altas e faz um gesto nas comuns
local Trilha = req("Trilha")
local tp = { t1 = 0.3, t2 = 1.5, t3 = 2.9, tEstouro = 3.4, t4 = 3.55, fim = 3.9 }
local rasgar = Trilha.rasgar(tp)
local function poseEm(tr, t)
	local de, para, peso = Trilha.avaliar(tr, t)
	return if peso >= 0.5 then para else de
end
igual("comeca neutra", poseEm(rasgar, 0), "neutra")
igual("alcanca no chamado", poseEm(rasgar, 0.29), "alcancar")
igual("agarra na ressonancia", poseEm(rasgar, 1.45), "agarrar")
igual("forca na instabilidade", poseEm(rasgar, 2.85), "forcar")
igual("segura ate a ruptura", poseEm(rasgar, 3.39), "forcar")
igual("rasga logo apos a ruptura", poseEm(rasgar, 3.53), "rasgar")
igual("volta ao neutro no fim", poseEm(rasgar, 3.9), "neutra")
igual("depois do fim continua neutra", poseEm(rasgar, 10), "neutra")
local ordenada = true
for i = 2, #rasgar do
	if rasgar[i].tempo < rasgar[i - 1].tempo then
		ordenada = false
	end
end
igual("trilha em ordem de tempo", ordenada, true)
local _, _, pesoMeio = Trilha.avaliar(rasgar, 0.15)
igual("peso suave no meio", math.abs(pesoMeio - 0.5) < 1e-9, true)
local curto = { t1 = 0.08, t2 = 0.35, t3 = 0.35, tEstouro = 0.43, t4 = 0.47, fim = 0.82 }
igual("comum usa gesto", poseEm(Trilha.gesto(curto, false), 0.3), "gesto")
igual("moderada usa duas maos", poseEm(Trilha.gesto(curto, true), 0.3), "gestoDuplo")
igual("comum solta no fim", poseEm(Trilha.gesto(curto, false), 0.465), "impulso")
igual("comum termina neutra", poseEm(Trilha.gesto(curto, false), 0.82), "neutra")
igual("fenda fechada antes da instabilidade", Trilha.aberturaFenda(tp, 1.0, 0, 0), 0)
igual("fenda e fresta na instabilidade", Trilha.aberturaFenda(tp, 2.5, 0.7, 0) < 0.3, true)
igual(
	"fenda cresce com a instabilidade",
	Trilha.aberturaFenda(tp, 2.8, 0.9, 0) > Trilha.aberturaFenda(tp, 2.0, 0.3, 0),
	true
)
igual("fenda toda aberta na ruptura", Trilha.aberturaFenda(tp, 3.54, 1, 0) > 0.99, true)
igual("fenda fecha no fim", Trilha.aberturaFenda(tp, 3.9, 1, 0), 0)
igual("animacoes ligadas por padrao", Perfil.padrao().configuracoes.animacoes, true)
-- Fenda guiada pelas mãos
igual(
	"bordas entre as maos",
	Trilha.meiaLarguraPelasMaos(tp, 2.5, 2.4, 0.2),
	1.2 * Trilha.FOLGA_MAOS
)
igual(
	"abre junto com os bracos",
	Trilha.meiaLarguraPelasMaos(tp, 3.5, 6, 1) > Trilha.meiaLarguraPelasMaos(tp, 2.5, 2.4, 0.2),
	true
)
igual("fecha depois da revelacao", Trilha.meiaLarguraPelasMaos(tp, 3.9, 6, 0), 0)
igual(
	"meio fechada no retorno",
	Trilha.meiaLarguraPelasMaos(tp, 3.7, 4, 0.5),
	2 * Trilha.FOLGA_MAOS * 0.5
)
-- Incursões
local Inc = req("Incursoes")
local pi = Perfil.padrao().incursoes
igual("inc fragmentos iniciais", pi.fragmentos, 0)
igual("inc cinzas aberto", Inc.liberado(pi, "cinzas"), true)
igual("inc mare fechado", Inc.liberado(pi, "mare"), false)
igual("inc universo invalido", Inc.liberado(pi, "nada"), false)
pi.concluidas.cinzas = 1
igual("inc mare aberto depois de cinzas", Inc.liberado(pi, "mare"), true)
igual("inc umbral ainda fechado", Inc.liberado(pi, "umbral"), false)
igual("inc nivel inicial", Inc.nivel(pi, "pulso"), 0)
igual("inc custo nivel 1", Inc.custo(pi, "pulso"), 25)
pi.reliquias.alcance = 3
igual("inc custo no maximo", Inc.custo(pi, "alcance"), nil)
igual("inc custo reliquia invalida", Inc.custo(pi, "nada"), nil)
igual("inc ressonancia minima", Inc.ressonancia(nil), 1)
igual("inc ressonancia 1 milhao", math.floor(Inc.ressonancia(1000000) * 100 + 0.5), 136)
igual("inc ressonancia cresce", Inc.ressonancia(1000) > Inc.ressonancia(10), true)
pi.reliquias.pulso = 2
igual(
	"inc dano com reliquia",
	math.floor(Inc.danoPulso(pi, 1) * 100 + 0.5),
	math.floor(22 * 1.24 * 100 + 0.5)
)
igual(
	"inc raio com reliquia",
	math.floor(Inc.raioPulso(pi) * 100 + 0.5),
	math.floor(14 * 1.24 * 100 + 0.5)
)
igual("inc vida base", Inc.vidaMax(Inc.padrao()), 100)
igual("inc grupo 1", Inc.bonusGrupo(1), 1)
igual("inc grupo 0", Inc.bonusGrupo(0), 0)
igual("inc grupo cresce", Inc.bonusGrupo(4) > Inc.bonusGrupo(2), true)
local a1, a5 = Inc.andar("cinzas", 1, 1), Inc.andar("cinzas", 5, 1)
igual("inc andar 1 tem nucleos", a1.nucleos > 0, true)
igual("inc andar 1 sem guardiao", a1.guardiao, false)
igual("inc andar 5 guardiao", a5.guardiao, true)
igual("inc andar 5 sem nucleos", a5.nucleos, 0)
igual(
	"inc grupo maior mais sombras",
	Inc.andar("cinzas", 2, 4).sombras > Inc.andar("cinzas", 2, 1).sombras,
	true
)
igual(
	"inc universo mais dificil",
	Inc.andar("umbral", 2, 1).vidaSombra > Inc.andar("cinzas", 2, 1).vidaSombra,
	true
)
igual("inc vidas", Inc.vidas(2), 5)
igual("inc recompensa 0 andares", Inc.recompensa("cinzas", 0, false, false), 0)
igual("inc recompensa 2 andares", Inc.recompensa("cinzas", 2, false, false), 6 + 8)
igual(
	"inc vitoria vale mais",
	Inc.recompensa("cinzas", 5, true, true) > Inc.recompensa("cinzas", 5, true, false),
	true
)
igual(
	"inc andares limitados",
	Inc.recompensa("cinzas", 99, false, false),
	Inc.recompensa("cinzas", 5, false, false)
)
igual("inc 3 universos", #Inc.UNIVERSOS, 3)

print(string.format("%d testes, %d falhas", total, falhas))
