-- Camada "extravagante" de efeitos que toda aura ganha por cima do efeito dela (só dados e regras
-- puras, testadas em testes/logica.luau; o cliente monta em Mundo/Auras/Extravagancia).
--
-- Engenharia reversa dos jogos de RNG do Roblox (Sol's RNG e parecidos): quanto mais rara a aura,
-- mais camadas ela empilha. As peças que se repetem nesses jogos:
--   * luz e brilho no corpo, faíscas
--   * anéis no chão que sobem e somem
--   * orbes girando em volta do jogador (com rastro)
--   * fitas de luz em espiral subindo pelo corpo
--   * pulsos de partículas na base a cada poucos segundos
--   * pilar de luz até o céu
--   * título da aura flutuando acima da cabeça
--   * portal/círculo acima da cabeça com feixes saindo dos ombros
--   * raios girando em volta do jogador
--   * contorno brilhante no corpo
--   * cores ciclando (cromático), coroa de estrelas e chuva de luz nas mais raras
--   * explosão de "manifestação" ao equipar: anéis, flash, tremor e tela tingida (cutscene curta)
-- Cada aura usa as próprias cores e um tema pelo estilo (chama, névoa, brilho).
local Extravagancia = {}

export type Camada =
	"brilho"
	| "anelChao"
	| "orbes"
	| "espiral"
	| "pulso"
	| "tema"
	| "pilar"
	| "titulo"
	| "portal"
	| "raios"
	| "contorno"
	| "cromatico"
	| "coroa"
	| "chuva"

-- O que cada raridade ACRESCENTA (as camadas se acumulam). Índices de Auras.Tiers.
Extravagancia.POR_TIER = {
	{ "brilho" }, -- Comum
	{ "anelChao" }, -- Incomum
	{ "orbes", "tema" }, -- Raro
	{ "espiral", "pulso" }, -- Épico
	{ "pilar", "titulo" }, -- Lendário
	{ "portal", "raios", "contorno" }, -- Mítico
	{ "cromatico", "coroa", "chuva" }, -- Divino
} :: { { Camada } }

-- Camadas pesadas que somem com "qualidade baixa"
Extravagancia.PESADAS = {
	espiral = true,
	pilar = true,
	portal = true,
	raios = true,
	chuva = true,
	coroa = true,
} :: { [string]: boolean }

-- Camadas que só fazem sentido no próprio jogador ou perto da câmera não entram aqui: o cliente
-- decide pela distância (ver Extravagancia.detalhe).

-- Lista das camadas de uma raridade (acumulada), sem as pesadas se `baixa`
function Extravagancia.camadas(tier: number, baixa: boolean?): { Camada }
	local saida: { Camada } = {}
	local ate = math.clamp(math.floor(tier), 1, #Extravagancia.POR_TIER)
	for i = 1, ate do
		for _, c in Extravagancia.POR_TIER[i] do
			if not (baixa and Extravagancia.PESADAS[c]) then
				table.insert(saida, c)
			end
		end
	end
	return saida
end

function Extravagancia.tem(tier: number, camada: string, baixa: boolean?): boolean
	for _, c in Extravagancia.camadas(tier, baixa) do
		if c == camada then
			return true
		end
	end
	return false
end

-- Quantidades que crescem com a raridade
function Extravagancia.orbes(tier: number): number
	return math.clamp(tier - 1, 2, 6)
end

function Extravagancia.fitas(tier: number): number
	return math.clamp(tier - 2, 2, 5)
end

function Extravagancia.intervaloPulso(tier: number): number
	return math.max(1.2, 4 - tier * 0.4)
end

function Extravagancia.alcanceLuz(tier: number): number
	return 6 + tier * 2
end

-- Tema pelo estilo da aura
export type Tema = {
	textura: string, -- rbxasset://textures/particles/<textura>.dds
	sobe: number, -- velocidade para cima
	tamanho: { number },
	taxa: number,
	brilho: number,
}
Extravagancia.TEMAS = {
	chama = { textura = "fire_main", sobe = 6, tamanho = { 1.2, 0.1 }, taxa = 18, brilho = 1 },
	nevoa = { textura = "smoke_main", sobe = 1.2, tamanho = { 2.5, 4 }, taxa = 6, brilho = 0.4 },
	brilho = { textura = "sparkles_main", sobe = 2.5, tamanho = { 0.6, 0 }, taxa = 14, brilho = 1 },
} :: { [string]: Tema }

function Extravagancia.tema(estilo: string?): Tema
	return Extravagancia.TEMAS[estilo or "brilho"] or Extravagancia.TEMAS.brilho
end

-- Manifestação ao equipar (a "cutscene" curta): quanto mais rara, maior
export type Manifestacao = {
	aneis: number,
	faiscas: number,
	tremor: number, -- força do tremor de câmera (só para o dono)
	flash: number, -- 0..1 brilho do flash de tela (só para o dono)
	tingir: boolean, -- tela tingida com a cor da aura por um instante
	duracao: number,
}
function Extravagancia.manifestacao(tier: number): Manifestacao
	local t = math.clamp(math.floor(tier), 1, #Extravagancia.POR_TIER)
	return {
		aneis = math.clamp(t - 1, 1, 5),
		faiscas = 15 + t * 15,
		tremor = if t >= 4 then 0.3 + (t - 4) * 0.35 else 0,
		flash = if t >= 5 then math.min(0.25 + (t - 5) * 0.2, 0.7) else 0,
		tingir = t >= 6,
		duracao = 0.8 + t * 0.25,
	}
end

-- Nível de detalhe pela distância da câmera: 2 = tudo, 1 = sem as pesadas, 0 = só a luz
function Extravagancia.detalhe(distancia: number, proprio: boolean): number
	if proprio or distancia < 60 then
		return 2
	elseif distancia < 140 then
		return 1
	end
	return 0
end

-- Cor do ciclo cromático (matiz 0..1 no instante t)
function Extravagancia.matiz(t: number, deslocamento: number?): number
	return (t * 0.12 + (deslocamento or 0)) % 1
end

return Extravagancia
