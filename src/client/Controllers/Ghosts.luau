--!strict
-- Client-side ghost presentation: smooth movement along the server's wander segments,
-- bobbing, facing, Spirit billboards, hit wobble and the POOF. One RenderStepped loop
-- for all ghosts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local Ghosts = {}

export type Entry = {
	Uid: number,
	Model: Model,
	Core: BasePart,
	Def: Config.GhostDef,
	From: Vector3,
	To: Vector3,
	T0: number,
	Dur: number,
	Phase: number,
	Max: number,
	Spirit: number,
	Fill: Frame,
	SpiritText: TextLabel,
	HitT: number,
	Yaw: number,
	Dying: boolean,
	Pos: Vector3,
	Gui: BillboardGui,
}

local entries: { [number]: Entry } = {}
local player = Players.LocalPlayer
local diedSignal = Instance.new("BindableEvent")
Ghosts.Died = diedSignal.Event -- (uid, pos)
local addedSignal = Instance.new("BindableEvent")
Ghosts.Added = addedSignal.Event -- (entry)

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

local function buildBillboard(e: Entry)
	local def = e.Def
	local big = def.Kind ~= "Normal"
	local scale = if def.Kind == "Event" then 2.2 elseif big then 1.35 else 1
	local gui: BillboardGui = Kit.new("BillboardGui", {
		Name = "SpiritGui",
		Size = UDim2.fromOffset(220 * scale, 70 * scale),
		StudsOffsetWorldSpace = Vector3.new(0, 2.2 * def.Scale + 1.5, 0),
		AlwaysOnTop = false,
		MaxDistance = if def.Kind == "Event" then 400 else 110,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Adornee = e.Core,
		Parent = e.Model,
	})
	local nameText = def.Name
	if def.Kind == "MiniBoss" then
		nameText = "⭐ " .. nameText
	elseif def.Kind == "Boss" or def.Kind == "Event" then
		nameText = "👑 " .. nameText
	end
	Kit.Label(gui, nameText, { Size = UDim2.fromScale(1, 0.38), Color = if big then Theme.Gold else Theme.Text, Stroke = 2 })
	local bar: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(0.86, 0.3),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(30, 15, 50),
		Parent = gui,
	})
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local fill: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
	Kit.Corner(fill, UDim.new(1, 0))
	Kit.Gradient(fill, def.Glow, Color3.fromRGB(180, 120, 255), 0)
	local txt = Kit.Label(bar, "", { Size = UDim2.fromScale(0.95, 0.85), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
	Kit.Label(gui, "SPIRIT", { Size = UDim2.fromScale(0.4, 0.22), Position = UDim2.fromScale(0.5, 0.75), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.Muted, ZIndex = 2 })
	e.Fill = fill
	e.SpiritText = txt
	e.Gui = gui
end

local function updateSpirit(e: Entry, spirit: number)
	local old = e.Spirit
	e.Spirit = spirit
	local frac = if e.Max > 0 then math.clamp(spirit / e.Max, 0, 1) else 0
	TweenService:Create(e.Fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(frac, 1) }):Play()
	e.SpiritText.Text = Format.Short(spirit) .. " / " .. Format.Short(e.Max)
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
	if not def or not core or not core:IsA("BasePart") then
		return
	end
	local e: Entry = {
		Uid = uid,
		Model = model,
		Core = core,
		Def = def,
		From = core.Position,
		To = core.Position,
		T0 = 0,
		Dur = 0,
		Phase = math.random() * math.pi * 2,
		Max = (model:GetAttribute("MaxSpirit") :: number?) or def.Spirit,
		Spirit = (model:GetAttribute("Spirit") :: number?) or def.Spirit,
		Fill = nil :: any,
		SpiritText = nil :: any,
		HitT = 0,
		Yaw = math.random() * math.pi * 2,
		Dying = false,
		Pos = core.Position,
		Gui = nil :: any,
	}
	readSegment(e)
	buildBillboard(e)
	updateSpirit(e, e.Spirit)
	entries[uid] = e
	model:GetAttributeChangedSignal("T0"):Connect(function()
		readSegment(e)
	end)
	model:GetAttributeChangedSignal("Spirit"):Connect(function()
		updateSpirit(e, (model:GetAttribute("Spirit") :: number?) or 0)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			entries[uid] = nil
		end
	end)
	-- spawn-in: grow from nothing (the event boss has its own dramatic entrance)
	if e.Def.Kind ~= "Event" then
		local s = Instance.new("NumberValue")
		s.Value = 0.2
		e.Model:ScaleTo(e.Def.Scale * 0.2)
		local conn
		conn = s.Changed:Connect(function(v)
			if e.Dying or not e.Model.Parent then
				conn:Disconnect()
				return
			end
			e.Model:ScaleTo(e.Def.Scale * v)
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
		diedSignal:Fire(data.Uid, pos)
		e.Gui.Enabled = false
		-- squash-and-stretch pop: inflate, then vanish
		local model = e.Model
		local v = Instance.new("NumberValue")
		v.Value = 1
		v.Changed:Connect(function(x)
			if model.Parent then
				model:ScaleTo(math.max(0.05, e.Def.Scale * x))
			end
		end)
		local up = TweenService:Create(v, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1.35 })
		up:Play()
		up.Completed:Connect(function()
			if near then
				Effects.Poof(pos, color, scale, data.Big == true)
			end
			for _, p in model:GetDescendants() do
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
		if data.Escaped then
			Sound.Play("Poof")
		else
			Sound.Play(if data.Big then "BigPoof" else "Poof", 0.08)
		end
	end
end

local function step()
	local t = workspace:GetServerTimeNow()
	local clock = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
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
		table.insert(parts, e.Core)
		table.insert(cframes, CFrame.new(pos) * CFrame.Angles(0, e.Yaw, 0) * CFrame.Angles(-lean, 0, sway))
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Ghosts.Init() end

function Ghosts.Start()
	local folder = workspace:WaitForChild("Ghosts")
	folder.ChildAdded:Connect(function(m)
		task.defer(add, m)
	end)
	for _, m in folder:GetChildren() do
		add(m)
	end
	Net.Event("Fx").OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Poof" then
			poof(data)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return Ghosts
