-- Ferramentas de teste. Só existem no Roblox Studio com Config.ModoTeste ligado;
-- em servidores publicados estas ações nem são registradas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Catalogo = require(Shared.Dados.Catalogo)
local Remotos = require(Shared.Remotos)
local Acoes = require(script.Parent.Acoes)
local Vitrine = require(script.Parent.Vitrine)
local Esteira = require(script.Parent.Esteira)
local Chuva = require(script.Parent.Chuva)

local Teste = {}

function Teste.iniciar()
	if not (RunService:IsStudio() and Config.ModoTeste) then
		return
	end
	warn(
		"[Teste] ModoTeste ligado: dados não são salvos e as teclas F1-F7 mostram os popups e testam a esteira e a chuva"
	)

	-- Dá um Docinho sorteado (testa o popup Novo Docinho com o fluxo real do servidor)
	Acoes.registrar("TesteDocinho", function(player)
		local d = Catalogo.Lista[math.random(1, #Catalogo.Lista)]
		local variante = ({ "normal", "normal", "dourado", "arcoiris" })[math.random(1, 4)]
		if not Vitrine.adicionarDocinho(player, d.id, variante) then
			return false, "Vitrine cheia"
		end
		return true
	end)

	Acoes.registrar("TesteResgate", function(player)
		Remotos.evento("Resgate"):FireClient(player, { id = "brigadeiro" })
		return true
	end)

	-- Solta um Docinho Lendário na esteira (testa a compra, carregar e entregar)
	Acoes.registrar("TesteEsteiraRaro", function()
		Esteira.soltar("pudim", "normal")
		return true, "Um Pudim Astronauta saiu da fábrica!"
	end)

	-- Liga a Chuva de Doces por 60 segundos (fora da agenda de sábado)
	Acoes.registrar("TesteChuva", function()
		Chuva.forcar(60)
		return true
	end)

	Acoes.registrar("TesteAvisoRaro", function()
		Remotos.evento("Aviso"):FireAllClients({ tipo = "raro", texto = "", docinho = "pudim" })
		return true
	end)
end

return Teste
