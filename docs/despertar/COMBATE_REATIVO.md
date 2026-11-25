# Combate reativo da Arena

**Status:** implementado e testado fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio**, principalmente para ajustar as janelas de tempo com o ping real.

Vale nos três modos da Arena: contra o Primeiro Soberano, pelo Trono do Servidor e na Rankeada.

## A base: engenharia reversa de Clair Obscur: Expedition 33

Pesquisei os sistemas de turno mais elogiados e os que juntam turno com reação em tempo real:
- **Clair Obscur: Expedition 33:** turno com defesa reativa (esquivar e aparar), contra-ataque, Pontos de Ação, botão no tempo certo nas habilidades e barra de quebra.
- **Paper Mario:** comandos de ação; aperta no tempo certo para bater mais forte ou se defender.
- **Octopath Traveler:** escudos, Break e Boost.

O Expedition 33 junta o melhor dos outros dois e é o referencial atual do gênero, então foi a base. Só as **mecânicas** foram reproduzidas; nomes, personagens, arte e números são nossos.

| Expedition 33 | No Despertar | Mudança |
|---|---|---|
| Ataque básico dá PA; habilidades gastam PA | Ataque dá +1 PA; Corte e Selo custam 2 PA, Despertar 5 PA (máx. 9) | — |
| Botão no tempo certo durante as habilidades | Anel dourado fecha no círculo: **Perfeito** ×1,35 (+Ruptura), **Bom** ×1, **Errou** ×0,7 | Um anel por marca do golpe |
| Esquiva (janela maior) e Aparar (janela curta, +1 PA) | Iguais: Esquivar ±0,2 s; Aparar ±0,12 s e +1 PA | — |
| Aparar todos os golpes do combo solta o contra-ataque | Igual: o contra-ataque sai sozinho, com 120 de dano | — |
| Golpes que não dá para aparar | **Golpe absoluto** (anel vermelho com "!"): a Sentença do Soberano e o Despertar só se esquivam | — |
| Inimigos fingem o golpe para enganar o tempo | **Lâmina Hesitante**: o Soberano finge o golpe pesado, para no meio e ataca duas vezes depois | — |
| Barra de quebra: cheia, o inimigo fica atordoado | **Ruptura**: cheia, o alvo fica **Rompido**, perde a próxima vez e recebe +50% de dano | — |
| Grupo de 3 heróis, ordem por velocidade | 1 contra 1, vez a vez | Mudança |
| — | **Concentrar**: +2 PA e janelas de defesa ×1,5 até a sua próxima vez | Mudança: substitui a troca de herói |
| — | No 1x1, o dano segue a Pontuação de Aura (o mais forte vence; entre parecidos, cada turno importa) | Mudança: o pilar do nosso jogo |

Fontes da pesquisa:
- [Clair Obscur: Expedition 33: o combate presta homenagem aos JRPGs (Epic Games Store)](https://store.epicgames.com/news/clair-obscur-expedition-33-turn-based-combat-pays-homage-jrpgs)
- [Guia de combate (Maxroll)](https://maxroll.gg/clair-obscur-expedition-33/guides/combat-guide)
- [Prévia do combate (Xbox Wire)](https://news.xbox.com/en-us/2024/08/28/clair-obscur-expedition-33-combat-breakdown-preview/)
- [Esquivas, aparadas, saltos e Gradient Counters (Automaton)](https://automaton-media.com/en/tips/clair-obscur-expedition-33-how-to-get-the-hang-of-dodges-parries-jumps-and-gradient-counters/)
- [Guia de combate (Game8)](https://game8.co/games/Clair-Obscur-Expedition-33/archives/515700)
- [Comando de ação (Super Mario Wiki)](https://www.mariowiki.com/Action_Command)
- [Break e Boost (Destructoid)](https://www.destructoid.com/break-and-boost-system-guide-octopath-traveler-2/)

## Ações do jogador
| Ação | PA | Golpes | Dano base |
|---|---|---|---|
| Ataque | +1 | 1 (corre até o alvo) | 85 |
| Corte de Ressonância | 2 | 2 (salto com giro e revés) | 75 + 75 |
| Selo de Ruptura | 2 | 1 | 50 · enche muito a Ruptura e corta pela metade o próximo golpe recebido |
| Despertar | 5 | 3 descargas (absoluto) | 100 + 100 + 140 |
| Concentrar | +2 | — | defesa mais fácil até a sua vez |

## Golpes do Primeiro Soberano
Ele segue um ciclo e, na sua vez, a tela mostra o que ele prepara:
- Investida: 1 golpe, 110.
- Fúria Tripla: 3 golpes, 60, 60 e 75.
- Baluarte: reduz o dano do seu próximo golpe em 45%.
- Lâmina Hesitante: finta, depois 2 golpes de 90.
- Sentença: absoluta, 240.

## Como o servidor confere o tempo
1. **Anúncio:** cada golpe é anunciado 0,55 s antes, com o instante de cada acerto no relógio do servidor. Assim, o anel fecha igual para todos.
2. **Toque:** o toque vai pelo evento `DueloEntrada`, com o horário em que aconteceu. O servidor compara esse horário com a hora de chegada menos o ping e, se a diferença passar de 0,3 s, usa a própria estimativa.
3. **Contagem:** vale só o primeiro toque de cada acerto, e no máximo 20 entradas por segundo.
4. **Resultado:** o servidor espera a janela fechar (+0,12 s) e então decide o acerto e avisa todos.

## Animações novas
São animações por código, como as de antes.
- **Jogador:**
  - Corte com dois golpes;
  - Despertar com três descargas;
  - Esquiva (passo para o lado);
  - Aparar (antebraços batem no golpe);
  - Contra-ataque (gancho);
  - Concentrar;
  - Rompido (curvado e tonto).
- **Soberano:**
  - Fúria Tripla (três cortes, o último de cima);
  - Lâmina Hesitante (ameaça o golpe pesado, para, e ataca duas vezes);
  - Rompido (ajoelha com a espada fincada).

Os testes conferem que cada acerto cabe dentro do clipe.

## Na tela
- **Cartões:** Vida, PA (losangos dourados) e Ruptura (barra laranja) dos dois, com avisos de Rompido, Selo, Concentrado e Baluarte.
- **Menu:** 5 ações com o custo; teclas 1 a 5.
- **No seu golpe:** um anel dourado fecha no círculo. Toque na tela, Espaço ou A.
- **No golpe do oponente:**
  - **ESQUIVAR** (Q / B) e **APARAR** (Espaço / E / R1);
  - os anéis são azuis, e vermelhos com "!" quando o golpe é absoluto.
- **Retorno na hora:** PERFEITO, BOM, ERROU, APARADO, ESQUIVOU, CONTRA-ATAQUE e RUPTURA, além de faíscas e números no ringue.

## Onde está
| Arquivo | Papel |
|---|---|
| `src/shared/Dados/Duelo.luau` | Regras: ações, PA, notas de tempo, defesa, contra-ataque, Ruptura, vez (puras, testadas) |
| `src/server/Arena/Motor.luau` | Motor do combate (vez, anúncio, tempo, acertos, contra-ataque, perder a vez) |
| `src/server/Arena/Servico.luau` · `PvP.luau` | Duelo contra o Soberano e 1x1, ligados ao motor |
| `src/shared/Dados/ArenaAnimacoes.luau` | Clipes novos |
| `src/client/UI/Telas/Arena.luau` · `src/client/Mundo/Arena.luau` | Tela, anéis, botões e efeitos |

O módulo antigo `Dados/Arena.luau` (duelo sem reação) saiu. O ArenaPvP ficou só com força, Elo, divisões e Rei.

## Playtest sugerido
1. **Ritmo:** contra o Soberano, conferir se o anel fecha junto com o golpe da animação. Se estiver adiantado ou atrasado, ajuste `acertos` em `Dados/Duelo`.
2. **Defesa:** aparar a Fúria Tripla inteira deve soltar o contra-ataque, e a Sentença não pode ser aparada.
3. **Ruptura:** usar o Selo e golpes Perfeitos até a barra encher. O Soberano ajoelha e perde a vez.
4. **Celular:** os botões ESQUIVAR e APARAR precisam ser fáceis de tocar, e o toque na tela precisa valer no próprio golpe.
5. **1x1:** com dois clientes, um golpeia e o outro defende. Testar também com ping alto (Studio → Network → Incoming Replication Lag).
