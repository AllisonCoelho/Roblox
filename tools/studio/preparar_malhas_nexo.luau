-- Executar na Command Bar do Studio em modo Edit, após importar os FBX próprios.
-- Selecione a pasta/modelo que contém as MeshParts importadas, com nomes de Dados/*.luau.
-- Não faz upload nem publica o jogo. Exporte a pasta resultante como .rbxmx para o Git.
local Selection = game:GetService("Selection")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Dados = StarterPlayer.StarterPlayerScripts.Client.Mundo.Nexo3D.Dados
local selecionados = Selection:Get()
assert(#selecionados == 1, "Selecione uma pasta/modelo com as malhas importadas")
local saida = Instance.new("Folder")
saida.Name = "NexoMalhasPreparadas"
local contagem = 0
for _, parte in selecionados[1]:GetDescendants() do
	if parte:IsA("MeshPart") then
		local modulo = Dados:FindFirstChild(parte.Name)
		assert(modulo, "Nome sem dados correspondentes: " .. parte.Name)
		assert(not saida:FindFirstChild(parte.Name), "Nome duplicado: " .. parte.Name)
		assert(parte.MeshId ~= "", "Publique a malha antes: " .. parte.Name)
		local d = require(modulo)
		local tamanho = Vector3.new(unpack(d.tamanho))
		local centro = Vector3.new(unpack(d.minimo)) + tamanho / 2
		local copia = parte:Clone()
		-- Evita levar scripts ou conteúdo estranho junto com os templates.
		copia:ClearAllChildren()
		copia.Size = tamanho
		copia.CFrame = CFrame.new()
		copia.Anchored = true
		copia.CanCollide = false
		copia.CanQuery = false
		copia.CanTouch = false
		copia:SetAttribute("CentroMalha", centro)
		copia.Parent = saida
		contagem += 1
	end
end
assert(contagem > 0, "Nenhuma MeshPart encontrada")
saida.Parent = ReplicatedStorage
Selection:Set({ saida })
print(
	string.format(
		"%d templates preparados. Salve os FILHOS como .rbxmx em assets/roblox/NexoMalhas; teste os MeshIds na experiência privada.",
		contagem
	)
)
