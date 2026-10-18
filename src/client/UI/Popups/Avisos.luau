-- Avisos curtos no topo da tela: sucesso, erro, info e "saiu um raro da fábrica"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Remotos = require(Shared.Remotos)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Visual = require(UI.Visual)

local Cores = Tema.Cores
local Avisos = {}

local MAX_VISIVEIS = 3
local DURACAO = 3.2

local pilha: Frame
local ordem = 0

local BORDAS = {
	sucesso = Cores.Menta,
	erro = Cores.Vermelho,
	info = Cores.Ceu,
	raro = Cores.Ouro,
}

export type Tipo = "sucesso" | "erro" | "info" | "raro"

function Avisos.mostrar(tipo: string, texto: string, docinhoId: string?)
	ordem += 1
	local cartao = C.novo("Frame", {
		Name = "Aviso",
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 0.08,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, if docinhoId then 72 else 56),
		LayoutOrder = ordem,
		Parent = pilha,
	})
	C.cantos(cartao, 18)
	C.contorno(cartao, 4, BORDAS[tipo] or Cores.Ceu)
	C.padding(cartao, 16, 6)
	C.lista(
		cartao,
		Enum.FillDirection.Horizontal,
		12,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	if docinhoId then
		Visual.docinho(docinhoId, { tamanho = UDim2.fromOffset(60, 60), ordem = 1, pai = cartao })
	end
	local icone = if tipo == "sucesso"
		then "✅"
		elseif tipo == "erro" then "⚠️"
		elseif tipo == "info" then "💬"
		else nil
	if icone then
		C.emoji(icone, 26, { LayoutOrder = 1, Parent = cartao })
	end
	C.texto({
		Text = texto,
		TextSize = 22,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		LayoutOrder = 2,
		Parent = cartao,
	})

	local filhos = {}
	for _, f in pilha:GetChildren() do
		if f:IsA("Frame") then
			table.insert(filhos, f)
		end
	end
	if #filhos > MAX_VISIVEIS then
		table.sort(filhos, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		filhos[1]:Destroy()
	end

	task.delay(DURACAO, function()
		if cartao.Parent then
			local t =
				TweenService:Create(cartao, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			t:Play()
			t.Completed:Wait()
			cartao:Destroy()
		end
	end)
end

-- Atalho para mostrar o resultado de Estado.pedir
function Avisos.resultado(ok: boolean, msg: string?)
	if msg and msg ~= "" then
		Avisos.mostrar(if ok then "sucesso" else "erro", msg)
	end
end

function Avisos.montar(raiz: Frame)
	pilha = C.novo("Frame", {
		Name = "Avisos",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 300),
		Position = UDim2.fromOffset(0, 100),
		ZIndex = 40,
		Parent = raiz,
	})
	C.lista(pilha, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Center)

	Remotos.evento("Aviso").OnClientEvent:Connect(function(dados: any)
		if type(dados) ~= "table" then
			return
		end
		if dados.tipo == "raro" and type(dados.docinho) == "string" then
			local d = Catalogo.docinho(dados.docinho)
			local r = Catalogo.raridadeDe(dados.docinho)
			if d and r then
				local cor = r.cor:ToHex()
				Avisos.mostrar(
					"raro",
					string.format(
						'Um <font color="#%s">%s %s</font> saiu da fábrica!',
						cor,
						d.nome,
						string.upper(r.nome)
					),
					d.id
				)
			end
		elseif type(dados.texto) == "string" then
			Avisos.mostrar(dados.tipo or "info", dados.texto)
		end
	end)
end

return Avisos
