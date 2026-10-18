-- Testes da lógica de src/shared. Rode com: python3 testes/rodar.py
local falhas, total = 0, 0
local function igual(nome, obtido, esperado)
  total += 1
  if obtido ~= esperado then
    falhas += 1
    print(string.format("FALHOU %s: obtido=%s esperado=%s", nome, tostring(obtido), tostring(esperado)))
  end
end
local Formato = req("Formato")
igual("inteiro 12450", Formato.inteiro(12450), "12.450")
igual("inteiro 0", Formato.inteiro(0), "0")
igual("inteiro 999", Formato.inteiro(999), "999")
igual("inteiro 1000", Formato.inteiro(1000), "1.000")
igual("inteiro -1500", Formato.inteiro(-1500), "-1.500")
igual("inteiro 1234567", Formato.inteiro(1234567), "1.234.567")
igual("curto 5000", Formato.curto(5000), "5.000")
igual("curto 15000", Formato.curto(15000), "15 mil")
igual("curto 80000", Formato.curto(80000), "80 mil")
igual("curto 1.2mi", Formato.curto(1200000), "1,2 mi")
igual("curto 1bi", Formato.curto(1e9), "1 bi")
igual("curto 381", Formato.curto(381), "381")
igual("tempo 42", Formato.tempo(42), "0:42")
igual("tempo 3725", Formato.tempo(3725), "1:02:05")
igual("tempo 97200", Formato.tempo(97200), "1d 03:00")
igual("tempo negativo", Formato.tempo(-5), "0:00")

local Evento = req("Evento")
local SAB = 1792260000 -- sábado 2026-10-17 18:00:00 UTC
local a, f = Evento.estado(SAB + 60)
igual("evento ativo", a, true); igual("evento resta", f, 540)
a, f = Evento.estado(SAB - 60)
igual("evento antes", a, false); igual("evento falta", f, 60)
a, f = Evento.estado(SAB + 600)
igual("evento acabou", a, false); igual("evento proxima semana", f, 7 * 86400 - 600)
a, f = Evento.estado(SAB - 86400 * 3)
igual("evento quarta", a, false); igual("evento falta 3 dias", f, 86400 * 3)

local Presentes = req("Presentes")
local MEIA_NOITE_BRT = 1792292400 -- 2026-10-18 03:00:00 UTC = 00:00 em Brasília
igual("dia vira na meia-noite BRT", Presentes.diaAtual(MEIA_NOITE_BRT) - Presentes.diaAtual(MEIA_NOITE_BRT - 1), 1)
igual("mesmo dia BRT", Presentes.diaAtual(MEIA_NOITE_BRT + 86399), Presentes.diaAtual(MEIA_NOITE_BRT))

local Missoes = req("Missoes")
for dia = 20000, 20010 do
  local l = Missoes.doDia(dia)
  igual("3 missões dia " .. dia, #l, 3)
  local vistos = {}
  for _, id in l do
    igual("missão existe " .. id, Missoes.missao(id) ~= nil, true)
    igual("missão repetida " .. id, vistos[id], nil)
    vistos[id] = true
  end
  igual("sorteio determinístico", table.concat(Missoes.doDia(dia), ","), table.concat(l, ","))
end

local Catalogo = req("Catalogo")
igual("10 docinhos", #Catalogo.Lista, 10)
for _, d in Catalogo.Lista do
  igual("raridade válida " .. d.id, Catalogo.Raridades[d.raridade] ~= nil, true)
end
igual("renda dourado", Catalogo.rendaDe("brigadeiro", "dourado"), 600)
igual("renda variante inválida", Catalogo.rendaDe("brigadeiro", "xyz"), 300)
igual("renda id inválido", Catalogo.rendaDe("nada"), 0)

local Economia = req("Economia")
local e = Economia.padrao()
igual("capacidade inicial", Economia.capacidadeVitrine(e), 8)
e.melhorias.vitrine = 2
igual("capacidade nível 2", Economia.capacidadeVitrine(e), 16)
table.insert(e.vitrine, { id = "brigadeiro", variante = "normal" })
table.insert(e.vitrine, { id = "beijinho", variante = "dourado" })
igual("renda base", Economia.rendaPorSegundo(e, 1000), 304)
e.passes.vip = true
igual("renda vip", Economia.rendaPorSegundo(e, 1000), 608)
e.boosts.moedas2x = 2000
igual("renda vip+boost", Economia.rendaPorSegundo(e, 1000), 1216)
igual("boost expirado", Economia.rendaPorSegundo(e, 3000), 608)
igual("escudo base", Economia.duracaoEscudo(Economia.padrao()), 60)
igual("caixa offline base", Economia.limiteCaixaSegundos(Economia.padrao()), 7200)
igual("padrao novo a cada chamada", Economia.padrao().vitrine ~= Economia.padrao().vitrine, true)

local Loja = req("Loja")
igual("custo nível 0", Loja.proximoCusto("vitrine", 0), 5000)
igual("custo máximo", Loja.proximoCusto("vitrine", 5), nil)
igual("custo item inválido", Loja.proximoCusto("xyz", 0), nil)
for _, dia in Presentes.Dias do
  if dia.boost then igual("boost do presente existe " .. dia.boost, Loja.boost(dia.boost) ~= nil, true) end
  if dia.docinho then igual("docinho do presente existe", Catalogo.docinho(dia.docinho) ~= nil, true) end
end

print(string.format("%d testes, %d falhas", total, falhas))
