"""Gera a Lume, Guardiã do Nexo (a guia do tutorial), no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/tutorial/source/generate_lume.py            # malhas e dados
    python assets/tutorial/source/generate_lume.py --render   # também o retrato

Personagem original, no estilo blocado do Roblox: busto (cabeça e ombros), capuz lilás com
ponta, olhos grandes de luz menta, um cristal do Nexo flutuando sobre a cabeça e um aro de
energia nos ombros. As peças que mexem ficam separadas para o jogo animar no retrato:
    lume_corpo     capuz, cabeça, ombros (fixo)
    lume_brilho    cristal, aro e detalhes de luz (Neon)
    lume_olhos     os dois olhos (o jogo achata para piscar)
    lume_boca      a boca (o jogo abre e fecha enquanto ela fala)
Origem no centro da cabeça; +Y (Blender) é a frente.

Saídas:
    src/client/Mundo/Nexo3D/Dados/lume_*.luau   geometria (formato do kit do Nexo)
    src/shared/Dados/LumeVisual.luau            peças, material e papel de cada uma (gerado)
    assets/tutorial/previews/lume.jpg           render (NÃO é print do Roblox)
"""

import math
import os
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

T, R, bx, montar = eq.T, eq.R, eq.bx, eq.montar
ARQ_VISUAL = os.path.join(RAIZ, "src", "shared", "Dados", "LumeVisual.luau")
DIR_PREV = os.path.join(RAIZ, "assets", "tutorial", "previews")

PELE = (0.98, 0.84, 0.70)
CAPUZ = (0.62, 0.50, 0.95)
CAPUZ_ESCURO = (0.38, 0.28, 0.66)
FORRO = (0.20, 0.14, 0.36)
MENTA = (0.55, 1.0, 0.85)
OURO = (1.0, 0.80, 0.35)


def corpo():
    p = [
        # cabeça
        bx((0, 0, 0), (1.2, 1.2, 1.2), PELE, 0.08),
        # bochechas
        bx((-0.36, 0.605, -0.22), (0.2, 0.02, 0.1), (1.0, 0.68, 0.70), 0.0),
        bx((0.36, 0.605, -0.22), (0.2, 0.02, 0.1), (1.0, 0.68, 0.70), 0.0),
        # franja
        bx((0, 0.5, 0.5), (1.24, 0.26, 0.26), (0.30, 0.22, 0.52), 0.05),
        bx((-0.42, 0.52, 0.32), (0.34, 0.22, 0.3), (0.30, 0.22, 0.52), 0.05, R(-12, "Y")),
        bx((0.4, 0.52, 0.36), (0.3, 0.22, 0.24), (0.30, 0.22, 0.52), 0.05, R(10, "Y")),
        # capuz: casca em volta da cabeça, aberta na frente
        bx((0, -0.08, 0.74), (1.5, 1.4, 0.28), CAPUZ, 0.08),
        bx((-0.74, -0.05, 0.05), (0.2, 1.36, 1.5), CAPUZ, 0.08),
        bx((0.74, -0.05, 0.05), (0.2, 1.36, 1.5), CAPUZ, 0.08),
        bx((0, -0.72, 0.05), (1.5, 0.2, 1.5), CAPUZ_ESCURO, 0.08),
        bx((0, 0.66, 0.74), (1.5, 0.1, 0.12), CAPUZ_ESCURO, 0.03),
        # ponta do capuz caindo para trás
        bx((0, -0.95, 0.55), (0.8, 0.5, 0.5), CAPUZ, 0.08, R(-25, "X")),
        bx((0, -1.25, 0.25), (0.46, 0.38, 0.4), CAPUZ_ESCURO, 0.06, R(-40, "X")),
        # pescoço e ombros (manto)
        bx((0, 0, -0.72), (0.5, 0.5, 0.3), PELE, 0.03),
        bx((0, -0.05, -1.18), (2.1, 1.1, 0.75), CAPUZ, 0.1),
        bx((0, 0.52, -1.05), (0.95, 0.12, 0.5), FORRO, 0.03),
        bx((0, -0.05, -0.86), (1.7, 1.0, 0.2), CAPUZ_ESCURO, 0.06),
        # fecho dourado
        bx((0, 0.6, -0.92), (0.26, 0.08, 0.26), OURO, 0.03, R(45, "Y")),
    ]
    return montar(p)


def brilho():
    p = [
        eq.cristal((0, 0, 1.35), 0.075, (0.70, 0.95, 1.0), 77),
        eq.cristal((0.34, -0.05, 1.22), 0.035, MENTA, 78, R(25, "Y")),
        eq.cristal((-0.32, -0.05, 1.24), 0.032, (0.80, 0.70, 1.0), 79, R(-25, "Y")),
        bx((0, 0.66, -0.92), (0.12, 0.04, 0.12), MENTA, 0.0, R(45, "Y")),
        bx((0, 0.6, 0.6), (0.14, 0.04, 0.14), MENTA, 0.0, R(45, "Y")),
    ]
    # aro de energia nos ombros
    n = 24
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        comp = 2 * math.pi * 1.25 / n * 1.06
        p.append(bx((math.cos(a) * 1.25, math.sin(a) * 0.85, -0.78), (0.06, comp, 0.05), MENTA, 0.0, R(math.degrees(a), "Z")))
    return montar(p)


def olhos():
    p = []
    for x in (-0.27, 0.27):
        p.append(bx((x, 0.605, 0.02), (0.2, 0.03, 0.36), (0.10, 0.08, 0.20), 0.02))
        p.append(bx((x, 0.62, 0.04), (0.15, 0.02, 0.3), MENTA, 0.0))
        p.append(bx((x + 0.03, 0.635, 0.12), (0.06, 0.02, 0.08), (1, 1, 1), 0.0))
    return montar(p)


def boca():
    return montar([
        bx((0, 0.61, -0.3), (0.26, 0.03, 0.1), (0.42, 0.12, 0.22), 0.02),
        bx((0, 0.618, -0.33), (0.14, 0.02, 0.04), (1.0, 0.55, 0.60), 0.0),
    ])


PECAS = [("corpo", corpo, "SmoothPlastic", "corpo"), ("brilho", brilho, "Neon", "brilho"), ("olhos", olhos, "SmoothPlastic", "olhos"), ("boca", boca, "SmoothPlastic", "boca")]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = {"base": kit.criar_material("Lume", rugosidade=0.55), "brilho": kit.criar_material("LumeBrilho", emissao=5.0)}
    linhas = ["-- GERADO por assets/tutorial/source/generate_lume.py. Não editar à mão.", "-- Peças da Lume (guia do tutorial): malha, material e papel na animação do retrato.", "return {"]
    objetos = {}
    total = 0
    for nome, fn, material, papel in PECAS:
        id_ = "lume_" + nome
        obj = kit.registrar(id_, fn(), mat["brilho" if material == "Neon" else "base"])
        objetos[id_] = obj
        total += eq.escrever_malha(id_, obj)
        linhas.append('\t{ malha = "%s", material = "%s", papel = "%s" },' % (id_, material, papel))
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
    cena.render.resolution_x, cena.render.resolution_y = 900, 700
    cena.render.image_settings.file_format = "JPEG"
    cena.view_settings.view_transform = "Standard"
    mundo = bpy.data.worlds.new("Estudio")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.08, 0.18, 1)
    mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.2
    cena.world = mundo
    for o in objetos.values():
        cena.collection.objects.link(o)
        o.rotation_euler = (0, 0, math.radians(18))
    bpy.ops.object.light_add(type="AREA", location=(3, 5, 4))
    luz = bpy.context.object
    luz.data.size = 5
    luz.data.energy = 500
    luz.rotation_euler = (Vector((0, 0, 0)) - luz.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="AREA", location=(-4, -2, 3))
    l2 = bpy.context.object
    l2.data.size = 4
    l2.data.energy = 250
    l2.data.color = (0.7, 0.6, 1.0)
    l2.rotation_euler = (Vector((0, 0, 0)) - l2.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(location=(1.4, 7.4, 0.5))
    cam = bpy.context.object
    cam.rotation_euler = (Vector((0, 0, 0.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    cena.camera = cam
    cena.render.filepath = os.path.join(DIR_PREV, "lume.jpg")
    bpy.ops.render.render(write_still=True)
    # retrato com fundo transparente, enquadrado como no jogo (para os mocks da interface)
    for o in objetos.values():
        o.rotation_euler = (0, 0, 0)
    cena.render.film_transparent = True
    cena.render.resolution_x, cena.render.resolution_y = 300, 340
    cena.render.image_settings.file_format = "PNG"
    cena.render.image_settings.color_mode = "RGBA"
    cam.location = (0.6, 6.2, 0.25)
    cam.rotation_euler = (Vector((0, 0, 0.05)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(34)
    cena.render.filepath = os.path.join(DIR_PREV, "lume_retrato.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
