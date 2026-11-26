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


def cabeca(cor):
    # cubo arredondado 1.2 (a cabeça clássica do boneco)
    return montar([bx((0, 0, 0), (1.2, 1.2, 1.2), cor, 0.16)])


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
    return montar(partes)


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
    # laço
    partes.append(esfera((0.45, -0.3, 0.72), 0.16, hexa("B7FFD9")))
    return montar(partes)


MALHAS = {
    "boneco_cabeca_tita": lambda: cabeca(hexa("FFF6E8")),
    "boneco_cabeca_lume": lambda: cabeca(hexa("FFDCC4")),
    "boneco_cabelo_nuvem": cabelo_nuvem,
    "boneco_cabelo_longo": cabelo_longo,
}


# ============================================================ prévia (mesmas peças do cliente)

def face(defn, cabeca_c, cor_pele):
    """Rosto feito de discos, como no cliente: olhos, anéis, boca e bochechas."""
    x0, y0, z0 = cabeca_c
    f = y0 + 0.61
    out = []
    escuro = hexa("2A1A10")
    def disco(cx, cz, d, cor, dy=0.0):
        return eq.cilindro((x0 + cx, f + dy, z0 + cz), d / 2, 0.04, cor, 16, R(90, "X"))
    for lado in (-1, 1):
        if defn["olhos"] == "aneis":
            out.append(disco(lado * 0.25, 0.1, 0.44, hexa(defn["corOlhos"]), -0.005))
            out.append(disco(lado * 0.25, 0.1, 0.32, hexa("FFFFFF"), 0.0))
            out.append(disco(lado * 0.25, 0.1, 0.16, escuro, 0.005))
        else:
            out.append(disco(lado * 0.24, 0.08, 0.26, hexa(defn["corOlhos"]), 0.0))
            out.append(disco(lado * 0.24, 0.0, 0.3, escuro, -0.004))
        out.append(disco(lado * 0.24 + 0.05, 0.16, 0.08, hexa("FFFFFF"), 0.01))
        if defn.get("bochechas"):
            out.append(disco(lado * 0.42, -0.15, 0.16, hexa("FF9E9E"), 0.0))
    if defn["boca"] == "sorrisao":
        # sorrisão em blocos: boca escura, dentes em cima e língua embaixo
        out.append(bx((x0, f, z0 - 0.24), (0.52, 0.04, 0.24), hexa("6A1E1E"), 0.0))
        out.append(bx((x0, f + 0.006, z0 - 0.15), (0.48, 0.04, 0.07), hexa("FFFFFF"), 0.0))
        out.append(bx((x0, f + 0.006, z0 - 0.32), (0.26, 0.04, 0.07), hexa("FF7A8A"), 0.0))
    else:
        out.append(bx((x0, f, z0 - 0.24), (0.3, 0.04, 0.06), hexa("6A1E1E"), 0.0))
    return out


def boneco(defn, x, escala):
    """Boneco inteiro na escala 1 (pés em z = 0), deslocado em x; depois escalado."""
    pele, camisa, calca = hexa(defn["pele"]), hexa(defn["camisa"]), hexa(defn["calca"])
    p = []
    p.append(bx((0.5, 0, 1), (1, 1, 2), calca, 0.02))
    p.append(bx((-0.5, 0, 1), (1, 1, 2), calca, 0.02))
    p.append(bx((0, 0, 3), (2, 1, 2), camisa, 0.02))
    p.append(bx((1.5, 0, 3), (1, 1, 2), pele, 0.02))
    p.append(bx((-1.5, 0, 3), (1, 1, 2), pele, 0.02))
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
    pai = bpy.data.objects.new("raiz_" + defn["id"], None)
    for o in objs:
        o.parent = pai
    pai.scale = (escala, escala, escala)
    pai.location = (x, 0, 0)
    return [pai] + objs


DEFS = {
    "tita": dict(id="tita", pele="FFF6E8", camisa="FFFFFF", calca="FFFFFF", olhos="aneis", corOlhos="FFD54A", boca="sorrisao",
                 bochechas=True, cabeca="boneco_cabeca_tita", cabelo="boneco_cabelo_nuvem", extras=["faixa", "gola", "aureola"]),
    "lume": dict(id="lume", pele="FFDCC4", camisa="C0ADFF", calca="F7F2EC", olhos="redondos", corOlhos="5B3FB0", boca="sorriso",
                 bochechas=True, cabeca="boneco_cabeca_lume", cabelo="boneco_cabelo_longo", extras=["capa", "estrela"]),
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
    # 2) Lume de perto
    c = cena((0.75, 0.7, 0.95))
    for o in boneco(DEFS["lume"], 0, 1) + boneco(DEFS["jogador"], 4.4, 1):
        c.collection.objects.link(o)
    foto(c, "lume_boneco.jpg", (6.5, 12, 4.4), (2.0, 0, 3.0))


if __name__ == "__main__":
    main()
