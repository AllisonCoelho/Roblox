local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Health = require(Shared:WaitForChild("Health"))
local Remotos = require(Shared:WaitForChild("Remotos"))

assert(Health.isWorldReady(workspace.Gravity), "Gravidade invalida")
Remotos.criarTodos()

local Servicos = script.Parent:WaitForChild("Servicos")
local Acoes = require(Servicos:WaitForChild("Acoes"))
local Dados = require(Servicos:WaitForChild("Dados"))

Acoes.iniciar()
Dados.iniciar()
print(string.format("[Servidor] %s | base v%s", Config.Title, Config.Version))
