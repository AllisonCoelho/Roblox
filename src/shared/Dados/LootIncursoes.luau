local Itens = require(script.Parent.Itens)
local Incursoes = require(script.Parent.Incursoes)

local Loot = {}

export type Registro = {
	andares: { [number]: boolean },
	itens: Itens.Estoque,
	fragmentos: number,
}

local BIOMAS = {
	cinzas = { material = "cinza_persistente", marca = "brasa_arauto" },
	mare = { material = "sal_mare_morta", marca = "perola_abissal" },
	umbral = { material = "po_umbral", marca = "veu_ocaso" },
}

Loot.CHANCE_MARCA_EXTRA = 0.10
Loot.CHANCE_CORACAO_FENDA = 0.03

function Loot.novo(): Registro
	return { andares = {}, itens = {}, fragmentos = 0 }
end

-- Chamado no servidor dentro da mesma alteração que credita os Fragmentos de Incursão.
-- Um Registro pertence a um jogador em uma partida e só admite um crédito por andar.
function Loot.creditar(
	registro: Registro,
	estoque: Itens.Estoque,
	universo: string,
	andar: number,
	aleatorio: () -> number
): Itens.Estoque?
	local bioma = BIOMAS[universo]
	if
		not bioma
		or andar < 1
		or andar > Incursoes.ANDARES
		or andar % 1 ~= 0
		or registro.andares[andar]
	then
		return nil
	end
	local previstos: Itens.Estoque =
		{ estilhaco_bruto = 3, [bioma.material] = if andar >= 3 then 2 else 1 }
	if andar == 1 then
		previstos.selo_purificacao = 1
	elseif andar == 2 or andar == 4 then
		previstos.lasca_estavel = 1
	end
	if andar >= 4 then
		previstos.fragmento_instavel = 1
	end
	if andar == Incursoes.ANDARES then
		previstos[bioma.marca] = if aleatorio() < Loot.CHANCE_MARCA_EXTRA then 2 else 1
		if aleatorio() < Loot.CHANCE_CORACAO_FENDA then
			previstos.coracao_fenda = 1
		end
	end

	local ganhos: Itens.Estoque = {}
	for id, qtd in previstos do
		local ganho = Itens.conceder(estoque, id, qtd)
		if ganho > 0 then
			ganhos[id] = ganho
			registro.itens[id] = (registro.itens[id] or 0) + ganho
		end
	end
	registro.andares[andar] = true
	return ganhos
end

return Loot
