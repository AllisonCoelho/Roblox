-- Itens avulsos (Developer Products): títulos, trilhas, aparências, emotes e finalizações.
-- ProcessReceipt é o ÚNICO ponto que entrega compra avulsa. Cada PurchaseId fica salvo no
-- perfil (perfil.compras) e a entrega só é confirmada ao Roblox depois do DataStore gravar
-- (Dados.alterarConfirmado). Assim uma compra nunca é entregue duas vezes nem perdida.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmeticos = require(Shared.Dados.Cosmeticos)
local Dados = require(script.Parent.Dados)

local Compras = {}

local function processar(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	-- Sem jogador, sem perfil real ou em sessão de teste: o Roblox tenta de novo depois
	if
		not player
		or not Dados.de(player)
		or Dados.emTeste(player)
		or not Dados.podeProgredir(player)
	then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local item = Cosmeticos.porProduto(info.ProductId)
	if not item then
		warn("[Compras] produto desconhecido: " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local compra = tostring(info.PurchaseId)
	local ok = Dados.alterarConfirmado(player, function(e: any)
		e.compras = if type(e.compras) == "table" then e.compras else {}
		if e.compras[compra] then
			return true -- já entregue antes (recibo repetido)
		end
		e.compras[compra] = true
		e.cosmeticos = e.cosmeticos or Cosmeticos.padrao()
		e.cosmeticos.equipados = e.cosmeticos.equipados or {}
		Cosmeticos.conceder(e.cosmeticos, { item.id })
		e.cosmeticos.equipados[item.tipo] = item.id
		return true
	end)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Compras.iniciar()
	MarketplaceService.ProcessReceipt = processar
end

return Compras
