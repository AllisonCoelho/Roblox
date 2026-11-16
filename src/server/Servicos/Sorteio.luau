-- Sorteio de auras, equipar e configurações. O servidor é a única autoridade:
-- o cliente só pede; cooldown, RNG, posse e anúncios são decididos aqui.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Config = require(Shared.Config)
local Perfil = require(Shared.Dados.Perfil)
local Remotos = require(Shared.Remotos)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)

local Sorteio = {}

-- Folga para atraso de rede: o cliente espera o cooldown inteiro, o servidor aceita um pouco antes
local TOLERANCIA = 0.1
local rng = Random.new()
local ultimoGiro: { [Player]: number } = {}

local function aleatorio(): number
	return rng:NextNumber()
end

local function despertar(player: Player): (boolean, string?, { [string]: any }?)
	local agora = os.clock()
	local ultimo = ultimoGiro[player]
	if ultimo and agora - ultimo < Config.CooldownGiro - TOLERANCIA then
		return false, "Aguarde um instante..."
	end
	if not Dados.de(player) then
		return false, "Carregando seus dados..."
	end
	ultimoGiro[player] = agora

	-- O resultado é decidido e registrado aqui, antes de qualquer apresentação no cliente
	local aura = Auras.sortear(aleatorio)
	local quantidade = 0
	local equipou = false
	Dados.alterar(player, function(estado)
		local eraVazia = Perfil.colecaoVazia(estado)
		Perfil.registrarGiro(estado, aura.id)
		quantidade = estado.auras[aura.id]
		-- Obter não força a troca (regras em Perfil.deveEquipar)
		local atual = if estado.equipada then Auras.porId[estado.equipada] else nil
		if
			Perfil.deveEquipar(estado, eraVazia, aura.chance, if atual then atual.chance else nil)
		then
			estado.equipada = aura.id
			equipou = true
		end
		return true
	end)

	-- Auras raras: os outros clientes mostram a versão abreviada e o anúncio do servidor
	if aura.chance >= Auras.ANUNCIO_MINIMO then
		Remotos.evento("Despertou"):FireAllClients({
			jogador = player.DisplayName,
			userId = player.UserId,
			aura = aura.id,
		})
	end
	return true, aura.id, { quantidade = quantidade, equipou = equipou }
end

-- Só no Studio: pede a encenação de uma categoria sem sortear nem dar posse de nada.
-- Em servidores publicados esta ação nem é registrada.
local function testeVisual(_player: Player, indice: any): (boolean, string?, { [string]: any }?)
	if type(indice) ~= "number" or indice ~= math.floor(indice) then
		return false, "Pedido inválido"
	end
	local categoria = Apresentacao.Categorias[indice]
	if not categoria then
		return false, "Pedido inválido"
	end
	-- A aura mais comum que cai nessa categoria serve de exemplo
	for _, aura in Auras.lista do
		if Apresentacao.indiceDe(aura.chance) == indice then
			return true, aura.id, { quantidade = 1, equipou = false, teste = true }
		end
	end
	return false, "Nenhuma aura nessa categoria"
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
	if RunService:IsStudio() then
		Acoes.registrar("TesteVisual", testeVisual)
	end
	Players.PlayerRemoving:Connect(function(player)
		ultimoGiro[player] = nil
	end)
end

return Sorteio
