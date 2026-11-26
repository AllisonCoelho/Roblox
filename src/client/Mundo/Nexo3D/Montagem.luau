-- Monta a praça do Nexo com o kit 3D, seguindo Cena.luau (gerado pelo Blender).
-- Tudo é local a este cliente: as peças visuais não colidem; a colisão vem de caixas simples
-- invisíveis (o personagem do jogador é simulado no próprio cliente, então elas valem para ele)
-- e do piso/pedestal provisórios do servidor, que continuam lá, só escondidos.
local Cena = require(script.Parent.Cena)
local Malha = require(script.Parent.Malha)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Carregamento = require(ReplicatedStorage.Shared.Dados.CarregamentoMapa)

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

local function preencher(pasta: Folder, prontas: Malha.Cache, pecas: { any }): Resultado
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

	for indice, dados in pecas do
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
		parte.CastShadow = not SEM_SOMBRA[dados.material]
		parte.Parent = pasta

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

-- Cada etapa é uma transação: uma falha distante preserva a praça já exibida.
-- O callback só recebe peças completas; não anima referências de uma etapa descartada.
function Montagem.construir(
	nexo: Instance,
	aoEtapa: ((Resultado, string) -> ())?
): (Resultado, string?)
	local pasta = Instance.new("Folder")
	pasta.Name = "Kit3D"
	pasta.Parent = nexo
	local prontas: Malha.Cache = {}
	local praca, mundo = Carregamento.dividir(Cena.pecas)
	local resultado: Resultado? = nil
	local falha: string? = nil
	for i, pecas in { praca, mundo } do
		local etapa = if i == 1 then "Praca" else "Mundo"
		local grupo = Instance.new("Folder")
		grupo.Name = etapa
		local ok, parcial = pcall(function()
			local montado = preencher(grupo, prontas, pecas)
			-- Só os assets publicados da praça são essenciais para a entrada.
			-- Não pré-carrega Workspace, Corredor, sons ou toda a coleção de auras.
			if i == 1 then
				local essenciais = {}
				for _, parte in grupo:GetChildren() do
					if parte:GetAttribute("MalhaPublicada") then
						table.insert(essenciais, parte)
					end
				end
				if #essenciais > 0 then
					local terminou, erro = false, nil
					task.spawn(function()
						local carregou, detalhe = pcall(function()
							ContentProvider:PreloadAsync(essenciais, function(id, status)
								if status ~= Enum.AssetFetchStatus.Success then
									erro = "Asset inacessível: "
										.. id
										.. " ("
										.. status.Name
										.. ")"
								end
							end)
						end)
						if not carregou then
							erro = tostring(detalhe)
						end
						terminou = true
					end)
					local limite = os.clock() + 8
					repeat
						task.wait()
					until terminou or os.clock() >= limite
					assert(
						terminou and not erro,
						erro or "Tempo limite ao carregar assets da praça"
					)
				end
			end
			return montado
		end)
		if not ok then
			grupo:Destroy()
			falha = tostring(parcial)
			break
		end
		grupo.Parent = pasta
		if resultado then
			for _, campo in { "estilhacos", "orbitas", "lanternas", "giram" } do
				for _, peca in (parcial :: any)[campo] do
					table.insert((resultado :: any)[campo], peca)
				end
			end
		else
			local primeiro = parcial :: Resultado
			primeiro.pasta = pasta
			resultado = primeiro
		end
		if aoEtapa then
			aoEtapa(resultado :: Resultado, etapa)
		end
		task.wait()
	end
	for _, pronta in prontas do
		pronta.modelo:Destroy()
	end
	if not resultado then
		pasta:Destroy()
		error(falha or "Praça indisponível", 0)
	end
	return resultado, falha
end

return Montagem
