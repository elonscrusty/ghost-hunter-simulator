--!strict
-- World liveliness + interactions:
--  * per-zone lighting blend (ambient + fog colour) as you walk between areas
--  * floating books/pumpkins (FloatingProp), flickering lights (FlickerLight), spinning
--    display crates (SpinProp) - one loop, only props near the camera are animated
--  * gates: open locally for zones you own, the NEW AREA UNLOCKED! sequence, sign text
--  * station prompts open the right panel
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Hud = require(script.Parent.Hud)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local CratePanel = require(script.Parent.CratePanel)
local GatePanel = require(script.Parent.GatePanel)
local Reveal = require(script.Parent.Reveal)

local Ambience = {}

local player = Players.LocalPlayer
local zoneRanges: { { number } } = {}
for _, z in Config.Zones do
	table.insert(zoneRanges, { z.MinZ, z.MaxZ })
end
local currentZone = 0
local unlocking: { [string]: boolean } = {}

type Prop = { Part: BasePart, Base: CFrame, Phase: number, Bob: number, Kind: string }
local props: { [BasePart]: Prop } = {}

local function addProp(inst: Instance, kind: string)
	if not inst:IsA("BasePart") or props[inst] then
		return
	end
	local bob = inst:GetAttribute("BobHeight")
	props[inst] = {
		Part = inst,
		Base = inst.CFrame,
		Phase = math.random() * 10,
		Bob = if type(bob) == "number" then bob else 0.6,
		Kind = kind,
	}
end

local flickers: { BasePart } = {}

local function blendZone(idx: number)
	local z = Config.Zones[idx]
	if not z then
		return
	end
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { Ambient = z.Ambient, OutdoorAmbient = z.Ambient:Lerp(Color3.new(1, 1, 1), 0.15) }):Play()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, info, { Color = z.FogColor, Decay = z.FogColor:Lerp(Color3.new(0, 0, 0), 0.35) }):Play()
	end
end

-- Gate sign cost row (World/Gates): the lock icon + price while locked, "✅ UNLOCKED" (whole
-- row, icon hidden) once owned. Without the icon (no image id) the text carries the 🔒.
local function setCost(cost: TextLabel, owned: boolean, price: number)
	local icon = cost.Parent and cost.Parent:FindFirstChild("CostIcon") :: GuiObject?
	if not cost:GetAttribute("BasePos") then
		cost:SetAttribute("BasePos", true)
		cost:SetAttribute("PosX", cost.Position.X.Scale)
		cost:SetAttribute("SizeX", cost.Size.X.Scale)
	end
	if icon then
		icon.Visible = not owned
		local x, w = cost:GetAttribute("PosX") :: number, cost:GetAttribute("SizeX") :: number
		cost.Position = UDim2.new(if owned then 0.08 else x, 0, cost.Position.Y.Scale, cost.Position.Y.Offset)
		cost.Size = UDim2.new(if owned then 0.84 else w, 0, cost.Size.Y.Scale, cost.Size.Y.Offset)
	end
	cost.Text = if owned then "✅ UNLOCKED" else (if icon then "" else "🔒 ") .. Format.Short(price) .. " ECTOPLASM"
end

local function gateParts(zoneId: string): (BasePart?, TextLabel?, ProximityPrompt?)
	local map = workspace:FindFirstChild("Map")
	local gates = map and map:FindFirstChild("Gates")
	local gate = gates and gates:FindFirstChild("Gate_" .. zoneId)
	if not gate then
		return nil, nil, nil
	end
	local barrier = gate:FindFirstChild("Barrier") :: BasePart?
	local sign = gate:FindFirstChild("Sign")
	local sg = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local cost = sg and sg:FindFirstChild("CostLabel", true) :: TextLabel?
	local anchor = gate:FindFirstChild("PromptAnchor")
	local prompt = anchor and anchor:FindFirstChildOfClass("ProximityPrompt")
	return barrier, cost, prompt
end

local barrierOriginal: { [BasePart]: { Size: Vector3, CFrame: CFrame, Transparency: number } } = {}

local function applyGates()
	local d = State.Data
	if not d then
		return
	end
	for _, z in Config.Zones do
		if not Config.Layout.Gates[z.Id] or unlocking[z.Id] then
			continue
		end
		local barrier, cost, prompt = gateParts(z.Id)
		local owned = d.Zones[z.Id] == true
		if barrier then
			if not barrierOriginal[barrier] then
				barrierOriginal[barrier] = { Size = barrier.Size, CFrame = barrier.CFrame, Transparency = barrier.Transparency }
			end
			local o = barrierOriginal[barrier]
			barrier.CanCollide = not owned
			barrier.Transparency = if owned then 1 else o.Transparency
			if not owned then
				barrier.Size = o.Size
				barrier.CFrame = o.CFrame
			end
		end
		if cost then
			setCost(cost, owned, z.Cost)
		end
		if prompt then
			prompt.Enabled = not owned
		end
	end
end

local function unlockSequence(zoneId: string)
	local zone = Config.ZoneById[zoneId]
	if not zone then
		return
	end
	unlocking[zoneId] = true
	local barrier, cost, prompt = gateParts(zoneId)
	Sound.Play("ZoneUnlock")
	Hud.Banner("NEW AREA UNLOCKED!", zone.Name .. "  ·  NEW GHOSTS  ·  NEW CRATE", zone.Accent)
	if prompt then
		prompt.Enabled = false
	end
	if cost then
		setCost(cost, true, zone.Cost)
	end
	-- camera emphasis: quick punch-in + shake
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = 58
		TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Back), { FieldOfView = 70 }):Play()
	end
	if barrier then
		barrier.CanCollide = false
		local cf = barrier.CFrame
		local size = barrier.Size
		barrier.Color = Color3.new(1, 1, 1)
		TweenService:Create(barrier, TweenInfo.new(0.25), { Color = zone.Accent }):Play()
		for i = -2, 2 do
			local p = cf.Position + cf.RightVector * (i * size.X / 5) + Vector3.new(0, -size.Y / 2 + 4, 0)
			Effects.Burst(p, { Color = zone.Accent, Color2 = Color3.new(1, 1, 1), Count = 30, Size = 1.4, Speed = 24, Life = 1 })
		end
		Effects.Ring(cf.Position - Vector3.new(0, size.Y / 2 - 0.3, 0), zone.Accent, 30, 0.9)
		task.wait(0.3)
		-- the force field drains into the ground
		TweenService:Create(barrier, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(size.X, 0.2, size.Z),
			CFrame = cf - Vector3.new(0, size.Y / 2, 0),
			Transparency = 1,
		}):Play()
		task.wait(1.2)
	end
	unlocking[zoneId] = nil
	applyGates()
end

local stepParts: { BasePart } = {}
local stepCfs: { CFrame } = {}

local function step()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	table.clear(stepParts)
	table.clear(stepCfs)
	local parts, cfs = stepParts, stepCfs
	for part, p in props do
		if (p.Base.Position - camPos).Magnitude > 160 then
			continue
		end
		local cf
		if p.Kind == "Spin" then
			cf = p.Base * CFrame.new(0, math.sin(t * 1.8 + p.Phase) * 0.4, 0) * CFrame.Angles(0, t * 0.9, 0)
		else
			cf = p.Base * CFrame.new(0, math.sin(t * 1.4 + p.Phase) * p.Bob, 0) * CFrame.Angles(math.sin(t * 0.9 + p.Phase) * 0.12, t * 0.35 + p.Phase, math.cos(t * 0.7 + p.Phase) * 0.1)
		end
		table.insert(parts, part)
		table.insert(cfs, cf)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Ambience.Init() end

function Ambience.Start()
	for _, inst in CollectionService:GetTagged("FloatingProp") do
		addProp(inst, "Float")
	end
	CollectionService:GetInstanceAddedSignal("FloatingProp"):Connect(function(inst)
		addProp(inst, "Float")
	end)
	for _, inst in CollectionService:GetTagged("SpinProp") do
		addProp(inst, "Spin")
	end
	CollectionService:GetInstanceAddedSignal("SpinProp"):Connect(function(inst)
		addProp(inst, "Spin")
	end)
	for _, inst in CollectionService:GetTagged("FlickerLight") do
		if inst:IsA("BasePart") then
			table.insert(flickers, inst)
		end
	end
	-- flicker: every so often one light stutters
	task.spawn(function()
		while true do
			task.wait(0.15 + math.random() * 0.35)
			if #flickers > 0 then
				local part = flickers[math.random(1, #flickers)]
				local light = part:FindFirstChildWhichIsA("Light")
				if light then
					local base = part:GetAttribute("BaseTransparency")
					if type(base) ~= "number" then
						base = part.Transparency
						part:SetAttribute("BaseTransparency", base)
					end
					local n = math.random(1, 3)
					for _ = 1, n do
						light.Enabled = false
						part.Transparency = math.max(base :: number, 0.6)
						task.wait(0.04 + math.random() * 0.08)
						light.Enabled = true
						part.Transparency = base :: number
						task.wait(0.03 + math.random() * 0.06)
					end
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(step)

	-- zone blend
	task.spawn(function()
		while true do
			task.wait(0.5)
			local cam = workspace.CurrentCamera
			if cam and not Reveal.IsPlaying() then
				local idx = Rules.ZoneIndexAt(cam.Focus.Position.Z, zoneRanges)
				if idx ~= currentZone then
					currentZone = idx
					blendZone(idx)
				end
			end
		end
	end)

	-- gates
	State.OnData(function()
		applyGates()
	end)
	State.OnFx("ZoneUnlocked", function(data: any)
		if type(data) == "table" and type(data.Zone) == "string" then
			unlockSequence(data.Zone)
		end
	end)

	-- prompts → panels
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player or Reveal.IsPlaying() then
			return
		end
		local crate = prompt:GetAttribute("Crate")
		local station = prompt:GetAttribute("Station")
		local zone = prompt:GetAttribute("Zone")
		if type(crate) == "string" then
			CratePanel.Open(crate)
		elseif station == "Upgrades" then
			Hud.Open("Upgrades")
		elseif type(zone) == "string" then
			GatePanel.Open(zone)
		end
	end)
	-- keep prompts out of the way while a menu is open
	Kit.PanelOpened:Connect(function(name)
		ProximityPromptService.Enabled = name == nil
	end)
end

return Ambience
