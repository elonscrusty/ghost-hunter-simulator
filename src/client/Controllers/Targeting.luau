--!strict
-- Ghost selection. PC: click a ghost. Mobile: tap a ghost. Console: ButtonX (or F on a
-- keyboard) targets the ghost nearest the centre of the screen and cycles on repeat presses.
-- The selection is optimistic (instant highlight + sound) and then follows the server's
-- authoritative "Target" attribute.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Net = require(GH.Net)
local Client = script.Parent.Parent
local Kit = require(Client.UI.Kit)
local State = require(Client.State)
local Ghosts = require(script.Parent.Ghosts)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)

local Targeting = {}

local player = Players.LocalPlayer
local selectRemote: RemoteEvent
local selectHL: Highlight
local hoverHL: Highlight
local pending: number? = nil
local pendingAt = 0
local blocked = false
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local selectedSignal = Instance.new("BindableEvent")
Targeting.Selected = selectedSignal.Event -- (uid) fired on a local selection

function Targeting.SetBlocked(on: boolean)
	blocked = on
end

function Targeting.Current(): number
	return (player:GetAttribute("Target") :: number?) or 0
end

local function showHighlight(uid: number)
	local e = if uid ~= 0 then Ghosts.Get(uid) else nil
	if e then
		selectHL.Adornee = e.Model
		selectHL.OutlineColor = e.Def.Glow
		selectHL.FillColor = e.Def.Glow
		selectHL.Enabled = true
	else
		selectHL.Adornee = nil
		selectHL.Enabled = false
	end
end

local function rootPos(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

function Targeting.Select(uid: number)
	if blocked then
		return
	end
	local e = Ghosts.Get(uid)
	if not e then
		return
	end
	local zone = Config.ZoneById[e.Def.Zone]
	local d = State.Data
	if d and zone and not d.Zones[zone.Id] then
		Kit.Toast("Unlock " .. zone.Name .. " first!", "Bad")
		return
	end
	local p = rootPos()
	if p and (e.Pos - p).Magnitude > Config.Combat.MaxRange + 10 then
		Kit.Toast("Get closer to that ghost!", "Bad")
		return
	end
	pending = uid
	pendingAt = os.clock()
	showHighlight(uid)
	Sound.Play("Select")
	Effects.Ring(e.Pos, e.Def.Glow, 4 * e.Def.Scale, 0.35)
	if Targeting.Current() ~= uid then
		selectRemote:FireServer(uid)
	end
	selectedSignal:Fire(uid)
end

-- `pos` is in GUI coordinates (InputObject.Position, TouchTap) unless `viewport` is true
-- (GetMouseLocation); the matching camera functions keep the top-bar inset consistent.
local function ghostAtScreen(pos: Vector2, viewport: boolean?): Ghosts.Entry?
	local cam = workspace.CurrentCamera
	local folder = workspace:FindFirstChild("Ghosts")
	if not cam or not folder then
		return nil
	end
	rayParams.FilterDescendantsInstances = { folder }
	local ray = if viewport then cam:ViewportPointToRay(pos.X, pos.Y) else cam:ScreenPointToRay(pos.X, pos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
	if hit then
		return Ghosts.FromInstance(hit.Instance)
	end
	-- forgiving fallback for small/fast ghosts: nearest ghost centre within 60 px of the tap
	local best, bestD = nil, 60
	for _, e in Ghosts.All() do
		local sp, onScreen
		if viewport then
			sp, onScreen = cam:WorldToViewportPoint(e.Pos)
		else
			sp, onScreen = cam:WorldToScreenPoint(e.Pos)
		end
		if onScreen then
			local dist = (Vector2.new(sp.X, sp.Y) - pos).Magnitude
			if dist < bestD then
				best, bestD = e, dist
			end
		end
	end
	return best
end

-- Console / keyboard: pick the ghost closest to screen centre (within range), cycling.
local function cycleTarget()
	local cam = workspace.CurrentCamera
	local p = rootPos()
	if not cam or not p then
		return
	end
	local list = {}
	for uid, e in Ghosts.All() do
		if (e.Pos - p).Magnitude <= Config.Combat.MaxRange then
			local sp, onScreen = cam:WorldToViewportPoint(e.Pos)
			if onScreen then
				local c = cam.ViewportSize / 2
				table.insert(list, { Uid = uid, Score = (Vector2.new(sp.X, sp.Y) - c).Magnitude })
			end
		end
	end
	if #list == 0 then
		Kit.Toast("No ghosts nearby!", "Bad")
		return
	end
	table.sort(list, function(a, b)
		return a.Score < b.Score
	end)
	local cur = pending or Targeting.Current()
	local idx = 1
	for i, item in list do
		if item.Uid == cur then
			idx = (i % #list) + 1
			break
		end
	end
	Targeting.Select(list[idx].Uid)
end

function Targeting.Init()
	selectHL = Instance.new("Highlight")
	selectHL.Name = "GHSelect"
	selectHL.FillTransparency = 0.75
	selectHL.OutlineTransparency = 0
	selectHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	selectHL.Enabled = false
	selectHL.Parent = workspace
	hoverHL = Instance.new("Highlight")
	hoverHL.Name = "GHHover"
	hoverHL.FillTransparency = 1
	hoverHL.OutlineColor = Color3.new(1, 1, 1)
	hoverHL.OutlineTransparency = 0.3
	hoverHL.DepthMode = Enum.HighlightDepthMode.Occluded
	hoverHL.Enabled = false
	hoverHL.Parent = workspace
end

function Targeting.Start()
	selectRemote = Net.Event("SelectTarget")

	-- Mouse click (PC). Taps use TouchTap so camera drags never select by accident.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or blocked then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local e = ghostAtScreen(Vector2.new(input.Position.X, input.Position.Y))
			if e then
				Targeting.Select(e.Uid)
			end
		end
	end)
	UserInputService.TouchTap:Connect(function(positions, processed)
		if processed or blocked or #positions == 0 then
			return
		end
		local e = ghostAtScreen(positions[1])
		if e then
			Targeting.Select(e.Uid)
		end
	end)
	ContextActionService:BindAction("GHTarget", function(_, state)
		if state == Enum.UserInputState.Begin and not blocked then
			cycleTarget()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonX, Enum.KeyCode.F)

	-- authoritative target from the server
	player:GetAttributeChangedSignal("Target"):Connect(function()
		local uid = Targeting.Current()
		pending = nil
		showHighlight(uid)
	end)
	Ghosts.Died:Connect(function(uid)
		if selectHL.Adornee and Targeting.Current() == uid then
			showHighlight(0)
		end
	end)

	-- hover outline (mouse only) + reconcile a rejected optimistic selection
	RunService.RenderStepped:Connect(function()
		if pending and os.clock() - pendingAt > 0.8 then
			pending = nil
			showHighlight(Targeting.Current())
		end
		if not UserInputService.MouseEnabled or blocked then
			hoverHL.Enabled = false
			return
		end
		local m = UserInputService:GetMouseLocation()
		local e = ghostAtScreen(m, true)
		if e and e.Model ~= selectHL.Adornee then
			hoverHL.Adornee = e.Model
			hoverHL.Enabled = true
		else
			hoverHL.Enabled = false
		end
	end)
end

return Targeting
