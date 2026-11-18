"""Gera o NPC Primeiro Soberano (Guardião do Trono Vazio) no Blender (testado com bpy 5.3).

Uso (Blender como módulo Python):
    python assets/npcs/primeiro_soberano/source/generate_soberano.py            # peças e dados
    python assets/npcs/primeiro_soberano/source/generate_soberano.py --render   # também as prévias

Saídas:
    assets/npcs/primeiro_soberano/source/primeiro_soberano.blend   cena editável (NPC no trono)
    assets/npcs/primeiro_soberano/exports/<peca>.fbx               uma peça por arquivo
    assets/npcs/primeiro_soberano/previews/*.png                   renders do Blender (NÃO do Roblox)
    src/client/Mundo/Nexo3D/Dados/soberano_<peca>.luau             geometria lida pelo jogo
    src/shared/Dados/SoberanoPecas.luau                            peças, juntas e medidas

O NPC é uma armadura de placas em PEÇAS RÍGIDAS ARTICULADAS (não é malha com pele/ossos): cada
peça gira em torno da sua junta. Isso entra no jogo pelo mesmo caminho do kit do Nexo
(EditableMesh), sem depender de importar asset no Studio. Placas rígidas combinam com armadura.

Espaço do NPC = espaço da peça `trono_assento` (origem no pé do trono, +Y é a frente, Z para cima).
Ele já é modelado SENTADO: quadril no assento, coxas para a frente, pés no degrau, mãos nos braços
do trono. Usa as mesmas ferramentas de modelagem do kit (assets/nexo/source/generate_nexo.py).
"""

import base64
import math
import os
import random
import struct
import sys

sys.dont_write_bytecode = True
AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "assets", "nexo", "source"))

import bpy  # noqa: E402

import generate_nexo as kit  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

DIR_BASE = os.path.join(RAIZ, "assets", "npcs", "primeiro_soberano")
DIR_DADOS = os.path.join(RAIZ, "src", "client", "Mundo", "Nexo3D", "Dados")
ARQ_PECAS = os.path.join(RAIZ, "src", "shared", "Dados", "SoberanoPecas.luau")

# Paleta do briefing
OBSIDIANA = (0.17, 0.17, 0.24)  # 11121B um pouco aberta para ler no escuro
ACO = (0.36, 0.32, 0.40)  # 3A3240
RUBRO = (0.55, 0.15, 0.19)  # 8B2630
OURO = (0.77, 0.64, 0.43)  # C4A46D
BRANCO = (1.0, 1.0, 1.0)  # peças de luz: a cor vem da parte (o jogo acende e apaga)
TECIDO = (0.42, 0.10, 0.14)

T = Matrix.Translation


def R(graus, eixo):
    return Matrix.Rotation(math.radians(graus), 4, eixo)


def placa(sx, sy, sz, rng, cor, m, chanfro=0.07):
    return kit.bloco(sx, sy, sz, rng, cor, chanfro=chanfro, tremor=0.012), m


def montar(pecas):
    bm = kit.novo_bm()
    for origem, m in pecas:
        kit.juntar(bm, origem, m)
    return bm


def so(bm):
    return bm, None


def membro(a, b, larg0, larg1, rng, cor, cortes=3):
    """Segmento de armadura de a até b: placas sobrepostas que afinam (cortes diagonais)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    comp = d.length
    eixo = d.normalized()
    rot = eixo.to_track_quat("Z", "Y").to_matrix().to_4x4()
    pecas = []
    for k in range(cortes):
        f0, f1 = k / cortes, (k + 1) / cortes
        larg = larg0 + (larg1 - larg0) * (f0 + f1) / 2
        meio = a + d * (f0 + f1) / 2
        torce = R(7 if k % 2 else -7, "Z")  # placas levemente giradas: corte diagonal assimétrico
        pecas.append(placa(larg * (1.06 if k % 2 == 0 else 0.94), larg * (0.94 if k % 2 == 0 else 1.04), comp / cortes + 0.1, rng, cor if k % 2 == 0 else ACO, T(meio) @ rot @ torce))
    return pecas


# Medidas (sentado no trono: assento em z = 1,7; braços do trono em x = ±3,0, topo z ≈ 3,35)
QUADRIL = 2.2
JOELHO_Y = 2.35
OMBRO = Vector((1.75, -0.35, 4.95))
COTOVELO = Vector((2.85, 0.0, 3.95))
MAO = Vector((3.0, 1.75, 3.72))
CINTURA = Vector((0, -0.25, 2.75))
PESCOCO = Vector((0, -0.3, 5.35))


def fazer_base():
    """Parte que não se move: bacia, coxas (para a frente), canelas e botas pesadas."""
    rng = random.Random(3101)
    p = []
    p.append(placa(2.5, 1.5, 0.95, rng, OBSIDIANA, T((0, -0.25, QUADRIL))))
    p.append(placa(2.9, 0.5, 0.5, rng, ACO, T((0, 0.45, QUADRIL + 0.3))))  # cinto
    p.append((kit.espinho((0, 0.72, QUADRIL + 0.45), (0, 0.9, QUADRIL - 0.7), 0.85, RUBRO, 1.0), None))  # faixa frontal
    for lado in (-1, 1):
        x = lado * 0.78
        p += membro((x, 0.1, QUADRIL), (x * 1.08, JOELHO_Y, QUADRIL + 0.05), 1.15, 1.0, rng, OBSIDIANA)
        p.append(placa(1.2, 1.0, 1.0, rng, ACO, T((x * 1.08, JOELHO_Y + 0.15, QUADRIL + 0.1)) @ R(lado * 8, "Z")))  # joelheira
        p.append((kit.espinho((x * 1.08, JOELHO_Y + 0.5, QUADRIL + 0.3), (x * 1.08, JOELHO_Y + 0.85, QUADRIL + 1.0), 0.5, OURO, 0.9), None))
        p += membro((x * 1.08, JOELHO_Y + 0.1, QUADRIL - 0.3), (x * 1.12, JOELHO_Y + 0.25, 0.55), 1.2, 1.3, rng, OBSIDIANA)
        p.append(placa(1.45, 2.3, 0.6, rng, OBSIDIANA, T((x * 1.12, JOELHO_Y + 0.75, 0.3))))  # bota
        p.append(placa(1.5, 0.5, 0.5, rng, ACO, T((x * 1.12, JOELHO_Y + 1.75, 0.3))))  # biqueira
    return montar([(a, b) for a, b in p])


def fazer_torso():
    """Tronco: placas com cortes diagonais assimétricos, gola alta e peitoral central."""
    rng = random.Random(3102)
    p = []
    p.append(placa(2.3, 1.35, 1.0, rng, ACO, T((0, -0.3, 3.2))))  # abdômen
    p.append(placa(3.0, 1.55, 1.3, rng, OBSIDIANA, T((0, -0.3, 4.25)) @ R(3, "Y")))  # peito
    p.append(placa(1.7, 0.5, 1.6, rng, OBSIDIANA, T((-0.55, 0.45, 4.2)) @ R(-22, "Y")))  # placa diagonal esq.
    p.append(placa(1.5, 0.5, 1.3, rng, ACO, T((0.65, 0.5, 4.05)) @ R(28, "Y")))  # placa diagonal dir.
    p.append(placa(2.6, 1.3, 0.55, rng, ACO, T((0, -0.35, 5.05))))  # ombros/gola
    p.append(placa(1.5, 0.35, 0.8, rng, OBSIDIANA, T((0, -1.0, 5.45)) @ R(-12, "X")))  # gola alta atrás
    for lado in (-1, 1):
        p.append(placa(0.4, 1.0, 0.7, rng, OBSIDIANA, T((lado * 0.85, -0.45, 5.4)) @ R(lado * 14, "Y")))
    p.append((kit.espinho((0, 0.75, 4.75), (0, 0.9, 3.55), 0.75, OURO, 0.85), None))  # moldura do núcleo
    return montar(p)


def fazer_nucleo():
    """Peça de luz no peito (baixa)."""
    return montar([(kit.espinho((0, 0.86, 4.6), (0, 0.98, 3.85), 0.42, BRANCO, 1.0), None)])


def fazer_fissuras():
    """Fissuras de luz na armadura (acendem em onda de tempos em tempos)."""
    rng = random.Random(3103)
    bm = kit.novo_bm()
    y = 0.74
    for a, b in (((-0.25, 4.5), (-1.2, 4.9)), ((0.25, 4.3), (1.25, 4.75)), ((-0.2, 3.9), (-0.95, 3.4)), ((0.2, 3.75), (0.85, 3.2)), ((0.0, 3.5), (0.05, 2.9))):
        linha = kit.zigue(a, b, 3, 0.12, rng)
        kit.juntar(bm, kit.fita3d([(q[0], y + (0.0 if abs(q[0]) < 0.9 else -0.25), q[1]) for q in linha], 0.09, (0, 1, 0), BRANCO))
    return bm


def fazer_cabeca():
    """Elmo fechado com máscara e coroa metálica QUEBRADA de cinco pontas irregulares (uma partida)."""
    rng = random.Random(3104)
    p = []
    c = Vector((0, -0.2, 5.95))
    p.append(placa(1.25, 1.4, 1.3, rng, OBSIDIANA, T(c)))
    p.append(placa(0.95, 0.45, 1.05, rng, ACO, T(c + Vector((0, 0.72, -0.12))) @ R(8, "X")))  # máscara
    p.append((kit.espinho(c + Vector((0, 0.9, -0.35)), c + Vector((0, 1.02, -1.0)), 0.5, OBSIDIANA, 1.0), None))  # queixo em cunha
    for lado in (-1, 1):
        p.append(placa(0.3, 1.1, 0.95, rng, ACO, T(c + Vector((lado * 0.72, 0.1, -0.1))) @ R(lado * 10, "Y")))  # guardas
    p.append(placa(1.5, 1.6, 0.3, rng, OURO, T(c + Vector((0, 0, 0.62)))))  # aro da coroa
    pontas = [(-0.6, 0.45, 1.25), (-0.25, 0.7, 0.75), (0.2, 0.7, 1.55), (0.6, 0.4, 0.45), (0.0, -0.6, 1.05)]  # (x, y, altura): a 4ª está quebrada
    for x, y, alt in pontas:
        base = c + Vector((x, y, 0.7))
        ponta = base + Vector((x * 0.35, y * 0.25, alt))
        if alt < 0.5:  # ponta partida: toco reto
            p.append(placa(0.3, 0.3, alt, rng, OURO, T(base + Vector((0, 0, alt / 2))) @ R(12, "Y")))
        else:
            p.append((kit.espinho(base, ponta, 0.36, OURO, rng.uniform(0.85, 1.0)), None))
    return montar(p)


def fazer_olhos():
    """Duas aberturas pequenas de luz na máscara."""
    bm = kit.novo_bm()
    c = Vector((0, -0.2, 5.95))
    for lado in (-1, 1):
        a = c + Vector((lado * 0.14, 0.99, 0.02))
        b = c + Vector((lado * 0.4, 0.97, 0.12))
        kit.juntar(bm, kit.fita3d([tuple(a), tuple(b)], 0.09, (0, 1, 0), BRANCO))
    return bm


def fazer_braco(lado):
    """Ombreira larga + braço (gira no ombro)."""
    rng = random.Random(3105 + (lado > 0))
    o = Vector((lado * OMBRO.x, OMBRO.y, OMBRO.z))
    cot = Vector((lado * COTOVELO.x, COTOVELO.y, COTOVELO.z))
    p = []
    p.append(placa(1.9, 1.9, 0.75, rng, OBSIDIANA, T(o + Vector((lado * 0.45, 0, 0.3))) @ R(-lado * 18, "Y")))
    p.append(placa(1.5, 1.6, 0.5, rng, ACO, T(o + Vector((lado * 0.85, 0, -0.2))) @ R(-lado * 34, "Y")))
    # a ombreira esquerda tem uma lâmina; a direita, duas menores (assimetria)
    if lado < 0:
        p.append((kit.espinho(o + Vector((lado * 0.7, 0, 0.6)), o + Vector((lado * 1.9, -0.2, 1.7)), 0.7, OBSIDIANA, 1.0), None))
    else:
        p.append((kit.espinho(o + Vector((lado * 0.6, 0.3, 0.6)), o + Vector((lado * 1.4, 0.4, 1.3)), 0.5, OBSIDIANA, 1.0), None))
        p.append((kit.espinho(o + Vector((lado * 0.8, -0.4, 0.55)), o + Vector((lado * 1.7, -0.6, 1.1)), 0.45, ACO, 1.0), None))
    p.append((kit.fita3d([tuple(o + Vector((lado * 0.1, 0.97, 0.45))), tuple(o + Vector((lado * 1.3, 0.97, 0.1)))], 0.12, (0, 1, 0), OURO), None))
    p += membro(o + Vector((lado * 0.35, 0, -0.35)), cot, 0.95, 0.85, rng, OBSIDIANA, cortes=2)
    return montar(p)


def fazer_antebraco(lado):
    """Antebraço, manopla e dedos segmentados sobre o braço do trono (gira no cotovelo)."""
    rng = random.Random(3107 + (lado > 0))
    cot = Vector((lado * COTOVELO.x, COTOVELO.y, COTOVELO.z))
    mao = Vector((lado * MAO.x, MAO.y, MAO.z))
    p = []
    p.append(placa(1.05, 1.05, 1.0, rng, ACO, T(cot) @ R(lado * 10, "Z")))  # cotoveleira
    p += membro(cot, mao, 0.9, 0.95, rng, OBSIDIANA, cortes=2)
    p.append(placa(1.05, 0.8, 0.5, rng, ACO, T(mao + Vector((0, 0.25, 0.05)))))  # dorso da mão
    for k in range(4):  # dedos segmentados, curvados sobre a ponta do braço do trono
        x = mao.x + (k - 1.5) * 0.25
        p.append(placa(0.2, 0.5, 0.22, rng, OBSIDIANA, T((x, mao.y + 0.75, mao.z - 0.02)) @ R(-12, "X"), chanfro=0.03))
        p.append(placa(0.19, 0.4, 0.2, rng, ACO, T((x, mao.y + 1.08, mao.z - 0.2)) @ R(-48, "X"), chanfro=0.03))
    return montar(p)


def fazer_capa(lado):
    """Meia capa presa ao ombro, caindo por fora do braço do trono (dois segmentos, um por lado)."""
    rng = random.Random(3109 + (lado > 0))
    bm = kit.novo_bm()
    linhas = 7
    cols = 4
    grade = []
    for i in range(linhas):
        f = i / (linhas - 1)
        linha = []
        for j in range(cols):
            g = j / (cols - 1)
            x = lado * (1.5 + 2.3 * f + 0.5 * g * (0.4 + f))
            y = -0.95 + 2.6 * g * f + 0.12 * math.sin(f * 4 + j)
            z = 5.15 - 4.6 * f - 0.25 * g + (0.0 if i < linhas - 1 else rng.uniform(-0.35, 0.1))
            linha.append(bm.verts.new((x, y, z)))
        grade.append(linha)
    for i in range(linhas - 1):
        for j in range(cols - 1):
            bm.faces.new((grade[i][j], grade[i][j + 1], grade[i + 1][j + 1], grade[i + 1][j]))
    # verso (o tecido aparece dos dois lados)
    verso = [[bm.verts.new(v.co + Vector((0, -0.06, 0))) for v in linha] for linha in grade]
    for i in range(linhas - 1):
        for j in range(cols - 1):
            bm.faces.new((verso[i][j], verso[i + 1][j], verso[i + 1][j + 1], verso[i][j + 1]))
    kit.bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    kit.pintar(bm, TECIDO, 1.0, topo_claro=0.15)
    kit.juntar(bm, kit.bloco(0.9, 0.5, 0.4, rng, OURO, chanfro=0.05), T((lado * 1.75, -0.9, 5.2)))  # presilha
    return bm


def fazer_espada():
    """Arma cerimonial: espadão embainhado, cravado de ponta no degrau ao lado direito do trono."""
    rng = random.Random(3111)
    p = []
    base = Vector((4.25, 1.9, 0.0))
    inclina = R(-7, "Y")
    def em(v):
        return T(base) @ inclina @ T(v)
    p.append(placa(0.75, 0.3, 5.2, rng, OBSIDIANA, em((0, 0, 2.8))))  # bainha
    p.append((kit.espinho(tuple((T(base) @ inclina) @ Vector((0, 0, 0.35))), tuple((T(base) @ inclina) @ Vector((0, 0, -0.15))), 0.6, ACO, 1.0), None))
    for z in (1.2, 3.0, 4.8):
        p.append(placa(0.9, 0.42, 0.3, rng, OURO, em((0, 0, z))))
    p.append(placa(2.6, 0.5, 0.4, rng, ACO, em((0, 0, 5.55))))  # guarda
    for lado in (-1, 1):
        a = (T(base) @ inclina) @ Vector((lado * 1.25, 0, 5.55))
        b = (T(base) @ inclina) @ Vector((lado * 1.75, 0, 5.05))
        p.append((kit.espinho(tuple(a), tuple(b), 0.4, ACO, 1.0), None))
    p.append(placa(0.35, 0.35, 1.9, rng, RUBRO, em((0, 0, 6.6))))  # cabo
    p.append(placa(0.6, 0.6, 0.5, rng, OURO, em((0, 0, 7.7))))  # pomo
    return montar(p)


# Em pé (duelo): a parte de baixo é articulada para andar, saltar e ajoelhar.
QUADRIL_PE = QUADRIL + 1.35
JOELHO_PE = 1.84
TORNOZELO_PE = 0.48


def perna_pe(lado):
    """Pontos da perna em pé (espaço do NPC no Blender): quadril, joelho e tornozelo."""
    x = lado * 0.89
    y = lado * 0.32
    return (
        Vector((x, -0.1, QUADRIL_PE)),
        Vector((x * 1.1, y, JOELHO_PE)),
        Vector((x * 1.16, y - 0.15, TORNOZELO_PE)),
    )


def fazer_quadril_duelo():
    """Bacia, cinto e faixa: a peça de onde saem as pernas e o tronco no duelo."""
    rng = random.Random(3112)
    q = QUADRIL_PE
    return montar([
        placa(2.5, 1.5, 0.95, rng, OBSIDIANA, T((0, -0.25, q))),
        placa(2.9, 0.5, 0.5, rng, ACO, T((0, 0.45, q + 0.3))),
        (kit.espinho((0, 0.72, q + 0.45), (0, 0.9, q - 0.7), 0.85, RUBRO, 1.0), None),
    ])


def fazer_coxa_duelo(lado):
    rng = random.Random(3114 + lado)
    quadril, joelho, _ = perna_pe(lado)
    p = membro(quadril, joelho, 1.15, 1.0, rng, OBSIDIANA)
    p.append(placa(1.2, 0.75, 0.9, rng, ACO, T(joelho + Vector((0, 0.45, 0))) @ R(lado * 8, "Z")))
    return montar(p)


def fazer_canela_duelo(lado):
    rng = random.Random(3117 + lado)
    _, joelho, tornozelo = perna_pe(lado)
    x = tornozelo.x
    y = joelho.y
    p = membro(joelho, tornozelo, 1.2, 1.3, rng, OBSIDIANA)
    p.append(placa(1.45, 2.1, 0.6, rng, OBSIDIANA, T((x, y + 0.38, 0.3))))  # bota
    p.append(placa(1.5, 0.5, 0.5, rng, ACO, T((x, y + 1.23, 0.3))))  # biqueira
    return montar(p)


def fazer_lamina_duelo():
    """Espadão desembainhado, com o centro do punho na origem e a lâmina para baixo."""
    rng = random.Random(3113)
    return montar([
        placa(0.36, 0.36, 1.7, rng, RUBRO, T((0, 0, 0.05))),
        placa(0.58, 0.56, 0.42, rng, OURO, T((0, 0, 0.92))),
        placa(2.45, 0.55, 0.35, rng, ACO, T((0, 0, -0.77))),
        placa(0.95, 0.28, 3.9, rng, ACO, T((0, 0, -2.76)), chanfro=0.11),
        (kit.espinho((0, 0, -4.41), (0, 0, -5.26), 0.49, ACO, 1.0), None),
        (kit.fita3d([(0, 0.17, -1.0), (0, 0.17, -4.3)], 0.11, (0, 1, 0), RUBRO), None),
    ])


# nome, função, junta, pai (o tronco entra como filho do quadril no cliente)
DUEL = [
    ("quadril_duelo", fazer_quadril_duelo, Vector((0, -0.25, QUADRIL_PE)), None),
    ("coxa_dir", lambda: fazer_coxa_duelo(1), perna_pe(1)[0], "quadril_duelo"),
    ("coxa_esq", lambda: fazer_coxa_duelo(-1), perna_pe(-1)[0], "quadril_duelo"),
    ("canela_dir", lambda: fazer_canela_duelo(1), perna_pe(1)[1], "coxa_dir"),
    ("canela_esq", lambda: fazer_canela_duelo(-1), perna_pe(-1)[1], "coxa_esq"),
    ("lamina_duelo", fazer_lamina_duelo, None, None),
]


def escrever_duelo(metal):
    for nome, montar_peca, _, _ in DUEL:
        obj = kit.registrar("soberano_" + nome, montar_peca(), metal)
        vertices, triangulos = escrever_dados(nome, obj)
        print("%-16s %6d vértices %6d triângulos" % (nome, vertices, triangulos))


# nome, função, material no jogo, junta (ponto em torno do qual gira; None = não gira), pai
def J(v, lado=1):
    return (lado * v.x, v.y, v.z)


PECAS = [
    ("base", fazer_base, "Metal", None, None),
    ("espada", fazer_espada, "Metal", None, None),
    ("torso", fazer_torso, "Metal", J(CINTURA), None),
    ("nucleo", fazer_nucleo, "Neon", J(CINTURA), "torso"),
    ("fissuras", fazer_fissuras, "Neon", J(CINTURA), "torso"),
    ("cabeca", fazer_cabeca, "Metal", J(PESCOCO), "torso"),
    ("olhos", fazer_olhos, "Neon", J(PESCOCO), "cabeca"),
    ("braco_dir", lambda: fazer_braco(1), "Metal", J(OMBRO), "torso"),
    ("braco_esq", lambda: fazer_braco(-1), "Metal", J(OMBRO, -1), "torso"),
    ("antebraco_dir", lambda: fazer_antebraco(1), "Metal", J(COTOVELO), "braco_dir"),
    ("antebraco_esq", lambda: fazer_antebraco(-1), "Metal", J(COTOVELO, -1), "braco_esq"),
    ("capa_dir", lambda: fazer_capa(1), "Fabric", (1.75, -0.9, 5.2), "torso"),
    ("capa_esq", lambda: fazer_capa(-1), "Fabric", (-1.75, -0.9, 5.2), "torso"),
]


def rbx(v):
    return (v[0], v[2], -v[1])


def escrever_dados(nome, obj):
    pos, cor, tris = kit.dados_da_malha(obj)
    assert len(pos) < 65536, nome
    minimo = [min(p[i] for p in pos) for i in range(3)]
    maximo = [max(p[i] for p in pos) for i in range(3)]
    tamanho = [max(maximo[i] - minimo[i], 1e-4) for i in range(3)]
    dados = bytearray()
    for p in pos:
        dados += struct.pack("<3H", *(int(round((p[i] - minimo[i]) / tamanho[i] * 65535)) for i in range(3)))
    for c in cor:
        dados += struct.pack("<3B", *c)
    for t in tris:
        dados += struct.pack("<3H", *t)
    texto = base64.b64encode(bytes(dados)).decode("ascii")
    pedacos = [texto[i : i + 4000] for i in range(0, len(texto), 4000)]
    linhas = [
        "-- GERADO por assets/npcs/primeiro_soberano/source/generate_soberano.py. Não editar à mão.",
        "-- Peça do NPC Primeiro Soberano, no mesmo formato do kit do Nexo (espaço do trono).",
        "return {",
        "\tvertices = %d," % len(pos),
        "\ttriangulos = %d," % len(tris),
        "\tminimo = { %s }," % ", ".join("%.4f" % v for v in minimo),
        "\ttamanho = { %s }," % ", ".join("%.4f" % v for v in tamanho),
        "\tdados = {",
    ]
    linhas += ['\t\t"%s",' % p for p in pedacos]
    linhas += ["\t},", "}", ""]
    with open(os.path.join(DIR_DADOS, "soberano_" + nome + ".luau"), "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))
    return len(pos), len(tris)


def escrever_pecas():
    g, dist = kit.LOCAIS["arena"]
    linhas = [
        "-- GERADO por assets/npcs/primeiro_soberano/source/generate_soberano.py. Não editar à mão.",
        "-- Primeiro Soberano: onde fica (espaço local da Arena, igual ao do trono) e as peças",
        "-- articuladas. junta = ponto em torno do qual a peça gira (espaço do NPC, studs do Roblox).",
        "return {",
        "\tarena = { graus = %g, dist = %g }," % (g, dist),
        "\ttrono = { 0, 2.1, 19.4 }, -- origem do NPC no espaço local da Arena (pé do trono)",
        "\tcabeca = { %.3f, %.3f, %.3f }, -- centro do elmo (para onde os olhos ficam)" % rbx((0, -0.2, 5.95)),
        "\tpecas = {",
    ]
    for nome, _, material, junta, pai in PECAS:
        campos = ['nome = "%s"' % nome, 'malha = "soberano_%s"' % nome, 'material = "%s"' % material]
        if junta:
            campos.append("junta = { %.3f, %.3f, %.3f }" % rbx(junta))
        if pai:
            campos.append('pai = "%s"' % pai)
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas += ["\t},", "\t-- em pé, no duelo: pernas articuladas (o tronco vira filho do quadril, 1,35 acima)"]
    linhas.append("\tduelo = {")
    for nome, _, junta, pai in DUEL:
        campos = ['nome = "%s"' % nome, 'malha = "soberano_%s"' % nome, 'material = "Metal"']
        if junta:
            campos.append("junta = { %.3f, %.3f, %.3f }" % rbx(junta))
        if pai:
            campos.append('pai = "%s"' % pai)
        linhas.append("\t\t{ " + ", ".join(campos) + " },")
    linhas.append("\t},")
    linhas.append("\t-- pontos da perna em pé para a cinemática inversa (quadril, joelho, tornozelo)")
    linhas.append("\tpernas = {")
    for chave, lado in (("dir", 1), ("esq", -1)):
        q, j, t = (rbx(v) for v in perna_pe(lado))
        linhas.append(
            "\t\t%s = { quadril = { %.3f, %.3f, %.3f }, joelho = { %.3f, %.3f, %.3f }, tornozelo = { %.3f, %.3f, %.3f } },"
            % ((chave,) + q + j + t)
        )
    linhas += ["\t},", "}", ""]
    with open(ARQ_PECAS, "w", encoding="utf-8") as f:
        f.write("\n".join(linhas))


def main():
    for d in ("exports", "previews"):
        os.makedirs(os.path.join(DIR_BASE, d), exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    metal = kit.criar_material("Soberano_Metal", rugosidade=0.5, metalico=0.7)
    escrever_duelo(metal)
    if "--duelo" in sys.argv:
        escrever_pecas()
        return
    tecido = kit.criar_material("Soberano_Tecido", rugosidade=0.95)
    luz = bpy.data.materials.new("Soberano_Luz")
    luz.use_nodes = True
    b = luz.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (1.0, 0.17, 0.1, 1)
    b.inputs["Emission Color"].default_value = (1.0, 0.17, 0.1, 1)
    b.inputs["Emission Strength"].default_value = 5.0
    total = 0
    objs = []
    for nome, fn, material, _, _ in PECAS:
        bm = fn()
        obj = kit.registrar("soberano_" + nome, bm, luz if material == "Neon" else tecido if material == "Fabric" else metal)
        bpy.context.scene.collection.objects.link(obj)
        v, t = escrever_dados(nome, obj)
        total += t
        print("%-16s %6d vértices %6d triângulos" % (nome, v, t))
        objs.append(obj)
    print("total: %d triângulos" % total)
    escrever_pecas()
    for obj in objs:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(filepath=os.path.join(DIR_BASE, "exports", obj.name + ".fbx"), use_selection=True, object_types={"MESH"}, apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE", colors_type="SRGB", bake_anim=False)
    # trono e degraus do kit, para o .blend e as prévias
    pedra = kit.criar_material("Nexo_Pedra")
    aco = kit.criar_material("Nexo_Metal", rugosidade=0.45, metalico=0.8)
    energia = kit.criar_material("Nexo_Energia", emissao=6.0)
    for nome, fn, mat, loc in (
        ("trono_assento", kit.fazer_trono, pedra, (0, 0, 0)),
        ("trono_metal", kit.fazer_trono_metal, aco, (0, 0, 0)),
        ("trono_energia", kit.fazer_trono_energia, energia, (0, 0, 0)),
        ("trono_plataforma", kit.fazer_trono_plataforma, pedra, (0, 2.0, -1.5)),
    ):
        o = kit.registrar(nome, fn(), mat)
        o.location = loc
        bpy.context.scene.collection.objects.link(o)
    if "--render" in sys.argv:
        renderizar()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DIR_BASE, "source", "primeiro_soberano.blend"), compress=True)


def renderizar():
    cena = bpy.context.scene
    cena.render.engine = "CYCLES"
    cena.cycles.device = "CPU"
    cena.cycles.samples = 48
    cena.cycles.use_denoising = True
    cena.render.resolution_x, cena.render.resolution_y = 760, 900
    cena.view_settings.view_transform = "AgX"
    mundo = bpy.data.worlds.new("Noite")
    mundo.use_nodes = True
    mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.045, 0.09, 1)
    cena.world = mundo
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, -1.5))
    chao = bpy.context.object
    m = bpy.data.materials.new("Chao")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.028, 0.045, 1)
    chao.data.materials.append(m)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(200)))
    bpy.context.object.data.energy = 2.6
    bpy.context.object.data.color = (0.75, 0.8, 1.0)
    bpy.ops.object.light_add(type="AREA", location=(0, 10, 7))
    luz = bpy.context.object
    luz.data.energy = 900
    luz.data.size = 7
    luz.data.color = (1.0, 0.75, 0.7)
    luz.rotation_euler = (Vector((0, 0, 4)) - luz.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    cam.data.lens = 40
    cena.camera = cam
    alvo = Vector((0, 0, 4.6))
    for nome, graus, dist, alt in (("frente", 0, 22, 4.5), ("45", 40, 22, 6), ("lateral", 90, 22, 5), ("costas", 180, 24, 7), ("trono", 12, 34, 5.5)):
        a = math.radians(graus)
        cam.location = alvo + Vector((math.sin(a) * dist, math.cos(a) * dist, alt - alvo.z))
        cam.rotation_euler = (alvo - cam.location).to_track_quat("-Z", "Y").to_euler()
        cena.render.image_settings.file_format = "PNG"
        cena.render.filepath = os.path.join(DIR_BASE, "previews", nome + ".png")
        bpy.ops.render.render(write_still=True)
        print("prévia", nome)


if __name__ == "__main__":
    main()
