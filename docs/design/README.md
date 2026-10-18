# Docinhos — documento de design

Jogo de coleção de **personagens de doces brasileiros**. Loop simples para crianças
(pegar, levar, ver as moedas subindo) com profundidade para os mais velhos
(raridades, variantes, álbum, eventos, Renascer e Ranking).

**Para lançar:** veja o [checklist do dono](../lancamento/README.md) (IDs de passe, produtos e
emblemas, ícone, miniaturas, descrição e questionário).

## Loop principal

1. **Esteira da Fábrica:** os Docinhos passam com preço. Toque para comprar.
2. **Carregue até a sua vitrine** (você anda mais devagar carregando).
3. **A vitrine gera moedas por segundo**, até offline (2 h, ou mais com a melhoria Caixa Maior).
4. **Melhore a vitrine** e compre Docinhos mais raros.
5. **Resgate:** com o escudo desligado, outro jogador pode levar um Docinho;
   tocando nele no caminho, o Docinho volta.
6. **Renascer:** com moedas suficientes, recomeça as moedas e ganha renda extra para sempre.

## Telas

| Tela | Imagem | Código |
|---|---|---|
| Identidade (cores, fonte, componentes) | [01](01-identidade.png) | `src/shared/Tema.luau`, `src/client/UI/Componentes.luau` |
| Docinhos e raridades | [02](02-docinhos.png) | `src/shared/Dados/Catalogo.luau` |
| Mapa | [03](03-mapa.png) · [planta do código](10-planta.png) | `src/shared/Dados/Mapa.luau`, `src/server/Mundo/Construtor.luau` |
| Vitrine no mundo | [04](04-vitrine.png) | `src/server/Servicos/Lotes.luau` |
| Esteira e carregar | — | `src/shared/Dados/Esteira.luau`, `src/server/Servicos/Esteira.luau`, `src/client/Mundo/*` |
| HUD no PC | [05](05-hud-pc.png) | `src/client/UI/Telas/HUD.luau` |
| HUD no celular | [06](06-hud-celular.png) | `src/client/UI/Telas/HUD.luau` (layout compacto) |
| Álbum (Docinhopédia) | [07](07-album.png) | `src/client/UI/Telas/Album.luau` |
| Loja | [08](08-loja.png) · [granulados](11-loja-granulados.png) | `src/client/UI/Telas/Loja.luau` |
| Popups | [09](09-popups.png) | `src/client/UI/Popups/*` |

Também existem os painéis **Meus Docinhos** (vitrine, caixa e venda), **Missões**,
**Presentes**, **Códigos**, **Ajustes** (tamanho da tela, efeitos e música), **Renascer** e **Ranking**.

## Economia (ajustada pela [simulação](balanceamento.md))

- **Moedas:** vêm da vitrine. **Granulados:** moeda rara (missões, presentes, códigos, álbum,
  Renascer e pacotes com Robux).
- **Vitrine:** 8 espaços + 4 por nível (5 níveis: 5 mil, 25 mil, 150 mil, 750 mil, 4 mi).
- **Escudo:** 60 s + 15 s por nível; depois recarrega 30 s.
- **Variantes:** Dourado (x2 de renda, 1 em 20) e Arco-íris (x5, 1 em 200).
- **Passe Confeiteiro VIP:** 2x moedas, coroa VIP no personagem e +10 granulados no presente diário.
- **Pacotes de granulados:** 120, 400, 1.100 e 3.000 (Developer Products).
  IDs de passe, produtos e emblemas ficam `0` até serem criados no Roblox (ver o checklist).
- **Renascer:** 2,5 mi de moedas (x4 a cada vez); +25% de renda para sempre e granulados.
  Mantém Docinhos, álbum e o tamanho da vitrine.
- **Chuva de Doces:** todo sábado às 15h (Brasília), por 10 minutos. **Chuvisco:** 1 minuto a cada 20.

## Como testar no Studio

Com `ModoTeste = true` em `src/shared/Config.luau` (vale **só no Studio**):

- Os dados **não são salvos** e o jogador começa com 2 milhões de moedas, granulados e alguns Docinhos.
- Teclas de teste:

| Tecla | O que mostra |
|---|---|
| F1 | Ganhar um Docinho aleatório (popup **Novo Docinho**) |
| F2 | Alerta de **Resgate** |
| F3 | Liga a **Chuva de Doces** de verdade por 60 s |
| F4 | **Tutorial** |
| F5 | Aviso "saiu um raro da fábrica" |
| F7 | Soltar um **Pudim Lendário** na esteira (comprar, carregar e entregar) |

- Para ver o layout de celular no PC: **Ajustes → Tamanho da tela → Celular**,
  ou use o emulador de dispositivos do Studio.
- Para testar o DataStore no Studio: coloque `ModoTeste = false` e ative
  *Game Settings → Security → Enable Studio Access to API Services*.

## Testes automáticos

`python3 testes/rodar.py` testa a lógica compartilhada (formatação, agenda do evento,
missões, economia, loja, compras, conquistas, mapa, esteira, resgate, chuva) e a trava de sessão
do DataStore, fora do Roblox. `python3 testes/rodar.py simulacao` roda a
[simulação de balanceamento](balanceamento.md). Precisa do
executável `luau` no PATH. O workflow `.github/workflows/testes.yml` roda esses testes,
o StyLua, a análise de tipos (luau-lsp) e o build em cada PR.

O que só dá para ver dentro do jogo está no [checklist de playtest](playtest.md).

## Jogabilidade (fase 2)

- **Mundo construído por código** (`Mundo/Construtor.luau`) a partir da planta: fábrica, esteira,
  6 vitrines, praça e decoração. Nada precisa ser montado à mão no Studio.
- **Esteira:** um Docinho a cada 2,5 s (sorteio por raridade; Esteira da Sorte de qualquer jogador
  dobra a chance de Raro+ para o servidor todo). Lendário ou melhor avisa todo mundo.
  Cada cliente anima a posição pelo tempo; o servidor faz a mesma conta para validar a compra.
- **Comprar e carregar:** chegue perto e aperte E. O servidor confere distância, moedas e espaço
  na vitrine. O Docinho vai em cima da cabeça e você anda mais devagar (o Tênis Rápido ajuda).
  Entrar na própria vitrine entrega. Se cair ou sair do jogo carregando, recebe as moedas de volta.
- **Vitrines:** cada jogador recebe uma livre ao entrar e renasce nela. Docinhos nos pedestais com
  nome, raridade e renda; pisar no caixa coleta; pisar no escudo liga (o portão azul aparece).
- **Praça:** Loja, Docinhopédia e Códigos abrem a tela com E.
- **Servidor com 6 vagas:** em *Game Settings → Places → Max Players*, use **6** (uma vitrine por jogador).

## Eventos e resgate (fase 3)

- **Chuva de Doces de verdade:** no sábado às 15h (ou com F3 no Studio), Docinhos caem em pontos
  livres do mapa a cada 1,2 s (com sorte dobrada para raros). Depois de pousar, quem encosta
  primeiro ganha de graça na vitrine (com a vitrine cheia, é vendido na hora por moedas).
  Ficam 20 s no chão. O Docinho **Secreto** só cai na chuva de sábado.
  O servidor marca `workspace.ChuvaAte`; a faixa e a contagem do HUD seguem esse atributo.
- **Resgate entre jogadores** (regras em `src/shared/Dados/Resgate.luau`): segure E por 1,5 s num
  Docinho da vitrine de outro jogador para levá-lo. Proteções para o público infantil:
  - escudo ligado protege a vitrine (e o portão bloqueia a entrada);
  - vitrines com menos de 3 Docinhos são de iniciante e não podem ser resgatadas;
  - quem foi resgatado fica 60 s imune; quem resgatou espera 30 s para resgatar de novo;
  - o dono que **encostar** em quem está levando recupera o Docinho na hora;
  - se quem resgatou cair ou sair do jogo, o Docinho volta para o dono.
  - na entrega o servidor confere se a viagem desde o resgate foi possível andando; quem se
    teletransporta perde o Docinho, que volta para o dono.
  O Docinho que volta não conta de novo no álbum. Não há moedas de compensação
  (evita que dois amigos fabriquem moedas resgatando um do outro).
- **Portão do escudo:** com o escudo ligado o portão bloqueia todo mundo menos o dono
  (grupos de colisão). Quem estiver dentro quando o escudo ligar é levado para fora.
  As paredes laterais subiram para 10 studs para não dar para pular por cima.
- **Caixa e escudo** têm esperas separadas: pisar num e logo no outro funciona.

## Pronto para lançar (fase 4)

- **Renascer** (painel com confirmação em dois toques) e **Ranking** (placar do servidor e recorde
  mundial de renda/s num OrderedDataStore; `leaderstats` com Renda/s, Álbum e Renascimentos).
- **Sons** em todos os botões, avisos, Docinho novo, chuva e resgate; efeitos e música podem ser
  desligados em Ajustes (fica salvo).
- **Trilha-guia** no chão: leva à esteira quando a vitrine está vazia, à vitrine quando está
  carregando e ao Docinho mais perto durante a chuva.
- **Prêmio do álbum completo** (500 granulados), **venda segura** (o servidor confere qual Docinho
  está sendo vendido) e o **Secreto** obtenível na chuva de sábado.
- **Granulados com Robux** (ProcessReceipt que só confirma depois de salvar e nunca entrega a
  mesma compra duas vezes) e **coroa VIP**.
- **Conquistas** com emblemas do Roblox (`src/shared/Dados/Conquistas.luau`).
- **Chuvisco de Doces** a cada 20 minutos e **balanceamento** pela simulação.

## Próximos passos

1. **Modelos 3D:** ver [modelos-3d.md](modelos-3d.md).
2. **Lançamento:** [checklist do dono](../lancamento/README.md).
3. **Depois de lançar:** ajustar números com os dados reais do painel de Análise.
