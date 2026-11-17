# Itens e Transcendência

Abra **Inventário** abaixo da aura equipada. O painel reúne materiais, artefatos e consumíveis em pilhas. Selecione um item para ver origem, uso e favoritos. Favoritos e ordem de obtenção recente duram pela sessão atual da interface.

O catálogo contém 16 entradas em sete raridades. O inventário é carregado pelo servidor no DataStore `Despertar_v1`. Fragmentos de Incursão continuam disponíveis na Mesa dos Cartógrafos para as quatro relíquias. A coleção de auras continua no Índice.

## Playtest do inventário

1. Abra o jogo no Studio com um perfil vazio e confirme que o Inventário mostra o estado inicial.
2. Confira botão, filtros, rolagem e fechamento com toque e controle. Gire uma aura com a janela fechada e confira que o Auto pausa enquanto ela estiver aberta.
3. Em ambiente de teste com um perfil antigo, anote giros, auras, fragmentos e relíquias. Saia e reconecte. Confirme os mesmos valores e o novo inventário vazio.

O primeiro PR habilita a tela e prepara o save. A obtenção de materiais entra no PR de loot.
