--!strict
-- ZONE 16: The Ghost King's Throne (Z 5200..5560), the final area. A floating royal palace in
-- the clouds: white marble, gold, royal purple and soft lavender.
--   Ground: marble slab + royal purple carpet along X = 0 with gold borders.
--   Ghost areas get flat gold-and-lavender medallions ((0,5285) r30, (-82,5320) r24,
--   (75,5380) r26, (-62,5440) r24); the boss area (0,5505) r28 is the royal seal. Nothing
--   stands in or above the boss circle (the Ghost King is huge and hovers at Y ~14).
--   Grand colonnades at X +-22 (Z 5325..5465) with banners, golden ghost-king statues,
--   floating chandeliers over the carpet (Y ~55), golden urns, lavender planters.
--   Grand final backdrop BEHIND the end of the play area (Z >= 5557, past the boss circle and
--   clear of the route check): the gigantic throne (crown tip ~Y 142, seen from the Inferno),
--   twin grand staircases up to a palace terrace, the palace facade with corner towers and the
--   "THE END... FOR NOW" banner. Cloud banks outside the side walls and behind the palace.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Throne = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local MARBLE = Enum.Material.Marble
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric

local Z0, Z1 = 5200, 5560
local BACK = Z1 - 3 -- the backdrop starts here (route check ends at Z1 - 4)

local WHITE = C(245, 242, 250)
local MARBLE_L = C(225, 215, 245) -- soft lavender marble
local LAVENDER = C(190, 160, 240)
local PURPLE = C(120, 65, 185)
local PURPLE_D = C(80, 40, 130)
local GOLD = C(255, 210, 90)
local CLOUD = C(250, 250, 255)
local CLOUD_S = C(225, 225, 245)
local WARM = C(255, 225, 160)

local GOLD_M: Kit.Opts = { Mat = METAL, Refl = 0.15 }
local SOLID_MARBLE: Kit.Opts = { Mat = MARBLE, Solid = true, Shadow = true }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305

--==================================================================
-- HELPERS
--==================================================================
local function banner(parent: Instance, pos: Vector3, w: number, h: number, fx: number, fz: number, color: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local gold = Kit.Vivid(GOLD)
	Kit.Part(parent, V(w, h, 0.3), cf, color, { Mat = FABRIC })
	-- little crown emblem
	Kit.Part(parent, V(w * 0.5, w * 0.18, 0.2), cf * CFrame.new(0, h * 0.12, -0.22), gold, { Mat = METAL })
	for i = -1, 1 do
		Kit.Part(parent, V(w * 0.1, w * 0.18, 0.2), cf * CFrame.new(i * w * 0.2, h * 0.12 + w * 0.17, -0.22), gold, { Mat = METAL })
	end
	Kit.Part(parent, V(w + 1, 0.5, 0.5), cf * CFrame.new(0, h / 2 + 0.2, 0), gold, { Mat = METAL })
	Kit.Part(parent, V(w, 0.6, 0.36), cf * CFrame.new(0, -h / 2 + 0.3, 0), gold, { Mat = FABRIC })
end

local function cloud(parent: Instance, pos: Vector3, d: number)
	local rng = Kit.Rng
	Kit.Ball(parent, d, pos, CLOUD, { Mat = Enum.Material.SmoothPlastic })
	Kit.Ball(parent, d * 0.7, pos + V(d * 0.45, -d * 0.12, rng:NextNumber(-d, d) * 0.25), CLOUD_S)
	Kit.Ball(parent, d * 0.6, pos + V(-d * 0.42, -d * 0.15, rng:NextNumber(-d, d) * 0.25), CLOUD)
end

-- Golden ghost-king statue facing (fx, fz).
local function statue(parent: Instance, x: number, z: number, fx: number, fz: number)
	local m = Kit.Model(parent, "GoldenStatue")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local gold = Kit.Vivid(GOLD)
	Kit.Part(m, V(8, 4, 8), base * CFrame.new(0, 2, 0), WHITE, SOLID_MARBLE)
	Kit.Part(m, V(8.6, 0.8, 8.6), base * CFrame.new(0, 4.2, 0), gold, GOLD_M)
	Kit.Cyl(m, 7, 5.6, base * CFrame.new(0, 8, 0), gold, GOLD_M)
	Kit.Ball(m, 7, (base * CFrame.new(0, 12, 0)).Position, gold, GOLD_M)
	for _, sx in { -1, 1 } do
		Kit.Ball(m, 2.2, (base * CFrame.new(sx * 3.4, 10, -0.6)).Position, gold, GOLD_M)
		Kit.Ball(m, 1.2, (base * CFrame.new(sx * 1.2, 12.6, -3.1)).Position, C(40, 30, 60))
	end
	Kit.Ball(m, 1, (base * CFrame.new(0, 11, -3.3)).Position, C(40, 30, 60))
	Kit.Cyl(m, 1.4, 5, base * CFrame.new(0, 15.6, 0), gold, GOLD_M)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		Kit.Part(m, V(1, 2.2, 1), base * CFrame.new(math.cos(a) * 1.9, 17.2, math.sin(a) * 1.9), gold, GOLD_M)
	end
	Kit.Ball(m, 1.2, (base * CFrame.new(0, 16, -2.5)).Position, Kit.Vivid(PURPLE), { Refl = 0.3 })
	Kit.AddCircle(x, z, 5.5)
end

local function urn(parent: Instance, x: number, z: number, light: boolean, flicker: boolean)
	local m = Kit.Model(parent, "GoldenUrn")
	local gold = Kit.Vivid(GOLD)
	Kit.Box(m, V(x - 2, 0, z - 2), V(x + 2, 3.5, z + 2), WHITE, SOLID_MARBLE)
	Kit.Cyl(m, 1.4, 1.6, CFrame.new(x, 4.2, z), gold, GOLD_M)
	Kit.Ball(m, 4, V(x, 6.2, z), gold, GOLD_M)
	Kit.Cyl(m, 0.6, 4.4, CFrame.new(x, 7.8, z), gold, GOLD_M)
	local flame = Kit.Ball(m, 2.6, V(x, 8.8, z), C(255, 220, 150), { Mat = NEON, Transp = 0.1 })
	if light then
		Kit.Light(flame, WARM, 26, 1.5, flicker)
	end
	Kit.AddCircle(x, z, 3)
end

local function planter(parent: Instance, x: number, z: number)
	Kit.Box(parent, V(x - 2.4, 0, z - 2.4), V(x + 2.4, 2.4, z + 2.4), MARBLE_L, { Mat = MARBLE, Solid = true })
	Kit.Box(parent, V(x - 2.6, 2.4, z - 2.6), V(x + 2.6, 2.8, z + 2.6), Kit.Vivid(GOLD), { Mat = METAL })
	Kit.Ball(parent, 4.6, V(x, 4.6, z), C(150, 200, 140), { Mat = Enum.Material.Grass })
	Kit.Ball(parent, 2, V(x + 1, 6.4, z - 0.6), Kit.Vivid(LAVENDER))
	Kit.AddCircle(x, z, 3)
end

local function chandelier(parent: Instance, x: number, y: number, z: number)
	local m = Kit.Model(parent, "Chandelier")
	local gold = Kit.Vivid(GOLD)
	Kit.Cyl(m, 1.2, 16, CFrame.new(x, y, z), gold, GOLD_M)
	Kit.Cyl(m, 1, 9, CFrame.new(x, y + 4, z), gold, GOLD_M)
	Kit.Cyl(m, 6, 1, CFrame.new(x, y + 2, z), gold, GOLD_M)
	Kit.Ball(m, 2.4, V(x, y + 7.6, z), gold, GOLD_M)
	Kit.Ball(m, 3, V(x, y - 2, z), LAVENDER, { Transp = 0.2, Refl = 0.3 })
	for i = 0, 5 do
		local a = i * math.pi / 3
		local cx, cz = x + math.cos(a) * 7.2, z + math.sin(a) * 7.2
		Kit.Cyl(m, 1.8, 0.7, CFrame.new(cx, y + 1.5, cz), C(250, 245, 230))
		local flame = Kit.Ball(m, 0.8, V(cx, y + 2.8, cz), WARM, { Mat = NEON })
		if i == 0 then
			Kit.Light(flame, WARM, 40, 1.4)
		end
	end
end

--==================================================================
-- GROUND, WALLS, CLOUDS
--==================================================================
local function ground(f: Instance)
	local gold = Kit.Vivid(GOLD)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), WHITE, { Mat = MARBLE, Solid = true, Name = "Ground_Throne" })
	-- royal carpet (flat) with gold borders, ending in a gold seal before the backdrop
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), Kit.Vivid(PURPLE), { Mat = FABRIC, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9.5, 0.07, Z1), gold, { Mat = FABRIC })
	end
	-- lavender diamond inlays beside the carpet
	for z = Z0 + 40, Z1 - 20, 40 do
		for _, s in { -1, 1 } do
			Kit.Part(f, V(6, 0.04, 6), CFrame.new(s * 15, 0.02, z) * CFrame.Angles(0, math.pi / 4, 0), MARBLE_L, { Mat = MARBLE })
		end
	end
	-- medallions on the ghost areas
	for i, a in AREAS do
		Kit.Disc(f, a[1], a[2], 0.08, a[3] * 2 + 4, 0.08, gold, { Mat = METAL })
		Kit.Disc(f, a[1], a[2], 0.11, a[3] * 2, 0.11, if i % 2 == 0 then MARBLE_L else C(235, 228, 250), { Mat = MARBLE })
		Kit.Disc(f, a[1], a[2], 0.14, 12, 0.14, Kit.Vivid(LAVENDER), { Mat = MARBLE })
		Kit.Disc(f, a[1], a[2], 0.17, 5, 0.17, gold, { Mat = METAL })
	end
	-- boss: the royal seal (purple, gold rings, flat gold crown and glowing star points)
	Kit.Disc(f, 0, BOSS_Z, 0.08, 62, 0.08, gold, { Mat = METAL })
	Kit.Disc(f, 0, BOSS_Z, 0.11, 58, 0.11, PURPLE_D, { Mat = MARBLE })
	Kit.Disc(f, 0, BOSS_Z, 0.14, 42, 0.03, gold, { Mat = METAL })
	Kit.Disc(f, 0, BOSS_Z, 0.16, 40, 0.05, Kit.Vivid(PURPLE), { Mat = MARBLE })
	Kit.Box(f, V(-9, 0.16, BOSS_Z - 4), V(9, 0.2, BOSS_Z + 1), gold, { Mat = METAL })
	for i = -2, 2 do
		local h = if i == 0 then 9 else (if math.abs(i) == 1 then 6 else 7.5)
		Kit.Box(f, V(i * 4 - 1.1, 0.16, BOSS_Z + 1), V(i * 4 + 1.1, 0.2, BOSS_Z + 1 + h), gold, { Mat = METAL })
	end
	for i = 0, 7 do
		local a = i * math.pi / 4
		Kit.Part(f, V(1.6, 0.06, 1.6), CFrame.new(math.cos(a) * 25, 0.18, BOSS_Z + math.sin(a) * 25) * CFrame.Angles(0, math.pi / 4, 0), C(255, 235, 150), { Mat = NEON })
	end
end

local function sideWalls(f: Instance)
	local gold = Kit.Vivid(GOLD)
	local z0, z1 = Z0 + 3, Z1 - 3
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, 14, z1), WHITE, SOLID_MARBLE)
		Kit.Box(f, V(s * 139.5, 14, z0), V(s * 146.5, 15, z1), gold, GOLD_M)
		Kit.Box(f, V(s * 139.7, 9, z0), V(s * 140, 10.2, z1), Kit.Vivid(LAVENDER), { Mat = MARBLE })
		for z = z0 + 12, z1 - 6, 36 do
			Kit.Box(f, V(s * 139, 0, z - 2.5), V(s * 147, 18, z + 2.5), MARBLE_L, SOLID_MARBLE)
			Kit.Ball(f, 3.4, V(s * 143, 19.6, z), gold, GOLD_M)
		end
	end
end

local function clouds(f: Instance)
	local rng = Kit.Rng
	for i = 0, 6 do
		local z = Z0 + 20 + i * 54
		for _, s in { -1, 1 } do
			cloud(f, V(s * rng:NextNumber(166, 186), rng:NextNumber(-8, 4), z + s * 10), rng:NextNumber(30, 44))
		end
	end
	-- high drifting cloud puffs outside the walls
	for _, p in { V(-200, 70, Z0 + 90), V(205, 85, Z0 + 200), V(-210, 95, Z0 + 330), V(200, 60, Z0 + 380) } do
		cloud(f, p, rng:NextNumber(24, 34))
	end
end

--==================================================================
-- COLONNADES AND HALL DECOR
--==================================================================
local function colonnade(f: Instance)
	local gold = Kit.Vivid(GOLD)
	local zs = { Z0 + 125, Z0 + 153, Z0 + 181, Z0 + 209, Z0 + 237, Z0 + 265 }
	for _, s in { -1, 1 } do
		local x = s * 22
		local built = 0
		for i, z in zs do
			if Kit.IsFree(x, z, 3.5) then
				built += 1
				Kit.Box(f, V(x - 2.8, 0, z - 2.8), V(x + 2.8, 2, z + 2.8), MARBLE_L, SOLID_MARBLE)
				Kit.Cyl(f, 28, 4, CFrame.new(x, 16, z), WHITE, SOLID_MARBLE)
				Kit.Box(f, V(x - 2.8, 30, z - 2.8), V(x + 2.8, 31.6, z + 2.8), gold, GOLD_M)
				if i % 2 == 1 then
					banner(f, V(x - s * 2.2, 18, z), 4, 12, -s, 0, if s < 0 then PURPLE else Kit.Vivid(LAVENDER))
				end
				Kit.AddCircle(x, z, 3.5)
			end
		end
		if built == #zs then
			Kit.Box(f, V(x - 2.6, 31.6, zs[1] - 2.8), V(x + 2.6, 34.4, zs[#zs] + 2.8), WHITE, { Mat = MARBLE, Shadow = true })
			Kit.Box(f, V(x - 2.8, 34.4, zs[1] - 3), V(x + 2.8, 35, zs[#zs] + 3), gold, GOLD_M)
		end
	end
end

local function decor(f: Instance)
	for _, p in { { -40, Z0 + 52 }, { 40, Z0 + 52 }, { -42, Z1 - 16 }, { 42, Z1 - 16 } } do
		if Kit.IsFree(p[1], p[2], 5.5) then
			statue(f, p[1], p[2], 0, -1)
		end
	end
	for i, p in { { -15, Z0 + 46 }, { 15, Z0 + 46 }, { -36, Z0 + 290 }, { 36, Z0 + 290 } } do
		if Kit.IsFree(p[1], p[2], 3) then
			urn(f, p[1], p[2], i == 2 or i == 3, i == 3)
		end
	end
	for _, p in { { -36, Z0 + 140 }, { 36, Z0 + 140 }, { -36, Z0 + 196 }, { 36, Z0 + 250 }, { 110, Z0 + 60 }, { -110, Z0 + 60 }, { 120, Z0 + 280 }, { -120, Z0 + 180 } } do
		if Kit.IsFree(p[1], p[2], 3) then
			planter(f, p[1], p[2])
		end
	end
	chandelier(f, 0, 54, Z0 + 155)
	chandelier(f, 0, 54, Z0 + 225)
	-- floating golden orbs and crowns (single tagged parts, outside the ghost areas)
	local gold = Kit.Vivid(GOLD)
	for i, p in { V(-40, 26, Z0 + 150), V(44, 30, Z0 + 120), V(-112, 28, Z0 + 190), V(116, 24, Z0 + 270), V(42, 32, Z0 + 250) } do
		local part: Part
		if i % 2 == 0 then
			part = Kit.Cyl(f, 1.4, 3, CFrame.new(p), gold, { Mat = METAL, Name = "FloatingCrown" })
		else
			part = Kit.Ball(f, 2.6, p, Kit.Vivid(LAVENDER), { Refl = 0.3, Name = "FloatingOrb" })
		end
		Kit.Float(part, 1.5)
	end
	-- low cloud tufts along the inner wall foot
	for _, p in { V(-132, 0, Z0 + 60), V(132, 0, Z0 + 110), V(-132, 0, Z0 + 290), V(132, 0, Z0 + 330), V(-132, 0, Z0 + 200) } do
		if Kit.IsFree(p.X, p.Z, 5) then
			Kit.Ball(f, 10, p + V(0, 1, 0), CLOUD)
			Kit.Ball(f, 7, p + V(0, 2, 5), CLOUD_S)
			Kit.AddCircle(p.X, p.Z, 6)
		end
	end
end

--==================================================================
-- GRAND FINAL BACKDROP (behind the end of the play area)
--==================================================================
local function backdrop(f: Instance)
	local m = Kit.Model(f, "GrandBackdrop")
	local gold = Kit.Vivid(GOLD)
	local TOP = 33.6 -- terrace height
	-- marble base under everything past the end of the zone
	Kit.Box(m, V(-190, -4, Z1), V(190, 0, Z1 + 90), WHITE, { Mat = MARBLE, Solid = true })

	-- twin grand staircases rising away from the hall (X +-34..140)
	local steps = 14
	local run = 3.2
	local rise = TOP / steps
	for i = 0, steps - 1 do
		local z = BACK + i * run
		local col = if i % 2 == 0 then WHITE else MARBLE_L
		-- each step is a slab reaching to the back; inset the hidden faces a hair per step so the
		-- alternating colours never share a plane (z-fighting)
		local d = (i + 1) * 0.03
		for _, s in { -1, 1 } do
			Kit.Box(m, V(s * (34 + d), d, z), V(s * (146 - d), rise * (i + 1), BACK + steps * run + 4 - d), col, { Mat = MARBLE, Solid = i < 2, Shadow = true })
		end
	end
	local stairEnd = BACK + steps * run
	for _, s in { -1, 1 } do
		Props.Beam(m, V(s * 34.5, 3, BACK + 0.5), V(s * 34.5, TOP + 3, stairEnd), 0.6, 0.6, gold, GOLD_M)
		for i = 0, 3 do
			local t = i / 3
			local p = V(s * 34.5, rise + (TOP - rise) * t, BACK + 0.5 + (stairEnd - BACK - 0.5) * t)
			Kit.Box(m, p + V(-0.5, 0, -0.5), p + V(0.5, 3.4, 0.5), gold, GOLD_M)
		end
	end
	-- terrace behind the throne and stairs
	Kit.Box(m, V(-146, 0, stairEnd), V(146, TOP, Z1 + 80), WHITE, { Mat = MARBLE })
	Kit.Box(m, V(-146, TOP - 1, stairEnd - 0.3), V(146, TOP, stairEnd), gold, GOLD_M)

	-- palace facade with arched windows
	local fz = stairEnd + 14
	Kit.Box(m, V(-122, TOP, fz), V(122, 98, fz + 8), WHITE, { Mat = MARBLE, Shadow = true })
	Kit.Box(m, V(-123, 96, fz - 0.6), V(123, 99, fz + 8.6), gold, GOLD_M)
	Kit.Box(m, V(-121, TOP, fz - 0.4), V(121, TOP + 2, fz), MARBLE_L, { Mat = MARBLE })
	for _, x in { -100, -70, 70, 100 } do
		Kit.Box(m, V(x - 6, 44, fz - 0.4), V(x + 6, 74, fz), gold, GOLD_M)
		Kit.Box(m, V(x - 5, 45, fz - 0.6), V(x + 5, 73, fz - 0.2), Kit.Vivid(PURPLE), { Mat = Enum.Material.Glass, Transp = 0.15, Refl = 0.2 })
		Kit.CylFlat(m, 0.6, 12, V(x, 74, fz - 0.4), "Z", gold, GOLD_M)
		Kit.CylFlat(m, 0.6, 10, V(x, 74, fz - 0.5), "Z", Kit.Vivid(PURPLE), { Mat = Enum.Material.Glass, Transp = 0.15 })
	end
	-- corner towers with gold domes and flags
	for _, s in { -1, 1 } do
		local tx, tz = s * 132, stairEnd + 10
		Kit.Cyl(m, 120, 22, CFrame.new(tx, 60, tz), WHITE, { Mat = MARBLE, Shadow = true })
		Kit.Cyl(m, 2, 24, CFrame.new(tx, 92, tz), gold, GOLD_M)
		Kit.Cyl(m, 3, 25, CFrame.new(tx, 121, tz), MARBLE_L, { Mat = MARBLE })
		Kit.Ball(m, 22, V(tx, 124, tz), gold, GOLD_M)
		Kit.Cyl(m, 18, 1, CFrame.new(tx, 142, tz), gold, GOLD_M)
		Kit.Part(m, V(0.3, 5, 9), CFrame.new(tx, 148, tz - 4.6), Kit.Vivid(PURPLE), { Mat = FABRIC })
		for _, y in { 50, 80 } do
			Kit.Box(m, V(tx - s * 11.2 - 1.6, y, tz - 3), V(tx - s * 11.2 + 1.6, y + 8, tz + 3), Kit.Vivid(PURPLE), { Mat = Enum.Material.Glass, Transp = 0.15 })
		end
	end
	-- the big farewell banners on the facade
	local endSign = Props.SignBoard(m, V(84, 84, fz - 0.8), 64, 9, 0, -1, "THE END... FOR NOW", PURPLE_D, gold, GOLD)
	Kit.Light(endSign, WARM, 50, 1.2)
	Props.SignBoard(m, V(-84, 84, fz - 0.8), 64, 9, 0, -1, "THANKS FOR HUNTING!", PURPLE_D, gold, GOLD)
	for _, x in { -84, 84 } do
		for _, dx in { -33, 33 } do
			Kit.Wedge(m, V(4, 8, 1), CFrame.new(x + dx, 78, fz - 0.9) * CFrame.Angles(math.pi / 2, 0, 0), Kit.Vivid(PURPLE), { Mat = FABRIC })
		end
	end

	-- THE THRONE (dais front at the end of the play area; seat faces the hall)
	local tz = BACK + 2 -- front of the dais
	for i = 0, 2 do
		local z = tz + i * 4
		Kit.Box(m, V(-32 + i * 2, i * 3, z), V(32 - i * 2, (i + 1) * 3, stairEnd), if i % 2 == 0 then WHITE else MARBLE_L, { Mat = MARBLE, Shadow = true })
		Kit.Box(m, V(-32 + i * 2, (i + 1) * 3 - 0.5, z - 0.2), V(32 - i * 2, (i + 1) * 3, z), gold, GOLD_M)
	end
	local seatZ = tz + 13
	Kit.Box(m, V(-20, 9, seatZ), V(20, 30, seatZ + 16), Kit.Vivid(PURPLE), { Mat = FABRIC, Shadow = true })
	Kit.Box(m, V(-20.4, 26, seatZ - 0.4), V(20.4, 27.2, seatZ + 16), gold, GOLD_M)
	Kit.Box(m, V(-18, 30, seatZ - 1), V(18, 34, seatZ + 14), Kit.Vivid(LAVENDER), { Mat = FABRIC })
	for _, s in { -1, 1 } do
		Kit.Box(m, V(s * 20, 9, seatZ - 4), V(s * 27, 42, seatZ + 20), gold, GOLD_M)
		Kit.Ball(m, 8, V(s * 23.5, 45, seatZ - 3), gold, GOLD_M)
		Kit.Ball(m, 3, V(s * 23.5, 50, seatZ - 3), Kit.Vivid(PURPLE), { Refl = 0.3 })
		Kit.Box(m, V(s * 22, 9, seatZ + 14), V(s * 27, 126, seatZ + 21), gold, GOLD_M)
	end
	Kit.Box(m, V(-22, 30, seatZ + 14), V(22, 120, seatZ + 20), Kit.Vivid(PURPLE), { Mat = FABRIC, Shadow = true })
	Kit.Box(m, V(-27, 120, seatZ + 13.5), V(27, 126, seatZ + 21), gold, GOLD_M)
	-- friendly ghost emblem on the backrest
	Kit.Ball(m, 20, V(0, 82, seatZ + 17), C(250, 248, 255))
	Kit.Box(m, V(-10, 62, seatZ + 13.4), V(10, 82, seatZ + 15), C(250, 248, 255))
	for _, sx in { -1, 1 } do
		Kit.Ball(m, 3.6, V(sx * 4, 85, seatZ + 7.6), C(45, 30, 70))
	end
	Kit.Ball(m, 3, V(0, 78, seatZ + 7.6), C(45, 30, 70))
	-- the crown on top
	local cz = seatZ + 17
	Kit.Cyl(m, 6, 28, CFrame.new(0, 129, cz), gold, GOLD_M)
	for i = -2, 2 do
		local h = if i == 0 then 14 else (if math.abs(i) == 1 then 10 else 8)
		Kit.Box(m, V(i * 6 - 2, 132, cz - 2), V(i * 6 + 2, 132 + h, cz + 2), gold, GOLD_M)
		Kit.Ball(m, 3.4, V(i * 6, 133 + h, cz), if i == 0 then C(255, 120, 160) else Kit.Vivid(LAVENDER), { Refl = 0.3 })
	end
	local gem = Kit.Ball(m, 6, V(0, 129, cz - 13.4), C(210, 150, 255), { Mat = NEON })
	Kit.Light(gem, C(210, 160, 255), 60, 2)
	local sparkle = Kit.Part(m, V(30, 4, 6), CFrame.new(0, 136, cz), gold, { Transp = 1, Name = "SparkleSource" })
	Kit.Emitter(sparkle, C(255, 230, 140), 4, 2, 1.5)
	Props.SignBoard(m, V(0, 1.5, tz - 0.4), 34, 2.6, 0, -1, "THE GHOST KING'S THRONE", PURPLE_D, gold)

	-- clouds hugging the back of the palace
	for i = -3, 3 do
		cloud(m, V(i * 50, Kit.Rng:NextNumber(20, 40), Z1 + 92), Kit.Rng:NextNumber(40, 56))
	end
	local mist = Kit.Part(m, V(260, 1, 20), CFrame.new(0, 34, Z1 + 70), CLOUD, { Transp = 1, Name = "CloudMist" })
	Kit.Emitter(mist, C(250, 250, 255), 3, 16, 0.5)
end

--==================================================================
-- BUILD
--==================================================================
function Throne.Build(map: Instance)
	local f = Kit.Folder(map, "Throne")
	ground(f)
	sideWalls(f)
	clouds(f)
	colonnade(f)
	decor(f)
	backdrop(f)
end

return Throne
