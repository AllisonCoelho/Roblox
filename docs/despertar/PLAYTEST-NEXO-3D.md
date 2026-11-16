# Playtest — Nexo 3D (praça e Núcleo)

Marcar cada item no Studio (`rojo serve` + Play) e depois na experiência privada. **Nenhum item foi executado ainda.**

## Montagem
- [ ] Output sem `[Nexo] kit 3D indisponível`.
- [ ] `Workspace.Nexo.Kit3D` existe no cliente, com 54 peças e a pasta `Colisores`.
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
