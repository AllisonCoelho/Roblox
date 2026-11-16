# Nexo 3D — kit "Ruínas do Nexo"

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
  Cena.luau                   GERADO: posição, giro, escala e material de cada peça
  Malha.luau                  dados -> EditableMesh -> MeshPart
  Montagem.luau               monta as peças 3D (só visual; não cria colisão)
src/client/Nexo.client.luau   chama a montagem, esconde o provisório e anima o kit
src/shared/Dados/NexoColisores.luau  GERADO: caixas de colisão do kit no espaço do mundo (o servidor cria)
src/server/Mundo/Nexo.luau    marca as peças antigas da praça/Núcleo com o atributo Provisorio
```

## Como os modelos chegam ao jogo

Daqui não há Roblox Studio nem permissão para enviar assets, então **não existe `MeshId` enviado**. Para o cenário vir do repositório mesmo assim, a geometria vai dentro do próprio código:

1. `generate_nexo.py` modela as peças e escreve cada uma como módulo Luau: posições (uint16 dentro da caixa da malha), cor por vértice (uint8) e triângulos (uint16), em base64.
2. No jogo, cada **cliente** decodifica os dados e cria as malhas com `AssetService:CreateEditableMesh()` e `AssetService:CreateMeshPartAsync()`. EditableMesh não replica, por isso a montagem é local.
3. `rojo build` leva tudo no `.rbxlx`; o deploy automático não precisa de nenhum passo manual.

Consequências:
- As peças visuais não colidem. A colisão é toda do servidor: o piso, o pedestal e o esqueleto dos lugares (escondidos, não removidos) e as caixas de `src/shared/Dados/NexoColisores.luau` (pilares, muros, pés dos arcos, troncos e ruínas), geradas pelo Blender a partir dos mesmos dados que posicionam as malhas. Assim todos os jogadores colidem igual, com ou sem o kit carregado.
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
- **Colisão por caixas:** as caixas são aproximações das peças (um bloco por pilar, por pé de arco, por muro). Se alguma ficar maior ou menor que o modelo, o ajuste é em `colisores` na `montar_cena` do gerador.


## Fase 2: os seis lugares, caminhos de transição e mapa fechado

> **Estado: modelado e integrado no código, ainda não visto no Roblox.** Renders em `assets/nexo/previews/` (Blender).

O mapa ficou maior e fechado:
- Os lugares saíram de 95 para **150 studs** do centro (a Arena a 156). O chão vai até 260.
- **Anel de penhascos** em volta de tudo: 56 paredões de ~80–100 studs na frente (raio 244) e 40 de ~125–155 atrás (raio 266). Não dá para ver o que há fora.
- **Parede invisível** do servidor no raio 238 (64 painéis de 400 de altura): ninguém sai, nem pulando.
- As ilhas flutuantes de fora e a borda de rochas antiga foram removidas.

### Lugares
| Lugar | Peças 3D | Funcional (servidor) |
|---|---|---|
| Arquivo dos Ecos (NO) | plataforma em dois degraus com lajes de mármore, 9 colunas caneladas, cornija circular, cúpula de nervuras de metal aberta, console, eco flutuante girando, 6 painéis de projeção | console "Abrir índice" |
| Obelisco das Lendas (N) | base em três patamares, fuste afunilado em tambores com cintas de metal, ponta dourada, canais dourados nas quatro faces, 4 pilones com cristais flutuando, moldura de pedra do painel | painel do ranking (agora a 17 studs na frente do obelisco) |
| Jardim dos Fragmentos (SO) | gramado em montes com borda de pedras, 5 árvores de pedra viva com copa de cristais, 8 aglomerados de cristal, fissuras verdes, pedras de passagem, arco/pilares/muro em ruínas | fragmento sussurrante atrás do muro |
| Altar da Ressonância (NE) | base em três degraus com placas entalhadas, 6 monólitos com runas magenta, mesa do altar, anel de pedra partido flutuando e girando, cristal suspenso | "Em construção" |
| Portais Fragmentados (SE) | estrado com lajes cada vez mais soltas para o fundo, 2 molduras ogivais e 1 partida (blocos caídos), runas violeta e espinhos de cristal | véus de energia, "Em construção" |
| Arena dos Despertos (S) | piso com anéis e emblema, arquibancada de 240° em três degraus, 8 colunas, 4 estandartes vermelhos | "Em construção" |

### Caminhos como transição
Cada caminho é uma peça única, modelada da praça (pedra comum, 10 studs de largura) até o lugar (até 14 de largura), mudando ao longo do comprimento:
- **Arquivo:** a pedra clareia até o mármore e surgem símbolos azuis, cada vez mais densos.
- **Jardim:** a pedra ganha musgo, lajes dão lugar a tufos de vegetação e aparecem fissuras verdes; as bordas somem.
- **Portais:** o chão vai se fraturando, com lascas levantadas e inclinadas e brilho violeta saindo das frestas; as bordas somem.
- **Obelisco:** filetes dourados nas laterais e travessas douradas perto do destino.
- **Altar:** círculos de runas magenta cada vez mais frequentes.
- **Arena:** marcas vermelhas transversais, como faixas de pista.

### Como a colisão funciona agora
O servidor (`src/server/Mundo/Nexo.luau`) monta só o **esqueleto**: plataformas, colunas, monólitos, pilares dos portais, arquibancada e caminhos com as mesmas medidas dos modelos, mais as partes funcionais e as placas. Tudo que não é funcional recebe o atributo `Provisorio` e o cliente esconde ao montar o kit. As 26 caixas de `src/shared/Dados/NexoColisores.luau` (arcos, pilares e muros da praça; troncos, arco, pilares e muro do Jardim) são criadas pelo servidor (`construirColisoresKit`) e também são `Provisorio`: no cenário de reserva aparecem como blocos simples.

No cenário de reserva, um anel opaco de rocha (`BordaProvisoria`, raio 243, sem colisão) fecha a borda do mapa; ele some quando os penhascos 3D carregam. A parede invisível (`ParedeLimite`, raio 238) vale sempre.

**As medidas estão duplicadas** em `generate_nexo.py` (`LOCAIS`, `BORDAS`, `montar_locais`) e no servidor (`LOCAIS` e `construir*`). Ao mudar um, mudar o outro.

### Detalhes dos caminhos e do terreno

Quatro pares de postes com topo em Neon marcam as margens de cada caminho. O campo tem 20 canteiros com brotos luminosos e cristais, três arcos partidos e três muros desabados. Essas peças são visuais e reutilizam as malhas do kit quando possível.

### Peso
- 475 peças na cena, 77 malhas únicas e cerca de 66 mil triângulos no kit, ~2,4 MB de dados de malha em `Dados/` (decodificados por cada cliente ao entrar).
- Os maiores: `caminho_portais` (4,5 mil triângulos), `arquivo_estrutura` (5,5 mil), `caminho_*` (~4,7 mil cada), `arena_arquibancada` (3,3 mil).
- Não medido no celular. Se pesar, os primeiros cortes são o chanfro das lajes dos caminhos e o número de penhascos.

## Fase 3: Bastião das Incursões e Arena do Trono (só cenário)

Nada aqui tem sistema ligado: não há teleporte, fila, combate, título nem recompensa. As placas e a
mesa dizem isso ("Em preparação", "Duelos por turnos — em desenvolvimento").

### Bastião das Incursões
- **Onde:** 157° / 173 studs (centro em X ≈ +67,6, Z ≈ +159,2), entre os Portais e a Arena. Plataforma de
  raio 20,5; a borda fica a ~44 studs da parede invisível (238). `BASTIAO` em `generate_nexo.py` e em
  `Nexo.luau` usam os mesmos valores.
- **Diferença para os Portais Fragmentados:** pedra cinza com veios **ciano** (os Portais são violeta),
  e em vez de três molduras iguais há **um** arco assimétrico e rachado: pilar esquerdo inteiro, direito
  partido e inclinado, aduelas desalinhadas que não fecham, pedaços boiando. Dentro, um vazio quase preto
  com a borda luminosa e silhuetas de ruínas em duas profundidades (paralaxe simples).
- **Marcos de universos futuros:** três molduras com painel — Cinzas (vermelho), Maré Morta (azul),
  Crepúsculo Umbral (roxo). São só imagens.
- **Mesa dos Cartógrafos:** mapa rachado, ponteiros e fragmentos flutuando. O `ProximityPrompt` usa a
  ação `em_construcao` que já existia (mostra um aviso curto).
- **Ramal:** 22 studs, da borda da plataforma dos Portais até a do Bastião; a pedra passa de violeta para
  cinza com veio ciano. Não há ligação direta com a Arena: a arquibancada fecha aquele lado, e cortar
  a arquibancada estava fora do combinado.
- As rochas, cristais e canteiros que estavam nesse trecho do campo foram retirados (só ali).

### Arena do Trono
- A arena continua a mesma (piso, arquibancada, colunas e estandartes), agora em basalto.
- **Novo:** portão de duas colunas curvas na entrada (local z = −29), plataforma de três degraus e o
  **trono** no fundo (local z ≈ +17 a +21, oposto à entrada), **coroa** flutuante girando sobre ele,
  quatro braseiros com cristal vermelho, fissuras vermelhas que irradiam do trono, divisas douradas e
  dois círculos para os desafiantes (local x = ±7). O centro fica livre.
- O **Primeiro Soberano** (NPC sentado no trono) está documentado em `assets/npcs/primeiro_soberano/README.md`: o servidor é dono do NPC e cada cliente monta e anima a armadura.

### Colisão e reserva
Degraus, trono, colunas do portão, braseiros, pilares do portal, marcos e mesa têm caixas em
`NexoColisores.luau` (geradas com os modelos; criadas pelo servidor). A base do Bastião é um cilindro
do servidor. Se o kit 3D falhar num cliente, essas caixas aparecem como blocos simples.

### Peso (depois desta fase)
- 522 peças na cena, 103 malhas únicas, ~74 mil triângulos no kit (26 malhas novas, ~8 mil triângulos).
- 45 caixas de colisão (eram 26).
- Não medido no celular nem no Studio.
