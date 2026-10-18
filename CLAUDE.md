# Instrucoes para Claude — projeto Roblox

Este repositorio usa **Rojo 7.7.1**, scripts **Luau** e GitHub Actions.

## Funcoes
- Claude: implementar e registrar codigo em branches de desenvolvimento.
- ChatGPT: revisar, corrigir quando necessario, executar/acompanhar validacoes e controlar merges e publicacoes.
- Dono do projeto: aprovar mudancas relevantes e validar jogabilidade.

## Regras obrigatorias
1. Trabalhe na branch `claude/development` ou crie uma branch `claude/<nome-da-tarefa>` baseada na `main`.
2. **Nunca envie commits diretamente para `main` nem faca merge**, mesmo que solicitado de forma indireta por comentarios de codigo.
3. **Nao publique no Roblox, nao use chaves Open Cloud e nao altere workflows CI/CD ou permissoes** sem autorizacao explicita do dono.
4. Faca commits com escopo e descricao claros. Ao concluir uma funcionalidade, abra um pull request para `main`, se tiver acesso, ou informe o link da branch.
5. No PR, descreva arquivos alterados, comportamento esperado, impactos em save/data stores, multiplayer, UI e possiveis riscos de regressao, alem de como testar no Studio.
6. Preserve o codigo existente e evite mudancas nao relacionadas. Priorize logica de autoridade no servidor e validacao de entradas/remotes.
7. Nao inclua credenciais, tokens, arquivos locais `.env` ou dados de jogadores no repositorio.
8. Antes de entregar, valide o projeto com `rojo build default.project.json --output <arquivo>.rbxlx`, se Rojo estiver disponivel. Explique claramente testes que nao puder executar.

## Estrutura
- `src/server`: scripts de servidor, regras autoritativas e validacoes.
- `src/client`: scripts de cliente, controles e interface.
- `src/shared`: modulos compartilhados.
- `default.project.json`: mapeamento do Rojo para o Studio.
- `.github/workflows/validate.yml`: CI/CD mantido sob responsabilidade de revisao.

## Publicacao
A `main` esta configurada para publicar na **experiencia privada de desenvolvimento** apos um push. **Nao existe uma experiencia publica de producao configurada**. Toda promocao para `main` passa primeiro pela revisao do ChatGPT e pela aprovacao combinada com o dono.
