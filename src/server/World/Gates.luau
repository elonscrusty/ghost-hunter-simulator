--!strict
-- Zone gates: workspace.Map.Gates.Gate_<ZoneId> with Barrier, Arch, PromptAnchor and Sign
-- (TextLabel "CostLabel" on the sign's Front face, which faces the approaching player at -Z).
-- The Barrier is a ForceField-material wall (shimmering, no neon blow-out); the client
-- (Ambience) toggles its collision, tweens its Color/Size/CFrame/Transparency on unlock.
-- Trims are painted (solid); only the hanging lanterns, pillar jack-o'-lanterns and the
-- skull's eyes glow.

local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Format = require(game:GetService("ReplicatedStorage").GH.Logic.Format)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Gates = {}

local C = Color3.fromRGB
local V = Vector3.new
local NEON = Enum.Material.Neon

type Theme = { Stone: Color3, Trim: Color3, Barrier: Color3, Lamp: Color3 }

local THEMES: { [string]: Theme } = {
	Cemetery = { Stone = C(150, 125, 200), Trim = C(140, 255, 120), Barrier = C(180, 110, 255), Lamp = C(140, 255, 160) },
	School = { Stone = C(225, 120, 100), Trim = C(210, 120, 255), Barrier = C(100, 255, 190), Lamp = C(220, 150, 255) },
	Carnival = { Stone = C(235, 75, 85), Trim = C(255, 210, 70), Barrier = C(255, 120, 200), Lamp = C(255, 220, 120) },
	Hospital = { Stone = C(220, 228, 238), Trim = C(100, 180, 255), Barrier = C(120, 255, 200), Lamp = C(170, 230, 255) },
	Harbor = { Stone = C(125, 90, 60), Trim = C(70, 200, 200), Barrier = C(90, 255, 210), Lamp = C(255, 200, 110) },
	Castle = { Stone = C(150, 150, 165), Trim = C(255, 200, 70), Barrier = C(190, 110, 255), Lamp = C(255, 190, 100) },
	SpiritRealm = { Stone = C(70, 60, 110), Trim = C(110, 230, 255), Barrier = C(110, 240, 255), Lamp = C(150, 255, 230) },
	Swamp = { Stone = C(100, 120, 75), Trim = C(170, 255, 120), Barrier = C(150, 255, 120), Lamp = C(200, 255, 140) },
	Frost = { Stone = C(205, 225, 245), Trim = C(110, 190, 255), Barrier = C(170, 240, 255), Lamp = C(200, 245, 255) },
	Tomb = { Stone = C(225, 190, 125), Trim = C(70, 200, 220), Barrier = C(255, 210, 90), Lamp = C(255, 220, 140) },
	ToyFactory = { Stone = C(255, 150, 190), Trim = C(255, 225, 90), Barrier = C(255, 140, 220), Lamp = C(255, 230, 150) },
	Sunken = { Stone = C(90, 150, 170), Trim = C(255, 220, 120), Barrier = C(90, 255, 230), Lamp = C(150, 255, 240) },
	Clockwork = { Stone = C(160, 120, 80), Trim = C(230, 200, 120), Barrier = C(255, 190, 90), Lamp = C(255, 210, 130) },
	Inferno = { Stone = C(90, 55, 55), Trim = C(255, 150, 60), Barrier = C(255, 120, 60), Lamp = C(255, 170, 90) },
	Throne = { Stone = C(240, 235, 255), Trim = C(255, 215, 90), Barrier = C(255, 230, 140), Lamp = C(255, 240, 180) },
}

local function buildGate(folder: Instance, id: string, z: number, width: number)
	local zone = Config.ZoneById[id]
	local theme = THEMES[id] or THEMES.Cemetery
	local half = width / 2
	local m = Kit.Model(folder, "Gate_" .. id)
	local trim = Kit.Vivid(theme.Trim)

	-- Barrier: fills the opening. Other code toggles collision locally and tweens it.
	local barrier = Kit.Part(m, V(width, 30, 2), CFrame.new(0, 15, z), theme.Barrier, {
		Name = "Barrier",
		Mat = Enum.Material.ForceField,
		Transp = 0.4,
		Solid = true,
		Shadow = false,
	})
	barrier.CanQuery = false
	barrier.CanTouch = true

	-- Arch around the opening (never inside it).
	local arch = Kit.Model(m, "Arch")
	local pw = 8 -- pillar width
	for _, s in { -1, 1 } do
		local x1, x2 = s * half, s * (half + pw)
		Kit.Box(arch, V(x1, 0, z - 5), V(x2, 32, z + 5), theme.Stone, { Mat = Enum.Material.Slate, Solid = true })
		Kit.Box(arch, V(s * (half + 0.01), 0, z - 6), V(s * (half + pw + 1), 3, z + 6), theme.Stone:Lerp(Color3.new(0, 0, 0), 0.2), { Mat = Enum.Material.Slate, Solid = true })
		-- painted trims on the pillar fronts (both sides)
		for _, fz in { -1, 1 } do
			for _, ex in { 0.6, pw - 0.6 } do
				local x = s * (half + ex)
				Kit.Box(arch, V(x - 0.3, 3, z + fz * 5), V(x + 0.3, 30, z + fz * 5.3), trim)
			end
		end
		-- glowing jack-o'-lantern on top of each pillar
		Props.Pumpkin(arch, V(s * (half + pw / 2), 36, z), 6.5, 0, -1, true)
		-- hanging lantern on the approach side
		local lx = s * (half + pw / 2)
		Kit.Box(arch, V(lx - 0.3, 24, z - 5.8), V(lx + 0.3, 26, z - 5), C(50, 40, 70))
		local lamp = Kit.Box(arch, V(lx - 1.1, 21, z - 6.8), V(lx + 1.1, 24, z - 4.6), theme.Lamp, { Mat = NEON })
		Kit.Light(lamp, theme.Lamp, 22, 1.6)
	end
	-- top beam (Y 30..36) spanning the opening above the barrier
	Kit.Box(arch, V(-(half + pw + 1), 30, z - 4), V(half + pw + 1, 36, z + 4), theme.Stone, { Mat = Enum.Material.Slate, Solid = true })
	for _, fz in { -1, 1 } do
		Kit.Box(arch, V(-(half + pw + 1), 30, z + fz * 4), V(half + pw + 1, 30.6, z + fz * 4.3), trim)
	end
	-- crenellations
	for i = -2, 2 do
		local x = i * 9
		Kit.Box(arch, V(x - 2, 36, z - 3), V(x + 2, 38, z + 3), theme.Stone, { Mat = Enum.Material.Slate })
	end
	-- skull centrepiece on the approach face
	Props.Skull(arch, V(0, 33, z - 5), 4.5, 0, -1)
	-- low wisps either side of the opening
	Props.Wisp(arch, V(-(half + 5), 0, z - 9), theme.Barrier, 10, false)
	Props.Wisp(arch, V(half + 5, 0, z - 9), theme.Barrier, 10, false)

	-- Sign above the arch, Front face (-Z) toward players coming from the previous zone.
	local sign = Kit.Part(m, V(40, 10, 1), CFrame.new(0, 43, z - 3), C(45, 25, 80), { Name = "Sign" })
	Kit.Part(arch, V(42, 12, 0.6), CFrame.new(0, 43, z - 2.3), trim) -- frame
	local gui = Kit.Gui(sign, Enum.NormalId.Front, 30)
	Kit.Label(gui, zone.Name, zone.Accent, {
		Name = "ZoneLabel",
		Pos = UDim2.fromScale(0.03, 0.04),
		Size = UDim2.fromScale(0.94, 0.5),
	})
	Kit.Label(gui, "🔒 " .. Format.Short(zone.Cost) .. " ECTOPLASM", C(150, 255, 140), {
		Name = "CostLabel",
		Pos = UDim2.fromScale(0.08, 0.56),
		Size = UDim2.fromScale(0.84, 0.38),
	})

	-- Prompt anchor on the near side.
	Kit.Part(m, V(1, 1, 1), CFrame.new(0, 4, z - 6), C(255, 255, 255), { Name = "PromptAnchor", Transp = 1 })

	m.PrimaryPart = barrier
end

function Gates.Build(map: Instance)
	local folder = Kit.Folder(map, "Gates")
	for id, g in Kit.Gates(Config.Layout) do
		buildGate(folder, id, g.Z, g.Width)
	end
end

return Gates
