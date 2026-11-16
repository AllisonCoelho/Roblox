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

local Perfil = req("Perfil")
local p = Perfil.padrao()
igual("versao", p.versao, 1)
igual("giros iniciais", p.giros, 0)
igual("colecao vazia", next(p.auras), nil)
igual("equipada vazia", p.equipada, nil)
igual("auto desligado", p.configuracoes.giroAutomatico, false)
igual("perfis independentes", Perfil.padrao().auras ~= Perfil.padrao().auras, true)

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
igual("rng 0 = mais rara", Auras.sortear(function() return 0 end).id, "despertar_absoluto")
igual("rng alto = mais comum", Auras.sortear(function() return 0.9999 end).id, "faisca")
local soma = 0
for _, a in Auras.lista do
	soma += Auras.probabilidadeReal(a.id)
end
igual("probabilidades somam 1", math.abs(soma - 1) < 1e-9, true)
igual("rara quase nominal", math.abs(Auras.probabilidadeReal("despertar_absoluto") - 1e-6) < 1e-9, true)
math.randomseed(42)
local N, contagem = 200000, {}
for _ = 1, N do
	local a = Auras.sortear(math.random)
	contagem[a.id] = (contagem[a.id] or 0) + 1
end
for _, id in { "faisca", "pedra_viva", "trovao_jovem" } do
	local esperado = Auras.probabilidadeReal(id) * N
	igual("frequencia " .. id, math.abs((contagem[id] or 0) - esperado) < esperado * 0.1, true)
end
igual("melhor da colecao", Auras.melhorDe({ faisca = 3, chama_azul = 1, inexistente = 9 }).id, "chama_azul")
igual("colecao vazia sem melhor", Auras.melhorDe({}), nil)
igual("descobertas", Auras.contarDescobertas({ faisca = 1, brasa = 0, x = 2 }), 1)
print(string.format("%d testes, %d falhas", total, falhas))
