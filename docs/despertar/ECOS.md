# Ecos e Núcleos (pets)

Terceira etapa do [plano dos Pontos de Aura](PLANO_PONTOS_DE_AURA.md).

**Status:** implementado e testado fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio.**

## Conceito

Os **Ecos** são criaturas guardadas nos **Núcleos**, as sementes de cristal que sobraram de cada mundo do Corredor dos Perdidos. O **Cristal do Nexo**, no meio da praça, desperta os Núcleos em troca de Fragmentos. Os seis Núcleos ficam orbitando o Cristal: os que a pessoa já pode abrir acendem, os outros ficam apagados.

Cada mundo tem uma linguagem visual própria, pensada para não parecer bicho genérico de simulador:

| Núcleo (preço) | Mundo e material | Ecos (chance) |
|---|---|---|
| Limiar (8) | pedra viva e cristal violeta | **Lasquinho** (72%), lasca de cristal com um olho só · **Mariposa de Vitral** (24%), asas de vidro colorido presas por chumbo · **Lanterneiro** (4%), pedaço de pilar que carrega uma lanterna |
| Bosque (20) | flora de vidro verde-água | **Sininho de Vidro** (70%), flor-sino · **Raposa Prisma** (26%), facetas com cauda de folha de cristal · **Cervo Cantor** (4%), chifres de cristal acesos |
| Dunas (50) | obsidiana e brasa | **Fagulha** (70%), brasa numa gaiola de obsidiana · **Escaravelho Solar** (26%), empurra um pequeno sol · **Salamandra de Obsidiana** (4%), rachaduras em brasa |
| Maré (120) | água presa no ar | **Peixe-Bolha** (70%), carrega o próprio mar numa bolha · **Água-viva Lanterna** (26%) · **Baleia Celeste** (4%), com nuvens e estrelas nas costas |
| Catedral (300) | mármore, ouro e vitral | **Sino Alado** (70%) · **Coruja Rosácea** (27%), o rosto é uma rosácea de vitral · **Querubim Partido** (3%), cabeça de anjo rachada em ouro com auréola |
| Vazio (700) | facetas escuras costuradas por estrelas | **Olho Errante** (70%), entre dois aros · **Gato Constelação** (27%), estrelas ligadas por linhas · **Dragão Estelar** (3%), uma constelação com forma de dragão |

Os preços estão em Fragmentos. Raridades vão de Comum a Divino, com as mesmas cores das auras.

**Prismático:** 1 em 50 Ecos nasce prismático, com bônus em dobro, contorno de arco-íris e faíscas.

## Regras (`Dados/Pets`)

**Abrir um Núcleo**
- É preciso estar perto do Cristal e ter concluído a fase do mundo dele no Corredor.
- Abre 1 ou 3 de uma vez.
- Paga só com Fragmentos e as chances ficam exibidas, por isso não depende de Robux nem de política de item aleatório pago.

**Bônus de cada Eco**
- Cada Eco dá um bônus: **+% Pontos de Aura**, **+% Sorte do giro** ou **+% Fragmentos** no Corredor.
- Os bônus dos equipados se somam.
- A sorte continua presa ao teto de 20x.

**Espaços e coleção**
- Começa com 3 espaços equipados. Concluir as fases 3 e 6 do Corredor abre mais um espaço cada.
- A coleção guarda até 60 Ecos.
- **Libertar** um Eco devolve 25% do preço do Núcleo; precisa de dois toques e o Eco tem de estar desequipado.
- O primeiro Eco já vai equipado. **Equipar melhores** escolhe os mais fortes.

## Onde está

| Arquivo | Papel |
|---|---|
| `assets/pets/source/generate_pets.py` | Os 18 Ecos e os 6 Núcleos no Blender (`--render` refaz as prévias) |
| `assets/pets/previews/*.jpg` | Renders do Blender (não são prints do Roblox) |
| `src/client/Mundo/Nexo3D/Dados/pet_*.luau`, `nucleo_*.luau` | Malhas (~14 mil triângulos no total) |
| `src/shared/Dados/PetsVisual.luau` | Peças de cada Eco e juntas das asas (gerado) |
| `src/shared/Dados/Pets.luau` | Regras puras e testadas |
| `src/server/Servicos/Pets.luau` | Ações `AbrirNucleo`, `EquiparEco`, `EquiparMelhoresEcos` e `LibertarEco`. Multiplicadores no ganho e na sorte (`PontosAura`) e nos Fragmentos (Corredor). Atributo `Ecos` com os equipados |
| `src/client/Mundo/Ecos.luau` | Ecos seguindo os donos e Núcleos orbitando o Cristal |
| `src/client/UI/Telas/Ecos.luau` | Painel (Núcleos / Meus Ecos) com modelos 3D girando e a revelação |

**Os Ecos no mundo**
- Seguem o dono em leque, atrás dele.
- Os que voam boiam e batem as asas; os que andam dão pulinhos.
- Quem assiste vê os Ecos de todo mundo, até 180 studs.
- Movimento reduzido: sem balanço. Qualidade baixa: prismáticos sem faíscas e contorno.

**Na interface**
- **Ecos** entrou no menu lateral.
- O Cristal tem a interação **Despertar Ecos**.

## Playtest sugerido
1. **Primeiro Núcleo:** concluir a fase 1 do Corredor e despertar um Núcleo do Limiar no Cristal. Conferir a revelação e o Eco seguindo o personagem.
2. **Abrir 3:** com Fragmentos de teste, abrir 3. Conferir Equipar/Desequipar, Equipar melhores e Libertar.
3. **Bônus:** conferir o "+X/s" no HUD e a sorte no Índice com Ecos de ganho e de sorte equipados.
4. **Multijogador:** com dois clientes, ver os Ecos do outro jogador e o prismático brilhando.
5. **Desempenho:** conferir em celular. O painel tem um ViewportFrame por cartão.

## Próximo
- Fundir Ecos repetidos numa versão mais forte.
- Mais espaços pela Ascensão ou por passe.
- Núcleo diário grátis.
