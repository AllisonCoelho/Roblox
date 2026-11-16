-- Transforma as peças do kit 3D (modeladas no Blender, guardadas em Dados/) em MeshParts.
-- A geometria é criada em tempo de execução com EditableMesh, então o cenário vem inteiro do
-- repositório: não depende de asset enviado ao Roblox nem de nada colocado à mão no Studio.
-- EditableMesh não replica: por isso a montagem acontece em cada cliente.
local AssetService = game:GetService("AssetService")

local Malha = {}

export type Dados = {
	vertices: number,
	triangulos: number,
	minimo: { number },
	tamanho: { number },
	dados: { string },
}

type Pronta = { editavel: EditableMesh, centro: Vector3 }

local pasta = script.Parent:WaitForChild("Dados")
local prontas: { [string]: Pronta } = {}

local ALFABETO = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALOR: { [number]: number } = {}
for i = 1, #ALFABETO do
	VALOR[string.byte(ALFABETO, i)] = i - 1
end

-- Base64 (em pedaços de tamanho múltiplo de 4) -> buffer
local function decodificar(pedacos: { string }, bytes: number): buffer
	local saida = buffer.create(bytes)
	local posicao = 0
	for _, pedaco in pedacos do
		for i = 1, #pedaco, 4 do
			local a, b, c, d = string.byte(pedaco, i, i + 3)
			local n = VALOR[a] * 262144 + VALOR[b] * 4096 + (VALOR[c] or 0) * 64 + (VALOR[d] or 0)
			if posicao < bytes then
				buffer.writeu8(saida, posicao, bit32.rshift(n, 16))
			end
			if posicao + 1 < bytes then
				buffer.writeu8(saida, posicao + 1, bit32.band(bit32.rshift(n, 8), 255))
			end
			if posicao + 2 < bytes then
				buffer.writeu8(saida, posicao + 2, bit32.band(n, 255))
			end
			posicao += 3
		end
	end
	return saida
end

-- Monta (uma vez por peça) o EditableMesh. Os vértices não são compartilhados entre faces,
-- então as normais automáticas dão o sombreado facetado do kit.
local function preparar(nome: string): Pronta
	local pronta = prontas[nome]
	if pronta then
		return pronta
	end
	local d = require(pasta:WaitForChild(nome)) :: Dados
	local nv, nt = d.vertices, d.triangulos
	local dados = decodificar(d.dados, nv * 9 + nt * 6)
	local minimo = Vector3.new(d.minimo[1], d.minimo[2], d.minimo[3])
	local tamanho = Vector3.new(d.tamanho[1], d.tamanho[2], d.tamanho[3])
	local centro = minimo + tamanho / 2

	local editavel = AssetService:CreateEditableMesh()
	local vertices = table.create(nv)
	local cores = table.create(nv)
	for i = 0, nv - 1 do
		local p = i * 6
		-- posições relativas ao centro da caixa: a peça fica centrada na MeshPart
		vertices[i + 1] = editavel:AddVertex(
			Vector3.new(
				(buffer.readu16(dados, p) / 65535 - 0.5) * tamanho.X,
				(buffer.readu16(dados, p + 2) / 65535 - 0.5) * tamanho.Y,
				(buffer.readu16(dados, p + 4) / 65535 - 0.5) * tamanho.Z
			)
		)
		local c = nv * 6 + i * 3
		cores[i + 1] = editavel:AddColor(
			Color3.fromRGB(
				buffer.readu8(dados, c),
				buffer.readu8(dados, c + 1),
				buffer.readu8(dados, c + 2)
			),
			1
		)
	end
	local inicio = nv * 9
	for t = 0, nt - 1 do
		local p = inicio + t * 6
		local a = buffer.readu16(dados, p) + 1
		local b = buffer.readu16(dados, p + 2) + 1
		local c = buffer.readu16(dados, p + 4) + 1
		local face = editavel:AddTriangle(vertices[a], vertices[b], vertices[c])
		editavel:SetFaceColors(face, { cores[a], cores[b], cores[c] })
	end
	pronta = { editavel = editavel, centro = centro }
	prontas[nome] = pronta
	return pronta
end

-- Cria uma MeshPart da peça. Devolve a parte e o deslocamento do centro da malha em relação
-- ao pivô da peça (a base, como foi modelada). Pode gerar erro: quem chama usa pcall.
function Malha.criar(nome: string): (MeshPart, Vector3)
	local pronta = preparar(nome)
	local parte = AssetService:CreateMeshPartAsync(Content.fromObject(pronta.editavel), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
	})
	parte.Name = nome
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	return parte, pronta.centro
end

return Malha
