"""Gera o Corredor dos Perdidos no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/corredor/source/generate_corredor.py            # malhas, cena e mapa
    python assets/corredor/source/generate_corredor.py --render   # também as prévias

O Corredor fica no MESMO mapa do Nexo: seis mundos fragmentados flutuam em espiral no céu da
praça, cada um um pouco mais alto que o anterior. Cada fase é uma ilha comprida partida em três
pedaços, com trilha, cenário do tema, um portal de volta ao Nexo no começo e o Portão da fase
seguinte no fim. As criaturas entram depois.

Saídas:
    src/client/Mundo/Nexo3D/Dados/corredor_*.luau   geometria (mesmo formato do kit do Nexo)
    src/client/Mundo/Nexo3D/CenaCorredor.luau       onde cada peça fica (cliente monta)
    src/shared/Dados/CorredorMapa.luau              pontos de cada fase e colisão (servidor)
    assets/corredor/source/corredor.blend           cena editável
    assets/corredor/previews/*.jpg                  renders do Blender (NÃO são prints do Roblox)

Espaço de uma ilha (Blender): origem no centro, topo da trilha em z = 0, a trilha anda de
y = -L/2 (começo) até y = +L/2 (Portão). No Roblox isso vira (x, z, -y): a frente é -Z.
"""

import math
import os
import random
import struct
import base64
import sys

sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "assets", "nexo", "source"))

import bpy  # noqa: E402
import bmesh  # noqa: E402

import generate_nexo as kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

DIR_BASE = os.path.join(RAIZ, "assets", "corredor")
DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Nexo3D", "Dados")
ARQ_CENA = os.path.join(RAIZ, "src", "client", "Mundo", "Nexo3D", "CenaCorredor.luau")
ARQ_MAPA = os.path.join(RAIZ, "src", "shared", "Dados", "CorredorMapa.luau")

T = Matrix.Translation

# Medidas comuns
COMPRIMENTO = 150.0  # da entrada ao Portão
LARGURA = 44.0
TRILHA = 10.0
PEDACOS = [(-75.0, -27.0), (-23.0, 23.0), (27.0, 75.0)]  # três fragmentos, vãos de 4 studs
RAIO = 172.0  # distância do centro da praça
ANGULO_INICIAL = 105.0  # fase 1 acima dos Portais Fragmentados (135°), girando no sentido horário
PASSO_ANGULO = 60.0
ALTURA_INICIAL = 95.0
PASSO_ALTURA = 22.0

# Temas: rocha (lados/baixo), chao (superfície), trilha, energia (Neon), detalhe (props), vidro
TEMAS = [
    {
        "nome": "Limiar Partido",
        "rocha": (0.36, 0.34, 0.44),
        "escura": (0.12, 0.11, 0.17),
        "chao": (0.42, 0.40, 0.50),
        "trilha": (0.56, 0.53, 0.66),
        "energia": (0.62, 0.40, 0.98),
        "detalhe": (0.30, 0.28, 0.36),
        "vidro": (0.72, 0.55, 1.00),
    },
    {
        "nome": "Bosque de Vidro",
        "rocha": (0.28, 0.33, 0.36),
        "escura": (0.08, 0.12, 0.14),
        "chao": (0.20, 0.38, 0.32),
        "trilha": (0.48, 0.56, 0.54),
        "energia": (0.35, 1.00, 0.80),
        "detalhe": (0.30, 0.24, 0.26),
        "vidro": (0.55, 1.00, 0.92),
    },
    {
        "nome": "Dunas de Cinza",
        "rocha": (0.20, 0.18, 0.21),
        "escura": (0.07, 0.05, 0.06),
        "chao": (0.38, 0.33, 0.31),
        "trilha": (0.50, 0.42, 0.37),
        "energia": (1.00, 0.45, 0.12),
        "detalhe": (0.10, 0.08, 0.10),
        "vidro": (1.00, 0.55, 0.25),
    },
    {
        "nome": "Maré Suspensa",
        "rocha": (0.28, 0.34, 0.46),
        "escura": (0.07, 0.10, 0.18),
        "chao": (0.62, 0.78, 0.90),
        "trilha": (0.80, 0.90, 0.98),
        "energia": (0.30, 0.90, 1.00),
        "detalhe": (0.40, 0.55, 0.70),
        "vidro": (0.60, 0.92, 1.00),
    },
    {
        "nome": "Catedral Quebrada",
        "rocha": (0.55, 0.52, 0.58),
        "escura": (0.20, 0.18, 0.22),
        "chao": (0.80, 0.77, 0.84),
        "trilha": (0.92, 0.88, 0.80),
        "energia": (1.00, 0.78, 0.30),
        "detalhe": (0.86, 0.83, 0.88),
        "vidro": (1.00, 0.86, 0.45),
    },
    {
        "nome": "Coração do Vazio",
        "rocha": (0.10, 0.08, 0.14),
        "escura": (0.02, 0.01, 0.04),
        "chao": (0.16, 0.12, 0.22),
        "trilha": (0.26, 0.20, 0.34),
        "energia": (0.92, 0.30, 1.00),
        "detalhe": (0.06, 0.05, 0.09),
        "vidro": (0.95, 0.45, 1.00),
    },
]


# ---------------------------------------------------------------- utilidades


def montar(partes):
    """Junta bmeshes (com matriz opcional) num só."""
    bm = kit.novo_bm()
    for item in partes:
        if isinstance(item, tuple):
            kit.juntar(bm, item[0], item[1])
        else:
            kit.juntar(bm, item)
    return bm


def contorno(y0, y1, meia, rng, pontos=7):
    """Contorno recortado de um fragmento (planta), sentido anti-horário."""
    esq, dir_ = [], []
    for k in range(pontos + 1):
        y = y0 + (y1 - y0) * k / pontos
        borda = 1.0 if 0 < k < pontos else 0.82
        dir_.append((meia * borda + rng.uniform(-2.6, 1.2), y + rng.uniform(-1.2, 1.2)))
        esq.append((-meia * borda - rng.uniform(-2.6, 1.2), y + rng.uniform(-1.2, 1.2)))
    return dir_ + list(reversed(esq))


def fragmento(y0, y1, tema, rng):
    """Pedaço de mundo flutuando: topo plano em z = 0 e um cone de rocha quebrada embaixo."""
    meia = LARGURA / 2
    topo = contorno(y0, y1, meia, rng)
    pts = [(x, y, 0.0) for x, y in topo]
    # saia logo abaixo do topo (mantém a borda grossa) e as pontas do fundo
    pts += [(x * 0.94, y, -4.5 - rng.uniform(0, 1.5)) for x, y in topo]
    meio = (y0 + y1) / 2
    comp = y1 - y0
    for _ in range(9):
        r = rng.uniform(0.25, 0.8)
        a = rng.uniform(0, 2 * math.pi)
        pts.append((math.cos(a) * meia * r, meio + math.sin(a) * comp * 0.42 * r, -rng.uniform(12, 24)))
    pts.append((rng.uniform(-4, 4), meio + rng.uniform(-6, 6), -rng.uniform(34, 46)))
    corpo = kit.casco(pts, tema["rocha"], 1.0, gradiente=(-40, 0, tema["escura"], tema["rocha"]))
    # pingentes de rocha soltos embaixo (leitura de "mundo fragmentado")
    pingentes = []
    for _ in range(3):
        cx, cy = rng.uniform(-meia * 0.6, meia * 0.6), meio + rng.uniform(-comp * 0.35, comp * 0.35)
        topo_z = -rng.uniform(6, 12)
        p2 = [(cx + rng.uniform(-3, 3), cy + rng.uniform(-3, 3), topo_z) for _ in range(5)]
        p2.append((cx, cy, topo_z - rng.uniform(14, 26)))
        pingentes.append(kit.casco(p2, tema["rocha"], 0.9, gradiente=(topo_z - 26, topo_z, tema["escura"], tema["rocha"])))
    return montar([corpo] + pingentes), topo


def superficie(topo, tema):
    """Camada da superfície (grama, cinza, gelo, mármore...) por cima do topo do fragmento."""
    return kit.chapa([(x * 0.985, y, 0.06) for x, y in topo], tema["chao"], 1.0)


def pedras_ponte(rng, tema):
    """Lajes que cobrem os vãos entre os fragmentos: dá para atravessar sem pular."""
    partes = []
    blocos = []
    for (a0, a1), (b0, b1) in zip(PEDACOS, PEDACOS[1:]):
        meio = (a1 + b0) / 2
        for x in (-2.6, 2.6):
            bm = kit.bloco(4.6, 6.4, 1.2, rng, tema["trilha"], chanfro=0.12)
            partes.append((bm, T((x, meio, -0.6)) @ Matrix.Rotation(rng.uniform(-0.08, 0.08), 4, "Z")))
            blocos.append(((x, meio, -0.6), (4.6, 6.4, 1.2)))
    return montar(partes), blocos


def trilha(rng, tema):
    """Lajes da trilha central, de ponta a ponta, sobre os fragmentos."""
    partes = []
    y = -72.0
    while y < 66:
        if all(not (a1 < y < b0) for (_, a1), (b0, _) in zip(PEDACOS, PEDACOS[1:])):
            for x in (-2.5, 2.5):
                bm = kit.bloco(4.6, 4.4, 0.4, rng, tema["trilha"], chanfro=0.0, tremor=0.04)
                partes.append((bm, T((x + rng.uniform(-0.2, 0.2), y, 0.12)) @ Matrix.Rotation(rng.uniform(-0.05, 0.05), 4, "Z")))
        y += 4.8
    return montar(partes)


def energia_trilha(rng, tema):
    """Runas de energia nas bordas da trilha e rachaduras acesas nos fragmentos."""
    partes = []
    for lado in (-1, 1):
        for y0, y1 in PEDACOS:
            y = y0 + 4
            while y < y1 - 6:
                comp = rng.uniform(5, 9)
                partes.append(kit.fita([(lado * 6.6, y), (lado * 6.6, min(y + comp, y1 - 3))], 0.35, 0.2, tema["energia"]))
                y += comp + rng.uniform(2, 4)
    for y0, y1 in PEDACOS:
        for _ in range(3):
            x = rng.choice((-1, 1)) * rng.uniform(10, 18)
            y = rng.uniform(y0 + 5, y1 - 5)
            partes.append(kit.fita(kit.zigue((x, y), (x + rng.uniform(-5, 5), y + rng.uniform(-7, 7)), 4, 1.2, rng), 0.3, 0.1, tema["energia"]))
        partes.append(kit.losango(rng.uniform(-14, 14), (y0 + y1) / 2 + rng.uniform(-8, 8), 0.12, 2.2, tema["energia"], rng.uniform(0, 3)))
    return montar(partes)


# ---------------------------------------------------------------- portais


def arco(largura, altura, espessura, cor, rng, quebrado=False):
    """Arco de pedra (dois pilares e verga em ogiva de blocos)."""
    partes = []
    meia = largura / 2
    for lado in (-1, 1):
        alto = altura * (0.55 if quebrado and lado == 1 else 1.0)
        n = 4
        for k in range(n):
            h = alto / n
            bm = kit.bloco(espessura * 1.15 if k == 0 else espessura, espessura, h * 0.96, rng, cor, chanfro=0.15)
            partes.append((bm, T((lado * (meia + espessura / 2), 0, h * k + h / 2))))
    if not quebrado:
        n = 9
        for k in range(n):
            a0 = math.pi * k / n
            a1 = math.pi * (k + 1) / n
            am = (a0 + a1) / 2
            r = meia + espessura / 2
            x, z = r * math.cos(am), altura + r * 0.55 * math.sin(am)
            bm = kit.bloco(espessura * 0.95, espessura, r * (a1 - a0) * 1.15, rng, cor, chanfro=0.15)
            rot = Matrix.Rotation(-(math.pi / 2 - am) * 0.9, 4, "Y")
            partes.append((bm, T((x, 0, z)) @ rot))
        partes.append((kit.espinho((0, 0, altura + meia * 0.55 + espessura * 0.4), (0, 0, altura + meia * 0.55 + espessura * 2.6), espessura * 0.9, cor), None))
    return montar(partes)


def veu(largura, altura, cor):
    """Véu de energia que preenche o arco (plano nos dois lados)."""
    meia = largura / 2
    pts = [(-meia, 0, 0), (meia, 0, 0), (meia, 0, altura)]
    for k in range(1, 8):
        a = math.pi * k / 8
        pts.append((meia * math.cos(a), 0, altura + meia * 0.55 * math.sin(a)))
    pts.append((-meia, 0, altura))
    return kit.chapa(pts, cor, 1.0, dupla=True)


# ---------------------------------------------------------------- cenário por tema


def cristal(rng, escala, cor, gradiente=None):
    pts = [(x * escala, y * escala, (z + 6.0) * escala) for x, y, z in kit.pontos_cristal(rng)]
    return kit.casco(pts, cor, 1.0, gradiente=gradiente)


def aglomerado(rng, cor, n=4, escala=0.5):
    partes = []
    for _ in range(n):
        e = escala * rng.uniform(0.55, 1.2)
        rot = Matrix.Rotation(rng.uniform(-0.45, 0.45), 4, "X") @ Matrix.Rotation(rng.uniform(-0.45, 0.45), 4, "Y")
        partes.append((cristal(rng, e, cor), T((rng.uniform(-1.8, 1.8), rng.uniform(-1.8, 1.8), 0)) @ rot))
    return montar(partes)


def pilar_partido(rng, cor, altura):
    partes = []
    z = 0
    n = rng.randint(2, 4)
    for k in range(n):
        h = altura / 4 * rng.uniform(0.8, 1.1)
        bm = kit.bloco(2.6 - 0.15 * k, 2.6 - 0.15 * k, h, rng, cor, chanfro=0.18)
        partes.append((bm, T((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), z + h / 2)) @ Matrix.Rotation(rng.uniform(-0.12, 0.12), 4, "Z")))
        z += h
    return montar(partes), z


def coluna(rng, cor, altura):
    perfil = [(1.7, 0), (1.7, 0.8), (1.3, 1.0), (1.2, altura - 1.0), (1.6, altura - 0.6), (1.6, altura)]
    return kit.torno(perfil, 12, cor, rng, estrela=0.08)


def arvore_vidro(rng, tronco, vidro):
    partes = []
    altura = rng.uniform(9, 13)
    pts = []
    for z in (0, altura * 0.5, altura):
        largura = 0.9 if z == 0 else 0.5
        for a in range(4):
            ang = a * math.pi / 2 + rng.uniform(-0.2, 0.2)
            pts.append((math.cos(ang) * largura + (z / altura) * 0.8, math.sin(ang) * largura, z))
    partes.append(kit.casco(pts, tronco, 1.0))
    for _ in range(5):
        e = rng.uniform(0.45, 0.75)
        rot = Matrix.Rotation(rng.uniform(-0.9, 0.9), 4, "X") @ Matrix.Rotation(rng.uniform(-0.9, 0.9), 4, "Y")
        partes.append((cristal(rng, e, vidro), T((0.8 + rng.uniform(-2, 2), rng.uniform(-2, 2), altura - 1 + rng.uniform(-1, 1.5))) @ rot))
    return montar(partes), altura


def braseiro(rng, cor):
    perfil = [(0.9, 0), (0.6, 0.4), (0.5, 2.6), (1.6, 3.4), (1.8, 4.0)]
    return kit.torno(perfil, 8, cor, rng)


def chama(rng, cor):
    partes = []
    for _ in range(4):
        a = rng.uniform(0, 2 * math.pi)
        partes.append(kit.espinho((math.cos(a) * 0.5, math.sin(a) * 0.5, 3.8), (math.cos(a) * 0.3, math.sin(a) * 0.3, 3.8 + rng.uniform(1.4, 2.6)), 0.7, cor))
    return montar(partes)


def monolito(rng, cor, altura):
    return kit.bloco(3.2, 1.6, altura, rng, cor, chanfro=0.2, tremor=0.08)


def estatua(rng, cor):
    """Guardião antigo de pedra, sem rosto, de braços cruzados (blocos)."""
    partes = [
        (kit.bloco(2.6, 2.0, 1.2, rng, cor), T((0, 0, 0.6))),
        (kit.bloco(1.8, 1.3, 3.8, rng, cor), T((0, 0, 3.1))),
        (kit.bloco(2.9, 1.5, 2.4, rng, cor), T((0, 0, 5.9))),
        (kit.bloco(1.3, 1.3, 1.4, rng, cor), T((0, 0, 7.9))),
        (kit.bloco(3.3, 0.9, 0.8, rng, cor), T((0, -0.75, 5.6))),
    ]
    return montar(partes)


def lados(rng, y0, y1, passos):
    """Posições ao longo das bordas, longe da trilha (x entre 9 e 19)."""
    saida = []
    for k in range(passos):
        y = y0 + (y1 - y0) * (k + 0.5) / passos + rng.uniform(-3, 3)
        for lado in (-1, 1):
            if rng.random() < 0.85:
                saida.append((lado * rng.uniform(10.5, 18.5), y, lado))
    return saida


def cenario(i, tema, rng):
    """Peças do tema: (props sólidos, cristais/vidro, energia extra, colisores locais)."""
    props, vidros, energia, colisores = [], [], [], []

    def caixa(x, y, z, sx, sy, sz):
        colisores.append(((x, y, z), (sx, sy, sz)))

    for y0, y1 in PEDACOS:
        for x, y, lado in lados(rng, y0 + 5, y1 - 5, 2):
            r = rng.random()
            if i == 0:  # Limiar Partido: pilares partidos e cristais violeta
                if r < 0.55:
                    bm, alto = pilar_partido(rng, tema["detalhe"], rng.uniform(8, 14))
                    props.append((bm, T((x, y, 0))))
                    caixa(x, y, alto / 2, 2.8, 2.8, alto)
                else:
                    vidros.append((aglomerado(rng, tema["vidro"], 4, 0.55), T((x, y, 0))))
            elif i == 1:  # Bosque de Vidro: árvores de cristal e arbustos brilhantes
                if r < 0.6:
                    bm, alto = arvore_vidro(rng, tema["detalhe"], tema["vidro"])
                    props.append((bm, T((x, y, 0)) @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z")))
                    caixa(x, y, alto / 2, 1.8, 1.8, alto)
                else:
                    vidros.append((aglomerado(rng, tema["vidro"], 5, 0.32), T((x, y, 0))))
            elif i == 2:  # Dunas de Cinza: espinhos de obsidiana e braseiros
                if r < 0.5:
                    alto = rng.uniform(7, 13)
                    props.append(kit.espinho((x, y, -0.5), (x + rng.uniform(-2, 2), y + rng.uniform(-2, 2), alto), rng.uniform(2.5, 3.6), tema["detalhe"]))
                    caixa(x, y, alto / 3, 2.4, 2.4, alto / 1.5)
                else:
                    props.append((braseiro(rng, tema["detalhe"]), T((x, y, 0))))
                    energia.append((chama(rng, tema["energia"]), T((x, y, 0))))
                    caixa(x, y, 2.0, 3.2, 3.2, 4.0)
            elif i == 3:  # Maré Suspensa: lâminas de gelo e bolhas de água presas no ar
                if r < 0.6:
                    alto = rng.uniform(6, 12)
                    vidros.append(kit.espinho((x, y, -0.5), (x + rng.uniform(-1.5, 1.5), y, alto), rng.uniform(1.8, 2.8), tema["vidro"]))
                    caixa(x, y, alto / 3, 2.0, 2.0, alto / 1.5)
                else:
                    z = rng.uniform(4, 8)
                    perfil = [(0.01, -1.6), (1.1, -1.2), (1.6, 0), (1.1, 1.2), (0.01, 1.6)]
                    energia.append((kit.torno(perfil, 10, tema["energia"], rng), T((x, y, z))))
            elif i == 4:  # Catedral Quebrada: colunas caneladas, estátuas e arcos partidos
                if r < 0.5:
                    alto = rng.uniform(10, 16)
                    props.append((coluna(rng, tema["detalhe"], alto), T((x, y, 0))))
                    caixa(x, y, alto / 2, 3.2, 3.2, alto)
                elif r < 0.8:
                    props.append((estatua(rng, tema["detalhe"]), T((x, y, 0)) @ Matrix.Rotation(math.pi / 2 * -lado, 4, "Z")))
                    caixa(x, y, 4.2, 3.0, 2.2, 8.4)
                else:
                    props.append((arco(6, 7, 1.4, tema["detalhe"], rng, quebrado=True), T((x, y, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")))
                    caixa(x, y - 3.7, 4.0, 1.6, 1.6, 8.0)
                    caixa(x, y + 3.7, 2.2, 1.6, 1.6, 4.4)
            else:  # Coração do Vazio: monólitos com costuras acesas e cubos à deriva
                if r < 0.6:
                    alto = rng.uniform(9, 17)
                    rot = Matrix.Rotation(rng.uniform(-0.12, 0.12), 4, "X") @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Z")
                    props.append((monolito(rng, tema["detalhe"], alto), T((x, y, alto / 2 - 0.4)) @ rot))
                    energia.append(kit.fita3d([(x, y + 0.85, 0.5), (x + 0.2, y + 0.85, alto * 0.8)], 0.3, (0, 1, 0), tema["energia"]))
                    caixa(x, y, alto / 2, 3.4, 3.4, alto)
                else:
                    for k in range(3):
                        s = rng.uniform(0.8, 1.8)
                        rot = Matrix.Rotation(rng.uniform(0, 6.28), 4, "X") @ Matrix.Rotation(rng.uniform(0, 6.28), 4, "Y")
                        props.append((kit.bloco(s, s, s, rng, tema["detalhe"], chanfro=0.05), T((x + rng.uniform(-2, 2), y + rng.uniform(-2, 2), 3 + k * 2.4)) @ rot))
    return props, vidros, energia, colisores


def ilha(i, tema):
    """Todas as peças de uma fase, no espaço local da ilha."""
    rng = random.Random(4100 + i * 37)
    corpo, topos, superficies = [], [], []
    colisores = []
    for y0, y1 in PEDACOS:
        bm, topo = fragmento(y0, y1, tema, rng)
        corpo.append(bm)
        superficies.append(superficie(topo, tema))
        # piso: uma caixa com o miolo do fragmento (a borda recortada fica fora)
        colisores.append(((0, (y0 + y1) / 2, -2.3), (LARGURA - 7, y1 - y0 - 1.5, 5)))
    ponte, blocos = pedras_ponte(rng, tema)
    corpo.append(ponte)
    colisores += blocos
    pecas = {
        "ilha": (montar(corpo), "Slate"),
        "superficie": (montar(superficies), "Ground" if i in (1, 2) else ("Ice" if i == 3 else ("Marble" if i == 4 else "Slate"))),
        "trilha": (trilha(rng, tema), "Slate" if i != 4 else "Marble"),
    }
    props, vidros, energia, cc = cenario(i, tema, rng)
    colisores += cc
    energia.append(energia_trilha(rng, tema))
    # portal de volta ao Nexo no começo e o Portão da próxima fase no fim
    retorno_y = -COMPRIMENTO / 2 + 3
    portao_y = COMPRIMENTO / 2 - 3
    props.append((arco(8, 7, 1.6, tema["detalhe"], rng), T((0, retorno_y, 0))))
    props.append((arco(16, 14, 2.6, tema["detalhe"], rng), T((0, portao_y, 0))))
    for x, y, sx, alto in ((5.3, retorno_y, 2.0, 7), (-5.3, retorno_y, 2.0, 7), (9.6, portao_y, 3.2, 14), (-9.6, portao_y, 3.2, 14)):
        colisores.append(((x, y, alto / 2), (sx, 2.4, alto)))
    pecas["props"] = (montar(props), "Slate" if i != 4 else "Marble")
    if vidros:
        pecas["vidro"] = (montar(vidros), "Glass")
    pecas["energia"] = (montar(energia), "Neon")
    pecas["retorno_veu"] = (montar([(veu(8, 7, kit.misturar(tema["energia"], (1, 1, 1), 0.35)), T((0, retorno_y, 0)))]), "Neon")
    pecas["portao_veu"] = (montar([(veu(16, 14, tema["energia"]), T((0, portao_y, 0)))]), "Neon")
    pontos = {
        "inicio": (0, retorno_y + 9, 0),
        "retorno": (0, retorno_y, 0),
        "portao": (0, portao_y, 0),
        "fim": (0, portao_y - 9, 0),
    }
    return pecas, colisores, pontos


def fazer_rochas_soltas():
    """Três rochas pequenas reaproveitadas em volta das ilhas (instâncias)."""
    saida = {}
    for k, semente in enumerate((71, 72, 73)):
        rng = random.Random(semente)
        pts = []
        for _ in range(14):
            v = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
            v.normalize()
            pts.append(tuple(v * rng.uniform(1.6, 2.6)))
        pts.append((0, 0, -4.2))
        saida["corredor_rocha_%s" % "abc"[k]] = kit.casco(pts, (0.33, 0.31, 0.40), 1.0, gradiente=(-4, 2, (0.1, 0.09, 0.14), (0.38, 0.36, 0.46)), chanfro=0.03)
    return saida


# ---------------------------------------------------------------- posição no mundo


def colocacao(i):
    """Centro (Roblox, studs) e giro (graus em Y) da ilha i (0..5)."""
    g = math.radians(ANGULO_INICIAL + PASSO_ANGULO * i)
    centro = (RAIO * math.sin(g), ALTURA_INICIAL + PASSO_ALTURA * i, -RAIO * math.cos(g))
    # a frente da ilha (-Z local no Roblox) segue a volta no sentido horário
    giro = math.degrees(math.atan2(-math.cos(g), -math.sin(g)))
    return centro, giro


def para_mundo(centro, giro, p):
    """Ponto local da ilha (Blender: x, y, z) -> mundo do Roblox."""
    lx, ly, lz = p[0], p[2], -p[1]
    t = math.radians(giro)
    return (
        centro[0] + lx * math.cos(t) + lz * math.sin(t),
        centro[1] + ly,
        centro[2] - lx * math.sin(t) + lz * math.cos(t),
    )


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
        "-- GERADO por assets/corredor/source/generate_corredor.py. Não editar à mão.",
        "-- Peça do Corredor dos Perdidos (mesmo formato do kit do Nexo).",
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
    return len(tris), len(texto)


def v3(p):
    return "{ %s }" % ", ".join(("%.3f" % c).rstrip("0").rstrip(".") for c in p)


def main():
    os.makedirs(os.path.join(DIR_BASE, "previews"), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materiais = {
        "Slate": kit.criar_material("Corredor_Pedra"),
        "Ground": kit.criar_material("Corredor_Chao"),
        "Ice": kit.criar_material("Corredor_Gelo", rugosidade=0.3),
        "Marble": kit.criar_material("Corredor_Marmore", rugosidade=0.4),
        "Glass": kit.criar_material("Corredor_Vidro", rugosidade=0.1, emissao=0.6),
        "Neon": kit.criar_material("Corredor_Energia", emissao=6.0),
    }
    cena, mapa, objetos = [], [], {}
    total = 0
    rng = random.Random(909)
    soltas = fazer_rochas_soltas()
    for nome, bm in soltas.items():
        objetos[nome] = (kit.registrar(nome, bm, materiais["Slate"]), "Slate")

    for i, tema in enumerate(TEMAS):
        centro, giro = colocacao(i)
        pecas, colisores, pontos = ilha(i, tema)
        for parte, (bm, material) in pecas.items():
            nome = "corredor_f%d_%s" % (i + 1, parte)
            objetos[nome] = (kit.registrar(nome, bm, materiais[material]), material)
            item = {"malha": nome, "posicao": centro, "giro": giro, "material": material, "fase": i + 1}
            if parte == "vidro":
                item["transparencia"] = 0.15
            if parte.endswith("veu"):
                item["transparencia"] = 0.35
                item["grupo"] = "veu"
            cena.append(item)
        # rochas soltas à deriva em volta da ilha
        for _ in range(7):
            lado = rng.choice((-1, 1))
            p = (lado * rng.uniform(30, 48), rng.uniform(-70, 70), rng.uniform(-30, 12))
            cena.append(
                {
                    "malha": "corredor_rocha_%s" % rng.choice("abc"),
                    "posicao": para_mundo(centro, giro, p),
                    "giro": rng.uniform(0, 360),
                    "escala": rng.uniform(0.8, 2.2),
                    "material": "Slate",
                    "fase": i + 1,
                    "grupo": "deriva",
                }
            )
        mapa.append(
            {
                "fase": i + 1,
                "nome": tema["nome"],
                "centro": centro,
                "giro": giro,
                "pontos": {k: para_mundo(centro, giro, v) for k, v in pontos.items()},
                "colisores": [(para_mundo(centro, giro, c), (s[0], s[2], s[1])) for c, s in colisores],
            }
        )

    print("%-28s %7s %9s" % ("peca", "tris", "base64"))
    for nome, (obj, _) in sorted(objetos.items()):
        t, c = escrever_malha(nome, obj)
        total += t
        print("%-28s %7d %9d" % (nome, t, c))
    print("total de triângulos: %d" % total)

    # Cena do cliente
    linhas = [
        "-- GERADO por assets/corredor/source/generate_corredor.py. Não editar à mão.",
        "-- Corredor dos Perdidos: onde cada peça fica (studs do Roblox; giro em graus no eixo Y).",
        "-- A colisão fica em src/shared/Dados/CorredorMapa.luau (criada pelo servidor).",
        "return {",
        "\tpecas = {",
    ]
    for item in cena:
        campos = ['malha = "%s"' % item["malha"], "posicao = %s" % v3(item["posicao"]), "giro = %.2f" % item["giro"]]
        campos.append("escala = %.2f" % item.get("escala", 1))
        campos.append('material = "%s"' % item["material"])
        campos.append("fase = %d" % item["fase"])
        if "transparencia" in item:
            campos.append("transparencia = %.2f" % item["transparencia"])
        if "grupo" in item:
            campos.append('grupo = "%s"' % item["grupo"])
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas += ["\t},", "}", ""]
    with open(ARQ_CENA, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))

    # Mapa do servidor: pontos e colisão de cada fase (no mundo)
    linhas = [
        "-- GERADO por assets/corredor/source/generate_corredor.py. Não editar à mão.",
        "-- Corredor dos Perdidos no mundo (studs do Roblox): centro e giro de cada ilha, pontos",
        "-- (inicio = chegada, retorno = portal de volta, fim = conclusão, portao = próxima fase)",
        "-- e caixas de colisão { posicao, giro, tamanho } que o servidor cria.",
        "return {",
        "\tcomprimento = %g," % COMPRIMENTO,
        "\tlargura = %g," % LARGURA,
        "\tfases = {",
    ]
    for m in mapa:
        linhas.append("\t\t{")
        linhas.append("\t\t\tfase = %d," % m["fase"])
        linhas.append('\t\t\tnome = "%s",' % m["nome"])
        linhas.append("\t\t\tcentro = %s," % v3(m["centro"]))
        linhas.append("\t\t\tgiro = %.3f," % m["giro"])
        linhas.append("\t\t\tpontos = {")
        for k in ("inicio", "retorno", "fim", "portao"):
            linhas.append("\t\t\t\t%s = %s," % (k, v3(m["pontos"][k])))
        linhas.append("\t\t\t},")
        linhas.append("\t\t\tcolisores = {")
        for c, s in m["colisores"]:
            linhas.append("\t\t\t\t{ posicao = %s, tamanho = %s }," % (v3(c), v3(s)))
        linhas.append("\t\t\t},")
        linhas.append("\t\t},")
    linhas += ["\t},", "}", ""]
    with open(ARQ_MAPA, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))

    montar_blender(cena, objetos)
    if "--render" in sys.argv:
        renderizar(mapa)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "corredor.blend"), compress=True)


def montar_blender(cena, objetos):
    colecao = bpy.data.collections.new("Corredor")
    bpy.context.scene.collection.children.link(colecao)
    for n, item in enumerate(cena):
        fonte = objetos[item["malha"]][0]
        inst = bpy.data.objects.new("%03d_%s" % (n, item["malha"]), fonte.data)
        inst.location = kit.roblox_para_blender(item["posicao"])
        inst.rotation_euler = (0, 0, math.radians(item["giro"]))
        inst.scale = (item.get("escala", 1),) * 3
        colecao.objects.link(inst)


def camera(nome, origem, alvo, lente):
    cam = bpy.data.objects.get("Camera")
    if cam is None:
        bpy.ops.object.camera_add()
        cam = bpy.context.object
        cam.name = "Camera"
    cam.location = origem
    cam.rotation_euler = (Vector(alvo) - Vector(origem)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lente
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = os.path.join(DIR_BASE, "previews", nome + ".jpg")
    bpy.ops.render.render(write_still=True)
    print("prévia", nome)


def renderizar(mapa):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 32
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 1280, 720
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 88
    cena.view_settings.view_transform = "AgX"
    mundo = bpy.data.worlds.new("Espaco")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.04, 0.03, 0.09, 1)
    cena.world = mundo
    # chão da praça lá embaixo, só para dar escala
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=240, fill_type="NGON", location=(0, 0, 0))
    chao = bpy.context.object
    m = bpy.data.materials.new("Chao")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.045, 0.08, 1)
    chao.data.materials.append(m)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(150)))
    bpy.context.object.data.energy = 2.4
    bpy.context.object.data.color = (0.75, 0.78, 1.0)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(70), 0, math.radians(-30)))
    bpy.context.object.data.energy = 0.8
    # visão geral: a espiral vista de fora e de baixo (como quem está na praça)
    camera("corredor_geral", (330, -330, 260), (0, 0, 130), 24)
    camera("corredor_da_praca", (0, -30, 6), (60, 150, 120), 18)
    for m in mapa:
        c = Vector(kit.roblox_para_blender(m["centro"]))
        inicio = Vector(kit.roblox_para_blender(m["pontos"]["inicio"]))
        portao = Vector(kit.roblox_para_blender(m["pontos"]["portao"]))
        frente = (portao - inicio).normalized()
        lado = Vector((frente.y, -frente.x, 0))
        olho = inicio - frente * 22 + lado * 9 + Vector((0, 0, 14))
        camera("corredor_fase%d" % m["fase"], tuple(olho), tuple(portao + Vector((0, 0, 4))), 22)
        camera("corredor_fase%d_lado" % m["fase"], tuple(c + lado * 120 + Vector((0, 0, 30))), tuple(c + Vector((0, 0, -8))), 26)


if __name__ == "__main__":
    main()
