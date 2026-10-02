--!strict
-- 2X ECTOPLASM EVENT announcement. Shown when a developer turns the global event on, and once
-- after joining while it is already on. Closing it only hides the popup (the event keeps
-- running; the "2X ECTOPLASM EVENT" chip under the counters stays while it's active).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Sound = require(script.Parent.Sound)

local EventPopup = {}

local panel: Kit.Panel
local shownThisSession = false
local _ = GH

local function show()
	if panel.IsOpen then
		return
	end
	shownThisSession = true
	Sound.Play("ZoneUnlock")
	panel:Open()
end

function EventPopup.Init()
	panel = Kit.Panel("Ecto2xEvent", "2X ECTOPLASM EVENT!", Vector2.new(460, 270), "Green")
	local body = panel.Body
	local big = Kit.Label(body, "2X", { Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 10), Color = Theme.Ecto, Style = "Banner", TextSize = 56, ZIndex = 62, Stroke = 3 })
	Kit.new("UIGradient", { Color = ColorSequence.new(Theme.Ecto, Theme.Gold), Rotation = 90, Parent = big })
	Kit.Label(body, "Earn DOUBLE Ectoplasm from ghosts while the event is active!", { Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 80), Style = "Body", ZIndex = 62 })
	local ok = Kit.Button(body, {
		Text = "LET'S HUNT!",
		Color = "Green",
		Size = UDim2.fromOffset(220, 48),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = function()
			panel:Close()
		end,
	})
	panel.Primary = ok
end

function EventPopup.Start()
	State.OnFx("Ecto2xEvent", function(data: any)
		if type(data) == "table" and data.On == true then
			show()
		elseif panel.IsOpen then
			panel:Close()
		end
	end)
	-- joined while the event is already on: show it once, after loading settles
	task.spawn(function()
		State.WaitForData()
		task.wait(4)
		if workspace:GetAttribute("Ecto2x") == true and not shownThisSession and not Kit.CurrentPanel() then
			show()
		end
	end)
end

return EventPopup
