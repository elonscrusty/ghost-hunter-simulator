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

export type OwnedHunter = { Id: string, Locked: boolean?, T: number?, Tier: number? }

-- Sum of Capture Power of the equipped hunters (unknown / missing uids are ignored).
-- powerOf(id, tier) gives one hunter's power (tier 0 = Normal, 1 = Shiny, 2 = Mega).
function Rules.CrewPower(equipped: { string }, owned: { [string]: OwnedHunter }, powerOf: (string, number) -> number): number
	local sum = 0
	for _, uid in equipped do
		local h = owned[uid]
		if h then
			sum += powerOf(h.Id, h.Tier or 0)
		end
	end
	return sum
end

-- Sorts uids strongest first (ties: rarity order, then uid for stability).
function Rules.SortByPower(owned: { [string]: OwnedHunter }, powerOf: (string, number) -> number, rarityOrder: (string) -> number): { string }
	local uids = {}
	for uid in owned do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		local pa, pb = powerOf(owned[a].Id, owned[a].Tier or 0), powerOf(owned[b].Id, owned[b].Tier or 0)
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

function Rules.EquipBest(owned: { [string]: OwnedHunter }, powerOf: (string, number) -> number, rarityOrder: (string) -> number, slots: number): { string }
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

-- Boss reward split: each helper's fraction of the boss reward = their share of all the
-- damage dealt (shares add up to 1, so the boss pays out its reward once in total).
function Rules.DamageShare(damage: number, totalDamage: number): number
	if totalDamage <= 0 or damage <= 0 then
		return 0
	end
	return math.clamp(damage / totalDamage, 0, 1)
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

--==================================================================
-- v1.6: shared rewards, tiers, retaliation, pets, tower, events
--==================================================================

-- Splits an integer pool by weights so the parts always add up to the pool: everyone gets the
-- floor of their exact share, then leftover units go to the largest fractional remainders
-- (ties: bigger weight, then earlier index). Zero / negative / NaN weights get nothing.
function Rules.SplitPool(pool: number, weights: { number }): { number }
	pool = if pool == pool then math.max(0, math.floor(pool)) else 0
	local out = table.create(#weights, 0)
	local total = 0
	for _, w in weights do
		if w == w and w > 0 then
			total += w
		end
	end
	if total <= 0 or pool == 0 then
		return out
	end
	local rems = {}
	local given = 0
	for i, w in weights do
		if w == w and w > 0 then
			local exact = pool * w / total
			local base = math.floor(exact)
			out[i] = base
			given += base
			table.insert(rems, { I = i, R = exact - base, W = w })
		end
	end
	table.sort(rems, function(a, b)
		if a.R ~= b.R then
			return a.R > b.R
		end
		if a.W ~= b.W then
			return a.W > b.W
		end
		return a.I < b.I
	end)
	local k = 1
	while given < pool and #rems > 0 do
		out[rems[k].I] += 1
		given += 1
		k = k % #rems + 1
	end
	return out
end

-- How many contributors size a shared pool: those with at least `minShare` of the total damage
-- (alts that land one tick can't inflate the pool). Always at least 1.
function Rules.PoolMembers(weights: { number }, minShare: number): number
	local total = 0
	for _, w in weights do
		if w == w and w > 0 then
			total += w
		end
	end
	local n = 0
	for _, w in weights do
		if w == w and w > 0 and w >= total * minShare then
			n += 1
		end
	end
	return math.max(1, n)
end

-- Retaliation target rotation: given the eligible hunter keys (any order) and the key hit
-- last time, returns the next key after it in sorted order (wrapping), so attacks spread over
-- every eligible hunter instead of focusing one. nil when nobody is eligible.
function Rules.NextTarget(keys: { string }, last: string?): string?
	if #keys == 0 then
		return nil
	end
	local sorted = table.clone(keys)
	table.sort(sorted)
	if last then
		for _, k in sorted do
			if k > last then
				return k
			end
		end
	end
	return sorted[1]
end

-- Damage that really counts: never more than the Spirit the ghost had left (no overkill).
function Rules.Effective(damage: number, spiritLeft: number): number
	if damage ~= damage or damage <= 0 or spiritLeft <= 0 then
		return 0
	end
	return math.min(damage, spiritLeft)
end

function Rules.HunterPower(base: number, tierMult: number): number
	return base * tierMult
end

function Rules.HunterMaxHP(power: number, hpPerPower: number, hpBonus: number): number
	return math.max(1, power * hpPerPower * (1 + math.max(0, hpBonus)))
end

-- One ghost hit: a share of the ghost's max Spirit, capped to a share of the target's max HP.
function Rules.RetaliationHit(maxSpirit: number, perSpirit: number, targetMaxHP: number, cap: number): number
	return math.max(1, math.min(maxSpirit * perSpirit, targetMaxHP * cap))
end

-- Knockout length after the pet Recovery bonus (never below 10% of the base timer).
function Rules.RecoverySeconds(base: number, recoveryBonus: number): number
	return math.max(base * 0.1, base * (1 - math.clamp(recoveryBonus, 0, 0.9)))
end

-- Total bonus per kind from a list of {Kind, Value}, each kind capped.
function Rules.PetBonuses(bonuses: { { Kind: string, Value: number } }, caps: { [string]: number }): { [string]: number }
	local out: { [string]: number } = {}
	for _, b in bonuses do
		if type(b.Value) == "number" and b.Value == b.Value and b.Value > 0 then
			out[b.Kind] = (out[b.Kind] or 0) + b.Value
		end
	end
	for kind, v in out do
		local cap = caps[kind]
		if cap then
			out[kind] = math.min(v, cap)
		end
	end
	return out
end

export type TowerCfg = {
	BaseHP: number,
	HPGrowth: number,
	FiveRoomBump: number,
	MinKillSeconds: number,
	HitFractionBase: number,
	HitFractionGrowth: number,
	HitFractionCap: number,
	MaxScaledRoom: number,
	ShardsBase: number,
	ShardsPerRoom: number,
	EctoBase: number,
	MilestoneEvery: { [number]: number },
}

-- Boss health for room `room` (absolute curve, floored at partyPower * MinKillSeconds) and the
-- boss hit as a fraction of the target hunter's max HP. Room is clamped and health capped so
-- numbers stay finite at any height.
function Rules.TowerScale(room: number, cfg: TowerCfg, partyPower: number): (number, number)
	local r = math.clamp(math.floor(room), 1, cfg.MaxScaledRoom)
	local hp = cfg.BaseHP * cfg.HPGrowth ^ (r - 1) * cfg.FiveRoomBump ^ ((r - 1) // 5)
	local power = if partyPower == partyPower then math.max(0, partyPower) else 0
	hp = math.min(1e300, math.max(hp, power * cfg.MinKillSeconds))
	local hit = math.min(cfg.HitFractionCap, cfg.HitFractionBase * cfg.HitFractionGrowth ^ (r - 1))
	return math.max(1, math.floor(hp)), hit
end

-- Highest checkpoint reached after clearing `room` (0 = none): rooms 5, 10, ... with every=5.
function Rules.TowerCheckpoint(room: number, every: number): number
	return math.max(0, math.floor(room / every) * every)
end

function Rules.TowerMilestone(room: number, cfg: TowerCfg): number
	local best = 1
	for every, mult in cfg.MilestoneEvery do
		if room % every == 0 and mult > best then
			best = mult
		end
	end
	return best
end

-- Reward pool PER PARTY MEMBER for beating `room` (the run's pool = this * party size, then
-- split by damage). Ecto is in base units before the zone multiplier.
function Rules.TowerReward(room: number, cfg: TowerCfg): (number, number)
	local r = math.max(1, math.floor(room))
	local m = Rules.TowerMilestone(r, cfg)
	local shards = math.floor((cfg.ShardsBase + math.min(r, cfg.MaxScaledRoom) * cfg.ShardsPerRoom) * m)
	local ecto = math.floor(cfg.EctoBase * math.min(r, cfg.MaxScaledRoom) ^ 0.9 * m)
	return shards, ecto
end

export type MergeHunter = { Id: string, Locked: boolean?, Tier: number? }

-- Checks a merge request. Returns (ok, error text, hunter id, current tier).
-- blocked(uid) -> reason text if the hunter is busy (in a trade, knocked out, ...).
function Rules.MergeCheck(owned: { [string]: MergeHunter }, uids: { any }, count: number, maxTier: number, blocked: (string) -> string?): (boolean, string?, string?, number?)
	if type(uids) ~= "table" or #uids ~= count then
		return false, string.format("Pick exactly %d hunters", count), nil, nil
	end
	local seen = {}
	local id, tier = nil, nil
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return false, "Pick different hunters", nil, nil
		end
		seen[uid] = true
		local h = owned[uid]
		if not h then
			return false, "You don't own that hunter", nil, nil
		end
		if h.Locked then
			return false, "Locked hunters can't be merged", nil, nil
		end
		local why = blocked(uid)
		if why then
			return false, why, nil, nil
		end
		local t = h.Tier or 0
		if id == nil then
			id, tier = h.Id, t
		elseif h.Id ~= id or t ~= tier then
			return false, "All hunters must be the same hunter and tier", nil, nil
		end
	end
	if (tier :: number) >= maxTier then
		return false, "Already the highest tier", nil, nil
	end
	return true, nil, id, tier
end

-- Active play credit for a timed event: seconds `step` count only inside [startT, endT).
function Rules.EventCredit(nowT: number, startT: number, endT: number, step: number): number
	if nowT < startT or nowT >= endT or step <= 0 then
		return 0
	end
	return math.min(step, endT - nowT)
end

return Rules
