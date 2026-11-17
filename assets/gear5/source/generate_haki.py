"""Malhas do Haki do Rei da Gear 5 (raios, onda de pressão e rachaduras). Testado com bpy 5.3.

Uso:
    python assets/gear5/source/generate_haki.py            # Dados/haki_*.luau + .blend
    python assets/gear5/source/generate_haki.py --render   # também a prévia (Blender, não Roblox)

Formato compacto lido por MalhaNuvem (src/client/Mundo/Auras/Dados): o jogo monta as MeshParts
sozinho. Vértices em tons de cinza: a cor final vem da MeshPart (preto do haki ou vermelho do brilho).
Modelado em eixos ROBLOX (y = cima, frente = -Z). Desenho próprio, inspirado na linguagem visual
de "raios negros com faísca vermelha" dos animes de luta; nada copiado de frames ou assets.
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

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
DIR_BASE = os.path.join(RAIZ, "assets", "gear5")
DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Auras", "Dados")


def V(x, y, z):  # Roblox -> Blender
    return Vector((x, -z, y))


def para_roblox(v):
    return (v.x, v.z, -v.y)


# ------------------------------------------------------------------ raio
def caminho_raio(rng, inicio, direcao, comprimento, passos, desvio):
    """Polilinha em zigue-zague (ângulos duros, cara de anime)."""
    d = Vector(direcao).normalized()
    a = d.orthogonal().normalized()
    b = d.cross(a)
    pts = [Vector(inicio)]
    for i in range(1, passos + 1):
        t = i / passos
        base = Vector(inicio) + d * comprimento * t
        amp = desvio * (1 - t * 0.35) * (0 if i == passos else 1)
        pts.append(base + a * rng.uniform(-amp, amp) + b * rng.uniform(-amp, amp))
    return pts


def tubo(bm, pts, r0, r1, lados=3):
    """Prisma fino ao longo da polilinha, afinando de r0 até r1 (ponta quase zero)."""
    aneis = []
    n = len(pts)
    for i, p in enumerate(pts):
        if i < n - 1:
            d = (pts[i + 1] - p).normalized()
        else:
            d = (p - pts[i - 1]).normalized()
        a = d.orthogonal().normalized()
        b = d.cross(a)
        r = r0 + (r1 - r0) * (i / (n - 1))
        anel = []
        for k in range(lados):
            ang = 2 * math.pi * k / lados
            anel.append(bm.verts.new(V(*(p + a * math.cos(ang) * r + b * math.sin(ang) * r))))
        aneis.append(anel)
    for i in range(n - 1):
        for k in range(lados):
            j = (k + 1) % lados
            bm.faces.new((aneis[i][k], aneis[i][j], aneis[i + 1][j], aneis[i + 1][k]))
    bm.faces.new(list(reversed(aneis[0])))
    bm.faces.new(aneis[-1])


def raio(semente):
    def gerar(bm):
        rng = random.Random(semente)
        # tronco de 4 studs ao longo de +X; o jogo estica até o comprimento desejado
        tronco = caminho_raio(rng, (0, 0, 0), (1, 0, 0), 4.0, 9, 0.38)
        tubo(bm, tronco, 0.11, 0.015)
        for _ in range(2):
            i = rng.randint(2, 5)
            dirr = Vector((1, rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9)))
            galho = caminho_raio(rng, tronco[i], dirr, rng.uniform(1.0, 1.7), 4, 0.22)
            tubo(bm, galho, 0.06, 0.01)
    return gerar


# ------------------------------------------------------------------ onda de pressão
def haki_onda(bm):
    """Anel achatado de raio 1 com borda externa em dentes irregulares (choque de pressão)."""
    rng = random.Random(11)
    n = 48
    dentes = [1.0 + (0.16 if i % 2 == 0 else 0.0) + rng.uniform(-0.04, 0.06) for i in range(n)]
    # duas camadas (cima e baixo, 0,02 de distância): visível dos dois lados sem faces repetidas
    for altura, frente in ((0.0, True), (-0.02, False)):
        interno, externo = [], []
        for i in range(n):
            ang = 2 * math.pi * i / n
            c, s = math.cos(ang), math.sin(ang)
            interno.append(bm.verts.new(V(c * 0.78, altura, s * 0.78)))
            externo.append(bm.verts.new(V(c * dentes[i], altura + 0.04, s * dentes[i])))
        for i in range(n):
            j = (i + 1) % n
            if frente:
                bm.faces.new((interno[i], interno[j], externo[j], externo[i]))
            else:
                bm.faces.new((externo[i], externo[j], interno[j], interno[i]))


# ------------------------------------------------------------------ rachaduras no chão
def fita(bm, pts, largura0, largura1):
    """Faixa achatada no plano XZ ao longo da polilinha (levemente afundada no centro)."""
    n = len(pts)
    esq, dir_ = [], []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        d.y = 0
        d.normalize()
        lado = Vector((-d.z, 0, d.x))
        w = largura0 + (largura1 - largura0) * (i / (n - 1))
        esq.append(bm.verts.new(V(*(p + lado * w))))
        dir_.append(bm.verts.new(V(*(p - lado * w))))
    for i in range(n - 1):
        bm.faces.new((esq[i], esq[i + 1], dir_[i + 1], dir_[i]))


def haki_rachadura(bm):
    rng = random.Random(23)
    braços = 9
    for k in range(braços):
        ang = 2 * math.pi * k / braços + rng.uniform(-0.2, 0.2)
        comp = rng.uniform(0.7, 1.0)
        pts = [Vector((math.cos(ang) * 0.12, 0.02, math.sin(ang) * 0.12))]
        a = ang
        for i in range(1, 6):
            a += rng.uniform(-0.45, 0.45)
            r = 0.12 + comp * i / 5
            pts.append(Vector((math.cos(a) * r, 0.02, math.sin(a) * r)))
        fita(bm, pts, 0.05, 0.004)
        # ramificação curta
        i0 = rng.randint(2, 3)
        b = a + rng.choice((-1, 1)) * rng.uniform(0.5, 0.9)
        p0 = pts[i0]
        galho = [p0, p0 + Vector((math.cos(b) * 0.16, 0, math.sin(b) * 0.16)),
                 p0 + Vector((math.cos(b + 0.2) * 0.3, 0, math.sin(b + 0.2) * 0.3))]
        fita(bm, galho, 0.025, 0.003)
    # cratera central (anel achatado)
    n = 14
    dentro, fora = [], []
    for i in range(n):
        ang = 2 * math.pi * i / n
        r = 0.14 + rng.uniform(-0.02, 0.02)
        dentro.append(bm.verts.new(V(math.cos(ang) * 0.05, 0.03, math.sin(ang) * 0.05)))
        fora.append(bm.verts.new(V(math.cos(ang) * r, 0.02, math.sin(ang) * r)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((dentro[i], dentro[j], fora[j], fora[i]))


PECAS = {
    "haki_raio_a": raio(1),
    "haki_raio_b": raio(5),
    "haki_raio_c": raio(9),
    "haki_onda": haki_onda,
    "haki_rachadura": haki_rachadura,
}


def escrever_luau(nome, bm):
    bm.verts.ensure_lookup_table()
    pos = [para_roblox(v.co) for v in bm.verts]
    tris = [tuple(v.index for v in f.verts) for f in bm.faces]
    minimo = [min(p[i] for p in pos) for i in range(3)]
    maximo = [max(p[i] for p in pos) for i in range(3)]
    tamanho = [max(maximo[i] - minimo[i], 1e-4) for i in range(3)]
    dados = bytearray()
    for p in pos:
        dados += struct.pack("<3H", *(int(round((p[i] - minimo[i]) / tamanho[i] * 65535)) for i in range(3)))
    for p in pos:
        # quase branco: a MeshPart decide a cor (preto do haki ou vermelho do brilho)
        dados += struct.pack("<3B", 245, 245, 245)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    linhas = [
        "-- GERADO por assets/gear5/source/generate_haki.py. Não editar à mão.",
        "-- Haki do Rei da Gear 5: a cor vem da MeshPart.",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ] + ['\t\t"%s",' % texto[i: i + 4000] for i in range(0, len(texto), 4000)] + ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(pos), len(tris)


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = {}
    for nome, fn in PECAS.items():
        bm = bmesh.new()
        fn(bm)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        nv, nt = escrever_luau(nome, bm)
        print("%-16s %4d vértices %4d triângulos" % (nome, nv, nt))
        me = bpy.data.meshes.new(nome)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(nome, me)
        bpy.context.scene.collection.objects.link(o)
        objs[nome] = o
    return objs


def renderizar(objs):
    """Prévia: rachadura no chão, onda de pressão e raios negros com brilho vermelho em volta."""
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 48
    cena.view_settings.view_transform = "Standard"
    cena.render.resolution_x, cena.render.resolution_y = 1100, 700
    mundo = bpy.data.worlds.new("w")
    cena.world = mundo
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs[0].default_value = (0.03, 0.01, 0.02, 1)

    def mat(nome, cor, emissao):
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*cor, 1)
        b.inputs["Emission Color"].default_value = (*cor, 1)
        b.inputs["Emission Strength"].default_value = emissao
        return m

    preto = mat("preto", (0.01, 0.0, 0.01), 0)
    vermelho = mat("vermelho", (0.9, 0.0, 0.03), 2.2)
    roxo = mat("roxo", (0.25, 0.0, 0.08), 0.8)

    chao = bpy.data.meshes.new("chao")
    bmc = bmesh.new()
    bmesh.ops.create_grid(bmc, x_segments=1, y_segments=1, size=12)
    bmc.to_mesh(chao)
    oc = bpy.data.objects.new("chao", chao)
    oc.data.materials.append(mat("pedra", (0.18, 0.15, 0.2), 0))
    cena.collection.objects.link(oc)

    for nome in objs:
        objs[nome].hide_render = True
    r = objs["haki_rachadura"].copy()
    r.data = r.data.copy()
    r.data.materials.append(preto)
    r.scale = (5, 5, 1)
    r2 = r.copy()
    r2.data = r.data.copy()
    r2.data.materials[0] = vermelho
    r2.scale = (5.15, 5.15, 1)
    r2.location = (0, 0, -0.01)
    cena.collection.objects.link(r2)
    r.hide_render = False
    cena.collection.objects.link(r)
    o = objs["haki_onda"].copy()
    o.data = o.data.copy()
    o.data.materials.append(roxo)
    o.scale = (4, 4, 4)
    o.location = (0, 0, 0.6)
    o.hide_render = False
    cena.collection.objects.link(o)

    # corpo simples no centro (só referência de escala)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=3.2, location=(0, 0, 1.6))
    bpy.context.object.data.materials.append(mat("corpo", (0.95, 0.95, 0.95), 1.5))

    rng = random.Random(4)
    for k in range(8):
        nome = ("haki_raio_a", "haki_raio_b", "haki_raio_c")[k % 3]
        ang = 2 * math.pi * k / 8 + rng.uniform(-0.2, 0.2)
        for material, escala in ((vermelho, 1.6), (preto, 1.0)):
            b = objs[nome].copy()
            b.data = b.data.copy()
            b.data.materials.append(material)
            s = rng.uniform(0.8, 1.2) if escala == 1.0 else None
            b.scale = (1.0, escala * 1.4, escala * 1.4) if escala > 1 else (1.0, 1.0, 1.0)
            b.location = (0, 0, 1.9)
            b.rotation_euler = (rng.uniform(-0.5, 0.5), rng.uniform(-0.6, 0.3), ang)
            b.hide_render = False
            cena.collection.objects.link(b)

    cam = bpy.data.cameras.new("c")
    ocam = bpy.data.objects.new("c", cam)
    ocam.location = (0, -13, 7.5)
    ocam.rotation_euler = (Vector((0, 0, 1.2)) - ocam.location).to_track_quat("-Z", "Y").to_euler()
    cena.collection.objects.link(ocam)
    cena.camera = ocam
    cena.render.filepath = os.path.join(DIR_BASE, "previews", "haki_rei.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "haki_rei.blend"), compress=True)
