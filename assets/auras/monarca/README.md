# Monarca das Sombras

**Prévia de Studio**: a aura ainda não está no catálogo de sorteio (chances, RNG e save intactos).
Usa o motor de auras da Gear 5 (Controlador, MalhaNuvem, atributo `AuraVfx`).

## Como ver no Studio

Play e **Alt+M** liga/desliga. Para ver tudo:

1. **Ligar**: as chamas sobem uma a uma, a sombra se abre no chão e a coroa desce sobre a cabeça.
2. **Andar/correr**: sombras menores, com olhos, perseguem o jogador pelo chão em fila; as chamas
   ficam para trás e voltam.
3. **Ficar parado ~5,5 s** (no chão): quatro soldados das sombras sobem de poças em volta do
   jogador e montam guarda virados para fora. Ao primeiro passo, afundam de volta.
4. **Pular**: a sombra fica no chão e encolhe um pouco.
5. A cada 12–20 s: explosão de poder (chamas crescem, a borda brilha, todos os olhos abrem).

## Como é feito (`src/client/Mundo/Auras/Monarca.luau`)

- **Chamas**: 9 labaredas (duas na frente, baixas) + 2 cortes em meia-lua, modelados no Blender.
  Três camadas dão o degradê: corpo Neon roxo quase preto, **pontas e garras em roxo vivo**
  (malha própria, pulsando) e **borda roxa brilhante** (casca invertida gerada no cliente).
  Cada chama segue o tronco/raiz por mola própria, treme como fogo e balança.
- **Labaredas pequenas**: 12 chamas menores nascem em volta do corpo (inclusive na frente, abaixo
  dos ombros), sobem, afinam e somem, cada uma no seu ciclo.
- **Coroa**: flutua sobre a cabeça (segue a cabeça), com gema brilhante.
- **Sombra com olhos**: poça irregular no chão (raycast: fica no chão mesmo no pulo) com 12 pares
  de olhos que piscam cada um na sua hora.
- **Sombras seguindo**: 5 poças menores com olhos, em fila, cada uma perseguindo a da frente.
- **Soldados**: quatro tipos, cada um com malha e jeito próprios; a ordem em volta do jogador é
  sorteada. Corpo escuro com borda roxa e olhos brilhantes; cada um acha o próprio chão.
  - **Cavaleiro comandante** (estilo Igris): alto e esguio, elmo com penacho longo, ombreiras em
    lâminas, capa comprida, espada longa cravada à frente. Imóvel.
  - **Gigante**: largo, ombros enormes, elmo pequeno com chifres laterais, escudo-torre e
    machado duplo no ombro; visor em fenda única. Respira pesado.
  - **Mago**: encapuzado, manto em trapos sem pernas (flutua), presas, cajado com lua e orbe
    brilhante, chama na outra mão.
  - **Rei-formiga** (estilo Beru): magro, pernas de inseto, braços longos com garras, mandíbulas,
    antenas, abdômen com ferrão e quatro asas. Inquieto, se remexe.
- Qualidade baixa: 2 soldados, sem sombras seguindo, sem lascas, sem explosão. Respeita movimento
  reduzido, ocultar efeitos dos outros, LOD (80/140 studs) e primeira pessoa.

## Arquivos

| Caminho | O que é |
|---|---|
| `source/generate_monarca.py` | gerador (Blender como módulo, bpy 5.3) |
| `source/monarca.blend` | cena editável |
| `exports/*.fbx` | peças para o 3D Importer (opcional) |
| `previews/*.png` | renders do Blender — **não são capturas do Roblox** |

Regenerar (depois `stylua src`):

```bash
python assets/auras/monarca/source/generate_monarca.py --render
```
