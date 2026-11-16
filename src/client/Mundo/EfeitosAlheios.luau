-- Preferência local "ocultar efeitos dos outros jogadores": desliga, só neste cliente, as
-- partículas, luzes e contornos das auras equipadas pelos outros. Não altera o gameplay.
local Players = game:GetService("Players")

local EfeitosAlheios = {}

local NOME_AURA = "AuraDespertar" -- mesmo nome usado por Servicos/AuraVisual no servidor
local ocultar = false
local conexoes: { [Player]: { RBXScriptConnection } } = {}

local function aplicar(inst: Instance)
	local daAura = inst.Name == NOME_AURA or (inst.Parent ~= nil and inst.Parent.Name == NOME_AURA)
	if not daAura then
		return
	end
	if inst:IsA("ParticleEmitter") then
		inst.Enabled = not ocultar
	elseif inst:IsA("Light") then
		inst.Enabled = not ocultar
	elseif inst:IsA("Highlight") then
		inst.Enabled = not ocultar
	end
end

local function aplicarPersonagem(personagem: Model)
	for _, inst in personagem:GetDescendants() do
		aplicar(inst)
	end
end

local function observar(jogador: Player)
	if jogador == Players.LocalPlayer then
		return
	end
	local lista = {}
	local function ligar(personagem: Model)
		aplicarPersonagem(personagem)
		table.insert(
			lista,
			personagem.DescendantAdded:Connect(function(inst)
				if ocultar then
					-- espera o servidor terminar de montar a aura antes de desligar
					task.defer(aplicar, inst)
				end
			end)
		)
	end
	table.insert(lista, jogador.CharacterAdded:Connect(ligar))
	if jogador.Character then
		ligar(jogador.Character)
	end
	conexoes[jogador] = lista
end

function EfeitosAlheios.definir(valor: boolean)
	if ocultar == valor then
		return
	end
	ocultar = valor
	for jogador in conexoes do
		if jogador.Character then
			aplicarPersonagem(jogador.Character)
		end
	end
end

function EfeitosAlheios.iniciar()
	Players.PlayerAdded:Connect(observar)
	for _, jogador in Players:GetPlayers() do
		observar(jogador)
	end
	Players.PlayerRemoving:Connect(function(jogador)
		local lista = conexoes[jogador]
		if lista then
			for _, c in lista do
				c:Disconnect()
			end
		end
		conexoes[jogador] = nil
	end)
end

return EfeitosAlheios
