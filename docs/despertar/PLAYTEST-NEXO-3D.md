# Playtest — Nexo 3D (praça e Núcleo)

Marcar cada item no Studio (`rojo serve` + Play) e depois na experiência privada. **Nenhum item foi executado ainda.**

## Montagem
- [ ] Output sem `[Nexo] kit 3D indisponível`.
- [ ] `Workspace.Nexo.Kit3D` existe no cliente, com as 475 peças do kit.
- [ ] As caixas `ColisorKit` existem no servidor e somem (ficam transparentes) no cliente quando o kit monta.
- [ ] Peças viradas para fora (não "do avesso") e no lugar: pedestal no centro, cristal acima, arco ao norte.
- [ ] As peças antigas da praça e do Núcleo sumiram; nada duplicado.

## Vista do spawn
- [ ] Ao nascer, a câmera vê o cristal partido no centro e o arco atrás.
- [ ] Captura da mesma câmera antes/depois anexada ao PR.
- [ ] Pedra fosca, energia só nas canaletas, cristal sem estourar o Bloom.
- [ ] Avatar e aura equipada legíveis perto do Núcleo.

## Comportamento preservado
- [ ] O coração flutua e pulsa; os três anéis giram em volta do cristal.
- [ ] Aura 1 em 1.000+ (no Studio: `Alt+3` não dispara o evento; usar um giro real com sorte alterada localmente, sem commitar): os estilhaços se afastam, mudam de cor por ~4 s e voltam.
- [ ] Arquivo dos Ecos abre o Índice.
- [ ] Obelisco mostra o ranking e atualiza com dois jogadores.
- [ ] Fragmento do Jardim e os avisos "Em construção" funcionam.

## Colisão e circulação
- [ ] Dá para andar da entrada ao pedestal e passar sob o arco.
- [ ] Pilares, muros e pés dos arcos bloqueiam; nenhum obstáculo invisível fora deles.
- [ ] Subir nos degraus do pedestal não prende o personagem.

## Robustez
- [ ] Morrer e renascer: o kit continua montado, sem duplicar.
- [ ] Entrar com o mapa recém-carregado (cliente lento): sem erro de `WaitForChild`.
- [ ] Dois jogadores: os dois veem o kit.

## Desempenho
- [ ] FPS no PC e em pelo menos um celular, com e sem "qualidade baixa".
- [ ] Tempo de entrada: travada perceptível na montagem?
- [ ] Memória no celular (Developer Console → Memory).


## Fase 2 — lugares, caminhos e mapa fechado
- [ ] Os seis lugares aparecem em 3D e o esqueleto cinza some.
- [ ] Caminhos: a transição de cada um é perceptível (mármore e símbolos azuis no Arquivo, vegetação e verde no Jardim, chão fraturado nos Portais).
- [ ] Os postes delimitam os seis caminhos. Os canteiros e as ruínas aparecem no terreno entre as áreas.
- [ ] Ninguém sai do mapa: andar e pular contra os penhascos em vários pontos.
- [ ] Cenário de reserva (kit desligado, por exemplo com erro forçado em `Montagem.construir`): o anel `BordaProvisoria` fecha a borda e os blocos `ColisorKit` aparecem onde estão os obstáculos.
- [ ] Do alto do Obelisco ou pulando perto da borda, não se vê o lado de fora.
- [ ] Painel do ranking legível, dentro da moldura, virado para a praça.
- [ ] Arquivo: "Abrir índice" no console; colunas e degraus sem prender o personagem.
- [ ] Jardim: troncos e ruínas bloqueiam; fragmento sussurrante atrás do muro.
- [ ] Altar e Portais: interações "Em construção"; véus dentro das molduras.
- [ ] Arena: subir e descer a arquibancada.
- [ ] Tempo de entrada e FPS no celular com as 475 peças.
