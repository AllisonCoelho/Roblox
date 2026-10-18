-- Decide a resposta ao Roblox para uma compra de Developer Product (lógica pura, testada
-- em testes/logica.luau com falhas de gravação, repetições e troca de servidor).
--
-- O Roblox chama o ProcessReceipt de novo (inclusive em outro servidor, quando o jogador
-- volta) até receber PurchaseGranted. Por isso:
--   * o crédito e a marca da compra (estado.recibos[PurchaseId]) entram juntos no estado,
--     sem pausa entre eles, e vão juntos para o DataStore na mesma gravação;
--   * PurchaseGranted só sai depois de uma gravação que começou DEPOIS do crédito ter dado
--     certo (a fila de Gravacao garante que ela leva o crédito);
--   * a marca nunca é apagada: uma compra antiga repetida é reconhecida para sempre.
local Compras = {}

-- Compras creditadas neste servidor cujo salvamento falhou: quando o Roblox repetir e der
-- certo, o jogador ainda precisa do aviso e do estado novo
local semAviso: { [string]: boolean } = {}

export type Info = { PurchaseId: string, ProductId: number }

-- O que importa do pacote (Shared/Dados/Loja.luau)
export type Pacote = { granulados: number }

export type Deps = {
	-- Estado do jogador já carregado e que pode ser salvo; nil se ainda não dá
	estado: () -> any?,
	-- Pacote do produto (Loja.pacoteDoProduto); nil se o produto não é nosso
	pacote: (productId: number) -> Pacote?,
	-- Grava na fila e diz se ficou salvo
	salvar: () -> boolean,
	-- Chamado uma vez quando os granulados entram (avisar o jogador, mandar o estado)
	entregue: (pacote: Pacote) -> (),
}

-- Põe a compra no estado. Devolve "entregue" (granulados somados agora), "repetida"
-- (esta compra já tinha sido entregue) ou "invalida" (produto desconhecido).
-- estado.recibos é um conjunto PurchaseId -> horário que nunca perde itens.
function Compras.aplicarRecibo(
	estado: { granulados: number, recibos: { [string]: number } },
	compraId: string,
	pacote: Pacote?,
	agora: number
): string
	if estado.recibos[compraId] then
		return "repetida"
	end
	if not pacote then
		return "invalida"
	end
	estado.granulados += pacote.granulados
	estado.recibos[compraId] = agora
	return "entregue"
end

-- "PurchaseGranted" ou "NotProcessedYet"
function Compras.processar(info: Info, deps: Deps, agora: number): string
	local estado = deps.estado()
	if not estado then
		return "NotProcessedYet"
	end
	local pacote = deps.pacote(info.ProductId)
	local resultado = Compras.aplicarRecibo(estado, info.PurchaseId, pacote, agora)
	if resultado == "invalida" then
		return "NotProcessedYet"
	end
	if not deps.salvar() then
		-- O crédito fica marcado no estado: se esta sessão salvar depois (autosave ou saída),
		-- a próxima tentativa do Roblox vê "repetida" e não credita de novo
		if resultado == "entregue" then
			semAviso[info.PurchaseId] = true
		end
		return "NotProcessedYet"
	end
	if pacote and (resultado == "entregue" or semAviso[info.PurchaseId]) then
		semAviso[info.PurchaseId] = nil
		deps.entregue(pacote)
	end
	return "PurchaseGranted"
end

return Compras
