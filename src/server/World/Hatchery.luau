--!strict
-- PET HATCHERY (workspace.Map.Hatchery): a small open pavilion in a graveyard garden near the
-- Boss Tower, south of the cross street and west of the tower plaza (footprint X 48..68,
-- Z 66..88; Builder reserves X 46..70, Z 65..90 plus the path X 50.5..54.5 to the street). Faces north
-- (+Z) toward the cross street.
--   Three pedestals (Config.EggOrder, west to east), each with a big egg, a price/unlock sign
--   and an invisible PromptAnchor (attribute Egg = egg id) holding a "View" ProximityPrompt.
--   The client (Controllers/Hatchery) opens the egg panel from the prompt; buying and rolling
--   happen only on the server (PetService "BuyEgg").
-- Built last in Builder and without Kit.Rng, so it never shifts other zones' random props.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Format = require(game:GetService("ReplicatedStorage").GH.Logic.Format)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Hatchery = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

local X1, X2, Z1, Z2 = 48, 68, 66, 88
local PED_Z = 73 -- pedestal row
local ROOF_Y = 14
local STONE = C(96, 84, 120)
local STONE_DARK = C(64, 54, 86)
local MOSS = C(70, 92, 70)
local SHARD = C(200, 160, 255)
local NORTH = math.pi -- yaw that turns a part's Front face (local -Z) toward +Z

-- Spirit Shard crystal (a diamond: a block turned 45 degrees), optionally floating.
local function crystal(parent: Instance, pos: Vector3, s: number, color: Color3, float: boolean)
	local p = Kit.Part(parent, V(s, s * 1.6, s), CFrame.new(pos) * CFrame.Angles(0, math.rad(45), math.rad(12)), color, { Mat = Enum.Material.Glass, Transp = 0.15, Refl = 0.2 })
	if float then
		Kit.Float(p, 0.6)
	end
	return p
end

-- The egg: two stacked balls (wide bottom, narrower top) read as an egg shape.
local function eggShape(parent: Instance, x: number, y: number, z: number, color: Color3, opts: Kit.Opts?): Part
	local low = Kit.Ball(parent, 4.2, V(x, y + 2.1, z), color, opts)
	Kit.Ball(parent, 3.4, V(x, y + 3.6, z), color, opts)
	return low
end

local function hauntedEgg(m: Instance, x: number, y: number, z: number, egg: Config.EggDef)
	eggShape(m, x, y, z, Kit.Vivid(egg.Color))
	-- green ecto cracks across the front (thin neon strips: the egg's one glowing accent)
	local front = z + 2.05
	local cracks = { { -0.9, 2.4, 25 }, { 0.2, 2.9, -35 }, { 0.9, 2.2, 40 }, { -0.2, 3.9, 60 } }
	for _, c in cracks do
		Kit.Part(m, V(0.18, 1.2, 0.2), CFrame.new(x + c[1], y + c[2], front) * CFrame.Angles(0, 0, math.rad(c[3])), egg.Accent, { Mat = NEON })
	end
	-- dark speckles
	for _, sp in { { -1.3, 1.6 }, { 1.2, 3.4 }, { 0.6, 1.2 } } do
		Kit.Ball(m, 0.6, V(x + sp[1], y + sp[2], z + 1.75), C(70, 30, 120))
	end
end

local function phantomEgg(m: Instance, x: number, y: number, z: number, egg: Config.EggDef)
	eggShape(m, x, y, z, egg.Color, { Mat = Enum.Material.Glass, Transp = 0.3, Refl = 0.1 })
	-- inner soft core
	Kit.Ball(m, 2.4, V(x, y + 2.5, z), egg.Accent, { Transp = 0.4 })
	-- ghost face on the front
	local dark = C(30, 30, 60)
	Kit.Ball(m, 0.8, V(x - 0.7, y + 3.4, z + 1.55), dark)
	Kit.Ball(m, 0.8, V(x + 0.7, y + 3.4, z + 1.55), dark)
	Kit.Part(m, V(0.9, 0.6, 0.3), CFrame.new(x, y + 2.4, z + 2.0), dark)
end

local function moonlightEgg(m: Instance, x: number, y: number, z: number, egg: Config.EggDef)
	eggShape(m, x, y, z, egg.Color, { Refl = 0.15 })
	-- crescent moon: a pale disc partly covered by an egg-coloured disc
	local front = z + 2.0
	Kit.Part(m, V(0.2, 1.6, 1.6), CFrame.new(x - 0.2, y + 3.0, front) * CFrame.Angles(0, math.pi / 2, 0), egg.Accent, { Shape = Enum.PartType.Cylinder })
	Kit.Part(m, V(0.2, 1.4, 1.4), CFrame.new(x + 0.2, y + 3.15, front + 0.08) * CFrame.Angles(0, math.pi / 2, 0), egg.Color, { Shape = Enum.PartType.Cylinder })
	-- stars
	for _, s in { { -1.2, 1.7 }, { 1.1, 2.0 }, { 0.8, 4.1 }, { -0.9, 4.0 }, { 0.1, 1.2 } } do
		Kit.Ball(m, 0.35, V(x + s[1], y + s[2], z + 1.85), C(255, 245, 200), { Mat = NEON })
	end
end

local EGG_LOOK: { [string]: (Instance, number, number, number, Config.EggDef) -> () } = {
	HauntedEgg = hauntedEgg,
	PhantomEgg = phantomEgg,
	MoonlightEgg = moonlightEgg,
}

local function pedestal(parent: Instance, egg: Config.EggDef, x: number)
	local m = Kit.Model(parent, "Pedestal_" .. egg.Id)
	local z = PED_Z
	-- stepped stone pedestal
	local base = Kit.Disc(m, x, z, 0.8, 6.4, 0.6, STONE_DARK, { Mat = Enum.Material.Slate, Solid = true, Name = "Base" })
	Kit.Cyl(m, 2.2, 4.2, CFrame.new(x, 1.9, z), STONE, { Mat = Enum.Material.Slate, Solid = true })
	Kit.Disc(m, x, z, 3.3, 5.2, 0.4, Kit.Vivid(egg.Accent))
	local look = EGG_LOOK[egg.Id]
	if look then
		look(m, x, 3.3, z, egg)
	else
		eggShape(m, x, 3.3, z, egg.Color)
	end
	-- soft glow under the egg (low brightness: no bloom spike)
	local glow = Kit.Part(m, V(1, 1, 1), CFrame.new(x, 5, z + 2), egg.Accent, { Transp = 1, Name = "Glow" })
	Kit.Light(glow, egg.Accent, 12, 0.7)
	-- floating Spirit Shard crystals beside the egg
	crystal(m, V(x - 2.6, 7.6, z), 0.7, SHARD, true)
	crystal(m, V(x + 2.6, 8.2, z), 0.6, SHARD, true)

	-- price / unlock sign in front of the pedestal, facing north
	local signCF = CFrame.new(x, 2.6, z + 4.2) * CFrame.Angles(0, NORTH, 0) * CFrame.Angles(math.rad(-12), 0, 0)
	local board = Kit.Part(m, V(5.6, 3.2, 0.4), signCF, C(35, 22, 60), { Name = "EggSign" })
	Kit.Part(m, V(6.1, 3.7, 0.3), signCF * CFrame.new(0, 0, 0.3), Kit.Vivid(egg.Accent))
	Kit.Box(m, V(x - 0.25, 0, z + 4.4), V(x + 0.25, 0.8, z + 4.9), STONE_DARK)
	local g = Kit.Gui(board, Enum.NormalId.Front)
	Kit.Label(g, string.upper(egg.Name), C(255, 255, 255), { Size = UDim2.fromScale(0.94, 0.34), Pos = UDim2.fromScale(0.03, 0.04) })
	Kit.Label(g, "🔮 " .. Format.Commas(egg.Price), SHARD, { Size = UDim2.fromScale(0.8, 0.3), Pos = UDim2.fromScale(0.1, 0.38) })
	local unlock = if egg.Unlock > 0 then "Unlock: Tower checkpoint " .. egg.Unlock else "Open to everyone"
	Kit.Label(g, unlock, C(150, 255, 170), { Size = UDim2.fromScale(0.94, 0.22), Pos = UDim2.fromScale(0.03, 0.72) })

	-- invisible prompt anchor in front of the sign
	local anchor = Kit.Part(m, V(1, 1, 1), CFrame.new(x, 3, z + 5.5), egg.Color, { Transp = 1, Name = "PromptAnchor" })
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
	m.PrimaryPart = base
end

-- Small leaning tombstone (garden decoration).
local function tomb(parent: Instance, x: number, z: number, tilt: number)
	local cf = CFrame.new(x, 1.4, z) * CFrame.Angles(0, NORTH, math.rad(tilt))
	Kit.Part(parent, V(2, 2.8, 0.6), cf, C(150, 145, 165), { Mat = Enum.Material.Slate, Solid = true })
	Kit.Part(parent, V(0.6, 2, 2), cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.pi / 2, 0), C(150, 145, 165), { Mat = Enum.Material.Slate, Shape = Enum.PartType.Cylinder })
	Kit.Part(parent, V(2.4, 0.3, 1), CFrame.new(x, 0.15, z), MOSS)
end

function Hatchery.Build(map: Instance)
	local m = Kit.Model(map, "Hatchery")

	-- mossy flagstone floor (low: stepped onto, not a wall)
	local floor = Kit.Box(m, V(X1, -0.4, Z1), V(X2, 0.2, Z2), C(80, 72, 100), { Mat = Enum.Material.Slate, Solid = true, Name = "Floor" })
	Kit.Box(m, V(X1 + 1, 0.2, Z1 + 1), V(X2 - 1, 0.24, Z1 + 13), C(105, 92, 135), { Mat = Enum.Material.Cobblestone, Solid = true })
	-- path to the cross street sidewalk (flat; west of the tower plaza's entrance arch pillar)
	Kit.Box(m, V(50.5, -0.4, Z2), V(54.5, 0.16, 106), C(110, 90, 150), { Mat = Enum.Material.Cobblestone, Solid = true, Name = "HatcheryPath" })

	-- iron garden fence on the south, west and east sides (north stays open)
	Props.Fence(m, V(X1, 0.2, Z1), V(X2, 0.2, Z1), "iron")
	Props.Fence(m, V(X1, 0.2, Z1), V(X1, 0.2, Z2 - 2), "iron")
	Props.Fence(m, V(X2, 0.2, Z1), V(X2, 0.2, Z2 - 2), "iron")

	-- open pavilion: four stone pillars and a slate roof over the pedestals
	local px1, px2, pz1, pz2 = X1 + 1.5, X2 - 1.5, Z1 + 1.5, PED_Z + 6
	for _, px in { px1, px2 } do
		for _, pz in { pz1, pz2 } do
			Kit.Box(m, V(px - 0.9, 0.2, pz - 0.9), V(px + 0.9, ROOF_Y, pz + 0.9), STONE, { Mat = Enum.Material.Slate, Solid = true })
			Kit.Box(m, V(px - 1.3, 0.2, pz - 1.3), V(px + 1.3, 1.2, pz + 1.3), STONE_DARK, { Mat = Enum.Material.Slate, Solid = true })
		end
	end
	local cz = (pz1 + pz2) / 2
	local depth = pz2 - pz1 + 4
	Kit.Box(m, V(px1 - 2, ROOF_Y, pz1 - 2), V(px2 + 2, ROOF_Y + 1, pz2 + 2), STONE_DARK, { Mat = Enum.Material.Slate, Shadow = true })
	local roofC = C(70, 40, 110)
	Kit.Wedge(m, V(px2 - px1 + 4, 4, depth / 2), CFrame.new((px1 + px2) / 2, ROOF_Y + 3, cz - depth / 4), roofC, { Mat = Enum.Material.Slate })
	Kit.Wedge(m, V(px2 - px1 + 4, 4, depth / 2), CFrame.new((px1 + px2) / 2, ROOF_Y + 3, cz + depth / 4) * CFrame.Angles(0, math.pi, 0), roofC, { Mat = Enum.Material.Slate })
	-- back wall panel (south) so the eggs read against a dark backdrop
	Kit.Box(m, V(px1, 0.2, pz1 - 0.4), V(px2, 9, pz1 + 0.4), C(45, 30, 75), { Mat = Enum.Material.Slate, Solid = true })

	-- big sign over the front of the pavilion, facing the cross street
	local signCF = CFrame.new((px1 + px2) / 2, ROOF_Y - 1.6, pz2 + 1.4) * CFrame.Angles(0, NORTH, 0)
	local sign = Kit.Part(m, V(16, 3.4, 0.6), signCF, C(35, 22, 60), { Name = "HatcherySign" })
	Kit.Part(m, V(17, 4.2, 0.4), signCF * CFrame.new(0, 0, 0.4), Kit.Vivid(SHARD))
	Kit.Sign(sign, Enum.NormalId.Front, "🥚 PET HATCHERY 🥚", C(255, 240, 160))
	-- side sign facing west (toward the main road and spawn)
	Props.SignBoard(m, V(X1 - 0.6, 6, Z2 - 4), 9, 2.6, -1, 0, "PET HATCHERY", C(35, 22, 60), C(255, 240, 160), SHARD)
	Kit.Box(m, V(X1 - 0.9, 0, Z2 - 4.3), V(X1 - 0.3, 4.7, Z2 - 3.7), STONE_DARK)

	-- pedestals (Config.EggOrder, west to east)
	local n = #Config.EggOrder
	for i, id in Config.EggOrder do
		local egg = Config.Eggs[id]
		if egg then
			pedestal(m, egg, (X1 + X2) / 2 + (i - (n + 1) / 2) * 6.5)
		end
	end

	-- graveyard garden: tombstones, lanterns and a big shard cluster by the entrance
	-- (all outside the fence, so nothing stands between the visitor and the egg price signs)
	tomb(m, X1 - 3, Z1 + 6, 6)
	tomb(m, X1 - 3.5, Z1 + 11, -5)
	tomb(m, X2 + 3, Z1 + 7, -7)
	Props.Lantern(m, V(X1 - 2.5, 0.2, Z2 + 1), SHARD, true, false)
	Props.Lantern(m, V(X2 + 2.5, 0.2, Z2 + 1), SHARD, false, false)
	local cluster = V(X2 + 3.5, 0.2, Z1 + 13)
	crystal(m, cluster + V(0, 1.4, 0), 1.2, SHARD, false)
	crystal(m, cluster + V(-0.9, 0.9, 0.6), 0.8, C(170, 130, 255), false)
	crystal(m, cluster + V(0.8, 0.8, -0.5), 0.7, C(220, 190, 255), false)
	crystal(m, cluster + V(0, 4.2, 0), 0.6, SHARD, true)

	m.PrimaryPart = floor
end

return Hatchery
