local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Health = require(Shared:WaitForChild("Health"))
local Remotos = require(Shared:WaitForChild("Remotos"))

assert(Health.isWorldReady(workspace.Gravity), "Gravidade invalida")

-- Os remotes precisam existir antes de qualquer serviço registrar ações
Remotos.criarTodos()

local Servicos = script.Parent:WaitForChild("Servicos")
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local Missoes = require(Servicos.Missoes)
local Vitrine = require(Servicos.Vitrine)
local Loja = require(Servicos.Loja)
local Recompensas = require(Servicos.Recompensas)
local Teste = require(Servicos.Teste)

Acoes.iniciar()
Missoes.iniciar()
Vitrine.iniciar()
Loja.iniciar()
Recompensas.iniciar()
Teste.iniciar()
-- Dados por último: os outros serviços já se registraram em Dados.quandoCarregar
Dados.iniciar()

print(string.format("[Servidor] %s | v%s", Config.Title, Config.Version))
