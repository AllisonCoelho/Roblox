-- Primeiro Soberano — Guardião do Trono Vazio. O NPC que ocupa o trono da Arena quando o
-- servidor nasce.
--
-- O SERVIDOR é o dono do NPC: existência, posição, colisão, conversa e reações compartilhadas
-- (atributos na peça "Raiz"). Cada cliente monta as peças 3D da armadura e anima a partir
-- desses atributos (src/client/Mundo/NPCs/PrimeiroSoberano.luau), como o kit do Nexo.
-- Se o visual falhar num cliente, as peças de reserva daqui continuam visíveis.
--
-- Fora do duelo, fica sentado, reage a quem chega e conversa. A Arena controla o duelo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotos = require(Shared.Remotos)
local Pecas = require(Shared.Dados.SoberanoPecas)
local ArenaCena = require(Shared.Dados.ArenaCena)

local PrimeiroSoberano = {}

PrimeiroSoberano.ESTADOS = {
	NPC_OCUPANTE = "NPC_OCUPANTE",
}

local FALAS = {
	"O trono não pertence a quem o deseja. Pertence a quem consegue defendê-lo.",
	"Quando estiver pronto, venha me desafiar.",
	"Os reis passam. A coroa permanece.",
}

local RAIO_PRESENCA = 30 -- studs: a partir daqui ele acompanha o visitante com a cabeça
local DISTANCIA_CONVERSA = 16
local FOLGA_CONVERSA = 6 -- tolerância do servidor sobre a distância do prompt
local ESPERA_CONVERSA = 2.5 -- por jogador
local ESPERA_REACAO = 8 -- compartilhada: uma reação por vez
local ESPERA_ALERTA = 25 -- compartilhada

local COR_ARMADURA = Color3.fromHex("2A2738")

local function bloco(
	pai: Instance,
	nome: string,
	cf: CFrame,
	tamanho: Vector3,
	visivel: boolean,
	colide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = tamanho
	p.CFrame = cf
	p.Color = COR_ARMADURA
	p.Material = Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = colide
	p.CanQuery = colide
	p.CanTouch = false
	p.Transparency = if visivel then 0 else 1
	p.Parent = pai
	return p
end

-- Cria o NPC dentro de `pasta` (o mapa). Chamar uma única vez, depois de montar o mapa.
function PrimeiroSoberano.iniciar(pasta: Instance)
	if pasta:FindFirstChild("PrimeiroSoberano") then
		return -- nunca duplicar
	end
	local a = math.rad(Pecas.arena.graus)
	local centro = Vector3.new(math.sin(a), 0, -math.cos(a)) * Pecas.arena.dist
	local olhar = CFrame.lookAt(centro, Vector3.zero)
	-- espaço do NPC: origem no pé do trono, -Z é a frente (para a entrada da Arena)
	local origem = olhar * CFrame.new(Pecas.trono[1], Pecas.trono[2], Pecas.trono[3])

	local modelo = Instance.new("Model")
	modelo.Name = "PrimeiroSoberano"

	local raiz = bloco(modelo, "Raiz", origem, Vector3.one, false, false)
	raiz:SetAttribute("Estado", PrimeiroSoberano.ESTADOS.NPC_OCUPANTE)
	raiz:SetAttribute("Alvo", 0) -- UserId de quem ele está olhando (0 = ninguém)
	raiz:SetAttribute("Reacao", 0) -- hora do servidor da última reação à chegada de alguém
	raiz:SetAttribute("Alerta", 0) -- hora do servidor do último gesto no braço do trono
	modelo.PrimaryPart = raiz

	-- Colisão (invisível): tronco e pernas. O trono já tem a própria colisão.
	bloco(
		modelo,
		"Colisor",
		origem * CFrame.new(0, 4.4, -0.3),
		Vector3.new(4.2, 3.8, 2.4),
		false,
		true
	)
	bloco(
		modelo,
		"Colisor",
		origem * CFrame.new(0, 1.3, -2.7),
		Vector3.new(3.4, 2.6, 2.6),
		false,
		true
	)

	-- Reserva visual simples (cada cliente esconde quando monta a armadura 3D)
	for _, d in
		{
			{ CFrame.new(0, 4.1, -0.3), Vector3.new(3.0, 3.0, 1.5) },
			{ CFrame.new(0, 6.0, -0.2), Vector3.new(1.3, 1.3, 1.4) },
			{ CFrame.new(0, 2.2, -1.2), Vector3.new(2.6, 1.0, 3.2) },
			{ CFrame.new(0, 1.1, -2.6), Vector3.new(2.6, 2.2, 1.2) },
		} :: { { any } }
	do
		local p = bloco(modelo, "Reserva", origem * d[1], d[2], true, false)
		p:SetAttribute("ReservaNPC", true)
	end

	local reservaDuelo = Instance.new("Folder")
	reservaDuelo.Name = "ReservaDuelo"
	reservaDuelo.Parent = modelo
	for _, d in
		{
			{ CFrame.new(0, 5.3, 0), Vector3.new(3.2, 3.1, 1.65) },
			{ CFrame.new(0, 7.4, 0), Vector3.new(1.55, 1.45, 1.45) },
			{ CFrame.new(1.92, 4.9, 0), Vector3.new(0.9, 2.2, 1.1) },
			{ CFrame.new(-1.92, 4.9, 0), Vector3.new(0.9, 2.2, 1.1) },
			{ CFrame.new(0.83, 1.8, 0), Vector3.new(1.3, 3.6, 1.4) },
			{ CFrame.new(-0.83, 1.8, 0), Vector3.new(1.3, 3.6, 1.4) },
			{ CFrame.new(2.5, 2.65, -0.5), Vector3.new(0.6, 5.2, 0.32) },
		} :: { { any } }
	do
		local parte = bloco(reservaDuelo, "Reserva", ArenaCena.soberano * d[1], d[2], false, false)
		parte:SetAttribute("ReservaNPC", true)
	end

	-- Nome sobre a cabeça
	local topo = bloco(modelo, "Nome", origem * CFrame.new(0, 9.2, -0.2), Vector3.one, false, false)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 52)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local nome = Instance.new("TextLabel")
	nome.BackgroundTransparency = 1
	nome.Size = UDim2.new(1, 0, 0, 30)
	nome.Font = Enum.Font.Oswald
	nome.TextSize = 24
	nome.TextColor3 = Color3.fromHex("C4A46D")
	nome.TextStrokeTransparency = 0.3
	nome.Text = "PRIMEIRO SOBERANO"
	nome.Parent = gui
	local titulo = Instance.new("TextLabel")
	titulo.BackgroundTransparency = 1
	titulo.Position = UDim2.fromOffset(0, 30)
	titulo.Size = UDim2.new(1, 0, 0, 20)
	titulo.Font = Enum.Font.Oswald
	titulo.TextSize = 16
	titulo.TextColor3 = Color3.fromHex("A9A3B6")
	titulo.TextStrokeTransparency = 0.4
	titulo.Text = "Guardião do Trono Vazio"
	titulo.Parent = gui
	gui.Parent = topo

	-- Conversa: o servidor confere distância e espera, mesmo com o prompt do cliente
	local ponto =
		bloco(modelo, "Conversa", origem * CFrame.new(0, 4.5, -2.4), Vector3.one, false, false)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Conversar"
	prompt.ObjectText = "Primeiro Soberano"
	prompt.MaxActivationDistance = DISTANCIA_CONVERSA
	prompt.RequiresLineOfSight = false
	prompt.Parent = ponto
	raiz:GetAttributeChangedSignal("Estado"):Connect(function()
		local sentado = raiz:GetAttribute("Estado") == PrimeiroSoberano.ESTADOS.NPC_OCUPANTE
		gui.Enabled = sentado
		prompt.Enabled = sentado
		for _, parte in modelo:GetChildren() do
			if parte:IsA("BasePart") and parte:GetAttribute("ReservaNPC") then
				parte.Transparency = if sentado then 0 else 1
			end
		end
		for _, parte in reservaDuelo:GetChildren() do
			if parte:IsA("BasePart") then
				parte.Transparency = if sentado then 1 else 0
			end
		end
	end)

	local ultimaConversa: { [Player]: number } = {}
	local proximaFala: { [Player]: number } = {}
	local ultimoAlerta = -math.huge
	prompt.Triggered:Connect(function(jogador: Player)
		local agora = os.clock()
		if agora - (ultimaConversa[jogador] or -math.huge) < ESPERA_CONVERSA then
			return
		end
		local personagem = jogador.Character
		local corpo = personagem and personagem:FindFirstChild("HumanoidRootPart")
		if not corpo or not corpo:IsA("BasePart") then
			return
		end
		if (corpo.Position - ponto.Position).Magnitude > DISTANCIA_CONVERSA + FOLGA_CONVERSA then
			return
		end
		if raiz:GetAttribute("Estado") ~= PrimeiroSoberano.ESTADOS.NPC_OCUPANTE then
			return
		end
		ultimaConversa[jogador] = agora
		local i = proximaFala[jogador] or 1
		proximaFala[jogador] = i % #FALAS + 1
		Remotos.evento("Aviso"):FireClient(jogador, {
			tipo = "npc",
			texto = "“" .. FALAS[i] .. "”",
		})
		-- gesto compartilhado (mão no braço do trono), no máximo um a cada ESPERA_ALERTA
		if agora - ultimoAlerta >= ESPERA_ALERTA then
			ultimoAlerta = agora
			raiz:SetAttribute("Alerta", Workspace:GetServerTimeNow())
		end
	end)
	Players.PlayerRemoving:Connect(function(jogador)
		ultimaConversa[jogador] = nil
		proximaFala[jogador] = nil
	end)

	modelo.Parent = pasta

	-- Presença: quem ele acompanha com a cabeça e quando reage à chegada de alguém.
	-- Uma reação por vez, com espera: vários jogadores entrando não empilham efeitos.
	task.spawn(function()
		local ultimaReacao = -math.huge
		local haviaAlguem = false
		local frente = (origem * CFrame.new(0, 3, -8)).Position
		while modelo.Parent do
			local maisPerto: Player? = nil
			local menor = RAIO_PRESENCA
			for _, jogador in Players:GetPlayers() do
				local personagem = jogador.Character
				local corpo = personagem and personagem:FindFirstChild("HumanoidRootPart")
				if corpo and corpo:IsA("BasePart") then
					local d = (corpo.Position - frente).Magnitude
					if d < menor then
						menor = d
						maisPerto = jogador
					end
				end
			end
			local alvo = if maisPerto then maisPerto.UserId else 0
			if raiz:GetAttribute("Alvo") ~= alvo then
				raiz:SetAttribute("Alvo", alvo)
			end
			local agora = os.clock()
			if maisPerto and not haviaAlguem and agora - ultimaReacao >= ESPERA_REACAO then
				ultimaReacao = agora
				raiz:SetAttribute("Reacao", Workspace:GetServerTimeNow())
			end
			haviaAlguem = maisPerto ~= nil
			task.wait(0.4)
		end
	end)
end

return PrimeiroSoberano
