local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Health = require(Shared:WaitForChild("Health"))

assert(Health.isWorldReady(workspace.Gravity), "Gravidade invalida")
print(string.format("[Servidor] %s | v%s", Config.Title, Config.Version))
