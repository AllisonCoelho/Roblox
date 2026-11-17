-- Regras do duelo, sem dependência de instâncias do Roblox.
local Arena = {}

Arena.VIDA = 1000
Arena.CARGA = 100
Arena.ESPERA_TURNO = 35

export type Acao = {
	nome: string,
	dano: number,
	energia: number,
	recarga: number,
	descricao: string?,
	especial: boolean?,
}
Arena.Acoes = {
	ataque = { nome = "Ataque", dano = 105, energia = 25, recarga = 0 },
	guarda = { nome = "Guarda", dano = 0, energia = 20, recarga = 0 },
	corte = {
		nome = "Corte de Ressonância",
		dano = 175,
		energia = 15,
		recarga = 2,
		descricao = "175 de dano",
		especial = true,
	},
	selo = {
		nome = "Selo de Ruptura",
		dano = 60,
		energia = 15,
		recarga = 3,
		descricao = "60 de dano · enfraquece o próximo golpe recebido",
		especial = true,
	},
	despertar = {
		nome = "Despertar",
		dano = 290,
		energia = -Arena.CARGA,
		recarga = 0,
		especial = true,
	},
} :: { [string]: Acao }

export type Intencao = { id: string, nome: string, aviso: string, dano: number }
local CORTE: Intencao = {
	id = "investida",
	nome = "Investida do Trono",
	aviso = "O Soberano aponta a espada para você.",
	dano = 100,
}
local PESADO: Intencao = {
	id = "pesado",
	nome = "Sentença do Trono",
	aviso = "O Soberano levanta a espada. Vem um golpe pesado.",
	dano = 260,
}
local GUARDA: Intencao = {
	id = "baluarte",
	nome = "Baluarte",
	aviso = "O Soberano firma a guarda. Seus golpes causarão menos dano.",
	dano = 0,
}
local PADRAO = { CORTE, PESADO, CORTE, GUARDA, PESADO }

export type Estado = {
	rodada: number,
	vida: number,
	soberano: number,
	energia: number,
	recargas: { [string]: number },
	selado: boolean,
}
export type Golpe = {
	id: string,
	nome: string,
	ator: string,
	dano: number,
	especial: boolean,
	estado: Estado,
}
export type Resolucao = { golpes: { Golpe }, estado: Estado, resultado: string? }

function Arena.novo(): Estado
	return {
		rodada = 1,
		vida = Arena.VIDA,
		soberano = Arena.VIDA,
		energia = 0,
		recargas = {},
		selado = false,
	}
end

function Arena.intencao(rodada: number): Intencao
	return PADRAO[(rodada - 1) % #PADRAO + 1]
end

function Arena.restante(estado: Estado, id: string): number
	return math.max(0, (estado.recargas[id] or 0) - estado.rodada)
end

function Arena.validar(estado: Estado, id: string): string?
	if estado.vida <= 0 or estado.soberano <= 0 then
		return "O duelo terminou."
	elseif not Arena.Acoes[id] then
		return "Ação desconhecida."
	elseif Arena.restante(estado, id) > 0 then
		return "Esta técnica está recarregando."
	elseif id == "despertar" and estado.energia < Arena.CARGA then
		return "Encha a barra de energia para despertar."
	end
	return nil
end

function Arena.resolver(estado: Estado, id: string): (Resolucao?, string?)
	local problema = Arena.validar(estado, id)
	if problema then
		return nil, problema
	end
	local acao = Arena.Acoes[id]
	local intencao = Arena.intencao(estado.rodada)
	local turno = table.clone(estado)
	turno.recargas = table.clone(estado.recargas)
	if acao.recarga > 0 then
		turno.recargas[id] = turno.rodada + acao.recarga + 1
	end
	turno.energia = math.clamp(turno.energia + acao.energia, 0, Arena.CARGA)
	local dano = math.floor(acao.dano * (if intencao == GUARDA then 0.55 else 1))
	dano = math.min(turno.soberano, dano)
	turno.soberano -= dano
	turno.selado = turno.selado or id == "selo"
	local golpes: { Golpe } = {
		{
			id = id,
			nome = acao.nome,
			ator = "jogador",
			dano = dano,
			especial = acao.especial == true,
			estado = turno,
		},
	}

	if turno.soberano == 0 then
		return { golpes = golpes, estado = turno, resultado = "vitoria" }, nil
	end

	local resposta = table.clone(turno)
	local danoRecebido = intencao.dano
	if id == "guarda" then
		danoRecebido = math.floor(danoRecebido * 0.35)
	end
	if resposta.selado and danoRecebido > 0 then
		danoRecebido = math.floor(danoRecebido * 0.5)
		resposta.selado = false
	end
	danoRecebido = math.min(resposta.vida, danoRecebido)
	resposta.vida -= danoRecebido
	table.insert(golpes, {
		id = intencao.id,
		nome = intencao.nome,
		ator = "soberano",
		dano = danoRecebido,
		especial = intencao == PESADO,
		estado = resposta,
	})
	if resposta.vida == 0 then
		return { golpes = golpes, estado = resposta, resultado = "derrota" }, nil
	end

	local seguinte = table.clone(resposta)
	seguinte.rodada += 1
	return { golpes = golpes, estado = seguinte }, nil
end

return Arena
