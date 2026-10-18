-- Missões diárias: 3 sorteadas por dia, iguais para todos os jogadores no mesmo dia
local Missoes = {}

export type Missao = {
	id: string,
	texto: string,
	tipo: string, -- evento que faz a missão andar (ver MissaoService.progredir)
	meta: number,
	granulados: number,
}

Missoes.Lista = {
	{
		id = "comprar5",
		texto = "Compre 5 Docinhos",
		tipo = "comprar_docinho",
		meta = 5,
		granulados = 20,
	},
	{
		id = "raros3",
		texto = "Compre 3 Docinhos Raros",
		tipo = "comprar_raro",
		meta = 3,
		granulados = 50,
	},
	{
		id = "coletar5k",
		texto = "Colete 5.000 moedas",
		tipo = "coletar_moedas",
		meta = 5000,
		granulados = 25,
	},
	{
		id = "melhoria1",
		texto = "Compre 1 melhoria na Loja",
		tipo = "comprar_melhoria",
		meta = 1,
		granulados = 15,
	},
	{
		id = "presente",
		texto = "Pegue o presente do dia",
		tipo = "presente_diario",
		meta = 1,
		granulados = 10,
	},
	{
		id = "escudo3",
		texto = "Ligue o escudo 3 vezes",
		tipo = "ligar_escudo",
		meta = 3,
		granulados = 15,
	},
	{
		id = "codigo",
		texto = "Resgate um código",
		tipo = "resgatar_codigo",
		meta = 1,
		granulados = 10,
	},
} :: { Missao }

Missoes.PorDia = 3

local porId: { [string]: Missao } = {}
for _, m in Missoes.Lista do
	porId[m.id] = m
end

function Missoes.missao(id: string): Missao?
	return porId[id]
end

-- Sorteio determinístico pelo número do dia
function Missoes.doDia(dia: number): { string }
	local rng = Random.new(dia * 7919)
	local ids: { string } = {}
	for _, m in Missoes.Lista do
		table.insert(ids, m.id)
	end
	local escolhidas: { string } = {}
	for _ = 1, math.min(Missoes.PorDia, #ids) do
		local id = table.remove(ids, rng:NextInteger(1, #ids)) :: string
		table.insert(escolhidas, id)
	end
	return escolhidas
end

return Missoes
