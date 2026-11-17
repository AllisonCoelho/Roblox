"""Testes rápidos do pipeline (sem renderizar vídeo). Rodar: python3 testes_pipeline.py"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pipeline import metadados  # noqa: E402
from pipeline.base import ErroPipeline, carregar_config, carregar_marcacoes  # noqa: E402
from pipeline.estilos import ESTILOS, Plano, Trecho, ajustar_duracao  # noqa: E402
from pipeline.render import _expr_zoom  # noqa: E402
from pipeline.textos import Legenda  # noqa: E402

CFG = carregar_config()
POS = {"topo": 330, "centro": 880, "base": 1460}


def momento(pico, forca=5.0, tipo="explosao", evento=None, i=0):
    return {"origem": f"g{i}.mp4", "origem_path": Path(f"g{i}.mp4"), "pico": pico, "inicio": pico - 6,
            "fim": pico + 4, "forca": forca, "tipo": tipo, "foco_x": 0.5, "dispersao_foco": 0.05,
            "evento": evento, "dur_origem": 300.0}


class TestFatos(unittest.TestCase):
    def test_sem_marcacao_nao_cita_aura(self):
        rng = np.random.default_rng(1)
        for nome, fn in ESTILOS.items():
            moms = [momento(30 + 20 * k, forca=6 - k, i=k) for k in range(6)]
            for _ in range(20):
                p = fn(moms, rng, CFG, POS)
                meta = metadados.gerar(p, CFG, rng)
                texto = " ".join([p.gancho, p.destaque, meta["titulo"], meta["legenda"]]).lower()
                for proibido in ("1 em", "tirei", "consegui", "gear"):
                    self.assertNotIn(proibido, texto, f"{nome}: '{proibido}' sem marcação")
                self.assertTrue(meta["classificacao"]["fatos_confirmados"].startswith("não"))

    def test_com_marcacao_usa_fatos(self):
        rng = np.random.default_rng(2)
        ev = {"inicio": 20, "fim": 30, "tipo": "revelacao", "titulo": "Coroa Solar", "raridade": "1 em 50.000"}
        p = ESTILOS["revelacao"]([momento(25, evento=ev)], rng, CFG, POS)
        meta = metadados.gerar(p, CFG, rng)
        self.assertIn("Coroa Solar", p.destaque)
        self.assertIn("Coroa Solar", meta["titulo"])
        self.assertIn("#coroasolar", meta["hashtags"])


class TestMarcacoes(unittest.TestCase):
    def test_valida_eventos(self):
        with tempfile.TemporaryDirectory() as d:
            v = Path(d) / "g.mp4"
            v.with_suffix(".json").write_text(json.dumps({"eventos": [{"inicio": 10, "fim": 5}]}))
            with self.assertRaises(ErroPipeline):
                carregar_marcacoes(v)
            v.with_suffix(".json").write_text(json.dumps({"eventos": [{"inicio": "3", "fim": 9}], "ignorar": [[0, 2]]}))
            m = carregar_marcacoes(v)
            self.assertEqual(m["eventos"][0]["inicio"], 3.0)
            self.assertEqual(m["ignorar"], [(0.0, 2.0)])

    def test_sem_arquivo(self):
        self.assertEqual(carregar_marcacoes(Path("/nao/existe.mp4"))["eventos"], [])


class TestTempo(unittest.TestCase):
    def test_expr_zoom(self):
        e = _expr_zoom([(0.0, 1.0), (1.0, 1.3), (2.0, 1.1)])
        self.assertIn("if(lt(it,0.000)", e)
        self.assertEqual(_expr_zoom([(0.0, 1.2)]), "1.2000")

    def test_ajustar_duracao(self):
        tr = Trecho(Path("g.mp4"), 0, 30.0, zoom=[(0.0, 1.0), (30.0, 1.1)])
        p = Plano("pov", [tr], textos=[{"tipo": "texto", "txt": "x", "inicio": 20.0, "fim": 22.0, "y": 500}],
                  sfx=[{"t": 20.0, "efeito": "pop"}], capa_t=20.0)
        ajustar_duracao(p, 8, 25)
        self.assertAlmostEqual(p.duracao, 25.0, places=3)
        self.assertAlmostEqual(p.textos[0]["inicio"], 15.0, places=3)
        self.assertAlmostEqual(p.sfx[0]["t"], 15.0, places=3)

    def test_duracoes_dos_estilos(self):
        rng = np.random.default_rng(3)
        moms = [momento(40 + 25 * k, forca=8 - k, i=k) for k in range(6)]
        for nome, fn in ESTILOS.items():
            for _ in range(15):
                p = ajustar_duracao(fn(moms, rng, CFG, POS), 8, 25)
                self.assertGreaterEqual(p.duracao, 7.5, nome)
                self.assertLessEqual(p.duracao, 25.01, nome)
                for tx in p.textos:
                    self.assertTrue(220 <= tx["y"] <= 1920 - 420, f"{nome}: texto fora da zona segura")


class TestTextos(unittest.TestCase):
    def test_escapa_chaves(self):
        leg = Legenda(1080, 1920, CFG["zona_segura"])
        leg.texto("oi {\\b1}", 0, 1, y=400)
        self.assertNotIn("{\\b1}", leg.eventos[0].split("}", 1)[1])


if __name__ == "__main__":
    unittest.main(verbosity=1)
