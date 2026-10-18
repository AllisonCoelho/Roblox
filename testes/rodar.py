"""Testes da lógica compartilhada (src/shared) fora do Roblox.

Uso: python3 testes/rodar.py   (precisa do executável `luau` no PATH:
https://github.com/luau-lang/luau/releases)

Junta os módulos com versões falsas de Color3/Random e roda testes/logica.luau.
"""
import os
import subprocess
import sys

repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(os.path.join(repo, 'dist'), exist_ok=True)
mods = {
 "Formato": "src/shared/Formato.luau",
 "Evento": "src/shared/Dados/Evento.luau",
 "Presentes": "src/shared/Dados/Presentes.luau",
 "Catalogo": "src/shared/Dados/Catalogo.luau",
 "Economia": "src/shared/Dados/Economia.luau",
 "Missoes": "src/shared/Dados/Missoes.luau",
 "Loja": "src/shared/Dados/Loja.luau",
 "Sessao": "src/server/Servicos/Sessao.luau",
 "Mapa": "src/shared/Dados/Mapa.luau",
 "Esteira": "src/shared/Dados/Esteira.luau",
 "Resgate": "src/shared/Dados/Resgate.luau",
 "Chuva": "src/shared/Dados/Chuva.luau",
}
out = ['''
-- stubs do Roblox
Color3 = { fromHex = function(h) return { hex = h } end }
Random = { new = function(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return { NextInteger = function(self, a, b) s = (s * 16807) % 2147483647; return a + (s % (b - a + 1)) end }
end }
-- Vector3 e CFrame simplificados (só o que a lógica compartilhada usa)
local V3 = {}
Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end
local function dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
local function cross(a, b) return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
V3.__index = function(v, k)
  if k == "Magnitude" then return math.sqrt(dot(v, v)) end
  if k == "Unit" then local m = math.sqrt(dot(v, v)); return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
  if k == "Cross" then return cross end
  if k == "Dot" then return dot end
  return nil
end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
  if type(a) == "number" then return Vector3.new(b.X * a, b.Y * a, b.Z * a) end
  if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
  return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
local CF = {}
CF.__index = CF
CFrame = {}
function CFrame.lookAt(pos, alvo)
  local look = (alvo - pos).Unit
  local right = cross(look, Vector3.new(0, 1, 0)).Unit
  local up = cross(right, look)
  return setmetatable({ Position = pos, RightVector = right, UpVector = up, LookVector = look }, CF)
end
function CF:PointToObjectSpace(p)
  local rel = p - self.Position
  return Vector3.new(dot(rel, self.RightVector), dot(rel, self.UpVector), -dot(rel, self.LookVector))
end
function CF:PointToWorldSpace(v)
  return self.Position + self.RightVector * v.X + self.UpVector * v.Y - self.LookVector * v.Z
end
local MODS = {}
local CACHE = {}
local function req(nome)
  if CACHE[nome] == nil then CACHE[nome] = MODS[nome]() end
  return CACHE[nome]
end
local function fakeScript() return { Parent = setmetatable({}, { __index = function(_, k) return k end }) } end
''']
for nome, path in mods.items():
    src = open(os.path.join(repo, path), encoding='utf-8').read()
    # tipos exportados não podem ficar dentro de função: remove 'export ' (vira tipo local)
    src = src.replace("export type", "type")
    out.append(f'MODS["{nome}"] = function()\n local script = fakeScript()\n local require = req\n{src}\nend\n')
out.append(open(os.path.join(repo, 'testes', 'logica.luau'), encoding='utf-8').read())
open(os.path.join(repo, 'dist', 'testes.luau'), 'w', encoding='utf-8').write("\n".join(out))

resultado = subprocess.run(['luau', os.path.join(repo, 'dist', 'testes.luau')], capture_output=True, text=True)
print(resultado.stdout, end='')
print(resultado.stderr, end='', file=sys.stderr)
sys.exit(1 if resultado.returncode != 0 or ' 0 falhas' not in resultado.stdout else 0)
