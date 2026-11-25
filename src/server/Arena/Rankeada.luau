-- Rankeada: duelos 1x1 que valem rating (Elo, regras em Shared/Dados/ArenaPvP) e o ranking
-- global de todos os servidores.
--
-- Fila: quem entra espera um oponente deste servidor com rating parecido (a janela aceita cresce
-- com a espera). Ao parear, os dois são avisados e o duelo começa em 5 s, quando o ringue estiver
-- livre (o Trono tem prioridade). No fim, o rating dos dois muda e é gravado no perfil e no
-- ranking global.
--
-- Ranking global: OrderedDataStore NOVO "Despertar_v1_RankingArena" (UserId -> rating). Nenhum
-- store anterior é lido ou alterado. A cada minuto o servidor lê o top 50 e publica para os
-- clientes em ReplicatedStorage.RankingGlobal (JSON). No Studio com ModoTeste nada é gravado: o
-- ranking mostra só quem está no servidor.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaPvP = require(Shared.Dados.ArenaPvP)
local Config = require(Shared.Config)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent.Servicos
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local Palco = require(script.Parent.Palco)
local PvP = require(script.Parent.PvP)
local Trono = require(script.Parent.Trono)

local Rankeada = {}

local NOME_STORE = "Despertar_v1_RankingArena"
local TOP = 50
local INTERVALO_LEITURA = 60
local CONTAGEM = 5

local usarStore = not (RunService:IsStudio() and Config.ModoTeste)
local store: OrderedDataStore? = nil
if usarStore then
	local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, NOME_STORE)
	store = if ok then s else nil
end

local fila: { [Player]: number } = {} -- jogador -> os.clock() de quando entrou
local pareando = false
type Linha = { id: number, nome: string, rating: number }
local top: { Linha } = {}
local nomes: { [number]: string } = {}
local valor: StringValue

local function aviso(player: Player, texto: string)
	if player.Parent == Players then
		Remotos.evento("Aviso"):FireClient(player, { tipo = "info", texto = texto })
	end
end

local function rating(player: Player): number
	local e = Dados.de(player) :: any
	return if e and e.arena then e.arena.rating else ArenaPvP.RATING_INICIAL
end

local function nomeDe(id: number): string
	if nomes[id] then
		return nomes[id]
	end
	local p = Players:GetPlayerByUserId(id)
	if p then
		nomes[id] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, id)
	nomes[id] = if ok and type(n) == "string" then n else "Jogador"
	return nomes[id]
end

-- Publica o top: o global lido (ou vazio) misturado com quem está neste servidor, que pode ter
-- mudado de rating há pouco
local function publicar()
	local porId: { [number]: Linha } = {}
	for _, l in top do
		porId[l.id] = table.clone(l)
	end
	for _, p in Players:GetPlayers() do
		local e = Dados.de(p) :: any
		if e and e.arena and (e.arena.vitorias + e.arena.derrotas) > 0 then
			porId[p.UserId] = { id = p.UserId, nome = p.DisplayName, rating = e.arena.rating }
		end
	end
	local lista = {}
	for _, l in porId do
		table.insert(lista, l)
	end
	table.sort(lista, function(a, b)
		if a.rating ~= b.rating then
			return a.rating > b.rating
		end
		return a.id < b.id
	end)
	while #lista > TOP do
		table.remove(lista)
	end
	valor.Value = HttpService:JSONEncode({ global = store ~= nil, lista = lista })
end

local function ler()
	local s = store
	if not s then
		top = {}
		publicar()
		return
	end
	local ok, pagina = pcall(function()
		return s:GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if not ok then
		warn("[Rankeada] ranking global indisponível: " .. tostring(pagina))
		publicar()
		return
	end
	local novo = {}
	for _, item in pagina :: { any } do
		local id = tonumber(item.key)
		if id then
			table.insert(novo, { id = id, nome = nomeDe(id), rating = math.floor(item.value) })
		end
	end
	top = novo
	publicar()
end

local function gravar(player: Player, novo: number)
	local s = store
	if not s then
		return
	end
	local id = tostring(player.UserId)
	task.spawn(function()
		local ok, erro = pcall(s.SetAsync, s, id, math.floor(novo))
		if not ok then
			warn("[Rankeada] não gravei o rating: " .. tostring(erro))
		end
	end)
end

local function aoFim(vencedor: Player?, perdedor: Player?, motivo: string): { [Player]: string }?
	if not vencedor or not perdedor then
		return nil
	end
	local rv, rp = rating(vencedor), rating(perdedor)
	local nv, np = ArenaPvP.elo(rv, rp)
	local detalhes: { [Player]: string } = {}
	for _, par in { { vencedor, nv, true }, { perdedor, np, false } } do
		local p, novo, venceu = par[1] :: Player, par[2] :: number, par[3] :: boolean
		if p.Parent == Players then
			Dados.alterar(p, function(estado)
				local a = (estado :: any).arena
				a.rating = novo
				if venceu then
					a.vitorias += 1
				else
					a.derrotas += 1
				end
				return true
			end)
			p:SetAttribute("RatingArena", novo)
			gravar(p, novo)
		end
		local antes = if venceu then rv else rp
		local div = ArenaPvP.divisao(novo)
		detalhes[p] = string.format(
			"%s%d de rating · %d (%s)%s",
			if novo >= antes then "+" else "−",
			math.abs(novo - antes),
			novo,
			div.nome,
			if not venceu and motivo == "desistencia" then " · conta como derrota" else ""
		)
	end
	publicar()
	return detalhes
end

local function iniciarPar(a: Player, b: Player)
	local ok, motivo = PvP.iniciar(a, b, {
		modo = "rankeada",
		titulo = "Rankeada",
		aoFim = aoFim,
	})
	if ok then
		return
	end
	-- não deu: quem ainda pode volta para a fila (na frente)
	for _, p in { a, b } do
		if p.Parent == Players and PvP.disponivel(p) then
			fila[p] = os.clock() - 60
			p:SetAttribute("RankeadaFila", true)
		end
	end
	if motivo ~= "palco" then
		for _, p in { a, b } do
			aviso(p, "O duelo não pôde começar. Você voltou para a fila.")
		end
	end
end

-- Procura o par mais parecido da fila
local function parear()
	if pareando or Palco.ocupado() or Trono.temPrioridade() then
		return
	end
	local agora = os.clock()
	local livres = {}
	for p in fila do
		if p.Parent ~= Players then
			fila[p] = nil
		elseif PvP.disponivel(p) then
			table.insert(livres, p)
		end
	end
	local melhor: { Player }? = nil
	local menor = math.huge
	for i = 1, #livres do
		for j = i + 1, #livres do
			local a, b = livres[i], livres[j]
			local diferenca = math.abs(rating(a) - rating(b))
			local espera = math.max(agora - (fila[a] or agora), agora - (fila[b] or agora))
			if diferenca <= ArenaPvP.janela(espera) and diferenca < menor then
				melhor, menor = { a, b }, diferenca
			end
		end
	end
	if not melhor then
		return
	end
	local a, b = melhor[1], melhor[2]
	fila[a], fila[b] = nil, nil
	a:SetAttribute("RankeadaFila", nil)
	b:SetAttribute("RankeadaFila", nil)
	pareando = true
	for _, par in { { a, b }, { b, a } } do
		aviso(
			par[1],
			string.format(
				"Oponente encontrado: %s (%d). O duelo começa em %d s!",
				par[2].DisplayName,
				rating(par[2]),
				CONTAGEM
			)
		)
	end
	task.delay(CONTAGEM, function()
		pareando = false
		iniciarPar(a, b)
	end)
end

local function entrar(player: Player): (boolean, string?)
	local e = Dados.de(player) :: any
	if not e then
		return false, "Aguarde o seu perfil carregar."
	end
	if not e.equipada then
		return false, "Desperte uma aura antes de entrar na Rankeada."
	end
	if fila[player] then
		return false, "Você já está na fila da Rankeada."
	end
	if player:GetAttribute("EmDueloArena") then
		return false, "Termine o duelo atual primeiro."
	end
	fila[player] = os.clock()
	player:SetAttribute("RankeadaFila", true)
	task.spawn(parear)
	return true, "Procurando um oponente na Rankeada..."
end

function Rankeada.iniciar()
	valor = Instance.new("StringValue")
	valor.Name = "RankingGlobal"
	valor.Value = HttpService:JSONEncode({ global = store ~= nil, lista = {} })
	valor.Parent = ReplicatedStorage
	Acoes.registrar("RankeadaEntrar", entrar)
	Acoes.registrar("RankeadaSair", function(player)
		if not fila[player] then
			return false, "Você não está na fila da Rankeada."
		end
		fila[player] = nil
		player:SetAttribute("RankeadaFila", nil)
		return true, "Você saiu da fila da Rankeada."
	end)
	Dados.quandoCarregar(function(player)
		player:SetAttribute("RatingArena", rating(player))
		task.defer(publicar)
	end)
	Players.PlayerRemoving:Connect(function(player)
		fila[player] = nil
	end)
	Palco.aoLiberar(parear)
	task.spawn(function()
		while true do
			local ok, erro = pcall(ler)
			if not ok then
				warn("[Rankeada] " .. tostring(erro))
			end
			task.wait(INTERVALO_LEITURA)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			local ok, erro = pcall(parear)
			if not ok then
				warn("[Rankeada] " .. tostring(erro))
			end
		end
	end)
end

return Rankeada
