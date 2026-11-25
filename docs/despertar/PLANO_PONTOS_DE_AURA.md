# Pontos de Aura, Corredor dos Perdidos e Pets — plano

> Plano aprovado pelo dono (nov/2026), com as decisões no fim. Substitui as propostas de mundo aberto e dos Guardiões (`GUARDIOES.md`).
>
> **Já implementado:** Etapa 1 e o painel Evoluir da Etapa 2. A sorte já entra no giro. As Incursões estão desligadas. Detalhes em `PONTOS_DE_AURA.md`.
>
> **Corredor dos Perdidos (Etapa 4):** seis fases no céu do Nexo, sem as criaturas por enquanto. Detalhes em `CORREDOR.md`.

## A ideia em uma frase

A aura que você tirou **gera Pontos de Aura** enquanto você joga. Com esses pontos você **evolui a Pontuação de Aura**, que decide quem é o mais forte na **Arena**. No **Corredor dos Perdidos** você atravessa mundos fragmentados e ganha **Fragmentos**, que compram **Pets** que multiplicam a geração de aura. A **Sorte** liga tudo de volta ao RNG.

## O ciclo do jogo

```
Gira aura (RNG) ─► a aura gera Pontos de Aura por segundo
      ▲                    │
      │                    ▼
   Sorte  ◄──── Evoluir (Nível de Aura, Fluxo, Sorte)
      ▲                    │
      │                    ▼
    Pets  ◄── Fragmentos ◄── Corredor dos Perdidos (fases + Guardiões)
                           │
                           ▼
              Pontuação de Aura ─► Arena (x1 e Trono) e ranking
```

Cada sistema alimenta o outro, e nenhum fica isolado:
- **Auras melhores** geram mais pontos, então girar volta a importar.
- **Mais pontos** dão mais Pontuação, que abre fases mais difíceis do Corredor.
- **Fases mais difíceis** dão mais Fragmentos, que compram pets melhores.
- **Pets melhores** geram mais pontos e mais sorte, e mais sorte dá auras melhores.

## Lapidação: o que ajustei na ideia

1. **Ganhar parado e ganhar jogando.**
   - Ficar no jogo gera pontos sozinho: é o lado "quem fica mais tempo fica mais forte".
   - Mas, se só ficar parado já basta, ninguém entra no Corredor. Por isso, concluir uma fase dá **Ressonância de Combate**: x2 nos Pontos de Aura por alguns minutos.
   - Fragmentos vêm **só** do Corredor, ou seja, de jogar ativamente.
   - O Roblox desconecta quem fica 20 min sem tocar em nada. Não vamos burlar isso.
   - Ganho offline: proponho **nenhum** no começo e decidir depois do playtest.
2. **Curva de raridade que não explode.** A geração cresce com a raridade, mas suavizada (algo como raiz quarta da chance). Pela raridade:

   | Raridade | Gera |
   |---|---|
   | 1 em 2 | 1/s |
   | 1 em 1.000 | ~6/s |
   | 1 em 1 milhão | ~30/s |
   | 1 em 1 bilhão | ~180/s |

   A aura rara faz diferença enorme sem tornar impossível alcançar quem a tem. Os números finais saem de teste.
3. **Pontos de Aura são moeda; Pontuação de Aura é força.** Você gasta os pontos em três evoluções, com custo crescente:
   - **Nível de Aura:** sobe a Pontuação.
   - **Fluxo:** mais pontos por segundo.
   - **Sorte:** sobe a sorte do giro, com teto.

   Pontuação = Nível × força da aura equipada × bônus dos pets.
4. **Arena x1: força pesa muito, mas não é tudo.**
   - O duelo por turnos que já existe passa a valer entre jogadores, como desafio que o outro aceita.
   - A Pontuação multiplica o dano (algo como a raiz da diferença). Quem é bem mais forte quase sempre vence, mas, entre forças parecidas, a escolha de turno decide.
   - **Trono do servidor:** quem vence o Soberano vira o Soberano daquele servidor, com coroa, título e nome no trono, até alguém derrubá-lo.
5. **Corredor dos Perdidos aproveita as Incursões.** As Incursões já têm universos (Cinzas, Maré Morta, Crepúsculo Umbral), andares, criaturas, Guardiões, combate e a moeda **Fragmentos**.
   - O Corredor reorganiza isso em uma linha de mundos fragmentados no espaço. Cada mundo tem fases com criaturas e um Guardião no fim.
   - Para entrar em cada mundo, é preciso uma Pontuação mínima.
   - Dá para jogar sozinho ou em grupo de até 4.
   - Reaproveitar economiza meses de trabalho.
6. **Pets.**
   - Saem de **Núcleos**, que são ovos comprados com Fragmentos, um tipo por mundo, com chances exibidas.
   - Cada pet tem raridade e um bônus: **+% Pontos de Aura** (a maioria), **+% Sorte** (raros) ou **+% Fragmentos**.
   - Começa com 3 espaços equipados.
   - O pet segue o jogador e tem modelo original (Blender).
   - Depois: fundir 5 pets iguais em uma versão dourada.
7. **Sorte com teto.**
   - Fontes: evolução de Sorte, pets, Transcendência (que já existe) e poções.
   - O total é limitado (ex.: até 10x). A chance que aparece no Índice e no giro passa a mostrar a chance com a sorte aplicada, coisa que `Auras.chanceEfetiva` já faz.
   - **Precisa de autorização explícita**, porque mexe nas chances efetivas.
8. **Regras de Robux.**
   - Núcleos pagos com Robux só com as chances exibidas (regra do Roblox para itens aleatórios).
   - No começo, Núcleos só com Fragmentos.
   - Produtos sugeridos para depois: 2x Pontos de Aura, +1 espaço de pet, Núcleo da sorte. Os IDs ficam com o dono, como sempre.

## O que acontece com o que já existe

| Sistema | Fica como |
|---|---|
| Giro / Índice / 67 auras | Centro do jogo; a raridade agora também gera pontos |
| Incursões | Viram o Corredor dos Perdidos (mesma base de código) |
| Fragmentos | Mesmo nome; passam a comprar Núcleos de pets |
| Relíquias das Incursões | **Decisão:** viram bônus de pets ou saem |
| Forja / Transcender | Continuam; materiais caem no Corredor; Transcender soma na Sorte |
| Arena / Soberano | Ganha x1 entre jogadores e o Trono do servidor |
| Loja / Passe de Temporada | Ganham missões de Pontos de Aura e Corredor |

## Plano de ação (um PR por etapa)

**Etapa 0 — decisões (dono):** ver a lista abaixo.

**Etapa 1 — Pontos de Aura (fundação)**
- `src/shared/Dados/PontosAura.luau`: geração por raridade, curvas de custo das evoluções e fórmula da Pontuação. Sem Roblox, com testes.
- Novo campo no save do `Despertar_v1`: `aura = { pontos, nivel, fluxo, sorte }`, com migração que preenche zero.
- Servidor: a cada segundo soma os pontos de quem está no jogo e salva junto com o perfil (sem gravar a cada segundo).
- HUD: contador de Pontos de Aura com "+X/s" e a Pontuação no cartão do jogador.

**Etapa 2 — Evoluir**
- Painel "Evoluir" no padrão de cartões, com Nível de Aura, Fluxo e Sorte.
- A Sorte entra na chance efetiva do giro só depois da autorização e do teto.

**Etapa 3 — Pets**
- `Dados/Pets.luau`: ~12 pets do mundo 1, raridades, bônus e chances dos Núcleos.
- Abrir Núcleo (com animação), inventário, equipar 3, pet seguindo o jogador.
- Modelos originais no Blender, com prévias.

**Etapa 4 — Corredor dos Perdidos**
- As Incursões viram uma linha de mundos fragmentados, com Pontuação mínima por mundo.
- Fases com criaturas, Guardião no fim e Fragmentos por fase.
- Ressonância de Combate ao concluir uma fase.
- Portal no Nexo, no lugar dos Portais Fragmentados ou do Bastião.

**Etapa 5 — Arena x1 e Trono**
- Duelo por turnos entre jogadores, com a Pontuação no dano.
- Trono do servidor e ranking de Pontuação. O ranking global depende de autorização, que já está nas pendências.

**Etapa 6 — Sorte completa, poções e eventos**
- Teto, poções temporárias e eventos de servidor (ex.: 2x Pontos por 15 min).

**Etapa 7 — Ascensão e produtos**
- Ascensão: zera Nível e Pontos em troca de multiplicador permanente e +1 espaço de pet.
- Produtos com IDs do dono.

**Toda etapa:** testes, stylua, rojo, luau-lsp e prévias das telas. Os testes no Studio são do dono.

## Decisões do dono (respondidas em nov/2026)

1. **Corredor dos Perdidos:** não reaproveita as Incursões.
   - É um corredor no próprio mapa, no mesmo ambiente, com portões por nível.
   - Quem não tem Pontuação de Aura suficiente não entra nem passa para o próximo nível.
2. **Incursões:** desligadas por agora (`Config.IncursoesAtivas = false`). O código continua no projeto.
3. **Ganho com o jogo fechado:** não. Vai existir um **mapa AFK**, a pesquisar e montar depois.
4. **Sorte:** autorizada a mexer no giro. As auras mais raras ficam quase impossíveis no começo, e a evolução de sorte deixa tudo cada vez mais fácil, mas nunca fácil.
5. **Arena x1:** o mais forte sempre vence; com auras semelhantes, cada turno importa.
6. **Ranking global:** autorizado.
7. **Nomes:** aprovados.
