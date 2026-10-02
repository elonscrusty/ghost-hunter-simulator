--!strict
-- Client-side ghost presentation. The server sends each ghost as a single invisible hitbox
-- (`Core`, the tap target) plus attributes; this module builds the visual rig locally
-- (GhostRig), moves both along the server's wander segments, and handles bobbing, facing,
-- Spirit labels, the selected-ghost state (active label + ground ring), hit wobble, spawn-in
-- and the POOF. One RenderStepped loop for all ghosts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Signal = require(GH.Signal)
local Format = require(GH.Logic.Format)
local GhostRig = require(GH.Rigs.GhostRig)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local State = require(Client.State)
local Theme = require(Client.UI.Theme)
local WorldLabel = require(Client.UI.WorldLabel)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local Ghosts = {}

export type Entry = {
	Uid: number,
	Model: Model, -- server model (hitbox)
	Core: BasePart, -- server hitbox (tap target, beam attachments)
	Vis: Model, -- local visual rig
	VisCore: BasePart,
	Def: Config.GhostDef,
	From: Vector3,
	To: Vector3,
	T0: number,
	Dur: number,
	Phase: number,
	Max: number,
	Spirit: number,
	Gui: BillboardGui,
	NameLabel: TextLabel,
	Bar: Frame,
	Fill: Frame,
	SpiritText: TextLabel,
	HitT: number,
	Yaw: number,
	Dying: boolean,
	Pos: Vector3, -- visual centre this frame
	Base: Vector3, -- centre without bob (for the ground ring)
	Selected: boolean,
}

local entries: { [number]: Entry } = {}
local player = Players.LocalPlayer
local diedSignal = Signal.new()
Ghosts.Died = diedSignal -- (uid, pos)
local addedSignal = Signal.new()
Ghosts.Added = addedSignal -- (entry)
local selectedUid = 0
local ring: Part
local ringStroke: UIStroke

function Ghosts.Get(uid: number): Entry?
	return entries[uid]
end

function Ghosts.All(): { [number]: Entry }
	return entries
end

-- Finds the ghost entry owning an instance (for tap targeting).
function Ghosts.FromInstance(inst: Instance?): Entry?
	local cur = inst
	while cur and cur ~= workspace do
		if cur:IsA("Model") then
			local uid = cur:GetAttribute("Uid")
			if type(uid) == "number" and entries[uid] then
				return entries[uid]
			end
		end
		cur = cur.Parent
	end
	return nil
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function labelSize(e: Entry): Vector2
	return if e.Selected then Theme.World.GhostLabelSelected else Theme.World.GhostLabel
end

local function maxDistance(e: Entry): number
	if e.Selected then
		return Theme.World.SelectedMaxDistance
	end
	return if e.Def.Kind == "Normal" then Theme.World.GhostMaxDistance else Theme.World.BossMaxDistance
end

-- Unselected: name + slim bar. Selected: bigger bar with numbers, brighter, visible further,
-- drawn on top so you never lose your target.
local function styleLabel(e: Entry)
	WorldLabel.Resize(e.Gui, labelSize(e))
	e.Gui.MaxDistance = maxDistance(e)
	e.Gui.AlwaysOnTop = e.Selected
	e.SpiritText.Visible = e.Selected
	e.Bar.Size = UDim2.fromScale(0.9, if e.Selected then 0.5 else 0.3)
	local st = e.Bar:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = if e.Selected then Color3.new(1, 1, 1) else Theme.Outline
		st.Thickness = if e.Selected then 2 else 1.5
	end
	e.NameLabel.TextColor3 = if e.Selected then Theme.Gold elseif e.Def.Kind ~= "Normal" then Color3.fromRGB(255, 230, 150) else Theme.Text
end

local function buildLabel(e: Entry)
	local def = e.Def
	-- above the head: hitbox top + a little, scaled with the ghost
	local gui = WorldLabel.New({
		Name = "SpiritGui",
		Adornee = e.Core,
		Parent = e.Model,
		Size = Theme.World.GhostLabel,
		Offset = Vector3.new(0, 2.6 * def.Scale + 0.8, 0),
		MaxDistance = Theme.World.GhostMaxDistance,
	})
	local nameText = def.Name
	if def.Kind == "MiniBoss" then
		nameText = "⭐ " .. nameText
	elseif def.Kind == "Boss" or def.Kind == "Event" then
		nameText = "👑 " .. nameText
	end
	e.NameLabel = WorldLabel.Text(gui, nameText, { Size = UDim2.fromScale(1, 0.48), Style = "Small" })
	local bar: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(0.9, 0.3),
		Position = UDim2.fromScale(0.5, 0.56),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(30, 15, 50),
		Parent = gui,
	})
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 1.5, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local fill: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
	Kit.Corner(fill, UDim.new(1, 0))
	Kit.Gradient(fill, def.Glow, Color3.fromRGB(180, 120, 255), 0)
	e.SpiritText = WorldLabel.Text(bar, "", { Style = "Tiny", ZIndex = 3 })
	e.SpiritText.Visible = false
	e.Bar = bar
	e.Fill = fill
	e.Gui = gui
end

local function updateSpirit(e: Entry, spirit: number)
	local old = e.Spirit
	e.Spirit = spirit
	local frac = if e.Max > 0 then math.clamp(spirit / e.Max, 0, 1) else 0
	TweenService:Create(e.Fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(frac, 1) }):Play()
	e.SpiritText.Text = Format.Short(spirit) .. " / " .. Format.Short(e.Max) .. " SPIRIT"
	if spirit < old then
		e.HitT = os.clock()
	end
end

local function readSegment(e: Entry)
	local m = e.Model
	local from = m:GetAttribute("From")
	local to = m:GetAttribute("To")
	e.From = if typeof(from) == "Vector3" then from else e.Pos
	e.To = if typeof(to) == "Vector3" then to else e.From
	e.T0 = (m:GetAttribute("T0") :: number?) or 0
	e.Dur = (m:GetAttribute("Dur") :: number?) or 0
end

-- Selected ghost: active label + soft ground ring (set by Targeting).
function Ghosts.SetSelected(uid: number)
	if uid == selectedUid then
		return
	end
	local old = entries[selectedUid]
	if old then
		old.Selected = false
		styleLabel(old)
	end
	selectedUid = uid
	local e = entries[uid]
	if e then
		e.Selected = true
		styleLabel(e)
		local d = math.max(4, 2.8 * e.Def.Scale + 1.5)
		ring.Size = Vector3.new(d, 0.1, d)
		ringStroke.Color = e.Def.Glow
	else
		ring.CFrame = CFrame.new(0, -500, 0)
	end
end

local function add(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local uid = model:GetAttribute("Uid")
	local ghostId = model:GetAttribute("GhostId")
	if type(uid) ~= "number" or type(ghostId) ~= "string" or entries[uid] then
		return
	end
	local def = Config.Ghosts[ghostId]
	local core = model.PrimaryPart or model:WaitForChild("Core", 5)
	if not def or not core or not core:IsA("BasePart") or model:GetAttribute("Dead") then
		return
	end
	local vis = GhostRig.Build(ghostId)
	vis.Name = "Visual"
	local visCore = vis.PrimaryPart :: BasePart
	visCore.CanQuery = false -- the server hitbox is the tap target
	vis:PivotTo(core.CFrame)
	vis.Parent = model
	local e: Entry = {
		Uid = uid,
		Model = model,
		Core = core,
		Vis = vis,
		VisCore = visCore,
		Def = def,
		From = core.Position,
		To = core.Position,
		T0 = 0,
		Dur = 0,
		Phase = math.random() * math.pi * 2,
		Max = (model:GetAttribute("MaxSpirit") :: number?) or def.Spirit,
		Spirit = (model:GetAttribute("Spirit") :: number?) or def.Spirit,
		Gui = nil :: any,
		NameLabel = nil :: any,
		Bar = nil :: any,
		Fill = nil :: any,
		SpiritText = nil :: any,
		HitT = 0,
		Yaw = math.random() * math.pi * 2,
		Dying = false,
		Pos = core.Position,
		Base = core.Position,
		Selected = false,
	}
	readSegment(e)
	buildLabel(e)
	updateSpirit(e, e.Spirit)
	entries[uid] = e
	if uid == selectedUid then
		selectedUid = 0
		Ghosts.SetSelected(uid)
	end
	model:GetAttributeChangedSignal("T0"):Connect(function()
		-- From/To/T0/Dur are set together; read them once they have all arrived
		task.defer(readSegment, e)
	end)
	model:GetAttributeChangedSignal("Spirit"):Connect(function()
		updateSpirit(e, (model:GetAttribute("Spirit") :: number?) or 0)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) and entries[uid] == e then
			entries[uid] = nil
		end
	end)
	-- spawn-in: grow from nothing (the event boss gets its own dramatic entrance)
	if def.Kind ~= "Event" then
		local s = Instance.new("NumberValue")
		s.Value = 0.2
		vis:ScaleTo(def.Scale * 0.2)
		local conn
		conn = s.Changed:Connect(function(v)
			if e.Dying or not vis.Parent then
				conn:Disconnect()
				return
			end
			vis:ScaleTo(def.Scale * v)
		end)
		local tw = TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Value = 1 })
		tw:Play()
		tw.Completed:Connect(function()
			conn:Disconnect()
			s:Destroy()
		end)
	end
	addedSignal:Fire(e)
end

local function poof(data: any)
	local e = entries[data.Uid]
	local pos: Vector3 = data.Pos
	local color: Color3 = data.Color
	local scale: number = data.Scale or 1
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = root == nil or (root.Position - pos).Magnitude < 160
	if e then
		e.Dying = true
		pos = e.Pos
		entries[data.Uid] = nil
		if selectedUid == data.Uid then
			selectedUid = 0
			ring.CFrame = CFrame.new(0, -500, 0)
		end
		diedSignal:Fire(data.Uid, pos)
		e.Gui.Enabled = false
		-- squash-and-stretch pop: inflate, then vanish
		local vis = e.Vis
		local v = Instance.new("NumberValue")
		v.Value = 1
		v.Changed:Connect(function(x)
			if vis.Parent then
				vis:ScaleTo(math.max(0.05, e.Def.Scale * x))
			end
		end)
		local up = TweenService:Create(v, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1.35 })
		up:Play()
		up.Completed:Connect(function()
			if near then
				Effects.Poof(pos, color, scale, data.Big == true)
			end
			for _, p in vis:GetDescendants() do
				if p:IsA("BasePart") then
					p.Transparency = 1
				elseif p:IsA("ParticleEmitter") then
					p.Enabled = false
				elseif p:IsA("Light") then
					p.Enabled = false
				end
			end
			v:Destroy()
		end)
	elseif near then
		Effects.Poof(pos, color, scale, data.Big == true)
	end
	if near then
		Sound.Play(if data.Big then "BigPoof" else "Poof", 0.08)
	end
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}

local function step()
	local t = workspace:GetServerTimeNow()
	local clock = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	table.clear(parts)
	table.clear(cframes)
	for _, e in entries do
		if e.Dying then
			continue
		end
		local a = if e.Dur > 0 then math.clamp((t - e.T0) / e.Dur, 0, 1) else 1
		local base = e.From:Lerp(e.To, smooth(a))
		local s = e.Def.Scale
		local bob = math.sin(clock * 2.2 + e.Phase) * 0.45 * math.sqrt(s)
		local pos = base + Vector3.new(0, bob, 0)
		-- hit shake
		local since = clock - e.HitT
		if since < 0.15 then
			local k = (0.15 - since) / 0.15
			pos += Vector3.new(math.sin(clock * 90) * 0.25 * k * s, 0, math.cos(clock * 80) * 0.2 * k * s)
		end
		-- face the camera horizontally (cute + readable), with a gentle sway
		local dx, dz = camPos.X - pos.X, camPos.Z - pos.Z
		if dx * dx + dz * dz > 1 then
			local target = math.atan2(-dx, -dz)
			local diff = (target - e.Yaw + math.pi) % (2 * math.pi) - math.pi
			e.Yaw += diff * 0.08
		end
		local sway = math.sin(clock * 1.7 + e.Phase) * 0.12
		local moving = a < 1 and (e.To - e.From).Magnitude > 0.5
		local lean = if moving then 0.12 else 0
		e.Pos = pos
		e.Base = base
		local cf = CFrame.new(pos) * CFrame.Angles(0, e.Yaw, 0) * CFrame.Angles(-lean, 0, sway)
		table.insert(parts, e.Core)
		table.insert(cframes, CFrame.new(pos))
		table.insert(parts, e.VisCore)
		table.insert(cframes, cf)
	end
	-- ground ring under the selected ghost
	local sel = entries[selectedUid]
	if sel and not sel.Dying then
		local groundY = sel.Base.Y - sel.Def.Hover + 0.15
		table.insert(parts, ring)
		table.insert(cframes, CFrame.new(sel.Base.X, groundY, sel.Base.Z) * CFrame.Angles(0, clock * 0.8, 0))
		ringStroke.Transparency = 0.25 + 0.2 * math.sin(clock * 4)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Ghosts.Init()
	ring = Instance.new("Part")
	ring.Name = "TargetRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Size = Vector3.new(6, 0.1, 6)
	ring.CFrame = CFrame.new(0, -500, 0)
	ring.Parent = workspace
	local sg: SurfaceGui = Kit.new("SurfaceGui", {
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 24,
		LightInfluence = 0,
		Brightness = 1.5,
		Parent = ring,
	})
	local circle: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = sg })
	Kit.Corner(circle, UDim.new(1, 0))
	ringStroke = Kit.new("UIStroke", { Thickness = 7, Color = Theme.Ecto, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = circle })
	-- dashed look: a second, inner faint circle
	local inner: Frame = Kit.new("Frame", { Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = circle })
	Kit.Corner(inner, UDim.new(1, 0))
	Kit.new("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = inner })
end

function Ghosts.Start()
	local folder = workspace:WaitForChild("Ghosts")
	folder.ChildAdded:Connect(function(m)
		task.defer(add, m)
	end)
	for _, m in folder:GetChildren() do
		task.spawn(add, m)
	end
	State.OnFx("Poof", poof)
	RunService.RenderStepped:Connect(step)
end

return Ghosts
