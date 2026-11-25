-- Corredor dos Perdidos: seis mundos fragmentados flutuando no céu do Nexo, em espiral. Cada
-- fase pede uma Pontuação de Aura mínima e que a anterior tenha sido concluída. Concluir dá
-- Fragmentos (moeda dos pets) e a Ressonância de Combate (Pontos de Aura em dobro por um tempo).
-- As criaturas entram depois: por enquanto, concluir é atravessar a ilha até o Portão.
-- Só regras puras (sem Roblox): o servidor decide tudo com este módulo. Testado em
-- testes/logica.luau. Onde cada fase fica no mundo: Dados/CorredorMapa (gerado pelo Blender).
local Corredor = {}

export type Fase = {
	numero: number,
	nome: string,
	descricao: string,
	cor: string, -- hex
	requisito: number, -- Pontuação de Aura mínima para entrar
	primeira: number, -- Fragmentos na primeira conclusão
	repetir: number, -- Fragmentos nas conclusões seguintes (com espera)
}

export type Progresso = {
	fragmentos: number,
	concluidas: { [string]: number }, -- "1".."6" -> vezes concluída
	ultima: { [string]: number }, -- "1".."6" -> os.time() da última recompensa
	bonusAte: number, -- os.time() até quando a Ressonância de Combate vale
}

Corredor.FASES = {
	{
		numero = 1,
		nome = "Limiar Partido",
		descricao = "A primeira lasca do mundo antigo, ainda presa ao Nexo.",
		cor = "C0ADFF",
		requisito = 0,
		primeira = 10,
		repetir = 2,
	},
	{
		numero = 2,
		nome = "Bosque de Vidro",
		descricao = "Árvores de cristal que cantam quando o vento passa.",
		cor = "5AF5CC",
		requisito = 60,
		primeira = 25,
		repetir = 5,
	},
	{
		numero = 3,
		nome = "Dunas de Cinza",
		descricao = "Brasas que nunca apagam num deserto suspenso.",
		cor = "FF8A3D",
		requisito = 250,
		primeira = 60,
		repetir = 12,
	},
	{
		numero = 4,
		nome = "Maré Suspensa",
		descricao = "Um oceano congelado no meio da queda.",
		cor = "5CE1FF",
		requisito = 1000,
		primeira = 150,
		repetir = 30,
	},
	{
		numero = 5,
		nome = "Catedral Quebrada",
		descricao = "Ruínas de mármore de quem guardava os portais.",
		cor = "FFC83D",
		requisito = 4000,
		primeira = 350,
		repetir = 70,
	},
	{
		numero = 6,
		nome = "Coração do Vazio",
		descricao = "O último fragmento antes do nada.",
		cor = "EE5CFF",
		requisito = 12000,
		primeira = 800,
		repetir = 160,
	},
} :: { Fase }

Corredor.TOTAL = #Corredor.FASES
Corredor.ESPERA_REPETIR = 300 -- segundos entre recompensas repetidas da mesma fase
Corredor.BONUS_DURACAO = 180 -- segundos de Ressonância de Combate por conclusão
Corredor.BONUS_MULTIPLICADOR = 2
Corredor.TEMPO_MINIMO = 6 -- segundos dentro da fase antes de poder concluir (sem atalhos)

local function numero(v: any): number
	return if type(v) == "number" and v == v and v >= 0 and v < math.huge then v else 0
end

function Corredor.padrao(): Progresso
	return { fragmentos = 0, concluidas = {}, ultima = {}, bonusAte = 0 }
end

-- Corrige dados salvos estranhos
function Corredor.normalizar(p: any): Progresso
	local t = if type(p) == "table" then p else {}
	local saida = Corredor.padrao()
	saida.fragmentos = math.floor(numero(t.fragmentos))
	saida.bonusAte = numero(t.bonusAte)
	for i = 1, Corredor.TOTAL do
		local k = tostring(i)
		if type(t.concluidas) == "table" and numero(t.concluidas[k]) > 0 then
			saida.concluidas[k] = math.floor(numero(t.concluidas[k]))
		end
		if type(t.ultima) == "table" and numero(t.ultima[k]) > 0 then
			saida.ultima[k] = numero(t.ultima[k])
		end
	end
	return saida
end

function Corredor.concluiu(p: Progresso, fase: number): boolean
	return (p.concluidas[tostring(fase)] or 0) > 0
end

-- Pode entrar na fase? (motivo quando não pode)
function Corredor.podeEntrar(p: Progresso, fase: any, pontuacao: number): (boolean, string?)
	local f = if type(fase) == "number" then Corredor.FASES[fase] else nil
	if not f then
		return false, "Fase desconhecida."
	end
	if fase > 1 and not Corredor.concluiu(p, fase - 1) then
		return false, string.format("Conclua %s primeiro.", Corredor.FASES[fase - 1].nome)
	end
	if pontuacao < f.requisito then
		return false, string.format("%s pede %d de Pontuação de Aura.", f.nome, f.requisito)
	end
	return true, nil
end

-- Maior fase em que o jogador pode entrar agora (1..6)
function Corredor.acesso(p: Progresso, pontuacao: number): number
	local maior = 1
	for i = 2, Corredor.TOTAL do
		if Corredor.podeEntrar(p, i, pontuacao) then
			maior = i
		else
			break
		end
	end
	return maior
end

-- Registra a conclusão. Devolve os Fragmentos ganhos (0 se ainda está na espera) e se foi a
-- primeira vez. Toda conclusão renova a Ressonância de Combate.
function Corredor.concluir(p: Progresso, fase: number, agora: number): (number, boolean)
	local f = Corredor.FASES[fase]
	if not f then
		return 0, false
	end
	local k = tostring(fase)
	local primeira = not Corredor.concluiu(p, fase)
	local ganho = 0
	if primeira then
		ganho = f.primeira
	elseif agora - (p.ultima[k] or 0) >= Corredor.ESPERA_REPETIR then
		ganho = f.repetir
	end
	if ganho > 0 then
		p.ultima[k] = agora
		p.fragmentos += ganho
	end
	p.concluidas[k] = (p.concluidas[k] or 0) + 1
	p.bonusAte = agora + Corredor.BONUS_DURACAO
	return ganho, primeira
end

-- Multiplicador de Pontos de Aura da Ressonância de Combate
function Corredor.multiplicador(p: Progresso, agora: number): number
	return if agora < p.bonusAte then Corredor.BONUS_MULTIPLICADOR else 1
end

return Corredor
