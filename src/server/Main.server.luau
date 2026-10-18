local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Health = require(Shared:WaitForChild("Health"))
local Remotos = require(Shared:WaitForChild("Remotos"))

assert(Health.isWorldReady(workspace.Gravity), "Gravidade invalida")

-- Os remotes precisam existir antes de qualquer serviço registrar ações
Remotos.criarTodos()

-- O mundo é construído antes dos serviços que usam as vitrines e a esteira
local Construtor = require(script.Parent:WaitForChild("Mundo"):WaitForChild("Construtor"))
local vitrines = Construtor.construir()

local Servicos = script.Parent:WaitForChild("Servicos")
local Acoes = require(Servicos.Acoes)
local Dados = require(Servicos.Dados)
local Missoes = require(Servicos.Missoes)
local Vitrine = require(Servicos.Vitrine)
local Loja = require(Servicos.Loja)
local Recompensas = require(Servicos.Recompensas)
local Lotes = require(Servicos.Lotes)
local Esteira = require(Servicos.Esteira)
local Resgate = require(Servicos.Resgate)
local Chuva = require(Servicos.Chuva)
local Ranking = require(Servicos.Ranking)
local Conquistas = require(Servicos.Conquistas)
local Teste = require(Servicos.Teste)

Acoes.iniciar()
Missoes.iniciar()
Vitrine.iniciar()
Loja.iniciar()
Recompensas.iniciar()
Lotes.iniciar(vitrines)
Esteira.iniciar(workspace:WaitForChild("Esteira") :: Folder)
Resgate.iniciar()
Chuva.iniciar(workspace:WaitForChild("Chuva") :: Folder)
Ranking.iniciar()
Conquistas.iniciar()
Teste.iniciar()
-- Dados por último: os outros serviços já se registraram em Dados.quandoCarregar
Dados.iniciar()

print(string.format("[Servidor] %s | v%s", Config.Title, Config.Version))
