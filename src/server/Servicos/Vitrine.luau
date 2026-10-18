-- Vitrine do jogador: renda por segundo, caixa, coleta, venda, escudo e novos Docinhos
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local Remotos = require(Shared.Remotos)
local Dados = require(script.Parent.Dados)
local Acoes = require(script.Parent.Acoes)
local Missoes = require(script.Parent.Missoes)

local Vitrine = {}

local FRACAO_VENDA = 0.5

-- Coloca um Docinho na vitrine e no álbum. Usado pela esteira, presentes e eventos.
-- Devolve false se a vitrine estiver cheia.
function Vitrine.adicionarDocinho(player: Player, id: string, variante: string?): boolean
	local def = Catalogo.docinho(id)
	local v = variante or "normal"
	if not def or not Catalogo.Variantes[v] then
		return false
	end
	local novidade = false
	local ok = Dados.alterar(player, function(estado)
		if #estado.vitrine >= Economia.capacidadeVitrine(estado) then
			return false
		end
		table.insert(estado.vitrine, { id = id, variante = v })
		local entrada = estado.album[id]
		if not entrada then
			entrada = { qtd = 0, desde = os.time(), dourado = false, arcoiris = false }
			estado.album[id] = entrada
			novidade = true
		end
		entrada.qtd += 1
		if v == "dourado" and not entrada.dourado then
			entrada.dourado = true
			novidade = true
		elseif v == "arcoiris" and not entrada.arcoiris then
			entrada.arcoiris = true
			novidade = true
		end
		return true
	end)
	if ok and novidade then
		Remotos.evento("NovoDocinho"):FireClient(player, { id = id, variante = v })
	end
	return ok
end

local function creditarOffline(player: Player, estado: Economia.Estado)
	if estado.ultimaVez <= 0 then
		return
	end
	local agora = os.time()
	local segundos = math.clamp(agora - estado.ultimaVez, 0, Economia.limiteCaixaSegundos(estado))
	local ganho = math.floor(Economia.rendaPorSegundo(estado, agora) * segundos)
	if ganho > 0 then
		estado.caixa += ganho
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "info",
			texto = "Sua vitrine guardou moedas enquanto você estava fora!",
		})
	end
end

function Vitrine.iniciar()
	Dados.quandoCarregar(function(player: Player, estado: Economia.Estado)
		creditarOffline(player, estado)
		Dados.enviar(player)
	end)

	-- Renda: a cada segundo cada vitrine enche o caixa.
	-- O caixa vai num atributo do jogador (leve) em vez de reenviar o estado inteiro todo segundo.
	task.spawn(function()
		while true do
			task.wait(1)
			local agora = os.time()
			for _, player in Players:GetPlayers() do
				local estado = Dados.de(player)
				if estado then
					estado.caixa += Economia.rendaPorSegundo(estado, agora)
					player:SetAttribute("Caixa", math.floor(estado.caixa))
				end
			end
		end
	end)

	Acoes.registrar("Coletar", function(player)
		local coletado = 0
		local ok, msg = Dados.alterar(player, function(estado)
			coletado = math.floor(estado.caixa)
			if coletado <= 0 then
				return false, "O caixa está vazio"
			end
			estado.moedas += coletado
			estado.caixa -= coletado
			return true
		end)
		if ok then
			player:SetAttribute("Caixa", 0)
			Missoes.progredir(player, "coletar_moedas", coletado)
		end
		return ok, msg
	end)

	Acoes.registrar("VenderDocinho", function(player, indice: any)
		if type(indice) ~= "number" or indice % 1 ~= 0 then
			return false, "Docinho inválido"
		end
		return Dados.alterar(player, function(estado)
			local item = estado.vitrine[indice]
			local def = item and Catalogo.docinho(item.id)
			if not item or not def then
				return false, "Docinho inválido"
			end
			table.remove(estado.vitrine, indice)
			local valor = math.floor(def.preco * FRACAO_VENDA)
			estado.moedas += valor
			return true, string.format("%s vendido!", def.nome)
		end)
	end)

	Acoes.registrar("LigarEscudo", function(player)
		local ok, msg = Dados.alterar(player, function(estado)
			local agora = os.time()
			if agora < estado.escudoAte then
				return false, "O escudo já está ligado"
			end
			if agora < estado.escudoProntoEm then
				return false, "O escudo está recarregando"
			end
			estado.escudoAte = agora + Economia.duracaoEscudo(estado)
			estado.escudoProntoEm = estado.escudoAte + Economia.EscudoRecarga
			return true
		end)
		if ok then
			Missoes.progredir(player, "ligar_escudo", 1)
		end
		return ok, msg
	end)

	Acoes.registrar("ConcluirTutorial", function(player)
		return Dados.alterar(player, function(estado)
			estado.tutorialFeito = true
			return true
		end)
	end)
end

return Vitrine
