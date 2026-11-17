# Incursões 2.0 — fase A

**Status:** implementado e testado fora do jogo (testes de lógica, tipos, `rojo build`). Falta o playtest.

## O que muda em cada run
- **Andares sorteados:** os andares 1 a 4 são sorteados sem repetir o tipo do andar anterior; o 5º é sempre o Guardião.

| Tipo | Objetivo | Nota S |
|---|---|---|
| Purificação | Purificar todos os Núcleos (o modo atual) | ≤ 95 s e sem quedas |
| Horda | Sobreviver 45 s + 5 s por andar; as ondas crescem e ficam mais rápidas | Sem quedas |
| Caçada | Derrubar 3 Elites (+1 a cada 2 jogadores extras) | ≤ 80 s |
| Escolta | Levar o Núcleo até a fenda; ele só anda com alguém perto e para se um inimigo encostar | ≤ 90 s |
| Cofre da Fenda | A fenda já abre; abrir o Cofre guardado por Elites (4 s perto, sem inimigos) dá o loot do andar de novo, com nota S | — |

- **Inimigos:**
  - **Sombra:** o inimigo básico.
  - **Corredor:** rápido e frágil.
  - **Atirador:** mantém distância e dispara com aviso; risco vermelho, dá para sair da mira.
  - **Explosivo:** acende o pavio perto do alvo e explode em área.
  - **Escudeiro:** tanque; recebe só 30% do dano de frente.
- **Elites:** coroa e nome sobre a cabeça, 3,5× a vida e 1 ou 2 afixos:
  - **Veloz:** mais rápida.
  - **Blindado:** recebe menos dano.
  - **Vampírico:** cura ao bater.
  - **Instável:** explode ao morrer.

  A partir do 2º andar aparecem Elites de surpresa, com anúncio na tela.
- **Bênçãos da Fenda:** ao concluir cada andar, cada jogador escolhe 1 de 3 cartas. Elas valem só nesta run e não se repetem. São 12, entre comuns, raras e lendárias: Ressonância Feroz, Olho Crítico, Técnicas Fluidas, Passo Fantasma, Pele de Pedra, Vigor da Fenda, Lâmina Faminta, Pulso em Cadeia, Despertar Ardente, Eco do Golpe, Rastro de Brasas e Ganância. Quem não escolher a tempo recebe uma sorteada ao descer.
- **Nota S/A/B:** calculada por tempo e quedas no andar. Multiplica os Fragmentos daquele andar (S ×1,5, A ×1,2, B ×1).
- **Sequência de abates:** contador na tela (janela de 3 s), com títulos em 5, 10 e 20 abates.

## Onde está
- **Regras puras (testadas):** `src/shared/Dados/IncursoesRun.luau`.
- **Servidor:**
  - `src/server/Incursoes/Servico.luau`: tipos de andar, Elites, Bênçãos, nota, sequência e Cofre.
  - `Inimigos.luau`: tipos de inimigo e afixos.
  - `Combate.luau`: efeito das Bênçãos no combate.
- **Cliente:**
  - `src/client/UI/Telas/IncursoesRunUI.luau`: banner, nota, sequência, alerta de Elite e cartas.
  - `Visual.luau`: nomes sobre os inimigos e aviso do disparo do Atirador.

## Fase B

### Guardião em 3 fases
O Guardião muda de fase aos 66% e aos 33% de vida. Em cada troca há uma onda de choque e 3 reforços, e a mecânica do universo começa:

| Universo | Mecânica (fase 2 → fase 3 mais intensa) |
|---|---|
| Cinzas — Arauto das Brasas | **Chuva de Brasas:** 4 círculos de fogo com aviso caem em cima dos jogadores (7 na fase 3) |
| Maré Morta — Cavaleiro Afogado | **Maré Alta:** onda em anel de raio 26; o único lugar seguro é colado nele (círculo verde) |
| Crepúsculo Umbral — Espectro do Ocaso | **Eclipse:** a tela escurece; ele some e reaparece em outro ponto e a sombra explode onde estava; na fase 3 deixa um reforço |

Depois de 3 minutos de luta o Guardião **enfurece**: +60% de dano, +40% de velocidade e golpe mais frequente.

### Marcas da Fenda
São escolhidas na Mesa dos Cartógrafos, no quadro "Preparo da Fenda". Quem abre a fila define o preparo do grupo, e o servidor valida tudo.

| Marca | Efeito | Fragmentos |
|---|---|---|
| Hordas Densas | +40% de inimigos | +25% |
| Sombras Velozes | Inimigos 30% mais rápidos | +20% |
| Corpo de Vidro | Jogadores com 30% menos vida | +30% |
| Coroa Dupla | Elites em dobro e com mais afixos | +30% |
| Sem Reviver | O grupo não tem vidas extras | +50% |

### Pesadelo
- **Liberação:** depois de vencer o universo no normal.
- **Dificuldade:** inimigos com ×1,8 de vida e dano e 12% mais rápidos; Elites com afixo extra.
- **Recompensa:** Fragmentos ×2 e bônus de vitória ×2.

O multiplicador final das Marcas e do Pesadelo aparece no painel antes de entrar.

### Auditoria da fase A (corrigido)
- Bênção sorteada automaticamente agora aplica os efeitos e aparece no HUD.
- Explosões e zonas pendentes passam a pertencer à partida certa (por posição), em vez de uma lista global consumida por qualquer partida.
- Eco do Golpe e Rastro de Brasas ganharam efeito visual.
- Abate pelo rebote da guarda da Gear 5 agora conta na sequência e na cura.

## Próximas fases
- **C:** Fenda do Dia com ranking diário, desafios semanais e reviver colega.
