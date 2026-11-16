-- Malhas lisas das auras (geradas no Blender, guardadas em Dados/) viram MeshParts.
-- Mesmo formato compacto do kit do Nexo, mas com vértices compartilhados: a superfície sai lisa.
-- Cada peça pode ter também um CONTORNO de anime: uma casca um pouco maior com as faces
-- invertidas (a MeshPart descarta as faces de costas, então só a borda escura aparece).
local AssetService = game:GetService("AssetService")

local Malha = require(script.Parent.Parent:WaitForChild("Nexo3D"):WaitForChild("Malha"))

local MalhaNuvem = {}

type Dados = {
	vertices: number,
	triangulos: number,
	minimo: { number },
	tamanho: { number },
	dados: { string },
}

-- centro: centro da malha no espaço do HumanoidRootPart (R15 padrão, studs)
export type Pronta = { modelo: MeshPart, centro: Vector3 }

local pasta = script.Parent:WaitForChild("Dados")
local prontas: { [string]: Pronta } = {}
local ESPESSURA_CONTORNO = 0.035

local function construir(nome: string, contorno: boolean): Pronta
	local d = require(pasta:WaitForChild(nome)) :: Dados
	local nv, nt = d.vertices, d.triangulos
	local bytes = Malha.decodificar(d.dados, nv * 9 + nt * 6)
	local minimo = Vector3.new(d.minimo[1], d.minimo[2], d.minimo[3])
	local tamanho = Vector3.new(d.tamanho[1], d.tamanho[2], d.tamanho[3])

	local pos = table.create(nv)
	for i = 0, nv - 1 do
		local p = i * 6
		pos[i + 1] = minimo
			+ Vector3.new(
				buffer.readu16(bytes, p) / 65535 * tamanho.X,
				buffer.readu16(bytes, p + 2) / 65535 * tamanho.Y,
				buffer.readu16(bytes, p + 4) / 65535 * tamanho.Z
			)
	end
	local tris = table.create(nt)
	local normais = table.create(nv, Vector3.zero)
	local inicio = nv * 9
	for t = 0, nt - 1 do
		local p = inicio + t * 6
		local a = buffer.readu16(bytes, p) + 1
		local b = buffer.readu16(bytes, p + 2) + 1
		local c = buffer.readu16(bytes, p + 4) + 1
		tris[t + 1] = { a, b, c }
		-- normal da face pesada pela área: soma nos três vértices (normal lisa)
		local n = (pos[b] - pos[a]):Cross(pos[c] - pos[a])
		normais[a] += n
		normais[b] += n
		normais[c] += n
	end
	for i = 1, nv do
		local n = normais[i]
		normais[i] = if n.Magnitude > 1e-8 then n.Unit else Vector3.yAxis
	end
	if contorno then
		for i = 1, nv do
			pos[i] += normais[i] * ESPESSURA_CONTORNO
		end
	end

	-- caixa real (o contorno é um pouco maior que a malha original)
	local lo, hi = pos[1], pos[1]
	for i = 2, nv do
		lo = lo:Min(pos[i])
		hi = hi:Max(pos[i])
	end
	local centro = (lo + hi) / 2

	local editavel = AssetService:CreateEditableMesh()
	if not editavel then
		error("Limite de memória de EditableMesh ao criar " .. nome)
	end
	local ok, conteudo = pcall(function()
		local ids = table.create(nv)
		local nids = table.create(nv)
		local cids = table.create(nv)
		for i = 1, nv do
			ids[i] = editavel:AddVertex(pos[i] - centro)
			nids[i] = editavel:AddNormal(if contorno then -normais[i] else normais[i])
			if not contorno then
				local c = nv * 6 + (i - 1) * 3
				cids[i] = editavel:AddColor(
					Color3.fromRGB(
						buffer.readu8(bytes, c),
						buffer.readu8(bytes, c + 1),
						buffer.readu8(bytes, c + 2)
					),
					1
				)
			end
		end
		for _, t in tris do
			local a, b, c = t[1], t[2], t[3]
			if contorno then
				a, c = c, a -- faces invertidas: só a borda de trás aparece
			end
			local face = editavel:AddTriangle(ids[a], ids[b], ids[c])
			editavel:SetFaceNormals(face, { nids[a], nids[b], nids[c] })
			if not contorno then
				editavel:SetFaceColors(face, { cids[a], cids[b], cids[c] })
			end
		end
		local status, estatico =
			AssetService:CreateDataModelContentAsync(Content.fromObject(editavel))
		assert(status == Enum.CreateContentResult.Success and estatico, tostring(status))
		return estatico
	end)
	editavel:Destroy()
	if not ok then
		error("Falha ao converter a malha " .. nome .. ": " .. tostring(conteudo))
	end
	local parte = AssetService:CreateMeshPartAsync(conteudo, {
		CollisionFidelity = Enum.CollisionFidelity.Box,
	})
	parte.Name = nome .. (if contorno then "_contorno" else "")
	parte.Anchored = true
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.CastShadow = false
	parte.Massless = true
	return { modelo = parte, centro = centro }
end

-- Uma cópia nova da peça (as malhas são convertidas uma vez e compartilhadas entre jogadores).
-- Pode esperar (yield) na primeira vez.
function MalhaNuvem.criar(nome: string, contorno: boolean): (MeshPart, Vector3)
	local chave = nome .. (if contorno then "#c" else "")
	local pronta = prontas[chave]
	if not pronta then
		pronta = construir(nome, contorno)
		prontas[chave] = pronta
	end
	return pronta.modelo:Clone(), pronta.centro
end

return MalhaNuvem
