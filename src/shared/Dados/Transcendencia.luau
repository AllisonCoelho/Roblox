local Itens = require(script.Parent.Itens)

local Transcendencia = {}

local CUSTOS: { Itens.Estoque } = {
	{ coracao_ressonancia = 1 },
	{ coracao_ressonancia = 2, brasa_arauto = 1 },
	{ coracao_ressonancia = 2, brasa_arauto = 2 },
	{ coracao_ressonancia = 2, perola_abissal = 1 },
	{ coracao_ressonancia = 3, perola_abissal = 2, sal_mare_morta = 6 },
	{ coracao_ressonancia = 3, perola_abissal = 3, sal_mare_morta = 12 },
	{ coracao_ressonancia = 3, veu_ocaso = 1, po_umbral = 8 },
	{ coracao_ressonancia = 4, veu_ocaso = 2, po_umbral = 12, fragmento_instavel = 4 },
	{ coracao_ressonancia = 4, veu_ocaso = 3, po_umbral = 18, perola_abissal = 2 },
	{
		coracao_ressonancia = 5,
		veu_ocaso = 4,
		po_umbral = 24,
		perola_abissal = 3,
		brasa_arauto = 3,
	},
}

Transcendencia.MAXIMO = #CUSTOS
local MULTIPLICADORES = { 1, 1.05, 1.10, 1.15, 1.20, 1.25, 1.30, 1.35, 1.40, 1.45, 1.50 }

function Transcendencia.nivel(nivel: any): number
	if type(nivel) ~= "number" or nivel < 0 or nivel > 10 or nivel % 1 ~= 0 then
		return 0
	end
	return nivel
end

function Transcendencia.sorte(nivel: any): number
	return MULTIPLICADORES[Transcendencia.nivel(nivel) + 1]
end

function Transcendencia.normalizar(dados: any): { nivel: number, totalRealizadas: number }
	local nivel = if type(dados) == "table" then Transcendencia.nivel(dados.nivel) else 0
	return { nivel = nivel, totalRealizadas = nivel }
end

function Transcendencia.custo(nivelAtual: number): Itens.Estoque?
	return CUSTOS[nivelAtual + 1]
end

function Transcendencia.podeOferecer(estoque: Itens.Estoque, custo: Itens.Estoque): boolean
	for id, qtd in custo do
		if not Itens.possui(estoque, id, qtd) then
			return false
		end
	end
	return true
end

function Transcendencia.oferecer(
	estoque: Itens.Estoque,
	progresso: { nivel: number, totalRealizadas: number }
): (boolean, string?)
	local custo = Transcendencia.custo(progresso.nivel)
	if not custo then
		return false, "Você alcançou o nível máximo disponível."
	end
	if not Transcendencia.podeOferecer(estoque, custo) then
		return false, "Você ainda não tem todos os itens da próxima oferta."
	end
	for id, qtd in custo do
		Itens.consumir(estoque, id, qtd)
	end
	progresso.nivel += 1
	progresso.totalRealizadas += 1
	return true, nil
end

return Transcendencia
