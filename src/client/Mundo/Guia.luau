-- Trilha-guia: uma faixa brilhante do personagem até o próximo objetivo.
-- Ajuda quem ainda não lê bem (o público infantil) a entender o jogo sem texto:
--   carregando um Docinho  -> até a própria vitrine
--   chuva acontecendo      -> até o Docinho pousado mais perto
--   vitrine vazia          -> até a esteira (comprar o primeiro Docinho)
-- Tudo aqui é local (só o próprio jogador vê).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Mapa = require(Shared.Dados.Mapa)
local ChuvaDados = require(Shared.Dados.Chuva)
local UI = script.Parent.Parent:WaitForChild("UI")
local Estado = require(UI.Estado)

local Guia = {}

local player = Players.LocalPlayer

local function minhaVitrine(): Model?
	local pasta = workspace:FindFirstChild("Vitrines")
	if not pasta then
		return nil
	end
	for _, v in pasta:GetChildren() do
		if v:IsA("Model") and v:GetAttribute("Dono") == player.UserId then
			return v
		end
	end
	return nil
end

-- Ponto da esteira mais perto do jogador (no topo da esteira)
local function pontoNaEsteira(de: Vector3): Vector3
	local e = Mapa.Esteira
	local minZ, maxZ = math.min(e.inicio.Z, e.fim.Z), math.max(e.inicio.Z, e.fim.Z)
	return Vector3.new(e.inicio.X, e.altura + 1, math.clamp(de.Z, minZ + 4, maxZ - 4))
end

local function docinhoDaChuvaMaisPerto(de: Vector3): Vector3?
	local pasta = workspace:FindFirstChild("Chuva")
	if not pasta then
		return nil
	end
	local agora = workspace:GetServerTimeNow()
	local melhor, distancia = nil, math.huge
	for _, m in pasta:GetChildren() do
		local pouso = m:GetAttribute("Pouso")
		local inicio = m:GetAttribute("Inicio")
		if
			typeof(pouso) == "Vector3"
			and type(inicio) == "number"
			and ChuvaDados.pousou(inicio, agora)
		then
			local d = ((pouso :: Vector3) - de).Magnitude
			if d < distancia then
				melhor, distancia = pouso :: Vector3, d
			end
		end
	end
	return if melhor then melhor + Vector3.new(0, 2, 0) else nil
end

local function objetivo(de: Vector3): (Vector3?, Color3?)
	if player:GetAttribute("Carregando") then
		local vitrine = minhaVitrine()
		local entrada = vitrine and vitrine:FindFirstChild("Entrada") :: BasePart?
		if entrada then
			return entrada.Position + Vector3.new(0, 2, 0), Tema.Cores.Menta
		end
		return nil, nil
	end
	local fimChuva = workspace:GetAttribute("ChuvaAte")
	if type(fimChuva) == "number" and fimChuva > Estado.agora() then
		local alvo = docinhoDaChuvaMaisPerto(de)
		if alvo then
			return alvo, Tema.Cores.Ceu
		end
	end
	local estado = Estado.atual
	if estado and #estado.vitrine == 0 then
		return pontoNaEsteira(de), Tema.Cores.Rosa
	end
	return nil, nil
end

function Guia.iniciar()
	-- Ponta do alvo: uma peça invisível só deste cliente (dentro da câmera)
	local alvoParte = Instance.new("Part")
	alvoParte.Name = "GuiaAlvo"
	alvoParte.Anchored = true
	alvoParte.CanCollide = false
	alvoParte.CanQuery = false
	alvoParte.CanTouch = false
	alvoParte.Transparency = 1
	alvoParte.Size = Vector3.one
	local anexoAlvo = Instance.new("Attachment")
	anexoAlvo.Parent = alvoParte

	local feixe = Instance.new("Beam")
	feixe.Name = "Guia"
	feixe.Attachment1 = anexoAlvo
	feixe.FaceCamera = true
	feixe.Width0 = 1.2
	feixe.Width1 = 0.6
	feixe.Segments = 24
	feixe.CurveSize0 = 6
	feixe.CurveSize1 = -6
	feixe.LightEmission = 0.6
	feixe.Transparency = NumberSequence.new(0.15, 0.5)
	feixe.Enabled = false
	feixe.Parent = alvoParte

	local function prender(personagem: Model)
		local raiz = personagem:WaitForChild("HumanoidRootPart", 10)
		if not raiz then
			return
		end
		local anexo = Instance.new("Attachment")
		anexo.Name = "GuiaOrigem"
		anexo.Position = Vector3.new(0, -1.5, 0)
		anexo.Parent = raiz
		feixe.Attachment0 = anexo
	end
	player.CharacterAdded:Connect(prender)
	if player.Character then
		task.spawn(prender, player.Character)
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			local camera = workspace.CurrentCamera
			if camera and alvoParte.Parent ~= camera then
				alvoParte.Parent = camera
			end
			local personagem = player.Character
			local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not raiz or not feixe.Attachment0 then
				feixe.Enabled = false
				continue
			end
			local alvo, cor = objetivo(raiz.Position)
			-- Perto do objetivo a trilha some (já chegou)
			if alvo and cor and (alvo - raiz.Position).Magnitude > 8 then
				alvoParte.Position = alvo
				feixe.Color = ColorSequence.new(cor, Tema.Cores.Branco)
				feixe.Enabled = true
			else
				feixe.Enabled = false
			end
		end
	end)
end

return Guia
