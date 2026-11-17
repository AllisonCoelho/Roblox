# Itens e Transcendência

Abra **Inventário** abaixo da aura equipada. O painel reúne materiais, artefatos e consumíveis em pilhas. Selecione um item para ver origem, uso e favoritos. Favoritos e ordem de obtenção recente duram pela sessão atual da interface.

O catálogo contém 16 entradas em sete raridades. O inventário é carregado pelo servidor no DataStore `Despertar_v1`. Fragmentos de Incursão continuam disponíveis na Mesa dos Cartógrafos para as quatro relíquias. A coleção de auras continua no Índice.

## Playtest do inventário

1. Abra o jogo no Studio com um perfil vazio e confirme que o Inventário mostra o estado inicial.
2. Confira botão, filtros, rolagem e fechamento com toque e controle. Gire uma aura com a janela fechada e confira que o Auto pausa enquanto ela estiver aberta.
3. Em ambiente de teste com um perfil antigo, anote giros, auras, fragmentos e relíquias. Saia e reconecte. Confirme os mesmos valores e o novo inventário vazio.

O primeiro PR habilita a tela e prepara o save. A obtenção de materiais entra no PR de loot.

## Andares e Guardiões

| Marco | Drops de itens |
|---|---|
| Cada andar concluído | 3 Estilhaços Brutos e 1 material do bioma nos andares 1–2 ou 2 nos andares 3–5 |
| Andar 1 | 1 Selo de Purificação |
| Andares 2 e 4 | 1 Lasca Estável |
| Andares 4 e 5 | 1 Fragmento Instável |
| Guardião | 1 marca do Guardião garantida, 10% de uma marca adicional e 3% de um Coração da Fenda |

Cinzas entrega Cinza Persistente e Brasa do Arauto. Maré Morta entrega Sal da Maré Morta e Pérola Abissal. Umbral entrega Pó do Ocaso e Véu do Ocaso. As chances de bônus rodam separadamente por jogador no servidor.

Os Fragmentos de Incursão mantêm os valores anteriores e passam a ser creditados junto aos materiais. A vitória mantém o bônus e o adicional de primeira vitória. O cartão final soma os créditos daquela partida. Os itens de andares concluídos ficam no inventário ao sair, morrer sem vidas ou desconectar.

### Playtest do loot

- Jogue Cinzas solo e em grupo de 2–4. Confira em cada andar os ganhos individuais e compare o saldo com o cartão final.
- Saia e reconecte após o primeiro andar. Confirme as recompensas e repita com morte e desconexão perto da purificação.
- Vença o Guardião e valide o drop temático e os Fragmentos de Incursão. Repita com uma partida do Painel Dev e compare com o perfil real após sair da simulação.

## Forja e Transcendência I

Abra o **Altar da Ressonância**, a nordeste da praça. A aba **Forja** mostra o estoque ao lado de cada custo e pede confirmação antes de consumir materiais.

| Receita | Ingredientes |
|---|---|
| Lasca Estável | 5 Estilhaços Brutos |
| Coração da Fenda | 8 Estilhaços Brutos, 2 Lascas Estáveis e 1 Selo de Purificação |
| Coração da Ressonância | 1 Coração da Fenda, 6 Estilhaços Brutos e 1 Cinza Persistente |

Uma vitória em Cinzas garante os materiais do primeiro ciclo. As Lascas Estáveis vêm dos andares 2 e 4, então a forja de Lascas é opcional. Na aba **Transcender**, ofereça um Coração da Ressonância para ganhar o primeiro nível sem perder auras, giros ou relíquias. A confirmação visual aparece depois da confirmação dos dados.

### Regra de sorte proposta para o playtest

A Transcendência I multiplica por **1,05** a probabilidade base das auras Raras, Épicas, Lendárias, Míticas e Divinas. O peso adicional sai proporcionalmente das auras Comuns e Incomuns, incluindo a reserva. No nível 0, o catálogo mantém suas probabilidades base. O Índice, a aura equipada e os resultados mostram o denominador efetivo arredondado. A raridade nominal, o critério para anúncios e a duração dos rituais continuam definidos no catálogo.

O catálogo das 67 auras originais está em um PR próprio. Sua entrada no sorteio e a chance base da Centelha do Nexo ainda requerem decisão e validação separada.

### Playtest do Altar

- Conclua Cinzas. No Altar, fabrique Coração da Fenda e Coração da Ressonância. Confirme os ingredientes descontados e o item recebido no Inventário.
- Tente confirmar duas vezes, forjar sem ingredientes, oferecer sem Coração e interagir longe do Altar. Confira que as recusas preservam o saldo.
- Transcenda e confira nível, bônus, Índice e resultado do giro. Pule a apresentação e confira o modo Movimento reduzido. Reconecte em ambiente de teste publicado e confirme o nível e os saldos.
- Teste conexão instável e encerre a sessão durante uma oferta. Ao retornar, os ingredientes e o resultado devem corresponder à gravação recuperada.

## Artefatos e níveis seguintes

Fabrique os artefatos no Altar. Em **Inventário → Artefatos**, selecione a peça e equipe. O perfil tem um slot. A troca fica disponível fora de partidas e fora da fila.

| Artefato | Receita | Efeito |
|---|---|---|
| Emblema do Guardião | 1 Coração da Fenda, 2 Brasas do Arauto e 2 Selos de Purificação | +10% de vida máxima na incursão, incluindo reviver durante a partida |
| Lâmina do Nexo | 2 Corações da Fenda, 1 Brasa do Arauto, 1 Pérola Abissal, 1 Véu do Ocaso e 6 Fragmentos Instáveis | Visual nas costas, disponível a até 80 studs. A qualidade baixa oculta o visual |

O Altar mostra os custos exatos da próxima oferta. As ofertas II–III usam marcas de Cinzas, IV–VI usam Maré Morta e VII–X incluem Umbral. O bônus relativo para auras Raras ou superiores soma cinco pontos percentuais por nível até +50% no nível X. Essência Primordial e Semente do Absoluto aguardam fontes futuras.

### Playtest da expansão

- Equipe o Emblema, confira a vida em uma incursão, morra e confira o mesmo teto ao reviver. Ao voltar, confira a vida do Nexo.
- Fabrique e equipe a Lâmina. Confira o visual em dois clientes, à distância, ao trocar a peça, ao renascer e com Qualidade baixa.
- Reconecte com um artefato equipado. Confirme o slot e tente gastar uma oferta incompleta sem perder nenhum item.
