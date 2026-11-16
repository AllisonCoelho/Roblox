# Nexo 3D — kit "Ruínas do Nexo" (praça e Núcleo)

> **Estado: integração escrita, ainda não vista dentro do Roblox.** Os modelos foram criados e renderizados no Blender; o código que os monta no jogo passou por testes, tipos e `rojo build`, mas ninguém abriu o resultado no Studio. As imagens em `assets/nexo/previews/` são **renders do Blender**, não capturas do jogo.

## O que mudou

Antes: a praça e o Núcleo eram montados só com `Part`, cilindros e esferas pelo servidor.
Agora: 23 malhas próprias modeladas no Blender (≈10,9 mil triângulos no kit, 54 instâncias na praça) substituem essas peças na vista do spawn. Arquivo, Obelisco, Jardim, Altar, Portais e Arena não foram tocados.

| Peça | Arquivo | Uso |
|---|---|---|
| Pedestal ancestral em três degraus, com contrafortes, tambor e selos | `pedestal_nexo` | base do Núcleo |
| Canaletas de energia do pedestal | `pedestal_energia` | emissivo |
| Garra de contenção (vértebras de metal com anéis dourados) | `garra_nexo` | 4 em volta do pedestal |
| Cristal partido em 8 estilhaços | `cristal_estilhaco_1..8` | cristal principal suspenso |
| Coração emissivo | `cristal_nucleo` | dentro do cristal |
| Fragmentos soltos (3 variações) | `cristal_fragmento_a/b/c` | órbita do Núcleo e lanternas dos pilares |
| Arco monumental partido (aduelas, trecho desabado) | `arco_partido` | 1 grande ao norte, 2 menores nas diagonais |
| Selo e veios do arco | `arco_energia` | emissivo |
| Módulo de ruína A: pilar canelado quebrado | `ruina_pilar_a` | 8 em volta da praça |
| Módulo de ruína B: muro desabando em escada | `ruina_parede_b` | 2 ao lado do arco |
| Entulho (2 variações) | `rocha_a/b` | 10 espalhados fora dos caminhos |
| Piso de lajes radiais com caminho de entrada | `praca_piso` | praça |
| Canaletas, caminho do spawn e marcas de contenção | `praca_energia` | emissivo |

## Arquivos

```text
assets/nexo/
  source/generate_nexo.py     gerador (Blender 5.3 como módulo Python); fonte da verdade
  source/nexo_master.blend    cena editável: coleção "Kit" (peças) e "Praca" (montagem)
  exports/*.fbx               uma peça por arquivo, para o 3D Importer do Studio
  previews/*.jpg              renders do Blender: spawn, nucleo, alto
src/client/Mundo/Nexo3D/
  Dados/*.luau                GERADO: geometria compacta de cada peça (base64)
  Cena.luau                   GERADO: posição, giro, escala, material e colisores de cada peça
  Malha.luau                  dados -> EditableMesh -> MeshPart
  Montagem.luau               monta a praça e os colisores locais
src/client/Nexo.client.luau   chama a montagem, esconde o provisório e anima o kit
src/server/Mundo/Nexo.luau    marca as peças antigas da praça/Núcleo com o atributo Provisorio
```

## Como os modelos chegam ao jogo

Daqui não há Roblox Studio nem permissão para enviar assets, então **não existe `MeshId` enviado**. Para o cenário vir do repositório mesmo assim, a geometria vai dentro do próprio código:

1. `generate_nexo.py` modela as peças e escreve cada uma como módulo Luau: posições (uint16 dentro da caixa da malha), cor por vértice (uint8) e triângulos (uint16), em base64.
2. No jogo, cada **cliente** decodifica os dados e cria as malhas com `AssetService:CreateEditableMesh()` e `AssetService:CreateMeshPartAsync()`. EditableMesh não replica, por isso a montagem é local.
3. `rojo build` leva tudo no `.rbxlx`; o deploy automático não precisa de nenhum passo manual.

Consequências:
- As peças visuais não colidem. A colisão vem do piso e do pedestal provisórios do servidor (escondidos, não removidos) e de caixas invisíveis locais nos pilares, muros e pés dos arcos.
- Sem texturas: a cor vem dos vértices e a superfície do material do Roblox (`Slate` na pedra, `Metal` nas garras, `Glass` nos cristais, `Neon` na energia).
- **Fallback temporário:** se `Montagem.construir` falhar, o cliente avisa no Output e o cenário antigo continua visível. Remover o cenário antigo do servidor só depois de validar o kit no Studio e no celular.

### Caminho alternativo (assets enviados)

Se o caminho por EditableMesh não servir (limite de memória no celular, por exemplo), os `.fbx` estão prontos:
1. Studio → Importar 3D → um `.fbx` por vez. O export já sai em studs, com Y para cima.
2. Conferir escala (o pedestal tem 18 studs de diâmetro) e a cor por vértice.
3. Salvar o conjunto como `assets/nexo/roblox/kit.rbxm`, mapear no `default.project.json` e trocar `Malha.criar` por um clone do modelo. `Cena.luau` continua valendo.
4. Esse envio usa a conta do dono; não foi feito.

## Regerar o kit

```bash
python -m venv .venv
```

```bash
.venv/bin/pip install bpy numpy
```

```bash
.venv/bin/python assets/nexo/source/generate_nexo.py --render
```

```bash
stylua src
```

As sementes são fixas: rodar de novo gera a mesma geometria. Para mudar a praça, editar `montar_cena()` (posições em studs do Roblox); para mudar uma peça, editar a função `fazer_*` dela. Nunca editar `Dados/` e `Cena.luau` à mão. Sem `--render` o script não gera as prévias.

Convenções: 1 unidade do Blender = 1 stud; norte = +Y no Blender e −Z no Roblox; conversão `(x, y, z) → (x, z, −y)`; pivô de cada peça no centro da base.

## Riscos conhecidos (nada disto foi observado; é o que pode dar errado)

- **API não exercitada.** `EditableMesh` foi usado conforme as definições de tipo do Roblox, sem rodar. Se a criação falhar na experiência publicada, entra o fallback.
- **Faces invertidas:** se as peças aparecerem "do avesso", inverter a ordem dos vértices em `Malha.luau` (`AddTriangle(vertices[a], vertices[c], vertices[b])`).
- **Posição do centro:** as peças são centradas na própria caixa antes de virar MeshPart. Se aparecerem deslocadas, o ajuste é em `Malha.criar`/`Montagem`.
- **Neon e cor por vértice:** se o material Neon ignorar a cor por vértice, as canaletas ficam brancas; a correção é separar as peças de energia por cor.
- **Vidro transparente** pode ter ordenação estranha entre estilhaços; alternativa: `Transparency = 0`.
- **Custo:** 54 MeshParts e a criação das malhas na entrada (a montagem cede o quadro a cada 6 peças). Memória de EditableMesh no celular não medida.
- **Colisão:** arcos e pilares só colidem para o próprio jogador (colisores locais). Outros jogadores veem todos respeitando os mesmos obstáculos porque cada cliente simula o próprio personagem.
