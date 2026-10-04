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
local eventOn = false -- latest on/off from the Ecto2xEvent Fx
local _ = GH

-- waits until no menu is open and no crate reveal is playing (never closes what you're using)
local queued = false
local function show()
	shownThisSession = true
	if queued then
		return -- one popup is already waiting for a free screen
	end
	queued = true
	Kit.WhenFree(function()
		queued = false
		if panel.IsOpen or not (eventOn or workspace:GetAttribute("Ecto2x") == true) then
			return -- already showing, or the event ended while we waited
		end
		Sound.Play("ZoneUnlock")
		panel:Open()
	end)
end

function EventPopup.Init()
	panel = Kit.Panel("Ecto2xEvent", "2X ECTOPLASM EVENT!", Vector2.new(460, 270), "Green")
	local body = panel.Body
	-- solid colour, no UIGradient: on phones the gradient-filled 56 px "2X" lost its "2" and
	-- flickered (seen in a player recording)
	Kit.Label(body, "2X", { Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 12), Color = Theme.Ecto, Style = "Banner", ZIndex = 62, Stroke = 3 })
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
		eventOn = type(data) == "table" and data.On == true
		if eventOn then
			show()
		elseif panel.IsOpen then
			panel:Close()
		end
	end)
	-- joined while the event is already on: show it once, after loading settles
	task.spawn(function()
		State.WaitForData()
		task.wait(4)
		if workspace:GetAttribute("Ecto2x") == true and not shownThisSession then
			show()
		end
	end)
end

return EventPopup
