"""Gera os drops do mapa (orbe de aura, lasca de fragmento, estrela cadente) no Blender.

Uso (Blender como módulo Python, testado com bpy 5.3):
    python assets/drops/source/generate_drops.py            # malhas e dados
    python assets/drops/source/generate_drops.py --render   # também a prévia

Cada drop tem duas camadas: "base" (material do jogo) e "brilho" (Neon). Tamanho ~2 studs, com a
origem no centro: o cliente faz o drop flutuar e girar.

Saídas:
    src/client/Mundo/Nexo3D/Dados/drop_*.luau    geometria (formato do kit do Nexo)
    src/shared/Dados/DropsVisual.luau            malhas de cada drop (gerado)
    assets/drops/previews/drops.jpg              render (NÃO é print do Roblox)
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
from mathutils import Vector  # noqa: E402

ARQ_VISUAL = os.path.join(RAIZ, "src", "shared", "Dados", "DropsVisual.luau")
DIR_PREV = os.path.join(RAIZ, "assets", "drops", "previews")

T, R, bx, montar = eq.T, eq.R, eq.bx, eq.montar
BRANCO = (1.0, 1.0, 1.0)


def esfera(raio, cor, lados=10, aneis=6):
    perfil = [(max(raio * math.sin(math.pi * k / aneis), 0.001), -raio * math.cos(math.pi * k / aneis)) for k in range(aneis + 1)]
    return kit.torno(perfil, lados, cor, random.Random(1), tinta=1.0)


def orbe():
    """Orbe de aura: núcleo menta facetado, casca de vidro e dois aros que se cruzam."""
    menta, claro = (0.42, 1.0, 0.72), (0.85, 1.0, 0.93)
    brilho = [esfera(0.42, menta, 8, 5)]
    base = []
    for giro in (R(70, "X"), R(90, "Z") @ R(70, "X")):
        aro = []
        n = 18
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n
            aro.append(bx((math.cos(a) * 0.72, math.sin(a) * 0.72, 0), (0.09, 2 * math.pi * 0.72 / n * 1.05, 0.06), claro, 0.0, R(math.degrees(a), "Z")))
        m = montar(aro)
        bmesh.ops.transform(m, matrix=giro, verts=m.verts[:])
        brilho.append(m)
    for k in range(4):
        a = math.pi / 2 * k + 0.4
        base.append(bx((math.cos(a) * 0.95, math.sin(a) * 0.95, 0.15 * (k % 2)), (0.12, 0.12, 0.12), (0.95, 1.0, 0.97), 0.0, R(45, "Z") @ R(35, "X")))
    return montar(base), montar(brilho)


def lasca():
    """Lasca de fragmento: três cristais violetas presos num pedaço de rocha."""
    rocha = (0.30, 0.27, 0.40)
    base = [kit.casco([(x * 0.5, y * 0.45, z * 0.3 - 0.75) for x, y, z in [(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0), (-0.7, -0.6, 1), (0.8, -0.5, 1.1), (0.6, 0.7, 0.9), (-0.6, 0.6, 1.2)]], rocha, 1.0)]
    brilho = [
        eq.cristal((0, 0, -0.6), 0.1, (0.72, 0.52, 1.0), 11),
        eq.cristal((0.32, 0.05, -0.62), 0.065, (0.80, 0.62, 1.0), 12, R(25, "Y")),
        eq.cristal((-0.3, -0.05, -0.62), 0.06, (0.66, 0.46, 1.0), 13, R(-28, "Y")),
    ]
    return montar(base), montar(brilho)


def estrela():
    """Estrela cadente: estrela de cinco pontas com volume, núcleo branco e cauda de faíscas."""
    ouro, claro = (1.0, 0.84, 0.36), (1.0, 0.97, 0.85)
    bm = kit.novo_bm()
    pts = []
    for k in range(10):
        a = math.pi / 2 + 2 * math.pi * k / 10
        r = 0.85 if k % 2 == 0 else 0.36
        pts.append((math.cos(a) * r, 0, math.sin(a) * r))
    frente = bm.verts.new((0, 0.22, 0))
    tras = bm.verts.new((0, -0.22, 0))
    anel = [bm.verts.new(p) for p in pts]
    for k in range(10):
        a, b = anel[k], anel[(k + 1) % 10]
        bm.faces.new((frente, a, b))
        bm.faces.new((tras, b, a))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    kit.pintar(bm, ouro, 1.0, topo_claro=0.25)
    brilho = [bm, bx((0, 0, 0), (0.28, 0.5, 0.28), claro, 0.04, R(45, "Y"))]
    base = []
    for k in range(5):
        d = 0.9 + 0.32 * k
        s = 0.16 - 0.022 * k
        base.append(bx((0.35 + 0.12 * k, -0.05, -d * 0.8), (s, s, s), claro, 0.0, R(45, "Y") @ R(35, "X")))
    return montar(base), montar(brilho)


DROPS = [("orbe", orbe, "Glass"), ("lasca", lasca, "Slate"), ("estrela", estrela, "SmoothPlastic")]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    materiais = {"base": kit.criar_material("Drop_Base", rugosidade=0.4), "brilho": kit.criar_material("Drop_Brilho", emissao=5.0)}
    linhas = ["-- GERADO por assets/drops/source/generate_drops.py. Não editar à mão.", "-- Malhas de cada drop do mapa (origem no centro).", "return {"]
    objetos = {}
    total = 0
    for nome, fn, material in DROPS:
        b, l = fn()
        camadas = []
        for camada, bm, mat in (("base", b, material), ("brilho", l, "Neon")):
            if len(bm.faces) == 0:
                continue
            id_ = "drop_%s%s" % (nome, "" if camada == "base" else "_brilho")
            obj = kit.registrar(id_, bm, materiais[camada])
            objetos[id_] = obj
            total += eq.escrever_malha(id_, obj)
            camadas.append('{ malha = "%s", material = "%s" }' % (id_, mat))
        linhas.append("\t%s = { %s }," % (nome, ", ".join(camadas)))
    linhas += ["}", ""]
    with open(ARQ_VISUAL, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    print("triângulos:", total)
    if "--render" in sys.argv:
        renderizar(objetos)


def renderizar(objetos):
    os.makedirs(DIR_PREV, exist_ok=True)
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 64
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 1200, 460
    cena.render.image_settings.file_format = "JPEG"
    cena.view_settings.view_transform = "Standard"
    mundo = bpy.data.worlds.new("Estudio")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.09, 0.07, 0.16, 1)
    cena.world = mundo
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, -1.6))
    for i, (nome, _, _) in enumerate(DROPS):
        for camada in ("", "_brilho"):
            o = objetos.get("drop_%s%s" % (nome, camada))
            if o:
                if o.name not in cena.collection.objects:
                    cena.collection.objects.link(o)
                o.location = ((i - 1) * 3.0, 0, 0)
                o.rotation_euler = (0, 0, math.radians(-20))
    bpy.ops.object.light_add(type="AREA", location=(3, -6, 6))
    luz = bpy.context.object
    luz.data.size = 8
    luz.data.energy = 900
    luz.rotation_euler = (Vector((0, 0, 0)) - luz.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(0, -10.5, 1.8))
    cam = bpy.context.object
    cam.rotation_euler = (Vector((0, 0, -0.1)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    cena.camera = cam
    cena.render.filepath = os.path.join(DIR_PREV, "drops.jpg")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
