-- Comandos do painel executados pelo servidor, para o próprio dono da experiência de testes.
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Auras = require(Shared.Dados.Auras)
local Incursoes = require(Shared.Dados.Incursoes)
local Perfil = require(Shared.Dados.Perfil)
local Acoes = require(script.Parent.Acoes)
local AuraVisual = require(script.Parent.AuraVisual)
local Dados = require(script.Parent.Dados)
local PermissaoDev = require(script.Parent.PermissaoDev)
local Sorteio = require(script.Parent.Sorteio)
local Nexo = require(script.Parent.Parent.Mundo.Nexo)
local ServicoIncursoes = require(script.Parent.Parent.Incursoes.Servico)

local PainelDev = {}
local studioTeste = RunService:IsStudio() and Config.ModoTeste
local privada = PermissaoDev.experienciaPrivada(game.GameId, game.PlaceId)
local dono: number? = if game.CreatorType == Enum.CreatorType.User then game.CreatorId else nil
local renascendo: { [Player]: boolean } = {}

local function autorizado(player: Player): boolean
	return player.Parent == Players
		and PermissaoDev.autoriza(
			game.GameId,
			game.PlaceId,
			studioTeste,
			dono,
			player.UserId,
			PermissaoDev.contaDeTeste(player.Name, player.UserId)
		)
end

local function estadoDeTeste(player: Player): Perfil.Estado?
	local real = Dados.real(player)
	if not real then
		return nil
	end
	if Dados.emTeste(player) then
		return Dados.de(player)
	end
	local copia = Perfil.copiar(real)
	Dados.definirPerfilTeste(player, copia)
	return copia
end

local function perfil(player: Player, modo: any): (boolean, string?)
	local real = Dados.real(player)
	if not real then
		return false, "Aguardando o perfil carregar"
	end
	local estado: Perfil.Estado?
	local mensagem: string
	if modo == "real" then
		estado = nil
		mensagem = "Perfil real restaurado"
	elseif modo == "novo" then
		estado = Perfil.padrao()
		mensagem = "Conta nova de teste pronta"
	elseif modo == "copia" then
		estado = Perfil.copiar(real)
		mensagem = "Cópia da conta pronta para testar"
	elseif modo == "completo" then
		local completo = Perfil.copiar(Dados.de(player) or real)
		for _, aura in Auras.lista do
			if not Perfil.possui(completo, aura.id) then
				completo.auras[aura.id] = 1
			end
		end
		local inc = completo.incursoes
		for _, universo in Incursoes.UNIVERSOS do
			inc.concluidas[universo.id] = math.max(1, inc.concluidas[universo.id] or 0)
			inc.melhor[universo.id] = Incursoes.ANDARES
		end
		for _, reliquia in Incursoes.RELIQUIAS do
			inc.reliquias[reliquia.id] = #reliquia.custos
		end
		estado = completo
		mensagem = "Auras, universos e relíquias liberados nesta sessão"
	else
		return false, "Perfil de teste desconhecido"
	end
	Dados.definirPerfilTeste(player, estado)
	AuraVisual.definirPrevia(player, "")
	return true, mensagem
end

local function equipar(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" or (id ~= "" and not Auras.porId[id]) then
		return false, "Aura desconhecida"
	end
	local estado = estadoDeTeste(player)
	if not estado then
		return false, "Aguardando o perfil carregar"
	end
	if id ~= "" and not Perfil.possui(estado, id) then
		estado.auras[id] = 1
	end
	estado.equipada = if id ~= "" then id else nil
	AuraVisual.definirPrevia(player, "")
	Dados.enviar(player)
	return true, if id ~= "" then "Aura equipada na sessão de teste" else "Aura desequipada"
end

-- O limite mantém a entrada inteira e dentro da faixa usada pelos contadores da interface.
local function inteiro(valor: any): boolean
	return type(valor) == "number" and valor >= 0 and valor <= 1000000000 and valor % 1 == 0
end

local function quantidade(player: Player, id: any, total: any): (boolean, string?)
	if type(id) ~= "string" or not Auras.porId[id] or not inteiro(total) then
		return false, "Selecione uma aura e informe um inteiro de 0 a 1 bilhão"
	end
	local estado = estadoDeTeste(player)
	if not estado then
		return false, "Aguardando o perfil carregar"
	end
	estado.auras[id] = if total > 0 then total else nil
	if total == 0 and estado.equipada == id then
		estado.equipada = nil
	end
	Dados.enviar(player)
	return true, "Quantidade atualizada na sessão de teste"
end

local function giros(player: Player, total: any): (boolean, string?)
	if not inteiro(total) then
		return false, "Informe um inteiro de 0 a 1 bilhão"
	end
	local estado = estadoDeTeste(player)
	if not estado then
		return false, "Aguardando o perfil carregar"
	end
	estado.giros = total
	Dados.enviar(player)
	return true, "Contagem de giros atualizada na sessão de teste"
end

local function girar(player: Player, id: any): (boolean, string?, { [string]: any }?)
	local aura = if type(id) == "string" then Auras.porId[id] else nil
	if id ~= nil and not aura then
		return false, "Aura desconhecida"
	end
	if not estadoDeTeste(player) then
		return false, "Aguardando o perfil carregar"
	end
	AuraVisual.definirPrevia(player, "")
	return Sorteio.simular(player, aura)
end

local function fragmentos(player: Player, total: any): (boolean, string?)
	if not inteiro(total) then
		return false, "Informe um inteiro de 0 a 1 bilhão"
	end
	local estado = estadoDeTeste(player)
	if not estado then
		return false, "Aguardando o perfil carregar"
	end
	estado.incursoes.fragmentos = total
	Dados.enviar(player)
	return true, "Fragmentos atualizados na sessão de teste"
end

-- Só na sessão de teste (perfil temporário): nada disto chega ao DataStore
local function pontosAura(player: Player, total: any): (boolean, string?)
	if not inteiro(total) then
		return false, "Informe um inteiro de 0 a 1 bilhão"
	end
	local estado = estadoDeTeste(player)
	if not estado then
		return false, "Aguardando o perfil carregar"
	end
	estado.poder.pontos = total
	player:SetAttribute("PontosAura", total)
	Dados.enviar(player)
	return true, "Pontos de Aura atualizados na sessão de teste"
end

local function incursao(player: Player, universo: any, andar: any): (boolean, string?)
	if type(universo) ~= "string" or not Incursoes.porId[universo] then
		return false, "Universo desconhecido"
	end
	if not inteiro(andar) or andar < 1 or andar > Incursoes.ANDARES then
		return false, "Andar inválido"
	end
	if not estadoDeTeste(player) then
		return false, "Aguardando o perfil carregar"
	end
	return ServicoIncursoes.iniciarTeste(player, universo, andar)
end

local function ir(player: Player, lugar: any): (boolean, string?)
	local destino = if type(lugar) == "string" then Nexo.destinoDev(lugar) else nil
	if not destino then
		return false, "Destino indisponível"
	end
	local personagem = player.Character
	local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
	local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
	if
		not personagem
		or not raiz
		or not raiz:IsA("BasePart")
		or not humanoide
		or humanoide.Health <= 0
	then
		return false, "Aguarde o personagem renascer"
	end
	personagem:PivotTo(destino)
	raiz.AssemblyLinearVelocity = Vector3.zero
	raiz.AssemblyAngularVelocity = Vector3.zero
	return true, "Destino alcançado"
end

local function renascer(player: Player): (boolean, string?)
	if renascendo[player] then
		return false, "O personagem já está renascendo"
	end
	renascendo[player] = true
	local ok, erro = pcall(player.LoadCharacterAsync, player)
	renascendo[player] = nil
	if not ok then
		warn("[PainelDev] Falha ao renascer: " .. tostring(erro))
	end
	return ok, if ok then "Personagem renascido" else "Não foi possível renascer"
end

type Comando = (Player, ...any) -> (boolean, string?, { [string]: any }?)
local comandos: { [string]: Comando } = {
	perfil = perfil,
	equipar = equipar,
	giros = giros,
	quantidade = quantidade,
	girar = girar,
	fragmentos = fragmentos,
	pontosAura = pontosAura,
	incursao = incursao,
	previa = AuraVisual.definirPrevia,
	ritual = function(_, indice)
		return Sorteio.testeVisual(indice)
	end,
	ir = ir,
	renascer = renascer,
}

local function executar(player: Player, nome: any, ...: any): (boolean, string?, { [string]: any }?)
	if not autorizado(player) then
		return false, "Painel dev indisponível"
	end
	local comando = if type(nome) == "string" then comandos[nome] else nil
	if not comando then
		return false, "Comando desconhecido"
	end
	if Dados.emTransacao(player) then
		return false, "Aguarde a confirmação no Altar."
	end
	if player:GetAttribute("EmDueloArena") then
		return false, "Encerre o duelo antes de usar o Painel Dev."
	end
	if nome ~= "previa" and ServicoIncursoes.ocupado(player) then
		return false, "Saia da fila ou aguarde o retorno ao Bastião para usar este comando."
	end
	return comando(player, ...)
end

local function marcar(player: Player)
	if autorizado(player) then
		player:SetAttribute("PainelDev", true)
	end
end

function PainelDev.iniciar()
	if not privada and not PermissaoDev.copiaLocal(game.GameId, game.PlaceId, studioTeste) then
		return
	end
	Acoes.registrar("PainelDev", executar)
	Players.PlayerAdded:Connect(marcar)
	for _, player in Players:GetPlayers() do
		marcar(player)
	end
	if privada and game.CreatorType == Enum.CreatorType.Group then
		task.spawn(function()
			local ok, grupo = pcall(GroupService.GetGroupInfoAsync, GroupService, game.CreatorId)
			local donoGrupo = if ok and type(grupo) == "table" then grupo.Owner else nil
			if type(donoGrupo) == "table" and type(donoGrupo.Id) == "number" then
				dono = donoGrupo.Id
				for _, player in Players:GetPlayers() do
					marcar(player)
				end
			end
		end)
	end
end

return PainelDev
