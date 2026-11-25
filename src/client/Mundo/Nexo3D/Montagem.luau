-- Monta a praça do Nexo com o kit 3D, seguindo Cena.luau (gerado pelo Blender).
-- Tudo é local a este cliente: as peças visuais não colidem; a colisão vem de caixas simples
-- invisíveis (o personagem do jogador é simulado no próprio cliente, então elas valem para ele)
-- e do piso/pedestal provisórios do servidor, que continuam lá, só escondidos.
local Cena = require(script.Parent.Cena)
local Malha = require(script.Parent.Malha)

local Montagem = {}

export type Peca = {
	parte: MeshPart,
	pivo: CFrame, -- onde a peça foi colocada (base da peça)
	centro: Vector3, -- do pivô até o centro da malha, já com a escala
	tamanho: Vector3, -- tamanho original da parte (para pulsar)
	dados: { [string]: any }, -- a linha de Cena.pecas
}

export type Resultado = {
	pasta: Folder,
	centroCristal: Vector3,
	estilhacos: { Peca },
	nucleo: Peca?,
	orbitas: { Peca },
	lanternas: { Peca },
	giram: { Peca }, -- giram devagar em torno do próprio eixo (anel do Altar, eco do Arquivo)
}

local SEM_SOMBRA = { Neon = true, Glass = true }

local function preencher(pasta: Folder, prontas: Malha.Cache): Resultado
	local c = Cena.centroCristal
	local resultado: Resultado = {
		pasta = pasta,
		centroCristal = Vector3.new(c[1], c[2], c[3]),
		estilhacos = {},
		nucleo = nil,
		orbitas = {},
		lanternas = {},
		giram = {},
	}

	for indice, dados in Cena.pecas :: { { [string]: any } } do
		local parte, centroMalha = Malha.criar(dados.malha, prontas)
		parte.Parent = pasta
		local escala = dados.escala or 1
		local pos = dados.posicao
		local pivo = CFrame.new(pos[1], pos[2], pos[3])
			* CFrame.Angles(0, math.rad(dados.giro or 0), 0)
		local centro = centroMalha * escala
		local tamanho = parte.Size * escala
		parte.Size = tamanho
		parte.CFrame = pivo * CFrame.new(centro)
		parte.Material = (Enum.Material :: any)[dados.material] or Enum.Material.Slate
		parte.Transparency = dados.transparencia or 0
		parte.CastShadow = not SEM_SOMBRA[dados.material]

		local peca: Peca =
			{ parte = parte, pivo = pivo, centro = centro, tamanho = tamanho, dados = dados }
		if dados.grupo == "estilhaco" then
			table.insert(resultado.estilhacos, peca)
		elseif dados.grupo == "nucleo" then
			resultado.nucleo = peca
		elseif dados.grupo == "orbita" then
			table.insert(resultado.orbitas, peca)
		elseif dados.grupo == "lanterna" then
			table.insert(resultado.lanternas, peca)
		elseif dados.grupo == "gira" then
			table.insert(resultado.giram, peca)
		end

		-- Criar malhas custa tempo: cede o quadro de vez em quando para não travar a entrada
		if indice % 6 == 0 then
			task.wait()
		end
	end

	return resultado
end

-- Corredor dos Perdidos (CenaCorredor, gerada por assets/corredor). As ilhas flutuam alto no
-- céu: nenhuma peça projeta sombra (senão a praça inteira ficaria manchada lá embaixo).
export type ResultadoCorredor = {
	pasta: Folder,
	veus: { Peca },
	deriva: { Peca },
}

function Montagem.construirCorredor(pai: Instance): ResultadoCorredor
	local CenaCorredor = require(script.Parent.CenaCorredor)
	local pasta = Instance.new("Folder")
	pasta.Name = "KitCorredor"
	local prontas: Malha.Cache = {}
	local resultado: ResultadoCorredor = { pasta = pasta, veus = {}, deriva = {} }
	local ok, erro = pcall(function()
		for indice, dados in CenaCorredor.pecas :: { { [string]: any } } do
			local parte, centroMalha = Malha.criar(dados.malha, prontas)
			local escala = dados.escala or 1
			local pos = dados.posicao
			local pivo = CFrame.new(pos[1], pos[2], pos[3])
				* CFrame.Angles(0, math.rad(dados.giro or 0), 0)
			local centro = centroMalha * escala
			local tamanho = parte.Size * escala
			parte.Size = tamanho
			parte.CFrame = pivo * CFrame.new(centro)
			parte.Material = (Enum.Material :: any)[dados.material] or Enum.Material.Slate
			parte.Transparency = dados.transparencia or 0
			parte.CastShadow = false
			parte.Parent = pasta
			local peca: Peca =
				{ parte = parte, pivo = pivo, centro = centro, tamanho = tamanho, dados = dados }
			if dados.grupo == "veu" then
				table.insert(resultado.veus, peca)
			elseif dados.grupo == "deriva" then
				table.insert(resultado.deriva, peca)
			end
			if indice % 6 == 0 then
				task.wait()
			end
		end
	end)
	for _, pronta in prontas do
		pronta.modelo:Destroy()
	end
	if not ok then
		pasta:Destroy()
		error(erro, 0)
	end
	pasta.Parent = pai
	return resultado
end

-- Só coloca a pasta no mundo quando o kit inteiro estiver pronto.
function Montagem.construir(nexo: Instance): Resultado
	local pasta = Instance.new("Folder")
	pasta.Name = "Kit3D"
	local prontas: Malha.Cache = {}
	local ok, resultado = pcall(preencher, pasta, prontas)
	for _, pronta in prontas do
		pronta.modelo:Destroy()
	end
	if not ok then
		pasta:Destroy()
		error(resultado, 0)
	end
	pasta.Parent = nexo
	return resultado
end

return Montagem
