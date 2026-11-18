local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")
local Shared = game:GetService("ReplicatedStorage").Shared

local Icones = require(Shared.Dados.Icones)
local Dados = require(script.Parent.DadosAtlasOrbita)

local IconeImagem = {}
local atlas: Content? = nil
local tentou = false
local tamanho = Vector2.new(Dados.celula, Dados.celula)

local function carregar(): Content?
	if not tentou then
		tentou = true
		local ok, conteudo = pcall(function()
			local comprimido =
				EncodingService:Base64Decode(buffer.fromstring((string.gsub(Dados.rgba, "%s", ""))))
			local rgba =
				EncodingService:DecompressBuffer(comprimido, Enum.CompressionAlgorithm.Zstd)
			local lado = Dados.celula * Icones.COLUNAS
			local dimensoes = Vector2.new(lado, lado)
			local imagem = AssetService:CreateEditableImage({ Size = dimensoes })
			if not imagem then
				return nil
			end
			imagem:WritePixelsBuffer(Vector2.zero, dimensoes, rgba)
			return Content.fromObject(imagem)
		end)
		if ok then
			atlas = conteudo
		end
		if not atlas then
			warn("[HUD] Atlas de ícones indisponível neste cliente.")
		end
	end
	return atlas
end

function IconeImagem.definir(imagem: ImageLabel, indice: number)
	local i = indice - 1
	imagem.ImageRectOffset =
		Vector2.new((i % Icones.COLUNAS) * Dados.celula, (i // Icones.COLUNAS) * Dados.celula)
end

function IconeImagem.criar(
	pai: Instance,
	indice: number,
	posicao: UDim2,
	dimensoes: UDim2
): ImageLabel
	local imagem = Instance.new("ImageLabel")
	imagem.Name = "Icone"
	imagem.BackgroundTransparency = 1
	imagem.Position = posicao
	imagem.Size = dimensoes
	imagem.ScaleType = Enum.ScaleType.Fit
	imagem.ImageRectSize = tamanho
	IconeImagem.definir(imagem, indice)
	local conteudo = carregar()
	if conteudo then
		imagem.ImageContent = conteudo
	end
	imagem.Parent = pai
	return imagem
end

return IconeImagem
