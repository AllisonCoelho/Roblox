-- Presente diário em sequência de 7 dias (ver docs/design/09-popups.png)
local Presentes = {}

export type Presente = {
	icone: string,
	texto: string,
	moedas: number?,
	granulados: number?,
	boost: string?, -- id de Loja.Boosts
	docinho: string?, -- id do Catálogo
}

Presentes.Dias = {
	{ icone = "🪙", texto = "500 moedas", moedas = 500 },
	{ icone = "✨", texto = "10 granulados", granulados = 10 },
	{ icone = "🍀", texto = "Esteira da Sorte", boost = "sorte" },
	{ icone = "🪙", texto = "5.000 moedas", moedas = 5000 },
	{ icone = "✨", texto = "25 granulados", granulados = 25 },
	{ icone = "🪙", texto = "Moedas em Dobro", boost = "moedas2x" },
	{ icone = "🍮", texto = "Pudim Lendário!", docinho = "pudim" },
} :: { Presente }

-- Dia do calendário no horário de Brasília (UTC-3), para virar à meia-noite do Brasil
function Presentes.diaAtual(agora: number): number
	return math.floor((agora - 3 * 3600) / 86400)
end

return Presentes
