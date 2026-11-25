-- Pontos de Aura no servidor: a cada segundo, a aura equipada de quem está no jogo gera pontos
-- (regras em Shared/Dados/PontosAura). O cliente só pede a evolução; o servidor confere o saldo.
--
-- Para não mandar o perfil inteiro todo segundo, o saldo e o ganho vão em atributos do Player
-- (baratos) e o perfil é reenviado a cada ENVIO segundos. O cliente anima o contador entre os
-- envios usando o ganho por segundo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PontosAura = require(Shared.Dados.PontosAura)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)

local Servico = {}

local ENVIO = 10 -- segundos entre os envios do perfil só por causa dos pontos

-- Multiplicadores de fora (pets, passes, bônus do Corredor). Cada fonte registra a sua função.
local fontesGanho: { (Player) -> number } = {}
local fontesPontuacao: { (Player) -> number } = {}
local fontesSorte: { (Player) -> number } = {}

function Servico.registrarGanho(fn: (Player) -> number)
	table.insert(fontesGanho, fn)
end

function Servico.registrarPontuacao(fn: (Player) -> number)
	table.insert(fontesPontuacao, fn)
end

function Servico.registrarSorte(fn: (Player) -> number)
	table.insert(fontesSorte, fn)
end

local function produto(fontes: { (Player) -> number }, player: Player): number
	local m = 1
	for _, fn in fontes do
		local ok, v = pcall(fn, player)
		if ok and type(v) == "number" and v > 0 and v < math.huge then
			m *= v
		end
	end
	return m
end

function Servico.ganho(player: Player): number
	local estado = Dados.de(player)
	if not estado then
		return 0
	end
	return PontosAura.ganhoPorSegundo(estado.poder, estado.equipada, produto(fontesGanho, player))
end

function Servico.pontuacao(player: Player): number
	local estado = Dados.de(player)
	if not estado then
		return 0
	end
	return PontosAura.pontuacao(estado.poder, estado.equipada, produto(fontesPontuacao, player))
end

function Servico.sorte(player: Player): number
	local estado = Dados.de(player)
	return PontosAura.sorteTotal(estado, produto(fontesSorte, player))
end

-- Atributos lidos pelo HUD, pela Arena e pelos portões do Corredor
local function publicar(player: Player)
	local estado = Dados.de(player)
	if not estado then
		return
	end
	player:SetAttribute("PontosAura", math.floor(estado.poder.pontos))
	player:SetAttribute("GanhoAura", Servico.ganho(player))
	player:SetAttribute("Pontuacao", Servico.pontuacao(player))
	player:SetAttribute("SorteTotal", Servico.sorte(player))
end

local function evoluir(player: Player, id: any): (boolean, string?)
	if not Dados.podeProgredir(player) then
		return false, "Seu perfil ainda não está disponível."
	end
	local ok, msg = Dados.alterar(player, function(estado)
		return PontosAura.evoluir(estado.poder, id)
	end)
	if ok then
		publicar(player)
	end
	return ok, msg
end

function Servico.iniciar()
	Acoes.registrar("Evoluir", evoluir)
	Dados.quandoCarregar(function(player)
		publicar(player)
	end)
	-- Trocar de aura muda o ganho e a Pontuação na hora
	Dados.quandoMudar(function(player)
		publicar(player)
	end)

	task.spawn(function()
		local tique = 0
		while true do
			task.wait(1)
			tique += 1
			for _, player in Players:GetPlayers() do
				local estado = Dados.de(player)
				-- Sem progresso enquanto o perfil não pode ser salvo ou está numa transação
				if estado and Dados.podeProgredir(player) and not Dados.emTransacao(player) then
					local g = Servico.ganho(player)
					estado.poder.pontos += g
					estado.poder.total += g
					player:SetAttribute("PontosAura", math.floor(estado.poder.pontos))
					if tique % ENVIO == 0 then
						Dados.enviar(player)
					end
				end
			end
		end
	end)
end

return Servico
