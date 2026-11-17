-- Etiqueta do chat: distintivo e título equipados (atributos Cos* que o servidor liga) e o
-- nome dourado do VIP do Nexo. Só aparência.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local EtiquetasChat = {}

local function hexValido(h: any): boolean
	return type(h) == "string" and string.match(h, "^%x%x%x%x%x%x$") ~= nil
end

local function escapar(t: string): string
	return (t:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function EtiquetasChat.prefixo(player: Player, prefixo: string): string
	local partes = {}
	local dis, disCor =
		player:GetAttribute("CosDistintivo"), player:GetAttribute("CosDistintivoCor")
	if type(dis) == "string" and hexValido(disCor) then
		table.insert(partes, string.format('<font color="#%s">%s</font>', disCor, escapar(dis)))
	end
	local tit, titCor = player:GetAttribute("CosTitulo"), player:GetAttribute("CosTituloCor")
	if type(tit) == "string" and hexValido(titCor) then
		table.insert(partes, string.format('<font color="#%s">[%s]</font>', titCor, escapar(tit)))
	end
	if player:GetAttribute("DonoServidorPrivado") == true then
		table.insert(partes, '<font color="#B7FFD9">🏠</font>')
	end
	local nome = prefixo
	if player:GetAttribute("CosVip") == true then
		nome = '<font color="#FFD36B">' .. prefixo .. "</font>"
	end
	table.insert(partes, nome)
	return table.concat(partes, " ")
end

function EtiquetasChat.iniciar()
	TextChatService.OnIncomingMessage = function(mensagem: TextChatMessage)
		local fonte = mensagem.TextSource
		if not fonte then
			return nil
		end
		local player = Players:GetPlayerByUserId(fonte.UserId)
		if not player then
			return nil
		end
		local props = Instance.new("TextChatMessageProperties")
		props.PrefixText = EtiquetasChat.prefixo(player, mensagem.PrefixText)
		return props
	end
end

return EtiquetasChat
