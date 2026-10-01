--!strict
-- Draws every player's equipped Ghost Hunters (client-side, never collide with anything).
-- Idle: follow in a formation behind their player. Assigned (player's "Target" attribute):
-- run to a ring around the ghost, aim and fire a wobbly energy beam, celebrate on the poof,
-- then come back. All crews update in ONE RenderStepped loop: BulkMoveTo for roots, Motor6D
-- transforms for poses, staggered ground raycasts, and far-away crews are hidden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local HunterRig = require(GH.Rigs.HunterRig)
local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WorldLabel = require(Client.UI.WorldLabel)
local Ghosts = require(script.Parent.Ghosts)
local Targeting = require(script.Parent.Targeting)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local Crew = {}

type Member = {
	Id: string,
	Rig: HunterRig.Rig,
	Pos: Vector3,
	Yaw: number,
	State: string,
	GroundY: number,
	NextRay: number,
	Beam: Beam,
	CelebrateUntil: number,
	Phase: number,
	Color: Color3,
}

type CrewData = {
	Player: Player,
	Members: { Member },
	Visible: boolean,
	LastTarget: number,
	NextSpark: number,
	NextSound: number,
	Conns: { RBXScriptConnection },
}

local player = Players.LocalPlayer
local crews: { [Player]: CrewData } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local nextFilter = 0

local VISIBLE_RANGE = 170
local HUNTER_SCALE = 0.88 -- rigs are ~4-4.6 studs; this puts them at a player's chest height
local RUN_SPEED = Config.Combat.HunterRunSpeed

local function refreshFilter()
	local list: { Instance } = { folder }
	for _, name in { "Ghosts", "GHEffects", "GHOrbs", "GHReveal" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(list, pl.Character)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

local function makeBeam(m: Member)
	local beam = Instance.new("Beam")
	beam.Name = "CaptureBeam"
	beam.Attachment0 = m.Rig.Tip
	beam.Color = ColorSequence.new(m.Color, Color3.new(1, 1, 1))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 0.4) })
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Width0 = 0.35
	beam.Width1 = 0.9
	beam.Enabled = false
	beam.Parent = m.Rig.Model
	m.Beam = beam
end

-- One small line over each hunter: "★ Name" in its rarity colour. Short range (your own crew
-- reads it when the camera is close; it never stacks into clutter from afar).
local function addTag(m: Member, isLocal: boolean)
	local def = Config.Hunters[m.Id]
	local rar = Config.Rarities[def.Rarity]
	local gui = WorldLabel.New({
		Name = "Tag",
		Adornee = m.Rig.Root,
		Parent = m.Rig.Model,
		Size = Theme.World.CrewTag,
		Offset = Vector3.new(0, m.Rig.Height + 0.7, 0),
		MaxDistance = if isLocal then Theme.World.CrewMaxDistance else Theme.World.CrewMaxDistance * 0.6,
	})
	WorldLabel.Text(gui, string.rep("★", math.min(rar.Order, 5)) .. " " .. def.Name, { Style = "Tiny", Color = rar.Color })
	-- rare+ hunters stand on a soft rarity-coloured disc
	if rar.Order >= 3 then
		local disc = Instance.new("Part")
		disc.Name = "RarityDisc"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.12, 3.4, 3.4)
		disc.Material = Enum.Material.SmoothPlastic
		disc.Color = rar.Color
		disc.Transparency = 0.45
		disc.CanCollide = false
		disc.CanQuery = false
		disc.CanTouch = false
		disc.CastShadow = false
		disc.Massless = true
		disc.CFrame = m.Rig.Root.CFrame * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90))
		local w = Instance.new("WeldConstraint")
		w.Part0 = m.Rig.Root
		w.Part1 = disc
		w.Parent = disc
		disc.Parent = m.Rig.Model
	end
end

local function newMember(id: string, at: Vector3, isLocal: boolean): Member
	local rig = HunterRig.Build(id)
	rig.Model:ScaleTo(HUNTER_SCALE)
	rig.Height *= HUNTER_SCALE
	for _, p in rig.Model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	rig.Model:PivotTo(CFrame.new(at))
	rig.Model.Parent = folder
	local def = Config.Hunters[id]
	local m: Member = {
		Id = id,
		Rig = rig,
		Pos = at,
		Yaw = 0,
		State = "Idle",
		GroundY = at.Y,
		NextRay = 0,
		Beam = nil :: any,
		CelebrateUntil = 0,
		Phase = math.random() * 10,
		Color = def.Look.Beam,
	}
	makeBeam(m)
	addTag(m, isLocal)
	return m
end

local function rootOf(pl: Player): BasePart?
	local char = pl.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function rebuild(c: CrewData)
	local raw = c.Player:GetAttribute("Crew")
	local ids = {}
	if type(raw) == "string" and raw ~= "" then
		for id in raw:gmatch("[^,]+") do
			if Config.Hunters[id] and #ids < 12 then
				table.insert(ids, id)
			end
		end
	end
	local root = rootOf(c.Player)
	local at = if root then root.Position - Vector3.new(0, 3, 0) else Vector3.zero
	local isLocal = c.Player == player
	for i, id in ids do
		local m = c.Members[i]
		if not m or m.Id ~= id then
			if m then
				m.Rig.Model:Destroy()
			end
			local spawnAt = if m then m.Pos else at + Vector3.new((i - 2.5) * 2, 0, 3)
			c.Members[i] = newMember(id, spawnAt, isLocal)
			if isLocal and m == nil and os.clock() > 3 then
				Effects.Burst(spawnAt + Vector3.new(0, 2, 0), { Color = Config.Rarities[Config.Hunters[id].Rarity].Color, Count = 14, Size = 0.7, Speed = 10 })
			end
		end
	end
	for i = #c.Members, #ids + 1, -1 do
		c.Members[i].Rig.Model:Destroy()
		c.Members[i] = nil
	end
	if not c.Visible then
		for _, m in c.Members do
			m.Rig.Model.Parent = nil
		end
	end
end

local function addPlayer(pl: Player)
	if crews[pl] then
		return
	end
	local c: CrewData = {
		Player = pl,
		Members = {},
		Visible = true,
		LastTarget = 0,
		NextSpark = 0,
		NextSound = 0,
		Conns = {},
	}
	crews[pl] = c
	table.insert(c.Conns, pl:GetAttributeChangedSignal("Crew"):Connect(function()
		rebuild(c)
	end))
	rebuild(c)
end

local function removePlayer(pl: Player)
	local c = crews[pl]
	if not c then
		return
	end
	for _, conn in c.Conns do
		conn:Disconnect()
	end
	for _, m in c.Members do
		m.Rig.Model:Destroy()
	end
	crews[pl] = nil
end

local function setVisible(c: CrewData, on: boolean, root: BasePart?)
	if c.Visible == on then
		return
	end
	c.Visible = on
	for i, m in c.Members do
		m.Rig.Model.Parent = if on then folder else nil
		if on and root then
			-- snap back into formation instead of sprinting across the map
			m.Pos = root.Position + Vector3.new((i - 2.5) * 2.5, -3, 4)
			m.NextRay = 0
		end
	end
end

local function angleDiff(a: number, b: number): number
	return (b - a + math.pi) % (2 * math.pi) - math.pi
end

local function centerAttachment(e: Ghosts.Entry): Attachment
	local a = e.Core:FindFirstChild("Center")
	if a and a:IsA("Attachment") then
		return a
	end
	local made = Instance.new("Attachment")
	made.Name = "Center"
	made.Parent = e.Core
	return made
end

local roots: { BasePart } = {}
local cframes: { CFrame } = {}

local function step(dt: number)
	dt = math.min(dt, 0.1)
	local clock = os.clock()
	if clock > nextFilter then
		nextFilter = clock + 2
		refreshFilter()
	end
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	table.clear(roots)
	table.clear(cframes)

	for pl, c in crews do
		local root = rootOf(pl)
		local isLocal = pl == player
		if not root or #c.Members == 0 then
			setVisible(c, false, nil)
			continue
		end
		local far = not isLocal and (root.Position - camPos).Magnitude > VISIBLE_RANGE
		setVisible(c, not far, root)
		if far then
			continue
		end
		local footY = root.Position.Y - 3
		-- your own crew reacts to your tap instantly; others follow the server's choice
		local uid = if isLocal then Targeting.LocalTarget() else ((pl:GetAttribute("Target") :: number?) or 0)
		local ghost = if uid ~= 0 then Ghosts.Get(uid) else nil
		if ghost and (ghost.Pos - root.Position).Magnitude > Config.Combat.MaxRange * 1.5 then
			ghost = nil
		end
		if ghost then
			c.LastTarget = uid
		end
		local n = #c.Members
		local anyAttacking = false
		local rootLook = root.CFrame.LookVector
		local rootYaw = math.atan2(-rootLook.X, -rootLook.Z)
		local flatRoot = CFrame.new(root.Position) * CFrame.Angles(0, rootYaw, 0)
		local speedNow = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude

		for i, m in c.Members do
			local goal: Vector3
			local faceTo: Vector3? = nil
			local attackMode = false
			if m.CelebrateUntil > clock then
				goal = m.Pos
			elseif ghost then
				attackMode = true
				local gp = ghost.Pos
				local away = Vector3.new(root.Position.X - gp.X, 0, root.Position.Z - gp.Z)
				local base = if away.Magnitude > 0.1 then math.atan2(away.X, away.Z) else 0
				local spread = math.rad(math.min(160, 42 * (n - 1)))
				local a = base + (if n > 1 then -spread / 2 + spread * (i - 1) / (n - 1) else 0)
				local r = 3.2 + ghost.Def.Scale * 2.2
				goal = Vector3.new(gp.X + math.sin(a) * r, m.Pos.Y, gp.Z + math.cos(a) * r)
				faceTo = gp
			else
				local row = (i - 1) // 3
				local col = (i - 1) % 3
				local inRow = math.min(3, n - row * 3)
				local x = (col - (inRow - 1) / 2) * 3.2
				local z = 4.6 + row * 3.4
				goal = (flatRoot * CFrame.new(x, 0, z)).Position
			end
			-- move (XZ), teleport if hopelessly far
			local delta = Vector3.new(goal.X - m.Pos.X, 0, goal.Z - m.Pos.Z)
			local dist = delta.Magnitude
			if dist > 75 then
				m.Pos = Vector3.new(goal.X, footY, goal.Z)
				m.NextRay = 0
				dist = 0
			elseif dist > 0.05 then
				local speed = if attackMode then RUN_SPEED else math.max(14, speedNow * 1.15 + dist * 2)
				local stepLen = math.min(dist, speed * dt)
				m.Pos += delta.Unit * stepLen
			end
			-- ground snap (staggered raycasts)
			if clock >= m.NextRay then
				m.NextRay = clock + 0.18 + math.random() * 0.08
				local hit = workspace:Raycast(Vector3.new(m.Pos.X, root.Position.Y + 3, m.Pos.Z), Vector3.new(0, -20, 0), rayParams)
				m.GroundY = if hit then math.clamp(hit.Position.Y, footY - 10, footY + 4) else footY
			end
			local y = m.Pos.Y + (m.GroundY - m.Pos.Y) * math.min(1, dt * 14)
			m.Pos = Vector3.new(m.Pos.X, y, m.Pos.Z)

			-- facing
			local wantYaw = m.Yaw
			if faceTo and dist < 4 then
				local f = Vector3.new(faceTo.X - m.Pos.X, 0, faceTo.Z - m.Pos.Z)
				if f.Magnitude > 0.1 then
					wantYaw = math.atan2(-f.X, -f.Z)
				end
			elseif dist > 0.6 then
				wantYaw = math.atan2(-delta.X, -delta.Z)
			elseif not ghost then
				wantYaw = rootYaw
			end
			m.Yaw += angleDiff(m.Yaw, wantYaw) * math.min(1, dt * 12)

			-- state
			local state
			if m.CelebrateUntil > clock then
				state = "Celebrate"
			elseif attackMode and dist < 4 then
				state = "Attack"
			elseif dist > 0.6 then
				state = "Run"
			else
				state = "Idle"
			end
			m.State = state
			HunterRig.Pose(m.Rig, state, clock + m.Phase, 1)

			-- beam
			local beam = m.Beam
			if state == "Attack" and ghost then
				anyAttacking = true
				local att = centerAttachment(ghost)
				if beam.Attachment1 ~= att then
					beam.Attachment1 = att
				end
				beam.Enabled = true
				local w = math.sin(clock * 9 + m.Phase)
				beam.CurveSize0 = w * 1.6
				beam.CurveSize1 = -w * 1.1
				beam.Width0 = 0.3 + 0.12 * math.sin(clock * 22 + m.Phase)
				beam.Width1 = 0.7 + 0.25 * math.sin(clock * 17 + m.Phase)
			elseif beam.Enabled then
				beam.Enabled = false
			end

			table.insert(roots, m.Rig.Root)
			table.insert(cframes, CFrame.new(m.Pos) * CFrame.Angles(0, m.Yaw, 0))
		end

		-- impact sparks + soft zaps for your own crew only (keeps busy servers cheap)
		if isLocal and anyAttacking and ghost then
			if clock >= c.NextSpark then
				c.NextSpark = clock + 0.3
				local m = c.Members[math.random(1, n)]
				local off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * ghost.Def.Scale * 2
				Effects.Burst(ghost.Pos + off, { Color = m.Color, Count = 7, Size = 0.5, Speed = 9, Life = 0.4 })
			end
			if clock >= c.NextSound then
				c.NextSound = clock + 0.45
				Sound.Play("Attack", 0.15)
			end
		end
	end
	if #roots > 0 then
		workspace:BulkMoveTo(roots, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Crew.Init()
	folder = Instance.new("Folder")
	folder.Name = "GHCrews"
	folder.Parent = workspace
end

function Crew.Start()
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, pl in Players:GetPlayers() do
		addPlayer(pl)
	end
	-- victory pose when a ghost they were fighting poofs
	Ghosts.Died:Connect(function(uid: number)
		local until_ = os.clock() + 0.9
		for _, c in crews do
			if c.LastTarget == uid then
				for _, m in c.Members do
					if m.State == "Attack" then
						m.CelebrateUntil = until_
					end
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

-- Local crew members (for the crate reveal / tutorial).
function Crew.LocalCount(): number
	local c = crews[player]
	return if c then #c.Members else 0
end

return Crew
