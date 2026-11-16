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
