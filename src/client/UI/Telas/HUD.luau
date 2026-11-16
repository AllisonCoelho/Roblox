-- HUD principal: botão DESPERTAR, giro automático, índice, contador e aura equipada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Perfil = require(Shared.Dados.Perfil)
local Tema = require(Shared.Tema)
local C = require(script.Parent.Parent.Componentes)

local Cores = Tema.Cores
local HUD = {}

export type Opcoes = {
	aoDespertar: () -> (),
	aoAlternarAuto: () -> (),
	aoAbrirIndice: () -> (),
	aoAlternarAnuncios: () -> (),
}

export type Api = {
	definirPronto: (pronto: boolean) -> (),
	atualizar: (estado: Perfil.Estado) -> (),
}

function HUD.montar(raiz: Frame, op: Opcoes): Api
	-- Cartão de informações (canto superior esquerdo)
	local info = C.cartaoEscuro({
		Name = "Info",
		Size = UDim2.fromOffset(380, 132),
		Position = UDim2.fromOffset(20, 20),
		Parent = raiz,
	})
	C.padding(info, 18, 12)
	C.lista(info, Enum.FillDirection.Vertical, 2)
	local giros = C.texto({
		Name = "Giros",
		Text = "Giros: 0",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = 1,
		Parent = info,
	})
	local equipada = C.texto({
		Name = "Equipada",
		Text = "Nenhuma aura",
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 2,
		Parent = info,
	})
	local raridade = C.texto({
		Name = "Raridade",
		Text = "Clique em DESPERTAR!",
		TextSize = 20,
		TextColor3 = Cores.CinzaClaro,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 3,
		Parent = info,
	})

	-- Botão de anúncios (abaixo do cartão: o canto direito fica para a lista de jogadores do Roblox)
	local anuncios = C.botao({
		cor = "roxo",
		icone = "🔔",
		tamanho = UDim2.fromOffset(72, 72),
		tamanhoIcone = 34,
		posicao = UDim2.fromOffset(20, 172),
		pai = raiz,
		aoClicar = op.aoAlternarAnuncios,
	})

	-- Barra inferior
	local barra = C.novo("Frame", {
		Name = "Acoes",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(860, 112),
		Parent = raiz,
	})
	C.lista(
		barra,
		Enum.FillDirection.Horizontal,
		24,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Bottom
	)
	local auto = C.botao({
		cor = "ardosia",
		icone = "🔁",
		texto = "AUTO",
		tamanho = UDim2.fromOffset(190, 84),
		tamanhoTexto = 26,
		ordem = 1,
		pai = barra,
		aoClicar = op.aoAlternarAuto,
	})
	local despertar = C.botao({
		cor = "roxo",
		icone = "✨",
		texto = "DESPERTAR",
		tamanho = UDim2.fromOffset(400, 104),
		tamanhoTexto = 38,
		ordem = 2,
		pai = barra,
		aoClicar = op.aoDespertar,
	})
	C.botao({
		cor = "azul",
		icone = "📖",
		texto = "ÍNDICE",
		tamanho = UDim2.fromOffset(190, 84),
		tamanhoTexto = 26,
		ordem = 3,
		pai = barra,
		aoClicar = op.aoAbrirIndice,
	})

	return {
		definirPronto = function(pronto: boolean)
			despertar.definirCor(if pronto then "roxo" else "cinza")
		end,
		atualizar = function(estado: Perfil.Estado)
			giros.Text = "Giros: " .. Formato.inteiro(estado.giros)
			local aura = if estado.equipada then Auras.porId[estado.equipada] else nil
			if aura then
				local tier = Auras.Tiers[aura.tier]
				equipada.Text = aura.nome
				equipada.TextColor3 = Color3.fromHex(tier.cor)
				raridade.Text =
					string.format("%s • 1 em %s", tier.nome, Formato.inteiro(aura.chance))
			else
				equipada.Text = "Nenhuma aura"
				equipada.TextColor3 = Cores.Branco
				raridade.Text = "Clique em DESPERTAR!"
			end
			local ligado = estado.configuracoes.giroAutomatico == true
			auto.definirCor(if ligado then "verde" else "ardosia")
			auto.definirTexto(if ligado then "AUTO ✓" else "AUTO")
			anuncios.definirCor(if estado.configuracoes.anuncios ~= false then "roxo" else "cinza")
		end,
	}
end

return HUD
