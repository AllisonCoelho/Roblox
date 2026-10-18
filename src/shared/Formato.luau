-- Formatação de números e tempos no padrão brasileiro
local Formato = {}

-- 12450 -> "12.450"
function Formato.inteiro(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local partes = {}
	while #s > 3 do
		table.insert(partes, 1, string.sub(s, -3))
		s = string.sub(s, 1, -4)
	end
	table.insert(partes, 1, s)
	return (if n < 0 then "-" else "") .. table.concat(partes, ".")
end

local function decimal(n: number): string
	local s = string.format("%.1f", n)
	s = string.gsub(s, "%.0$", "")
	return (string.gsub(s, "%.", ","))
end

-- Números grandes: 5000 -> "5 mil", 1200000 -> "1,2 mi"
function Formato.curto(n: number): string
	local a = math.abs(n)
	if a >= 1e12 then
		return decimal(n / 1e12) .. " tri"
	elseif a >= 1e9 then
		return decimal(n / 1e9) .. " bi"
	elseif a >= 1e6 then
		return decimal(n / 1e6) .. " mi"
	elseif a >= 1e4 then
		return decimal(n / 1e3) .. " mil"
	end
	return Formato.inteiro(n)
end

-- 3725 -> "1:02:05", 42 -> "0:42", 97200 -> "1d 03:00"
function Formato.tempo(segundos: number): string
	local s = math.max(0, math.floor(segundos))
	local d = s // 86400
	local h = (s % 86400) // 3600
	local m = (s % 3600) // 60
	local r = s % 60
	if d > 0 then
		return string.format("%dd %02d:%02d", d, h, m)
	elseif h > 0 then
		return string.format("%d:%02d:%02d", h, m, r)
	end
	return string.format("%d:%02d", m, r)
end

return Formato
