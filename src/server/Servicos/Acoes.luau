-- Porta única dos pedidos do cliente (RemoteFunction "Acao").
-- Cada ação é registrada por um serviço; nomes desconhecidos e excesso de pedidos são recusados.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotos = require(ReplicatedStorage.Shared.Remotos)

local Acoes = {}

type Handler = (Player, ...any) -> (boolean, string?)

local handlers: { [string]: Handler } = {}
local LIMITE_POR_SEGUNDO = 8
local janela: { [Player]: { inicio: number, qtd: number } } = {}

function Acoes.registrar(nome: string, fn: Handler)
	assert(handlers[nome] == nil, "Ação registrada duas vezes: " .. nome)
	handlers[nome] = fn
end

local function permitido(player: Player): boolean
	local agora = os.clock()
	local j = janela[player]
	if not j or agora - j.inicio >= 1 then
		janela[player] = { inicio = agora, qtd = 1 }
		return true
	end
	j.qtd += 1
	return j.qtd <= LIMITE_POR_SEGUNDO
end

function Acoes.iniciar()
	Remotos.funcao("Acao").OnServerInvoke = function(player: Player, nome: any, ...: any)
		if type(nome) ~= "string" then
			return false, "Pedido inválido"
		end
		local fn = handlers[nome]
		if not fn then
			return false, "Pedido inválido"
		end
		if not permitido(player) then
			return false, "Calma! Muitos toques seguidos."
		end
		local ok, sucesso, msg = pcall(fn, player, ...)
		if not ok then
			warn(string.format("[Acoes] erro em %s: %s", nome, tostring(sucesso)))
			return false, "Algo deu errado. Tente de novo."
		end
		return sucesso == true, msg
	end
	Players.PlayerRemoving:Connect(function(player)
		janela[player] = nil
	end)
end

return Acoes
