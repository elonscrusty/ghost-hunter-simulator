--!strict
-- Pure game rules (no Roblox types) so they can be unit tested with the Luau CLI.
-- Callers pass in the bits of Config they need.

local Rules = {}

export type PoolEntry = { Hunter: string, Weight: number }

-- Weight of an entry after the luck boost: rarities whose order >= luckFrom get luckMul.
local function weightOf(e: PoolEntry, rarityOrder: (string) -> number, luckMul: number, luckFrom: number): number
	if rarityOrder(e.Hunter) >= luckFrom then
		return e.Weight * luckMul
	end
	return e.Weight
end

-- Chance (0..1) of each hunter in a crate.
function Rules.Odds(pool: { PoolEntry }, rarityOrder: (string) -> number, luckMul: number, luckFrom: number): { [string]: number }
	local total = 0
	for _, e in pool do
		total += weightOf(e, rarityOrder, luckMul, luckFrom)
	end
	local out = {}
	for _, e in pool do
		out[e.Hunter] = if total > 0 then weightOf(e, rarityOrder, luckMul, luckFrom) / total else 0
	end
	return out
end

-- r in [0, 1). Returns the rolled hunter id.
function Rules.Roll(pool: { PoolEntry }, rarityOrder: (string) -> number, luckMul: number, luckFrom: number, r: number): string
	local total = 0
	for _, e in pool do
		total += weightOf(e, rarityOrder, luckMul, luckFrom)
	end
	local pick = r * total
	for _, e in pool do
		pick -= weightOf(e, rarityOrder, luckMul, luckFrom)
		if pick < 0 then
			return e.Hunter
		end
	end
	return pool[#pool].Hunter
end

export type OwnedHunter = { Id: string, Locked: boolean?, T: number? }

-- Sum of Capture Power of the equipped hunters (unknown / missing uids are ignored).
function Rules.CrewPower(equipped: { string }, owned: { [string]: OwnedHunter }, powerOf: (string) -> number): number
	local sum = 0
	for _, uid in equipped do
		local h = owned[uid]
		if h then
			sum += powerOf(h.Id)
		end
	end
	return sum
end

-- Sorts uids strongest first (ties: rarity order, then uid for stability).
function Rules.SortByPower(owned: { [string]: OwnedHunter }, powerOf: (string) -> number, rarityOrder: (string) -> number): { string }
	local uids = {}
	for uid in owned do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		local pa, pb = powerOf(owned[a].Id), powerOf(owned[b].Id)
		if pa ~= pb then
			return pa > pb
		end
		local ra, rb = rarityOrder(owned[a].Id), rarityOrder(owned[b].Id)
		if ra ~= rb then
			return ra > rb
		end
		local na, nb = tonumber(a), tonumber(b)
		if na and nb then
			return na < nb
		end
		return a < b
	end)
	return uids
end

function Rules.EquipBest(owned: { [string]: OwnedHunter }, powerOf: (string) -> number, rarityOrder: (string) -> number, slots: number): { string }
	local sorted = Rules.SortByPower(owned, powerOf, rarityOrder)
	local out = {}
	for i = 1, math.min(slots, #sorted) do
		out[i] = sorted[i]
	end
	return out
end

-- Upgrades: level is 1-based. Returns nil when maxed.
function Rules.UpgradeCost(costs: { number }, level: number): number?
	return costs[level]
end

function Rules.UpgradeValue(levels: { number }, level: number): number
	return levels[math.clamp(level, 1, #levels)]
end

export type DailyInfo = { CanClaim: boolean, Day: number, Wait: number, StreakBroken: boolean }

-- Which day (1..days) the next claim gives, and whether it is claimable now.
-- last = os.time of last claim (0 = never), streak = consecutive days already claimed.
function Rules.Daily(now: number, last: number, streak: number, cooldown: number, resetAfter: number, days: number): DailyInfo
	if last <= 0 then
		return { CanClaim = true, Day = 1, Wait = 0, StreakBroken = false }
	end
	local elapsed = now - last
	if elapsed < 0 then
		-- server clock went backwards; treat as "just claimed"
		return { CanClaim = false, Day = (streak % days) + 1, Wait = cooldown, StreakBroken = false }
	end
	if elapsed >= resetAfter then
		return { CanClaim = true, Day = 1, Wait = 0, StreakBroken = streak > 0 }
	end
	local day = (streak % days) + 1
	if elapsed >= cooldown then
		return { CanClaim = true, Day = day, Wait = 0, StreakBroken = false }
	end
	return { CanClaim = false, Day = day, Wait = cooldown - elapsed, StreakBroken = false }
end

-- Splits an integer total into n positive integer parts (n is reduced if total < n).
function Rules.Split(total: number, n: number): { number }
	total = math.max(0, math.floor(total))
	if total == 0 then
		return {}
	end
	n = math.clamp(math.floor(n), 1, total)
	local base = total // n
	local extra = total - base * n
	local out = table.create(n, base)
	for i = 1, extra do
		out[i] += 1
	end
	return out
end

-- Event reward multiplier for a participant: share of damage scaled by participant count.
function Rules.EventShare(damage: number, totalDamage: number, participants: number, minShare: number, maxShare: number): number
	if totalDamage <= 0 or participants <= 0 then
		return minShare
	end
	return math.clamp((damage / totalDamage) * participants, minShare, maxShare)
end

-- Ectoplasm multiplier from upgrades and boosts.
function Rules.EctoMultiplier(bonus: number, boostActive: boolean, boostMul: number, passMul: number): number
	return (1 + bonus) * (if boostActive then boostMul else 1) * passMul
end

-- Simple sliding-window rate limiter keyed by string.
export type Limiter = { hits: { [string]: { number } }, count: number, window: number }

function Rules.NewLimiter(count: number, window: number): Limiter
	return { hits = {}, count = count, window = window }
end

function Rules.Allow(l: Limiter, key: string, now: number): boolean
	local list = l.hits[key]
	if not list then
		list = {}
		l.hits[key] = list
	end
	local i = 1
	while i <= #list do
		if now - list[i] >= l.window then
			table.remove(list, i)
		else
			i += 1
		end
	end
	if #list >= l.count then
		return false
	end
	table.insert(list, now)
	return true
end

function Rules.Forget(l: Limiter, prefix: string)
	for key in l.hits do
		if string.sub(key, 1, #prefix) == prefix then
			l.hits[key] = nil
		end
	end
end

-- Zone index (1-based order) for a Z coordinate given ordered {MinZ, MaxZ} pairs.
function Rules.ZoneIndexAt(z: number, ranges: { { number } }): number
	for i, r in ranges do
		if z >= r[1] and z < r[2] then
			return i
		end
	end
	if #ranges > 0 and z >= ranges[#ranges][2] then
		return #ranges
	end
	return 1
end

return Rules
