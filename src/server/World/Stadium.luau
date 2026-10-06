--!strict
-- ZONE 26: Haunted Stadium (Z 10240..10600). A big sports ground on game night, with ghosts
-- in the seats instead of fans.
--   Ground: the playing field itself (grass with mowing stripes, white sidelines, end lines,
--   a halfway line and centre circle, painted yard numbers); the lane along X = 0 is a lighter
--   chalk-edged strip. A red running track runs along both sides (|X| 100..109).
--   Ghost areas are flat painted team logos ((0,10325) r30, (-82,10360) r24, (75,10420) r26,
--   (-62,10480) r24); the boss area (0,10545) r26 is a big painted ghost logo in the far end zone.
--   Stands: a padded barrier with ad boards at |X| 109..111, then nine solid seat tiers rising
--   to the back wall (|X| 112..140, top Y 18) in team-colour sections, ghost fans in the seats,
--   and a decorative upper deck outside the walls (|X| 146..186).
--   Goalposts at both ends (uprights at X +-14, crossbars at Y 12 over the lane), the giant
--   scoreboard high over the far gate (bottom Y 52, so the gate sign stays visible), four
--   floodlight towers outside the walls (soft light), team banners on the back walls, a
--   ghost mascot statue, team dugouts, a popcorn cart and a trophy on a plinth.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Stadium = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon
local GRASS = Enum.Material.Grass
local CONCRETE = Enum.Material.Concrete
local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local GLASS = Enum.Material.Glass

local Z0, Z1 = 10240, 10600
local ZC = (Z0 + Z1) / 2

local TURF = C(62, 140, 70)
local TURF_L = C(78, 160, 82)
local CHALK = C(240, 242, 236)
local TRACK = C(180, 70, 60)
local CONC = C(130, 134, 145)
local CONC_D = C(92, 96, 108)
local STEEL = C(150, 155, 168)
local DARK = C(26, 26, 34)
-- teams: Spookton Specters (purple/orange, left) and Booville Banshees (teal/white, right)
local PURPLE = C(110, 60, 170)
local ORANGE = C(255, 150, 40)
local TEAL = C(30, 160, 160)
local WHITE = C(245, 245, 240)
local GOLD = C(230, 185, 60)
local GHOST = C(225, 240, 255)
local LAMP = C(255, 250, 225)

local STEEL_O: Kit.Opts = { Mat = METAL }

local AREAS = { { 0, Z0 + 85, 30 }, { -82, Z0 + 120, 24 }, { 75, Z0 + 180, 26 }, { -62, Z0 + 240, 24 } }
local BOSS_Z = Z0 + 305
local FW = 96 -- field half width
local FZ0, FZ1 = Z0 + 24, Z1 - 24 -- end lines
local TIER_X0, TIER_D, TIER_H, TIERS = 112, 3, 2, 9
local SZ0, SZ1 = Z0 + 6, Z1 - 6 -- stand length

--==================================================================
-- HELPERS
--==================================================================
local function line(f: Instance, x1: number, z1: number, x2: number, z2: number)
	Kit.Box(f, V(x1, 0.06, z1), V(x2, 0.09, z2), CHALK)
end

-- Flat text painted on the ground, readable from above (reads along +Z).
local function paint(f: Instance, x: number, z: number, w: number, h: number, text: string, col: Color3, yaw: number?)
	local p = Kit.Part(f, V(w, 0.05, h), CFrame.new(x, 0.1, z) * CFrame.Angles(0, yaw or math.pi, 0), col, { Transp = 1, Name = "SignBoard" })
	Kit.Sign(p, Enum.NormalId.Top, text, col)
end

-- Ghost fan sitting in the seats (looks toward the field at -s).
local function ghostFan(f: Instance, x: number, y: number, z: number, s: number, cheer: boolean)
	Kit.Ball(f, 2.8, V(x, y + 1.6, z), GHOST, { Transp = 0.25 })
	Kit.Ball(f, 2.2, V(x, y + 0.6, z), GHOST, { Transp = 0.25 })
	for _, dz in { -0.5, 0.5 } do
		Kit.Ball(f, 0.5, V(x - s * 1.3, y + 1.9, z + dz), DARK)
	end
	if cheer then
		-- little arms up
		for _, dz in { -1.4, 1.4 } do
			Kit.Part(f, V(0.6, 1.8, 0.6), CFrame.new(x, y + 3.2, z + dz) * CFrame.Angles(dz * 0.25, 0, 0), GHOST, { Transp = 0.25 })
		end
	end
end

--==================================================================
-- FIELD
--==================================================================
local function field(f: Instance)
	Kit.Box(f, V(-190, -4, Z0), V(190, 0, Z1), TURF, { Mat = GRASS, Solid = true, Name = "Ground_Stadium" })
	-- mowing stripes across the field
	local k = 0
	for z = FZ0, FZ1 - 1, 24 do
		if k % 2 == 0 then
			Kit.Box(f, V(-FW, 0, z), V(FW, 0.03, math.min(z + 24, FZ1)), TURF_L, { Mat = GRASS })
		end
		k += 1
	end
	-- the lane: a lighter chalk-edged strip down the middle
	Kit.Box(f, V(-8, 0, Z0), V(8, 0.05, Z1), C(96, 176, 96), { Mat = GRASS, Solid = true, Name = "Path" })
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 8, 0.04, Z0), V(s * 8.6, 0.08, Z1), CHALK)
	end
	-- sidelines, end lines, halfway line
	for _, s in { -1, 1 } do
		line(f, s * FW - 0.4, FZ0, s * FW + 0.4, FZ1)
	end
	line(f, -FW, FZ0 - 0.4, FW, FZ0 + 0.4)
	line(f, -FW, FZ1 - 0.4, FW, FZ1 + 0.4)
	line(f, -FW, ZC - 0.4, FW, ZC + 0.4)
	-- centre circle (segments) and spot
	local R, N = 18, 24
	for i = 0, N - 1 do
		local a = (i + 0.5) / N * 2 * math.pi
		Kit.Part(f, V(0.8, 0.03, 2 * math.pi * R / N + 0.2), CFrame.new(math.cos(a) * R, 0.08, ZC + math.sin(a) * R) * CFrame.Angles(0, -a, 0), CHALK)
	end
	Kit.Disc(f, 0, ZC, 0.1, 2, 0.04, CHALK)
	-- yard numbers along both sides
	for i = 1, 12 do
		local z = FZ0 + i * 24
		local n = math.min(i, 13 - i) * 10
		for _, s in { -1, 1 } do
			line(f, s * (FW - 10), z - 0.25, s * (FW - 2), z + 0.25)
			paint(f, s * (FW - 16), z, 8, 5, tostring(n), CHALK)
		end
	end
	-- end-zone words
	paint(f, -50, FZ0 - 12, 40, 9, "SPECTERS", ORANGE)
	paint(f, 50, FZ0 - 12, 40, 9, "BANSHEES", TEAL)
	-- running track
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 100, 0, SZ0), V(s * 109, 0.05, SZ1), TRACK, { Mat = Enum.Material.Rubber })
		for _, lx in { 103, 106 } do
			Kit.Box(f, V(s * lx - 0.15, 0.05, SZ0), V(s * lx + 0.15, 0.07, SZ1), CHALK)
		end
	end
	-- painted team logos on the ghost areas
	for i, a in AREAS do
		local x, z, r = a[1], a[2], a[3]
		local main, trim = if i % 2 == 1 then PURPLE else TEAL, if i % 2 == 1 then ORANGE else WHITE
		Kit.Disc(f, x, z, 0.1, r * 2 + 1.5, 0.04, CHALK)
		Kit.Disc(f, x, z, 0.12, r * 2 - 1, 0.04, Kit.Vivid(main))
		Kit.Disc(f, x, z, 0.14, r * 1.3, 0.02, Kit.Vivid(trim))
		Kit.Disc(f, x, z, 0.16, r * 1.1, 0.02, Kit.Vivid(main))
		paint(f, x, z, r * 1.0, r * 0.8, if i % 2 == 1 then "S" else "B", Kit.Vivid(trim))
	end
	-- boss end zone: gold ring and navy disc
	Kit.Disc(f, 0, BOSS_Z, 0.1, 55, 0.04, Kit.Vivid(GOLD))
	Kit.Disc(f, 0, BOSS_Z, 0.12, 52, 0.04, C(40, 50, 90))
	-- a big friendly ghost logo ("BOO!") painted in the end zone
	Kit.Disc(f, 0, BOSS_Z + 3, 0.16, 26, 0.03, WHITE)
	Kit.Box(f, V(-13, 0.13, BOSS_Z - 10), V(13, 0.16, BOSS_Z + 3), WHITE)
	for _, hx in { -8.7, 0, 8.7 } do
		Kit.Disc(f, hx, BOSS_Z - 10, 0.16, 8.6, 0.03, WHITE)
	end
	for _, ex in { -5, 5 } do
		Kit.Disc(f, ex, BOSS_Z + 4, 0.19, 4.4, 0.03, DARK)
	end
	Kit.Disc(f, 0, BOSS_Z - 3, 0.19, 5, 0.03, DARK)
	paint(f, 0, BOSS_Z + 17, 14, 4, "BOO!", Kit.Vivid(GOLD))
	for i = 0, 15 do
		local a = i / 16 * 2 * math.pi
		Kit.Part(f, V(0.6, 0.03, 2.4), CFrame.new(math.cos(a) * 24, 0.15, BOSS_Z + math.sin(a) * 24) * CFrame.Angles(0, -a, 0), WHITE)
	end
	-- corner flags
	for _, c in { { -FW, FZ0 }, { FW, FZ0 }, { -FW, FZ1 }, { FW, FZ1 } } do
		Kit.Box(f, V(c[1] - 0.15, 0, c[2] - 0.15), V(c[1] + 0.15, 5, c[2] + 0.15), WHITE)
		Kit.Part(f, V(0.1, 1.4, 2), CFrame.new(c[1], 4.3, c[2] + 1), if c[1] < 0 then ORANGE else TEAL)
	end
	-- the match ball on the centre spot
	Kit.Ball(f, 2, V(0, 1.1, ZC), WHITE)
	Kit.Ball(f, 0.9, V(0.4, 1.7, ZC - 0.6), DARK)
end

local function goalpost(f: Instance, z: number, dir: number)
	local m = Kit.Model(f, "Goalpost")
	local gold = Kit.Vivid(GOLD)
	for _, sx in { -14, 14 } do
		Kit.Cyl(m, 3, 1.6, CFrame.new(sx, 1.5, z), PURPLE, { Mat = FABRIC, Solid = true })
		Kit.Cyl(m, 30, 0.8, CFrame.new(sx, 15, z), gold, STEEL_O)
		Kit.Part(m, V(0.4, 3, 1.6), CFrame.new(sx, 28.5, z + dir * 0.9), if sx < 0 then ORANGE else TEAL)
		Kit.AddCircle(sx, z, 2)
	end
	Kit.CylFlat(m, 28.8, 0.8, V(0, 12, z), "X", gold, STEEL_O)
	-- a cheeky ghost sitting on the crossbar
	Kit.Ball(m, 2.6, V(-6, 13.6, z), GHOST, { Transp = 0.2 })
	for _, dx in { -0.5, 0.5 } do
		Kit.Ball(m, 0.5, V(-6 + dx, 14, z - dir * 1.2), DARK)
	end
end

--==================================================================
-- STANDS
--==================================================================
local function stands(f: Instance)
	local sections = 4
	local secLen = (SZ1 - SZ0) / sections
	for _, s in { -1, 1 } do
		local teamA, teamB = if s < 0 then PURPLE else TEAL, if s < 0 then ORANGE else WHITE
		-- back wall (play-area edge) and its cap
		Kit.Box(f, V(s * 140, -0.5, Z0 + 4), V(s * 146, 36, Z1 - 4), CONC_D, { Mat = CONCRETE, Solid = true, Shadow = true })
		Kit.Box(f, V(s * 139.6, 36, Z0 + 4), V(s * 146.4, 37.2, Z1 - 4), Kit.Vivid(teamA), STEEL_O)
		-- padded barrier with ad boards
		Kit.Box(f, V(s * 109, 0, SZ0), V(s * 111, 3.4, SZ1), CONC, { Mat = CONCRETE, Solid = true })
		Kit.Box(f, V(s * 108.8, 3.4, SZ0), V(s * 111.2, 3.9, SZ1), Kit.Vivid(teamA), { Mat = FABRIC })
		local ads: { string } = if s < 0 then { "BOO-COLA", "GHOST GUM", "GO SPECTERS!", "MOON PIZZA", "HOWL FM", "SPOOKY SNACKS" } else { "SLIME SODA", "GO BANSHEES!", "COMET CANDY", "BOO-COLA", "PUMPKIN PIE CO.", "GHOST GUM" }
		local adLen = (SZ1 - SZ0) / #ads
		for i, t in ads do
			local z = SZ0 + (i - 0.5) * adLen
			Props.SignBoard(f, V(s * 108.7, 1.7, z), adLen - 6, 2.6, -s, 0, t, if i % 2 == 0 then DARK else Kit.Vivid(teamA), if i % 2 == 0 then Kit.Vivid(teamB) else WHITE)
		end
		-- seat tiers (solid steps) with team-colour seat rows in sections
		for t = 0, TIERS - 1 do
			local xi = TIER_X0 + t * TIER_D
			local top = (t + 1) * TIER_H
			Kit.Box(f, V(s * xi, 0, SZ0), V(s * 140, top, SZ1), if t % 2 == 0 then CONC else C(120, 124, 136), { Mat = CONCRETE, Solid = true })
			for sec = 0, sections - 1 do
				local za, zb = SZ0 + sec * secLen + 2.5, SZ0 + (sec + 1) * secLen - 2.5
				local col = if (sec + t) % 2 == 0 then teamA else teamB
				Kit.Box(f, V(s * (xi + 1.6), top, za), V(s * (xi + 2.8), top + 1.3, zb), Kit.Vivid(col), { Mat = Enum.Material.Plastic })
			end
		end
		-- aisle handrails between the sections
		local topX, topY = TIER_X0 + TIERS * TIER_D, TIERS * TIER_H
		for sec = 1, sections - 1 do
			local z = SZ0 + sec * secLen
			local a, b = V(s * TIER_X0, 3.2, z), V(s * topX, topY + 3, z)
			Kit.Part(f, V(0.4, 0.4, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), STEEL, STEEL_O)
		end
		-- team banners on the back wall
		for i = 0, 3 do
			local z = SZ0 + (i + 0.5) * secLen
			Kit.Box(f, V(s * 139.4, 33, z - 7), V(s * 139.8, 33.5, z + 7), STEEL, STEEL_O)
			local cf = CFrame.new(s * 139.4, 26.5, z) * CFrame.Angles(0, Kit.FaceYaw(-s, 0), 0)
			local col = if i % 2 == 0 then teamA else teamB
			local p = Kit.Part(f, V(13, 12, 0.25), cf, Kit.Vivid(col), { Mat = FABRIC, Name = "SignBoard" })
			Kit.Sign(p, Enum.NormalId.Front, if s < 0 then "SPOOKTON SPECTERS" else "BOOVILLE BANSHEES", if i % 2 == 0 then WHITE else DARK)
			Kit.Wedge(f, V(13, 2, 0.25), cf * CFrame.new(0, -7, 0) * CFrame.Angles(math.pi, 0, 0), Kit.Vivid(col), { Mat = FABRIC })
		end
		-- upper deck outside the wall (decor): base, sloped seating, seat stripes, roof edge
		Kit.Box(f, V(s * 146, 0, SZ0), V(s * 188, 34, SZ1), CONC_D, { Mat = CONCRETE })
		local rise, run = 26, 42
		local ang = math.atan2(rise, run)
		Kit.Wedge(f, V(SZ1 - SZ0, rise, run), CFrame.new(s * (146 + run / 2), 34 + rise / 2, ZC) * CFrame.Angles(0, s * math.pi / 2, 0), CONC, { Mat = CONCRETE })
		for i = 1, 6 do
			local d = i / 7
			local pos = V(s * (146 + run * d), 34 + rise * d + 0.5, ZC)
			Kit.Part(f, V(2.4, 0.8, SZ1 - SZ0 - 4), CFrame.new(pos) * CFrame.Angles(0, 0, s * ang), Kit.Vivid(if i % 2 == 0 then teamA else teamB), { Mat = Enum.Material.Plastic })
		end
		-- pennants along the wall cap
		for i = 0, 13 do
			local z = Z0 + 18 + i * 25
			Kit.Box(f, V(s * 143 - 0.15, 37.2, z - 0.15), V(s * 143 + 0.15, 43, z + 0.15), STEEL, STEEL_O)
			Kit.Wedge(f, V(0.2, 2, 3.2), CFrame.new(s * 143, 41.8, z + 1.6) * CFrame.Angles(0, 0, 0), Kit.Vivid(if i % 2 == 0 then teamA else teamB), { Mat = FABRIC })
		end
		-- ghost fans in the seats (some cheering, some floating up out of their seat)
		for i = 1, 16 do
			local t = Kit.Rng:NextInteger(0, TIERS - 1)
			local z = Kit.Rng:NextNumber(SZ0 + 6, SZ1 - 6)
			local x = s * (TIER_X0 + t * TIER_D + 1.2)
			ghostFan(f, x, (t + 1) * TIER_H, z, s, i % 3 == 0)
		end
		for i = 1, 6 do
			local d = Kit.Rng:NextNumber(0.15, 0.85)
			ghostFan(f, s * (146 + run * d), 34 + rise * d + 1, Kit.Rng:NextNumber(SZ0 + 10, SZ1 - 10), s, i % 2 == 0)
		end
	end
	for i, p in { V(-124, 26, Z0 + 140), V(126, 28, Z0 + 230), V(-120, 30, Z0 + 300) } do
		local g = Kit.Ball(f, 2.6, p, GHOST, { Transp = 0.25, Name = "FloatingFan" })
		Kit.Float(g, 1.4 + i * 0.2)
	end
end

local function floodlights(f: Instance)
	for _, z in { Z0 + 30, Z1 - 30 } do
		for _, s in { -1, 1 } do
			local m = Kit.Model(f, "Floodlight")
			local x = s * 176
			Kit.Cyl(m, 76, 3, CFrame.new(x, 38, z), STEEL, STEEL_O)
			Kit.Box(m, V(x - 3, 0, z - 3), V(x + 3, 2, z + 3), CONC_D, { Mat = CONCRETE })
			-- lamp bank tilted toward the field
			local head = CFrame.new(x - s * 2, 78, z) * CFrame.Angles(0, Kit.FaceYaw(-s, 0), 0) * CFrame.Angles(-0.45, 0, 0)
			Kit.Part(m, V(20, 10, 1.6), head, DARK, STEEL_O)
			Kit.Part(m, V(20.6, 0.6, 2), head * CFrame.new(0, 5.3, 0), STEEL, STEEL_O)
			for r = 0, 1 do
				for c = 0, 3 do
					Kit.Part(m, V(3.4, 3, 0.4), head * CFrame.new(-7.5 + c * 5, -2.2 + r * 4.4, -0.9), LAMP, { Mat = if (r + c) % 2 == 0 then NEON else Enum.Material.SmoothPlastic })
				end
			end
			-- the light itself sits lower over the track so it reaches the field
			local glow = Kit.Part(m, V(1, 1, 1), CFrame.new(s * 104, 44, z + (if z < ZC then 30 else -30)), LAMP, { Transp = 1, Name = "FloodGlow" })
			Kit.Light(glow, C(235, 240, 255), 60, 0.55)
		end
	end
end

--==================================================================
-- SCOREBOARD (over the far gate, bottom Y 52)
--==================================================================
local function scoreboard(f: Instance)
	local m = Kit.Model(f, "Scoreboard")
	local z = Z1 - 8
	local y0, y1 = 52, 80
	for _, sx in { -50, 50 } do
		Kit.Box(m, V(sx - 1.6, 0, z - 1.6), V(sx + 1.6, y1 + 2, z + 1.6), STEEL, { Mat = METAL, Solid = true })
		Kit.Box(m, V(sx - 2.6, 0, z - 2.6), V(sx + 2.6, 3, z + 2.6), CONC_D, { Mat = CONCRETE, Solid = true })
		Kit.AddCircle(sx, z, 4)
	end
	Kit.Box(m, V(-48, y0, z - 1.2), V(48, y1, z + 1.2), DARK, STEEL_O)
	Kit.Box(m, V(-49, y1, z - 1.5), V(49, y1 + 1.4, z + 1.5), Kit.Vivid(GOLD), STEEL_O)
	Kit.Box(m, V(-49, y0 - 1.4, z - 1.5), V(49, y0, z + 1.5), Kit.Vivid(GOLD), STEEL_O)
	local function panel(x: number, y: number, w: number, h: number, text: string, bg: Color3, fg: Color3)
		local p = Kit.Part(m, V(w, h, 0.3), CFrame.new(x, y, z - 1.3), bg, { Name = "SignBoard" })
		Kit.Sign(p, Enum.NormalId.Front, text, fg)
	end
	panel(0, 76.5, 50, 4.4, "HAUNTED STADIUM", DARK, Kit.Vivid(GOLD))
	panel(-28, 70.5, 36, 4, "SPECTERS", Kit.Vivid(PURPLE), WHITE)
	panel(28, 70.5, 36, 4, "BANSHEES", Kit.Vivid(TEAL), WHITE)
	panel(-28, 61.5, 18, 11, "13", C(40, 20, 20), C(255, 190, 90))
	panel(28, 61.5, 18, 11, "13", C(40, 20, 20), C(255, 190, 90))
	panel(0, 66, 18, 4, "QUARTER", DARK, WHITE)
	panel(0, 61, 18, 4, "MIDNIGHT", C(20, 30, 40), C(140, 255, 160))
	panel(0, 56, 30, 3, "TIME 00:13", DARK, C(255, 220, 120))
	-- horn speakers on top
	for _, sx in { -20, 20 } do
		Kit.Box(m, V(sx - 0.3, y1 + 1.4, z - 0.3), V(sx + 0.3, y1 + 5, z + 0.3), STEEL, STEEL_O)
		Kit.Wedge(m, V(3, 3, 3.6), CFrame.new(sx, y1 + 5.5, z - 0.8) * CFrame.Angles(0, math.pi, 0), C(200, 200, 205), STEEL_O)
	end
	local glow = Kit.Part(m, V(1, 1, 1), CFrame.new(0, 60, z - 14), C(255, 220, 160), { Transp = 1, Name = "ScoreGlow" })
	Kit.Light(glow, C(255, 210, 150), 40, 0.6)
end

--==================================================================
-- EXTRAS
--==================================================================
local function mascot(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "MascotStatue")
	Kit.Box(m, V(x - 6, 0, z - 6), V(x + 6, 4, z + 6), C(200, 200, 210), { Mat = Enum.Material.Marble, Solid = true })
	Kit.Box(m, V(x - 6.4, 4, z - 6.4), V(x + 6.4, 4.6, z + 6.4), Kit.Vivid(GOLD), STEEL_O)
	Props.SignBoard(m, V(x, 2.2, z - 6.05), 10, 2.4, 0, -1, "BOOSTER, OUR MASCOT", DARK, Kit.Vivid(GOLD))
	local y = 4.6
	-- ghost body with a wavy hem, team jersey, eyes and a big smile
	Kit.Ball(m, 9, V(x, y + 12, z), GHOST)
	Kit.Cyl(m, 8, 9, CFrame.new(x, y + 7.5, z), GHOST)
	for i = 0, 5 do
		local a = i / 6 * 2 * math.pi
		Kit.Ball(m, 3.4, V(x + math.cos(a) * 3.3, y + 3.4, z + math.sin(a) * 3.3), GHOST)
	end
	Kit.Cyl(m, 4, 9.3, CFrame.new(x, y + 8.5, z), Kit.Vivid(PURPLE), { Mat = FABRIC })
	Kit.Cyl(m, 0.8, 9.4, CFrame.new(x, y + 10.2, z), Kit.Vivid(ORANGE), { Mat = FABRIC })
	local num = Kit.Part(m, V(3, 3, 0.2), CFrame.new(x, y + 8.4, z - 4.65), Kit.Vivid(PURPLE), { Name = "SignBoard" })
	Kit.Sign(num, Enum.NormalId.Front, "13", WHITE)
	for _, dx in { -1.5, 1.5 } do
		Kit.Ball(m, 1.6, V(x + dx, y + 13.5, z - 3.6), DARK)
		Kit.Ball(m, 0.5, V(x + dx + 0.3, y + 13.9, z - 4.3), WHITE)
	end
	Kit.Part(m, V(3, 0.6, 0.4), CFrame.new(x, y + 11.3, z - 4.2), C(200, 60, 80))
	-- cap
	Kit.Cyl(m, 1.4, 6.4, CFrame.new(x, y + 16.4, z), Kit.Vivid(PURPLE), { Mat = FABRIC })
	Kit.Part(m, V(4.4, 0.4, 3), CFrame.new(x, y + 15.9, z - 3.6), Kit.Vivid(ORANGE), { Mat = FABRIC })
	-- one arm up with a giant foam finger, the other waving a pennant
	local a1 = CFrame.new(x + 4.4, y + 12, z) * CFrame.Angles(0, 0, -0.35)
	Kit.Part(m, V(1.8, 6, 1.8), a1 * CFrame.new(0, 3, 0), GHOST)
	local hand = a1 * CFrame.new(0, 7, 0)
	Kit.Part(m, V(3, 3.4, 2), hand, Kit.Vivid(ORANGE), { Mat = FABRIC })
	Kit.Part(m, V(1.1, 4, 1.1), hand * CFrame.new(0.2, 3.6, 0), Kit.Vivid(ORANGE), { Mat = FABRIC })
	local a2 = CFrame.new(x - 4.4, y + 11, z) * CFrame.Angles(0, 0, 0.9)
	Kit.Part(m, V(1.8, 5, 1.8), a2 * CFrame.new(0, 2.5, 0), GHOST)
	Kit.Part(m, V(0.3, 7, 0.3), a2 * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, -0.9), STEEL, STEEL_O)
	Kit.Wedge(m, V(0.2, 2.6, 5), a2 * CFrame.new(-1.6, 7.6, 2.3) * CFrame.Angles(0, 0, -0.9) * CFrame.Angles(0, 0, 0), Kit.Vivid(PURPLE), { Mat = FABRIC })
	local spot = Kit.Part(m, V(1, 1, 1), CFrame.new(x, y + 24, z - 6), C(255, 240, 210), { Transp = 1, Name = "MascotLight" })
	Kit.Light(spot, C(255, 236, 200), 26, 0.7)
	Kit.AddRect(x - 8, z - 8, x + 8, z + 8)
end

local function dugout(f: Instance, x: number, z0: number, z1: number, s: number, team: Color3)
	local m = Kit.Model(f, "Dugout")
	-- back panel, clear roof, team-colour bench
	Kit.Box(m, V(x + s * 3, 0, z0), V(x + s * 3.6, 7, z1), CONC_D, { Mat = CONCRETE, Solid = true })
	for _, zz in { z0, z1 } do
		Kit.Box(m, V(x - s * 3, 0, zz - 0.3), V(x + s * 3.6, 7, zz + 0.3), STEEL, STEEL_O)
	end
	Kit.Box(m, V(x - s * 3.2, 7, z0 - 0.5), V(x + s * 3.8, 7.4, z1 + 0.5), C(200, 230, 255), { Mat = GLASS, Transp = 0.45 })
	Kit.Box(m, V(x + s * 0.6, 1.8, z0 + 1), V(x + s * 2.8, 2.4, z1 - 1), Kit.Vivid(team), { Solid = true })
	Kit.Box(m, V(x + s * 2.4, 2.4, z0 + 1), V(x + s * 2.9, 4.6, z1 - 1), Kit.Vivid(team))
	-- water cooler and a towel stack
	Kit.Cyl(m, 3, 2.4, CFrame.new(x - s * 1.6, 1.5, z0 + 2.6), Kit.Vivid(ORANGE), { Solid = true })
	Kit.Cyl(m, 0.5, 2.6, CFrame.new(x - s * 1.6, 3.2, z0 + 2.6), WHITE)
	Kit.Box(m, V(x - s * 2, 0, z1 - 4), V(x - s * 0.6, 1.4, z1 - 2.6), WHITE, { Mat = FABRIC })
	-- two ghost players resting on the bench
	for _, zz in { z0 + 10, z0 + 17 } do
		ghostFan(m, x + s * 1.6, 2.4, zz, s, false)
	end
	Kit.AddRect(math.min(x - s * 3.4, x + s * 4), z0 - 1, math.max(x - s * 3.4, x + s * 4), z1 + 1)
end

local function popcorn(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "PopcornCart")
	Kit.Box(m, V(x - 3, 1.4, z - 2), V(x + 3, 4.4, z + 2), C(220, 50, 60), { Solid = true })
	for i = -2, 2, 2 do
		Kit.Box(m, V(x + i - 0.4, 1.4, z - 2.05), V(x + i + 0.4, 4.4, z - 2), WHITE)
	end
	Kit.Box(m, V(x - 2.6, 4.4, z - 1.6), V(x + 2.6, 8.4, z + 1.6), C(220, 240, 255), { Mat = GLASS, Transp = 0.4 })
	Kit.Box(m, V(x - 2.4, 4.4, z - 1.4), V(x + 2.4, 6.4, z + 1.4), C(255, 240, 180), { Mat = Enum.Material.Pebble })
	Kit.Box(m, V(x - 2.9, 8.4, z - 1.9), V(x + 2.9, 9, z + 1.9), C(220, 50, 60))
	for _, dx in { -2.4, 2.4 } do
		Kit.CylFlat(m, 0.6, 2.4, V(x + dx, 1.2, z - 2.2), "X", DARK)
		Kit.CylFlat(m, 0.6, 2.4, V(x + dx, 1.2, z + 2.2), "X", DARK)
	end
	Kit.Cyl(m, 6, 0.3, CFrame.new(x + 3.4, 12, z), STEEL, STEEL_O)
	for i = 0, 5 do
		Kit.Part(m, V(5, 0.3, 3.2), CFrame.new(x + 3.4, 15, z) * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(2.2, 0, 0) * CFrame.Angles(0, 0, -0.3), if i % 2 == 0 then C(220, 50, 60) else WHITE, { Mat = FABRIC })
	end
	Props.SignBoard(m, V(x, 10.2, z - 1), 6, 1.6, 0, -1, "POPCORN", C(220, 50, 60), WHITE)
	-- a couple of popcorn boxes on the grass
	Kit.Box(m, V(x + 4.6, 0, z - 3), V(x + 5.6, 1.4, z - 2), C(220, 50, 60))
	Kit.Box(m, V(x + 4.6, 1.4, z - 3), V(x + 5.6, 1.9, z - 2), C(255, 240, 180))
	Kit.AddCircle(x, z, 6.5)
end

local function trophy(f: Instance, x: number, z: number)
	local m = Kit.Model(f, "Trophy")
	Kit.Box(m, V(x - 4, 0, z - 4), V(x + 4, 5, z + 4), DARK, { Mat = Enum.Material.Marble, Solid = true })
	Kit.Box(m, V(x - 4.3, 5, z - 4.3), V(x + 4.3, 5.5, z + 4.3), Kit.Vivid(GOLD), STEEL_O)
	local gold: Kit.Opts = { Mat = Enum.Material.Foil, Refl = 0.15 }
	Kit.Box(m, V(x - 2, 5.5, z - 2), V(x + 2, 7.5, z + 2), C(70, 40, 30), { Mat = Enum.Material.Wood })
	Kit.Cyl(m, 3, 1, CFrame.new(x, 9, z), GOLD, gold)
	Kit.Cyl(m, 5, 5, CFrame.new(x, 13, z), GOLD, gold)
	Kit.Ball(m, 5, V(x, 11, z), GOLD, gold)
	Kit.Cyl(m, 0.5, 5.6, CFrame.new(x, 15.6, z), GOLD, gold)
	for _, sx in { -1, 1 } do
		Kit.CylFlat(m, 0.6, 3.4, V(x + sx * 3, 13, z), "Z", GOLD, gold)
	end
	Kit.Ball(m, 1.6, V(x, 16.5, z), C(255, 250, 230), { Mat = NEON })
	Props.SignBoard(m, V(x, 2.6, z - 4.05), 7, 2, 0, -1, "GHOST CUP", DARK, Kit.Vivid(GOLD))
	Kit.AddCircle(x, z, 6)
end

local function extras(f: Instance)
	mascot(f, -78, Z0 + 52)
	dugout(f, -104, Z0 + 46, Z0 + 76, -1, PURPLE)
	dugout(f, 104, Z0 + 262, Z0 + 292, 1, TEAL)
	popcorn(f, 54, Z0 + 56)
	trophy(f, -56, Z0 + 312)
	-- kit bags and a ball rack by the sideline
	for _, p in { { 90, Z0 + 120 }, { -90, Z0 + 296 }, { 46, Z0 + 296 } } do
		if Kit.IsFree(p[1], p[2], 3) then
			Kit.Box(f, V(p[1] - 2.4, 0, p[2] - 1), V(p[1] + 2.4, 1.6, p[2] + 1), Kit.Vivid(if p[1] < 0 then PURPLE else TEAL), { Mat = FABRIC })
			for i = 0, 2 do
				Kit.Ball(f, 1.6, V(p[1] - 1.6 + i * 1.6, 2.4, p[2]), WHITE)
			end
			Kit.AddCircle(p[1], p[2], 3)
		end
	end
	-- a beach ball and a foam finger drifting over the field
	local ball = Kit.Ball(f, 3, V(30, 26, Z0 + 140), C(255, 120, 160), { Name = "FloatingBall" })
	Kit.Float(ball, 1.6)
	local finger = Kit.Part(f, V(2.4, 4, 1.2), CFrame.new(-34, 30, Z0 + 210) * CFrame.Angles(0, 0, 0.3), Kit.Vivid(ORANGE), { Mat = FABRIC, Name = "FloatingFinger" })
	Kit.Float(finger, 1.2)
end

--==================================================================
-- BUILD
--==================================================================
function Stadium.Build(map: Instance)
	local f = Kit.Folder(map, "Stadium")
	field(f)
	goalpost(f, Z0 + 48, -1)
	goalpost(f, Z1 - 26, 1)
	stands(f)
	floodlights(f)
	scoreboard(f)
	extras(f)
end

return Stadium
