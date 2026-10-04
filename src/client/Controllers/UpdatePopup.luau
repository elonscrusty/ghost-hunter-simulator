--!strict
-- WHAT'S NEW popup (Config.UpdateNotes): once per update version, a short list of what changed.
-- Waits until no menu or crate reveal is open; closing it tells the server it was seen.
-- Brand-new players (tutorial not finished) skip it: everything is new to them anyway.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Sound = require(script.Parent.Sound)

local UpdatePopup = {}

local panel: Kit.Panel
local notes = Config.UpdateNotes

function UpdatePopup.Init()
	local lines = #notes.Lines
	panel = Kit.Panel("UpdateNotes", notes.Title, Vector2.new(480, 130 + lines * 34), "Purple")
	local body = panel.Body
	Kit.Label(body, "Update " .. notes.Version, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 6), Color = Theme.Gold, Style = "Body", ZIndex = 62 })
	for i, text in notes.Lines do
		Kit.Label(body, text, {
			Size = UDim2.new(1, -24, 0, 30),
			Position = UDim2.fromOffset(12, 6 + i * 34),
			Align = Enum.TextXAlignment.Left,
			Font = Theme.Body,
			Style = "Small",
			Wrap = true,
			ZIndex = 62,
			Stroke = 0,
		})
	end
	local ok = Kit.Button(body, {
		Text = "LET'S GO!",
		Color = "Green",
		Size = UDim2.fromOffset(200, 46),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = function()
			panel:Close()
		end,
	})
	panel.Primary = ok
end

-- DEV panel preview
function UpdatePopup.Show()
	panel:Open()
end

function UpdatePopup.Start()
	task.spawn(function()
		local d = State.WaitForData()
		if d.SeenUpdate == notes.Version then
			return
		end
		if (d.Tutorial or 1) <= #Config.Tutorial.Steps then
			State.Request("SeenUpdate") -- new player: nothing to catch up on
			return
		end
		task.wait(3)
		Kit.WhenFree(function()
			Sound.Play("ZoneUnlock")
			panel:Open()
			State.Request("SeenUpdate")
		end)
	end)
end

return UpdatePopup
