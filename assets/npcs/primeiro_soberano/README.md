# Primeiro Soberano — Guardião do Trono Vazio

NPC que ocupa o trono da Arena quando o servidor nasce. **Nesta fase ele só fica sentado, reage a
quem chega e conversa.** Não há duelo, coroação, título nem recompensa — a fala termina em
"Duelos por turnos — em desenvolvimento".

## O que é (e o que não é)

- **É** uma armadura de placas em **13 peças rígidas articuladas** (~3,6 mil triângulos): base
  (bacia, pernas, botas), tronco, núcleo, fissuras, cabeça com coroa quebrada, olhos, dois braços com
  ombreiras, dois antebraços com manoplas, duas meias-capas e o espadão embainhado.
- **Não é** uma malha com pele e ossos (skinning). Cada peça gira em volta da sua junta. Escolhi assim
  porque entra no jogo pelo mesmo caminho do kit do Nexo (`EditableMesh`, tudo no repositório), sem
  depender de importar um FBX riggado no Studio e publicar IDs. Os `.fbx` e o `.blend` estão aqui para
  quem quiser fazer um rig com pele depois.
- Original: coroa de cinco pontas irregulares com uma partida, ombreiras assimétricas, máscara fechada
  com duas aberturas de luz. Não é a aura Monarca das Sombras (roxa, de chamas).

## Quem faz o quê

- **Servidor** (`src/server/NPCs/PrimeiroSoberano.luau`): cria o NPC uma única vez (não duplica em
  respawn/reconexão), a colisão, o nome, o `ProximityPrompt` "Conversar" e os atributos compartilhados
  na peça `Raiz`: `Estado`, `Alvo` (quem ele olha), `Reacao` e `Alerta` (hora do servidor).
  Confere distância e espera por jogador na conversa; reação e gesto têm espera global (não empilham).
- **Cliente** (`src/client/Mundo/NPCs/PrimeiroSoberano.luau`): monta as peças 3D, esconde a reserva
  de blocos e anima a partir dos atributos. Se a montagem falhar, a reserva continua visível.

## Animações desta entrega

- **Repouso:** respiração discreta (tronco e ombros), cabeça com olhar lento e leve inclinação, dedos
  e capa com variação mínima; uma linha de luz passa pelas fissuras a cada 8–15 s.
- **Proximidade:** a cabeça acompanha o jogador mais próximo (até ±55°); quando alguém chega e não
  havia ninguém, os olhos acendem por 0,55 s (no máximo uma vez a cada 8 s).
- **Alerta:** ao conversar (no máximo a cada 25 s, compartilhado), a mão direita pressiona o braço do
  trono e uma onda de luz corre pelo piso.
- Movimento reduzido: amplitudes menores, capa parada, sem onda. Qualidade baixa: capa parada, sem onda.
- Só nomes reservados para depois: `Levantar`, `Desembainhar`, `Desafiar`, `Derrota`,
  `RetornoPeloPortal`, `Sentar`.

## Arquivos

| Caminho | O que é |
|---|---|
| `source/generate_soberano.py` | gerador (usa as ferramentas de `assets/nexo/source/generate_nexo.py`) |
| `source/primeiro_soberano.blend` | cena editável: NPC sentado no trono |
| `exports/soberano_*.fbx` | uma peça por arquivo |
| `previews/{frente,45,lateral,costas,trono}.png` | renders do Blender — **não são capturas do Roblox** |
| `src/client/Mundo/Nexo3D/Dados/soberano_*.luau` | geometria lida pelo jogo |
| `src/shared/Dados/SoberanoPecas.luau` | posição no trono, peças e juntas |

Regenerar (depois `stylua src`):

```bash
python assets/npcs/primeiro_soberano/source/generate_soberano.py --render
```
