-- Cópia local do estado do jogador, recebida do servidor.
-- A interface só lê daqui; para mudar algo ela pede ao servidor com Estado.pedir.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economia = require(Shared.Dados.Economia)
local Remotos = require(Shared.Remotos)

local Estado = {}

Estado.atual = nil :: Economia.Estado?

local ouvintes: { (Economia.Estado) -> () } = {}

-- Chama fn agora (se já houver estado) e toda vez que o estado mudar
function Estado.aoMudar(fn: (Economia.Estado) -> ())
	table.insert(ouvintes, fn)
	if Estado.atual then
		task.spawn(fn, Estado.atual)
	end
end

-- Hora do servidor (mesma base do os.time() usado nos dados)
function Estado.agora(): number
	return workspace:GetServerTimeNow()
end

-- Moedas esperando no caixa (atualizado pelo servidor a cada segundo)
function Estado.caixa(): number
	local valor = Players.LocalPlayer:GetAttribute("Caixa")
	if type(valor) == "number" then
		return valor
	end
	return if Estado.atual then math.floor(Estado.atual.caixa) else 0
end

-- Pede uma ação ao servidor. Devolve (ok, mensagem)
function Estado.pedir(acao: string, ...: any): (boolean, string?)
	local ok, sucesso, msg =
		pcall(Remotos.funcao("Acao").InvokeServer, Remotos.funcao("Acao"), acao, ...)
	if not ok then
		return false, "Sem conexão com o servidor"
	end
	return sucesso == true, msg
end

-- Revisão da cópia que temos: cópias com número menor ou igual chegaram atrasadas
local revisaoAtual = -1

local function receber(novo: any, revisao: any)
	if type(novo) ~= "table" then
		return
	end
	local rev = if type(revisao) == "number" then revisao else revisaoAtual + 1
	if rev <= revisaoAtual then
		return
	end
	revisaoAtual = rev
	Estado.atual = novo
	for _, fn in ouvintes do
		task.spawn(fn, novo)
	end
end

function Estado.iniciar()
	-- 1) Ouve as atualizações do servidor
	Remotos.evento("Estado").OnClientEvent:Connect(receber)
	-- 2) Handshake: pede a cópia atual em vez de depender de um envio que pode ter
	--    acontecido antes deste script começar. Repete até os dados terminarem de carregar.
	task.spawn(function()
		local espera = 0.5
		local funcao = Remotos.funcao("ObterEstado")
		while not Estado.atual do
			local ok, estado, revisao = pcall(funcao.InvokeServer, funcao)
			if ok and estado then
				receber(estado, revisao)
			else
				task.wait(espera)
				espera = math.min(espera * 2, 5)
			end
		end
	end)
end

return Estado
