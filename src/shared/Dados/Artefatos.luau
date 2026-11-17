local Itens = require(script.Parent.Itens)

local Artefatos = {}

Artefatos.porId = {
	emblema_guardiao = { bonusVida = 0.10, visual = false },
	lamina_nexo = { bonusVida = 0, visual = true },
}

type Inventario = { itens: Itens.Estoque, equipados: { artefato: string? } }

function Artefatos.equipar(inventario: Inventario, id: string): (boolean, string?)
	if id == "" then
		inventario.equipados.artefato = nil
		return true, "Artefato desequipado."
	end
	if not Artefatos.porId[id] or not Itens.possui(inventario.itens, id, 1) then
		return false, "Você não possui esse artefato."
	end
	inventario.equipados.artefato = id
	return true, Itens.porId[id].nome .. " equipado."
end

function Artefatos.bonusVida(id: string?): number
	local cfg = if id then Artefatos.porId[id] else nil
	return if cfg then cfg.bonusVida else 0
end

function Artefatos.visual(id: string?): string?
	local cfg = if id then Artefatos.porId[id] else nil
	return if cfg and cfg.visual then id else nil
end

return Artefatos
