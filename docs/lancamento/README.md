# Lançamento — checklist do dono

O código está pronto para o **playtest**. **Não lance antes do playtest real** (seções 6 e 7 de
[../design/playtest.md](../design/playtest.md): dois jogadores, escudo, resgate, chuva, Renascer,
celular, sair e voltar com DataStore de verdade). O resto são passos que só o dono da conta pode
fazer no Roblox (criar produtos, emblemas, subir imagens, responder o questionário). Siga na
ordem; cada item diz **onde** mexer.

## 1. Experiência de produção

- [ ] Hoje a `main` publica na **experiência privada de testes**. Para o público, crie uma
      **experiência nova** (Creator Hub → Criações → Criar experiência) e deixe a de testes como está.
- [ ] A publicação automática na experiência pública **não está configurada** (é uma mudança de
      CI/CD e de chaves Open Cloud, que precisa da sua autorização). Até lá, publique pelo Studio:
      `rojo build default.project.json --output Docinhos.rbxlx`, abra no Studio e use
      *Arquivo → Publicar no Roblox como…* na experiência nova.

## 2. Configurações da experiência (Creator Hub)

- [ ] **Tamanho do servidor: 6** (Lugares → Configurações → Máximo de jogadores). São 6 vitrines;
      um 7º jogador ficaria sem vitrine.
- [ ] **Dispositivos:** Computador, Celular e Tablet. Deixe **Console desligado** até testar com controle.
- [ ] **Gênero:** Simulação. **Descrição e nome:** em [descricao.md](descricao.md).
- [ ] **Ícone:** [icone.png](icone.png) (512×512).
- [ ] **Miniaturas:** [thumb-1.png](thumb-1.png), [thumb-2.png](thumb-2.png), [thumb-3.png](thumb-3.png)
      (1920×1080). Quando os modelos 3D estiverem prontos, acrescente prints do jogo de verdade:
      o Roblox recomenda que as miniaturas mostrem o jogo.
- [ ] **Localização:** ligue a **captura automática de texto** e a **tradução automática** para
      inglês e espanhol. O jogo é em português; a tradução automática cobre os textos da interface.
- [ ] **Questionário de maturidade:** responda com sinceridade; o esperado é **Mínimo**.
      - Violência, sangue, sustos, linguagem: não.
      - **Itens aleatórios pagos: não.** Nada que se compra com Robux é sorteado: os pacotes dão
        uma quantidade fixa de granulados e o jogador vê cada Docinho na esteira antes de comprar
        com moedas. O boost "Esteira da Sorte" só muda quais Docinhos aparecem.
      - Interação social: só o chat padrão do Roblox; o jogo não depende do chat.
- [ ] **Acesso aos serviços de API:** os DataStores funcionam sozinhos no jogo publicado. No Studio,
      para testar salvamento, ligue *Game Settings → Security → Enable Studio Access to API Services*.

## 3. Monetização (Robux)

Crie cada item na experiência **pública** e cole o número (ID) no arquivo indicado. Enquanto o ID
for `0`, o botão mostra "chega em breve" e nada é cobrado.

| Item | Tipo no Creator Hub | Preço | Onde colar o ID |
|---|---|---|---|
| Confeiteiro VIP | Passe (Monetização → Passes) | 199 | `src/shared/Dados/Loja.luau` → `Passes` → `gamePassId` |
| 120 granulados | Produto de desenvolvedor | 25 | `Loja.luau` → `Pacotes` → `punhado` → `productId` |
| 400 granulados | Produto de desenvolvedor | 69 | `Pacotes` → `potinho` |
| 1.100 granulados | Produto de desenvolvedor | 169 | `Pacotes` → `lata` |
| 3.000 granulados | Produto de desenvolvedor | 389 | `Pacotes` → `caminhao` |

- Imagens para os itens: use o ícone de cada um (👑 VIP, ✨/🧁/🍰/🎂 pacotes) ou recorte da arte
  em [../design/11-loja-granulados.png](../design/11-loja-granulados.png).
- **Teste no Studio antes de publicar:** no Studio as compras são de teste (não cobram). Compre um
  pacote: os granulados entram e aparece "+N granulados! Obrigado 💖".
- Segurança já feita no código: a compra só é confirmada ao Roblox **depois de salvar**; se falhar,
  o Roblox tenta de novo e a mesma compra nunca é entregue duas vezes (`estado.recibos` guarda
  todas as compras). As gravações de cada jogador vão em fila, então um salvamento antigo não
  apaga um crédito novo.
- **Não coloque IDs de verdade antes de testar as compras** no Studio com DataStore de verdade
  (item de compras na seção 7 do playtest).

## 4. Emblemas (conquistas)

Crie em Creator Hub → Engajamento → Emblemas e cole em `src/shared/Dados/Conquistas.luau` → `badgeId`.
Enquanto for `0`, a conquista vale só dentro do jogo; quem já ganhou recebe o emblema quando o ID
for colocado. O Roblox libera alguns emblemas grátis por dia e cobra Robux pelos outros: confira
o valor na hora de criar e comece pelos mais importantes.

| Ordem sugerida | Conquista | Como ganha |
|---|---|---|
| 1 | Bem-vindo à Fábrica | entrar no jogo |
| 2 | Primeiro Docinho | primeiro Docinho na vitrine |
| 3 | Que Sorte! | um Lendário ou mais raro |
| 4 | Álbum Completo | todos os Docinhos do álbum |
| 5 | Renascido | primeiro Renascer |
| 6 | Toque de Ouro | um Docinho Dourado |
| 7 | Caiu do Céu | pegar um Docinho na chuva |
| 8 | Guardião da Vitrine | alcançar quem levava seu Docinho |
| 9 | Milionário | juntar 1 milhão de moedas |

## 5. Conteúdo

- [ ] **Modelos 3D dos Docinhos:** guia e prompts em [../design/modelos-3d.md](../design/modelos-3d.md).
      Sem eles o jogo funciona com modelos de peças coloridas.
- [ ] **Sons:** já tocam com sons do próprio Roblox. Para trocar ou pôr música de fundo, cole IDs da
      Creator Store em `src/shared/Dados/Sons.luau` (`Musica.id` vazio = sem música).
- [ ] **Códigos:** `DOCINHOS`, `BRIGADEIRO` e `1MILVISITAS` em `src/server/Servicos/Recompensas.luau`.
      Divulgue o `1MILVISITAS` só quando chegar a 1 milhão de visitas.

## 6. Antes de abrir para o público

- [ ] Rodar o [checklist de playtest](../design/playtest.md) no PC e no celular, com 2 jogadores.
- [ ] Jogar 20 minutos como jogador novo (`ModoTeste = false`): o ritmo esperado está em
      [../design/balanceamento.md](../design/balanceamento.md).
- [ ] Revisão do ChatGPT e merge na `main` (testa de novo na experiência privada).
- [ ] Publicar na experiência pública e deixar **Pública** em Configurações → Privacidade.

## Depois do lançamento

- Olhe o painel de **Análise** do Creator Hub (retenção D1/D7, tempo de sessão, compras).
- Ajuste preços e chances em `src/shared/Dados/*.luau` e confira o efeito com
  `python3 testes/rodar.py simulacao` antes de publicar.
- Eventos novos são fáceis de agendar em `src/shared/Dados/Evento.luau`.
