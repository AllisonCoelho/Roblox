"""Título, legenda, hashtags e classificação de conteúdo para cada vídeo.

Os fatos (aura, raridade) só aparecem quando vêm das marcações do dono. Sem marcação,
os textos descrevem o formato do vídeo, nunca um resultado que não foi confirmado.
"""
from __future__ import annotations

import re

from .estilos import Plano

TITULOS = {
    "revelacao": ["Esse final me pegou", "Espera o final", "Não pisca nesse vídeo", "Olha o que aconteceu no Despertar"],
    "pausa": ["Pera... olha isso", "Repara no detalhe", "Calma que vem coisa"],
    "montagem": ["{n} momentos do Despertar", "Compilado do Despertar", "Só os momentos bons"],
    "pov": ["POV no Despertar", "Um dia normal no Despertar", "Mais uma no Despertar"],
    "top3": ["Top 3 momentos do Despertar", "Ranking dos momentos de hoje", "Qual foi o melhor?"],
}
LEGENDAS = {
    "revelacao": ["assiste até o final 👀", "o final desse aqui 😳", "não esperava esse final"],
    "pausa": ["repara no que acontece depois da pausa 👀", "pausei pra vocês verem isso", "calma… olha o depois"],
    "montagem": ["{n} momentos seguidos no Despertar ⚡", "um pouco do que rola no Despertar", "qual desses foi o melhor?"],
    "pov": ["{gancho}", "só mais uma vez… né? 😅", "quem joga sabe"],
    "top3": ["qual foi o melhor dos 3? comenta 👇", "concorda com o ranking?", "o #1 é imbatível ou não?"],
}
PERGUNTAS = ["vocês já viram isso?", "comenta o que você achou 👇", "manda pra quem joga Roblox", "", ""]
HASHTAGS_ESTILO = {
    "revelacao": ["#aurarng", "#rng", "#sorte"],
    "pausa": ["#aurarng", "#rng", "#espera"],
    "montagem": ["#gameplay", "#robloxedit", "#compilado"],
    "pov": ["#pov", "#robloxpov", "#gameplay"],
    "top3": ["#top3", "#ranking", "#gameplay"],
}
HASHTAGS_GERAIS = ["#robloxbrasil", "#jogosroblox", "#robloxfyp", "#anime", "#aura", "#fyp", "#viral", "#shorts"]


def _sem_marcacao(t: str) -> str:
    return re.sub(r"\\N", " ", t.replace("*", "")).strip()


def gerar(plano: Plano, cfg: dict, rng) -> dict:
    n = len(plano.momentos)
    eventos = [m["evento"] for m in plano.momentos if m.get("evento")]
    ev = eventos[0] if eventos else None
    fatos = bool(ev and ev.get("titulo"))
    gancho = _sem_marcacao(plano.gancho)

    if fatos:
        titulo = f"{ev['titulo']}" + (f" ({ev['raridade']})" if ev.get("raridade") else "") + " no Despertar"
        legenda = f"{gancho} ✨"
    else:
        titulo = str(rng.choice(TITULOS[plano.estilo])).format(n=n)
        legenda = str(rng.choice(LEGENDAS[plano.estilo])).format(n=n, gancho=gancho)
    pergunta = str(rng.choice(PERGUNTAS))
    chamada = cfg["jogo"]["chamada_legenda"]
    legenda_final = " ".join(x for x in (legenda, pergunta) if x) + f"\n\n{chamada}"

    tags = list(cfg["jogo"]["hashtags_fixas"]) + HASHTAGS_ESTILO[plano.estilo]
    extras = [h for h in HASHTAGS_GERAIS if h not in tags]
    rng.shuffle(extras)
    tags += extras[: int(rng.integers(2, 4))]
    if fatos:
        fixas = len(cfg["jogo"]["hashtags_fixas"])
        tags.insert(fixas, "#" + re.sub(r"[^0-9A-Za-zÀ-ÿ]", "", ev["titulo"]).lower())
    tags = list(dict.fromkeys(tags))[:8]

    tipos = {m["tipo"] for m in plano.momentos}
    combate = any(t in ("acao", "combate", "incursao", "arena") for t in tipos) or any(
        e.get("tipo") in ("combate", "incursao", "arena") for e in eventos)
    classificacao = {
        "faixa_etaria": "Livre",
        "categoria": {"revelacao": "revelação", "pausa": "suspense", "montagem": "compilado",
                      "pov": "pov / cotidiano", "top3": "ranking"}[plano.estilo],
        "violencia": "fantasiosa leve (combate estilizado, sem sangue)" if combate else "nenhuma",
        "linguagem": "nenhuma",
        "fatos_confirmados": "sim (marcação do dono)" if fatos else "não: textos só de reação, sem citar resultado",
        "divulgacao_propria": "sim: ativar a opção de conteúdo de marca/promoção própria ao publicar",
        "publico_infantil": "decidir no YouTube ('feito para crianças')",
        "revisar_antes": "nomes de usuário, chat e informações pessoais visíveis na tela",
    }
    return {
        "titulo": titulo[:90],
        "legenda": legenda_final,
        "hashtags": tags,
        "gancho_no_video": gancho,
        "classificacao": classificacao,
    }
