-- Sons do jogo. Para trocar um som: escolha um áudio grátis na Creator Store do Roblox
-- e coloque o id aqui como "rbxassetid://NUMERO". Os padrões usam sons que já vêm
-- com o Roblox (rbxasset://sounds/...), então o jogo tem som mesmo sem configurar nada.
local Sons = {}

export type Som = { id: string, volume: number, velocidade: number }

local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLIQUE = "rbxasset://sounds/clickfast.wav"

Sons.Lista = {
	clique = { id = CLIQUE, volume = 0.4, velocidade = 1.1 },
	sucesso = { id = PING, volume = 0.45, velocidade = 1.25 },
	erro = { id = PING, volume = 0.35, velocidade = 0.6 },
	novo = { id = PING, volume = 0.6, velocidade = 1 },
	raro = { id = PING, volume = 0.6, velocidade = 0.8 },
	chuva = { id = PING, volume = 0.6, velocidade = 1.5 },
	resgate = { id = PING, volume = 0.6, velocidade = 0.5 },
} :: { [string]: Som }

-- Música de fundo em loop (vazia = sem música). Use um id da Creator Store.
Sons.Musica = { id = "", volume = 0.25, velocidade = 1 } :: Som

return Sons
