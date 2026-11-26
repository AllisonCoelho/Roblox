"""Geometria real e transações de montagem; não substitui o renderer do Studio."""
from pathlib import Path
import base64
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PASTA = ROOT / "src/client/Mundo/Nexo3D"
referencias = set()
for cena in ("Cena.luau", "CenaCorredor.luau"):
    referencias.update(re.findall(r'malha = "([^"]+)"', (PASTA / cena).read_text(encoding="utf-8")))
for nome in sorted(referencias):
    fonte = (PASTA / "Dados" / (nome + ".luau")).read_text(encoding="utf-8")
    nv = int(re.search(r"vertices = (\d+)", fonte)[1])
    nt = int(re.search(r"triangulos = (\d+)", fonte)[1])
    assert 0 < nv <= 60000 and 0 < nt <= 20000, nome
    dados = base64.b64decode("".join(re.findall(r'"([A-Za-z0-9+/=]+)"', fonte)))
    assert len(dados) == nv * 9 + nt * 6, nome
    assert all(v[0] < nv for v in struct.iter_unpack("<H", dados[nv * 9:])), nome
print(f"Mapa: {len(referencias)} malhas referenciadas com payload e índices válidos")

politica = (ROOT / "src/shared/Dados/CarregamentoMapa.luau").read_text(encoding="utf-8")
montagem = (PASTA / "Montagem.luau").read_text(encoding="utf-8")
montagem = montagem.replace('require(script.Parent.Cena)', 'ENV.Cena')
montagem = montagem.replace('require(script.Parent.Malha)', 'ENV.Malha')
montagem = montagem.replace('require(ReplicatedStorage.Shared.Dados.CarregamentoMapa)', 'ENV.Politica')
mock = r'''
local ENV = {}
local agora = 0
local os = { clock = function() return agora end }
local task = {
    wait = function() agora += 0.1 end,
    spawn = function(fn) if not ENV.travarPreload then fn() end end,
}
local vetor = {}
vetor.__index = vetor
vetor.__mul = function(a, b) return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
Vector3 = {new = function(x, y, z) return setmetatable({X=x, Y=y, Z=z}, vetor) end}
local cf = { __mul = function(a) return a end }
local CFrame = {new = function() return setmetatable({}, cf) end, Angles = function() return setmetatable({}, cf) end}
local function instancia(classe)
    local item = {ClassName=classe, filhos={}, atributos={}}
    function item:GetChildren() return self.filhos end
    function item:GetAttribute(k) return self.atributos[k] end
    function item:Destroy()
        self.destruido = true
        for _, filho in self.filhos do filho:Destroy() end
    end
    return setmetatable(item, {__newindex = function(t, k, v)
        rawset(t, k, v)
        if k == 'Parent' and v then table.insert(v.filhos, t) end
    end})
end
local Instance = {new = instancia}
local Enum = {Material={Slate='Slate'}, AssetFetchStatus={Success='Success'}}
local game = {GetService = function(_, nome)
    if nome == 'ContentProvider' then
        return {PreloadAsync=function(_, _, callback)
            if ENV.preloadFalha then callback('rbxassetid://123', {Name='Failure'}) end
        end}
    end
    return {}
end}
local feitas = {}
ENV.Malha = {criar = function(nome, cache)
    table.insert(feitas, nome)
    if nome == ENV.falhar then error('Falha injetada: ' .. nome) end
    local parte = instancia('MeshPart')
    parte.Size = Vector3.new(1,1,1)
    parte.atributos.MalhaPublicada = ENV.publicadas
    if not cache[nome] then cache[nome] = {modelo=instancia('MeshPart')} end
    return parte, Vector3.new(0,0,0)
end}
local function peca(nome, distancia, grupo)
    return {malha=nome, posicao={0,0,distancia}, material='Slate', grupo=grupo}
end
-- Intencionalmente fora de ordem: o plano deve antecipar a praça.
ENV.Cena = {centroCristal={0,15,0}, pecas={peca('longe',150,'lanterna'), peca('centro',0,'nucleo'), peca('piso',1)}}
'''
testes = r'''
local function validar(falha, publicadas, erroPreload, travar)
    ENV.falhar, ENV.publicadas, ENV.preloadFalha, ENV.travarPreload = falha, publicadas, erroPreload, travar
    feitas = {}
    local pai, etapas = instancia('Folder'), {}
    local ok, resultado, erro = pcall(Montagem.construir, pai, function(parcial, etapa)
        table.insert(etapas, etapa)
        assert(parcial.pasta.Parent == pai, 'Etapa deve estar visível no callback')
        if etapa == 'Praca' then
            assert(#feitas == 2 and feitas[1] == 'centro', 'Mundo não pode bloquear praça')
            assert(parcial.nucleo and #parcial.lanternas == 0)
        end
    end)
    if falha == 'centro' or erroPreload or travar then
        assert(not ok and #etapas == 0, 'Falha inicial não pode esconder fallback')
        assert(pai.filhos[1].destruido, 'Limpar kit não confirmado')
    elseif falha == 'longe' then
        assert(ok and erro and #etapas == 1, 'Preservar etapa já confirmada')
        assert(not resultado.pasta.destruido and not resultado.nucleo.parte.destruido)
        assert(#resultado.lanternas == 0, 'Sem referências da etapa que falhou')
        assert(resultado.pasta.filhos[1].Name == 'Praca')
    else
        assert(ok and not erro and #etapas == 2 and etapas[2] == 'Mundo')
        assert(#resultado.lanternas == 1 and not resultado.lanternas[1].parte.destruido)
    end
end
validar(nil, false, false, false)
validar('centro', false, false, false)
validar('longe', false, false, false)
validar(nil, true, false, false)
validar(nil, true, true, false)
validar(nil, true, false, true)
print('Mapa: 6 cenários de montagem passaram (sucesso, rollback, preservação, preload e timeout)')
'''
saida = ROOT / "dist/testes_mapa.luau"
saida.parent.mkdir(exist_ok=True)
saida.write_text(mock + "\nENV.Politica = (function()\n" + politica +
                 "\nend)()\nlocal Montagem = (function()\n" + montagem +
                 "\nend)()\n" + testes, encoding="utf-8")
subprocess.run(["luau", str(saida)], check=True)
