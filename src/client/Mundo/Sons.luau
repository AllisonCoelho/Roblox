-- Sons do ritual. Usa apenas sons que já vêm com o Roblox (rbxasset), para não depender de
-- nenhum asset enviado nem de áudio de terceiros. Para trocar por sons próprios, basta colocar
-- o "rbxassetid://..." na tabela abaixo. Um id vazio simplesmente não toca.
local Debris = game:GetService("Debris")

local Sons = {}

Sons.Ids = {
	chamado = "rbxasset://sounds/electronicpingshort.wav",
	batida = "rbxasset://sounds/clickfast.wav",
	instavel = "rbxasset://sounds/bass.wav",
	ruptura = "rbxasset://sounds/Rocket shot.wav",
	estilhaco = "rbxasset://sounds/glassbreak.wav",
	revelacao = "rbxasset://sounds/flashbulb.wav",
}

Sons.ligado = true

-- Toca um som curto preso a `pai` (3D) e o remove sozinho
function Sons.tocar(nome: string, pai: Instance, tom: number?, volume: number?)
	local id = Sons.Ids[nome]
	if not Sons.ligado or not id or id == "" then
		return
	end
	local som = Instance.new("Sound")
	som.SoundId = id
	som.PlaybackSpeed = tom or 1
	som.Volume = volume or 0.5
	som.RollOffMaxDistance = 120
	som.Parent = pai
	som:Play()
	Debris:AddItem(som, 4)
end

return Sons
