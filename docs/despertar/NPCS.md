# NPCs no estilo boneco do Roblox

## Por quê

Os primeiros NPCs (Lume, Titã) eram modelos do Blender com proporções próprias e destoavam dos
jogadores. Nos jogos mais jogados do Roblox (Blox Fruits, simuladores, jogos de RNG) os NPCs
usam **o mesmo corpo de boneco dos jogadores**, e é isso que faz eles "parecerem do Roblox".

## Engenharia reversa (o padrão desses jogos)

| O que eles fazem | Como fica aqui |
|---|---|
| Corpo do boneco clássico (R6): tronco 2×2×1, braços e pernas 1×2×1 | `Bonecos.MEMBROS`, Parts comuns `SmoothPlastic` |
| Cabeça arredondada, rosto simples e expressivo | malha `boneco_cabeca_<id>` (cubo arredondado 1.2) + olhos, boca e bochechas de discos/blocos |
| Personalidade vem do cabelo e de 1–2 acessórios marcantes | cabelo do Blender (`boneco_cabelo_*`) + acessórios de Parts (faixa, gola, capa, auréola, estrela) |
| Chefe = o mesmo boneco em escala gigante | Titã de Borracha com `escala = 5` (26 studs) |
| Animação simples: respirar, olhar, acenar, golpe telegrafado | poses procedurais em `Bonecos.pose` (parado, falar, acenar, erguer, bater, comemorar), piscar e falar |
| Nome/título flutuando, marcador de quest | (já existe nos NPCs com BillboardGui) |

Nenhum asset de terceiros, nenhuma animação enviada: tudo são Parts e malhas próprias.

## Arquivos

| Arquivo | O quê |
|---|---|
| `src/shared/Dados/Bonecos.luau` | proporções, aparência de cada NPC e poses (testado) |
| `src/client/Mundo/Boneco.luau` | monta e posiciona as peças (mundo e ViewportFrame) |
| `assets/npcs/source/generate_bonecos.py` | cabeças e cabelos no Blender + prévias |

## Criar um NPC novo

1. Adicione a definição em `Bonecos.NPCS` (cores de pele/camisa/calça, rosto, acessórios, escala).
2. Gere a cabeça `boneco_cabeca_<id>` (e o cabelo, se for novo) em `generate_bonecos.py`.
3. No cliente: `local b = Boneco.criar(id, pasta)` e, a cada quadro,
   `b:posicionar(pes, Bonecos.pose("parado", t), { piscando = ..., falando = ... })`.

## Próximos a converter

Primeiro Soberano (armadura) e as criaturas do Corredor ainda usam os modelos antigos.
