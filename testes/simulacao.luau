-- Relatório de balanceamento (não faz parte dos testes). Rode com: python3 testes/rodar.py simulacao
local Simulador = req("Simulador")
local Catalogo = req("Catalogo")
local Esteira = req("Esteira")
local Formato = req("Formato")
local tempoFmt = Simulador.tempoFmt
local simular = Simulador.simular

-- Chance de cada raridade aparecer na esteira e o tempo médio entre duas aparições
print("## Esteira: com que frequência cada raridade aparece\n")
print("| Raridade | Peso | Chance por Docinho | Tempo médio entre aparições |")
print("|---|---|---|---|")
local totalPeso = 0
for _, p in Esteira.Pesos do totalPeso += p end
local ordem = {}
for id, r in Catalogo.Raridades do table.insert(ordem, r) end
table.sort(ordem, function(a, b) return a.ordem < b.ordem end)
for _, r in ordem do
  local peso = Esteira.Pesos[r.id] or 0
  if peso > 0 then
    local chance = peso / totalPeso
    print(string.format("| %s | %s | %.2f%% | %s |", r.nome, tostring(peso), chance * 100, tempoFmt(Esteira.Intervalo / chance)))
  end
end

local PERFIS = { Simulador.PERFIS.casual, Simulador.PERFIS.dedicado }
local SEMENTES = { 11, 23, 37, 41, 59 }

for _, perfil in PERFIS do
  print("\n## " .. perfil.nome .. string.format(" — média de %d jogos de %d h\n", #SEMENTES, perfil.horas))
  local somaMarcos, contaMarcos = {}, {}
  local rendaMedia = {}
  local renasc = {}
  for _, semente in SEMENTES do
    local r = simular(perfil, semente)
    for nome, quando in r.marcos do
      somaMarcos[nome] = (somaMarcos[nome] or 0) + quando
      contaMarcos[nome] = (contaMarcos[nome] or 0) + 1
    end
    for i, linha in r.renda do
      rendaMedia[i] = rendaMedia[i] or { linha[1], 0, 0, 0 }
      rendaMedia[i][2] += linha[2] / #SEMENTES
      rendaMedia[i][4] += linha[4] / #SEMENTES
    end
    for i, quando in r.renasceuEm do
      renasc[i] = renasc[i] or { 0, 0 }
      renasc[i][1] += quando
      renasc[i][2] += 1
    end
  end
  local lista = {}
  for nome, soma in somaMarcos do
    table.insert(lista, { nome = nome, media = soma / contaMarcos[nome], vezes = contaMarcos[nome] })
  end
  table.sort(lista, function(a, b) return a.media < b.media end)
  print("| Marco | Quando (média) | Em quantos jogos |")
  print("|---|---|---|")
  for _, m in lista do
    print(string.format("| %s | %s | %d/%d |", m.nome, tempoFmt(m.media), m.vezes, #SEMENTES))
  end
  for i, r in renasc do
    print(string.format("| Renascer %d | %s | %d/%d |", i, tempoFmt(r[1] / r[2]), r[2], #SEMENTES))
  end
  print("\n| Tempo de jogo | Renda média | Docinhos na vitrine |")
  print("|---|---|---|")
  for _, linha in rendaMedia do
    print(string.format("| %s | %s/s | %.0f |", tempoFmt(linha[1]), Formato.curto(math.floor(linha[2])), linha[4]))
  end
end
