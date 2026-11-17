-- Motor puro do RNG do Despertar: pesos por tier, normalizados a 100%.
-- Nao usa APIs do Roblox e nao altera drops de itens.
local Probabilidades = {}

local EXPOENTES: { [string]: number } = {
 Comum = 0,
 Incomum = 0.25,
 Raro = 1,
 ["Épico"] = 1.2,
 ["Lendário"] = 1.4,
 ["Mítico"] = 1.6,
 Divino = 1.8,
}
Probabilidades.MAX_SORTE = 3
Probabilidades.MAX_NIVEL = 10

local function finito(valor: any): boolean
 return type(valor) == "number" and valor == valor and valor > -math.huge and valor < math.huge
end

function Probabilidades.sorteValida(valor: any): number
 if not finito(valor) then
  return 1
 end
 return math.clamp(valor, 1, Probabilidades.MAX_SORTE)
end

function Probabilidades.sorteTranscendencia(nivel: any): number
 if not finito(nivel) then
  return 1
 end
 return 1 + 0.05 * math.clamp(math.floor(nivel), 0, Probabilidades.MAX_NIVEL)
end

function Probabilidades.validarCatalogo(catalogo: { any })
 assert(type(catalogo) == "table" and #catalogo > 1, "catalogo vazio")
 local vistos: { [string]: boolean } = {}
 local reservas = 0
 local soma = 0
 for _, aura in catalogo do
  assert(type(aura.id) == "string" and #aura.id > 0, "id invalido")
  assert(not vistos[aura.id], "id duplicado: " .. aura.id)
  vistos[aura.id] = true
  assert(type(EXPOENTES[aura.tierNome]) == "number", "tier invalido: " .. aura.id)
  assert(finito(aura.pBase) and aura.pBase > 0 and aura.pBase < 1, "pBase invalida")
  if aura.reserva == true then
   reservas += 1
  end
  soma += aura.pBase
 end
 assert(reservas == 1, "catalogo precisa de uma unica reserva")
 assert(math.abs(soma - 1) < 1e-10, "probabilidades base nao somam 100%")
end

function Probabilidades.distribuicao(catalogo: { any }, sorte: number?): ({ number }, number)
 local s = Probabilidades.sorteValida(sorte)
 local pesos: { number } = table.create(#catalogo)
 local total = 0
 for i, aura in catalogo do
  local expoente = EXPOENTES[aura.tierNome]
  assert(type(expoente) == "number", "tier invalido")
  assert(finito(aura.pBase) and aura.pBase > 0, "pBase invalida")
  local peso = aura.pBase * s ^ expoente
  assert(finito(peso) and peso > 0, "peso invalido")
  pesos[i] = peso
  total += peso
 end
 assert(finito(total) and total > 0, "total invalido")
 return pesos, total
end

function Probabilidades.sortearPesos(
 catalogo: { any }, pesos: { number }, total: number, aleatorio: () -> number
): any
 local u = aleatorio()
 assert(finito(u) and u >= 0 and u < 1, "RNG invalido")
 local alvo = u * total
 local acumulado = 0
 for i = #catalogo, 1, -1 do
  acumulado += pesos[i]
  if alvo < acumulado then
   return catalogo[i]
  end
 end
 return catalogo[1]
end

function Probabilidades.sortear(catalogo: { any }, sorte: number?, aleatorio: () -> number): any
 local pesos, total = Probabilidades.distribuicao(catalogo, sorte)
 return Probabilidades.sortearPesos(catalogo, pesos, total, aleatorio)
end

function Probabilidades.chanceEfetiva(catalogo: { any }, id: string, sorte: number?): number
 local pesos, total = Probabilidades.distribuicao(catalogo, sorte)
 for i, aura in catalogo do
  if aura.id == id then
   return pesos[i] / total
  end
 end
 return 0
end

return Probabilidades
