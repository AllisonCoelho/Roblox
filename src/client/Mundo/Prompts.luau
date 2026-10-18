-- "Aperte E" do mundo: comprar Docinhos na esteira, resgatar nas vitrines dos outros
-- e abrir telas nos prédios da praça. Quem decide tudo é o servidor; aqui só pedimos
-- e escondemos os botões que com certeza não valeriam (para não confundir as crianças).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Avisos = require(UI.Popups.Avisos)

local Prompts = {}

local player = Players.LocalPlayer
local pedindo = false

local function loteDe(prompt: ProximityPrompt): Model?
	local atual: Instance? = prompt.Parent
	while atual and atual ~= workspace do
		if
			atual:IsA("Model")
			and atual:GetAttribute("Indice") ~= nil
			and atual:GetAttribute("Dono") ~= nil
		then
			return atual
		end
		atual = atual.Parent
	end
	return nil
end

-- "Resgatar" só aparece na vitrine de outro jogador, com escudo desligado e mãos livres
local function resgateVisivel(prompt: ProximityPrompt): boolean
	local lote = loteDe(prompt)
	if not lote then
		return false
	end
	local dono = lote:GetAttribute("Dono")
	local escudoAte = lote:GetAttribute("EscudoAte")
	local protegida = type(escudoAte) == "number" and escudoAte > Estado.agora()
	return dono ~= 0
		and dono ~= player.UserId
		and not protegida
		and player:GetAttribute("Carregando") == nil
end

local function atualizarResgates(pastaVitrines: Instance)
	for _, d in pastaVitrines:GetDescendants() do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Slot") ~= nil then
			d.Enabled = resgateVisivel(d)
		end
	end
end

local function pedir(acao: string, ...: any)
	if pedindo then
		return
	end
	pedindo = true
	local ok, msg = Estado.pedir(acao, ...)
	pedindo = false
	if msg and msg ~= "" then
		Avisos.mostrar(if ok then "sucesso" else "erro", msg)
	elseif not ok then
		Avisos.mostrar("erro", "Não deu certo")
	end
end

function Prompts.iniciar()
	local pastaEsteira = workspace:WaitForChild("Esteira")
	local pastaVitrines = workspace:WaitForChild("Vitrines")

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		-- Prédios da praça: o atributo "Tela" diz qual painel abrir
		local tela = prompt:GetAttribute("Tela")
		if type(tela) == "string" then
			Navegacao.abrir(tela)
			return
		end
		-- Docinho da esteira: o servidor confere distância, moedas e espaço na vitrine
		if prompt:IsDescendantOf(pastaEsteira) then
			local modelo = prompt:FindFirstAncestorOfClass("Model")
			local uid = modelo and modelo:GetAttribute("Uid")
			if type(uid) == "number" then
				pedir("ComprarDaEsteira", uid)
			end
			return
		end
		-- Docinho na vitrine de outro jogador: resgate (regras em Shared/Dados/Resgate.luau)
		local slot = prompt:GetAttribute("Slot")
		local lote = loteDe(prompt)
		if type(slot) == "number" and lote then
			pedir("Resgatar", lote:GetAttribute("Indice"), slot)
		end
	end)

	pastaVitrines.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") and d:GetAttribute("Slot") ~= nil then
			d.Enabled = resgateVisivel(d)
		end
	end)
	player:GetAttributeChangedSignal("Carregando"):Connect(function()
		atualizarResgates(pastaVitrines)
	end)
	-- O escudo liga e desliga com o tempo: confere duas vezes por segundo
	task.spawn(function()
		while true do
			atualizarResgates(pastaVitrines)
			task.wait(0.5)
		end
	end)
end

return Prompts
