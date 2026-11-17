-- Incursões 2.0 (fase C): o que traz o jogador de volta. Só regras puras (testadas).
--   * Fenda do Dia: mesmo universo, mesmas Marcas e mesma sequência de andares para todos no dia
--     (UTC); pontuação e recorde pessoal; recompensa na primeira vitória do dia
--   * Desafios semanais: 3 por semana, sorteados pela semana; progresso salvo no perfil
--   * Reviver colega: tempos do estado "abatido"
-- Campos novos ficam dentro de perfil.incursoes (mesmo store Despertar_v1):
--   diaria = { dia, melhor, vitoria }   semana = { id, progresso = { [desafio] = n }, feitos = { [desafio] = true } }
local D = {}

local SEGUNDOS_DIA = 86400

-- Dia e semana (UTC) a partir de os.time(): o servidor passa o relógio, nada vem do cliente
function D.dia(agora: number): number
	return math.floor(agora / SEGUNDOS_DIA)
end

function D.semana(agora: number): number
	-- semanas começam na segunda-feira (1/1/1970 foi quinta: +3 dias)
	return math.floor((D.dia(agora) + 3) / 7)
end

-- Gerador simples e determinístico (mesmo resultado em todos os servidores)
local function gerador(semente: number): () -> number
	local estado = (semente * 2654435761) % 4294967296
	return function()
		estado = (estado * 1664525 + 1013904223) % 4294967296
		return estado / 4294967296
	end
end
D.gerador = gerador

-- ---------------------------------------------------------------- Fenda do Dia

D.UNIVERSOS_DIA = { "cinzas", "mare", "umbral" }
D.MARCAS_DIA = { "densas", "velozes", "vidro", "coroa" } -- "Sem Reviver" fica de fora: o dia é para todos

export type FendaDoDia = {
	dia: number,
	universo: string,
	marcas: { [string]: boolean },
	semente: number,
}

function D.fendaDoDia(dia: number): FendaDoDia
	local sorte = gerador(dia + 7919)
	local universo = D.UNIVERSOS_DIA[dia % #D.UNIVERSOS_DIA + 1]
	local marcas = {}
	local lista = table.clone(D.MARCAS_DIA)
	for _ = 1, 2 do
		local k = math.clamp(math.floor(sorte() * #lista) + 1, 1, #lista)
		marcas[lista[k]] = true
		table.remove(lista, k)
	end
	return { dia = dia, universo = universo, marcas = marcas, semente = dia * 104729 + 17 }
end

-- Pontuação da run do dia: andares, vitória, notas S, abates e rapidez
function D.pontuacao(
	andares: number,
	venceu: boolean,
	notasS: number,
	abates: number,
	tempo: number
): number
	local p = andares * 1000 + notasS * 300 + abates * 10
	if venceu then
		p += 3000 + math.max(0, 1200 - math.floor(tempo)) * 2
	end
	return math.max(0, math.floor(p))
end

-- Recompensa da primeira vitória do dia (Fragmentos), pelo nível do universo
function D.recompensaDia(nivel: number): number
	return 120 * math.max(nivel, 1)
end

-- ---------------------------------------------------------------- desafios semanais

export type Desafio = { id: string, nome: string, meta: number, recompensa: number }

D.DESAFIOS = {
	{ id = "guardioes", nome = "Derrube 3 Guardiões", meta = 3, recompensa = 220 },
	{ id = "elites", nome = "Derrube 30 Elites", meta = 30, recompensa = 180 },
	{ id = "notasS", nome = "Conclua 8 andares com nota S", meta = 8, recompensa = 200 },
	{ id = "hordas", nome = "Sobreviva a 5 Hordas", meta = 5, recompensa = 160 },
	{ id = "cofres", nome = "Abra 3 Cofres da Fenda", meta = 3, recompensa = 180 },
	{ id = "sequencia", nome = "Faça uma sequência de 25 abates", meta = 25, recompensa = 150 },
	{ id = "reviver", nome = "Reviva aliados 5 vezes", meta = 5, recompensa = 170 },
	{ id = "pesadelo", nome = "Vença 1 Incursão no Pesadelo", meta = 1, recompensa = 400 },
	{ id = "marcas", nome = "Vença com 2 ou mais Marcas", meta = 1, recompensa = 250 },
	{ id = "abates", nome = "Derrube 400 inimigos", meta = 400, recompensa = 160 },
} :: { Desafio }

D.desafioPorId = {} :: { [string]: Desafio }
for _, d in D.DESAFIOS do
	D.desafioPorId[d.id] = d
end

-- 3 desafios diferentes da semana (iguais para todos)
function D.desafiosDaSemana(semana: number): { string }
	local sorte = gerador(semana + 104723)
	local lista = {}
	for _, d in D.DESAFIOS do
		table.insert(lista, d.id)
	end
	local saida = {}
	for _ = 1, 3 do
		local k = math.clamp(math.floor(sorte() * #lista) + 1, 1, #lista)
		table.insert(saida, lista[k])
		table.remove(lista, k)
	end
	return saida
end

-- Estado semanal normalizado (semana nova zera o progresso)
function D.semanaDe(
	inc: any,
	semana: number
): { id: number, progresso: { [string]: number }, feitos: { [string]: boolean } }
	local s = if type(inc) == "table" then inc.semana else nil
	if type(s) ~= "table" or s.id ~= semana then
		return { id = semana, progresso = {}, feitos = {} }
	end
	s.progresso = if type(s.progresso) == "table" then s.progresso else {}
	s.feitos = if type(s.feitos) == "table" then s.feitos else {}
	return s
end

-- Soma progresso a um desafio da semana. "maximo" (sequência) guarda o maior valor em vez de somar.
-- Devolve a recompensa se o desafio acabou de ser concluído (0 caso contrário).
function D.progredir(
	estadoSemana: any,
	semana: number,
	id: string,
	valor: number,
	maximo: boolean?
): number
	if not table.find(D.desafiosDaSemana(semana), id) then
		return 0
	end
	local d = D.desafioPorId[id]
	if estadoSemana.feitos[id] then
		return 0
	end
	local atual = estadoSemana.progresso[id] or 0
	local novo = if maximo then math.max(atual, valor) else atual + valor
	estadoSemana.progresso[id] = math.min(novo, d.meta)
	if novo >= d.meta then
		estadoSemana.feitos[id] = true
		return d.recompensa
	end
	return 0
end

-- ---------------------------------------------------------------- reviver colega

D.ABATIDO_ESPERA = 15 -- sem ajuda, levanta sozinho depois disso
D.REVIVER_TEMPO = 2.5 -- aliado perto por esse tempo levanta o colega
D.REVIVER_RAIO = 7
D.REVIVER_VIDA = 0.5 -- volta com metade da vida

return D
