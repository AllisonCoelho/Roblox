# Equipamento (RPG)

**Status:** implementado e testado fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio.**

## Como funciona

**Espaços e atributos.** São cinco espaços, e cada um tem o seu atributo principal:

| Espaço | Atributo principal (conjunto do mundo 1) |
|---|---|
| Elmo | +4% Sorte |
| Armadura | +15% Vida e +4% Pontos de Aura |
| Manoplas | +8% Dano |
| Botas | +10% Pontos de Aura |
| Arma | +14% Dano |

**Mundos.** Os conjuntos dos mundos seguintes multiplicam esses valores: ×2, ×3,5, ×6, ×10 e ×16.

**O que cada atributo faz**
- **Pontos de Aura:** mais ganho por segundo.
- **Sorte:** mais sorte no giro, dentro do teto de 20x.
- **Dano:** golpes da aura mais fortes nas criaturas do Corredor.
- **Vida:** aumenta a vida máxima do personagem.
- **Fragmentos:** mais Fragmentos no Corredor (soma com o bônus dos Ecos).

**Conjuntos.** Há seis conjuntos, um por mundo do Corredor. Equipar 3 e 5 peças do mesmo conjunto dá bônus extra:

| Conjunto | Peças | 3 peças | 5 peças |
|---|---|---|---|
| Limiar (Comum) | Elmo do Limiar, Couraça Lascada, Manoplas de Cristal, Botas de Pedra Viva, Espada de Cristal | +5% Sorte | +12% Sorte, +10% Pontos |
| Bosque (Incomum) | Coroa de Folhas de Vidro, Casca do Ancião, Luvas de Galho, Botas de Raiz, Cajado do Bosque | +15% Pontos | +40% Pontos, +10% Fragmentos |
| Dunas (Raro) | Elmo Chifrudo de Obsidiana, Peitoral de Brasa, Punhos de Magma, Botas de Cinza, Machado de Brasa | +20% Dano | +50% Dano, +25% Vida |
| Maré (Épico) | Elmo de Concha, Couraça de Coral, Manoplas da Maré, Botas Abissais, Tridente da Maré | +40% Vida | +80% Vida, +20% Sorte |
| Catedral (Lendário) | Elmo Alado, Armadura do Arcanjo, Manoplas de Ouro, Botas de Mármore, Martelo de Luz | +25% Fragmentos | +50% Fragmentos, +80% Pontos |
| Vazio (Mítico) | Coroa Estelar, Manto do Devorador, Garras do Vazio, Passos do Vazio, Foice Estelar | +60% Pontos, +15% Sorte | +150% Pontos, +35% Sorte, +60% Dano |

**Como conseguir.** As peças caem das criaturas do mundo de cada conjunto. Cada jogador que ajudou a derrubar a criatura tem a própria chance:
- **chefe:** 35% de chance de uma peça;
- **lacaio:** 3%.

**Aprimorar.** Cada nível custa Fragmentos e vai até +10. Cada nível dá +12% nos atributos da peça. O custo cresce com o nível e com o mundo.

**Desmontar.** Devolve Fragmentos, com dois toques e a peça desequipada.

**Ocultar.** O olho (◉ Visível / ◌ Oculto) esconde o visual daquele espaço; os bônus continuam.

**Mochila.** Guarda até 80 peças.

## No personagem

- As peças foram modeladas no tamanho de um R15 blocado. O jogo escala cada uma pela largura da parte do corpo de cada jogador, então funciona em R15 de qualquer escala e em R6.
- As peças acompanham o membro animado a cada quadro, presas ao corpo.
- Todos os jogadores veem a armadura de todo mundo (atributo `Equipamento` do Player), até 200 studs.
- O elmo é aberto na frente, então o rosto do avatar continua aparecendo.

## Onde está

| Arquivo | Papel |
|---|---|
| `assets/equipamento/source/generate_equipamento.py` | As 30 peças no Blender (84 malhas, ~15 mil triângulos). `--render` refaz as prévias |
| `src/shared/Dados/EquipamentoVisual.luau` | Malhas de cada peça (gerado) |
| `src/shared/Dados/Equipamento.luau` | Itens, atributos, conjuntos, aprimorar, desmontar e drops (regras puras, testadas) |
| `src/server/Servicos/Equipamento.luau` | Ações `EquiparItem`, `OcultarEquipamento`, `AprimorarItem` e `DesmontarItem`. Bônus em ganho e sorte, vida no Humanoid e `darDrop` |
| `src/server/Corredor/Criaturas.luau` | Dano × bônus de Dano, Fragmentos × bônus, sorteio da peça ao derrubar |
| `src/client/Mundo/Equipamento.luau` | Peças visíveis no corpo de todo mundo |
| `src/client/UI/Telas/Equipamento.luau` | Painel: Personagem (5 espaços, olho, bônus, conjuntos) e uma aba por espaço |

No menu lateral, **Equipar** entrou no lugar do Índice; o Índice continua no espaço 3 da barra de baixo.

## Playtest sugerido
1. **Peças:** derrotar o chefe da fase 1 algumas vezes até cair uma peça. Pelo Painel Dev, dá para dar Fragmentos para aprimorar.
2. **Visual:** equipar e ver a peça no personagem. Ocultar e mostrar pelo olho.
3. **Bônus:** com Manoplas e Arma, o número de dano nas criaturas sobe. Com Armadura, a vida máxima sobe.
4. **Ajuste no corpo:** conferir com avatar R6, com R15 alto e magro (escala) e em primeira pessoa (as peças somem com o corpo).
5. **Multijogador:** com dois clientes, um vê a armadura do outro.

Fontes da pesquisa:
- [Deepwoken: bônus de conjunto](https://deepwoken.fandom.com/wiki/Equipment)
- [The Forge: ocultar armadura](https://www.thespike.gg/roblox/the-forge/how-to-hide-armor-guide)
- [Sunhaven: conjuntos](https://sunhaven.wiki.gg/wiki/Armor)
- [Clover RPG: espaços](https://www.ofzenandcomputing.com/clover-rpg-all-equipment-guide-gear-armor-and-stats/)
