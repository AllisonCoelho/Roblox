"""Gera a coroa do Rei do Servidor no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/arena/source/generate_coroa.py            # malhas e dados
    python assets/arena/source/generate_coroa.py --render   # também a prévia

Coroa original no estilo blocado: aro dourado de oito faces com cinco pontas, cada ponta com um
cristal violeta do Nexo, e a pedra grande na frente. Flutua um pouco acima da cabeça (o jogo a faz
girar devagar). Duas camadas: "base" (ouro) e "brilho" (cristais em Neon). Origem no centro do aro.

Saídas:
    src/client/Mundo/Nexo3D/Dados/coroa_*.luau   geometria (formato do kit do Nexo)
    src/shared/Dados/CoroaVisual.luau            malhas da coroa (gerado)
    assets/arena/previews/coroa.jpg              render (NÃO é print do Roblox)
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

import generate_nexo as kit  # noqa: E402
import generate_equipamento as eq  # noqa: E402
from mathutils import Vector  # noqa: E402

T, R, bx, montar = eq.T, eq.R, eq.bx, eq.montar
ARQ_VISUAL = os.path.join(RAIZ, "src", "shared", "Dados", "CoroaVisual.luau")
DIR_PREV = os.path.join(RAIZ, "assets", "arena", "previews")
OURO = (1.0, 0.78, 0.30)
OURO_ESCURO = (0.78, 0.52, 0.16)
VIOLETA = (0.75, 0.55, 1.0)
RUBI = (1.0, 0.35, 0.50)


def coroa():
    base, brilho = [], []
    n, raio = 8, 0.62
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        comp = 2 * math.pi * raio / n * 1.08
        x, y = math.cos(a) * raio, math.sin(a) * raio
        base.append(bx((x, y, 0), (0.12, comp, 0.34), OURO, 0.03, R(math.degrees(a), "Z")))
        base.append(bx((x * 1.04, y * 1.04, -0.15), (0.06, comp, 0.08), OURO_ESCURO, 0.0, R(math.degrees(a), "Z")))
    for k in range(5):
        a = math.pi / 2 + 2 * math.pi * k / 5
        x, y = math.cos(a) * raio, math.sin(a) * raio
        alto = 0.62 if k == 0 else 0.48
        base.append(eq.ponta((x, y, 0.12), (x * 0.96, y * 0.96, 0.12 + alto), 0.2, OURO))
        brilho.append(eq.cristal((x * 1.02, y * 1.02, 0.12 + alto * 0.55), 0.028, VIOLETA, 50 + k))
    # pedra grande na frente (+Y) e pedrinhas no aro
    brilho.append(bx((0, raio + 0.07, 0.02), (0.2, 0.06, 0.2), RUBI, 0.02, R(45, "Y")))
    for k in range(n):
        if k in (1, 2):
            continue
        a = 2 * math.pi * k / n
        brilho.append(bx((math.cos(a) * (raio + 0.065), math.sin(a) * (raio + 0.065), 0.02), (0.08, 0.04, 0.08), VIOLETA, 0.0, R(math.degrees(a) + 90, "Z") @ R(45, "Y")))
    return montar(base), montar(brilho)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = {"base": kit.criar_material("Coroa", rugosidade=0.3, metalico=0.6), "brilho": kit.criar_material("CoroaBrilho", emissao=5.0)}
    b, l = coroa()
    objetos = {}
    linhas = ["-- GERADO por assets/arena/source/generate_coroa.py. Não editar à mão.", "-- Malhas da coroa do Rei do Servidor (origem no centro do aro).", "return {"]
    for nome, bm, material, chave in (("coroa_base", b, "Metal", "base"), ("coroa_brilho", l, "Neon", "brilho")):
        obj = kit.registrar(nome, bm, mat[chave])
        objetos[nome] = obj
        eq.escrever_malha(nome, obj)
        linhas.append('\t{ malha = "%s", material = "%s" },' % (nome, material))
    linhas += ["}", ""]
    with open(ARQ_VISUAL, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    if "--render" in sys.argv:
        os.makedirs(DIR_PREV, exist_ok=True)
        cena = bpy.context.scene
        cena.render.engine = "CYCLES"
        cena.cycles.samples = 64
        cena.cycles.use_denoising = True
        cena.render.resolution_x, cena.render.resolution_y = 700, 520
        cena.render.image_settings.file_format = "JPEG"
        cena.view_settings.view_transform = "Standard"
        mundo = bpy.data.worlds.new("E")
        mundo.use_nodes = True
        mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.09, 0.07, 0.16, 1)
        cena.world = mundo
        for o in objetos.values():
            cena.collection.objects.link(o)
        bpy.ops.object.light_add(type="AREA", location=(2, 3, 3))
        luz = bpy.context.object
        luz.data.size = 4
        luz.data.energy = 300
        luz.rotation_euler = (Vector((0, 0, 0)) - luz.location).to_track_quat("-Z", "Y").to_euler()
        bpy.ops.object.camera_add(location=(1.2, 3.4, 1.4))
        cam = bpy.context.object
        cam.rotation_euler = (Vector((0, 0, 0.2)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 50
        cena.camera = cam
        cena.render.filepath = os.path.join(DIR_PREV, "coroa.jpg")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
