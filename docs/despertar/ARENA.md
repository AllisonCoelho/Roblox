# Arena do Trono

Aproxime-se do Primeiro Soberano no Nexo e escolha **Desafiar**. O atalho no teclado é **F**.
O diálogo oferece duas respostas.

- **Eu te desafio pelo trono.** O Soberano se levanta, os dois ocupam os pedestais e o painel
  mostra a intenção dele.
- **Hoje não. Vou embora.** O personagem recua até a entrada da Arena.

Um jogador por vez pode ocupar a Arena em cada servidor. Quem espera pode assistir do próprio
ponto de vista.

## Como funciona

O jogador escolhe primeiro. Se o Soberano ainda tiver vida depois da ação, ele responde com o
movimento anunciado. O prazo de escolha é 35 segundos. Em caso de vitória, derrota ou tempo
esgotado, o resultado aparece por cinco segundos. **Sair** encerra o duelo durante a partida.
A vida usada no combate é própria da Arena. No final, o jogador volta ao ponto do desafio.

| Ação | Efeito inicial |
|---|---|
| Ataque | 105 de dano e 25 de energia. |
| Corte de Ressonância | 175 de dano, 15 de energia e recarga de duas rodadas. |
| Selo de Ruptura | 60 de dano, 15 de energia e recarga de três rodadas. Reduz pela metade o próximo golpe recebido. |
| Guarda | Reduz o golpe da rodada em 65% e dá 20 de energia. |
| Despertar | Custa 100 de energia e causa 290 de dano. A aura equipada define o nome e a aparência do efeito. |

Os dois começam com 1.000 PV. O Soberano alterna Investida (100 de dano), Sentença (260 de dano)
e Baluarte (redução de 45% do dano recebido). Os números servem ao primeiro playtest. A raridade
da aura tem efeito na apresentação. Coroação, recompensas persistentes e PvP são etapas futuras.

A câmera de decisão mostra o avatar à esquerda, o Soberano à direita e o trono ao fundo. Técnicas,
Despertar e Sentença usam um corte lateral. O modo movimento reduzido conserva a câmera de decisão.
Os comandos aceitam toque, mouse, seleção por controle e teclas **1–4**.

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

1. Abra o build no Studio e use **Desafiar** perto do trono. Na entrada, o Soberano deve saltar do trono e pousar no ringue sem atravessar o chão. Os pés não podem deslizar nem afundar; se afundarem, ajuste `PERNA_R15` ou as posições `peD`/`peE` dos clipes. Teste a fuga primeiro e depois confirme
   o duelo. Confira a câmera e os botões no PC e no emulador de celular em paisagem.
2. Use Guarda na Sentença, confira as recargas das duas técnicas e carregue o Despertar com uma
   aura equipada. Observe o dano, a resposta do Soberano e a volta ao enquadramento de decisão.
3. Com dois clientes, verifique se o segundo consegue assistir e desafiar depois que a Arena for
   liberada. Repita com Sair, reset durante um golpe e abandono por tempo. A câmera e o HUD do
   Nexo devem voltar e o Soberano deve retornar ao trono.
4. Gire uma aura, abra o Índice e entre na fila de Incursões após sair do duelo. Confira também
   movimento reduzido e qualidade baixa.
