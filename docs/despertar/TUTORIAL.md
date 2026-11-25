# Tutorial guiado (Lume) e HUD menor no celular

**Status:** implementado e testado fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio.**

## A Lume, Guardiã do Nexo

A Lume é uma personagem original, no estilo blocado do Roblox:
- capuz lilás e olhos de luz menta;
- um cristal do Nexo flutuando sobre a cabeça;
- um aro de energia nos ombros.

Foi feita no Blender (`assets/tutorial/source/generate_lume.py`), com olhos e boca em peças separadas para animar.

**Como ela aparece**
- Uma caixa de diálogo na parte de baixo da tela, logo acima do DESPERTAR, com a Lume em 3D (ViewportFrame).
- O texto é digitado letra por letra, com um som curto.
- Ela mexe a boca enquanto fala, pisca, respira e vira levemente a cabeça.

**Controles**
- Tocar na caixa acelera o texto ou passa para a próxima fala.
- "Pular tutorial" pede um segundo toque para confirmar.

**Com um painel aberto** (ex.: Evoluir), a caixa encolhe para o canto de baixo e mostra só a dica, para não tapar o painel.

## Os passos (~3 minutos)

| # | Passo | O que a Lume ensina | Objetivo | Destaque | Presente |
|---|---|---|---|---|---|
| 1 | Boas-vindas | Quem ela é, o que é o Nexo | Continuar | — | — |
| 2 | Girar | Despertar a primeira aura | Girar (o servidor confere) | botão DESPERTAR | — |
| 3 | Pontos | Raridade, Pontos de Aura sem parar, Pontuação decide a Arena | Continuar | painel de Pontos | — |
| 4 | Evoluir | Gastar Pontos em evoluções | Comprar uma evolução (o servidor confere) | botão Evoluir | **+40 Pontos de Aura** |
| 5 | Sorte | Sorte deixa as raras mais fáceis, mas as mais raras são quase impossíveis no começo | Continuar | — | — |
| 6 | Drops | Orbes e lascas pelo mapa; mais à noite e Estrelas Cadentes | Pegar um drop (seta amarela em cima do mais perto) | relógio do ciclo | — |
| 7 | Portais | O Corredor dos Perdidos, criaturas, Fragmentos, Pontuação por mundo | Chegar aos Portais (coluna de luz amarela e distância) | — | — |
| 8 | Final | Ecos no Cristal do Nexo, equipamento, Arena do Trono | Concluir | — | **+60 Pontos de Aura e +5 Fragmentos** |

- **Destaque:** o botão do passo ganha um contorno amarelo pulsando e uma seta.
- **Drops e Portais:** se o jogador não cumprir o objetivo, depois de 45 s (drops) ou 40 s (portais) aparece "Continuar", para ninguém ficar preso.

## Segurança e save

- **O que é salvo:** o progresso fica no perfil `Despertar_v1`, no campo `tutorial` (`passo`, `concluido`, `presenteAte`).
- **Quem vê o tutorial:** só quem nunca girou. Perfis antigos que já giraram não veem, e os presentes contam como entregues.
- **Validação:** o servidor só deixa avançar um passo por vez e confere os objetivos que ele consegue ver (giro e evolução).
- **Presentes:** cada presente é entregue uma única vez. Rever o tutorial (**Ajustes → Rever tutorial**) não repete os presentes.
- **Ações:**
  - `TutorialAvancar(passo)`
  - `TutorialPular`
  - `TutorialReiniciar`

## HUD menor no celular

- **Toque (celular e tablet):** o HUD fica com **80%** do tamanho de antes. Em tela pequena sem toque, 90%.
- **O que encolhe:** cartão do jogador, moedas, Pontos, relógio do ciclo, menu lateral e barra do DESPERTAR.
- **O que não muda:** os painéis (Evoluir, Ecos, Equipamento…) continuam do tamanho de leitura.
- **Como funciona:** o quadro do HUD cresce na mesma proporção, então tudo continua preso às bordas da tela. As contas de posição usam o tamanho já reduzido.
- A caixa da Lume também fica um pouco menor no toque (88%).

## Onde está

| Arquivo | Papel |
|---|---|
| `src/shared/Dados/Tutorial.luau` | Passos, falas, objetivos, presentes, avançar, pular e rever (regras puras, testadas) |
| `src/server/Servicos/Tutorial.luau` | Ações do tutorial, conferência e presentes |
| `src/client/UI/Telas/Tutorial.luau` | Caixa da Lume, digitação, animação, destaques, seta do drop e coluna dos Portais |
| `src/shared/Dados/LumeVisual.luau` | Peças da Lume (gerado) |
| `src/client/UI/Telas/HUD.luau` | `HUD.escalaDoHud()` e o HUD menor no toque |
| `src/client/UI/Telas/Ajustes.luau` | "Rever tutorial" |

## Playtest sugerido
1. **Começo:** entrar com perfil novo (no Studio o perfil de teste é novo) e fazer o tutorial inteiro, cronometrando. A meta é perto de 3 minutos.
2. **Celular:** conferir o tamanho do HUD, se a caixa da Lume não cobre o DESPERTAR e se dá para tocar em tudo.
3. **Painel aberto:** no passo de Evoluir, a caixa deve ir para o canto.
4. **Rever:** em Ajustes → Rever tutorial, refazer o tutorial e conferir que os presentes não vêm de novo.
5. **Pular:** "Pular tutorial" com dois toques.
