"""Gera as peças da aura Senbonzakura — Jardim de Mil Lâminas (testado com bpy 5.3).

Pipeline v2 (docs: DESPERTAR_PADRAO_PIPELINE_BLENDER_STUDIO_ROJO_ASSETS_3D):
    Blender (este script) -> FBX -> Roblox Studio (3D Importer + upload) -> Senbonzakura.rbxm
    -> Rojo (ReplicatedStorage/AuraAssets) -> Senbonzakura.luau clona os MeshParts e anima.
Nada de geometria em Dados/*.luau nem EditableMesh para esta aura.

Uso (Blender como módulo Python):
    python assets/auras/senbonzakura/source/generate_senbonzakura.py            # .blend, .fbx, manifesto, Luau
    python assets/auras/senbonzakura/source/generate_senbonzakura.py --render   # também as prévias

Saídas:
    assets/auras/senbonzakura/source/senbonzakura.blend    cena editável (peças + dummy de referência)
    assets/auras/senbonzakura/source/senbon_lamina.png     textura compartilhada (degradê das lâminas)
    assets/auras/senbonzakura/exports/<peca>.fbx            uma peça por arquivo, para o 3D Importer
    assets/auras/senbonzakura/manifest.json                 nomes, tamanhos, pivôs, triângulos, status
    assets/auras/senbonzakura/previews/*.png                renders do Blender (NÃO são capturas do Roblox)
    src/client/Mundo/Auras/SenbonzakuraPecas.luau           tamanhos/pivôs + órbitas e coreografia

Escala: 1 unidade = 1 stud. Avatar R15 padrão: chão em z=0, HumanoidRootPart em z=3, olhando para +Y.
Eixos: Blender (x, y, z) -> Roblox (x, z, -y). Cada peça tem o próprio pivô na origem:
    pétalas e clusters: centro de massa / ponto de controle; o fio aponta para +Y (Roblox: LookVector)
    lanças: pivô na base, lâmina subindo em +Z (Roblox: UpVector)
    arcos e selo: pivô no centro do círculo, deitados no plano XY (Roblox: plano horizontal)
Semente fixa: duas execuções geram exatamente as mesmas peças.
"""

import json
import math
import os
import random
import sys

import bpy

import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
DIR_BASE = os.path.join(RAIZ, "assets", "auras", "senbonzakura")
DIR_LUAU = os.path.join(RAIZ, "src", "client", "Mundo", "Auras")
TEXTURA = os.path.join(DIR_BASE, "source", "senbon_lamina.png")
REVISAO = 1


def hexcor(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


# Paleta (tabela 1.3 do briefing)
SOMBRA = hexcor("160B23")
VIOLETA = hexcor("4F1C66")
MAGENTA = hexcor("CF338F")
SAKURA = hexcor("F36BC7")
LUMINOSO = hexcor("FF9BDF")
BRANCO = hexcor("FFE5F8")


def mistura(a, b, t):
    t = min(max(t, 0.0), 1.0)
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def suave(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- textura compartilhada


def cor_lamina(s, t):
    """Cor da textura no ponto (s, t). s: metade esquerda = face, direita = verso;
    dentro da metade, 0..1 atravessa a lâmina (0,5 = dobra). t: 0 = base, 1 = ponta."""
    verso = s >= 0.5
    lado = abs(((s - 0.5 if verso else s) * 2) * 2 - 1)  # 0 na dobra, 1 no fio
    c = mistura(VIOLETA, SAKURA, suave(0.0, 0.5, t))
    c = mistura(c, MAGENTA, 0.35 * suave(0.2, 0.0, lado))  # dobra um pouco mais funda
    c = mistura(c, LUMINOSO, suave(0.62, 0.86, lado) * suave(0.25, 0.75, t))  # bisel claro
    c = mistura(c, BRANCO, suave(0.8, 0.93, lado) * suave(0.78, 0.97, t))  # reflexo só perto da ponta
    c = mistura(c, SOMBRA, suave(0.93, 1.0, lado) * 0.85)  # fio escuro separa as lâminas
    if verso:
        c = mistura(c, VIOLETA, 0.55)
    return c


def gerar_textura():
    n = 256
    img = bpy.data.images.new("senbon_lamina", n, n, alpha=False)
    px = []
    for j in range(n):
        for i in range(n):
            c = cor_lamina((i + 0.5) / n, (j + 0.5) / n)
            px.extend((c[0], c[1], c[2], 1.0))
    img.pixels.foreach_set(px)
    img.filepath_raw = TEXTURA
    img.file_format = "PNG"
    img.save()
    return img


# ---------------------------------------------------------------- geometria


class Malha:
    """Acumula vértices/faces com UV e cor por canto; vira um objeto no final."""

    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.cor = self.bm.loops.layers.float_color.new("Col")

    def face(self, vs, uvs, cores):
        if len({v.index if v.index >= 0 else id(v) for v in vs}) < 3:
            return
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return
        for loop, uv, c in zip(f.loops, uvs, cores):
            loop[self.uv].uv = uv
            loop[self.cor] = (*c, 1.0)

    def limpar(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.dissolve_degenerate(self.bm, edges=self.bm.edges, dist=1e-6)
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)


def lamina(m, perfil, comprimento, espessura, transform, entalhe=0.0, linhas=6, torcao=0.0, curva=0.0, lateral=0.0, verso_fino=0.6):
    """Lâmina fechada com dobra longitudinal: seção em losango (face com 2 facetas, verso mais fino).

    perfil(u) -> meia-largura (u: 0 = base, 1 = ponta). entalhe recua o centro da ponta
    (ponta dupla de pétala de sakura). A lâmina vai de y = -0,45 L a +0,55 L (pivô ~ centro de massa)."""
    colunas = (-1.0, -0.5, 0.0, 0.5, 1.0)
    anel = []
    for k in range(linhas + 1):
        u = k / linhas
        w = perfil(u)
        t = espessura * (u ** 0.35) * max(0.0, 1 - u ** 3) ** 0.6
        topo = []
        fundo = []
        for v in colunas:
            y = (u - 0.45) * comprimento - entalhe * comprimento * (1 - abs(v)) * u ** 5
            z = t * 0.5 * (1 - abs(v))
            topo.append((v * w, y, z, v, u))
            if abs(v) < 1:
                fundo.append((v * w, y, -z * verso_fino, v, u))
        anel.append((topo, list(reversed(fundo))))
    verts = []
    for topo, fundo in anel:
        linha = []
        for x, y, z, v, u in topo:
            linha.append((x, y, z, v, u, False))
        for x, y, z, v, u in fundo:
            linha.append((x, y, z, v, u, True))
        verts.append(linha)

    def deformar(x, y, z, u):
        a = torcao * (u - 0.5)
        ca, sa = math.cos(a), math.sin(a)
        x, z = x * ca - z * sa, x * sa + z * ca
        z += curva * comprimento * (u - 0.5) ** 2 * 4 - curva * comprimento * 0.25
        x += lateral * comprimento * u * u
        return transform @ Vector((x, y, z))

    bverts = []
    for linha in verts:
        bl = []
        for x, y, z, v, u, verso in linha:
            bl.append((m.bm.verts.new(deformar(x, y, z, u)), v, u, verso))
        bverts.append(bl)

    def uvcor(item, lado_verso):
        _, v, u, _ = item
        s = (v + 1) / 4 + (0.5 if lado_verso else 0.0)
        s = min(max(s, 0.002), 0.998)
        return (s, min(max(u, 0.002), 0.998)), cor_lamina(s, u)

    n = len(bverts[0])
    for k in range(linhas):
        a, b = bverts[k], bverts[k + 1]
        for i in range(n):
            j = (i + 1) % n
            quad = [a[i], a[j], b[j], b[i]]
            # o fio (coluna 0 e 4) é compartilhado entre face e verso: UV do lado certo
            lado_verso = any(q[3] for q in quad)
            uvs, cores = zip(*(uvcor(q, lado_verso) for q in quad))
            m.face([q[0] for q in quad], uvs, cores)


def petala(m, forma, escala, transform, rng=None):
    """forma 'a': pétala-lâmina com ponta dupla (entalhe); 'b': mais comprida e estreita, ponta única."""
    rng = rng or random.Random(0)
    if forma == "a":
        larg = 0.105 * escala
        perfil = lambda u: larg * (u ** 0.55) * (1 - u ** 2.6) ** 0.55 + larg * 0.42 * u ** 7  # noqa: E731
        lamina(m, perfil, 0.5 * escala, 0.04 * escala, transform, entalhe=0.13, linhas=5, torcao=rng.uniform(0.25, 0.6) * rng.choice((-1, 1)), curva=0.05)
    else:
        larg = 0.07 * escala
        perfil = lambda u: larg * (u ** 0.6) * (1 - u ** 1.7) ** 0.7  # noqa: E731
        lamina(m, perfil, 0.68 * escala, 0.032 * escala, transform, linhas=5, torcao=rng.uniform(0.3, 0.7) * rng.choice((-1, 1)), curva=0.07, lateral=rng.uniform(-0.05, 0.05))


def orientacao(frente, rolar, guinar=0.0, arfar=0.0):
    """Matriz que leva +Y para 'frente' e gira a lâmina em torno do próprio fio."""
    f = Vector(frente).normalized()
    cima = Vector((0, 0, 1)) if abs(f.z) < 0.95 else Vector((1, 0, 0))
    x = f.cross(cima).normalized()
    z = x.cross(f).normalized()
    base = Matrix((x, f, z)).transposed()
    return base @ Matrix.Rotation(arfar, 3, "X") @ Matrix.Rotation(guinar, 3, "Z") @ Matrix.Rotation(rolar, 3, "Y")


def cluster(m, rng, n, comprimento, largura, altura, curva, espiral=0.0):
    """Enxame de n pétalas num volume curvo (não é cartão plano): cada pétala aponta na tangente
    do fluxo (+Y); 30% mostram o perfil, 30% a face, o resto fica no meio-termo. Mantém vazios."""
    postos = []
    tentativas = 0
    while len(postos) < n and tentativas < 4000:
        tentativas += 1
        s = rng.uniform(-0.5, 0.5)
        if espiral:
            ang = s * espiral
            raio = largura * (0.55 + 0.45 * (s + 0.5))
            p = Vector((math.cos(ang) * raio - raio, s * comprimento, math.sin(ang) * raio * 0.8 + s * altura))
        else:
            p = Vector((rng.gauss(0, largura * 0.42) + curva * (s * s * 4 - 1) * 0.5, s * comprimento, rng.gauss(0, altura * 0.42)))
        if any((p - q).length < 0.26 for q, _ in postos):
            continue
        postos.append((p, s))
    familias = (0.8, 1.1, 1.3, 1.3, 1.55, 1.75)
    for i, (p, s) in enumerate(postos):
        # tangente do fluxo naquele ponto (derivada da curva)
        if espiral:
            frente = Vector((-math.sin(s * espiral) * espiral * 0.3, comprimento, math.cos(s * espiral) * espiral * 0.25 + altura))
        else:
            frente = Vector((curva * s * 4 * 0.5, comprimento, 0))
        sorteio = rng.random()
        rolar = math.pi / 2 if sorteio < 0.3 else (0.0 if sorteio < 0.6 else rng.uniform(0.35, 1.2))
        rolar *= rng.choice((-1, 1))
        rot = orientacao(frente, rolar, rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25))
        t = Matrix.Translation(p) @ rot.to_4x4()
        petala(m, "a" if i % 3 != 2 else "b", familias[rng.randrange(len(familias))], t, rng)
    return len(postos)


def lanca(m, comprimento, largura, espessura, arco=0.0, inclinar=0.0):
    """Lâmina vertical facetada com ponta em chanfro assimétrico; base reta (pivô) no chão."""
    linhas = 7

    def perfil(u):
        return largura * (0.75 + 0.25 * suave(0.0, 0.25, u)) * (1 - suave(0.72, 1.0, u)) ** 0.8

    rot = Matrix.Rotation(math.pi / 2, 4, "X")  # +Y da lâmina vira +Z (para cima)
    m0 = len(m.bm.verts)
    lamina(m, perfil, comprimento, espessura, Matrix.Identity(4), linhas=linhas, curva=0.0)
    novos = list(m.bm.verts)[m0:]
    for v in novos:
        co = v.co.copy()
        u = (co.y / comprimento) + 0.45
        co.y += 0.45 * comprimento
        # chanfro: um fio sobe mais que o outro perto da ponta
        co.y += 0.12 * comprimento * suave(0.7, 1.0, u) * (co.x / max(largura, 1e-6))
        co.x += arco * comprimento * u * u
        v.co = (Matrix.Rotation(inclinar, 4, "Y") @ rot) @ co


def fita(m, fragmentos, espessura, linhas_por_rad=7.0):
    """Arcos quebrados: cada fragmento é uma lâmina curva (seção em losango) em volta do pivô."""
    for th0, th1, raio, z0, sobe, largura in fragmentos:
        linhas = max(4, int(abs(th1 - th0) * linhas_por_rad))

        def perfil(u, largura=largura):
            return largura * math.sin(math.pi * min(max(u, 0.0), 1.0)) ** 0.7

        m0 = len(m.bm.verts)
        lamina(m, perfil, 1.0, espessura, Matrix.Identity(4), linhas=linhas)
        for v in list(m.bm.verts)[m0:]:
            u = v.co.y + 0.45
            ang = th0 + (th1 - th0) * u
            r = raio + v.co.x
            v.co = Vector((math.cos(ang) * r, math.sin(ang) * r, z0 + sobe * (u - 0.5) + v.co.z))


def selo(m, rng):
    """Selo de chão: 4 segmentos de anel (com vazios) + 5 marcas de pétala apontando para fora."""
    frags = []
    for k in range(4):
        a = k * math.pi / 2 + 0.2
        frags.append((a, a + rng.uniform(1.0, 1.25), 3.1, 0.0, 0.0, 0.07))
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.9
        frags.append((a, a + 0.8, 2.72, 0.0, 0.0, 0.035))
    fita(m, frags, 0.03, 9.0)
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.35
        p = Vector((math.cos(a) * 3.45, math.sin(a) * 3.45, 0.0))
        rot = orientacao(Vector((math.cos(a), math.sin(a), 0)), 0.0)
        petala(m, "a", 0.75, Matrix.Translation(p) @ rot.to_4x4(), rng)


# ---------------------------------------------------------------- peças

PECAS = []  # (nome, função construtora)


def peca(nome):
    def reg(fn):
        PECAS.append((nome, fn))
        return fn

    return reg


@peca("senbon_petal_a")
def _(m, rng):
    petala(m, "a", 1.4, Matrix.Identity(4), rng)  # destaque ocasional maior (0,7 stud)


@peca("senbon_petal_b")
def _(m, rng):
    petala(m, "b", 1.1, Matrix.Identity(4), rng)


@peca("senbon_cluster_a")
def _(m, rng):
    return cluster(m, rng, 16, 2.1, 0.75, 0.65, 0.3)


@peca("senbon_cluster_b")
def _(m, rng):
    return cluster(m, rng, 15, 2.4, 0.55, 0.8, -0.35)


@peca("senbon_cluster_c")
def _(m, rng):
    return cluster(m, rng, 11, 1.9, 0.6, 0.7, 0.0, espiral=2.6)


@peca("senbon_lance_a")
def _(m, rng):
    lanca(m, 2.6, 0.2, 0.08)


@peca("senbon_lance_b")
def _(m, rng):
    lanca(m, 3.0, 0.16, 0.07, arco=0.1, inclinar=0.12)


@peca("senbon_arco_a")
def _(m, rng):
    fita(m, [(0.0, 0.62, 3.0, 0.0, 0.25, 0.15), (0.86, 1.18, 3.05, 0.12, 0.1, 0.1), (1.42, 1.62, 2.95, 0.2, 0.05, 0.07)], 0.05)


@peca("senbon_arco_b")
def _(m, rng):
    fita(m, [(0.0, 0.85, 2.6, 0.0, -0.35, 0.18), (1.12, 1.48, 2.7, -0.22, -0.12, 0.12)], 0.07)


@peca("senbon_selo")
def _(m, rng):
    selo(m, rng)


# ---------------------------------------------------------------- coreografia (vai para o Luau)
# Coordenadas Roblox relativas ao HumanoidRootPart (frente = -Z). Ângulo 0 = direita (+X);
# -pi/2 = frente. Ver seções 4 e 5 do briefing.

ORBITAS = [
    # template, rx, rz, altura, ângulo inicial, vel (rad/s), inclinação, escala, rigidez, atraso, giro (graus)
    ("senbon_cluster_a", 2.9, 2.6, 0.35, 0.3, 0.42, 0.28, 1.0, 46, 0.55, 12),
    ("senbon_cluster_b", 3.3, 2.9, 1.0, 2.4, 0.36, -0.35, 1.0, 38, 0.7, 9),
    ("senbon_cluster_c", 2.7, 2.4, 1.65, 4.2, 0.55, 0.22, 0.9, 58, 0.45, 15),
    ("senbon_cluster_a", 3.5, 3.1, -0.5, 3.6, -0.3, 0.45, 1.15, 30, 0.85, 8),
    ("senbon_cluster_b", 3.0, 2.7, 0.2, 5.4, 0.48, -0.2, 0.85, 50, 0.6, 14),
    ("senbon_cluster_c", 3.6, 3.2, 2.0, 1.2, -0.27, 0.3, 1.1, 26, 0.9, 10),
    ("senbon_cluster_a", 2.6, 2.3, -0.95, 0.9, 0.6, 0.15, 0.75, 64, 0.4, 18),
]
QUALIDADE_BAIXA = 5  # só as 5 primeiras órbitas
DETALHE_MEDIO = 4  # 80–140 studs: só as 4 primeiras

# lanças do pico/manifestação: ângulo em graus a partir da FRENTE (0 = frente, 180 = costas)
LANCAS = [
    (180, 2.9, 1.15), (150, 3.2, 1.0), (-150, 3.1, 1.05), (120, 2.8, 0.9), (-120, 2.9, 0.95),
    (95, 3.4, 0.8), (-95, 3.3, 0.85), (165, 3.7, 0.75), (-165, 3.6, 0.9),
]


# ---------------------------------------------------------------- saída


def para_roblox(v):
    return (v[0], v[2], -v[1])


def material_lamina(img):
    m = bpy.data.materials.new("senbon_lamina")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Metallic"].default_value = 0.35
    b.inputs["Roughness"].default_value = 0.35
    return m


def objeto(nome, m, mat):
    me = bpy.data.meshes.new(nome)
    m.bm.to_mesh(me)
    for p in me.polygons:
        p.use_smooth = False  # facetas: cada face reflete a luz de um jeito
    me.materials.append(mat)
    obj = bpy.data.objects.new(nome, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def lua_num(x):
    return ("%.4f" % x).rstrip("0").rstrip(".") if abs(x) > 5e-5 else "0"


def lua_vec(v):
    return "Vector3.new(%s, %s, %s)" % tuple(lua_num(c) for c in v)


def escrever_pecas(info):
    linhas = [
        "-- GERADO por assets/auras/senbonzakura/source/generate_senbonzakura.py — edite lá e rode de novo.",
        "-- Templates (MeshParts importados no Studio) e a coreografia da Senbonzakura.",
        "-- tamanho: caixa da malha em studs (eixos Roblox); centro: do pivô até o centro da caixa.",
        "-- Órbitas relativas ao HumanoidRootPart (frente = -Z); ângulo 0 = direita, -pi/2 = frente.",
        "local Pecas = {}",
        "",
        "Pecas.REVISAO = %d" % REVISAO,
        "",
        "Pecas.TEMPLATES = {",
    ]
    for nome, d in info.items():
        linhas.append("\t%s = { tamanho = %s, centro = %s }," % (nome, lua_vec(d["tamanhoRoblox"]), lua_vec(d["centroRoblox"])))
    linhas += ["}", "", "Pecas.ORBITAS = {"]
    for t, rx, rz, alt, a0, w, inc, esc, k, atraso, giro in ORBITAS:
        linhas.append(
            '\t{ template = "%s", rx = %s, rz = %s, altura = %s, angulo = %s, vel = %s, inclinacao = %s, escala = %s, rigidez = %s, atraso = %s, giro = %s },'
            % (t, *(lua_num(x) for x in (rx, rz, alt, a0, w, inc, esc, k, atraso, giro)))
        )
    linhas += ["}", "Pecas.ORBITAS_BAIXA = %d" % QUALIDADE_BAIXA, "Pecas.ORBITAS_MEDIO = %d" % DETALHE_MEDIO, "", "Pecas.LANCAS = {"]
    for i, (graus, raio, alt) in enumerate(LANCAS):
        t = "senbon_lance_a" if i % 2 == 0 else "senbon_lance_b"
        linhas.append('\t{ template = "%s", graus = %d, raio = %s, altura = %s },' % (t, graus, lua_num(raio), lua_num(alt)))
    linhas += [
        "}",
        "",
        "-- Parâmetros da tabela 5.2 do briefing (ajustáveis em playtest)",
        "Pecas.PARAMETROS = {",
        "\trespiracao = 0.05, -- fração do raio (3%–7%)",
        "\tperiodoRespiracao = 6, -- s (4–8)",
        "\tbalanco = 0.16, -- studs de sobe/desce (0,08–0,28)",
        "\tintervaloPico = { 12, 20 }, -- s",
        "\tduracaoPico = 1.8, -- s (1,5–2,0)",
        "\tduracaoManifestar = 1.55, -- s (1,3–1,7)",
        "\tduracaoSaida = 0.28, -- s (0,22–0,35)",
        "\tlodDetalhe = 80,",
        "\tlodOculto = 140,",
        "}",
        "",
        "return Pecas",
        "",
    ]
    with open(os.path.join(DIR_LUAU, "SenbonzakuraPecas.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def escrever_manifesto(info):
    dados = {
        "auraId": "senbonzakura",
        "nome": "Senbonzakura — Jardim de Mil Lâminas",
        "source": "assets/auras/senbonzakura/source/senbonzakura.blend",
        "generator": "assets/auras/senbonzakura/source/generate_senbonzakura.py",
        "texture": "assets/auras/senbonzakura/exports/senbon_lamina.png",
        "runtimeTemplate": "ReplicatedStorage/AuraAssets/Senbonzakura",
        "templateFile": "assets/roblox/AuraAssets/Senbonzakura.rbxm",
        "status": "AWAITING_STUDIO_IMPORT",
        "creatorType": "group_or_user_to_fill",
        "creatorId": None,
        "revision": REVISAO,
        "units": "1 Blender unit = 1 stud; FBX exported with axis_forward=-Z, axis_up=Y",
        "axes": "Blender (x, y, z) -> Roblox (x, z, -y); sizes/centers below already in Roblox axes",
        "triangleTotal": sum(d["triangulos"] for d in info.values()),
        "pieces": [
            {
                "name": nome,
                "role": d["papel"],
                "triangles": d["triangulos"],
                "petals": d.get("petalas"),
                "sizeStuds": [round(c, 4) for c in d["tamanhoRoblox"]],
                "pivot": d["pivo"],
                "centerFromPivot": [round(c, 4) for c in d["centroRoblox"]],
                "materialSuggestion": d["material"],
                "meshId": None,
                "textureId": None,
            }
            for nome, d in info.items()
        ],
    }
    with open(os.path.join(DIR_BASE, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(dados, f, ensure_ascii=False, indent=2)
        f.write("\n")


PAPEIS = {
    "senbon_petal_a": ("pétala-lâmina de destaque (ponta dupla); também solta/rastro", "centro de massa; fio para +Y (LookVector)", "SmoothPlastic + textura"),
    "senbon_petal_b": ("variação comprida e estreita; quebra repetição", "centro de massa; fio para +Y (LookVector)", "SmoothPlastic + textura"),
    "senbon_cluster_a": ("enxame principal (16 pétalas)", "ponto de controle do enxame; fluxo para +Y", "SmoothPlastic + textura"),
    "senbon_cluster_b": ("enxame alongado (15 pétalas)", "ponto de controle do enxame; fluxo para +Y", "SmoothPlastic + textura"),
    "senbon_cluster_c": ("espiral assimétrica (11 pétalas)", "ponto de controle do enxame; fluxo para +Y", "SmoothPlastic + textura"),
    "senbon_lance_a": ("lança vertical do pico/manifestação", "base da lâmina (no chão); sobe em +Y Roblox", "Neon #FF9BDF"),
    "senbon_lance_b": ("lança arqueada/inclinada do pico", "base da lâmina (no chão); sobe em +Y Roblox", "Neon #FF9BDF"),
    "senbon_arco_a": ("traços de corte quebrados (3 fragmentos)", "centro do círculo (raio ~3)", "Neon #CF338F"),
    "senbon_arco_b": ("traços cruzados (2 fragmentos)", "centro do círculo (raio ~2,6)", "Neon #CF338F"),
    "senbon_selo": ("selo de chão quebrado (opcional)", "centro do círculo, no chão", "Neon #CF338F"),
}


def gerar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for pasta in ("exports", "previews"):
        d = os.path.join(DIR_BASE, pasta)
        os.makedirs(d, exist_ok=True)
        for antigo in os.listdir(d):
            os.remove(os.path.join(d, antigo))
    os.makedirs(os.path.join(DIR_BASE, "source"), exist_ok=True)
    img = gerar_textura()
    mat = material_lamina(img)
    objs = {}
    info = {}
    for i, (nome, fn) in enumerate(PECAS):
        m = Malha()
        qtd = fn(m, random.Random(1700 + i))
        m.limpar()
        obj = objeto(nome, m, mat)
        objs[nome] = obj
        xs = [v.co for v in obj.data.vertices]
        lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
        hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
        tam = hi - lo
        centro = (hi + lo) / 2
        papel, pivo, material = PAPEIS[nome]
        info[nome] = {
            "triangulos": len(obj.data.polygons),
            "tamanhoRoblox": (tam.x, tam.z, tam.y),
            "centroRoblox": para_roblox(centro),
            "papel": papel,
            "pivo": pivo,
            "material": material,
        }
        if qtd:
            info[nome]["petalas"] = qtd
        m.bm.free()
        print("%-18s %5d triângulos  tamanho %s" % (nome, info[nome]["triangulos"], tuple(round(c, 2) for c in info[nome]["tamanhoRoblox"])))
    escrever_pecas(info)
    escrever_manifesto(info)
    img.save_render(os.path.join(DIR_BASE, "exports", "senbon_lamina.png"))
    for obj in objs.values():
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(DIR_BASE, "exports", obj.name + ".fbx"),
            use_selection=True,
            axis_forward="-Z",
            axis_up="Y",
            apply_scale_options="FBX_SCALE_UNITS",
            mesh_smooth_type="FACE",
            path_mode="COPY",
            embed_textures=True,
        )
    return objs


# ---------------------------------------------------------------- prévias (Blender, não Roblox)


def emissao(nome, cor, forca):
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*cor, 1)
    em.inputs["Strength"].default_value = forca
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def lamina_render(img):
    """Textura + um pouco de emissão (no jogo o brilho vem de Neon/luz/partículas)."""
    m = bpy.data.materials.new("lamina_render")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.4
    b.inputs["Metallic"].default_value = 0.4
    b.inputs["Roughness"].default_value = 0.3
    return m


def fosco(cor, rough=0.7):
    m = bpy.data.materials.new("fosco")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*cor, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def copia(fonte, matriz, escala, mat, colecao):
    obj = bpy.data.objects.new(fonte.name + "_i", fonte.data.copy())
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.matrix_world = matriz @ Matrix.Scale(escala, 4)
    colecao.objects.link(obj)
    return obj


def caixa(centro, tam, mat, colecao):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2])) + Vector(centro)
    me = bpy.data.meshes.new("caixa")
    bm.to_mesh(me)
    obj = bpy.data.objects.new("dummy", me)
    obj.data.materials.append(mat)
    colecao.objects.link(obj)


def rb_para_blender(v):
    """Roblox (relativo à raiz) -> Blender (raiz em z=3)."""
    return Vector((v[0], -v[2], v[1] + 3.0))


def pose_orbitas(t, abrir=0.0, correr=0.0, n=len(ORBITAS)):
    """Mesma ideia do Senbonzakura.luau (sem as molas): onde cada enxame está no instante t."""
    poses = []
    for template, rx, rz, alt, a0, w, inc, esc, _, _, _ in ORBITAS[:n]:
        a = a0 + w * t
        frente = max(0.0, -math.sin(a)) ** 2
        r = 1 + 0.3 * frente + 0.6 * abrir
        x, z = math.cos(a) * rx * r, math.sin(a) * rz * r
        y = alt * (1 + 0.35 * abrir) + inc * math.sin(a + 0.8) - (0.5 * frente if alt > 1.2 else 0)
        if correr:
            # enxame aerodinâmico: atrás (+Z) e nos ombros
            z = z * (1 - 0.35 * correr) + 1.6 * correr * (1 + max(0, z) * 0.2)
            x *= 1 - 0.25 * correr
            y += 0.35 * correr
        tang = Vector((-math.sin(a) * rx, 0, math.cos(a) * rz)) * (1 if w > 0 else -1)
        if correr:
            tang = tang.lerp(Vector((0, 0.15, 1)) * tang.length, 0.6 * correr)
        poses.append((template, Vector((x, y, z)), tang.normalized(), esc))
    return poses


def montar_cena(objs, mats, colecao, t, modo):
    def matriz_rb(pos, frente_rb, rolar=0.0):
        p = rb_para_blender(pos)
        f = Vector((frente_rb.x, -frente_rb.z, frente_rb.y))
        return Matrix.Translation(p) @ orientacao(f, rolar).to_4x4()

    abrir = 1.0 if modo == "peak" else 0.0
    correr = 1.0 if modo == "running" else 0.0
    for k, (template, pos, tang, esc) in enumerate(pose_orbitas(t, abrir, correr)):
        copia(objs[template], matriz_rb(pos, tang, 0.4 * math.sin(k * 1.7)), esc, mats["lamina"], colecao)
    rng = random.Random(11 + len(modo))
    # pétalas soltas (desprendendo / rastro)
    soltas = 9 if modo != "running" else 7
    for k in range(soltas):
        a = rng.uniform(0, 2 * math.pi)
        if modo == "running":
            pos = (rng.uniform(-1.2, 1.2), rng.uniform(-0.8, 1.6), rng.uniform(2.6, 5.0))
        else:
            if math.sin(a) < -0.3:
                a += math.pi
            r = rng.uniform(2.2, 4.4) * (1.4 if modo == "peak" else 1)
            pos = (math.cos(a) * r, rng.uniform(-1.6, 2.6), math.sin(a) * r)
        f = Vector((rng.uniform(-1, 1), rng.uniform(-0.4, 0.4), rng.uniform(-1, 1)))
        copia(objs["senbon_petal_a" if k % 2 else "senbon_petal_b"], matriz_rb(Vector(pos), f, rng.uniform(0, 3)), rng.uniform(0.7, 1.0), mats["lamina"], colecao)
    # um arco curto num setor (idle) ou os dois cruzados (pico/corrida)
    def arco(nome, giro, inclinar, alt, escala):
        m = Matrix.Translation((0, 0, 3.0 + alt)) @ Matrix.Rotation(inclinar, 4, "X") @ Matrix.Rotation(giro, 4, "Z")
        copia(objs[nome], m, escala, mats["arco"], colecao)

    if modo == "peak":
        arco("senbon_arco_a", 0.6, 0.35, 0.6, 1.35)
        arco("senbon_arco_b", 2.9, -0.4, 0.9, 1.45)
        copia(objs["senbon_selo"], Matrix.Translation((0, 0, 0.02)) @ Matrix.Rotation(0.4, 4, "Z"), 1.0, mats["arco"], colecao)
        for i, (graus, raio, alt) in enumerate(LANCAS):
            a = math.radians(graus)
            pos = Vector((math.sin(a) * raio, math.cos(a) * raio, 0.0))
            fora = math.radians(rng.uniform(4, 9))
            m = Matrix.Translation(pos) @ Matrix.Rotation(-a, 4, "Z") @ Matrix.Rotation(-fora, 4, "X")
            copia(objs["senbon_lance_a" if i % 2 == 0 else "senbon_lance_b"], m, alt, mats["lanca"], colecao)
    elif modo == "running":
        arco("senbon_arco_b", 0.4, 0.1, -0.2, 1.0)
    else:
        arco("senbon_arco_a", 2.9 + t * 0.4, 0.12, 0.3, 1.0)


def renderizar(objs):
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 40
    cena.cycles.device = "CPU"
    cena.view_settings.view_transform = "AgX"
    cena.view_settings.look = "AgX - Punchy"
    mundo = bpy.data.worlds.new("noite")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.025, 0.012, 0.05, 1)
    cena.world = mundo
    for o in objs.values():
        o.hide_render = True
        o.hide_set(True)
    img = bpy.data.images["senbon_lamina"]
    mats = {
        "lamina": lamina_render(img),
        "arco": emissao("arco", (0.95, 0.3, 0.68), 9.0),
        "lanca": emissao("lanca", (1.0, 0.6, 0.88), 6.0),
    }
    fixa = bpy.data.collections.new("dummy_referencia")
    cena.collection.children.link(fixa)
    avatar = fosco((0.16, 0.15, 0.18))
    for c, t in (((-0.5, 0, 1), (0.9, 0.9, 2)), ((0.5, 0, 1), (0.9, 0.9, 2)), ((0, 0, 3), (2, 1, 2)), ((-1.5, 0, 3), (0.95, 0.95, 2)), ((1.5, 0, 3), (0.95, 0.95, 2)), ((0, 0, 4.6), (1.2, 1.2, 1.2))):
        caixa(c, t, avatar, fixa)
    caixa((0, 0, -0.06), (300, 300, 0.1), fosco((0.05, 0.03, 0.07), 0.5), fixa)
    for nome, energia, pos, cor in (("chave", 900, (5, 8, 9), (1.0, 0.75, 0.95)), ("contra", 700, (-6, -7, 6), (0.7, 0.45, 1.0))):
        luz = bpy.data.lights.new(nome, "AREA")
        luz.energy = energia
        luz.size = 6
        luz.color = cor
        ol = bpy.data.objects.new(nome, luz)
        ol.location = pos
        ol.rotation_euler = (Vector((0, 0, 3)) - ol.location).to_track_quat("-Z", "Y").to_euler()
        fixa.objects.link(ol)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 42
    oc = bpy.data.objects.new("cam", cam)
    fixa.objects.link(oc)
    cena.camera = oc

    def tirar(nome, pos, alvo, rx_=600, ry_=760):
        cena.render.resolution_x, cena.render.resolution_y = rx_, ry_
        oc.location = pos
        oc.rotation_euler = (Vector(alvo) - oc.location).to_track_quat("-Z", "Y").to_euler()
        cena.render.filepath = os.path.join(DIR_BASE, "previews", nome + ".png")
        bpy.ops.render.render(write_still=True)
        print("prévia", nome)

    def com(modo, t, fn):
        col = bpy.data.collections.new(modo)
        cena.collection.children.link(col)
        montar_cena(objs, mats, col, t, modo)
        fn()
        for o in list(col.objects):
            bpy.data.objects.remove(o)
        bpy.data.collections.remove(col)

    def vistas():
        for nome, graus in (("front", 0), ("three_quarter", 40), ("side", 90), ("back", 180)):
            a = math.radians(graus)
            tirar(nome, (math.sin(a) * 15, math.cos(a) * 15, 5.0), (0, 0, 3.4))
        tirar("top", (0.01, 0.6, 19), (0, 0, 2.5), 700, 700)
        tirar("idle", (11, 12, 6.5), (0, 0, 3.2))

    com("idle", 3.0, vistas)
    com("running", 5.0, lambda: tirar("running", (13, -6, 5.5), (0, 0.8, 3.2)))
    com("peak", 7.0, lambda: tirar("peak", (9, 15, 6.5), (0, 0, 3.0), 760, 760))
    folha_de_contato()


def folha_de_contato():
    from PIL import Image

    nomes = ["front", "three_quarter", "side", "back", "top", "idle", "running", "peak"]
    imgs = [Image.open(os.path.join(DIR_BASE, "previews", n + ".png")).convert("RGB") for n in nomes]
    alt = 380
    redim = [im.resize((int(im.width * alt / im.height), alt)) for im in imgs]
    larg = max(sum(im.width for im in redim[:4]), sum(im.width for im in redim[4:]))
    folha = Image.new("RGB", (larg, alt * 2), (8, 4, 14))
    for linha in range(2):
        x = 0
        for im in redim[linha * 4 : linha * 4 + 4]:
            folha.paste(im, (x, linha * alt))
            x += im.width
    folha.save(os.path.join(DIR_BASE, "previews", "contact_sheet.png"))


if __name__ == "__main__":
    objetos = gerar()
    if "--render" in sys.argv:
        renderizar(objetos)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "senbonzakura.blend"), compress=True)
