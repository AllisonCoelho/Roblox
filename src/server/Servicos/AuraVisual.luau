-- Mostra a aura equipada em volta do personagem. Criada no servidor para todos verem.
-- Só partículas, luz e Highlight: leve e sem modelos 3D.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Cosmeticos = require(Shared.Dados.Cosmeticos)
local AurasVfx = require(Shared.Dados.AurasVfx)
local Perfil = require(Shared.Dados.Perfil)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)

local AuraVisual = {}

local NOME = "AuraDespertar"
local TEXTURAS = {
	brilho = "rbxasset://textures/particles/sparkles_main.dds",
	chama = "rbxasset://textures/particles/fire_main.dds",
	nevoa = "rbxasset://textures/particles/smoke_main.dds",
}

-- Aura que está aplicada em cada jogador ("" = nenhuma), para só refazer quando mudar
local aplicada: { [Player]: string } = {}
-- Só no Studio: aura de VFX mostrada como prévia (não é posse, não salva, não sorteia)
local previa: { [Player]: string? } = {}

local function emissor(pai: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = pai
	return e
end

local function limpar(personagem: Model)
	for _, inst in personagem:GetDescendants() do
		if inst.Name == NOME then
			inst:Destroy()
		end
	end
end

-- Aparência Alternativa equipada (cosmético): recolore a aura sem mudar raridade nem efeito
local function aparenciaDe(estado: any): Cosmeticos.Item?
	local id = estado
		and estado.cosmeticos
		and estado.cosmeticos.equipados
		and estado.cosmeticos.equipados.aparencia
	local item = if type(id) == "string" then Cosmeticos.porId[id] else nil
	return if item and item.tipo == "aparencia" then item else nil
end

local function criarEfeito(
	aura: Auras.Aura,
	personagem: Model,
	raiz: BasePart,
	aparencia: Cosmeticos.Item?
)
	local c1 = Color3.fromHex(aura.cores[1])
	local c2 = Color3.fromHex(aura.cores[2])
	if aparencia then
		c1 = c1:Lerp(Color3.fromHex(aparencia.cor), 0.75)
		c2 = c2:Lerp(Color3.fromHex(aparencia.cor2 or aparencia.cor), 0.75)
	end
	local t = aura.tier -- 1 (Comum) .. 7 (Divino)
	local cores = ColorSequence.new(c1, c2)

	local anexo = Instance.new("Attachment")
	anexo.Name = NOME
	anexo.Position = Vector3.new(0, -0.5, 0)

	-- Corpo da aura: partículas que sobem em volta do personagem
	emissor(anexo, {
		Name = "Corpo",
		Texture = TEXTURAS[aura.estilo] or TEXTURAS.brilho,
		Color = cores,
		LightEmission = if aura.estilo == "nevoa" then 0.4 else 1,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9 + 0.2 * t),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 10 + 6 * t,
		Speed = NumberRange.new(0.6, 1.4),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 3 + t * 0.5, 0),
		Drag = 1,
		RotSpeed = NumberRange.new(-60, 60),
		Rotation = NumberRange.new(0, 360),
	})

	-- A partir de Raro: faíscas
	if t >= 3 then
		emissor(anexo, {
			Name = "Faiscas",
			Texture = TEXTURAS.brilho,
			Color = ColorSequence.new(c1),
			LightEmission = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Lifetime = NumberRange.new(0.5, 1),
			Rate = 4 + 4 * t,
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 3,
		})
	end

	-- A partir de Épico: luz
	if t >= 4 then
		local luz = Instance.new("PointLight")
		luz.Name = NOME
		luz.Color = c1
		luz.Brightness = 0.5 + 0.4 * t
		luz.Range = 6 + 2 * t
		luz.Parent = raiz
	end

	-- A partir de Lendário: contorno brilhante no personagem
	if t >= 5 then
		local destaque = Instance.new("Highlight")
		destaque.Name = NOME
		destaque.FillColor = c2
		destaque.FillTransparency = 0.85
		destaque.OutlineColor = c1
		destaque.OutlineTransparency = 0.15
		destaque.DepthMode = Enum.HighlightDepthMode.Occluded
		destaque.Parent = personagem
	end

	-- A partir de Mítico: halo grande e lento
	if t >= 6 then
		emissor(anexo, {
			Name = "Halo",
			Texture = TEXTURAS.nevoa,
			Color = ColorSequence.new(c2, c1),
			LightEmission = 0.8,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(5 + t * 0.5),
			Lifetime = NumberRange.new(2, 3),
			Rate = 3,
			Speed = NumberRange.new(0),
			RotSpeed = NumberRange.new(-30, 30),
			Rotation = NumberRange.new(0, 360),
			LockedToPart = true,
		})
	end

	anexo.Parent = raiz
end

local function aplicar(player: Player, forcar: boolean?)
	local estado = Dados.de(player)
	local equipada = if estado and estado.equipada then estado.equipada else ""
	local id = previa[player] or equipada
	local aparencia = aparenciaDe(estado)
	local chave = id .. "|" .. (if aparencia then aparencia.id else "")
	if not forcar and aplicada[player] == chave then
		return
	end
	local personagem = player.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	if not personagem or not raiz or not raiz:IsA("BasePart") then
		return
	end
	local anterior = aplicada[player]
	local mudou = anterior ~= nil and string.split(anterior, "|")[1] ~= id
	aplicada[player] = chave
	limpar(personagem)
	-- Auras com VFX próprio: cada cliente monta o efeito a partir deste atributo.
	-- "AuraVfxEm" só muda quando o jogador troca de aura (não no respawn): é a deixa da manifestação.
	if AurasVfx[id] then
		if mudou then
			personagem:SetAttribute("AuraVfxEm", Workspace:GetServerTimeNow())
		end
		personagem:SetAttribute("AuraVfx", id)
		personagem:SetAttribute("AuraAparencia", if aparencia then aparencia.cor else nil)
		return
	end
	personagem:SetAttribute("AuraVfx", nil)
	local aura = Auras.porId[id]
	if aura then
		criarEfeito(aura, personagem, raiz, aparencia)
	end
end

function AuraVisual.definirPrevia(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" or (id ~= "" and not AurasVfx[id]) then
		return false, "Prévia inválida"
	end
	previa[player] = if id == "" then nil else id
	aplicar(player)
	return true, if previa[player] then "Prévia ligada: " .. id else "Prévia desligada"
end

-- Os atalhos no Studio alternam a prévia. O painel seleciona um efeito explicitamente.
local function alternarPrevia(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" or not AurasVfx[id] then
		return false, "Prévia inválida"
	end
	return AuraVisual.definirPrevia(player, if previa[player] == id then "" else id)
end

local function aoCarregar(player: Player, _estado: Perfil.Estado)
	player.CharacterAdded:Connect(function(personagem)
		personagem:WaitForChild("HumanoidRootPart", 10)
		aplicar(player, true)
	end)
	if player.Character then
		aplicar(player, true)
	end
end

function AuraVisual.iniciar()
	Dados.quandoCarregar(aoCarregar)
	Dados.quandoMudar(function(player)
		aplicar(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		aplicada[player] = nil
		previa[player] = nil
	end)
	if RunService:IsStudio() then
		Acoes.registrar("PreviaAura", alternarPrevia)
	end
end

return AuraVisual
