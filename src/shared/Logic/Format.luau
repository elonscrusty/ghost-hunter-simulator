--!strict
-- Number/time formatting shared by UI and signs (pure).
local Format = {}

-- 1250 -> "1,250"
function Format.Commas(n: number): string
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if neg then "-" else "") .. out
end

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1250 -> "1,250", 125000 -> "125K", 1520000 -> "1.52M"
function Format.Short(n: number): string
	if math.abs(n) < 100000 then
		return Format.Commas(n)
	end
	local i = 1
	local v = math.abs(n)
	while v >= 1000 and i < #SUFFIX do
		v /= 1000
		i += 1
	end
	local digits = if v >= 100 then 0 elseif v >= 10 then 1 else 2
	local s = string.format("%." .. digits .. "f", math.floor(v * 10 ^ digits) / 10 ^ digits)
	if digits > 0 then
		-- trim trailing decimal zeros only ("1.50" -> "1.5", "2.00" -> "2"; "100" stays "100")
		s = s:gsub("0+$", "")
		s = s:gsub("%.$", "")
	end
	return (if n < 0 then "-" else "") .. s .. SUFFIX[i]
end

-- 3725 -> "1h 2m", 125 -> "2:05"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Format.Percent(x: number): string
	local p = x * 100
	if p >= 10 then
		return string.format("%d%%", math.floor(p + 0.5))
	elseif p >= 1 then
		return (string.format("%.1f", p):gsub("%.0$", "")) .. "%"
	end
	return (string.format("%.2f", p):gsub("0+$", ""):gsub("%.$", "")) .. "%"
end

return Format
