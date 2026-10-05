--!strict
-- THE VOID EMPEROR (World 2 final boss): the pure rules VoidEmperorService runs on. No Roblox
-- types here, so every rule is unit tested (tests/VoidEmperor.spec).
--   Phase 1 THE CROWN   (100-66%): x ShieldTaken while any pylon stands; all pylons down = he
--                                  kneels (x KneelTaken) and the 66% wall opens
--   Phase 2 THE SPLIT   (66-33%):  only the crowned copy takes damage
--   Phase 3 THE LAST LIGHT (33-0%): damage only while every active light circle is held
-- Damage past the current phase's wall is wasted (never carried into the next phase).
local VoidEmperor = {}

local function finite(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

-- Boss Spirit at spawn: Seconds * max(sum(min(power, cap)), minCrews * powerRef). Bad powers
-- (NaN, negative) count as 0; the floor means a small group still faces minCrews crews' worth.
function VoidEmperor.Spirit(powers: { number }, seconds: number, minCrews: number, powerRef: number, cap: number): number
	local sum = 0
	for _, p in powers do
		if finite(p) and p > 0 then
			sum += math.min(p, cap)
		end
	end
	return math.floor(seconds * math.max(sum, minCrews * powerRef))
end

-- Share of the Spirit the current phase can't go below (phase 3: 0).
function VoidEmperor.Floor(phase: number, walls: { number }): number
	return walls[phase] or 0
end

export type TakenState = {
	Phase: number,
	PylonsUp: number, -- phase 1: pylons still standing
	Kneeling: boolean, -- phase 1: knelt after the pylons fell
	Crowned: boolean, -- phase 2: this copy wears the crown
	ShieldDown: boolean, -- phase 3: every active circle is held
	Mirrored: boolean, -- this player tapped a wrong copy recently
}

-- Multiplier on a crew's raw damage against the boss body / a copy.
function VoidEmperor.Taken(s: TakenState, shieldTaken: number, kneelTaken: number): number
	if s.Mirrored then
		return 0
	end
	if s.Phase == 1 then
		if s.PylonsUp > 0 then
			return shieldTaken
		end
		return if s.Kneeling then kneelTaken else 1
	elseif s.Phase == 2 then
		return if s.Crowned then 1 else 0
	elseif s.Phase == 3 then
		return if s.ShieldDown then 1 else 0
	end
	return 0
end

-- Damage that lands: raw * mult, never taking the boss below the phase floor.
function VoidEmperor.Apply(hp: number, max: number, raw: number, mult: number, floorShare: number): number
	if not (finite(hp) and finite(max) and finite(raw) and finite(mult) and finite(floorShare)) then
		return 0
	end
	if raw <= 0 or mult <= 0 or max <= 0 then
		return 0
	end
	local room = hp - max * floorShare
	if room <= 0 then
		return 0
	end
	return math.min(raw * mult, room)
end

-- Phase after this tick: the wall is reached (and in phase 1 every pylon is down).
function VoidEmperor.Advance(phase: number, hp: number, max: number, walls: { number }, pylonsUp: number): number
	local wall = walls[phase]
	if not wall then
		return phase
	end
	local reached = hp <= max * wall * (1 + 1e-9)
	if phase == 1 and reached and pylonsUp <= 0 then
		return 2
	elseif phase == 2 and reached then
		return 3
	end
	return phase
end

-- Light circles that must be held: min(maxCircles, players - 1), at least 1.
function VoidEmperor.ActiveCircles(players: number, maxCircles: number): number
	return math.clamp(math.floor(players) - 1, 1, math.max(1, maxCircles))
end

-- Shield is down only while circles 1..active all have someone in them.
function VoidEmperor.ShieldDown(held: { boolean }, active: number): boolean
	if active < 1 then
		return false
	end
	for i = 1, active do
		if held[i] ~= true then
			return false
		end
	end
	return true
end

-- The last stretch (all circles merge into one in the centre).
function VoidEmperor.Final(hp: number, max: number, share: number): boolean
	return max > 0 and hp <= max * share
end

-- Took part: dealt at least minContribution of the Spirit, or minSeconds of their own crew's power
-- (so a small crew next to a huge one still counts). No damage = never a participant.
function VoidEmperor.IsParticipant(dealt: number, max: number, power: number, minContribution: number, minSeconds: number): boolean
	if not finite(dealt) or dealt <= 0 then
		return false
	end
	if finite(max) and dealt >= max * minContribution then
		return true
	end
	return finite(power) and power > 0 and dealt >= power * minSeconds
end

-- Base Ectoplasm per participant (before each player's own multiplier), same order as weights:
-- base * zoneMult * clamp(share * participants, minShare, maxShare), * failShare on a timeout.
-- Weights <= 0 (or bad) get 0 and don't count as participants.
function VoidEmperor.Rewards(weights: { number }, base: number, zoneMult: number, minShare: number, maxShare: number, won: boolean, failShare: number): { number }
	local total, n = 0, 0
	for _, w in weights do
		if finite(w) and w > 0 then
			total += w
			n += 1
		end
	end
	local out = table.create(#weights, 0)
	if total <= 0 then
		return out
	end
	local k = if won then 1 else failShare
	for i, w in weights do
		if finite(w) and w > 0 then
			out[i] = math.floor(base * zoneMult * math.clamp(w / total * n, minShare, maxShare) * k)
		end
	end
	return out
end

-- Next crowned copy (never the current one): roll in [0, 1).
function VoidEmperor.NextCrown(current: number, count: number, roll: number): number
	if count <= 1 then
		return 1
	end
	local k = math.clamp(math.floor((if finite(roll) then roll else 0) * (count - 1)), 0, count - 2)
	local idx = k + 1
	if idx >= current then
		idx += 1
	end
	return idx
end

-- A fresh pick of a copy is a mistake (mirror) when it isn't crowned and lost the crown more
-- than `grace` seconds ago (picks right as the crown hops are forgiven).
function VoidEmperor.Mistake(crowned: boolean, uncrownedFor: number, grace: number): boolean
	return not crowned and uncrownedFor >= grace
end

export type OpenCheck = {
	Now: number,
	NextAt: number, -- scheduled opening (server time)
	HeraldKills: number,
	HeraldNeed: number,
	Waiting: number, -- players in the ring who can fight
	GatherNeed: number,
	LastEnd: number, -- when the last fight / window ended
	GatherCooldown: number,
}

-- Should the portal open now?
function VoidEmperor.ShouldOpen(c: OpenCheck): boolean
	if c.Now >= c.NextAt then
		return true
	end
	if c.Now - c.LastEnd < c.GatherCooldown then
		return false
	end
	return c.HeraldKills >= c.HeraldNeed or (c.GatherNeed > 0 and c.Waiting >= c.GatherNeed)
end

-- Angle (radians) of light circle `i` of `count` after `moves` moves: evenly spaced around the
-- centre, the whole set turning by half a gap each move so every circle lands somewhere new.
function VoidEmperor.CircleAngle(base: number, i: number, count: number, moves: number): number
	local gap = 2 * math.pi / math.max(1, count)
	return base + (i - 1) * gap + moves * gap / 2
end

return VoidEmperor
