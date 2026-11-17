# Presença Anime — animação de personagem e reação do ambiente

## Objetivo
Uma **aura de anime não é apenas um emissor VFX**: modifica a postura do avatar, sua movimentação aparente e a forma como o mundo *parece* reagir ao poder. Isto é diferente das 67 auras originais, que podem usar VFX sem pose exclusiva.

## Fase 1 — Gear 5 (este PR)
- Silhueta de risada: tronco para trás, uma mão na cabeça, outro braço solto/aberto, pescoço inclinado, pernas em passos irregulares.
- *Idle* pulando de alegria: pequenas elevações **visuais** pelo Motor6D.Transform (não força o Humanoid a saltar, não muda velocidade, pulo nem colisão).
- Em deslocamento: balanço solto e marca de borracha nas passadas; no salto, postura aérea mais aberta; na aterrissagem, o chão **amassa, infla e volta** com ondas visuais.
- A reação segue a superfície real por raycast e dura ~1 s, sem deixar peças no mapa. Jogadores próximos veem o mesmo estilo calculado localmente. O servidor continua autoritativo para gameplay.
- Compatível com R6 e R15 (juntas encontradas por nome com FindFirstChild(..., true)).
- Não sobrepõe ataques e guarda das Incursões quando `Poses.ocupada(personagem)` está ativo.
- A pose é aplicada depois do Animator via `RunService.PreSimulation`; sem alterar C0/C1 permanentemente.
- Primeira etapa **não** altera a física de Terrain, partes ancoradas nem o mapa compartilhado. São bolhas rasas e ondas locais representando a borracha, não uma deformação real da geometria.

## Acessibilidade e desempenho
- Distância da câmera: pose até 90 studs e efeito de chão até 85 studs.
- No máximo 14 marcas ativas por cliente, até duas Parts por marca, com autodestruição em ~1 s.
- `qualidadeBaixa`: elimina borda extra, desliga marcas do idle/passos; o pouso continua básico.
- `movimentoReduzido`: minimiza o quique do corpo e elimina marcas de idle/passos; a aterrissagem tem duração menor.
- `ocultarEfeitosAlheios`: não ativa a presença dos outros jogadores.
- Sem rede adicional, remotes ou DataStore; os efeitos são observados através de `AuraVfx` definido pelo servidor. A Gear 5 continua somente prévia dev enquanto não for integrada ao catálogo.

## Fase 2 planejada: borracha real nos objetos preparados
Criar props de cenário com atributo/tag de interação elástica, idealmente por **templates Blender/Studio importados**, e feedback local de compressão; apenas objetos expressamente marcados participam. Qualquer impulso, salto extra, rebote ou dano deve ser validado no servidor, com cooldown, limites e restauração. Nunca deformar Terrain global nem mover o chão de todo o Nexo a cada passo.

## Regra de identidade para outras auras anime
Cada uma receberá controladores de: pose idle, caminhada/corrida, salto, reação a pouso, entrada especial e campo ambiental. Exemplos futuros: Naruto — chakra e poeira/chão vibrando; Monarca — sombra se espalha sob os pés e soldados emergindo; Senbonzakura — pétalas cortando o vento e jardim de pétalas temporário.

## Playtest obrigatório no Studio
1. Ativar Gear 5 no Painel Dev / `Alt+G`; observar pose característica parado, andando e pulando.
2. Testar R15 e R6, em câmera próxima, terceira pessoa e dois jogadores. Desligar a aura e verificar retorno ao padrão.
3. Saltar em pisos de materiais diferentes: onda coincide com o ponto de contato e some; chão e colisão permanecem intactos.
4. Iniciar Incursão e lançar combos/guarda: as poses de combate têm prioridade e retornam ao idle ao terminar.
5. Testar `qualidadeBaixa`, `movimentoReduzido`, ocultar efeitos dos outros e celulares.
6. Confirmar que não cria peças permanentemente e não interfere com o RNG, a economia ou o salvamento.
