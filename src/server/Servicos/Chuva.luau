-- Chuva de Doces (sábado 15h, ver Shared/Dados/Evento.luau): Docinhos caem em pontos livres
-- do mapa e quem encosta primeiro ganha de graça na vitrine.
-- Como na esteira, cada Docinho fica parado no servidor (no ponto de pouso) e o cliente
-- anima a queda pelo tempo; o servidor só deixa pegar depois que pousou.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tema = require(Shared.Tema)
local Catalogo = require(Shared.Dados.Catalogo)
local ChuvaDados = require(Shared.Dados.Chuva)
local EsteiraDados = require(Shared.Dados.Esteira)
local Evento = require(Shared.Dados.Evento)
local Modelos = require(Shared.Dados.Modelos)
local Remotos = require(Shared.Remotos)
local Dados = require(script.Parent.Dados)
local Vitrine = require(script.Parent.Vitrine)

local Cores = Tema.Cores
local Chuva = {}

local ESCALA = 1.4

type Item = { id: string, variante: string, inicio: number, pouso: Vector3, modelo: Model }

local pasta: Folder
local itens: { [number]: Item } = {}
local quantidade = 0
local proximoUid = 0
local forcadoAte = 0
local aleatorio = Random.new()

local function agora(): number
	return workspace:GetServerTimeNow()
end

-- Está chovendo agora? (pela agenda de sábado ou forçado pelo teste)
-- Devolve também quando acaba, para os clientes mostrarem a contagem
local function estado(): (boolean, number)
	local t = os.time()
	local ativo, falta = Evento.estado(t)
	if ativo then
		return true, t + falta
	end
	if forcadoAte > t then
		return true, forcadoAte
	end
	return false, 0
end

local function remover(uid: number)
	local item = itens[uid]
	if item then
		itens[uid] = nil
		quantidade -= 1
		item.modelo:Destroy()
	end
end

local function soltar()
	if quantidade >= ChuvaDados.MaximoNoChao then
		return
	end
	local pouso = ChuvaDados.sortearPonto(function()
		return aleatorio:NextNumber()
	end)
	if not pouso then
		return
	end
	-- Na chuva a sorte é maior: raros pesam o dobro
	local id, variante = EsteiraDados.sortear(function()
		return aleatorio:NextNumber()
	end, true, ChuvaDados.PesoSecreto)
	proximoUid += 1
	local uid = proximoUid
	local modelo = Modelos.criar(id)
	modelo:ScaleTo(ESCALA)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
	end
	modelo:PivotTo(CFrame.new())
	local caixa, tamanho = modelo:GetBoundingBox()
	local alturaBase = -(caixa.Position.Y - tamanho.Y / 2)
	modelo:PivotTo(CFrame.new(pouso + Vector3.new(0, alturaBase, 0)))
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local alvo = modelo:FindFirstChildWhichIsA("BasePart")
	if id == "coxinha" then
		Remotos.evento("Aviso")
			:FireAllClients({ tipo = "raro", texto = "", docinho = id, onde = "chuva" })
	end
	if alvo then
		local brilho = Instance.new("Sparkles")
		brilho.SparkleColor = if variante == "normal" then Cores.Ceu else Cores.Ouro
		brilho.Parent = alvo
	end
	local inicio = agora()
	modelo.Name = "Gota" .. uid
	modelo:SetAttribute("Inicio", inicio)
	modelo:SetAttribute("AlturaBase", alturaBase)
	modelo:SetAttribute("Pouso", pouso)
	modelo.Parent = pasta
	itens[uid] = { id = id, variante = variante, inicio = inicio, pouso = pouso, modelo = modelo }
	quantidade += 1
	task.delay(ChuvaDados.Queda + ChuvaDados.TempoNoChao, remover, uid)
end

local function pegar(player: Player, uid: number, item: Item)
	remover(uid)
	if Vitrine.adicionarDocinho(player, item.id, item.variante) then
		local d = Catalogo.docinho(item.id)
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "sucesso",
			texto = "Você pegou " .. (if d then d.nome else "um Docinho") .. " na chuva!",
		})
	else
		Dados.alterar(player, function(e)
			e.granulados += ChuvaDados.GranuladosSeCheia
			return true
		end)
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "info",
			texto = "Vitrine cheia! Você ganhou "
				.. ChuvaDados.GranuladosSeCheia
				.. " granulados.",
		})
	end
end

-- Quem encostou num Docinho que já pousou, pega
local function verificarPegadas()
	local t = agora()
	for _, player in Players:GetPlayers() do
		local personagem = player.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not raiz or not Dados.de(player) then
			continue
		end
		for uid, item in itens do
			if
				ChuvaDados.pousou(item.inicio, t)
				and (raiz.Position - item.pouso).Magnitude <= ChuvaDados.DistanciaPegar
			then
				pegar(player, uid, item)
				break
			end
		end
	end
end

-- Liga a chuva por alguns segundos fora da agenda (usado pelo teste no Studio)
function Chuva.forcar(segundos: number)
	forcadoAte = os.time() + segundos
end

function Chuva.iniciar(pastaChuva: Folder)
	pasta = pastaChuva
	local chovendoAntes = false
	task.spawn(function()
		local ultimoSolto = 0
		while true do
			task.wait(0.2)
			local chovendo, fim = estado()
			if chovendo ~= chovendoAntes then
				-- Os clientes mostram a faixa e a contagem a partir deste atributo
				workspace:SetAttribute("ChuvaAte", if chovendo then fim else 0)
				chovendoAntes = chovendo
				if not chovendo then
					for uid in itens do
						remover(uid)
					end
				end
			end
			if chovendo then
				local t = os.clock()
				if t - ultimoSolto >= ChuvaDados.Intervalo then
					ultimoSolto = t
					local ok, erro = pcall(soltar)
					if not ok then
						warn("[Chuva] " .. tostring(erro))
					end
				end
			end
			if quantidade > 0 then
				verificarPegadas()
			end
		end
	end)
end

return Chuva
