--!strict
-- GHOST HUNTER SIMULATOR client entry: initialises every controller, then starts them.
local StarterGui = game:GetService("StarterGui")

local State = require(script.Parent.State)
State.Init()

-- no tools or health in this game: keep the screen clean
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

local Controllers = script.Parent.Controllers
local order = {
	"Sound",
	"Effects",
	"Hud",
	"Ghosts",
	"Targeting",
	"Crew",
	"Orbs",
	"Reveal",
	"CratePanel",
	"HuntersPanel",
	"IndexPanel",
	"UpgradesPanel",
	"ShopPanel",
	"DailyPanel",
	"GatePanel",
	"WorldsPanel",
	"DevPanel",
	"FeedbackPanel",
	"Boss",
	"Ambience",
	"Tutorial",
}
local loaded: { any } = {}
for _, name in order do
	local mod = require(Controllers:FindFirstChild(name) :: ModuleScript) :: any
	table.insert(loaded, mod)
	if mod.Init then
		mod.Init()
	end
end
for _, mod in loaded do
	if mod.Start then
		task.spawn(mod.Start)
	end
end
