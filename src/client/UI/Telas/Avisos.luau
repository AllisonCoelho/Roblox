-- Mensagens locais e anúncios de auras raras na área segura da interface.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local Cores = require(Shared.Tema).Orbita
local Kit = require(script.Parent.Parent.Kit)
local Estado = require(script.Parent.Parent.Estado)
local Escala = require(script.Parent.Parent.Escala)

local Avisos = {}

local toast: Kit.Placa
local toastTexto: TextLabel
local toastToken = 0
local banner: Kit.Placa
local bannerTexto: TextLabel
local bannerToken = 0

local function escapar(texto: string): string
	return (texto:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Avisos.toast(texto: string)
	toastToken += 1
	local meu = toastToken
	toastTexto.Text = texto
	toast.quadro.Visible = true
	task.delay(2.5, function()
		if toastToken == meu then
			toast.quadro.Visible = false
		end
	end)
end

function Avisos.anunciar(nomeJogador: string, _userId: number, aura: Auras.Aura)
	if aura.chance < Auras.ANUNCIO_MINIMO then
		return
	end
	local estado = Estado.atual
	if estado and estado.configuracoes.anuncios == false then
		return
	end
	local tier = Auras.Tiers[aura.tier]
	local cor = Color3.fromHex(tier.cor)
	local corLegivel = Kit.corLegivel(cor):ToHex()
	local nome = escapar(nomeJogador)
	local auraNome = escapar(aura.nome)
	local chance = Formato.chance(aura.chance)
	bannerTexto.Text = string.format(
		'<b>%s</b> despertou <font color="#%s"><b>%s</b></font> · 1 em %s',
		nome,
		corLegivel,
		auraNome,
		chance
	)
	banner.definirCor(Cores.Painel, cor)
	bannerToken += 1
	local meu = bannerToken
	banner.quadro.Visible = true
	task.delay(5, function()
		if bannerToken == meu then
			banner.quadro.Visible = false
		end
	end)
	pcall(function()
		local canais = TextChatService:FindFirstChild("TextChannels")
		local geral = canais and canais:FindFirstChild("RBXGeneral")
		if geral and geral:IsA("TextChannel") then
			geral:DisplaySystemMessage(
				string.format(
					'<b>%s</b> despertou <font color="#%s"><b>%s</b></font> (1 em %s)!',
					nome,
					tier.cor,
					auraNome,
					chance
				)
			)
		end
	end)
end

local function mensagem(raiz: Frame, titulo: string, cor: Color3): (Kit.Placa, TextLabel)
	local placa = Kit.placa({
		tamanho = UDim2.fromOffset(520, 78),
		borda = cor,
		z = 40,
		pai = raiz,
	})
	placa.quadro.Visible = false
	Kit.texto({
		Text = titulo,
		TextSize = 14,
		TextColor3 = cor,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(1, -28, 0, 24),
		Parent = placa.conteudo,
	})
	local texto = Kit.texto({
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 31),
		Size = UDim2.new(1, -28, 1, -36),
		Parent = placa.conteudo,
	})
	return placa, texto
end

function Avisos.montar(raiz: Frame)
	banner, bannerTexto = mensagem(raiz, "◆  ANÚNCIO DO SERVIDOR", Cores.Lilas)
	bannerTexto.RichText = true
	banner.quadro.AnchorPoint = Vector2.new(0.5, 0)
	toast, toastTexto = mensagem(raiz, "◆  AVISO", Cores.Aviso)
	toast.quadro.AnchorPoint = Vector2.new(0.5, 1)

	Escala.aoMudar(function()
		local largura = Escala.tamanho.X
		local estreito = largura < 820
		local altura = if estreito then 96 else 78
		banner.quadro.Size = UDim2.fromOffset(math.min(550, largura - 30), altura)
		banner.quadro.Position = UDim2.new(0.5, 0, 0, if estreito then 174 else 12)
		toast.quadro.Size = UDim2.fromOffset(math.min(480, largura - 30), altura)
		local margem = if Escala.toque and largura < 710 then 256 elseif Escala.compacto then 156 else 192
		toast.quadro.Position = UDim2.new(0.5, 0, 1, -margem)
	end)
	Remotos.evento("Aviso").OnClientEvent:Connect(function(dados: any)
		if type(dados) == "table" and type(dados.texto) == "string" then
			Avisos.toast(dados.texto)
		end
	end)
end

return Avisos
