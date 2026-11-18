# Mundo Aberto e Treino — proposta lapidada

> Documento de debate. **Nada aqui está aprovado nem implementado.** Cada fase precisa do ok do dono antes de virar código.

## A ideia em uma frase

Criar uma segunda trilha de progressão, de combate, ao lado do RNG.

**Loop:** matar no mapa → juntar Essência → trocar por Treino → ficar mais forte → abrir a próxima região → bater no limite → Ascender → rodar aura de novo.

A estrutura é a dos servidores de Dragon Ball, mas espalhada num mapa vivo em vez de "sala → NPC → orbe → sala".

## Veredito: dá certo, com quatro condições

**Por que dá certo**
- **O loop é provado.** É o mesmo esqueleto de Blox Fruits, Anime Fighters e dos servidores de DBZ. O jogador sempre tem algo a fazer entre uma rolagem e outra.
- **Metade já existe.** Já temos:
  - combate autoritativo no servidor (`Combate.luau`, M1, técnicas, esquiva, guarda);
  - inimigos com IA (`Incursoes/Inimigos.luau`);
  - kit próprio da Gear 5;
  - Ressonância, que já faz a aura rara bater mais forte.

  Falta tirar tudo isso de dentro da Incursão e levar para o mapa.
- **A aura passa a mudar o gameplay, não só o visual.** Tirar uma aura nova vira "quero testar no lugar onde farmo". Esse é o gancho mais forte da proposta.
- **O Nexo ganha propósito.** Fica denso sem precisar crescer.

**Por que pode dar errado (e como evitar)**

| Risco | Como evitar |
|---|---|
| Construir em cima de um combate que ainda não foi playtestado. Se o M1 não for gostoso, farmar 50 NPCs vira castigo. | **Fase 0:** playtest do combate atual antes de tudo. |
| Escopo: 10 regiões e uma habilidade por aura (67 auras) não fecham nunca. | 3 regiões no começo. Passivas por **família** de aura (~6), não por aura. |
| Inflação de poder (+8000% de dano). | Teto de nível por Ascensão e fórmula de poder com crescimento suave, testada. |
| Celular e servidor engasgando com muitos NPCs. | Orçamento fixo (ex.: até 12 NPCs vivos por região). IA simples no servidor e visual no cliente. Região só "acorda" com jogador perto. |
| Farm AFK ou autoclicker. | Drop só para quem causou dano. Nenhum ganho sem jogador na região. Limite de abates por minuto validado no servidor. |
| Moedas demais confundem (Fragmentos de incursão, materiais, Essência, pontos). | Uma moeda nova só: **Essência**. Treino é nível, não moeda. |

## Lapidação: o que muda em relação à ideia original

1. **Nomes sem conflito.**
   - "Fragmentos" já é a moeda das Incursões, então a moeda nova se chama **Essência**.
   - "Renascer" já é o respawn do personagem na interface, então o rebirth se chama **Ascensão**.
2. **Quatro atributos, com redistribuição.**
   - Força: dano.
   - Vigor: vida.
   - Foco: recarga e medidor do Despertar.
   - Agilidade: velocidade e esquiva.

   Um número só, o **Poder**, resume tudo e aparece nas placas das regiões ("Recomendado: 250").
3. **Teto por Ascensão.**
   - Nível máximo 50. Cada Ascensão soma +25 ao teto e dá um bônus permanente pequeno (+5% de dano e vida).
   - A Ascensão zera o nível, não as auras nem os itens.
4. **Sorte fora do combate.** Concordo com a ideia original, mas um detalhe precisa de decisão:
   - A **Transcendência já dá sorte** (até 1,5x) e é paga com materiais das Incursões.
   - Proposta: deixar como está, já que tem teto e é lenta, e o Treino nunca dar sorte.
5. **Auras por família.** São ~6 passivas de farm aplicadas pelo servidor, sem mexer em chance de RNG:
   - Elétrica: dano em cadeia.
   - Fogo: chão queimando.
   - Sombra: o inimigo abatido luta por você alguns segundos.
   - Gelo: lentidão.
   - Sangue/vida: roubo de vida.
   - Borracha/Gear 5: quique e lançar para cima.

   Raridade aumenta a força da passiva. A Ressonância continua valendo.
6. **Três camadas de conteúdo.**
   - **Mundo aberto (fases 2–4):** farm constante.
   - **Desafios (fase 7):** ondas curtas e mais difíceis.
   - **Incursões (já existem):** passam a mostrar Poder recomendado.
7. **O "filho da puta da montanha".** Toda região tem um **chefe visível desde o começo**, muito acima do nível de quem chega. É ele que faz o jogador sentir que ficou mais forte.
8. **Elite por sequência.**
   - A cada N abates seguidos na região soa o alarme e nasce um **Elite**.
   - O Elite tem chance pequena de soltar **Essência Condensada**, que vale para Ascensão e cosméticos.
   - O contador de sequência fica no HUD.

## Passo a passo de implementação (um PR por fase)

**Fase 0 — Decisões e playtest (dono)**
- Aprovar este documento e os nomes (Essência, Treino, Ascensão).
- Playtestar o combate atual da Incursão e dizer o que está ruim na sensação: dano, ritmo, hitbox, câmera.
- Escolher onde ficam as 3 primeiras regiões no Nexo.

**Fase 1 — Base de dados e regras (sem visual)**
- `src/shared/Dados/Treino.luau`: XP por nível, tetos, atributos, fórmula do Poder, custo de Ascensão.
- Novo campo no perfil `Despertar_v1`: `treino = { nivel, xp, essencia, pontos, atributos, ascensoes }`, com migração que preenche zero para quem já joga.
- Ações no servidor: `DistribuirPonto` e `RedistribuirPontos`, com validação de tipo e frequência.
- Testes de curva: quanto tempo leva do nível 1 ao 50; o Poder no teto não passa de X.

**Fase 2 — Combate fora da Incursão + Região 1**
- Extrair de `Incursoes/` um serviço de combate reutilizável. A Incursão passa a usá-lo, sem mudar o comportamento.
- Liga M1, técnicas, esquiva e guarda dentro das regiões de combate. O resto do Nexo continua pacífico.
- `src/server/Mundo/Regioes.luau`:
  - pontos de nascimento dos NPCs, limite de vivos e renascimento;
  - IA simples e drop de Essência só para quem causou dano.
- Altar do Treino no Nexo: deposita Essência e sobe nível.
- HUD: Essência, nível e barra de XP.

**Fase 3 — Painel de Treino**
- Painel no padrão de cartões (Loja, Bolsa, Altar): atributos, pontos livres, Poder, botão de redistribuir.
- Placas nas entradas das regiões: nome, Poder recomendado, recompensa, chance de Elite.

**Fase 4 — Elite, chefe da região, Regiões 2 e 3**
- Contador de sequência, alarme e Elite com Essência Condensada.
- Chefe de região com renascimento lento e recompensa de primeira vitória.
- Bosque Corrompido (100–300) e Fortaleza (300–700).

**Fase 5 — Passivas de família de aura**
- Tabela família → passiva em `Dados/` e aplicação no serviço de combate.
- Efeito visual de cada passiva, original, no estilo dos VFX atuais.
- A Gear 5 ganha a passiva de quique e lançamento.

**Fase 6 — Ascensão**
- Tela de Ascensão: requisito (nível no teto + Essência Condensada), o que zera e o que fica.
- Bônus permanente e teto novo, com anúncio no servidor.

**Fase 7 — Desafios e integração**
- Área de desafio: ondas progressivas, entrada e saída rápidas, muita Essência.
- Incursões mostram Poder recomendado; o Treino passa a contar dentro delas.
- Rodada de balanceamento com os números do playtest.

**Toda fase:** stylua, testes, `rojo build`, luau-lsp e prévias das telas. Os testes no Studio são do dono.
