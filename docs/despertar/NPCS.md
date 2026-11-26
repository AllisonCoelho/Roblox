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

## Detalhamento (segunda engenharia reversa)

Depois da estrutura, o que os jogos grandes fazem para o NPC não parecer "boneco liso":

| Técnica dos jogos | Como fica aqui |
|---|---|
| Roupa pintada (templates de Shirt/Pants): sombra suave nas quinas, luz de cima, sombra embaixo da gola, dobras em cotovelo e joelho, costuras | `caixa_pintada` no Blender: cada membro é uma caixa subdividida com cor por vértice (`boneco_<id>_<membro>`), nas medidas exatas do boneco |
| Detalhes de roupa em relevo | emblema de sol, tornozeleira e sandália (Titã); gola em V, botões, cinto com fivela, punho da manga e botas (Lume) |
| Rosto expressivo | olho em camadas (contorno, íris, pupila) com **dois brilhos**, sobrancelha arqueada, cílios, bochechas e boca desenhada |
| Cabelo em camadas com reflexo | degradê (pontas escuras, topo claro), faixa de reflexo de anime (Lume), nuvem com sombra azulada (Titã) |
| Chefe com efeitos temáticos e placa | Titã: vapor de nuvem saindo dos ombros, faíscas douradas, luz quente, contorno e placa "TITÃ DE BORRACHA · Chefe do Evento" |

Se alguma malha falhar, o membro volta a ser um bloco liso da mesma cor (o NPC nunca some).

## Arquivos

| Arquivo | O quê |
|---|---|
| `src/shared/Dados/Bonecos.luau` | proporções, aparência de cada NPC e poses (testado) |
| `src/client/Mundo/Boneco.luau` | monta e posiciona as peças (mundo e ViewportFrame) |
| `assets/npcs/source/generate_bonecos.py` | cabeças, cabelos e roupas pintadas no Blender + prévias |

## Criar um NPC novo

1. Adicione a definição em `Bonecos.NPCS` (cores de pele/camisa/calça, rosto, acessórios, escala).
2. Gere a cabeça `boneco_cabeca_<id>`, o cabelo e a roupa pintada (`boneco_<id>_tronco`, `_bracoD`,
   `_bracoE`, `_pernaD`, `_pernaE`) em `generate_bonecos.py`. O `testes/rodar.py` confere se existem.
3. No cliente: `local b = Boneco.criar(id, pasta)` e, a cada quadro,
   `b:posicionar(pes, Bonecos.pose("parado", t), { piscando = ..., falando = ... })`.

## Próximos a converter

Primeiro Soberano (armadura) e as criaturas do Corredor ainda usam os modelos antigos.
