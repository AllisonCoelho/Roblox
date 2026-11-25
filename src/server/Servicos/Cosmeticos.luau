-- Cosméticos no servidor (catálogo em Shared/Dados/Cosmeticos). Só aparência, visível a todos:
-- título e distintivo sobre a cabeça, rastro ao andar, etiqueta no chat (atributos lidos
-- pelo cliente). Os pacotes pagos (Iniciante, VIP) entregam seus itens ao detectar o passe.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Catalogo = require(Shared.Dados.Cosmeticos)
local Conveniencia = require(Shared.Dados.Conveniencia)
local Perfil = require(Shared.Dados.Perfil)
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
	if item and item.exigeAssinatura and not Passes.tem(player, "assinatura") then
		return nil
	end
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
	-- Cores do ritual de giro (cada cliente aplica ao tocar o ritual deste jogador)
	local ritual = itemEquipado(player, "ritual")
	player:SetAttribute("CosRitualCor", if ritual then ritual.cor else nil)
	player:SetAttribute("CosRitualCor2", if ritual then ritual.cor2 else nil)
	local personagem = player.Character
	if personagem then
		placa(personagem, titulo, distintivo)
		rastro(personagem, trilha)
	end
end

local function atualizarSeMudou(player: Player)
	local e = equipados(player)
	local chave = string.format(
		"%s|%s|%s|%s|%s|%s",
		e.titulo or "",
		e.distintivo or "",
		e.rastro or "",
		e.ritual or "",
		tostring(Passes.tem(player, "vip")),
		tostring(Passes.tem(player, "assinatura"))
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
	if Passes.tem(player, "assinatura") then
		local agora = os.date("!*t")
		table.insert(ids, Catalogo.mensal(agora.year, agora.month))
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
		local item = Catalogo.porId[id]
		if item and item.exigeAssinatura and not Passes.tem(player, "assinatura") then
			return false, "Exclusivo da Assinatura do Nexo."
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

-- ===================================================================== Presets de Auras

local function salvarPreset(player: Player, slot: any): (boolean, string?)
	if not Conveniencia.slotValido(slot) then
		return false, "Pedido inválido"
	end
	if not Passes.tem(player, "presets") then
		return false, "Presets de Auras é um passe de 49 Robux."
	end
	return Dados.alterar(player, function(e: any)
		e.presets = if type(e.presets) == "table" then e.presets else {}
		local cos = e.cosmeticos and e.cosmeticos.equipados or {}
		-- preenche os espaços anteriores para manter a lista sem buracos (serializável)
		for i = 1, slot - 1 do
			e.presets[i] = e.presets[i] or Conveniencia.criarPreset(nil, nil)
		end
		e.presets[slot] = Conveniencia.criarPreset(e.equipada, cos)
		return true, "Preset " .. slot .. " salvo."
	end)
end

local function aplicarPreset(player: Player, slot: any): (boolean, string?)
	if not Conveniencia.slotValido(slot) then
		return false, "Pedido inválido"
	end
	if not Passes.tem(player, "presets") then
		return false, "Presets de Auras é um passe de 49 Robux."
	end
	if player:GetAttribute("EmDueloArena") then
		return false, "A aura fica equipada até o duelo terminar."
	end
	local ok, msg = Dados.alterar(player, function(e: any)
		local p = type(e.presets) == "table" and e.presets[slot]
		if type(p) ~= "table" then
			return false, "Preset vazio."
		end
		local aura = p.aura
		if
			type(aura) == "string"
			and aura ~= ""
			and Auras.porId[aura]
			and Perfil.possui(e, aura)
		then
			e.equipada = aura
		end
		e.cosmeticos = e.cosmeticos or Catalogo.padrao()
		local novos = {}
		if type(p.cosmeticos) == "table" then
			for tipo, id in p.cosmeticos do
				if
					type(tipo) == "string"
					and type(id) == "string"
					and Catalogo.podeEquipar(e.cosmeticos, tipo, id)
				then
					novos[tipo] = id
				end
			end
		end
		e.cosmeticos.equipados = novos
		return true, "Preset " .. slot .. " aplicado."
	end)
	if ok then
		atualizarSeMudou(player)
	end
	return ok, msg
end

-- ===================================================================== Arena

local function explosao(
	pai: BasePart,
	item: Catalogo.Item,
	quantidade: number,
	velocidade: number,
	duracao: number
)
	local anexo = Instance.new("Attachment")
	anexo.Name = "CosmeticoCelebracao"
	anexo.Parent = pai
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromHex(item.cor), Color3.fromHex(item.cor2 or item.cor))
	e.LightEmission = 0.8
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(velocidade * 0.5, velocidade)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = anexo
	e:Emit(quantidade)
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromHex(item.cor)
	luz.Range = 14
	luz.Brightness = 3
	luz.Parent = anexo
	task.delay(duracao, function()
		anexo:Destroy()
	end)
end

local function letreiro(pai: BasePart, item: Catalogo.Item)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CosmeticoCelebracao"
	gui.Size = UDim2.fromOffset(260, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Tema.FonteNegrito
	t.TextScaled = true
	t.TextColor3 = Color3.fromHex(item.cor)
	t.TextStrokeTransparency = 0.3
	t.Text = item.nome
	t.Parent = gui
	gui.Parent = pai
	task.delay(3, function()
		gui:Destroy()
	end)
end

-- Vitória na Arena: emote equipado no jogador e finalização no Soberano (todos veem)
function Servico.celebrar(player: Player, corpo: BasePart?, soberano: BasePart?)
	local emote = itemEquipado(player, "emote")
	if emote and corpo and corpo.Parent then
		explosao(corpo, emote, if emote.id == "emo_tempestade" then 120 else 80, 18, 3)
		letreiro(corpo, emote)
	end
	local fin = itemEquipado(player, "finalizacao")
	if fin and soberano and soberano.Parent then
		explosao(soberano, fin, if fin.id == "fin_eclipse" then 160 else 110, 26, 3)
	end
end

function Servico.iniciar()
	Acoes.registrar("EquiparCosmetico", equipar)
	Acoes.registrar("SalvarPreset", salvarPreset)
	Acoes.registrar("AplicarPreset", aplicarPreset)
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
