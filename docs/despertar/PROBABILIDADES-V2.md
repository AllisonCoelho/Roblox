# Probabilidades V2 — pesos de raridade normalizados

O sorteio e o Índice usam as 67 auras de `AurasOriginaisV2.luau`. As malhas do PR #50 são carregadas pelo motor das auras originais quando o jogador equipa uma delas.

Ao entrar no jogo, o perfil converte os 30 IDs antigos em auras novas de raridade equivalente e chance-base próxima. A conversão preserva cópias, soma quantidades caso o destino já exista e atualiza a aura equipada. Giros e demais campos do perfil não participam dessa conversão.

- A Centelha do Nexo usa complemento calculado: **20,9966227926%**, chance ~1/4,7627.
- Musgo Luminoso: **1/6**. Todas as outras 65 chances explicitas seguem a versao V2.
- Peso = pBase * sorte ^ expoenteTier; probabilidade efetiva = peso / soma(pesos).
- Expoentes: Comum 0, Incomum 0.25, Raro 1, Epico 1.2, Lendario 1.4, Mitico 1.6, Divino 1.8.
- Nivel 0..10 de Transcendencia gera indice de sorte 1.00..1.50. E um **indice**, nao garantia de multiplicar chances de todas as auras por 1.5.
- **Desde nov/2026 (autorizado pelo dono):** a sorte do giro e a **sorte total** = evolucao Sorte (Pontos de Aura) x Transcendencia x pets, com teto de **20x** (`Probabilidades.MAX_SORTE`). Valores e tabela em [PONTOS_DE_AURA.md](PONTOS_DE_AURA.md).
- O servidor usa a sorte total do perfil, e o Índice distingue chances **Base** e **Atual**.
- A sorte **nao** afeta drops das Incursoes, raridade intrinseca, ranking ou ressonancia.

## Referencias de teste (catalogo 67, nivel X / sorte 1.50)
| Aura | Chance base | Chance com sorte 1.50 |
| --- | --- | --- |
| Centelha do Nexo | 20,99662279% | 19,77931853% |
| Musgo Luminoso | 16,66666667% | 15,70039678% |
| Coroa de Coral | 1/110 | ~1/77,847 |
| Soberania do Vazio | 1/100.000.000 | ~1/51.165.103 |

Executar `python3 testes/rodar.py` e validar formatacao, tipos e build pelo GitHub Actions. O DataStore continua sendo `Despertar_v1`.
