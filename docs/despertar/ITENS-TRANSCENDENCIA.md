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
