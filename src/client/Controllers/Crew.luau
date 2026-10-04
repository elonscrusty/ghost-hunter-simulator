--!strict
-- Draws every player's equipped Ghost Hunters (client-side, never collide with anything).
-- Idle: follow in a formation behind their player. Assigned (player's "Target" attribute):
-- run to a ring around the ghost, aim and fire a wobbly energy beam, celebrate on the poof,
-- then come back. All crews update in ONE RenderStepped loop: BulkMoveTo for roots, Motor6D
-- transforms for poses, staggered ground raycasts, and far-away crews are hidden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local HunterRig = require(GH.Rigs.HunterRig)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local State = require(Client.State)
local Theme = require(Client.UI.Theme)
local WorldLabel = require(Client.UI.WorldLabel)
local Ghosts = require(script.Parent.Ghosts)
local Targeting = require(script.Parent.Targeting)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local Crew = {}

type Member = {
	Id: string,
	Uid: string,
	Tier: number,
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
	-- HP bar over the tag (own crew: big, plus a short alert line like "DODGED"; others: small)
	HpGui: BillboardGui,
	HpFill: Frame,
	Hp: number,
	Alert: TextLabel?,
	AlertUntil: number,
	Chest: Attachment?, -- end point of incoming ghost bolts (own crew, made on first hit)
	Mark: Highlight?, -- red outline while a ghost winds up on this hunter
	MarkUntil: number,
}

-- An own equipped hunter that is knocked out: a faded rig behind the player with a countdown.
type KO = {
	Uid: string,
	Rig: HunterRig.Rig,
	Pos: Vector3,
	Label: TextLabel,
}

type CrewData = {
	Player: Player,
	Members: { Member },
	Visible: boolean,
	LastTarget: number,
	NextSpark: number,
	NextSound: number,
	Fighting: boolean,
	Conns: { RBXScriptConnection },
}

local player = Players.LocalPlayer
local crews: { [Player]: CrewData } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local nextFilter = 0
local gone: { [string]: Vector3 } = {} -- last spot of local rigs removed by the latest rebuild (knockout poof)
local kos: { KO } = {}

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
		AlwaysOnTop = true, -- never cut by walls / the hunter's own body
	})
	local tier = Config.Tiers[m.Tier]
	local text = (if tier and tier.Icon ~= "" then tier.Icon .. " " else "") .. string.rep("⭐", math.min(rar.Order, 5)) .. " " .. def.Name
	WorldLabel.Text(gui, text, { Style = "Tiny", Color = rar.Color })
	-- HP bar: its own label at the tag's anchor point, drawn in the upper part so it always
	-- sits just above the name. Own crew: readable at play distance; others: small and close only.
	local hpGui = WorldLabel.New({
		Name = "Hp",
		Adornee = m.Rig.Root,
		Parent = m.Rig.Model,
		Size = if isLocal then Vector2.new(84, 64) else Vector2.new(44, 40),
		Offset = Vector3.new(0, m.Rig.Height + 0.7, 0),
		MaxDistance = if isLocal then 70 else 35,
		AlwaysOnTop = true,
	})
	hpGui.Enabled = false
	local bar: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, if isLocal then 0.16 else 0.12),
		Position = UDim2.fromScale(0, 0.3),
		BackgroundColor3 = Color3.fromRGB(30, 15, 50),
		Parent = hpGui,
	})
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, if isLocal then 1.5 else 1, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local fill: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Ecto, Parent = bar })
	Kit.Corner(fill, UDim.new(1, 0))
	m.HpGui = hpGui
	m.HpFill = fill
	if isLocal then
		m.Alert = WorldLabel.Text(hpGui, "", { Style = "Small", Color = Theme.Bad, Size = UDim2.fromScale(1, 0.28) })
	end
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

local function newMember(id: string, tier: number, uid: string, at: Vector3, isLocal: boolean): Member
	local rig = HunterRig.Build(id)
	HunterRig.ApplyTier(rig.Model, tier) -- Shiny / Mega finish (same look as inventory + index)
	local scale = if tier >= 2 then HUNTER_SCALE * 1.2 else HUNTER_SCALE
	rig.Model:ScaleTo(scale)
	rig.Height *= scale
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
		Uid = uid,
		Tier = tier,
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
		HpGui = nil :: any,
		HpFill = nil :: any,
		Hp = 100,
		AlertUntil = 0,
		MarkUntil = 0,
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

-- green (full) -> gold (half) -> red (empty)
local function hpColor(pct: number): Color3
	local f = math.clamp(pct / 100, 0, 1)
	return if f > 0.5 then Theme.Gold:Lerp(Theme.Ecto, (f - 0.5) * 2) else Theme.Bad:Lerp(Theme.Gold, f * 2)
end

-- Reads each rig's HP from "uid=pct,uid=pct" (the bar itself is shown/hidden in step).
local function applyHP(c: CrewData)
	local hp: { [string]: number } = {}
	local raw = c.Player:GetAttribute("CrewHP")
	if type(raw) == "string" then
		for uid, pct in raw:gmatch("([^,=]+)=(%d+)") do
			hp[uid] = tonumber(pct) or 100
		end
	end
	for _, m in c.Members do
		local pct = math.clamp(hp[m.Uid] or 100, 0, 100)
		m.Hp = pct
		m.HpFill.Size = UDim2.fromScale(pct / 100, 1)
		m.HpFill.BackgroundColor3 = hpColor(pct)
	end
end

-- "Crew" is "HunterId|tier|uid,..." (old "HunterId,..." still works); rigs are kept per uid.
local function rebuild(c: CrewData)
	local raw = c.Player:GetAttribute("Crew")
	local root = rootOf(c.Player)
	local at = if root then root.Position - Vector3.new(0, 3, 0) else Vector3.zero
	local isLocal = c.Player == player
	local old: { [string]: Member } = {}
	for _, m in c.Members do
		old[m.Uid] = m
	end
	local members: { Member } = {}
	if type(raw) == "string" then
		for item in raw:gmatch("[^,]+") do
			local p = item:split("|")
			local id = p[1]
			if Config.Hunters[id] and #members < 12 then
				local i = #members + 1
				local tier = tonumber(p[2]) or 0
				local uid = p[3] or (id .. "#" .. i)
				local m = old[uid]
				old[uid] = nil
				if not m or m.Id ~= id or m.Tier ~= tier then
					local spawnAt = if m then m.Pos else at + Vector3.new((i - 2.5) * 2, 0, 3)
					if m then
						m.Rig.Model:Destroy()
					elseif isLocal and os.clock() > 3 then
						Effects.Burst(spawnAt + Vector3.new(0, 2, 0), { Color = Config.Rarities[Config.Hunters[id].Rarity].Color, Count = 14, Size = 0.7, Speed = 10 })
					end
					m = newMember(id, tier, uid, spawnAt, isLocal)
				end
				members[i] = m :: Member
			end
		end
	end
	if isLocal then
		table.clear(gone)
	end
	for uid, m in old do
		if isLocal then
			gone[uid] = m.Pos
		end
		m.Rig.Model:Destroy()
	end
	c.Members = members
	if not c.Visible then
		for _, m in c.Members do
			m.Rig.Model.Parent = nil
		end
	end
	applyHP(c)
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
		Fighting = false,
		Conns = {},
	}
	crews[pl] = c
	table.insert(c.Conns, pl:GetAttributeChangedSignal("Crew"):Connect(function()
		rebuild(c)
	end))
	table.insert(c.Conns, pl:GetAttributeChangedSignal("CrewHP"):Connect(function()
		applyHP(c)
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
				-- RAINBOW BEAMS pass (cosmetic): hue cycles along the beam
				if pl:GetAttribute("RainbowBeams") == true then
					local h = (clock * 0.35 + m.Phase * 0.1) % 1
					beam.Color = ColorSequence.new(Color3.fromHSV(h, 0.75, 1), Color3.fromHSV((h + 0.35) % 1, 0.75, 1))
				end
			elseif beam.Enabled then
				beam.Enabled = false
			end

			-- HP bar: while hurt, while the own crew fights, or while an alert line shows
			local alertOn = m.AlertUntil > clock
			local show = m.Hp < 100 or (isLocal and c.Fighting) or alertOn
			if m.HpGui.Enabled ~= show then
				m.HpGui.Enabled = show
			end
			local a = m.Alert
			if a and not alertOn and a.Text ~= "" then
				a.Text = ""
			end

			table.insert(roots, m.Rig.Root)
			table.insert(cframes, CFrame.new(m.Pos) * CFrame.Angles(0, m.Yaw, 0))
		end
		c.Fighting = anyAttacking

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
	-- knocked-out own hunters drift along in a row behind the crew
	local lroot = rootOf(player)
	if lroot and #kos > 0 then
		local c = crews[player]
		local rows = math.ceil((if c then #c.Members else 0) / 3)
		local look = lroot.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local flat = CFrame.new(lroot.Position) * CFrame.Angles(0, yaw, 0)
		local k = math.min(1, dt * 6)
		for i, ko in kos do
			local col = (i - 1) % 3
			local row = (i - 1) // 3
			local goal = (flat * CFrame.new((col - 1) * 3.2, -2.7, 4.6 + (rows + row) * 3.4)).Position
			ko.Pos = if (goal - ko.Pos).Magnitude > 60 then goal else ko.Pos:Lerp(goal, k)
			table.insert(roots, ko.Rig.Root)
			table.insert(cframes, CFrame.new(ko.Pos) * CFrame.Angles(0, yaw, 0))
		end
	end
	if #roots > 0 then
		workspace:BulkMoveTo(roots, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local KO_TINT = Color3.fromRGB(170, 175, 200)

local function newKO(uid: string, id: string, tier: number, at: Vector3): KO
	local rig = HunterRig.Build(id)
	local scale = if tier >= 2 then HUNTER_SCALE * 1.2 else HUNTER_SCALE
	rig.Model:ScaleTo(scale)
	rig.Height *= scale
	for _, p in rig.Model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = p.Color:Lerp(KO_TINT, 0.75)
			p.Transparency = math.max(p.Transparency, 0.6)
		elseif p:IsA("Light") or p:IsA("ParticleEmitter") then
			p:Destroy()
		end
	end
	rig.Model:PivotTo(CFrame.new(at))
	rig.Model.Parent = folder
	local gui = WorldLabel.New({
		Name = "KO",
		Adornee = rig.Root,
		Parent = rig.Model,
		Size = Vector2.new(80, 22),
		Offset = Vector3.new(0, rig.Height + 0.7, 0),
		MaxDistance = 70,
		AlwaysOnTop = true,
	})
	return { Uid = uid, Rig = rig, Pos = at, Label = WorldLabel.Text(gui, "", { Style = "Small", Color = Color3.fromRGB(200, 205, 230) }) }
end

-- Keeps one faded rig per equipped hunter whose knockout hasn't ended; updates the countdowns.
local function syncKnocked()
	local d = State.Data
	local now = State.Now()
	local want: { [string]: number } = {}
	if d and d.Equipped and d.Knocked then
		for _, uid in d.Equipped do
			local t = d.Knocked[uid]
			local h = d.Hunters and d.Hunters[uid]
			if type(t) == "number" and t > now and h and Config.Hunters[h.Id] then
				want[uid] = t
			end
		end
	end
	for i = #kos, 1, -1 do
		local ko = kos[i]
		if not want[ko.Uid] then
			ko.Rig.Model:Destroy()
			table.remove(kos, i)
		end
	end
	for uid, t in want do
		local label: TextLabel? = nil
		for _, k in kos do
			if k.Uid == uid then
				label = k.Label
				break
			end
		end
		if not label then
			local root = rootOf(player)
			local at = gone[uid] or (if root then root.Position - Vector3.new(0, 2.7, -6) else Vector3.zero)
			local h = d.Hunters[uid]
			local ko = newKO(uid, h.Id, tonumber(h.Tier) or 0, at)
			table.insert(kos, ko)
			label = ko.Label
		end
		(label :: TextLabel).Text = "💤 " .. Format.Time(t - now)
	end
end

-- Ghost -> hunter bolt: a few reused beams from the ghost's core to the hit hunter's chest
-- (or, if the rig is already gone after a knockout, to where it stood). Shrinks out in 0.35 s.
type Bolt = { Beam: Beam, End: Attachment, Token: number }
local bolts: { Bolt } = {}
local boltNext = 0
local BOLT_RED = Color3.fromRGB(255, 60, 110)

local function bolt(e: Ghosts.Entry, target: Attachment?, at: Vector3)
	boltNext = boltNext % 3 + 1
	local b = bolts[boltNext]
	if not b then
		local endAtt = Instance.new("Attachment")
		endAtt.Name = "GhostBoltEnd"
		endAtt.Parent = workspace.Terrain
		local beam = Instance.new("Beam")
		beam.Name = "GhostBolt"
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 10
		beam.Transparency = NumberSequence.new(0.05, 0.25)
		beam.Enabled = false
		beam.Parent = folder
		b = { Beam = beam, End = endAtt, Token = 0 }
		bolts[boltNext] = b
	end
	local beam = b.Beam
	if target then
		beam.Attachment1 = target
	else
		b.End.WorldPosition = at
		beam.Attachment1 = b.End
	end
	beam.Attachment0 = centerAttachment(e)
	beam.Color = ColorSequence.new(e.Def.Glow, BOLT_RED)
	beam.CurveSize0 = (math.random() - 0.5) * 4
	beam.CurveSize1 = (math.random() - 0.5) * 3
	beam.Width0 = 1
	beam.Width1 = 0.55
	beam.Enabled = true
	TweenService:Create(beam, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 }):Play()
	b.Token += 1
	local token = b.Token
	task.delay(0.36, function()
		if b.Token == token then
			beam.Enabled = false
		end
	end)
end

local function chestOf(m: Member): Attachment
	local a = m.Chest
	if not a then
		local made = Instance.new("Attachment")
		made.Name = "Chest"
		made.Position = Vector3.new(0, m.Rig.Height * 0.55, 0)
		made.Parent = m.Rig.Root
		m.Chest = made
		return made
	end
	return a
end

local function localMember(uid: any): Member?
	local c = crews[player]
	if c then
		for _, m in c.Members do
			if m.Uid == uid then
				return m
			end
		end
	end
	return nil
end

-- Short line over an own rig's HP bar ("DODGED"); step clears it when the time is up.
local function flash(m: Member, text: string, color: Color3, t: number)
	local a = m.Alert
	if not a then
		return
	end
	a.Text = text
	a.TextColor3 = color
	m.AlertUntil = os.clock() + t
end

-- Calm red outline on the targeted hunter during a windup (one reused Highlight per rig).
local function mark(m: Member, t: number)
	local hl = m.Mark
	if not hl then
		local made = Instance.new("Highlight")
		made.FillTransparency = 1
		made.OutlineColor = Theme.Bad
		made.OutlineTransparency = 0.1
		made.Parent = m.Rig.Model
		m.Mark = made
		hl = made
	end
	local h = hl :: Highlight
	h.Enabled = t > 0
	m.MarkUntil = os.clock() + t
	if t > 0 then
		task.delay(t + 0.05, function()
			if os.clock() >= m.MarkUntil then
				h.Enabled = false
			end
		end)
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
	-- v1.6 retaliation (Fx only reaches the attacked player): telegraph, dodge, knockout poof
	State.OnFx("GhostWindup", function(d: any)
		local m = localMember(d.Hunter)
		if not m then
			return
		end
		-- the ❗ + ring sit on the ghost (Ghosts.luau); the hunter only gets a quiet outline
		mark(m, tonumber(d.Time) or 0.9)
	end)
	State.OnFx("GhostHit", function(d: any)
		local m = localMember(d.Hunter)
		if m then
			mark(m, 0)
		end
		if d.Dodged then
			if m then
				flash(m, "DODGED", Theme.Ecto, 0.8)
			end
			return
		end
		local e = Ghosts.Get(d.Ghost)
		local pos = if m then m.Pos else gone[d.Hunter]
		if e and not e.Dying and pos then
			bolt(e, if m then chestOf(m) else nil, pos + Vector3.new(0, 2, 0))
		end
		if m and not d.Knocked then
			Effects.Burst(m.Pos + Vector3.new(0, 2, 0), { Color = Theme.Bad, Count = 8, Size = 0.5, Speed = 8, Life = 0.4 })
		end
	end)
	-- knocked-out rigs + countdowns: resync on every snapshot and once a second
	State.Changed:Connect(syncKnocked)
	task.spawn(function()
		while true do
			syncKnocked()
			task.wait(1)
		end
	end)
	State.OnFx("Knocked", function(d: any)
		local m = localMember(d.Uid)
		local pos = if m then m.Pos else gone[d.Uid]
		if pos then
			Effects.Poof(pos + Vector3.new(0, 2, 0), Color3.fromRGB(200, 200, 215), 0.6, false)
		end
	end)
end

-- Local crew members (for the crate reveal / tutorial).
function Crew.LocalCount(): number
	local c = crews[player]
	return if c then #c.Members else 0
end

return Crew
