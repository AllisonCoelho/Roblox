-- Conveniências pagas (lógica pura, testada): Auto Inteligente e Presets de Auras.
-- Nada aqui muda a chance de aura: só quando o giro automático para e o que fica equipado.
local Conveniencia = {}

-- Auto Inteligente: o giro automático para sozinho ao sair uma aura desta raridade (1 em N)
Conveniencia.LIMIARES = { 0, 1000, 10000, 100000, 1000000, 10000000 } -- 0 = nunca para por raridade

function Conveniencia.autoPadrao(): { pararChance: number, pararNova: boolean }
	return { pararChance = 0, pararNova = false }
end

function Conveniencia.limiarValido(n: any): boolean
	return type(n) == "number" and table.find(Conveniencia.LIMIARES, n) ~= nil
end

-- Deve parar o giro automático? Devolve o motivo ou nil.
function Conveniencia.devePararAuto(auto: any, chance: number, nova: boolean): string?
	if type(auto) ~= "table" then
		return nil
	end
	if auto.pararNova == true and nova then
		return "Auto Inteligente: aura nova! Giro automático pausado."
	end
	local limiar = auto.pararChance
	if type(limiar) == "number" and limiar > 0 and chance >= limiar then
		return "Auto Inteligente: aura rara! Giro automático pausado."
	end
	return nil
end

-- Presets de Auras: até 5 combinações de aura + cosméticos equipados
Conveniencia.MAX_PRESETS = 5

function Conveniencia.slotValido(n: any): boolean
	return type(n) == "number" and n == math.floor(n) and n >= 1 and n <= Conveniencia.MAX_PRESETS
end

function Conveniencia.criarPreset(equipada: string?, cosmeticos: { [string]: string }?): any
	return { aura = equipada or "", cosmeticos = table.clone(cosmeticos or {}) }
end

return Conveniencia
