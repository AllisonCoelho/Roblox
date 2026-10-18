-- Vitrine do jogador: renda por segundo, caixa, coleta, venda, escudo e novos Docinhos
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local Remotos = require(Shared.Remotos)
local Formato = require(Shared.Formato)
local EsteiraDados = require(Shared.Dados.Esteira)
local Dados = require(script.Parent.Dados)
local Acoes = require(script.Parent.Acoes)
local Missoes = require(script.Parent.Missoes)

local Vitrine = {}

local INTERVALO_TELEPORTE = 3 -- segundos entre dois "ir para a vitrine"

local ultimoTeleporte: { [Player]: number } = {}

-- Vitrine do jogador no mapa: filho de workspace.Vitrines com o atributo Dono = UserId.
-- O atributo é colocado pelo servidor quando a vitrine é dada ao jogador.
function Vitrine.daJogador(player: Player): PVInstance?
	local pasta = workspace:FindFirstChild("Vitrines")
	if not pasta then
		return nil
	end
	for _, v in pasta:GetChildren() do
		if v:IsA("PVInstance") and v:GetAttribute("Dono") == player.UserId then
			return v
		end
	end
	return nil
end

-- Coloca um Docinho na vitrine e no álbum. Usado pela esteira, presentes e eventos.
-- Devolve false se a vitrine estiver cheia.
-- devolucao = true quando o Docinho só está voltando (resgate recuperado): não conta no álbum.
function Vitrine.adicionarDocinho(
	player: Player,
	id: string,
	variante: string?,
	devolucao: boolean?
): boolean
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
		if devolucao then
			return true
		end
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

-- Passa as moedas do caixa para o jogador (botão COLETAR e o caixa da vitrine no mundo)
function Vitrine.coletar(player: Player): (boolean, string?)
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
		return true, "+" .. Formato.inteiro(coletado) .. " moedas!"
	end
	return ok, msg
end

-- Liga o escudo da vitrine (botão do HUD e o tapete do escudo no mundo)
function Vitrine.ligarEscudo(player: Player): (boolean, string?)
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
		return true, "Escudo ligado!"
	end
	return ok, msg
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

	Acoes.registrar("Coletar", Vitrine.coletar)

	-- O cliente manda a posição e qual Docinho ele viu ali: se a vitrine mudou nesse meio-tempo
	-- (um resgate tirou um Docinho e as posições andaram), a venda é recusada em vez de
	-- vender o Docinho errado.
	Acoes.registrar("VenderDocinho", function(player, indice: any, id: any, variante: any)
		if
			type(indice) ~= "number"
			or indice % 1 ~= 0
			or type(id) ~= "string"
			or type(variante) ~= "string"
		then
			return false, "Docinho inválido"
		end
		return Dados.alterar(player, function(estado)
			local item = estado.vitrine[indice]
			local def = item and Catalogo.docinho(item.id)
			if not item or not def then
				return false, "Docinho inválido"
			end
			if item.id ~= id or item.variante ~= variante then
				return false, "Sua vitrine mudou. Confira e tente de novo"
			end
			table.remove(estado.vitrine, indice)
			estado.moedas += EsteiraDados.valorVenda(item.id, item.variante)
			return true, string.format("%s vendido!", def.nome)
		end)
	end)

	Acoes.registrar("LigarEscudo", Vitrine.ligarEscudo)

	Acoes.registrar("IrParaVitrine", function(player)
		local agora = os.clock()
		local ultimo = ultimoTeleporte[player]
		if ultimo and agora - ultimo < INTERVALO_TELEPORTE then
			return false, "Espere um pouquinho para usar de novo"
		end
		local vitrine = Vitrine.daJogador(player)
		if not vitrine then
			return false, "Você ainda não tem uma vitrine neste servidor"
		end
		local personagem = player.Character
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if not personagem or not humanoide or humanoide.Health <= 0 then
			return false, "Espere renascer para voltar à vitrine"
		end
		-- Carregando um Docinho não vale teletransportar: tem que levar andando
		if player:GetAttribute("Carregando") then
			return false, "Leve o Docinho andando até a vitrine!"
		end
		ultimoTeleporte[player] = agora
		local entrada = vitrine:FindFirstChild("Entrada")
		local destino = if entrada and entrada:IsA("BasePart")
			then entrada.CFrame + Vector3.new(0, 3, 0)
			else vitrine:GetPivot() * CFrame.new(0, 5, 8)
		personagem:PivotTo(destino)
		return true
	end)
	Players.PlayerRemoving:Connect(function(player)
		ultimoTeleporte[player] = nil
	end)

	-- Preferências do jogador (só chaves conhecidas e valores verdadeiro/falso)
	Acoes.registrar("Configurar", function(player, chave: any, valor: any)
		if (chave ~= "sons" and chave ~= "musica") or type(valor) ~= "boolean" then
			return false, "Ajuste inválido"
		end
		return Dados.alterar(player, function(estado)
			estado.config[chave] = valor
			return true
		end)
	end)

	Acoes.registrar("ConcluirTutorial", function(player)
		return Dados.alterar(player, function(estado)
			estado.tutorialFeito = true
			return true
		end)
	end)
end

return Vitrine
