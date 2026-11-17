# Importar os inimigos das Incursões no Roblox Studio

São 6 modelos riggados (com ossos) e com textura, feitos no Blender por
`generate_inimigos.py`. O jogo já funciona sem eles (usa as malhas simples do kit); quando você
importar, ele passa a usar estes **sozinho**, sem mudar código.

| Arquivo (`exports/`) | Inimigo |
|---|---|
| `inc_cinzas_sombra.fbx` | Sombra das Cinzas (chifres de rocha, rachadura em brasa) |
| `inc_mare_sombra.fbx` | Sombra da Maré Morta (nadadeiras, cracas, algas) |
| `inc_umbral_sombra.fbx` | Sombra Umbral (capuz, farrapos, cauda de fumaça) |
| `inc_cinzas_guardiao.fbx` | Arauto das Brasas (chefe) |
| `inc_mare_guardiao.fbx` | Cavaleiro Afogado (chefe) |
| `inc_umbral_guardiao.fbx` | Espectro do Ocaso (chefe) |

Cada FBX tem: o esqueleto (`..._Rig`), o corpo com a textura embutida (PNG também em `texturas/`)
e a malha de brilho (`..._Brilho`: olhos, garras, núcleo).

## Passo a passo (para cada um dos 6)

1. Baixe a pasta `assets/incursoes/inimigos/exports/` do GitHub (ou o repositório inteiro).
2. No Studio, abra o lugar do jogo. Aba **Home** (ou **Avatar**) → **Import 3D**.
3. Escolha o `.fbx`. Na janela do importador:
   - **Rig General → Rig Type: Custom** (não é R15: tem ossos próprios).
   - Deixe **Import Only As Model** marcado e **Anchored** desmarcado (o jogo ancora).
   - Escala: tanto faz — o jogo ajusta a altura sozinho.
   - Clique **Import**. Aparece um Model com as MeshParts e os Bones dentro.
4. Em **ReplicatedStorage**, crie uma **Folder** chamada exatamente `IncursoesModelos`
   (só uma vez, para os 6).
5. Arraste o Model importado para dentro de `IncursoesModelos` e **renomeie** com o nome do arquivo
   sem `.fbx` (ex.: `inc_cinzas_sombra`). O nome precisa ser idêntico.
6. Dentro do Model, selecione a MeshPart que termina em `_Brilho` e mude **Material** para **Neon**
   (o jogo pinta com a cor do universo).
7. Confira a textura: selecione o corpo; em **TextureID** deve haver uma imagem. Se ficou vazio,
   importe `texturas/<nome>_cor.png` (Asset Manager → Import) e cole o ID em **TextureID**.
8. **Salve e publique** o lugar (File → Publish to Roblox), senão os modelos só existem no seu Studio.

## Testar

- Play → vá ao Bastião → Mesa dos Cartógrafos → **Entrar na fila** (Cinzas). Em ~12 s a partida
  começa. As Sombras devem aparecer com o modelo novo; o Guardião aparece no 5º andar.
- **Virado de costas?** No Model em `IncursoesModelos`, adicione o atributo **Giro** (Number) = `180`.
- **Grande ou pequeno demais?** Atributo **Escala** (Number), ex.: `1.2` ou `0.8`.
- Os ossos são animados por código (andar, respirar, atacar, morrer): **não precisa publicar
  animação**. Se algum membro dobrar para o lado errado, me diga qual — ajusto os eixos em
  `src/client/Mundo/Incursoes/Ossos.luau`.

## Ossos (nomes que o jogo procura)

`Raiz, Quadril, Tronco, Peito, Cabeca, Braco.L/R, Antebraco.L/R, Coxa.L/R, Canela.L/R`
(+ `Cauda1..3` na Sombra Umbral, `Asa.L/R` no Espectro do Ocaso). Não renomeie os ossos.

## Limites

- Corpo de 8 a 11 mil triângulos (o Roblox aceita até ~20 mil por malha).
- Não testei a importação no Studio daqui: os FBX foram gerados e conferidos só no Blender.
