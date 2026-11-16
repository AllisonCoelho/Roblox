-- Monta a interface do Despertar e controla o giro (manual e automático).
-- O cliente só pede: o resultado do sorteio sempre vem do servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Config = require(Shared.Config)
local Escala = require(script.Parent.Escala)
local Estado = require(script.Parent.Estado)
local Navegacao = require(script.Parent.Navegacao)
local Telas = script.Parent:WaitForChild("Telas")
local Avisos = require(Telas.Avisos)
local HUD = require(Telas.HUD)
local Indice = require(Telas.Indice)
local Revelacao = require(Telas.Revelacao)

local App = {}

-- Pequena folga além do cooldown do servidor para não ter pedidos recusados
local FOLGA = 0.05

local girando = false
local proximoGiro = 0
local hud: HUD.Api

local function girar(automatico: boolean)
	if girando or os.clock() < proximoGiro then
		return
	end
	girando = true
	proximoGiro = os.clock() + Config.CooldownGiro + FOLGA
	hud.definirPronto(false)
	local ok, resposta = Estado.pedir("Despertar")
	if ok and resposta then
		local aura = Auras.porId[resposta]
		if aura then
			Revelacao.mostrar(aura, automatico)
		end
	elseif resposta then
		Avisos.toast(resposta)
	end
	girando = false
	task.delay(math.max(0, proximoGiro - os.clock()), function()
		if not girando then
			hud.definirPronto(true)
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
			task.spawn(girar, false)
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
	Avisos.montar(raiz)
	Indice.montar(Avisos.toast)
	Navegacao.ajustar()

	Estado.aoMudar(hud.atualizar)
	Estado.iniciar()

	-- Atalho de teclado: E para despertar
	UserInputService.InputBegan:Connect(function(input, processado)
		if not processado and input.KeyCode == Enum.KeyCode.E then
			task.spawn(girar, false)
		end
	end)

	-- Giro automático: o servidor valida o mesmo cooldown do giro manual
	task.spawn(function()
		while true do
			task.wait(0.1)
			local estado = Estado.atual
			if
				estado
				and estado.configuracoes.giroAutomatico
				and not girando
				and os.clock() >= proximoGiro
			then
				task.spawn(girar, true)
			end
		end
	end)
end

return App
