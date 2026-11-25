-- Tutorial guiado (regras e falas em Shared/Dados/Tutorial). A Lume, Guardiã do Nexo, aparece em
-- 3D numa caixa de diálogo na parte de baixo da tela e fala: o texto é digitado letra por letra,
-- ela mexe a boca enquanto fala e pisca. Toque na caixa para acelerar ou seguir.
--
-- Em cada passo o tutorial destaca o botão certo do HUD (contorno pulsando e uma seta) e espera o
-- objetivo: girar, evoluir, pegar um drop (seta em cima do drop mais perto) ou chegar aos Portais
-- (coluna de luz no lugar). Com um painel aberto a caixa encolhe para um canto e mostra só a
-- dica. O servidor confere cada avanço e entrega os presentes; dá para pular a qualquer hora.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Dados = require(Shared.Dados.Tutorial)
local LumeVisual = require(Shared.Dados.LumeVisual)
local PontosAura = require(Shared.Dados.PontosAura)
local Remotos = require(Shared.Remotos)
local Cores = require(Shared.Tema).Orbita
local Escala = require(script.Parent.Parent.Escala)
local Estado = require(script.Parent.Parent.Estado)
local Kit = require(script.Parent.Parent.Kit)
local Navegacao = require(script.Parent.Parent.Navegacao)
local Revelacao = require(script.Parent.Revelacao)
local Mundo = script.Parent.Parent.Parent.Mundo
local Malha = require(Mundo.Nexo3D.Malha)
local Sons = require(Mundo.Sons)

local Tela = {}

local LETRAS_POR_SEGUNDO = 42
local RAIO_PORTAIS = 30

type Parte = { parte: MeshPart, papel: string, tamanho: Vector3 }

local raiz: Frame
local hudQuadro: GuiObject
local aviso: (string) -> ()

local caixa: Kit.Placa
local escalaCaixa: UIScale
local retrato: ViewportFrame
local camera: Camera
local partes: { Parte } = {}
local fala: TextLabel
local objetivoTexto: TextLabel
local seguir: Kit.BotaoPlaca
local pularBotao: TextButton
local indicador: TextLabel
local contorno: Frame
local seta: TextLabel
local setaDrop: BillboardGui
local coluna: Part?
local rotuloColuna: BillboardGui?

-- estado da conversa
local passoAtual = 0
local falaAtual = 1
local mostradas = 0 -- letras já digitadas
local digitando = false
local esperando = false -- falas acabaram; esperando o objetivo
local desde = 0 -- quando o objetivo começou a ser esperado
local pegouDrop = false
local pedindo = false
local confirmarPular = false
local proximaPiscada = 0
local ultimoBip = 0

local function progresso(): Dados.Progresso?
	local e = Estado.atual :: any
	if not e or type(e.tutorial) ~= "table" then
		return nil
	end
	return e.tutorial
end

local function passo(): Dados.Passo?
	return Dados.PASSOS[passoAtual]
end

local function raizPersonagem(): BasePart?
	local personagem = Players.LocalPlayer.Character
	local r = personagem and personagem:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function portais(): BasePart?
	local nexo = Workspace:FindFirstChild("Nexo")
	local veu = nexo and nexo:FindFirstChild("PortalVeu", true)
	return if veu and veu:IsA("BasePart") then veu else nil
end

-- ============================================================ objetivos

local function cumprido(p: Dados.Passo): boolean
	local e = Estado.atual :: any
	if not e then
		return false
	end
	if p.objetivo == "continuar" then
		return false -- só pelo botão
	elseif p.objetivo == "girar" then
		return (e.giros or 0) > 0 and not Revelacao.ativa()
	elseif p.objetivo == "evoluir" then
		local poder = e.poder or {}
		return (poder.nivel or 0) + (poder.fluxo or 0) + (poder.sorte or 0) > 0
	elseif p.objetivo == "drop" then
		return pegouDrop
	elseif p.objetivo == "portais" then
		local r, alvo = raizPersonagem(), portais()
		return r ~= nil and alvo ~= nil and (r.Position - alvo.Position).Magnitude < RAIO_PORTAIS
	end
	return false
end

local function textoObjetivo(p: Dados.Passo): string
	local dica = p.dica or ""
	local e = Estado.atual :: any
	if p.objetivo == "evoluir" and e and e.poder then
		local custo = PontosAura.custo("nivel", e.poder.nivel or 0)
		if custo then
			dica ..= string.format(
				"  (%d / %d Pontos)",
				math.floor(e.poder.pontos or 0),
				math.floor(custo)
			)
		end
	elseif p.objetivo == "portais" then
		local r, alvo = raizPersonagem(), portais()
		if r and alvo then
			dica ..= string.format("  (%d m)", math.floor((r.Position - alvo.Position).Magnitude))
		end
	end
	return "◎ " .. dica
end

-- ============================================================ avanço

local function avancar()
	if pedindo then
		return
	end
	pedindo = true
	local de = passoAtual
	task.spawn(function()
		local ok, msg = Estado.pedir("TutorialAvancar", de)
		pedindo = false
		if ok and msg then
			aviso("Presente da Lume: " .. msg)
			Sons.tocar("revelacao", Workspace, 1.4, 0.3)
		elseif not ok and msg then
			aviso(msg)
		end
	end)
end

local function comecarFala(i: number)
	falaAtual = i
	mostradas = 0
	digitando = true
	esperando = false
	local p = passo()
	fala.Text = if p then p.falas[i] or "" else ""
	fala.MaxVisibleGraphemes = 0
end

local function aoMudarPasso(novo: number)
	passoAtual = novo
	pegouDrop = false
	confirmarPular = false
	comecarFala(1)
end

-- Toque na caixa: acelera, vai para a próxima fala ou segue
local function tocar()
	local p = passo()
	if not p then
		return
	end
	if digitando then
		mostradas = utf8.len(fala.Text) or #fala.Text
		return
	end
	if falaAtual < #p.falas then
		comecarFala(falaAtual + 1)
		return
	end
	if p.objetivo == "continuar" then
		avancar()
	elseif p.paciencia and esperando and os.clock() - desde >= p.paciencia then
		avancar()
	end
end

-- ============================================================ montagem

local function montarRetrato(pai: Instance)
	retrato = Kit.novo("ViewportFrame", {
		Name = "Lume",
		BackgroundTransparency = 1,
		Ambient = Color3.fromHex("A89CD8"),
		LightColor = Color3.fromHex("FFF4E6"),
		LightDirection = Vector3.new(-0.4, -0.6, 1),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -6, 1, -2),
		Size = UDim2.fromOffset(150, 170),
		ZIndex = 6,
		Parent = pai,
	}) :: ViewportFrame
	local modelo = Instance.new("Model")
	local prontas: Malha.Cache = {}
	for _, m in LumeVisual :: { any } do
		local ok, parte, centro = pcall(Malha.criar, m.malha, prontas)
		if ok then
			parte.Material = (Enum.Material :: any)[m.material] or Enum.Material.SmoothPlastic
			parte.CFrame = CFrame.new(centro)
			parte.Parent = modelo
			table.insert(partes, { parte = parte, papel = m.papel, tamanho = parte.Size })
		end
	end
	modelo.Parent = retrato
	camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = retrato
	retrato.CurrentCamera = camera
end

local function montarCaixa()
	caixa = Kit.placa({
		nome = "Tutorial",
		tamanho = UDim2.fromOffset(640, 132),
		ancora = Vector2.new(0.5, 1),
		posicao = UDim2.new(0.5, 0, 1, -184),
		borda = Cores.Lilas,
		corte = 14,
		z = 20,
		pai = raiz,
	})
	caixa.quadro.Visible = false
	escalaCaixa = Kit.novo("UIScale", { Parent = caixa.quadro }) :: UIScale
	montarRetrato(caixa.conteudo)
	Kit.texto({
		fonte = "titulo",
		Text = string.upper(Dados.NOME) .. "  ·  " .. Dados.TITULO,
		TextSize = 15,
		TextColor3 = Cores.Lilas,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(150, 8),
		Size = UDim2.new(1, -260, 0, 18),
		Parent = caixa.conteudo,
	})
	fala = Kit.texto({
		Text = "",
		TextSize = 19,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(150, 30),
		Size = UDim2.new(1, -166, 0, 66),
		Parent = caixa.conteudo,
	})
	objetivoTexto = Kit.texto({
		Text = "",
		TextSize = 15,
		TextColor3 = Cores.Menta,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(150, 100),
		Size = UDim2.new(1, -310, 0, 22),
		Parent = caixa.conteudo,
	})
	indicador = Kit.texto({
		fonte = "titulo",
		Text = "▶",
		TextSize = 16,
		TextColor3 = Cores.Lilas,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -8),
		Size = UDim2.fromOffset(20, 20),
		Parent = caixa.conteudo,
	})
	-- toque em qualquer lugar da caixa
	local alvo = Kit.alvo(caixa.quadro, "Lume", tocar)
	alvo.ZIndex = 2 -- abaixo dos botões (que ficam no conteúdo)
	seguir = Kit.botaoPlaca({
		texto = "Continuar",
		tamanho = UDim2.fromOffset(130, 34),
		tamanhoTexto = 15,
		tom = "lilas",
		pai = caixa.conteudo,
		aoClicar = tocar,
	})
	seguir.placa.quadro.AnchorPoint = Vector2.new(1, 1)
	seguir.placa.quadro.Position = UDim2.new(1, -40, 1, -8)
	seguir.placa.quadro.ZIndex = 8
	pularBotao = Kit.novo("TextButton", {
		Text = "Pular tutorial",
		FontFace = Font.fromEnum(Enum.Font.Gotham),
		TextSize = 13,
		TextColor3 = Cores.TextoSuave,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(120, 20),
		ZIndex = 8,
		Parent = caixa.conteudo,
	}) :: TextButton
	pularBotao.Activated:Connect(function()
		if not confirmarPular then
			confirmarPular = true
			pularBotao.Text = "Tocar de novo para pular"
			pularBotao.TextColor3 = Color3.fromHex("FFC83D")
			task.delay(3, function()
				confirmarPular = false
				pularBotao.Text = "Pular tutorial"
				pularBotao.TextColor3 = Cores.TextoSuave
			end)
			return
		end
		task.spawn(Estado.pedir, "TutorialPular")
	end)

	-- destaque no HUD: contorno pulsando e seta
	contorno = Kit.novo("Frame", {
		Name = "DestaqueTutorial",
		BackgroundTransparency = 1,
		ZIndex = 19,
		Visible = false,
		Parent = raiz,
	}) :: Frame
	Kit.novo("UIStroke", {
		Color = Color3.fromHex("FFE27A"),
		Thickness = 3,
		Parent = contorno,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(0, 12), Parent = contorno })
	seta = Kit.texto({
		fonte = "titulo",
		Text = "▼",
		TextSize = 34,
		TextColor3 = Color3.fromHex("FFE27A"),
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 19,
		Visible = false,
		Parent = raiz,
	})
	-- seta em cima do drop mais perto
	setaDrop = Instance.new("BillboardGui")
	setaDrop.Size = UDim2.fromOffset(60, 60)
	setaDrop.StudsOffset = Vector3.new(0, 4, 0)
	setaDrop.AlwaysOnTop = true
	setaDrop.Enabled = false
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Size = UDim2.fromScale(1, 1)
	s.Font = Enum.Font.GothamBlack
	s.TextScaled = true
	s.Text = "▼"
	s.TextColor3 = Color3.fromHex("FFE27A")
	s.TextStrokeTransparency = 0.3
	s.Parent = setaDrop
	setaDrop.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- Coluna de luz nos Portais (só para este jogador)
local function mostrarColuna(ligar: boolean)
	if not ligar then
		if coluna then
			coluna:Destroy()
			coluna = nil
			rotuloColuna = nil
		end
		return
	end
	if coluna then
		return
	end
	local alvo = portais()
	if not alvo then
		return
	end
	local c = Instance.new("Part")
	c.Name = "LuzTutorial"
	c.Anchored = true
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.CastShadow = false
	c.Material = Enum.Material.Neon
	c.Color = Color3.fromHex("FFE27A")
	c.Transparency = 0.45
	c.Shape = Enum.PartType.Cylinder
	c.Size = Vector3.new(140, 3, 3)
	c.CFrame = CFrame.new(alvo.Position.X, 70, alvo.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	c.Parent = Workspace
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromOffset(260, 50)
	b.StudsOffset = Vector3.new(0, -50, 0)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = Color3.fromHex("FFE27A")
	t.TextStrokeTransparency = 0.3
	t.Text = "▼ Portais Fragmentados"
	t.Parent = b
	b.Parent = c
	coluna = c
	rotuloColuna = b
end

local function posicionarDestaque(nomeAlvo: string?, mini: boolean)
	local alvo = if nomeAlvo and not mini then hudQuadro:FindFirstChild(nomeAlvo, true) else nil
	if not alvo or not alvo:IsA("GuiObject") or not alvo.Visible then
		contorno.Visible = false
		seta.Visible = false
		return
	end
	local s = Escala.escala
	local origem = raiz.AbsolutePosition
	local pos = (alvo.AbsolutePosition - origem) / s
	local tam = alvo.AbsoluteSize / s
	local pulso = 1 + 0.06 * math.sin(os.clock() * 6)
	local folga = 6 * pulso
	contorno.Position = UDim2.fromOffset(pos.X - folga, pos.Y - folga)
	contorno.Size = UDim2.fromOffset(tam.X + folga * 2, tam.Y + folga * 2)
	contorno.Visible = true
	seta.Position =
		UDim2.fromOffset(pos.X + tam.X / 2, pos.Y - 8 - 6 * math.abs(math.sin(os.clock() * 4)))
	seta.Visible = true
end

local function atualizarSetaDrop(ligar: boolean)
	if not ligar then
		setaDrop.Enabled = false
		return
	end
	local r = raizPersonagem()
	local pasta = Workspace:FindFirstChild("DropsMapa")
	local melhor, menor = nil, math.huge
	if r and pasta then
		for _, d in pasta:GetChildren() do
			if d:IsA("BasePart") then
				local dist = (d.Position - r.Position).Magnitude
				if dist < menor then
					melhor, menor = d, dist
				end
			end
		end
	end
	setaDrop.Adornee = melhor
	setaDrop.Enabled = melhor ~= nil
end

-- ============================================================ quadro a quadro

local function animarRetrato(t: number)
	-- respiração (câmera) e um leve virar de cabeça
	local y = math.sin(t * 2) * 0.05
	local lado = math.sin(t * 0.7) * 0.35
	camera.CFrame = CFrame.lookAt(Vector3.new(lado + 0.6, 0.25 + y, -6.2), Vector3.new(0, 0.05, 0))
	if t >= proximaPiscada then
		proximaPiscada = t + 2.5 + math.random() * 2.5
	end
	local fechado = (proximaPiscada - t) < 0.12
	local falando = digitando and math.floor(t * 11) % 2 == 0
	for _, p in partes do
		if p.papel == "olhos" then
			local alvo = if fechado
				then Vector3.new(p.tamanho.X, p.tamanho.Y * 0.15, p.tamanho.Z)
				else p.tamanho
			if p.parte.Size ~= alvo then
				p.parte.Size = alvo
			end
		elseif p.papel == "boca" then
			local alvo = if falando
				then Vector3.new(p.tamanho.X, p.tamanho.Y * 2.4, p.tamanho.Z)
				else p.tamanho
			if p.parte.Size ~= alvo then
				p.parte.Size = alvo
			end
		end
	end
end

local function quadro(dt: number)
	local prog = progresso()
	local ativo = prog ~= nil and not prog.concluido and hudQuadro.Visible
	if not ativo then
		caixa.quadro.Visible = false
		contorno.Visible = false
		seta.Visible = false
		atualizarSetaDrop(false)
		mostrarColuna(false)
		return
	end
	local pr = prog :: Dados.Progresso
	if pr.passo ~= passoAtual then
		aoMudarPasso(pr.passo)
	end
	local p = passo()
	if not p then
		return
	end
	caixa.quadro.Visible = true
	local t = os.clock()
	-- digitação
	if digitando then
		mostradas += dt * LETRAS_POR_SEGUNDO
		local total = utf8.len(fala.Text) or #fala.Text
		fala.MaxVisibleGraphemes = math.floor(mostradas)
		if t - ultimoBip > 0.09 then
			ultimoBip = t
			Sons.tocar("batida", Workspace, 1.7 + math.random() * 0.3, 0.08)
		end
		if mostradas >= total then
			digitando = false
			fala.MaxVisibleGraphemes = -1
		end
	end
	local ultimaFala = falaAtual >= #p.falas and not digitando
	if ultimaFala and not esperando then
		esperando = true
		desde = t
	end
	-- objetivo cumprido: segue sozinho
	if ultimaFala and p.objetivo ~= "continuar" and cumprido(p) then
		avancar()
	end
	local aguardandoObjetivo = ultimaFala and p.objetivo ~= "continuar"
	local paciente = aguardandoObjetivo and p.paciencia ~= nil and t - desde >= p.paciencia
	objetivoTexto.Text = if aguardandoObjetivo then textoObjetivo(p) else ""
	seguir.placa.quadro.Visible = ultimaFala and (p.objetivo == "continuar" or paciente)
	seguir.rotulo.Text = if p.objetivo == "continuar" and passoAtual == #Dados.PASSOS
		then "Concluir"
		else "Continuar"
	indicador.Visible = not digitando and not ultimaFala
	indicador.Position = UDim2.new(1, -14, 1, -8 - 3 * math.abs(math.sin(t * 5)))
	-- com um painel aberto, a caixa encolhe para o canto e mostra só a dica
	local mini = Navegacao.aberto() ~= nil
	escalaCaixa.Scale = if Escala.toque then 0.88 else 1
	if mini then
		caixa.quadro.AnchorPoint = Vector2.new(0, 1)
		caixa.quadro.Position = UDim2.new(0, 12, 1, -12)
		caixa.quadro.Size = UDim2.fromOffset(470, 96)
		fala.TextSize = 15
	else
		caixa.quadro.AnchorPoint = Vector2.new(0.5, 1)
		caixa.quadro.Position = UDim2.new(
			0.5,
			0,
			1,
			if Escala.toque then -138 elseif Escala.compacto then -150 else -184
		)
		caixa.quadro.Size = UDim2.fromOffset(
			math.min(640, Escala.tamanho.X - 24),
			if Escala.compacto then 122 else 132
		)
		fala.TextSize = if Escala.compacto then 17 else 19
	end
	posicionarDestaque(
		if aguardandoObjetivo or p.objetivo == "continuar" then p.destaque else nil,
		mini
	)
	atualizarSetaDrop(aguardandoObjetivo and p.objetivo == "drop")
	mostrarColuna(passoAtual == Dados.porId.portais)
	if rotuloColuna then
		rotuloColuna.Enabled = not mini
	end
	animarRetrato(t)
end

function Tela.montar(paiRaiz: Frame, hud: GuiObject, aoAviso: (string) -> ())
	raiz = paiRaiz
	hudQuadro = hud
	aviso = aoAviso
	montarCaixa()
	Remotos.evento("DropsMapa").OnClientEvent:Connect(function(dados)
		if type(dados) == "table" and dados.de == Players.LocalPlayer.UserId then
			pegouDrop = true
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok, erro = pcall(quadro, dt)
		if not ok then
			warn("[Tutorial] " .. tostring(erro))
		end
	end)
end

-- Rever o tutorial (Ajustes / Painel Dev)
function Tela.reiniciar()
	task.spawn(Estado.pedir, "TutorialReiniciar")
end

return Tela
