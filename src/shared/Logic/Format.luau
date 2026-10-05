--!strict
-- Number/time formatting shared by UI and signs (pure).
local Format = {}

-- 1250 -> "1,250" (whole digits even past 1e21, where tostring would switch to "1e+21";
-- prefer Format.Short for anything that can get that big)
function Format.Commas(n: number): string
	local neg = n < 0
	local a = math.floor(math.abs(n))
	local s = if a < 1e15 then tostring(a) else string.format("%.0f", a)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if neg then "-" else "") .. out
end

-- thousand steps: K 1e3, M 1e6, B 1e9, T 1e12, Qa 1e15, Qi 1e18, Sx 1e21, Sp 1e24, Oc 1e27,
-- No 1e30, Dc 1e33 (World 2 prices reach the Sx range)
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1250 -> "1,250", 125000 -> "125K", 1520000 -> "1.52M", 1.41e21 -> "1.41Sx"
function Format.Short(n: number): string
	if n ~= n then
		return "0"
	end
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
	-- tiny epsilon: dividing by 1000 seven times can leave 1.41 as 1.4099999...
	local s = string.format("%." .. digits .. "f", math.floor(v * 10 ^ digits + 1e-7) / 10 ^ digits)
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
