-- Combate das Incursões no cliente: teclas, previsão de recarga, dash, guarda e a barra de
-- habilidades. O cliente só pede; o servidor (src/server/Incursoes/Combate) confere e aplica o dano.
--
-- PC: M1 golpe (combo de 3) · 1 e 2 técnicas · R Despertar · Shift esquiva · F (segurar) guarda.
-- Q continua sendo o Pulso. Controle: R2 golpe · X/Y técnicas · R1 Despertar · L1 esquiva · L2 guarda.
-- Celular: botões na barra.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dados = require(Shared.Dados.Combate)
local Tema = require(Shared.Tema)
local Kit = require(script.Parent.Parent.Kit)
local Estado = require(script.Parent.Parent.Estado)
local EfeitosCombate = require(
	script.Parent.Parent.Parent
		:WaitForChild("Mundo")
		:WaitForChild("Incursoes")
		:WaitForChild("EfeitosCombate")
)

local Cores = Tema.Orbita
local Combate = {}

local ativo = false
local recargas: { [string]: number } = {}
local proximoDash = 0
local guardando = false
local guardaBloqueadaAte = 0
local medidor = 0
local despertarAte = 0 -- tempo do servidor
local barra: Frame
local slots: { [string]: { recarga: Frame, rotulo: TextLabel } } = {}
local medidorFill: Frame
local medidorTexto: TextLabel

local function kitAtual(): Dados.Kit
	local c = Players.LocalPlayer.Character
	return Dados.kitDe(if c then c:GetAttribute("AuraVfx") else nil)
end

local function raiz(): (BasePart?, Humanoid?)
	local c = Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if r and r:IsA("BasePart") and h and h.Health > 0 then
		return r, h
	end
	return nil, nil
end

-- Direção do ataque: para onde a câmera olha (no plano); o personagem vira para lá
local function mirar(): Vector3?
	local r = raiz()
	local cam = Workspace.CurrentCamera
	if not r or not cam then
		return nil
	end
	local l = cam.CFrame.LookVector
	local dir = Vector3.new(l.X, 0, l.Z)
	if dir.Magnitude < 1e-3 then
		dir = r.CFrame.LookVector
	end
	dir = dir.Unit
	r.CFrame = CFrame.lookAt(r.Position, r.Position + dir)
	return dir
end

local function pedir(acao: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		Estado.pedir(acao, table.unpack(args, 1, args.n))
	end)
end

local function usar(id: string)
	if not ativo then
		return
	end
	local kit = kitAtual()
	local t = kit.tecnicas[id]
	local agora = os.clock()
	if not t or agora < (recargas[id] or 0) then
		return
	end
	if id == "despertar" and medidor < Dados.MEDIDOR_MAX then
		return
	end
	local dir = mirar()
	if not dir then
		return
	end
	recargas[id] = agora + t.recarga
	if id == "despertar" then
		medidor = 0
	end
	if guardando then
		guardando = false
	end
	pedir("IncursaoTecnica", id, dir)
end

local function esquivar()
	if not ativo or os.clock() < proximoDash then
		return
	end
	local r, h = raiz()
	if not r or not h then
		return
	end
	proximoDash = os.clock() + Dados.DASH_RECARGA
	local dir = h.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = r.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local kit = kitAtual()
	-- o personagem é do cliente: o empurrão do dash é aplicado aqui
	local a = Instance.new("Attachment")
	a.Parent = r
	local v = Instance.new("LinearVelocity")
	v.Attachment0 = a
	v.MaxForce = math.huge
	v.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	v.PrimaryTangentAxis = Vector3.xAxis
	v.SecondaryTangentAxis = Vector3.zAxis
	v.PlaneVelocity = Vector2.new(dir.X, dir.Z) * (kit.dash.distancia / 0.2)
	v.RelativeTo = Enum.ActuatorRelativeTo.World
	v.Parent = r
	task.delay(0.2, function()
		v:Destroy()
		a:Destroy()
	end)
	pedir("IncursaoEsquiva", dir)
end

local function guardar(ligar: boolean)
	if not ativo then
		return
	end
	if ligar and (guardando or os.clock() < guardaBloqueadaAte) then
		return
	end
	if not ligar and not guardando then
		return
	end
	guardando = ligar
	pedir("IncursaoGuarda", ligar)
end

-- ====================================================================== barra

local ORDEM = {
	{ "golpe", "M1" },
	{ "tecnica1", "1" },
	{ "tecnica2", "2" },
	{ "despertar", "R" },
	{ "esquiva", "SHIFT" },
	{ "guarda", "F" },
}

local function montarBarra(pai: Instance)
	barra = Kit.novo("Frame", {
		Name = "BarraCombate",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(6 * 104 + 5 * 10, 128),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = pai,
	})
	Kit.novo("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 10),
		Parent = barra,
	})
	for i, par in ORDEM do
		local id, tecla = par[1], par[2]
		local slot = Kit.novo("TextButton", {
			Name = id,
			Text = "",
			AutoButtonColor = true,
			LayoutOrder = i,
			Size = UDim2.fromOffset(104, 92),
			BackgroundColor3 = Cores.Painel,
			BackgroundTransparency = 0.1,
			Parent = barra,
		})
		Kit.novo("UICorner", { CornerRadius = UDim.new(0, 14), Parent = slot })
		Kit.novo("UIStroke", {
			Color = if id == "despertar" then Cores.Lilas else Cores.Borda,
			Thickness = 2,
			Parent = slot,
		})
		local recarga = Kit.novo("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 3,
			Parent = slot,
		})
		Kit.novo("UICorner", { CornerRadius = UDim.new(0, 14), Parent = recarga })
		local rotulo = Kit.texto({
			Text = "",
			TextSize = 15,
			TextWrapped = true,
			Size = UDim2.new(1, -8, 0, 46),
			Position = UDim2.fromOffset(4, 6),
			ZIndex = 4,
			Parent = slot,
		})
		Kit.texto({
			fonte = "titulo",
			Text = tecla,
			TextSize = 22,
			TextColor3 = Cores.Lilas,
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 1, -34),
			ZIndex = 4,
			Parent = slot,
		})
		slots[id] = { recarga = recarga, rotulo = rotulo }
		-- toque / clique no botão (celular)
		if id == "guarda" then
			slot.MouseButton1Down:Connect(function()
				guardar(true)
			end)
			slot.MouseButton1Up:Connect(function()
				guardar(false)
			end)
			slot.MouseLeave:Connect(function()
				guardar(false)
			end)
		elseif id == "esquiva" then
			slot.Activated:Connect(esquivar)
		else
			slot.Activated:Connect(function()
				usar(id)
			end)
		end
	end
	-- medidor do Despertar (acima da barra, fora do layout dos botões)
	local fundo = Kit.novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -128),
		Size = UDim2.fromOffset(420, 18),
		BackgroundColor3 = Cores.Painel,
		Visible = false,
		Parent = pai,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fundo })
	medidorFill = Kit.novo("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Cores.Lilas,
		Parent = fundo,
	})
	Kit.novo("UICorner", { CornerRadius = UDim.new(1, 0), Parent = medidorFill })
	medidorTexto = Kit.texto({
		fonte = "mono",
		Text = "DESPERTAR 0%",
		TextSize = 14,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = fundo,
	})
	barra:GetPropertyChangedSignal("Visible"):Connect(function()
		fundo.Visible = barra.Visible
	end)
end

local function atualizarBarra()
	if not barra.Visible then
		return
	end
	local kit = kitAtual()
	local agora = os.clock()
	for id, s in slots do
		local t = kit.tecnicas[id]
		local falta, total = 0, 1
		if t then
			s.rotulo.Text = t.nome
			falta, total = (recargas[id] or 0) - agora, t.recarga
		elseif id == "esquiva" then
			s.rotulo.Text = if kit.id == "gear5" then "Salto de Borracha" else "Esquiva"
			falta, total = proximoDash - agora, Dados.DASH_RECARGA
		elseif id == "guarda" then
			s.rotulo.Text = if guardando
				then "Guardando…"
				elseif kit.id == "gear5" then "Corpo de Borracha"
				else "Guarda"
			falta, total = guardaBloqueadaAte - agora, Dados.GUARDA_QUEBRA
		end
		if id == "despertar" then
			local pronto = medidor >= Dados.MEDIDOR_MAX
			s.recarga.Size =
				UDim2.fromScale(1, if pronto then 0 else 1 - medidor / Dados.MEDIDOR_MAX)
		else
			s.recarga.Size = UDim2.fromScale(1, math.clamp(falta / total, 0, 1))
		end
	end
	local resta = despertarAte - Workspace:GetServerTimeNow()
	if resta > 0 then
		medidorFill.Size = UDim2.fromScale(math.clamp(resta / kit.despertar.duracao, 0, 1), 1)
		medidorTexto.Text = string.format("DESPERTADO  %.1fs", resta)
	else
		medidorFill.Size = UDim2.fromScale(math.clamp(medidor / Dados.MEDIDOR_MAX, 0, 1), 1)
		medidorTexto.Text = if medidor >= Dados.MEDIDOR_MAX
			then "DESPERTAR PRONTO — R"
			else string.format("DESPERTAR %d%%", math.floor(medidor))
	end
end

-- ====================================================================== entrada pública

-- Eventos "combate" e "combateEstado" chegam pelo remoto das Incursões
function Combate.evento(d: { [string]: any })
	if d.tipo == "combateEstado" then
		if type(d.medidor) == "number" then
			medidor = d.medidor
		end
		if type(d.despertarAte) == "number" then
			despertarAte = d.despertarAte
		end
	elseif d.tipo == "guardaQuebrou" then
		guardando = false
		guardaBloqueadaAte = os.clock() + Dados.GUARDA_QUEBRA
	elseif d.tipo == "combate" then
		EfeitosCombate.evento(d, function(kitId)
			local k = Dados.KITS[kitId]
			return if k then k.despertar.duracao else 8
		end)
	end
end

function Combate.definirPartida(emPartida: boolean)
	ativo = emPartida
	barra.Visible = emPartida
	if not emPartida then
		if guardando then
			guardando = false
		end
		table.clear(recargas)
		medidor = 0
		despertarAte = 0
		EfeitosCombate.limpar()
	end
end

function Combate.definirQualidade(qualidadeBaixa: boolean, movimentoReduzido: boolean)
	EfeitosCombate.definirQualidade(qualidadeBaixa, movimentoReduzido)
end

function Combate.montar(hud: Instance)
	EfeitosCombate.iniciar()
	montarBarra(hud)
	UserInputService.InputBegan:Connect(function(input, processado)
		if not ativo or processado then
			return
		end
		local k = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or k == Enum.KeyCode.ButtonR2 then
			usar("golpe")
		elseif k == Enum.KeyCode.One or k == Enum.KeyCode.ButtonX then
			usar("tecnica1")
		elseif k == Enum.KeyCode.Two or k == Enum.KeyCode.ButtonY then
			usar("tecnica2")
		elseif k == Enum.KeyCode.R or k == Enum.KeyCode.ButtonR1 then
			usar("despertar")
		elseif k == Enum.KeyCode.LeftShift or k == Enum.KeyCode.ButtonL1 then
			esquivar()
		elseif k == Enum.KeyCode.F or k == Enum.KeyCode.ButtonL2 then
			guardar(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local k = input.KeyCode
		if k == Enum.KeyCode.F or k == Enum.KeyCode.ButtonL2 then
			guardar(false)
		end
	end)
	RunService.RenderStepped:Connect(atualizarBarra)
end

return Combate
