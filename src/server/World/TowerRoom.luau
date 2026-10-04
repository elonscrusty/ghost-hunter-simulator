--!strict
-- BOSS TOWER room geometry, built at runtime by TowerService for one run in its own far-away
-- slot (outside the main map). Anchored, solid 4-stud floor (top at origin.Y), stone walls all
-- round (no ceiling), pillars with ghost lanterns, a painted rune circle where the boss floats,
-- the entry portal on the south wall and a ROOM n sign on the north wall.
--
-- Rooms are not part of the map build, so they don't use the map's Kit light/emitter budgets:
-- the few lights here are created directly (4 per room) and the room is destroyed with the run.
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)

local TowerRoom = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local HALF = 48 -- room spans origin +-HALF in X and Z
local WALL_H = 26
local ECTO = C(110, 255, 160)
local STONE = C(78, 58, 118)
local STONE_DARK = C(48, 34, 74)
local STONE_LIGHT = C(120, 94, 170)

-- Accent colour per boss in the cycle (room 1 Warden, 2 Jester, 3 Baron, 4 Titan, ...).
local ACCENTS = { C(110, 255, 160), C(255, 200, 80), C(120, 200, 255), C(200, 140, 255) }

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
end

-- Where the party appears: the south end of the room, facing the boss (+Z).
function TowerRoom.Entry(origin: Vector3): Vector3
	return origin + V(0, 0, -HALF + 12)
end

-- Centre of the boss's wander circle.
function TowerRoom.BossCenter(origin: Vector3): Vector3
	return origin + V(0, 0, 8)
end

TowerRoom.BossRadius = 10

local function ringPaint(parent: Instance, cx: number, cz: number, y: number, r: number, n: number, w: number, color: Color3, name: string?)
	local segLen = 2 * math.pi * r / n + 0.4
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local p = V(cx + math.cos(a) * r, y + 0.05, cz + math.sin(a) * r)
		local tangent = V(-math.sin(a), 0, math.cos(a))
		Kit.Part(parent, V(w, 0.12, segLen), CFrame.lookAt(p, p + tangent), color, { Name = name })
	end
end

local function lanternPillar(m: Model, x: number, z: number, y: number, lit: boolean)
	Kit.Box(m, V(x - 2, y, z - 2), V(x + 2, y + 20, z + 2), STONE_LIGHT, { Mat = Enum.Material.Slate, Solid = true })
	Kit.Box(m, V(x - 2.5, y, z - 2.5), V(x + 2.5, y + 1.5, z + 2.5), STONE_DARK, { Mat = Enum.Material.Slate, Solid = true })
	Kit.Box(m, V(x - 2.5, y + 20, z - 2.5), V(x + 2.5, y + 21, z + 2.5), STONE_DARK, { Mat = Enum.Material.Slate })
	local glow = Kit.Ball(m, 2, V(x, y + 22.4, z), ECTO, { Mat = NEON, Name = "Accent" })
	if lit then
		light(glow, ECTO, 34, 1.4)
	end
end

-- Builds the room for one slot. The model holds a "RoomSign" label and "Accent" parts that
-- SetRoom updates.
function TowerRoom.Build(parent: Instance, origin: Vector3, slot: number): Model
	local m = Instance.new("Model")
	m.Name = "TowerRoom_" .. slot
	local ox, oy, oz = origin.X, origin.Y, origin.Z
	local solid: Kit.Opts = { Mat = Enum.Material.Slate, Solid = true }

	-- floor (4 thick) with a darker inlay and painted runes under the boss
	local floor = Kit.Box(m, V(ox - HALF - 3, oy - 4, oz - HALF - 3), V(ox + HALF + 3, oy, oz + HALF + 3), STONE_DARK, { Mat = Enum.Material.Slate, Solid = true, Name = "Floor" })
	Kit.Box(m, V(ox - HALF + 4, oy, oz - HALF + 4), V(ox + HALF - 4, oy + 0.06, oz + HALF - 4), STONE, { Mat = Enum.Material.Slate })
	local bc = TowerRoom.BossCenter(origin)
	ringPaint(m, bc.X, bc.Z, oy, 18, 28, 1.2, Kit.Vivid(ECTO), "Accent")
	ringPaint(m, bc.X, bc.Z, oy, 11, 20, 0.7, Kit.Vivid(C(255, 110, 220)))
	Kit.Disc(m, bc.X, bc.Z, oy + 0.2, 6, 0.12, Kit.Vivid(C(190, 120, 255)))
	-- carpet from the entry to the circle
	Kit.Box(m, V(ox - 3, oy, oz - HALF + 4), V(ox + 3, oy + 0.1, bc.Z - 18), C(120, 30, 60), { Mat = Enum.Material.Fabric })

	-- walls (no ceiling) with an ectoplasm band and battlements
	local w = 3
	Kit.Box(m, V(ox - HALF - w, oy, oz - HALF - w), V(ox + HALF + w, oy + WALL_H, oz - HALF), STONE, solid)
	Kit.Box(m, V(ox - HALF - w, oy, oz + HALF), V(ox + HALF + w, oy + WALL_H, oz + HALF + w), STONE, solid)
	Kit.Box(m, V(ox - HALF - w, oy, oz - HALF), V(ox - HALF, oy + WALL_H, oz + HALF), STONE, solid)
	Kit.Box(m, V(ox + HALF, oy, oz - HALF), V(ox + HALF + w, oy + WALL_H, oz + HALF), STONE, solid)
	local paint = Kit.Vivid(ECTO)
	Kit.Box(m, V(ox - HALF, oy + 18, oz - HALF), V(ox + HALF, oy + 19, oz - HALF + 0.3), paint, { Name = "Accent" })
	Kit.Box(m, V(ox - HALF, oy + 18, oz + HALF - 0.3), V(ox + HALF, oy + 19, oz + HALF), paint, { Name = "Accent" })
	Kit.Box(m, V(ox - HALF, oy + 18, oz - HALF), V(ox - HALF + 0.3, oy + 19, oz + HALF), paint, { Name = "Accent" })
	Kit.Box(m, V(ox + HALF - 0.3, oy + 18, oz - HALF), V(ox + HALF, oy + 19, oz + HALF), paint, { Name = "Accent" })
	for i = -HALF, HALF - 2, 6 do
		Kit.Box(m, V(ox + i, oy + WALL_H, oz - HALF - w), V(ox + i + 3, oy + WALL_H + 2.5, oz - HALF), STONE_LIGHT, { Mat = Enum.Material.Slate })
		Kit.Box(m, V(ox + i, oy + WALL_H, oz + HALF), V(ox + i + 3, oy + WALL_H + 2.5, oz + HALF + w), STONE_LIGHT, { Mat = Enum.Material.Slate })
		Kit.Box(m, V(ox - HALF - w, oy + WALL_H, oz + i), V(ox - HALF, oy + WALL_H + 2.5, oz + i + 3), STONE_LIGHT, { Mat = Enum.Material.Slate })
		Kit.Box(m, V(ox + HALF, oy + WALL_H, oz + i), V(ox + HALF + w, oy + WALL_H + 2.5, oz + i + 3), STONE_LIGHT, { Mat = Enum.Material.Slate })
	end

	-- pillars with ghost lanterns (4 of them lit)
	for _, sx in { -1, 1 } do
		for k, z in { -HALF + 8, -6, HALF - 8 } do
			lanternPillar(m, ox + sx * (HALF - 6), oz + z, oy, k ~= 2)
		end
	end

	-- entry portal on the south wall (behind the party)
	Kit.Box(m, V(ox - 7, oy, oz - HALF), V(ox + 7, oy + 16, oz - HALF + 0.6), C(25, 15, 40))
	Kit.Box(m, V(ox - 5.5, oy + 0.3, oz - HALF + 0.6), V(ox + 5.5, oy + 14, oz - HALF + 0.8), ECTO, { Mat = NEON, Transp = 0.5 })
	Kit.Box(m, V(ox - 9, oy, oz - HALF + 0.6), V(ox - 7, oy + 18, oz - HALF + 2.2), STONE_LIGHT, solid)
	Kit.Box(m, V(ox + 7, oy, oz - HALF + 0.6), V(ox + 9, oy + 18, oz - HALF + 2.2), STONE_LIGHT, solid)
	Kit.Box(m, V(ox - 9, oy + 16, oz - HALF + 0.6), V(ox + 9, oy + 18, oz - HALF + 2.2), STONE_LIGHT, solid)

	-- ROOM n sign on the north wall, facing the party
	local signCF = CFrame.new(ox, oy + 13, oz + HALF - 0.5) * CFrame.Angles(0, Kit.FaceYaw(0, -1), 0)
	local sign = Kit.Part(m, V(26, 7, 0.6), signCF, C(45, 25, 80))
	Kit.Part(m, V(27, 8, 0.3), signCF * CFrame.new(0, 0, 0.45), paint, { Name = "Accent" })
	local label = Kit.Sign(sign, Enum.NormalId.Front, "ROOM 1", C(150, 255, 170))
	label.Name = "RoomSign"
	-- hanging banners either side of the sign
	for _, s in { -1, 1 } do
		Kit.Box(m, V(ox + s * 20 - 3, oy + 6, oz + HALF - 0.6), V(ox + s * 20 + 3, oy + 20, oz + HALF - 0.3), C(110, 30, 70), { Mat = Enum.Material.Fabric })
		Kit.Ball(m, 2.4, V(ox + s * 20, oy + 15, oz + HALF - 0.8), paint, { Name = "Accent" })
	end

	m.PrimaryPart = floor
	m.Parent = parent
	return m
end

-- Updates the room number sign and the accent colour for room n.
function TowerRoom.SetRoom(m: Model, n: number)
	local accent = ACCENTS[(n - 1) % #ACCENTS + 1]
	for _, d in m:GetDescendants() do
		if d.Name == "RoomSign" and d:IsA("TextLabel") then
			d.Text = "ROOM " .. n
			d.TextColor3 = accent
		elseif d.Name == "Accent" and d:IsA("BasePart") then
			d.Color = if d.Material == NEON then accent else Kit.Vivid(accent)
		end
	end
end

-- Treasure chest in front of the boss circle (facing the entry). It is only the visual of a
-- payout the server already credited, so it has no prompt and nothing to claim.
function TowerRoom.Chest(m: Model, origin: Vector3): Model
	local old = m:FindFirstChild("Chest")
	if old then
		old:Destroy()
	end
	local pos = TowerRoom.BossCenter(origin) + V(0, 0, -14)
	local chest = Instance.new("Model")
	chest.Name = "Chest"
	local wood, gold = C(120, 70, 40), C(255, 200, 70)
	local base = Kit.Box(chest, pos + V(-2.5, 0, -1.8), pos + V(2.5, 2.8, 1.8), wood, { Mat = Enum.Material.WoodPlanks, Solid = true, Name = "Base" })
	Kit.Box(chest, pos + V(-2.6, 0.2, -1.9), pos + V(2.6, 0.6, 1.9), gold, { Mat = Enum.Material.Metal })
	Kit.Box(chest, pos + V(-2.6, 2.3, -1.9), pos + V(2.6, 2.7, 1.9), gold, { Mat = Enum.Material.Metal })
	local glow = Kit.Box(chest, pos + V(-2.1, 2.2, -1.4), pos + V(2.1, 2.85, 1.4), ECTO, { Mat = NEON, Name = "Glow" })
	glow.Transparency = 1
	-- lid hinged along its back (+Z) top edge
	Kit.Part(chest, V(5, 1.4, 3.6), CFrame.new(pos + V(0, 3.5, 0)), wood, { Mat = Enum.Material.WoodPlanks, Name = "Lid" })
	Kit.Part(chest, V(1, 1, 0.3), CFrame.new(pos + V(0, 2, -1.95)), gold, { Mat = Enum.Material.Metal })
	chest.PrimaryPart = base
	chest.Parent = m
	return chest
end

-- Opens the chest lid (server tween; replicates to the party) and lights the inside.
function TowerRoom.OpenChest(chest: Model)
	local lid = chest:FindFirstChild("Lid") :: BasePart?
	local glow = chest:FindFirstChild("Glow") :: BasePart?
	if not lid then
		return
	end
	local hinge = lid.CFrame * CFrame.new(0, -0.7, 1.8)
	local open = hinge * CFrame.Angles(math.rad(105), 0, 0) * CFrame.new(0, 0.7, -1.8)
	TweenService:Create(lid, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = open }):Play()
	if glow then
		glow.Transparency = 0.15
		light(glow, ECTO, 16, 2)
	end
end

return TowerRoom
