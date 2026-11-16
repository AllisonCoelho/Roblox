"""Gera as malhas da aura Gear 5 ("nuvens vivas") no Blender (testado com bpy 5.3) e exporta tudo.

Uso (Blender como módulo Python):
    pip install bpy numpy
    python assets/auras/gear5/source/generate_gear5.py            # malhas, .blend, .fbx e dados Luau
    python assets/auras/gear5/source/generate_gear5.py --render   # também renderiza as prévias

Saídas:
    assets/auras/gear5/source/gear5_clouds.blend   cena editável
    assets/auras/gear5/exports/<peca>.fbx          uma peça por arquivo (3D Importer do Studio)
    assets/auras/gear5/previews/*.png              renders do Blender (NÃO são capturas do Roblox)
    src/client/Mundo/Auras/Dados/gear5_<peca>.luau geometria compacta lida pelo jogo (EditableMesh)
    src/client/Mundo/Auras/Gear5Pecas.luau         onde cada peça fica em volta do personagem

Escala: 1 unidade = 1 stud. Avatar R15 padrão: chão em z=0, centro do HumanoidRootPart em z=3.
O avatar olha para +Y (frente); "atrás" é -Y. Conversão para o Roblox, relativa ao
HumanoidRootPart: (x, y, z) Blender -> (x, z - 3, -y).

Segue a imagem de referência do dono: faixa grossa em S por cima da cabeça terminando num caracol,
nuvens fofas nos ombros, tentáculos finos abraçando a cintura, pontas de chama afiadas e gotinhas.
Volumes com metaballs; chamas, caracóis e tentáculos como tubos afinados. Cada peça é presa a um
membro. As cores por vértice já trazem o sombreado lavanda.
Sementes fixas: rodar de novo gera os mesmos arquivos.
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
from mathutils.bvhtree import BVHTree  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
DIR_BASE = os.path.join(RAIZ, "assets", "auras", "gear5")
DIR_LUAU = os.path.join(RAIZ, "src", "client", "Mundo", "Auras")
DIR_DADOS = os.path.join(DIR_LUAU, "Dados")
ALTURA_RAIZ = 3.0  # centro do HumanoidRootPart acima do chão
CABECA_R15 = 1.5  # cabeça acima do HumanoidRootPart num R15 padrão (referência de escala)

# Paleta (sRGB 0..1) — tabela 2.3 do briefing
NUCLEO = (1.0, 0.992, 0.988)  # FFFDFC
BORDA = (0.961, 0.949, 1.0)  # F5F2FF
SOMBRA = (0.74, 0.73, 0.9)  # BDBAE6 (sombra azul-lilás suave)
DOBRA = (0.686, 0.663, 0.839)  # AFA9D6
LUZ = Vector((0.35, 0.75, 0.62)).normalized()  # luz-chave de frente e de cima


def catmull(pts, n):
    """Curva Catmull-Rom que passa pelos pontos; devolve n amostras uniformes no parâmetro."""
    p = [Vector(x) for x in pts]
    p = [p[0] * 2 - p[1]] + p + [p[-1] * 2 - p[-2]]
    out = []
    seg = len(p) - 3
    for i in range(n):
        t = i / (n - 1) * seg
        k = min(int(t), seg - 1)
        u = t - k
        a, b, c, d = p[k], p[k + 1], p[k + 2], p[k + 3]
        out.append(
            0.5
            * (
                2 * b
                + (-a + c) * u
                + (2 * a - 5 * b + 4 * c - d) * u * u
                + (-a + 3 * b - 3 * c + d) * u * u * u
            )
        )
    return out


def suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- volume (metaballs)


class Volume:
    """Junta esferas (metaballs) e converte em uma malha lisa e contínua."""

    def __init__(self, nome):
        self.mb = bpy.data.metaballs.new(nome)
        self.mb.resolution = 0.05
        self.mb.render_resolution = 0.05
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
        return e

    def malha(self):
        dg = bpy.context.evaluated_depsgraph_get()
        ev = self.obj.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev)
        bpy.data.objects.remove(self.obj)
        bm = bmesh.new()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        return bm


def tubo(bm, caminho, raios, lados=10):
    """Tubo afinado ao longo de um caminho (para caracóis, línguas e mechas)."""
    n = len(caminho)
    anel_ant = None
    ref = Vector((0, 0, 1))
    for i, p in enumerate(caminho):
        t = (caminho[min(i + 1, n - 1)] - caminho[max(i - 1, 0)]).normalized()
        if abs(t.dot(ref)) > 0.95:
            ref = Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        v = t.cross(u).normalized()
        ref = v
        r = raios[i]
        anel = [bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * r) for a in (2 * math.pi * j / lados for j in range(lados))]
        if anel_ant:
            for j in range(lados):
                bm.faces.new((anel_ant[j], anel_ant[(j + 1) % lados], anel[(j + 1) % lados], anel[j]))
        else:
            bm.faces.new(list(reversed(anel)))
        anel_ant = anel
    bm.faces.new(anel_ant)


def espiral(centro, u, v, r0, voltas, n=40, encolher=0.18):
    """Espiral em caracol no plano (u, v): começa fora (r0) e enrola para dentro."""
    pts = []
    for i in range(n):
        f = i / (n - 1)
        a = f * voltas * 2 * math.pi
        r = r0 * (1 - f * (1 - encolher))
        pts.append(centro + (u * math.cos(a) + v * math.sin(a)) * r)
    return pts


def base_plano(normal):
    normal = normal.normalized()
    ref = Vector((0, 0, 1)) if abs(normal.z) < 0.9 else Vector((1, 0, 0))
    u = normal.cross(ref).normalized()
    v = normal.cross(u).normalized()
    return u, v


def cacho(vol, centro, normal, tam, rng, voltas=1.2):
    """Cacho desenhado: espiral de bolas em relevo na superfície (o "@" das nuvens).

    Feito com metaballs, ele se funde com a massa em vez de parecer uma peça colada."""
    u, v = base_plano(normal)
    giro = rng.uniform(0, 2 * math.pi)
    u, v = u * math.cos(giro) + v * math.sin(giro), v * math.cos(giro) - u * math.sin(giro)
    n = 22
    for i, p in enumerate(espiral(centro, u, v, tam, voltas, n=n, encolher=0.25)):
        f = i / (n - 1)
        vol.bola(p + normal.normalized() * 0.04 * (1 - f), max(tam * 0.36 * (1 - 0.6 * f), 0.085))


def lingua(vol, base, direcao, lado, comp, grossura):
    """Lambida de nuvem: sai da borda, afina e termina enrolando em gancho."""
    d = direcao.normalized()
    lado = lado.normalized()
    n = 18
    for i in range(n):
        f = i / (n - 1)
        curva = math.sin(f * math.pi * 0.5) ** 2
        p = base + d * comp * f + lado * comp * 0.45 * curva
        if f > 0.55:  # gancho final, enrolando de volta
            g = (f - 0.55) / 0.45
            p += -d * comp * 0.55 * g * g + lado * comp * 0.25 * g
        vol.bola(p, max(grossura * (1 - 0.7 * f ** 1.2), 0.1))


# ---------------------------------------------------------------- peças
#
# Segue a referência do dono (4 vistas): uma faixa grossa em "S" que sobe por trás do ombro
# esquerdo, passa por cima da cabeça e termina num caracol grande no alto à direita; nuvens
# fofas (couve-flor) nos ombros; tentáculos finos que abraçam a cintura pela frente; e muitas
# pontas de chama afiadas e curvas saindo da borda, além de gotinhas soltas.

OSSOS = {
    "raiz": Vector((0, 0, 3.0)),  # HumanoidRootPart
    "tronco": Vector((0, 0, 3.55)),  # UpperTorso (R6: Torso)
    "cabeca": Vector((0, 0, 4.9)),  # Head
    "braco_dir": Vector((1.5, 0, 2.75)),  # RightLowerArm (R6: Right Arm)
    "braco_esq": Vector((-1.5, 0, 2.75)),  # LeftLowerArm (R6: Left Arm)
}


def tubo_liso(bm, pts, raios, lados=12):
    """Tubo com referencial transportado (não torce) e ponta fechada: chamas e tentáculos."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tang = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    normal = tang[0].orthogonal().normalized()
    aneis = []
    for i in range(n):
        t = tang[i]
        normal = (normal - t * normal.dot(t)).normalized()
        bi = t.cross(normal)
        r = raios[i]
        aneis.append([bm.verts.new(pts[i] + (normal * math.cos(a) + bi * math.sin(a)) * r) for a in (2 * math.pi * j / lados for j in range(lados))])
    for i in range(n - 1):
        a0, a1 = aneis[i], aneis[i + 1]
        for j in range(lados):
            bm.faces.new((a0[j], a0[(j + 1) % lados], a1[(j + 1) % lados], a1[j]))
    inicio = bm.verts.new(pts[0] - tang[0] * raios[0] * 0.5)
    fim = bm.verts.new(pts[-1] + tang[-1] * max(raios[-1], 0.01))
    for j in range(lados):
        bm.faces.new((inicio, aneis[0][(j + 1) % lados], aneis[0][j]))
        bm.faces.new((aneis[-1][j], aneis[-1][(j + 1) % lados], fim))


def chama(bm, base, direcao, curva, comp, grossura, gancho=0.35, n=26):
    """Ponta de chama: sai grossa, afina até virar uma ponta AFIADA e curva para um lado."""
    d = Vector(direcao).normalized()
    c = Vector(curva).normalized()
    pts, raios = [], []
    for i in range(n):
        f = i / (n - 1)
        p = Vector(base) + d * comp * f + c * comp * gancho * f * f
        pts.append(p)
        raios.append(grossura * (1 - f) ** 1.1 * (1 + 0.35 * math.sin(math.pi * f * 0.8)) + 0.004)
    tubo_liso(bm, pts, raios, lados=10)


def caracol_tubo(bm, centro, u, v, r0, voltas, grossura, n=50, encolher=0.08):
    """Espiral (o "@" das nuvens) como tubo afinando para dentro."""
    pts = espiral(Vector(centro), Vector(u).normalized(), Vector(v).normalized(), r0, voltas, n=n, encolher=encolher)
    raios = [grossura * (1 - 0.85 * i / (n - 1)) + 0.01 for i in range(n)]
    tubo_liso(bm, pts, raios, lados=10)


def tentaculo(bm, pts_guia, r0, r1=0.0, n=40):
    """Faixa fina que abraça o corpo e termina em ponta (catmull pelos pontos)."""
    pts = catmull(pts_guia, n)
    raios = [r0 + (r1 - r0) * (i / (n - 1)) ** 0.8 + 0.006 for i in range(n)]
    # bojo no começo: parece sair de dentro da nuvem
    raios = [r * (1 + 0.4 * math.exp(-((i / (n - 1)) / 0.15) ** 2)) for i, r in enumerate(raios)]
    tubo_liso(bm, pts, raios, lados=10)


def gotas(bm, rng, centro, raio, qtd):
    """Gotinhas soltas em forma de vírgula em volta da nuvem."""
    for _ in range(qtd):
        a = rng.uniform(0, 2 * math.pi)
        z = rng.uniform(-raio * 0.5, raio * 0.5)
        p = Vector(centro) + Vector((math.cos(a) * raio, math.sin(a) * raio * 0.4 - 0.3, z))
        d = Vector((rng.uniform(-1, 1), rng.uniform(-0.3, 0.3), rng.uniform(0.2, 1)))
        chama(bm, p, d, Vector((math.cos(a + 1.5), 0, math.sin(a))), rng.uniform(0.25, 0.4), rng.uniform(0.08, 0.11), gancho=0.6, n=14)


def corrente(vol, tubos, rng, guia_pts, r_max, fim="ponta", lado_fim=1.0, chamas=(), n=56, achatar=0.85, raiz=0.8):
    """Uma corrente de fumaça: nasce grossa no corpo, ondula, afina e termina em ponta comprida
    ou em espiral. O arco sobre a cabeça aparece da SOMA de várias correntes, não de uma peça.

    Volumes grandes e sobrepostos (elipsoides), sem bolhinhas: lisa, não parece espuma."""
    guia = catmull(guia_pts, n)
    ult = len(guia) - 1
    corte = 0.8  # daqui em diante a ponta é um tubo afiado
    fase = rng.uniform(0, 6.28)

    def raio(f):
        perfil = raiz + (1 - raiz) * suave(0.0, 0.25, f)  # sai do corpo e incha
        perfil *= 1 - 0.62 * suave(0.35, corte, f)  # afina para a ponta
        return r_max * perfil * (1 + 0.12 * math.sin(f * 7 + fase))  # ondulação lenta, irregular

    def tang(i):
        return (guia[min(i + 1, ult)] - guia[max(i - 1, 0)]).normalized()

    for i, p in enumerate(guia):
        f = i / ult
        if f > corte:
            break
        r = raio(f)
        vol.bola(p, r, achatar=(1.0, achatar, 1.0))
        if i % 3 == 1 and f < corte - 0.08:  # um volume a mais, deslocado: a faixa não é um cano
            t = tang(i)
            lado = t.cross(Vector((0, 1, 0))).normalized()
            vol.bola(p + lado * r * rng.uniform(-0.5, 0.5) + Vector((0, rng.uniform(-0.45, 0.1) * r, 0)), r * rng.uniform(0.72, 0.9), achatar=(1.0, achatar, 1.0))
    i0 = int(corte * ult)
    p0, t0, r0 = guia[i0], tang(i0), raio(corte)
    if fim == "espiral":
        # espiral que continua a direção da corrente e enrola para dentro
        u = -t0
        v = t0.cross(Vector((0, 1, 0))).normalized() * lado_fim
        centro = p0 + t0 * r0 * 0.4 - v * (r0 * 2.2)
        pts = [p0 - t0 * r0 * 0.6]
        pts += espiral(centro, v, t0, r0 * 2.2, 1.6, n=56, encolher=0.1)
        m = len(pts)
        raios = [r0 * 0.95 * (1 - 0.9 * (j / (m - 1)) ** 0.85) + 0.012 for j in range(m)]
        tubo_liso(tubos, pts, raios, lados=12)
    else:
        # ponta alongada: segue a curva e afina até ficar afiada, com um gancho leve
        resto = guia[i0:]
        comp = sum((resto[j + 1] - resto[j]).length for j in range(len(resto) - 1)) + r0 * 2.5
        lado = t0.cross(Vector((0, 1, 0))).normalized() * lado_fim
        pts, raios = [], []
        m = 30
        for j in range(m):
            f = j / (m - 1)
            pts.append(p0 - t0 * r0 * 0.5 + t0 * comp * f + lado * comp * 0.3 * f * f)
            raios.append(r0 * (1 - f) ** 1.25 + 0.004)
        tubo_liso(tubos, pts, raios, lados=12)
    for f, comp, sentido, g in chamas:  # pontas laterais saindo da borda
        i = int(f * ult)
        t = tang(i)
        fora = t.cross(Vector((0, 1, 0))).normalized() * sentido
        chama(tubos, guia[i] + fora * raio(f) * 0.45, fora * 0.8 + t * 0.6, t - fora * 0.3, comp * 1.15, g, gancho=1.15)
    return guia


def fazer_ombros(rng):
    """De onde a energia nasce: volumes grandes e sobrepostos nos ombros e no alto das costas."""
    vol = Volume("ombros")
    tubos = bmesh.new()
    for c, r, ach in (
        ((0.0, -0.8, 4.3), 0.75, (1.3, 0.7, 0.9)),
        ((1.2, -0.6, 4.55), 0.68, (1.2, 0.75, 0.9)),
        ((-1.25, -0.6, 4.6), 0.72, (1.2, 0.75, 0.9)),
        ((2.0, -0.4, 4.35), 0.55, (1.0, 0.85, 0.95)),
        ((-2.05, -0.4, 4.45), 0.6, (1.0, 0.85, 0.95)),
        ((0.65, -0.85, 5.05), 0.52, (1.1, 0.8, 1.0)),
        ((-0.7, -0.85, 5.1), 0.56, (1.1, 0.8, 1.0)),
        ((2.3, -0.3, 3.7), 0.45, (1.0, 0.85, 1.0)),
        ((-2.35, -0.3, 3.8), 0.48, (1.0, 0.85, 1.0)),
    ):
        vol.bola(c, r * rng.uniform(0.94, 1.06), achatar=ach)
    chama(tubos, (2.3, -0.3, 4.6), (0.7, 0, 1), (1, 0, -0.3), 0.75, 0.24, gancho=1.1)
    chama(tubos, (-2.4, -0.3, 4.7), (-0.7, 0, 1), (-1, 0, -0.3), 0.8, 0.26, gancho=1.1)
    return vol.malha(), tubos, Vector((0, -0.5, 4.2))


def fazer_corrente_a(rng):
    """A maior: sobe do ombro esquerdo, cruza por cima da cabeça e enrola no alto à direita."""
    vol, tubos = Volume("corrente_a"), bmesh.new()
    corrente(vol, tubos, rng, [(-1.2, -0.65, 4.4), (-2.0, -0.9, 5.15), (-1.85, -1.0, 6.05), (-0.85, -1.05, 6.65), (0.45, -1.0, 6.95), (1.55, -0.9, 6.85), (2.1, -0.8, 6.4)],
             1.05, fim="espiral", lado_fim=1.0, chamas=((0.4, 0.9, 1, 0.3), (0.62, 0.8, 1, 0.26)))
    return vol.malha(), tubos, Vector((-1.2, -0.65, 4.4))


def fazer_corrente_b(rng):
    """Sobe do ombro direito, passa por trás da A e termina numa ponta comprida no alto à esquerda."""
    vol, tubos = Volume("corrente_b"), bmesh.new()
    corrente(vol, tubos, rng, [(1.15, -0.65, 4.4), (1.95, -0.95, 5.15), (1.8, -1.15, 6.0), (0.9, -1.25, 6.5), (-0.3, -1.3, 6.85), (-1.2, -1.3, 7.45)],
             0.8, fim="ponta", lado_fim=-1.0, chamas=((0.45, 0.75, 1, 0.24),))
    return vol.malha(), tubos, Vector((1.15, -0.65, 4.4))


def fazer_corrente_c(rng):
    """Do meio das costas, sobe colada atrás da cabeça e solta uma espiral pequena."""
    vol, tubos = Volume("corrente_c"), bmesh.new()
    corrente(vol, tubos, rng, [(0.1, -0.85, 4.5), (0.35, -1.15, 5.4), (-0.15, -1.35, 6.15), (-0.75, -1.4, 6.6)],
             0.66, fim="espiral", lado_fim=-1.0)
    return vol.malha(), tubos, Vector((0.1, -0.85, 4.5))


def fazer_lateral_esq(rng):
    """Do ombro esquerdo para fora e para baixo, terminando em espiral (massa lateral)."""
    vol, tubos = Volume("lateral_esq"), bmesh.new()
    corrente(vol, tubos, rng, [(-1.6, -0.45, 4.3), (-2.35, -0.5, 4.0), (-2.7, -0.35, 3.3), (-2.55, -0.15, 2.7)],
             0.68, fim="espiral", lado_fim=1.0, chamas=((0.4, 0.65, -1, 0.22),))
    return vol.malha(), tubos, Vector((-1.6, -0.45, 4.3))


def fazer_lateral_dir(rng):
    """Do ombro direito para fora, terminando numa ponta alongada para baixo."""
    vol, tubos = Volume("lateral_dir"), bmesh.new()
    corrente(vol, tubos, rng, [(1.6, -0.45, 4.25), (2.4, -0.5, 4.05), (2.85, -0.4, 3.45), (3.05, -0.25, 2.65)],
             0.64, fim="ponta", lado_fim=1.0, chamas=((0.4, 0.6, 1, 0.2),))
    return vol.malha(), tubos, Vector((1.6, -0.45, 4.25))


def fazer_cintura(rng):
    """Correntes finas que saem da parte de baixo das costas e abraçam a cintura pela frente."""
    vol, tubos = Volume("cintura"), bmesh.new()
    vol.bola((0.0, -0.75, 2.45), 0.48, achatar=(1.4, 0.75, 0.9))
    corrente(vol, tubos, rng, [(0.2, -0.8, 2.45), (1.6, -0.5, 2.25), (1.85, 0.5, 2.0), (0.6, 1.05, 1.75), (-0.8, 1.0, 1.55), (-1.8, 0.4, 1.35)],
             0.3, fim="ponta", lado_fim=-1.0, raiz=1.0)
    corrente(vol, tubos, rng, [(-0.2, -0.8, 2.4), (-1.6, -0.45, 2.1), (-1.95, 0.4, 1.95), (-1.6, 0.6, 2.4)],
             0.34, fim="espiral", lado_fim=1.0, raiz=1.0)
    return vol.malha(), tubos, Vector((0, 0, 2.3))


def fazer_mecha(rng):
    """Gotinha/mecha que se solta e evapora (reaproveitada pelo jogo)."""
    vol = Volume("mecha")
    vol.bola((0, 0, 0), 0.16)
    tubos = bmesh.new()
    chama(tubos, (0, 0, 0), (0.3, 0, 1), (1, 0, 0), 0.45, 0.14, gancho=0.6, n=16)
    return vol.malha(), tubos, Vector((0, 0, 0))


def junta(destino, origem):
    me = bpy.data.meshes.new("tmp")
    origem.to_mesh(me)
    destino.from_mesh(me)
    bpy.data.meshes.remove(me)


# ---------------------------------------------------------------- cor e exportação


def suavizar(bm, passos, fator=0.5):
    """Alisa a superfície (tira o "caroço" das metaballs) sem mudar a forma geral."""
    for _ in range(passos):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=fator, use_axis_x=True, use_axis_y=True, use_axis_z=True)


def preparar(bm, alvo_tris):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
    suavizar(bm, 3)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    obj = bpy.data.objects.new("tmp", me)
    bpy.context.scene.collection.objects.link(obj)
    if len(me.polygons) > alvo_tris:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = alvo_tris / len(me.polygons)
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        obj.modifiers.clear()
        obj.data = me2
        bpy.data.meshes.remove(me)
        me = me2
    bm2 = bmesh.new()
    bm2.from_mesh(me)
    bmesh.ops.triangulate(bm2, faces=bm2.faces)
    suavizar(bm2, 1, 0.3)  # depois de reduzir: some com as quinas que a redução deixa
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    return bm2


def colorir(bm):
    """Sombreado de nuvem desenhada: núcleo creme na luz, lavanda nas sombras e dobras."""
    bm.normal_update()
    bvh = BVHTree.FromBMesh(bm)
    cores = {}
    for v in bm.verts:
        n = v.normal
        lambert = n.dot(LUZ)
        f = suave(-0.35, 0.75, lambert)
        cor = [SOMBRA[i] + (NUCLEO[i] - SOMBRA[i]) * f for i in range(3)]
        # borda (silhueta vista de frente) puxa para o branco-frio
        borda = 1 - abs(n.y)
        cor = [cor[i] + (BORDA[i] - cor[i]) * 0.35 * borda * f for i in range(3)]
        # dobras: oclusão simples — algo perto na direção da normal = cavidade
        oclusao = 0
        for d in (n, (n + Vector((0.4, 0, 0))).normalized(), (n + Vector((-0.4, 0, 0))).normalized(), (n + Vector((0, 0, 0.4))).normalized()):
            hit = bvh.ray_cast(v.co + d * 0.02, d, 0.45)
            if hit[0] is not None:
                oclusao += 1 - hit[3] / 0.45
        o = suave(0.35, 1.6, oclusao)
        cor = [cor[i] + (DOBRA[i] - cor[i]) * o * 0.7 for i in range(3)]
        cores[v.index] = tuple(min(max(c, 0), 1) for c in cor)
    return cores


def para_roblox(co):
    return (co.x, co.z - ALTURA_RAIZ, -co.y)


def escrever_luau(nome, bm, cores):
    bm.verts.ensure_lookup_table()
    pos = [para_roblox(v.co) for v in bm.verts]
    cor = [tuple(int(round(c * 255)) for c in cores[v.index]) for v in bm.verts]
    # (x, y, z) -> (x, z, -y) é rotação: a ordem dos vértices se mantém
    tris = [tuple(v.index for v in f.verts) for f in bm.faces]
    assert len(pos) < 65536, nome
    minimo = [min(p[i] for p in pos) for i in range(3)]
    maximo = [max(p[i] for p in pos) for i in range(3)]
    tamanho = [max(maximo[i] - minimo[i], 1e-4) for i in range(3)]
    dados = bytearray()
    for p in pos:
        dados += struct.pack("<3H", *(int(round((p[i] - minimo[i]) / tamanho[i] * 65535)) for i in range(3)))
    for c in cor:
        dados += struct.pack("<3B", *c)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    pedacos = [texto[i : i + 4000] for i in range(0, len(texto), 4000)]
    linhas = [
        "-- GERADO por assets/auras/gear5/source/generate_gear5.py. Não editar à mão.",
        "-- Peça da aura Gear 5: posições (uint16), cores (uint8) e triângulos (uint16) em base64.",
        "-- Vértices compartilhados entre faces: a nuvem é lisa (sem facetas).",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ]
    linhas += ['\t\t"%s",' % p for p in pedacos]
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, "gear5_" + nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(pos), len(tris)


def objeto(nome, bm, cores):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    camada = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    for i, c in cores.items():
        camada.data[i].color_srgb = (*c, 1.0)
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("gear5_" + nome, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# Como cada peça se move (o jogo lê isto em Gear5Pecas.luau):
#   osso:    membro que ela segue (raiz, tronco, cabeca, braco_dir, braco_esq)
#   rigidez: mola que segue o membro (alto = firme; baixo = atrasa mais)
#   atraso:  quanto pode ficar para trás ao andar (studs)
#   ordem:   quando surge na manifestação (0..1)
#   orbita:  graus que a peça vai e volta em volta do eixo do membro (o redemoinho "gira")
#   volta:   giro contínuo em volta do eixo do membro (rad/s; os punhos)
PECAS = [
    ("ombros", fazer_ombros, 3000, dict(osso="tronco", rigidez=120, atraso=0.15, ordem=0.0, respira=0.04, giro=3, orbita=0, volta=0, baixo=False)),
    ("lateral_esq", fazer_lateral_esq, 1500, dict(osso="tronco", rigidez=60, atraso=0.5, ordem=0.18, respira=0.05, giro=9, orbita=0, volta=0, baixo=False)),
    ("lateral_dir", fazer_lateral_dir, 1500, dict(osso="tronco", rigidez=62, atraso=0.5, ordem=0.22, respira=0.05, giro=9, orbita=0, volta=0, baixo=False)),
    ("corrente_c", fazer_corrente_c, 2000, dict(osso="tronco", rigidez=70, atraso=0.45, ordem=0.3, respira=0.05, giro=7, orbita=0, volta=0, baixo=False)),
    ("corrente_b", fazer_corrente_b, 3500, dict(osso="tronco", rigidez=50, atraso=0.65, ordem=0.38, respira=0.04, giro=6, orbita=0, volta=0, baixo=False)),
    ("corrente_a", fazer_corrente_a, 5000, dict(osso="tronco", rigidez=45, atraso=0.75, ordem=0.45, respira=0.04, giro=6, orbita=0, volta=0, baixo=False)),
    ("cintura", fazer_cintura, 2000, dict(osso="raiz", rigidez=45, atraso=0.7, ordem=0.6, respira=0.04, giro=3, orbita=10, volta=0, baixo=True)),
]


def escrever_pecas(lista):
    linhas = [
        "-- GERADO por assets/auras/gear5/source/generate_gear5.py. Não editar à mão.",
        "-- Peças da Gear 5 (studs, relativo ao HumanoidRootPart de um R15 padrão; o jogo reescala pela",
        "-- altura real). pivo = ponto por onde a peça se prende e gira; osso = membro que ela segue.",
        "return {",
        # escala: cabeça de um R15 padrão real fica ~1,5 stud acima da raiz. As peças são presas
        # ao CENTRO do membro (relOsso), então a diferença de proporção do avatar de blocos das
        # prévias não muda onde elas ficam.
        "\tcabecaPadrao = %.3f," % CABECA_R15,
        "\tossos = {",
    ]
    for nome, c in OSSOS.items():
        linhas.append("\t\t%s = { %.3f, %.3f, %.3f }," % ((nome,) + para_roblox(c)))
    linhas += ["\t},", "\tpecas = {"]
    for nome, pivo, cfg in lista:
        campos = ['nome = "%s"' % nome, "pivo = { %.3f, %.3f, %.3f }" % pivo]
        for k, v in cfg.items():
            if isinstance(v, bool):
                campos.append("%s = %s" % (k, "true" if v else "false"))
            elif isinstance(v, str):
                campos.append('%s = "%s"' % (k, v))
            else:
                campos.append("%s = %g" % (k, v))
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_LUAU, "Gear5Pecas.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(DIR_DADOS, exist_ok=True)
    # peças de versões anteriores não podem sobrar
    for antigo in os.listdir(DIR_DADOS):
        if antigo.startswith("gear5_"):
            os.remove(os.path.join(DIR_DADOS, antigo))
    for pasta in ("exports", "previews"):
        d = os.path.join(DIR_BASE, pasta)
        if os.path.isdir(d):
            for antigo in os.listdir(d):
                os.remove(os.path.join(d, antigo))
    os.makedirs(os.path.join(DIR_BASE, "exports"), exist_ok=True)
    lista = []
    objs = []
    for i, (nome, fn, alvo, cfg) in enumerate(PECAS + [("mecha", fazer_mecha, 200, None)]):
        rng = random.Random(500 + i)
        bm, tubos, pivo = fn(rng)
        bm = preparar(bm, alvo)
        junta(bm, tubos)  # tubos (chamas, caracóis, tentáculos) já são leves: não passam pela redução
        tubos.free()
        bmesh.ops.triangulate(bm, faces=bm.faces)
        cores = colorir(bm)
        nv, nt = escrever_luau(nome, bm, cores)
        print("%-10s %5d vértices %5d triângulos" % (nome, nv, nt))
        objs.append(objeto(nome, bm, cores))
        if cfg is not None:
            lista.append((nome, para_roblox(pivo), cfg))
    escrever_pecas(lista)
    for obj in objs:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(DIR_BASE, "exports", obj.name + ".fbx"),
            use_selection=True,
            axis_forward="-Z",
            axis_up="Y",
            apply_scale_options="FBX_SCALE_UNITS",
            colors_type="SRGB",
        )
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "gear5_clouds.blend"), compress=True)
    return objs


# ---------------------------------------------------------------- prévias (Cycles)


def material_nuvem():
    m = bpy.data.materials.new("nuvem")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.45  # aproxima o brilho leve do jogo
    bsdf.inputs["Roughness"].default_value = 0.9
    return m


def material_contorno():
    """Casca invertida: só aparece onde a face está de costas para a câmera (como no jogo,
    em que a MeshPart descarta as faces viradas para trás)."""
    m = bpy.data.materials.new("contorno")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    saida = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeMixShader")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    cor = nt.nodes.new("ShaderNodeEmission")
    cor.inputs["Color"].default_value = (0.36, 0.32, 0.6, 1)
    cor.inputs["Strength"].default_value = 0.8
    vazio = nt.nodes.new("ShaderNodeBsdfTransparent")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(cor.outputs[0], mix.inputs[1])
    nt.links.new(vazio.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], saida.inputs["Surface"])
    return m


def material_cor(nome, cor, emissao=0.0):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*cor, 1)
    if emissao:
        bsdf.inputs["Emission Color"].default_value = (*cor, 1)
        bsdf.inputs["Emission Strength"].default_value = emissao
    bsdf.inputs["Roughness"].default_value = 0.8
    m.use_backface_culling = True
    return m


def caixa(nome, centro, tam, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2])) + Vector(centro)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    obj = bpy.data.objects.new(nome, me)
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)


def avatar():
    """Avatar genérico (blocos com as proporções de um R15 padrão), só para escala nas prévias."""
    m = material_cor("avatar", (0.13, 0.13, 0.17))
    caixa("perna_e", (-0.5, 0, 1.0), (0.9, 0.9, 2.0), m)
    caixa("perna_d", (0.5, 0, 1.0), (0.9, 0.9, 2.0), m)
    caixa("tronco", (0, 0, 3.15), (2.0, 1.0, 2.3), m)
    caixa("braco_e", (-1.5, 0, 3.2), (0.95, 0.95, 2.2), m)
    caixa("braco_d", (1.5, 0, 3.2), (0.95, 0.95, 2.2), m)
    caixa("cabeca", (0, 0, 4.9), (1.2, 1.2, 1.2), m)


def renderizar(objs):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 48
    cena.cycles.device = "CPU"
    cena.render.resolution_x = 720
    cena.render.resolution_y = 900
    cena.view_settings.view_transform = "AgX"
    cena.view_settings.look = "AgX - Punchy"
    mundo = bpy.data.worlds.new("w")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.014, 0.035, 1)
    mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    cena.world = mundo
    mat = material_nuvem()
    contorno = material_contorno()
    for obj in objs:
        obj.data.materials.append(mat)
        if obj.name.endswith("mecha"):
            obj.hide_render = True
            continue
        # contorno de anime: casca invertida (o mesmo truque que o jogo usa)
        mod = obj.modifiers.new("contorno", "SOLIDIFY")
        mod.thickness = 0.045
        mod.offset = 1
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = 1
        obj.data.materials.append(contorno)
    avatar()
    chao = material_cor("chao", (0.05, 0.05, 0.08))
    caixa("chao", (0, 0, -0.05), (30, 30, 0.1), chao)
    luz = bpy.data.lights.new("chave", "SUN")
    luz.energy = 4.0
    luz.angle = 0.3
    ol = bpy.data.objects.new("chave", luz)
    ol.rotation_euler = (math.radians(50), 0, math.radians(200))
    cena.collection.objects.link(ol)
    preencher = bpy.data.lights.new("lavanda", "AREA")
    preencher.energy = 400
    preencher.size = 6
    preencher.color = (0.75, 0.7, 1.0)
    op = bpy.data.objects.new("lavanda", preencher)
    op.location = (-4, -6, 7)
    op.rotation_euler = (math.radians(-130), 0, math.radians(-30))
    cena.collection.objects.link(op)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    oc = bpy.data.objects.new("cam", cam)
    cena.collection.objects.link(oc)
    cena.camera = oc
    alvo = Vector((0, 0, 3.6))
    for nome, graus in (("front", 0), ("three_quarter", 45), ("side", 90), ("back", 180)):
        a = math.radians(graus)
        oc.location = alvo + Vector((math.sin(a) * 15.5, math.cos(a) * 15.5, 0.6))
        direcao = alvo - oc.location
        oc.rotation_euler = direcao.to_track_quat("-Z", "Y").to_euler()
        cena.render.filepath = os.path.join(DIR_BASE, "previews", nome + ".png")
        bpy.ops.render.render(write_still=True)
        print("prévia", nome)


if __name__ == "__main__":
    objs = gerar()
    if "--render" in sys.argv:
        renderizar(objs)
