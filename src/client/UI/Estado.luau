-- Cópia local do estado do jogador, recebida do servidor.
-- A interface só lê daqui; para mudar algo ela pede ao servidor com Estado.pedir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Perfil = require(Shared.Dados.Perfil)
local Remotos = require(Shared.Remotos)

local Estado = {}

Estado.atual = nil :: Perfil.Estado?

local ouvintes: { (Perfil.Estado) -> () } = {}

-- Chama fn agora (se já houver estado) e toda vez que o estado mudar
function Estado.aoMudar(fn: (Perfil.Estado) -> ())
	table.insert(ouvintes, fn)
	if Estado.atual then
		task.spawn(fn, Estado.atual)
	end
end

-- Hora do servidor (mesma base do os.time() usado nos dados)
function Estado.agora(): number
	return workspace:GetServerTimeNow()
end

-- Pede uma ação ao servidor. Devolve (ok, mensagem, dados)
function Estado.pedir(acao: string, ...: any): (boolean, string?, { [string]: any }?)
	local funcao = Remotos.funcao("Acao")
	local ok, sucesso, msg, dados = pcall(funcao.InvokeServer, funcao, acao, ...)
	if not ok then
		return false, "Sem conexão com o servidor", nil
	end
	return sucesso == true, msg, if type(dados) == "table" then dados else nil
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
