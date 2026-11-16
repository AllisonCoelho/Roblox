# Despertar — escopo da primeira versão

Estética **anime original**: proibir nomes, personagens, técnicas e marcas de obras existentes.

## Loop principal

O jogador clica em **Despertar**. O servidor sorteia uma aura usando `Random.new()`, respeita cooldown de cerca de 1 segundo, registra no índice e permite equipar somente as auras obtidas. O efeito equipado aparece para os outros jogadores. O ciclo se repete.

## MVP

- Aproximadamente 30 auras originais em `src/shared/Dados/Auras.luau`: id, nome, raridade `1 em N`, cores e parâmetros de partículas.
- Raridades de ≈1 em 4,2 (Faísca, a aura de reserva) até 1 em 1.000.000, sem seed vinda do cliente. Sorteio com um único número e faixas acumuladas: o "1 em N" exibido é a probabilidade real de cada aura.
- Partículas, luzes, brilho ou beams leves. Sem modelos 3D complexos.
- Índice com colecionáveis visíveis e silhuetas para desconhecidos.
- Anúncios no servidor quando raridade ≥ 1 em 1.000.
- Ranking `Giros` e `Melhor aura` em leaderstats.
- DataStore `Despertar_v1`: giros, auras obtidas (contagem), equipada e configurações.
- Giro automático usa o mesmo cooldown do manual.

## Fora da V1

Poções, presentes diários, códigos, eventos limitados, passes, trocas e títulos.

## Aceitação

CI e build verde. Sem erros no Output do Studio. Testes com dois jogadores (auras visíveis e anúncios para ambos), repetição rápida de pedidos, persistência após reconexão, interface e tempo de resposta.

## V1 implementada

- **Identidade "Tinta e Selo"**: preto-tinta, papel e vermelho de carimbo; fontes Oswald e Permanent Marker. Mockups aprovados pelo dono.
- **HUD**: placas de giros e aura equipada, selo DESPERTAR com anel de carga (intervalo de 1 s), AUTO, ÍNDICE e feed "Últimos despertares" (oculto no celular).
- **Animação de despertar** (`src/client/Mundo/Despertar.luau`), feita por código, sem asset de animação: pose via `Motor6D.C0`, flutuação, anéis, onda de choque e pilar de luz. Roda em todos os clientes pelo remote `Despertou`.
  - Comum/Incomum: sem animação. Raro: só a explosão (0,6 s). Épico/Lendário: 3,5 s. Mítico/Divino: 5 s com céu escurecido.
- **Cena de quem girou** (`Telas/Revelacao.luau`), Épico+: câmera, barras de cinema, clarão, faixa com o nome e selo da raridade. Toque pula.
- Para trocar a pose por uma animação feita no Animation Editor: publique a animação e substitua `POSES` por um `Animator:LoadAnimation` com o ID.


## Ritual + Ruptura (direção aprovada)

Frase-mãe: **o jogador não gira uma aura; ele tenta conter um poder que está despertando.**

O servidor sorteia e registra a aura **antes** de qualquer apresentação. O cliente recebe o resultado e escolhe a encenação pela chance real (`src/shared/Dados/Apresentacao.luau`):

| Chance da aura | Categoria | Até a revelação | O que acontece |
|---|---|---|---|
| até 1 em 49 | Baixa | 0,47 s | núcleo, 1 anel, pulso |
| 1 em 50 – 999 | Moderada | 0,98 s | 2 anéis, círculo no chão, uma batida |
| 1 em 1.000 – 9.999 | Alta | 1,8 s | 3 anéis, rachaduras, anéis se partem, coluna de luz, cartão, anúncio |
| 1 em 10.000 – 99.999 | Muito alta | 2,55 s | + câmera, avatar flutua, silêncio breve |
| 1 em 100.000 – 999.999 | Extrema | 3,55 s | + mais batidas e rachaduras |
| 1 em 1.000.000 | Absoluta | 5 s | + volta de câmera e céu escurecido para o servidor |

Todos os valores são parâmetros da tabela `Apresentacao.Categorias` (durações por etapa, anéis, batidas, rachaduras, onda, tremor). Ajustar ali depois do playtest; não mexe em probabilidade.

Módulos do cliente:
- `Mundo/Despertar.luau` — diretor: escolhe categoria, respeita preferências, separa "quem girou" de "os outros".
- `Mundo/Ritual.luau` — as cinco etapas em 3D (núcleo, anéis em Beam, satélites, círculo rúnico, rachaduras, estouro). Limpa tudo no fim, na morte, no respawn e ao pular.
- `Mundo/Camera.luau` — câmera cinematográfica só de quem girou; sempre restaura câmera e movimento.
- `Mundo/Sons.luau` — sons embutidos do Roblox (`rbxasset://sounds/...`), trocáveis por ids próprios.
- `Mundo/EfeitosAlheios.luau` — preferência local de esconder auras dos outros.
- `UI/Telas/Revelacao.luau` — cartão com nome, raridade real, nova descoberta/duplicata e EQUIPAR / CONTINUAR.
- `UI/Telas/Ajustes.luau` — anúncios, sons, equipar automático, animação curta para repetidas, movimento reduzido, qualidade baixa, ocultar efeitos alheios.

Regras:
- **Obter não é equipar.** Só a primeira aura é equipada sozinha; depois, pelo cartão, pelo Índice ou ligando "equipar a mais rara automaticamente".
- Os outros jogadores veem só a versão abreviada (≈1 s, sem câmera) das auras 1 em 1.000 ou mais raras, e podem desligar.
- **Teste visual (só no Studio):** `Alt+1` a `Alt+6` encena cada categoria sem sortear, salvar nem anunciar. A ação `TesteVisual` não é registrada em servidor publicado.

### Avaliação visual pendente (seção 16 do prompt mestre)

Nada disso foi visto rodando: a validação foi por testes, tipos e build. Antes de expandir, conferir no Studio com `Alt+1..6`:
- o núcleo aparece à frente do peito e os anéis formam círculos (se virarem "S", inverter o sinal de `CurveSize1` em `Ritual.definirRaio`);
- os braços vão para a frente na contenção e abrem na ruptura (ângulos em `POSES`);
- comum × 1 em 10.000 se distinguem sem ler o texto;
- tremor e brilho não incomodam; câmera volta após morte/respawn;
- os sons embutidos existem e têm volume adequado;
- FPS no celular, com e sem "qualidade baixa".

## Motion do personagem e fenda

O personagem participa do giro (poses por código, sem asset de animação):

| Raridade | O que o personagem faz |
|---|---|
| Baixa (até 1 em 49) | Gesto curto com uma mão: chama a energia e solta. |
| Moderada (1 em 50 – 999) | O mesmo gesto com as duas mãos. |
| Alta para cima (1 em 1.000+) | **Rasga a ruptura do mundo:** alcança a energia, agarra, força a abertura com as pernas firmes (os braços tremem a cada batida) e, na ruptura, abre os braços de uma vez. Entre as mãos surge uma fenda: bordas incandescentes, vazio escuro e um fio de energia. A fenda cresce com a raridade e fecha na revelação. |

- `src/shared/Dados/Trilha.luau`: qual pose vale em cada instante e quanto a fenda está aberta (lógica pura, testada).
- `src/client/Mundo/Motion.luau`: os ângulos de cada pose (tabela `Motion.Poses`). Ajustar aqui depois do playtest.
- `src/client/Mundo/Fenda.luau`: o efeito da fenda.
- Os outros jogadores veem quem rasgou a fenda na versão abreviada (1 em 1.000+).

Pular e desativar:
- **Pular:** apertar DESPERTAR (ou `E`) durante um ritual pula direto para o resultado; nas cenas com cartão, um toque na tela também pula. O giro automático nunca pula.
- **Ajustes → "Animações do giro"** desligado: sem ritual, pose nem câmera, para você e para os rituais dos outros; o resultado e o cartão aparecem na hora.
- **"Movimento reduzido"** continua tirando só pose, câmera e tremor, mantendo os efeitos.
- Nenhuma dessas opções muda resultado, cooldown ou anúncio.

A conferir no Studio (`Alt+1` a `Alt+6`): direção dos braços e pernas em cada pose, posição da fenda entre as mãos e se ela fica virada para a frente do personagem. Avatares R6 não têm essas juntas e ficam sem pose.
