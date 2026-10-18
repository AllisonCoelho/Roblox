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
}
out = ['''
-- stubs do Roblox
Color3 = { fromHex = function(h) return { hex = h } end }
Random = { new = function(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return { NextInteger = function(self, a, b) s = (s * 16807) % 2147483647; return a + (s % (b - a + 1)) end }
end }
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
