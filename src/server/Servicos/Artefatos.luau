local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Acoes = require(script.Parent.Acoes)
local Artefatos = require(Shared.Dados.Artefatos)
local Dados = require(script.Parent.Dados)
local Incursoes = require(script.Parent.Parent.Incursoes.Servico)

local Servico = {}

local function equipar(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" or #id > 64 then
		return false, "Artefato inválido."
	end
	if Incursoes.ocupado(player) then
		return false, "Saia da fila ou termine sua incursão antes de trocar de artefato."
	end
	if not Dados.podeProgredir(player) then
		return false, "Aguarde seu perfil carregar."
	end
	return Dados.alterar(player, function(estado)
		return Artefatos.equipar(estado.inventario, id)
	end)
end

local function atualizarVisual(player: Player)
	local real = Dados.real(player)
	local id = if real then real.inventario.equipados.artefato else nil
	player:SetAttribute("ArtefatoVisual", Artefatos.visual(id))
end

function Servico.iniciar()
	Acoes.registrar("EquiparArtefato", equipar)
	Dados.quandoCarregar(atualizarVisual)
	Dados.quandoMudar(atualizarVisual)
end

return Servico
