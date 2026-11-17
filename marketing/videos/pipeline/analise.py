"""Análise de gravações: movimento, clarões, cores vivas, picos de áudio e foco horizontal.

Lê o vídeo em baixa resolução (10 quadros/s) por um pipe do FFmpeg, sem carregar tudo
na memória, e grava o resultado em cache para não repetir o trabalho.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import numpy as np

from .base import CACHE, ErroPipeline, InfoMidia, carregar_marcacoes, executar, hash_arquivo, sondar

PASSO = 0.1  # segundos por amostra
LARG, ALT = 96, 54
VERSAO_ANALISE = 3  # mudar invalida o cache


def _ler_quadros(caminho: Path):
    cmd = [
        "ffmpeg", "-v", "error", "-i", str(caminho), "-an",
        "-vf", f"fps={1 / PASSO:g},scale={LARG}:{ALT}:flags=area",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-",
    ]
    tam = LARG * ALT * 3
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as proc:
        while True:
            buf = proc.stdout.read(tam)
            if len(buf) < tam:
                break
            yield np.frombuffer(buf, dtype=np.uint8).reshape(ALT, LARG, 3)


def _audio_rms(caminho: Path, info: InfoMidia, n: int) -> np.ndarray:
    if not info.tem_audio:
        return np.zeros(n)
    taxa = 8000
    proc = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(caminho), "-vn", "-ac", "1", "-ar", str(taxa), "-f", "s16le", "-"],
        capture_output=True,
    )
    amostras = np.frombuffer(proc.stdout, dtype=np.int16).astype(np.float32) / 32768.0
    janela = int(taxa * PASSO)
    m = min(n, len(amostras) // janela)
    rms = np.zeros(n)
    if m:
        blocos = amostras[: m * janela].reshape(m, janela)
        rms[:m] = np.sqrt((blocos ** 2).mean(axis=1) + 1e-12)
    return rms


def _z_robusto(x: np.ndarray) -> np.ndarray:
    med = np.median(x)
    mad = np.median(np.abs(x - med)) * 1.4826
    escala = mad if mad > 1e-6 else (x.std() + 1e-6)
    return (x - med) / escala


def _suavizar(x: np.ndarray, janela: int) -> np.ndarray:
    if janela <= 1 or len(x) < janela:
        return x
    k = np.hanning(janela + 2)[1:-1]
    k /= k.sum()
    return np.convolve(x, k, mode="same")


def analisar(caminho: Path, forcar: bool = False) -> dict:
    """Retorna as séries por amostra e os metadados da gravação (com cache)."""
    info = sondar(caminho)
    chave = hash_arquivo(caminho, completo=False)
    CACHE.mkdir(parents=True, exist_ok=True)
    arq_cache = CACHE / f"analise_{chave}_v{VERSAO_ANALISE}.npz"
    if arq_cache.exists() and not forcar:
        dados = dict(np.load(arq_cache))
        return {"info": info, "chave": chave, **dados}

    luma, mov, foco, vivo, sat = [], [], [], [], []
    anterior = None
    for q in _ler_quadros(caminho):
        f = q.astype(np.float32)
        y = 0.299 * f[..., 0] + 0.587 * f[..., 1] + 0.114 * f[..., 2]
        mx, mn = f.max(axis=2), f.min(axis=2)
        s = (mx - mn) / (mx + 1e-3)
        luma.append(y.mean())
        sat.append(s.mean())
        vivo.append(((s > 0.55) & (mx > 150)).mean())
        if anterior is None:
            mov.append(0.0)
            foco.append(0.5)
        else:
            d = np.abs(y - anterior)
            mov.append(d.mean())
            col = d.sum(axis=0)
            # ignora as bordas, onde ficam HUD e botões
            col[:6] = 0
            col[-6:] = 0
            tot = col.sum()
            foco.append(float((col * np.arange(LARG)).sum() / tot / (LARG - 1)) if tot > 1 else foco[-1])
        anterior = y
    n = len(luma)
    if n < 20:
        raise ErroPipeline(f"{caminho.name}: gravação curta demais ou ilegível ({n} amostras)")

    rms = _audio_rms(caminho, info, n)
    luma_a, mov_a = np.array(luma), np.array(mov)
    # clarão: subida de brilho em relação ao segundo anterior
    base = np.array([np.median(luma_a[max(0, i - 10): i + 1]) for i in range(n)])
    clarao = np.clip(luma_a - base, 0, None)
    # golpe de áudio: subida de energia em relação ao meio segundo anterior
    rms_db = 20 * np.log10(rms + 1e-5)
    base_a = np.array([np.median(rms_db[max(0, i - 5): i + 1]) for i in range(n)])
    golpe = np.clip(rms_db - base_a, 0, None)

    dados = {
        "luma": luma_a, "movimento": mov_a, "foco_x": np.array(foco), "vivo": np.array(vivo),
        "saturacao": np.array(sat), "rms": rms, "clarao": clarao, "golpe": golpe,
    }
    np.savez_compressed(arq_cache, **dados)
    return {"info": info, "chave": chave, **dados}


def pontuar(a: dict) -> np.ndarray:
    z = lambda k: np.clip(_z_robusto(a[k]), -2, 8)  # noqa: E731
    bruto = 0.32 * z("movimento") + 0.22 * z("rms") + 0.18 * z("golpe") + 0.18 * z("clarao") + 0.10 * z("vivo")
    # telas paradas (menus, carregamento) e quadros escuros perdem pontos
    parado = _suavizar((a["movimento"] < 0.4).astype(float), 30) > 0.9
    escuro = a["luma"] < 12
    bruto = bruto - 3 * parado - 4 * escuro
    return _suavizar(bruto, 7)


def _tipo_momento(a: dict, i0: int, i1: int, pico: int) -> str:
    """Rótulo do formato do sinal (não do conteúdo): orienta estilo e texto genérico."""
    zc = _z_robusto(a["clarao"])[pico - 5: pico + 6].max(initial=0)
    zg = _z_robusto(a["golpe"])[pico - 5: pico + 6].max(initial=0)
    zm = _z_robusto(a["movimento"])[i0:i1]
    sustentado = (zm > 1.5).mean() if len(zm) else 0
    if zc > 4 and zg > 2:
        return "explosao"
    if sustentado > 0.45:
        return "acao"
    if zc > 4 or _z_robusto(a["vivo"])[pico - 5: pico + 6].max(initial=0) > 4:
        return "brilho"
    return "movimento"


def encontrar_momentos(caminho: Path, a: dict, maximo: int = 12, distancia: float = 6.0) -> list[dict]:
    """Escolhe os picos mais fortes, afastados entre si, como candidatos a vídeo."""
    marc = carregar_marcacoes(caminho)
    score = pontuar(a)
    n = len(score)
    t = np.arange(n) * PASSO
    bloqueado = np.zeros(n, dtype=bool)
    for ini, fim in marc["ignorar"]:
        bloqueado[(t >= ini) & (t <= fim)] = True
    bloqueado[: int(1.5 / PASSO)] = True  # começo da gravação
    bloqueado[max(0, n - int(1.0 / PASSO)):] = True

    momentos = []
    # eventos marcados pelo dono têm prioridade e trazem os fatos que podem virar texto
    for ev in marc["eventos"]:
        i0, i1 = int(ev["inicio"] / PASSO), min(n - 1, int(ev["fim"] / PASSO))
        if i1 <= i0:
            continue
        pico = int(ev.get("pico", 0) / PASSO) if "pico" in ev else i0 + int(np.argmax(score[i0:i1]))
        momentos.append(_montar(caminho, a, score, pico, i0, i1, evento=ev))
        bloqueado[max(0, i0 - int(2 / PASSO)): i1 + int(2 / PASSO)] = True

    s = score.copy()
    s[bloqueado] = -np.inf
    raio = int(distancia / PASSO)
    while len(momentos) < maximo:
        pico = int(np.argmax(s))
        if not np.isfinite(s[pico]) or s[pico] < 0.6:
            break
        i0 = max(0, pico - int(6 / PASSO))
        i1 = min(n - 1, pico + int(4 / PASSO))
        momentos.append(_montar(caminho, a, score, pico, i0, i1))
        s[max(0, pico - raio): pico + raio] = -np.inf
    momentos.sort(key=lambda m: -m["forca"])
    return momentos


def _ajustar_pico(a: dict, pico: int) -> int:
    """O score suavizado adianta o pico; alinha com o golpe real (áudio + clarão) mais próximo."""
    j0, j1 = max(0, pico - 10), min(len(a["golpe"]), pico + 11)
    sinal = np.clip(_z_robusto(a["golpe"]), 0, None) + np.clip(_z_robusto(a["clarao"]), 0, None)
    trecho = sinal[j0:j1]
    if len(trecho) and trecho.max() > 3:
        return j0 + int(np.argmax(trecho))
    return pico


def _montar(caminho, a, score, pico, i0, i1, evento=None) -> dict:
    if not (evento and "pico" in evento):
        pico = _ajustar_pico(a, pico)
    j0, j1 = max(0, pico - 15), min(len(score), pico + 15)
    foco = float(np.median(a["foco_x"][j0:j1]))
    return {
        "origem": caminho.name,
        "pico": round(pico * PASSO, 2),
        "inicio": round(i0 * PASSO, 2),
        "fim": round(i1 * PASSO, 2),
        "forca": round(float(score[pico]) + (5 if evento else 0), 3),
        "tipo": evento.get("tipo", "evento") if evento else _tipo_momento(a, i0, i1, pico),
        "foco_x": round(foco, 3),
        "evento": evento,
        "dispersao_foco": round(float(np.std(a["foco_x"][j0:j1])), 3),
    }


def folha_de_contato(video: Path, momento: dict, destino: Path, largura: int = 480) -> Path:
    """Quatro quadros (antes, aproximação, pico, depois) em grade 2x2 para conferência visual."""
    p = momento["pico"]
    tempos = [max(0.0, momento["inicio"]), max(0.0, p - 1.0), p, momento["fim"]]
    cmd = ["ffmpeg", "-v", "error", "-y"]
    for tq in tempos:
        cmd += ["-ss", f"{tq:.2f}", "-i", str(video)]
    rotulos = ["inicio", "pico-1s", "pico", "fim"]
    partes = []
    for i, (tq, r) in enumerate(zip(tempos, rotulos)):
        partes.append(
            f"[{i}:v]trim=end_frame=1,scale={largura}:-2,"
            f"drawbox=x=0:y=0:w=iw:h=34:color=black@0.6:t=fill,"
            f"drawtext=text='{r} {tq:.1f}s':x=10:y=8:fontsize=20:fontcolor=white[q{i}]"
        )
    partes.append("[q0][q1][q2][q3]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[s]")
    cmd += ["-filter_complex", ";".join(partes), "-map", "[s]", "-frames:v", "1", "-q:v", "3", str(destino)]
    executar(cmd)
    return destino


def resumo_json(momentos: list[dict]) -> str:
    return json.dumps(momentos, ensure_ascii=False, indent=2)
