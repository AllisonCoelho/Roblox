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

local function entregar(player: Player, aura: Auras.Aura): (boolean, string?, { [string]: any }?)
	local quantidade = 0
	local equipou = false
	local simulado = Dados.emTeste(player)
	local ok, mensagem = Dados.alterar(player, function(estado)
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
	if not ok then
		return false, mensagem
	end

	-- Em teste, só o dono recebe o evento para ver a reação do Núcleo e a revelação local.
	if aura.chance >= Auras.ANUNCIO_MINIMO then
		local evento = Remotos.evento("Despertou")
		local dados = {
			jogador = player.DisplayName,
			userId = player.UserId,
			aura = aura.id,
		}
		if simulado then
			evento:FireClient(player, dados)
		else
			evento:FireAllClients(dados)
		end
	end
	return true, aura.id, { quantidade = quantidade, equipou = equipou, simulado = simulado }
end

local function despertar(player: Player): (boolean, string?, { [string]: any }?)
	if player:GetAttribute("EmDueloArena") then
		return false, "O giro volta assim que o duelo terminar."
	end
	local agora = os.clock()
	local ultimo = ultimoGiro[player]
	if ultimo and agora - ultimo < Config.CooldownGiro - TOLERANCIA then
		return false, "Aguarde um instante..."
	end
	if not Dados.de(player) then
		return false, "Carregando seus dados..."
	end
	ultimoGiro[player] = agora
	return entregar(player, Auras.sortear(aleatorio))
end

function Sorteio.simular(player: Player, aura: Auras.Aura?): (boolean, string?, { [string]: any }?)
	if not Dados.emTeste(player) then
		return false, "Abra uma sessão de teste"
	end
	return entregar(player, aura or Auras.sortear(aleatorio))
end

-- Encena uma categoria sem alterar o perfil, pelo atalho do Studio ou pelo painel autorizado.
function Sorteio.testeVisual(indice: any): (boolean, string?, { [string]: any }?)
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
	if player:GetAttribute("EmDueloArena") then
		return false, "A aura fica equipada até o duelo terminar."
	end
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
		Acoes.registrar("TesteVisual", function(_, indice)
			return Sorteio.testeVisual(indice)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		ultimoGiro[player] = nil
	end)
end

return Sorteio
