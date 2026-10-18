-- Trava de sessão dos dados salvos (lógica pura, testada em testes/logica.luau).
-- Cada registro no DataStore guarda os dados e qual servidor está usando eles agora.
-- Só o servidor dono da trava pode salvar; outro servidor espera ela ser liberada
-- (ou expirar, se o servidor antigo caiu sem liberar).
local Sessao = {}

-- Segundos sem renovar para uma trava ser considerada abandonada.
-- O autosave renova a trava, então isto precisa ser bem maior que o intervalo dele.
Sessao.EXPIRA = 150

export type Trava = { jobId: string, ts: number }
export type Registro = { dados: any?, sessao: Trava? }

-- Aceita registro novo, vazio ou no formato antigo (estado salvo direto, sem envelope)
function Sessao.normalizar(valor: any): Registro
	if type(valor) ~= "table" then
		return { dados = nil, sessao = nil }
	end
	if valor.dados == nil and valor.versao ~= nil then
		return { dados = valor, sessao = nil }
	end
	return valor
end

-- Tenta pegar a trava. Devolve o registro a gravar, ou nil e o motivo ("ocupado")
function Sessao.travar(valor: any, jobId: string, agora: number): (Registro?, string?)
	local r = Sessao.normalizar(valor)
	local s = r.sessao
	if s and s.jobId ~= jobId and agora - s.ts < Sessao.EXPIRA then
		return nil, "ocupado"
	end
	r.sessao = { jobId = jobId, ts = agora }
	return r, nil
end

-- Monta o registro a salvar. Só funciona com a trava na mão; com liberar = true ela é solta.
-- Devolve nil e "sem_trava" se outro servidor já assumiu (assim nunca sobrescrevemos ele).
function Sessao.salvar(
	valor: any,
	jobId: string,
	agora: number,
	dados: any,
	liberar: boolean
): (Registro?, string?)
	local r = Sessao.normalizar(valor)
	local s = r.sessao
	if not s or s.jobId ~= jobId then
		return nil, "sem_trava"
	end
	r.dados = dados
	r.sessao = if liberar then nil else { jobId = jobId, ts = agora }
	return r, nil
end

return Sessao
