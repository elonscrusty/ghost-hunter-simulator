--!strict
-- PET HATCHERY (workspace.Map.Hatchery): a small open pavilion in the left pocket behind the
-- spawn plaza (beside Ghost Hunter HQ), turned to face the plaza. Built in a local frame `base`
-- (origin CENTER = Config.Layout.Hatchery, local -Z = front, toward the spawn): footprint 21 x 13
-- studs, which lands at about X -39..-14, Z -106..-81 in the lobby (Builder reserves the pocket;
-- PetService's BuyEgg near check uses the same point).
--   Three pedestals (Config.EggOrder, left to right as seen from the plaza), each with a big egg,
--   a price/unlock sign and an invisible PromptAnchor (attribute Egg = egg id) holding a "View"
--   ProximityPrompt. The client (Controllers/Hatchery) opens the egg panel from the prompt;
--   buying and rolling happen only on the server (PetService "BuyEgg").
-- Built last in Builder and without Kit.Rng, so it never shifts other zones' random props.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Format = require(game:GetService("ReplicatedStorage").GH.Logic.Format)
local Icons = require(game:GetService("ReplicatedStorage").GH.Icons)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Hatchery = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local CENTER: Vector3 = Config.Layout.Hatchery -- PetService BuyEgg near check uses this spot
local HW, HD = 10.5, 6.5 -- floor half width (local X) / half depth (local Z)
local PED_Z = 1.5 -- pedestal row (local Z, behind the middle)
local PED_GAP = 6
local PX, PZ = 9.5, 5.3 -- pillar offsets
local ROOF_Y = 12
local STONE = C(96, 84, 120)
local STONE_DARK = C(64, 54, 86)
local MOSS = C(70, 92, 70)
local SHARD = C(200, 160, 255)

-- Spirit Shard crystal (a diamond: a block turned 45 degrees), optionally floating.
local function crystal(parent: Instance, pos: Vector3, s: number, color: Color3, float: boolean)
	local p = Kit.Part(parent, V(s, s * 1.6, s), CFrame.new(pos) * CFrame.Angles(0, math.rad(45), math.rad(12)), color, { Mat = Enum.Material.Glass, Transp = 0.15, Refl = 0.2 })
	if float then
		Kit.Float(p, 0.6)
	end
	return p
end

-- `at` is the pedestal top centre; dz > 0 moves toward the front (local -Z).
local function off(at: CFrame, dx: number, dy: number, dz: number): CFrame
	return at * CFrame.new(dx, dy, -dz)
end

-- The egg: two stacked balls (wide bottom, narrower top) read as an egg shape.
local function eggShape(parent: Instance, at: CFrame, color: Color3, opts: Kit.Opts?): Part
	local low = Kit.Ball(parent, 4.2, off(at, 0, 2.1, 0).Position, color, opts)
	Kit.Ball(parent, 3.4, off(at, 0, 3.6, 0).Position, color, opts)
	return low
end

local function hauntedEgg(m: Instance, at: CFrame, egg: Config.EggDef)
	eggShape(m, at, Kit.Vivid(egg.Color))
	-- green ecto cracks across the front (thin neon strips: the egg's one glowing accent)
	local cracks = { { -0.9, 2.4, 25 }, { 0.2, 2.9, -35 }, { 0.9, 2.2, 40 }, { -0.2, 3.9, 60 } }
	for _, c in cracks do
		Kit.Part(m, V(0.18, 1.2, 0.2), off(at, c[1], c[2], 2.05) * CFrame.Angles(0, 0, math.rad(c[3])), egg.Accent, { Mat = NEON })
	end
	-- dark speckles
	for _, sp in { { -1.3, 1.6 }, { 1.2, 3.4 }, { 0.6, 1.2 } } do
		Kit.Ball(m, 0.6, off(at, sp[1], sp[2], 1.75).Position, C(70, 30, 120))
	end
end

local function phantomEgg(m: Instance, at: CFrame, egg: Config.EggDef)
	eggShape(m, at, egg.Color, { Mat = Enum.Material.Glass, Transp = 0.3, Refl = 0.1 })
	-- inner soft core
	Kit.Ball(m, 2.4, off(at, 0, 2.5, 0).Position, egg.Accent, { Transp = 0.4 })
	-- ghost face on the front
	local dark = C(30, 30, 60)
	Kit.Ball(m, 0.8, off(at, -0.7, 3.4, 1.55).Position, dark)
	Kit.Ball(m, 0.8, off(at, 0.7, 3.4, 1.55).Position, dark)
	Kit.Part(m, V(0.9, 0.6, 0.3), off(at, 0, 2.4, 2.0), dark)
end

local function moonlightEgg(m: Instance, at: CFrame, egg: Config.EggDef)
	eggShape(m, at, egg.Color, { Refl = 0.15 })
	-- crescent moon: a pale disc partly covered by an egg-coloured disc
	local spin = CFrame.Angles(0, math.pi / 2, 0)
	Kit.Part(m, V(0.2, 1.6, 1.6), off(at, -0.2, 3.0, 2.0) * spin, egg.Accent, { Shape = Enum.PartType.Cylinder })
	Kit.Part(m, V(0.2, 1.4, 1.4), off(at, 0.2, 3.15, 2.08) * spin, egg.Color, { Shape = Enum.PartType.Cylinder })
	-- stars
	for _, s in { { -1.2, 1.7 }, { 1.1, 2.0 }, { 0.8, 4.1 }, { -0.9, 4.0 }, { 0.1, 1.2 } } do
		Kit.Ball(m, 0.35, off(at, s[1], s[2], 1.85).Position, C(255, 245, 200), { Mat = NEON })
	end
end

local EGG_LOOK: { [string]: (Instance, CFrame, Config.EggDef) -> () } = {
	HauntedEgg = hauntedEgg,
	PhantomEgg = phantomEgg,
	MoonlightEgg = moonlightEgg,
}

local function pedestal(parent: Instance, base: CFrame, egg: Config.EggDef, x: number)
	local m = Kit.Model(parent, "Pedestal_" .. egg.Id)
	local pcf = base * CFrame.new(x, 0, PED_Z)
	local function at(dx: number, dy: number, dz: number): CFrame
		return off(pcf, dx, dy, dz)
	end
	-- stepped stone pedestal
	local basePart = Kit.Cyl(m, 0.6, 5.6, at(0, 0.5, 0), STONE_DARK, { Mat = Enum.Material.Slate, Solid = true, Name = "Base" })
	Kit.Cyl(m, 2.2, 4, at(0, 1.9, 0), STONE, { Mat = Enum.Material.Slate, Solid = true })
	Kit.Cyl(m, 0.4, 4.8, at(0, 3.1, 0), Kit.Vivid(egg.Accent))
	local top = at(0, 3.3, 0)
	local look = EGG_LOOK[egg.Id]
	if look then
		look(m, top, egg)
	else
		eggShape(m, top, egg.Color)
	end
	-- soft glow under the egg (low brightness: no bloom spike)
	local glow = Kit.Part(m, V(1, 1, 1), at(0, 5, 2), egg.Accent, { Transp = 1, Name = "Glow" })
	Kit.Light(glow, egg.Accent, 12, 0.7)
	-- floating Spirit Shard crystals beside the egg
	crystal(m, at(-2.4, 7.4, 0).Position, 0.7, SHARD, true)
	crystal(m, at(2.4, 8, 0).Position, 0.6, SHARD, true)

	-- price / unlock sign in front of the pedestal, facing the plaza
	local signCF = at(0, 2.6, 4.2) * CFrame.Angles(math.rad(-12), 0, 0)
	local board = Kit.Part(m, V(5, 3, 0.4), signCF, C(35, 22, 60), { Name = "EggSign" })
	Kit.Part(m, V(5.5, 3.5, 0.3), signCF * CFrame.new(0, 0, 0.3), Kit.Vivid(egg.Accent))
	Kit.Part(m, V(0.5, 0.8, 0.5), at(0, 0.4, 3.9), STONE_DARK)
	local g = Kit.Gui(board, Enum.NormalId.Front)
	Kit.Label(g, string.upper(egg.Name), C(255, 255, 255), { Size = UDim2.fromScale(0.94, 0.34), Pos = UDim2.fromScale(0.03, 0.04) })
	-- price: the Spirit Shards icon image left of the number (emoji only without an image id);
	-- the icon is square at the row height (0.3 of the 3-stud board = 0.18 of its 5-stud width)
	local price = Format.Commas(egg.Price)
	local shards = Icons.Get("shards")
	if shards then
		local img = Instance.new("ImageLabel")
		img.Name = "ShardIcon"
		img.BackgroundTransparency = 1
		img.Image = shards
		img.ScaleType = Enum.ScaleType.Fit
		img.Position = UDim2.fromScale(0.14, 0.38)
		img.Size = UDim2.fromScale(0.18, 0.3)
		img.Parent = g
		local label = Kit.Label(g, price, SHARD, { Name = "Price", Size = UDim2.fromScale(0.52, 0.3), Pos = UDim2.fromScale(0.34, 0.38) })
		label.TextXAlignment = Enum.TextXAlignment.Left
	else
		Kit.Label(g, "🔮 " .. price, SHARD, { Name = "Price", Size = UDim2.fromScale(0.8, 0.3), Pos = UDim2.fromScale(0.1, 0.38) })
	end
	local unlock = if egg.Unlock > 0 then "Unlock: Tower checkpoint " .. egg.Unlock else "Open to everyone"
	Kit.Label(g, unlock, C(150, 255, 170), { Size = UDim2.fromScale(0.94, 0.22), Pos = UDim2.fromScale(0.03, 0.72) })

	-- invisible prompt anchor in front of the sign
	local anchor = Kit.Part(m, V(1, 1, 1), at(0, 3, 5.5), egg.Color, { Transp = 1, Name = "PromptAnchor" })
	anchor:SetAttribute("Egg", egg.Id)
	-- pcall: the headless world simulator (tools/worldsim) has no ProximityPrompt class
	pcall(function()
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggPrompt"
		prompt.ActionText = "View"
		prompt.ObjectText = egg.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt:SetAttribute("Egg", egg.Id)
		prompt.Parent = anchor
	end)
	m.PrimaryPart = basePart
end

-- Small leaning tombstone (garden decoration), facing the plaza.
local function tomb(parent: Instance, cf: CFrame, tilt: number)
	local t = cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(tilt))
	Kit.Part(parent, V(2, 2.8, 0.6), t, C(150, 145, 165), { Mat = Enum.Material.Slate, Solid = true })
	Kit.Part(parent, V(0.6, 2, 2), t * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.pi / 2, 0), C(150, 145, 165), { Mat = Enum.Material.Slate, Shape = Enum.PartType.Cylinder })
	Kit.Part(parent, V(2.4, 0.3, 1), cf * CFrame.new(0, 0.15, 0), MOSS)
end

function Hatchery.Build(map: Instance)
	local m = Kit.Model(map, "Hatchery")
	local spawnPos = Config.Layout.Spawn
	local c = CENTER
	local base = CFrame.new(c) * CFrame.Angles(0, Kit.FaceYaw(spawnPos.X - c.X, spawnPos.Z - c.Z), 0)
	local function L(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, z)
	end

	-- mossy flagstone floor (low: stepped onto, not a wall) with a cobble apron at the front
	local floor = Kit.Part(m, V(HW * 2, 0.6, HD * 2), L(0, -0.1, 0), C(80, 72, 100), { Mat = Enum.Material.Slate, Solid = true, Name = "Floor" })
	Kit.Part(m, V(HW * 2 - 2, 0.04, 4.6), L(0, 0.22, -HD + 3.3), C(105, 92, 135), { Mat = Enum.Material.Cobblestone, Solid = true })

	-- iron garden fence along the back and both sides (the front stays open)
	local function at(x: number, z: number): Vector3
		return L(x, 0.2, z).Position
	end
	Props.Fence(m, at(-HW, HD), at(HW, HD), "iron")
	Props.Fence(m, at(-HW, HD), at(-HW, -HD + 2), "iron")
	Props.Fence(m, at(HW, HD), at(HW, -HD + 2), "iron")

	-- open pavilion: four stone pillars and a slate roof over the pedestals
	for _, px in { -PX, PX } do
		for _, pz in { -PZ, PZ } do
			Kit.Part(m, V(1.6, ROOF_Y - 0.2, 1.6), L(px, 0.2 + (ROOF_Y - 0.2) / 2, pz), STONE, { Mat = Enum.Material.Slate, Solid = true })
			Kit.Part(m, V(2.4, 1, 2.4), L(px, 0.7, pz), STONE_DARK, { Mat = Enum.Material.Slate, Solid = true })
		end
	end
	local rw, rd = PX * 2 + 3, PZ * 2 + 3
	Kit.Part(m, V(rw, 1, rd), L(0, ROOF_Y + 0.5, 0), STONE_DARK, { Mat = Enum.Material.Slate, Shadow = true })
	local roofC = C(70, 40, 110)
	Kit.Wedge(m, V(rw, 3.5, rd / 2), L(0, ROOF_Y + 2.75, -rd / 4), roofC, { Mat = Enum.Material.Slate })
	Kit.Wedge(m, V(rw, 3.5, rd / 2), L(0, ROOF_Y + 2.75, rd / 4) * CFrame.Angles(0, math.pi, 0), roofC, { Mat = Enum.Material.Slate })
	-- back wall panel so the eggs read against a dark backdrop
	Kit.Part(m, V(PX * 2, 8.4, 0.8), L(0, 4.4, PZ), C(45, 30, 75), { Mat = Enum.Material.Slate, Solid = true })

	-- big sign over the front of the pavilion, facing the plaza
	local signCF = L(0, ROOF_Y - 1.5, -PZ - 1.1)
	local sign = Kit.Part(m, V(14, 3, 0.6), signCF, C(35, 22, 60), { Name = "HatcherySign" })
	Kit.Part(m, V(15, 3.8, 0.4), signCF * CFrame.new(0, 0, 0.4), Kit.Vivid(SHARD))
	Kit.Sign(sign, Enum.NormalId.Front, "🥚 PET HATCHERY 🥚", C(255, 240, 160))

	-- pedestals (Config.EggOrder, left to right as seen from the plaza)
	local n = #Config.EggOrder
	for i, id in Config.EggOrder do
		local egg = Config.Eggs[id]
		if egg then
			pedestal(m, base, egg, (i - (n + 1) / 2) * PED_GAP)
		end
	end

	-- graveyard garden outside the fence: tombstones, lanterns at the open front, a shard cluster
	-- (nothing stands between the visitor and the egg price signs)
	tomb(m, L(-HW - 1.8, 0.2, 1), 6)
	tomb(m, L(-HW - 1.8, 0.2, 4.5), -5)
	tomb(m, L(HW + 1.8, 0.2, 3), -7)
	Props.Lantern(m, L(-HW - 1, 0.2, -HD - 1).Position, SHARD, true, false)
	Props.Lantern(m, L(HW + 1, 0.2, -HD - 1).Position, SHARD, false, false)
	local cluster = L(HW + 2, 0.2, -1).Position
	crystal(m, cluster + V(0, 1.4, 0), 1.2, SHARD, false)
	crystal(m, cluster + V(-0.6, 0.9, 0.7), 0.8, C(170, 130, 255), false)
	crystal(m, cluster + V(0.6, 0.8, -0.6), 0.7, C(220, 190, 255), false)
	crystal(m, cluster + V(0, 4.2, 0), 0.6, SHARD, true)

	m.PrimaryPart = floor
end

return Hatchery
