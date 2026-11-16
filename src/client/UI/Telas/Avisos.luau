-- Avisos na tela: mensagens curtas (toast) e anúncios de auras raras para o servidor inteiro.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local C = require(script.Parent.Parent.Componentes)
local Estado = require(script.Parent.Parent.Estado)

local Avisos = {}

local toast: Frame
local toastTexto: TextLabel
local toastToken = 0
local banner: Frame
local bannerTexto: TextLabel
local bannerToken = 0

local function escapar(texto: string): string
	return (texto:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Avisos.toast(texto: string)
	toastToken += 1
	local meu = toastToken
	toastTexto.Text = texto
	toast.Visible = true
	task.delay(2.5, function()
		if toastToken == meu then
			toast.Visible = false
		end
	end)
end

local function anunciar(dados: { [string]: any })
	local aura = Auras.porId[dados.aura]
	if not aura or type(dados.jogador) ~= "string" then
		return
	end
	local proprio = dados.userId == Players.LocalPlayer.UserId
	local estado = Estado.atual
	if not proprio and estado and estado.configuracoes.anuncios == false then
		return
	end
	local tier = Auras.Tiers[aura.tier]
	local texto = string.format(
		'⚡ <b>%s</b> despertou <font color="#%s"><b>%s</b></font> (1 em %s)!',
		escapar(dados.jogador),
		tier.cor,
		aura.nome,
		Formato.inteiro(aura.chance)
	)
	bannerToken += 1
	local meu = bannerToken
	bannerTexto.Text = texto
	banner.Visible = true
	task.delay(5, function()
		if bannerToken == meu then
			banner.Visible = false
		end
	end)
	-- Também no chat, se o chat novo estiver ativo
	pcall(function()
		local canais = TextChatService:FindFirstChild("TextChannels")
		local geral = canais and canais:FindFirstChild("RBXGeneral")
		if geral and geral:IsA("TextChannel") then
			geral:DisplaySystemMessage(texto)
		end
	end)
end

function Avisos.montar(raiz: Frame)
	banner = C.cartaoEscuro({
		Name = "Anuncio",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(820, 70),
		Visible = false,
		ZIndex = 15,
		Parent = raiz,
	})
	bannerTexto = C.texto({
		RichText = true,
		TextSize = 26,
		TextWrapped = true,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		ZIndex = 15,
		Parent = banner,
	})
	toast = C.cartaoEscuro({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -160),
		Size = UDim2.fromOffset(560, 54),
		Visible = false,
		ZIndex = 15,
		Parent = raiz,
	})
	toastTexto = C.texto({
		TextSize = 22,
		TextWrapped = true,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		ZIndex = 15,
		Parent = toast,
	})

	Remotos.evento("Aviso").OnClientEvent:Connect(function(dados: any)
		if type(dados) ~= "table" then
			return
		end
		if dados.tipo == "anuncio" then
			anunciar(dados)
		elseif type(dados.texto) == "string" then
			Avisos.toast(dados.texto)
		end
	end)
end

return Avisos
