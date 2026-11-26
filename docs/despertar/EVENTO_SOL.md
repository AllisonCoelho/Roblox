# Evento Despertar do Sol (Gear 5)

Evento coletivo com tema Gear 5 que se repete pelo relógio do servidor. A ideia é dar a todo
servidor um momento "chamativo" a cada meia hora e uma forma de conseguir a aura **Gear 5**,
que **não sai no sorteio normal**.

## Ciclo (30 min, todos os servidores juntos)

| Fase | Duração | O que acontece |
|---|---|---|
| espera | ~25 min | chip no HUD "☀ Despertar do Sol em 12:40" + botão ABRIR BAÚS |
| aviso | 60 s | faixa dourada pulsando com contagem, céu clareando, tambores na música |
| luta | 240 s | o **Titã de Borracha** cai na praça; todos batem nele; barra de vida e ranking |
| fim | 20 s | resultado e entrega dos baús |

Regras puras em `src/shared/Dados/EventoSol.luau` (testadas em `testes/logica.luau`).

## Chefe: Titã de Borracha

Personagem **original** (não é o Luffy): um **boneco do Roblox gigante** (escala 5, 26 studs,
ver `NPCS.md`) todo branco, com cabelo de nuvem, olhos com anéis dourados, sorrisão, gola de
nuvem, faixa dourada e auréola de sol girando. Estica os braços e achata como borracha.

- Vida = 150 golpes de quem está no servidor (mínimo 3000): ~2 min de luta, forte ou fraco.
- A aura de quem está a até 42 studs bate sozinha a cada 0,8 s (dano = força da aura × equipamento).
- A cada 5 s: **onda** — 1 s de aviso (braços esticados para cima) e um tapa no chão que
  arremessa quem estiver a até 20 studs (12% da vida).
- Visual no cliente (`src/client/Mundo/EventoSol.luau`): chegada caindo do céu com quique e
  onda de choque, respiração squash/stretch, golpes com orbes e números de dano, tremor de
  câmera (respeita *movimento reduzido*), derrota girando em chuva de luz.
- Céu do evento: o Ciclo mistura um "sol do meio-dia" branco e dourado (brilho contido),
  nuvens fofas e um sol sorridente no céu.

## Baús

Ganhos só no evento (não são vendidos). Ficam no perfil (`evento` no `Despertar_v1`).

| Prêmio | Baú do Sol (todos que ajudaram) | Baú Dourado (top 3, se o Titã cair) |
|---|---|---|
| Aura Gear 5 | 1% | 5% |
| Rastro Nuvem do Sol | 10% | 25% |
| Título Libertado | 15% | 30% |
| Pontos de Aura | 44% | 25% |
| Fragmentos | 30% | 15% |

- **Garantia:** a Gear 5 vem no máximo no **60º baú** aberto (contando os dois tipos).
- Cosmético repetido vira Pontos de Aura.
- Sorteio com `Random` do servidor; o cliente só pede `AbrirBau(tipo)`.
- Abertura com roleta (o prêmio já vem decidido do servidor) e flash.
- Quando alguém tira a Gear 5, **todo o servidor** vê a faixa "☀ FULANO DESPERTOU A GEAR 5!".

## Música

Sem nenhuma faixa de áudio: `src/shared/Dados/Musica.luau` gera as notas e
`src/client/Mundo/Musica.luau` toca com os sons que já vêm no Roblox (`rbxasset://sounds/...`),
mudando o tom. Três climas: calmo (78 bpm, I–vi–IV–V), aviso (120 bpm, tensão subindo) e
evento (132 bpm, tambores e arpejo). Opção "Música" em Ajustes desliga.

## Painel Dev

Botões **Aviso agora**, **Titã agora**, **Horário normal** (vale para o servidor) e
**+7 baús (teste)** (só em sessão de teste).

## Não testado ainda

Nada disso foi testado no Roblox Studio: precisa de playtest real do Titã (malhas, animação,
onda), do céu, da roleta, da música e do anúncio multiplayer.
