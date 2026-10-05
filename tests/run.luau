-- Tiny test harness for the Luau CLI. Run via tools/check.sh (it generates tests/_Config.luau,
-- a copy of Config with Roblox type stubs, for the economy spec).
local specs = { "./Rules.spec", "./Format.spec", "./Economy.spec", "./Eggs.spec", "./Layout.spec", "./VoidEmperor.spec" }
local passed, failed = 0, 0
for _, path in specs do
	local spec = require(path) :: any
	for name, fn in spec do
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			failed += 1
			print("FAIL " .. path .. " :: " .. name .. " :: " .. tostring(err))
		end
	end
end
print(string.format("%d passed, %d failed", passed, failed))
