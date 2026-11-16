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


# ---------------------------------------------------------------- soldados das sombras
# Quatro soldados diferentes, cada um com silhueta própria (pés na origem, olhando para +Y).
# Cada função devolve (volume, tubos, pontos dos olhos).


def membro(vol, a, b, r0, r1, n=6):
    a, b = Vector(a), Vector(b)
    for j in range(n):
        f = j / (n - 1)
        vol.bola(a + (b - a) * f, r0 + (r1 - r0) * f)


def capa(t, x0, x1, y, z, comp, n=7, grossura=0.3):
    for j in range(n):
        x = x0 + (x1 - x0) * j / (n - 1)
        garra(t, (x, y, z), (x * 0.25, -0.35, -1), (0, -1, 0), comp * (1 + 0.18 * (j % 2)), grossura, gancho=0.25, n=10)


def soldado_cavaleiro(rng):
    """Comandante (estilo Igris): cavaleiro alto e esguio, elmo com penacho longo, ombreiras em
    lâmina, capa comprida e a espada longa cravada à frente com as duas mãos."""
    vol = Volume("cavaleiro", 0.06)
    t = bmesh.new()
    for lado in (1, -1):
        membro(vol, (lado * 0.42, 0, 0.2), (lado * 0.4, 0, 2.5), 0.36, 0.34, 8)
        vol.bola((lado * 0.48, 0.25, 0.18), 0.32)  # bota
        garra(t, (lado * 0.45, 0.3, 1.35), (0, 1, 0.3), (0, 0, 1), 0.35, 0.14, gancho=0.4)  # joelheira
        vol.bola((lado * 1.1, 0, 4.3), 0.5)  # ombreira
        for k in range(3):  # ombreira em lâminas sobrepostas
            garra(t, (lado * (1.2 + 0.1 * k), 0, 4.5 - 0.22 * k), (lado, 0, 0.55 - 0.3 * k), (0, 0, 1), 0.8 - 0.12 * k, 0.2, gancho=0.45)
        membro(vol, (lado * 1.2, 0, 4.0), (lado * 0.95, 0.4, 3.2), 0.3, 0.27, 4)
        membro(vol, (lado * 0.95, 0.4, 3.2), (lado * 0.25, 0.8, 3.75), 0.27, 0.24, 4)
    for j in range(7):  # tronco: cintura fina, peito largo
        f = j / 6
        vol.bola((0, 0, 2.6 + 0.3 * j), 0.5 + 0.32 * f, achatar=(1.2, 0.8, 1.0))
    vol.bola((0, 0, 5.05), 0.44)  # elmo
    vol.bola((0, 0.22, 4.92), 0.32)  # viseira em bico
    garra(t, (0, 0.38, 4.85), (0, 1, -0.25), (0, 0, -1), 0.35, 0.14, gancho=0.3)
    # penacho: sai do alto do elmo e cai longo para trás
    pen = catmull([(0, 0.05, 5.4), (0, -0.25, 6.1), (0, -0.95, 6.2), (0, -1.5, 5.4), (0, -1.75, 4.3), (0, -1.6, 3.4)], 26)
    tubo_liso(t, pen, [0.2 * (1 - (j / 25) ** 1.5) + 0.02 for j in range(26)], lados=8, achatar=0.5)
    # espada longa cravada no chão
    lam = [Vector((0, 0.85, 3.9 - 3.8 * j / 17)) for j in range(18)]
    tubo_liso(t, lam, [0.19 * (1 - 0.6 * (j / 17) ** 2) + 0.01 for j in range(18)], lados=8, achatar=0.3)
    tubo_liso(t, [Vector((-0.7 + 1.4 * j / 9, 0.85, 3.9 + 0.1 * abs(j - 4.5) / 4.5)) for j in range(10)], [0.09] * 10, lados=6)
    tubo_liso(t, [Vector((0, 0.85, 3.9 + 0.75 * j / 5)) for j in range(6)], [0.08] * 6, lados=6)
    capa(t, -0.95, 0.95, -0.5, 4.1, 3.3, 8, 0.32)
    olhos = [[(lado * (0.08 + 0.06 * j), 0.5, 4.97 + 0.03 * j) for j in range(4)] for lado in (1, -1)]
    return vol, t, olhos


def soldado_gigante(rng):
    """Gigante de armadura pesada: muito largo, ombros enormes, elmo pequeno com chifres para os
    lados, escudo-torre no braço esquerdo e um machado grande apoiado no ombro direito."""
    vol = Volume("gigante", 0.07)
    t = bmesh.new()
    for lado in (1, -1):
        membro(vol, (lado * 0.75, 0, 0.3), (lado * 0.7, 0, 2.6), 0.62, 0.6, 6)
        vol.bola((lado * 0.8, 0.35, 0.3), 0.55)
        vol.bola((lado * 1.9, 0, 5.0), 0.95)  # ombros enormes
        garra(t, (lado * 2.2, 0, 5.5), (lado * 0.6, 0, 1), (lado, 0, 0), 0.8, 0.3, gancho=0.5)
        garra(t, (lado * 0.5, 0, 6.35), (lado, 0, 0.35), (0, 0, 1), 0.9, 0.2, gancho=0.6)  # chifres laterais
    for j in range(7):  # barril
        f = j / 6
        vol.bola((0, 0, 2.9 + 0.38 * j), 1.0 + 0.3 * math.sin(f * math.pi * 0.8), achatar=(1.25, 0.9, 1.0))
    vol.bola((0, 0.25, 3.3), 0.85)  # barriga
    vol.bola((0, 0.05, 6.1), 0.5)  # elmo pequeno
    # braço esquerdo com escudo-torre
    membro(vol, (-2.0, 0, 4.6), (-2.1, 0.6, 3.0), 0.55, 0.5, 5)
    esc = [Vector((-2.0, 1.25, 5.2 - 4.9 * j / 15)) for j in range(16)]
    tubo_liso(t, esc, [1.15 * (1 - 0.5 * (j / 15) ** 3) * (0.75 + 0.25 * math.sin(math.pi * min(j / 4, 1) / 2)) for j in range(16)], lados=14, achatar=0.16)
    garra(t, (-2.0, 1.45, 3.6), (0, 1, 0), (0, 0, 1), 0.5, 0.25, gancho=0.2)  # espigão do escudo
    # braço direito e machado no ombro
    membro(vol, (2.0, 0, 4.6), (2.3, 0.5, 3.6), 0.55, 0.5, 4)
    membro(vol, (2.3, 0.5, 3.6), (2.0, 0.7, 4.6), 0.5, 0.45, 4)
    cabo = [Vector((2.0, 0.9 - 2.6 * j / 13, 3.6 + 3.9 * j / 13)) for j in range(14)]
    tubo_liso(t, cabo, [0.13] * 14, lados=6)
    topo = cabo[-1]
    for sinal in (1, -1):  # lâminas duplas do machado
        for k in range(5):
            a = math.radians(-50 + 25 * k)
            garra(t, topo + Vector((0, 0, -0.3)), (sinal * math.cos(a), 0, math.sin(a)), (0, 0, -1), 1.25, 0.34, gancho=0.2, achatar=0.3)
    capa(t, -1.6, 1.6, -0.85, 4.6, 2.6, 6, 0.4)
    olhos = [[(-0.28 + 0.08 * j, 0.52, 6.15) for j in range(8)]]  # um visor só, em fenda
    return vol, t, olhos


def soldado_mago(rng):
    """Mago das sombras: encapuzado, curvado, manto que se desfaz em trapos (sem pernas: flutua),
    presas saindo do capuz, cajado alto com um orbe e uma chama na outra mão."""
    vol = Volume("mago", 0.06)
    t = bmesh.new()
    for j in range(9):  # manto: abre para baixo
        f = j / 8
        vol.bola((0, -0.1 * f, 4.2 - 0.38 * j), 0.6 + 0.55 * f, achatar=(1.1, 0.85, 1.0))
    for j in range(10):  # barra em trapos
        a = 2 * math.pi * j / 10
        garra(t, (1.05 * math.cos(a), 0.85 * math.sin(a) - 0.1, 1.15), (0.25 * math.cos(a), 0.25 * math.sin(a), -1), (math.cos(a), math.sin(a), 0), 0.9 + 0.35 * (j % 2), 0.3, gancho=0.35, n=10)
    vol.bola((0, 0.25, 4.75), 0.62)  # capuz (curvado para a frente)
    vol.bola((0, -0.2, 4.6), 0.6)
    garra(t, (0, -0.35, 5.1), (0, -1, 0.5), (0, 0, -1), 1.1, 0.34, gancho=0.7)  # bico do capuz
    for lado in (1, -1):
        vol.bola((lado * 0.85, 0, 4.25), 0.48)  # ombros caídos
        garra(t, (lado * 0.24, 0.72, 4.45), (lado * 0.25, 0.35, 1), (0, 1, 0), 0.55, 0.1, gancho=0.35)  # presas
    # braço direito segurando o cajado
    membro(vol, (0.95, 0.1, 4.1), (1.45, 0.7, 3.5), 0.34, 0.3, 4)
    caj = [Vector((1.5, 0.8, 0.7 + 6.0 * j / 15)) for j in range(16)]
    tubo_liso(t, caj, [0.1] * 16, lados=6)
    lua = [Vector((1.5 + 0.55 * math.cos(a), 0.8, 7.05 + 0.55 * math.sin(a))) for a in (math.radians(200 + 320 * j / 15) for j in range(16))]
    tubo_liso(t, lua, [0.13 * math.sin(math.pi * j / 15) + 0.02 for j in range(16)], lados=6, achatar=0.5)
    # braço esquerdo erguido com uma chama
    membro(vol, (-0.95, 0.1, 4.1), (-1.55, 0.75, 4.35), 0.34, 0.28, 4)
    for k in range(4):
        garra(t, (-1.6 + 0.12 * (k - 1.5), 0.8, 4.55), (0.2 * (k - 1.5), 0, 1), (1 if k % 2 else -1, 0, 0), 0.7 + 0.2 * (k % 2), 0.16, gancho=0.5)
    olhos = [[(lado * 0.2, 0.86, 4.8)] for lado in (1, -1)] + [[(1.5, 0.8, 7.05)]]  # dois olhos redondos + orbe
    return vol, t, olhos


def soldado_formiga(rng):
    """Rei-formiga (estilo Beru): magro e curvado, pernas de inseto, braços longos com garras,
    mandíbulas, antenas compridas, abdômen atrás e quatro asas finas."""
    vol = Volume("formiga", 0.055)
    t = bmesh.new()
    for lado in (1, -1):
        # pernas digitígradas (joelho para trás)
        membro(vol, (lado * 0.45, 0.25, 0.15), (lado * 0.5, -0.45, 1.3), 0.22, 0.26, 12)
        membro(vol, (lado * 0.5, -0.45, 1.3), (lado * 0.4, 0.1, 2.5), 0.26, 0.34, 12)
        for k in range(3):
            garra(t, (lado * 0.45, 0.3, 0.15), (lado * 0.4 * (k - 1), 1, -0.1), (0, 0, -1), 0.45, 0.1, gancho=0.4)
        vol.bola((lado * 0.95, 0, 4.25), 0.42)
        garra(t, (lado * 1.05, 0, 4.5), (lado, -0.2, 0.8), (0, 0, 1), 0.6, 0.16, gancho=0.5)
        # braços longos, abertos, com três garras
        membro(vol, (lado * 1.05, 0, 4.1), (lado * 1.75, 0.3, 3.0), 0.24, 0.2, 12)
        membro(vol, (lado * 1.75, 0.3, 3.0), (lado * 1.55, 0.95, 2.2), 0.2, 0.22, 12)
        for k in range(3):
            garra(t, (lado * 1.55, 1.0, 2.15), (lado * 0.35 * (k - 1), 0.8, -0.7), (0, 0, -1), 0.8, 0.1, gancho=0.5)
        # mandíbulas e antenas
        garra(t, (lado * 0.2, 0.5, 4.75), (lado * 0.5, 1, -0.5), (-lado, 0, 0), 0.5, 0.1, gancho=0.7)
        ant = catmull([(lado * 0.2, 0.2, 5.3), (lado * 0.55, 0.3, 6.2), (lado * 0.9, -0.3, 6.9), (lado * 1.0, -1.0, 6.9)], 16)
        tubo_liso(t, ant, [0.06 * (1 - j / 15) + 0.012 for j in range(16)], lados=6)
        # asas de inseto: duas por lado, finas
        for k, (dz, comp) in enumerate(((0.6, 3.4), (-0.5, 2.6))):
            asa = [Vector((lado * (0.3 + 1.6 * f), -0.6 - 1.4 * f, 3.9 + dz * f * 2 + 0.5 * math.sin(f * math.pi))) for f in (j / 13 * comp / 3.4 for j in range(14))]
            tubo_liso(t, asa, [0.55 * math.sin(math.pi * (j / 13) ** 0.7) + 0.02 for j in range(14)], lados=8, achatar=0.08)
    for j in range(6):  # tórax: peito projetado, cintura finíssima
        f = j / 5
        vol.bola((0, 0.1 * f, 2.7 + 0.32 * j), 0.3 + 0.38 * f, achatar=(1.2, 0.9, 1.0))
    vol.bola((0, 0.3, 4.95), 0.42, achatar=(0.9, 1.2, 1.0))  # cabeça alongada
    vol.bola((0, -0.1, 5.15), 0.36)
    for j in range(5):  # abdômen segmentado atrás
        vol.bola((0, -0.55 - 0.42 * j, 2.6 - 0.22 * j), 0.5 - 0.06 * abs(j - 1.5), achatar=(1.0, 1.0, 0.9))
    garra(t, (0, -2.35, 1.6), (0, -1, -0.4), (0, 0, -1), 0.7, 0.2, gancho=0.5)  # ferrão
    olhos = [[(lado * (0.14 + 0.07 * j), 0.68 - 0.03 * j, 5.0 + 0.05 * j) for j in range(4)] for lado in (1, -1)]
    return vol, t, olhos


# tipo: malha, escala no jogo, altura (para emergir), flutua (studs), balanço (graus)
SOLDADOS = [
    ("cavaleiro", soldado_cavaleiro, 4500, dict(escala=1.2, altura=6.6, flutua=0, balanco=0)),
    ("gigante", soldado_gigante, 4500, dict(escala=1.05, altura=8.0, flutua=0, balanco=1)),
    ("mago", soldado_mago, 4000, dict(escala=1.0, altura=7.8, flutua=0.35, balanco=2)),
    ("formiga", soldado_formiga, 5000, dict(escala=1.0, altura=7.2, flutua=0, balanco=4)),
]


def malha_olhos(grupos):
    vol = Volume("olhos", 0.025)
    for g in grupos:
        for p in g:
            vol.bola(p, 0.075 if len(g) > 1 else 0.16)
    bm = vol.malha()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_chama_pequena(rng):
    """Labareda pequena (origem na base): muitas delas sobem e somem em volta do corpo."""
    vol = Volume("pequena", 0.04)
    t = bmesh.new()
    for j in range(6):
        f = j / 5
        vol.bola((0.08 * math.sin(f * 3), 0, 0.15 + 0.5 * f), 0.26 * (1 - 0.45 * f), achatar=(1.0, 0.65, 1.0))
    garra(t, (0.05, 0, 0.55), (0.15, 0, 1), (1, 0, 0), 0.95, 0.17, gancho=0.55)
    garra(t, (-0.12, 0, 0.3), (-0.5, 0, 1), (-1, 0, 0), 0.5, 0.1, gancho=0.6)
    return vol.malha(), t, Vector((0, 0, 0))


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


def escrever_luau(nome, bm, no_corpo, cores=None):
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
    for i in range(len(pos)):  # cor por vértice (multiplica a cor da parte); branca se não houver
        c = cores[i] if cores else (1.0, 1.0, 1.0)
        dados += struct.pack("<3B", *(int(round(min(max(x, 0), 1) * 255)) for x in c))
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
    ("chama_frente_e", lambda r: labareda(r, [(-0.9, 0.55, 0.5), (-1.8, 0.95, 1.0), (-2.4, 0.9, 1.9), (-2.2, 0.8, 2.7), (-1.8, 0.8, 3.0)], 0.42, ((0.3, 0.45, -1),), 1.0), 1400, ch("raiz", 40, 0.8, 0.62, giro=10)),
    ("chama_frente_d", lambda r: labareda(r, [(1.0, 0.55, 0.3), (1.9, 0.95, 0.7), (2.5, 0.9, 1.5), (2.7, 0.8, 2.3), (2.4, 0.8, 2.7)], 0.4, ((0.3, 0.45, 1),), -1.0), 1400, ch("raiz", 40, 0.8, 0.66, giro=10)),
    ("corte_a", lambda r: corte_meia_lua([(-2.1, 0.3, 1.7), (-0.9, 1.0, 2.0), (0.6, 1.1, 2.45), (2.0, 0.5, 3.1)], 0.2), 600, ch("raiz", 80, 0.4, 0.7, tremor=0.0, giro=3, volta=0.5)),
    ("corte_b", lambda r: corte_meia_lua([(1.9, 0.4, 1.4), (0.7, 1.05, 1.15), (-0.7, 1.0, 1.0), (-1.9, 0.3, 0.7)], 0.16), 600, ch("raiz", 80, 0.4, 0.8, tremor=0.0, giro=3, volta=-0.35)),
]
SOLTAS = [
    ("coroa", fazer_coroa, 2500),
    ("coroa_gema", fazer_gema, 50),
    ("chama_pequena", fazer_chama_pequena, 300),
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


def escrever_pecas(lista, soldados):
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
    linhas += ["\t},", "\tsoldados = {"]
    for nome, cfg in soldados:
        campos = ['malha = "monarca_soldado_%s"' % nome, 'olhos = "monarca_soldado_%s_olhos"' % nome] + ["%s = %g" % kv for kv in cfg.items()]
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_LUAU, "MonarcaPecas.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def degrade(bm, pivo):
    """Degradê contínuo pintado nos vértices: escuro na raiz da chama, roxo vivo nas pontas.
    No jogo a cor do vértice multiplica a cor (roxo vivo) da parte."""
    bm.verts.ensure_lookup_table()
    longe = max((v.co - pivo).length for v in bm.verts)
    escuro = (0.2, 0.17, 0.3)
    cores = []
    for v in bm.verts:
        f = suave(0.12, 0.95, (v.co - pivo).length / longe) ** 1.4
        cores.append(tuple(escuro[i] + (1 - escuro[i]) * f for i in range(3)))
    return cores


def objeto(nome, bm, cores=None):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    camada = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for i in range(len(me.vertices)):
        camada.data[i].color_srgb = (*(cores[i] if cores else (1, 1, 1)), 1.0)
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
        corpo, tubos, pivo = fn(random.Random(1300 + i))
        cfg = dict(cfg)
        cfg["pontas"] = 0
        if corpo is None:  # cortes: só a lâmina
            bm = tubos
        else:
            bmesh.ops.remove_doubles(corpo, verts=corpo.verts, dist=0.004)
            suavizar(corpo, 2)
            bm = reduzir(corpo, alvo)
            junta(bm, tubos)
            tubos.free()
        bmesh.ops.triangulate(bm, faces=bm.faces)
        cores = degrade(bm, pivo)
        nv, nt = escrever_luau(nome, bm, True, cores)
        print("%-16s %5d vértices %5d triângulos" % (nome, nv, nt))
        objs[nome] = objeto(nome, bm, cores)
        lista.append((nome, pivo, cfg))
    soldados = []
    for i, (nome, fn, alvo, cfg) in enumerate(SOLDADOS):
        vol, tubos, olhos = fn(random.Random(1500 + i))
        bm = vol.malha()
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
        suavizar(bm, 2)
        bm = reduzir(bm, alvo)
        junta(bm, tubos)
        tubos.free()
        bm = reduzir(bm, alvo)  # corta também os tubos: o soldado inteiro cabe no orçamento
        nv, nt = escrever_luau("soldado_" + nome, bm, False)
        print("%-16s %5d vértices %5d triângulos" % ("soldado_" + nome, nv, nt))
        objs["soldado_" + nome] = objeto("soldado_" + nome, bm)
        bo = malha_olhos(olhos)
        escrever_luau("soldado_" + nome + "_olhos", bo, False)
        objs["soldado_" + nome + "_olhos"] = objeto("soldado_" + nome + "_olhos", bo)
        soldados.append((nome, cfg))
    for i, (nome, fn, alvo) in enumerate(SOLTAS):
        bm, _ = montar(fn, alvo, random.Random(1400 + i), 0.12 if nome == "poca" else None)
        nv, nt = escrever_luau(nome, bm, False)
        print("%-16s %5d vértices %5d triângulos" % (nome, nv, nt))
        objs[nome] = objeto(nome, bm)
    escrever_pecas(lista, soldados)
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


def chama_mat(cor, forca):
    """Emissão = cor x cor do vértice (o degradê)."""
    m = bpy.data.materials.new("chama")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    mix = nt.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    mix.inputs[2].default_value = (*cor, 1)
    nt.links.new(attr.outputs["Color"], mix.inputs[1])
    nt.links.new(mix.outputs[0], em.inputs["Color"])
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
    vivo = emissao("vivo", (0.22, 0.04, 0.75), 2.2)
    fogo = chama_mat((0.2, 0.035, 0.7), 2.2)
    for nome, _, _, _ in CORPO:
        copia(objs[nome], (0, 0, 0), 1, 0, [fogo, roxo])
    rp = random.Random(3)
    for k in range(14):  # labaredas pequenas em volta (inclusive na frente, abaixo dos ombros)
        a = 2 * math.pi * k / 14 + rp.uniform(-0.2, 0.2)
        d = rp.uniform(1.3, 2.3)
        copia(objs["chama_pequena"], (math.cos(a) * d, math.sin(a) * d * 0.8, rp.uniform(0.1, 3.0)), rp.uniform(0.7, 1.3), rp.uniform(0, 6.28), [vivo])
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
    for k, (nome, _, _, cfg) in enumerate(SOLDADOS):
        a = math.radians(45 + 90 * k)
        p = (math.sin(a) * 7.5, math.cos(a) * 7.5, cfg["flutua"])
        e = cfg["escala"]
        copia(objs["soldado_" + nome], p, e, -a, [escuro, roxo], 0.06)
        copia(objs["soldado_" + nome + "_olhos"], p, e, -a, [brilho])
        copia(objs["poca"], (p[0], p[1], 0.02), 2.2, a, [escuro, roxo], 0.02)
    # cada soldado de perto, de frente
    for k, (nome, _, _, cfg) in enumerate(SOLDADOS):
        a = math.radians(45 + 90 * k)
        c = Vector((math.sin(a) * 7.5, math.cos(a) * 7.5, 0))
        fora = Vector((math.sin(a), math.cos(a), 0))
        ladoc = Vector((math.cos(a), -math.sin(a), 0))
        tirar("soldado_" + nome, c + fora * 15 + ladoc * 5 + Vector((0, 0, 4.5)), c + Vector((0, 0, 3.6)), 520, 640)
    tirar("soldados", (10, 27, 12), (0, 0, 2.8), 1000, 700)


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
