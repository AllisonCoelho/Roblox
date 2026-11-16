# Despertar — Aura RNG

Roblox com **Luau + Rojo**, estética anime original. Repositório `AllisonCoelho/Roblox`.

## Estado

**V1 jogável.** Loop: **Despertar → sorteio no servidor → animação/revelação → índice → equipar aura → repetir**. 30 auras originais (Faísca ≈ 1 em 4,2 até 1 em 1.000.000; a chance exibida é a probabilidade real), intervalo de 1 s validado no servidor, giro automático, índice, anúncios de raros, `leaderstats` (Giros/Melhor), persistência e animação de despertar no personagem visível para todos. Visual "Tinta e Selo" (ver `docs/despertar/README.md`).

## Comandos PowerShell

```powershell
cd "$HOME\Documents\Roblox"
git pull --ff-only
rojo serve default.project.json --port 34873
```

Conecte o plugin Rojo em `localhost:34873`. Build local: `rojo build default.project.json --output build.rbxlx`. Testes: `python testes/rodar.py` (requer Luau CLI no PATH).

## Estrutura e deploy

- `src/shared/Dados/Auras.luau`: catálogo de auras e sorteio (lógica pura, testada).
- `src/shared/Dados/Perfil.luau`: dados salvos do jogador.
- `src/server/Servicos/Sorteio.luau`: Despertar/Equipar/Configurar, validados no servidor.
- `src/server/Servicos/AuraVisual.luau` e `Ranking.luau`: aura equipada no personagem e leaderstats.
- `src/server/Servicos/Dados.luau`: DataStore **`Despertar_v1`** com trava de sessão.
- `src/server/Servicos/Acoes.luau` e `src/shared/Remotos.luau`: remotes autoritativos e rate limit.
- `src/client/Mundo/Despertar.luau`: animação de despertar (pose por código, efeitos), em todos os clientes.
- `src/client/UI`: HUD, revelação, índice e avisos (`Kit.luau` tem as peças do visual).
- `docs/despertar/README.md`: especificação do MVP.

Merges revisados na `main` publicam na **experiência privada de testes**: Universe `10771776655`, Place `112360499723635`. O workflow `.github/workflows/validate.yml` e a chave `ROBLOX_API_KEY` permanecem intactos. A experiência pública não está configurada.

**Fluxo:** Claude desenvolve na branch `claude/<tarefa>`; Codex/ChatGPT revisa e integra; o dono testa no Roblox.
