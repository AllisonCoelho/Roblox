# Roblox — Projeto base

Projeto Roblox em Luau, gerenciado por GitHub e sincronizado com Roblox Studio via [Rojo](https://rojo.space/).

## Rodar no Windows

1. Instale Git, Roblox Studio e Rojo.
2. Execute `rojo plugin install` para instalar o plugin no Studio.
3. Clone: `git clone https://github.com/AllisonCoelho/Roblox.git`.
4. Entre na pasta: `cd Roblox`.
5. Rode `rojo serve default.project.json` e **deixe o terminal aberto**.
6. No Roblox Studio, abra um Baseplate, acesse Plugins > Rojo > Connect e confirme a sincronização.

O Rojo sincroniza **arquivos locais** para o Studio. Para receber mudanças feitas no GitHub pelo ChatGPT, execute `git pull` na pasta local e mantenha o Rojo conectado.

## Estrutura

- `src/server`: scripts de servidor
- `src/client`: scripts locais de jogador
- `src/shared`: módulos compartilhados
- `default.project.json`: mapeamento Rojo
- `.github/workflows`: CI de validação

## Segurança e publicação

Não inclua chaves Open Cloud no Git. A futura variável `ROBLOX_API_KEY` deve ficar em GitHub Actions Secrets. Publicação em produção requer configuração e aprovação específicas; **nenhuma publicação no Roblox acontece só por subir este repositório**.

> Estado atual: projeto inicial de código e sincronização. Conexão com Open Cloud e testes de publicação ainda precisam ser configurados nas contas Roblox/GitHub.
