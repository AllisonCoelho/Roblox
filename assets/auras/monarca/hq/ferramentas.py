"""Ferramentas de modelagem em alta qualidade no Blender (bpy 5.3), para modelos que serão
IMPORTADOS MANUALMENTE no Roblox Studio: corpo orgânico com Skin + Subdivision, deslocamento por
ruído, tubos afinados, placas com bevel, armadura (ossos) com pesos por distância, UV e textura
assada (bake). As mesmas ferramentas dos inimigos das Incursões.
"""

import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector, noise

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


def uv_e_bake(obj, nome, mat, dir_tex, res=1024):
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
    caminho = os.path.join(dir_tex, nome + "_cor.png")
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


