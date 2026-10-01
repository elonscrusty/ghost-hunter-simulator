--!strict
-- ZONE 2: Cemetery (Z 260..540). Cobblestone path along X = 0 from gate to gate, a giant
-- mausoleum in the north-west corner (tall dome + glowing spire orb, visible from spawn),
-- small crypts, rows of oversized pastel gravestones, twisted trees, lanterns, neon cracks,
-- candy mushrooms, iron fences and slow purple fog. Glow is kept to the lanterns, candles,
-- crypt doorways, the spire orb and the small ectoplasm cracks.

local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Cemetery = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local STONES = { C(190, 180, 230), C(170, 220, 210), C(210, 200, 215), C(180, 200, 240), C(230, 190, 220) }
local EPITAPHS = { "RIP", "BRB", "BOO", "LOL", "GG", "AFK", "R.I.P.\nIN PEACE", "BE BACK\nSOON", "NOT\nHERE" }

-- Gable roof with the ridge along local X (slopes toward local ±Z), bottom at local y = 0.
local function gable(parent: Instance, base: CFrame, length: number, depth: number, height: number, color: Color3)
	local half = depth / 2
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, -half / 2), color, { Solid = true, Shadow = true })
	Kit.Wedge(parent, V(length, height, half), base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), color, { Solid = true, Shadow = true })
end

local function mausoleum(f: Instance)
	local m = Kit.Model(f, "Mausoleum")
	local stone, light, roof = C(215, 205, 240), C(240, 235, 255), C(110, 80, 180)
	local glow = C(120, 255, 170)
	local mint = Kit.Vivid(glow) -- solid trims in the glow colour
	-- stepped platform
	Kit.Box(m, V(-122, 0, 477), V(-78, 1.2, 513), C(150, 140, 180), { Mat = Enum.Material.Slate, Solid = true })
	Kit.Box(m, V(-120, 1.2, 479), V(-82, 2.4, 511), C(170, 160, 200), { Mat = Enum.Material.Slate, Solid = true })
	-- body (front faces +X toward the path)
	Kit.Box(m, V(-118, 2.4, 482), V(-90, 26, 508), stone, { Mat = Enum.Material.Slate, Solid = true, Name = "Body" })
	-- portico columns
	for i = 0, 4 do
		local z = 483.5 + i * 5.75
		Kit.Cyl(m, 22, 2.6, CFrame.new(-85.5, 13.4, z), light, { Solid = true, Shadow = true })
		Kit.Box(m, V(-87, 2.4, z - 1.6), V(-84, 3.2, z + 1.6), light)
	end
	-- entablature + cornice
	Kit.Box(m, V(-119, 24.4, 480), V(-83, 27, 510), light, { Solid = true })
	Kit.Box(m, V(-83.3, 25, 483), V(-82.9, 26.4, 507), mint)
	-- pediment roof (triangle face toward +X)
	gable(m, CFrame.new(-101, 27, 495), 37, 31, 9, roof)
	-- ectoplasm-filled doorway (solid mint, lit by its own green light)
	Kit.Box(m, V(-90.3, 2.4, 487.5), V(-89.9, 17.5, 502.5), light)
	local door = Kit.Box(m, V(-90.1, 2.4, 489), V(-89.6, 16, 501), mint, { Refl = 0.1 })
	Kit.Light(door, glow, 30, 2)
	-- name plate on the entablature, facing +X
	local plateCF = CFrame.new(-82.7, 25.7, 495) * CFrame.Angles(0, Kit.FaceYaw(1, 0), 0)
	local plate = Kit.Part(m, V(18, 2.4, 0.4), plateCF, C(60, 40, 100))
	Kit.Sign(plate, Enum.NormalId.Front, "REST IN PURPLE", C(150, 255, 170))
	-- drum + dome + spire (tall: visible from spawn)
	Kit.Cyl(m, 12, 15, CFrame.new(-104, 36, 495), light, { Solid = true, Shadow = true })
	Kit.Cyl(m, 1, 16.5, CFrame.new(-104, 42.2, 495), mint)
	Kit.Ball(m, 15, V(-104, 42.5, 495), C(150, 110, 230), { Shadow = true })
	Kit.Cyl(m, 14, 1.4, CFrame.new(-104, 56, 495), C(240, 220, 120))
	local orb = Kit.Ball(m, 4.5, V(-104, 64, 495), glow, { Mat = NEON })
	Kit.Light(orb, glow, 40, 1.5)
	Kit.Emitter(orb, glow, 2, 4, 0.8)
	-- corner obelisks
	for _, x in { -121, -79 } do
		for _, z in { 476, 514 } do
			Kit.Box(m, V(x - 1.2, 0, z - 1.2), V(x + 1.2, 12, z + 1.2), light, { Solid = true })
			Kit.Wedge(m, V(2.4, 2, 1.2), CFrame.new(x, 13, z - 0.6), light)
			Kit.Wedge(m, V(2.4, 2, 1.2), CFrame.new(x, 13, z + 0.6) * CFrame.Angles(0, math.pi, 0), light)
			Kit.Ball(m, 1.6, V(x, 14.6, z), mint)
		end
	end
	-- floating candles by the door
	for i = 0, 3 do
		Props.FloatingCandle(m, V(-80, 8 + (i % 2) * 2.5, 486 + i * 6))
	end
	Kit.AddRect(-124, 474, -76, 516)
end

local function crypt(f: Instance, cx: number, cz: number, fx: number, fz: number, flicker: boolean)
	local m = Kit.Model(f, "Crypt")
	local base = CFrame.new(cx, 0, cz) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local stone = Kit.Pick(STONES)
	Kit.Part(m, V(15, 1, 13), base * CFrame.new(0, 0.5, 0), C(140, 130, 170), { Mat = Enum.Material.Slate, Solid = true })
	Kit.Part(m, V(12, 10, 10), base * CFrame.new(0, 6, 0), stone, { Mat = Enum.Material.Slate, Solid = true, Shadow = true })
	-- roof ridge runs front-to-back (local Z) so the triangle faces the front
	gable(m, base * CFrame.new(0, 11, 0) * CFrame.Angles(0, math.pi / 2, 0), 12, 14, 5, C(120, 90, 190))
	local glow = Kit.Pick({ C(120, 255, 170), C(200, 130, 255) })
	local door = Kit.Part(m, V(4.4, 7, 0.4), base * CFrame.new(0, 4.5, -5.1), glow, { Mat = NEON, Transp = 0.15 })
	Kit.Part(m, V(5.6, 8.2, 0.3), base * CFrame.new(0, 4.6, -5.05), C(240, 235, 255))
	Kit.Part(m, V(1, 3.6, 0.6), base * CFrame.new(0, 13.5, -6.3), C(240, 235, 255))
	Kit.Part(m, V(2.6, 1, 0.6), base * CFrame.new(0, 14.2, -6.3), C(240, 235, 255))
	if flicker then
		Kit.Light(door, glow, 16, 1.4, true)
	end
	Props.FloatingCandle(m, (base * CFrame.new(-4, 7.5, -7.5)).Position)
	Kit.AddCircle(cx, cz, 10)
end

local function gravestone(f: Instance, x: number, z: number)
	local rng = Kit.Rng
	local w = rng:NextNumber(3.6, 5.2)
	local h = rng:NextNumber(3.5, 6)
	local yaw = rng:NextNumber(-0.25, 0.25)
	local tilt = rng:NextNumber(-0.08, 0.08)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, tilt * 0.5)
	local col = Kit.Pick(STONES)
	local kind = rng:NextInteger(1, 6)
	if kind == 6 then
		-- cross
		Kit.Part(f, V(1.4, h + 2, 1), base * CFrame.new(0, (h + 2) / 2, 0), col, { Solid = true })
		Kit.Part(f, V(w * 0.8, 1.2, 1), base * CFrame.new(0, h * 0.75 + 0.6, 0), col)
	else
		local slab = Kit.Part(f, V(w, h, 1.2), base * CFrame.new(0, h / 2, 0), col, { Solid = true, Shadow = true })
		Kit.Part(f, V(1.2, w, w), base * CFrame.new(0, h, 0) * CFrame.Angles(0, math.pi / 2, 0), col, { Shape = Enum.PartType.Cylinder })
		if kind <= 2 then
			Kit.Sign(slab, Enum.NormalId.Front, Kit.Pick(EPITAPHS), C(110, 70, 170), { Stroke = C(255, 255, 255), Font = Enum.Font.GothamBlack })
		elseif kind == 3 then
			Kit.Part(f, V(w * 0.5, 0.3, 0.2), base * CFrame.new(0, h * 0.55, -0.65), Kit.Vivid(C(120, 255, 170)))
		end
	end
	-- little dirt mound in front
	Kit.Part(f, V(w + 0.6, 0.4, 3.4), base * CFrame.new(0, 0.1, -2.4), C(120, 95, 130))
	Kit.AddCircle(x, z, 2.5)
end

function Cemetery.Build(map: Instance)
	local f = Kit.Folder(map, "Cemetery")
	local rng = Kit.Rng

	-- main path + branch to the mausoleum
	Kit.Box(f, V(-8, -0.4, 260), V(8, 0.1, 540), C(165, 150, 190), { Mat = Enum.Material.Cobblestone, Solid = true, Name = "Path" })
	Kit.Box(f, V(-80, -0.4, 490), V(-8, 0.08, 500), C(165, 150, 190), { Mat = Enum.Material.Cobblestone, Solid = true })
	local edging = Kit.Vivid(C(120, 255, 170))
	for z = 270, 530, 20 do
		for _, s in { -1, 1 } do
			Kit.Box(f, V(s * 8, 0.1, z), V(s * 8.6, 0.25, z + 10), edging)
		end
	end
	Kit.AddRect(-9, 260, 9, 540, true)
	Kit.AddRect(-80, 489, -8, 501, true)

	mausoleum(f)
	crypt(f, 112, 300, -1, 0, true)
	crypt(f, -110, 345, 1, 0, true)
	crypt(f, 116, 500, -1, 0, false)
	crypt(f, -116, 392, 1, 0, false)

	-- lanterns along the path
	local lit = 0
	for z = 280, 530, 30 do
		for _, s in { -1, 1 } do
			local x = s * 10.5
			if Kit.IsFree(x, z, 1, true) then
				lit += 1
				Props.Lantern(f, V(x, 0, z), if s < 0 then C(140, 255, 170) else C(200, 140, 255), lit % 3 == 1 and lit <= 10)
				Kit.AddCircle(x, z, 1.5)
			end
		end
	end

	-- twisted trees (tall ones near the back so they show over the wall from spawn)
	local treeSpots = {
		{ -125, 280, 26 }, { 126, 285, 24 }, { -100, 300, 30 }, { 45, 292, 22 }, { -30, 380, 26 }, { 110, 410, 30 },
		{ 128, 430, 34 }, { -128, 455, 36 }, { 30, 470, 28 }, { 100, 470, 34 }, { -60, 522, 38 }, { 60, 525, 40 },
		{ -128, 525, 34 }, { 128, 525, 36 },
	}
	for _, t in treeSpots do
		if Kit.IsFree(t[1], t[2], 4) then
			Props.TwistedTree(f, V(t[1], 0, t[2]), t[3])
		end
	end

	-- gravestone field on a jittered grid
	for gx = -128, 128, 11 do
		for gz = 272, 532, 12 do
			local x = gx + rng:NextNumber(-2, 2)
			local z = gz + rng:NextNumber(-2, 2)
			if rng:NextNumber() < 0.45 and Kit.IsFree(x, z, 3.2) then
				gravestone(f, x, z)
			end
		end
	end

	-- iron fences around the mausoleum yard and a few decorative runs
	Props.Fence(f, V(-126, 0, 472), V(-84, 0, 472), "iron")
	Props.Fence(f, V(-126, 0, 518), V(-84, 0, 518), "iron")
	Props.Fence(f, V(-133, 0, 300), V(-133, 0, 330), "iron")
	Props.Fence(f, V(133, 0, 330), V(133, 0, 360), "iron")

	-- neon ectoplasm cracks in the ground (flat, fine inside ghost areas)
	for _ = 1, 16 do
		local p = V(rng:NextNumber(-120, 120), 0.1, rng:NextNumber(275, 530))
		local a = rng:NextNumber(0, math.pi * 2)
		for _ = 1, 3 do
			a += rng:NextNumber(-1, 1)
			local q = p + V(math.cos(a), 0, math.sin(a)) * rng:NextNumber(3, 6)
			Props.Beam(f, p, q, 0.5, 0.12, C(120, 255, 170), { Mat = NEON })
			p = q
		end
	end

	-- glowing mushrooms
	local shrooms = 0
	for _ = 1, 200 do
		if shrooms >= 14 then
			break
		end
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(270, 530)
		if Kit.IsFree(x, z, 2.5) then
			shrooms += 1
			Props.Mushrooms(f, V(x, 0, z))
			Kit.AddCircle(x, z, 2.5)
		end
	end

	-- slow purple fog
	for _, p in { V(-40, 0, 300), V(40, 0, 395), V(-95, 0, 470), V(95, 0, 330), V(30, 0, 520) } do
		Props.Wisp(f, p, C(170, 110, 255), 14, true)
	end
	for _, p in { V(-60, 0, 360), V(80, 0, 500), V(-20, 0, 460) } do
		Props.Wisp(f, p, C(120, 255, 170), 10, false)
	end
end

return Cemetery
