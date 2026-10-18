-- Monta toda a interface dos Docinhos
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Estado = require(script.Parent.Estado)
local Escala = require(script.Parent.Escala)
local Visual = require(script.Parent.Visual)
local Navegacao = require(script.Parent.Navegacao)
local Telas = script.Parent.Telas
local Popups = script.Parent.Popups
local HUD = require(Telas.HUD)
local Avisos = require(Popups.Avisos)
local NovoDocinho = require(Popups.NovoDocinho)
local Resgate = require(Popups.Resgate)
local Chuva = require(Popups.Chuva)
local Tutorial = require(Popups.Tutorial)

local App = {}

local player = Players.LocalPlayer

-- A vitrine do jogador é um Model/Part dentro de workspace.Vitrines com o atributo Dono = UserId.
-- Aqui ela só é lida para a seta do HUD; ir até ela é pedido ao servidor.
local function minhaVitrine(): PVInstance?
	local pasta = workspace:FindFirstChild("Vitrines")
	if not pasta then
		return nil
	end
	for _, v in pasta:GetChildren() do
		if v:GetAttribute("Dono") == player.UserId and v:IsA("PVInstance") then
			return v
		end
	end
	return nil
end

local function posicaoVitrine(): Vector3?
	local v = minhaVitrine()
	return v and v:GetPivot().Position
end

-- Quem move o personagem é o servidor (ele confere dono da vitrine, intervalo e estado)
local function irParaVitrine()
	Navegacao.fechar()
	local ok, msg = Estado.pedir("IrParaVitrine")
	if not ok and msg then
		Avisos.mostrar("info", msg)
	end
end

-- Teclas de teste (só no Studio com Config.ModoTeste)
local function teclasDeTeste()
	if not (RunService:IsStudio() and Config.ModoTeste) then
		return
	end
	UserInputService.InputBegan:Connect(function(input, processado)
		if processado then
			return
		end
		local tecla = input.KeyCode
		if tecla == Enum.KeyCode.F1 then
			Avisos.resultado(Estado.pedir("TesteDocinho"))
		elseif tecla == Enum.KeyCode.F2 then
			Estado.pedir("TesteResgate")
		elseif tecla == Enum.KeyCode.F3 then
			-- Liga a chuva de verdade por 60 s (a faixa aparece sozinha)
			Avisos.resultado(Estado.pedir("TesteChuva"))
		elseif tecla == Enum.KeyCode.F4 then
			Tutorial.mostrar()
		elseif tecla == Enum.KeyCode.F5 then
			Estado.pedir("TesteAvisoRaro")
		elseif tecla == Enum.KeyCode.F7 then
			Avisos.resultado(Estado.pedir("TesteEsteiraRaro"))
		end
	end)
end

function App.iniciar()
	Estado.iniciar()
	Visual.iniciar()

	local gui = Instance.new("ScreenGui")
	gui.Name = "Docinhos"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local raiz = Escala.montar(gui)
	HUD.montar(raiz, {
		abrir = Navegacao.abrir,
		irParaVitrine = irParaVitrine,
		posicaoVitrine = posicaoVitrine,
	})
	Navegacao.montar(raiz)
	require(Telas.Loja).montar()
	require(Telas.MeusDocinhos).montar()
	require(Telas.Album).montar(HUD.marcarAlbumVisto)
	require(Telas.Missoes).montar()
	require(Telas.Presentes).montar()
	require(Telas.Codigos).montar()
	require(Telas.Ajustes).montar()
	Navegacao.ajustar()

	Tutorial.montar(raiz)
	Chuva.montar(raiz)
	Resgate.montar(raiz, irParaVitrine)
	NovoDocinho.montar(raiz)
	Avisos.montar(raiz)

	-- Mundo: esteira animada e os "aperte E" (esperam o mapa que o servidor constrói)
	local Mundo = script.Parent.Parent:WaitForChild("Mundo")
	task.spawn(require(Mundo.EsteiraVisual).iniciar)
	task.spawn(require(Mundo.Prompts).iniciar)
	task.spawn(require(Mundo.ChuvaVisual).iniciar)

	teclasDeTeste()
end

return App
