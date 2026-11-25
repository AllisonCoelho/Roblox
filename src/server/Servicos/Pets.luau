-- Ecos (pets) e Núcleos no servidor. O Cristal do Nexo, no meio da praça, desperta Núcleos em
-- troca de Fragmentos do Corredor (regras em Shared/Dados/Pets). O cliente só pede; o servidor
-- confere distância ao Cristal, fase concluída, saldo, espaço e sorteia com Random.new().
--
-- Os Ecos equipados vão num atributo do Player ("Ecos") para que todo cliente desenhe os Ecos
-- de todo mundo, e entram como multiplicadores no ganho de Pontos de Aura e na sorte do giro.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared.Dados.Pets)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)
local PontosAura = require(script.Parent.PontosAura)

local Servico = {}

local rng = Random.new()
local RAIO_CRISTAL = 45 -- distância (no plano) do centro da praça para abrir Núcleos

local function aleatorio(): number
	return rng:NextNumber()
end

local function colecao(player: Player): Pets.Colecao?
	local estado = Dados.de(player)
	return if estado then (estado :: any).pets else nil
end

function Servico.multiplicadores(player: Player): (number, number, number)
	local c = colecao(player)
	if not c then
		return 1, 1, 1
	end
	return Pets.multiplicadores(c)
end

-- Ecos equipados para os clientes: "eco:prisma;eco:prisma"
local function publicar(player: Player)
	local c = colecao(player)
	if not c then
		return
	end
	local partes = {}
	for _, uid in c.equipados do
		local g = c.lista[uid]
		if g then
			table.insert(partes, g.eco .. ":" .. (if g.prisma then "1" else "0"))
		end
	end
	local texto = table.concat(partes, ";")
	if player:GetAttribute("Ecos") ~= texto then
		player:SetAttribute("Ecos", texto)
	end
end

local function pertoDoCristal(player: Player): boolean
	local personagem = player.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not raiz or not raiz:IsA("BasePart") then
		return false
	end
	local p = raiz.Position
	return Vector3.new(p.X, 0, p.Z).Magnitude <= RAIO_CRISTAL and p.Y < 40
end

local function abrir(
	player: Player,
	numero: any,
	quantidade: any
): (boolean, string?, { [string]: any }?)
	if type(numero) ~= "number" or not Pets.NUCLEOS[numero] then
		return false, "Núcleo desconhecido."
	end
	if
		type(quantidade) ~= "number"
		or quantidade % 1 ~= 0
		or quantidade < 1
		or quantidade > Pets.ABRIR_MAXIMO
	then
		return false, "Quantidade inválida."
	end
	if not Dados.podeProgredir(player) then
		return false, "Seu perfil ainda não está disponível."
	end
	if not pertoDoCristal(player) then
		return false, "Os Núcleos só despertam perto do Cristal do Nexo."
	end
	local nucleo = Pets.NUCLEOS[numero]
	local nascidos: { { uid: string, eco: string, prisma: boolean } } = {}
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		if not Pets.nucleoLiberado(nucleo, e.corredor) then
			return false,
				string.format("Conclua a fase %d do Corredor para abrir este Núcleo.", nucleo.fase)
		end
		local custo = nucleo.preco * quantidade
		if e.corredor.fragmentos < custo then
			return false, string.format("Faltam %d Fragmentos.", custo - e.corredor.fragmentos)
		end
		if Pets.quantidade(e.pets) + quantidade > Pets.CAPACIDADE then
			return false, "Sua coleção está cheia. Liberte alguns Ecos."
		end
		e.corredor.fragmentos -= custo
		for _ = 1, quantidade do
			local eco, prisma = Pets.sortear(nucleo, aleatorio)
			local uid = Pets.adicionar(e.pets, eco, prisma, os.time())
			if uid then
				table.insert(nascidos, { uid = uid, eco = eco, prisma = prisma })
				-- primeiro Eco: já vai para o lado do jogador
				if #e.pets.equipados < Pets.slots(e.corredor) then
					Pets.equipar(e.pets, uid, true, Pets.slots(e.corredor))
				end
			end
		end
		return true
	end)
	if not ok then
		return false, msg
	end
	publicar(player)
	return true, nil, { ecos = nascidos }
end

local function equipar(player: Player, uid: any, ligar: any): (boolean, string?)
	if type(ligar) ~= "boolean" then
		return false, "Pedido inválido."
	end
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		return Pets.equipar(e.pets, uid, ligar, Pets.slots(e.corredor))
	end)
	if ok then
		publicar(player)
	end
	return ok, msg
end

local function melhores(player: Player): (boolean, string?)
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		Pets.equiparMelhores(e.pets, Pets.slots(e.corredor))
		return true
	end)
	if ok then
		publicar(player)
	end
	return ok, msg
end

local function libertar(player: Player, uid: any): (boolean, string?)
	local devolvido = 0
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		local volta, erro = Pets.libertar(e.pets, uid)
		if not volta then
			return false, erro
		end
		devolvido = volta
		e.corredor.fragmentos += volta
		return true
	end)
	if ok then
		return true, string.format("Eco libertado. +%d Fragmentos", devolvido)
	end
	return false, msg
end

function Servico.iniciar()
	Acoes.registrar("AbrirNucleo", abrir)
	Acoes.registrar("EquiparEco", equipar)
	Acoes.registrar("EquiparMelhoresEcos", melhores)
	Acoes.registrar("LibertarEco", libertar)
	PontosAura.registrarGanho(function(player)
		local ganho = Servico.multiplicadores(player)
		return ganho
	end)
	PontosAura.registrarSorte(function(player)
		local _, sorte = Servico.multiplicadores(player)
		return sorte
	end)
	Dados.quandoCarregar(function(player)
		publicar(player)
	end)
	Dados.quandoMudar(function(player)
		publicar(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("Ecos", nil)
	end)
end

return Servico
