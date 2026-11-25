-- Drops aleatórios pelo Nexo (regras em Shared/Dados/DropsMapa) e o relógio do ciclo de dia e
-- noite (Shared/Dados/Ciclo).
--
-- Cada drop é uma peça invisível em Workspace.DropsMapa com os atributos Tipo e Ate; cada cliente
-- monta o visual. A coleta é só do servidor: quem tiver a raiz do personagem a até RAIO_COLETA
-- studs primeiro leva (sem remote, então não há o que falsificar). Os lugares são sorteados
-- no anel do mapa e conferidos com um raio para baixo: só chão aberto (chão, praça, caminhos e
-- jardim), nunca em cima de construções ou dentro delas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ciclo = require(Shared.Dados.Ciclo)
local DropsMapa = require(Shared.Dados.DropsMapa)
local Remotos = require(Shared.Remotos)
local Dados = require(script.Parent.Dados)
local PontosAura = require(script.Parent.PontosAura)
local Pets = require(script.Parent.Pets)
local Equipamento = require(script.Parent.Equipamento)

local Servico = {}

local CHAO_VALIDO = { Chao = true, Praca = true, Caminho = true, JardimChao = true }
local ALTURA_MAXIMA = 4 -- o chão do Nexo fica perto de y = 0
local AFASTAMENTO = 3.2 -- o drop flutua acima do chão

type Drop = { id: number, tipo: string, parte: Part, ate: number }

local rng = Random.new()
local drops: { [number]: Drop } = {}
local contador = 0
local pasta: Folder
local bencaoAte: { [Player]: number } = {}

-- Segundos do ciclo (relógio do servidor + deslocamento do Painel Dev)
function Servico.segundos(): number
	return Workspace:GetServerTimeNow()
		+ (tonumber(Workspace:GetAttribute("CicloDeslocamento")) or 0)
end

-- Painel Dev: pula para o começo de uma fase
function Servico.irParaFase(fase: any): (boolean, string?)
	if type(fase) ~= "string" or not Ciclo.NOMES[fase] then
		return false, "Fase desconhecida"
	end
	local agora = Workspace:GetServerTimeNow()
	local alvo = Ciclo.inicioDa(fase :: Ciclo.Fase) + 1
	Workspace:SetAttribute("CicloDeslocamento", alvo - agora % Ciclo.DURACAO)
	return true, "Ciclo: " .. Ciclo.NOMES[fase]
end

local function contar(): number
	local n = 0
	for _ in drops do
		n += 1
	end
	return n
end

local function lugarLivre(): Vector3?
	local nexo = Workspace:FindFirstChild("Nexo")
	if not nexo then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { nexo }
	for _ = 1, 12 do
		local x, z = DropsMapa.pontoNoAnel(rng:NextNumber(), rng:NextNumber())
		local hit = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), params)
		if
			hit
			and CHAO_VALIDO[hit.Instance.Name]
			and hit.Normal.Y > 0.9
			and hit.Position.Y < ALTURA_MAXIMA
		then
			-- longe dos outros drops
			local pos = hit.Position + Vector3.new(0, AFASTAMENTO, 0)
			local perto = false
			for _, d in drops do
				if (d.parte.Position - pos).Magnitude < 12 then
					perto = true
					break
				end
			end
			if not perto then
				return pos
			end
		end
	end
	return nil
end

local function criar(noite: boolean)
	local pos = lugarLivre()
	if not pos then
		return
	end
	contador += 1
	local tipo = DropsMapa.sortear(noite, function()
		return rng:NextNumber()
	end)
	local parte = Instance.new("Part")
	parte.Name = "Drop"
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanTouch = false
	parte.CanQuery = false
	parte.Transparency = 1
	parte.Size = Vector3.new(2, 2, 2)
	parte.Position = pos
	local ate = Workspace:GetServerTimeNow() + DropsMapa.VIDA
	parte:SetAttribute("Id", contador)
	parte:SetAttribute("Tipo", tipo)
	parte:SetAttribute("Ate", ate)
	parte.Parent = pasta
	drops[contador] = { id = contador, tipo = tipo, parte = parte, ate = ate }
end

local function premiar(player: Player, d: Drop)
	local estado = Dados.de(player) :: any
	if not estado then
		return
	end
	local fase = DropsMapa.faseMaxima(estado.corredor and estado.corredor.concluidas)
	local _, _, multFragPets = Pets.multiplicadores(player)
	local multFrag = multFragPets * Equipamento.multiplicadores(player).fragmentos
	local premio = DropsMapa.premio(d.tipo, PontosAura.ganho(player), fase, multFrag)
	Dados.alterar(player, function(e)
		local s = e :: any
		s.poder.pontos += premio.pontos
		s.poder.total += premio.pontos
		s.corredor.fragmentos += premio.fragmentos
		return true
	end)
	player:SetAttribute("PontosAura", math.floor((Dados.de(player) :: any).poder.pontos))
	if premio.bencao then
		bencaoAte[player] = Workspace:GetServerTimeNow() + DropsMapa.BENCAO
		player:SetAttribute("BencaoEstelarAte", bencaoAte[player])
	end
	Remotos.evento("DropsMapa"):FireAllClients({
		tipo = "coleta",
		id = d.id,
		de = player.UserId,
		texto = DropsMapa.texto(d.tipo, premio),
	})
end

local function coletar()
	if next(drops) == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		local personagem = player.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local humanoide = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if not raiz or not raiz:IsA("BasePart") or not humanoide or humanoide.Health <= 0 then
			continue
		end
		if not Dados.de(player) then
			continue
		end
		for id, d in drops do
			if (d.parte.Position - raiz.Position).Magnitude <= DropsMapa.RAIO_COLETA then
				drops[id] = nil
				d.parte:Destroy()
				premiar(player, d)
			end
		end
	end
end

local function limparVencidos(agora: number)
	for id, d in drops do
		if agora >= d.ate then
			drops[id] = nil
			d.parte:Destroy()
		end
	end
end

function Servico.iniciar()
	pasta = Instance.new("Folder")
	pasta.Name = "DropsMapa"
	pasta.Parent = Workspace
	PontosAura.registrarGanho(function(player)
		local ate = bencaoAte[player]
		return if ate and ate > Workspace:GetServerTimeNow() then DropsMapa.BENCAO_GANHO else 1
	end)
	Players.PlayerRemoving:Connect(function(player)
		bencaoAte[player] = nil
	end)
	local proximo = 0
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, erro = pcall(function()
				local agora = Workspace:GetServerTimeNow()
				coletar()
				limparVencidos(agora)
				if agora >= proximo then
					local noite = Ciclo.ehNoite(Servico.segundos())
					proximo = agora + DropsMapa.intervalo(noite)
					if contar() < DropsMapa.maximo(#Players:GetPlayers()) then
						criar(noite)
					end
				end
			end)
			if not ok then
				warn("[DropsMapa] " .. tostring(erro))
			end
		end
	end)
end

return Servico
