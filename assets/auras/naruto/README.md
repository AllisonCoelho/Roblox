# Família Naruto — 2 a 9 caudas + Modo Sábio dos Seis Caminhos

**Prévia de Studio**: as 9 auras ainda não estão no catálogo de sorteio (chances, RNG e save
intactos). Depende do motor de auras da Gear 5 (PR da Gear 5).

## Como ver no Studio

Play e **Alt+N**: passa por 2 → 3 → … → 9 caudas → Seis Caminhos → desliga. Cada troca toca a
manifestação (as caudas crescem da base para a ponta). Ande, corra e pule para ver as caudas
reagirem; a explosão de poder vem sozinha a cada 9–15 s.

## Chakra vivo, não escultura

Cada cauda é uma corrente de 4 segmentos (`naruto_cauda_base`, `meio1`, `meio2`, `ponta`) que o
jogo dobra junta a junta todo quadro (`src/client/Mundo/Auras/Caudas.luau`):

- ondas correm da base para a ponta, cada cauda com fase e ritmo próprios;
- andando/correndo o leque fecha e as caudas são puxadas para trás;
- pulando/caindo elas sobem ou descem;
- explosão de poder: o leque abre, as caudas esticam e o núcleo brilha mais (faíscas);
- cada segmento é uma **meia-lua** (já vem curvado de fábrica, largo no plano da curva), com
  **chamas nas duas bordas** varrendo para a ponta;
- por dentro, uma segunda malha com **veios de fogo desenhados** (núcleo Neon mais claro) que
  aparece através da casca Neon translúcida.

| Estágio | O que muda |
|---|---|
| 2 | duas caudas grossas, onda moderada |
| 3 | leque de três; cada cauda no seu ritmo |
| 4 | chakra mais escuro e denso, pulsações bruscas |
| 5 | caudas mais pesadas + contrações de vez em quando |
| 6 | mais compridas, onda mais forte |
| 7 | caudas alternadas (ondas em oposição) |
| 8 | mais volumosas, leque quase fechando uma criatura |
| 9 | nove caudas + cabeça espectral da raposa (orelhas longas, sobrancelhas bravas, juba de chamas, boca aberta com presas, olhos amarelos com pupila em fenda, fogo interno) na manifestação e nas explosões + anel no chão |
| Seis Caminhos | dourado, caudas de luz finas e lentas, 9 esferas negras girando num halo, anel no chão e **roupa**: manto dourado no tronco com gola, 9 magatamas pretas na gola e o círculo na barriga, mangas e abas com barra em chamas (cada peça veste o membro e segue as animações) |

Todos os números de cada estágio ficam em `CaudasEstagios.luau`, gerado junto com as malhas.

## Arquivos

| Caminho | O que é |
|---|---|
| `source/generate_naruto.py` | gerador (Blender como módulo, bpy 5.3): malhas, estágios e prévias |
| `source/naruto_caudas.blend` | cena editável |
| `exports/*.fbx` | peças para o 3D Importer (opcional) |
| `previews/*.png` | renders do Blender com a mesma conta de pose do jogo — **não são capturas do Roblox** |

Regenerar (depois `stylua src`):

```bash
python assets/auras/naruto/source/generate_naruto.py --render
```
