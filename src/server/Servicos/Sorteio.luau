-- Sorteio de auras, equipar e configurações. O servidor é a única autoridade:
-- o cliente só pede; cooldown, RNG, posse e anúncios são decididos aqui.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Config = require(Shared.Config)
local Monetizacao = require(Shared.Dados.Monetizacao)
local Perfil = require(Shared.Dados.Perfil)
local Remotos = require(Shared.Remotos)
local Transcendencia = require(Shared.Dados.Transcendencia)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)
local Passes = require(script.Parent.Passes)
local TemporadaServico = require(script.Parent.Temporada)

local Sorteio = {}

-- Folga para atraso de rede: o cliente espera o cooldown inteiro, o servidor aceita um pouco antes
local TOLERANCIA = 0.1
local rng = Random.new()
local ultimoGiro: { [Player]: number } = {}
-- Sem o passe "Pular Animação", o próximo giro só vale depois do ritual do anterior
local liberadoEm: { [Player]: number } = {}
local FOLGA_ANIMACAO = 0.25

local function aleatorio(): number
	return rng:NextNumber()
end

local function entregar(
	player: Player,
	aura: Auras.Aura,
	sorte: number?
): (boolean, string?, { [string]: any }?)
	local quantidade = 0
	local equipou = false
	local simulado = Dados.emTeste(player)
	local ok, mensagem = Dados.alterar(player, function(estado)
		local eraVazia = Perfil.colecaoVazia(estado)
		Perfil.registrarGiro(estado, aura.id)
		TemporadaServico.creditar(player, estado, "giro")
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

	local chance = Auras.chanceEfetiva(aura, sorte)
	-- Em teste, só o dono recebe o evento para ver a reação do Núcleo e a revelação local.
	if aura.chance >= Auras.ANUNCIO_MINIMO then
		local evento = Remotos.evento("Despertou")
		local dados = {
			jogador = player.DisplayName,
			userId = player.UserId,
			aura = aura.id,
			chance = chance,
		}
		if simulado then
			evento:FireClient(player, dados)
		else
			evento:FireAllClients(dados)
		end
	end
	return true,
		aura.id,
		{ quantidade = quantidade, equipou = equipou, simulado = simulado, chance = chance }
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
	local estado = Dados.de(player)
	if not estado or not Dados.podeProgredir(player) then
		return false, "Seu perfil ainda não está disponível."
	end
	if agora < (liberadoEm[player] or 0) then
		return false, nil -- a animação ainda está correndo (pular é um passe)
	end
	local sorte = Transcendencia.sorte(estado.transcendencia.nivel)
	ultimoGiro[player] = agora
	local aura = Auras.sortear(aleatorio, sorte)
	local ok, id, dados = entregar(player, aura, sorte)
	if ok and not Passes.tem(player, "pularAnimacao") then
		local cat = Apresentacao.de(aura.chance)
		liberadoEm[player] = agora + Apresentacao.tempoAteRevelacao(cat) - FOLGA_ANIMACAO
	end
	return ok, id, dados
end

function Sorteio.simular(player: Player, aura: Auras.Aura?): (boolean, string?, { [string]: any }?)
	if not Dados.emTeste(player) then
		return false, "Abra uma sessão de teste"
	end
	local estado = Dados.de(player)
	local sorte = Transcendencia.sorte(if estado then estado.transcendencia.nivel else 0)
	return entregar(player, aura or Auras.sortear(aleatorio, sorte), sorte)
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
	local passe = Monetizacao.passeNecessario(chave, valor, function(id)
		return Passes.tem(player, id)
	end)
	if passe then
		local produto = Monetizacao.porId[passe]
		return false, string.format("%s é um passe de %d Robux.", produto.nome, produto.preco)
	end
	return Dados.alterar(player, function(estado)
		estado.configuracoes[chave] = valor
		return true
	end)
end

-- Desliga configurações pagas de quem não tem (ou perdeu) o passe
local function corrigirConfiguracoes(player: Player)
	if not Passes.verificado(player) or not Dados.de(player) then
		return
	end
	local estado = Dados.de(player) :: Perfil.Estado
	local precisa = false
	for chave, regra in Monetizacao.CONFIGURACOES_PAGAS do
		if estado.configuracoes[chave] == regra.exige and not Passes.tem(player, regra.passe) then
			precisa = true
		end
	end
	if not precisa then
		return
	end
	Dados.alterar(player, function(e)
		for chave, regra in Monetizacao.CONFIGURACOES_PAGAS do
			if e.configuracoes[chave] == regra.exige and not Passes.tem(player, regra.passe) then
				e.configuracoes[chave] = not regra.exige
			end
		end
		return true
	end)
end

function Sorteio.iniciar()
	Passes.aoMudar(corrigirConfiguracoes)
	Dados.quandoCarregar(function(player)
		corrigirConfiguracoes(player)
	end)
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
		liberadoEm[player] = nil
	end)
end

return Sorteio
