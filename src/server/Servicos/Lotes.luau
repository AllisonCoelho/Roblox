-- Vitrines no mundo (ver docs/design/04-vitrine.png): cada jogador recebe um lote livre,
-- os Docinhos da vitrine aparecem nos pedestais e o caixa e o escudo funcionam pisando neles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local Economia = require(Shared.Dados.Economia)
local Modelos = require(Shared.Dados.Modelos)
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local Construtor = require(script.Parent.Parent.Mundo.Construtor)
local Dados = require(script.Parent.Dados)
local Vitrine = require(script.Parent.Vitrine)

local Cores = Tema.Cores
local Lotes = {}

local ESCALA_DOCINHO = 1.5
local ESPERA_TOQUE = 1.5 -- segundos entre dois toques no caixa/escudo

local pasta: Folder
local donos: { [Player]: Model } = {}
local mostrado: { [Player]: string } = {} -- assinatura do que já está nos pedestais
local ultimoToque: { [Player]: number } = {}

function Lotes.de(player: Player): Model?
	return donos[player]
end

function Lotes.indiceDe(player: Player): number?
	local lote = donos[player]
	return lote and lote:GetAttribute("Indice") :: number
end

local function letreiro(lote: Model): (TextLabel?, TextLabel?)
	local placa = lote:FindFirstChild("Placa")
	local gui = placa and placa:FindFirstChild("Letreiro")
	if not gui then
		return nil, nil
	end
	return gui:FindFirstChild("Titulo") :: TextLabel, gui:FindFirstChild("Sub") :: TextLabel
end

local function rotulo(lote: Model, nome: string): (TextLabel?, TextLabel?)
	local parte = lote:FindFirstChild(nome)
	local gui = parte and parte:FindFirstChild("Rotulo")
	if not gui then
		return nil, nil
	end
	return gui:FindFirstChild("Titulo") :: TextLabel, gui:FindFirstChild("Sub") :: TextLabel
end

-- Coloca o modelo em cima do pedestal, de frente para a esteira
local function posicionar(modelo: Model, pedestal: BasePart, frente: Vector3)
	local _, tamanho = modelo:GetBoundingBox()
	local topo = pedestal.Position + Vector3.new(0, pedestal.Size.X / 2, 0)
	local giro = modelo:GetAttribute("GiroY")
	local cf = CFrame.lookAt(topo, topo + frente)
	if type(giro) == "number" then
		cf *= CFrame.Angles(0, -math.rad(giro), 0)
	end
	modelo:PivotTo(cf)
	-- Ajusta a altura para o fundo do modelo encostar no pedestal
	local caixa = modelo:GetBoundingBox()
	local fundo = caixa.Position.Y - tamanho.Y / 2
	modelo:PivotTo(modelo:GetPivot() + Vector3.new(0, topo.Y - fundo, 0))
end

local function efeitoVariante(modelo: Model, variante: string)
	local alvo = modelo.PrimaryPart or modelo:FindFirstChildWhichIsA("BasePart")
	if not alvo or variante == "normal" then
		return
	end
	local brilho = Instance.new("Sparkles")
	brilho.SparkleColor = if variante == "dourado" then Cores.Ouro else Cores.Rosa
	brilho.Parent = alvo
	local luz = Instance.new("PointLight")
	luz.Color = if variante == "dourado" then Cores.Ouro else Cores.Ceu
	luz.Range = 8
	luz.Brightness = 1.5
	luz.Parent = alvo
end

local function etiquetaDocinho(modelo: Model, id: string, variante: string)
	local d = Catalogo.docinho(id)
	local r = Catalogo.raridadeDe(id)
	local alvo = modelo.PrimaryPart or modelo:FindFirstChildWhichIsA("BasePart")
	if not d or not r or not alvo then
		return
	end
	local v = Catalogo.Variantes[variante]
	local nome = d.nome .. (if v and v.id ~= "normal" then " " .. v.nome else "")
	local _, _, sub = Construtor.placa(alvo, nome, {
		nome = "Etiqueta",
		tamanho = UDim2.fromOffset(180, 50),
		deslocamento = Vector3.new(0, 3.2, 0),
		distancia = 45,
		corSub = r.cor,
	})
	sub.Text = r.nome .. " · +" .. Formato.curto(Catalogo.rendaDe(id, variante)) .. "/s"
end

local function prepararModelo(modelo: Model)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
	end
end

-- Atualiza pedestais, Docinhos e letreiro do lote para combinar com o estado
function Lotes.sincronizar(player: Player, estado: Economia.Estado)
	local lote = donos[player]
	if not lote then
		return
	end
	local capacidade = Economia.capacidadeVitrine(estado)
	local titulo, sub = letreiro(lote)
	if titulo and sub then
		titulo.Text = "Vitrine de " .. player.DisplayName
		sub.Text = string.format(
			"Nível %d · %d / %d Docinhos",
			Economia.nivel(estado, "vitrine") + 1,
			#estado.vitrine,
			capacidade
		)
	end

	local partes = { tostring(capacidade) }
	for _, item in estado.vitrine do
		table.insert(partes, item.id .. ":" .. item.variante)
	end
	local assinatura = table.concat(partes, ",")
	if mostrado[player] == assinatura then
		return
	end
	mostrado[player] = assinatura

	local pedestais = lote:FindFirstChild("Pedestais") :: Folder
	local docinhos = lote:FindFirstChild("Docinhos") :: Folder
	docinhos:ClearAllChildren()
	local frente = (lote:GetPivot()).LookVector
	for _, pedestal in pedestais:GetChildren() do
		local i = pedestal:GetAttribute("Indice") :: number
		local ativo = i <= capacidade
		local p = pedestal :: BasePart
		p.Transparency = if ativo then 0 else 1
		p.CanCollide = ativo
		local item = estado.vitrine[i]
		if item and ativo then
			local modelo = Modelos.criar(item.id)
			modelo:ScaleTo(ESCALA_DOCINHO)
			prepararModelo(modelo)
			modelo.Name = item.id
			modelo.Parent = docinhos
			posicionar(modelo, p, frente)
			efeitoVariante(modelo, item.variante)
			etiquetaDocinho(modelo, item.id, item.variante)
		end
	end
end

local function limparLote(lote: Model)
	lote:SetAttribute("Dono", 0)
	local docinhos = lote:FindFirstChild("Docinhos")
	if docinhos then
		docinhos:ClearAllChildren()
	end
	local pedestais = lote:FindFirstChild("Pedestais")
	if pedestais then
		for _, p in pedestais:GetChildren() do
			(p :: BasePart).Transparency = 1
			(p :: BasePart).CanCollide = false
		end
	end
	local titulo, sub = letreiro(lote)
	if titulo and sub then
		titulo.Text = "Vitrine livre"
		sub.Text = ""
	end
	local portao = lote:FindFirstChild("Portao") :: BasePart?
	if portao then
		portao.Transparency = 1
	end
end

local function levarParaLote(player: Player, lote: Model)
	local personagem = player.Character
	local entrada = lote:FindFirstChild("Entrada") :: BasePart?
	-- O personagem pode ainda estar montando: espera a parte principal aparecer
	if personagem and not personagem:FindFirstChild("HumanoidRootPart") then
		personagem:WaitForChild("HumanoidRootPart", 5)
	end
	if personagem and personagem.Parent and entrada then
		personagem:PivotTo(entrada.CFrame + Vector3.new(0, 3, 0))
	end
end

local function atribuir(player: Player, estado: Economia.Estado)
	if donos[player] then
		return
	end
	for _, lote in pasta:GetChildren() do
		if lote:IsA("Model") and lote:GetAttribute("Dono") == 0 then
			lote:SetAttribute("Dono", player.UserId)
			donos[player] = lote
			Lotes.sincronizar(player, estado)
			levarParaLote(player, lote)
			return
		end
	end
	Remotos.evento("Aviso"):FireClient(player, {
		tipo = "erro",
		texto = "Este servidor está cheio de vitrines. Tente outro servidor!",
	})
end

-- Quem pisou: devolve o jogador se a parte é do personagem dele
local function jogadorDe(parte: BasePart): Player?
	local modelo = parte:FindFirstAncestorOfClass("Model")
	return modelo and Players:GetPlayerFromCharacter(modelo)
end

local function aoPisar(lote: Model, nomeParte: string, acao: (Player) -> (boolean, string?))
	local parte = lote:FindFirstChild(nomeParte) :: BasePart
	parte.CanTouch = true
	parte.Touched:Connect(function(outra)
		local player = jogadorDe(outra)
		if not player or donos[player] ~= lote then
			return
		end
		local agora = os.clock()
		if ultimoToque[player] and agora - ultimoToque[player] < ESPERA_TOQUE then
			return
		end
		ultimoToque[player] = agora
		local ok, msg = acao(player)
		if msg then
			Remotos.evento("Aviso")
				:FireClient(player, { tipo = if ok then "sucesso" else "info", texto = msg })
		end
	end)
end

-- Caixa, escudo e portão: atualiza os textos e o brilho duas vezes por segundo
local function atualizarRotulos()
	local agora = os.time()
	for player, lote in donos do
		local estado = Dados.de(player)
		if not estado then
			continue
		end
		local _, subCaixa = rotulo(lote, "Caixa")
		if subCaixa then
			subCaixa.Text = "🪙 " .. Formato.curto(math.floor(estado.caixa))
		end
		local tituloEscudo, subEscudo = rotulo(lote, "Escudo")
		local portao = lote:FindFirstChild("Portao") :: BasePart?
		local ligado = agora < estado.escudoAte
		if tituloEscudo and subEscudo then
			if ligado then
				subEscudo.Text = "ligado · " .. Formato.tempo(estado.escudoAte - agora)
			elseif agora < estado.escudoProntoEm then
				subEscudo.Text = "recarregando · " .. Formato.tempo(estado.escudoProntoEm - agora)
			else
				subEscudo.Text = "pise para ligar"
			end
		end
		if portao then
			portao.Transparency = if ligado then 0.2 else 1
		end
	end
end

function Lotes.iniciar(vitrines: Folder)
	pasta = vitrines
	for _, lote in pasta:GetChildren() do
		if lote:IsA("Model") then
			aoPisar(lote, "Caixa", Vitrine.coletar)
			aoPisar(lote, "Escudo", Vitrine.ligarEscudo)
		end
	end

	Dados.quandoCarregar(function(player, estado)
		-- Espera o personagem existir para levar o jogador até a vitrine
		task.spawn(function()
			if not player.Character then
				player.CharacterAdded:Wait()
			end
			if player.Parent then
				atribuir(player, Dados.de(player) or estado)
			end
		end)
	end)
	Dados.quandoMudar(function(player, estado)
		Lotes.sincronizar(player, estado)
	end)
	local function aoEntrar(player: Player)
		player.CharacterAdded:Connect(function()
			local lote = donos[player]
			if lote then
				-- Renascer na própria vitrine (depois que o personagem termina de aparecer)
				task.defer(levarParaLote, player, lote)
			end
		end)
	end
	Players.PlayerAdded:Connect(aoEntrar)
	for _, player in Players:GetPlayers() do
		aoEntrar(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local lote = donos[player]
		if lote then
			limparLote(lote)
		end
		donos[player] = nil
		mostrado[player] = nil
		ultimoToque[player] = nil
	end)

	task.spawn(function()
		while true do
			atualizarRotulos()
			task.wait(0.5)
		end
	end)
end

return Lotes
