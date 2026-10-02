--!strict
-- Giant Ghost event arena (workspace.Map.EventArena): a flat rune circle that stays clear
-- (nothing above 0.3 studs inside the radius, nothing in the air up to Y=40), with pumpkin
-- spectators, bleachers on the north/south edges and an entrance sign over the cross street.
-- The rune circle is painted in solid candy colours; only the lamps, the small rim lights
-- and the rim jack-o'-lanterns glow.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Arena = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local function ring(parent: Instance, cx: number, cz: number, r: number, n: number, w: number, color: Color3, topY: number)
	local segLen = 2 * math.pi * r / n + 0.4
	local paint = Kit.Vivid(color)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = V(cx + math.cos(a) * r, topY - 0.1, cz + math.sin(a) * r)
		local tangent = V(-math.sin(a), 0, math.cos(a))
		Kit.Part(parent, V(w, 0.2, segLen), CFrame.lookAt(p, p + tangent), paint)
	end
end

local function bleachers(parent: Instance, cx: number, z0: number, outward: number)
	-- 3 steps rising away from the arena; outward = +1 (north) or -1 (south)
	local cols = { C(160, 90, 255), C(255, 150, 60), C(110, 230, 160) }
	for i = 0, 2 do
		local zA = z0 + outward * (i * 3.5)
		local zB = z0 + outward * 11
		Kit.Box(parent, V(cx - 14, 0, zA), V(cx + 14, 1.6 * (i + 1), zB), cols[i + 1], { Mat = Enum.Material.WoodPlanks, Solid = true })
	end
	-- pumpkin audience on the steps
	for i = 0, 2 do
		for k = -2, 2 do
			if (i + k) % 2 == 0 then
				local z = z0 + outward * (i * 3.5 + 1.75)
				Props.Pumpkin(parent, V(cx + k * 5, 1.6 * (i + 1), z), 2.6, 0, -outward)
			end
		end
	end
	Kit.AddRect(cx - 15, z0, cx + 15, z0 + outward * 12)
end

function Arena.Build(map: Instance)
	local ea = Config.Layout.EventArena
	local cx, cz, r = ea.Center.X, ea.Center.Z, ea.Radius
	local m = Kit.Model(map, "EventArena")

	-- Field (flat, top 0.12)
	local field = Kit.Disc(m, cx, cz, 0.12, r * 2 + 4, 0.4, C(90, 60, 140), { Mat = Enum.Material.Slate, Solid = true, Name = "Field" })
	Kit.Disc(m, cx, cz, 0.16, r * 2 - 6, 0.1, C(120, 80, 190), { Solid = true })
	ring(m, cx, cz, r, 36, 1.4, C(150, 255, 120), 0.32)
	ring(m, cx, cz, r * 0.62, 24, 0.9, C(255, 110, 220), 0.3)
	Kit.Disc(m, cx, cz, 0.3, 10, 0.12, Kit.Vivid(C(150, 255, 160)))
	-- rune spokes and a star
	local spoke, dot = Kit.Vivid(C(190, 120, 255)), Kit.Vivid(C(255, 230, 90))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local p1 = V(cx + math.cos(a) * r * 0.62, 0.25, cz + math.sin(a) * r * 0.62)
		local a2 = a + math.pi * 2 / 6 * 2
		local p2 = V(cx + math.cos(a2) * r * 0.62, 0.25, cz + math.sin(a2) * r * 0.62)
		Props.Beam(m, p1, p2, 0.6, 0.12, spoke)
		local outer = V(cx + math.cos(a) * (r - 3), 0.25, cz + math.sin(a) * (r - 3))
		Kit.Disc(m, outer.X, outer.Z, 0.3, 3, 0.12, dot)
	end

	-- Edge decorations (outside the radius)
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * math.pi * 2
		local px, pz = cx + math.cos(a) * (r + 3.5), cz + math.sin(a) * (r + 3.5)
		if math.abs(px) < 134 and not (px < cx and pz > cz - 10 and pz < cz + 26) then
			if i % 2 == 0 then
				Props.Pumpkin(m, V(px, 0, pz), 3.4, cx - px, cz - pz, true)
			else
				Kit.Box(m, V(px - 0.6, 0, pz - 0.6), V(px + 0.6, 4, pz + 0.6), C(60, 40, 90), { Mat = Enum.Material.Metal })
				Kit.Ball(m, 2, V(px, 5, pz), C(150, 255, 140), { Mat = NEON })
			end
		end
	end
	bleachers(m, cx, cz + r + 4, 1)
	bleachers(m, cx, cz - r - 4, -1)

	-- Entrance arch over the cross street on the west side, sign facing -X (toward the road)
	local ax = cx - r - 5
	for _, sz in { -1, 1 } do
		local pz = cz + 7 + sz * 13
		Kit.Box(m, V(ax - 1.2, 0, pz - 1.2), V(ax + 1.2, 22, pz + 1.2), C(110, 70, 200), { Mat = Enum.Material.Slate, Solid = true })
		Kit.Ball(m, 3, V(ax, 23, pz), Kit.Vivid(C(255, 150, 60)))
	end
	local signCF = CFrame.new(ax, 19, cz + 7) * CFrame.Angles(0, Kit.FaceYaw(-1, 0), 0)
	local sign = Kit.Part(m, V(24, 5, 0.8), signCF, C(45, 25, 80))
	Kit.Part(m, V(25, 6, 0.4), signCF * CFrame.new(0, 0, 0.5), Kit.Vivid(C(255, 110, 220)))
	Kit.Sign(sign, Enum.NormalId.Front, "👻 GIANT GHOST EVENT 👻", C(255, 230, 90))
	-- second sign facing into the arena from the east wall side
	local sign2CF = CFrame.new(cx + r + 4, 9, cz) * CFrame.Angles(0, Kit.FaceYaw(-1, 0), 0)
	local s2 = Kit.Part(m, V(16, 5, 0.6), sign2CF, C(45, 25, 80))
	Kit.Part(m, V(17, 6, 0.3), sign2CF * CFrame.new(0, 0, 0.4), Kit.Vivid(C(150, 255, 120)))
	Kit.Box(m, V(cx + r + 4.6, 0, cz - 0.5), V(cx + r + 5.6, 7, cz + 0.5), C(60, 40, 90))
	Kit.Sign(s2, Enum.NormalId.Front, "GIANT GHOST EVENT", C(150, 255, 140))

	-- lights on two tall poles at the edge
	for _, sz in { -1, 1 } do
		local p = V(cx + r * 0.75, 0, cz + sz * (r + 9))
		Kit.Cyl(m, 26, 1, CFrame.new(p + V(0, 13, 0)), C(60, 40, 90), { Mat = Enum.Material.Metal })
		local lamp = Kit.Ball(m, 3, p + V(0, 27, 0), C(255, 160, 230), { Mat = NEON })
		Kit.Light(lamp, C(255, 170, 230), 40, 1.4)
	end
	-- low, faint haze (a big bright cloud here washed out the rune circle)
	local haze = Kit.Emitter(field, C(200, 140, 255), 1.5, 6, 0.3)
	if haze then
		haze.LightEmission = 0.25
	end

	Kit.AddCircle(cx, cz, r + 6)
	m.PrimaryPart = field
end

return Arena
