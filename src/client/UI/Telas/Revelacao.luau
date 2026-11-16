-- Animação de revelação da aura sorteada: nomes passando rápido e depois o resultado.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local C = require(script.Parent.Parent.Componentes)

local Revelacao = {}

local quadro: Frame
local escala: UIScale
local tierTexto: TextLabel
local nomeTexto: TextLabel
local chanceTexto: TextLabel
local clarao: Frame
local token = 0

function Revelacao.montar(raiz: Frame)
	quadro = C.novo("Frame", {
		Name = "Revelacao",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(900, 200),
		Visible = false,
		ZIndex = 10,
		Parent = raiz,
	})
	escala = C.novo("UIScale", { Parent = quadro })
	C.lista(quadro, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center)
	tierTexto = C.texto({
		Name = "Tier",
		TextSize = 32,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 1,
		ZIndex = 10,
		Parent = quadro,
	})
	nomeTexto = C.texto({
		Name = "Nome",
		TextSize = 76,
		contorno = 4,
		Size = UDim2.new(1, 0, 0, 90),
		LayoutOrder = 2,
		ZIndex = 10,
		Parent = quadro,
	})
	chanceTexto = C.texto({
		Name = "Chance",
		TextSize = 30,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
		ZIndex = 10,
		Parent = quadro,
	})
	clarao = C.novo("Frame", {
		Name = "Clarao",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
		Parent = raiz,
	})
end

local function exibir(aura: Auras.Aura, final: boolean)
	local tier = Auras.Tiers[aura.tier]
	local cor = Color3.fromHex(tier.cor)
	nomeTexto.Text = aura.nome
	nomeTexto.TextColor3 = if final then cor else Color3.new(0.85, 0.85, 0.9)
	tierTexto.Text = if final then string.upper(tier.nome) else ""
	tierTexto.TextColor3 = cor
	chanceTexto.Text = if final then "1 em " .. Formato.inteiro(aura.chance) else ""
end

-- rapido = giro automático: pula a roleta e mostra só o resultado
function Revelacao.mostrar(aura: Auras.Aura, rapido: boolean)
	token += 1
	local meu = token
	task.spawn(function()
		quadro.Visible = true
		if not rapido then
			local passos = if aura.chance >= Auras.ANUNCIO_MINIMO then 14 else 8
			for i = 1, passos do
				exibir(Auras.lista[math.random(1, #Auras.lista)], false)
				escala.Scale = 0.9
				task.wait(0.035 + i * 0.006)
				if token ~= meu then
					return
				end
			end
		end
		exibir(aura, true)
		escala.Scale = 1.3
		TweenService:Create(escala, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
		if aura.chance >= Auras.ANUNCIO_MINIMO then
			clarao.BackgroundColor3 = Color3.fromHex(Auras.Tiers[aura.tier].cor)
			clarao.BackgroundTransparency = 0.3
			TweenService:Create(clarao, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		end
		task.wait(if aura.chance >= Auras.ANUNCIO_MINIMO then 3 else 1.6)
		if token == meu then
			quadro.Visible = false
		end
	end)
end

return Revelacao
