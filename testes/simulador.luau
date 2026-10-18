-- Simulador de balanceamento: um jogador comprando na esteira durante horas, usando as
-- mesmas regras do jogo (Catalogo, Economia, Esteira, Loja). Usado pelo relatório
-- (testes/simulacao.luau) e pelas asserções de ritmo em testes/logica.luau.
local Simulador = {}
local Catalogo = req("Catalogo")
local Economia = req("Economia")
local Esteira = req("Esteira")
local Loja = req("Loja")
local Formato = req("Formato")

-- Gerador simples e repetível (mesmo resultado em toda execução)
local function gerador(semente)
  local s = semente
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

local function rendaDe(item)
  return Catalogo.rendaDe(item.id, item.variante)
end

function Simulador.tempoFmt(seg)
  if not seg then return "—" end
  if seg < 60 then
    return string.format("%d s", math.floor(seg + 0.5))
  end
  if seg < 3600 then
    return string.format("%d min", math.floor(seg / 60 + 0.5))
  end
  return string.format("%.1f h", seg / 3600)
end

-- perfil: { nome, viagemExtra (s gastos além de andar), gastaFracao (quanto do saldo topa
-- gastar em melhorias que não rendem), horas }
function Simulador.simular(perfil, semente)
  local rnd = gerador(semente)
  local estado = Economia.padrao()
  local t, dt = 0, 0.5
  local fim = perfil.horas * 3600
  local esteira = {} -- { id, variante, nasceu }
  local proximoSpawn = 0
  local carregandoAte, carga = nil, nil
  local marcos = {}
  local renda = {}
  local checkpoints = { 5 * 60, 15 * 60, 30 * 60, 3600, 2 * 3600, 5 * 3600, 10 * 3600 }
  local proximoCheck = 1
  local renasceuEm = {}
  local compras = 0
  local duracaoEsteira = Esteira.duracao()

  local function marcar(nome)
    if not marcos[nome] then marcos[nome] = t end
  end

  local function piorIndice()
    local idx, menor = nil, math.huge
    for i, d in estado.vitrine do
      local r = rendaDe(d)
      if r < menor then idx, menor = i, r end
    end
    return idx, menor
  end

  local function viagem()
    -- Esteira (x=0) até a entrada do lote (x≈42) carregando, e volta andando normal
    local ida = 45 / (Economia.VelocidadeCarregando + Economia.nivel(estado, "tenis") * Economia.VelocidadePorNivelTenis)
    local volta = 45 / Economia.VelocidadeBase
    return ida + volta + perfil.viagemExtra
  end

  while t < fim do
    -- renda da vitrine (o caixa é esvaziado a cada viagem, então entra direto)
    estado.moedas += Economia.rendaPorSegundo(estado, 0) * dt

    -- esteira solta Docinhos
    while proximoSpawn <= t do
      local id, variante = Esteira.sortear(rnd, false)
      table.insert(esteira, { id = id, variante = variante, nasceu = proximoSpawn })
      proximoSpawn += Esteira.Intervalo
    end
    for i = #esteira, 1, -1 do
      if t - esteira[i].nasceu > duracaoEsteira then table.remove(esteira, i) end
    end

    -- entrega
    if carga and t >= carregandoAte then
      local cap = Economia.capacidadeVitrine(estado)
      if #estado.vitrine >= cap then
        local idx = piorIndice()
        local velho = table.remove(estado.vitrine, idx)
        estado.moedas += Esteira.valorVenda(velho.id, velho.variante)
      end
      table.insert(estado.vitrine, carga)
      estado.album[carga.id] = estado.album[carga.id] or { qtd = 0, desde = t, dourado = false, arcoiris = false }
      local r = Catalogo.raridadeDe(carga.id)
      marcar("1º " .. r.nome)
      if carga.variante ~= "normal" then marcar("1º " .. Catalogo.Variantes[carga.variante].nome) end
      if #estado.vitrine >= Economia.EspacosBase then marcar("vitrine cheia (8)") end
      if Economia.albumCompleto(estado) then marcar("álbum sem o Secreto") end
      carga = nil
    end

    if not carga then
      -- melhorias
      local cap = Economia.capacidadeVitrine(estado)
      local custoV = Loja.proximoCusto("vitrine", Economia.nivel(estado, "vitrine"))
      if custoV and #estado.vitrine >= cap and estado.moedas >= custoV then
        estado.moedas -= custoV
        estado.melhorias.vitrine = Economia.nivel(estado, "vitrine") + 1
        marcar("vitrine nível " .. estado.melhorias.vitrine)
      end
      for _, id in { "tenis", "escudo", "caixa" } do
        local custo = Loja.proximoCusto(id, Economia.nivel(estado, id))
        if custo and custo <= estado.moedas * perfil.gastaFracao then
          estado.moedas -= custo
          estado.melhorias[id] = Economia.nivel(estado, id) + 1
        end
      end
      -- renascer
      local custoR = Economia.custoRenascer(estado.renascimentos)
      if perfil.renasce and estado.moedas >= custoR then
        estado.renascimentos += 1
        estado.moedas = 0
        for id in estado.melhorias do
          if id ~= "vitrine" then estado.melhorias[id] = 0 end
        end
        estado.granulados += Economia.RenascerGranulados * estado.renascimentos
        table.insert(renasceuEm, t)
      end
      -- compra o melhor Docinho que cabe no bolso e melhora a vitrine
      cap = Economia.capacidadeVitrine(estado)
      local _, menor = piorIndice()
      local cheia = #estado.vitrine >= cap
      local melhor, melhorIdx = nil, nil
      for i, item in esteira do
        local preco = Esteira.preco(item.id, item.variante)
        if preco <= estado.moedas and (not cheia or rendaDe(item) > menor) then
          if not melhor or rendaDe(item) > rendaDe(melhor) then
            melhor, melhorIdx = item, i
          end
        end
      end
      if melhor then
        table.remove(esteira, melhorIdx)
        estado.moedas -= Esteira.preco(melhor.id, melhor.variante)
        carga = { id = melhor.id, variante = melhor.variante }
        carregandoAte = t + viagem()
        compras += 1
      end
    end

    t += dt
    while proximoCheck <= #checkpoints and t >= checkpoints[proximoCheck] do
      if checkpoints[proximoCheck] <= fim then
        table.insert(renda, { checkpoints[proximoCheck], Economia.rendaPorSegundo(estado, 0), estado.moedas, #estado.vitrine })
      end
      proximoCheck += 1
    end
  end
  return { marcos = marcos, renda = renda, renasceuEm = renasceuEm, compras = compras, estado = estado }
end

Simulador.PERFIS = {
  casual = { nome = "Criança casual (anda devagar, gasta à toa)", viagemExtra = 12, gastaFracao = 0.6, horas = 3, renasce = true },
  dedicado = { nome = "Jogador dedicado", viagemExtra = 4, gastaFracao = 0.25, horas = 10, renasce = true },
}

return Simulador
