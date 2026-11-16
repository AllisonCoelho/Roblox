-- Monta a interface do Despertar e controla o giro (manual e automático).
-- O cliente só pede: o resultado do sorteio sempre vem do servidor, já decidido e registrado.
-- A apresentação (Mundo/Despertar) é escolhida a partir desse resultado.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Apresentacao = require(Shared.Dados.Apresentacao)
local Auras = require(Shared.Dados.Auras)
local Config = require(Shared.Config)
local Remotos = require(Shared.Remotos)
local Escala = require(script.Parent.Escala)
local Estado = require(script.Parent.Estado)
local Navegacao = require(script.Parent.Navegacao)
local Telas = script.Parent:WaitForChild("Telas")
local Ajustes = require(Telas.Ajustes)
local Avisos = require(Telas.Avisos)
local HUD = require(Telas.HUD)
local Indice = require(Telas.Indice)
local Revelacao = require(Telas.Revelacao)
local Mundo = script.Parent.Parent:WaitForChild("Mundo")
local Despertar = require(Mundo:WaitForChild("Despertar"))
local EfeitosAlheios = require(Mundo:WaitForChild("EfeitosAlheios"))

local App = {}

-- Pequena folga além do cooldown do servidor para não ter pedidos recusados
local FOLGA = 0.05
local INTERVALO = Config.CooldownGiro + FOLGA

local girando = false
local proximoGiro = 0
local ocupadoAte = 0 -- fim do ritual em andamento (auras sem cartão)
local hud: HUD.Api

local function preferencias(): Despertar.Preferencias
	local estado = Estado.atual
	return Despertar.preferencias(if estado then estado.configuracoes else nil)
end

local function podeGirar(): boolean
	local agora = os.clock()
	return not girando
		and not Revelacao.ativa()
		and agora >= proximoGiro
		and agora >= ocupadoAte
		-- o toque que fechou o cartão não deve virar um giro
		and agora - Revelacao.fimEm > 0.4
end

-- Encena um resultado já confirmado pelo servidor
local function apresentar(aura: Auras.Aura, dados: { [string]: any })
	local quantidade = if type(dados.quantidade) == "number" then dados.quantidade else 1
	local teste = dados.teste == true
	local nova = quantidade <= 1 and not teste
	local prefs = preferencias()
	local cat = Despertar.categoria(aura, not nova and not teste, prefs)
	local comCartao = cat.cartao > 0

	local function revelar()
		if not teste then
			hud.registrarResultado(aura, nova)
		end
		if comCartao then
			local estado = Estado.atual
			Revelacao.mostrar(aura, cat, {
				quantidade = quantidade,
				equipada = dados.equipou == true or (estado ~= nil and estado.equipada == aura.id),
				teste = teste,
			})
		end
	end

	ocupadoAte = os.clock() + Apresentacao.tempoAteRevelacao(cat)
	if comCartao then
		Revelacao.cena(cat.camera and not prefs.movimentoReduzido)
	end
	Despertar.proprio(aura, cat, prefs, revelar)
end

local function girar()
	if not podeGirar() then
		return
	end
	girando = true
	proximoGiro = os.clock() + INTERVALO
	local ok, resposta, dados = Estado.pedir("Despertar")
	girando = false
	if ok and resposta then
		local aura = Auras.porId[resposta]
		if aura then
			apresentar(aura, dados or {})
		end
	elseif resposta then
		Avisos.toast(resposta)
	end
end

-- Só no Studio: Alt+1..6 encena uma categoria sem sortear nem salvar nada
local function testeVisual(indice: number)
	if not podeGirar() then
		return
	end
	task.spawn(function()
		local ok, resposta, dados = Estado.pedir("TesteVisual", indice)
		local aura = if ok and resposta then Auras.porId[resposta] else nil
		if aura then
			apresentar(aura, dados or { teste = true })
		elseif resposta then
			Avisos.toast(resposta)
		end
	end)
end

local function alternarConfiguracao(chave: string)
	local estado = Estado.atual
	if not estado then
		return
	end
	task.spawn(function()
		local ok, msg = Estado.pedir("Configurar", chave, not estado.configuracoes[chave])
		if not ok and msg then
			Avisos.toast(msg)
		end
	end)
end

-- Alguém do servidor tirou uma aura 1 em 1.000 ou mais rara
local function aoDespertou(dados: any)
	if type(dados) ~= "table" or type(dados.aura) ~= "string" or type(dados.userId) ~= "number" then
		return
	end
	local aura = Auras.porId[dados.aura]
	if not aura then
		return
	end
	-- O próprio jogador já está vendo a versão completa
	if dados.userId ~= Players.LocalPlayer.UserId then
		local jogador = Players:GetPlayerByUserId(dados.userId)
		if jogador then
			Despertar.alheio(jogador, aura, preferencias())
		end
	end
	if type(dados.jogador) == "string" then
		Avisos.anunciar(dados.jogador, dados.userId, aura)
	end
end

function App.iniciar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Despertar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local raiz = Escala.montar(gui)
	Navegacao.montar(raiz)
	hud = HUD.montar(raiz, {
		aoDespertar = function()
			task.spawn(girar)
		end,
		aoAlternarAuto = function()
			alternarConfiguracao("giroAutomatico")
		end,
		aoAbrirIndice = Indice.abrir,
		aoAbrirAjustes = Ajustes.abrir,
	})
	Revelacao.montar(raiz, {
		aoEquipar = function(auraId)
			task.spawn(function()
				local ok, msg = Estado.pedir("Equipar", auraId)
				if not ok and msg then
					Avisos.toast(msg)
				end
			end)
		end,
		aoPular = Despertar.pular,
		aoMudar = function(ativa)
			hud.definirVisivel(not ativa)
		end,
	})
	Avisos.montar(raiz)
	Indice.montar(Avisos.toast)
	Ajustes.montar(Avisos.toast)
	Navegacao.ajustar()

	EfeitosAlheios.iniciar()
	Estado.aoMudar(function(estado)
		hud.atualizar(estado)
		EfeitosAlheios.definir(estado.configuracoes.ocultarEfeitosAlheios == true)
	end)
	Estado.iniciar()
	Remotos.evento("Despertou").OnClientEvent:Connect(aoDespertou)

	-- Se o personagem renascer no meio de uma cena, a tela não pode ficar presa
	Players.LocalPlayer.CharacterAdded:Connect(function()
		Revelacao.fechar()
	end)

	-- Anel do selo: enche durante o intervalo entre giros
	RunService.RenderStepped:Connect(function()
		local falta = math.max(0, math.max(proximoGiro, ocupadoAte) - os.clock())
		hud.definirCarga(1 - math.min(falta / INTERVALO, 1))
	end)

	UserInputService.InputBegan:Connect(function(input, processado)
		if processado then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			task.spawn(girar)
		elseif RunService:IsStudio() and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
			local indice = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			if indice >= 1 and indice <= #Apresentacao.Categorias then
				testeVisual(indice)
			end
		end
	end)

	-- Giro automático: mesma rotina e mesmo cooldown do giro manual
	task.spawn(function()
		while true do
			task.wait(0.1)
			local estado = Estado.atual
			if estado and estado.configuracoes.giroAutomatico and podeGirar() then
				task.spawn(girar)
			end
		end
	end)
end

return App
