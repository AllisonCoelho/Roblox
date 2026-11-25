# Corredor dos Perdidos

Segunda etapa do [plano dos Pontos de Aura](PLANO_PONTOS_DE_AURA.md).

**Status:** implementado e testado fora do Studio (testes de lógica, análise de tipos, `rojo build`). **Falta playtest no Studio.** As criaturas ainda não entraram: por enquanto, concluir uma fase é atravessar a ilha até o Portão.

## O que é

São seis mundos fragmentados flutuando em espiral no céu do Nexo, no mesmo mapa. Cada fase fica 22 studs acima da anterior, e quem está na praça vê as ilhas lá em cima.

Cada fase é uma ilha comprida partida em três pedaços, ligados por lajes. Tem:
- trilha;
- runas acesas;
- cenário do tema;
- o portal **Voltar ao Nexo** no começo;
- o **Portão** da próxima fase no fim.

| Fase | Mundo | Pontuação mínima | 1ª conclusão | Depois (a cada 5 min) |
|---|---|---|---|---|
| 1 | Limiar Partido | 0 | 10 Fragmentos | 2 |
| 2 | Bosque de Vidro | 60 | 25 | 5 |
| 3 | Dunas de Cinza | 250 | 60 | 12 |
| 4 | Maré Suspensa | 1.000 | 150 | 30 |
| 5 | Catedral Quebrada | 4.000 | 350 | 70 |
| 6 | Coração do Vazio | 12.000 | 800 | 160 |

**Entrada**
- O portal do meio dos **Portais Fragmentados** (Entrar) abre o painel do Corredor, com uma carta por fase: o que pede, o que dá e o botão **Ir**.
- Para entrar numa fase é preciso ter a **Pontuação de Aura** mínima e ter concluído a fase anterior.

**Conclusão**
- Chegar perto do Portão conclui a fase. É preciso ter passado pelo menos 6 s nela.
- A conclusão dá Fragmentos e a **Ressonância de Combate**: Pontos de Aura em dobro por 3 min.
- Fragmentos: o valor cheio na primeira vez; depois, uma recompensa menor a cada 5 min por fase.

**Portão**
- Atravessar o Portão leva à fase seguinte, se você tiver acesso. Se não tiver, o Portão te devolve com o aviso do que falta.
- O Portão da fase 6 leva de volta ao Nexo.

**Queda:** quem cai da ilha volta ao começo da fase.

**Fragmentos**
- Ficam em `corredor.fragmentos` e vão comprar pets na próxima etapa.
- O HUD (FRAGM.) passou a mostrar estes Fragmentos.
- Os Fragmentos antigos das Incursões continuam guardados no perfil.

## Segurança (servidor)
- Toda troca de fase é um **teleporte do servidor**. O cliente só pede (`CorredorIr`, `CorredorSair`) ou encosta num portal.
- O servidor confere:
  - Pontuação e fase anterior concluída;
  - distância até os Portais (para entrar) ou se o jogador já está no Corredor;
  - se o corpo está mesmo perto do portal tocado;
  - o tempo mínimo na fase.
- A cada 0,5 s um vigia devolve ao Nexo quem aparecer numa ilha sem acesso (voando, atravessando...) e devolve ao começo quem cair.

## Arquivos

| Arquivo | Papel |
|---|---|
| `assets/corredor/source/generate_corredor.py` | Gerador no Blender (como o kit do Nexo). `--render` refaz as prévias |
| `assets/corredor/source/corredor.blend` | Cena editável |
| `assets/corredor/previews/*.jpg` | Renders do Blender (não são prints do Roblox) |
| `src/client/Mundo/Nexo3D/Dados/corredor_*.luau` | Malhas (~23 mil triângulos, sem sombra projetada) |
| `src/client/Mundo/Nexo3D/CenaCorredor.luau` | Onde cada peça fica (gerado) |
| `src/shared/Dados/CorredorMapa.luau` | Pontos e colisão de cada fase no mundo (gerado) |
| `src/shared/Dados/Corredor.luau` | Fases, requisitos, recompensas e bônus (regras puras, testadas) |
| `src/server/Corredor/Servico.luau` | Colisão, portais, placas, entrada, conclusão e vigia |
| `src/client/UI/Telas/Corredor.luau` | Painel com as seis fases |

A colisão é feita de caixas criadas pelo servidor. Elas aparecem como blocos simples se o kit 3D falhar num cliente; com o kit montado, ficam invisíveis.

## Playtest sugerido
1. **Entrada:** nos Portais Fragmentados, abrir o painel e ir à fase 1. Atravessar até o Portão: deve aparecer o aviso com +10 Fragmentos e o "+X/s ×2 COMBATE" no topo.
2. **Bloqueio:** sem a Pontuação da fase 2, o Portão te devolve com o aviso de quanto falta. Com Pontos de Aura de teste (Painel Dev) e Nível de Aura comprado, ele te leva à fase 2.
3. **Queda e retorno:** cair da ilha devolve ao começo da fase; o portal Voltar ao Nexo devolve aos Portais.
4. **Colisão:** conferir se as lajes entre os pedaços, as árvores, os pilares e os arcos colidem no lugar do visual.
5. **Desempenho:** conferir em celular e em qualidade baixa. As ilhas não projetam sombra.

## Próximo
- Criaturas em cada fase e um chefe antes do Portão. A conclusão passa a exigir vencê-los.
- Pets comprados com Fragmentos.
