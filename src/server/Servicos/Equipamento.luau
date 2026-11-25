-- Equipamento no servidor (regras em Shared/Dados/Equipamento). O cliente só pede; o servidor
-- confere a posse, o saldo de Fragmentos e o nível máximo. Os bônus entram como
-- multiplicadores: ganho e sorte no PontosAura, dano e Fragmentos no combate do Corredor e a
-- vida no Humanoid. As peças visíveis vão no atributo "Equipamento" do Player para que todo
-- cliente desenhe a armadura de todo mundo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipamento = require(Shared.Dados.Equipamento)
local Remotos = require(Shared.Remotos)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)
local PontosAura = require(script.Parent.PontosAura)

local Servico = {}

local VIDA_BASE = 100
local rng = Random.new()

local function colecao(player: Player): Equipamento.Colecao?
	local estado = Dados.de(player)
	return if estado then (estado :: any).equipamento else nil
end

function Servico.multiplicadores(player: Player): { [string]: number }
	local c = colecao(player)
	if not c then
		return { ganho = 1, sorte = 1, dano = 1, vida = 1, fragmentos = 1 }
	end
	return Equipamento.multiplicadores(c)
end

local function aplicarVida(player: Player)
	local personagem = player.Character
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 then
		return
	end
	local maximo = math.floor(VIDA_BASE * Servico.multiplicadores(player).vida + 0.5)
	if humanoide.MaxHealth ~= maximo then
		local fracao = humanoide.Health / math.max(humanoide.MaxHealth, 1)
		humanoide.MaxHealth = maximo
		humanoide.Health = math.clamp(maximo * fracao, 1, maximo)
	end
end

-- Peças visíveis para os clientes: "espaco:item:nivel;..."
local function publicar(player: Player)
	local c = colecao(player)
	if not c then
		return
	end
	local partes = {}
	for _, espaco in Equipamento.ESPACOS do
		local uid = c.equipados[espaco]
		local g = uid and c.lista[uid]
		if g and not c.ocultos[espaco] then
			table.insert(partes, string.format("%s:%s:%d", espaco, g.item, g.nivel))
		end
	end
	local texto = table.concat(partes, ";")
	if player:GetAttribute("Equipamento") ~= texto then
		player:SetAttribute("Equipamento", texto)
	end
	aplicarVida(player)
end

-- Sorteia e entrega uma peça a quem ajudou a derrubar uma criatura do Corredor
function Servico.darDrop(player: Player, fase: number, tipo: string)
	local item = Equipamento.sortearDrop(fase, tipo, function()
		return rng:NextNumber()
	end)
	if not item then
		return
	end
	local entregue = false
	Dados.alterar(player, function(estado)
		entregue = Equipamento.adicionar((estado :: any).equipamento, item, os.time()) ~= nil
		return entregue
	end)
	local dados = Equipamento.porId[item]
	Remotos.evento("Aviso"):FireClient(player, {
		tipo = "info",
		texto = if entregue
			then string.format("Equipamento encontrado: %s!", dados.nome)
			else "Sua mochila de equipamento está cheia: desmonte peças para guardar novas.",
	})
end

local function equipar(player: Player, uid: any, ligar: any): (boolean, string?)
	if type(ligar) ~= "boolean" then
		return false, "Pedido inválido."
	end
	if player:GetAttribute("EmDueloArena") then
		return false, "Troque o equipamento depois do duelo."
	end
	return Dados.alterar(player, function(estado)
		return Equipamento.equipar((estado :: any).equipamento, uid, ligar)
	end)
end

local function ocultar(player: Player, espaco: any, oculto: any): (boolean, string?)
	if type(oculto) ~= "boolean" then
		return false, "Pedido inválido."
	end
	return Dados.alterar(player, function(estado)
		return Equipamento.ocultar((estado :: any).equipamento, espaco, oculto)
	end)
end

local function aprimorar(player: Player, uid: any): (boolean, string?)
	if type(uid) ~= "string" then
		return false, "Peça desconhecida."
	end
	if not Dados.podeProgredir(player) then
		return false, "Seu perfil ainda não está disponível."
	end
	local nivel = 0
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		local g = e.equipamento.lista[uid]
		if not g then
			return false, "Peça desconhecida."
		end
		local custo = Equipamento.custoAprimorar(g)
		if not custo then
			return false, "Esta peça já está no nível máximo."
		end
		if e.corredor.fragmentos < custo then
			return false, string.format("Faltam %d Fragmentos.", custo - e.corredor.fragmentos)
		end
		e.corredor.fragmentos -= custo
		g.nivel += 1
		nivel = g.nivel
		return true
	end)
	if ok then
		return true, string.format("Peça aprimorada para +%d!", nivel)
	end
	return false, msg
end

local function desmontar(player: Player, uid: any): (boolean, string?)
	if type(uid) ~= "string" then
		return false, "Peça desconhecida."
	end
	local valor = 0
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		local c = e.equipamento
		local g = c.lista[uid]
		if not g then
			return false, "Peça desconhecida."
		end
		if Equipamento.equipado(c, uid) then
			return false, "Desequipe a peça antes de desmontar."
		end
		valor = Equipamento.valorDesmontar(g)
		c.lista[uid] = nil
		e.corredor.fragmentos += valor
		return true
	end)
	if ok then
		return true, string.format("Peça desmontada. +%d Fragmentos", valor)
	end
	return false, msg
end

function Servico.iniciar()
	Acoes.registrar("EquiparItem", equipar)
	Acoes.registrar("OcultarEquipamento", ocultar)
	Acoes.registrar("AprimorarItem", aprimorar)
	Acoes.registrar("DesmontarItem", desmontar)
	PontosAura.registrarGanho(function(player)
		return Servico.multiplicadores(player).ganho
	end)
	PontosAura.registrarSorte(function(player)
		return Servico.multiplicadores(player).sorte
	end)
	Dados.quandoCarregar(function(player)
		publicar(player)
		player.CharacterAdded:Connect(function(personagem)
			personagem:WaitForChild("Humanoid", 10)
			task.defer(aplicarVida, player)
		end)
		if player.Character then
			aplicarVida(player)
		end
	end)
	Dados.quandoMudar(function(player)
		publicar(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("Equipamento", nil)
	end)
end

return Servico
