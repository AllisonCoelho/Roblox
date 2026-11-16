-- Monta a interface do Despertar e controla o giro (manual e automático).
-- O cliente só pede: o resultado do sorteio sempre vem do servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Config = require(Shared.Config)
local Remotos = require(Shared.Remotos)
local Escala = require(script.Parent.Escala)
local Estado = require(script.Parent.Estado)
local Navegacao = require(script.Parent.Navegacao)
local Telas = script.Parent:WaitForChild("Telas")
local Avisos = require(Telas.Avisos)
local HUD = require(Telas.HUD)
local Indice = require(Telas.Indice)
local Revelacao = require(Telas.Revelacao)
local Despertar = require(script.Parent.Parent:WaitForChild("Mundo"):WaitForChild("Despertar"))

local App = {}

-- Pequena folga além do cooldown do servidor para não ter pedidos recusados
local FOLGA = 0.05
local INTERVALO = Config.CooldownGiro + FOLGA

local girando = false
local proximoGiro = 0
local hud: HUD.Api

local function podeGirar(): boolean
	return not girando
		and not Revelacao.ativa()
		and os.clock() >= proximoGiro
		-- o toque que pulou a cena não deve virar um giro
		and os.clock() - Revelacao.fimEm > 0.4
end

local function girar()
	if not podeGirar() then
		return
	end
	girando = true
	proximoGiro = os.clock() + INTERVALO
	local ok, resposta = Estado.pedir("Despertar")
	girando = false
	if ok and resposta then
		local aura = Auras.porId[resposta]
		if aura then
			hud.registrarResultado(aura)
			Revelacao.mostrar(aura)
		end
	elseif resposta then
		Avisos.toast(resposta)
	end
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

-- Alguém (inclusive você) tirou uma aura Rara ou melhor: anima o personagem e anuncia
local function aoDespertou(dados: any)
	if type(dados) ~= "table" or type(dados.aura) ~= "string" or type(dados.userId) ~= "number" then
		return
	end
	local aura = Auras.porId[dados.aura]
	if not aura then
		return
	end
	local jogador = Players:GetPlayerByUserId(dados.userId)
	if jogador and jogador.Character then
		Despertar.tocar(jogador.Character, aura)
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
		aoAlternarAnuncios = function()
			alternarConfiguracao("anuncios")
		end,
	})
	Revelacao.montar(raiz)
	Revelacao.aoMudar(function(ativa)
		hud.definirVisivel(not ativa)
	end)
	Avisos.montar(raiz)
	Indice.montar(Avisos.toast)
	Navegacao.ajustar()

	Estado.aoMudar(hud.atualizar)
	Estado.iniciar()
	Remotos.evento("Despertou").OnClientEvent:Connect(aoDespertou)

	-- Anel do selo: enche durante o intervalo entre giros
	RunService.RenderStepped:Connect(function()
		local falta = math.max(0, proximoGiro - os.clock())
		hud.definirCarga(1 - falta / INTERVALO)
	end)

	-- Atalho de teclado: E para despertar
	UserInputService.InputBegan:Connect(function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.E then
			task.spawn(girar)
		end
	end)

	-- Giro automático: o servidor valida o mesmo cooldown do giro manual
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
