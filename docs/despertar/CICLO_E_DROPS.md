# Ciclo de dia e noite e drops pelo mapa

**Status:** implementado e testado fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio.**

## Ciclo de dia e noite

Uma volta dura **20 minutos**:

| Fase | Duração | Hora no céu | Visual | Efeito no jogo |
|---|---|---|---|---|
| Aurora | 2 min | 5 h → 7 h | Céu rosado e dourado, as estrelas somem | — |
| Dia | 8 min | 7 h → 17 h | Claro, levemente lilás (a identidade do Nexo continua) | Drops a cada 5 s |
| Crepúsculo | 2 min | 17 h → 19 h | Laranja e magenta | — |
| Noite | 8 min | 19 h → 5 h | O céu violeta estrelado de sempre | **Drops 2× mais rápidos (a cada 2,5 s)** e **Estrelas Cadentes** |

**Sincronização**
- O ciclo segue o relógio do servidor (horário Unix). Todos os servidores e jogadores estão na mesma fase, sem nada replicado.
- Cada cliente ajusta a própria iluminação a cada 0,1 s, com transição suave: hora do céu, brilho, ambiente, névoa (Atmosphere), estrelas, sol e lua, e a cor do `NexoCor`.
- Efeitos temporários de outros sistemas, como ritual e câmera, continuam por cima.

**HUD:** abaixo do painel de Pontos aparece a fase e quanto falta para a próxima (ex.: "☾ Noite · 5:12"). À noite aparece "drops ×2 · estrelas", e durante a Bênção Estelar, o tempo dela.

**Painel Dev:** na página de testes, há botões que pulam para o começo de cada fase. Eles valem para o servidor todo.

## Drops pelo mapa

**Onde aparecem**
- Em chão aberto do Nexo: chão, caminhos e jardim, entre 30 e 222 studs do centro.
- Nunca em cima de construções nem dentro delas. O servidor confere com um raio para baixo antes de criar.

**Quantos**
- Até 8 + 3 por jogador ao mesmo tempo, no máximo 40.
- Cada drop some depois de 2 minutos e pisca nos últimos 10 segundos.

**Os três tipos**

| Drop | Chance de dia | Chance à noite | Prêmio |
|---|---|---|---|
| Orbe de Aura | 72% | 52% | 15 segundos do seu ganho de Pontos de Aura (mínimo 5) |
| Lasca de Fragmento | 28% | 30% | 1 Fragmento + 1 por fase do Corredor já concluída (até 7), com o bônus de Fragmentos dos Ecos e do equipamento |
| Estrela Cadente | — | 18% | 60 segundos de ganho + **Bênção Estelar** (+25% de Pontos de Aura por 2 min) |

A Estrela Cadente tem um feixe de luz alto para ser vista de longe.

**Coleta**
- Quem passar primeiro a até 6 studs leva o drop. A coleta é conferida só no servidor, sem remote, então não dá para pegar de longe.
- O drop voa até quem pegou. Para quem pegou, aparece o texto do prêmio e toca um som.

## Onde está

| Arquivo | Papel |
|---|---|
| `src/shared/Dados/Ciclo.luau` | Fases, relógio e cores de cada hora (regras puras, testadas) |
| `src/shared/Dados/DropsMapa.luau` | Tipos, chances, prêmios, intervalo e limite de drops (regras puras, testadas) |
| `src/server/Servicos/DropsMapa.luau` | Cria os drops em lugares válidos, confere a coleta, entrega o prêmio e a Bênção, e trata o ciclo do Painel Dev |
| `src/client/Mundo/Ciclo.luau` | Iluminação de cada fase no cliente |
| `src/client/Mundo/DropsMapa.luau` | Visual dos drops (flutuar, girar, piscar, voar até quem pegou, texto do prêmio) |
| `assets/drops/source/generate_drops.py` | Os três drops no Blender (`--render` refaz a prévia) |
| `src/shared/Dados/DropsVisual.luau` | Malhas dos drops (gerado) |

## Playtest sugerido
1. **Ciclo:** pelo Painel Dev, pule para cada fase e confira se o céu fica legível. A noite precisa continuar igual à de antes.
2. **Drops de dia:** andar pelo mapa e pegar orbes e lascas. Os Pontos de Aura e os Fragmentos sobem no HUD.
3. **Noite:** os drops aparecem mais rápido e surgem Estrelas Cadentes com o feixe de luz. Ao pegar uma, o HUD mostra "★ +25%" e o ganho por segundo sobe.
4. **Multijogador:** com dois jogadores, só um pega cada drop, e o outro vê o drop voar até quem pegou.
5. **Desempenho no celular:** com 40 drops no mapa, conferir o FPS. Cada drop tem uma PointLight pequena.
