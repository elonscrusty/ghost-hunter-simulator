--!strict
-- World 2 ghost looks for the seven areas added in the 16-area World 2: 19 Pumpkin Farm,
-- 21 Water Park, 23 Shopping Mall, 25 Dino Museum, 26 Stadium, 28 Giant's Kitchen, 29 Cyber Arcade.
--
-- Same contract as World2.luau: GhostRig.Build draws the standard body (diameter 3.5 at the
-- origin, face towards -Z, nub arms at x = +-1.7, tail curling down and back to (0.2, -2.7, 1.9))
-- and the face, then calls Styles[style](kit) to add the accessories. Every boss here is a big
-- themed object-ghost; glow stays modest (Neon only on eyes, screens' pixels, lamps and tiny bits).

local U = require(script.Parent.Parent.RigUtil)
local World2 = require(script.Parent.World2)

type Kit = World2.Kit

local H = World2.Help
local arc, blade, sparkle = H.arc, H.blade, H.sparkle

local World2b = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local WHITE = rgb(255, 255, 255)
local EYE = rgb(25, 15, 40)
local GOLD = rgb(255, 205, 60)
local SILVER = rgb(200, 205, 222)
local STEEL = rgb(95, 100, 120)
local PINKY = rgb(255, 150, 190)

local NEON = { Material = Enum.Material.Neon }
local METAL = { Material = Enum.Material.Metal }

-- frame at `p` whose +Y runs along `dir`
local function upAlong(p: Vector3, dir: Vector3): CFrame
	return CFrame.lookAt(p, p + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- flat block lying on the body surface in direction `d` (its -Z looks outward), spun by `spin`
local function onSurf(k: Kit, d: Vector3, out: number, spin: number?): CFrame
	local p = k.surf(d, out)
	return U.Facing(p, d) * CFrame.Angles(0, 0, spin or 0)
end

-- solid triangle a-b-c, `thick` studs thick (two wedges)
local function tri(k: Kit, a: Vector3, b: Vector3, c: Vector3, thick: number, col: Color3, opts: U.Opts?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local h = math.max(math.abs(ab:Dot(up)), 0.05)
	k.wedge(v(thick, h, math.max(math.abs(ab:Dot(back)), 0.05)), CFrame.fromMatrix((a + b) / 2, right, up, back), col, opts)
	k.wedge(v(thick, h, math.max(math.abs(ac:Dot(back)), 0.05)), CFrame.fromMatrix((a + c) / 2, -right, up, -back), col, opts)
end

-- chain of rods through `pts`
local function chain(k: Kit, pts: { Vector3 }, d: number, c: Color3, c2: Color3?, opts: U.Opts?)
	for i = 1, #pts - 1 do
		k.rod(pts[i], pts[i + 1], d, if c2 and i % 2 == 0 then c2 else c, opts)
	end
end

-- sunglasses pushed up on the forehead
local function sunnies(k: Kit, frameC: Color3, lensC: Color3)
	local lens = {}
	for _, s in { -1, 1 } do
		local d = v(0.52 * s, 1.3, -1.0)
		local p = k.surf(d, 0.06)
		k.cyl(0.08, 0.86, U.DiscFacing(p, d), frameC)
		k.cyl(0.1, 0.7, U.DiscFacing(k.surf(d, 0.1), d), lensC)
		k.block(v(0.22, 0.08, 0.04), U.Facing(k.surf(d, 0.16), d) * at(-0.12, 0.14, 0) * CFrame.Angles(0, 0, 0.5), WHITE)
		lens[s] = p
		k.rod(k.surf(v(0.95 * s, 1.15, -0.75), 0.08), k.surf(v(1.05 * s, 0.95, 0.55), 0.04), 0.09, frameC)
	end
	k.rod(lens[-1] + v(0.35, 0, 0), lens[1] - v(0.35, 0, 0), 0.1, frameC)
end

-- 7-segment digit (0, 1, 2, 7, 8) in frame `cf` (face looks along its -Z, so its -X is the
-- viewer's right)
local SEGS: { [number]: string } = { [0] = "abcdef", [1] = "bc", [2] = "abged", [7] = "abc", [8] = "abcdefg" }
local function digit(k: Kit, cf: CFrame, n: number, h: number, c: Color3, opts: U.Opts?)
	local w, t = h * 0.55, h * 0.13
	local pos: { [string]: { number } } = {
		a = { 0, h / 2, 1 }, d = { 0, -h / 2, 1 }, g = { 0, 0, 1 },
		b = { w / 2, h / 4, 0 }, c = { w / 2, -h / 4, 0 }, e = { -w / 2, -h / 4, 0 }, f = { -w / 2, h / 4, 0 },
	}
	for i = 1, #SEGS[n] do
		local p = pos[string.sub(SEGS[n], i, i)]
		local size = if p[3] == 1 then v(w - t * 0.6, t, 0.05) else v(t, h / 2 - t * 0.6, 0.05)
		k.block(size, cf * at(-p[1], p[2], 0), c, opts)
	end
end

-- 8-bit heart (rows 2-5-3-1 of pixel `s`) in frame `cf`
local function pixelHeart(k: Kit, cf: CFrame, s: number, c: Color3)
	for _, x in { -1, 1 } do
		k.block(v(s * 2, s, s), cf * at(x * s * 1.5, s * 1.5, 0), c)
	end
	k.block(v(s * 5, s, s), cf * at(0, s * 0.5, 0), c)
	k.block(v(s * 3, s, s), cf * at(0, -s * 0.5, 0), c)
	k.block(v(s, s, s), cf * at(0, -s * 1.5, 0), c)
	k.block(v(s * 0.6, s * 0.6, s * 0.2), cf * at(s * 1.6, s * 1.6, -s * 0.5), WHITE) -- shine
end

-- straw tuft: `n` thin straws fanning out of `p` round the direction `dir`
local function tuft(k: Kit, p: Vector3, dir: Vector3, n: number, len: number, c1: Color3, c2: Color3, seed: number)
	local d = dir.Unit
	local side = d:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = d:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local up = side:Cross(d).Unit
	for i = 1, n do
		local t = (i - (n + 1) / 2) / math.max(n - 1, 1)
		local w = math.sin(seed + i * 2.3) * 0.25
		local dd = (d + side * t * 0.9 + up * w).Unit
		local l = len * (0.8 + 0.25 * math.sin(seed * 3 + i))
		k.block(v(0.12, 0.12, l), CFrame.lookAt(p + dd * l / 2, p + dd * l), if i % 2 == 0 then c2 else c1)
	end
end

local S: { [string]: (Kit) -> () } = {}

------------------------------------------------------------------ 19 Pumpkin Farm
S.CornCob = function(k)
	-- a corn cob worn as a tall hat (kernel bumps, green husks peeling down), popcorn drifting round
	local corn, kern = rgb(255, 205, 60), rgb(255, 225, 100)
	local husk, huskD = rgb(120, 195, 75), rgb(85, 150, 55)
	local base = v(0.05, 1.3, 0.1)
	k.cyl(2.1, 1.25, CFrame.new(base + v(0, 1.05, 0)) * U.AxisY, corn)
	k.ball(1.2, CFrame.new(base + v(0, 2.1, 0)), corn)
	for row = 0, 3 do
		for i = 0, 3 do
			local a = (i + (row % 2) * 0.5) * 2 * math.pi / 4 + 0.4
			k.ball(0.42, CFrame.new(base + v(math.sin(a) * 0.55, 0.55 + row * 0.47, -math.cos(a) * 0.55)), kern)
		end
	end
	-- husks peeling down over the head
	for i, a in { -0.9, 0.9, 2.3, -2.3 } do
		local out = v(math.sin(a), 0, -math.cos(a))
		local p = base + v(0, 0.55, 0) + out * 0.5
		blade(k, p, out - v(0, 0.55, 0), out + v(0, 1.2, 0), 0.62, 1.35, 0.1, if i % 2 == 0 then huskD else husk)
	end
	-- popcorn puffs
	local pop, butter = rgb(255, 250, 235), rgb(255, 225, 120)
	for i, p in { v(2.45, 0.95, -0.6), v(-2.5, 0.25, -0.4), v(2.1, -1.35, 0.1), v(-1.9, -1.6, 0.6) } do
		local r = 0.32 + (i % 2) * 0.06
		k.ball(r * 1.5, CFrame.new(p), pop)
		k.ball(r * 1.2, CFrame.new(p + v(0.25, 0.18, -0.08)), pop)
		if i % 2 == 0 then
			k.ball(r * 1.1, CFrame.new(p + v(-0.2, 0.2, 0.1)), butter)
		end
	end
end

S.HayBale = function(k)
	-- wearing a hay bale like a barrel (two twine bands, straw sticking out), red bandana, chewing a straw
	local hay, hayD = rgb(232, 196, 100), rgb(200, 160, 70)
	local twine = rgb(140, 85, 45)
	local red = rgb(215, 45, 50)
	k.block(v(3.9, 2.0, 3.5), at(0, -2.05, 0.35), hay)
	for _, y in { -1.45, -2.2 } do
		k.block(v(3.92, 0.06, 3.52), at(0, y, 0.35), hayD) -- straw grain lines
	end
	for _, x in { -0.95, 0.95 } do
		k.block(v(0.2, 2.06, 3.56), at(x, -2.05, 0.35), twine)
	end
	-- straw poking out of the edges
	for i, t in { { v(1.95, -1.1, -1.4), v(1, 0.5, -0.6) }, { v(-1.95, -1.15, -1.4), v(-1, 0.4, -0.7) }, { v(-1.95, -3.0, -1.3), v(-1, -0.6, -0.5) },
		{ v(1.95, -2.9, 0.4), v(1, -0.3, 0.2) }, { v(0.4, -3.05, -1.4), v(0.2, -1, -0.6) }, { v(-1.2, -1.05, 2.1), v(-0.4, 0.6, 1) } } do
		tuft(k, t[1], t[2], 3, 0.75, hay, hayD, i)
	end
	-- bandana round the neck with a knot and a dangling corner
	k.ring(-1.0, 0.32, red)
	local kp = k.surf(v(0.55, -1.0, -1.45), 0.05)
	k.ball(0.38, CFrame.new(kp), red)
	blade(k, kp + v(0.08, -0.08, -0.05), v(0.3, -1, -0.3), v(0, 0, -1), 0.5, 0.55, 0.08, red)
	for _, d in { v(-0.8, -1.0, -1.4), v(-0.2, -1.0, -1.6), v(1.3, -1.0, -1.0) } do
		k.ball(0.13, CFrame.new(k.surf(d, 0.1)), WHITE)
	end
	-- a straw to chew on
	local m = k.surf(v(0.25, -0.5, -1.65), 0.0)
	k.block(v(0.09, 0.09, 1.1), CFrame.lookAt(m + v(0.45, 0.12, -0.15), m + v(0.95, 0.3, -0.35)), hay)
end

S.Scarecrow = function(k)
	-- a scarecrow ghost: burlap sack head with glowing eyes and a stitched smile, floppy straw hat with
	-- a crooked little crown, plaid sleeves on a wooden crossbeam stuffed with straw, three crows on
	-- the beam and a jack-o'-lantern hanging from one end
	local straw, strawD = rgb(238, 205, 100), rgb(200, 160, 70)
	local wood, woodD = rgb(135, 90, 55), rgb(100, 65, 40)
	local stitch = rgb(70, 45, 30)
	local plaid, plaidD = rgb(195, 55, 45), rgb(120, 30, 30)
	local crow = rgb(32, 30, 40)
	local beak = rgb(255, 160, 50)
	-- crossbeam and post
	k.block(v(8.6, 0.5, 0.5), at(0, -0.3, 0.75), wood)
	k.block(v(0.5, 4.8, 0.5), at(0, -3.2, 0.75), wood)
	k.block(v(0.55, 0.12, 0.55), at(0, -5.0, 0.75), woodD)
	for _, s in { -1, 1 } do
		-- plaid sleeves over the nubs, straw spilling from the cuffs
		k.cyl(1.25, 1.15, at(1.75 * s, -0.35, -0.15), plaid)
		for _, x in { 1.45, 2.05 } do
			k.cyl(0.12, 1.18, at(x * s, -0.35, -0.15), plaidD)
		end
		k.block(v(0.1, 1.17, 1.17), at(1.75 * s, -0.35, -0.15) * CFrame.Angles(math.pi / 4, 0, 0), plaidD)
		tuft(k, v(2.35 * s, -0.35, -0.15), v(s, 0, -0.15), 5, 0.9, straw, strawD, s + 2)
		k.brow(s, 0.98, true, stitch, 0.62)
	end
	-- rope tied round the sack's neck, straw poking out below it
	k.ring(-1.0, 0.24, rgb(175, 135, 80))
	tuft(k, v(-0.7, -1.25, -1.2), v(-0.3, -1, -0.6), 4, 0.7, straw, strawD, 4)
	tuft(k, v(0.8, -1.25, -1.15), v(0.4, -1, -0.5), 3, 0.65, straw, strawD, 7)
	-- stitched smile
	local pts = {}
	for i = 0, 6 do
		local x = -0.95 + i * 0.95 / 3
		local y = -0.32 - 0.32 * (1 - (x / 0.95) ^ 2)
		table.insert(pts, k.surf(v(x, y, -1.5), 0.02))
	end
	for i = 1, 6 do
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		k.block(v(0.1, 0.07, (b - a).Magnitude + 0.04), CFrame.lookAt(mid, b, mid.Unit), stitch)
	end
	for i = 2, 6 do
		k.block(v(0.07, 0.34, 0.06), U.Facing(pts[i], pts[i]), stitch)
	end
	-- burlap patches with big cross-stitches
	for i, pt in { { d = v(-1.0, -0.55, -0.6), c = rgb(90, 125, 175) }, { d = v(1.0, 0.25, 0.35), c = rgb(150, 110, 70) } } do
		local f = onSurf(k, pt.d, 0.0, 0.25 * i)
		k.block(v(0.95, 0.8, 0.12), f, pt.c)
		for _, c in { v(-0.42, 0.35, 0), v(0.42, -0.35, 0) } do
			for _, r in { 0.785, -0.785 } do
				k.block(v(0.3, 0.06, 0.05), f * at(c.X, c.Y, -0.07) * CFrame.Angles(0, 0, r), stitch)
			end
		end
	end
	-- floppy straw hat, tipped back and to one side, with a crooked gold crown on top
	local hat = at(0.05, 1.55, 0.3) * CFrame.Angles(-0.26, 0, 0.12)
	k.cyl(0.18, 4.7, hat * U.AxisY, straw)
	k.block(v(1.4, 0.16, 2.6), hat * at(-2.25, -0.3, 0.2) * CFrame.Angles(0, 0, 0.45), straw)
	k.cyl(1.45, 2.45, hat * at(0, 0.75, 0) * U.AxisY, straw)
	k.cyl(0.12, 2.0, hat * at(0, 1.5, 0) * U.AxisY, strawD)
	k.cyl(0.42, 2.52, hat * at(0, 0.3, 0) * U.AxisY, plaid)
	local hp = hat * at(-0.55, 0.9, -1.2)
	k.block(v(0.6, 0.55, 0.08), hp, rgb(90, 160, 90))
	for _, r in { 0.785, -0.785 } do
		k.block(v(0.32, 0.06, 0.05), CFrame.new(hp.Position + v(0, 0, -0.06)) * CFrame.Angles(0, 0, r), stitch)
	end
	local crown = hat * at(0.15, 1.75, 0.1) * CFrame.Angles(0, 0, -0.25)
	k.cyl(0.38, 1.45, crown * U.AxisY, GOLD, METAL)
	for i = 0, 4 do
		local a = i * 2 * math.pi / 5 + 0.3
		local dir = crown:VectorToWorldSpace(v(math.sin(a) * 0.25, 1, -math.cos(a) * 0.25))
		k.point((crown * v(math.sin(a) * 0.6, 0.15, -math.cos(a) * 0.6)), dir, 0.36, 0.55, 0.16, GOLD, METAL)
	end
	k.ball(0.22, crown * at(0, 0, -0.74), rgb(255, 120, 40), NEON)
	tuft(k, v(-1.55, 0.95, 0.75), v(-1, -0.3, 0.4), 3, 0.7, straw, strawD, 9)
	tuft(k, v(1.6, 0.9, 0.6), v(1, -0.35, 0.4), 3, 0.7, straw, strawD, 11)
	tuft(k, v(0.1, 0.9, 1.6), v(0.1, -0.4, 1), 4, 0.75, straw, strawD, 13)
	-- three crows on the beam
	for i, c in { { x = -3.55, turn = 0.4, s = 1 }, { x = 3.05, turn = -0.2, s = 0.9 }, { x = 3.85, turn = -0.6, s = 0.75 } } do
		local f = at(c.x, -0.05, 0.75) * CFrame.Angles(0, c.turn, 0)
		local s = c.s
		k.ball(0.8 * s, f * at(0, 0.35 * s, 0.05), crow)
		k.ball(0.55 * s, f * at(0, 0.82 * s, -0.25 * s), crow)
		k.point(f * v(0, 0.8 * s, -0.5 * s), f:VectorToWorldSpace(v(0, -0.2, -1)), 0.22 * s, 0.4 * s, 0.18 * s, beak)
		k.point(f * v(0, 0.4 * s, 0.35 * s), f:VectorToWorldSpace(v(0, 0.35, 1)), 0.4 * s, 0.55 * s, 0.1 * s, crow)
		for _, e in { -1, 1 } do
			k.ball(0.15 * s, f * at(0.15 * e * s, 0.9 * s, -0.47 * s), WHITE)
		end
		if i == 1 then
			k.point(f * v(0, 1.05 * s, -0.25 * s), v(0.2, 1, 0.3), 0.18, 0.25, 0.06, crow) -- head tuft
		end
	end
	-- jack-o'-lantern hanging under the left end of the beam
	local jp = v(-3.0, -2.0, 0.75)
	k.rod(v(-3.0, -0.55, 0.75), jp + v(0, 0.6, 0), 0.07, stitch)
	local orange = rgb(240, 130, 40)
	k.ball(1.15, CFrame.new(jp), orange)
	for _, x in { -0.3, 0.3 } do
		k.ball(0.85, CFrame.new(jp + v(x, 0, 0.05)), U.Shade(orange, 0.9))
	end
	k.cyl(0.3, 0.18, CFrame.new(jp + v(0, 0.6, 0)) * U.AxisY, rgb(90, 140, 60))
	for _, s in { -1, 1 } do
		k.wedge(v(0.06, 0.2, 0.2), CFrame.new(jp + v(0.2 * s, 0.13, -0.56)) * CFrame.Angles(-math.pi / 4, 0, 0) * U.AxisZ * CFrame.Angles(0, -math.pi / 2, 0), rgb(255, 200, 80), NEON)
	end
	k.block(v(0.42, 0.1, 0.06), CFrame.new(jp + v(0, -0.18, -0.57)), rgb(255, 200, 80), NEON)
end

------------------------------------------------------------------ 21 Water Park
S.SwimRing = function(k)
	-- red-and-white striped swim ring round its middle, snorkel mask over its eyes, water drops
	local red = rgb(230, 55, 60)
	local n = 12
	local c = v(0, -1.3, 0.25)
	for i = 0, n - 1 do
		local a = (i + 0.5) * 2 * math.pi / n
		k.ball(1.05, CFrame.new(c + v(math.sin(a) * 1.75, 0, -math.cos(a) * 1.75)), if i % 2 == 0 then red else WHITE)
	end
	-- snorkel mask: frame round both eyes, rubber skirt, strap round the back
	local maskC, rubber = rgb(255, 210, 50), rgb(50, 60, 80)
	k.block(v(2.75, 0.24, 0.5), at(0, 0.98, -1.55) * CFrame.Angles(0.35, 0, 0), maskC)
	k.block(v(2.6, 0.24, 0.4), at(0, -0.22, -1.82), maskC)
	for _, s in { -1, 1 } do
		k.block(v(0.24, 1.35, 0.8), at(1.3 * s, 0.38, -1.45) * CFrame.Angles(0, 0.45 * s, 0), maskC)
		k.block(v(0.42, 0.06, 0.04), at(0.95 * s, 0.75, -1.95) * CFrame.Angles(0, 0, 0.6), WHITE) -- glass glint
	end
	k.wedge(v(0.5, 0.45, 0.3), at(0, 0.0, -1.98) * CFrame.Angles(0, math.pi, 0), maskC) -- nose pocket
	arc(k, at(0, 0.45, 0.05) * CFrame.Angles(math.pi / 2, 0, 0), 1.78, math.rad(-15), math.rad(195), 7, 0.18, rubber)
	-- snorkel: mouthpiece, tube up the side of the head, orange tip
	local snork = rgb(70, 200, 255)
	local mp = v(0, -0.5, -1.75)
	k.block(v(0.55, 0.32, 0.3), CFrame.new(mp), rubber)
	chain(k, { mp + v(-0.2, 0, -0.05), v(-0.9, -0.55, -1.6), v(-1.75, 0.0, -0.95), v(-1.85, 1.2, -0.75), v(-1.6, 2.3, -0.6) }, 0.28, snork)
	k.cyl(0.4, 0.34, upAlong(v(-1.55, 2.45, -0.58), v(0.25, 1, 0.1)) * U.AxisY, rgb(255, 120, 40))
	-- trail of water drops behind
	local water = rgb(110, 205, 255)
	for i, p in { v(0.6, -3.2, 2.5), v(1.0, -3.6, 3.2), v(1.3, -3.9, 3.8) } do
		local d = 0.5 - i * 0.1
		k.ball(d, CFrame.new(p), water)
		k.point(p + v(0, d * 0.3, 0), v(-0.1, 1, -0.3), d * 0.7, d * 0.7, d * 0.7, water)
	end
end

S.Floatie = function(k)
	-- lounging on a pink donut float with sprinkles, sunglasses up on its head, a drink umbrella in the float
	local pink = rgb(255, 140, 195)
	local n = 12
	local c = v(0, -1.55, 0.35)
	for i = 0, n - 1 do
		local a = (i + 0.5) * 2 * math.pi / n
		k.ball(1.3, CFrame.new(c + v(math.sin(a) * 1.85, 0, -math.cos(a) * 1.85)), if i % 3 == 0 then U.Shade(pink, 0.93) else pink)
	end
	local sprinkles = { rgb(255, 255, 255), rgb(90, 200, 255), rgb(255, 220, 70), rgb(120, 230, 140) }
	for i = 0, 9 do
		local a = i * 2 * math.pi / 10 + 0.2
		local p = c + v(math.sin(a) * 1.85, 0.6, -math.cos(a) * 1.85)
		k.block(v(0.32, 0.08, 0.08), CFrame.new(p) * CFrame.Angles(0, a * 3, 0), sprinkles[i % 4 + 1])
	end
	-- relaxed half-closed eyelids
	local lid = U.Shade(k.color, 0.93)
	for _, s in { -1, 1 } do
		k.ball(0.94, CFrame.new(v(0.6 * s, 0.5, -1.39)), lid)
	end
	sunnies(k, rgb(255, 120, 60), rgb(35, 35, 55))
	-- drink umbrella stuck in the float
	local base = c + v(1.4, 0.55, -1.2)
	local top = base + v(0.4, 1.9, -0.15)
	k.rod(base, top, 0.08, rgb(240, 225, 190))
	local cf = upAlong(top, v(0.2, 1, 0))
	k.cone(cf * at(0, -0.1, 0), 1.5, 0.55, 3, rgb(80, 220, 200), rgb(255, 250, 240))
	k.ball(0.14, cf * at(0, 0.5, 0), rgb(255, 90, 120))
	-- nub resting behind its head
	k.ball(0.8, at(-1.25, 1.05, 0.65), k.color)
end

S.WaveCrown = function(k)
	-- King Cannonball rides a huge curling wave (seen side-on it is a big "C" rising behind him and
	-- breaking over his head): inflatable gold crown, lifeguard whistle, a water-slide tube looped
	-- round his tail and a splash under him
	local deep, light = rgb(35, 110, 205), rgb(120, 210, 250)
	local foam = rgb(245, 250, 255)
	local c = v(-0.2, 1.0, 1.7)
	local n = 12
	local pts = {}
	for i = 0, n do
		local t = i / n
		local th = math.rad(-60 + 265 * t)
		local r = 3.7 - 1.8 * t
		table.insert(pts, c + v(r * math.cos(th), r * math.sin(th), 0))
	end
	for i = 1, n do
		local t = (i - 0.5) / n
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		local f = CFrame.lookAt(mid, b, (mid - c).Unit)
		local thick = 1.6 - 1.1 * t
		k.block(v(2.8 - 1.1 * t, thick, (b - a).Magnitude + 0.3), f, U.Mix(deep, light, t))
		if i >= 4 then -- foam along the crest (front and back edges)
			for _, z in { -1, 1 } do
				k.ball(0.62 - 0.2 * t, f * at(z * (1.25 - 0.5 * t), thick / 2, 0), foam)
			end
		end
	end
	-- foamy lip where it breaks, spray drops
	local tip = pts[n + 1]
	for j = 0, 2 do
		k.ball(0.75 - j * 0.15, CFrame.new(tip + v(0.15 * j, -0.35 * j, -0.5 + j * 0.45)), foam)
	end
	for _, d in { v(0.5, -0.6, -1.0), v(-0.3, -0.9, -0.7), v(0.9, -1.2, -0.5) } do
		k.ball(0.3, CFrame.new(tip + d), light)
	end
	-- inflatable gold crown (puffy band and five puffy points), red valve gem
	local gold, goldL = rgb(255, 200, 50), rgb(255, 232, 130)
	k.cyl(0.65, 2.35, at(0, 1.6, 0.05) * U.AxisY, gold)
	k.cyl(0.14, 2.42, at(0, 1.62, 0.05) * U.AxisY, goldL)
	for i = 0, 4 do
		local a = i * 2 * math.pi / 5
		local o = v(math.sin(a), 0, -math.cos(a))
		k.ball(0.72, CFrame.new(v(0, 2.05, 0.05) + o * 0.9), gold)
		k.ball(0.52, CFrame.new(v(0, 2.45, 0.05) + o * 1.0), gold)
		k.ball(0.34, CFrame.new(v(0, 2.75, 0.05) + o * 1.08), goldL)
	end
	k.ball(0.38, at(0, 1.62, -1.18), rgb(230, 50, 60))
	-- lifeguard whistle on a red cord
	local cord = rgb(220, 45, 55)
	local w = v(0, -1.55, -1.4)
	for _, s in { -1, 1 } do
		k.rod(v(1.15 * s, -1.0, -0.9), w + v(0.12 * s, 0.12, 0), 0.08, cord)
	end
	k.cyl(0.5, 0.36, CFrame.new(w + v(0, -0.12, -0.08)), rgb(255, 160, 40))
	k.block(v(0.22, 0.2, 0.3), CFrame.new(w + v(-0.3, -0.06, -0.12)), rgb(255, 160, 40))
	-- water-slide tube looped round the tail
	local tf = at(0.1, -1.95, 1.15) * CFrame.Angles(math.rad(-50), 0, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	arc(k, tf, 1.45, 0, 2 * math.pi, 10, 0.48, rgb(255, 125, 55))
	arc(k, tf * at(0, 0, 0.6), 1.05, 0, 2 * math.pi, 8, 0.42, rgb(255, 205, 60))
	-- pool of water he floats on, foam round its rim
	k.cyl(0.4, 6.4, at(0.3, -3.4, 1.4) * U.AxisY, deep)
	k.cyl(0.42, 4.6, at(0.3, -3.39, 1.4) * U.AxisY, U.Mix(deep, light, 0.5))
	-- splash under him
	for i, p in { v(0.2, -3.9, 1.6), v(-0.8, -3.7, 1.9), v(1.2, -3.8, 2.2), v(0.3, -4.2, 2.6) } do
		k.ball(0.7 - i * 0.08, CFrame.new(p), if i % 2 == 0 then foam else light)
	end
	for _, s in { -1, 1 } do
		k.brow(s, 1.0, false, U.Shade(k.color, 0.5), 0.6)
	end
end

------------------------------------------------------------------ 23 Shopping Mall
S.ShoppingBags = function(k)
	-- a paper shopping bag on each nub, sunglasses on its head, a long receipt curling off its tail
	for _, b in { { s = 1, c = rgb(255, 120, 190) }, { s = -1, c = rgb(110, 205, 255) } } do
		local s = b.s
		local p = v(2.1 * s, -1.75, -0.35)
		k.block(v(1.0, 1.1, 0.6), CFrame.new(p) * CFrame.Angles(0, 0.15 * s, 0), b.c)
		k.block(v(1.02, 0.16, 0.62), CFrame.new(p + v(0, 0.5, 0)) * CFrame.Angles(0, 0.15 * s, 0), U.Shade(b.c, 0.8))
		k.ball(0.4, CFrame.new(p + v(0, -0.05, -0.29)) * CFrame.Angles(0, 0.15 * s, 0), WHITE)
		k.ball(0.26, CFrame.new(p + v(0, -0.05, -0.33)), b.c)
		for _, x in { -0.25, 0.25 } do
			k.rod(p + v(x, 0.55, -0.05), v(1.95 * s, -0.75, -0.3), 0.07, U.Shade(b.c, 0.7))
		end
		if s == 1 then -- tissue paper peeking out
			for _, t in { v(-0.2, 0.75, 0), v(0.2, 0.8, 0.05) } do
				k.wedge(v(0.08, 0.45, 0.4), CFrame.new(p + t) * CFrame.Angles(0, math.pi / 2, 0.3), rgb(255, 235, 120))
			end
		end
	end
	sunnies(k, rgb(255, 110, 180), rgb(40, 30, 60))
	-- receipt curling off the tail
	local paper = rgb(250, 248, 238)
	local p = v(0.2, -2.85, 2.0)
	local dir = v(0.1, -0.35, 1).Unit
	for i = 1, 8 do
		local nd = (CFrame.Angles(0.32, 0.12, 0):VectorToWorldSpace(dir)).Unit
		local q = p + nd * 0.55
		k.block(v(0.55, 0.03, 0.58), CFrame.lookAt((p + q) / 2, q), paper)
		if i % 2 == 1 then
			k.block(v(0.35, 0.035, 0.06), CFrame.lookAt((p + q) / 2, q) * at(-0.04, 0.01, 0), rgb(150, 150, 160))
		end
		p, dir = q, nd
	end
	sparkle(k, v(-2.2, 1.35, -0.9), 0.55, U.Vivid(k.glow))
	sparkle(k, v(2.4, 1.1, -0.7), 0.4, rgb(255, 230, 120), nil, 0.4)
end

S.Mannequin = function(k)
	-- shop-window mannequin: neat wig bob, eyelashes, scarf, big price tag, display-stand pole
	local hair, hairL = rgb(85, 50, 40), rgb(115, 70, 55)
	k.ball(3.7, at(0, 0.92, 0.28), hair)
	for _, s in { -1, 1 } do
		k.ball(1.75, at(1.28 * s, -0.12, 0.38), hair)
		k.block(v(0.9, 0.15, 0.9), at(1.5 * s, -0.95, 0.25), hair) -- blunt cut ends
		for i = 0, 1 do -- lashes
			k.block(v(0.22, 0.07, 0.06), U.Facing(k.surf(v(0.95 * s, 0.58 + i * 0.16, -1.25), 0.05), v(0.95 * s, 0.6, -1.25)) * CFrame.Angles(0, 0, -0.5 * s), EYE)
		end
	end
	k.ball(0.5, at(-0.75, 1.6, -0.95), hairL) -- hair clip
	k.ball(0.3, at(-0.95, 1.62, -1.08), rgb(255, 120, 170))
	-- scarf with two hanging ends
	local scarf, stripe = rgb(120, 220, 255), rgb(255, 255, 255)
	k.ring(-1.15, 0.45, scarf)
	k.ring(-1.15, 0.12, stripe)
	for i, s in { -1, 1 } do
		local cf = at(0.45 * s, -1.9, -1.45) * CFrame.Angles(0.25, 0, 0.15 * s + 0.1 * i)
		k.block(v(0.5, 1.3, 0.14), cf, scarf)
		k.block(v(0.52, 0.12, 0.16), cf * at(0, -0.45, 0), stripe)
		for x = -1, 1 do
			k.block(v(0.08, 0.2, 0.08), cf * at(x * 0.18, -0.74, 0), scarf) -- fringe
		end
	end
	-- price tag on a string from the left nub
	local tag = at(-2.35, -1.55, -0.55) * CFrame.Angles(0, 0.3, 0.25)
	k.rod(v(-1.95, -0.6, -0.3), tag * v(0.0, 0.62, 0), 0.05, rgb(60, 60, 70))
	k.block(v(0.95, 1.25, 0.06), tag, rgb(255, 250, 235))
	k.block(v(0.95, 0.3, 0.07), tag * at(0, -0.15, 0), rgb(235, 60, 70))
	k.block(v(0.55, 0.08, 0.08), tag * at(0, 0.25, -0.01), STEEL)
	k.ball(0.14, tag * at(0, 0.47, 0), STEEL)
	-- display stand pole under the tail
	k.rod(v(0.2, -2.9, 1.9), v(0.2, -4.7, 1.9), 0.18, SILVER, METAL)
	k.cyl(0.18, 1.7, at(0.2, -4.75, 1.9) * U.AxisY, STEEL, METAL)
end

S.FoodCourt = function(k)
	-- Queen of the Food Court: a lunch tray for a crown (burger, fries, giant soda with a bendy
	-- straw, gold points on its rim), pearl necklace, a fork sceptre, ketchup and mustard orbiting
	local tray = at(0, 1.95, 0.15) * CFrame.Angles(0.06, 0, -0.07)
	local trayC = rgb(220, 60, 60)
	k.block(v(4.0, 0.18, 3.0), tray, trayC)
	for _, z in { -1.45, 1.45 } do
		k.block(v(4.0, 0.3, 0.12), tray * at(0, 0.12, z), U.Shade(trayC, 0.85))
	end
	for _, x in { -1.95, 1.95 } do
		k.block(v(0.12, 0.3, 3.0), tray * at(x, 0.12, 0), U.Shade(trayC, 0.85))
	end
	-- the tray balances on a gold crown
	k.cyl(0.55, 2.7, at(0, 1.45, 0.1) * U.AxisY, GOLD, METAL)
	for i = 0, 7 do
		local a = i * 2 * math.pi / 8
		k.point(v(math.sin(a) * 1.25, 1.65, 0.1 - math.cos(a) * 1.25), v(math.sin(a) * 0.3, 1, -math.cos(a) * 0.3), 0.4, 0.3, 0.12, GOLD, METAL)
	end
	k.ball(0.38, at(0, 1.45, -1.25), rgb(90, 200, 255), NEON)
	for _, s in { -1, 1 } do
		k.ball(0.26, at(0.75 * s, 1.45, -1.05), rgb(255, 70, 110))
	end
	-- royal cape: red panels with a white fur collar
	local capeC = rgb(200, 40, 60)
	for i = -2, 2 do
		local cf = CFrame.Angles(0, i * 0.36, 0) * at(0, -1.1, 2.0) * CFrame.Angles(-0.25, 0, 0)
		k.block(v(1.4, 3.6, 0.14), cf, if i % 2 == 0 then capeC else U.Shade(capeC, 0.88))
		k.block(v(1.42, 0.16, 0.18), cf * at(0, -1.78, 0), GOLD)
	end
	for i = -3, 3 do
		k.ball(0.62, CFrame.Angles(0, i * 0.33, 0) * at(0, 0.55, 1.55), WHITE)
	end
	-- burger
	local bun = rgb(225, 150, 70)
	local bg = tray * at(-1.0, 0, 0.2)
	k.cyl(0.32, 1.35, bg * at(0, 0.25, 0) * U.AxisY, bun)
	k.cyl(0.28, 1.45, bg * at(0, 0.53, 0) * U.AxisY, rgb(110, 60, 35))
	k.block(v(1.15, 0.07, 1.15), bg * at(0, 0.7, 0) * CFrame.Angles(0, math.pi / 4, 0), rgb(255, 205, 50))
	k.cyl(0.08, 1.55, bg * at(0, 0.76, 0) * U.AxisY, rgb(110, 200, 80))
	k.cyl(0.1, 1.25, bg * at(0, 0.84, 0) * U.AxisY, rgb(230, 60, 55))
	k.ball(1.38, bg * at(0, 0.9, 0), bun)
	for _, p in { v(-0.3, 1.5, -0.25), v(0.25, 1.52, -0.2), v(0.0, 1.55, 0.2), v(-0.25, 1.48, 0.3) } do
		k.ball(0.13, bg * CFrame.new(p), rgb(255, 245, 220))
	end
	-- fries
	local fr = tray * at(0.2, 0, 0.7)
	k.block(v(0.85, 0.8, 0.5), fr * at(0, 0.5, 0), rgb(235, 50, 60))
	k.block(v(0.87, 0.12, 0.52), fr * at(0, 0.82, 0), rgb(255, 205, 50))
	for i = 0, 5 do
		local x = -0.3 + i * 0.12
		k.block(v(0.13, 0.75, 0.13), fr * at(x, 1.05 + (i % 2) * 0.12, (i % 3 - 1) * 0.1) * CFrame.Angles(0, 0, (i - 2.5) * 0.08), rgb(255, 215, 90))
	end
	-- giant soda cup with a bendy straw
	local sc = tray * at(1.0, 0, -0.35)
	k.cyl(2.0, 1.1, sc * at(0, 1.1, 0) * U.AxisY, WHITE)
	k.cyl(0.6, 1.12, sc * at(0, 1.0, 0) * U.AxisY, U.Vivid(k.glow))
	k.cyl(0.14, 1.18, sc * at(0, 2.12, 0) * U.AxisY, rgb(235, 235, 240))
	local s0 = sc * v(0.1, 2.15, 0)
	local s1 = s0 + v(0, 0.9, 0)
	local s2 = s1 + v(0.6, 0.35, 0)
	k.rod(s0, s1, 0.16, rgb(255, 110, 160))
	k.ball(0.16, CFrame.new(s1), rgb(255, 110, 160))
	k.rod(s1, s2, 0.16, rgb(255, 110, 160))
	-- pearl necklace
	k.ruff(-1.05, 14, 0.3, WHITE, rgb(255, 240, 230))
	-- lashes
	for _, s in { -1, 1 } do
		for i = 0, 1 do
			k.block(v(0.22, 0.07, 0.06), U.Facing(k.surf(v(0.95 * s, 0.58 + i * 0.16, -1.25), 0.05), v(0.95 * s, 0.6, -1.25)) * CFrame.Angles(0, 0, -0.5 * s), EYE)
		end
	end
	-- fork sceptre in her right nub
	local fb = v(2.1, -0.9, -0.5)
	k.rod(fb, fb + v(0.15, 2.8, 0), 0.2, SILVER, METAL)
	local fh = fb + v(0.16, 2.85, 0)
	k.block(v(0.85, 0.22, 0.14), CFrame.new(fh), SILVER, METAL)
	for i = 0, 3 do
		k.block(v(0.12, 0.8, 0.12), CFrame.new(fh + v(-0.36 + i * 0.24, 0.48, 0)), SILVER, METAL)
	end
	k.ball(0.35, CFrame.new(fb + v(0, -0.15, 0)), GOLD, METAL)
	-- ketchup and mustard bottles orbiting, mid-squirt
	for _, b in { { p = v(-3.3, 0.8, -0.6), dir = v(0.5, 1, -0.2), c = rgb(225, 40, 45), cap = WHITE }, { p = v(3.4, -1.6, -0.4), dir = v(-0.45, 1, -0.3), c = rgb(255, 210, 40), cap = rgb(225, 40, 45) } } do
		local cf = upAlong(b.p, b.dir)
		k.cyl(1.3, 0.75, cf * U.AxisY, b.c)
		k.ball(0.75, cf * at(0, 0.62, 0), b.c)
		k.cyl(0.25, 0.42, cf * at(0, 1.0, 0) * U.AxisY, b.cap)
		k.point(cf * v(0, 1.1, 0), cf.UpVector, 0.3, 0.4, 0.3, b.cap)
		k.block(v(0.5, 0.45, 0.05), cf * at(0, -0.05, -0.38), WHITE) -- label
		for i = 1, 2 do
			k.ball(0.28 - i * 0.06, CFrame.new(cf * v(0, 1.4 + i * 0.4, 0)), b.c)
		end
	end
end

------------------------------------------------------------------ 25 Dino Museum
S.Pterodactyl = function(k)
	-- bony pterodactyl wings (membranes on bone struts), long head crest, tiny beak
	local bone, boneD = rgb(250, 244, 225), rgb(210, 195, 160)
	local mem = rgb(225, 210, 180)
	for _, s in { -1, 1 } do
		local sh, el, tp = v(1.3 * s, 0.5, 0.45), v(2.9 * s, 1.55, 0.55), v(4.5 * s, 0.75, 0.75)
		local l1, l2 = v(1.25 * s, -0.75, 0.55), v(3.0 * s, -0.05, 0.65)
		tri(k, sh, el, l1, 0.08, mem)
		tri(k, el, l2, l1, 0.08, U.Shade(mem, 0.93))
		tri(k, el, tp, l2, 0.08, mem)
		k.rod(sh, el, 0.24, bone)
		k.rod(el, tp, 0.18, bone)
		k.rod(el, l2, 0.12, boneD)
		k.ball(0.32, CFrame.new(el), bone)
		k.point(el + v(0, 0.1, -0.05), v(0.2 * s, 0.6, -0.7), 0.16, 0.35, 0.12, boneD) -- wing claw
	end
	-- crest sweeping back from the head
	blade(k, v(0, 1.3, 0.85), v(0, 0.45, 1), v(1, 0, 0), 0.85, 2.2, 0.12, bone)
	k.block(v(0.13, 0.12, 1.4), CFrame.lookAt(v(0, 1.55, 1.25), v(0, 1.95, 2.3)), U.Vivid(k.glow))
	-- tiny beak
	local bp = k.surf(v(0, -0.3, -1), -0.05)
	k.point(bp, v(0, -0.3, -1), 0.5, 0.7, 0.32, rgb(235, 195, 120))
	k.block(v(0.05, 0.05, 0.4), CFrame.lookAt(bp + v(0, -0.05, -0.2), bp + v(0, -0.25, -0.8)), rgb(150, 110, 60))
end

S.RaptorSkull = function(k)
	-- raptor skull helmet (long toothy snout, round eye holes), curved claws on the nubs, back spikes
	local bone, boneD = rgb(245, 238, 215), rgb(205, 192, 160)
	local dark = rgb(45, 35, 40)
	local cc = v(0, 0.95, 0.3)
	k.ball(3.45, CFrame.new(cc), bone)
	k.block(v(2.1, 0.28, 0.45), at(0, 1.05, -1.42) * CFrame.Angles(-0.2, 0, 0), boneD) -- brow ridge
	for _, s in { -1, 1 } do
		local d = v(0.82 * s, 0.4, -0.4).Unit
		k.cyl(0.12, 0.75, U.DiscFacing(cc + d * 1.68, d), dark)
		k.ball(0.18, CFrame.new(cc + d * 1.72 + v(0, 0, -0.1)), U.Vivid(k.glow))
	end
	local sn = at(0, 1.35, -1.45) * CFrame.Angles(0.18, 0, 0)
	k.block(v(1.4, 0.72, 2.3), sn * at(0, 0, -1.0), bone)
	k.wedge(v(1.4, 0.72, 0.65), sn * at(0, 0, -2.45), bone)
	k.block(v(1.42, 0.12, 2.3), sn * at(0, -0.3, -1.0), boneD)
	for _, s in { -1, 1 } do
		k.ball(0.18, sn * at(0.3 * s, 0.25, -2.3), dark)
		for i = 0, 4 do
			k.point(sn * v(0.58 * s, -0.35, -0.25 - i * 0.45), sn:VectorToWorldSpace(v(0, -1, 0)), 0.18, 0.3, 0.1, WHITE)
		end
	end
	-- curved claw on each nub
	local claw = rgb(70, 60, 60)
	for _, s in { -1, 1 } do
		local p0 = v(2.1 * s, -0.4, -0.45)
		local p1 = p0 + v(0.25 * s, 0.12, -0.38)
		local p2 = p1 + v(0.08 * s, -0.12, -0.32)
		k.rod(p0, p1, 0.24, claw)
		k.rod(p1, p2, 0.19, claw)
		k.point(p2, v(0.0, -0.75, -0.45), 0.18, 0.35, 0.15, claw)
	end
	-- spikes down the back
	for i, y in { -0.3, -0.85, -1.4 } do
		local d = v(0, y, 1)
		k.point(k.surf(d, -0.05), v(0, 0.5, 1), 0.45 - i * 0.06, 0.6 - i * 0.08, 0.14, boneD)
	end
end

S.BoneTyrant = function(k)
	-- Rex the Bone Tyrant: a giant fossil T-rex skull worn over the ghost (it peers out between the
	-- toothy jaws), glowing eye sockets, ribcage round the body, tiny bony arms and a long tail of
	-- shrinking vertebrae with spines
	local bone, boneD = rgb(228, 215, 182), rgb(186, 168, 130)
	local dark = rgb(40, 32, 36)
	local tooth = rgb(255, 252, 240)
	-- jaws hinge behind the head and gape wide open so the face shows between them
	local up = at(0, 1.0, 1.0) * CFrame.Angles(0.32, 0, 0) * at(0, 0.85, -1.55)
	k.block(v(3.9, 2.1, 3.0), up * at(0, 0.5, 1.25), bone)
	k.wedge(v(3.9, 0.9, 1.6), up * at(0, 1.98, 1.95), boneD)
	k.block(v(3.1, 1.4, 3.4), up * at(0, 0.1, -1.8), bone)
	k.wedge(v(3.1, 0.75, 2.8), up * at(0, 1.17, -1.7), bone)
	k.wedge(v(3.1, 1.4, 0.8), up * at(0, 0.1, -3.9), bone)
	k.block(v(3.15, 0.18, 3.4), up * at(0, -0.5, -1.8), boneD)
	for _, s in { -1, 1 } do
		-- socket with a glowing eye, nostril, brow horn, cheek bone down to the jaw
		k.ball(1.25, up * at(1.6 * s, 0.75, 0.35), dark)
		k.ball(0.42, up * at(1.98 * s, 0.75, 0.25), k.glow, NEON)
		k.ball(0.5, up * at(0.7 * s, 0.75, -3.35), dark)
		k.point(up * v(1.5 * s, 1.55, 0.25), up:VectorToWorldSpace(v(0.3 * s, 1, 0.2)), 0.6, 0.7, 0.4, boneD)
		k.block(v(0.5, 3.0, 1.0), at(1.85 * s, 0.1, 1.0) * CFrame.Angles(0, 0, -0.12 * s), boneD)
		-- upper teeth along the jaw edge
		for i = 0, 4 do
			k.point(up * v(1.33 * s, -0.55, -0.45 - i * 0.6), up:VectorToWorldSpace(v(0, -1, -0.1)), 0.36, 0.6, 0.28, tooth)
		end
		k.point(up * v(0.7 * s, -0.55, -3.45), up:VectorToWorldSpace(v(0, -1, -0.1)), 0.36, 0.55, 0.28, tooth)
	end
	-- lower jaw, opened wide under the face
	local lo = at(0, -0.9, 0.9) * CFrame.Angles(-0.2, 0, 0) * at(0, -0.95, -1.4)
	for _, s in { -1, 1 } do
		k.block(v(0.6, 0.75, 3.7), lo * at(1.3 * s, 0, -1.25), bone)
		for i = 0, 3 do
			k.point(lo * v(1.3 * s, 0.37, -0.2 - i * 0.68), lo:VectorToWorldSpace(v(0, 1, -0.1)), 0.34, 0.5, 0.26, tooth)
		end
		k.point(lo * v(0.75 * s, 0.37, -3.05), lo:VectorToWorldSpace(v(0, 1, -0.1)), 0.34, 0.5, 0.26, tooth)
	end
	k.block(v(3.2, 0.75, 0.75), lo * at(0, 0, -3.1), bone)
	k.wedge(v(3.2, 0.5, 0.75), lo * at(0, -0.62, -3.1) * CFrame.Angles(math.pi, 0, 0), boneD)
	-- ribcage round the back half of the body and the spine
	for i, r in { { y = -0.5, z = 0.2, r = 1.85 }, { y = -1.1, z = 0.4, r = 1.62 }, { y = -1.7, z = 0.75, r = 1.38 } } do
		arc(k, at(0, r.y, r.z) * CFrame.Angles(math.pi / 2, 0, 0), r.r, math.rad(-20), math.rad(200), 6, 0.3 - i * 0.03, bone)
		k.block(v(0.5, 0.42, 0.5), at(0, r.y, r.z + r.r), boneD)
	end
	-- tiny bony arms
	for _, s in { -1, 1 } do
		local sh = v(1.85 * s, -0.55, -0.45)
		local el = sh + v(0.35 * s, -0.45, -0.55)
		local wr = el + v(-0.1 * s, 0.2, -0.55)
		k.rod(sh, el, 0.24, bone)
		k.rod(el, wr, 0.2, bone)
		k.ball(0.3, CFrame.new(el), boneD)
		for _, d in { -1, 1 } do
			k.point(wr, v(0.15 * d, -0.6, -0.8), 0.13, 0.35, 0.1, boneD)
		end
	end
	-- long tail of shrinking vertebrae with spines
	local p = v(0.1, -2.35, 2.2)
	local dir = v(0.05, -0.15, 1).Unit
	for i = 1, 9 do
		local s = 0.98 - i * 0.07
		local q = p + dir * (s + 0.12)
		local f = CFrame.lookAt((p + q) / 2, q)
		k.block(v(s, s * 0.85, s * 0.9), f, if i % 2 == 0 then boneD else bone)
		k.point(f * v(0, s * 0.4, 0), f.UpVector + f.LookVector * -0.4, s * 0.5, s * 0.7, s * 0.25, bone)
		p = q
		dir = (CFrame.Angles(if i < 5 then 0.09 else -0.07, 0.06, 0):VectorToWorldSpace(dir)).Unit
	end
	for _, s in { -1, 1 } do
		k.brow(s, 0.98, true, dark, 0.6)
	end
end

------------------------------------------------------------------ 26 Stadium
S.Cheerleader = function(k)
	-- fluffy pom-pom on each nub, big hair bow, team skirt band, a little megaphone floating by
	local pink = U.Vivid(k.glow)
	for _, s in { -1, 1 } do
		local c = v(2.3 * s, -0.2, -0.35)
		k.ball(0.7, CFrame.new(c), pink)
		for i = 0, 7 do
			local a = i * 2 * math.pi / 8
			local d = v(math.cos(a) * 0.38, math.sin(a) * 0.38, -0.12 + (i % 2) * 0.25)
			k.ball(0.5, CFrame.new(c + d), if i % 2 == 0 then pink else WHITE)
		end
	end
	-- hair bow on top
	local kn = v(0.55, 1.75, -0.35)
	k.ball(0.45, CFrame.new(kn), pink)
	for _, s in { -1, 1 } do
		local out = v(s, 0.35 * s + 0.1, 0).Unit
		blade(k, kn + out * 1.05, -out, v(0, 0, -1), 0.95, 1.0, 0.28, pink)
		blade(k, kn + v(0.05 * s, -0.1, 0), v(0.4 * s, -1, -0.2), v(0, 0, -1), 0.3, 0.6, 0.08, pink)
	end
	-- skirt band with a white stripe
	k.ring(-1.25, 0.4, pink)
	k.ring(-1.0, 0.1, WHITE)
	-- megaphone floating beside it
	local mouth = v(-3.0, 1.1, -0.9)
	local back = v(0.85, -0.25, 0.3).Unit
	local cf = upAlong(mouth, back)
	k.cone(cf, 1.1, 1.3, 3, WHITE, pink)
	k.cyl(0.06, 0.95, U.DiscFacing(mouth - back * 0.02, -back), EYE)
	k.block(v(0.18, 0.5, 0.18), cf * at(0, 0.75, 0.35), pink)
	sparkle(k, v(-2.3, 2.0, -0.9), 0.45, rgb(255, 230, 120))
end

S.FoamFinger = function(k)
	-- waving a giant foam "#1" hand, team cap on backwards, two face-paint stripes on each cheek
	local foam = U.Vivid(k.glow)
	local navy = rgb(40, 60, 150)
	local cuff = at(2.45, 0.2, -0.45) * CFrame.Angles(0, -0.15, -0.25)
	k.rod(v(1.95, -0.4, -0.3), cuff * v(0, -0.2, 0), 0.25, navy)
	k.block(v(1.35, 0.55, 0.65), cuff, navy)
	k.block(v(1.3, 1.15, 0.58), cuff * at(0, 0.82, 0), foam)
	k.block(v(0.46, 1.5, 0.54), cuff * at(-0.38, 2.1, 0), foam)
	k.ball(0.5, cuff * at(-0.38, 2.85, 0), foam)
	for i = 0, 2 do
		k.ball(0.42, cuff * at(-0.02 + i * 0.3, 1.42, -0.04), U.Shade(foam, 0.92))
	end
	k.block(v(0.36, 0.75, 0.48), cuff * at(-0.82, 0.85, 0) * CFrame.Angles(0, 0, 0.5), U.Shade(foam, 0.92))
	-- "#1" on the palm
	local pf = cuff * at(0.1, 0.85, -0.3)
	k.block(v(0.12, 0.62, 0.05), pf * at(-0.25, 0, 0), WHITE)
	k.block(v(0.22, 0.1, 0.05), pf * at(-0.17, 0.24, 0) * CFrame.Angles(0, 0, -0.6), WHITE)
	for _, d in { -0.1, 0.1 } do
		k.block(v(0.06, 0.45, 0.05), pf * at(0.3 + d, 0, 0), WHITE)
		k.block(v(0.4, 0.06, 0.05), pf * at(0.3, d, 0), WHITE)
	end
	-- team cap on backwards
	k.ball(2.5, at(0, 1.12, 0.12), navy)
	k.block(v(1.4, 0.12, 1.1), at(0, 1.5, 1.6) * CFrame.Angles(-0.25, 0, 0), foam)
	k.ball(0.3, at(0, 2.37, 0.12), foam)
	k.block(v(0.5, 0.35, 0.05), U.Facing(k.surf(v(0, 0.8, 1.2), 0.38), v(0, 0.4, 1)), WHITE) -- strap gap
	-- face paint
	for _, s in { -1, 1 } do
		for i, y in { 0.0, -0.25 } do
			k.block(v(0.45, 0.11, 0.06), onSurf(k, v(1.0 * s, y - 0.05, -1.4), 0.0, 0.15 * s), if i == 1 then foam else navy)
		end
	end
	-- pennant flag in the other nub
	local fp = v(-2.05, -0.4, -0.35)
	k.rod(fp, fp + v(-0.3, 2.0, 0), 0.1, WHITE)
	tri(k, fp + v(-0.29, 1.95, 0), fp + v(-0.2, 1.25, 0), fp + v(-1.6, 1.75, -0.1), 0.06, navy)
end

S.Scoreboard = function(k)
	-- the Phantom Scoreboard: a stadium scoreboard for a body; its big screen is its face (pixel eyes,
	-- smirk), glowing score digits above, a bulb strip below, horn speakers on top and a floodlight
	-- tower on each side
	local frameC = rgb(38, 42, 58)
	local screen = rgb(14, 20, 32)
	local amber = rgb(255, 185, 60)
	local green = U.Vivid(k.glow)
	k.block(v(6.6, 5.5, 1.4), at(0, 0.55, -1.15), frameC, METAL)
	for _, y in { 3.27, -2.17 } do
		k.block(v(6.75, 0.22, 1.5), at(0, y, -1.15), green)
	end
	-- face screen
	local fc = at(0, 0.05, -1.86)
	k.block(v(3.6, 2.5, 0.1), fc, screen)
	for _, s in { -1, 1 } do
		k.block(v(0.66, 0.66, 0.06), fc * at(0.8 * s, 0.3, -0.06), k.glow, NEON)
		k.block(v(0.24, 0.24, 0.06), fc * at(0.8 * s + 0.14, 0.44, -0.09), WHITE)
		k.block(v(0.8, 0.16, 0.06), fc * at(0.8 * s, 0.86, -0.06) * CFrame.Angles(0, 0, -0.32 * s), green)
	end
	for _, p in { { -1.0, -0.4 }, { -0.55, -0.68 }, { 0, -0.72 }, { 0.5, -0.66 }, { 0.92, -0.45 }, { 1.2, -0.18 } } do
		k.block(v(0.42, 0.26, 0.06), fc * at(p[1], p[2], -0.06), green)
	end
	-- score panels: HOME 10, GUEST 07 (digits only), period lights in the middle
	for _, sc in { { x = -2.0, d = { 1, 0 } }, { x = 2.0, d = { 0, 7 } } } do
		local pc = at(sc.x, 2.3, -1.86)
		k.block(v(2.0, 1.45, 0.1), pc, screen)
		for i, n in sc.d do
			digit(k, pc * at(0.42 - (i - 1) * 0.84, 0.1, -0.07), n, 0.85, amber, NEON)
		end
		k.block(v(1.2, 0.09, 0.05), pc * at(0, -0.55, -0.07), WHITE)
	end
	local mc = at(0, 2.3, -1.86)
	k.block(v(1.4, 0.95, 0.1), mc, screen)
	for i = -1, 1 do
		k.ball(0.26, mc * at(i * 0.38, 0.12, -0.05), if i == -1 then rgb(255, 80, 80) else rgb(70, 70, 90), if i == -1 then NEON else nil)
	end
	k.block(v(0.9, 0.09, 0.05), mc * at(0, -0.25, -0.07), WHITE)
	-- bulb strip under the screen
	for i = 0, 10 do
		k.ball(0.26, at(-2.75 + i * 0.55, -1.55, -1.88), if i % 2 == 0 then rgb(255, 245, 210) else green)
	end
	-- horn speakers on top
	for _, s in { -1, 1 } do
		local post = v(1.7 * s, 3.4, -1.1)
		k.rod(post, post + v(0, 0.75, 0), 0.22, STEEL, METAL)
		local out = v(0.7 * s, 0.25, -0.65).Unit
		local mouth = post + v(0, 0.85, 0) + out * 1.2
		k.cone(upAlong(mouth, -out), 1.15, 1.25, 3, rgb(215, 220, 230), rgb(170, 175, 190))
		k.cyl(0.06, 1.0, U.DiscFacing(mouth + out * 0.02, out), rgb(30, 30, 40))
	end
	-- pennant string between the floodlights
	local flagC = { rgb(255, 205, 60), U.Vivid(k.glow), WHITE }
	for i = 0, 6 do
		local x = -3.3 + i * 1.1
		local y = 4.58
		tri(k, v(x - 0.4, y, -1.4), v(x + 0.4, y, -1.4), v(x, y - 0.75, -1.45), 0.06, flagC[i % 3 + 1])
	end
	k.rod(v(-3.9, 4.6, -1.4), v(3.9, 4.6, -1.4), 0.05, rgb(230, 230, 240))
	-- floodlight towers
	for _, s in { -1, 1 } do
		local x = 4.05 * s
		k.rod(v(x, -4.2, -0.9), v(x, 4.9, -0.9), 0.32, STEEL, METAL)
		for _, y in { 2.3, -1.4 } do
			k.rod(v(3.25 * s, y, -1.0), v(x, y, -0.9), 0.18, STEEL, METAL)
		end
		local head = at(x, 5.35, -1.0) * CFrame.Angles(-0.25, -0.35 * s, 0)
		k.block(v(1.75, 1.25, 0.35), head, frameC, METAL)
		for i = 0, 3 do
			local lx, ly = (i % 2 - 0.5) * 0.8, (math.floor(i / 2) - 0.5) * 0.55
			k.cyl(0.08, 0.45, head * at(lx, ly, -0.2) * U.AxisZ, rgb(255, 250, 225), NEON)
		end
		-- white cartoon gloves gripping the board edges
		k.ball(1.0, at(3.45 * s, -0.7, -1.6), WHITE)
		k.cyl(0.3, 0.75, at(3.85 * s, -0.75, -1.55), U.Vivid(k.glow))
		k.ball(0.42, at(3.2 * s, -0.25, -1.95), WHITE)
	end
end

------------------------------------------------------------------ 28 Giant's Kitchen
S.Crumb = function(k)
	-- hugging a cookie crumb as big as itself (chocolate chips), rainbow sprinkles floating round
	local cookie, cookieL = rgb(205, 145, 75), rgb(230, 175, 100)
	local chip = rgb(80, 45, 30)
	k.block(v(2.3, 1.45, 1.4), at(0, -1.75, -1.55) * CFrame.Angles(0.1, 0.15, 0.08), cookie)
	k.block(v(1.3, 1.0, 1.0), at(-0.95, -1.5, -1.55) * CFrame.Angles(0.5, 0.3, 0.6), cookieL)
	k.block(v(1.1, 0.9, 0.95), at(0.95, -2.2, -1.35) * CFrame.Angles(-0.3, 0.5, 0.4), cookie)
	k.block(v(0.8, 0.7, 0.8), at(0.3, -2.45, -1.8) * CFrame.Angles(0.7, 0.2, 0.3), cookieL)
	for _, p in { v(-0.45, -1.35, -2.3), v(0.45, -1.85, -2.3), v(0.95, -1.35, -2.0), v(-1.15, -2.0, -2.0), v(0.0, -2.4, -2.25), v(-0.6, -1.15, -1.0) } do
		k.ball(0.36, CFrame.new(p), chip)
	end
	for _, s in { -1, 1 } do
		k.ball(0.62, at(1.15 * s, -1.25, -2.05), k.color) -- little hands hugging it
	end
	k.block(v(0.16, 0.14, 0.14), CFrame.new(k.surf(v(0.6, -0.55, -1.4), 0.03)) * CFrame.Angles(0.3, 0.4, 0.2), cookie) -- crumb on its cheek
	local colors = { rgb(255, 90, 120), rgb(255, 210, 60), rgb(90, 210, 255), rgb(130, 230, 120), rgb(190, 120, 255), rgb(255, 150, 60) }
	for i, p in { v(2.3, 1.0, -0.6), v(2.6, -0.3, -0.2), v(-2.4, 0.8, -0.4), v(-2.55, -0.6, 0.0), v(1.6, 2.0, -0.2), v(-1.4, 2.1, 0.1), v(2.2, -1.6, 0.5), v(-2.1, -1.7, 0.6) } do
		k.cyl(0.5, 0.15, CFrame.new(p) * CFrame.Angles(i * 0.9, i * 1.7, i * 0.6), colors[(i - 1) % 6 + 1])
	end
end

S.Teacup = function(k)
	-- sitting in a flowery teacup on a saucer: gold rim, ring handle, tea-bag tag, steam puffs
	local china = rgb(250, 248, 245)
	local c = v(0, 0, 0.3)
	k.cyl(0.9, 4.2, CFrame.new(c + v(0, -1.35, 0)) * U.AxisY, china)
	k.cyl(0.9, 3.5, CFrame.new(c + v(0, -2.2, 0)) * U.AxisY, china)
	k.cyl(0.3, 2.2, CFrame.new(c + v(0, -2.75, 0)) * U.AxisY, china)
	k.cyl(0.12, 4.3, CFrame.new(c + v(0, -0.9, 0)) * U.AxisY, GOLD, METAL)
	k.cyl(0.05, 4.05, CFrame.new(c + v(0, -0.88, 0)) * U.AxisY, rgb(170, 105, 55)) -- tea
	-- saucer
	k.cyl(0.16, 5.4, CFrame.new(c + v(0, -2.95, 0)) * U.AxisY, china)
	k.cyl(0.06, 5.5, CFrame.new(c + v(0, -2.88, 0)) * U.AxisY, GOLD, METAL)
	-- ring handle
	arc(k, CFrame.new(c + v(2.05, -1.55, 0)), 0.55, math.rad(-100), math.rad(100), 6, 0.25, china)
	-- flowers on the side
	local petal = PINKY
	for i, a in { -0.55, 0.15, 0.85 } do
		local d = v(math.sin(a), 0, -math.cos(a))
		local f = CFrame.lookAt(c + v(0, -1.4 + (i % 2) * 0.15, 0) + d * 2.08, c + v(0, -1.4, 0) + d * 3)
		for j = 0, 3 do
			local t = j * math.pi / 2 + 0.4
			k.ball(0.32, f * at(math.cos(t) * 0.2, math.sin(t) * 0.2, 0), if i == 2 then rgb(160, 170, 255) else petal)
		end
		k.ball(0.2, f * at(0, 0, -0.05), rgb(255, 215, 70))
	end
	-- tea bag string over the rim and its tag
	local tagC = U.Vivid(k.glow)
	local rim = c + v(-1.45, -0.82, -1.55)
	k.rod(v(-0.9, -0.9, -1.0), rim, 0.05, WHITE)
	k.rod(rim, rim + v(-0.05, -0.6, -0.06), 0.05, WHITE)
	k.block(v(0.5, 0.55, 0.05), CFrame.lookAt(rim + v(-0.05, -0.85, -0.08), rim + v(-0.8, -0.85, -1.0)), tagC)
	-- steam puffs
	for i, p in { v(1.1, 1.95, 0.5), v(0.7, 2.6, 0.75), v(1.15, 3.2, 0.95) } do
		k.ball(0.7 - i * 0.12, CFrame.new(p), rgb(245, 245, 255))
	end
	-- pinky raised
	k.ball(0.32, at(-2.15, -0.05, -0.35), k.color)
end

S.CheeseWheel = function(k)
	-- the Big Cheese: half inside a giant holey cheese wedge, a mousetrap for a crown, a curly
	-- moustache, a butter-knife sword, and a little mouse peeking out of one hole
	local cheese, hole = rgb(255, 200, 65), rgb(220, 155, 35)
	local rind = rgb(240, 150, 40)
	local y = -2.1
	local a, b, c = v(-3.6, y, 2.4), v(3.6, y, 2.4), v(0, y, -3.7)
	tri(k, a, b, c, 2.4, cheese)
	k.block(v(7.2, 2.42, 0.22), at(0, y, 2.45), rind)
	-- holes on the two front faces, the top and its edges
	for _, side in { { a, c }, { b, c } } do
		local p0, p1 = side[1], side[2]
		local n = (p1 - p0):Cross(Vector3.yAxis).Unit
		if n:Dot(p0 - v(0, y, 0)) < 0 then
			n = -n
		end
		for i, h in { { 0.25, 0.35, 0.95 }, { 0.55, -0.45, 0.7 }, { 0.8, 0.3, 0.55 } } do
			local p = p0 + (p1 - p0) * h[1] + v(0, h[2], 0) + n * 0.02
			k.cyl(0.08, h[3], U.DiscFacing(p, n), hole)
			if i == 2 then
				k.ball(h[3] * 0.85, CFrame.new(p - n * 0.25), hole)
			end
		end
	end
	for _, p in { v(-1.6, y + 1.2, 1.2), v(1.9, y + 1.2, 1.5), v(0.4, y + 1.2, -2.3) } do
		k.cyl(0.08, 0.8, CFrame.new(p) * U.AxisY, hole)
	end
	k.ball(0.9, CFrame.new(v(2.6, y + 1.15, 1.6)), hole)
	-- mouse peeking from the left face
	local mp = b + (c - b) * 0.42 + v(0, -0.55, 0)
	local n = (c - b):Cross(Vector3.yAxis).Unit
	if n.X < 0 then
		n = -n
	end
	local grey = rgb(175, 175, 190)
	k.ball(0.55, CFrame.new(mp + n * 0.2), grey)
	for _, s in { -1, 1 } do
		local side = n:Cross(Vector3.yAxis).Unit
		local ep = mp + n * 0.1 + side * 0.22 * s + v(0, 0.3, 0)
		k.cyl(0.06, 0.32, U.DiscFacing(ep, n), grey)
		k.cyl(0.07, 0.2, U.DiscFacing(ep + n * 0.03, n), PINKY)
		k.ball(0.08, CFrame.new(mp + n * 0.44 + side * 0.1 * s + v(0, 0.08, 0)), EYE)
	end
	k.ball(0.12, CFrame.new(mp + n * 0.5 + v(0, -0.05, 0)), PINKY)
	-- curly moustache
	local stache = rgb(125, 75, 40)
	for _, s in { -1, 1 } do
		local m0 = k.surf(v(0.08 * s, -0.15, -1.7), 0.1)
		local m1 = k.surf(v(0.6 * s, -0.2, -1.5), 0.08)
		local m2 = k.surf(v(0.92 * s, 0.05, -1.35), 0.06)
		k.ball(0.42, CFrame.new(m0), stache)
		k.rod(m0, m1, 0.36, stache)
		k.ball(0.32, CFrame.new(m1), stache)
		k.rod(m1, m2, 0.26, stache)
		k.ball(0.26, CFrame.new(m2), stache)
		k.brow(s, 0.98, false, stache, 0.6)
	end
	-- mousetrap crown with gold corner points and a cheese bait
	local wood = rgb(205, 155, 95)
	local mt = at(0, 1.85, 0.1) * CFrame.Angles(-0.08, 0, 0.1)
	k.block(v(2.5, 0.2, 1.5), mt, wood)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			k.point(mt * v(1.12 * x, 0.1, 0.62 * z), mt.UpVector, 0.3, 0.55, 0.14, GOLD, METAL)
		end
	end
	k.cyl(1.4, 0.3, mt * at(0, 0.25, 0.4), SILVER, METAL)
	for _, x in { -0.85, 0.85 } do
		k.rod(mt * v(x, 0.15, 0.45), mt * v(x, 1.05, 0.15), 0.08, SILVER, METAL)
	end
	k.rod(mt * v(-0.85, 1.05, 0.15), mt * v(0.85, 1.05, 0.15), 0.08, SILVER, METAL)
	k.block(v(0.6, 0.05, 0.5), mt * at(0, 0.13, -0.35), SILVER, METAL)
	k.wedge(v(0.35, 0.25, 0.4), mt * at(0, 0.28, -0.35), cheese)
	-- butter-knife sword in the right nub
	local hb = v(2.15, -0.25, -0.5)
	k.cyl(0.9, 0.34, CFrame.new(hb) * U.AxisY, rgb(250, 245, 235))
	k.block(v(0.6, 0.14, 0.3), CFrame.new(hb + v(0, 0.5, 0)), SILVER, METAL)
	k.block(v(0.46, 2.6, 0.08), CFrame.new(hb + v(0, 1.85, 0)), SILVER, METAL)
	k.cyl(0.08, 0.46, CFrame.new(hb + v(0, 3.15, 0)) * U.AxisZ, SILVER, METAL)
	k.block(v(0.3, 0.35, 0.06), CFrame.new(hb + v(0.04, 2.6, -0.06)), rgb(255, 235, 140)) -- butter smear
end

------------------------------------------------------------------ 29 Cyber Arcade
S.Pixel = function(k)
	-- chunky pixel ghost: stepped cube outline, square 8-bit eyes and smile, stair tail, square coins
	local g = 0.5
	for i = -4, 4 do
		for j = -4, 4 do
			local x, y = i * g, j * g
			local d = math.sqrt(x * x + y * y)
			if d > 1.45 and d < 1.95 then
				k.block(v(g, g, 1.2), at(x, y, 0.3), if (i + j) % 3 == 0 then U.Shade(k.color, 0.9) else k.color)
			end
		end
	end
	k.block(v(g, g, g), at(1.0, 1.5, -0.4), U.Vivid(k.glow)) -- highlight pixel
	-- stair-stepped tail
	for i, s in { 0.95, 0.75, 0.55, 0.4 } do
		k.block(v(s, s, s), at(0.1 + i * 0.12, -1.85 - i * 0.42, 0.6 + i * 0.45), k.color)
	end
	-- 8-bit face
	for _, s in { -1, 1 } do
		local e = k.surf(v(0.6 * s, 0.35, -1.4), 0.02)
		local f = U.Facing(e, e)
		k.block(v(0.55, 0.75, 0.14), f, EYE)
		k.block(v(0.2, 0.2, 0.06), f * at(0.1, 0.18, -0.08), WHITE)
		k.block(v(0.28, 0.2, 0.08), U.Facing(k.surf(v(1.0 * s, -0.15, -1.45), 0.0), v(1.0 * s, -0.15, -1.45)), PINKY)
		local mc = k.surf(v(0.38 * s, -0.42, -1.6), 0.0)
		k.block(v(0.2, 0.2, 0.1), U.Facing(mc, mc), EYE)
	end
	local mm = k.surf(v(0, -0.6, -1.6), 0.0)
	k.block(v(0.56, 0.2, 0.1), U.Facing(mm, mm), EYE)
	-- square coins
	for _, p in { v(2.65, 0.9, -0.5), v(3.15, -0.15, -0.2), v(-2.7, 0.55, -0.3) } do
		local cf = CFrame.new(p) * CFrame.Angles(0, 0.4, 0)
		k.block(v(0.6, 0.6, 0.14), cf, GOLD)
		k.block(v(0.32, 0.32, 0.16), cf, rgb(255, 235, 140))
	end
end

S.Glitch = function(k)
	-- RGB-split ghost: pink and cyan copies offset left and right, jagged scanline slices, glitchy
	-- eyes, gremlin ears, floating error bars and a "?" block over its head
	local cyan, pink = rgb(70, 230, 255), rgb(255, 80, 190)
	k.ball(3.5, at(-0.14, 0.03, 0.32), cyan)
	k.ball(3.5, at(0.14, -0.03, 0.32), pink)
	for _, b in { { y = 1.05, x = -0.5, c = cyan }, { y = 0.45, x = 0.55, c = pink }, { y = -0.65, x = -0.6, c = cyan }, { y = -1.25, x = 0.5, c = pink } } do
		local w = 2 * math.sqrt(3.06 - b.y * b.y)
		k.block(v(w, 0.2, 1.4), at(b.x, b.y, 0.15), b.c)
	end
	for _, s in { -1, 1 } do
		k.ball(0.9, at(0.6 * s - 0.1, 0.35, -1.33), cyan)
		k.ball(0.9, at(0.6 * s + 0.1, 0.35, -1.33), pink)
		-- pointy gremlin ears
		k.point(v(1.35 * s, 1.0, 0.0), v(0.8 * s, 1, 0.1), 0.75, 1.0, 0.25, k.color)
		k.point(v(1.4 * s, 1.05, -0.1), v(0.8 * s, 1, 0.1), 0.4, 0.65, 0.26, pink)
		k.brow(s, 0.98, false, rgb(70, 50, 110), 0.55)
	end
	-- floating error bars
	for _, e in { { p = v(2.6, 1.25, -0.3), w = 0.95, c = WHITE }, { p = v(3.0, 1.05, -0.3), w = 0.5, c = pink }, { p = v(-2.65, -0.85, -0.2), w = 1.0, c = rgb(30, 25, 45) },
		{ p = v(-2.3, -1.08, -0.2), w = 0.45, c = cyan }, { p = v(2.4, -1.4, 0.1), w = 0.6, c = cyan } } do
		k.block(v(e.w, 0.13, 0.1), CFrame.new(e.p), e.c)
	end
	-- "?" block over its head
	local qb = at(0.2, 2.85, -0.1) * CFrame.Angles(0.15, -0.15, 0.1)
	k.block(v(1.2, 1.2, 1.2), qb, rgb(70, 35, 110))
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			k.block(v(0.14, 0.14, 0.05), qb * at(0.48 * x, 0.48 * y, -0.6), pink)
		end
	end
	local q = qb * at(0, 0.02, -0.62)
	for _, p in { { 0, 0.36, 0.44, 0.13 }, { -0.22, 0.22, 0.13, 0.26 }, { 0.22, 0.26, 0.13, 0.13 }, { -0.1, 0.05, 0.14, 0.14 }, { 0, -0.1, 0.13, 0.15 }, { 0, -0.36, 0.13, 0.13 } } do
		k.block(v(p[3], p[4], 0.04), q * at(p[1], p[2], 0), WHITE)
	end
end

S.GameOver = function(k)
	-- the Game Over Goliath wears an arcade cabinet: marquee, a screen that is its face (pixel eyes and
	-- toothy grin), control deck with a joystick and big buttons (its ghost hands on them), coin door,
	-- side art, a wispy tail below and 8-bit hearts orbiting (one already lost)
	local cab = k.color
	local trim = U.Vivid(k.glow)
	local screen = rgb(12, 16, 30)
	k.block(v(4.6, 6.4, 4.0), at(0, 0.3, 0.25), cab)
	k.block(v(4.7, 0.25, 4.1), at(0, -2.95, 0.25), trim)
	-- marquee
	k.block(v(4.9, 1.1, 1.3), at(0, 3.35, -1.25), U.Shade(cab, 0.8))
	k.block(v(3.4, 0.16, 0.06), at(0, 3.4, -1.92), k.glow, NEON)
	for _, x in { -1.9, 1.9 } do
		k.block(v(0.35, 0.35, 0.06), at(x, 3.4, -1.92), rgb(255, 210, 70))
	end
	-- screen face
	k.block(v(4.0, 2.9, 0.2), at(0, 1.35, -1.83), rgb(25, 25, 35))
	local fc = at(0, 1.35, -1.95)
	k.block(v(3.5, 2.45, 0.06), fc, screen)
	for _, s in { -1, 1 } do
		k.block(v(0.6, 0.6, 0.05), fc * at(0.8 * s, 0.45, -0.05), k.glow, NEON)
		k.block(v(0.22, 0.22, 0.05), fc * at(0.8 * s + 0.13, 0.58, -0.08), WHITE)
		k.block(v(0.85, 0.16, 0.05), fc * at(0.78 * s, 1.0, -0.05) * CFrame.Angles(0, 0, 0.35 * s), trim)
	end
	for i = 0, 5 do
		local x = -1.0 + i * 0.4
		local yy = -0.3 - (if i == 0 or i == 5 then -0.15 else 0)
		k.block(v(0.36, 0.34, 0.05), fc * at(x, yy, -0.05), trim)
		if i > 0 and i < 5 then
			k.block(v(0.16, 0.14, 0.05), fc * at(x, yy + 0.08, -0.07), WHITE) -- teeth
		end
	end
	-- control deck with joystick and buttons
	local deck = at(0, -0.3, -2.15) * CFrame.Angles(0.25, 0, 0)
	k.block(v(4.6, 0.45, 1.5), deck, U.Shade(cab, 0.85))
	k.block(v(4.62, 0.12, 0.12), deck * at(0, 0.2, -0.75), trim)
	local js = deck * v(-1.2, 0.22, 0)
	k.cyl(0.12, 0.7, CFrame.new(js) * U.AxisY, rgb(30, 30, 40))
	k.rod(js, js + v(0.12, 0.55, -0.1), 0.14, rgb(30, 30, 40))
	k.ball(0.45, CFrame.new(js + v(0.14, 0.62, -0.12)), rgb(235, 50, 60))
	for i, b in { { x = 0.4, z = 0.25, c = rgb(255, 210, 60) }, { x = 1.05, z = 0.15, c = rgb(80, 220, 255) }, { x = 1.65, z = 0.3, c = rgb(255, 90, 180) }, { x = 0.75, z = -0.35, c = rgb(120, 235, 120) } } do
		k.cyl(0.18, if i == 4 then 0.5 else 0.42, deck * at(b.x, 0.27, b.z) * U.AxisY, b.c)
	end
	-- the ghost's hands on the controls
	local wisp = rgb(225, 215, 255)
	k.ball(0.75, CFrame.new(js + v(0.55, 0.35, -0.05)), wisp)
	k.ball(0.75, deck * at(1.05, 0.55, 0.15), wisp)
	-- coin door
	k.block(v(1.7, 1.5, 0.1), at(0, -1.95, -1.78), U.Shade(cab, 0.7))
	for _, x in { -0.4, 0.4 } do
		k.block(v(0.42, 0.55, 0.06), at(x, -1.75, -1.85), rgb(50, 50, 60), METAL)
		k.block(v(0.08, 0.3, 0.05), at(x, -1.75, -1.89), rgb(255, 150, 60), NEON)
	end
	k.block(v(0.5, 0.25, 0.06), at(0, -2.4, -1.85), rgb(50, 50, 60), METAL)
	-- side art stripes
	for _, s in { -1, 1 } do
		for i = 0, 1 do
			k.block(v(0.06, 0.3, 4.2), at(2.32 * s, 0.6 - i * 0.6, 0.25) * CFrame.Angles(0.55, 0, 0), if i == 0 then trim else rgb(255, 90, 180))
		end
	end
	-- wispy ghost tail below the cabinet
	for i, p in { v(0, -3.35, 0.6), v(0.2, -3.9, 1.0), v(0.35, -4.3, 1.35) } do
		k.ball(1.7 - i * 0.45, CFrame.new(p), wisp)
	end
	-- orbiting 8-bit hearts (the last one is grey: a life already lost)
	for i, h in { { p = v(3.3, 2.3, -1.6), turn = 0.15 }, { p = v(3.6, 0.5, -1.2), turn = -0.1 }, { p = v(-3.4, 1.6, -1.4), turn = -0.15 } } do
		pixelHeart(k, CFrame.new(h.p) * CFrame.Angles(0, h.turn, 0.12 * (i - 2)), 0.26, if i == 3 then rgb(120, 120, 135) else rgb(240, 50, 70))
	end
end

World2b.Styles = S

return World2b
