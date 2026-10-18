-- Planta do mapa em studs (ver docs/design/03-mapa.png). Só dados e contas puras:
-- o servidor constrói o mundo a partir daqui e os testes conferem que nada se sobrepõe.
-- Eixos: X = esquerda/direita, Z = norte (negativo, fábrica) / sul (positivo, praça).
-- O chão (Baseplate) tem o topo em Y = 0.
local Mapa = {}

-- Fábrica no norte; a esteira sai dela e desce até perto da praça
Mapa.Fabrica = { centro = Vector3.new(0, 0, -82), tamanho = Vector3.new(44, 26, 20) }
Mapa.Esteira = {
	inicio = Vector3.new(0, 0, -71), -- ponto onde os Docinhos aparecem
	fim = Vector3.new(0, 0, 58), -- ponto onde somem
	largura = 10,
	altura = 3, -- topo da esteira
}

-- Vitrines (lotes dos jogadores). "frente" aponta para a esteira (onde fica o portão).
Mapa.LoteLargura = 40 -- ao longo da frente
Mapa.LoteProfundidade = 30 -- da frente até a parede do fundo
Mapa.Lotes = {
	{ centro = Vector3.new(-62, 0, -50), frente = Vector3.new(1, 0, 0) },
	{ centro = Vector3.new(-62, 0, -6), frente = Vector3.new(1, 0, 0) },
	{ centro = Vector3.new(-62, 0, 38), frente = Vector3.new(1, 0, 0) },
	{ centro = Vector3.new(62, 0, -50), frente = Vector3.new(-1, 0, 0) },
	{ centro = Vector3.new(62, 0, -6), frente = Vector3.new(-1, 0, 0) },
	{ centro = Vector3.new(62, 0, 38), frente = Vector3.new(-1, 0, 0) },
}

-- Pedestais: grade 7 x 4 (até 28 Docinhos, o máximo da Vitrine Maior nível 5)
Mapa.PedestalColunas = 7
Mapa.PedestalLinhas = 4
Mapa.PedestalEspaco = 5

-- Praça no sul: prédios que abrem telas da interface
Mapa.Praca = {
	{
		id = "Loja",
		nome = "Loja",
		tela = "Loja",
		centro = Vector3.new(-56, 0, 90),
		cor = "ouro",
		icone = "🛒",
	},
	{
		id = "Album",
		nome = "Docinhopédia",
		tela = "Album",
		centro = Vector3.new(-28, 0, 90),
		cor = "roxo",
		icone = "📖",
	},
	{
		id = "Codigos",
		nome = "Códigos",
		tela = "Codigos",
		centro = Vector3.new(28, 0, 90),
		cor = "azul",
		icone = "🎁",
	},
	{
		id = "Palco",
		nome = "Palco de Eventos",
		tela = nil,
		centro = Vector3.new(56, 0, 90),
		cor = "rosa",
		icone = "🎪",
	},
}
Mapa.PredioTamanho = Vector3.new(18, 14, 16)
Mapa.Nascimento = Vector3.new(0, 0, 90)

-- Metade do chão (Baseplate 256 x 256): tudo precisa caber aqui dentro
Mapa.LimiteChao = 128

-- CFrame do lote: posição no centro, LookVector = frente (para a esteira)
function Mapa.cframeLote(indice: number): CFrame
	local lote = Mapa.Lotes[indice]
	return CFrame.lookAt(lote.centro, lote.centro + lote.frente)
end

-- Posição local (relativa ao CFrame do lote) do pedestal i (1 = fundo à esquerda).
-- -Z local é a frente; as fileiras começam no fundo (+Z) e vêm para a frente.
function Mapa.pedestalLocal(i: number): Vector3
	local coluna = (i - 1) % Mapa.PedestalColunas
	local linha = (i - 1) // Mapa.PedestalColunas
	local x = (coluna - (Mapa.PedestalColunas - 1) / 2) * Mapa.PedestalEspaco
	local z = Mapa.LoteProfundidade / 2 - 4 - linha * Mapa.PedestalEspaco
	return Vector3.new(x, 0, z)
end

-- Caixa (coletar) e escudo ficam na frente, entre os pedestais e o portão
Mapa.CaixaLocal = Vector3.new(-8, 0, -10)
Mapa.EscudoLocal = Vector3.new(8, 0, -10)
Mapa.EntradaLocal = Vector3.new(0, 0, -12)

-- Um ponto (mundo) está dentro do lote? Usado para entregar o Docinho carregado.
function Mapa.dentroDoLote(indice: number, ponto: Vector3): boolean
	local localPonto = Mapa.cframeLote(indice):PointToObjectSpace(ponto)
	return math.abs(localPonto.X) <= Mapa.LoteLargura / 2
		and math.abs(localPonto.Z) <= Mapa.LoteProfundidade / 2
end

-- Retângulo ocupado no chão (min/max em X e Z), para conferir sobreposições nos testes
export type Retangulo = { nome: string, minX: number, maxX: number, minZ: number, maxZ: number }

local function retangulo(nome: string, centro: Vector3, tamX: number, tamZ: number): Retangulo
	return {
		nome = nome,
		minX = centro.X - tamX / 2,
		maxX = centro.X + tamX / 2,
		minZ = centro.Z - tamZ / 2,
		maxZ = centro.Z + tamZ / 2,
	}
end

function Mapa.retangulos(): { Retangulo }
	local lista = {}
	table.insert(
		lista,
		retangulo("Fabrica", Mapa.Fabrica.centro, Mapa.Fabrica.tamanho.X, Mapa.Fabrica.tamanho.Z)
	)
	local e = Mapa.Esteira
	local comprimento = math.abs(e.fim.Z - e.inicio.Z)
	local meioZ = (e.fim.Z + e.inicio.Z) / 2
	table.insert(
		lista,
		retangulo("Esteira", Vector3.new(e.inicio.X, 0, meioZ), e.largura, comprimento)
	)
	for i, lote in Mapa.Lotes do
		-- Lote virado para X: a largura fica ao longo de Z e a profundidade ao longo de X
		local tamX = if lote.frente.X ~= 0 then Mapa.LoteProfundidade else Mapa.LoteLargura
		local tamZ = if lote.frente.X ~= 0 then Mapa.LoteLargura else Mapa.LoteProfundidade
		table.insert(lista, retangulo("Lote" .. i, lote.centro, tamX, tamZ))
	end
	for _, p in Mapa.Praca do
		table.insert(lista, retangulo(p.id, p.centro, Mapa.PredioTamanho.X, Mapa.PredioTamanho.Z))
	end
	return lista
end

return Mapa
