-- Mesmos pedestais de assets/nexo/source/generate_nexo.py, no referencial do trono.
local Pecas = require(script.Parent.SoberanoPecas)
local ArenaCena = {}

local a = math.rad(Pecas.arena.graus)
local centro = Vector3.new(math.sin(a), 0, -math.cos(a)) * Pecas.arena.dist
ArenaCena.referencia = CFrame.lookAt(centro, Vector3.zero)

local jogador = ArenaCena.referencia:PointToWorldSpace(Vector3.new(7, 0.9, 0))
local soberano = ArenaCena.referencia:PointToWorldSpace(Vector3.new(-7, 0.9, 0))
ArenaCena.jogador = CFrame.lookAt(jogador, soberano)
ArenaCena.soberano = CFrame.lookAt(soberano, jogador)

return ArenaCena
