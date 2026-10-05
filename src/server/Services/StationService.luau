--!strict
-- Dresses the stations the world builder made: crate display models, odds boards and
-- ProximityPrompts (crates, upgrades, gates). Prompts only open client UI; every purchase
-- goes through validated Requests.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local CrateRig = require(GH.Rigs.CrateRig)

local StationService = {}

local function find(path: { string }): Instance?
	local cur: Instance? = workspace
	for _, name in path do
		cur = cur and cur:FindFirstChild(name)
	end
	return cur
end

local function prompt(parent: Instance, action: string, object: string, attrs: { [string]: any }): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "GHPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonY
	p.Style = Enum.ProximityPromptStyle.Default
	for k, v in attrs do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, font: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.Font = font or Enum.Font.FredokaOne
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(25, 10, 45)
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function rarityOrder(id: string): number
	local h = Config.Hunters[id]
	return if h then Config.Rarities[h.Rarity].Order else 1
end

local function buildOddsBoard(board: BasePart, crate: Config.CrateDef)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Odds"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.15
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(35, 20, 60)
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(70, 40, 120), Color3.fromRGB(25, 15, 45))
	grad.Rotation = 90
	grad.Parent = bg
	label(bg, crate.Name, UDim2.fromScale(0.94, 0.13), UDim2.fromScale(0.03, 0.03), crate.Trim)
	label(bg, Format.Short(crate.Price) .. " ECTOPLASM", UDim2.fromScale(0.8, 0.09), UDim2.fromScale(0.1, 0.17), Color3.fromRGB(150, 255, 150))
	local odds = Rules.Odds(crate.Pool :: any, rarityOrder, 1, Config.LuckAffectsFromOrder)
	for i, e in crate.Pool do
		local def = Config.Hunters[e.Hunter]
		local rar = Config.Rarities[def.Rarity]
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(0.92, 0.155)
		row.Position = UDim2.fromScale(0.04, 0.29 + (i - 1) * 0.175)
		row.BackgroundColor3 = rar.Color
		row.BackgroundTransparency = 0.15
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = row
		local g2 = Instance.new("UIGradient")
		g2.Color = ColorSequence.new(rar.Color, rar.Color2)
		g2.Parent = row
		row.Parent = bg
		label(row, string.upper(def.Name), UDim2.fromScale(0.55, 0.55), UDim2.fromScale(0.03, 0.05), Color3.new(1, 1, 1))
		label(row, rar.Name .. "  ·  ⚡" .. Format.Short(def.Power), UDim2.fromScale(0.55, 0.38), UDim2.fromScale(0.03, 0.58), Color3.fromRGB(255, 255, 230))
		label(row, Format.Percent(odds[e.Hunter]), UDim2.fromScale(0.35, 0.8), UDim2.fromScale(0.62, 0.1), Color3.new(1, 1, 1))
	end
	gui.Parent = board
end

function StationService.Init() end

function StationService.Start()
	for crateId, crate in Config.Crates do
		if not Config.Layout.CrateStations[crateId] then
			continue -- no station (Exclusive Crate is Robux-only)
		end
		local station = find({ "Map", "Stations", "CrateStation_" .. crateId })
		if not station then
			warn("[Stations] missing CrateStation_" .. crateId)
			continue
		end
		local slot = station:FindFirstChild("DisplaySlot") :: BasePart?
		if slot then
			local rig = CrateRig.Build(crateId)
			rig.Model.Name = "DisplayCrate"
			rig.Model:ScaleTo(1.3)
			rig.Model:PivotTo(CFrame.new(slot.Position - Vector3.new(0, 1.6, 0)))
			rig.Model.Parent = station
			CollectionService:AddTag(rig.Base, "SpinProp")
		end
		local board = station:FindFirstChild("OddsBoard") :: BasePart?
		if board then
			buildOddsBoard(board, crate)
		end
		local anchor = station:FindFirstChild("PromptAnchor")
		if anchor then
			prompt(anchor, "Open Crate", crate.Name .. " · " .. Format.Short(crate.Price), { Crate = crateId })
		end
	end
	local up = find({ "Map", "Stations", "UpgradeStation", "PromptAnchor" })
	if up then
		prompt(up, "Upgrades", "Upgrade Station", { Station = "Upgrades" })
	end
	-- zone gates, plus the World 2 portal (Map.Portals.Gate_<zone>), which sells its zone the same way
	for _, zone in Config.Zones do
		local anchor = find({ "Map", "Gates", "Gate_" .. zone.Id, "PromptAnchor" }) or find({ "Map", "Portals", "Gate_" .. zone.Id, "PromptAnchor" })
		if anchor then
			prompt(anchor, "Unlock", zone.Name .. " · " .. Format.Short(zone.Cost), { Zone = zone.Id })
		end
	end
end

return StationService
