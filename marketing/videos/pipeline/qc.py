"""Controle de qualidade dos vídeos exportados."""
from __future__ import annotations

import json
import re
from pathlib import Path

from .base import executar, sondar


def _loudness(video: Path) -> dict:
    proc = executar(["ffmpeg", "-hide_banner", "-nostats", "-i", str(video), "-vn",
                     "-af", "ebur128=peak=true", "-f", "null", "-"], checar=False)
    txt = proc.stderr
    resumo = txt[txt.rfind("Summary:"):] if "Summary:" in txt else txt
    i = re.search(r"I:\s+(-?[\d.]+) LUFS", resumo)
    pk = re.search(r"Peak:\s+(-?[\d.]+|-inf) dBFS", resumo)
    return {"lufs": float(i.group(1)) if i else None,
            "pico_dbfs": float(pk.group(1)) if pk and pk.group(1) != "-inf" else None}


def _intervalos(video: Path, filtro: str, chave: str) -> float:
    proc = executar(["ffmpeg", "-hide_banner", "-nostats", "-i", str(video), "-an", "-vf", filtro,
                     "-f", "null", "-"], checar=False)
    total = 0.0
    for m in re.finditer(chave + r"_duration:\s*([\d.]+)", proc.stderr):
        total += float(m.group(1))
    return total


def verificar(video: Path, cfg: dict, plano_info: dict | None = None) -> dict:
    s, d = cfg["saida"], cfg["duracao"]
    res: dict = {"arquivo": video.name, "problemas": [], "avisos": []}
    if not video.exists() or video.stat().st_size < 50_000:
        res["problemas"].append("arquivo ausente ou muito pequeno")
        res["ok"] = False
        return res
    info = sondar(video)
    res.update({"duracao": round(info.duracao, 2), "resolucao": f"{info.largura}x{info.altura}",
                "fps": round(info.fps, 2), "audio": info.tem_audio, "tamanho_mb": round(video.stat().st_size / 1e6, 2)})
    if (info.largura, info.altura) != (s["largura"], s["altura"]):
        res["problemas"].append(f"resolução {info.largura}x{info.altura} (esperado {s['largura']}x{s['altura']})")
    if abs(info.fps - s["fps"]) > 0.5:
        res["problemas"].append(f"fps {info.fps:.2f}")
    if info.duracao < d["min"] - 0.5 or info.duracao > d["max"] + 5:
        res["problemas"].append(f"duração {info.duracao:.1f}s fora de {d['min']}–{d['max']}s")
    elif info.duracao > d["max"] + 0.5:
        res["avisos"].append(f"duração {info.duracao:.1f}s acima do alvo ({d['max']}s)")
    if info.codec_video != "h264" or info.codec_audio != "aac":
        res["problemas"].append(f"codecs {info.codec_video}/{info.codec_audio} (esperado h264/aac)")
    if not info.tem_audio:
        res["problemas"].append("sem faixa de áudio")

    # integridade: decodifica o arquivo inteiro
    proc = executar(["ffmpeg", "-v", "error", "-i", str(video), "-f", "null", "-"], checar=False)
    erros = [l for l in proc.stderr.splitlines() if l.strip()]
    if proc.returncode != 0 or erros:
        res["problemas"].append("erros de decodificação: " + "; ".join(erros[:3]))

    som = _loudness(video)
    res["audio_lufs"], res["audio_pico_dbfs"] = som["lufs"], som["pico_dbfs"]
    if som["lufs"] is None or som["lufs"] < -30:
        res["problemas"].append("áudio praticamente mudo")
    elif abs(som["lufs"] - s["lufs"]) > 3:
        res["avisos"].append(f"volume {som['lufs']:.1f} LUFS (alvo {s['lufs']})")
    if som["pico_dbfs"] is not None and som["pico_dbfs"] > -0.3:
        res["avisos"].append(f"pico de áudio {som['pico_dbfs']:.1f} dBFS (risco de distorção)")

    preto = _intervalos(video, "blackdetect=d=0.3:pix_th=0.08", "black")
    congelado = _intervalos(video, "freezedetect=n=0.002:d=2.5", "freeze")
    res["segundos_pretos"], res["segundos_congelados"] = round(preto, 2), round(congelado, 2)
    if preto > 1.0:
        res["problemas"].append(f"{preto:.1f}s de tela preta")
    if congelado > 0:
        res["avisos"].append(f"{congelado:.1f}s de imagem parada (confira se é pausa intencional)")

    if plano_info:
        # enquadramento: o foco do momento precisa cair dentro do recorte vertical
        for m in plano_info.get("enquadramento", []):
            if not m["foco_visivel"]:
                res["avisos"].append(f"foco do trecho {m['trecho']} perto da borda do recorte ({m['layout']})")
        if plano_info.get("textos_fora_da_zona"):
            res["problemas"].append("texto fora da zona segura")
    res["ok"] = not res["problemas"]
    return res


def salvar(res: dict, destino: Path) -> None:
    destino.write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
