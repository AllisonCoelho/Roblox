"""Gera as malhas da aura Monarca das Sombras no Blender (testado com bpy 5.3) e exporta tudo.

Uso (Blender como módulo Python):
    python assets/auras/monarca/source/generate_monarca.py            # malhas, .blend, .fbx, Luau
    python assets/auras/monarca/source/generate_monarca.py --render   # também as prévias

Saídas:
    assets/auras/monarca/source/monarca.blend          cena editável
    assets/auras/monarca/exports/<peca>.fbx            peças para o 3D Importer (opcional)
    assets/auras/monarca/previews/*.png                renders do Blender (NÃO são capturas do Roblox)
    src/client/Mundo/Auras/Dados/monarca_<peca>.luau   geometria lida pelo jogo (EditableMesh)
    src/client/Mundo/Auras/MonarcaPecas.luau           onde cada chama fica e como se move

Visual (referência do dono): chamas ESCURAS com a borda roxa brilhando, pontas afiadas em gancho,
cortes em meia-lua cruzando a cintura e uma coroa flutuando sobre a cabeça. No jogo, o corpo de
cada chama é quase preto e a borda roxa é uma casca invertida Neon (gerada no cliente).
Também saem daqui: o soldado das sombras, a poça de sombra e o par de olhos que pisca dentro dela.

Escala: 1 unidade = 1 stud. Avatar R15 padrão: chão em z=0, HumanoidRootPart em z=3, olhando
para +Y. Peças do corpo: (x, y, z) Blender -> (x, z - 3, -y) no Roblox (relativo à raiz).
Peças soltas (soldado, poça, olhos, mecha): origem própria, (x, y, z) -> (x, z, -y).
"""

import base64
import math
import os
import random
import struct
import sys

import bpy

import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
DIR_BASE = os.path.join(RAIZ, "assets", "auras", "monarca")
DIR_LUAU = os.path.join(RAIZ, "src", "client", "Mundo", "Auras")
DIR_DADOS = os.path.join(DIR_LUAU, "Dados")
ALTURA_RAIZ = 3.0

OSSOS = {
    "raiz": Vector((0, 0, 3.0)),
    "tronco": Vector((0, 0, 3.55)),
    "cabeca": Vector((0, 0, 4.5)),
}


def catmull(pts, n):
    p = [Vector(x) for x in pts]
    p = [p[0] * 2 - p[1]] + p + [p[-1] * 2 - p[-2]]
    out = []
    seg = len(p) - 3
    for i in range(n):
        t = i / (n - 1) * seg
        k = min(int(t), seg - 1)
        u = t - k
        a, b, c, d = p[k], p[k + 1], p[k + 2], p[k + 3]
        out.append(0.5 * (2 * b + (-a + c) * u + (2 * a - 5 * b + 4 * c - d) * u * u + (-a + 3 * b - 3 * c + d) * u * u * u))
    return out


def suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


class Volume:
    def __init__(self, nome, res=0.05):
        self.mb = bpy.data.metaballs.new(nome)
        self.mb.resolution = res
        self.mb.render_resolution = res
        self.mb.threshold = 0.6
        self.obj = bpy.data.objects.new(nome + "_mb", self.mb)
        bpy.context.scene.collection.objects.link(self.obj)

    def bola(self, c, r, achatar=None):
        e = self.mb.elements.new()
        e.co = Vector(c)
        e.radius = r
        if achatar:
            e.type = "ELLIPSOID"
            e.size_x, e.size_y, e.size_z = achatar

    def malha(self):
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.obj.evaluated_get(dg))
        bpy.data.objects.remove(self.obj)
        bm = bmesh.new()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        return bm


def tubo_liso(bm, pts, raios, lados=10, achatar=1.0):
    """Tubo com referencial transportado e pontas fechadas. achatar < 1 = lâmina (fino num eixo)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tang = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    # normal inicial o mais alinhada possível com a profundidade (Y): a lâmina fica "de frente"
    normal = Vector((0, 1, 0)) - tang[0] * tang[0].y
    normal = normal.normalized() if normal.length > 1e-3 else tang[0].orthogonal().normalized()
    aneis = []
    for i in range(n):
        t = tang[i]
        normal = (normal - t * normal.dot(t)).normalized()
        bi = t.cross(normal)
        aneis.append([bm.verts.new(pts[i] + (normal * math.cos(a) * achatar + bi * math.sin(a)) * raios[i]) for a in (2 * math.pi * j / lados for j in range(lados))])
    for i in range(n - 1):
        a0, a1 = aneis[i], aneis[i + 1]
        for j in range(lados):
            bm.faces.new((a0[j], a0[(j + 1) % lados], a1[(j + 1) % lados], a1[j]))
    inicio = bm.verts.new(pts[0] - tang[0] * raios[0] * 0.5)
    fim = bm.verts.new(pts[-1] + tang[-1] * max(raios[-1], 0.01))
    for j in range(lados):
        bm.faces.new((inicio, aneis[0][(j + 1) % lados], aneis[0][j]))
        bm.faces.new((aneis[-1][j], aneis[-1][(j + 1) % lados], fim))


def garra(bm, base, direcao, curva, comp, grossura, gancho=0.7, n=22, achatar=0.6):
    """Ponta de chama em gancho: afiada e curva (a marca das chamas da referência)."""
    d = Vector(direcao).normalized()
    c = Vector(curva).normalized()
    pts, raios = [], []
    for i in range(n):
        f = i / (n - 1)
        pts.append(Vector(base) + d * comp * f + c * comp * gancho * f * f)
        raios.append(grossura * (1 - f) ** 1.15 * (1 + 0.3 * math.sin(math.pi * f * 0.8)) + 0.004)
    tubo_liso(bm, pts, raios, lados=10, achatar=achatar)


def labareda(rng, guia_pts, r_max, garras=(), enrolar=1.0):
    """Uma chama de sombra: nasce larga no corpo, ondula, afina e termina em gancho afiado.
    Achatada em profundidade (lâmina), com garras saindo das bordas."""
    vol = Volume("labareda")
    tubos = bmesh.new()
    guia = catmull(guia_pts, 48)
    ult = len(guia) - 1
    corte = 0.62
    fase = rng.uniform(0, 6.28)

    def raio(f):
        return r_max * (0.75 + 0.25 * suave(0, 0.2, f)) * (1 - 0.55 * suave(0.25, corte, f)) * (1 + 0.1 * math.sin(f * 8 + fase))

    def tang(i):
        return (guia[min(i + 1, ult)] - guia[max(i - 1, 0)]).normalized()

    for i, p in enumerate(guia):
        f = i / ult
        if f > corte:
            break
        vol.bola(p, raio(f), achatar=(1.0, 0.7, 1.0))
    i0 = int(corte * ult)
    r0 = raio(corte)
    # ponta: segue o resto da curva e enrola em gancho
    resto = guia[i0 - 1 :]
    t0 = tang(i0)
    lado = t0.cross(Vector((0, 1, 0))).normalized() * enrolar
    pts, raios = [], []
    m = len(resto)
    for j, p in enumerate(resto):
        f = j / (m - 1)
        pts.append(p + lado * 0.9 * r_max * f * f)
        raios.append(r0 * 1.05 * (1 - f) ** 1.2 + 0.004)
    tubo_liso(tubos, pts, raios, lados=12, achatar=0.5)
    # labaredas menores, dos dois lados, ao longo de toda a chama (borda recortada)
    extras = [(rng.uniform(0.08, 0.6), rng.uniform(0.35, 0.6) * r_max / 0.6, rng.choice((1, -1))) for _ in range(5)]
    for f, comp, sentido in list(garras) + extras:
        i = int(f * ult)
        t = tang(i)
        fora = t.cross(Vector((0, 1, 0))).normalized() * sentido
        garra(tubos, guia[i] + fora * raio(f) * 0.5, fora * 0.6 + t, t - fora * 0.2, comp, raio(f) * 0.45, gancho=0.8)
    return vol.malha(), tubos, Vector(guia_pts[0])


def corte_meia_lua(pts, r_max):
    """Corte em meia-lua (lâmina fina e afiada nas duas pontas) que cruza a cintura."""
    bm = bmesh.new()
    guia = catmull(pts, 40)
    raios = [r_max * math.sin(math.pi * (j / 39)) ** 0.8 + 0.004 for j in range(40)]
    tubo_liso(bm, guia, raios, lados=10, achatar=0.35)
    return None, bm, Vector((0, 0, 2.0))


def fazer_coroa(rng):
    """Coroa do monarca: aro com pontas afiadas (a da frente é a maior)."""
    bm = bmesh.new()
    n = 48
    r = 0.62
    aro = [Vector((r * math.cos(2 * math.pi * j / n), r * math.sin(2 * math.pi * j / n), 0)) for j in range(n + 1)]
    tubo_liso(bm, aro, [0.09] * (n + 1), lados=8)
    aro2 = [p * 1.04 + Vector((0, 0, 0.16)) for p in aro]
    tubo_liso(bm, aro2, [0.05] * (n + 1), lados=6)
    for j in range(8):
        a = math.pi / 2 + 2 * math.pi * j / 8  # j=0 é a frente (+Y)
        alto = (0.75 if j == 0 else 0.5 if j % 2 == 0 else 0.34)
        base = Vector((r * math.cos(a), r * math.sin(a), 0.05))
        fora = Vector((math.cos(a), math.sin(a), 0))
        garra(bm, base, fora * 0.25 + Vector((0, 0, 1)), fora, alto, 0.13, gancho=0.25, achatar=0.7)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    return None, bm, Vector((0, 0, 0))


def fazer_gema(rng):
    """Gema da coroa (losango brilhante na frente)."""
    bm = bmesh.new()
    c = Vector((0, 0.66, 0.2))
    pts = [c + Vector((0, 0, 0.2)), c + Vector((0, 0, -0.16)), c + Vector((0.09, 0, 0)), c + Vector((-0.09, 0, 0)), c + Vector((0, 0.07, 0)), c + Vector((0, -0.05, 0))]
    v = [bm.verts.new(p) for p in pts]
    for a, b, d in ((0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2), (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5)):
        bm.faces.new((v[a], v[b], v[d]))
    return None, bm, Vector((0, 0, 0))


def fazer_soldado(rng):
    """Soldado das sombras: cavaleiro de armadura com ombreiras pontudas, elmo com chifres, capa
    rasgada e espada cravada à frente. Pés na origem, olhando para +Y, ~5,6 studs."""
    vol = Volume("soldado", 0.06)
    t = bmesh.new()
    for lado in (1, -1):
        for j in range(7):  # pernas
            vol.bola((lado * 0.45, 0, 0.25 + 0.33 * j), 0.4 - 0.02 * j)
        vol.bola((lado * 0.5, 0.25, 0.2), 0.34)  # pé
        vol.bola((lado * 1.2, 0, 3.95), 0.6)  # ombreira
        garra(t, (lado * 1.35, 0, 4.2), (lado, 0, 0.8), (0, 0, 1), 0.75, 0.24, gancho=0.5)
        garra(t, (lado * 1.45, 0, 3.9), (lado, 0, 0.15), (0, 0, 1), 0.55, 0.18, gancho=0.5)
        for j in range(5):  # braços
            vol.bola((lado * (1.3 + 0.03 * j), 0.08 * j, 3.5 - 0.3 * j), 0.33)
        garra(t, (lado * 0.22, 0.05, 4.95), (lado * 0.6, -0.2, 1), (lado, 0, 0), 0.7, 0.13, gancho=0.5)  # chifres
    for j in range(6):  # tronco (peitoral largo)
        f = j / 5
        vol.bola((0, 0, 2.3 + 0.32 * j), 0.62 + 0.2 * f, achatar=(1.25, 0.8, 1.0))
    vol.bola((0, 0, 4.65), 0.5)  # elmo
    vol.bola((0, 0.2, 4.5), 0.38)  # viseira
    # espada cravada no chão, à frente, com as duas mãos
    lamina = [Vector((0, 0.75, 3.5 - 3.3 * j / 15)) for j in range(16)]
    tubo_liso(t, lamina, [0.17 * (1 - 0.5 * (j / 15) ** 2) + 0.01 for j in range(16)], lados=8, achatar=0.35)
    guarda = [Vector((-0.55 + 1.1 * j / 9, 0.75, 3.5)) for j in range(10)]
    tubo_liso(t, guarda, [0.09] * 10, lados=6)
    cabo = [Vector((0, 0.75, 3.5 + 0.6 * j / 5)) for j in range(6)]
    tubo_liso(t, cabo, [0.08] * 6, lados=6)
    for lado in (1, -1):  # antebraços até o cabo
        vol.bola((lado * 0.9, 0.45, 2.9), 0.3)
        vol.bola((lado * 0.45, 0.65, 3.3), 0.28)
    for j in range(7):  # capa rasgada
        x = -0.9 + 0.3 * j
        garra(t, (x, -0.55, 3.6), (x * 0.25, -0.35, -1), (0, -1, 0), 2.6 + 0.5 * (j % 2), 0.3, gancho=0.25, n=10)
    return vol.malha(), t, Vector((0, 0, 0))


def fazer_soldado_olhos(rng):
    vol = Volume("olhos", 0.02)
    for lado in (1, -1):
        for j in range(4):
            vol.bola((lado * (0.1 + 0.07 * j), 0.56, 4.52 + 0.025 * j), 0.05)
    return vol.malha(), bmesh.new(), Vector((0, 0, 0))


def fazer_olhos_par(rng):
    """Par de olhos que espia de dentro da sombra (deitado no chão, bravo). Largura ~0,8."""
    vol = Volume("par", 0.02)
    for lado in (1, -1):
        for j in range(6):
            f = j / 5
            vol.bola((lado * (0.1 + 0.3 * f), 0.03 + 0.1 * f, 0), 0.075 * (1 - 0.5 * abs(f - 0.4)), achatar=(1, 1, 0.4))
    return vol.malha(), bmesh.new(), Vector((0, 0, 0))


def fazer_poca(rng):
    """Poça de sombra: mancha irregular e chata, com filetes escorrendo para fora. Raio ~1."""
    vol = Volume("poca", 0.04)
    t = bmesh.new()
    vol.bola((0, 0, 0), 0.9, achatar=(1, 1, 0.3))
    for j in range(11):
        a = 2 * math.pi * j / 11 + rng.uniform(-0.2, 0.2)
        d = rng.uniform(0.55, 0.8)
        vol.bola((math.cos(a) * d, math.sin(a) * d, 0), rng.uniform(0.3, 0.45), achatar=(1, 1, 0.3))
        if j % 3 == 0:
            base = Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 0))
            garra(t, base, (math.cos(a), math.sin(a), 0), (-math.sin(a), math.cos(a), 0), rng.uniform(0.2, 0.35), 0.14, gancho=0.6, achatar=1.0)
    bm = vol.malha()
    return bm, t, Vector((0, 0, 0))


def fazer_mecha(rng):
    """Lasca de sombra que se solta e some (reaproveitada pelo jogo)."""
    bm = bmesh.new()
    garra(bm, (0, 0, -0.3), (0.2, 0, 1), (1, 0, 0), 0.8, 0.14, gancho=0.7)
    return None, bm, Vector((0, 0, 0))


# ---------------------------------------------------------------- exportação


def suavizar(bm, passos, fator=0.5):
    for _ in range(passos):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=fator, use_axis_x=True, use_axis_y=True, use_axis_z=True)


def junta(destino, origem):
    me = bpy.data.meshes.new("tmp")
    origem.to_mesh(me)
    destino.from_mesh(me)
    bpy.data.meshes.remove(me)


def reduzir(bm, alvo):
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    obj = bpy.data.objects.new("tmp", me)
    bpy.context.scene.collection.objects.link(obj)
    if len(me.polygons) > alvo:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = alvo / len(me.polygons)
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        obj.data = me2
        bpy.data.meshes.remove(me)
        me = me2
    bm2 = bmesh.new()
    bm2.from_mesh(me)
    bmesh.ops.triangulate(bm2, faces=bm2.faces)
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    return bm2


def escrever_luau(nome, bm, no_corpo):
    bm.verts.ensure_lookup_table()
    dz = ALTURA_RAIZ if no_corpo else 0.0
    pos = [(v.co.x, v.co.z - dz, -v.co.y) for v in bm.verts]
    tris = [tuple(v.index for v in f.verts) for f in bm.faces]
    assert len(pos) < 65536, nome
    minimo = [min(p[i] for p in pos) for i in range(3)]
    maximo = [max(p[i] for p in pos) for i in range(3)]
    tamanho = [max(maximo[i] - minimo[i], 1e-4) for i in range(3)]
    dados = bytearray()
    for p in pos:
        dados += struct.pack("<3H", *(int(round((p[i] - minimo[i]) / tamanho[i] * 65535)) for i in range(3)))
    for _ in pos:  # cor por vértice branca: a cor vem da parte
        dados += struct.pack("<3B", 255, 255, 255)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    pedacos = [texto[i : i + 4000] for i in range(0, len(texto), 4000)]
    linhas = [
        "-- GERADO por assets/auras/monarca/source/generate_monarca.py. Não editar à mão.",
        "-- Peça da aura Monarca das Sombras: posições (uint16), cores (uint8) e triângulos (uint16).",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ]
    linhas += ['\t\t"%s",' % p for p in pedacos]
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, "monarca_" + nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(pos), len(tris)


# Chamas e peças presas ao corpo. cfg:
#   osso: membro que segue; rigidez/atraso: mola (atraso = quanto fica para trás ao andar)
#   tremor: quanto a chama treme/estica (fogo); giro: balanço em graus; volta: rad/s em volta do corpo
#   ordem: quando surge na manifestação (0..1)
def ch(osso, rigidez, atraso, ordem, tremor=0.08, giro=7, volta=0.0):
    return dict(osso=osso, rigidez=rigidez, atraso=atraso, ordem=ordem, tremor=tremor, giro=giro, volta=volta)


CORPO = [
    ("chama_costas_e", lambda r: labareda(r, [(-0.7, -0.7, 3.3), (-1.9, -0.95, 4.6), (-2.6, -1.0, 6.0), (-2.2, -1.0, 7.0), (-1.5, -1.0, 7.4)], 0.85, ((0.25, 0.9, -1), (0.45, 0.8, -1)), 1.0), 2600, ch("tronco", 60, 0.6, 0.1)),
    ("chama_costas_d", lambda r: labareda(r, [(0.7, -0.7, 3.4), (1.8, -0.95, 4.9), (1.9, -1.05, 6.3), (2.5, -1.0, 7.3), (3.2, -1.0, 7.6)], 0.8, ((0.3, 0.9, 1), (0.5, 0.75, -1)), -1.0), 2600, ch("tronco", 55, 0.65, 0.2)),
    ("chama_meio", lambda r: labareda(r, [(0.0, -0.85, 4.0), (0.35, -1.5, 5.3), (-0.1, -1.9, 6.3), (-0.5, -2.1, 6.9)], 0.62, ((0.4, 0.6, 1),), 1.0), 1800, ch("tronco", 70, 0.5, 0.3)),
    ("chama_lado_e", lambda r: labareda(r, [(-1.5, -0.35, 2.7), (-2.6, -0.1, 3.2), (-3.1, 0.3, 4.2), (-2.8, 0.5, 5.0), (-2.3, 0.5, 5.3)], 0.62, ((0.3, 0.7, -1),), 1.0), 2000, ch("tronco", 45, 0.8, 0.4, giro=10)),
    ("chama_lado_d", lambda r: labareda(r, [(1.5, -0.35, 2.5), (2.5, -0.1, 2.9), (3.1, 0.25, 3.8), (3.4, 0.45, 4.6), (3.2, 0.5, 5.1)], 0.58, ((0.35, 0.7, 1),), -1.0), 2000, ch("tronco", 45, 0.8, 0.45, giro=10)),
    ("chama_baixo_e", lambda r: labareda(r, [(-0.8, -0.5, 1.7), (-1.8, -0.2, 1.2), (-2.4, 0.4, 1.7), (-2.2, 0.8, 2.5), (-1.8, 0.9, 2.8)], 0.5, ((0.3, 0.55, 1),), 1.0), 1600, ch("raiz", 34, 1.0, 0.55, giro=10)),
    ("chama_baixo_d", lambda r: labareda(r, [(0.8, -0.5, 1.5), (1.7, -0.2, 0.9), (2.3, 0.4, 1.3), (2.5, 0.8, 2.1), (2.2, 0.9, 2.6)], 0.5, ((0.3, 0.55, -1),), -1.0), 1600, ch("raiz", 34, 1.0, 0.6, giro=10)),
    ("corte_a", lambda r: corte_meia_lua([(-2.1, 0.3, 1.7), (-0.9, 1.0, 2.0), (0.6, 1.1, 2.45), (2.0, 0.5, 3.1)], 0.2), 600, ch("raiz", 80, 0.4, 0.7, tremor=0.0, giro=3, volta=0.5)),
    ("corte_b", lambda r: corte_meia_lua([(1.9, 0.4, 1.4), (0.7, 1.05, 1.15), (-0.7, 1.0, 1.0), (-1.9, 0.3, 0.7)], 0.16), 600, ch("raiz", 80, 0.4, 0.8, tremor=0.0, giro=3, volta=-0.35)),
]
SOLTAS = [
    ("coroa", fazer_coroa, 2500),
    ("coroa_gema", fazer_gema, 50),
    ("soldado", fazer_soldado, 3000),
    ("soldado_olhos", fazer_soldado_olhos, 300),
    ("olhos_par", fazer_olhos_par, 400),
    ("poca", fazer_poca, 1600),
    ("mecha", fazer_mecha, 200),
]


def montar(fn, alvo, rng, achatar_z=None):
    bm, tubos, pivo = fn(rng)
    if bm is None:
        bm = bmesh.new()
    else:
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
        suavizar(bm, 2)
        bm = reduzir(bm, alvo)
    junta(bm, tubos)
    tubos.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    if achatar_z:
        for v in bm.verts:
            v.co.z *= achatar_z
    return bm, pivo


def escrever_pecas(lista):
    linhas = [
        "-- GERADO por assets/auras/monarca/source/generate_monarca.py. Não editar à mão.",
        "-- Chamas do Monarca das Sombras (studs, relativo ao HumanoidRootPart de um R15 padrão).",
        "-- pivo = raiz da chama (onde ela se prende ao corpo e de onde balança).",
        "return {",
        "\tossos = {",
    ]
    for nome, c in OSSOS.items():
        linhas.append("\t\t%s = { %.3f, %.3f, %.3f }," % (nome, c.x, c.z - ALTURA_RAIZ, -c.y))
    linhas += ["\t},", "\tpecas = {"]
    for nome, pivo, cfg in lista:
        campos = ['nome = "%s"' % nome, "pivo = { %.3f, %.3f, %.3f }" % (pivo.x, pivo.z - ALTURA_RAIZ, -pivo.y)]
        for k, v in cfg.items():
            campos.append(('%s = "%s"' if isinstance(v, str) else "%s = %g") % (k, v))
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_LUAU, "MonarcaPecas.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def objeto(nome, bm):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("monarca_" + nome, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(DIR_DADOS, exist_ok=True)
    for antigo in os.listdir(DIR_DADOS):
        if antigo.startswith("monarca_"):
            os.remove(os.path.join(DIR_DADOS, antigo))
    for pasta in ("exports", "previews"):
        d = os.path.join(DIR_BASE, pasta)
        os.makedirs(d, exist_ok=True)
        for antigo in os.listdir(d):
            os.remove(os.path.join(d, antigo))
    objs = {}
    lista = []
    for i, (nome, fn, alvo, cfg) in enumerate(CORPO):
        bm, pivo = montar(fn, alvo, random.Random(1300 + i))
        nv, nt = escrever_luau(nome, bm, True)
        print("%-16s %5d vértices %5d triângulos" % (nome, nv, nt))
        objs[nome] = objeto(nome, bm)
        lista.append((nome, pivo, cfg))
    for i, (nome, fn, alvo) in enumerate(SOLTAS):
        bm, _ = montar(fn, alvo, random.Random(1400 + i), 0.12 if nome == "poca" else None)
        nv, nt = escrever_luau(nome, bm, False)
        print("%-16s %5d vértices %5d triângulos" % (nome, nv, nt))
        objs[nome] = objeto(nome, bm)
    escrever_pecas(lista)
    for obj in objs.values():
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(filepath=os.path.join(DIR_BASE, "exports", obj.name + ".fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_UNITS")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "monarca.blend"), compress=True)
    return objs


# ---------------------------------------------------------------- prévias


def emissao(nome, cor, forca):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*cor, 1)
    em.inputs["Strength"].default_value = forca
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def borda(cor, forca):
    """Casca invertida: só aparece onde a face está de costas (a borda roxa brilhando)."""
    m = bpy.data.materials.new("borda")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeMixShader")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*cor, 1)
    em.inputs["Strength"].default_value = forca
    vazio = nt.nodes.new("ShaderNodeBsdfTransparent")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(vazio.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def fosco(cor):
    m = bpy.data.materials.new("fosco")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    b.inputs["Roughness"].default_value = 0.7
    return m


def copia(fonte, loc, escala, rot_z, mats, espessura=0.05):
    obj = bpy.data.objects.new(fonte.name + "_i", fonte.data.copy())
    obj.data.materials.clear()
    for m in mats:
        obj.data.materials.append(m)
    obj.location = loc
    obj.scale = (escala, escala, escala)
    obj.rotation_euler = (0, 0, rot_z)
    bpy.context.scene.collection.objects.link(obj)
    if len(mats) > 1:
        mod = obj.modifiers.new("borda", "SOLIDIFY")
        mod.thickness = espessura
        mod.offset = 1
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = 1
    return obj


def caixa(centro, tam, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2])) + Vector(centro)
    me = bpy.data.meshes.new("caixa")
    bm.to_mesh(me)
    obj = bpy.data.objects.new("caixa", me)
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)


def renderizar(objs):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 48
    cena.cycles.device = "CPU"
    cena.view_settings.view_transform = "AgX"
    cena.view_settings.look = "AgX - Punchy"
    mundo = bpy.data.worlds.new("w")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.008, 0.02, 1)
    cena.world = mundo
    for o in objs.values():
        o.hide_render = True
    escuro = emissao("escuro", (0.035, 0.008, 0.1), 1.0)
    roxo = borda((0.28, 0.04, 0.9), 3.0)
    brilho = emissao("brilho", (0.55, 0.25, 1.0), 12.0)
    avatar = fosco((0.12, 0.12, 0.14))
    for c, t in (((-0.5, 0, 1), (0.9, 0.9, 2)), ((0.5, 0, 1), (0.9, 0.9, 2)), ((0, 0, 3), (2, 1, 2)), ((-1.5, 0, 3), (0.95, 0.95, 2)), ((1.5, 0, 3), (0.95, 0.95, 2)), ((0, 0, 4.6), (1.2, 1.2, 1.2))):
        caixa(c, t, avatar)
    caixa((0, 0, -0.06), (60, 60, 0.1), fosco((0.03, 0.025, 0.045)))
    for nome, _, _, _ in CORPO:
        copia(objs[nome], (0, 0, 0), 1, 0, [escuro, roxo])
    copia(objs["coroa"], (0, 0, 5.75), 1, 0, [escuro, roxo], 0.04)
    copia(objs["coroa_gema"], (0, 0, 5.75), 1, 0, [brilho])
    copia(objs["poca"], (0, 0, 0.02), 3.4, 0, [escuro, roxo], 0.02)
    rng = random.Random(7)
    for _ in range(12):
        a, d = rng.uniform(0, 6.28), rng.uniform(0.5, 2.6)
        copia(objs["olhos_par"], (math.cos(a) * d, math.sin(a) * d + 0.6, 0.12), rng.uniform(0.7, 1.1), rng.uniform(-0.5, 0.5) + math.pi, [brilho])
    luz = bpy.data.lights.new("frente", "AREA")
    luz.energy = 250
    luz.size = 8
    luz.color = (0.7, 0.5, 1.0)
    ol = bpy.data.objects.new("frente", luz)
    ol.location = (0, 9, 8)
    ol.rotation_euler = (Vector((0, 0, 3)) - ol.location).to_track_quat("-Z", "Y").to_euler()
    cena.collection.objects.link(ol)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 45
    oc = bpy.data.objects.new("cam", cam)
    cena.collection.objects.link(oc)
    cena.camera = oc

    def tirar(nome, pos, alvo, rx_, ry_):
        cena.render.resolution_x, cena.render.resolution_y = rx_, ry_
        oc.location = pos
        oc.rotation_euler = (Vector(alvo) - oc.location).to_track_quat("-Z", "Y").to_euler()
        cena.render.filepath = os.path.join(DIR_BASE, "previews", nome + ".png")
        bpy.ops.render.render(write_still=True)
        print("prévia", nome)

    for nome, graus in (("front", 0), ("three_quarter", 40), ("side", 90), ("back", 180)):
        a = math.radians(graus)
        tirar(nome, (math.sin(a) * 17, math.cos(a) * 17, 4.6), (0, 0, 3.8), 600, 760)
    # soldados em guarda (jogador parado)
    soldados = []
    for k in range(4):
        a = math.radians(45 + 90 * k)
        p = (math.sin(a) * 6.5, math.cos(a) * 6.5, 0)
        soldados.append(copia(objs["soldado"], p, 1.0 + 0.1 * (k % 2), -a, [escuro, roxo], 0.06))
        soldados.append(copia(objs["soldado_olhos"], p, 1.0 + 0.1 * (k % 2), -a, [brilho]))
        soldados.append(copia(objs["poca"], (p[0], p[1], 0.02), 1.8, a, [escuro, roxo], 0.02))
    tirar("soldados", (9, 24, 10), (0, 0, 2.6), 1000, 700)


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
