"""Gera as malhas e os estágios da família de auras Naruto (2 a 9 caudas + Modo Sábio dos Seis
Caminhos) no Blender (testado com bpy 5.3) e exporta tudo.

Uso (Blender como módulo Python):
    python assets/auras/naruto/source/generate_naruto.py            # malhas, .blend, .fbx, Luau
    python assets/auras/naruto/source/generate_naruto.py --render   # também as prévias

Saídas:
    assets/auras/naruto/source/naruto_caudas.blend    cena editável
    assets/auras/naruto/exports/<peca>.fbx            peças para o 3D Importer (opcional)
    assets/auras/naruto/previews/*.png                renders do Blender (NÃO são capturas do Roblox)
    src/client/Mundo/Auras/Dados/naruto_<peca>.luau   geometria lida pelo jogo (EditableMesh)
    src/client/Mundo/Auras/CaudasEstagios.luau        parâmetros de cada estágio (fonte única)

As caudas NÃO são esculturas fixas: cada cauda é uma corrente de 4 segmentos (base, meio, meio,
ponta) que o jogo dobra junta a junta todo quadro (ondas, velocidade, pulo, explosão). Aqui só se
modela UM jogo de segmentos; todas as caudas de todos os estágios usam os mesmos, em escalas e
cores diferentes. O render das prévias usa a mesma conta de pose do jogo (Caudas.luau) em t=0.

Escala: 1 unidade = 1 stud. Os segmentos crescem para +Z no Blender (= +Y no Roblox) a partir da
junta (origem). Conversão para o Roblox: (x, y, z) Blender -> (x, z, -y).
"""

import base64
import math
import os
import random
import struct
import sys

import bpy

import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
DIR_BASE = os.path.join(RAIZ, "assets", "auras", "naruto")
DIR_LUAU = os.path.join(RAIZ, "src", "client", "Mundo", "Auras")
DIR_DADOS = os.path.join(DIR_LUAU, "Dados")

# ---------------------------------------------------------------- estágios (fonte única)
# abertura: meia-abertura do leque (graus); elevacao/elevLados: quanto a cauda do meio / das pontas
# sobe ao sair das costas; curva: dobra por junta (para cima); onda: amplitude (rad) das ondas que
# correm pela cauda; freq: rad/s; cores em hex: fora (casca) e dentro (núcleo brilhante).
ESTAGIOS = [
    dict(id="naruto_2", nome="Modo 2 Caudas", caudas=2, abertura=55, elevacao=40, elevLados=28, curva=32, comprimento=1.0, grossura=1.52,
         fora="FF2A12", dentro="FF9A3A", transpFora=0.3, onda=0.2, freq=2.4, alterna=False, pulso=False, contracao=False, raposa=False, seis=False),
    dict(id="naruto_3", nome="Modo 3 Caudas", caudas=3, abertura=62, elevacao=48, elevLados=24, curva=32, comprimento=1.0, grossura=1.45,
         fora="FF2A12", dentro="FF9A3A", transpFora=0.3, onda=0.22, freq=2.5, alterna=False, pulso=False, contracao=False, raposa=False, seis=False),
    dict(id="naruto_4", nome="Modo 4 Caudas", caudas=4, abertura=70, elevacao=50, elevLados=18, curva=32, comprimento=1.05, grossura=1.57,
         fora="B3120A", dentro="FF4A1A", transpFora=0.22, onda=0.26, freq=2.8, alterna=False, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_5", nome="Modo 5 Caudas", caudas=5, abertura=78, elevacao=52, elevLados=14, curva=31, comprimento=1.08, grossura=1.62,
         fora="B3120A", dentro="FF4A1A", transpFora=0.22, onda=0.26, freq=2.6, alterna=False, pulso=True, contracao=True, raposa=False, seis=False),
    dict(id="naruto_6", nome="Modo 6 Caudas", caudas=6, abertura=86, elevacao=55, elevLados=10, curva=30, comprimento=1.2, grossura=1.62,
         fora="A80F08", dentro="FF3A14", transpFora=0.2, onda=0.3, freq=2.9, alterna=False, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_7", nome="Modo 7 Caudas", caudas=7, abertura=92, elevacao=58, elevLados=6, curva=30, comprimento=1.22, grossura=1.67,
         fora="A80F08", dentro="FF3A14", transpFora=0.2, onda=0.28, freq=2.7, alterna=True, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_8", nome="Modo 8 Caudas", caudas=8, abertura=98, elevacao=60, elevLados=4, curva=29, comprimento=1.28, grossura=1.81,
         fora="9E0C06", dentro="FF3A14", transpFora=0.18, onda=0.28, freq=2.6, alterna=True, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_9", nome="Modo 9 Caudas", caudas=9, abertura=104, elevacao=62, elevLados=2, curva=29, comprimento=1.32, grossura=1.86,
         fora="9E0C06", dentro="FF5A1A", transpFora=0.18, onda=0.3, freq=2.6, alterna=True, pulso=True, contracao=False, raposa=True, seis=False),
    dict(id="naruto_seis", nome="Modo Sábio dos Seis Caminhos", caudas=6, abertura=100, elevacao=42, elevLados=0, curva=25, comprimento=1.25, grossura=1.13,
         fora="FFC93A", dentro="FFF6D0", transpFora=0.35, onda=0.12, freq=1.1, alterna=False, pulso=False, contracao=False, raposa=False, seis=True),
]

# Segmentos: comprimento (studs) e quanto avança até a próxima junta (sobreposição esconde a junta)
SEGMENTOS = [("cauda_base", 2.3), ("cauda_meio1", 2.2), ("cauda_meio2", 2.0), ("cauda_ponta", 2.8)]
AVANCO = 0.82
RAIZ_CAUDAS = (0.0, -0.75, 0.55)  # no espaço do HumanoidRootPart (Roblox): parte baixa das costas


def suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- geometria


class Volume:
    def __init__(self, nome):
        self.mb = bpy.data.metaballs.new(nome)
        self.mb.resolution = 0.045
        self.mb.render_resolution = 0.045
        self.mb.threshold = 0.6
        self.obj = bpy.data.objects.new(nome + "_mb", self.mb)
        bpy.context.scene.collection.objects.link(self.obj)

    def bola(self, c, r, achatar=None):
        e = self.mb.elements.new()
        e.co = Vector(c)
        e.radius = r
        if achatar:
            e.type = "ELLIPSOID"
            e.size_x, e.size_y, e.size_z = achatar

    def malha(self):
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(self.obj.evaluated_get(dg))
        bpy.data.objects.remove(self.obj)
        bm = bmesh.new()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        return bm


def tubo_liso(bm, pts, raios, lados=12):
    """Tubo com referencial transportado (não torce) e pontas fechadas."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tang = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    normal = tang[0].orthogonal().normalized()
    aneis = []
    for i in range(n):
        t = tang[i]
        normal = (normal - t * normal.dot(t)).normalized()
        bi = t.cross(normal)
        aneis.append([bm.verts.new(pts[i] + (normal * math.cos(a) + bi * math.sin(a)) * raios[i]) for a in (2 * math.pi * j / lados for j in range(lados))])
    for i in range(n - 1):
        a0, a1 = aneis[i], aneis[i + 1]
        for j in range(lados):
            bm.faces.new((a0[j], a0[(j + 1) % lados], a1[(j + 1) % lados], a1[j]))
    inicio = bm.verts.new(pts[0] - tang[0] * raios[0] * 0.5)
    fim = bm.verts.new(pts[-1] + tang[-1] * max(raios[-1], 0.01))
    for j in range(lados):
        bm.faces.new((inicio, aneis[0][(j + 1) % lados], aneis[0][j]))
        bm.faces.new((aneis[-1][j], aneis[-1][(j + 1) % lados], fim))


def chama(bm, base, direcao, curva, comp, grossura, gancho=0.5, n=22):
    """Lambida de chakra: sai da cauda, afina até uma ponta afiada e curva."""
    d = Vector(direcao).normalized()
    c = Vector(curva).normalized()
    pts, raios = [], []
    for i in range(n):
        f = i / (n - 1)
        pts.append(Vector(base) + d * comp * f + c * comp * gancho * f * f)
        raios.append(grossura * (1 - f) ** 1.1 * (1 + 0.3 * math.sin(math.pi * f * 0.8)) + 0.004)
    tubo_liso(bm, pts, raios, lados=10)


def segmento(rng, comp, r0, r1, lambidas, ponta=False):
    """Um pedaço de cauda ao longo de +Z: corpo liso afinando + lambidas de chama na borda."""
    vol = Volume("seg")
    tubos = bmesh.new()
    n = 16
    for i in range(n):
        f = i / (n - 1)
        z = comp * f * (0.62 if ponta else 1.0)
        r = r0 + (r1 - r0) * f
        # leve ondulação: a cauda não é um cano
        vol.bola((0.05 * math.sin(f * 5 + rng.uniform(0, 1)), 0, z), r * (1 + 0.05 * math.sin(f * 9)), achatar=(1.0, 0.8, 1.0))
    if ponta:
        # ponta afiada que curva para fora (o "gancho" da chama)
        p0 = Vector((0, 0, comp * 0.55))
        pts, raios = [], []
        m = 30
        for j in range(m):
            f = j / (m - 1)
            pts.append(p0 + Vector((0.35 * comp * f * f, -0.1 * f, comp * 0.55 * f)))
            raios.append(r1 * 1.25 * (1 - f) ** 1.1 + 0.004)
        tubo_liso(tubos, pts, raios, lados=12)
    for k in range(lambidas):
        f = rng.uniform(0.2, 0.75)
        a = rng.uniform(0, 2 * math.pi)
        fora = Vector((math.cos(a), math.sin(a) * 0.6, 0)).normalized()
        r = r0 + (r1 - r0) * f
        base = Vector((0, 0, comp * f * (0.62 if ponta else 1.0))) + fora * r * 0.6
        chama(tubos, base, fora * 0.45 + Vector((0, 0, 1)), fora, rng.uniform(0.6, 0.9) * comp * 0.4, r * 0.38, gancho=0.55)
    bm = vol.malha()
    suavizar(bm, 2)
    junta(bm, tubos)
    tubos.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_raposa(rng):
    """Cabeça espectral da raposa (estágio de 9 caudas). Olha para a frente (+Y)."""
    vol = Volume("raposa")
    tubos = bmesh.new()
    vol.bola((0, 0, 0), 0.95, achatar=(1.15, 1.0, 0.9))  # crânio
    vol.bola((0, 0.75, -0.3), 0.55, achatar=(0.9, 1.4, 0.7))  # focinho
    vol.bola((0, 1.35, -0.25), 0.22)  # nariz
    vol.bola((0, 0.75, -0.75), 0.42, achatar=(1.0, 1.2, 0.5))  # mandíbula
    for lado in (1, -1):
        vol.bola((lado * 0.75, 0.35, -0.35), 0.5)  # bochechas
        # orelhas grandes, pontudas
        chama(tubos, (lado * 0.55, -0.15, 0.55), (lado * 0.45, -0.2, 1), (lado, 0, 0.2), 1.35, 0.42, gancho=0.25)
        # pelo em chama saindo das bochechas e da nuca
        for j in range(3):
            chama(tubos, (lado * (0.95 + 0.05 * j), 0.2 - 0.3 * j, -0.4 + 0.25 * j), (lado, -0.4, -0.3 + 0.35 * j), (0, -1, 0.3), 0.75 - 0.1 * j, 0.22, gancho=0.5)
        # presas
        chama(tubos, (lado * 0.28, 1.05, -0.55), (0, 0.15, -1), (0, 1, 0), 0.32, 0.07, gancho=0.2)
        # sobrancelha brava
        chama(tubos, (lado * 0.2, 0.75, 0.32), (lado, 0.1, 0.35), (0, 0, 1), 0.65, 0.12, gancho=0.3)
    bm = vol.malha()
    suavizar(bm, 2)
    junta(bm, tubos)
    tubos.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_olhos(rng):
    """Os dois olhos luminosos da raposa (peça separada, brilho próprio)."""
    vol = Volume("olhos")
    for lado in (1, -1):
        for j in range(5):  # olho alongado e inclinado (bravo)
            f = j / 4
            vol.bola((lado * (0.3 + 0.28 * f), 0.86 - 0.05 * f, 0.18 + 0.12 * f), 0.11)
    bm = vol.malha()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_anel(rng):
    """Anel fino (chão dos estágios finais e halo dos Seis Caminhos). Raio 1, no plano XY."""
    bm = bmesh.new()
    n = 96
    pts = [Vector((math.cos(2 * math.pi * i / n), math.sin(2 * math.pi * i / n), 0)) for i in range(n + 1)]
    tubo_liso(bm, pts, [0.03] * (n + 1), lados=8)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def suavizar(bm, passos, fator=0.5):
    for _ in range(passos):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=fator, use_axis_x=True, use_axis_y=True, use_axis_z=True)


def junta(destino, origem):
    me = bpy.data.meshes.new("tmp")
    origem.to_mesh(me)
    destino.from_mesh(me)
    bpy.data.meshes.remove(me)


def reduzir(bm, alvo):
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    obj = bpy.data.objects.new("tmp", me)
    bpy.context.scene.collection.objects.link(obj)
    if len(me.polygons) > alvo:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = alvo / len(me.polygons)
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        obj.data = me2
        bpy.data.meshes.remove(me)
        me = me2
    bm2 = bmesh.new()
    bm2.from_mesh(me)
    bmesh.ops.triangulate(bm2, faces=bm2.faces)
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    return bm2


# ---------------------------------------------------------------- exportação


def para_roblox(co):
    return (co.x, co.z, -co.y)


def escrever_luau(nome, bm):
    bm.verts.ensure_lookup_table()
    pos = [para_roblox(v.co) for v in bm.verts]
    tris = [tuple(v.index for v in f.verts) for f in bm.faces]
    assert len(pos) < 65536, nome
    minimo = [min(p[i] for p in pos) for i in range(3)]
    maximo = [max(p[i] for p in pos) for i in range(3)]
    tamanho = [max(maximo[i] - minimo[i], 1e-4) for i in range(3)]
    dados = bytearray()
    for p in pos:
        dados += struct.pack("<3H", *(int(round((p[i] - minimo[i]) / tamanho[i] * 65535)) for i in range(3)))
    for _ in pos:  # cor por vértice branca: a cor vem da parte (Neon)
        dados += struct.pack("<3B", 255, 255, 255)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    pedacos = [texto[i : i + 4000] for i in range(0, len(texto), 4000)]
    linhas = [
        "-- GERADO por assets/auras/naruto/source/generate_naruto.py. Não editar à mão.",
        "-- Peça das auras Naruto: posições (uint16), cores (uint8) e triângulos (uint16) em base64.",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ]
    linhas += ['\t\t"%s",' % p for p in pedacos]
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, "naruto_" + nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(pos), len(tris)


def luau_valor(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return "%g" % v
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (tuple, list)):
        return "{ " + ", ".join(luau_valor(x) for x in v) + " }"
    raise TypeError(v)


def escrever_estagios():
    linhas = [
        "-- GERADO por assets/auras/naruto/source/generate_naruto.py. Não editar à mão.",
        "-- Família Naruto: um estágio por aura. Ângulos em graus (exceto onda, em radianos).",
        "return {",
        "\tsegmentos = {",
    ]
    for nome, comp in SEGMENTOS:
        linhas.append('\t\t{ malha = "naruto_%s", comprimento = %g },' % (nome, comp))
    linhas += ["\t},", "\tavanco = %g," % AVANCO, "\traiz = %s," % luau_valor(RAIZ_CAUDAS), "\testagios = {"]
    for e in ESTAGIOS:
        linhas.append("\t\t%s = { %s }," % (e["id"], ", ".join("%s = %s" % (k, luau_valor(v)) for k, v in e.items() if k != "id")))
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_LUAU, "CaudasEstagios.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def objeto(nome, bm):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new("naruto_" + nome, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


PECAS = [
    ("cauda_base", lambda r: segmento(r, 2.3, 0.62, 0.72, 1), 2600),
    ("cauda_meio1", lambda r: segmento(r, 2.2, 0.72, 0.6, 1), 2400),
    ("cauda_meio2", lambda r: segmento(r, 2.0, 0.6, 0.42, 0), 2000),
    ("cauda_ponta", lambda r: segmento(r, 2.8, 0.42, 0.3, 0, ponta=True), 2000),
    ("raposa", fazer_raposa, 6000),
    ("olhos", fazer_olhos, 600),
    ("anel", fazer_anel, 2000),
]


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(DIR_DADOS, exist_ok=True)
    for antigo in os.listdir(DIR_DADOS):
        if antigo.startswith("naruto_"):
            os.remove(os.path.join(DIR_DADOS, antigo))
    for pasta in ("exports", "previews"):
        d = os.path.join(DIR_BASE, pasta)
        os.makedirs(d, exist_ok=True)
        for antigo in os.listdir(d):
            os.remove(os.path.join(d, antigo))
    objs = {}
    for i, (nome, fn, alvo) in enumerate(PECAS):
        bm = fn(random.Random(900 + i))
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.003)
        bm = reduzir(bm, alvo)
        nv, nt = escrever_luau(nome, bm)
        print("%-12s %5d vértices %5d triângulos" % (nome, nv, nt))
        objs[nome] = objeto(nome, bm)
    escrever_estagios()
    for obj in objs.values():
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(filepath=os.path.join(DIR_BASE, "exports", obj.name + ".fbx"), use_selection=True, axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_UNITS")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "naruto_caudas.blend"), compress=True)
    return objs


# ---------------------------------------------------------------- pose (mesma conta de Caudas.luau)

R = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))  # Blender -> Roblox
R_INV = R.inverted()


def rx(a):
    return Matrix.Rotation(a, 4, "X")


def ry(a):
    return Matrix.Rotation(a, 4, "Y")


def rz(a):
    return Matrix.Rotation(a, 4, "Z")


def tr(x, y, z):
    return Matrix.Translation((x, y, z))


def pose_caudas(e, t=0.0, mov=0.0, fases=None):
    """Lista de (cauda, segmento, CFrame em espaço do HumanoidRootPart, Roblox) — igual ao jogo."""
    n = e["caudas"]
    raiz = tr(*RAIZ_CAUDAS)
    saida = []
    for i in range(n):
        u = (i / (n - 1)) * 2 - 1 if n > 1 else 0.0
        fase = fases[i] if fases else i * 1.7
        if e["alterna"] and i % 2 == 1:
            fase += math.pi
        phi = math.radians(e["abertura"]) * u * (1 - 0.45 * mov)
        elev = math.radians(e["elevacao"] + (e["elevLados"] - e["elevacao"]) * abs(u)) * (1 - 0.55 * mov)
        cf = raiz @ ry(phi) @ rx(math.pi / 2 - elev)
        for k, (nome, comp) in enumerate(SEGMENTOS):
            onda = e["onda"] * (1 + 0.8 * mov) * math.sin(e["freq"] * t - k * 0.9 + fase)
            lado = e["onda"] * 0.6 * math.sin(e["freq"] * 0.7 * t - k * 0.7 + fase * 1.3) - u * math.radians(12)
            dobra = math.radians(e["curva"]) * (1 - 0.6 * mov) + onda
            if k > 0:
                cf = cf @ rx(-dobra) @ rz(lado)
            saida.append((i, nome, cf))
            cf = cf @ tr(0, comp * e["comprimento"] * AVANCO, 0)
    return saida


# ---------------------------------------------------------------- prévias


def material_chakra(nome, cor_hex, forca, alfa):
    cor = tuple(int(cor_hex[i : i + 2], 16) / 255 for i in (0, 2, 4))
    cor = tuple(c ** 2.2 for c in cor)
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*cor, 1)
    em.inputs["Strength"].default_value = forca
    tr_ = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = alfa
    nt.links.new(tr_.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def caixa(nome, centro, tam, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2])) + Vector(centro)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    obj = bpy.data.objects.new(nome, me)
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def instancia(fonte, matriz_rbx, escala, mat, colecao):
    obj = bpy.data.objects.new(fonte.name + "_i", fonte.data.copy())
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.matrix_world = tr(0, 0, 3) @ R_INV @ matriz_rbx @ R @ Matrix.Diagonal((escala[0], escala[1], escala[2], 1))
    colecao.objects.link(obj)
    return obj


def renderizar(objs):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 40
    cena.cycles.device = "CPU"
    cena.render.resolution_x = 560
    cena.render.resolution_y = 640
    cena.view_settings.view_transform = "AgX"
    cena.view_settings.look = "AgX - Punchy"
    mundo = bpy.data.worlds.new("w")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.008, 0.006, 0.01, 1)
    cena.world = mundo
    for o in objs.values():
        o.hide_render = True
    avatar_m = material_cor((0.09, 0.09, 0.1))
    for nome, c, t in (("pe", (-0.5, 0, 1), (0.9, 0.9, 2)), ("pd", (0.5, 0, 1), (0.9, 0.9, 2)), ("tr", (0, 0, 3), (2, 1, 2)),
                       ("be", (-1.5, 0, 3), (0.95, 0.95, 2)), ("bd", (1.5, 0, 3), (0.95, 0.95, 2)), ("ca", (0, 0, 4.6), (1.2, 1.2, 1.2))):
        caixa(nome, c, t, avatar_m)
    caixa("chao", (0, 0, -0.05), (40, 40, 0.1), material_cor((0.02, 0.02, 0.025)))
    cam = bpy.data.cameras.new("cam")
    cam.lens = 42
    oc = bpy.data.objects.new("cam", cam)
    cena.collection.objects.link(oc)
    cena.camera = oc
    oc.location = (0, 24, 5.2)
    oc.rotation_euler = (Vector((0, 0, 4.6)) - oc.location).to_track_quat("-Z", "Y").to_euler()
    luz = bpy.data.lights.new("aro", "AREA")
    luz.energy = 300
    luz.size = 8
    ol = bpy.data.objects.new("aro", luz)
    ol.location = (0, 8, 9)
    ol.rotation_euler = (Vector((0, 0, 4)) - ol.location).to_track_quat("-Z", "Y").to_euler()
    cena.collection.objects.link(ol)
    for e in ESTAGIOS:
        if e["id"] not in ("naruto_2", "naruto_4", "naruto_6", "naruto_9", "naruto_seis"):
            continue
        col = bpy.data.collections.new(e["id"])
        cena.collection.children.link(col)
        fora = material_chakra("fora_" + e["id"], e["fora"], 3.0, 1 - e["transpFora"])
        dentro = material_chakra("dentro_" + e["id"], e["dentro"], 5.0, 0.55)
        g, c = e["grossura"], e["comprimento"]
        for i, nome, cf in pose_caudas(e):
            instancia(objs[nome], cf, (g, c, g), fora, col)
            instancia(objs[nome], cf, (g * 0.5, c * 0.96, g * 0.5), dentro, col)
        if e["raposa"]:
            m = tr(0, 3.4, 2.6) @ Matrix.Diagonal((3.0, 3.0, 3.0, 1))
            instancia(objs["raposa"], m, (1, 1, 1), material_chakra("rap", e["fora"], 2.5, 0.5), col)
            instancia(objs["olhos"], m, (1, 1, 1), material_chakra("olh", "FFE14A", 12, 1), col)
        if e["raposa"] or e["seis"]:
            chao = tr(0, -2.95, 0) @ Matrix.Diagonal((3.2, 3.2, 3.2, 1))
            instancia(objs["anel"], chao, (1, 1, 1), material_chakra("anel_" + e["id"], e["fora"], 8, 1), col)
        if e["seis"]:
            halo = tr(0, 2.6, 1.6) @ rx(math.pi / 2) @ Matrix.Diagonal((3.6, 3.6, 3.6, 1))
            instancia(objs["anel"], halo, (1, 1, 1), material_chakra("halo", e["fora"], 6, 0.8), col)
            preto = material_esfera()
            for k in range(9):
                a = 2 * math.pi * k / 9
                bpy.ops.mesh.primitive_uv_sphere_add(radius=0.48, location=(math.cos(a) * 3.6, -1.6, 3 + 2.6 + math.sin(a) * 3.6))
                esf = bpy.context.active_object
                esf.data.materials.append(preto)
                for colx in esf.users_collection:
                    colx.objects.unlink(esf)
                col.objects.link(esf)
        for outra in bpy.data.collections:
            outra.hide_render = outra.name != e["id"]
        cena.render.filepath = os.path.join(DIR_BASE, "previews", e["id"] + ".png")
        bpy.ops.render.render(write_still=True)
        print("prévia", e["id"])


def material_esfera():
    """Esfera negra com borda levemente iluminada (senão some no fundo escuro)."""
    m = bpy.data.materials.new("esfera")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.01, 0.01, 0.012, 1)
    b.inputs["Roughness"].default_value = 0.25
    b.inputs["Coat Weight"].default_value = 1.0
    return m


def material_cor(cor):
    m = bpy.data.materials.new("cor")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    b.inputs["Roughness"].default_value = 0.7
    return m


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
