-- Carrega, guarda e salva os dados de cada jogador (DataStore).
-- O servidor é a única fonte da verdade; o cliente só recebe cópias pelo remote "Estado".
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Economia = require(Shared.Dados.Economia)
local Remotos = require(Shared.Remotos)

type Estado = Economia.Estado

local Dados = {}

local NOME_STORE = "Docinhos_v1"
local INTERVALO_AUTOSAVE = 120
local TENTATIVAS = 3

-- No Studio com ModoTeste, nada é salvo: os dados vivem só na memória
local usarDataStore = not (RunService:IsStudio() and Config.ModoTeste)
local store = if usarDataStore then DataStoreService:GetDataStore(NOME_STORE) else nil

local estados: { [Player]: Estado } = {}
-- Jogadores cujo carregamento falhou: nunca salvamos por cima do que está no DataStore
local semSalvar: { [Player]: boolean } = {}
local envioPendente: { [Player]: boolean } = {}
-- Lista simples de funções (BindableEvent copiaria a tabela do estado e as mudanças se perderiam)
local aoCarregar: { (Player, Estado) -> () } = {}

-- Registra uma função chamada quando os dados de um jogador terminam de carregar
function Dados.quandoCarregar(fn: (Player, Estado) -> ())
	table.insert(aoCarregar, fn)
end

local function chave(player: Player): string
	return "jogador_" .. player.UserId
end

-- Preenche campos que faltam (dados antigos) sem apagar o que já existe
local function completar(destino: { [any]: any }, modelo: { [any]: any })
	for k, v in modelo do
		if destino[k] == nil then
			destino[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(destino[k]) == "table" and next(v) ~= nil then
			completar(destino[k], v)
		end
	end
end

local function comTentativas<T>(fn: () -> T): (boolean, T | string)
	local ok, resultado
	for tentativa = 1, TENTATIVAS do
		ok, resultado = pcall(fn)
		if ok then
			return true, resultado
		end
		warn(string.format("[Dados] tentativa %d falhou: %s", tentativa, tostring(resultado)))
		task.wait(2 ^ tentativa)
	end
	return false, resultado
end

local function estadoDeTeste(): Estado
	local e = Economia.padrao()
	e.moedas = 12450
	e.granulados = 320
	e.caixa = 1200
	e.melhorias.vitrine = 2
	e.melhorias.escudo = 1
	e.melhorias.tenis = 2
	local agora = os.time()
	for _, item in
		{
			{ "brigadeiro", "normal" },
			{ "quindim", "normal" },
			{ "pacoca", "normal" },
			{ "balaDeCoco", "normal" },
			{ "beijinho", "dourado" },
		}
	do
		table.insert(e.vitrine, { id = item[1], variante = item[2] })
	end
	for id, qtd in
		{
			balaDeCoco = 12,
			beijinho = 8,
			pacoca = 3,
			peDeMoleque = 1,
			cocada = 2,
			quindim = 1,
			brigadeiro = 2,
		}
	do
		e.album[id] =
			{ qtd = qtd, desde = agora - 86400, dourado = id == "beijinho", arcoiris = false }
	end
	return e
end

function Dados.carregar(player: Player)
	local estado: Estado
	if store then
		local ok, resultado = comTentativas(function()
			return (store :: DataStore):GetAsync(chave(player))
		end)
		if not ok then
			-- Joga com dados vazios, mas sem salvar, para não apagar o progresso real
			semSalvar[player] = true
			estado = Economia.padrao()
			warn("[Dados] não consegui carregar " .. player.Name .. "; jogando sem salvar")
		else
			estado = if type(resultado) == "table" then resultado else Economia.padrao()
			completar(estado :: any, Economia.padrao() :: any)
		end
	else
		estado = if Config.ModoTeste then estadoDeTeste() else Economia.padrao()
	end
	if not player.Parent then
		return -- saiu enquanto carregava
	end
	estados[player] = estado
	for _, fn in aoCarregar do
		local ok, erro = pcall(fn, player, estado)
		if not ok then
			warn("[Dados] erro ao preparar " .. player.Name .. ": " .. tostring(erro))
		end
	end
	Dados.enviar(player)
	if semSalvar[player] then
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "erro",
			texto = "Não foi possível carregar seu progresso. Volte mais tarde para não perder nada.",
		})
	end
end

function Dados.salvar(player: Player)
	local estado = estados[player]
	if not estado or not store or semSalvar[player] then
		return
	end
	estado.ultimaVez = os.time()
	local copia = table.clone(estado)
	comTentativas(function()
		return (store :: DataStore):UpdateAsync(chave(player), function()
			return copia
		end)
	end)
end

function Dados.de(player: Player): Estado?
	return estados[player]
end

-- Envia o estado ao cliente no fim do quadro (várias mudanças seguidas viram 1 envio)
function Dados.enviar(player: Player)
	if envioPendente[player] then
		return
	end
	envioPendente[player] = true
	task.defer(function()
		envioPendente[player] = nil
		local estado = estados[player]
		if estado and player.Parent then
			Remotos.evento("Estado"):FireClient(player, estado)
		end
	end)
end

-- Altera o estado e já agenda o envio. fn recebe o estado e devolve (ok, mensagem?)
function Dados.alterar(player: Player, fn: (Estado) -> (boolean, string?)): (boolean, string?)
	local estado = estados[player]
	if not estado then
		return false, "Carregando seus dados..."
	end
	local ok, msg = fn(estado)
	if ok then
		Dados.enviar(player)
	end
	return ok, msg
end

function Dados.iniciar()
	Players.PlayerAdded:Connect(function(player)
		Dados.carregar(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(Dados.carregar, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		Dados.salvar(player)
		estados[player] = nil
		semSalvar[player] = nil
		envioPendente[player] = nil
	end)
	game:BindToClose(function()
		local pendentes = 0
		for player in estados do
			pendentes += 1
			task.spawn(function()
				Dados.salvar(player)
				pendentes -= 1
			end)
		end
		local inicio = os.clock()
		while pendentes > 0 and os.clock() - inicio < 25 do
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(INTERVALO_AUTOSAVE)
			for player in estados do
				task.spawn(Dados.salvar, player)
			end
		end
	end)
end

return Dados
