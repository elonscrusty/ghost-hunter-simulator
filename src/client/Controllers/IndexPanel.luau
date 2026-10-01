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
local bar: Frame
local side: Frame
local detail: ScrollingFrame
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
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Bg,
			BackgroundTransparency = 0.45,
			LayoutOrder = zi,
			ZIndex = 62,
			Parent = scroll,
		})
		Kit.Corner(section, UDim.new(0, 12))
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = section })
		Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = section })
		local unlocked = d.Zones[z.Id] == true
		local complete = zf == #list
		local header: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 62, Parent = section })
		Kit.Label(header, (if unlocked then "" else "🔒 ") .. z.Name, { Size = UDim2.new(0.6, 0, 1, 0), Align = Enum.TextXAlignment.Left, Color = z.Accent, Style = "Heading", Fit = true, ZIndex = 63 })
		Kit.Label(header, (if complete then "★ " else "") .. zf .. "/" .. #list .. " DISCOVERED", { Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Align = Enum.TextXAlignment.Right, Color = if complete then Theme.Gold else Theme.Text, Style = "Small", Fit = true, ZIndex = 63 })
		local row: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 62, Parent = section })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(100, 124), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for _, h in list do
			local rar = Config.Rarities[h.Rarity]
			local known = d.Discovered[h.Id] == true
			local card: TextButton = Kit.new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 63,
				Parent = row,
			})
			Kit.Corner(card, UDim.new(0, 12))
			Kit.Stroke(card, 2.5, Theme.Outline, Enum.ApplyStrokeMode.Border)
			if known then
				Kit.Gradient(card, rar.Color, rar.Color2, 90)
			else
				Kit.Gradient(card, Color3.fromRGB(70, 60, 100), Color3.fromRGB(40, 32, 66), 90)
			end
			local pic: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(30, 18, 55), BackgroundTransparency = 0.35, ZIndex = 64, Parent = card })
			Kit.Corner(pic, UDim.new(1, 0))
			Portrait.Face(pic, h.Id, not known)
			Kit.Label(card, if known then string.upper(h.Name) else "???", { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 80), ZIndex = 66, Style = "Small", Fit = true })
			Kit.Label(card, rar.Name, { Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 100), ZIndex = 66, Color = if known then Color3.new(1, 1, 1) else rar.Color, Style = "Tiny", Fit = true })
			if newIds[h.Id] then
				local stamp = Kit.Label(card, "NEW!", { Size = UDim2.fromOffset(46, 18), Position = UDim2.new(1, 6, 0, -6), AnchorPoint = Vector2.new(1, 0), Color = Theme.Ecto, Style = "Body", ZIndex = 70, Stroke = 2 })
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
	panel = Kit.Panel("Index", "HUNTER INDEX", Vector2.new(860, 500), "Blue")
	local body = panel.Body
	bar = Kit.new("Frame", { Size = UDim2.new(1, -270, 0, 28), Position = UDim2.fromOffset(0, 12), BackgroundColor3 = Theme.Bg, ZIndex = 62, Parent = body })
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	totalFill = Kit.new("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = bar })
	Kit.Corner(totalFill, UDim.new(1, 0))
	Kit.Gradient(totalFill, Theme.Ecto, Theme.Ecto2, 0)
	totalLabel = Kit.Label(bar, "COLLECTION", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), Style = "Body", Fit = true, ZIndex = 64 })
	scroll = Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Panel3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		BorderSizePixel = 0,
		ZIndex = 62,
		Parent = body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	side = Kit.new("Frame", { Position = UDim2.new(1, 0, 0, 12), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.5, ZIndex = 62, Parent = body })
	Kit.Corner(side, UDim.new(0, 12))
	Kit.Label(side, "Tap a card to take a closer look!", { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Muted, Font = Theme.Body, Style = "Small", ZIndex = 63, Stroke = 0 })
	detail = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		ZIndex = 64,
		Parent = side,
	})
	Kit.Corner(detail, UDim.new(0, 12))
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = detail })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = detail })
	detailView = Kit.new("Frame", { Size = UDim2.fromOffset(160, 160), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 65, Parent = detail })
	detailName = Kit.Label(detail, "", { Size = UDim2.new(1, 0, 0, 22), Style = "Heading", Fit = true, ZIndex = 66 })
	detailName.LayoutOrder = 2
	detailInfo = Kit.Label(detail, "", { Size = UDim2.new(1, 0, 0, 0), ZIndex = 66, Color = Theme.Text, Font = Theme.Body, Style = "Small", Stroke = 0 })
	detailInfo.AutomaticSize = Enum.AutomaticSize.Y
	detailInfo.LayoutOrder = 3
	detailBlurb = Kit.Label(detail, "", { Size = UDim2.new(1, 0, 0, 0), ZIndex = 66, Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0 })
	detailBlurb.AutomaticSize = Enum.AutomaticSize.Y
	detailBlurb.LayoutOrder = 4
	-- NEW badge on the INDEX menu button
	menuBadge = Kit.new("Frame", {
		Size = UDim2.fromOffset(36, 18),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Ecto,
		Visible = false,
		ZIndex = 10,
		Parent = Hud.Buttons.Index,
	})
	Kit.Corner(menuBadge, UDim.new(1, 0))
	Kit.Stroke(menuBadge, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Label(menuBadge, "NEW", { Style = "Tiny", ZIndex = 11 })
	Hud.RegisterPanel("Index", function()
		panel:Toggle()
	end)
end

-- Side pane takes ~30% of the panel's actual width; sections wrap their cards.
local function layout()
	local w = panel.Root.Size.X.Offset - 28
	local sideW = math.clamp(math.floor(w * 0.3), 190, 250)
	bar.Size = UDim2.new(1, -(sideW + 10), 0, 28)
	scroll.Size = UDim2.new(1, -(sideW + 10), 1, -50)
	side.Size = UDim2.new(0, sideW, 1, -12)
end

function IndexPanel.Start()
	panel.OnOpen:Connect(function()
		layout()
		lastKey = ""
		detail.Visible = false
		rebuild()
	end)
	Kit.ScaleChanged:Connect(function()
		if panel.IsOpen then
			layout()
		end
	end)
	panel.OnClose:Connect(function()
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
