#!/usr/bin/env python3
"""Despertar — gerador de vídeos curtos (TikTok, Shorts, Reels) a partir de gravações de gameplay.

Uso:
  python3 despertar_videos.py analisar                 # mostra os momentos encontrados
  python3 despertar_videos.py produzir -n 5            # produz um lote de 5 vídeos
  python3 despertar_videos.py produzir -n 3 --estilos revelacao,pov
  python3 despertar_videos.py verificar saida/lote_... # refaz o controle de qualidade
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pipeline import qc  # noqa: E402
from pipeline.base import ErroPipeline, carregar_config  # noqa: E402
from pipeline.estilos import ESTILOS  # noqa: E402
from pipeline.lote import analisar_tudo, produzir  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", type=Path, help="arquivo de configuração (padrão: config.json)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("analisar", help="analisa as gravações e gera folhas de contato dos momentos")
    p = sub.add_parser("produzir", help="produz um lote de vídeos")
    p.add_argument("-n", "--quantidade", type=int, default=5)
    p.add_argument("--estilos", help=f"lista separada por vírgula entre: {', '.join(ESTILOS)}")
    p.add_argument("--origem", action="append", help="usar só esta gravação (pode repetir)")
    p.add_argument("--semente", type=int, help="semente para repetir exatamente um lote")
    v = sub.add_parser("verificar", help="refaz o QC de um lote")
    v.add_argument("pasta", type=Path)
    args = ap.parse_args()
    cfg = carregar_config(args.config)
    try:
        if args.cmd == "analisar":
            analisar_tudo(cfg)
        elif args.cmd == "produzir":
            if not 1 <= args.quantidade <= 100:
                ap.error("--quantidade deve ficar entre 1 e 100")
            estilos = [e.strip() for e in args.estilos.split(",")] if args.estilos else None
            produzir(args.quantidade, cfg, estilos=estilos, semente=args.semente, origens=args.origem)
        elif args.cmd == "verificar":
            falhas = 0
            for video in sorted(args.pasta.glob("*/video.mp4")):
                plano = video.parent / "plano.json"
                info = json.loads(plano.read_text(encoding="utf-8")) if plano.exists() else None
                r = qc.verificar(video, cfg, info)
                qc.salvar(r, video.parent / "qc.json")
                falhas += not r["ok"]
                print(f"{video.parent.name}: {'OK' if r['ok'] else 'FALHOU'} {r.get('duracao')}s "
                      f"{r.get('resolucao')} {r.get('audio_lufs')} LUFS {r['problemas'] + r['avisos']}")
            return 1 if falhas else 0
    except ErroPipeline as e:
        print(f"ERRO: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
