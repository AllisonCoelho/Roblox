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

-- Trava de sessão do DataStore -------------------------------------------------
local Sessao = req("Sessao")
local T = 1000000
local r = Sessao.travar(nil, "A", T)
igual("trava em registro vazio", r and r.sessao and r.sessao.jobId, "A")
local ocupado, motivo = Sessao.travar(r, "B", T + 10)
igual("outro servidor fica de fora", ocupado, nil)
igual("motivo ocupado", motivo, "ocupado")
local roubado = Sessao.travar({ sessao = { jobId = "B", ts = T } }, "A", T + Sessao.EXPIRA)
igual("trava abandonada pode ser assumida", roubado and roubado.sessao.jobId, "A")
local renovado = Sessao.travar({ sessao = { jobId = "A", ts = T } }, "A", T + 5)
igual("mesmo servidor renova a trava", renovado and renovado.sessao.ts, T + 5)
local antigo = Sessao.normalizar({ versao = 1, moedas = 5 })
igual("formato antigo vira envelope", antigo.dados and antigo.dados.moedas, 5)
igual("formato antigo sem trava", antigo.sessao, nil)

local salvo = Sessao.salvar({ sessao = { jobId = "A", ts = T } }, "A", T + 60, { moedas = 9 }, false)
igual("salva com a trava", salvo and salvo.dados.moedas, 9)
igual("salvar renova a trava", salvo and salvo.sessao.ts, T + 60)
local solto = Sessao.salvar({ sessao = { jobId = "A", ts = T } }, "A", T + 60, { moedas = 9 }, true)
igual("sair solta a trava", solto and solto.sessao, nil)
local negado, m2 = Sessao.salvar({ sessao = { jobId = "B", ts = T } }, "A", T, { moedas = 1 }, false)
igual("não salva com trava de outro", negado, nil)
igual("motivo sem_trava", m2, "sem_trava")
igual("não salva sem trava", (Sessao.salvar({ dados = {} }, "A", T, {}, false)), nil)

-- Troca rápida de servidor: A tem a trava, B espera; A sai e solta; B entra;
-- um autosave atrasado de A não pode sobrescrever B.
local banco = Sessao.travar(nil, "A", T)
igual("B espera enquanto A joga", (Sessao.travar(banco, "B", T + 1)), nil)
banco = Sessao.salvar(banco, "A", T + 2, { moedas = 100 }, true)
banco = Sessao.travar(banco, "B", T + 3)
igual("B entra depois que A solta", banco and banco.sessao.jobId, "B")
igual("B recebe o progresso salvo por A", banco and banco.dados.moedas, 100)
igual("autosave atrasado de A é recusado", (Sessao.salvar(banco, "A", T + 4, { moedas = 1 }, false)), nil)
igual("B continua com o progresso certo", banco and banco.dados.moedas, 100)

-- Planta do mapa --------------------------------------------------------------
local Mapa = req("Mapa")
local rets = Mapa.retangulos()
for _, r in rets do
  igual("dentro do chão " .. r.nome, r.minX >= -Mapa.LimiteChao and r.maxX <= Mapa.LimiteChao and r.minZ >= -Mapa.LimiteChao and r.maxZ <= Mapa.LimiteChao, true)
end
-- Nada se sobrepõe (com 2 studs de folga para dar para andar entre as coisas)
for i = 1, #rets do
  for j = i + 1, #rets do
    local a, b = rets[i], rets[j]
    -- A esteira sai da porta da fábrica: as duas encostam de propósito (folga 0)
    local folga = if (a.nome == "Fabrica" and b.nome == "Esteira") then 0 else 2
    local separados = a.maxX + folga <= b.minX or b.maxX + folga <= a.minX or a.maxZ + folga <= b.minZ or b.maxZ + folga <= a.minZ
    igual("sem sobreposição " .. a.nome .. " x " .. b.nome, separados, true)
  end
end
-- Pedestais cabem no lote e não ficam em cima do caixa nem do escudo
local maxPedestais = Mapa.PedestalColunas * Mapa.PedestalLinhas
igual("28 pedestais para a vitrine nível máximo", maxPedestais, 8 + 4 * 5)
for i = 1, maxPedestais do
  local p = Mapa.pedestalLocal(i)
  igual("pedestal " .. i .. " dentro da largura", math.abs(p.X) <= Mapa.LoteLargura / 2 - 2, true)
  igual("pedestal " .. i .. " dentro da profundidade", math.abs(p.Z) <= Mapa.LoteProfundidade / 2 - 2, true)
  igual("pedestal " .. i .. " longe do caixa", (p - Mapa.CaixaLocal).Magnitude > 4.5, true)
  igual("pedestal " .. i .. " longe do escudo", (p - Mapa.EscudoLocal).Magnitude > 4.5, true)
end
for i, lote in Mapa.Lotes do
  igual("centro do lote " .. i .. " é do lote", Mapa.dentroDoLote(i, lote.centro), true)
  igual("esteira não é do lote " .. i, Mapa.dentroDoLote(i, Vector3.new(0, 0, lote.centro.Z)), false)
  igual("entrada do lote " .. i .. " é do lote", Mapa.dentroDoLote(i, Mapa.cframeLote(i):PointToWorldSpace(Mapa.EntradaLocal)), true)
  -- A frente (portão) aponta para a esteira
  local frenteMundo = Mapa.cframeLote(i):PointToWorldSpace(Vector3.new(0, 0, -Mapa.LoteProfundidade / 2))
  igual("portão do lote " .. i .. " virado para a esteira", math.abs(frenteMundo.X) < math.abs(lote.centro.X), true)
  for j, outro in Mapa.Lotes do
    if j ~= i then
      igual("lote " .. i .. " não pega o centro do lote " .. j, Mapa.dentroDoLote(i, outro.centro), false)
    end
  end
end

-- Esteira ----------------------------------------------------------------------
local Est = req("Esteira")
local inicioEst = Est.posicao(100, 100)
igual("esteira começa no início", inicioEst == Mapa.Esteira.inicio + Vector3.new(0, Mapa.Esteira.altura, 0), true)
local fimEst = Est.posicao(100, 100 + Est.duracao())
igual("esteira termina no fim", (fimEst - (Mapa.Esteira.fim + Vector3.new(0, Mapa.Esteira.altura, 0))).Magnitude < 1e-6, true)
igual("não passa do fim", (Est.posicao(100, 100 + Est.duracao() * 3) - fimEst).Magnitude < 1e-6, true)
igual("não volta antes do início", Est.posicao(100, 50) == inicioEst, true)
igual("meio do caminho", (Est.posicao(0, Est.duracao() / 2) - (inicioEst + fimEst) / 2).Magnitude < 1e-6, true)
igual("preço normal", Est.preco("pacoca", "normal"), 400)
igual("preço dourado", Est.preco("pacoca", "dourado"), 800)
igual("preço arco-íris", Est.preco("pacoca", "arcoiris"), 2000)
igual("preço inválido", Est.preco("nada", "normal"), 0)

local function contar(sorte)
  local semente = 12345
  local function rng()
    semente = (semente * 1103515245 + 12345) % 2147483648
    return semente / 2147483648
  end
  local porRaridade, porVariante = {}, {}
  local N = 40000
  for _ = 1, N do
    local id, var = Est.sortear(rng, sorte)
    local r = Catalogo.docinho(id).raridade
    porRaridade[r] = (porRaridade[r] or 0) + 1
    porVariante[var] = (porVariante[var] or 0) + 1
  end
  return porRaridade, porVariante, N
end
local pr, pv, N = contar(false)
igual("secreto nunca sai na esteira", pr.secreto, nil)
igual("comum ~60%", math.abs(pr.comum / N - 0.6) < 0.02, true)
igual("incomum ~25%", math.abs(pr.incomum / N - 0.25) < 0.02, true)
igual("raro ~10%", math.abs(pr.raro / N - 0.10) < 0.015, true)
igual("lendário é raro (<2%)", (pr.lendario or 0) / N < 0.02, true)
igual("dourado ~5%", math.abs((pv.dourado or 0) / N - 0.045) < 0.01, true)
igual("arco-íris ~0,5%", math.abs((pv.arcoiris or 0) / N - 0.005) < 0.003, true)
local prSorte = contar(true)
igual("sorte aumenta raros", prSorte.raro > pr.raro, true)
igual("sorte aumenta épicos", prSorte.epico > pr.epico, true)
igual("sorte diminui comuns", prSorte.comum < pr.comum, true)
igual("sorteio com aleatório 0 dá o primeiro", (Est.sortear(function() return 0 end, false)), "balaDeCoco")
igual("sorteio com aleatório ~1 não quebra", Catalogo.docinho((Est.sortear(function() return 0.9999999 end, false))) ~= nil, true)

print(string.format("%d testes, %d falhas", total, falhas))
