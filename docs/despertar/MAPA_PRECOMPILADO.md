# Cena 3D pré-compilada: carregamento rápido

## Diagnóstico (25/11/2026)
O código atual converte todos os dados de geometria em EditableMesh **no cliente**, ao entrar no jogo (`Malha.preparar` -> `CreateEditableMesh` -> `CreateDataModelContentAsync` -> `CreateMeshPartAsync`). Isso é demorado, consome memória e pode não funcionar no jogo publicado por permissões de Mesh/Image APIs. Não é um problema que `PreloadAsync` resolva sozinho.

## Caminho de produção (novo no cliente)
O cliente procura `ReplicatedStorage/Nexo3DPrecompilado` antes de tentar gerar a cena. Se existir como Model ou Folder, clona o conjunto estático para `workspace.Nexo.Kit3D` e esconde apenas os elementos marcados `Provisorio` e os placeholders do coração, preservando colisão funcional do servidor. Caso não exista, mantém **exatamente** o caminho antigo e seu cenário de reserva.

**Importante: o modelo pré-compilado não foi criado nem importado por este PR.** Até adicioná-lo ao place, continuará executando o caminho lento de EditableMesh. O Corredor dos Perdidos ainda é gerado dinamicamente e exige migração separada.

## Como finalizar no Roblox Studio
1. Importar as malhas finais (FBX/OBJ) do kit do Nexo geradas no Blender, preferencialmente pelo 3D Importer/Asset Manager do Studio, garantindo que são assets publicados sob a mesma propriedade/permissões da experiência.
2. Montar um `Model` chamado **Nexo3DPrecompilado**, com todas as peças já posicionadas em **coordenadas mundiais** corretas em relação à origem (Nexo no centro), e colocá-lo em `ReplicatedStorage`. Não precisa de scripts dentro do modelo.
3. Confirmar que as peças visuais estão ancoradas, sem colisão e que a geometria/cores são as desejadas. Não remover `workspace.Nexo` nem os colisores do servidor.
4. Testar no Studio com **Start Server + 2 Players**, observar `Output` (`[Nexo] cenário 3D pré-compilado pronto em ...`) e conferir chão, núcleo, portais, colisão, interações, luzes, texturas e dispositivos móveis.
5. Publicar o place pelo fluxo autorizado. Verificar no Roblox Player (não somente no Studio); comparar o tempo de entrada contra o fallback, checar memória e erros de carregamento.
6. Se usar o Rojo, preservar o modelo importado no place de forma que sincronizações/republicações não apaguem `ReplicatedStorage.Nexo3DPrecompilado`. Para reproduzir integralmente via CI, versionar o place/modelo em um pipeline adequado ou usar IDs de assets publicados e autorizados.

## Limitações e segurança
- Não existe promessa de carregamento literalmente instantâneo: o cliente ainda baixa dados de mesh e textura. Esta estratégia remove **a conversão de geometria em tempo real**, que é a parte cara.
- O modelo estático não recebe automaticamente as animações específicas de `Montagem.Resultado` (estilhaços/orbitas); estes terão de ser ajustados numa segunda etapa caso desejados.
- A cena dinâmica e seus erros persistem como fallback. Se o precompilado estiver incompleto, ele poderá exibir cenário incompleto; valide o prefab antes da publicação.
- `StreamingEnabled` não substitui o upload correto de malhas; `ContentProvider:PreloadAsync` pode priorizar alguns assets visuais, mas não força instantaneidade.
