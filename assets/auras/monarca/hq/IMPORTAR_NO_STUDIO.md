# Importar o Monarca das Sombras detalhado no Roblox Studio

Cinco modelos feitos no Blender por `generate_monarca_hq.py`. O jogo funciona sem eles (usa as
malhas simples); quando você importar, ele passa a usar estes **sozinho**, sem mudar código.

| Arquivo (`exports/`) | O quê |
|---|---|
| `monarca_soldado_cavaleiro.fbx` | Cavaleiro comandante (espada cravada, penacho, capa) |
| `monarca_soldado_gigante.fbx` | Gigante (escudo-torre, machado duplo) |
| `monarca_soldado_mago.fbx` | Mago (capuz, manto em tiras, cajado com orbe, chama na mão) |
| `monarca_soldado_formiga.fbx` | Rei-formiga (garras, mandíbulas, antenas, asas, ferrão) |
| `monarca_coroa.fbx` | Coroa do monarca (aro duplo, oito pontas, gemas) |

Os soldados têm esqueleto (`..._Rig`), corpo com textura embutida (PNG também em `texturas/`) e a
malha de brilho (`..._Brilho`: olhos, fio das armas, garras, orbe). A coroa não tem esqueleto.

## Passo a passo (para cada um dos 5)

1. Baixe a pasta `assets/auras/monarca/hq/exports/` do GitHub.
2. No Studio, abra o lugar do jogo → **Import 3D** e escolha o `.fbx`.
3. Na janela do importador:
   - Soldados: **Rig Type: Custom**. Coroa: sem rig.
   - **Import Only As Model** marcado. Escala: tanto faz, o jogo ajusta a altura.
   - **Import**.
4. Em **ReplicatedStorage**, crie uma **Folder** chamada exatamente `AurasModelos` (só uma vez).
5. Arraste o Model importado para dentro dela e **renomeie** com o nome do arquivo sem `.fbx`
   (ex.: `monarca_soldado_cavaleiro`). O nome precisa ser idêntico.
6. Textura: selecione o corpo e confira **TextureID**. Se estiver vazio, importe
   `texturas/<nome>_cor.png` e cole o ID.
7. A peça `_Brilho` vira Neon roxo sozinha no jogo (não precisa mexer).
8. **Publique** o lugar (File → Publish to Roblox).

## Testar

Play → **Alt+M** liga a aura → a coroa nova aparece sobre a cabeça. Fique parado ~6 s: os quatro
soldados sobem da sombra com os modelos novos.

- **Virado de costas?** No Model, atributo **Giro** (Number) = `180`.
- **Grande ou pequeno?** Atributo **Escala** (Number), ex.: `1.2`.
- Não renomeie os ossos (`Tronco`, `Peito`, `Cabeca` recebem um movimento leve por código).

## Limites

- Soldados com 11 a 14 mil triângulos cada; coroa com 6,6 mil.
- A borda roxa brilhante das malhas simples não existe nos modelos importados: o brilho vem da
  peça `_Brilho` e da textura com veios roxos.
- As chamas, a poça e os olhos da sombra continuam sendo as peças do jogo (já são animadas por código).
- Não testei a importação no Studio daqui: os FBX foram gerados e conferidos só no Blender.
