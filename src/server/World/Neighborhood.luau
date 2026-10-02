--!strict
-- ZONE 1: Haunted Neighborhood (Z -60..260). Spawn plaza + Ghost Hunter HQ at the south end,
-- a main road along X = 0 to the Cemetery gate, a cross street at Z 110..124 leading east to
-- the event arena, and candy-coloured houses placed on a grid wherever the keep-out map allows.
-- Palette: bright grass, warm houses, orange accents, purple paranormal touches, ectoplasm
-- green. Glow is reserved for the front windows, street lamps, car headlights and the HQ
-- antenna; side windows, plaza rings, chevrons, bands, doors and tanks are solid colours.
-- Materials: Asphalt roads, Concrete sidewalks, Slate roof shingles, Brick chimneys, Wood posts.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Neighborhood = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local WALLS = {
	C(255, 175, 190), C(255, 214, 168), C(255, 225, 140), C(250, 236, 200), C(215, 180, 255),
	C(255, 190, 140), C(240, 200, 150), C(255, 155, 135),
}
local ROOFS = { C(120, 60, 170), C(60, 120, 190), C(200, 70, 110), C(70, 150, 110), C(230, 110, 50), C(90, 70, 160) }
local WINDOWS = { C(255, 235, 120), C(150, 255, 140), C(205, 140, 255), C(255, 200, 90) }
local DOORS = { C(140, 70, 200), C(255, 110, 70), C(60, 170, 150), C(230, 70, 120) }
local TRIM = C(255, 250, 245)

--==================================================================
-- HOUSE
--==================================================================
-- Front windows glow; side windows (lit = false) are warm painted glass.
local function window(m: Instance, cf: CFrame, glow: Color3, lit: boolean?)
	Kit.Part(m, V(4, 4, 0.3), cf, TRIM, { Mat = Enum.Material.Wood })
	local glass: Kit.Opts = if lit == false then { Refl = 0.2 } else { Mat = NEON }
	Kit.Part(m, V(3.2, 3.2, 0.3), cf * CFrame.new(0, 0, -0.12), if lit == false then Kit.Vivid(glow) else glow, glass)
end

local function house(parent: Instance, cx: number, cz: number, fx: number, fz: number)
	local rng = Kit.Rng
	local W = rng:NextInteger(18, 23) -- along local X
	local D = rng:NextInteger(15, 19) -- along local Z (front = -Z)
	local twoStory = rng:NextNumber() < 0.35
	local H = if twoStory then 20 else 13
	local RH = math.floor(W * 0.38)
	local base = CFrame.new(cx, 0, cz) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local m = Kit.Model(parent, "House")
	local wall = Kit.Pick(WALLS)
	local roof = Kit.Pick(ROOFS)
	local glow = Kit.Pick(WINDOWS)

	Kit.Part(m, V(W + 0.8, 1.2, D + 0.8), base * CFrame.new(0, 0.6, 0), C(150, 130, 170), { Mat = Enum.Material.Slate, Solid = true })
	Kit.Part(m, V(W, H, D), base * CFrame.new(0, H / 2, 0), wall, { Solid = true, Shadow = true, Name = "Body" })
	-- corner trims (front)
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(0.9, H, 0.9), base * CFrame.new(sx * W / 2, H / 2, -D / 2), TRIM)
	end
	-- gable roof: two wedges meeting at the ridge (ridge along local X)
	local half = D / 2 + 1.5
	Kit.Part(m, V(W + 2.4, 0.6, D + 3.4), base * CFrame.new(0, H + 0.3, 0), TRIM)
	Kit.Wedge(m, V(W + 2, RH, half), base * CFrame.new(0, H + 0.6 + RH / 2, -half / 2), roof, { Mat = Enum.Material.Slate, Solid = true, Shadow = true })
	Kit.Wedge(m, V(W + 2, RH, half), base * CFrame.new(0, H + 0.6 + RH / 2, half / 2) * CFrame.Angles(0, math.pi, 0), roof, { Mat = Enum.Material.Slate, Solid = true, Shadow = true })
	-- chimney poking through the back slope
	local chX = (if rng:NextNumber() < 0.5 then -1 else 1) * W * 0.28
	Kit.Part(m, V(2.4, RH + 2.5, 2.4), base * CFrame.new(chX, H + (RH + 2.5) / 2 + 0.6, D * 0.22), C(190, 110, 100), { Mat = Enum.Material.Brick, Shadow = true })
	Kit.Part(m, V(3, 0.6, 3), base * CFrame.new(chX, H + RH + 3.4, D * 0.22), C(90, 70, 110))
	if rng:NextNumber() < 0.25 then
		-- a puff of ectoplasm smoke
		Kit.Ball(m, 2.2, (base * CFrame.new(chX, H + RH + 5, D * 0.22)).Position, Kit.Vivid(C(150, 255, 160)), { Transp = 0.4 })
	end
	-- front windows
	local rows: { number } = if twoStory then { H * 0.3, H * 0.72 } else { H * 0.5 }
	for _, wy in rows do
		for _, sx in { -1, 1 } do
			window(m, base * CFrame.new(sx * W * 0.28, wy, -D / 2 - 0.15), glow)
		end
	end
	if twoStory then
		window(m, base * CFrame.new(0, H * 0.72, -D / 2 - 0.15), Kit.Pick(WINDOWS))
	end
	-- side windows
	for _, sx in { -1, 1 } do
		window(m, base * CFrame.new(sx * (W / 2 + 0.15), H * 0.5, 0) * CFrame.Angles(0, -sx * math.pi / 2, 0), glow, false)
	end
	-- door
	Kit.Part(m, V(5, 8, 0.3), base * CFrame.new(0, 4.6, -D / 2 - 0.1), TRIM)
	Kit.Part(m, V(4, 7, 0.4), base * CFrame.new(0, 4.4, -D / 2 - 0.2), Kit.Pick(DOORS))
	Kit.Ball(m, 0.6, (base * CFrame.new(1.3, 4.2, -D / 2 - 0.5)).Position, C(255, 215, 80), { Refl = 0.3 }) -- brass knob
	-- porch with a little roof
	local pw = W * 0.6
	Kit.Part(m, V(pw, 0.8, 5), base * CFrame.new(0, 0.4, -D / 2 - 2.5), C(170, 120, 85), { Mat = Enum.Material.WoodPlanks, Solid = true })
	local porchTop = if twoStory then 9.5 else 9.2
	Kit.Part(m, V(pw + 0.6, 0.5, 5.6), base * CFrame.new(0, porchTop + 0.25, -D / 2 - 2.8), roof)
	for _, sx in { -1, 1 } do
		Kit.Part(m, V(0.6, porchTop - 0.8, 0.6), base * CFrame.new(sx * (pw / 2 - 0.4), 0.8 + (porchTop - 0.8) / 2, -D / 2 - 5), TRIM, { Mat = Enum.Material.Wood })
	end
	if rng:NextNumber() < 0.55 then
		local p = base * CFrame.new(pw * 0.32, 0.8, -D / 2 - 3.2)
		local front = base.LookVector
		Props.Pumpkin(m, p.Position, 2.4, front.X, front.Z)
	end

	-- yard extras (only where the keep-out map allows)
	local function free(lx: number, lz: number, r: number): boolean
		local p = (base * CFrame.new(lx, 0, lz)).Position
		return Kit.IsFree(p.X, p.Z, r)
	end
	local yard = -D / 2 - 9
	if rng:NextNumber() < 0.45 and free(-W / 2 - 1, yard, 1) and free(W / 2 + 1, yard, 1) then
		local a1 = (base * CFrame.new(-W / 2 - 1, 0, yard)).Position
		local a2 = (base * CFrame.new(-2.5, 0, yard)).Position
		local b1 = (base * CFrame.new(2.5, 0, yard)).Position
		local b2 = (base * CFrame.new(W / 2 + 1, 0, yard)).Position
		Props.Fence(m, a1, a2, "picket")
		Props.Fence(m, b1, b2, "picket")
	elseif free(-W / 2 + 1, yard + 1, 1.5) then
		-- mailbox
		local mp = base * CFrame.new(-W / 2 + 1, 0, yard + 1)
		Kit.Part(m, V(0.5, 3.4, 0.5), mp * CFrame.new(0, 1.7, 0), C(110, 80, 60), { Mat = Enum.Material.Wood })
		Kit.Part(m, V(1.4, 1.3, 2.2), mp * CFrame.new(0, 3.9, 0), Kit.Pick(DOORS))
		Kit.Part(m, V(0.15, 1.2, 0.4), mp * CFrame.new(0.8, 4.4, 0.6), C(255, 70, 90))
	end
	if rng:NextNumber() < 0.3 then
		Props.FloatingPumpkin(m, (base * CFrame.new(-pw * 0.3, 11 + rng:NextNumber(0, 3), -D / 2 - 6)).Position)
	end
	Kit.AddCircle(cx, cz, math.max(W, D) / 2 + 4)
end

--==================================================================
-- SPAWN PLAZA + HQ
--==================================================================
local function chevron(parent: Instance, tip: Vector3, dir: Vector3, color: Color3)
	local perp = V(-dir.Z, 0, dir.X)
	local paint = Kit.Vivid(color)
	for _, s in { -1, 1 } do
		local arm = (-dir + perp * s).Unit
		local center = tip + arm * 2
		Kit.Part(parent, V(1, 0.15, 4.6), CFrame.lookAt(center, center + arm), paint)
	end
end

local function plaza(f: Instance)
	local spawnPos = Config.Layout.Spawn
	local sx, sz = spawnPos.X, spawnPos.Z
	Kit.Disc(f, sx, sz, 0.25, 52, 0.6, C(175, 150, 220), { Mat = Enum.Material.Cobblestone, Solid = true })
	Kit.Disc(f, sx, sz, 0.35, 44, 0.2, Kit.Vivid(C(150, 255, 140)))
	Kit.Disc(f, sx, sz, 0.42, 42, 0.3, C(120, 95, 180), { Mat = Enum.Material.Slate, Solid = true })
	Kit.Disc(f, sx, sz, 0.5, 20, 0.2, Kit.Vivid(C(210, 120, 255)))

	local spawn: SpawnLocation = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(14, 1, 14)
	-- top surface at Y = 1.1; face +Z (forward)
	spawn.CFrame = CFrame.new(sx, 0.6, sz) * CFrame.Angles(0, math.pi, 0)
	spawn.Color = C(130, 70, 220)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.CanCollide = true
	spawn.CanQuery = true
	spawn.CanTouch = true
	spawn.CastShadow = false
	spawn.Parent = f
	Kit.Stats.Parts += 1
	local g = Kit.Gui(spawn, Enum.NormalId.Top, 20)
	Kit.Label(g, "👻", C(255, 255, 255), { Pos = UDim2.fromScale(0.15, 0.15), Size = UDim2.fromScale(0.7, 0.7) })
	local border = Kit.Vivid(C(150, 255, 140))
	for _, s in { -1, 1 } do
		Kit.Box(f, V(sx - 7.4, 0.4, sz + s * 7) - V(0, 0, 0.4), V(sx + 7.4, 1.3, sz + s * 7) + V(0, 0, 0.4), border)
		Kit.Box(f, V(sx + s * 7, 0.4, sz - 7) - V(0.4, 0, 0), V(sx + s * 7, 1.3, sz + 7) + V(0.4, 0, 0), border)
	end

	-- plaza lamps on the rim
	for i, a in { 45, 135, 225, 315 } do
		local r = math.rad(a)
		Props.StreetLamp(f, V(sx + math.cos(r) * 23, 0.25, sz + math.sin(r) * 23), C(200, 140, 255), i <= 2)
	end

	-- guide chevrons to the Beginner crate and the upgrade booth
	local beg = Config.Layout.CrateStations.Beginner
	local up = Config.Layout.UpgradeStation
	for _, target in { beg, up } do
		local dir = (V(target.X, 0, target.Z) - V(sx, 0, sz)).Unit
		for i = 1, 3 do
			chevron(f, V(sx, 0.55, sz) + dir * (8 + i * 4.5), dir, if target == beg then C(255, 180, 60) else C(90, 210, 255))
		end
	end
	-- signpost straight ahead of spawn
	local post = V(sx, 0, sz + 19)
	Kit.Box(f, post - V(0.4, 0, 0.4), post + V(0.4, 11, 0.4), C(110, 80, 60), { Mat = Enum.Material.Wood })
	local boards = {
		{ Y = 10, Off = 0, Text = "👻 GHOSTS AHEAD", Col = C(150, 255, 140) },
		-- the player faces +Z, so -X is on their right
		{ Y = 7.6, Off = -3, Text = "CRATES ▶", Col = C(255, 190, 70) },
		{ Y = 5.2, Off = 3, Text = "◀ UPGRADES", Col = C(110, 220, 255) },
	}
	for _, b in boards do
		Props.SignBoard(f, post + V(b.Off, b.Y, -0.6), 8, 2, 0, -1, b.Text, C(50, 30, 85), b.Col)
	end
end

local function hq(f: Instance)
	local purple, dark = C(120, 75, 210), C(60, 40, 110)
	Kit.Box(f, V(-24, 0, -58), V(24, 16, -40), purple, { Mat = Enum.Material.Concrete, Solid = true, Name = "HQ" })
	Kit.Box(f, V(-26, 16, -60), V(26, 17.5, -38), dark, { Mat = Enum.Material.Slate, Solid = true })
	Kit.Ball(f, 18, V(0, 17.5, -50), C(190, 160, 255), { Shadow = true })
	Kit.Box(f, V(-24.3, 5.6, -39.9), V(24.3, 6.4, -39.6), Kit.Vivid(C(150, 255, 140)))
	Kit.Box(f, V(-24.3, 15, -39.9), V(24.3, 15.6, -39.6), Kit.Vivid(C(255, 150, 60)))
	-- big mint door
	Kit.Box(f, V(-7, 0, -39.85), V(7, 12, -39.6), TRIM)
	Kit.Box(f, V(-6, 0, -39.7), V(6, 11, -39.35), Kit.Vivid(C(150, 255, 160)), { Refl = 0.1 })
	-- windows
	for _, x in { -17, -11, 11, 17 } do
		Kit.Box(f, V(x - 2, 8, -39.8), V(x + 2, 12.5, -39.4), C(255, 235, 120), { Mat = NEON })
	end
	-- sign facing +Z (toward spawn)
	local signCF = CFrame.new(0, 21.5, -39) * CFrame.Angles(0, Kit.FaceYaw(0, 1), 0)
	local sign = Kit.Part(f, V(32, 6, 1), signCF, C(45, 25, 80))
	Kit.Part(f, V(33.5, 7.5, 0.5), signCF * CFrame.new(0, 0, 0.6), Kit.Vivid(C(150, 255, 140)))
	Kit.Sign(sign, Enum.NormalId.Front, "GHOST HUNTER HQ", C(255, 230, 90))
	-- antenna + dish
	Kit.Cyl(f, 18, 0.8, CFrame.new(16, 26.5, -50), C(200, 200, 220), { Mat = Enum.Material.Metal })
	local orb = Kit.Ball(f, 2.6, V(16, 36, -50), C(255, 90, 160), { Mat = NEON })
	Kit.Light(orb, C(255, 120, 190), 30, 1.2)
	Kit.Cyl(f, 0.8, 9, CFrame.new(-16, 21, -50) * CFrame.Angles(math.rad(35), 0, 0), C(230, 230, 245))
	Kit.Cyl(f, 3, 1, CFrame.new(-16, 19, -50), C(150, 150, 170))
	-- containment tanks with captured ghosts
	for _, s in { -1, 1 } do
		local x = s * 30
		Kit.Cyl(f, 1, 9, CFrame.new(x, 0.5, -46), dark, { Mat = Enum.Material.Metal, Solid = true })
		local tank = Kit.Cyl(f, 12, 8, CFrame.new(x, 7, -46), Kit.Vivid(C(130, 255, 170)), { Transp = 0.55, Refl = 0.2 })
		Kit.Cyl(f, 1, 9, CFrame.new(x, 13.5, -46), dark, { Mat = Enum.Material.Metal })
		Kit.Ball(f, 3.6, V(x, 7.5, -46), C(240, 245, 255))
		Kit.Emitter(tank, C(150, 255, 180), 2, 2, 0.5)
	end
	Kit.AddRect(-36, -60, 36, -36)
end

--==================================================================
-- ROADS
--==================================================================
local function roads(f: Instance)
	local asphalt = C(72, 64, 92)
	local walk = C(200, 185, 230)
	-- main road X -10..10 from HQ to the gate
	local pave: Kit.Opts = { Mat = Enum.Material.Concrete, Solid = true }
	Kit.Box(f, V(-10, -0.4, -36), V(10, 0.1, 260), asphalt, { Mat = Enum.Material.Asphalt, Solid = true, Name = "MainRoad" })
	for z = 34, 250, 12 do
		Kit.Box(f, V(-0.4, 0.1, z), V(0.4, 0.14, z + 6), C(255, 210, 80))
	end
	-- cross street toward the arena
	Kit.Box(f, V(-136, -0.4, 110), V(63, 0.06, 124), asphalt, { Mat = Enum.Material.Asphalt, Solid = true, Name = "CrossStreet" })
	for x = -130, 55, 12 do
		if x < -16 or x > 14 then
			Kit.Box(f, V(x, 0.06, 116.6), V(x + 6, 0.1, 117.4), C(255, 210, 80))
		end
	end
	-- sidewalks
	for _, s in { -1, 1 } do
		Kit.Box(f, V(s * 10, -0.4, 26), V(s * 14, 0.22, 106), walk, pave)
		Kit.Box(f, V(s * 10, -0.4, 128), V(s * 14, 0.22, 257), walk, pave)
		Kit.Box(f, V(-136, -0.4, if s < 0 then 106 else 124), V(-14, 0.22, if s < 0 then 110 else 128), walk, pave)
		Kit.Box(f, V(14, -0.4, if s < 0 then 106 else 124), V(61, 0.22, if s < 0 then 110 else 128), walk, pave)
	end
	Kit.AddRect(-14, -36, 14, 260, true)
	Kit.AddRect(-136, 106, 63, 128, true)
end

--==================================================================
-- BUILD
--==================================================================
function Neighborhood.Build(map: Instance)
	local f = Kit.Folder(map, "Neighborhood")
	local rng = Kit.Rng

	plaza(f)
	hq(f)
	roads(f)

	-- Houses on a grid; each faces the main road.
	local houses = Kit.Folder(f, "Houses")
	for _, x in { -118, -88, -58, -28, 28, 58, 88, 118 } do
		for z = -40, 230, 30 do
			if Kit.IsFree(x, z, 15) then
				house(houses, x, z, if x < 0 then 1 else -1, 0)
			end
		end
	end

	-- Street lamps along the main road (skipped inside ghost areas)
	local lit = 0
	for z = 34, 250, 24 do
		for _, s in { -1, 1 } do
			local x = s * 12.5
			if Kit.IsFree(x, z, 1, true) then
				lit += 1
				Props.StreetLamp(f, V(x, 0.22, z), Kit.Pick({ C(255, 230, 120), C(170, 255, 150), C(210, 150, 255) }), lit % 2 == 1 and lit <= 9)
			end
		end
	end
	for x = -125, 50, 35 do
		if Kit.IsFree(x, 108, 1, true) then
			Props.StreetLamp(f, V(x, 0.22, 108), C(255, 200, 120), false)
		end
	end

	-- Parked cars (curbside)
	local cars = {
		{ -6, 150, 0, 1 }, { 6, 186, 0, -1 }, { -105, 113.5, 1, 0 }, { -42, 113.5, 1, 0 }, { 40, 120.5, -1, 0 },
		{ 70, -30, 0, 1 }, { -70, 20, 0, -1 },
	}
	for _, c in cars do
		if Kit.IsFree(c[1], c[2], 7.5, true) then
			Props.Car(f, V(c[1], 0.1, c[2]), c[3], c[4], Kit.Pick(Props.Colors.Car))
		end
	end

	-- Trees and pumpkins scattered on free grass
	local trees = 0
	for _ = 1, 260 do
		if trees >= 30 then
			break
		end
		local x, z = rng:NextNumber(-132, 132), rng:NextNumber(-54, 250)
		if Kit.IsFree(x, z, 5) then
			trees += 1
			Props.Tree(f, V(x, 0, z), rng:NextNumber(10, 17))
		end
	end
	local pumpkins = 0
	for _ = 1, 300 do
		if pumpkins >= 26 then
			break
		end
		local x, z = rng:NextNumber(-134, 134), rng:NextNumber(-54, 254)
		if Kit.IsFree(x, z, 2.5) then
			pumpkins += 1
			Props.Pumpkin(f, V(x, 0, z), rng:NextNumber(2.4, 4.6), -x, -z + 100)
			Kit.AddCircle(x, z, 2.5)
		end
	end
	local floats = 0
	for _ = 1, 200 do
		if floats >= 3 then
			break
		end
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(-40, 240)
		if Kit.IsFree(x, z, 3) then
			floats += 1
			Props.FloatingPumpkin(f, V(x, rng:NextNumber(8, 13), z))
		end
	end

	-- Spectral fog accents
	Props.Wisp(f, V(-40, 0, 40), C(170, 110, 255), 14, true)
	Props.Wisp(f, V(55, 0, 135), C(120, 255, 170), 12, true)
	Props.Wisp(f, V(-110, 0, 215), C(200, 120, 255), 16, true)
	Props.Wisp(f, V(30, 0, 240), C(120, 255, 170), 10, false)
	Props.Wisp(f, V(-60, 0, -20), C(170, 110, 255), 12, false)
	Props.Wisp(f, V(110, 0, 20), C(255, 140, 220), 12, false)
end

return Neighborhood
