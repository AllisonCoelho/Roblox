# Senbonzakura — Jardim de Mil Lâminas

Aura de **prévia** (Studio e Painel Dev). **Não está no sorteio**: `src/shared/Dados/Auras.luau` não foi
alterado, não há chance 1/N, DataStore, inventário nem RemoteEvent novo.

Primeira aura no **pipeline v2**: Blender → FBX → Roblox Studio (3D Importer + upload) →
`assets/roblox/AuraAssets/Senbonzakura.rbxm` → Rojo (`ReplicatedStorage.AuraAssets`) → o cliente clona
os MeshParts e anima. Não há `EditableMesh`, nem geometria em `Dados/*.luau`, nem `MeshId` atribuído em runtime.

## Status

| Etapa | Situação |
|---|---|
| Fonte Blender, gerador, FBX, textura, renders, manifesto | ✅ pronto (este PR) |
| Código do cliente (`Senbonzakura.luau`, registro na prévia) | ✅ pronto, **mas inativo sem templates** |
| Mapeamento Rojo `ReplicatedStorage.AuraAssets` → `assets/roblox/AuraAssets` | ✅ pronto (pasta vazia por enquanto) |
| Importar/publicar no Studio e salvar `Senbonzakura.rbxm` | ⏳ **etapa manual do dono** (passo a passo abaixo) |
| Teste no Studio (Play, 2 jogadores, mobile) | ⏳ não feito — `manifest.json` segue `AWAITING_STUDIO_IMPORT` |

**Renders do Blender não são teste no Roblox.** Nada aqui foi aberto no Studio.

## Peças

| Peça | Triângulos | Papel |
|---|---:|---|
| `senbon_petal_a` | 72 | pétala-lâmina de ponta dupla (destaque, pétalas soltas, rastro) |
| `senbon_petal_b` | 64 | variação comprida e estreita |
| `senbon_cluster_a` | 1112 | enxame de 16 pétalas num volume curvo |
| `senbon_cluster_b` | 1040 | enxame alongado de 15 pétalas |
| `senbon_cluster_c` | 560 | espiral assimétrica |
| `senbon_lance_a` | 104 | lança vertical facetada (pico/manifestação) |
| `senbon_lance_b` | 104 | lança arqueada e inclinada |
| `senbon_arco_a` | 144 | 3 fragmentos de corte (nunca um aro inteiro) |
| `senbon_arco_b` | 112 | 2 fragmentos cruzados |
| `senbon_selo` | 1240 | selo de chão quebrado + 5 marcas de pétala |

Tamanhos, pivôs e centros exatos: `manifest.json` (eixos Roblox) e `src/client/Mundo/Auras/SenbonzakuraPecas.luau`.

**Orçamento estimado em cena (qualidade alta, perto da câmera):** 7 enxames (~6,5 mil tri) + até 7 pétalas
soltas (~0,5 mil) + 2 arcos (~0,3 mil) ≈ **7,3 mil triângulos e até 16 MeshParts** no idle; no pico entram
9 lanças e o selo: ≈ **9,5 mil triângulos e até 26 MeshParts** por ~1,8 s. 1 `ParticleEmitter`, 1 `PointLight`.
Qualidade baixa: 5 enxames, 1 arco, sem luz, faíscas, pétalas soltas, selo nem pico. Medições reais: só no Studio.

## Passo a passo no Roblox Studio (dono)

Uma vez por revisão das malhas — não por jogador nem a cada partida.

1. Abra **o lugar do jogo** no Studio, com o **criador certo** (a conta ou o grupo dono da experiência).
2. **Home → Import 3D** (ou **File → Import 3D**). Selecione os **10 arquivos `.fbx`** de
   `assets/auras/senbonzakura/exports/` (pode importar um por vez).
3. Na janela do importador:
   - **Não** marque *Merge Meshes* / juntar peças: cada arquivo tem uma peça só e ela precisa continuar separada.
   - Escala: deixe o padrão. O jogo define o tamanho final de cada peça pelo `manifest.json`; só a
     proporção precisa bater (se vier girado, o Output avisa).
   - Confira que **não há avisos** de normais ou de geometria.
   - Deixe **Upload to Roblox** ligado, com o *Creator* = dono da experiência.
4. Se a textura `senbon_lamina.png` não vier junto (pétalas brancas), faça o upload de
   `exports/senbon_lamina.png` (Asset Manager → Images) e coloque o ID no **TextureID** de
   `senbon_petal_a/b` e `senbon_cluster_a/b/c`.
5. Materiais nos templates:
   - pétalas e enxames: **SmoothPlastic** (ou Metal) com a textura;
   - lanças, arcos e selo: o código já troca para **Neon** com as cores da paleta.
6. No Explorer, crie **um `Model` chamado `Senbonzakura`** e coloque dentro os 10 **MeshParts**, com
   **exatamente** estes nomes: `senbon_petal_a`, `senbon_petal_b`, `senbon_cluster_a`, `senbon_cluster_b`,
   `senbon_cluster_c`, `senbon_lance_a`, `senbon_lance_b`, `senbon_arco_a`, `senbon_arco_b`, `senbon_selo`.
   (Se o importador criou um Model por arquivo, tudo bem deixá-los dentro: o código procura pelo nome.)
7. Olhe as peças ao lado de um dummy R15: frente, costas e lado. Se algo estiver achatado ou girado, me avise
   — corrijo no Blender, não no runtime.
8. Clique com o botão direito no Model `Senbonzakura` → **Save to File…** → salve como
   **`assets/roblox/AuraAssets/Senbonzakura.rbxm`** (neste repositório).
9. Anote no `manifest.json` o **criador** e, se quiser, os `MeshId`/`TextureID` reais de cada peça
   (Properties do MeshPart). Nunca coloque senha, token ou chave.
10. Envie o `.rbxm` (commit na branch ou anexe aqui). Eu confiro o arquivo, o Rojo já leva para
    `ReplicatedStorage.AuraAssets.Senbonzakura` e então seguimos para o teste.
11. Teste: **Play**, segure **Alt+K** (só no Studio) ou use **Painel Dev → VFX → Senbonzakura**. Veja o Output.
12. Depois, confira num servidor de teste publicado com 2 jogadores e, se der, no celular.

Se o template faltar, tiver nome errado ou estiver sem `MeshId`, a aura **não é montada** e aparece um aviso
`[Senbonzakura] ...` no Output dizendo o que falta.

## Coreografia implementada (`src/client/Mundo/Auras/Senbonzakura.luau`)

- **Manifestação (~1,55 s):** pétalas surgem nos ombros/mãos → enxames chegam de trás dando a volta no tronco
  (overshoot ~8%) → 7 lanças sobem atrás e nos flancos, selo no chão → lanças se desfazem em pétalas,
  brilho cai ~30% e um único estalo de faíscas marca o fim. Não trava o personagem.
- **Parado:** 7 enxames em órbitas elípticas inclinadas, velocidades e sentidos diferentes (espirais que se
  cruzam), respiração de 5% a cada 6 s, giro das facetas; passam rápido e mais longe pela frente do rosto.
  Pétalas se desprendem de vez em quando; um arco curto aparece em 1 de 3 setores (costas/laterais).
- **Andando/correndo:** mola amortecida com atraso limitado; comprime à frente e alonga atrás; correndo, o
  enxame vai para trás e para os ombros, o fio aponta na direção do movimento, rastro curto de pétalas e uma
  lâmina maior corta perto do corpo por ~0,3 s.
- **Pulo/queda/pouso:** enxames baixos sobem junto; caindo, convergem e inclinam para cima; no pouso, pulso
  radial de 0,3 s e 4–7 pétalas saltando. O selo fica no último chão.
- **Pico (a cada 12–20 s, fase própria por jogador):** contrai → abre a flor (raio +60%, 9 lanças, arcos
  diagonais, selo) → um giro completo → brilho máximo só no instante central → lanças estilhaçam e tudo volta.
  Desligado em qualidade baixa e movimento reduzido. Puramente cosmético.
- **Saída (0,28 s):** encolhe para o centro, apaga, destrói a pasta e a luz. Morte/respawn/troca: o
  Controlador garante uma instância só.
- **LOD:** até 80 studs completo; 80–140 só 4 enxames + 1 arco a 10 Hz; acima de 140 oculto.
  Primeira pessoa: peças perto da lente somem só para o próprio jogador. `ocultarEfeitosAlheios` respeitado.

## Regenerar

```bash
python assets/auras/senbonzakura/source/generate_senbonzakura.py --render
```

Use o Python com `bpy` 5.3 (Blender como módulo). Semente fixa: as malhas, o manifesto e o
`SenbonzakuraPecas.luau` saem iguais. Mudou a malha? Reimporte no Studio e salve o `.rbxm` de novo.

## Propriedade intelectual

“Senbonzakura” vem de *Bleach*. O dono autorizou nomes de anime como referência (CLAUDE.md); malhas,
textura e movimento aqui são próprios. Antes de vender como item premium, decidir licença ou nome
original (ex.: *Jardim das Mil Lâminas*).
