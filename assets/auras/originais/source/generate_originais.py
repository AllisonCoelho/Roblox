"""Gera as malhas do LOTE INICIAL das auras originais v2 (testado com bpy 5.3).

Pipeline v2: Blender (este script) -> FBX -> Studio (3D Importer + upload) -> <id>.rbxm
-> Rojo (ReplicatedStorage.AurasOriginais.<id>) -> Mundo/Auras/Originais/Motor.luau clona e anima.

Uso:
    python assets/auras/originais/source/generate_originais.py            # FBX, .blend, manifestos, Luau
    python assets/auras/originais/source/generate_originais.py --render   # também as prévias (Blender, não Roblox)

As peças são modeladas direto em eixos ROBLOX (x, y = cima, z = trás; frente do avatar = -Z) e convertidas
para o Blender em V(). Pivô de cada peça = origem. Cor e material de cada instância vêm do Luau gerado
(src/client/Mundo/Auras/Originais/Definicoes.luau), não de textura. Semente fixa.
"""

import json
import math
import os
import random
import sys

import bpy

import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
DIR_BASE = os.path.join(RAIZ, "assets", "auras", "originais")
DIR_LUAU = os.path.join(RAIZ, "src", "client", "Mundo", "Auras", "Originais")


def V(x, y, z):
    """Roblox -> Blender."""
    return Vector((x, -z, y))


# ---------------------------------------------------------------- primitivas (coordenadas Roblox)


def bipiramide(bm, centro, eixo, comp_cima, comp_baixo, raio, lados=6, rng=None, torcer=0.0, achatar=1.0):
    """Cristal facetado: anel de 'lados' vértices e duas pontas (assimétricas)."""
    rng = rng or random.Random(0)
    e = Vector(eixo).normalized()
    a = e.orthogonal().normalized()
    b = e.cross(a)
    c = Vector(centro)
    anel = []
    for i in range(lados):
        t = 2 * math.pi * i / lados + torcer
        r = raio * rng.uniform(0.85, 1.15)
        p = c + (a * math.cos(t) * r + b * math.sin(t) * r * achatar)
        anel.append(bm.verts.new(V(*p)))
    topo = bm.verts.new(V(*(c + e * comp_cima)))
    base = bm.verts.new(V(*(c - e * comp_baixo)))
    for i in range(lados):
        j = (i + 1) % lados
        bm.faces.new((anel[i], anel[j], topo))
        bm.faces.new((anel[j], anel[i], base))


def prisma_ponta(bm, centro, eixo, comp, raio, ponta, lados=6, rng=None):
    """Prisma de gelo: corpo hexagonal com ponta facetada nas duas extremidades."""
    rng = rng or random.Random(0)
    e = Vector(eixo).normalized()
    a = e.orthogonal().normalized()
    b = e.cross(a)
    c = Vector(centro)
    aneis = []
    for k, h in enumerate((-comp / 2, comp / 2)):
        anel = []
        for i in range(lados):
            t = 2 * math.pi * i / lados
            r = raio * (1 + 0.12 * math.sin(i * 2.3 + k))
            anel.append(bm.verts.new(V(*(c + e * h + a * math.cos(t) * r + b * math.sin(t) * r))))
        aneis.append(anel)
    topo = bm.verts.new(V(*(c + e * (comp / 2 + ponta))))
    base = bm.verts.new(V(*(c - e * (comp / 2 + ponta * 0.45))))
    for i in range(lados):
        j = (i + 1) % lados
        bm.faces.new((aneis[0][i], aneis[0][j], aneis[1][j], aneis[1][i]))
        bm.faces.new((aneis[1][i], aneis[1][j], topo))
        bm.faces.new((aneis[0][j], aneis[0][i], base))


def tubo(bm, pts, raios, lados=8, achatar=1.0, fechar=True):
    """Tubo ao longo de uma polilinha (pontos Roblox), com raio variável."""
    pts = [Vector(p) for p in pts]
    aneis = []
    anterior = None
    for k, p in enumerate(pts):
        t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        if anterior is None:
            n = t.orthogonal().normalized()
        else:
            n = (anterior - t * anterior.dot(t)).normalized()
        anterior = n
        bi = t.cross(n)
        r = raios[k] if isinstance(raios, (list, tuple)) else raios
        anel = []
        for i in range(lados):
            a = 2 * math.pi * i / lados
            anel.append(bm.verts.new(V(*(p + n * math.cos(a) * r + bi * math.sin(a) * r * achatar))))
        aneis.append(anel)
    for k in range(len(aneis) - 1):
        for i in range(lados):
            j = (i + 1) % lados
            bm.faces.new((aneis[k][i], aneis[k][j], aneis[k + 1][j], aneis[k + 1][i]))
    if fechar:
        for anel, ponta in ((aneis[0], pts[0]), (aneis[-1], pts[-1])):
            c = bm.verts.new(V(*ponta))
            for i in range(lados):
                j = (i + 1) % lados
                bm.faces.new((anel[i], anel[j], c) if anel is aneis[-1] else (anel[j], anel[i], c))


def placa(bm, contorno, espessura, matriz=Matrix.Identity(4)):
    """Polígono (lista de (x, y) no plano local XY) extrudado em Z, transformado por 'matriz' (Roblox)."""
    n = len(contorno)
    cima, baixo = [], []
    for x, y in contorno:
        cima.append(bm.verts.new(V(*(matriz @ Vector((x, y, espessura / 2))))))
        baixo.append(bm.verts.new(V(*(matriz @ Vector((x, y, -espessura / 2))))))
    cc = bm.verts.new(V(*(matriz @ Vector((sum(p[0] for p in contorno) / n, sum(p[1] for p in contorno) / n, espessura / 2)))))
    cb = bm.verts.new(V(*(matriz @ Vector((sum(p[0] for p in contorno) / n, sum(p[1] for p in contorno) / n, -espessura / 2)))))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((cima[i], cima[j], cc))
        bm.faces.new((baixo[j], baixo[i], cb))
        bm.faces.new((cima[j], cima[i], baixo[i], baixo[j]))


def caixa(bm, centro, tam, matriz=Matrix.Identity(4)):
    t = bmesh.ops.create_cube(bm, size=1.0)
    for v in t["verts"]:
        p = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2])) + Vector(centro)
        v.co = V(*(matriz @ p))


def arco_pts(raio, a0, a1, n, y=0.0, onda=0.0):
    return [(math.cos(a0 + (a1 - a0) * i / (n - 1)) * raio, y + onda * math.sin(math.pi * i / (n - 1)), math.sin(a0 + (a1 - a0) * i / (n - 1)) * raio) for i in range(n)]


def estrela(pontas, r_ext, r_int, irregular=0.0, rng=None):
    rng = rng or random.Random(0)
    pts = []
    for i in range(pontas * 2):
        a = math.pi / 2 + math.pi * i / pontas
        r = (r_ext * rng.uniform(1 - irregular, 1 + irregular)) if i % 2 == 0 else r_int
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def rot(rx=0, ry=0, rz=0):
    """Euler em graus, ordem Roblox (X, Y, Z) aplicada em coordenadas Roblox."""
    return (Matrix.Rotation(math.radians(rx), 4, "X") @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rz), 4, "Z"))


# ---------------------------------------------------------------- peças por aura

PECAS = {}  # (aura, nome) -> função(bm, rng)


def peca(aura, nome):
    def reg(fn):
        PECAS[(aura, nome)] = fn
        return fn

    return reg


# 01 Centelha do Nexo — losango dourado, lascas, halo interrompido
@peca("centelha_do_nexo", "nucleo")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0, 1, 0), 0.62, 0.48, 0.34, lados=4, rng=random.Random(1))
    bipiramide(bm, (0, 0, 0), (0, 1, 0), 0.32, 0.25, 0.42, lados=4, torcer=math.pi / 4, rng=random.Random(2), achatar=0.4)


@peca("centelha_do_nexo", "lasca")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0.15, 1, 0.05), 0.55, 0.22, 0.12, lados=5, rng=rng, achatar=0.6)


@peca("centelha_do_nexo", "halo")
def _(bm, rng):
    for a0, a1, r in ((0.2, 1.7, 2.3), (2.1, 3.3, 2.35), (3.8, 5.6, 2.28)):
        n = max(6, int((a1 - a0) * 9))
        tubo(bm, arco_pts(r, a0, a1, n, onda=0.08), [0.025 + 0.055 * math.sin(math.pi * i / (n - 1)) for i in range(n)], lados=6, achatar=0.5)


# 06 Gelo de Néon — quatro prismas laterais e uma lasca alta atrás da cabeça
@peca("gelo_de_neon", "prisma")
def _(bm, rng):
    prisma_ponta(bm, (0, 0, 0), (0, 1, 0), 0.9, 0.2, 0.45, rng=rng)
    bipiramide(bm, (0.17, -0.25, 0.05), (0.5, 1, 0.1), 0.35, 0.1, 0.07, lados=5, rng=rng)


@peca("gelo_de_neon", "lasca_alta")
def _(bm, rng):
    prisma_ponta(bm, (0, 0, 0), (0, 1, 0), 1.9, 0.22, 0.75, rng=rng)
    for k, (dx, dy, s) in enumerate(((0.3, -0.5, 0.6), (-0.28, -0.2, 0.5), (0.22, 0.4, 0.4))):
        bipiramide(bm, (dx, dy, 0.05), (dx * 1.6, 1, 0.1), 0.5 * s + 0.2, 0.12, 0.09, lados=5, rng=random.Random(k))


@peca("gelo_de_neon", "estrela")
def _(bm, rng):
    placa(bm, estrela(6, 1.0, 0.32, 0.08, rng), 0.08)


# 17 Prisma Partilhado — seis cunhas de cristal em volta de um centro vazio
@peca("prisma_partilhado", "cunha")
def _(bm, rng):
    placa(bm, [(-0.28, -0.5), (0.28, -0.5), (0.12, 0.5), (-0.05, 0.62)], 0.22)


@peca("prisma_partilhado", "raio")
def _(bm, rng):
    bipiramide(bm, (0, 1.6, 0), (0, 1, 0), 1.6, 1.6, 0.07, lados=4, rng=random.Random(3))


# 30 Arquivista Espectral — pergaminhos vivos e mãos caligráficas
@peca("arquivista_espectral", "pergaminho")
def _(bm, rng):
    tubo(bm, [(-0.65, 0.55, 0), (0.65, 0.55, 0)], 0.13, lados=10)
    folha = []
    for i in range(9):
        t = i / 8
        folha.append((0, 0.5 - t * 1.35, 0.12 * math.sin(t * math.pi * 1.5)))
    # folha pendurada: faixa ondulada
    esquerda = [bm.verts.new(V(-0.58, y, z)) for _, y, z in folha]
    direita = [bm.verts.new(V(0.58, y, z + 0.02)) for _, y, z in folha]
    esq_v = [bm.verts.new(V(-0.58, y, z + 0.025)) for _, y, z in folha]  # verso (dupla face real)
    dir_v = [bm.verts.new(V(0.58, y, z + 0.045)) for _, y, z in folha]
    for i in range(len(folha) - 1):
        bm.faces.new((esquerda[i], direita[i], direita[i + 1], esquerda[i + 1]))
        bm.faces.new((esq_v[i + 1], dir_v[i + 1], dir_v[i], esq_v[i]))
    for k in range(3):  # linhas de "texto" que se escrevem sozinhas
        y = 0.25 - k * 0.32
        caixa(bm, (0.0 - 0.1 * (k % 2), y, 0.12 * math.sin((0.5 - y) / 1.35 * math.pi * 1.5) - 0.025), (0.8 - 0.2 * k, 0.04, 0.02))


@peca("arquivista_espectral", "mao")
def _(bm, rng):
    caixa(bm, (0, 0, 0), (0.5, 0.55, 0.16))
    for k, (x, comp, curva) in enumerate(((-0.18, 0.55, 0.2), (-0.06, 0.65, 0.15), (0.06, 0.62, 0.12), (0.18, 0.5, 0.18))):
        pts = [(x, 0.27 + comp * t, -curva * t * t) for t in (0, 0.33, 0.66, 1.0)]
        tubo(bm, pts, [0.055, 0.05, 0.045, 0.03], lados=6)
    tubo(bm, [(0.25, 0.0, 0), (0.42, 0.18, -0.08), (0.5, 0.36, -0.15)], [0.06, 0.05, 0.035], lados=6)
    # pena de caligrafia presa entre os dedos
    tubo(bm, [(-0.05, 0.1, -0.15), (0.1, 0.9, -0.35), (0.2, 1.35, -0.45)], [0.02, 0.035, 0.005], lados=5)


@peca("arquivista_espectral", "pagina")
def _(bm, rng):
    placa(bm, [(-0.35, -0.45), (0.35, -0.45), (0.35, 0.45), (-0.35, 0.45)], 0.02)


# 50 Coração de Fênix — costelas douradas, asas de penas triangulares, núcleo
@peca("coracao_de_fenix", "costelas")
def _(bm, rng):
    tubo(bm, [(0, -0.9, 0), (0, 0, 0.12), (0, 0.9, 0.05), (0, 1.3, -0.1)], [0.05, 0.08, 0.07, 0.04], lados=6)
    for k in range(5):
        y = 0.75 - k * 0.36
        larg = 0.75 - abs(k - 1.5) * 0.12
        for s in (-1, 1):
            pts = [(0, y, 0.1), (s * larg * 0.6, y - 0.05, 0.0), (s * larg, y - 0.15, -0.3), (s * larg * 0.8, y - 0.25, -0.55)]
            tubo(bm, pts, [0.045, 0.04, 0.03, 0.012], lados=5)


def asa(bm, lado, rng):
    for k in range(8):
        a = math.radians(-15 + k * 13)
        comp = 1.1 + 0.9 * math.sin(math.pi * (k + 1) / 9) + rng.uniform(-0.1, 0.1)
        larg = 0.22 + 0.06 * (k % 2)
        m = Matrix.Translation(Vector((lado * 0.15 * k, 0.05 * k, 0.04 * k))) @ rot(0, 0, lado * (math.degrees(a) - 90)) @ rot(lado * 8, 0, 0)
        placa(bm, [(-larg * 0.3, 0), (larg, comp * 0.35), (0, comp), (-larg, comp * 0.4)], 0.05, m)
    tubo(bm, [(0, 0, 0), (lado * 0.55, 0.3, 0.05), (lado * 1.15, 0.45, 0.15)], [0.07, 0.06, 0.03], lados=6)


@peca("coracao_de_fenix", "asa_esq")
def _(bm, rng):
    asa(bm, -1, rng)


@peca("coracao_de_fenix", "asa_dir")
def _(bm, rng):
    asa(bm, 1, rng)


@peca("coracao_de_fenix", "nucleo")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0, 1, 0), 0.32, 0.4, 0.26, lados=7, rng=rng)


# 61 Leviatã Astral — baleia cósmica translúcida
@peca("leviata_astral", "baleia")
def _(bm, rng):
    n = 16
    pts, raios = [], []
    for i in range(n):
        t = i / (n - 1)
        pts.append((0, 0.25 * math.sin(t * math.pi) - 0.15 * t * t, -3.0 + 6.0 * t))  # cabeça na frente (-Z)
        raios.append(0.08 + 0.75 * math.sin(math.pi * min(t * 1.25, 1.0)) ** 0.7 * (1 - 0.85 * t ** 2))
    tubo(bm, pts, raios, lados=12, achatar=0.8)
    for s in (-1, 1):  # nadadeiras peitorais enormes
        placa(bm, [(0, 0), (1.9, -0.5), (2.3, -0.9), (0.6, -0.55)], 0.08, Matrix.Translation(Vector((s * 0.55, -0.2, -1.4))) @ rot(90, 0, 0) @ rot(0, 0, 0) @ Matrix.Scale(-1 if s < 0 else 1, 4, Vector((1, 0, 0))))
    for s in (-1, 1):  # cauda
        placa(bm, [(0, 0), (1.2, 0.35), (1.35, -0.1), (0.4, -0.2)], 0.06, Matrix.Translation(Vector((0, -0.2, 3.0))) @ rot(90, 0, 0) @ Matrix.Scale(-1 if s < 0 else 1, 4, Vector((1, 0, 0))))
    placa(bm, [(0, 0), (0.15, 0.55), (0.6, 0.05)], 0.05, Matrix.Translation(Vector((0, 0.55, 0.3))) @ rot(0, 90, 0))  # dorsal


@peca("leviata_astral", "estrela")
def _(bm, rng):
    placa(bm, estrela(4, 0.3, 0.07), 0.05)


# 67 Soberania do Vazio — coroa branca, monólitos negros, estrela de vazio
@peca("soberania_do_vazio", "coroa")
def _(bm, rng):
    n = 28
    tubo(bm, arco_pts(0.75, 0, 2 * math.pi, n), 0.05, lados=6, fechar=False)
    for k in range(7):
        a = 2 * math.pi * k / 7
        alto = 0.75 if k % 2 == 0 else 0.45
        m = Matrix.Translation(Vector((math.cos(a) * 0.75, 0.0, math.sin(a) * 0.75))) @ rot(0, -math.degrees(a) + 90, 0)
        placa(bm, [(-0.14, 0), (0.14, 0), (0.03, alto * 0.6), (0, alto), (-0.03, alto * 0.6)], 0.05, m)


@peca("soberania_do_vazio", "monolito")
def _(bm, rng):
    placa(bm, [(-0.22, -1.0), (0.2, -1.0), (0.24, 0.75), (0.0, 1.05), (-0.24, 0.8)], 0.26)


@peca("soberania_do_vazio", "estrela_vazio")
def _(bm, rng):
    placa(bm, estrela(8, 1.5, 0.45, 0.15, random.Random(9)), 0.06)


@peca("soberania_do_vazio", "estrela_borda")
def _(bm, rng):
    pts = estrela(8, 1.58, 0.5, 0.15, random.Random(9))
    pts3 = [(x, y, 0) for x, y in pts] + [(pts[0][0], pts[0][1], 0)]
    tubo(bm, [(x, y, z) for x, y, z in pts3], 0.035, lados=5, fechar=False)



# ================================================================ Comuns e Incomuns (lote de acesso)


def bolha(bm, centro, raio, sub=2, achatar=(1, 1, 1), rng=None):
    rng = rng or random.Random(0)
    t = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in t["verts"]:
        d = v.co.copy()
        r = raio * (1 + rng.uniform(-0.08, 0.08))
        p = Vector(centro) + Vector((d.x * r * achatar[0], d.z * r * achatar[1], d.y * r * achatar[2]))
        v.co = V(*p)


def gota(bm, centro, eixo, comp, raio, lados=8):
    e = Vector(eixo).normalized()
    c = Vector(centro)
    n = 9
    pts = [c - e * comp * 0.35 + e * comp * i / (n - 1) for i in range(n)]
    raios = [raio * math.sin(math.pi * min(1, (i / (n - 1)) * 1.6)) ** 0.6 * (1 - (i / (n - 1)) ** 1.5) + 0.004 for i in range(n)]
    tubo(bm, [tuple(p) for p in pts], raios, lados=lados)


@peca("musgo_luminoso", "raiz")
def _(bm, rng):
    pts = [(0, 0.1, 0), (0.35, 0.0, 0.1), (0.7, 0.25, -0.05), (0.95, 0.15, 0.25), (1.25, 0.4, 0.3)]
    tubo(bm, pts, [0.14, 0.11, 0.08, 0.05, 0.015], lados=7)
    tubo(bm, [(0.7, 0.25, -0.05), (0.8, 0.5, -0.35), (0.7, 0.75, -0.5)], [0.05, 0.03, 0.01], lados=5)


@peca("musgo_luminoso", "broto")
def _(bm, rng):
    tubo(bm, [(0, 0, 0), (0.04, 0.3, 0), (0, 0.55, 0.03)], [0.05, 0.04, 0.03], lados=6)
    for s in (-1, 1):
        m = Matrix.Translation(Vector((0, 0.52, 0))) @ rot(0, 0, s * -55) @ rot(25, 0, 0)
        placa(bm, [(0, 0), (0.12, 0.12), (0.06, 0.38), (0, 0.42), (-0.06, 0.3), (-0.1, 0.1)], 0.025, m)


@peca("musgo_luminoso", "esporo")
def _(bm, rng):
    placa(bm, estrela(5, 0.16, 0.06), 0.05)


@peca("fagulha_de_cobre", "caco")
def _(bm, rng):
    placa(bm, [(-0.25, -0.2), (0.22, -0.28), (0.3, 0.05), (0.08, 0.32), (-0.2, 0.18)], 0.06, rot(10, 15, 0))


@peca("fagulha_de_cobre", "filamento")
def _(bm, rng):
    tubo(bm, [(0, 0, 0), (0.2, 0.25, 0.05), (0.1, 0.55, -0.1), (0.3, 0.8, 0)], [0.035, 0.03, 0.022, 0.008], lados=5)
    caixa(bm, (0.3, 0.85, 0), (0.08, 0.08, 0.08))


@peca("chuvisco_de_vidro", "gota")
def _(bm, rng):
    gota(bm, (0, 0, 0), (0, -1, 0), 1.0, 0.2, lados=8)
    caixa(bm, (0.05, 0.05, 0.0), (0.03, 0.4, 0.22), rot(0, 0, 30))  # corte diagonal (lâmina de vidro)


@peca("chuvisco_de_vidro", "prisma_mini")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0.2, 1, 0), 0.22, 0.22, 0.09, lados=3, rng=rng)


@peca("borboletas_de_cinza", "mariposa")
def _(bm, rng):
    tubo(bm, [(0, -0.18, 0), (0, 0.2, 0)], [0.04, 0.025], lados=6)
    for s in (-1, 1):
        sup = [(0, 0.05), (0.2, 0.32), (0.42, 0.28), (0.38, 0.12), (0.46, 0.0), (0.3, 0.03), (0.1, -0.02)]
        inf = [(0, -0.02), (0.22, -0.05), (0.3, -0.22), (0.15, -0.3), (0.04, -0.15)]
        for forma in (sup, inf):
            placa(bm, [(s * x, y) for x, y in (forma if s > 0 else list(reversed(forma)))], 0.012, rot(0, 0, 0) @ Matrix.Translation(Vector((0, 0, 0))) @ rot(s * 12, 0, 0) @ rot(0, s * 15, 0) @ rot(90, 0, 0) @ rot(-90, 0, 0))
    bipiramide(bm, (0.2, 0.18, 0.012), (0, 0, 1), 0.01, 0.01, 0.05, lados=5)  # olho violeta (só na manifestação aparece com brilho)


@peca("mare_de_quartzo", "fita")
def _(bm, rng):
    pts = [(math.cos(t) * 2.3, -1.6 + 2.8 * t / math.pi, math.sin(t) * 2.0) for t in [math.pi * i / 22 for i in range(23)]]
    tubo(bm, pts, [0.04 + 0.16 * math.sin(math.pi * i / 22) for i in range(23)], lados=6, achatar=0.25)


@peca("mare_de_quartzo", "concha")
def _(bm, rng):
    for k in range(7):
        a = math.radians(-60 + k * 20)
        placa(bm, [(-0.04, 0), (0.04, 0), (0.09, 0.42), (-0.09, 0.42)], 0.03, rot(0, 0, math.degrees(a)) @ rot(12 * (k % 2), 0, 0))


@peca("mare_de_quartzo", "bolha")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0, 1, 0), 0.16, 0.16, 0.16, lados=6, rng=rng)


@peca("raiz_cintilante", "cipo")
def _(bm, rng):
    n = 28
    pts = [(math.cos(i * 0.62) * 0.62, -2.9 + 2.6 * i / (n - 1), math.sin(i * 0.62) * 0.62) for i in range(n)]
    tubo(bm, pts, [0.075 - 0.05 * i / (n - 1) for i in range(n)], lados=5)
    for k in (8, 15, 22):
        x, y, z = pts[k]
        placa(bm, [(0, 0), (0.12, 0.1), (0, 0.3), (-0.12, 0.1)], 0.02, Matrix.Translation(Vector((x * 1.15, y, z * 1.15))) @ rot(0, -k * 35, 40))


@peca("raiz_cintilante", "semente")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0, 1, 0), 0.2, 0.12, 0.1, lados=6, rng=rng)


@peca("raiz_cintilante", "arvore")
def _(bm, rng):
    tubo(bm, [(0, 0, 0), (0.05, 0.8, 0), (-0.05, 1.6, 0.05)], [0.16, 0.1, 0.06], lados=7)
    for k in range(5):
        a = k * 72
        m = rot(0, a, 0)
        p0 = (0, 1.0 + 0.15 * k, 0)
        p1 = tuple(m @ Vector((0.55, 1.5 + 0.12 * k, 0)))
        p2 = tuple(m @ Vector((0.9, 1.75 + 0.1 * k, 0.1)))
        tubo(bm, [p0, p1, p2], [0.06, 0.035, 0.01], lados=5)
        bipiramide(bm, p2, (0, 1, 0), 0.14, 0.08, 0.08, lados=5, rng=rng)


@peca("nevoa_de_amora", "massa")
def _(bm, rng):
    for k in range(5):
        bolha(bm, (rng.uniform(-0.35, 0.35), rng.uniform(-0.2, 0.25), rng.uniform(-0.25, 0.25)), rng.uniform(0.35, 0.55), sub=2, rng=rng)


@peca("nevoa_de_amora", "caroco")
def _(bm, rng):
    for k in range(6):
        a = k * 1.05
        bolha(bm, (math.cos(a) * 0.12, math.sin(a * 2) * 0.08, math.sin(a) * 0.12), 0.08, sub=1, rng=rng)


@peca("vento_de_papel", "passaro")
def _(bm, rng):
    placa(bm, [(0, -0.35), (0.07, 0.0), (0, 0.4), (-0.07, 0.0)], 0.06, rot(90, 0, 0))
    for s in (-1, 1):
        placa(bm, [(0, -0.12), (s * 0.55, 0.05), (s * 0.18, 0.2), (0, 0.15)], 0.015, rot(90, 0, 0) @ rot(0, s * 18, 0))
    placa(bm, [(0, 0.38), (0.08, 0.52), (-0.02, 0.46)], 0.02, rot(90, 0, 0) @ rot(0, 70, 0))


@peca("vento_de_papel", "tira")
def _(bm, rng):
    n = 14
    pts = [(0.12 * math.sin(i * 0.8), 1.2 * i / (n - 1), 0.25 * math.sin(i * 0.5)) for i in range(n)]
    tubo(bm, pts, 0.09, lados=4, achatar=0.12)


@peca("polen_lunar", "coroa_estames")
def _(bm, rng):
    tubo(bm, arco_pts(0.55, math.pi * 0.1, math.pi * 0.9, 14), 0.025, lados=5)
    for k in range(9):
        a = math.pi * (0.12 + 0.76 * k / 8)
        base = (math.cos(a) * 0.55, 0, math.sin(a) * 0.55)
        topo = (math.cos(a) * 0.75, 0.45 + 0.15 * (k % 2), math.sin(a) * 0.75)
        tubo(bm, [base, topo], [0.015, 0.008], lados=4)
        bolha(bm, topo, 0.045, sub=1, rng=rng)


@peca("polen_lunar", "grao")
def _(bm, rng):
    gota(bm, (0, 0, 0), (0, 1, 0), 0.32, 0.08, lados=6)


@peca("polen_lunar", "disco")
def _(bm, rng):
    tubo(bm, arco_pts(1.0, 0, 2 * math.pi, 40), 0.05, lados=6, fechar=False, achatar=0.4)
    for k in range(12):
        a = 2 * math.pi * k / 12
        placa(bm, [(0, 0), (0.08, 0.35), (0, 0.55), (-0.08, 0.35)], 0.02, Matrix.Translation(Vector((math.cos(a) * 0.3, 0, math.sin(a) * 0.3))) @ rot(90, 0, 0) @ rot(0, 0, -math.degrees(a) - 90))


@peca("engrenagem_de_orvalho", "engrenagem")
def _(bm, rng):
    dentes, r_ext, r_int = 12, 0.62, 0.5
    pts = []
    for i in range(dentes * 4):
        a = 2 * math.pi * i / (dentes * 4)
        r = r_ext if i % 4 in (1, 2) else r_int
        pts.append((math.cos(a) * r, math.sin(a) * r))
    placa(bm, pts, 0.1)
    for k in range(4):  # gotas encaixadas
        a = 2 * math.pi * k / 4 + 0.2
        gota(bm, (math.cos(a) * 0.68, math.sin(a) * 0.68, 0.0), (math.cos(a), math.sin(a), 0), 0.22, 0.07, lados=6)


@peca("trilha_de_vaga_lumes", "vagalume")
def _(bm, rng):
    tubo(bm, [(0, 0, -0.18), (0, 0.02, 0.0), (0, 0, 0.12)], [0.05, 0.06, 0.045], lados=7)
    bolha(bm, (0, -0.01, 0.22), 0.09, sub=1, rng=rng)  # cauda luminosa
    for s in (-1, 1):
        placa(bm, [(0, 0), (s * 0.28, 0.06), (s * 0.22, -0.08)], 0.008, Matrix.Translation(Vector((0, 0.06, -0.05))) @ rot(90, 0, 0) @ rot(0, s * -20, 0))


@peca("ambar_vivo", "placa")
def _(bm, rng):
    contorno = []
    for i in range(9):
        a = 2 * math.pi * i / 9
        r = 0.42 * (1 + 0.25 * math.sin(i * 2.7))
        contorno.append((math.cos(a) * r * 0.8, math.sin(a) * r * 1.2))
    placa(bm, contorno, 0.18, rot(8, 12, 0))
    placa(bm, [(0, -0.2), (0.07, 0.0), (0, 0.22), (-0.07, 0.0)], 0.02, Matrix.Translation(Vector((0.05, 0, 0.0))) @ rot(0, 0, 25))  # folha presa dentro


# ================================================================ Raras


def anel(bm, raio, espessura, n=32, y=0.0, a0=0.0, a1=2 * math.pi, achatar=1.0, lados=6):
    tubo(bm, arco_pts(raio, a0, a1, n, y=y), espessura, lados=lados, fechar=abs(a1 - a0) < 6.2, achatar=achatar)


@peca("coroa_de_coral", "galho")
def _(bm, rng):
    def ramo(p0, direcao, comp, r, nivel):
        p1 = Vector(p0) + Vector(direcao).normalized() * comp
        tubo(bm, [tuple(p0), tuple((Vector(p0) + p1) / 2 + Vector((rng.uniform(-0.05, 0.05), 0, 0))), tuple(p1)], [r, r * 0.8, r * 0.55], lados=6)
        bolha(bm, tuple(p1), r * 0.7, sub=1, rng=rng)
        if nivel < 3:
            for s in (-1, 1):
                d = Vector(direcao).normalized() + Vector((s * rng.uniform(0.5, 0.9), rng.uniform(0.1, 0.4), rng.uniform(-0.3, 0.3)))
                ramo(p1, d, comp * 0.7, r * 0.7, nivel + 1)

    ramo(Vector((0, 0, 0)), Vector((0, 1, 0.1)), 0.7, 0.09, 0)


@peca("relampago_de_giz", "raio")
def _(bm, rng):
    pts = [(0, 1.4), (0.35, 0.55), (0.12, 0.5), (0.45, -0.3), (0.2, -0.32), (0.4, -1.4), (-0.25, -0.15), (-0.02, -0.12), (-0.3, 0.6), (-0.08, 0.62)]
    placa(bm, pts, 0.12)


@peca("relampago_de_giz", "placa_tri")
def _(bm, rng):
    placa(bm, [(-0.25, -0.2), (0.28, -0.15), (0.0, 0.3)], 0.05)


@peca("jiboia_de_fumaca", "corpo")
def _(bm, rng):
    n = 30
    pts, raios = [], []
    for i in range(n):
        t = i / (n - 1)
        a = math.pi * 1.5 * t
        pts.append((math.cos(a) * 2.4, -1.0 + 2.6 * t + 0.35 * math.sin(t * 9), math.sin(a) * 2.2))
        raios.append(0.12 + 0.42 * math.sin(math.pi * min(1, t * 1.1)) ** 0.8)
    tubo(bm, pts, raios, lados=10)


@peca("fenda_de_porcelana", "caco")
def _(bm, rng):
    placa(bm, [(-0.35, -0.3), (0.1, -0.38), (0.4, -0.05), (0.25, 0.35), (-0.15, 0.4), (-0.4, 0.05)], 0.06, rot(0, 0, 0))
    for k in range(3):  # rachaduras azuis em relevo
        a = k * 2.1
        tubo(bm, [(0, 0, 0.035), (math.cos(a) * 0.18, math.sin(a) * 0.18, 0.035), (math.cos(a + 0.4) * 0.32, math.sin(a + 0.4) * 0.32, 0.035)], 0.012, lados=4)


@peca("fenda_de_porcelana", "mascara")
def _(bm, rng):
    contorno = [(math.cos(a) * 0.5 * (1 if math.sin(a) > 0 else 0.85), math.sin(a) * 0.65) for a in [2 * math.pi * i / 20 for i in range(20)]]
    placa(bm, contorno, 0.08)
    for s in (-1, 1):
        caixa(bm, (s * 0.2, 0.12, 0.05), (0.16, 0.06, 0.04))
    tubo(bm, [(0.05, 0.6, 0.05), (-0.1, 0.2, 0.05), (0.08, -0.15, 0.05), (-0.05, -0.6, 0.05)], 0.02, lados=4)


@peca("petalas_de_ferrugem", "petala")
def _(bm, rng):
    placa(bm, [(0, -0.45), (0.22, -0.2), (0.28, 0.15), (0.12, 0.42), (0, 0.55), (-0.12, 0.42), (-0.28, 0.15), (-0.22, -0.2)], 0.045, rot(15, 0, 0))
    caixa(bm, (0, -0.25, 0.03), (0.12, 0.14, 0.04))  # miolo escuro


@peca("sinos_do_crepusculo", "sino")
def _(bm, rng):
    pts = [(0, 0.55, 0), (0, 0.42, 0), (0, 0.15, 0), (0, -0.15, 0), (0, -0.32, 0)]
    tubo(bm, pts, [0.03, 0.14, 0.18, 0.24, 0.32], lados=12, fechar=False)
    bolha(bm, (0, -0.28, 0), 0.07, sub=1, rng=rng)
    tubo(bm, [(0, 0.55, 0), (0, 0.95, 0)], 0.012, lados=4)


@peca("sinos_do_crepusculo", "onda")
def _(bm, rng):
    anel(bm, 0.6, 0.025, n=36, achatar=0.4)


@peca("esporos_de_safira", "cogumelo")
def _(bm, rng):
    tubo(bm, [(0, -0.6, 0), (0.05, -0.2, 0), (0, 0.2, 0.02)], [0.07, 0.06, 0.05], lados=7)
    pts = [(0, 0.45, 0), (0, 0.38, 0), (0, 0.25, 0), (0, 0.18, 0)]
    tubo(bm, pts, [0.02, 0.3, 0.42, 0.38], lados=12)


@peca("esporos_de_safira", "esporo_cubo")
def _(bm, rng):
    caixa(bm, (0, 0, 0), (0.14, 0.14, 0.14), rot(30, 45, 0))


@peca("solsticio_de_areia", "duna")
def _(bm, rng):
    n = 14
    pts = [(-1.0 + 2.0 * i / (n - 1), 0.2 * math.sin(math.pi * i / (n - 1)) ** 2, 0) for i in range(n)]
    tubo(bm, pts, [0.03 + 0.14 * math.sin(math.pi * i / (n - 1)) for i in range(n)], lados=5, achatar=0.35)


@peca("solsticio_de_areia", "relogio")
def _(bm, rng):
    anel(bm, 0.55, 0.04, n=30, a0=0.0, a1=math.pi * 1.6)
    for k in range(8):
        a = k * math.pi * 1.6 / 8
        caixa(bm, (math.cos(a) * 0.45, 0, math.sin(a) * 0.45), (0.04, 0.03, 0.12), rot(0, -math.degrees(a), 0))
    placa(bm, [(0, 0), (0.05, 0.5), (-0.05, 0.5)], 0.03, rot(90, 0, 0) @ rot(0, 0, -40))


@peca("marfim_flutuante", "presa")
def _(bm, rng):
    n = 12
    pts = [(0.35 * (i / (n - 1)) ** 2, -0.8 + 1.6 * i / (n - 1), 0) for i in range(n)]
    tubo(bm, pts, [0.14 * (1 - (i / (n - 1)) ** 1.3) + 0.01 for i in range(n)], lados=8)
    anel(bm, 0.16, 0.025, n=14, y=-0.55)  # encaixe metálico
    tubo(bm, [(0, -0.6, 0.15), (0.02, -0.9, 0.18)], 0.01, lados=4)
    bipiramide(bm, (0.02, -0.98, 0.18), (0, 1, 0), 0.05, 0.08, 0.04, lados=4)


@peca("lotus_de_gravidade", "lotus")
def _(bm, rng):
    for camada, (n, r, inc) in enumerate(((8, 0.85, 50), (6, 0.6, 35))):
        for k in range(n):
            a = 360 * k / n + camada * 22
            placa(bm, [(0, 0), (0.18, 0.3), (0.0, 0.8 * r + 0.2), (-0.18, 0.3)], 0.06, rot(0, a, 0) @ rot(180 - inc, 0, 0))
    bolha(bm, (0, -0.05, 0), 0.22, sub=2, rng=rng)


@peca("lotus_de_gravidade", "petala_solta")
def _(bm, rng):
    placa(bm, [(0, 0), (0.14, 0.22), (0.0, 0.55), (-0.14, 0.22)], 0.05)


@peca("espelho_de_chuva", "espelho")
def _(bm, rng):
    caixa(bm, (0, 0, 0), (0.9, 1.2, 0.05))
    for x in (-0.47, 0.47):
        caixa(bm, (x, 0, 0), (0.05, 1.28, 0.09))
    for y in (-0.62, 0.62):
        caixa(bm, (0, y, 0), (0.98, 0.05, 0.09))


@peca("espelho_de_chuva", "gota_espelho")
def _(bm, rng):
    gota(bm, (0, 0, 0), (0, 1, 0), 0.3, 0.06, lados=6)


@peca("capsula_de_tempestade", "capsula")
def _(bm, rng):
    for k in range(6):  # grade vazada: meridianos
        a = math.pi * k / 6
        pts = [(math.cos(a) * math.sin(t) * 0.7, math.cos(t) * 0.7, math.sin(a) * math.sin(t) * 0.7) for t in [math.pi * i / 16 for i in range(17)]]
        tubo(bm, pts, 0.025, lados=5, fechar=False)
    for y in (-0.35, 0.0, 0.35):
        anel(bm, math.sqrt(0.49 - y * y), 0.025, n=24, y=y, lados=5)


@peca("capsula_de_tempestade", "aro")
def _(bm, rng):
    anel(bm, 1.05, 0.05, n=36, a0=0.3, a1=2 * math.pi - 0.3, lados=6)


@peca("capsula_de_tempestade", "trovao")
def _(bm, rng):
    placa(bm, [(0, 0.45), (0.12, 0.08), (0.04, 0.06), (0.14, -0.45), (-0.1, -0.02), (-0.02, -0.0)], 0.04)


@peca("cauda_de_cometa", "nucleo")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.32, sub=1, rng=random.Random(3))


@peca("cauda_de_cometa", "faixa")
def _(bm, rng):
    n = 16
    pts = [(0.15 * math.sin(i * 0.5), -0.05 * i, 0.25 * i) for i in range(n)]
    tubo(bm, pts, [0.24 * (1 - i / (n - 1)) ** 0.8 + 0.01 for i in range(n)], lados=6, achatar=0.25)


@peca("prisma_do_silencio", "octaedro")
def _(bm, rng):
    vs = [(0.6, 0, 0), (-0.6, 0, 0), (0, 0.75, 0), (0, -0.75, 0), (0, 0, 0.6), (0, 0, -0.6)]
    arestas = [(0, 2), (0, 3), (0, 4), (0, 5), (1, 2), (1, 3), (1, 4), (1, 5), (2, 4), (4, 3), (3, 5), (5, 2)]
    for a, b in arestas:
        tubo(bm, [vs[a], vs[b]], 0.04, lados=5)


@peca("prisma_do_silencio", "placa_som")
def _(bm, rng):
    placa(bm, [(-0.35, -0.12), (0.35, -0.12), (0.3, 0.12), (-0.3, 0.12)], 0.04)


# ================================================================ Épicas


@peca("jardim_das_agulhas", "flor")
def _(bm, rng):
    tubo(bm, [(0, -0.9, 0), (0.12, -0.3, 0.05), (0, 0.2, 0)], [0.03, 0.025, 0.02], lados=5)
    for k in range(10):
        a = 2 * math.pi * k / 10
        d = Vector((math.cos(a), 0.55 + 0.25 * (k % 2), math.sin(a))).normalized()
        tubo(bm, [(0, 0.2, 0), tuple(Vector((0, 0.2, 0)) + d * (0.7 + 0.15 * (k % 3)))], [0.022, 0.004], lados=4)
    bolha(bm, (0, 0.2, 0), 0.08, sub=1, rng=rng)


@peca("carrossel_de_eclipses", "eclipse")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.32, sub=2, achatar=(1, 1, 0.35), rng=random.Random(4))
    anel(bm, 0.42, 0.05, n=32, achatar=0.3)


@peca("carrossel_de_eclipses", "orbita")
def _(bm, rng):
    anel(bm, 2.4, 0.018, n=60, a0=0.2, a1=2 * math.pi - 0.6, lados=4)


@peca("coracao_de_basalto", "coracao")
def _(bm, rng):
    for k in range(9):
        a, b = rng.uniform(0, 6.28), rng.uniform(-0.6, 0.6)
        bipiramide(bm, (math.cos(a) * 0.25, b * 0.45, math.sin(a) * 0.2), (rng.uniform(-1, 1), 1, rng.uniform(-1, 1)), 0.3, 0.25, 0.22, lados=5, rng=rng)


@peca("coracao_de_basalto", "veio")
def _(bm, rng):
    for k in range(4):
        a = k * 1.57 + 0.3
        tubo(bm, [(0, 0.05 * k, 0), (math.cos(a) * 0.25, 0.2 - 0.15 * k, math.sin(a) * 0.22), (math.cos(a + 0.4) * 0.42, 0.1 - 0.2 * k, math.sin(a + 0.4) * 0.32)], [0.04, 0.03, 0.012], lados=4)


@peca("coracao_de_basalto", "pedra")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0.3, 1, 0.2), 0.2, 0.18, 0.16, lados=5, rng=rng)


@peca("plumas_de_mercurio", "asa")
def _(bm, rng):
    for k in range(9):
        comp = 0.9 + 1.3 * math.sin(math.pi * (k + 1) / 10)
        a = -10 + k * 11
        m = rot(0, 0, -a) @ Matrix.Translation(Vector((0.1 * k, 0.05 * k, 0.03 * (k % 2))))
        pts = [(0, 0, 0), (0.08, comp * 0.45, 0.04), (0, comp, 0)]
        tubo(bm, [tuple(m @ Vector(q)) for q in pts], [0.09, 0.07, 0.006], lados=6, achatar=0.35)


@peca("valsa_do_abismo", "fita")
def _(bm, rng):
    n = 34
    pts = [(math.cos(t * 2.4) * (1.9 + 0.3 * math.sin(t * 5)), -1.8 + 3.8 * t, math.sin(t * 2.4) * 1.8) for t in [i / (n - 1) for i in range(n)]]
    tubo(bm, pts, [0.05 + 0.22 * math.sin(math.pi * i / (n - 1)) for i in range(n)], lados=6, achatar=0.15)


@peca("navio_de_papel_fantasma", "barco")
def _(bm, rng):
    placa(bm, [(-0.6, 0.0), (0.6, 0.0), (0.35, -0.25), (-0.35, -0.25)], 0.3, rot(0, 90, 0))
    placa(bm, [(0, 0.05), (0.42, 0.05), (0, 0.75)], 0.015, Matrix.Translation(Vector((0, 0, -0.05))) @ rot(0, 90, 0))
    placa(bm, [(0, 0.05), (-0.3, 0.05), (0, 0.55)], 0.015, Matrix.Translation(Vector((0, 0, 0.1))) @ rot(0, 90, 0))


@peca("navio_de_papel_fantasma", "onda")
def _(bm, rng):
    n = 20
    tubo(bm, [(-1.0 + 2.0 * i / (n - 1), 0.08 * math.sin(i * 1.2), 0) for i in range(n)], 0.06, lados=5, achatar=0.4)


@peca("duas_luas_partidas", "lua")
def _(bm, rng):
    n = 26
    pts, raios = [], []
    for i in range(n):
        t = i / (n - 1)
        a = math.pi * (0.15 + 1.2 * t)
        pts.append((math.cos(a) * 1.3, math.sin(a) * 1.3, 0))
        raios.append(0.03 + 0.32 * math.sin(math.pi * t) ** 0.7)
    tubo(bm, pts, raios, lados=8, achatar=0.5)
    bipiramide(bm, (math.cos(math.pi * 0.85) * 1.6, math.sin(math.pi * 0.85) * 1.6, 0), (1, 0.2, 0), 0.2, 0.12, 0.12, lados=4, rng=rng)


@peca("correntes_do_vazio", "corrente")
def _(bm, rng):
    for k in range(9):
        y = -0.35 * k
        r = rot(0, 90 * (k % 2), 0)
        pts = [tuple(r @ Vector((math.cos(a) * 0.14, y + math.sin(a) * 0.2, 0))) for a in [2 * math.pi * i / 12 for i in range(13)]]
        tubo(bm, pts, 0.035, lados=5, fechar=False)


@peca("correntes_do_vazio", "nucleo")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.4, sub=2, rng=rng)


@peca("catedral_de_sal", "arco")
def _(bm, rng):
    n = 18
    pts = [(math.cos(math.pi * i / (n - 1)) * 0.9, -1.4 + 2.6 * math.sin(math.pi * i / (n - 1)) ** 0.6, 0) for i in range(n)]
    tubo(bm, pts, 0.08, lados=6)
    bipiramide(bm, (0, 1.3, 0), (0, 1, 0), 0.6, 0.1, 0.1, lados=4, rng=rng)
    for k in range(4):
        x = -0.9 + 0.6 * k
        bipiramide(bm, (x, -0.2 + 0.4 * math.sin(k), 0.05), (0.2, 1, 0.2), 0.25, 0.08, 0.06, lados=5, rng=rng)


@peca("circulo_dos_predadores", "pegada")
def _(bm, rng):
    for k in range(4):
        x = -0.36 + 0.24 * k
        placa(bm, [(-0.06, 0), (0.06, 0), (0.0, 0.5 + 0.15 * (k in (1, 2)))], 0.05, Matrix.Translation(Vector((x, 0.1 + 0.15 * (k in (1, 2)), 0))) @ rot(0, 0, (k - 1.5) * -10))
    placa(bm, [(math.cos(a) * 0.32, math.sin(a) * 0.24 - 0.25) for a in [2 * math.pi * i / 10 for i in range(10)]], 0.05)


@peca("circulo_dos_predadores", "arranhao")
def _(bm, rng):
    for k in range(3):
        tubo(bm, [(-0.25 + 0.25 * k, 0.9, 0), (-0.2 + 0.25 * k, 0, 0.05), (-0.3 + 0.25 * k, -0.9, 0)], [0.008, 0.05, 0.008], lados=4, achatar=0.3)


@peca("jardim_invertido", "flor_pendente")
def _(bm, rng):
    tubo(bm, [(0, 0.6, 0), (0.1, 0.1, 0.05), (0, -0.5, 0)], [0.025, 0.02, 0.015], lados=5)
    for k in range(6):
        a = k * 60
        placa(bm, [(0, 0), (0.12, -0.2), (0, -0.45), (-0.12, -0.2)], 0.025, Matrix.Translation(Vector((0, -0.5, 0))) @ rot(0, a, 0) @ rot(-35, 0, 0))


@peca("jardim_invertido", "raiz_teto")
def _(bm, rng):
    for k in range(5):
        a = k * 1.25
        tubo(bm, [(0, 0, 0), (math.cos(a) * 0.6, -0.15, math.sin(a) * 0.6), (math.cos(a + 0.3) * 1.1, -0.5, math.sin(a + 0.3) * 1.1)], [0.08, 0.05, 0.01], lados=5)


@peca("guardiao_da_ampulheta", "ampulheta")
def _(bm, rng):
    n = 15
    perfil = [0.55 * (abs(math.cos(math.pi * i / (n - 1))) ** 1.2) + 0.05 for i in range(n)]
    tubo(bm, [(0, 1.2 - 2.4 * i / (n - 1), 0) for i in range(n)], perfil, lados=10, fechar=False)
    for y in (1.25, -1.25):
        anel(bm, 0.65, 0.07, n=24, y=y)
    for k in range(3):
        a = k * 2.09
        tubo(bm, [(math.cos(a) * 0.65, -1.25, math.sin(a) * 0.65), (math.cos(a) * 0.65, 1.25, math.sin(a) * 0.65)], 0.035, lados=5)


@peca("guardiao_da_ampulheta", "areia")
def _(bm, rng):
    tubo(bm, [(0, 0.9, 0), (0, -0.9, 0)], 0.035, lados=5)
    bolha(bm, (0, -0.85, 0), 0.32, sub=1, achatar=(1, 0.4, 1), rng=rng)


@peca("mare_de_vidro_negro", "onda")
def _(bm, rng):
    n = 16
    for camada in range(2):
        pts = [(-1.2 + 2.4 * i / (n - 1), 0.9 * math.sin(math.pi * i / (n - 1)) + 0.25 * math.sin(i * 1.7) * camada, 0.15 * camada) for i in range(n)]
        tubo(bm, pts, [0.06 + 0.28 * math.sin(math.pi * i / (n - 1)) for i in range(n)], lados=5, achatar=0.25)
    for k in range(5):
        x = -0.8 + 0.4 * k
        bipiramide(bm, (x, 0.95 * math.sin(math.pi * (x + 1.2) / 2.4) + 0.25, 0), (0.3, 1, 0), 0.3, 0.05, 0.08, lados=3, rng=rng)


@peca("sussurro_das_mascaras", "mascara")
def _(bm, rng):
    contorno = [(math.cos(a) * 0.42, math.sin(a) * 0.55 * (1 if math.sin(a) > 0 else 1.1)) for a in [2 * math.pi * i / 18 for i in range(18)]]
    placa(bm, contorno, 0.1)
    for s in (-1, 1):
        placa(bm, [(-0.1, -0.03), (0.1, -0.03), (0.06, 0.05), (-0.06, 0.05)], 0.04, Matrix.Translation(Vector((s * 0.17, 0.12, 0.06))) @ rot(0, 0, s * 12))
    placa(bm, [(-0.12, 0), (0.12, 0), (0, -0.06)], 0.04, Matrix.Translation(Vector((0, -0.25, 0.06))))
    tubo(bm, [(0.4, 0.2, -0.05), (0.75, 0.0, -0.1), (0.9, -0.5, 0.0), (1.1, -0.9, -0.1)], 0.04, lados=4, achatar=0.25)


# ================================================================ Lendárias


@peca("arquiduque_de_cinzas", "capa")
def _(bm, rng):
    for fila in range(5):
        for k in range(7 - fila):
            x = (k - (6 - fila) / 2) * 0.32
            y = 0.9 - fila * 0.45
            m = Matrix.Translation(Vector((x, y, 0.05 * abs(x) ** 2 + 0.03 * fila))) @ rot(0, 0, rng.uniform(-12, 12) + x * 15)
            placa(bm, [(-0.15, 0.1), (0.15, 0.1), (0.05, -0.55), (0, -0.7), (-0.05, -0.55)], 0.04, m)


@peca("arquiduque_de_cinzas", "broche")
def _(bm, rng):
    bipiramide(bm, (0, 0, 0), (0, 0, 1), 0.12, 0.05, 0.22, lados=6, rng=rng)
    anel(bm, 0.24, 0.03, n=18, achatar=1.0)


@peca("aurora_do_mar_profundo", "umbrela")
def _(bm, rng):
    t = bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=8, radius=1.0)
    for v in t["verts"]:
        x, y, z = v.co.x, v.co.y, v.co.z
        if z < 0:
            z *= 0.15
        onda = 1 + 0.06 * math.sin(math.atan2(y, x) * 8)
        v.co = V(x * 1.4 * onda, z * 0.9, y * 1.4 * onda)


@peca("aurora_do_mar_profundo", "tentaculo")
def _(bm, rng):
    n = 14
    tubo(bm, [(0.12 * math.sin(i * 0.7), -2.6 * i / (n - 1), 0.1 * math.cos(i * 0.5)) for i in range(n)], [0.07 * (1 - i / (n - 1)) + 0.008 for i in range(n)], lados=5)


@peca("imperatriz_de_porcelana", "leque")
def _(bm, rng):
    for k in range(11):
        a = -75 + k * 15
        placa(bm, [(-0.04, 0), (0.04, 0), (0.17, 1.6), (0, 1.75), (-0.17, 1.6)], 0.035, rot(0, 0, a) @ rot(5 * (k % 2), 0, 0))
    anel(bm, 1.5, 0.03, n=30, a0=math.radians(15), a1=math.radians(165))


@peca("trono_de_raios", "relampago")
def _(bm, rng):
    pts = [(0, 1.6), (0.25, 0.6), (0.08, 0.55), (0.32, -0.5), (0.12, -0.52), (0.28, -1.6), (-0.2, -0.3), (-0.02, -0.28), (-0.22, 0.65), (-0.05, 0.68)]
    placa(bm, pts, 0.1)


@peca("trono_de_raios", "aro")
def _(bm, rng):
    anel(bm, 1.3, 0.07, n=36, a0=0.4, a1=2 * math.pi - 1.0, lados=6)
    for k in range(5):
        a = 0.6 + k * 1.0
        caixa(bm, (math.cos(a) * 1.3, 0, math.sin(a) * 1.3), (0.12, 0.2, 0.12), rot(0, -math.degrees(a), 0))


@peca("relicario_do_inverno", "altar")
def _(bm, rng):
    caixa(bm, (0, -0.4, 0), (0.7, 0.12, 0.45))
    for s in (-1, 1):
        prisma_ponta(bm, (s * 0.3, 0.05, 0), (0, 1, 0), 0.7, 0.07, 0.15, rng=rng)
    tubo(bm, arco_pts(0.32, 0, math.pi, 14, y=0) and [(math.cos(math.pi * i / 13) * 0.32, 0.45 + math.sin(math.pi * i / 13) * 0.4, 0) for i in range(14)], 0.05, lados=5)
    bipiramide(bm, (0, 0.95, 0), (0, 1, 0), 0.35, 0.05, 0.08, lados=6, rng=rng)


@peca("relicario_do_inverno", "sino_gelo")
def _(bm, rng):
    tubo(bm, [(0, 0.3, 0), (0, 0.2, 0), (0, 0.0, 0), (0, -0.2, 0)], [0.02, 0.1, 0.14, 0.2], lados=8, fechar=False)


@peca("atlas_fragmentado", "ilha")
def _(bm, rng):
    contorno = [(math.cos(a) * (0.6 + 0.2 * math.sin(a * 3 + 1)), math.sin(a) * (0.45 + 0.15 * math.cos(a * 2))) for a in [2 * math.pi * i / 14 for i in range(14)]]
    placa(bm, contorno, 0.18, rot(90, 0, 0))
    for k in range(3):
        bipiramide(bm, (rng.uniform(-0.3, 0.3), 0.18, rng.uniform(-0.2, 0.2)), (0, 1, 0), rng.uniform(0.2, 0.4), 0.02, 0.1, lados=4, rng=rng)
    tubo(bm, [(-0.5, 0.1, 0.0), (-0.1, 0.1, 0.1), (0.3, 0.1, -0.05)], 0.035, lados=4, achatar=0.3)
    bipiramide(bm, (0, -0.15, 0), (0, -1, 0), 0.4, 0.05, 0.35, lados=6, rng=rng)


@peca("serpente_de_cristal", "corpo")
def _(bm, rng):
    n = 22
    for i in range(n):
        t = i / (n - 1)
        x = -3.0 + 6.0 * t
        p = (x, 0.9 * math.sin(t * math.pi * 2), 0.6 * math.cos(t * math.pi * 2))
        r = 0.32 * math.sin(math.pi * min(1, t * 1.15)) ** 0.5 + 0.06
        bipiramide(bm, p, (1, 0.2, 0), r * 0.9, r * 0.9, r, lados=5, rng=rng)
    bipiramide(bm, (-3.3, 0.0, 0.6), (-1, 0, 0), 0.6, 0.2, 0.35, lados=5, rng=rng)


@peca("serpente_de_cristal", "olho")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.12, sub=1, rng=rng)


@peca("horizonte_rasgado", "fenda")
def _(bm, rng):
    placa(bm, [(-0.9, -1.3), (-0.4, -1.4), (0.5, -1.25), (0.95, -0.6), (0.8, 0.4), (1.0, 1.2), (0.2, 1.4), (-0.6, 1.3), (-0.95, 0.5), (-0.8, -0.5)], 0.05)


@peca("horizonte_rasgado", "borda")
def _(bm, rng):
    for (a, b) in (((-0.9, -1.3), (-0.95, 0.5)), ((-0.6, 1.3), (1.0, 1.2)), ((0.95, -0.6), (0.8, 0.4)), ((-0.4, -1.4), (0.5, -1.25))):
        m = [(a[0] + (b[0] - a[0]) * t + rng.uniform(-0.08, 0.08), a[1] + (b[1] - a[1]) * t, 0.04) for t in (0, 0.33, 0.66, 1)]
        tubo(bm, m, [0.02, 0.06, 0.06, 0.02], lados=5)


@peca("arauto_dos_mil_sinos", "halo")
def _(bm, rng):
    anel(bm, 1.1, 0.06, n=40, lados=6)
    for k in range(10):
        a = 2 * math.pi * k / 10
        x, z = math.cos(a) * 1.1, math.sin(a) * 1.1
        comp = 0.25 + 0.2 * (k % 3)
        tubo(bm, [(x, 0, z), (x, -comp, z)], 0.01, lados=4)
        tubo(bm, [(x, -comp, z), (x, -comp - 0.1, z), (x, -comp - 0.25, z)], [0.04, 0.09, 0.13], lados=7, fechar=False)


@peca("orquestra_das_estrelas", "harpa")
def _(bm, rng):
    tubo(bm, [(-0.9, -1.0, 0), (-1.0, 0.2, 0), (-0.4, 1.2, 0), (0.6, 1.3, 0), (1.0, 0.6, 0)], 0.06, lados=6)
    for k in range(8):
        x = -0.85 + 0.24 * k
        topo = 1.2 - 0.12 * max(0, k - 4) ** 1.3
        tubo(bm, [(x, -0.9 + 0.15 * k, 0), (x, topo, 0)], 0.012, lados=4)
        placa(bm, estrela(4, 0.09, 0.03), 0.02, Matrix.Translation(Vector((x, -0.9 + 0.15 * k + 0.5 * (topo + 0.9 - 0.15 * k), 0.03))))


@peca("orquestra_das_estrelas", "nota")
def _(bm, rng):
    placa(bm, estrela(5, 0.2, 0.08), 0.06)


@peca("majestade_de_cobre", "leao")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.5, sub=2, achatar=(0.9, 1.0, 0.8), rng=rng)
    caixa(bm, (0, -0.25, -0.4), (0.4, 0.3, 0.35))
    for s in (-1, 1):
        bipiramide(bm, (s * 0.2, 0.15, -0.42), (0, 0, -1), 0.03, 0.03, 0.07, lados=4, rng=rng)
        bipiramide(bm, (s * 0.35, 0.5, -0.05), (s * 0.3, 1, 0), 0.2, 0.05, 0.1, lados=4, rng=rng)
    for k in range(16):  # crina de lâminas
        a = 2 * math.pi * k / 16
        placa(bm, [(-0.07, 0), (0.07, 0), (0, 0.55 + 0.15 * (k % 2))], 0.04, Matrix.Translation(Vector((0, 0, 0.15))) @ rot(0, 0, math.degrees(a)) @ Matrix.Translation(Vector((0, 0.5, 0))))


@peca("majestade_de_cobre", "relogio")
def _(bm, rng):
    anel(bm, 0.32, 0.04, n=24, achatar=1.0)
    placa(bm, [(-0.02, 0), (0.02, 0), (0, 0.25)], 0.02, rot(90, 0, 0) and rot(0, 0, -30))
    placa(bm, [(-0.02, 0), (0.02, 0), (0, 0.18)], 0.02, rot(0, 0, 80))


# Peças reaproveitadas entre auras (cada .rbxm leva sua própria cópia do template)
for _destino, _origem in (
    (("imperatriz_de_porcelana", "caco"), ("fenda_de_porcelana", "caco")),
    (("relicario_do_inverno", "prisma"), ("gelo_de_neon", "prisma")),
    (("arauto_dos_mil_sinos", "onda"), ("sinos_do_crepusculo", "onda")),
    (("arauto_dos_mil_sinos", "sino"), ("sinos_do_crepusculo", "sino")),
):
    PECAS[_destino] = PECAS[_origem]


# ================================================================ Míticas


@peca("devorador_de_alvoradas", "sol_negro")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.9, sub=3, achatar=(1, 1, 0.5), rng=random.Random(5))


@peca("devorador_de_alvoradas", "mandibula")
def _(bm, rng):
    n = 18
    tubo(bm, [(math.cos(a) * 1.25, math.sin(a) * 1.25, 0) for a in [math.pi * (0.1 + 0.8 * i / (n - 1)) for i in range(n)]], 0.16, lados=6, achatar=0.6)
    for k in range(9):
        a = math.pi * (0.15 + 0.7 * k / 8)
        bipiramide(bm, (math.cos(a) * 1.1, math.sin(a) * 1.1, 0), (-math.cos(a), -math.sin(a), 0), 0.35 + 0.1 * (k % 2), 0.05, 0.08, lados=4, rng=rng)


@peca("devorador_de_alvoradas", "anel_brasas")
def _(bm, rng):
    for k in range(14):
        a = 2 * math.pi * k / 14
        bipiramide(bm, (math.cos(a) * 1.6, math.sin(a) * 1.6, 0), (math.cos(a), math.sin(a), 0), 0.15, 0.1, 0.09, lados=4, rng=rng)


@peca("coroa_do_fim", "ponta")
def _(bm, rng):
    placa(bm, [(-0.3, -0.6), (0.3, -0.6), (0.18, 0.4), (0.04, 1.4), (-0.06, 0.5), (-0.2, 0.35)], 0.12)
    for k in range(3):
        bipiramide(bm, (0.15 * (k - 1), -0.2 + 0.4 * k, 0.1), (0.3 * (k - 1), 1, 0.6), 0.35, 0.03, 0.05, lados=4, rng=rng)


@peca("oceano_sem_fundo", "janela")
def _(bm, rng):
    caixa(bm, (0, 0, 0), (1.6, 3.2, 0.08))


@peca("oceano_sem_fundo", "moldura")
def _(bm, rng):
    pts = [(-0.85, -1.65, 0.06), (-0.9, 0.2, 0.06), (-0.8, 1.68, 0.06), (0.85, 1.65, 0.06), (0.9, -0.3, 0.06), (0.82, -1.66, 0.06), (-0.85, -1.65, 0.06)]
    tubo(bm, pts, 0.07, lados=5, fechar=False)


@peca("oceano_sem_fundo", "peixe")
def _(bm, rng):
    tubo(bm, [(-0.3, 0, 0), (0, 0.03, 0), (0.25, 0, 0)], [0.03, 0.09, 0.02], lados=6, achatar=0.5)
    placa(bm, [(0.22, 0), (0.42, 0.12), (0.4, -0.12)], 0.02)


@peca("fio_das_parcas", "tear")
def _(bm, rng):
    vs = [(-1.4, -0.8, 0), (1.4, -0.8, 0), (0, 1.5, 0)]
    for a, b in ((0, 1), (1, 2), (2, 0)):
        tubo(bm, [vs[a], vs[b]], 0.07, lados=6)
    for k in range(7):
        t = (k + 1) / 8
        x0, y0 = -1.4 + 1.4 * t, -0.8 + 2.3 * t
        tubo(bm, [(x0, y0, 0.02), (1.4 - 1.4 * t + 0.0, -0.8 + 2.3 * t * (1 - t) * 1.2, 0.02)], 0.012, lados=4)


@peca("fio_das_parcas", "fio")
def _(bm, rng):
    n = 20
    tubo(bm, [(0.25 * math.sin(i * 0.9), -1.8 + 3.6 * i / (n - 1), 0.2 * math.cos(i * 0.6)) for i in range(n)], 0.025, lados=4)


@peca("labirinto_vivo", "cubo")
def _(bm, rng):
    for x in (-0.6, 0.6):
        for y in (-0.6, 0.6):
            tubo(bm, [(x, y, -0.6), (x, y, 0.6)], 0.05, lados=4)
            tubo(bm, [(x, -0.6, y), (x, 0.6, y)], 0.05, lados=4)
            tubo(bm, [(-0.6, x, y), (0.6, x, y)], 0.05, lados=4)


@peca("labirinto_vivo", "escada")
def _(bm, rng):
    for k in range(7):
        caixa(bm, (0.0, 0.18 * k, 0.24 * k), (0.6, 0.08, 0.26))
    tubo(bm, [(0.32, 0.1, 0), (0.32, 1.2, 1.5)], 0.03, lados=4)


@peca("labirinto_vivo", "arco_pedra")
def _(bm, rng):
    for k in range(9):
        a = math.pi * k / 8
        caixa(bm, (math.cos(a) * 0.8, math.sin(a) * 0.8, 0), (0.28, 0.2, 0.25), rot(0, 0, math.degrees(a)))
    for s in (-1, 1):
        caixa(bm, (s * 0.8, -0.6, 0), (0.25, 1.1, 0.25))


@peca("eclipse_de_mil_olhos", "olho_grande")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.75, sub=2, achatar=(1, 0.6, 0.35), rng=random.Random(8))
    bolha(bm, (0, 0, 0.22), 0.28, sub=2, achatar=(1, 1, 0.4), rng=random.Random(9))


@peca("eclipse_de_mil_olhos", "olho")
def _(bm, rng):
    bolha(bm, (0, 0, 0), 0.25, sub=2, achatar=(1, 0.55, 0.4), rng=rng)
    bolha(bm, (0, 0, 0.08), 0.1, sub=1, rng=rng)


@peca("eclipse_de_mil_olhos", "anel_eclipse")
def _(bm, rng):
    n = 40
    tubo(bm, [(math.cos(a) * 1.7 * (1 + 0.12 * math.sin(3 * a)), math.sin(a) * 1.5, 0) for a in [2 * math.pi * i / (n - 1) for i in range(n)]], 0.08, lados=6, fechar=False)


# ================================================================ Divinas


@peca("alvorecer_dos_titas", "mao")
def _(bm, rng):
    caixa(bm, (0, 0, 0), (1.0, 1.1, 0.35))
    for k, (x, comp) in enumerate(((-0.36, 1.0), (-0.12, 1.2), (0.12, 1.15), (0.36, 0.95))):
        pts = [(x, 0.55 + comp * t, -0.25 * t * t) for t in (0, 0.33, 0.66, 1.0)]
        tubo(bm, pts, [0.12, 0.11, 0.1, 0.07], lados=8)
    tubo(bm, [(0.5, 0.0, 0), (0.8, 0.4, -0.15), (0.95, 0.75, -0.3)], [0.13, 0.11, 0.08], lados=8)
    tubo(bm, [(-0.45, -0.55, 0), (0.45, -0.55, 0)], 0.2, lados=8)


@peca("alvorecer_dos_titas", "halo_solar")
def _(bm, rng):
    for a0 in (0.1, 1.7, 3.3, 4.9):
        anel(bm, 1.5, 0.08, n=14, a0=a0, a1=a0 + 1.25, lados=6)
    for k in range(16):
        a = 2 * math.pi * k / 16
        bipiramide(bm, (math.cos(a) * 1.85, math.sin(a) * 1.85, 0), (math.cos(a), math.sin(a), 0), 0.35 + 0.2 * (k % 2), 0.05, 0.07, lados=4, rng=rng)


@peca("divindade_do_prisma", "catedral")
def _(bm, rng):
    for k in range(7):
        x = (k - 3) * 0.42
        alto = 2.4 - 0.45 * abs(k - 3)
        prisma_ponta(bm, (x, alto / 2 - 0.6, 0.1 * abs(k - 3)), (0, 1, 0), alto, 0.14 + 0.03 * (3 - abs(k - 3)), 0.5, rng=rng)


@peca("divindade_do_prisma", "nucleo")
def _(bm, rng):
    prisma_ponta(bm, (0, 0, 0), (0, 1, 0), 0.5, 0.45, 0.3, lados=6, rng=random.Random(2))


@peca("divindade_do_prisma", "petala_luz")
def _(bm, rng):
    placa(bm, [(0, 0), (0.45, 0.9), (0.2, 2.2), (0, 2.6), (-0.2, 2.2), (-0.45, 0.9)], 0.05)


@peca("ultimo_jardim", "arvore")
def _(bm, rng):
    tubo(bm, [(0, -1.4, 0), (0.1, -0.4, 0.05), (-0.05, 0.6, 0), (0, 1.2, 0)], [0.28, 0.22, 0.16, 0.1], lados=9)
    for k in range(7):
        a = k * 51 + 20
        m = rot(0, a, 0)
        h = 0.2 + 0.18 * k
        p1 = tuple(m @ Vector((0.7, h + 0.5, 0)))
        p2 = tuple(m @ Vector((1.3, h + 0.9, 0.2)))
        tubo(bm, [(0, h, 0), p1, p2], [0.09, 0.05, 0.015], lados=6)
    for k in range(4):
        a = k * 1.57 + 0.4
        tubo(bm, [(0, -1.3, 0), (math.cos(a) * 0.7, -1.55, math.sin(a) * 0.7), (math.cos(a + 0.4) * 1.3, -1.75, math.sin(a + 0.4) * 1.3)], [0.14, 0.08, 0.02], lados=6)


@peca("ultimo_jardim", "flor_galaxia")
def _(bm, rng):
    for k in range(7):
        a = 360 * k / 7
        placa(bm, [(0, 0), (0.14, 0.18), (0.0, 0.45), (-0.14, 0.18)], 0.03, rot(0, 0, a) @ rot(15, 0, 0))
    bolha(bm, (0, 0, 0.05), 0.1, sub=1, rng=rng)

# ---------------------------------------------------------------- comportamento (vai para o Luau)
# modo: "ancora" (pos local), "orbita" (rx, rz, altura, ang, vel), "pendulo" (arco atrás: centro, abertura)
# rot = graus (X, Y, Z); giro = graus/s; osc = {eixo, amplitude graus, freq}; correr = pos local correndo;
# abrir = deslocamento no pico/manifestação; abrirGiro = graus no pico; apontar = pontas para o movimento.

AURAS = {
    "centelha_do_nexo": {
        "cores": ("FFE6A0", "8F71FF"),
        "pecas": [
            dict(template="nucleo", modo="ancora", pos=(0, 3.1, 0.25), giro=(0, 45, 0), bob=0.15, cor=0, material="Neon", rigidez=40, atraso=0.5, pulso=0.06),
            dict(template="halo", modo="ancora", pos=(0, -0.45, 0), rot=(6, 0, -4), giro=(0, 14, 0), cor=1, material="Neon", rigidez=60, atraso=0.4, transp=0.15),
            dict(template="lasca", modo="orbita", rx=2.1, rz=1.9, altura=0.9, ang=0.4, vel=0.9, inclinacao=0.25, cor=0, material="Neon", rigidez=36, atraso=0.7, correr=(0, 0.9, 2.0)),
            dict(template="lasca", modo="orbita", rx=2.4, rz=2.1, altura=-0.1, ang=2.5, vel=-0.6, inclinacao=0.3, cor=0, material="Neon", rigidez=30, atraso=0.8, correr=(0.55, 0.55, 2.8), escala=0.85),
            dict(template="lasca", modo="orbita", rx=1.8, rz=1.7, altura=1.7, ang=4.4, vel=1.3, inclinacao=0.2, cor=0, material="Neon", rigidez=44, atraso=0.6, correr=(-0.55, 0.55, 2.8), escala=0.75, detalhe=True),
        ],
        "especial": dict(template="lasca", n=6, origem=(0, 3.1, 0.25), raio=1.6, escala=0.6, cor=0, material="Neon"),
    },
    "gelo_de_neon": {
        "cores": ("77F7FF", "1758D9"),
        "pecas": [
            dict(template="lasca_alta", modo="ancora", pos=(0, 2.4, 1.0), rot=(-14, 0, 4), cor=0, material="Glass", transp=0.15, rigidez=34, atraso=0.6, osc=(2, 3, 0.35)),
            dict(template="prisma", modo="ancora", pos=(-2.0, 1.0, 0.2), rot=(0, 0, 22), cor=0, material="Glass", transp=0.1, rigidez=40, atraso=0.55, apontar=True, osc=(0, 4, 0.5), bob=0.12),
            dict(template="prisma", modo="ancora", pos=(2.0, 0.85, 0.25), rot=(0, 30, -20), cor=0, material="Glass", transp=0.1, rigidez=42, atraso=0.55, apontar=True, osc=(0, 4, 0.45), bob=0.12),
            dict(template="prisma", modo="ancora", pos=(-1.7, -0.7, 0.5), rot=(0, 60, 30), cor=1, material="Neon", rigidez=36, atraso=0.65, apontar=True, osc=(2, 5, 0.55), bob=0.1, escala=0.8, detalhe=True),
            dict(template="prisma", modo="ancora", pos=(1.75, -0.6, 0.45), rot=(0, -40, -28), cor=1, material="Neon", rigidez=38, atraso=0.65, apontar=True, osc=(2, 5, 0.6), bob=0.1, escala=0.8, detalhe=True),
        ],
        "especial": dict(template="estrela", n=1, origem=(0, 0.9, 1.3), raio=0, escala=2.2, cor=0, material="Neon", girar=180),
    },
    "prisma_partilhado": {
        "cores": ("C4B6FF", "FBE09A"),
        "pecas": [
            dict(template="cunha", modo="orbita", rx=2.4, rz=2.2, altura=0.2 + 0.45 * (k % 2) + 0.15 * k, ang=k * math.pi / 3, vel=0.5, inclinacao=0.35 * (1 if k % 2 else -1), cor=k % 2, material="Glass", transp=0.2, rigidez=40, atraso=0.6, correr=(math.cos(k * math.pi / 3) * 0.9, 0.7 + math.sin(k * math.pi / 3) * 0.9, 1.6), detalhe=k >= 5)
            for k in range(6)
        ],
        "especial": dict(template="raio", n=6, origem=(0, 0.6, -0.3), raio=0.2, escala=1.0, cor=1, material="Neon", arco_iris=True),
    },
    "arquivista_espectral": {
        "cores": ("A1F4E7", "6359B1"),
        "pecas": [
            dict(template="pergaminho", modo="ancora", pos=(-1.9, 1.1, 0.7), rot=(0, 35, 8), cor=0, material="Neon", transp=0.25, rigidez=30, atraso=0.7, osc=(0, 6, 0.3), bob=0.18, correr=(-1.3, 1.3, 1.5), correrRot=(0, 70, 25)),
            dict(template="pergaminho", modo="ancora", pos=(1.9, 0.9, 0.7), rot=(0, -35, -8), cor=0, material="Neon", transp=0.25, rigidez=32, atraso=0.7, osc=(0, 6, 0.35), bob=0.18, correr=(1.3, 1.3, 1.5), correrRot=(0, -70, -25)),
            dict(template="pergaminho", modo="ancora", pos=(0, 2.6, 1.3), rot=(-20, 0, 0), cor=1, material="Neon", transp=0.2, rigidez=26, atraso=0.8, osc=(0, 4, 0.25), bob=0.12, escala=1.15, detalhe=True),
            dict(template="mao", modo="ancora", pos=(-1.5, 0.1, -0.5), rot=(-30, 20, 10), cor=0, material="ForceField", rigidez=24, atraso=0.8, osc=(0, 12, 0.6), bob=0.15),
            dict(template="mao", modo="ancora", pos=(1.5, 0.3, -0.4), rot=(-30, -20, -10), cor=0, material="ForceField", rigidez=24, atraso=0.8, osc=(0, 12, 0.55), bob=0.15, espelhar=True),
        ],
        "especial": dict(template="pagina", n=10, origem=(0, 1.2, 1.2), raio=2.6, escala=1.0, cor=0, material="Neon", arco=True),
    },
    "coracao_de_fenix": {
        "cores": ("FFD46A", "E74747"),
        "pecas": [
            dict(template="costelas", modo="ancora", pos=(0, 0.6, 1.0), rot=(0, 180, 0), cor=0, material="Neon", rigidez=60, atraso=0.35, pulso=0.03),
            dict(template="nucleo", modo="ancora", pos=(0, 0.75, 0.9), cor=1, material="Neon", rigidez=60, atraso=0.35, pulso=0.15, giro=(0, 30, 0)),
            dict(template="asa_esq", modo="ancora", pos=(-0.5, 1.1, 1.1), rot=(10, 30, 0), cor=1, material="Neon", rigidez=40, atraso=0.5, osc=(2, 9, 0.45), correrRot=(10, 75, 25), abrirGiro=(0, -40, -35)),
            dict(template="asa_dir", modo="ancora", pos=(0.5, 1.1, 1.1), rot=(10, -30, 0), cor=1, material="Neon", rigidez=40, atraso=0.5, osc=(2, -9, 0.45), correrRot=(10, -75, -25), abrirGiro=(0, 40, 35)),
        ],
        "especial": dict(template="nucleo", n=8, origem=(0, 0.75, 0.9), raio=2.2, escala=0.45, cor=0, material="Neon"),
    },
    "leviata_astral": {
        "cores": ("7CB4F4", "A274E7"),
        "pecas": [
            dict(template="baleia", modo="pendulo", raio=4.2, altura=3.0, abertura=1.15, vel=0.28, cor=1, material="ForceField", rigidez=10, atraso=2.0, escala=1.0, abrir=(0, 3.0, -2.0)),
            dict(template="estrela", modo="orbita", rx=2.0, rz=1.8, altura=2.2, ang=0.0, vel=0.7, inclinacao=0.4, cor=0, material="Neon", rigidez=40, atraso=0.6, giro=(0, 0, 90), detalhe=True),
            dict(template="estrela", modo="orbita", rx=2.6, rz=2.3, altura=0.4, ang=3.0, vel=-0.5, inclinacao=0.3, cor=0, material="Neon", rigidez=40, atraso=0.6, giro=(0, 0, -70), escala=0.7, detalhe=True),
        ],
        "especial": dict(template="estrela", n=8, origem=(0, 3.5, 0.5), raio=2.5, escala=0.8, cor=0, material="Neon"),
    },
    "soberania_do_vazio": {
        "cores": ("F4F3FF", "160B26"),
        "pecas": [
            dict(template="coroa", modo="ancora", pos=(0, 3.0, 0), rot=(4, 0, 0), giro=(0, 12, 0), cor=0, material="Neon", rigidez=50, atraso=0.4, bob=0.08, abrirEscala=0.6),
            dict(template="estrela_vazio", modo="ancora", pos=(0, 1.2, 1.8), giro=(0, 0, 8), cor=1, material="SmoothPlastic", rigidez=30, atraso=0.6, abrirEscala=0.5),
            dict(template="estrela_borda", modo="ancora", pos=(0, 1.2, 1.76), giro=(0, 0, 8), cor=0, material="Neon", rigidez=30, atraso=0.6, abrirEscala=0.5, detalhe=True),
        ]
        + [
            dict(template="monolito", modo="orbita", rx=3.1, rz=2.8, altura=0.6 + 0.5 * math.sin(k * 2.1), ang=k * math.pi / 3 + 0.3, vel=0.22, inclinacao=0.15, cor=1, material="SmoothPlastic", rigidez=34, atraso=0.7, correr=(0, 1.0, 1.5 + 0.6 * k), correrRot=(90, 0, 0), escala=0.85 + 0.1 * (k % 3), detalhe=k >= 4, abrir=(0, 0.8, 0))
            for k in range(6)
        ],
        "especial": dict(template="monolito", n=6, origem=(0, 1.0, 0), raio=6.0, escala=1.2, cor=1, material="SmoothPlastic"),
    },
}



# Comuns e Incomuns (lote de acesso)
AURAS.update({
    "musgo_luminoso": {
        "cores": ("A1F5A6", "2A805B"),
        "pecas": [
            dict(template="raiz", modo="ancora", pos=(-0.5, -2.95, 0.1), rot=(0, 160, 0), cor=1, material="SmoothPlastic", rigidez=70, atraso=0.3, correr=(-0.4, -2.95, 0.8)),
            dict(template="raiz", modo="ancora", pos=(0.5, -2.95, 0.1), rot=(0, 20, 0), cor=1, material="SmoothPlastic", rigidez=70, atraso=0.3, correr=(0.4, -2.95, 0.8), escala=0.85),
            dict(template="broto", modo="ancora", pos=(-1.0, 1.05, 0.1), rot=(0, 0, 12), cor=0, material="Neon", rigidez=50, atraso=0.4, osc=(2, 10, 0.4), pulso=0.08),
            dict(template="broto", modo="ancora", pos=(1.0, 1.05, 0.1), rot=(0, 90, -12), cor=0, material="Neon", rigidez=50, atraso=0.4, osc=(2, -10, 0.45), pulso=0.08),
            dict(template="esporo", modo="orbita", rx=1.8, rz=1.6, altura=0.4, ang=0, vel=0.5, inclinacao=0.5, cor=0, material="Neon", rigidez=30, atraso=0.7, giro=(0, 0, 60), detalhe=True),
        ],
        "especial": dict(template="broto", n=8, origem=(0, -2.95, 0), raio=2.0, escala=1.3, cor=0, material="Neon"),
    },
    "fagulha_de_cobre": {
        "cores": ("FFB15E", "7A3F29"),
        "pecas": [
            dict(template="caco", modo="orbita", rx=1.9, rz=1.7, altura=0.8, ang=0.3, vel=0.7, inclinacao=0.3, cor=0, material="Neon", rigidez=36, atraso=0.7, giro=(70, 40, 0), correr=(0.4, 0.6, 2.2)),
            dict(template="caco", modo="orbita", rx=2.2, rz=1.9, altura=0.0, ang=2.2, vel=-0.55, inclinacao=0.2, cor=1, material="Metal", rigidez=30, atraso=0.8, giro=(-50, 60, 20), correr=(-0.4, 0.2, 2.8), escala=1.2),
            dict(template="caco", modo="orbita", rx=1.7, rz=1.5, altura=1.6, ang=4.1, vel=0.9, inclinacao=0.25, cor=0, material="Neon", rigidez=40, atraso=0.6, giro=(30, -80, 40), correr=(0, 1.0, 3.3), escala=0.8),
            dict(template="caco", modo="orbita", rx=2.4, rz=2.1, altura=-0.8, ang=5.2, vel=0.4, inclinacao=0.35, cor=1, material="Metal", rigidez=28, atraso=0.8, giro=(90, 10, 60), escala=0.9, detalhe=True),
            dict(template="filamento", modo="ancora", pos=(-1.2, 0.6, 0.6), rot=(0, 0, 30), cor=0, material="Neon", rigidez=40, atraso=0.5, osc=(2, 8, 1.3)),
            dict(template="filamento", modo="ancora", pos=(1.25, 0.2, 0.5), rot=(0, 180, -25), cor=0, material="Neon", rigidez=40, atraso=0.5, osc=(2, -8, 1.1), detalhe=True),
        ],
        "especial": dict(template="caco", n=8, origem=(0, 0.6, 0), raio=2.4, escala=0.8, cor=0, material="Neon"),
    },
    "chuvisco_de_vidro": {
        "cores": ("9BE9FF", "3970AB"),
        "pecas": [
            dict(template="gota", modo="ancora", pos=(1.6 * math.cos(a), 0.8 + 0.6 * math.sin(k * 1.7), 1.6 * math.sin(a)), rot=(0, -math.degrees(a), 0), cor=0, material="Glass", transp=0.25, rigidez=40, atraso=0.5, bob=0.45 * (1 if k % 2 else -1), correr=(0.6 * math.cos(a), 0.6 + 0.3 * k, 1.6 + 0.4 * k), correrRot=(70, 0, 0), detalhe=k >= 4)
            for k, a in enumerate([math.radians(x) for x in (20, 80, 140, 200, 300)])
        ]
        + [
            dict(template="prisma_mini", modo="orbita", rx=2.2, rz=2.0, altura=0.2, ang=1.0, vel=0.8, inclinacao=0.3, cor=1, material="Neon", rigidez=36, atraso=0.6, giro=(0, 90, 0)),
            dict(template="prisma_mini", modo="orbita", rx=1.9, rz=1.8, altura=1.4, ang=3.8, vel=-0.7, inclinacao=0.2, cor=1, material="Neon", rigidez=36, atraso=0.6, giro=(0, -90, 0), detalhe=True),
        ],
        "especial": dict(template="gota", n=10, origem=(0, 2.6, 0), raio=2.4, escala=0.7, cor=0, material="Glass"),
    },
    "borboletas_de_cinza": {
        "cores": ("D4CDD6", "6B647C"),
        "pecas": [
            dict(template="mariposa", modo="orbita", rx=1.6, rz=1.4, altura=1.3, ang=0.5, vel=0.45, inclinacao=0.35, cor=0, material="SmoothPlastic", rigidez=26, atraso=0.8, osc=(2, 35, 2.2), correr=(0.7, 1.4, 1.8)),
            dict(template="mariposa", modo="orbita", rx=1.9, rz=1.6, altura=0.6, ang=2.6, vel=-0.38, inclinacao=0.4, cor=1, material="SmoothPlastic", rigidez=22, atraso=0.9, osc=(2, 40, 2.6), correr=(-0.4, 1.0, 2.4), escala=1.2),
            dict(template="mariposa", modo="orbita", rx=1.5, rz=1.3, altura=1.9, ang=4.4, vel=0.6, inclinacao=0.3, cor=0, material="SmoothPlastic", rigidez=30, atraso=0.7, osc=(2, 30, 2.0), correr=(0.1, 1.9, 3.0), escala=0.85, detalhe=True),
        ],
        "especial": dict(template="mariposa", n=10, origem=(0, 1.2, 0), raio=2.8, escala=0.9, cor=0, material="SmoothPlastic"),
    },
    "mare_de_quartzo": {
        "cores": ("7BD8E3", "D8FFFF"),
        "pecas": [
            dict(template="fita", modo="ancora", pos=(0, 0.2, 0), giro=(0, 25, 0), cor=0, material="Glass", transp=0.2, rigidez=50, atraso=0.5, bob=0.25, correrRot=(0, 0, 0)),
            dict(template="fita", modo="ancora", pos=(0, 0.6, 0), rot=(0, 180, 0), giro=(0, 25, 0), cor=1, material="Glass", transp=0.3, rigidez=46, atraso=0.55, bob=-0.25, escala=0.85),
            dict(template="concha", modo="ancora", pos=(-1.4, 1.4, 0.6), rot=(-20, 30, 20), cor=1, material="SmoothPlastic", rigidez=40, atraso=0.5, osc=(1, 10, 0.3)),
            dict(template="concha", modo="ancora", pos=(1.5, -0.6, 0.7), rot=(-10, -40, -30), cor=1, material="SmoothPlastic", rigidez=40, atraso=0.5, osc=(1, -10, 0.35), escala=0.8, detalhe=True),
            dict(template="bolha", modo="orbita", rx=1.7, rz=1.5, altura=1.0, ang=0.0, vel=0.6, inclinacao=0.6, cor=0, material="Glass", transp=0.3, rigidez=30, atraso=0.7, detalhe=True),
        ],
        "especial": dict(template="fita", n=1, origem=(0, 0.4, 1.2), raio=0, escala=1.5, cor=1, material="Glass", girar=120),
    },
    "raiz_cintilante": {
        "cores": ("E3C66B", "58794D"),
        "pecas": [
            dict(template="cipo", modo="ancora", pos=(-0.5, 0, 0), cor=1, material="SmoothPlastic", rigidez=80, atraso=0.25, correrRot=(-25, 0, 0)),
            dict(template="cipo", modo="ancora", pos=(0.5, 0, 0), rot=(0, 140, 0), cor=1, material="SmoothPlastic", rigidez=80, atraso=0.25, correrRot=(-25, 140, 0)),
        ]
        + [
            dict(template="semente", modo="orbita", rx=1.7, rz=1.5, altura=-1.7 + 0.2 * k, ang=k * 1.57, vel=0.5, inclinacao=0.2, cor=0, material="Neon", rigidez=36, atraso=0.6, pulso=0.25, detalhe=k >= 3)
            for k in range(4)
        ],
        "especial": dict(template="arvore", n=1, origem=(0, -2.95, 1.2), raio=0, escala=1.4, cor=0, material="Neon"),
    },
    "nevoa_de_amora": {
        "cores": ("E77BA7", "582A64"),
        "pecas": [
            dict(template="massa", modo="orbita", rx=1.9, rz=1.7, altura=a, ang=b, vel=v, inclinacao=0.3, cor=c, material="ForceField", rigidez=18, atraso=1.1, pulso=0.08, escala=e, correr=(x, a * 0.5, 1.6 + 0.4 * i), detalhe=i >= 2)
            for i, (a, b, v, c, e, x) in enumerate(((0.4, 0.0, 0.3, 1, 1.0, 0.5), (1.4, 2.1, -0.25, 0, 0.85, -0.5), (-0.6, 4.2, 0.35, 1, 0.9, 0)))
        ]
        + [
            dict(template="caroco", modo="orbita", rx=1.2, rz=1.1, altura=0.6 + 0.6 * k, ang=k * 2.1, vel=0.8, inclinacao=0.3, cor=0, material="Neon", rigidez=30, atraso=0.8, pulso=0.2)
            for k in range(2)
        ],
        "especial": dict(template="massa", n=6, origem=(0, 0.8, 0.6), raio=2.0, escala=0.7, cor=0, material="ForceField"),
    },
    "vento_de_papel": {
        "cores": ("EAE5D9", "65ABBF"),
        "pecas": [
            dict(template="passaro", modo="orbita", rx=2.0, rz=1.8, altura=1.2 + 0.4 * k, ang=k * 2.1, vel=0.6 - 0.25 * k, inclinacao=0.4, cor=0, material="SmoothPlastic", rigidez=30, atraso=0.7, osc=(2, 25, 1.4 + 0.3 * k), correr=(0.6 * (k - 1), 1.6 + 0.3 * k, -1.2), detalhe=k >= 2)
            for k in range(3)
        ]
        + [
            dict(template="tira", modo="ancora", pos=(-1.4, -0.6, 0.8), rot=(0, 30, 15), cor=1, material="SmoothPlastic", rigidez=30, atraso=0.7, osc=(2, 15, 0.8)),
            dict(template="tira", modo="ancora", pos=(1.3, -0.2, 0.9), rot=(0, -30, -15), cor=0, material="SmoothPlastic", rigidez=30, atraso=0.7, osc=(2, -15, 0.7)),
        ],
        "especial": dict(template="passaro", n=1, origem=(0, 2.4, 1.0), raio=0, escala=5.0, cor=0, material="SmoothPlastic"),
    },
    "polen_lunar": {
        "cores": ("FBE9AB", "A2B2FA"),
        "pecas": [
            dict(template="coroa_estames", modo="ancora", pos=(0, 1.5, 0.15), rot=(-10, 0, 0), cor=0, material="Neon", rigidez=60, atraso=0.35, osc=(1, 6, 0.3)),
        ]
        + [
            dict(template="grao", modo="orbita", rx=1.6 + 0.2 * k, rz=1.4 + 0.2 * k, altura=0.2 + 0.4 * k, ang=k * 1.26, vel=0.4 + 0.1 * k, inclinacao=0.3, cor=k % 2, material="Neon", rigidez=30, atraso=0.7, correr=(0.2 * (k - 2), 1.0 + 0.1 * k, 1.4 + 0.5 * k), detalhe=k >= 3)
            for k in range(5)
        ],
        "especial": dict(template="disco", n=1, origem=(0, 2.1, 0.8), raio=0, escala=1.6, cor=1, material="Neon", girar=60),
    },
    "engrenagem_de_orvalho": {
        "cores": ("B6D7FF", "6B64C6"),
        "pecas": [
            dict(template="engrenagem", modo="ancora", pos=(-1.5, 1.3, 0.8), rot=(0, 25, 0), giro=(0, 0, 50), cor=0, material="Glass", transp=0.25, rigidez=40, atraso=0.5, bob=0.1),
            dict(template="engrenagem", modo="ancora", pos=(1.6, 0.4, 0.7), rot=(0, -25, 0), giro=(0, 0, -70), cor=1, material="Glass", transp=0.25, rigidez=40, atraso=0.5, bob=0.1, escala=0.8),
            dict(template="engrenagem", modo="ancora", pos=(-0.4, -0.9, 1.3), rot=(0, 0, 0), giro=(0, 0, 90), cor=0, material="Glass", transp=0.25, rigidez=40, atraso=0.5, bob=0.08, escala=0.6, detalhe=True),
        ],
        "especial": dict(template="engrenagem", n=1, origem=(0, 0.5, 1.4), raio=0, escala=2.6, cor=1, material="Neon", girar=180),
    },
    "trilha_de_vaga_lumes": {
        "cores": ("FBF09A", "4A7A53"),
        "pecas": [
            dict(template="vagalume", modo="orbita", rx=1.4 + 0.25 * k, rz=1.3 + 0.2 * k, altura=-0.5 + 0.45 * k, ang=k * 0.9, vel=(0.5 + 0.1 * k) * (1 if k % 2 else -1), inclinacao=0.5, cor=0, material="Neon", rigidez=20 + 3 * k, atraso=0.9, osc=(0, 15, 3), correr=(0.25 * (k - 3), 0.4 + 0.15 * k, 1.2 + 0.45 * k), detalhe=k >= 5)
            for k in range(7)
        ],
        "especial": dict(template="vagalume", n=7, origem=(0, 1.0, 1.4), raio=2.0, escala=1.2, cor=0, material="Neon", arco=True),
    },
    "ambar_vivo": {
        "cores": ("FFBE66", "7D3A20"),
        "pecas": [
            dict(template="placa", modo="orbita", rx=1.8 + 0.15 * k, rz=1.6, altura=0.9 - 0.5 * k, ang=k * 1.57, vel=0.25, inclinacao=0.2, cor=0 if k % 2 == 0 else 1, material="Glass", transp=0.2, rigidez=20, atraso=0.9, bob=0.3 * (1 if k % 2 else -1), correr=(0.5 * (k - 1.5), 0.6, 1.6), correrRot=(0, 0, 0), detalhe=k >= 3)
            for k in range(4)
        ],
        "especial": dict(template="placa", n=6, origem=(0, 0.8, 0), raio=1.2, escala=1.4, cor=0, material="Glass"),
    },
})


# Raras
AURAS.update({
    "coroa_de_coral": {
        "cores": ("FF8DAA", "42D4C6"),
        "pecas": [
            dict(template="galho", modo="ancora", pos=(x, 1.3 + 0.25 * abs(x), 0.9), rot=(-15, 0, -x * 28), cor=k % 2, material="SmoothPlastic", rigidez=40, atraso=0.5, osc=(2, 5, 0.3), escala=1.6 - 0.25 * abs(x), correr=(x * 0.6, 1.2, 1.1), correrRot=(-50, 0, -x * 15), detalhe=k >= 4)
            for k, x in enumerate((0.0, -0.9, 0.9, -1.7, 1.7))
        ],
        "especial": dict(template="galho", n=8, origem=(0, 0.8, 0.6), raio=2.4, escala=1.3, cor=0, material="Neon"),
    },
    "relampago_de_giz": {
        "cores": ("F4F7FF", "4C93FF"),
        "pecas": [
            dict(template="raio", modo="ancora", pos=(-1.8, 0.8, 0.5), rot=(0, 30, 10), cor=0, material="Neon", rigidez=50, atraso=0.4, osc=(1, 8, 2.3), escala=1.3, correr=(-0.8, 0.6, 2.0), correrRot=(70, 0, 0)),
            dict(template="raio", modo="ancora", pos=(1.9, 0.5, 0.6), rot=(0, -30, -15), cor=1, material="Neon", rigidez=50, atraso=0.4, osc=(1, -8, 1.9), escala=1.15, correr=(0.8, 0.4, 2.4), correrRot=(70, 0, 0)),
            dict(template="raio", modo="ancora", pos=(0, 2.6, 1.0), rot=(0, 0, 90), cor=0, material="Neon", rigidez=40, atraso=0.5, osc=(2, 10, 2.7), escala=0.9, detalhe=True),
        ]
        + [
            dict(template="placa_tri", modo="orbita", rx=2.2, rz=2.0, altura=0.2 + 0.8 * k, ang=k * 2.1, vel=0.6, inclinacao=0.3, cor=1, material="SmoothPlastic", rigidez=34, atraso=0.6, giro=(40, 60, 0), escala=1.5, detalhe=k >= 2)
            for k in range(3)
        ],
        "especial": dict(template="raio", n=6, origem=(0, 0.6, 0), raio=2.8, escala=1.0, cor=1, material="Neon"),
    },
    "jiboia_de_fumaca": {
        "cores": ("7DD7B2", "2D696F"),
        "pecas": [
            dict(template="corpo", modo="ancora", pos=(0, 0.2, 0), giro=(0, 18, 0), cor=0, material="ForceField", rigidez=24, atraso=0.9, bob=0.2, osc=(2, 6, 0.25), correr=(0, 0.5, 1.4), correrRot=(0, 0, 0)),
            dict(template="corpo", modo="ancora", pos=(0, -0.4, 0), rot=(0, 140, 0), giro=(0, 18, 0), cor=1, material="ForceField", rigidez=20, atraso=1.0, bob=-0.2, escala=0.8, detalhe=True),
        ],
        "especial": dict(template="corpo", n=1, origem=(0, 1.8, 0), raio=0, escala=1.3, cor=0, material="ForceField", girar=90),
    },
    "fenda_de_porcelana": {
        "cores": ("F7F5EC", "2D3D69"),
        "pecas": [
            dict(template="caco", modo="ancora", pos=p, rot=r, cor=0, material="SmoothPlastic", rigidez=45, atraso=0.4, bob=0.08, osc=(1, 10, 0.4), escala=1.5, correr=(p[0] * 0.4, p[1] * 0.6 + 0.4, 1.3 + 0.4 * k), correrRot=(0, 0, 40), detalhe=k >= 4)
            for k, (p, r) in enumerate((((-1.45, 1.1, 0.0), (0, 60, 10)), ((1.5, 1.0, 0.1), (0, -60, -10)), ((-1.6, -0.1, -0.3), (0, 40, 30)), ((1.55, -1.3, -0.2), (0, -45, -20)), ((-0.9, -1.6, -0.6), (20, 20, 0))))
        ],
        "especial": dict(template="mascara", n=1, origem=(0, 1.4, -1.6), raio=0, escala=2.2, cor=0, material="SmoothPlastic"),
    },
    "petalas_de_ferrugem": {
        "cores": ("E78952", "543D50"),
        "pecas": [
            dict(template="petala", modo="orbita", rx=2.0 + 0.3 * (k % 3), rz=1.8 + 0.25 * (k % 3), altura=-0.6 + 0.45 * k, ang=k * 1.1, vel=0.55 if k % 2 else -0.45, inclinacao=0.35, cor=k % 2, material="Metal", rigidez=32, atraso=0.7, giro=(0, 0, 50), escala=1.6, correr=(0.3 * (k - 2.5), 0.4 + 0.15 * k, 1.6 + 0.3 * k), correrRot=(80, 0, 20), detalhe=k >= 4)
            for k in range(6)
        ],
        "especial": dict(template="petala", n=10, origem=(0, 0.8, 0), raio=2.8, escala=1.5, cor=0, material="Metal"),
    },
    "sinos_do_crepusculo": {
        "cores": ("BCA2FF", "D5A66D"),
        "pecas": [
            dict(template="sino", modo="ancora", pos=p, cor=1, material="Metal", rigidez=36, atraso=0.6, osc=(2, 14, 0.5 + 0.12 * k), escala=1.4 - 0.15 * k, correr=(p[0] * 0.5, p[1], 1.6))
            for k, p in enumerate(((-1.6, 1.6, 0.5), (1.7, 0.9, 0.4), (-1.2, -0.2, 0.9)))
        ]
        + [
            dict(template="onda", modo="ancora", pos=p, rot=(90, 0, 0), cor=0, material="Neon", transp=0.3, rigidez=36, atraso=0.6, pulso=0.3, escala=1.2, detalhe=k >= 2)
            for k, p in enumerate(((-1.6, 1.2, 0.5), (1.7, 0.5, 0.4), (-1.2, -0.6, 0.9)))
        ],
        "especial": dict(template="onda", n=3, origem=(0, 1.0, 0), raio=0.4, escala=5.0, cor=0, material="Neon"),
    },
    "esporos_de_safira": {
        "cores": ("53B3FF", "1D2758"),
        "pecas": [
            dict(template="cogumelo", modo="ancora", pos=p, rot=(0, 0, r), cor=0, material="Glass", transp=0.15, rigidez=50, atraso=0.4, pulso=0.06, escala=e, correrRot=(-30, 0, r), apontar=True, detalhe=k >= 3)
            for k, (p, r, e) in enumerate((((-1.3, -2.3, 0.5), 10, 1.6), ((1.2, -2.4, 0.7), -12, 1.3), ((-1.5, 1.5, 0.4), 25, 0.9), ((0.4, -2.5, -1.2), 5, 1.0)))
        ]
        + [
            dict(template="esporo_cubo", modo="orbita", rx=1.6, rz=1.5, altura=-1.0 + 1.2 * k, ang=k * 2.1, vel=0.5, inclinacao=0.4, cor=0, material="Neon", rigidez=30, atraso=0.7, giro=(80, 80, 0))
            for k in range(3)
        ],
        "especial": dict(template="cogumelo", n=8, origem=(0, -2.9, 0), raio=2.4, escala=1.4, cor=0, material="Glass"),
    },
    "solsticio_de_areia": {
        "cores": ("FFD27A", "7A5583"),
        "pecas": [
            dict(template="duna", modo="ancora", pos=(0, 2.3, 0.9), rot=(10, 0, 8), cor=0, material="SmoothPlastic", rigidez=40, atraso=0.5, bob=0.12, escala=1.5, correr=(0, 1.0, 1.8), correrRot=(0, 90, 0)),
            dict(template="duna", modo="ancora", pos=(0, -0.6, 1.1), rot=(-10, 0, -6), cor=0, material="SmoothPlastic", rigidez=40, atraso=0.5, bob=-0.12, escala=1.7, correr=(0, 0.0, 2.4), correrRot=(0, 90, 0)),
            dict(template="relogio", modo="ancora", pos=(1.3, 1.6, 0), rot=(0, 0, 90), giro=(0, 20, 0), cor=1, material="Neon", rigidez=46, atraso=0.4, escala=1.4),
        ],
        "especial": dict(template="relogio", n=1, origem=(0, 1.2, 1.6), raio=0, escala=3.4, cor=0, material="Neon", girar=180),
    },
    "marfim_flutuante": {
        "cores": ("F5E7CB", "876E93"),
        "pecas": [
            dict(template="presa", modo="ancora", pos=p, rot=r, cor=0, material="SmoothPlastic", rigidez=34, atraso=0.6, bob=0.3 * (1 if k % 2 else -1), escala=1.6, correr=(p[0] * 0.35, 0.8, 1.6), correrRot=(r[0], r[1] + 90, r[2]), detalhe=k >= 3)
            for k, (p, r) in enumerate((((-1.9, 1.0, 0.6), (0, 20, 15)), ((1.9, 0.9, 0.6), (0, 160, 15)), ((-1.6, -0.9, 0.9), (0, 30, -20)), ((1.6, -1.0, 0.9), (0, 150, -20))))
        ],
        "especial": dict(template="presa", n=2, origem=(0, 1.0, 1.6), raio=0.6, escala=2.6, cor=1, material="Neon"),
    },
    "lotus_de_gravidade": {
        "cores": ("9B83D9", "202036"),
        "pecas": [
            dict(template="lotus", modo="ancora", pos=(0, 2.9, 0.1), giro=(0, 12, 0), cor=1, material="SmoothPlastic", rigidez=50, atraso=0.4, bob=0.1, escala=1.5, correrRot=(-20, 0, 0)),
        ]
        + [
            dict(template="petala_solta", modo="orbita", rx=1.4 + 0.2 * k, rz=1.3 + 0.2 * k, altura=0.9 + 0.35 * k, ang=k * 1.25, vel=0.4, inclinacao=0.6, cor=k % 2, material="Neon" if k % 2 == 0 else "SmoothPlastic", rigidez=28, atraso=0.7, giro=(0, 0, 70), escala=1.4, correr=(math.cos(k) * 0.9, 0.6 + 0.2 * k, math.sin(k) * 0.9), detalhe=k >= 3)
            for k in range(5)
        ],
        "especial": dict(template="petala_solta", n=12, origem=(0, 2.9, 0.1), raio=2.2, escala=1.4, cor=0, material="Neon"),
    },
    "espelho_de_chuva": {
        "cores": ("C8E7FF", "3A6787"),
        "pecas": [
            dict(template="espelho", modo="orbita", rx=2.3, rz=2.1, altura=0.6 + 0.25 * (k % 2), ang=k * 1.57 + 0.4, vel=0.18, inclinacao=0.1, cor=0, material="Glass", transp=0.1, rigidez=36, atraso=0.6, rot=(0, 90, 0), escala=1.3, correr=(math.cos(k * 1.57) * 2.6, 0.7, 0.8 + abs(math.sin(k * 1.57))), detalhe=k >= 3)
            for k in range(4)
        ]
        + [
            dict(template="gota_espelho", modo="orbita", rx=2.0, rz=1.8, altura=-1.0 + 0.9 * k, ang=k * 2.0, vel=0.3, inclinacao=0.0, cor=1, material="Neon", rigidez=30, atraso=0.6, bob=0.6, detalhe=True)
            for k in range(3)
        ],
        "especial": dict(template="espelho", n=1, origem=(0, 1.2, 2.0), raio=0, escala=3.2, cor=0, material="Glass"),
    },
    "capsula_de_tempestade": {
        "cores": ("8AE8F5", "344B79"),
        "pecas": [
            dict(template="capsula", modo="ancora", pos=(0, 1.4, 1.5), giro=(0, 30, 0), cor=1, material="Metal", rigidez=40, atraso=0.5, bob=0.12, escala=1.6, correr=(0, 1.2, 2.0), abrirEscala=0.4),
            dict(template="trovao", modo="ancora", pos=(0, 1.4, 1.5), giro=(150, 230, 90), cor=0, material="Neon", rigidez=40, atraso=0.5, escala=1.6, correr=(0, 1.2, 2.0)),
        ]
        + [
            dict(template="aro", modo="ancora", pos=(0, 1.4, 1.5), rot=r, giro=g, cor=0, material="Neon", rigidez=40, atraso=0.5, escala=1.6, correr=(0, 1.2, 2.0), detalhe=k >= 2)
            for k, (r, g) in enumerate((((90, 0, 0), (0, 0, 40)), ((0, 0, 60), (0, 50, 0)), ((30, 0, -50), (0, -35, 0))))
        ],
        "especial": dict(template="trovao", n=6, origem=(0, 1.4, 1.5), raio=2.6, escala=2.0, cor=0, material="Neon"),
    },
    "cauda_de_cometa": {
        "cores": ("FF9A6A", "6C74EE"),
        "pecas": [
            dict(template="nucleo", modo="ancora", pos=(1.3, 1.9, 0.6), giro=(40, 60, 0), cor=0, material="Neon", rigidez=46, atraso=0.4, bob=0.1, escala=1.4, pulso=0.08),
        ]
        + [
            dict(template="faixa", modo="ancora", pos=(1.3, 1.9, 0.6), rot=(rx, -20 + 18 * k, 0), cor=k % 2, material="Neon", transp=0.15 + 0.15 * k, rigidez=30 - 4 * k, atraso=0.8, osc=(1, 10, 0.5 + 0.15 * k), escala=1.4, correr=(0.6, 1.6, 1.0), correrRot=(10, 0, 0), detalhe=k >= 2)
            for k, rx in enumerate((-5, 10, 25))
        ],
        "especial": dict(template="nucleo", n=1, origem=(0, 1.8, 0), raio=3.0, escala=1.2, cor=0, material="Neon"),
    },
    "prisma_do_silencio": {
        "cores": ("B7F7DD", "435870"),
        "pecas": [
            dict(template="octaedro", modo="ancora", pos=(0, 0.6, -1.6), giro=(0, 25, 10), cor=0, material="Glass", transp=0.2, rigidez=50, atraso=0.4, bob=0.12, escala=1.3, correr=(0, 0.8, 1.6)),
        ]
        + [
            dict(template="placa_som", modo="orbita", rx=1.9, rz=1.7, altura=0.6 + 0.5 * math.sin(k * 2), ang=k * 1.57, vel=0.2, inclinacao=0.0, cor=1, material="SmoothPlastic", rigidez=36, atraso=0.6, rot=(0, 90, 0), escala=1.8, correr=(math.cos(k * 1.57) * 1.0, 0.8, 1.6 + math.sin(k * 1.57) * 0.5), correrRot=(0, 0, 90), detalhe=k >= 3)
            for k in range(4)
        ],
        "especial": dict(template="placa_som", n=8, origem=(0, 0.8, 0), raio=3.4, escala=2.0, cor=0, material="Glass"),
    },
})


# Épicas
AURAS.update({
    "jardim_das_agulhas": {
        "cores": ("FF8AD7", "5E379A"),
        "pecas": [
            dict(template="flor", modo="ancora", pos=p, rot=r, cor=k % 2, material="Neon", rigidez=40, atraso=0.5, osc=(2, 12, 0.35 + 0.08 * k), escala=1.7 - 0.2 * (k % 2), apontar=True, detalhe=k >= 4)
            for k, (p, r) in enumerate((((-1.6, 1.2, 0.3), (0, 0, 20)), ((1.7, 0.9, 0.4), (0, 0, -25)), ((-1.3, -0.5, 0.7), (0, 0, 35)), ((1.4, -0.9, 0.6), (0, 0, -30)), ((0, 2.3, 1.0), (-20, 0, 0))))
        ],
        "especial": dict(template="flor", n=8, origem=(0, 1.0, 0), raio=2.6, escala=1.6, cor=0, material="Neon"),
    },
    "carrossel_de_eclipses": {
        "cores": ("E8B56E", "693A6B"),
        "pecas": [
            dict(template="orbita", modo="ancora", pos=(0, 0.8 + 0.6 * k, 0), rot=(20 - 20 * k, 30 * k, 15 * (k - 1)), giro=(0, 10 + 5 * k, 0), cor=0, material="Neon", transp=0.3, rigidez=50, atraso=0.4, detalhe=k >= 2)
            for k in range(3)
        ]
        + [
            dict(template="eclipse", modo="orbita", rx=2.4, rz=2.4, altura=0.8 + 0.6 * k, ang=k * 2.1, vel=0.4 + 0.15 * k, inclinacao=0.5 - 0.35 * k, cor=1, material="SmoothPlastic", rigidez=40, atraso=0.5, escala=1.6, correr=(-0.9 + 0.9 * k, 1.0 + 0.5 * k, 1.6 + 0.3 * k))
            for k in range(3)
        ],
        "especial": dict(template="eclipse", n=1, origem=(0, 2.2, 1.0), raio=0, escala=4.0, cor=1, material="SmoothPlastic"),
    },
    "coracao_de_basalto": {
        "cores": ("FF684D", "4C4159"),
        "pecas": [
            dict(template="coracao", modo="ancora", pos=(0, 0.7, 1.2), giro=(0, 10, 0), cor=1, material="Slate", rigidez=60, atraso=0.3, pulso=0.05, escala=2.0),
            dict(template="veio", modo="ancora", pos=(0, 0.7, 1.2), giro=(0, 10, 0), cor=0, material="Neon", rigidez=60, atraso=0.3, pulso=0.1, escala=2.1),
        ]
        + [
            dict(template="pedra", modo="orbita", rx=2.1, rz=1.9, altura=0.3 + 0.5 * k, ang=k * 1.6, vel=0.45 if k % 2 else -0.35, inclinacao=0.3, cor=1 if k % 2 else 0, material="Slate" if k % 2 else "Neon", rigidez=36, atraso=0.6, giro=(40, 50, 0), escala=2.0, detalhe=k >= 3)
            for k in range(4)
        ],
        "especial": dict(template="pedra", n=8, origem=(0, 0.7, 1.2), raio=2.6, escala=1.8, cor=0, material="Neon"),
    },
    "plumas_de_mercurio": {
        "cores": ("D7E7F0", "6E809B"),
        "pecas": [
            dict(template="asa", modo="ancora", pos=(s * 0.5, 1.2, 0.9), rot=(10, s * 25, 0), cor=0, material="Metal", rigidez=40, atraso=0.5, osc=(2, s * 8, 0.4), escala=1.5, espelhar=s < 0, correrRot=(10, s * 70, s * 30), abrirGiro=(0, -s * 35, -s * 40))
            for s in (-1, 1)
        ],
        "especial": dict(template="asa", n=6, origem=(0, 2.0, 0.6), raio=1.2, escala=0.8, cor=1, material="Metal"),
    },
    "valsa_do_abismo": {
        "cores": ("8E75E5", "1D1638"),
        "pecas": [
            dict(template="fita", modo="ancora", pos=(0, 0.3, 0), giro=(0, 30, 0), cor=1, material="SmoothPlastic", rigidez=30, atraso=0.8, bob=0.25, correrRot=(-15, 0, 0)),
            dict(template="fita", modo="ancora", pos=(0, 0.2, 0), rot=(0, 180, 0), giro=(0, 30, 0), cor=0, material="Neon", transp=0.15, rigidez=26, atraso=0.9, bob=-0.25, escala=0.92),
        ],
        "especial": dict(template="fita", n=1, origem=(0, 0.6, 0.8), raio=0, escala=1.2, cor=0, material="Neon", girar=200),
    },
    "navio_de_papel_fantasma": {
        "cores": ("ECE7D1", "3D88A5"),
        "pecas": [
            dict(template="barco", modo="orbita", rx=2.0 + 0.25 * k, rz=1.8, altura=0.6 + 0.6 * k, ang=k * 2.1, vel=0.3, inclinacao=0.25, cor=0, material="SmoothPlastic", rigidez=30, atraso=0.7, osc=(2, 10, 0.4 + 0.1 * k), escala=1.7, correr=(0.7 * (k - 1), 0.8, 1.8), detalhe=k >= 2)
            for k in range(3)
        ]
        + [
            dict(template="onda", modo="orbita", rx=2.0 + 0.25 * k, rz=1.8, altura=0.35 + 0.6 * k, ang=k * 2.1, vel=0.3, inclinacao=0.25, cor=1, material="Neon", transp=0.2, rigidez=30, atraso=0.7, escala=1.3, detalhe=k >= 2)
            for k in range(3)
        ],
        "especial": dict(template="barco", n=1, origem=(0, 1.6, 2.2), raio=0, escala=4.0, cor=1, material="ForceField"),
    },
    "duas_luas_partidas": {
        "cores": ("E7EAFF", "7A69B8"),
        "pecas": [
            dict(template="lua", modo="ancora", pos=(-1.4, 2.0, 0.8), rot=(0, 20, 30), giro=(0, 0, 12), cor=0, material="Neon", rigidez=40, atraso=0.5, bob=0.15, escala=1.4, correr=(-1.0, 2.1, 1.6), correrRot=(0, 70, 30), abrir=(0.9, -0.5, 0)),
            dict(template="lua", modo="ancora", pos=(1.4, -0.4, 0.9), rot=(0, -20, 210), giro=(0, 0, -10), cor=1, material="Neon", rigidez=40, atraso=0.5, bob=-0.15, escala=1.25, correr=(1.0, -0.2, 1.8), correrRot=(0, -70, 210), abrir=(-0.9, 0.6, 0)),
        ],
        "especial": dict(template="lua", n=2, origem=(0, 1.0, 1.4), raio=0.5, escala=1.6, cor=0, material="Neon", girar=90),
    },
    "correntes_do_vazio": {
        "cores": ("6FA0C3", "1A1539"),
        "pecas": [
            dict(template="nucleo", modo="ancora", pos=(0, -0.3, 1.3), cor=1, material="SmoothPlastic", rigidez=50, atraso=0.4, pulso=0.1, escala=1.3),
        ]
        + [
            dict(template="corrente", modo="ancora", pos=(0, -0.3, 1.3), rot=(70 * math.cos(k * 1.05), k * 60, 70 * math.sin(k * 1.05)), cor=0 if k % 2 else 1, material="Metal", rigidez=24 + 2 * k, atraso=0.8, osc=(0, 12, 0.3 + 0.07 * k), escala=1.4, correrRot=(110, 0, 0), detalhe=k >= 4)
            for k in range(6)
        ],
        "especial": dict(template="corrente", n=6, origem=(0, 1.0, 0), raio=2.4, escala=1.4, cor=0, material="Neon"),
    },
    "catedral_de_sal": {
        "cores": ("F7F5E5", "7BDDE8"),
        "pecas": [
            dict(template="arco", modo="ancora", pos=(x, 1.0, 1.0 + 0.4 * abs(x)), rot=(0, x * 25, 0), cor=k % 2, material="Glass", transp=0.15, rigidez=46, atraso=0.4, escala=1.5 - 0.15 * abs(x), correrRot=(0, x * 50, 0), detalhe=k >= 3)
            for k, x in enumerate((0, -1.2, 1.2, -2.0, 2.0))
        ],
        "especial": dict(template="arco", n=8, origem=(0, 1.0, 0), raio=1.8, escala=2.0, cor=1, material="Glass"),
    },
    "circulo_dos_predadores": {
        "cores": ("FFB38A", "6D263B"),
        "pecas": [
            dict(template="pegada", modo="orbita", rx=2.3, rz=2.1, altura=0.2 + 0.7 * (k % 2), ang=k * 1.57 + 0.78, vel=0.35, inclinacao=0.2, cor=k % 2, material="Neon", rigidez=36, atraso=0.6, rot=(0, 0, 45 * (1 if k % 2 else -1)), pulso=0.15, escala=1.8, detalhe=k >= 3)
            for k in range(4)
        ]
        + [
            dict(template="arranhao", modo="ancora", pos=(0, 0.6, 1.8), rot=(0, 0, 25), cor=0, material="Neon", transp=0.1, rigidez=50, atraso=0.5, pulso=0.2, escala=1.6, correr=(0, 0.4, 2.6)),
        ],
        "especial": dict(template="arranhao", n=3, origem=(0, 1.2, -1.4), raio=0.8, escala=3.0, cor=0, material="Neon"),
    },
    "jardim_invertido": {
        "cores": ("87F3CE", "3B4B9E"),
        "pecas": [
            dict(template="raiz_teto", modo="ancora", pos=(0, 3.6, 0.2), giro=(0, 8, 0), cor=1, material="SmoothPlastic", rigidez=40, atraso=0.5, escala=1.6, correrRot=(-15, 0, 0)),
        ]
        + [
            dict(template="flor_pendente", modo="ancora", pos=(1.5 * math.cos(a), 3.0 - 0.3 * (k % 2), 1.4 * math.sin(a)), cor=0, material="Neon", rigidez=26, atraso=0.7, osc=(0, 10, 0.4 + 0.1 * k), escala=1.6, correrRot=(-30, 0, 0), detalhe=k >= 4)
            for k, a in enumerate([k * 1.25 + 0.3 for k in range(5)])
        ],
        "especial": dict(template="flor_pendente", n=10, origem=(0, -2.5, 0), raio=2.4, escala=1.6, cor=0, material="Neon"),
    },
    "guardiao_da_ampulheta": {
        "cores": ("E6C681", "7E5E6F"),
        "pecas": [
            dict(template="ampulheta", modo="ancora", pos=(0, 1.0, 1.6), rot=(0, 0, 8), giro=(0, 15, 0), cor=1, material="Glass", transp=0.2, rigidez=40, atraso=0.5, escala=1.4, abrirGiro=(0, 0, 180)),
            dict(template="areia", modo="ancora", pos=(0, 1.0, 1.6), rot=(0, 0, 8), giro=(0, 15, 0), cor=0, material="Neon", rigidez=40, atraso=0.5, escala=1.4, pulso=0.06, abrirGiro=(0, 0, 180)),
        ],
        "especial": dict(template="areia", n=6, origem=(0, 1.0, 1.6), raio=2.2, escala=0.8, cor=0, material="Neon"),
    },
    "mare_de_vidro_negro": {
        "cores": ("7695CA", "080F28"),
        "pecas": [
            dict(template="onda", modo="ancora", pos=(s * 0.9, -1.8, 1.0), rot=(0, s * 30, 0), cor=1, material="Glass", transp=0.05, rigidez=40, atraso=0.5, osc=(0, 8, 0.35), escala=1.6, correr=(s * 0.6, -2.4, 1.8), correrRot=(-60, s * 20, 0))
            for s in (-1, 1)
        ]
        + [
            dict(template="onda", modo="ancora", pos=(0, -1.6, 1.4), cor=0, material="Neon", transp=0.6, rigidez=36, atraso=0.6, osc=(0, 6, 0.3), escala=1.8, detalhe=True),
        ],
        "especial": dict(template="onda", n=1, origem=(0, -1.2, 2.0), raio=0, escala=3.4, cor=0, material="Glass"),
    },
    "sussurro_das_mascaras": {
        "cores": ("D6C7FF", "663763"),
        "pecas": [
            dict(template="mascara", modo="orbita", rx=2.3, rz=2.1, altura=0.6 + 0.4 * math.sin(k * 1.3), ang=k * 1.256, vel=0.2, inclinacao=0.25, cor=k % 2, material="Wood" if k % 2 else "SmoothPlastic", rigidez=32, atraso=0.7, rot=(0, 180, 0), osc=(1, 25, 0.12), escala=1.6, correr=(0.3 * (k - 2), 1.2 + 0.1 * k, 1.4 + 0.35 * k), detalhe=k >= 4)
            for k in range(5)
        ],
        "especial": dict(template="mascara", n=5, origem=(0, 1.2, -1.0), raio=2.2, escala=1.8, cor=0, material="Neon", arco=True),
    },
})


# Lendárias
AURAS.update({
    "arquiduque_de_cinzas": {
        "cores": ("FF8F69", "4A3442"),
        "pecas": [
            dict(template="capa", modo="ancora", pos=(0, 0.9, 1.0), cor=1, material="Slate", rigidez=30, atraso=0.7, osc=(0, 6, 0.6), escala=1.5, correrRot=(-40, 0, 0), abrirEscala=0.5),
            dict(template="capa", modo="ancora", pos=(0, 0.9, 1.05), cor=0, material="Neon", transp=0.55, rigidez=28, atraso=0.75, osc=(0, 6, 0.6), escala=1.55, correrRot=(-40, 0, 0), detalhe=True),
            dict(template="broche", modo="ancora", pos=(0, 1.3, -0.55), cor=0, material="Neon", rigidez=60, atraso=0.3, pulso=0.12, escala=1.3),
        ],
        "especial": dict(template="capa", n=2, origem=(0, 1.0, 1.0), raio=1.8, escala=1.4, cor=0, material="Neon"),
    },
    "aurora_do_mar_profundo": {
        "cores": ("8DE9F5", "735AF0"),
        "pecas": [
            dict(template="umbrela", modo="ancora", pos=(0, 3.2, 0.9), cor=1, material="ForceField", rigidez=30, atraso=0.6, pulso=0.08, bob=0.2, escala=1.3, correrRot=(-25, 0, 0)),
        ]
        + [
            dict(template="tentaculo", modo="ancora", pos=(1.3 * math.cos(a), 2.95, 0.9 + 1.2 * math.sin(a)), cor=0, material="Neon", transp=0.2, rigidez=18 + 2 * k, atraso=1.0, osc=(2, 14, 0.35 + 0.06 * k), escala=1.2, correrRot=(-50, 0, 0), detalhe=k >= 4)
            for k, a in enumerate([k * 1.05 for k in range(6)])
        ],
        "especial": dict(template="umbrela", n=1, origem=(0, 3.6, 0.9), raio=0, escala=2.6, cor=0, material="ForceField"),
    },
    "imperatriz_de_porcelana": {
        "cores": ("FFE3EF", "465A9E"),
        "pecas": [
            dict(template="leque", modo="ancora", pos=(0, 0.7, 1.2), cor=0, material="SmoothPlastic", rigidez=40, atraso=0.5, osc=(2, 4, 0.25), escala=1.5, correrRot=(0, 0, 0), abrirEscala=0.4),
        ]
        + [
            dict(template="caco", modo="orbita", rx=2.2, rz=2.0, altura=0.4 + 0.7 * k, ang=k * 2.1, vel=0.4, inclinacao=0.3, cor=1, material="Neon", rigidez=34, atraso=0.6, giro=(50, 40, 0), escala=1.4, detalhe=k >= 2)
            for k in range(3)
        ],
        "especial": dict(template="leque", n=3, origem=(0, 1.0, 1.6), raio=1.0, escala=1.8, cor=1, material="Neon", arco=True),
    },
    "trono_de_raios": {
        "cores": ("F9D47A", "6A55A6"),
        "pecas": [
            dict(template="relampago", modo="ancora", pos=p, rot=r, cor=0, material="Neon", rigidez=50, atraso=0.4, osc=(1, 6, 2.2 + 0.3 * k), escala=1.4, correr=(p[0] * 0.5, p[1], 2.0), correrRot=(70, 0, 0), detalhe=k >= 3)
            for k, (p, r) in enumerate((((-1.3, 0.6, 1.0), (0, 0, 0)), ((1.3, 0.6, 1.0), (0, 0, 0)), ((0, 2.5, 1.3), (0, 0, 90)), ((0, -0.5, 1.4), (0, 0, 90))))
        ]
        + [
            dict(template="aro", modo="ancora", pos=(0, 1.0, 1.2), rot=(90, 0, 0), giro=(0, 0, 15), cor=1, material="Metal", rigidez=46, atraso=0.4, escala=1.4),
        ],
        "especial": dict(template="relampago", n=4, origem=(0, 1.0, 1.0), raio=1.6, escala=1.8, cor=0, material="Neon"),
    },
    "relicario_do_inverno": {
        "cores": ("DCF7FF", "7591D0"),
        "pecas": [
            dict(template="altar", modo="ancora", pos=(0, 2.9, 0.4), giro=(0, 15, 0), cor=0, material="Glass", transp=0.15, rigidez=46, atraso=0.4, bob=0.12, escala=1.6),
        ]
        + [
            dict(template="sino_gelo", modo="orbita", rx=2.0, rz=1.8, altura=0.6 + 0.6 * k, ang=k * 2.1, vel=0.35, inclinacao=0.3, cor=1, material="Glass", transp=0.1, rigidez=32, atraso=0.6, osc=(2, 12, 0.5), escala=1.8, detalhe=k >= 2)
            for k in range(3)
        ]
        + [
            dict(template="prisma", modo="orbita", rx=2.5, rz=2.2, altura=-0.4 + 0.9 * k, ang=k * 2.1 + 1.0, vel=-0.5, inclinacao=0.3, cor=0, material="Neon", rigidez=36, atraso=0.6, giro=(0, 60, 0), escala=0.9, correr=(0.4 * (k - 1), 0.8, 1.8 + 0.4 * k), detalhe=k >= 2)
            for k in range(3)
        ],
        "especial": dict(template="altar", n=1, origem=(0, 1.2, 1.4), raio=0, escala=4.0, cor=0, material="Glass"),
    },
    "atlas_fragmentado": {
        "cores": ("9EC5FB", "8AD69C"),
        "pecas": [
            dict(template="ilha", modo="orbita", rx=2.3 + 0.2 * (k % 2), rz=2.1, altura=-0.3 + 0.6 * k, ang=k * 1.57, vel=0.25 if k % 2 else -0.2, inclinacao=0.35, cor=k % 2, material="SmoothPlastic", rigidez=30, atraso=0.6, giro=(0, 15, 0), escala=1.5 - 0.1 * k, correr=(math.cos(k * 1.57) * 1.3, 0.4 + 0.4 * k, math.sin(k * 1.57) * 1.3), detalhe=k >= 3)
            for k in range(4)
        ],
        "especial": dict(template="ilha", n=8, origem=(0, 1.2, 0), raio=0.6, escala=1.2, cor=1, material="SmoothPlastic"),
    },
    "serpente_de_cristal": {
        "cores": ("88F2EB", "547FCB"),
        "pecas": [
            dict(template="corpo", modo="pendulo", raio=2.6, altura=1.2, abertura=0.9, vel=0.35, cor=0, material="Glass", transp=0.1, rigidez=14, atraso=1.6, escala=1.2, abrir=(0, 2.4, 0)),
            dict(template="olho", modo="orbita", rx=2.6, rz=2.4, altura=1.6, ang=0, vel=0.35, inclinacao=0.2, cor=1, material="Neon", rigidez=20, atraso=1.0, escala=1.6, detalhe=True),
        ],
        "especial": dict(template="olho", n=10, origem=(0, 4.2, 0.4), raio=2.4, escala=1.4, cor=0, material="Neon"),
    },
    "horizonte_rasgado": {
        "cores": ("FF729F", "24103F"),
        "pecas": [
            dict(template="fenda", modo="ancora", pos=(1.6, 1.2, 1.4), rot=(0, -25, 8), cor=1, material="SmoothPlastic", rigidez=34, atraso=0.6, pulso=0.06, osc=(0, 6, 0.3), escala=1.6, correrRot=(0, 60, 8)),
            dict(template="borda", modo="ancora", pos=(1.6, 1.2, 1.38), rot=(0, -25, 8), cor=0, material="Neon", rigidez=34, atraso=0.6, pulso=0.06, osc=(0, 6, 0.3), escala=1.6, correrRot=(0, 60, 8)),
        ],
        "especial": dict(template="borda", n=4, origem=(1.6, 1.2, 1.4), raio=1.8, escala=1.6, cor=0, material="Neon"),
    },
    "arauto_dos_mil_sinos": {
        "cores": ("FDE7A1", "8760AD"),
        "pecas": [
            dict(template="halo", modo="ancora", pos=(0, 2.9, 0.3), rot=(12, 0, 0), giro=(0, 18, 0), cor=0, material="Metal", rigidez=46, atraso=0.4, bob=0.1, escala=1.5, correrRot=(30, 0, 0)),
            dict(template="onda", modo="ancora", pos=(0, 2.6, 0.3), rot=(0, 0, 0), cor=1, material="Neon", transp=0.3, rigidez=46, atraso=0.4, pulso=0.35, escala=3.0, detalhe=True),
        ],
        "especial": dict(template="sino", n=10, origem=(0, 3.0, 0.3), raio=2.8, escala=1.4, cor=0, material="Neon"),
    },
    "orquestra_das_estrelas": {
        "cores": ("B7A5FF", "FFC2EC"),
        "pecas": [
            dict(template="harpa", modo="ancora", pos=(0, 1.2, 1.4), rot=(0, 0, 0), cor=0, material="Neon", rigidez=40, atraso=0.5, osc=(1, 6, 0.25), escala=1.5, correrRot=(0, 70, 0)),
        ]
        + [
            dict(template="nota", modo="orbita", rx=2.1 + 0.2 * (k % 2), rz=1.9, altura=0.3 + 0.55 * k, ang=k * 1.6, vel=0.5 if k % 2 else -0.4, inclinacao=0.4, cor=1, material="Neon", rigidez=32, atraso=0.6, giro=(0, 0, 90), escala=1.6, detalhe=k >= 3)
            for k in range(4)
        ],
        "especial": dict(template="nota", n=10, origem=(0, 2.6, 0.6), raio=3.0, escala=1.6, cor=0, material="Neon", arco=True),
    },
    "majestade_de_cobre": {
        "cores": ("FFCA80", "854F50"),
        "pecas": [
            dict(template="leao", modo="ancora", pos=(0, 2.3, 1.3), rot=(0, 180, 0), cor=0, material="Metal", rigidez=46, atraso=0.4, pulso=0.04, escala=1.5, abrirGiro=(-30, 0, 0)),
            dict(template="relogio", modo="ancora", pos=(0, 0.6, -0.6), giro=(0, 0, 30), cor=1, material="Neon", rigidez=60, atraso=0.3, escala=1.3),
        ],
        "especial": dict(template="engrenagem", n=0, origem=(0, 2.3, 1.3), raio=0, escala=1, cor=0, material="Neon"),
    },
})
# Majestade: o especial usa engrenagens da própria aura (crina) — reaproveita o leão em rajada
AURAS["majestade_de_cobre"]["especial"] = dict(template="relogio", n=8, origem=(0, 2.3, 1.3), raio=2.6, escala=1.6, cor=0, material="Neon")


# Míticas
AURAS.update({
    "devorador_de_alvoradas": {
        "cores": ("FFAD4D", "150F29"),
        "pecas": [
            dict(template="sol_negro", modo="ancora", pos=(0, 2.4, 1.6), giro=(0, 0, 10), cor=1, material="SmoothPlastic", rigidez=40, atraso=0.5, pulso=0.04, escala=1.5),
            dict(template="anel_brasas", modo="ancora", pos=(0, 2.4, 1.62), giro=(0, 0, -20), cor=0, material="Neon", rigidez=40, atraso=0.5, pulso=0.06, escala=1.5),
            dict(template="mandibula", modo="ancora", pos=(0, 2.4, 1.5), rot=(0, 0, 0), cor=1, material="Slate", rigidez=40, atraso=0.5, osc=(2, 8, 0.4), escala=1.5, abrirGiro=(0, 0, 25), correr=(0, 2.2, 1.0)),
            dict(template="mandibula", modo="ancora", pos=(0, 2.4, 1.5), rot=(0, 0, 180), cor=1, material="Slate", rigidez=40, atraso=0.5, osc=(2, -8, 0.4), escala=1.5, abrirGiro=(0, 0, -25), correr=(0, 2.2, 1.0)),
        ],
        "especial": dict(template="anel_brasas", n=1, origem=(0, 2.4, 1.6), raio=0, escala=3.0, cor=0, material="Neon", girar=180),
    },
    "coroa_do_fim": {
        "cores": ("CCA7FF", "131023"),
        "pecas": [
            dict(template="ponta", modo="ancora", pos=(1.4 * math.cos(a), 3.4 + 0.3 * math.sin(a * 2), 1.4 * math.sin(a)), rot=(0, -math.degrees(a) + 90, 12), giro=(0, 0, 0), osc=(1, 25, 0.12 + 0.03 * k), cor=1 if k % 2 else 0, material="SmoothPlastic" if k % 2 else "Neon", rigidez=36, atraso=0.6, bob=0.18, escala=1.7, correr=(0.45 * (k - 2), 2.8, 1.4 + 0.3 * k), correrRot=(-60, 0, 0), abrir=(0, -1.2, 0))
            for k, a in enumerate([k * 2 * math.pi / 5 for k in range(5)])
        ],
        "especial": dict(template="ponta", n=5, origem=(0, 3.2, 0), raio=2.6, escala=2.2, cor=0, material="Neon"),
    },
    "oceano_sem_fundo": {
        "cores": ("39B6E6", "071427"),
        "pecas": [
            dict(template="janela", modo="ancora", pos=(0, 1.0, 1.7), cor=1, material="Glass", transp=0.1, rigidez=40, atraso=0.5, escala=1.4, correrRot=(0, 0, 0), abrirEscala=0.3),
            dict(template="moldura", modo="ancora", pos=(0, 1.0, 1.66), cor=0, material="Neon", rigidez=40, atraso=0.5, escala=1.4, pulso=0.03, abrirEscala=0.3),
        ]
        + [
            dict(template="peixe", modo="orbita", rx=0.7, rz=0.05, altura=0.2 + 0.8 * k, ang=k * 2.0, vel=0.5 + 0.2 * k, inclinacao=0.6, cor=0, material="Neon", rigidez=40, atraso=0.4, escala=1.6, detalhe=k >= 2)
            for k in range(3)
        ],
        "especial": dict(template="peixe", n=12, origem=(0, 1.0, 2.2), raio=3.2, escala=3.0, cor=0, material="Neon", arco=True),
    },
    "fio_das_parcas": {
        "cores": ("FFE8EF", "C63B66"),
        "pecas": [
            dict(template="tear", modo="ancora", pos=(0, 2.6, 0.9), rot=(-10, 0, 0), cor=0, material="Neon", rigidez=46, atraso=0.4, bob=0.12, escala=1.3),
        ]
        + [
            dict(template="fio", modo="ancora", pos=(x, 1.4, 1.0), rot=(0, 0, x * 10), giro=(0, 40 * (1 if k % 2 else -1), 0), cor=k % 2, material="Neon", rigidez=28, atraso=0.7, osc=(2, 10, 0.5 + 0.1 * k), escala=1.2, correrRot=(70, 0, 0), detalhe=k >= 2)
            for k, x in enumerate((-0.9, 0.9, 0.0))
        ],
        "especial": dict(template="fio", n=8, origem=(0, 1.4, 1.2), raio=2.4, escala=1.4, cor=1, material="Neon", arco=True),
    },
    "labirinto_vivo": {
        "cores": ("F2E0B9", "7874AE"),
        "pecas": [
            dict(template="cubo", modo="ancora", pos=(0, 1.6, 1.8), giro=(20, 30, 0), cor=1, material="Neon", rigidez=40, atraso=0.5, escala=1.3, correr=(0, 1.2, 1.4)),
            dict(template="escada", modo="orbita", rx=2.3, rz=2.1, altura=0.2, ang=0.4, vel=0.3, inclinacao=0.3, cor=0, material="Sandstone", rigidez=32, atraso=0.6, giro=(0, 0, 30), escala=1.4, correr=(-1.0, 0.8, 1.6)),
            dict(template="escada", modo="orbita", rx=2.3, rz=2.1, altura=1.4, ang=3.5, vel=0.3, inclinacao=0.3, cor=0, material="Sandstone", rigidez=32, atraso=0.6, giro=(0, 0, -30), escala=1.2, correr=(1.0, 1.6, 1.6)),
            dict(template="arco_pedra", modo="orbita", rx=2.6, rz=2.3, altura=0.8, ang=1.9, vel=-0.2, inclinacao=0.2, cor=0, material="Sandstone", rigidez=30, atraso=0.6, escala=1.3, detalhe=True),
        ],
        "especial": dict(template="escada", n=6, origem=(0, -2.0, 1.4), raio=1.0, escala=1.6, cor=1, material="Neon", arco=True),
    },
    "eclipse_de_mil_olhos": {
        "cores": ("FF7BB9", "15122E"),
        "pecas": [
            dict(template="anel_eclipse", modo="ancora", pos=(0, 2.0, 1.8), giro=(0, 0, 12), cor=0, material="Neon", rigidez=40, atraso=0.5, escala=1.3),
            dict(template="olho_grande", modo="ancora", pos=(0, 2.0, 1.75), rot=(0, 180, 0), cor=1, material="SmoothPlastic", rigidez=40, atraso=0.5, pulso=0.05, escala=1.3, osc=(1, 15, 0.15)),
        ]
        + [
            dict(template="olho", modo="orbita", rx=2.2 + 0.2 * (k % 2), rz=1.9, altura=0.5 + 0.5 * (k % 3), ang=k * 1.05, vel=0.25 if k % 2 else -0.3, inclinacao=0.6, cor=0, material="Neon", rigidez=32, atraso=0.6, osc=(1, 40, 0.2 + 0.05 * k), escala=1.6, correr=(0.5 * math.cos(k), 1.6, -0.4), detalhe=k >= 4)
            for k in range(6)
        ],
        "especial": dict(template="olho", n=12, origem=(0, 1.6, 0), raio=3.4, escala=2.0, cor=0, material="Neon"),
    },
})


# Divinas
AURAS.update({
    "alvorecer_dos_titas": {
        "cores": ("FFE1A8", "8B8DE8"),
        "pecas": [
            dict(template="mao", modo="ancora", pos=(s * 2.0, 1.2, 1.4), rot=(0, s * -20, s * -25), cor=0, material="Marble", rigidez=26, atraso=0.8, osc=(0, 5, 0.25), bob=0.2, escala=1.5, espelhar=s < 0, correr=(s * 1.4, 1.6, 1.0), correrRot=(-40, 0, s * -10), abrir=(s * 0.8, 1.8, 0.4))
            for s in (-1, 1)
        ]
        + [
            dict(template="halo_solar", modo="ancora", pos=(0, 3.6, 1.0), rot=(10, 0, 0), giro=(0, 0, 10), cor=0, material="Neon", rigidez=46, atraso=0.4, pulso=0.04, escala=1.3),
        ],
        "especial": dict(template="mao", n=2, origem=(0, 1.0, 2.2), raio=2.6, escala=2.6, cor=1, material="Neon"),
    },
    "divindade_do_prisma": {
        "cores": ("E8F6FF", "D89FFF"),
        "pecas": [
            dict(template="catedral", modo="ancora", pos=(0, 1.4, 1.8), cor=0, material="Glass", transp=0.1, rigidez=40, atraso=0.5, escala=1.3, correr=(0, 1.0, 2.6), correrRot=(-70, 0, 0)),
            dict(template="nucleo", modo="ancora", pos=(0, 1.3, 1.2), giro=(0, 45, 0), cor=1, material="Neon", rigidez=50, atraso=0.4, pulso=0.1, escala=1.4),
        ]
        + [
            dict(template="petala_luz", modo="ancora", pos=(0, 1.0, 2.0), rot=(0, 0, -60 + 30 * k), cor=k % 2, material="Neon", transp=0.4, rigidez=40, atraso=0.5, osc=(2, 4, 0.25), escala=0.9, abrirEscala=0.8, detalhe=k >= 3)
            for k in range(5)
        ],
        "especial": dict(template="petala_luz", n=5, origem=(0, 1.0, 1.8), raio=0.6, escala=2.2, cor=0, material="Neon", arco_iris=True),
    },
    "ultimo_jardim": {
        "cores": ("D0FFDA", "F8B1F1"),
        "pecas": [
            dict(template="arvore", modo="ancora", pos=(0, 1.3, 1.9), cor=0, material="Neon", transp=0.2, rigidez=34, atraso=0.6, osc=(2, 3, 0.2), escala=1.5, correrRot=(-35, 0, 0)),
        ]
        + [
            dict(template="flor_galaxia", modo="orbita", rx=2.3 + 0.3 * (k % 2), rz=2.0, altura=0.6 + 0.4 * k, ang=k * 1.25, vel=0.25, inclinacao=0.5, cor=1, material="Neon", rigidez=30, atraso=0.6, giro=(0, 0, 40), pulso=0.15, escala=1.8, correr=(0.4 * (k - 2), 1.8 + 0.2 * k, 1.6 + 0.3 * k), detalhe=k >= 3)
            for k in range(5)
        ],
        "especial": dict(template="flor_galaxia", n=14, origem=(0, 2.4, 1.6), raio=3.6, escala=2.2, cor=1, material="Neon"),
    },
})


# Ajuste de leitura das Comuns/Incomuns (rodada 2): peças maiores e mais afastadas do corpo,
# para não sumirem atrás do avatar. (fator de tamanho, fator de afastamento)
AJUSTE = {
    "centelha_do_nexo": (1.3, 1.0),
    "musgo_luminoso": (1.8, 1.15),
    "fagulha_de_cobre": (2.2, 1.15),
    "chuvisco_de_vidro": (1.3, 1.1),
    "borboletas_de_cinza": (2.2, 1.2),
    "gelo_de_neon": (1.25, 1.0),
    "mare_de_quartzo": (1.15, 1.05),
    "raiz_cintilante": (1.35, 1.15),
    "nevoa_de_amora": (1.0, 1.05),
    "vento_de_papel": (2.4, 1.15),
    "polen_lunar": (1.8, 1.1),
    "engrenagem_de_orvalho": (1.5, 1.15),
    "trilha_de_vaga_lumes": (2.6, 1.1),
    "ambar_vivo": (1.25, 1.05),
}
for _id, (_ft, _fr) in AJUSTE.items():
    for _p in AURAS[_id]["pecas"]:
        _p["escala"] = round(_p.get("escala", 1.0) * _ft, 3)
        if _p["modo"] == "orbita":
            _p["rx"], _p["rz"] = _p["rx"] * _fr, _p["rz"] * _fr
        elif _p["modo"] == "ancora" and abs(_p["pos"][1]) < 2.8:
            _p["pos"] = (_p["pos"][0] * _fr, _p["pos"][1], _p["pos"][2] * _fr)
    _e = AURAS[_id]["especial"]
    _e["escala"] = round(_e["escala"] * min(_ft, 1.6), 3)


# Rodada de correção (3 Comuns/Incomuns + 6 Raras): material, cor, tamanho e posição por peça.
def _ajustar(aura, filtro, **mudancas):
    for _p in AURAS[aura]["pecas"]:
        if _p["template"] == filtro:
            for _k, _v in mudancas.items():
                _p[_k] = _v(_p) if callable(_v) else _v


_ajustar("fagulha_de_cobre", "caco", material="Neon", escala=lambda p: round(p["escala"] * 0.55, 3))
for _k in range(4):  # mais cacos menores, faiscando em volta
    AURAS["fagulha_de_cobre"]["pecas"].append(dict(template="caco", modo="orbita", rx=1.6 + 0.3 * _k, rz=1.4 + 0.3 * _k, altura=-0.4 + 0.6 * _k, ang=_k * 1.6 + 0.8, vel=0.8 if _k % 2 else -0.7, inclinacao=0.4, cor=_k % 2, material="Neon" if _k % 2 == 0 else "Metal", rigidez=40, atraso=0.6, giro=(90, 70 - 20 * _k, 30), escala=1.0, detalhe=_k >= 2))
_ajustar("fagulha_de_cobre", "filamento", escala=1.8)
for _i, _p in enumerate(AURAS["engrenagem_de_orvalho"]["pecas"]):
    _lado = -1 if _p["pos"][0] < 0 else 1
    _p.update(pos=(_lado * 1.9, _p["pos"][1], 0.1), rot=(0, _lado * 75, 0), material="Neon" if _i == 1 else "Glass", transp=0.3 if _i != 1 else 0.1)
_ajustar("raiz_cintilante", "cipo", material="Neon", cor=0, escala=1.45)
_ajustar("raiz_cintilante", "semente", escala=1.8)
for _i, _p in enumerate(AURAS["fenda_de_porcelana"]["pecas"]):
    _p.update(cor=0 if _i % 2 == 0 else 1, material="SmoothPlastic" if _i % 2 == 0 else "Neon", escala=2.0)
_ajustar("petalas_de_ferrugem", "petala", escala=2.6)
for _i, _p in enumerate(AURAS["petalas_de_ferrugem"]["pecas"]):
    if _i % 2 == 0:
        _p["material"] = "Neon"
_ajustar("sinos_do_crepusculo", "sino", material="Neon", escala=lambda p: round(p["escala"] * 1.7, 3), pos=lambda p: (p["pos"][0] * 1.2, p["pos"][1], 0.1))
_ajustar("sinos_do_crepusculo", "onda", escala=2.0, pos=lambda p: (p["pos"][0] * 1.2, p["pos"][1], 0.1))
_ajustar("marfim_flutuante", "presa", escala=2.1, pos=lambda p: (p["pos"][0] * 1.1, p["pos"][1], -0.1))
_ajustar("lotus_de_gravidade", "lotus", cor=0, material="SmoothPlastic", escala=2.0)
_ajustar("lotus_de_gravidade", "petala_solta", escala=2.0)
_ajustar("solsticio_de_areia", "duna", material="Neon", transp=0.15, escala=2.4, pos=lambda p: (p["pos"][0], p["pos"][1], 0.3))

# ---------------------------------------------------------------- saída


def lua(x):
    if isinstance(x, bool):
        return "true" if x else "false"
    if isinstance(x, (int, float)):
        return ("%.4f" % x).rstrip("0").rstrip(".") if abs(x) > 5e-5 else "0"
    if isinstance(x, str):
        return '"%s"' % x
    if isinstance(x, (tuple, list)):
        return "{ " + ", ".join(lua(v) for v in x) + " }"
    if isinstance(x, dict):
        return "{ " + ", ".join("%s = %s" % (k, lua(v)) for k, v in sorted(x.items())) + " }"
    raise TypeError(x)


def escrever_luau(info):
    linhas = [
        "-- GERADO por assets/auras/originais/source/generate_originais.py — edite lá e rode de novo.",
        "-- Lote inicial das auras originais v2: tamanho/centro das malhas (eixos Roblox) e comportamento.",
        "-- Vetores como tabelas { x, y, z }; graus para rotações. cor = índice em cores (0 = principal).",
        "return {",
    ]
    for aura, cfg in AURAS.items():
        tpl = {nome: {"tamanho": d["tamanho"], "centro": d["centro"]} for (a, nome), d in info.items() if a == aura}
        linhas.append("\t%s = {" % aura)
        linhas.append("\t\tcores = %s," % lua(list(cfg["cores"])))
        linhas.append("\t\ttemplates = {")
        for nome, d in tpl.items():
            linhas.append("\t\t\t%s = %s," % (nome, lua(d)))
        linhas.append("\t\t},")
        linhas.append("\t\tpecas = {")
        for p in cfg["pecas"]:
            linhas.append("\t\t\t%s," % lua(p))
        linhas.append("\t\t},")
        linhas.append("\t\tespecial = %s," % lua(cfg["especial"]))
        linhas.append("\t},")
    linhas += ["}", ""]
    os.makedirs(DIR_LUAU, exist_ok=True)
    with open(os.path.join(DIR_LUAU, "Definicoes.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs, info = {}, {}
    for (aura, nome), fn in PECAS.items():
        for pasta in ("exports", "previews"):
            os.makedirs(os.path.join(DIR_BASE, aura, pasta), exist_ok=True)
        bm = bmesh.new()
        fn(bm, random.Random(hash((aura, nome)) % 10007 if False else len(aura) * 31 + len(nome)))
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(aura + "_" + nome)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        obj = bpy.data.objects.new(nome, me)
        bpy.context.scene.collection.objects.link(obj)
        objs[(aura, nome)] = obj
        xs = [v.co for v in me.vertices]
        lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
        hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
        t, c = hi - lo, (hi + lo) / 2
        info[(aura, nome)] = {"tamanho": (round(t.x, 4), round(t.z, 4), round(t.y, 4)), "centro": (round(c.x, 4), round(c.z, 4), round(-c.y, 4)), "triangulos": len(me.polygons)}
        print("%-22s %-14s %5d tri" % (aura, nome, len(me.polygons)))
    escrever_luau(info)
    for aura, cfg in AURAS.items():
        dados = {
            "auraId": aura,
            "runtimeTemplate": "ReplicatedStorage/AurasOriginais/" + aura,
            "templateFile": "assets/roblox/auras_originais/%s.rbxm" % aura,
            "status": "AWAITING_STUDIO_IMPORT",
            "creatorId": None,
            "revision": 1,
            "axes": "sizes/centers in Roblox axes; FBX axis_forward=-Z, axis_up=Y, 1 unit = 1 stud",
            "pieces": [
                {"name": nome, "triangles": d["triangulos"], "sizeStuds": d["tamanho"], "centerFromPivot": d["centro"], "meshId": None}
                for (a, nome), d in info.items()
                if a == aura
            ],
            "instancesInScene": len(cfg["pecas"]),
        }
        with open(os.path.join(DIR_BASE, aura, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump(dados, f, ensure_ascii=False, indent=2)
            f.write("\n")
    for (aura, nome), obj in objs.items():
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(filepath=os.path.join(DIR_BASE, aura, "exports", nome + ".fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_UNITS", mesh_smooth_type="FACE")
    return objs


# ---------------------------------------------------------------- prévias


def hexcor(h):
    return tuple((int(h[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))


def material(cor, tipo, transp=0.0):
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    if tipo == "Neon":
        b.inputs["Emission Color"].default_value = (*cor, 1)
        b.inputs["Emission Strength"].default_value = 4.0
    elif tipo in ("Glass", "ForceField"):
        b.inputs["Transmission Weight"].default_value = 0.85
        b.inputs["Roughness"].default_value = 0.08
        b.inputs["Emission Color"].default_value = (*cor, 1)
        b.inputs["Emission Strength"].default_value = 0.8 if tipo == "Glass" else 1.6
        b.inputs["Alpha"].default_value = 0.75 if tipo == "ForceField" else 1.0
    else:
        b.inputs["Roughness"].default_value = 0.35
        b.inputs["Specular IOR Level"].default_value = 1.0
        b.inputs["Coat Weight"].default_value = 1.0
    return m


def rb_cf(pos, graus):
    return Matrix.Translation(V(pos[0], pos[1] + 3.0, pos[2])) @ conv_rot(graus)


def conv_rot(graus):
    # rotação Roblox (X, Y, Z em graus) expressa no Blender
    r = rot(*graus).to_3x3()
    p = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox -> Blender
    return (p @ r @ p.inverted()).to_4x4()


def pose(cfg, t):
    """Posição/rotação de cada peça no idle (aproximação do Motor.luau, sem molas)."""
    saida = []
    for p in cfg["pecas"]:
        g = [p.get("rot", (0, 0, 0))[i] + p.get("giro", (0, 0, 0))[i] * t for i in range(3)]
        if "osc" in p:
            e, amp, fr = p["osc"]
            g[e] += amp * math.sin(t * fr * 6.28)
        if p["modo"] == "ancora":
            pos = p["pos"]
        elif p["modo"] == "orbita":
            a = p["ang"] + p["vel"] * t
            pos = (math.cos(a) * p["rx"], p["altura"] + p["inclinacao"] * math.sin(a + 0.8), math.sin(a) * p["rz"])
            g[1] += -math.degrees(a) - (90 if p["vel"] > 0 else -90)
        else:
            a = math.pi / 2 + p["abertura"] * math.sin(t * p["vel"])
            pos = (math.cos(a) * p["raio"], p["altura"], math.sin(a) * p["raio"])
            g[1] += -math.degrees(a) + (180 if math.cos(t * p["vel"]) > 0 else 0)
        saida.append((p, pos, g))
    return saida


def renderizar(objs):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 32
    cena.cycles.device = "CPU"
    cena.view_settings.view_transform = "AgX"
    cena.view_settings.look = "AgX - Punchy"
    mundo = bpy.data.worlds.new("w")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.03, 0.04, 0.1, 1)
    cena.world = mundo
    for o in objs.values():
        o.hide_render = True
    fixa = bpy.data.collections.new("dummy")
    cena.collection.children.link(fixa)
    av = material((0.09, 0.09, 0.11), "x")
    for c, t in (((-0.5, 0, 1), (0.9, 0.9, 2)), ((0.5, 0, 1), (0.9, 0.9, 2)), ((0, 0, 3), (2, 1, 2)), ((-1.5, 0, 3), (0.95, 0.95, 2)), ((1.5, 0, 3), (0.95, 0.95, 2)), ((0, 0, 4.6), (1.2, 1.2, 1.2))):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * t[0] + c[0], v.co.y * t[1] + c[1], v.co.z * t[2] + c[2]))
        me = bpy.data.meshes.new("d")
        bm.to_mesh(me)
        o = bpy.data.objects.new("d", me)
        me.materials.append(av)
        fixa.objects.link(o)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=150)
    me = bpy.data.meshes.new("chao")
    bm.to_mesh(me)
    chao = bpy.data.objects.new("chao", me)
    me.materials.append(material((0.02, 0.025, 0.06), "x"))
    fixa.objects.link(chao)
    for nome, e, pos in (("k", 700, (6, 8, 9)), ("r", 600, (-7, -6, 7))):
        l = bpy.data.lights.new(nome, "AREA")
        l.energy, l.size = e, 6
        ol = bpy.data.objects.new(nome, l)
        ol.location = pos
        ol.rotation_euler = (Vector((0, 0, 3)) - ol.location).to_track_quat("-Z", "Y").to_euler()
        fixa.objects.link(ol)
    cam = bpy.data.cameras.new("c")
    cam.lens = 40
    oc = bpy.data.objects.new("c", cam)
    fixa.objects.link(oc)
    cena.camera = oc
    so = [x for x in os.environ.get("SO", "").split(",") if x]
    for aura, cfg in AURAS.items():
        if so and aura not in so:
            continue
        col = bpy.data.collections.new(aura)
        cena.collection.children.link(col)
        cores = [hexcor(c) for c in cfg["cores"]]
        for p, pos, g in pose(cfg, 2.0):
            fonte = objs[(aura, p["template"])]
            o = bpy.data.objects.new("i", fonte.data.copy())
            o.data.materials.append(material(cores[p["cor"]], p["material"]))
            esc = p.get("escala", 1.0)
            o.matrix_world = rb_cf(pos, g) @ Matrix.Scale(esc, 4) @ (Matrix.Scale(-1, 4, Vector((1, 0, 0))) if p.get("espelhar") else Matrix.Identity(4))
            col.objects.link(o)
        for nome, graus in (("front", 0), ("three_quarter", 50), ("side", 90), ("back", 180)):
            a = math.radians(graus)
            cena.render.resolution_x, cena.render.resolution_y = 520, 680
            oc.location = (math.sin(a) * 13, math.cos(a) * 13, 4.6)
            oc.rotation_euler = (Vector((0, 0, 3.9)) - oc.location).to_track_quat("-Z", "Y").to_euler()
            cena.render.filepath = os.path.join(DIR_BASE, aura, "previews", nome + ".png")
            bpy.ops.render.render(write_still=True)
        print("prévias", aura)
        for o in list(col.objects):
            bpy.data.objects.remove(o)
        bpy.data.collections.remove(col)
    if not so:
        folha()


def folha():
    from PIL import Image

    imgs = [Image.open(os.path.join(DIR_BASE, a, "previews", "three_quarter.png")).convert("RGB") for a in AURAS]
    w, h = imgs[0].size
    f = Image.new("RGB", (w * len(imgs), h))
    for i, im in enumerate(imgs):
        f.paste(im, (i * w, 0))
    f.save(os.path.join(DIR_BASE, "lote_inicial_three_quarter.png"))


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "originais_lote_inicial.blend"), compress=True)
