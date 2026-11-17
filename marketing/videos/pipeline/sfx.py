"""Efeitos sonoros sintetizados com numpy: nenhum áudio de terceiros.

Cada efeito aceita um gerador aleatório para variar timbre e duração entre vídeos.
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

TAXA = 48000


def _env(n: int, ataque: float, queda: float) -> np.ndarray:
    t = np.linspace(0, 1, n)
    a = np.clip(t / max(ataque, 1e-4), 0, 1)
    return a * np.exp(-t / max(queda, 1e-4))


def _ruido(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.standard_normal(n)


def _passa_baixa(x: np.ndarray, corte: np.ndarray | float) -> np.ndarray:
    """Filtro de um polo com corte variável (Hz)."""
    corte = np.broadcast_to(np.asarray(corte, dtype=float), x.shape)
    alfa = 1 - np.exp(-2 * np.pi * corte / TAXA)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alfa[i] * (x[i] - acc)
        y[i] = acc
    return y


def whoosh(rng, dur=None):
    dur = dur or rng.uniform(0.28, 0.5)
    n = int(TAXA * dur)
    t = np.linspace(0, 1, n)
    corte = 300 + 5200 * np.sin(np.pi * t) ** 1.6
    x = _passa_baixa(_ruido(n, rng), corte) * np.sin(np.pi * t) ** 1.3
    return x * 2.2


def impacto(rng, dur=None):
    dur = dur or rng.uniform(0.7, 1.1)
    n = int(TAXA * dur)
    t = np.arange(n) / TAXA
    f0, f1 = rng.uniform(90, 130), rng.uniform(32, 45)
    freq = f1 + (f0 - f1) * np.exp(-t * 9)
    fase = 2 * np.pi * np.cumsum(freq) / TAXA
    corpo = np.sin(fase) * _env(n, 0.002, 0.35)
    estalo = _passa_baixa(_ruido(n, rng), 3500) * _env(n, 0.001, 0.05) * 1.5
    return np.tanh((corpo * 1.4 + estalo) * 1.6)


def subida(rng, dur=None):
    """Riser: ruído e tom subindo até o pico."""
    dur = dur or rng.uniform(1.0, 1.8)
    n = int(TAXA * dur)
    t = np.linspace(0, 1, n)
    f = 200 + 1400 * t ** 2
    tom = np.sin(2 * np.pi * np.cumsum(f) / TAXA) * 0.35
    ar = _passa_baixa(_ruido(n, rng), 400 + 7000 * t ** 2) * 0.9
    return (tom + ar) * t ** 1.8


def pop(rng, dur=None):
    dur = dur or 0.12
    n = int(TAXA * dur)
    t = np.arange(n) / TAXA
    f = rng.uniform(600, 900) * np.exp(-t * 25) + 250
    return np.sin(2 * np.pi * np.cumsum(f) / TAXA) * _env(n, 0.002, 0.25)


def sino(rng, dur=None):
    dur = dur or rng.uniform(0.6, 0.9)
    n = int(TAXA * dur)
    t = np.arange(n) / TAXA
    base = rng.choice([880.0, 987.8, 1046.5, 1174.7])
    x = sum(a * np.sin(2 * np.pi * base * m * t) for m, a in ((1, 1), (2.01, 0.4), (3.02, 0.18)))
    return x * _env(n, 0.003, 0.3) * 0.6


def glitch(rng, dur=None):
    dur = dur or rng.uniform(0.18, 0.3)
    n = int(TAXA * dur)
    bloco = int(TAXA * 0.012)
    x = np.zeros(n)
    for i in range(0, n, bloco):
        if rng.random() < 0.7:
            f = rng.uniform(200, 2500)
            seg = np.sign(np.sin(2 * np.pi * f * np.arange(min(bloco, n - i)) / TAXA))
            x[i: i + bloco] = seg * rng.uniform(0.2, 0.6)
    return x


def grave(rng, dur=None):
    """Bass drop curto para cortes fortes."""
    dur = dur or rng.uniform(0.5, 0.8)
    n = int(TAXA * dur)
    t = np.arange(n) / TAXA
    f = 70 * np.exp(-t * 3) + 35
    return np.tanh(np.sin(2 * np.pi * np.cumsum(f) / TAXA) * 2) * _env(n, 0.005, 0.5)


def clique(rng, dur=None):
    n = int(TAXA * 0.04)
    return _passa_baixa(_ruido(n, rng), 6000) * _env(n, 0.001, 0.08) * 1.2


EFEITOS = {
    "whoosh": whoosh, "impacto": impacto, "subida": subida, "pop": pop,
    "sino": sino, "glitch": glitch, "grave": grave, "clique": clique,
}
GANHO = {"whoosh": 0.35, "impacto": 0.55, "subida": 0.3, "pop": 0.3, "sino": 0.25,
         "glitch": 0.2, "grave": 0.45, "clique": 0.25}


def montar_trilha(cues: list[dict], duracao: float, destino: Path, semente: int) -> Path:
    """Mistura os efeitos em uma faixa estéreo WAV do tamanho do vídeo.

    cue = {"t": segundos, "efeito": nome, "ganho": opcional, "fim_em": opcional (alinha o fim do som)}
    """
    rng = np.random.default_rng(semente)
    n = int(TAXA * duracao) + TAXA
    esq, dir_ = np.zeros(n), np.zeros(n)
    for cue in cues:
        som = EFEITOS[cue["efeito"]](rng, cue.get("dur"))
        som = som / (np.abs(som).max() + 1e-9) * GANHO[cue["efeito"]] * cue.get("ganho", 1.0)
        inicio = cue["t"] - (len(som) / TAXA if cue.get("fim_em") else 0)
        i = int(max(0.0, inicio) * TAXA)
        if inicio < 0:
            som = som[int(-inicio * TAXA):]
        som = som[: max(0, n - i)]
        pan = cue.get("pan", rng.uniform(-0.25, 0.25))
        esq[i: i + len(som)] += som * (1 - max(0, pan))
        dir_[i: i + len(som)] += som * (1 + min(0, pan))
    estereo = np.stack([esq, dir_], axis=1)[: int(TAXA * duracao)]
    pico = np.abs(estereo).max()
    if pico > 0.95:
        estereo *= 0.95 / pico
    dados = (estereo * 32767).astype("<i2")
    with wave.open(str(destino), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(dados.tobytes())
    return destino
