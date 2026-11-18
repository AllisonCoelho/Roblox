"""Testes da infraestrutura compartilhada. Requer o executável luau no PATH."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
MODULOS = {
    "Formato": "src/shared/Formato.luau",
    "LootIncursoes": "src/shared/Dados/LootIncursoes.luau",
    "Receitas": "src/shared/Dados/Receitas.luau",
    "Transcendencia": "src/shared/Dados/Transcendencia.luau",
    "Artefatos": "src/shared/Dados/Artefatos.luau",
    "Itens": "src/shared/Dados/Itens.luau",
    "Perfil": "src/shared/Dados/Perfil.luau",
    "Probabilidades": "src/shared/Dados/Probabilidades.luau",
    "Catalogo67Probabilidades": "src/shared/Dados/Catalogo67Probabilidades.luau",
    "Auras": "src/shared/Dados/Auras.luau",
    "Apresentacao": "src/shared/Dados/Apresentacao.luau",
    "Trilha": "src/shared/Dados/Trilha.luau",
    "Sessao": "src/server/Servicos/Sessao.luau",
    "PermissaoDev": "src/server/Servicos/PermissaoDev.luau",
    "Arena": "src/shared/Dados/Arena.luau",
    "Incursoes": "src/shared/Dados/Incursoes.luau",
    "Gear5Movimento": "src/client/Mundo/Auras/Gear5Movimento.luau",
    "AurasVfx": "src/shared/Dados/AurasVfx.luau",
    "EfeitosOriginais": "src/shared/Dados/EfeitosOriginais.luau",
    "AurasOriginaisV2": "src/shared/Dados/AurasOriginaisV2.luau",
    "Combate": "src/shared/Dados/Combate.luau",
    "Monetizacao": "src/shared/Dados/Monetizacao.luau",
    "Icones": "src/shared/Dados/Icones.luau",
    "Cosmeticos": "src/shared/Dados/Cosmeticos.luau",
    "Temporada": "src/shared/Dados/Temporada.luau",
    "IncursoesRun": "src/shared/Dados/IncursoesRun.luau",
    "IncursoesDesafios": "src/shared/Dados/IncursoesDesafios.luau",
}
codigo = ["""
-- Vector3 mínimo (o luau puro não tem): só para a geometria do combate nos testes
local Vector3 = {}
Vector3.__index = function(v, k)
    if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
    elseif k == "Unit" then
        local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
        return Vector3.new(v.X / m, v.Y / m, v.Z / m)
    elseif k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
    end
    return nil
end
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3) end
Vector3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
local MODULOS, CACHE = {}, {}
local function req(nome)
    if CACHE[nome] == nil then CACHE[nome] = MODULOS[nome]() end
    return CACHE[nome]
end
"""]
for nome, caminho in MODULOS.items():
    fonte = (ROOT / caminho).read_text(encoding="utf-8").replace("export type", "type")
    fonte = re.sub(r'require\(script\.Parent\.(\w+)\)', r'req("\1")', fonte)
    if nome in ("Auras", "Catalogo67Probabilidades"):
        fonte = fonte.replace("require(script.Parent.Probabilidades)", 'req("Probabilidades")')
    codigo.append('MODULOS["' + nome + '"] = function()\n' + fonte + '\nend\n')
codigo.append((ROOT / "testes/logica.luau").read_text(encoding="utf-8"))
saida = ROOT / "dist" / "testes.luau"
saida.parent.mkdir(parents=True, exist_ok=True)
saida.write_text("\n".join(codigo), encoding="utf-8")
resultado = subprocess.run(["luau", str(saida)], capture_output=True, text=True)
print(resultado.stdout, end="")
print(resultado.stderr, end="", file=sys.stderr)
sys.exit(0 if resultado.returncode == 0 and " 0 falhas" in resultado.stdout else 1)
