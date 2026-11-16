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


# ================================================================ locais do Nexo (fase 2)
# Os seis lugares em volta da praça, os caminhos de transição e o anel de penhascos.
# Convenção das peças de lugar: pivô no centro do lugar, no chão; a "frente" (lado da praça)
# é +Y no Blender, que vira -Z local no Roblox.

GRAMA = (0.20, 0.36, 0.30)
MUSGO = (0.30, 0.46, 0.34)
VERDE = (0.36, 1.00, 0.55)
SELO = (0.92, 0.16, 0.24)
MAGENTA = (0.86, 0.36, 1.00)
MARMORE = (0.78, 0.76, 0.84)
ROCHA = (0.27, 0.25, 0.33)
TRONCO = (0.30, 0.25, 0.30)


def misturar(a, b, f):
    return tuple(a[i] + (b[i] - a[i]) * f for i in range(3))


def fita3d(pontos, largura, normal, cor):
    """Faixa de energia seguindo pontos 3D; `normal` é o lado para onde a faixa olha."""
    bm = novo_bm()
    n = Vector(normal).normalized()
    esq, direita = [], []
    for i, p in enumerate(pontos):
        a = Vector(pontos[max(i - 1, 0)])
        b = Vector(pontos[min(i + 1, len(pontos) - 1)])
        t = (b - a).normalized()
        lado = t.cross(n).normalized() * (largura / 2)
        p = Vector(p)
        esq.append(bm.verts.new(p + lado))
        direita.append(bm.verts.new(p - lado))
    for i in range(len(pontos) - 1):
        f = bm.faces.new((direita[i], direita[i + 1], esq[i + 1], esq[i]))
        if f.normal.dot(n) < 0:
            f.normal_flip()
    pintar(bm, cor, 1.0, topo_claro=0.0)
    return bm


def losango(cx, cy, z, tam, cor, giro=0.0):
    """Marca de contenção (losango) plana no chão."""
    pts = [(tam, 0), (0, tam * 0.6), (-tam, 0), (0, -tam * 0.6), (tam, 0)]
    c, s = math.cos(giro), math.sin(giro)
    return fita([(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts], tam * 0.18, z, cor)


def tronco_quadrado(b0, b1, z0, z1, rng, cor, chanfro=0.08):
    """Bloco quadrado afunilado (largura b0 embaixo, b1 em cima)."""
    pts = []
    for z, b in ((z0, b0), (z1, b1)):
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts.append((sx * b / 2, sy * b / 2, z))
    return casco(pts, cor, rng.uniform(0.9, 1.04), chanfro=chanfro)


# ---------------------------------------------------------------- Arquivo dos Ecos


def fazer_arquivo_base():
    rng = random.Random(1101)
    bm = novo_bm()
    juntar(bm, torno([(21, 0), (21, 0.85), (20.6, 1.0), (0.5, 1.0)], 40, PEDRA, rng, tinta=0.95))
    for i in range(20):
        a0, a1 = 2 * math.pi * i / 20, 2 * math.pi * (i + 1) / 20
        juntar(bm, cunha(13.0, 17.0, a0, a1, 1.0, 2.0, rng, PEDRA, chanfro=0.12, arcos=2))
    for r0, r1, n in ((3.2, 7.8, 10), (7.8, 13.0, 16)):
        giro = rng.uniform(0, 1)
        for i in range(n):
            a0, a1 = giro + 2 * math.pi * i / n, giro + 2 * math.pi * (i + 1) / n
            juntar(bm, laje(r0, r1, a0, a1, 2.0, rng, MARMORE, tinta=rng.uniform(0.82, 0.98)))
    juntar(bm, torno([(3.2, 1.0), (3.2, 2.0), (0.3, 2.0)], 16, MARMORE, rng, tinta=0.9))
    return bm


def fazer_arquivo_coluna():
    rng = random.Random(1102)
    bm = novo_bm()
    juntar(bm, bloco(3.2, 3.2, 0.6, rng, MARMORE, chanfro=0.1, tinta=0.92), Matrix.Translation((0, 0, 0.3)))
    juntar(bm, torno([(1.6, 0.6), (1.6, 0.9), (1.3, 1.1), (1.3, 12.4), (1.75, 13.1), (1.75, 13.4)], 20, MARMORE, rng, estrela=0.07))
    juntar(bm, bloco(3.5, 3.5, 0.6, rng, MARMORE, chanfro=0.1, tinta=0.95), Matrix.Translation((0, 0, 13.7)))
    return bm


def fazer_arquivo_estrutura():
    """Cornija circular sobre as colunas e a cúpula de nervuras, aberta como um observatório."""
    rng = random.Random(1103)
    bm = novo_bm()
    for i in range(20):
        a0, a1 = 2 * math.pi * i / 20, 2 * math.pi * (i + 1) / 20
        juntar(bm, cunha(13.2, 16.9, a0, a1, 14.0, 15.8, rng, MARMORE, chanfro=0.12, arcos=2, tinta=rng.uniform(0.86, 0.96)))
        juntar(bm, cunha(12.9, 17.3, a0, a1, 15.8, 16.5, rng, PEDRA, chanfro=0.1, arcos=2))
    # Nervuras: quartos de elipse do anel até a coroa
    n = 8
    for k in range(n):
        a = 2 * math.pi * k / n + math.pi / n
        rot = Matrix.Rotation(a, 4, "Z")
        segs = 7
        anterior = None
        for s in range(segs + 1):
            t = s / segs
            r = 3.2 + (15.0 - 3.2) * math.cos(t * math.pi / 2)
            z = 16.5 + 11.0 * math.sin(t * math.pi / 2)
            ponto = Vector((r, 0, z))
            if anterior is not None:
                meio = (ponto + anterior) / 2
                d = ponto - anterior
                inclinacao = math.atan2(d.x, d.z)
                seg = bloco(0.9, 1.0, d.length + 0.25, rng, METAL, chanfro=0.08, tremor=0.0)
                juntar(bm, seg, rot @ Matrix.Translation(meio) @ Matrix.Rotation(inclinacao, 4, "Y"))
            anterior = ponto
    for i in range(8):
        a0, a1 = 2 * math.pi * i / 8, 2 * math.pi * (i + 1) / 8
        juntar(bm, cunha(2.4, 4.0, a0, a1, 27.0, 28.4, rng, METAL, chanfro=0.08))
    return bm


def fazer_arquivo_energia():
    bm = novo_bm()
    juntar(bm, fita(arco_pontos(12.6, 0, 2 * math.pi, 48), 0.24, 2.12, CIANO))
    juntar(bm, fita(arco_pontos(7.6, 0, 2 * math.pi, 36), 0.18, 2.12, CIANO))
    for i in range(10):
        a = 2 * math.pi * i / 10
        c, s = math.cos(a), math.sin(a)
        juntar(bm, losango(10.2 * c, 10.2 * s, 2.12, 0.8, OURO if i % 2 else CIANO, a))
    # anel brilhante na base da cúpula e a coroa
    juntar(bm, fita(arco_pontos(15.4, 0, 2 * math.pi, 48), 0.3, 16.56, CIANO))
    juntar(bm, fita(arco_pontos(3.3, 0, 2 * math.pi, 20), 0.35, 28.45, OURO))
    return bm


def fazer_arquivo_console():
    rng = random.Random(1104)
    bm = novo_bm()
    juntar(bm, torno([(2.3, 0), (2.3, 0.4), (1.6, 0.6), (1.2, 2.1), (1.9, 2.5), (1.9, 2.75), (0.3, 2.75)], 12, PEDRA, rng))
    tampo = bloco(3.0, 2.0, 0.3, rng, MARMORE, chanfro=0.06, tinta=0.95)
    juntar(bm, tampo, Matrix.Translation((0, 0.2, 2.95)) @ Matrix.Rotation(math.radians(18), 4, "X"))
    return bm


def fazer_projecao():
    """Painel de projeção do Arquivo: lâmina hexagonal fina."""
    pts = []
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        for y in (-0.06, 0.06):
            pts.append((1.3 * math.cos(a), y, 2.0 * math.sin(a) + 2.0))
    return casco(pts, CIANO, 1.0, gradiente=(0.0, 4.0, VIOLETA, CIANO))


# ---------------------------------------------------------------- Obelisco das Lendas


def fazer_obelisco_base():
    rng = random.Random(1201)
    bm = novo_bm()
    for i, (lado, z0) in enumerate(((26, 0.0), (20, 1.2), (14, 2.4))):
        juntar(bm, bloco(lado, lado, 1.2, rng, PEDRA, chanfro=0.14, tinta=0.92 + 0.04 * i), Matrix.Translation((0, 0, z0 + 0.6)))
        # pedras de canto
        for sx in (-1, 1):
            for sy in (-1, 1):
                juntar(bm, bloco(1.6, 1.6, 1.5, rng, PEDRA, chanfro=0.1), Matrix.Translation((sx * (lado / 2 - 0.6), sy * (lado / 2 - 0.6), z0 + 0.75)))
    return bm


def largura_fuste(z):
    return 6.0 - (6.0 - 4.2) * (z - 3.6) / 30.0


def fazer_obelisco_fuste():
    rng = random.Random(1202)
    bm = novo_bm()
    cortes = [3.6, 9.6, 15.0, 20.0, 24.6, 29.0, 33.6]
    for i in range(len(cortes) - 1):
        z0, z1 = cortes[i], cortes[i + 1]
        juntar(bm, tronco_quadrado(largura_fuste(z0) - 0.05, largura_fuste(z1) - 0.05, z0 + 0.04, z1 - 0.04, rng, ROCHA, chanfro=0.1))
        if 0 < i:
            b = largura_fuste(z0) + 0.35
            juntar(bm, bloco(b, b, 0.35, rng, METAL, chanfro=0.06, tremor=0.0, tinta=0.95), Matrix.Translation((0, 0, z0)))
    return bm


def fazer_obelisco_ponta():
    return casco([(2.15, 2.15, 0), (-2.15, 2.15, 0), (2.15, -2.15, 0), (-2.15, -2.15, 0), (0, 0, 4.8)], OURO, 0.95, chanfro=0.05)


def fazer_obelisco_energia():
    """Canais dourados que sobem pelas quatro faces do obelisco, mais fortes no alto."""
    bm = novo_bm()
    for k in range(4):
        rot = Matrix.Rotation(math.pi / 2 * k, 4, "Z")
        pontos = []
        for i in range(14):
            z = 4.2 + i * 2.1
            x = (0.35 if i % 2 else -0.35) * (1 - i / 16)
            d = largura_fuste(z) / 2 + 0.04
            pontos.append(rot @ Vector((x, d, z)))
        normal = rot @ Vector((0, 1, 0))
        juntar(bm, fita3d(pontos, 0.22, normal, OURO))
        # selo em cada face, na altura do painel
        selo = [rot @ Vector((x, largura_fuste(z) / 2 + 0.05, z)) for x, z in ((0, 6.2), (0.9, 7.4), (0, 8.6), (-0.9, 7.4), (0, 6.2))]
        juntar(bm, fita3d(selo, 0.2, normal, CIANO))
    return bm


def fazer_pilone():
    rng = random.Random(1203)
    bm = novo_bm()
    juntar(bm, bloco(3.4, 3.4, 0.8, rng, PEDRA, chanfro=0.1), Matrix.Translation((0, 0, 0.4)))
    juntar(bm, tronco_quadrado(2.6, 1.7, 0.8, 8.4, rng, ROCHA))
    juntar(bm, bloco(2.3, 2.3, 0.4, rng, METAL, chanfro=0.05, tremor=0.0), Matrix.Translation((0, 0, 8.6)))
    return bm


def fazer_moldura_ranking():
    """Moldura de pedra em volta do painel do ranking (painel 14 x 8 a 17 studs na frente)."""
    rng = random.Random(1204)
    bm = novo_bm()
    y = 17.0
    for sx in (-1, 1):
        juntar(bm, bloco(1.6, 1.6, 10.6, rng, PEDRA, chanfro=0.12), Matrix.Translation((sx * 7.9, y, 5.3)))
    juntar(bm, bloco(18.4, 1.9, 1.3, rng, PEDRA, chanfro=0.14), Matrix.Translation((0, y, 10.95)))
    juntar(bm, bloco(18.0, 2.4, 1.6, rng, PEDRA, chanfro=0.14), Matrix.Translation((0, y, 0.8)))
    juntar(bm, bloco(2.0, 0.5, 2.0, rng, OURO, chanfro=0.06, tremor=0.0, tinta=0.9), Matrix.Translation((0, y + 0.95, 11.0)) @ Matrix.Rotation(math.radians(45), 4, "Y"))
    return bm


# ---------------------------------------------------------------- Jardim dos Fragmentos


def ruido(x, y, semente):
    return (
        math.sin(x * 0.21 + semente) * math.cos(y * 0.17 - semente * 0.7)
        + 0.5 * math.sin(x * 0.53 - y * 0.41 + semente * 1.3)
    )


def fazer_jardim_chao():
    """Gramado em montes suaves, com borda de pedras irregulares."""
    rng = random.Random(1301)
    bm = novo_bm()
    aneis = [0, 4, 9, 14, 19, 24, 28, 31]
    lados = 40
    grade = []
    for r in aneis:
        anel = []
        for i in range(lados if r > 0 else 1):
            a = 2 * math.pi * i / lados
            x, y = r * math.cos(a), r * math.sin(a)
            borda = 1 - (r / 31) ** 3
            z = 0.55 + 0.45 * max(ruido(x, y, 2.0), -0.3) * borda
            anel.append(bm.verts.new((x, y, z)))
        grade.append(anel)
    for i in range(lados):
        j = (i + 1) % lados
        bm.faces.new((grade[0][0], grade[1][i], grade[1][j]))
    for k in range(1, len(aneis) - 1):
        for i in range(lados):
            j = (i + 1) % lados
            bm.faces.new((grade[k][i], grade[k + 1][i], grade[k + 1][j], grade[k][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    camada = bm.loops.layers.color["Col"]
    for f in bm.faces:
        tom = rng.uniform(0.82, 1.08)
        cor = misturar(GRAMA, MUSGO, rng.uniform(0, 1))
        for loop in f.loops:
            loop[camada] = tuple(min(c * tom, 1) for c in cor) + (1.0,)
    # Borda de pedras
    for i in range(30):
        a0, a1 = 2 * math.pi * i / 30, 2 * math.pi * (i + 0.86) / 30
        juntar(bm, cunha(30.5, 33.0, a0, a1, 0.0, rng.uniform(0.7, 1.2), rng, PEDRA, chanfro=0.14, tremor=0.08))
    return bm


def fazer_arvore_tronco():
    """Tronco retorcido de pedra viva que sustenta a copa de cristais."""
    rng = random.Random(1302)
    bm = novo_bm()
    p = Vector((0, 0, 0))
    direcao = Vector((0.15, 0.05, 1)).normalized()
    for i in range(7):
        grosso = 1.3 - i * 0.13
        comp = 1.4
        prox = p + direcao * comp
        meio = (p + prox) / 2
        seg = bloco(grosso, grosso, comp + 0.2, rng, TRONCO, chanfro=0.1, tremor=0.05)
        rot = direcao.to_track_quat("Z", "Y").to_matrix().to_4x4()
        juntar(bm, seg, Matrix.Translation(meio) @ rot)
        p = prox
        direcao = (direcao + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0.25))).normalized()
    # raízes
    for k in range(4):
        a = math.pi / 2 * k + 0.4
        raiz = bloco(2.2, 0.6, 0.5, rng, TRONCO, chanfro=0.08)
        juntar(bm, raiz, Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((1.0, 0, 0.2)) @ Matrix.Rotation(math.radians(-15), 4, "Y"))
    return bm


def fazer_arvore_copa():
    """Copa de cristais em leque, presa no alto do tronco (z ~ 9.4)."""
    rng = random.Random(1303)
    bm = novo_bm()
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        inclina = math.radians(rng.uniform(30, 60))
        comp = rng.uniform(2.6, 4.2)
        lasca = fazer_fragmento(1400 + k, comp, comp * 0.24)
        m = Matrix.Translation((0.6, 0.3, 9.4)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(inclina, 4, "X") @ Matrix.Translation((0, 0, comp * 0.42))
        juntar(bm, lasca, m)
    centro = fazer_fragmento(1410, 3.6, 0.9)
    juntar(bm, centro, Matrix.Translation((0.6, 0.3, 10.8)))
    return bm


def fazer_aglomerado(semente):
    rng = random.Random(semente)
    bm = novo_bm()
    for k in range(rng.randint(4, 7)):
        a = rng.uniform(0, 2 * math.pi)
        comp = rng.uniform(1.4, 3.6)
        lasca = fazer_fragmento(semente * 10 + k, comp, comp * 0.26)
        m = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((rng.uniform(0, 0.8), 0, comp * 0.3)) @ Matrix.Rotation(math.radians(rng.uniform(5, 40)), 4, "Y")
        juntar(bm, lasca, m)
    return bm


def fazer_passagem():
    """Pedras de passagem: da entrada (frente, +Y) ao fragmento escondido atrás do muro (-Y)."""
    rng = random.Random(1305)
    bm = novo_bm()
    for i in range(14):
        y = 30 - i * 3.9
        x = 3.2 * math.sin(i * 0.7)
        pts = []
        for k in range(7):
            a = 2 * math.pi * k / 7
            r = rng.uniform(0.9, 1.3)
            pts.append((x + r * math.cos(a), y + r * math.sin(a) * 0.8, 0.0))
            pts.append((x + r * 0.85 * math.cos(a), y + r * 0.8 * math.sin(a) * 0.85, 0.32))
        juntar(bm, casco(pts, PEDRA_CAMINHO, rng.uniform(0.85, 1.0), chanfro=0.06), Matrix.Translation((0, 0, 0.55)))
    return bm


def fazer_jardim_energia():
    """Fissuras verdes no gramado, irradiando das árvores de cristal."""
    rng = random.Random(1306)
    bm = novo_bm()
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(4, 24)
        x, y = r * math.cos(a), r * math.sin(a)
        pts = [(x, y)]
        for _ in range(4):
            a += rng.uniform(-0.8, 0.8)
            x += 1.6 * math.cos(a)
            y += 1.6 * math.sin(a)
            pts.append((x, y))
        z = 0.55 + 0.45 * max(ruido(x, y, 2.0), -0.3) + 0.08
        juntar(bm, fita(pts, 0.16, z + 0.12, VERDE))
    return bm


# ---------------------------------------------------------------- Altar da Ressonância


def fazer_altar_base():
    rng = random.Random(1501)
    bm = novo_bm()
    juntar(bm, torno([(16, 0), (16, 1), (12, 1), (12, 2), (8, 2), (8, 3), (0.4, 3)], 36, PEDRA, rng, tinta=0.94))
    # placas entalhadas nos espelhos dos degraus
    for i in range(16):
        a = 2 * math.pi * i / 16
        rot = Matrix.Rotation(a, 4, "Z")
        juntar(bm, bloco(0.25, 2.2, 0.6, rng, ROCHA, chanfro=0.04, tremor=0.0), rot @ Matrix.Translation((16.05, 0, 0.5)))
        if i % 2 == 0:
            juntar(bm, bloco(0.25, 2.0, 0.6, rng, ROCHA, chanfro=0.04, tremor=0.0), rot @ Matrix.Translation((12.05, 0, 1.5)))
    return bm


def fazer_monolito(semente):
    rng = random.Random(semente)
    pts = []
    for z, s in ((0, 1.0), (4.5, 0.97), (9.5, 0.86), (13.0, 0.66)):
        for sx in (-1, 1):
            for sy in (-1, 1):
                pts.append((sx * 1.35 * s + rng.uniform(-0.15, 0.15), sy * 0.95 * s + rng.uniform(-0.1, 0.1), z + rng.uniform(-0.2, 0.2)))
    pts.append((rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.3), 14.4))
    return casco(pts, ROCHA, rng.uniform(0.9, 1.05), chanfro=0.07)


def fazer_monolito_runa():
    """Runa vertical na face do monólito que olha para o centro (+Y)."""
    pontos = [(0, 1.0, z) for z in (2.0, 3.6)] + [(0.45, 1.0, 4.6), (0, 1.0, 5.6), (-0.45, 1.0, 6.6), (0, 1.0, 7.6), (0, 1.0, 9.6)]
    bm = fita3d(pontos, 0.22, (0, 1, 0), MAGENTA)
    juntar(bm, fita3d([(-0.5, 0.98, 10.6), (0, 0.95, 11.3), (0.5, 0.98, 10.6), (0, 0.98, 9.9), (-0.5, 0.98, 10.6)], 0.16, (0, 1, 0), MAGENTA))
    return bm


def fazer_altar_mesa():
    rng = random.Random(1503)
    return torno([(2.3, 0), (2.3, 0.5), (1.6, 0.7), (1.3, 2.1), (2.1, 2.5), (2.1, 2.85), (1.6, 2.85), (1.2, 2.55), (0.3, 2.5)], 14, PEDRA, rng)


def fazer_altar_halo():
    """Anel de pedra partido que flutua sobre o altar (gira devagar)."""
    rng = random.Random(1504)
    bm = novo_bm()
    for i in range(18):
        if i in (4, 5, 12):
            continue
        a0, a1 = 2 * math.pi * i / 18, 2 * math.pi * (i + 0.9) / 18
        desloc = Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), rng.uniform(-0.3, 0.3)))
        juntar(bm, cunha(6.2, 7.8, a0, a1, -0.55, 0.55, rng, PEDRA, chanfro=0.1, arcos=2), Matrix.Translation(desloc))
    return bm


def fazer_altar_energia():
    bm = novo_bm()
    for r, z in ((15.4, 1.03), (11.4, 2.03), (7.4, 3.03)):
        juntar(bm, fita(arco_pontos(r, 0, 2 * math.pi, 48), 0.2, z, MAGENTA))
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        c, s = math.cos(a), math.sin(a)
        juntar(bm, fita([(2.6 * c, 2.6 * s), (4.6 * c - 0.5 * s, 4.6 * s + 0.5 * c), (6.9 * c, 6.9 * s)], 0.18, 3.03, VIOLETA))
        juntar(bm, losango(10 * math.cos(a + 0.5), 10 * math.sin(a + 0.5), 2.03, 0.7, MAGENTA, a))
    return bm


# ---------------------------------------------------------------- Portais Fragmentados


def fazer_portais_base():
    rng = random.Random(1601)
    bm = novo_bm()
    juntar(bm, torno([(22, 0), (22, 0.7), (21.5, 0.8), (0.4, 0.8)], 40, ROCHA, rng, tinta=0.95))
    # lajes rachadas, cada vez mais soltas para o fundo (-Y)
    for r0, r1, n in ((4, 10, 12), (10, 16, 18), (16, 21.5, 24)):
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            meio = (a0 + a1) / 2
            fundo = max(0.0, -math.sin(meio))  # 0 na frente, 1 no fundo
            l = laje(r0, r1, a0, a1, 0.85 + fundo * rng.uniform(0, 0.35), rng, PEDRA, folga=0.08 + 0.2 * fundo)
            if fundo > 0.3:
                ang = math.radians(rng.uniform(-6, 6) * fundo)
                c = Vector((math.cos(meio) * (r0 + r1) / 2, math.sin(meio) * (r0 + r1) / 2, 0))
                l_m = Matrix.Translation(c) @ Matrix.Rotation(ang, 4, Vector((math.sin(meio), -math.cos(meio), 0))) @ Matrix.Translation(-c)
                juntar(bm, l, l_m)
            else:
                juntar(bm, l)
    return bm


def pontos_ogiva(raio_extra=0.0):
    """Arco ogival equilátero sobre o vão (-3,8 a 3,8) a partir de z = 12: lista (x, z), esquerda -> topo -> direita."""
    R = 7.6 + raio_extra
    esq = []
    for k in range(7):
        ang = math.pi - (math.pi / 3) * k / 6  # 180 -> 120 graus, centro em (+3.8, 12)
        esq.append((3.8 + R * math.cos(ang), 12 + R * math.sin(ang)))
    direita = [(-x, z) for x, z in reversed(esq[:-1])]
    return esq + direita


def fazer_portal(quebrado):
    rng = random.Random(1602 + quebrado)
    bm = novo_bm()
    alturas = (12.0, 6.5 if quebrado else 12.0)
    for lado, alt in zip((-1, 1), alturas):
        z = 0.0
        x = lado * 5.0
        juntar(bm, bloco(3.4, 3.2, 0.8, rng, PEDRA, chanfro=0.12), Matrix.Translation((x, 0, 0.4)))
        z = 0.8
        while z < alt - 0.3:
            h = min(2.2, alt - z)
            juntar(bm, bloco(2.4 + rng.uniform(-0.1, 0.1), 2.4, h - 0.06, rng, ROCHA, chanfro=0.12), Matrix.Translation((x + rng.uniform(-0.05, 0.05), 0, z + h / 2)))
            z += h
    # aduelas do arco ogival (2,2 de espessura)
    pts = pontos_ogiva(1.1)
    limite = 4 if quebrado else len(pts) - 1
    for i in range(limite):
        a, b = Vector((pts[i][0], 0, pts[i][1])), Vector((pts[i + 1][0], 0, pts[i + 1][1]))
        meio = (a + b) / 2
        d = b - a
        ang = math.atan2(d.x, d.z)
        juntar(bm, bloco(2.3, 2.4, d.length + 0.1, rng, ROCHA, chanfro=0.12), Matrix.Translation(meio) @ Matrix.Rotation(ang, 4, "Y"))
    if quebrado:
        # blocos caídos à frente do pilar partido
        for k in range(4):
            juntar(bm, bloco(2.3, 2.4, 2.0, rng, ROCHA, chanfro=0.12), Matrix.Translation((3 + k * 1.6, 2.5 + rng.uniform(-1, 1), 1.0)) @ Matrix.Rotation(rng.uniform(0, 3), 4, "Z") @ Matrix.Rotation(math.radians(rng.uniform(10, 40)), 4, "X"))
    return bm


def fazer_portal_runas(quebrado):
    bm = novo_bm()
    pts = [(-3.8, 0.8)] + pontos_ogiva(0.0) + [(3.8, 0.8)]
    if quebrado:
        pts = pts[:6]
    linha = [(x * 0.96, 1.25, z) for x, z in pts]
    juntar(bm, fita3d(linha, 0.24, (0, 1, 0), VIOLETA))
    # espinhos de cristal no topo e nos ombros
    alvos = [(0, 19.1), (-5, 12.6)] if quebrado else [(0, 19.1), (-5, 12.6), (5, 12.6)]
    for k, (x, z) in enumerate(alvos):
        lasca = fazer_fragmento(1650 + k, 2.4, 0.5)
        juntar(bm, lasca, Matrix.Translation((x, 0, z + 0.6)))
    return bm


# ---------------------------------------------------------------- Arena dos Despertos

ARENA_ARCO = (math.radians(-210), math.radians(30))  # 240 graus, aberta para +Y (praça)


def fazer_arena_piso():
    rng = random.Random(1701)
    bm = novo_bm()
    juntar(bm, torno([(24, 0), (24, 0.5), (0.4, 0.5)], 40, PEDRA, rng, tinta=0.9))
    for r0, r1, n in ((3, 9, 10), (9, 16, 16), (16, 23.5, 24)):
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            juntar(bm, laje(r0, r1, a0, a1, 0.6, rng, PEDRA_PISO))
    juntar(bm, torno([(3, 0.4), (3, 0.75), (0.3, 0.75)], 16, ROCHA, rng))
    return bm


def fazer_arena_arquibancada():
    rng = random.Random(1702)
    bm = novo_bm()
    a0, a1 = ARENA_ARCO
    n = 16
    for d in range(1, 4):
        r0, r1 = 24.5 + 3 * (d - 1), 24.5 + 3 * d
        for i in range(n):
            b0 = a0 + (a1 - a0) * i / n
            b1 = a0 + (a1 - a0) * (i + 1) / n
            juntar(bm, cunha(r0, r1, b0, b1, 0.0, 1.4 * d, rng, PEDRA, chanfro=0.12, arcos=2))
    return bm


def fazer_estandarte():
    """Estandarte vermelho pendurado numa trave de metal (preso ao topo da coluna, z = 14)."""
    rng = random.Random(1703)
    bm = novo_bm()
    juntar(bm, bloco(0.3, 3.4, 0.3, rng, METAL, chanfro=0.04, tremor=0.0), Matrix.Translation((0, 1.6, 13.0)))
    pano = novo_bm()
    pts = []
    for k in range(7):
        z = 12.8 - k * 1.2
        largura = 1.3 if k < 6 else 0.0
        onda = 0.18 * math.sin(k * 1.1)
        pts.append((largura, 2.6 + onda, z))
        pts.append((-largura if k < 6 else 0.0, 2.6 + onda, z))
    vs = [pano.verts.new(p) for p in pts]
    for k in range(6):
        a, b, c, d = vs[2 * k], vs[2 * k + 1], vs[2 * k + 3], vs[2 * k + 2]
        if k == 5:
            pano.faces.new((a, b, d))
        else:
            pano.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(pano, faces=pano.faces[:])
    pintar(pano, SELO, 0.9, topo_claro=0.1)
    juntar(bm, pano)
    return bm


def fazer_arena_energia():
    bm = novo_bm()
    for r in (5.5, 12.5):
        juntar(bm, fita(arco_pontos(r, 0, 2 * math.pi, 40), 0.26, 0.7, SELO))
    for i in range(8):
        a = math.pi / 4 * i
        c, s = math.cos(a), math.sin(a)
        juntar(bm, fita([(6 * c, 6 * s), (12 * c, 12 * s)], 0.18, 0.7, OURO))
        juntar(bm, losango(17.5 * c, 17.5 * s, 0.7, 0.9, SELO, a))
    return bm


# ---------------------------------------------------------------- Penhascos e caminhos


def fazer_penhasco(semente, largura, altura, prof):
    """Paredão de rocha: lâminas verticais lado a lado, topo serrilhado, frente para +Y."""
    rng = random.Random(semente)
    bm = novo_bm()
    x = -largura / 2
    while x < largura / 2:
        w = rng.uniform(5, 10)
        h = altura * rng.uniform(0.72, 1.08)
        y0 = rng.uniform(-1.5, 1.5)
        pts = []
        for xx in (x - 0.6, x + w + 0.6):
            for yy, zz in ((y0, 0), (y0 - prof, 0), (y0 - h * 0.1, h * rng.uniform(0.5, 0.7)), (y0 - prof * 0.8, h * rng.uniform(0.6, 0.8))):
                pts.append((xx, yy, zz))
        pts.append((x + w * rng.uniform(0.3, 0.7), y0 - prof * 0.45 - h * 0.08, h))
        pts.append((x + w * 0.2, y0 - prof * 0.3, h * rng.uniform(0.82, 0.95)))
        juntar(bm, casco(pts, ROCHA, rng.uniform(0.8, 1.05), gradiente=(0, altura, misturar(ROCHA, (0.1, 0.09, 0.14), 0.4), misturar(ROCHA, VIOLETA, 0.25))))
        x += w
    return bm


TEMAS = {
    # destino: (cor da pedra ao chegar, cor da energia)
    "arquivo": (MARMORE, CIANO),
    "obelisco": ((0.30, 0.29, 0.35), OURO),
    "jardim": (MUSGO, VERDE),
    "altar": ((0.38, 0.33, 0.48), MAGENTA),
    "portais": ((0.32, 0.30, 0.40), VIOLETA),
    "arena": ((0.50, 0.42, 0.44), SELO),
}


def fazer_caminho(tema, comprimento, semente):
    """Caminho da praça até um lugar, como TRANSIÇÃO: começa na pedra da praça e vai ganhando
    a cara do destino. Modelado de y = 0 (praça) a y = -comprimento (lugar); largura cresce.

    Devolve (pedra, energia).
    """
    rng = random.Random(semente)
    pedra, energia = novo_bm(), novo_bm()
    cor_fim, cor_energia = TEMAS[tema]
    passo = 2.6
    fileiras = int(comprimento / passo)
    for k in range(fileiras):
        f = k / max(fileiras - 1, 1)  # 0 = praça, 1 = destino
        y0 = -k * passo
        largura = 10 + 4 * f
        colunas = 3 if largura < 12 else 4
        cor = misturar(PEDRA_CAMINHO, cor_fim, f ** 1.3)
        for c in range(colunas):
            x0 = -largura / 2 + largura * c / colunas
            x1 = -largura / 2 + largura * (c + 1) / colunas
            folga = 0.08
            pts_base = [(x0 + folga, y0 - folga), (x1 - folga, y0 - folga), (x1 - folga, y0 - passo + folga), (x0 + folga, y0 - passo + folga)]
            zbase = 0.12
            tom = rng.uniform(0.85, 1.07)
            if tema == "portais" and f > 0.25 and rng.random() < 0.35 + 0.6 * f:
                # chão fraturado: a laje vira lascas inclinadas e levantadas
                partes = 2 + int(1.5 * f)
                for p in range(partes):
                    px = x0 + (x1 - x0) * rng.uniform(0.15, 0.85)
                    py = y0 - passo * rng.uniform(0.15, 0.85)
                    tam = (x1 - x0) / partes * rng.uniform(0.7, 1.1)
                    pts = []
                    for q in range(5):
                        ang = 2 * math.pi * q / 5 + rng.uniform(-0.3, 0.3)
                        pts.append((px + tam * math.cos(ang), py + tam * 0.8 * math.sin(ang), 0))
                        pts.append((px + tam * 0.9 * math.cos(ang), py + tam * 0.7 * math.sin(ang), 0.3))
                    lasca = casco(pts, cor, tom)
                    sobe = 0.12 + f * rng.uniform(0, 0.6)
                    inclina = Matrix.Rotation(math.radians(rng.uniform(-14, 14) * f), 4, Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized())
                    juntar(pedra, lasca, Matrix.Translation((px, py, sobe)) @ inclina @ Matrix.Translation((-px, -py, 0)))
                # brilho violeta saindo da fresta
                juntar(energia, fita([(x0 + 0.3, y0 - passo * rng.uniform(0.2, 0.8)), ((x0 + x1) / 2, y0 - passo * rng.uniform(0.2, 0.8)), (x1 - 0.3, y0 - passo * rng.uniform(0.2, 0.8))], 0.14 + 0.1 * f, 0.1, cor_energia))
                continue
            if tema == "jardim" and f > 0.3 and rng.random() < 0.5 * f:
                # a laje some e dá lugar a um tufo de vegetação
                for q in range(rng.randint(3, 6)):
                    gx, gy = rng.uniform(x0 + 0.3, x1 - 0.3), rng.uniform(y0 - passo + 0.3, y0 - 0.3)
                    h = rng.uniform(0.5, 1.3)
                    juntar(pedra, casco([(gx - 0.15, gy, 0.1), (gx + 0.15, gy, 0.1), (gx, gy + 0.12, 0.1), (gx + rng.uniform(-0.3, 0.3), gy + rng.uniform(-0.3, 0.3), 0.1 + h)], misturar(GRAMA, VERDE, rng.uniform(0, 0.3)), 1.0))
                continue
            bm_l = novo_bm()
            vs_cima = [bm_l.verts.new((x, y, zbase + 0.22 + rng.uniform(-0.03, 0.03))) for x, y in pts_base]
            vs_baixo = [bm_l.verts.new((x, y, 0.0)) for x, y in pts_base]
            bm_l.faces.new(vs_cima)
            for i in range(4):
                j = (i + 1) % 4
                bm_l.faces.new((vs_baixo[i], vs_baixo[j], vs_cima[j], vs_cima[i]))
            bmesh.ops.recalc_face_normals(bm_l, faces=bm_l.faces[:])
            chanfrar(bm_l, 0.06)
            pintar(bm_l, cor, tom, topo_claro=0.35)
            juntar(pedra, bm_l)
        # Energia do destino, cada vez mais densa
        z = 0.38
        if tema == "arquivo" and rng.random() < f * 1.3:
            for _ in range(1 + int(2 * f)):
                juntar(energia, losango(rng.uniform(-largura / 2 + 1, largura / 2 - 1), y0 - passo / 2, z, 0.35 + 0.4 * f, cor_energia, rng.uniform(0, math.pi)))
        elif tema == "jardim" and rng.random() < 0.3 + f:
            x = rng.uniform(-largura / 2 + 0.5, largura / 2 - 0.5)
            pts = [(x, y0)]
            for q in range(3):
                x += rng.uniform(-0.8, 0.8)
                pts.append((x, y0 - passo * (q + 1) / 3))
            juntar(energia, fita(pts, 0.1 + 0.12 * f, z, cor_energia))
        elif tema == "obelisco" and k % 2 == 0:
            for lado in (-1, 1):
                juntar(energia, fita([(lado * (largura / 2 - 0.4), y0), (lado * (largura / 2 - 0.4), y0 - passo)], 0.1 + 0.18 * f, z, cor_energia))
            if f > 0.4 and k % 4 == 0:
                juntar(energia, fita([(-largura / 2 + 0.4, y0 - 1), (largura / 2 - 0.4, y0 - 1)], 0.12, z, cor_energia))
        elif tema == "altar" and rng.random() < f:
            cx = rng.uniform(-largura / 3, largura / 3)
            juntar(energia, fita(arco_pontos(0.5 + 0.6 * f, 0, 2 * math.pi, 14), 0.1, z, cor_energia), Matrix.Translation((cx, y0 - passo / 2, 0)))
        elif tema == "arena" and k % 3 == 0 and f > 0.2:
            juntar(energia, fita([(-largura / 2 + 0.6, y0 - 1.2), (-1.0, y0 - 1.2)], 0.12 + 0.15 * f, z, cor_energia))
            juntar(energia, fita([(1.0, y0 - 1.2), (largura / 2 - 0.6, y0 - 1.2)], 0.12 + 0.15 * f, z, cor_energia))
    # Bordas de pedra baixa nos dois lados (somem no jardim e nos portais perto do destino)
    for lado in (-1, 1):
        for k in range(0, fileiras, 2):
            f = k / max(fileiras - 1, 1)
            if tema in ("jardim", "portais") and rng.random() < f:
                continue
            largura = 10 + 4 * f
            juntar(pedra, bloco(0.7, passo * 2 - 0.2, 0.55, rng, misturar(PEDRA, TEMAS[tema][0], f), chanfro=0.08), Matrix.Translation((lado * (largura / 2 + 0.4), -k * passo - passo, 0.27)))
    return pedra, energia


# ---------------------------------------------------------------- registro e montagem

def fazer_poste_caminho():
    rng = random.Random(1951)
    perfil = [(0.63, 0.0), (0.63, 0.18), (0.29, 0.32), (0.20, 2.95), (0.40, 3.12)]
    bm = torno(perfil, 8, METAL, rng)
    juntar(bm, torno([(0.41, 3.63), (0.35, 3.78), (0.14, 3.94)], 8, METAL, rng))
    return bm


def fazer_luz_caminho():
    perfil = [(0.28, 3.08), (0.38, 3.20), (0.38, 3.57), (0.28, 3.69)]
    return torno(perfil, 8, (1.0, 0.90, 0.68), random.Random(1952), tinta=1.0)


def fazer_canteiro():
    rng = random.Random(1953)
    bm = novo_bm()
    lados = 20
    raios = [rng.uniform(0.86, 1.06) for _ in range(lados)]
    aneis = []
    for escala, z in ((10.0, 0.03), (9.7, 0.16), (7.8, 0.22)):
        anel = []
        for i, r in enumerate(raios):
            a = 2 * math.pi * i / lados
            anel.append(bm.verts.new((r * escala * math.cos(a), r * escala * math.sin(a), z)))
        aneis.append(anel)
    for baixo, alto in zip(aneis, aneis[1:]):
        for i in range(lados):
            j = (i + 1) % lados
            bm.faces.new((baixo[i], baixo[j], alto[j], alto[i]))
    centro = bm.verts.new((0.0, 0.0, 0.24))
    for i in range(lados):
        bm.faces.new((centro, aneis[-1][i], aneis[-1][(i + 1) % lados]))
    camada = bm.loops.layers.color["Col"]
    for face in bm.faces:
        cor = misturar(GRAMA, MUSGO, rng.uniform(0, 0.65))
        for loop in face.loops:
            loop[camada] = (*cor, 1.0)
    return bm


def fazer_brotos_canteiro():
    rng = random.Random(1954)
    bm = novo_bm()
    for i in range(17):
        a = i * math.radians(137.508) + rng.uniform(-0.2, 0.2)
        r = rng.uniform(2.4, 7.6)
        x, y = r * math.cos(a), r * math.sin(a)
        largura = rng.uniform(0.12, 0.30)
        altura = rng.uniform(0.24, 0.78)
        pontos = [
            (x - largura, y, 0.24), (x + largura, y, 0.24),
            (x, y - largura, 0.24), (x, y + largura, 0.24),
            (x + 0.10, y, 0.24 + altura),
        ]
        cor = misturar((1.0, 0.95, 0.74), (0.58, 1.0, 0.78), rng.random())
        juntar(bm, casco(pontos, cor))
    return bm


# ---------------------------------------------------------------- Bastião das Incursões
# Base de preparação para expedições a universos destruídos, entre os Portais e a Arena.
# Pedra cinza com veios CIANO (os Portais são violeta). O portal é uma ferida na realidade:
# arco assimétrico e rachado, vazio escuro no meio e ruínas distantes lá dentro.

BASTIAO = (157, 173)  # (graus, distância) — o servidor usa os mesmos valores
BASTIAO_PEDRA = (0.36, 0.38, 0.44)
BASTIAO_ESCURA = (0.25, 0.27, 0.32)
VAZIO = (0.02, 0.03, 0.06)


def zigue(a, b, n, desvio, rng):
    """Linha rachada de a até b (pontos 2D), com n trechos."""
    a, b = Vector(a), Vector(b)
    d = b - a
    lado = Vector((-d.y, d.x)).normalized()
    return [tuple(a + d * (i / n) + lado * (rng.uniform(-desvio, desvio) if 0 < i < n else 0)) for i in range(n + 1)]


def chapa(pontos, cor, tinta=1.0, dupla=False):
    """Polígono plano (leque a partir do centro) com os pontos 3D dados."""
    bm = novo_bm()
    c = sum((Vector(q) for q in pontos), Vector()) / len(pontos)
    vc = bm.verts.new(c)
    vs = [bm.verts.new(q) for q in pontos]
    for i in range(len(vs)):
        bm.faces.new((vc, vs[i], vs[(i + 1) % len(vs)]))
    if dupla:
        vc2 = bm.verts.new(c)
        vs2 = [bm.verts.new(q) for q in pontos]
        for i in range(len(vs2)):
            bm.faces.new((vc2, vs2[(i + 1) % len(vs2)], vs2[i]))
    pintar(bm, cor, tinta, topo_claro=0.0)
    return bm


def espinho(base, ponta, largura, cor, tinta=1.0, chanfro=0.0):
    """Lâmina/pirâmide de 4 lados da base até a ponta."""
    b, t = Vector(base), Vector(ponta)
    eixo = (t - b).normalized()
    u = eixo.orthogonal().normalized()
    v = eixo.cross(u)
    pts = [tuple(b + (u * sx + v * sy) * largura / 2) for sx, sy in ((1, 1), (1, -1), (-1, -1), (-1, 1))] + [tuple(t)]
    return casco(pts, cor, tinta, chanfro=chanfro)


def fazer_incursao_base():
    rng = random.Random(2101)
    bm = novo_bm()
    juntar(bm, torno([(21.5, 0), (20.2, 0.8), (0.4, 0.8)], 40, BASTIAO_ESCURA, rng, tinta=0.95))
    for r0, r1, n in ((3.6, 9, 11), (9, 15, 17), (15, 19.8, 23)):
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            borda = r1 > 19
            if borda and rng.random() < 0.18:
                continue  # placa que falta: a borda está fraturada
            sobe = rng.uniform(0.0, 0.28) if borda else rng.uniform(0, 0.06)
            juntar(bm, laje(r0, r1, a0, a1, 0.86 + sobe, rng, BASTIAO_PEDRA, folga=0.09 + (0.12 if borda else 0)))
    # estrado do portal, no fundo (-Y)
    juntar(bm, bloco(17, 5.2, 0.6, rng, BASTIAO_ESCURA, chanfro=0.14), Matrix.Translation((0, -11, 1.1)))
    juntar(bm, bloco(12, 1.4, 0.3, rng, BASTIAO_PEDRA, chanfro=0.1), Matrix.Translation((0, -8.0, 0.95)))  # degrau baixo
    return bm


def fazer_incursao_energia():
    """Fissuras ciano no piso: irradiam do portal e cercam a mesa."""
    rng = random.Random(2102)
    bm = novo_bm()
    for k, a in enumerate((-150, -115, -80, -40, 0, 35, 75, 110, 150)):
        r = math.radians(a + 90)
        fim = (19.2 * math.cos(r), 19.2 * math.sin(r))
        juntar(bm, fita(zigue((0, -7.6), fim, 7, 0.9, rng), 0.2 if k % 2 else 0.3, 0.93, CIANO))
    juntar(bm, fita(arco_pontos(4.3, 0, 2 * math.pi, 28), 0.22, 0.93, CIANO))
    return bm


def contorno_fenda():
    """Contorno irregular do rasgo (x, z), no sentido anti-horário visto de frente."""
    rng = random.Random(2103)
    pts = []
    n = 26
    for i in range(n):
        a = 2 * math.pi * i / n
        rx, rz = 5.0, 7.2
        j = rng.uniform(0.72, 1.08) if i % 2 else rng.uniform(0.95, 1.18)
        pts.append((rx * math.cos(a) * j + 0.5 * math.sin(a * 2), 8.4 + rz * math.sin(a) * j))
    return pts


def fazer_incursao_portal():
    """Arco assimétrico e rachado: pilar esquerdo inteiro, direito partido e inclinado, aduelas
    desalinhadas com vãos (as peças soltas que boiam são instâncias à parte na cena)."""
    rng = random.Random(2104)
    bm = novo_bm()
    # pilar esquerdo: alto, quase inteiro
    z = 0.0
    while z < 15.0:
        h = rng.uniform(1.9, 2.6)
        f = z / 15.0
        juntar(bm, bloco(3.9 - 0.9 * f, 3.6 - 0.6 * f, h - 0.07, rng, BASTIAO_PEDRA, chanfro=0.14), Matrix.Translation((-7.2 + 0.5 * f + rng.uniform(-0.08, 0.08), 0, z + h / 2)))
        z += h
    # pilar direito: partido aos 9,5 e inclinado para fora
    z = 0.0
    while z < 9.5:
        h = rng.uniform(1.9, 2.5)
        f = z / 9.5
        m = Matrix.Translation((7.2 + 0.9 * f * f, 0, z + h / 2)) @ Matrix.Rotation(math.radians(-7 * f), 4, "Y")
        juntar(bm, bloco(3.8 - 0.6 * f, 3.6 - 0.5 * f, h - 0.07, rng, BASTIAO_PEDRA, chanfro=0.14), m)
        z += h
    # aduelas: saem do topo do pilar esquerdo e se perdem antes de fechar o arco
    arco = [(-6.6, 16.2, 12), (-5.2, 18.1, 30), (-3.0, 19.5, 52), (-0.4, 20.2, 76), (2.6, 19.9, 104)]
    for i, (x, zc, giro) in enumerate(arco):
        solto = i * 0.07
        m = Matrix.Translation((x + rng.uniform(-solto, solto) * 3, rng.uniform(-solto, solto) * 4, zc + rng.uniform(-solto, solto) * 2)) @ Matrix.Rotation(math.radians(giro + rng.uniform(-6, 6) * i), 4, "Y")
        juntar(bm, bloco(2.3 - 0.12 * i, 3.0 - 0.2 * i, 2.5, rng, BASTIAO_PEDRA, chanfro=0.14), m)
    # garras de pedra nos pés (contrafortes quebrados)
    for lado in (-1, 1):
        juntar(bm, bloco(2.6, 2.2, 1.4, rng, BASTIAO_ESCURA, chanfro=0.14), Matrix.Translation((lado * 9.6, 0.6, 0.7)) @ Matrix.Rotation(math.radians(lado * 12), 4, "Z"))
    return bm


def fazer_incursao_vazio():
    """O vazio dentro do rasgo (recuado): quase preto, com as duas faces."""
    return chapa([(x, -1.25, z) for x, z in contorno_fenda()], VAZIO, dupla=True)


def fazer_incursao_fenda():
    """Bordas luminosas do rasgo e rachaduras que escapam dele."""
    rng = random.Random(2105)
    bm = novo_bm()
    pts = contorno_fenda()
    juntar(bm, fita3d([(x, 0.0, z) for x, z in pts + pts[:1]], 0.34, (0, 1, 0), CIANO))
    for i in (1, 4, 8, 11, 15, 18, 22):
        x, z = pts[i]
        fora = Vector((x, z - 8.4)).normalized()
        fim = (x + fora.x * rng.uniform(1.6, 3.2), z + fora.y * rng.uniform(1.6, 3.2))
        juntar(bm, fita3d([(q[0], 0.0, q[1]) for q in zigue((x, z), fim, 4, 0.35, rng)], 0.16, (0, 1, 0), CIANO))
    return bm


def fazer_incursao_ruinas():
    """Um mundo em ruína visto pelo rasgo: silhuetas em duas profundidades (paralaxe)."""
    rng = random.Random(2106)
    bm = novo_bm()
    for y, cor, torres in ((-0.95, (0.06, 0.10, 0.17), 6), (-0.45, (0.11, 0.19, 0.30), 4)):
        for k in range(torres):
            x = -3.6 + 7.2 * (k + rng.uniform(0.2, 0.8)) / torres
            larg = rng.uniform(0.7, 1.3)
            alt = rng.uniform(3.5, 8.5)
            inclina = rng.uniform(-0.9, 0.9)
            base = 2.4 + rng.uniform(0, 1.2)
            topo = base + alt
            pts = [(x - larg / 2, y, base), (x + larg / 2, y, base), (x + larg / 2 + inclina, y, topo - rng.uniform(0.3, 1.4)), (x + inclina, y, topo), (x - larg / 2 + inclina, y, topo - rng.uniform(0.6, 2.0))]
            juntar(bm, chapa(pts, cor))
        # destroços soltos no ar
        for k in range(5):
            cx, cz = rng.uniform(-3.5, 3.5), rng.uniform(6, 13.5)
            t = rng.uniform(0.25, 0.6)
            g = rng.uniform(0, 3)
            juntar(bm, chapa([(cx + t * math.cos(g + q), y + 0.02, cz + t * math.sin(g + q)) for q in (0, 1.7, 3.3, 4.9)], cor, 1.15))
    return bm


def fazer_marco():
    """Moldura de pedra de um marco de universo: dois montantes, verga torta e soleira."""
    rng = random.Random(2107)
    bm = novo_bm()
    juntar(bm, bloco(4.6, 1.7, 0.5, rng, BASTIAO_ESCURA, chanfro=0.1), Matrix.Translation((0, 0, 0.25)))
    for lado in (-1, 1):
        juntar(bm, bloco(0.75, 0.9, 5.0, rng, BASTIAO_PEDRA, chanfro=0.1), Matrix.Translation((lado * 1.7, 0, 3.0)))
    juntar(bm, bloco(4.4, 1.0, 0.7, rng, BASTIAO_PEDRA, chanfro=0.1), Matrix.Translation((0.1, 0, 5.8)) @ Matrix.Rotation(math.radians(4), 4, "Y"))
    return bm


def fazer_marco_painel(tema):
    """Janela de prévia de um universo futuro (só imagem: nada de teleporte)."""
    rng = random.Random(2110 + len(tema))
    bm = novo_bm()
    cor = {"cinzas": (1.0, 0.30, 0.12), "mare": (0.25, 0.60, 1.0), "umbral": (0.55, 0.22, 0.95)}[tema]
    escura = tuple(c * 0.16 for c in cor)
    juntar(bm, chapa([(-1.3, 0.0, 0.55), (1.3, 0.0, 0.55), (1.3, 0.0, 5.4), (-1.3, 0.0, 5.4)], escura, dupla=True))
    y = 0.06
    if tema == "cinzas":  # ruínas avermelhadas e brasas
        for k in range(4):
            x = -1.0 + 0.65 * k
            h = rng.uniform(1.2, 2.8)
            juntar(bm, chapa([(x - 0.25, y, 0.6), (x + 0.3, y, 0.6), (x + 0.3, y, 0.6 + h * 0.8), (x, y, 0.6 + h), (x - 0.25, y, 0.6 + h * 0.6)], cor, 0.55))
        for k in range(9):
            cx, cz, t = rng.uniform(-1.1, 1.1), rng.uniform(2.6, 5.1), rng.uniform(0.05, 0.11)
            juntar(bm, chapa([(cx - t, y, cz), (cx, y, cz - t), (cx + t, y, cz), (cx, y, cz + t)], cor))
    elif tema == "mare":  # pilares submersos e reflexos frios
        for k in range(3):
            x = -0.85 + 0.85 * k
            h = rng.uniform(2.0, 3.6)
            juntar(bm, chapa([(x - 0.22, y, 0.6), (x + 0.22, y, 0.6), (x + 0.22, y, 0.6 + h), (x - 0.22, y, 0.6 + h - 0.4)], cor, 0.5))
        for k in range(5):
            z = 1.0 + 0.55 * k
            juntar(bm, fita3d([(-1.2 + 0.3 * i, y + 0.02, z + 0.07 * math.sin(i * 1.4 + k)) for i in range(9)], 0.07, (0, 1, 0), cor))
    else:  # umbral: fragmentos roxos e formas de sombra
        for k in range(5):
            x = -1.0 + 0.5 * k
            h = rng.uniform(1.5, 4.2)
            juntar(bm, chapa([(x - 0.3, y, 0.6), (x + 0.3, y, 0.6), (x + rng.uniform(-0.3, 0.3), y, 0.6 + h)], cor, 0.45))
        for k in range(2):
            cx, cz = -0.45 + 0.9 * k, 4.3
            juntar(bm, chapa([(cx - 0.22, y, cz), (cx, y, cz - 0.07), (cx + 0.22, y, cz + 0.05), (cx, y, cz + 0.1)], cor))
    return bm


def fazer_incursao_mesa():
    """Mesa dos Cartógrafos: pedestal e tampo com um mapa rachado."""
    rng = random.Random(2108)
    bm = novo_bm()
    juntar(bm, torno([(2.4, 0), (1.7, 0.45), (1.3, 2.0), (3.2, 2.35), (3.2, 2.7), (0.3, 2.7)], 12, BASTIAO_ESCURA, rng))
    for i in range(6):
        a0, a1 = 2 * math.pi * i / 6, 2 * math.pi * (i + 1) / 6
        juntar(bm, laje(0.25, 3.0, a0, a1, 2.82 + rng.uniform(0, 0.08), rng, BASTIAO_PEDRA, folga=0.1, saia=0.1))
    return bm


def fazer_incursao_mesa_energia():
    rng = random.Random(2109)
    bm = novo_bm()
    z = 2.96
    juntar(bm, fita(arco_pontos(2.55, 0, 2 * math.pi, 24), 0.12, z, CIANO))
    alvos = [(-1.6, 0.9), (1.4, 1.3), (0.5, -1.8)]
    for x, y in alvos:
        juntar(bm, fita(zigue((0, 0), (x, y), 4, 0.25, rng), 0.09, z, CIANO))
        juntar(bm, losango(x, y, z, 0.32, OURO, rng.uniform(0, 3)))
    # ponteiros de metal
    juntar(bm, espinho((0, 0, 2.9), (0.9, -0.4, 3.9), 0.22, OURO, 0.9))
    juntar(bm, espinho((0, 0, 2.9), (-0.6, 0.5, 3.6), 0.18, OURO, 0.9))
    return bm


RAMAL_COMPRIMENTO = 22.0


def fazer_ramal():
    """Ramal curto Portais -> Bastião (ao longo de +Y): a pedra violeta dá lugar à cinza com veios
    azuis, e as lajes vão ficando mais soltas."""
    rng = random.Random(2111)
    pedra, energia = novo_bm(), novo_bm()
    n = 8
    passo = RAMAL_COMPRIMENTO / n
    violeta_pedra = misturar(ROCHA, VIOLETA, 0.22)
    for i in range(n):
        f = i / (n - 1)
        cor = misturar(violeta_pedra, BASTIAO_PEDRA, f)
        for lado in (-1, 1):
            m = Matrix.Translation((lado * 2.45 + rng.uniform(-0.25, 0.25) * f, (i + 0.5) * passo, 0.2 + rng.uniform(0, 0.1) * f)) @ Matrix.Rotation(math.radians(rng.uniform(-7, 7) * f), 4, "Z")
            juntar(pedra, bloco(4.6, passo - 0.25, 0.4, rng, cor, chanfro=0.09), m)
    meio = RAMAL_COMPRIMENTO / 2
    juntar(energia, fita(zigue((0, 0.4), (0, meio), 5, 0.45, rng), 0.2, 0.44, VIOLETA))
    juntar(energia, fita(zigue((0, meio), (0, RAMAL_COMPRIMENTO - 0.4), 5, 0.6, rng), 0.22, 0.44, CIANO))
    return pedra, energia


# ---------------------------------------------------------------- Arena do Trono
# A arena existente ganha um eixo: portão -> campo de batalha -> trono. Basalto, metal envelhecido,
# vermelho profundo e ouro antigo. Formas originais (nenhum símbolo de franquia).

BASALTO = (0.17, 0.16, 0.21)
BASALTO_CLARO = (0.26, 0.24, 0.31)
ACO = (0.30, 0.27, 0.31)
RUBRO = (0.74, 0.13, 0.17)
OURO_ANTIGO = (0.77, 0.64, 0.43)


def fazer_trono_plataforma():
    """Três degraus baixos no fundo da arena (o trono fica em cima)."""
    rng = random.Random(2201)
    bm = novo_bm()
    for k, (sx, sy, dy) in enumerate(((16, 10, 0.0), (13, 8, -0.7), (10, 6, -1.4))):
        juntar(bm, bloco(sx, sy, 0.5, rng, BASALTO_CLARO if k < 2 else BASALTO, chanfro=0.12), Matrix.Translation((0, dy, 0.25 + 0.5 * k)))
    for lado in (-1, 1):  # blocos-guarda nos cantos
        juntar(bm, bloco(1.6, 1.6, 1.9, rng, BASALTO, chanfro=0.14), Matrix.Translation((lado * 7.0, -3.6, 0.95)))
    return bm


LAMINAS_TRONO = [(-2.3, 2.6), (-1.45, 4.6), (-0.55, 6.6), (0.5, 5.4), (1.4, 3.8), (2.3, 1.9)]  # (x, altura): assimétricas


def fazer_trono():
    """Trono do Primeiro Soberano: assento largo, braços, encosto alto com seis lâminas de pedra."""
    rng = random.Random(2202)
    bm = novo_bm()
    juntar(bm, bloco(5.0, 3.8, 1.7, rng, BASALTO, chanfro=0.14), Matrix.Translation((0, 0.2, 0.85)))
    for lado in (-1, 1):
        juntar(bm, bloco(1.1, 4.0, 2.9, rng, BASALTO, chanfro=0.14), Matrix.Translation((lado * 3.0, 0.2, 1.45)))
        juntar(bm, bloco(1.3, 1.2, 0.5, rng, BASALTO_CLARO, chanfro=0.1), Matrix.Translation((lado * 3.0, 1.9, 3.1)))
        # aletas laterais do encosto
        juntar(bm, bloco(1.0, 1.0, 6.5, rng, BASALTO, chanfro=0.14), Matrix.Translation((lado * 3.3, -1.9, 4.6)) @ Matrix.Rotation(math.radians(-lado * 9), 4, "Y"))
    juntar(bm, tronco_quadrado(5.8, 5.0, 0.0, 9.2, rng, BASALTO, chanfro=0.14), Matrix.Translation((0, -1.9, 0)) @ Matrix.Scale(0.24, 4, (0, 1, 0)))
    for x, alt in LAMINAS_TRONO:
        juntar(bm, espinho((x, -1.9, 8.8), (x + 0.12 * x, -2.1, 9.2 + alt), 0.95, BASALTO, rng.uniform(0.9, 1.1), chanfro=0.05))
    return bm


def fazer_trono_metal():
    """Espinha de metal envelhecido no encosto, cintas e ponteiras dos braços."""
    rng = random.Random(2203)
    bm = novo_bm()
    for k in range(9):
        z = 2.4 + k * 0.78
        juntar(bm, bloco(1.0 - 0.05 * k, 0.5, 0.55, rng, ACO, chanfro=0.07, tremor=0.01), Matrix.Translation((0, -1.2, z)))
        if k % 2 == 0:
            for lado in (-1, 1):
                juntar(bm, espinho((lado * 0.45, -1.2, z), (lado * (1.5 + 0.1 * k), -1.25, z + 0.35), 0.3, ACO, 1.0))
    for z in (0.3, 1.6):
        juntar(bm, bloco(5.2, 0.25, 0.3, rng, ACO, chanfro=0.05, tremor=0.01), Matrix.Translation((0, 2.15, z)))
    for lado in (-1, 1):
        juntar(bm, espinho((lado * 3.0, 2.3, 3.2), (lado * 3.0, 3.3, 3.6), 0.6, ACO, 1.0))
    return bm


def fazer_trono_energia():
    """Fendas vermelhas discretas no encosto e nos degraus."""
    rng = random.Random(2204)
    bm = novo_bm()
    y = -1.18
    for lado in (-1, 1):
        for z0, z1, x1 in ((3.0, 4.6, 2.3), (5.2, 7.4, 2.0), (7.0, 8.9, 1.2)):
            linha = zigue((lado * 0.75, z0), (lado * x1, z1), 4, 0.22, rng)
            juntar(bm, fita3d([(q[0], y, q[1]) for q in linha], 0.13, (0, 1, 0), RUBRO))
    for x, alt in LAMINAS_TRONO[1:5]:
        juntar(bm, fita3d([(x * 1.02, -1.42, 9.0), (x * 1.08, -1.5, 9.0 + alt * 0.55)], 0.1, (0, 1, 0), RUBRO))
    return bm


def fazer_trono_coroa():
    """Coroa flutuante sobre o trono: aro com seis pontas irregulares (forma própria)."""
    rng = random.Random(2205)
    bm = novo_bm()
    juntar(bm, torno([(1.75, 0), (1.9, 0.25), (1.75, 0.6), (1.5, 0.6), (1.4, 0.25), (1.5, 0)], 18, OURO_ANTIGO, rng))
    for k, alt in enumerate((2.4, 1.3, 1.9, 1.1, 2.1, 1.5)):
        a = 2 * math.pi * k / 6 + math.pi / 2
        c, s_ = math.cos(a), math.sin(a)
        juntar(bm, espinho((1.65 * c, 1.65 * s_, 0.5), (1.9 * c, 1.9 * s_, 0.5 + alt), 0.7, OURO_ANTIGO, rng.uniform(0.85, 1.05)))
    return bm


def fazer_arena_trono_energia():
    """Piso: fissuras que irradiam do trono, divisas apontando para o centro e os dois círculos
    dos desafiantes."""
    rng = random.Random(2206)
    bm = novo_bm()
    z = 0.74
    origem = (0, -12.6)  # pé da plataforma do trono (fundo = -Y)
    for a in (-62, -38, -14, 10, 34, 58):
        r = math.radians(a + 90)
        comp = rng.uniform(13, 21)
        fim = (origem[0] + comp * math.cos(r), origem[1] + comp * math.sin(r))
        juntar(bm, fita(zigue(origem, fim, 7, 0.55, rng), 0.2, z, RUBRO))
    for k in range(6):  # divisas (chevrons) num anel
        a = 2 * math.pi * k / 6 + math.pi / 6
        c, s_ = math.cos(a), math.sin(a)
        p0 = (20.5 * c - 1.3 * s_, 20.5 * s_ + 1.3 * c)
        p1 = (19.0 * c, 19.0 * s_)
        p2 = (20.5 * c + 1.3 * s_, 20.5 * s_ - 1.3 * c)
        juntar(bm, fita([p0, p1, p2], 0.22, z, OURO_ANTIGO))
    for lado in (-1, 1):  # onde cada desafiante se posiciona
        pts = [(lado * 7 + 1.9 * math.cos(q), 1.9 * math.sin(q)) for q in (2 * math.pi * i / 20 for i in range(21))]
        juntar(bm, fita(pts, 0.16, z + 0.32, OURO_ANTIGO))
    return bm


def fazer_arena_pedestal():
    rng = random.Random(2207)
    return torno([(2.4, 0), (2.1, 0.3), (0.3, 0.3)], 10, BASALTO_CLARO, rng)


def fazer_arena_portao():
    """Portão de entrada: duas colunas monumentais curvas para dentro, com garra no topo e uma
    placa de pedra pendurada em corrente."""
    rng = random.Random(2208)
    bm = novo_bm()
    for lado in (-1, 1):
        z = 0.0
        juntar(bm, bloco(4.2, 4.2, 1.0, rng, BASALTO_CLARO, chanfro=0.14), Matrix.Translation((lado * 8.6, 0, 0.5)))
        z = 1.0
        while z < 16.5:
            h = rng.uniform(2.0, 2.6)
            f = z / 16.5
            dentro = 2.6 * f * f  # curva para o vão
            m = Matrix.Translation((lado * (8.6 - dentro), 0, z + h / 2)) @ Matrix.Rotation(math.radians(lado * 14 * f), 4, "Y")
            juntar(bm, bloco(3.2 - 1.1 * f, 3.2 - 1.0 * f, h - 0.07, rng, BASALTO, chanfro=0.14), m)
            z += h
        juntar(bm, espinho((lado * 6.0, 0, 16.6), (lado * 3.6, 0, 19.4), 1.5, BASALTO, 1.0, chanfro=0.06))  # garra
        juntar(bm, espinho((lado * 8.9, 0, 9.0), (lado * 11.2, 0, 11.0), 1.2, BASALTO, 1.0, chanfro=0.06))  # esporão
        for k in range(5):  # corrente
            juntar(bm, bloco(0.3, 0.3, 0.55, rng, ACO, chanfro=0.05, tremor=0.0), Matrix.Translation((lado * 5.0, 0, 15.6 - 0.62 * k)))
        juntar(bm, bloco(1.9, 0.35, 2.6, rng, BASALTO_CLARO, chanfro=0.08), Matrix.Translation((lado * 5.0, 0, 11.3)))
    return bm


def fazer_arena_portao_energia():
    rng = random.Random(2209)
    bm = novo_bm()
    for lado in (-1, 1):
        for y in (2.14, -2.14):
            n = (0, 1, 0) if y > 0 else (0, -1, 0)
            juntar(bm, fita3d([(lado * 7.0, y, 0.55), (lado * 10.2, y, 0.55)], 0.2, n, RUBRO))
            juntar(bm, fita3d([(q[0], y * 0.105, q[1]) for q in zigue((lado * 5.0, 10.4), (lado * 5.0, 12.2), 3, 0.3, rng)], 0.14, n, RUBRO))
    return bm


def fazer_braseiro():
    rng = random.Random(2210)
    return torno([(1.3, 0), (0.85, 0.35), (0.6, 2.2), (1.55, 2.8), (1.55, 3.05), (1.1, 3.05), (0.9, 2.8)], 8, BASALTO, rng, estrela=0.08)


def fazer_braseiro_chama():
    """Cristal espiritual vermelho no lugar do fogo (luz baixa, sem lavar a tela)."""
    rng = random.Random(2211)
    bm = novo_bm()
    for k, (dx, dy, alt, larg) in enumerate(((0, 0, 2.3, 0.8), (0.4, 0.2, 1.4, 0.55), (-0.35, 0.3, 1.6, 0.5), (0.05, -0.45, 1.2, 0.5))):
        juntar(bm, espinho((dx, dy, 0.0), (dx * 1.6, dy * 1.6, alt), larg, RUBRO, rng.uniform(0.85, 1.1)))
    return bm


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
    if mat.node_tree is None:
        mat.use_nodes = True
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
    registrar("caminho_poste", fazer_poste_caminho(), metal)
    registrar("caminho_luz", fazer_luz_caminho(), energia)
    registrar("campo_canteiro", fazer_canteiro(), pedra)
    registrar("campo_brotos", fazer_brotos_canteiro(), energia)

    # Locais em volta da praça
    registrar("arquivo_base", fazer_arquivo_base(), pedra)
    registrar("arquivo_coluna", fazer_arquivo_coluna(), pedra)
    registrar("arquivo_estrutura", fazer_arquivo_estrutura(), pedra)
    registrar("arquivo_energia", fazer_arquivo_energia(), energia)
    registrar("arquivo_console", fazer_arquivo_console(), pedra)
    registrar("arquivo_projecao", fazer_projecao(), cristal)
    registrar("obelisco_base", fazer_obelisco_base(), pedra)
    registrar("obelisco_fuste", fazer_obelisco_fuste(), pedra)
    registrar("obelisco_ponta", fazer_obelisco_ponta(), metal)
    registrar("obelisco_energia", fazer_obelisco_energia(), energia)
    registrar("obelisco_pilone", fazer_pilone(), pedra)
    registrar("obelisco_moldura", fazer_moldura_ranking(), pedra)
    registrar("jardim_chao", fazer_jardim_chao(), pedra)
    registrar("jardim_energia", fazer_jardim_energia(), energia)
    registrar("jardim_passagem", fazer_passagem(), pedra)
    registrar("arvore_tronco", fazer_arvore_tronco(), pedra)
    registrar("arvore_copa", fazer_arvore_copa(), cristal)
    registrar("cristal_aglomerado_a", fazer_aglomerado(1311), cristal)
    registrar("cristal_aglomerado_b", fazer_aglomerado(1312), cristal)
    registrar("altar_base", fazer_altar_base(), pedra)
    registrar("altar_energia", fazer_altar_energia(), energia)
    registrar("altar_mesa", fazer_altar_mesa(), pedra)
    registrar("altar_halo", fazer_altar_halo(), pedra)
    registrar("altar_monolito_a", fazer_monolito(1511), pedra)
    registrar("altar_monolito_b", fazer_monolito(1512), pedra)
    registrar("altar_monolito_runa", fazer_monolito_runa(), energia)
    registrar("portais_base", fazer_portais_base(), pedra)
    registrar("portal_moldura", fazer_portal(False), pedra)
    registrar("portal_quebrado", fazer_portal(True), pedra)
    registrar("portal_runas", fazer_portal_runas(False), energia)
    registrar("portal_runas_quebrado", fazer_portal_runas(True), energia)
    registrar("arena_piso", fazer_arena_piso(), pedra)
    registrar("arena_arquibancada", fazer_arena_arquibancada(), pedra)
    registrar("arena_estandarte", fazer_estandarte(), pedra)
    registrar("arena_energia", fazer_arena_energia(), energia)
    # Arena do Trono
    registrar("trono_plataforma", fazer_trono_plataforma(), pedra)
    registrar("trono_assento", fazer_trono(), pedra)
    registrar("trono_metal", fazer_trono_metal(), metal)
    registrar("trono_energia", fazer_trono_energia(), energia)
    registrar("trono_coroa", fazer_trono_coroa(), energia)
    registrar("arena_trono_energia", fazer_arena_trono_energia(), energia)
    registrar("arena_pedestal", fazer_arena_pedestal(), pedra)
    registrar("arena_portao", fazer_arena_portao(), pedra)
    registrar("arena_portao_energia", fazer_arena_portao_energia(), energia)
    registrar("arena_braseiro", fazer_braseiro(), pedra)
    registrar("arena_braseiro_chama", fazer_braseiro_chama(), energia)
    # Bastião das Incursões
    registrar("incursao_base", fazer_incursao_base(), pedra)
    registrar("incursao_energia", fazer_incursao_energia(), energia)
    registrar("incursao_portal", fazer_incursao_portal(), pedra)
    registrar("incursao_vazio", fazer_incursao_vazio(), energia)
    registrar("incursao_fenda", fazer_incursao_fenda(), energia)
    registrar("incursao_ruinas", fazer_incursao_ruinas(), energia)
    registrar("incursao_marco", fazer_marco(), pedra)
    for tema in ("cinzas", "mare", "umbral"):
        registrar("incursao_marco_" + tema, fazer_marco_painel(tema), energia)
    registrar("incursao_mesa", fazer_incursao_mesa(), pedra)
    registrar("incursao_mesa_energia", fazer_incursao_mesa_energia(), energia)
    pedra_r, energia_r = fazer_ramal()
    registrar("caminho_ramal", pedra_r, pedra)
    registrar("caminho_ramal_energia", energia_r, energia)
    registrar("penhasco_a", fazer_penhasco(1801, 30, 82, 16), pedra)
    registrar("penhasco_b", fazer_penhasco(1802, 30, 90, 16), pedra)
    registrar("penhasco_c", fazer_penhasco(1803, 44, 125, 22), pedra)
    for i, (tema, (graus, dist)) in enumerate(sorted(LOCAIS.items())):
        comprimento = dist - BORDAS[tema] - INICIO_CAMINHO
        pedra_c, energia_c = fazer_caminho(tema, comprimento, 1900 + i)
        registrar("caminho_" + tema, pedra_c, pedra)
        registrar("caminho_" + tema + "_energia", energia_c, energia)


# Montagem da praça em coordenadas do ROBLOX (studs; Y para cima; norte = -Z; topo da praça em y = 1).
# material: nome de Enum.Material. grupo: papel da peça na animação do Núcleo.
# colisores: caixas simples {centro local, tamanho} em coordenadas do Roblox, relativas ao pivô.
TOPO = 1.0
CENTRO_CRISTAL = (0.0, 15.5, 0.0)

# Locais: (ângulo em graus a partir do norte, sentido horário; distância ao centro).
# ATENÇÃO: src/server/Mundo/Nexo.luau usa os mesmos valores (colisão e partes funcionais).
LOCAIS = {
    "obelisco": (0, 150),
    "altar": (45, 150),
    "portais": (135, 150),
    "arena": (180, 156),
    "jardim": (225, 150),
    "arquivo": (315, 150),
}
BORDAS = {"obelisco": 20, "altar": 22, "portais": 23, "arena": 25, "jardim": 33, "arquivo": 22}
INICIO_CAMINHO = 47  # onde os caminhos saem da praça
RAIO_PENHASCO = 244  # anel interno de penhascos; a parede invisível do servidor fica em 238


def mundo(graus, dist, lx=0.0, ly=0.0, lz=0.0):
    """Ponto do espaço LOCAL de um lugar (como o servidor usa: CFrame.lookAt(centro, origem),
    -Z local apontando para a praça) em coordenadas do mundo do Roblox."""
    g = math.radians(graus)
    t = math.radians(180 - graus)
    cx, cz = dist * math.sin(g), -dist * math.cos(g)
    return (cx + lx * math.cos(t) + lz * math.sin(t), ly, cz - lx * math.sin(t) + lz * math.cos(t))


def giro_de(graus, extra=0.0):
    """Giro (Y, graus) de uma peça cuja frente (+Y no Blender) olha para a praça."""
    return (180 - graus + extra) % 360


def polar_local(raio, a):
    """Posição local num círculo, com o ângulo `a` medido a partir da frente (lado da praça)."""
    r = math.radians(a)
    return raio * math.sin(r), -raio * math.cos(r)


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

    montar_locais(por, rng)
    montar_decoracao(por)
    montar_expansao(cena, por)
    return cena


def ramal_pontos():
    """Início (borda dos Portais) e direção do ramal até o Bastião, no mundo (x, z)."""
    p = mundo(*LOCAIS["portais"])
    b = mundo(*BASTIAO)
    d = Vector((b[0] - p[0], b[2] - p[2]))
    dist = d.length
    d.normalize()
    inicio = Vector((p[0], p[2])) + d * (dist - 21.3 - RAMAL_COMPRIMENTO)
    return inicio, d


def montar_expansao(cena, por):
    """Bastião das Incursões + Arena do Trono. Vem por último e tem o próprio sorteio, para não
    mexer em nada do que já estava no mapa."""
    rng = random.Random(2300)
    centro = mundo(*BASTIAO)
    inicio, d = ramal_pontos()

    # limpa o campo (rochas, cristais, canteiros) onde o Bastião e o ramal vão ficar
    campo = {"rocha_a", "rocha_b", "cristal_aglomerado_a", "cristal_aglomerado_b", "campo_canteiro", "campo_brotos", "arco_partido", "ruina_parede_b"}

    def ocupado(pos):
        q = Vector((pos[0], pos[2]))
        if (q - Vector((centro[0], centro[2]))).length < 31:
            return True
        t = min(max((q - inicio).dot(d), 0), RAMAL_COMPRIMENTO)
        return (q - (inicio + d * t)).length < 9

    cena[:] = [it for it in cena if not (it["malha"] in campo and ocupado(it["posicao"]))]

    def emb(lx, ly, lz, malha, extra_giro=0.0, **kw):
        return por(malha, mundo(BASTIAO[0], BASTIAO[1], lx, ly, lz), giro=giro_de(BASTIAO[0], extra_giro), **kw)

    # ---- Bastião
    emb(0, 0, 0, "incursao_base", colisores=[((0, 1.1, 11), (17, 0.6, 5.2))])
    emb(0, 0, 0, "incursao_energia", material="Neon")
    yp = 1.4
    emb(0, yp, 11, "incursao_portal", material="Basalt", colisores=[((-7, 7.5, 0), (4, 15, 3.6)), ((7.6, 4.8, 0), (4, 9.6, 3.6)), ((0, 7.5, 1.2), (10.5, 15, 0.6))])
    emb(0, yp, 11, "incursao_vazio", material="Neon")
    emb(0, yp, 11, "incursao_ruinas", material="Neon")
    emb(0, yp, 11, "incursao_fenda", material="Neon")
    # pedaços do arco que se soltaram e boiam, desalinhados
    for lx, ly, escala, malha in ((4.6, 19.5, 1.5, "rocha_b"), (7.4, 15.8, 1.9, "rocha_a"), (8.6, 12.6, 1.2, "rocha_b"), (-2.0, 22.6, 1.0, "rocha_b"), (10.6, 9.0, 0.9, "rocha_a"), (-9.8, 17.5, 0.8, "rocha_b")):
        emb(lx, yp + ly, 11 + rng.uniform(-0.8, 0.8), malha, extra_giro=rng.uniform(0, 360), escala=escala, material="Basalt", grupo="lanterna", fase=rng.uniform(0, 360))
    for lx, ly in ((-4.5, 5.0), (3.6, 9.5), (0.5, 16.0)):
        emb(lx, yp + ly, 9.6, "cristal_fragmento_c", extra_giro=rng.uniform(0, 360), material="Neon", grupo="lanterna", fase=rng.uniform(0, 360))
    # três marcos de universos futuros (a entrada, vinda dos Portais, fica em ~59 graus)
    colisor_marco = [((0, 3.0, 0), (4.6, 6.0, 1.7))]
    for a, tema in ((-100, "cinzas"), (-48, "mare"), (118, "umbral")):
        x, z = polar_local(15.5, a)
        emb(x, 0.85, z, "incursao_marco", extra_giro=180 - a, material="Basalt", colisores=colisor_marco)
        emb(x, 0.85, z, "incursao_marco_" + tema, extra_giro=180 - a, material="Neon")
    # Mesa dos Cartógrafos
    emb(0, 0.85, -3, "incursao_mesa", colisores=[((0, 1.4, 0), (5.0, 2.8, 5.0))])
    emb(0, 0.85, -3, "incursao_mesa_energia", material="Neon")
    for k in range(3):
        a = math.radians(120 * k + 20)
        emb(1.5 * math.cos(a), 0.85 + 4.6 + 0.5 * k, -3 + 1.5 * math.sin(a), "cristal_fragmento_c", extra_giro=120 * k, escala=0.5, material="Neon", grupo="lanterna", fase=120 * k)
    for lx, lz in ((-17.5, 6), (16.5, -9), (-12, -15.5), (13.5, 15)):
        emb(lx, 0.4, lz, "rocha_a", extra_giro=rng.uniform(0, 360), escala=rng.uniform(1.2, 1.8))
    # ramal Portais -> Bastião (a frente da peça, +Y, aponta para o Bastião)
    giro_ramal = math.degrees(math.atan2(-d.x, -d.y)) % 360
    por("caminho_ramal", (inicio.x, 0.0, inicio.y), giro=giro_ramal)
    por("caminho_ramal_energia", (inicio.x, 0.0, inicio.y), giro=giro_ramal, material="Neon")

    # ---- Arena do Trono (o trono fica no fundo: +Z local, oposto à entrada)
    def ema(lx, ly, lz, malha, extra_giro=0.0, **kw):
        g, dist = LOCAIS["arena"]
        return por(malha, mundo(g, dist, lx, ly, lz), giro=giro_de(g, extra_giro), **kw)

    piso = 0.6
    ema(0, piso, 17.4, "trono_plataforma", material="Basalt", colisores=[((0, 0.25, 0), (16, 0.5, 10)), ((0, 0.75, 0.7), (13, 0.5, 8)), ((0, 1.25, 1.4), (10, 0.5, 6))])
    yt = piso + 1.5
    colisor_trono = [((0, 1.45, -0.2), (7.2, 2.9, 4.0)), ((0, 5.0, 1.9), (6.6, 10.0, 1.6))]
    ema(0, yt, 19.4, "trono_assento", material="Basalt", colisores=colisor_trono)
    ema(0, yt, 19.4, "trono_metal", material="Metal")
    ema(0, yt, 19.4, "trono_energia", material="Neon")
    ema(0, yt + 18.5, 20.8, "trono_coroa", material="Neon", grupo="gira", velocidade=0.25)
    ema(0, 0, 0, "arena_trono_energia", material="Neon")
    for lado in (-1, 1):
        ema(lado * 7, piso, 0, "arena_pedestal", material="Basalt")
    ema(0, 0, -29, "arena_portao", material="Basalt", colisores=[((-8.3, 8, 0), (3.6, 16, 3.6)), ((8.3, 8, 0), (3.6, 16, 3.6))])
    ema(0, 0, -29, "arena_portao_energia", material="Neon")
    for a in (48, 132, 228, 312):
        x, z = polar_local(21.2, a)
        ema(x, piso, z, "arena_braseiro", material="Basalt", colisores=[((0, 1.5, 0), (2.6, 3.0, 2.6))])
        ema(x, piso + 3.0, z, "arena_braseiro_chama", material="Neon", grupo="lanterna", fase=a)


def montar_decoracao(por):
    """Postes nas margens e os detalhes entre os lugares, como na vista aérea de referência."""
    for tema, (graus, dist) in LOCAIS.items():
        a = math.radians(graus)
        dx, dz = math.sin(a), -math.cos(a)
        inicio, fim = INICIO_CAMINHO + 8, dist - BORDAS[tema] - 9
        for i in range(4):
            r = inicio + (fim - inicio) * i / 3
            for lado in (-1, 1):
                x, z = r * dx - lado * 8 * dz, r * dz + lado * 8 * dx
                p = (x, 0.0, z)
                por("caminho_poste", p, material="Metal")
                por("caminho_luz", p, material="Neon")

    rng = random.Random(1955)
    canteiros = [
        (-171, 108, 1.0), (-142, 162, 0.7), (-98, 148, 0.54),
        (-43, 138, 0.75), (35, 136, 0.98), (155, 66, 0.93),
        (184, 23, 1.18), (194, -22, 1.0), (222, -43, 0.80),
        (192, -80, 0.84), (208, -92, 0.91), (199, -113, 0.55),
        (138, 45, 0.86), (41, -66, 0.85), (88, 20, 0.53),
        (-134, 2, 1.03), (-156, -72, 1.18), (-115, -162, 1.12),
        (-34, -155, 1.0), (-38, 207, 0.8),
    ]
    for i, (x, z, escala) in enumerate(canteiros):
        giro = rng.uniform(0, 360)
        pos = (x, 0.0, z)
        por("campo_canteiro", pos, giro=giro, escala=escala, material="Grass")
        por("campo_brotos", pos, giro=giro, escala=escala, material="Neon")
        cristal = "cristal_aglomerado_a" if i % 2 == 0 else "cristal_aglomerado_b"
        por(
            cristal, (x, 0.22 * escala, z), giro=giro, escala=0.6 * escala,
            material="Glass", transparencia=0.08,
        )

    for x, z, giro, escala in [(-98, 164, -24, 0.36), (89, -46, 40, 0.52), (124, 41, -33, 0.42)]:
        por("arco_partido", (x, 0.0, z), giro=giro, escala=escala)
    for x, z, giro, escala in [(-122, 192, 30, 0.60), (76, 2, -28, 0.52), (-35, 89, 70, 0.44)]:
        por("ruina_parede_b", (x, 0.0, z), giro=giro, escala=escala)


def montar_locais(por, rng):
    """Os seis lugares, os caminhos de transição, o campo entre eles e o anel de penhascos."""

    def em(local, lx, ly, lz, malha, extra_giro=0.0, **kw):
        graus, dist = LOCAIS[local]
        return por(malha, mundo(graus, dist, lx, ly, lz), giro=giro_de(graus, extra_giro), **kw)

    def voltado_ao_centro(local, raio, a, ly, malha, **kw):
        """Peça num círculo do lugar, com a frente virada para o centro do lugar."""
        x, z = polar_local(raio, a)
        return em(local, x, ly, z, malha, extra_giro=180 - a, **kw)

    # Caminhos: um por lugar, saindo da borda da praça
    for tema, (graus, dist) in LOCAIS.items():
        g = math.radians(graus)
        inicio = (INICIO_CAMINHO * math.sin(g), 0.0, -INICIO_CAMINHO * math.cos(g))
        por("caminho_" + tema, inicio, giro=giro_de(graus))
        por("caminho_" + tema + "_energia", inicio, giro=giro_de(graus), material="Neon")

    # Arquivo dos Ecos: observatório aberto
    em("arquivo", 0, 0, 0, "arquivo_base", material="Marble")
    em("arquivo", 0, 0, 0, "arquivo_estrutura", material="Marble")
    em("arquivo", 0, 0, 0, "arquivo_energia", material="Neon")
    em("arquivo", 0, 2, 0, "arquivo_console")
    em("arquivo", 0, 7.5, 0, "cristal_fragmento_a", material="Neon", grupo="gira", velocidade=0.6)
    for i in range(1, 10):
        voltado_ao_centro("arquivo", 15, 36 * i, 2, "arquivo_coluna", material="Marble")
    for k in range(6):
        voltado_ao_centro("arquivo", 9.5, 60 * k + 30, 2.4, "arquivo_projecao", material="Neon", transparencia=0.55)

    # Obelisco das Lendas
    em("obelisco", 0, 0, 0, "obelisco_base")
    em("obelisco", 0, 0, 0, "obelisco_fuste", material="Basalt")
    em("obelisco", 0, 33.6, 0, "obelisco_ponta", material="Metal")
    em("obelisco", 0, 0, 0, "obelisco_energia", material="Neon")
    em("obelisco", 0, 0, 0, "obelisco_moldura")
    for sx in (-1, 1):
        for sz in (-1, 1):
            em("obelisco", sx * 15.5, 0, sz * 15.5, "obelisco_pilone", material="Basalt")
            em("obelisco", sx * 15.5, 11.6, sz * 15.5, "cristal_fragmento_c", material="Neon", grupo="lanterna", fase=rng.uniform(0, 360))

    # Jardim dos Fragmentos
    em("jardim", 0, 0, 0, "jardim_chao", material="Grass")
    em("jardim", 0, 0, 0, "jardim_energia", material="Neon")
    em("jardim", 0, 0, 0, "jardim_passagem")
    colisor_tronco = [((0, 4.5, 0), (1.6, 9.0, 1.6))]
    for x, z in ((-14, -6), (13, -11), (-17, 11), (18, 8), (9, 16)):
        giro_arvore = rng.uniform(0, 360)
        em("jardim", x, 0.4, z, "arvore_tronco", extra_giro=giro_arvore, colisores=colisor_tronco)
        em("jardim", x, 0.4, z, "arvore_copa", extra_giro=giro_arvore, material="Glass", transparencia=0.1)
    for x, z in ((-6, -20), (8, -21), (-22, -2), (23, -1), (-11, 20), (16, 21), (-24, 8), (2, -12)):
        em("jardim", x, 0.4, z, "cristal_aglomerado_a" if x % 2 == 0 else "cristal_aglomerado_b", extra_giro=rng.uniform(0, 360), material="Glass", transparencia=0.08, escala=rng.uniform(0.8, 1.3))
    colisores_arco = [((-12.5, 5.2, 0), (4.6, 10.4, 4.4)), ((12.5, 5.2, 0), (4.6, 10.4, 4.4))]
    em("jardim", -10, 0.4, 3, "arco_partido", extra_giro=65, escala=0.45, colisores=colisores_arco)
    colisor_pilar = [((0, 6.2, 0), (3.0, 12.4, 3.0))]
    em("jardim", 12, 0.4, 1, "ruina_pilar_a", extra_giro=rng.uniform(0, 360), escala=0.75, colisores=colisor_pilar)
    em("jardim", -5, 0.4, -13, "ruina_pilar_a", extra_giro=rng.uniform(0, 360), escala=0.6, colisores=colisor_pilar)
    colisor_muro = [((-1.2, 2.6, 0), (12.8, 5.2, 1.9))]
    em("jardim", -6, 0.4, 18, "ruina_parede_b", escala=0.7, colisores=colisor_muro)
    for x, z in ((20, -16), (-21, -15), (3, 26)):
        em("jardim", x, 0.4, z, "rocha_a", extra_giro=rng.uniform(0, 360), escala=rng.uniform(1.0, 1.6))

    # Altar da Ressonância
    em("altar", 0, 0, 0, "altar_base")
    em("altar", 0, 0, 0, "altar_energia", material="Neon")
    em("altar", 0, 3, 0, "altar_mesa")
    em("altar", 0, 14, 0, "altar_halo", grupo="gira", velocidade=0.15)
    em("altar", 0, 10.5, 0, "cristal_fragmento_a", material="Neon", grupo="lanterna", fase=0)
    for i in range(6):
        a = 30 + 60 * i
        malha = "altar_monolito_a" if i % 2 == 0 else "altar_monolito_b"
        voltado_ao_centro("altar", 19.5, a, 0, malha, material="Basalt")
        voltado_ao_centro("altar", 19.5, a, 0, "altar_monolito_runa", material="Neon")

    # Portais Fragmentados: três molduras ogivais no fundo do estrado, a da esquerda partida
    em("portais", 0, 0, 0, "portais_base")
    for b in (-38, 0, 38):
        x, z = math.sin(math.radians(b)) * 10, math.cos(math.radians(b)) * 10
        quebrado = b == -38
        em("portais", x, 0.8, z, "portal_quebrado" if quebrado else "portal_moldura", extra_giro=b, material="Basalt")
        em("portais", x, 0.8, z, "portal_runas_quebrado" if quebrado else "portal_runas", extra_giro=b, material="Neon")
    for k in range(5):
        em("portais", rng.uniform(-14, 14), rng.uniform(4, 13), rng.uniform(2, 16), "cristal_fragmento_c" if k % 2 else "rocha_b", extra_giro=rng.uniform(0, 360), material="Neon" if k % 2 else "Slate", grupo="lanterna", fase=rng.uniform(0, 360))

    # Arena dos Despertos
    em("arena", 0, 0, 0, "arena_piso", material="Basalt")
    em("arena", 0, 0, 0, "arena_arquibancada", material="Basalt")
    em("arena", 0, 0, 0, "arena_energia", material="Neon")
    for k in range(8):
        a = 67.5 + k * (225 / 7)
        voltado_ao_centro("arena", 35.5, a, 0, "arquivo_coluna", material="Basalt")
        if k % 2 == 0:
            voltado_ao_centro("arena", 35.5, a, 0, "arena_estandarte", material="Fabric")

    # Campo entre os lugares: rochas e cristais, fora dos caminhos e longe dos lugares
    angulos_caminho = [g for g, _ in LOCAIS.values()]
    centros = [mundo(g, d) for g, d in LOCAIS.values()]
    colocados = 0
    tentativas = 0
    while colocados < 46 and tentativas < 2000:
        tentativas += 1
        r = rng.uniform(58, 228)
        a = rng.uniform(0, 360)
        x, z = r * math.sin(math.radians(a)), -r * math.cos(math.radians(a))
        if any(abs((a - g + 180) % 360 - 180) * math.pi / 180 * r < 12 for g in angulos_caminho):
            continue
        if any(math.hypot(x - c[0], z - c[2]) < 40 for c in centros):
            continue
        cristal = colocados % 4 == 0
        malha = ("cristal_aglomerado_a" if colocados % 8 == 0 else "cristal_aglomerado_b") if cristal else ("rocha_a" if colocados % 3 else "rocha_b")
        por(malha, (x, 0.0, z), giro=rng.uniform(0, 360), escala=rng.uniform(1.0, 2.2) if not cristal else rng.uniform(1.0, 1.8), material="Glass" if cristal else "Slate", **({"transparencia": 0.08} if cristal else {}))
        colocados += 1

    # Anel de penhascos: fecha o mapa e esconde o que há fora
    n = 56
    for i in range(n):
        g = 360 * i / n + rng.uniform(-1.5, 1.5)
        r = RAIO_PENHASCO + rng.uniform(0, 3)
        por("penhasco_a" if i % 2 == 0 else "penhasco_b", (r * math.sin(math.radians(g)), -0.5, -r * math.cos(math.radians(g))), giro=giro_de(g, rng.uniform(-6, 6)), escala=rng.uniform(0.95, 1.25), material="Rock")
    n = 40
    for i in range(n):
        g = 360 * (i + 0.5) / n
        r = RAIO_PENHASCO + 22
        por("penhasco_c", (r * math.sin(math.radians(g)), -0.5, -r * math.cos(math.radians(g))), giro=giro_de(g, rng.uniform(-8, 8)), escala=rng.uniform(1.0, 1.25), material="Rock")


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
        "-- A colisão dessas peças fica em src/shared/Dados/NexoColisores.luau (criada pelo servidor).",
        "return {",
        "\tcentroCristal = %s," % luau_valor(CENTRO_CRISTAL),
        "\tpecas = {",
    ]
    for item in cena:
        campos = ["%s = %s" % (k, luau_valor(v)) for k, v in item.items() if k != "colisores"]
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_LUAU, "Cena.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def escrever_colisores(cena):
    """Caixas de colisão das peças do kit, já no espaço do mundo, para o SERVIDOR criar.

    Assim a colisão é a mesma para todos os jogadores, com ou sem o kit 3D carregado.
    """
    linhas = [
        "-- GERADO por assets/nexo/source/generate_nexo.py. Não editar à mão.",
        "-- Colisão das peças do kit 3D do Nexo, no espaço do mundo (studs do Roblox).",
        "-- O servidor cria uma caixa por linha: { posicao, giro (graus em Y), tamanho, peça }.",
        "return {",
    ]
    total = 0
    for item in cena:
        for centro, tamanho in item.get("colisores", []):
            e = item["escala"]
            t = math.radians(item["giro"])
            cx, cy, cz = (c * e for c in centro)
            px, py, pz = item["posicao"]
            mundo_x = px + cx * math.cos(t) + cz * math.sin(t)
            mundo_z = pz - cx * math.sin(t) + cz * math.cos(t)
            linhas.append(
                "\t{ posicao = %s, giro = %s, tamanho = %s, peca = %s },"
                % (
                    luau_valor((round(mundo_x, 3), round(py + cy, 3), round(mundo_z, 3))),
                    luau_valor(round(item["giro"], 3)),
                    luau_valor(tuple(round(v * e, 3) for v in tamanho)),
                    luau_valor(item["malha"]),
                )
            )
            total += 1
    linhas += ["}", ""]
    with open(os.path.join(RAIZ, "src", "shared", "Dados", "NexoColisores.luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return total


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
    if mundo.node_tree is None:
        mundo.use_nodes = True
    fundo = mundo.node_tree.nodes["Background"]
    fundo.inputs["Color"].default_value = (0.035, 0.03, 0.08, 1)
    fundo.inputs["Strength"].default_value = 1.0
    cena.world = mundo
    # chão escuro além da praça
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=300, fill_type="NGON", location=(0, 0, 0))
    chao = bpy.context.object
    mat = bpy.data.materials.new("Chao")
    if mat.node_tree is None:
        mat.use_nodes = True
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
    print("colisores no servidor: %d" % escrever_colisores(cena))
    print("total de triangulos no kit: %d | instancias na cena: %d" % (total_tris, len(cena)))

    if "--render" in sys.argv:
        preparar_render()
        # mesma posição de quem nasce: ao sul da praça, câmera em terceira pessoa olhando o Núcleo
        renderizar("spawn", (0, -47, 7.5), (0, 0, 12.5), lente=24)
        renderizar("nucleo", (17, -21, 9), (0, 0, 11), lente=30)
        renderizar("alto", (38, -52, 34), (0, -4, 6), lente=28)
        renderizar("mapa", (150, -230, 210), (0, 0, 0), lente=22)
        renderizar("arquivo", tuple(roblox_para_blender(mundo(315, 150, 0, 9, -38))), tuple(roblox_para_blender(mundo(315, 150, 0, 9, 0))), lente=28)
        renderizar("obelisco", tuple(roblox_para_blender(mundo(0, 150, 6, 6, -50))), tuple(roblox_para_blender(mundo(0, 150, 0, 17, 0))), lente=26)
        renderizar("jardim", tuple(roblox_para_blender(mundo(225, 150, 0, 14, -44))), tuple(roblox_para_blender(mundo(225, 150, 0, 3, 0))), lente=26)
        renderizar("altar", tuple(roblox_para_blender(mundo(45, 150, 8, 12, -44))), tuple(roblox_para_blender(mundo(45, 150, 0, 7, 0))), lente=26)
        renderizar("portais", tuple(roblox_para_blender(mundo(135, 150, -6, 9, -36))), tuple(roblox_para_blender(mundo(135, 150, 0, 8, 6))), lente=26)
        renderizar("arena", tuple(roblox_para_blender(mundo(180, 156, 0, 16, -50))), tuple(roblox_para_blender(mundo(180, 156, 0, 3, 0))), lente=24)
        renderizar("arena_trono_entrada", tuple(roblox_para_blender(mundo(180, 156, 0, 6.5, -44))), tuple(roblox_para_blender(mundo(180, 156, 0, 7, 18))), lente=30)
        renderizar("arena_trono_centro", tuple(roblox_para_blender(mundo(180, 156, 0, 5.5, -4))), tuple(roblox_para_blender(mundo(180, 156, 0, 8, 19))), lente=28)
        renderizar("arena_trono_45", tuple(roblox_para_blender(mundo(180, 156, 30, 26, -34))), tuple(roblox_para_blender(mundo(180, 156, 0, 4, 6))), lente=26)
        renderizar("arena_trono_lateral", tuple(roblox_para_blender(mundo(180, 156, 15, 7, 12))), tuple(roblox_para_blender(mundo(180, 156, 0, 7, 19.5))), lente=30)
        renderizar("incursoes", tuple(roblox_para_blender(mundo(BASTIAO[0], BASTIAO[1], 4, 8, -36))), tuple(roblox_para_blender(mundo(BASTIAO[0], BASTIAO[1], 0, 9, 9))), lente=26)
        renderizar("incursoes_portal", tuple(roblox_para_blender(mundo(BASTIAO[0], BASTIAO[1], -5, 6, -9))), tuple(roblox_para_blender(mundo(BASTIAO[0], BASTIAO[1], 0, 10.5, 11))), lente=24)
        renderizar("incursoes_ramal", tuple(roblox_para_blender(mundo(135, 150, 6, 7, 14))), tuple(roblox_para_blender(mundo(BASTIAO[0], BASTIAO[1], 0, 8, 6))), lente=26)
        renderizar("incursoes_alto", tuple(roblox_para_blender(mundo(BASTIAO[0], BASTIAO[1], 30, 45, -50))), tuple(roblox_para_blender(mundo(BASTIAO[0], BASTIAO[1], 0, 3, 0))), lente=26)
        renderizar("caminho_arquivo", tuple(roblox_para_blender(mundo(315, 72, 0, 4.5, -2))), tuple(roblox_para_blender(mundo(315, 150, 0, 3, 0))), lente=26)
        renderizar("caminho_portais", tuple(roblox_para_blender(mundo(135, 72, 0, 4.5, -2))), tuple(roblox_para_blender(mundo(135, 150, 0, 3, 0))), lente=26)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_SOURCE, "nexo_master.blend"), compress=True)


if __name__ == "__main__":
    main()
