--!strict
-- ZONE 25: Haunted Moon Base (Z 9880..10240). A quiet, slightly spooky research base on the
-- grey Moon: dusty cratered ground, white habitat domes joined by tubes, a glass greenhouse,
-- antennas and a big radar dish, a rover, a gold-foil lander, a rocket on its launch pad and a
-- crashed saucer. Earth hangs huge in the sky. Lighting stays low-key: cool floodlights and
-- small orange beacons, no big glow.
--   Ground: grey moondust slab (top Y = 0) + a white metal walkway along X = 0 with orange
--   edge stripes. Ghost areas are flat craters ((0,9965) r30, (-82,10000) r24, (75,10060) r26,
--   (-62,10120) r24); the boss area (0,10185) r26 is a flat saucer landing pad.
--   Landmarks: the rocket at (100, 10200) (nose ~Y 86) and Earth at (-250, 190, 10110).

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local MoonBase = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local SAND = Enum.Material.Sand
local ROCK = Enum.Material.Rock

local Z0, Z1 = 9880, 10240

local DUST = C(138, 138, 146)
local DUST_L = C(170, 170, 178)
local DUST_D = C(108, 108, 117)
local DUST_DD = C(92, 92, 101)
local PANEL = C(232, 234, 240)
local PANEL_D = C(190, 194, 205)
local ORANGE = C(255, 140, 60)
local SOLAR = C(45, 70, 140)
local FOIL = C(230, 185, 80)
local DARK = C(45, 48, 60)
local GLASS = C(170, 215, 255)
local COOL = C(210, 230, 255)

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 }, { 0, Z0 + 305, 26 } }

local function clearOfAreas(x: number, z: number, pad: number): boolean
	for _, a in AREAS do
		local dx, dz = x - a[1], z - a[2]
		if dx * dx + dz * dz < (a[3] + pad) * (a[3] + pad) then
			return false
		end
	end
	return true
end

--==================================================================
-- HELPERS
--==================================================================
-- Decorative crater with a bumpy rim (outside the ghost areas).
local function crater(parent: Instance, x: number, z: number, r: number)
	local rng = Kit.Rng
	Kit.Disc(parent, x, z, 0.05, r * 2 + 3, 0.05, DUST_L, { Mat = SAND })
	Kit.Disc(parent, x, z, 0.08, r * 2, 0.03, DUST_D, { Mat = SAND })
	Kit.Disc(parent, x + r * 0.15, z - r * 0.1, 0.1, r * 1.1, 0.02, DUST_DD, { Mat = SAND })
	local n = math.max(6, math.floor(r * 1.1))
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local d = rng:NextNumber(2.2, 3.6)
		Kit.Ball(parent, d, V(x + math.cos(a) * (r + 1.2), -d * 0.25, z + math.sin(a) * (r + 1.2)), if i % 3 == 0 then DUST else DUST_L, { Mat = SAND })
	end
	Kit.AddCircle(x, z, r + 3)
end

local function rock(parent: Instance, x: number, z: number, d: number)
	local rng = Kit.Rng
	Kit.Ball(parent, d, V(x, -d * 0.2, z), Kit.Pick({ DUST, DUST_D, C(125, 122, 128) }), { Mat = ROCK })
	if d > 3 then
		Kit.Ball(parent, d * 0.55, V(x + d * 0.45, -d * 0.1, z + rng:NextNumber(-0.3, 0.3) * d), DUST_L, { Mat = ROCK })
	end
	Kit.AddCircle(x, z, d * 0.6)
end

-- White habitat dome (half-buried ball) with a base ring, a door facing (fx, fz) and portholes.
local function dome(parent: Instance, x: number, z: number, d: number, fx: number, fz: number, glass: boolean)
	local m = Kit.Model(parent, if glass then "Greenhouse" else "HabitatDome")
	local r = d / 2
	if glass then
		Kit.Ball(m, d, V(x, 0, z), GLASS, { Mat = Enum.Material.Glass, Transp = 0.55, Refl = 0.15 })
		Kit.Disc(m, x, z, 0.3, d - 1, 0.3, C(110, 85, 60), { Mat = Enum.Material.Ground })
		local rng = Kit.Rng
		for _ = 1, 6 do
			local a = rng:NextNumber(0, math.pi * 2)
			local q = rng:NextNumber(0, r * 0.55)
			local h = rng:NextNumber(2, 4)
			Kit.Cyl(m, h, 0.4, CFrame.new(x + math.cos(a) * q, h / 2, z + math.sin(a) * q), C(90, 160, 80))
			Kit.Ball(m, rng:NextNumber(2, 3.4), V(x + math.cos(a) * q, h + 0.5, z + math.sin(a) * q), Kit.Pick({ C(110, 210, 110), C(150, 230, 120), C(255, 170, 200) }))
		end
		-- frame ribs
		for i = 0, 2 do
			Kit.Part(m, V(d * 0.98, 0.4, 0.4), CFrame.new(x, 0, z) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, r * 0.62, 0), PANEL_D, { Mat = METAL })
		end
	else
		Kit.Ball(m, d, V(x, 0, z), PANEL, { Solid = true, Shadow = true })
		Kit.Ball(m, d * 0.22, V(x, r * 0.97, z), PANEL_D, { Mat = METAL })
		local yaw = Kit.FaceYaw(fx, fz)
		local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		-- airlock door sticking out of the dome toward (fx, fz)
		Kit.Part(m, V(6, 7, 4), base * CFrame.new(0, 3.5, -r + 1), PANEL_D, { Solid = true })
		Kit.Part(m, V(4, 5.6, 0.3), base * CFrame.new(0, 2.8, -r - 1.05), DARK, { Mat = METAL })
		Kit.Part(m, V(4.4, 0.5, 0.35), base * CFrame.new(0, 6, -r - 1.05), Kit.Vivid(ORANGE))
		-- portholes (small warm windows) around the dome
		for i = -2, 2 do
			if i ~= 0 then
				local a = i * 0.6
				local p = (base * CFrame.Angles(0, a, 0) * CFrame.new(0, r * 0.45, -r * 0.9)).Position
				Kit.Ball(m, 1.8, p, C(255, 215, 150), { Mat = if i == 1 then NEON else Enum.Material.SmoothPlastic })
			end
		end
	end
	Kit.Cyl(m, 1.2, d + 0.6, CFrame.new(x, 0.6, z), Kit.Vivid(ORANGE))
	Kit.AddCircle(x, z, r + 1.5)
end

-- Connector tube between two ground points (raised on little legs).
local function tube(parent: Instance, a: Vector3, b: Vector3)
	local pa, pb = V(a.X, 2.6, a.Z), V(b.X, 2.6, b.Z)
	Props.Beam(parent, pa, pb, 3.6, 3.6, PANEL_D, { Solid = true })
	local n = math.floor((pb - pa).Magnitude / 8)
	for i = 1, n do
		local p = pa:Lerp(pb, i / (n + 1))
		Props.Beam(parent, p - V(0, 0.4, 0), p + V(0, 0.4, 0) + (pb - pa).Unit * 0.01, 4.2, 4.2, Kit.Vivid(ORANGE))
	end
end

local function antenna(parent: Instance, x: number, z: number, h: number)
	local m = Kit.Model(parent, "AntennaMast")
	Kit.Box(m, V(x - 2.5, 0, z - 2.5), V(x + 2.5, 1, z + 2.5), PANEL_D, { Mat = METAL, Solid = true })
	for _, o in { V(-1.2, 0, -1.2), V(1.2, 0, -1.2), V(-1.2, 0, 1.2), V(1.2, 0, 1.2) } do
		Props.Beam(m, V(x, 1, z) + o, V(x, h, z) + o * 0.35, 0.35, 0.35, PANEL, { Mat = METAL })
	end
	for y = 5, h - 4, 6 do
		local w = 2.4 - (y / h) * 1.6
		Kit.Box(m, V(x - w / 2 - 0.2, y, z - w / 2 - 0.2), V(x + w / 2 + 0.2, y + 0.3, z + w / 2 + 0.2), Kit.Vivid(ORANGE))
	end
	Kit.Cyl(m, 6, 0.3, CFrame.new(x, h + 3, z), PANEL, { Mat = METAL })
	Kit.Ball(m, 1, V(x, h + 6.2, z), C(255, 90, 60), { Mat = NEON })
	for _, s in { -1, 1 } do
		Kit.CylFlat(m, 3, 1.2, V(x + s * 1.6, h - 2, z), "X", PANEL_D, { Mat = METAL })
	end
	Kit.AddCircle(x, z, 3.5)
end

local function radarDish(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "RadarDish")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Cyl(m, 2, 12, base * CFrame.new(0, 1, 0), PANEL_D, { Mat = METAL, Solid = true })
	Kit.Cyl(m, 12, 3, base * CFrame.new(0, 8, 0), PANEL, { Solid = true })
	Kit.Box(m, V(x - 2.2, 13, z - 2.2), V(x + 2.2, 16, z + 2.2), PANEL_D, { Mat = METAL })
	local tilt = base * CFrame.new(0, 21, 0) * CFrame.Angles(math.rad(-50), 0, 0)
	-- dish = shallow stack of discs facing up-forward
	Kit.Part(m, V(1, 24, 24), tilt * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, 0, 0), PANEL, { Shape = Enum.PartType.Cylinder, Shadow = true })
	Kit.Part(m, V(1.2, 18, 18), tilt * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), PANEL_D, { Shape = Enum.PartType.Cylinder })
	Kit.Part(m, V(1.2, 25, 25), tilt * CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Kit.Vivid(ORANGE), { Shape = Enum.PartType.Cylinder })
	-- feed horn on three struts
	local tip = (tilt * CFrame.new(0, 10, 0)).Position
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		Props.Beam(m, (tilt * CFrame.new(math.cos(a) * 9, 0.6, math.sin(a) * 9)).Position, tip, 0.35, 0.35, PANEL_D, { Mat = METAL })
	end
	Kit.Ball(m, 1.6, tip, C(255, 110, 70))
	Kit.AddCircle(x, z, 9)
end

local function rover(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "MoonRover")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Part(m, V(7, 2.4, 11), base * CFrame.new(0, 3.2, 0), PANEL, { Solid = true, Shadow = true })
	Kit.Part(m, V(7.4, 0.6, 11.4), base * CFrame.new(0, 2, 0), Kit.Vivid(ORANGE))
	Kit.Part(m, V(9, 0.3, 6), base * CFrame.new(0, 4.6, 2) * CFrame.Angles(math.rad(-8), 0, 0), SOLAR, { Refl = 0.2 })
	for i = -1, 1 do
		for _, s in { -1, 1 } do
			Kit.CylFlat(m, 1.4, 3, (base * CFrame.new(s * 4.1, 1.5, i * 4)).Position, "X", DARK)
			Kit.CylFlat(m, 1.5, 1.4, (base * CFrame.new(s * 4.1, 1.5, i * 4)).Position, "X", PANEL_D)
		end
	end
	-- mast camera with two "eyes" (friendly)
	Kit.Cyl(m, 4, 0.5, base * CFrame.new(0, 6.4, -4), PANEL_D, { Mat = METAL })
	Kit.Part(m, V(2.6, 1.4, 1.4), base * CFrame.new(0, 8.8, -4), PANEL)
	for _, s in { -0.6, 0.6 } do
		Kit.Ball(m, 0.7, (base * CFrame.new(s, 8.8, -4.75)).Position, C(40, 40, 60))
	end
	Kit.Cyl(m, 5, 0.2, base * CFrame.new(2.6, 7, 4), PANEL_D, { Mat = METAL })
	Kit.Ball(m, 0.6, (base * CFrame.new(2.6, 9.6, 4)).Position, C(255, 90, 60), { Mat = NEON })
	-- tyre tracks behind it
	for _, s in { -1, 1 } do
		Kit.Part(m, V(1.6, 0.03, 26), base * CFrame.new(s * 4.1, 0.03, 19), DUST_D, { Mat = SAND })
	end
	Kit.AddCircle(x, z, 7)
end

local function lander(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "Lander")
	Kit.Box(m, V(x - 5, 5, z - 5), V(x + 5, 10, z + 5), FOIL, { Mat = Enum.Material.Foil, Shadow = true })
	Kit.Box(m, V(x - 3.6, 10, z - 3.6), V(x + 3.6, 15, z + 3.6), PANEL, { Shadow = true })
	Kit.Box(m, V(x - 1.5, 11.5, z - 3.8), V(x + 1.5, 13.5, z - 3.6), DARK, { Mat = Enum.Material.Glass })
	Kit.Cyl(m, 3, 0.4, CFrame.new(x + 2.4, 16.5, z + 2), PANEL_D, { Mat = METAL })
	Kit.Ball(m, 2.4, V(x + 2.4, 18.4, z + 2), PANEL)
	for _, o in { V(-1, 0, -1), V(1, 0, -1), V(-1, 0, 1), V(1, 0, 1) } do
		local top = V(x, 6, z) + o * 4.5
		local foot = V(x, 0.3, z) + o * 8.5
		Props.Beam(m, top, foot, 0.6, 0.6, PANEL_D, { Mat = METAL })
		Kit.Disc(m, foot.X, foot.Z, 0.5, 2.6, 0.5, PANEL_D, { Mat = METAL })
	end
	Kit.Cyl(m, 3, 4, CFrame.new(x, 3.6, z), DARK, { Mat = METAL })
	-- ladder down the front
	for i = 0, 3 do
		Kit.Box(m, V(x - 1.2, 1.6 + i * 1.6, z - 6.6 + i * 0.4), V(x + 1.2, 1.9 + i * 1.6, z - 6.2 + i * 0.4), PANEL_D, { Mat = METAL })
	end
	Kit.AddCircle(x, z, 9.5)
end

local function solarArray(parent: Instance, x: number, z: number, rows: number)
	local m = Kit.Model(parent, "SolarArray")
	for i = 0, rows - 1 do
		local zz = z + i * 7
		for _, dx in { -5, 5 } do
			Kit.Cyl(m, 3, 0.4, CFrame.new(x + dx, 1.5, zz), PANEL_D, { Mat = METAL })
		end
		Kit.Part(m, V(16, 0.3, 5), CFrame.new(x, 3.4, zz) * CFrame.Angles(math.rad(25), 0, 0), SOLAR, { Refl = 0.25 })
		Kit.Part(m, V(16.4, 0.2, 0.3), CFrame.new(x, 3.4, zz) * CFrame.Angles(math.rad(25), 0, 0) * CFrame.new(0, 0.2, 0), PANEL)
	end
	Kit.AddCircle(x, z + (rows - 1) * 3.5, 9 + rows * 2)
end

local function floodlight(parent: Instance, x: number, z: number, fx: number, fz: number, light: boolean)
	local m = Kit.Model(parent, "Floodlight")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Box(m, V(x - 1.4, 0, z - 1.4), V(x + 1.4, 1, z + 1.4), PANEL_D, { Mat = METAL, Solid = true })
	Kit.Cyl(m, 15, 0.7, CFrame.new(x, 8, z), PANEL, { Mat = METAL })
	local head = base * CFrame.new(0, 16, -0.6) * CFrame.Angles(math.rad(-25), 0, 0)
	Kit.Part(m, V(4.4, 2.6, 1.4), head, DARK, { Mat = METAL })
	local lens = Kit.Part(m, V(3.8, 2, 0.2), head * CFrame.new(0, 0, -0.75), COOL, { Mat = NEON })
	if light then
		Kit.Light(lens, COOL, 40, 1.1)
	end
	Kit.AddCircle(x, z, 2)
end

local function rocket(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "Rocket")
	-- launch pad
	Kit.Disc(m, x, z, 1, 30, 1, PANEL_D, { Mat = Enum.Material.Concrete, Solid = true })
	Kit.Disc(m, x, z, 1.05, 22, 0.05, DARK, { Mat = METAL })
	for i = 0, 7 do
		local a = i * math.pi / 4
		Kit.Part(m, V(2.4, 0.06, 4), CFrame.new(x + math.cos(a) * 13, 1.03, z + math.sin(a) * 13) * CFrame.Angles(0, -a, 0), if i % 2 == 0 then Kit.Vivid(ORANGE) else PANEL)
	end
	-- body
	local by = 1
	Kit.Cyl(m, 50, 10, CFrame.new(x, by + 12 + 25, z), PANEL, { Shadow = true })
	for _, y in { 20, 40, 58 } do
		Kit.Cyl(m, 2.4, 10.3, CFrame.new(x, by + y, z), Kit.Vivid(ORANGE))
	end
	Kit.Cyl(m, 5, 9, CFrame.new(x, by + 64.5, z), PANEL)
	Kit.Cyl(m, 4, 7, CFrame.new(x, by + 69, z), PANEL)
	Kit.Cyl(m, 3.5, 4.6, CFrame.new(x, by + 72.7, z), Kit.Vivid(ORANGE))
	Kit.Cyl(m, 3, 2.4, CFrame.new(x, by + 75.8, z), PANEL)
	Kit.Ball(m, 2.4, V(x, by + 77.6, z), Kit.Vivid(ORANGE))
	-- porthole + ghost face on the side facing the zone
	Kit.Ball(m, 3.4, V(x - 4.6, by + 50, z - 0.5), C(150, 200, 255), { Mat = Enum.Material.Glass, Refl = 0.2 })
	-- engine bell and fins
	Kit.Cyl(m, 4, 7, CFrame.new(x, by + 10, z), DARK, { Mat = METAL })
	Kit.Cyl(m, 3, 8.4, CFrame.new(x, by + 7, z), C(70, 72, 85), { Mat = METAL })
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3 + math.pi / 6
		local cf = CFrame.new(x, by + 12, z) * CFrame.Angles(0, -a, 0) * CFrame.new(7, 3, 0)
		Kit.Wedge(m, V(0.8, 10, 5), cf * CFrame.Angles(0, -math.pi / 2, 0), Kit.Vivid(ORANGE))
	end
	-- gantry tower beside it
	local gx = x + 13
	for _, o in { V(-2, 0, -2), V(2, 0, -2), V(-2, 0, 2), V(2, 0, 2) } do
		Kit.Box(m, V(gx, by, z) + o - V(0.4, 0, 0.4), V(gx, by + 68, z) + o + V(0.4, 0, 0.4), C(200, 70, 60), { Mat = METAL })
	end
	for y = 8, 64, 8 do
		Kit.Box(m, V(gx - 2.4, by + y, z - 2.4), V(gx + 2.4, by + y + 0.5, z + 2.4), C(200, 70, 60), { Mat = METAL })
	end
	Props.Beam(m, V(gx - 2, by + 56, z), V(x + 5, by + 56, z), 1.2, 1.2, C(200, 70, 60), { Mat = METAL })
	Kit.Ball(m, 1.2, V(gx, by + 69.5, z), C(255, 80, 60), { Mat = NEON })
	Kit.AddCircle(x, z, 16)
	Kit.AddCircle(gx, z, 4)
end

local function saucer(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "CrashedSaucer")
	local cf = CFrame.new(x, 4, z) * CFrame.Angles(math.rad(14), 0.5, math.rad(-18))
	Kit.Part(m, V(3, 26, 26), cf * CFrame.Angles(0, 0, math.pi / 2), C(150, 160, 175), { Shape = Enum.PartType.Cylinder, Mat = METAL, Refl = 0.2, Shadow = true })
	Kit.Part(m, V(1.6, 30, 30), cf * CFrame.Angles(0, 0, math.pi / 2), C(120, 128, 145), { Shape = Enum.PartType.Cylinder, Mat = METAL })
	Kit.Ball(m, 12, (cf * CFrame.new(0, 2.5, 0)).Position, C(150, 255, 200), { Mat = Enum.Material.Glass, Transp = 0.45 })
	for i = 0, 7 do
		local a = i * math.pi / 4
		Kit.Ball(m, 1.4, (cf * CFrame.new(math.cos(a) * 14.4, 0, math.sin(a) * 14.4)).Position, if i % 2 == 0 then C(150, 255, 200) else C(255, 220, 120), { Mat = if i % 4 == 0 then NEON else Enum.Material.SmoothPlastic })
	end
	-- dirt pushed up in front of it + a skid trail
	for i = 0, 4 do
		Kit.Ball(m, 4 + i * 0.4, V(x - 10 + i * 4.5, -1, z - 12 + i * 1.5), DUST_L, { Mat = SAND })
	end
	Kit.Part(m, V(10, 0.04, 40), CFrame.new(x - 6, 0.04, z - 32) * CFrame.Angles(0, 0.35, 0), DUST_D, { Mat = SAND })
	local wisp = Kit.Part(m, V(10, 1, 10), cf * CFrame.new(0, 6, 0), C(150, 255, 200), { Transp = 1, Name = "SaucerWisp" })
	Kit.Emitter(wisp, C(170, 255, 210), 2, 5, 0.5)
	Kit.AddCircle(x, z, 16)
end

local function flag(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "BaseFlag")
	Kit.Cyl(m, 14, 0.4, CFrame.new(x, 7, z), PANEL, { Mat = METAL })
	Kit.Part(m, V(0.2, 0.3, 7), CFrame.new(x, 13.8, z - 3.5), PANEL, { Mat = METAL })
	Kit.Part(m, V(0.15, 4.4, 7), CFrame.new(x, 11.5, z - 3.5), Kit.Vivid(ORANGE), { Mat = Enum.Material.Fabric })
	-- little ghost emblem on the flag
	Kit.Ball(m, 2.2, V(x - 0.15, 11.8, z - 3.5), C(250, 250, 255))
	Kit.Part(m, V(0.1, 1, 2.2), CFrame.new(x - 0.15, 11, z - 3.5), C(250, 250, 255))
	Kit.AddCircle(x, z, 1.5)
end

--==================================================================
-- GROUND, WALLS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), DUST, { Mat = SAND, Solid = true, Name = "Ground_MoonBase" })
	-- metal walkway with orange edges and little beacon studs
	Kit.Box(f, V(-7, 0, Z0), V(7, 0.06, Z1), PANEL_D, { Mat = Enum.Material.DiamondPlate, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 7, 0, Z0), V(s * 8.2, 0.08, Z1), Kit.Vivid(ORANGE))
	end
	local i = 0
	for z = Z0 + 6, Z1 - 6, 12 do
		i += 1
		Kit.Box(f, V(-7, 0.06, z - 0.2), V(7, 0.08, z + 0.2), C(160, 165, 178), { Mat = METAL })
		if i % 2 == 0 then
			for _, s in { -1, 1 } do
				Kit.Disc(f, s * 9.2, z, 0.12, 0.9, 0.06, ORANGE, { Mat = if i % 4 == 0 then NEON else Enum.Material.SmoothPlastic })
			end
		end
	end
	-- ghost areas: flat craters
	local rng = Kit.Rng
	for k = 1, 4 do
		local a = AREAS[k]
		Kit.Disc(f, a[1], a[2], 0.06, a[3] * 2 + 6, 0.06, DUST_L, { Mat = SAND })
		Kit.Disc(f, a[1], a[2], 0.1, a[3] * 2, 0.04, DUST_D, { Mat = SAND })
		Kit.Disc(f, a[1] - a[3] * 0.1, a[2] + a[3] * 0.1, 0.13, a[3] * 1.1, 0.03, DUST_DD, { Mat = SAND })
		for _ = 1, 4 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0.35, 0.8) * a[3]
			local cx, cz = a[1] + math.cos(ang) * d, a[2] + math.sin(ang) * d
			local cr = rng:NextNumber(2, 4)
			Kit.Disc(f, cx, cz, 0.16, cr * 2 + 1.2, 0.03, DUST_L, { Mat = SAND })
			Kit.Disc(f, cx, cz, 0.19, cr * 2, 0.03, DUST_DD, { Mat = SAND })
		end
		-- rim boulders just outside the circle
		local n = math.floor(a[3] * 0.7)
		for j = 0, n - 1 do
			local ang = j / n * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local bx, bz = a[1] + math.cos(ang) * (a[3] + 3.4), a[2] + math.sin(ang) * (a[3] + 3.4)
			if math.abs(bx) > 11 and Kit.IsFree(bx, bz, 0.5, true) then
				local d = rng:NextNumber(2.4, 3.6)
				Kit.Ball(f, d, V(bx, -d * 0.3, bz), if j % 2 == 0 then DUST_L else DUST, { Mat = SAND })
			end
		end
	end
	-- boss: saucer landing pad (flat)
	local bz = AREAS[5][2]
	Kit.Disc(f, 0, bz, 0.06, 60, 0.06, DUST_L, { Mat = SAND })
	Kit.Disc(f, 0, bz, 0.1, 56, 0.04, DARK, { Mat = Enum.Material.Concrete })
	Kit.Disc(f, 0, bz, 0.13, 50, 0.03, PANEL, { Mat = Enum.Material.Concrete })
	Kit.Disc(f, 0, bz, 0.16, 47, 0.03, C(60, 64, 78), { Mat = Enum.Material.Concrete })
	for k = 0, 11 do
		local a = k * math.pi / 6
		Kit.Part(f, V(5, 0.04, 2.6), CFrame.new(math.cos(a) * 25.8, 0.15, bz + math.sin(a) * 25.8) * CFrame.Angles(0, -a + math.pi / 2, 0), if k % 2 == 0 then Kit.Vivid(ORANGE) else C(250, 250, 250))
		if k % 3 == 0 then
			Kit.Disc(f, math.cos(a + 0.26) * 20, bz + math.sin(a + 0.26) * 20, 0.22, 1.4, 0.06, C(170, 255, 210), { Mat = NEON })
		end
	end
	Kit.Disc(f, 0, bz, 0.2, 16, 0.04, Kit.Vivid(ORANGE))
	Kit.Disc(f, 0, bz, 0.23, 12, 0.04, C(60, 64, 78), { Mat = Enum.Material.Concrete })
	Kit.Disc(f, 0, bz, 0.26, 5, 0.04, C(170, 255, 210))
	-- darker and lighter dust patches so the ground isn't one flat grey
	for _ = 1, 14 do
		local x = rng:NextNumber(-125, 125)
		local z = rng:NextNumber(Z0 + 15, Z1 - 15)
		local d = rng:NextNumber(14, 30)
		if math.abs(x) > d / 2 + 9 and clearOfAreas(x, z, d / 2 + 4) then
			Kit.Disc(f, x, z, 0.02, d, 0.02, if rng:NextNumber() < 0.5 then C(128, 128, 136) else C(150, 150, 157), { Mat = SAND })
		end
	end
	-- footprints wandering across the dust (a ghost astronaut's walk)
	local fx, fz = -30, Z0 + 150
	for k = 0, 13 do
		local x = fx + k * 2.2
		local z = fz + math.sin(k * 0.6) * 3 + (if k % 2 == 0 then 0.8 else -0.8)
		if Kit.IsFree(x, z, 0.6, true) and math.abs(x) > 9 then
			Kit.Part(f, V(1, 0.03, 1.8), CFrame.new(x, 0.02, z) * CFrame.Angles(0, math.pi / 2, 0), DUST_DD, { Mat = SAND })
		end
	end
end

local function sideWalls(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 10, z1), PANEL, { Solid = true, Shadow = true, Name = "BaseWall" })
		Kit.Box(f, V(s * 139.8, 6.5, z0), V(s * 140, 7.6, z1), Kit.Vivid(ORANGE))
		Kit.Box(f, V(s * 139.6, 10, z0), V(s * 146.4, 10.8, z1), PANEL_D, { Mat = METAL })
		local k = 0
		for z = z0 + 10, z1 - 6, 30 do
			k += 1
			Kit.Box(f, V(s * 139.4, 0, z - 1.6), V(s * 146.6, 13, z + 1.6), PANEL_D, { Mat = METAL, Solid = true })
			Kit.Ball(f, 1.1, V(s * 143, 13.6, z), if k % 2 == 0 then ORANGE else C(255, 210, 160), { Mat = if k % 3 == 0 then NEON else Enum.Material.SmoothPlastic })
			-- square window strip between the posts
			Kit.Box(f, V(s * 139.8, 2.5, z + 6), V(s * 140, 4.8, z + 14), C(60, 70, 100), { Mat = Enum.Material.Glass, Refl = 0.2 })
		end
		-- grey crater-rim hills beyond the wall
		for z = Z0 + 20, Z1 - 10, 40 do
			local d = Kit.Rng:NextNumber(36, 56)
			Kit.Ball(f, d, V(s * Kit.Rng:NextNumber(170, 195), -d * 0.3, z + Kit.Rng:NextNumber(-12, 12)), Kit.Pick({ DUST, DUST_L, DUST_D }), { Mat = SAND })
		end
	end
end

--==================================================================
-- SKY: Earth and a few stars
--==================================================================
local function sky(f: Instance)
	local m = Kit.Model(f, "EarthRise")
	local c = V(-235, 150, Z0 + 330)
	local R = 55
	Kit.Ball(m, R * 2, c, C(45, 110, 215))
	Kit.Ball(m, R * 2 + 4, c, C(140, 200, 255), { Transp = 0.8 })
	-- continents and clouds on the side facing the base
	local face = (V(0, 0, Z0 + 150) - c).Unit
	local right = face:Cross(V(0, 1, 0)).Unit
	local up = right:Cross(face).Unit
	for _, q in { { -0.3, 0.25, 34, 1 }, { 0.35, 0.05, 40, 1 }, { 0.05, -0.45, 26, 1 }, { -0.45, -0.2, 18, 1 }, { 0.2, 0.55, 22, 2 }, { -0.1, -0.05, 14, 2 }, { 0.5, -0.4, 16, 2 } } do
		local dir = (face + right * q[1] + up * q[2]).Unit
		local col = if q[4] == 1 then C(90, 170, 90) else C(245, 248, 255)
		local d: number = q[3]
		Kit.Ball(m, d, c + dir * (R - d * 0.38), col)
	end
	Kit.Ball(m, 20, c + up * (R - 7), C(245, 248, 255))
	-- stars (few, small: the Void Throne next door gets the big star field)
	local rng = Kit.Rng
	for _ = 1, 34 do
		local p = V(rng:NextNumber(-320, 320), rng:NextNumber(140, 280), rng:NextNumber(Z0 - 40, Z1 + 40))
		if math.abs(p.X) > 60 or p.Y > 200 then
			Kit.Ball(f, rng:NextNumber(1.4, 2.6), p, C(255, 250, 235), { Mat = NEON, Name = "Star" })
		end
	end
	-- a small satellite drifting overhead
	local sat = V(40, 70, Z0 + 120)
	Kit.Box(f, sat - V(1.6, 1.6, 1.6), sat + V(1.6, 1.6, 1.6), FOIL, { Mat = Enum.Material.Foil })
	for _, s in { -1, 1 } do
		Kit.Part(f, V(7, 0.2, 3), CFrame.new(sat + V(s * 5.4, 0, 0)), SOLAR, { Refl = 0.2 })
	end
	local rockA = Kit.Ball(f, 4, V(-40, 60, Z0 + 200), DUST_D, { Mat = ROCK, Name = "DriftingMoonRock" })
	Kit.Float(rockA, 1.5)
end

--==================================================================
-- BASE BUILDINGS AND DECOR
--==================================================================
local function base(f: Instance)
	-- habitat cluster on the +X side near the entrance
	dome(f, 62, Z0 + 52, 24, -1, 0, false)
	dome(f, 112, Z0 + 92, 20, -1, 0, false)
	dome(f, 112, Z0 + 38, 18, -1, 0, true)
	tube(f, V(72, 0, Z0 + 58), V(104, 0, Z0 + 86))
	tube(f, V(72, 0, Z0 + 46), V(103, 0, Z0 + 40))
	-- a lone dome far down the -X side
	dome(f, -116, Z0 + 260, 20, 1, 0, false)
	radarDish(f, -112, Z0 + 44, 1, -1)
	antenna(f, -40, Z0 + 180, 30)
	antenna(f, 120, Z0 + 150, 24)
	rover(f, 34, Z0 + 128, -1, 0.3)
	lander(f, -112, Z0 + 180)
	solarArray(f, 112, Z0 + 200, 4)
	solarArray(f, 36, Z0 + 232, 3)
	rocket(f, 100, Z1 - 42)
	saucer(f, -100, Z1 - 50)
	flag(f, -46, Z0 + 26)
	if Kit.IsFree(-46, Z0 + 46, 3) then
		Props.SignBoard(f, V(-46, 4, Z0 + 46), 12, 3, 0, -1, "MOON BASE G-1", DARK, C(255, 200, 150), ORANGE)
		for _, dx in { -5, 5 } do
			Kit.Cyl(f, 3, 0.4, CFrame.new(-46 + dx, 1.5, Z0 + 46.4), PANEL_D, { Mat = METAL })
		end
		Kit.AddCircle(-46, Z0 + 46, 7)
	end
	local lit = 0
	for _, p in { { 20, Z0 + 46 }, { -20, Z0 + 150 }, { 20, Z0 + 268 }, { -40, Z0 + 300 } } do
		if Kit.IsFree(p[1], p[2], 2) then
			lit += 1
			floodlight(f, p[1], p[2], -p[1], 0, lit <= 2)
		end
	end
	-- decorative craters and moon rocks
	local rng = Kit.Rng
	for _, p in { { -40, Z0 + 110, 8 }, { 40, Z0 + 80, 6 }, { 118, Z0 + 250, 9 }, { -118, Z0 + 110, 7 }, { 30, Z0 + 175, 5 }, { -30, Z0 + 270, 6 }, { 60, Z0 + 330, 6 }, { -50, Z0 + 330, 5 } } do
		if Kit.IsFree(p[1], p[2], p[3] + 3) then
			crater(f, p[1], p[2], p[3])
		end
	end
	local placed = 0
	for _ = 1, 140 do
		if placed >= 40 then
			break
		end
		local x = rng:NextNumber(-134, 134)
		local z = rng:NextNumber(Z0 + 10, Z1 - 10)
		local d = rng:NextNumber(1.6, 5)
		if Kit.IsFree(x, z, d * 0.6 + 0.5) then
			placed += 1
			rock(f, x, z, d)
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function MoonBase.Build(map: Instance)
	local f = Kit.Folder(map, "MoonBase")
	ground(f)
	sideWalls(f)
	base(f)
	sky(f)
end

return MoonBase
