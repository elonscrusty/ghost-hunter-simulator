--!strict
-- DEV panel: owner-only test tools. The 🛠 button appears only when the server marked this
-- player as a developer (attribute "IsDev"); every action is checked again on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)

local DevPanel = {}

local player = Players.LocalPlayer
local panel: Kit.Panel
local inbox: Kit.Panel
local inboxList: ScrollingFrame
local devButton: TextButton

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
		local head = (if e.Kind == "Bug" then "🐞 BUG" else "💡 IDEA") .. "  •  " .. tostring(e.Name) .. "  •  " .. tostring(e.Zone) .. "  •  " .. os.date("%Y-%m-%d %H:%M", e.T or 0) .. "  •  v" .. tostring(e.Version)
		local h = Kit.Label(f, head, { Size = UDim2.new(1, 0, 0, 16), Align = Enum.TextXAlignment.Left, Color = if e.Kind == "Bug" then Theme.Bad else Theme.Ecto, Style = "Tiny", Fit = true, ZIndex = 63 })
		h.LayoutOrder = 1
		local t = Kit.Label(f, tostring(e.Text), { Size = UDim2.new(1, 0, 0, 0), Align = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Body, Style = "Small", Stroke = 0, ZIndex = 63 })
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.LayoutOrder = 2
	end
	panel:Close()
	inbox:Open()
end

type Action = { Text: string, Cmd: string, Arg: any?, Color: string }
local ACTIONS: { Action } = {
	{ Text = "+10K ECTO", Cmd = "Ecto", Arg = 10000, Color = "Green" },
	{ Text = "+1M ECTO", Cmd = "Ecto", Arg = 1000000, Color = "Green" },
	{ Text = "+1B ECTO", Cmd = "Ecto", Arg = 1000000000, Color = "Green" },
	{ Text = "+1T ECTO", Cmd = "Ecto", Arg = 1000000000000, Color = "Green" },
	{ Text = "UNLOCK ALL AREAS", Cmd = "Zones", Color = "Blue" },
	{ Text = "ALL 32 HUNTERS", Cmd = "Hunters", Color = "Orange" },
	{ Text = "MAX UPGRADES", Cmd = "MaxUpgrades", Color = "Teal" },
	{ Text = "START EVENT", Cmd = "Event", Color = "Pink" },
	{ Text = "RESET DAILY", Cmd = "ResetDaily", Color = "Purple" },
	{ Text = "AUTO ATTACK PASS", Cmd = "AutoAttack", Color = "Purple" },
	{ Text = "REPLAY TUTORIAL", Cmd = "Tutorial", Color = "Gray" },
	{ Text = "💬 READ FEEDBACK", Cmd = "Inbox", Color = "Blue" },
}

local function run(a: Action)
	if a.Cmd == "Inbox" then
		showInbox()
		return
	end
	local res = State.Request("Dev", a.Cmd, a.Arg)
	if res.ok then
		Kit.Toast(if a.Cmd == "Ecto" then "+" .. Format.Short(a.Arg :: number) .. " Ectoplasm" else a.Text .. " ✓", "Good")
	else
		Kit.Toast(res.err or "Failed", "Bad")
	end
end

function DevPanel.Init()
	panel = Kit.Panel("Dev", "🛠 DEV TOOLS", Vector2.new(620, 360), "Gray")
	local list: ScrollingFrame = Kit.new("ScrollingFrame", {
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
		local b = Kit.Button(list, { Text = a.Text, Color = a.Color, TextStyle = "Small", ZIndex = 62, OnClick = function()
			run(a)
		end })
		b.LayoutOrder = i
		if i == 1 then
			panel.Primary = b
		end
	end
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

	devButton = Kit.Button(Kit.Screen(), {
		Text = "🛠",
		Color = "Gray",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -60, 0.5, -48),
		AnchorPoint = Vector2.new(1, 0.5),
		TextStyle = "Heading",
		OnClick = function()
			panel:Toggle()
		end,
	})
	devButton.Visible = false
end

function DevPanel.Start()
	local function refresh()
		devButton.Visible = player:GetAttribute("IsDev") == true
	end
	player:GetAttributeChangedSignal("IsDev"):Connect(refresh)
	refresh()
end

return DevPanel
