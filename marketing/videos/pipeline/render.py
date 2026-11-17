"""Renderização com FFmpeg: cada trecho vira um intermediário 1080x1920, depois tudo é
concatenado, recebe os textos (ASS), os efeitos sonoros e a normalização de volume."""
from __future__ import annotations

import os
from pathlib import Path

from .base import FONTES, InfoMidia, executar, sondar
from .estilos import Plano, Trecho
from .sfx import montar_trilha
from .textos import Legenda

SUPERAMOSTRA = 1.5  # o zoompan trabalha em resolução maior para o zoom lento não "tremer"


def _expr_zoom(chaves: list) -> str:
    chaves = sorted(chaves)
    if len(chaves) == 1:
        return f"{chaves[0][1]:.4f}"
    expr = f"{chaves[-1][1]:.4f}"
    for (t0, z0), (t1, z1) in reversed(list(zip(chaves, chaves[1:]))):
        if t1 - t0 < 1e-3:
            continue
        p = f"((it-{t0:.3f})/{t1 - t0:.3f})"
        seg = f"({z0:.4f}+({z1 - z0:.4f})*{p}*{p}*(3-2*{p}))"
        expr = f"if(lt(it,{t1:.3f}),{seg},{expr})"
    return f"if(lt(it,{chaves[0][0]:.3f}),{chaves[0][1]:.4f},{expr})"


def _expr_tremor(tremores: list, eixo: int) -> str:
    if not tremores:
        return "0"
    freq = 61 if eixo == 0 else 47
    partes = [f"{a}*sin(it*{freq})*between(it,{t0:.3f},{t1:.3f})*(1-(it-{t0:.3f})/{t1 - t0:.3f})"
              for t0, t1, a in tremores]
    return "+".join(partes)


def _geometria(info: InfoMidia, tr: Trecho, W: int, H: int):
    """Retorna (região de recorte na origem, tamanho do primeiro plano, y do primeiro plano, foco no recorte)."""
    sw, sh = info.largura, info.altura
    layout = tr.layout
    if sh > sw:  # gravação já vertical
        layout = "recorte"
    if layout == "recorte":
        rw, rh = min(sw, round(sh * W / H)), sh
        if rw == sw:
            rh = min(sh, round(sw * H / W))
        fw, fh, fy = W, H, 0
    elif layout == "meio":
        rw, rh = min(sw, round(sh * 3 / 4)), sh
        fw, fh = W, round(W * 4 / 3)
        fy = (H - fh) // 2
    else:  # preenchido: quadro inteiro
        rw, rh = sw, sh
        fw, fh = W, round(W * sh / sw / 2) * 2
        fy = (H - fh) // 2 - 40
    rw -= rw % 2
    rh -= rh % 2
    cx = tr.foco_x * sw
    x0 = int(min(max(0, cx - rw / 2), sw - rw))
    y0 = (sh - rh) // 2
    foco_rel = (cx - x0) / rw
    return (rw, rh, x0, y0), (fw, fh, fy), foco_rel


def renderizar_trecho(tr: Trecho, destino: Path, cfg: dict) -> Path:
    W, H, FPS = cfg["saida"]["largura"], cfg["saida"]["altura"], cfg["saida"]["fps"]
    info = sondar(tr.origem)
    (rw, rh, x0, y0), (fw, fh, fy), foco = _geometria(info, tr, W, H)
    dur = tr.dur_saida
    sw_, sh_ = int(fw * SUPERAMOSTRA) // 2 * 2, int(fh * SUPERAMOSTRA) // 2 * 2

    base = f"[0:v]setpts=(PTS-STARTPTS)/{tr.velocidade:.4f},fps={FPS}"
    if tr.congelar > 0:
        base += f",tpad=stop_mode=clone:stop_duration={tr.congelar:.3f}"
    base += f",trim=duration={dur:.3f},setpts=PTS-STARTPTS"

    zoom = _expr_zoom(tr.zoom)
    tx, ty = _expr_tremor(tr.tremor, 0), _expr_tremor(tr.tremor, 1)
    zp = (f"zoompan=z='{zoom}':x='max(0,min(iw-iw/zoom,{foco:.4f}*iw-iw/zoom/2))+({tx})'"
          f":y='(ih-ih/zoom)/2+({ty})':d=1:s={fw}x{fh}:fps={FPS}")
    fg = f"crop={rw}:{rh}:{x0}:{y0},scale={sw_}:{sh_}:flags=lanczos,setsar=1,{zp}"

    partes = []
    if (fw, fh) == (W, H):
        partes.append(f"{base},{fg}[comp]")
    else:
        partes.append(f"{base},split[a][b]")
        partes.append(f"[a]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
                      f"gblur=sigma=30,eq=brightness=-0.14:saturation=1.25[fundo]")
        partes.append(f"[b]{fg}[frente]")
        partes.append(f"[fundo][frente]overlay=0:{fy}:shortest=1[comp]")

    brilho = "+".join(f"{i}*exp(-(t-{t:.3f})*7)*gte(t,{t:.3f})" for t, i in tr.clarao) or "0"
    satur = f"{tr.saturacao:.3f}"
    if tr.congelar > 0:
        t_c = tr.dur / tr.velocidade
        satur = f"if(gte(t,{t_c:.3f}),0.35,{tr.saturacao:.3f})"
        brilho = f"({brilho})-0.06*gte(t,{t_c:.3f})"
    pos = f"[comp]eq=brightness='{brilho}':saturation='{satur}':contrast=1.04:eval=frame"
    for g0, g1 in tr.glitch:
        pos += (f",rgbashift=rh=-14:bh=14:gv=6:enable='between(t,{g0:.3f},{g1:.3f})'"
                f",noise=alls=28:allf=t:enable='between(t,{g0:.3f},{g1:.3f})'")
    pos += ",unsharp=5:5:0.4,format=yuv420p[v]"
    partes.append(pos)

    if info.tem_audio:
        tempos = []
        v = tr.velocidade
        while v < 0.5:
            tempos.append("atempo=0.5")
            v /= 0.5
        tempos.append(f"atempo={v:.4f}")
        partes.append(f"[0:a]asetpts=PTS-STARTPTS,{','.join(tempos)},volume={tr.volume:.2f},aresample=48000,"
                      f"aformat=sample_fmts=fltp:channel_layouts=stereo,apad,atrim=duration={dur:.3f}[a]")
        mapa_a = "[a]"
        extra = []
    else:
        extra = ["-f", "lavfi", "-t", f"{dur:.3f}", "-i", "anullsrc=r=48000:cl=stereo"]
        mapa_a = "1:a"

    cmd = ["ffmpeg", "-v", "error", "-y", "-ss", f"{tr.inicio:.3f}", "-t", f"{tr.dur + 0.1:.3f}",
           "-i", str(tr.origem), *extra, "-filter_complex", ";".join(partes),
           "-map", "[v]", "-map", mapa_a, "-t", f"{dur:.3f}",
           "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-r", str(FPS),
           "-c:a", "pcm_s16le", "-ar", "48000", str(destino)]
    executar(cmd)
    return destino


def _caminho_filtro(p: Path) -> str:
    """Escapa um caminho para uso dentro de um filtro do FFmpeg (também no Windows)."""
    s = str(p.resolve()).replace("\\", "/")
    return s.replace(":", "\\:").replace("'", "\\'").replace(",", "\\,")


def renderizar_plano(plano: Plano, pasta: Path, cfg: dict, semente: int, amostra_tecnica: bool = False) -> dict:
    W, H = cfg["saida"]["largura"], cfg["saida"]["altura"]
    tmp = pasta / "_tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    pedacos = []
    for i, tr in enumerate(plano.trechos):
        pedacos.append(renderizar_trecho(tr, tmp / f"trecho_{i:02d}.mkv", cfg))
    lista = tmp / "lista.txt"
    lista.write_text("".join(f"file '{p.resolve().as_posix()}'\n" for p in pedacos), encoding="utf-8")
    duracao = plano.duracao

    zona = cfg["zona_segura"]
    leg = Legenda(W, H, zona)
    for tx in plano.textos:
        tx = dict(tx)
        tipo = tx.pop("tipo")
        txt, ini, fim = tx.pop("txt"), max(0.0, tx.pop("inicio")), min(duracao, tx.pop("fim"))
        if fim - ini < 0.3:
            continue
        if tipo == "selo":
            leg.selo(txt, ini, fim, **tx)
        else:
            leg.texto(txt, ini, fim, **tx)
    if amostra_tecnica:
        leg.marca_teste(duracao)
    ass = leg.salvar(tmp / "textos.ass")
    trilha = montar_trilha(plano.sfx, duracao, tmp / "sfx.wav", semente)

    s = cfg["saida"]
    video = pasta / "video.mp4"
    filtro = (f"[0:v]ass='{_caminho_filtro(ass)}':fontsdir='{_caminho_filtro(FONTES)}',format=yuv420p[v];"
              f"[0:a]volume={cfg['audio']['volume_jogo']}[j];[1:a]volume={cfg['audio']['volume_efeitos']}[e];"
              f"[j][e]amix=inputs=2:duration=first:normalize=0,"
              f"loudnorm=I={s['lufs']}:TP=-1.5:LRA=11,aresample=48000,alimiter=limit=0.7:attack=1:release=40:level=false[a]")
    executar(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(lista), "-i", str(trilha),
              "-filter_complex", filtro, "-map", "[v]", "-map", "[a]", "-t", f"{duracao:.3f}",
              "-c:v", "libx264", "-preset", s["preset"], "-crf", str(s["crf"]), "-profile:v", "high",
              "-pix_fmt", "yuv420p", "-r", str(s["fps"]), "-g", str(s["fps"] * 2),
              "-c:a", "aac", "-b:a", f"{s['audio_kbps']}k", "-ar", "48000",
              "-movflags", "+faststart", str(video)])
    capa = pasta / "capa.jpg"
    executar(["ffmpeg", "-v", "error", "-y", "-ss", f"{min(plano.capa_t, duracao - 0.1):.2f}", "-i", str(video),
              "-frames:v", "1", "-q:v", "2", str(capa)])
    if not os.environ.get("DESPERTAR_MANTER_TMP"):
        for p in tmp.iterdir():
            p.unlink()
        tmp.rmdir()
    return {"video": video, "capa": capa, "duracao": duracao}
