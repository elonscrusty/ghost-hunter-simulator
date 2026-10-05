-- THE VOID EMPEROR rules (src/shared/Logic/VoidEmperor) + its Config block.
local VE = require("../src/shared/Logic/VoidEmperor")
local Config = require("./_Config")
local T = {}

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) <= math.max(1e-9, math.abs(b) * 1e-9)
end

T.spirit_has_a_floor_and_scales_with_crews = function()
	-- one small crew: the floor (4 reference crews) wins
	check(VE.Spirit({ 1e18 }, 150, 4, 1e20, 2e20) == 150 * 4e20, "floor")
	check(VE.Spirit({}, 150, 4, 1e20, 2e20) == 150 * 4e20, "empty server still has the floor")
	-- six reference crews: their own power sets it
	check(near(VE.Spirit({ 1e20, 1e20, 1e20, 1e20, 1e20, 1e20 }, 150, 4, 1e20, 2e20), 150 * 6e20), "big group")
	-- one whale is capped
	check(near(VE.Spirit({ 1e30, 1e20, 1e20, 1e20 }, 150, 4, 1e20, 2e20), 150 * 5e20), "cap")
	-- garbage powers count as 0
	check(VE.Spirit({ 0 / 0, -5, math.huge }, 150, 4, 1e20, 2e20) == 150 * 4e20, "bad powers")
end

T.taken_follows_the_phase_mechanics = function()
	local base = { Phase = 1, PylonsUp = 4, Kneeling = false, Crowned = false, ShieldDown = false, Mirrored = false }
	check(VE.Taken(base, 0.1, 2) == 0.1, "shielded by pylons")
	local s = table.clone(base)
	s.PylonsUp = 0
	check(VE.Taken(s, 0.1, 2) == 1, "pylons down")
	s.Kneeling = true
	check(VE.Taken(s, 0.1, 2) == 2, "kneeling")
	s.Mirrored = true
	check(VE.Taken(s, 0.1, 2) == 0, "mirrored players deal nothing")
	local p2 = table.clone(base)
	p2.Phase = 2
	check(VE.Taken(p2, 0.1, 2) == 0, "copy without the crown")
	p2.Crowned = true
	check(VE.Taken(p2, 0.1, 2) == 1, "crowned copy")
	local p3 = table.clone(base)
	p3.Phase = 3
	check(VE.Taken(p3, 0.1, 2) == 0, "void shield up")
	p3.ShieldDown = true
	check(VE.Taken(p3, 0.1, 2) == 1, "void shield down")
	p3.Phase = 9
	check(VE.Taken(p3, 0.1, 2) == 0, "no phase = no damage")
end

T.damage_stops_at_the_phase_wall = function()
	check(VE.Apply(1000, 1000, 50, 1, 0.66) == 50, "plain hit")
	check(VE.Apply(1000, 1000, 50, 0.1, 0.66) == 5, "shielded hit")
	check(VE.Apply(700, 1000, 500, 1, 0.66) == 40, "clamped to the wall")
	check(VE.Apply(660, 1000, 500, 1, 0.66) == 0, "at the wall: wasted")
	check(VE.Apply(10, 1000, 500, 1, 0) == 10, "last phase can finish him")
	check(VE.Apply(1000, 1000, 0 / 0, 1, 0) == 0 and VE.Apply(1000, 1000, -5, 1, 0) == 0, "bad damage")
	check(VE.Apply(1000, 1000, math.huge, 1, 0) == 0, "infinite damage ignored")
	check(VE.Apply(1000, 1000, 50, 0, 0) == 0, "blocked")
end

T.phases_advance_only_when_the_mechanic_is_done = function()
	local walls = { 0.66, 0.33 }
	check(VE.Advance(1, 660, 1000, walls, 1) == 1, "pylon still up")
	check(VE.Advance(1, 660, 1000, walls, 0) == 2, "pylons down + wall")
	check(VE.Advance(1, 700, 1000, walls, 0) == 1, "wall not reached")
	check(VE.Advance(2, 330, 1000, walls, 0) == 3, "second wall")
	check(VE.Advance(2, 400, 1000, walls, 0) == 2, "second wall not reached")
	check(VE.Advance(3, 0, 1000, walls, 0) == 3, "phase 3 is last")
	check(VE.Floor(1, walls) == 0.66 and VE.Floor(2, walls) == 0.33 and VE.Floor(3, walls) == 0, "floors")
	-- a full fight: damage can never skip a phase
	local hp, phase = 1000, 1
	for _ = 1, 100 do
		hp -= VE.Apply(hp, 1000, 400, 1, VE.Floor(phase, walls))
		phase = VE.Advance(phase, hp, 1000, walls, 0)
	end
	check(hp == 0 and phase == 3, "fight ends in phase 3")
end

T.light_circles = function()
	check(VE.ActiveCircles(1, 4) == 1, "solo: one circle")
	check(VE.ActiveCircles(2, 4) == 1, "duo: one circle")
	check(VE.ActiveCircles(3, 4) == 2, "three players")
	check(VE.ActiveCircles(12, 4) == 4, "max four")
	check(VE.ActiveCircles(0, 4) == 1, "never zero")
	check(VE.ShieldDown({ true, true, false, false }, 2), "two held of two")
	check(not VE.ShieldDown({ true, false, true, true }, 3), "one missing")
	check(not VE.ShieldDown({}, 1), "nobody")
	check(VE.Final(50, 1000, 0.05) and not VE.Final(51, 1000, 0.05), "final 5%")
end

T.participation_needs_real_damage = function()
	check(not VE.IsParticipant(0, 1000, 100, 0.01, 8), "no damage")
	check(VE.IsParticipant(10, 1000, 1e9, 0.01, 8), "1% of the boss")
	check(VE.IsParticipant(8, 1e9, 1, 0.01, 8), "8 s of a small crew")
	check(not VE.IsParticipant(7, 1e9, 1, 0.01, 8), "less than that")
	check(not VE.IsParticipant(0 / 0, 1000, 1, 0.01, 8), "NaN")
end

T.rewards_match_the_event_formula = function()
	-- two equal players: share * players = 1 each
	local r = VE.Rewards({ 50, 50 }, 900, 10, 0.35, 2.5, true, 0.25)
	check(r[1] == 9000 and r[2] == 9000, "equal split")
	-- carried player gets the floor, carrier is capped
	r = VE.Rewards({ 999, 1 }, 900, 10, 0.35, 2.5, true, 0.25)
	check(r[1] == math.floor(900 * 10 * 1.998) and r[2] == math.floor(900 * 10 * 0.35), "floor and share")
	r = VE.Rewards({ 100, 1, 1, 1, 1 }, 900, 10, 0.35, 2.5, true, 0.25)
	check(r[1] == 900 * 10 * 2.5, "max share cap")
	-- timeout: 25%
	r = VE.Rewards({ 50, 50 }, 900, 10, 0.35, 2.5, false, 0.25)
	check(r[1] == 2250, "fail share")
	-- no damage, no reward; never a negative or NaN amount
	r = VE.Rewards({ 0, 0 / 0, -3, 10 }, 900, 10, 0.35, 2.5, true, 0.25)
	check(r[1] == 0 and r[2] == 0 and r[3] == 0 and r[4] == 9000, "bad weights")
	check(#VE.Rewards({}, 900, 10, 0.35, 2.5, true, 0.25) == 0, "nobody")
end

T.crown_always_hops_to_another_copy = function()
	for cur = 1, 3 do
		for _, roll in { 0, 0.2, 0.49, 0.5, 0.99, 1, -1, 0 / 0 } do
			local n = VE.NextCrown(cur, 3, roll)
			check(n ~= cur and n >= 1 and n <= 3, "hop " .. cur .. " " .. tostring(roll))
		end
	end
	check(VE.NextCrown(1, 1, 0.5) == 1, "single copy")
	check(VE.Mistake(false, 5, 2.5) and not VE.Mistake(true, 5, 2.5) and not VE.Mistake(false, 1, 2.5), "mirror rule")
	check(not VE.Mistake(false, 5, 2.5, true), "the announced next crown is forgiven during the tell")
	check(VE.Mistake(false, 5, 2.5, false), "other uncrowned copies still mirror")
end

T.participation_uses_the_peak_crew_power = function()
	-- 1 s with a 1e9 crew, then swap to a weak hunter: still not 8 s of the peak
	local peak = VE.PeakPower(nil, 1e9)
	peak = VE.PeakPower(peak, 10)
	check(peak == 1e9, "peak kept")
	check(not VE.IsParticipant(1e9, 1e15, peak, 0.01, 8), "unequip trick fails")
	check(VE.IsParticipant(8e9, 1e15, peak, 0.01, 8), "8 s of the peak counts")
	check(VE.PeakPower(nil, 0 / 0) == 0 and VE.PeakPower(5, -1) == 5 and VE.PeakPower(0 / 0, 3) == 3, "garbage ignored")
end

T.only_active_challengers_count_for_circles = function()
	check(VE.IsActive(95, 100, 10), "hit 5 s ago")
	check(not VE.IsActive(85, 100, 10), "idle 15 s")
	check(not VE.IsActive(nil, 100, 10), "never hit")
	check(VE.ActiveCircles(0, 4) == 1, "all AFK: still one circle")
end

T.portal_opening = function()
	local c = { Now = 100, NextAt = 1300, HeraldKills = 0, HeraldNeed = 50, Waiting = 0, GatherNeed = 4, LastEnd = 0, GatherCooldown = 300 }
	check(not VE.ShouldOpen(c), "too early")
	c.Now = 1300
	check(VE.ShouldOpen(c), "timer")
	c.Now = 500
	c.HeraldKills = 50
	check(VE.ShouldOpen(c), "herald kills")
	c.HeraldKills = 0
	c.Waiting = 4
	check(VE.ShouldOpen(c), "players gathered")
	c.LastEnd = 400
	check(not VE.ShouldOpen(c), "cooldown after a fight")
end

T.circles_move_somewhere_new = function()
	local a0 = VE.CircleAngle(0, 1, 4, 0)
	local a1 = VE.CircleAngle(0, 1, 4, 1)
	check(math.abs(a1 - a0 - math.pi / 4) < 1e-9, "half a gap per move")
	check(math.abs(VE.CircleAngle(0, 3, 4, 0) - math.pi) < 1e-9, "evenly spaced")
end

T.config_is_sane = function()
	local C = Config.VoidEmperor
	check(Config.Ghosts[C.Ghost] ~= nil and Config.Ghosts[C.Pylon] ~= nil, "ghost entries")
	check(Config.Ghosts[C.Pylon].Reward == 0 and Config.Ghosts[C.Ghost].Reward == 0, "boss pieces pay only through the fight")
	check(Config.Crates[C.Crate] ~= nil and Config.Crates[C.Crate].Zone == C.Zone, "reward crate")
	check(Config.Daily.ZoneMultiplier[C.RewardZone] ~= nil, "zone multiplier")
	check(C.Walls[1] > C.Walls[2] and C.Walls[2] > C.FinalShare, "walls in order")
	check(C.PylonShare * 4 < 1 - C.Walls[1], "pylons smaller than the first phase")
	check(C.ShieldTaken < 1 and C.KneelTaken > 1, "shield / kneel")
	check(C.FailShare > 0 and C.FailShare < 1, "fail share")
	check(C.TimeLimit > C.CrownHopSeconds and C.PylonReturnSeconds > C.KneelSeconds, "timers")
	-- a solo reference crew can't do it on damage alone inside the limit (team fight by numbers)
	check(C.SpiritSeconds * C.MinCrews > C.TimeLimit, "solo can't brute force")
end

return T
