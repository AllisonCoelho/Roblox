-- Resgate: levar um Docinho da vitrine de outro jogador (regras em Shared/Dados/Resgate.luau).
-- Quem resgata carrega o Docinho até a própria vitrine; se o dono encostar nele no caminho,
-- o Docinho volta. Se quem resgata cair ou sair do jogo, o Docinho também volta para o dono.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local ResgateDados = require(Shared.Dados.Resgate)
local Remotos = require(Shared.Remotos)
local Dados = require(script.Parent.Dados)
local Acoes = require(script.Parent.Acoes)
local Lotes = require(script.Parent.Lotes)
local Esteira = require(script.Parent.Esteira)

local Resgate = {}

local ultimoResgateFeito: { [Player]: number } = {}
local ultimoResgateSofrido: { [Player]: number } = {}

local function raizDe(player: Player): BasePart?
	local personagem = player.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not personagem or not humanoide or humanoide.Health <= 0 then
		return nil
	end
	return personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function resgatar(player: Player, indiceLote: any, slot: any): (boolean, string?)
	if type(indiceLote) ~= "number" or type(slot) ~= "number" or slot % 1 ~= 0 then
		return false, "Pedido inválido"
	end
	local pasta = workspace:FindFirstChild("Vitrines")
	local lote = pasta and pasta:FindFirstChild("Vitrine" .. indiceLote)
	if not lote or not lote:IsA("Model") then
		return false, "Pedido inválido"
	end
	local dono = Players:GetPlayerByUserId(lote:GetAttribute("Dono") :: number)
	local estadoLadrao = Dados.de(player)
	local estadoDono = dono and Dados.de(dono)
	local raiz = raizDe(player)
	if not dono or not estadoLadrao or not estadoDono or not raiz then
		return false, "Agora não dá para resgatar"
	end
	local item = estadoDono.vitrine[slot]
	local pedestal = lote:FindFirstChild("Pedestais")
	pedestal = pedestal and pedestal:FindFirstChild("Pedestal" .. slot)
	local agora = os.time()
	local ok, motivo = ResgateDados.pode({
		agora = agora,
		mesmoJogador = dono == player,
		escudoAte = estadoDono.escudoAte,
		docinhosNaVitrine = #estadoDono.vitrine,
		ultimoResgateSofrido = ultimoResgateSofrido[dono],
		ultimoResgateFeito = ultimoResgateFeito[player],
		carregando = estadoLadrao.carregando ~= nil,
		espacoNaVitrine = #estadoLadrao.vitrine < Economia.capacidadeVitrine(estadoLadrao),
		temVitrine = Lotes.de(player) ~= nil,
		distancia = if pedestal and pedestal:IsA("BasePart")
			then (raiz.Position - pedestal.Position).Magnitude
			else math.huge,
		slotValido = item ~= nil,
	})
	if not ok then
		return false, motivo
	end
	-- Tira da vitrine do dono (confere de novo o mesmo Docinho no mesmo lugar)
	local levado: Economia.DocinhoNaVitrine? = nil
	Dados.alterar(dono, function(estado)
		local atual = estado.vitrine[slot]
		if not atual or atual.id ~= item.id or atual.variante ~= item.variante then
			return false
		end
		levado = table.remove(estado.vitrine, slot)
		return true
	end)
	if not levado then
		return false, "Esse Docinho não está mais aqui"
	end
	local d = levado :: Economia.DocinhoNaVitrine
	Dados.alterar(player, function(estado)
		estado.carregando = { id = d.id, variante = d.variante, preco = 0, origem = dono.UserId }
		return true
	end)
	ultimoResgateFeito[player] = agora
	ultimoResgateSofrido[dono] = agora
	Esteira.atualizarCarga(player)
	Remotos.evento("Resgate"):FireClient(dono, { id = d.id })
	local nome = (Catalogo.docinho(d.id) or { nome = "Docinho" }).nome
	return true, "Corra! Leve o " .. nome .. " para a sua vitrine antes que o dono te alcance."
end

-- O dono encostou em quem está levando o Docinho dele: o Docinho volta
local function verificarRecuperacoes()
	for _, ladrao in Players:GetPlayers() do
		local estado = Dados.de(ladrao)
		local carga = estado and estado.carregando
		if not carga or not carga.origem then
			continue
		end
		local dono = Players:GetPlayerByUserId(carga.origem)
		local raizLadrao = raizDe(ladrao)
		local raizDono = dono and raizDe(dono)
		if
			raizLadrao
			and raizDono
			and (raizLadrao.Position - raizDono.Position).Magnitude
				<= ResgateDados.DistanciaRecuperar
		then
			Esteira.devolver(ladrao, "O dono te alcançou!")
		end
	end
end

function Resgate.iniciar()
	Acoes.registrar("Resgatar", resgatar)

	-- Quem sai do jogo carregando um Docinho resgatado: ele volta para o dono antes de salvar
	Dados.antesDeSair(function(player, estado)
		if estado.carregando and estado.carregando.origem then
			Esteira.devolver(player, "")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		ultimoResgateFeito[player] = nil
		ultimoResgateSofrido[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, erro = pcall(verificarRecuperacoes)
			if not ok then
				warn("[Resgate] " .. tostring(erro))
			end
		end
	end)
end

return Resgate
