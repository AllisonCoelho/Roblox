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

A forma vem de curvas Catmull-Rom (nada de círculos): um arco ABERTO e assimétrico atrás e acima
da cabeça, lobos grandes, pontas que terminam em caracol, bancos na cintura e cachos desenhados
(espirais em relevo) na superfície. As cores por vértice já trazem o sombreado lavanda.
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

# Paleta (sRGB 0..1) — tabela 2.3 do briefing
NUCLEO = (1.0, 0.992, 0.988)  # FFFDFC
BORDA = (0.961, 0.949, 1.0)  # F5F2FF
SOMBRA = (0.796, 0.776, 0.914)  # CBC6E9
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


ARCO_GUIA = [
    (1.25, -0.3, 3.55),  # nasce atrás do ombro direito e desce largo (lado "varrido")
    (2.15, -0.55, 4.45),
    (2.4, -0.95, 5.6),
    (1.7, -1.25, 6.7),
    (0.35, -1.4, 7.25),
    (-1.0, -1.3, 7.0),
    (-1.95, -1.0, 6.25),
    (-2.2, -0.6, 5.35),
    (-1.75, -0.3, 4.7),  # do lado esquerdo termina mais alto, perto do ombro
]
CENTRO_ARCO = Vector((-0.1, -1.0, 5.1))

# Lobos (bolhas grandes) ao longo do arco: posição na curva, raio e quanto saem para fora.
# Tamanhos e espaçamentos desiguais de propósito: não é colar de contas.
LOBOS_ARCO = [(0.14, 0.5, 0.15), (0.27, 0.72, 0.3), (0.41, 0.62, 0.2), (0.5, 0.9, 0.42), (0.6, 0.66, 0.25), (0.71, 0.85, 0.38), (0.86, 0.55, 0.18)]
# Línguas da borda externa: (posição, comprimento, para que lado do arco enrolam)
LINGUAS_ARCO = [(0.2, 0.7, -1), (0.36, 0.75, -1), (0.56, 0.7, 1), (0.7, 0.65, 1)]
CACHOS_ARCO = [(0.24, 0.34), (0.37, 0.42), (0.5, 0.48), (0.64, 0.44), (0.77, 0.38)]


def fora_do_arco(p):
    f = p - CENTRO_ARCO
    f.y = 0
    return f.normalized()


def fazer_arco(rng):
    vol = Volume("arco")
    guia = catmull(ARCO_GUIA, 70)
    ultimo = len(guia) - 1

    def em(f):
        i = int(round(f * ultimo))
        tang = (guia[min(i + 1, ultimo)] - guia[max(i - 1, 0)]).normalized()
        return guia[i], tang, fora_do_arco(guia[i])

    # miolo contínuo e achatado em profundidade (a faixa é larga de frente, fina de lado)
    for i, p in enumerate(guia):
        f = i / ultimo
        if f < 0.07 or f > 0.94:
            continue  # as pontas são peças próprias
        r = 0.5 + 0.16 * math.sin(f * 7.3 + 1.1) + 0.1 * rng.uniform(-1, 1)
        vol.bola(p, r, achatar=(1.0, 0.95, 1.0))
        if i % 3 == 1:  # volume para trás: de perfil a faixa tem espessura
            vol.bola(p + Vector((0, -r * 0.7, 0)), r * 0.75)
        if i % 2 == 0:  # dobras internas (lado do avatar), menores
            vol.bola(p - fora_do_arco(p) * r * 0.5 + Vector((0, -0.15, 0)), r * 0.6)
    for f, r, saida in LOBOS_ARCO:
        p, tang, fora = em(f)
        r *= rng.uniform(0.92, 1.08)
        vol.bola(p + fora * saida + Vector((0, rng.uniform(-0.35, 0.25), 0)), r, achatar=(1.0, 0.9, 1.0))
        # bolhas menores na borda do lobo: contorno recortado
        for k in range(3):
            ang = rng.uniform(-1.2, 1.2)
            d = (fora * math.cos(ang) + tang * math.sin(ang)).normalized()
            vol.bola(p + fora * saida + d * r * rng.uniform(0.7, 0.95), r * rng.uniform(0.35, 0.5))
    for f, comp, sentido in LINGUAS_ARCO:
        p, tang, fora = em(f)
        lingua(vol, p + fora * 0.5, fora + tang * 0.45 * sentido, tang * sentido, comp, 0.46)
    for f, tam in CACHOS_ARCO:
        p, tang, fora = em(f)
        normal = (fora * 0.35 + Vector((0, 1, 0))).normalized()  # cacho olhando para a frente
        cacho(vol, p + normal * 0.42 + fora * 0.15, normal, tam, rng)
    return vol.malha(), Vector((0, -0.8, 4.3))


def fazer_lobo(rng, lado):
    """Massa grande que incha para fora do arco, no alto de um dos lados."""
    vol = Volume("lobo")
    if lado > 0:
        c = Vector((2.85, -0.8, 4.85))
        bolas = [((0, 0, 0), 0.62), ((0.38, 0.05, 0.38), 0.46), ((0.22, -0.1, -0.45), 0.5), ((0.62, 0.0, -0.08), 0.4), ((-0.25, -0.1, 0.5), 0.42)]
    else:
        c = Vector((-2.55, -0.75, 6.35))
        bolas = [((0, 0, 0), 0.68), ((-0.42, 0.05, 0.32), 0.5), ((-0.2, -0.15, -0.48), 0.52), ((-0.66, 0.0, -0.12), 0.4), ((0.22, 0.05, 0.55), 0.45), ((-0.38, 0.05, 0.72), 0.34)]
    for d, r in bolas:
        vol.bola(c + Vector(d), r * rng.uniform(0.92, 1.08), achatar=(1.0, 0.8, 1.0))
    normal = Vector((lado * 0.5, 1, 0.15)).normalized()
    cacho(vol, c + Vector((lado * 0.1, 0.5, 0.1)), normal, 0.36, rng)
    lingua(vol, c + Vector((lado * 0.55, 0, 0.35)), Vector((lado, 0, 0.7)), Vector((0, 0, 1)), 1.0, 0.3)
    lingua(vol, c + Vector((lado * 0.5, 0, -0.45)), Vector((lado, 0, -0.4)), Vector((0, 0, -1)), 0.75, 0.24)
    return vol.malha(), c - Vector((lado * 0.55, 0, 0))


def fazer_ponta(rng, lado):
    """Ponta do arco: afunila e termina num caracol grande, enrolado para dentro."""
    vol = Volume("ponta")
    if lado > 0:
        base = Vector(ARCO_GUIA[0]) + Vector((0.15, 0, 0.0))
        centro = base + Vector((0.75, 0.1, -0.6))
    else:
        base = Vector(ARCO_GUIA[-1]) + Vector((-0.05, 0, 0.05))
        centro = base + Vector((-0.6, 0.1, -0.5))
    u = Vector((-lado, 0, 0))
    v = Vector((0, 0.3, 1)).normalized()
    vol.bola(base, 0.45)
    vol.bola(base + Vector((lado * 0.3, -0.1, -0.15)), 0.38)
    n = 30
    grande = 0.85 if lado > 0 else 0.55  # o caracol do lado varrido é o maior
    for i, p in enumerate(espiral(centro, u, v, grande, 1.4, n=n, encolher=0.18)):
        f = i / (n - 1)
        vol.bola(p, max(grande * 0.52 * (1 - 0.78 * f ** 0.8), 0.09))
    return vol.malha(), base


def fazer_banco(rng, lado):
    """Banco denso atrás do quadril e da cintura, com borda recortada; os pés ficam à mostra."""
    vol = Volume("banco")
    guia = catmull(
        [(lado * 0.3, -0.85, 3.05), (lado * 1.1, -0.95, 2.8), (lado * 1.7, -0.85, 2.35), (lado * 1.95, -0.65, 1.9), (lado * 1.8, -0.45, 1.6)],
        22,
    )
    for i, p in enumerate(guia):
        f = i / (len(guia) - 1)
        r = (0.55 - 0.22 * f) * rng.uniform(0.85, 1.12) * (1.0 if lado < 0 else 0.85)
        vol.bola(p, r, achatar=(1.0, 0.8, 0.9))
        if i % 3 == 0:
            vol.bola(p + Vector((lado * 0.3, -0.15, rng.uniform(-0.2, 0.3))), r * 0.62)
    cacho(vol, guia[7] + Vector((lado * 0.05, 0.42, 0.1)), Vector((lado * 0.3, 1, 0.1)), 0.32, rng)
    cacho(vol, guia[15] + Vector((lado * 0.15, 0.36, 0)), Vector((lado * 0.5, 1, 0)), 0.24, rng)
    lingua(vol, guia[-1], Vector((lado * 0.6, 0.3, -0.3)), Vector((lado, 0, 0.8)), 0.75, 0.26)
    lingua(vol, guia[4] + Vector((0, 0, 0.3)), Vector((lado * 0.4, 0, 1)), Vector((lado, 0, 0)), 0.7, 0.24)
    return vol.malha(), Vector((lado * 0.4, -0.6, 2.9))


def fazer_rolo(rng, lado):
    """Rolo lateral pequeno perto do ombro, ligado visualmente ao arco."""
    vol = Volume("rolo")
    c = Vector((lado * 1.7, -0.3, 4.05))
    for d, r in (((0, 0, 0), 0.36), ((lado * 0.28, -0.1, 0.22), 0.3), ((lado * 0.1, 0.05, -0.28), 0.28)):
        vol.bola(c + Vector(d), r)
    cacho(vol, c + Vector((lado * 0.15, 0.3, 0)), Vector((lado * 0.5, 1, 0)), 0.22, rng)
    lingua(vol, c + Vector((lado * 0.3, 0, -0.2)), Vector((lado, 0, -0.5)), Vector((0, 0, -1)), 0.6, 0.2)
    return vol.malha(), c - Vector((lado * 0.35, -0.25, 0))


def fazer_mecha(rng):
    """Mecha pequena que se solta no rastro e evapora (reaproveitada pelo jogo)."""
    vol = Volume("mecha")
    n = 18
    for i, p in enumerate(espiral(Vector((0, 0, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.34, 1.2, n=n, encolher=0.2)):
        vol.bola(p, max(0.2 * (1 - 0.6 * i / (n - 1)), 0.09))
    return vol.malha(), Vector((0, 0, 0))


def junta(destino, origem):
    me = bpy.data.meshes.new("tmp")
    origem.to_mesh(me)
    destino.from_mesh(me)
    bpy.data.meshes.remove(me)


# ---------------------------------------------------------------- cor e exportação


def preparar(bm, alvo_tris):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
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
        f = suave(-0.05, 0.6, lambert)
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


# grupo: como a peça se move (o jogo lê isto em Gear5Pecas.luau)
#   rigidez: mola que segue o corpo (alto = acompanha firme; baixo = atrasa mais)
#   atraso:  quanto a peça pode ficar para trás ao andar (studs)
#   ordem:   quando surge na manifestação (0..1)
PECAS = [
    ("arco", lambda r: fazer_arco(r), 9000, dict(rigidez=90, atraso=0.35, ordem=0.15, respira=0.03, giro=4, baixo=False)),
    ("lobo_dir", lambda r: fazer_lobo(r, 1), 2200, dict(rigidez=55, atraso=0.6, ordem=0.42, respira=0.05, giro=8, baixo=False)),
    ("lobo_esq", lambda r: fazer_lobo(r, -1), 2400, dict(rigidez=50, atraso=0.65, ordem=0.48, respira=0.05, giro=8, baixo=False)),
    ("ponta_dir", lambda r: fazer_ponta(r, 1), 1800, dict(rigidez=38, atraso=0.9, ordem=0.55, respira=0.04, giro=16, baixo=False)),
    ("ponta_esq", lambda r: fazer_ponta(r, -1), 1800, dict(rigidez=34, atraso=0.95, ordem=0.6, respira=0.04, giro=16, baixo=False)),
    ("rolo_dir", lambda r: fazer_rolo(r, 1), 900, dict(rigidez=45, atraso=0.7, ordem=0.66, respira=0.05, giro=12, baixo=False)),
    ("rolo_esq", lambda r: fazer_rolo(r, -1), 900, dict(rigidez=45, atraso=0.7, ordem=0.7, respira=0.05, giro=12, baixo=False)),
    ("banco_dir", lambda r: fazer_banco(r, 1), 2600, dict(rigidez=30, atraso=1.1, ordem=0.72, respira=0.04, giro=6, baixo=True)),
    ("banco_esq", lambda r: fazer_banco(r, -1), 2600, dict(rigidez=28, atraso=1.15, ordem=0.78, respira=0.04, giro=6, baixo=True)),
]


def escrever_pecas(lista):
    linhas = [
        "-- GERADO por assets/auras/gear5/source/generate_gear5.py. Não editar à mão.",
        "-- Peças da Gear 5 em volta do personagem (studs, relativo ao HumanoidRootPart de um R15",
        "-- padrão; o jogo reescala pela altura real). pivo = ponto por onde a peça se prende e gira.",
        "return {",
    ]
    for nome, pivo, cfg in lista:
        campos = ['nome = "%s"' % nome, "pivo = { %.3f, %.3f, %.3f }" % pivo]
        for k, v in cfg.items():
            campos.append("%s = %s" % (k, ("true" if v else "false") if isinstance(v, bool) else ("%g" % v)))
        linhas.append("\t{ " + ", ".join(campos) + " },")
    linhas += ["}", ""]
    with open(os.path.join(DIR_LUAU, "Gear5Pecas.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(DIR_DADOS, exist_ok=True)
    os.makedirs(os.path.join(DIR_BASE, "exports"), exist_ok=True)
    lista = []
    objs = []
    for i, (nome, fn, alvo, cfg) in enumerate(PECAS + [("mecha", lambda r: fazer_mecha(r), 500, None)]):
        rng = random.Random(500 + i)
        bm, pivo = fn(rng)
        bm = preparar(bm, alvo)
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
    bsdf.inputs["Emission Strength"].default_value = 0.6  # aproxima o brilho leve do jogo
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
    """Avatar genérico (blocos de um R15 padrão), só para escala nas prévias."""
    m = material_cor("avatar", (0.13, 0.13, 0.17))
    caixa("perna_e", (-0.5, 0, 1.0), (0.9, 0.9, 2.0), m)
    caixa("perna_d", (0.5, 0, 1.0), (0.9, 0.9, 2.0), m)
    caixa("tronco", (0, 0, 3.0), (2.0, 1.0, 2.0), m)
    caixa("braco_e", (-1.5, 0, 3.0), (0.95, 0.95, 2.0), m)
    caixa("braco_d", (1.5, 0, 3.0), (0.95, 0.95, 2.0), m)
    caixa("cabeca", (0, 0, 4.6), (1.2, 1.2, 1.2), m)


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
        mod.thickness = 0.035
        mod.offset = 1
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = 1
        obj.data.materials.append(contorno)
    avatar()
    chao = material_cor("chao", (0.05, 0.05, 0.08))
    caixa("chao", (0, 0, -0.05), (30, 30, 0.1), chao)
    luz = bpy.data.lights.new("chave", "SUN")
    luz.energy = 3.0
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
    alvo = Vector((0, 0, 3.9))
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
