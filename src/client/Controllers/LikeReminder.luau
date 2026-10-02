--!strict
-- A friendly reminder to like the game, shown once per session after a while of play.
-- No reward (Roblox doesn't allow rewards for likes) and nothing blocks the screen.
local Theme = require(script.Parent.Parent.UI.Theme)
local Hud = require(script.Parent.Hud)

local LikeReminder = {}

local FIRST_AFTER = 10 * 60 -- seconds of play before the reminder

function LikeReminder.Init() end

function LikeReminder.Start()
	task.delay(FIRST_AFTER, function()
		Hud.Banner("HAVING FUN? 👻", "Tap 👍 on the game page to help Ghost Hunters grow!", Theme.Ecto)
	end)
end

return LikeReminder
