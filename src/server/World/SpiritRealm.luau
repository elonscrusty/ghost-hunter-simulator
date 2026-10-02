--!strict
-- ZONE 8: Spirit Realm (Z 2280..2680), the endgame: "you have entered another dimension".
--   Play area (|X| <= 140): a dark translucent "void glass" floor (top Y = 0, no holes) with
--   flat-topped floating islands of dark slate (tops Y 0.04..0.06) sunk into it; their glowing
--   lips and rocky undersides show through the glass, with stars and nebula far below.
--   Rune path along X = 0 (flat, top 0.08) from the gate to the portal platform at the back.
--   Ghost areas (0,2365) r30, (-82,2400) r24, (75,2470) r26, (-62,2530) r24 and the boss
--   SPIRIT OVERLORD at (0,2605) r28 hold only flat paint; nothing stands in or hangs above them.
--   Side walls: crystal-capped rock ridges at X +-140..146 (Z 2283..2677).
--   Back (Z 2645..2677): a huge swirling portal, decorative "next destination" glimpse.
--   Outside the walls: open void with floating islands, spirit trees, crystals, waterfalls
--   pouring into nothing, broken bridges, distant islands, cloud banks and a ringed planet.
--   Glow: island lips, path edge runes, wall crystal tips, a few crystals, tree spirit-orbs,
--   portal runes and stars. Rock, ruins, trunks and most crystals are solid/glass.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local SpiritRealm = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local ROCK = Enum.Material.Rock
local SLATE = Enum.Material.Slate
local GLASS = Enum.Material.Glass
local WOOD = Enum.Material.Wood

local Z0, Z1 = 2280, 2680
local W = 146 -- outer face of the side walls

local ROCKS = { C(44, 38, 70), C(36, 34, 60), C(52, 44, 82), C(32, 36, 58) }
local LIPS = { C(150, 100, 255), C(80, 210, 255), C(110, 240, 190), C(120, 140, 255) }
local CRYSTAL = { C(160, 110, 255), C(90, 200, 255), C(120, 235, 200), C(195, 140, 255) }
local LEAVES = { C(80, 210, 255), C(160, 105, 255), C(110, 240, 200), C(130, 150, 255) }
local RUIN = C(82, 76, 112)
local RUIN_DARK = C(56, 50, 84)
local BARK = C(34, 28, 46)
local BLACK = C(0, 0, 0)

local function clearOfGhosts(x: number, z: number, r: number): boolean
	for _, a in Config.Layout.GhostAreas do
		local dx, dz = x - a.Center.X, z - a.Center.Z
		local rr = a.Radius + r
		if dx * dx + dz * dz < rr * rr then
			return false
		end
	end
	return true
end

--==================================================================
-- PIECES
--==================================================================

-- Floating island: flat slate top at topY, a glowing lip just under the top edge and a
-- rocky underside tapering into the void.
local function island(f: Instance, x: number, z: number, topY: number, d: number, solid: boolean, lip: boolean): Part
	local rock = Kit.Pick(ROCKS)
	local top = Kit.Disc(f, x, z, topY, d, 3, rock, { Mat = SLATE, Solid = solid, Shadow = true })
	if lip then
		Kit.Disc(f, x, z, topY - 0.5, d + 1.6, 0.8, Kit.Pick(LIPS), { Mat = NEON })
	end
	local under = rock:Lerp(BLACK, 0.2)
	Kit.Disc(f, x, z, topY - 3, d * 0.84, 5, under, { Mat = ROCK })
	Kit.Disc(f, x + d * 0.04, z, topY - 8, d * 0.58, 7, under:Lerp(BLACK, 0.2), { Mat = ROCK })
	Kit.Disc(f, x - d * 0.03, z + d * 0.03, topY - 15, d * 0.3, 9, under:Lerp(BLACK, 0.35), { Mat = ROCK })
	Kit.Ball(f, d * 0.17, V(x, topY - 23, z), under:Lerp(BLACK, 0.45), { Mat = ROCK })
	return top
end

-- Crystal prism with a diamond tip, leaning by (tiltX, tiltZ). Neon only when asked;
-- otherwise translucent glass in a vivid colour.
local function shard(parent: Instance, base: Vector3, h: number, w: number, tiltX: number, tiltZ: number, color: Color3, neon: boolean): Part
	local cf = CFrame.new(base) * CFrame.Angles(tiltX, 0, tiltZ) * CFrame.Angles(0, Kit.Rng:NextNumber(0, math.pi), 0)
	local opts: Kit.Opts = if neon then { Mat = NEON } else { Mat = GLASS, Transp = 0.2, Refl = 0.2 }
	local col = if neon then color else Kit.Vivid(color)
	local body = Kit.Part(parent, V(w, h, w), cf * CFrame.new(0, h / 2, 0), col, opts)
	Kit.Part(parent, V(w * 0.72, w * 0.72, w * 0.72), cf * CFrame.new(0, h, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), col, opts)
	return body
end

-- Cluster of crystals on a dark rock base; returns the big central crystal.
local function crystalCluster(parent: Instance, pos: Vector3, scale: number, neonMain: boolean): Part
	local rng = Kit.Rng
	local col = Kit.Pick(CRYSTAL)
	Kit.Part(parent, V(5, 2.2, 4.4) * scale, CFrame.new(pos + V(0, 0.5 * scale, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.12), Kit.Pick(ROCKS), { Mat = ROCK, Solid = true, Shadow = true })
	local main = shard(parent, pos, 12 * scale, 2.6 * scale, rng:NextNumber(-0.1, 0.1), rng:NextNumber(-0.1, 0.1), col, neonMain)
	for k = 1, 3 do
		local a = k * 2.1 + rng:NextNumber(-0.3, 0.3)
		local t = rng:NextNumber(0.25, 0.45)
		local p = pos + V(math.cos(a), 0, math.sin(a)) * (1.7 * scale)
		shard(parent, p, rng:NextNumber(4.5, 8) * scale, rng:NextNumber(1.2, 1.8) * scale, math.sin(a) * t, -math.cos(a) * t, Kit.Pick(CRYSTAL), false)
	end
	return main
end

-- Enormous spirit tree: twisted dark trunk, roots, four branches with glowing leaf clusters
-- (solid translucent colour) and one small Neon spirit-orb. Returns the orb.
local function spiritTree(parent: Instance, pos: Vector3, height: number): Part
	local rng = Kit.Rng
	local pts = { pos }
	local seg = height / 4
	for i = 1, 4 do
		local sway = (if i % 2 == 0 then -1 else 1) * rng:NextNumber(1, 2.5)
		table.insert(pts, pts[i] + V(sway, seg, rng:NextNumber(-1.5, 1.5)))
	end
	for i = 1, 4 do
		local w = 4.6 - i * 0.85
		Props.Beam(parent, pts[i], pts[i + 1], w, w, BARK, { Mat = WOOD, Solid = i == 1, Shadow = true })
	end
	for r = 0, 2 do
		local a = r * 2.1 + rng:NextNumber(-0.3, 0.3)
		Props.Beam(parent, pos + V(0, 2.6, 0), pos + V(math.cos(a) * 5.5, -0.3, math.sin(a) * 5.5), 1.4, 1.4, BARK, { Mat = WOOD })
	end
	local s = height / 40
	local top = pts[5]
	local crown = Kit.Pick(LEAVES)
	Kit.Ball(parent, 12 * s, top + V(0, 1.5, 0), Kit.Vivid(crown), { Transp = 0.12, Shadow = true })
	for b = 1, 4 do
		local from = pts[3 + (b % 2)]
		local ang = b * 1.57 + rng:NextNumber(-0.4, 0.4)
		local len = height * rng:NextNumber(0.2, 0.28)
		local tip = from + V(math.cos(ang) * len, len * 0.5, math.sin(ang) * len)
		Props.Beam(parent, from, tip, 1.2, 1.2, BARK, { Mat = WOOD })
		Kit.Ball(parent, rng:NextNumber(7, 9.5) * s, tip, Kit.Vivid(Kit.Pick(LEAVES)), { Transp = 0.15 })
	end
	local orb = Kit.Ball(parent, 3.2 * s, top + V(0, -4.5 * s, 0), crown:Lerp(C(255, 255, 255), 0.3), { Mat = NEON })
	return orb
end

-- Falling water pouring off an edge into the void: a translucent sheet facing X plus a paler
-- core streak and a misty lip.
local function waterfall(parent: Instance, top: Vector3, width: number, len: number, mist: boolean)
	local cf = CFrame.new(top - V(0, len / 2, 0))
	Kit.Part(parent, V(1.2, len, width), cf, C(110, 180, 255), { Mat = GLASS, Transp = 0.45, Refl = 0.1, Name = "Waterfall" })
	Kit.Part(parent, V(1.6, len, width * 0.4), cf, C(205, 235, 255), { Transp = 0.6 })
	local lip = Kit.Part(parent, V(3, 0.8, width + 1), CFrame.new(top + V(0, 0.2, 0)), C(170, 220, 255), { Transp = 0.35 })
	if mist then
		Kit.Emitter(lip, C(190, 225, 255), 4, 7, 1.2)
	end
end

local function brokenColumn(parent: Instance, x: number, z: number)
	local rng = Kit.Rng
	Kit.Box(parent, V(x - 2.2, 0, z - 2.2), V(x + 2.2, 1.2, z + 2.2), RUIN_DARK, { Mat = SLATE, Solid = true })
	local h = rng:NextNumber(4, 17)
	Kit.Cyl(parent, h, 3, CFrame.new(x, 1.2 + h / 2, z), RUIN, { Mat = SLATE, Solid = true, Shadow = true })
	if h > 13 then
		Kit.Box(parent, V(x - 2.2, 1.2 + h, z - 2.2), V(x + 2.2, 2.6 + h, z + 2.2), RUIN_DARK, { Mat = SLATE })
	else
		Kit.Part(parent, V(2.4, 1.4, 2.4), CFrame.new(x, 1.6 + h, z) * CFrame.Angles(0.35, rng:NextNumber(0, 3), 0.25), RUIN, { Mat = SLATE })
		if rng:NextNumber() < 0.5 then
			Kit.CylFlat(parent, 4, 3, V(x + 2.2, 1.5, z + 2.4), "X", RUIN, { Mat = SLATE, Solid = true })
		end
	end
end

local function brokenArch(parent: Instance, x: number, z: number, yaw: number)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local o: Kit.Opts = { Mat = SLATE, Solid = true, Shadow = true }
	Kit.Part(parent, V(3, 18, 3), base * CFrame.new(-7, 9, 0), RUIN, o)
	Kit.Part(parent, V(3, 11, 3), base * CFrame.new(7, 5.5, 0), RUIN, o)
	Kit.Part(parent, V(3, 2, 3), base * CFrame.new(7, 11.6, 0) * CFrame.Angles(0, 0, 0.4), RUIN_DARK, { Mat = SLATE })
	Kit.Part(parent, V(10, 3, 3.2), base * CFrame.new(-3.2, 19.3, 0) * CFrame.Angles(0, 0, -0.08), RUIN_DARK, { Mat = SLATE, Shadow = true })
	Kit.Part(parent, V(6, 3, 3), base * CFrame.new(9.5, 1.3, 5) * CFrame.Angles(0.25, 0.6, 0.1), RUIN_DARK, o)
	-- faint rune carved on the standing pillar
	Kit.Part(parent, V(1.2, 1.2, 0.2), base * CFrame.new(-7, 12, -1.55) * CFrame.Angles(0, 0, math.pi / 4), Kit.Vivid(C(120, 220, 255)))
	Kit.AddCircle(x, z, 10)
end

local function temple(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "AncientTemple")
	Kit.Box(m, V(x - 13, 0, z - 11), V(x + 13, 0.9, z + 11), RUIN_DARK, { Mat = SLATE, Solid = true })
	Kit.Box(m, V(x - 10, 0.9, z - 8), V(x + 10, 1.8, z + 8), RUIN, { Mat = SLATE, Solid = true })
	local rng = Kit.Rng
	for _, cx in { -8, 8 } do
		for _, cz in { -6, 0, 6 } do
			local intact = cz >= 0
			local h = if intact then 14 else rng:NextNumber(4, 9)
			Kit.Cyl(m, h, 2.6, CFrame.new(x + cx, 1.8 + h / 2, z + cz), RUIN, { Mat = SLATE, Solid = true, Shadow = true })
		end
	end
	Kit.Box(m, V(x - 9.6, 15.8, z - 1.6), V(x + 9.6, 17.4, z + 7.6), RUIN_DARK, { Mat = SLATE, Shadow = true })
	Kit.Wedge(m, V(19.2, 4, 4.6), CFrame.new(x, 19.4, z + 5.3) * CFrame.Angles(0, math.pi, 0), RUIN_DARK, { Mat = SLATE })
	Kit.Part(m, V(9, 1.6, 4), CFrame.new(x + 3, 2.4, z - 9) * CFrame.Angles(0.15, 0.4, -0.2), RUIN_DARK, { Mat = SLATE, Solid = true })
	-- altar with a spirit flame
	Kit.Box(m, V(x - 1.6, 1.8, z - 4.6), V(x + 1.6, 4.4, z - 1.4), C(70, 62, 102), { Mat = SLATE, Solid = true })
	local flame = Kit.Ball(m, 1.8, V(x, 5.3, z - 3), C(140, 255, 210), { Mat = NEON })
	Kit.Light(flame, C(140, 255, 210), 26, 1.6, true)
	Kit.AddCircle(x, z, 15)
end

local function monolithRing(parent: Instance, mx: number, mz: number)
	local rng = Kit.Rng
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		local p = V(mx + math.cos(a) * 9, 0, mz + math.sin(a) * 9)
		local h = rng:NextNumber(7, 12)
		local cf = CFrame.new(p) * CFrame.Angles(0, Kit.FaceYaw(mx - p.X, mz - p.Z), 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
		Kit.Part(parent, V(2.8, h, 1.8), cf * CFrame.new(0, h / 2 - 0.3, 0), RUIN_DARK, { Mat = SLATE, Solid = true, Shadow = true })
	end
	Kit.Disc(parent, mx, mz, 0.1, 9, 0.06, Kit.Vivid(C(150, 100, 255)))
	Kit.Disc(parent, mx, mz, 0.13, 3.2, 0.06, C(150, 240, 255), { Mat = NEON })
	Kit.AddCircle(mx, mz, 12)
end

-- Flat ring of paint segments.
local function paintRing(parent: Instance, cx: number, cz: number, r: number, n: number, w: number, color: Color3, topY: number)
	local segLen = 2 * math.pi * r / n + 0.3
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = V(cx + math.cos(a) * r, topY - 0.03, cz + math.sin(a) * r)
		Kit.Part(parent, V(w, 0.06, segLen), CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a))), color)
	end
end

--==================================================================
-- SECTIONS
--==================================================================
local function ground(f: Instance)
	-- void glass: walkable everywhere in the play area, dark and see-through
	Kit.Box(f, V(-W, -1, Z0), V(W, 0, Z1), C(16, 12, 34), { Solid = true, Transp = 0.3, Refl = 0.15, Name = "VoidGlass" })
	-- islands sunk into the glass (tops alternate 0.04 / 0.06 so overlaps never flicker)
	local islands = {
		{ 0, 2320, 92, 0.04 }, { 6, 2382, 70, 0.06 }, { -82, 2400, 66, 0.06 }, { 92, 2352, 46, 0.04 },
		{ 75, 2470, 70, 0.04 }, { -20, 2462, 40, 0.06 }, { -62, 2530, 66, 0.04 }, { 60, 2562, 42, 0.04 },
		{ 0, 2605, 90, 0.06 }, { -106, 2612, 36, 0.04 }, { 102, 2640, 34, 0.04 }, { -108, 2322, 40, 0.06 },
		{ 0, 2658, 60, 0.04 },
	}
	for _, i in islands do
		island(f, i[1], i[2], i[4], i[3], true, true)
	end
	-- starfield and nebula far below the glass
	local rng = Kit.Rng
	for _ = 1, 12 do
		Kit.Ball(f, rng:NextNumber(0.6, 1.4), V(rng:NextNumber(-135, 135), rng:NextNumber(-110, -35), rng:NextNumber(Z0 + 10, Z1 - 10)), Kit.Pick({ C(220, 230, 255), C(180, 150, 255), C(150, 240, 255) }), { Mat = NEON })
	end
	local nebula = { V(-180, -200, 2400), V(200, -230, 2560), V(0, -260, 2480) }
	local nebulaCol = { C(90, 50, 160), C(40, 80, 160), C(40, 120, 130) }
	for k, n in nebula do
		Kit.Disc(f, n.X, n.Z, n.Y, 520, 2, nebulaCol[k], { Transp = 0.55 })
	end
end

local function runePath(f: Instance)
	local z2 = 2648
	Kit.Box(f, V(-5, 0.02, Z0 + 3), V(5, 0.08, z2), C(40, 36, 68), { Mat = SLATE, Solid = true, Name = "RunePath" })
	local edge = C(120, 210, 255)
	for z = Z0 + 10, z2 - 14, 28 do
		for _, s in { -1, 1 } do
			Kit.Box(f, V(s * 5, 0.02, z), V(s * 5.6, 0.1, z + 14), edge, { Mat = NEON })
		end
	end
	local glyph = C(190, 140, 255)
	for z = Z0 + 30, z2 - 10, 48 do
		Kit.Part(f, V(1.8, 0.04, 1.8), CFrame.new(0, 0.1, z) * CFrame.Angles(0, math.pi / 4, 0), glyph, { Mat = NEON })
	end
	-- painted (solid) dashes between the glyphs
	local dash = Kit.Vivid(C(130, 110, 220))
	for z = Z0 + 54, z2 - 10, 48 do
		Kit.Box(f, V(-0.3, 0.08, z - 4), V(0.3, 0.1, z + 4), dash)
	end
end

local function bossRing(f: Instance)
	local cx, cz = 0, 2605
	paintRing(f, cx, cz, 31, 28, 1.2, Kit.Vivid(C(150, 100, 255)), 0.12)
	paintRing(f, cx, cz, 20, 20, 0.8, Kit.Vivid(C(90, 200, 255)), 0.12)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Kit.Disc(f, cx + math.cos(a) * 33, cz + math.sin(a) * 33, 0.14, 2.4, 0.06, C(170, 240, 255), { Mat = NEON })
	end
end

local function portal(f: Instance)
	local m = Kit.Model(f, "SpiritPortal")
	local cy, pz, R = 38, 2666, 32
	Kit.Box(m, V(-40, 0, 2648), V(40, 0.8, 2677), C(48, 42, 78), { Mat = SLATE, Solid = true })
	Kit.Box(m, V(-36, 0.8, 2654), V(36, 1.4, 2676), C(60, 52, 92), { Mat = SLATE, Solid = true })
	-- stone ring
	local n = 28
	local segLen = 2 * math.pi * R / n + 0.6
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local pos = V(math.cos(a) * R, cy + math.sin(a) * R, pz)
		Kit.Part(m, V(segLen, 4.5, 4), CFrame.new(pos) * CFrame.Angles(0, 0, a + math.pi / 2), if i % 2 == 0 then C(52, 44, 84) else C(40, 36, 66), { Mat = SLATE, Shadow = true })
		if i % 4 == 1 then
			Kit.Part(m, V(1.4, 1.4, 0.3), CFrame.new(pos.X, pos.Y, pz - 2.1) * CFrame.Angles(0, 0, math.pi / 4), C(150, 240, 255), { Mat = NEON })
		end
	end
	-- swirl: dark backing, two shimmering ForceField layers, pale core and two spiral arms
	Kit.CylFlat(m, 1, 62, V(0, cy, pz + 0.6), "Z", C(10, 6, 22))
	Kit.CylFlat(m, 0.3, 58, V(0, cy, pz - 0.4), "Z", C(160, 90, 255), { Mat = Enum.Material.ForceField, Transp = 0.2 })
	Kit.CylFlat(m, 0.3, 42, V(0, cy, pz - 0.8), "Z", C(80, 220, 255), { Mat = Enum.Material.ForceField, Transp = 0.25 })
	local core = Kit.CylFlat(m, 0.3, 18, V(0, cy, pz - 1.2), "Z", C(225, 210, 255), { Transp = 0.35 })
	local arms = { Kit.Vivid(C(170, 110, 255)), Kit.Vivid(C(100, 220, 255)) }
	for arm = 0, 1 do
		for i = 0, 8 do
			local ang = arm * math.pi + i * 0.7
			local r = 3 + i * 3
			local p = V(math.cos(ang) * r, cy + math.sin(ang) * r, pz - 1.6)
			Kit.Part(m, V(r * 0.7 + 1, 0.9, 0.3), CFrame.new(p) * CFrame.Angles(0, 0, ang + math.pi / 2), arms[arm + 1], { Transp = 0.15 })
		end
	end
	Kit.Light(core, C(190, 150, 255), 60, 2)
	Kit.Emitter(core, C(200, 160, 255), 5, 5, 2.5)
	-- supports from the platform to the ring
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 16 - 2, 1.4, pz - 2), V(s * 16 + 2, 11, pz + 2), C(44, 38, 70), { Mat = ROCK, Solid = true, Shadow = true })
	end
	-- flanking obelisks with crystal tips
	for _, s in { -1, 1 } do
		local x = s * 43
		Kit.Box(m, V(x - 2.5, 0, 2657.5), V(x + 2.5, 2, 2662.5), RUIN_DARK, { Mat = SLATE, Solid = true })
		Kit.Box(m, V(x - 1.8, 2, 2658.2), V(x + 1.8, 28, 2661.8), C(48, 42, 78), { Mat = SLATE, Solid = true, Shadow = true })
		shard(m, V(x, 28, 2660), 6, 2.2, 0, 0, if s < 0 then C(170, 110, 255) else C(90, 220, 255), true)
	end
	-- two rocks drifting around the portal
	for _, s in { -1, 1 } do
		local rock = Kit.Part(m, V(6, 4.5, 5), CFrame.new(s * 52, 30 + s * 6, 2655) * CFrame.Angles(0.4, s * 0.7, 0.3), Kit.Pick(ROCKS), { Mat = ROCK, Name = "FloatingRock" })
		Kit.Float(rock, 1.6)
	end
	Kit.AddRect(-47, 2645, 47, 2678)
end

local function sideWalls(f: Instance)
	local rng = Kit.Rng
	local zA, zB = Z0 + 3, Z1 - 3
	local n = 10
	local len = (zB - zA) / n
	for _, s in { -1, 1 } do
		for i = 0, n - 1 do
			local z = zA + i * len
			local h = rng:NextNumber(8, 13)
			Kit.Box(f, V(s * 140, -26, z), V(s * W, h, z + len), Kit.Pick(ROCKS), { Mat = ROCK, Solid = true, Shadow = true })
			for k = 1, 2 do
				local cz = z + len * (k / 3) + rng:NextNumber(-3, 3)
				local lean = rng:NextNumber(0.1, 0.35)
				shard(f, V(s * 143, h - 0.5, cz), rng:NextNumber(5, 10), rng:NextNumber(1.6, 2.4), rng:NextNumber(-0.2, 0.2), -s * lean, Kit.Pick(CRYSTAL), k == 1 and i % 4 == 1)
			end
		end
	end
end

local function insideScenery(f: Instance)
	local rng = Kit.Rng
	temple(f, 105, 2545)
	if Kit.IsFree(-104, 2345, 12) then
		monolithRing(f, -104, 2345)
	end
	-- broken arches beside the path
	local arches = { { -45, 2330, 0.3 }, { 48, 2412, -0.4 }, { -28, 2495, 0.2 }, { 40, 2525, -0.2 }, { -100, 2478, 1.2 } }
	local placed = 0
	for _, a in arches do
		if placed < 3 and Kit.IsFree(a[1], a[2], 10) then
			placed += 1
			brokenArch(f, a[1], a[2], a[3])
		end
	end
	-- entry pylons flanking the path just past the gate
	for _, s in { -1, 1 } do
		if Kit.IsFree(s * 13, 2318, 3, true) then
			local c = crystalCluster(f, V(s * 13, 0, 2318), 0.9, s > 0)
			if s > 0 then
				Kit.Light(c, C(120, 230, 255), 30, 1.5)
			else
				Kit.Emitter(c, C(170, 140, 255), 2, 2.5, 0.8)
			end
			Kit.AddCircle(s * 13, 2318, 4)
		end
	end
	-- enormous spirit trees along the edges (crowns kept clear of the ghost areas)
	local trees = { { -120, 2296, 42 }, { 120, 2298, 38 }, { -122, 2445, 44 }, { 124, 2395, 40 }, { 122, 2600, 42 }, { -124, 2566, 38 }, { 118, 2510, 34 } }
	local lit = 0
	for _, t in trees do
		if Kit.IsFree(t[1], t[2], 5) and clearOfGhosts(t[1], t[2], 19) then
			local orb = spiritTree(f, V(t[1], 0, t[2]), t[3])
			lit += 1
			if lit <= 2 then
				Kit.Light(orb, orb.Color, 28, 1.3)
			end
			Kit.AddCircle(t[1], t[2], 6)
		end
	end
	-- giant spectral crystal clusters
	local clusters, lights = 0, 0
	for _ = 1, 300 do
		if clusters >= 9 then
			break
		end
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 30, Z1 - 45)
		if math.abs(x) > 14 and Kit.IsFree(x, z, 6) then
			clusters += 1
			local neon = clusters % 2 == 1
			local main = crystalCluster(f, V(x, 0, z), rng:NextNumber(0.9, 1.4), neon)
			if neon and lights < 3 then
				lights += 1
				Kit.Light(main, main.Color, 26, 1.4)
			end
			Kit.AddCircle(x, z, 6)
		end
	end
	-- broken colonnade lining the path
	for z = Z0 + 46, 2640, 30 do
		for _, s in { -1, 1 } do
			local x = s * rng:NextNumber(17, 24)
			if Kit.IsFree(x, z, 5) then
				brokenColumn(f, x, z)
				Kit.AddCircle(x, z, 4)
			end
		end
	end
	-- loose boulders
	local boulders = 0
	for _ = 1, 200 do
		if boulders >= 14 then
			break
		end
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(Z0 + 30, Z1 - 40)
		if Kit.IsFree(x, z, 3) then
			boulders += 1
			local sz = V(rng:NextNumber(2, 4.5), rng:NextNumber(1.5, 3), rng:NextNumber(2, 4.5))
			Kit.Part(f, sz, CFrame.new(x, sz.Y * 0.35, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), Kit.Pick(ROCKS), { Mat = ROCK, Solid = true, Shadow = true })
			Kit.AddCircle(x, z, 3)
		end
	end
	-- floating ruin pieces and crystals (never over a ghost area)
	local floats = 0
	for _ = 1, 300 do
		if floats >= 8 then
			break
		end
		local x, z = rng:NextNumber(-125, 125), rng:NextNumber(Z0 + 40, Z1 - 50)
		if math.abs(x) > 12 and Kit.IsFree(x, z, 6) then
			floats += 1
			local y = rng:NextNumber(9, 18)
			local cf = CFrame.new(x, y, z) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5))
			local p: Part
			if floats <= 2 then
				p = Kit.Part(f, V(1.8, 6, 1.8), cf, Kit.Vivid(Kit.Pick(CRYSTAL)), { Mat = GLASS, Transp = 0.15, Refl = 0.2, Name = "FloatingCrystal" })
			elseif floats % 2 == 0 then
				p = Kit.Part(f, V(3, 5, 3), cf, RUIN, { Mat = SLATE, Shape = Enum.PartType.Cylinder, Name = "FloatingColumn" })
			else
				p = Kit.Part(f, V(4, 2.4, 3), cf, RUIN_DARK, { Mat = SLATE, Name = "FloatingBlock" })
			end
			Kit.Float(p, rng:NextNumber(0.8, 1.6))
		end
	end
end

local function outsideScenery(f: Instance)
	local rng = Kit.Rng
	local o = Kit.Folder(f, "Void")
	-- floating islands just beyond the walls: { x, z, topY, d, content, waterfall? }
	type Outer = { x: number, z: number, y: number, d: number, kind: string, falls: boolean }
	local outer: { Outer } = {
		{ x = -186, z = 2322, y = 6, d = 44, kind = "tree", falls = true },
		{ x = -206, z = 2420, y = -2, d = 52, kind = "crystal", falls = false },
		{ x = -182, z = 2522, y = 10, d = 36, kind = "ruin", falls = true },
		{ x = -214, z = 2622, y = 2, d = 50, kind = "tree", falls = false },
		{ x = 190, z = 2342, y = 2, d = 50, kind = "crystal", falls = true },
		{ x = 182, z = 2450, y = 12, d = 34, kind = "tree", falls = false },
		{ x = 210, z = 2552, y = -4, d = 56, kind = "ruin", falls = true },
		{ x = 188, z = 2652, y = 8, d = 40, kind = "crystal", falls = false },
	}
	local mist = false
	local litOuter = false
	for _, i in outer do
		island(o, i.x, i.z, i.y, i.d, false, true)
		local top = V(i.x, i.y, i.z)
		if i.kind == "tree" then
			spiritTree(o, top, rng:NextNumber(30, 40))
		elseif i.kind == "crystal" then
			local c = crystalCluster(o, top, 1.8, not litOuter)
			if not litOuter then
				litOuter = true
				Kit.Light(c, c.Color, 40, 1.6)
			end
			crystalCluster(o, top + V(i.d * 0.25, 0, i.d * 0.2), 0.9, false)
		else
			for k = 0, 2 do
				local h = 8 + k * 4
				Kit.Cyl(o, h, 3.2, CFrame.new(i.x - 8 + k * 8, i.y + h / 2, i.z - 6 + k * 3), RUIN, { Mat = SLATE })
			end
			Kit.Part(o, V(14, 2.4, 3.4), CFrame.new(i.x, i.y + 17, i.z) * CFrame.Angles(0, 0.3, 0.2), RUIN_DARK, { Mat = SLATE })
		end
		if i.falls then
			local s = if i.x < 0 then -1 else 1
			-- pours off the island edge that faces the play area
			-- (offset in Z so it never lands on a bridge)
			waterfall(o, V(i.x - s * (i.d / 2 - 2), i.y, i.z + i.d * 0.22), rng:NextNumber(7, 10), 170, not mist)
			mist = true
		end
	end
	-- broken bridges from the walls to two islands
	local bridges = { { -1, 2322, 6, 186 - 22 }, { 1, 2450, 12, 182 - 17 } }
	for _, b in bridges do
		local s, z, y, reach = b[1], b[2], b[3], b[4]
		local slabs = math.floor((reach - W) / 4.5)
		for k = 0, slabs - 1 do
			if k ~= 2 then
				local x = s * (W + 2.25 + k * 4.5)
				local cf = CFrame.new(x, y - 0.6, z)
				if k == slabs - 1 then
					cf = CFrame.new(x, y - 4, z + 1) * CFrame.Angles(0.3, 0, s * 0.5)
				end
				Kit.Part(o, V(4.2, 1.2, 7), cf, RUIN, { Mat = SLATE })
				if k % 2 == 0 then
					Kit.Box(o, V(x - 0.4, y, z + 3), V(x + 0.4, y + 3.5, z + 3.8), RUIN_DARK, { Mat = SLATE })
				end
			end
		end
	end
	-- loose rocks hanging in the void
	for _ = 1, 12 do
		local s = if rng:NextNumber() < 0.5 then -1 else 1
		local sz = V(rng:NextNumber(4, 12), rng:NextNumber(3, 8), rng:NextNumber(4, 12))
		Kit.Part(o, sz, CFrame.new(s * rng:NextNumber(160, 290), rng:NextNumber(-30, 45), rng:NextNumber(Z0, Z1 + 40)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Kit.Pick(ROCKS), { Mat = ROCK })
	end
	-- distant islands (low detail silhouettes)
	local far = { { -340, 2330, 30, 120 }, { -410, 2520, 55, 150 }, { -330, 2690, 20, 100 }, { 350, 2300, 45, 130 }, { 420, 2480, 25, 150 }, { 340, 2660, 60, 110 } }
	for _, d in far do
		local x, z, y, dia = d[1], d[2], d[3], d[4]
		Kit.Disc(o, x, z, y, dia, 6, C(40, 34, 66), { Mat = ROCK })
		Kit.Disc(o, x, z, y - 6, dia * 0.7, 12, C(30, 26, 50), { Mat = ROCK })
		Kit.Disc(o, x, z, y - 18, dia * 0.36, 18, C(22, 20, 40), { Mat = ROCK })
		Props.Beam(o, V(x, y, z), V(x + 4, y + 30, z), 4, 4, BARK, { Mat = WOOD })
		Kit.Ball(o, 22, V(x + 4, y + 34, z), Kit.Vivid(Kit.Pick(LEAVES)), { Transp = 0.25 })
	end
	-- the next destination beyond the portal
	Kit.Disc(o, 0, 2880, 34, 150, 6, C(46, 38, 80), { Mat = ROCK })
	Kit.Disc(o, 0, 2880, 28, 100, 14, C(32, 28, 56), { Mat = ROCK })
	Kit.Disc(o, 0, 2880, 14, 50, 20, C(24, 20, 42), { Mat = ROCK })
	shard(o, V(0, 34, 2880), 46, 7, 0, 0, C(170, 230, 255), true)
	-- cloud banks and a ringed planet in a strange sky
	local clouds = {
		{ -260, 2300, 90, 160 }, { -420, 2460, 130, 220 }, { -300, 2640, 110, 180 }, { 280, 2340, 120, 200 },
		{ 440, 2560, 95, 230 }, { 260, 2700, 140, 170 }, { 0, 2820, 120, 260 }, { -150, 2800, 80, 150 },
		{ 160, 2790, 70, 150 }, { 0, 2250, 170, 200 },
	}
	for i, c in clouds do
		local col = if i % 2 == 0 then C(120, 90, 200) else C(80, 120, 210)
		Kit.Cyl(o, rng:NextNumber(6, 12), c[4], CFrame.new(c[1], c[3], c[2]) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)), col, { Transp = 0.75 })
	end
	local planet = V(-520, 230, 2760)
	Kit.Ball(o, 220, planet, C(110, 80, 180), { Transp = 0.15 })
	Kit.Cyl(o, 1, 400, CFrame.new(planet) * CFrame.Angles(0.35, 0, 0.25), C(170, 150, 230), { Transp = 0.65 })
	Kit.Ball(o, 60, V(480, 190, 2480), C(150, 220, 235), { Transp = 0.1 })
end

function SpiritRealm.Build(map: Instance)
	local f = Kit.Folder(map, "SpiritRealm")
	ground(f)
	runePath(f)
	bossRing(f)
	portal(f)
	sideWalls(f)
	insideScenery(f)
	outsideScenery(f)
end

return SpiritRealm
