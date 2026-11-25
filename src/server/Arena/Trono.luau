-- Trono do Servidor (sem rating). O trono começa com o Primeiro Soberano. Quem derrota o
-- Soberano prova o seu valor (conta no perfil, para sempre) e, se o trono estiver vazio, vira o
-- Rei do Servidor. A partir daí, quem já provou o valor pode desafiar o Rei no 1x1 pelo trono.
--
-- O Rei ganha +25% de Pontos de Aura e +10% de sorte enquanto reinar, uma coroa e o título sobre a
-- cabeça. Os desafios entram numa fila; quando o ringue está livre, o Rei é chamado e tem alguns
-- segundos para Lutar ou Entregar o trono (sem resposta, o duelo começa). Depois de defender,
-- o Rei fica protegido por alguns segundos. Se o Rei sair do servidor, o trono volta ao Soberano.
--
-- Estado público (para todos os clientes): atributos do Workspace ReiDoServidor (UserId, 0 =
-- Soberano), ReiNome e ReiDesde; no Player, TronoFila (posição na fila).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaPvP = require(Shared.Dados.ArenaPvP)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent.Servicos
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local PontosAura = require(Servicos.PontosAura)
local Palco = require(script.Parent.Palco)
local PvP = require(script.Parent.PvP)

local Trono = {}

local rei: Player? = nil
local reiDesde = 0
local protegidoAte = 0
local fila: { Player } = {}
type Convite = { desafiante: Player, prazo: number }
local convite: Convite? = nil

local function aviso(player: Player, texto: string)
	if player.Parent == Players then
		Remotos.evento("Aviso"):FireClient(player, { tipo = "info", texto = texto })
	end
end

local function anunciar(texto: string)
	Remotos.evento("Aviso"):FireAllClients({ tipo = "info", texto = texto })
end

local function arena(player: Player): ArenaPvP.Perfil?
	local e = Dados.de(player) :: any
	return if e then e.arena else nil
end

function Trono.rei(): Player?
	return rei
end

-- O Trono tem um desafio prestes a começar (a Rankeada espera)
function Trono.temPrioridade(): boolean
	return convite ~= nil
end

local function publicarFila()
	for i, p in fila do
		p:SetAttribute("TronoFila", i)
	end
end

local function tirarDaFila(player: Player)
	local i = table.find(fila, player)
	if i then
		table.remove(fila, i)
		player:SetAttribute("TronoFila", nil)
		publicarFila()
	end
end

local function publicarRei()
	Workspace:SetAttribute("ReiDoServidor", if rei then rei.UserId else 0)
	Workspace:SetAttribute("ReiNome", if rei then rei.DisplayName else "Primeiro Soberano")
	Workspace:SetAttribute("ReiDesde", reiDesde)
end

-- Guarda o reinado mais longo do Rei que está saindo
local function fecharReinado()
	local antigo = rei
	if not antigo then
		return
	end
	local duracao = math.floor(Workspace:GetServerTimeNow() - reiDesde)
	if antigo.Parent == Players then
		Dados.alterar(antigo, function(estado)
			local a = (estado :: any).arena
			a.maiorReinado = math.max(a.maiorReinado, duracao)
			return true
		end)
	end
end

local function coroar(player: Player)
	fecharReinado()
	rei = player
	reiDesde = Workspace:GetServerTimeNow()
	protegidoAte = reiDesde + ArenaPvP.PROTECAO_REI
	tirarDaFila(player)
	Dados.alterar(player, function(estado)
		(estado :: any).arena.reinados += 1
		return true
	end)
	publicarRei()
	anunciar(string.format("👑 %s é o novo Rei do Servidor!", player.DisplayName))
end

local function devolverAoSoberano(motivo: string)
	fecharReinado()
	rei = nil
	reiDesde = 0
	convite = nil
	publicarRei()
	anunciar(motivo)
	-- sem Rei não há o que desafiar: a fila esvazia
	for _, p in fila do
		p:SetAttribute("TronoFila", nil)
	end
	table.clear(fila)
end

-- O jogador derrotou o Primeiro Soberano (chamado pelo duelo da Arena)
function Trono.vencerMonarca(player: Player)
	Dados.alterar(player, function(estado)
		(estado :: any).arena.monarca += 1
		return true
	end)
	if not rei then
		coroar(player)
	elseif rei ~= player then
		aviso(
			player,
			string.format(
				"Você provou o seu valor! Agora pode desafiar o Rei %s pelo trono no painel da Arena.",
				rei.DisplayName
			)
		)
	end
end

local function aoFim(desafiante: Player, reiNoDuelo: Player): PvP.Fim
	return function(vencedor, perdedor, motivo)
		local detalhes: { [Player]: string } = {}
		if vencedor == desafiante and rei == reiNoDuelo then
			coroar(desafiante)
			detalhes[desafiante] =
				"Você é o novo Rei do Servidor! +25% de Pontos de Aura e +10% de sorte enquanto reinar."
			if perdedor then
				detalhes[perdedor] = if motivo == "desistencia"
					then "Você deixou o duelo e perdeu o trono."
					else "Você perdeu o trono. Derrote o novo Rei para recuperá-lo!"
			end
		elseif vencedor == reiNoDuelo then
			protegidoAte = Workspace:GetServerTimeNow() + ArenaPvP.PROTECAO_REI
			anunciar(
				string.format(
					"👑 %s defendeu o trono contra %s!",
					vencedor.DisplayName,
					desafiante.DisplayName
				)
			)
			detalhes[vencedor] = "Você defendeu o trono!"
			detalhes[desafiante] =
				"O Rei defendeu o trono. Tente de novo quando estiver mais forte."
		end
		return detalhes
	end
end

local function comecar(c: Convite)
	local r = rei
	if not r or convite ~= c then
		return
	end
	local ok, motivo = PvP.iniciar(c.desafiante, r, {
		modo = "trono",
		titulo = "Duelo pelo Trono",
		aoFim = aoFim(c.desafiante, r),
	})
	if ok then
		convite = nil
		return
	end
	if motivo == "palco" then
		return -- tenta de novo no próximo passo
	end
	convite = nil
	local reiLivre = PvP.disponivel(r)
	if not reiLivre then
		-- o Rei não pode lutar agora (morto ou ocupado): o desafiante volta para a frente da fila
		table.insert(fila, 1, c.desafiante)
		publicarFila()
		aviso(c.desafiante, "O Rei não pode lutar agora. Você continua na frente da fila.")
	else
		aviso(c.desafiante, "Você não pôde entrar no duelo e saiu da fila do trono.")
	end
end

local function passo()
	local agora = Workspace:GetServerTimeNow()
	if rei and rei.Parent ~= Players then
		devolverAoSoberano("O Rei deixou o servidor. O trono voltou ao Primeiro Soberano.")
		return
	end
	local c = convite
	if c then
		if c.desafiante.Parent ~= Players then
			convite = nil
		elseif agora >= c.prazo then
			comecar(c)
		end
		return
	end
	local r = rei
	if not r or #fila == 0 or Palco.ocupado() or agora < protegidoAte then
		return
	end
	if not PvP.disponivel(r) then
		return
	end
	-- primeiro da fila que pode lutar agora
	for _, p in table.clone(fila) do
		if p.Parent ~= Players then
			tirarDaFila(p)
		elseif PvP.disponivel(p) then
			tirarDaFila(p)
			local novo: Convite = { desafiante = p, prazo = agora + ArenaPvP.AVISO_REI }
			convite = novo
			Remotos.evento("Trono"):FireClient(r, {
				tipo = "desafio",
				de = p.DisplayName,
				prazo = novo.prazo,
			})
			aviso(
				p,
				string.format("O Rei %s foi chamado! O duelo começa em instantes.", r.DisplayName)
			)
			return
		end
	end
end

local function desafiar(player: Player): (boolean, string?)
	local r = rei
	if not r then
		return false, "O trono está com o Primeiro Soberano: derrote-o para virar o Rei."
	end
	if r == player then
		return false, "Você já é o Rei do Servidor."
	end
	local a = arena(player)
	if not a or a.monarca <= 0 then
		return false, "Derrote o Primeiro Soberano antes de desafiar o Rei."
	end
	if table.find(fila, player) or (convite and convite.desafiante == player) then
		return false, "Você já está na fila do trono."
	end
	table.insert(fila, player)
	publicarFila()
	task.spawn(passo)
	return true, string.format("Você entrou na fila do trono (posição %d).", #fila)
end

local function responder(player: Player, resposta: any): (boolean, string?)
	local c = convite
	if player ~= rei or not c then
		return false, "Não há desafio para responder."
	end
	if resposta == "entregar" then
		convite = nil
		anunciar(
			string.format("%s entregou o trono a %s.", player.DisplayName, c.desafiante.DisplayName)
		)
		coroar(c.desafiante)
		return true, nil
	elseif resposta == "lutar" then
		c.prazo = Workspace:GetServerTimeNow()
		task.spawn(comecar, c)
		return true, nil
	end
	return false, "Resposta inválida."
end

function Trono.iniciar()
	publicarRei()
	Acoes.registrar("TronoDesafiar", desafiar)
	Acoes.registrar("TronoSairFila", function(player)
		if not table.find(fila, player) then
			return false, "Você não está na fila do trono."
		end
		tirarDaFila(player)
		return true, "Você saiu da fila do trono."
	end)
	Acoes.registrar("TronoResponder", responder)
	PontosAura.registrarGanho(function(player)
		return if player == rei then ArenaPvP.REI_GANHO else 1
	end)
	PontosAura.registrarSorte(function(player)
		return if player == rei then ArenaPvP.REI_SORTE else 1
	end)
	Players.PlayerRemoving:Connect(function(player)
		tirarDaFila(player)
		if player == rei then
			devolverAoSoberano("O Rei deixou o servidor. O trono voltou ao Primeiro Soberano.")
		end
	end)
	Palco.aoLiberar(passo)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, erro = pcall(passo)
			if not ok then
				warn("[Trono] " .. tostring(erro))
			end
		end
	end)
end

return Trono
