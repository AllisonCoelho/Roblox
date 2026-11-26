# Diagnóstico e carregamento do mapa — 25/11/2026

## Evidências

- #59, #60, #61 e #62 estão mesclados. Seus heads e commits de merge são ancestrais de `main`; o conteúdo de combate reativo existe junto com as funcionalidades anteriores.
- Os quatro pushes passaram nos dois workflows. O deploy de `120b0d5` respondeu `{"versionNumber":92}` no place privado **112360499723635**, universo **10771776655** ([execução](https://github.com/AllisonCoelho/Roblox/actions/runs/45713590974)). Isso confirma publicação, não funcionamento do renderer.
- Há um PR aberto: [#63](https://github.com/AllisonCoelho/Roblox/pull/63). Seu build passou; o check de qualidade falhou em StyLua. Ele não contém o prefab proposto e não preserva as animações do kit no caminho estático. Este trabalho é uma alternativa baseada na `main`, não depende de #63. Revisar a sobreposição antes de escolher qual integrar; nenhum PR foi mesclado ou fechado.
- A busca de PRs pelo conector retornou vazio; a consulta autenticada direta (`gh pr list --state open`) revelou #63. Usar a consulta direta para confirmar a lista.

## Causas encontradas e limites da investigação

O mapa não está salvo como geometria visível em Workspace. `src/server/Nexo.server.luau` constrói o cenário básico ao executar Play; `src/client/Nexo.client.luau` reconstrói o visual Blender **em cada cliente**. A vista de edição antes de Play não executa esses scripts. Renders Blender em `previews/` não são assets publicados nem imagens que o jogo carregue como mapa.

O kit tem **522 instâncias e 103 malhas únicas**. Cada malha exige decodificação, milhares de chamadas de vértices/faces, `CreateDataModelContentAsync` e `CreateMeshPartAsync`. Antes, nenhuma peça aparecia até completar as 522; qualquer erro descartava toda a montagem. NPCs, pets e outros visuais podiam competir pela memória/API durante essa montagem. O Soberano ainda podia impedir o início do Corredor se falhasse.

O payload e os índices das **150 malhas referenciadas pelo Nexo e Corredor** foram verificados automaticamente: nenhum arquivo ausente, índice fora dos limites ou payload truncado encontrado. Isso não valida orientação, cores nem aparência no renderer.

EditableMesh [falha por padrão em jogos publicados](https://create.roblox.com/docs/reference/engine/classes/EditableMesh) sem **Enable Mesh / Image APIs**, e tem orçamento de memória restrito no cliente. Verificar a opção no Creator Dashboard ou Experience Settings → Security. Não foi possível ler essa configuração da experiência nem observar o Output do Studio nesta investigação; permissão desativada e incompatibilidade de API são causas possíveis, não um erro reproduzido. `CreateDataModelContentAsync` também depende do suporte do motor e tem orçamento de armazenamento de sessão.

`default.project.json` não ativa `StreamingEnabled`. Portanto, não há evidência de que streaming seja a causa do atraso da versão publicada. Mesmo desligado, meshes e texturas ainda são baixadas sob demanda. Streaming do mundo e carregamento de conteúdo são mecanismos diferentes.

## Correções

- Duas transações: **Praça** (pivôs até 46 studs) e **Mundo**. A praça aparece e anima antes de começar a montar o complemento. Uma falha distante preserva a praça e mantém o resto provisório.
- Só esconde o fallback da etapa concluída; usa `LocalTransparencyModifier`, preservando colisões, prompts e regras do servidor. Partes que chegam depois por streaming também são tratadas.
- O pequeno Model `Nucleo` é Persistent para os acessos contínuos do cliente se o Studio estiver com streaming ligado. Não torna o mapa inteiro Persistent e não ativa streaming globalmente.
- Construção de vértices/faces cede o quadro após aproximadamente 4 ms (verificação a cada 256 elementos). Isso limita blocos de CPU; não impõe prazo às APIs assíncronas do motor.
- Visuais secundários começam depois da tentativa do mapa, com falhas isoladas. O preload é somente das malhas **publicadas** da praça, com limite de espera de 8 s e conferência de falhas individuais. Sem preload global de Workspace.
- `EstadoKit3D`, `ErroKit3D`, `TempoKit3DPraca` e `TempoKit3DMundo` ficam no Nexo **local**. Os tempos medem montagem/pré-carregamento, não garantem que cada pixel já tenha sido renderizado.
- `Malha.criar` prefere MeshParts publicados por nome em `ReplicatedStorage.NexoMalhas`; usa os mesmos pivôs, escala, Cena e animações. A pasta agora está mapeada no Rojo. Sem template válido, mantém o caminho procedural.

## Caminho mais rápido com assets publicados (etapa manual pendente)

**Este PR não contém MeshIds novos.** A otimização progressiva já atua sobre os dados atuais; eliminar a conversão por jogador exige importar/publicar os FBX com a conta dona e versionar os templates. Não existe carregamento instantâneo absoluto: rede, dispositivo, cache e permissões continuam relevantes.

1. Abra no Studio o build Rojo ou sincronize o projeto. Em Edit, importe os FBX próprios de `assets/nexo/exports/`, usando uma MeshPart por nome de `src/client/Mundo/Nexo3D/Dados/*.luau`. Preserve os eixos e cores; confirme a escala. Priorize as malhas da praça.
2. Publique com o proprietário correto e conceda uso à experiência. Selecione um Folder/Model contendo as peças e execute o conteúdo de `tools/studio/preparar_malhas_nexo.luau` na Command Bar. O script prepara dimensões e atributo `CentroMalha`; não faz upload ou deploy.
3. Salve **cada MeshPart filha** da pasta resultante como `<nome>.rbxmx` diretamente em `assets/roblox/NexoMalhas/`. Não salve uma pasta contendo outra pasta: os templates devem ser filhos diretos de `ReplicatedStorage.NexoMalhas`. `.gitignore` já permite modelos dentro de `assets/`.
4. Faça `rojo build default.project.json --output dist/jogo.rbxlx` e confira que os MeshParts, MeshIds e atributos estão no resultado. Uma edição apenas no Studio é perdida pelo próximo deploy Rojo.
5. Teste no place privado, inclusive com outra conta. Um MeshId pode existir e ainda falhar por moderação/permissões; o preload inicial mantém fallback e informa o ID no erro. Assets distantes continuam sob demanda. Não habilitar upload/deploy automático ou mudar CI/segredos para isso.

Não integrar #63 junto sem reconciliar os dois carregadores. Seu nome `Nexo3DPrecompilado` não é usado aqui: esta implementação usa templates individuais e conserva as animações.

## Validação e riscos

Automação: `python testes/rodar.py` inclui validação binária das malhas, testes da divisão da cena real e seis cenários executando o código de Montagem com mocks: sucesso, falha inicial, falha distante, preload publicado bem-sucedido, asset recusado e timeout. Rodar também StyLua, luau-lsp e Rojo. Mocks não simulam GPU, rede real ou EditableMesh.

Playtest ainda necessário antes de aprovar merge:

1. Studio → Play e Test → Start Server + 2 Players: praça primeiro, restante depois, sem erros; Núcleo continua pulsando, cristais/lanternas giram. Em Edit, o mapa procedural não é esperado.
2. No painel DEV → Mapa, conferir estado. No Explorer **do cliente**, inspecionar os tempos e `ErroKit3D`; guardar também FPS, dispositivo, conta, cache frio/quente e PlaceVersion. Fazer pelo menos cinco entradas no mesmo dispositivo antes/depois e comparar mediana e pior tempo até a praça visível. Não há números reais de ganho ainda.
3. No place privado correto, entrar em **servidor novo** e conferir a versão esperada. Uma cópia local ou servidor antigo pode continuar executando código anterior. A versão 92 é a referência anterior à correção, não a versão futura deste PR.
4. Testar a API desabilitada numa cópia de teste: fallback deve continuar jogável e o diagnóstico deve explicar a falha. Repetir habilitada. Testar falha de uma malha distante: praça permanece e o complemento não desaparece.
5. Testar desktop e celular, cache frio, respawn e reconexão; caminhar até cada lugar, subir no pedestal, usar índice, portais, drops, Núcleos, Arena e combate. Visuais secundários passam a iniciar depois da tentativa do mapa e podem aparecer mais tarde.
6. Numa cópia com streaming ligado, afastar e voltar à praça; conferir fallback sem duplicação e o Núcleo persistente. Outros sistemas do jogo ainda precisam de auditoria própria antes de ativar streaming globalmente.

Riscos: sobreposição/encaixe entre kit e fallback deve ser inspecionada visualmente; APIs ainda podem recusar criação ou demorar; memória e FPS móvel não medidos. Malhas publicadas fora da praça não têm preload bloqueante nem teste de permissões automático. Uma falha no complemento mantém sua etapa inteira provisória. Não foram alterados workflows, permissões, segredos, DataStores nem regras de combate. Nenhum merge ou publicação foi executado por este trabalho.
