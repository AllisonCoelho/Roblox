# Arena do Trono

**Status:** o duelo contra o Soberano já existia. O Trono do Servidor, o x1 entre jogadores, a Rankeada e o ranking global foram implementados e testados fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio com dois jogadores.**

A Arena tem duas partes no mesmo ringue, um duelo por vez:

| | Trono do Servidor | Rankeada |
|---|---|---|
| Contra quem | O Primeiro Soberano e depois o Rei | Jogadores deste servidor com rating parecido |
| Vale | O trono e o buff de Rei | Rating (Elo) e o ranking global |
| Como entra | Desafiar o Soberano; depois "Desafiar o Rei" no painel | "Entrar na fila" no painel |

O painel abre em **"Trono e Rankeada"**, perto do Soberano (tecla **G**). Tem três abas: Trono, Rankeada e Ranking.

## Trono do Servidor (sem rating)
1. **Começo:** o trono começa com o **Primeiro Soberano**.
2. **Prova:** vencer o Soberano no duelo de sempre é a **prova do trono**. Fica salva no perfil (`arena.monarca`) para sempre.
3. **Coroação:** se o trono estiver com o Soberano, quem o vence vira o **Rei do Servidor** e todos recebem um anúncio.
4. **Desafiar:** com um Rei no trono, quem já tem a prova pode **desafiar o Rei** no painel. O desafio entra numa fila.
5. **Chamado:** quando o ringue fica livre, o Rei é chamado e tem 12 s para **Lutar agora** ou **Entregar o trono**. Sem resposta, o duelo começa sozinho. Se o Rei estiver morto ou ocupado, o desafiante continua na frente da fila.
6. **Resultado:** quem vence o x1 fica com o trono. Depois de defender, o Rei fica protegido por 30 s.
7. **Saída:** se o Rei sair do servidor, o trono volta ao Soberano e a fila esvazia.

**Buff do Rei:** +25% de Pontos de Aura e +10% de sorte, dentro do teto de 20x. Vale enquanto reinar.

**Visual do Rei:** uma coroa dourada com cristais (feita no Blender) gira sobre a cabeça dele, com o título "👑 REI DO SERVIDOR", e todos veem.

**Perfil:** guarda o número de reinados e o reinado mais longo.

## O x1 entre jogadores
O x1 usa o **combate reativo** (veja `COMBATE_REATIVO.md`), o mesmo do duelo contra o Soberano.
- **Turnos:** vez a vez. Na sua vez, você escolhe a ação e acerta o tempo do golpe; na do oponente, Esquiva ou Apara cada golpe.
- **Dano pela Pontuação de Aura:** multiplicador = (sua Pontuação / a do oponente)^0,6, entre ×0,35 e ×2,8. O mais forte vence; entre auras parecidas, cada turno decide.
- **Sem escolha no prazo:** quem não escolher em 30 s Concentra.
- **Fim:** depois de 40 vezes, vence quem tem mais vida. Sair, morrer ou sair do jogo conta como desistência.
- **Câmera e animações:** a câmera é espelhada para quem está do outro lado do ringue, e as animações são as mesmas.
- **Corredor:** quem estava no Corredor sai dele e, no fim, volta para a entrada da Arena.

## Rankeada e ranking global
**Rating:** Elo, começando em 1000, com K = 32. Vencer quem tem rating maior vale mais.

**Divisões:** Bronze, Prata (1100), Ouro (1250), Platina (1400), Diamante (1600) e Mestre (1850).

**Fila**
- Pareia jogadores **deste servidor** com rating parecido.
- A janela aceita começa em ±100 e cresce 50 a cada 10 s de espera.
- O duelo começa 5 s depois do pareamento, quando o ringue estiver livre. O Trono tem prioridade.

**Ranking global**
- Fica num **OrderedDataStore novo**, `Despertar_v1_RankingArena` (UserId → rating). Nenhum store antigo é lido ou alterado.
- O servidor grava depois de cada partida e lê o **top 50** a cada minuto.
- O top é publicado em `ReplicatedStorage.RankingGlobal` e misturado com os jogadores do servidor, que aparecem atualizados na hora.
- No Studio com ModoTeste nada é gravado: o ranking mostra só o servidor.

**Limitações**
- Só pareia jogadores do mesmo servidor; um pareamento entre servidores fica para depois.
- Quem sai do jogo durante um duelo perde, mas o rating dele só é gravado se ainda estiver no servidor quando o duelo termina.

## Onde está
| Arquivo | Papel |
|---|---|
| `src/shared/Dados/ArenaPvP.luau` | x1 simultâneo, força pela Pontuação, Elo, divisões, perfil e buff do Rei (regras puras, testadas) |
| `src/server/Arena/Palco.luau` | O ringue é um só: reserva e libera |
| `src/server/Arena/PvP.luau` | Motor do x1: posições, turnos, animações, desistência |
| `src/server/Arena/Trono.luau` | Rei do Servidor, fila de desafios, chamado do Rei, buff |
| `src/server/Arena/Rankeada.luau` | Fila, pareamento, Elo e ranking global |
| `src/server/Arena/Servico.luau` | Duelo contra o Soberano (agora divide o ringue e coroa o vencedor) |
| `src/client/UI/Telas/ArenaLobby.luau` | Painel Trono, Rankeada e Ranking, e o aviso de desafio para o Rei |
| `src/client/UI/Telas/Arena.luau`, `src/client/Mundo/Arena.luau` | A mesma tela e câmera, agora também no x1 |
| `src/client/Mundo/Coroa.luau` | Coroa e título sobre o Rei |
| `assets/arena/source/generate_coroa.py` | A coroa no Blender |

**Painel Dev:** "Vencer o Soberano / virar Rei (teste)" só funciona na sessão de teste.

## Playtest do Trono e da Rankeada
1. **Coroação:** no Studio, com 2 jogadores (Test → Local Server), o jogador 1 vence o Soberano. Ele deve virar Rei, com coroa, título, anúncio e o ganho por segundo maior.
2. **Desafio:** o jogador 2 vence o Soberano e abre o painel (G) → Trono → Desafiar o Rei.
   - O Rei deve receber o aviso.
   - Conferir Lutar, Entregar e o duelo começando sozinho.
3. **No x1:** conferir a câmera espelhada do jogador 2, as escolhas simultâneas, o "Fulano já escolheu", a Guarda e o Selo. Sair no meio deve contar como derrota.
4. **Rankeada:** os dois entram na fila. Eles devem se encontrar, lutar e ver o rating mudar (+16/−16 com ratings iguais) e aparecer na aba Ranking.
5. **Saídas:** o Rei sai do jogo e o trono volta ao Soberano. Repetir com alguém vindo do Corredor.

---

## Duelo contra o Primeiro Soberano (a prova do trono)

Aproxime-se do Primeiro Soberano no Nexo e escolha **Desafiar**. O atalho no teclado é **F**. O diálogo oferece duas respostas:
- **Eu te desafio pelo trono.** O Soberano salta do trono para o ringue.
- **Hoje não. Vou embora.** O personagem recua até a entrada da Arena.

**O combate é reativo** (veja `COMBATE_REATIVO.md`):
- **Sua vez:** escolha Ataque, Corte, Selo, Despertar ou Concentrar. Acerte o anel dourado no tempo certo.
- **Vez do Soberano:** **Esquive** ou **Apare** cada golpe. Aparar todos solta o contra-ataque.
- **Aviso:** a tela mostra o que o Soberano prepara. Os dois começam com 1.000 PV.
- **Prazo:** 30 s para escolher; sem escolha, o duelo termina.
- **Ringue:** é um só para o Soberano, o Trono e a Rankeada.

## Animações do duelo

As animações são feitas por código, sem assets publicados. Os quadros-chave e os tempos ficam em `src/shared/Dados/ArenaAnimacoes.luau`. O servidor escreve qual clipe tocar e em que instante: `ArenaAnim`/`ArenaAnimEm` no Player e `DueloAnim`/`DueloAnimEm` no Soberano. Assim, quem assiste vê o mesmo movimento do desafiante.

**Pernas plantadas:** os pés de cada clipe são posições no chão, e coxa e joelho saem de cinemática inversa. Quando o corpo avança, o pé de trás continua no chão.

**Jogador** (`src/client/Mundo/ArenaCorpo.luau`, R15; o R6 usa braços, tronco e quadris)
- Postura de luta com respiração entre as ações.
- **Ataque:** corre até o Soberano, solta um direto e volta com um salto para trás.
- **Corte:** avança, salta e gira com o braço esticado.
- **Selo:** abre a base e empurra as duas palmas.
- **Guarda:** cruza os braços e segura a pose até o golpe chegar; no impacto, desliza para trás.
- **Despertar:** junta energia agachado, sobe com os braços ao céu e descarrega à frente.
- **Golpe recebido:** recua no golpe leve; no pesado, é arremessado e cai sobre um joelho.
- **Fim:** punho erguido na vitória, joelho no chão na derrota.

**Soberano** (`src/client/Mundo/NPCs/PrimeiroSoberano.luau`). As pernas agora são cinco peças articuladas: quadril, duas coxas e duas canelas.
- **Entrada:** levanta do trono, agacha, salta até o ringue e pousa com o espadão no chão (poeira no piso).
- **Aviso do próximo golpe:**
  - Investida: aponta a espada.
  - Sentença: espadão acima da cabeça.
  - Baluarte: guarda fechada.
- **Investida:** torce o corpo, arranca com passadas e corta de lado.
- **Sentença:** agacha, salta e crava o espadão no chão, com onda de poeira e tremor de câmera.
- **Baluarte:** firma a base com a lâmina na frente do peito.
- **Golpe recebido:** recua no leve; no Corte e no Despertar, é empurrado e derrapa.
- **Fim:** ajoelha com a espada fincada quando perde; ergue o espadão quando vence.

**Tempos:** o duelo ficou um pouco mais lento para as animações caberem. O golpe comum leva ~0,9 s e a Sentença ~1,6 s; a entrada leva 2,6 s.

**Acessibilidade:**
- Movimento reduzido: sem giros completos nem saltos altos, com deslocamentos pela metade.
- Qualidade baixa: sem a poeira do pouso.

**Prévias:** `assets/npcs/primeiro_soberano/previews/duelo_*` são renders do Blender com as poses calculadas pelo mesmo módulo, não prints do Roblox.

## Playtest

O roteiro de playtest do combate (tempo dos anéis, aparar, Ruptura, celular e ping) está em `COMBATE_REATIVO.md`. As animações continuam com os cuidados acima: os pés não podem deslizar nem afundar, e o modo movimento reduzido e a qualidade baixa precisam ser conferidos.
