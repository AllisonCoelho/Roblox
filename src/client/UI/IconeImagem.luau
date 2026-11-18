local Dados = require(script.Parent.DadosAtlasOrbita)

local IconeImagem = {}
local modelos: { [number]: Frame } = {}
local LADO = Dados.lado

local function modelo(indice: number): Frame
	local pronto = modelos[indice]
	if pronto then
		return pronto
	end

	local dados = Dados.desenhos[indice]
	local paleta, retangulos = dados[1], dados[2]
	local cores = {}
	for i = 1, #paleta, 6 do
		table.insert(cores, Color3.fromHex(string.sub(paleta, i, i + 5)))
	end

	local imagem = Instance.new("Frame")
	imagem.Name = "Arte"
	imagem.BackgroundTransparency = 1
	imagem.AnchorPoint = Vector2.new(0.5, 0.5)
	imagem.Position = UDim2.fromScale(0.5, 0.5)
	imagem.Size = UDim2.fromScale(1, 1)
	local aspecto = Instance.new("UIAspectRatioConstraint")
	aspecto.AspectType = Enum.AspectType.FitWithinMaxSize
	aspecto.Parent = imagem
	for i = 1, #retangulos, 5 do
		local x, y, largura, altura, cor = string.byte(retangulos, i, i + 4)
		local trecho = Instance.new("Frame")
		trecho.BorderSizePixel = 0
		trecho.BackgroundColor3 = cores[cor - 64]
		trecho.Position = UDim2.fromScale((x - 65) / LADO, (y - 65) / LADO)
		trecho.Size = UDim2.fromScale((largura - 65) / LADO, (altura - 65) / LADO)
		trecho.Parent = imagem
	end

	modelos[indice] = imagem
	return imagem
end

function IconeImagem.definir(quadro: Frame, indice: number, cor: Color3?)
	if
		quadro:GetAttribute("Indice") == indice
		and (quadro:GetAttribute("Cor") :: Color3?) == cor
	then
		return
	end
	quadro:SetAttribute("Indice", indice)
	quadro:SetAttribute("Cor", cor)

	local anterior = quadro:FindFirstChild("Arte")
	if anterior then
		anterior:Destroy()
	end
	local imagem = modelo(indice):Clone()
	if cor then
		for _, trecho in imagem:GetChildren() do
			if trecho:IsA("Frame") then
				trecho.BackgroundColor3 = trecho.BackgroundColor3:Lerp(cor, 0.72)
			end
		end
	end
	imagem.Parent = quadro
end

function IconeImagem.criar(pai: Instance, indice: number, posicao: UDim2, dimensoes: UDim2): Frame
	local quadro = Instance.new("Frame")
	quadro.Name = "Icone"
	quadro.BackgroundTransparency = 1
	quadro.Position = posicao
	quadro.Size = dimensoes
	IconeImagem.definir(quadro, indice)
	quadro.Parent = pai
	return quadro
end

return IconeImagem
