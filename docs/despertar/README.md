# Despertar — escopo da primeira versão

Estética **anime original**: proibir nomes, personagens, técnicas e marcas de obras existentes.

## Loop principal

O jogador clica em **Despertar**. O servidor sorteia uma aura usando `Random.new()`, respeita cooldown de cerca de 1 segundo, registra no índice e permite equipar somente as auras obtidas. O efeito equipado aparece para os outros jogadores. O ciclo se repete.

## MVP

- Aproximadamente 30 auras originais em `src/shared/Dados/Auras.luau`: id, nome, raridade `1 em N`, cores e parâmetros de partículas.
- Raridades de 1 em 2 até 1 em 1.000.000, sem seed vinda do cliente.
- Partículas, luzes, brilho ou beams leves. Sem modelos 3D complexos.
- Índice com colecionáveis visíveis e silhuetas para desconhecidos.
- Anúncios no servidor quando raridade ≥ 1 em 1.000.
- Ranking `Giros` e `Melhor aura` em leaderstats.
- DataStore `Despertar_v1`: giros, auras obtidas (contagem), equipada e configurações.
- Giro automático usa o mesmo cooldown do manual.

## Fora da V1

Poções, presentes diários, códigos, eventos limitados, passes, trocas, títulos e cutscenes.

## Aceitação

CI e build verde. Sem erros no Output do Studio. Testes com dois jogadores (auras visíveis e anúncios para ambos), repetição rápida de pedidos, persistência após reconexão, interface e tempo de resposta.

**Esta branch prepara a base de desenvolvimento; o MVP ainda não foi implementado.**
