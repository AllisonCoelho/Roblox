# Docinhos — documento de design

Jogo de coleção de **personagens de doces brasileiros**. Loop simples para crianças
(pegar, levar, ver as moedas subindo) com profundidade para os mais velhos
(raridades, variantes, álbum, eventos semanais).

## Loop principal

1. **Esteira da Fábrica:** os Docinhos passam com preço. Toque para comprar.
2. **Carregue até a sua vitrine** (você anda mais devagar carregando).
3. **A vitrine gera moedas por segundo**, até offline (2 h, ou mais com a melhoria Caixa Maior).
4. **Melhore a vitrine** e compre Docinhos mais raros.
5. *(Fase 3)* **Resgate:** com o escudo desligado, outro jogador pode levar um Docinho;
   tocando nele no caminho, o Docinho volta.

## Telas

| Tela | Imagem | Código |
|---|---|---|
| Identidade (cores, fonte, componentes) | [01](01-identidade.png) | `src/shared/Tema.luau`, `src/client/UI/Componentes.luau` |
| Docinhos e raridades | [02](02-docinhos.png) | `src/shared/Dados/Catalogo.luau` |
| Mapa | [03](03-mapa.png) | *próxima fase (jogabilidade)* |
| Vitrine no mundo | [04](04-vitrine.png) | *próxima fase (jogabilidade)* |
| HUD no PC | [05](05-hud-pc.png) | `src/client/UI/Telas/HUD.luau` |
| HUD no celular | [06](06-hud-celular.png) | `src/client/UI/Telas/HUD.luau` (layout compacto) |
| Álbum (Docinhopédia) | [07](07-album.png) | `src/client/UI/Telas/Album.luau` |
| Loja | [08](08-loja.png) | `src/client/UI/Telas/Loja.luau` |
| Popups | [09](09-popups.png) | `src/client/UI/Popups/*` |

Também existem os painéis **Meus Docinhos** (vitrine, caixa e venda), **Missões**,
**Presentes**, **Códigos** e **Ajustes**.

## Economia (valores iniciais, para balancear)

- **Moedas:** vêm da vitrine. **Granulados:** moeda rara (missões, presentes, códigos).
- **Vitrine:** 8 espaços + 4 por nível (5 níveis).
- **Escudo:** 60 s + 15 s por nível; depois recarrega 30 s.
- **Variantes:** Dourado (x2 de renda, 1 em 20) e Arco-íris (x5, 1 em 200).
- **Passe Confeiteiro VIP:** 2x moedas. O `gamePassId` está `0` em
  `src/shared/Dados/Loja.luau` até o passe ser criado no Roblox.
- **Chuva de Doces:** todo sábado às 15h (Brasília), por 10 minutos.

## Como testar no Studio

Com `ModoTeste = true` em `src/shared/Config.luau` (vale **só no Studio**):

- Os dados **não são salvos** e o jogador começa com moedas, granulados e alguns Docinhos.
- Teclas de teste:

| Tecla | O que mostra |
|---|---|
| F1 | Ganhar um Docinho aleatório (popup **Novo Docinho**) |
| F2 | Alerta de **Resgate** |
| F3 | Faixa da **Chuva de Doces** |
| F4 | **Tutorial** |
| F5 | Aviso "saiu um raro da fábrica" |
| F6 | Mostrar/esconder o Docinho **carregado** no HUD |

- Para ver o layout de celular no PC: **Ajustes → Tamanho da tela → Celular**,
  ou use o emulador de dispositivos do Studio.
- Para testar o DataStore no Studio: coloque `ModoTeste = false` e ative
  *Game Settings → Security → Enable Studio Access to API Services*.

## Testes automáticos

`python3 testes/rodar.py` testa a lógica compartilhada (formatação, agenda do evento,
missões, economia, loja) e a trava de sessão do DataStore, fora do Roblox. Precisa do
executável `luau` no PATH. O workflow `.github/workflows/testes.yml` roda esses testes,
o StyLua, a análise de tipos (luau-lsp) e o build em cada PR.

O que só dá para ver dentro do jogo está no [checklist de playtest](playtest.md).

## Próximas fases

1. **Jogabilidade:** mapa, esteira, carregar Docinhos, vitrines no mundo com caixa e escudo.
2. **Modelos 3D:** ver [modelos-3d.md](modelos-3d.md).
3. **Eventos e resgate:** Chuva de Doces de verdade e o resgate entre jogadores.
