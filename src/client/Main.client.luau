local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
print(string.format("[Cliente] Bem-vindo a %s", Config.Title))

require(script.Parent:WaitForChild("UI"):WaitForChild("App")).iniciar()
