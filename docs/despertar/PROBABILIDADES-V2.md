# Probabilidades V2 — pesos de raridade normalizados

A correção das probabilidades e independente do inventario/forja. O catalogo 67 incluido aqui e **uma tabela de referencia matematica**: a colecao antiga de 30 auras continua ativa ate o PR da migracao de catalogo.

- A Centelha do Nexo usa complemento calculado: **20,9966227926%**, chance ~1/4,7627.
- Musgo Luminoso: **1/6**. Todas as outras 65 chances explicitas seguem a versao V2.
- Peso = pBase * sorte ^ expoenteTier; probabilidade efetiva = peso / soma(pesos).
- Expoentes: Comum 0, Incomum 0.25, Raro 1, Epico 1.2, Lendario 1.4, Mitico 1.6, Divino 1.8.
- Nivel 0..10 de Transcendencia gera indice de sorte 1.00..1.50, limitado tecnicamente a 3.00 para futuras fontes. E um **indice**, nao garantia de multiplicar chances de todas as auras por 1.5.
- O servidor usa opcionalmente `estado.transcendencia.nivel` (caso inexistente, assume 0) e o Indice distingue chances **Base** e **Atual**. O PR de inventario sera responsavel por criar e salvar o nivel com a fabricacao no Altar.
- A sorte **nao** afeta drops das Incursoes, raridade intrinseca, ranking ou ressonancia.

## Referencias de teste (catalogo 67, nivel X / sorte 1.50)
| Aura | Chance base | Chance com sorte 1.50 |
| --- | --- | --- |
| Centelha do Nexo | 20,99662279% | 19,77931853% |
| Musgo Luminoso | 16,66666667% | 15,70039678% |
| Coroa de Coral | 1/110 | ~1/77,847 |
| Soberania do Vazio | 1/100.000.000 | ~1/51.165.103 |

Executar `python3 testes/rodar.py` e validar formatacao, tipos e build pelo GitHub Actions. Este PR **nao** cria itens, receitas, nem altera o DataStore.
