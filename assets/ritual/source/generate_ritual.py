"""Malhas da Roleta de Ecos (etapa nova do giro de aura). Testado com bpy 5.3.

Uso:
    python assets/ritual/source/generate_ritual.py            # Dados/ritual_*.luau + .blend
    python assets/ritual/source/generate_ritual.py --render   # também a prévia (Blender, não Roblox)

Mesmo formato compacto das auras (src/client/Mundo/Auras/Dados, lidas por MalhaNuvem): o jogo
monta as MeshParts sozinho, sem importação no Studio. Vértices claros com leve degradê: a cor de
cada cristal vem da MeshPart (a cor de uma aura sorteada para girar na roleta).
Modeladas em eixos ROBLOX (y = cima, frente = -Z).
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
DIR_BASE = os.path.join(RAIZ, "assets", "ritual")
DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Auras", "Dados")


def V(x, y, z):
    return Vector((x, -z, y))


def para_roblox(v):
    return (v.x, v.z, -v.y)


def cristal(bm, centro, eixo, comp_cima, comp_baixo, raio, lados, rng, torcer=0.0):
    e = Vector(eixo).normalized()
    a = e.orthogonal().normalized()
    b = e.cross(a)
    c = Vector(centro)
    meio = []
    for i in range(lados):
        t = 2 * math.pi * i / lados + torcer
        r = raio * rng.uniform(0.85, 1.1)
        meio.append(bm.verts.new(V(*(c + a * math.cos(t) * r + b * math.sin(t) * r))))
    # anel do "ombro": o cristal afina em dois estágios (facetas a mais)
    ombro = []
    for i in range(lados):
        t = 2 * math.pi * (i + 0.5) / lados + torcer
        r = raio * 0.55
        ombro.append(bm.verts.new(V(*(c + e * comp_cima * 0.55 + a * math.cos(t) * r + b * math.sin(t) * r))))
    topo = bm.verts.new(V(*(c + e * comp_cima)))
    base = bm.verts.new(V(*(c - e * comp_baixo)))
    for i in range(lados):
        j = (i + 1) % lados
        bm.faces.new((meio[i], meio[j], ombro[i]))
        bm.faces.new((ombro[i], meio[j], ombro[j]))
        bm.faces.new((ombro[i], ombro[j], topo))
        bm.faces.new((meio[j], meio[i], base))


def ritual_eco(bm):
    """Cristal-eco: um prisma principal alongado e dois menores encostados (lê bem de longe)."""
    rng = random.Random(7)
    cristal(bm, (0, 0, 0), (0, 1, 0), 1.0, 0.55, 0.26, 6, rng)
    cristal(bm, (0.2, -0.2, 0.05), (0.55, 1, 0.1), 0.5, 0.2, 0.12, 5, rng, 0.3)
    cristal(bm, (-0.18, -0.25, -0.06), (-0.5, 1, -0.15), 0.38, 0.15, 0.1, 5, rng, 0.7)


def ritual_ponteiro(bm):
    """Ponteiro da roleta: losango apontando para baixo com duas asas, fica acima do cristal sorteado."""
    rng = random.Random(3)
    cristal(bm, (0, 0, 0), (0, -1, 0), 0.7, 0.25, 0.18, 4, rng, math.pi / 4)
    for s in (-1, 1):
        cristal(bm, (s * 0.32, 0.12, 0), (s * 1, 0.35, 0), 0.32, 0.08, 0.07, 4, rng)


PECAS = {"ritual_eco": ritual_eco, "ritual_ponteiro": ritual_ponteiro}


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
        # degradê: base um pouco mais escura, ponta quase branca
        t = (p[1] - minimo[1]) / tamanho[1]
        v = int(170 + 85 * t)
        dados += struct.pack("<3B", v, v, v)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    linhas = [
        "-- GERADO por assets/ritual/source/generate_ritual.py. Não editar à mão.",
        "-- Malha da Roleta de Ecos (giro de aura): a cor vem da MeshPart.",
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
    for nome, fn in PECAS.items():
        bm = bmesh.new()
        fn(bm)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
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
    """Prévia: 8 cristais em roda (cores de auras) e o ponteiro sobre o da frente."""
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 32
    cena.render.resolution_x, cena.render.resolution_y = 900, 600
    mundo = bpy.data.worlds.new("w")
    mundo.node_tree if False else None
    cena.world = mundo
    mundo.color = (0.02, 0.015, 0.05)
    cores = ["FFF1A8", "B8F2FF", "FF9EC1", "B79CFF", "7FD8FF", "FFC46B", "9EE7FF", "FF7A7A"]

    def mat(h, forca):
        c = tuple((int(h[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))
        m = bpy.data.materials.new(h)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*c, 1)
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = forca
        return m

    eco = objs["ritual_eco"]
    eco.hide_render = True
    for k, h in enumerate(cores):
        a = 2 * math.pi * k / len(cores)
        o = bpy.data.objects.new("eco%d" % k, eco.data.copy())
        o.data.materials.append(mat(h, 6 if k == 0 else 2.5))
        o.location = (math.sin(a) * 4.5, -math.cos(a) * 4.5, 3 + 0.3 * math.sin(a * 2))
        o.rotation_euler = (0.2, 0, a)
        s = 1.35 if k == 0 else 1.0
        o.scale = (s, s, s)
        cena.collection.objects.link(o)
    p = objs["ritual_ponteiro"]
    p.data.materials.append(mat("FFFFFF", 5))
    p.location = (0, -4.5, 5.2)
    cam = bpy.data.cameras.new("c")
    oc = bpy.data.objects.new("c", cam)
    oc.location = (0, -14, 7)
    oc.rotation_euler = (Vector((0, 0, 3)) - oc.location).to_track_quat("-Z", "Y").to_euler()
    cena.collection.objects.link(oc)
    cena.camera = oc
    cena.render.filepath = os.path.join(DIR_BASE, "previews", "roleta.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "ritual_roleta.blend"), compress=True)
