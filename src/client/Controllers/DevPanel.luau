--!strict
-- DEV panel: owner-only test tools. The 🛠 button appears only when the server marked this
-- player as a developer (attribute "IsDev"); every action is checked again on the server
-- (DevService), which also sends back the confirmation line shown in the toast.
-- Rare pet launch event admins (attribute "RarePetAdmin", Config.RarePetEvent.AdminUserIds) also
-- get the button, with the START RARE PET EVENT control under BOSSES & EVENTS.
--
-- Layout: a row of tabs (MONEY, AREAS, HUNTERS, PETS, BOSSES & EVENTS, PLAYER, DANGER ZONE), a
-- search box that filters every tool across all tabs, then one scrolling list. Each tool is a big
-- button with a one-line explanation next to it. Risky tools need a second tap within 4 s.
-- Phone rules: 44 px taps, fixed text sizes (Kit labels; no TextScaled, no text scale tweens).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Format = require(GH.Logic.Format)
local DevTools = require(GH.Logic.DevTools)
local Config = require(GH.Config)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Portrait = require(Client.UI.Portrait)
local Hud = require(script.Parent.Hud)

local DevPanel = {}

local player = Players.LocalPlayer
local IS_STUDIO = RunService:IsStudio()
local CONFIRM_SECONDS = 4

local panel: Kit.Panel
local inbox: Kit.Panel
local inboxList: ScrollingFrame
local devButton: TextButton
local list: ScrollingFrame
local searchBox: TextBox
local feedbackButton: TextButton
local noResults: TextLabel
local refreshAll: () -> () -- set below (rows call it before it is defined)

--------------------------------------------------------------------------------
-- Tabs and items
--------------------------------------------------------------------------------
type Tab = { Key: string, Text: string, Color: string }
local TABS: { Tab } = {
	{ Key = "Money", Text = "MONEY", Color = "Green" },
	{ Key = "Areas", Text = "AREAS", Color = "Blue" },
	{ Key = "Hunters", Text = "HUNTERS", Color = "Orange" },
	{ Key = "Pets", Text = "PETS", Color = "Pink" },
	{ Key = "Bosses", Text = "BOSSES & EVENTS", Color = "Purple" },
	{ Key = "Player", Text = "PLAYER", Color = "Teal" },
	{ Key = "Danger", Text = "DANGER ZONE", Color = "Red" },
}
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Money" -- remembered while you play (the panel reopens on the last tab)
local query = ""

-- One row in the list. Shown when its tab is open (and Show() agrees), or, while searching, when
-- its Search text matches (OnSearch decides for grids that filter their own cards).
type Item = {
	Tab: string,
	Frame: GuiObject,
	Search: string?, -- nil = hidden while searching (section headers, notes)
	Show: (() -> boolean)?,
	OnSearch: ((q: string) -> boolean)?,
	Admin: boolean?, -- also shown to Rare Pet admins who aren't devs
	Studio: boolean?, -- only in Studio
}
local items: { Item } = {}
local order = 0
local refreshers: { () -> () } = {}

local function addItem(it: Item)
	order += 1
	it.Frame.LayoutOrder = order
	table.insert(items, it)
end

local function rowFrame(h: number, transparent: boolean?): Frame
	local f: Frame = Kit.new("Frame", {
		Size = UDim2.new(1, -12, 0, h),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = if transparent then 1 else 0.35,
		ZIndex = 62,
		Parent = list,
	})
	if not transparent then
		Kit.Corner(f, UDim.new(0, 10))
	end
	return f
end

-- A row that grows with its content: a title, an optional grey line, then a grid of buttons.
local function gridRow(title: string, desc: string?, cell: Vector2): (Frame, Frame)
	local f = rowFrame(0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = f })
	Kit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	local t = Kit.Label(f, title, { Size = UDim2.new(1, 0, 0, 24), Align = Enum.TextXAlignment.Left, Style = "Body", Fit = true, ZIndex = 63 })
	t.LayoutOrder = 1
	if desc then
		local s = Kit.Label(f, desc, { Size = UDim2.new(1, 0, 0, 18), Align = Enum.TextXAlignment.Left, Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, Fit = true, ZIndex = 63 })
		s.LayoutOrder = 2
	end
	local grid: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 62, Parent = f })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	return f, grid
end

--------------------------------------------------------------------------------
-- Sending commands
--------------------------------------------------------------------------------
local inFlight: { [string]: boolean } = {}

-- Sends one dev command and toasts the server's confirmation (or its error).
local function send(cmd: string, arg: any?, arg2: any?): boolean
	local key = cmd .. ":" .. tostring(arg) .. ":" .. tostring(arg2)
	if inFlight[key] then
		return false -- a double tap while the first one is still on its way
	end
	inFlight[key] = true
	local res = State.Request("Dev", cmd, arg, arg2)
	inFlight[key] = nil
	if res.ok then
		Kit.Toast("✅ " .. (if type(res.Msg) == "string" then res.Msg else "Done"), "Good")
	else
		Kit.Toast(res.err or "Failed", "Bad")
	end
	return res.ok == true
end

-- Two-tap confirm: the first tap turns the button red with "TAP AGAIN TO CONFIRM" for a few
-- seconds; only a second tap in that time runs the action.
local armed: { [string]: number } = {}
local function confirmTap(key: string, b: TextButton, text: string, color: string): boolean
	if DevTools.Confirm(armed, key, os.clock(), CONFIRM_SECONDS) then
		Kit.SetButtonText(b, text)
		b:SetAttribute("Color", color)
		return true
	end
	Kit.SetButtonText(b, "TAP AGAIN TO CONFIRM")
	b:SetAttribute("Color", "Red")
	local stamp = armed[key]
	task.delay(CONFIRM_SECONDS, function()
		if armed[key] == stamp then
			armed[key] = nil
			Kit.SetButtonText(b, text)
			b:SetAttribute("Color", color)
		end
	end)
	return false
end

--------------------------------------------------------------------------------
-- Row builders
--------------------------------------------------------------------------------
-- Section heading (hidden while searching). `sub` = a live status line (refreshed).
local function header(tab: string, text: string, sub: (() -> string)?, admin: boolean?)
	local f = rowFrame(if sub then 50 else 30, true)
	Kit.Label(f, text, { Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 2), Align = Enum.TextXAlignment.Left, Style = "Heading", Fit = true, ZIndex = 63 })
	if sub then
		local s = Kit.Label(f, "", { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 28), Align = Enum.TextXAlignment.Left, Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, Fit = true, ZIndex = 63 })
		table.insert(refreshers, function()
			s.Text = sub()
		end)
	end
	addItem({ Tab = tab, Frame = f, Admin = admin })
end

-- Short grey note (hidden while searching).
local function note(tab: string, text: string)
	local f = rowFrame(44)
	local l = Kit.Label(f, text, { Size = UDim2.new(1, -16, 1, -4), Position = UDim2.fromOffset(8, 2), Align = Enum.TextXAlignment.Left, Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, Wrap = true, ZIndex = 63 })
	l.TextWrapped = true
	addItem({ Tab = tab, Frame = f })
end

local function tabText(key: string): string
	for _, t in TABS do
		if t.Key == key then
			return t.Text
		end
	end
	return ""
end

type Action = {
	Text: string,
	Desc: string,
	Color: string?,
	Cmd: string?, -- server command (DevService)
	Arg: any?,
	Client: (() -> ())?, -- runs after a successful Cmd, or alone when there is no Cmd
	Confirm: boolean?,
	Studio: boolean?,
	Words: string?, -- extra search words
}

-- A big button with a one-line explanation next to it.
local function action(tab: string, a: Action)
	local f = rowFrame(56)
	local color = a.Color or "Blue"
	local b: TextButton
	b = Kit.Button(f, {
		Text = a.Text,
		Color = color,
		Size = UDim2.new(0.42, 0, 0, 46),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextStyle = "Small",
		ZIndex = 63,
		OnClick = function()
			if a.Confirm and not confirmTap(a.Text, b, a.Text, color) then
				return
			end
			if a.Cmd then
				if send(a.Cmd :: string, a.Arg) and a.Client then
					(a.Client :: () -> ())()
				end
			elseif a.Client then
				(a.Client :: () -> ())()
			end
		end,
	})
	local d = Kit.Label(f, a.Desc, { Size = UDim2.new(0.58, -18, 1, -6), Position = UDim2.new(0.42, 12, 0, 3), Align = Enum.TextXAlignment.Left, Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, Wrap = true, ZIndex = 63 })
	d.TextWrapped = true
	addItem({ Tab = tab, Frame = f, Search = a.Text .. " " .. a.Desc .. " " .. tabText(tab) .. " " .. (a.Words or ""), Studio = a.Studio })
end

-- Amount picker: one button per amount (+1,000 ... +1Dc, MAX).
local function amountPicker(tab: string, title: string, desc: string, kind: string)
	local f, grid = gridRow(title, desc, Vector2.new(104, 44))
	for i, amt in DevTools.Amounts(kind, Format.Short) do
		local b = Kit.Button(grid, { Text = amt.Label, Color = if amt.Label == "MAX" then "Orange" else "Green", TextStyle = "Small", ZIndex = 63, OnClick = function()
			send(kind, amt.Value)
		end })
		b.LayoutOrder = i
	end
	addItem({ Tab = tab, Frame = f, Search = title .. " " .. desc .. " money currency" })
end

-- Number box + buttons that use it (Boss Tower room).
type NumberButton = { Text: string, Color: string, Cmd: string, Close: boolean? }
local function numberRow(tab: string, title: string, lo: number, hi: number, buttons: { NumberButton }, words: string)
	local f = rowFrame(86)
	Kit.Label(f, title, { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(8, 4), Align = Enum.TextXAlignment.Left, Style = "Body", Fit = true, ZIndex = 63 })
	local boxBg: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(110, 46), Position = UDim2.fromOffset(6, 32), BackgroundColor3 = Theme.Panel, ZIndex = 63, Parent = f })
	Kit.Corner(boxBg, UDim.new(0, 10))
	Kit.Stroke(boxBg, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local box: TextBox = Kit.new("TextBox", {
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = Theme.Body,
		TextSize = Theme.Type.Body,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Muted,
		PlaceholderText = "room #",
		Text = "",
		ZIndex = 64,
		Parent = boxBg,
	})
	local x = 124
	local names: { string } = {}
	for _, bt in buttons do
		Kit.Button(f, { Text = bt.Text, Color = bt.Color, TextStyle = "Small", Size = UDim2.fromOffset(170, 46), Position = UDim2.fromOffset(x, 32), ZIndex = 63, OnClick = function()
			local n = DevTools.Int(tonumber(box.Text), lo, hi)
			if not n then
				Kit.Toast("Type a whole number " .. lo .. "-" .. hi .. " in the box first", "Bad")
				return
			end
			if send(bt.Cmd, n) and bt.Close then
				panel:Close()
			end
		end })
		x += 178
		table.insert(names, bt.Text)
	end
	addItem({ Tab = tab, Frame = f, Search = title .. " " .. table.concat(names, " ") .. " " .. words })
end

--------------------------------------------------------------------------------
-- AREAS: World 1 / World 2 sub-tabs, a row per area (GO + UNLOCK UP TO HERE)
--------------------------------------------------------------------------------
local areaWorld = 1

local function worldOf(zoneOrder: number): number
	for wi, w in Config.Worlds do
		if zoneOrder >= w.First and zoneOrder <= w.Last then
			return wi
		end
	end
	return 1
end

local function buildAreas()
	header("Areas", "AREAS & TRAVEL")
	action("Areas", { Text = "UNLOCK ALL AREAS", Desc = "Own all " .. #Config.Zones .. " areas in both worlds (also counts the Ghost King as beaten).", Color = "Green", Cmd = "Zones", Words = "world 2 portal zones" })
	local places = {
		{ Text = "LOBBY", Key = "Lobby" },
		{ Text = "BOSS TOWER", Key = "Tower" },
		{ Text = "PET HATCHERY", Key = "Hatchery" },
		{ Text = "TRADING BOOTH", Key = "TradeBooth" },
		{ Text = "WORLD 2 PORTAL", Key = "Portal" },
	}
	local pf, pg = gridRow("TELEPORT TO A PLACE", nil, Vector2.new(150, 44))
	local placeWords: { string } = {}
	for i, p in places do
		local b = Kit.Button(pg, { Text = p.Text, Color = "Blue", TextStyle = "Small", ZIndex = 63, OnClick = function()
			send("Teleport", p.Key)
		end })
		b.LayoutOrder = i
		table.insert(placeWords, p.Text)
	end
	addItem({ Tab = "Areas", Frame = pf, Search = "teleport go travel place " .. table.concat(placeWords, " ") })

	-- WORLD 1 / WORLD 2 sub-tabs
	local wf = rowFrame(52, true)
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wf })
	local worldButtons: { TextButton } = {}
	local function paintWorlds()
		for wi, b in worldButtons do
			b:SetAttribute("Color", if wi == areaWorld then "Blue" else "Gray")
		end
	end
	for wi, w in Config.Worlds do
		local b = Kit.Button(wf, { Text = w.Name .. ": AREAS " .. w.First .. "-" .. w.Last, Size = UDim2.fromOffset(230, 44), TextStyle = "Small", ZIndex = 63, OnClick = function()
			areaWorld = wi
			paintWorlds()
			refreshAll()
		end })
		b.LayoutOrder = wi
		worldButtons[wi] = b
	end
	paintWorlds()
	addItem({ Tab = "Areas", Frame = wf })

	for _, z in Config.Zones do
		local f = rowFrame(56)
		local stripe: Frame = Kit.new("Frame", { Size = UDim2.new(0, 6, 1, -12), Position = UDim2.fromOffset(4, 6), BackgroundColor3 = z.Accent, BorderSizePixel = 0, ZIndex = 63, Parent = f })
		Kit.Corner(stripe, UDim.new(0, 3))
		Kit.Label(f, z.Order .. ". " .. z.Name, { Size = UDim2.new(1, -250, 0, 24), Position = UDim2.fromOffset(16, 4), Align = Enum.TextXAlignment.Left, Style = "Body", Fit = true, ZIndex = 63 })
		local status = Kit.Label(f, "", { Size = UDim2.new(1, -250, 0, 20), Position = UDim2.fromOffset(16, 30), Align = Enum.TextXAlignment.Left, Font = Theme.Body, Style = "Small", Stroke = 0, Fit = true, ZIndex = 63 })
		Kit.Button(f, { Text = "GO", Color = "Green", TextStyle = "Small", Size = UDim2.fromOffset(90, 44), Position = UDim2.new(1, -226, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 63, OnClick = function()
			if send("TeleportArea", z.Id) then
				panel:Close()
			end
		end })
		local unlock = Kit.Button(f, { Text = "UNLOCK UP TO HERE", Color = "Purple", TextStyle = "Tiny", Size = UDim2.fromOffset(124, 44), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 63, OnClick = function()
			send("UnlockTo", z.Id)
		end })
		table.insert(refreshers, function()
			local d = State.Data
			local owned = d ~= nil and d.Zones[z.Id] == true
			status.Text = (if owned then "Unlocked" else "Locked") .. "  ·  price " .. Format.Short(z.Cost) .. " Ecto"
			status.TextColor3 = if owned then Theme.Ecto else Theme.Muted
			unlock:SetAttribute("Color", if owned then "Gray" else "Purple")
		end)
		local w = worldOf(z.Order)
		addItem({
			Tab = "Areas",
			Frame = f,
			Search = z.Name .. " area " .. z.Order .. " teleport go unlock " .. Config.Worlds[w].Name,
			Show = function()
				return w == areaWorld
			end,
		})
	end
end

--------------------------------------------------------------------------------
-- HUNTERS: pick an area, then give any of its hunters (with their portraits)
--------------------------------------------------------------------------------
local hunterArea = 1
local hunterGrid: Frame
local hunterTitle: TextLabel
local shownHunters = "" -- what the grid holds now ("area:<n>" or "q:<query>")
local MAX_SEARCH_CARDS = 24

local function rarityOf(id: string): Config.RarityDef
	return Config.Rarities[Config.Hunters[id].Rarity] or Config.Rarities.Common
end

local function hunterCard(id: string, i: number)
	local def = Config.Hunters[id]
	local r = rarityOf(id)
	local card: Frame = Kit.new("Frame", { BackgroundColor3 = Theme.Panel2, LayoutOrder = i, ZIndex = 63, Parent = hunterGrid })
	Kit.Corner(card, UDim.new(0, 12))
	Kit.Stroke(card, 2, r.Color, Enum.ApplyStrokeMode.Border)
	local pic: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 63, Parent = card })
	Portrait.Face(pic, id, false)
	local n = Kit.Label(card, def.Name, { Size = UDim2.new(1, -8, 0, 34), Position = UDim2.fromOffset(4, 66), Style = "Small", Wrap = true, ZIndex = 64 })
	n.TextWrapped = true
	Kit.Label(card, r.Name .. "  ·  " .. Format.Short(def.Power) .. " power", { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 100), Color = Theme.RarityText(r), Style = "Tiny", Fit = true, ZIndex = 64 })
	Kit.Button(card, { Text = "+1", Color = "Green", TextStyle = "Small", Size = UDim2.new(0.5, -9, 0, 44), Position = UDim2.new(0, 6, 1, -6), AnchorPoint = Vector2.new(0, 1), ZIndex = 64, OnClick = function()
		send("GiveHunter", id, 1)
	end })
	Kit.Button(card, { Text = "+" .. Config.Merge.Count, Color = "Orange", TextStyle = "Small", Size = UDim2.new(0.5, -9, 0, 44), Position = UDim2.new(1, -6, 1, -6), AnchorPoint = Vector2.new(1, 1), ZIndex = 64, OnClick = function()
		send("GiveHunter", id, Config.Merge.Count)
	end })
end

local function sortedHunters(filter: (Config.HunterDef) -> boolean): { string }
	local ids: { string } = {}
	for id, def in Config.Hunters do
		if filter(def) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local za, zb = Config.ZoneById[Config.Hunters[a].Zone], Config.ZoneById[Config.Hunters[b].Zone]
		local oa, ob = if za then za.Order else 99, if zb then zb.Order else 99
		if oa ~= ob then
			return oa < ob
		end
		local ra, rb = rarityOf(a).Order, rarityOf(b).Order
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	return ids
end

-- Fills the grid with `ids` (no rebuild when it already shows them).
local function fillHunters(key: string, ids: { string })
	if shownHunters == key then
		return
	end
	shownHunters = key
	for _, c in hunterGrid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	for i, id in ids do
		if i > MAX_SEARCH_CARDS and key:sub(1, 2) == "q:" then
			break
		end
		hunterCard(id, i)
	end
end

local function showArea()
	local z = Config.Zones[hunterArea]
	hunterTitle.Text = z.Order .. ". " .. z.Name .. "  (" .. Config.Worlds[worldOf(z.Order)].Name .. ")"
	fillHunters("area:" .. hunterArea, sortedHunters(function(def)
		return def.Zone == z.Id
	end))
end

local function buildHunters()
	header("Hunters", "GIVE HUNTERS")
	action("Hunters", { Text = "ONE OF EVERY HUNTER", Desc = "Gives each hunter you don't own yet (all areas + Exclusives). Can go over storage.", Color = "Orange", Cmd = "Hunters", Words = "all" })
	action("Hunters", { Text = "EXCLUSIVE CRATE TEST", Desc = "Same as buying the Exclusive Crate: the Exclusive hunter of your best area.", Color = "Teal", Cmd = "Exclusive", Words = "robux" })
	action("Hunters", { Text = "COMPLETE THE INDEX", Desc = "Marks every hunter as found in Normal, Shiny and Mega (gives no hunters).", Color = "Purple", Cmd = "IndexAll", Words = "discovered collection" })

	-- area picker: < AREA > , WORLD 1 / WORLD 2 jumps, and the whole set
	header("Hunters", "PICK AN AREA, THEN GIVE ITS HUNTERS")
	local f = rowFrame(106)
	Kit.Button(f, { Text = "<", Color = "Blue", TextStyle = "Heading", Size = UDim2.fromOffset(52, 44), Position = UDim2.fromOffset(6, 6), ZIndex = 63, OnClick = function()
		hunterArea = if hunterArea <= 1 then #Config.Zones else hunterArea - 1
		showArea()
	end })
	hunterTitle = Kit.Label(f, "", { Size = UDim2.new(1, -136, 0, 44), Position = UDim2.fromOffset(66, 6), Style = "Body", Fit = true, ZIndex = 63 })
	Kit.Button(f, { Text = ">", Color = "Blue", TextStyle = "Heading", Size = UDim2.fromOffset(52, 44), Position = UDim2.new(1, -6, 0, 6), AnchorPoint = Vector2.new(1, 0), ZIndex = 63, OnClick = function()
		hunterArea = if hunterArea >= #Config.Zones then 1 else hunterArea + 1
		showArea()
	end })
	local x = 6
	for _, w in Config.Worlds do
		Kit.Button(f, { Text = w.Name, Color = "Gray", TextStyle = "Small", Size = UDim2.fromOffset(120, 44), Position = UDim2.fromOffset(x, 56), ZIndex = 63, OnClick = function()
			hunterArea = w.First
			showArea()
		end })
		x += 128
	end
	Kit.Button(f, { Text = "GIVE WHOLE AREA SET", Color = "Orange", TextStyle = "Small", Size = UDim2.fromOffset(210, 44), Position = UDim2.new(1, -6, 0, 56), AnchorPoint = Vector2.new(1, 0), ZIndex = 63, OnClick = function()
		send("GiveSet", Config.Zones[hunterArea].Id)
	end })
	addItem({ Tab = "Hunters", Frame = f })

	-- the hunter cards (the picked area's set, or search results across every area)
	hunterGrid = rowFrame(0, true)
	hunterGrid.AutomaticSize = Enum.AutomaticSize.Y
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 172), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = hunterGrid })
	Kit.new("UIPadding", { PaddingBottom = UDim.new(0, 6), Parent = hunterGrid })
	addItem({
		Tab = "Hunters",
		Frame = hunterGrid,
		Show = function()
			showArea() -- back from search results to the picked area
			return true
		end,
		OnSearch = function(q: string): boolean
			if #q < 2 then
				return false
			end
			local ids = sortedHunters(function(def)
				local z = Config.ZoneById[def.Zone]
				return DevTools.Matches(q, def.Name .. " " .. def.Rarity .. " " .. (if z then z.Name else "") .. " hunter")
			end)
			if #ids == 0 then
				return false
			end
			fillHunters("q:" .. q, ids)
			return true
		end,
	})
	showArea()

	header("Hunters", "MY CREW (your equipped hunters)")
	action("Hunters", { Text = "CREW → SHINY", Desc = "Your equipped hunters become Shiny (never lowers a Mega).", Color = "Purple", Cmd = "ShinyCrew", Words = "tier merge" })
	action("Hunters", { Text = "CREW → MEGA (MAX MERGE)", Desc = "Your equipped hunters become Mega, the top merge tier.", Color = "Purple", Cmd = "MegaCrew", Words = "tier merge max" })
	action("Hunters", { Text = "COPIES TO TEST MERGING", Desc = "Gives " .. (Config.Merge.Count - 1) .. " more copies of each equipped hunter, so you can try a merge.", Color = "Orange", Cmd = "MergeCopies", Words = "merge" })
	action("Hunters", { Text = "KNOCK OUT MY CREW", Desc = "Your equipped hunters are knocked out for 30 seconds.", Color = "Red", Cmd = "KnockCrew", Words = "ko hp health" })
	action("Hunters", { Text = "HEAL ALL MY HUNTERS", Desc = "Wakes up knocked-out hunters and fills everyone's health.", Color = "Green", Cmd = "HealAll", Words = "ko hp health" })
	note("Hunters", "Hunters from these tools can't be traded and give nothing back when released.")
end

--------------------------------------------------------------------------------
-- PETS
--------------------------------------------------------------------------------
local function buildPets()
	header("Pets", "PETS & EGGS")
	action("Pets", { Text = "ONE OF EVERY PET", Desc = "Gives each pet you don't own yet (up to " .. Config.PetRules.MaxOwned .. " pets).", Color = "Pink", Cmd = "AllPets", Words = "all" })
	action("Pets", { Text = "UNLOCK ALL EGGS", Desc = "Raises your Boss Tower checkpoint high enough for every egg.", Color = "Pink", Cmd = "UnlockEggs", Words = "hatchery tower" })
	action("Pets", { Text = "GO TO PET HATCHERY", Desc = "Teleports you to the eggs.", Color = "Blue", Cmd = "Teleport", Arg = "Hatchery", Words = "teleport eggs" })
	header("Pets", "GIVE ONE PET")
	local grid = rowFrame(0, true)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 132), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	Kit.new("UIPadding", { PaddingBottom = UDim.new(0, 6), Parent = grid })
	local cards: { { Frame: Frame, Text: string } } = {}
	for i, petId in Config.PetOrder do
		local def = Config.Pets[petId]
		if not def then
			continue
		end
		local r = Config.Rarities[def.Rarity] or Config.Rarities.Common
		local card: Frame = Kit.new("Frame", { BackgroundColor3 = Theme.Panel2, LayoutOrder = i, ZIndex = 63, Parent = grid })
		Kit.Corner(card, UDim.new(0, 12))
		Kit.Stroke(card, 2, r.Color, Enum.ApplyStrokeMode.Border)
		Kit.Label(card, def.Icon, { Size = UDim2.fromOffset(40, 34), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0), Style = "Icon", Stroke = 0, ZIndex = 64 })
		Kit.Label(card, def.Name, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 38), Style = "Small", Fit = true, ZIndex = 64 })
		local bonus = "+" .. math.floor(def.Bonus.Value * 100 + 0.5) .. "% " .. def.Bonus.Kind
		Kit.Label(card, r.Name .. "  ·  " .. bonus, { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 58), Color = Theme.RarityText(r), Style = "Tiny", Fit = true, ZIndex = 64 })
		Kit.Button(card, { Text = "GIVE", Color = "Pink", TextStyle = "Small", Size = UDim2.new(1, -12, 0, 44), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 64, OnClick = function()
			send("GivePet", petId)
		end })
		table.insert(cards, { Frame = card, Text = def.Name .. " " .. def.Rarity .. " " .. def.Bonus.Kind .. " pet" })
	end
	addItem({
		Tab = "Pets",
		Frame = grid,
		Show = function()
			for _, c in cards do
				c.Frame.Visible = true
			end
			return true
		end,
		OnSearch = function(q: string): boolean
			if #q < 2 then
				return false
			end
			local any = false
			for _, c in cards do
				c.Frame.Visible = DevTools.Matches(q, c.Text)
				any = any or c.Frame.Visible
			end
			return any
		end,
	})
end

--------------------------------------------------------------------------------
-- BOSSES & EVENTS (incl. the Rare Pet launch event for admins)
--------------------------------------------------------------------------------
local rareStatus: TextLabel
local rareButton: TextButton
local rareConfirm: Kit.Panel
local rareBusy = false
local rareMsg: string? = nil -- last error / result line from the server
local rareMsgBad = false

local function utc(t: number): string
	return os.date("!%Y-%m-%d %H:%M UTC", t)
end

local function refreshRare()
	if not rareStatus then
		return
	end
	local startT = workspace:GetAttribute("RarePetStart")
	local endT = workspace:GetAttribute("RarePetEnd")
	local checked = workspace:GetAttribute("RarePetChecked") == true
	local text: string
	local color = Theme.Muted
	local canStart = false
	if type(startT) == "number" and type(endT) == "number" then
		local active = State.Now() < endT
		text = (if active then "ACTIVE" else "ENDED") .. "  ·  Start " .. utc(startT) .. "  ·  End " .. utc(endT)
		color = if active then Theme.Good else Theme.Muted
	elseif rareBusy then
		text = "Starting..."
	elseif not checked then
		text = "Checking..."
	else
		text = "Not started. Starts ONE 48-hour event on ALL servers; it can never be restarted."
		canStart = true
	end
	if rareMsg then
		text ..= "\n" .. (rareMsg :: string)
		if rareMsgBad then
			color = Theme.Bad
		end
	end
	rareStatus.Text = text
	rareStatus.TextColor3 = color
	canStart = canStart and not rareBusy
	rareButton:SetAttribute("Color", if canStart then "Orange" else "Gray")
	rareButton.Active = canStart
	local label = if canStart then "START RARE PET EVENT" elseif type(startT) == "number" then "ALREADY STARTED" elseif rareBusy then "STARTING..." else "CHECKING..."
	Kit.SetButtonText(rareButton, label)
end

local function startRare()
	if rareBusy then
		return
	end
	rareBusy = true
	rareMsg = nil
	refreshRare()
	local res = State.Request("Dev", "StartRarePetEvent")
	rareBusy = false
	if res.ok then
		rareMsg = "Started on all servers."
		rareMsgBad = false
		Kit.Toast("✅ Rare Pet Event started", "Good")
	else
		rareMsg = res.err or "Failed"
		rareMsgBad = true
		Kit.Toast(rareMsg :: string, "Bad")
	end
	refreshRare()
	panel:Open()
end

local function buildRare()
	local f = rowFrame(64)
	rareButton = Kit.Button(f, {
		Text = "START RARE PET EVENT",
		Color = "Orange",
		Size = UDim2.new(0.42, 0, 0, 46),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextStyle = "Small",
		ZIndex = 63,
		OnClick = function()
			if not rareButton.Active then
				refreshRare()
				return
			end
			rareConfirm:Open()
		end,
	})
	rareButton.AutoButtonColor = false
	rareStatus = Kit.Label(f, "Checking...", { Size = UDim2.new(0.58, -18, 1, -6), Position = UDim2.new(0.42, 12, 0, 3), Align = Enum.TextXAlignment.Left, Font = Theme.Body, Style = "Small", Stroke = 0, Wrap = true, ZIndex = 63 })
	rareStatus.TextWrapped = true
	addItem({ Tab = "Bosses", Frame = f, Search = "rare pet launch event start global", Admin = true })

	rareConfirm = Kit.Panel("RarePetConfirm", "START RARE PET EVENT?", Vector2.new(480, 270), "Orange")
	Kit.Label(rareConfirm.Body, "This starts ONE global 48-hour event on ALL servers immediately. It can't be undone or restarted.", { Size = UDim2.new(1, -20, 0, 90), Position = UDim2.fromOffset(10, 16), Style = "Body", Wrap = true, ZIndex = 62 })
	Kit.Label(rareConfirm.Body, "Players who play 30 active minutes before it ends get the Rare pet.", { Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 110), Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, Wrap = true, ZIndex = 62 })
	Kit.Button(rareConfirm.Body, {
		Text = "CANCEL",
		Color = "Gray",
		Size = UDim2.fromOffset(170, 46),
		Position = UDim2.new(0.5, -8, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 63,
		OnClick = function()
			rareConfirm:Close()
			panel:Open()
		end,
	})
	local confirm = Kit.Button(rareConfirm.Body, {
		Text = "CONFIRM",
		Color = "Red",
		Size = UDim2.fromOffset(170, 46),
		Position = UDim2.new(0.5, 8, 1, -4),
		AnchorPoint = Vector2.new(0, 1),
		ZIndex = 63,
		OnClick = function()
			rareConfirm:Close()
			task.spawn(startRare)
		end,
	})
	rareConfirm.Primary = confirm
end

local function ecto2xStatus(): string
	if workspace:GetAttribute("Ecto2x") ~= true then
		return "Right now: OFF"
	end
	local ends = workspace:GetAttribute("Ecto2xEnds")
	if type(ends) == "number" and ends > 0 then
		return "Right now: ON, ends in " .. Format.Time(ends - State.Now())
	end
	return "Right now: ON"
end

local function ghostKingStatus(): string
	local d = State.Data
	local boss = Config.Layout.Portals.ToWorld2.Boss
	local beaten = d ~= nil and d.BossesBeaten ~= nil and d.BossesBeaten[boss] == true
	return "Your save: " .. (if beaten then "BEATEN (the World 2 portal can be opened)" else "NOT beaten yet")
end

local function towerStatus(): string
	local d = State.Data
	if not d then
		return ""
	end
	return "Your checkpoint: room " .. tostring(d.TowerCheckpoint or 0) .. "  ·  best room: " .. tostring(d.TowerBest or 0)
end

local function serverLuckStatus(): string
	local d = State.Data
	local left = if d and type(d.ServerLuckUntil) == "number" then d.ServerLuckUntil - State.Now() else 0
	return if left > 0 then "Right now: ON, " .. Format.Time(left) .. " left" else "Right now: OFF"
end

local function buildBosses()
	header("Bosses", "BOSS TOWER", towerStatus)
	numberRow("Bosses", "TYPE A ROOM NUMBER (1-" .. Config.Tower.MaxScaledRoom .. "), THEN:", 1, Config.Tower.MaxScaledRoom, {
		{ Text = "START TEST RUN", Color = "Orange", Cmd = "TowerRoom", Close = true },
		{ Text = "SET CHECKPOINT", Color = "Purple", Cmd = "TowerCheckpoint" },
	}, "boss tower room solo dev run checkpoint")
	note("Bosses", "Test runs are solo and pay nothing. SET CHECKPOINT rounds down to a checkpoint room (5, 10, 15...).")
	action("Bosses", { Text = "GO TO BOSS TOWER", Desc = "Teleports you to the tower's party pad.", Color = "Blue", Cmd = "Teleport", Arg = "Tower", Words = "teleport" })

	header("Bosses", "THE GHOST KING (World 1 final boss)", ghostKingStatus)
	action("Bosses", { Text = "MARK GHOST KING BEATEN", Desc = "Lets you open the World 2 portal without fighting him.", Color = "Purple", Cmd = "GhostKing", Arg = true, Words = "portal world 2 boss" })
	action("Bosses", { Text = "MARK NOT BEATEN", Desc = "Only works while you don't own World 2 yet.", Color = "Gray", Cmd = "GhostKing", Arg = false, Words = "portal world 2 boss" })

	header("Bosses", "THE VOID EMPEROR (World 2 final boss)")
	action("Bosses", { Text = "FIGHT VOID EMPEROR NOW", Desc = "Takes you into his arena and starts the fight. Needs The Void Throne unlocked. Pays nothing.", Color = "Purple", Cmd = "VoidEmperor", Words = "boss" })

	header("Bosses", "2X ECTOPLASM EVENT (ALL SERVERS)", ecto2xStatus)
	action("Bosses", { Text = "TURN ON FOR 2 DAYS", Desc = "Everyone on every server earns double Ectoplasm for 48 hours.", Color = "Green", Cmd = "Ecto2x", Arg = true, Confirm = not IS_STUDIO, Words = "2x ecto event global double" })
	action("Bosses", { Text = "TURN OFF", Desc = "Ends the 2X Ectoplasm event on every server.", Color = "Red", Cmd = "Ecto2x", Arg = false, Confirm = not IS_STUDIO, Words = "2x ecto event global double" })

	header("Bosses", "SERVER LUCK (THIS SERVER)", serverLuckStatus)
	action("Bosses", { Text = "SERVER LUCK +15 MIN", Desc = "Better crate luck for everyone in this server (like the Robux product).", Color = "Green", Cmd = "ServerLuck", Words = "crate luck" })

	header("Bosses", "RARE PET LAUNCH EVENT", nil, true)
	buildRare()
	action("Bosses", { Text = "+5 MIN EVENT PLAY", Desc = "Studio only: counts 5 more minutes toward the Rare pet.", Color = "Orange", Cmd = "RarePetAddMinutes", Studio = true, Words = "rare pet" })
end

--------------------------------------------------------------------------------
-- PLAYER
--------------------------------------------------------------------------------
local function buildPlayer()
	header("Player", "BOOSTS, LUCK, UPGRADES, PASSES")
	for _, id in { "Ecto", "Luck" } do
		local def = (Config.Boosts :: any)[id]
		if type(def) == "table" then
			action("Player", { Text = tostring(def.Name) .. " +30 MIN", Desc = "Adds 30 minutes to your own " .. tostring(def.Name) .. " boost.", Color = "Green", Cmd = "Boost", Arg = id, Words = "boost" })
		end
	end
	action("Player", { Text = "MAX LUCKY OPENS", Desc = "Fills Lucky Opens (better crate luck) on every crate.", Color = "Green", Cmd = "LuckyOpens", Words = "crate luck" })
	action("Player", { Text = "MAX ALL UPGRADES", Desc = "Pickup radius, Ecto bonus and walk speed to the top level.", Color = "Teal", Cmd = "MaxUpgrades", Words = "upgrade" })
	action("Player", { Text = "ALL GAME PASSES", Desc = "Turns on every game pass until you leave. Nothing is bought or saved.", Color = "Purple", Cmd = "AllPasses", Words = "pass vip robux" })
	action("Player", { Text = "OLD AUTO ATTACK PASS", Desc = "The retired pass (its owners get Auto Open). Until you leave.", Color = "Purple", Cmd = "AutoAttack", Words = "pass legacy auto open" })

	header("Player", "DAILY REWARD")
	local f, g = gridRow("MAKE THE DAILY REWARD READY NOW, ON DAY:", nil, Vector2.new(70, 44))
	for day = 1, #Config.Daily.Rewards do
		local b = Kit.Button(g, { Text = tostring(day), Color = if day == #Config.Daily.Rewards then "Orange" else "Purple", ZIndex = 63, OnClick = function()
			send("DailyDay", day)
		end })
		b.LayoutOrder = day
	end
	addItem({ Tab = "Player", Frame = f, Search = "daily reward day streak reset ready" })

	header("Player", "TUTORIAL, MENU TOUR, WHAT'S NEW")
	action("Player", { Text = "REPLAY TUTORIAL", Desc = "Starts the first-time tutorial again from step 1.", Color = "Gray", Cmd = "Tutorial", Client = function()
		local mod = script.Parent:FindFirstChild("Tutorial")
		local ok, Tutorial = pcall(require, mod :: ModuleScript)
		if ok and type(Tutorial) == "table" and type((Tutorial :: any).Restart) == "function" then
			(Tutorial :: any).Restart()
		end
		panel:Close()
	end })
	action("Player", { Text = "SHOW MENU TOUR NOW", Desc = "Plays the quick tour of the menu buttons.", Color = "Gray", Client = function()
		panel:Close()
		Hud.Open("MenuTour")
	end, Words = "tour" })
	action("Player", { Text = "MENU TOUR NEXT JOIN", Desc = "The menu tour plays again the next time you join.", Color = "Gray", Cmd = "TourAgain", Words = "tour reset" })
	action("Player", { Text = "SHOW WHAT'S NEW NOW", Desc = "Opens the update popup (" .. Config.UpdateNotes.Title .. ").", Color = "Gray", Client = function()
		panel:Close()
		require(script.Parent.UpdatePopup).Show()
	end, Words = "update popup notes" })
	action("Player", { Text = "WHAT'S NEW NEXT JOIN", Desc = "The update popup shows again the next time you join.", Color = "Gray", Cmd = "UpdateAgain", Words = "update popup notes reset" })
end

--------------------------------------------------------------------------------
-- DANGER ZONE (Studio only, two taps)
--------------------------------------------------------------------------------
local function buildDanger()
	header("Danger", "DANGER ZONE: YOUR OWN TEST SAVE")
	note("Danger", if IS_STUDIO
		then "Only changes your own Studio test save; other players are never touched. Each button needs two taps."
		else "These only work in Studio test sessions, so your real save can't be wiped by mistake.")
	action("Danger", { Text = "SET MY ECTO TO 0", Desc = "Empties your Ectoplasm (to test prices and 'not enough').", Color = "Red", Cmd = "EctoClear", Confirm = true, Studio = true, Words = "money clear" })
	action("Danger", { Text = "REMOVE TEST HUNTERS", Desc = "Deletes every hunter the dev tools gave or made Shiny/Mega. Other crate hunters stay.", Color = "Red", Cmd = "RemoveDevHunters", Confirm = true, Studio = true, Words = "delete clear dev" })
	action("Danger", { Text = "LOCK ALL AREAS", Desc = "Back to only area 1 owned (also forgets the Ghost King). Respawns you.", Color = "Red", Cmd = "LockAreas", Confirm = true, Studio = true, Words = "zones relock gates portal" })
	action("Danger", { Text = "RESET MY PROGRESS", Desc = "Back to a brand new player. Robux purchases and settings are kept.", Color = "Red", Cmd = "ResetProgress", Confirm = true, Studio = true, Words = "wipe new player" })
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------
local function allowed(it: Item, isDev: boolean, isAdmin: boolean): boolean
	if it.Studio and not IS_STUDIO then
		return false
	end
	return isDev or (it.Admin == true and isAdmin)
end

refreshAll = function()
	local isDev = player:GetAttribute("IsDev") == true
	local isAdmin = player:GetAttribute("RarePetAdmin") == true
	local searching = query:match("%S") ~= nil
	-- tabs that have something for this player
	local tabHas: { [string]: boolean } = {}
	for _, it in items do
		if allowed(it, isDev, isAdmin) then
			tabHas[it.Tab] = true
		end
	end
	if not tabHas[currentTab] then
		for _, t in TABS do
			if tabHas[t.Key] then
				currentTab = t.Key
				break
			end
		end
	end
	for _, t in TABS do
		local b = tabButtons[t.Key]
		b.Visible = tabHas[t.Key] == true
		b:SetAttribute("Color", if t.Key == currentTab and not searching then t.Color else "Gray")
	end
	local shown = 0
	for _, it in items do
		local vis = false
		if allowed(it, isDev, isAdmin) then
			if searching then
				if it.OnSearch then
					vis = (it.OnSearch :: (string) -> boolean)(query)
				elseif it.Search then
					vis = DevTools.Matches(query, it.Search :: string)
				end
			else
				vis = it.Tab == currentTab and (it.Show == nil or (it.Show :: () -> boolean)())
			end
		end
		it.Frame.Visible = vis
		if vis then
			shown += 1
		end
	end
	noResults.Visible = searching and shown == 0
	feedbackButton.Visible = isDev
	for _, fn in refreshers do
		fn()
	end
	refreshRare()
end
DevPanel.Refresh = refreshAll

local function setTab(key: string)
	currentTab = key
	list.CanvasPosition = Vector2.zero
	if query ~= "" or searchBox.Text ~= "" then
		query = ""
		searchBox.Text = "" -- picking a tab ends the search
	end
	refreshAll()
end

--------------------------------------------------------------------------------
-- Player feedback inbox
--------------------------------------------------------------------------------
local function showInbox()
	local res = State.Request("FeedbackInbox")
	if not res.ok then
		Kit.Toast(res.err or "Couldn't load feedback", "Bad")
		return
	end
	for _, c in inboxList:GetChildren() do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local entries = res.Entries or {}
	if #entries == 0 then
		Kit.Label(inboxList, "No feedback yet.", { Size = UDim2.new(1, 0, 0, 30), Style = "Body", ZIndex = 62 })
	end
	for i, e in entries do
		local f: Frame = Kit.new("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.3, LayoutOrder = i, ZIndex = 62, Parent = inboxList })
		Kit.Corner(f, UDim.new(0, 10))
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = f })
		Kit.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
		local head = (if e.Kind == "Bug" then "🐞 BUG" else "💡 IDEA") .. "  ·  " .. tostring(e.Name) .. "  ·  " .. tostring(e.Zone) .. "  ·  " .. os.date("%Y-%m-%d %H:%M", e.T or 0) .. "  ·  v" .. tostring(e.Version)
		local h = Kit.Label(f, head, { Size = UDim2.new(1, 0, 0, 16), Align = Enum.TextXAlignment.Left, Color = if e.Kind == "Bug" then Theme.Bad else Theme.Ecto, Style = "Tiny", Fit = true, ZIndex = 63 })
		h.LayoutOrder = 1
		local t = Kit.Label(f, tostring(e.Text), { Size = UDim2.new(1, 0, 0, 0), Align = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Body, Style = "Small", Stroke = 0, ZIndex = 63 })
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.LayoutOrder = 2
	end
	panel:Close()
	inbox:Open()
end

--------------------------------------------------------------------------------
-- Init / Start
--------------------------------------------------------------------------------
local TOP_TABS = 6
local TOP_SEARCH = 58
local TOP_LIST = 110

function DevPanel.Init()
	panel = Kit.Panel("Dev", "🛠 DEV TOOLS", Vector2.new(820, 520), "Gray")

	-- tab row (scrolls sideways on narrow screens)
	local tabRow: ScrollingFrame = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, TOP_TABS),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ZIndex = 62,
		Parent = panel.Body,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabRow })
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 1), Parent = tabRow })
	for i, t in TABS do
		local b = Kit.Button(tabRow, { Text = t.Text, Color = "Gray", TextStyle = "Small", Size = UDim2.fromOffset(#t.Text * 9 + 34, 44), ZIndex = 63, OnClick = function()
			setTab(t.Key)
		end })
		b.LayoutOrder = i
		tabButtons[t.Key] = b
		if i == 1 then
			panel.Primary = b
		end
	end

	-- search box + CLEAR + player feedback inbox
	local boxBg: Frame = Kit.new("Frame", { Size = UDim2.new(1, -236, 0, 44), Position = UDim2.fromOffset(0, TOP_SEARCH), BackgroundColor3 = Theme.Panel, ZIndex = 62, Parent = panel.Body })
	Kit.Corner(boxBg, UDim.new(0, 10))
	Kit.Stroke(boxBg, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	searchBox = Kit.new("TextBox", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Body,
		TextSize = Theme.Type.Body,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Muted,
		PlaceholderText = "Search all tools: ecto, king, egg, rookie...",
		Text = "",
		ZIndex = 63,
		Parent = boxBg,
	})
	local searchSeq = 0
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchSeq += 1
		local my = searchSeq
		task.delay(0.25, function() -- wait for typing to pause before filtering
			if my == searchSeq and query ~= searchBox.Text then
				query = searchBox.Text
				list.CanvasPosition = Vector2.zero
				refreshAll()
			end
		end)
	end)
	Kit.Button(panel.Body, { Text = "CLEAR", Color = "Gray", TextStyle = "Small", Size = UDim2.fromOffset(90, 44), Position = UDim2.new(1, -138, 0, TOP_SEARCH), AnchorPoint = Vector2.new(1, 0), ZIndex = 63, OnClick = function()
		searchBox.Text = ""
	end })
	feedbackButton = Kit.Button(panel.Body, { Text = "💬 FEEDBACK", Color = "Blue", TextStyle = "Small", Size = UDim2.fromOffset(130, 44), Position = UDim2.new(1, 0, 0, TOP_SEARCH), AnchorPoint = Vector2.new(1, 0), ZIndex = 63, OnClick = showInbox })

	list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -(TOP_LIST + 24)),
		Position = UDim2.fromOffset(0, TOP_LIST),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = list })
	noResults = Kit.Label(list, "Nothing matches. Try another word, or tap CLEAR.", { Size = UDim2.new(1, -12, 0, 40), Color = Theme.Muted, Font = Theme.Body, Style = "Body", Stroke = 0, ZIndex = 62 })
	noResults.LayoutOrder = 0
	noResults.Visible = false

	header("Money", "MONEY")
	amountPicker("Money", "ADD ECTOPLASM", "Tap an amount to add it to your Ectoplasm.", "Ecto")
	amountPicker("Money", "ADD SPIRIT SHARDS", "Spirit Shards buy pet eggs (normally only from Boss Tower chests).", "Shards")
	action("Money", { Text = "+10 CRATE SKIPS", Desc = "Skip tokens for the crate opening animation (max " .. Config.CrateSkip.MaxTokens .. ").", Color = "Teal", Cmd = "SkipTokens", Words = "skip tokens" })
	buildAreas()
	buildHunters()
	buildPets()
	buildBosses()
	buildPlayer()
	buildDanger()

	Kit.Label(panel.Body, "Only you can see this. In a live game these change your real save (Danger Zone works only in Studio).", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), Color = Theme.Muted, Font = Theme.Body, Style = "Tiny", Stroke = 0, Fit = true, ZIndex = 62 })

	inbox = Kit.Panel("DevInbox", "💬 PLAYER FEEDBACK", Vector2.new(760, 460), "Blue")
	inboxList = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -8),
		Position = UDim2.fromOffset(0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 61,
		Parent = inbox.Body,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inboxList })

	-- lower-right row next to FEEDBACK / SETTINGS
	devButton = Kit.Button(Hud.LowerRow or Kit.Screen(), {
		Text = "🛠",
		Color = "Gray",
		Size = UDim2.fromOffset(44, 44),
		TextStyle = "Heading",
		OnClick = function()
			panel:Toggle()
		end,
	})
	devButton.Visible = false
	devButton.LayoutOrder = 1
end

function DevPanel.Start()
	local function refreshAccess()
		devButton.Visible = player:GetAttribute("IsDev") == true or player:GetAttribute("RarePetAdmin") == true
		if panel.IsOpen then
			refreshAll()
		end
	end
	player:GetAttributeChangedSignal("IsDev"):Connect(refreshAccess)
	player:GetAttributeChangedSignal("RarePetAdmin"):Connect(refreshAccess)
	refreshAccess()
	panel.OnOpen:Connect(refreshAll) -- reopens on the last tab you used
	State.Changed:Connect(function()
		if panel.IsOpen then
			for _, fn in refreshers do
				fn()
			end
		end
	end)
	for _, attr in { "RarePetStart", "RarePetEnd", "RarePetChecked", "Ecto2x", "Ecto2xEnds" } do
		workspace:GetAttributeChangedSignal(attr):Connect(function()
			if panel.IsOpen then
				refreshAll()
			end
		end)
	end
	-- live countdowns (2X event, Server Luck, rare pet Active -> Ended) while the panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.IsOpen then
				for _, fn in refreshers do
					fn()
				end
				refreshRare()
			end
		end
	end)
end

return DevPanel
