# Importar as criaturas do Corredor no Roblox Studio

São 12 personagens blocados, no estilo do Roblox, feitos no Blender por `generate_criaturas.py`: um lacaio e um chefe por fase. **O jogo já funciona sem importar nada**, porque monta as mesmas peças pelo kit do Nexo (EditableMesh). Quando você importar, ele passa a usar o modelo importado **sozinho**, sem mudar código.

| Arquivo (`exports/`) | Criatura | Fase |
|---|---|---|
| `lasca_errante.fbx` | Lasca Errante | 1 |
| `sentinela_limiar.fbx` | Sentinela do Limiar (chefe) | 1 |
| `broto_vidro.fbx` | Broto de Vidro | 2 |
| `anciao_bosque.fbx` | Ancião do Bosque (chefe) | 2 |
| `cinzento.fbx` | Cinzento | 3 |
| `senhor_brasas.fbx` | Senhor das Brasas (chefe) | 3 |
| `marujo_afogado.fbx` | Marujo Afogado | 4 |
| `capitao_abissal.fbx` | Capitão Abissal (chefe) | 4 |
| `estatua_viva.fbx` | Estátua Viva | 5 |
| `arcanjo_partido.fbx` | Arcanjo Partido (chefe) | 5 |
| `eco_vazio.fbx` | Eco do Vazio | 6 |
| `devorador_estrelas.fbx` | Devorador de Estrelas (chefe) | 6 |

Cada FBX tem uma MeshPart por peça, com o nome da peça: `tronco`, `cabeca`, `braco_e`, `braco_d`, `perna_e`, `perna_d` e, no Arcanjo, `asa_e`/`asa_d`. As peças acesas terminam em `_brilho` e as de vidro em `_vidro`. Há também uma peça pequena `Origem`, no chão, que o jogo usa de referência. As cores vêm **por vértice** (sem textura para subir).

## Passo a passo

1. No Studio, abra o lugar do jogo: **Home → Import 3D** e escolha o `.fbx`.
2. Na janela do importador:
   - deixe **Import Only As Model** marcado;
   - **não** marque *Ignore Vertex Colors*: as cores estão nos vértices;
   - clique em **Import**.
3. Em **ReplicatedStorage**, crie uma **Folder** chamada exatamente `CorredorModelos` (uma vez só, para os 12).
4. Arraste o Model importado para dentro de `CorredorModelos` e **renomeie** com o nome do arquivo sem `.fbx` (ex.: `lasca_errante`).
5. Confira duas coisas nas MeshParts:
   - a cor deve ser **branca** (255, 255, 255), porque a cor por vértice é multiplicada por ela;
   - as peças `_brilho` ficam com **Material = Neon**. O jogo também troca isso sozinho.
6. **Salve e publique** o lugar.

## Testar

Entre no Corredor dos Perdidos (Portais Fragmentados → painel → fase 1). As criaturas aparecem com o modelo importado.

**Ajustes sem mudar código** (atributos no Model dentro de `CorredorModelos`):
- **Grande ou pequeno demais?** Atributo **Escala** (Number), ex.: `1.2`.
- **Virado de costas?** Me avise: o FBX sai com a frente em -Z, igual ao kit.

A animação (respirar, atacar, levar golpe, cair e voltar) é por código, peça por peça. **Não precisa publicar animação.**

## Refazer

```
python assets/corredor/criaturas/generate_criaturas.py --render
```

Isso refaz as malhas do kit, `src/shared/Dados/CriaturasVisual.luau`, os FBX e as prévias. Não testei a importação no Studio daqui: os FBX foram gerados e conferidos só no Blender.
