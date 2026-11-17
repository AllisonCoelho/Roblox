"""Estilos de edição. Cada estilo transforma momentos analisados em um plano de corte.

Os textos citam fatos (nome de aura, raridade, resultado) somente quando vêm das
marcações escritas pelo dono (<video>.json). Sem marcação, os textos são reações
genéricas que não afirmam nada sobre o que aconteceu.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Trecho:
    origem: Path
    inicio: float
    dur: float  # duração na gravação original
    velocidade: float = 1.0
    layout: str = "preenchido"  # preenchido | meio | recorte
    foco_x: float = 0.5
    zoom: list = field(default_factory=lambda: [(0.0, 1.0)])  # (tempo no trecho, zoom)
    tremor: list = field(default_factory=list)  # (t0, t1, amplitude em px)
    clarao: list = field(default_factory=list)  # (t, intensidade)
    glitch: list = field(default_factory=list)  # (t0, t1)
    congelar: float = 0.0  # segundos de quadro congelado no fim
    saturacao: float = 1.1
    volume: float = 1.0

    @property
    def dur_saida(self) -> float:
        return self.dur / self.velocidade + self.congelar


@dataclass
class Plano:
    estilo: str
    trechos: list
    textos: list = field(default_factory=list)  # dicts para Legenda.texto / selo
    sfx: list = field(default_factory=list)
    momentos: list = field(default_factory=list)
    capa_t: float = 1.0
    gancho: str = ""
    destaque: str = ""
    variacao: dict = field(default_factory=dict)

    @property
    def duracao(self) -> float:
        return sum(t.dur_saida for t in self.trechos)


# ---------------------------------------------------------------------------
# textos
GANCHOS = {
    "revelacao": ["espera o final...", "não pisca", "olha o que veio", "presta atenção no *final*",
                  "eu não tava pronto pra isso", "isso aqui foi *forte*"],
    "montagem": ["o Despertar em {s} segundos", "{n} momentos seguidos", "só os momentos *bons*",
                 "um pouco do *caos* do Despertar", "compilado da gameplay de hoje"],
    "pov": ["POV: você abre o Despertar", "POV: só mais uma vez...", "POV: você decidiu testar esse jogo",
            "POV: 3 da manhã no Despertar"],
    "top3": ["top 3 momentos da gameplay", "3 momentos dessa gravação", "ranking dos momentos de hoje"],
    "pausa": ["pera...", "calma...", "olha isso", "espera..."],
}
REACOES = ["?!", "OLHA ISSO", "QUE ISSO", "ABSURDO", "NÃO ACREDITO", "MDS"]
CONGELAR = ["pera...", "repara aqui...", "agora olha...", "3... 2... 1..."]


def _escolher(rng, lista, **fmt) -> str:
    return str(rng.choice(lista)).format(**fmt)


def _gancho_evento(ev: dict, rng) -> str | None:
    """Gancho com fatos vindos da marcação do dono."""
    if not ev:
        return None
    titulo, rar = ev.get("titulo"), ev.get("raridade")
    if ev.get("gancho"):
        return ev["gancho"]
    if titulo and rar:
        return _escolher(rng, ["{r}... e veio *{t}*", "tirei *{t}* ({r})", "a chance era {r}"], t=titulo, r=rar)
    if titulo:
        return _escolher(rng, ["olha a *{t}*", "consegui *{t}*", "*{t}* em ação"], t=titulo)
    return None


def tamanho_destaque(txt: str) -> int:
    """Reações curtas ("?!") ficam enormes; nomes longos diminuem para caber."""
    n = len(txt.replace("*", "").split("\\N")[0])
    return 200 if n <= 4 else 150 if n <= 9 else 124


def _destaque_evento(ev: dict, rng) -> str:
    if ev and ev.get("titulo"):
        return f"*{ev['titulo']}*" + (f"\\N{ev['raridade']}" if ev.get("raridade") else "")
    return str(rng.choice(REACOES))


# ---------------------------------------------------------------------------
# utilidades de corte
def _layout(m: dict, rng, preferido: str | None = None) -> str:
    if preferido:
        return preferido
    if m["dispersao_foco"] > 0.18:  # ação espalhada pela tela: mostra o quadro inteiro
        return "preenchido"
    return str(rng.choice(["meio", "meio", "recorte", "preenchido"]))


def _limitar(inicio: float, fim: float, dur_origem: float) -> tuple[float, float]:
    inicio = max(0.0, inicio)
    fim = min(dur_origem - 0.05, fim)
    return inicio, max(inicio + 0.5, fim)


def _soco(t: float, zoom_max: float, rng) -> list:
    """Zoom de impacto rápido que relaxa um pouco."""
    return [(0.0, 1.0), (max(0.0, t - 0.02), 1.0), (t + 0.12, zoom_max), (t + 0.9, 1 + (zoom_max - 1) * 0.55)]


def _variacoes_impacto(rng) -> dict:
    return {
        "clarao": bool(rng.random() < 0.65),
        "glitch": bool(rng.random() < 0.35),
        "tremor": bool(rng.random() < 0.7),
        "zoom": float(rng.uniform(1.18, 1.42)),
        "acento": str(rng.choice(["lilas", "menta", "dourado", "ciano"])),
        "anim_gancho": str(rng.choice(["pop", "maquina", "deslizar", "queda"])),
        "anim_destaque": str(rng.choice(["pop", "tremor", "queda"])),
        "chamada": bool(rng.random() < 0.5),
    }


def _aplicar_impacto(tr: Trecho, t: float, v: dict) -> None:
    tr.zoom = _soco(t, v["zoom"], None)
    if v["clarao"]:
        tr.clarao.append((t, 0.55))
    if v["glitch"]:
        tr.glitch.append((t, t + 0.22))
    if v["tremor"]:
        tr.tremor.append((t, t + 0.45, 14))


def _chamada(plano: Plano, cfg: dict, leg_y: int) -> None:
    if plano.variacao.get("chamada"):
        fim = plano.duracao
        plano.textos.append({"tipo": "texto", "txt": cfg["jogo"]["chamada_video"], "inicio": fim - 1.8, "fim": fim,
                             "y": leg_y, "tamanho": 54, "animacao": "deslizar", "fonte": "Inter ExtraBold", "borda": 5,
                             "largura_linha": 30})


# ---------------------------------------------------------------------------
# estilos
def estilo_revelacao(momentos, rng, cfg, pos) -> Plano | None:
    m = momentos[0]
    v = _variacoes_impacto(rng)
    v["camera_lenta"] = bool(rng.random() < 0.5)
    pre, pos_ = float(rng.uniform(5.0, 8.5)), float(rng.uniform(3.0, 5.0))
    i0, _ = _limitar(m["pico"] - pre, m["pico"], m["dur_origem"])
    _, f1 = _limitar(m["pico"], m["pico"] + pos_, m["dur_origem"])
    lay = _layout(m, rng)
    corte = m["pico"] - 0.15
    a = Trecho(m["origem_path"], i0, corte - i0, layout=lay, foco_x=m["foco_x"],
               zoom=[(0.0, 1.0), (corte - i0, float(rng.uniform(1.05, 1.12)))])
    trechos = [a]
    if v["camera_lenta"]:
        b1 = Trecho(m["origem_path"], corte, 1.0, velocidade=0.55, layout=lay, foco_x=m["foco_x"])
        _aplicar_impacto(b1, 0.2, v)
        b2 = Trecho(m["origem_path"], corte + 1.0, max(0.6, f1 - corte - 1.0), layout=lay, foco_x=m["foco_x"],
                    zoom=[(0.0, 1 + (v["zoom"] - 1) * 0.55), (0.6, 1.0)])
        trechos += [b1, b2]
    else:
        b = Trecho(m["origem_path"], corte, f1 - corte, layout=lay, foco_x=m["foco_x"])
        _aplicar_impacto(b, 0.15, v)
        trechos.append(b)
    p = Plano("revelacao", trechos, momentos=[m], variacao=v)
    t_imp = a.dur_saida + (0.2 if v["camera_lenta"] else 0.15)
    p.gancho = _gancho_evento(m.get("evento"), rng) or _escolher(rng, GANCHOS["revelacao"])
    p.destaque = _destaque_evento(m.get("evento"), rng)
    leg = pos
    p.textos += [
        {"tipo": "texto", "txt": p.gancho, "inicio": 0.0, "fim": min(2.6, a.dur_saida - 0.2), "y": leg["topo"],
         "animacao": v["anim_gancho"], "acento": v["acento"], "tamanho": 84},
        {"tipo": "texto", "txt": p.destaque, "inicio": t_imp, "fim": t_imp + 1.7, "y": leg["centro"],
         "animacao": v["anim_destaque"], "acento": v["acento"], "tamanho": tamanho_destaque(p.destaque), "largura_linha": 12},
    ]
    p.sfx += [{"t": t_imp, "efeito": "subida", "fim_em": True, "dur": min(1.6, a.dur_saida)},
              {"t": t_imp, "efeito": "impacto"}]
    if v["glitch"]:
        p.sfx.append({"t": t_imp, "efeito": "glitch"})
    p.capa_t = t_imp + 0.4
    _chamada(p, cfg, leg["base"])
    return p


def estilo_pausa(momentos, rng, cfg, pos) -> Plano | None:
    m = momentos[0]
    v = _variacoes_impacto(rng)
    pre, pos_ = float(rng.uniform(4.0, 7.0)), float(rng.uniform(3.0, 5.0))
    i0, _ = _limitar(m["pico"] - pre, m["pico"], m["dur_origem"])
    _, f1 = _limitar(m["pico"], m["pico"] + pos_, m["dur_origem"])
    lay = _layout(m, rng)
    corte = m["pico"] - 0.35
    congela = float(rng.uniform(1.1, 1.6))
    a = Trecho(m["origem_path"], i0, corte - i0, layout=lay, foco_x=m["foco_x"], congelar=congela)
    t_cong = corte - i0
    a.zoom = [(0.0, 1.0), (t_cong, 1.0), (t_cong + congela, float(rng.uniform(1.25, 1.4)))]
    b = Trecho(m["origem_path"], corte, f1 - corte, layout=lay, foco_x=m["foco_x"])
    _aplicar_impacto(b, 0.35, v)
    p = Plano("pausa", [a, b], momentos=[m], variacao={**v, "congelar": congela})
    t_imp = a.dur_saida + 0.35
    p.gancho = _gancho_evento(m.get("evento"), rng) or _escolher(rng, GANCHOS["revelacao"])
    p.destaque = _destaque_evento(m.get("evento"), rng)
    p.textos += [
        {"tipo": "texto", "txt": p.gancho, "inicio": 0.0, "fim": min(2.4, t_cong), "y": pos["topo"],
         "animacao": v["anim_gancho"], "acento": v["acento"], "tamanho": 82},
        {"tipo": "texto", "txt": _escolher(rng, CONGELAR), "inicio": t_cong + 0.05, "fim": a.dur_saida,
         "y": pos["centro"], "animacao": str(rng.choice(["maquina", "tremor"])), "tamanho": 104, "acento": v["acento"]},
        {"tipo": "texto", "txt": p.destaque, "inicio": t_imp, "fim": t_imp + 1.6, "y": pos["centro"],
         "animacao": v["anim_destaque"], "acento": v["acento"], "tamanho": tamanho_destaque(p.destaque), "largura_linha": 12},
    ]
    p.sfx += [{"t": t_cong, "efeito": "clique"},
              {"t": t_imp, "efeito": "subida", "fim_em": True, "dur": congela + 0.3},
              {"t": t_imp, "efeito": "impacto"}]
    p.capa_t = t_cong + congela * 0.7
    _chamada(p, cfg, pos["base"])
    return p


def estilo_montagem(momentos, rng, cfg, pos) -> Plano | None:
    if len(momentos) < 4:
        return None
    n = int(min(len(momentos), rng.integers(4, 7)))
    escolha = list(momentos[:n])
    melhor = escolha.pop(0)
    rng.shuffle(escolha)
    escolha.append(melhor)  # o momento mais forte fecha o vídeo
    v = {"acento": str(rng.choice(["lilas", "menta", "dourado"])), "contador": bool(rng.random() < 0.5),
         "corte_clarao": bool(rng.random() < 0.5), "anim_gancho": str(rng.choice(["pop", "queda", "maquina"])),
         "chamada": bool(rng.random() < 0.6)}
    trechos, t, sfx, textos = [], 0.0, [], []
    for k, m in enumerate(escolha):
        ultimo = k == len(escolha) - 1
        antes, depois = (2.5, 2.5) if ultimo else (float(rng.uniform(1.0, 1.6)), float(rng.uniform(0.8, 1.4)))
        i0, f1 = _limitar(m["pico"] - antes, m["pico"] + depois, m["dur_origem"])
        z_ini, z_fim = (1.0, 1.15) if k % 2 == 0 else (1.15, 1.0)
        tr = Trecho(m["origem_path"], i0, f1 - i0, layout=_layout(m, rng), foco_x=m["foco_x"],
                    zoom=[(0.0, z_ini), (f1 - i0, z_fim)])
        if ultimo:
            _aplicar_impacto(tr, m["pico"] - i0, {"clarao": True, "glitch": False, "tremor": True, "zoom": 1.3})
            sfx.append({"t": t + m["pico"] - i0, "efeito": "impacto"})
        if k > 0:
            sfx.append({"t": t, "efeito": "whoosh", "fim_em": False})
            if v["corte_clarao"]:
                tr.clarao.append((0.0, 0.35))
        if v["contador"]:
            textos.append({"tipo": "selo", "txt": f"{k + 1}/{len(escolha)}", "inicio": t + 0.05,
                           "fim": t + tr.dur_saida - 0.05, "y": pos["base"] - 20, "cor_fundo": v["acento"], "tamanho": 42})
        trechos.append(tr)
        t += tr.dur_saida
    p = Plano("montagem", trechos, sfx=sfx, momentos=escolha, variacao=v)
    p.gancho = _escolher(rng, GANCHOS["montagem"], n=len(escolha), s=int(round(p.duracao)))
    p.textos = [{"tipo": "texto", "txt": p.gancho, "inicio": 0.0, "fim": 2.4, "y": pos["topo"],
                 "animacao": v["anim_gancho"], "acento": v["acento"], "tamanho": 84}] + textos
    p.capa_t = t - trechos[-1].dur_saida + 2.6
    _chamada(p, cfg, pos["base"] - 120 if v["contador"] else pos["base"])
    return p


def estilo_pov(momentos, rng, cfg, pos) -> Plano | None:
    m = momentos[0]
    dur = float(rng.uniform(10.0, 15.0))
    pre = dur * float(rng.uniform(0.55, 0.7))
    i0, f1 = _limitar(m["pico"] - pre, m["pico"] + dur - pre, m["dur_origem"])
    v = {"acento": str(rng.choice(["lilas", "menta", "ciano"])), "zoom_final": float(rng.uniform(1.08, 1.18)),
         "chamada": bool(rng.random() < 0.4)}
    tr = Trecho(m["origem_path"], i0, f1 - i0, layout="preenchido", foco_x=m["foco_x"],
                zoom=[(0.0, 1.0), (f1 - i0, v["zoom_final"])], saturacao=1.05)
    p = Plano("pov", [tr], momentos=[m], variacao=v)
    ev = m.get("evento")
    p.gancho = (f"POV: {ev['pov']}" if ev and ev.get("pov") else _escolher(rng, GANCHOS["pov"]))
    p.textos = [{"tipo": "texto", "txt": p.gancho, "inicio": 0.0, "fim": p.duracao - 0.1, "y": pos["topo"],
                 "animacao": "deslizar", "acento": v["acento"], "tamanho": 70, "largura_linha": 22,
                 "fonte": "Inter ExtraBold", "borda": 6}]
    if ev and ev.get("titulo"):
        t = m["pico"] - i0
        p.textos.append({"tipo": "texto", "txt": f"*{ev['titulo']}*", "inicio": t, "fim": t + 1.8,
                         "y": pos["centro"], "animacao": "pop", "acento": v["acento"], "tamanho": 110})
    p.sfx = [{"t": m["pico"] - i0, "efeito": "grave", "ganho": 0.6}]
    p.capa_t = m["pico"] - i0 + 0.3
    _chamada(p, cfg, pos["base"])
    return p


def estilo_top3(momentos, rng, cfg, pos) -> Plano | None:
    if len(momentos) < 3:
        return None
    tres = sorted(momentos[:3], key=lambda m: m["forca"])  # #3 (mais fraco) primeiro
    v = {"acento": str(rng.choice(["dourado", "lilas", "menta"])), "chamada": bool(rng.random() < 0.5)}
    trechos, sfx, textos, t = [], [], [], 0.0
    for k, m in enumerate(tres):
        num = 3 - k
        antes, depois = float(rng.uniform(2.2, 3.2)), float(rng.uniform(1.6, 2.4))
        i0, f1 = _limitar(m["pico"] - antes, m["pico"] + depois, m["dur_origem"])
        tr = Trecho(m["origem_path"], i0, f1 - i0, layout=_layout(m, rng, "meio"), foco_x=m["foco_x"])
        if num == 1:
            _aplicar_impacto(tr, m["pico"] - i0, {"clarao": True, "glitch": False, "tremor": True, "zoom": 1.3})
            sfx.append({"t": t + m["pico"] - i0, "efeito": "impacto"})
        else:
            tr.zoom = [(0.0, 1.0), (f1 - i0, 1.1)]
        sfx.append({"t": t + 0.02, "efeito": "sino" if num > 1 else "grave"})
        if k:
            sfx.append({"t": t, "efeito": "whoosh"})
        ev = m.get("evento")
        rotulo = f"#{num}" + (f" {ev['titulo']}" if ev and ev.get("titulo") else "")
        textos.append({"tipo": "selo", "txt": rotulo, "inicio": t + 0.05, "fim": t + tr.dur_saida - 0.05,
                       "y": pos["topo"] + 270, "cor_fundo": v["acento"], "tamanho": 64})
        trechos.append(tr)
        t += tr.dur_saida
    p = Plano("top3", trechos, sfx=sfx, momentos=tres, variacao=v)
    p.gancho = _escolher(rng, GANCHOS["top3"])
    p.textos = [{"tipo": "texto", "txt": p.gancho, "inicio": 0.0, "fim": 2.2, "y": pos["topo"],
                 "animacao": str(rng.choice(["pop", "queda"])), "acento": v["acento"], "tamanho": 76, "largura_linha": 20}] + textos
    p.capa_t = t - trechos[-1].dur_saida + 2.8
    _chamada(p, cfg, pos["base"])
    return p


ESTILOS = {
    "revelacao": estilo_revelacao,
    "pausa": estilo_pausa,
    "montagem": estilo_montagem,
    "pov": estilo_pov,
    "top3": estilo_top3,
}
# quantos momentos distintos cada estilo consome e quais tipos de sinal ele prefere
NECESSIDADE = {"revelacao": 1, "pausa": 1, "montagem": 4, "pov": 1, "top3": 3}
# ordem de distribuição dos momentos no lote: quem depende de um pico forte escolhe primeiro
PRIORIDADE = ["revelacao", "pausa", "top3", "montagem", "pov"]
PREFERENCIA_FORTE = {"revelacao", "pausa"}
PREFERE = {"revelacao": ("evento", "revelacao", "explosao", "brilho"), "pausa": ("evento", "revelacao", "explosao", "brilho", "acao"),
           "pov": ("acao", "movimento", "evento"), "montagem": (), "top3": ()}


def ajustar_duracao(plano: Plano, minimo: float, maximo: float) -> Plano:
    """Encurta o primeiro trecho (antes do pico) se o vídeo passar do máximo."""
    excesso = plano.duracao - maximo
    if excesso > 0 and plano.trechos:
        tr = plano.trechos[0]
        corte = min(excesso * tr.velocidade, tr.dur - 1.5)
        if corte > 0:
            tr.inicio += corte
            tr.dur -= corte
            # o zoom do primeiro trecho é relativo ao seu início; os eventos seguintes recuam junto
            tr.zoom = [(max(0.0, t - corte / tr.velocidade), z) for t, z in tr.zoom]
            delta = corte / tr.velocidade
            for tx in plano.textos:
                if tx["inicio"] > 0.01:
                    tx["inicio"] = max(0.0, tx["inicio"] - delta)
                    tx["fim"] = max(tx["inicio"] + 0.5, tx["fim"] - delta)
                else:
                    tx["fim"] = min(tx["fim"], max(1.5, tx["fim"] - delta))
            for s in plano.sfx:
                s["t"] = max(0.0, s["t"] - delta)
            plano.capa_t = max(0.2, plano.capa_t - delta)
    return plano

