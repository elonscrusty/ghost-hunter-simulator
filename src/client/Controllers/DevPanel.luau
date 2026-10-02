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
local devButton: TextButton

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
}

local function run(a: Action)
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
