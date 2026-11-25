-- Corredor dos Perdidos no servidor: monta a colisão das seis ilhas (Dados/CorredorMapa, gerado
-- pelo Blender), os portais e as regras de entrada e conclusão (Dados/Corredor).
--
-- Todo movimento entre fases é um teleporte feito AQUI: o cliente só pede ("CorredorIr") ou
-- encosta num portal. O servidor confere Pontuação, fase anterior, distância e tempo mínimo, e
-- devolve ao Nexo quem aparece numa ilha sem acesso. O visual das ilhas é do cliente
-- (Nexo3D/CenaCorredor); as caixas daqui são a colisão e a reserva se o kit falhar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Corredor = require(Shared.Dados.Corredor)
local Mapa = require(Shared.Dados.CorredorMapa)
local Remotos = require(Shared.Remotos)
local Servicos = script.Parent.Parent.Servicos
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local PontosAura = require(Servicos.PontosAura)

local Servico = {}

type Fase = { [string]: any }
type Presenca = { fase: number, desde: number, concluiu: boolean }

local presenca: { [Player]: Presenca } = {}
local esperaToque: { [Player]: number } = {}

-- Entrada no Nexo: os Portais Fragmentados (mesmos valores de Mundo/Nexo e do gerador do Nexo)
local PORTAIS_GRAUS, PORTAIS_DIST = 135, 150
local ENTRADA_RAIO = 40
local QUEDA = 60 -- abaixo do topo da ilha: volta ao começo da fase
local RAIO_ILHA = 95 -- distância (no plano) até o centro que ainda conta como "na ilha"

local CORES_RESERVA = {
	Color3.fromHex("5C5872"),
	Color3.fromHex("3E5A52"),
	Color3.fromHex("4A3C3A"),
	Color3.fromHex("8FA9C0"),
	Color3.fromHex("B9B4BF"),
	Color3.fromHex("221A2E"),
}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function fase(n: number): Fase
	return (Mapa.fases :: { Fase })[n]
end

local function giroDe(f: Fase): CFrame
	return CFrame.Angles(0, math.rad(f.giro), 0)
end

local function entradaNexo(): Vector3
	local g = math.rad(PORTAIS_GRAUS)
	return Vector3.new(math.sin(g) * PORTAIS_DIST, 0, -math.cos(g) * PORTAIS_DIST)
end

local function corpoDe(player: Player): (Model?, BasePart?)
	local personagem = player.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if
		not personagem
		or not raiz
		or not raiz:IsA("BasePart")
		or not humanoide
		or humanoide.Health <= 0
	then
		return nil, nil
	end
	return personagem, raiz
end

local function avisar(player: Player, texto: string)
	Remotos.evento("Aviso"):FireClient(player, { tipo = "info", texto = texto })
end

local function pontuacao(player: Player): number
	return PontosAura.pontuacao(player)
end

local function progresso(player: Player): Corredor.Progresso?
	local estado = Dados.de(player)
	return if estado then (estado :: any).corredor else nil
end

local function publicar(player: Player)
	local p = progresso(player)
	if not p then
		return
	end
	player:SetAttribute("CorredorAcesso", Corredor.acesso(p, pontuacao(player)))
	player:SetAttribute("BonusAuraAte", p.bonusAte)
end

local function teleportar(player: Player, destino: CFrame)
	local personagem, raiz = corpoDe(player)
	if not personagem or not raiz then
		return
	end
	personagem:PivotTo(destino * raiz.CFrame:ToObjectSpace(personagem:GetPivot()))
	raiz.AssemblyLinearVelocity = Vector3.zero
	raiz.AssemblyAngularVelocity = Vector3.zero
end

local function voltarAoNexo(player: Player)
	presenca[player] = nil
	player:SetAttribute("CorredorFase", nil)
	local centro = entradaNexo()
	-- na frente dos Portais, olhando para eles
	local rumo = -centro.Unit
	local chegada = centro + rumo * 28 + Vector3.new(0, 4, 0)
	teleportar(player, CFrame.lookAt(chegada, centro + Vector3.new(0, 4, 0)))
end

local function entrar(player: Player, n: number)
	local f = fase(n)
	local inicio = v3(f.pontos.inicio) + Vector3.new(0, 4, 0)
	local alvo = v3(f.pontos.portao) + Vector3.new(0, 4, 0)
	presenca[player] = { fase = n, desde = os.clock(), concluiu = false }
	player:SetAttribute("CorredorFase", n)
	teleportar(player, CFrame.lookAt(inicio, alvo))
end

local function tentarEntrar(player: Player, n: number): (boolean, string?)
	local p = progresso(player)
	if not p or not Dados.podeProgredir(player) then
		return false, "Seu perfil ainda não está disponível."
	end
	if player:GetAttribute("EmDueloArena") then
		return false, "Termine o duelo antes de entrar no Corredor."
	end
	local ok, motivo = Corredor.podeEntrar(p, n, pontuacao(player))
	if not ok then
		return false, motivo
	end
	entrar(player, n)
	return true, nil
end

local function concluir(player: Player, n: number)
	local estar = presenca[player]
	if not estar or estar.fase ~= n or estar.concluiu then
		return
	end
	if os.clock() - estar.desde < Corredor.TEMPO_MINIMO then
		return
	end
	estar.concluiu = true
	local ganho, primeira = 0, false
	local ok = Dados.alterar(player, function(estado)
		ganho, primeira = Corredor.concluir((estado :: any).corredor, n, os.time())
		return true
	end)
	if not ok then
		return
	end
	publicar(player)
	local f = Corredor.FASES[n]
	local minutos = math.floor(Corredor.BONUS_DURACAO / 60)
	if ganho > 0 then
		avisar(
			player,
			string.format(
				"%s %s! +%d Fragmentos · Pontos de Aura em dobro por %d min",
				f.nome,
				if primeira then "concluída pela primeira vez" else "concluída",
				ganho,
				minutos
			)
		)
	else
		avisar(
			player,
			string.format("%s concluída! Pontos de Aura em dobro por %d min", f.nome, minutos)
		)
	end
end

-- Portão do fim da fase n: leva à próxima (se puder) ou, na última, de volta ao Nexo
local function passarPortao(player: Player, n: number)
	local estar = presenca[player]
	if not estar or estar.fase ~= n then
		return
	end
	if not estar.concluiu then
		concluir(player, n)
	end
	if n >= Corredor.TOTAL then
		avisar(player, "Você atravessou todo o Corredor dos Perdidos!")
		voltarAoNexo(player)
		return
	end
	local ok, motivo = tentarEntrar(player, n + 1)
	if not ok then
		avisar(player, motivo or "O Portão não abre para você ainda.")
		-- empurra de volta para antes do Portão
		local f = fase(n)
		local fim = v3(f.pontos.fim) + Vector3.new(0, 4, 0)
		teleportar(player, CFrame.lookAt(fim, v3(f.pontos.portao) + Vector3.new(0, 4, 0)))
	end
end

local function aoTocar(gatilho: BasePart, n: number, tipo: string)
	gatilho.Touched:Connect(function(outro)
		local personagem = outro.Parent
		local player = personagem and Players:GetPlayerFromCharacter(personagem)
		if not player then
			return
		end
		local agora = os.clock()
		if (esperaToque[player] or 0) > agora then
			return
		end
		local _, raiz = corpoDe(player)
		-- o toque vem do cliente: confere se o corpo está mesmo perto do gatilho
		if not raiz or (raiz.Position - gatilho.Position).Magnitude > gatilho.Size.Magnitude then
			return
		end
		esperaToque[player] = agora + 0.6
		if tipo == "retorno" then
			voltarAoNexo(player)
		elseif tipo == "fim" then
			concluir(player, n)
		elseif tipo == "portao" then
			passarPortao(player, n)
		end
	end)
end

local function parte(pasta: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = pasta
	return p
end

local function placa(
	pasta: Instance,
	posicao: Vector3,
	titulo: string,
	detalhe: string,
	cor: Color3
)
	local ancora = parte(pasta, {
		Name = "Placa",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = Vector3.one,
		CFrame = CFrame.new(posicao),
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 64)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 36)
	t.Font = Enum.Font.Oswald
	t.TextSize = 28
	t.TextColor3 = cor
	t.TextStrokeTransparency = 0.3
	t.Text = titulo
	t.Parent = gui
	local d = Instance.new("TextLabel")
	d.BackgroundTransparency = 1
	d.Position = UDim2.fromOffset(0, 36)
	d.Size = UDim2.new(1, 0, 0, 24)
	d.Font = Enum.Font.GothamMedium
	d.TextSize = 17
	d.TextColor3 = Color3.fromHex("E8E4F2")
	d.TextStrokeTransparency = 0.4
	d.Text = detalhe
	d.Parent = gui
	gui.Parent = ancora
end

local function construir(): Folder
	local existente = Workspace:FindFirstChild("Corredor")
	if existente then
		existente:Destroy()
	end
	local pasta = Instance.new("Folder")
	pasta.Name = "Corredor"
	for n, f in Mapa.fases :: { Fase } do
		local sub = Instance.new("Folder")
		sub.Name = "Fase" .. n
		sub.Parent = pasta
		local giro = giroDe(f)
		local dados = Corredor.FASES[n]
		local cor = Color3.fromHex(dados.cor)
		for _, c in f.colisores do
			local p = parte(sub, {
				Name = "Colisor",
				Color = CORES_RESERVA[n],
				Material = Enum.Material.Slate,
				CastShadow = false,
				Size = v3(c.tamanho),
				CFrame = CFrame.new(v3(c.posicao)) * giro,
			})
			-- reserva visual: o cliente esconde quando o kit do Corredor monta
			p:SetAttribute("Provisorio", true)
		end
		local function gatilho(nome: string, ponto: Vector3, tamanho: Vector3, tipo: string)
			local p = parte(sub, {
				Name = nome,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Size = tamanho,
				CFrame = CFrame.new(ponto + Vector3.new(0, tamanho.Y / 2, 0)) * giro,
			})
			aoTocar(p, n, tipo)
		end
		gatilho("Retorno", v3(f.pontos.retorno), Vector3.new(8, 8, 3), "retorno")
		gatilho("Fim", v3(f.pontos.fim), Vector3.new(30, 10, 4), "fim")
		gatilho("Portao", v3(f.pontos.portao), Vector3.new(15, 15, 3), "portao")

		placa(
			sub,
			v3(f.pontos.inicio) + Vector3.new(0, 12, 0),
			string.format("FASE %d · %s", n, string.upper(dados.nome)),
			dados.descricao,
			cor
		)
		local proxima = Corredor.FASES[n + 1]
		placa(
			sub,
			v3(f.pontos.portao) + Vector3.new(0, 21, 0),
			if proxima then string.format("PORTÃO · FASE %d", n + 1) else "FIM DO CORREDOR",
			if proxima
				then string.format("%s · Pontuação %d", proxima.nome, proxima.requisito)
				else "O portal leva de volta ao Nexo",
			if proxima then Color3.fromHex(proxima.cor) else cor
		)
		placa(sub, v3(f.pontos.retorno) + Vector3.new(0, 10, 0), "VOLTAR AO NEXO", "", cor)
	end
	pasta.Parent = Workspace
	return pasta
end

-- Em que ilha a posição está (nil fora de todas)
local function ilhaDe(posicao: Vector3): number?
	for n, f in Mapa.fases :: { Fase } do
		local c = v3(f.centro)
		local plano = Vector3.new(posicao.X - c.X, 0, posicao.Z - c.Z).Magnitude
		if plano < RAIO_ILHA and posicao.Y > c.Y - 20 and posicao.Y < c.Y + 40 then
			return n
		end
	end
	return nil
end

-- Vigia: quem cai volta ao começo da fase; quem aparece numa ilha sem acesso volta ao Nexo
local function vigiar()
	for _, player in Players:GetPlayers() do
		local _, raiz = corpoDe(player)
		if not raiz then
			continue
		end
		local estar = presenca[player]
		if estar then
			local f = fase(estar.fase)
			if raiz.Position.Y < f.centro[2] - QUEDA then
				avisar(player, "O vazio te devolveu ao começo da fase.")
				entrar(player, estar.fase)
				continue
			end
		end
		local n = ilhaDe(raiz.Position)
		if n and (not estar or estar.fase ~= n) then
			local p = progresso(player)
			if p and Corredor.podeEntrar(p, n, pontuacao(player)) then
				presenca[player] = { fase = n, desde = os.clock(), concluiu = false }
				player:SetAttribute("CorredorFase", n)
			else
				avisar(player, "Este fragmento ainda não te aceita.")
				voltarAoNexo(player)
			end
		end
	end
end

local function pedirFase(player: Player, n: any): (boolean, string?)
	if type(n) ~= "number" or n % 1 ~= 0 or n < 1 or n > Corredor.TOTAL then
		return false, "Fase desconhecida."
	end
	local _, raiz = corpoDe(player)
	if not raiz then
		return false, "Aguarde o personagem renascer."
	end
	-- só da entrada (Portais Fragmentados) ou de dentro do próprio Corredor
	local entrada = entradaNexo()
	local plano = Vector3.new(raiz.Position.X - entrada.X, 0, raiz.Position.Z - entrada.Z).Magnitude
	if plano > ENTRADA_RAIO and not presenca[player] then
		return false, "Vá até os Portais Fragmentados para entrar no Corredor."
	end
	return tentarEntrar(player, n)
end

function Servico.iniciar()
	construir()
	Acoes.registrar("CorredorIr", pedirFase)
	Acoes.registrar("CorredorSair", function(player)
		if not presenca[player] then
			return false, "Você não está no Corredor."
		end
		voltarAoNexo(player)
		return true, nil
	end)
	-- Ressonância de Combate: Pontos de Aura em dobro depois de concluir uma fase
	PontosAura.registrarGanho(function(player)
		local p = progresso(player)
		return if p then Corredor.multiplicador(p, os.time()) else 1
	end)
	Dados.quandoCarregar(function(player)
		publicar(player)
		player:GetAttributeChangedSignal("Pontuacao"):Connect(function()
			publicar(player)
		end)
		player.CharacterAdded:Connect(function()
			presenca[player] = nil
			player:SetAttribute("CorredorFase", nil)
		end)
	end)
	Dados.quandoSair(function(player)
		presenca[player] = nil
		esperaToque[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, erro = pcall(vigiar)
			if not ok then
				warn("[Corredor] " .. tostring(erro))
			end
		end
	end)
end

return Servico
