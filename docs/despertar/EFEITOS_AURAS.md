# Efeitos extravagantes das auras

Toda aura ganha uma **camada extravagante** por cima do efeito próprio dela. Quanto mais rara a
aura, mais camadas.

## Engenharia reversa (jogos de RNG do Roblox)

Nos jogos de RNG do Roblox (Sol's RNG e parecidos), o visual escala com a raridade. Os elementos
que se repetem:
- anéis no chão que sobem;
- orbes e raios girando;
- feixes subindo até um portal acima da cabeça;
- cores ciclando (cromático);
- pulsos de partículas na base;
- título da aura;
- uma "cutscene" curta ao obter ou equipar.

## Camadas por raridade (acumulam)

| Raridade | Acrescenta |
|---|---|
| Comum | luz no corpo + faíscas |
| Incomum | anéis no chão que sobem e abrem |
| Raro | orbes girando com rastro + tema (chama: brasas · névoa: fumaça · brilho: estrelas) |
| Épico | fitas de luz em espiral subindo pelo corpo + pulso de faíscas e onda a cada poucos segundos |
| Lendário | pilar de luz até o céu + título flutuante (nome com brilho correndo, raridade e "1 em N") |
| Mítico | portal acima da cabeça com feixes saindo dos ombros + raios em volta + contorno brilhante |
| Divino | cores ciclando (cromático) em tudo + coroa de estrelas + chuva de luz |

A Gear 5 (exclusiva do evento) conta como Divino.

## Manifestação ao equipar

Ao equipar a aura, ela "manifesta":
- núcleo de explosão, anéis de choque em sequência e faíscas;
- luz piscando forte.

Só o dono vê o resto, que cresce com a raridade:
- a partir de Épico, tremor de câmera;
- a partir de Lendário, flash de tela;
- a partir de Mítico, tela tingida com a cor da aura.

## Desempenho e acessibilidade

- **Qualidade baixa:** tira as camadas pesadas (espiral, pilar, portal, raios, coroa, chuva).
- **Distância:** até 60 studs aparece tudo; de 60 a 140, sem as pesadas; mais longe, só a luz.
  O próprio jogador sempre vê tudo.
- **Movimento reduzido:** nada gira e não há tremor.
- **Ocultar efeitos alheios:** só a sua aura aparece.
- A Aparência Alternativa (cosmético) recolore a camada.

## Arquivos

- `src/shared/Dados/Extravagancia.luau`: regras (testadas).
- `src/client/Mundo/Auras/Extravagancia.luau`: montagem e animação.
- `src/server/Servicos/AuraVisual.luau`: publica os atributos `AuraId`, `AuraIdEm` e `AuraCor`.
- Prévia: `assets/auras/previews/extravagancia.png` (mock em HTML, **não é print do Roblox**).

Só texturas de partícula que já vêm com o Roblox (`rbxasset://textures/particles/...`). Nenhum
asset de terceiros.

**Não testado no Roblox Studio ainda.**
