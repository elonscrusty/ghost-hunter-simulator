--!strict
-- Ghost pets floating beside every player (read from the player's "Pets" attribute, e.g.
-- "GlowWisp,BooBat", plus "PetNames": the server-filtered nicknames, one per line).
-- Each pet is a miniature of the world ghosts (GhostRig's body, tapering tail, big eyes with a
-- shine, "O" mouth, blush, nub arms) tinted with the pet's Color, plus a few Shape accents
-- (bat wings, kitty ears + tail, ...) and a small name label. GhostRig.Build itself is not
-- reused: it needs a Config.Ghosts id and builds a welded ~40-part model with an aura; here
-- every pet is ~15-20 anchored parts with no collisions/queries/touch/shadows, all moved by
-- one RenderStepped loop with a single BulkMoveTo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local WorldLabel = require(script.Parent.Parent.UI.WorldLabel)

local PetFollowers = {}

type Piece = { Part: Part, Offset: CFrame }
type Pet = { Pieces: { Piece }, Cur: CFrame?, Slot: number }
type Entry = { Pets: { Pet }, Conns: { RBXScriptConnection } }

-- beside/behind the shoulders (root space: +X right, +Z behind)
local SLOTS = { Vector3.new(-2.6, 1.4, 1.6), Vector3.new(2.6, 1.4, 1.6), Vector3.new(0, 2.6, 2.8) }
local FAR = 200 -- don't bother moving pets this far from the camera

local folder: Folder
local entries: { [Player]: Entry } = {}

local function part(pieces: { Piece }, shape: Enum.PartType, size: Vector3, color: Color3, offset: CFrame, neon: boolean?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	table.insert(pieces, { Part = p, Offset = offset })
	return p
end

local BALL, BLOCK, WEDGE, CYL = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Wedge, Enum.PartType.Cylinder

-- GhostRig's palette and proportions (ghost units: body diameter 3.5), shrunk by S
local S = 0.4
local R = 1.75
local EYE = Color3.fromRGB(25, 15, 40)
local WHITE = Color3.fromRGB(255, 255, 255)
local MOUTH = Color3.fromRGB(70, 20, 50)
local BLUSH = Color3.fromRGB(255, 150, 190)
local GOLD = Color3.fromRGB(255, 205, 60)
local CREAM = Color3.fromRGB(255, 244, 220)
local PINK = Color3.fromRGB(255, 170, 200)
local DARK = Color3.fromRGB(60, 50, 40)
local LABEL_Y = 2.9 * S + 0.3 -- above the tallest accent (studs from the body centre)

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x * S, y * S, z * S)
end

local function buildPet(def: Config.PetDef, slot: number, label: string): Pet
	local pieces: { Piece } = {}
	local c, g = def.Color, def.Glow
	local sh = def.Shape
	local function ball(d: number, cf: CFrame, col: Color3, neon: boolean?, tr: number?): Part
		return part(pieces, BALL, Vector3.one * (d * S), col, cf, neon, tr)
	end
	local function block(x: number, y: number, z: number, cf: CFrame, col: Color3, neon: boolean?): Part
		return part(pieces, BLOCK, Vector3.new(x, y, z) * S, col, cf, neon)
	end
	-- triangle seen from the front (ears, horns, crest); side = -1 slopes left, 1 right
	local function spike(x: number, y: number, w: number, h: number, side: number, col: Color3, neon: boolean?): Part
		return part(pieces, WEDGE, Vector3.new(0.3, h, w) * S, col, at(x, y, 0.1) * CFrame.Angles(0, -side * math.pi / 2, 0), neon)
	end
	local function wings(col: Color3, neon: boolean?)
		for _, s in { -1, 1 } do
			block(2.2, 0.22, 1.3, at(2.4 * s, 0.6, 0.4) * CFrame.Angles(0, 0, math.rad(-28 * s)), col, neon)
		end
	end

	------------------------------------------------------------ the ghost (GhostRig at scale S)
	local body = ball(2 * R, CFrame.identity, c)
	if sh == "Blob" then
		-- jelly: drips instead of a tail, plus a shiny highlight
		ball(1.0, at(-0.9, -1.45, 0.1), c)
		ball(0.8, at(0.2, -1.65, -0.2), c)
		ball(0.65, at(1.0, -1.4, 0.3), c)
		ball(0.7, at(-0.7, 1.1, -0.95), WHITE, false, 0.35)
	else
		local tip = sh == "Phoenix" or sh == "Wisp" -- flame / wisp tail tip
		ball(2.4, at(0, -1.0, 0.5), c)
		ball(1.6, at(0.15, -1.8, 1.05), if tip then g else c, tip)
		ball(0.9, at(-0.05, -2.35, 1.55), if tip then g else c, tip)
	end
	for _, s in { -1, 1 } do
		local eye = Vector3.new(0.6 * s, 0.35, -1.38)
		ball(0.9, CFrame.new(eye * S), EYE)
		ball(0.32, CFrame.new((eye + Vector3.new(0.16, 0.18, -0.3)) * S), WHITE)
		ball(0.95, at(1.7 * s, -0.35, -0.2), c) -- nub arm
		ball(0.4, at(1.0 * s, -0.12, -1.45), BLUSH)
	end
	local mouth = Vector3.new(0, -0.45, -1.65).Unit * (R - 0.02)
	part(pieces, CYL, Vector3.new(0.25, 0.6, 0.6) * S, MOUTH, CFrame.new(mouth * S) * CFrame.Angles(0, math.pi / 2, 0))

	-- rarity glow: brighter and wider for rarer pets
	local r = Config.Rarities[def.Rarity]
	local order = if r then r.Order else 1
	local light = Instance.new("PointLight")
	light.Color = g
	light.Range = 4 + order * 1.5
	light.Brightness = 0.6 + order * 0.3
	light.Shadows = false
	light.Parent = body

	------------------------------------------------------------ identity accents
	if sh == "Wisp" then
		ball(0.9, at(0, 1.95, 0), g, true)
		ball(0.5, at(0.15, 2.55, 0.1), g, true, 0.2)
	elseif sh == "Bat" then
		for _, s in { -1, 1 } do
			spike(0.85 * s, 1.75, 0.8, 1.0, s, c)
		end
		wings(Color3.new(c.R * 0.7, c.G * 0.7, c.B * 0.7))
	elseif sh == "Cat" or sh == "Fox" then
		local fox = sh == "Fox"
		for _, s in { -1, 1 } do
			spike(0.85 * s, 1.7, 0.85, if fox then 1.3 else 1.0, s, c)
			spike(0.85 * s, 1.6, 0.45, 0.55, s, if fox then CREAM else PINK)
		end
		if fox then -- big fluffy tail with a white tip
			ball(1.5, at(0.4, -0.6, 2.1), c)
			ball(1.0, at(0.7, -0.1, 2.9), CREAM)
		else -- curled kitty tail
			ball(0.6, at(1.0, -0.4, 1.8), c)
			ball(0.55, at(1.25, 0.25, 2.0), c)
			ball(0.5, at(1.15, 0.85, 1.95), c)
		end
	elseif sh == "Owl" then
		for _, s in { -1, 1 } do
			block(0.4, 0.8, 0.4, at(0.95 * s, 1.65, 0) * CFrame.Angles(0, 0, math.rad(-22 * s)), c) -- ear tuft
			ball(1.25, at(0.6 * s, 0.35, -1.15), CREAM) -- big owl eye ring
		end
		part(pieces, WEDGE, Vector3.new(0.35, 0.45, 0.35) * S, GOLD, at(0, -0.15, -1.75) * CFrame.Angles(math.pi, 0, 0))
		ball(0.55, at(0, 1.15, -1.3), GOLD, true) -- moon mark
		ball(0.4, at(0.12, 1.25, -1.45), c) -- carves the crescent
	elseif sh == "Drake" then
		for _, s in { -1, 1 } do
			spike(0.75 * s, 1.75, 0.5, 1.1, s, GOLD)
		end
		wings(g)
		part(pieces, WEDGE, Vector3.new(0.3, 0.6, 0.7) * S, g, at(0, 0.6, 1.8))
	elseif sh == "Phoenix" then
		spike(0, 2.05, 0.7, 1.2, 1, g, true)
		spike(-0.4, 1.85, 0.5, 0.9, -1, GOLD)
		spike(0.4, 1.85, 0.5, 0.9, 1, GOLD)
		wings(g, true)
	elseif sh == "Lantern" then
		local hand = Vector3.new(2.0, -0.6, -0.5)
		block(0.12, 0.6, 0.12, CFrame.new((hand + Vector3.new(0, -0.3, 0)) * S), DARK)
		block(0.9, 0.2, 0.9, CFrame.new((hand + Vector3.new(0, -0.65, 0)) * S), DARK)
		block(0.75, 0.9, 0.75, CFrame.new((hand + Vector3.new(0, -1.2, 0)) * S), g, true)
	end

	-- name tag (the nickname is filtered by the server before it is published)
	local gui = WorldLabel.New({
		Name = "PetTag",
		Adornee = body,
		Parent = body,
		Size = Vector2.new(140, 20),
		Offset = Vector3.new(0, LABEL_Y, 0),
		MaxDistance = 60,
	})
	WorldLabel.Text(gui, label, { Style = "Small", Color = if r then r.Color else nil })
	return { Pieces = pieces, Slot = slot }
end

-- A standalone pet Model (no name tag), pivot = body centre. Used by the egg hatch reveal.
function PetFollowers.BuildPet(petId: string): Model?
	local def = Config.Pets[petId]
	if not def then
		return nil
	end
	local pet = buildPet(def, 1, def.Name)
	local m = Instance.new("Model")
	m.Name = "Pet_" .. petId
	for _, pc in pet.Pieces do
		local tag = pc.Part:FindFirstChild("PetTag")
		if tag then
			tag:Destroy()
		end
		pc.Part.CFrame = pc.Offset
		pc.Part.Parent = m
	end
	m.PrimaryPart = pet.Pieces[1].Part
	return m
end

local function clear(e: Entry)
	for _, pet in e.Pets do
		for _, pc in pet.Pieces do
			pc.Part:Destroy()
		end
	end
	e.Pets = {}
end

local function rebuild(plr: Player)
	local e = entries[plr]
	if not e then
		return
	end
	clear(e)
	if not plr.Character then
		return
	end
	local list = plr:GetAttribute("Pets")
	if type(list) ~= "string" or list == "" then
		return
	end
	local rawNames = plr:GetAttribute("PetNames")
	local names = if type(rawNames) == "string" then string.split(rawNames, "\n") else {}
	for i, id in string.split(list, ",") do
		local def = Config.Pets[id]
		if def and #e.Pets < #SLOTS then
			local nick = names[i]
			table.insert(e.Pets, buildPet(def, #e.Pets + 1, if nick and nick ~= "" then nick else def.Name))
		end
	end
end

local function track(plr: Player)
	local e: Entry = { Pets = {}, Conns = {} }
	entries[plr] = e
	local function re()
		rebuild(plr)
	end
	table.insert(e.Conns, plr:GetAttributeChangedSignal("Pets"):Connect(re))
	table.insert(e.Conns, plr:GetAttributeChangedSignal("PetNames"):Connect(re))
	table.insert(e.Conns, plr.CharacterAdded:Connect(re))
	table.insert(e.Conns, plr.CharacterRemoving:Connect(function()
		clear(e)
	end))
	re()
end

local function untrack(plr: Player)
	local e = entries[plr]
	if e then
		clear(e)
		for _, c in e.Conns do
			c:Disconnect()
		end
		entries[plr] = nil
	end
end

function PetFollowers.Start()
	folder = Instance.new("Folder")
	folder.Name = "PetFollowers"
	folder.Parent = workspace
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, plr in Players:GetPlayers() do
		track(plr)
	end
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt: number)
		table.clear(parts)
		table.clear(cfs)
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		local t = os.clock()
		local alpha = math.min(1, dt * 8)
		for plr, e in entries do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or #e.Pets == 0 or (root.Position - camPos).Magnitude > FAR then
				continue
			end
			local base = root.CFrame
			for _, pet in e.Pets do
				local bob = math.sin(t * 2.2 + pet.Slot * 1.7) * 0.25
				local target = base * CFrame.new(SLOTS[pet.Slot] + Vector3.new(0, bob, 0))
				local cur = if pet.Cur then pet.Cur:Lerp(target, alpha) else target
				pet.Cur = cur
				for _, pc in pet.Pieces do
					table.insert(parts, pc.Part)
					table.insert(cfs, cur * pc.Offset)
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return PetFollowers
