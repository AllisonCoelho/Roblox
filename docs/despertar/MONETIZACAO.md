# Monetização do Despertar — catálogo

Fonte única no código: `src/shared/Dados/Monetizacao.luau`. Desenvolvemos **um produto por vez**.
Quando um produto fica pronto, ele passa de `planejado` para `ativo`.

**Regra:** só vendemos cosmético e conveniência. Nada muda a chance de aura, o poder em combate
ou a recompensa das Incursões.

## Status

| Produto | Preço | Benefício | Prioridade | Status |
|---|---:|---|---|---|
| **Giro Automático** | 49 | Liga o giro automático de auras | 🔥 | ✅ ativo (falta o ID) |
| **Pular Animação** | 39 | Pular o ritual, desligar animações e encurtar repetidas | 🔥 | ✅ ativo (falta o ID) |
| **Pacote do Iniciante** | 49 | Título "Despertado", distintivo 🌱, Rastro de Faíscas | 🔥 Alta | ✅ ativo (falta o ID) |
| **Auto Inteligente** | 79 | O auto-giro para sozinho em aura rara (limiar) ou nova | 🔥 Alta | ✅ ativo (falta o ID) |
| **Presets de Auras** | 49 | 5 presets de aura + cosméticos | Alta | ✅ ativo (falta o ID) |
| **Ritual Personalizado** | 99 | 3 estilos de cor do ritual (Solar, Abismo, Aurora) | 🔥 Alta | ✅ ativo (falta o ID) |
| **VIP do Nexo** | 199 | Título "VIP do Nexo", 👑, Rastro Real, nome dourado no chat, +10% XP da Temporada | 🔥 Alta | ✅ ativo (falta o ID) |
| **Pacote Fundador** | 149 | Título, distintivo ✧ e rastro Fundador | Alta | ✅ ativo (falta o ID) |
| **Títulos Especiais** | 39–79 | 3 títulos avulsos (Developer Products) | Média | ✅ ativo (faltam os IDs) |
| **Trilhas de Movimento** | 49–99 | 3 rastros avulsos | Média | ✅ ativo (faltam os IDs) |
| **Aura: Aparência Alternativa** | 99–199 | 3 recolorações da aura equipada | 🔥 Alta | ✅ ativo (faltam os IDs) |
| **Emotes de Vitória** | 49–99 | 3 celebrações ao vencer na Arena | Média | ✅ ativo (faltam os IDs) |
| **Finalizações Especiais** | 99–149 | 2 efeitos no Soberano derrotado | Média | ✅ ativo (faltam os IDs) |
| **Passe de Temporada** | 299 | Trilha premium da Temporada 1 (14 cosméticos) | 🔥 Alta | ✅ ativo (falta o ID) |
| **Assinatura do Nexo** | 99/mês | Título Membro (enquanto ativa) + 1 cosmético permanente por mês | Baixa | ✅ ativo (falta o ID) |
| **Servidor Privado** | 49/mês | Servidor do Roblox; dono com 🏠 no chat | Média | ✅ ativo (ligar no Creator Hub) |

## Como ativar um passe (dono)
1. No Creator Hub, abra a experiência → **Monetização → Passes** → **Criar passe**.
   Use o nome e o preço da tabela.
2. Copie o **ID do passe** (o número que aparece na URL ou nos detalhes).
3. Envie o ID para mim, ou coloque em `gamePassId` no produto correspondente em `Monetizacao.luau`.
4. Enquanto o ID estiver vazio, o recurso fica bloqueado e o jogo mostra "em breve na loja".
   - **Exceção:** a conta dev, na experiência de teste e no Studio, já tem o passe liberado para testar.

## Como os passes ativos funcionam
- **Giro Automático:**
  - O servidor recusa ligar `giroAutomatico` sem o passe.
  - O laço do cliente também confere o passe.
  - Quem não tem o passe e aperta AUTO vê a compra.
- **Pular Animação:**
  - Sem o passe, o servidor só aceita o próximo giro depois do tempo da animação do anterior. Assim o pulo não pode ser burlado.
  - Com o passe, tocar durante o ritual pula na hora, e as opções "desligar animações" e "encurtar repetidas" ficam liberadas.
  - Movimento reduzido e qualidade baixa continuam livres, porque são acessibilidade.
- **Perfil sem passe:** se o perfil tiver uma configuração paga ligada e o jogador não tiver o passe, o servidor a desliga ao entrar.

## Loja do Nexo (botão "✦ Loja" no HUD)
- **Abas:** Temporada, Pacotes e Cosméticos.
- **Cosméticos** (`Dados/Cosmeticos.luau`): título e distintivo sobre a cabeça, rastro ao correr e etiqueta no chat. Todos os jogadores veem. São só aparência.
- **Pacotes:** o servidor entrega os itens assim que detecta o passe (ao entrar ou ao comprar) e os equipa nos espaços vazios.
- **Temporada 1 — Despertar das Fendas** (`Dados/Temporada.luau`), de 17/11/2026 a 16/01/2027:
  - 30 níveis de 120 XP.
  - XP por fonte: giro +1 (máximo de 150 por dia, para o auto-giro não completar o passe sozinho), andar de Incursão +12, vitória +50.
  - Trilha grátis: 6 itens. Trilha premium: 14 itens.
  - O resgate é validado no servidor (nível, trilha e passe).
  - Quando a temporada acaba, o XP para de subir, mas o que já foi alcançado continua resgatável.
  - Na próxima temporada o progresso zera (novo `Temporada.ID`) e os itens obtidos continuam com o jogador.

## Segundo lote (todos os 14 ativos)
- **Itens avulsos** (Títulos, Trilhas, Aparências, Emotes, Finalizações) são **Developer Products**:
  - O dono cria cada um em Creator Hub → Monetização → Produtos de desenvolvedor, com o preço do item em `Dados/Cosmeticos.luau`.
  - O dono preenche o `developerProductId` do item.
  - A entrega acontece só em `Servicos/Compras.luau` (ProcessReceipt).
  - Cada `PurchaseId` é salvo no perfil, com confirmação do DataStore antes de responder ao Roblox. Assim uma compra nunca é entregue duas vezes nem perdida.
  - Em sessão de teste, a entrega fica para depois.
- **Assinatura do Nexo** é uma Roblox Subscription:
  - O dono cria em Creator Hub → Monetização → Assinaturas (99/mês).
  - O dono coloca o id `EXP-...` em `subscriptionId`.
- **Servidor Privado**: não tem produto no código. Ligar em Creator Hub → Acesso ao servidor → Servidores privados, com preço de 49/mês.
- **Auto Inteligente**: a parada é decidida pelo servidor (`Dados/Conveniencia.luau`).
- **Aparência Alternativa**: recolore as partículas da aura padrão. As auras com VFX próprio (Gear 5, Monarca, Caudas) recebem só o atributo `AuraAparencia`, ainda não aplicado no visual 3D.
