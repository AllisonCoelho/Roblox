-- Ranking do servidor (leaderstats): Pontuação de Aura, Giros e Melhor aura.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Perfil = require(Shared.Dados.Perfil)
local Dados = require(script.Parent.Dados)

local Ranking = {}

local function atualizar(player: Player, estado: Perfil.Estado)
	local pasta = player:FindFirstChild("leaderstats")
	if not pasta then
		return
	end
	local giros = pasta:FindFirstChild("Giros") :: IntValue?
	local melhor = pasta:FindFirstChild("Melhor") :: StringValue?
	if giros then
		giros.Value = estado.giros
	end
	if melhor then
		local aura = Auras.melhorDe(estado.auras)
		melhor.Value = if aura then "1/" .. Formato.chanceCurta(aura.chance) else "-"
	end
end

local function criar(player: Player, estado: Perfil.Estado)
	local pasta = Instance.new("Folder")
	pasta.Name = "leaderstats"
	-- Primeira coluna = ordem da lista de jogadores do Roblox
	local pontuacao = Instance.new("IntValue")
	pontuacao.Name = "Pontuação"
	pontuacao.Value = math.floor(tonumber(player:GetAttribute("Pontuacao")) or 0)
	pontuacao.Parent = pasta
	player:GetAttributeChangedSignal("Pontuacao"):Connect(function()
		pontuacao.Value = math.floor(tonumber(player:GetAttribute("Pontuacao")) or 0)
	end)
	local giros = Instance.new("IntValue")
	giros.Name = "Giros"
	giros.Parent = pasta
	local melhor = Instance.new("StringValue")
	melhor.Name = "Melhor"
	melhor.Parent = pasta
	pasta.Parent = player
	atualizar(player, estado)
end

function Ranking.iniciar()
	Dados.quandoCarregar(criar)
	Dados.quandoMudar(function(player)
		local real = Dados.real(player)
		if real then
			atualizar(player, real)
		end
	end)
end

return Ranking
