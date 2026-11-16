-- Avisos na tela: mensagens curtas (toast) e anúncios de auras raras para o servidor inteiro.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local Tema = require(Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)
local Estado = require(script.Parent.Parent.Estado)

local Cores = Tema.Cores
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

-- Anúncio de aura rara (dados vindos do remote "Despertou")
function Avisos.anunciar(nomeJogador: string, userId: number, aura: Auras.Aura)
	if aura.chance < Auras.ANUNCIO_MINIMO then
		return
	end
	local proprio = userId == Players.LocalPlayer.UserId
	local estado = Estado.atual
	if not proprio and estado and estado.configuracoes.anuncios == false then
		return
	end
	local tier = Auras.Tiers[aura.tier]
	local nome = escapar(string.upper(nomeJogador))
	local chance = Formato.chance(aura.chance)
	-- No banner (fundo papel) a cor da raridade é escurecida para dar contraste
	local corBanner = Color3.fromHex(tier.cor):Lerp(Cores.Tinta, 0.35):ToHex()
	bannerTexto.Text = string.format(
		'<b>%s</b> DESPERTOU <font color="#%s"><b>%s</b></font> · 1 EM %s',
		nome,
		corBanner,
		string.upper(aura.nome),
		chance
	)
	bannerToken += 1
	local meu = bannerToken
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
			geral:DisplaySystemMessage(
				string.format(
					'<b>%s</b> despertou <font color="#%s"><b>%s</b></font> (1 em %s)!',
					escapar(nomeJogador),
					tier.cor,
					aura.nome,
					chance
				)
			)
		end
	end)
end

function Avisos.montar(raiz: Frame)
	local placaBanner = Kit.placa({
		largura = 900,
		altura = 56,
		fundo = Cores.Papel,
		sombra = Cores.Selo,
		posicao = UDim2.new(0.5, 0, 0, 22),
		ancora = Vector2.new(0.5, 0),
		z = 20,
		pai = raiz,
	})
	banner = placaBanner.quadro
	banner.Visible = false
	bannerTexto = Kit.texto({
		fonte = "media",
		RichText = true,
		TextSize = 24,
		TextColor3 = Cores.Tinta,
		Size = UDim2.new(1, -40, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		Parent = placaBanner.conteudo,
	})

	local placaToast = Kit.placa({
		largura = 560,
		altura = 50,
		fundo = Cores.Tinta,
		borda = Cores.Papel,
		espessura = 2,
		posicao = UDim2.new(0.5, 0, 1, -290),
		ancora = Vector2.new(0.5, 1),
		z = 20,
		pai = raiz,
	})
	toast = placaToast.quadro
	toast.Visible = false
	toastTexto = Kit.texto({
		fonte = "media",
		TextSize = 22,
		TextWrapped = true,
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(15, 0),
		Parent = placaToast.conteudo,
	})

	Remotos.evento("Aviso").OnClientEvent:Connect(function(dados: any)
		if type(dados) == "table" and type(dados.texto) == "string" then
			Avisos.toast(dados.texto)
		end
	end)
end

return Avisos
