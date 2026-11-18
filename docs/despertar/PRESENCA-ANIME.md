# Presença Anime — animação de personagem e reação do ambiente

## Objetivo
Uma **aura de anime não é apenas um emissor VFX**: modifica a postura do avatar, sua movimentação aparente e a forma como o mundo *parece* reagir ao poder. Isto é diferente das 67 auras originais, que podem usar VFX sem pose exclusiva.

## Fase 1 — Gear 5
- Parado, sustenta duas silhuetas e alterna entre elas suavemente. Na risada, a mão direita cobre a testa, a esquerda fica sobre o abdômen e uma perna fica mais alta. No repouso, as mãos vão atrás da cabeça, os cotovelos se abrem e o corpo reclina.
- Ao andar ou correr, usa uma passada própria com compressão do joelho, braços opostos e fase aérea. A cadência acompanha a velocidade real e a mistura com as poses paradas é gradual.
- A borracha aparece sob o pé de apoio no instante do contato e também no pouso de um salto real. Os quiques e o reclinar são visuais e preservam a física do jogador.
- A reação segue a superfície real por raycast e dura ~1 s, sem deixar peças no mapa. Jogadores próximos veem o mesmo estilo calculado localmente. O servidor continua autoritativo para gameplay.
- A pose usa `Transform` nas juntas `Motor6D` do R6/R15 e `AnimationConstraint` do R15 com Avatar Joint Upgrade. O ciclo procedural está no código.
- Não sobrepõe ataques e guarda das Incursões quando `Poses.ocupada(personagem)` está ativo.
- O cliente retira a pose anterior em `PreAnimation` e aplica o novo quadro em `PreSimulation`, após a avaliação do Animator.
- Primeira etapa **não** altera a física de Terrain, partes ancoradas nem o mapa compartilhado. São bolhas rasas e ondas locais representando a borracha, não uma deformação real da geometria.

## Acessibilidade e desempenho
- Distância da câmera: pose até 90 studs e efeito de chão até 85 studs.
- No máximo 14 marcas ativas por cliente, até duas Parts por marca, com autodestruição em ~1 s.
- `qualidadeBaixa`: elimina borda extra, desliga marcas dos passos; o pouso continua básico.
- `movimentoReduzido`: mantém uma pose mais leve, com quique vertical suavizado e sem marcas dos passos; a aterrissagem tem duração menor.
- `ocultarEfeitosAlheios`: não ativa a presença dos outros jogadores.
- Sem rede adicional, remotes ou DataStore; os efeitos são observados através de `AuraVfx` definido pelo servidor. A Gear 5 continua somente prévia dev enquanto não for integrada ao catálogo.

## Fase 2 planejada: borracha real nos objetos preparados
Criar props de cenário com atributo/tag de interação elástica, idealmente por **templates Blender/Studio importados**, e feedback local de compressão; apenas objetos expressamente marcados participam. Qualquer impulso, salto extra, rebote ou dano deve ser validado no servidor, com cooldown, limites e restauração. Nunca deformar Terrain global nem mover o chão de todo o Nexo a cada passo.

## Regra de identidade para outras auras anime
Cada uma receberá controladores de: pose idle, caminhada/corrida, salto, reação a pouso, entrada especial e campo ambiental. Exemplos futuros: Naruto — chakra e poeira/chão vibrando; Monarca — sombra se espalha sob os pés e soldados emergindo; Senbonzakura — pétalas cortando o vento e jardim de pétalas temporário.

## Playtest obrigatório no Studio
1. Ativar Gear 5 no Painel Dev / `Alt+G`. Ficar parado por pelo menos cinco segundos e conferir as duas silhuetas e a transição.
2. Testar R15 com Avatar Joint Upgrade e R6 em terceira pessoa e com dois jogadores. Desligar a aura e confirmar o retorno à pose padrão.
3. Andar devagar, correr, mudar de direção e soltar o controle. Conferir a passada saltitante, a onda no pé de apoio e a transição suave para a pose parada. Saltar e conferir a onda no pouso.
4. Iniciar Incursão e lançar combos/guarda: as poses de combate têm prioridade e retornam ao idle ao terminar.
5. Testar `qualidadeBaixa`, `movimentoReduzido`, ocultar efeitos dos outros e celulares.
6. Confirmar que não cria peças permanentemente e não interfere com o RNG, a economia ou o salvamento.

## Fase 1.5 — Haki do Rei da Gear 5
- **Malhas próprias do Blender** (`assets/gear5/source/generate_haki.py`): 3 raios em zigue-zague com galhos, onda de pressão serrilhada e rachadura em estrela.
- **Montagem em runtime** (`Gear5Haki.luau`, via MalhaNuvem): núcleo preto com casca vermelha neon. Sem EditableMesh, usa um bloco fino como reserva.
- **Sincronização com a animação parada** (`Gear5Movimento.hakiParado`). Os ciclos se alternam:
  - **faíscas:** no meio da pose de repouso, 4 raios curtos;
  - **estouro forte:** no auge da risada, ciclo sim, ciclo não. Tem 9 raios piscando em 3 quadros, silhueta escura com contorno vermelho, onda de pressão, rachadura e, para o dono da aura, a tela perde cor e treme.
- **Corrida:** faíscas a cada 8 pisadas.
- **Pouso de queda alta (< -30 studs/s):** estouro proporcional à queda (`hakiPouso`).
- **Limites:** no máximo 3 estouros ao mesmo tempo; tudo some sozinho em até cerca de 1,8 s; nada colide.
  - `qualidadeBaixa`: menos raios e sem rachadura.
  - `movimentoReduzido`: 1 quadro de raio e sem tremor de câmera.
- Não usa rede, remotes nem DataStore: cada cliente calcula a partir da pose.
- **Prévias:** `assets/gear5/previews/haki_rei.png` (Blender) e `haki_linha_do_tempo.png`.
