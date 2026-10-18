-- Nomes e acesso aos remotes. O servidor cria; o cliente espera existirem.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotos = {}

Remotos.Eventos = {
	"Estado", -- servidor -> cliente: estado completo do jogador
	"Aviso", -- servidor -> cliente: mensagem curta ({ tipo, texto, docinho? })
	"NovoDocinho", -- servidor -> cliente: Docinho descoberto ({ id, variante })
	"Resgate", -- servidor -> cliente: alguém está levando um Docinho seu ({ id })
}
Remotos.Funcoes = {
	"Acao", -- cliente -> servidor: pedido validado no servidor; devolve (ok, mensagem)
}

local NOME_PASTA = "Remotos"

local function pasta(): Folder
	if RunService:IsServer() then
		local p = ReplicatedStorage:FindFirstChild(NOME_PASTA)
		if not p then
			p = Instance.new("Folder")
			p.Name = NOME_PASTA
			p.Parent = ReplicatedStorage
		end
		return p :: Folder
	end
	return ReplicatedStorage:WaitForChild(NOME_PASTA) :: Folder
end

function Remotos.criarTodos()
	local p = pasta()
	for _, nome in Remotos.Eventos do
		if not p:FindFirstChild(nome) then
			local r = Instance.new("RemoteEvent")
			r.Name = nome
			r.Parent = p
		end
	end
	for _, nome in Remotos.Funcoes do
		if not p:FindFirstChild(nome) then
			local r = Instance.new("RemoteFunction")
			r.Name = nome
			r.Parent = p
		end
	end
end

function Remotos.evento(nome: string): RemoteEvent
	return pasta():WaitForChild(nome) :: RemoteEvent
end

function Remotos.funcao(nome: string): RemoteFunction
	return pasta():WaitForChild(nome) :: RemoteFunction
end

return Remotos
