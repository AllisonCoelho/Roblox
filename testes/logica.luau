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

-- Combate das Incursões (fase 1)
do
	local C = req("Combate")
	local V3 = Vector3
	for _, nome in { "generico", "gear5" } do
		local kit = C.KITS[nome]
		for _, id in C.TECNICAS do
			igual("combate: " .. nome .. " tem " .. id, kit.tecnicas[id] ~= nil, true)
		end
		igual("combate: combo de 3 " .. nome, #kit.combo, 3)
	end
	igual("combate: kit padrão", C.kitDe(nil).id, "generico")
	igual("combate: kit da gear 5", C.kitDe("gear5").id, "gear5")
	igual("combate: monarca usa o genérico por enquanto", C.kitDe("monarca").id, "generico")
	igual(
		"combate: braço da gear 5 alcança mais",
		C.KITS.gear5.tecnicas.golpe.alcance > C.KITS.generico.tecnicas.golpe.alcance,
		true
	)
	igual(
		"combate: gatling acerta várias vezes",
		(C.KITS.gear5.tecnicas.tecnica2.acertos or 1) > 1,
		true
	)
	igual("combate: dano base", C.dano(10, 1), 10)
	igual("combate: ressonância tem teto", C.dano(10, 99), 16)
	igual("combate: ressonância nunca diminui", C.dano(10, 0.2), 10)
	igual("combate: crítico", C.dano(10, 1, 1, true), 15)
	igual("combate: esquiva anula", C.danoRecebido(20, C.KITS.generico, false, true, true), 0)
	igual(
		"combate: guarda de frente reduz",
		math.floor(C.danoRecebido(20, C.KITS.generico, true, true, false) + 0.5),
		6
	)
	igual(
		"combate: guarda de costas não vale",
		C.danoRecebido(20, C.KITS.generico, true, false, false),
		20
	)
	local o, f = V3.new(0, 0, 0), V3.new(0, 0, -1)
	local golpe = C.KITS.generico.tecnicas.golpe
	igual("acerto: cone na frente", C.acerta(golpe, o, f, V3.new(0, 0, -6), 1), true)
	igual("acerto: cone atrás erra", C.acerta(golpe, o, f, V3.new(0, 0, 6), 1), false)
	igual("acerto: cone longe erra", C.acerta(golpe, o, f, V3.new(0, 0, -20), 1), false)
	local linha = C.KITS.gear5.tecnicas.tecnica1
	igual("acerto: linha longa", C.acerta(linha, o, f, V3.new(1, 0, -38), 1), true)
	igual("acerto: linha de lado erra", C.acerta(linha, o, f, V3.new(10, 0, -20), 1), false)
	igual(
		"acerto: área em volta",
		C.acerta(C.KITS.gear5.tecnicas.despertar, o, f, V3.new(0, 0, 20), 1),
		true
	)
	igual("guarda: de frente", C.deFrente(o, f, V3.new(0.5, 0, -5)), true)
	igual("guarda: pelas costas", C.deFrente(o, f, V3.new(0, 0, 5)), false)
end

-- Incursões 2.0: andares variados, inimigos, Bênçãos e nota
do
	local R = req("IncursoesRun")
	local semente = 0
	local function aleatorio()
		semente = (semente * 1103515245 + 12345) % 2147483648
		return semente / 2147483648
	end
	for rodada = 1, 50 do
		local andares = R.sortearAndares(5, aleatorio)
		igual("run: 5 andares", #andares, 5)
		igual("run: último é o Guardião", andares[5], "guardiao")
		igual("run: 1º andar nunca é Cofre", andares[1] ~= "cofre" and andares[1] ~= "caca", true)
		for n = 2, 4 do
			if andares[n] == andares[n - 1] then
				igual("run: não repete em seguida (rodada " .. rodada .. ")", false, true)
			end
		end
	end
	for _ = 1, 30 do
		igual(
			"run: andar 1 só Sombra/Corredor",
			({ sombra = true, corredor = true })[R.sortearArquetipo(1, aleatorio)],
			true
		)
		local afixos = R.sortearAfixos(3, aleatorio)
		igual("run: 2 afixos no andar 3", #afixos, 2)
		igual("run: afixos diferentes", afixos[1] ~= afixos[2], true)
	end
	local tem = {}
	for _ = 1, #R.BENCAOS do
		local ofertas = R.ofertas(tem, aleatorio, 1)
		igual("run: sempre há oferta enquanto sobra Bênção", #ofertas, 1)
		tem[ofertas[1]] = true
	end
	igual("run: sem repetição de Bênção", #R.ofertas(tem, aleatorio), 0)
	local tres = R.ofertas({}, aleatorio)
	igual("run: 3 ofertas", #tres, 3)
	igual(
		"run: ofertas distintas",
		tres[1] ~= tres[2] and tres[2] ~= tres[3] and tres[1] ~= tres[3],
		true
	)
	local m = R.modificadores({ furia = true, ganancia = true, vigor = true })
	igual("run: dano somado", m.dano, 0.2)
	igual("run: vida soma vigor e ganância", math.floor(m.vidaMax * 100 + 0.5), 15)
	igual("run: nota S", R.nota("purificacao", 60, 0), "S")
	igual("run: nota A com uma queda", R.nota("purificacao", 60, 1), "A")
	igual("run: nota B lenta", R.nota("purificacao", 400, 0), "B")
	igual("run: Horda só conta quedas", R.nota("horda", 999, 0), "S")
	igual(
		"run: nota S paga mais",
		R.MULT_NOTA.S > R.MULT_NOTA.A and R.MULT_NOTA.A > R.MULT_NOTA.B,
		true
	)
	-- Fase B: preparo (Marcas e Pesadelo) vindo do cliente é sempre validado
	local vazio = R.preparo(nil)
	igual("preparo: padrão sem Pesadelo", vazio.pesadelo, false)
	igual("preparo: padrão normal", R.descreverPreparo(vazio), "Normal")
	igual("preparo: padrão x1", R.multPreparo(vazio), 1)
	local lixo =
		R.preparo({ pesadelo = "sim", marcas = { inventada = true, densas = 1, vidro = true } })
	igual("preparo: pesadelo só com true", lixo.pesadelo, false)
	igual("preparo: ignora marca inventada", lixo.marcas.inventada, nil)
	igual("preparo: ignora valor não booleano", lixo.marcas.densas, nil)
	igual("preparo: aceita marca válida", lixo.marcas.vidro, true)
	local tudo = R.preparo({ pesadelo = true, marcas = { densas = true, semVidas = true } })
	igual(
		"preparo: pesadelo dobra e marcas somam",
		math.floor(R.multPreparo(tudo) * 100 + 0.5),
		350
	)
	igual(
		"preparo: descrição",
		R.descreverPreparo(tudo),
		"PESADELO · Hordas Densas · Sem Reviver"
	)
	igual("guardião: fases em ordem", R.FASES_GUARDIAO[1] > R.FASES_GUARDIAO[2], true)
end

-- Incursões fase C: Fenda do Dia, desafios semanais, reviver
do
	local D = req("IncursoesDesafios")
	local R = req("IncursoesRun")
	local t = 1763337600 -- 17/11/2025 00:00 UTC (segunda-feira)
	igual("diaria: mesmo dia, mesmo número", D.dia(t), D.dia(t + 86399))
	igual("diaria: dia seguinte muda", D.dia(t + 86400), D.dia(t) + 1)
	igual("semana: segunda a domingo iguais", D.semana(t), D.semana(t + 6 * 86400 + 86399))
	igual("semana: próxima segunda muda", D.semana(t + 7 * 86400), D.semana(t) + 1)
	local a, b = D.fendaDoDia(D.dia(t)), D.fendaDoDia(D.dia(t))
	igual("diaria: determinística (universo)", a.universo, b.universo)
	igual("diaria: determinística (semente)", a.semente, b.semente)
	local n = 0
	for id in a.marcas do
		n += 1
		igual("diaria: marca válida " .. id, R.marcaPorId[id] ~= nil, true)
		igual("diaria: nunca Sem Reviver", id ~= "semVidas", true)
	end
	igual("diaria: 2 marcas", n, 2)
	local x, y = D.gerador(5), D.gerador(5)
	igual("diaria: gerador repetível", x(), y())
	local s1 = R.sortearAndares(5, D.gerador(a.semente))
	local s2 = R.sortearAndares(5, D.gerador(a.semente))
	igual("diaria: mesmos andares para todos", table.concat(s1, ","), table.concat(s2, ","))
	igual(
		"diaria: vitória vale mais",
		D.pontuacao(5, true, 2, 50, 600) > D.pontuacao(5, false, 2, 50, 600),
		true
	)
	igual("diaria: pontuação nunca negativa", D.pontuacao(0, false, 0, 0, 99999) >= 0, true)
	igual("diaria: recompensa por nível", D.recompensaDia(2), 240)
	local semana = D.semana(t)
	local tres = D.desafiosDaSemana(semana)
	igual("semana: 3 desafios", #tres, 3)
	igual(
		"semana: distintos",
		tres[1] ~= tres[2] and tres[2] ~= tres[3] and tres[1] ~= tres[3],
		true
	)
	local st = D.semanaDe({}, semana)
	local alvo = D.desafioPorId[tres[1]]
	igual(
		"semana: progresso parcial sem prêmio",
		D.progredir(st, semana, alvo.id, alvo.meta - 1, alvo.id == "sequencia"),
		0
	)
	igual(
		"semana: completar dá prêmio",
		D.progredir(st, semana, alvo.id, alvo.meta, alvo.id == "sequencia"),
		alvo.recompensa
	)
	igual("semana: não paga duas vezes", D.progredir(st, semana, alvo.id, 999, false), 0)
	local fora
	for _, d in D.DESAFIOS do
		if not table.find(tres, d.id) then
			fora = d.id
			break
		end
	end
	igual(
		"semana: desafio de outra semana não conta",
		D.progredir(st, semana, fora, 9999, false),
		0
	)
	igual("semana: semana nova zera", next(D.semanaDe({ semana = st }, semana + 1).progresso), nil)
	igual("reviver: tempos coerentes", D.REVIVER_TEMPO < D.ABATIDO_ESPERA, true)
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

-- Matematica do RNG, limite seguro de sorte e nova tabela de 67 originais.
local Probabilidades = req("Probabilidades")
local C67 = req("Catalogo67Probabilidades")
igual("catalogo 67 entradas", #C67.lista, 67)
igual("Musgo alterado para 1 em 6", C67.porId.musgo_luminoso.chance, 6)
igual(
	"Centelha mais comum",
	C67.porId.centelha_do_nexo.pBase > C67.porId.musgo_luminoso.pBase,
	true
)
igual("Centelha 20.9966%", math.abs(C67.PROBABILIDADE_RESERVA - 0.2099662279261313) < 1e-12, true)
igual("sorte NaN segura", Probabilidades.sorteValida(0 / 0), 1)
igual("sorte infinito segura", Probabilidades.sorteValida(math.huge), 1)
igual("sorte negativa segura", Probabilidades.sorteValida(-1), 1)
igual("limite superior de sorte 3", Probabilidades.sorteValida(10), 3)
igual("transcendencia 0", Probabilidades.sorteTranscendencia(0), 1)
igual("transcendencia X", Probabilidades.sorteTranscendencia(10), 1.5)
igual("transcendencia maior que X", Probabilidades.sorteTranscendencia(20), 1.5)
igual("perfil sem nivel segue sorte 1", Auras.sorteTranscendencia(nil), 1)
local anteriorCoroa = 0
local anteriorDivino = 0
for nivel = 0, 10 do
	local sorte = Probabilidades.sorteTranscendencia(nivel)
	local pesos, z = Probabilidades.distribuicao(C67.lista, sorte)
	local somaEfetiva = 0
	for _, peso in pesos do
		somaEfetiva += peso / z
	end
	igual("67 total no nivel " .. nivel, math.abs(somaEfetiva - 1) < 1e-10, true)
	local coroa = Probabilidades.chanceEfetiva(C67.lista, "coroa_de_coral", sorte)
	local divino = Probabilidades.chanceEfetiva(C67.lista, "soberania_do_vazio", sorte)
	igual("67 Coroa cresce nivel " .. nivel, coroa >= anteriorCoroa, true)
	igual("67 Soberania cresce nivel " .. nivel, divino >= anteriorDivino, true)
	anteriorCoroa = coroa
	anteriorDivino = divino
end
igual(
	"67 Centelha no nivel X",
	math.abs(Probabilidades.chanceEfetiva(C67.lista, "centelha_do_nexo", 1.5) - 0.19779318528564926)
		< 1e-11,
	true
)
igual(
	"67 Musgo no nivel X",
	math.abs(Probabilidades.chanceEfetiva(C67.lista, "musgo_luminoso", 1.5) - 0.15700396776446937)
		< 1e-11,
	true
)
igual(
	"67 Soberania no nivel X",
	math.abs(
		Probabilidades.chanceEfetiva(C67.lista, "soberania_do_vazio", 1.5) - 1.954457110930131e-8
	) < 1e-16,
	true
)
local pesos3, z3 = Probabilidades.distribuicao(C67.lista, 3)
local soma3 = 0
for _, peso in pesos3 do
	soma3 += peso / z3
end
igual("67 sorte 3 segue 100%", math.abs(soma3 - 1) < 1e-10, true)
igual(
	"67 RNG zero = divino",
	Probabilidades.sortear(C67.lista, 1.5, function()
		return 0
	end).id,
	"soberania_do_vazio"
)
igual(
	"67 RNG alto = Centelha",
	Probabilidades.sortear(C67.lista, 1.5, function()
		return 0.999999
	end).id,
	"centelha_do_nexo"
)
igual("67 aura inexistente", Probabilidades.chanceEfetiva(C67.lista, "desconhecida", 1.5), 0)
local somaAtual3 = 0
for _, aura in Auras.lista do
	somaAtual3 += Auras.probabilidadeReal(aura.id, 3)
end
igual("catalogo atual em 3x soma 100%", math.abs(somaAtual3 - 1) < 1e-10, true)
igual(
	"catalogo atual aumenta chance divina",
	Auras.probabilidadeReal("despertar_absoluto", 1.5)
		> Auras.probabilidadeReal("despertar_absoluto"),
	true
)

local Itens = req("Itens")
local estoque = Itens.sanitizar({
	estilhaco_bruto = 1000005,
	cinza_persistente = 0 / 0,
	sal_mare_morta = math.huge,
	po_umbral = -8,
	lasca_estavel = 2.5,
	brasa_arauto = 4,
	faisca = 4,
})
igual("estoque respeita limite", estoque.estilhaco_bruto, 999999)
igual("estoque preserva saldo válido", estoque.brasa_arauto, 4)
for _, id in { "cinza_persistente", "sal_mare_morta", "po_umbral", "lasca_estavel", "faisca" } do
	igual("estoque rejeita " .. id, estoque[id], nil)
end
igual(
	"save antigo sem inventário recebe estado vazio",
	next(Itens.normalizarInventario(nil).itens),
	nil
)
igual("preencher inventário antigo preserva fragmentos", salvarReal.incursoes.fragmentos, 0)
igual(
	"normaliza slot sem posse",
	Itens.normalizarInventario({ equipados = { artefato = "emblema_guardiao" } }).equipados.artefato,
	nil
)
igual(
	"inventários novos independentes",
	Perfil.padrao().inventario.itens ~= Perfil.padrao().inventario.itens,
	true
)
igual("pilha cheia não credita", Itens.conceder(estoque, "estilhaco_bruto", 10), 0)
igual("crédito aceita item", Itens.conceder(estoque, "po_umbral", 1), 1)
igual("crédito rejeita id da aura", Itens.conceder(estoque, "faisca", 1), 0)
igual("crédito rejeita quantidade inválida", Itens.conceder(estoque, "po_umbral", -1), 0)
igual("consumo insuficiente", Itens.consumir(estoque, "po_umbral", 2), false)
igual(
	"consumo remove pilha vazia",
	Itens.consumir(estoque, "po_umbral", 1) and estoque.po_umbral,
	nil
)
local totalItens = 0
for id, item in Itens.porId do
	totalItens += 1
	igual("id do item " .. id, item.id, id)
	igual("raridade do item " .. id, Itens.Tiers[item.raridade] ~= nil, true)
end
igual("catálogo inicial de itens", totalItens, 16)

local Loot = req("LootIncursoes")
local membroA, membroB = Loot.novo(), Loot.novo()
local function semBonus()
	return 1
end
local materiaisA, materiaisB = {}, {}
for andar = 1, 5 do
	igual(
		"credita andar " .. andar,
		Loot.creditar(membroA, materiaisA, "cinzas", andar, semBonus) ~= nil,
		true
	)
	igual(
		"não repete andar " .. andar,
		Loot.creditar(membroA, materiaisA, "cinzas", andar, semBonus),
		nil
	)
end
igual(
	"progresso de cada membro é isolado",
	Loot.creditar(membroB, materiaisB, "cinzas", 1, semBonus).estilhaco_bruto,
	3
)
igual("primeira incursão rende estilhaços suficientes", materiaisA.estilhaco_bruto, 15)
igual("lascas garantidas", materiaisA.lasca_estavel, 2)
igual("selo garantido por marco", materiaisA.selo_purificacao, 1)
igual("marca de Guardião garantida", materiaisA.brasa_arauto, 1)
igual(
	"bônus épico separado",
	Loot.creditar(Loot.novo(), {}, "cinzas", 5, function()
		return 0
	end).coracao_fenda,
	1
)
igual(
	"outro bioma entrega material de Maré",
	Loot.creditar(Loot.novo(), {}, "mare", 1, semBonus).sal_mare_morta,
	1
)
igual(
	"outro Guardião entrega marca de Umbral",
	Loot.creditar(Loot.novo(), {}, "umbral", 5, semBonus).veu_ocaso,
	1
)
igual(
	"andar inválido não é premiado",
	Loot.creditar(Loot.novo(), {}, "cinzas", 6, semBonus),
	nil
)
igual(
	"universo inválido não é premiado",
	Loot.creditar(Loot.novo(), {}, "arena", 1, semBonus),
	nil
)
igual("membros não compartilham estoque", materiaisB.estilhaco_bruto, 3)

local Receitas = req("Receitas")
local Transcendencia = req("Transcendencia")
local pT1 = Perfil.padrao()
pT1.giros = 5
pT1.incursoes.fragmentos = 23
pT1.auras.faisca = 5
local rT1 = Loot.novo()
for andar = 1, 5 do
	Loot.creditar(rT1, pT1.inventario.itens, "cinzas", andar, semBonus)
end
local estoqueT1 = pT1.inventario.itens
igual("bloqueia receita desconhecida", Receitas.fabricar(estoqueT1, "invalida"), false)
igual(
	"conclusão de Cinzas permite fabricar Coração da Fenda",
	Receitas.fabricar(estoqueT1, "coracao_fenda"),
	true
)
igual(
	"T1 permite Coração da Ressonância",
	Receitas.fabricar(estoqueT1, "coracao_ressonancia"),
	true
)
igual(
	"uma única entrada não gera duas saídas",
	Receitas.fabricar(estoqueT1, "coracao_ressonancia"),
	false
)
igual("receita recusada mantém matéria-prima", estoqueT1.estilhaco_bruto, 1)
igual("Transcende I", Transcendencia.oferecer(estoqueT1, pT1.transcendencia), true)
igual("Transcendência consome exatamente um coração", estoqueT1.coracao_ressonancia, nil)
igual(
	"Transcendência não repete oferta",
	Transcendencia.oferecer(estoqueT1, pT1.transcendencia),
	false
)
igual("Transcendência persiste nível 1", pT1.transcendencia.nivel, 1)
igual("Transcendência preserva auras", pT1.auras.faisca, 5)
igual("Transcendência preserva giros", pT1.giros, 5)
igual("Transcendência preserva fragmentos", pT1.incursoes.fragmentos, 23)
igual("nível antigo é neutro", Transcendencia.normalizar(nil).nivel, 0)
igual("nível inválido é neutro", Transcendencia.sorte(0 / 0), 1)
for nivel = 0, 10 do
	local sorte = Transcendencia.sorte(nivel)
	local anterior = 0
	for i = #Auras.lista, 1, -1 do
		local aura = Auras.lista[i]
		local chance = Auras.probabilidadeReal(aura.id, sorte)
		igual("probabilidade positiva " .. aura.id .. "/" .. nivel, chance > 0, true)
		igual(
			"sorteio cai na faixa publicada " .. aura.id .. "/" .. nivel,
			Auras.sortear(function()
				return anterior + chance / 2
			end, sorte).id,
			aura.id
		)
		anterior += chance
	end
	igual("sorte soma 1 no nível " .. nivel, math.abs(anterior - 1) < 1e-12, true)
end
local rara = "trovao_jovem"
igual(
	"T1 aumenta a probabilidade rara no RNG normalizado",
	Auras.probabilidadeReal(rara, 1.05) > Auras.probabilidadeReal(rara),
	true
)
igual(
	"estoque cheio não consome ingredientes",
	Receitas.fabricar(
		{ coracao_fenda = 999999, estilhaco_bruto = 8, lasca_estavel = 2, selo_purificacao = 1 },
		"coracao_fenda"
	),
	false
)

local Artefatos = req("Artefatos")
local pArtefato = Perfil.padrao()
local invArtefato = pArtefato.inventario
igual("equipar exige posse", Artefatos.equipar(invArtefato, "emblema_guardiao"), false)
igual("equipar rejeita ID de material", Artefatos.equipar(invArtefato, "estilhaco_bruto"), false)
invArtefato.itens = {
	coracao_fenda = 3,
	brasa_arauto = 3,
	selo_purificacao = 2,
	perola_abissal = 1,
	veu_ocaso = 1,
	fragmento_instavel = 6,
}
igual("forja Emblema", Receitas.fabricar(invArtefato.itens, "emblema_guardiao"), true)
igual("forja Lâmina dos três mundos", Receitas.fabricar(invArtefato.itens, "lamina_nexo"), true)
igual("equipa Emblema", Artefatos.equipar(invArtefato, "emblema_guardiao"), true)
igual("Emblema aumenta vida", Artefatos.bonusVida(invArtefato.equipados.artefato), 0.10)
igual("troca slot pela Lâmina", Artefatos.equipar(invArtefato, "lamina_nexo"), true)
igual("Lâmina fica no slot único", invArtefato.equipados.artefato, "lamina_nexo")
igual("Lâmina não aumenta vida", Artefatos.bonusVida(invArtefato.equipados.artefato), 0)
igual("Lâmina tem visual", Artefatos.visual(invArtefato.equipados.artefato), "lamina_nexo")
igual(
	"slot válido sobrevive à migração",
	Itens.normalizarInventario(invArtefato).equipados.artefato,
	"lamina_nexo"
)
igual("desequipar limpa slot", Artefatos.equipar(invArtefato, ""), true)
igual("slot vazio", invArtefato.equipados.artefato, nil)
igual("equipamento não afeta sorte", Transcendencia.sorte(pArtefato.transcendencia.nivel), 1)

local pOferta = Perfil.padrao()
for nivel = 1, 10 do
	local custo = Transcendencia.custo(nivel - 1)
	local estoqueOferta = table.clone(custo)
	local id, qtd = next(custo)
	estoqueOferta[id] = qtd - 1
	igual(
		"oferta incompleta é recusada no nível " .. nivel,
		Transcendencia.oferecer(estoqueOferta, pOferta.transcendencia),
		false
	)
	igual("oferta incompleta mantém o nível " .. nivel, pOferta.transcendencia.nivel, nivel - 1)
	for item, preco in custo do
		igual(
			"oferta recusada preserva " .. item .. "/" .. nivel,
			estoqueOferta[item],
			if item == id then preco - 1 else preco
		)
	end
	estoqueOferta[id] = qtd
	igual(
		"oferta completa funciona no nível " .. nivel,
		Transcendencia.oferecer(estoqueOferta, pOferta.transcendencia),
		true
	)
	igual("consumo exato no nível " .. nivel, next(estoqueOferta), nil)
	igual("nível concedido " .. nivel, pOferta.transcendencia.nivel, nivel)
end
igual("limite de 10 níveis", Transcendencia.custo(10), nil)
igual("bônus máximo 1,50x", Transcendencia.sorte(10), 1.50)

local Arena = req("Arena")
local entrada = Arena.novo()
igual("arena não permite despertar sem energia", Arena.resolver(entrada, "despertar"), nil)
igual("arena rejeita ação inventada", Arena.resolver(entrada, "inexistente"), nil)
local corte = Arena.resolver(entrada, "corte")
igual("arena dano da técnica", corte.golpes[1].dano, 175)
igual("arena jogador age antes do soberano", corte.golpes[1].ator, "jogador")
igual("arena contra-ataque", corte.estado.vida, 900)
igual("arena preserva os dados de entrada", entrada.soberano, 1000)
igual("arena mantém a primeira técnica em recarga", Arena.restante(corte.estado, "corte"), 2)
igual("arena rejeita técnica em recarga", Arena.resolver(corte.estado, "corte"), nil)
igual("arena avança a rodada", corte.estado.rodada, 2)
local guarda = Arena.resolver(corte.estado, "guarda")
igual("arena guarda reduz o golpe pesado", guarda.golpes[2].dano, 91)
igual("arena guarda gera energia", guarda.estado.energia, 35)
local ataque = Arena.resolver(guarda.estado, "ataque")
igual("arena recarga devolve a técnica na rodada 4", Arena.restante(ataque.estado, "corte"), 0)
local selo = Arena.resolver(ataque.estado, "selo")
igual("arena baluarte reduz dano recebido pelo soberano", selo.golpes[1].dano, 33)
igual("arena selo fica ativo até um golpe de dano", selo.estado.selado, true)
local pesado = Arena.resolver(selo.estado, "ataque")
igual("arena selo reduz o dano seguinte", pesado.golpes[2].dano, 130)
igual("arena consome o selo num golpe", pesado.estado.selado, false)
igual("arena limita energia a 100", pesado.estado.energia, 100)
local ult = Arena.resolver(pesado.estado, "despertar")
igual("arena despertar consome a carga", ult.estado.energia, 0)
igual("arena despertar causa dano", ult.golpes[1].dano, 290)
local decisivo = Arena.novo()
decisivo.soberano = 10
local vitoria = Arena.resolver(decisivo, "ataque")
igual("arena golpe final limitado à vida restante", vitoria.golpes[1].dano, 10)
igual("arena vitória cancela a resposta do soberano", #vitoria.golpes, 1)
igual("arena vitória confirmada", vitoria.resultado, "vitoria")
igual("arena não aceita agir após vitória", Arena.resolver(vitoria.estado, "ataque"), nil)
decisivo.soberano = 1000
decisivo.vida = 1
local derrota = Arena.resolver(decisivo, "ataque")
igual("arena derrota confirmada", derrota.resultado, "derrota")
igual("arena vida nunca fica negativa", derrota.estado.vida, 0)

print(string.format("%d testes, %d falhas", total, falhas))
