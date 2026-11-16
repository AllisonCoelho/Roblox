"""Gera o kit 3D "Ruínas do Nexo" no Blender (testado com bpy 5.3) e exporta tudo.

Uso (Blender como módulo Python):
    pip install bpy numpy
    python assets/nexo/source/generate_nexo.py            # modelos, .blend, .fbx e dados Luau
    python assets/nexo/source/generate_nexo.py --render   # também renderiza as prévias (Cycles, CPU)

Ou dentro do Blender: blender --background --python assets/nexo/source/generate_nexo.py

Saídas:
    assets/nexo/source/nexo_master.blend      cena editável (kit + montagem da praça)
    assets/nexo/exports/<peca>.fbx            uma peça por arquivo, para o 3D Importer do Studio
    assets/nexo/previews/*.jpg                renders do Blender (NÃO são capturas do Roblox)
    src/client/Mundo/Nexo3D/Dados/<peca>.luau geometria compacta lida pelo jogo (EditableMesh)
    src/client/Mundo/Nexo3D/Cena.luau         onde cada peça fica na praça (fonte única da montagem)

Unidades: 1 unidade do Blender = 1 stud. Blender é Z para cima; o Roblox é Y para cima.
Conversão usada na exportação Luau: (x, y, z) Blender -> (x, z, -y) Roblox. Norte do mapa = +Y aqui.
Cada peça é modelada em volta do próprio pivô (centro da base), com geometria determinística
(sementes fixas): rodar de novo gera exatamente os mesmos arquivos.
"""

import base64
import math
import os
import random
import struct
import sys

import bpy  # precisa vir antes de bmesh/mathutils quando o Blender roda como módulo

import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
DIR_SOURCE = os.path.join(RAIZ, "assets", "nexo", "source")
DIR_EXPORTS = os.path.join(RAIZ, "assets", "nexo", "exports")
DIR_PREVIEWS = os.path.join(RAIZ, "assets", "nexo", "previews")
DIR_LUAU = os.path.join(RAIZ, "src", "client", "Mundo", "Nexo3D")
DIR_DADOS = os.path.join(DIR_LUAU, "Dados")

# Paleta (sRGB 0..1)
PEDRA = (0.40, 0.39, 0.47)
PEDRA_PISO = (0.43, 0.42, 0.51)
PEDRA_CAMINHO = (0.56, 0.54, 0.64)
PEDRA_PEDESTAL = (0.44, 0.40, 0.56)
METAL = (0.22, 0.21, 0.27)
OURO = (0.95, 0.74, 0.30)
CIANO = (0.49, 0.98, 1.00)
VIOLETA = (0.62, 0.40, 0.98)


# ---------------------------------------------------------------- utilidades de malha


def novo_bm():
    bm = bmesh.new()
    bm.loops.layers.color.new("Col")
    return bm


def pintar(bm, base, tinta=1.0, topo_claro=0.30, gradiente=None):
    """Cor por vértice: base x variação do bloco x luz simples (faces de cima mais claras).

    gradiente = (z0, z1, cor_baixo, cor_alto) mistura duas cores pela altura (cristais).
    """
    camada = bm.loops.layers.color["Col"]
    bm.normal_update()
    for face in bm.faces:
        luz = (1.0 - topo_claro) + topo_claro * max(face.normal.z, 0.0)
        if face.normal.z < -0.3:
            luz *= 0.8
        for loop in face.loops:
            cor = base
            if gradiente:
                z0, z1, baixo, alto = gradiente
                f = min(max((loop.vert.co.z - z0) / (z1 - z0), 0.0), 1.0)
                cor = tuple(baixo[i] + (alto[i] - baixo[i]) * f for i in range(3))
            loop[camada] = tuple(min(c * tinta * luz, 1.0) for c in cor) + (1.0,)


def chanfrar(bm, largura):
    if largura > 0:
        bmesh.ops.bevel(
            bm,
            geom=bm.edges[:],
            offset=largura,
            offset_type="OFFSET",
            segments=1,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )


def tremer(bm, rng, quanto):
    for v in bm.verts:
        v.co += Vector((rng.uniform(-quanto, quanto), rng.uniform(-quanto, quanto), rng.uniform(-quanto, quanto)))


def juntar(destino, origem, matriz=None):
    """Copia a geometria de `origem` para `destino` (aplicando a matriz) e libera `origem`."""
    if matriz is not None:
        bmesh.ops.transform(origem, matrix=matriz, verts=origem.verts[:])
    tmp = bpy.data.meshes.new("tmp")
    origem.to_mesh(tmp)
    origem.free()
    destino.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)


def bloco(sx, sy, sz, rng, cor, chanfro=0.1, tremor=0.03, tinta=None):
    """Bloco de pedra talhado: caixa levemente irregular com arestas chanfradas."""
    bm = novo_bm()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts[:])
    tremer(bm, rng, tremor)
    chanfrar(bm, chanfro)
    pintar(bm, cor, tinta if tinta is not None else rng.uniform(0.86, 1.06))
    return bm


def cunha(r_in, r_out, a0, a1, z0, z1, rng, cor, chanfro=0.1, tremor=0.03, folga=0.06, arcos=1, tinta=None):
    """Bloco em forma de fatia de anel (planta polar), para pisos e degraus circulares."""
    bm = novo_bm()
    # A folga angular vira uma distância constante entre blocos vizinhos
    d_in = folga / max(r_in, 0.5)
    d_out = folga / r_out
    baixo, cima = [], []
    pontos = []
    for i in range(arcos + 1):
        f = i / arcos
        pontos.append((r_out - folga, a0 + d_out + (a1 - a0 - 2 * d_out) * f))
    for i in range(arcos, -1, -1):
        f = i / arcos
        pontos.append((r_in + folga, a0 + d_in + (a1 - a0 - 2 * d_in) * f))
    for r, a in pontos:
        baixo.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z0)))
        cima.append(bm.verts.new((r * math.cos(a), r * math.sin(a), z1)))
    n = len(pontos)
    bm.faces.new(cima)
    bm.faces.new(list(reversed(baixo)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((baixo[i], baixo[j], cima[j], cima[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    tremer(bm, rng, tremor)
    chanfrar(bm, chanfro)
    pintar(bm, cor, tinta if tinta is not None else rng.uniform(0.86, 1.06))
    return bm


def laje(r_in, r_out, a0, a1, topo, rng, cor, folga=0.07, chanfro=0.09, saia=0.3, tinta=None):
    """Laje de piso econômica: só o topo, o chanfro e uma saia curta (o fundo nunca aparece)."""
    bm = novo_bm()
    d_in = folga / max(r_in, 0.5)
    d_out = folga / r_out
    cantos = [
        (r_in + folga, a0 + d_in),
        (r_out - folga, a0 + d_out),
        (r_out - folga, a1 - d_out),
        (r_in + folga, a1 - d_in),
    ]
    centro_r = (r_in + r_out) / 2
    centro_a = (a0 + a1) / 2
    cx, cy = centro_r * math.cos(centro_a), centro_r * math.sin(centro_a)
    fora = [Vector((r * math.cos(a), r * math.sin(a), 0.0)) for r, a in cantos]
    z = topo + rng.uniform(-0.035, 0.035)
    inclina = (rng.uniform(-0.012, 0.012), rng.uniform(-0.012, 0.012))

    def altura(p):
        return z + (p.x - cx) * inclina[0] + (p.y - cy) * inclina[1]

    dentro = []
    for p in fora:
        d = Vector((cx - p.x, cy - p.y, 0.0))
        d.normalize()
        q = p + d * chanfro
        dentro.append(bm.verts.new((q.x, q.y, altura(q))))
    borda = [bm.verts.new((p.x, p.y, altura(p) - chanfro)) for p in fora]
    base = [bm.verts.new((p.x, p.y, altura(p) - chanfro - saia)) for p in fora]
    bm.faces.new(dentro)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((borda[i], borda[j], dentro[j], dentro[i]))
        bm.faces.new((base[i], base[j], borda[j], borda[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        if f.normal.z < -0.01 and len(f.verts) == 4 and all(v in dentro for v in f.verts):
            f.normal_flip()
    pintar(bm, cor, tinta if tinta is not None else rng.uniform(0.84, 1.08), topo_claro=0.35)
    return bm


def torno(perfil, lados, cor, rng, estrela=0.0, tinta=None):
    """Sólido de revolução a partir de um perfil [(raio, z)]. estrela > 0 cria caneluras."""
    bm = novo_bm()
    aneis = []
    for r, z in perfil:
        anel = []
        for i in range(lados):
            a = 2 * math.pi * i / lados
            raio = r * (1.0 - estrela if i % 2 else 1.0)
            anel.append(bm.verts.new((raio * math.cos(a), raio * math.sin(a), z)))
        aneis.append(anel)
    for k in range(len(aneis) - 1):
        for i in range(lados):
            j = (i + 1) % lados
            bm.faces.new((aneis[k][i], aneis[k][j], aneis[k + 1][j], aneis[k + 1][i]))
    bm.faces.new(list(reversed(aneis[0])))
    bm.faces.new(aneis[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    pintar(bm, cor, tinta if tinta is not None else rng.uniform(0.9, 1.04))
    return bm


def casco(pontos, cor=None, tinta=1.0, gradiente=None, chanfro=0.0):
    """Sólido facetado (casco convexo) a partir de pontos: cristais e rochas."""
    bm = novo_bm()
    for p in pontos:
        bm.verts.new(p)
    resultado = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    sobra = [e for e in resultado["geom_interior"] + resultado["geom_unused"] if isinstance(e, bmesh.types.BMVert)]
    if sobra:
        bmesh.ops.delete(bm, geom=list(set(sobra)), context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    chanfrar(bm, chanfro)
    pintar(bm, cor or CIANO, tinta, topo_claro=0.25, gradiente=gradiente)
    return bm


def fita(pontos, largura, z, cor):
    """Faixa plana de energia seguindo uma linha de pontos (x, y)."""
    bm = novo_bm()
    esq, direita = [], []
    for i, p in enumerate(pontos):
        a = Vector(pontos[max(i - 1, 0)])
        b = Vector(pontos[min(i + 1, len(pontos) - 1)])
        d = b - a
        d.normalize()
        normal = Vector((-d.y, d.x))
        esq.append(bm.verts.new((p[0] + normal.x * largura / 2, p[1] + normal.y * largura / 2, z)))
        direita.append(bm.verts.new((p[0] - normal.x * largura / 2, p[1] - normal.y * largura / 2, z)))
    for i in range(len(pontos) - 1):
        bm.faces.new((direita[i], direita[i + 1], esq[i + 1], esq[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    pintar(bm, cor, 1.0, topo_claro=0.0)
    return bm


def arco_pontos(raio, a0, a1, n):
    return [(raio * math.cos(a0 + (a1 - a0) * i / n), raio * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


# ---------------------------------------------------------------- peças do kit


def fazer_pedestal():
    """Pedestal ancestral em três degraus de blocos talhados, com coroa e bacia."""
    rng = random.Random(101)
    bm = novo_bm()
    # Degrau 1: doze blocos largos
    for i in range(12):
        a0, a1 = 2 * math.pi * i / 12, 2 * math.pi * (i + 1) / 12
        topo = 1.3 + rng.uniform(-0.05, 0.05)
        juntar(bm, cunha(5.4, 9.0, a0, a1, 0.0, topo, rng, PEDRA_PEDESTAL, chanfro=0.14, arcos=2))
    # Degrau 2: oito blocos, desalinhados do primeiro
    for i in range(8):
        a0 = 2 * math.pi * (i + 0.5) / 8
        a1 = 2 * math.pi * (i + 1.5) / 8
        topo = 2.5 + rng.uniform(-0.05, 0.05)
        juntar(bm, cunha(2.6, 6.3, a0, a1, 0.9, topo, rng, PEDRA_PEDESTAL, chanfro=0.14, arcos=2))
    # Contrafortes entre as garras: cunhas inclinadas que quebram a silhueta circular
    for i in range(4):
        a = math.pi / 2 * i
        b = bloco(2.6, 1.5, 2.0, rng, PEDRA_PEDESTAL, chanfro=0.16)
        m = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((7.4, 0, 1.2)) @ Matrix.Rotation(math.radians(-14), 4, "Y")
        juntar(bm, b, m)
    # Tambor central com faixa entalhada e bacia aberta para o cristal
    perfil = [(3.7, 2.3), (3.7, 2.9), (3.35, 3.0), (3.35, 3.5), (3.75, 3.6), (3.9, 4.1), (3.2, 4.25), (2.4, 3.9), (0.4, 3.75)]
    juntar(bm, torno(perfil, 16, PEDRA_PEDESTAL, rng, tinta=0.98))
    # Selos em relevo na faixa do tambor (losangos originais)
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        b = bloco(0.5, 0.16, 0.5, rng, OURO, chanfro=0.05, tremor=0.0, tinta=0.9)
        m = Matrix.Rotation(a + math.pi / 2, 4, "Z") @ Matrix.Translation((0, -3.38, 3.25)) @ Matrix.Rotation(math.radians(45), 4, "Y")
        juntar(bm, b, m)
    return bm


def fazer_pedestal_energia():
    """Canaletas de energia do pedestal: anel na bacia e veios descendo os degraus."""
    bm = novo_bm()
    juntar(bm, fita(arco_pontos(2.9, 0, 2 * math.pi, 32), 0.22, 4.16, CIANO))
    for i in range(4):
        a = math.pi / 2 * i + math.pi / 4
        c, s = math.cos(a), math.sin(a)
        # veio em zigue-zague no topo de cada degrau
        juntar(bm, fita([(2.7 * c, 2.7 * s), (4.2 * c - 0.3 * s, 4.2 * s + 0.3 * c), (6.1 * c, 6.1 * s)], 0.2, 2.58, CIANO))
        juntar(bm, fita([(6.5 * c, 6.5 * s), (7.6 * c + 0.3 * s, 7.6 * s - 0.3 * c), (8.8 * c, 8.8 * s)], 0.2, 1.38, CIANO))
    return bm


def fazer_garra():
    """Garra de contenção: vértebras de metal que sobem em curva e apontam para o cristal.

    Modelada ao longo de +X; a cena usa quatro, giradas em volta do pedestal.
    """
    rng = random.Random(202)
    bm = novo_bm()
    p0, p1, p2 = Vector((5.0, 1.2)), Vector((10.2, 5.2)), Vector((5.6, 9.6))  # (raio, z)
    n = 7

    def ponto(t):
        return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t**2 * p2

    for i in range(n):
        a, b = ponto(i / n), ponto((i + 1) / n)
        meio = (a + b) / 2
        d = b - a
        alfa = math.atan2(d.x, d.y)
        grosso = 1.5 - 0.95 * (i / (n - 1))
        seg = bloco(grosso, grosso * 0.8, d.length * 0.94, rng, METAL, chanfro=0.12, tremor=0.0, tinta=1.0 + 0.04 * (i % 2))
        m = Matrix.Translation((meio.x, 0, meio.y)) @ Matrix.Rotation(alfa, 4, "Y")
        juntar(bm, seg, m)
        # anel dourado entre vértebras
        if 0 < i < n - 1:
            anel = bloco(grosso * 1.12, grosso * 0.92, 0.14, rng, OURO, chanfro=0.04, tremor=0.0, tinta=0.85)
            juntar(bm, anel, Matrix.Translation((a.x, 0, a.y)) @ Matrix.Rotation(alfa, 4, "Y"))
    # ponta afiada
    d = ponto(1.0) - ponto(0.9)
    alfa = math.atan2(d.x, d.y)
    ponta = casco([(0.3, 0.24, 0), (-0.3, 0.24, 0), (-0.3, -0.24, 0), (0.3, -0.24, 0), (0, 0, 1.5)], OURO, 0.95)
    juntar(bm, ponta, Matrix.Translation((p2.x, 0, p2.y)) @ Matrix.Rotation(alfa, 4, "Y"))
    return bm


def pontos_cristal(rng):
    pts = [(0.15, -0.1, 6.6), (-0.2, 0.15, -6.0)]
    for i in range(6):
        a = 2 * math.pi * i / 6 + rng.uniform(-0.2, 0.2)
        r = 2.5 + rng.uniform(-0.45, 0.5)
        pts.append((r * math.cos(a), r * math.sin(a), 2.3 + rng.uniform(-0.7, 0.7)))
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6 + rng.uniform(-0.2, 0.2)
        r = 3.1 + rng.uniform(-0.4, 0.5)
        pts.append((r * math.cos(a), r * math.sin(a), -1.2 + rng.uniform(-0.7, 0.7)))
    return pts


def fazer_cristal_partido():
    """Cristal principal: um sólido facetado partido por planos em estilhaços afastados.

    Devolve [(bmesh, direcao_do_estilhaco)]: cada estilhaço é uma peça própria, com pivô
    no centro do cristal, para o jogo poder afastá-los quando o Núcleo se agita.
    """
    rng = random.Random(303)
    inteiro = casco(pontos_cristal(rng))
    planos = [
        (Vector((0.3, 0.2, 0.6)), Vector((0.25, 0.15, 1.0))),
        (Vector((0.2, -0.3, -0.4)), Vector((1.0, 0.35, 0.3))),
        (Vector((-0.3, 0.2, 0.2)), Vector((-0.3, 1.0, -0.25))),
    ]
    pedacos = [inteiro]
    for co, no in planos:
        novos = []
        for p in pedacos:
            for lado in (True, False):
                c = p.copy()
                bmesh.ops.bisect_plane(c, geom=c.verts[:] + c.edges[:] + c.faces[:], plane_co=co, plane_no=no, clear_inner=lado, clear_outer=not lado)
                borda = [e for e in c.edges if e.is_boundary]
                if borda:
                    bmesh.ops.contextual_create(c, geom=borda)
                if len(c.faces) >= 4 and c.calc_volume(signed=False) > 1.5:
                    bmesh.ops.recalc_face_normals(c, faces=c.faces[:])
                    novos.append(c)
                else:
                    c.free()
            p.free()
        pedacos = novos
    saida = []
    for p in pedacos:
        centro = sum((v.co for v in p.verts), Vector()) / len(p.verts)
        direcao = centro.normalized() if centro.length > 0.01 else Vector((0, 0, 1))
        # encolhe um pouco e afasta: as frestas deixam o coração aparecer
        for v in p.verts:
            v.co = centro + (v.co - centro) * 0.93 + direcao * 0.42
        chanfrar(p, 0.05)
        pintar(p, CIANO, rng.uniform(0.9, 1.05), topo_claro=0.22, gradiente=(-6.0, 6.6, VIOLETA, CIANO))
        saida.append((p, direcao))
    return saida


def fazer_cristal_nucleo():
    """Coração emissivo dentro do cristal partido."""
    rng = random.Random(404)
    pts = [(0, 0, 2.6), (0, 0, -2.4)]
    for i in range(7):
        a = 2 * math.pi * i / 7
        r = 1.35 + rng.uniform(-0.2, 0.2)
        pts.append((r * math.cos(a), r * math.sin(a), 0.5 + rng.uniform(-0.5, 0.5)))
    return casco(pts, CIANO, 1.0, gradiente=(-2.4, 2.6, (0.85, 0.75, 1.0), (0.9, 1.0, 1.0)))


def fazer_fragmento(semente, comprimento, largura):
    """Fragmento de cristal solto (flutua em volta do Núcleo e sobre os pilares)."""
    rng = random.Random(semente)
    pts = [(rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), comprimento * 0.58), (0, 0, -comprimento * 0.42)]
    lados = rng.choice((4, 5))
    for i in range(lados):
        a = 2 * math.pi * i / lados + rng.uniform(-0.3, 0.3)
        r = largura * rng.uniform(0.75, 1.15)
        pts.append((r * math.cos(a), r * math.sin(a), comprimento * rng.uniform(0.05, 0.25)))
    return casco(pts, CIANO, 1.0, gradiente=(-comprimento * 0.42, comprimento * 0.58, VIOLETA, CIANO), chanfro=0.03)


def fazer_arco():
    """Arco monumental partido: dois pilares de blocos e aduelas, com um trecho desabado."""
    rng = random.Random(505)
    bm = novo_bm()
    r_in, espessura, fundo = 11.0, 3.0, 3.2
    alt_pilar = 9.6
    x_pilar = r_in + espessura / 2
    for lado in (-1, 1):
        # soco e blocos do pilar
        juntar(bm, bloco(4.6, 4.4, 0.9, rng, PEDRA, chanfro=0.16), Matrix.Translation((lado * x_pilar, 0, 0.45)))
        z = 0.9
        for k in range(4):
            h = (alt_pilar - 0.9 - 0.7) / 4
            b = bloco(3.5 + rng.uniform(-0.12, 0.12), 3.5 + rng.uniform(-0.12, 0.12), h - 0.05, rng, PEDRA, chanfro=0.15)
            m = Matrix.Translation((lado * x_pilar + rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08), z + h / 2))
            m = m @ Matrix.Rotation(math.radians(rng.uniform(-1.5, 1.5)), 4, "Z")
            juntar(bm, b, m)
            z += h
        juntar(bm, bloco(4.3, 4.1, 0.7, rng, PEDRA, chanfro=0.14), Matrix.Translation((lado * x_pilar, 0, alt_pilar - 0.35)))
    # Aduelas: 15 fatias de 12°. As de 96° a 132° desabaram; as vizinhas saíram do lugar.
    n = 15
    de_pe = Matrix.Rotation(math.radians(90), 4, "X")
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        if i in (9, 10):
            continue
        chave = i == 7
        extra = 0.7 if chave else 0.0
        b = cunha(r_in - (0.25 if chave else 0), r_in + espessura + extra, a0, a1, -fundo / 2 - extra / 3, fundo / 2 + extra / 3, rng, PEDRA, chanfro=0.15, arcos=2)
        m = Matrix.Translation((0, 0, alt_pilar)) @ de_pe
        if i == 8:  # pendurada na beira da falha
            m = Matrix.Translation((-0.35, 0.1, alt_pilar - 0.45)) @ Matrix.Rotation(math.radians(5), 4, "Y") @ de_pe
        if i == 11:
            m = Matrix.Translation((0.3, -0.15, alt_pilar - 0.25)) @ Matrix.Rotation(math.radians(-4), 4, "Y") @ de_pe
        juntar(bm, b, m)
    # Cunha quebrada: meia aduela lascada na falha
    resto = casco([(-1.2, -1.4, 0), (1.3, -1.5, 0.2), (1.1, 1.5, 0), (-1.0, 1.4, 0.3), (0.2, -1.0, 2.1), (-0.6, 1.0, 1.6), (0.9, 0.8, 1.2)], PEDRA, 0.92, chanfro=0.08)
    a = math.radians(138)
    juntar(bm, resto, Matrix.Translation(((r_in + 1.4) * math.cos(a), 0, alt_pilar + (r_in + 1.4) * math.sin(a))) @ Matrix.Rotation(math.radians(40), 4, "Y"))
    # Moldura em relevo na pedra-chave
    juntar(bm, bloco(1.5, 0.3, 1.5, rng, PEDRA, chanfro=0.1, tinta=1.08), Matrix.Translation((0, -fundo / 2 - 0.3, alt_pilar + r_in + 1.7)) @ Matrix.Rotation(math.radians(45), 4, "Y"))
    return bm


def fazer_arco_energia():
    """Selo emissivo da pedra-chave e veios nos pilares do arco."""
    bm = novo_bm()
    gema = casco([(0, 0, 0.75), (0, 0, -0.75), (0.75, 0, 0), (-0.75, 0, 0), (0, -0.3, 0)], OURO, 1.0)
    juntar(bm, gema, Matrix.Translation((0, -2.05, 9.6 + 11.0 + 1.7)))
    for lado in (-1, 1):
        f = fita([(0, 1.6), (0.35, 4.0), (-0.3, 6.2), (0, 8.4)], 0.2, 0, CIANO)
        m = Matrix.Translation((lado * 12.5, -1.84, 0)) @ Matrix.Rotation(math.radians(90), 4, "X")
        juntar(bm, f, m)
    return bm


def fazer_pilar():
    """Módulo de ruína A: pilar canelado em tambores, com o topo quebrado."""
    rng = random.Random(606)
    bm = novo_bm()
    juntar(bm, bloco(3.6, 3.6, 0.7, rng, PEDRA, chanfro=0.14), Matrix.Translation((0, 0, 0.35)))
    juntar(bm, torno([(1.75, 0.7), (1.75, 1.0), (1.45, 1.3)], 12, PEDRA, rng))
    z = 1.3
    for k in range(4):
        h = 2.25 + rng.uniform(-0.15, 0.15)
        perfil = [(1.3, 0), (1.36, 0.12), (1.36, h - 0.16), (1.3, h - 0.04)]
        t = torno(perfil, 24, PEDRA, rng, estrela=0.09)
        m = Matrix.Translation((rng.uniform(-0.07, 0.07), rng.uniform(-0.07, 0.07), z)) @ Matrix.Rotation(rng.uniform(0, 0.5), 4, "Z")
        juntar(bm, t, m)
        z += h
    # Tambor quebrado: cortado por um plano inclinado
    quebrado = torno([(1.3, 0), (1.36, 0.12), (1.36, 2.4), (1.3, 2.5)], 24, PEDRA, rng, estrela=0.09)
    bmesh.ops.bisect_plane(quebrado, geom=quebrado.verts[:] + quebrado.edges[:] + quebrado.faces[:], plane_co=(0, 0, 1.2), plane_no=(0.55, 0.25, 1.0), clear_outer=True)
    borda = [e for e in quebrado.edges if e.is_boundary]
    if borda:
        bmesh.ops.contextual_create(quebrado, geom=borda)
    bmesh.ops.recalc_face_normals(quebrado, faces=quebrado.faces[:])
    pintar(quebrado, PEDRA, 0.95)
    juntar(bm, quebrado, Matrix.Translation((0.05, -0.04, z)))
    return bm


def fazer_parede():
    """Módulo de ruína B: trecho de muro em fiadas, desabando em escada para um lado."""
    rng = random.Random(707)
    bm = novo_bm()
    comp, alt, fundo = 2.4, 1.15, 1.5
    fiadas = [6, 6, 5, 4, 2, 1]
    juntar(bm, bloco(15.2, 2.1, 0.5, rng, PEDRA, chanfro=0.12), Matrix.Translation((0, 0, 0.25)))
    for linha, quantos in enumerate(fiadas):
        desloc = (comp / 2) if linha % 2 else 0.0
        for k in range(quantos):
            x = -7.2 + comp / 2 + k * comp + desloc
            b = bloco(comp - 0.08 + rng.uniform(-0.1, 0.05), fundo + rng.uniform(-0.1, 0.1), alt - 0.06, rng, PEDRA, chanfro=0.11)
            m = Matrix.Translation((x, rng.uniform(-0.07, 0.07), 0.5 + alt / 2 + linha * alt))
            if k == quantos - 1 and linha > 1:  # bloco da ponta, meio solto
                m = m @ Matrix.Rotation(math.radians(rng.uniform(4, 9)), 4, "Y")
            juntar(bm, b, m)
    # Bloco caído ao pé do muro
    juntar(bm, bloco(comp, fundo, alt, rng, PEDRA, chanfro=0.11), Matrix.Translation((5.6, -1.9, 0.5)) @ Matrix.Rotation(math.radians(24), 4, "Z") @ Matrix.Rotation(math.radians(12), 4, "X"))
    return bm


def fazer_rocha(semente, tamanho):
    rng = random.Random(semente)
    pts = []
    for _ in range(16):
        v = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0, 1)))
        v.normalize()
        pts.append((v.x * tamanho * rng.uniform(0.7, 1.1), v.y * tamanho * rng.uniform(0.6, 1.0), v.z * tamanho * rng.uniform(0.45, 0.8)))
    pts += [(tamanho * 0.7, tamanho * 0.5, 0), (-tamanho * 0.7, tamanho * 0.45, 0), (0, -tamanho * 0.75, 0)]
    return casco(pts, PEDRA, rng.uniform(0.85, 1.0), chanfro=0.04)


ANEIS_PISO = [(8.7, 14.0, 12), (14.0, 20.5, 18), (20.5, 27.0, 24), (27.0, 33.5, 28), (33.5, 40.0, 32), (40.0, 46.0, 36)]


def fazer_piso():
    """Piso da praça: lajes radiais com alturas e tons variados e um caminho claro de entrada."""
    rng = random.Random(808)
    bm = novo_bm()
    sul = -math.pi / 2  # o spawn fica ao sul (-Y)
    for indice, (r0, r1, n) in enumerate(ANEIS_PISO):
        giro = rng.uniform(0, 2 * math.pi / n)
        for i in range(n):
            a0 = giro + 2 * math.pi * i / n
            a1 = giro + 2 * math.pi * (i + 1) / n
            meio = (a0 + a1) / 2
            # distância angular até o eixo sul, convertida em studs
            dif = abs((meio - sul + math.pi) % (2 * math.pi) - math.pi) * (r0 + r1) / 2
            caminho = dif < 4.2
            cor = PEDRA_CAMINHO if caminho else PEDRA_PISO
            tinta = rng.uniform(0.84, 1.08) * (1.0 if indice % 2 else 0.95)
            juntar(bm, laje(r0, r1, a0, a1, 0.05, rng, cor, tinta=tinta))
    return bm


def fazer_piso_energia():
    """Canaletas de energia da praça: anéis, raios, o caminho do spawn e marcas originais."""
    bm = novo_bm()
    z = 0.16  # acima da laje mais alta, para nenhuma canaleta ficar enterrada
    juntar(bm, fita(arco_pontos(14.0, 0, 2 * math.pi, 48), 0.26, z, CIANO))
    # anel externo interrompido nos caminhos (norte e sul)
    for a0, a1 in ((math.radians(-78), math.radians(78)), (math.radians(102), math.radians(258))):
        juntar(bm, fita(arco_pontos(27.0, a0, a1, 40), 0.22, z, VIOLETA))
    # raios entre os dois anéis, nas diagonais
    for i in range(8):
        a = math.pi / 4 * i + math.pi / 8
        c, s = math.cos(a), math.sin(a)
        juntar(bm, fita([(14.4 * c, 14.4 * s), (20.5 * c - 0.5 * s, 20.5 * s + 0.5 * c), (26.6 * c, 26.6 * s)], 0.2, z, CIANO))
    # caminho de entrada: duas linhas do spawn ao pedestal
    for x in (-4.3, 4.3):
        juntar(bm, fita([(x, -45.0), (x, -30.0), (x * 0.86, -20.0), (x * 0.7, -14.6)], 0.24, z, OURO))
    # marcas de contenção: losango com traço, doze em volta da praça
    for i in range(12):
        a = 2 * math.pi * i / 12 + math.pi / 12
        cx, cy = 37.0 * math.cos(a), 37.0 * math.sin(a)
        rot = Matrix.Rotation(a, 4, "Z")
        losango = fita([(0.9, 0), (0, 0.55), (-0.9, 0), (0, -0.55), (0.9, 0)], 0.16, z, OURO if i % 3 == 0 else CIANO)
        traco = fita([(-1.7, 0), (-1.1, 0)], 0.16, z, CIANO)
        traco2 = fita([(1.1, 0), (1.7, 0)], 0.16, z, CIANO)
        for parte in (losango, traco, traco2):
            juntar(bm, parte, Matrix.Translation((cx, cy, 0)) @ rot)
    return bm


# ---------------------------------------------------------------- registro e montagem

PECAS = {}  # nome -> objeto do Blender
ESTILHACOS = []  # (nome, direcao em coordenadas do Roblox)


def registrar(nome, bm, material):
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    malha = bpy.data.meshes.new(nome)
    bm.to_mesh(malha)
    bm.free()
    for poligono in malha.polygons:
        poligono.use_smooth = False
    malha.materials.append(material)
    obj = bpy.data.objects.new(nome, malha)
    PECAS[nome] = obj
    return obj


def criar_material(nome, emissao=0.0, rugosidade=0.85, transmissao=0.0, metalico=0.0):
    mat = bpy.data.materials.new(nome)
    nos = mat.node_tree.nodes
    bsdf = nos["Principled BSDF"]
    cor = nos.new("ShaderNodeVertexColor")
    cor.layer_name = "Col"
    mat.node_tree.links.new(cor.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rugosidade
    bsdf.inputs["Metallic"].default_value = metalico
    if transmissao > 0:
        bsdf.inputs["Transmission Weight"].default_value = transmissao
    if emissao > 0:
        mat.node_tree.links.new(cor.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emissao
    return mat


def construir_kit():
    pedra = criar_material("Nexo_Pedra")
    metal = criar_material("Nexo_Metal", rugosidade=0.45, metalico=0.8)
    energia = criar_material("Nexo_Energia", emissao=6.0)
    cristal = criar_material("Nexo_Cristal", emissao=0.6, rugosidade=0.12, transmissao=0.55)
    coracao = criar_material("Nexo_Coracao", emissao=9.0)

    registrar("pedestal_nexo", fazer_pedestal(), pedra)
    registrar("pedestal_energia", fazer_pedestal_energia(), energia)
    registrar("garra_nexo", fazer_garra(), metal)
    for i, (bm, direcao) in enumerate(fazer_cristal_partido(), start=1):
        nome = "cristal_estilhaco_%d" % i
        registrar(nome, bm, cristal)
        ESTILHACOS.append((nome, (direcao.x, direcao.z, -direcao.y)))
    registrar("cristal_nucleo", fazer_cristal_nucleo(), coracao)
    registrar("cristal_fragmento_a", fazer_fragmento(11, 4.2, 0.95), cristal)
    registrar("cristal_fragmento_b", fazer_fragmento(12, 3.0, 0.8), cristal)
    registrar("cristal_fragmento_c", fazer_fragmento(13, 2.2, 0.55), cristal)
    registrar("arco_partido", fazer_arco(), pedra)
    registrar("arco_energia", fazer_arco_energia(), energia)
    registrar("ruina_pilar_a", fazer_pilar(), pedra)
    registrar("ruina_parede_b", fazer_parede(), pedra)
    registrar("rocha_a", fazer_rocha(21, 1.5), pedra)
    registrar("rocha_b", fazer_rocha(22, 0.9), pedra)
    registrar("praca_piso", fazer_piso(), pedra)
    registrar("praca_energia", fazer_piso_energia(), energia)


# Montagem da praça em coordenadas do ROBLOX (studs; Y para cima; norte = -Z; topo da praça em y = 1).
# material: nome de Enum.Material. grupo: papel da peça na animação do Núcleo.
# colisores: caixas simples {centro local, tamanho} em coordenadas do Roblox, relativas ao pivô.
TOPO = 1.0
CENTRO_CRISTAL = (0.0, 15.5, 0.0)


def montar_cena():
    rng = random.Random(909)
    cena = []

    def por(malha, pos, giro=0.0, escala=1.0, material="Slate", **extra):
        item = {"malha": malha, "posicao": pos, "giro": giro, "escala": escala, "material": material}
        item.update(extra)
        cena.append(item)
        return item

    por("praca_piso", (0, TOPO, 0))
    por("praca_energia", (0, TOPO, 0), material="Neon")
    por("pedestal_nexo", (0, TOPO, 0), material="Slate")
    por("pedestal_energia", (0, TOPO, 0), material="Neon")
    for i in range(4):
        por("garra_nexo", (0, TOPO, 0), giro=45 + 90 * i, material="Metal")
    for nome, direcao in ESTILHACOS:
        por(nome, CENTRO_CRISTAL, material="Glass", transparencia=0.12, grupo="estilhaco", direcao=direcao)
    por("cristal_nucleo", CENTRO_CRISTAL, material="Neon", grupo="nucleo")
    # Fragmentos em órbita lenta em volta do cristal
    orbitas = [("cristal_fragmento_a", 8.5, 3.5, 20), ("cristal_fragmento_b", 9.5, -2.5, 95), ("cristal_fragmento_c", 7.5, 5.5, 160), ("cristal_fragmento_b", 10.5, 1.0, 230), ("cristal_fragmento_c", 8.0, -4.0, 300)]
    for malha, raio, altura, fase in orbitas:
        por(malha, CENTRO_CRISTAL, material="Glass", transparencia=0.1, grupo="orbita", raio=raio, altura=altura, fase=fase, inclinacao=rng.uniform(-25, 25))

    # Arco monumental ao norte, atrás do Núcleo para quem nasce ao sul
    escala_arco = 1.25
    colisores_arco = [((-12.5, 5.2, 0), (4.6, 10.4, 4.4)), ((12.5, 5.2, 0), (4.6, 10.4, 4.4))]
    por("arco_partido", (0, TOPO, -31), escala=escala_arco, colisores=colisores_arco)
    por("arco_energia", (0, TOPO, -31), escala=escala_arco, material="Neon")
    # Dois arcos menores nas diagonais, virados para o centro
    for x, z, giro in ((-33, -12, 70), (33, -12, -70)):
        por("arco_partido", (x, TOPO, z), giro=giro, escala=0.55, colisores=colisores_arco)

    # Pilares em ruína em volta da praça, com um fragmento-lanterna flutuando em cada um
    colisor_pilar = [((0, 6.2, 0), (3.0, 12.4, 3.0))]
    for i in range(8):
        graus = 22.5 + 45 * i
        a = math.radians(graus)
        x, z = 41 * math.sin(a), -41 * math.cos(a)
        por("ruina_pilar_a", (x, TOPO, z), giro=rng.uniform(0, 360), escala=rng.uniform(0.9, 1.12), colisores=colisor_pilar)
        por("cristal_fragmento_b", (x, TOPO + 15.5, z), giro=rng.uniform(0, 360), material="Neon", grupo="lanterna", fase=rng.uniform(0, 360))

    # Muros desabados ao lado do arco
    colisor_muro = [((-1.2, 2.6, 0), (12.8, 5.2, 1.9))]
    por("ruina_parede_b", (-29, TOPO, -33), giro=24, colisores=colisor_muro)
    por("ruina_parede_b", (29, TOPO, -33), giro=156, colisores=colisor_muro)

    # Entulho: fora dos caminhos, perto das ruínas
    entulho = [(-20, -27), (-17.5, -29.5), (21, -28), (-36, -30), (36, -29), (-31, -9), (32, -15), (24, -34), (-12, -38), (13, -37)]
    for i, (x, z) in enumerate(entulho):
        por("rocha_a" if i % 2 == 0 else "rocha_b", (x, TOPO, z), giro=rng.uniform(0, 360), escala=rng.uniform(0.8, 1.5))
    return cena


# ---------------------------------------------------------------- exportação


def roblox_para_blender(p):
    return Vector((p[0], -p[2], p[1]))


def dados_da_malha(obj):
    """Geometria no formato do jogo: vértices não compartilhados entre faces (sombreado plano)."""
    malha = obj.data
    cores = malha.color_attributes["Col"].data
    malha.calc_loop_triangles()
    pos, cor, tris = [], [], []
    mapa = {}
    for tri in malha.loop_triangles:
        indices = []
        for loop in tri.loops:
            chave = (tri.polygon_index, malha.loops[loop].vertex_index)
            if chave not in mapa:
                v = malha.vertices[malha.loops[loop].vertex_index].co
                mapa[chave] = len(pos)
                pos.append((v.x, v.z, -v.y))
                c = cores[loop].color
                cor.append(tuple(int(round(min(max(linear_para_srgb(c[i]), 0), 1) * 255)) for i in range(3)))
            indices.append(mapa[chave])
        # A troca de eixos é uma rotação (não espelha), então a ordem dos vértices se mantém
        tris.append(tuple(indices))
    return pos, cor, tris


def linear_para_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def escrever_luau(nome, obj):
    pos, cor, tris = dados_da_malha(obj)
    assert len(pos) < 65536, nome
    minimo = [min(p[i] for p in pos) for i in range(3)]
    maximo = [max(p[i] for p in pos) for i in range(3)]
    tamanho = [max(maximo[i] - minimo[i], 1e-4) for i in range(3)]
    dados = bytearray()
    for p in pos:  # posição: 3 x uint16 dentro da caixa da malha
        dados += struct.pack("<3H", *(int(round((p[i] - minimo[i]) / tamanho[i] * 65535)) for i in range(3)))
    for c in cor:  # cor: 3 x uint8
        dados += struct.pack("<3B", *c)
    for t in tris:  # triângulos: 3 x uint16
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    pedacos = [texto[i : i + 4000] for i in range(0, len(texto), 4000)]
    linhas = [
        "-- GERADO por assets/nexo/source/generate_nexo.py. Não editar à mão.",
        "-- Peça do kit 3D do Nexo: posições (uint16), cores (uint8) e triângulos (uint16) em base64.",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ]
    linhas += ['\t\t"%s",' % p for p in pedacos]
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(pos), len(tris), len(texto)


def luau_valor(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return ("%.3f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, (tuple, list)):
        return "{ " + ", ".join(luau_valor(x) for x in v) + " }"
    raise TypeError(v)


def escrever_cena(cena):
    linhas = [
        "-- GERADO por assets/nexo/source/generate_nexo.py. Não editar à mão.",
        "-- Montagem da praça: onde cada peça do kit fica (studs do Roblox; giro em graus no eixo Y).",
        "-- colisores = caixas { centro local, tamanho } relativas ao pivô da peça, antes da escala.",
        "return {",
        "\tcentroCristal = %s," % luau_valor(CENTRO_CRISTAL),
        "\tpecas = {",
    ]
    for item in cena:
        campos = ["%s = %s" % (k, luau_valor(v)) for k, v in item.items()]
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_LUAU, "Cena.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def exportar_fbx(nome, obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(DIR_EXPORTS, nome + ".fbx"),
        use_selection=True,
        object_types={"MESH"},
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        colors_type="SRGB",
        bake_anim=False,
    )


def montar_no_blender(cena):
    """Coloca o kit numa coleção e monta a praça com instâncias (para o .blend e os renders)."""
    raiz = bpy.context.scene.collection
    kit = bpy.data.collections.new("Kit")
    praca = bpy.data.collections.new("Praca")
    raiz.children.link(kit)
    kit.hide_render = True  # a vitrine do kit não entra nos renders da praça
    raiz.children.link(praca)
    for i, (nome, obj) in enumerate(sorted(PECAS.items())):
        kit.objects.link(obj)
        obj.location = (-120 + (i % 6) * 40, 140 + (i // 6) * 40, 0)  # vitrine do kit, longe da praça
    for n, item in enumerate(cena):
        fonte = PECAS[item["malha"]]
        inst = bpy.data.objects.new("%03d_%s" % (n, item["malha"]), fonte.data)
        pos = roblox_para_blender(item["posicao"])
        if item.get("grupo") == "orbita":
            a = math.radians(item["fase"])
            pos = pos + Vector((item["raio"] * math.cos(a), item["raio"] * math.sin(a), item["altura"]))
            inst.rotation_euler = (math.radians(item["inclinacao"]), math.radians(20), a)
        else:
            inst.rotation_euler = (0, 0, math.radians(item["giro"]))
        inst.location = pos
        inst.scale = (item["escala"],) * 3
        praca.objects.link(inst)
    return kit, praca


def preparar_render():
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 40
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 1280, 720
    cena.view_settings.view_transform = "Filmic" if "Filmic" in [i.identifier for i in type(cena.view_settings).bl_rna.properties["view_transform"].enum_items] else "AgX"
    mundo = bpy.data.worlds.new("Noite")
    fundo = mundo.node_tree.nodes["Background"]
    fundo.inputs["Color"].default_value = (0.035, 0.03, 0.08, 1)
    fundo.inputs["Strength"].default_value = 1.0
    cena.world = mundo
    # chão escuro além da praça
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=150, fill_type="NGON", location=(0, 0, 0.9))
    chao = bpy.context.object
    mat = bpy.data.materials.new("Chao")
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.018, 0.035, 1)
    chao.data.materials.append(mat)
    # luar frio e a luz do coração
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(55), 0, math.radians(140)))
    bpy.context.object.data.energy = 1.8
    bpy.context.object.data.color = (0.6, 0.7, 1.0)
    bpy.ops.object.light_add(type="POINT", location=roblox_para_blender(CENTRO_CRISTAL))
    bpy.context.object.data.energy = 60000
    bpy.context.object.data.color = (0.5, 0.95, 1.0)
    bpy.context.object.data.shadow_soft_size = 2.0


def renderizar(nome, origem, alvo, lente=28):
    bpy.ops.object.camera_add(location=origem)
    camera = bpy.context.object
    direcao = Vector(alvo) - Vector(origem)
    camera.rotation_euler = direcao.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = lente
    bpy.context.scene.camera = camera
    bpy.context.scene.render.image_settings.file_format = "JPEG"
    bpy.context.scene.render.image_settings.quality = 90
    bpy.context.scene.render.filepath = os.path.join(DIR_PREVIEWS, nome + ".jpg")
    bpy.ops.render.render(write_still=True)


def main():
    for d in (DIR_SOURCE, DIR_EXPORTS, DIR_PREVIEWS, DIR_DADOS):
        os.makedirs(d, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    construir_kit()
    cena = montar_cena()
    montar_no_blender(cena)

    total_tris = 0
    print("%-22s %8s %8s %9s" % ("peca", "vertices", "tris", "base64"))
    for nome, obj in sorted(PECAS.items()):
        v, t, c = escrever_luau(nome, obj)
        total_tris += t
        print("%-22s %8d %8d %9d" % (nome, v, t, c))
        exportar_fbx(nome, obj)
    escrever_cena(cena)
    print("total de triangulos no kit: %d | instancias na cena: %d" % (total_tris, len(cena)))

    if "--render" in sys.argv:
        preparar_render()
        # mesma posição de quem nasce: ao sul da praça, câmera em terceira pessoa olhando o Núcleo
        renderizar("spawn", (0, -47, 7.5), (0, 0, 12.5), lente=24)
        renderizar("nucleo", (17, -21, 9), (0, 0, 11), lente=30)
        renderizar("alto", (38, -52, 34), (0, -4, 6), lente=28)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_SOURCE, "nexo_master.blend"))


if __name__ == "__main__":
    main()
