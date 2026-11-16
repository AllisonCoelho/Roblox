-- Ajustes do jogador: anúncios, sons, equipar automático e opções de acessibilidade/desempenho.
-- Cada opção é salva no servidor (ação "Configurar"); nenhuma delas muda resultado ou chance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = require(ReplicatedStorage.Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Estado = require(script.Parent.Parent.Estado)

local Cores = Tema.Cores
local Ajustes = {}

local OPCOES = {
	{
		"anuncios",
		"Anúncios de auras raras",
		"Mostra quando alguém do servidor desperta 1 em 1.000 ou mais raro.",
	},
	{ "sons", "Sons do ritual", "Efeitos sonoros do giro." },
	{
		"equiparAutomatico",
		"Equipar a mais rara automaticamente",
		"Troca sozinho de aura quando sair uma mais rara que a equipada.",
	},
	{
		"pularRepetidas",
		"Animação curta para auras repetidas",
		"Auras que você já tem usam a animação rápida. O resultado não muda.",
	},
	{
		"movimentoReduzido",
		"Movimento reduzido",
		"Sem câmera de cinema, tremor nem escurecimento da tela.",
	},
	{
		"qualidadeBaixa",
		"Qualidade baixa",
		"Menos anéis, partículas e rastros. Bom para celular fraco.",
	},
	{
		"ocultarEfeitosAlheios",
		"Ocultar efeitos dos outros jogadores",
		"Esconde rituais e auras dos outros. Só muda o que você vê.",
	},
}

function Ajustes.montar(aoAviso: (string) -> ())
	local painel =
		Navegacao.criarPainel("Ajustes", { titulo = "Ajustes", icone = "⚙", cor = "selo" })
	local rolagem = Kit.novo("ScrollingFrame", {
		Name = "Lista",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Cores.Papel,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = painel.conteudo,
	})
	Kit.novo("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 24),
		Parent = rolagem,
	})
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rolagem,
	})

	local interruptores: { [string]: Kit.BotaoPlaca } = {}
	for i, opcao in OPCOES do
		local chave, titulo, descricao = opcao[1], opcao[2], opcao[3]
		local linha = Kit.novo("Frame", {
			Name = chave,
			BackgroundColor3 = Cores.Tinta,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 78),
			LayoutOrder = i,
			Parent = rolagem,
		})
		Kit.texto({
			Text = titulo,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(18, 8),
			Size = UDim2.new(1, -220, 0, 32),
			Parent = linha,
		})
		Kit.texto({
			fonte = "media",
			Text = descricao,
			TextSize = 17,
			TextColor3 = Cores.TextoSuave,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Position = UDim2.fromOffset(18, 40),
			Size = UDim2.new(1, -220, 0, 30),
			Parent = linha,
		})
		local botao = Kit.botaoPlaca({
			texto = "NÃO",
			largura = 150,
			altura = 50,
			tamanhoTexto = 22,
			sombra = Color3.new(0, 0, 0),
			aoClicar = function()
				local estado = Estado.atual
				if not estado then
					return
				end
				task.spawn(function()
					local ok, msg =
						Estado.pedir("Configurar", chave, not estado.configuracoes[chave])
					if not ok and msg then
						aoAviso(msg)
					end
				end)
			end,
		})
		botao.placa.quadro.AnchorPoint = Vector2.new(1, 0.5)
		botao.placa.quadro.Position = UDim2.new(1, -18, 0.5, 0)
		botao.placa.quadro.Parent = linha
		interruptores[chave] = botao
	end

	Estado.aoMudar(function(estado)
		for chave, botao in interruptores do
			local ligado = estado.configuracoes[chave] == true
			botao.definirAtivo(ligado)
			botao.definirTexto(if ligado then "SIM" else "NÃO")
		end
	end)
end

function Ajustes.abrir()
	Navegacao.alternar("Ajustes")
end

return Ajustes
