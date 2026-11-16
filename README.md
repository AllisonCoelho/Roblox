# Despertar — Aura RNG

Roblox com **Luau + Rojo**, estética anime original. Repositório `AllisonCoelho/Roblox`.

## Estado

**Base técnica limpa.** A V1 ainda não está implementada: no Studio, uma tela temporária apenas confirma o carregamento do perfil. O futuro loop será: **Despertar → sorteio no servidor → índice → equipar aura → repetir**.

V1 planejada: cerca de 30 auras (1 em 2 até 1 em 1.000.000), cooldown de aproximadamente 1 segundo, partículas e luzes, índice, anúncios de raros, `leaderstats`, persistência e giro automático. Sem nomes, marcas ou técnicas de animes existentes.

## Comandos PowerShell

```powershell
cd "$HOME\Documents\Roblox"
git pull --ff-only
rojo serve default.project.json --port 34873
```

Conecte o plugin Rojo em `localhost:34873`. Build local: `rojo build default.project.json --output build.rbxlx`. Testes: `python testes/rodar.py` (requer Luau CLI no PATH).

## Estrutura e deploy

- `src/shared/Dados/Perfil.luau`: novo perfil da experiência, sem lógica RNG ainda.
- `src/server/Servicos/Dados.luau`: DataStore **`Despertar_v1`** com trava de sessão.
- `src/server/Servicos/Sessao.luau`: lógica pura da trava.
- `src/server/Servicos/Acoes.luau` e `src/shared/Remotos.luau`: remotes autoritativos e rate limit.
- `src/client/UI`: infraestrutura genérica de interface, a ser redesenhada.
- `docs/despertar/README.md`: especificação do MVP.

Merges revisados na `main` publicam na **experiência privada de testes**: Universe `10771776655`, Place `112360499723635`. O workflow `.github/workflows/validate.yml` e a chave `ROBLOX_API_KEY` permanecem intactos. A experiência pública não está configurada.

**Fluxo:** Claude desenvolve na branch `claude/<tarefa>`; Codex/ChatGPT revisa e integra; o dono testa no Roblox.
