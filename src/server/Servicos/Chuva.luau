-- Chuva de Doces (sábado 15h) e Chuvisco (ver Shared/Dados/Evento.luau): Docinhos caem em pontos livres
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
local Formato = require(Shared.Formato)
local Remotos = require(Shared.Remotos)
local Dados = require(script.Parent.Dados)
local Vitrine = require(script.Parent.Vitrine)
local Conquistas = require(script.Parent.Conquistas)

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

-- Está chovendo agora? (pela agenda ou forçado pelo teste, que conta como chuva grande)
-- Devolve também quando acaba, para os clientes mostrarem a contagem, e se é a grande
local function estado(): (boolean, number, boolean)
	local t = os.time()
	if forcadoAte > t then
		return true, forcadoAte, true
	end
	local ativo, falta, grande = Evento.chuva(t)
	if ativo then
		return true, t + falta, grande
	end
	return false, 0, false
end

local function remover(uid: number)
	local item = itens[uid]
	if item then
		itens[uid] = nil
		quantidade -= 1
		item.modelo:Destroy()
	end
end

local function soltar(grande: boolean)
	if quantidade >= ChuvaDados.MaximoNoChao then
		return
	end
	local pouso = ChuvaDados.sortearPonto(function()
		return aleatorio:NextNumber()
	end)
	if not pouso then
		return
	end
	-- Na chuva grande a sorte é maior (raros pesam o dobro) e o Secreto pode cair
	local id, variante = EsteiraDados.sortear(function()
		return aleatorio:NextNumber()
	end, grande, if grande then ChuvaDados.PesoSecreto else nil)
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
		Conquistas.dar(player, "chuva")
		local d = Catalogo.docinho(item.id)
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "sucesso",
			texto = "Você pegou " .. (if d then d.nome else "um Docinho") .. " na chuva!",
		})
	else
		-- Vitrine cheia: vende na hora pelo mesmo valor da vitrine (moedas, não granulados,
		-- para a chuva não virar uma fonte de granulados)
		local valor = EsteiraDados.valorVenda(item.id, item.variante)
		Dados.alterar(player, function(e)
			e.moedas += valor
			return true
		end)
		Remotos.evento("Aviso"):FireClient(player, {
			tipo = "info",
			texto = "Vitrine cheia! Vendemos o Docinho por " .. Formato.curto(valor) .. " moedas.",
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
	local fimAntes = 0
	task.spawn(function()
		local ultimoSolto = 0
		while true do
			task.wait(0.2)
			local chovendo, fim, grande = estado()
			local fimAtual = if chovendo then fim else 0
			if fimAtual ~= fimAntes then
				-- Os clientes mostram a faixa e a contagem a partir destes atributos
				-- (ChuvaGrande antes, porque o cliente reage à mudança de ChuvaAte)
				workspace:SetAttribute("ChuvaGrande", grande)
				workspace:SetAttribute("ChuvaAte", fimAtual)
				fimAntes = fimAtual
			end
			if chovendo ~= chovendoAntes then
				chovendoAntes = chovendo
				if not chovendo then
					for uid in itens do
						remover(uid)
					end
				end
			end
			if chovendo then
				local t = os.clock()
				local intervalo = if grande
					then ChuvaDados.Intervalo
					else ChuvaDados.IntervaloChuvisco
				if t - ultimoSolto >= intervalo then
					ultimoSolto = t
					local ok, erro = pcall(soltar, grande)
					if not ok then
						warn("[Chuva] " .. tostring(erro))
					end
				end
			end
			if quantidade > 0 then
				local ok, erro = pcall(verificarPegadas)
				if not ok then
					warn("[Chuva] " .. tostring(erro))
				end
			end
		end
	end)
end

return Chuva
