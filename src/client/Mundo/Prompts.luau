-- "Aperte E" do mundo: comprar Docinhos na esteira e abrir telas nos prédios da praça
local ProximityPromptService = game:GetService("ProximityPromptService")

local UI = script.Parent.Parent:WaitForChild("UI")
local Estado = require(UI.Estado)
local Navegacao = require(UI.Navegacao)
local Avisos = require(UI.Popups.Avisos)

local Prompts = {}

local comprando = false

function Prompts.iniciar()
	local pastaEsteira = workspace:WaitForChild("Esteira")
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		-- Prédios da praça: o atributo "Tela" diz qual painel abrir
		local tela = prompt:GetAttribute("Tela")
		if type(tela) == "string" then
			Navegacao.abrir(tela)
			return
		end
		-- Docinho da esteira: o servidor confere distância, moedas e espaço na vitrine
		if prompt:IsDescendantOf(pastaEsteira) and not comprando then
			local modelo = prompt:FindFirstAncestorOfClass("Model")
			local uid = modelo and modelo:GetAttribute("Uid")
			if type(uid) ~= "number" then
				return
			end
			comprando = true
			local ok, msg = Estado.pedir("ComprarDaEsteira", uid)
			comprando = false
			if not ok then
				Avisos.mostrar("erro", msg or "Não deu para comprar")
			end
		end
	end)
end

return Prompts
