-- Vida do mapa no cliente: monta o kit 3D da praça, anima o Núcleo do Despertar (flutua,
-- pulsa, estilhaços, anéis orbitais) e trata as interações por proximidade.
-- Só visual e navegação de interface.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local PetsDados = require(Shared.Dados.Pets)
local Remotos = require(Shared.Remotos)
local UI = script.Parent:WaitForChild("UI")
local Navegacao = require(UI:WaitForChild("Navegacao"))
local Avisos = require(UI:WaitForChild("Telas"):WaitForChild("Avisos"))
local Montagem =
	require(script.Parent:WaitForChild("Mundo"):WaitForChild("Nexo3D"):WaitForChild("Montagem"))
local Estado = require(UI:WaitForChild("Estado"))
local PrimeiroSoberano = require(
	script.Parent:WaitForChild("Mundo"):WaitForChild("NPCs"):WaitForChild("PrimeiroSoberano")
)
local ArenaCorpo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("ArenaCorpo"))
local EcosMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Ecos"))
local CriaturasMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Criaturas"))
local EquipamentoMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Equipamento"))
local CicloMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Ciclo"))
local DropsMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("DropsMapa"))
local CoroaMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Coroa"))
local EventoSolMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("EventoSol"))
local EstatuaMundo = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Estatua"))
local Musica = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Musica"))
local EcosTela = require(UI:WaitForChild("Telas"):WaitForChild("Ecos"))

local K_CIRCULO = 0.5523 -- fator de Bézier para 4 arcos formarem um círculo

local nexo = workspace:WaitForChild("Nexo")
local nucleo = nexo:WaitForChild("Nucleo")
local coracao = nucleo:WaitForChild("Coracao") :: BasePart
local casca = nucleo:WaitForChild("Casca") :: BasePart
local luz = coracao:FindFirstChildOfClass("PointLight")
local centro = coracao.Position
local tamanho = coracao.Size.X
local corBase = coracao.Color

-- Anel de energia feito com 4 Beams curvos em volta de uma peça invisível
local function criarAnel(raio: number, largura: number, cor: Color3): Part
	local base = Instance.new("Part")
	base.Name = "AnelNucleo"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.Transparency = 1
	base.Size = Vector3.new(0.2, 0.2, 0.2)
	local anexos = {}
	for k = 1, 4 do
		local a = (k - 1) * math.pi / 2
		local anexo = Instance.new("Attachment")
		anexo.CFrame = CFrame.fromMatrix(
			Vector3.new(math.cos(a) * raio, 0, math.sin(a) * raio),
			Vector3.new(-math.sin(a), 0, math.cos(a)),
			Vector3.yAxis
		)
		anexo.Parent = base
		anexos[k] = anexo
	end
	for k = 1, 3 do -- 3 arcos: a abertura deixa a rotação visível
		local feixe = Instance.new("Beam")
		feixe.Attachment0 = anexos[k]
		feixe.Attachment1 = anexos[k % 4 + 1]
		feixe.CurveSize0 = K_CIRCULO * raio
		feixe.CurveSize1 = K_CIRCULO * raio
		feixe.Width0, feixe.Width1 = largura, largura
		feixe.Color = ColorSequence.new(cor)
		feixe.Transparency = NumberSequence.new(0.15)
		feixe.LightEmission = 1
		feixe.LightInfluence = 0
		feixe.FaceCamera = true
		feixe.Segments = 14
		feixe.Parent = base
	end
	base.Parent = nucleo
	return base
end

local aneis = {
	{
		parte = criarAnel(7, 0.35, corBase),
		inclinacao = CFrame.Angles(math.rad(70), 0, 0),
		velocidade = 0.5,
	},
	{
		parte = criarAnel(9, 0.25, Color3.fromHex("A855F7")),
		inclinacao = CFrame.Angles(math.rad(40), 0, math.rad(55)),
		velocidade = -0.35,
	},
	{
		parte = criarAnel(11, 0.2, Color3.fromHex("FFC83D")),
		inclinacao = CFrame.Angles(math.rad(-25), 0, math.rad(-60)),
		velocidade = 0.22,
	},
}

-- Estado da reação do Núcleo a auras raras (ver o evento "Despertou" mais abaixo)
local agitadoAte = 0
local corAgitada = corBase

-- Corredor dos Perdidos: as seis ilhas no céu (assets/corredor). A colisão é do servidor
-- (workspace.Corredor); aqui só o visual. Se falhar, as caixas de reserva continuam visíveis.
local corredor: Montagem.ResultadoCorredor? = nil
local function montarCorredor()
	local pastaServidor = workspace:WaitForChild("Corredor", 30)
	if not pastaServidor then
		return
	end
	local ok, resultado = pcall(Montagem.construirCorredor, workspace)
	if not ok then
		warn(
			"[Corredor] kit 3D indisponível; mantendo as caixas de reserva: "
				.. tostring(resultado)
		)
		return
	end
	corredor = resultado
	for _, inst in pastaServidor:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Provisorio") then
			inst.Transparency = 1
		end
	end
end

-- Véus dos portais respiram e as rochas soltas boiam devagar (só perto da câmera)
RunService.Heartbeat:Connect(function()
	local c = corredor
	local camera = workspace.CurrentCamera
	if not c or not camera then
		return
	end
	local t = os.clock()
	local olho = camera.CFrame.Position
	for i, p in c.veus do
		if (p.parte.Position - olho).Magnitude < 260 then
			p.parte.Transparency = 0.3 + 0.12 * math.sin(t * 1.6 + i)
		end
	end
	for i, p in c.deriva do
		if (p.parte.Position - olho).Magnitude < 260 then
			p.parte.CFrame = p.pivo
				* CFrame.new(0, math.sin(t * 0.5 + i * 1.7) * 1.2, 0)
				* CFrame.Angles(0, t * 0.05 + i, 0)
				* CFrame.new(p.centro)
		end
	end
end)

-- Kit 3D da praça (modelado no Blender). Se o motor recusar criar as malhas, o cenário
-- provisório do servidor continua visível: é o fallback temporário desta fase.
local kit: Montagem.Resultado? = nil
nexo:SetAttribute("EstadoKit3D", "Montando")
local etapasProntas: { [string]: boolean } = {}
local function ocultarParte(inst: Instance)
	if inst:IsA("BasePart") and inst:GetAttribute("Provisorio") then
		local etapa = inst:GetAttribute("EtapaKit3D")
		if etapasProntas.Mundo or (etapa == "Praca" and etapasProntas.Praca) then
			inst.LocalTransparencyModifier = 1
		end
	end
end
nexo.DescendantAdded:Connect(function(inst)
	-- Também cobre peças do servidor que chegam depois com instance streaming.
	task.defer(ocultarParte, inst)
end)
local function esconderProvisorio(etapa: string)
	etapasProntas[etapa] = true
	for _, inst in nexo:GetDescendants() do
		ocultarParte(inst)
	end
	coracao.LocalTransparencyModifier = 1
	casca.LocalTransparencyModifier = 1
end

local function iniciarVisual(nome: string, iniciar: () -> ())
	task.defer(function()
		local ok, erro = pcall(iniciar)
		if not ok then
			warn("[Nexo] visual " .. nome .. ": " .. tostring(erro))
		end
	end)
end

-- Os avatares já podem duelar enquanto o mapa carrega.
iniciarVisual("Arena", ArenaCorpo.iniciar)

-- a música não espera o mapa (ninguém fica no silêncio enquanto ele carrega)
task.defer(function()
	local ok, erro = pcall(Musica.iniciar)
	if not ok then
		warn("[Nexo] música: " .. tostring(erro))
	end
end)

task.spawn(function()
	local inicio = os.clock()
	local ok, resultado, falha = pcall(Montagem.construir, nexo, function(parcial, etapa)
		kit = parcial
		esconderProvisorio(etapa)
		local segundos = os.clock() - inicio
		nexo:SetAttribute(
			"EstadoKit3D",
			if etapa == "Praca" then "Praça pronta; montando mundo" else "Carregado"
		)
		nexo:SetAttribute("TempoKit3D" .. etapa, segundos)
		print(string.format("[Nexo] %s pronta em %.2fs", etapa, segundos))
	end)
	if not ok then
		nexo:SetAttribute("EstadoKit3D", "Cenário provisório")
		nexo:SetAttribute("ErroKit3D", tostring(resultado))
		warn(
			"[Nexo] kit 3D indisponível; mantendo o cenário provisório: " .. tostring(resultado)
		)
	else
		kit = resultado
		if falha then
			nexo:SetAttribute("EstadoKit3D", "Praça pronta; mundo provisório")
			nexo:SetAttribute("ErroKit3D", falha)
			warn("[Nexo] preservando a praça 3D; restante provisório: " .. falha)
		end
	end
	-- O mapa tem prioridade sobre as malhas opcionais na entrada.
	-- Uma falha no Soberano não impede Corredor, ciclo, drops ou interações.
	iniciarVisual("Soberano", PrimeiroSoberano.iniciar)
	iniciarVisual("Corredor", montarCorredor)
	iniciarVisual("Ecos", EcosMundo.iniciar)
	iniciarVisual("Criaturas", CriaturasMundo.iniciar)
	iniciarVisual("Equipamento", EquipamentoMundo.iniciar)
	iniciarVisual("Ciclo", CicloMundo.iniciar)
	iniciarVisual("Drops", DropsMundo.iniciar)
	iniciarVisual("Coroa", CoroaMundo.iniciar)
	iniciarVisual("EventoSol", EventoSolMundo.iniciar)
	iniciarVisual("Estatua", EstatuaMundo.iniciar)
end)

local BRANCO = Color3.new(1, 1, 1)

-- Animação do kit: o coração pulsa, os estilhaços respiram e se afastam quando o Núcleo se
-- agita, os fragmentos orbitam e as lanternas flutuam
local function animarKit(
	k: Montagem.Resultado,
	agora: number,
	posicao: Vector3,
	pulso: number,
	agitacao: number
)
	local giro = CFrame.Angles(0, agora * 0.12, 0)
	local tinta = BRANCO:Lerp(corAgitada, 0.6 * agitacao)
	if k.nucleo then
		local n = k.nucleo
		n.parte.Size = n.tamanho * pulso
		n.parte.CFrame = CFrame.new(posicao)
			* CFrame.Angles(0, -agora * 0.4, 0)
			* CFrame.new(n.centro)
		n.parte.Color = tinta
	end
	for i, e in k.estilhacos do
		local d = e.dados.direcao
		local afastar = 0.1 * math.sin(agora * 1.3 + i * 1.7) + 1.8 * agitacao
		e.parte.CFrame = CFrame.new(posicao)
			* giro
			* CFrame.new(e.centro + Vector3.new(d[1], d[2], d[3]) * afastar)
		e.parte.Color = tinta
	end
	for i, o in k.orbitas do
		local d = o.dados
		local a = math.rad(d.fase) + agora * (0.18 + 0.03 * i) * (1 + 3 * agitacao)
		local p = posicao
			+ Vector3.new(
				math.cos(a) * d.raio,
				d.altura + math.sin(agora * 0.9 + i) * 0.6,
				math.sin(a) * d.raio
			)
		o.parte.CFrame = CFrame.new(p)
			* CFrame.Angles(math.rad(d.inclinacao), agora * 0.5 + i, math.rad(20))
			* CFrame.new(o.centro)
	end
	for _, l in k.lanternas do
		local sobe = math.sin(agora * 0.7 + math.rad(l.dados.fase)) * 0.5
		l.parte.CFrame = l.pivo
			* CFrame.new(0, sobe, 0)
			* CFrame.Angles(0, agora * 0.3, 0)
			* CFrame.new(l.centro)
	end
	for i, g in k.giram do
		local velocidade = g.dados.velocidade or 0.2
		g.parte.CFrame = g.pivo
			* CFrame.new(0, math.sin(agora * 0.5 + i) * 0.3, 0)
			* CFrame.Angles(0, agora * velocidade, 0)
			* CFrame.new(g.centro)
	end
end

-- O Núcleo reage quando alguém do servidor desperta uma aura rara
Remotos.evento("Despertou").OnClientEvent:Connect(function(dados: any)
	local aura = if type(dados) == "table" and type(dados.aura) == "string"
		then Auras.porId[dados.aura]
		else nil
	-- Mesmo limiar do anúncio, independentemente de quando o servidor dispara o evento
	if aura and aura.chance >= Auras.ANUNCIO_MINIMO then
		agitadoAte = os.clock() + 4
		corAgitada = Color3.fromHex(Auras.Tiers[aura.tier].cor)
	end
end)

local angulos = { 0, 0, 0 }
local ultimo = os.clock()
RunService.Heartbeat:Connect(function()
	local agora = os.clock()
	local dt = agora - ultimo
	ultimo = agora
	local agitacao = math.clamp((agitadoAte - agora) / 4, 0, 1)
	local k = kit
	local base = if k then k.centroCristal else centro
	local posicao = base + Vector3.new(0, math.sin(agora * 0.8) * 0.8, 0)
	local pulso = 1
		+ 0.05 * math.sin(agora * 2.2)
		+ 0.25 * agitacao * (0.5 + 0.5 * math.sin(agora * 14))
	coracao.CFrame = CFrame.new(posicao)
	coracao.Size = Vector3.one * tamanho * pulso
	coracao.Color = corBase:Lerp(corAgitada, agitacao)
	casca.CFrame = CFrame.new(posicao) * CFrame.Angles(0, agora * 0.3, 0)
	if luz then
		luz.Brightness = 3 + 3 * agitacao
		luz.Color = coracao.Color
	end
	if k then
		animarKit(k, agora, posicao, pulso, agitacao)
	end
	for i, anel in aneis do
		angulos[i] += dt * anel.velocidade * (1 + 5 * agitacao)
		anel.parte.CFrame = CFrame.new(posicao)
			* CFrame.Angles(0, agora * 0.1, 0)
			* anel.inclinacao
			* CFrame.Angles(0, angulos[i], 0)
	end
end)

-- Primeiro Soberano: armadura 3D e repouso (o NPC em si é do servidor)
-- ArenaCorpo: corpo dos jogadores em duelo (todos os clientes veem os mesmos golpes)
Estado.aoMudar(function(estado)
	CriaturasMundo.definir({
		qualidadeBaixa = estado.configuracoes.qualidadeBaixa == true,
		movimentoReduzido = estado.configuracoes.movimentoReduzido == true,
	})
	EcosMundo.definir({
		qualidadeBaixa = estado.configuracoes.qualidadeBaixa == true,
		movimentoReduzido = estado.configuracoes.movimentoReduzido == true,
	})
	-- Núcleos acesos no Cristal: os que a pessoa já pode abrir
	local corredor = (estado :: any).corredor
	local liberados: { [number]: boolean } = {}
	for i, nucleo in PetsDados.NUCLEOS do
		liberados[i] = PetsDados.nucleoLiberado(nucleo, corredor)
	end
	EcosMundo.definirLiberados(liberados)
	PrimeiroSoberano.definir({
		qualidadeBaixa = estado.configuracoes.qualidadeBaixa == true,
		movimentoReduzido = estado.configuracoes.movimentoReduzido == true,
	})
	ArenaCorpo.definir({ movimentoReduzido = estado.configuracoes.movimentoReduzido == true })
	EventoSolMundo.definir({ movimentoReduzido = estado.configuracoes.movimentoReduzido == true })
	Musica.definir((estado.configuracoes :: any).musica ~= false)
end)

-- Interações do mapa
ProximityPromptService.PromptTriggered:Connect(function(prompt, jogador)
	if jogador ~= Players.LocalPlayer then
		return
	end
	local acao = prompt:GetAttribute("Acao")
	if acao == "indice" then
		Navegacao.abrir("Indice")
	elseif acao == "altar" then
		Navegacao.abrir("Altar")
	elseif acao == "incursoes" then
		Navegacao.abrir("Incursoes")
	elseif acao == "corredor" then
		Navegacao.abrir("Corredor")
	elseif acao == "baus" then
		Navegacao.abrir("Baus")
	elseif acao == "nucleos" then
		EcosTela.abrir("Nucleos")
	elseif acao == "em_construcao" or acao == "eco" then
		local texto = prompt:GetAttribute("Texto")
		if type(texto) == "string" then
			-- A interface pode ainda estar carregando no primeiro segundo de jogo
			pcall(Avisos.toast, texto)
		end
	end
end)
