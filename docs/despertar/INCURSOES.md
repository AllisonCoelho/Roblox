# Incursões

Expedições cooperativas (1 a 4 jogadores) a universos destruídos, saindo do **Bastião das Incursões**.

## Como joga

1. No Bastião, a **Mesa dos Cartógrafos** abre o painel: três universos, fragmentos, ressonância e relíquias.
2. **Entrar na fila** de um universo. Contagem de 12 s a partir do primeiro (ou sai na hora com 4).
   Quem se afastar do Bastião sai da fila.
3. O grupo vai para um espaço só dele, longe do Nexo. Cada universo tem **5 andares**:
   - **Andares 1–4:** purificar os **Núcleos Corrompidos** (ficar perto). Mais gente purifica mais rápido.
     Uma **Sombra** perto do Núcleo trava a purificação e faz o progresso voltar um pouco.
     As Sombras perseguem e atacam; reforços chegam enquanto houver Núcleo.
     Com todos purificados, as Sombras se desfazem e abre a **fenda**: o primeiro que entra
     leva o grupo para baixo em 4 s.
   - **Andar 5:** o **Guardião**. Golpe em área com aviso no chão (círculo que enche) e reforços aos
     66% e 33% da vida.
4. **PULSO** (tecla **Q** ou botão): onda em volta do jogador que fere as Sombras. Espera de 1,1 s.
5. **Vidas do grupo:** 3 + número de jogadores. Quem cai volta ao andar enquanto houver vida; sem vidas,
   volta ao Nexo com o que já ganhou. **SAIR** a qualquer momento (também leva o que ganhou).
6. **Recompensas:** fragmentos por andar concluído, bônus de vitória (maior na primeira).
   Vencer um universo abre o próximo (Cinzas → Maré Morta → Crepúsculo Umbral).

## Universos

| Universo | Nível | Guardião | Clima |
|---|---|---|---|
| Cinzas | 1 | Arauto das Brasas | ruínas avermelhadas, brasas |
| Maré Morta | 2 | Cavaleiro Afogado | azul frio, corais, ondas paradas |
| Crepúsculo Umbral | 3 | Espectro do Ocaso | roxo escuro, lascas, sombras |

O nível multiplica vida e dano das Sombras e a recompensa. Andares mais fundos ficam mais fortes; grupos
maiores enfrentam mais Sombras e um Guardião com mais vida.

## Relíquias (só valem nas Incursões)

| Relíquia | Efeito por nível | Níveis |
|---|---|---|
| Eco do Pulso | +12% de dano | 5 |
| Coração de Brasa | +15% de vida | 5 |
| Mãos de Selo | +12% de purificação | 5 |
| Olho do Vazio | +8% de alcance do Pulso | 3 |

## Ressonância (ligação com as auras)

A aura **mais rara** do jogador vira força nas Incursões: `1 + 0,06 × log10(chance)`
(1 em 1 milhão ≈ 1,36×). Multiplica dano do Pulso e purificação. **Nada aqui muda as chances do giro.**

## Onde está o código

| Arquivo | O quê |
|---|---|
| `src/shared/Dados/Incursoes.luau` | regras puras e números (testadas em `testes/logica.luau`) |
| `src/shared/Dados/IncursoesKit.luau` | medidas das peças 3D (gerado) |
| `src/server/Incursoes/Servico.luau` | fila, partidas, purificação, vidas, ações e recompensas |
| `src/server/Incursoes/Mapa.luau` | monta cada andar (sorteado no servidor) |
| `src/server/Incursoes/Inimigos.luau` | Sombras e Guardião (movimento, ataque, golpe, reforços) |
| `src/client/UI/Telas/Incursoes.luau` | painel, HUD, Pulso e resultado |
| `src/client/Mundo/Incursoes/Visual.luau` | malhas, efeitos, clima e modelos importados |
| `src/client/Mundo/Incursoes/Ossos.luau` | anima por código os inimigos importados |
| `assets/incursoes/source/generate_incursoes.py` | kits dos três universos (entram pelo código) |
| `assets/incursoes/inimigos/` | inimigos detalhados para importar no Studio (ver `IMPORTAR_NO_STUDIO.md`) |

**Save:** campo novo `incursoes` no perfil (`Despertar_v1`): `fragmentos`, `melhor`, `concluidas`,
`reliquias`. Perfis antigos recebem o padrão ao carregar. Ações novas (todas validadas no servidor, com o
limite de 8/s das ações): `IncursaoFila`, `IncursaoSair`, `IncursaoPulso`, `IncursaoReliquia`.
Remote novo: `Incursao` (servidor → jogador).

## Não testado

Nada disto foi jogado no Studio ainda: falta playtest de fila com 2+ jogadores, combate, morte e
revivência, Guardião, desconexão no meio da partida, salvamento das recompensas e FPS no celular.
