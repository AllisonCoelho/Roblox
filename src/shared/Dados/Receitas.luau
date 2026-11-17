local Itens = require(script.Parent.Itens)

local Receitas = {}

export type Receita = {
	resultado: string,
	custo: Itens.Estoque,
}

Receitas.ordem = { "lasca_estavel", "coracao_fenda", "coracao_ressonancia" }
Receitas.porId = {
	lasca_estavel = { resultado = "lasca_estavel", custo = { estilhaco_bruto = 5 } },
	coracao_fenda = {
		resultado = "coracao_fenda",
		custo = { estilhaco_bruto = 8, lasca_estavel = 2, selo_purificacao = 1 },
	},
	coracao_ressonancia = {
		resultado = "coracao_ressonancia",
		custo = { coracao_fenda = 1, estilhaco_bruto = 6, cinza_persistente = 1 },
	},
} :: { [string]: Receita }

function Receitas.podeFabricar(estoque: Itens.Estoque, receita: Receita): (boolean, string?)
	for id, custo in receita.custo do
		if not Itens.possui(estoque, id, custo) then
			return false, "Você ainda não tem todos os ingredientes."
		end
	end
	if (estoque[receita.resultado] or 0) >= Itens.porId[receita.resultado].limitePilha then
		return false, "A pilha desse item está cheia."
	end
	return true, nil
end

function Receitas.fabricar(estoque: Itens.Estoque, id: string): (boolean, string?)
	local receita = Receitas.porId[id]
	if not receita then
		return false, "Receita desconhecida."
	end
	local ok, msg = Receitas.podeFabricar(estoque, receita)
	if not ok then
		return false, msg
	end
	for ingrediente, custo in receita.custo do
		Itens.consumir(estoque, ingrediente, custo)
	end
	Itens.conceder(estoque, receita.resultado, 1)
	return true, Itens.porId[receita.resultado].nome .. " fabricado!"
end

return Receitas
