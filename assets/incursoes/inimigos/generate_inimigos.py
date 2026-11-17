"""Inimigos das Incursões em ALTA QUALIDADE para importar manualmente no Roblox Studio.

Diferente dos kits (que entram pelo código), estes modelos usam o Blender por inteiro:
  * corpo orgânico: modificador SKIN sobre um esqueleto de vértices + SUBDIVISION SURFACE,
    depois deslocamento por ruído fractal (mathutils.noise) para a pele/rocha/lodo;
  * peças extras (chifres, garras, nadadeiras, placas, capuz, asas) como tubos afinados e
    blocos com BEVEL + subdivisão, unidos ao corpo;
  * ARMATURE com ossos nomeados (o jogo anima pelos nomes) e pesos calculados por distância
    aos ossos (mistura suave entre os dois mais próximos);
  * UV (Smart UV Project) e TEXTURA ASSADA (bake Cycles) a partir de um material procedural
    (ruído + Voronoi para veios + escurecer embaixo), salva em PNG e embutida no FBX;
  * malha de BRILHO separada (olhos, garras, núcleo), também presa aos ossos: no Studio vira Neon.

Uso:
    python assets/incursoes/inimigos/generate_inimigos.py            # modelos + FBX + texturas
    python assets/incursoes/inimigos/generate_inimigos.py --render   # também as prévias

Saídas (um modelo por inimigo, mesmo nome que o jogo procura):
    exports/inc_<universo>_sombra.fbx, exports/inc_<universo>_guardiao.fbx
    texturas/<nome>_cor.png
    previews/<nome>.jpg
    source/inimigos.blend
Os modelos olham para -Y (frente padrão do Blender) e têm os pés em z = 0.
Passo a passo de importação: assets/incursoes/inimigos/IMPORTAR_NO_STUDIO.md
"""

import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector, noise

AQUI = os.path.dirname(os.path.abspath(__file__))
DIR_EXP = os.path.join(AQUI, "exports")
DIR_TEX = os.path.join(AQUI, "texturas")
DIR_PREV = os.path.join(AQUI, "previews")
DIR_SRC = os.path.join(AQUI, "source")

# ---------------------------------------------------------------- utilidades


def suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def objeto(nome, me):
    obj = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def ativar(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def malha_avaliada(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    return me


class Esqueleto:
    """Juntas (pontos) + ligações com raio: vira corpo pelo modificador Skin."""

    def __init__(self):
        self.pts = []
        self.raios = []
        self.arestas = []
        self.nomes = {}

    def ponto(self, nome, p, rx, ry=None):
        self.nomes[nome] = len(self.pts)
        self.pts.append(Vector(p))
        self.raios.append((rx, ry if ry is not None else rx))
        return nome

    def liga(self, a, b, passos=1):
        """Liga a até b; passos > 1 cria juntas intermediárias (raio interpolado)."""
        ia, ib = self.nomes[a], self.nomes[b]
        anterior = ia
        for k in range(1, passos):
            f = k / passos
            p = self.pts[ia].lerp(self.pts[ib], f)
            r = tuple(self.raios[ia][i] + (self.raios[ib][i] - self.raios[ia][i]) * f for i in range(2))
            idx = len(self.pts)
            self.pts.append(p)
            self.raios.append(r)
            self.arestas.append((anterior, idx))
            anterior = idx
        self.arestas.append((anterior, ib))

    def corpo(self, nome, subdiv=2):
        me = bpy.data.meshes.new(nome + "_esq")
        me.from_pydata([tuple(p) for p in self.pts], self.arestas, [])
        obj = objeto(nome + "_esq", me)
        mod = obj.modifiers.new("skin", "SKIN")
        mod.use_smooth_shade = True
        mod.branch_smoothing = 0.6
        dados = me.skin_vertices[0].data
        for i, (rx, ry) in enumerate(self.raios):
            dados[i].radius = (rx, ry)
        dados[0].use_root = True
        sub = obj.modifiers.new("sub", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
        me2 = malha_avaliada(obj)
        bpy.data.objects.remove(obj)
        bpy.data.meshes.remove(me)
        bm = bmesh.new()
        bm.from_mesh(me2)
        bpy.data.meshes.remove(me2)
        return bm


def deslocar(bm, forca, escala, semente, veios=0.0):
    """Superfície orgânica: ruído fractal ao longo da normal (+ sulcos de Voronoi)."""
    bm.normal_update()
    off = Vector((semente * 7.1, semente * 3.3, semente * 5.7))
    for v in bm.verts:
        p = v.co * escala + off
        n = noise.fractal(p, 0.6, 2.2, 4)
        d = n * forca
        if veios:
            dist = noise.voronoi(p * 0.7)[0][0]
            d -= veios * (1 - suave(0.0, 0.18, dist))
        v.co += v.normal * d


def tubo(bm, pts, raios, lados=10, achatar=1.0):
    """Tubo liso (referencial transportado) com pontas fechadas: chifres, garras, farrapos."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tang = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    normal = tang[0].orthogonal().normalized()
    aneis = []
    for i in range(n):
        t = tang[i]
        normal = (normal - t * normal.dot(t)).normalized()
        bi = t.cross(normal)
        aneis.append([bm.verts.new(pts[i] + (normal * math.cos(a) * achatar + bi * math.sin(a)) * raios[i]) for a in (2 * math.pi * j / lados for j in range(lados))])
    for i in range(n - 1):
        for j in range(lados):
            bm.faces.new((aneis[i][j], aneis[i][(j + 1) % lados], aneis[i + 1][(j + 1) % lados], aneis[i + 1][j]))
    ini = bm.verts.new(pts[0] - tang[0] * raios[0] * 0.3)
    fim = bm.verts.new(pts[-1] + tang[-1] * max(raios[-1], 0.01))
    for j in range(lados):
        bm.faces.new((ini, aneis[0][(j + 1) % lados], aneis[0][j]))
        bm.faces.new((aneis[-1][j], aneis[-1][(j + 1) % lados], fim))


def chifre(bm, base, direcao, curva, comp, raio, gancho=0.5, n=18, lados=10, achatar=1.0):
    d = Vector(direcao).normalized()
    c = Vector(curva).normalized()
    pts, rs = [], []
    for i in range(n):
        f = i / (n - 1)
        pts.append(Vector(base) + d * comp * f + c * comp * gancho * f * f)
        rs.append(raio * (1 - f) ** 1.05 + 0.005)
    tubo(bm, pts, rs, lados, achatar)


def placa(bm, centro, tam, giro=(0, 0, 0), bisel=0.15, sub=1):
    """Bloco com bevel e subdivisão (placas de armadura, rochas)."""
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=tam, verts=tmp.verts[:])
    bmesh.ops.bevel(tmp, geom=tmp.edges[:], offset=bisel, offset_type="OFFSET", segments=2, profile=0.6, affect="EDGES", clamp_overlap=True)
    if sub:
        bmesh.ops.subdivide_edges(tmp, edges=tmp.edges[:], cuts=sub, use_grid_fill=True, smooth=0.6)
    m = Matrix.Translation(centro) @ Matrix.Rotation(math.radians(giro[2]), 4, "Z") @ Matrix.Rotation(math.radians(giro[1]), 4, "Y") @ Matrix.Rotation(math.radians(giro[0]), 4, "X")
    bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts[:])
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def esfera(bm, centro, r, sub=2):
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=r)
    bmesh.ops.translate(tmp, vec=centro, verts=tmp.verts[:])
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def juntar(destino, origem):
    me = bpy.data.meshes.new("tmp")
    origem.to_mesh(me)
    origem.free()
    destino.from_mesh(me)
    bpy.data.meshes.remove(me)


def reduzir(obj, alvo):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > alvo:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = alvo / tris
        ativar(obj)
        bpy.ops.object.modifier_apply(modifier="dec")


# ---------------------------------------------------------------- ossos e pesos


def armadura(nome, ossos):
    """ossos: lista (nome, cabeça, cauda, pai)."""
    arm = bpy.data.armatures.new(nome + "_Rig")
    obj = objeto(nome + "_Rig", arm)
    ativar(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    feitos = {}
    for n, cab, cau, pai in ossos:
        b = arm.edit_bones.new(n)
        b.head = Vector(cab)
        b.tail = Vector(cau)
        if pai:
            b.parent = feitos[pai]
        feitos[n] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def dist_segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def pesar(obj_malha, rig, ossos, so=None):
    """Pesos por distância: cada vértice fica com os 2 ossos mais próximos (mistura suave).
    so = nome de um osso: a malha inteira vai para ele (peças rígidas como olhos)."""
    me = obj_malha.data
    grupos = {n: obj_malha.vertex_groups.new(name=n) for n, _, _, _ in ossos}
    segs = [(n, Vector(c), Vector(t)) for n, c, t, _ in ossos if n != "Raiz"]
    for v in me.vertices:
        if so:
            grupos[so].add([v.index], 1.0, "REPLACE")
            continue
        ds = sorted(((dist_segmento(v.co, a, b), n) for n, a, b in segs))[:2]
        w = [1 / max(d, 0.05) ** 4 for d, _ in ds]
        s = sum(w)
        for (d, n), wi in zip(ds, w):
            grupos[n].add([v.index], wi / s, "REPLACE")
    mod = obj_malha.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    obj_malha.parent = rig


# ---------------------------------------------------------------- material e bake


def material_procedural(nome, escura, clara, veio, escala=2.5):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    coord = nt.nodes.new("ShaderNodeTexCoord")
    ruido = nt.nodes.new("ShaderNodeTexNoise")
    ruido.inputs["Scale"].default_value = escala
    ruido.inputs["Detail"].default_value = 8
    nt.links.new(coord.outputs["Object"], ruido.inputs["Vector"])
    rampa = nt.nodes.new("ShaderNodeValToRGB")
    rampa.color_ramp.elements[0].color = (*escura, 1)
    rampa.color_ramp.elements[1].color = (*clara, 1)
    rampa.color_ramp.elements[0].position = 0.35
    rampa.color_ramp.elements[1].position = 0.75
    nt.links.new(ruido.outputs["Fac"], rampa.inputs["Fac"])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = escala * 2.6
    nt.links.new(coord.outputs["Object"], vor.inputs["Vector"])
    corte = nt.nodes.new("ShaderNodeMapRange")
    corte.inputs["From Min"].default_value = 0.0
    corte.inputs["From Max"].default_value = 0.025
    corte.inputs["To Min"].default_value = 1.0
    corte.inputs["To Max"].default_value = 0.0
    nt.links.new(vor.outputs["Distance"], corte.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMixRGB")
    mix.inputs[2].default_value = (*veio, 1)
    mix.inputs[0].default_value = 0.0
    nt.links.new(corte.outputs["Result"], mix.inputs[0])
    nt.links.new(rampa.outputs["Color"], mix.inputs[1])
    # escurece embaixo (pés na sombra)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs["Vector"])
    alt = nt.nodes.new("ShaderNodeMapRange")
    alt.inputs["From Min"].default_value = 0.0
    alt.inputs["From Max"].default_value = 2.5
    alt.inputs["To Min"].default_value = 0.45
    alt.inputs["To Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], alt.inputs["Value"])
    mul = nt.nodes.new("ShaderNodeMixRGB")
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(mix.outputs["Color"], mul.inputs[1])
    nt.links.new(alt.outputs["Result"], mul.inputs[2])
    nt.links.new(mul.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.65
    return m


def material_brilho(nome, cor):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    b.inputs["Emission Color"].default_value = (*cor, 1)
    b.inputs["Emission Strength"].default_value = 6
    return m


def uv_e_bake(obj, nome, mat, res=1024):
    """Smart UV Project + bake da cor (DIFFUSE/COLOR) do material procedural para um PNG,
    e troca o material por um que só usa a imagem (é o que vai no FBX)."""
    ativar(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.015)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    img = bpy.data.images.new(nome + "_cor", res, res)
    no = mat.node_tree.nodes.new("ShaderNodeTexImage")
    no.image = img
    mat.node_tree.nodes.active = no
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 8
    cena.render.bake.use_pass_direct = False
    cena.render.bake.use_pass_indirect = False
    cena.render.bake.margin = 6
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    caminho = os.path.join(DIR_TEX, nome + "_cor.png")
    img.filepath_raw = caminho
    img.file_format = "PNG"
    img.save()
    final = bpy.data.materials.new(nome)
    final.use_nodes = True
    nt = final.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.7
    obj.data.materials.clear()
    obj.data.materials.append(final)
    return caminho


# ---------------------------------------------------------------- esqueletos (frente = +Y; vira para -Y no fim)


def ossos_humanoide(e):
    """Ossos padrão a partir das juntas do esqueleto (os nomes que o jogo anima)."""
    P = lambda n: tuple(e.pts[e.nomes[n]])  # noqa: E731
    return [
        ("Raiz", (0, 0, 0), (0, 0, 0.6), None),
        ("Quadril", P("pelve"), P("barriga"), "Raiz"),
        ("Tronco", P("barriga"), P("peito"), "Quadril"),
        ("Peito", P("peito"), P("pescoco"), "Tronco"),
        ("Cabeca", P("pescoco"), P("topo"), "Peito"),
        ("Braco.L", P("ombro.L"), P("cotovelo.L"), "Peito"),
        ("Antebraco.L", P("cotovelo.L"), P("mao.L"), "Braco.L"),
        ("Braco.R", P("ombro.R"), P("cotovelo.R"), "Peito"),
        ("Antebraco.R", P("cotovelo.R"), P("mao.R"), "Braco.R"),
        ("Coxa.L", P("quadril.L"), P("joelho.L"), "Quadril"),
        ("Canela.L", P("joelho.L"), P("tornozelo.L"), "Coxa.L"),
        ("Coxa.R", P("quadril.R"), P("joelho.R"), "Quadril"),
        ("Canela.R", P("joelho.R"), P("tornozelo.R"), "Coxa.R"),
    ]


def esqueleto_humanoide(s, curvado=0.0, braco=1.0, perna=1.0, larg=1.0, grosso=1.0):
    """s = escala de altura (1 = ~5 studs). curvado: quanto o tronco vai para a frente."""
    e = Esqueleto()
    g = grosso
    e.ponto("pelve", (0, 0, 2.3 * s), 0.55 * s * g * larg, 0.45 * s * g)
    e.ponto("barriga", (0, 0.25 * curvado * s, 3.0 * s), 0.5 * s * g * larg, 0.42 * s * g)
    e.ponto("peito", (0, 0.6 * curvado * s, 3.75 * s), 0.72 * s * g * larg, 0.5 * s * g)
    e.ponto("pescoco", (0, 0.95 * curvado * s + 0.05 * s, 4.25 * s), 0.25 * s * g)
    e.ponto("cabeca", (0, 1.15 * curvado * s + 0.15 * s, 4.65 * s), 0.42 * s * g, 0.46 * s * g)
    e.ponto("topo", (0, 1.2 * curvado * s + 0.15 * s, 5.05 * s), 0.2 * s * g)
    e.liga("pelve", "barriga", 2)
    e.liga("barriga", "peito", 2)
    e.liga("peito", "pescoco")
    e.liga("pescoco", "cabeca")
    e.liga("cabeca", "topo")
    for lado, L in ((1, "L"), (-1, "R")):
        e.ponto("ombro." + L, (lado * 0.95 * s * larg, 0.55 * curvado * s, 3.95 * s), 0.3 * s * g)
        e.ponto("cotovelo." + L, (lado * 1.45 * s * larg, (0.6 * curvado + 0.3) * s, (3.95 - 1.0 * braco) * s), 0.22 * s * g)
        e.ponto("mao." + L, (lado * 1.5 * s * larg, (0.6 * curvado + 0.75) * s, (3.95 - 2.0 * braco) * s), 0.2 * s * g, 0.14 * s * g)
        e.liga("peito", "ombro." + L)
        e.liga("ombro." + L, "cotovelo." + L, 2)
        e.liga("cotovelo." + L, "mao." + L, 2)
        e.ponto("quadril." + L, (lado * 0.48 * s * larg, 0, 2.15 * s), 0.3 * s * g)
        e.ponto("joelho." + L, (lado * 0.55 * s * larg, 0.3 * s, (2.15 - 1.0 * perna) * s), 0.24 * s * g)
        e.ponto("tornozelo." + L, (lado * 0.52 * s * larg, -0.05 * s, 0.25 * s), 0.18 * s * g)
        e.ponto("pe." + L, (lado * 0.52 * s * larg, 0.4 * s, 0.1 * s), 0.16 * s * g, 0.1 * s * g)
        e.liga("pelve", "quadril." + L)
        e.liga("quadril." + L, "joelho." + L, 2)
        e.liga("joelho." + L, "tornozelo." + L, 2)
        e.liga("tornozelo." + L, "pe." + L)
    return e


def P(e, n):
    return e.pts[e.nomes[n]]


# ---------------------------------------------------------------- os inimigos

PALETA = {
    "cinzas": dict(escura=(0.035, 0.012, 0.01), clara=(0.16, 0.07, 0.05), veio=(0.55, 0.16, 0.04), brilho=(1.0, 0.42, 0.12)),
    "mare": dict(escura=(0.01, 0.03, 0.045), clara=(0.06, 0.15, 0.17), veio=(0.12, 0.4, 0.4), brilho=(0.3, 0.75, 1.0)),
    "umbral": dict(escura=(0.02, 0.01, 0.04), clara=(0.09, 0.05, 0.16), veio=(0.3, 0.14, 0.5), brilho=(0.68, 0.38, 1.0)),
}


def garras(luz, e, s, n=3, comp=0.7):
    for lado, L in ((1, "L"), (-1, "R")):
        m = P(e, "mao." + L)
        for k in range(n):
            ang = (k - (n - 1) / 2) * 0.35
            chifre(luz, m + Vector((lado * 0.08 * (k - 1), 0.12 * s, -0.1 * s)), (lado * math.sin(ang) * 0.4, 0.6, -1), (0, 1, 0), comp * s, 0.06 * s, gancho=0.55, n=10, lados=6)


def olhos(luz, e, s, larg=0.17, alt=0.02):
    c = P(e, "cabeca")
    for lado in (1, -1):
        esfera(luz, c + Vector((lado * larg * s, 0.38 * s, alt * s)), 0.075 * s, 1)


def sombra(u):
    rng = random.Random(len(u) * 31)
    s = 1.0
    e = esqueleto_humanoide(s, curvado=1.0, braco=1.15, perna=1.0, larg=1.0, grosso=0.9)
    if u == "umbral":
        # cauda de fumaça (vira ossos Cauda1..3)
        e.ponto("cauda1", (0, -0.6, 2.0), 0.25)
        e.ponto("cauda2", (0, -1.4, 1.4), 0.17)
        e.ponto("cauda3", (0, -2.0, 0.9), 0.08)
        e.liga("pelve", "cauda1", 2)
        e.liga("cauda1", "cauda2", 2)
        e.liga("cauda2", "cauda3", 2)
    corpo = e.corpo("corpo", 2)
    deslocar(corpo, 0.06, 2.2, len(u), veios=0.03)
    luz = bmesh.new()
    garras(luz, e, s, 3, 0.75)
    olhos(luz, e, s)
    cab = P(e, "cabeca")
    if u == "cinzas":
        for lado in (1, -1):
            chifre(corpo, cab + Vector((lado * 0.25, 0.1, 0.25)), (lado * 0.6, -0.5, 0.8), (0, -1, -0.3), 1.2, 0.13, gancho=0.6)
        for k in range(5):  # espinhos de rocha nas costas
            p = P(e, "peito").lerp(P(e, "pelve"), k / 4)
            chifre(corpo, p + Vector((0, -0.35, 0)), (0, -1, 0.4), (0, 0, 1), 0.5 - 0.06 * k, 0.12, gancho=0.3, n=8, lados=8)
        tubo(luz, [P(e, "peito") + Vector((x, 0.48, z)) for x, z in ((-0.25, 0.25), (-0.05, 0.0), (0.1, -0.2), (0.0, -0.45))], [0.04, 0.05, 0.04, 0.02], 6)
    elif u == "mare":
        for k in range(4):  # nadadeira dorsal
            p = P(e, "peito").lerp(P(e, "pelve"), k / 3)
            chifre(corpo, p + Vector((0, -0.4, 0)), (0, -1, 0.5), (0, 0, 1), 0.7 - 0.1 * k, 0.16, gancho=0.2, n=8, lados=8, achatar=0.25)
        for lado, L in ((1, "L"), (-1, "R")):  # nadadeiras dos antebraços
            chifre(corpo, P(e, "cotovelo." + L), (lado * 0.6, -0.4, 0.2), (0, 0, 1), 0.6, 0.14, gancho=0.3, n=8, lados=8, achatar=0.3)
        corpo.verts.ensure_lookup_table()
        pontos = [corpo.verts[rng.randrange(len(corpo.verts))].co.copy() for _ in range(14)]
        for co in pontos:  # cracas
            esfera(corpo, co, rng.uniform(0.05, 0.1), 1)
        for k in range(5):  # algas penduradas
            b = P(e, "peito") + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.2, 0.3), -0.2))
            tubo(corpo, [b + Vector((0.08 * math.sin(i), 0.05 * i, -0.25 * i)) for i in range(6)], [0.04 * (1 - i / 6) + 0.01 for i in range(6)], 6)
    else:
        # capuz pontudo e farrapos do manto
        chifre(corpo, cab + Vector((0, -0.05, 0.1)), (0, -0.7, 1), (0, -1, -0.2), 1.0, 0.45, gancho=0.5, n=14, lados=14)
        for k in range(8):
            a = math.pi * (k / 7) - math.pi / 2
            b = P(e, "peito") + Vector((0.7 * math.sin(a), -0.35, 0.1))
            chifre(corpo, b, (0.3 * math.sin(a), -0.5, -1), (0, -1, 0), rng.uniform(1.4, 2.2), 0.15, gancho=0.3, n=10, lados=6, achatar=0.25)
    return e, corpo, luz


def guardiao(u):
    rng = random.Random(len(u) * 57)
    if u == "cinzas":  # Arauto das Brasas: colosso de basalto
        s = 3.0
        e = esqueleto_humanoide(s, curvado=0.35, braco=1.0, perna=0.85, larg=1.15, grosso=1.25)
        corpo = e.corpo("corpo", 2)
        deslocar(corpo, 0.22, 0.8, 3, veios=0.12)
        luz = bmesh.new()
        cab = P(e, "cabeca")
        for lado in (1, -1):
            chifre(corpo, cab + Vector((lado * 0.8, 0, 0.6)), (lado * 1, -0.3, 0.6), (0, -0.5, 1), 4.2, 0.55, gancho=0.7, n=18, lados=12)
        for lado, L in ((1, "L"), (-1, "R")):
            placa(corpo, P(e, "ombro." + L) + Vector((lado * 0.3, 0, 0.6)), (2.6, 2.4, 1.4), (rng.uniform(-10, 10), lado * 20, 0), 0.3, 1)
            placa(corpo, P(e, "mao." + L), (1.6, 1.6, 1.6), (15, 0, 30), 0.35, 1)  # punhos de pedra
            for k in range(3):
                chifre(corpo, P(e, "ombro." + L) + Vector((lado * 0.4 * k, -0.4, 1.0)), (lado * 0.3, -0.6, 1), (0, 0, 1), 1.4 - 0.3 * k, 0.32, gancho=0.2, n=10, lados=8)
        # coração de brasa e rachaduras
        esfera(luz, P(e, "peito") + Vector((0, 1.15, -0.2)), 0.55, 2)
        for k in range(6):
            a = 2 * math.pi * k / 6
            o = P(e, "peito") + Vector((0, 1.1, -0.2))
            tubo(luz, [o + Vector(((0.5 + 0.35 * i) * math.cos(a), -0.08 * i, (0.5 + 0.35 * i) * math.sin(a))) for i in range(5)], [0.1 * (1 - i / 5) + 0.02 for i in range(5)], 6)
        for lado in (1, -1):
            esfera(luz, cab + Vector((lado * 0.4, 1.15, 0.05)), 0.16, 1)
        return e, corpo, luz
    if u == "mare":  # Cavaleiro Afogado
        s = 2.9
        e = esqueleto_humanoide(s, curvado=0.1, braco=1.05, perna=1.05, larg=0.95, grosso=0.85)
        corpo = e.corpo("corpo", 2)
        deslocar(corpo, 0.05, 1.2, 5)
        luz = bmesh.new()
        # placas de armadura
        for nome, tam in (("peito", (3.6, 2.4, 2.6)), ("barriga", (3.0, 2.0, 1.6)), ("pelve", (3.2, 2.2, 1.4))):
            placa(corpo, P(e, nome) + Vector((0, 0.15, 0)), tam, (rng.uniform(-4, 4), 0, 0), 0.25, 1)
        cab = P(e, "cabeca")
        placa(corpo, cab, (1.6, 1.8, 1.9), (0, 0, 0), 0.35, 1)  # elmo
        chifre(corpo, cab + Vector((0, -0.2, 0.9)), (0, -1, 0.6), (0, 0, -1), 2.4, 0.3, gancho=0.4, n=14, lados=8, achatar=0.25)  # crista
        tubo(luz, [cab + Vector((x, 0.98, 0.15)) for x in (-0.55, -0.2, 0.2, 0.55)], [0.07] * 4, 6)  # visor
        for lado, L in ((1, "L"), (-1, "R")):
            placa(corpo, P(e, "ombro." + L) + Vector((lado * 0.4, 0, 0.4)), (2.2, 2.4, 1.2), (0, lado * 25, 0), 0.3, 1)
            for k in range(5):  # corais
                b = P(e, "ombro." + L) + Vector((lado * rng.uniform(0.4, 1.4), rng.uniform(-0.6, 0.6), 0.9))
                chifre(corpo, b, (lado * rng.uniform(0, 0.6), rng.uniform(-0.3, 0.3), 1), (lado, 0, 0), rng.uniform(0.8, 1.6), 0.13, gancho=0.5, n=8, lados=6)
        # tridente na mão direita
        m = P(e, "mao.R")
        tubo(corpo, [m + Vector((0, 0, -4.5 + 1.0 * i)) for i in range(11)], [0.14] * 11, 8)
        topo = m + Vector((0, 0, 5.5))
        for dx in (-0.7, 0, 0.7):
            chifre(luz, topo + Vector((dx, 0, 0)), (dx * 0.25, 0, 1), (dx, 0, 0), 1.6, 0.14, gancho=0.1, n=8, lados=6)
        for k in range(9):  # capa em farrapos
            x = -1.6 + 0.4 * k
            chifre(corpo, P(e, "peito") + Vector((x, -0.9, 0.6)), (x * 0.15, -0.4, -1), (0, -1, 0), rng.uniform(5.5, 8.5), 0.4, gancho=0.2, n=10, lados=6, achatar=0.15)
        return e, corpo, luz
    # Espectro do Ocaso: flutua, manto que se abre embaixo, garras longas, asas de lascas
    s = 2.8
    e = esqueleto_humanoide(s, curvado=0.45, braco=1.35, perna=0.7, larg=0.9, grosso=0.8)
    corpo = e.corpo("corpo", 2)
    deslocar(corpo, 0.06, 1.0, 9, veios=0.04)
    luz = bmesh.new()
    cab = P(e, "cabeca")
    chifre(corpo, cab + Vector((0, -0.1, 0.1)), (0, -0.6, 1), (0, -1, 0), 3.2, 1.25, gancho=0.5, n=16, lados=16)  # capuz
    for k in range(16):  # manto
        a = 2 * math.pi * k / 16
        b = P(e, "barriga") + Vector((0.9 * math.cos(a), 0.7 * math.sin(a), 0.4))
        chifre(corpo, b, (0.55 * math.cos(a), 0.45 * math.sin(a), -1), (math.cos(a), math.sin(a), 0), rng.uniform(4.5, 6.5), 0.6, gancho=0.3, n=10, lados=6, achatar=0.25)
    for lado, L in ((1, "L"), (-1, "R")):
        for k in range(6):  # asas de lascas
            o = P(e, "peito") + Vector((lado * 0.6, -0.9, 0.6 - 0.3 * k))
            chifre(corpo, o, (lado * (1 + 0.15 * k), -0.6, 0.9 - 0.35 * k), (0, -1, 0), 4.0 + 1.1 * k, 0.32, gancho=0.2, n=8, lados=6, achatar=0.35)
    garras(luz, e, s, 4, 1.1)
    olhos(luz, e, s, 0.15, 0.05)
    return e, corpo, luz


def ossos_extra(e, ossos, u, tipo):
    lista = list(ossos)
    if tipo == "sombra" and u == "umbral":
        lista += [
            ("Cauda1", tuple(P(e, "pelve")), tuple(P(e, "cauda1")), "Quadril"),
            ("Cauda2", tuple(P(e, "cauda1")), tuple(P(e, "cauda2")), "Cauda1"),
            ("Cauda3", tuple(P(e, "cauda2")), tuple(P(e, "cauda3")), "Cauda2"),
        ]
    if tipo == "guardiao" and u == "umbral":
        pe = P(e, "peito")
        lista += [
            ("Asa.L", tuple(pe + Vector((0.6, -0.9, 0.5))), tuple(pe + Vector((6.0, -3.0, 2.0))), "Peito"),
            ("Asa.R", tuple(pe + Vector((-0.6, -0.9, 0.5))), tuple(pe + Vector((-6.0, -3.0, 2.0))), "Peito"),
        ]
    return lista


ALVO_TRIS = {"sombra": 14000, "guardiao": 18000}  # Roblox aceita até ~20 mil por malha


def gerar_um(u, tipo):
    nome = "inc_%s_%s" % (u, tipo)
    e, corpo_bm, luz_bm = (sombra if tipo == "sombra" else guardiao)(u)
    ossos = ossos_extra(e, ossos_humanoide(e), u, tipo)
    pal = PALETA[u]
    me = bpy.data.meshes.new(nome)
    corpo_bm.to_mesh(me)
    corpo_bm.free()
    for p in me.polygons:
        p.use_smooth = True
    corpo = objeto(nome, me)
    reduzir(corpo, ALVO_TRIS[tipo])
    for p in corpo.data.polygons:  # a redução desfaz o sombreamento suave
        p.use_smooth = True
    me_l = bpy.data.meshes.new(nome + "_Brilho")
    luz_bm.to_mesh(me_l)
    luz_bm.free()
    for p in me_l.polygons:
        p.use_smooth = True
    luz = objeto(nome + "_Brilho", me_l)
    luz.data.materials.append(material_brilho(nome + "_Brilho", pal["brilho"]))
    rig = armadura(nome, ossos)
    # vira para -Y (frente padrão do Blender e do importador do Roblox)
    giro = Matrix.Rotation(math.pi, 4, "Z")
    for o in (corpo, luz):
        o.data.transform(giro)
    ativar(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    for b in rig.data.edit_bones:
        b.transform(giro)
    bpy.ops.object.mode_set(mode="OBJECT")
    ossos_girados = [(n, tuple(giro @ Vector(c)), tuple(giro @ Vector(t)), p) for n, c, t, p in ossos]
    uv_e_bake(corpo, nome, material_procedural(nome + "_proc", pal["escura"], pal["clara"], pal["veio"], 2.5 if tipo == "sombra" else 0.9))
    pesar(corpo, rig, ossos_girados)
    pesar(luz, rig, ossos_girados)
    tris = sum(len(p.vertices) - 2 for p in corpo.data.polygons) + sum(len(p.vertices) - 2 for p in luz.data.polygons)
    print("%-22s %6d triângulos, %d ossos" % (nome, tris, len(ossos)))
    # exporta rig + corpo + brilho, com a textura embutida
    bpy.ops.object.select_all(action="DESELECT")
    for o in (rig, corpo, luz):
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(DIR_EXP, nome + ".fbx"),
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        use_armature_deform_only=True,
        bake_anim=False,
        path_mode="COPY",
        embed_textures=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
    )
    return rig, corpo, luz


def renderizar(modelos):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 48
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 900, 900
    cena.view_settings.view_transform = "AgX"
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 90
    mundo = bpy.data.worlds.new("w")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.12, 0.15, 1)
    cena.world = mundo
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(30)))
    bpy.context.object.data.energy = 3.5
    bpy.ops.object.light_add(type="AREA", location=(0, -30, 25))
    bpy.context.object.data.energy = 6000
    bpy.context.object.data.size = 20
    bpy.context.object.rotation_euler = (Vector((0, 0, 5)) - Vector((0, -30, 25))).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cena.camera = cam
    todos = [o for trio in modelos.values() for o in trio]
    for nome, (rig, corpo, luz) in modelos.items():
        for o in todos:
            o.hide_render = o not in (rig, corpo, luz)
        alt = max(v.co.z for v in corpo.data.vertices)
        alvo = Vector((0, 0, alt * 0.55))
        for sufixo, graus in (("", 25), ("_lado", 100)):
            a = math.radians(graus)
            dist = alt * 2.3
            cam.location = alvo + Vector((math.sin(a) * dist, -math.cos(a) * dist, alt * 0.15))
            cam.rotation_euler = (alvo - cam.location).to_track_quat("-Z", "Y").to_euler()
            cam.data.lens = 50
            cena.render.filepath = os.path.join(DIR_PREV, nome + sufixo + ".jpg")
            bpy.ops.render.render(write_still=True)
        print("prévia", nome)


def main():
    for d in (DIR_EXP, DIR_TEX, DIR_PREV, DIR_SRC):
        os.makedirs(d, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    modelos = {}
    for i, u in enumerate(("cinzas", "mare", "umbral")):
        for j, tipo in enumerate(("sombra", "guardiao")):
            trio = gerar_um(u, tipo)
            # espalha na cena do .blend para ver todos juntos
            for o in trio:
                if o.parent is None:
                    o.location = (i * 30.0, j * 30.0, 0)
            modelos["inc_%s_%s" % (u, tipo)] = trio
    if "--render" in sys.argv:
        for trio in modelos.values():
            for o in trio:
                if o.parent is None:
                    o.location = (0, 0, 0)
        renderizar(modelos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_SRC, "inimigos.blend"), compress=True)


if __name__ == "__main__":
    main()
