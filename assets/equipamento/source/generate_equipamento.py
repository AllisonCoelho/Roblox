"""Gera o equipamento (elmo, armadura, manoplas, botas e arma) no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/equipamento/source/generate_equipamento.py            # malhas e dados
    python assets/equipamento/source/generate_equipamento.py --render   # também as prévias

Seis conjuntos, um por mundo do Corredor dos Perdidos (as peças caem das criaturas de lá):
    1 Limiar Partido     pedra lavrada e cristal violeta          · espada de cristal
    2 Bosque de Vidro    casca e folhas de vidro                   · cajado de galho
    3 Dunas de Cinza     obsidiana, lava e ouro velho              · machado de brasa
    4 Maré Suspensa      conchas, coral e água                     · tridente
    5 Catedral Quebrada  mármore e ouro                            · martelo de luz
    6 Coração do Vazio   facetas escuras costuradas por estrelas   · foice estelar

Cada peça é feita num tamanho de referência (partes de um avatar R15 blocado) e o jogo escala
para o corpo de cada jogador (R15 de qualquer tamanho ou R6):
    elmo       centro da cabeça (cabeça 1,2 × 1,2 × 1,2)
    armadura   centro do UpperTorso (2 × 1 × 1,6)
    manopla    centro do LowerArm (1 × 1 × 1,05); _e e _d espelhadas
    bota       sola do pé, no centro (pé 1 × 1 × 0,3)
    arma       empunhadura na mão, lâmina para a frente

Saídas:
    src/client/Mundo/Nexo3D/Dados/equip_*.luau   geometria (formato do kit do Nexo)
    src/shared/Dados/EquipamentoVisual.luau      malhas de cada peça (gerado)
    assets/equipamento/source/equipamento.blend
    assets/equipamento/previews/*.jpg            renders (NÃO são prints do Roblox)
"""

import base64
import math
import os
import random
import struct
import sys

sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "assets", "nexo", "source"))

import bpy  # noqa: E402
import bmesh  # noqa: E402

import generate_nexo as kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Nexo3D", "Dados")
ARQ_VISUAL = os.path.join(RAIZ, "src", "shared", "Dados", "EquipamentoVisual.luau")
DIR_PREV = os.path.join(RAIZ, "assets", "equipamento", "previews")
DIR_SRC = os.path.join(RAIZ, "assets", "equipamento", "source")

T = Matrix.Translation
PRETO = (0.03, 0.025, 0.04)
BRANCO = (1.0, 1.0, 1.0)


def R(graus, eixo):
    return Matrix.Rotation(math.radians(graus), 4, eixo)


def montar(partes):
    bm = kit.novo_bm()
    for item in partes:
        if isinstance(item, tuple):
            kit.juntar(bm, item[0], item[1])
        else:
            kit.juntar(bm, item)
    return bm


def bx(c, s, cor, bisel=0.05, rot=None):
    bm = kit.bloco(s[0], s[1], s[2], random.Random(1), cor, chanfro=bisel, tremor=0.0, tinta=1.0)
    m = T(c) @ (rot if rot is not None else Matrix.Identity(4))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
    return bm


def ponta(base, topo, largura, cor):
    return kit.espinho(base, topo, largura, cor)


def cristal(c, escala, cor, semente=1, rot=None):
    rng = random.Random(semente)
    pts = [(x * escala, y * escala, (z + 6.0) * escala) for x, y, z in kit.pontos_cristal(rng)]
    bm = kit.casco(pts, cor, 1.0, gradiente=(0, 12 * escala, kit.misturar(cor, PRETO, 0.3), kit.misturar(cor, BRANCO, 0.35)))
    bmesh.ops.transform(bm, matrix=T(c) @ (rot if rot is not None else Matrix.Identity(4)), verts=bm.verts[:])
    return bm


def cilindro(c, raio, altura, cor, lados=12, rot=None):
    bm = kit.torno([(raio, -altura / 2), (raio, altura / 2)], lados, cor, random.Random(2), tinta=1.0)
    bmesh.ops.transform(bm, matrix=T(c) @ (rot if rot is not None else Matrix.Identity(4)), verts=bm.verts[:])
    return bm


def espelhar(bm):
    bmesh.ops.scale(bm, vec=(-1, 1, 1), verts=bm.verts[:])
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    return bm


# ---------------------------------------------------------------- temas

TEMAS = [
    {"id": "limiar", "metal": (0.58, 0.56, 0.70), "escuro": (0.36, 0.34, 0.48), "detalhe": (0.75, 0.62, 1.0), "brilho": (0.70, 0.48, 1.0), "material": "Slate"},
    {"id": "bosque", "metal": (0.62, 0.42, 0.26), "escuro": (0.42, 0.28, 0.17), "detalhe": (0.40, 1.0, 0.82), "brilho": (0.45, 1.0, 0.75), "material": "Wood"},
    {"id": "dunas", "metal": (0.22, 0.18, 0.20), "escuro": (0.14, 0.11, 0.13), "detalhe": (0.85, 0.66, 0.32), "brilho": (1.0, 0.48, 0.12), "material": "SmoothPlastic"},
    {"id": "mare", "metal": (0.32, 0.58, 0.78), "escuro": (0.20, 0.36, 0.55), "detalhe": (0.98, 0.86, 0.80), "brilho": (0.35, 0.95, 1.0), "material": "SmoothPlastic"},
    {"id": "catedral", "metal": (0.90, 0.88, 0.94), "escuro": (0.72, 0.70, 0.78), "detalhe": (1.0, 0.80, 0.32), "brilho": (1.0, 0.86, 0.45), "material": "Marble"},
    {"id": "vazio", "metal": (0.20, 0.13, 0.32), "escuro": (0.12, 0.08, 0.20), "detalhe": (0.55, 0.40, 0.85), "brilho": (0.95, 0.38, 1.0), "material": "SmoothPlastic"},
]


def enfeite_topo(t, i, c, escala=1.0):
    """Enfeite característico do conjunto (cristais, folhas, chifres, conchas, asinhas, estrelas)."""
    base, brilho = [], []
    x, y, z = c
    if i == 0:
        brilho.append(cristal((x, y, z), 0.07 * escala, t["detalhe"], 3))
        brilho.append(cristal((x + 0.25 * escala, y - 0.1, z - 0.05), 0.045 * escala, t["detalhe"], 4, R(25, "Y")))
        brilho.append(cristal((x - 0.25 * escala, y - 0.1, z - 0.05), 0.045 * escala, t["detalhe"], 5, R(-25, "Y")))
    elif i == 1:
        for k, a in enumerate((-35, 0, 35)):
            base.append(kit.chapa([(x, y, z), (x + math.sin(math.radians(a)) * 0.55 * escala, y - 0.15, z + 0.55 * escala), (x + math.sin(math.radians(a + 18)) * 0.25 * escala, y, z + 0.25 * escala)], t["detalhe"], 1.0, dupla=True))
    elif i == 2:
        for lado in (-1, 1):
            base.append(ponta((x + lado * 0.35 * escala, y, z), (x + lado * 0.75 * escala, y + 0.1, z + 0.55 * escala), 0.18 * escala, t["detalhe"]))
        brilho.append(bx((x, y + 0.02, z + 0.05), (0.18 * escala, 0.06, 0.18 * escala), t["brilho"], 0.02, R(45, "Y")))
    elif i == 3:
        perfil = [(0.02, 0), (0.22 * escala, 0.06), (0.3 * escala, 0.2 * escala), (0.18 * escala, 0.42 * escala), (0.02, 0.5 * escala)]
        concha = kit.torno(perfil, 8, t["detalhe"], random.Random(6), estrela=0.25)
        bmesh.ops.transform(concha, matrix=T((x, y, z)), verts=concha.verts[:])
        base.append(concha)
        brilho.append(bx((x, y + 0.25 * escala, z + 0.2 * escala), (0.1 * escala,) * 3, t["brilho"], 0.03))
    elif i == 4:
        for lado in (-1, 1):
            for k in range(3):
                comp = (0.5 - 0.1 * k) * escala
                a = math.radians(30 + 18 * k)
                base.append(bx((x + lado * (0.25 * escala + math.cos(a) * comp / 2), y - 0.05, z + math.sin(a) * comp / 2 + 0.05 * k), (comp, 0.08, 0.14 * escala), kit.misturar(BRANCO, t["detalhe"], 0.15 * k), 0.02, R(-lado * math.degrees(a), "Y")))
        brilho.append(bx((x, y + 0.02, z + 0.05), (0.16 * escala, 0.06, 0.16 * escala), t["brilho"], 0.02, R(45, "Y")))
    else:
        for k in range(4):
            a = 2 * math.pi * k / 4 + 0.4
            brilho.append(bx((x + math.cos(a) * 0.3 * escala, y + math.sin(a) * 0.12, z + 0.15 * escala * (k % 2)), (0.09 * escala, 0.05, 0.09 * escala), (0.95, 0.9, 1.0), 0.01, R(45, "Y")))
        brilho.append(bx((x, y + 0.02, z + 0.25 * escala), (0.2 * escala, 0.06, 0.2 * escala), t["brilho"], 0.02, R(45, "Y")))
    return base, brilho


# ---------------------------------------------------------------- peças


def elmo(t, i):
    """Elmo aberto na frente (o rosto do avatar aparece), com o enfeite do conjunto no alto."""
    m, e = t["metal"], t["escuro"]
    base = [
        bx((0, -0.02, 0.52), (1.42, 1.38, 0.42), m),
        bx((0, -0.6, 0.02), (1.42, 0.22, 1.25), e),
        bx((-0.64, 0.0, 0.0), (0.18, 1.3, 1.08), m),
        bx((0.64, 0.0, 0.0), (0.18, 1.3, 1.08), m),
        bx((0, 0.64, 0.38), (1.42, 0.18, 0.24), e),
        bx((0, 0.66, 0.24), (0.24, 0.16, 0.55), m),
        bx((-0.64, 0.42, -0.42), (0.2, 0.5, 0.24), e),
        bx((0.64, 0.42, -0.42), (0.2, 0.5, 0.24), e),
    ]
    brilho = [bx((0, 0.74, 0.38), (0.9, 0.06, 0.06), t["brilho"], 0.01)]
    b2, br2 = enfeite_topo(t, i, (0, 0.05, 0.74), 1.0)
    return montar(base + b2), montar(brilho + br2)


def armadura(t, i):
    """Peitoral e costas, ombreiras largas, cinto e o emblema do conjunto no peito."""
    m, e = t["metal"], t["escuro"]
    base = [
        bx((0, 0.56, 0.1), (2.16, 0.18, 1.45), m),
        bx((0, -0.56, 0.1), (2.16, 0.18, 1.45), e),
        bx((-1.06, 0, 0.1), (0.14, 1.1, 1.45), e),
        bx((1.06, 0, 0.1), (0.14, 1.1, 1.45), e),
        bx((0, 0, -0.72), (2.22, 1.2, 0.24), e),
        bx((0, 0.64, 0.25), (0.8, 0.08, 0.9), kit.misturar(m, BRANCO, 0.15)),
    ]
    for lado in (-1, 1):
        base.append(bx((lado * 1.28, 0, 0.72), (0.95, 1.25, 0.32), m, 0.08))
        base.append(bx((lado * 1.42, 0, 0.5), (0.7, 1.15, 0.22), e, 0.06))
    brilho = [bx((0, 0.7, 0.3), (0.32, 0.05, 0.32), t["brilho"], 0.02, R(45, "Y"))]
    for lado in (-1, 1):
        b2, br2 = enfeite_topo(t, i, (lado * 1.3, 0, 0.88), 0.7)
        base += b2
        brilho += br2
    brilho.append(bx((0, 0.62, -0.72), (0.3, 0.06, 0.16), t["brilho"], 0.02))
    return montar(base), montar(brilho)


def manopla(t, i):
    """Manopla direita (a esquerda é o espelho): punho reforçado, aro no antebraço e um espinho."""
    m, e = t["metal"], t["escuro"]
    base = [
        bx((0, 0, -0.15), (1.14, 1.14, 0.85), m),
        bx((0, 0, 0.38), (1.24, 1.24, 0.2), e),
        bx((0, 0, -0.62), (1.18, 1.18, 0.16), e),
        bx((0.6, 0, -0.1), (0.1, 0.7, 0.6), kit.misturar(m, BRANCO, 0.12)),
    ]
    brilho = [bx((0, 0.6, -0.1), (0.24, 0.05, 0.24), t["brilho"], 0.02, R(45, "Y"))]
    if i in (0, 2, 5):
        base.append(ponta((0.58, 0, 0.05), (0.98, 0, 0.3), 0.2, t["detalhe"]))
    elif i == 1:
        base.append(kit.chapa([(0.58, 0, -0.2), (1.0, 0.05, 0.25), (0.62, 0, 0.15)], t["detalhe"], 1.0, dupla=True))
    elif i == 3:
        base.append(bx((0.62, 0, -0.1), (0.12, 0.5, 0.5), t["detalhe"], 0.08, R(45, "X")))
    else:
        base.append(bx((0.62, 0, 0.2), (0.1, 0.45, 0.2), t["detalhe"]))
    return montar(base), montar(brilho)


def bota(t, i):
    """Bota direita (a esquerda é o espelho): biqueira, caneleira e aro no alto. Origem na sola."""
    m, e = t["metal"], t["escuro"]
    base = [
        bx((0, 0.12, 0.17), (1.1, 1.35, 0.34), e),
        bx((0, 0.62, 0.22), (1.0, 0.3, 0.3), m),
        bx((0, 0, 0.75), (1.12, 1.12, 0.85), m),
        bx((0, 0.0, 1.25), (1.2, 1.2, 0.18), e),
        bx((0, 0.6, 0.85), (0.5, 0.1, 0.65), kit.misturar(m, BRANCO, 0.12)),
    ]
    brilho = [bx((0, 0.66, 0.9), (0.18, 0.05, 0.18), t["brilho"], 0.02, R(45, "Y"))]
    if i == 4:
        for k in range(2):
            base.append(bx((0.58, -0.1 - 0.12 * k, 1.0 + 0.1 * k), (0.06, 0.5 - 0.1 * k, 0.12), BRANCO, 0.02, R(-30, "X")))
    elif i == 2:
        base.append(ponta((0.56, 0, 1.0), (0.85, -0.2, 1.3), 0.14, t["detalhe"]))
    return montar(base), montar(brilho)


def arma(t, i):
    """Arma segurada na mão direita: empunhadura na origem, a ponta para a frente (+Y)."""
    m, e, d, b = t["metal"], t["escuro"], t["detalhe"], t["brilho"]
    base, brilho = [], []
    cabo = lambda comp: bx((0, comp / 2 - 0.3, 0), (0.16, comp, 0.16), e, 0.03)  # noqa: E731
    if i == 0:  # espada de cristal
        base += [cabo(0.9), bx((0, 0.62, 0), (0.9, 0.16, 0.2), m)]
        brilho.append(cristal((0, 0.7, 0), 0.06, b, 9, R(-90, "X") @ T((0, 0, 0))))
        bl = kit.casco([(-0.16, 0.7, -0.05), (0.16, 0.7, -0.05), (-0.16, 0.7, 0.05), (0.16, 0.7, 0.05), (-0.12, 2.6, 0), (0.12, 2.6, 0), (0, 3.0, 0)], d, 1.0)
        base.append(bl)
    elif i == 1:  # cajado de galho com folha-cristal
        base += [bx((0, 0.9, 0), (0.18, 2.6, 0.18), m, 0.04)]
        for lado in (-1, 1):
            base.append(ponta((0, 2.1, 0), (lado * 0.35, 2.55, 0.15), 0.12, m))
        brilho.append(cristal((0, 2.25, 0), 0.07, d, 10, R(-90, "X")))
    elif i == 2:  # machado de brasa
        base += [bx((0, 0.6, 0), (0.17, 2.0, 0.17), e, 0.03)]
        cabeca = kit.casco([(0.05, 1.3, -0.06), (0.05, 1.8, -0.06), (0.05, 1.3, 0.06), (0.05, 1.8, 0.06), (0.75, 1.1, 0), (0.85, 2.0, 0), (0.6, 1.55, 0)], m, 1.0)
        base.append(cabeca)
        brilho.append(kit.fita3d([(0.82, 1.15, 0.03), (0.92, 1.55, 0.03), (0.86, 1.95, 0.03)], 0.06, (0, 0, 1), b))
        brilho.append(kit.fita3d([(0.82, 1.15, -0.03), (0.92, 1.55, -0.03), (0.86, 1.95, -0.03)], 0.06, (0, 0, -1), b))
    elif i == 3:  # tridente
        base += [bx((0, 1.0, 0), (0.14, 2.8, 0.14), e, 0.03), bx((0, 2.35, 0), (0.75, 0.14, 0.14), m, 0.03)]
        for x in (-0.32, 0, 0.32):
            base.append(ponta((x, 2.35, 0), (x, 2.95 if x == 0 else 2.75, 0), 0.14, d))
        brilho.append(bx((0, 2.35, 0), (0.16, 0.16, 0.16), b, 0.04))
    elif i == 4:  # martelo de luz
        base += [bx((0, 0.7, 0), (0.18, 2.1, 0.18), e, 0.03), bx((0, 1.9, 0), (0.95, 0.55, 0.55), m, 0.06)]
        for lado in (-1, 1):
            base.append(bx((lado * 0.5, 1.9, 0), (0.08, 0.6, 0.6), d, 0.02))
        brilho.append(bx((0, 1.9, 0.29), (0.25, 0.25, 0.04), b, 0.02, R(45, "Z")))
    else:  # foice estelar
        base += [bx((0, 1.0, 0), (0.15, 2.8, 0.15), e, 0.03)]
        lam = [(0, 2.3, 0), (0.45, 2.55, 0), (0.9, 2.45, 0), (1.2, 2.1, 0), (1.25, 1.75, 0)]
        brilho.append(kit.fita3d(lam, 0.28, (0, 0, 1), b))
        brilho.append(kit.fita3d(lam, 0.28, (0, 0, -1), b))
        base.append(bx((0, 2.3, 0), (0.26, 0.26, 0.26), d, 0.04, R(45, "Z")))
    return montar(base), montar(brilho)


# ---------------------------------------------------------------- acessórios (minimalistas)
#
# Peças pequenas para quem prefere um visual leve, com ou sem armadura:
#    colar     no UpperTorso: corrente de contas em volta do pescoço e um pingente do conjunto
#    manto     no UpperTorso: fecho nos ombros (fixo) + três faixas articuladas (manto_s1..s3)
#              que o jogo balança com o movimento. Cada faixa tem a origem na sua dobradiça
#    bracelete no pulso esquerdo (a mão direita segura a arma): aro e a pedra para fora
#    aureola   acima da cabeça: aro de luz com os enfeites do conjunto; o jogo faz girar devagar

MANTO_TOPO = (0.0, -0.56, 0.78)  # dobradiça da primeira faixa (Blender, em relação ao torso)
MANTO_FAIXAS = (0.9, 1.0, 1.1)  # comprimento de cada faixa
MANTO_LARGURA = (1.75, 1.95, 2.1, 2.25)  # largura nas bordas de cada faixa (de cima para baixo)


def contas(caminho, tam, cor, passo=0.085):
    """Contas pequenas (cubos girados) ao longo de um caminho de pontos 3D."""
    saida = []
    pts = [Vector(q) for q in caminho]
    resto = 0.0
    for a, b in zip(pts, pts[1:]):
        d = (b - a).length
        k = resto
        while k < d:
            c = a + (b - a) * (k / d)
            saida.append(bx(tuple(c), (tam, tam, tam), cor, 0.0, R(45, "Z") @ R(35, "X")))
            k += passo
        resto = k - d
    return saida


def pingente(t, i, c, escala=1.0):
    """Pingente/joia do conjunto (vai na camada de brilho, menos a moldura)."""
    base, brilho = [], []
    x, y, z = c
    d, b = t["detalhe"], t["brilho"]
    if i == 0:  # lasca de cristal pendurada
        brilho.append(cristal((x, y, z - 0.2 * escala), 0.035 * escala, b, 21, R(180, "Y")))
    elif i == 1:  # folha de vidro
        brilho.append(kit.chapa([(x, y, z), (x + 0.12 * escala, y, z - 0.12 * escala), (x, y, z - 0.32 * escala), (x - 0.12 * escala, y, z - 0.12 * escala)], b, 1.0, dupla=True))
    elif i == 2:  # brasa em losango com moldura de ouro velho
        base.append(bx((x, y - 0.01, z - 0.12 * escala), (0.2 * escala, 0.04, 0.2 * escala), d, 0.01, R(45, "Y")))
        brilho.append(bx((x, y + 0.02, z - 0.12 * escala), (0.12 * escala, 0.05, 0.12 * escala), b, 0.01, R(45, "Y")))
    elif i == 3:  # pérola
        perola = kit.torno([(0.001, -0.08 * escala), (0.06 * escala, -0.06 * escala), (0.085 * escala, 0), (0.06 * escala, 0.06 * escala), (0.001, 0.08 * escala)], 10, (0.97, 0.95, 1.0), random.Random(7), tinta=1.0)
        bmesh.ops.transform(perola, matrix=T((x, y + 0.03, z - 0.1 * escala)), verts=perola.verts[:])
        base.append(perola)
        brilho.append(bx((x, y + 0.02, z - 0.22 * escala), (0.05 * escala,) * 3, b, 0.0, R(45, "Y")))
    elif i == 4:  # medalha de ouro com a pedra no meio
        disco = cilindro((x, y, z - 0.15 * escala), 0.13 * escala, 0.04, d, 12, R(90, "X"))
        base.append(disco)
        brilho.append(bx((x, y + 0.03, z - 0.15 * escala), (0.09 * escala, 0.04, 0.09 * escala), b, 0.01, R(45, "Y")))
    else:  # estrela de quatro pontas
        for a in (0, 90, 180, 270):
            r = math.radians(a)
            brilho.append(ponta((x, y + 0.02, z - 0.14 * escala), (x + math.cos(r) * 0.16 * escala, y + 0.02, z - 0.14 * escala + math.sin(r) * 0.16 * escala), 0.06 * escala, b))
        brilho.append(bx((x, y + 0.02, z - 0.14 * escala), (0.06 * escala, 0.05, 0.06 * escala), (1.0, 0.95, 1.0), 0.0, R(45, "Y")))
    return base, brilho


def colar(t, i):
    """Corrente de contas por cima dos ombros e um pingente no peito."""
    cor = kit.misturar(t["detalhe"], BRANCO, 0.15) if i != 5 else (0.75, 0.68, 0.95)
    if i in (1, 2):
        cor = t["metal"] if i == 1 else (0.88, 0.70, 0.36)
    arco = [(math.sin(a) * 0.48, -math.cos(a) * 0.4 + 0.08, 0.83) for a in [math.radians(-120 + 12 * k) for k in range(21)]]
    frente_d = (0.42, 0.53, 0.78)
    frente_e = (-0.42, 0.53, 0.78)
    fundo = (0.0, 0.56, 0.36)
    caminho = [frente_e] + arco + [frente_d]
    base = contas(caminho, 0.07, cor)
    base += contas([frente_d, (0.18, 0.555, 0.5), fundo], 0.065, cor)
    base += contas([frente_e, (-0.18, 0.555, 0.5), fundo], 0.065, cor)
    b2, br2 = pingente(t, i, (0, 0.58, 0.36))
    return montar(base + b2), montar(br2)


def manto_fecho(t, i):
    """Parte fixa do manto: faixa em cima dos ombros e dois fechos com a pedra do conjunto."""
    m, e = t["metal"], t["escuro"]
    tecido = kit.misturar(t["brilho"], e, 0.55)
    base = [
        bx((0, -0.52, 0.8), (1.8, 0.12, 0.12), tecido, 0.02),
        bx((-0.72, -0.05, 0.84), (0.26, 1.0, 0.08), tecido, 0.02),
        bx((0.72, -0.05, 0.84), (0.26, 1.0, 0.08), tecido, 0.02),
        bx((-0.72, 0.53, 0.66), (0.24, 0.06, 0.3), tecido, 0.02),
        bx((0.72, 0.53, 0.66), (0.24, 0.06, 0.3), tecido, 0.02),
        bx((-0.72, 0.56, 0.62), (0.2, 0.05, 0.2), m, 0.02, R(45, "Y")),
        bx((0.72, 0.56, 0.62), (0.2, 0.05, 0.2), m, 0.02, R(45, "Y")),
    ]
    brilho = [
        bx((-0.72, 0.59, 0.62), (0.1, 0.04, 0.1), t["brilho"], 0.0, R(45, "Y")),
        bx((0.72, 0.59, 0.62), (0.1, 0.04, 0.1), t["brilho"], 0.0, R(45, "Y")),
    ]
    return montar(base), montar(brilho)


def manto_faixa(t, i, k):
    """Faixa k (0, 1, 2) do manto, com a dobradiça na origem e caindo para -Z.

    Tecido levemente curvo (o meio afasta das costas), avesso escuro e, na última faixa, a
    barra com a cor de brilho do conjunto e o recorte característico."""
    comp = MANTO_FAIXAS[k]
    w0, w1 = MANTO_LARGURA[k], MANTO_LARGURA[k + 1]
    tecido = kit.misturar(t["brilho"], t["escuro"], 0.55)
    avesso = kit.misturar(tecido, PRETO, 0.45)
    colunas = 6
    bm = kit.novo_bm()
    frente, tras = [], []
    for linha, (z, w) in enumerate(((0.0, w0), (-comp, w1))):
        f, tr = [], []
        for c in range(colunas + 1):
            u = c / colunas - 0.5
            curva = -0.08 * (1 - (2 * u) ** 2)  # o meio do manto fica mais para trás
            f.append(bm.verts.new((u * w, curva, z)))
            tr.append(bm.verts.new((u * w, curva - 0.05, z)))
        frente.append(f)
        tras.append(tr)
    for c in range(colunas):
        bm.faces.new((frente[0][c], frente[1][c], frente[1][c + 1], frente[0][c + 1]))
        bm.faces.new((tras[0][c], tras[0][c + 1], tras[1][c + 1], tras[1][c]))
    for linha in (0, 1):
        for c in range(colunas):
            a, b = frente[linha][c], frente[linha][c + 1]
            ta, tb = tras[linha][c], tras[linha][c + 1]
            bm.faces.new((a, b, tb, ta) if linha == 0 else (b, a, ta, tb))
    for c, d in ((0, 0), (colunas, colunas)):
        if c == 0:
            bm.faces.new((frente[0][c], tras[0][c], tras[1][c], frente[1][c]))
        else:
            bm.faces.new((frente[0][c], frente[1][c], tras[1][c], tras[0][c]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    kit.pintar(bm, avesso, 1.0, topo_claro=0.0)
    # o lado de fora (Y negativo) leva a cor do tecido; o de dentro fica com o avesso
    camada = bm.loops.layers.color["Col"]
    for face in bm.faces:
        cor = tecido if face.normal.y < -0.3 else avesso
        for loop in face.loops:
            loop[camada] = (*cor, 1.0)
    base = [bm]
    brilho = []
    if k == 0:
        # emblema do conjunto entre as omoplatas
        b2, br2 = enfeite_topo(t, i, (0, 0.16, -0.5), 0.45)
        for x in b2 + br2:
            bmesh.ops.transform(x, matrix=R(180, "Z"), verts=x.verts[:])
        base += b2
        brilho += br2
    if k == 2:
        barra = []
        for c in range(colunas + 1):
            u = c / colunas - 0.5
            curva = -0.08 * (1 - (2 * u) ** 2)
            barra.append((u * w1 * 0.98, curva - 0.065, -comp + 0.1))
        brilho.append(kit.fita3d(barra, 0.09, (0, -1, 0), t["brilho"]))
        # recorte da barra: pontas (limiar/dunas/vazio), folhas (bosque), ondas (maré), franja dourada (catedral)
        for c in range(5):
            u = (c + 0.5) / 5 - 0.5
            x = u * w1 * 0.9
            curva = -0.08 * (1 - (2 * u) ** 2)
            if i == 3:
                base.append(bx((x, curva - 0.025, -comp - 0.04), (0.28, 0.04, 0.1), tecido, 0.03, R(25, "Y")))
            elif i == 4:
                base.append(bx((x, curva - 0.025, -comp - 0.08), (0.06, 0.04, 0.18), t["detalhe"], 0.0))
            else:
                base.append(ponta((x, curva - 0.025, -comp + 0.02), (x, curva - 0.025, -comp - 0.2), 0.18, tecido))
    return montar(base), montar(brilho)


def bracelete(t, i):
    """Bracelete no pulso esquerdo (origem no centro do LowerArm, aro na altura do pulso) e a
    pedra do conjunto virada para fora (-X)."""
    m, d, b = t["metal"], t["detalhe"], t["brilho"]
    aro = kit.misturar(d, BRANCO, 0.1) if i in (2, 4) else kit.misturar(m, BRANCO, 0.15)
    z = -0.36
    base = [
        bx((0, 0.53, z), (1.12, 0.08, 0.16), aro, 0.01),
        bx((0, -0.53, z), (1.12, 0.08, 0.16), aro, 0.01),
        bx((0.53, 0, z), (0.08, 1.12, 0.16), aro, 0.01),
        bx((-0.53, 0, z), (0.08, 1.12, 0.16), aro, 0.01),
        bx((-0.58, 0, z), (0.06, 0.36, 0.26), kit.misturar(aro, PRETO, 0.2), 0.02),
    ]
    brilho = [bx((0, 0.575, z), (0.7, 0.02, 0.035), b, 0.0), bx((0, -0.575, z), (0.7, 0.02, 0.035), b, 0.0)]
    if i == 0:
        brilho.append(cristal((-0.62, 0, z - 0.07), 0.022, b, 31, R(90, "Y")))
    elif i == 3:
        perola = kit.torno([(0.001, -0.11), (0.09, -0.08), (0.11, 0), (0.09, 0.08), (0.001, 0.11)], 10, (0.97, 0.95, 1.0), random.Random(8), tinta=1.0)
        bmesh.ops.transform(perola, matrix=T((-0.66, 0, z)) @ R(90, "Y"), verts=perola.verts[:])
        base.append(perola)
    elif i == 5:
        for a in (0, 90, 180, 270):
            r = math.radians(a)
            brilho.append(ponta((-0.62, 0, z), (-0.62, math.cos(r) * 0.17, z + math.sin(r) * 0.17), 0.06, b))
    else:
        brilho.append(bx((-0.63, 0, z), (0.08, 0.18, 0.18), b, 0.01, R(45, "X")))
    return montar(base), montar(brilho)


def aureola(t, i):
    """Aro de luz acima da cabeça (centro a 1,05 do centro da cabeça), levemente inclinado."""
    b, d = t["brilho"], t["detalhe"]
    raio, n = 0.48, 20
    brilho, base = [], []
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        comp = 2 * math.pi * raio / n * 1.08
        brilho.append(bx((math.cos(a) * raio, math.sin(a) * raio, 0), (0.07, comp, 0.06), b, 0.0, R(math.degrees(a), "Z")))
    for k in range(6 if i != 4 else 12):
        a = 2 * math.pi * k / (6 if i != 4 else 12)
        x, y = math.cos(a) * raio, math.sin(a) * raio
        if i == 0:
            if k % 2 == 0:
                base.append(cristal((x, y, 0.02), 0.022, d, 40 + k))
        elif i == 1:
            base.append(kit.chapa([(x, y, 0), (x * 1.25, y * 1.25, 0.12), (x * 1.05, y * 1.05, 0.2)], d, 1.0, dupla=True))
        elif i == 2:
            brilho.append(ponta((x, y, 0.02), (x * 1.05, y * 1.05, 0.22 + 0.06 * (k % 2)), 0.07, kit.misturar(b, (1.0, 0.9, 0.4), 0.4)))
        elif i == 3:
            base.append(bx((x * 1.0, y * 1.0, 0.06), (0.07, 0.07, 0.07), (0.97, 0.95, 1.0), 0.02))
        elif i == 4:
            brilho.append(ponta((x * 1.05, y * 1.05, 0), (x * 1.35, y * 1.35, 0), 0.05, kit.misturar(b, BRANCO, 0.3)))
        else:
            if k % 2 == 0:
                brilho.append(bx((x * 1.3, y * 1.3, 0.08 * (k % 3)), (0.08, 0.08, 0.08), (1.0, 0.95, 1.0), 0.0, R(45, "Z") @ R(35, "X")))
    tudo_b, tudo_l = montar(base), montar(brilho)
    for bm in (tudo_b, tudo_l):
        bmesh.ops.transform(bm, matrix=T((0, 0, 1.05)) @ R(-12, "X"), verts=bm.verts[:])
    return tudo_b, tudo_l


ACESSORIOS = [
    ("colar", colar),
    ("manto", manto_fecho),
    ("manto_s1", lambda t, i: manto_faixa(t, i, 0)),
    ("manto_s2", lambda t, i: manto_faixa(t, i, 1)),
    ("manto_s3", lambda t, i: manto_faixa(t, i, 2)),
    ("bracelete", bracelete),
    ("aureola", aureola),
]


PECAS = [("elmo", elmo), ("armadura", armadura), ("manopla", manopla), ("bota", bota), ("arma", arma)] + ACESSORIOS


# ---------------------------------------------------------------- escrita


def escrever_malha(nome, obj):
    pos, cor, tris = kit.dados_da_malha(obj)
    assert len(pos) < 65536, nome
    minimo = [min(p[k] for p in pos) for k in range(3)]
    maximo = [max(p[k] for p in pos) for k in range(3)]
    tamanho = [max(maximo[k] - minimo[k], 1e-4) for k in range(3)]
    dados = bytearray()
    for p in pos:
        dados += struct.pack("<3H", *(int(round((p[k] - minimo[k]) / tamanho[k] * 65535)) for k in range(3)))
    for c in cor:
        dados += struct.pack("<3B", *c)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    pedacos = [texto[k : k + 4000] for k in range(0, len(texto), 4000)]
    linhas = [
        "-- GERADO por assets/equipamento/source/generate_equipamento.py. Não editar à mão.",
        "-- Peça de equipamento (mesmo formato do kit do Nexo).",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ]
    linhas += ['\t\t"%s",' % p for p in pedacos]
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(tris)


# Boneco R15 blocado de referência (só para as prévias): peça -> (centro, tamanho), em studs
BONECO = {
    "Head": ((0, 0, 4.6), (1.2, 1.2, 1.2)),
    "UpperTorso": ((0, 0, 3.2), (2.0, 1.0, 1.6)),
    "LowerTorso": ((0, 0, 2.2), (2.0, 1.0, 0.4)),
    "RightUpperArm": ((1.5, 0, 3.45), (1.0, 1.0, 1.1)),
    "RightLowerArm": ((1.5, 0, 2.37), (1.0, 1.0, 1.05)),
    "RightHand": ((1.5, 0, 1.7), (1.0, 1.0, 0.3)),
    "LeftUpperArm": ((-1.5, 0, 3.45), (1.0, 1.0, 1.1)),
    "LeftLowerArm": ((-1.5, 0, 2.37), (1.0, 1.0, 1.05)),
    "LeftHand": ((-1.5, 0, 1.7), (1.0, 1.0, 0.3)),
    "RightUpperLeg": ((0.5, 0, 1.57), (1.0, 1.0, 0.85)),
    "RightLowerLeg": ((0.5, 0, 0.72), (1.0, 1.0, 0.85)),
    "RightFoot": ((0.5, 0, 0.15), (1.0, 1.0, 0.3)),
    "LeftUpperLeg": ((-0.5, 0, 1.57), (1.0, 1.0, 0.85)),
    "LeftLowerLeg": ((-0.5, 0, 0.72), (1.0, 1.0, 0.85)),
    "LeftFoot": ((-0.5, 0, 0.15), (1.0, 1.0, 0.3)),
}
# onde cada peça fica no boneco (mesma regra do jogo, com escala 1)
def _manto_preview():
    torso = T((0, 0, 3.2))
    m = torso @ T(MANTO_TOPO)
    saida = {}
    for k, (comp, ang) in enumerate(zip(MANTO_FAIXAS, (6, 7, 9))):
        m = m @ R(-ang, "X")
        saida["manto_s%d" % (k + 1)] = [(m.copy(), "")]
        m = m @ T((0, 0, -comp))
    return saida


ENCAIXE = {
    "elmo": [(T((0, 0, 4.6)), "")],
    "armadura": [(T((0, 0, 3.2)), "")],
    "manopla": [(T((1.5, 0, 2.37)), "_d"), (T((-1.5, 0, 2.37)), "_e")],
    "bota": [(T((0.5, 0, 0.0)), "_d"), (T((-0.5, 0, 0.0)), "_e")],
    "arma": [(T((1.5, 0, 1.6)), "")],
    "colar": [(T((0, 0, 3.2)), "")],
    "manto": [(T((0, 0, 3.2)), "")],
    "bracelete": [(T((-1.5, 0, 2.37)), "")],
    "aureola": [(T((0, 0, 4.6)), "")],
}
ENCAIXE.update(_manto_preview())
GRUPO_ARMADURA = ("elmo", "armadura", "manopla", "bota", "arma")


def main():
    os.makedirs(DIR_PREV, exist_ok=True)
    os.makedirs(DIR_SRC, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materiais = {
        "base": kit.criar_material("Equip_Base", rugosidade=0.45, metalico=0.25),
        "brilho": kit.criar_material("Equip_Brilho", emissao=5.0),
    }
    linhas = [
        "-- GERADO por assets/equipamento/source/generate_equipamento.py. Não editar à mão.",
        "-- Malhas de cada peça por conjunto. Peças dos lados (manopla, bota) têm _e e _d.",
        "-- Espaço de cada peça: o da parte do corpo de referência (ver o gerador).",
        "return {",
    ]
    total = 0
    objetos = {}
    for i, t in enumerate(TEMAS):
        linhas.append("\t%s = {" % t["id"])
        for peca, fn in PECAS:
            base_bm, brilho_bm = fn(t, i)
            lados = [("", base_bm, brilho_bm)]
            if peca in ("manopla", "bota"):
                b2 = base_bm.copy()
                l2 = brilho_bm.copy()
                lados = [("_d", base_bm, brilho_bm), ("_e", espelhar(b2), espelhar(l2))]
            for sufixo, bb, lb in lados:
                camadas = []
                for camada, bm, material in (("base", bb, t["material"]), ("brilho", lb, "Neon")):
                    if len(bm.faces) == 0:
                        continue
                    nome = "equip_%s_%s%s%s" % (t["id"], peca, sufixo, "" if camada == "base" else "_brilho")
                    obj = kit.registrar(nome, bm, materiais[camada])
                    objetos[nome] = obj
                    total += escrever_malha(nome, obj)
                    camadas.append('{ malha = "%s", material = "%s" }' % (nome, material))
                linhas.append("\t\t%s%s = { %s }," % (peca, sufixo, ", ".join(camadas)))
        linhas.append("\t},")
    linhas += ["}", ""]
    with open(ARQ_VISUAL, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    print("total de triângulos: %d" % total)
    if "--render" in sys.argv:
        renderizar(objetos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_SRC, "equipamento.blend"), compress=True)


def renderizar(objetos):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 48
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 560, 700
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 90
    cena.view_settings.view_transform = "Standard"
    mundo = bpy.data.worlds.new("Estudio")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.08, 0.17, 1)
    mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.3
    cena.world = mundo
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, 0))
    chao = bpy.context.object
    m = bpy.data.materials.new("Chao")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.075, 0.14, 1)
    chao.data.materials.append(m)
    pele = kit.criar_material("Boneco")
    for i, t in enumerate(TEMAS):
        grupos = {}
        for g in ("boneco", "arm", "ace"):
            col = bpy.data.collections.new("set_%s_%s" % (t["id"], g))
            bpy.context.scene.collection.children.link(col)
            grupos[g] = col
        dx = i * 8.0
        for nome, (c, s) in BONECO.items():
            cor = (0.95, 0.80, 0.62) if nome in ("Head",) or "Hand" in nome or "Arm" in nome else ((0.30, 0.35, 0.55) if "Leg" in nome or "Foot" in nome or "Lower" in nome else (0.85, 0.85, 0.9))
            o = kit.registrar("boneco_%d_%s" % (i, nome), bx(c, s, cor, 0.03), pele)
            o.location = (dx, 0, 0)
            grupos["boneco"].objects.link(o)
        for peca, lugares in ENCAIXE.items():
            grupo = grupos["arm" if peca in GRUPO_ARMADURA else "ace"]
            for matriz, sufixo in lugares:
                for camada in ("", "_brilho"):
                    fonte = objetos.get("equip_%s_%s%s%s" % (t["id"], peca, sufixo, camada))
                    if not fonte:
                        continue
                    inst = bpy.data.objects.new(fonte.name + "_inst", fonte.data)
                    inst.matrix_world = T((dx, 0, 0)) @ matriz
                    grupo.objects.link(inst)
    bpy.ops.object.light_add(type="AREA")
    luz = bpy.context.object
    luz.data.size = 10
    bpy.ops.object.light_add(type="AREA")
    luz2 = bpy.context.object
    luz2.data.size = 8
    luz2.data.color = (0.7, 0.6, 1.0)
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cena.camera = cam
    cam.data.lens = 50
    so = [a for a in sys.argv if a.startswith("--so=")]
    passes = [
        ("conjunto", ("boneco", "arm"), Vector((5.5, 10.5, 2.2))),
        ("acessorios", ("boneco", "ace"), Vector((5.5, 10.5, 2.2))),
        ("acessorios_costas", ("boneco", "ace"), Vector((-6.5, -9.5, 2.6))),
    ]
    for i, t in enumerate(TEMAS):
        if so and t["id"] not in so[0][5:].split(","):
            continue
        for nome_passe, visiveis, olhar in passes:
            for tt in TEMAS:
                for g in ("boneco", "arm", "ace"):
                    bpy.data.collections["set_%s_%s" % (tt["id"], g)].hide_render = not (tt["id"] == t["id"] and g in visiveis)
            alvo = Vector((i * 8.0, 0, 2.7))
            cam.location = alvo + olhar
            cam.rotation_euler = (alvo - cam.location).to_track_quat("-Z", "Y").to_euler()
            luz.location = alvo + Vector((6 * math.copysign(1, olhar.x), 8 * math.copysign(1, olhar.y), 9))
            luz.rotation_euler = (alvo - luz.location).to_track_quat("-Z", "Y").to_euler()
            luz.data.energy = 3500
            luz2.location = alvo + Vector((-9 * math.copysign(1, olhar.x), -4 * math.copysign(1, olhar.y), 5))
            luz2.rotation_euler = (alvo - luz2.location).to_track_quat("-Z", "Y").to_euler()
            luz2.data.energy = 1400
            cena.render.filepath = os.path.join(DIR_PREV, "%s_%s.jpg" % (nome_passe, t["id"]))
            bpy.ops.render.render(write_still=True)
            print("prévia", nome_passe, t["id"])

if __name__ == "__main__":
    main()
