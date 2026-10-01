--!strict
-- HUNTER INDEX: discovery tracking per zone ("HAUNTED NEIGHBORHOOD 3/4 DISCOVERED"),
-- overall completion %, silhouettes for unknown hunters, a 3D preview for known ones and a
-- NEW! indicator (menu badge + card sticker) for discoveries you haven't looked at yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Rules = require(GH.Logic.Rules)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Portrait = require(Client.UI.Portrait)
local Hud = require(script.Parent.Hud)
local CratePanel = require(script.Parent.CratePanel)

local IndexPanel = {}

local panel: Kit.Panel
local scroll: ScrollingFrame
local totalLabel: TextLabel
local totalFill: Frame
local detail: Frame
local detailView: Frame
local detailName: TextLabel
local detailInfo: TextLabel
local detailBlurb: TextLabel
local menuBadge: Frame
local newIds: { [string]: boolean } = {}
local spinConn: RBXScriptConnection? = nil
local lastKey = ""

local function hunterList(zoneId: string): { Config.HunterDef }
	local out = {}
	local crate = Config.Crates[(Config.ZoneById[zoneId] :: Config.ZoneDef).Crate]
	for _, e in crate.Pool do
		table.insert(out, Config.Hunters[e.Hunter])
	end
	return out
end

local function oddsOf(h: Config.HunterDef): number
	local zone = Config.ZoneById[h.Zone]
	local crate = Config.Crates[zone.Crate]
	local odds = Rules.Odds(crate.Pool :: any, function(id)
		return Config.Rarities[Config.Hunters[id].Rarity].Order
	end, 1, Config.LuckAffectsFromOrder)
	return odds[h.Id] or 0
end

local function showDetail(h: Config.HunterDef, found: boolean)
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	for _, c in detailView:GetChildren() do
		c:Destroy()
	end
	detail.Visible = true
	local rar = Config.Rarities[h.Rarity]
	local crate = Config.Crates[(Config.ZoneById[h.Zone] :: Config.ZoneDef).Crate]
	if found then
		local _, model = Portrait.Viewport(detailView, h.Id, false)
		if model then
			local t0 = os.clock()
			spinConn = RunService.RenderStepped:Connect(function()
				model:PivotTo(CFrame.Angles(0, (os.clock() - t0) * 0.9, 0))
			end)
		end
		detailName.Text = string.upper(h.Name)
		detailBlurb.Text = h.Blurb
	else
		Portrait.Viewport(detailView, h.Id, true)
		detailName.Text = "???"
		detailBlurb.Text = "Not discovered yet. Keep opening crates!"
	end
	detailName.TextColor3 = rar.Color
	detailInfo.Text = rar.Name .. "  •  ⚡ " .. (if found then Format.Commas(h.Power) else "?") .. "\n" .. crate.Name .. "  •  " .. Format.Percent(oddsOf(h))
end

local function rebuild()
	local d = State.Data
	if not d then
		return
	end
	local key = ""
	for _, z in Config.Zones do
		for _, h in hunterList(z.Id) do
			key ..= (if d.Discovered[h.Id] then "1" else "0") .. (if newIds[h.Id] then "n" else "")
		end
	end
	if key == lastKey then
		return
	end
	lastKey = key
	for _, c in scroll:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local total, found = 0, 0
	for zi, z in Config.Zones do
		local list = hunterList(z.Id)
		local zf = 0
		for _, h in list do
			if d.Discovered[h.Id] then
				zf += 1
			end
		end
		total += #list
		found += zf
		local section: Frame = Kit.new("Frame", {
			Size = UDim2.new(1, -8, 0, 214),
			BackgroundColor3 = Theme.Bg,
			BackgroundTransparency = 0.45,
			LayoutOrder = zi,
			ZIndex = 62,
			Parent = scroll,
		})
		Kit.Corner(section, UDim.new(0, 16))
		local unlocked = d.Zones[z.Id] == true
		Kit.Label(section, (if unlocked then "" else "🔒 ") .. z.Name, { Size = UDim2.new(0.6, 0, 0, 30), Position = UDim2.fromOffset(14, 8), Align = Enum.TextXAlignment.Left, Color = z.Accent, ZIndex = 63 })
		local complete = zf == #list
		Kit.Label(section, (if complete then "★ COMPLETE " else "") .. zf .. "/" .. #list .. " DISCOVERED", { Size = UDim2.new(0.38, 0, 0, 26), Position = UDim2.new(1, -14, 0, 10), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = if complete then Theme.Gold else Theme.Text, ZIndex = 63 })
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, -20, 0, 160), Position = UDim2.fromOffset(10, 46), BackgroundTransparency = 1, ZIndex = 62, Parent = section })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), Parent = row })
		for _, h in list do
			local rar = Config.Rarities[h.Rarity]
			local known = d.Discovered[h.Id] == true
			local card: TextButton = Kit.new("TextButton", {
				Size = UDim2.fromOffset(118, 156),
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 63,
				Parent = row,
			})
			Kit.Corner(card, UDim.new(0, 16))
			Kit.Stroke(card, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
			if known then
				Kit.Gradient(card, rar.Color, rar.Color2, 90)
			else
				Kit.Gradient(card, Color3.fromRGB(70, 60, 100), Color3.fromRGB(40, 32, 66), 90)
			end
			local pic: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(90, 90), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(30, 18, 55), BackgroundTransparency = 0.35, ZIndex = 64, Parent = card })
			Kit.Corner(pic, UDim.new(1, 0))
			Portrait.Face(pic, h.Id, not known)
			Kit.Label(card, if known then string.upper(h.Name) else "???", { Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 102), ZIndex = 66 })
			Kit.Label(card, rar.Name, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 126), ZIndex = 66, Color = if known then Color3.new(1, 1, 1) else rar.Color })
			if newIds[h.Id] then
				local stamp = Kit.Label(card, "NEW!", { Size = UDim2.fromOffset(64, 26), Position = UDim2.new(1, 8, 0, -8), AnchorPoint = Vector2.new(1, 0), Color = Theme.Ecto, ZIndex = 70, Stroke = 3 })
				stamp.Rotation = 12
			end
			card.Activated:Connect(function()
				Kit.Play("Click")
				if newIds[h.Id] then
					newIds[h.Id] = nil
					menuBadge.Visible = next(newIds) ~= nil
				end
				showDetail(h, known)
			end)
		end
	end
	local pct = if total > 0 then found / total else 0
	totalLabel.Text = "COLLECTION " .. found .. "/" .. total .. "  (" .. math.floor(pct * 100 + 0.5) .. "%)"
	Kit.Tween(totalFill, 0.4, { Size = UDim2.fromScale(math.max(pct, 0.02), 1) })
end

function IndexPanel.Init()
	panel = Kit.Panel("Index", "HUNTER INDEX", Vector2.new(920, 560), "Blue")
	local body = panel.Body
	local bar: Frame = Kit.new("Frame", { Size = UDim2.new(1, -310, 0, 40), Position = UDim2.fromOffset(0, 16), BackgroundColor3 = Theme.Bg, ZIndex = 62, Parent = body })
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	totalFill = Kit.new("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = bar })
	Kit.Corner(totalFill, UDim.new(1, 0))
	Kit.Gradient(totalFill, Theme.Ecto, Theme.Ecto2, 0)
	totalLabel = Kit.Label(bar, "COLLECTION", { Size = UDim2.fromScale(0.9, 0.72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 64 })
	scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, -300, 1, -76),
		Position = UDim2.fromOffset(0, 70),
		BackgroundTransparency = 1,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Theme.Panel3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 62,
		Parent = body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local side: Frame = Kit.new("Frame", { Size = UDim2.new(0, 284, 1, -30), Position = UDim2.new(1, 0, 0, 16), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.5, ZIndex = 62, Parent = body })
	Kit.Corner(side, UDim.new(0, 16))
	Kit.Label(side, "Tap a card to take a closer look!", { Size = UDim2.new(1, -30, 0, 60), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Muted, Font = Theme.Body, ZIndex = 63, Stroke = 0 })
	detail = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0, Visible = false, ZIndex = 64, Parent = side })
	Kit.Corner(detail, UDim.new(0, 16))
	detailView = Kit.new("Frame", { Size = UDim2.fromOffset(220, 230), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 65, Parent = detail })
	detailName = Kit.Label(detail, "", { Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 240), ZIndex = 66 })
	detailInfo = Kit.Label(detail, "", { Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 278), ZIndex = 66, Color = Theme.Text, Font = Theme.Body, Stroke = 0 })
	detailBlurb = Kit.Label(detail, "", { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 336), ZIndex = 66, Color = Theme.Muted, Font = Theme.Body, Stroke = 0 })
	-- NEW badge on the INDEX menu button
	menuBadge = Kit.new("Frame", {
		Size = UDim2.fromOffset(48, 24),
		Position = UDim2.new(1, 8, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Ecto,
		Visible = false,
		ZIndex = 10,
		Parent = Hud.Buttons.Index,
	})
	Kit.Corner(menuBadge, UDim.new(1, 0))
	Kit.Stroke(menuBadge, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Label(menuBadge, "NEW", { Size = UDim2.fromScale(0.85, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11 })
	Hud.RegisterPanel("Index", function()
		panel:Toggle()
	end)
end

function IndexPanel.Start()
	panel.OnOpen.Event:Connect(function()
		lastKey = ""
		detail.Visible = false
		rebuild()
	end)
	panel.OnClose.Event:Connect(function()
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		-- looked at the index: discoveries are no longer "new"
		table.clear(newIds)
		menuBadge.Visible = false
	end)
	State.Changed:Connect(function()
		if panel.IsOpen then
			rebuild()
		end
	end)
	CratePanel.Opened:Connect(function(res: any)
		if res.IsNew then
			newIds[res.Hunter] = true
			menuBadge.Visible = true
		end
	end)
end

return IndexPanel
