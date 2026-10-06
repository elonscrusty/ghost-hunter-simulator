--!strict
-- ZONE 23: Haunted Shopping Mall (Z 9160..9520). Inside a two-level mall after hours: pale
-- pink marble floors, lilac walls, shop fronts with glowing-free painted signs (made-up stores),
-- a glass barrel-vault skylight over the whole atrium.
--   Ground floor: shop units along both side walls (glass fronts at |X| = 112, 30 wide). Upper
--   floor: a balcony walkway (|X| 109..124, floor top Y 16, glass railings) in front of the
--   upper shops (fronts at |X| = 124), reached by two escalator pairs (right Z ~9210..9260,
--   left Z ~9430..9480). Side ceilings at Y 30, clerestory to the vault springline at Y 44;
--   vault ribs peak at Y 66 (all overhead parts over the ghost areas stay above Y 44).
--   Ghost areas are flat marble medallions ((0,9245) r30, (-82,9280) r24, (75,9340) r26,
--   (-62,9400) r24); the boss area (0,9465) r26 is a big star mosaic.
--   The central fountain (left of the lane, Z ~9340), a food court (right back) facing four
--   food shops, a mannequin display, potted palms, benches, kiosk carts, a mall directory,
--   hanging sale banners and a few floating shopping bags.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local ShoppingMall = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local MARBLE = Enum.Material.Marble
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric

local Z0, Z1 = 9160, 9520

local FLOOR = C(236, 222, 226)
local FLOOR_D = C(206, 186, 196)
local ROSE = C(214, 150, 176)
local GOLD = C(230, 190, 100)
local WALL = C(205, 185, 222)
local WALL_D = C(150, 128, 175)
local TRIM = C(250, 244, 240)
local GLASS_C = C(190, 225, 245)
local STEEL = C(180, 185, 200)
local DARK = C(40, 36, 50)
local POT = C(200, 120, 90)
local LEAF = C(70, 160, 90)
local TRUNK = C(130, 100, 70)
local WATER_C = C(90, 180, 235)
local WARM = C(255, 220, 200)

local SIGN_COLS = { C(230, 90, 140), C(80, 150, 220), C(120, 90, 200), C(60, 170, 150), C(240, 150, 60), C(200, 70, 90), C(90, 120, 190), C(160, 110, 210) }
local ITEM_COLS = { C(255, 120, 160), C(110, 200, 255), C(255, 210, 90), C(150, 230, 140), C(200, 150, 255), C(255, 150, 90) }

local METAL_O: Kit.Opts = { Mat = METAL }
local GLASS_O: Kit.Opts = { Mat = GLASS, Transp = 0.55, Refl = 0.1, Solid = true }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305
local FRONT, UPFRONT, BAL = 112, 124, 109 -- shop fronts (ground, upper) and the balcony edge
local UP = 16 -- upper floor top
local CEIL = 30 -- side ceiling
local SPRING = 44 -- vault springline

local GROUND_SHOPS = {
	{ "BOO-TIQUE", "GHOUL'S GADGETS", "SPECTRE SPORTS", "PHANTOM PETS", "CANDY CRYPT", "TOY TOMB", "HAUNTED HATS", "BOOKS & BOOS", "SPOOKY SHOES", "WRAPPED UP", "FANGTASTIC FASHION" },
	{ "MOONLIGHT MUSIC", "GLOOM & GLAM", "CRYSTAL BALL CAFE", "PIXEL PHANTOM", "COBWEB CLOSET", "LANTERN LANE", "SNEAKY SNEAKERS", "PIZZA PHANTOM", "NOODLE NOOK", "BOO-BA TEA", "SCREAM CREAM" },
}
local UPPER_SHOPS = {
	{ "SKELETON KEYS", "CREEPY CRAFTS", "GHOST GLASSES", "SLIME SHOP", "CURSED CANDLES", "POTION PERFUME", "MUMMY WRAPS", "OWL OPTICS", "FOG & FROST", "BAT & BALL", "WICKED WATCHES" },
	{ "SPELLBOOK STORE", "HOWL HOUSE", "PUMPKIN PLUSH", "STARDUST SWEETS", "MIDNIGHT MOVIES", "PHONE-TOM", "BROOM BIKES", "GOO GALLERY", "TIKI TERROR", "CLOAK & COAT", "GRAVE GAMES" },
}
local FOOD = { ["PIZZA PHANTOM"] = true, ["NOODLE NOOK"] = true, ["BOO-BA TEA"] = true, ["SCREAM CREAM"] = true, ["CRYSTAL BALL CAFE"] = true }
local FASHION = { ["BOO-TIQUE"] = true, ["FANGTASTIC FASHION"] = true, ["COBWEB CLOSET"] = true, ["HAUNTED HATS"] = true, ["SPOOKY SHOES"] = true, ["SNEAKY SNEAKERS"] = true, ["GLOOM & GLAM"] = true }

--==================================================================
-- HELPERS
--==================================================================
-- Faceless mannequin standing at (x, y, z), facing yaw.
local function mannequin(parent: Instance, x: number, y: number, z: number, yaw: number, outfit: Color3)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	Kit.Part(parent, V(1.8, 0.3, 1.8), base * CFrame.new(0, 0.15, 0), DARK, METAL_O)
	Kit.Part(parent, V(1.3, 2.6, 0.7), base * CFrame.new(0, 1.6, 0), C(235, 230, 225))
	Kit.Part(parent, V(1.9, 2.4, 1), base * CFrame.new(0, 4.1, 0), outfit, { Mat = FABRIC })
	Kit.Part(parent, V(2.6, 0.7, 0.8), base * CFrame.new(0, 5, 0), outfit, { Mat = FABRIC })
	Kit.Ball(parent, 1.4, (base * CFrame.new(0, 6, 0)).Position, C(240, 236, 230))
end

local function pottedPalm(parent: Instance, x: number, y: number, z: number)
	Kit.Cyl(parent, 2.6, 3.2, CFrame.new(x, y + 1.3, z), POT, { Mat = Enum.Material.Plaster, Solid = true })
	Kit.Cyl(parent, 0.2, 2.8, CFrame.new(x, y + 2.6, z), C(90, 60, 40))
	local top = V(x, y + 9, z)
	Props.Beam(parent, V(x, y + 2.6, z), top, 0.7, 0.7, TRUNK, { Mat = Enum.Material.Wood })
	for k = 0, 4 do
		local a = k * math.pi * 0.4
		Props.Beam(parent, top, top + V(math.cos(a) * 4.5, -1.8, math.sin(a) * 4.5), 1.8, 0.2, if k % 2 == 0 then LEAF else Kit.Vivid(LEAF), { Mat = Enum.Material.LeafyGrass })
	end
	Kit.AddCircle(x, z, 2.5)
end

local function bench(parent: Instance, x: number, z: number, alongZ: boolean)
	local hx, hz = if alongZ then 1.2 else 4, if alongZ then 4 else 1.2
	Kit.Box(parent, V(x - hx, 1.5, z - hz), V(x + hx, 2, z + hz), C(150, 105, 75), { Mat = Enum.Material.Wood, Solid = true })
	Kit.Box(parent, V(x - hx + 0.3, 0, z - hz + 0.3), V(x + hx - 0.3, 1.5, z + hz - 0.3), STEEL, METAL_O)
	Kit.AddCircle(x, z, 4.5)
end

-- Shop unit between |X| front..140 (side s), from z to z + w, floor at y0, height h.
local function shop(parent: Instance, s: number, front: number, z: number, w: number, y0: number, h: number, name: string, idx: number, lite: boolean?)
	local m = Kit.Model(parent, "Shop")
	local col = SIGN_COLS[(idx - 1) % #SIGN_COLS + 1]
	local item = ITEM_COLS[(idx - 1) % #ITEM_COLS + 1]
	local xf, xb = s * front, s * 139.8
	local depth = 140 - front
	-- partition (solid) on the low-Z side, painted back wall, coloured floor
	Kit.Box(m, V(xf, y0, z), V(s * 140, y0 + h, z + 1), WALL_D, { Mat = Enum.Material.Plaster, Solid = true })
	Kit.Box(m, V(xb, y0, z + 1), V(s * 140, y0 + h - 2, z + w), col:Lerp(TRIM, 0.55))
	if not lite then
		Kit.Box(m, V(xf, y0, z + 1), V(xb, y0 + 0.05, z + w), col:Lerp(FLOOR, 0.7), { Mat = MARBLE })
	end
	-- glass front with a door, fascia and sign
	local gh = h - 3
	Kit.Box(m, V(xf - 0.2, y0, z + 1), V(xf + 0.2, y0 + gh, z + w), GLASS_C, GLASS_O)
	if not lite then
		Kit.Box(m, V(xf - s * 0.25, y0, z + w / 2 - 3), V(xf - s * 0.05, y0 + gh, z + w / 2 + 3), col:Lerp(GLASS_C, 0.5), { Mat = GLASS, Transp = 0.4 })
	end
	Kit.Box(m, V(xf - s * 0.6, y0 + gh, z + 0.6), V(xf + s * 0.4, y0 + h, z + w + 0.4), Kit.Vivid(col))
	local board = Kit.Part(m, V(w - 6, 2, 0.3), CFrame.new(xf - s * 0.75, y0 + gh + 1.5, z + w / 2) * CFrame.Angles(0, Kit.FaceYaw(-s, 0), 0), TRIM, { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Front, name, Kit.Vivid(col))
	-- what's in the window
	local yaw = Kit.FaceYaw(-s, 0)
	local wx = s * (front + 4)
	if FASHION[name] then
		mannequin(m, wx, y0, z + w * 0.25, yaw, Kit.Vivid(item))
		mannequin(m, wx, y0, z + w * 0.75, yaw, Kit.Vivid(ITEM_COLS[idx % #ITEM_COLS + 1]))
		Kit.Box(m, V(s * (front + depth - 5), y0, z + 4), V(s * (front + depth - 1), y0 + 6, z + w - 4), C(160, 120, 90), { Mat = Enum.Material.Wood })
	elseif FOOD[name] then
		Kit.Box(m, V(s * (front + 6), y0, z + 4), V(s * (front + 9), y0 + 3.6, z + w - 4), TRIM, { Mat = MARBLE })
		Kit.Box(m, V(s * (front + 5.8), y0 + 3.6, z + 4), V(s * (front + 9.2), y0 + 3.9, z + w - 4), Kit.Vivid(col))
		Kit.Box(m, V(xb - s * 0.2, y0 + 6, z + 5), V(xb, y0 + 9, z + w - 5), DARK)
		for k = 0, 2 do
			Kit.Box(m, V(xb - s * 0.3, y0 + 6.5, z + 6 + k * (w - 12) / 3), V(xb - s * 0.2, y0 + 8.5, z + 4 + (k + 1) * (w - 12) / 3), Kit.Vivid(ITEM_COLS[(idx + k) % #ITEM_COLS + 1]))
		end
	else
		-- shelves with goods along the back and a display table
		Kit.Box(m, V(s * (front + depth - 4), y0, z + 3), V(s * (front + depth - 0.5), y0 + 8, z + w - 3), C(170, 140, 120), { Mat = Enum.Material.Wood })
		for k = 0, 1 do
			Kit.Box(m, V(s * (front + depth - 4.2), y0 + 2.5 + k * 3, z + 4), V(s * (front + depth - 3.8), y0 + 4 + k * 3, z + w - 4), Kit.Vivid(ITEM_COLS[(idx + k) % #ITEM_COLS + 1]))
		end
		Kit.Box(m, V(s * (front + 5), y0, z + w / 2 - 4), V(s * (front + 9), y0 + 3, z + w / 2 + 4), Kit.Vivid(item))
		Kit.Ball(m, 2, V(s * (front + 7), y0 + 4, z + w / 2), Kit.Vivid(ITEM_COLS[(idx + 2) % #ITEM_COLS + 1]))
	end
end

-- Pair of escalators rising from (Y 0, zLow) to (Y UP, zHigh), centred on x (12 wide).
local function escalator(parent: Instance, x: number, zLow: number, zHigh: number)
	local m = Kit.Model(parent, "Escalator")
	local len = math.abs(zHigh - zLow)
	local zm = (zLow + zHigh) / 2
	local flip = if zHigh > zLow then 0 else math.pi
	Kit.Wedge(m, V(12, UP, len), CFrame.new(x, UP / 2, zm) * CFrame.Angles(0, flip, 0), C(120, 120, 140), { Mat = METAL, Solid = true })
	local dir = if zHigh > zLow then 1 else -1
	local a, b = V(x, 0, zLow), V(x, UP, zHigh)
	-- step stripes on the slope
	for k = 1, 9 do
		local p = a:Lerp(b, k / 10)
		Kit.Box(m, V(x - 5.6, p.Y - 0.05, p.Z - 0.25), V(x + 5.6, p.Y + 0.08, p.Z + 0.25), Kit.Vivid(GOLD))
	end
	for _, dx in { -6, 0, 6 } do
		Props.Beam(m, a + V(dx, 1.8, -dir * 1), b + V(dx, 1.8, 0), 0.3, 3.4, GLASS_C, { Mat = GLASS, Transp = 0.4 })
		Props.Beam(m, a + V(dx, 3.7, -dir * 1), b + V(dx, 3.7, 0), 0.7, 0.4, DARK)
	end
	Kit.AddRect(x - 7, math.min(zLow, zHigh) - 3, x + 7, math.max(zLow, zHigh) + 1)
end

--==================================================================
-- FLOOR, LANE, MEDALLIONS
--==================================================================
local function floor(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), FLOOR, { Mat = MARBLE, Solid = true, Name = "Ground_ShoppingMall" })
	-- big floor tiles: thin seams
	for x = -96, 96, 48 do
		if x ~= 0 then
			Kit.Box(f, V(x - 0.15, 0, Z0 + 4), V(x + 0.15, 0.03, Z1 - 4), FLOOR_D)
		end
	end
	for z = Z0 + 16, Z1 - 8, 24 do
		Kit.Box(f, V(-FRONT, 0, z - 0.15), V(FRONT, 0.03, z + 0.15), FLOOR_D)
	end
	-- the lane: a rose marble runner with gold edges and diamond inlays
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.08, Z1), ROSE, { Mat = MARBLE, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0, Z0), V(s * 9, 0.1, Z1), Kit.Vivid(GOLD), METAL_O)
	end
	for z = Z0 + 20, Z1 - 10, 20 do
		Kit.Part(f, V(3, 0.03, 3), CFrame.new(0, 0.1, z) * CFrame.Angles(0, math.pi / 4, 0), TRIM, { Mat = MARBLE })
	end
	-- medallions: compass roses in marble
	local cols = { C(120, 90, 200), C(60, 150, 170), C(230, 110, 150), C(90, 130, 210) }
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		local c = cols[i]
		Kit.Disc(f, x, z, 0.08, r * 2 + 3, 0.08, Kit.Vivid(GOLD), METAL_O)
		Kit.Disc(f, x, z, 0.11, r * 2, 0.03, TRIM, { Mat = MARBLE })
		Kit.Disc(f, x, z, 0.13, r * 1.4, 0.02, c:Lerp(TRIM, 0.3), { Mat = MARBLE })
		Kit.Disc(f, x, z, 0.15, r * 1.2, 0.02, TRIM, { Mat = MARBLE })
		for k = 0, 3 do
			local ang = k * math.pi / 4
			Kit.Part(f, V(r * 1.7, 0.02, r * 0.18), CFrame.new(x, 0.17, z) * CFrame.Angles(0, ang, 0), if k % 2 == 0 then c else Kit.Vivid(GOLD), { Mat = MARBLE })
		end
		Kit.Disc(f, x, z, 0.2, r * 0.35, 0.03, c, { Mat = MARBLE })
	end
	-- boss: a big star mosaic
	Kit.Disc(f, 0, BOSS_Z, 0.08, 58, 0.08, Kit.Vivid(GOLD), METAL_O)
	Kit.Disc(f, 0, BOSS_Z, 0.11, 54, 0.03, C(70, 50, 110), { Mat = MARBLE })
	Kit.Disc(f, 0, BOSS_Z, 0.13, 48, 0.02, TRIM, { Mat = MARBLE })
	for k = 0, 4 do
		local ang = k * 2 * math.pi / 5
		Kit.Part(f, V(6, 0.02, 22), CFrame.new(math.sin(ang) * 10, 0.16, BOSS_Z + math.cos(ang) * 10) * CFrame.Angles(0, ang, 0), Kit.Vivid(C(230, 110, 150)), { Mat = MARBLE })
	end
	Kit.Disc(f, 0, BOSS_Z, 0.19, 12, 0.03, Kit.Vivid(GOLD), METAL_O)
	Kit.Disc(f, 0, BOSS_Z, 0.21, 6, 0.02, C(70, 50, 110), { Mat = MARBLE })
end

--==================================================================
-- SHELL: WALLS, SHOPS, BALCONY, VAULT
--==================================================================
local function shell(f: Instance)
	local z0, z1 = Z0 + 3, Z1 - 3
	local H = 48
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 140, -0.5, z0), V(s * 146, H, z1), WALL, { Mat = Enum.Material.Plaster, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.5, H, z0), V(s * 146.5, H + 1, z1), TRIM, { Mat = MARBLE })
		-- the balcony slab (top at UP) and its gold edge
		Kit.Box(f, V(s * BAL, UP - 1.2, z0), V(s * 140, UP, z1), FLOOR, { Mat = MARBLE, Solid = true })
		Kit.Box(f, V(s * BAL - s * 0.3, UP - 1.4, z0), V(s * BAL, UP + 0.1, z1), Kit.Vivid(GOLD), METAL_O)
		-- side ceiling, clerestory wall up to the vault, cornice
		Kit.Box(f, V(s * BAL, CEIL, z0), V(s * 140, CEIL + 1, z1), TRIM, { Mat = Enum.Material.Plaster })
		Kit.Box(f, V(s * BAL, CEIL + 1, z0), V(s * (BAL + 2), SPRING, z1), WALL, { Mat = Enum.Material.Plaster })
		Kit.Box(f, V(s * (BAL - 0.6), SPRING - 1, z0), V(s * (BAL + 2.4), SPRING + 0.6, z1), TRIM, { Mat = MARBLE })
		for z = Z0 + 30, Z1 - 20, 40 do
			Kit.CylFlat(f, 0.4, 6, V(s * (BAL - 0.2), CEIL + 7, z), "X", C(170, 200, 240), { Mat = GLASS, Transp = 0.2 })
		end
		-- columns under the balcony edge
		for z = Z0 + 20, Z1 - 10, 40 do
			Kit.Cyl(f, UP - 1.2, 2.2, CFrame.new(s * (BAL + 1.4), (UP - 1.2) / 2, z), TRIM, { Mat = MARBLE, Solid = true })
			Kit.Cyl(f, CEIL - UP, 1.6, CFrame.new(s * (BAL + 1.4), (UP + CEIL) / 2, z), TRIM, { Mat = MARBLE })
		end
		-- glass railing along the balcony edge (gap where the escalator lands)
		local gap0, gap1 = if s > 0 then Z0 + 98 else Z0 + 260, if s > 0 then Z0 + 110 else Z0 + 272
		for _, seg in { { z0, gap0 }, { gap1, z1 } } do
			Kit.Box(f, V(s * (BAL + 0.2), UP, seg[1]), V(s * (BAL + 0.5), UP + 3.4, seg[2]), GLASS_C, { Mat = GLASS, Transp = 0.45, Solid = true })
			Kit.Box(f, V(s * (BAL + 0.05), UP + 3.4, seg[1]), V(s * (BAL + 0.65), UP + 3.8, seg[2]), Kit.Vivid(GOLD), METAL_O)
		end
		-- shops: ground floor and upper floor
		for i = 1, 11 do
			local z = Z0 + 8 + (i - 1) * 30
			shop(f, s, FRONT, z, 30, 0, UP - 1.2, GROUND_SHOPS[(s + 3) // 2][i], i + (s + 1) * 3)
			shop(f, s, UPFRONT, z, 30, UP, CEIL - UP, UPPER_SHOPS[(s + 3) // 2][i], i + 5 + (s + 1) * 2, true)
		end
		Kit.Box(f, V(s * FRONT, 0, Z0 + 338), V(s * 140, UP - 1.2, z1), WALL_D, { Mat = Enum.Material.Plaster, Solid = true })
		Kit.Box(f, V(s * UPFRONT, UP, Z0 + 338), V(s * 140, CEIL, z1), WALL_D, { Mat = Enum.Material.Plaster, Solid = true })
		Kit.Box(f, V(s * FRONT, 0, z0), V(s * 140, UP - 1.2, Z0 + 8), WALL_D, { Mat = Enum.Material.Plaster, Solid = true })
		Kit.Box(f, V(s * UPFRONT, UP, z0), V(s * 140, CEIL, Z0 + 8), WALL_D, { Mat = Enum.Material.Plaster, Solid = true })
	end
	-- glass barrel vault over the atrium: ribs every 40 studs, tinted glass panels
	local n = 8
	local function arc(t: number): Vector3
		local a = math.pi * t
		return V(math.cos(a) * (BAL + 1), SPRING + math.sin(a) * 22, 0)
	end
	for z = Z0 + 15, Z1 - 10, 55 do
		for k = 0, n - 1 do
			local p, q = arc(k / n), arc((k + 1) / n)
			Props.Beam(f, p + V(0, 0, z), q + V(0, 0, z), 1, 1.2, TRIM, METAL_O)
		end
	end
	for k = 0, n - 1 do
		local p, q = arc(k / n), arc((k + 1) / n)
		local d = q - p
		local mid = (p + q) / 2
		Kit.Part(f, V(d.Magnitude, 0.3, Z1 - Z0 - 6), CFrame.new(mid.X, mid.Y, (Z0 + Z1) / 2) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)), C(170, 160, 220), { Mat = GLASS, Transp = 0.82 })
		Kit.Box(f, V(q.X - 0.5, q.Y - 0.5, Z0 + 3), V(q.X + 0.5, q.Y + 0.5, Z1 - 3), TRIM, METAL_O)
	end
	-- the moon seen through the skylight
	Kit.Ball(f, 40, V(280, 130, Z0 + 260), C(240, 235, 255), { Name = "Moon" })
end

--==================================================================
-- ATRIUM: ESCALATORS, FOUNTAIN, FOOD COURT, DECOR
--==================================================================
local function fountain(f: Instance)
	local m = Kit.Model(f, "Fountain")
	local x, z = -36, Z0 + 180
	Kit.Disc(m, x, z, 1.8, 24, 1.8, TRIM, { Mat = MARBLE, Solid = true })
	Kit.Disc(m, x, z, 1.85, 21, 0.3, WATER_C, { Transp = 0.3, Refl = 0.2 })
	Kit.Disc(m, x, z, 1.9, 20.6, 0.04, Kit.Vivid(GOLD), { Transp = 0.6 })
	Kit.Cyl(m, 5, 2.4, CFrame.new(x, 4, z), TRIM, { Mat = MARBLE })
	Kit.Disc(m, x, z, 6.8, 11, 1, TRIM, { Mat = MARBLE })
	Kit.Disc(m, x, z, 6.85, 9.6, 0.3, WATER_C, { Transp = 0.3 })
	Kit.Cyl(m, 3, 1.4, CFrame.new(x, 8.3, z), TRIM, { Mat = MARBLE })
	Kit.Disc(m, x, z, 10.2, 5, 0.6, TRIM, { Mat = MARBLE })
	Kit.Ball(m, 1.6, V(x, 11, z), Kit.Vivid(GOLD), METAL_O)
	-- water jets and falling curtains (see-through)
	Kit.Cyl(m, 5, 0.8, CFrame.new(x, 13.5, z), C(200, 235, 255), { Transp = 0.5 })
	for k = 0, 5 do
		local a = k * math.pi / 3
		Props.Beam(m, V(x + math.cos(a) * 1.5, 13, z + math.sin(a) * 1.5), V(x + math.cos(a) * 4.5, 7, z + math.sin(a) * 4.5), 0.4, 0.4, C(200, 235, 255), { Transp = 0.5 })
		Props.Beam(m, V(x + math.cos(a + 0.5) * 5.3, 6.6, z + math.sin(a + 0.5) * 5.3), V(x + math.cos(a + 0.5) * 9.5, 2, z + math.sin(a + 0.5) * 9.5), 0.4, 0.4, C(200, 235, 255), { Transp = 0.5 })
	end
	-- coins on the bottom
	for k = 0, 3 do
		local a = k * 1.6
		Kit.Disc(m, x + math.cos(a) * (6 + k % 3), z + math.sin(a) * (6 + k % 3), 1.88, 0.8, 0.04, Kit.Vivid(GOLD), METAL_O)
	end
	local glow = Kit.Part(m, V(1, 1, 1), CFrame.new(x, 4, z), WARM, { Transp = 1, Name = "FountainGlow" })
	Kit.Light(glow, C(170, 220, 255), 28, 1)
	Kit.Emitter(glow, C(220, 240, 255), 2, 4, 0.5)
	-- benches round it
	for _, p in { { 0, -16 }, { 0, 16 }, { 16, 0 }, { -16, 0 } } do
		if Kit.IsFree(x + p[1], z + p[2], 4.5) then
			bench(f, x + p[1], z + p[2], p[1] ~= 0)
		end
	end
	Kit.AddCircle(x, z, 13)
end

local function foodCourt(f: Instance)
	local cols = { C(255, 120, 160), C(110, 200, 255), C(255, 200, 90), C(150, 220, 140) }
	local i = 0
	for z = Z0 + 222, Z0 + 290, 17 do
		for x = 46, 98, 17 do
			i += 1
			if Kit.IsFree(x, z, 4.5) then
				Kit.Cyl(f, 0.3, 4, CFrame.new(x, 3, z), TRIM, { Mat = MARBLE, Solid = true })
				Kit.Box(f, V(x - 0.25, 0, z - 0.25), V(x + 0.25, 2.9, z + 0.25), STEEL, METAL_O)
				for _, d in { { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } } do
					Kit.Cyl(f, 1.8, 1.4, CFrame.new(x + d[1], 0.9, z + d[2]), cols[(i + d[1] // 3) % #cols + 1])
				end
				if i % 3 == 0 then
					Kit.Box(f, V(x - 0.8, 3.15, z - 0.6), V(x + 0.8, 3.35, z + 0.6), Kit.Vivid(cols[i % #cols + 1]))
				end
				Kit.AddCircle(x, z, 4.5)
			end
		end
	end
	-- hanging food court sign
	local board = Kit.Part(f, V(20, 3.4, 0.5), CFrame.new(72, 24, Z0 + 214), C(255, 150, 90), { Name = "SignBoard" })
	Kit.Sign(board, Enum.NormalId.Front, "FOOD COURT", TRIM)
	Kit.Sign(board, Enum.NormalId.Back, "FOOD COURT", TRIM)
	for _, dx in { -8, 8 } do
		Kit.Box(f, V(72 + dx - 0.1, 25.7, Z0 + 214 - 0.1), V(72 + dx + 0.1, SPRING + 4, Z0 + 214 + 0.1), DARK)
	end
	local glow = Kit.Part(f, V(1, 1, 1), CFrame.new(72, 14, Z0 + 255), WARM, { Transp = 1, Name = "FoodGlow" })
	Kit.Light(glow, WARM, 34, 0.9)
end

local function kiosk(parent: Instance, x: number, z: number, name: string, col: Color3)
	local m = Kit.Model(parent, "KioskCart")
	Kit.Box(m, V(x - 4, 0.8, z - 2), V(x + 4, 4, z + 2), col, { Solid = true })
	Kit.Box(m, V(x - 4.2, 4, z - 2.2), V(x + 4.2, 4.3, z + 2.2), TRIM, { Mat = MARBLE })
	for _, sx in { -3.2, 3.2 } do
		Kit.CylFlat(m, 0.4, 1.4, V(x + sx, 0.7, z - 2), "X", DARK)
		Kit.CylFlat(m, 0.4, 1.4, V(x + sx, 0.7, z + 2), "X", DARK)
		Kit.Box(m, V(x + sx - 0.15, 4.3, z - 0.15), V(x + sx + 0.15, 9, z + 0.15), Kit.Vivid(GOLD), METAL_O)
	end
	Kit.Box(m, V(x - 4.6, 9, z - 2.6), V(x + 4.6, 9.6, z + 2.6), Kit.Vivid(col), { Mat = FABRIC })
	for k = -2, 2 do
		Kit.Box(m, V(x + k * 1.4 - 0.5, 4.3, z - 1), V(x + k * 1.4 + 0.5, 5.3, z + 1), Kit.Vivid(ITEM_COLS[(k + 3) % #ITEM_COLS + 1]))
	end
	local b = Kit.Part(m, V(8, 1.4, 0.2), CFrame.new(x, 8, z), TRIM, { Name = "SignBoard" })
	Kit.Sign(b, Enum.NormalId.Front, name, Kit.Vivid(col))
	Kit.Sign(b, Enum.NormalId.Back, name, Kit.Vivid(col))
	Kit.AddCircle(x, z, 5)
end

local function decor(f: Instance)
	escalator(f, 100, Z0 + 50, Z0 + 98)
	Kit.Box(f, V(94, UP - 1.2, Z0 + 98), V(BAL, UP, Z0 + 110), FLOOR, { Mat = MARBLE, Solid = true })
	escalator(f, -100, Z0 + 320, Z0 + 272)
	Kit.Box(f, V(-BAL, UP - 1.2, Z0 + 260), V(-94, UP, Z0 + 272), FLOOR, { Mat = MARBLE, Solid = true })
	Kit.AddRect(-110, Z0 + 258, -92, Z0 + 274)
	Kit.AddRect(92, Z0 + 96, 110, Z0 + 112)
	fountain(f)
	foodCourt(f)
	-- mannequin display stage in the atrium
	local mx, mz = 40, Z0 + 128
	Kit.Disc(f, mx, mz, 1, 14, 1, TRIM, { Mat = MARBLE, Solid = true })
	Kit.Disc(f, mx, mz, 1.05, 12, 0.05, Kit.Vivid(C(230, 110, 150)))
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3 + 0.3
		mannequin(f, mx + math.cos(a) * 3.5, 1, mz + math.sin(a) * 3.5, Kit.FaceYaw(math.cos(a), math.sin(a)), Kit.Vivid(ITEM_COLS[k + 1]))
	end
	Props.SignBoard(f, V(mx - 8, 3, mz), 6, 1.6, -1, 0, "NEW LOOKS!", C(230, 110, 150), TRIM)
	Kit.AddCircle(mx, mz, 9)
	-- kiosk carts
	local carts: { { x: number, z: number, name: string } } = {
		{ x = 44, z = 40, name = "PHONE CASES" }, { x = -40, z = 112, name = "SPOOKY SOCKS" }, { x = 30, z = 210, name = "SLIME TIME" }, { x = -96, z = 200, name = "BALLOONS" },
	}
	for i, k in carts do
		local x, z = k.x, Z0 + k.z
		if Kit.IsFree(x, z, 5) then
			kiosk(f, x, z, k.name, SIGN_COLS[i * 2])
		end
	end
	-- potted palms and benches along the lane and the shop fronts
	for _, p in { { 16, 30 }, { -16, 130 }, { 16, 130 }, { -16, 200 }, { 16, 250 }, { -16, 270 }, { 16, 340 }, { -16, 340 }, { 104, 140 }, { -104, 170 }, { 104, 300 }, { -104, 60 }, { 60, 60 } } do
		if Kit.IsFree(p[1], Z0 + p[2], 2.5) then
			pottedPalm(f, p[1], 0, Z0 + p[2])
		end
	end
	for _, p in { { 116, 140 }, { -116, 200 }, { 116, 260 }, { -116, 80 }, { 116, 30 }, { -116, 330 } } do
		pottedPalm(f, p[1], UP, Z0 + p[2])
	end
	for _, p in { { 20, 160 }, { -20, 236 }, { 20, 290 }, { -20, 60 }, { 100, 200 }, { -100, 220 } } do
		if Kit.IsFree(p[1], Z0 + p[2], 4.5) then
			bench(f, p[1], Z0 + p[2], true)
		end
	end
	-- mall directory
	local dx, dz = -18, Z0 + 26
	if Kit.IsFree(dx, dz, 2) then
		Kit.Box(f, V(dx - 0.5, 0, dz - 2.5), V(dx + 0.5, 8, dz + 2.5), WALL_D, { Solid = true })
		Props.SignBoard(f, V(dx + 0.7, 5.2, dz), 4.6, 4.6, 1, 0, "MALL MAP\nYOU ARE HERE", C(60, 50, 90), TRIM)
		Kit.AddCircle(dx, dz, 3)
	end
	-- hanging sale banners and pendant lamps over the lane (outside the ghost areas)
	for i, z in { Z0 + 40, Z0 + 150, Z0 + 212, Z0 + 268 } do
		local text = ({ "HAUNTED HOLLOW MALL", "BOO-NANZA SALE!", "OPEN ALL NIGHT", "50% OFF SPOOKS" })[i]
		for _, sx in { -7, 7 } do
			Kit.Box(f, V(sx - 0.1, 26, z - 0.1), V(sx + 0.1, SPRING + 10, z + 0.1), DARK)
		end
		local board = Kit.Part(f, V(18, 3.6, 0.4), CFrame.new(0, 24.2, z), SIGN_COLS[i + 2], { Name = "SignBoard" })
		Kit.Sign(board, Enum.NormalId.Front, text, TRIM)
		Kit.Sign(board, Enum.NormalId.Back, text, TRIM)
	end
	for i, p in { { 0, 175 }, { 40, 260 }, { -40, 80 }, { 60, 110 }, { -30, 300 }, { 90, 40 } } do
		local x, z = p[1], Z0 + p[2]
		Kit.Box(f, V(x - 0.08, 46, z - 0.08), V(x + 0.08, SPRING + 12, z + 0.08), DARK)
		local lamp = Kit.Ball(f, 2.2, V(x, 45, z), WARM, { Mat = NEON })
		Kit.Cyl(f, 1, 3.2, CFrame.new(x, 46.2, z), Kit.Vivid(GOLD), METAL_O)
		if i <= 3 then
			Kit.Light(lamp, WARM, 40, 0.8)
		end
	end
	-- floating shopping bags (single parts) and a ghostly mist by the boss mosaic
	for i, p in { V(-60, 20, Z0 + 150), V(50, 24, Z0 + 90), V(-90, 26, Z0 + 300), V(20, 30, Z0 + 230), V(80, 22, Z0 + 330), V(-20, 28, Z0 + 20) } do
		local bag = Kit.Part(f, V(2.4, 3, 1.2), CFrame.new(p) * CFrame.Angles(0, i, 0.15), Kit.Vivid(ITEM_COLS[(i - 1) % #ITEM_COLS + 1]), { Name = "ShoppingBag" })
		Kit.Float(bag, 1)
	end
	Props.Wisp(f, V(0, 0, BOSS_Z + 34), C(220, 190, 255), 10, true)
	local ug = Kit.Part(f, V(1, 1, 1), CFrame.new(-120, UP + 8, Z0 + 180), WARM, { Transp = 1, Name = "UpperGlow" })
	Kit.Light(ug, C(255, 200, 235), 36, 0.8)
	local ug2 = Kit.Part(f, V(1, 1, 1), CFrame.new(120, UP + 8, Z0 + 180), WARM, { Transp = 1, Name = "UpperGlow" })
	Kit.Light(ug2, C(200, 220, 255), 36, 0.8)
end

--==================================================================
-- BUILD
--==================================================================
function ShoppingMall.Build(map: Instance)
	local f = Kit.Folder(map, "ShoppingMall")
	-- shop fronts and the balcony: nothing random goes under them
	Kit.AddRect(-140, Z0, -FRONT + 1, Z1)
	Kit.AddRect(FRONT - 1, Z0, 140, Z1)
	floor(f)
	shell(f)
	decor(f)
end

return ShoppingMall
