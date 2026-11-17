"""Produção em lote: análise → escolha de momentos e estilos → render → QC → metadados → CSV."""
from __future__ import annotations

import csv
import json
import shutil
import time
from datetime import datetime
from pathlib import Path

import numpy as np

from . import analise, metadados, qc
from .base import ENTRADAS, SAIDA, ErroPipeline, carregar_marcacoes, exigir_ferramentas, hash_arquivo, listar_gravacoes, sondar
from .estilos import ESTILOS, NECESSIDADE, PREFERE, PREFERENCIA_FORTE, PRIORIDADE, ajustar_duracao
from .render import _geometria, renderizar_plano

REGISTRO = SAIDA / "registro.json"
CONTROLE = SAIDA / "controle_publicacao.csv"
COLUNAS = ["id", "lote", "arquivo", "capa", "estilo", "duracao_s", "titulo", "legenda", "hashtags",
           "faixa_etaria", "categoria", "violencia", "fatos_confirmados", "gancho", "origens", "trechos",
           "qc_ok", "qc_problemas", "qc_avisos", "status", "plataformas", "data_agendada", "aprovado_por",
           "link_publicado", "observacoes"]


def _chave(m: dict) -> str:
    return f"{m['origem']}@{round(m['pico'])}"


def _ler_registro() -> dict:
    if REGISTRO.exists():
        return json.loads(REGISTRO.read_text(encoding="utf-8"))
    return {"usos": {}, "assinaturas": []}


def coletar_momentos(gravacoes: list[Path], log=print) -> list[dict]:
    todos = []
    for g in gravacoes:
        t0 = time.time()
        a = analise.analisar(g)
        marc = carregar_marcacoes(g)
        moms = analise.encontrar_momentos(g, a)
        for m in moms:
            m["dur_origem"] = a["info"].duracao
            m["origem_path"] = g
            m["amostra_tecnica"] = bool(marc.get("amostra_tecnica"))
        log(f"  {g.name}: {a['info'].duracao:.0f}s, {len(moms)} momentos ({time.time() - t0:.1f}s)")
        todos += moms
    todos.sort(key=lambda m: -m["forca"])
    return todos


def _escolher_momentos(estilo: str, pool: list[dict], usados_lote: set, registro: dict) -> list[dict] | None:
    precisa = NECESSIDADE[estilo]
    pref = PREFERE[estilo]

    def custo(m):
        k = _chave(m)
        anteriores = registro["usos"].get(k, [])
        c = -m["forca"]
        c += 6 * (k in usados_lote)
        c += 4 * (estilo in anteriores) + 1.5 * len(anteriores)
        if pref and m["tipo"] not in pref:
            c += 8 if estilo in PREFERENCIA_FORTE else 1.5
        return c

    candidatos = sorted(pool, key=custo)
    if precisa == 1:
        m = candidatos[0] if candidatos else None
        if m is None or (_chave(m) in usados_lote and estilo in ("revelacao", "pausa", "pov")):
            livres = [c for c in candidatos if _chave(c) not in usados_lote]
            m = livres[0] if livres else None
        return [m] if m else None
    if len(candidatos) < precisa:
        return None
    escolha = candidatos[: max(precisa, min(6, len(candidatos)))]
    return sorted(escolha, key=lambda m: -m["forca"])


def _info_enquadramento(plano, cfg) -> dict:
    W, H = cfg["saida"]["largura"], cfg["saida"]["altura"]
    enq = []
    for i, tr in enumerate(plano.trechos):
        _, _, foco = _geometria(sondar(tr.origem), tr, W, H)
        enq.append({"trecho": i, "layout": tr.layout, "foco_rel": round(foco, 3), "foco_visivel": 0.12 <= foco <= 0.88})
    z = cfg["zona_segura"]
    fora = [t for t in plano.textos if not (z["topo"] <= t["y"] <= H - z["base"])]
    return {"enquadramento": enq, "textos_fora_da_zona": len(fora)}


def _plano_json(plano) -> dict:
    return {
        "estilo": plano.estilo, "duracao": round(plano.duracao, 2), "variacao": plano.variacao,
        "gancho": plano.gancho, "destaque": plano.destaque,
        "trechos": [{"origem": tr.origem.name, "inicio": round(tr.inicio, 2), "dur": round(tr.dur, 2),
                     "velocidade": tr.velocidade, "layout": tr.layout, "congelar": round(tr.congelar, 2)}
                    for tr in plano.trechos],
        "textos": plano.textos, "sfx": plano.sfx,
        "momentos": [{k: v for k, v in m.items() if k != "origem_path"} for m in plano.momentos],
    }


def produzir(quantidade: int, cfg: dict, estilos: list[str] | None = None, semente: int | None = None,
             origens: list[str] | None = None, log=print) -> Path:
    exigir_ferramentas()
    gravacoes = listar_gravacoes()
    if origens:
        gravacoes = [g for g in gravacoes if g.name in origens]
    if not gravacoes:
        raise ErroPipeline(f"Nenhuma gravação em {ENTRADAS}. Copie os vídeos de gameplay para essa pasta.")
    semente = int(semente if semente is not None else time.time()) % (2**31)
    rng = np.random.default_rng(semente)
    agora = datetime.now()
    lote_id = agora.strftime("lote_%Y%m%d_%H%M%S")
    pasta_lote = SAIDA / lote_id
    pasta_lote.mkdir(parents=True, exist_ok=True)

    log(f"Conferindo {len(gravacoes)} gravação(ões) originais (hash)...")
    hashes_antes = {g.name: hash_arquivo(g) for g in gravacoes}
    log("Analisando:")
    pool = coletar_momentos(gravacoes, log)
    if not pool:
        raise ErroPipeline("Nenhum momento interessante encontrado nas gravações.")

    registro = _ler_registro()
    if estilos:
        desconhecidos = [e for e in estilos if e not in ESTILOS]
        if desconhecidos:
            raise ErroPipeline(f"Estilos desconhecidos: {desconhecidos}. Disponíveis: {list(ESTILOS)}")
        ciclo = list(estilos)
    else:
        ciclo = list(ESTILOS)
        rng.shuffle(ciclo)
    pos = {"topo": cfg["zona_segura"]["topo"] + 110, "centro": int(cfg["saida"]["altura"] * 0.46),
           "base": cfg["saida"]["altura"] - cfg["zona_segura"]["base"] - 40}

    usados_lote: set = set()
    linhas, resultados = [], []

    # 1) monta os planos: estilos em rodízio, mas os momentos são distribuídos por prioridade
    pedidos = [ciclo[i % len(ciclo)] for i in range(quantidade)]
    ordem = sorted(range(quantidade), key=lambda i: PRIORIDADE.index(pedidos[i]))
    planos: dict[int, object] = {}
    assinaturas_lote: set = set()
    for i in ordem:
        alternativas = [pedidos[i]] + [e for e in ciclo if e != pedidos[i]]
        for estilo in alternativas:
            moms = _escolher_momentos(estilo, pool, usados_lote, registro)
            plano = ESTILOS[estilo](moms, rng, cfg, pos) if moms else None
            if plano is None:
                continue
            plano = ajustar_duracao(plano, cfg["duracao"]["min"], cfg["duracao"]["max"])
            assinatura = f"{estilo}|" + ",".join(sorted(_chave(m) for m in plano.momentos))
            if assinatura in registro["assinaturas"] or assinatura in assinaturas_lote:
                continue
            if plano.duracao < cfg["duracao"]["min"] - 0.5:
                log(f"  descartado {estilo}: só {plano.duracao:.1f}s")
                continue
            planos[i] = (plano, assinatura)
            assinaturas_lote.add(assinatura)
            for m in plano.momentos:
                usados_lote.add(_chave(m))
            break

    # 2) renderiza na ordem do rodízio
    for i in sorted(planos):
        plano, assinatura = planos[i]
        estilo = plano.estilo
        num = len(resultados) + 1
        vid_id = f"{lote_id}_{num:02d}"
        pasta = pasta_lote / f"{num:02d}_{estilo}"
        pasta.mkdir(parents=True, exist_ok=True)
        amostra = any(m.get("amostra_tecnica") for m in plano.momentos)
        log(f"[{num}/{quantidade}] {estilo}: {len(plano.trechos)} trecho(s), {plano.duracao:.1f}s ...")
        t0 = time.time()
        saida = renderizar_plano(plano, pasta, cfg, semente + num, amostra_tecnica=amostra)
        meta = metadados.gerar(plano, cfg, rng)
        info_enq = _info_enquadramento(plano, cfg)
        res_qc = qc.verificar(saida["video"], cfg, info_enq)
        qc.salvar(res_qc, pasta / "qc.json")
        (pasta / "plano.json").write_text(json.dumps({**_plano_json(plano), **info_enq}, ensure_ascii=False, indent=2,
                                                      default=str), encoding="utf-8")
        (pasta / "metadados.json").write_text(json.dumps({"id": vid_id, **meta}, ensure_ascii=False, indent=2),
                                              encoding="utf-8")
        (pasta / "legenda.txt").write_text(
            f"{meta['titulo']}\n\n{meta['legenda']}\n\n{' '.join(meta['hashtags'])}\n", encoding="utf-8")
        m0 = plano.momentos[-1] if estilo in ("montagem", "top3") else plano.momentos[0]
        analise.folha_de_contato(m0["origem_path"], m0, pasta / "referencia_momento.jpg")
        estado = "teste_tecnico_nao_publicar" if amostra else ("aguardando_aprovacao" if res_qc["ok"] else "corrigir")
        log(f"     ok em {time.time() - t0:.0f}s · QC {'OK' if res_qc['ok'] else 'FALHOU'}"
            + (f" · avisos: {'; '.join(res_qc['avisos'])}" if res_qc["avisos"] else ""))
        for m in plano.momentos:
            registro["usos"].setdefault(_chave(m), []).append(estilo)
        registro["assinaturas"].append(assinatura)
        linhas.append({
            "id": vid_id, "lote": lote_id, "arquivo": str(saida["video"].relative_to(SAIDA)),
            "capa": str(saida["capa"].relative_to(SAIDA)), "estilo": estilo, "duracao_s": res_qc.get("duracao"),
            "titulo": meta["titulo"], "legenda": meta["legenda"].replace("\n", " "), "hashtags": " ".join(meta["hashtags"]),
            "faixa_etaria": meta["classificacao"]["faixa_etaria"], "categoria": meta["classificacao"]["categoria"],
            "violencia": meta["classificacao"]["violencia"], "fatos_confirmados": meta["classificacao"]["fatos_confirmados"],
            "gancho": meta["gancho_no_video"], "origens": " ".join(sorted({m["origem"] for m in plano.momentos})),
            "trechos": " ".join(f"{tr.origem.name}@{tr.inicio:.1f}+{tr.dur:.1f}" for tr in plano.trechos),
            "qc_ok": "sim" if res_qc["ok"] else "não", "qc_problemas": "; ".join(res_qc["problemas"]),
            "qc_avisos": "; ".join(res_qc["avisos"]), "status": estado, "plataformas": "TikTok; Shorts; Reels",
            "data_agendada": "", "aprovado_por": "", "link_publicado": "", "observacoes": "",
        })
        resultados.append(res_qc)

    _escrever_csv(pasta_lote / "publicacao.csv", linhas, anexar=False)
    _escrever_csv(CONTROLE, linhas, anexar=True)
    REGISTRO.write_text(json.dumps(registro, ensure_ascii=False, indent=1), encoding="utf-8")

    hashes_depois = {g.name: hash_arquivo(g) for g in gravacoes}
    intactos = hashes_antes == hashes_depois
    resumo = {"lote": lote_id, "semente": semente, "pedidos": quantidade, "produzidos": len(linhas),
              "estilos": [l["estilo"] for l in linhas], "originais_intactos": intactos,
              "hash_originais": hashes_antes, "qc_ok": sum(1 for r in resultados if r["ok"])}
    (pasta_lote / "resumo.json").write_text(json.dumps(resumo, ensure_ascii=False, indent=2), encoding="utf-8")
    if not intactos:
        raise ErroPipeline("ATENÇÃO: o hash de alguma gravação original mudou durante o lote!")
    if len(linhas) < quantidade:
        log(f"Aviso: só {len(linhas)} de {quantidade} vídeos. Faltam momentos novos nas gravações "
            "(adicione gravações ou marcações).")
    log(f"Pronto: {pasta_lote}")
    return pasta_lote


def _escrever_csv(destino: Path, linhas: list[dict], anexar: bool) -> None:
    novo = not destino.exists() or not anexar
    with open(destino, "a" if anexar else "w", newline="", encoding="utf-8-sig" if novo else "utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUNAS)
        if novo:
            w.writeheader()
        w.writerows(linhas)


def analisar_tudo(cfg: dict, log=print) -> Path:
    exigir_ferramentas()
    gravacoes = listar_gravacoes()
    if not gravacoes:
        raise ErroPipeline(f"Nenhuma gravação em {ENTRADAS}.")
    destino = SAIDA / "analise"
    for g in gravacoes:
        pasta = destino / g.stem
        if pasta.exists():
            shutil.rmtree(pasta)
        pasta.mkdir(parents=True)
        a = analise.analisar(g)
        moms = analise.encontrar_momentos(g, a)
        for i, m in enumerate(moms):
            analise.folha_de_contato(g, m, pasta / f"momento_{i + 1:02d}_{m['pico']:.0f}s_{m['tipo']}.jpg")
        (pasta / "momentos.json").write_text(analise.resumo_json(moms), encoding="utf-8")
        log(f"{g.name}: {len(moms)} momentos → {pasta}")
    return destino
