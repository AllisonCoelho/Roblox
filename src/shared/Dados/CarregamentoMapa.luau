-- Política pura: a praça aparece antes dos caminhos, lugares e penhascos.
local Carregamento = {}

function Carregamento.etapa(dados: { [string]: any }): string
	local p = dados.posicao
	return if p[1] * p[1] + p[3] * p[3] <= 46 * 46 then "Praca" else "Mundo"
end

function Carregamento.dividir(pecas: { { [string]: any } }): ({ any }, { any })
	local praca, mundo = {}, {}
	for _, peca in pecas do
		table.insert(if Carregamento.etapa(peca) == "Praca" then praca else mundo, peca)
	end
	return praca, mundo
end

return Carregamento
