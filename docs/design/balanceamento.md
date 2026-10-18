# Balanceamento — Docinhos

Os números saem de `testes/simulacao.luau`, que joga sozinho por horas usando as mesmas regras do jogo
(`Catalogo`, `Economia`, `Esteira`, `Loja`). Para rodar de novo depois de mudar qualquer número:

```
python3 testes/rodar.py simulacao
```

## Como o jogador simulado joga

- Fica na esteira e compra o **melhor Docinho que cabe no bolso** entre os que estão passando
  (com a vitrine cheia, só compra se render mais que o pior da vitrine, e vende o pior ao entregar).
- Leva o Docinho até a vitrine (anda devagar carregando; o Tênis Rápido ajuda) e volta.
- Compra **Vitrine Maior** assim que a vitrine enche e tem moedas; Tênis, Escudo e Caixa quando
  custam pouco perto do saldo; **renasce** assim que pode.
- Não conta: Chuva/Chuvisco, missões, presentes, boosts, VIP, códigos nem renda offline
  (tudo isso só deixa o jogo **mais rápido** que a tabela).
- Dois perfis: **criança casual** (viagens lentas, gasta à toa, 3 h) e **jogador dedicado** (10 h).
  Cada perfil é a média de 5 jogos com sorteios diferentes.

## O que mudou por causa da simulação

| O quê | Antes | Agora | Por quê |
|---|---|---|---|
| Vitrine Maior (custos) | 5 mil · 20 mil · 50 mil · 200 mil · 1 mi | 5 mil · 25 mil · 150 mil · 750 mil · 4 mi | A vitrine chegava ao máximo em ~30 min e sobrava pouco objetivo depois de 1 h. Agora o máximo chega perto de 1 h. |
| 1º Renascer | 1 mi (≈ 35–40 min) | 2,5 mi (≈ 45–55 min) | Renascer não tira os Docinhos, então é quase "de graça"; precisava vir depois da 1ª hora de descobertas. |
| Docinho da chuva com vitrine cheia | +5 granulados | vende na hora (moedas, valor de venda) | Um jogador sozinho tirava ~2.000 granulados por Chuva, mais que o maior pacote pago. |
| Chuva | só sábado (10 min) | + **Chuvisco** de 1 min a cada 20 min | A maioria nunca veria a chuva. O Chuvisco solta menos Docinhos, sem sorte extra e sem o Secreto. |

## Ritmo esperado (depois dos ajustes)

- **Primeira sessão (15–20 min):** vitrine cheia em 2–3 min, 1º Raro em ~8 min, 2 níveis de vitrine,
  1º Épico perto dos 15–20 min. Sempre tem algo novo a cada poucos minutos.
- **Primeira hora:** 1º Lendário (~40 min), 1º Renascer (~50 min), vitrine no máximo (~1 h).
- **Longo prazo:** Mítico (~2 h, 1 a cada 42 min na esteira em média), Arco-íris (1 em 200),
  renascimentos cada vez mais caros (x4), o Secreto só na Chuva de sábado e o Ranking.

## Economia de granulados (moeda premium)

| Fonte grátis | Quanto |
|---|---|
| Missões do dia (3 por dia) | 10–50 cada |
| Presente diário | 10–25 nos dias de granulados (+10 com VIP) |
| Álbum completo | 500 (uma vez) |
| Renascer | 50 × número do renascimento |
| Códigos | variam |

Boosts custam 40–60 granulados: quem joga todo dia ganha 1–2 boosts por dia sem pagar. Os pacotes
(120 a 3.000 granulados) são atalho, nunca obrigação.

## Resultado da simulação

### Esteira: com que frequência cada raridade aparece

| Raridade | Peso | Chance por Docinho | Tempo médio entre aparições |
|---|---|---|---|
| Comum | 60 | 60.00% | 4 s |
| Incomum | 25 | 25.00% | 10 s |
| Raro | 10 | 10.00% | 25 s |
| Épico | 4 | 4.00% | 1 min |
| Lendário | 0.9 | 0.90% | 5 min |
| Mítico | 0.1 | 0.10% | 42 min |

### Criança casual (anda devagar, gasta à toa) — média de 5 jogos de 3 h

| Marco | Quando (média) | Em quantos jogos |
|---|---|---|
| 1º Comum | 21 s | 5/5 |
| vitrine cheia (8) | 3 min | 5/5 |
| 1º Dourado | 3 min | 5/5 |
| 1º Incomum | 3 min | 5/5 |
| vitrine nível 1 | 6 min | 5/5 |
| 1º Raro | 8 min | 5/5 |
| vitrine nível 2 | 12 min | 5/5 |
| 1º Épico | 19 min | 5/5 |
| vitrine nível 3 | 22 min | 5/5 |
| vitrine nível 4 | 35 min | 5/5 |
| 1º Lendário | 46 min | 5/5 |
| 1º Arco-íris | 1.1 h | 4/5 |
| vitrine nível 5 | 1.1 h | 5/5 |
| 1º Mítico | 2.0 h | 3/5 |
| Renascer 1 | 56 min | 5/5 |
| Renascer 2 | 1.3 h | 5/5 |
| Renascer 3 | 1.8 h | 5/5 |
| Renascer 4 | 2.7 h | 5/5 |

| Tempo de jogo | Renda média | Docinhos na vitrine |
|---|---|---|
| 5 min | 69/s | 8 |
| 15 min | 735/s | 16 |
| 30 min | 3.665/s | 20 |
| 1.0 h | 14,6 mil/s | 24 |
| 2.0 h | 51,8 mil/s | 28 |

### Jogador dedicado — média de 5 jogos de 10 h

| Marco | Quando (média) | Em quantos jogos |
|---|---|---|
| 1º Comum | 13 s | 5/5 |
| 1º Dourado | 60 s | 5/5 |
| vitrine cheia (8) | 2 min | 5/5 |
| 1º Incomum | 2 min | 5/5 |
| vitrine nível 1 | 5 min | 5/5 |
| 1º Raro | 7 min | 5/5 |
| vitrine nível 2 | 11 min | 5/5 |
| 1º Épico | 15 min | 5/5 |
| vitrine nível 3 | 18 min | 5/5 |
| vitrine nível 4 | 28 min | 5/5 |
| 1º Arco-íris | 36 min | 4/5 |
| 1º Lendário | 36 min | 5/5 |
| vitrine nível 5 | 55 min | 5/5 |
| 1º Mítico | 2.0 h | 4/5 |
| Renascer 1 | 46 min | 5/5 |
| Renascer 2 | 1.1 h | 5/5 |
| Renascer 3 | 1.6 h | 5/5 |
| Renascer 4 | 2.4 h | 5/5 |
| Renascer 5 | 4.1 h | 5/5 |
| Renascer 6 | 7.2 h | 4/5 |

| Tempo de jogo | Renda média | Docinhos na vitrine |
|---|---|---|
| 5 min | 86/s | 8 |
| 15 min | 1.093/s | 16 |
| 30 min | 4.922/s | 23 |
| 1.0 h | 21,7 mil/s | 28 |
| 2.0 h | 60,6 mil/s | 28 |
| 5.0 h | 187,7 mil/s | 28 |
| 10.0 h | 366,9 mil/s | 28 |
