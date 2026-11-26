-- Carrega, guarda e salva os dados de cada jogador (DataStore).
-- O servidor é a única fonte da verdade; o cliente só recebe cópias pelo remote "Estado"
-- (e pode pedir uma cópia a qualquer momento com a RemoteFunction "ObterEstado").
-- Uma trava de sessão (Servicos/Sessao.luau) impede dois servidores de salvarem o mesmo jogador.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Perfil = require(Shared.Dados.Perfil)
local Itens = require(Shared.Dados.Itens)
local Transcendencia = require(Shared.Dados.Transcendencia)
local PontosAura = require(Shared.Dados.PontosAura)
local Corredor = require(Shared.Dados.Corredor)
local Pets = require(Shared.Dados.Pets)
local Equipamento = require(Shared.Dados.Equipamento)
local Tutorial = require(Shared.Dados.Tutorial)
local ArenaPvP = require(Shared.Dados.ArenaPvP)
local EventoSol = require(Shared.Dados.EventoSol)
local Remotos = require(Shared.Remotos)
local Sessao = require(script.Parent.Sessao)

type Estado = Perfil.Estado

local Dados = {}

local NOME_STORE = "Despertar_v1"
local INTERVALO_AUTOSAVE = 60 -- também renova a trava (bem abaixo de Sessao.EXPIRA)
local TENTATIVAS = 3
-- Se outro servidor ainda está com a trava (o jogador acabou de trocar de servidor),
-- esperamos ele salvar e soltar: 8 tentativas x 5 s
local TENTATIVAS_TRAVA = 8
local ESPERA_TRAVA = 5
-- No Studio o JobId é vazio; um id aleatório evita que duas sessões de teste se confundam
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

-- No Studio com ModoTeste, nada é salvo: os dados vivem só na memória
local usarDataStore = not (RunService:IsStudio() and Config.ModoTeste)
local store = if usarDataStore then DataStoreService:GetDataStore(NOME_STORE) else nil

local estados: { [Player]: Estado } = {}
-- Perfis temporários do painel. A rotina de gravação lê sempre a tabela estados.
local perfisTeste: { [Player]: Estado? } = {}
-- Jogadores cujo carregamento falhou: nunca salvamos por cima do que está no DataStore
local semSalvar: { [Player]: boolean } = {}
local gravando: { [Player]: boolean } = {}
local transacao: { [Player]: boolean } = {}
local saindo: { [Player]: string } = {}
local envioPendente: { [Player]: boolean } = {}
-- Número da versão enviada ao cliente: ele ignora cópias mais velhas que a que já tem
local revisao: { [Player]: number } = {}
-- Lista simples de funções (BindableEvent copiaria a tabela do estado e as mudanças se perderiam)
local aoCarregar: { (Player, Estado) -> () } = {}
local aoSair: { (Player) -> () } = {}

-- Registra uma função chamada quando os dados de um jogador terminam de carregar
function Dados.quandoCarregar(fn: (Player, Estado) -> ())
	table.insert(aoCarregar, fn)
end

-- Fecha atividades que ainda precisam registrar progresso antes do salvamento final.
function Dados.quandoSair(fn: (Player) -> ())
	table.insert(aoSair, fn)
end

-- Funções chamadas depois de cada envio do estado (ex.: atualizar a vitrine no mundo)
local aoMudar: { (Player, Estado) -> () } = {}
function Dados.quandoMudar(fn: (Player, Estado) -> ())
	table.insert(aoMudar, fn)
end

-- ObterEstado é só leitura, mas limitamos a frequência para não virar spam
local INTERVALO_OBTER = 0.25
local ultimoObter: { [Player]: number } = {}

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
	return Perfil.padrao()
end

-- Pega a trava e lê o registro. Devolve:
--   "ok", registro  |  "ocupado" (outro servidor não soltou)  |  "erro" (DataStore fora do ar)
local function travarELer(player: Player): (string, Sessao.Registro?)
	for tentativa = 1, TENTATIVAS_TRAVA do
		local registro: Sessao.Registro? = nil
		local motivo: string? = nil
		local ok = comTentativas(function()
			return (store :: DataStore):UpdateAsync(chave(player), function(atual)
				registro, motivo = Sessao.travar(atual, JOB_ID, os.time())
				return registro -- nil cancela a gravação
			end)
		end)
		if not ok then
			return "erro", nil
		end
		if registro then
			return "ok", registro
		end
		if not player.Parent or tentativa == TENTATIVAS_TRAVA then
			break
		end
		warn(
			string.format(
				"[Dados] %s ainda está em outro servidor (%s); esperando",
				player.Name,
				tostring(motivo)
			)
		)
		task.wait(ESPERA_TRAVA)
	end
	return "ocupado", nil
end

-- Grava no DataStore só se a trava ainda for deste servidor. liberar = true solta a trava.
local function gravar(player: Player, dados: any, liberar: boolean): boolean
	local motivo: string? = nil
	local ok = comTentativas(function()
		return (store :: DataStore):UpdateAsync(chave(player), function(atual)
			local novo
			novo, motivo = Sessao.salvar(atual, JOB_ID, os.time(), dados, liberar)
			return novo
		end)
	end)
	if ok and motivo == "sem_trava" then
		-- Outro servidor assumiu este jogador: paramos de salvar aqui para não sobrescrever
		semSalvar[player] = true
		if not liberar then
			warn(
				"[Dados] trava de " .. player.Name .. " é de outro servidor; salvamento cancelado"
			)
		end
		return false
	end
	return ok
end

function Dados.carregar(player: Player)
	local estado: Estado
	if store then
		local resultado, registro = travarELer(player)
		if resultado == "ocupado" then
			if player.Parent then
				player:Kick(
					"Seu progresso ainda está sendo salvo em outro servidor. Entre de novo em alguns segundos!"
				)
			end
			return
		elseif resultado == "erro" or not registro then
			-- Joga com dados vazios, mas sem salvar, para não apagar o progresso real
			semSalvar[player] = true
			estado = Perfil.padrao()
			warn("[Dados] não consegui carregar " .. player.Name .. "; jogando sem salvar")
		else
			local dados = registro.dados
			estado = if type(dados) == "table" then dados else Perfil.padrao()
			completar(estado :: any, Perfil.padrao() :: any)
		end
		if not player.Parent then
			-- Saiu enquanto carregava: solta a trava sem mudar nada
			if not semSalvar[player] and registro then
				gravar(player, registro.dados, true)
			end
			semSalvar[player] = nil
			return
		end
	else
		estado = if Config.ModoTeste then estadoDeTeste() else Perfil.padrao()
		if not player.Parent then
			return
		end
	end
	Perfil.migrarAuras(estado)
	estado.inventario = Itens.normalizarInventario(estado.inventario)
	estado.transcendencia = Transcendencia.normalizar(estado.transcendencia)
	estado.poder = PontosAura.normalizar(estado.poder)
	estado.corredor = Corredor.normalizar(estado.corredor)
	estado.pets = Pets.normalizar(estado.pets)
	estado.equipamento = Equipamento.normalizar(estado.equipamento)
	estado.tutorial = Tutorial.normalizar(estado.tutorial, estado.giros)
	estado.arena = ArenaPvP.normalizar(estado.arena)
	estado.evento = EventoSol.normalizar(estado.evento)
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

-- Salva o jogador. liberar = true (saída do jogo) também solta a trava da sessão.
function Dados.salvar(player: Player, liberar: boolean?)
	local estado = estados[player]
	if not estado or not store or gravando[player] or (saindo[player] and not liberar) then
		return
	end
	if semSalvar[player] then
		if liberar then
			-- Em caso de resposta ambígua, preserva a versão que efetivamente chegou ao store.
			comTentativas(function()
				return (store :: DataStore):UpdateAsync(chave(player), function(atual)
					local registro = Sessao.normalizar(atual)
					return Sessao.salvar(atual, JOB_ID, os.time(), registro.dados, true)
				end)
			end)
		end
		return
	end
	gravando[player] = true
	estado.ultimaVez = os.time()
	gravar(player, Perfil.copiar(estado), liberar == true)
	gravando[player] = nil
end

-- Cópia atual para o cliente que pediu (handshake de entrada). nil enquanto carrega.
function Dados.instantaneo(player: Player): (Estado?, number)
	return Dados.de(player), revisao[player] or 0
end

function Dados.de(player: Player): Estado?
	return perfisTeste[player] or estados[player]
end

function Dados.real(player: Player): Estado?
	return estados[player]
end

-- Um perfil de contingência nunca deve confirmar progresso que não pode ser salvo.
function Dados.emTransacao(player: Player): boolean
	return transacao[player] == true
end

function Dados.podeProgredir(player: Player): boolean
	return Dados.de(player) ~= nil and (Dados.emTeste(player) or not semSalvar[player])
end

function Dados.emTeste(player: Player): boolean
	return perfisTeste[player] ~= nil
end

function Dados.definirPerfilTeste(player: Player, estado: Estado?)
	perfisTeste[player] = estado
	player:SetAttribute("PerfilDeTeste", estado ~= nil)
	Dados.enviar(player)
end

-- Envia o estado ao cliente no fim do quadro (várias mudanças seguidas viram 1 envio)
function Dados.enviar(player: Player)
	if envioPendente[player] then
		return
	end
	envioPendente[player] = true
	task.defer(function()
		envioPendente[player] = nil
		local estado = Dados.de(player)
		if estado and player.Parent then
			local rev = (revisao[player] or 0) + 1
			revisao[player] = rev
			Remotos.evento("Estado"):FireClient(player, estado, rev)
			for _, fn in aoMudar do
				task.spawn(fn, player, estado)
			end
		end
	end)
end

-- Altera o estado e já agenda o envio. fn recebe o estado e devolve (ok, mensagem?)
function Dados.alterar(player: Player, fn: (Estado) -> (boolean, string?)): (boolean, string?)
	local estado = Dados.de(player)
	if not estado then
		return false, "Carregando seus dados..."
	end
	if transacao[player] then
		return false, "Aguarde a confirmação da operação no Altar."
	end
	local ok, msg = fn(estado)
	if ok then
		Dados.enviar(player)
	end
	return ok, msg
end

-- Executa a mudança em uma cópia e só a torna visível após confirmação do DataStore.
-- Retries gravam o mesmo snapshot; o callback de economia nunca é reexecutado pelo store.
function Dados.alterarConfirmado(
	player: Player,
	fn: (Estado) -> (boolean, string?)
): (boolean, string?)
	if gravando[player] or saindo[player] then
		return false, "Aguarde a gravação atual terminar."
	end
	if not Dados.podeProgredir(player) then
		return false, "Seu perfil está indisponível. Reconecte para tentar de novo."
	end
	if not store or Dados.emTeste(player) then
		return Dados.alterar(player, fn)
	end
	local copia = Perfil.copiar(estados[player])
	local ok, msg = fn(copia)
	if not ok then
		return false, msg
	end
	gravando[player] = true
	transacao[player] = true
	copia.ultimaVez = os.time()
	local salvo = gravar(player, copia, false)
	if salvo then
		estados[player] = copia
		Dados.enviar(player)
	else
		-- A gravação pode ter chegado ao store sem resposta. Não sobrescreve com a cópia antiga.
		semSalvar[player] = true
	end
	transacao[player] = nil
	gravando[player] = nil
	if not salvo then
		return false, "Não deu para confirmar o salvamento. Reconecte antes de tentar de novo."
	end
	return true, msg
end

local function salvarSaida(player: Player)
	if saindo[player] then
		while saindo[player] == "salvando" do
			task.wait()
		end
		return
	end
	saindo[player] = "salvando"
	while gravando[player] do
		task.wait()
	end
	for _, fn in aoSair do
		local ok, erro = pcall(fn, player)
		if not ok then
			warn("[Dados] erro ao finalizar a sessão: " .. tostring(erro))
		end
	end
	Dados.salvar(player, true)
	saindo[player] = "concluido"
end

function Dados.iniciar()
	-- O cliente pede o estado ao abrir; se ainda está carregando, recebe nil e tenta de novo
	Remotos.funcao("ObterEstado").OnServerInvoke = function(player: Player)
		local agora = os.clock()
		local ultimo = ultimoObter[player]
		if ultimo and agora - ultimo < INTERVALO_OBTER then
			return nil, -1 -- rápido demais: o cliente tenta de novo depois
		end
		ultimoObter[player] = agora
		return Dados.instantaneo(player)
	end
	Players.PlayerAdded:Connect(function(player)
		Dados.carregar(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(Dados.carregar, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		salvarSaida(player)
		estados[player] = nil
		perfisTeste[player] = nil
		semSalvar[player] = nil
		envioPendente[player] = nil
		revisao[player] = nil
		saindo[player] = nil
		ultimoObter[player] = nil
	end)
	game:BindToClose(function()
		local pendentes = 0
		for player in estados do
			pendentes += 1
			task.spawn(function()
				salvarSaida(player)
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
