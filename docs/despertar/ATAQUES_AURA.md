# Poderes do ataque automático da aura

Antes, todo ataque automático da aura era o mesmo orbe. Agora cada **família de aura** tem um
**poder próprio**, com formato, efeito e mecânica diferentes. Vale no Corredor (criaturas) e no
Titã de Borracha (evento).

## Engenharia reversa

Nos jogos de anime e tower defense do Roblox (Anime Defenders, Anime Last Stand, All Star TD,
Universal TD), cada unidade ataca de um jeito: projétil, linha, cone, círculo, corrente que pula
entre inimigos ou golpe do céu. Muitas também aplicam efeitos: queimar, congelar ou deixar lento,
crítico, vários golpes, golpe forte a cada N.

## Os 14 poderes

| Poder | Famílias | Como ataca | Mecânica |
|---|---|---|---|
| Estilhaço de Cristal | Cristal, Mineral, Reflexo | lança de cristal que explode em estilhaços | 100% + 30% em área |
| Prisão de Vinhas | Natureza, Floral | vinhas brotam do chão sob o alvo | 105% + alvo ataca 40% mais devagar por 2,5 s |
| Jato da Maré | Oceano | jato de água em linha, com espuma | 95% + 60% em quem estiver atrás |
| Bola de Brasa | Forja, Fênix | bola de fogo em arco e explosão | 85% + 45% de queimadura em 3 s |
| Raio em Cadeia | Tempestade, Mecânico, Metal | relâmpago que pula | 95% + 65% + 40% em mais 2 alvos |
| Lança de Geada | Geada | lança de gelo; o alvo fica preso no gelo | 100% + alvo ataca 80% mais devagar por 3 s |
| Revoada de Espíritos | Espírito, Bruma | 3 espíritos teleguiados | 3 × 40% |
| Eco Sônico | Som | ondas de som em cone | 100% + 45% em área |
| Chuva de Estrelas | Cósmico | estrelas caem do céu | 90%; a cada 3 golpes, um meteoro de 260% |
| Implosão do Vazio | Abismo, Fenda | esfera negra que suga e explode | 85% + 55% em área grande |
| Lâminas Rúnicas | Relíquia, Artefato, Arcano, Temporal | 2 lâminas de runa girando | 2 × 50%, 20% de crítico ×2 |
| Garras da Fera | Fera, Deserto | 3 cortes em X | 3 × 33%, 25% de crítico ×2 |
| Lâmina do Soberano | Soberano | espada de luz gigante desce do céu | 120% + 40% em área, rachaduras no chão |
| Punho de Borracha Gigante | Gear 5 (evento) | o braço estica e o punho cresce | 130% + 50% em área |

**Raridade:** o ataque fica maior quanto mais rara a aura, e o raio de área e de corrente cresce
um pouco.

**Balanço:** no alvo único, todos ficam entre 85% e 140% do dano base (os de área batem menos no
alvo principal). Os testes conferem isso. A Pontuação continua sendo o que mais pesa.

## Como funciona

- **Servidor** (`server/Corredor/Criaturas.luau`, `server/Servicos/EventoSol.luau`): pega a aura
  equipada e o poder (`Dados/AtaquesAura.poderDe`), e resolve os acertos com
  `AtaquesAura.resolver`. Isso inclui área, corrente, linha, golpes seguidos, crítico,
  queimadura (com atraso) e lentidão (a criatura ataca mais devagar). O RNG é o `Random` do
  servidor.
- **Cliente** (`client/Mundo/AtaquesAura.luau`): desenha a animação do poder com as cores da
  aura, e o número de cada acerto ("CRÍTICO" em dourado, queimadura em laranja). Quando há muitos
  efeitos na tela, os ataques dos outros viram o orbe simples. Movimento reduzido tira o tremor.
- No Titã (alvo único), os acertos do poder são somados num golpe só.

Só Parts, partículas e texturas do próprio Roblox. Prévia: `assets/auras/previews/ataques.png`
(mock em HTML, **não é print do Roblox**).

**Não testado no Roblox Studio ainda.**
