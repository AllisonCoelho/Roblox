"""Testes da infraestrutura compartilhada. Requer o executável luau no PATH."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
MODULOS = {
    "CarregamentoMapa": "src/shared/Dados/CarregamentoMapa.luau",
    "NexoCena": "src/client/Mundo/Nexo3D/Cena.luau",
    "Formato": "src/shared/Formato.luau",
    "LootIncursoes": "src/shared/Dados/LootIncursoes.luau",
    "Receitas": "src/shared/Dados/Receitas.luau",
    "Transcendencia": "src/shared/Dados/Transcendencia.luau",
    "PontosAura": "src/shared/Dados/PontosAura.luau",
    "Corredor": "src/shared/Dados/Corredor.luau",
    "Pets": "src/shared/Dados/Pets.luau",
    "Criaturas": "src/shared/Dados/Criaturas.luau",
    "Equipamento": "src/shared/Dados/Equipamento.luau",
    "Ciclo": "src/shared/Dados/Ciclo.luau",
    "DropsMapa": "src/shared/Dados/DropsMapa.luau",
    "Tutorial": "src/shared/Dados/Tutorial.luau",
    "ArenaPvP": "src/shared/Dados/ArenaPvP.luau",
    "Duelo": "src/shared/Dados/Duelo.luau",
    "AtaquesAura": "src/shared/Dados/AtaquesAura.luau",
    "EventoSol": "src/shared/Dados/EventoSol.luau",
    "Musica": "src/shared/Dados/Musica.luau",
    "Bonecos": "src/shared/Dados/Bonecos.luau",
    "CoroaVisual": "src/shared/Dados/CoroaVisual.luau",
    "EquipamentoVisual": "src/shared/Dados/EquipamentoVisual.luau",
    "CriaturasVisual": "src/shared/Dados/CriaturasVisual.luau",
    "PetsVisual": "src/shared/Dados/PetsVisual.luau",
    "CorredorMapa": "src/shared/Dados/CorredorMapa.luau",
    "Artefatos": "src/shared/Dados/Artefatos.luau",
    "Itens": "src/shared/Dados/Itens.luau",
    "Perfil": "src/shared/Dados/Perfil.luau",
    "Probabilidades": "src/shared/Dados/Probabilidades.luau",
    "Auras": "src/shared/Dados/Auras.luau",
    "Apresentacao": "src/shared/Dados/Apresentacao.luau",
    "Trilha": "src/shared/Dados/Trilha.luau",
    "Sessao": "src/server/Servicos/Sessao.luau",
    "PermissaoDev": "src/server/Servicos/PermissaoDev.luau",
    "ArenaAnimacoes": "src/shared/Dados/ArenaAnimacoes.luau",
    "SoberanoPecas": "src/shared/Dados/SoberanoPecas.luau",
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
    "Conveniencia": "src/shared/Dados/Conveniencia.luau",
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
-- Color3 mínimo: só o que as tabelas de cor do ciclo de dia e noite usam
local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3) end
function Color3.fromHex(h)
    h = h:gsub("#", "")
    return Color3.new(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255)
end
function Color3.Lerp(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
local MODULOS, CACHE = {}, {}
local function req(nome)
    if CACHE[nome] == nil then CACHE[nome] = MODULOS[nome]() end
    return CACHE[nome]
end
"""]
for nome, caminho in MODULOS.items():
    fonte = (ROOT / caminho).read_text(encoding="utf-8").replace("export type", "type")
    fonte = re.sub(r'require\(script\.Parent\.(\w+)\)', r'req("\1")', fonte)
    codigo.append('MODULOS["' + nome + '"] = function()\n' + fonte + '\nend\n')
codigo.append((ROOT / "testes/logica.luau").read_text(encoding="utf-8"))
subprocess.run([sys.executable, str(ROOT / "testes/mapa.py")], check=True)
# NPCs (Dados/Bonecos): toda malha citada (cabeça, cabelo e roupa pintada) existe
_bonecos = (ROOT / "src/shared/Dados/Bonecos.luau").read_text(encoding="utf-8")
_dados = ROOT / "src/client/Mundo/Nexo3D/Dados"
_faltando = []
for _id in re.findall(r"^\t(\w+) = \{\n\t\tnome =", _bonecos, re.M):
    _nomes = ["boneco_cabeca_" + _id]
    _bloco = _bonecos.split("\t" + _id + " = {", 1)[1].split("\n\t},", 1)[0]
    if "corpoMalha = true" in _bloco:
        _nomes += ["boneco_%s_%s" % (_id, m) for m in ("tronco", "bracoD", "bracoE", "pernaD", "pernaE")]
    _nomes += re.findall(r'malha = "(\w+)"', _bloco)
    _faltando += [n for n in _nomes if not (_dados / (n + ".luau")).exists()]
if _faltando:
    sys.exit("Malhas de NPC faltando: " + ", ".join(_faltando))
print("NPCs: malhas de cabeça, cabelo e roupa presentes")
saida = ROOT / "dist" / "testes.luau"
saida.parent.mkdir(parents=True, exist_ok=True)
saida.write_text("\n".join(codigo), encoding="utf-8")
resultado = subprocess.run(["luau", str(saida)], capture_output=True, text=True)
print(resultado.stdout, end="")
print(resultado.stderr, end="", file=sys.stderr)
sys.exit(0 if resultado.returncode == 0 and " 0 falhas" in resultado.stdout else 1)
