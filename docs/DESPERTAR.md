# Despertar — Aura RNG (novo rumo do projeto)

> Documento de handoff para o **Codex/ChatGPT**. Explica a nova ideia do jogo, o fluxo de trabalho entre Claude, Codex e o dono, e o que fazer com o código do **Docinhos**, que está sendo **descartado**.

---

## 1. Decisão

- O jogo **Docinhos** foi **descontinuado**. A ideia não será mais desenvolvida.
- No lugar dele, o repositório passa a ser do **Despertar**, um jogo de **Aura RNG** com estética anime original.
- Vai ficar **no mesmo repositório** e ser publicado na **mesma experiência privada de teste**:
  - Universe ID: `10771776655`
  - Place ID: `112360499723635`
  - Secret: `ROBLOX_API_KEY` (já configurado; não alterar)
- O workflow `.github/workflows/validate.yml` **continua igual**. Nenhuma mudança de CI/CD, permissões ou chaves sem autorização explícita do dono.

---

## 2. A ideia do jogo

### Loop principal
1. O jogador clica em **"Despertar"**.
2. O **servidor** sorteia uma aura com raridade (1 em 2 … 1 em 1.000.000).
3. A aura nova vai para o **índice** (coleção). O jogador pode **equipar** a aura que quiser, e ela aparece em volta do personagem para todo mundo ver.
4. Repete: "só mais um giro".

### Por que prende
- Expectativa de tirar algo raro a cada clique.
- **Anúncio global** no servidor quando alguém tira uma aura rara: status e inveja saudável.
- Coleção (índice) com progresso visível.
- Ranking de giros e da aura mais rara.

### Escopo da Versão 1 (MVP)
| Sistema | Descrição |
|---|---|
| Sorteio | ~30 auras com pesos, sorteadas **só no servidor**. Cooldown entre giros (~1 s), validado no servidor. |
| Auras | Apenas partículas, cores, luz e brilho (ParticleEmitter, Light, Highlight/Beam). Sem modelos 3D complexos. |
| Equipar | O jogador escolhe uma aura do seu índice; o servidor valida a posse e aplica o efeito no personagem. |
| Índice | Tela com todas as auras: as obtidas aparecem coloridas, as não obtidas como silhueta "???" com a raridade. |
| Anúncio global | Mensagem no chat/UI para o servidor quando sai uma aura de raridade ≥ 1 em 1.000 (configurável). |
| Ranking | Leaderstats: **Giros** e **Melhor aura** (raridade). |
| Save | DataStore com: giros totais, auras obtidas (contagem), aura equipada, configurações. |
| Giro automático | Toggle simples (já validado no servidor pelo mesmo cooldown). |

### Fora da V1 (próximas versões)
- Poções de sorte (multiplicador temporário)
- Recompensa diária, códigos e metas de likes
- Eventos de tempo limitado (auras exclusivas)
- Game passes: giro mais rápido, sorte x2, slots
- Trocas, auras animadas mais elaboradas, títulos e cutscene para auras ultrarraras

### Regras de conteúdo
- Estilo **anime original**. **Proibido** usar nomes, personagens, técnicas ou marcas de animes reais (Naruto, Dragon Ball, Sharingan, Super Saiyajin etc.), por risco de DMCA.
- Nomes das auras: originais (ex.: "Brasa Sussurrante", "Eco do Vazio", "Lótus Celestial").

### Regras técnicas
- **Servidor é a autoridade**: sorteio, cooldown, posse de auras, aura equipada e anúncios. O cliente só pede e exibe.
- Todo RemoteEvent/RemoteFunction valida tipos, valores e frequência (rate limit).
- RNG no servidor com `Random.new()`, sem semente vinda do cliente.
- Tabela de auras em `src/shared/Dados/Auras.luau` (id, nome, raridade "1 em N", cores, parâmetros de partículas).
- DataStore com nome novo (ex.: `Despertar_v1`), **sem reaproveitar** `Docinhos_v1`.

---

## 3. Fluxo de trabalho

| Quem | Papel |
|---|---|
| **Claude** (Claude Code) | Implementa em branches `claude/<tarefa>`, valida com `rojo build`, abre PR para `main`. |
| **Codex/ChatGPT** | Revisa PRs, corrige, acompanha CI e controla merges na `main`. Também pode implementar em branches próprias (ex.: `codex/<tarefa>`). |
| **Dono do projeto** | Aprova mudanças relevantes, testa a jogabilidade na experiência privada. |

### Regras para não haver conflito
1. **Nunca** os dois agentes trabalham na mesma branch ao mesmo tempo.
2. Ninguém faz commit direto na `main`. Tudo entra por PR.
3. Antes de começar uma tarefa, atualize a branch a partir da `main` mais recente.
4. Merge na `main` = publicação automática na experiência privada. Só faça merge do que foi revisado.
5. As regras completas estão em `CLAUDE.md`, que vale para os dois agentes.

### Ciclo de uma funcionalidade
```
Dono pede → Claude implementa em claude/<tarefa> → PR para main
→ Codex revisa/corrige → CI verde → merge → publica na experiência privada
→ Dono testa no Roblox → feedback → próxima tarefa
```

---

## 4. Limpeza do Docinhos (tarefa para o Codex)

O Codex desenvolveu boa parte do Docinhos. Pedimos que ele ajude a **remover tudo o que é específico do Docinhos**, deixando o repositório limpo para o Despertar. Fazer em uma branch própria (ex.: `codex/remover-docinhos`) com PR para `main`.

### Remover (específico do Docinhos)
- `assets/docinhos/`
- `docs/design/` (imagens e docs de identidade, mapa, vitrine, HUD, álbum, loja, modelos 3D e playtest do Docinhos)
- `src/shared/Dados/`: `Catalogo`, `Esteira`, `Mapa`, `Modelos`, `Presentes`, `Loja`, `Missoes`, `Evento`, `Economia` (os que forem só do Docinhos)
- `src/server/Servicos/`: `Esteira`, `Lotes`, `Vitrine`, `Presentes`/`Recompensas` e afins do Docinhos
- `src/server/Mundo/Construtor.luau` (mapa do Docinhos)
- `src/client/Mundo/EsteiraVisual.luau`, `src/client/Mundo/Prompts.luau`
- `src/client/UI/Telas/`: `MeusDocinhos`, `Album`, `Presentes`, `Loja`, `Missoes` (se não forem genéricas)
- `src/client/UI/Popups/`: `NovoDocinho`, `Chuva`, `Resgate`, `Tutorial` (do Docinhos)
- Testes em `testes/` que testam lógica do Docinhos
- Referências a "Docinhos" no `README.md`

### Avaliar e reaproveitar (genérico, pode servir ao Despertar)
- `src/server/Servicos/Dados.luau`: carregamento/salvamento com trava de sessão. **Manter a lógica**, trocar o nome do store para `Despertar_v1` e o formato dos dados.
- `src/server/Servicos/Sessao.luau`, `Acoes.luau` (rate limit/validação de remotes, se houver)
- `src/shared/Remotos.luau`, `Config.luau`, `Formato.luau`, `Tema.luau`, `Health.luau`
- `src/client/UI/`: `App`, `Navegacao`, `Componentes`, `Escala`, `Estado`, `Visual`, `Telas/HUD`, `Telas/Ajustes`, `Telas/Codigos`, `Popups/Avisos`
- `testes/rodar.py` (infra de testes)

### Critérios de aceite da limpeza
- `rojo build default.project.json --output build.rbxlx` passa.
- O jogo abre no Studio sem erros no Output (pode ficar vazio, só com a base).
- Nenhuma referência restante a "Docinho(s)" no código (`grep -ri docinho src`).
- CI (`validate.yml`) verde, **sem alterar o workflow**.
- No PR: listar o que foi removido, o que foi mantido e por quê.

> Se o Codex fizer a limpeza primeiro, o Claude implementa o Despertar V1 em cima da `main` limpa. Se o Claude começar antes, a V1 pode já incluir a remoção. Combinar com o dono para não fazer os dois ao mesmo tempo.

---

## 5. Como testar (Studio e experiência privada)
1. `rojo serve` e conectar o plugin do Rojo no Studio, **ou** abrir o `.rbxlx` gerado pelo `rojo build`.
2. Play: clicar em "Despertar" várias vezes. A aura deve aparecer, o índice deve atualizar e o leaderstats deve contar os giros.
3. Testar com 2 jogadores (Test → Clients and Servers): o anúncio global aparece para ambos e a aura equipada é visível para o outro jogador.
4. Sair e entrar de novo: giros, índice e aura equipada devem persistir (em servidor publicado ou com o DataStore do Studio habilitado).
5. Spam de clique / exploit: o servidor deve ignorar giros fora do cooldown.
