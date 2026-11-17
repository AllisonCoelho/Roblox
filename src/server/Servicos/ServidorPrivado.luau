-- Servidor Privado (49 Robux/mês). A venda é do próprio Roblox: o dono liga em
-- Creator Hub → Acesso ao servidor → Servidores privados. Aqui só identificamos o servidor
-- para a interface ("Servidor privado de <dono>") e damos ao dono do servidor um distintivo
-- visível só enquanto ele está no próprio servidor.
local Players = game:GetService("Players")

local ServidorPrivado = {}

function ServidorPrivado.ehPrivado(): boolean
	-- PrivateServerOwnerId > 0: servidor comprado por um jogador (servidores reservados têm 0)
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

function ServidorPrivado.iniciar()
	if not ServidorPrivado.ehPrivado() then
		return
	end
	workspace:SetAttribute("ServidorPrivadoDono", game.PrivateServerOwnerId)
	local function marcar(player: Player)
		if player.UserId == game.PrivateServerOwnerId then
			player:SetAttribute("DonoServidorPrivado", true)
		end
	end
	Players.PlayerAdded:Connect(marcar)
	for _, player in Players:GetPlayers() do
		marcar(player)
	end
end

return ServidorPrivado
