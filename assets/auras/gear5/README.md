# Gear 5 — Aura de Nuvens Vivas (VFX da aura equipada)

Arte-fonte e pipeline da aura Gear 5. **Prévia de Studio**: a aura ainda não está no catálogo
de sorteio (`src/shared/Dados/Auras.luau` continua com as 30 auras; chances, RNG e save intactos).

## Como ver no Studio

1. `rojo serve` e conectar o Studio; dar Play.
2. **Alt+G** liga/desliga a prévia no próprio personagem (só existe no Studio: a ação
   `PreviaAura` nem é registrada fora dele). Ao ligar, toca a manifestação (~1,2 s).
3. Andar, correr, pular, girar a câmera. Em *Ajustes*: "qualidade baixa", "movimento reduzido"
   e "ocultar efeitos dos outros" valem para a aura. Com 2+ jogadores (Test > Players) cada
   um vê a Gear 5 dos outros.

## Como funciona

- **Servidor** (`Servicos/AuraVisual.luau`): decide qual aura está ativa e grava o atributo
  `AuraVfx` no personagem (e `AuraVfxEm` quando o jogador acabou de trocar de aura, para a
  manifestação). Para auras com VFX próprio (`Shared/Dados/AurasVfx.luau`) o efeito antigo de
  partículas não é criado — sem duplicar.
- **Cliente** (`Mundo/Auras/Controlador.luau`): observa o atributo em todos os personagens e
  monta o efeito localmente (nada de centenas de peças pela rede). Um único laço `PreRender`.
- **Gear5.luau**: 9 malhas (arco, 2 lobos, 2 pontas em caracol, 2 rolos, 2 bancos) + contorno
  de anime (casca invertida gerada no cliente) + 6 mechas reaproveitadas + luz e poucas faíscas.
  - Idle: cada peça sobe/desce, balança e respira fora de fase (ciclos de 6–17 s somados).
  - Andar/correr: cada peça segue o corpo por uma mola própria; pontas e bancos atrasam mais,
    esticam para trás e soltam mechas que evaporam em 0,5 s.
  - Pulo/pouso: a mola deixa as nuvens para trás na subida; no pouso o alto amassa e volta.
  - Burst a cada 12–20 s (fase aleatória por jogador): arco incha, pontas enrolam, volta.
  - Manifestar: fiapos saem dos ombros, peças surgem em ordem com ~10% de overshoot.
  - Desequipar/trocar/morrer: fade de 0,22 s e tudo destruído.
- **LOD**: até 80 studs completo; 80–140 sem contorno/mechas/luz e a 10 Hz; além de 140 oculto.
  Qualidade baixa: sem contorno, mechas, luz, faíscas e burst — o arco nunca some.

## Arquivos

| Caminho | O que é |
|---|---|
| `source/generate_gear5.py` | gerador (Blender como módulo Python, bpy 5.3) |
| `source/gear5_clouds.blend` | cena editável |
| `exports/gear5_*.fbx` | uma peça por arquivo, para o 3D Importer (opcional) |
| `previews/*.png` | renders do Blender — **não são capturas do Roblox** |
| `src/client/Mundo/Auras/Dados/gear5_*.luau` | geometria lida pelo jogo (EditableMesh) |
| `src/client/Mundo/Auras/Gear5Pecas.luau` | pivôs e parâmetros de movimento de cada peça |

As malhas são criadas em tempo de execução com `EditableMesh` (o mesmo caminho do Nexo 3D):
nenhum `rbxassetid` publicado, nada colocado à mão no Workspace. Não há flipbook de textura:
texturas exigiriam enviar imagens ao Roblox; as mechas são malhas próprias.

Regenerar (depois rodar `stylua src`):

```bash
python assets/auras/gear5/source/generate_gear5.py --render
```
