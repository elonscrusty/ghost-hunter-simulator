--!strict
-- ZONE 4: Abandoned Carnival (Z 880..1220). Bright, candy-striped and only a little spooky.
--   Ground + boardwalk midway along X = 0 (flat paint), painted sawdust rings on the ghost areas
--   ((0,965) r30, (-82,1000) r24, (75,1055) r26, (-62,1115) r24, boss ring (0,1165) r22).
--   Entrance arch at Z 926 (pillars X ±13..19, beam Y 30..38) with two ticket booths.
--   Game stalls along the east side (X 52, Z 948..1006) and one west (X -48, Z 1062),
--   popcorn cart, balloon cart, high striker, prize booth with giant plushies (X ~-96, Z 1058).
--   String lights over the midway between the first ghost area and the boss ring (Z 1005..1130).
--   Landmarks seen from the School: ferris wheel (100, 1182, top ~Y 82), big top (-100, 1180,
--   top ~Y 52) and the carousel (78, 1125).
--   Side walls: red/cream board fence along X ±140..146 with blue posts; outside: hills, a
--   wooden roller coaster and two far tents.
-- Glow is kept to a few bulbs (arch, wheel, carousel, string lights), two lanterns, the striker
-- bell and small purple ectoplasm puddles; everything else is painted wood, fabric and plastic.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Carnival = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local WOOD = Enum.Material.WoodPlanks
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

local MIN_Z, MAX_Z = 880, 1220
local RED = C(225, 60, 70)
local CREAM = C(255, 240, 215)
local YELLOW = C(255, 205, 60)
local BLUE = C(70, 140, 235)
local PURPLE = C(165, 100, 235)
local PINK = C(255, 140, 190)
local MINT = C(120, 220, 150)
local DARK = C(60, 35, 90)
local ECTO = C(200, 130, 255)
local BULB = C(255, 225, 130)
local WOODC = C(190, 135, 90)
local SOLID: Kit.Opts = { Solid = true, Shadow = true }

local function faced(center: Vector3, fx: number, fz: number): CFrame
	return CFrame.new(center) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
end

-- Straight bar between two points in the X/Y plane (wheel rims, spokes, legs).
local function bar(parent: Instance, a: Vector3, b: Vector3, w: number, color: Color3, opts: Kit.Opts?): Part
	local mid = (a + b) / 2
	return Kit.Part(parent, V(w, w, (b - a).Magnitude), CFrame.lookAt(mid, b, V(0, 0, 1)), color, opts)
end

local function glowOpts(glow: boolean): Kit.Opts?
	return if glow then { Mat = NEON } else nil
end

--==================================================================
-- GROUND, WALLS, OUTSIDE
--==================================================================
local function ground(f: Instance)
	-- Same grass as the School slab, which also covers Z 880..920 (no colour flicker there).
	Kit.Box(f, V(-190, -4, MIN_Z), V(190, 0, MAX_Z), C(115, 195, 110), { Mat = Enum.Material.Grass, Solid = true, Name = "Ground_Carnival" })
	-- boardwalk midway with red edges (flat paint)
	Kit.Box(f, V(-9, 0, MIN_Z), V(9, 0.05, MAX_Z), C(220, 170, 120), { Mat = WOOD, Name = "Midway" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 9, 0, MIN_Z), V(s * 10, 0.06, MAX_Z), Kit.Vivid(RED))
	end
	-- sawdust rings on the ghost areas (flat; ghosts float above them)
	local sawdust = C(240, 215, 165)
	Kit.Disc(f, 0, 965, 0.08, 63, 0.04, Kit.Vivid(YELLOW))
	Kit.Disc(f, 0, 965, 0.1, 58, 0.04, sawdust)
	Kit.Disc(f, -82, 1000, 0.08, 51, 0.04, Kit.Vivid(BLUE))
	Kit.Disc(f, -82, 1000, 0.1, 47, 0.04, sawdust)
	Kit.Disc(f, 75, 1055, 0.08, 55, 0.04, Kit.Vivid(PURPLE))
	Kit.Disc(f, 75, 1055, 0.1, 51, 0.04, sawdust)
	Kit.Disc(f, -62, 1115, 0.08, 51, 0.04, Kit.Vivid(BLUE))
	Kit.Disc(f, -62, 1115, 0.1, 47, 0.04, sawdust)
	-- boss: circus ring
	Kit.Disc(f, 0, 1165, 0.08, 47, 0.04, Kit.Vivid(RED))
	Kit.Disc(f, 0, 1165, 0.1, 42, 0.04, CREAM)
	Kit.Disc(f, 0, 1165, 0.12, 14, 0.04, Kit.Vivid(YELLOW))
	-- small purple ectoplasm puddles (flat neon accents)
	for _, p in { V(12, 0, 975), V(-75, 0, 1010), V(82, 0, 1046), V(-55, 0, 1122), V(-9, 0, 1172) } do
		Kit.Disc(f, p.X, p.Z, 0.16, 5, 0.04, ECTO, { Mat = NEON, Transp = 0.2 })
	end
end

local function sideWalls(f: Instance)
	-- red/cream board fence, leaving Z MinZ..MinZ+3 and MaxZ-3..MaxZ for the gate walls
	local z0, z1 = MIN_Z + 3, MAX_Z - 3
	local n = 16
	local step = (z1 - z0) / n
	local post = Kit.Vivid(BLUE)
	local ball = Kit.Vivid(YELLOW)
	for _, s in { -1, 1 } do
		for i = 0, n - 1 do
			local a = z0 + i * step
			Kit.Box(f, V(s * 140, 0, a), V(s * 146, 12, a + step), if i % 2 == 0 then Kit.Vivid(RED) else CREAM, { Mat = WOOD, Solid = true })
		end
		Kit.Box(f, V(s * 139.5, 12, z0), V(s * 146.5, 13, z1), ball, { Mat = WOOD })
		for i = 2, n - 2, 2 do
			local z = z0 + i * step
			Kit.Box(f, V(s * 139, 0, z - 2.5), V(s * 147, 15, z + 2.5), post, SOLID)
			Kit.Ball(f, 4, V(s * 143, 17, z), ball)
		end
	end
end

-- Round tent: fabric drum + stacked striped tiers + flag. Door faces the midway.
local function tent(f: Instance, x: number, z: number, d: number, c1: Color3, c2: Color3)
	local m = Kit.Model(f, "Tent")
	local fx = if x > 0 then -1 else 1
	Kit.Cyl(m, 8, d, CFrame.new(x, 4, z), c2, { Mat = FABRIC, Solid = true, Shadow = true })
	Kit.Part(m, V(1.6, 7, d * 0.3), CFrame.new(x + fx * (d / 2 - 0.6), 3.5, z), DARK)
	local sizes = { 1.12, 0.86, 0.6, 0.34 }
	for i, k in sizes do
		Kit.Disc(m, x, z, 8 + i * 2.2, d * k, 2.2, if i % 2 == 1 then c1 else c2, { Mat = FABRIC, Shadow = true })
	end
	Kit.Cyl(m, 3, 0.4, CFrame.new(x, 18.3, z), CREAM)
	Kit.Ball(m, 1.3, V(x, 20, z), Kit.Vivid(YELLOW))
	Kit.Box(m, V(x - 0.1, 18.4, z), V(x + 0.1, 19.8, z + 2.4), c1)
	Kit.AddCircle(x, z, d / 2 + 1.5)
end

local function outside(f: Instance)
	local hill = { C(120, 90, 190), C(100, 150, 120), C(150, 100, 200) }
	for i, z in { 935, 1050, 1165 } do
		for _, s in { -1, 1 } do
			Kit.Ball(f, 70, V(s * 188, -14, z + s * 12), hill[(i + (if s > 0 then 1 else 0)) % #hill + 1], { Mat = Enum.Material.Grass })
		end
	end
	-- wooden roller coaster beyond the east wall
	local heights = { 12, 26, 34, 22, 14, 28, 20, 12 }
	local prev: Vector3? = nil
	for i, h in heights do
		local z = 975 + (i - 1) * 22
		Kit.Box(f, V(171.4, 0, z - 0.6), V(172.6, h, z + 0.6), CREAM, { Mat = WOOD })
		local top = V(172, h + 0.4, z)
		if prev then
			Props.Beam(f, prev, top, 2.6, 0.8, Kit.Vivid(RED))
		end
		prev = top
	end
	-- far tents beyond the west wall
	tent(f, -170, 990, 22, Kit.Vivid(RED), CREAM)
	tent(f, -172, 1105, 20, Kit.Vivid(BLUE), Kit.Vivid(YELLOW))
	for _, z in { 905, 1205 } do
		for _, s in { -1, 1 } do
			Props.Tree(f, V(s * 158, 0, z), 22 + Kit.Rng:NextNumber(0, 8), Kit.Pick({ C(255, 140, 50), C(170, 90, 230), C(255, 110, 90) }))
		end
	end
end

--==================================================================
-- ENTRANCE
--==================================================================
local function entranceArch(f: Instance)
	local m = Kit.Model(f, "CarnivalArch")
	local z = 926
	for _, s in { -1, 1 } do
		for i = 0, 5 do
			Kit.Box(m, V(s * 13, i * 6, z - 3), V(s * 19, i * 6 + 6, z + 3), if i % 2 == 0 then Kit.Vivid(RED) else CREAM, SOLID)
		end
		Kit.Box(m, V(s * 12.4, 0, z - 3.6), V(s * 19.6, 2.5, z + 3.6), Kit.Vivid(BLUE), SOLID)
		Kit.Cyl(m, 4, 8, CFrame.new(s * 16, 40, z), Kit.Vivid(YELLOW))
		Kit.Ball(m, 4.5, V(s * 16, 44, z), Kit.Vivid(RED))
		Kit.AddRect(s * 12, z - 4, s * 20.5, z + 4)
	end
	-- beam (bottom Y 30) + round crest
	Kit.Box(m, V(-22, 30, z - 3.5), V(22, 38, z + 3.5), Kit.Vivid(BLUE), SOLID)
	Kit.CylFlat(m, 3, 20, V(0, 40, z), "Z", Kit.Vivid(YELLOW))
	Kit.Ball(m, 4, V(0, 52, z), Kit.Vivid(RED))
	local sign = Kit.Part(m, V(38, 6, 0.4), CFrame.new(0, 34, z - 3.75), DARK)
	Kit.Sign(sign, Enum.NormalId.Front, "🎪 SPOOKY CARNIVAL 🎪", Kit.Vivid(YELLOW))
	local back = Kit.Part(m, V(30, 4.4, 0.4), CFrame.new(0, 34, z + 3.75) * CFrame.Angles(0, math.pi, 0), DARK)
	Kit.Sign(back, Enum.NormalId.Front, "COME BACK SOON... 👻", CREAM)
	-- bulbs under the beam (every other one glows)
	for i = 0, 8 do
		local glow = i % 2 == 0
		local b = Kit.Ball(m, 1.6, V(-18 + i * 4.5, 29.6, z - 3.6), if glow then BULB else Kit.Vivid(RED), glowOpts(glow))
		if i == 4 then
			Kit.Light(b, C(255, 210, 140), 26, 1.4)
		end
	end
	-- giant "ADMIT ONE" ticket by the gate
	local t = Kit.Part(m, V(12, 5, 0.6), CFrame.new(-62, 3.2, 905) * CFrame.Angles(0, 0.3, 0.1), Kit.Vivid(YELLOW))
	Kit.Sign(t, Enum.NormalId.Front, "ADMIT ONE\n👻 BOO 👻", Kit.Vivid(RED), { Stroke = CREAM })
	Kit.Box(m, V(-62.5, 0, 904.5), V(-61.5, 1, 905.5), WOODC)
	Kit.AddCircle(-62, 905, 7)
end

local function ticketBooth(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "TicketBooth")
	local fx = if x > 0 then -1 else 1
	local base = faced(V(x, 0, z), fx, 0)
	Kit.Part(m, V(7, 8, 6), base * CFrame.new(0, 4, 0), Kit.Vivid(RED), { Mat = WOOD, Solid = true, Shadow = true })
	Kit.Part(m, V(7.4, 1, 6.4), base * CFrame.new(0, 1.5, 0), CREAM)
	Kit.Part(m, V(4.4, 3, 0.3), base * CFrame.new(0, 5, -3.05), C(255, 235, 175))
	Kit.Part(m, V(5.6, 0.5, 1.4), base * CFrame.new(0, 3.3, -3.5), CREAM)
	local sign = Kit.Part(m, V(6.6, 1.5, 0.4), base * CFrame.new(0, 7.3, -3.15), DARK)
	Kit.Sign(sign, Enum.NormalId.Front, "🎟️ TICKETS", Kit.Vivid(YELLOW))
	Kit.Part(m, V(8.4, 1, 7.4), base * CFrame.new(0, 8.5, 0), Kit.Vivid(YELLOW))
	Kit.Cyl(m, 1.6, 7, CFrame.new(x, 9.8, z), Kit.Vivid(RED))
	Kit.Cyl(m, 1.6, 5, CFrame.new(x, 11.4, z), CREAM)
	Kit.Cyl(m, 1.6, 3, CFrame.new(x, 13, z), Kit.Vivid(RED))
	Kit.Ball(m, 1.4, V(x, 14.4, z), Kit.Vivid(YELLOW))
	Kit.AddCircle(x, z, 6)
end

--==================================================================
-- LANDMARKS
--==================================================================
local function ferrisWheel(f: Instance)
	local m = Kit.Model(f, "FerrisWheel")
	local cx, cy, cz = 100, 47, 1182
	local R, N = 34, 20
	Kit.Box(m, V(70, 0, 1170), V(130, 1, 1194), WOODC, { Mat = WOOD, Solid = true })
	local function rim(a: number, dz: number): Vector3
		return V(cx + math.cos(a) * R, cy + math.sin(a) * R, cz + dz)
	end
	local rimCol = Kit.Vivid(RED)
	for _, dz in { -3, 3 } do
		for i = 0, N - 1 do
			bar(m, rim(i / N * math.pi * 2, dz), rim((i + 1) / N * math.pi * 2, dz), 1.2, rimCol, { Mat = METAL })
		end
		for i = 0, 4 do
			local a = i / 5 * math.pi
			bar(m, rim(a, dz), rim(a + math.pi, dz), 0.7, CREAM)
		end
	end
	local hub = Kit.CylFlat(m, 9, 5, V(cx, cy, cz), "Z", Kit.Vivid(YELLOW))
	Kit.CylFlat(m, 10, 2, V(cx, cy, cz), "Z", Kit.Vivid(PURPLE))
	Kit.Light(hub, C(255, 200, 150), 34, 1.3)
	-- A-frame legs + braces
	local leg = C(240, 240, 250)
	for _, dz in { -6, 6 } do
		for _, sx in { -1, 1 } do
			bar(m, V(cx + sx * 22, 1, cz + dz), V(cx, cy, cz + dz * 0.6), 1.6, leg, { Mat = METAL, Solid = true })
		end
		Kit.Box(m, V(cx - 15, 15.5, cz + dz * 0.87 - 0.5), V(cx + 15, 16.5, cz + dz * 0.87 + 0.5), Kit.Vivid(BLUE))
	end
	-- gondolas hang from the spoke ends
	local cabs = { Kit.Vivid(BLUE), Kit.Vivid(YELLOW), Kit.Vivid(MINT), Kit.Vivid(PURPLE), Kit.Vivid(PINK) }
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = V(cx + math.cos(a) * R, cy + math.sin(a) * R, cz)
		Kit.CylFlat(m, 6.4, 0.6, p, "Z", C(200, 200, 215))
		Kit.Box(m, p + V(-0.2, -3, -0.2), p + V(0.2, 0, 0.2), C(200, 200, 215))
		Kit.Box(m, p + V(-2.6, -7.2, -2.2), p + V(2.6, -3, 2.2), cabs[i % #cabs + 1], { Shadow = true })
		Kit.Disc(m, p.X, p.Z, p.Y - 2.2, 6.2, 0.8, CREAM)
	end
	-- bulbs between the gondolas on the front rim (half glow)
	for i = 0, 9 do
		local glow = i % 2 == 0
		Kit.Ball(m, 1.8, rim((i + 0.5) / 10 * math.pi * 2, -3.8), if glow then BULB else Kit.Vivid(YELLOW), glowOpts(glow))
	end
	Props.SignBoard(m, V(cx, 6, 1167.5), 16, 3, 0, -1, "🎡 BOO-RIS WHEEL", DARK, Kit.Vivid(YELLOW), RED)
	for _, sx in { -7, 7 } do
		Kit.Box(m, V(cx + sx - 0.4, 0, 1167.4), V(cx + sx + 0.4, 4.5, 1168.2), CREAM)
	end
	Kit.AddRect(66, 1163, 136, 1197)
end

local function carousel(f: Instance)
	local m = Kit.Model(f, "Carousel")
	local cx, cz = 78, 1125
	Kit.Disc(m, cx, cz, 0.6, 32, 0.6, Kit.Vivid(RED), { Solid = true })
	Kit.Disc(m, cx, cz, 1.2, 29, 0.6, CREAM, { Mat = WOOD, Solid = true })
	local column = Kit.Cyl(m, 13, 5, CFrame.new(cx, 7.7, cz), Kit.Vivid(YELLOW), SOLID)
	Kit.Light(column, C(255, 215, 150), 24, 1.2)
	local horses = { CREAM, Kit.Vivid(PINK), Kit.Vivid(C(150, 200, 255)), Kit.Vivid(MINT) }
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local px, pz = cx + math.cos(a) * 10, cz + math.sin(a) * 10
		Kit.Cyl(m, 13, 0.5, CFrame.new(px, 7.7, pz), C(255, 215, 120), { Mat = METAL })
		local base = faced(V(px, 5 + (i % 2) * 1.5, pz), -math.sin(a), math.cos(a))
		local col = horses[i % #horses + 1]
		Kit.Part(m, V(1.6, 1.8, 4.2), base, col)
		Kit.Part(m, V(1.3, 2.6, 1.5), base * CFrame.new(0, 1.6, -2) * CFrame.Angles(0.35, 0, 0), col)
		Kit.Part(m, V(1.2, 2.2, 3.4), base * CFrame.new(0, -1.9, 0), col:Lerp(C(0, 0, 0), 0.15))
	end
	-- striped roof: valance + 12 wedge panels
	Kit.Cyl(m, 2, 32, CFrame.new(cx, 15, cz), CREAM, { Mat = FABRIC })
	local L, h = 16, 7
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * math.pi * 2
		local dx, dz = math.cos(a), math.sin(a)
		local cf = CFrame.new(cx + dx * L / 2, 16 + h / 2, cz + dz * L / 2) * CFrame.Angles(0, Kit.FaceYaw(dx, dz), 0)
		Kit.Wedge(m, V(8.8, h, L), cf, if i % 2 == 0 then Kit.Vivid(RED) else CREAM, { Mat = FABRIC, Shadow = true })
	end
	Kit.Cyl(m, 2, 3, CFrame.new(cx, 24, cz), Kit.Vivid(YELLOW))
	Kit.Ball(m, 2.6, V(cx, 26, cz), Kit.Vivid(BLUE))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local glow = i % 2 == 0
		Kit.Ball(m, 1.3, V(cx + math.cos(a) * 16.2, 15, cz + math.sin(a) * 16.2), if glow then BULB else Kit.Vivid(BLUE), glowOpts(glow))
	end
	Props.SignBoard(m, V(58.5, 7, cz), 12, 2.6, -1, 0, "🎠 MERRY-GO-BOO", DARK, Kit.Vivid(YELLOW), BLUE)
	for _, dz in { -5, 5 } do
		Kit.Box(m, V(58.2, 0, cz + dz - 0.4), V(59, 5.7, cz + dz + 0.4), CREAM)
	end
	Kit.AddCircle(cx, cz, 17)
	Kit.AddCircle(58.5, cz, 7)
end

local function bigTop(f: Instance)
	local m = Kit.Model(f, "BigTop")
	local cx, cz = -100, 1180
	Kit.Cyl(m, 16, 44, CFrame.new(cx, 8, cz), CREAM, { Mat = FABRIC, Solid = true, Shadow = true })
	Kit.Cyl(m, 2, 44.6, CFrame.new(cx, 2, cz), Kit.Vivid(RED), { Mat = FABRIC })
	for i, d in { 48, 40, 32, 24, 16, 8 } do
		Kit.Disc(m, cx, cz, 16 + i * 4, d, 4, if i % 2 == 1 then Kit.Vivid(RED) else CREAM, { Mat = FABRIC, Shadow = true })
	end
	Kit.Cyl(m, 10, 1, CFrame.new(cx, 45, cz), C(240, 240, 250))
	Kit.Ball(m, 2.2, V(cx, 50.6, cz), Kit.Vivid(YELLOW))
	local flag = Kit.Box(m, V(cx + 0.5, 44, cz - 0.1), V(cx + 8.5, 48.5, cz + 0.1), Kit.Vivid(PURPLE))
	Kit.Sign(flag, Enum.NormalId.Front, "BOO", CREAM)
	-- doorway toward the midway (+X)
	local door = Kit.Box(m, V(cx + 20.5, 0, cz - 6), V(cx + 22.4, 13, cz + 6), DARK)
	Kit.Light(door, ECTO, 22, 1.2)
	for _, dz in { -1, 1 } do
		Kit.Part(m, V(0.6, 13, 3.2), CFrame.new(cx + 22.7, 6.5, cz + dz * 5.4) * CFrame.Angles(0, 0, dz * 0.08), Kit.Vivid(RED), { Mat = FABRIC })
	end
	Props.SignBoard(m, V(cx + 23.2, 14.2, cz), 18, 3.5, 1, 0, "🎪 THE BIG TOP", DARK, Kit.Vivid(YELLOW), RED)
	Kit.AddCircle(cx, cz, 25)
	Props.Wisp(f, V(-68, 0, cz), ECTO, 10, true)
	Kit.AddCircle(-68, cz, 5)
end

--==================================================================
-- STALLS, BOOTHS, CARTS
--==================================================================
local function stall(f: Instance, x: number, z: number, color: Color3, title: string)
	local m = Kit.Model(f, "GameStall")
	local fx = if x > 0 then -1 else 1
	local base = faced(V(x, 0, z), fx, 0)
	local col = Kit.Vivid(color)
	Kit.Part(m, V(12, 10, 1), base * CFrame.new(0, 5, 3.5), col, { Mat = WOOD, Solid = true, Shadow = true })
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(1, 10, 8), base * CFrame.new(sx * 5.5, 5, 0), CREAM, { Mat = WOOD, Solid = true })
	end
	Kit.Part(m, V(10, 3.5, 1.6), base * CFrame.new(0, 1.75, -3.2), CREAM, { Mat = WOOD, Solid = true })
	Kit.Part(m, V(10.2, 0.5, 2), base * CFrame.new(0, 3.75, -3.2), col)
	for i = 0, 3 do
		local cf = base * CFrame.new(-4.875 + i * 3.25, 11, -1) * CFrame.Angles(-0.25, 0, 0)
		Kit.Part(m, V(3.25, 0.5, 10), cf, if i % 2 == 0 then col else CREAM, { Mat = FABRIC })
	end
	Kit.Part(m, V(10, 0.5, 1.4), base * CFrame.new(0, 5.5, 2.4), CREAM)
	local prizes = { Kit.Vivid(PINK), Kit.Vivid(YELLOW), Kit.Vivid(MINT) }
	for i = 0, 2 do
		Kit.Ball(m, 1.9, (base * CFrame.new(-3 + i * 3, 6.7, 2.4)).Position, prizes[i + 1])
	end
	local sign = Kit.Part(m, V(10, 2.4, 0.5), base * CFrame.new(0, 13.6, 3.2), DARK)
	Kit.Sign(sign, Enum.NormalId.Front, title, Kit.Vivid(YELLOW))
	Kit.AddCircle(x, z, 8)
end

local function plushBear(parent: Instance, pos: Vector3, s: number, color: Color3, fx: number, fz: number)
	local base = faced(pos, fx, fz)
	Kit.Ball(parent, s, (base * CFrame.new(0, s * 0.45, 0)).Position, color, { Mat = FABRIC })
	local head = base * CFrame.new(0, s * 1.15, 0)
	Kit.Ball(parent, s * 0.75, head.Position, color, { Mat = FABRIC })
	for _, sx in { -1, 1 } do
		Kit.Ball(parent, s * 0.28, (head * CFrame.new(sx * s * 0.3, s * 0.3, 0)).Position, color, { Mat = FABRIC })
		Kit.Ball(parent, s * 0.1, (head * CFrame.new(sx * s * 0.14, s * 0.06, -s * 0.34)).Position, C(40, 30, 50))
	end
	Kit.Ball(parent, s * 0.28, (head * CFrame.new(0, -s * 0.1, -s * 0.3)).Position, CREAM)
	Kit.Part(parent, V(s * 0.5, s * 0.22, s * 0.15), base * CFrame.new(0, s * 0.85, -s * 0.38), Kit.Vivid(RED))
end

local function plushGhost(parent: Instance, pos: Vector3, s: number)
	Kit.Cyl(parent, s * 0.6, s, CFrame.new(pos + V(0, s * 0.3, 0)), CREAM, { Mat = FABRIC })
	Kit.Ball(parent, s, pos + V(0, s * 0.7, 0), CREAM, { Mat = FABRIC })
	for _, sz in { -1, 1 } do
		Kit.Ball(parent, s * 0.14, pos + V(s * 0.44, s * 0.8, sz * s * 0.16), C(40, 30, 50))
		Kit.Ball(parent, s * 0.12, pos + V(s * 0.42, s * 0.62, sz * s * 0.3), Kit.Vivid(PINK))
	end
end

local function prizeBooth(f: Instance)
	local m = Kit.Model(f, "PrizeBooth")
	Kit.Box(m, V(-106, 0, 1045), V(-86, 1, 1071), WOODC, { Mat = WOOD, Solid = true })
	Kit.Box(m, V(-108, 0, 1044), V(-106, 16, 1072), Kit.Vivid(BLUE), { Mat = WOOD, Solid = true })
	for _, z in { 1045, 1071 } do
		Kit.Box(m, V(-87, 1, z - 0.6), V(-85.8, 15, z + 0.6), Kit.Vivid(YELLOW), SOLID)
	end
	Kit.Box(m, V(-108, 15, 1044), V(-84, 17, 1072), Kit.Vivid(RED), { Mat = WOOD })
	local valance = Kit.Box(m, V(-84.4, 13, 1044), V(-84, 15, 1072), CREAM)
	Kit.Sign(valance, Enum.NormalId.Right, "🧸 PRIZES! 🧸", Kit.Vivid(RED), { Stroke = CREAM })
	Kit.Box(m, V(-106, 1, 1047), V(-100, 4, 1069), CREAM, { Mat = WOOD, Solid = true })
	plushBear(m, V(-102.5, 4, 1058), 7, Kit.Vivid(PINK), 1, 0)
	plushBear(m, V(-95, 1, 1050), 5, Kit.Vivid(C(150, 200, 255)), 1, 0)
	plushGhost(m, V(-95, 1, 1066), 5)
	Kit.AddRect(-109, 1043, -83, 1073)
end

local function popcorn(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "PopcornCart")
	Kit.Box(m, V(x - 3, 1.2, z - 2.2), V(x + 3, 4.6, z + 2.2), Kit.Vivid(RED), { Solid = true })
	Kit.Box(m, V(x - 3.1, 3.2, z - 2.3), V(x + 3.1, 3.8, z + 2.3), CREAM)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.CylFlat(m, 0.5, 2.4, V(x + sx * 1.8, 1.2, z + sz * 2.4), "Z", DARK)
		end
	end
	local glass = Kit.Box(m, V(x - 2.8, 4.6, z - 2), V(x + 2.8, 8.6, z + 2), C(220, 240, 255), { Transp = 0.5, Refl = 0.1 })
	Kit.Light(glass, C(255, 220, 150), 20, 1.2)
	for i = 0, 2 do
		Kit.Ball(m, 2.4, V(x - 1.4 + i * 1.4, 5.8 + (i % 2) * 0.6, z), C(255, 240, 190))
	end
	Kit.Box(m, V(x - 3.4, 8.6, z - 2.6), V(x + 3.4, 9.2, z + 2.6), Kit.Vivid(RED))
	Kit.Cyl(m, 1.4, 4, CFrame.new(x, 9.9, z), CREAM)
	Kit.Box(m, V(x - 0.2, 10.6, z - 0.2), V(x + 0.2, 11.7, z + 0.2), CREAM)
	local sign = Kit.Part(m, V(6, 1.8, 0.4), faced(V(x + 0.2, 12.6, z), 1, 0), Kit.Vivid(YELLOW))
	Kit.Sign(sign, Enum.NormalId.Front, "🍿 POPCORN", Kit.Vivid(RED), { Stroke = CREAM })
	Kit.AddCircle(x, z, 5)
end

local function balloonCart(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "BalloonCart")
	Kit.Box(m, V(x - 2, 1, z - 1.5), V(x + 2, 4, z + 1.5), Kit.Vivid(BLUE), { Solid = true })
	Kit.Box(m, V(x - 2.2, 4, z - 1.7), V(x + 2.2, 4.4, z + 1.7), Kit.Vivid(YELLOW))
	for _, sz in { -1, 1 } do
		Kit.CylFlat(m, 0.4, 2.2, V(x, 1.1, z + sz * 1.7), "Z", DARK)
	end
	local cols = { RED, YELLOW, BLUE, PURPLE, PINK, MINT, CREAM }
	local top = V(x, 4.4, z)
	for i, col in cols do
		local a = i / #cols * math.pi * 2
		local p = V(x + math.cos(a) * 2.4, 11 + (i % 3) * 1.4, z + math.sin(a) * 2.4)
		Props.Beam(m, top, p - V(0, 1.4, 0), 0.1, 0.1, C(245, 245, 245))
		Kit.Ball(m, 2.8, p, Kit.Vivid(col), { Refl = 0.05 })
	end
	Kit.AddCircle(x, z, 5)
end

local function highStriker(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "HighStriker")
	Kit.Box(m, V(x - 3, 0, z - 3), V(x + 3, 1, z + 3), Kit.Vivid(RED), { Mat = WOOD, Solid = true })
	Kit.Box(m, V(x - 0.8, 1, z - 0.8), V(x + 0.8, 25, z + 0.8), CREAM, { Mat = WOOD, Solid = true })
	for i, col in { YELLOW, BLUE, RED } do
		local y = 2 + i * 6
		Kit.Box(m, V(x + 0.8, y, z - 1), V(x + 1, y + 3, z + 1), Kit.Vivid(col))
	end
	Kit.Ball(m, 2.6, V(x, 26.3, z), C(255, 230, 120), { Mat = NEON })
	Kit.Box(m, V(x + 0.8, 11, z - 0.5), V(x + 1.6, 12, z + 0.5), DARK)
	Kit.Box(m, V(x + 1, 1, z - 0.8), V(x + 2.8, 1.4, z + 0.8), Kit.Vivid(YELLOW))
	-- giant mallet leaning on the tower
	Props.Beam(m, V(x + 3.5, 0.2, z + 3), V(x + 1.5, 7, z + 3.6), 0.6, 0.6, WOODC)
	Kit.Part(m, V(3, 1.8, 1.8), CFrame.new(x + 1.4, 7.4, z + 3.6), Kit.Vivid(RED))
	Props.SignBoard(m, V(x + 1.2, 4.6, z), 5, 2.2, 1, 0, "BOO-O-METER", DARK, Kit.Vivid(YELLOW))
	Kit.AddCircle(x, z, 5)
end

--==================================================================
-- STREET FURNITURE + DECOR
--==================================================================
local function bench(f: Instance, x: number, z: number, fx: number, fz: number)
	local base = faced(V(x, 0, z), fx, fz)
	Kit.Part(f, V(6, 0.6, 2.2), base * CFrame.new(0, 2, 0), WOODC, { Mat = WOOD, Solid = true })
	Kit.Part(f, V(6, 2.4, 0.5), base * CFrame.new(0, 3.6, 1), WOODC, { Mat = WOOD })
	for _, sx in { -1, 1 } do
		Kit.Part(f, V(0.5, 2, 2), base * CFrame.new(sx * 2.6, 1, 0), Kit.Vivid(RED))
	end
	Kit.AddCircle(x, z, 3.5)
end

local function fence(f: Instance, a: Vector3, b: Vector3)
	local d = b - a
	local len = d.Magnitude
	local dir = d.Unit
	local yaw = Kit.FaceYaw(dir.X, dir.Z)
	for _, ry in { 1.2, 2.8 } do
		Kit.Part(f, V(0.3, 0.5, len), CFrame.new(a + d / 2 + V(0, ry, 0)) * CFrame.Angles(0, yaw, 0), Kit.Vivid(RED), { Mat = WOOD })
	end
	local n = math.max(1, math.floor(len / 4))
	for i = 0, n do
		local p = a + dir * (i * len / n)
		Kit.Box(f, p + V(-0.35, 0, -0.35), p + V(0.35, 3.8, 0.35), CREAM, { Mat = WOOD })
	end
	Kit.AddRect(math.min(a.X, b.X) - 1, math.min(a.Z, b.Z) - 1, math.max(a.X, b.X) + 1, math.max(a.Z, b.Z) + 1)
end

local function stringLights(f: Instance)
	local zs = { 1005, 1030, 1055, 1080, 1105, 1130 }
	local top = 17.5
	local cols = { Kit.Vivid(RED), Kit.Vivid(YELLOW), Kit.Vivid(BLUE), CREAM }
	for _, z in zs do
		for _, s in { -1, 1 } do
			Kit.Cyl(f, top + 0.5, 0.7, CFrame.new(s * 13, (top + 0.5) / 2, z), C(150, 100, 70), { Mat = WOOD })
			Kit.Ball(f, 1.4, V(s * 13, top + 0.9, z), Kit.Vivid(YELLOW))
			Kit.AddCircle(s * 13, z, 1.5)
		end
	end
	local nb = 0
	local lit = false
	local function wire(a: Vector3, b: Vector3)
		local mid = (a + b) / 2 - V(0, 2, 0)
		Props.Beam(f, a, mid, 0.15, 0.15, DARK)
		Props.Beam(f, mid, b, 0.15, 0.15, DARK)
		for k = 1, 4 do
			local t = k / 5
			local sag = 2 * (1 - math.abs(2 * t - 1))
			local p = a:Lerp(b, t) - V(0, sag + 0.5, 0)
			nb += 1
			local glow = nb % 4 == 0
			local bulb = Kit.Ball(f, 0.9, p, if glow then BULB else cols[nb % #cols + 1], glowOpts(glow))
			if glow and not lit then
				lit = true
				Kit.Light(bulb, C(255, 215, 150), 30, 1.1)
			end
		end
	end
	for i, z in zs do
		wire(V(-13, top, z), V(13, top, z))
		local nextZ = zs[i + 1]
		if nextZ then
			local s = if i % 2 == 1 then 1 else -1
			wire(V(-13 * s, top, z), V(13 * s, top, nextZ))
		end
	end
end

local function lollipop(f: Instance, x: number, z: number, color: Color3)
	Kit.Cyl(f, 12, 0.8, CFrame.new(x, 6, z), CREAM)
	Kit.CylFlat(f, 1.2, 7, V(x, 14, z), "Z", Kit.Vivid(color))
	Kit.CylFlat(f, 1.4, 4, V(x, 14, z), "Z", CREAM)
	Kit.CylFlat(f, 1.6, 1.6, V(x, 14, z), "Z", Kit.Vivid(color))
	Kit.AddCircle(x, z, 2)
end

local function circusBall(f: Instance, x: number, z: number, color: Color3, band: Color3)
	Kit.Ball(f, 6, V(x, 3, z), Kit.Vivid(color), { Solid = true })
	Kit.CylFlat(f, 1.4, 6.15, V(x, 3, z), "X", band)
	Kit.AddCircle(x, z, 3.5)
end

type BallSpot = { P: Vector3, Col: Color3, Band: Color3 }

local function decor(f: Instance)
	local rng = Kit.Rng
	-- benches between the string-light poles
	local benches = 0
	for _, z in { 1017, 1042, 1067, 1092, 1117 } do
		for _, s in { -1, 1 } do
			if benches < 7 and Kit.IsFree(s * 16.5, z, 3.5) then
				benches += 1
				bench(f, s * 16.5, z, -s, 0)
			end
		end
	end
	-- wooden fencing
	fence(f, V(68, 0, 1164), V(92, 0, 1164))
	fence(f, V(-124, 0, 1150), V(-78, 0, 1150))
	fence(f, V(128, 0, 1030), V(128, 0, 1078))
	-- lanterns flanking the boss ring (one flickers)
	Props.Lantern(f, V(-26, 0, 1142), C(200, 150, 255), true, true)
	Props.Lantern(f, V(26, 0, 1142), C(255, 220, 140), true, false)
	Kit.AddCircle(-26, 1142, 1.5)
	Kit.AddCircle(26, 1142, 1.5)
	-- oversized decorations
	local lolly = { RED, BLUE, PURPLE, PINK }
	for i, p in { V(-60, 0, 936), V(40, 0, 938), V(-125, 0, 1020), V(122, 0, 1092) } do
		if Kit.IsFree(p.X, p.Z, 2) then
			lollipop(f, p.X, p.Z, lolly[i])
		end
	end
	local balls: { BallSpot } = {
		{ P = V(34, 0, 1036), Col = RED, Band = CREAM },
		{ P = V(-30, 0, 1035), Col = BLUE, Band = Kit.Vivid(YELLOW) },
		{ P = V(112, 0, 1100), Col = PURPLE, Band = CREAM },
	}
	for _, b in balls do
		if Kit.IsFree(b.P.X, b.P.Z, 3.5) then
			circusBall(f, b.P.X, b.P.Z, b.Col, b.Band)
		end
	end
	-- floating balloons (single parts, client-animated)
	local fl = { RED, YELLOW, BLUE, PURPLE, PINK }
	for i, p in { V(36, 19, 1078), V(24, 22, 1090), V(-36, 18, 1040), V(60, 24, 940), V(-40, 22, 1150) } do
		local b = Kit.Ball(f, 3, p, Kit.Vivid(fl[i]), { Name = "FloatingBalloon" })
		Kit.Float(b, 1.2)
	end
	-- candy trees near the walls
	local trees = 0
	for _ = 1, 120 do
		if trees >= 6 then
			break
		end
		local x = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(100, 131)
		local z = rng:NextNumber(905, 1150)
		if Kit.IsFree(x, z, 5) then
			trees += 1
			Props.Tree(f, V(x, 0, z), rng:NextNumber(12, 17), Kit.Pick({ C(255, 140, 50), C(170, 90, 230), C(255, 110, 90) }))
		end
	end
	-- wooden crates and pumpkins scattered around the grounds
	local crates, pumpkins = 0, 0
	for _ = 1, 300 do
		if crates >= 7 and pumpkins >= 6 then
			break
		end
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(908, 1212)
		if Kit.IsFree(x, z, 3) then
			if crates < 7 then
				crates += 1
				local s = rng:NextNumber(2.6, 3.8)
				local cf = CFrame.new(x, s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
				Kit.Part(f, V(s, s, s), cf, Kit.Pick({ WOODC, C(170, 115, 75), C(205, 160, 110) }), { Mat = WOOD, Solid = true })
			else
				pumpkins += 1
				Props.Pumpkin(f, V(x, 0, z), rng:NextNumber(2.4, 3.4), -x, 0)
			end
			Kit.AddCircle(x, z, 3)
		end
	end
end

function Carnival.Build(map: Instance)
	local f = Kit.Folder(map, "Carnival")
	ground(f)
	sideWalls(f)
	outside(f)
	entranceArch(f)
	ticketBooth(f, -46, 930)
	ticketBooth(f, 46, 930)
	ferrisWheel(f)
	carousel(f)
	bigTop(f)
	prizeBooth(f)
	-- striped tents (door toward the midway)
	tent(f, -112, 936, 16, Kit.Vivid(RED), CREAM)
	tent(f, -80, 950, 13, Kit.Vivid(BLUE), Kit.Vivid(YELLOW))
	tent(f, 118, 952, 16, Kit.Vivid(BLUE), Kit.Vivid(YELLOW))
	tent(f, 115, 1005, 14, Kit.Vivid(RED), CREAM)
	tent(f, -122, 1110, 14, Kit.Vivid(RED), CREAM)
	tent(f, 40, 1180, 12, Kit.Vivid(BLUE), Kit.Vivid(YELLOW))
	tent(f, -45, 1185, 12, Kit.Vivid(RED), CREAM)
	-- game stalls
	stall(f, 52, 948, BLUE, "RING TOSS")
	stall(f, 52, 977, PURPLE, "DUCK POND")
	stall(f, 52, 1006, RED, "BOO BALLOONS")
	stall(f, -48, 1062, YELLOW, "WHACK-A-GHOST")
	popcorn(f, -40, 958)
	balloonCart(f, 30, 1085)
	highStriker(f, -28, 1078)
	Props.Wisp(f, V(58, 0, 1158), ECTO, 10, true)
	Kit.AddCircle(58, 1158, 5)
	stringLights(f)
	decor(f)
end

return Carnival
