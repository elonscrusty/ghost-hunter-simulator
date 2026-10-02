--!strict
-- ZONE 13: Sunken City (Z 4120..4480). Atlantis ruins on a sandy sea floor you can walk on.
--   Ground: sand slab + pale marble-tile avenue along X = 0 (flat, teal edging).
--   Ghost areas get flat mosaic discs ((0,4205) r30, (-82,4240) r24, (75,4300) r26,
--   (-62,4360) r24, boss (0,4425) r26 with a gold trident star).
--   Atlantis gate arch over the avenue at Z 4168 (beam bottom Y 30).
--   Landmark seen from the Toy Factory: domed temple (-100, 4432), trident tip ~Y 102.
--   Sunken ship bow (east back corner), giant clams, coral reefs, kelp, broken columns,
--   treasure chests and flat starfish. A translucent water surface floats at Y 120
--   (no collision) with a few soft light shafts.
--   Side walls: teal reef rock (X +-140..146) topped with coral; outside: reef hills, coral
--   spires and kelp forests.
-- Glow: temple pearl, clam pearl, arch crystal, sea lanterns, the ship lantern, the boss
-- mosaic heart and a few anemone patches. Everything else is sand, marble, rock and plastic.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Sunken = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local SAND = Enum.Material.Sand
local MARBLE = Enum.Material.Marble
local ROCK = Enum.Material.Rock
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.WoodPlanks
local FABRIC = Enum.Material.Fabric
local PEBBLE = Enum.Material.Pebble

local Z0, Z1 = 4120, 4480

local SANDC = C(226, 206, 160)
local SAND_D = C(205, 182, 135)
local TEAL = C(60, 175, 175)
local SEA = C(55, 125, 200)
local DEEP = C(40, 80, 130)
local CORAL = C(255, 120, 150)
local CORAL_O = C(255, 150, 80)
local CORAL_P = C(190, 110, 230)
local GOLD = C(255, 205, 80)
local MARBLE_C = C(232, 238, 236)
local MARBLE_T = C(190, 225, 220)
local REEF = C(75, 130, 145)
local KELP = { C(70, 160, 90), C(95, 185, 85), C(60, 140, 100) }
local AQUA = C(130, 255, 235)
local PEARL = C(250, 245, 255)
local WOODC = C(110, 80, 60)

local SOLID_MARBLE: Kit.Opts = { Mat = MARBLE, Solid = true, Shadow = true }
local GOLD_M: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- SMALL PROPS
--==================================================================
local function coral(parent: Instance, x: number, z: number, s: number)
	local rng = Kit.Rng
	local m = Kit.Model(parent, "Coral")
	local cols = { CORAL, CORAL_O, CORAL_P, C(255, 190, 90) }
	-- brain coral
	Kit.Ball(m, 4.5 * s, V(x, 0.8 * s, z), Kit.Vivid(Kit.Pick(cols)), { Mat = PEBBLE })
	-- branching coral
	local bc = Kit.Vivid(Kit.Pick(cols))
	local base = V(x + 2.6 * s, 0, z + rng:NextNumber(-1.5, 1.5))
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(-0.4, 0.4)
		local tip = base + V(math.cos(a) * 1.6 * s, rng:NextNumber(4, 6.5) * s, math.sin(a) * 1.6 * s)
		Props.Beam(m, base, tip, 0.8 * s, 0.8 * s, bc)
		Kit.Ball(m, 1.3 * s, tip, bc)
	end
	-- tube coral
	local tc = Kit.Vivid(Kit.Pick(cols))
	for i = 0, 1 do
		local h = rng:NextNumber(2.5, 4.5) * s
		local p = V(x - 2.4 * s + i * 1.4 * s, 0, z + 1.6 * s - i * 1.2 * s)
		Kit.Cyl(m, h, 1.3 * s, CFrame.new(p + V(0, h / 2, 0)), tc)
		Kit.Disc(m, p.X, p.Z, h + 0.2, 1.6 * s, 0.4, tc:Lerp(Color3.new(1, 1, 1), 0.35))
	end
	-- fan coral
	Kit.Part(m, V(0.3, 4 * s, 4.5 * s), CFrame.new(x - 0.5 * s, 2 * s, z - 2.4 * s) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Kit.Vivid(Kit.Pick(cols)))
	Kit.AddCircle(x, z, 4.5 * s)
end

local function kelp(parent: Instance, x: number, z: number, h: number)
	local rng = Kit.Rng
	for i = 1, 3 do
		local hh = h * rng:NextNumber(0.6, 1)
		local p = V(x + rng:NextNumber(-2, 2), hh / 2, z + rng:NextNumber(-2, 2))
		local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, math.pi), rng:NextNumber(-0.08, 0.08))
		Kit.Part(parent, V(0.7, hh, 2.4), cf, Kit.Pick(KELP), { Mat = Enum.Material.Grass })
		if i == 1 then
			Kit.Ball(parent, 1.4, p + V(0, hh * 0.3, 0), C(170, 200, 70))
		end
	end
	Kit.AddCircle(x, z, 3)
end

local function starfish(parent: Instance, x: number, z: number)
	local col = Kit.Vivid(Kit.Pick({ CORAL_O, CORAL, C(255, 215, 90) }))
	local yaw = Kit.Rng:NextNumber(0, math.pi * 2)
	for i = 0, 4 do
		local a = yaw + i * math.pi * 2 / 5
		Kit.Part(parent, V(0.9, 0.12, 2.6), CFrame.new(x + math.cos(a) * 1.2, 0.08, z + math.sin(a) * 1.2) * CFrame.Angles(0, -a + math.pi / 2, 0), col)
	end
end

local function brokenColumn(parent: Instance, x: number, z: number)
	local rng = Kit.Rng
	local m = Kit.Model(parent, "BrokenColumn")
	local h = rng:NextNumber(6, 18)
	Kit.Box(m, V(x - 2.6, 0, z - 2.6), V(x + 2.6, 1.2, z + 2.6), MARBLE_T, SOLID_MARBLE)
	Kit.Cyl(m, h, 3.6, CFrame.new(x, 1.2 + h / 2, z), MARBLE_C, SOLID_MARBLE)
	if h > 12 then
		Kit.Box(m, V(x - 2.4, 1.2 + h, z - 2.4), V(x + 2.4, 2.4 + h, z + 2.4), Kit.Vivid(GOLD), GOLD_M)
	else
		Kit.CylFlat(m, 6, 3.6, V(x + (if x > 0 then 3.2 else -3.2), 1.8, z + 3.5), "Z", MARBLE_C, { Mat = MARBLE })
		Kit.Ball(m, 2.2, V(x, 1.2 + h + 0.4, z), Kit.Vivid(CORAL), { Mat = PEBBLE })
	end
	Kit.AddCircle(x, z, 4)
end

local function chest(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "TreasureChest")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local gold = Kit.Vivid(GOLD)
	Kit.Part(m, V(6, 3.4, 4), base * CFrame.new(0, 1.7, 0), WOODC, { Mat = WOOD, Solid = true })
	Kit.Part(m, V(6.3, 0.6, 4.3), base * CFrame.new(0, 3.1, 0), gold, GOLD_M)
	Kit.Part(m, V(6, 0.6, 4), base * CFrame.new(0, 4.6, 2.6) * CFrame.Angles(-1.1, 0, 0), WOODC, { Mat = WOOD })
	Kit.Part(m, V(0.8, 1.2, 0.3), base * CFrame.new(0, 2.6, -2.1), gold, GOLD_M)
	-- coin pile spilling out the front + a couple of gems
	for i = 0, 3 do
		Kit.Ball(m, 2.4 - i * 0.3, (base * CFrame.new(-1.5 + i, 3.4 - i * 0.6, -0.6 - i * 0.9)).Position, gold, GOLD_M)
	end
	Kit.Ball(m, 1.1, (base * CFrame.new(1.6, 3.8, 0)).Position, Kit.Vivid(C(230, 60, 110)), { Refl = 0.3 })
	Kit.Ball(m, 1, (base * CFrame.new(-1.8, 3.7, 0.6)).Position, Kit.Vivid(C(70, 200, 255)), { Refl = 0.3 })
	Kit.AddCircle(x, z, 5)
end

local function clam(parent: Instance, x: number, z: number, d: number, glow: boolean): Part
	local m = Kit.Model(parent, "GiantClam")
	local R = d / 2
	local shell = C(230, 170, 215)
	local rib = C(250, 215, 240)
	Kit.Disc(m, x, z, 1.6, d, 1.6, shell, { Solid = true, Shadow = true })
	Kit.Disc(m, x, z, 1.8, d - 2, 0.3, C(255, 205, 220))
	-- upper shell hinged at the back (+Z), opening toward -Z
	local hinge = CFrame.new(x, 1.8, z + R) * CFrame.Angles(0.65, 0, 0)
	Kit.Cyl(m, 1.4, d, hinge * CFrame.new(0, 0.7, -R), shell, { Shadow = true })
	for i = -2, 2 do
		local a = i * 0.32
		Kit.Part(m, V(0.6, 0.4, R * 1.7), hinge * CFrame.new(0, 1.5, -R) * CFrame.Angles(0, a, 0), rib)
	end
	local pearlOpts: Kit.Opts = if glow then { Mat = NEON } else { Refl = 0.35 }
	local pearl = Kit.Ball(m, d * 0.28, V(x, 1.8 + d * 0.14, z - R * 0.15), PEARL, pearlOpts)
	if glow then
		Kit.Light(pearl, C(220, 240, 255), 28, 1.4)
	end
	Kit.AddCircle(x, z, R + 2)
	return pearl
end

local function seaLantern(parent: Instance, x: number, z: number, light: boolean)
	local m = Kit.Model(parent, "SeaLantern")
	Kit.Disc(m, x, z, 0.8, 3, 0.8, MARBLE_T, { Mat = MARBLE })
	Kit.Cyl(m, 9, 0.7, CFrame.new(x, 5.2, z), Kit.Vivid(GOLD), GOLD_M)
	-- shell cup holding a glowing sea-glass orb
	Kit.Cyl(m, 0.8, 3.4, CFrame.new(x, 10, z), Kit.Vivid(CORAL))
	local orb = Kit.Ball(m, 2.4, V(x, 11.4, z), AQUA, { Mat = NEON, Transp = 0.1 })
	if light then
		Kit.Light(orb, AQUA, 24, 1.4)
	end
	Kit.AddCircle(x, z, 2.5)
end

--==================================================================
-- GROUND, WALLS, OUTSIDE, WATER
--==================================================================
local function ground(f: Instance)
	local rng = Kit.Rng
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), SANDC, { Mat = SAND, Solid = true, Name = "Ground_Sunken" })
	-- marble-tile avenue with teal edging and gold mosaic bands
	Kit.Box(f, V(-9, 0, Z0), V(9, 0.05, Z1), MARBLE_C, { Mat = MARBLE, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 9, 0, Z0), V(s * 10, 0.08, Z1), Kit.Vivid(TEAL))
	end
	for z = Z0 + 40, Z1 - 20, 40 do
		Kit.Box(f, V(-9, 0.05, z - 0.8), V(9, 0.08, z + 0.8), Kit.Vivid(GOLD), GOLD_M)
	end
	-- darker sand ripples (flat)
	for _ = 1, 8 do
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(Z0 + 30, Z1 - 20)
		if math.abs(x) > 26 then
			Kit.Part(f, V(rng:NextNumber(18, 30), 0.04, 3), CFrame.new(x, 0.02, z) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), SAND_D, { Mat = SAND })
		end
	end
	-- mosaic discs on the ghost areas
	for i, a in AREAS do
		Kit.Disc(f, a[1], a[2], 0.07, a[3] * 2 + 4, 0.07, Kit.Vivid(if i % 2 == 0 then SEA else TEAL), { Mat = MARBLE })
		Kit.Disc(f, a[1], a[2], 0.1, a[3] * 2, 0.1, MARBLE_T, { Mat = MARBLE })
		Kit.Disc(f, a[1], a[2], 0.13, 10, 0.13, Kit.Vivid(GOLD), GOLD_M)
	end
	-- boss: deep-blue mosaic with a gold trident star and a glowing heart
	Kit.Disc(f, 0, BOSS_Z, 0.07, 58, 0.07, Kit.Vivid(GOLD), GOLD_M)
	Kit.Disc(f, 0, BOSS_Z, 0.1, 54, 0.1, DEEP, { Mat = MARBLE })
	for i = 0, 5 do
		local a = i * math.pi / 3
		Props.Beam(f, V(math.cos(a) * 4, 0.14, BOSS_Z + math.sin(a) * 4), V(math.cos(a) * 22, 0.14, BOSS_Z + math.sin(a) * 22), 1.2, 0.06, Kit.Vivid(GOLD), GOLD_M)
	end
	Kit.Disc(f, 0, BOSS_Z, 0.18, 7, 0.06, AQUA, { Mat = NEON, Transp = 0.15 })
end

local function sideWalls(f: Instance)
	local rng = Kit.Rng
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 26, z1), REEF, { Mat = ROCK, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.6, 26, z0), V(s * 146.4, 27.2, z1), SAND_D, { Mat = Enum.Material.Sandstone })
		Kit.Box(f, V(s * 139.7, 18, z0), V(s * 140, 19.2, z1), Kit.Vivid(TEAL))
		-- coral growing over the wall top
		for z = z0 + 14, z1 - 10, 30 do
			local c = Kit.Vivid(Kit.Pick({ CORAL, CORAL_O, CORAL_P }))
			Kit.Ball(f, rng:NextNumber(6, 9), V(s * 143, 28, z), c, { Mat = PEBBLE })
			Kit.Ball(f, rng:NextNumber(3.5, 5), V(s * 142, 30.5, z + 4), c:Lerp(Color3.new(1, 1, 1), 0.2), { Mat = PEBBLE })
		end
	end
end

local function outside(f: Instance)
	local rng = Kit.Rng
	local hills = { REEF, C(90, 110, 160), C(110, 150, 140) }
	for i = 0, 4 do
		local z = Z0 + 30 + i * 75
		for _, s in { -1, 1 } do
			Kit.Ball(f, rng:NextNumber(60, 80), V(s * rng:NextNumber(185, 200), -16, z + s * 15), Kit.Pick(hills), { Mat = ROCK })
			-- coral spire
			local x = s * rng:NextNumber(158, 168)
			local h = rng:NextNumber(30, 48)
			local c = Kit.Vivid(Kit.Pick({ CORAL, CORAL_O, CORAL_P }))
			Kit.Cyl(f, h, 5, CFrame.new(x, h / 2, z + 30), c)
			Kit.Ball(f, 8, V(x, h, z + 30), c:Lerp(Color3.new(1, 1, 1), 0.2), { Mat = PEBBLE })
			Kit.Ball(f, 5, V(x + s * 3, h * 0.6, z + 32), c, { Mat = PEBBLE })
			-- tall kelp forest
			for k = 0, 2 do
				local hh = rng:NextNumber(36, 60)
				local cf = CFrame.new(s * (151 + k * 5), hh / 2, z + 6 + k * 7) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.08, 0.08))
				Kit.Part(f, V(1.2, hh, 3.6), cf, Kit.Pick(KELP), { Mat = Enum.Material.Grass })
			end
		end
	end
end

local function water(f: Instance)
	Kit.Box(f, V(-190, 120, Z0), V(190, 121, Z1), C(70, 180, 215), { Transp = 0.85, Name = "WaterSurface", Shadow = false })
	-- soft light shafts (kept outside the ghost areas)
	for _, p in { { -118, Z0 + 52 }, { 116, Z0 + 120 }, { -24, Z0 + 205 }, { 48, Z0 + 262 } } do
		Kit.Part(f, V(6, 110, 14), CFrame.new(p[1], 64, p[2]) * CFrame.Angles(0, 0.4, 0.12), C(200, 245, 255), { Transp = 0.9, Name = "LightShaft", Shadow = false })
	end
end

--==================================================================
-- LANDMARKS
--==================================================================
local function gateArch(f: Instance)
	local m = Kit.Model(f, "AtlantisArch")
	local z = Z0 + 48
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 13.5, 0, z - 4), V(s * 20.5, 2.5, z + 4), MARBLE_T, SOLID_MARBLE)
		Kit.Cyl(m, 27.5, 5.5, CFrame.new(s * 17, 2.5 + 13.75, z), MARBLE_C, SOLID_MARBLE)
		for _, y in { 8, 18 } do
			Kit.Cyl(m, 0.8, 6, CFrame.new(s * 17, y, z), Kit.Vivid(TEAL))
		end
		Kit.Ball(m, 5, V(s * 19, 4.5, z - 3), Kit.Vivid(CORAL), { Mat = PEBBLE })
		Kit.AddRect(s * 12.5, z - 4.5, s * 21.5, z + 4.5)
	end
	Kit.Box(m, V(-22, 30, z - 3.5), V(22, 34, z + 3.5), MARBLE_C, SOLID_MARBLE)
	Kit.Box(m, V(-22.4, 30, z - 3.7), V(22.4, 30.8, z + 3.7), Kit.Vivid(GOLD), GOLD_M)
	-- pediment (two wedges meeting in the middle)
	Kit.Wedge(m, V(7, 7, 22), CFrame.new(-11, 37.5, z) * CFrame.Angles(0, -math.pi / 2, 0), MARBLE_C, { Mat = MARBLE })
	Kit.Wedge(m, V(7, 7, 22), CFrame.new(11, 37.5, z) * CFrame.Angles(0, math.pi / 2, 0), MARBLE_C, { Mat = MARBLE })
	local crystal = Kit.Part(m, V(3, 3, 3), CFrame.new(0, 43.5, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), AQUA, { Mat = NEON })
	Kit.Light(crystal, AQUA, 30, 1.4)
	Props.SignBoard(m, V(0, 32, z - 3.9), 30, 3.4, 0, -1, "~ SUNKEN CITY ~", DEEP, Kit.Vivid(GOLD))
end

local function temple(f: Instance)
	local m = Kit.Model(f, "DomedTemple")
	local x, z = -100, Z0 + 312
	local gold = Kit.Vivid(GOLD)
	Kit.Disc(m, x, z, 2, 48, 2, MARBLE_T, SOLID_MARBLE)
	Kit.Disc(m, x, z, 4, 44, 2, MARBLE_C, SOLID_MARBLE)
	Kit.Disc(m, x, z, 6, 40, 2, MARBLE_T, SOLID_MARBLE)
	-- ring of columns
	for i = 0, 9 do
		local a = i * math.pi / 5
		local cx, cz = x + math.cos(a) * 17, z + math.sin(a) * 17
		Kit.Cyl(m, 30, 3.4, CFrame.new(cx, 21, cz), MARBLE_C, SOLID_MARBLE)
		Kit.Box(m, V(cx - 2.2, 35, cz - 2.2), V(cx + 2.2, 36.4, cz + 2.2), gold, GOLD_M)
	end
	-- inner cella with a door toward the avenue
	Kit.Cyl(m, 28, 22, CFrame.new(x, 20, z), C(150, 205, 200), SOLID_MARBLE)
	Kit.Box(m, V(x + 10.5, 6, z - 3.5), V(x + 11.2, 18, z + 3.5), C(30, 60, 90))
	Kit.Box(m, V(x + 10.6, 18, z - 4.3), V(x + 11.3, 19, z + 4.3), gold, GOLD_M)
	-- entablature, drum, dome
	Kit.Cyl(m, 4, 40, CFrame.new(x, 38, z), MARBLE_C, { Mat = MARBLE, Shadow = true })
	Kit.Cyl(m, 0.8, 40.6, CFrame.new(x, 36.6, z), gold, GOLD_M)
	Kit.Cyl(m, 6, 32, CFrame.new(x, 43, z), MARBLE_T, { Mat = MARBLE, Shadow = true })
	Kit.Ball(m, 32, V(x, 46, z), C(80, 190, 175), { Shadow = true, Refl = 0.1 })
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		Props.Beam(m, V(x + math.cos(a) * 15.6, 47, z + math.sin(a) * 15.6), V(x + math.cos(a) * 3, 61.6, z + math.sin(a) * 3), 0.9, 0.9, gold, GOLD_M)
	end
	-- lantern with the glowing pearl
	Kit.Cyl(m, 1, 9, CFrame.new(x, 62.5, z), gold, GOLD_M)
	for i = 0, 3 do
		local a = i * math.pi / 2
		Kit.Cyl(m, 6, 0.8, CFrame.new(x + math.cos(a) * 3.4, 66, z + math.sin(a) * 3.4), gold, GOLD_M)
	end
	local pearl = Kit.Ball(m, 4.2, V(x, 66, z), PEARL, { Mat = NEON })
	Kit.Light(pearl, C(200, 240, 255), 40, 1.6)
	Kit.Cyl(m, 1.2, 9, CFrame.new(x, 69.6, z), gold, GOLD_M)
	-- giant trident on top
	Kit.Cyl(m, 22, 1.2, CFrame.new(x, 81, z), gold, GOLD_M)
	Kit.Box(m, V(x - 5, 91.4, z - 0.6), V(x + 5, 92.6, z + 0.6), gold, GOLD_M)
	for _, dx in { -4.4, 0, 4.4 } do
		local top = if dx == 0 then 101 else 98
		Kit.Box(m, V(x + dx - 0.6, 92.6, z - 0.6), V(x + dx + 0.6, top, z + 0.6), gold, GOLD_M)
		Kit.Wedge(m, V(1.2, 2, 1.2), CFrame.new(x + dx, top + 1, z), gold, GOLD_M)
	end
	-- bubbles rising from the dome
	local src = Kit.Part(m, V(10, 0.4, 10), CFrame.new(x, 63, z), AQUA, { Transp = 1, Name = "BubbleSource" })
	local e = Kit.Emitter(src, C(210, 250, 255), 3, 2, 3)
	if e then
		e.Acceleration = V(0, 2, 0)
	end
	Props.SignBoard(m, V(x + 11.6, 22.5, z), 11, 2.6, 1, 0, "TEMPLE OF TIDES", DEEP, Kit.Vivid(GOLD))
	Kit.AddCircle(x, z, 25)
end

local function ship(f: Instance)
	local m = Kit.Model(f, "SunkenShip")
	local hull = C(120, 85, 65)
	local plank = C(150, 110, 80)
	local base = CFrame.new(104, 3, Z0 + 296) * CFrame.Angles(0, -0.35, 0) * CFrame.Angles(0.28, 0, 0.12)
	local so: Kit.Opts = { Mat = WOOD, Solid = true, Shadow = true }
	Kit.Part(m, V(16, 14, 40), base, hull, so)
	Kit.Part(m, V(11.3, 14, 11.3), base * CFrame.new(0, 0, -20) * CFrame.Angles(0, math.pi / 4, 0), hull, so)
	Kit.Part(m, V(15.4, 0.6, 40), base * CFrame.new(0, 7.2, 0), plank, { Mat = WOOD })
	Kit.Part(m, V(16.4, 1.2, 40.4), base * CFrame.new(0, 2, 0), Kit.Vivid(C(220, 70, 70)), { Mat = WOOD })
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(0.6, 2, 38), base * CFrame.new(sx * 7.8, 8.5, 1), plank, { Mat = WOOD })
		for i = 0, 2 do
			Kit.Part(m, V(0.4, 2.6, 2.6), base * CFrame.new(sx * 8.1, 4.5, -10 + i * 9), Kit.Vivid(GOLD), { Mat = METAL, Shape = Enum.PartType.Cylinder })
			Kit.Part(m, V(0.5, 1.8, 1.8), base * CFrame.new(sx * 8.15, 4.5, -10 + i * 9), C(40, 70, 100), { Shape = Enum.PartType.Cylinder })
		end
	end
	-- bowsprit, broken mast and a tattered sail
	Kit.Part(m, V(1.2, 1.2, 14), base * CFrame.new(0, 7, -30) * CFrame.Angles(0.25, 0, 0), plank, { Mat = WOOD })
	local mast = base * CFrame.new(0, 7, -6) * CFrame.Angles(0, 0, 0.35)
	Kit.Part(m, V(1.8, 26, 1.8), mast * CFrame.new(0, 13, 0), WOODC, { Mat = WOOD })
	Kit.Part(m, V(0.2, 12, 14), mast * CFrame.new(0.4, 16, 0), C(240, 230, 205), { Mat = FABRIC, Transp = 0.1 })
	Kit.Part(m, V(1, 1, 16), mast * CFrame.new(0, 22, 0), WOODC, { Mat = WOOD })
	-- lantern hanging from the bowsprit
	local lantern = Kit.Part(m, V(1.6, 2.2, 1.6), base * CFrame.new(0, 5.5, -33), C(255, 210, 120), { Mat = NEON })
	Kit.Light(lantern, C(255, 200, 120), 26, 1.3, true)
	-- name board on the stern deck
	local sign = Kit.Part(m, V(9, 2.6, 0.4), base * CFrame.new(0, 10.3, 19.5) * CFrame.Angles(0, math.pi, 0), DEEP)
	Kit.Sign(sign, Enum.NormalId.Front, "S.S. BOO-NANZA", Kit.Vivid(GOLD))
	Kit.AddRect(80, Z0 + 262, 128, Z0 + 340)
end

local function seaLife(f: Instance)
	-- floating jellyfish and fish (single tagged parts, outside the ghost areas)
	for _, p in { V(-30, 26, Z0 + 150), V(40, 32, Z0 + 230), V(-116, 30, Z0 + 190), V(112, 28, Z0 + 92) } do
		local j = Kit.Ball(f, 4, p, Kit.Vivid(Kit.Pick({ CORAL, CORAL_P, C(255, 170, 220) })), { Transp = 0.35, Name = "Jellyfish" })
		Kit.Float(j, 2)
	end
	for _, p in { V(26, 18, Z0 + 140), V(-30, 22, Z0 + 290), V(120, 16, Z0 + 230) } do
		local fish = Kit.Part(f, V(1.4, 2.2, 4), CFrame.new(p) * CFrame.Angles(0, Kit.Rng:NextNumber(0, 6), 0), Kit.Vivid(Kit.Pick({ CORAL_O, C(255, 215, 80), SEA })), { Name = "Fish" })
		Kit.Float(fish, 1.5)
	end
end

local function scatter(f: Instance)
	local rng = Kit.Rng
	-- broken columns lining the avenue
	for z = Z0 + 128, Z1 - 70, 26 do
		for _, s in { -1, 1 } do
			local x = s * 16
			if Kit.IsFree(x, z, 3.5) then
				brokenColumn(f, x, z)
			end
		end
	end
	-- giant clams
	if Kit.IsFree(-104, Z0 + 52, 9) then
		clam(f, -104, Z0 + 52, 14, true)
	end
	if Kit.IsFree(118, Z0 + 140, 8) then
		clam(f, 118, Z0 + 140, 12, false)
	end
	if Kit.IsFree(-34, Z0 + 320, 7) then
		local pearl = clam(f, -34, Z0 + 320, 10, false)
		local e = Kit.Emitter(pearl, C(210, 250, 255), 2, 1.6, 2.5)
		if e then
			e.Acceleration = V(0, 2.5, 0)
		end
	end
	-- treasure
	for _, p in { { 84, Z0 + 248, -1, -1 }, { -64, Z0 + 320, 1, 0 }, { 120, Z0 + 352, -1, 0 } } do
		if Kit.IsFree(p[1], p[2], 5) then
			chest(f, p[1], p[2], p[3], p[4])
		end
	end
	-- sea lanterns along the avenue
	for i, p in { { -14, Z0 + 118 }, { 14, Z0 + 118 }, { -14, Z0 + 265 }, { 14, Z0 + 265 } } do
		if Kit.IsFree(p[1], p[2], 2.5) then
			seaLantern(f, p[1], p[2], i == 1 or i == 4)
		end
	end
	-- coral reefs and kelp
	local corals, kelps, stars = 0, 0, 0
	for _ = 1, 500 do
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(Z0 + 30, Z1 - 10)
		if corals < 14 and Kit.IsFree(x, z, 6) then
			corals += 1
			coral(f, x, z, rng:NextNumber(0.9, 1.3))
		elseif kelps < 10 and Kit.IsFree(x, z, 3) then
			kelps += 1
			kelp(f, x, z, rng:NextNumber(14, 30))
		elseif stars < 8 and math.abs(x) > 12 then
			stars += 1
			starfish(f, x, z)
		end
	end
	-- glowing anemone patches (flat neon accents)
	for _, p in { V(-48, 0, Z0 + 60), V(46, 0, Z0 + 330), V(-122, 0, Z0 + 270) } do
		Kit.Disc(f, p.X, p.Z, 0.2, 3.5, 0.1, AQUA, { Mat = NEON, Transp = 0.2 })
	end
end

--==================================================================
-- BUILD
--==================================================================
function Sunken.Build(map: Instance)
	local f = Kit.Folder(map, "Sunken")
	ground(f)
	sideWalls(f)
	outside(f)
	water(f)
	gateArch(f)
	temple(f)
	ship(f)
	seaLife(f)
	scatter(f)
end

return Sunken
