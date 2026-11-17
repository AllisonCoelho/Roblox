"""Gera os kits 3D dos universos das Incursões (Cinzas, Maré Morta, Crepúsculo Umbral) no Blender
(testado com bpy 5.3). Usa as ferramentas de modelagem do kit do Nexo (generate_nexo.py).

Uso (Blender como módulo Python):
    python assets/incursoes/source/generate_incursoes.py            # malhas, .blend, .fbx, Luau
    python assets/incursoes/source/generate_incursoes.py --render   # também as prévias

Saídas:
    assets/incursoes/source/incursoes.blend            cena editável (as três composições)
    assets/incursoes/exports/inc_*.fbx                 uma peça por arquivo
    assets/incursoes/previews/*.jpg                    renders do Blender (NÃO são capturas do Roblox)
    src/client/Mundo/Nexo3D/Dados/inc_*.luau           geometria lida pelo jogo (EditableMesh)
    src/shared/Dados/IncursoesKit.luau                 caixa, centro, colisão e material de cada peça

Cada universo tem as mesmas peças, com forma e cor próprias:
    piso / piso_luz          lajes do andar e as fissuras de energia (o chão que colide é do servidor)
    pilar, muro, rocha       ruínas (colidem)
    nucleo / nucleo_luz      Núcleo Corrompido: pedestal e cristal (o jogo pinta o cristal pelo progresso)
    sombra / sombra_luz      inimigo comum (o jogo move a peça; olhos/garras em _luz)
    guardiao / guardiao_luz  chefe do 5º andar
    portal / portal_luz      fenda que leva ao próximo andar
As peças "_luz" têm cor branca nos vértices: a cor vem da parte (Neon) no jogo.
Origem de cada peça = pé dela no chão; +Y é a frente. Conversão para o Roblox: (x, y, z) -> (x, z, -y).
"""

import math
import os
import random
import sys

sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "assets", "nexo", "source"))

import bpy  # noqa: E402

import generate_nexo as kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

DIR_BASE = os.path.join(RAIZ, "assets", "incursoes")
DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Nexo3D", "Dados")
ARQ_KIT = os.path.join(RAIZ, "src", "shared", "Dados", "IncursoesKit.luau")

T = Matrix.Translation
BRANCO = (1.0, 1.0, 1.0)
RAIO_ANDAR = 64.0  # raio do chão de cada andar (o servidor usa o mesmo)


def R(graus, eixo):
    return Matrix.Rotation(math.radians(graus), 4, eixo)


# paletas por universo
PALETAS = {
    "cinzas": dict(pedra=(0.24, 0.17, 0.15), pedra2=(0.33, 0.22, 0.18), escura=(0.12, 0.08, 0.08), detalhe=(0.55, 0.30, 0.18), corpo=(0.10, 0.06, 0.06)),
    "mare": dict(pedra=(0.20, 0.27, 0.33), pedra2=(0.26, 0.35, 0.40), escura=(0.10, 0.14, 0.18), detalhe=(0.30, 0.62, 0.58), corpo=(0.05, 0.09, 0.13)),
    "umbral": dict(pedra=(0.19, 0.15, 0.27), pedra2=(0.26, 0.20, 0.36), escura=(0.09, 0.07, 0.14), detalhe=(0.45, 0.28, 0.62), corpo=(0.06, 0.04, 0.10)),
}


def membro(bm, a, b, larg0, larg1, rng, cor, cortes=2):
    a, b = Vector(a), Vector(b)
    d = b - a
    rot = d.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    for k in range(cortes):
        f0, f1 = k / cortes, (k + 1) / cortes
        larg = larg0 + (larg1 - larg0) * (f0 + f1) / 2
        kit.juntar(bm, kit.bloco(larg, larg * 0.9, d.length / cortes + 0.12, rng, cor, chanfro=0.06), T(a + d * (f0 + f1) / 2) @ rot @ R(9 if k % 2 else -9, "Z"))


# ---------------------------------------------------------------- chão


def fazer_piso(u, p):
    rng = random.Random(4100 + len(u))
    bm = kit.novo_bm()
    aneis = [(3, 12, 10), (12, 24, 16), (24, 38, 24), (38, 52, 32), (52, RAIO_ANDAR, 40)]
    for r0, r1, n in aneis:
        for i in range(n):
            if r1 > 50 and rng.random() < 0.12:
                continue  # lajes que faltam na borda
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            cor = p["pedra"] if rng.random() < 0.7 else p["pedra2"]
            kit.juntar(bm, kit.laje(r0, r1, a0, a1, 0.3 + rng.uniform(0, 0.08 if r1 < 50 else 0.3), rng, cor, folga=0.12, saia=0.35))
    kit.juntar(bm, kit.torno([(3.2, 0), (3.2, 0.4), (0.3, 0.4)], 12, p["escura"], rng))
    return bm


def fazer_piso_luz(u, p):
    rng = random.Random(4200 + len(u))
    bm = kit.novo_bm()
    for k in range(9):
        a = 2 * math.pi * k / 9 + rng.uniform(-0.2, 0.2)
        r0, r1 = rng.uniform(6, 14), rng.uniform(40, 60)
        kit.juntar(bm, kit.fita(kit.zigue((r0 * math.cos(a), r0 * math.sin(a)), (r1 * math.cos(a + 0.3), r1 * math.sin(a + 0.3)), 9, 2.2, rng), 0.35, 0.42, BRANCO))
    kit.juntar(bm, kit.fita(kit.arco_pontos(9, 0, 2 * math.pi, 36), 0.3, 0.42, BRANCO))
    if u == "mare":  # ondas concêntricas paradas
        for r in (20, 31):
            kit.juntar(bm, kit.fita([(r * math.cos(t) * (1 + 0.03 * math.sin(t * 7)), r * math.sin(t) * (1 + 0.03 * math.sin(t * 7))) for t in (2 * math.pi * j / 60 for j in range(61))], 0.18, 0.42, BRANCO))
    return bm


# ---------------------------------------------------------------- ruínas


def fazer_pilar(u, p):
    rng = random.Random(4300 + len(u))
    bm = kit.novo_bm()
    if u == "umbral":  # monólito-lasca inclinado, com estilhaços em volta
        kit.juntar(bm, kit.espinho((0, 0, 0), (0.6, 0.2, 13), 3.2, p["pedra2"], 1.0, chanfro=0.08))
        for k in range(4):
            a = k * 1.6
            kit.juntar(bm, kit.espinho((2.2 * math.cos(a), 2.2 * math.sin(a), 0), (2.8 * math.cos(a), 2.8 * math.sin(a), rng.uniform(2, 4.5)), 1.0, p["pedra"], 1.0))
        return bm
    z = 0.0
    alto = 11 if u == "cinzas" else 12.5
    while z < alto:
        h = rng.uniform(1.6, 2.4)
        f = z / alto
        larg = 2.8 - 0.5 * f
        m = T((rng.uniform(-0.1, 0.1), 0, z + h / 2)) @ R(rng.uniform(-4, 4), "Z") @ R(rng.uniform(-3, 3) * f, "X")
        kit.juntar(bm, kit.bloco(larg, larg, h - 0.08, rng, p["pedra"] if rng.random() < 0.6 else p["pedra2"], chanfro=0.14), m)
        z += h
    kit.juntar(bm, kit.bloco(3.6, 3.6, 0.7, rng, p["escura"], chanfro=0.12), T((0, 0, 0.35)))
    if u == "cinzas":  # topo partido em pontas
        for k in range(3):
            kit.juntar(bm, kit.espinho((rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), z), (rng.uniform(-1, 1), rng.uniform(-1, 1), z + rng.uniform(1.0, 2.2)), 1.0, p["pedra2"], 1.0))
    else:  # corais e cracas
        for k in range(6):
            a = rng.uniform(0, 2 * math.pi)
            zz = rng.uniform(1, alto * 0.8)
            kit.juntar(bm, kit.espinho((1.3 * math.cos(a), 1.3 * math.sin(a), zz), (2.4 * math.cos(a), 2.4 * math.sin(a), zz + rng.uniform(0.8, 1.8)), 0.45, p["detalhe"], 1.0))
    return bm


def fazer_muro(u, p):
    rng = random.Random(4400 + len(u))
    bm = kit.novo_bm()
    larg = 14
    for i in range(7):
        x = -larg / 2 + (i + 0.5) * larg / 7
        alt = 6.5 * (1 - abs(x) / larg) + rng.uniform(-1.6, 1.2) + (2.0 if i == 2 else 0)
        z = 0.0
        while z < alt:
            h = min(rng.uniform(1.1, 1.6), alt - z)
            if h < 0.4:
                break
            kit.juntar(bm, kit.bloco(larg / 7 - 0.1, 1.8, h - 0.06, rng, p["pedra"] if rng.random() < 0.6 else p["pedra2"], chanfro=0.1), T((x + rng.uniform(-0.05, 0.05), rng.uniform(-0.08, 0.08), z + h / 2)))
            z += h
    for k in range(4):  # entulho caído na frente
        kit.juntar(bm, kit.bloco(1.6, 1.4, 1.0, rng, p["pedra2"], chanfro=0.1), T((rng.uniform(-5, 5), rng.uniform(1.6, 3.2), 0.5)) @ R(rng.uniform(0, 90), "Z") @ R(rng.uniform(-20, 20), "X"))
    if u == "umbral":
        for k in range(3):
            kit.juntar(bm, kit.espinho((rng.uniform(-5, 5), 0, 4), (rng.uniform(-6, 6), rng.uniform(-1, 1), rng.uniform(8, 10)), 0.9, p["pedra2"], 1.0))
    return bm


def fazer_rocha(u, p):
    rng = random.Random(4500 + len(u))
    bm = kit.novo_bm()
    for k in range(4):
        pts = [(rng.uniform(-1.6, 1.6) + k * 1.4 - 2, rng.uniform(-1.4, 1.4), rng.uniform(0, 2.2 - 0.4 * k)) for _ in range(12)] + [(k * 1.4 - 2, 0, 0)]
        kit.juntar(bm, kit.casco(pts, p["pedra"] if k % 2 else p["pedra2"], 1.0, chanfro=0.06))
    return bm


# ---------------------------------------------------------------- núcleo


def fazer_nucleo(u, p):
    rng = random.Random(4600 + len(u))
    bm = kit.torno([(3.0, 0), (2.6, 0.6), (1.7, 0.8), (1.7, 1.6), (2.4, 1.9), (2.4, 2.2), (0.3, 2.2)], 8, p["escura"], rng, estrela=0.06)
    for k in range(4):  # garras de pedra segurando o cristal
        a = math.pi / 4 + k * math.pi / 2
        kit.juntar(bm, kit.espinho((2.0 * math.cos(a), 2.0 * math.sin(a), 2.0), (1.0 * math.cos(a), 1.0 * math.sin(a), 5.5), 0.6, p["pedra2"], 1.0))
    return bm


def fazer_nucleo_luz(u, p):
    bm = kit.novo_bm()
    kit.juntar(bm, kit.espinho((0, 0, 2.0), (0.2, 0, 8.2), 1.5, BRANCO, 1.0))
    kit.juntar(bm, kit.espinho((0, 0, 2.2), (0.0, 0, -0.0 + 2.4), 0.1, BRANCO, 1.0))
    for k in range(5):
        a = k * 2 * math.pi / 5
        kit.juntar(bm, kit.espinho((0.6 * math.cos(a), 0.6 * math.sin(a), 2.2), (1.6 * math.cos(a), 1.6 * math.sin(a), 4.2 + 0.4 * k), 0.6, BRANCO, 1.0))
    return bm


# ---------------------------------------------------------------- sombra (inimigo comum)


def fazer_sombra(u, p):
    """Figura curvada de matéria escura, ~5 studs, braços longos com garras."""
    rng = random.Random(4700 + len(u))
    bm = kit.novo_bm()
    c = p["corpo"]
    for lado in (-1, 1):
        membro(bm, (lado * 0.45, -0.2, 0.0), (lado * 0.55, 0.3, 1.2), 0.5, 0.55, rng, c)
        membro(bm, (lado * 0.55, 0.3, 1.2), (lado * 0.5, -0.1, 2.3), 0.55, 0.6, rng, c)
        membro(bm, (lado * 1.05, 0.2, 3.6), (lado * 1.5, 0.9, 2.4), 0.45, 0.4, rng, c)  # braço
        membro(bm, (lado * 1.5, 0.9, 2.4), (lado * 1.45, 1.5, 1.2), 0.4, 0.38, rng, c)
    kit.juntar(bm, kit.bloco(1.6, 1.0, 1.3, rng, c, chanfro=0.12), T((0, 0.0, 2.75)) @ R(18, "X"))
    kit.juntar(bm, kit.bloco(2.2, 1.2, 1.2, rng, c, chanfro=0.12), T((0, 0.35, 3.7)) @ R(28, "X"))
    kit.juntar(bm, kit.bloco(0.95, 1.1, 0.9, rng, c, chanfro=0.1), T((0, 1.0, 4.35)) @ R(20, "X"))  # cabeça baixa, projetada
    if u == "cinzas":
        for lado in (-1, 1):
            kit.juntar(bm, kit.espinho((lado * 0.35, 0.9, 4.75), (lado * 0.9, 0.5, 5.6), 0.3, p["pedra2"], 1.0))
    elif u == "mare":
        for k in range(4):
            kit.juntar(bm, kit.espinho((rng.uniform(-0.8, 0.8), 0.1, 3.9), (rng.uniform(-1.2, 1.2), -0.6, 4.8), 0.3, p["detalhe"], 1.0))
    else:
        kit.juntar(bm, kit.espinho((0, 0.6, 4.7), (0, -0.4, 6.0), 0.7, c, 1.0))  # capuz pontudo
        for lado in (-1, 1):
            kit.juntar(bm, kit.espinho((lado * 0.9, -0.3, 3.9), (lado * 2.2, -0.9, 4.9), 0.5, c, 1.0))
    return bm


def fazer_sombra_luz(u, p):
    bm = kit.novo_bm()
    for lado in (-1, 1):
        kit.juntar(bm, kit.fita3d([(lado * 0.15, 1.57, 4.45), (lado * 0.38, 1.55, 4.55)], 0.12, (0, 1, 0), BRANCO))
        for k in range(3):  # garras
            kit.juntar(bm, kit.espinho((lado * (1.3 + 0.15 * k), 1.55, 1.05), (lado * (1.35 + 0.25 * k), 2.1, 0.2), 0.16, BRANCO, 1.0))
    return bm


# ---------------------------------------------------------------- guardiões


def fazer_guardiao(u, p):
    rng = random.Random(4800 + len(u))
    bm = kit.novo_bm()
    c, d = p["corpo"], p["pedra2"]
    if u == "cinzas":
        # Arauto das Brasas: colosso de basalto, chifres enormes, punhos de pedra
        for lado in (-1, 1):
            membro(bm, (lado * 1.4, 0, 0), (lado * 1.5, 0.2, 4.0), 1.6, 1.7, rng, c, 3)
            kit.juntar(bm, kit.bloco(2.4, 3.0, 1.0, rng, d, chanfro=0.15), T((lado * 1.5, 0.6, 0.5)))
            membro(bm, (lado * 3.2, 0, 10.0), (lado * 4.2, 0.8, 6.5), 1.5, 1.4, rng, c, 2)
            membro(bm, (lado * 4.2, 0.8, 6.5), (lado * 4.0, 1.6, 3.2), 1.4, 1.5, rng, c, 2)
            kit.juntar(bm, kit.bloco(2.4, 2.4, 2.4, rng, d, chanfro=0.18), T((lado * 4.0, 1.7, 2.4)))  # punho
            kit.juntar(bm, kit.bloco(3.2, 3.0, 2.0, rng, d, chanfro=0.18), T((lado * 3.0, 0, 10.6)) @ R(lado * -15, "Y"))  # ombreira
            kit.juntar(bm, kit.espinho((lado * 1.0, 0.6, 13.0), (lado * 3.6, -0.6, 16.2), 1.1, d, 1.0))  # chifre
            kit.juntar(bm, kit.espinho((lado * 3.4, -0.2, 11.4), (lado * 4.4, -0.8, 13.4), 0.9, d, 1.0))
        for j in range(4):
            kit.juntar(bm, kit.bloco(4.8 + 0.6 * j, 3.2, 1.6, rng, c, chanfro=0.15), T((0, 0, 5.0 + 1.5 * j)))
        kit.juntar(bm, kit.bloco(2.4, 2.6, 2.2, rng, c, chanfro=0.15), T((0, 0.9, 12.0)))
    elif u == "mare":
        # Cavaleiro Afogado: armadura alta e esguia, capa em farrapos, tridente, corais
        for lado in (-1, 1):
            membro(bm, (lado * 1.0, 0, 0), (lado * 1.1, 0, 5.6), 1.1, 1.2, rng, c, 3)
            kit.juntar(bm, kit.bloco(2.4, 1.6, 1.6, rng, d, chanfro=0.14), T((lado * 2.5, 0, 11.0)) @ R(lado * -12, "Y"))
            for k in range(4):  # corais nas ombreiras
                kit.juntar(bm, kit.espinho((lado * (2.2 + 0.3 * k), rng.uniform(-0.4, 0.4), 11.6), (lado * (2.6 + 0.5 * k), rng.uniform(-0.8, 0.8), 13.0 + 0.4 * k), 0.35, p["detalhe"], 1.0))
        membro(bm, (-2.6, 0, 10.6), (-3.2, 1.2, 7.6), 1.0, 0.9, rng, c, 2)
        membro(bm, (2.6, 0, 10.6), (3.4, 1.6, 8.4), 1.0, 0.9, rng, c, 2)
        for j in range(5):
            kit.juntar(bm, kit.bloco(3.4 + 0.25 * j, 2.2, 1.3, rng, c, chanfro=0.14), T((0, 0, 6.0 + 1.2 * j)))
        kit.juntar(bm, kit.bloco(1.5, 1.7, 1.9, rng, c, chanfro=0.14), T((0, 0.2, 12.6)))  # elmo
        kit.juntar(bm, kit.espinho((0, 0.2, 13.4), (0, -1.6, 15.2), 0.7, d, 1.0))  # crista
        haste = [Vector((3.6, 1.8, 0.4 + 16.5 * j / 11)) for j in range(12)]
        kit.juntar(bm, kit.fita3d([tuple(v) for v in haste], 0.4, (0, 1, 0), d))
        kit.juntar(bm, kit.bloco(0.35, 0.35, 16.5, rng, d, chanfro=0.04), T((3.6, 1.8, 8.6)))
        for dx in (-0.9, 0, 0.9):
            kit.juntar(bm, kit.espinho((3.6 + dx, 1.8, 16.6), (3.6 + dx * 1.2, 1.8, 18.6 - abs(dx) * 0.5), 0.35, d, 1.0))
        for k in range(7):  # capa em farrapos
            x = -2.2 + 0.73 * k
            kit.juntar(bm, kit.espinho((x, -1.2, 11.5), (x * 1.2, -2.2, rng.uniform(0.8, 2.8)), 0.9, c, 1.0))
    else:
        # Espectro do Ocaso: flutua, capuz alto, garras longas, asas de lascas
        for j in range(7):
            f = j / 6
            kit.juntar(bm, kit.bloco(3.8 - 1.6 * f, 2.6 - 0.8 * f, 1.4, rng, c, chanfro=0.14), T((0, 0, 3.0 + 1.3 * j)) @ R(rng.uniform(-6, 6), "Z"))
        for k in range(9):  # manto que se desfaz embaixo
            a = 2 * math.pi * k / 9
            kit.juntar(bm, kit.espinho((1.6 * math.cos(a), 1.2 * math.sin(a), 3.4), (2.2 * math.cos(a), 1.6 * math.sin(a), 0.6 + 0.4 * (k % 2)), 1.1, c, 1.0))
        kit.juntar(bm, kit.espinho((0, 0.2, 11.0), (0, -0.8, 16.4), 2.6, c, 1.0))  # capuz
        for lado in (-1, 1):
            membro(bm, (lado * 2.0, 0.2, 10.0), (lado * 3.8, 1.6, 8.0), 0.8, 0.7, rng, c, 2)
            membro(bm, (lado * 3.8, 1.6, 8.0), (lado * 4.4, 2.8, 5.6), 0.7, 0.6, rng, c, 2)
            for k in range(5):  # asas de lascas
                kit.juntar(bm, kit.espinho((lado * 1.6, -0.8, 11.0 - 0.6 * k), (lado * (5.5 + 1.2 * k), -2.0 - 0.4 * k, 13.5 - 1.6 * k), 0.8, d, 1.0))
    return bm


def fazer_guardiao_luz(u, p):
    bm = kit.novo_bm()
    if u == "cinzas":
        kit.juntar(bm, kit.espinho((0, 1.65, 7.8), (0, 1.75, 10.2), 1.4, BRANCO, 1.0))  # coração de brasa
        for lado in (-1, 1):
            kit.juntar(bm, kit.fita3d([(lado * 0.3, 2.22, 12.3), (lado * 0.95, 2.2, 12.6)], 0.25, (0, 1, 0), BRANCO))
            for k in range(3):
                kit.juntar(bm, kit.fita3d([(lado * 4.0 + 0.4 * (k - 1), 2.95, 1.8), (lado * 4.0 + 0.5 * (k - 1), 2.95, 3.0)], 0.12, (0, 1, 0), BRANCO))
    elif u == "mare":
        kit.juntar(bm, kit.fita3d([(-0.55, 1.08, 12.75), (0.55, 1.08, 12.75)], 0.18, (0, 1, 0), BRANCO))  # visor
        for dx in (-0.9, 0, 0.9):
            kit.juntar(bm, kit.espinho((3.6 + dx, 2.0, 16.9), (3.6 + dx * 1.2, 2.0, 18.3 - abs(dx) * 0.5), 0.16, BRANCO, 1.0))
        kit.juntar(bm, kit.espinho((0, 1.15, 8.5), (0, 1.2, 10.5), 0.9, BRANCO, 1.0))
    else:
        for lado in (-1, 1):
            kit.juntar(bm, kit.espinho((lado * 0.35, 1.25, 13.0), (lado * 0.6, 1.3, 13.4), 0.25, BRANCO, 1.0))
            for k in range(3):
                kit.juntar(bm, kit.espinho((lado * (4.3 + 0.2 * k), 2.8, 5.6), (lado * (4.4 + 0.3 * k), 3.8, 3.6), 0.2, BRANCO, 1.0))
    return bm


# ---------------------------------------------------------------- fenda para o próximo andar


def fazer_portal(u, p):
    rng = random.Random(4900 + len(u))
    bm = kit.novo_bm()
    kit.juntar(bm, kit.torno([(6.5, 0), (6.0, 0.6), (0.3, 0.6)], 16, p["escura"], rng))
    for k in range(9):  # pedras flutuando em arco irregular
        a = math.radians(-10 + 200 * k / 8)
        r = 5.0 + rng.uniform(-0.3, 0.5)
        kit.juntar(bm, kit.bloco(1.6, 1.4, 1.5, rng, p["pedra2"], chanfro=0.12), T((r * math.cos(a), 0, 6.0 + r * math.sin(a))) @ R(rng.uniform(0, 60), "Y"))
    return bm


def fazer_portal_luz(u, p):
    rng = random.Random(4950 + len(u))
    bm = kit.novo_bm()
    pts = []
    for k in range(25):
        a = 2 * math.pi * k / 24
        j = 1 if k % 24 == 0 else rng.uniform(0.85, 1.12)
        pts.append((3.4 * math.cos(a) * j, 0.0, 6.0 + 4.4 * math.sin(a) * j))
    kit.juntar(bm, kit.fita3d(pts, 0.4, (0, 1, 0), BRANCO))
    kit.juntar(bm, kit.chapa([(x * 0.9, -0.05, 6.0 + (z - 6.0) * 0.9) for x, _, z in pts[:-1]], BRANCO, 0.35, dupla=True))
    return bm


PECAS = [
    # nome, função, material no jogo, colide
    ("piso", fazer_piso, "Slate", False),
    ("piso_luz", fazer_piso_luz, "Neon", False),
    ("pilar", fazer_pilar, "Basalt", True),
    ("muro", fazer_muro, "Basalt", True),
    ("rocha", fazer_rocha, "Slate", True),
    ("nucleo", fazer_nucleo, "Basalt", True),
    ("nucleo_luz", fazer_nucleo_luz, "Neon", False),
    ("sombra", fazer_sombra, "SmoothPlastic", False),
    ("sombra_luz", fazer_sombra_luz, "Neon", False),
    ("guardiao", fazer_guardiao, "SmoothPlastic", False),
    ("guardiao_luz", fazer_guardiao_luz, "Neon", False),
    ("portal", fazer_portal, "Basalt", False),
    ("portal_luz", fazer_portal_luz, "Neon", False),
]
UNIVERSOS = ["cinzas", "mare", "umbral"]


def escrever_kit(info):
    linhas = [
        "-- GERADO por assets/incursoes/source/generate_incursoes.py. Não editar à mão.",
        "-- Peças dos universos das Incursões: caixa (tamanho), centro da caixa a partir do pé da",
        "-- peça (studs do Roblox), se colide e o material. O servidor cria uma caixa com essas medidas",
        "-- (colisão e reserva) e cada cliente põe a malha 3D no lugar.",
        "return {",
        "\traioAndar = %g," % RAIO_ANDAR,
        "\tpecas = {",
    ]
    for nome, (tam, centro, colide, material) in sorted(info.items()):
        linhas.append(
            "\t\t%s = { tamanho = { %.3f, %.3f, %.3f }, centro = { %.3f, %.3f, %.3f }, colide = %s, material = \"%s\" },"
            % ((nome,) + tuple(tam) + tuple(centro) + ("true" if colide else "false", material))
        )
    linhas += ["\t},", "}", ""]
    with open(ARQ_KIT, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def main():
    for d in ("exports", "previews"):
        os.makedirs(os.path.join(DIR_BASE, d), exist_ok=True)
    for antigo in os.listdir(DIR_DADOS):
        if antigo.startswith("inc_"):
            os.remove(os.path.join(DIR_DADOS, antigo))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pedra = kit.criar_material("Inc_Pedra")
    corpo = kit.criar_material("Inc_Corpo", rugosidade=0.6)
    luz = kit.criar_material("Inc_Luz", emissao=5.0)
    info = {}
    total = 0
    for u in UNIVERSOS:
        p = PALETAS[u]
        for nome, fn, material, colide in PECAS:
            nome_c = "inc_%s_%s" % (u, nome)
            mat = luz if material == "Neon" else corpo if material == "SmoothPlastic" else pedra
            obj = kit.registrar(nome_c, fn(u, p), mat)
            bpy.context.scene.collection.objects.link(obj)
            v, t, _ = kit.escrever_luau(nome_c, obj)
            arq = os.path.join(DIR_DADOS, nome_c + ".luau")
            with open(arq, encoding="utf-8") as f:
                texto = f.read().split("\n", 2)
            texto[0] = "-- GERADO por assets/incursoes/source/generate_incursoes.py. Não editar à mão."
            texto[1] = "-- Peça das Incursões: posições (uint16), cores (uint8) e triângulos (uint16) em base64."
            with open(arq, "w", encoding="utf-8") as f:
                f.write("\n".join(texto))
            total += t
            pos, _, _ = kit.dados_da_malha(obj)
            mn = [min(q[i] for q in pos) for i in range(3)]
            mx = [max(q[i] for q in pos) for i in range(3)]
            info[nome_c] = ([max(mx[i] - mn[i], 0.05) for i in range(3)], [(mx[i] + mn[i]) / 2 for i in range(3)], colide, material)
            print("%-24s %6d tris" % (nome_c, t))
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.export_scene.fbx(filepath=os.path.join(DIR_BASE, "exports", nome_c + ".fbx"), use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", colors_type="SRGB", bake_anim=False)
            obj.hide_render = True
    print("total: %d triângulos (%d peças)" % (total, len(info)))
    escrever_kit(info)
    if "--render" in sys.argv:
        renderizar()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "incursoes.blend"), compress=True)


# ---------------------------------------------------------------- prévias (composição de exemplo)

COR_LUZ = {"cinzas": (1.0, 0.35, 0.12), "mare": (0.25, 0.65, 1.0), "umbral": (0.6, 0.3, 1.0)}
CEU = {"cinzas": (0.09, 0.03, 0.02), "mare": (0.01, 0.04, 0.08), "umbral": (0.04, 0.02, 0.07)}


def instancia(nome, loc, giro=0.0, escala=1.0, mat=None, col=None):
    fonte = kit.PECAS[nome]
    obj = bpy.data.objects.new(nome + "_i", fonte.data.copy() if mat else fonte.data)
    if mat:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    obj.location = loc
    obj.rotation_euler = (0, 0, math.radians(giro))
    obj.scale = (escala,) * 3
    col.objects.link(obj)
    return obj


def emissao(cor, forca):
    m = bpy.data.materials.new("luz")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    b.inputs["Emission Color"].default_value = (*cor, 1)
    b.inputs["Emission Strength"].default_value = forca
    return m


def renderizar():
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 40
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 1280, 720
    cena.view_settings.view_transform = "AgX"
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 90
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(55), 0, math.radians(150)))
    sol = bpy.context.object
    sol.data.energy = 1.6
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cena.camera = cam
    for i, u in enumerate(UNIVERSOS):
        col = bpy.data.collections.new(u)
        cena.collection.children.link(col)
        cl = COR_LUZ[u]
        luz = emissao(cl, 6.0)
        claro = emissao(tuple(min(c * 0.5 + 0.5, 1) for c in cl), 8.0)
        x0 = i * 400.0
        instancia("inc_%s_piso" % u, (x0, 0, 0), col=col)
        instancia("inc_%s_piso_luz" % u, (x0, 0, 0), mat=luz, col=col)
        rng = random.Random(77 + i)
        for k in range(8):
            a = 2 * math.pi * k / 8 + rng.uniform(-0.2, 0.2)
            r = rng.uniform(26, 50)
            nome = ["pilar", "muro", "rocha"][k % 3]
            instancia("inc_%s_%s" % (u, nome), (x0 + r * math.cos(a), r * math.sin(a), 0.3), giro=math.degrees(a) + 90, col=col)
        for a, r in ((140, 18), (40, 22)):
            pos = (x0 + r * math.cos(math.radians(a)), r * math.sin(math.radians(a)), 0.3)
            instancia("inc_%s_nucleo" % u, pos, col=col)
            instancia("inc_%s_nucleo_luz" % u, pos, mat=claro, col=col)
        for k in range(4):
            a = rng.uniform(0, 2 * math.pi)
            pos = (x0 + 12 * math.cos(a), 12 * math.sin(a) - 4, 0.3)
            instancia("inc_%s_sombra" % u, pos, giro=rng.uniform(150, 210), col=col)
            instancia("inc_%s_sombra_luz" % u, pos, giro=rng.uniform(150, 210), mat=luz, col=col)
        instancia("inc_%s_portal" % u, (x0, 46, 0.3), giro=180, col=col)
        instancia("inc_%s_portal_luz" % u, (x0, 46, 0.3), giro=180, mat=claro, col=col)
        # guardião ao lado, para a prévia dele
        instancia("inc_%s_guardiao" % u, (x0 + 200, 0, 0.3), giro=180, col=col)
        instancia("inc_%s_guardiao_luz" % u, (x0 + 200, 0, 0.3), giro=180, mat=luz, col=col)
        instancia("inc_%s_piso" % u, (x0 + 200, 0, 0), col=col)
        bpy.ops.object.light_add(type="POINT", location=(x0, 0, 14))
        bpy.context.object.data.energy = 60000
        bpy.context.object.data.color = cl
        bpy.ops.object.light_add(type="POINT", location=(x0 + 200, -14, 14))
        bpy.context.object.data.energy = 30000
        bpy.context.object.data.color = cl
    for i, u in enumerate(UNIVERSOS):
        mundo = bpy.data.worlds.new(u)
        mundo.use_nodes = True
        mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (*CEU[u], 1)
        cena.world = mundo
        x0 = i * 400.0
        for nome, origem, alvo, lente in (
            ("andar", (x0, -46, 20), (x0, 6, 2), 22),
            ("guardiao", (x0 + 200, -30, 9), (x0 + 200, 0, 8), 30),
        ):
            cam.location = origem
            cam.rotation_euler = (Vector(alvo) - Vector(origem)).to_track_quat("-Z", "Y").to_euler()
            cam.data.lens = lente
            cena.render.filepath = os.path.join(DIR_BASE, "previews", "%s_%s.jpg" % (u, nome))
            bpy.ops.render.render(write_still=True)
            print("prévia", u, nome)


if __name__ == "__main__":
    main()
