# Os primeiros 5 minutos

**Objetivo:** em poucos minutos, a pessoa entende do que se trata o jogo e quer continuar.
Regras puras em `src/shared/Dados/PrimeirosMinutos.luau`, testadas.

## O que acontece com um jogador novo

1. **Abertura de 8 s** (`UI/Telas/Abertura.luau`)
   - Faixas de cinema.
   - A câmera desce sobre o Nexo, passa pela estátua da Gear 5 e para nela.
   - Na tela: "DESPERTAR · AURA RNG" e depois "Gire. Desperte. Conquiste a GEAR 5."
   - Tem botão **Pular**.
   - Só aparece para quem nunca girou e não concluiu o tutorial, uma vez por sessão.
2. **Tutorial guiado da Lume** (`Dados/Tutorial` e `UI/Telas/Tutorial`)
   - Começa depois da abertura e segue a trilha.
   - Passos: boas-vindas (destaca a trilha), girar, pontos, evoluir, sorte, pegar um drop,
     **estátua da Gear 5** (novo), Portais (Corredor) e final (Arena e trilha).
   - Cada objetivo de lugar tem uma coluna de luz e a distância em metros.
3. **Primeiro giro garantido Raro ou melhor** (servidor, `Servicos/Sorteio`)
   - Se o primeiro giro da vida sair abaixo de Raro, vira uma aura Rara sorteada pelo `Random`
     do servidor.
   - A Lume comemora: "a sua primeira aura já veio RARA!".
4. **Trilha do caminho no HUD** (`UI/Telas/Caminho.luau`)
   - Etapas: **GIRAR → EVOLUIR → CORREDOR → ARENA → EVENTO**.
   - O que já foi feito fica verde e o próximo passo pulsa em dourado.
   - Tocar numa etapa mostra o que fazer e abre o painel certo.
   - Some quando tudo foi feito.
5. **Estátua da Gear 5 na praça** (`Servicos/Estatua` e `Mundo/Estatua`)
   - Boneco de mármore gigante a leste da praça, com o punho erguido, auréola de sol, faíscas,
     pilar de luz e anéis dourados.
   - Placa: "☀ AURA GEAR 5 ☀ · Só no baú do evento" e a contagem do próximo Despertar do Sol.
   - Muda para "O TITÃ ESTÁ NA PRAÇA!" durante a luta.
   - A interação "Ver baús do Sol" abre o painel de baús.

## O que conta como feito na trilha

| Etapa | Feita quando |
|---|---|
| GIRAR | girou pelo menos uma vez |
| EVOLUIR | comprou uma evolução (nível, fluxo ou sorte) |
| CORREDOR | concluiu uma fase do Corredor |
| ARENA | lutou na Arena (vitória, derrota ou Soberano) |
| EVENTO | participou do Despertar do Sol ou abriu um baú |

## Não testado ainda

Nada foi testado no Roblox Studio. Falta conferir no playtest:
- câmera da abertura;
- posição da estátua no mapa;
- trilha no celular;
- primeiro giro Raro numa conta nova;
- passo da estátua no tutorial.
