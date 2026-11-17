"""Testes da infraestrutura compartilhada. Requer o executável luau no PATH."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
MODULOS = {
    "Formato": "src/shared/Formato.luau",
    "Itens": "src/shared/Dados/Itens.luau",
    "Perfil": "src/shared/Dados/Perfil.luau",
    "Auras": "src/shared/Dados/Auras.luau",
    "Apresentacao": "src/shared/Dados/Apresentacao.luau",
    "Trilha": "src/shared/Dados/Trilha.luau",
    "Sessao": "src/server/Servicos/Sessao.luau",
    "PermissaoDev": "src/server/Servicos/PermissaoDev.luau",
    "Incursoes": "src/shared/Dados/Incursoes.luau",
}
codigo = ["""
local MODULOS, CACHE = {}, {}
local function req(nome)
    if CACHE[nome] == nil then CACHE[nome] = MODULOS[nome]() end
    return CACHE[nome]
end
"""]
for nome, caminho in MODULOS.items():
    fonte = (ROOT / caminho).read_text(encoding="utf-8").replace("export type", "type")
    codigo.append('MODULOS["' + nome + '"] = function()\n' + fonte + '\nend\n')
codigo.append((ROOT / "testes/logica.luau").read_text(encoding="utf-8"))
saida = ROOT / "dist" / "testes.luau"
saida.parent.mkdir(parents=True, exist_ok=True)
saida.write_text("\n".join(codigo), encoding="utf-8")
resultado = subprocess.run(["luau", str(saida)], capture_output=True, text=True)
print(resultado.stdout, end="")
print(resultado.stderr, end="", file=sys.stderr)
sys.exit(0 if resultado.returncode == 0 and " 0 falhas" in resultado.stdout else 1)
