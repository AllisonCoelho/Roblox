# DESPERTAR RNG — 67 AURAS ORIGINAIS

> **Direção de arte | Versão 1.0 | 17/11/2026 | Documento criativo para o Claude**
> Este documento substitui o *planejamento visual* das 30 auras originais atuais por **67 designs inteiramente novos**, mantendo as auras temáticas de anime em uma coleção/pipeline separado. **Não é confirmação de implementação nem de publicação.**

## 0. Regra fundamental

**São 67 auras distintas em silhueta, geometria, reação e personalidade.** Não produzir 67 variações de fumaça, aura circular, partículas genéricas ou um arco atrás das costas. Cada entrada tem um símbolo central reconhecível de 15–30 studs, uma hierarquia de formas 3D e uma assinatura temporal.

- **Arte original Despertar:** fantasia mística moderna, low-poly premium/anime estilizado, geometria esculpida em profundidade, contornos legíveis, acentos neon controlados e cor localizada; não colar personagens de obras existentes.
- **Base visual:** dummy Roblox fosco antracito, pose neutra, cenário azul-marinho escuro, silhueta 3/4. Uma imagem por aura; para aprovação final, gerar também frente/3/4/lateral/costas e vídeo do Roblox Studio.
- **Padrão de modelagem:** formas grandes > intermediárias > microdetalhes. Partículas **complementam** malhas — nunca substituem a forma principal. Frente e costas têm leitura distinta; o avatar jamais é completamente tapado.
- **Sistema futuro:** 67 auras originais no catálogo principal; coleção de animes independente, com sistema de obtenção/preços/riscos jurídicos definidos separadamente. **Não presumir que o RNG da coleção anime usa as mesmas chances.**
- **Acesso a modelos:** Blender `.blend` e `.fbx`/`.glb` exportado; importação Studio; templates `.rbxm`/`.rbxmx` para versionar e clonar via Rojo (conforme o novo pipeline). Evitar `EditableMesh` na etapa runtime quando a geometria já é estática.

## 1. Sistema de raridade preservado

Usar inicialmente os limiares já presentes em `src/shared/Dados/Auras.luau`: Comum ≥1, Incomum ≥10, Raro ≥100, Épico ≥1.000, Lendário ≥10.000, Mítico ≥100.000, Divino ≥1.000.000. Valores abaixo são **proposta de balanceamento**. A aura de reserva ocupa o intervalo restante, não tem chance fixa independente. Cada número é `1/N` **somente com sorte-base = 1** e o algoritmo corretamente ajustado.

| Raridade | Quantidade | Linguagem visual dominante |
|---|---:|---|
| Comum | 4 | Formas contidas, 1 motivo claro, microdestaque. |
| Incomum | 10 | 2–3 volumes, textura e física própria. |
| Raro | 15 | Silhuetas ornamentais mais largas e interação entre peças. |
| Épico | 15 | Elementos escultóricos com 2–4 estados visuais. |
| Lendário | 12 | Arquiteturas e criaturas espectrais, presença evidente. |
| Mítico | 7 | Escala enorme, realidade deformada, 1 forma memorável. |
| Divino | 4 | Cenário sobrenatural temporário, volume majestoso e contido em uso normal. |

**Validação matemática (sorte = 1):** soma das 66 probabilidades explícitas = `0.823367`; sobra para **Centelha do Nexo** = `0.176633` (aproximadamente **1 em 5.66**). Logo, a soma de probabilidades = 100% na configuração base. Não arredondar o valor de reserva antes do cálculo.

**Atenção ao bônus de sorte:** o algoritmo atual adiciona `sorte / chance` a todas as faixas. Se a soma ultrapassar 100%, a distribuição perde a probabilidade de reserva e altera as chances efetivas. Para produção, definir/testar a política de sorte antes de inserir as 67; não assumir linearidade ilimitada. Preservar transparência das probabilidades e equilíbrio do gameplay.

## 2. Catálogo criativo das 67 auras

### Legenda de cada ficha

`ID` = slug estável sugerido (não renomear após publicar). `Base` = chance 1 em N proposta (ou RESERVA). `Silhueta/3D` = geometria modelada (não só partículas). `Idle`, `Movimento`, `Manifestação` = comportamentos mínimos exigidos. Cada efeito tem de funcionar com avatar parado, andando, correndo e pulando, com interpolação própria.

### COMUM — 4 auras

#### 01. Centelha do Nexo
**ID:** `centelha_do_nexo` · **Chance-base:** reserva calculada · **Família:** Cristal · **Cores:** `#FFE6A0` + `#8F71FF`
- **Silhueta/3D:** Núcleo de losango dourado, três lascas orbitais assimétricas e um halo interrompido na cintura.
- **Repouso:** O losango gira devagar; cada lasca dá uma volta em um ritmo distinto.
- **Corrida/salto:** As lascas se alinham como uma flecha atrás do avatar. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** O núcleo se divide em seis fragmentos e se recompõe com estalo de luz. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 02. Musgo Luminoso
**ID:** `musgo_luminoso` · **Chance-base:** 1 em 5 · **Família:** Natureza · **Cores:** `#A1F5A6` + `#2A805B`
- **Silhueta/3D:** Pequenas raízes retorcidas emergindo dos pés, esporos em formato de estrela e dois brotos no ombro.
- **Repouso:** Brotos abrem e fecham em ondas; esporos flutuam.
- **Corrida/salto:** Raízes recuam para não prender a silhueta e deixam pó verde. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um anel de brotos floresce por um instante ao redor dos pés. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 03. Fagulha de Cobre
**ID:** `fagulha_de_cobre` · **Chance-base:** 1 em 7 · **Família:** Forja · **Cores:** `#FFB15E` + `#7A3F29`
- **Silhueta/3D:** Cacos de metal cobre em brasa, três filamentos curtos e faíscas de ponta quadrada.
- **Repouso:** Cacos estalam sem formar esfera simétrica.
- **Corrida/salto:** Os fragmentos se tornam um rastro de faíscas e voltam ao corpo. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um martelo espectral invisível provoca uma pancada luminosa nos cacos. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 04. Chuvisco de Vidro
**ID:** `chuvisco_de_vidro` · **Chance-base:** 1 em 9 · **Família:** Cristal · **Cores:** `#9BE9FF` + `#3970AB`
- **Silhueta/3D:** Cinco gotas alongadas de vidro azul translúcido, com cortes diagonais e pequenos prismas.
- **Repouso:** As gotas caem e sobem em movimento invertido.
- **Corrida/salto:** Os prismas se achatam em trilhos diagonais atrás do avatar. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma chuva vertical congelada no tempo se desfaz em reflexos. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

### INCOMUM — 10 auras

#### 05. Borboletas de Cinza
**ID:** `borboletas_de_cinza` · **Chance-base:** 1 em 12 · **Família:** Espírito · **Cores:** `#D4CDD6` + `#6B647C`
- **Silhueta/3D:** Três pares de asas recortadas como papel queimado, cinza em vez de partículas genéricas.
- **Repouso:** As mariposas pousam e voltam a voar junto aos ombros.
- **Corrida/salto:** Formam uma curva de voo assimétrica ao acompanhar o corpo. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma explosão de asas cinzentas revela pequenos olhos violetas. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 06. Gelo de Néon
**ID:** `gelo_de_neon` · **Chance-base:** 1 em 16 · **Família:** Geada · **Cores:** `#77F7FF` + `#1758D9`
- **Silhueta/3D:** Quatro prismas de gelo facetado suspensos nos lados e uma lasca alta atrás da cabeça.
- **Repouso:** Crescem microfraturas e recuperam a superfície.
- **Corrida/salto:** Os prismas inclinam suas pontas para o sentido do deslocamento. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma estrela de gelo de seis pontas cresce e implode. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 07. Maré de Quartzo
**ID:** `mare_de_quartzo` · **Chance-base:** 1 em 22 · **Família:** Oceano · **Cores:** `#7BD8E3` + `#D8FFFF`
- **Silhueta/3D:** Duas fitas de água cristalizada, conchas de quartzo e pequenas bolhas poliédricas.
- **Repouso:** As fitas sobem e descem como maré de águas rasas.
- **Corrida/salto:** A maré se prolonga como uma esteira espiral. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma onda em meia-lua rompe atrás do corpo sem cobri-lo. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 08. Raiz Cintilante
**ID:** `raiz_cintilante` · **Chance-base:** 1 em 30 · **Família:** Natureza · **Cores:** `#E3C66B` + `#58794D`
- **Silhueta/3D:** Cipós geométricos contornam as pernas e sementes âmbar flutuam em órbita baixa.
- **Repouso:** Sementes acendem em sequência, como pulsação natural.
- **Corrida/salto:** Os cipós dobram para trás com atraso elástico. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma pequena árvore de luz cresce e volta para a semente. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 09. Névoa de Amora
**ID:** `nevoa_de_amora` · **Chance-base:** 1 em 42 · **Família:** Bruma · **Cores:** `#E77BA7` + `#582A64`
- **Silhueta/3D:** Três massas de neblina arredondadas, com pequenos caroços brilhantes no interior.
- **Repouso:** Os volumes se misturam e se separam sem virar fumaça uniforme.
- **Corrida/salto:** A névoa afunila em fitas curtas atrás da cintura. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma nuvem se abre como flor de amora, revelando pontos de luz. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 10. Vento de Papel
**ID:** `vento_de_papel` · **Chance-base:** 1 em 55 · **Família:** Artefato · **Cores:** `#EAE5D9` + `#65ABBF`
- **Silhueta/3D:** Tiras de origami e três pequenos pássaros de papel dobrado.
- **Repouso:** Cada pássaro abre suas asas de papel em tempos distintos.
- **Corrida/salto:** Os pássaros planam na direção oposta à corrida. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** As tiras compõem um enorme pássaro de papel por um segundo. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 11. Pólen Lunar
**ID:** `polen_lunar` · **Chance-base:** 1 em 70 · **Família:** Floral · **Cores:** `#FBE9AB` + `#A2B2FA`
- **Silhueta/3D:** Fios de pólen em formas de gota e uma coroa de estames finos ao redor da nuca.
- **Repouso:** O pólen se move em órbitas suaves elípticas.
- **Corrida/salto:** Forma uma cauda de grãos que se desfaz rapidamente. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A coroa floresce em um disco lunar delicado. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 12. Engrenagem de Orvalho
**ID:** `engrenagem_de_orvalho` · **Chance-base:** 1 em 82 · **Família:** Mecânico · **Cores:** `#B6D7FF` + `#6B64C6`
- **Silhueta/3D:** Três engrenagens transparentes em alturas diferentes e gotas encaixadas nos dentes.
- **Repouso:** As rodas giram em sentidos contrários com pausas curtas.
- **Corrida/salto:** As engrenagens giram mais rápido e deixam dois rastros claros. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma engrenagem maior encaixa as três e as solta. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 13. Trilha de Vaga-Lumes
**ID:** `trilha_de_vaga_lumes` · **Chance-base:** 1 em 90 · **Família:** Espírito · **Cores:** `#FBF09A` + `#4A7A53`
- **Silhueta/3D:** Sete insetos-lanterna volumétricos com asas translúcidas e caudas pontuais.
- **Repouso:** Formam pequenas constelações breves, depois se dispersam.
- **Corrida/salto:** Uma trilha de pontos acompanha o corpo com atraso. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Os insetos desenham um pequeno símbolo luminoso no ar. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 14. Âmbar Vivo
**ID:** `ambar_vivo` · **Chance-base:** 1 em 95 · **Família:** Mineral · **Cores:** `#FFBE66` + `#7D3A20`
- **Silhueta/3D:** Placas de resina irregular flutuam como pétalas grossas; interior contém pequenas folhas presas.
- **Repouso:** Uma placa sobe enquanto outra desce como líquido espesso.
- **Corrida/salto:** A resina se alonga em gotas viscosas e retorna. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Todas as placas fundem-se em um casulo âmbar que se rompe. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

### RARO — 15 auras

#### 15. Coroa de Coral
**ID:** `coroa_de_coral` · **Chance-base:** 1 em 110 · **Família:** Oceano · **Cores:** `#FF8DAA` + `#42D4C6`
- **Silhueta/3D:** Galhos de coral flutuantes formam uma coroa aberta atrás dos ombros.
- **Repouso:** Ramos crescem lentamente a partir de suas pontas.
- **Corrida/salto:** Galhos retraem e liberam bolhas de ar coloridas. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um recife inteiro floresce numa silhueta radial por um instante. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 16. Relâmpago de Giz
**ID:** `relampago_de_giz` · **Chance-base:** 1 em 135 · **Família:** Tempestade · **Cores:** `#F4F7FF` + `#4C93FF`
- **Silhueta/3D:** Raios angulares grossos, de aparência desenhada a giz, com placas triangulares soltas.
- **Repouso:** Traços piscam em ordem irregular sem efeito estroboscópico.
- **Corrida/salto:** Uma linha elétrica se prolonga pelo chão atrás do jogador. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um hexágono quebrado de eletricidade se fecha e estoura. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 17. Prisma Partilhado
**ID:** `prisma_partilhado` · **Chance-base:** 1 em 160 · **Família:** Cristal · **Cores:** `#C4B6FF` + `#FBE09A`
- **Silhueta/3D:** Seis cunhas de cristal translúcido orbitam um centro vazio, cada uma com reflexo diferente.
- **Repouso:** Fragmentos trocam lentamente suas posições de profundidade.
- **Corrida/salto:** As cunhas se comprimem em formação de escudo posterior. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um feixe branco se fragmenta em seis raios coloridos. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 18. Jiboia de Fumaça
**ID:** `jiboia_de_fumaca` · **Chance-base:** 1 em 195 · **Família:** Bruma · **Cores:** `#7DD7B2` + `#2D696F`
- **Silhueta/3D:** Uma serpente sem rosto feita de três grandes volumes de fumaça verde torcidos.
- **Repouso:** O corpo ondula ao redor do avatar sem formar anel rígido.
- **Corrida/salto:** A cauda da névoa atrasa e se curva no caminho percorrido. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A serpente ergue um arco sobre o avatar e se dissipa. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 19. Fenda de Porcelana
**ID:** `fenda_de_porcelana` · **Chance-base:** 1 em 240 · **Família:** Artefato · **Cores:** `#F7F5EC` + `#2D3D69`
- **Silhueta/3D:** Cacos de porcelana branca rachada pairam em torno de ombro, braço e joelho, interior azul-escuro.
- **Repouso:** Fendas azuis pulsam como veias de esmalte cerâmico.
- **Corrida/salto:** Os cacos se fecham em uma linha inclinada e reabrem. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma máscara inteira de porcelana surge, racha e estilhaça. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 20. Pétalas de Ferrugem
**ID:** `petalas_de_ferrugem` · **Chance-base:** 1 em 300 · **Família:** Floral · **Cores:** `#E78952` + `#543D50`
- **Silhueta/3D:** Pétalas de ferro corroído com bordas cortantes e miolo escuro.
- **Repouso:** Pétalas orbitam em espirais interrompidas.
- **Corrida/salto:** Se alinham como lâminas inclinadas ao vento. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma flor metálica abre cinco camadas e vira tempestade. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 21. Sinos do Crepúsculo
**ID:** `sinos_do_crepusculo` · **Chance-base:** 1 em 360 · **Família:** Som · **Cores:** `#BCA2FF` + `#D5A66D`
- **Silhueta/3D:** Três sinos finos suspensos em alturas distintas, acompanhados de discos de onda.
- **Repouso:** Os sinos balançam em defasagem; ondas finas saem deles.
- **Corrida/salto:** Os discos de som são arrastados e desaparecem atrás. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Os três sinos tocam juntos e geram uma campânula translúcida. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 22. Esporos de Safira
**ID:** `esporos_de_safira` · **Chance-base:** 1 em 440 · **Família:** Natureza · **Cores:** `#53B3FF` + `#1D2758`
- **Silhueta/3D:** Chapéus de cogumelo de vidro azul, esporos cúbicos e uma raiz luminosa pequena.
- **Repouso:** Esporos escapam em pulsos curtos, como respiração.
- **Corrida/salto:** Cogumelos inclinam suas hastes ao vento do movimento. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma floresta miniatura espectral brota e se dissolve. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 23. Solstício de Areia
**ID:** `solsticio_de_areia` · **Chance-base:** 1 em 520 · **Família:** Deserto · **Cores:** `#FFD27A` + `#7A5583`
- **Silhueta/3D:** Lâminas de dunas flutuantes e relógio solar incompleto na lateral da cabeça.
- **Repouso:** Os grãos passam entre duas dunas suspensas.
- **Corrida/salto:** As dunas formam setas de areia apontando atrás do corpo. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um sol circular de areia vítrea emerge e se quebra. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 24. Marfim Flutuante
**ID:** `marfim_flutuante` · **Chance-base:** 1 em 600 · **Família:** Relíquia · **Cores:** `#F5E7CB` + `#876E93`
- **Silhueta/3D:** Quatro presas curvas de marfim, encaixes metálicos e pingentes finos.
- **Repouso:** Presas sobem e descem como marionetes leves.
- **Corrida/salto:** Uma formação protetora se fecha nas costas. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Duas presas cruzam atrás do personagem como portão antigo. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 25. Lótus de Gravidade
**ID:** `lotus_de_gravidade` · **Chance-base:** 1 em 680 · **Família:** Floral · **Cores:** `#9B83D9` + `#202036`
- **Silhueta/3D:** Uma flor de lótus de pedra escura invertida flutua acima da cabeça, pétalas abaixo.
- **Repouso:** As pétalas caem para cima e retornam ao miolo.
- **Corrida/salto:** Lótus inclina e as pétalas orbitam mais perto do tronco. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um campo gravitacional dobra as pétalas em um disco escuro. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 26. Espelho de Chuva
**ID:** `espelho_de_chuva` · **Chance-base:** 1 em 760 · **Família:** Reflexo · **Cores:** `#C8E7FF` + `#3A6787`
- **Silhueta/3D:** Quatro quadrados espelhados verticais guardam reflexos abstratos de gotas.
- **Repouso:** Gotas deslizam de baixo para cima dentro dos espelhos.
- **Corrida/salto:** Os painéis abrem caminho e deixam reflexos fantasma. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um espelho líquido enorme aparece atrás e se parte em ondas. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 27. Cápsula de Tempestade
**ID:** `capsula_de_tempestade` · **Chance-base:** 1 em 840 · **Família:** Tempestade · **Cores:** `#8AE8F5` + `#344B79`
- **Silhueta/3D:** Esfera vazada de metal com trovões confinados e três aros de sustentação.
- **Repouso:** Raios quicam pelo interior da cápsula.
- **Corrida/salto:** A esfera se estica em elipse e vibra com a velocidade. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A cápsula abre sua grade e libera um arco elétrico controlado. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 28. Cauda de Cometa
**ID:** `cauda_de_cometa` · **Chance-base:** 1 em 910 · **Família:** Cósmico · **Cores:** `#FF9A6A` + `#6C74EE`
- **Silhueta/3D:** Uma cauda curta de três faixas cometárias, com pequeno núcleo rochoso incandescente.
- **Repouso:** As faixas oscilam como bandeiras no espaço.
- **Corrida/salto:** A cauda estica e deixa fagulhas compactas atrás. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um cometa miniatura atravessa um arco e retorna ao núcleo. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 29. Prisma do Silêncio
**ID:** `prisma_do_silencio` · **Chance-base:** 1 em 970 · **Família:** Arcano · **Cores:** `#B7F7DD` + `#435870`
- **Silhueta/3D:** Um octaedro oco de vidro fosco suspenso no peito, com placas sonoras quietas.
- **Repouso:** A peça orbita sem emitir partículas e deforma reflexos.
- **Corrida/salto:** As placas giram para guardar a silhueta. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A luz da área parece se contrair num anel de silêncio mudo. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

### ÉPICO — 15 auras

#### 30. Arquivista Espectral
**ID:** `arquivista_espectral` · **Chance-base:** 1 em 1.200 · **Família:** Arcano · **Cores:** `#A1F4E7` + `#6359B1`
- **Silhueta/3D:** Três pergaminhos vivos, tinta suspensa e duas mãos caligráficas espectrais.
- **Repouso:** Páginas se folheiam com traços que se escrevem sozinhos.
- **Corrida/salto:** Os rolos se dobram e pairam como asas finas atrás. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma biblioteca de páginas se abre em arco e fecha. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 31. Jardim das Agulhas
**ID:** `jardim_das_agulhas` · **Chance-base:** 1 em 1.500 · **Família:** Floral · **Cores:** `#FF8AD7` + `#5E379A`
- **Silhueta/3D:** Flores de fio metálico com pétalas longas como agulhas, em múltiplas profundidades.
- **Repouso:** Hastes flexíveis traçam curvas em torno do corpo.
- **Corrida/salto:** As flores inclinam e soltam minúsculas agulhas de luz. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma coroa radial de agulhas desabrocha e volta a ser flor. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 32. Carrossel de Eclipses
**ID:** `carrossel_de_eclipses` · **Chance-base:** 1 em 1.900 · **Família:** Cósmico · **Cores:** `#E8B56E` + `#693A6B`
- **Silhueta/3D:** Três sóis eclipsados pequenos presos a órbitas inclinadas assimétricas.
- **Repouso:** Os eclipses giram e fazem sombras cruzarem o avatar.
- **Corrida/salto:** As órbitas se alinham brevemente em diagonal. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Os três eclipses se sobrepõem num único sol negro dourado. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 33. Coração de Basalto
**ID:** `coracao_de_basalto` · **Chance-base:** 1 em 2.500 · **Família:** Forja · **Cores:** `#FF684D` + `#4C4159`
- **Silhueta/3D:** Um coração de rocha rachada atrás do peito, veios de lava e pedras orbitais.
- **Repouso:** A pedra pulsa por fendas internas, sem bater como coração humano.
- **Corrida/salto:** Partículas de cinza seguem nos passos e somem. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** O coração se parte, expõe magma e se fecha novamente. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 34. Plumas de Mercúrio
**ID:** `plumas_de_mercurio` · **Chance-base:** 1 em 3.200 · **Família:** Metal · **Cores:** `#D7E7F0` + `#6E809B`
- **Silhueta/3D:** Duas asas incompletas compostas de penas líquidas prateadas, reflexos espelhados.
- **Repouso:** As penas trocam forma e comprimento como metal líquido.
- **Corrida/salto:** As asas afinam para cortar o vento sem bloquear a câmera. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** As asas se abrem em um semicírculo e chovem gotas metálicas. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 35. Valsa do Abismo
**ID:** `valsa_do_abismo` · **Chance-base:** 1 em 4.200 · **Família:** Abismo · **Cores:** `#8E75E5` + `#1D1638`
- **Silhueta/3D:** Duas fitas negras de veludo espacial, pequenas estrelas lilases presas nas bordas.
- **Repouso:** As fitas dançam em passos alternados ao redor do corpo.
- **Corrida/salto:** Formam hélices suaves, atrasando o giro do jogador. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um véu em espiral cobre as costas e se desfaz em estrelas. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 36. Navio de Papel Fantasma
**ID:** `navio_de_papel_fantasma` · **Chance-base:** 1 em 5.500 · **Família:** Relíquia · **Cores:** `#ECE7D1` + `#3D88A5`
- **Silhueta/3D:** Três barcos de origami espectral com velas translucentes flutuam em água suspensa.
- **Repouso:** Os barcos balançam em ondas aéreas desencontradas.
- **Corrida/salto:** A água deixa um arco ondulado logo atrás do jogador. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um navio espectral maior surge por trás em miniatura e some. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 37. Duas Luas Partidas
**ID:** `duas_luas_partidas` · **Chance-base:** 1 em 6.500 · **Família:** Cósmico · **Cores:** `#E7EAFF` + `#7A69B8`
- **Silhueta/3D:** Dois enormes crescentes quebrados, um alto à esquerda e outro baixo à direita.
- **Repouso:** As luas giram lentamente em planos separados.
- **Corrida/salto:** As metades mudam de inclinação para se afastar da frente. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** As peças quase se encaixam e uma fenda estelar aparece. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 38. Correntes do Vazio
**ID:** `correntes_do_vazio` · **Chance-base:** 1 em 7.000 · **Família:** Abismo · **Cores:** `#6FA0C3` + `#1A1539`
- **Silhueta/3D:** Seis correntes negras flutuam presas a um núcleo de sombra atrás da cintura.
- **Repouso:** As correntes serpenteiam como se estivessem na água.
- **Corrida/salto:** Os elos esticam e batem entre si com atraso. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** As correntes trançam uma prisão circular e a abrem. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 39. Catedral de Sal
**ID:** `catedral_de_sal` · **Chance-base:** 1 em 7.500 · **Família:** Relíquia · **Cores:** `#F7F5E5` + `#7BDDE8`
- **Silhueta/3D:** Arcos góticos de cristal de sal formam costelas arquitetônicas às costas.
- **Repouso:** Pequenos cristais brotam nos arcos e derretem.
- **Corrida/salto:** Os arcos fecham o ângulo para manter a leitura do corpo. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma cúpula de sal aparece como silhueta por um instante. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 40. Círculo dos Predadores
**ID:** `circulo_dos_predadores` · **Chance-base:** 1 em 8.000 · **Família:** Fera · **Cores:** `#FFB38A` + `#6D263B`
- **Silhueta/3D:** Quatro pegadas fantasmas de grandes garras giram no ar em posições diagonais.
- **Repouso:** As marcas surgem e desaparecem como caçadores invisíveis.
- **Corrida/salto:** Três arranhões luminosos ficam brevemente no ar atrás. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um conjunto de garras gigantes rasga uma superfície imaginária. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 41. Jardim Invertido
**ID:** `jardim_invertido` · **Chance-base:** 1 em 8.500 · **Família:** Natureza · **Cores:** `#87F3CE` + `#3B4B9E`
- **Silhueta/3D:** Raízes e flores pendem do vazio acima do personagem como jardim de teto.
- **Repouso:** Flores se abrem apontando para baixo, folhas flutuam para cima.
- **Corrida/salto:** O jardim pende e balança contra o impulso da corrida. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma chuva invertida de flores sobe até uma árvore invertida. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 42. Guardião da Ampulheta
**ID:** `guardiao_da_ampulheta` · **Chance-base:** 1 em 9.000 · **Família:** Temporal · **Cores:** `#E6C681` + `#7E5E6F`
- **Silhueta/3D:** Ampulheta grande fragmentada atrás do avatar, areia suspensa entre duas pontas.
- **Repouso:** A areia sobe e desce sem esgotar, vidro girando devagar.
- **Corrida/salto:** Os grãos se alinham em trilhas paralelas. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A ampulheta vira de cabeça para baixo e para o tempo por um piscar. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 43. Maré de Vidro Negro
**ID:** `mare_de_vidro_negro` · **Chance-base:** 1 em 9.500 · **Família:** Oceano · **Cores:** `#7695CA` + `#080F28`
- **Silhueta/3D:** Duas ondas negras espelhadas e dentadas se erguem atrás das pernas.
- **Repouso:** Cristas refletem céu inexistente em cortes opacos.
- **Corrida/salto:** A crista se deita formando um rastro de vidro líquido. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma parede rasa de onda negra quebra em lascas. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 44. Sussurro das Máscaras
**ID:** `sussurro_das_mascaras` · **Chance-base:** 1 em 9.900 · **Família:** Espírito · **Cores:** `#D6C7FF` + `#663763`
- **Silhueta/3D:** Cinco máscaras de madeira flutuantes com expressões abstratas e fita de tecido.
- **Repouso:** Máscaras trocam lentamente suas faces para dentro e fora.
- **Corrida/salto:** Se ordenam em fila fugidia atrás dos ombros. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Todas encaram o observador ao mesmo tempo e se desfazem. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

### LENDÁRIO — 12 auras

#### 45. Arquiduque de Cinzas
**ID:** `arquiduque_de_cinzas` · **Chance-base:** 1 em 12.000 · **Família:** Fênix · **Cores:** `#FF8F69` + `#4A3442`
- **Silhueta/3D:** Capa de penas de cinza geométricas, brasas escuras e um broche de carvão dourado.
- **Repouso:** As penas tremem como fogo que não aquece.
- **Corrida/salto:** A capa flutua e derrama carvão em vez de tecido. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A capa se abre como asas de cinza e fecha em punhado. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 46. Aurora do Mar Profundo
**ID:** `aurora_do_mar_profundo` · **Chance-base:** 1 em 16.000 · **Família:** Oceano · **Cores:** `#8DE9F5` + `#735AF0`
- **Silhueta/3D:** Umbrela de água-viva colossal translúcida atrás da cabeça, seis tentáculos de luz suaves.
- **Repouso:** A umbrela respira como criatura de profundidade.
- **Corrida/salto:** Os tentáculos recuam e deixam cintilações azuis. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma aurora oceânica em forma de medusa ilumina o entorno. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 47. Imperatriz de Porcelana
**ID:** `imperatriz_de_porcelana` · **Chance-base:** 1 em 21.000 · **Família:** Relíquia · **Cores:** `#FFE3EF` + `#465A9E`
- **Silhueta/3D:** Leque real de porcelana com fissuras rosas, máscara cerimonial e cacos flutuantes.
- **Repouso:** As placas do leque abrem em sequências sutis.
- **Corrida/salto:** O leque fecha em feixes finos, sem ocupar a tela. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um trono de pratos de porcelana floresce atrás e se quebra. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 48. Trono de Raios
**ID:** `trono_de_raios` · **Chance-base:** 1 em 26.000 · **Família:** Tempestade · **Cores:** `#F9D47A` + `#6A55A6`
- **Silhueta/3D:** Estrutura de trono vazio feita de quatro relâmpagos rígidos e aro de metal quebrado.
- **Repouso:** Cargas saltam entre braços invisíveis do trono.
- **Corrida/salto:** O trono desmancha em faixas e acompanha a corrida. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** O trono se materializa completo por 1 segundo, com trovão seco. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 49. Relicário do Inverno
**ID:** `relicario_do_inverno` · **Chance-base:** 1 em 33.000 · **Família:** Geada · **Cores:** `#DCF7FF` + `#7591D0`
- **Silhueta/3D:** Um altar suspenso minúsculo em arco de gelo, sinos congelados e estilhaços.
- **Repouso:** Gotas congeladas circulam o relicário em órbita.
- **Corrida/salto:** Cristais pequenos voam em formação afiada atrás. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um templo de gelo translúcido se abre e desaba em flocos. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 50. Coração de Fênix
**ID:** `coracao_de_fenix` · **Chance-base:** 1 em 42.000 · **Família:** Fênix · **Cores:** `#FFD46A` + `#E74747`
- **Silhueta/3D:** Pássaro de fogo formado por costelas douradas e grandes penas triangulares atrás do torso.
- **Repouso:** O pássaro dobra as asas com calor pulsante no peito.
- **Corrida/salto:** As penas formam rastro de chamas pequenas na corrida. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A ave abre as asas, vira cinza e renasce do núcleo. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 51. Atlas Fragmentado
**ID:** `atlas_fragmentado` · **Chance-base:** 1 em 51.000 · **Família:** Cósmico · **Cores:** `#9EC5FB` + `#8AD69C`
- **Silhueta/3D:** Ilhas de um mapa-múndi partido flutuam em camadas, rios e mini montanhas de cristal.
- **Repouso:** Continentes giram em órbitas sem nunca se encaixar.
- **Corrida/salto:** Os fragmentos orbitam mais perto do eixo do corpo. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um globo completo emerge e se despedaça em ilhas. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 52. Serpente de Cristal
**ID:** `serpente_de_cristal` · **Chance-base:** 1 em 60.000 · **Família:** Fera · **Cores:** `#88F2EB` + `#547FCB`
- **Silhueta/3D:** Serpente gigantesca composta por vértebras prismáticas suspensas, olhos de vidro turquesa.
- **Repouso:** O corpo passa por trás do avatar em S volumétrico.
- **Corrida/salto:** As vértebras se alinham e arrastam a cauda em atraso. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A cabeça cruza o alto e abre uma mandala cristalina. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 53. Horizonte Rasgado
**ID:** `horizonte_rasgado` · **Chance-base:** 1 em 70.000 · **Família:** Fenda · **Cores:** `#FF729F` + `#24103F`
- **Silhueta/3D:** Uma grande ferida retangular no ar, bordas desconectadas e interior de crepúsculo impossível.
- **Repouso:** A fenda se expande e contrai fora do eixo do avatar.
- **Corrida/salto:** O corte se dobra como uma bandeira de outra dimensão. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma segunda linha de horizonte surge dentro da fenda e explode. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 54. Arauto dos Mil Sinos
**ID:** `arauto_dos_mil_sinos` · **Chance-base:** 1 em 80.000 · **Família:** Som · **Cores:** `#FDE7A1` + `#8760AD`
- **Silhueta/3D:** Halo metálico com sinos de várias formas e correntes de fios dourados.
- **Repouso:** Os sinos tocam uma sequência visual de ondas em notas.
- **Corrida/salto:** O halo se inclina mantendo os sinos em órbita suave. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Um campanário circular de som aparece acima do corpo. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 55. Orquestra das Estrelas
**ID:** `orquestra_das_estrelas` · **Chance-base:** 1 em 90.000 · **Família:** Cósmico · **Cores:** `#B7A5FF` + `#FFC2EC`
- **Silhueta/3D:** Cordas de harpa de constelação e notas estelares orbitando em arcos vazados.
- **Repouso:** As notas percorrem as cordas gerando ondas brilhantes.
- **Corrida/salto:** Cordas se esticam e vibram como música do deslocamento. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma partitura astral inteira se acende em cinco acordes. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 56. Majestade de Cobre
**ID:** `majestade_de_cobre` · **Chance-base:** 1 em 99.000 · **Família:** Mecânico · **Cores:** `#FFCA80` + `#854F50`
- **Silhueta/3D:** Cabeça de leão mecânico em cobre atrás da nuca, crina de lâminas engrenadas e relógio no peito.
- **Repouso:** A crina abre e fecha como mecanismo respirando.
- **Corrida/salto:** A juba vira um rastro de lâminas articuladas. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** O leão ergue a cabeça e ruge em ondas de engrenagens. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

### MÍTICO — 7 auras

#### 57. Devorador de Alvoradas
**ID:** `devorador_de_alvoradas` · **Chance-base:** 1 em 130.000 · **Família:** Abismo · **Cores:** `#FFAD4D` + `#150F29`
- **Silhueta/3D:** Sol negro semicoberto por mandíbulas de pedra e um anel de brasas douradas.
- **Repouso:** O eclipse parece mastigar a luz ao redor.
- **Corrida/salto:** Os dentes orbitais retraem para perto da nuca. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Mandíbulas do eclipse se fecham e deixam uma coroa solar escura. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 58. Coroa do Fim
**ID:** `coroa_do_fim` · **Chance-base:** 1 em 190.000 · **Família:** Soberano · **Cores:** `#CCA7FF` + `#131023`
- **Silhueta/3D:** Coroa colossal de cinco pontas desconectadas e espinhos negros em profundidade.
- **Repouso:** Cada ponta gira em eixo isolado, sem união rígida.
- **Corrida/salto:** Pontas se alinham atrás e puxam uma sombra em véu. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A coroa desce sobre um rei espectral vazio e retorna ao ar. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 59. Oceano Sem Fundo
**ID:** `oceano_sem_fundo` · **Chance-base:** 1 em 260.000 · **Família:** Oceano · **Cores:** `#39B6E6` + `#071427`
- **Silhueta/3D:** Janela vertical de mar abissal com queda d’água invertida, peixes luminosos como constelações.
- **Repouso:** Correntes descem para cima dentro da janela.
- **Corrida/salto:** A janela afina como um rasgo e deixa espuma azul. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Uma onda invisível revela criaturas gigantes nas profundezas. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 60. Fio das Parcas
**ID:** `fio_das_parcas` · **Chance-base:** 1 em 350.000 · **Família:** Temporal · **Cores:** `#FFE8EF` + `#C63B66`
- **Silhueta/3D:** Tear triangular fantasma acima dos ombros com linhas vermelho-brancas tecendo símbolos.
- **Repouso:** Linhas se entrelaçam e desfazem a cada batida.
- **Corrida/salto:** O tear faz fio contínuo que se rompe com a velocidade. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Fios desenham uma tapeçaria brilhante do destino e somem. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 61. Leviatã Astral
**ID:** `leviata_astral` · **Chance-base:** 1 em 480.000 · **Família:** Fera · **Cores:** `#7CB4F4` + `#A274E7`
- **Silhueta/3D:** Baleia cósmica translúcida com barbatanas enormes cruza por trás do jogador em arco 3D.
- **Repouso:** A criatura nada lentamente no vazio, exibindo estrelas internas.
- **Corrida/salto:** A barbatana se recolhe e deixa um rastro cósmico. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** O leviatã emerge em corpo quase inteiro sobre a cabeça e mergulha. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 62. Labirinto Vivo
**ID:** `labirinto_vivo` · **Chance-base:** 1 em 650.000 · **Família:** Temporal · **Cores:** `#F2E0B9` + `#7874AE`
- **Silhueta/3D:** Escadas impossíveis e arcos de pedra girando em perspectiva ao redor de um cubo oco.
- **Repouso:** Degraus mudam de ordem sem se desconectar.
- **Corrida/salto:** O labirinto se dobra em forma compacta atrás do corpo. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** O conjunto revela uma escada infinita vertical por um instante. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 63. Eclipse de Mil Olhos
**ID:** `eclipse_de_mil_olhos` · **Chance-base:** 1 em 900.000 · **Família:** Abismo · **Cores:** `#FF7BB9` + `#15122E`
- **Silhueta/3D:** Eclipse roxo com grande olho central e seis olhos menores em anéis não circulares.
- **Repouso:** As pupilas acompanham direções diferentes, piscando com parcimônia.
- **Corrida/salto:** As órbitas se fecham e os olhos miram a frente. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Todos os olhos se abrem e o eclipse parece olhar o servidor. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

### DIVINO — 4 auras

#### 64. Alvorecer dos Titãs
**ID:** `alvorecer_dos_titas` · **Chance-base:** 1 em 1.200.000 · **Família:** Soberano · **Cores:** `#FFE1A8` + `#8B8DE8`
- **Silhueta/3D:** Duas enormes mãos de mármore luminoso flutuam às costas, halo solar fragmentado no alto.
- **Repouso:** Dedos se movem sutilmente como mãos de estátua acordando.
- **Corrida/salto:** As mãos protegem os ombros e seguem atrás do passo. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** Mãos se erguem como portões de uma civilização colossal. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 65. Divindade do Prisma
**ID:** `divindade_do_prisma` · **Chance-base:** 1 em 5.000.000 · **Família:** Cristal · **Cores:** `#E8F6FF` + `#D89FFF`
- **Silhueta/3D:** Catedral flutuante de cristal prismático e um núcleo hexagonal transparente com luz multicolorida.
- **Repouso:** Raios refratados deslizam entre as facetas inclinadas.
- **Corrida/salto:** As estruturas colapsam em um cometa facetado. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A catedral abre cinco grandes pétalas arquitetônicas de luz. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 66. Último Jardim
**ID:** `ultimo_jardim` · **Chance-base:** 1 em 20.000.000 · **Família:** Natureza · **Cores:** `#D0FFDA` + `#F8B1F1`
- **Silhueta/3D:** Árvore cósmica com tronco de ouro pálido, raízes de nebulosa e flores de galáxia às costas.
- **Repouso:** As flores se abrem uma a uma e liberam pequenas estrelas.
- **Corrida/salto:** Os galhos se contraem formando um estandarte atrás. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** A árvore floresce em uma aurora estrelada que envolve o céu local. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

#### 67. Soberania do Vazio
**ID:** `soberania_do_vazio` · **Chance-base:** 1 em 100.000.000 · **Família:** Soberano · **Cores:** `#F4F3FF` + `#160B26`
- **Silhueta/3D:** Coroa branca de espaço negativo cercada de monólitos negros flutuantes e um vazio em forma de estrela atrás.
- **Repouso:** Os monólitos giram silenciosamente sem emitir partículas comuns.
- **Corrida/salto:** Todo o conjunto se organiza numa lança de ausência de luz. No salto, a geometria reage à velocidade vertical e retorna com amortecimento.
- **Manifestação especial:** O espaço se abre em seis planos e uma coroa branca domina o horizonte. Duração sugerida 1,0–1,8 s; não causar dano nem alterar chances nesta fase.

## 3. Linguagem visual global

### 3.1 Leitura em três distâncias

- **2–20 studs:** geometria grande, microefeitos, contorno discreto e detalhes facetados; efeitos de brilho moderados.
- **20–80 studs:** silhueta principal + cerca de 30–50% dos volumes secundários; reduzir partículas; manter identidade.
- **80–140 studs:** silhueta ou cluster simplificado, 10 Hz se houver movimento; efeitos pesados desativados.
- **>140 studs:** culling local de detalhes distantes conforme orçamento de desempenho, reutilizando regras dos controladores existentes.

### 3.2 Geometria e performance

- Orçamento inicial por aura **para protótipo**, não limite rígido da plataforma: Comum/Incomum até ~1k–2k triângulos visíveis; Raro/Épico até ~3k–5k; Lendário/Mítico até ~5k–10k; Divino até ~12k, com LOD. **Medir FPS/memória em celular e ajustar pelos resultados reais.**
- Evitar 100 `MeshPart` independentes e centenas de luzes por jogador. Repetir a mesma malha por instância quando necessário, em grupos limitados; VFX de massa devem usar partículas ou composição inteligente de malhas.
- **Sem física nem colisão** em todas as partes cosméticas (`CanCollide/CanTouch/CanQuery = false`, `CastShadow = false` para microefeitos). Sem replicar centenas de transformações por frame.
- `R6` e `R15`, diferentes alturas; escala proporcional ao avatar, limite de amplitude da câmera e modo primeira pessoa.
- Acessibilidade: respeitar `qualidadeBaixa`, `movimentoReduzido`, `ocultarEfeitosAlheios`; sem flashes agressivos nem distorções que cubram toda a tela de terceiros.

### 3.3 Ciclo de animação sugerido

1. **Manifestar (0,8–1,6 s):** o símbolo nasce junto ao corpo, volumes externos aparecem em sequência, um breve pico apresenta a assinatura. Chamada quando efetivamente equipado; não repetir a cada respawn sem intenção.
2. **Idle:** componente maior respira em 4–10 s; volumes secundários oscilam em 2–6 s; fases desencontradas; sem rotação constante de toda a aura.
3. **Andar/correr:** física falsa por molas/inércia; o desenho fica alongado no sentido oposto ao deslocamento, sem virar hélice rígida.
4. **Pular/cair/pousar:** suspensões relativas ao `HumanoidRootPart`, deformações e recuperação amortecida; efeitos em chão usam raycast e não sobem junto ao avatar.
5. **Burst ambiente eventual:** 1,0–1,8 s, de tempos variados (ex.: 12–20 s); não interrompe combate/controle e pode ser desabilitado em `qualidadeBaixa`.
6. **Desequipar/morrer:** fade ≤0,3 s, `Destroy`, desconectar observadores, nenhuma órfã na Workspace.

## 4. Fluxo Blender → Studio → Rojo para as 67

```text
assets/auras/originais/
  <aura_id>/
    source/<aura_id>.blend
    source/generate_<aura_id>.py      # opcional: autoria automatizada pelo Claude
    exports/<aura_id>_*.fbx
    previews/front.png
    previews/three_quarter.png
    previews/side.png
    previews/back.png
    README.md
src/client/Mundo/Auras/Originais/
  <Aura>.luau
  ...
assets/roblox/auras_originais/
  <aura_id>.rbxm                  # template IMPORTADO pelo proprietário; integrar no projeto Rojo
```

**Importante:** não tentar criar `MeshPart` em tempo de execução atribuindo `MeshId` via Luau — criar/clonar **templates já importados**. A arquitetura compartilhada existente usa `AuraVfx`, `AuraVfxEm`, `AurasVfx.luau` e `Controlador.luau`; conservar servidor autoritativo sobre posse/equipamento. Os modelos `.rbxm` precisam ser referenciados corretamente no Rojo e verificados no Studio e no jogo publicado.

**Arte de produção:** uma malha ou um pequeno grupo por motivo visual principal; pivôs claros, nomes estáveis, sem ossos supérfluos. Rig com Bones somente para deformações contínuas; demais partes em Lua e instâncias clonadas. Material Neon apenas nos núcleos e acentos, não em 100% da aura.

## 5. Substituição das 30 atuais sem quebrar dados

- **Não trocar IDs antigos em produção sem plano de migração**; verificar existência de dados dos testadores e de dados já publicados. O jogo tem coleção, equip e melhor aura dependentes do catálogo. Criar uma migração explícita ou conversão/compensação compatível.
- Criar um catálogo separado `AurasOriginaisV2` primeiro, com asserts de IDs únicos, contagens e soma das probabilidades; testar exaustivamente o RNG.
- Somente depois da aprovação artística e técnica da coleção, decidir a substituição de `DEFINICOES` em `src/shared/Dados/Auras.luau` e como manter IDs previamente obtidos.
- Auras de anime ficam **fora da contagem de 67**, com identificação e regras próprias; não misturar com fallback de probabilidade sem revisar distribuição. Não presumir licenças de marcas/personagens; revisar aspectos de propriedade intelectual antes da monetização.
- Conferir se `tierDe`, exibição de `1/N`, sorte aumentada e anúncios globais continuam consistentes após mudança.

## 6. Aprovação por gates de qualidade

**Gate A — Silhueta:** render 3/4 com dummy cinza. O avaliador consegue reconhecer a aura sem ler o nome? Se não, refazer geometria.

**Gate B — Volumetria:** quatro imagens ortogonais (frente, 3/4, lateral e costas), mesma escala. Não aceitar VFX plano, aro rígido inexplicado ou elementos atravessando o corpo.

**Gate C — Movimento:** vídeo de 20–30 s no Studio, idle → caminhada → corrida → salto → burst → desequipar. Nada fica preso no mundo ou invade a câmera.

**Gate D — Mobile:** qualidade reduzida mantém silhueta principal, FPS e memória avaliados com múltiplas auras simultâneas.

**Gate E — Gameplay:** chance-base correta, estado salvo e aura equipável apenas quando concedida; prévia do dev separada de posse real.

## 7. Organização do concept art

As pranchas de imagens acompanham o documento na pasta `concepts/`. A ordem é a ordem das fichas. **Os conceitos são direção artística para modelagem, não arquivos prontos para Roblox.** Claude deve respeitar as fichas acima se uma imagem gerada divergir da silhueta explicitamente especificada.

## 8. Ordem de fabricação sugerida

1. **Lote inicial (7):** Centelha do Nexo, Gelo de Néon, Prisma Partilhado, Arquivista Espectral, Coração de Fênix, Leviatã Astral, Soberania do Vazio — testa sete famílias visuais diferentes.
2. **Lote de acesso (14):** completar as 4 Comuns e 10 Incomuns; devem estar prontas primeiro para o começo do jogo.
3. **Lotes por raridade:** Raros → Épicos → Lendários → Míticos → Divinos, sempre com medições de performance.
4. **Lançamento:** não anunciar 67 como plenamente implementadas antes de ter os 67 VFX importados, testados e integrados. Pode haver 67 entradas catalogadas e menos visuais prontos durante o desenvolvimento, mas na versão pública comunicar o que realmente existe.

---
**Princípio estético do Despertar:** cada aura conta uma história visual em 1 segundo, mantém uma personalidade em 10 segundos e entrega um momento memorável no burst.
