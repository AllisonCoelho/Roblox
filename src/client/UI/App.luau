-- Tela temporária: a UI de sorteios do Despertar será implementada na V1.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tema = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tema"))
local Estado = require(script.Parent:WaitForChild("Estado"))

local App = {}

function App.iniciar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Despertar"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local rotulo = Instance.new("TextLabel")
	rotulo.Name = "Status"
	rotulo.AnchorPoint = Vector2.new(0.5, 0)
	rotulo.Position = UDim2.new(0.5, 0, 0, 64)
	rotulo.Size = UDim2.fromOffset(460, 84)
	rotulo.BackgroundColor3 = Tema.Cores.Fundo
	rotulo.TextColor3 = Tema.Cores.Branco
	rotulo.Font = Tema.Fonte
	rotulo.TextSize = 21
	rotulo.TextWrapped = true
	rotulo.Text = "DESPERTAR | Conectando ao servidor..."
	rotulo.Parent = gui

	local cantos = Instance.new("UICorner")
	cantos.CornerRadius = UDim.new(0, 12)
	cantos.Parent = rotulo

	Estado.aoMudar(function(perfil)
		rotulo.Text = string.format("DESPERTAR | Base pronta!\nPerfil: %d giros", perfil.giros)
	end)
	Estado.iniciar()
end

return App
