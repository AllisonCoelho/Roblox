-- Estátua da Gear 5 na praça (Dados/PrimeirosMinutos.ESTATUA). O servidor só monta o pedestal, a
-- colisão e a interação ("Ver baús"); cada cliente monta a estátua em si (Mundo/Estatua), um
-- boneco de mármore com a placa e a contagem do próximo evento.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PrimeirosMinutos = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dados"):WaitForChild("PrimeirosMinutos")
)

local Estatua = {}

local PEDRA = Color3.fromHex("5A5470")
local OURO = Color3.fromHex("FFC23A")

local function peca(pai: Instance, nome: string, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = pai
	return p
end

function Estatua.iniciar()
	if Workspace:FindFirstChild("EstatuaGear5") then
		return
	end
	local e = PrimeirosMinutos.ESTATUA
	local base = Vector3.new(e.x, 0, e.z)
	local pasta = Instance.new("Model")
	pasta.Name = "EstatuaGear5"
	-- pedestal em degraus, com filete dourado
	peca(pasta, "Degrau", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 16, 16),
		CFrame = CFrame.new(base + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PEDRA,
		Material = Enum.Material.Slate,
	})
	peca(pasta, "Pedestal", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 11, 11),
		CFrame = CFrame.new(base + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("E8E2D6"),
		Material = Enum.Material.Marble,
	})
	peca(pasta, "Filete", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 11.4, 11.4),
		CFrame = CFrame.new(base + Vector3.new(0, 2.45, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = OURO,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	-- colisão da estátua (o visual é do cliente) e a interação
	local corpo = peca(pasta, "Corpo", {
		Size = Vector3.new(6, 12, 3),
		CFrame = CFrame.new(base + Vector3.new(0, 2.4 + 6, 0)),
		Transparency = 1,
	})
	corpo:SetAttribute("Base", base + Vector3.new(0, 2.4, 0))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ver baús do Sol"
	prompt.ObjectText = "Estátua da Gear 5"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Acao", "baus")
	prompt.Parent = corpo
	pasta.PrimaryPart = corpo
	pasta.Parent = Workspace
end

return Estatua
