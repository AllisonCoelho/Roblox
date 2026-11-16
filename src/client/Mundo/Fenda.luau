-- A ruptura do mundo: uma fenda vertical que o personagem rasga com as mãos.
-- Duas bordas quebradas e incandescentes (Beams) que se afastam, com um vazio escuro no meio
-- e um fio de energia no centro. Leve: 16 anexos, 14 feixes e 8 peças finas.
local Fenda = {}

export type Controle = {
	-- cf: centro da fenda, de frente para onde o personagem olha. abertura: 0 (fechada) a 1.
	atualizar: (cf: CFrame, abertura: number) -> (),
}

local SEGMENTOS = 7
local BRANCO = Color3.new(1, 1, 1)

local function peca(pai: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = pai
	return p
end

-- largura/altura: tamanho da fenda totalmente aberta, em studs
function Fenda.criar(
	pai: Instance,
	corBorda: Color3,
	corEnergia: Color3,
	largura: number,
	altura: number
): Controle
	local suporte =
		peca(pai, { Name = "Fenda", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
	local rng = Random.new()
	-- Perfil em amêndoa com dentes: irregular, mas fixo durante toda a cena
	local perfil: { number } = {}
	for k = 0, SEGMENTOS do
		local v = k / SEGMENTOS
		perfil[k] = math.sin(math.pi * v) ^ 0.7 * (1 + rng:NextNumber(-0.28, 0.28))
	end
	local lados: { { Attachment } } = { {}, {} }
	for lado = 1, 2 do
		for k = 0, SEGMENTOS do
			local anexo = Instance.new("Attachment")
			anexo.Parent = suporte
			lados[lado][k] = anexo
		end
		for k = 0, SEGMENTOS - 1 do
			local feixe = Instance.new("Beam")
			feixe.Attachment0 = lados[lado][k]
			feixe.Attachment1 = lados[lado][k + 1]
			feixe.Color = ColorSequence.new(BRANCO:Lerp(corBorda, 0.35))
			feixe.Width0, feixe.Width1 = 0.2, 0.2
			feixe.LightEmission = 1
			feixe.LightInfluence = 0
			feixe.FaceCamera = true
			feixe.Segments = 1
			feixe.Parent = suporte
		end
	end
	-- Vazio: uma faixa escura por segmento, entre as duas bordas
	local vazio: { Part } = {}
	for k = 1, SEGMENTOS do
		vazio[k] = peca(pai, {
			Name = "Vazio",
			Material = Enum.Material.SmoothPlastic,
			Color = corEnergia:Lerp(Color3.new(0, 0, 0), 0.88),
			Size = Vector3.new(0.05, 0.05, 0.05),
		})
	end
	local fio = peca(pai, {
		Name = "Fio",
		Material = Enum.Material.Neon,
		Color = corEnergia,
		Size = Vector3.new(0.05, 0.05, 0.05),
	})
	local luz = Instance.new("PointLight")
	luz.Color = corBorda
	luz.Range = 10 + altura
	luz.Brightness = 0
	luz.Parent = suporte

	return {
		atualizar = function(cf: CFrame, abertura: number)
			abertura = math.clamp(abertura, 0, 1)
			local visivel = abertura > 0.01
			local transparencia = if visivel then 0 else 1
			-- A fenda ganha altura logo no começo e só depois largura
			local alto = altura * (0.3 + 0.7 * math.min(abertura * 3, 1))
			local meia = largura / 2 * abertura
			suporte.CFrame = cf
			for k = 0, SEGMENTOS do
				local y = (k / SEGMENTOS - 0.5) * alto
				local x = meia * perfil[k]
				lados[1][k].Position = Vector3.new(-x, y, 0)
				lados[2][k].Position = Vector3.new(x, y, 0)
			end
			for k = 1, SEGMENTOS do
				local y0 = ((k - 1) / SEGMENTOS - 0.5) * alto
				local y1 = (k / SEGMENTOS - 0.5) * alto
				local x = meia * (perfil[k - 1] + perfil[k]) / 2
				local faixa = vazio[k]
				faixa.Size = Vector3.new(math.max(x * 2, 0.05), y1 - y0 + 0.02, 0.05)
				faixa.CFrame = cf * CFrame.new(0, (y0 + y1) / 2, 0.06)
				faixa.Transparency = transparencia
			end
			fio.Size = Vector3.new(math.max(0.1 * abertura, 0.04), alto * 0.9, 0.04)
			fio.CFrame = cf * CFrame.new(0, 0, 0.03)
			fio.Transparency = transparencia
			luz.Brightness = 4 * abertura
			for _, filho in suporte:GetChildren() do
				if filho:IsA("Beam") then
					filho.Enabled = visivel
				end
			end
		end,
	}
end

return Fenda
