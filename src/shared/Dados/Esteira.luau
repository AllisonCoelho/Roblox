-- Regras da esteira da Fábrica (contas puras, usadas pelo servidor, pelo cliente e pelos testes).
-- A posição de cada Docinho é calculada pelo tempo: o servidor não precisa mandar a posição
-- a cada quadro e o cliente anima liso; para validar compras, o servidor faz a mesma conta.
local Catalogo = require(script.Parent.Catalogo)
local Mapa = require(script.Parent.Mapa)

local Esteira = {}

Esteira.Velocidade = 4 -- studs por segundo
Esteira.Intervalo = 2.5 -- segundos entre dois Docinhos
Esteira.DistanciaCompra = 14 -- distância máxima (studs) entre o jogador e o Docinho
Esteira.AvisarAPartirDe = 5 -- ordem da raridade (5 = Lendário) que avisa o servidor inteiro

-- Peso de cada raridade no sorteio (Secreto não sai na esteira)
Esteira.Pesos = {
	comum = 60,
	incomum = 25,
	raro = 10,
	epico = 4,
	lendario = 0.9,
	mitico = 0.1,
	secreto = 0,
}
-- Com a Esteira da Sorte ativa, raridades a partir de Raro pesam o dobro
Esteira.MultiplicadorSorte = 2
Esteira.SorteAPartirDe = 3

function Esteira.comprimento(): number
	return (Mapa.Esteira.fim - Mapa.Esteira.inicio).Magnitude
end

function Esteira.duracao(): number
	return Esteira.comprimento() / Esteira.Velocidade
end

-- Posição (no topo da esteira) de um Docinho que apareceu em "inicio", no instante "agora"
function Esteira.posicao(inicio: number, agora: number): Vector3
	local e = Mapa.Esteira
	local direcao = (e.fim - e.inicio).Unit
	local andou = math.clamp((agora - inicio) * Esteira.Velocidade, 0, Esteira.comprimento())
	return e.inicio + direcao * andou + Vector3.new(0, e.altura, 0)
end

-- Preço na esteira: preço do catálogo vezes o multiplicador da variante
function Esteira.preco(id: string, variante: string): number
	local d = Catalogo.docinho(id)
	local v = Catalogo.Variantes[variante]
	if not d or not v then
		return 0
	end
	return d.preco * v.multiplicador
end

-- A vitrine compra de volta por metade do preço da esteira (que já conta a variante)
Esteira.FracaoVenda = 0.5

function Esteira.valorVenda(id: string, variante: string): number
	return math.floor(Esteira.preco(id, variante) * Esteira.FracaoVenda)
end

-- Sorteia um Docinho e a variante. "aleatorio" devolve um número em [0, 1).
-- pesoSecreto: peso do Secreto (só a Chuva de Doces passa; na esteira ele nunca sai).
function Esteira.sortear(
	aleatorio: () -> number,
	sorte: boolean,
	pesoSecreto: number?
): (string, string)
	local pesos: { { id: string, peso: number } } = {}
	local total = 0
	for _, d in Catalogo.Lista do
		local r = Catalogo.Raridades[d.raridade]
		local peso = Esteira.Pesos[d.raridade] or 0
		if d.raridade == "secreto" and pesoSecreto then
			peso = pesoSecreto
		elseif sorte and r.ordem >= Esteira.SorteAPartirDe then
			peso *= Esteira.MultiplicadorSorte
		end
		if peso > 0 then
			-- Raridades com vários Docinhos dividem o peso entre eles
			local mesmos = 0
			for _, outro in Catalogo.Lista do
				if outro.raridade == d.raridade then
					mesmos += 1
				end
			end
			table.insert(pesos, { id = d.id, peso = peso / mesmos })
			total += peso / mesmos
		end
	end
	local alvo = aleatorio() * total
	local escolhido = pesos[#pesos].id
	for _, p in pesos do
		alvo -= p.peso
		if alvo < 0 then
			escolhido = p.id
			break
		end
	end
	-- Variante: Arco-íris (1 em 200) tem prioridade sobre Dourado (1 em 20)
	local variante = "normal"
	local rolagem = aleatorio()
	if rolagem < 1 / Catalogo.Variantes.arcoiris.chance then
		variante = "arcoiris"
	elseif rolagem < 1 / Catalogo.Variantes.dourado.chance then
		variante = "dourado"
	end
	return escolhido, variante
end

return Esteira
