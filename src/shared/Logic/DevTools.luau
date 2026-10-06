--!strict
-- DEV panel rules (pure, tested in tests/DevTools.spec.luau): the amount pickers, the search
-- filter and argument checks shared by the panel (quick message) and DevService (the real check).
local DevTools = {}

-- Ectoplasm grants: +1K, +1M, ... +1Dc, then MAX. World 2 prices reach ~2.4e27 (area 32).
DevTools.ECTO_MAX = 1e36
-- Spirit Shards grants: +100 ... +100K, then MAX
DevTools.SHARDS_MAX = 1e6

export type Amount = { Value: number, Label: string }

local function list(values: { number }, max: number, short: (number) -> string): { Amount }
	local out: { Amount } = {}
	for _, v in values do
		table.insert(out, { Value = v, Label = "+" .. short(v) })
	end
	table.insert(out, { Value = max, Label = "MAX" })
	return out
end

-- The amount buttons for "Ecto" or "Shards" (each power of 1000 for Ecto up to Dc). `short`
-- formats the labels (Format.Short).
function DevTools.Amounts(kind: string, short: (number) -> string): { Amount }
	if kind == "Shards" then
		return list({ 100, 1000, 10000, 100000 }, DevTools.SHARDS_MAX, short)
	end
	-- literals, not 10^e: pow can land just under 1e33 (shown as "1000No")
	return list({ 1e3, 1e6, 1e9, 1e12, 1e15, 1e18, 1e21, 1e24, 1e27, 1e30, 1e33 }, DevTools.ECTO_MAX, short)
end

-- Whole number in [lo, hi] (finite), else nil.
function DevTools.Int(arg: any, lo: number, hi: number): number?
	if type(arg) ~= "number" or arg ~= arg or arg % 1 ~= 0 or arg < lo or arg > hi then
		return nil
	end
	return arg
end

-- A valid grant amount for "Ecto" / "Shards", else nil.
function DevTools.Grant(kind: string, arg: any): number?
	if kind == "Shards" then
		return DevTools.Int(arg, 1, DevTools.SHARDS_MAX)
	elseif kind == "Ecto" then
		return DevTools.Int(arg, 1, DevTools.ECTO_MAX)
	end
	return nil
end

-- The checkpoint a dev "set checkpoint" for `room` saves: rounded down to a checkpoint room.
function DevTools.Checkpoint(room: number, every: number): number
	if room ~= room or every < 1 then
		return 0
	end
	return math.max(0, math.floor(room / every) * every)
end

local function words(s: string): { string }
	local out: { string } = {}
	for w in string.lower(s):gmatch("[^%s]+") do
		table.insert(out, w)
	end
	return out
end

-- Search filter: true when every word of `query` is found (plain, any case) in `text`.
-- An empty query matches everything.
function DevTools.Matches(query: string, text: string): boolean
	local hay = string.lower(text)
	for _, w in words(query) do
		if not string.find(hay, w, 1, true) then
			return false
		end
	end
	return true
end

-- Two-tap confirm: the first tap arms the action (returns false); a second tap within `window`
-- seconds goes through (returns true and disarms). `armed` maps key -> time of the first tap.
function DevTools.Confirm(armed: { [string]: number }, key: string, now: number, window: number): boolean
	local t = armed[key]
	if t and now - t <= window then
		armed[key] = nil
		return true
	end
	armed[key] = now
	return false
end

return DevTools
