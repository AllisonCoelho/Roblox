-- Esteira da Fábrica: solta Docinhos, vende para quem chega perto e cuida de quem está carregando.
-- Os Docinhos ficam parados no servidor; cada cliente anima a posição pelo tempo
-- (Shared/Dados/Esteira.luau). Para validar a compra o servidor faz a mesma conta.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local EsteiraDados = require(Shared.Dados.Esteira)
local Mapa = require(Shared.Dados.Mapa)
local Modelos = require(Shared.Dados.Modelos)
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local Dados = require(script.Parent.Dados)
local Acoes = require(script.Parent.Acoes)
local Missoes = require(script.Parent.Missoes)
local Vitrine = require(script.Parent.Vitrine)
local Lotes = require(script.Parent.Lotes)

local Cores = Tema.Cores
local Esteira = {}

local ESCALA_NA_ESTEIRA = 1.4
local ESCALA_NA_CABECA = 1.1
-- Folga na distância de compra por causa do atraso da internet
local FOLGA_DISTANCIA = 4

type Item = {
	id: string,
	variante: string,
	preco: number,
	inicio: number,
	modelo: Model,
	vendido: boolean,
}

local itens: { [number]: Item } = {}
local proximoUid = 0
local pasta: Folder
local aleatorio = Random.new()

local function agora(): number
	return workspace:GetServerTimeNow()
end

local function sorteAtiva(): boolean
	local t = os.time()
	for _, player in Players:GetPlayers() do
		local estado = Dados.de(player)
		if estado and Economia.boostAtivo(estado, "sorte", t) then
			return true
		end
	end
	return false
end

local function prepararPecas(modelo: Model, ancorado: boolean)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = ancorado
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
		end
	end
end

local function remover(uid: number)
	local item = itens[uid]
	if item then
		itens[uid] = nil
		item.modelo:Destroy()
	end
end

-- Cria um Docinho no começo da esteira (id/variante opcionais: usados pelo teste)
function Esteira.soltar(idForcado: string?, varianteForcada: string?)
	local id, variante
	if idForcado then
		id, variante = idForcado, varianteForcada or "normal"
	else
		id, variante = EsteiraDados.sortear(function()
			return aleatorio:NextNumber()
		end, sorteAtiva())
	end
	local d = Catalogo.docinho(id)
	local r = Catalogo.raridadeDe(id)
	if not d or not r then
		return
	end
	proximoUid += 1
	local uid = proximoUid
	local inicio = agora()
	local preco = EsteiraDados.preco(id, variante)

	local modelo = Modelos.criar(id)
	modelo:ScaleTo(ESCALA_NA_ESTEIRA)
	prepararPecas(modelo, true)
	-- Altura do pivô acima do fundo do modelo: com ela o Docinho fica apoiado na esteira
	modelo:PivotTo(CFrame.new())
	local caixa, tamanho = modelo:GetBoundingBox()
	local alturaBase = -(caixa.Position.Y - tamanho.Y / 2)
	local posicao = EsteiraDados.posicao(inicio, inicio)
	modelo:PivotTo(CFrame.new(posicao + Vector3.new(0, alturaBase, 0)))
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Peça invisível para o "aperte E" (o cliente move o modelo inteiro junto)
	local toque = Instance.new("Part")
	toque.Name = "Toque"
	toque.Size = Vector3.new(4, 4, 4)
	toque.Transparency = 1
	toque.Anchored = true
	toque.CanCollide = false
	toque.CanTouch = false
	toque.CFrame = modelo:GetPivot()
	toque.Parent = modelo
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Comprar · 🪙 " .. Formato.curto(preco)
	local v = Catalogo.Variantes[variante]
	prompt.ObjectText = d.nome
		.. (if v and v.id ~= "normal" then " " .. v.nome else "")
		.. " ("
		.. r.nome
		.. ")"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = EsteiraDados.DistanciaCompra - 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = toque

	if variante ~= "normal" then
		local brilho = Instance.new("Sparkles")
		brilho.SparkleColor = if variante == "dourado" then Cores.Ouro else Cores.Rosa
		brilho.Parent = toque
	end

	modelo.Name = "Item" .. uid
	modelo:SetAttribute("Uid", uid)
	modelo:SetAttribute("Inicio", inicio)
	modelo:SetAttribute("Docinho", id)
	modelo:SetAttribute("Variante", variante)
	modelo:SetAttribute("Preco", preco)
	-- Distância do pivô até o fundo do modelo (o cliente usa para apoiar na esteira)
	modelo:SetAttribute("AlturaBase", alturaBase)
	modelo.Parent = pasta

	itens[uid] = {
		id = id,
		variante = variante,
		preco = preco,
		inicio = inicio,
		modelo = modelo,
		vendido = false,
	}
	task.delay(EsteiraDados.duracao(), remover, uid)

	if r.ordem >= EsteiraDados.AvisarAPartirDe then
		Remotos.evento("Aviso"):FireAllClients({ tipo = "raro", texto = "", docinho = id })
	end
end

-- Mostra (ou tira) o Docinho em cima da cabeça e ajusta a velocidade
local function visualCarregando(player: Player)
	local personagem = player.Character
	local estado = Dados.de(player)
	local carga = estado and estado.carregando
	player:SetAttribute("Carregando", if carga then carga.id else nil)
	player:SetAttribute("CarregandoVariante", if carga then carga.variante else nil)
	if not personagem then
		return
	end
	local antigo = personagem:FindFirstChild("DocinhoCarregado")
	if antigo then
		antigo:Destroy()
	end
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	local raiz = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local nivelTenis = estado and Economia.nivel(estado, "tenis") or 0
	if humanoide then
		humanoide.WalkSpeed = if carga
			then Economia.VelocidadeCarregando + nivelTenis * Economia.VelocidadePorNivelTenis
			else Economia.VelocidadeBase
	end
	if not carga or not raiz then
		return
	end
	local modelo = Modelos.criar(carga.id)
	modelo.Name = "DocinhoCarregado"
	modelo:ScaleTo(ESCALA_NA_CABECA)
	prepararPecas(modelo, false)
	modelo:PivotTo(raiz.CFrame * CFrame.new(0, 5, 0))
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			local solda = Instance.new("WeldConstraint")
			solda.Part0 = raiz
			solda.Part1 = p
			solda.Parent = p
		end
	end
	if carga.variante ~= "normal" then
		local alvo = modelo:FindFirstChildWhichIsA("BasePart")
		if alvo then
			local brilho = Instance.new("Sparkles")
			brilho.SparkleColor = if carga.variante == "dourado" then Cores.Ouro else Cores.Rosa
			brilho.Parent = alvo
		end
	end
	modelo.Parent = personagem
end

-- Devolve as moedas de um Docinho que não chegou na vitrine
local function devolver(player: Player, motivo: string)
	local valor = 0
	local ok = Dados.alterar(player, function(estado)
		local carga = estado.carregando
		if not carga then
			return false
		end
		valor = carga.preco
		estado.moedas += carga.preco
		estado.carregando = nil
		return true
	end)
	if ok then
		visualCarregando(player)
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "info",
			texto = motivo .. " Você recebeu " .. Formato.curto(valor) .. " moedas de volta.",
		})
	end
end

local function entregar(player: Player)
	local carga: { id: string, variante: string, preco: number }? = nil
	Dados.alterar(player, function(estado)
		carga = estado.carregando
		estado.carregando = nil
		return carga ~= nil
	end)
	if not carga then
		return
	end
	local c = carga :: { id: string, variante: string, preco: number }
	if Vitrine.adicionarDocinho(player, c.id, c.variante) then
		local d = Catalogo.docinho(c.id)
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "sucesso",
			texto = (if d then d.nome else "Docinho") .. " está na sua vitrine!",
		})
		visualCarregando(player)
	else
		-- Vitrine encheu no caminho: devolve como carga e reembolsa
		Dados.alterar(player, function(estado)
			estado.carregando = c
			return true
		end)
		devolver(player, "Sua vitrine está cheia!")
	end
end

local function comprar(player: Player, uid: any): (boolean, string?)
	if type(uid) ~= "number" then
		return false, "Docinho inválido"
	end
	local item = itens[uid]
	if not item or item.vendido then
		return false, "Esse Docinho já foi embora"
	end
	local personagem = player.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if not raiz or not humanoide or humanoide.Health <= 0 then
		return false, "Espere renascer"
	end
	if not Lotes.de(player) then
		return false, "Você ainda não tem uma vitrine neste servidor"
	end
	local posicao = EsteiraDados.posicao(item.inicio, agora())
	if (raiz.Position - posicao).Magnitude > EsteiraDados.DistanciaCompra + FOLGA_DISTANCIA then
		return false, "Chegue mais perto da esteira"
	end
	local ok, msg = Dados.alterar(player, function(estado)
		if estado.carregando then
			return false, "Leve primeiro o Docinho que você está carregando"
		end
		if #estado.vitrine >= Economia.capacidadeVitrine(estado) then
			return false, "Sua vitrine está cheia! Venda um Docinho ou melhore a vitrine"
		end
		if estado.moedas < item.preco then
			return false, "Faltam " .. Formato.curto(item.preco - estado.moedas) .. " moedas"
		end
		estado.moedas -= item.preco
		estado.carregando = { id = item.id, variante = item.variante, preco = item.preco }
		return true
	end)
	if not ok then
		return false, msg
	end
	item.vendido = true
	remover(uid)
	visualCarregando(player)
	Missoes.progredir(player, "comprar_docinho", 1)
	local r = Catalogo.raridadeDe(item.id)
	if r and r.ordem >= 3 then
		Missoes.progredir(player, "comprar_raro", 1)
	end
	return true
end

function Esteira.iniciar(pastaItens: Folder)
	pasta = pastaItens
	Acoes.registrar("ComprarDaEsteira", comprar)

	-- Quem saiu ou caiu carregando recebe as moedas de volta ao entrar
	Dados.quandoCarregar(function(player, estado)
		if estado.carregando then
			task.defer(devolver, player, "O Docinho que você carregava não chegou na vitrine.")
		end
	end)

	local function aoEntrar(player: Player)
		player.CharacterAdded:Connect(function(personagem)
			local humanoide = personagem:WaitForChild("Humanoid") :: Humanoid
			visualCarregando(player)
			humanoide.Died:Connect(function()
				devolver(player, "Você caiu e o Docinho voltou para a fábrica.")
			end)
		end)
	end
	Players.PlayerAdded:Connect(aoEntrar)
	for _, player in Players:GetPlayers() do
		aoEntrar(player)
	end

	-- Entrega: quem chega na própria vitrine carregando, entrega
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local estado = Dados.de(player)
				local indice = Lotes.indiceDe(player)
				local personagem = player.Character
				local raiz = personagem
					and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
				if
					estado
					and estado.carregando
					and indice
					and raiz
					and Mapa.dentroDoLote(indice, raiz.Position)
				then
					entregar(player)
				end
			end
		end
	end)

	-- Fábrica: um Docinho novo a cada intervalo
	task.spawn(function()
		while true do
			local ok, erro = pcall(Esteira.soltar)
			if not ok then
				warn("[Esteira] erro ao soltar Docinho: " .. tostring(erro))
			end
			task.wait(EsteiraDados.Intervalo)
		end
	end)
end

return Esteira
