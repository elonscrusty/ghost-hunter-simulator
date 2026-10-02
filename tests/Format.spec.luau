local Format = require("../src/shared/Logic/Format")
local function eq(a, b) if a ~= b then error("expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local T = {}
T.commas = function() eq(Format.Commas(0), "0"); eq(Format.Commas(1250), "1,250"); eq(Format.Commas(100000), "100,000"); eq(Format.Commas(-1234567), "-1,234,567") end
T.short = function() eq(Format.Short(99999), "99,999"); eq(Format.Short(125000), "125K"); eq(Format.Short(1520000), "1.52M"); eq(Format.Short(2000000), "2M") end
-- whole hundreds/tens must keep their zeros (regression: 100,000 used to show "1K")
T.short_keeps_integer_zeros = function()
	eq(Format.Short(100000), "100K"); eq(Format.Short(110000), "110K"); eq(Format.Short(150000), "150K")
	eq(Format.Short(200000), "200K"); eq(Format.Short(130000), "130K"); eq(Format.Short(1e8), "100M")
	eq(Format.Short(10500000), "10.5M"); eq(Format.Short(-250000), "-250K"); eq(Format.Short(1000000), "1M")
end
T.time = function() eq(Format.Time(125), "2:05"); eq(Format.Time(3725), "1h 2m") end
T.percent = function() eq(Format.Percent(0.6), "60%"); eq(Format.Percent(0.02), "2%"); eq(Format.Percent(0.025), "2.5%"); eq(Format.Percent(0.005), "0.5%") end
return T
