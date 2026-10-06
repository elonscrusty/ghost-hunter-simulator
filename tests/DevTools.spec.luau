-- DEV panel rules: amount pickers, search filter, argument checks, two-tap confirm.
local DevTools = require("../src/shared/Logic/DevTools")
local Format = require("../src/shared/Logic/Format")
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local T = {}
T.ecto_amounts_reach_dc_then_max = function()
	local a = DevTools.Amounts("Ecto", Format.Short)
	eq(#a, 12)
	eq(a[1].Value, 1000); eq(a[1].Label, "+1,000")
	eq(a[2].Label, "+1M"); eq(a[5].Label, "+1Qa"); eq(a[11].Label, "+1Dc")
	eq(a[12].Label, "MAX"); eq(a[12].Value, DevTools.ECTO_MAX)
	for i = 2, #a do
		assert(a[i].Value > a[i - 1].Value, "amounts grow")
	end
	for _, x in a do
		assert(DevTools.Grant("Ecto", x.Value) ~= nil, "every button passes the server check: " .. x.Label)
	end
end
T.shard_amounts = function()
	local a = DevTools.Amounts("Shards", Format.Short)
	eq(a[1].Label, "+100"); eq(a[#a].Label, "MAX"); eq(a[#a].Value, 1e6)
	for _, x in a do
		assert(DevTools.Grant("Shards", x.Value) ~= nil, x.Label)
	end
end
T.grant_rejects_bad_args = function()
	eq(DevTools.Grant("Ecto", 0), nil); eq(DevTools.Grant("Ecto", -5), nil); eq(DevTools.Grant("Ecto", 1.5), nil)
	eq(DevTools.Grant("Ecto", 0 / 0), nil); eq(DevTools.Grant("Ecto", math.huge), nil); eq(DevTools.Grant("Ecto", "100"), nil)
	eq(DevTools.Grant("Ecto", 1e37), nil); eq(DevTools.Grant("Shards", 1e6 + 1), nil); eq(DevTools.Grant("Gems", 5), nil)
	eq(DevTools.Grant("Shards", 250), 250)
end
T.int = function()
	eq(DevTools.Int(5, 1, 7), 5); eq(DevTools.Int(8, 1, 7), nil); eq(DevTools.Int(nil, 1, 7), nil); eq(DevTools.Int(2.5, 1, 7), nil)
end
T.checkpoint_rounds_down = function()
	eq(DevTools.Checkpoint(0, 5), 0); eq(DevTools.Checkpoint(4, 5), 0); eq(DevTools.Checkpoint(5, 5), 5); eq(DevTools.Checkpoint(53, 5), 50)
	eq(DevTools.Checkpoint(0 / 0, 5), 0)
end
T.search = function()
	assert(DevTools.Matches("", "anything"))
	assert(DevTools.Matches("  ", "anything"))
	assert(DevTools.Matches("ecto", "ADD ECTOPLASM"))
	assert(DevTools.Matches("ghost king", "GHOST KING: BEATEN the portal boss"))
	assert(DevTools.Matches("king ghost", "GHOST KING"), "word order doesn't matter")
	assert(not DevTools.Matches("ghost queen", "GHOST KING"))
	assert(DevTools.Matches("2x", "2X ECTOPLASM EVENT"))
	assert(DevTools.Matches("(", "a (b)"), "special characters are plain text")
	assert(not DevTools.Matches("%", "100"))
end
T.two_tap_confirm = function()
	local armed = {}
	eq(DevTools.Confirm(armed, "Reset", 10, 4), false, "first tap arms")
	eq(DevTools.Confirm(armed, "Reset", 12, 4), true, "second tap goes")
	eq(DevTools.Confirm(armed, "Reset", 13, 4), false, "disarmed after use")
	eq(DevTools.Confirm(armed, "Reset", 20, 4), false, "too late: re-arms")
	eq(DevTools.Confirm(armed, "Other", 21, 4), false, "keys are separate")
	eq(DevTools.Confirm(armed, "Reset", 22, 4), true)
end
return T
