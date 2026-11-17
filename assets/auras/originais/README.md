# Auras originais v2 — lote inicial (7)

Catálogo das 67 auras: `src/shared/Dados/AurasOriginaisV2.luau`, separado do sorteio. `Auras.luau` não
mudou. Trocar o sorteio exige aprovação do dono e um plano de migração dos IDs antigos.

Lote inicial, com 1 de cada família visual: Centelha do Nexo, Gelo de Néon, Prisma Partilhado,
Arquivista Espectral, Coração de Fênix, Leviatã Astral e Soberania do Vazio.

**Status: primeiro passe de arte, `AWAITING_STUDIO_IMPORT`.** As prévias em `<id>/previews/` são renders
do Blender, não do Roblox. Nada foi testado no Studio.

## Arquivos
- `source/generate_originais.py`: gerador bpy das 7 auras, com semente fixa. Escreve os FBX, os
  manifestos, o `.blend` e `src/client/Mundo/Auras/Originais/Definicoes.luau`, que guarda tamanhos,
  pivôs e comportamento de cada peça.
- `<id>/exports/*.fbx`, `<id>/manifest.json`, `<id>/previews/{front,three_quarter,side,back}.png`.
- `Motor.luau`: motor único que clona os templates e anima as peças de três jeitos:
  - **âncora:** ponto fixo no corpo;
  - **órbita:** elipse em volta do corpo;
  - **pêndulo:** arco atrás do avatar.

  Também cuida da mola ao andar e pular, da formação de corrida, do pico a cada 12–20 s, da
  manifestação com efeito especial, da saída, do LOD 80/140, da qualidade baixa, do movimento
  reduzido e da primeira pessoa.

## Importar no Studio (por aura)
1. Use **Import 3D** em `assets/auras/originais/<id>/exports/*.fbx`, sem *Merge Meshes* e com
   **Upload to Roblox** no criador da experiência.
2. Crie um **Model chamado `<id>`** (ex.: `gelo_de_neon`) com os MeshParts, mantendo os nomes dos FBX.
   Cor e material são definidos pelo código.
3. Use **Save to File** como `assets/roblox/auras_originais/<id>.rbxm` e me envie o arquivo.
4. Teste em **Painel Dev → VFX → "v2 · …"**. Sem o `.rbxm`, a aura não monta e o Output avisa.
