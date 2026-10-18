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
- [ ] Carregando um Docinho, o cartão embaixo mostra o Docinho e a seta aponta para a vitrine
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

## 5. Mundo (fase 2)

- [ ] Ao entrar, o jogador aparece na própria vitrine e o letreiro mostra o nome dele
- [ ] Os Docinhos da vitrine aparecem nos pedestais, de frente para a esteira, com etiqueta
- [ ] A esteira anda lisa (sem tremer) e os Docinhos olham para a câmera
- [ ] Aperte E num Docinho: as moedas descem, ele vai para a cabeça e você anda mais devagar
- [ ] Sem moedas / vitrine cheia / longe demais: aparece o aviso e nada é cobrado
- [ ] Entrar na própria vitrine entrega o Docinho (aviso verde) e ele aparece num pedestal
- [ ] Morrer carregando (pule da borda ou resete o personagem) devolve as moedas
- [ ] **F7** solta um Pudim Lendário: aviso para todos e dá para comprar com as moedas de teste
- [ ] Pisar no caixa verde coleta; pisar no escudo azul liga e o portão azul aparece
- [ ] Botão Vitrine leva até a vitrine; usar de novo em menos de 3 s mostra aviso
- [ ] Carregando um Docinho, o botão Vitrine recusa ("Leve o Docinho andando")
- [ ] Prédios da praça: E abre Loja, Docinhopédia e Códigos
- [ ] Com 2 jogadores (aba Test → 2 Players): cada um tem a sua vitrine e vê o Docinho na cabeça do outro

## 6. Eventos e resgate (fase 3)

Chuva de Doces (sozinho):

- [ ] **F3** liga a chuva: a faixa aparece e a contagem do HUD mostra "acontecendo"
- [ ] Docinhos caem do céu girando, pousam fora das construções e ficam quicando
- [ ] Encostar num Docinho pousado: aviso "Você pegou ..." e ele aparece na vitrine
- [ ] Encostar enquanto ainda está caindo não pega
- [ ] Depois de 60 s a chuva para e os Docinhos que sobraram somem

Resgate e escudo (aba Test → 2 Players; jogadores A e B):

- [ ] O "Resgatar" não aparece na própria vitrine, nem com escudo ligado, nem carregando algo
- [ ] B segura E por 1,5 s num Docinho de A: o Docinho vai para a cabeça de B e A vê o alerta Resgate
- [ ] A encosta em B no caminho: o Docinho volta para a vitrine de A ("Você recuperou ...")
- [ ] Se B chegar na vitrine dele: o Docinho fica com B e A recebe o aviso
- [ ] B tenta resgatar de novo logo em seguida: "Espere N s"; resgatar A de novo em menos de 60 s: bloqueado
- [ ] Vitrine com menos de 3 Docinhos: "Vitrine de iniciante: protegida"
- [ ] B resetar o personagem carregando o Docinho de A: o Docinho volta para A
- [ ] A liga o escudo: o portão azul aparece; B não passa; A passa normalmente
- [ ] B dentro da vitrine de A quando A liga o escudo: B é levado para fora
- [ ] Pisar no caixa e logo no escudo: os dois funcionam (esperas separadas)

Anote o que falhar com print e a plataforma (PC/celular).
