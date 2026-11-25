"""Gera as criaturas do Corredor dos Perdidos no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/corredor/criaturas/generate_criaturas.py            # malhas, dados e FBX
    python assets/corredor/criaturas/generate_criaturas.py --render   # também as prévias

Estilo: personagens blocados como os do Roblox (cabeça, tronco, braços e pernas em blocos
chanfrados), com acessórios do tema de cada mundo, rosto de olhos acesos e cores fortes.
Duas criaturas por fase: um lacaio (altura de um avatar) e o chefe (2,3x maior).

Cada criatura é um conjunto de PEÇAS RÍGIDAS com juntas (como um R6): tronco (raiz), cabeça,
braços, pernas e, em alguns, asas. Cada peça tem a malha base e, se tiver, a malha de brilho
(olhos, runas, lava), que no Roblox vira Neon.

Saídas:
    src/client/Mundo/Nexo3D/Dados/criatura_*.luau   geometria das peças (kit do Nexo, funciona já)
    src/shared/Dados/CriaturasVisual.luau           peças, juntas e alturas (gerado)
    assets/corredor/criaturas/exports/<id>.fbx      para importar no Studio (cor por vértice)
    assets/corredor/criaturas/source/criaturas.blend
    assets/corredor/criaturas/previews/*.jpg        renders do Blender (NÃO são prints do Roblox)

Espaço de cada criatura: origem no chão, no centro; +Y do Blender é a frente (-Z no Roblox).
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
ARQ_VISUAL = os.path.join(RAIZ, "src", "shared", "Dados", "CriaturasVisual.luau")
DIR_EXP = os.path.join(AQUI, "exports")
DIR_PREV = os.path.join(AQUI, "previews")
DIR_SRC = os.path.join(AQUI, "source")

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


# ---------------------------------------------------------------- primitivas


def bx(c, s, cor, bisel=0.07, rot=None, tinta=1.0):
    """Bloco limpo (sem tremor) com chanfro, como as peças do Roblox."""
    bm = kit.bloco(s[0], s[1], s[2], random.Random(1), cor, chanfro=bisel, tremor=0.0, tinta=tinta)
    m = T(c) @ (rot if rot is not None else Matrix.Identity(4))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
    return bm


def ponta(base, topo, largura, cor):
    return kit.espinho(base, topo, largura, cor)


def cristal(c, escala, cor, semente=1, inclinar=(0, 0)):
    rng = random.Random(semente)
    pts = [(x * escala, y * escala, (z + 6.0) * escala) for x, y, z in kit.pontos_cristal(rng)]
    bm = kit.casco(pts, cor, 1.0, gradiente=(0, 12 * escala, kit.misturar(cor, PRETO, 0.35), kit.misturar(cor, BRANCO, 0.35)))
    m = T(c) @ R(inclinar[0], "X") @ R(inclinar[1], "Y")
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts[:])
    return bm


def cilindro(c, raio, altura, cor, lados=10, eixo="Z"):
    bm = kit.torno([(raio, -altura / 2), (raio, altura / 2)], lados, cor, random.Random(2), tinta=1.0)
    rot = Matrix.Identity(4) if eixo == "Z" else (R(90, "Y") if eixo == "X" else R(90, "X"))
    bmesh.ops.transform(bm, matrix=T(c) @ rot, verts=bm.verts[:])
    return bm


# ---------------------------------------------------------------- corpo blocado

# Proporções de um avatar blocado (studs): pernas 2, tronco 2, cabeça 1,3
PERNA = (0.95, 0.95, 2.0)
TRONCO = (2.0, 1.05, 2.0)
BRACO = (0.92, 0.92, 2.0)
CABECA = (1.6, 1.45, 1.45)


class Corpo:
    """Peças de uma criatura: nome -> {base: [bm], brilho: [bm], junta, pai}."""

    def __init__(self):
        self.pecas = {}

    def peca(self, nome, junta=None, pai=None):
        if nome not in self.pecas:
            self.pecas[nome] = {"base": [], "brilho": [], "vidro": [], "junta": junta, "pai": pai}
        return self.pecas[nome]

    def base(self, nome, bm):
        self.pecas[nome]["base"].append(bm)

    def brilho(self, nome, bm):
        self.pecas[nome]["brilho"].append(bm)

    def vidro(self, nome, bm):
        self.pecas[nome]["vidro"].append(bm)


def humanoide(c, pele, roupa, calca, cabeca=None, tronco=None, braco=None, perna=None, largura=1.0):
    """Monta o esqueleto de blocos (R6): tronco, cabeça, braços e pernas com juntas."""
    tp = tronco or TRONCO
    tp = (tp[0] * largura, tp[1], tp[2])
    pp = perna or PERNA
    bp = braco or BRACO
    cp = CABECA  # `cabeca` é só a cor da cabeça
    h_perna = pp[2]
    z_tronco = h_perna + tp[2] / 2
    ombro_x = tp[0] / 2 + bp[0] / 2 + 0.02
    quadril_x = tp[0] / 2 - pp[0] / 2
    c.peca("tronco")
    c.base("tronco", bx((0, 0, z_tronco), tp, roupa))
    topo = h_perna + tp[2]
    c.peca("cabeca", junta=(0, 0, topo), pai="tronco")
    c.base("cabeca", bx((0, 0, topo + cp[2] / 2 + 0.02), cp, pele if cabeca is None else cabeca))
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        c.peca(nome, junta=(lado * ombro_x, 0, topo - 0.3), pai="tronco")
        c.base(nome, bx((lado * ombro_x, 0, topo - bp[2] / 2), bp, pele))
    for lado, nome in ((-1, "perna_e"), (1, "perna_d")):
        c.peca(nome, junta=(lado * quadril_x, 0, h_perna), pai="tronco")
        c.base(nome, bx((lado * quadril_x, 0, h_perna / 2), pp, calca))
    return {"topo": topo, "cabeca_z": topo + cp[2] / 2 + 0.02, "cabeca": cp, "ombro_x": ombro_x, "tronco": tp, "z_tronco": z_tronco, "quadril_x": quadril_x, "perna": pp, "braco": bp}


def olhos(c, m, cor, largura=0.34, altura=0.26, sep=0.34, dz=0.08, raiva=True):
    """Dois olhos acesos na frente da cabeça, com ponto de luz e sobrancelha de bloco."""
    zf = m["cabeca_z"] + dz
    yf = m["cabeca"][1] / 2 + 0.02
    for lado in (-1, 1):
        c.base("cabeca", bx((lado * sep, yf - 0.01, zf), (largura + 0.08, 0.05, altura + 0.08), PRETO, bisel=0.02))
        c.brilho("cabeca", bx((lado * sep, yf + 0.01, zf), (largura, 0.06, altura), cor, bisel=0.02))
        c.brilho("cabeca", bx((lado * sep - lado * largura * 0.22, yf + 0.04, zf + altura * 0.2), (largura * 0.3, 0.04, altura * 0.3), BRANCO, bisel=0.01))
        if raiva:
            c.base("cabeca", bx((lado * sep, yf + 0.01, zf + altura * 0.9), (largura * 1.15, 0.07, 0.07), PRETO, bisel=0.01, rot=R(-lado * 14, "Y")))


def escalar(c, fator):
    for p in c.pecas.values():
        for chave in ("base", "brilho", "vidro"):
            for bm in p[chave]:
                bmesh.ops.scale(bm, vec=(fator, fator, fator), verts=bm.verts[:])
        if p["junta"]:
            p["junta"] = tuple(v * fator for v in p["junta"])


# ---------------------------------------------------------------- as criaturas

PEDRA = (0.62, 0.60, 0.74)
PEDRA_ESC = (0.40, 0.37, 0.52)
VIOLETA = (0.66, 0.45, 1.0)


def lasca_errante():
    """Fase 1 · lacaio: golem de pedra pequeno com cristais violeta crescendo nos ombros."""
    c = Corpo()
    m = humanoide(c, PEDRA, (0.50, 0.44, 0.70), PEDRA_ESC, cabeca=(0.66, 0.64, 0.78))
    olhos(c, m, VIOLETA)
    # rachaduras acesas no peito
    c.brilho("tronco", kit.fita3d([(-0.5, 0.54, 3.3), (-0.1, 0.55, 3.0), (0.15, 0.55, 3.25), (0.5, 0.54, 2.8)], 0.08, (0, 1, 0), VIOLETA))
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        x = lado * m["ombro_x"]
        c.vidro(nome, cristal((x, -0.05, m["topo"] + 0.05), 0.11, VIOLETA, 3 + lado, (lado * 15, 0)))
        c.vidro(nome, cristal((x + lado * 0.3, 0.1, m["topo"] - 0.1), 0.075, (0.85, 0.7, 1.0), 5 + lado, (lado * 35, 10)))
    c.vidro("cabeca", cristal((0.3, -0.1, m["cabeca_z"] + 0.7), 0.08, VIOLETA, 7, (0, 20)))
    c.vidro("cabeca", cristal((-0.35, 0.0, m["cabeca_z"] + 0.7), 0.06, (0.85, 0.7, 1.0), 8, (0, -25)))
    # punhos de pedra maiores
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        c.base(nome, bx((lado * m["ombro_x"], 0, 2.2), (1.1, 1.1, 0.6), PEDRA_ESC))
    return c


def sentinela_limiar():
    """Fase 1 · chefe: cavaleiro de pedra com armadura de cristal, escudo e coroa de lascas."""
    c = Corpo()
    m = humanoide(c, PEDRA, (0.46, 0.44, 0.62), PEDRA_ESC, cabeca=(0.58, 0.56, 0.72), largura=1.1)
    olhos(c, m, VIOLETA, largura=0.36, altura=0.14)
    # elmo: viseira e coroa de lascas
    c.base("cabeca", bx((0, 0.05, m["cabeca_z"] - 0.32), (1.7, 1.55, 0.28), PEDRA_ESC))
    for k, a in enumerate((-40, -15, 15, 40)):
        x = math.sin(math.radians(a)) * 0.55
        c.vidro("cabeca", cristal((x, -0.05, m["cabeca_z"] + 0.68), 0.08 + 0.02 * (k % 2), VIOLETA, 20 + k, (0, a * 0.6)))
    # ombreiras e peitoral de cristal
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        c.base(nome, bx((lado * m["ombro_x"], 0, m["topo"] - 0.1), (1.25, 1.25, 0.55), (0.52, 0.50, 0.66)))
        c.vidro(nome, cristal((lado * (m["ombro_x"] + 0.2), 0, m["topo"] + 0.15), 0.09, VIOLETA, 30 + lado, (lado * 30, 0)))
    c.vidro("tronco", cristal((0, 0.5, 3.2), 0.05, VIOLETA, 33, (70, 0)))
    c.brilho("tronco", kit.fita3d([(-0.7, 0.56, 3.65), (0, 0.58, 3.1), (0.7, 0.56, 3.65)], 0.1, (0, 1, 0), VIOLETA))
    # escudo grande no braço esquerdo, espada larga no direito
    c.base("braco_e", bx((-m["ombro_x"] - 0.55, 0.35, 2.6), (0.18, 1.6, 2.1), (0.50, 0.48, 0.64)))
    c.base("braco_e", bx((-m["ombro_x"] - 0.62, 0.35, 2.6), (0.08, 1.75, 2.25), (0.85, 0.7, 0.35)))
    c.vidro("braco_e", cristal((-m["ombro_x"] - 0.72, 0.35, 2.55), 0.09, VIOLETA, 40, (0, -90)))
    c.base("braco_d", bx((m["ombro_x"], 0.75, 1.75), (0.18, 0.3, 0.18), (0.5, 0.4, 0.25)))
    c.base("braco_d", bx((m["ombro_x"], 1.3, 1.75), (0.6, 0.15, 0.15), (0.8, 0.68, 0.35)))
    c.vidro("braco_d", bx((m["ombro_x"], 2.6, 1.75), (0.28, 2.4, 0.42), VIOLETA, bisel=0.05))
    escalar(c, 2.3)
    return c


CASCA = (0.62, 0.42, 0.26)
FOLHA = (0.40, 1.0, 0.82)


def broto_vidro():
    """Fase 2 · lacaio: brotinho de madeira com copa de folhas de vidro e braços de galho."""
    c = Corpo()
    m = humanoide(c, CASCA, (0.52, 0.34, 0.21), (0.44, 0.29, 0.18), cabeca=(0.70, 0.50, 0.32), braco=(0.6, 0.6, 2.0))
    olhos(c, m, (0.6, 1.0, 0.75), raiva=False)
    # copa: cubos de vidro em cima da cabeça
    rng = random.Random(4)
    for k in range(7):
        c.vidro("cabeca", bx((rng.uniform(-0.65, 0.65), rng.uniform(-0.55, 0.45), m["cabeca_z"] + 0.95 + rng.uniform(-0.1, 0.5)), (rng.uniform(0.7, 1.1),) * 3, kit.misturar(FOLHA, (0.2, 0.7, 0.5), rng.random() * 0.5), bisel=0.05, rot=R(rng.uniform(-25, 25), "Z") @ R(rng.uniform(-20, 20), "X")))
    # galhos nos braços e musgo no tronco
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        c.base(nome, ponta((lado * m["ombro_x"], 0, 2.4), (lado * (m["ombro_x"] + 0.6), 0.2, 2.0), 0.18, CASCA))
        c.vidro(nome, bx((lado * (m["ombro_x"] + 0.6), 0.2, 2.0), (0.35, 0.35, 0.35), FOLHA, bisel=0.04, rot=R(30, "Z")))
    c.base("tronco", bx((0, 0.4, 3.75), (2.05, 0.3, 0.3), (0.25, 0.5, 0.3)))
    c.brilho("tronco", bx((0, 0.54, 3.0), (0.3, 0.05, 0.3), (0.6, 1.0, 0.75), bisel=0.02, rot=R(45, "Y")))
    return c


def anciao_bosque():
    """Fase 2 · chefe: ent de casca com coroa de cristais, barba de musgo e braços de galho."""
    c = Corpo()
    m = humanoide(c, CASCA, (0.50, 0.33, 0.21), (0.42, 0.28, 0.18), cabeca=(0.58, 0.40, 0.26), largura=1.15, braco=(0.8, 0.8, 2.3))
    olhos(c, m, (0.55, 1.0, 0.7), largura=0.3, altura=0.24)
    # barba de musgo e casca em placas
    c.base("cabeca", bx((0, 0.5, m["cabeca_z"] - 0.5), (1.0, 0.35, 0.6), (0.22, 0.48, 0.28)))
    for k in range(5):
        c.base("tronco", bx((-0.8 + k * 0.4, 0.55, 2.4 + (k % 2) * 0.5), (0.3, 0.08, 0.9), (0.28, 0.18, 0.13)))
    # coroa de cristal e galhos
    rng = random.Random(8)
    for k in range(6):
        a = -60 + k * 24
        x = math.sin(math.radians(a)) * 0.6
        c.vidro("cabeca", cristal((x, -0.1, m["cabeca_z"] + 0.55), 0.05 + rng.uniform(0, 0.03), FOLHA, 50 + k, (rng.uniform(-15, 15), a * 0.5)))
    for lado in (-1, 1):
        c.base("cabeca", ponta((lado * 0.5, 0, m["cabeca_z"] + 0.4), (lado * 1.4, -0.2, m["cabeca_z"] + 1.5), 0.22, CASCA))
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        for k in range(3):
            c.base(nome, ponta((lado * m["ombro_x"], 0.1, 1.6 + k * 0.15), (lado * (m["ombro_x"] + 0.3 * (k - 1)), 0.7, 0.9 - k * 0.1), 0.18, CASCA))
        c.vidro(nome, bx((lado * m["ombro_x"], 0, m["topo"] + 0.2), (0.7, 0.7, 0.7), FOLHA, bisel=0.05, rot=R(25, "Z")))
    c.brilho("tronco", kit.fita3d([(0, 0.6, 2.2), (0.1, 0.6, 2.8), (-0.1, 0.6, 3.3), (0, 0.6, 3.8)], 0.12, (0, 1, 0), (0.55, 1.0, 0.7)))
    escalar(c, 2.3)
    return c


CINZA = (0.36, 0.32, 0.31)
BRASA = (1.0, 0.45, 0.12)
OBSIDIANA = (0.12, 0.10, 0.12)


def cinzento():
    """Fase 3 · lacaio: andarilho das cinzas de capuz, cachecol, óculos e lâmina curva."""
    c = Corpo()
    m = humanoide(c, (0.85, 0.62, 0.46), (0.68, 0.52, 0.36), (0.40, 0.33, 0.28), cabeca=(0.62, 0.48, 0.36))
    # capuz e cachecol
    c.base("cabeca", bx((0, -0.1, m["cabeca_z"] + 0.14), (1.78, 1.55, 1.55), (0.56, 0.44, 0.33)))
    c.base("cabeca", bx((0, 0.15, m["cabeca_z"] - 0.5), (1.7, 1.35, 0.5), (0.85, 0.3, 0.18)))
    # óculos de proteção acesos
    zf = m["cabeca_z"] + 0.05
    for lado in (-1, 1):
        c.base("cabeca", cilindro((lado * 0.36, 0.76, zf), 0.24, 0.12, (0.3, 0.25, 0.2), lados=10, eixo="Y"))
        c.brilho("cabeca", cilindro((lado * 0.36, 0.83, zf), 0.17, 0.04, BRASA, lados=10, eixo="Y"))
    c.base("cabeca", bx((0, 0.74, zf), (1.65, 0.08, 0.1), (0.25, 0.2, 0.17)))
    # brasa no peito, cinto e lâmina curva
    c.brilho("tronco", bx((0, 0.56, 3.4), (0.35, 0.05, 0.35), BRASA, bisel=0.02, rot=R(45, "Y")))
    c.base("tronco", bx((0, 0, 2.15), (2.1, 1.15, 0.25), (0.22, 0.17, 0.14)))
    lam = [(m["ombro_x"], 0.4, 1.2), (m["ombro_x"], 0.9, 1.1), (m["ombro_x"], 1.5, 1.35), (m["ombro_x"], 1.9, 1.8)]
    c.brilho("braco_d", kit.fita3d(lam, 0.22, (1, 0, 0), (1.0, 0.7, 0.4)))
    c.brilho("braco_d", kit.fita3d(lam, 0.22, (-1, 0, 0), (1.0, 0.7, 0.4)))
    c.base("braco_d", bx((m["ombro_x"], 0.3, 1.2), (0.2, 0.35, 0.2), (0.25, 0.2, 0.17)))
    return c


def senhor_brasas():
    """Fase 3 · chefe: brutamontes de obsidiana com rachaduras de lava, chifres e punhos de magma."""
    c = Corpo()
    m = humanoide(c, (0.2, 0.17, 0.19), (0.24, 0.19, 0.21), (0.17, 0.14, 0.16), cabeca=(0.26, 0.2, 0.22), largura=1.25, braco=(1.15, 1.15, 2.1))
    olhos(c, m, BRASA, largura=0.3, altura=0.14)
    # chifres e rachaduras de lava
    for lado in (-1, 1):
        c.base("cabeca", ponta((lado * 0.5, 0, m["cabeca_z"] + 0.45), (lado * 1.2, 0.3, m["cabeca_z"] + 1.4), 0.35, (0.25, 0.2, 0.18)))
    rng = random.Random(9)
    for nome, z0, z1, xs in (("tronco", 2.2, 3.9, 1.0), ("braco_e", 1.2, 3.6, 0.0), ("braco_d", 1.2, 3.6, 0.0)):
        for k in range(3):
            x0 = (-m["ombro_x"] if nome == "braco_e" else (m["ombro_x"] if nome == "braco_d" else 0)) + rng.uniform(-0.3, 0.3) * xs
            pts = kit.zigue((x0, z0), (x0 + rng.uniform(-0.3, 0.3), z1), 4, 0.15, rng)
            y = 0.59 if nome == "tronco" else 0.6
            c.brilho(nome, kit.fita3d([(x, y, z) for x, z in pts], 0.08, (0, 1, 0), BRASA))
    # punhos de magma e coração de brasa
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        c.brilho(nome, bx((lado * m["ombro_x"], 0, 1.2), (1.3, 1.3, 0.7), BRASA, bisel=0.12))
    c.brilho("tronco", bx((0, 0.6, 3.3), (0.6, 0.05, 0.6), (1.0, 0.75, 0.3), bisel=0.02, rot=R(45, "Y")))
    escalar(c, 2.3)
    return c


AZUL_MAR = (0.25, 0.45, 0.70)
PELE_MAR = (0.55, 0.78, 0.78)
CORAL = (1.0, 0.45, 0.45)
AQUA = (0.3, 0.95, 1.0)


def marujo_afogado():
    """Fase 4 · lacaio: marujo da maré suspensa com bandana, cracas, coral e olhos d'água."""
    c = Corpo()
    m = humanoide(c, PELE_MAR, (0.92, 0.92, 0.95), AZUL_MAR)
    olhos(c, m, AQUA, raiva=False)
    # listras da camisa, bandana e coral
    for k in range(3):
        c.base("tronco", bx((0, 0, 2.4 + k * 0.6), (2.04, 1.09, 0.18), AZUL_MAR))
    c.base("cabeca", bx((0, 0, m["cabeca_z"] + 0.45), (1.42, 1.32, 0.35), (0.85, 0.2, 0.25)))
    c.base("cabeca", bx((-0.6, -0.55, m["cabeca_z"] + 0.35), (0.25, 0.5, 0.25), (0.85, 0.2, 0.25), rot=R(30, "X")))
    c.base("braco_e", ponta((-m["ombro_x"], 0, 3.9), (-m["ombro_x"] - 0.4, -0.1, 4.6), 0.2, CORAL))
    c.base("braco_e", ponta((-m["ombro_x"] - 0.15, 0, 4.0), (-m["ombro_x"] - 0.1, 0.25, 4.5), 0.15, CORAL))
    for x, z in ((0.5, 3.1), (-0.6, 2.6), (0.3, 2.3)):
        c.base("tronco", cilindro((x, 0.55, z), 0.12, 0.08, (0.85, 0.85, 0.8), lados=8, eixo="Y"))
    # bolhas acesas e um pequeno arpão
    c.brilho("cabeca", bx((0.55, 0.4, m["cabeca_z"] + 0.85), (0.15, 0.15, 0.15), AQUA, bisel=0.06))
    c.base("braco_d", bx((m["ombro_x"], 0.5, 1.15), (0.12, 2.2, 0.12), (0.45, 0.35, 0.25), rot=R(-15, "X")))
    c.brilho("braco_d", ponta((m["ombro_x"], 1.6, 1.45), (m["ombro_x"], 2.1, 1.6), 0.2, AQUA))
    return c


def capitao_abissal():
    """Fase 4 · chefe: capitão de casaco longo, chapéu de três pontas, barba de tentáculos e âncora."""
    c = Corpo()
    m = humanoide(c, PELE_MAR, (0.18, 0.24, 0.42), (0.14, 0.16, 0.25), largura=1.15)
    olhos(c, m, AQUA, largura=0.3, altura=0.12)
    # chapéu de três pontas com caveira de concha
    zc = m["cabeca_z"] + 0.62
    c.base("cabeca", bx((0, 0, zc), (2.0, 1.6, 0.18), (0.12, 0.1, 0.12)))
    c.base("cabeca", bx((0, 0, zc + 0.35), (1.3, 1.15, 0.6), (0.12, 0.1, 0.12)))
    c.base("cabeca", bx((0, 0.6, zc + 0.35), (0.4, 0.06, 0.4), (0.95, 0.85, 0.5), bisel=0.02))
    # barba de tentáculos
    for k, x in enumerate((-0.45, -0.15, 0.15, 0.45)):
        pts = [(x, 0.66, m["cabeca_z"] - 0.4), (x * 1.1, 0.75, m["cabeca_z"] - 0.9), (x * 0.9 + 0.1 * (k % 2), 0.7, m["cabeca_z"] - 1.35)]
        c.base("cabeca", kit.fita3d(pts, 0.2, (0, 1, 0), (0.45, 0.75, 0.7)))
        c.base("cabeca", kit.fita3d(pts, 0.2, (0, -1, 0), (0.45, 0.75, 0.7)))
    # casaco longo com botões dourados e lanterna acesa
    c.base("tronco", bx((0, -0.05, 1.65), (2.25, 1.15, 1.3), (0.18, 0.24, 0.42)))
    for z in (2.6, 3.1, 3.6):
        c.base("tronco", cilindro((0.35, 0.56, z), 0.1, 0.06, (0.95, 0.8, 0.35), lados=8, eixo="Y"))
    c.base("braco_e", bx((-m["ombro_x"], 0.2, 1.0), (0.12, 0.12, 0.5), (0.3, 0.25, 0.2)))
    c.base("braco_e", bx((-m["ombro_x"], 0.2, 0.55), (0.45, 0.45, 0.55), (0.25, 0.22, 0.2)))
    c.brilho("braco_e", bx((-m["ombro_x"], 0.2, 0.55), (0.3, 0.3, 0.4), AQUA, bisel=0.03))
    # âncora no braço direito
    xa = m["ombro_x"]
    c.base("braco_d", bx((xa, 0.4, 0.9), (0.18, 0.18, 2.4), (0.45, 0.48, 0.55)))
    c.base("braco_d", bx((xa, 0.4, -0.2), (1.4, 0.2, 0.2), (0.45, 0.48, 0.55)))
    for lado in (-1, 1):
        c.base("braco_d", ponta((xa + lado * 0.7, 0.4, -0.25), (xa + lado * 0.85, 0.4, 0.25), 0.22, (0.45, 0.48, 0.55)))
    escalar(c, 2.3)
    return c


MARMORE = (0.88, 0.86, 0.92)
OURO = (1.0, 0.80, 0.32)


def estatua_viva():
    """Fase 5 · lacaio: estátua de mármore com rachaduras douradas, auréola e lança."""
    c = Corpo()
    m = humanoide(c, MARMORE, (0.82, 0.80, 0.88), (0.75, 0.73, 0.82))
    olhos(c, m, OURO, largura=0.22, altura=0.08, raiva=False)
    c.base("cabeca", bx((0, -0.05, m["cabeca_z"] + 0.45), (1.45, 1.35, 0.3), (0.78, 0.76, 0.84)))
    c.brilho("cabeca", kit.fita3d([(-0.2, 0.64, m["cabeca_z"] + 0.6), (0.05, 0.65, m["cabeca_z"] + 0.2), (-0.1, 0.65, m["cabeca_z"] - 0.2)], 0.05, (0, 1, 0), OURO))
    # auréola
    halo = kit.torno([(0.62, -0.05), (0.72, -0.05), (0.72, 0.05), (0.62, 0.05)], 20, OURO, random.Random(5))
    bmesh.ops.translate(halo, vec=Vector((0, -0.2, m["cabeca_z"] + 1.0)), verts=halo.verts[:])
    c.brilho("cabeca", halo)
    # saiote de placas, rachaduras e lança
    for k in range(4):
        c.base("tronco", bx((-0.75 + k * 0.5, 0.05, 2.05), (0.45, 1.15, 0.45), (0.78, 0.76, 0.84)))
    c.brilho("tronco", kit.fita3d([(0.6, 0.55, 3.8), (0.3, 0.56, 3.3), (0.45, 0.56, 2.8)], 0.06, (0, 1, 0), OURO))
    c.base("braco_d", bx((m["ombro_x"], 0.45, 1.6), (0.14, 0.14, 3.2), (0.7, 0.6, 0.45)))
    c.brilho("braco_d", ponta((m["ombro_x"], 0.45, 3.15), (m["ombro_x"], 0.45, 3.9), 0.3, OURO))
    return c


def arcanjo_partido():
    """Fase 5 · chefe: anjo de mármore partido, asas de penas em bloco, armadura de ouro e espada de luz."""
    c = Corpo()
    m = humanoide(c, MARMORE, (0.85, 0.83, 0.9), (0.8, 0.78, 0.86), largura=1.1)
    olhos(c, m, OURO, largura=0.3, altura=0.08, raiva=False)
    c.base("tronco", bx((0, 0.05, 3.3), (2.3, 1.2, 1.0), OURO))
    c.base("tronco", bx((0, 0.62, 3.3), (0.5, 0.06, 0.5), (1.0, 0.95, 0.75), bisel=0.02, rot=R(45, "Y")))
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        c.base(nome, bx((lado * m["ombro_x"], 0, m["topo"] - 0.15), (1.2, 1.15, 0.5), OURO))
    halo = kit.torno([(0.75, -0.06), (0.88, -0.06), (0.88, 0.06), (0.75, 0.06)], 24, OURO, random.Random(6))
    bmesh.ops.transform(halo, matrix=T((0, -0.3, m["cabeca_z"] + 1.0)) @ R(15, "X"), verts=halo.verts[:])
    c.brilho("cabeca", halo)
    # rosto partido: um pedaço faltando com luz dentro
    c.brilho("cabeca", bx((0.45, 0.63, m["cabeca_z"] + 0.35), (0.35, 0.04, 0.4), (1.0, 0.92, 0.6), bisel=0.01))
    # asas: penas em bloco, em leque
    for lado, nome in ((-1, "asa_e"), (1, "asa_d")):
        c.peca(nome, junta=(lado * 0.6, -0.55, 3.6), pai="tronco")
        for k in range(5):
            comp = 2.6 - k * 0.35
            a = math.radians(25 + k * 14)
            cx = lado * (0.6 + math.cos(a) * comp / 2)
            cz = 3.6 + math.sin(a) * comp / 2 - k * 0.15
            c.base(nome, bx((cx, -0.65 - k * 0.04, cz), (comp, 0.18, 0.42), kit.misturar(MARMORE, (1.0, 0.95, 0.8), k * 0.1), rot=R(-lado * math.degrees(a), "Y")))
    # espada de luz
    c.base("braco_d", bx((m["ombro_x"], 0.5, 1.1), (0.5, 0.2, 0.15), OURO))
    c.brilho("braco_d", bx((m["ombro_x"], 0.5, 2.6), (0.2, 0.12, 2.8), (1.0, 0.95, 0.7), bisel=0.03))
    escalar(c, 2.3)
    return c


VAZIO = (0.16, 0.11, 0.26)
MAGENTA = (0.92, 0.35, 1.0)


def eco_vazio():
    """Fase 6 · lacaio: silhueta do vazio salpicada de estrelas, com um único olho."""
    c = Corpo()
    m = humanoide(c, VAZIO, (0.21, 0.13, 0.34), (0.13, 0.09, 0.22), cabeca=(0.24, 0.15, 0.38))
    zf = m["cabeca_z"] + 0.05
    c.brilho("cabeca", bx((0, m["cabeca"][1] / 2 + 0.02, zf), (0.75, 0.06, 0.48), MAGENTA, bisel=0.03))
    c.base("cabeca", bx((0, m["cabeca"][1] / 2 + 0.04, zf), (0.3, 0.06, 0.3), PRETO, bisel=0.02))
    c.brilho("cabeca", bx((0.1, m["cabeca"][1] / 2 + 0.06, zf + 0.08), (0.1, 0.04, 0.1), BRANCO, bisel=0.01))
    rng = random.Random(11)
    for nome in ("tronco", "braco_e", "braco_d", "perna_e", "perna_d", "cabeca"):
        p = c.pecas[nome]
        for _ in range(4 if nome == "tronco" else 2):
            if nome == "tronco":
                pos = (rng.uniform(-0.8, 0.8), 0.54, rng.uniform(2.2, 3.8))
            elif nome == "cabeca":
                pos = (rng.uniform(-0.55, 0.55), 0.64, m["cabeca_z"] + rng.uniform(0.3, 0.55))
            else:
                x = {"braco_e": -m["ombro_x"], "braco_d": m["ombro_x"], "perna_e": -m["quadril_x"], "perna_d": m["quadril_x"]}[nome]
                pos = (x + rng.uniform(-0.2, 0.2), 0.48, rng.uniform(0.4, 3.5) if "braco" in nome else rng.uniform(0.3, 1.7))
            c.brilho(nome, bx(pos, (0.1, 0.04, 0.1), (0.9, 0.85, 1.0), bisel=0.01, rot=R(45, "Y")))
    # fiapos de sombra nos pés e nos ombros
    for lado, nome in ((-1, "perna_e"), (1, "perna_d")):
        c.base(nome, ponta((lado * m["quadril_x"], 0, 0.3), (lado * (m["quadril_x"] + 0.5), -0.6, 0.0), 0.4, VAZIO))
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        c.base(nome, ponta((lado * m["ombro_x"], 0, m["topo"]), (lado * (m["ombro_x"] + 0.4), -0.3, m["topo"] + 0.8), 0.35, (0.18, 0.1, 0.28)))
    return c


def devorador_estrelas():
    """Fase 6 · chefe: titã do vazio de braços longos, coroa de cubos, vários olhos e constelações."""
    c = Corpo()
    m = humanoide(c, VAZIO, (0.2, 0.13, 0.33), (0.13, 0.09, 0.22), cabeca=(0.3, 0.18, 0.46), largura=1.2, braco=(1.0, 1.0, 2.8))
    # três olhos
    zf = m["cabeca_z"]
    yf = m["cabeca"][1] / 2 + 0.02
    for x, z, w in ((-0.4, zf - 0.05, 0.36), (0.4, zf - 0.05, 0.36), (0, zf + 0.38, 0.42)):
        c.base("cabeca", bx((x, yf - 0.01, z), (w + 0.1, 0.05, w * 0.6 + 0.1), PRETO, bisel=0.02))
        c.brilho("cabeca", bx((x, yf + 0.01, z), (w, 0.06, w * 0.6), MAGENTA, bisel=0.02))
    # coroa de cubos flutuando
    for k in range(7):
        a = 2 * math.pi * k / 7
        c.base("cabeca", bx((math.cos(a) * 0.85, math.sin(a) * 0.7, m["cabeca_z"] + 0.95 + 0.15 * (k % 2)), (0.32, 0.32, 0.32), (0.2, 0.14, 0.3), rot=R(45, "Z") @ R(35, "X")))
        c.brilho("cabeca", bx((math.cos(a) * 0.85, math.sin(a) * 0.7, m["cabeca_z"] + 0.95 + 0.15 * (k % 2)), (0.12, 0.12, 0.12), MAGENTA, bisel=0.01))
    # constelação no peito: estrelas ligadas por linhas
    nos = [(-0.6, 3.7), (-0.2, 3.2), (0.3, 3.5), (0.5, 2.8), (-0.1, 2.5), (-0.6, 2.7)]
    for i, (x, z) in enumerate(nos):
        c.brilho("tronco", bx((x, 0.56, z), (0.16, 0.04, 0.16), (0.95, 0.9, 1.0), bisel=0.01, rot=R(45, "Y")))
        if i:
            x0, z0 = nos[i - 1]
            c.brilho("tronco", kit.fita3d([(x0, 0.57, z0), (x, 0.57, z)], 0.04, (0, 1, 0), (0.7, 0.55, 1.0)))
    # garras longas
    for lado, nome in ((-1, "braco_e"), (1, "braco_d")):
        for k in (-1, 0, 1):
            c.brilho(nome, ponta((lado * m["ombro_x"] + k * 0.3, 0.2, 1.3), (lado * m["ombro_x"] + k * 0.4, 0.6, 0.5), 0.14, MAGENTA))
    escalar(c, 2.4)
    return c


CRIATURAS = [
    ("lasca_errante", lasca_errante, 1, "lacaio"),
    ("sentinela_limiar", sentinela_limiar, 1, "chefe"),
    ("broto_vidro", broto_vidro, 2, "lacaio"),
    ("anciao_bosque", anciao_bosque, 2, "chefe"),
    ("cinzento", cinzento, 3, "lacaio"),
    ("senhor_brasas", senhor_brasas, 3, "chefe"),
    ("marujo_afogado", marujo_afogado, 4, "lacaio"),
    ("capitao_abissal", capitao_abissal, 4, "chefe"),
    ("estatua_viva", estatua_viva, 5, "lacaio"),
    ("arcanjo_partido", arcanjo_partido, 5, "chefe"),
    ("eco_vazio", eco_vazio, 6, "lacaio"),
    ("devorador_estrelas", devorador_estrelas, 6, "chefe"),
]


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
        "-- GERADO por assets/corredor/criaturas/generate_criaturas.py. Não editar à mão.",
        "-- Peça de uma criatura do Corredor (mesmo formato do kit do Nexo).",
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


def rbx(v):
    return (v[0], v[2], -v[1])


def v3(p):
    return "{ %s }" % ", ".join(("%.3f" % c).rstrip("0").rstrip(".") for c in p)


ORDEM = ["tronco", "cabeca", "braco_e", "braco_d", "perna_e", "perna_d", "asa_e", "asa_d"]
MATERIAL_BASE = {1: "Slate", 2: "Wood", 3: "SmoothPlastic", 4: "SmoothPlastic", 5: "Marble", 6: "SmoothPlastic"}


def main():
    for d in (DIR_EXP, DIR_PREV, DIR_SRC):
        os.makedirs(d, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materiais = {
        "base": kit.criar_material("Criatura_Base", rugosidade=0.6),
        "brilho": kit.criar_material("Criatura_Brilho", emissao=5.0),
        "vidro": kit.criar_material("Criatura_Vidro", rugosidade=0.08, transmissao=0.6),
    }
    registros = []
    colecoes = {}
    total = 0
    for idx, (cid, fn, fase, tipo) in enumerate(CRIATURAS):
        corpo = fn()
        col = bpy.data.collections.new(cid)
        bpy.context.scene.collection.children.link(col)
        colecoes[cid] = col
        partes = []
        altura = 0.0
        for nome in ORDEM:
            p = corpo.pecas.get(nome)
            if not p:
                continue
            malhas = []
            for camada, material, transp in (("base", MATERIAL_BASE[fase], 0.0), ("vidro", "Glass", 0.15), ("brilho", "Neon", 0.0)):
                if not p[camada]:
                    continue
                malha = "criatura_%s_%s%s" % (cid, nome, "" if camada == "base" else "_" + camada)
                obj = kit.registrar(malha, montar(p[camada]), materiais[camada])
                col.objects.link(obj)
                obj.location = ((idx % 6) * 12.0, -(idx // 6) * 14.0, 0)
                altura = max(altura, max(v.co.z for v in obj.data.vertices))
                total += escrever_malha(malha, obj)
                malhas.append({"malha": malha, "material": material, "transparencia": transp, "obj": obj, "camada": camada})
            partes.append({"nome": nome, "pai": p["pai"], "junta": p["junta"], "malhas": malhas})
        registros.append({"id": cid, "fase": fase, "tipo": tipo, "altura": altura, "partes": partes})
        print("%-20s altura %.2f" % (cid, altura))
    print("total de triângulos: %d" % total)

    # dados para o jogo
    linhas = [
        "-- GERADO por assets/corredor/criaturas/generate_criaturas.py. Não editar à mão.",
        "-- Criaturas do Corredor: peças rígidas (como um R6), juntas (studs, espaço da criatura com",
        "-- origem no chão) e as malhas de cada peça. Com um modelo importado em",
        "-- ReplicatedStorage.CorredorModelos.<id>, o cliente usa as MeshParts dele com estes nomes.",
        "return {",
    ]
    for r in registros:
        linhas.append("\t%s = {" % r["id"])
        linhas.append("\t\tfase = %d," % r["fase"])
        linhas.append('\t\ttipo = "%s",' % r["tipo"])
        linhas.append("\t\taltura = %.3f," % r["altura"])
        linhas.append("\t\tpartes = {")
        for p in r["partes"]:
            campos = ['nome = "%s"' % p["nome"]]
            if p["pai"]:
                campos.append('pai = "%s"' % p["pai"])
            if p["junta"]:
                campos.append("junta = %s" % v3(rbx(p["junta"])))
            ms = ", ".join('{ malha = "%s", material = "%s", transparencia = %.2f }' % (m["malha"], m["material"], m["transparencia"]) for m in p["malhas"])
            campos.append("malhas = { %s }" % ms)
            linhas.append("\t\t\t{ " + ", ".join(campos) + " },")
        linhas.append("\t\t},")
        linhas.append("\t},")
    linhas += ["}", ""]
    with open(ARQ_VISUAL, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))

    # FBX para importar no Studio: uma peça por objeto, nomes = peça (+ _brilho/_vidro)
    for r in registros:
        bpy.ops.object.select_all(action="DESELECT")
        copias = []
        for p in r["partes"]:
            for m in p["malhas"]:
                obj = m["obj"].copy()
                obj.data = m["obj"].data.copy()
                obj.name = p["nome"] + ("" if m["camada"] == "base" else "_" + m["camada"])
                obj.location = (0, 0, 0)
                bpy.context.scene.collection.objects.link(obj)
                obj.select_set(True)
                copias.append(obj)
        bpy.ops.mesh.primitive_cube_add(size=0.2, location=(0, 0, 0.1))
        origem = bpy.context.object
        origem.name = "Origem"
        origem.select_set(True)
        copias.append(origem)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(DIR_EXP, r["id"] + ".fbx"),
            use_selection=True,
            object_types={"MESH"},
            apply_scale_options="FBX_SCALE_ALL",
            axis_forward="-Z",
            axis_up="Y",
            mesh_smooth_type="FACE",
            colors_type="SRGB",
            bake_anim=False,
        )
        for o in copias:
            bpy.data.objects.remove(o, do_unlink=True)

    if "--render" in sys.argv:
        renderizar(registros, colecoes)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_SRC, "criaturas.blend"), compress=True)


def renderizar(registros, colecoes):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 48
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 560, 640
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 90
    cena.view_settings.view_transform = "Standard"
    mundo = bpy.data.worlds.new("Estudio")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.08, 0.17, 1)
    mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.4
    cena.world = mundo
    bpy.ops.mesh.primitive_plane_add(size=400, location=(30, -10, 0))
    chao = bpy.context.object
    m = bpy.data.materials.new("Chao")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.075, 0.14, 1)
    chao.data.materials.append(m)
    bpy.ops.object.light_add(type="AREA")
    luz = bpy.context.object
    luz.data.energy = 2500
    luz.data.size = 10
    bpy.ops.object.light_add(type="AREA")
    luz2 = bpy.context.object
    luz2.data.energy = 900
    luz2.data.size = 8
    luz2.data.color = (0.7, 0.6, 1.0)
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cena.camera = cam
    cam.data.lens = 50
    for r in registros:
        for cid, col in colecoes.items():
            col.hide_render = cid != r["id"]
        obj = r["partes"][0]["malhas"][0]["obj"]
        base = obj.location.copy()
        h = r["altura"]
        alvo = base + Vector((0, 0, h * 0.52))
        dist = h * 2.2 + 2.5
        cam.location = alvo + Vector((dist * 0.45, dist * 0.88, dist * 0.18))
        cam.rotation_euler = (alvo - cam.location).to_track_quat("-Z", "Y").to_euler()
        luz.location = alvo + Vector((dist * 0.6, dist * 0.7, dist * 0.8))
        luz.rotation_euler = (alvo - luz.location).to_track_quat("-Z", "Y").to_euler()
        luz2.location = alvo + Vector((-dist * 0.8, -dist * 0.3, dist * 0.4))
        luz2.rotation_euler = (alvo - luz2.location).to_track_quat("-Z", "Y").to_euler()
        luz.data.energy = 250 * dist
        luz2.data.energy = 90 * dist
        cena.render.filepath = os.path.join(DIR_PREV, r["id"] + ".jpg")
        bpy.ops.render.render(write_still=True)
        print("prévia", r["id"])


if __name__ == "__main__":
    main()
