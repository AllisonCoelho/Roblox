-- Trilhas de pose do personagem durante o giro (lógica pura, testada).
-- Uma trilha é uma lista de quadros-chave { tempo, nome da pose }; entre dois quadros a pose
-- é misturada com suavização. As poses em si (ângulos das juntas) ficam em
-- src/client/Mundo/Motion.luau; aqui só se decide QUAL pose vale em cada instante.
local Trilha = {}

export type Quadro = { tempo: number, pose: string }
export type Tempos = {
	t1: number, -- fim do Chamado
	t2: number, -- fim da Ressonância
	t3: number, -- fim da Instabilidade
	tEstouro: number, -- instante da ruptura
	t4: number, -- revelação
	fim: number, -- fim dos efeitos
}

Trilha.NEUTRA = "neutra"

local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Devolve (pose de origem, pose de destino, peso 0..1) para o instante t
function Trilha.avaliar(trilha: { Quadro }, t: number): (string, string, number)
	local n = #trilha
	if n == 0 then
		return Trilha.NEUTRA, Trilha.NEUTRA, 0
	end
	if t <= trilha[1].tempo then
		return trilha[1].pose, trilha[1].pose, 0
	end
	for i = 1, n - 1 do
		local a, b = trilha[i], trilha[i + 1]
		if t < b.tempo then
			local duracao = b.tempo - a.tempo
			return a.pose, b.pose, if duracao > 0 then suave((t - a.tempo) / duracao) else 1
		end
	end
	return trilha[n].pose, trilha[n].pose, 0
end

-- Raridades altas: o personagem alcança a energia, agarra, força a abertura e RASGA a fenda
function Trilha.rasgar(tp: Tempos): { Quadro }
	return {
		{ tempo = 0, pose = Trilha.NEUTRA },
		{ tempo = tp.t1, pose = "alcancar" },
		{ tempo = tp.t2, pose = "agarrar" },
		{ tempo = tp.t3, pose = "forcar" },
		{ tempo = tp.tEstouro, pose = "forcar" },
		{ tempo = math.min(tp.tEstouro + 0.12, tp.t4), pose = "rasgar" },
		{ tempo = tp.t4, pose = "rasgar" },
		{ tempo = tp.fim, pose = Trilha.NEUTRA },
	}
end

-- Raridades comuns: um gesto curto de chamar a energia e soltá-la.
-- duasMaos = versão um pouco maior (categoria Moderada).
function Trilha.gesto(tp: Tempos, duasMaos: boolean): { Quadro }
	local gesto = if duasMaos then "gestoDuplo" else "gesto"
	local impulso = if duasMaos then "impulsoDuplo" else "impulso"
	return {
		{ tempo = 0, pose = Trilha.NEUTRA },
		{ tempo = math.max(tp.t1, 0.1), pose = gesto },
		{ tempo = tp.tEstouro, pose = gesto },
		{ tempo = tp.t4, pose = impulso },
		{ tempo = tp.fim, pose = Trilha.NEUTRA },
	}
end

-- Quanto a fenda está aberta (0..1) no instante t das raridades altas:
-- fresta que cresce a cada batida da instabilidade, abre de vez na ruptura e fecha no fim.
function Trilha.aberturaFenda(tp: Tempos, t: number, instavel: number, impulso: number): number
	if t < tp.t2 then
		return 0
	elseif t < tp.tEstouro then
		return 0.06 + 0.22 * instavel + 0.06 * impulso
	elseif t < tp.t4 then
		local f = suave((t - tp.tEstouro) / 0.12)
		return 0.28 + 0.72 * f
	end
	return 1 - suave((t - tp.t4) / math.max(tp.fim - tp.t4, 0.01))
end

-- Quando as mãos do personagem guiam a fenda: metade da largura a partir da distância entre
-- as mãos. As bordas ficam um pouco para dentro das mãos; depois da revelação a fenda fecha
-- junto com `abertura`, mesmo que os braços ainda estejam voltando.
Trilha.FOLGA_MAOS = 0.9
-- Distância mínima da fenda à frente do corpo (studs), para ela não entrar no tronco quando
-- os braços se abrem para os lados
Trilha.FRENTE_MINIMA = 1.8

function Trilha.meiaLarguraPelasMaos(
	tp: Tempos,
	t: number,
	distanciaMaos: number,
	abertura: number
): number
	local meia = distanciaMaos / 2 * Trilha.FOLGA_MAOS
	if t >= tp.t4 then
		meia *= abertura
	end
	return meia
end

return Trilha
