local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Itens = require(Shared.Dados.Itens)
local Receitas = require(Shared.Dados.Receitas)
local Transcendencia = require(Shared.Dados.Transcendencia)
local Cores = require(Shared.Tema).Orbita
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)

local Altar = {}
local camada: CanvasGroup? = nil
local coracao: Part? = nil
local contadorCena = 0

function Altar.ativa(): boolean
	return camada ~= nil and camada.Visible
end

local function fecharCena()
	contadorCena += 1
	if coracao then
		coracao:Destroy()
		coracao = nil
	end
	if camada then
		camada:Destroy()
		camada = nil
	end
end

local function elevarCoracao(meu: number)
	local personagem = Players.LocalPlayer.Character
	local cabeca = if personagem then personagem:FindFirstChild("Head") else nil
	if not cabeca or not cabeca:IsA("BasePart") then
		return
	end
	local nexo = workspace:FindFirstChild("Nexo")
	local nucleo = if nexo then nexo:FindFirstChild("Nucleo") else nil
	local inicio = cabeca.CFrame * CFrame.new(0, 0, -2.6)
	local alto = inicio + Vector3.new(0, 2.5, 0)
	local gema: Part = Kit.novo("Part", {
		Name = "CoracaoDaRessonanciaLocal",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = Color3.fromHex("FFC83D"),
		Size = Vector3.new(0.8, 0.8, 0.8),
		CFrame = inicio * CFrame.Angles(0, math.rad(30), math.rad(45)),
		Parent = workspace,
	})
	coracao = gema
	TweenService:Create(gema, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {
		CFrame = alto * CFrame.Angles(0, math.rad(110), math.rad(45)),
		Color = Color3.fromHex("DD69E9"),
	}):Play()
	task.delay(0.75, function()
		if contadorCena ~= meu then
			return
		end
		local alvo = if nucleo
				and nucleo:IsA("Model")
				and nucleo.Parent
			then nucleo:GetPivot().Position + Vector3.new(0, 4, 0)
			else alto.Position + Vector3.new(0, 4, 0)
		TweenService:Create(gema, TweenInfo.new(0.58, Enum.EasingStyle.Sine), {
			Position = alvo,
			Transparency = 1,
		}):Play()
	end)
end

local function cena(raiz: Frame, nivel: number, reduzido: boolean, qualidadeBaixa: boolean)
	fecharCena()
	local meu = contadorCena
	local grupo: CanvasGroup = Kit.novo("CanvasGroup", {
		Name = "TranscendenciaConfirmada",
		BackgroundColor3 = Cores.Fundo,
		BackgroundTransparency = 0.64,
		GroupTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 45,
		Parent = raiz,
	})
	camada = grupo
	local placa = Kit.placa({
		tamanho = UDim2.new(0.88, 0, 0, 238),
		posicao = UDim2.fromScale(0.5, 0.5),
		ancora = Vector2.new(0.5, 0.5),
		borda = Color3.fromHex(Itens.Tiers[5].cor),
		pai = grupo,
	})
	Kit.novo("UISizeConstraint", { MaxSize = Vector2.new(560, 238), Parent = placa.quadro })
	local nucleo = Kit.cristal(placa.conteudo, 58, Color3.fromHex(Itens.Tiers[5].cor))
	nucleo.AnchorPoint = Vector2.new(0.5, 0)
	nucleo.Position = UDim2.new(0.5, 0, 0, 24)
	Kit.texto({
		fonte = "titulo",
		Text = "TRANSCENDÊNCIA "
			.. ({ "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" })[nivel],
		TextSize = 28,
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 94),
		Size = UDim2.new(1, -20, 0, 46),
		Parent = placa.conteudo,
	})
	Kit.texto({
		Text = string.format(
			"+%.0f%% na chance de auras raras ou superiores",
			(Transcendencia.sorte(nivel) - 1) * 100
		),
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 138),
		Size = UDim2.new(1, -20, 0, 38),
		Parent = placa.conteudo,
	})
	local pular = Kit.botaoPlaca({
		texto = "Continuar",
		tamanho = UDim2.fromOffset(150, 42),
		tamanhoTexto = 16,
		pai = placa.conteudo,
		aoClicar = fecharCena,
	})
	pular.placa.quadro.AnchorPoint = Vector2.new(0.5, 1)
	pular.placa.quadro.Position = UDim2.new(0.5, 0, 1, -10)
	if not reduzido then
		local escala: UIScale = Kit.novo("UIScale", { Scale = 0.65, Parent = nucleo })
		TweenService:Create(escala, TweenInfo.new(0.55, Enum.EasingStyle.Sine), { Scale = 1 })
			:Play()
		if not qualidadeBaixa then
			elevarCoracao(meu)
		end
	end
	task.delay(2.2, function()
		if contadorCena == meu then
			fecharCena()
		end
	end)
end

function Altar.montar(raiz: Frame, avisar: (string) -> ())
	local aba = "Forja"
	local armado: string? = nil
	local pendente = false
	local botoes: { [string]: Kit.BotaoPlaca } = {}
	local lista: Frame
	local atualizar: () -> ()

	local function pedir(acao: string, id: string?)
		if pendente then
			return
		end
		local chave = id or acao
		if armado ~= chave then
			armado = chave
			atualizar()
			return
		end
		armado = nil
		pendente = true
		atualizar()
		task.spawn(function()
			local ok, msg, dados = Estado.pedir(acao, id)
			pendente = false
			atualizar()
			if msg then
				avisar(msg)
			end
			if ok and acao == "Transcender" and dados and type(dados.nivel) == "number" then
				Navegacao.fechar()
				local estado = Estado.atual
				cena(
					raiz,
					dados.nivel,
					estado ~= nil and estado.configuracoes.movimentoReduzido == true,
					estado ~= nil and estado.configuracoes.qualidadeBaixa == true
				)
			end
		end)
	end

	local ord = 0
	local function linha(texto: string, titulo: boolean?)
		ord += 1
		Kit.texto({
			fonte = if titulo then "titulo" else nil,
			Text = texto,
			TextColor3 = if titulo then Cores.Lilas else Cores.Texto,
			TextSize = if titulo then 22 else 17,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -12, 0, 0),
			LayoutOrder = ord,
			Parent = lista,
		})
	end

	local function botao(texto: string, disponivel: boolean, aoClicar: () -> ())
		ord += 1
		local b = Kit.botaoPlaca({
			texto = if pendente then "Aguardando confirmação…" else texto,
			tamanho = UDim2.new(1, -12, 0, 46),
			tamanhoTexto = 18,
			ordem = ord,
			tom = if disponivel and not pendente then "lilas" else "neutro",
			pai = lista,
			aoClicar = aoClicar,
		})
		b.botao.Interactable = disponivel and not pendente
	end

	local function mostrarCustos(estoque: Itens.Estoque, custo: Itens.Estoque)
		local nomes: { string } = {}
		for ingrediente, qtd in custo do
			table.insert(
				nomes,
				string.format(
					"%s  ·  %d / %d",
					Itens.porId[ingrediente].nome,
					estoque[ingrediente] or 0,
					qtd
				)
			)
		end
		table.sort(nomes)
		linha(table.concat(nomes, "\n"))
	end

	atualizar = function()
		if Navegacao.aberto() ~= "Altar" then
			return
		end
		for _, filho in lista:GetChildren() do
			if filho:IsA("GuiObject") then
				filho:Destroy()
			end
		end
		ord = 0
		for nome, b in botoes do
			b.definirTom(if nome == aba then "lilas" else "neutro")
		end
		local estado = Estado.atual
		if not estado then
			linha("Carregando seu perfil…")
			return
		end
		local estoque = estado.inventario.itens
		if aba == "Forja" then
			linha(
				"Conclua andares em Cinzas e use os materiais para forjar o Coração da Ressonância."
			)
			for _, id in Receitas.ordem do
				local receita = Receitas.porId[id]
				linha(Itens.porId[receita.resultado].nome, true)
				mostrarCustos(estoque, receita.custo)
				botao(
					if armado == id then "Confirmar fabricação" else "Fabricar",
					Receitas.podeFabricar(estoque, receita),
					function()
						pedir("FabricarItem", id)
					end
				)
			end
		else
			local nivel = estado.transcendencia.nivel
			local sorte = Transcendencia.sorte(nivel)
			linha(string.format("Transcendência %d / %d", nivel, Transcendencia.MAXIMO), true)
			linha(
				(
					string.gsub(
						string.format(
							"Sorte atual %.2fx  ·  Bônus permanente +%.0f%%\nO bônus aumenta a chance de auras raras ou superiores.",
							sorte,
							(sorte - 1) * 100
						),
						"%.",
						","
					)
				)
			)
			local custo = Transcendencia.custo(nivel)
			if not custo then
				linha("Você já alcançou o nível máximo disponível.")
				return
			end
			linha(string.format("Oferta para o nível %d", nivel + 1), true)
			mostrarCustos(estoque, custo)
			linha(
				string.format(
					"Bônus após a oferta  ·  +%.0f%% para auras raras ou superiores.",
					(Transcendencia.sorte(nivel + 1) - 1) * 100
				)
			)
			botao(
				if armado == "Transcender" then "Confirmar oferta" else "Transcender",
				Transcendencia.podeOferecer(estoque, custo),
				function()
					pedir("Transcender")
				end
			)
		end
	end

	local painel = Navegacao.criarPainel(
		"Altar",
		{ titulo = "Altar da Ressonância", icone = "◆" },
		function()
			armado = nil
			atualizar()
		end
	)
	for i, nome in { "Forja", "Transcender" } do
		local b = Kit.botaoPlaca({
			texto = nome,
			tamanho = UDim2.new(0.5, -16, 0, 46),
			tamanhoTexto = 19,
			pai = painel.conteudo,
			aoClicar = function()
				aba = nome
				armado = nil
				atualizar()
			end,
		})
		b.placa.quadro.Position = UDim2.new((i - 1) * 0.5, 10, 0, 4)
		botoes[nome] = b
	end
	local rolagem = Kit.rolagem(painel.conteudo)
	rolagem.Position = UDim2.fromOffset(12, 58)
	rolagem.Size = UDim2.new(1, -24, 1, -64)
	lista = Kit.novo("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = rolagem,
	})
	Kit.novo(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lista }
	)
	Estado.aoMudar(atualizar)
	Players.LocalPlayer.CharacterAdded:Connect(fecharCena)
end

return Altar
