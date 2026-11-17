#!/usr/bin/env python3
"""Gera uma gravação SINTÉTICA para testar o pipeline enquanto não há gameplay real.

Usa as prévias renderizadas dos cenários de Incursões (assets/incursoes/previews) com
movimento de câmera, clarões, tremores e sons sintéticos. NÃO é gameplay: o arquivo
de marcação marca a gravação como amostra técnica, e todos os vídeos gerados a partir
dela recebem a tarja "AMOSTRA TÉCNICA · não publicar".
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))
from pipeline.sfx import TAXA, montar_trilha  # noqa: E402

PREVIAS = RAIZ.parents[1] / "assets" / "incursoes" / "previews"
W, H, FPS = 1280, 720, 30

# (imagem, duração, tipo, eventos relativos à cena)
CENAS = [
    ("umbral_andar", 9, "calmo", []),
    ("mare_andar", 5, "explosao", [3.6]),
    ("cinzas_andar", 9, "calmo", []),
    ("cinzas_guardiao", 8, "combate", [1.5, 3.0, 4.4, 6.0]),
    ("mare_guardiao", 9, "calmo", []),
    ("umbral_guardiao", 6, "explosao", [4.2]),
    ("umbral_andar", 8, "calmo", []),
    ("mare_andar", 7, "combate", [1.2, 2.6, 4.1]),
    ("cinzas_guardiao", 7, "explosao", [4.8]),
]


def cena(img: Path, dur: float, tipo: str, eventos: list[float], destino: Path, sentido: int) -> None:
    n = int(dur * FPS)
    z = "1.08+0.0015*on" if sentido > 0 else "1.25-0.0015*on"
    x = f"(iw-iw/zoom)/2+{sentido}*on*0.6"
    filtros = [f"scale={W * 2}:{H * 2}", f"zoompan=z='{z}':x='{x}':y='(ih-ih/zoom)/2':d={n}:s={W}x{H}:fps={FPS}"]
    if eventos:
        forca = 0.75 if tipo == "explosao" else 0.3
        brilho = "+".join(f"{forca}*exp(-(t-{e})*6)*gte(t,{e})" for e in eventos)
        subida = "+".join(f"0.25*max(0,1-abs(t-{e})/1.5)*lt(t,{e})" for e in eventos) if tipo == "explosao" else "0"
        filtros.append(f"eq=brightness='{brilho}+{subida}':saturation='1.2+1.5*({subida})':eval=frame")
        amp = 26 if tipo == "combate" else 18
        trem = "+".join(f"{amp}*sin(t*70)*between(t,{e},{e + 0.4})" for e in eventos)
        filtros.append(f"pad={W + 80}:{H + 80}:40:40,crop={W}:{H}:x='40+{trem}':y='40+0.7*({trem})'")
    if tipo == "explosao":
        filtros.append(f"hue=h='120*exp(-(t-{eventos[0]})*2)*gte(t,{eventos[0]})'")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-i", str(img), "-t", str(dur),
                    "-vf", ",".join(filtros) + ",format=yuv420p", "-r", str(FPS),
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", str(destino)], check=True)


def main() -> None:
    destino = RAIZ / "entradas" / "amostra_tecnica.mp4"
    destino.parent.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(7)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        partes, cues, t = [], [], 0.0
        for i, (nome, dur, tipo, evs) in enumerate(CENAS):
            p = tmp / f"c{i}.mp4"
            cena(PREVIAS / f"{nome}.jpg", dur, tipo, evs, p, 1 if i % 2 == 0 else -1)
            partes.append(p)
            for e in evs:
                if tipo == "explosao":
                    cues += [{"t": t + e, "efeito": "subida", "fim_em": True, "dur": 1.5}, {"t": t + e, "efeito": "impacto"}]
                else:
                    cues += [{"t": t + e - 0.15, "efeito": "whoosh"}, {"t": t + e, "efeito": "grave", "ganho": 0.8}]
            t += dur
        trilha = montar_trilha(cues, t, tmp / "a.wav", 11)
        # ambiente grave e contínuo para a gravação não ficar muda entre os eventos
        amb = tmp / "amb.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i",
                        f"anoisesrc=d={t}:c=brown:a=0.05:r={TAXA}", "-af", "lowpass=f=400", "-ac", "2", str(amb)], check=True)
        lista = tmp / "l.txt"
        lista.write_text("".join(f"file '{p}'\n" for p in partes))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lista),
                        "-i", str(trilha), "-i", str(amb), "-filter_complex", "[1:a][2:a]amix=inputs=2:normalize=0[a]",
                        "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-shortest", str(destino)], check=True)
    destino.with_suffix(".json").write_text(json.dumps({
        "amostra_tecnica": True,
        "descricao": "Gravação sintética (prévias de Incursões + efeitos). Não é gameplay real; não publicar.",
        "eventos": [],
        "ignorar": [],
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Amostra técnica: {destino} ({t:.0f}s)")


if __name__ == "__main__":
    main()
