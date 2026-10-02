--!strict
-- ZONE 7: Cursed Castle (Z 1920..2280).
--   Z 1926..1936  cosmetic moat (water over a solid floor at Y -0.5: a half-stud wade, no pit)
--                 crossed by a stone bridge on the path (X -12..12).
--   Z 1936..1962  outer bailey: Royal crate station (-28, 1952) and Fast Travel pad (26, 1952).
--   Z 1962..1975  gatehouse (archway X -16..16, clear to Y ~30, 26+ wide at Y 30) flanked by a
--                 crenellated curtain wall out to the side walls.
--   Z 1975..2186  open courtyard (no roofs): every non-boss ghost area, knight statues, a
--                 spectral fountain, braziers, sword in the stone, lawns.
--   Z 2186..2256  open-topped throne room (X -45..45) around the boss area (0, 2220); giant doors
--                 swung outward; the throne sits on a balcony over a 26-wide arch in the back
--                 wall that leads on to the Spirit Realm gate.
--   Library corner X 74..140, Z 2146..2254 (open front/top). Eight round towers with stepped cone
--   roofs (keep towers flank the throne room, tips ~117), cliffs beyond the side walls.
--   Glow: rune ring, cracks, tower windows (half the towers), torches, braziers, candles, the
--   fountain orb and the throne gem. Everything else is stone, wood, metal and fabric.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Castle = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local SLATE = Enum.Material.Slate
local COBBLE = Enum.Material.Cobblestone
local WOOD = Enum.Material.Wood
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local ROCK = Enum.Material.Rock

local Z0, Z1 = 1920, 2280

local STONE = C(150, 150, 166)
local STONE_D = C(112, 114, 132)
local STONE_L = C(188, 188, 200)
local FLOOR = C(132, 130, 148)
local PATH = C(176, 170, 186)
local BLUE = C(55, 78, 150)
local ROOF = C(60, 75, 145)
local ROOF_P = C(100, 60, 150)
local ROYAL_RED = C(175, 40, 70)
local PURPLE = C(125, 65, 175)
local GOLD = C(255, 200, 70)
local SPECTRAL = C(120, 255, 170)
local GHOST_PURPLE = C(190, 120, 255)
local WARM = C(255, 185, 95)
local WOOD_C = C(112, 76, 52)
local IRON = C(60, 62, 78)
local SILVER = C(196, 200, 214)
local ROCKC = C(102, 106, 124)

local SOLID_SLATE: Kit.Opts = { Mat = SLATE, Solid = true, Shadow = true }

--==================================================================
-- HELPERS
--==================================================================
-- Stepped cone roof (stacked cylinders) from y up to y + h, with a gold finial.
local function cone(parent: Instance, x: number, z: number, y: number, d: number, h: number, color: Color3)
	local tiers = 5
	local th = h / tiers
	for i = 0, tiers - 1 do
		local di = d * (1 - i / tiers)
		local col = if i % 2 == 0 then color else color:Lerp(Color3.new(1, 1, 1), 0.12)
		Kit.Cyl(parent, th, di, CFrame.new(x, y + th * (i + 0.5), z), col, { Mat = SLATE, Shadow = true })
	end
	Kit.Ball(parent, math.max(1.2, d * 0.12), V(x, y + h + 0.4, z), Kit.Vivid(GOLD), { Mat = METAL })
end

-- Round tower with crenellated top, cone roof, flag and two windows facing the path.
local function tower(parent: Instance, x: number, z: number, d: number, h: number, roof: Color3, glow: Color3?)
	local m = Kit.Model(parent, "Tower")
	Kit.Cyl(m, 3, d + 3, CFrame.new(x, 1.5, z), STONE_D, SOLID_SLATE)
	Kit.Cyl(m, h, d, CFrame.new(x, h / 2, z), STONE, SOLID_SLATE)
	Kit.Cyl(m, 1.2, d + 0.6, CFrame.new(x, h * 0.62, z), Kit.Vivid(BLUE), { Mat = SLATE })
	Kit.Cyl(m, 4, d + 3, CFrame.new(x, h + 2, z), STONE_L, { Mat = SLATE, Shadow = true })
	local r = (d + 3) / 2 - 1.3
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		Kit.Box(m, V(px - 1.4, h + 4, pz - 1.4), V(px + 1.4, h + 7, pz + 1.4), STONE_L, { Mat = SLATE })
	end
	local coneH = (d - 1) * 1.75
	cone(m, x, z, h + 4, d - 1, coneH, roof)
	local tip = h + 4 + coneH
	Kit.Cyl(m, 6, 0.3, CFrame.new(x, tip + 3, z), IRON, { Mat = METAL })
	Kit.Part(m, V(0.3, 2.6, 4.5), CFrame.new(x, tip + 4.6, z - 2.4), Kit.Vivid(if roof == ROOF then ROYAL_RED else PURPLE), { Mat = FABRIC })
	local dir = if x > 0 then -1 else 1
	local winOpts: Kit.Opts = if glow then { Mat = NEON, Transp = 0.1 } else {}
	for _, wy in { h * 0.42, h * 0.8 } do
		Kit.Part(m, V(2.2, 5, 1), CFrame.new(x + dir * (d / 2 - 0.2), wy, z) * CFrame.Angles(0, Kit.FaceYaw(dir, 0), 0), glow or C(40, 50, 85), winOpts)
	end
	Kit.AddCircle(x, z, d / 2 + 2.5)
end

-- Hanging banner facing (fx, fz); pos = centre of the cloth.
local function banner(parent: Instance, pos: Vector3, w: number, h: number, fx: number, fz: number, color: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local gold = Kit.Vivid(GOLD)
	Kit.Part(parent, V(w, h, 0.3), cf, color, { Mat = FABRIC })
	local e = w * 0.42
	Kit.Part(parent, V(e, e, 0.2), cf * CFrame.new(0, h * 0.12, -0.22) * CFrame.Angles(0, 0, math.pi / 4), gold, { Mat = METAL })
	Kit.Part(parent, V(w + 1.2, 0.5, 0.5), cf * CFrame.new(0, h / 2 + 0.2, 0), gold, { Mat = METAL })
	Kit.Part(parent, V(w, 0.6, 0.36), cf * CFrame.new(0, -h / 2 + 0.3, 0), gold, { Mat = FABRIC })
end

local function knightStatue(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "KnightStatue")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local stone = C(178, 178, 190)
	local so: Kit.Opts = { Mat = Enum.Material.Concrete, Shadow = true }
	Kit.Part(m, V(6, 3, 6), base * CFrame.new(0, 1.5, 0), STONE_D, SOLID_SLATE)
	Kit.Part(m, V(3, 4, 1.8), base * CFrame.new(0, 5, 0), stone, so)
	Kit.Part(m, V(4.2, 4.6, 2.4), base * CFrame.new(0, 9.3, 0), stone, so)
	Kit.Ball(m, 2.8, (base * CFrame.new(0, 12.9, 0)).Position, stone, so)
	Kit.Wedge(m, V(0.6, 1.8, 2.6), base * CFrame.new(0, 14.6, 0.4), Kit.Vivid(ROYAL_RED), { Mat = FABRIC })
	Kit.Part(m, V(3.2, 4.2, 0.5), base * CFrame.new(-2.7, 8.6, -0.9), Kit.Vivid(ROYAL_RED), { Mat = METAL })
	Kit.Part(m, V(1.4, 1.4, 0.2), base * CFrame.new(-2.7, 8.8, -1.2) * CFrame.Angles(0, 0, math.pi / 4), Kit.Vivid(GOLD), { Mat = METAL })
	Kit.Part(m, V(0.5, 9, 0.3), base * CFrame.new(2.6, 9.5, -1.3), SILVER, { Mat = METAL })
	Kit.Part(m, V(2.4, 0.45, 0.45), base * CFrame.new(2.6, 7.2, -1.3), Kit.Vivid(GOLD), { Mat = METAL })
	Kit.AddCircle(x, z, 4.5)
end

local function armor(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "SuitOfArmor")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local mo: Kit.Opts = { Mat = METAL, Refl = 0.15 }
	Kit.Part(m, V(3, 0.6, 3), base * CFrame.new(0, 0.3, 0), WOOD_C, { Mat = WOOD, Solid = true })
	Kit.Part(m, V(1.9, 3.6, 1.2), base * CFrame.new(0, 2.4, 0), SILVER, mo)
	Kit.Part(m, V(2.8, 2.8, 1.6), base * CFrame.new(0, 5.6, 0), SILVER, mo)
	Kit.Part(m, V(3.4, 0.9, 1.8), base * CFrame.new(0, 6.9, 0), Kit.Vivid(GOLD), { Mat = METAL })
	Kit.Part(m, V(1.6, 1.9, 1.6), base * CFrame.new(0, 8.3, 0), SILVER, mo)
	Kit.Part(m, V(1.2, 0.25, 0.12), base * CFrame.new(0, 8.4, -0.82), C(25, 25, 35))
	Kit.Wedge(m, V(0.4, 1.2, 1.6), base * CFrame.new(0, 9.8, 0.2), Kit.Vivid(PURPLE), { Mat = FABRIC })
	Kit.Part(m, V(0.3, 10, 0.3), base * CFrame.new(1.9, 5, -0.5), WOOD_C, { Mat = WOOD })
	Kit.Part(m, V(0.2, 1.8, 1.4), base * CFrame.new(1.9, 9.6, -0.9), SILVER, mo)
	Kit.AddCircle(x, z, 2.5)
end

local function candelabra(parent: Instance, x: number, z: number, light: boolean)
	local m = Kit.Model(parent, "Candelabra")
	local gold = Kit.Vivid(GOLD)
	Kit.Disc(m, x, z, 0.5, 2.4, 0.5, gold, { Mat = METAL })
	Kit.Cyl(m, 6, 0.6, CFrame.new(x, 3.5, z), gold, { Mat = METAL })
	Kit.CylFlat(m, 4.2, 0.4, V(x, 6.5, z), "X", gold, { Mat = METAL })
	for i = -1, 1 do
		Kit.Cyl(m, 1.4, 0.55, CFrame.new(x + i * 1.9, 7.4, z), C(250, 240, 215))
		local flame = Kit.Ball(m, 0.6, V(x + i * 1.9, 8.4, z), WARM, { Mat = NEON })
		if light and i == 0 then
			Kit.Light(flame, WARM, 20, 1.3, true)
		end
	end
	Kit.AddCircle(x, z, 2.5)
end

local function brazier(parent: Instance, x: number, z: number)
	local m = Kit.Model(parent, "Brazier")
	Kit.Cyl(m, 4, 2.4, CFrame.new(x, 2, z), STONE_D, SOLID_SLATE)
	Kit.Cyl(m, 1.6, 4.4, CFrame.new(x, 4.8, z), IRON, { Mat = METAL })
	local flame = Kit.Ball(m, 2.6, V(x, 5.9, z), SPECTRAL, { Mat = NEON, Transp = 0.1 })
	Kit.Light(flame, SPECTRAL, 26, 1.6)
	Kit.AddCircle(x, z, 3)
end

local function crack(parent: Instance, p: Vector3, segs: number)
	local rng = Kit.Rng
	local a = rng:NextNumber(0, math.pi * 2)
	for _ = 1, segs do
		a += rng:NextNumber(-0.9, 0.9)
		local q = p + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(4, 7)
		Props.Beam(parent, p, q, 0.45, 0.06, if rng:NextNumber() < 0.5 then SPECTRAL else GHOST_PURPLE, { Mat = NEON })
		p = q
	end
end

--==================================================================
-- GROUND, MOAT, BRIDGE, PATH, WALLS, CLIFFS
--==================================================================
local function ground(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, 1926), FLOOR, { Mat = COBBLE, Solid = true, Name = "Ground_Castle" })
	Kit.Box(f, V(-190, -4, 1926), V(190, -0.5, 1936), C(60, 72, 95), { Mat = SLATE, Solid = true, Name = "MoatFloor" })
	Kit.Box(f, V(-146, -0.5, 1926), V(146, -0.12, 1936), C(45, 85, 150), { Transp = 0.2, Refl = 0.25, Name = "MoatWater" })
	Kit.Box(f, V(-190, -4, 1936), V(190, 0, Z1), FLOOR, { Mat = COBBLE, Solid = true, Name = "Ground_Castle" })
	-- low stone curbs along the moat banks (steppable)
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 13.6, -0.5, 1925.2), V(s * 140, 0.3, 1926), STONE_D, { Mat = SLATE, Solid = true })
		Kit.Box(f, V(s * 13.6, -0.5, 1936), V(s * 140, 0.3, 1936.8), STONE_D, { Mat = SLATE, Solid = true })
	end
	-- stone bridge over the moat
	Kit.Box(f, V(-12, -0.5, 1923.5), V(12, 0.06, 1938.5), PATH, { Mat = COBBLE, Solid = true, Name = "Bridge" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 12, 0, 1924.5), V(s * 13.6, 3.2, 1937.5), STONE, SOLID_SLATE)
		for _, z in { 1924.5, 1937.5 } do
			Kit.Box(f, V(s * 11.8, 0, z - 1.1), V(s * 14, 4.6, z + 1.1), STONE_L, SOLID_SLATE)
			Kit.Ball(f, 1.8, V(s * 12.9, 5.4, z), Kit.Vivid(GOLD), { Mat = METAL })
		end
	end
	-- main path with blue slate edging
	Kit.Box(f, V(-9, 0, 1938.5), V(9, 0.05, Z1), PATH, { Mat = COBBLE, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 9 - 0.4, 0.05, 1938.5), V(s * 9 + 0.4, 0.12, Z1), Kit.Vivid(BLUE), { Mat = SLATE })
	end
	-- flat lawns in the courtyard
	for _, l in { { 40, 1978, 136, 2062 }, { -136, 1978, -40, 2012 }, { -136, 2070, -92, 2130 }, { 28, 2130, 70, 2186 }, { -46, 2192, -136, 2250 } } do
		Kit.Box(f, V(l[1], 0, l[2]), V(l[3], 0.04, l[4]), C(100, 165, 105), { Mat = Enum.Material.Grass })
	end
end

local function sideWalls(f: Instance)
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, Z0 + 3), V(s * 146, 30, Z1 - 3), STONE, SOLID_SLATE)
		Kit.Box(f, V(s * 139.6, 30, Z0 + 3), V(s * 146.4, 31.2, Z1 - 3), STONE_D, { Mat = SLATE })
		Kit.Box(f, V(s * 139.7, 24, Z0 + 3), V(s * 140, 25.2, Z1 - 3), Kit.Vivid(BLUE), { Mat = SLATE })
		for z = Z0 + 12, Z1 - 12, 16 do
			Kit.Box(f, V(s * 140, 31.2, z - 3), V(s * 146, 35, z + 3), STONE, { Mat = SLATE })
		end
		for _, z in { 2012, 2056, 2146, 2190 } do
			Kit.Box(f, V(s * 137.5, 0, z - 2.5), V(s * 140, 26, z + 2.5), STONE_D, SOLID_SLATE)
		end
		-- spectral crack climbing the wall
		local x = s * 139.75
		local z0 = if s < 0 then 2120 else 2040
		Props.Beam(f, V(x, 2, z0), V(x, 9, z0 + 5), 0.4, 0.4, SPECTRAL, { Mat = NEON })
		Props.Beam(f, V(x, 9, z0 + 5), V(x, 15, z0 + 1), 0.4, 0.4, SPECTRAL, { Mat = NEON })
	end
	-- royal banners on the inner wall faces
	for i, z in { 2034, 2078, 2130 } do
		for _, s in { -1, 1 } do
			banner(f, V(s * 139.5, 15, z), 7, 14, -s, 0, if (i + (if s > 0 then 1 else 0)) % 2 == 0 then ROYAL_RED else PURPLE)
		end
	end
end

local function cliffs(f: Instance)
	local rng = Kit.Rng
	local cols = { ROCKC, C(88, 92, 112), C(115, 118, 138) }
	for _, s in { -1, 1 } do
		for i = 0, 7 do
			local z = 1934 + i * 46
			local w = rng:NextNumber(26, 44)
			local h = rng:NextNumber(42, 66)
			local cf = CFrame.new(s * (149 + w / 2), h / 2 - 3, z) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), s * rng:NextNumber(0.02, 0.08))
			Kit.Part(f, V(w, h, rng:NextNumber(38, 52)), cf, Kit.Pick(cols), { Mat = ROCK })
			Kit.Ball(f, rng:NextNumber(40, 60), V(s * rng:NextNumber(185, 205), rng:NextNumber(4, 18), z + 20), Kit.Pick(cols), { Mat = ROCK })
		end
	end
end

--==================================================================
-- GATEHOUSE + CURTAIN WALL
--==================================================================
local function gatehouse(f: Instance)
	local m = Kit.Model(f, "Gatehouse")
	local zA, zB = 1962, 1975
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 16, 0, zA), V(s * 34, 46, zB), STONE, SOLID_SLATE)
		Kit.Box(m, V(s * 15.6, 0, zA - 0.4), V(s * 34.4, 3, zB + 0.4), STONE_D, SOLID_SLATE)
		for _, mx in { 18.5, 31.5 } do
			for _, mz in { zA + 1.5, zB - 1.5 } do
				Kit.Box(m, V(s * (mx - 1.5), 46, mz - 1.5), V(s * (mx + 1.5), 50, mz + 1.5), STONE_L, { Mat = SLATE })
			end
		end
		-- little turret with a cone roof
		Kit.Cyl(m, 10, 7, CFrame.new(s * 25, 51, (zA + zB) / 2), STONE_L, { Mat = SLATE, Shadow = true })
		cone(m, s * 25, (zA + zB) / 2, 56, 8.5, 13, ROOF_P)
		-- banner and torch on the approach face
		banner(m, V(s * 25, 24, zA - 0.35), 8, 18, 0, -1, if s < 0 then ROYAL_RED else PURPLE)
		local tx = s * 18.2
		Kit.Box(m, V(tx - 0.4, 16.5, zA - 0.8), V(tx + 0.4, 19.5, zA), IRON, { Mat = METAL })
		local flame = Kit.Ball(m, 1.7, V(tx, 20.3, zA - 0.6), WARM, { Mat = NEON })
		Kit.Light(flame, WARM, 26, 1.6)
	end
	-- lintel over the archway (opening X -16..16, Y 0..32) + rounded arch corners
	Kit.Box(m, V(-16, 32, zA + 1), V(16, 46, zB - 1), STONE, SOLID_SLATE)
	Kit.Box(m, V(-16, 32, zA + 0.7), V(16, 33, zB - 0.7), Kit.Vivid(GOLD), { Mat = METAL })
	local mid = (zA + zB) / 2
	Kit.Wedge(m, V(zB - zA - 2, 5, 5), CFrame.fromMatrix(V(-13.5, 29.5, mid), V(0, 0, -1), V(0, -1, 0)), STONE, { Mat = SLATE })
	Kit.Wedge(m, V(zB - zA - 2, 5, 5), CFrame.fromMatrix(V(13.5, 29.5, mid), V(0, 0, 1), V(0, -1, 0)), STONE, { Mat = SLATE })
	-- raised portcullis teeth
	Kit.Box(m, V(-15, 31, mid - 0.4), V(15, 31.6, mid + 0.4), IRON, { Mat = METAL })
	for x = -12, 12, 4 do
		Kit.Box(m, V(x - 0.35, 30.4, mid - 0.3), V(x + 0.35, 32, mid + 0.3), IRON, { Mat = METAL })
	end
	Props.SignBoard(m, V(0, 39.5, zA + 0.6), 26, 5, 0, -1, "CURSED CASTLE", C(45, 35, 80), Kit.Vivid(GOLD), GOLD)

	-- curtain wall from the gatehouse to the side walls
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 34, 0, 1964), V(s * 140, 24, 1972), STONE, SOLID_SLATE)
		Kit.Box(f, V(s * 34, 24, 1963.6), V(s * 140, 25, 1972.4), STONE_D, { Mat = SLATE })
		Kit.Box(f, V(s * 34, 18, 1963.7), V(s * 122, 19, 1964), Kit.Vivid(BLUE), { Mat = SLATE })
		for x = 40, 116, 9.5 do
			Kit.Box(f, V(s * (x - 2), 25, 1963.6), V(s * (x + 2), 28.5, 1966.6), STONE, { Mat = SLATE })
		end
		for i, x in { 58, 96 } do
			banner(f, V(s * x, 12, 1963.4), 7, 14, 0, -1, if i == 1 then ROYAL_RED else PURPLE)
		end
	end
	Kit.AddRect(-140, 1961, -15, 1976)
	Kit.AddRect(15, 1961, 140, 1976)
end

--==================================================================
-- THRONE ROOM
--==================================================================
local function throneRoom(f: Instance)
	local m = Kit.Model(f, "ThroneRoom")
	local wall = C(138, 134, 160)
	local gold = Kit.Vivid(GOLD)
	local H = 28
	-- walls (open top)
	Kit.Box(m, V(-45, 0, 2186), V(-15, H, 2190), wall, SOLID_SLATE)
	Kit.Box(m, V(15, 0, 2186), V(45, H, 2190), wall, SOLID_SLATE)
	Kit.Box(m, V(-45, 0, 2186), V(-42, H, 2256), wall, SOLID_SLATE)
	Kit.Box(m, V(42, 0, 2186), V(45, H, 2256), wall, SOLID_SLATE)
	Kit.Box(m, V(-45, 0, 2248), V(-13, H, 2256), wall, SOLID_SLATE)
	Kit.Box(m, V(13, 0, 2248), V(45, H, 2256), wall, SOLID_SLATE)
	-- balcony over the back arch (opening X -13..13, Y 0..20) carries the throne
	Kit.Box(m, V(-13, 20, 2248), V(13, 24, 2256), wall, SOLID_SLATE)
	Kit.Box(m, V(-13, 20, 2247.7), V(13, 21, 2248), gold, { Mat = METAL })
	-- gold trim and merlons
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 15, 22, 2185.7), V(s * 45, 23, 2186), gold, { Mat = METAL })
		for _, x in { 22, 32, 42 } do
			Kit.Box(m, V(s * (x - 2), H, 2186), V(s * (x + 2), H + 3.5, 2189), wall, { Mat = SLATE })
		end
		for _, z in { 2200, 2218, 2236 } do
			Kit.Box(m, V(s * 42, H, z - 2), V(s * 45, H + 3.5, z + 2), wall, { Mat = SLATE })
		end
	end
	-- lintel + name over the doorway (doorway X -15..15, Y 0..28)
	Kit.Box(m, V(-17, H, 2185.5), V(17, H + 6, 2190.5), STONE_L, SOLID_SLATE)
	Props.SignBoard(m, V(0, H + 3, 2185.1), 24, 4.5, 0, -1, "THRONE ROOM", C(80, 25, 50), gold, GOLD)
	Props.SignBoard(m, V(-24, 9, 2185.4), 9, 3, 0, -1, "BEWARE OF\nTHE KING", C(240, 232, 215), Kit.Vivid(ROYAL_RED))
	-- giant doors, swung outward
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 15, 0, 2171), V(s * 16.6, H, 2186), C(105, 68, 45), { Mat = Enum.Material.WoodPlanks, Solid = true, Shadow = true })
		for _, y in { 5, 14, 23 } do
			Kit.Box(m, V(s * 14.8, y, 2171), V(s * 16.8, y + 1, 2186), IRON, { Mat = METAL })
		end
		Kit.CylFlat(m, 0.4, 2.2, V(s * 14.7, 12, 2174), "X", gold, { Mat = METAL })
		Kit.AddRect(s * 14, 2170, s * 17.5, 2186)
	end
	-- royal carpet (flat) from the doors to the throne
	Kit.Box(m, V(-5, 0, 2166), V(5, 0.08, 2248), Kit.Vivid(ROYAL_RED), { Mat = FABRIC })
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 5 - 0.4, 0, 2166), V(s * 5 + 0.4, 0.1, 2248), gold, { Mat = FABRIC })
	end
	-- columns
	for _, s in { -1, 1 } do
		for _, z in { 2200, 2222, 2244 } do
			Kit.Cyl(m, 24, 3.2, CFrame.new(s * 36, 12, z), STONE_L, SOLID_SLATE)
			Kit.Box(m, V(s * 36 - 2.2, 24, z - 2.2), V(s * 36 + 2.2, 25.2, z + 2.2), gold, { Mat = METAL })
		end
		banner(m, V(s * 41.8, 15, 2211), 6, 14, -s, 0, ROYAL_RED)
		banner(m, V(s * 41.8, 15, 2233), 6, 14, -s, 0, PURPLE)
	end
	candelabra(m, -30, 2195, true)
	candelabra(m, 30, 2195, false)

	-- the throne on the balcony
	Kit.Box(m, V(-8, 24, 2247.5), V(8, 25.2, 2256), gold, { Mat = METAL })
	Kit.Box(m, V(-5.5, 25.2, 2248), V(5.5, 28.6, 2254), Kit.Vivid(PURPLE), { Mat = FABRIC })
	Kit.Box(m, V(-6.5, 25.2, 2253), V(6.5, 46, 2256), Kit.Vivid(ROYAL_RED), { Mat = FABRIC })
	Kit.Box(m, V(-7.6, 25.2, 2253.6), V(7.6, 47.6, 2256.3), gold, { Mat = METAL })
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 5.5, 25.2, 2248), V(s * 7.6, 30.6, 2254), gold, { Mat = METAL })
		Kit.Cyl(m, 3.4, 1.2, CFrame.new(s * 5, 49.3, 2255), gold, { Mat = METAL })
		Kit.Ball(m, 1.6, V(s * 5, 51.4, 2255), Kit.Vivid(ROYAL_RED), { Refl = 0.2 })
	end
	Kit.Cyl(m, 4.4, 1.4, CFrame.new(0, 49.8, 2255), gold, { Mat = METAL })
	local gem = Kit.Ball(m, 2.2, V(0, 52.6, 2255), GHOST_PURPLE, { Mat = NEON })
	Kit.Light(gem, GHOST_PURPLE, 40, 1.8)
	Props.Beam(m, V(-3, 28, 2252.9), V(1, 36, 2252.9), 0.35, 0.35, SPECTRAL, { Mat = NEON })
	Props.Beam(m, V(1, 36, 2252.9), V(-1, 42, 2252.9), 0.35, 0.35, SPECTRAL, { Mat = NEON })
	local mist = Kit.Part(m, V(14, 0.2, 6), CFrame.new(0, 26, 2251), GHOST_PURPLE, { Transp = 1, Name = "FogSource" })
	Kit.Emitter(mist, GHOST_PURPLE, 1.5, 6, 0.4)
	local crown = Kit.Cyl(m, 1.8, 3.4, CFrame.new(0, 58, 2252), gold, { Mat = METAL, Name = "FloatingCrown" })
	Kit.Float(crown, 1.2)

	-- boss area paint: royal disc, gold ring, spectral rune ring (flat)
	Kit.Disc(m, 0, 2220, 0.09, 52, 0.09, gold, { Mat = METAL })
	Kit.Disc(m, 0, 2220, 0.11, 48, 0.11, C(70, 40, 95), { Mat = SLATE })
	for i = 0, 7 do
		local a1 = i * math.pi / 4 + 0.1
		local a2 = a1 + math.pi / 4 - 0.2
		Props.Beam(m, V(math.cos(a1) * 20, 0.15, 2220 + math.sin(a1) * 20), V(math.cos(a2) * 20, 0.15, 2220 + math.sin(a2) * 20), 0.5, 0.06, GHOST_PURPLE, { Mat = NEON })
	end
	Kit.AddRect(-46, 2185, 46, 2257)
end

--==================================================================
-- LIBRARY CORNER (+X back)
--==================================================================
local function library(f: Instance)
	local m = Kit.Model(f, "Library")
	local rng = Kit.Rng
	local shelfC = C(92, 60, 42)
	Kit.Box(m, V(74, 0, 2249), V(140, 22, 2253), STONE, SOLID_SLATE)
	Kit.Box(m, V(74, 0, 2205), V(76, 16, 2230), STONE, SOLID_SLATE)
	Kit.Box(m, V(74, 0, 2230), V(76, 11, 2249), STONE, SOLID_SLATE)
	Kit.Box(m, V(80, 0, 2160), V(134, 0.06, 2244), Kit.Vivid(PURPLE), { Mat = FABRIC })
	Kit.Box(m, V(84, 0, 2164), V(130, 0.08, 2240), C(95, 50, 135), { Mat = FABRIC })
	-- shelves along the back wall (facing -Z), two colours per row
	for _, x in { 84, 100, 116 } do
		Kit.Box(m, V(x - 7, 0, 2245), V(x + 7, 18, 2249), shelfC, { Mat = WOOD, Solid = true })
		for row = 0, 2 do
			local y = 2.5 + row * 5
			local split = rng:NextNumber(-2, 2)
			Kit.Box(m, V(x - 6.3, y, 2244.6), V(x + split, y + 3.6, 2245.1), Kit.Pick(Props.Colors.Book))
			Kit.Box(m, V(x + split, y, 2244.6), V(x + 6.3, y + 3.4, 2245.1), Kit.Pick(Props.Colors.Book))
		end
	end
	-- shelves along the side wall (facing -X)
	for _, z in { 2166, 2184, 2202, 2220 } do
		Kit.Box(m, V(135, 0, z - 7), V(139.5, 18, z + 7), shelfC, { Mat = WOOD, Solid = true })
		for row = 0, 2 do
			local y = 2.5 + row * 5
			Kit.Box(m, V(134.6, y, z - 6.3), V(135.1, y + 3.6, z + 6.3), Kit.Pick(Props.Colors.Book))
		end
	end
	-- ladder
	Props.Beam(m, V(91, 0, 2243.4), V(91.6, 17.5, 2244.6), 0.3, 0.3, shelfC)
	Props.Beam(m, V(93.4, 0, 2243.4), V(94, 17.5, 2244.6), 0.3, 0.3, shelfC)
	-- reading table with candles and a book pile
	Kit.Box(m, V(88, 3, 2190), V(100, 3.8, 2198), shelfC, { Mat = WOOD, Solid = true })
	Kit.Box(m, V(89, 0, 2191), V(90, 3, 2197), shelfC, { Mat = WOOD })
	Kit.Box(m, V(98, 0, 2191), V(99, 3, 2197), shelfC, { Mat = WOOD })
	Kit.Box(m, V(90.5, 3.8, 2192), V(93.5, 4.6, 2196), Kit.Vivid(ROYAL_RED))
	Kit.Box(m, V(90.8, 4.6, 2192.4), V(93.2, 5.3, 2195.6), Kit.Vivid(BLUE))
	for i, x in { 96, 98 } do
		Kit.Cyl(m, 1.6, 0.6, CFrame.new(x, 4.6, 2194), C(250, 240, 215))
		local flame = Kit.Ball(m, 0.6, V(x, 5.7, 2194), WARM, { Mat = NEON })
		if i == 1 then
			Kit.Light(flame, WARM, 24, 1.3, true)
		end
	end
	-- lectern with a giant open spell book
	Kit.Box(m, V(104, 0, 2214), V(107, 4.2, 2217), shelfC, { Mat = WOOD, Solid = true })
	Kit.Part(m, V(6, 0.5, 4.2), CFrame.new(105.5, 4.8, 2215.5) * CFrame.Angles(-0.35, 0, 0), C(250, 245, 230))
	Kit.Part(m, V(2.8, 0.1, 0.25), CFrame.new(105.5, 5.1, 2215.2) * CFrame.Angles(-0.35, 0, 0), SPECTRAL, { Mat = NEON })
	-- floating books and a candle
	Props.FloatingBook(m, V(96, 10, 2214))
	Props.FloatingBook(m, V(112, 12, 2228))
	Props.FloatingBook(m, V(120, 9, 2204))
	Props.FloatingCandle(m, V(106, 10, 2196))
	Props.SignBoard(m, V(100, 20.2, 2248.6), 26, 3.4, 0, -1, "ROYAL LIBRARY - SHHH!", C(50, 35, 80), Kit.Vivid(GOLD), GOLD)
	Kit.AddRect(72, 2146, 140, 2254)
end

--==================================================================
-- COURTYARD FEATURES
--==================================================================
local function fountain(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "SpectralFountain")
	Kit.Disc(m, x, z, 2, 14, 2, STONE_L, SOLID_SLATE)
	Kit.Disc(m, x, z, 2.1, 12, 0.2, C(80, 200, 190), { Transp = 0.25, Refl = 0.2 })
	Kit.Cyl(m, 5, 2, CFrame.new(x, 4.5, z), STONE, { Mat = SLATE })
	Kit.Cyl(m, 1, 6, CFrame.new(x, 7.2, z), STONE_L, { Mat = SLATE })
	local orb = Kit.Ball(m, 2.4, V(x, 8.6, z), SPECTRAL, { Mat = NEON, Transp = 0.1 })
	Kit.Light(orb, SPECTRAL, 24, 1.4)
	Kit.Emitter(orb, SPECTRAL, 2, 5, 0.8)
	Kit.AddCircle(x, z, 8)
end

local function swordInStone(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "SwordInStone")
	Kit.Ball(m, 8, V(x, -1, z), ROCKC, { Mat = ROCK, Solid = true })
	Kit.Part(m, V(0.8, 9, 0.3), CFrame.new(x, 6.5, z) * CFrame.Angles(0, 0.4, 0.06), SILVER, { Mat = METAL, Refl = 0.2 })
	Kit.Part(m, V(3.2, 0.6, 0.6), CFrame.new(x + 0.6, 10.6, z) * CFrame.Angles(0, 0.4, 0.06), Kit.Vivid(GOLD), { Mat = METAL })
	Kit.Part(m, V(0.6, 2.2, 0.6), CFrame.new(x + 0.66, 12, z) * CFrame.Angles(0, 0.4, 0.06), C(90, 50, 40), { Mat = FABRIC })
	Kit.Ball(m, 0.9, V(x + 0.72, 13.3, z), Kit.Vivid(GOLD), { Mat = METAL })
	Props.SignBoard(m, V(x - 4.5, 2.4, z - 3), 5, 2, -1, -1, "TUG ME?", C(240, 232, 215), Kit.Vivid(PURPLE))
	Kit.AddCircle(x, z, 6)
end

local function scatter(f: Instance)
	local rng = Kit.Rng
	local rubble, barrels, broken = 0, 0, 0
	for _ = 1, 400 do
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(1942, 2272)
		if rubble < 10 and Kit.IsFree(x, z, 3) then
			rubble += 1
			Kit.Ball(f, rng:NextNumber(2.5, 4.5), V(x, -0.4, z), Kit.Pick({ ROCKC, STONE_D, STONE }), { Mat = ROCK, Solid = true })
			Kit.Ball(f, rng:NextNumber(1.4, 2.2), V(x + 2, -0.2, z + 1), STONE_D, { Mat = ROCK })
			Kit.AddCircle(x, z, 3)
		elseif barrels < 7 and Kit.IsFree(x, z, 2.5) then
			barrels += 1
			Kit.Cyl(f, 4, 2.8, CFrame.new(x, 2, z), C(140, 95, 60), { Mat = WOOD, Solid = true })
			Kit.Cyl(f, 0.4, 2.95, CFrame.new(x, 2.8, z), IRON, { Mat = METAL })
			Kit.AddCircle(x, z, 2.5)
		elseif broken < 5 and Kit.IsFree(x, z, 5) then
			broken += 1
			local h = rng:NextNumber(5, 11)
			Kit.Box(f, V(x - 2, 0, z - 2), V(x + 2, 1, z + 2), STONE_D, SOLID_SLATE)
			Kit.Cyl(f, h, 3, CFrame.new(x, 1 + h / 2, z) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)), STONE_L, SOLID_SLATE)
			Kit.CylFlat(f, 7, 3, V(x + 1, 1.5, z + 3.5), "X", STONE_L, { Mat = SLATE })
			Kit.AddCircle(x, z, 5)
		end
	end
end

--==================================================================
-- BUILD
--==================================================================
function Castle.Build(map: Instance)
	local f = Kit.Folder(map, "Castle")
	local rng = Kit.Rng

	ground(f)
	sideWalls(f)
	cliffs(f)
	gatehouse(f)

	-- ghost-area paint (flat rune circles; the boss circle is painted by the throne room)
	local areas = { { 0, 2005, 30 }, { -82, 2040, 24 }, { 75, 2100, 26 }, { -62, 2160, 24 } }
	for i, a in areas do
		Kit.Disc(f, a[1], a[2], 0.07, a[3] * 2 + 4, 0.07, Kit.Vivid(if i % 2 == 0 then PURPLE else BLUE), { Mat = SLATE })
		Kit.Disc(f, a[1], a[2], 0.1, a[3] * 2, 0.1, STONE_L, { Mat = SLATE })
		crack(f, V(a[1] + rng:NextNumber(-8, 8), 0.13, a[2] + rng:NextNumber(-8, 8)), 2)
	end

	-- towers: front corners, side middles, back corners and the two keep towers by the throne
	tower(f, -131, 1968, 18, 56, ROOF)
	tower(f, 131, 1968, 18, 56, ROOF)
	tower(f, -128, 2100, 18, 66, ROOF_P, SPECTRAL)
	tower(f, 128, 2100, 18, 66, ROOF_P, SPECTRAL)
	tower(f, -128, 2262, 18, 60, ROOF)
	tower(f, 128, 2262, 18, 60, ROOF)
	tower(f, -60, 2238, 20, 80, ROOF_P, GHOST_PURPLE)
	tower(f, 60, 2238, 20, 80, ROOF_P, GHOST_PURPLE)

	throneRoom(f)
	library(f)

	-- courtyard
	for _, p in { { -22, 2062 }, { 22, 2062 }, { -22, 2122 }, { 22, 2122 } } do
		if Kit.IsFree(p[1], p[2], 4) then
			knightStatue(f, p[1], p[2], if p[1] < 0 then 1 else -1, 0)
		end
	end
	if Kit.IsFree(-31, 2092, 8) then
		fountain(f, -31, 2092)
	end
	if Kit.IsFree(32, 2090, 6) then
		swordInStone(f, 32, 2090)
	end
	for _, s in { -1, 1 } do
		if Kit.IsFree(s * 16, 2150, 2.5, true) then
			brazier(f, s * 16, 2150)
		end
	end
	for _, p in { { -30, 2181, 0, -1 }, { 30, 2181, 0, -1 }, { -50, 1980, 1, 0 }, { 50, 1980, -1, 0 }, { 68, 2150, -1, 0 }, { -70, 2206, 1, 0 } } do
		if Kit.IsFree(p[1], p[2], 2.5) then
			armor(f, p[1], p[2], p[3], p[4])
		end
	end
	scatter(f)
	for _ = 1, 4 do
		crack(f, V(rng:NextNumber(-120, 120), 0.13, rng:NextNumber(1980, 2180)), 1)
	end
end

return Castle
