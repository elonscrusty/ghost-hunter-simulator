--!strict
-- ZONE 17: Lantern Market (Z 7000..7360), the first World 2 area. A cosy night market: dark
-- plum stone tiles, a red-brick lane with gold edging, rows of food stalls with curly red
-- roofs, strings of red paper lanterns across the lane, hundreds of sky lanterns rising.
--   Entry: no gate wall (players come through the portal). A red wall closes the back
--   (Z 6990..6996) and a red-and-gold paifang arch with the "LANTERN MARKET" sign spans the
--   lane at Z 7040, past the BACK TO WORLD 1 portal pad (X -14..14, Z 7002..7026, kept free).
--   Ghost areas get flat festival mats ((0,7085) r30, (-82,7120) r24, (75,7180) r26,
--   (-62,7240) r24); the boss area (0,7305) r26 is a flat red-and-gold dragon-pearl seal with a
--   giant parade dragon floating high above it (bottom ~Y 44).
--   Food stalls (DUMPLINGS, NOODLES, BAO BUNS, ...) face the lane at X +-21; tall red poles at
--   X +-31 carry five lantern strings across the lane (Z 7128..7268).
--   Shophouse facades along both side walls, rooftops and a five-tier pagoda outside on the
--   right (landmark, ~Y 95), a koi pond with a moon bridge, dining tables with parasols, a
--   giant dumpling steamer.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local LanternMarket = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local SLATE = Enum.Material.Slate
local BRICK = Enum.Material.Brick
local WOOD = Enum.Material.Wood
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local CLAY = Enum.Material.ClayRoofTiles

local Z0, Z1 = 7000, 7360

local TILE = C(74, 46, 52)
local TILE_L = C(96, 60, 64)
local LANE = C(160, 52, 48)
local RED = C(205, 42, 48)
local RED_D = C(128, 30, 38)
local GOLD = C(255, 196, 72)
local WOODC = C(105, 62, 42)
local WOOD_D = C(70, 42, 32)
local CREAM = C(250, 236, 208)
local PAPER = C(232, 64, 52)
local GLOW = C(255, 150, 80) -- lit lantern (neon)
local WARM = C(255, 190, 110)
local JADE = C(70, 175, 135)
local BAMBOO = C(205, 170, 95)
local WATER = C(40, 70, 110)

local SOLID_WOOD: Kit.Opts = { Mat = WOOD, Solid = true, Shadow = true }
local GOLD_M: Kit.Opts = { Mat = METAL, Refl = 0.1 }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
-- Red paper lantern hanging from `top` (the cord point). Every lit one is a small neon ball.
local function lantern(parent: Instance, top: Vector3, d: number, lit: boolean)
	local gold = Kit.Vivid(GOLD)
	local c = top - V(0, d * 0.75, 0)
	Kit.Cyl(parent, d * 0.18, d * 0.55, CFrame.new(top - V(0, d * 0.2, 0)), gold, GOLD_M)
	return Kit.Ball(parent, d, c, if lit then GLOW else Kit.Vivid(PAPER), if lit then { Mat = NEON } else { Mat = FABRIC })
end

-- Sagging rope with lanterns between two pole tops (same Z).
local function lanternString(parent: Instance, x1: number, x2: number, y: number, z: number, lit: number)
	local mid = V((x1 + x2) / 2, y - 3, z)
	local a, b = V(x1, y, z), V(x2, y, z)
	Props.Beam(parent, a, mid, 0.25, 0.25, C(60, 30, 30))
	Props.Beam(parent, mid, b, 0.25, 0.25, C(60, 30, 30))
	local n = math.clamp(math.floor(math.abs(x2 - x1) / 9), 5, 9)
	for i = 1, n do
		local t = i / (n + 1)
		local x = x1 + (x2 - x1) * t
		local sag = 3 * (1 - math.abs(2 * t - 1))
		lantern(parent, V(x, y - sag - 0.3, z), 2.2, i % 3 == lit)
	end
end

local function pole(parent: Instance, x: number, z: number, h: number)
	local gold = Kit.Vivid(GOLD)
	Kit.Box(parent, V(x - 1.2, 0, z - 1.2), V(x + 1.2, 1.2, z + 1.2), C(60, 40, 40), { Mat = SLATE, Solid = true })
	Kit.Cyl(parent, h, 1.3, CFrame.new(x, h / 2, z), RED, { Mat = WOOD, Solid = true })
	Kit.Ball(parent, 2, V(x, h + 0.6, z), gold, GOLD_M)
	Kit.AddCircle(x, z, 2)
end

-- Food on a stall counter (local frame: counter top at y = 3.8, front toward local -Z).
local FOODS = { "DUMPLINGS", "NOODLES", "BAO BUNS", "SKEWERS", "BUBBLE TEA", "MOON CAKES", "MANGO ICE", "RICE BALLS", "SESAME BALLS", "FORTUNE COOKIES" }

local function food(m: Instance, cf: CFrame, kind: number)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	if kind == 1 then -- bamboo steamer stacks + dumplings
		for _, sx in { -3, 2.5 } do
			Kit.Cyl(m, 2.2, 3, at(sx, 4.9, -0.8), BAMBOO, { Mat = WOOD })
			Kit.Cyl(m, 0.3, 3.2, at(sx, 5.2, -0.8), C(170, 130, 70), { Mat = WOOD })
			Kit.Cyl(m, 0.5, 3.2, at(sx, 6.2, -0.8), BAMBOO, { Mat = WOOD })
		end
		Kit.Ball(m, 1.1, at(0, 4.3, -1.4).Position, CREAM)
		Kit.Ball(m, 1.1, at(-0.9, 4.3, -1.1).Position, CREAM)
	elseif kind == 2 then -- noodle bowls
		for i = -1, 1 do
			Kit.Cyl(m, 1, 2.2, at(i * 3.2, 4.3, -1), C(245, 245, 250))
			Kit.Cyl(m, 0.2, 1.8, at(i * 3.2, 4.75, -1), C(250, 215, 120))
		end
		Props.Beam(m, at(1.2, 4.9, -1.2).Position, at(2.2, 6.4, -0.6).Position, 0.15, 0.15, WOOD_D)
	elseif kind == 3 then -- bao buns on a tray
		Kit.Part(m, V(7, 0.3, 2.4), at(0, 3.95, -1), RED_D)
		for i = 0, 3 do
			Kit.Ball(m, 1.4, at(-2.4 + i * 1.6, 4.6, -1).Position, CREAM)
		end
	elseif kind == 4 then -- skewers
		for i = 0, 3 do
			local p = at(-2.4 + i * 1.6, 4.9, -1)
			Kit.Part(m, V(0.12, 2.4, 0.12), p, WOOD_D)
			Kit.Part(m, V(0.6, 1.2, 0.6), p * CFrame.new(0, 0.5, 0), if i % 2 == 0 then C(190, 90, 50) else C(120, 190, 80))
		end
	elseif kind == 5 then -- bubble tea cups
		for i = -1, 1 do
			Kit.Cyl(m, 1.8, 1.1, at(i * 2.4, 4.7, -1), C(235, 205, 170), { Transp = 0.2 })
			Kit.Cyl(m, 0.3, 1.2, at(i * 2.4, 5.7, -1), Kit.Vivid(if i == 0 then C(255, 140, 180) else C(140, 220, 255)))
		end
	elseif kind == 6 then -- moon cakes
		for i = 0, 3 do
			Kit.Cyl(m, 0.6, 1.5, at(-2.6 + i * 1.75, 4.1, -1), C(215, 150, 70))
		end
		Kit.Cyl(m, 0.6, 1.5, at(-1.7, 4.7, -1), C(215, 150, 70))
	elseif kind == 7 then -- mango ice
		for i = -1, 1 do
			Kit.Cyl(m, 1, 1.6, at(i * 2.6, 4.3, -1), C(240, 240, 250))
			Kit.Ball(m, 1.5, at(i * 2.6, 5.1, -1).Position, Kit.Vivid(C(255, 175, 60)))
		end
	elseif kind == 8 then -- rice balls
		for i = 0, 2 do
			Kit.Wedge(m, V(1.4, 1.3, 0.7), at(-2 + i * 2, 4.45, -1.3), CREAM)
			Kit.Wedge(m, V(1.4, 1.3, 0.7), at(-2 + i * 2, 4.45, -0.6) * CFrame.Angles(0, math.pi, 0), CREAM)
		end
	elseif kind == 9 then -- sesame balls in a basket
		Kit.Cyl(m, 0.8, 4, at(0, 4.2, -1), BAMBOO, { Mat = WOOD })
		for i = 0, 2 do
			Kit.Ball(m, 1.2, at(-1 + i, 4.9, -1).Position, C(230, 170, 80))
		end
	else -- fortune cookies + a jar
		Kit.Cyl(m, 2.4, 2, at(2, 5, -0.8), C(200, 230, 255), { Transp = 0.4, Refl = 0.2 })
		for i = 0, 2 do
			Kit.Wedge(m, V(1.2, 0.6, 0.9), at(-2.5 + i * 1.3, 4.1, -1.2), C(235, 180, 90))
		end
	end
end

-- Food stall facing the lane. side = -1 (left of the lane) or 1.
local function stall(parent: Instance, x: number, z: number, side: number, kind: number, litLantern: boolean)
	local m = Kit.Model(parent, "FoodStall")
	local gold = Kit.Vivid(GOLD)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(-side, 0), 0)
	local roofCol = if kind % 2 == 0 then RED else C(225, 70, 45)
	Kit.Part(m, V(12, 3.6, 3), cf * CFrame.new(0, 1.8, -1.2), RED_D, SOLID_WOOD)
	Kit.Part(m, V(12.6, 0.4, 3.6), cf * CFrame.new(0, 3.8, -1.2), WOODC, { Mat = WOOD })
	Kit.Part(m, V(12.2, 0.5, 0.2), cf * CFrame.new(0, 2.4, -2.8), gold)
	Kit.Part(m, V(12, 10, 0.6), cf * CFrame.new(0, 5, 2.8), WOOD_D, SOLID_WOOD)
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(0.7, 10, 0.7), cf * CFrame.new(sx * 5.8, 5, -2.6), roofCol, { Mat = WOOD })
	end
	-- sloped tiled roof with a gold ridge and curly gold eave tips
	Kit.Wedge(m, V(14, 2.4, 8.4), cf * CFrame.new(0, 11.2, -0.6), roofCol, { Mat = CLAY })
	Kit.Part(m, V(14.4, 0.5, 0.7), cf * CFrame.new(0, 12.5, 3.4), gold, GOLD_M)
	Kit.Part(m, V(14, 1, 0.2), cf * CFrame.new(0, 9.6, -4.5), gold, { Mat = FABRIC })
	-- name board over the roof edge
	local sign = Props.SignBoard(m, (cf * CFrame.new(0, 14.4, 2.4)).Position, 9, 2.4, -side, 0, FOODS[kind], RED_D, CREAM)
	sign.Name = "StallSign"
	lantern(m, (cf * CFrame.new(if litLantern then -6 else 6, 9.1, -4.4)).Position, 1.8, litLantern)
	food(m, cf, kind)
	Kit.AddCircle(x, z, 8)
end

local function diningTable(parent: Instance, x: number, z: number, umbrella: Color3)
	local m = Kit.Model(parent, "DiningTable")
	Kit.Cyl(m, 3, 0.8, CFrame.new(x, 1.5, z), WOOD_D, { Mat = WOOD })
	Kit.Disc(m, x, z, 3.2, 5, 0.3, WOODC, { Mat = WOOD, Solid = true })
	for i = 0, 3 do
		local a = i * math.pi / 2 + 0.4
		Kit.Cyl(m, 1.8, 1.8, CFrame.new(x + math.cos(a) * 3.8, 0.9, z + math.sin(a) * 3.8), RED, { Mat = WOOD })
	end
	-- paper parasol: stacked discs
	Kit.Cyl(m, 8, 0.3, CFrame.new(x, 7, z), WOOD_D)
	Kit.Disc(m, x, z, 9.4, 11, 0.4, umbrella, { Mat = FABRIC })
	Kit.Disc(m, x, z, 10, 7, 0.6, umbrella, { Mat = FABRIC })
	Kit.Disc(m, x, z, 10.6, 2.4, 0.6, Kit.Vivid(GOLD))
	Kit.Cyl(m, 1, 0.6, CFrame.new(x, 3.8, z), CREAM)
	Kit.AddCircle(x, z, 6)
end

--==================================================================
-- GROUND, BACK WALL, ENTRANCE ARCH
--==================================================================
local function ground(f: Instance)
	local gold = Kit.Vivid(GOLD)
	Kit.Box(f, V(-190, -4, Z0 - 12), V(190, 0, Z1), TILE, { Mat = SLATE, Solid = true, Name = "Ground_LanternMarket" })
	Kit.Box(f, V(-9, 0, Z0 - 8), V(9, 0.05, Z1), LANE, { Mat = BRICK, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 9, 0, Z0 - 8), V(s * 10.5, 0.07, Z1), gold, { Mat = SLATE })
	end
	-- lighter paving squares in a loose grid beside the lane
	for z = Z0 + 20, Z1 - 15, 30 do
		for _, x in { -100, 100 } do
			if Kit.IsFree(x, z, 5) then
				Kit.Part(f, V(9, 0.04, 9), CFrame.new(x, 0.02, z) * CFrame.Angles(0, math.pi / 4, 0), TILE_L, { Mat = SLATE })
			end
		end
	end
	-- festival mats on the ghost areas: gold rim, red, cream ring, red petals, gold centre
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		Kit.Disc(f, x, z, 0.08, r * 2 + 3, 0.08, gold, { Mat = SLATE })
		Kit.Disc(f, x, z, 0.11, r * 2, 0.11, if i % 2 == 0 then RED_D else RED, { Mat = FABRIC })
		Kit.Disc(f, x, z, 0.14, r * 1.1, 0.03, CREAM, { Mat = FABRIC })
		Kit.Disc(f, x, z, 0.16, r * 1.0, 0.05, if i % 2 == 0 then RED else RED_D, { Mat = FABRIC })
		for k = 0, 7 do
			local ang = k * math.pi / 4
			Kit.Part(f, V(3, 0.04, 3), CFrame.new(x + math.cos(ang) * r * 0.78, 0.15, z + math.sin(ang) * r * 0.78) * CFrame.Angles(0, ang + math.pi / 4, 0), gold, { Mat = FABRIC })
		end
		Kit.Disc(f, x, z, 0.18, 6, 0.18, gold, GOLD_M)
	end
	-- boss: dragon-pearl seal (red, gold rings, a flat coiled dragon of gold scales, a pearl)
	Kit.Disc(f, 0, BOSS_Z, 0.08, 58, 0.08, gold, GOLD_M)
	Kit.Disc(f, 0, BOSS_Z, 0.11, 54, 0.11, RED_D, { Mat = SLATE })
	Kit.Disc(f, 0, BOSS_Z, 0.14, 40, 0.03, gold, GOLD_M)
	Kit.Disc(f, 0, BOSS_Z, 0.16, 38, 0.05, RED, { Mat = SLATE })
	for k = 0, 17 do
		local t = k / 18
		local ang = t * math.pi * 3.2
		local rr = 6 + t * 11
		local d = 3.4 - t * 1.4
		Kit.Disc(f, math.cos(ang) * rr, BOSS_Z + math.sin(ang) * rr, 0.19, d, 0.03, if k % 2 == 0 then gold else C(255, 150, 60), { Mat = SLATE })
	end
	Kit.Disc(f, 0, BOSS_Z, 0.21, 6, 0.05, CREAM, { Mat = Enum.Material.Marble, Refl = 0.2 })
end

local function backWall(f: Instance)
	local gold = Kit.Vivid(GOLD)
	local z0, z1 = Z0 - 10, Z0 - 4
	-- visual only: the World 2 boundary owns the collision at the back edge (the route check
	-- walks through here from the portal gap)
	Kit.Box(f, V(-146, 0, z0), V(146, 18, z1), RED_D, { Mat = BRICK, Shadow = true, Name = "MarketBackWall" })
	Kit.Box(f, V(-147, 18, z0 - 1), V(147, 19.2, z1 + 1), C(60, 40, 40), { Mat = CLAY })
	Kit.Box(f, V(-146, 15, z1), V(146, 15.8, z1 + 0.3), gold)
	-- round moon windows with lattice
	for _, x in { -100, -55, 55, 100 } do
		Kit.CylFlat(f, 0.4, 10, V(x, 9, z1 + 0.1), "Z", gold, GOLD_M)
		Kit.CylFlat(f, 0.5, 8.6, V(x, 9, z1 + 0.15), "Z", C(40, 25, 30))
		Kit.Box(f, V(x - 4.2, 8.8, z1 + 0.3), V(x + 4.2, 9.2, z1 + 0.5), gold)
		Kit.Box(f, V(x - 0.2, 4.8, z1 + 0.3), V(x + 0.2, 13.2, z1 + 0.5), gold)
	end
	for _, x in { -30, 30 } do
		lantern(f, V(x, 17, z1 + 1.2), 3, true)
	end
end

local function entranceArch(f: Instance)
	local m = Kit.Model(f, "MarketArch")
	local gold = Kit.Vivid(GOLD)
	local z = Z0 + 40 -- past the BACK TO WORLD 1 portal pad (X -14..14, Z 7002..7026)
	for _, s in { -1, 1 } do
		local x = s * 14
		Kit.Box(m, V(x - 2.2, 0, z - 2.2), V(x + 2.2, 2, z + 2.2), C(60, 40, 40), { Mat = SLATE, Solid = true })
		Kit.Cyl(m, 26, 2.6, CFrame.new(x, 15, z), RED, { Mat = WOOD, Solid = true, Shadow = true })
		Kit.Cyl(m, 1, 3.2, CFrame.new(x, 2.5, z), gold, GOLD_M)
		lantern(m, V(x - s * 3.6, 18.8, z), 2.6, true)
		Kit.AddCircle(x, z, 3)
	end
	Kit.Box(m, V(-18, 19, z - 1.2), V(18, 20.6, z + 1.2), RED_D, { Mat = WOOD })
	Kit.Box(m, V(-19, 25, z - 1.5), V(19, 27.2, z + 1.5), RED, { Mat = WOOD, Shadow = true })
	-- tiled roof: two slopes + gold ridge + curled ends
	Kit.Wedge(m, V(44, 3, 4), CFrame.new(0, 28.7, z - 2), C(60, 40, 40), { Mat = CLAY })
	Kit.Wedge(m, V(44, 3, 4), CFrame.new(0, 28.7, z + 2) * CFrame.Angles(0, math.pi, 0), C(60, 40, 40), { Mat = CLAY })
	Kit.Box(m, V(-22, 30.2, z - 0.5), V(22, 31, z + 0.5), gold, GOLD_M)
	for _, s in { -1, 1 } do
		Kit.Wedge(m, V(1.4, 3, 3), CFrame.new(s * 22.5, 31, z) * CFrame.Angles(0, s * math.pi / 2, 0), gold, GOLD_M)
	end
	local sign = Props.SignBoard(m, V(0, 22.8, z - 1.4), 22, 3.6, 0, -1, "LANTERN MARKET", RED_D, Kit.Vivid(GOLD), gold)
	Props.SignBoard(m, V(0, 22.8, z + 1.4), 22, 3.6, 0, 1, "LANTERN MARKET", RED_D, Kit.Vivid(GOLD))
	Kit.Light(sign, WARM, 30, 1.2)
end

--==================================================================
-- SIDE WALLS (shophouse facades) AND OUTSIDE
--==================================================================
local function sideWalls(f: Instance)
	local gold = Kit.Vivid(GOLD)
	local z0, z1 = Z0 - 4, Z1 - 3
	local facade = { C(120, 40, 45), C(150, 95, 70), C(95, 50, 60), C(140, 60, 50) }
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 22, z1), RED_D, { Mat = BRICK, Solid = true, Shadow = true })
		Kit.Wedge(f, V(z1 - z0, 2.4, 3.6), CFrame.new(s * 138.2, 9.6, (z0 + z1) / 2) * CFrame.Angles(0, Kit.FaceYaw(-s, 0), 0), C(60, 40, 40), { Mat = CLAY })
		Kit.Box(f, V(s * 139, 22, z0), V(s * 147, 23.4, z1), C(60, 40, 40), { Mat = CLAY })
		Kit.Box(f, V(s * 139.6, 23.4, z0), V(s * 140.4, 24, z1), gold, GOLD_M)
		local i = 0
		for z = z0 + 18, z1 - 10, 30 do
			i += 1
			-- shopfront panel, two upstairs windows, a hanging banner
			Kit.Box(f, V(s * 139.6, 0, z - 9), V(s * 140, 7, z + 9), facade[i % #facade + 1], { Mat = WOOD })
			Kit.Box(f, V(s * 139.4, 5.5, z - 9.5), V(s * 139.8, 6.2, z + 9.5), gold)
			for _, dz in { -5, 5 } do
				local lit = (i + dz) % 3 == 0
				Kit.Box(f, V(s * 139.5, 13, z + dz - 2.2), V(s * 139.9, 18, z + dz + 2.2), if lit then C(255, 205, 130) else C(70, 45, 50), { Mat = Enum.Material.Glass })
			end
			if i % 2 == 0 then
				local banner = Kit.Box(f, V(s * 138.9, 13, z - 1.4), V(s * 139.3, 20.5, z + 1.4), if i % 4 == 0 then JADE else RED, { Mat = FABRIC })
				Kit.Sign(banner, if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left, if i % 4 == 0 then "TEA" else "EAT", CREAM)
			end
		end
	end
end

local function outside(f: Instance)
	local rng = Kit.Rng
	local gold = Kit.Vivid(GOLD)
	local walls = { C(120, 45, 50), C(150, 100, 80), C(100, 60, 70) }
	-- rooftops beyond the side walls
	for z = Z0 + 10, Z1 - 20, 58 do
		for _, s in { -1, 1 } do
			local x = s * rng:NextNumber(156, 170)
			local w, h, d = rng:NextNumber(18, 26), rng:NextNumber(26, 40), rng:NextNumber(24, 34)
			Kit.Box(f, V(x - w / 2, 0, z - d / 2), V(x + w / 2, h, z + d / 2), Kit.Pick(walls), { Mat = BRICK })
			Kit.Wedge(f, V(w + 4, 5, d / 2 + 2), CFrame.new(x, h + 2.5, z - d / 4 - 0.5), C(60, 40, 40), { Mat = CLAY })
			Kit.Wedge(f, V(w + 4, 5, d / 2 + 2), CFrame.new(x, h + 2.5, z + d / 4 + 0.5) * CFrame.Angles(0, math.pi, 0), C(60, 40, 40), { Mat = CLAY })
			Kit.Box(f, V(x - w / 2 - 2, h + 4.6, z - 0.4), V(x + w / 2 + 2, h + 5.4, z + 0.4), gold)
			if (z // 58) % 2 == 0 then
				Kit.Box(f, V(x - s * (w / 2 + 0.2) - 1.5, h * 0.55, z - 2.5), V(x - s * (w / 2 + 0.2) + 1.5, h * 0.55 + 4, z + 2.5), C(255, 200, 120), { Mat = NEON })
			end
		end
	end
	-- five-tier pagoda (landmark, outside the right wall)
	local m = Kit.Model(f, "Pagoda")
	local px, pz = 172, Z0 + 215
	local y = 0
	for t = 0, 4 do
		local w = 30 - t * 4.5
		local h = if t == 0 then 16 else 11
		Kit.Box(m, V(px - w / 2, y, pz - w / 2), V(px + w / 2, y + h, pz + w / 2), if t % 2 == 0 then RED else RED_D, { Mat = WOOD })
		local e = w + 9
		y += h
		Kit.Box(m, V(px - e / 2, y, pz - e / 2), V(px + e / 2, y + 1, pz + e / 2), C(60, 40, 40), { Mat = CLAY })
		for k = 0, 3 do
			local ang = k * math.pi / 2
			local cf = CFrame.new(px, y + 2, pz) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -e / 4)
			Kit.Wedge(m, V(e, 2.6, e / 2), cf, C(60, 40, 40), { Mat = CLAY })
		end
		Kit.Box(m, V(px - e / 2 - 0.2, y - 0.3, pz - e / 2 - 0.2), V(px + e / 2 + 0.2, y + 0.2, pz + e / 2 + 0.2), gold, GOLD_M)
		lantern(m, V(px - e / 2 + 1, y - 0.4, pz - e / 2 + 1), 2.4, t % 2 == 0)
		y += 3.3
	end
	Kit.Cyl(m, 14, 1, CFrame.new(px, y + 7, pz), gold, GOLD_M)
	for k = 0, 2 do
		Kit.Disc(m, px, pz, y + 4 + k * 3.2, 4 - k, 0.7, gold, GOLD_M)
	end
	Kit.Ball(m, 2.2, V(px, y + 14.5, pz), gold, GOLD_M)
end

--==================================================================
-- LANES, STALLS, LANTERNS
--==================================================================
local function stalls(f: Instance)
	local zs = { Z0 + 44, Z0 + 128, Z0 + 150, Z0 + 172, Z0 + 196, Z0 + 218, Z0 + 242, Z0 + 266, Z0 + 340 }
	local kind = 0
	for _, z in zs do
		for _, s in { -1, 1 } do
			if kind < 10 and Kit.IsFree(s * 21, z, 7.5) then
				kind += 1
				stall(f, s * 21, z, s, (kind - 1) % #FOODS + 1, kind % 3 == 1)
			end
		end
	end
	-- a few more stalls out in the side squares, also facing the lane
	local extra = 0
	for _, p in { { 58, Z0 + 44 }, { -60, Z0 + 52 }, { 118, Z0 + 130 }, { -118, Z0 + 196 }, { 118, Z0 + 286 }, { -100, Z0 + 300 }, { 60, Z0 + 250 } } do
		if extra < 5 and Kit.IsFree(p[1], p[2], 7.5) then
			extra += 1
			kind += 1
			stall(f, p[1], p[2], if p[1] < 0 then -1 else 1, (kind - 1) % #FOODS + 1, extra % 2 == 1)
		end
	end
end

-- True when a rope along X between x1 and x2 at z stays clear of every ghost circle.
local function ropeClear(x1: number, x2: number, z: number): boolean
	local lo, hi = math.min(x1, x2), math.max(x1, x2)
	for _, a in { AREAS[1], AREAS[2], AREAS[3], AREAS[4], { 0, BOSS_Z, 26 } } do
		local cx = math.clamp(a[1], lo, hi)
		local dx, dz = a[1] - cx, a[2] - z
		if dx * dx + dz * dz < (a[3] + 2) ^ 2 then
			return false
		end
	end
	return true
end

local function strings(f: Instance)
	for i, z in { Z0 + 139, Z0 + 161, Z0 + 207, Z0 + 230, Z0 + 254 } do
		local ok = Kit.IsFree(-31, z, 1.5) and Kit.IsFree(31, z, 1.5)
		if ok then
			pole(f, -31, z, 24)
			pole(f, 31, z, 24)
			lanternString(f, -31, 31, 23.5, z, i % 3)
			-- side strings from the pole tops to the shophouse eaves, where no ghost area is below
			for _, s in { -1, 1 } do
				if ropeClear(s * 31, s * 138, z) then
					lanternString(f, s * 31, s * 138, 23, z, (i + 1) % 3)
				end
			end
		end
	end
end

-- Sky lanterns drifting up above the market (all above Y 44).
local function skyLanterns(f: Instance)
	local rng = Kit.Rng
	for i = 1, 26 do
		local x = rng:NextNumber(-150, 150)
		local z = rng:NextNumber(Z0 + 10, Z1 - 10)
		local y = rng:NextNumber(46, 120)
		local d = rng:NextNumber(1.6, 2.8)
		local lit = i % 3 == 0
		local p = Kit.Cyl(f, d * 1.3, d, CFrame.new(x, y, z), if lit then C(255, 175, 100) else C(250, 120, 80), if lit then { Mat = NEON, Name = "SkyLantern" } else { Mat = FABRIC, Name = "SkyLantern" })
		if i <= 3 then
			Kit.Float(p, rng:NextNumber(1.5, 2.5))
		end
	end
end

--==================================================================
-- DECOR: pond, tables, steamer, dragon
--==================================================================
local function pond(f: Instance)
	local x, z = 102, Z0 + 92
	if not Kit.IsFree(x, z, 17) then
		return
	end
	local m = Kit.Model(f, "KoiPond")
	local gold = Kit.Vivid(GOLD)
	Kit.Disc(m, x, z, 0.06, 32, 0.06, C(120, 110, 105), { Mat = SLATE })
	Kit.Disc(m, x, z, 0.1, 28, 0.08, WATER, { Mat = Enum.Material.Glass, Refl = 0.25 })
	for _ = 1, 9 do
		local a, r = Kit.Rng:NextNumber(0, math.pi * 2), Kit.Rng:NextNumber(3, 12)
		Kit.Part(m, V(1.4, 0.06, 0.7), CFrame.new(x + math.cos(a) * r, 0.14, z + math.sin(a) * r) * CFrame.Angles(0, a, 0), Kit.Pick({ C(255, 140, 50), CREAM, C(240, 70, 50) }))
	end
	for _ = 1, 5 do
		local a, r = Kit.Rng:NextNumber(0, math.pi * 2), Kit.Rng:NextNumber(5, 12)
		Kit.Disc(m, x + math.cos(a) * r, z + math.sin(a) * r, 0.18, 2.4, 0.04, C(90, 170, 90))
	end
	-- arched moon bridge across the pond (along X)
	local n = 7
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local bx = x - 16 + 32 * t
		local by = math.sin(t * math.pi) * 6
		Kit.Part(m, V(32 / n + 0.4, 0.8, 6), CFrame.new(bx, by + 0.4, z) * CFrame.Angles(0, 0, math.cos(t * math.pi) * 0.6), RED, { Mat = WOOD, Solid = true })
		for _, sz in { -1, 1 } do
			Kit.Part(m, V(32 / n + 0.2, 0.4, 0.4), CFrame.new(bx, by + 2.6, z + sz * 2.8) * CFrame.Angles(0, 0, math.cos(t * math.pi) * 0.6), gold, GOLD_M)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.Box(m, V(x + sx * 16 - 0.4, 0, z + sz * 2.8 - 0.4), V(x + sx * 16 + 0.4, 3.4, z + sz * 2.8 + 0.4), RED, { Mat = WOOD })
		end
	end
	Kit.AddCircle(x, z, 17)
end

local function steamer(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "GiantSteamer")
	Kit.Cyl(m, 5, 16, CFrame.new(x, 2.5, z), BAMBOO, { Mat = WOOD, Solid = true, Shadow = true })
	Kit.Cyl(m, 0.8, 16.6, CFrame.new(x, 5.2, z), C(170, 130, 70), { Mat = WOOD })
	Kit.Cyl(m, 4, 16, CFrame.new(x, 7.6, z), BAMBOO, { Mat = WOOD, Solid = true })
	Kit.Cyl(m, 0.8, 16.6, CFrame.new(x, 9.8, z), C(170, 130, 70), { Mat = WOOD })
	for i = 0, 3 do
		Kit.Ball(m, 4.4, V(x + (i % 2) * 5 - 2.5, 11.4, z + (i // 2) * 5 - 2.5), CREAM)
		Kit.Ball(m, 1.2, V(x + (i % 2) * 5 - 2.5, 13.6, z + (i // 2) * 5 - 2.5), CREAM)
	end
	local steam = Kit.Part(m, V(10, 1, 10), CFrame.new(x, 13, z), CREAM, { Transp = 1, Name = "Steam" })
	Kit.Emitter(steam, C(255, 250, 245), 3, 5, 1.2)
	Props.SignBoard(m, V(x, 3, z - 8.4), 10, 2, 0, -1, "BIGGEST DUMPLINGS", RED_D, CREAM)
	Kit.AddCircle(x, z, 9.5)
end

-- Festival parade dragon floating high over the boss seal (all parts above Y 44).
local function dragon(f: Instance)
	local m = Kit.Model(f, "ParadeDragon")
	local gold = Kit.Vivid(GOLD)
	local n = 16
	local pts: { Vector3 } = {}
	for i = 0, n - 1 do
		local t = i / (n - 1)
		table.insert(pts, V(-62 + 124 * t, 54 + math.sin(t * math.pi * 3) * 5, BOSS_Z + 8 + math.cos(t * math.pi * 2) * 8))
	end
	for i, p in pts do
		local d = if i <= 2 then 8 else 7.4 - i * 0.22
		Kit.Ball(m, d, p, if i % 2 == 0 then RED else C(230, 70, 40), { Mat = FABRIC })
		if i % 2 == 1 then
			Kit.Wedge(m, V(0.6, 2.2, 2.4), CFrame.new(p + V(0, d / 2 + 0.6, 0)) * CFrame.Angles(0, math.pi / 2, 0), gold, GOLD_M)
		end
		if i % 3 == 0 then
			Kit.Ball(m, d * 0.5, p + V(0, -d * 0.36, 0), CREAM)
		end
	end
	-- head at the -X end, facing -X
	local h = pts[1] - V(6, -1, 0)
	local hc = CFrame.new(h) * CFrame.Angles(0, Kit.FaceYaw(-1, 0), 0)
	Kit.Part(m, V(8, 6, 9), hc, RED, { Mat = FABRIC })
	Kit.Part(m, V(7, 2, 6), hc * CFrame.new(0, -3.4, -2.4), Kit.Vivid(GOLD), { Mat = FABRIC })
	Kit.Part(m, V(7.4, 1.2, 1), hc * CFrame.new(0, -2.2, -5.2), CREAM)
	for _, sx in { -1, 1 } do
		Kit.Ball(m, 2.6, (hc * CFrame.new(sx * 2.4, 2, -4)).Position, CREAM)
		Kit.Ball(m, 1.3, (hc * CFrame.new(sx * 2.4, 2.1, -5.1)).Position, C(30, 25, 30))
		Props.Beam(m, (hc * CFrame.new(sx * 1.5, 4, 1)).Position, (hc * CFrame.new(sx * 3.5, 9, 4)).Position, 0.8, 0.8, gold, GOLD_M)
		Props.Beam(m, (hc * CFrame.new(sx * 3, -1, -4.6)).Position, (hc * CFrame.new(sx * 8, -3, -8)).Position, 0.25, 0.25, gold)
		Kit.Ball(m, 3, (hc * CFrame.new(sx * 4, 0, 1)).Position, Kit.Vivid(C(255, 220, 120)), { Mat = FABRIC })
	end
	-- the pearl it chases
	local pearl = Kit.Ball(m, 4, h + V(-12, -2, 0), C(255, 240, 220), { Mat = NEON })
	Kit.Light(pearl, WARM, 40, 1.2)
	-- gold tail fan at the +X end
	local tl = pts[n] + V(4, 0, 0)
	for k = -1, 1 do
		Kit.Part(m, V(5, 0.6, 2), CFrame.new(tl) * CFrame.Angles(0, k * 0.5, 0) * CFrame.new(2.4, 0, 0), gold, GOLD_M)
	end
end

local function decor(f: Instance)
	pond(f)
	local umbrellas = { RED, Kit.Vivid(GOLD), JADE, C(240, 120, 60) }
	local nt = 0
	for _, p in { { 48, Z0 + 46 }, { -60, Z0 + 52 }, { 110, Z0 + 140 }, { -118, Z0 + 172 }, { 40, Z0 + 238 }, { 112, Z0 + 250 }, { -110, Z0 + 290 }, { 60, Z0 + 300 }, { -45, Z0 + 330 } } do
		if Kit.IsFree(p[1], p[2], 6) then
			nt += 1
			diningTable(f, p[1], p[2], umbrellas[nt % #umbrellas + 1])
		end
	end
	if Kit.IsFree(-112, Z0 + 60, 9.5) then
		steamer(f, -112, Z0 + 60)
	end
	-- lantern trees: dark trunks with lanterns on every branch
	for _, p in { { 115, Z0 + 205 }, { -118, Z0 + 228 }, { 120, Z0 + 320 }, { -40, Z0 + 180 } } do
		if Kit.IsFree(p[1], p[2], 4) then
			local x, z = p[1], p[2]
			Kit.Cyl(f, 14, 1.8, CFrame.new(x, 7, z), WOOD_D, { Mat = WOOD, Solid = true })
			for k = 0, 3 do
				local a = k * math.pi / 2 + 0.3
				local tip = V(x + math.cos(a) * 6, 16 + (k % 2) * 2, z + math.sin(a) * 6)
				Props.Beam(f, V(x, 12, z), tip, 0.7, 0.7, WOOD_D)
				lantern(f, tip - V(0, 0.2, 0), 2, k == 0)
			end
			Kit.AddCircle(x, z, 4)
		end
	end
	-- stacked tea crates and barrels
	for _, p in { { 132, Z0 + 60 }, { -132, Z0 + 140 }, { 132, Z0 + 280 }, { -132, Z0 + 330 }, { 132, Z0 + 120 } } do
		if Kit.IsFree(p[1], p[2], 4) then
			local x, z = p[1], p[2]
			Kit.Box(f, V(x - 2.5, 0, z - 2.5), V(x + 2.5, 4, z + 2.5), WOODC, SOLID_WOOD)
			Kit.Box(f, V(x - 2, 4, z - 1), V(x + 2, 7, z + 3), C(150, 100, 60), { Mat = WOOD })
			Kit.Cyl(f, 4.5, 3.6, CFrame.new(x, 2.25, z + 5), WOOD_D, { Mat = WOOD, Solid = true })
			Kit.AddCircle(x, z + 2, 4.5)
		end
	end
	dragon(f)
end

--==================================================================
-- BUILD
--==================================================================
function LanternMarket.Build(map: Instance)
	local f = Kit.Folder(map, "LanternMarket")
	-- the core builder's BACK TO WORLD 1 portal + pad: keep it clear of every prop
	Kit.AddRect(-16, Z0, 16, Z0 + 28)
	ground(f)
	backWall(f)
	entranceArch(f)
	sideWalls(f)
	outside(f)
	stalls(f)
	strings(f)
	skyLanterns(f)
	decor(f)
end

return LanternMarket
