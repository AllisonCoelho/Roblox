-- Câmera cinematográfica do ritual, só para quem girou e só nas raridades altas.
-- Aproxima suavemente pela frente do avatar, treme em ritmo na instabilidade, recua na
-- ruptura e (na categoria Absoluta) dá uma volta em torno do personagem na revelação.
-- A câmera e o personagem SEMPRE voltam ao normal: no fim, ao pular, na morte ou no respawn.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Apresentacao = require(ReplicatedStorage.Shared.Dados.Apresentacao)

local Camera = {}

local encerrarAtual: (() -> ())? = nil

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function Camera.ativa(): boolean
	return encerrarAtual ~= nil
end

function Camera.encerrar()
	if encerrarAtual then
		encerrarAtual()
	end
end

-- cor: tom da raridade usado para tingir a cena. Devolve a função que encerra.
function Camera.tocar(personagem: Model, cat: Apresentacao.Categoria, cor: Color3): () -> ()
	Camera.encerrar()
	local raiz = personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not raiz or not raiz:IsA("BasePart") or not humanoide or not camera then
		return function() end
	end

	local t2 = cat.chamado + cat.ressonancia
	local t3 = t2 + cat.instabilidade
	local t4 = t3 + cat.ruptura
	local fim = t4 + cat.cartao

	local base = raiz.CFrame
	local origem = camera.CFrame
	local inicio = os.clock()

	-- Trava o andar durante a cena (valores restaurados no fim)
	local velocidade, alturaPulo, forcaPulo =
		humanoide.WalkSpeed, humanoide.JumpHeight, humanoide.JumpPower
	humanoide.WalkSpeed, humanoide.JumpHeight, humanoide.JumpPower = 0, 0, 0

	-- Cena levemente mais escura e tingida; sem clarão de tela cheia
	local correcao = Instance.new("ColorCorrectionEffect")
	correcao.Name = "CenaDespertar"
	correcao.Parent = Lighting
	TweenService:Create(correcao, TweenInfo.new(t3), {
		Brightness = -0.18,
		Saturation = -0.35,
		TintColor = Color3.new(1, 1, 1):Lerp(cor, 0.35),
	}):Play()

	camera.CameraType = Enum.CameraType.Scriptable
	local encerrado = false
	local conexoes: { RBXScriptConnection } = {}

	local function encerrar()
		if encerrado then
			return
		end
		encerrado = true
		if encerrarAtual == encerrar then
			encerrarAtual = nil
		end
		for _, c in conexoes do
			c:Disconnect()
		end
		correcao:Destroy()
		camera.CameraType = Enum.CameraType.Custom
		if humanoide.Parent then
			camera.CameraSubject = humanoide
			if humanoide.Health > 0 then
				humanoide.WalkSpeed, humanoide.JumpHeight, humanoide.JumpPower =
					velocidade, alturaPulo, forcaPulo
			end
		end
	end
	encerrarAtual = encerrar

	table.insert(conexoes, humanoide.Died:Connect(encerrar))
	table.insert(
		conexoes,
		personagem.AncestryChanged:Connect(function(_, pai)
			if not pai then
				encerrar()
			end
		end)
	)
	table.insert(
		conexoes,
		RunService.RenderStepped:Connect(function()
			local t = os.clock() - inicio
			if t >= fim or not raiz.Parent then
				encerrar()
				return
			end
			local foco = raiz.Position + Vector3.new(0, 1.2, 0)
			-- Enquadramento: de frente, de baixo para cima, chegando perto até a ruptura
			local aproximacao = suave(t / t3)
			local distancia = 12 - 5 * aproximacao
			local altura = 1.5 - 2.2 * aproximacao
			if t >= t3 then
				-- Recuo no estouro
				distancia += 4 * suave((t - t3) / math.max(cat.ruptura, 0.01))
			end
			local angulo = 0
			if cat.ceu and t > t4 then
				-- Categoria Absoluta: volta completa durante a revelação
				angulo = suave((t - t4) / math.max(cat.cartao - 0.5, 0.5)) * math.pi * 2
			end
			local alvo = (base * CFrame.Angles(0, angulo, 0) * CFrame.new(0, altura, -distancia)).Position
			-- Tremor ritmado, crescente na instabilidade e curto no estouro
			local instavel = if t3 > t2 then math.clamp((t - t2) / (t3 - t2), 0, 1) else 0
			local forca = cat.tremor * instavel
			if t >= t3 and t < t4 + 0.2 then
				forca = cat.tremor * 1.5 * (1 - suave((t - t3) / (cat.ruptura + 0.2)))
			end
			local tremor = Vector3.new(math.sin(t * 47), math.sin(t * 61 + 2), 0) * forca
			local destino = CFrame.lookAt(alvo + tremor, foco)
			-- Sai da câmera do jogador sem corte seco
			camera.CFrame = origem:Lerp(destino, suave(t / 0.45))
			-- Depois do estouro a cena clareia de novo
			if t >= t4 then
				local volta = suave((t - t4) / 0.6)
				correcao.Brightness = -0.18 * (1 - volta)
				correcao.Saturation = -0.35 * (1 - volta)
			end
		end)
	)
	return encerrar
end

return Camera
