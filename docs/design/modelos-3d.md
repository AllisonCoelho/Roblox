# Modelos 3D dos Docinhos (com a IA do Roblox)

A interface já funciona sem os modelos: enquanto um Docinho não tiver modelo
oficial, o jogo usa um **provisório feito de peças** (`src/shared/Dados/Modelos.luau`).
Quando o modelo oficial entra no repositório, ele aparece sozinho em todas as telas
(Álbum, Loja, popups) e, depois, na vitrine e na esteira.

## Passo a passo (para cada Docinho)

1. No Roblox Studio, abra a ferramenta de geração 3D por texto da IA do Roblox
   (Assistente / geração de malha) e cole o *prompt* da tabela abaixo.
   Os prompts estão em inglês porque a geração costuma acertar mais assim.
2. Gere algumas opções e escolha a mais parecida com `docs/design/02-docinhos.png`.
3. Ajuste o modelo:
   - Agrupe tudo num **Model** com o nome **exatamente igual ao `id`** (ex.: `brigadeiro`).
   - Tamanho: por volta de **2 a 3 studs de altura**.
   - Deixe as peças **Anchored = true** e **CanCollide = false**.
4. Salve o modelo: clique com o botão direito no Model → **Save to File** →
   formato `.rbxm` → salve como `assets/docinhos/<id>.rbxm` (ex.: `assets/docinhos/brigadeiro.rbxm`).
5. Faça commit do arquivo (ou envie para a branch do Claude). O Rojo coloca o modelo
   em `ReplicatedStorage.DocinhosModelos` e o jogo passa a usar ele.

> **Se o Docinho aparecer de costas ou de lado** na interface, selecione o Model,
> adicione um atributo do tipo **number** chamado `GiroY` com `180` (ou `90`/`-90`)
> e salve o `.rbxm` de novo. Não precisa mexer em código.

> **Importante:** malhas geradas pela IA ficam salvas na conta de quem gerou.
> Gere com a **mesma conta (ou grupo) dona da experiência**, senão os modelos
> podem não carregar no jogo publicado.

> **Por que salvar em arquivo e não só no Studio?** Cada merge na `main` recria o
> jogo inteiro a partir do repositório. Um modelo que só existe no Studio é apagado
> na próxima publicação.

## Prompts

Estilo comum a todos (já incluído em cada prompt): personagem fofo, estilo
brinquedo/cartoon, olhos grandes e redondos, bochechas rosadas, cores vivas, sem texto.

| id | Docinho | Prompt |
|---|---|---|
| `balaDeCoco` | Bala de Coco (Comum) | `cute chibi candy character, white coconut taffy wrapped in a pastel pink twisted candy wrapper on both sides, big round black eyes, rosy cheeks, small smile, toy-like cartoon style, smooth, vibrant colors, no text` |
| `beijinho` | Beijinho Fofinho (Comum) | `cute chibi Brazilian beijinho candy character, white coconut ball covered in sugar, a single clove on top, sitting in a light blue paper candy cup, happy closed eyes, rosy cheeks, toy-like cartoon style, no text` |
| `pacoca` | Paçoca Ninja (Incomum) | `cute chibi Brazilian paçoca peanut candy character, crumbly beige square block, red ninja headband with ribbons, determined eyebrows, big eyes, rosy cheeks, toy-like cartoon style, no text` |
| `peDeMoleque` | Pé-de-Moleque Skatista (Incomum) | `cute chibi Brazilian pe-de-moleque candy character, caramel brown bar with peanuts, orange backwards cap, riding a purple skateboard, big eyes, open smile, toy-like cartoon style, no text` |
| `cocada` | Cocada Surfista (Raro) | `cute chibi Brazilian cocada coconut candy character, bumpy cream-colored round cookie with toasted edges, black sunglasses, holding a light blue surfboard, big smile, toy-like cartoon style, no text` |
| `quindim` | Quindim Cantor (Raro) | `cute chibi Brazilian quindim dessert character, shiny bright yellow glossy dome on a golden coconut base, singing with open mouth, small floating music notes, big eyes, toy-like cartoon style, no text` |
| `brigadeiro` | Brigadeiro Turbo (Épico) | `cute chibi Brazilian brigadeiro candy character, chocolate ball covered in chocolate sprinkles, sitting in a pink paper candy cup, blue racing goggles on forehead, excited open mouth, speed lines, toy-like cartoon style, no text` |
| `pudim` | Pudim Astronauta (Lendário) | `cute chibi Brazilian flan pudding character, cream-colored flan with dripping caramel top on a small plate, wearing a clear round astronaut helmet bubble with a small antenna, big eyes, toy-like cartoon style, no text` |
| `boloDeRolo` | Bolo de Rolo Mago (Mítico) | `cute chibi Brazilian bolo de rolo cake slice character, light sponge with thin red guava layers, purple wizard hat with golden stars, holding a small wand with a star, happy closed eyes, toy-like cartoon style, no text` |
| `coxinha` | Coxinha Doce Misteriosa (Secreto) | `cute mysterious teardrop-shaped coxinha character, dark purple-black body with a subtle rainbow outline glow, glowing yellow eyes and smile, magical sparkles, toy-like cartoon style, no text` |

## Conferindo

- No Studio, rode o jogo (Play) e abra o **Álbum**: o Docinho deve aparecer com o modelo novo.
- Se ele aparecer muito pequeno ou cortado, confira o tamanho (2–3 studs) e se não
  sobrou nenhuma peça solta longe do corpo (ela aumenta a "caixa" do modelo).
