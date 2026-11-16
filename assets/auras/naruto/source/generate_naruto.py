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
    dict(id="naruto_2", nome="Modo 2 Caudas", caudas=2, abertura=55, elevacao=40, elevLados=28, curva=32, comprimento=1.0, grossura=1.05,
         fora="FF2A12", dentro="FF9A3A", transpFora=0.3, onda=0.2, freq=2.4, alterna=False, pulso=False, contracao=False, raposa=False, seis=False),
    dict(id="naruto_3", nome="Modo 3 Caudas", caudas=3, abertura=62, elevacao=48, elevLados=24, curva=32, comprimento=1.0, grossura=1,
         fora="FF2A12", dentro="FF9A3A", transpFora=0.3, onda=0.22, freq=2.5, alterna=False, pulso=False, contracao=False, raposa=False, seis=False),
    dict(id="naruto_4", nome="Modo 4 Caudas", caudas=4, abertura=70, elevacao=50, elevLados=18, curva=32, comprimento=1.05, grossura=1.08,
         fora="B3120A", dentro="FF4A1A", transpFora=0.22, onda=0.26, freq=2.8, alterna=False, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_5", nome="Modo 5 Caudas", caudas=5, abertura=78, elevacao=52, elevLados=14, curva=31, comprimento=1.08, grossura=1.12,
         fora="B3120A", dentro="FF4A1A", transpFora=0.22, onda=0.26, freq=2.6, alterna=False, pulso=True, contracao=True, raposa=False, seis=False),
    dict(id="naruto_6", nome="Modo 6 Caudas", caudas=6, abertura=86, elevacao=55, elevLados=10, curva=30, comprimento=1.2, grossura=1.12,
         fora="A80F08", dentro="FF3A14", transpFora=0.2, onda=0.3, freq=2.9, alterna=False, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_7", nome="Modo 7 Caudas", caudas=7, abertura=92, elevacao=58, elevLados=6, curva=30, comprimento=1.22, grossura=1.15,
         fora="A80F08", dentro="FF3A14", transpFora=0.2, onda=0.28, freq=2.7, alterna=True, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_8", nome="Modo 8 Caudas", caudas=8, abertura=98, elevacao=60, elevLados=4, curva=29, comprimento=1.28, grossura=1.25,
         fora="9E0C06", dentro="FF3A14", transpFora=0.18, onda=0.28, freq=2.6, alterna=True, pulso=True, contracao=False, raposa=False, seis=False),
    dict(id="naruto_9", nome="Modo 9 Caudas", caudas=9, abertura=104, elevacao=62, elevLados=2, curva=29, comprimento=1.32, grossura=1.28,
         fora="9E0C06", dentro="FF5A1A", transpFora=0.18, onda=0.3, freq=2.6, alterna=True, pulso=True, contracao=False, raposa=True, seis=False),
    dict(id="naruto_seis", nome="Modo Sábio dos Seis Caminhos", caudas=6, abertura=100, elevacao=42, elevLados=0, curva=25, comprimento=1.25, grossura=0.78,
         fora="FFC93A", dentro="FFF6D0", transpFora=0.35, onda=0.12, freq=1.1, alterna=False, pulso=False, contracao=False, raposa=False, seis=True),
]

# Segmentos: comprimento (studs) e quanto avança até a próxima junta (sobreposição esconde a junta)
SEGMENTOS = [("cauda_base", 2.3), ("cauda_meio1", 2.2), ("cauda_meio2", 2.0), ("cauda_ponta", 2.8)]
AVANCO = 0.82
CURVA_MALHA = 14  # graus que cada segmento já vem curvado de fábrica (a cauda vira meia-lua lisa)
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


def arco(s, comp, curva_graus):
    """Ponto e tangente de um arco que cresce em +Z e curva para +Y (no Roblox: para -Z, "para cima"
    quando a cauda está deitada). Mesma conta usada pelo jogo para achar a próxima junta."""
    b = math.radians(curva_graus)
    if b < 1e-6:
        return Vector((0, 0, s)), Vector((0, 0, 1))
    r = comp / b
    th = b * s / comp
    return Vector((0, r * (1 - math.cos(th)), r * math.sin(th))), Vector((0, math.sin(th), math.cos(th)))


def segmento(rng, comp, r0, r1, chamas_borda, ponta=False):
    """Pedaço de cauda em MEIA-LUA: curvado, largo no plano da curva (Y), mais fino de lado (X),
    com lambidas de chama nas duas bordas apontando para a ponta."""
    vol = Volume("seg")
    tubos = bmesh.new()
    n = 18
    corpo = 0.6 if ponta else 1.0  # na ponta, o volume vai até 60% e o resto é a chama afiada
    for i in range(n):
        f = i / (n - 1)
        p, _ = arco(comp * f * corpo, comp, CURVA_MALHA)
        r = r0 + (r1 - r0) * f
        vol.bola(p, r * (1 + 0.05 * math.sin(f * 9 + rng.uniform(0, 1))), achatar=(0.75, 1.35, 1.0))
    if ponta:
        # ponta longa e afiada que continua a meia-lua e enrola no fim
        pts, raios = [], []
        m = 34
        for j in range(m):
            f = j / (m - 1)
            p, t = arco(comp * (0.55 + 0.6 * f), comp, CURVA_MALHA * (1 + 2.2 * f))
            pts.append(p)
            raios.append(r1 * 1.2 * (1 - f) ** 1.15 + 0.004)
        tubo_liso(tubos, pts, raios, lados=14)
    # chamas nas bordas (plano da curva): saem para fora e varrem em direção à ponta
    for lado in (1, -1):
        for k in range(chamas_borda):
            f = (k + rng.uniform(0.2, 0.8)) / chamas_borda * (0.62 if ponta else 0.95)
            p, t = arco(comp * f, comp, CURVA_MALHA)
            r = r0 + (r1 - r0) * f / (0.62 if ponta else 1.0)
            fora = Vector((0, lado, 0))
            base = p + fora * r * 1.05
            chama(tubos, base, fora * 0.35 + t, fora, comp * rng.uniform(0.45, 0.6), r * rng.uniform(0.34, 0.42), gancho=0.45)
    bm = vol.malha()
    suavizar(bm, 2)
    junta(bm, tubos)
    tubos.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def nucleo(rng, comp, r0, r1, ponta=False):
    """Fogo DESENHADO por dentro: veios de chama ondulados correndo pela cauda, perto das duas
    faces (brilham através da casca translúcida), com ramos que se abrem como labaredas."""
    bm = bmesh.new()
    alcance = 0.6 if ponta else 1.0
    for face in (1, -1):
        for v in range(2):
            y0 = (v - 0.5) * 0.7
            fase = rng.uniform(0, 6.28)
            pts, raios = [], []
            m = 26
            for j in range(m):
                f = j / (m - 1)
                s = comp * alcance * (0.02 + 0.98 * f) * (1.0 if ponta else 1.03)
                p, _ = arco(s, comp, CURVA_MALHA)
                r = r0 + (r1 - r0) * f
                larg = r * 1.35 * 0.8
                pts.append(p + Vector((face * r * 0.52, y0 * larg * (1 - 0.6 * f) + 0.1 * larg * math.sin(f * 5 + fase), 0)))
                raios.append(r * 0.075 * (1 - 0.7 * f) + 0.01)
            tubo_liso(bm, pts, raios, lados=6)
            # ramo de labareda saindo do veio
            j = rng.randint(8, 16)
            f = j / (m - 1)
            dirr = Vector((0, (1 if y0 >= 0 else -1) * 0.8, 1)).normalized()
            chama(bm, pts[j], dirr, Vector((0, 1 if y0 >= 0 else -1, 0)), comp * 0.25, raios[j] * 1.2, gancho=0.5, n=12)
    if ponta:
        pts = [arco(comp * (0.5 + 0.55 * j / 19), comp, CURVA_MALHA * (1 + 2.2 * j / 19))[0] for j in range(20)]
        tubo_liso(bm, pts, [r1 * 0.35 * (1 - j / 19) + 0.01 for j in range(20)], lados=6)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_raposa(rng):
    """Cabeça espectral da raposa (estágio de 9 caudas), olhando para a frente (+Y): crânio, testa
    com sobrancelhas bravas, focinho em cunha, boca aberta, bochechas e juba de chamas, orelhas
    longas. Dentes, olhos, pupilas e o fogo interno são peças à parte (cores próprias)."""
    vol = Volume("raposa")
    t = bmesh.new()
    vol.bola((0, -0.1, 0.1), 1.0, achatar=(1.2, 1.0, 0.92))  # crânio
    vol.bola((0, 0.45, 0.42), 0.6, achatar=(1.35, 0.9, 0.55))  # testa
    for lado in (1, -1):
        vol.bola((lado * 0.42, 0.78, 0.36), 0.3, achatar=(1.3, 0.8, 0.6))  # arco da sobrancelha
        vol.bola((lado * 0.78, 0.35, -0.3), 0.52)  # bochecha
        vol.bola((lado * 0.32, 1.05, -0.12), 0.34, achatar=(0.9, 1.4, 0.8))  # lado do focinho
    vol.bola((0, 1.05, 0.0), 0.42, achatar=(0.95, 1.6, 0.7))  # dorso do focinho
    vol.bola((0, 1.72, -0.02), 0.2)  # nariz
    vol.bola((0, 1.2, -0.42), 0.36, achatar=(1.1, 1.5, 0.45))  # maxilar superior
    vol.bola((0, 1.0, -0.98), 0.34, achatar=(1.1, 1.5, 0.45))  # mandíbula (boca aberta)
    vol.bola((0, 0.45, -0.78), 0.42, achatar=(1.2, 1.0, 0.6))  # queixo/garganta
    for lado in (1, -1):
        # orelhas longas, pontudas, um pouco para trás
        chama(t, (lado * 0.62, -0.25, 0.7), (lado * 0.5, -0.35, 1), (lado, -0.2, 0.1), 1.6, 0.46, gancho=0.22, n=26)
        # juba de chamas atrás das bochechas e da nuca (em leque)
        for j in range(5):
            a = math.radians(-40 + 25 * j)
            base = Vector((lado * 0.95, -0.35 - 0.1 * j, -0.6 + 0.32 * j))
            d = Vector((lado * math.cos(a), -0.6, math.sin(a)))
            chama(t, base, d, Vector((0, -1, 0.4)), 0.9 + 0.12 * (j % 2), 0.26, gancho=0.55)
        # tufos das bochechas (pontas para baixo e para fora)
        chama(t, (lado * 1.05, 0.45, -0.45), (lado, 0.2, -0.6), (0, 1, -0.2), 0.7, 0.2, gancho=0.5)
        chama(t, (lado * 0.95, 0.65, -0.65), (lado * 0.6, 0.4, -1), (lado, 0, 0), 0.55, 0.16, gancho=0.4)
    for j in range(4):  # chamas no alto da cabeça, entre as orelhas
        chama(t, ((j - 1.5) * 0.25, -0.2, 0.9), ((j - 1.5) * 0.3, -0.5, 1), (0, -1, 0), 0.7, 0.18, gancho=0.5)
    bm = vol.malha()
    suavizar(bm, 2)
    junta(bm, t)
    t.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_raposa_nucleo(rng):
    """Fogo interno da raposa: marcas acima dos olhos, linhas do focinho e o fundo da boca."""
    bm = bmesh.new()
    for lado in (1, -1):
        pts = [Vector((lado * (0.15 + 0.5 * f), 0.9 - 0.2 * f, 0.42 + 0.28 * f)) for f in (j / 11 for j in range(12))]
        tubo_liso(bm, pts, [0.07 * (1 - 0.7 * j / 11) + 0.01 for j in range(12)], lados=6)
        pts = [Vector((lado * (0.2 + 0.45 * f), 1.25 - 0.55 * f, -0.2 - 0.05 * f)) for f in (j / 11 for j in range(12))]
        tubo_liso(bm, pts, [0.05 * (1 - 0.6 * j / 11) + 0.01 for j in range(12)], lados=6)
    vol = Volume("boca")
    vol.bola((0, 1.05, -0.7), 0.3, achatar=(1.0, 1.4, 0.5))
    junta(bm, vol.malha())
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_dentes(rng):
    """Dentes da boca aberta: presas grandes e fileiras de dentes menores."""
    bm = bmesh.new()
    for lado in (1, -1):
        chama(bm, (lado * 0.3, 1.35, -0.5), (0, 0.1, -1), (0, 1, 0), 0.42, 0.08, gancho=0.15, n=12)  # presa de cima
        chama(bm, (lado * 0.27, 1.25, -0.88), (0, 0.1, 1), (0, 1, 0), 0.3, 0.065, gancho=0.15, n=12)  # presa de baixo
        for j in range(3):
            y = 1.15 - 0.17 * j
            chama(bm, (lado * (0.33 + 0.04 * j), y, -0.52), (0, 0, -1), (0, 1, 0), 0.18, 0.04, gancho=0.1, n=8)
            chama(bm, (lado * (0.3 + 0.04 * j), y - 0.05, -0.86), (0, 0, 1), (0, 1, 0), 0.14, 0.035, gancho=0.1, n=8)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_olhos(rng):
    """Os dois olhos luminosos, alongados e inclinados (bravos)."""
    vol = Volume("olhos")
    for lado in (1, -1):
        for j in range(6):
            f = j / 5
            vol.bola((lado * (0.24 + 0.36 * f), 0.98 - 0.12 * f, 0.22 + 0.16 * f), 0.11 * (1 - 0.35 * abs(f - 0.45)))
    bm = vol.malha()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_pupilas(rng):
    """Pupilas em fenda (escuras), um pouco à frente dos olhos."""
    vol = Volume("pupilas")
    for lado in (1, -1):
        for j in range(4):
            vol.bola((lado * 0.42, 1.07, 0.2 + 0.07 * j), 0.05, achatar=(0.7, 0.6, 1.4))
    bm = vol.malha()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


# ---------------------------------------------------------------- roupa dos Seis Caminhos
# Cada peça é modelada para o tamanho de referência do membro que veste (o jogo reescala pela
# parte real: R15 UpperTorso/UpperArm/LowerTorso ou R6 Torso/Arm). Centro do membro = origem.
TRONCO_REF = (2.0, 1.6, 1.0)  # X, Y(altura no Roblox), Z(profundidade) — em studs
MANGA_REF = (1.0, 1.17, 1.0)


def caixa_arredondada(vol, tam, folga, n=4):
    """Casca de roupa: bolas cobrindo uma caixa (x, profundidade, altura no Blender)."""
    sx, sy, sz = tam
    for i in range(n + 1):
        for j in range(3):
            for k in range(n + 1):
                x = (i / n - 0.5) * sx
                y = (j / 2 - 0.5) * sy
                z = (k / n - 0.5) * sz
                vol.bola((x, y, z), folga + 0.5)


def fazer_roupa_tronco(rng):
    """Manto dourado no tronco, com gola alta e abas de chama nos ombros."""
    vol = Volume("roupa")
    t = bmesh.new()
    # Blender: X largura, Y profundidade (frente +Y), Z altura
    caixa_arredondada(vol, (TRONCO_REF[0] * 0.8, TRONCO_REF[2] * 0.45, TRONCO_REF[1] * 0.8), 0.12)
    for lado in (1, -1):  # ombreiras de chama
        chama(t, (lado * 0.95, 0, 0.7), (lado, 0, 0.25), (0, 0, -1), 0.6, 0.22, gancho=0.6)
        chama(t, (lado * 0.9, -0.2, 0.55), (lado * 0.8, -0.3, 0.4), (0, -0.4, -1), 0.55, 0.18, gancho=0.6)
    gola = [Vector((0.52 * math.cos(a), 0.36 * math.sin(a), 0.86)) for a in (math.radians(200 + 140 * j / 20) for j in range(21))]
    tubo_liso(t, gola, [0.11] * len(gola), lados=8)  # gola (aberta na frente)
    bm = vol.malha()
    suavizar(bm, 2)
    junta(bm, t)
    t.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_roupa_marcas(rng):
    """Marcas pretas: 9 magatamas em volta da gola e o círculo na barriga."""
    bm = bmesh.new()
    frente = TRONCO_REF[2] * 0.5 + 0.17  # um pouco à frente da casca
    for j in range(9):
        a = math.radians(-60 + 120 * j / 8)
        c = Vector((0.62 * math.sin(a), frente + 0.02, 0.55 - 0.18 * math.cos(a)))
        # magatama: gota com cauda curva
        vol = Volume("mag")
        vol.bola(c, 0.075, achatar=(1.0, 0.5, 1.0))
        junta(bm, vol.malha())
        chama(bm, c + Vector((0.03, 0, -0.03)), (0.5, 0, -1), (1, 0, 0), 0.12, 0.05, gancho=0.8, n=10)
    anel = [Vector((0.24 * math.cos(a), frente + 0.02, -0.38 + 0.24 * math.sin(a))) for a in (2 * math.pi * j / 40 for j in range(41))]
    tubo_liso(bm, anel, [0.035] * 41, lados=6)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_roupa_manga(rng):
    """Manga larga dourada (vale para os dois braços), terminando em pontas de chama."""
    vol = Volume("manga")
    t = bmesh.new()
    caixa_arredondada(vol, (MANGA_REF[0] * 0.4, MANGA_REF[2] * 0.4, MANGA_REF[1] * 0.75), 0.05, n=3)
    for j in range(6):
        a = 2 * math.pi * j / 6
        base = Vector((0.58 * math.cos(a), 0.58 * math.sin(a), -0.5))
        chama(t, base, (math.cos(a) * 0.5, math.sin(a) * 0.5, -1), (math.cos(a), math.sin(a), 0), 0.45, 0.15, gancho=0.5)
    bm = vol.malha()
    suavizar(bm, 2)
    junta(bm, t)
    t.free()
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def fazer_roupa_aba(rng):
    """Abas do manto a partir da cintura (aberto na frente), barra recortada em chamas.
    A origem é o topo (cintura); a aba cai para -Z."""
    vol = Volume("aba")
    t = bmesh.new()
    for j in range(15):
        a = math.radians(30 + 300 * j / 14)  # 30°..330°: deixa a frente aberta (frente = 90°... ajustado abaixo)
        a = a + math.pi / 2  # frente (+Y) fica no vão
        x, y = 1.2 * math.cos(a), 0.75 * math.sin(a)
        for k in range(5):
            f = k / 4
            vol.bola((x * (1 + 0.25 * f), y * (1 + 0.25 * f), -0.15 - 1.25 * f), 0.36)
        chama(t, (x * 1.25, y * 1.25, -1.45), (x * 0.4, y * 0.4, -1), (x, y, 0), 0.45 + 0.15 * (j % 2), 0.17, gancho=0.5)
    bm = vol.malha()
    suavizar(bm, 2)
    junta(bm, t)
    t.free()
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
        linhas.append('\t\t{ malha = "naruto_%s", nucleo = "naruto_%s_nucleo", comprimento = %g },' % (nome, nome, comp))
    linhas += [
        "\t},",
        "\tavanco = %g," % AVANCO,
        "\tcurvaMalha = %g," % CURVA_MALHA,
        "\traiz = %s," % luau_valor(RAIZ_CAUDAS),
        "\ttroncoRef = %s," % luau_valor(TRONCO_REF),
        "\tmangaRef = %s," % luau_valor(MANGA_REF),
        "\testagios = {",
    ]
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
    ("cauda_base", lambda r: segmento(r, 2.3, 0.62, 0.82, 1), 3200),
    ("cauda_meio1", lambda r: segmento(r, 2.2, 0.82, 0.74, 2), 3000),
    ("cauda_meio2", lambda r: segmento(r, 2.0, 0.74, 0.55, 1), 2600),
    ("cauda_ponta", lambda r: segmento(r, 2.8, 0.55, 0.4, 1, ponta=True), 2600),
    ("cauda_base_nucleo", lambda r: nucleo(r, 2.3, 0.62, 0.82), 3000),
    ("cauda_meio1_nucleo", lambda r: nucleo(r, 2.2, 0.82, 0.74), 3000),
    ("cauda_meio2_nucleo", lambda r: nucleo(r, 2.0, 0.74, 0.55), 3000),
    ("cauda_ponta_nucleo", lambda r: nucleo(r, 2.8, 0.55, 0.4, ponta=True), 3000),
    ("raposa", fazer_raposa, 9000),
    ("raposa_nucleo", fazer_raposa_nucleo, 1200),
    ("dentes", fazer_dentes, 1500),
    ("olhos", fazer_olhos, 800),
    ("pupilas", fazer_pupilas, 400),
    ("anel", fazer_anel, 2000),
    ("roupa_tronco", fazer_roupa_tronco, 3000),
    ("roupa_marcas", fazer_roupa_marcas, 2500),
    ("roupa_manga", fazer_roupa_manga, 1500),
    ("roupa_aba", fazer_roupa_aba, 3500),
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


def avancar(comp, curva_graus):
    """Da junta até a próxima: anda pelo arco do segmento (curvado de fábrica) e gira junto."""
    b = math.radians(curva_graus)
    th = b * AVANCO
    if b < 1e-6:
        return tr(0, comp * AVANCO, 0)
    r = comp / b
    # no Roblox o segmento cresce em +Y e curva para -Z (rotação negativa em X)
    return tr(0, r * math.sin(th), -r * (1 - math.cos(th))) @ rx(-th)


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
            dobra = math.radians(e["curva"] - CURVA_MALHA) * (1 - 0.6 * mov) + onda
            if k > 0:
                cf = cf @ rx(-dobra) @ rz(lado)
            saida.append((i, nome, cf))
            cf = cf @ avancar(comp * e["comprimento"], CURVA_MALHA)
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
        dentro = material_chakra("dentro_" + e["id"], e["dentro"], 2.5, 0.65)
        g, c = e["grossura"], e["comprimento"]
        for i, nome, cf in pose_caudas(e):
            instancia(objs[nome], cf, (g, c, g), fora, col)
            instancia(objs[nome + "_nucleo"], cf, (g, c, g), dentro, col)
        if e["raposa"]:
            m = tr(0, 5.6, 1.3) @ Matrix.Diagonal((2.6, 2.6, 2.6, 1))
            instancia(objs["raposa"], m, (1, 1, 1), material_chakra("rap", e["fora"], 2.5, 0.55), col)
            instancia(objs["raposa_nucleo"], m, (1, 1, 1), material_chakra("rapn", e["dentro"], 6, 0.9), col)
            instancia(objs["dentes"], m, (1, 1, 1), material_chakra("den", "FFF1C9", 4, 1), col)
            instancia(objs["olhos"], m, (1, 1, 1), material_chakra("olh", "FFE14A", 12, 1), col)
            instancia(objs["pupilas"], m, (1, 1, 1), material_cor((0.01, 0.0, 0.0)), col)
        if e["raposa"] or e["seis"]:
            chao = tr(0, -2.95, 0) @ Matrix.Diagonal((3.2, 3.2, 3.2, 1))
            instancia(objs["anel"], chao, (1, 1, 1), material_chakra("anel_" + e["id"], e["fora"], 8, 1), col)
        if e["seis"]:
            halo = tr(0, 2.6, 1.6) @ rx(math.pi / 2) @ Matrix.Diagonal((3.6, 3.6, 3.6, 1))
            instancia(objs["anel"], halo, (1, 1, 1), material_chakra("halo", e["fora"], 6, 0.8), col)
            # roupa: no avatar de blocos das prévias o tronco é 2x2x1 e os braços 0.95x2x0.95
            ouro = material_chakra("roupa", e["fora"], 3.5, 0.92)
            tronco = tr(0, 0, 0) @ Matrix.Diagonal((2 / TRONCO_REF[0], 2 / TRONCO_REF[1], 1 / TRONCO_REF[2], 1))
            instancia(objs["roupa_tronco"], tronco, (1, 1, 1), ouro, col)
            instancia(objs["roupa_marcas"], tronco, (1, 1, 1), material_cor((0.01, 0.01, 0.01)), col)
            for lado in (1, -1):
                braco = tr(lado * 1.5, 0, 0) @ Matrix.Diagonal((0.95 / MANGA_REF[0], 2 / MANGA_REF[1], 0.95 / MANGA_REF[2], 1))
                instancia(objs["roupa_manga"], braco, (1, 1, 1), ouro, col)
            instancia(objs["roupa_aba"], tr(0, -0.85, 0), (1, 1, 1), ouro, col)
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
