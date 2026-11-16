-- Sorteio de auras, equipar e configurações. O servidor é a única autoridade:
-- o cliente só pede; cooldown, RNG, posse e anúncios são decididos aqui.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Config = require(Shared.Config)
local Perfil = require(Shared.Dados.Perfil)
local Remotos = require(Shared.Remotos)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)

local Sorteio = {}

-- Folga para atraso de rede: o cliente espera o cooldown inteiro, o servidor aceita um pouco antes
local TOLERANCIA = 0.1
-- A partir desta faixa (Raro) o personagem faz a animação de despertar
local TIER_ANIMACAO = 3

local rng = Random.new()
local ultimoGiro: { [Player]: number } = {}

local function aleatorio(): number
	return rng:NextNumber()
end

local function despertar(player: Player): (boolean, string?)
	local agora = os.clock()
	local ultimo = ultimoGiro[player]
	if ultimo and agora - ultimo < Config.CooldownGiro - TOLERANCIA then
		return false, "Aguarde um instante..."
	end
	if not Dados.de(player) then
		return false, "Carregando seus dados..."
	end
	ultimoGiro[player] = agora

	local aura = Auras.sortear(aleatorio)
	Dados.alterar(player, function(estado)
		Perfil.registrarGiro(estado, aura.id)
		-- Equipa sozinho quando a nova aura é mais rara que a atual
		local atual = if estado.equipada then Auras.porId[estado.equipada] else nil
		if not atual or aura.chance > atual.chance then
			estado.equipada = aura.id
		end
		return true
	end)

	-- Raro ou melhor: todos os clientes animam o personagem; a partir de Épico também anunciam
	if aura.tier >= TIER_ANIMACAO then
		Remotos.evento("Despertou"):FireAllClients({
			jogador = player.DisplayName,
			userId = player.UserId,
			aura = aura.id,
		})
	end
	return true, aura.id
end

-- auraId nil ou "" desequipa
local function equipar(player: Player, auraId: any): (boolean, string?)
	if auraId ~= nil and type(auraId) ~= "string" then
		return false, "Pedido inválido"
	end
	if auraId == "" then
		auraId = nil
	end
	if auraId ~= nil and not Auras.porId[auraId] then
		return false, "Aura desconhecida"
	end
	return Dados.alterar(player, function(estado)
		if auraId ~= nil and not Perfil.possui(estado, auraId) then
			return false, "Você ainda não despertou essa aura"
		end
		estado.equipada = auraId
		return true
	end)
end

local function configurar(player: Player, chave: any, valor: any): (boolean, string?)
	if type(chave) ~= "string" or not Perfil.CONFIGURACOES[chave] or type(valor) ~= "boolean" then
		return false, "Pedido inválido"
	end
	return Dados.alterar(player, function(estado)
		estado.configuracoes[chave] = valor
		return true
	end)
end

function Sorteio.iniciar()
	Acoes.registrar("Despertar", despertar)
	Acoes.registrar("Equipar", equipar)
	Acoes.registrar("Configurar", configurar)
	Players.PlayerRemoving:Connect(function(player)
		ultimoGiro[player] = nil
	end)
end

return Sorteio
