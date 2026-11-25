-- Tutorial guiado pela Lume (regras em Shared/Dados/Tutorial). O cliente percebe cada objetivo e
-- pede para avançar; aqui o servidor só deixa avançar um passo por vez, confere o que consegue
-- ver no perfil (giro e evolução) e entrega o presente de cada passo uma única vez.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(ReplicatedStorage:WaitForChild("Shared").Dados.Tutorial)
local Acoes = require(script.Parent.Acoes)
local Dados = require(script.Parent.Dados)

local Servico = {}

local function situacao(e: any): Tutorial.Situacao
	local poder = e.poder or {}
	return {
		giros = tonumber(e.giros) or 0,
		evolucoes = (tonumber(poder.nivel) or 0) + (tonumber(poder.fluxo) or 0) + (tonumber(
			poder.sorte
		) or 0),
	}
end

local function avancar(player: Player, de: any): (boolean, string?)
	local presente = nil
	local ok, msg = Dados.alterar(player, function(estado)
		local e = estado :: any
		local p = Tutorial.normalizar(e.tutorial, e.giros)
		local certo, dado, erro = Tutorial.avancar(p, de, situacao(e))
		if not certo then
			return false, erro
		end
		e.tutorial = p
		if dado then
			presente = dado
			e.poder.pontos += dado.pontos or 0
			e.poder.total += dado.pontos or 0
			e.corredor.fragmentos += dado.fragmentos or 0
		end
		return true
	end)
	if ok and presente then
		player:SetAttribute("PontosAura", math.floor((Dados.de(player) :: any).poder.pontos))
		return true, Tutorial.textoPresente(presente)
	end
	return ok, if ok then nil else msg
end

local function mudar(fn: (Tutorial.Progresso) -> ()): (Player) -> (boolean, string?)
	return function(player)
		return Dados.alterar(player, function(estado)
			local e = estado :: any
			local p = Tutorial.normalizar(e.tutorial, e.giros)
			fn(p)
			e.tutorial = p
			return true
		end)
	end
end

function Servico.iniciar()
	Acoes.registrar("TutorialAvancar", avancar)
	Acoes.registrar("TutorialPular", mudar(Tutorial.pular))
	Acoes.registrar("TutorialReiniciar", mudar(Tutorial.reiniciar))
end

return Servico
