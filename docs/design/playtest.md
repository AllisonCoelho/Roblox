# Checklist de playtest: interface dos Docinhos

O CI testa a lógica, a formatação, os tipos e o build, mas **não abre o jogo**.
Este roteiro cobre o que só dá para ver no Roblox Studio. Marque cada item em
**PC** e em **celular** (Ajustes → Celular, ou o emulador de dispositivos do Studio,
por exemplo um iPhone deitado).

## 1. Entrada e dados (handshake)

Rode 5 vezes seguidas (Play → Stop → Play) com `ModoTeste = true`:

- [ ] As moedas e os granulados aparecem logo ao entrar (nunca fica "0" parado)
- [ ] O tutorial aparece no primeiro acesso
- [ ] Com **Start Server + 2 jogadores** (aba Test), cada um vê os próprios dados

Com `ModoTeste = false` e *Enable Studio Access to API Services* ligado:

- [ ] Entrar, comprar uma melhoria, sair e entrar de novo: a melhoria continua lá
- [ ] O Output não mostra "salvamento cancelado" nem "trava de outro servidor"

## 2. HUD

- [ ] Moedas com "+N/s" à direita; o número sobe quando o caixa é coletado
- [ ] Menu: cada botão abre o painel certo; bolinhas vermelhas aparecem e somem
- [ ] Contagem da Chuva de Doces anda a cada segundo
- [ ] Missão em destaque mostra o progresso; tocar abre Missões
- [ ] Escudo: tocar liga; mostra "desliga em", depois "recarregando"
- [ ] **F6** mostra e esconde o Docinho carregado embaixo
- [ ] Celular: nada fica embaixo do analógico, do botão de pular ou da barra do Roblox

## 3. Painéis

- [ ] Abrem com animação, um por vez; fecham no X, no fundo escuro e no Esc
- [ ] **Loja:** as 3 abas; comprar com e sem moedas (sem moedas aparece "Faltam ...")
- [ ] **Meus Docinhos:** COLETAR soma no contador; Vender pede "CERTEZA?" antes
- [ ] **Álbum:** silhueta nos não descobertos; tocar num Docinho troca o detalhe; abas Dourados e Arco-íris
- [ ] **Missões:** PEGAR só quando completa; depois mostra "FEITO ✓"
- [ ] **Presentes:** PEGAR uma vez; depois "Volte em ..."
- [ ] **Códigos:** `DOCINHOS` funciona uma vez; código errado mostra o aviso
- [ ] **Ajustes:** trocar Automático / Celular / Computador muda o layout na hora

## 4. Popups (teclas de teste)

- [ ] **F1** Novo Docinho (com raios girando), **F2** Resgate, **F3** Chuva de Doces,
      **F4** Tutorial, **F5** aviso de raro
- [ ] Vários F1 seguidos entram em fila (um por vez)

## 5. Vitrine (quando o mapa existir)

- [ ] Botão Vitrine leva até a sua vitrine; usar de novo em menos de 3 s mostra aviso
- [ ] Carregando um Docinho, o botão Vitrine recusa ("Leve o Docinho andando")

Anote o que falhar com print e a plataforma (PC/celular).
