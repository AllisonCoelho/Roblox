local Itens = require(script.Parent.Itens)

local Transcendencia = {}

Transcendencia.MAXIMO = 1
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

function Transcendencia.oferecer(
	estoque: Itens.Estoque,
	progresso: { nivel: number, totalRealizadas: number }
): (boolean, string?)
	if progresso.nivel >= Transcendencia.MAXIMO then
		return false, "Você alcançou o nível máximo disponível."
	end
	if not Itens.consumir(estoque, "coracao_ressonancia", 1) then
		return false, "Fabrique um Coração da Ressonância primeiro."
	end
	progresso.nivel += 1
	progresso.totalRealizadas += 1
	return true, nil
end

return Transcendencia
