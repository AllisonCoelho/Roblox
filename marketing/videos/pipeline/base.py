"""Caminhos, configuração e chamadas ao FFmpeg usados por todo o pipeline."""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ENTRADAS = RAIZ / "entradas"
SAIDA = RAIZ / "saida"
CACHE = RAIZ / ".cache"
FONTES = RAIZ / "fontes"
EXTENSOES_VIDEO = {".mp4", ".mov", ".mkv", ".webm", ".avi", ".m4v"}


class ErroPipeline(RuntimeError):
    pass


def carregar_config(caminho: Path | None = None) -> dict:
    caminho = caminho or RAIZ / "config.json"
    with open(caminho, encoding="utf-8") as f:
        return json.load(f)


def exigir_ferramentas() -> None:
    for nome in ("ffmpeg", "ffprobe"):
        if shutil.which(nome) is None:
            raise ErroPipeline(f"'{nome}' não encontrado no PATH. Instale o FFmpeg (com libass).")
    filtros = executar(["ffmpeg", "-hide_banner", "-filters"]).stdout
    for filtro in ("ass", "zoompan", "ebur128"):
        if f" {filtro} " not in filtros:
            raise ErroPipeline(f"O FFmpeg instalado não tem o filtro '{filtro}'.")


def executar(cmd: list[str], *, entrada: bytes | None = None, checar: bool = True) -> subprocess.CompletedProcess:
    proc = subprocess.run(cmd, input=entrada, capture_output=True, text=entrada is None)
    if checar and proc.returncode != 0:
        erro = proc.stderr if isinstance(proc.stderr, str) else proc.stderr.decode("utf-8", "replace")
        raise ErroPipeline(f"Falhou: {' '.join(cmd[:6])} ...\n{erro[-2500:]}")
    return proc


@dataclass
class InfoMidia:
    caminho: Path
    duracao: float
    largura: int
    altura: int
    fps: float
    tem_audio: bool
    codec_video: str
    codec_audio: str | None
    taxa_audio: int | None


def sondar(caminho: Path) -> InfoMidia:
    proc = executar([
        "ffprobe", "-v", "error", "-print_format", "json",
        "-show_format", "-show_streams", str(caminho),
    ])
    dados = json.loads(proc.stdout)
    video = next((s for s in dados["streams"] if s["codec_type"] == "video"), None)
    audio = next((s for s in dados["streams"] if s["codec_type"] == "audio"), None)
    if video is None:
        raise ErroPipeline(f"{caminho.name}: sem faixa de vídeo")
    num, _, den = video.get("avg_frame_rate", "30/1").partition("/")
    fps = float(num) / float(den or 1) if float(den or 1) else 30.0
    duracao = float(dados["format"].get("duration") or video.get("duration") or 0)
    largura, altura = int(video["width"]), int(video["height"])
    rot = 0
    for side in video.get("side_data_list", []) or []:
        rot = int(side.get("rotation", 0) or 0)
    if abs(rot) in (90, 270):
        largura, altura = altura, largura
    return InfoMidia(
        caminho=caminho, duracao=duracao, largura=largura, altura=altura, fps=fps or 30.0,
        tem_audio=audio is not None, codec_video=video.get("codec_name", "?"),
        codec_audio=audio.get("codec_name") if audio else None,
        taxa_audio=int(audio["sample_rate"]) if audio and audio.get("sample_rate") else None,
    )


def hash_arquivo(caminho: Path, completo: bool = True) -> str:
    """SHA-256 do arquivo. Com completo=False usa só tamanho, data e as pontas (rápido, para cache)."""
    h = hashlib.sha256()
    if not completo:
        st = caminho.stat()
        h.update(f"{st.st_size}:{int(st.st_mtime)}".encode())
        with open(caminho, "rb") as f:
            h.update(f.read(1 << 20))
            if st.st_size > 2 << 20:
                f.seek(-(1 << 20), 2)
                h.update(f.read())
        return h.hexdigest()[:20]
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 22), b""):
            h.update(bloco)
    return h.hexdigest()


def listar_gravacoes(pasta: Path = ENTRADAS) -> list[Path]:
    if not pasta.exists():
        return []
    return sorted(p for p in pasta.rglob("*") if p.is_file() and p.suffix.lower() in EXTENSOES_VIDEO)


def carregar_marcacoes(video: Path) -> dict:
    """Lê o arquivo opcional <video>.json escrito pelo dono, com o que realmente acontece na gravação.

    O pipeline só cita nomes de auras, raridades ou resultados que estejam neste arquivo.
    """
    lateral = video.with_suffix(".json")
    if not lateral.exists():
        return {"eventos": [], "ignorar": []}
    with open(lateral, encoding="utf-8") as f:
        dados = json.load(f)
    eventos = []
    for ev in dados.get("eventos", []):
        try:
            inicio = float(ev["inicio"])
            fim = float(ev.get("fim", inicio + 4))
        except (KeyError, TypeError, ValueError):
            raise ErroPipeline(f"{lateral.name}: evento sem 'inicio' numérico: {ev}")
        if fim <= inicio:
            raise ErroPipeline(f"{lateral.name}: evento com fim <= inicio: {ev}")
        eventos.append({**ev, "inicio": inicio, "fim": fim})
    ignorar = [(float(a), float(b)) for a, b in dados.get("ignorar", [])]
    return {**dados, "eventos": eventos, "ignorar": ignorar}
