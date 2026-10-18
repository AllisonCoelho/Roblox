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
-- (Ela será criada pela parte de jogabilidade; até lá o botão só avisa.)
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

local function irParaVitrine()
	local v = minhaVitrine()
	local personagem = player.Character
	if not v or not personagem then
		Avisos.mostrar("info", "Sua vitrine aparece quando o mapa estiver pronto!")
		return
	end
	Navegacao.fechar()
	personagem:PivotTo(v:GetPivot() * CFrame.new(0, 5, 8))
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
			Chuva.mostrar()
		elseif tecla == Enum.KeyCode.F4 then
			Tutorial.mostrar()
		elseif tecla == Enum.KeyCode.F5 then
			Estado.pedir("TesteAvisoRaro")
		elseif tecla == Enum.KeyCode.F6 then
			player:SetAttribute(
				"Carregando",
				if player:GetAttribute("Carregando") then nil else "pudim"
			)
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

	teclasDeTeste()
end

return App
