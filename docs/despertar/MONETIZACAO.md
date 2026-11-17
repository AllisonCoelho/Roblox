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
| Auto Inteligente | 79 | Configurações avançadas para o giro automático | 🔥 Alta | planejado |
| Presets de Auras | 49 | Salvar combinações de apresentação e aura | Alta | planejado |
| Ritual Personalizado | 99 | Novo efeito visual para o despertar | 🔥 Alta | planejado |
| **VIP do Nexo** | 199 | Título "VIP do Nexo", 👑, Rastro Real, nome dourado no chat, +10% XP da Temporada | 🔥 Alta | ✅ ativo (falta o ID) |
| Pacote Fundador | 149 | Cosméticos comemorativos e distintivo permanente | Alta | planejado |
| Títulos Especiais | 39–79 | Títulos visíveis no mundo | Média | planejado |
| Trilhas de Movimento | 49–99 | Efeitos visuais ao correr e saltar | Média | planejado |
| Aura: Aparência Alternativa | 99–199 | Variação cosmética de uma aura obtida | 🔥 Alta | planejado |
| Emotes de Vitória | 49–99 | Celebrações na Arena | Média | planejado |
| Finalizações Especiais | 99–149 | Animação visual de vitória na Arena | Média | planejado |
| **Passe de Temporada** | 299 | Trilha premium da Temporada 1 (14 cosméticos) | 🔥 Alta | ✅ ativo (falta o ID) |
| Assinatura do Nexo | 99/mês | Cosméticos mensais e conveniência | Baixa no lançamento | planejado |
| Servidor Privado | 49/mês | Espaço para jogar com amigos | Média | planejado |

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
