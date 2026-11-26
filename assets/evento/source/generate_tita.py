"""Gera o Titã de Borracha (chefe do evento Despertar do Sol) no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/evento/source/generate_tita.py            # malhas e dados
    python assets/evento/source/generate_tita.py --render   # também as prévias

Personagem original no estilo cartoon de borracha: corpo redondo cor creme, cabelo de nuvem,
sorriso enorme, olhos com anéis, auréola de sol dourada atrás da cabeça, faixa dourada, punhos e
pés gigantes. ~26 studs de altura. Cada peça é modelada em torno da sua junta (origem = junta),
para o jogo esticar, quicar e girar as peças:
    tita_pernaD / tita_pernaE   junta no quadril
    tita_tronco                 junta na cintura
    tita_cabeca, tita_cabelo    junta no pescoço
    tita_halo                   centro da cabeça (Neon)
    tita_bracoD / tita_bracoE   junta no ombro
+Y (Blender) é a frente.

Saídas:
    src/client/Mundo/Nexo3D/Dados/tita_*.luau   geometria (formato do kit do Nexo)
    src/shared/Dados/TitaVisual.luau            peças, material e junta (gerado)
    assets/evento/previews/tita.jpg             render (NÃO é print do Roblox)
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
ARQ_VISUAL = os.path.join(RAIZ, "src", "shared", "Dados", "TitaVisual.luau")
DIR_PREV = os.path.join(RAIZ, "assets", "evento", "previews")
rng = random.Random(5)

CREME = (1.0, 0.95, 0.86)
CREME_ESC = (0.88, 0.80, 0.70)
NUVEM = (1.0, 1.0, 1.0)
OURO = (1.0, 0.78, 0.22)
OURO_ESC = (0.85, 0.55, 0.12)
BOCA = (0.35, 0.08, 0.12)
LINGUA = (1.0, 0.45, 0.50)
PRETO = (0.05, 0.04, 0.06)
BOCHECHA = (1.0, 0.62, 0.62)
SOL = (1.0, 0.82, 0.25)


def esfera(c, r, cor, esc=(1, 1, 1), lados=12, aneis=8):
    perfil = [(max(r * math.sin(math.pi * k / aneis), 0.001), -r * math.cos(math.pi * k / aneis)) for k in range(aneis + 1)]
    bm = kit.torno(perfil, lados, cor, rng, tinta=1.0)
    bmesh.ops.transform(bm, matrix=T(c) @ Matrix.Diagonal((*esc, 1)), verts=bm.verts[:])
    kit.pintar(bm, cor, 1.0, topo_claro=0.25)
    return bm


def membro(p0, p1, r0, r1, cor, lados=12):
    a, b = Vector(p0), Vector(p1)
    d = b - a
    L = d.length
    bm = kit.torno([(0.001, 0), (r0, 0), (r1, L), (0.001, L)], lados, cor, rng, tinta=1.0)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=T(a) @ rot, verts=bm.verts[:])
    kit.pintar(bm, cor, 1.0, topo_claro=0.25)
    return bm


def nuvem(c, r, n, semente):
    g = random.Random(semente)
    out = [esfera(c, r, NUVEM, lados=10, aneis=6)]
    for _ in range(n):
        a = g.uniform(0, math.pi * 2)
        e = g.uniform(-0.4, 0.6)
        d = r * g.uniform(0.6, 0.95)
        out.append(esfera((c[0] + math.cos(a) * d, c[1] + math.sin(a) * d * 0.7, c[2] + e * r), r * g.uniform(0.45, 0.7), NUVEM, lados=10, aneis=6))
    return out


def perna(lado):
    # junta no quadril (origem); perna descendo até o pé (z = -7.5)
    p = [
        esfera((0, 0, -1.6), 2.3, CREME, (1, 1, 1.15)),  # coxa bufante
        membro((0, 0, -3.0), (0, 0.2, -6.2), 1.7, 1.5, CREME),
        esfera((0, 0.2, -5.6), 1.85, NUVEM, (1, 1, 0.55), 12, 6),  # punho de nuvem na canela
        esfera((0, 1.2, -6.9), 1.9, CREME_ESC, (1.0, 1.55, 0.7)),  # pé grandão
        esfera((0, 2.4, -6.85), 0.5, CREME, (1.2, 1, 0.8)),
    ]
    return montar(p), montar([])


def tronco():
    # junta na cintura (origem); barriga redonda até o pescoço (z = +10)
    perfil = [(0.001, -0.6), (3.6, -0.4), (4.4, 1.5), (4.6, 4.0), (4.3, 6.5), (3.6, 8.6), (2.2, 9.8), (0.001, 10.1)]
    corpo = kit.torno(perfil, 16, CREME, rng, tinta=1.0)
    bmesh.ops.scale(corpo, vec=(1.0, 0.82, 1.0), verts=corpo.verts[:])
    kit.pintar(corpo, CREME, 1.0, topo_claro=0.3)
    faixa = kit.torno([(4.5, 0.2), (4.65, 0.9), (4.55, 1.8), (4.4, 2.2)], 16, OURO, rng, tinta=1.0)
    bmesh.ops.scale(faixa, vec=(1.02, 0.84, 1.0), verts=faixa.verts[:])
    kit.pintar(faixa, OURO, 1.0, topo_claro=0.3)
    base = [corpo, faixa]
    # nó da faixa com as pontas voando
    base.append(esfera((2.6, 3.4, 1.2), 0.7, OURO_ESC))
    base.append(eq.ponta((2.8, 3.5, 1.0), (4.2, 3.0, -1.8), 0.9, OURO))
    base.append(eq.ponta((2.4, 3.5, 1.0), (3.0, 3.8, -2.2), 0.8, OURO_ESC))
    # sol no peito
    brilho = [eq.cilindro((0, 3.95, 6.0), 1.0, 0.25, SOL, 14, R(90, "X"))]
    for k in range(8):
        a = k * 45
        r = math.radians(a)
        brilho.append(eq.ponta((math.cos(r) * 1.0, 3.95, 6.0 + math.sin(r) * 1.0), (math.cos(r) * 1.7, 3.85, 6.0 + math.sin(r) * 1.7), 0.35, SOL))
    # nuvens nos ombros
    for lado in (1, -1):
        base += nuvem((lado * 4.0, -0.2, 8.8), 1.4, 4, 10 + lado)
    return montar(base), montar(brilho)


def cabeca():
    # junta no pescoço (origem); cabeça grande e redonda (centro z = +4)
    c = (0, 0.3, 4.0)
    base = [esfera(c, 4.0, CREME, (1.0, 0.95, 0.98), 16, 10)]
    # sorriso enorme: boca escura, dentes e língua
    base.append(esfera((0, 3.55, 2.6), 2.4, BOCA, (1.0, 0.35, 0.55), 14, 6))
    base.append(bx((0, 4.25, 3.05), (3.6, 0.35, 0.55), NUVEM, 0.12))
    base.append(esfera((0, 4.05, 2.0), 1.0, LINGUA, (1.2, 0.5, 0.45)))
    # olhos redondos com anéis (o "olhar elétrico")
    olhos = []
    for x in (-1.5, 1.5):
        base.append(esfera((x, 3.6, 5.1), 1.05, NUVEM, (1, 0.45, 1.1)))
        base.append(esfera((x, 4.0, 5.15), 0.55, PRETO, (1, 0.4, 1.1)))
        olhos.append(esfera((x + 0.2, 4.15, 5.45), 0.18, NUVEM, (1, 0.4, 1)))
        anel = kit.torno([(1.25, -0.08), (1.4, -0.08), (1.4, 0.08), (1.25, 0.08), (1.25, -0.08)], 16, SOL, rng, tinta=1.0)
        bmesh.ops.transform(anel, matrix=T((x, 3.85, 5.1)) @ R(90, "X"), verts=anel.verts[:])
        olhos.append(anel)
        base.append(esfera((x * 1.7, 3.2, 3.2), 0.6, BOCHECHA, (1, 0.35, 0.7)))
        # sobrancelha arqueada de alegria
        base.append(bx((x, 3.9, 6.75), (1.4, 0.35, 0.3), CREME_ESC, 0.08, R(0, "Y")))
    base.append(esfera((0, 4.05, 4.1), 0.45, CREME_ESC, (1, 0.8, 0.8)))  # nariz
    return montar(base), montar(olhos)


def cabelo():
    # junta no pescoço; nuvem de cabelo branco em cima e atrás da cabeça
    base = []
    for c, r in [((0, -0.3, 8.0), 2.6), ((-2.6, -0.6, 7.2), 2.0), ((2.6, -0.6, 7.2), 2.0), ((0, -2.4, 6.6), 2.3), ((-1.8, -2.2, 5.0), 1.7), ((1.8, -2.2, 5.0), 1.7), ((-3.4, 0.2, 5.8), 1.4), ((3.4, 0.2, 5.8), 1.4)]:
        base += nuvem(c, r, 3, int(r * 10 + c[0] * 7))
    # mechas espetadas para cima
    for k in range(7):
        a = (k - 3) * 22
        base.append(eq.ponta((math.sin(math.radians(a)) * 2.0, -0.6, 8.6), (math.sin(math.radians(a)) * 3.8, -1.4, 11.0 - abs(k - 3) * 0.35), 1.1, NUVEM))
    return montar(base), montar([])


def halo():
    # auréola de sol atrás da cabeça (centro da cabeça na origem)
    brilho = []
    anel = kit.torno([(5.6, -0.25), (6.2, -0.25), (6.2, 0.25), (5.6, 0.25), (5.6, -0.25)], 32, SOL, rng, tinta=1.0)
    bmesh.ops.transform(anel, matrix=T((0, -3.2, 0)) @ R(90, "X"), verts=anel.verts[:])
    brilho.append(anel)
    for k in range(16):
        r = math.radians(k * 22.5)
        comp = 1.6 if k % 2 == 0 else 1.0
        brilho.append(eq.ponta((math.cos(r) * 6.2, -3.2, math.sin(r) * 6.2), (math.cos(r) * (6.2 + comp), -3.2, math.sin(r) * (6.2 + comp)), 0.7, SOL))
    return montar([]), montar(brilho)


def braco(lado):
    # junta no ombro; braço de borracha caindo até o punho gigante (z = -8)
    base = [
        esfera((0, 0, 0), 1.7, CREME),
        membro((0, 0, -0.5), (lado * 0.6, 0.6, -5.5), 1.35, 1.2, CREME),
        esfera((lado * 0.7, 0.7, -5.3), 1.5, NUVEM, (1, 1, 0.5)),  # punho de nuvem no pulso
        esfera((lado * 0.8, 0.9, -7.4), 2.1, NUVEM, (1, 1, 1.05)),  # luva/punho gigante
    ]
    for k in range(3):
        base.append(esfera((lado * 0.8 + (k - 1) * 0.9, 2.6, -7.0), 0.6, NUVEM))
    return montar(base), montar([])


PECAS = [
    ("pernaD", lambda: perna(1), (2.6, 0, 7.5)),
    ("pernaE", lambda: perna(-1), (-2.6, 0, 7.5)),
    ("tronco", tronco, (0, 0, 7.5)),
    ("cabeca", cabeca, (0, 0, 17.2)),
    ("cabelo", cabelo, (0, 0, 17.2)),
    ("halo", halo, (0, 0.3, 21.2)),
    ("bracoD", lambda: braco(1), (5.2, 0, 15.2)),
    ("bracoE", lambda: braco(-1), (-5.2, 0, 15.2)),
]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {"base": kit.criar_material("Tita", rugosidade=0.55), "brilho": kit.criar_material("TitaBrilho", emissao=3.0)}
    linhas = ["-- GERADO por assets/evento/source/generate_tita.py. Não editar à mão.", "-- Peças do Titã de Borracha: malhas (base e brilho), junta no espaço do Titã (pés no chão,", "-- frente = -Z do Roblox) e o papel de cada peça na animação.", "return {"]
    objetos = []
    for nome, fn, junta in PECAS:
        b, l = fn()
        camadas = []
        for camada, bm, material in (("base", b, "SmoothPlastic"), ("brilho", l, "Neon")):
            if len(bm.faces) == 0:
                continue
            id_ = "tita_%s%s" % (nome, "" if camada == "base" else "_brilho")
            obj = kit.registrar(id_, bm, mats[camada])
            eq.escrever_malha(id_, obj)
            obj.location = junta
            objetos.append(obj)
            camadas.append('{ malha = "%s", material = "%s" }' % (id_, material))
        # junta em coordenadas do Roblox: (x, z, -y)
        linhas.append('\t{ nome = "%s", junta = { %.3f, %.3f, %.3f }, camadas = { %s } },' % (nome, junta[0], junta[2], -junta[1], ", ".join(camadas)))
    linhas += ["}", ""]
    with open(ARQ_VISUAL, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    if "--render" in sys.argv:
        renderizar(objetos)


def renderizar(objetos):
    os.makedirs(DIR_PREV, exist_ok=True)
    c = bpy.context.scene
    c.render.engine = "CYCLES"; c.cycles.samples = 64; c.cycles.use_denoising = True
    c.render.resolution_x, c.render.resolution_y = 1100, 1200
    c.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.95, 0.86, 0.6, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.7
    c.world = w
    for o in objetos:
        c.collection.objects.link(o)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    chao = bpy.context.object; m = bpy.data.materials.new("chao"); m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.7, 0.62, 1)
    chao.data.materials.append(m)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(40), 0, math.radians(150))); bpy.context.object.data.energy = 3.0
    bpy.ops.object.light_add(type="AREA", location=(-20, 20, 25)); l = bpy.context.object; l.data.size = 20; l.data.energy = 6000
    l.rotation_euler = (Vector((0, 0, 12)) - l.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add(); cam = bpy.context.object; c.camera = cam; cam.data.lens = 45
    for nome, pos in (("tita", (22, 42, 16)), ("tita_rosto", (8, 22, 22))):
        alvo = Vector((0, 0, 13.5)) if nome == "tita" else Vector((0, 0.5, 21))
        cam.location = pos
        cam.rotation_euler = (alvo - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        c.render.filepath = os.path.join(DIR_PREV, nome + ".jpg")
        c.render.image_settings.file_format = "JPEG"
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
