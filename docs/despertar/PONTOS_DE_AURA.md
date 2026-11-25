# Pontos de Aura, Evoluir e Sorte

Primeira parte do plano em [PLANO_PONTOS_DE_AURA.md](PLANO_PONTOS_DE_AURA.md). Status: implementado e testado fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio.**

## Como funciona

**Pontos de Aura**
- A aura equipada gera pontos por segundo enquanto a pessoa está no jogo.
- O ganho cresce com a raridade, suavizado pela raiz quarta da chance:

  | Aura | Ganho |
  |---|---|
  | 1 em 2 | ~1,2/s |
  | 1 em 1.000 | ~5,6/s |
  | 1 em 1 milhão | ~32/s |
  | Soberania do Vazio (1 em 100 milhões) | 100/s |
  | Sem aura equipada | 0,5/s |
- Não há ganho com o jogo fechado; o mapa AFK vem depois.

**Evoluções** (painel **Evoluir**, no menu lateral e tocando no contador do topo)

| Evolução | Efeito por nível | Custo do nível n | Máximo |
|---|---|---|---|
| Nível de Aura | +25% de Pontuação | 25 × 1,12ⁿ | 500 |
| Fluxo | +10% de pontos por segundo | 60 × 1,17ⁿ | 120 |
| Sorte | +0,2x de sorte no giro | 200 × 1,16ⁿ | 95 |

**Pontuação de Aura**
- Fórmula: 10 × força da aura equipada × (1 + 0,25 × Nível).
- Aparece no topo do HUD e é a primeira coluna da lista de jogadores.
- Vai decidir a Arena x1, o ranking e os portões do Corredor.

**Sorte do giro**
- Fórmula: evolução × Transcendência (até 1,5x) × fontes futuras (pets).
- Teto total de **20x** (`Probabilidades.MAX_SORTE`).
- O Índice e o HUD mostram a chance já com a sorte aplicada.

**Valores de referência** (mesmo motor de pesos por raridade)

| Sorte | Soberania do Vazio | Qualquer Divina |
|---|---|---|
| 1x (começo) | 1 em 100 milhões | 1 em ~915 mil |
| 3x | 1 em ~16,8 milhões | 1 em ~154 mil |
| 10x | 1 em ~2,8 milhões | 1 em ~25,6 mil |
| 20x (teto) | 1 em ~1,1 milhão | 1 em ~10,3 mil |

## Servidor

- `Servicos/PontosAura.luau` soma o ganho a cada segundo para quem pode progredir. Não soma durante transações do Altar nem com o perfil sem salvar.
- O saldo, o ganho, a Pontuação e a sorte vão em atributos do Player (`PontosAura`, `GanhoAura`, `Pontuacao`, `SorteTotal`). O perfil é reenviado a cada 10 s.
- A ação `Evoluir` (`nivel`/`fluxo`/`sorte`) confere o saldo e o máximo no servidor.
- Pets, passes e bônus do Corredor entram depois por `registrarGanho`, `registrarPontuacao` e `registrarSorte`, sem mudar este serviço.
- Save: novo campo `poder = { pontos, total, nivel, fluxo, sorte }` no `Despertar_v1`. Perfis antigos ganham zero ao carregar e o normalizador corrige valores estranhos.

## Incursões desligadas

- Chave: `Config.IncursoesAtivas = false`.
- O servidor não inicia o serviço de Incursões: sem filas nem ações.
- A Mesa dos Cartógrafos só avisa que o Corredor dos Perdidos vem aí.
- O código continua no projeto.

## Painel Dev

Em **Incursões & recursos**, o botão **Definir Pontos de Aura** muda o saldo só na sessão de teste.

## Playtest sugerido

1. **Contador:** entrar, equipar uma aura e ver o contador do topo subir. O "+X/s" deve mudar quando você troca de aura.
2. **Evoluções:** abrir Evoluir pelo menu e pelo contador. Comprar cada evolução e conferir que o botão trava sem saldo.
3. **Sorte:** com a evolução Sorte comprada, abrir o Índice e ver a chance atual menor (mais fácil) que a base.
4. **Persistência:** sair e voltar. Os pontos e os níveis devem permanecer.
5. **Incursões:** a Mesa dos Cartógrafos não deve abrir as Incursões.
