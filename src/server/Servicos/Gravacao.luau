-- Fila de gravação dos dados de cada jogador (lógica pura, testada em testes/logica.luau).
-- Duas regras evitam que um salvamento antigo apague uma mudança mais nova
-- (por exemplo, granulados de uma compra já confirmada ao Roblox):
--   1. Só uma gravação por vez para cada jogador; as outras esperam a vez.
--   2. O estado é copiado DENTRO do UpdateAsync, no instante em que é gravado, e não antes
--      da espera. Assim cada gravação leva tudo o que mudou até ali, e a última a terminar
--      é sempre a mais nova.
local Gravacao = {}

export type Fila = { ocupada: boolean }

function Gravacao.nova(): Fila
	return { ocupada = false }
end

-- Roda "fn" sozinha na fila. "esperar" cede a vez (task.wait no Roblox) enquanto outra
-- gravação está em andamento. Devolve true só se fn devolveu true sem erro.
function Gravacao.executar(fila: Fila, esperar: () -> (), fn: () -> boolean): boolean
	while fila.ocupada do
		esperar()
	end
	fila.ocupada = true
	local ok, resultado = pcall(fn)
	fila.ocupada = false
	return ok and resultado == true
end

-- Cópia profunda (tabelas dentro de tabelas também), para o que vai ao DataStore não
-- compartilhar nenhuma tabela com o estado vivo do jogo
function Gravacao.copiar<T>(valor: T): T
	if type(valor) ~= "table" then
		return valor
	end
	local copia = {}
	for k, v in valor :: any do
		copia[k] = Gravacao.copiar(v)
	end
	return copia :: any
end

return Gravacao
