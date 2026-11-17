"""Malhas dos efeitos de combate das Incursões (testado com bpy 5.3).

Uso:
    python assets/combate/source/generate_fx.py            # Dados/fx_*.luau + .blend
    python assets/combate/source/generate_fx.py --render   # também a prévia (Blender, não Roblox)

As peças vão no mesmo formato compacto das auras (src/client/Mundo/Auras/Dados, lidas por
MalhaNuvem): o jogo monta as MeshParts sozinho, sem importação no Studio. Vértices brancos: a cor
de cada efeito vem da MeshPart (cor da aura ou da Gear 5).

Modeladas direto em eixos ROBLOX (y = cima, frente = -Z). Escala 1 = tamanho base em studs.
"""

import base64
import math
import os
import struct
import sys

import bpy

import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
DIR_BASE = os.path.join(RAIZ, "assets", "combate")
DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Auras", "Dados")


def V(x, y, z):
    return Vector((x, -z, y))


def para_roblox(v):
    return (v.x, v.z, -v.y)


def tubo(bm, pts, raios, lados=10, achatar=1.0):
    pts = [Vector(p) for p in pts]
    aneis, anterior = [], None
    for k, p in enumerate(pts):
        t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        n = t.orthogonal().normalized() if anterior is None else (anterior - t * anterior.dot(t)).normalized()
        anterior = n
        b = t.cross(n)
        r = raios[k] if isinstance(raios, (list, tuple)) else raios
        aneis.append([bm.verts.new(V(*(p + n * math.cos(a) * r + b * math.sin(a) * r * achatar))) for a in [2 * math.pi * i / lados for i in range(lados)]])
    for k in range(len(aneis) - 1):
        for i in range(lados):
            j = (i + 1) % lados
            bm.faces.new((aneis[k][i], aneis[k][j], aneis[k + 1][j], aneis[k + 1][i]))
    for anel, ponta, ultimo in ((aneis[0], pts[0], False), (aneis[-1], pts[-1], True)):
        c = bm.verts.new(V(*ponta))
        for i in range(lados):
            j = (i + 1) % lados
            bm.faces.new((anel[i], anel[j], c) if ultimo else (anel[j], anel[i], c))


def esfera(bm, centro, raio, escala=(1, 1, 1), sub=2):
    t = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in t["verts"]:
        d = v.co.copy()
        v.co = V(centro[0] + d.x * raio * escala[0], centro[1] + d.z * raio * escala[1], centro[2] + d.y * raio * escala[2])
    return t["verts"]


# ---------------------------------------------------------------- peças


def fx_corte(bm):
    """Meia-lua de corte: arco de 160° na frente do corpo, grossa no meio e afiada nas pontas."""
    n = 28
    pts, raios = [], []
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(-80 + 160 * t)
        pts.append((math.sin(a) * 3.0, 0.15 * math.sin(math.pi * t), -math.cos(a) * 3.0 + 1.2))
        raios.append(0.02 + 0.32 * math.sin(math.pi * t) ** 1.4)
    tubo(bm, pts, raios, lados=8, achatar=0.22)


def fx_punho(bm):
    """Punho de desenho: palma arredondada, 4 nós dos dedos e polegar. Aponta para -Z."""
    esfera(bm, (0, 0, 0.05), 0.55, (1.0, 0.85, 0.9))
    for k in range(4):
        x = -0.36 + 0.24 * k
        esfera(bm, (x, 0.12 + 0.04 * (k in (1, 2)), -0.45), 0.2, (1, 1.1, 1.1), sub=2)
        esfera(bm, (x, -0.12, -0.38), 0.17, (1, 1, 1), sub=1)
    tubo(bm, [(0.5, -0.05, 0.1), (0.58, -0.15, -0.2), (0.4, -0.22, -0.4)], [0.17, 0.15, 0.12], lados=8)
    tubo(bm, [(0, 0, 0.4), (0, 0, 0.9)], [0.38, 0.32], lados=10)  # pulso


def fx_esfera(bm):
    """Esfera de energia com espinhos (núcleo + 12 pontas)."""
    esfera(bm, (0, 0, 0), 1.0, sub=2)
    fi = (1 + 5 ** 0.5) / 2
    pontas = [(0, 1, fi), (0, -1, fi), (0, 1, -fi), (0, -1, -fi), (1, fi, 0), (-1, fi, 0), (1, -fi, 0), (-1, -fi, 0), (fi, 0, 1), (-fi, 0, 1), (fi, 0, -1), (-fi, 0, -1)]
    for p in pontas:
        d = Vector(p).normalized()
        tubo(bm, [tuple(d * 0.85), tuple(d * 1.25), tuple(d * 1.7)], [0.32, 0.16, 0.01], lados=6)


def fx_onda(bm):
    """Cone aberto de onda de choque: estreito atrás (z = 0), largo na frente (-Z)."""
    n, lados = 10, 24
    aneis = []
    for k in range(n):
        t = k / (n - 1)
        z = -3.0 * t
        r = 0.6 + 2.6 * t ** 0.8
        esp = 0.12 * (1 - t) + 0.03
        anel_ext = [bm.verts.new(V(math.cos(a) * r, math.sin(a) * r * 0.75, z)) for a in [2 * math.pi * i / lados for i in range(lados)]]
        anel_int = [bm.verts.new(V(math.cos(a) * (r - esp), math.sin(a) * (r - esp) * 0.75, z + esp)) for a in [2 * math.pi * i / lados for i in range(lados)]]
        aneis.append((anel_ext, anel_int))
    for k in range(n - 1):
        for i in range(lados):
            j = (i + 1) % lados
            e0, i0 = aneis[k]
            e1, i1 = aneis[k + 1]
            bm.faces.new((e0[i], e0[j], e1[j], e1[i]))
            bm.faces.new((i1[i], i1[j], i0[j], i0[i]))
    for anel in (aneis[0], aneis[-1]):
        e, i_ = anel
        for i in range(lados):
            j = (i + 1) % lados
            bm.faces.new((e[j], e[i], i_[i], i_[j]) if anel is aneis[0] else (e[i], e[j], i_[j], i_[i]))


def fx_impacto(bm):
    """Estrela de impacto de desenho (8 pontas irregulares), de frente para +Z."""
    pontas = 8
    cima, baixo = [], []
    for i in range(pontas * 2):
        a = math.pi * i / pontas
        r = (1.0 if i % 4 == 0 else 0.75) if i % 2 == 0 else 0.32
        cima.append(bm.verts.new(V(math.cos(a) * r, math.sin(a) * r, 0.06)))
        baixo.append(bm.verts.new(V(math.cos(a) * r, math.sin(a) * r, -0.06)))
    cc, cb = bm.verts.new(V(0, 0, 0.12)), bm.verts.new(V(0, 0, -0.12))
    m = len(cima)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((cima[i], cima[j], cc))
        bm.faces.new((baixo[j], baixo[i], cb))
        bm.faces.new((cima[j], cima[i], baixo[i], baixo[j]))


PECAS = {"fx_corte": fx_corte, "fx_punho": fx_punho, "fx_esfera": fx_esfera, "fx_onda": fx_onda, "fx_impacto": fx_impacto}


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
    for _ in pos:
        dados += struct.pack("<3B", 255, 255, 255)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    linhas = [
        "-- GERADO por assets/combate/source/generate_fx.py. Não editar à mão.",
        "-- Malha de efeito de combate das Incursões (vértices brancos: a cor vem da MeshPart).",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ] + ['\t\t"%s",' % texto[i : i + 4000] for i in range(0, len(texto), 4000)] + ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(pos), len(tris)


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(os.path.join(DIR_BASE, "source"), exist_ok=True)
    os.makedirs(os.path.join(DIR_BASE, "previews"), exist_ok=True)
    objs = {}
    for k, (nome, fn) in enumerate(PECAS.items()):
        bm = bmesh.new()
        fn(bm)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        nv, nt = escrever_luau(nome, bm)
        print("%-12s %5d vértices %5d triângulos" % (nome, nv, nt))
        me = bpy.data.meshes.new(nome)
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
        o = bpy.data.objects.new(nome, me)
        o.location = (k * 5.0 - 10, 0, 2)
        bpy.context.scene.collection.objects.link(o)
        objs[nome] = o
    return objs


def renderizar(objs):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 24
    cena.render.resolution_x, cena.render.resolution_y = 1400, 420
    mundo = bpy.data.worlds.new("w")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.02, 0.05, 1)
    cena.world = mundo
    cores = [(0.8, 0.6, 1.0), (1, 1, 1), (0.6, 0.8, 1.0), (1.0, 0.7, 0.9), (1.0, 0.9, 0.5)]
    for (nome, o), c in zip(objs.items(), cores):
        m = bpy.data.materials.new(nome)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*c, 1)
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = 0.0 if nome == "fx_punho" else 2.5
        o.data.materials.append(m)
        o.rotation_euler = (0.3, 0, 0.6)
    luz = bpy.data.lights.new("l", "AREA")
    luz.energy = 1500
    luz.size = 10
    ol = bpy.data.objects.new("l", luz)
    ol.location = (0, -10, 10)
    ol.rotation_euler = (Vector((0, 0, 2)) - ol.location).to_track_quat("-Z", "Y").to_euler()
    cena.collection.objects.link(ol)
    cam = bpy.data.cameras.new("c")
    cam.type = "ORTHO"
    cam.ortho_scale = 27
    oc = bpy.data.objects.new("c", cam)
    oc.location = (0, -20, 3)
    oc.rotation_euler = (math.radians(87), 0, 0)
    cena.collection.objects.link(oc)
    cena.camera = oc
    cena.render.filepath = os.path.join(DIR_BASE, "previews", "fx.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "fx_combate.blend"), compress=True)
