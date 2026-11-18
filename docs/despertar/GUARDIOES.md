# Guardiões do Nexo — proposta

> Documento de debate. **Nada aqui está aprovado nem implementado.** Cada fase precisa do ok do dono antes de virar código.

## A ideia

Adaptar o loop dos servidores de Dragon Ball ("mato → ganho → fico forte → próxima área") ao nosso RNG, **sem mundo aberto e sem atributos**:
- O mapa e a estrutura do Nexo continuam iguais.
- Cada lugar do Nexo foi **tomado por um Guardião**, um chefe parado.
- O jogador toca no Guardião e começa um **Duelo de Ressonância**: a própria aura ataca sozinha e o jogador defende no tempo certo.
- O Guardião solta materiais e, com chance rara, um item exclusivo.
- Quem vence libera a área e pode desafiar o próximo Guardião.
- O **Primeiro Soberano** continua sendo o mais forte do servidor, no duelo por turnos da Arena.

## Por que se encaixa no RNG

- **A força vem da aura**, sem Força ou Agilidade.
  - O dano do duelo usa a Ressonância, que já existe: quanto mais rara a melhor aura, mais forte.
  - A aparência dos ataques segue a aura equipada. A Gear 5 duela diferente de uma aura de chama.
  - Tirar uma aura nova significa poder voltar e derrubar quem antes te derrubava.
- **O drop também é RNG.** Cada Guardião tem tabela com chances exibidas ("Coroa do Bosque — 1 em 80"). Um drop raro gera anúncio no servidor, como uma aura rara.
- **Usa o que já existe.** Os materiais vão para a Forja e para a Transcendência do Altar, e os artefatos da Bolsa dão bônus no duelo. Nenhuma moeda nova.

## Os Guardiões (ordem de dificuldade)

Cada um fica na borda do seu lugar, sem bloquear console, Forja nem Mesa dos Cartógrafos.

| # | Lugar | Guardião (nome provisório) | Ideia de ataque |
|---|---|---|---|
| 1 | Jardim dos Fragmentos | Colosso de Musgo | Pancadas lentas e bem avisadas, para ensinar |
| 2 | Arquivo dos Ecos | Escriba Fantasma | Projéteis em sequência, defesa rápida |
| 3 | Portais Fragmentados | Sentinela da Fenda | Golpes que trocam de ritmo |
| 4 | Obelisco das Lendas | Arauto Dourado | Carga longa e golpe devastador |
| 5 | Altar da Ressonância | Coração Corrompido | Mistura todos os padrões |
| — | Arena do Trono | **Primeiro Soberano** (já existe) | Duelo por turnos, o chefe final |

**Enquanto um Guardião não for vencido**, seu lugar fica "tomado" para aquele jogador: névoa da cor dele, chão rachado, música tensa perto. Vencido, o lugar se purifica só para quem venceu, e o Guardião seguinte acende.

**Eco Errante (evento):** de tempos em tempos aparece um chefe num ponto aleatório do mapa. Todo o servidor pode duelar ao mesmo tempo, e todos que ajudaram recebem o drop.

## Como é o Duelo de Ressonância

- **Início:** tocar ou clicar no Guardião (ProximityPrompt). A câmera enquadra os dois e o jogador não anda.
- **Ataque automático:** a cada ~1,2 s a aura dispara um golpe (projétil, corte ou onda, conforme a família da aura).
  - **Dano** = base × Ressonância × bônus do artefato equipado × Marcas.
- **O Guardião ataca com aviso:** um anel se fecha sobre o jogador.
  - Tocar **Ressoar** quando o anel fecha: bloqueio perfeito, devolve dano e enche o medidor.
  - Tocar fora do tempo ou não tocar: toma o golpe.
- **Despertar:** com o medidor cheio, um botão dispara o golpe especial da aura (reaproveita o Despertar do combate das Incursões).
- **Fim:** o duelo dura de 30 a 60 s. Se a vida acabar, o jogador perde, sem penalidade, e espera um pouco para tentar de novo.
- **Controles:** dois botões só (Ressoar e Despertar), que funcionam bem no celular.
- **Servidor:**
  - cada jogador tem a própria vida do Guardião, então vários podem duelar ao mesmo tempo;
  - o servidor sorteia, calcula o dano e valida o tempo do Ressoar;
  - o cliente só desenha.
- **Repetir:** o Guardião volta para aquele jogador depois de ~1 min. Dá para farmar o drop raro sem virar sessão de 50 cliques.

## Progressão sem atributos

- **Marcas:** a primeira vitória sobre cada Guardião dá uma Marca permanente (+dano e +vida no duelo e nas Incursões). É assim que o jogador sente que ficou mais forte.
- **Poder** = Ressonância da melhor aura × artefato × Marcas. Aparece ao lado do Poder recomendado de cada Guardião ("Recomendado 2,4 · Seu 1,9").
- **Primeiro Soberano:** com as 5 Marcas, o duelo dele fica justo. Sem elas, ele é quase impossível, mas o desafio continua aberto.
- **Sorte:** nenhuma das recompensas dá sorte de RNG.

## Passo a passo (um PR por fase)

**Fase 0 — Decisões (dono)**
- Nomes, ordem dos lugares e se o Soberano exige as 5 Marcas ou fica aberto.

**Fase 1 — Regras e dados (sem visual)**
- `src/shared/Dados/Guardioes.luau`: vida, padrões de ataque, janelas do Ressoar, drops com chances e Poder recomendado.
- Fórmula do Poder e das Marcas.
- Perfil `Despertar_v1`: `guardioes = { vencidos = {}, vitorias = {} }`, com migração que preenche vazio.
- Testes: duração do duelo por raridade de aura, soma das chances de drop, limites.

**Fase 2 — Serviço do duelo (servidor)**
- `src/server/Guardioes/Servico.luau`:
  - duelo instanciado por jogador, relógio do servidor e sorteio com `Random.new()`;
  - ações `DesafiarGuardiao`, `Ressoar` e `DespertarDuelo`, com validação de tipo, frequência e distância;
  - fila de espera depois da derrota ou da vitória.

**Fase 3 — Primeiro Guardião completo (Jardim)**
- Modelo original no Blender e posição na borda do Jardim.
- Câmera do duelo, golpes da aura (reaproveita os VFX), anel de aviso, barras de vida e os dois botões.
- Névoa e purificação do lugar.
- Prévias das telas e playtest antes de seguir.

**Fase 4 — Guardiões 2 a 5**
- Modelos, padrões e drops; anúncio de drop raro.

**Fase 5 — Eco Errante**
- Evento cooperativo no mapa.

**Fase 6 — Ligação com o Soberano e as Incursões**
- Marcas valendo na Arena e nas Incursões; balanceamento com números do playtest.

**Toda fase:** stylua, testes, `rojo build`, luau-lsp e prévias das telas. Os testes no Studio são do dono.
