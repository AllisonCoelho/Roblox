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
-- Chuvisco a cada 20 minutos; a grande de sábado tem prioridade
local g
a, f, g = Evento.chuva(SAB + 60)
igual("chuva grande ativa", a, true); igual("chuva grande resta", f, 540); igual("é a grande", g, true)
local Q = SAB - 86400 * 3 -- quarta, 18:00 UTC (múltiplo de 20 min)
a, f, g = Evento.chuva(Q + 10)
igual("chuvisco ativo", a, true); igual("chuvisco resta", f, Evento.ChuviscoDuracao - 10); igual("chuvisco não é grande", g, false)
a, f, g = Evento.chuva(Q + Evento.ChuviscoDuracao)
igual("chuvisco acabou", a, false); igual("próximo chuvisco", f, Evento.ChuviscoIntervalo - Evento.ChuviscoDuracao); igual("próximo é chuvisco", g, false)
a, f, g = Evento.chuva(SAB - 300)
igual("antes da grande", a, false); igual("grande em 5 min", f, 300); igual("próxima é a grande", g, true)
a, f, g = Evento.chuva(SAB + 600)
igual("depois da grande", a, false); igual("depois da grande vem chuvisco", g, false)
local chuviscosNoDia = 0
for s = 0, 86400 - 1, 30 do
  local at, _, gr = Evento.chuva(Q - 18 * 3600 + s)
  if at and not gr and s % 1200 == 0 then chuviscosNoDia += 1 end
end
igual("72 chuviscos por dia", chuviscosNoDia, 72)

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
-- Pacotes de granulados e entrega de compras (ProcessReceipt)
local idsPacotes, precoAnterior, taxaAnterior = {}, 0, 0
for _, p in Loja.Pacotes do
  igual("pacote id único " .. p.id, idsPacotes[p.id], nil)
  idsPacotes[p.id] = true
  igual("pacote busca " .. p.id, Loja.pacote(p.id), p)
  igual("pacote preço sobe " .. p.id, p.precoRobux > precoAnterior, true)
  local taxa = p.granulados / p.precoRobux
  igual("pacote maior rende mais por Robux " .. p.id, taxa > taxaAnterior, true)
  precoAnterior, taxaAnterior = p.precoRobux, taxa
end
igual("produto 0 não é pacote", Loja.pacoteDoProduto(0), nil)
local compra = { granulados = 10, recibos = {} }
local pac = Loja.Pacotes[2]
igual("recibo novo entrega", Loja.aplicarRecibo(compra, "c1", pac), "entregue")
igual("recibo soma granulados", compra.granulados, 10 + pac.granulados)
igual("recibo repetido não entrega", Loja.aplicarRecibo(compra, "c1", pac), "repetida")
igual("recibo repetido mantém granulados", compra.granulados, 10 + pac.granulados)
igual("recibo de produto desconhecido", Loja.aplicarRecibo(compra, "c2", nil), "invalida")
igual("recibo inválido não guarda id", #compra.recibos, 1)
for i = 1, Loja.MaxRecibos + 5 do
  Loja.aplicarRecibo(compra, "x" .. i, Loja.Pacotes[1])
end
igual("recibos ficam limitados", #compra.recibos, Loja.MaxRecibos)
igual("recibo mais novo fica", compra.recibos[#compra.recibos], "x" .. (Loja.MaxRecibos + 5))
igual("recibo mais velho sai", table.find(compra.recibos, "c1"), nil)
igual("padrao tem recibos vazios", #Economia.padrao().recibos, 0)

for _, dia in Presentes.Dias do
  if dia.boost then igual("boost do presente existe " .. dia.boost, Loja.boost(dia.boost) ~= nil, true) end
  if dia.docinho then igual("docinho do presente existe", Catalogo.docinho(dia.docinho) ~= nil, true) end
end

-- Conquistas -----------------------------------------------------------------
local Conquistas = req("Conquistas")
local idsConq = {}
for _, c in Conquistas.Lista do
  igual("conquista id único " .. c.id, idsConq[c.id], nil)
  idsConq[c.id] = true
  igual("conquista busca " .. c.id, Conquistas.conquista(c.id), c)
end
igual("no máximo 10 emblemas (1 consulta CheckUserBadgesAsync)", #Conquistas.Lista <= 10, true)
local function tem(lista, id) return table.find(lista, id) ~= nil end
local novo = Economia.padrao()
local c0 = Conquistas.doEstado(novo)
igual("jogador novo: só boas-vindas", #c0, 1)
igual("jogador novo: boas-vindas", tem(c0, "bemVindo"), true)
novo.album.brigadeiro = { qtd = 1, desde = 0, dourado = false, arcoiris = false }
igual("primeiro Docinho", tem(Conquistas.doEstado(novo), "primeiroDocinho"), true)
igual("comum não é lendário", tem(Conquistas.doEstado(novo), "lendario"), false)
novo.album.brigadeiro.dourado = true
igual("dourado", tem(Conquistas.doEstado(novo), "dourado"), true)
local idLend
for _, d in Catalogo.Lista do
  local r = Catalogo.raridadeDe(d.id)
  if r and r.ordem >= 5 then idLend = d.id break end
end
novo.album[idLend] = { qtd = 1, desde = 0, dourado = false, arcoiris = false }
igual("lendário", tem(Conquistas.doEstado(novo), "lendario"), true)
igual("álbum incompleto", tem(Conquistas.doEstado(novo), "albumCompleto"), false)
for _, d in Catalogo.Lista do
  novo.album[d.id] = novo.album[d.id] or { qtd = 1, desde = 0, dourado = false, arcoiris = false }
end
igual("álbum completo", tem(Conquistas.doEstado(novo), "albumCompleto"), true)
novo.moedas = 999999
igual("quase milionário", tem(Conquistas.doEstado(novo), "milionario"), false)
novo.moedas = 1000000
igual("milionário", tem(Conquistas.doEstado(novo), "milionario"), true)
novo.renascimentos = 1
igual("renascido", tem(Conquistas.doEstado(novo), "renascer"), true)
for _, id in Conquistas.doEstado(novo) do
  igual("conquista do estado existe " .. id, Conquistas.conquista(id) ~= nil, true)
end
igual("padrao tem conquistas vazias", next(Economia.padrao().conquistas), nil)

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

-- Resgate ---------------------------------------------------------------------
local Resgate = req("Resgate")
local function contexto(mudar)
  local c = {
    agora = 10000, mesmoJogador = false, escudoAte = 0, docinhosNaVitrine = 5,
    ultimoResgateSofrido = nil, ultimoResgateFeito = nil, carregando = false,
    espacoNaVitrine = true, temVitrine = true, distancia = 4, slotValido = true,
  }
  for k, v in mudar or {} do c[k] = v end
  return c
end
igual("resgate permitido no caso normal", (Resgate.pode(contexto())), true)
local casos = {
  { "própria vitrine", { mesmoJogador = true } },
  { "sem vitrine", { temVitrine = false } },
  { "já carregando", { carregando = true } },
  { "pedestal vazio", { slotValido = false } },
  { "escudo ligado", { escudoAte = 10001 } },
  { "vitrine de iniciante", { docinhosNaVitrine = Resgate.MinimoNaVitrine - 1 } },
  { "vítima imune", { ultimoResgateSofrido = 10000 - Resgate.ImunidadeVitima + 1 } },
  { "recarga de quem resgata", { ultimoResgateFeito = 10000 - Resgate.RecargaQuemResgata + 1 } },
  { "longe demais", { distancia = Resgate.Distancia + 0.1 } },
  { "vitrine cheia", { espacoNaVitrine = false } },
}
for _, caso in casos do
  local ok, motivo = Resgate.pode(contexto(caso[2]))
  igual("resgate bloqueado: " .. caso[1], ok, false)
  igual("motivo explicado: " .. caso[1], type(motivo) == "string" and #motivo > 0, true)
end
igual("escudo acabou: pode", (Resgate.pode(contexto({ escudoAte = 10000 }))), true)
igual("imunidade acabou: pode", (Resgate.pode(contexto({ ultimoResgateSofrido = 10000 - Resgate.ImunidadeVitima }))), true)
igual("recarga acabou: pode", (Resgate.pode(contexto({ ultimoResgateFeito = 10000 - Resgate.RecargaQuemResgata }))), true)
igual("vitrine com o mínimo: pode", (Resgate.pode(contexto({ docinhosNaVitrine = Resgate.MinimoNaVitrine }))), true)
igual("na distância limite: pode", (Resgate.pode(contexto({ distancia = Resgate.Distancia }))), true)
local _, msgRecarga = Resgate.pode(contexto({ ultimoResgateFeito = 10000 - 10 }))
igual("recarga diz quanto falta", msgRecarga, "Espere " .. (Resgate.RecargaQuemResgata - 10) .. " s para resgatar de novo")
igual("prompt de resgate alcança o pedestal", Resgate.Distancia - 2 > 0, true)

-- Chuva de Doces --------------------------------------------------------------
local ChuvaD = req("Chuva")
igual("chuva não cai na fábrica", ChuvaD.pontoLivre(Mapa.Fabrica.centro.X, Mapa.Fabrica.centro.Z), false)
igual("chuva não cai na esteira", ChuvaD.pontoLivre(0, 0), false)
for i, lote in Mapa.Lotes do
  igual("chuva não cai na vitrine " .. i, ChuvaD.pontoLivre(lote.centro.X, lote.centro.Z), false)
end
igual("chuva não cai fora da área", ChuvaD.pontoLivre(ChuvaD.Area + 1, 0), false)
igual("chuva cai no campo aberto", ChuvaD.pontoLivre(-100, -100), true)
do
  local semente = 777
  local function rng()
    semente = (semente * 1103515245 + 12345) % 2147483648
    return semente / 2147483648
  end
  local achados = 0
  for _ = 1, 500 do
    local p = ChuvaD.sortearPonto(rng)
    if p then
      achados += 1
      igual("ponto sorteado é livre", ChuvaD.pontoLivre(p.X, p.Z), true)
    end
  end
  igual("quase sempre acha ponto livre", achados >= 495, true)
end
igual("começa lá em cima", ChuvaD.alturaNoAr(50, 50), ChuvaD.AlturaQueda)
igual("chega no chão", ChuvaD.alturaNoAr(50, 50 + ChuvaD.Queda), 0)
igual("não fura o chão", ChuvaD.alturaNoAr(50, 50 + ChuvaD.Queda * 5), 0)
igual("cai cada vez mais rápido", ChuvaD.AlturaQueda - ChuvaD.alturaNoAr(0, ChuvaD.Queda / 2) < ChuvaD.alturaNoAr(0, ChuvaD.Queda / 2), true)
igual("no ar não dá para pegar", ChuvaD.pousou(0, ChuvaD.Queda - 0.01), false)
igual("pousou dá para pegar", ChuvaD.pousou(0, ChuvaD.Queda), true)

-- Correções da fase 4 -------------------------------------------------------------
igual("venda normal = metade do preço", Est.valorVenda("pacoca", "normal"), 200)
igual("venda dourada vale o dobro", Est.valorVenda("pacoca", "dourado"), 400)
igual("venda arco-íris vale 5x", Est.valorVenda("pacoca", "arcoiris"), 1000)
do
  local semente = 4242
  local function rng()
    semente = (semente * 1103515245 + 12345) % 2147483648
    return semente / 2147483648
  end
  local secretosEsteira, secretosChuva = 0, 0
  for _ = 1, 100000 do
    if Est.sortear(rng, true) == "coxinha" then secretosEsteira += 1 end
    if Est.sortear(rng, true, ChuvaD.PesoSecreto) == "coxinha" then secretosChuva += 1 end
  end
  igual("Secreto nunca sai na esteira", secretosEsteira, 0)
  igual("Secreto sai na chuva (raro)", secretosChuva > 30 and secretosChuva < 300, true)
end
local eAlbum = Economia.padrao()
igual("álbum vazio não está completo", Economia.albumCompleto(eAlbum), false)
for _, d in Catalogo.Lista do eAlbum.album[d.id] = { qtd = 1, desde = 0, dourado = false, arcoiris = false } end
igual("álbum com todos está completo", Economia.albumCompleto(eAlbum), true)
eAlbum.album.coxinha = nil
igual("sem o Secreto não está completo", Economia.albumCompleto(eAlbum), false)
igual("padrão tem prêmios vazios", next(Economia.padrao().premios), nil)

-- Renascer --------------------------------------------------------------------
igual("primeiro renascer custa 2,5 mi", Economia.custoRenascer(0), 2500000)
igual("segundo custa 10 mi", Economia.custoRenascer(1), 10000000)
igual("sem renascer: x1", Economia.multiplicadorRenascer(0), 1)
igual("2 renascimentos: x1,5", Economia.multiplicadorRenascer(2), 1.5)
local eR = Economia.padrao()
table.insert(eR.vitrine, { id = "brigadeiro", variante = "normal" })
eR.renascimentos = 2
igual("renda com renascer", Economia.rendaPorSegundo(eR, 0), 450)
eR.passes.vip = true
igual("renascer soma com VIP", Economia.rendaPorSegundo(eR, 0), 900)
igual("padrão começa sem renascer", Economia.padrao().renascimentos, 0)

print(string.format("%d testes, %d falhas", total, falhas))
