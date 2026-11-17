# Despertar: vídeos curtos (TikTok, Shorts, Reels)

Pipeline local que transforma gravações de gameplay em vídeos verticais 1080×1920 prontos
para **aprovação** (nada é publicado automaticamente).

## Requisitos

- Python 3.10+ com `numpy`
- FFmpeg com `libass`, `libx264` e `aac` (no Windows, a build "full" do gyan.dev serve)

## Uso

1. Copie as gravações (`.mp4`, `.mov`, `.mkv`, `.webm`) para `entradas/`. Elas nunca são
   alteradas: o lote confere o SHA-256 antes e depois.
2. (Opcional, recomendado) Crie `entradas/<nome_do_video>.json` dizendo o que realmente
   acontece. **Só o que estiver aqui pode virar texto com fatos** (aura, raridade, resultado):

   ```json
   {
     "eventos": [
       {"inicio": 42.0, "fim": 50.5, "tipo": "revelacao", "titulo": "Gear 5", "raridade": "1 em 1.000.000"},
       {"inicio": 95.0, "fim": 104.0, "tipo": "combate", "pov": "você entra no andar 7"}
     ],
     "ignorar": [[0, 12], [300, 320]]
   }
   ```

   `pico` (segundo exato do impacto) e `gancho` (texto do início) também são aceitos.
   `ignorar` exclui trechos com menus, chat ou nomes de usuários.
3. Rode:

   ```bash
   python3 despertar_videos.py analisar        # folhas de contato dos momentos em saida/analise/
   python3 despertar_videos.py produzir -n 5   # lote com 5 vídeos
   python3 despertar_videos.py produzir -n 10 --estilos revelacao,pausa --semente 42
   python3 despertar_videos.py verificar saida/lote_AAAAMMDD_HHMMSS
   ```

## O que sai

```
saida/
  controle_publicacao.csv        # planilha acumulada de todos os lotes (abre no Excel/Sheets)
  registro.json                  # momentos e estilos já usados (evita repetir vídeo)
  lote_.../
    publicacao.csv  resumo.json
    01_revelacao/
      video.mp4                  # H.264 + AAC, 30 fps, -14 LUFS
      capa.jpg  legenda.txt  metadados.json  qc.json  plano.json
      referencia_momento.jpg     # 4 quadros do trecho original, para conferir
```

Na planilha, `status` começa como `aguardando_aprovacao` (ou `corrigir` se o QC falhou).
Preencha `aprovado_por`, `data_agendada` e `link_publicado` ao agendar.

## Como funciona

1. **Análise** (`pipeline/analise.py`): lê o vídeo a 10 quadros/s em baixa resolução e mede
   movimento, clarões, cores vivas, volume e golpes de áudio. Encontra os picos, ajusta o
   pico ao golpe real e calcula onde está a ação na horizontal (foco do recorte vertical).
2. **Estilos** (`pipeline/estilos.py`), em rodízio dentro de cada lote:
   | Estilo | Formato |
   |---|---|
   | `revelacao` | gancho → tensão com zoom lento → soco de zoom, clarão/glitch/tremor, câmera lenta opcional |
   | `pausa` | congela antes do pico, escurece e aproxima, "pera..." → solta no impacto |
   | `montagem` | 4–6 cortes rápidos com whoosh, zoom alternado, contador opcional, o melhor por último |
   | `pov` | um trecho longo, quase sem efeitos, texto "POV:" fixo (estilo mais autêntico) |
   | `top3` | ranking #3 → #1 com selos e sino |
   Cada vídeo sorteia variações (animação dos textos, cor de destaque, força do zoom, clarão
   ou glitch, câmera lenta, chamada final), então dois vídeos do mesmo estilo não saem iguais.
3. **Enquadramento** (`pipeline/render.py`): `preenchido` (quadro inteiro sobre fundo
   desfocado, usado quando a ação está espalhada), `meio` (recorte 3:4) ou `recorte` (9:16
   no foco).
4. **Som** (`pipeline/sfx.py`): efeitos sintetizados no próprio código (whoosh, impacto,
   riser, glitch, sino...), sem áudio de terceiros. Música em alta deve ser adicionada no
   próprio app na hora de publicar.
5. **Textos** (`pipeline/textos.py`): ASS/libass com fonte Inter (OFL, em `fontes/`), sempre
   dentro da zona segura das interfaces dos apps.
6. **QC** (`pipeline/qc.py`): resolução, fps, codecs, duração (8–25 s), decodificação
   completa sem erros, áudio presente, volume (-14 LUFS) e pico, tela preta, imagem parada,
   foco dentro do recorte e textos na zona segura.
7. **Metadados** (`pipeline/metadados.py`): título, legenda, hashtags e classificação
   (faixa etária, violência, fatos confirmados, divulgação própria, público infantil).

## Amostra técnica

Enquanto não houver gameplay gravada, `python3 amostras/gerar_amostra.py` cria uma gravação
**sintética** com as prévias de Incursões. Os vídeos gerados dela levam a tarja
"AMOSTRA TÉCNICA · não publicar" e o status `teste_tecnico_nao_publicar`.

## Testes

```bash
python3 testes_pipeline.py
```

## Dicas para gravar

- 1920×1080 ou maior, 60 fps, áudio do jogo ligado, sem música de fundo.
- Esconda o chat e o nome de usuário se possível. Senão, marque em `ignorar`.
- Grave sessões longas (10 a 30 min) com variedade: giros raros, incursões, arena, índice.
- Anote o minuto dos momentos bons no `.json`: isso libera textos com fatos ("tirei Gear 5").
