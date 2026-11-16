# Despertar — roadmap V2/V3

> Documento de debate. **Nada aqui está aprovado nem implementado.** Cada item precisa do ok do dono antes de virar código. Estimativas são de design, não promessas de retenção.

## Próximos PRs da V1

1. **Nexo do Despertar** (mapa): praça com o Núcleo, Arquivo dos Ecos (abre o índice), Obelisco das Lendas (ranking), Jardim dos Fragmentos e cenários-teaser marcados como "Em construção".
2. **Identidade por aura**: hoje a aura equipada varia por estilo (brilho/chama/névoa) e raridade. Falta dar padrão de movimento próprio a cada uma (pétalas, órbitas, cinzas, constelação), reconhecível de longe.
3. **Polimento**: sons próprios, limite de efeitos simultâneos, ajustes de duração após playtest, checklist mobile.

## V2

| Sistema | Ideia | Riscos / cuidados | Esforço |
|---|---|---|---|
| Maestria de aura | Usar uma aura e cumprir pequenas tarefas libera detalhes cosméticos dela | Não alterar chances; novo campo no save (`maestria[id]`) | Médio |
| Títulos de prestígio | Títulos por marcos (giros, descobertas) exibidos sobre o avatar | Texto fixo, sem entrada livre do jogador | Baixo/médio |
| Desafios semanais e conquistas | Metas rotativas com recompensa cosmética | Relógio do servidor; não virar obrigação diária | Médio |
| Rituais de coleção | Conjuntos de auras descobertas ativam algo no Altar da Ressonância | Não consumir auras de forma frustrante | Alto |
| Exploração ampliada | Mais segredos e leitura ambiental no Nexo | Não prometer recompensa inexistente | Médio |
| Ranking global | OrderedDataStore de giros e melhor aura | Orçamento de DataStore, atualização espaçada | Médio |

## V3

| Sistema | Ideia | Riscos / cuidados | Esforço |
|---|---|---|---|
| Fenômenos dimensionais | Eclipse, Tempestade Astral, Convergência mudam céu, música e segredos | Se mexer em chance, a chance efetiva exibida tem de mudar junto, com teste | Alto |
| Portais / biomas | Áreas novas atrás dos Portais Fragmentados | Custo de construção e de desempenho no celular | Alto |
| Personalização do ritual | Escolher estilo de anéis/círculo | Só cosmético | Médio |
| Eventos cooperativos | Acontecimento público no mapa, sem PvP | Sincronização e carga em servidores cheios | Alto |

## Monetização

Fora da V1. Qualquer item pago ligado a sorteio exige antes: análise das políticas do Roblox para itens aleatórios pagos, chances exibidas e decisão explícita do dono.
