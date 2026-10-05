--!strict
-- Pet egg rules (pure, tested in tests/Eggs.spec.luau). Egg definitions live in Config.Eggs;
-- these functions only take the egg table, so the CLI tests can run them without Roblox.
local Eggs = {}

Eggs.REQUEST_ID_MAX = 40 -- characters in a client hatch request id
Eggs.KEEP_RECORDS = 20 -- hatch results remembered per profile (retries return the stored result)

export type Odds = { Pet: string, Chance: number }
export type Egg = { Unlock: number, Odds: { Odds } }
export type Record = { Egg: string, Pet: string, Uid: string, T: number }

-- Sum of the egg's percent chances (must be exactly 100).
function Eggs.Total(egg: Egg): number
	local t = 0
	for _, o in egg.Odds do
		t += o.Chance
	end
	return t
end

-- Pet id for a uniform roll r in [0, 1). Walks the odds in their listed order.
function Eggs.Roll(egg: Egg, r: number): string
	local total = Eggs.Total(egg)
	local x = math.clamp(r, 0, 1) * total
	local acc = 0
	for _, o in egg.Odds do
		acc += o.Chance
		if x < acc then
			return o.Pet
		end
	end
	return egg.Odds[#egg.Odds].Pet
end

-- True when the player's Boss Tower checkpoint opens this egg.
function Eggs.Unlocked(egg: Egg, checkpoint: number): boolean
	return (checkpoint or 0) >= (egg.Unlock or 0)
end

-- True when some egg can hatch this pet (pets in no egg, such as event pets, can't be won again).
function Eggs.Hatchable(eggs: { [string]: Egg }, petId: string): boolean
	for _, egg in eggs do
		for _, o in egg.Odds do
			if o.Pet == petId then
				return true
			end
		end
	end
	return false
end

-- A client request id: 1..REQUEST_ID_MAX characters of letters, digits, "-", "_", "{", "}".
function Eggs.ValidRequestId(id: any): boolean
	return type(id) == "string" and #id >= 1 and #id <= Eggs.REQUEST_ID_MAX and string.find(id, "^[%w%-_{}]+$") ~= nil
end

-- Order key of a record: pet uids ("p12") only grow, so they give the hatch order; T breaks ties.
local function order(rec: Record): number
	return (tonumber(string.match(rec.Uid, "^p(%d+)$")) or 0) * 1e10 + rec.T
end

-- Request ids to drop so that only the newest `keep` records remain.
function Eggs.Prune(records: { [string]: Record }, keep: number): { string }
	local ids = {}
	for id in records do
		table.insert(ids, id)
	end
	if #ids <= keep then
		return {}
	end
	table.sort(ids, function(a, b)
		local oa, ob = order(records[a]), order(records[b])
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	local out = {}
	for i = 1, #ids - keep do
		table.insert(out, ids[i])
	end
	return out
end

return Eggs
