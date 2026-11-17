# Combate das Incursões — fase 1

**Status:** implementado e testado só fora do Studio (testes de lógica, análise de tipos, `rojo build`).
Precisa de playtest no Studio para validar sensação, dano e recargas.

## Referências pesquisadas
- **Hades RNG:** aura RNG com bloqueio, dash e combo de 4 M1; aura mais rara, mais habilidades.
- **Sol's RNG (Raid):** aura de combate escolhida para o chefe; aluguel para quem não tem.
- **Aura Battles:** auras mudam o jeito de lutar.
- **Anime Dungeons / Dungeon Quest:** M1, esquiva e 2 habilidades em dungeon cooperativa.
- **Jujutsu Shenanigans / Strongest Battlegrounds:** combo M1, dash, bloqueio frontal, técnicas 1–4 e despertar.
- **Gear 5 em One Fruit / Haze Piece:** punho gigante, trovão, palmas, tornado; forma focada em área.

## Controles (só dentro da Incursão)
| PC | Controle | Ação |
|---|---|---|
| M1 | R2 | Golpe (combo de 3; o 3º empurra e atordoa) |
| Q | — | Pulso (já existia) |
| 1 | X | Técnica 1 |
| 2 | Y | Técnica 2 |
| R | R1 | Despertar (medidor 0–100) |
| Shift | L1 | Esquiva (invulnerável por um instante) |
| F (segurar) | L2 | Guarda frontal (quebra se segurar mais de 3 s) |

No celular, a barra de habilidades tem um botão para cada ação. O **E** (giro) fica desligado durante a partida.

## Kits
- **Genérico (todas as auras):**
  - Golpe de Aura: cortes curvos.
  - Esfera de Aura: projétil reto que atravessa.
  - Onda Ressonante: cone que empurra e atordoa.
  - Despertar: coluna de luz e explosão em área, depois +30% de dano por 8 s.
  - Tudo pintado com a cor da aura equipada.
- **Gear 5:**
  - Soco Elástico: braço estica até 13 studs.
  - Pistola de Borracha: recua o braço e solta até 42 studs.
  - Gatling Elástica: 8 acertos em cone, dezenas de punhos no efeito.
  - Punho do Trovão Gigante: puxa todos, ergue o punho com raios e desce com nuvens; +35% por 9 s.
  - Esquiva maior, que quica.
  - Guarda de borracha: reduz 80% e devolve metade do golpe.

## Regras (servidor)
- O cliente só pede a técnica e a direção.
- O servidor confere recarga, posição e medidor, calcula a área (cone, linha ou círculo) e aplica o dano.
- **Fórmula:** `dano = base × Ressonância (máx. 1,6) × combo × Despertar × crítico (5%, ×1,5)`.
- O medidor enche com dano causado, golpes aparados e esquivas.
- **Sem PvP.**
- Todo dano de inimigo passa por `Inimigos.defesa`, onde entram a guarda e a esquiva.
- Números em `src/shared/Dados/Combate.luau`; geometria testada em `testes/logica.luau`.

## Próximas fases
2. Balanceamento após playtest.
3. Kits próprios para Naruto, Monarca e Senbonzakura.
4. Kits por família das 67 originais.
