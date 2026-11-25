# Pendências do Despertar

Lista salva para retomar quando o dono pedir. Atualizada em 17/11/2026.

## Merges (dono / Codex), nesta ordem
1. #33 → #34 → #35 (Incursões, fases A, B e C)
2. #36 (roleta do giro + passes Giro Automático e Pular Animação)
3. #37 (Loja: Passe de Temporada, Pacote do Iniciante e VIP do Nexo)
4. #38 (os outros 11 produtos)
5. #24 (pendente de antes)

## Creator Hub (dono) → enviar os IDs para colocar no código
- **Game Passes (9)**:
  - Giro Automático 49
  - Pular Animação 39
  - Pacote do Iniciante 49
  - VIP do Nexo 199
  - Passe de Temporada 299
  - Auto Inteligente 79
  - Presets de Auras 49
  - Ritual Personalizado 99
  - Pacote Fundador 149

  Os IDs vão em `gamePassId` em `src/shared/Dados/Monetizacao.luau`.
- **Produtos de desenvolvedor (14)**: os IDs vão em `developerProductId` em `src/shared/Dados/Cosmeticos.luau`.
  - Títulos: Lenda Viva 39, Tecelão de Destinos 59, Olhos do Abismo 79
  - Trilhas: Relâmpago 49, Sakura 69, Cósmico 99
  - Aparências: Sombria 99, Prisma 149, Solar 199
  - Emotes: Fogos do Nexo 49, Coroação 69, Tempestade 99
  - Finalizações: Estilhaço 99, Eclipse 149
- **Assinatura do Nexo** 99/mês: o id `EXP-...` vai em `subscriptionId` no produto `assinatura`.
- **Servidores privados**: ligar em Acesso ao servidor, com preço de 49/mês.

## Studio / playtest (dono)
- Importar os assets 3D que ainda não aparecem.
- Testar no jogo:
  - roleta do giro e passes;
  - Loja (Temporada, Pacotes, Itens, Cosméticos, Extras);
  - ProcessReceipt;
  - assinatura;
  - rituais coloridos;
  - emotes e finalizações na Arena.

## Decisões em aberto
- Ranking global diário das Incursões: precisa de OrderedDataStore novo (aguarda autorização).
- Aparência Alternativa nas auras com VFX próprio (Gear 5, Monarca, Caudas): só o atributo `AuraAparencia` existe; falta aplicar no visual 3D.
- Licença ou adaptação dos nomes de anime antes do lançamento público.
