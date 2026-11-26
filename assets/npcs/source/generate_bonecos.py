"""NPCs no estilo boneco do Roblox (ver src/shared/Dados/Bonecos.luau). Testado com bpy 5.3.

O corpo (tronco, braços e pernas) é feito de Parts comuns no jogo, como o boneco dos jogadores.
Do Blender saem só as peças arredondadas: a cabeça (cubo arredondado 1.2, como a cabeça clássica)
e os cabelos, já coloridos por NPC. Origem = centro da cabeça; +Y (Blender) = frente.

Uso:
    python assets/npcs/source/generate_bonecos.py            # malhas
    python assets/npcs/source/generate_bonecos.py --render   # e as prévias (NÃO são prints do Roblox)

A prévia monta o boneco inteiro com as mesmas medidas e peças que o cliente (Mundo/Boneco.luau).
"""

import math
import os
import random
import sys

sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "assets", "nexo", "source"))
sys.path.insert(0, os.path.join(RAIZ, "assets", "equipamento", "source"))

import bpy  # noqa: E402
import bmesh  # noqa: E402

import generate_nexo as kit  # noqa: E402
import generate_equipamento as eq  # noqa: E402
from mathutils import Vector, Matrix  # noqa: E402

T, R, bx, montar = eq.T, eq.R, eq.bx, eq.montar
DIR_PREV = os.path.join(RAIZ, "assets", "npcs", "previews")
rng = random.Random(3)


def hexa(h):
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def esfera(c, r, cor, esc=(1, 1, 1), lados=12, aneis=8):
    perfil = [(max(r * math.sin(math.pi * k / aneis), 0.001), -r * math.cos(math.pi * k / aneis)) for k in range(aneis + 1)]
    bm = kit.torno(perfil, lados, cor, rng, tinta=1.0)
    bmesh.ops.transform(bm, matrix=T(c) @ Matrix.Diagonal((*esc, 1)), verts=bm.verts[:])
    kit.pintar(bm, cor, 1.0, topo_claro=0.2)
    return bm


def misturar(a, b, f):
    return tuple(a[i] + (b[i] - a[i]) * f for i in range(3))


def escurecer(c, f):
    return tuple(min(max(v * f, 0.0), 1.0) for v in c)


def cabeca(cor):
    # cubo arredondado 1.2 (a cabeça clássica do boneco), com luz de cima e sombra no queixo
    bm = bx((0, 0, 0), (1.2, 1.2, 1.2), cor, 0.16)
    kit.pintar(bm, cor, 1.0, topo_claro=0.15, gradiente=(-0.6, 0.6, escurecer(cor, 0.86), misturar(cor, (1, 1, 1), 0.12)))
    return montar([bm])


# ============================================================ roupa "pintada" (técnica dos templates de roupa)
# Os jogos detalham o boneco pintando a roupa por cima dos blocos: sombra suave nas bordas,
# degradê de luz de cima, sombra embaixo da gola, dobras nos cotovelos/joelhos e costuras. Aqui a
# mesma ideia vira cor por vértice numa caixa subdividida, mais alguns relevos (emblema, punhos,
# botas, fivela, botões). As medidas são as do boneco (tronco 2x1x2, membros 1x1x2 em Blender).

def suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def caixa_pintada(sx, sy, sz, pintor, cortes=14):
    bm = kit.novo_bm()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts[:])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cortes, use_grid_fill=True)
    camada = bm.loops.layers.color["Col"]
    bm.normal_update()
    meia = (sx / 2, sy / 2, sz / 2)
    for face in bm.faces:
        n = face.normal
        eixo = max(range(3), key=lambda k: abs(n[k]))
        luz = 0.84 + 0.16 * max(n.z, 0.0)
        if n.z < -0.5:
            luz *= 0.82
        for loop in face.loops:
            q = loop.vert.co
            # distância até a borda da face (sombra suave nas quinas, como no template)
            d = min(meia[k] - abs(q[k]) for k in range(3) if k != eixo)
            borda = 1.0 - 0.16 * (1.0 - suave(0.0, 0.14, d))
            cor = pintor(q, n)
            loop[camada] = tuple(min(c * luz * borda, 1.0) for c in cor) + (1.0,)
    return bm


def linha(v, centro, largura):
    """1 no centro da linha, 0 longe (para dobras e costuras)."""
    return max(0.0, 1.0 - abs(v - centro) / largura)


def tronco_tita():
    branco, sombra, ouro = hexa("FFFDF6"), hexa("E7E2EE"), hexa("FFC23A")
    def pintor(q, n):
        c = branco
        frente = n.y > 0.5
        # quimono cruzado: a borda do pano desce em diagonal na frente
        if frente:
            borda = 0.42 * (q.z) - 0.05
            c = misturar(c, sombra, 0.55 * linha(q.x, borda, 0.06))
            if q.x > borda:
                c = escurecer(c, 0.97)
        # sombra embaixo da gola e dobras nas laterais
        c = misturar(c, sombra, 0.6 * suave(0.6, 1.0, q.z))
        c = misturar(c, sombra, 0.35 * linha(q.x + 0.3 * q.z, 0.75, 0.08) + 0.35 * linha(-q.x + 0.3 * q.z, 0.75, 0.08))
        c = misturar(c, sombra, 0.4 * suave(-0.75, -1.0, q.z))
        return c
    partes = [caixa_pintada(2, 1, 2, pintor)]
    # emblema de sol em relevo no peito
    partes.append(eq.cilindro((0.45, 0.52, 0.35), 0.26, 0.05, ouro, 16, R(90, "X")))
    for k in range(8):
        a = math.radians(k * 45)
        partes.append(bx((0.45 + math.cos(a) * 0.36, 0.53, 0.35 + math.sin(a) * 0.36), (0.1, 0.03, 0.14), ouro, 0.0, R(-k * 45 + 90, "Y")))
    return montar(partes)


def braco_tita(lado):
    pele, sombra, branco = hexa("FFF6E8"), hexa("EBD9C2"), hexa("FFFFFF")
    def pintor(q, n):
        c = pele
        c = misturar(c, sombra, 0.45 * linha(q.z, 0.05, 0.08) * (1 if n.y > 0.5 else 0.4))  # cotovelo
        c = misturar(c, sombra, 0.3 * suave(0.7, 1.0, q.z))  # sombra do ombro
        return c
    partes = [caixa_pintada(1, 1, 2, pintor, 10)]
    # punho de nuvem fofo no pulso
    for k in range(6):
        a = k * math.pi / 3
        partes.append(esfera((math.cos(a) * 0.5, math.sin(a) * 0.5, -0.74), 0.24, branco, lados=8, aneis=5))
    return montar(partes)


def perna_tita(lado):
    branco, sombra, ouro, pele = hexa("FFFDF6"), hexa("E2DDEA"), hexa("FFC23A"), hexa("FFF0DC")
    def pintor(q, n):
        c = branco
        if q.z < -0.8:
            return pele  # pés descalços
        c = misturar(c, sombra, 0.5 * linha(q.z, 0.05, 0.09) + 0.35 * linha(q.z, -0.25, 0.07))  # dobras do joelho
        if (n.x * lado) < -0.5:
            c = misturar(c, sombra, 0.4)  # lado de dentro na sombra
        c = misturar(c, sombra, 0.4 * linha(q.x * lado, -0.45, 0.06) * (1 if abs(n.y) > 0.5 else 0))  # costura
        return c
    partes = [caixa_pintada(1, 1, 2, pintor, 10)]
    partes.append(bx((0, 0, -0.68), (1.06, 1.06, 0.16), ouro, 0.03))  # tornozeleira dourada
    partes.append(bx((0, 0.1, -0.97), (1.02, 1.2, 0.08), hexa("B07A3A"), 0.02))  # sandália
    return montar(partes)


def tronco_lume():
    lilas, sombra, branco, roxo, ouro = hexa("C0ADFF"), hexa("9A86E0"), hexa("FFFFFF"), hexa("5B3FB0"), hexa("FFD54A")
    def pintor(q, n):
        c = lilas
        frente = n.y > 0.5
        c = misturar(c, sombra, 0.45 * suave(0.55, 0.95, q.z))
        # cinto
        if -0.78 < q.z < -0.55:
            c = roxo
        # barra branca
        if q.z < -0.88:
            c = branco
        # dobras que saem do cinto e costuras laterais
        c = misturar(c, sombra, 0.3 * linha(q.x, 0.55, 0.06) * suave(0.0, -0.5, q.z) + 0.3 * linha(q.x, -0.55, 0.06) * suave(0.0, -0.5, q.z))
        return c
    partes = [caixa_pintada(2, 1, 2, pintor)]
    # gola em V branca em relevo (duas lapelas) e gola de trás
    for lado in (-1, 1):
        partes.append(bx((lado * 0.2, 0.52, 0.78), (0.5, 0.05, 0.16), branco, 0.02, R(lado * 35, "Y")))
    partes.append(bx((0, 0, 0.95), (1.5, 1.04, 0.12), branco, 0.03))
    partes.append(bx((0, 0.52, -0.665), (0.36, 0.06, 0.26), ouro, 0.02))  # fivela
    partes.append(bx((0, 0.54, -0.665), (0.18, 0.06, 0.12), roxo, 0.0))
    for z in (0.3, -0.05, -0.38):
        partes.append(esfera((0, 0.52, z), 0.06, ouro, lados=8, aneis=5))  # botões
    return montar(partes)


def braco_lume(lado):
    lilas, sombra, branco, pele = hexa("C0ADFF"), hexa("9A86E0"), hexa("FFFFFF"), hexa("FFDCC4")
    def pintor(q, n):
        if q.z < -0.45:
            return misturar(pele, escurecer(pele, 0.9), suave(-0.6, -1.0, q.z))  # mão
        c = lilas
        c = misturar(c, sombra, 0.45 * linha(q.z, 0.05, 0.08) + 0.3 * suave(0.7, 1.0, q.z))  # cotovelo e ombro
        return c
    partes = [caixa_pintada(1, 1, 2, pintor, 10)]
    partes.append(bx((0, 0, -0.38), (1.08, 1.08, 0.16), branco, 0.03))  # punho da manga
    return montar(partes)


def perna_lume(lado):
    branco, sombra, bota, sola = hexa("F7F2EC"), hexa("D8D0E6"), hexa("8F7BE0"), hexa("4A3A8A")
    def pintor(q, n):
        if q.z < -0.25:
            if q.z < -0.9:
                return sola
            return misturar(bota, escurecer(bota, 0.85), 0.5 * linha(q.z, -0.6, 0.08))
        c = branco
        c = misturar(c, sombra, 0.4 * linha(q.z, 0.1, 0.08))
        if (n.x * lado) < -0.5:
            c = misturar(c, sombra, 0.35)
        return c
    partes = [caixa_pintada(1, 1, 2, pintor, 10)]
    partes.append(bx((0, 0, -0.22), (1.1, 1.1, 0.16), bota, 0.03))  # borda da bota
    partes.append(bx((0, 0.08, -0.96), (1.04, 1.18, 0.1), sola, 0.02))  # sola com bico
    return montar(partes)


def espelhar(bm):
    bmesh.ops.scale(bm, vec=(-1, 1, 1), verts=bm.verts[:])
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    return bm


def cabelo_nuvem():
    branco = hexa("FFFFFF")
    g = random.Random(11)
    partes = []
    # topo fofo
    for c, r in [((0, -0.05, 0.62), 0.42), ((-0.38, 0.0, 0.52), 0.34), ((0.38, 0.0, 0.52), 0.34), ((0, -0.42, 0.45), 0.4),
                 ((-0.5, -0.32, 0.25), 0.3), ((0.5, -0.32, 0.25), 0.3), ((0, 0.28, 0.6), 0.3), ((-0.22, -0.55, 0.05), 0.3), ((0.22, -0.55, 0.05), 0.3)]:
        partes.append(esfera(c, r, branco, lados=10, aneis=6))
    # mechas espetadas para cima (cabelo "despertado")
    for k in range(7):
        a = (k - 3) * 0.42
        base = (math.sin(a) * 0.35, -0.15 + abs(k - 3) * 0.03, 0.8)
        topo = (math.sin(a) * 0.75, -0.3 - g.uniform(0, 0.15), 1.45 - abs(k - 3) * 0.1)
        partes.append(eq.ponta(base, topo, 0.32, branco))
    bm = montar(partes)
    # nuvem: sombra azulada embaixo, branco puro em cima
    kit.pintar(bm, branco, 1.0, topo_claro=0.2, gradiente=(-0.2, 1.2, hexa("D6E0F2"), hexa("FFFFFF")))
    return bm


def cabelo_longo():
    lilas = hexa("A58BF0")
    escuro = hexa("7A62C8")
    partes = []
    # touca: casca por cima da cabeça
    partes.append(bx((0, -0.06, 0.42), (1.36, 1.36, 0.5), lilas, 0.22))
    # franja em mechas na frente
    for k in range(5):
        x = (k - 2) * 0.26
        partes.append(eq.ponta((x, 0.6, 0.55), (x + 0.06 * (k - 2), 0.66, 0.34 - 0.04 * abs(k - 2)), 0.3, lilas))
    # laterais e trás longos (até os ombros/costas)
    for lado in (-1, 1):
        partes.append(bx((lado * 0.66, 0.05, -0.15), (0.22, 0.9, 1.4), lilas, 0.1))
    partes.append(bx((0, -0.62, -0.55), (1.3, 0.3, 2.2), escuro, 0.14))
    for k in range(4):
        x = (k - 1.5) * 0.32
        partes.append(eq.ponta((x, -0.65, -1.5), (x * 1.1, -0.72, -2.05), 0.3, escuro))
    bm = montar(partes)
    # degradê: pontas mais escuras, topo claro
    kit.pintar(bm, lilas, 1.0, topo_claro=0.25, gradiente=(-2.0, 0.7, hexa("6A52B8"), hexa("BFA8FF")))
    # reflexo de luz (o "anel" brilhante dos cabelos de anime)
    reflexo = []
    for k in range(5):
        a = math.radians(-50 + k * 25)
        reflexo.append(bx((math.sin(a) * 0.62, math.cos(a) * 0.62 - 0.06, 0.5), (0.18, 0.05, 0.05), hexa("E8DEFF"), 0.0, R(-math.degrees(a), "Z")))
    # laço
    reflexo.append(esfera((0.45, -0.3, 0.72), 0.16, hexa("B7FFD9")))
    return montar([bm] + reflexo)


MALHAS = {
    "boneco_cabeca_tita": lambda: cabeca(hexa("FFF6E8")),
    "boneco_cabeca_lume": lambda: cabeca(hexa("FFDCC4")),
    "boneco_cabeca_estatua": lambda: cabeca(hexa("F2EEE6")),
    "boneco_cabelo_nuvem": cabelo_nuvem,
    "boneco_cabelo_longo": cabelo_longo,
    "boneco_tita_tronco": tronco_tita,
    "boneco_tita_bracoD": lambda: braco_tita(1),
    "boneco_tita_bracoE": lambda: espelhar(braco_tita(1)),
    "boneco_tita_pernaD": lambda: perna_tita(1),
    "boneco_tita_pernaE": lambda: perna_tita(-1),
    "boneco_lume_tronco": tronco_lume,
    "boneco_lume_bracoD": lambda: braco_lume(1),
    "boneco_lume_bracoE": lambda: espelhar(braco_lume(1)),
    "boneco_lume_pernaD": lambda: perna_lume(1),
    "boneco_lume_pernaE": lambda: perna_lume(-1),
}


# ============================================================ prévia (mesmas peças do cliente)

def face(defn, cabeca_c, cor_pele):
    """Rosto feito de discos e blocos, igual ao cliente (Mundo/Boneco.luau)."""
    x0, y0, z0 = cabeca_c
    f = y0 + 0.61
    out = []
    escuro = hexa("2A1A10")
    branco = hexa("FFFFFF")
    def disco(cx, cz, d, cor, dy=0.0):
        return eq.cilindro((x0 + cx, f + dy, z0 + cz), d / 2, 0.04, cor, 16, R(90, "X"))
    def bloco(cx, cz, w, h, cor, giro=0.0, dy=0.0):
        return bx((x0 + cx, f + dy, z0 + cz), (w, 0.04, h), cor, 0.0, R(giro, "Y"))
    sobr = hexa(defn.get("corSobrancelha", "6A4A30"))
    for lado in (-1, 1):
        ex = lado * 0.25
        if defn["olhos"] == "aneis":
            out.append(disco(ex, 0.08, 0.46, hexa(defn["corOlhos"]), -0.004))
            out.append(disco(ex, 0.08, 0.34, branco, 0.0))
            out.append(disco(ex, 0.08, 0.17, escuro, 0.004))
        else:
            out.append(disco(ex, 0.04, 0.3, escuro, -0.004))
            out.append(disco(ex, 0.03, 0.24, hexa(defn["corOlhos"]), 0.0))
            out.append(disco(ex, 0.02, 0.12, escuro, 0.004))
        # dois brilhos no olho
        out.append(disco(ex + 0.05, 0.1, 0.09, branco, 0.008))
        out.append(disco(ex - 0.05, -0.02, 0.045, branco, 0.008))
        # sobrancelha arqueada (alegre)
        out.append(bloco(ex, 0.29, 0.22, 0.05, sobr, lado * 12, 0.004))
        if defn.get("cilios"):
            out.append(bloco(ex, 0.185, 0.28, 0.03, escuro, 0, 0.006))
            out.append(bloco(ex + lado * 0.15, 0.2, 0.07, 0.025, escuro, lado * -35, 0.006))
        if defn.get("bochechas"):
            out.append(disco(lado * 0.42, -0.15, 0.16, hexa("FF9E9E"), 0.0))
    if defn["boca"] == "sorrisao":
        out.append(bloco(0, -0.24, 0.52, 0.24, hexa("6A1E1E")))
        out.append(bloco(0, -0.15, 0.48, 0.07, branco, 0, 0.006))
        out.append(bloco(0, -0.32, 0.26, 0.07, hexa("FF7A8A"), 0, 0.006))
    else:
        # sorriso em três blocos formando a curva
        boca = hexa("6A1E1E")
        out.append(bloco(0, -0.27, 0.16, 0.05, boca))
        out.append(bloco(0.12, -0.245, 0.11, 0.05, boca, -28))
        out.append(bloco(-0.12, -0.245, 0.11, 0.05, boca, 28))
    return out


def boneco(defn, x, escala):
    """Boneco inteiro na escala 1 (pés em z = 0), deslocado em x; depois escalado."""
    pele, camisa, calca = hexa(defn["pele"]), hexa(defn["camisa"]), hexa(defn["calca"])
    p = []
    membros = [("pernaD", (0.5, 0, 1), (1, 1, 2), calca), ("pernaE", (-0.5, 0, 1), (1, 1, 2), calca), ("tronco", (0, 0, 3), (2, 1, 2), camisa),
               ("bracoD", (1.5, 0, 3), (1, 1, 2), pele), ("bracoE", (-1.5, 0, 3), (1, 1, 2), pele)]
    if defn.get("vitoria"):
        # pose da estátua: punho direito erguido
        membros[3] = ("bracoD_erguido", (1.71, 0, 3.95), (1, 1, 2), pele)
    malhas_corpo = []
    for nome, c, tam, cor in membros:
        chave = "boneco_%s_%s" % (defn["id"], nome)
        if chave in MALHAS:
            malhas_corpo.append((chave, c))
        elif nome == "bracoD_erguido":
            p.append(bx(c, tam, cor, 0.02, R(-155, "Y")))
        else:
            p.append(bx(c, tam, cor, 0.02))
    brilho = []
    for a in defn.get("extras", []):
        if a == "faixa":
            ouro = hexa("FFB52E")
            p.append(bx((0, 0, 2.18), (2.08, 1.08, 0.36), ouro, 0.03))
            p.append(esfera((0.55, 0.56, 2.18), 0.16, ouro))
            p.append(bx((0.68, 0.56, 1.75), (0.18, 0.06, 0.7), ouro, 0.02, R(-12, "Y")))
        elif a == "gola":
            for k in range(5):
                ang = math.radians(-60 + k * 30)
                p.append(esfera((math.sin(ang) * 0.75, math.cos(ang) * 0.2 - 0.1, 4.0), 0.32, hexa("FFFFFF"), lados=10, aneis=6))
        elif a == "aureola":
            sol = hexa("FFD54A")
            brilho.append(eq.cilindro((0, -0.7, 4.6), 1.3, 0.08, sol, 24, R(90, "X")))
            for k in range(12):
                r = math.radians(k * 30)
                brilho.append(bx((math.cos(r) * 1.5, -0.72, 4.6 + math.sin(r) * 1.5), (0.22, 0.06, 0.5), sol, 0.0, R(-k * 30 + 90, "Y")))
        elif a == "capa":
            p.append(bx((0, -0.58, 2.6), (2.1, 0.12, 2.6), hexa("8F7BE0"), 0.03))
        elif a == "estrela":
            menta = hexa("B7FFD9")
            brilho.append(bx((0.0, 0, 5.75), (0.4, 0.08, 0.4), menta, 0.0, R(45, "Y")))
            brilho.append(bx((0.0, 0, 5.75), (0.56, 0.06, 0.12), menta, 0.0))
            brilho.append(bx((0.0, 0, 5.75), (0.12, 0.06, 0.56), menta, 0.0))
    p += face(defn, (0, 0, 4.6), pele)
    objs = []
    mat = kit.criar_material("b", rugosidade=0.6)
    matb = kit.criar_material("bb", emissao=2.5)
    for i, (bm, m) in enumerate(((montar(p), mat), (montar(brilho), matb))):
        if len(bm.faces):
            objs.append(kit.registrar("prev_%s_%d" % (defn["id"], i), bm, m))
    for nome in (defn["cabeca"], defn["cabelo"]):
        if nome:
            o = kit.registrar("prev_" + nome + defn["id"], MALHAS[nome](), mat)
            o.location = (0, 0, 4.6)
            objs.append(o)
    for chave, c in malhas_corpo:
        o = kit.registrar("prev_" + chave, MALHAS[chave](), mat)
        o.location = c
        objs.append(o)
    pai = bpy.data.objects.new("raiz_" + defn["id"], None)
    for o in objs:
        o.parent = pai
    pai.scale = (escala, escala, escala)
    pai.location = (x, 0, 0)
    return [pai] + objs


DEFS = {
    "tita": dict(id="tita", pele="FFF6E8", camisa="FFFFFF", calca="FFFFFF", olhos="aneis", corOlhos="FFD54A", boca="sorrisao",
                 bochechas=True, corSobrancelha="C9B79A", cabeca="boneco_cabeca_tita", cabelo="boneco_cabelo_nuvem", extras=["faixa", "gola", "aureola"]),
    "lume": dict(id="lume", pele="FFDCC4", camisa="C0ADFF", calca="F7F2EC", olhos="redondos", corOlhos="5B3FB0", boca="sorriso",
                 bochechas=True, cilios=True, corSobrancelha="6A52B8", cabeca="boneco_cabeca_lume", cabelo="boneco_cabelo_longo", extras=["capa", "estrela"]),
    "estatua": dict(id="estatua", pele="F2EEE6", camisa="F7F4EE", calca="ECE6DA", olhos="aneis", corOlhos="FFD54A", boca="sorrisao",
                    corSobrancelha="D8CFBF", cabeca="boneco_cabeca_estatua", cabelo="boneco_cabelo_nuvem", extras=["faixa", "gola", "aureola"], vitoria=True),
    # jogador comum ao lado, para mostrar a escala (cores clássicas do boneco)
    "jogador": dict(id="jogador", pele="F5CD30", camisa="0D69AC", calca="A4BD47", olhos="redondos", corOlhos="2A1A10", boca="sorriso",
                    cabeca="boneco_cabeca_lume", cabelo=None, extras=[]),
}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = kit.criar_material("Boneco", rugosidade=0.6)
    for nome, fn in MALHAS.items():
        obj = kit.registrar(nome, fn(), mat)
        eq.escrever_malha(nome, obj)
    if "--render" in sys.argv:
        renderizar()


def cena(fundo):
    c = bpy.context.scene
    for o in list(c.collection.objects):
        bpy.data.objects.remove(o)
    c.render.engine = "CYCLES"; c.cycles.samples = 48; c.cycles.use_denoising = True
    c.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (*fundo, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    c.world = w
    bpy.ops.mesh.primitive_plane_add(size=400)
    chao = bpy.context.object; m = bpy.data.materials.new("chao"); m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.62, 0.35, 1)
    chao.data.materials.append(m)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(45), 0, math.radians(160))); bpy.context.object.data.energy = 3.2
    return c


def foto(c, nome, pos, alvo, lente=45, res=(1200, 1000)):
    c.render.resolution_x, c.render.resolution_y = res
    bpy.ops.object.camera_add(); cam = bpy.context.object; c.camera = cam; cam.data.lens = lente
    cam.location = pos
    cam.rotation_euler = (Vector(alvo) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    c.render.filepath = os.path.join(DIR_PREV, nome)
    c.render.image_settings.file_format = "JPEG"
    bpy.ops.render.render(write_still=True)


def renderizar():
    os.makedirs(DIR_PREV, exist_ok=True)
    # 1) Titã gigante com um jogador do lado
    c = cena((0.98, 0.9, 0.7))
    for o in boneco(DEFS["tita"], 0, 5) + boneco(DEFS["jogador"], 9, 1):
        c.collection.objects.link(o)
    foto(c, "tita_boneco.jpg", (20, 46, 14), (2.5, 0, 12))
    foto(c, "tita_detalhe.jpg", (6, 22, 21), (0, 0, 19), lente=50)
    # 1b) estátua da Gear 5 no pedestal, com um jogador olhando
    c = cena((0.98, 0.9, 0.7))
    ped = kit.torno([(0.001, 0), (5.5, 0), (5.5, 0.5), (5.0, 0.5), (5.0, 2.4), (0.001, 2.4)], 32, hexa("E8E2D6"), rng, tinta=1.0)
    kit.pintar(ped, hexa("E8E2D6"), 1.0, topo_claro=0.3)
    anel = eq.cilindro((0, 0, 2.45), 5.2, 0.15, hexa("FFC23A"), 32)
    objp = kit.registrar("pedestal", montar([ped, anel]), kit.criar_material("ped", rugosidade=0.4))
    c.collection.objects.link(objp)
    raizes = boneco(DEFS["estatua"], 0, 2.2)
    raizes[0].location = (0, 0, 2.4)
    for o in raizes + boneco(DEFS["jogador"], 9, 1):
        c.collection.objects.link(o)
    foto(c, "estatua_gear5.jpg", (18, 30, 10), (2, 0, 7))
    # 2) Lume de perto
    c = cena((0.75, 0.7, 0.95))
    for o in boneco(DEFS["lume"], 0, 1) + boneco(DEFS["jogador"], 4.4, 1):
        c.collection.objects.link(o)
    foto(c, "lume_boneco.jpg", (6.5, 12, 4.4), (2.0, 0, 3.0))
    foto(c, "lume_detalhe.jpg", (1.4, 4.6, 4.3), (0, 0, 3.9), lente=50)


if __name__ == "__main__":
    main()
