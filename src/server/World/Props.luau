--!strict
-- Reusable chunky props shared by every zone (pumpkins, trees, lamps, fences, cars...).
-- Positions are ground points (Y = 0 is the walkable surface) unless stated otherwise.

local Kit = require(script.Parent.Kit)

local Props = {}

local NEON = Enum.Material.Neon
local C = Color3.fromRGB

Props.Colors = {
	PumpkinBody = { C(255, 140, 30), C(255, 120, 40), C(255, 165, 50) },
	Canopy = { C(170, 90, 230), C(255, 140, 50), C(200, 110, 255), C(255, 110, 90), C(140, 220, 90) },
	Glow = { C(255, 230, 110), C(140, 255, 120), C(200, 130, 255), C(255, 170, 70) },
	Car = { C(255, 90, 140), C(80, 200, 255), C(255, 200, 60), C(140, 255, 140), C(190, 120, 255), C(255, 120, 60) },
	Book = { C(255, 90, 90), C(90, 170, 255), C(255, 210, 70), C(140, 230, 120), C(200, 120, 255), C(255, 140, 200) },
}

-- Segment between two points (square cross-section). Used for twisted trunks, branches, cracks.
function Props.Beam(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, color: Color3, opts: Kit.Opts?): Part
	local d = b - a
	local len = d.Magnitude
	local mid = (a + b) / 2
	local cf: CFrame
	if math.abs(d.Unit.Y) > 0.98 then
		cf = CFrame.new(mid) * CFrame.Angles(math.pi / 2, 0, 0)
	else
		cf = CFrame.lookAt(mid, b)
	end
	return Kit.Part(parent, Vector3.new(w, h, len), cf, color, opts)
end

-- Pumpkin / jack-o-lantern with a glowing face toward (fx, fz). `y` is the bottom of the pumpkin.
function Props.Pumpkin(parent: Instance, pos: Vector3, d: number, fx: number, fz: number, lit: boolean?): Part
	local center = pos + Vector3.new(0, d * 0.45, 0)
	local body = Kit.Ball(parent, d, center, Kit.Pick(Props.Colors.PumpkinBody), { Shadow = false })
	local base = CFrame.new(center) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Part(parent, Vector3.new(d * 0.12, d * 0.3, d * 0.12), base * CFrame.new(0, d * 0.55, 0) * CFrame.Angles(0, 0, 0.25), C(90, 160, 60))
	local face = C(255, 235, 90)
	Kit.Part(parent, Vector3.new(d * 0.18, d * 0.16, d * 0.1), base * CFrame.new(-d * 0.2, d * 0.12, -d * 0.46), face, { Mat = NEON })
	Kit.Part(parent, Vector3.new(d * 0.18, d * 0.16, d * 0.1), base * CFrame.new(d * 0.2, d * 0.12, -d * 0.46), face, { Mat = NEON })
	Kit.Part(parent, Vector3.new(d * 0.42, d * 0.1, d * 0.1), base * CFrame.new(0, -d * 0.12, -d * 0.45), face, { Mat = NEON })
	if lit then
		Kit.Light(body, C(255, 170, 60), 12, 1.5)
	end
	return body
end

-- Lollipop tree: trunk + three canopy balls.
function Props.Tree(parent: Instance, pos: Vector3, height: number, canopy: Color3?)
	local col = canopy or Kit.Pick(Props.Colors.Canopy)
	local rng = Kit.Rng
	Kit.Cyl(parent, height, 1.8, CFrame.new(pos + Vector3.new(0, height / 2, 0)), C(120, 75, 50), { Solid = true, Shadow = true })
	local top = pos + Vector3.new(0, height, 0)
	local s = height * 0.55
	Kit.Ball(parent, s, top, col, { Shadow = true })
	Kit.Ball(parent, s * 0.75, top + Vector3.new(rng:NextNumber(-2, 2), s * 0.35, rng:NextNumber(-2, 2)), col:Lerp(Color3.new(1, 1, 1), 0.15))
	Kit.Ball(parent, s * 0.6, top + Vector3.new(rng:NextNumber(-3, 3), -s * 0.2, rng:NextNumber(-3, 3)), col:Lerp(Color3.new(0, 0, 0), 0.12))
	Kit.AddCircle(pos.X, pos.Z, 3)
end

-- Twisted spooky tree made of crooked segments, bare branches and a few glowing leaf puffs.
function Props.TwistedTree(parent: Instance, pos: Vector3, height: number)
	local rng = Kit.Rng
	local trunk = C(95, 70, 110)
	local pts = { pos }
	local seg = height / 3
	for i = 1, 3 do
		local prev = pts[i]
		local sway = (if i % 2 == 0 then -1 else 1) * rng:NextNumber(1.2, 2.8)
		table.insert(pts, prev + Vector3.new(sway, seg, rng:NextNumber(-1.5, 1.5)))
	end
	for i = 1, 3 do
		local w = 3.2 - i * 0.7
		Props.Beam(parent, pts[i], pts[i + 1], w, w, trunk, { Solid = i == 1, Shadow = true })
	end
	local leaf = { C(170, 90, 255), C(110, 255, 160), C(255, 120, 200) }
	for b = 1, 3 do
		local from = pts[2 + (b % 2)]
		local ang = b * 2.1 + rng:NextNumber(-0.4, 0.4)
		local len = height * rng:NextNumber(0.22, 0.32)
		local tip = from + Vector3.new(math.cos(ang) * len, len * 0.6, math.sin(ang) * len)
		Props.Beam(parent, from, tip, 0.9, 0.9, trunk)
		Kit.Ball(parent, rng:NextNumber(3.5, 5.5), tip, Kit.Pick(leaf), { Mat = if b == 1 then NEON else Enum.Material.SmoothPlastic, Transp = 0.1 })
	end
	Kit.AddCircle(pos.X, pos.Z, 3)
end

-- Street lamp: pole, arm and a glowing globe.
function Props.StreetLamp(parent: Instance, pos: Vector3, color: Color3, withLight: boolean)
	local pole = C(60, 45, 90)
	Kit.Cyl(parent, 13, 0.8, CFrame.new(pos + Vector3.new(0, 6.5, 0)), pole)
	Kit.Cyl(parent, 0.8, 1.8, CFrame.new(pos + Vector3.new(0, 0.4, 0)), pole)
	Kit.Box(parent, pos + Vector3.new(-0.3, 12.6, -0.3), pos + Vector3.new(0.3, 13.2, 0.3), pole)
	local globe = Kit.Ball(parent, 2.4, pos + Vector3.new(0, 14, 0), color, { Mat = NEON })
	Kit.Cyl(parent, 0.5, 2.8, CFrame.new(pos + Vector3.new(0, 15.3, 0)), pole)
	if withLight then
		Kit.Light(globe, color, 22, 1.6)
	end
end

-- Little post lantern (cemetery paths).
function Props.Lantern(parent: Instance, pos: Vector3, color: Color3, withLight: boolean, flicker: boolean?)
	local iron = C(50, 40, 70)
	Kit.Box(parent, pos + Vector3.new(-0.3, 0, -0.3), pos + Vector3.new(0.3, 7, 0.3), iron)
	local glow = Kit.Box(parent, pos + Vector3.new(-0.8, 7, -0.8), pos + Vector3.new(0.8, 9, 0.8), color, { Mat = NEON })
	Kit.Wedge(parent, Vector3.new(2.2, 1, 1.1), CFrame.new(pos + Vector3.new(0, 9.5, -0.55)), iron)
	Kit.Wedge(parent, Vector3.new(2.2, 1, 1.1), CFrame.new(pos + Vector3.new(0, 9.5, 0.55)) * CFrame.Angles(0, math.pi, 0), iron)
	if withLight then
		Kit.Light(glow, color, 18, 1.4, flicker)
	end
end

-- Mushroom cluster with glowing caps.
function Props.Mushrooms(parent: Instance, pos: Vector3)
	local rng = Kit.Rng
	local caps = { C(120, 255, 200), C(200, 120, 255), C(255, 150, 220), C(120, 220, 255) }
	for _ = 1, rng:NextInteger(2, 3) do
		local p = pos + Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
		local h = rng:NextNumber(0.8, 2)
		Kit.Cyl(parent, h, 0.5, CFrame.new(p + Vector3.new(0, h / 2, 0)), C(245, 240, 225))
		Kit.Ball(parent, rng:NextNumber(1.3, 2), p + Vector3.new(0, h, 0), Kit.Pick(caps), { Mat = NEON })
	end
end

-- Fence run from a to b (ground points). style: "picket" (crooked white) or "iron" (dark with neon tips).
function Props.Fence(parent: Instance, a: Vector3, b: Vector3, style: string)
	local rng = Kit.Rng
	local d = b - a
	local len = d.Magnitude
	if len < 1 then
		return
	end
	local dir = d.Unit
	local yaw = math.atan2(-dir.X, -dir.Z) -- local -Z along the run
	local iron = style == "iron"
	local col = if iron then C(55, 45, 80) else C(250, 240, 255)
	local h = if iron then 6 else 3.6
	local step = if iron then 2 else 1.6
	local rails = { h * 0.3, h * 0.75 }
	for _, ry in rails do
		local mid = a + d / 2 + Vector3.new(0, ry, 0)
		Kit.Part(parent, Vector3.new(0.3, 0.3, len), CFrame.new(mid) * CFrame.Angles(0, yaw, 0), col)
	end
	local n = math.floor(len / step)
	for i = 0, n do
		local p = a + dir * (i * step) + Vector3.new(0, h / 2, 0)
		local tilt = if iron then 0 else rng:NextNumber(-0.14, 0.14)
		local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt * 0.3, 0, tilt)
		Kit.Part(parent, Vector3.new(if iron then 0.35 else 0.25, h, if iron then 0.35 else 0.9), cf, col)
		if iron and i % 3 == 0 then
			Kit.Ball(parent, 0.7, p + Vector3.new(0, h / 2 + 0.3, 0), C(120, 255, 170), { Mat = NEON })
		end
	end
end

-- Low translucent neon wisp on the ground; optional slow particle fog.
function Props.Wisp(parent: Instance, pos: Vector3, color: Color3, d: number, emit: boolean)
	local p = Kit.Disc(parent, pos.X, pos.Z, 0.3, d, 0.12, color, { Mat = NEON, Transp = 0.8 })
	if emit then
		local src = Kit.Part(parent, Vector3.new(d * 0.6, 0.2, d * 0.6), CFrame.new(pos + Vector3.new(0, 1, 0)), color, { Transp = 1, Name = "FogSource" })
		Kit.Emitter(src, color, 1.5, 7, 0.4)
	end
	return p
end

-- Chunky cartoon car. `along` = direction the car faces (unit X/Z vector).
function Props.Car(parent: Instance, pos: Vector3, fx: number, fz: number, color: Color3)
	local m = Kit.Model(parent, "Car")
	local base = CFrame.new(pos) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	-- body (length along local Z)
	Kit.Part(m, Vector3.new(7.5, 3, 14), base * CFrame.new(0, 2.6, 0), color, { Solid = true, Shadow = true })
	Kit.Part(m, Vector3.new(6.6, 2.8, 7), base * CFrame.new(0, 5.4, 0.8), color:Lerp(Color3.new(1, 1, 1), 0.25), { Solid = true })
	local glass = C(170, 230, 255)
	Kit.Part(m, Vector3.new(5.8, 2, 0.3), base * CFrame.new(0, 5.5, -2.75), glass, { Mat = NEON, Transp = 0.35 })
	Kit.Part(m, Vector3.new(6.7, 1.8, 5.4), base * CFrame.new(0, 5.5, 0.8), glass, { Mat = NEON, Transp = 0.55 })
	local axle = if math.abs(fx) > math.abs(fz) then "Z" else "X"
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.CylFlat(m, 1.2, 3.4, (base * CFrame.new(sx * 3.5, 1.7, sz * 4.4)).Position, axle, C(40, 35, 55))
		end
		Kit.Part(m, Vector3.new(1.4, 1, 0.3), base * CFrame.new(sx * 2.6, 3, -7.05), C(255, 250, 200), { Mat = NEON })
		Kit.Part(m, Vector3.new(1.2, 0.8, 0.3), base * CFrame.new(sx * 2.7, 3, 7.05), C(255, 60, 90), { Mat = NEON })
	end
	Kit.AddCircle(pos.X, pos.Z, 8)
end

-- Cute skull (big white ball with black eyes) facing (fx, fz). pos = centre.
function Props.Skull(parent: Instance, pos: Vector3, d: number, fx: number, fz: number)
	local base = CFrame.new(pos) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	Kit.Ball(parent, d, pos, C(250, 245, 235))
	Kit.Part(parent, Vector3.new(d * 0.55, d * 0.35, d * 0.5), base * CFrame.new(0, -d * 0.4, -d * 0.1), C(250, 245, 235))
	for _, sx in { -1, 1 } do
		Kit.Ball(parent, d * 0.28, (base * CFrame.new(sx * d * 0.18, d * 0.05, -d * 0.38)).Position, C(120, 255, 170), { Mat = NEON })
	end
end

-- Single-part floating book (tagged). pos = centre in the air.
function Props.FloatingBook(parent: Instance, pos: Vector3)
	local rng = Kit.Rng
	local cf = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4))
	local b = Kit.Part(parent, Vector3.new(1.8, 0.5, 2.4), cf, Kit.Pick(Props.Colors.Book), { Name = "FloatingBook" })
	Kit.Float(b, rng:NextNumber(0.6, 1.2))
end

-- Single-part floating candle (tagged).
function Props.FloatingCandle(parent: Instance, pos: Vector3)
	local c = Kit.Cyl(parent, 1.6, 0.6, CFrame.new(pos), C(255, 230, 160), { Mat = NEON, Name = "FloatingCandle" })
	Kit.Float(c, Kit.Rng:NextNumber(0.5, 1))
end

-- Single-part floating pumpkin (tagged).
function Props.FloatingPumpkin(parent: Instance, pos: Vector3)
	local p = Kit.Ball(parent, 2.4, pos, C(255, 150, 40), { Name = "FloatingPumpkin" })
	Kit.Float(p, Kit.Rng:NextNumber(0.6, 1.1))
end

-- A sign board facing (fx, fz) with text on its Front face.
function Props.SignBoard(parent: Instance, center: Vector3, w: number, h: number, fx: number, fz: number, text: string, bg: Color3, fg: Color3, frame: Color3?): Part
	local cf = CFrame.new(center) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local board = Kit.Part(parent, Vector3.new(w, h, 0.6), cf, bg, { Name = "SignBoard" })
	if frame then
		Kit.Part(parent, Vector3.new(w + 1, h + 1, 0.4), cf * CFrame.new(0, 0, 0.35), frame, { Mat = NEON })
	end
	Kit.Sign(board, Enum.NormalId.Front, text, fg)
	return board
end

-- Graffiti: an invisible thin panel with neon text, flat against a wall, facing (fx, fz).
function Props.Graffiti(parent: Instance, center: Vector3, w: number, h: number, fx: number, fz: number, text: string, color: Color3, rot: number?)
	local cf = CFrame.new(center) * CFrame.Angles(0, Kit.FaceYaw(fx, fz), 0)
	local panel = Kit.Part(parent, Vector3.new(w, h, 0.1), cf, color, { Transp = 1, Name = "Graffiti" })
	Kit.Sign(panel, Enum.NormalId.Front, text, color, { Font = Enum.Font.FredokaOne, Stroke = C(30, 10, 50), Rotation = rot })
end

return Props
