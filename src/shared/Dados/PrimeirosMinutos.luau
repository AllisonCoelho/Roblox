-- Os primeiros 5 minutos (só regras puras, testadas em testes/logica.luau).
--
-- Objetivo: em poucos minutos a pessoa entende do que se trata o jogo e quer continuar.
--   1. Abertura de 8 s (só para quem nunca girou): a câmera voa pelo Nexo, passa pela estátua da
--      Gear 5 e mostra o título. Dá para pular.
--   2. O primeiro giro da vida é garantido Raro ou melhor (o "uau" logo de cara).
--   3. Trilha do caminho no HUD: GIRAR → EVOLUIR → CORREDOR → ARENA → EVENTO, marcando o que já
--      foi feito e destacando o próximo. Some quando tudo foi feito.
--   4. Estátua da Gear 5 na praça com a contagem para o próximo evento (o objetivo de longo prazo
--      fica à vista desde o primeiro segundo).
--   5. O tutorial guiado da Lume (Dados/Tutorial) segue a mesma trilha.
local PrimeirosMinutos = {}

-- ============================================================ abertura

PrimeirosMinutos.ABERTURA = 8 -- segundos

-- Mostra a abertura? Só para quem nunca girou e ainda não pulou/viu nesta conta
function PrimeirosMinutos.deveAbrir(estado: any): boolean
	if type(estado) ~= "table" then
		return false
	end
	local giros = tonumber(estado.giros) or 0
	local tutorial = estado.tutorial
	local concluido = type(tutorial) == "table" and tutorial.concluido == true
	return giros == 0 and not concluido
end

-- ============================================================ primeiro giro

PrimeirosMinutos.TIER_GARANTIDO = 3 -- Raro (índice em Auras.Tiers)

-- Se for o primeiro giro da vida e a aura sorteada for mais fraca que Raro, troca por uma aura
-- Rara sorteada (Random do servidor). Auras melhores que Raro ficam como saíram.
function PrimeirosMinutos.primeiroGiro(
	giros: number,
	aura: { tier: number, reserva: boolean? },
	lista: { any },
	aleatorio: () -> number
): any
	if giros > 0 or aura.tier >= PrimeirosMinutos.TIER_GARANTIDO then
		return aura
	end
	local raras = {}
	for _, a in lista do
		if a.tier == PrimeirosMinutos.TIER_GARANTIDO and not a.reserva and not a.exclusiva then
			table.insert(raras, a)
		end
	end
	if #raras == 0 then
		return aura
	end
	return raras[math.clamp(math.floor(aleatorio() * #raras) + 1, 1, #raras)]
end

-- ============================================================ trilha do caminho

export type Etapa = {
	id: string,
	nome: string,
	dica: string, -- o que fazer (aparece ao tocar na etapa)
}

PrimeirosMinutos.ETAPAS = {
	{ id = "girar", nome = "GIRAR", dica = "Toque em DESPERTAR para girar a sua aura." },
	{
		id = "evoluir",
		nome = "EVOLUIR",
		dica = "Use os Pontos de Aura em Evoluir para ficar mais forte.",
	},
	{
		id = "corredor",
		nome = "CORREDOR",
		dica = "Vença o chefe da 1ª fase do Corredor dos Perdidos (Portais Fragmentados).",
	},
	{
		id = "arena",
		nome = "ARENA",
		dica = "Desafie o Primeiro Soberano ou alguém na Arena do Trono (ao sul).",
	},
	{
		id = "evento",
		nome = "EVENTO",
		dica = "Bata no Titã de Borracha no Despertar do Sol e ganhe um baú com chance da Gear 5.",
	},
} :: { Etapa }

local function numero(v: any): number
	return if type(v) == "number" and v == v then v else 0
end

-- Cada etapa já foi feita?
function PrimeirosMinutos.feito(id: string, estado: any): boolean
	if type(estado) ~= "table" then
		return false
	end
	if id == "girar" then
		return numero(estado.giros) > 0
	elseif id == "evoluir" then
		local p = type(estado.poder) == "table" and estado.poder or {}
		return numero(p.nivel) + numero(p.fluxo) + numero(p.sorte) > 0
	elseif id == "corredor" then
		local c = type(estado.corredor) == "table" and estado.corredor or {}
		if type(c.concluidas) == "table" then
			for _, n in c.concluidas do
				if numero(n) > 0 then
					return true
				end
			end
		end
		return false
	elseif id == "arena" then
		local a = type(estado.arena) == "table" and estado.arena or {}
		return numero(a.vitorias) + numero(a.derrotas) + numero(a.monarca) > 0
	elseif id == "evento" then
		local e = type(estado.evento) == "table" and estado.evento or {}
		return numero(e.participacoes) + numero(e.abertos) > 0
	end
	return false
end

export type Progresso = { feitas: { boolean }, atual: number?, total: number, completo: boolean }

-- Situação da trilha: o que já foi feito e qual é a próxima etapa (a primeira não feita)
function PrimeirosMinutos.progresso(estado: any): Progresso
	local feitas = {}
	local atual: number? = nil
	local total = 0
	for i, e in PrimeirosMinutos.ETAPAS do
		local f = PrimeirosMinutos.feito(e.id, estado)
		feitas[i] = f
		if f then
			total += 1
		elseif not atual then
			atual = i
		end
	end
	return { feitas = feitas, atual = atual, total = total, completo = atual == nil }
end

-- ============================================================ estátua da Gear 5

-- Na praça, a leste (graus 90 do Nexo: nenhum outro lugar fica ali), de frente para o centro
PrimeirosMinutos.ESTATUA = { x = 62, z = 0, raio = 26 }

-- Texto da contagem na placa da estátua (fase do evento e segundos que faltam)
function PrimeirosMinutos.textoEstatua(fase: string?, restante: number): string
	local s = math.max(0, math.floor(restante))
	local tempo = string.format("%d:%02d", s // 60, s % 60)
	if fase == "luta" then
		return "O TITÃ ESTÁ NA PRAÇA! " .. tempo
	elseif fase == "aviso" then
		return "O SOL ESTÁ DESPERTANDO! " .. tempo
	elseif fase == "fim" then
		return "Evento terminando..."
	end
	return "Próximo Despertar do Sol em " .. tempo
end

return PrimeirosMinutos
