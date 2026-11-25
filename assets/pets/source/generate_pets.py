"""Gera os Ecos (pets) e os Núcleos no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/pets/source/generate_pets.py            # malhas e dados
    python assets/pets/source/generate_pets.py --render   # também as prévias

Conceito: os Ecos são criaturas guardadas dentro dos Núcleos, as sementes de cristal que sobraram
de cada mundo do Corredor dos Perdidos. O Cristal do Nexo desperta cada uma. Cada mundo tem
uma linguagem de material própria:
    1 Limiar Partido     pedra viva e cristal violeta
    2 Bosque de Vidro    flora de vidro verde-água
    3 Dunas de Cinza     obsidiana com rachaduras em brasa
    4 Maré Suspensa      água presa no ar, gelo e coral
    5 Catedral Quebrada  mármore, ouro e vitral
    6 Coração do Vazio   facetas escuras costuradas por estrelas

Cada Eco tem até cinco peças: corpo, brilho (Neon), vidro (Glass) e asa_e/asa_d (batem).

Saídas:
    src/client/Mundo/Nexo3D/Dados/pet_*.luau e nucleo_*.luau   geometria (formato do kit)
    src/shared/Dados/PetsVisual.luau                            peças, juntas e tamanhos
    assets/pets/source/pets.blend                               cena editável
    assets/pets/previews/*.jpg                                  renders (NÃO são prints do Roblox)

Espaço de cada Eco: origem no chão, no centro; +Y do Blender é a frente (-Z no Roblox).
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

DIR_BASE = os.path.join(RAIZ, "assets", "pets")
DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Nexo3D", "Dados")
ARQ_VISUAL = os.path.join(RAIZ, "src", "shared", "Dados", "PetsVisual.luau")

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


def esfera(c, rx, ry, rz, cor, lados=10, aneis=6, tinta=1.0, topo_claro=0.3):
    """Elipsoide facetado centrado em c."""
    perfil = []
    for k in range(aneis + 1):
        a = -math.pi / 2 + math.pi * k / aneis
        perfil.append((max(math.cos(a), 0.02), math.sin(a)))
    bm = kit.torno(perfil, lados, cor, random.Random(1), tinta=tinta)
    bmesh.ops.scale(bm, vec=(rx, ry, rz), verts=bm.verts[:])
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts[:])
    kit.pintar(bm, cor, tinta, topo_claro=topo_claro)
    return bm


def olho(c, r, frente=(0, 1, 0)):
    """Olho fofo: pupila preta com um brilho branco puxado para cima e para a frente."""
    f = Vector(frente).normalized()
    pupila = esfera(c, r, r * 0.7, r * 1.15, PRETO, lados=8, aneis=5, topo_claro=0.0)
    luz = esfera(Vector(c) + f * r * 0.62 + Vector((r * 0.25, 0, r * 0.4)), r * 0.32, r * 0.2, r * 0.32, BRANCO, lados=6, aneis=3, topo_claro=0.0)
    return montar([pupila, luz])


def casca(pts, cor, tinta=1.0, gradiente=None, chanfro=0.0):
    return kit.casco(pts, cor, tinta, gradiente=gradiente, chanfro=chanfro)


def anel(c, raio, espessura, cor, lados=20, inclinar=0.0, eixo="X"):
    """Toro facetado (aro, auréola, órbita)."""
    bm = kit.novo_bm()
    secao = 4
    vs = []
    for i in range(lados):
        a = 2 * math.pi * i / lados
        linha = []
        for j in range(secao):
            b = 2 * math.pi * j / secao + math.pi / 4
            r = raio + espessura * math.cos(b)
            linha.append(bm.verts.new((r * math.cos(a), r * math.sin(a), espessura * math.sin(b))))
        vs.append(linha)
    for i in range(lados):
        for j in range(secao):
            a, b = vs[i][j], vs[(i + 1) % lados][j]
            c2, d = vs[(i + 1) % lados][(j + 1) % secao], vs[i][(j + 1) % secao]
            bm.faces.new((a, b, c2, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    kit.pintar(bm, cor, 1.0, topo_claro=0.2)
    if inclinar:
        bmesh.ops.transform(bm, matrix=R(inclinar, eixo), verts=bm.verts[:])
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts[:])
    return bm


def lamina(pts, cor):
    """Polígono plano de dois lados (asas, folhas, barbatanas)."""
    return kit.chapa(pts, cor, 1.0, dupla=True)


def vitral(celulas, chumbo):
    """Asa de vitral: células coloridas planas e um contorno escuro levemente à frente."""
    partes = []
    for pts, cor in celulas:
        partes.append(lamina(pts, cor))
        for k in range(len(pts)):
            a, b = Vector(pts[k]), Vector(pts[(k + 1) % len(pts)])
            partes.append(kit.fita3d([tuple(a), tuple(b)], 0.06, (0, 1, 0), chumbo))
            partes.append(kit.fita3d([tuple(a), tuple(b)], 0.06, (0, -1, 0), chumbo))
    return montar(partes)


def perna(base, topo, largura, cor):
    return casca(
        [
            (base[0] - largura, base[1] - largura, base[2]),
            (base[0] + largura, base[1] - largura, base[2]),
            (base[0] - largura, base[1] + largura, base[2]),
            (base[0] + largura, base[1] + largura, base[2]),
            (topo[0] - largura * 0.8, topo[1], topo[2]),
            (topo[0] + largura * 0.8, topo[1], topo[2]),
            (topo[0], topo[1] - largura * 0.8, topo[2]),
            (topo[0], topo[1] + largura * 0.8, topo[2]),
        ],
        cor,
    )


def estrela(c, r, cor):
    """Ponto de estrela: dois losangos cruzados."""
    x, y, z = c
    return casca([(x + r, y, z), (x - r, y, z), (x, y + r * 0.35, z), (x, y - r * 0.35, z), (x, y, z + r), (x, y, z - r)], cor)


# ---------------------------------------------------------------- os Ecos
# Cada função devolve { parte: (bm, material, transparencia) } e opções (voa, junta das asas).

VIOLETA = (0.62, 0.42, 1.00)
LILAS_CLARO = (0.82, 0.72, 1.00)
PEDRA = (0.42, 0.40, 0.50)
PEDRA_ESCURA = (0.22, 0.20, 0.28)


def lasquinho():
    rng = random.Random(11)
    pts = [(x * 0.2, y * 0.2, (z + 6.6) * 0.2) for x, y, z in kit.pontos_cristal(rng)]
    corpo = casca(pts, VIOLETA, gradiente=(0, 2.6, (0.40, 0.25, 0.80), LILAS_CLARO))
    pes = [kit.bloco(0.42, 0.5, 0.36, rng, PEDRA_ESCURA, chanfro=0.05) for _ in range(2)]
    lasca = casca([(x * 0.07 + 0.45, y * 0.07, (z + 6.6) * 0.07 + 2.0) for x, y, z in kit.pontos_cristal(random.Random(12))], LILAS_CLARO)
    lasca2 = casca([(x * 0.06 - 0.4, y * 0.06 - 0.1, (z + 6.6) * 0.06 + 1.9) for x, y, z in kit.pontos_cristal(random.Random(13))], VIOLETA)
    return {
        "corpo": (montar([corpo, (pes[0], T((0.32, 0.05, 0.18))), (pes[1], T((-0.32, 0.05, 0.18))), olho((0, 0.52, 1.5), 0.2), lasca, lasca2]), "SmoothPlastic", 0),
    }, {"voa": False}


def mariposa_vitral():
    corpo = montar([
        esfera((0, 0, 1.6), 0.28, 0.5, 0.3, (0.96, 0.90, 0.78)),
        esfera((0, 0.52, 1.72), 0.26, 0.24, 0.24, (0.96, 0.92, 0.82)),
        olho((0.14, 0.7, 1.78), 0.08),
        olho((-0.14, 0.7, 1.78), 0.08),
        kit.espinho((0.08, 0.66, 1.92), (0.45, 1.1, 2.5), 0.05, (0.3, 0.25, 0.2)),
        kit.espinho((-0.08, 0.66, 1.92), (-0.45, 1.1, 2.5), 0.05, (0.3, 0.25, 0.2)),
    ])
    brilho = montar([esfera((0.45, 1.1, 2.5), 0.08, 0.08, 0.08, (1.0, 0.85, 0.4)), esfera((-0.45, 1.1, 2.5), 0.08, 0.08, 0.08, (1.0, 0.85, 0.4))])
    chumbo = (0.12, 0.08, 0.14)

    def asa(lado):
        s = lado
        cima = [
            ([(s * 0.25, 0.1, 1.65), (s * 1.3, 0.5, 2.5), (s * 0.9, 0.15, 2.05)], (0.30, 0.85, 0.90)),
            ([(s * 0.9, 0.15, 2.05), (s * 1.3, 0.5, 2.5), (s * 1.6, -0.1, 2.15)], (0.95, 0.40, 0.75)),
            ([(s * 0.25, 0.1, 1.65), (s * 0.9, 0.15, 2.05), (s * 1.6, -0.1, 2.15), (s * 1.0, -0.3, 1.6)], (1.0, 0.80, 0.30)),
        ]
        baixo = [
            ([(s * 0.25, -0.1, 1.5), (s * 1.0, -0.3, 1.6), (s * 0.85, -0.75, 1.05)], (0.55, 0.40, 1.00)),
            ([(s * 0.25, -0.1, 1.5), (s * 0.85, -0.75, 1.05), (s * 0.35, -0.5, 1.15)], (0.30, 0.85, 0.90)),
        ]
        return vitral(cima + baixo, chumbo)

    return {
        "corpo": (corpo, "SmoothPlastic", 0),
        "brilho": (brilho, "Neon", 0),
        "asa_e": (asa(-1), "Glass", 0.1),
        "asa_d": (asa(1), "Glass", 0.1),
    }, {"voa": True, "junta_e": (-0.22, 1.6, 0.05), "junta_d": (0.22, 1.6, 0.05), "bater": 38}


def lanterneiro():
    rng = random.Random(31)
    corpo = montar([
        (kit.bloco(0.95, 0.85, 0.75, rng, PEDRA, chanfro=0.08), T((0, 0, 0.55))),
        (kit.bloco(0.85, 0.75, 0.6, rng, (0.50, 0.48, 0.58), chanfro=0.08), T((0.03, 0, 1.2)) @ R(6, "Z")),
        (kit.bloco(0.7, 0.62, 0.5, rng, PEDRA, chanfro=0.08), T((-0.02, 0.02, 1.72)) @ R(-8, "Z")),
        (kit.bloco(0.75, 0.6, 0.38, rng, PEDRA_ESCURA, chanfro=0.06), T((0, 0.02, 2.1))),
        perna((0.25, 0, 0), (0.25, 0, 0.3), 0.16, PEDRA_ESCURA),
        perna((-0.25, 0, 0), (-0.25, 0, 0.3), 0.16, PEDRA_ESCURA),
        # braço que segura a lanterna e a gaiola da lanterna
        casca([(0.45, 0.1, 1.3), (0.5, 0.0, 1.45), (0.95, 0.45, 1.0), (0.9, 0.55, 0.9)], PEDRA_ESCURA),
        anel((0.95, 0.55, 0.62), 0.24, 0.035, (0.25, 0.22, 0.20), lados=10),
        anel((0.95, 0.55, 0.95), 0.18, 0.035, (0.25, 0.22, 0.20), lados=10),
        kit.espinho((0.95, 0.55, 0.95), (0.95, 0.55, 1.18), 0.12, (0.25, 0.22, 0.20)),
    ])
    return {
        "corpo": (corpo, "Slate", 0),
        "brilho": (montar([(esfera((0.95, 0.55, 0.78), 0.17, 0.17, 0.22, (1.0, 0.80, 0.40)), None), (kit.bloco(0.42, 0.06, 0.08, rng, (0.80, 0.65, 1.0), chanfro=0.0), T((0, 0.36, 2.12)))]), "Neon", 0),
    }, {"voa": False}


VERDE_AGUA = (0.40, 1.00, 0.85)
VERDE_VIDRO = (0.30, 0.85, 0.70)


def sininho_vidro():
    perfil = [(0.05, 1.0), (0.45, 0.95), (0.62, 0.6), (0.7, 0.2), (0.82, 0.02)]
    sino = kit.torno(perfil, 12, VERDE_VIDRO, random.Random(2))
    bmesh.ops.translate(sino, vec=Vector((0, 0, 0.5)), verts=sino.verts[:])
    caule = montar([
        kit.fita3d([(0, 0, 1.5), (0.1, 0, 1.85), (0.35, 0, 2.05), (0.5, 0, 1.95)], 0.08, (0, 1, 0), (0.25, 0.55, 0.35)),
        kit.fita3d([(0, 0, 1.5), (0.1, 0, 1.85), (0.35, 0, 2.05), (0.5, 0, 1.95)], 0.08, (0, -1, 0), (0.25, 0.55, 0.35)),
        lamina([(0.05, 0, 1.55), (-0.65, 0.1, 1.95), (-0.25, 0, 1.6)], (0.30, 0.75, 0.45)),
        lamina([(0.08, 0, 1.6), (0.65, -0.1, 1.75), (0.3, 0, 1.55)], (0.30, 0.75, 0.45)),
    ])
    corpo = montar([caule, olho((0.2, 0.62, 1.05), 0.11), olho((-0.2, 0.62, 1.05), 0.11)])
    brilho = esfera((0, 0, 0.42), 0.2, 0.2, 0.2, (1.0, 0.95, 0.6))
    return {
        "vidro": (sino, "Glass", 0.25),
        "corpo": (corpo, "SmoothPlastic", 0),
        "brilho": (brilho, "Neon", 0),
    }, {"voa": True}


def raposa_prisma():
    laranja = (1.0, 0.55, 0.30)
    creme = (1.0, 0.92, 0.82)
    corpo = montar([
        casca([(0.4, -0.5, 0.6), (-0.4, -0.5, 0.6), (0.45, 0.4, 0.65), (-0.45, 0.4, 0.65), (0.3, -0.45, 1.15), (-0.3, -0.45, 1.15), (0.35, 0.45, 1.2), (-0.35, 0.45, 1.2), (0, 0.6, 0.9)], laranja),
        casca([(0.36, 0.45, 1.2), (-0.36, 0.45, 1.2), (0.32, 0.95, 1.25), (-0.32, 0.95, 1.25), (0.3, 0.6, 1.75), (-0.3, 0.6, 1.75), (0, 1.35, 1.25), (0, 0.9, 1.0)], laranja),
        casca([(0.15, 1.05, 1.15), (-0.15, 1.05, 1.15), (0, 1.36, 1.24), (0, 1.1, 1.0)], creme),
        kit.espinho((0.2, 0.65, 1.65), (0.32, 0.6, 2.25), 0.26, laranja),
        kit.espinho((-0.2, 0.65, 1.65), (-0.32, 0.6, 2.25), 0.26, laranja),
        perna((0.25, 0.3, 0), (0.25, 0.3, 0.7), 0.1, (0.35, 0.18, 0.12)),
        perna((-0.25, 0.3, 0), (-0.25, 0.3, 0.7), 0.1, (0.35, 0.18, 0.12)),
        perna((0.25, -0.35, 0), (0.25, -0.35, 0.7), 0.1, (0.35, 0.18, 0.12)),
        perna((-0.25, -0.35, 0), (-0.25, -0.35, 0.7), 0.1, (0.35, 0.18, 0.12)),
        olho((0.17, 1.02, 1.42), 0.09),
        olho((-0.17, 1.02, 1.42), 0.09),
        esfera((0, 1.37, 1.25), 0.06, 0.05, 0.05, PRETO, lados=6, aneis=3),
    ])
    # cauda: uma grande folha de cristal
    cauda = casca([(0, -0.45, 0.95), (0.25, -0.9, 1.4), (-0.25, -0.9, 1.4), (0.1, -1.3, 2.0), (-0.1, -1.3, 2.0), (0, -1.5, 2.45), (0, -1.0, 1.1)], VERDE_AGUA, gradiente=(1.0, 2.4, (0.2, 0.7, 0.6), (0.75, 1.0, 0.95)))
    return {"corpo": (corpo, "SmoothPlastic", 0), "vidro": (cauda, "Glass", 0.1)}, {"voa": False}


def cervo_cantor():
    branco = (0.92, 0.95, 0.96)
    corpo = montar([
        casca([(0.42, -0.7, 0.95), (-0.42, -0.7, 0.95), (0.45, 0.55, 1.0), (-0.45, 0.55, 1.0), (0.35, -0.6, 1.6), (-0.35, -0.6, 1.6), (0.38, 0.55, 1.65), (-0.38, 0.55, 1.65)], branco),
        casca([(0.22, 0.45, 1.5), (-0.22, 0.45, 1.5), (0.18, 0.75, 2.3), (-0.18, 0.75, 2.3), (0, 0.6, 1.3)], branco),
        casca([(0.24, 0.65, 2.2), (-0.24, 0.65, 2.2), (0.2, 0.7, 2.65), (-0.2, 0.7, 2.65), (0.1, 1.3, 2.35), (-0.1, 1.3, 2.35), (0, 1.32, 2.2)], branco),
        perna((0.3, 0.4, 0), (0.3, 0.4, 1.05), 0.1, (0.35, 0.4, 0.42)),
        perna((-0.3, 0.4, 0), (-0.3, 0.4, 1.05), 0.1, (0.35, 0.4, 0.42)),
        perna((0.3, -0.55, 0), (0.3, -0.55, 1.05), 0.1, (0.35, 0.4, 0.42)),
        perna((-0.3, -0.55, 0), (-0.3, -0.55, 1.05), 0.1, (0.35, 0.4, 0.42)),
        olho((0.19, 1.0, 2.45), 0.08),
        olho((-0.19, 1.0, 2.45), 0.08),
        lamina([(0.2, 0.7, 2.55), (0.55, 0.6, 2.7), (0.25, 0.65, 2.45)], (0.85, 0.9, 0.9)),
        lamina([(-0.2, 0.7, 2.55), (-0.55, 0.6, 2.7), (-0.25, 0.65, 2.45)], (0.85, 0.9, 0.9)),
    ])
    galhos = []
    for s in (1, -1):
        galhos.append(kit.espinho((s * 0.12, 0.7, 2.6), (s * 0.45, 0.55, 3.4), 0.12, VERDE_AGUA))
        galhos.append(kit.espinho((s * 0.32, 0.6, 3.0), (s * 0.75, 0.75, 3.35), 0.09, VERDE_AGUA))
        galhos.append(kit.espinho((s * 0.4, 0.57, 3.25), (s * 0.35, 0.3, 3.75), 0.08, VERDE_AGUA))
        galhos.append(kit.espinho((s * 0.28, 0.62, 2.85), (s * 0.15, 0.95, 3.3), 0.07, VERDE_AGUA))
    return {"corpo": (corpo, "SmoothPlastic", 0), "brilho": (montar(galhos), "Neon", 0)}, {"voa": False}


BRASA = (1.0, 0.45, 0.12)
OBSIDIANA = (0.10, 0.08, 0.10)


def fagulha():
    perfil = [(0.02, 0.0), (0.45, 0.15), (0.6, 0.5), (0.5, 0.9), (0.25, 1.3), (0.02, 1.75)]
    gota = kit.torno(perfil, 10, (1.0, 0.62, 0.20), random.Random(4))
    kit.pintar(gota, (1.0, 0.6, 0.2), 1.0, topo_claro=0.0, gradiente=(0, 1.75, (1.0, 0.35, 0.05), (1.0, 0.95, 0.5)))
    bmesh.ops.translate(gota, vec=Vector((0, 0, 0.6)), verts=gota.verts[:])
    gaiola = montar([
        anel((0, 0, 1.0), 0.72, 0.05, OBSIDIANA, lados=14),
        anel((0, 0, 1.25), 0.68, 0.045, OBSIDIANA, lados=14, inclinar=90, eixo="X"),
        anel((0, 0, 1.25), 0.68, 0.045, OBSIDIANA, lados=14, inclinar=90, eixo="Y"),
        olho((0.17, 0.52, 1.15), 0.1),
        olho((-0.17, 0.52, 1.15), 0.1),
    ])
    return {"brilho": (gota, "Neon", 0.05), "corpo": (gaiola, "Metal", 0)}, {"voa": True}


def escaravelho_solar():
    ouro = (1.0, 0.78, 0.30)
    casco_ = casca([(0.55, -0.6, 0.35), (-0.55, -0.6, 0.35), (0.6, 0.4, 0.35), (-0.6, 0.4, 0.35), (0.4, -0.5, 0.95), (-0.4, -0.5, 0.95), (0.42, 0.35, 0.95), (-0.42, 0.35, 0.95), (0, -0.1, 1.15), (0, 0.6, 0.6)], (0.12, 0.30, 0.32), gradiente=(0.3, 1.15, (0.06, 0.15, 0.18), (0.25, 0.65, 0.6)))
    partes = [casco_]
    partes.append(kit.fita3d([(0, 0.4, 1.0), (0, -0.1, 1.17), (0, -0.62, 0.9)], 0.06, (0, 0, 1), ouro))
    cabeca = casca([(0.3, 0.45, 0.35), (-0.3, 0.45, 0.35), (0.25, 0.8, 0.45), (-0.25, 0.8, 0.45), (0.22, 0.6, 0.75), (-0.22, 0.6, 0.75)], (0.10, 0.18, 0.2))
    partes += [cabeca, olho((0.15, 0.8, 0.62), 0.08), olho((-0.15, 0.8, 0.62), 0.08)]
    for s in (1, -1):
        for y in (0.3, -0.05, -0.4):
            partes.append(kit.espinho((s * 0.45, y, 0.4), (s * 0.85, y + 0.1, 0.02), 0.08, (0.08, 0.1, 0.1)))
        partes.append(kit.espinho((s * 0.12, 0.78, 0.7), (s * 0.3, 1.15, 1.0), 0.05, ouro))
    sol = montar([esfera((0, 1.25, 1.35), 0.42, 0.42, 0.42, (1.0, 0.85, 0.35), lados=12, aneis=7)])
    return {"corpo": (montar(partes), "SmoothPlastic", 0), "brilho": (sol, "Neon", 0)}, {"voa": False}


def salamandra_obsidiana():
    partes, brilhos = [], []
    seg = [(0, 0.9, 0.55, 0.38), (0, 0.4, 0.5, 0.42), (0, -0.15, 0.48, 0.4), (0.1, -0.65, 0.42, 0.3), (0.3, -1.05, 0.38, 0.22), (0.6, -1.3, 0.38, 0.15)]
    for x, y, z, r in seg:
        partes.append(esfera((x, y, z), r, r * 1.2, r * 0.75, OBSIDIANA, lados=8, aneis=4))
    partes.append(casca([(0.32, 1.0, 0.45), (-0.32, 1.0, 0.45), (0.25, 1.55, 0.5), (-0.25, 1.55, 0.5), (0.25, 1.1, 0.85), (-0.25, 1.1, 0.85), (0, 1.75, 0.55)], (0.14, 0.11, 0.13)))
    partes += [olho((0.22, 1.35, 0.78), 0.1), olho((-0.22, 1.35, 0.78), 0.1)]
    for s in (1, -1):
        for y in (0.55, -0.3):
            partes.append(perna((s * 0.6, y + 0.05, 0), (s * 0.3, y, 0.45), 0.09, (0.12, 0.1, 0.12)))
    for x, y, z, r in seg[:-1]:
        brilhos.append(kit.fita3d([(x - r * 0.45, y + 0.05, z + r * 0.7), (x, y - 0.05, z + r * 0.78), (x + r * 0.45, y + 0.08, z + r * 0.68)], 0.07, (0, 0, 1), BRASA))
        brilhos.append(kit.espinho((x, y, z + r * 0.6), (x, y - 0.1, z + r * 0.6 + 0.28), 0.1, BRASA))
    return {"corpo": (montar(partes), "SmoothPlastic", 0), "brilho": (montar(brilhos), "Neon", 0)}, {"voa": False}


AGUA = (0.45, 0.85, 1.0)


def peixe_bolha():
    coral = (1.0, 0.50, 0.40)
    peixe = montar([
        casca([(0, 0.55, 1.2), (0.22, 0.1, 1.2), (-0.22, 0.1, 1.2), (0, 0.1, 1.55), (0, 0.1, 0.9), (0, -0.35, 1.2)], coral),
        lamina([(0, -0.3, 1.2), (0, -0.7, 1.5), (0, -0.6, 1.2), (0, -0.7, 0.9)], (1.0, 0.75, 0.40)),
        lamina([(0, 0.15, 1.5), (0, -0.15, 1.75), (0, -0.2, 1.45)], (1.0, 0.75, 0.40)),
        olho((0.13, 0.38, 1.28), 0.07),
        olho((-0.13, 0.38, 1.28), 0.07),
    ])
    bolha = esfera((0, 0, 1.2), 0.95, 0.95, 0.95, AGUA, lados=14, aneis=8, topo_claro=0.4)
    bolhinhas = montar([esfera((0.55, 0.3, 2.35), 0.12, 0.12, 0.12, (0.8, 0.95, 1.0)), esfera((0.35, 0.1, 2.6), 0.08, 0.08, 0.08, (0.8, 0.95, 1.0))])
    return {"corpo": (peixe, "SmoothPlastic", 0), "vidro": (bolha, "Glass", 0.55), "brilho": (bolhinhas, "Neon", 0.3)}, {"voa": True}


def aguaviva_lanterna():
    perfil = [(0.02, 1.0), (0.55, 0.92), (0.85, 0.6), (0.95, 0.25), (0.8, 0.1), (0.3, 0.15), (0.02, 0.2)]
    sino = kit.torno(perfil, 14, (0.75, 0.85, 1.0), random.Random(5))
    bmesh.ops.translate(sino, vec=Vector((0, 0, 1.3)), verts=sino.verts[:])
    tentaculos = []
    rng = random.Random(6)
    for i in range(7):
        a = 2 * math.pi * i / 7
        x, y = math.cos(a) * 0.5, math.sin(a) * 0.5
        pts = [(x, y, 1.4), (x * 1.1 + rng.uniform(-0.1, 0.1), y * 1.1, 0.95), (x * 0.9, y * 0.9 + rng.uniform(-0.1, 0.1), 0.55), (x * 1.15, y * 1.15, 0.15)]
        tentaculos.append(kit.fita3d(pts, 0.07, (math.cos(a), math.sin(a), 0), (0.85, 0.65, 1.0)))
        tentaculos.append(kit.fita3d(pts, 0.07, (-math.cos(a), -math.sin(a), 0), (0.85, 0.65, 1.0)))
    nucleo = esfera((0, 0, 1.65), 0.32, 0.32, 0.3, (0.65, 1.0, 0.95))
    olhos = montar([olho((0.25, 0.82, 1.75), 0.09), olho((-0.25, 0.82, 1.75), 0.09)])
    return {"vidro": (sino, "Glass", 0.35), "brilho": (montar([nucleo] + tentaculos), "Neon", 0.15), "corpo": (olhos, "SmoothPlastic", 0)}, {"voa": True}


def baleia_celeste():
    azul = (0.35, 0.55, 0.95)
    corpo = montar([
        esfera((0, 0.2, 1.3), 0.75, 1.15, 0.72, azul, lados=12, aneis=7),
        esfera((0, 0.45, 1.05), 0.6, 0.8, 0.42, (0.92, 0.95, 1.0), lados=12, aneis=6),
        casca([(0, -0.8, 1.35), (0.2, -1.2, 1.4), (-0.2, -1.2, 1.4), (0, -1.25, 1.55)], azul),
        lamina([(0, -1.15, 1.45), (0.75, -1.6, 1.75), (0.35, -1.45, 1.4)], azul),
        lamina([(0, -1.15, 1.45), (-0.75, -1.6, 1.75), (-0.35, -1.45, 1.4)], azul),
        olho((0.42, 1.05, 1.4), 0.1),
        olho((-0.42, 1.05, 1.4), 0.1),
        esfera((0, 0.0, 2.15), 0.38, 0.38, 0.28, BRANCO),
        esfera((0.3, -0.15, 2.05), 0.28, 0.28, 0.22, BRANCO),
        esfera((-0.28, 0.2, 2.05), 0.3, 0.3, 0.22, BRANCO),
    ])
    estrelas = montar([estrela((0.5 * math.cos(a), -0.1 + 0.5 * math.sin(a), 1.75), 0.09, (1, 0.95, 0.6)) for a in (0.4, 1.5, 2.6, 3.9, 5.2)])
    asa_e = lamina([(-0.55, 0.45, 1.0), (-1.35, 0.2, 0.75), (-0.75, 0.05, 1.0)], azul)
    asa_d = lamina([(0.55, 0.45, 1.0), (1.35, 0.2, 0.75), (0.75, 0.05, 1.0)], azul)
    return {
        "corpo": (corpo, "SmoothPlastic", 0),
        "brilho": (estrelas, "Neon", 0),
        "asa_e": (asa_e, "SmoothPlastic", 0),
        "asa_d": (asa_d, "SmoothPlastic", 0),
    }, {"voa": True, "junta_e": (-0.55, 0.3, 1.0), "junta_d": (0.55, 0.3, 1.0), "bater": 18}


OURO = (1.0, 0.80, 0.32)
MARMORE = (0.92, 0.90, 0.95)


def penas(lado, cor, base, n=5, comp=1.3):
    """Asa de penas em leque: penas largas e arredondadas, as de cima mais longas."""
    partes = []
    bx, by, bz = base
    for k in range(n):
        f = k / max(n - 1, 1)
        ang = math.radians(62 - 58 * f)  # das penas de cima (mais erguidas) às de baixo
        tam = comp * (1.0 - 0.35 * f)
        largura = 0.2 + 0.08 * (1 - f)
        dx, dz = math.cos(ang), math.sin(ang)
        nx, nz = -dz, dx  # perpendicular no plano da asa
        y = by - 0.06 * k
        pts = [
            (bx, y, bz),
            (bx + lado * (dx * tam * 0.35 + nx * largura), y - 0.02, bz + dz * tam * 0.35 + nz * largura),
            (bx + lado * (dx * tam * 0.8 + nx * largura * 0.8), y - 0.04, bz + dz * tam * 0.8 + nz * largura * 0.8),
            (bx + lado * dx * tam, y - 0.05, bz + dz * tam),
            (bx + lado * (dx * tam * 0.8 - nx * largura * 0.7), y - 0.04, bz + dz * tam * 0.8 - nz * largura * 0.7),
            (bx + lado * (dx * tam * 0.35 - nx * largura * 0.8), y - 0.02, bz + dz * tam * 0.35 - nz * largura * 0.8),
        ]
        partes.append(lamina(pts, kit.misturar(cor, (0.75, 0.72, 0.85), 0.12 * k)))
    return montar(partes)


def sino_alado():
    perfil = [(0.08, 1.75), (0.4, 1.7), (0.52, 1.35), (0.6, 0.9), (0.78, 0.55), (0.82, 0.48)]
    sino = kit.torno(perfil, 12, OURO, random.Random(7))
    corpo = montar([sino, anel((0, 0, 1.85), 0.16, 0.05, OURO, lados=10, inclinar=90, eixo="X"), olho((0.2, 0.52, 1.25), 0.1), olho((-0.2, 0.52, 1.25), 0.1)])
    badalo = esfera((0, 0, 0.42), 0.18, 0.18, 0.2, (1.0, 0.95, 0.7))
    return {
        "corpo": (corpo, "Metal", 0),
        "brilho": (badalo, "Neon", 0),
        "asa_e": (penas(-1, BRANCO, (-0.45, 0, 1.4)), "SmoothPlastic", 0),
        "asa_d": (penas(1, BRANCO, (0.45, 0, 1.4)), "SmoothPlastic", 0),
    }, {"voa": True, "junta_e": (-0.45, 0, 1.4), "junta_d": (0.45, 0, 1.4), "bater": 28}


def coruja_vitral():
    corpo = montar([
        esfera((0, 0, 1.15), 0.72, 0.62, 0.95, MARMORE, lados=12, aneis=7),
        kit.espinho((0.4, 0.05, 1.85), (0.55, -0.05, 2.35), 0.2, MARMORE),
        kit.espinho((-0.4, 0.05, 1.85), (-0.55, -0.05, 2.35), 0.2, MARMORE),
        kit.espinho((0, 0.62, 1.35), (0, 0.85, 1.15), 0.14, OURO),
        perna((0.2, 0.1, 0), (0.2, 0.1, 0.3), 0.08, OURO),
        perna((-0.2, 0.1, 0), (-0.2, 0.1, 0.3), 0.08, OURO),
    ])
    # rosácea: o rosto é um vitral redondo com dois olhos grandes
    celulas = []
    cores = [(0.30, 0.55, 1.0), (1.0, 0.35, 0.45), (1.0, 0.80, 0.30), (0.45, 0.90, 0.60)]
    for i in range(8):
        a0, a1 = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8
        celulas.append(([(0, 0.6, 1.35), (0.55 * math.cos(a0), 0.6, 1.35 + 0.5 * math.sin(a0)), (0.55 * math.cos(a1), 0.6, 1.35 + 0.5 * math.sin(a1))], cores[i % 4]))
    rosto = vitral(celulas, (0.15, 0.12, 0.18))
    olhos = montar([esfera((0.22, 0.66, 1.45), 0.17, 0.08, 0.17, (1.0, 0.85, 0.35)), esfera((-0.22, 0.66, 1.45), 0.17, 0.08, 0.17, (1.0, 0.85, 0.35)), esfera((0.22, 0.72, 1.45), 0.08, 0.05, 0.1, PRETO), esfera((-0.22, 0.72, 1.45), 0.08, 0.05, 0.1, PRETO)])
    return {
        "corpo": (montar([corpo, olhos]), "Marble", 0),
        "vidro": (rosto, "Glass", 0.05),
        "asa_e": (penas(-1, MARMORE, (-0.65, -0.05, 1.3), n=5, comp=1.1), "Marble", 0),
        "asa_d": (penas(1, MARMORE, (0.65, -0.05, 1.3), n=5, comp=1.1), "Marble", 0),
    }, {"voa": True, "junta_e": (-0.65, -0.05, 1.3), "junta_d": (0.65, -0.05, 1.3), "bater": 22}


def querubim_partido():
    rng = random.Random(15)
    rosto = esfera((0, 0, 1.4), 0.7, 0.62, 0.78, MARMORE, lados=12, aneis=8)
    # rachaduras douradas, olhos fechados em linha e cachos de mármore
    partes = [rosto]
    partes.append(kit.fita3d([(0.18, 0.6, 1.55), (0.32, 0.58, 1.5), (0.45, 0.52, 1.56)], 0.05, (0, 1, 0), PRETO))
    partes.append(kit.fita3d([(-0.18, 0.6, 1.55), (-0.32, 0.58, 1.5), (-0.45, 0.52, 1.56)], 0.05, (0, 1, 0), PRETO))
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6)
        partes.append(esfera((0.62 * math.cos(a), -0.05, 1.45 + 0.62 * math.sin(a)), 0.2, 0.2, 0.2, (0.85, 0.83, 0.9), lados=8, aneis=4))
    fragmentos = []
    for k in range(5):
        a = 2 * math.pi * k / 5
        c = (math.cos(a) * 1.15, math.sin(a) * 0.6, 1.0 + 0.25 * math.sin(a * 2))
        fragmentos.append(casca([(c[0] + rng.uniform(-0.18, 0.18), c[1] + rng.uniform(-0.18, 0.18), c[2] + rng.uniform(-0.18, 0.18)) for _ in range(7)], MARMORE))
    ouro = montar([
        kit.fita3d([(0.05, 0.62, 1.95), (0.15, 0.6, 1.7), (0.1, 0.62, 1.4)], 0.06, (0, 1, 0), OURO),
        anel((0, -0.1, 2.45), 0.55, 0.06, OURO, lados=24, inclinar=12, eixo="X"),
    ])
    return {
        "corpo": (montar(partes + fragmentos), "Marble", 0),
        "brilho": (ouro, "Neon", 0),
        "asa_e": (penas(-1, BRANCO, (-0.55, -0.35, 1.3), n=4, comp=0.9), "SmoothPlastic", 0),
        "asa_d": (penas(1, BRANCO, (0.55, -0.35, 1.3), n=4, comp=0.9), "SmoothPlastic", 0),
    }, {"voa": True, "junta_e": (-0.55, -0.35, 1.3), "junta_d": (0.55, -0.35, 1.3), "bater": 20}


VAZIO = (0.08, 0.06, 0.13)
MAGENTA = (0.95, 0.35, 1.0)


def olho_errante():
    globo = esfera((0, 0, 1.4), 0.62, 0.62, 0.62, (0.96, 0.94, 0.98), lados=14, aneis=8)
    iris = esfera((0, 0.5, 1.4), 0.36, 0.14, 0.36, MAGENTA, lados=12, aneis=4, topo_claro=0.0)
    pupila = esfera((0, 0.6, 1.4), 0.15, 0.06, 0.26, PRETO, lados=8, aneis=3, topo_claro=0.0)
    luz = esfera((0.1, 0.64, 1.53), 0.06, 0.03, 0.06, BRANCO, lados=6, aneis=3, topo_claro=0.0)
    aros = montar([anel((0, 0, 1.4), 0.95, 0.06, VAZIO, lados=24, inclinar=70, eixo="Y"), anel((0, 0, 1.4), 1.05, 0.05, VAZIO, lados=24, inclinar=-60, eixo="X")])
    runas = montar([estrela((0.95 * math.cos(a), 0, 1.4 + 0.95 * math.sin(a) * 0.34), 0.1, MAGENTA) for a in (0.3, 1.6, 2.9, 4.2, 5.5)])
    return {"corpo": (montar([globo, pupila, luz, aros]), "SmoothPlastic", 0), "brilho": (montar([iris, runas]), "Neon", 0)}, {"voa": True}


def gato_constelacao():
    corpo = montar([
        casca([(0.35, -0.55, 0.5), (-0.35, -0.55, 0.5), (0.38, 0.4, 0.5), (-0.38, 0.4, 0.5), (0.3, -0.5, 1.0), (-0.3, -0.5, 1.0), (0.32, 0.4, 1.05), (-0.32, 0.4, 1.05)], VAZIO),
        casca([(0.36, 0.35, 0.95), (-0.36, 0.35, 0.95), (0.32, 0.8, 1.0), (-0.32, 0.8, 1.0), (0.3, 0.45, 1.55), (-0.3, 0.45, 1.55), (0, 0.9, 1.25)], (0.12, 0.09, 0.18)),
        kit.espinho((0.22, 0.5, 1.45), (0.32, 0.45, 1.95), 0.24, VAZIO),
        kit.espinho((-0.22, 0.5, 1.45), (-0.32, 0.45, 1.95), 0.24, VAZIO),
        perna((0.22, 0.3, 0), (0.22, 0.3, 0.55), 0.09, VAZIO),
        perna((-0.22, 0.3, 0), (-0.22, 0.3, 0.55), 0.09, VAZIO),
        perna((0.22, -0.45, 0), (0.22, -0.45, 0.55), 0.09, VAZIO),
        perna((-0.22, -0.45, 0), (-0.22, -0.45, 0.55), 0.09, VAZIO),
        kit.fita3d([(0, -0.55, 0.85), (0.1, -0.9, 1.1), (0.05, -1.05, 1.6), (-0.2, -0.95, 1.95)], 0.16, (1, 0, 0), VAZIO),
        kit.fita3d([(0, -0.55, 0.85), (0.1, -0.9, 1.1), (0.05, -1.05, 1.6), (-0.2, -0.95, 1.95)], 0.16, (-1, 0, 0), VAZIO),
    ])
    nos = [(0.22, 0.85, 1.32), (-0.22, 0.85, 1.32), (0.3, 0.45, 1.95), (-0.3, 0.45, 1.95), (0.3, 0.0, 1.05), (-0.25, -0.35, 1.02), (0.05, -1.05, 1.6), (-0.2, -0.95, 1.95)]
    brilho = [estrela(p, 0.09, (0.85, 0.85, 1.0)) for p in nos]
    linhas = [(nos[2], nos[0]), (nos[0], nos[4]), (nos[4], nos[5]), (nos[5], nos[6]), (nos[6], nos[7]), (nos[3], nos[1])]
    for a, b in linhas:
        a2 = (a[0] * 1.04, a[1], a[2] + 0.02)
        b2 = (b[0] * 1.04, b[1], b[2] + 0.02)
        brilho.append(kit.fita3d([a2, b2], 0.03, (0, 0, 1), (0.75, 0.6, 1.0)))
    olhos = montar([esfera((0.15, 0.85, 1.3), 0.09, 0.05, 0.11, (1.0, 0.85, 0.35)), esfera((-0.15, 0.85, 1.3), 0.09, 0.05, 0.11, (1.0, 0.85, 0.35))])
    return {"corpo": (corpo, "SmoothPlastic", 0), "brilho": (montar(brilho + [olhos]), "Neon", 0)}, {"voa": False}


def dragao_estelar():
    partes, brilho = [], []
    caminho = []
    for k in range(9):
        f = k / 8
        caminho.append((0.55 * math.sin(f * 5.2), 0.9 - 2.4 * f, 1.5 + 0.45 * math.sin(f * 4.0 + 1.0)))
    for k, (x, y, z) in enumerate(caminho):
        r = 0.42 * (1 - k / 11)
        partes.append(casca([(x + r, y, z), (x - r, y, z), (x, y + r, z), (x, y - r, z), (x, y, z + r * 0.9), (x, y, z - r * 0.8), (x + r * 0.6, y + r * 0.6, z + r * 0.4)], kit.misturar(VAZIO, (0.25, 0.18, 0.45), k / 9)))
        brilho.append(estrela((x, y, z + r * 0.9), 0.08 + 0.04 * (k % 2), (0.9, 0.85, 1.0)))
        if k > 0:
            a, b = caminho[k - 1], caminho[k]
            brilho.append(kit.fita3d([(a[0], a[1], a[2] + 0.42 * (1 - (k - 1) / 11) * 0.9), (b[0], b[1], b[2] + r * 0.9)], 0.035, (0, 0, 1), (0.7, 0.55, 1.0)))
    hx, hy, hz = caminho[0]
    partes.append(casca([(hx + 0.35, hy + 0.1, hz), (hx - 0.35, hy + 0.1, hz), (hx + 0.25, hy + 0.85, hz - 0.05), (hx - 0.25, hy + 0.85, hz - 0.05), (hx + 0.3, hy + 0.2, hz + 0.4), (hx - 0.3, hy + 0.2, hz + 0.4), (hx, hy + 0.95, hz + 0.1)], (0.15, 0.10, 0.25)))
    partes += [olho((hx + 0.2, hy + 0.5, hz + 0.25), 0.08), olho((hx - 0.2, hy + 0.5, hz + 0.25), 0.08)]
    chifres = [kit.espinho((hx + s * 0.18, hy + 0.15, hz + 0.35), (hx + s * 0.45, hy - 0.35, hz + 0.85), 0.11, (0.85, 0.75, 1.0)) for s in (1, -1)]
    asa_e = vitral([([(-0.3, 0.3, 1.8), (-1.4, 0.0, 2.4), (-0.9, -0.3, 1.9)], (0.35, 0.2, 0.7)), ([(-0.3, 0.3, 1.8), (-0.9, -0.3, 1.9), (-0.5, -0.4, 1.6)], (0.55, 0.3, 0.9))], (0.85, 0.7, 1.0))
    asa_d = vitral([([(0.3, 0.3, 1.8), (1.4, 0.0, 2.4), (0.9, -0.3, 1.9)], (0.35, 0.2, 0.7)), ([(0.3, 0.3, 1.8), (0.9, -0.3, 1.9), (0.5, -0.4, 1.6)], (0.55, 0.3, 0.9))], (0.85, 0.7, 1.0))
    return {
        "corpo": (montar(partes), "SmoothPlastic", 0),
        "brilho": (montar(brilho + chifres), "Neon", 0),
        "asa_e": (asa_e, "Glass", 0.1),
        "asa_d": (asa_d, "Glass", 0.1),
    }, {"voa": True, "junta_e": (-0.3, 0.3, 1.8), "junta_d": (0.3, 0.3, 1.8), "bater": 16}


ECOS = [
    ("lasquinho", lasquinho),
    ("mariposa_vitral", mariposa_vitral),
    ("lanterneiro", lanterneiro),
    ("sininho_vidro", sininho_vidro),
    ("raposa_prisma", raposa_prisma),
    ("cervo_cantor", cervo_cantor),
    ("fagulha", fagulha),
    ("escaravelho_solar", escaravelho_solar),
    ("salamandra_obsidiana", salamandra_obsidiana),
    ("peixe_bolha", peixe_bolha),
    ("aguaviva_lanterna", aguaviva_lanterna),
    ("baleia_celeste", baleia_celeste),
    ("sino_alado", sino_alado),
    ("coruja_vitral", coruja_vitral),
    ("querubim_partido", querubim_partido),
    ("olho_errante", olho_errante),
    ("gato_constelacao", gato_constelacao),
    ("dragao_estelar", dragao_estelar),
]

# Núcleos: uma semente de cristal por mundo, com a cor da fase e um miolo aceso
NUCLEOS = [
    (VIOLETA, (0.95, 0.85, 1.0)),
    ((0.35, 0.95, 0.80), (0.85, 1.0, 0.95)),
    ((1.0, 0.50, 0.20), (1.0, 0.85, 0.5)),
    ((0.40, 0.85, 1.0), (0.85, 0.97, 1.0)),
    ((1.0, 0.80, 0.32), (1.0, 0.95, 0.75)),
    ((0.90, 0.35, 1.0), (1.0, 0.8, 1.0)),
]


def nucleo(i, cor, miolo):
    rng = random.Random(700 + i)
    pts = []
    for k in range(12):
        a = 2 * math.pi * k / 12 + rng.uniform(-0.15, 0.15)
        z = rng.uniform(-0.6, 0.6)
        r = 0.9 * math.sqrt(1 - (z / 1.25) ** 2) * rng.uniform(0.9, 1.08)
        pts.append((r * math.cos(a), r * math.sin(a), z * 1.25 + 1.3))
    pts += [(0, 0, 2.75), (0, 0, -0.05)]
    casco_ = casca(pts, cor, gradiente=(0, 2.75, kit.misturar(cor, (0, 0, 0), 0.5), kit.misturar(cor, BRANCO, 0.4)))
    aro = anel((0, 0, 1.3), 1.05, 0.06, (0.2, 0.18, 0.25), lados=20, inclinar=14, eixo="X")
    brilho = esfera((0, 0, 1.3), 0.42, 0.42, 0.55, miolo, lados=10, aneis=6)
    return {"vidro": (casco_, "Glass", 0.35), "corpo": (aro, "Metal", 0), "brilho": (brilho, "Neon", 0)}


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
        "-- GERADO por assets/pets/source/generate_pets.py. Não editar à mão.",
        "-- Peça de um Eco ou Núcleo (mesmo formato do kit do Nexo).",
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


ORDEM_PARTES = ["corpo", "vidro", "brilho", "asa_e", "asa_d"]


def main():
    os.makedirs(os.path.join(DIR_BASE, "previews"), exist_ok=True)
    os.makedirs(os.path.join(DIR_BASE, "source"), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materiais = {
        "SmoothPlastic": kit.criar_material("Eco_Liso", rugosidade=0.55),
        "Slate": kit.criar_material("Eco_Pedra"),
        "Metal": kit.criar_material("Eco_Metal", rugosidade=0.35, metalico=0.8),
        "Marble": kit.criar_material("Eco_Marmore", rugosidade=0.3),
        "Glass": kit.criar_material("Eco_Vidro", rugosidade=0.05, transmissao=0.85),
        "Neon": kit.criar_material("Eco_Brilho", emissao=6.0),
    }
    visuais = []
    objetos = {}
    total = 0
    for nome, fn in ECOS:
        partes, op = fn()
        registro = {"id": nome, "voa": op.get("voa", False), "partes": []}
        caixa_min = [1e9] * 3
        caixa_max = [-1e9] * 3
        for parte in ORDEM_PARTES:
            if parte not in partes:
                continue
            bm, material, transp = partes[parte]
            malha = "pet_%s_%s" % (nome, parte)
            obj = kit.registrar(malha, bm, materiais[material])
            objetos[malha] = obj
            for v in obj.data.vertices:
                for k in range(3):
                    caixa_min[k] = min(caixa_min[k], v.co[k])
                    caixa_max[k] = max(caixa_max[k], v.co[k])
            item = {"nome": parte, "malha": malha, "material": material, "transparencia": transp}
            if parte in ("asa_e", "asa_d"):
                item["junta"] = rbx(op["junta_e" if parte == "asa_e" else "junta_d"])
                item["bater"] = op.get("bater", 25)
            registro["partes"].append(item)
        registro["altura"] = caixa_max[2]
        registro["largura"] = max(caixa_max[0] - caixa_min[0], caixa_max[1] - caixa_min[1])
        visuais.append(registro)
    nucleos = []
    for i, (cor, miolo) in enumerate(NUCLEOS):
        partes = nucleo(i, cor, miolo)
        lista = []
        for parte in ("corpo", "vidro", "brilho"):
            bm, material, transp = partes[parte]
            malha = "nucleo_%d_%s" % (i + 1, parte)
            objetos[malha] = kit.registrar(malha, bm, materiais[material])
            lista.append({"nome": parte, "malha": malha, "material": material, "transparencia": transp})
        nucleos.append(lista)

    print("%-36s %6s" % ("peca", "tris"))
    for malha, obj in sorted(objetos.items()):
        t = escrever_malha(malha, obj)
        total += t
        print("%-36s %6d" % (malha, t))
    print("total de triângulos: %d" % total)

    linhas = [
        "-- GERADO por assets/pets/source/generate_pets.py. Não editar à mão.",
        "-- Como montar cada Eco e cada Núcleo: peças (malha, material, transparência) e, nas asas,",
        "-- a junta (studs, espaço do Eco, origem no chão) e quanto batem (graus).",
        "return {",
        "\tecos = {",
    ]
    for r in visuais:
        linhas.append("\t\t%s = {" % r["id"])
        linhas.append("\t\t\tvoa = %s," % ("true" if r["voa"] else "false"))
        linhas.append("\t\t\taltura = %.3f," % r["altura"])
        linhas.append("\t\t\tlargura = %.3f," % r["largura"])
        linhas.append("\t\t\tpartes = {")
        for p in r["partes"]:
            campos = ['nome = "%s"' % p["nome"], 'malha = "%s"' % p["malha"], 'material = "%s"' % p["material"], "transparencia = %.2f" % p["transparencia"]]
            if "junta" in p:
                campos.append("junta = %s" % v3(p["junta"]))
                campos.append("bater = %d" % p["bater"])
            linhas.append("\t\t\t\t{ " + ", ".join(campos) + " },")
        linhas.append("\t\t\t},")
        linhas.append("\t\t},")
    linhas += ["\t},", "\tnucleos = {"]
    for lista in nucleos:
        linhas.append("\t\t{")
        for p in lista:
            linhas.append('\t\t\t{ nome = "%s", malha = "%s", material = "%s", transparencia = %.2f },' % (p["nome"], p["malha"], p["material"], p["transparencia"]))
        linhas.append("\t\t},")
    linhas += ["\t},", "}", ""]
    with open(ARQ_VISUAL, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))

    # vitrine no Blender: Ecos em fila por mundo, Núcleos à frente
    for k, (nome, _) in enumerate(ECOS):
        for parte in ORDEM_PARTES:
            obj = objetos.get("pet_%s_%s" % (nome, parte))
            if obj:
                obj.location = ((k % 3) * 3.6 - 3.6, -(k // 3) * 4.2, 0)
                bpy.context.scene.collection.objects.link(obj)
    for i in range(6):
        for parte in ("corpo", "vidro", "brilho"):
            obj = objetos["nucleo_%d_%s" % (i + 1, parte)]
            obj.location = (8 + (i % 3) * 3, -(i // 3) * 4.2, 0)
            bpy.context.scene.collection.objects.link(obj)
    if "--render" in sys.argv:
        renderizar(objetos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "pets.blend"), compress=True)


def renderizar(objetos):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 48
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 520, 520
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 90
    cena.view_settings.view_transform = "AgX"
    mundo = bpy.data.worlds.new("Estudio")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.09, 0.07, 0.16, 1)
    mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    cena.world = mundo
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    chao = bpy.context.object
    m = bpy.data.materials.new("Chao")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.08, 0.065, 0.13, 1)
    chao.data.materials.append(m)
    bpy.ops.object.light_add(type="AREA", location=(3, 6, 8))
    luz = bpy.context.object
    luz.data.energy = 700
    luz.data.size = 6
    bpy.ops.object.light_add(type="AREA", location=(-6, -3, 4))
    luz2 = bpy.context.object
    luz2.data.energy = 250
    luz2.data.size = 5
    luz2.data.color = (0.7, 0.6, 1.0)
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cena.camera = cam
    cam.data.lens = 50
    # esconde tudo e mostra um modelo por vez
    for o in bpy.context.scene.collection.objects:
        if o.type == "MESH" and o is not chao:
            o.hide_render = True
    grupos = [("pet_%s" % n, n) for n, _ in ECOS] + [("nucleo_%d" % (i + 1), "nucleo_%d" % (i + 1)) for i in range(6)]
    for prefixo, nome in grupos:
        visiveis = [o for k, o in objetos.items() if k.startswith(prefixo + "_")]
        base = None
        for o in visiveis:
            o.hide_render = False
            base = o.location.copy()
        topo = max(max(v.co.z for v in o.data.vertices) for o in visiveis)
        alvo = base + Vector((0, 0, topo * 0.48))
        dist = max(4.2, topo * 2.3)
        cam.location = alvo + Vector((dist * 0.55, dist * 0.8, dist * 0.32))
        luz.location = alvo + Vector((3, 6, 8))
        luz2.location = alvo + Vector((-6, -3, 4))
        cam.rotation_euler = (alvo - cam.location).to_track_quat("-Z", "Y").to_euler()
        cena.render.filepath = os.path.join(DIR_BASE, "previews", nome + ".jpg")
        bpy.ops.render.render(write_still=True)
        for o in visiveis:
            o.hide_render = True
        print("prévia", nome)


if __name__ == "__main__":
    main()
