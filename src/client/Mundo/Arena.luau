-- Câmera e efeitos do desafiante. O resultado de cada golpe já veio do servidor.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Dados = require(Shared.Dados.Arena)
local Cena = require(Shared.Dados.ArenaCena)

local Arena = {}
local VIOLETA = Color3.fromHex("C0ADFF")
local RUBRO = Color3.fromHex("FF735D")
local MENTA = Color3.fromHex("B7FFD9")
local FonteNumeros = require(Shared.Tema).FonteNumeros

export type Opcoes = {
	movimentoReduzido: boolean,
	qualidadeBaixa: boolean,
	cor: Color3,
	estilo: string?,
	lado: string?, -- 1x1 entre jogadores: "a" (posto do desafiante) ou "b" (posto do outro)
}

-- Referencial da câmera: quem luta do lado "b" vê o ringue espelhado (ele mesmo à esquerda)
local referencia = Cena.referencia

local function enquadrar(lateral: boolean, estreito: boolean): (CFrame, CFrame, number)
	local posicao = if lateral
		then Vector3.new(5, 6.3, -15)
		elseif estreito then Vector3.new(12, 11, -23)
		else Vector3.new(12, 10, -21)
	local centro = if lateral then Vector3.new(0, 4.8, 0) else Vector3.new(0, 5.2, 2.8)
	local foco = referencia * CFrame.new(centro)
	local camera = CFrame.lookAt(referencia:PointToWorldSpace(posicao), foco.Position)
	return camera, foco, if estreito then 68 elseif lateral then 53 else 56
end

local function neon(pai: Instance, cor: Color3, cf: CFrame, tamanho: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = cor
	p.CFrame = cf
	p.Size = tamanho
	p.Parent = pai
	Debris:AddItem(p, 1.4)
	return p
end

local function dissipar(p: Part, duracao: number, propriedades: { [string]: any })
	propriedades.Transparency = 1
	TweenService:Create(p, TweenInfo.new(duracao, Enum.EasingStyle.Quad), propriedades):Play()
end

local function anel(pai: Instance, centro: CFrame, cor: Color3, tamanho: number)
	local n = neon(pai, cor, centro * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.06, 1, 1))
	n.Shape = Enum.PartType.Cylinder
	n.Transparency = 0.48
	dissipar(n, 0.46, { Size = Vector3.new(0.06, tamanho, tamanho) })
end

local function danoFlutuante(pai: Instance, alvo: CFrame, golpe: Dados.Golpe, cor: Color3)
	-- o Soberano é alto; no 1x1 os dois são jogadores
	local altura = if (golpe :: any).lado then 5.6 elseif golpe.ator == "jogador" then 8.4 else 5.6
	local ponto = neon(pai, cor, alvo * CFrame.new(0.6, altura, 0), Vector3.one * 0.1)
	ponto.Transparency = 1
	local letreiro = Instance.new("BillboardGui")
	letreiro.Size = UDim2.fromOffset(120, 50)
	letreiro.AlwaysOnTop = true
	letreiro.LightInfluence = 0
	letreiro.Parent = ponto
	local valor = Instance.new("TextLabel")
	valor.BackgroundTransparency = 1
	valor.Size = UDim2.fromScale(1, 1)
	valor.FontFace = FonteNumeros
	valor.TextSize = 28
	valor.Text = "−" .. golpe.dano
	valor.TextColor3 = cor:Lerp(Color3.new(1, 1, 1), 0.5)
	valor.TextStrokeTransparency = 0.25
	valor.Parent = letreiro
	TweenService:Create(letreiro, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
		StudsOffsetWorldSpace = Vector3.new(0, 1.05, 0),
	}):Play()
	TweenService:Create(
		valor,
		TweenInfo.new(0.23, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.34),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	):Play()
end

local function impacto(pai: Instance, golpe: Dados.Golpe, op: Opcoes)
	local doJogador = golpe.ator == "jogador"
	-- no 1x1, o lado diz onde cada um está; contra o Soberano, o jogador está sempre no posto "a"
	local ladoGolpe = (golpe :: any).lado
	local deA = if ladoGolpe then ladoGolpe == "a" else doJogador
	local alvo = if deA then Cena.soberano else Cena.jogador
	local origem = if deA then Cena.jogador else Cena.soberano
	local cor = if not doJogador then RUBRO elseif golpe.id == "despertar" then op.cor else VIOLETA
	if golpe.dano > 0 and not op.movimentoReduzido then
		danoFlutuante(pai, alvo, golpe, cor)
	end
	if golpe.id == "guarda" or golpe.id == "baluarte" then
		anel(pai, origem + Vector3.new(0, 0.18, 0), if doJogador then MENTA else RUBRO, 7)
		return
	end
	if op.qualidadeBaixa or op.movimentoReduzido or not golpe.especial then
		anel(pai, alvo + Vector3.new(0, 0.26, 0), cor, 5)
		return
	end
	local escala = if golpe.id == "despertar" then 1.35 else 1
	if golpe.id == "despertar" or golpe.id == "selo" then
		anel(pai, alvo + Vector3.new(0, 0.22, 0), cor, 10 * escala)
		if op.estilo == "nevoa" and golpe.id == "despertar" then
			return
		end
	end

	local centro = alvo * CFrame.new(0, if deA and not ladoGolpe then 4.4 else 2.8, -1)
	local inclina = if golpe.id == "pesado" then math.rad(50) else math.rad(-14)
	centro *= CFrame.Angles(0, 0, inclina)
	for i = 1, 8 do
		local a = (i - 1) / 8 * math.pi
		local b = i / 8 * math.pi
		local p = centro:PointToWorldSpace(
			Vector3.new(math.cos(a) * 4 * escala, 0, -math.sin(a) * 2.8 * escala)
		)
		local q = centro:PointToWorldSpace(
			Vector3.new(math.cos(b) * 4 * escala, 0, -math.sin(b) * 2.8 * escala)
		)
		local trecho = neon(
			pai,
			cor,
			CFrame.lookAt((p + q) / 2, q),
			Vector3.new(0.09, 0.16, (p - q).Magnitude + 0.06)
		)
		dissipar(trecho, 0.28 + i / 60, {})
	end
end

export type Controle = {
	tocar: (Dados.Golpe, number, number) -> (),
	encerrar: () -> (),
}

function Arena.iniciar(op: Opcoes): Controle
	referencia = if op.lado == "b"
		then Cena.referencia * CFrame.Angles(0, math.pi, 0)
		else Cena.referencia
	local camera = workspace.CurrentCamera
	local tipoAnterior = if camera then camera.CameraType else Enum.CameraType.Custom
	local fovAnterior = if camera then camera.FieldOfView else 70
	local focusAnterior = if camera then camera.Focus else CFrame.identity
	local cfAnterior = if camera then camera.CFrame else CFrame.identity
	local efeito = Instance.new("Folder")
	efeito.Name = "EfeitosArena"
	efeito.Parent = workspace
	local morto = false
	local lateral = false
	local ultimo = 0
	local trocarAte = 0
	local tremor = 0 -- força do tremor da câmera (cai rápido)

	if camera then
		local destino, foco, fov =
			enquadrar(false, camera.ViewportSize.X < camera.ViewportSize.Y * 1.35)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = destino
		camera.Focus = foco
		camera.FieldOfView = fov
	end
	local render = RunService.RenderStepped:Connect(function(dt)
		if not camera or camera ~= workspace.CurrentCamera then
			return
		end
		local destino, foco, fov =
			enquadrar(lateral, camera.ViewportSize.X < camera.ViewportSize.Y * 1.35)
		local passo = if workspace:GetServerTimeNow() < trocarAte and lateral
			then 1
			else math.min(1, dt * (if op.movimentoReduzido then 12 else 8))
		tremor = math.max(0, tremor - dt * 3.2)
		local abalo = if tremor > 0
			then CFrame.new(
				math.noise(os.clock() * 31, 0.3) * tremor,
				math.noise(0.7, os.clock() * 29) * tremor,
				0
			)
			else CFrame.identity
		camera.CFrame = camera.CFrame:Lerp(destino, passo) * abalo
		camera.Focus = foco
		camera.FieldOfView += (fov - camera.FieldOfView) * passo
	end)

	return {
		tocar = function(golpe, instante, fim)
			ultimo += 1
			local token = ultimo
			local agora = workspace:GetServerTimeNow()
			lateral = golpe.especial and not op.movimentoReduzido
			trocarAte = agora + 0.11
			task.delay(math.max(0, instante - agora), function()
				if morto or ultimo ~= token then
					return
				end
				if not op.movimentoReduzido and golpe.dano > 0 then
					tremor = math.max(
						tremor,
						if golpe.id == "pesado" or golpe.id == "despertar"
							then 0.55
							elseif golpe.especial then 0.32
							else 0.18
					)
				end
				impacto(efeito, golpe, op)
			end)
			task.delay(math.max(0, fim - agora), function()
				if not morto and ultimo == token then
					lateral = false
				end
			end)
		end,
		encerrar = function()
			morto = true
			render:Disconnect()
			efeito:Destroy()
			if camera and camera == workspace.CurrentCamera then
				camera.FieldOfView = fovAnterior
				camera.CFrame = cfAnterior
				camera.Focus = focusAnterior
				camera.CameraType = tipoAnterior
			end
		end,
	}
end

return Arena
