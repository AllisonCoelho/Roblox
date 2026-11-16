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
- **Gear5.luau**: o arco não é uma peça — ele aparece da SOMA de várias correntes de fumaça que
  nascem nos ombros e nas costas (7 malhas presas a membros + contorno de anime gerado no
  cliente + 6 mechas reaproveitadas + luz e poucas faíscas).
  - `ombros` (tronco): volumes grandes e sobrepostos de onde as correntes saem.
  - `corrente_a` (tronco): a maior; sobe do ombro esquerdo, cruza por cima da cabeça e termina
    numa espiral grande.
  - `corrente_b` (tronco): sobe do ombro direito, passa por trás da A e termina em ponta comprida.
  - `corrente_c` (tronco): do meio das costas, colada atrás da cabeça, termina em espiral.
  - `lateral_esq` / `lateral_dir` (tronco): saem dos ombros para fora; espiral e ponta.
  - `cintura` (raiz): correntes finas que saem da parte de baixo das costas e abraçam a cintura.
  - Volumes: elipsoides grandes sobrepostos (metaballs), sem bolhinhas — lisos, não espuma.
    Pontas, espirais e chamas são tubos afinados até ficarem afiados.
  - Cada corrente segue o membro por uma mola própria (as compridas atrasam mais), respira e
    balança em volta da raiz dela no ombro. Burst, manifestação, pulo e saída como antes.
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
