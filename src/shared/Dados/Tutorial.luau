-- Tutorial dos primeiros minutos, guiado pela Lume, Guardiã do Nexo (personagem original).
-- Só regras puras (sem Roblox), testadas em testes/logica.luau.
--
-- Cada passo tem as falas da Lume (a tela digita uma por vez) e, quando precisa, um objetivo
-- que o jogador cumpre no jogo (girar, evoluir, pegar um drop, chegar aos Portais). O cliente
-- percebe o objetivo e pede para avançar; o servidor só deixa avançar um passo por vez, confere
-- os objetivos que ele consegue ver (giro e evolução) e entrega o presente de cada passo uma
-- única vez (o passo fica salvo no perfil). Dá para pular o tutorial a qualquer momento.
local Tutorial = {}

export type Objetivo = "continuar" | "girar" | "evoluir" | "drop" | "portais" | "estatua"
export type Passo = {
	id: string,
	falas: { string },
	objetivo: Objetivo,
	dica: string?, -- texto curto enquanto espera o objetivo
	destaque: string?, -- elemento do HUD destacado (nome no HUD)
	presente: { pontos: number?, fragmentos: number? }?, -- ao ENTRAR no passo
	paciencia: number?, -- segundos até aparecer "Continuar" num objetivo opcional
}
export type Progresso = {
	passo: number,
	concluido: boolean,
	presenteAte: number, -- último passo cujo presente já foi entregue (rever não dá de novo)
	apresentacaoOferecida: boolean?, -- migração da dispensa silenciosa dos veteranos
}

Tutorial.NOME = "Lume"
Tutorial.TITULO = "Guardiã do Nexo"

Tutorial.PASSOS = {
	{
		id = "boasVindas",
		falas = {
			"Oi! Eu sou a Lume, Guardiã do Nexo. Que bom que você acordou!",
			"Aqui, cada pessoa desperta uma aura. Quanto mais forte a sua, mais longe você chega.",
			"Olha a trilha ali no canto: GIRAR, EVOLUIR, CORREDOR, ARENA e EVENTO. É o seu caminho!",
			"Vem, eu te guio pelo começo em uns minutinhos.",
		},
		objetivo = "continuar",
		destaque = "Caminho",
	},
	{
		id = "girar",
		falas = {
			"Primeiro, a sua aura! Toque em DESPERTAR para girar.",
		},
		objetivo = "girar",
		dica = "Toque em DESPERTAR",
		destaque = "Despertar",
	},
	{
		id = "pontos",
		falas = {
			"UAU! A sua primeira aura já veio RARA! Quanto mais rara a aura, mais forte ela é.",
			"E olha ali em cima: a sua aura gera Pontos de Aura sem parar, até parado.",
			"A Pontuação do lado mostra a força da sua aura. É ela que decide quem vence na Arena!",
		},
		objetivo = "continuar",
		destaque = "PontosAura",
	},
	{
		id = "evoluir",
		falas = {
			"Pontos de Aura servem para evoluir. Tome, um presente para começar!",
			"Abra Evoluir e compre um Nível de Aura: ele aumenta a sua Pontuação.",
		},
		objetivo = "evoluir",
		dica = "Abra Evoluir e compre uma evolução",
		destaque = "Evoluir",
		presente = { pontos = 40 },
	},
	{
		id = "sorte",
		falas = {
			"Isso! Lá também tem a Sorte. Ela deixa as auras raras mais fáceis de sair.",
			"As auras mais raras são quase impossíveis no começo. Evolua e elas ficam ao seu alcance.",
		},
		objetivo = "continuar",
	},
	{
		id = "drop",
		falas = {
			"Agora explore! Pelo Nexo aparecem orbes e lascas brilhando no chão.",
			"Encoste em um para pegar. À noite aparecem mais, e até Estrelas Cadentes!",
		},
		objetivo = "drop",
		dica = "Pegue um drop brilhando no mapa",
		destaque = "Ciclo",
		paciencia = 45,
	},
	{
		id = "estatua",
		falas = {
			"Agora olha só ali na praça: a estátua da Gear 5!",
			"A Gear 5 é a aura mais cobiçada do Nexo. Ela não sai no giro: só no Baú do Sol.",
			"A cada 30 minutos o Titã de Borracha cai na praça. Quem ajuda a derrubar ganha o baú!",
			"Vai lá ver de perto. A placa mostra quanto falta para o próximo evento.",
		},
		objetivo = "estatua",
		dica = "Vá até a estátua da Gear 5 na praça",
		paciencia = 35,
	},
	{
		id = "portais",
		falas = {
			"Por último: os Portais Fragmentados levam ao Corredor dos Perdidos.",
			"Lá você enfrenta criaturas e ganha Fragmentos. Cada mundo pede mais Pontuação.",
			"Siga a luz até os Portais!",
		},
		objetivo = "portais",
		dica = "Siga a luz até os Portais Fragmentados",
		paciencia = 40,
	},
	{
		id = "final",
		falas = {
			"Com Fragmentos você compra Ecos no Cristal do Nexo e aprimora o seu equipamento.",
			"Quando ficar forte, desafie a Arena do Trono, ao sul. Vença o Soberano e vire o Rei do Servidor!",
			"A trilha no canto mostra sempre o próximo passo. Toque nela se esquecer.",
			"É isso! Tome mais um presente. Eu fico por aqui, boa jornada!",
		},
		objetivo = "continuar",
		presente = { pontos = 60, fragmentos = 5 },
	},
} :: { Passo }

Tutorial.porId = {} :: { [string]: number }
for i, p in Tutorial.PASSOS do
	Tutorial.porId[p.id] = i
end

function Tutorial.padrao(): Progresso
	return { passo = 1, concluido = false, presenteAte = 1 }
end

local function inteiro(v: any, minimo: number, maximo: number, padrao: number): number
	return if type(v) == "number" and v == v
		then math.clamp(math.floor(v), minimo, maximo)
		else padrao
end

-- Oferece a apresentação uma única vez, inclusive para veteranos que foram
-- dispensados automaticamente pelo tutorial anterior. Os presentes permanecem marcados
-- como recebidos para contas com giros anteriores; nunca duplicamos recompensas.
-- Marcador adicionado em 2026-11-26: evita voltar a oferecer nas próximas entradas.
function Tutorial.normalizar(t: any, giros: number?): Progresso
	local n = #Tutorial.PASSOS
	local veterano = (giros or 0) > 0
	if type(t) ~= "table" then
		return {
			passo = 1,
			concluido = false,
			presenteAte = if veterano then n else 1,
			apresentacaoOferecida = true,
		}
	end
	-- Migração: versão antiga marcava veteranos como concluídos sem sequer abrir
	-- a primeira fala. Essa combinação identifica a dispensa automática antiga.
	-- Ao oferecer uma vez, mantém todos os presentes como já recebidos.
	local dispensaAntiga = veterano
		and t.apresentacaoOferecida ~= true
		and t.concluido == true
		and t.passo == 1
		and t.presenteAte == n
	return {
		passo = inteiro(t.passo, 1, n, 1),
		concluido = if dispensaAntiga then false else t.concluido == true,
		presenteAte = inteiro(t.presenteAte, 1, n, 1),
		apresentacaoOferecida = true,
	}
end

-- O que o servidor consegue conferir sozinho
export type Situacao = { giros: number, evolucoes: number }

-- Pode sair do passo atual? (objetivos que o servidor não vê, como drop e portais, valem)
function Tutorial.cumpriu(objetivo: Objetivo, s: Situacao): boolean
	if objetivo == "girar" then
		return s.giros > 0
	elseif objetivo == "evoluir" then
		return s.evolucoes > 0
	end
	return true
end

-- Avança do passo `de` para o próximo. Devolve (ok, presente do novo passo, mensagem)
function Tutorial.avancar(
	p: Progresso,
	de: any,
	s: Situacao
): (boolean, { pontos: number?, fragmentos: number? }?, string?)
	if p.concluido then
		return false, nil, "Tutorial já concluído."
	end
	if type(de) ~= "number" or de ~= p.passo then
		return false, nil, "Passo fora de ordem."
	end
	local atual = Tutorial.PASSOS[p.passo]
	if not Tutorial.cumpriu(atual.objetivo, s) then
		return false, nil, "Termine o passo primeiro."
	end
	if p.passo >= #Tutorial.PASSOS then
		p.concluido = true
		return true, nil, nil
	end
	p.passo += 1
	if p.passo <= p.presenteAte then
		return true, nil, nil
	end
	p.presenteAte = p.passo
	return true, Tutorial.PASSOS[p.passo].presente, nil
end

function Tutorial.pular(p: Progresso)
	p.concluido = true
end

-- Rever o tutorial do começo (os presentes não se repetem)
function Tutorial.reiniciar(p: Progresso)
	p.passo = 1
	p.concluido = false
end

-- Texto do presente para mostrar na tela
function Tutorial.textoPresente(presente: { pontos: number?, fragmentos: number? }?): string?
	if not presente then
		return nil
	end
	local partes = {}
	if presente.pontos and presente.pontos > 0 then
		table.insert(partes, string.format("+%d Pontos de Aura", presente.pontos))
	end
	if presente.fragmentos and presente.fragmentos > 0 then
		table.insert(partes, string.format("+%d Fragmentos", presente.fragmentos))
	end
	return if #partes > 0 then table.concat(partes, " · ") else nil
end

return Tutorial
