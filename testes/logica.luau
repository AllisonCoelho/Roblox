local total, falhas = 0, 0
local function igual(nome, obtido, esperado)
	total += 1
	if obtido ~= esperado then
		falhas += 1
		print(string.format("FALHOU %s: %s != %s", nome, tostring(obtido), tostring(esperado)))
	end
end

local Formato = req("Formato")
do
	local C = req("CarregamentoMapa")
	local cena = req("NexoCena")
	local praca, mundo = C.dividir(cena.pecas)
	igual("mapa: preserva todas as peças", #praca + #mundo, #cena.pecas)
	igual("mapa: praça antes do mundo", #praca > 0 and #mundo > #praca, true)
	local nucleo, piso = false, false
	for _, p in praca do
		nucleo = nucleo or p.grupo == "nucleo"
		piso = piso or p.malha == "praca_piso"
		igual("mapa: praça dentro do raio", C.etapa(p), "Praca")
	end
	igual("mapa: núcleo na primeira etapa", nucleo, true)
	igual("mapa: piso na primeira etapa", piso, true)
	for _, p in mundo do
		igual("mapa: complemento fora da praça", C.etapa(p), "Mundo")
	end
	igual("mapa: limite da praça", C.etapa({posicao = {46, 0, 0}}), "Praca")
	igual("mapa: caminho fica para depois", C.etapa({posicao = {47, 0, 0}}), "Mundo")
end
igual("inteiro", Formato.inteiro(12450), "12.450")
igual("negativo", Formato.inteiro(-1500), "-1.500")
igual("abreviado", Formato.curto(15000), "15 mil")
igual("tempo", Formato.tempo(42), "0:42")

-- O catálogo de dados e o catálogo do sorteio usam os mesmos IDs, nomes e chances.
do
	local V2 = req("AurasOriginaisV2")
	local AurasAtuais = req("Auras")
	igual("v2: 67 auras", #V2.lista, 67)
	local ids, contagem = 0, {}
	for i, a in V2.lista do
		igual("v2: numeração " .. a.id, a.numero, i)
		if V2.porId[a.id] == a then
			ids += 1
		end
		contagem[a.tier] = (contagem[a.tier] or 0) + 1
		local ativa = AurasAtuais.porId[a.id]
		igual("v2: aura disponível no sorteio " .. a.id, ativa ~= nil, true)
		igual("v2: chance ativa " .. a.id, ativa and ativa.chance, a.chance)
		local tier = AurasAtuais.Tiers[AurasAtuais.tierDe(math.floor(a.chance))].nome
		igual("v2: raridade bate com a chance " .. a.id, a.tier, tier)
		if i > 1 then
			igual("v2: ordem crescente " .. a.id, a.chance > V2.lista[i - 1].chance, true)
		end
	end
	igual("v2: ids únicos", ids, 67)
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
	igual(
		"v2: soma das explícitas",
		math.abs(V2.SOMA_EXPLICITAS - 0.7900337720738687) < 1e-12,
		true
	)
	igual("v2: reserva ~1 em 4,76", math.floor(V2.porId.centelha_do_nexo.chance * 100), 476)
	local total = 0
	for _, a in V2.lista do
		total += 1 / a.chance
	end
	igual("v2: probabilidades somam 100%", math.abs(total - 1) < 1e-9, true)
	igual("v2: lote inicial existe", #V2.LOTE_INICIAL, 7)
	for _, id in V2.LOTE_INICIAL do
		igual("v2: prévia de VFX " .. id, req("AurasVfx")[id], true)
	end
	for _, id in V2.LOTE_INICIAL do
		igual("v2: lote " .. id, V2.porId[id] ~= nil, true)
	end
end

-- Efeitos das 67: todas têm receita, presets existem e nenhuma receita repete outra
do
	local V2 = req("AurasOriginaisV2")
	local E = req("EfeitosOriginais")
	local assinaturas, repetidas, semReceita, presetFaltando = {}, 0, 0, 0
	for _, a in V2.lista do
		local r = E.AURAS[a.id]
		if not r then
			semReceita += 1
			continue
		end
		local partes = {}
		for _, c in r.camadas do
			if not E.PRESETS[c[1]] then
				presetFaltando += 1
			end
			table.insert(partes, c[1] .. ":" .. c[2])
		end
		table.sort(partes)
		local chave = table.concat(partes, "|")
		if assinaturas[chave] then
			repetidas += 1
			print("receita repetida: " .. a.id .. " = " .. assinaturas[chave])
		end
		assinaturas[chave] = a.id
		igual("efeitos: 2+ camadas " .. a.id, #r.camadas >= 2, true)
		igual("efeitos: prévia " .. a.id, req("AurasVfx")[a.id], true)
	end
	igual("efeitos: todas as 67 têm receita", semReceita, 0)
	igual("efeitos: presets existem", presetFaltando, 0)
	igual("efeitos: receitas únicas", repetidas, 0)
end

-- Senbonzakura: efeito de prévia, nunca entra no sorteio sem autorização do dono
igual("senbonzakura como prévia de VFX", req("AurasVfx").senbonzakura, true)
igual("senbonzakura fora do catálogo sorteável", req("Auras").porId.senbonzakura, nil)

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

-- Monetização: catálogo e passes das configurações
do
	local M = req("Monetizacao")
	local Ap = req("Apresentacao")
	local vistos = {}
	for _, p in M.PRODUTOS do
		igual("loja: id único " .. p.id, vistos[p.id], nil)
		vistos[p.id] = true
		igual("loja: preço positivo " .. p.id, p.preco > 0, true)
		igual(
			"loja: status conhecido " .. p.id,
			p.status == "ativo" or p.status == "planejado",
			true
		)
	end
	igual("loja: 16 produtos no catálogo", #M.PRODUTOS, 16)
	igual("loja: giro automático 49", M.porId.autoGiro.preco, 49)
	igual("loja: pular animação 39", M.porId.pularAnimacao.preco, 39)
	igual("loja: todos os 16 ativos", #M.ativos(), 16)
	igual("loja: iniciante 49", M.porId.iniciante.preco, 49)
	igual("loja: vip 199", M.porId.vip.preco, 199)
	igual("loja: passe de temporada 299", M.porId.passeTemporada.preco, 299)
	local nada = function()
		return false
	end
	local tudo = function()
		return true
	end
	igual(
		"loja: ligar auto exige passe",
		M.passeNecessario("giroAutomatico", true, nada),
		"autoGiro"
	)
	igual("loja: desligar auto é livre", M.passeNecessario("giroAutomatico", false, nada), nil)
	igual(
		"loja: desligar animações exige passe",
		M.passeNecessario("animacoes", false, nada),
		"pularAnimacao"
	)
	igual("loja: ligar animações é livre", M.passeNecessario("animacoes", true, nada), nil)
	igual(
		"loja: encurtar repetidas exige passe",
		M.passeNecessario("pularRepetidas", true, nada),
		"pularAnimacao"
	)
	igual("loja: acessibilidade é livre", M.passeNecessario("movimentoReduzido", true, nada), nil)
	igual("loja: com passe libera", M.passeNecessario("giroAutomatico", true, tudo), nil)
	for _, c in Ap.Categorias do
		igual("ritual: roleta em " .. c.id, (c.roleta or 0) > 0, true)
		igual("ritual: tempo inclui a roleta " .. c.id, Ap.tempoAteRevelacao(c) > c.roleta, true)
	end
	igual(
		"ritual: raras giram mais tempo",
		Ap.Categorias[#Ap.Categorias].roleta > Ap.Categorias[1].roleta,
		true
	)
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
igual("67 auras", #Auras.lista, 67)
local ids, crescente = {}, true
for i, a in Auras.lista do
	igual("id unico " .. a.id, ids[a.id], nil)
	ids[a.id] = true
	if i > 1 and a.chance <= Auras.lista[i - 1].chance then
		crescente = false
	end
end
igual("chances crescentes", crescente, true)
igual("mais rara", Auras.lista[67].chance, 100000000)
igual("tier comum", Auras.porId.centelha_do_nexo.tier, 1)
igual("tier divino", Auras.porId.soberania_do_vazio.tier, 7)
igual("tier epico", Auras.tierDe(1000), 4)
igual(
	"rng 0 = mais rara",
	Auras.sortear(function()
		return 0
	end).id,
	"soberania_do_vazio"
)
igual(
	"rng alto = reserva",
	Auras.sortear(function()
		return 0.9999
	end).id,
	"centelha_do_nexo"
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
	Auras.probabilidadeReal("centelha_do_nexo") > Auras.probabilidadeReal("musgo_luminoso"),
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
for _, id in
	{ "centelha_do_nexo", "musgo_luminoso", "fagulha_de_cobre", "gelo_de_neon", "coroa_de_coral" }
do
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
igual("texto reserva", Formato.chance(Auras.porId.centelha_do_nexo.chance), "4,8")
igual("texto inteiro", Formato.chance(1000), "1.000")
igual("texto curto", Formato.chanceCurta(25000), "25 mil")
igual("texto curto pequeno", Formato.chanceCurta(4.26), "4,3")
igual(
	"melhor da colecao",
	Auras.melhorDe({ centelha_do_nexo = 3, esporos_de_safira = 1, inexistente = 9 }).id,
	"esporos_de_safira"
)
igual("colecao vazia sem melhor", Auras.melhorDe({}), nil)
igual(
	"descobertas",
	Auras.contarDescobertas({ centelha_do_nexo = 1, fagulha_de_cobre = 0, x = 2 }),
	1
)
-- Contas antigas preservam descobertas e quantidades ao entrar no catálogo de 67.
do
	local antigas = {
		faisca = 1,
		nevoa = 5,
		brasa = 7,
		orvalho = 9,
		folha_dancante = 12,
		pedra_viva = 16,
		mare_calma = 20,
		brasa_sussurrante = 30,
		vento_cortante = 45,
		raiz_antiga = 60,
		gelo_fino = 80,
		trovao_jovem = 100,
		lotus_rubra = 150,
		pluma_celeste = 250,
		chama_azul = 400,
		eco_do_vazio = 500,
		cristal_lunar = 750,
		tempestade_rubra = 1000,
		sombra_gemea = 1500,
		sol_nascente = 2500,
		dragao_de_jade = 5000,
		aurora_boreal = 7500,
		coracao_estelar = 10000,
		lamina_do_crepusculo = 25000,
		lotus_celestial = 50000,
		fenix_eterna = 100000,
		eclipse_carmesim = 250000,
		olho_do_abismo = 500000,
		nebulosa_primordial = 750000,
		despertar_absoluto = 1000000,
	}
	local destinos = {}
	for id, chance in antigas do
		local estado = Perfil.padrao()
		estado.auras[id] = 2
		estado.equipada = id
		Perfil.migrarAuras(estado)
		local destino = estado.equipada
		local aura = Auras.porId[destino]
		igual(
			"migração: destino da mesma raridade " .. id,
			aura and aura.tier,
			Auras.tierDe(chance)
		)
		igual("migração: duas cópias " .. id, estado.auras[destino], 2)
		igual("migração: origem removida " .. id, estado.auras[id], nil)
		igual("migração: destino exclusivo " .. id, destinos[destino], nil)
		igual("migração: origem fora do sorteio " .. id, Auras.porId[id], nil)
		destinos[destino] = true
	end

	local conta = Perfil.padrao()
	conta.giros = 1842
	conta.transcendencia.nivel = 5
	conta.auras = { faisca = 8, centelha_do_nexo = 2, brasa = 1, futura = 3 }
	conta.equipada = "faisca"
	Perfil.migrarAuras(conta)
	Perfil.migrarAuras(conta)
	igual("migração: soma idempotente", conta.auras.centelha_do_nexo, 10)
	igual("migração: aura equipada convertida", conta.equipada, "centelha_do_nexo")
	igual("migração: saldo de giros", conta.giros, 1842)
	igual("migração: Transcendência", conta.transcendencia.nivel, 5)
	igual("migração: IDs desconhecidos preservados", conta.auras.futura, 3)
	igual("migração: coleção aparece no Índice", Auras.contarDescobertas(conta.auras), 2)

	local invalida = Perfil.padrao()
	invalida.auras.brasa = -1
	invalida.equipada = "brasa"
	Perfil.migrarAuras(invalida)
	igual("migração: não concede saldo inválido", invalida.auras.fagulha_de_cobre, nil)
	igual("migração: não equipa aura sem posse", invalida.equipada, nil)
end

-- Apresentação do giro: categorias pela chance real e durações dentro das faixas do design
local Apresentacao = req("Apresentacao")
igual("6 categorias", #Apresentacao.Categorias, 6)
igual("centelha = baixa", Apresentacao.de(Auras.porId.centelha_do_nexo.chance).id, "baixa")
igual("1 em 49 = baixa", Apresentacao.de(49).id, "baixa")
igual("1 em 50 = moderada", Apresentacao.de(50).id, "moderada")
igual("1 em 999 = moderada", Apresentacao.de(999).id, "moderada")
igual("1 em 1.000 = alta", Apresentacao.de(1000).id, "alta")
igual("1 em 10.000 = muito alta", Apresentacao.de(10000).id, "muito_alta")
igual("1 em 100.000 = extrema", Apresentacao.de(100000).id, "extrema")
igual("1 em 1.000.000 = absoluta", Apresentacao.de(1000000).id, "absoluta")
-- durações com a Roleta de Ecos (1,2 a 2,6 s) somada ao ritual (pedido do dono: giro mais longo)
local faixas = { { 1.6, 1.8 }, { 2.2, 2.6 }, { 3.2, 3.7 }, { 4, 5 }, { 5.3, 6.3 }, { 6.6, 8.6 } }
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
igual("catalogo 67 entradas", #Auras.lista, 67)
igual("Musgo alterado para 1 em 6", Auras.porId.musgo_luminoso.chance, 6)
igual(
	"Centelha mais comum",
	Auras.porId.centelha_do_nexo.pBase > Auras.porId.musgo_luminoso.pBase,
	true
)
igual("Centelha 20.9966%", math.abs(Auras.PROBABILIDADE_RESERVA - 0.2099662279261313) < 1e-12, true)
igual("sorte NaN segura", Probabilidades.sorteValida(0 / 0), 1)
igual("sorte infinito segura", Probabilidades.sorteValida(math.huge), 1)
igual("sorte negativa segura", Probabilidades.sorteValida(-1), 1)
igual("limite superior de sorte 20", Probabilidades.sorteValida(50), 20)
igual("transcendencia 0", Probabilidades.sorteTranscendencia(0), 1)
igual("transcendencia X", Probabilidades.sorteTranscendencia(10), 1.5)
igual("transcendencia maior que X", Probabilidades.sorteTranscendencia(20), 1.5)
igual("perfil sem nivel segue sorte 1", Auras.sorteTranscendencia(nil), 1)
local anteriorCoroa = 0
local anteriorDivino = 0
for nivel = 0, 10 do
	local sorte = Probabilidades.sorteTranscendencia(nivel)
	local pesos, z = Probabilidades.distribuicao(Auras.lista, sorte)
	local somaEfetiva = 0
	for _, peso in pesos do
		somaEfetiva += peso / z
	end
	igual("67 total no nivel " .. nivel, math.abs(somaEfetiva - 1) < 1e-10, true)
	local coroa = Probabilidades.chanceEfetiva(Auras.lista, "coroa_de_coral", sorte)
	local divino = Probabilidades.chanceEfetiva(Auras.lista, "soberania_do_vazio", sorte)
	igual("67 Coroa cresce nivel " .. nivel, coroa >= anteriorCoroa, true)
	igual("67 Soberania cresce nivel " .. nivel, divino >= anteriorDivino, true)
	anteriorCoroa = coroa
	anteriorDivino = divino
end
igual(
	"67 Centelha no nivel X",
	math.abs(
		Probabilidades.chanceEfetiva(Auras.lista, "centelha_do_nexo", 1.5) - 0.19779318528564926
	) < 1e-11,
	true
)
igual(
	"67 Musgo no nivel X",
	math.abs(Probabilidades.chanceEfetiva(Auras.lista, "musgo_luminoso", 1.5) - 0.15700396776446937)
		< 1e-11,
	true
)
igual(
	"67 Soberania no nivel X",
	math.abs(
		Probabilidades.chanceEfetiva(Auras.lista, "soberania_do_vazio", 1.5) - 1.954457110930131e-8
	) < 1e-16,
	true
)
local pesos3, z3 = Probabilidades.distribuicao(Auras.lista, 3)
local soma3 = 0
for _, peso in pesos3 do
	soma3 += peso / z3
end
igual("67 sorte 3 segue 100%", math.abs(soma3 - 1) < 1e-10, true)
igual(
	"67 RNG zero = divino",
	Probabilidades.sortear(Auras.lista, 1.5, function()
		return 0
	end).id,
	"soberania_do_vazio"
)
igual(
	"67 RNG alto = Centelha",
	Probabilidades.sortear(Auras.lista, 1.5, function()
		return 0.999999
	end).id,
	"centelha_do_nexo"
)
igual("67 aura inexistente", Probabilidades.chanceEfetiva(Auras.lista, "desconhecida", 1.5), 0)
local somaAtual3 = 0
for _, aura in Auras.lista do
	somaAtual3 += Auras.probabilidadeReal(aura.id, 3)
end
igual("catalogo atual em 3x soma 100%", math.abs(somaAtual3 - 1) < 1e-10, true)
igual(
	"catalogo atual aumenta chance divina",
	Auras.probabilidadeReal("soberania_do_vazio", 1.5)
		> Auras.probabilidadeReal("soberania_do_vazio"),
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
local rara = "coroa_de_coral"
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

-- Cosméticos e Passe de Temporada
do
	local C = req("Cosmeticos")
	local T = req("Temporada")
	local M = req("Monetizacao")
	local vistos = {}
	for _, i in C.ITENS do
		igual("cosmético: id único " .. i.id, vistos[i.id], nil)
		vistos[i.id] = true
		igual("cosmético: tipo conhecido " .. i.id, table.find(C.TIPOS, i.tipo) ~= nil, true)
		igual("cosmético: cor hex " .. i.id, string.match(i.cor, "^%x%x%x%x%x%x$") ~= nil, true)
	end
	for pacote, itens in C.PACOTES do
		igual("cosmético: pacote é produto ativo " .. pacote, M.porId[pacote].status, "ativo")
		for _, id in itens do
			igual("cosmético: item do pacote existe " .. id, C.porId[id] ~= nil, true)
		end
	end
	local c = C.padrao()
	igual("cosmético: conceder novos", #C.conceder(c, { "tit_vip", "dis_coroa", "xx" }), 2)
	igual("cosmético: conceder é idempotente", #C.conceder(c, { "tit_vip" }), 0)
	igual("cosmético: equipar item possuído", C.podeEquipar(c, "titulo", "tit_vip"), true)
	igual("cosmético: não equipa no tipo errado", C.podeEquipar(c, "rastro", "tit_vip"), false)
	igual("cosmético: não equipa sem possuir", C.podeEquipar(c, "titulo", "tit_mestre"), false)
	igual("cosmético: tirar sempre pode", C.podeEquipar(c, "titulo", ""), true)
	igual("cosmético: tipo inválido", C.podeEquipar(c, "chapeu", ""), false)

	local usados = {}
	for n, r in T.RECOMPENSAS do
		igual("temporada: nível válido " .. n, n >= 1 and n <= T.NIVEIS, true)
		for _, trilha in { "gratis", "premium" } do
			local id = r[trilha]
			if id then
				igual(
					"temporada: recompensa existe " .. id,
					C.porId[id] ~= nil and C.porId[id].origem,
					"temporada"
				)
				igual("temporada: recompensa não repete " .. id, usados[id], nil)
				usados[id] = true
			end
		end
	end
	igual("temporada: 60 dias", (T.FIM - T.INICIO) / 86400, 60)
	igual("temporada: ativa no início", T.ativa(T.INICIO), true)
	igual("temporada: encerrada no fim", T.ativa(T.FIM), false)
	local t = T.de(nil)
	igual("temporada: começa zerada", t.xp, 0)
	igual("temporada: outra temporada zera", T.de({ id = "t0", xp = 999 }).xp, 0)
	igual("temporada: giro dá 1 XP", T.ganhar(t, "giro", 10, false), 1)
	igual("temporada: fonte desconhecida", T.ganhar(t, "trapaça", 10, false), 0)
	for _ = 1, 400 do
		T.ganhar(t, "giro", 10, false)
	end
	igual("temporada: teto diário dos giros", t.xp, T.TETO_GIRO_DIA)
	igual("temporada: andar ignora o teto dos giros", T.ganhar(t, "andar", 10, false), T.XP.andar)
	igual("temporada: novo dia libera giros", T.ganhar(t, "giro", 11, false), 1)
	igual(
		"temporada: VIP +10%",
		math.abs(T.ganhar(t, "vitoria", 11, true) - T.XP.vitoria * 1.1) < 1e-9,
		true
	)
	igual("temporada: nível pelo XP", T.nivel(T.XP_POR_NIVEL * 5 + 3), 5)
	igual("temporada: nível limitado", T.nivel(10 ^ 9), T.NIVEIS)
	local r = T.de(nil)
	r.xp = T.XP_POR_NIVEL * 15
	igual(
		"temporada: resgata grátis alcançado",
		T.resgatavel(r, 15, "gratis", false),
		"tit_cacador"
	)
	igual("temporada: premium sem passe", T.resgatavel(r, 15, "premium", false), nil)
	igual("temporada: premium com passe", T.resgatavel(r, 15, "premium", true), "ras_aurora")
	igual("temporada: nível não alcançado", T.resgatavel(r, 20, "gratis", true), nil)
	igual("temporada: nível sem recompensa", T.resgatavel(r, 2, "gratis", true), nil)
	r.resgates.gratis["15"] = true
	igual("temporada: não resgata duas vezes", T.resgatavel(r, 15, "gratis", true), nil)
	local maximo = T.de(nil)
	for _ = 1, 1000 do
		T.ganhar(maximo, "vitoria", 1, true)
	end
	igual("temporada: XP limitado ao último nível", maximo.xp, T.NIVEIS * T.XP_POR_NIVEL)
end

-- Itens avulsos, assinatura e conveniências
do
	local C = req("Cosmeticos")
	local V = req("Conveniencia")
	local M = req("Monetizacao")
	for _, grupo in
		{ "titulos", "trilhas", "aparenciaAlternativa", "emotesVitoria", "finalizacoes" }
	do
		local itens = C.doGrupo(grupo)
		igual("avulso: grupo tem itens " .. grupo, #itens >= 2, true)
		igual("avulso: grupo é produto " .. grupo, M.porId[grupo].tipo, "produto")
		for _, i in itens do
			igual("avulso: preço dentro da faixa " .. i.id, i.preco >= M.porId[grupo].preco, true)
			igual("avulso: sem ID inventado " .. i.id, i.developerProductId, nil)
		end
	end
	igual("avulso: sem ID nenhum produto é achado", C.porProduto(123), nil)
	for _, id in C.MENSAIS do
		igual("assinatura: mensal existe " .. id, C.porId[id] ~= nil, true)
	end
	igual("assinatura: mês seguinte troca o item", C.mensal(2026, 11) ~= C.mensal(2026, 12), true)
	igual("assinatura: virada de ano segue a lista", C.mensal(2026, 12) ~= C.mensal(2027, 1), true)
	igual("assinatura: título exclusivo", C.porId.tit_membro.exigeAssinatura, true)
	igual("ritual: estilos do passe", #C.PACOTES.ritualPersonalizado, 3)

	igual("auto: limiar válido", V.limiarValido(10000), true)
	igual("auto: limiar inválido", V.limiarValido(12345), false)
	igual("auto: texto não é limiar", V.limiarValido("1000"), false)
	local a = { pararChance = 10000, pararNova = false }
	igual("auto: para em aura rara", V.devePararAuto(a, 50000, false) ~= nil, true)
	igual("auto: segue em aura comum", V.devePararAuto(a, 50, false), nil)
	igual("auto: nova só com opção", V.devePararAuto(a, 2, true), nil)
	a.pararNova = true
	igual("auto: para em aura nova", V.devePararAuto(a, 2, true) ~= nil, true)
	igual("auto: padrão nunca para", V.devePararAuto(V.autoPadrao(), 10 ^ 9, true), nil)
	igual("auto: sem dados não para", V.devePararAuto(nil, 10 ^ 9, true), nil)
	igual("presets: slot 1", V.slotValido(1), true)
	igual("presets: slot 6", V.slotValido(6), false)
	igual("presets: slot fracionado", V.slotValido(1.5), false)
	local cos = { titulo = "tit_vip" }
	local p = V.criarPreset("aura_x", cos)
	cos.titulo = "outro"
	igual("presets: cópia dos cosméticos", p.cosmeticos.titulo, "tit_vip")
	igual("presets: sem aura vira vazio", V.criarPreset(nil, nil).aura, "")
end

-- Gear 5: duas silhuetas em repouso e contatos no passo que move o corpo.
do
	local M = req("Gear5Movimento")
	local risada, flutuar = M.parado(0.8)
	igual("gear 5: sustenta a risada", risada, 0)
	igual("gear 5: flutuação discreta", math.abs(flutuar) <= 0.075, true)
	local transicao = M.parado(1.9)
	igual("gear 5: mistura gradual das poses", transicao > 0 and transicao < 1, true)
	local relaxado = M.parado(3)
	igual("gear 5: sustenta o repouso", relaxado, 1)
	local volta = M.parado(4.2)
	igual("gear 5: volta gradualmente à risada", volta > 0 and volta < 1, true)
	igual("gear 5: repete o ciclo", M.parado(4.8), 0)

	local fase, pe = M.passo(0.49, 0.02, 14)
	igual("gear 5: pousa no pé esquerdo", pe, "E")
	igual("gear 5: sem segundo contato no quadro seguinte", select(2, M.passo(fase, 0.02, 14)), nil)
	fase, pe = M.passo(0.99, 0.02, 14)
	igual("gear 5: volta com o pé direito", pe, "D")
	igual("gear 5: a fase volta ao começo", fase < 0.05, true)
	igual("gear 5: parado não avança o passo", M.passo(0.2, 1, 0), 0.2)
	local andando = M.passo(0, 0.2, 5)
	local correndo = M.passo(0, 0.2, 16)
	igual("gear 5: passo acelera com movimento", correndo > andando, true)
	local esquerda, quadro, _, altura = M.corrida(0.819)
	igual("gear 5: espelha a passada alternada", esquerda, true)
	igual("gear 5: pose aérea no topo do passo", quadro, 3)
	igual("gear 5: há quique na passada", altura > 0.55, true)
	local _, _, _, contato = M.corrida(0.5)
	igual("gear 5: volta à altura de apoio no contato", contato, 0)
end

-- Gear 5: Haki do Rei sincronizado com a animação parada
do
	local M = req("Gear5Movimento")
	local T = M.TEMPO_PARADO
	local eventos = {}
	local t = 0
	while t < T * 4 do
		local e = M.hakiParado(t, t + 1 / 60)
		if e then
			table.insert(eventos, { e, t + 1 / 60 })
		end
		t += 1 / 60
	end
	igual("haki: 4 eventos em 4 ciclos parados", #eventos, 4)
	igual("haki: primeiro são faíscas no repouso", eventos[1][1], "fraco")
	igual(
		"haki: faíscas no quadro do repouso",
		math.abs(eventos[1][2] - M.HAKI_RELAXADO) < 0.02,
		true
	)
	igual("haki: estouro forte no auge da risada", eventos[2][1], "forte")
	igual(
		"haki: forte no segundo ciclo",
		math.abs(eventos[2][2] - (T + M.HAKI_RISADA)) < 0.02,
		true
	)
	igual("haki: ciclos alternados", eventos[3][1] .. eventos[4][1], "fracoforte")
	igual("haki: nada ao começar a ficar parado", M.hakiParado(0, 0.3), nil)
	igual("haki: um quadro longo não perde o evento", M.hakiParado(T + 0.3, T + 0.4), "forte")
	igual("haki: queda baixa só borracha", M.hakiPouso(-20), nil)
	igual("haki: queda forte estoura", M.hakiPouso(-45), 1)
	igual("haki: intensidade do pouso limitada", M.hakiPouso(-500), 1.6)
	igual("haki: queda média tem mínimo", M.hakiPouso(-31), 0.8)
end

-- Ícones da interface
do
	local I = req("Icones")
	local It = req("Itens")
	for id, item in It.porId do
		igual("ícone: item tem símbolo próprio " .. id, I.ITENS[id] ~= nil, true)
		igual("ícone: categoria conhecida " .. id, I.CATEGORIAS[item.categoria] ~= nil, true)
	end
	igual(
		"ícone: item desconhecido usa a categoria",
		I.item("xx", "Artefatos"),
		I.CATEGORIAS.Artefatos
	)
	igual("ícone: sem categoria", I.item("xx", nil), I.DESCONHECIDO)
	igual("ícone: aura sem estilo", I.aura(nil), I.AURAS.brilho)
	local vistos = { [I.DESCONHECIDO] = true }
	for _, grupo in { I.ITENS, I.CATEGORIAS, I.AURAS, I.MENU, I.STATUS, I.DISTINTIVOS } do
		for nome, indice in grupo do
			igual(
				"ícone: célula válida " .. nome,
				indice % 1 == 0 and indice >= 1 and indice <= I.TOTAL,
				true
			)
			vistos[indice] = true
		end
	end
	for i = 1, I.TOTAL do
		igual("ícone: atlas usa a célula " .. i, vistos[i], true)
	end
end

-- Animações da Arena: tempos, clipes e pernas com os pés no chão
do
	local Anim = req("ArenaAnimacoes")
	local Pecas = req("SoberanoPecas")
	local function perto(a, b)
		return math.abs(a - b) < 0.05
	end
	-- chaves em ordem e dentro da duração
	local function chavesOk(clipe)
		local anterior = -1
		for _, c in clipe.chaves do
			if c.t < anterior or c.t > clipe.duracao + 1e-6 then
				return false
			end
			anterior = c.t
		end
		return true
	end
	for nome, clipe in Anim.JOGADOR do
		igual("animação: chaves do jogador " .. nome, chavesOk(clipe), true)
	end
	for nome, clipe in Anim.SOBERANO do
		igual("animação: chaves do Soberano " .. nome, chavesOk(clipe), true)
	end
	-- amostragem: começo, fim, interpolação e laço
	local postura = Anim.JOGADOR.postura
	igual("animação: laço volta ao começo", perto(Anim.amostrar(postura, postura.duracao).raiz2, Anim.amostrar(postura, 0).raiz2), true)
	local ataque = Anim.JOGADOR.ataque
	local fim = Anim.amostrar(ataque, ataque.duracao + 5)
	igual("animação: fim do ataque volta à postura", perto(fim.ombroD1, Anim.amostrar(postura, 0).ombroD1), true)
	-- cinemática inversa: repouso = zero; agachar dobra o joelho para a frente; o pé alcança o alvo
	for nome, perna in { r15 = Anim.PERNA_R15, dir = Pecas.pernas.dir, esq = Pecas.pernas.esq } do
		local c, j = Anim.perna(perna, 0, 0, 0, 0)
		igual("perna " .. nome .. ": repouso sem giro", perto(c, 0) and perto(j, 0), true)
		c, j = Anim.perna(perna, 0, 0, -0.8, 0)
		igual("perna " .. nome .. ": agachar leva a coxa à frente", c > 0.2, true)
		igual("perna " .. nome .. ": agachar dobra o joelho", j < -0.4, true)
	end
	-- o tornozelo cai onde o clipe pediu (agachado e com o pé à frente)
	do
		local perna = Anim.PERNA_R15
		local c, j = Anim.perna(perna, 0, -0.6, -0.5, 0)
		local l = 1.2
		local jy, jz = -math.cos(c) * l, -math.sin(c) * l
		local ty = jy - math.cos(c + j) * l
		local tz = jz - math.sin(c + j) * l
		igual("perna r15: tornozelo na altura pedida", perto(ty, -2.4 + 0.5), true)
		igual("perna r15: tornozelo à frente", perto(tz, -0.6), true)
	end
	-- salto do Soberano: a entrada vai do trono (viagem 0) ao ringue (viagem 1)
	local entrada = Anim.SOBERANO.entrada
	igual("soberano: entrada começa no trono", Anim.amostrar(entrada, 0).viagem1, 0)
	igual("soberano: entrada termina no ringue", Anim.amostrar(entrada, entrada.duracao).viagem1, 1)
	igual("soberano: entrada cabe na introdução", entrada.duracao <= Anim.INTRODUCAO, true)
	igual("soberano: peças do duelo com pernas", #Pecas.duelo, 6)
end

-- Pontos de Aura, evoluções e sorte total
do
	local PA = req("PontosAura")
	local AurasP = req("Auras")
	local ProbP = req("Probabilidades")
	local p = PA.padrao()
	igual("pontos: começa zerado", p.pontos + p.nivel + p.fluxo + p.sorte, 0)
	-- raridade gera mais, mas suavizado
	local comum = PA.forcaDaAura("musgo_luminoso")
	local divina = PA.forcaDaAura("soberania_do_vazio")
	igual("pontos: aura rara gera mais", divina > comum, true)
	igual("pontos: 1 em 100 milhões gera 100/s", math.abs(divina - 100) < 0.01, true)
	igual("pontos: sem aura ainda gera um pouco", PA.forcaDaAura(nil), PA.SEM_AURA)
	igual("pontos: aura inventada conta como sem aura", PA.forcaDaAura("nao_existe"), PA.SEM_AURA)
	-- evoluir cobra, sobe o nível e respeita saldo e máximo
	igual("evoluir: sem saldo falha", (PA.evoluir(p, "nivel")), false)
	p.pontos = PA.custo("nivel", 0)
	igual("evoluir: com saldo compra", (PA.evoluir(p, "nivel")), true)
	igual("evoluir: nível sobe", p.nivel, 1)
	igual("evoluir: saldo gasto", p.pontos, 0)
	igual("evoluir: custo cresce", PA.custo("nivel", 1) > PA.custo("nivel", 0), true)
	igual("evoluir: id inválido", (PA.evoluir(p, "voar")), false)
	igual("evoluir: tipo inválido", (PA.evoluir(p, 12)), false)
	local cheio = PA.normalizar({ pontos = 1e300, sorte = 999 })
	igual("evoluir: normalizar limita o máximo", cheio.sorte, PA.porId.sorte.maximo)
	igual("evoluir: no máximo não compra", (PA.evoluir(cheio, "sorte")), false)
	local estranho = PA.normalizar({ pontos = 0 / 0, nivel = -3, fluxo = "x" })
	igual("normalizar: NaN e negativos viram zero", estranho.pontos + estranho.nivel + estranho.fluxo, 0)
	igual("normalizar: nil vira padrão", PA.normalizar(nil).total, 0)
	-- fluxo e nível mudam ganho e pontuação
	local base = PA.ganhoPorSegundo(PA.padrao(), "musgo_luminoso")
	local comFluxo = PA.ganhoPorSegundo({ pontos = 0, total = 0, nivel = 0, fluxo = 10, sorte = 0 }, "musgo_luminoso")
	igual("fluxo: 10 níveis dobram o ganho", math.abs(comFluxo - 2 * base) < 1e-9, true)
	igual("fluxo: multiplicador extra", math.abs(PA.ganhoPorSegundo(PA.padrao(), "musgo_luminoso", 3) - 3 * base) < 1e-9, true)
	local pt0 = PA.pontuacao(PA.padrao(), "musgo_luminoso")
	local pt4 = PA.pontuacao({ pontos = 0, total = 0, nivel = 4, fluxo = 0, sorte = 0 }, "musgo_luminoso")
	igual("pontuação: 4 níveis dobram", pt4, math.floor(2 * 10 * PA.forcaDaAura("musgo_luminoso")))
	igual("pontuação: aura rara pesa mais", PA.pontuacao(PA.padrao(), "soberania_do_vazio") > pt0, true)
	-- sorte total: evolução x Transcendência x extra, com teto
	igual("sorte: começa em 1", PA.sorteTotal({ poder = PA.padrao(), transcendencia = { nivel = 0 } }), 1)
	igual("sorte: estado estranho é 1", PA.sorteTotal(nil), 1)
	local s5 = PA.sorteTotal({ poder = { sorte = 20 }, transcendencia = { nivel = 10 } })
	igual("sorte: evolução x transcendência", math.abs(s5 - 5 * 1.5) < 1e-9, true)
	local teto = PA.sorteTotal({ poder = { sorte = 95 }, transcendencia = { nivel = 10 } }, 50)
	igual("sorte: respeita o teto", teto, PA.SORTE_MAXIMA)
	igual("sorte: teto é o do sorteio", PA.SORTE_MAXIMA, ProbP.MAX_SORTE)
	-- no teto, a aura mais rara continua rara (nunca fácil) e a sorte ajuda de verdade
	local rara = AurasP.porId.soberania_do_vazio
	local noTeto = AurasP.chanceEfetiva(rara, PA.SORTE_MAXIMA)
	igual("sorte: no teto a mais rara ainda passa de 1 em 1 milhão", noTeto > 1000000, true)
	igual("sorte: no teto fica bem mais fácil que a base", noTeto < rara.chance / 50, true)
	local soma = 0
	for _, a in AurasP.lista do
		soma += AurasP.probabilidadeReal(a.id, 7.3)
	end
	igual("sorte: distribuição soma 100% em sorte qualquer", math.abs(soma - 1) < 1e-9, true)
end

-- Corredor dos Perdidos: acesso, conclusão, recompensas, bônus e o mapa gerado
do
	local C = req("Corredor")
	local M = req("CorredorMapa")
	igual("corredor: seis fases", C.TOTAL, 6)
	igual("corredor: mapa com seis ilhas", #M.fases, 6)
	local p = C.padrao()
	igual("corredor: fase 1 aberta a todos", (C.podeEntrar(p, 1, 0)), true)
	igual("corredor: fase 2 pede a 1 concluída", (C.podeEntrar(p, 2, 1e9)), false)
	igual("corredor: fase inexistente", (C.podeEntrar(p, 7, 1e9)), false)
	igual("corredor: fase de tipo errado", (C.podeEntrar(p, "2", 1e9)), false)
	igual("corredor: acesso inicial", C.acesso(p, 1e9), 1)
	local ganho, primeira = C.concluir(p, 1, 1000)
	igual("corredor: primeira conclusão paga o bônus", ganho, C.FASES[1].primeira)
	igual("corredor: marcada como primeira", primeira, true)
	igual("corredor: fragmentos somados", p.fragmentos, C.FASES[1].primeira)
	igual("corredor: fase 2 sem Pontuação", (C.podeEntrar(p, 2, C.FASES[2].requisito - 1)), false)
	igual("corredor: fase 2 com Pontuação", (C.podeEntrar(p, 2, C.FASES[2].requisito)), true)
	igual("corredor: acesso sobe", C.acesso(p, 1e9), 2)
	local g2 = C.concluir(p, 1, 1000 + C.ESPERA_REPETIR - 1)
	igual("corredor: repetir antes da espera não paga", g2, 0)
	local g3 = C.concluir(p, 1, 1000 + C.ESPERA_REPETIR)
	igual("corredor: repetir depois da espera paga menos", g3, C.FASES[1].repetir)
	igual("corredor: bônus ativo", C.multiplicador(p, 1000 + C.ESPERA_REPETIR + 1), C.BONUS_MULTIPLICADOR)
	igual("corredor: bônus acaba", C.multiplicador(p, 1000 + C.ESPERA_REPETIR + C.BONUS_DURACAO + 1), 1)
	local estranho = C.normalizar({ fragmentos = -5, concluidas = { ["1"] = "x", ["9"] = 3 }, bonusAte = 0 / 0 })
	igual("corredor: normalizar limpa", estranho.fragmentos + estranho.bonusAte, 0)
	igual("corredor: normalizar ignora fase inválida", estranho.concluidas["9"], nil)
	-- requisitos crescem; o mapa sobe em espiral e fica dentro da parede do Nexo (raio 238)
	for i = 2, C.TOTAL do
		igual("corredor: requisito cresce na fase " .. i, C.FASES[i].requisito > C.FASES[i - 1].requisito, true)
		igual("corredor: ilha " .. i .. " mais alta", M.fases[i].centro[2] > M.fases[i - 1].centro[2], true)
	end
	for _, f in M.fases do
		local dentro = true
		for _, k in { "inicio", "retorno", "fim", "portao" } do
			local pt = f.pontos[k]
			if math.sqrt(pt[1] * pt[1] + pt[3] * pt[3]) > 230 then
				dentro = false
			end
		end
		igual("corredor: pontos da fase " .. f.fase .. " dentro do mapa", dentro, true)
		igual("corredor: fase " .. f.fase .. " tem colisão", #f.colisores > 5, true)
		local ini, fim, por = f.pontos.inicio, f.pontos.fim, f.pontos.portao
		local d1 = math.sqrt((ini[1] - por[1]) ^ 2 + (ini[3] - por[3]) ^ 2)
		local d2 = math.sqrt((fim[1] - por[1]) ^ 2 + (fim[3] - por[3]) ^ 2)
		igual("corredor: a conclusão fica antes do Portão na fase " .. f.fase, d2 < d1, true)
	end
end

-- Ecos (pets) e Núcleos
do
	local P = req("Pets")
	local V = req("PetsVisual")
	local C = req("Corredor")
	igual("ecos: 27 Ecos (18 + 9 exclusivos)", #P.ECOS, 27)
	igual("ecos: 9 Núcleos (6 + 3 exclusivos)", #P.NUCLEOS, 9)
	for _, e in P.ECOS do
		igual("ecos: visual de " .. e.id, V.ecos[e.id] ~= nil, true)
		igual("ecos: raridade de " .. e.id, P.RARIDADES[e.raridade] ~= nil, true)
	end
	for i, n in P.NUCLEOS do
		local soma = 0
		for _, ch in P.chances(n) do
			soma += ch.chance
			igual("ecos: Núcleo " .. i .. " tem só Ecos do seu mundo", P.porId[ch.id].nucleo, i)
		end
		igual("ecos: chances do Núcleo " .. i .. " somam 100%", math.abs(soma - 1) < 1e-9, true)
		igual("ecos: visual do Núcleo " .. i, V.nucleos[i] ~= nil, true)
		if i > 1 and n.exclusivo == P.NUCLEOS[i - 1].exclusivo then
			igual("ecos: Núcleo " .. i .. " mais caro", n.preco > P.NUCLEOS[i - 1].preco, true)
		end
		if n.exclusivo then
			igual("ecos: exclusivo " .. i .. " tem série", type(n.serie), "string")
			for _, ch in P.chances(n) do
				igual("ecos: exclusivo " .. ch.id .. " é Épico ou mais", P.porId[ch.id].raridade >= 4, true)
				igual("ecos: exclusivo " .. ch.id .. " da mesma série", P.porId[ch.id].serie, n.serie)
			end
		end
	end
	-- sorteio: o extremo baixo dá o primeiro, o alto dá o último; prisma só com o 2º número baixo
	local seq = { 0, 0.99 }
	local k = 0
	local eco, prisma = P.sortear(P.NUCLEOS[1], function()
		k += 1
		return seq[k]
	end)
	igual("ecos: sorteio baixo dá o comum", eco, "lasquinho")
	igual("ecos: sem prisma", prisma, false)
	seq, k = { 0.999, 0 }, 0
	eco, prisma = P.sortear(P.NUCLEOS[1], function()
		k += 1
		return seq[k]
	end)
	igual("ecos: sorteio alto dá o raro", eco, "lanterneiro")
	igual("ecos: prisma com número baixo", prisma, true)
	-- coleção: adicionar, equipar com limite, melhores, libertar e multiplicadores
	local c = P.padrao()
	local corredor = C.padrao()
	igual("ecos: 3 espaços no começo", P.slots(corredor), 3)
	corredor.concluidas["3"] = 1
	corredor.concluidas["6"] = 1
	igual("ecos: fases 3 e 6 dão mais 2 espaços", P.slots(corredor), 5)
	igual("ecos: Núcleo 1 trancado sem a fase 1", P.nucleoLiberado(P.NUCLEOS[1], C.padrao()), false)
	local u1 = P.adicionar(c, "lasquinho", false, 0)
	local u2 = P.adicionar(c, "lanterneiro", true, 0)
	local u3 = P.adicionar(c, "mariposa_vitral", false, 0)
	local u4 = P.adicionar(c, "raposa_prisma", false, 0)
	igual("ecos: id inventado não entra", P.adicionar(c, "nada", false, 0), nil)
	igual("ecos: quatro na coleção", P.quantidade(c), 4)
	igual("ecos: equipa", (P.equipar(c, u1, true, 2)), true)
	igual("ecos: equipa o segundo", (P.equipar(c, u2, true, 2)), true)
	igual("ecos: respeita os espaços", (P.equipar(c, u3, true, 2)), false)
	igual("ecos: uid inválido", (P.equipar(c, 5, true, 2)), false)
	local ganho, sorte, frag = P.multiplicadores(c)
	igual("ecos: ganho soma (prisma em dobro)", math.abs(ganho - (1 + (15 + 45 * 2) / 100)) < 1e-9, true)
	igual("ecos: sem sorte equipada", sorte, 1)
	igual("ecos: sem fragmentos equipados", frag, 1)
	igual("ecos: não liberta equipado", (P.libertar(c, u1)), nil)
	P.equiparMelhores(c, 2)
	igual("ecos: melhores começa pelo prismático", c.equipados[1], u2)
	local volta = P.libertar(c, u3)
	igual("ecos: libertar devolve parte do Núcleo", volta, math.floor(P.NUCLEOS[1].preco * P.DEVOLUCAO))
	igual("ecos: some da coleção", c.lista[u3], nil)
	igual("ecos: índice lembra quem já foi visto", c.vistos.mariposa_vitral, true)
	igual("ecos: u4 ainda existe", c.lista[u4] ~= nil, true)
	local n = P.normalizar({ lista = { x = { eco = "nada" }, e9 = { eco = "fagulha", prisma = true } }, equipados = { "e9", "e9", "zz" }, contador = -2 })
	igual("ecos: normalizar descarta Eco inventado", n.lista.x, nil)
	igual("ecos: normalizar mantém válido", n.lista.e9.prisma, true)
	igual("ecos: normalizar remove repetidos e órfãos", #n.equipados, 1)
	igual("ecos: normalizar contador", n.contador, 0)
	-- capacidade
	local cheia = P.padrao()
	for _ = 1, P.CAPACIDADE do
		P.adicionar(cheia, "lasquinho", false, 0)
	end
	igual("ecos: coleção cheia recusa", P.adicionar(cheia, "lasquinho", false, 0), nil)
	-- fragmentos multiplicados na conclusão do Corredor
	local pc = C.padrao()
	local g = C.concluir(pc, 1, 0, 1.5)
	igual("corredor: bônus de Fragmentos dos Ecos", g, math.floor(C.FASES[1].primeira * 1.5 + 0.5))
end

-- Criaturas do Corredor
do
	local K = req("Criaturas")
	local V = req("CriaturasVisual")
	local C = req("Corredor")
	local M = req("CorredorMapa")
	igual("criaturas: uma dupla por fase", #K.FASES, C.TOTAL)
	for i, f in K.FASES do
		for _, id in { f.lacaio, f.chefe } do
			local v = V[id]
			igual("criaturas: visual de " .. id, v ~= nil, true)
			igual("criaturas: " .. id .. " é da fase " .. i, v and v.fase, i)
			local nomes = {}
			for _, p in (v and v.partes or {}) do
				nomes[p.nome] = true
				if p.pai then
					igual("criaturas: pai de " .. id .. "." .. p.nome .. " vem antes", nomes[p.pai], true)
				end
			end
			igual("criaturas: " .. id .. " tem tronco, cabeça, braços e pernas", nomes.tronco and nomes.cabeca and nomes.braco_d and nomes.perna_e, true)
		end
		igual("criaturas: chefe maior que o lacaio na fase " .. i, V[f.chefe].altura > V[f.lacaio].altura * 1.8, true)
		igual("criaturas: chefe tem mais vida na fase " .. i, K.vida(i, "chefe") > K.vida(i, "lacaio") * 5, true)
		if i > 1 then
			igual("criaturas: lacaio mais resistente na fase " .. i, K.vida(i, "lacaio") > K.vida(i - 1, "lacaio"), true)
		end
		-- quem tem a Pontuação mínima derruba o lacaio em ~6 golpes
		local golpes = math.ceil(K.vida(i, "lacaio") / K.danoJogador(math.max(C.FASES[i].requisito, 12)))
		igual("criaturas: lacaio cai em 6 golpes com a Pontuação mínima (fase " .. i .. ")", golpes, 6)
	end
	igual("criaturas: dano cresce com a Pontuação", K.danoJogador(1000) > K.danoJogador(10), true)
	igual("criaturas: Pontuação estranha não quebra", K.danoJogador(0 / 0), 5)
	-- posições: dentro da ilha (largura 44, comprimento 150) e o chefe antes do Portão
	local chefes = 0
	for _, p in K.POSICOES do
		igual("criaturas: posição dentro da ilha", math.abs(p.x) < M.largura / 2 - 4 and math.abs(p.y) < M.comprimento / 2 - 8, true)
		if p.tipo == "chefe" then
			chefes += 1
			igual("criaturas: chefe guarda o fim da ilha", p.y > 40, true)
		end
	end
	igual("criaturas: um chefe por fase", chefes, 1)
	-- recompensas
	local pts, frag = K.recompensa(3, "lacaio", 10, 0.01, 1)
	igual("criaturas: lacaio dá segundos de Pontos", pts, 10 * K.LACAIO.pontos)
	igual("criaturas: lacaio com sorte solta Fragmentos", frag, K.FASES[3].fragmentosLacaio)
	local _, sem = K.recompensa(3, "lacaio", 10, 0.99, 1)
	igual("criaturas: sem sorte, sem Fragmentos", sem, 0)
	local pc, fc = K.recompensa(3, "chefe", 10, 0.01, 1)
	igual("criaturas: chefe dá mais Pontos", pc > pts, true)
	igual("criaturas: chefe não sorteia Fragmentos (o Portão dá)", fc, 0)
	-- paraMundo coincide com o gerador (o centro fica no centro)
	local f1 = M.fases[1]
	local x, y, z = K.paraMundo(f1.centro, f1.giro, 0, 0)
	igual("criaturas: origem da ilha é o centro", math.abs(x - f1.centro[1]) + math.abs(z - f1.centro[3]) < 1e-6 and y == f1.centro[2], true)
end

-- Equipamento (RPG)
do
	local E = req("Equipamento")
	local V = req("EquipamentoVisual")
	igual("equip: 6 conjuntos × 9 espaços", #E.ITENS, 54)
	local pecaVisual = {
		elmo = { "elmo" },
		armadura = { "armadura" },
		manoplas = { "manopla_d", "manopla_e" },
		botas = { "bota_d", "bota_e" },
		arma = { "arma" },
		colar = { "colar" },
		manto = { "manto", "manto_s1", "manto_s2", "manto_s3" },
		bracelete = { "bracelete" },
		aureola = { "aureola" },
	}
	local noGrupo = {}
	for _, g in E.GRUPOS do
		for _, espaco in g.espacos do
			noGrupo[espaco] = (noGrupo[espaco] or 0) + 1
		end
	end
	for _, espaco in E.ESPACOS do
		igual("equip: " .. espaco .. " em um grupo do painel", noGrupo[espaco], 1)
		igual("equip: " .. espaco .. " tem nome", E.NOMES_ESPACOS[espaco] ~= nil, true)
	end
	for _, item in E.ITENS do
		for _, p in pecaVisual[item.espaco] do
			igual("equip: visual de " .. item.id .. " (" .. p .. ")", V[item.conjunto] ~= nil and V[item.conjunto][p] ~= nil, true)
		end
		igual("equip: " .. item.id .. " tem atributo", E.texto(item.atributos) ~= "", true)
	end
	for i = 2, #E.CONJUNTOS do
		local a, b = E.porId[E.CONJUNTOS[i].id .. "_arma"], E.porId[E.CONJUNTOS[i - 1].id .. "_arma"]
		igual("equip: arma do mundo " .. i .. " mais forte", a.atributos.dano > b.atributos.dano, true)
	end
	local c = E.padrao()
	local u1 = E.adicionar(c, "limiar_elmo", 0)
	local u2 = E.adicionar(c, "limiar_armadura", 0)
	local u3 = E.adicionar(c, "limiar_botas", 0)
	local u4 = E.adicionar(c, "dunas_elmo", 0)
	igual("equip: item inventado não entra", E.adicionar(c, "nada", 0), nil)
	igual("equip: equipar", (E.equipar(c, u1, true)), true)
	igual("equip: equipa no espaço certo", c.equipados.elmo, u1)
	E.equipar(c, u4, true)
	igual("equip: trocar no mesmo espaço substitui", c.equipados.elmo, u4)
	E.equipar(c, u1, true)
	E.equipar(c, u2, true)
	E.equipar(c, u3, true)
	igual("equip: uid inválido", (E.equipar(c, 7, true)), false)
	local total = E.total(c)
	-- elmo 4 sorte + armadura 15 vida e 4 ganho + botas 10 ganho + conjunto de 3 (5 sorte)
	igual("equip: soma de sorte com bônus de 3 peças", total.sorte, 4 + 5)
	igual("equip: soma de ganho", total.ganho, 14)
	igual("equip: soma de vida", total.vida, 15)
	igual("equip: multiplicador", math.abs(E.multiplicadores(c).sorte - 1.09) < 1e-9, true)
	-- nível
	local g = c.lista[u3]
	local custo0 = E.custoAprimorar(g)
	g.nivel = 5
	igual("equip: aprimorar fica mais caro", E.custoAprimorar(g) > custo0, true)
	igual("equip: nível sobe os atributos", E.atributos(g).ganho, math.floor(10 * (1 + 5 * E.POR_NIVEL) + 0.5))
	g.nivel = E.NIVEL_MAXIMO
	igual("equip: nível máximo sem custo", E.custoAprimorar(g), nil)
	igual("equip: desmontar devolve mais em nível alto", E.valorDesmontar(g) > E.valorDesmontar({ item = "limiar_botas", nivel = 0, desde = 0 }), true)
	-- ocultar e normalizar
	igual("equip: ocultar espaço", (E.ocultar(c, "elmo", true)), true)
	igual("equip: espaço inventado", (E.ocultar(c, "capa", true)), false)
	local n = E.normalizar({ lista = { q1 = { item = "limiar_arma", nivel = 99 }, x = { item = "nada" } }, equipados = { arma = "q1", elmo = "q1" }, ocultos = { arma = true, nada = true } })
	igual("equip: normalizar limita o nível", n.lista.q1.nivel, E.NIVEL_MAXIMO)
	igual("equip: normalizar descarta item inventado", n.lista.x, nil)
	igual("equip: normalizar confere o espaço", n.equipados.elmo, nil)
	igual("equip: normalizar mantém o certo", n.equipados.arma, "q1")
	igual("equip: normalizar ocultos", n.ocultos.arma, true)
	-- drops
	local seq, k = { 0.0, 0.99 }, 0
	local drop = E.sortearDrop(2, "chefe", function()
		k += 1
		return seq[k]
	end)
	igual("equip: chefe com sorte dá peça do seu mundo", drop, "bosque_aureola")
	k = 0
	seq = { 0.0, 0.0 }
	igual("equip: sorteio cobre o primeiro espaço", E.sortearDrop(2, "chefe", function()
		k += 1
		return seq[k]
	end), "bosque_elmo")
	igual("equip: lacaio sem sorte não dá", E.sortearDrop(2, "lacaio", function()
		return 0.5
	end), nil)
	igual("equip: fase inexistente", E.sortearDrop(9, "chefe", function()
		return 0
	end), nil)
	-- conjunto completo
	local cheio = E.padrao()
	for _, espaco in E.ESPACOS do
		E.equipar(cheio, E.adicionar(cheio, "vazio_" .. espaco, 0), true)
	end
	local t5 = E.total(cheio)
	igual("equip: conjunto completo soma os dois bônus", t5.ganho >= 60 + 150, true)
	-- só acessórios também fecham conjunto
	local leve = E.padrao()
	for _, espaco in { "colar", "manto", "bracelete" } do
		E.equipar(leve, E.adicionar(leve, "limiar_" .. espaco, 0), true)
	end
	local tl = E.total(leve)
	-- colar 3 sorte + bracelete 2 sorte + conjunto de 3 (5 sorte)
	igual("equip: acessórios contam para o conjunto", tl.sorte, 3 + 2 + 5)
	igual("equip: manto dá ganho e vida", tl.vida, 8)
	igual("equip: acessório não ocupa espaço de armadura", leve.equipados.armadura, nil)
end

-- Ciclo de dia e noite
do
	local C = req("Ciclo")
	local soma = 0
	for _, f in C.FASES do
		soma += f.fracao
	end
	igual("ciclo: frações somam uma volta", math.abs(soma - 1) < 1e-9, true)
	igual("ciclo: começa na aurora", C.estado(0).fase, "aurora")
	igual("ciclo: 5 h no início da aurora", C.estado(0).relogio, 5)
	igual("ciclo: dia depois de 2 min", C.estado(2 * 60 + 1).fase, "dia")
	igual("ciclo: crepúsculo aos 10 min", C.estado(10 * 60 + 1).fase, "crepusculo")
	igual("ciclo: noite aos 12 min", C.estado(12 * 60 + 1).fase, "noite")
	igual("ciclo: volta para a aurora", C.estado(C.DURACAO + 1).fase, "aurora")
	igual("ciclo: noite atravessa a meia-noite", C.estado(16 * 60).relogio < 5, true)
	igual("ciclo: relógio sempre de 0 a 24", (function()
		for s = 0, C.DURACAO, 7 do
			local r = C.estado(s).relogio
			if r < 0 or r >= 24 then
				return false
			end
		end
		return true
	end)(), true)
	igual("ciclo: restante até a noite acabar", math.floor(C.estado(12 * 60).restante + 0.5), 8 * 60)
	for _, f in C.FASES do
		igual("ciclo: início da " .. f.id, C.estado(C.inicioDa(f.id) + 0.5).fase, f.id)
	end
	igual("ciclo: noite é a luz original", C.luz(0).brilho, 2.4)
	igual("ciclo: dia mais claro que a noite", C.luz(12).brilho > C.luz(0).brilho, true)
	igual("ciclo: sem estrelas ao meio-dia", C.luz(12).estrelas, 0)
	igual("ciclo: luz mistura entre quadros", C.luz(7.5).brilho > C.luz(6).brilho - 1e-9, true)
	igual("ciclo: tempo formatado", C.tempo(192), "3:12")
end

-- Drops do mapa
do
	local D = req("DropsMapa")
	igual("drops: estrela não aparece de dia", (function()
		for k = 0, 99 do
			if D.sortear(false, function()
				return k / 100
			end) == "estrela" then
				return false
			end
		end
		return true
	end)(), true)
	igual("drops: estrela aparece à noite", D.sortear(true, function()
		return 0.99
	end), "estrela")
	igual("drops: orbe é o mais comum", D.sortear(false, function()
		return 0
	end), "orbe")
	igual("drops: noite mais rápida", D.intervalo(true) < D.intervalo(false), true)
	igual("drops: máximo cresce com jogadores", D.maximo(5) > D.maximo(1), true)
	igual("drops: máximo tem teto", D.maximo(100), 40)
	igual("drops: orbe vale 15 s de ganho", D.premio("orbe", 10, 0).pontos, 150)
	igual("drops: orbe tem mínimo", D.premio("orbe", 0, 0).pontos, D.MINIMO_PONTOS)
	igual("drops: lasca sem Corredor", D.premio("lasca", 10, 0).fragmentos, 1)
	igual("drops: lasca cresce com o Corredor", D.premio("lasca", 10, 4).fragmentos, 5)
	igual("drops: lasca com bônus de Fragmentos", D.premio("lasca", 10, 4, 1.5).fragmentos, 8)
	igual("drops: estrela dá bênção", D.premio("estrela", 10, 0).bencao, true)
	igual("drops: estrela vale mais que o orbe", D.premio("estrela", 10, 0).pontos > D.premio("orbe", 10, 0).pontos, true)
	igual("drops: tipo inventado não dá nada", D.premio("nada", 10, 6).pontos, 0)
	igual("drops: fase máxima", D.faseMaxima({ ["1"] = 3, ["4"] = 1, ["5"] = 0 }), 4)
	igual("drops: fase máxima sem dados", D.faseMaxima(nil), 0)
	igual("drops: ponto dentro do anel", (function()
		for k = 0, 50 do
			local x, z = D.pontoNoAnel(k / 50, (k * 7 % 50) / 50)
			local r = math.sqrt(x * x + z * z)
			if r < D.RAIO_MIN - 1e-6 or r > D.RAIO_MAX + 1e-6 then
				return false
			end
		end
		return true
	end)(), true)
	igual("drops: texto do prêmio", D.texto("lasca", { pontos = 0, fragmentos = 3, bencao = false }), "Lasca de Fragmento! +3 Fragmentos")
end

-- Tutorial (Lume)
do
	local T = req("Tutorial")
	local L = req("LumeVisual")
	local papeis = {}
	for _, p in L do
		papeis[p.papel] = true
	end
	igual("tutorial: retrato tem olhos e boca separados", papeis.olhos == true and papeis.boca == true, true)
	for i, p in T.PASSOS do
		igual("tutorial: passo " .. p.id .. " tem falas", #p.falas > 0, true)
		igual("tutorial: índice de " .. p.id, T.porId[p.id], i)
		if p.objetivo ~= "continuar" then
			igual("tutorial: " .. p.id .. " tem dica", type(p.dica) == "string", true)
		end
	end
	igual("tutorial: novato começa", T.normalizar(nil, 0).concluido, false)
	igual("tutorial: veterano não vê", T.normalizar(nil, 12).concluido, true)
	igual("tutorial: veterano já ganhou os presentes", T.normalizar(nil, 12).presenteAte, #T.PASSOS)
	igual("tutorial: passo inválido vira 1", T.normalizar({ passo = "x" }).passo, 1)
	igual("tutorial: passo acima do total", T.normalizar({ passo = 99 }).passo, #T.PASSOS)
	local nada = { giros = 0, evolucoes = 0 }
	local girou = { giros = 1, evolucoes = 0 }
	local tudo = { giros = 1, evolucoes = 1 }
	local p = T.padrao()
	igual("tutorial: fora de ordem", (T.avancar(p, 2, tudo)), false)
	igual("tutorial: passo 1 avança", (T.avancar(p, 1, nada)), true)
	igual("tutorial: girar exige giro", (T.avancar(p, 2, nada)), false)
	local ok, presente = T.avancar(p, 2, girou)
	igual("tutorial: depois de girar avança", ok, true)
	igual("tutorial: passo 3 sem presente", presente, nil)
	local _, presente4 = T.avancar(p, 3, girou)
	igual("tutorial: entrar em evoluir dá presente", presente4 and presente4.pontos, 40)
	igual("tutorial: evoluir exige evolução", (T.avancar(p, 4, girou)), false)
	T.avancar(p, 4, tudo)
	T.avancar(p, 5, tudo)
	T.avancar(p, 6, tudo)
	local _, presenteFinal = T.avancar(p, 7, tudo)
	igual("tutorial: presente final", presenteFinal and presenteFinal.fragmentos, 5)
	igual("tutorial: concluir no último", (T.avancar(p, 8, tudo)), true)
	igual("tutorial: concluído", p.concluido, true)
	igual("tutorial: não avança depois de concluído", (T.avancar(p, 8, tudo)), false)
	-- rever não repete os presentes
	T.reiniciar(p)
	igual("tutorial: rever volta ao começo", p.passo == 1 and not p.concluido, true)
	T.avancar(p, 1, tudo)
	T.avancar(p, 2, tudo)
	local _, repetido = T.avancar(p, 3, tudo)
	igual("tutorial: rever não repete presente", repetido, nil)
	local q = T.padrao()
	T.pular(q)
	igual("tutorial: pular conclui", q.concluido, true)
	igual("tutorial: texto do presente", T.textoPresente({ pontos = 60, fragmentos = 5 }), "+60 Pontos de Aura · +5 Fragmentos")
	igual("tutorial: sem presente sem texto", T.textoPresente(nil), nil)
end

-- Arena 1x1 (Trono e Rankeada): força, Elo e divisões
do
	local P = req("ArenaPvP")
	igual("pvp: coroa tem malhas", #req("CoroaVisual") >= 2, true)
	local ma, mb = P.multiplicadores(1000, 1000)
	igual("pvp: forças iguais", ma == 1 and mb == 1, true)
	ma, mb = P.multiplicadores(2000, 1000)
	igual("pvp: mais forte bate mais", ma > 1 and mb < 1, true)
	ma, mb = P.multiplicadores(1000000, 1)
	igual("pvp: multiplicador tem teto", ma, P.MULT_MAX)
	igual("pvp: multiplicador tem piso", mb, P.MULT_MIN)
	local nv, np = P.elo(1000, 1000)
	igual("pvp: elo igual +16", nv, 1016)
	igual("pvp: elo igual -16", np, 984)
	local zv = P.elo(1000, 1400)
	igual("pvp: zebra vale mais", zv - 1000 > 16, true)
	local fv = P.elo(1400, 1000)
	igual("pvp: favorito ganha pouco", fv - 1400 < 16 and fv - 1400 >= 1, true)
	igual("pvp: rating não fica negativo", select(2, P.elo(3000, 5)) >= 0, true)
	igual("pvp: divisão inicial", P.divisao(P.RATING_INICIAL).nome, "Bronze")
	igual("pvp: divisão ouro", P.divisao(1300).nome, "Ouro")
	igual("pvp: divisão mestre", P.divisao(2400).nome, "Mestre")
	igual("pvp: janela cresce", P.janela(30) > P.janela(0), true)
	local n = P.normalizar({ rating = -5, vitorias = 3, monarca = "x" })
	igual("pvp: normalizar rating inválido", n.rating, P.RATING_INICIAL)
	igual("pvp: normalizar mantém vitórias", n.vitorias, 3)
	igual("pvp: normalizar monarca", n.monarca, 0)
end

-- Combate reativo (Duelo): PA, golpe no tempo certo, esquivar, aparar, contra-ataque, Ruptura
do
	local D = req("Duelo")
	local A = req("ArenaAnimacoes")
	-- os acertos de cada golpe cabem no clipe da animação
	for id, acao in D.ACOES do
		local clipe = A.JOGADOR[id] or A.SOBERANO[id]
		if #acao.acertos > 0 then
			igual("duelo: clipe de " .. id, clipe ~= nil, true)
			if clipe then
				igual("duelo: acertos de " .. id .. " dentro do clipe", acao.acertos[#acao.acertos] < clipe.duracao, true)
			end
			igual("duelo: dano por acerto de " .. id, #acao.dano, #acao.acertos)
		end
	end
	for _, id in { "esquiva", "aparar", "contra", "concentrar", "rompido" } do
		igual("duelo: clipe do jogador " .. id, A.JOGADOR[id] ~= nil, true)
	end
	for i = 1, 8 do
		igual("duelo: intenção do Soberano tem clipe " .. i, A.SOBERANO[D.intencao(i)] ~= nil, true)
	end
	-- notas
	igual("duelo: toque perfeito", D.notaQte(0.05), "perfeito")
	igual("duelo: toque bom", D.notaQte(-0.15), "bom")
	igual("duelo: toque fora", D.notaQte(0.3), "erro")
	igual("duelo: sem toque", D.notaQte(nil), "erro")
	igual("duelo: aparar no tempo", D.notaDefesa("aparar", 0.1, false, false), "aparado")
	igual("duelo: aparar atrasado", D.notaDefesa("aparar", 0.16, false, false), "atingido")
	igual("duelo: concentrar amplia a janela", D.notaDefesa("aparar", 0.16, false, true), "aparado")
	igual("duelo: golpe absoluto não se apara", D.notaDefesa("aparar", 0, true, false), "atingido")
	igual("duelo: golpe absoluto se esquiva", D.notaDefesa("esquivar", 0.15, true, false), "esquivado")
	igual("duelo: sem defesa", D.notaDefesa(nil, nil, false, false), "atingido")
	-- PA e validação
	local e = D.novo()
	igual("duelo: começa com 1 PA", e.a.pa, D.PA_INICIAL)
	igual("duelo: corte pede 2 PA", D.validar(e, "a", "corte") ~= nil, true)
	igual("duelo: não é a vez de b", D.validar(e, "b", "ataque") ~= nil, true)
	igual("duelo: ação do Soberano não é do jogador", D.validar(e, "a", "trinca") ~= nil, true)
	D.iniciarAcao(e, "a", "ataque")
	local r = D.acerto(e, "a", "ataque", 1, "perfeito", "atingido")
	igual("duelo: ataque perfeito", r.dano, math.floor(85 * D.MULT_QTE.perfeito + 0.5))
	D.terminarAcao(e, "a", "ataque", true)
	igual("duelo: ataque dá 1 PA", e.a.pa, 2)
	igual("duelo: passa a vez", D.passarVez(e), nil)
	igual("duelo: vez do Soberano", e.quem, "b")
	-- defesa e contra-ataque
	D.iniciarAcao(e, "b", "trinca")
	local defs = {}
	for i = 1, 3 do
		defs[i] = D.acerto(e, "b", "trinca", i, "bom", "aparado").defesa
	end
	igual("duelo: aparar não tira vida", e.a.vida, D.VIDA)
	igual("duelo: aparar dá PA", e.a.pa, 5)
	igual("duelo: aparar tudo solta o contra", D.contraAtaca(D.ACOES.trinca, defs), true)
	igual("duelo: um acerto não aparado, sem contra", D.contraAtaca(D.ACOES.trinca, { "aparado", "esquivado", "aparado" }), false)
	igual("duelo: absoluto não dá contra", D.contraAtaca(D.ACOES.pesado, { "aparado" }), false)
	igual("duelo: aparar enche a Ruptura de quem golpeia", e.b.ruptura > 0, true)
	local esquiva = D.acerto(e, "b", "pesado", 1, "bom", "esquivado")
	igual("duelo: esquivar não tira vida", esquiva.dano, 0)
	-- Selo: metade do próximo golpe
	local s = D.novo()
	s.a.pa = 5
	D.iniciarAcao(s, "a", "selo")
	igual("duelo: selo gasta PA", s.a.pa, 3)
	D.acerto(s, "a", "selo", 1, "bom", "atingido")
	D.terminarAcao(s, "a", "selo", true)
	igual("duelo: selo protege", s.a.selado, true)
	igual("duelo: selo enche a Ruptura", s.b.ruptura >= D.RUPTURA.selo, true)
	D.passarVez(s)
	D.iniciarAcao(s, "b", "investida")
	igual("duelo: selo corta pela metade", D.acerto(s, "b", "investida", 1, "bom", "atingido").dano, 55)
	-- Ruptura: cheia, o alvo perde a vez e recebe mais dano
	local rp = D.novo()
	rp.b.ruptura = 99
	local rr = D.acerto(rp, "a", "ataque", 1, "bom", "atingido")
	igual("duelo: rompe", rr.rompeu, true)
	igual("duelo: rompido", rp.b.rompido, true)
	local forte = D.acerto(rp, "a", "ataque", 1, "bom", "atingido")
	igual("duelo: rompido recebe mais dano", forte.dano, math.floor(85 * D.ROMPIDO_DANO + 0.5))
	igual("duelo: rompido perde a vez", D.passarVez(rp), "b")
	igual("duelo: e a vez volta para quem rompeu", rp.quem, "a")
	igual("duelo: sai do rompido", rp.b.rompido, false)
	-- Baluarte
	local bl = D.novo()
	D.iniciarAcao(bl, "b", "baluarte")
	igual("duelo: baluarte reduz", D.acerto(bl, "a", "ataque", 1, "bom", "atingido").dano, math.floor(85 * D.BALUARTE + 0.5))
	-- força no PvP e vencedor
	local pv = D.novo(2, 0.5, 4000, 1000)
	igual("duelo: força dobra o dano", D.acerto(pv, "a", "ataque", 1, "bom", "atingido").dano, 170)
	pv.b.vida = 0
	igual("duelo: vencedor", D.vencedor(pv), "a")
	local dupla = D.novo(1, 1, 500, 900)
	dupla.a.vida, dupla.b.vida = 0, 0
	igual("duelo: queda dupla vai para o mais forte", D.vencedor(dupla), "b")
	local longo = D.novo()
	longo.vez = D.RODADAS_MAX + 1
	longo.a.vida = 10
	igual("duelo: limite de vezes", D.vencedor(longo), "b")
	-- nota do acerto segue a última marca
	igual("duelo: despertar usa a 1ª marca", D.notaDoAcerto(D.ACOES.despertar, { [1] = "perfeito" }, 3), "perfeito")
	igual("duelo: golpe do Soberano sem anel", D.notaDoAcerto(D.ACOES.trinca, {}, 2), "bom")
	local v = D.visao(D.novo(), "b")
	igual("duelo: visão", v.minhaVez == false and v.oponente.vida == D.VIDA, true)
end

print(string.format("%d testes, %d falhas", total, falhas))
