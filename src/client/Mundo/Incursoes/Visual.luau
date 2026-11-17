-- Visual das Incursões neste cliente. O servidor cria caixas com o atributo "Kit" (medidas das
-- peças do Blender); aqui cada caixa ganha a aparência final:
--   1) se existir um modelo importado no Studio em ReplicatedStorage.IncursoesModelos com o MESMO
--      nome do Kit (ex.: "inc_cinzas_sombra"), ele é usado (com ossos animados por código);
--   2) senão, a malha do kit vem dos Dados/ (EditableMesh), como o Nexo.
-- Também desenha o Pulso, o aviso do golpe do Guardião, o progresso dos Núcleos e o clima de
-- cada universo. Só imagem: o servidor decide tudo.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Incursoes = require(Shared.Dados.Incursoes)
local Kit = require(Shared.Dados.IncursoesKit)
local Malha = require(script.Parent.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))
local Ossos = require(script.Parent.Ossos)

local Visual = {}

local cache: Malha.Cache = {} -- malhas convertidas uma vez e reaproveitadas
local BRANCO = Color3.new(1, 1, 1)

type Vivo = {
	parte: BasePart,
	nome: string,
	pivoLocal: CFrame, -- da caixa até o pé da peça
	visual: { BasePart }, -- malhas (kit) ou partes do modelo importado
	deslocamentos: { CFrame }, -- de pé da peça até cada malha
	luz: BasePart?,
	modelo: Model?,
	ossos: Ossos.Rig?,
	movel: boolean,
	ultimaPos: Vector3,
	fase: number,
	morreuEm: number?,
	feridoEm: number,
	ataqueEm: number,
	conexoes: { RBXScriptConnection },
}

local vivos: { [BasePart]: Vivo } = {}
local efeitos = Instance.new("Folder")
efeitos.Name = "IncursoesEfeitos"
local raiz: Instance? = nil
local slotAtual: number? = nil
local fila: { BasePart } = {}
local naFila: { [BasePart]: boolean } = {}
local processando = false

local function naPartida(parte: BasePart): boolean
	local pasta = if raiz and slotAtual then raiz:FindFirstChild("Partida" .. slotAtual) else nil
	return pasta ~= nil and parte:IsDescendantOf(pasta)
end

local function desmontar(v: Vivo)
	vivos[v.parte] = nil
	for _, c in v.conexoes do
		c:Disconnect()
	end
	if v.parte.Parent then
		v.parte.LocalTransparencyModifier = 0
	end
	if v.modelo then
		v.modelo:Destroy()
	else
		for _, p in v.visual do
			p:Destroy()
		end
	end
end

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function modeloImportado(nome: string): Model?
	local pasta = ReplicatedStorage:FindFirstChild("IncursoesModelos")
	local m = pasta and pasta:FindFirstChild(nome)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function montar(parte: BasePart)
	if vivos[parte] or not naPartida(parte) then
		return
	end
	local nome = parte:GetAttribute("Kit")
	local d = if type(nome) == "string" then Kit.pecas[nome] else nil
	if not d then
		return
	end
	local escala = parte:GetAttribute("Escala") or 1
	local pivoLocal = CFrame.new(-vec(d.centro) * escala)
	local pe = parte.CFrame * pivoLocal
	local v: Vivo = {
		parte = parte,
		nome = nome,
		pivoLocal = pivoLocal,
		visual = {},
		deslocamentos = {},
		luz = nil,
		modelo = nil,
		ossos = nil,
		movel = parte:GetAttribute("Movel") == true,
		ultimaPos = parte.Position,
		fase = math.random() * 10,
		morreuEm = nil,
		feridoEm = -1,
		ataqueEm = -1,
		conexoes = {},
	}
	local cor = parte:GetAttribute("CorLuz")
	local corLuz = if typeof(cor) == "Color3" then cor else BRANCO

	local ok, erro = pcall(function()
		local importado = modeloImportado(nome)
		if importado then
			local m = importado:Clone()
			v.modelo = m
			-- encaixe automático, seja qual for a escala do importador: mesma altura da peça do kit,
			-- pés no chão e virado para a frente (atributo "Giro", em graus, corrige se vier de costas)
			local giro = m:GetAttribute("Giro")
			m:PivotTo(
				pe * CFrame.Angles(0, math.rad(if type(giro) == "number" then giro else 0), 0)
			)
			local _, tam = m:GetBoundingBox()
			local alvo = d.tamanho[2] * escala * (m:GetAttribute("Escala") or 1)
			if tam.Y > 0.01 then
				m:ScaleTo(m:GetScale() * alvo / tam.Y)
			end
			local caixa, tam2 = m:GetBoundingBox()
			local pes = caixa.Position - Vector3.new(0, tam2.Y / 2, 0)
			m:PivotTo(m:GetPivot() + (pe.Position - pes))
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					table.insert(v.visual, p)
					table.insert(v.deslocamentos, pe:ToObjectSpace(p.CFrame))
					if p.Material == Enum.Material.Neon then
						p.Color = corLuz
					end
				end
			end
			m.Parent = efeitos
			v.ossos = Ossos.ligar(m)
		else
			local malha, centro = Malha.criar(nome, cache)
			malha.Material = (Enum.Material :: any)[d.material] or Enum.Material.Slate
			malha.Size = malha.Size * escala
			malha.CastShadow = not v.movel
			malha.Parent = efeitos
			table.insert(v.visual, malha)
			table.insert(v.deslocamentos, CFrame.new(centro * escala))
			local nomeLuz = nome .. "_luz"
			if Kit.pecas[nomeLuz] then
				local luz, centroLuz = Malha.criar(nomeLuz, cache)
				luz.Material = Enum.Material.Neon
				luz.Color = corLuz
				luz.Size = luz.Size * escala
				luz.CastShadow = false
				luz.Parent = efeitos
				table.insert(v.visual, luz)
				table.insert(v.deslocamentos, CFrame.new(centroLuz * escala))
				v.luz = luz
			end
		end
	end)
	if not ok or not naPartida(parte) then
		desmontar(v)
		if not ok then
			warn("[Incursoes] malha " .. nome .. " indisponível: " .. tostring(erro))
		end
		return
	end
	for i, p in v.visual do
		p.CFrame = pe * v.deslocamentos[i]
	end
	parte.LocalTransparencyModifier = 1
	vivos[parte] = v

	local function aoMudar(atributo: string, fn: () -> ())
		table.insert(v.conexoes, parte:GetAttributeChangedSignal(atributo):Connect(fn))
	end
	aoMudar("Morreu", function()
		v.morreuEm = os.clock()
	end)
	aoMudar("Ferido", function()
		v.feridoEm = os.clock()
	end)
	aoMudar("Ataque", function()
		v.ataqueEm = os.clock()
	end)
	aoMudar("Golpe", function()
		local quando = parte:GetAttribute("Golpe")
		local raio = parte:GetAttribute("GolpeRaio")
		if type(quando) == "number" and type(raio) == "number" then
			Visual.avisoGolpe(parte, raio, quando - Workspace:GetServerTimeNow(), corLuz)
		end
	end)
	-- nome sobre Elites e inimigos especiais (Corredor, Atirador, Explosivo, Escudeiro)
	local rotulo = parte:GetAttribute("Rotulo")
	if type(rotulo) == "string" then
		local elite = parte:GetAttribute("Elite") == true
		local bb = Instance.new("BillboardGui")
		bb.Name = "Rotulo"
		bb.Adornee = parte
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(if elite then 260 else 150, if elite then 46 else 28)
		bb.StudsOffsetWorldSpace = Vector3.new(0, parte.Size.Y * 0.75 + 1.5, 0)
		bb.MaxDistance = if elite then 140 else 70
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = (if elite then "👑 " else "") .. rotulo
		t.TextColor3 = if elite then Color3.fromHex("FFD36B") else corLuz
		t.TextStrokeTransparency = 0.25
		t.Parent = bb
		bb.Parent = parte
	end
	-- Atirador: risco vermelho até o ponto mirado, depois o disparo (dá para sair da mira)
	aoMudar("MiraEm", function()
		local para = parte:GetAttribute("Mira")
		local quando = parte:GetAttribute("MiraEm")
		if typeof(para) ~= "Vector3" or type(quando) ~= "number" then
			return
		end
		local espera = math.max(quando - Workspace:GetServerTimeNow(), 0.05)
		local de = (parte.CFrame * pivoLocal).Position + Vector3.new(0, 2.5, 0)
		local alvo = para - Vector3.new(0, 2, 0)
		local risco = Instance.new("Part")
		risco.Anchored = true
		risco.CanCollide = false
		risco.CanQuery = false
		risco.CanTouch = false
		risco.CastShadow = false
		risco.Material = Enum.Material.Neon
		risco.Color = Color3.fromHex("FF3344")
		risco.Transparency = 0.5
		local comp = (alvo - de).Magnitude
		risco.Size = Vector3.new(0.15, 0.15, comp)
		risco.CFrame = CFrame.lookAt((de + alvo) / 2, alvo)
		risco.Parent = efeitos
		local marca = Instance.new("Part")
		marca.Shape = Enum.PartType.Cylinder
		marca.Anchored = true
		marca.CanCollide = false
		marca.CanQuery = false
		marca.CanTouch = false
		marca.CastShadow = false
		marca.Material = Enum.Material.Neon
		marca.Color = Color3.fromHex("FF3344")
		marca.Transparency = 0.55
		marca.Size = Vector3.new(0.12, 6.4, 6.4)
		marca.CFrame = CFrame.new(alvo + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		marca.Parent = efeitos
		task.delay(espera, function()
			risco.Color = corLuz
			risco.Transparency = 0
			risco.Size = Vector3.new(0.6, 0.6, comp)
			Visual.onda(alvo, 3.4, corLuz, 0.3)
			TweenService:Create(risco, TweenInfo.new(0.2), { Transparency = 1 }):Play()
			task.delay(0.25, function()
				risco:Destroy()
				marca:Destroy()
			end)
		end)
	end)
	aoMudar("Piscou", function()
		Visual.onda((parte.CFrame * pivoLocal).Position, 6, corLuz, 0.4)
	end)
	aoMudar("Impacto", function()
		local raio = parte:GetAttribute("GolpeRaio")
		Visual.onda(
			(parte.CFrame * pivoLocal).Position,
			if type(raio) == "number" then raio else 14,
			corLuz,
			0.5
		)
	end)
	table.insert(
		v.conexoes,
		parte.AncestryChanged:Connect(function()
			if not naPartida(parte) then
				desmontar(v)
			end
		end)
	)
end

-- Anel que se abre no chão (Pulso, impacto do Guardião)
function Visual.onda(centro: Vector3, raio: number, cor: Color3, duracao: number)
	local anel = Instance.new("Part")
	anel.Shape = Enum.PartType.Cylinder
	anel.Anchored = true
	anel.CanCollide = false
	anel.CanQuery = false
	anel.CanTouch = false
	anel.CastShadow = false
	anel.Material = Enum.Material.Neon
	anel.Color = cor
	anel.Transparency = 0.2
	anel.Size = Vector3.new(0.2, 2, 2)
	anel.CFrame = CFrame.new(centro + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	anel.Parent = efeitos
	local tw = TweenService:Create(
		anel,
		TweenInfo.new(duracao, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.2, raio * 2, raio * 2),
			Transparency = 1,
		}
	)
	tw:Play()
	tw.Completed:Once(function()
		anel:Destroy()
	end)
end

-- Círculo de aviso que enche até o golpe do Guardião
function Visual.avisoGolpe(parte: BasePart, raio: number, tempo: number, cor: Color3)
	if tempo <= 0 then
		return
	end
	local v = vivos[parte]
	local centro = if v then (parte.CFrame * v.pivoLocal).Position else parte.Position
	local borda = Instance.new("Part")
	borda.Shape = Enum.PartType.Cylinder
	borda.Anchored = true
	borda.CanCollide = false
	borda.CanQuery = false
	borda.CanTouch = false
	borda.CastShadow = false
	borda.Material = Enum.Material.Neon
	borda.Color = Color3.fromHex("FF3344")
	borda.Transparency = 0.75
	borda.Size = Vector3.new(0.12, raio * 2, raio * 2)
	borda.CFrame = CFrame.new(centro + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	borda.Parent = efeitos
	local enche = borda:Clone()
	enche.Color = cor
	enche.Transparency = 0.45
	enche.Size = Vector3.new(0.14, 1, 1)
	enche.Parent = efeitos
	local tw = TweenService:Create(enche, TweenInfo.new(tempo, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.14, raio * 2, raio * 2),
	})
	tw:Play()
	task.delay(tempo, function()
		borda:Destroy()
		enche:Destroy()
	end)
end

-- Clima do universo enquanto o jogador está numa incursão (só neste cliente)
local CLIMA = {
	cinzas = {
		tinta = Color3.fromHex("FFD2BF"),
		atmosfera = Color3.fromHex("8A3A22"),
		brilho = -0.02,
	},
	mare = {
		tinta = Color3.fromHex("CFE6FF"),
		atmosfera = Color3.fromHex("1E4E78"),
		brilho = -0.04,
	},
	umbral = {
		tinta = Color3.fromHex("E2CCFF"),
		atmosfera = Color3.fromHex("4A2A7A"),
		brilho = -0.06,
	},
}
local climaAtual: { Instance } = {}

-- Zona de ataque do Guardião: anel vermelho que enche até o golpe. interno > 0: o meio é seguro
function Visual.zona(pos: Vector3, raio: number, interno: number, tempo: number, cor: Color3)
	if tempo <= 0 then
		return
	end
	local function disco(r: number, c: Color3, transp: number, grossura: number): Part
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = c
		p.Transparency = transp
		p.Size = Vector3.new(grossura, r * 2, r * 2)
		p.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = efeitos
		return p
	end
	local borda = disco(raio, Color3.fromHex("FF3344"), 0.7, 0.12)
	local enche = disco(math.max(interno, 0.5), cor, 0.45, 0.14)
	local seguro = if interno > 0 then disco(interno, Color3.fromHex("6BFFB0"), 0.55, 0.16) else nil
	TweenService:Create(enche, TweenInfo.new(tempo, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.14, raio * 2, raio * 2),
	}):Play()
	task.delay(tempo, function()
		borda:Destroy()
		enche:Destroy()
		if seguro then
			seguro:Destroy()
		end
		Visual.onda(pos, raio, cor, 0.35)
	end)
end

-- Escuridão do Eclipse (Espectro do Ocaso a partir da fase 2)
local eclipse: ColorCorrectionEffect? = nil
function Visual.eclipse(ligado: boolean)
	if ligado and not eclipse then
		local e = Instance.new("ColorCorrectionEffect")
		e.Name = "IncursaoEclipse"
		e.Brightness = -0.18
		e.Saturation = -0.35
		e.TintColor = Color3.fromHex("C9B8FF")
		e.Parent = Lighting
		eclipse = e
	elseif not ligado and eclipse then
		eclipse:Destroy()
		eclipse = nil
	end
end

function Visual.clima(universo: string?)
	for _, inst in climaAtual do
		inst:Destroy()
	end
	table.clear(climaAtual)
	local c = universo and CLIMA[universo]
	if not c then
		return
	end
	local cor = Instance.new("ColorCorrectionEffect")
	cor.Name = "IncursaoCor"
	cor.TintColor = c.tinta
	cor.Brightness = c.brilho
	cor.Contrast = 0.1
	cor.Parent = Lighting
	table.insert(climaAtual, cor)
	local fumaca = Instance.new("Atmosphere")
	fumaca.Name = "IncursaoAtmosfera"
	fumaca.Density = 0.42
	fumaca.Color = c.atmosfera
	fumaca.Decay = c.atmosfera:Lerp(Color3.new(), 0.6)
	fumaca.Haze = 2.5
	-- a atmosfera do Nexo volta quando esta sai
	local nexo = Lighting:FindFirstChildOfClass("Atmosphere")
	if nexo and nexo ~= fumaca then
		nexo.Parent = nil
		table.insert(climaAtual, fumaca)
		local devolver = Instance.new("ObjectValue")
		devolver.Name = "IncursaoDevolve"
		devolver.Value = nexo
		devolver.Destroying:Connect(function()
			nexo.Parent = Lighting
		end)
		table.insert(climaAtual, devolver)
	else
		table.insert(climaAtual, fumaca)
	end
	fumaca.Parent = Lighting
end

local function animar(dt: number)
	local agora = os.clock()
	for parte, v in vivos do
		local pe = parte.CFrame * v.pivoLocal
		local extra = CFrame.identity
		local escalaVis = 1
		local passo = 0
		if v.movel then
			local vel = (parte.Position - v.ultimaPos).Magnitude / math.max(dt, 1 / 240)
			v.ultimaPos = parte.Position
			passo = math.clamp(vel / 10, 0, 1)
			v.fase += dt * (2 + 6 * passo)
			-- balanço de andar e respiração (malhas do kit); o modelo importado usa os ossos
			if not v.ossos then
				extra = CFrame.new(0, math.abs(math.sin(v.fase)) * 0.25 * passo, 0)
					* CFrame.Angles(
						math.rad(6) * passo + math.rad(1.5) * math.sin(agora * 2),
						0,
						math.rad(4) * math.sin(v.fase) * passo
					)
			end
			local at = agora - v.ataqueEm
			if at < 0.35 then
				extra = extra * CFrame.new(0, 0, -1.2 * math.sin(at / 0.35 * math.pi))
			end
			if v.morreuEm then
				local t = math.clamp((agora - v.morreuEm) / 0.55, 0, 1)
				escalaVis = 1 - t
				extra = extra * CFrame.new(0, -t * 1.5, 0)
			end
		end
		if v.ossos then
			Ossos.animar(
				v.ossos,
				dt,
				passo,
				agora - v.ataqueEm,
				v.morreuEm and (agora - v.morreuEm) or nil
			)
		end
		local base = pe * extra
		for i, p in v.visual do
			local d = v.deslocamentos[i]
			if escalaVis < 1 then
				d = CFrame.new(d.Position * escalaVis) * d.Rotation
			end
			p.CFrame = base * d
			if v.morreuEm then
				p.Transparency = 1 - escalaVis
			end
		end
		-- luz: Núcleo pelo progresso; inimigo pisca ao ser ferido; fenda pulsa
		local luz = v.luz
		if luz then
			local cor = parte:GetAttribute("CorLuz")
			local base3 = if typeof(cor) == "Color3" then cor else BRANCO
			if parte:GetAttribute("Nucleo") then
				local prog = parte:GetAttribute("Progresso") or 0
				local corrompido = base3:Lerp(Color3.new(), 0.45)
				local puro = Color3.fromHex("E9FBFF")
				luz.Color = corrompido:Lerp(puro, prog)
				local contestado = parte:GetAttribute("Contestado") == true
				luz.Transparency = if prog >= 1
					then 0
					else 0.15 + 0.15 * math.sin(agora * (if contestado then 14 else 3))
			elseif agora - v.feridoEm < 0.15 then
				luz.Color = BRANCO
			else
				luz.Color = base3
				if parte:GetAttribute("Fenda") then
					luz.Transparency = 0.1 + 0.15 * math.sin(agora * 4)
				end
			end
		end
	end
end

local function adicionar(inst: Instance)
	if
		not inst:IsA("BasePart")
		or not inst:GetAttribute("Kit")
		or not naPartida(inst)
		or naFila[inst]
		or vivos[inst]
	then
		return
	end
	naFila[inst] = true
	table.insert(fila, inst)
	if processando then
		return
	end
	processando = true
	task.defer(function()
		while #fila > 0 do
			local parte = table.remove(fila, 1)
			local ok, erro = pcall(montar, parte)
			naFila[parte] = nil
			if not ok then
				warn("[Incursoes] falha ao montar peça: " .. tostring(erro))
			end
		end
		processando = false
	end)
end

local function carregarPartida()
	local pasta = if raiz and slotAtual then raiz:FindFirstChild("Partida" .. slotAtual) else nil
	if pasta then
		for _, inst in pasta:GetDescendants() do
			adicionar(inst)
		end
	end
end

function Visual.definirPartida(slot: number?)
	if slotAtual == slot then
		return
	end
	slotAtual = slot
	Visual.eclipse(false)
	table.clear(fila)
	table.clear(naFila)
	for _, v in table.clone(vivos) do
		desmontar(v)
	end
	carregarPartida()
end

function Visual.iniciar()
	efeitos.Parent = Workspace
	local pasta = Workspace:WaitForChild("Incursoes")
	raiz = pasta
	pasta.DescendantAdded:Connect(adicionar)
	carregarPartida()
	RunService.RenderStepped:Connect(animar)
end

-- Pulso de um jogador (evento do servidor)
function Visual.pulso(origem: Vector3, raio: number, universo: string?)
	local u = universo and Incursoes.porId[universo]
	local cor = if u then Color3.fromHex(u.corVeio) else BRANCO
	Visual.onda(origem - Vector3.new(0, 2.5, 0), raio, cor, 0.35)
	Visual.onda(origem - Vector3.new(0, 2.5, 0), raio * 0.6, BRANCO, 0.25)
end

return Visual
