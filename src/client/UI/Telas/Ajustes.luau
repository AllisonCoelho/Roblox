-- Preferências sincronizadas pelo servidor, agrupadas pelo que o jogador quer ajustar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cores = require(ReplicatedStorage.Shared.Tema).Orbita
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Estado = require(script.Parent.Parent.Estado)

local Ajustes = {}

local SECOES = {
	{
		titulo = "Ritual",
		opcoes = {
			{ "sons", "Sons do ritual", "Toca os efeitos sonoros do giro." },
			{ "animacoes", "Animações do giro", "Exibe o ritual, a pose e a câmera do despertar." },
			{ "pularRepetidas", "Animação curta para auras repetidas", "Encurta o ritual de auras que você já tem." },
		},
	},
	{
		titulo = "Coleção e avisos",
		opcoes = {
			{ "anuncios", "Anúncios de auras raras", "Mostra as descobertas raras do servidor." },
			{ "equiparAutomatico", "Equipar a mais rara automaticamente", "Troca a aura equipada quando sair uma mais rara." },
		},
	},
	{
		titulo = "Acessibilidade e desempenho",
		opcoes = {
			{ "movimentoReduzido", "Movimento reduzido", "Evita movimentos de câmera, poses e tremor do ritual." },
			{ "qualidadeBaixa", "Qualidade baixa", "Reduz anéis, partículas e rastros." },
			{ "ocultarEfeitosAlheios", "Ocultar efeitos dos outros jogadores", "Oculta rituais e auras de outros jogadores na sua tela." },
		},
	},
}

local function descricaoOpcao(pai: Frame, titulo: string, descricao: string)
	local texto = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -170, 0, 0),
		Position = UDim2.fromOffset(12, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = pai,
	})
	Kit.novo("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = texto })
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = texto,
	})
	Kit.texto({
		fonte = "titulo",
		Text = titulo,
		TextSize = 23,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = texto,
	})
	Kit.texto({
		Text = descricao,
		TextSize = 16,
		TextColor3 = Cores.TextoSuave,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = texto,
	})
end

function Ajustes.montar(aoAviso: (string) -> ())
	local painel = Navegacao.criarPainel("Ajustes", { titulo = "Ajustes", icone = "⚙" })
	local rolagem = Kit.rolagem(painel.conteudo)
	Kit.novo("UIListLayout", {
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = rolagem,
	})

	local interruptores: { [string]: Kit.BotaoPlaca } = {}
	local ordem = 0
	for _, secao in SECOES do
		ordem += 1
		Kit.texto({
			Text = string.upper(secao.titulo),
			TextSize = 15,
			TextColor3 = Cores.Lilas,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -12, 0, 34),
			LayoutOrder = ordem,
			Parent = rolagem,
		})
		for _, opcao in secao.opcoes do
			ordem += 1
			local chave, titulo, descricao = opcao[1], opcao[2], opcao[3]
			local linha = Kit.novo("Frame", {
				Name = chave,
				BackgroundColor3 = Cores.Elevado,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -12, 0, 76),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = ordem,
				Parent = rolagem,
			})
			Kit.novo("UICorner", { CornerRadius = UDim.new(0, 6), Parent = linha })
			descricaoOpcao(linha, titulo, descricao)
			local botao = Kit.botaoPlaca({
				texto = "○ Desligado",
				tamanho = UDim2.fromOffset(136, 64),
				tamanhoTexto = 18,
				aoClicar = function()
					local estado = Estado.atual
					if not estado then
						return
					end
					local controle = interruptores[chave].botao
					controle.Interactable = false
					task.spawn(function()
						local ok, msg = Estado.pedir("Configurar", chave, not estado.configuracoes[chave])
						controle.Interactable = true
						if not ok and msg then
							aoAviso(msg)
						end
					end)
				end,
			})
			botao.botao.Text = titulo
			botao.placa.quadro.AnchorPoint = Vector2.new(1, 0.5)
			botao.placa.quadro.Position = UDim2.new(1, -10, 0.5, 0)
			botao.placa.quadro.Parent = linha
			interruptores[chave] = botao
		end
	end

	Estado.aoMudar(function(estado)
		for chave, botao in interruptores do
			local ligado = estado.configuracoes[chave] == true
			botao.definirTom(if ligado then "menta" else "neutro")
			botao.rotulo.Text = if ligado then "● Ligado" else "○ Desligado"
		end
	end)
end

function Ajustes.abrir()
	Navegacao.alternar("Ajustes")
end

return Ajustes
