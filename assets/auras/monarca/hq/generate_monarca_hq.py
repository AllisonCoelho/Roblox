"""Monarca das Sombras em ALTA QUALIDADE, para importar manualmente no Roblox Studio.

Quatro soldados das sombras (cada um com corpo esculpido, armadura, esqueleto com ossos, textura
assada e malha de brilho) e a coroa do monarca. O jogo usa estes modelos sozinho quando eles
existem em ReplicatedStorage.AurasModelos com o mesmo nome; sem eles, usa as malhas simples.

Uso:
    python assets/auras/monarca/hq/generate_monarca_hq.py            # modelos + FBX + texturas
    python assets/auras/monarca/hq/generate_monarca_hq.py --render   # também as prévias

Saídas:
    exports/monarca_soldado_{cavaleiro,gigante,mago,formiga}.fbx, exports/monarca_coroa.fbx
    texturas/<nome>_cor.png, previews/<nome>.jpg, source/monarca_hq.blend
Passo a passo de importação: assets/auras/monarca/hq/IMPORTAR_NO_STUDIO.md
Os modelos olham para -Y e têm os pés em z = 0 (a coroa tem a base em z = 0).
"""

import math
import os
import random
import sys

sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import ferramentas as f  # noqa: E402

DIR_EXP = os.path.join(AQUI, "exports")
DIR_TEX = os.path.join(AQUI, "texturas")
DIR_PREV = os.path.join(AQUI, "previews")
DIR_SRC = os.path.join(AQUI, "source")

ESCURA = (0.012, 0.006, 0.028)
CLARA = (0.075, 0.04, 0.15)
VEIO = (0.38, 0.13, 0.85)
BRILHO = (0.62, 0.36, 1.0)


def humanoide(s, pose=None, curvado=0.0, braco=1.0, perna=1.0, larg=1.0, grosso=1.0, pernas=True):
    """Esqueleto para o modificador Skin. pose = {junta: (x, y, z)} troca a posição de juntas
    ANTES de ligar (ex.: mãos juntas segurando a espada). Frente = +Y."""
    g = grosso
    J = {
        "pelve": ((0, 0, 2.3 * s), 0.55 * s * g * larg, 0.45 * s * g),
        "barriga": ((0, 0.25 * curvado * s, 3.0 * s), 0.5 * s * g * larg, 0.42 * s * g),
        "peito": ((0, 0.6 * curvado * s, 3.75 * s), 0.72 * s * g * larg, 0.5 * s * g),
        "pescoco": ((0, 0.95 * curvado * s + 0.05 * s, 4.25 * s), 0.25 * s * g, 0.25 * s * g),
        "cabeca": ((0, 1.15 * curvado * s + 0.15 * s, 4.65 * s), 0.4 * s * g, 0.44 * s * g),
        "topo": ((0, 1.2 * curvado * s + 0.15 * s, 5.05 * s), 0.2 * s * g, 0.2 * s * g),
    }
    for lado, L in ((1, "L"), (-1, "R")):
        J["ombro." + L] = ((lado * 0.95 * s * larg, 0.55 * curvado * s, 3.95 * s), 0.3 * s * g, 0.3 * s * g)
        J["cotovelo." + L] = ((lado * 1.4 * s * larg, (0.6 * curvado + 0.25) * s, (3.95 - 1.0 * braco) * s), 0.22 * s * g, 0.22 * s * g)
        J["mao." + L] = ((lado * 1.45 * s * larg, (0.6 * curvado + 0.7) * s, (3.95 - 2.0 * braco) * s), 0.2 * s * g, 0.14 * s * g)
        J["quadril." + L] = ((lado * 0.48 * s * larg, 0, 2.15 * s), 0.3 * s * g, 0.3 * s * g)
        J["joelho." + L] = ((lado * 0.55 * s * larg, 0.3 * s, (2.15 - 1.0 * perna) * s), 0.24 * s * g, 0.24 * s * g)
        J["tornozelo." + L] = ((lado * 0.52 * s * larg, -0.05 * s, 0.25 * s), 0.18 * s * g, 0.18 * s * g)
        J["pe." + L] = ((lado * 0.52 * s * larg, 0.42 * s, 0.1 * s), 0.17 * s * g, 0.1 * s * g)
    for nome, p in (pose or {}).items():
        J[nome] = (p, J[nome][1], J[nome][2])
    e = f.Esqueleto()
    for nome, (p, rx, ry) in J.items():
        e.ponto(nome, p, rx, ry)
    e.liga("pelve", "barriga", 2)
    e.liga("barriga", "peito", 2)
    e.liga("peito", "pescoco")
    e.liga("pescoco", "cabeca")
    e.liga("cabeca", "topo")
    for L in ("L", "R"):
        e.liga("peito", "ombro." + L)
        e.liga("ombro." + L, "cotovelo." + L, 2)
        e.liga("cotovelo." + L, "mao." + L, 2)
        e.liga("pelve", "quadril." + L)
        e.liga("quadril." + L, "joelho." + L, 2)
        e.liga("joelho." + L, "tornozelo." + L, 2)
        e.liga("tornozelo." + L, "pe." + L)
    return e


def P(e, n):
    return e.pts[e.nomes[n]]


def ossos_de(e, extras=()):
    T = lambda n: tuple(P(e, n))  # noqa: E731
    lista = [
        ("Raiz", (0, 0, 0), (0, 0, 0.6), None),
        ("Quadril", T("pelve"), T("barriga"), "Raiz"),
        ("Tronco", T("barriga"), T("peito"), "Quadril"),
        ("Peito", T("peito"), T("pescoco"), "Tronco"),
        ("Cabeca", T("pescoco"), T("topo"), "Peito"),
        ("Braco.L", T("ombro.L"), T("cotovelo.L"), "Peito"),
        ("Antebraco.L", T("cotovelo.L"), T("mao.L"), "Braco.L"),
        ("Braco.R", T("ombro.R"), T("cotovelo.R"), "Peito"),
        ("Antebraco.R", T("cotovelo.R"), T("mao.R"), "Braco.R"),
        ("Coxa.L", T("quadril.L"), T("joelho.L"), "Quadril"),
        ("Canela.L", T("joelho.L"), T("tornozelo.L"), "Coxa.L"),
        ("Coxa.R", T("quadril.R"), T("joelho.R"), "Quadril"),
        ("Canela.R", T("joelho.R"), T("tornozelo.R"), "Coxa.R"),
    ]
    return lista + list(extras)


def capa(bm, e, s, rng, n=9, comp=3.2, larg=1.0):
    """Capa em tiras rasgadas: saem dos ombros/costas e caem atrás."""
    pe = P(e, "peito")
    for k in range(n):
        x = (-1 + 2 * k / (n - 1)) * larg * s
        f.chifre(bm, pe + Vector((x, -0.45 * s, 0.25 * s)), (x * 0.12, -0.35, -1), (0, -1, 0), comp * s * rng.uniform(0.85, 1.15), 0.28 * s, gancho=0.25, n=12, lados=6, achatar=0.18)


def ombreira(bm, e, s, L, lado, camadas=3, tam=1.0):
    o = P(e, "ombro." + L)
    for k in range(camadas):
        f.placa(bm, o + Vector((lado * (0.15 + 0.22 * k) * s, 0, (0.28 - 0.2 * k) * s)), (1.05 * s * tam, 1.1 * s * tam, 0.34 * s), (0, lado * (18 + 16 * k), 0), 0.1 * s, 1)
    f.chifre(bm, o + Vector((lado * 0.3 * s, 0, 0.4 * s)), (lado, -0.1, 0.9), (0, 0, 1), 0.8 * s * tam, 0.16 * s, gancho=0.4, n=10, lados=8)


# ---------------------------------------------------------------- os quatro soldados


def cavaleiro():
    """Comandante (estilo Igris): alto e esguio, elmo com penacho longo, ombreiras em camadas,
    capa comprida e a espada longa cravada à frente, segura com as duas mãos."""
    rng = random.Random(11)
    s = 1.25
    pose = {}
    for lado, L in ((1, "L"), (-1, "R")):
        pose["cotovelo." + L] = (lado * 1.05 * s, 0.75 * s, 3.2 * s)
        pose["mao." + L] = (lado * 0.16 * s, 1.15 * s, 3.25 * s)
    e = humanoide(s, pose, curvado=0.05, grosso=0.82, larg=0.95)
    corpo = e.corpo("corpo", 2)
    f.deslocar(corpo, 0.025, 2.0, 1)
    luz = bmesh.new()
    cab = P(e, "cabeca")
    f.placa(corpo, P(e, "peito") + Vector((0, 0.12 * s, 0)), (1.75 * s, 1.15 * s, 1.05 * s), (8, 0, 0), 0.14 * s, 1)  # peitoral
    f.placa(corpo, P(e, "barriga") + Vector((0, 0.05 * s, 0)), (1.2 * s, 0.95 * s, 0.6 * s), (0, 0, 0), 0.1 * s, 1)
    f.placa(corpo, cab + Vector((0, 0, 0.05 * s)), (0.92 * s, 1.0 * s, 1.05 * s), (0, 0, 0), 0.2 * s, 1)  # elmo
    f.chifre(corpo, cab + Vector((0, 0.42 * s, -0.12 * s)), (0, 1, -0.35), (0, 0, -1), 0.5 * s, 0.2 * s, gancho=0.3, n=10, lados=8)  # viseira em bico
    # penacho: sobe do topo do elmo e cai longo para trás
    pen = [cab + Vector((0, 0.05 - 0.02 * i * i * 0.9, 0.5 + 0.55 * math.sin(min(i / 5, 1) * math.pi * 0.9) - max(i - 5, 0) * 0.42)) * 1.0 for i in range(12)]
    f.tubo(corpo, [cab + (p - cab) * s for p in pen], [0.17 * s * (1 - (i / 11) ** 1.6) + 0.02 for i in range(12)], 8, achatar=0.45)
    for lado, L in ((1, "L"), (-1, "R")):
        ombreira(corpo, e, s, L, lado, 3)
        f.placa(corpo, P(e, "joelho." + L) + Vector((0, 0.18 * s, 0)), (0.5 * s, 0.4 * s, 0.6 * s), (0, 0, 0), 0.1 * s, 1)
        f.placa(corpo, P(e, "cotovelo." + L), (0.5 * s, 0.5 * s, 0.5 * s), (0, 0, 20), 0.1 * s, 1)
    capa(corpo, e, s, rng, 9, 3.3, 1.0)
    # espada longa: lâmina cravada no chão, guarda e cabo entre as mãos
    y = 1.15 * s
    topo = 3.55 * s
    f.tubo(corpo, [Vector((0, y, topo - (topo - 0.05) * i / 15)) for i in range(16)], [0.2 * s * (1 - 0.55 * (i / 15) ** 2.2) + 0.01 for i in range(16)], 8, achatar=0.28)
    f.tubo(corpo, [Vector((-0.75 * s + 1.5 * s * i / 9, y, topo + 0.12 * s * abs(i - 4.5) / 4.5)) for i in range(10)], [0.09 * s] * 10, 8)
    f.tubo(corpo, [Vector((0, y, topo + 0.8 * s * i / 5)) for i in range(6)], [0.075 * s] * 6, 8)
    f.esfera(corpo, Vector((0, y, topo + 0.88 * s)), 0.13 * s, 1)
    # brilho: olhos em fenda, fio da lâmina e runa no peito
    for lado in (1, -1):
        f.tubo(luz, [cab + Vector((lado * 0.08 * s, 0.52 * s, 0.02 * s)), cab + Vector((lado * 0.3 * s, 0.5 * s, 0.1 * s))], [0.035 * s, 0.02 * s], 6)
    f.tubo(luz, [Vector((0, y + 0.07 * s, topo - 0.2 * s - 2.9 * s * i / 7)) for i in range(8)], [0.03 * s] * 8, 6)
    pe = P(e, "peito")
    f.tubo(luz, [pe + Vector((x * s, 0.72 * s, z * s)) for x, z in ((-0.3, 0.25), (0, -0.05), (0.3, 0.25))], [0.035 * s] * 3, 6)
    return e, corpo, luz, ossos_de(e)


def gigante():
    """Gigante de armadura pesada: muito largo, ombros enormes, elmo pequeno com chifres laterais,
    escudo-torre no braço esquerdo e machado duplo apoiado no ombro direito."""
    rng = random.Random(12)
    s = 1.5
    pose = {
        "cotovelo.R": (-1.85 * s, 0.7 * s, 3.3 * s),
        "mao.R": (-1.55 * s, 0.75 * s, 4.25 * s),  # mão direita erguida segurando o cabo
        "cotovelo.L": (1.9 * s, 0.6 * s, 3.0 * s),
        "mao.L": (1.7 * s, 1.15 * s, 2.5 * s),
    }
    e = humanoide(s, pose, curvado=0.15, grosso=1.45, larg=1.35, perna=0.9)
    corpo = e.corpo("corpo", 2)
    f.deslocar(corpo, 0.04, 1.4, 2)
    luz = bmesh.new()
    cab = P(e, "cabeca")
    f.placa(corpo, P(e, "peito") + Vector((0, 0.2 * s, 0)), (2.9 * s, 1.9 * s, 1.5 * s), (6, 0, 0), 0.22 * s, 1)
    f.placa(corpo, P(e, "barriga") + Vector((0, 0.25 * s, -0.1 * s)), (2.4 * s, 1.8 * s, 1.0 * s), (0, 0, 0), 0.2 * s, 1)
    f.placa(corpo, cab, (0.95 * s, 1.0 * s, 0.95 * s), (0, 0, 0), 0.2 * s, 1)
    for lado, L in ((1, "L"), (-1, "R")):
        ombreira(corpo, e, s, L, lado, 3, 1.55)
        f.chifre(corpo, cab + Vector((lado * 0.4 * s, 0, 0.2 * s)), (lado, 0, 0.35), (0, 0, 1), 1.0 * s, 0.17 * s, gancho=0.6, n=12, lados=8)
        f.placa(corpo, P(e, "joelho." + L) + Vector((0, 0.25 * s, 0)), (0.85 * s, 0.6 * s, 0.9 * s), (0, 0, 0), 0.14 * s, 1)
    # escudo-torre
    ce = Vector((1.75 * s, 1.55 * s, 2.55 * s))
    f.placa(corpo, ce, (1.9 * s, 0.22 * s, 3.9 * s), (0, 0, -12), 0.09 * s, 2)
    f.chifre(corpo, ce + Vector((0, 0.1 * s, 0.3 * s)), (0.2, 1, 0), (0, 0, 1), 0.5 * s, 0.22 * s, gancho=0.1, n=8, lados=8)
    f.tubo(luz, [ce + Vector((0.55 * s * math.cos(a) - 0.05 * s, 0.17 * s + 0.11 * s * math.cos(a), 0.3 * s + 0.75 * s * math.sin(a))) for a in (2 * math.pi * i / 20 for i in range(21))], [0.04 * s] * 21, 6)
    # machado duplo no ombro
    mao = P(e, "mao.R")
    cabo = [mao + Vector((0.05 * s * i, -0.33 * s * i, 0.42 * s * i)) + Vector((-0.1 * s, 0.6 * s, -0.8 * s)) for i in range(9)]
    f.tubo(corpo, cabo, [0.1 * s] * 9, 8)
    topo = cabo[-1]
    for sinal in (1, -1):
        f.placa(corpo, topo + Vector((sinal * 0.75 * s, 0, 0)), (1.3 * s, 0.14 * s, 1.5 * s), (0, sinal * 14, 0), 0.06 * s, 1)
        f.tubo(luz, [topo + Vector((sinal * 1.42 * s, 0.0, (-0.7 + 1.4 * i / 5) * s)) for i in range(6)], [0.035 * s] * 6, 6)
    capa(corpo, e, s, rng, 7, 2.6, 1.3)
    f.tubo(luz, [cab + Vector((x * s, 0.5 * s, 0.03 * s)) for x in (-0.3, 0, 0.3)], [0.04 * s] * 3, 6)  # visor único
    return e, corpo, luz, ossos_de(e)


def mago():
    """Mago das sombras: encapuzado e curvado, manto longo em tiras (não se veem as pernas),
    presas, cajado alto com lua e orbe, e uma chama na mão erguida."""
    rng = random.Random(13)
    s = 1.15
    pose = {
        "cotovelo.L": (1.25 * s, 0.9 * s, 3.3 * s),
        "mao.L": (1.5 * s, 1.35 * s, 4.0 * s),  # mão erguida com a chama
        "cotovelo.R": (-1.2 * s, 0.85 * s, 3.1 * s),
        "mao.R": (-1.45 * s, 1.3 * s, 3.2 * s),  # segura o cajado
    }
    e = humanoide(s, pose, curvado=0.55, grosso=0.85, larg=0.9)
    corpo = e.corpo("corpo", 2)
    f.deslocar(corpo, 0.03, 2.0, 3)
    luz = bmesh.new()
    cab = P(e, "cabeca")
    # capuz fundo, com bico caído para trás
    f.chifre(corpo, cab + Vector((0, -0.05 * s, 0.05 * s)), (0, -0.75, 0.8), (0, -1, -0.8), 1.5 * s, 0.62 * s, gancho=0.7, n=16, lados=14)
    for lado in (1, -1):
        f.chifre(corpo, cab + Vector((lado * 0.2 * s, 0.4 * s, -0.25 * s)), (lado * 0.3, 0.4, 1), (0, 1, 0), 0.5 * s, 0.07 * s, gancho=0.4, n=8, lados=6)  # presas
        f.esfera(luz, cab + Vector((lado * 0.15 * s, 0.4 * s, 0.03 * s)), 0.07 * s, 1)
    # manto: tiras largas em volta do corpo todo, da cintura ao chão
    pv = P(e, "pelve")
    for k in range(16):
        a = 2 * math.pi * k / 16
        b = pv + Vector((0.5 * s * math.cos(a), 0.4 * s * math.sin(a), 0.5 * s))
        f.chifre(corpo, b, (0.4 * math.cos(a), 0.35 * math.sin(a), -1), (math.cos(a), math.sin(a), 0), rng.uniform(2.6, 3.1) * s, 0.42 * s, gancho=0.22, n=12, lados=6, achatar=0.3)
    for k in range(7):  # mangas largas
        for L in ("L", "R"):
            c = P(e, "cotovelo." + L)
            a = 2 * math.pi * k / 7
            f.chifre(corpo, c + Vector((0.12 * s * math.cos(a), 0, 0.12 * s * math.sin(a))), (0.3 * math.cos(a), -0.2, -1), (0, -1, 0), 0.95 * s, 0.16 * s, gancho=0.2, n=8, lados=6, achatar=0.3)
    # cajado
    mao = P(e, "mao.R")
    x, y = mao.x, mao.y + 0.1 * s
    f.tubo(corpo, [Vector((x + 0.03 * math.sin(i), y, 0.05 + 6.2 * s * i / 14)) for i in range(15)], [0.085 * s] * 15, 8)
    cz = 6.2 * s + 0.55 * s
    f.tubo(corpo, [Vector((x + 0.55 * s * math.cos(a), y, cz + 0.55 * s * math.sin(a))) for a in (math.radians(215 + 290 * i / 15) for i in range(16))], [0.11 * s * math.sin(math.pi * i / 15) + 0.02 for i in range(16)], 8, achatar=0.5)
    f.esfera(luz, Vector((x, y, cz)), 0.24 * s, 2)
    # chama na mão erguida
    ml = P(e, "mao.L")
    for k in range(5):
        f.chifre(luz, ml + Vector((0.1 * s * (k - 2), 0, 0.12 * s)), (0.15 * (k - 2), 0, 1), (1 if k % 2 else -1, 0, 0), (0.55 + 0.25 * (k % 2)) * s, 0.12 * s, gancho=0.5, n=10, lados=6)
    return e, corpo, luz, ossos_de(e)


def formiga():
    """Rei-formiga (estilo Beru): magro e curvado, carapaça segmentada, braços longos com garras,
    mandíbulas, antenas, abdômen com ferrão e quatro asas finas."""
    rng = random.Random(14)
    s = 1.12
    pose = {}
    for lado, L in ((1, "L"), (-1, "R")):
        pose["cotovelo." + L] = (lado * 1.75 * s, 0.75 * s, 3.1 * s)
        pose["mao." + L] = (lado * 1.55 * s, 1.5 * s, 2.2 * s)
        pose["joelho." + L] = (lado * 0.6 * s, -0.5 * s, 1.35 * s)  # joelho para trás (inseto)
        pose["tornozelo." + L] = (lado * 0.55 * s, 0.25 * s, 0.4 * s)
        pose["pe." + L] = (lado * 0.55 * s, 0.75 * s, 0.1 * s)
    e = humanoide(s, pose, curvado=0.7, grosso=0.62, larg=0.95, braco=1.2)
    # abdômen atrás (vira ossos Cauda1..3)
    e.ponto("abd1", (0, -0.7 * s, 2.25 * s), 0.5 * s, 0.45 * s)
    e.ponto("abd2", (0, -1.5 * s, 1.95 * s), 0.6 * s, 0.5 * s)
    e.ponto("abd3", (0, -2.3 * s, 1.55 * s), 0.3 * s, 0.26 * s)
    e.liga("pelve", "abd1")
    e.liga("abd1", "abd2", 2)
    e.liga("abd2", "abd3", 2)
    corpo = e.corpo("corpo", 2)
    f.deslocar(corpo, 0.02, 2.5, 4)
    luz = bmesh.new()
    cab = P(e, "cabeca")
    f.chifre(corpo, P(e, "abd3"), (0, -1, -0.35), (0, 0, -1), 0.75 * s, 0.16 * s, gancho=0.5, n=10, lados=8)  # ferrão
    for k in range(4):  # placas da carapaça nas costas
        p = P(e, "peito").lerp(P(e, "pelve"), k / 3)
        f.placa(corpo, p + Vector((0, -0.3 * s, 0)), (1.0 * s - 0.1 * s * k, 0.5 * s, 0.42 * s), (-25, 0, 0), 0.1 * s, 1)
    f.placa(corpo, cab + Vector((0, 0.05 * s, 0.1 * s)), (0.7 * s, 0.95 * s, 0.6 * s), (20, 0, 0), 0.16 * s, 1)  # cabeça alongada
    for lado, L in ((1, "L"), (-1, "R")):
        f.chifre(corpo, cab + Vector((lado * 0.18 * s, 0.42 * s, -0.22 * s)), (lado * 0.5, 1, -0.5), (-lado, 0.2, 0), 0.55 * s, 0.09 * s, gancho=0.8, n=10, lados=6)  # mandíbulas
        ant = [cab + Vector((lado * (0.18 + 0.1 * i) * s, (0.2 - 0.02 * i * i) * s, (0.3 + 0.38 * i - 0.035 * i * i) * s)) for i in range(8)]
        f.tubo(corpo, ant, [0.05 * s * (1 - i / 8) + 0.012 for i in range(8)], 6)
        f.chifre(corpo, P(e, "ombro." + L) + Vector((0, 0, 0.15 * s)), (lado, -0.3, 0.9), (0, 0, 1), 0.7 * s, 0.14 * s, gancho=0.5, n=10, lados=8)
        for k, (sobe, comp) in enumerate(((0.55, 3.6), (-0.25, 2.7))):  # asas
            base = P(e, "peito") + Vector((lado * 0.3 * s, -0.5 * s, 0.1 * s - 0.25 * s * k))
            f.chifre(corpo, base, (lado * 0.8, -0.75, sobe), (0, 0, -1), comp * s, 0.42 * s, gancho=0.12, n=12, lados=8, achatar=0.07)
        # garras brilhantes e olhos grandes inclinados
        m = P(e, "mao." + L)
        for k in range(3):
            f.chifre(luz, m + Vector((lado * 0.07 * s * (k - 1), 0.1 * s, -0.05 * s)), (lado * 0.3 * (k - 1), 0.75, -0.8), (0, 0, -1), 0.85 * s, 0.065 * s, gancho=0.5, n=10, lados=6)
        f.tubo(luz, [cab + Vector((lado * 0.12 * s, 0.5 * s, 0.1 * s)), cab + Vector((lado * 0.36 * s, 0.42 * s, 0.26 * s))], [0.07 * s, 0.035 * s], 6)
    extras = [
        ("Cauda1", tuple(P(e, "pelve")), tuple(P(e, "abd1")), "Quadril"),
        ("Cauda2", tuple(P(e, "abd1")), tuple(P(e, "abd2")), "Cauda1"),
        ("Cauda3", tuple(P(e, "abd2")), tuple(P(e, "abd3")), "Cauda2"),
    ]
    return e, corpo, luz, ossos_de(e, extras)


SOLDADOS = [("cavaleiro", cavaleiro), ("gigante", gigante), ("mago", mago), ("formiga", formiga)]


def coroa():
    """Coroa do monarca: aro duplo trabalhado, oito pontas afiadas (a da frente é a maior),
    arcos entre as pontas e gemas. Base em z = 0, frente em +Y (vira para -Y no fim)."""
    corpo, luz = bmesh.new(), bmesh.new()
    r = 0.62
    n = 64
    aro = [Vector((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), 0.1)) for i in range(n + 1)]
    f.tubo(corpo, aro, [0.1] * (n + 1), 10)
    f.tubo(corpo, [p * 1.05 + Vector((0, 0, 0.2)) for p in aro], [0.045] * (n + 1), 8)
    f.tubo(corpo, [p * 1.05 + Vector((0, 0, -0.08)) for p in aro], [0.04] * (n + 1), 8)
    for j in range(8):
        a = math.pi / 2 + 2 * math.pi * j / 8
        alto = 0.95 if j == 0 else 0.62 if j % 2 == 0 else 0.42
        fora = Vector((math.cos(a), math.sin(a), 0))
        base = fora * r + Vector((0, 0, 0.15))
        f.chifre(corpo, base, fora * 0.22 + Vector((0, 0, 1)), fora, alto, 0.13, gancho=0.22, n=14, lados=10, achatar=0.6)
        # arco baixo ligando esta ponta à próxima
        a2 = a + 2 * math.pi / 8
        arco = [Vector((r * 1.02 * math.cos(a + (a2 - a) * t), r * 1.02 * math.sin(a + (a2 - a) * t), 0.22 + 0.16 * math.sin(math.pi * t))) for t in (i / 8 for i in range(9))]
        f.tubo(corpo, arco, [0.03] * 9, 6)
        # gema na base de cada ponta (a da frente é maior)
        g = 0.1 if j == 0 else 0.055
        f.esfera(luz, fora * (r + 0.1) + Vector((0, 0, 0.12 if j else 0.16)), g, 1)
    return corpo, luz


# ---------------------------------------------------------------- finalização e exportação

GIRO = Matrix.Rotation(math.pi, 4, "Z")  # frente +Y -> -Y


def malha_obj(nome, bm):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    return f.objeto(nome, me)


def exportar(nome, objs, com_rig):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(DIR_EXP, nome + ".fbx"),
        use_selection=True,
        object_types={"ARMATURE", "MESH"} if com_rig else {"MESH"},
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        use_armature_deform_only=True,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
    )


def finalizar_soldado(tipo, fn):
    nome = "monarca_soldado_" + tipo
    e, corpo_bm, luz_bm, ossos = fn()
    corpo = malha_obj(nome, corpo_bm)
    f.reduzir(corpo, 15000)
    for p in corpo.data.polygons:
        p.use_smooth = True
    luz = malha_obj(nome + "_Brilho", luz_bm)
    luz.data.materials.append(f.material_brilho(nome + "_Brilho", BRILHO))
    rig = f.armadura(nome, ossos)
    for o in (corpo, luz):
        o.data.transform(GIRO)
    f.ativar(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for b in rig.data.edit_bones:
        b.transform(GIRO)
    bpy.ops.object.mode_set(mode="OBJECT")
    girados = [(n, tuple(GIRO @ Vector(c)), tuple(GIRO @ Vector(t)), p) for n, c, t, p in ossos]
    f.uv_e_bake(corpo, nome, f.material_procedural(nome + "_proc", ESCURA, CLARA, VEIO, 2.2), DIR_TEX)
    f.pesar(corpo, rig, girados)
    f.pesar(luz, rig, girados)
    tris = sum(len(p.vertices) - 2 for p in corpo.data.polygons) + sum(len(p.vertices) - 2 for p in luz.data.polygons)
    alt = max(v.co.z for v in corpo.data.vertices)
    print("%-28s %6d triângulos, %2d ossos, altura %.1f" % (nome, tris, len(ossos), alt))
    exportar(nome, [rig, corpo, luz], True)
    return [rig, corpo, luz]


def finalizar_coroa():
    nome = "monarca_coroa"
    corpo_bm, luz_bm = coroa()
    corpo = malha_obj(nome, corpo_bm)
    luz = malha_obj(nome + "_Brilho", luz_bm)
    luz.data.materials.append(f.material_brilho(nome + "_Brilho", BRILHO))
    for o in (corpo, luz):
        o.data.transform(GIRO)
    f.uv_e_bake(corpo, nome, f.material_procedural(nome + "_proc", (0.02, 0.012, 0.04), (0.16, 0.1, 0.3), VEIO, 6.0), DIR_TEX, 512)
    tris = sum(len(p.vertices) - 2 for p in corpo.data.polygons) + sum(len(p.vertices) - 2 for p in luz.data.polygons)
    print("%-28s %6d triângulos" % (nome, tris))
    exportar(nome, [corpo, luz], False)
    return [corpo, luz]


def renderizar(modelos):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 48
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 800, 900
    cena.view_settings.view_transform = "AgX"
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 90
    mundo = bpy.data.worlds.new("w")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.06, 0.05, 0.1, 1)
    cena.world = mundo
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    chao = bpy.context.object
    m = bpy.data.materials.new("chao")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.045, 0.08, 1)
    chao.data.materials.append(m)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(25)))
    bpy.context.object.data.energy = 5
    bpy.context.object.data.color = (0.8, 0.8, 1.0)
    bpy.ops.object.light_add(type="AREA", location=(-8, -12, 9))
    luz = bpy.context.object
    luz.data.energy = 2500
    luz.data.size = 8
    luz.data.color = (0.75, 0.6, 1.0)
    luz.rotation_euler = (Vector((0, 0, 3)) - luz.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cena.camera = cam
    todos = [o for objs in modelos.values() for o in objs]
    for nome, objs in modelos.items():
        for o in todos:
            o.hide_render = o not in objs
        corpo = [o for o in objs if o.type == "MESH"][0]
        alt = max(v.co.z for v in corpo.data.vertices)
        alvo = Vector((0, 0, alt * 0.5))
        for sufixo, graus in (("", 28), ("_costas", 150)):
            a = math.radians(graus)
            dist = max(alt * 2.2, 2.6)
            cam.location = alvo + Vector((math.sin(a) * dist, -math.cos(a) * dist, alt * 0.2))
            cam.rotation_euler = (alvo - cam.location).to_track_quat("-Z", "Y").to_euler()
            cam.data.lens = 50
            cena.render.filepath = os.path.join(DIR_PREV, nome + sufixo + ".jpg")
            bpy.ops.render.render(write_still=True)
        print("prévia", nome)


def main():
    for d in (DIR_EXP, DIR_TEX, DIR_PREV, DIR_SRC):
        os.makedirs(d, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    modelos = {}
    for tipo, fn in SOLDADOS:
        modelos["monarca_soldado_" + tipo] = finalizar_soldado(tipo, fn)
    modelos["monarca_coroa"] = finalizar_coroa()
    if "--render" in sys.argv:
        renderizar(modelos)
    for i, objs in enumerate(modelos.values()):  # espalha no .blend para ver todos
        for o in objs:
            if o.parent is None:
                o.location = (i * 9.0, 0, 0)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_SRC, "monarca_hq.blend"), compress=True)


if __name__ == "__main__":
    main()
