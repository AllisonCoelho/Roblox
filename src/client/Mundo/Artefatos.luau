local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Dados = require(Shared.Dados.Artefatos)
local localPlayer = Players.LocalPlayer
local Artefatos = {}
local pecas: { [Player]: BasePart } = {}
local proprio: string? = nil
local qualidadeBaixa = false
local ocultarAlheios = false

local function limpar(player: Player)
	local parte = pecas[player]
	if parte then
		parte:Destroy()
		pecas[player] = nil
	end
end

local function montarLamina(player: Player, tronco: BasePart)
	local lamina = Instance.new("WedgePart")
	lamina.Name = "LaminaDoNexoLocal"
	lamina.Size = Vector3.new(0.25, 2.4, 0.65)
	lamina.Material = Enum.Material.Neon
	lamina.Color = Color3.fromHex("FFC83D")
	lamina.CanCollide = false
	lamina.CanTouch = false
	lamina.CanQuery = false
	lamina.CastShadow = false
	lamina.Massless = true
	lamina.CFrame = tronco.CFrame * CFrame.new(0.1, 0, 0.7) * CFrame.Angles(0, math.pi / 2, 0.55)
	local vinculo = Instance.new("WeldConstraint")
	vinculo.Part0 = tronco
	vinculo.Part1 = lamina
	vinculo.Parent = lamina
	lamina.Parent = tronco
	pecas[player] = lamina
end

function Artefatos.definir(id: string?, baixa: boolean, ocultar: boolean)
	proprio = Dados.visual(id)
	qualidadeBaixa = baixa
	ocultarAlheios = ocultar
end

function Artefatos.iniciar()
	Players.PlayerRemoving:Connect(limpar)
	task.spawn(function()
		while true do
			local camera = workspace.CurrentCamera
			for _, player in Players:GetPlayers() do
				local meu = player == localPlayer
				local visual = if meu then proprio else player:GetAttribute("ArtefatoVisual")
				local personagem = player.Character
				local tronco = if personagem
					then personagem:FindFirstChild("UpperTorso") or personagem:FindFirstChild(
						"Torso"
					)
					else nil
				if
					visual == "lamina_nexo"
					and (meu or not ocultarAlheios)
					and not qualidadeBaixa
					and camera
					and tronco
					and tronco:IsA("BasePart")
					and (camera.CFrame.Position - tronco.Position).Magnitude <= 80
				then
					local atual = pecas[player]
					if not atual or atual.Parent ~= tronco then
						limpar(player)
						montarLamina(player, tronco)
					end
				else
					limpar(player)
				end
			end
			task.wait(0.35)
		end
	end)
end

return Artefatos
