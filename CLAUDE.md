# Despertar — regras para Claude e Codex

Este repositório passa a hospedar **Despertar — Aura RNG**, em **Luau + Rojo 7.7.1**.

## Responsabilidades

- Claude implementa funcionalidades em branches `claude/<tarefa>`, abre PR para `main`.
- Codex/ChatGPT revisa e corrige em branches próprias (`codex/<tarefa>`), valida os checks e controla os merges.
- O dono aprova decisões relevantes e faz os playtests no Roblox.

**Nunca compartilhar a mesma branch entre agentes nem fazer push direto na `main`.** Criar branches a partir da `main` atualizada.

## Regras técnicas

- RNG com `Random.new()` exclusivamente no servidor: ele valida cooldown, posse, equipar e anúncios. Nenhuma seed fornecida pelo cliente.
- Validar tipos, valores e frequência de todas as entradas dos remotes.
- Esquema novo no store **`Despertar_v1`**, sem ler ou modificar stores anteriores.
- Ao implementar a V1, criar `src/shared/Dados/Auras.luau` com aproximadamente 30 auras originais e pesos.
- Nomes e técnicas de animes reais: **autorizados pelo dono** (nov/2026) como referência das auras (ex.: Gear 5). Modelos, texturas, movimentos e sons são sempre próprios — nunca copiar frames, assets ou áudio dos animes. Antes do lançamento público, o dono decide sobre licença ou adaptação dos nomes.
- Não incluir chaves, tokens, senhas, arquivos .env nem dados sensíveis.
- **Não alterar os workflows CI/CD, permissões ou segredos sem autorização explícita do dono.**
- Testar `rojo build default.project.json --output build.rbxlx` e `python3 testes/rodar.py` quando disponível; relatar testes não executados.

## Publicação

A `main` publica automaticamente **somente na experiência privada**. Antes do merge, revisão e CI verde. Antes do lançamento público, playtest real de RNG, índice, efeitos multiplayer, persistência, interface e rate limit.

Ler `docs/despertar/README.md` antes de implementar o próximo recurso.
