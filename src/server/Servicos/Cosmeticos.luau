-- Cosméticos no servidor (catálogo em Shared/Dados/Cosmeticos). Só aparência, visível a todos:
-- título e distintivo sobre a cabeça, rastro ao andar, etiqueta no chat (atributos lidos
-- pelo cliente). Os pacotes pagos (Iniciante, VIP) entregam seus itens ao detectar o passe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalogo = require(Shared.Dados.Cosmeticos)
local Tema = require(Shared.Tema)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)
local Passes = require(script.Parent.Passes)

local Servico = {}

local NOME_PLACA = "CosmeticoPlaca"
local NOME_RASTRO = "CosmeticoRastro"
local assinatura: { [Player]: string } = {}

local function equipados(player: Player): { [string]: string }
	local estado = Dados.de(player)
	local c = estado and (estado :: any).cosmeticos
	return if c and type(c.equipados) == "table" then c.equipados else {}
end

local function itemEquipado(player: Player, tipo: string): Catalogo.Item?
	local id = equipados(player)[tipo]
	local item = if id then Catalogo.porId[id] else nil
	return if item and item.tipo == tipo then item else nil
end

local function placa(personagem: Model, titulo: Catalogo.Item?, distintivo: Catalogo.Item?)
	local cabeca = personagem:FindFirstChild("Head")
	local antiga = cabeca and cabeca:FindFirstChild(NOME_PLACA)
	if antiga then
		antiga:Destroy()
	end
	if not cabeca or (not titulo and not distintivo) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = NOME_PLACA
	gui.Size = UDim2.fromOffset(240, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.9, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.fromScale(1, 1)
	texto.FontFace = Tema.FonteNegrito
	texto.TextScaled = true
	texto.RichText = true
	texto.TextStrokeTransparency = 0.35
	texto.TextStrokeColor3 = Color3.fromRGB(10, 6, 20)
	local partes = {}
	if distintivo then
		table.insert(
			partes,
			string.format('<font color="#%s">%s</font>', distintivo.cor, distintivo.texto)
		)
	end
	if titulo then
		table.insert(partes, string.format('<font color="#%s">%s</font>', titulo.cor, titulo.texto))
	end
	texto.Text = table.concat(partes, "  ")
	texto.Parent = gui
	gui.Parent = cabeca
end

local function rastro(personagem: Model, item: Catalogo.Item?)
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	for _, filho in raiz:GetChildren() do
		if filho.Name == NOME_RASTRO then
			filho:Destroy()
		end
	end
	if not item then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = NOME_RASTRO
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = raiz
	local a1 = Instance.new("Attachment")
	a1.Name = NOME_RASTRO
	a1.Position = Vector3.new(0, -1.1, 0)
	a1.Parent = raiz
	local t = Instance.new("Trail")
	t.Name = NOME_RASTRO
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Lifetime = 0.45
	t.MinLength = 0.15
	t.LightEmission = 0.7
	t.FaceCamera = true
	t.Color = ColorSequence.new(Color3.fromHex(item.cor), Color3.fromHex(item.cor2 or item.cor))
	t.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	t.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	t.Parent = raiz
end

local function aplicar(player: Player)
	local titulo = itemEquipado(player, "titulo")
	local distintivo = itemEquipado(player, "distintivo")
	local trilha = itemEquipado(player, "rastro")
	-- Etiqueta do chat (cliente monta o prefixo a partir destes atributos)
	player:SetAttribute("CosTitulo", if titulo then titulo.texto else nil)
	player:SetAttribute("CosTituloCor", if titulo then titulo.cor else nil)
	player:SetAttribute("CosDistintivo", if distintivo then distintivo.texto else nil)
	player:SetAttribute("CosDistintivoCor", if distintivo then distintivo.cor else nil)
	player:SetAttribute("CosVip", Passes.tem(player, "vip"))
	local personagem = player.Character
	if personagem then
		placa(personagem, titulo, distintivo)
		rastro(personagem, trilha)
	end
end

local function atualizarSeMudou(player: Player)
	local e = equipados(player)
	local chave = string.format(
		"%s|%s|%s|%s",
		e.titulo or "",
		e.distintivo or "",
		e.rastro or "",
		tostring(Passes.tem(player, "vip"))
	)
	if assinatura[player] ~= chave then
		assinatura[player] = chave
		aplicar(player)
	end
end

-- Entrega os itens dos pacotes que o jogador tem; equipa nos espaços vazios
local function concederPacotes(player: Player)
	if not Passes.verificado(player) or not Dados.de(player) then
		return
	end
	local ids: { string } = {}
	for pacote, itens in Catalogo.PACOTES do
		if Passes.tem(player, pacote) then
			for _, id in itens do
				table.insert(ids, id)
			end
		end
	end
	local estado = Dados.de(player) :: any
	local possui = estado.cosmeticos and estado.cosmeticos.possui or {}
	local falta = false
	for _, id in ids do
		falta = falta or not possui[id]
	end
	if falta then
		Dados.alterar(player, function(e: any)
			e.cosmeticos = e.cosmeticos or Catalogo.padrao()
			e.cosmeticos.equipados = e.cosmeticos.equipados or {}
			for _, id in Catalogo.conceder(e.cosmeticos, ids) do
				local tipo = Catalogo.porId[id].tipo
				if not e.cosmeticos.equipados[tipo] then
					e.cosmeticos.equipados[tipo] = id
				end
			end
			return true
		end)
	end
	atualizarSeMudou(player)
end

local function equipar(player: Player, tipo: any, id: any): (boolean, string?)
	if type(tipo) ~= "string" or type(id) ~= "string" or #id > 40 then
		return false, "Pedido inválido"
	end
	local ok, msg = Dados.alterar(player, function(e: any)
		e.cosmeticos = e.cosmeticos or Catalogo.padrao()
		if not Catalogo.podeEquipar(e.cosmeticos, tipo, id) then
			return false, "Você ainda não tem esse item."
		end
		e.cosmeticos.equipados = e.cosmeticos.equipados or {}
		e.cosmeticos.equipados[tipo] = if id == "" then nil else id
		return true
	end)
	if ok then
		atualizarSeMudou(player)
	end
	return ok, msg
end

function Servico.iniciar()
	Acoes.registrar("EquiparCosmetico", equipar)
	Passes.aoMudar(concederPacotes)
	Dados.quandoCarregar(function(player)
		concederPacotes(player)
	end)
	Dados.quandoMudar(function(player)
		atualizarSeMudou(player)
	end)
	local function conectar(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait() -- a Head e o HumanoidRootPart já existem no CharacterAdded do servidor
			aplicar(player)
		end)
	end
	Players.PlayerAdded:Connect(conectar)
	for _, player in Players:GetPlayers() do
		conectar(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		assinatura[player] = nil
	end)
end

return Servico
