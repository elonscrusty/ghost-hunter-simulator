--!strict
-- ZONE 10: Frostbite Peaks (Z 3040..3400). A bright snowy valley under an aurora.
--   Ground: snow slab (top Y = 0). Main path along X = 0: pale ice-blue paving (X -8..8,
--   top 0.05, normal friction, NOT the slippery Ice material) with lilac edges.
--   Ghost areas hold flat paint only: a frozen pond with cracks on the path (0, 3125), snow
--   drift circles, a second frozen pond (75, 3220) and the Blizzard Queen's ice rink with a big
--   snowflake (0, 3345). Frozen surfaces are smooth plastic with reflectance (walkable, not slippery).
--   Landmark: the frozen castle with a ~98-stud ice spire at (95, 3330) in front of a snowy
--   mountain range (outside the +X wall, peaks up to ~150), visible from the Swamp.
--   Also: a ski lodge and a cabin (east), igloos, snowmen, a ski rack and sled, snowy pines,
--   ice crystal clusters, a skating pond (-35, 3210). Side walls: snowbank walls with ice blocks.
--   Sky: aurora curtains (big translucent coloured planes, not neon) high above the walls,
--   gentle snowfall (one emitter).
-- Glow: a few ice-crystal tips, the spire crystal and window, lodge/igloo windows, lanterns and
-- small glints on the boss rink.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Frost = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local SNOW = Enum.Material.Snow
local ICE = Enum.Material.Ice
local GLACIER = Enum.Material.Glacier
local WOOD = Enum.Material.Wood
local ROCK = Enum.Material.Rock
local FABRIC = Enum.Material.Fabric
local SLATE = Enum.Material.Slate

local Z0, Z1 = 3040, 3400

local WHITE = C(244, 248, 255)
local SNOWC = C(236, 243, 252)
local SNOW_SHADE = C(214, 226, 246)
local ICEC = C(170, 215, 245)
local LILAC = C(196, 170, 245)
local AURORA = C(120, 255, 190)
local PATH = C(196, 220, 244)
local PINE = { C(46, 112, 92), C(56, 126, 98), C(40, 100, 90) }
local BARK = C(110, 78, 58)
local LOG = C(156, 100, 64)
local WARM = C(255, 210, 130)
local MTN = C(150, 152, 190)
local MTN_DARK = C(124, 128, 170)

local function rz(n: number): number
	return Z0 + n
end

local function gable(parent: Instance, base: CFrame, length: number, depth: number, height: number, color: Color3, mat: Enum.Material, solid: boolean)
	local half = depth / 2
	local o: Kit.Opts = { Mat = mat, Solid = solid, Shadow = true }
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, -half / 2), color, o)
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), color, o)
end

-- Flat frozen pond (non-solid sheet on the solid ground) with a snow rim.
local function frozenPond(parent: Instance, x: number, z: number, d: number)
	Kit.Disc(parent, x, z, 0.04, d + 5, 0.03, WHITE, { Mat = SNOW })
	Kit.Disc(parent, x, z, 0.08, d, 0.04, ICEC, { Refl = 0.3, Name = "FrozenPond" })
end

--==================================================================
-- PROPS
--==================================================================
local function pine(parent: Instance, pos: Vector3, h: number)
	local col = Kit.Pick(PINE)
	Kit.Cyl(parent, h * 0.3, 1.8, CFrame.new(pos + V(0, h * 0.15, 0)), BARK, { Mat = WOOD, Solid = true, Shadow = true })
	for k = 0, 2 do
		local d = h * 0.62 * (1 - k * 0.27)
		local th = h * 0.2
		local y = h * 0.22 + k * h * 0.22
		Kit.Cyl(parent, th, d, CFrame.new(pos + V(0, y + th / 2, 0)), col, { Mat = Enum.Material.Grass, Shadow = true })
		Kit.Cyl(parent, 0.7, d * 0.82, CFrame.new(pos + V(0, y + th + 0.35, 0)), WHITE, { Mat = SNOW })
	end
	Kit.Ball(parent, h * 0.12, pos + V(0, h * 0.88 + 0.4, 0), WHITE, { Mat = SNOW })
	Kit.AddCircle(pos.X, pos.Z, h * 0.31)
end

local function snowman(parent: Instance, x: number, z: number, fx: number, fz: number, scarf: Color3)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local snow: Kit.Opts = { Mat = SNOW, Solid = true }
	Kit.Ball(parent, 5, (base * CFrame.new(0, 2.2, 0)).Position, WHITE, snow)
	Kit.Ball(parent, 3.7, (base * CFrame.new(0, 5.4, 0)).Position, WHITE, { Mat = SNOW })
	Kit.Ball(parent, 2.7, (base * CFrame.new(0, 8, 0)).Position, WHITE, { Mat = SNOW })
	for _, s in { -1, 1 } do
		Kit.Ball(parent, 0.42, (base * CFrame.new(s * 0.5, 8.35, -1.15)).Position, C(30, 30, 40))
		Props.Beam(parent, (base * CFrame.new(s * 1.6, 5.8, 0)).Position, (base * CFrame.new(s * 3.6, 7.4, -0.3)).Position, 0.3, 0.3, BARK, { Mat = WOOD })
	end
	Kit.Part(parent, V(0.35, 0.35, 1.3), base * CFrame.new(0, 7.9, -1.65), Kit.Vivid(C(255, 140, 40)))
	Kit.Cyl(parent, 0.6, 3.1, base * CFrame.new(0, 6.95, 0), Kit.Vivid(scarf), { Mat = FABRIC })
	Kit.Cyl(parent, 0.25, 2.9, base * CFrame.new(0, 9.2, 0), C(40, 40, 55))
	Kit.Cyl(parent, 1.6, 1.9, base * CFrame.new(0, 10.1, 0), C(40, 40, 55))
	Kit.AddCircle(x, z, 4)
end

local function iceCluster(parent: Instance, x: number, z: number, glow: boolean)
	local rng = Kit.Rng
	local cols = { ICEC, C(200, 190, 255), C(160, 235, 240) }
	for k = 0, 2 do
		local h = if k == 0 then rng:NextNumber(6, 9) else rng:NextNumber(3, 5)
		local w = if k == 0 then 2.2 else 1.5
		local a = k * 2.2
		local p = V(x + math.cos(a) * (if k == 0 then 0 else 1.8), 0, z + math.sin(a) * (if k == 0 then 0 else 1.8))
		local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 3), rng:NextNumber(-0.25, 0.25))
		Kit.Part(parent, V(w, h, w), cf * CFrame.new(0, h / 2 - 0.5, 0), Kit.Pick(cols), { Mat = ICE, Transp = 0.15, Refl = 0.2 })
		if k == 0 then
			Kit.Part(parent, V(w * 0.7, w * 0.7, w * 0.7), cf * CFrame.new(0, h - 0.5, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), if glow then AURORA else C(225, 245, 255), if glow then { Mat = NEON } else { Mat = ICE, Transp = 0.1 })
		end
	end
	Kit.AddCircle(x, z, 3)
end

local function igloo(parent: Instance, x: number, z: number, fx: number, fz: number, lit: boolean)
	local m = Kit.Model(parent, "Igloo")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Ball(m, 16, V(x, 0, z), WHITE, { Mat = SNOW, Solid = true, Shadow = true })
	Kit.Cyl(m, 0.35, 15.4, CFrame.new(x, 2.6, z), SNOW_SHADE, { Mat = SNOW })
	Kit.Cyl(m, 0.35, 12.6, CFrame.new(x, 5, z), SNOW_SHADE, { Mat = SNOW })
	-- entrance tunnel (cylinder axis turned to point out of the dome) and the doorway
	local tunnel = base * CFrame.new(0, 0, -8) * CFrame.Angles(0, math.pi / 2, 0)
	Kit.Part(m, V(6, 6.4, 6.4), tunnel, WHITE, { Mat = SNOW, Shape = Enum.PartType.Cylinder, Solid = true })
	local door = Kit.Part(m, V(0.4, 4.2, 4.2), tunnel * CFrame.new(3.05, 0, 0), if lit then WARM else C(50, 60, 90), { Shape = Enum.PartType.Cylinder, Mat = if lit then NEON else Enum.Material.SmoothPlastic })
	if lit then
		Kit.Light(door, WARM, 18, 1.2)
	end
	Kit.AddCircle(x, z, 10)
end

-- Log cabin facing (fx, 0). length along the facade, depth into the cabin.
local function cabin(parent: Instance, x: number, z: number, fx: number, length: number, depth: number, wall: Color3, roof: Color3, sign: string?, lit: boolean, flicker: boolean)
	local m = Kit.Model(parent, "Cabin")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, 0), 0)
	local h = 11
	Kit.Part(m, V(length + 1, 1.2, depth + 1), base * CFrame.new(0, 0.6, 0), C(150, 150, 175), { Mat = SLATE, Solid = true })
	Kit.Part(m, V(length, h, depth), base * CFrame.new(0, 1.2 + h / 2, 0), wall, { Mat = WOOD, Solid = true, Shadow = true })
	-- log seams on the front
	for k = 1, 3 do
		Kit.Part(m, V(length + 0.2, 0.35, 0.3), base * CFrame.new(0, 1.2 + k * h / 4, -depth / 2 - 0.1), wall:Lerp(Color3.new(0, 0, 0), 0.25), { Mat = WOOD })
	end
	gable(m, base * CFrame.new(0, 1.2 + h, 0), length + 2, depth + 3, 7, roof, SLATE, true)
	gable(m, base * CFrame.new(0, 1.2 + h + 0.7, 0), length + 2.4, depth + 3.4, 7, WHITE, SNOW, false)
	-- chimney
	Kit.Part(m, V(3, 9, 3), base * CFrame.new(length / 2 - 3, 1.2 + h + 5, depth * 0.2), C(150, 140, 160), { Mat = Enum.Material.Cobblestone })
	Kit.Part(m, V(3.4, 0.8, 3.4), base * CFrame.new(length / 2 - 3, 1.2 + h + 9.8, depth * 0.2), WHITE, { Mat = SNOW })
	-- door and windows on the front (local -Z)
	Kit.Part(m, V(3.4, 6.5, 0.3), base * CFrame.new(0, 4.45, -depth / 2 - 0.2), C(110, 60, 50), { Mat = WOOD })
	local first: Part? = nil
	for _, s in { -1, 1 } do
		local win = Kit.Part(m, V(3.4, 3, 0.3), base * CFrame.new(s * length * 0.3, 6.5, -depth / 2 - 0.2), WARM, if lit then { Mat = NEON } else {})
		Kit.Part(m, V(4.2, 3.8, 0.2), base * CFrame.new(s * length * 0.3, 6.5, -depth / 2 - 0.08), Kit.Vivid(C(200, 70, 80)), { Mat = WOOD })
		first = first or win
	end
	if lit and first then
		Kit.Light(first, WARM, 22, 1.4, flicker)
	end
	if sign then
		Props.SignBoard(m, (base * CFrame.new(0, 1.2 + h + 2.2, -depth / 2 - 1.2)).Position, length * 0.55, 3.2, fx, 0, sign, C(70, 45, 40), C(255, 235, 190), C(200, 70, 80))
	end
	local r = math.max(length, depth) / 2 + 3
	Kit.AddCircle(x, z, r)
end

local function skiRack(parent: Instance, x: number, z: number)
	local wood: Kit.Opts = { Mat = WOOD }
	for _, s in { -1, 1 } do
		Kit.Box(parent, V(x + s * 3 - 0.3, 0, z - 0.3), V(x + s * 3 + 0.3, 4, z + 0.3), LOG, wood)
	end
	Kit.Box(parent, V(x - 3.5, 3.6, z - 0.4), V(x + 3.5, 4.2, z + 0.4), LOG, wood)
	local skis = { C(255, 90, 120), C(90, 180, 255), C(255, 210, 70), C(150, 110, 240) }
	for i, col in skis do
		local sx = x - 2.6 + (i - 1) * 1.7
		Kit.Part(parent, V(0.6, 6.5, 0.2), CFrame.new(sx, 3.2, z - 0.6) * CFrame.Angles(-0.12, 0, 0), Kit.Vivid(col))
	end
	-- sled
	local sz = z - 5
	for _, s in { -1, 1 } do
		Kit.Box(parent, V(x + s * 1.4 - 0.2, 0, sz - 2.5), V(x + s * 1.4 + 0.2, 0.4, sz + 2.5), C(70, 70, 90), { Mat = Enum.Material.Metal })
	end
	Kit.Box(parent, V(x - 1.8, 0.4, sz - 2), V(x + 1.8, 0.9, sz + 2.2), Kit.Vivid(C(220, 60, 70)), wood)
	Kit.AddCircle(x, z - 2, 6)
end

--==================================================================
-- GROUND, PATH, WALLS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), SNOWC, { Mat = SNOW, Solid = true, Name = "Ground_Frost" })
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), PATH, { Solid = true, Refl = 0.08, Name = "IcePath" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8 - 0.5, 0.05, Z0), V(s * 8 + 0.5, 0.1, Z1), Kit.Vivid(LILAC))
	end
	for z = Z0 + 16, Z1 - 10, 30 do
		Kit.Part(f, V(1.6, 0.04, 1.6), CFrame.new(0, 0.07, z) * CFrame.Angles(0, math.pi / 4, 0), WHITE)
	end
	-- soft snow drifts (flat shading patches)
	local rng = Kit.Rng
	for _ = 1, 8 do
		local x = rng:NextNumber(-125, 125)
		local z = rng:NextNumber(Z0 + 30, Z1 - 30)
		if math.abs(x) > 22 then
			Kit.Part(f, V(rng:NextNumber(16, 28), 0.03, rng:NextNumber(12, 22)), CFrame.new(x, 0.015, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), SNOW_SHADE, { Mat = SNOW })
		end
	end
end

local function sideWalls(f: Instance)
	local zA, zB = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, 0, zA), V(s * 146, 10, zB), WHITE, { Mat = SNOW, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.6, 10, zA), V(s * 146.4, 11, zB), ICEC, { Mat = GLACIER })
		Kit.Box(f, V(s * 139.85, 2.4, zA), V(s * 139.65, 3, zB), Kit.Vivid(LILAC))
		for z = zA + 14, zB - 6, 32 do
			Kit.Part(f, V(6, 6, 6), CFrame.new(s * 143, 13, z) * CFrame.Angles(0, 0.4, 0), if (z // 32) % 2 == 0 then ICEC else C(200, 190, 255), { Mat = ICE, Transp = 0.15, Solid = true })
			Kit.Ball(f, 7, V(s * 141, 10.5, z + 9), WHITE, { Mat = SNOW })
		end
	end
end

--==================================================================
-- GHOST AREA PAINT (flat only)
--==================================================================
local function ghostPaint(f: Instance)
	-- frost spirits: frozen pond across the path with a few cracks
	local cz = rz(85)
	frozenPond(f, 0, cz, 60)
	local crack = C(110, 160, 215)
	for i = 0, 4 do
		local a = i * 1.3 + 0.4
		local p = V(math.cos(a) * 8, 0.1, cz + math.sin(a) * 8)
		Props.Beam(f, p, p + V(math.cos(a + 0.3) * 14, 0, math.sin(a + 0.3) * 14), 0.35, 0.04, crack)
	end
	-- snow drift circles with lilac rings
	for _, a in { { -82, rz(120), 24 }, { -62, rz(240), 24 } } do
		Kit.Disc(f, a[1], a[2], 0.04, a[3] * 2 + 3, 0.03, Kit.Vivid(LILAC))
		Kit.Disc(f, a[1], a[2], 0.07, a[3] * 2, 0.03, SNOW_SHADE, { Mat = SNOW })
		frozenPond(f, a[1] + 5, a[2] + 3, 12)
	end
	-- yeti phantoms: second frozen pond
	frozenPond(f, 75, rz(180), 46)
	Props.Beam(f, V(62, 0.1, rz(172)), V(84, 0.1, rz(188)), 0.35, 0.04, crack)
	-- boss: the Blizzard Queen's ice rink with a big snowflake
	local bz = rz(305)
	Kit.Disc(f, 0, bz, 0.04, 58, 0.03, Kit.Vivid(LILAC))
	Kit.Disc(f, 0, bz, 0.08, 54, 0.04, ICEC, { Refl = 0.3, Name = "IceRink" })
	for i = 0, 5 do
		local a = i * math.pi / 3
		local tip = V(math.cos(a) * 22, 0.12, bz + math.sin(a) * 22)
		Props.Beam(f, V(0, 0.12, bz), tip, 1.4, 0.04, WHITE)
		local mid = V(math.cos(a) * 13, 0.12, bz + math.sin(a) * 13)
		for _, d in { -0.7, 0.7 } do
			Props.Beam(f, mid, mid + V(math.cos(a + d) * 5, 0, math.sin(a + d) * 5), 0.8, 0.04, WHITE)
		end
		Kit.Part(f, V(1.6, 0.05, 1.6), CFrame.new(tip.X, 0.13, tip.Z) * CFrame.Angles(0, math.pi / 4, 0), AURORA, { Mat = NEON })
	end
	Kit.Disc(f, 0, bz, 0.14, 5, 0.04, Kit.Vivid(C(120, 200, 255)))
end

--==================================================================
-- LANDMARK: frozen castle + mountains
--==================================================================
local function castle(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "FrozenCastle")
	local ice: Kit.Opts = { Mat = GLACIER, Solid = true, Shadow = true }
	local iceCol = C(186, 222, 248)
	local roof = Kit.Vivid(LILAC)
	Kit.Disc(m, x, z, 1.2, 46, 1.2, C(170, 175, 205), { Mat = ROCK, Solid = true })
	Kit.Disc(m, x, z, 1.3, 42, 0.1, WHITE, { Mat = SNOW })
	-- curtain walls (front faces -X with a gate)
	local hw, wh, t = 14, 16, 3
	Kit.Box(m, V(x + hw - t, 1.2, z - hw), V(x + hw, wh, z + hw), iceCol, ice)
	Kit.Box(m, V(x - hw, 1.2, z - hw), V(x + hw, wh, z - hw + t), iceCol, ice)
	Kit.Box(m, V(x - hw, 1.2, z + hw - t), V(x + hw, wh, z + hw), iceCol, ice)
	for _, s in { -1, 1 } do
		Kit.Box(m, V(x - hw, 1.2, z + s * 4.5), V(x - hw + t, wh, z + s * hw), iceCol, ice)
	end
	Kit.Box(m, V(x - hw, 11, z - 4.5), V(x - hw + t, wh, z + 4.5), iceCol, ice)
	Kit.Box(m, V(x - hw + 0.4, 1.2, z - 4.5), V(x - hw + 0.8, 11, z + 4.5), C(80, 90, 150))
	-- crenellations on the front wall
	for k = -2, 2 do
		Kit.Box(m, V(x - hw - 0.2, wh, z + k * 5.5 - 1.5), V(x - hw + t + 0.2, wh + 2, z + k * 5.5 + 1.5), iceCol, { Mat = GLACIER })
	end
	-- corner towers with lilac cone roofs
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local tx, tz = x + sx * hw, z + sz * hw
			Kit.Cyl(m, 28, 8, CFrame.new(tx, 15.2, tz), C(200, 230, 252), ice)
			for k = 0, 2 do
				Kit.Cyl(m, 3, 9.5 - k * 3, CFrame.new(tx, 30.7 + k * 3, tz), roof)
			end
			Kit.Ball(m, 1.6, V(tx, 37.6, tz), Kit.Vivid(AURORA))
		end
	end
	-- central ice spire
	Kit.Cyl(m, 64, 14, CFrame.new(x, 33.2, z), C(160, 210, 245), { Mat = ICE, Transp = 0.08, Solid = true, Shadow = true })
	Kit.Cyl(m, 2, 16, CFrame.new(x, 42, z), roof)
	Kit.Cyl(m, 2, 15.4, CFrame.new(x, 24, z), roof)
	local stack = { { 12, 6 }, { 8.5, 6 }, { 5, 7 } }
	local y = 65.2
	for _, s in stack do
		Kit.Cyl(m, s[2], s[1], CFrame.new(x, y + s[2] / 2, z), if s[1] > 10 then C(200, 230, 252) else roof, { Mat = GLACIER })
		y += s[2]
	end
	local tip = Kit.Part(m, V(3.6, 3.6, 3.6), CFrame.new(x, y + 2, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), AURORA, { Mat = NEON })
	Kit.Part(m, V(1.4, 10, 1.4), CFrame.new(x, y + 8.5, z), C(220, 245, 255), { Mat = ICE, Transp = 0.1 })
	Kit.Light(tip, AURORA, 40, 1.6)
	-- spire windows facing the valley (-X); the top one glows
	for k, wy in { 34, 50 } do
		Kit.Box(m, V(x - 7.2, wy, z - 1.4), V(x - 6.6, wy + 4, z + 1.4), if k == 2 then C(200, 240, 255) else C(70, 90, 160), if k == 2 then { Mat = NEON } else { Refl = 0.2 })
	end
	-- banners on the front towers
	for _, sz in { -1, 1 } do
		Kit.Box(m, V(x - hw - 4.3, 14, z + sz * hw - 1.6), V(x - hw - 4, 24, z + sz * hw + 1.6), Kit.Vivid(C(150, 110, 230)), { Mat = FABRIC })
	end
	-- ice shards around the base
	local rng = Kit.Rng
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.5
		local p = V(x + math.cos(a) * 20, 0, z + math.sin(a) * 20)
		local h = rng:NextNumber(6, 10)
		local cf = CFrame.new(p) * CFrame.Angles(math.sin(a) * 0.3, rng:NextNumber(0, 3), -math.cos(a) * 0.3)
		Kit.Part(m, V(2.4, h, 2.4), cf * CFrame.new(0, h / 2 - 0.5, 0), if i % 2 == 0 then ICEC else C(205, 195, 255), { Mat = ICE, Transp = 0.15 })
	end
	-- icy mist rolling off the castle
	local fog = Kit.Part(m, V(40, 0.2, 40), CFrame.new(x, 1.5, z), C(225, 240, 255), { Transp = 1, Name = "FogSource" })
	Kit.Emitter(fog, C(225, 240, 255), 1.4, 9, 0.3)
	Kit.AddCircle(x, z, 24)
end

-- A mountain peak: a diamond-turned block half buried, plus a snow cap. Runs along Z.
local function peak(parent: Instance, x: number, z: number, size: number, depth: number, col: Color3)
	local cf = CFrame.new(x, -size * 0.12, z) * CFrame.Angles(0, 0, math.pi / 4)
	Kit.Part(parent, V(size, size, depth), cf, col, { Mat = ROCK })
	local capS = size * 0.36
	local topY = -size * 0.12 + size * 0.7071
	Kit.Part(parent, V(capS, capS, depth * 0.9), CFrame.new(x, topY - capS * 0.7071 + 0.6, z) * CFrame.Angles(0, 0, math.pi / 4), WHITE, { Mat = SNOW })
end

--==================================================================
-- OUTSIDE: mountains, snowfield, pines, aurora
--==================================================================
local function outside(f: Instance)
	local rng = Kit.Rng
	local o = Kit.Folder(f, "Peaks")
	for _, s in { -1, 1 } do
		Kit.Box(o, V(s * 190, -3, Z0), V(s * 420, -0.2, Z1), SNOWC, { Mat = SNOW })
		-- pines on the outer snow
		for i = 0, 7 do
			local x = s * rng:NextNumber(152, 200)
			local z = Z0 + 20 + i * 44 + rng:NextNumber(-8, 8)
			local h = rng:NextNumber(22, 34)
			local col = Kit.Pick(PINE)
			Kit.Cyl(o, h * 0.3, 2, CFrame.new(x, h * 0.15, z), BARK, { Mat = WOOD })
			Kit.Cyl(o, h * 0.35, h * 0.55, CFrame.new(x, h * 0.42, z), col, { Mat = Enum.Material.Grass })
			Kit.Cyl(o, h * 0.3, h * 0.34, CFrame.new(x, h * 0.74, z), col, { Mat = Enum.Material.Grass })
			Kit.Cyl(o, 0.8, h * 0.3, CFrame.new(x, h * 0.9 + 0.4, z), WHITE, { Mat = SNOW })
		end
	end
	-- mountain ranges both sides, tallest behind the castle (+X, back)
	local ranges = {
		{ -260, rz(40), 150, 120 }, { -300, rz(160), 200, 130 }, { -250, rz(270), 160, 110 }, { -320, rz(340), 190, 120 },
		{ 270, rz(30), 140, 110 }, { 310, rz(140), 180, 130 }, { 250, rz(230), 150, 100 }, { 260, rz(320), 210, 120 },
	}
	for i, r in ranges do
		peak(o, r[1], r[2], r[3], r[4], if i % 2 == 0 then MTN else MTN_DARK)
	end
	-- aurora curtains: big translucent planes high above the side walls
	type Curtain = { s: number, z: number, col: Color3, t: number }
	local aur: { Curtain } = {
		{ s = -1, z = rz(110), col = AURORA, t = 0.62 },
		{ s = -1, z = rz(260), col = C(190, 150, 255), t = 0.66 },
		{ s = 1, z = rz(70), col = C(110, 220, 255), t = 0.66 },
		{ s = 1, z = rz(220), col = AURORA, t = 0.62 },
		{ s = 1, z = rz(330), col = C(190, 150, 255), t = 0.66 },
	}
	for i, a in aur do
		local s = a.s
		local cf = CFrame.new(s * (175 + (i % 2) * 20), 130 + (i % 3) * 12, a.z) * CFrame.Angles(0, (i % 2) * 0.15 - 0.07, s * 0.25)
		Kit.Part(o, V(1, 46, 190), cf, a.col, { Transp = a.t, Name = "Aurora" })
		Kit.Part(o, V(1, 14, 170), cf * CFrame.new(0, -26, 6), a.col, { Transp = 0.8, Name = "Aurora" })
	end
end

--==================================================================
-- BUILD
--==================================================================
function Frost.Build(map: Instance)
	local f = Kit.Folder(map, "Frost")
	local rng = Kit.Rng

	ground(f)
	sideWalls(f)
	ghostPaint(f)
	castle(f, 95, rz(290))
	cabin(f, 98, rz(62), -1, 30, 18, LOG, C(170, 60, 70), "⛷ SKI LODGE ⛷", true, true)
	cabin(f, 112, rz(118), -1, 18, 14, C(140, 92, 62), C(70, 90, 150), nil, true, false)
	skiRack(f, 72, rz(80))
	igloo(f, 56, rz(122), -1, 0, true)
	igloo(f, -100, rz(46), 1, 0, false)
	igloo(f, -118, rz(196), 1, 0, false)
	igloo(f, 30, rz(214), -1, -1, false)
	frozenPond(f, -35, rz(170), 28)
	Kit.AddCircle(-35, rz(170), 17)
	snowman(f, 15, rz(52), 0, -1, C(230, 60, 80))

	-- welcome sign
	do
		local x, z = -62, rz(14)
		for _, s in { -1, 1 } do
			Kit.Cyl(f, 13, 1.4, CFrame.new(x + s * 10, 6.5, z), LOG, { Mat = WOOD, Solid = true })
		end
		Props.SignBoard(f, V(x, 10, z), 20, 5.5, 0, -1, "❄ FROSTBITE PEAKS ❄", C(70, 90, 150), WHITE, LILAC)
		Kit.Box(f, V(x - 11, 12.8, z - 0.6), V(x + 11, 13.6, z + 0.6), WHITE, { Mat = SNOW })
		Kit.AddCircle(x, z, 12)
	end

	-- lanterns along the path (one lit)
	local lit = 0
	for z = Z0 + 46, Z1 - 30, 46 do
		for _, s in { -1, 1 } do
			local zz = z + (if s > 0 then 23 else 0)
			local x = s * 12.5
			if zz < Z1 - 26 and Kit.IsFree(x, zz, 1.2, true) then
				lit += 1
				Props.Lantern(f, V(x, 0, zz), C(190, 235, 255), lit == 2, false)
				Kit.AddCircle(x, zz, 1.5)
			end
		end
	end

	-- pines
	local trees = 0
	for _ = 1, 400 do
		if trees >= 18 then
			break
		end
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(Z0 + 30, Z1 - 30)
		local h = rng:NextNumber(18, 30)
		if Kit.IsFree(x, z, h * 0.31 + 1) then
			trees += 1
			pine(f, V(x, 0, z), h)
		end
	end

	-- ice crystals and snowmen
	local scarves = { C(230, 60, 80), C(90, 170, 255), C(150, 110, 240), C(80, 200, 140) }
	local crystals, men = 0, 0
	for _ = 1, 600 do
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(Z0 + 28, Z1 - 28)
		if crystals < 9 and Kit.IsFree(x, z, 3.5) then
			crystals += 1
			iceCluster(f, x, z, crystals <= 3)
		elseif men < 4 and Kit.IsFree(x, z, 4.5) then
			men += 1
			snowman(f, x, z, -x, -10, scarves[men])
		end
	end

	-- floating snowflake crystals near the castle and the lodge
	for _, p in { V(70, 9, rz(262)), V(118, 12, rz(250)), V(64, 7, rz(318)), V(78, 10, rz(140)), V(120, 8, rz(320)) } do
		local c = Kit.Part(f, V(1.6, 1.6, 1.6), CFrame.new(p) * CFrame.Angles(math.pi / 4, 0.3, math.pi / 4), C(220, 245, 255), { Mat = ICE, Transp = 0.1, Name = "FloatingCrystal" })
		Kit.Float(c, rng:NextNumber(0.6, 1.2))
	end

	-- gentle snowfall over the valley
	local sky = Kit.Part(f, V(260, 1, 340), CFrame.new(0, 48, rz(180)), WHITE, { Transp = 1, Name = "SnowSource" })
	local e = Kit.Emitter(sky, WHITE, 18, 0.5, 1)
	if e then
		e.LightEmission = 0.2
		e.Acceleration = V(0, -3, 0)
		e.Lifetime = NumberRange.new(7, 10)
		e.Size = NumberSequence.new(0.45)
		e.Transparency = NumberSequence.new(0.15)
		e.EmissionDirection = Enum.NormalId.Bottom
	end

	outside(f)
end

return Frost
