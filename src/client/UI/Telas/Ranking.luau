-- Painel do Ranking: quem mais rende neste servidor e o recorde no mundo todo
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Formato = require(Shared.Formato)
local UI = script.Parent.Parent
local C = require(UI.Componentes)
local Navegacao = require(UI.Navegacao)

local Cores = Tema.Cores
local Ranking = {}

local MEDALHAS = { "🥇", "🥈", "🥉" }

local function coluna(pai: Instance, titulo: string, icone: string, x: number): ScrollingFrame
	local caixa = C.cartaoClaro({
		Size = UDim2.new(0.5, -36, 1, -40),
		Position = UDim2.new(x, if x > 0 then 12 else 24, 0, 18),
		Parent = pai,
	}, 22)
	C.emoji(icone, 34, { Position = UDim2.fromOffset(16, 10), Parent = caixa })
	C.textoEscuro({
		Text = titulo,
		Font = Tema.Fonte,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -80, 0, 50),
		Position = UDim2.fromOffset(66, 6),
		Parent = caixa,
	})
	local lista = C.novo("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 1, -72),
		Position = UDim2.fromOffset(12, 62),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Cores.Contorno,
		Parent = caixa,
	})
	C.lista(lista, Enum.FillDirection.Vertical, 8)
	return lista
end

local function linha(
	lista: Instance,
	posicao: number,
	nome: string,
	valor: number,
	destaque: boolean
)
	local f = C.cartaoClaro({
		Size = UDim2.new(1, -8, 0, 52),
		LayoutOrder = posicao,
		BackgroundColor3 = if destaque then Cores.OuroClaro else Cores.Lilas,
		Parent = lista,
	}, 14)
	C.textoEscuro({
		Text = MEDALHAS[posicao] or (posicao .. "º"),
		Font = Tema.Fonte,
		TextSize = 24,
		Size = UDim2.fromOffset(56, 52),
		Parent = f,
	})
	C.textoEscuro({
		Text = nome,
		Font = Tema.Fonte,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -230, 1, 0),
		Position = UDim2.fromOffset(60, 0),
		Parent = f,
	})
	C.textoEscuro({
		Text = "🪙 " .. Formato.curto(valor) .. "/s",
		Font = Tema.Fonte,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(160, 52),
		Position = UDim2.new(1, -172, 0, 0),
		Parent = f,
	})
end

local function limpar(lista: Instance)
	for _, f in lista:GetChildren() do
		if f:IsA("Frame") then
			f:Destroy()
		end
	end
end

local function vazio(lista: Instance, texto: string)
	C.textoEscuro({
		Text = texto,
		TextSize = 20,
		TextColor3 = Cores.TextoSuave,
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 60),
		BackgroundTransparency = 1,
		Parent = lista,
	})
end

function Ranking.montar()
	local painel =
		Navegacao.criarPainel("Ranking", { titulo = "Ranking", icone = "🏆", cor = "ouro" })
	local servidor = coluna(painel.conteudo, "Neste servidor", "🏠", 0)
	local mundo = coluna(painel.conteudo, "Recordes do mundo", "🌎", 0.5)

	local function desenhar()
		limpar(servidor)
		limpar(mundo)
		for _, f in servidor:GetChildren() do
			if f:IsA("TextLabel") then
				f:Destroy()
			end
		end
		for _, f in mundo:GetChildren() do
			if f:IsA("TextLabel") then
				f:Destroy()
			end
		end
		-- Servidor: lê o placar (leaderstats) de cada jogador
		local jogadores = {}
		for _, p in Players:GetPlayers() do
			local stats = p:FindFirstChild("leaderstats")
			local renda = stats and stats:FindFirstChild("Renda/s") :: IntValue?
			table.insert(jogadores, {
				nome = p.DisplayName,
				valor = if renda then renda.Value else 0,
				eu = p == Players.LocalPlayer,
			})
		end
		table.sort(jogadores, function(a, b)
			return a.valor > b.valor
		end)
		for i, j in jogadores do
			linha(servidor, i, j.nome, j.valor, j.eu)
		end
		-- Mundo: lista publicada pelo servidor
		local pasta = ReplicatedStorage:FindFirstChild("Ranking")
		local global = pasta and pasta:FindFirstChild("Global") :: StringValue?
		local ok, lista = pcall(function()
			return HttpService:JSONDecode(if global then global.Value else "[]")
		end)
		if not ok or type(lista) ~= "table" or #lista == 0 then
			vazio(
				mundo,
				"O ranking do mundo aparece no jogo publicado (atualiza a cada 2 minutos)."
			)
			return
		end
		for i, j in lista do
			if type(j) == "table" and type(j.nome) == "string" and type(j.valor) == "number" then
				linha(mundo, i, j.nome, j.valor, j.nome == Players.LocalPlayer.DisplayName)
			end
		end
	end

	Navegacao.aoTrocar(function(nome)
		if nome == "Ranking" then
			desenhar()
		end
	end)
end

return Ranking
