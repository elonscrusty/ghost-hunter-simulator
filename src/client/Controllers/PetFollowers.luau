--!strict
-- Ghost pets floating beside every player (read from the player's "Pets" attribute, e.g.
-- "GlowWisp,BooBat"). Small procedural ghosts: ball body, 2 eyes, a wispy tail and a few
-- accents per Shape, lit in their glow colour. Client-only, anchored, no collisions/queries/
-- shadows; one RenderStepped loop moves every pet with a single BulkMoveTo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)

local PetFollowers = {}

type Piece = { Part: Part, Offset: CFrame }
type Pet = { Pieces: { Piece }, Cur: CFrame?, Slot: number }
type Entry = { Pets: { Pet }, Conns: { RBXScriptConnection } }

-- beside/behind the shoulders (root space: +X right, +Z behind)
local SLOTS = { Vector3.new(-2.6, 1.4, 1.6), Vector3.new(2.6, 1.4, 1.6), Vector3.new(0, 2.6, 2.8) }
local FAR = 250 -- don't bother moving pets this far from the camera

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

local BALL, BLOCK, WEDGE = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Wedge
local function v(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function buildPet(def: Config.PetDef, slot: number): Pet
	local pieces: { Piece } = {}
	local c, g = def.Color, def.Glow
	local body = part(pieces, BALL, if def.Shape == "Blob" then Vector3.new(1.7, 1.3, 1.7) else Vector3.new(1.4, 1.4, 1.4), c, CFrame.identity, false, 0.1)
	-- rarity glow: brighter and wider for rarer pets
	local r = Config.Rarities[def.Rarity]
	local order = if r then r.Order else 1
	local light = Instance.new("PointLight")
	light.Color = g
	light.Range = 4 + order * 1.5
	light.Brightness = 0.6 + order * 0.3
	light.Shadows = false
	light.Parent = body
	-- ghost tail + eyes (every pet)
	part(pieces, BALL, Vector3.new(0.8, 0.8, 0.8), g, v(0, -0.55, 0.35), true, 0.45)
	local eye = Color3.fromRGB(25, 20, 40)
	part(pieces, BALL, Vector3.new(0.28, 0.36, 0.2), eye, v(-0.25, 0.15, -0.62))
	part(pieces, BALL, Vector3.new(0.28, 0.36, 0.2), eye, v(0.25, 0.15, -0.62))
	local s = def.Shape
	if s == "Wisp" then
		part(pieces, BALL, Vector3.new(0.4, 0.4, 0.4), g, v(0, -0.9, 0.8), true, 0.3)
	elseif s == "Bat" or s == "Drake" or s == "Phoenix" then
		local wc = if s == "Phoenix" then g else c
		part(pieces, BLOCK, Vector3.new(1.1, 0.12, 0.6), wc, v(-1.1, 0.25, 0.1) * CFrame.Angles(0, 0, math.rad(25)), s == "Phoenix")
		part(pieces, BLOCK, Vector3.new(1.1, 0.12, 0.6), wc, v(1.1, 0.25, 0.1) * CFrame.Angles(0, 0, math.rad(-25)), s == "Phoenix")
		if s == "Drake" then
			part(pieces, WEDGE, Vector3.new(0.12, 0.4, 0.25), g, v(-0.3, 0.8, 0), true)
			part(pieces, WEDGE, Vector3.new(0.12, 0.4, 0.25), g, v(0.3, 0.8, 0), true)
		elseif s == "Phoenix" then
			part(pieces, WEDGE, Vector3.new(0.12, 0.5, 0.5), g, v(0, 0.85, 0.05), true)
		else
			part(pieces, WEDGE, Vector3.new(0.12, 0.35, 0.3), c, v(-0.35, 0.75, 0))
			part(pieces, WEDGE, Vector3.new(0.12, 0.35, 0.3), c, v(0.35, 0.75, 0))
		end
	elseif s == "Cat" or s == "Fox" then
		part(pieces, WEDGE, Vector3.new(0.15, 0.45, 0.35), c, v(-0.38, 0.75, 0))
		part(pieces, WEDGE, Vector3.new(0.15, 0.45, 0.35), c, v(0.38, 0.75, 0))
		if s == "Fox" then
			part(pieces, BALL, Vector3.new(0.6, 0.6, 1.1), g, v(0, -0.2, 0.95), true, 0.2)
		end
	elseif s == "Owl" then
		part(pieces, BLOCK, Vector3.new(0.2, 0.35, 0.2), c, v(-0.4, 0.75, 0) * CFrame.Angles(0, 0, math.rad(20)))
		part(pieces, BLOCK, Vector3.new(0.2, 0.35, 0.2), c, v(0.4, 0.75, 0) * CFrame.Angles(0, 0, math.rad(-20)))
		part(pieces, BALL, Vector3.new(0.2, 0.2, 0.25), Color3.fromRGB(255, 190, 70), v(0, -0.08, -0.68))
	elseif s == "Lantern" then
		part(pieces, BLOCK, Vector3.new(0.5, 0.6, 0.5), g, v(0, -1.1, -0.2), true, 0.15)
		part(pieces, BLOCK, Vector3.new(0.08, 0.4, 0.08), Color3.fromRGB(60, 50, 40), v(0, -0.65, -0.2))
	end
	return { Pieces = pieces, Slot = slot }
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
	if type(list) ~= "string" then
		return
	end
	for id in string.gmatch(list, "[^,]+") do
		local def = Config.Pets[id]
		if def and #e.Pets < #SLOTS then
			table.insert(e.Pets, buildPet(def, #e.Pets + 1))
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
