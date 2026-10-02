--!strict
-- HUNTERS inventory: grid of cards (portrait, name, rarity, Capture Power, equipped/locked
-- badges), an inspect pane with a 3D preview, EQUIP / UNEQUIP / EQUIP BEST / LOCK / RELEASE,
-- sort by power or rarity, and a release mode with "select weak" for clearing storage.
-- Cards are cached per hunter uid, so data updates only touch what changed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Portrait = require(Client.UI.Portrait)
local Hud = require(script.Parent.Hud)

local HuntersPanel = {}

type Card = {
	Frame: TextButton,
	Equip: Frame,
	Lock: TextLabel,
	Select: Frame,
}

local panel: Kit.Panel
local grid: ScrollingFrame
local cards: { [string]: Card } = {}
local equippedLabel: TextLabel
local powerLabel: TextLabel
local storageLabel: TextLabel
local sortButton: TextButton
local releaseButton: TextButton
local equipBestButton: TextButton
local top: Frame
local actionsRow: Frame
local side: Frame
-- inspect pane
local inspect: ScrollingFrame
local viewHolder: Frame
local nameLabel: TextLabel
local rarityLabel: TextLabel
local rarityRibbon: Frame
local statLabel: TextLabel
local blurbLabel: TextLabel
local equipButton: TextButton
local lockButton: TextButton
local relOneButton: TextButton
local emptyHint: TextLabel
-- release mode
local releaseBar: Frame
local releaseConfirm: TextButton
local releaseMode = false
local selected: { [string]: boolean } = {}
local inspectUid: string? = nil
local sortMode = "Power"
local spinModel: Model? = nil
local spinConn: RBXScriptConnection? = nil

local function powerOf(id: string): number
	local h = Config.Hunters[id]
	return if h then h.Power else 0
end

local function rarityOf(id: string): Config.RarityDef
	return Config.Rarities[Config.Hunters[id].Rarity]
end

local function crateRefund(id: string): number
	local def = Config.Hunters[id]
	local zone = Config.ZoneById[def.Zone]
	local crate = zone and Config.Crates[zone.Crate]
	return if crate then math.floor(crate.Price * Config.Inventory.ReleaseRefund) else 0
end

local function sortedUids(d: any): { string }
	local uids = {}
	for uid in d.Hunters do
		table.insert(uids, uid)
	end
	local eq: { [string]: boolean } = {}
	for _, uid in d.Equipped do
		eq[uid] = true
	end
	table.sort(uids, function(a, b)
		if eq[a] ~= eq[b] then
			return eq[a] == true
		end
		local ha, hb = d.Hunters[a].Id, d.Hunters[b].Id
		local pa, pb = powerOf(ha), powerOf(hb)
		local ra, rb = rarityOf(ha).Order, rarityOf(hb).Order
		if sortMode == "Rarity" and ra ~= rb then
			return ra > rb
		end
		if pa ~= pb then
			return pa > pb
		end
		if ra ~= rb then
			return ra > rb
		end
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	return uids
end

local previewUid: string? = nil

local function clearPreview()
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	for _, c in viewHolder:GetChildren() do
		if c:IsA("ViewportFrame") then
			c:Destroy()
		end
	end
	spinModel = nil
	previewUid = nil
end

local function setInspect(uid: string?)
	inspectUid = uid
	local d = State.Data
	local h = uid and d and d.Hunters[uid]
	inspect.Visible = h ~= nil and not releaseMode
	emptyHint.Visible = not inspect.Visible and not releaseMode
	if not h or not d or not uid then
		clearPreview()
		return
	end
	local def = Config.Hunters[h.Id]
	local rar = rarityOf(h.Id)
	-- the 3D preview is only rebuilt when you pick a different hunter (not on every update)
	if previewUid ~= uid then
		clearPreview()
		previewUid = uid
		local _, model = Portrait.Viewport(viewHolder, h.Id, false)
		spinModel = model
		if model then
			local t0 = os.clock()
			spinConn = RunService.RenderStepped:Connect(function()
				if spinModel then
					spinModel:PivotTo(CFrame.Angles(0, math.sin((os.clock() - t0) * 0.8) * 0.6, 0))
				end
			end)
		end
	end
	nameLabel.Text = string.upper(def.Name)
	rarityLabel.Text = rar.Name
	local g = rarityRibbon:FindFirstChildOfClass("UIGradient") :: UIGradient
	g.Color = ColorSequence.new(rar.Color, rar.Color2)
	statLabel.Text = "⚡ " .. Format.Commas(def.Power) .. " CAPTURE POWER"
	blurbLabel.Text = def.Blurb
	local isEq = table.find(d.Equipped, uid) ~= nil
	Kit.SetButtonText(equipButton, if isEq then "UNEQUIP" else "EQUIP")
	equipButton:SetAttribute("Color", if isEq then "Red" else "Green")
	Kit.SetButtonText(lockButton, if h.Locked then "🔓 UNLOCK" else "🔒 LOCK")
	relOneButton.Visible = not isEq and not h.Locked
	Kit.SetButtonText(relOneButton, "RELEASE +" .. Format.Short(crateRefund(h.Id)))
end

local function updateReleaseBar()
	local d = State.Data
	local n, refund = 0, 0
	if d then
		for uid in selected do
			local h = d.Hunters[uid]
			if h then
				n += 1
				refund += crateRefund(h.Id)
			else
				selected[uid] = nil
			end
		end
	end
	Kit.SetButtonText(releaseConfirm, "RELEASE " .. n .. "  (+💚" .. Format.Short(refund) .. ")")
	releaseConfirm:SetAttribute("Color", if n > 0 then "Red" else "Gray")
end

local function makeCard(uid: string, hunterId: string): Card
	local def = Config.Hunters[hunterId]
	local rar = rarityOf(hunterId)
	local f: TextButton = Kit.new("TextButton", {
		Name = uid,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 63,
		Parent = grid,
	})
	Kit.Corner(f, UDim.new(0, 16))
	Kit.Stroke(f, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(f, rar.Color, rar.Color2, 90)
	if rar.Order >= 5 then
		-- legendary cards shimmer
		local shine: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, ZIndex = 63, Parent = f })
		Kit.Corner(shine, UDim.new(0, 16))
		local sg = Kit.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }),
			Rotation = 25,
			Parent = shine,
		})
		task.spawn(function()
			while shine.Parent do
				sg.Offset = Vector2.new(-1, 0)
				Kit.Tween(sg, 1.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Linear)
				task.wait(2.4)
			end
		end)
	end
	local pic: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(70, 70),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(30, 18, 55),
		BackgroundTransparency = 0.35,
		ZIndex = 64,
		Parent = f,
	})
	Kit.Corner(pic, UDim.new(1, 0))
	Portrait.Face(pic, hunterId, false)
	Kit.Label(f, string.upper(def.Name), { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 80), ZIndex = 66, Style = "Small", Fit = true })
	Kit.Label(f, "⚡" .. Format.Short(def.Power), { Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 98), ZIndex = 66, Color = Theme.Gold, Style = "Body", Fit = true })
	local eqBadge: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(-5, -5),
		BackgroundColor3 = Theme.Good,
		Visible = false,
		ZIndex = 68,
		Parent = f,
	})
	Kit.Corner(eqBadge, UDim.new(1, 0))
	Kit.Stroke(eqBadge, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Label(eqBadge, "✓", { Style = "Body", ZIndex = 69 })
	local lock = Kit.Label(f, "🔒", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, 2, 0, -3), AnchorPoint = Vector2.new(1, 0), ZIndex = 68, Stroke = 0, Style = "Small" })
	lock.Visible = false
	local sel: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Bad, BackgroundTransparency = 0.45, Visible = false, ZIndex = 70, Parent = f })
	Kit.Corner(sel, UDim.new(0, 12))
	Kit.Label(sel, "✖", { Style = "Title", ZIndex = 71 })
	f.Activated:Connect(function()
		Kit.Play("Click")
		if releaseMode then
			local d = State.Data
			local h = d and d.Hunters[uid]
			if not h or h.Locked or table.find(d.Equipped, uid) then
				Kit.Toast("Equipped or locked hunters can't be released", "Bad")
				return
			end
			if selected[uid] then
				selected[uid] = nil
			else
				selected[uid] = true
			end
			sel.Visible = selected[uid] == true
			updateReleaseBar()
		else
			setInspect(uid)
		end
	end)
	return { Frame = f, Equip = eqBadge, Lock = lock, Select = sel }
end

local BATCH = 24 -- new cards per frame: a 150-hunter inventory opens without a hitch
local rebuildQueued = false

local function rebuild()
	local d = State.Data
	if not d then
		return
	end
	local created = 0
	-- remove cards for hunters that are gone
	for uid, c in cards do
		if not d.Hunters[uid] then
			c.Frame:Destroy()
			cards[uid] = nil
			selected[uid] = nil
		end
	end
	local eq: { [string]: boolean } = {}
	for _, uid in d.Equipped do
		eq[uid] = true
	end
	for i, uid in sortedUids(d) do
		local h = d.Hunters[uid]
		local c = cards[uid]
		if not c then
			if created >= BATCH then
				-- finish the rest next frame
				if not rebuildQueued then
					rebuildQueued = true
					task.spawn(function()
						task.wait() -- next frame
						rebuildQueued = false
						if panel.IsOpen then
							rebuild()
						end
					end)
				end
				continue
			end
			created += 1
			c = makeCard(uid, h.Id)
			cards[uid] = c
		end
		c.Frame.LayoutOrder = i
		c.Equip.Visible = eq[uid] == true
		c.Lock.Visible = h.Locked == true
		c.Select.Visible = releaseMode and selected[uid] == true
	end
	local count = State.CountOwned()
	local slots = d.Slots or Config.Inventory.BaseSlots
	equippedLabel.Text = "EQUIPPED " .. #d.Equipped .. "/" .. slots
	powerLabel.Text = "⚡ " .. Format.Short(d.CrewPower or 0)
	local maxHunters = (State.Data and State.Data.MaxHunters) or Config.Inventory.MaxHunters
	storageLabel.Text = "STORAGE " .. count .. "/" .. maxHunters
	storageLabel.TextColor3 = if count >= maxHunters - 5 then Theme.Bad else Theme.Muted
	if inspectUid and not d.Hunters[inspectUid] then
		inspectUid = nil
	end
	setInspect(inspectUid)
	if releaseMode then
		updateReleaseBar()
	end
end

local function setReleaseMode(on: boolean)
	releaseMode = on
	table.clear(selected)
	releaseBar.Visible = on
	Kit.SetButtonText(releaseButton, if on then "DONE" else "RELEASE")
	releaseButton:SetAttribute("Color", if on then "Gray" else "Red")
	rebuild()
end

local function act(action: string, ...: any)
	local res = State.Request(action, ...)
	if not res.ok then
		Kit.Toast(res.err or "Couldn't do that", "Bad")
	end
	return res
end

function HuntersPanel.Init()
	panel = Kit.Panel("Hunters", "GHOST HUNTERS", Vector2.new(860, 500), "Orange")
	local body = panel.Body
	-- top bar: counts on the left, actions on the right (actions drop to a 2nd row when narrow)
	top = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 10), BackgroundTransparency = 1, ZIndex = 61, Parent = body })
	equippedLabel = Kit.Label(top, "EQUIPPED 0/4", { Size = UDim2.fromOffset(150, 22), Position = UDim2.fromOffset(0, 0), Align = Enum.TextXAlignment.Left, Style = "Heading", Fit = true, ZIndex = 62 })
	powerLabel = Kit.Label(top, "⚡ 0", { Size = UDim2.fromOffset(120, 22), Position = UDim2.fromOffset(152, 0), Align = Enum.TextXAlignment.Left, Color = Theme.Gold, Style = "Heading", Fit = true, ZIndex = 62 })
	storageLabel = Kit.Label(top, "STORAGE 0/150", { Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(0, 25), Align = Enum.TextXAlignment.Left, Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, ZIndex = 62 })
	actionsRow = Kit.new("Frame", { Size = UDim2.new(0, 400, 0, 40), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 61, Parent = top })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = actionsRow })
	local buttons = actionsRow
	sortButton = Kit.Button(buttons, {
		Text = "SORT: POWER",
		Color = "Blue",
		Size = UDim2.fromOffset(124, 38),
		TextStyle = "Small",
		ZIndex = 62,
		OnClick = function()
			sortMode = if sortMode == "Power" then "Rarity" else "Power"
			Kit.SetButtonText(sortButton, "SORT: " .. string.upper(sortMode))
			rebuild()
		end,
	})
	releaseButton = Kit.Button(buttons, {
		Text = "RELEASE",
		Color = "Red",
		Size = UDim2.fromOffset(100, 38),
		TextStyle = "Small",
		ZIndex = 62,
		OnClick = function()
			setReleaseMode(not releaseMode)
		end,
	})
	equipBestButton = Kit.Button(buttons, {
		Text = "EQUIP BEST",
		Color = "Green",
		Size = UDim2.fromOffset(140, 38),
		ZIndex = 62,
		OnClick = function()
			local res = act("EquipBest")
			if res.ok then
				Kit.Toast("Best crew equipped! ⚡ " .. Format.Commas(res.Power or 0), "Good")
			end
		end,
	})
	equipBestButton.Name = "EquipBest"
	panel.Primary = equipBestButton
	-- grid
	grid = Kit.new("ScrollingFrame", {
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.5,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Panel3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BorderSizePixel = 0,
		ZIndex = 62,
		Parent = body,
	})
	Kit.Corner(grid, UDim.new(0, 12))
	Kit.Padding(grid, 8)
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(100, 122),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	-- inspect pane (scrolls, so it fits short phone screens)
	side = Kit.new("Frame", { AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.5, ZIndex = 62, Parent = body })
	Kit.Corner(side, UDim.new(0, 12))
	emptyHint = Kit.Label(side, "Tap a hunter to inspect it.\n\nEQUIP BEST picks your strongest crew!", { Size = UDim2.new(1, -24, 0.6, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Muted, Font = Theme.Body, Style = "Small", ZIndex = 63, Stroke = 0 })
	inspect = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		ZIndex = 63,
		Parent = side,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = inspect })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = inspect })
	viewHolder = Kit.new("Frame", { Size = UDim2.fromOffset(150, 132), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 63, Parent = inspect })
	nameLabel = Kit.Label(inspect, "", { Size = UDim2.new(1, 0, 0, 22), Style = "Heading", Fit = true, ZIndex = 64 })
	nameLabel.LayoutOrder = 2
	rarityRibbon = Kit.new("Frame", { Size = UDim2.fromOffset(150, 22), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 3, ZIndex = 64, Parent = inspect })
	Kit.Corner(rarityRibbon, UDim.new(1, 0))
	Kit.Stroke(rarityRibbon, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(rarityRibbon, Theme.Panel2, Theme.Panel, 0)
	rarityLabel = Kit.Label(rarityRibbon, "", { Style = "Small", ZIndex = 65 })
	statLabel = Kit.Label(inspect, "", { Size = UDim2.new(1, 0, 0, 20), Color = Theme.Gold, Style = "Body", Fit = true, ZIndex = 64 })
	statLabel.LayoutOrder = 4
	blurbLabel = Kit.Label(inspect, "", { Size = UDim2.new(1, 0, 0, 0), Color = Theme.Muted, Font = Theme.Body, Style = "Small", ZIndex = 64, Stroke = 0 })
	blurbLabel.AutomaticSize = Enum.AutomaticSize.Y
	blurbLabel.LayoutOrder = 5
	local actions: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundTransparency = 1, LayoutOrder = 6, ZIndex = 63, Parent = inspect })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 40), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions })
	equipButton = Kit.Button(actions, {
		Text = "EQUIP",
		Color = "Green",
		TextStyle = "Small",
		ZIndex = 64,
		OnClick = function()
			local d = State.Data
			local uid = inspectUid
			if not d or not uid then
				return
			end
			if table.find(d.Equipped, uid) then
				act("Unequip", uid)
			else
				act("Equip", uid)
			end
		end,
	})
	equipButton.LayoutOrder = 1
	lockButton = Kit.Button(actions, {
		Text = "🔒 LOCK",
		Color = "Blue",
		TextStyle = "Small",
		ZIndex = 64,
		OnClick = function()
			local d = State.Data
			local uid = inspectUid
			local h = uid and d and d.Hunters[uid]
			if h then
				act("Lock", uid, not h.Locked)
			end
		end,
	})
	lockButton.LayoutOrder = 2
	relOneButton = Kit.Button(actions, {
		Text = "RELEASE",
		Color = "Red",
		TextStyle = "Small",
		ZIndex = 64,
		OnClick = function()
			local uid = inspectUid
			if uid then
				act("Release", { uid })
			end
		end,
	})
	relOneButton.LayoutOrder = 3
	-- release bar (replaces the inspect pane in release mode)
	releaseBar = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 63, Parent = side })
	Kit.Label(releaseBar, "Tap hunters to select them. Released hunters give back a little Ectoplasm.", { Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 8), Color = Theme.Muted, Font = Theme.Body, Style = "Small", ZIndex = 64, Stroke = 0 })
	Kit.Button(releaseBar, {
		Text = "SELECT WEAK",
		Color = "Orange",
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 74),
		ZIndex = 64,
		OnClick = function()
			-- every unequipped, unlocked hunter weaker than your weakest equipped one
			local d = State.Data
			if not d then
				return
			end
			local weakest = math.huge
			for _, uid in d.Equipped do
				local h = d.Hunters[uid]
				if h then
					weakest = math.min(weakest, powerOf(h.Id))
				end
			end
			table.clear(selected)
			for uid, h in d.Hunters do
				if not h.Locked and not table.find(d.Equipped, uid) and powerOf(h.Id) < weakest then
					selected[uid] = true
				end
			end
			rebuild()
		end,
	})
	releaseConfirm = Kit.Button(releaseBar, {
		Text = "RELEASE 0",
		Color = "Gray",
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.new(0, 10, 1, -10),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 64,
		OnClick = function()
			local list = {}
			for uid in selected do
				table.insert(list, uid)
			end
			if #list == 0 then
				return
			end
			local res = act("Release", list)
			if res.ok then
				table.clear(selected)
				rebuild()
			end
		end,
	})
	Hud.RegisterPanel("Hunters", function()
		panel:Toggle()
	end)
end

-- Responsive layout from the panel's actual (logical) width: the inspect pane takes ~30%,
-- and the action buttons move under the counters when the panel is narrow.
local function layout()
	local w = panel.Root.Size.X.Offset - 28
	local narrow = w < 700
	local topH = if narrow then 88 else 44
	top.Size = UDim2.new(1, 0, 0, topH)
	if narrow then
		actionsRow.AnchorPoint = Vector2.zero
		actionsRow.Position = UDim2.fromOffset(0, 46)
		actionsRow.Size = UDim2.new(1, 0, 0, 40)
		local list = actionsRow:FindFirstChildOfClass("UIListLayout")
		if list then
			list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
	else
		actionsRow.AnchorPoint = Vector2.new(1, 0)
		actionsRow.Position = UDim2.fromScale(1, 0)
		actionsRow.Size = UDim2.new(0, 400, 0, 40)
		local list = actionsRow:FindFirstChildOfClass("UIListLayout")
		if list then
			list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		end
	end
	local sideW = math.clamp(math.floor(w * 0.3), 200, 260)
	local y = topH + 16
	grid.Position = UDim2.fromOffset(0, y)
	grid.Size = UDim2.new(1, -(sideW + 8), 1, -y)
	side.Position = UDim2.new(1, 0, 0, y)
	side.Size = UDim2.new(0, sideW, 1, -y)
end

function HuntersPanel.Start()
	panel.OnOpen:Connect(function()
		layout()
		rebuild()
	end)
	Kit.ScaleChanged:Connect(function()
		if panel.IsOpen then
			layout()
		end
	end)
	panel.OnClose:Connect(function()
		if releaseMode then
			setReleaseMode(false)
		end
		clearPreview()
	end)
	State.Changed:Connect(function()
		if panel.IsOpen then
			rebuild()
		end
	end)
end

function HuntersPanel.EquipBestButton(): TextButton
	return equipBestButton
end

function HuntersPanel.IsOpen(): boolean
	return panel.IsOpen
end

return HuntersPanel
