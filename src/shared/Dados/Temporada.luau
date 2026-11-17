-- Passe de Temporada (lógica pura, testada). 30 níveis com trilha grátis e trilha premium
-- (o premium é o passe "passeTemporada", 299 Robux). Recompensas são só cosméticas.
--
-- XP: giros de aura (com teto diário, para o giro automático não "farmar" a temporada sozinho),
-- andares das Incursões e vitórias. O VIP ganha +10% de XP (conveniência, sem poder).
-- Salvo em perfil.temporada = { id, xp, resgates = { gratis = {}, premium = {} }, giroDia = { dia, xp } }
local Temporada = {}

Temporada.ID = "t1"
Temporada.NOME = "Temporada 1 — Despertar das Fendas"
Temporada.INICIO = 1794873600 -- 17/11/2026 00:00 UTC
Temporada.FIM = 1800057600 -- 16/01/2027 00:00 UTC
Temporada.NIVEIS = 30
Temporada.XP_POR_NIVEL = 120

Temporada.XP = {
	giro = 1,
	andar = 12,
	vitoria = 50,
}
Temporada.TETO_GIRO_DIA = 150 -- XP máximo por dia vindo de giros
Temporada.BONUS_VIP = 0.1

-- nível -> { gratis = item?, premium = item? }
Temporada.RECOMPENSAS = {
	[1] = { gratis = "dis_estrela", premium = "tit_rompe" },
	[3] = { premium = "dis_cometa" },
	[5] = { gratis = "tit_andarilho" },
	[6] = { premium = "ras_violeta" },
	[9] = { premium = "tit_guardiao" },
	[10] = { gratis = "ras_cinza" },
	[12] = { premium = "dis_olho" },
	[15] = { gratis = "tit_cacador", premium = "ras_aurora" },
	[18] = { premium = "tit_soberano" },
	[20] = { gratis = "dis_lua" },
	[21] = { premium = "dis_coracao" },
	[24] = { premium = "ras_eclipse" },
	[25] = { gratis = "tit_veterano" },
	[27] = { premium = "dis_nexo" },
	[29] = { premium = "ras_prisma" },
	[30] = { premium = "tit_mestre" },
} :: { [number]: { gratis: string?, premium: string? } }

function Temporada.padrao(): any
	return {
		id = Temporada.ID,
		xp = 0,
		resgates = { gratis = {}, premium = {} },
		giroDia = { dia = 0, xp = 0 },
	}
end

-- Estado da temporada atual (temporada nova zera o progresso)
function Temporada.de(t: any): any
	if type(t) ~= "table" or t.id ~= Temporada.ID then
		return Temporada.padrao()
	end
	t.xp = if type(t.xp) == "number" then t.xp else 0
	t.resgates = if type(t.resgates) == "table" then t.resgates else {}
	t.resgates.gratis = if type(t.resgates.gratis) == "table" then t.resgates.gratis else {}
	t.resgates.premium = if type(t.resgates.premium) == "table" then t.resgates.premium else {}
	t.giroDia = if type(t.giroDia) == "table" then t.giroDia else { dia = 0, xp = 0 }
	return t
end

function Temporada.ativa(agora: number): boolean
	return agora >= Temporada.INICIO and agora < Temporada.FIM
end

function Temporada.nivel(xp: number): number
	return math.clamp(math.floor(xp / Temporada.XP_POR_NIVEL), 0, Temporada.NIVEIS)
end

-- Soma XP respeitando o teto diário dos giros. Devolve quanto entrou de fato.
function Temporada.ganhar(t: any, fonte: string, dia: number, vip: boolean): number
	local base = Temporada.XP[fonte]
	if not base then
		return 0
	end
	local ganho = base * (if vip then 1 + Temporada.BONUS_VIP else 1)
	if fonte == "giro" then
		if t.giroDia.dia ~= dia then
			t.giroDia = { dia = dia, xp = 0 }
		end
		ganho = math.min(ganho, Temporada.TETO_GIRO_DIA - t.giroDia.xp)
		if ganho <= 0 then
			return 0
		end
		t.giroDia.xp += ganho
	end
	local maximo = Temporada.NIVEIS * Temporada.XP_POR_NIVEL
	local antes = t.xp
	t.xp = math.min(maximo, t.xp + ganho)
	return t.xp - antes
end

-- Pode resgatar a recompensa do nível n na trilha? Devolve o id do item ou nil + motivo.
function Temporada.resgatavel(
	t: any,
	n: number,
	trilha: string,
	premium: boolean
): (string?, string?)
	local r = Temporada.RECOMPENSAS[n]
	local id = r and (r :: any)[trilha]
	if not id then
		return nil, "Não há recompensa aqui."
	end
	if trilha == "premium" and not premium then
		return nil, "Recompensa do Passe de Temporada."
	end
	if Temporada.nivel(t.xp) < n then
		return nil, "Alcance o nível " .. n .. " primeiro."
	end
	if t.resgates[trilha][tostring(n)] then
		return nil, "Já resgatada."
	end
	return id, nil
end

return Temporada
