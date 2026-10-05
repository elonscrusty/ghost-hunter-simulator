--!strict
-- DEV panel: owner-only test tools. The 🛠 button appears only when the server marked this
-- player as a developer (attribute "IsDev"); every action is checked again on the server.
-- Rare pet launch event admins (attribute "RarePetAdmin", Config.RarePetEvent.AdminUserIds) also
-- get the button, with the START RARE PET EVENT control + status at the top of the panel.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Format = require(GH.Logic.Format)
local Config = require(GH.Config)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)

local DevPanel = {}

local player = Players.LocalPlayer
local panel: Kit.Panel
local inbox: Kit.Panel
local inboxList: ScrollingFrame
local devButton: TextButton
local list: ScrollingFrame
local actionButtons: { GuiObject } = {}
local rareRow: Frame
local rareStatus: TextLabel
local rareButton: TextButton
local rareConfirm: Kit.Panel
local rareBusy = false
local rareMsg: string? = nil -- last error / result line from the server
local rareMsgBad = false

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

local HUNTER_COUNT = 0
for _ in Config.Hunters do
	HUNTER_COUNT += 1
end

type Action = { Text: string, Cmd: string, Arg: any?, Color: string, Confirm: boolean?, StudioOnly: boolean? }
local ACTIONS: { Action } = {
	{ Text = "+10K ECTO", Cmd = "Ecto", Arg = 10000, Color = "Green" },
	{ Text = "+1M ECTO", Cmd = "Ecto", Arg = 1000000, Color = "Green" },
	{ Text = "+1B ECTO", Cmd = "Ecto", Arg = 1000000000, Color = "Green" },
	{ Text = "+1T ECTO", Cmd = "Ecto", Arg = 1000000000000, Color = "Green" },
	{ Text = "+1Qa ECTO", Cmd = "Ecto", Arg = 1e15, Color = "Green" },
	{ Text = "+1Qi ECTO", Cmd = "Ecto", Arg = 1e18, Color = "Green" },
	{ Text = "+100Sx ECTO", Cmd = "Ecto", Arg = 1e23, Color = "Green" },
	{ Text = "+10Oc ECTO", Cmd = "Ecto", Arg = 1e28, Color = "Green" },
	{ Text = "UNLOCK ALL AREAS (BOTH WORLDS)", Cmd = "Zones", Color = "Blue" },
	{ Text = "GHOST KING: BEATEN", Cmd = "GhostKing", Arg = true, Color = "Purple" },
	{ Text = "GHOST KING: NOT BEATEN", Cmd = "GhostKing", Arg = false, Color = "Red" },
	{ Text = "ALL " .. HUNTER_COUNT .. " HUNTERS", Cmd = "Hunters", Color = "Orange" },
	{ Text = "COMPLETE INDEX (ALL FORMS)", Cmd = "IndexAll", Color = "Orange" },
	{ Text = "EQUIPPED CREW → MEGA", Cmd = "MegaCrew", Color = "Purple" },
	{ Text = "KNOCK OUT CREW (30S)", Cmd = "KnockCrew", Color = "Red" },
	{ Text = "MAX UPGRADES", Cmd = "MaxUpgrades", Color = "Teal" },
	{ Text = "GIVE ALL PETS", Cmd = "AllPets", Color = "Pink" },
	{ Text = "UNLOCK ALL EGGS", Cmd = "UnlockEggs", Color = "Pink" },
	{ Text = "+1K SPIRIT SHARDS", Cmd = "Shards", Arg = 1000, Color = "Purple" },
	{ Text = "+10K SPIRIT SHARDS", Cmd = "Shards", Arg = 10000, Color = "Purple" },
	{ Text = "+100K SPIRIT SHARDS", Cmd = "Shards", Arg = 100000, Color = "Purple" },
	{ Text = "EQUIPPED CREW → SHINY", Cmd = "ShinyCrew", Color = "Purple" },
	{ Text = "+4 COPIES OF CREW (MERGE TEST)", Cmd = "MergeCopies", Color = "Orange" },
	{ Text = "TELEPORT: LOBBY", Cmd = "Teleport", Arg = "Lobby", Color = "Blue" },
	{ Text = "TELEPORT: BOSS TOWER", Cmd = "Teleport", Arg = "Tower", Color = "Blue" },
	{ Text = "TELEPORT: PET HATCHERY", Cmd = "Teleport", Arg = "Hatchery", Color = "Blue" },
	{ Text = "TELEPORT: WORLD 2 PORTAL", Cmd = "Teleport", Arg = "Portal", Color = "Blue" },
	{ Text = "TELEPORT: WORLD 2 START", Cmd = "Teleport", Arg = "World2", Color = "Blue" },
	{ Text = "TELEPORT: THE VOID THRONE", Cmd = "Teleport", Arg = "VoidThrone", Color = "Blue" },
	{ Text = "MAX LUCKY OPENS", Cmd = "LuckyOpens", Color = "Green" },
	{ Text = "+10 SKIP TOKENS", Cmd = "SkipTokens", Color = "Teal" },
	{ Text = "2X ECTO + LUCK BOOSTS 30M", Cmd = "Boosts", Color = "Green" },
	{ Text = "HEAL ALL HUNTERS", Cmd = "HealAll", Color = "Green" },
	{ Text = "2X ECTOPLASM: 2 DAYS", Cmd = "Ecto2x", Arg = 48, Color = "Green" },
	{ Text = "2X ECTOPLASM: ON (48H)", Cmd = "Ecto2x", Arg = true, Color = "Green" },
	{ Text = "2X ECTOPLASM: OFF", Cmd = "Ecto2x", Arg = false, Color = "Red" },
	{ Text = "VOID EMPEROR: FIGHT NOW (NO REWARDS)", Cmd = "VoidEmperor", Color = "Purple" },
	{ Text = "RESET DAILY", Cmd = "ResetDaily", Color = "Purple" },
	{ Text = "LEGACY PASS: AUTO OPEN", Cmd = "AutoAttack", Color = "Purple" },
	{ Text = "ALL GAME PASSES", Cmd = "AllPasses", Color = "Purple" },
	{ Text = "SERVER LUCK 15M", Cmd = "ServerLuck", Color = "Green" },
	{ Text = "EXCLUSIVE HUNTER", Cmd = "Exclusive", Color = "Teal" },
	{ Text = "REPLAY TUTORIAL", Cmd = "Tutorial", Color = "Gray" },
	{ Text = "+5 MIN RARE PET PLAY", Cmd = "RarePetAddMinutes", Arg = 5, Color = "Orange", StudioOnly = true },
	{ Text = "💬 READ FEEDBACK", Cmd = "Inbox", Color = "Blue" },
	{ Text = "PREVIEW UPDATE POPUP", Cmd = "UpdatePopup", Color = "Purple" },
	{ Text = "⚠️ RESET MY PROGRESS", Cmd = "ResetProgress", Color = "Red", Confirm = true },
}

local armed: { [string]: number } = {} -- dangerous actions need a second tap within 4 s

local function run(a: Action)
	if a.Cmd == "Inbox" then
		showInbox()
		return
	end
	if a.Cmd == "UpdatePopup" then
		panel:Close()
		require(script.Parent.UpdatePopup).Show()
		return
	end
	if a.Confirm then
		local t = armed[a.Cmd]
		if not t or os.clock() - t > 4 then
			armed[a.Cmd] = os.clock()
			Kit.Toast("Tap " .. a.Text .. " again to confirm", "Bad")
			return
		end
		armed[a.Cmd] = nil
	end
	local res = State.Request("Dev", a.Cmd, a.Arg)
	if res.ok then
		Kit.Toast(if a.Cmd == "Ecto" then "+" .. Format.Short(a.Arg :: number) .. " Ectoplasm" elseif a.Cmd == "Shards" then "+" .. Format.Short(a.Arg :: number) .. " Spirit Shards" else a.Text .. " ✅", "Good")
	else
		Kit.Toast(res.err or "Failed", "Bad")
	end
end

-- One grid cell: number box + button. Checked here for a quick message; the server re-checks.
local function numberInput(order: number, placeholder: string, text: string, color: string, cmd: string, max: number, done: (number) -> string)
	local cell: Frame = Kit.new("Frame", { BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.3, LayoutOrder = order, ZIndex = 62, Parent = list })
	Kit.Corner(cell, UDim.new(0, 10))
	local box: TextBox = Kit.new("TextBox", {
		Size = UDim2.new(0, 70, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = Theme.Body,
		TextSize = Theme.Type.Body,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Muted,
		PlaceholderText = placeholder,
		Text = "",
		ZIndex = 63,
		Parent = cell,
	})
	Kit.Button(cell, { Text = text, Color = color, TextStyle = "Small", Size = UDim2.new(1, -80, 1, -6), Position = UDim2.new(1, -3, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 63, OnClick = function()
		local n = tonumber(box.Text)
		if not n or n % 1 ~= 0 or n < 1 or n > max then
			Kit.Toast("Enter a whole number 1-" .. Format.Short(max), "Bad")
			return
		end
		local res = State.Request("Dev", cmd, n)
		if res.ok then
			Kit.Toast(done(n), "Good")
		else
			Kit.Toast(res.err or "Failed", "Bad")
		end
	end })
	table.insert(actionButtons, cell)
end

--------------------------------------------------------------------------------
-- Rare pet launch event (admins only; the server checks again)
--------------------------------------------------------------------------------
local RARE_ROW_H = 58

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
		text = (if active then "🏮 RARE PET EVENT: ACTIVE" else "🏮 RARE PET EVENT: ENDED") .. "\nStart " .. utc(startT) .. "  ·  End " .. utc(endT)
		color = if active then Theme.Good else Theme.Muted
	elseif rareBusy then
		text = "🏮 RARE PET EVENT: Starting..."
	elseif not checked then
		text = "🏮 RARE PET EVENT: Checking..."
	else
		text = "🏮 RARE PET EVENT: Not started"
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
	rareButton.AutoButtonColor = false
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
		Kit.Toast("Rare Pet Event started ✅", "Good")
	else
		rareMsg = res.err or "Failed"
		rareMsgBad = true
		Kit.Toast(rareMsg :: string, "Bad")
	end
	refreshRare()
	panel:Open()
end

local function buildRare()
	rareRow = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, RARE_ROW_H), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = Theme.Bg, BackgroundTransparency = 0.3, Visible = false, ZIndex = 61, Parent = panel.Body })
	Kit.Corner(rareRow, UDim.new(0, 10))
	rareStatus = Kit.Label(rareRow, "🏮 RARE PET EVENT: Checking...", { Size = UDim2.new(1, -212, 1, -6), Position = UDim2.fromOffset(10, 3), Align = Enum.TextXAlignment.Left, Font = Theme.Body, Style = "Tiny", Stroke = 0, Wrap = true, ZIndex = 62 })
	rareButton = Kit.Button(rareRow, {
		Text = "START RARE PET EVENT",
		Color = "Orange",
		Size = UDim2.fromOffset(190, 42),
		Position = UDim2.new(1, -6, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextStyle = "Small",
		ZIndex = 62,
		OnClick = function()
			if not rareButton.Active then
				refreshRare()
				return
			end
			rareConfirm:Open()
		end,
	})

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

function DevPanel.Init()
	panel = Kit.Panel("Dev", "🛠 DEV TOOLS", Vector2.new(620, 400), "Gray")
	list = Kit.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.fromOffset(0, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 61,
		Parent = panel.Body,
	})
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(180, 46), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), Parent = list })
	for i, a in ACTIONS do
		if a.StudioOnly and not RunService:IsStudio() then
			continue
		end
		local b = Kit.Button(list, { Text = a.Text, Color = a.Color, TextStyle = "Small", ZIndex = 62, OnClick = function()
			run(a)
		end })
		b.LayoutOrder = i
		table.insert(actionButtons, b)
		if i == 1 then
			panel.Primary = b
		end
	end
	numberInput(#ACTIONS + 1, "amount", "GIVE SHARDS", "Teal", "Shards", 1000000, function(n)
		return "+" .. Format.Short(n) .. " Spirit Shards"
	end)
	numberInput(#ACTIONS + 2, "room", "TOWER ROOM", "Orange", "TowerRoom", 400, function(n)
		panel:Close()
		return "Tower room " .. n .. " ✅"
	end)
	buildRare()
	Kit.Label(panel.Body, "Only you can see this. In a live server these change your real save.", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), Color = Theme.Muted, Font = Theme.Body, Style = "Tiny", Stroke = 0, ZIndex = 62 })

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
	local function refresh()
		local isDev = player:GetAttribute("IsDev") == true
		local isAdmin = player:GetAttribute("RarePetAdmin") == true
		devButton.Visible = isDev or isAdmin
		for _, b in actionButtons do
			b.Visible = isDev
		end
		rareRow.Visible = isAdmin
		local top = if isAdmin then RARE_ROW_H + 12 else 8
		list.Position = UDim2.fromOffset(0, top)
		list.Size = UDim2.new(1, 0, 1, -26 - top)
		refreshRare()
	end
	player:GetAttributeChangedSignal("IsDev"):Connect(refresh)
	player:GetAttributeChangedSignal("RarePetAdmin"):Connect(refresh)
	for _, attr in { "RarePetStart", "RarePetEnd", "RarePetChecked" } do
		workspace:GetAttributeChangedSignal(attr):Connect(refreshRare)
	end
	refresh()
	-- Active -> Ended needs no message: re-check the clock while the panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.IsOpen and rareRow.Visible then
				refreshRare()
			end
		end
	end)
end

return DevPanel
