# Nexo do Despertar — mapa da V1

Mapa compacto, construído por código em `src/server/Mundo/Nexo.luau` (sem malhas nem assets enviados). Norte = −Z. O `default.project.json` não cria mais Baseplate nem SpawnLocation: o mapa cria os seus.

| Lugar | Onde | Estado na V1 |
|---|---|---|
| Núcleo do Despertar | centro | Peça central animada no cliente (flutua, pulsa, três anéis orbitais). Fica agitado e muda de cor por 4 s quando alguém do servidor desperta 1 em 1.000 ou mais raro. |
| Obelisco das Lendas | norte | Painel com o ranking do servidor (aura mais rara, depois giros), atualizado a cada 4 s com dados do perfil no servidor. |
| Arquivo dos Ecos | noroeste | Console com interação "Abrir índice". |
| Jardim dos Fragmentos | sudoeste | Cristais, ruínas e um fragmento escondido que mostra uma frase. Não dá recompensa. |
| Altar da Ressonância | nordeste | Só cenário, marcado "Em construção". |
| Portais Fragmentados | sudeste | Só cenário, marcado "Em construção". |
| Arena dos Despertos | sul | Só cenário, marcado "Em construção". |

Também: praça de mármore com filetes de luz, oito lanternas, seis caminhos, borda de rochas, sete ilhas flutuantes ao longe e céu noturno com atmosfera violeta e bloom.

## Arquivos
- `src/server/Mundo/Nexo.luau` — construtor (posições, cores e medidas no topo do arquivo).
- `src/server/Nexo.server.luau` — monta o mapa e atualiza o painel do ranking.
- `src/client/Nexo.client.luau` — anima o Núcleo e trata as interações (`Acao` = `indice`, `em_construcao`, `eco`).

## A conferir no Studio (nada disso foi visto rodando)
- Ao nascer, o jogador olha para o Núcleo.
- Escala e leitura: colunas, obelisco e placas legíveis; nada bloqueando os caminhos.
- Painel do ranking virado para a praça (se aparecer de costas, trocar `Face` para `Back`).
- Anéis do Núcleo formam círculos (se virarem "S", inverter o sinal de `CurveSize1`).
- Contagem de peças e FPS no celular com várias auras equipadas.
