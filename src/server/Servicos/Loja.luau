-- Loja: melhorias (moedas), boosts (granulados), pacotes de granulados e passes (Robux)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local LojaDados = require(Shared.Dados.Loja)
local Formato = require(Shared.Formato)
local Economia = require(Shared.Dados.Economia)
local Remotos = require(Shared.Remotos)
local Tema = require(Shared.Tema)
local Construtor = require(script.Parent.Parent.Mundo.Construtor)
local Dados = require(script.Parent.Dados)
local Compras = require(script.Parent.Compras)
local Acoes = require(script.Parent.Acoes)
local Missoes = require(script.Parent.Missoes)

local Loja = {}

-- Coroa "VIP" em cima da cabeça de quem tem o passe
local function coroaVip(player: Player)
	local estado = Dados.de(player)
	local personagem = player.Character
	local cabeca = personagem and personagem:FindFirstChild("Head")
	if not estado or not estado.passes.vip or not cabeca or cabeca:FindFirstChild("CoroaVip") then
		return
	end
	Construtor.placa(cabeca, "👑 VIP", {
		nome = "CoroaVip",
		tamanho = UDim2.new(4, 0, 1.4, 0),
		deslocamento = Vector3.new(0, 3.4, 0),
		distancia = 80,
		cor = Tema.Cores.OuroClaro,
	})
end

local function marcarPasse(player: Player, passeId: string)
	Dados.alterar(player, function(estado)
		if estado.passes[passeId] then
			return false
		end
		estado.passes[passeId] = true
		return true
	end)
	if passeId == "vip" then
		coroaVip(player)
	end
end

-- Compras de Developer Products (pacotes de granulados). As regras e o porquê de cada passo
-- estão em Servicos/Compras.luau.
local ESPERA_CARREGAR = 20 -- o jogador pode ter acabado de entrar (ou trocado de servidor)

local function processarRecibo(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Dados.esperarCarregar(player, ESPERA_CARREGAR)
	local decisao = Compras.processar(info :: any, {
		estado = function()
			return if Dados.podeSalvar(player) then Dados.de(player) else nil
		end,
		pacote = LojaDados.pacoteDoProduto,
		salvar = function()
			return Dados.salvar(player)
		end,
		entregue = function(pacote)
			Dados.enviar(player)
			Remotos.evento("Aviso"):FireClient(player, {
				tipo = "sucesso",
				texto = "+" .. Formato.inteiro(pacote.granulados) .. " granulados! Obrigado 💖",
			})
		end,
	}, os.time())
	if decisao == "PurchaseGranted" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not LojaDados.pacoteDoProduto(info.ProductId) then
		warn("[Loja] produto desconhecido: " .. tostring(info.ProductId))
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Confere no Roblox os passes que o jogador já tem (compras feitas fora do jogo também contam)
local function verificarPasses(player: Player)
	for _, passe in LojaDados.Passes do
		if passe.gamePassId ~= 0 then
			local ok, tem = pcall(
				MarketplaceService.UserOwnsGamePassAsync,
				MarketplaceService,
				player.UserId,
				passe.gamePassId
			)
			if ok and tem then
				marcarPasse(player, passe.id)
			end
		end
	end
end

function Loja.iniciar()
	Dados.quandoCarregar(function(player: Player)
		task.spawn(verificarPasses, player)
		coroaVip(player)
		player.CharacterAdded:Connect(function(personagem)
			personagem:WaitForChild("Head", 10)
			coroaVip(player)
		end)
	end)

	MarketplaceService.ProcessReceipt = processarRecibo

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, comprou)
		if not comprou then
			return
		end
		for _, passe in LojaDados.Passes do
			if passe.gamePassId == gamePassId then
				marcarPasse(player, passe.id)
			end
		end
	end)

	Acoes.registrar("ComprarMelhoria", function(player, id: any)
		if type(id) ~= "string" or not LojaDados.melhoria(id) then
			return false, "Item inválido"
		end
		local ok, msg = Dados.alterar(player, function(estado)
			local nivel = estado.melhorias[id] or 0
			local custo = LojaDados.proximoCusto(id, nivel)
			if not custo then
				return false, "Já está no nível máximo"
			end
			if estado.moedas < custo then
				return false, "Faltam " .. Formato.curto(custo - estado.moedas) .. " moedas"
			end
			estado.moedas -= custo
			estado.melhorias[id] = nivel + 1
			return true, "Melhoria comprada!"
		end)
		if ok then
			Missoes.progredir(player, "comprar_melhoria", 1)
			-- O tênis muda a velocidade na hora (o personagem lê este atributo)
			if id == "tenis" then
				local estado = Dados.de(player)
				player:SetAttribute("NivelTenis", estado and estado.melhorias.tenis or 0)
			end
		end
		return ok, msg
	end)

	Acoes.registrar("ComprarBoost", function(player, id: any)
		local boost = type(id) == "string" and LojaDados.boost(id)
		if not boost then
			return false, "Item inválido"
		end
		return Dados.alterar(player, function(estado)
			if estado.granulados < boost.custoGranulados then
				return false,
					"Faltam " .. (boost.custoGranulados - estado.granulados) .. " granulados"
			end
			estado.granulados -= boost.custoGranulados
			-- Comprar de novo soma tempo ao boost que já está ativo
			local agora = os.time()
			estado.boosts[boost.id] = math.max(estado.boosts[boost.id] or 0, agora) + boost.duracao
			return true, boost.nome .. " ativado!"
		end)
	end)

	-- Renascer (regras em Shared/Dados/Economia.luau)
	Acoes.registrar("Renascer", function(player)
		local feitos = 0
		local ok, msg = Dados.alterar(player, function(estado)
			if estado.carregando then
				return false, "Entregue o Docinho que está carregando antes"
			end
			local custo = Economia.custoRenascer(estado.renascimentos)
			if estado.moedas < custo then
				return false,
					"Faltam " .. Formato.curto(custo - estado.moedas) .. " moedas para renascer"
			end
			estado.renascimentos += 1
			feitos = estado.renascimentos
			estado.moedas = 0
			estado.caixa = 0
			for id in estado.melhorias do
				if id ~= "vitrine" then
					estado.melhorias[id] = 0
				end
			end
			estado.granulados += Economia.RenascerGranulados * feitos
			return true
		end)
		if not ok then
			return false, msg
		end
		player:SetAttribute("Caixa", 0)
		player:SetAttribute("NivelTenis", 0)
		local bonus = math.floor((Economia.multiplicadorRenascer(feitos) - 1) * 100 + 0.5)
		return true,
			string.format(
				"Você renasceu! Agora sua vitrine rende +%d%% para sempre (+%d granulados)",
				bonus,
				Economia.RenascerGranulados * feitos
			)
	end)

	Acoes.registrar("ComprarPacote", function(player, id: any)
		local pacote = type(id) == "string" and LojaDados.pacote(id)
		if not pacote then
			return false, "Item inválido"
		end
		if pacote.productId == 0 then
			return false, "Este pacote chega em breve!"
		end
		if not Dados.podeSalvar(player) then
			return false, "Seu progresso não carregou; compras estão pausadas"
		end
		-- A janela oficial do Roblox cobra; os granulados chegam pelo ProcessReceipt
		MarketplaceService:PromptProductPurchase(player, pacote.productId)
		return true
	end)

	Acoes.registrar("ComprarPasse", function(player, id: any)
		local passe = type(id) == "string" and LojaDados.passe(id)
		if not passe then
			return false, "Item inválido"
		end
		local estado = Dados.de(player)
		if estado and estado.passes[passe.id] then
			return false, "Você já tem este passe"
		end
		if passe.gamePassId == 0 then
			return false, "Este passe chega em breve!"
		end
		-- A janela oficial do Roblox cuida do pagamento; o passe só é dado no evento de compra
		MarketplaceService:PromptGamePassPurchase(player, passe.gamePassId)
		return true
	end)

	Dados.quandoCarregar(function(player: Player, estado)
		player:SetAttribute("NivelTenis", estado.melhorias.tenis or 0)
	end)
end

return Loja
