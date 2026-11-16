-- Monta o mapa e mantém o painel do Obelisco das Lendas atualizado.
-- Script separado do Main: só cenário e leitura de dados, nenhuma regra de jogo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auras = require(Shared.Dados.Auras)
local Formato = require(Shared.Formato)
local Dados = require(script.Parent.Servicos.Dados)
local Nexo = require(script.Parent.Mundo.Nexo)
local PrimeiroSoberano = require(script.Parent.NPCs.PrimeiroSoberano)

local INTERVALO = 4
local LINHAS = 5

local pasta = Nexo.construir()
PrimeiroSoberano.iniciar(pasta) -- o NPC nasce sentado no trono da Arena
local painel = pasta:WaitForChild("PainelRanking")
local texto = painel:WaitForChild("Ranking"):WaitForChild("Texto") :: TextLabel

local function escapar(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- Ranking do servidor atual: pela aura mais rara (chance real); empate decide por giros.
-- Os valores vêm do perfil no servidor, nunca do cliente.
local function atualizar()
	local linhas = {}
	for _, jogador in Players:GetPlayers() do
		local estado = Dados.de(jogador)
		if estado then
			local melhor = Auras.melhorDe(estado.auras)
			table.insert(linhas, {
				nome = jogador.DisplayName,
				giros = estado.giros,
				aura = melhor,
				chance = if melhor then melhor.chance else 0,
			})
		end
	end
	table.sort(linhas, function(a, b)
		if a.chance ~= b.chance then
			return a.chance > b.chance
		end
		return a.giros > b.giros
	end)
	local partes = { '<font size="40"><b>LENDAS DESTE SERVIDOR</b></font>' }
	for i = 1, math.min(LINHAS, #linhas) do
		local l = linhas[i]
		local aura = l.aura
		if aura then
			table.insert(
				partes,
				string.format(
					'%d. <b>%s</b>  <font color="#%s">%s</font> · 1 em %s  <font color="#A9A3B6">%s giros</font>',
					i,
					escapar(l.nome),
					Auras.Tiers[aura.tier].cor,
					aura.nome,
					Formato.chance(aura.chance),
					Formato.curto(l.giros)
				)
			)
		else
			table.insert(
				partes,
				string.format("%d. <b>%s</b>  ainda não despertou", i, escapar(l.nome))
			)
		end
	end
	if #linhas == 0 then
		table.insert(partes, '<font color="#A9A3B6">Ninguém despertou ainda.</font>')
	end
	texto.Text = table.concat(partes, "\n")
end

while true do
	local ok, erro = pcall(atualizar)
	if not ok then
		warn("[Nexo] ranking: " .. tostring(erro))
	end
	task.wait(INTERVALO)
end
