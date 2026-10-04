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

-- "Loading your hunters..." until the first data snapshot arrives (a slow DataStore load used
-- to show an empty HUD with 0 Ectoplasm, which looks like lost progress)
task.spawn(function()
	if State.Data then
		return
	end
	local Kit = require(script.Parent.UI.Kit)
	local Theme = require(script.Parent.UI.Theme)
	local cover: Frame = Kit.new("Frame", {
		Name = "Loading",
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(-1.5, -1.5),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
		ZIndex = 200,
		Parent = Kit.Overlay(),
	})
	local box: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(420, 90), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 201, Parent = cover })
	local title = Kit.Label(box, "Loading your hunters...", { Size = UDim2.new(1, 0, 0, 36), Style = "Heading", ZIndex = 202 })
	local hint = Kit.Label(box, "Still loading - your progress is safe", { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 44), Color = Theme.Muted, Style = "Small", ZIndex = 202 })
	hint.Visible = false
	task.delay(10, function()
		if cover.Parent then
			hint.Visible = true
		end
	end)
	State.WaitForData()
	for _, l in { title, hint } do
		Kit.Tween(l, 0.3, { TextTransparency = 1 })
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			Kit.Tween(st, 0.3, { Transparency = 1 })
		end
	end
	Kit.Tween(cover, 0.3, { BackgroundTransparency = 1 })
	task.wait(0.3)
	cover:Destroy()
end)

local Controllers = script.Parent.Controllers
local order = {
	"Sound",
	"Effects",
	"Hud",
	"Ghosts",
	"PetFollowers",
	"Targeting",
	"Crew",
	"Orbs",
	"Reveal",
	"CratePanel",
	"HuntersPanel",
	"TradePanel",
	"IndexPanel",
	"UpgradesPanel",
	"ShopPanel",
	"PetsPanel",
	"Hatchery",
	"DailyPanel",
	"GatePanel",
	"WorldsPanel",
	"DevPanel",
	"FeedbackPanel",
	"EventPopup",
	"UpdatePopup",
	"LikeReminder",
	"Boss",
	"TowerHud",
	"Payouts",
	"RarePetEvent",
	"Ambience",
	"MenuTour",
	"Tutorial",
}
-- one broken controller must not take the whole UI down with it: each one loads, inits and
-- starts inside pcall (like the server's Main) and a failure is only a warning
local loaded: { { Name: string, Mod: any } } = {}
for _, name in order do
	local ok, mod = pcall(require, Controllers:FindFirstChild(name) :: ModuleScript)
	if not ok then
		warn("[Main] couldn't load " .. name .. ": " .. tostring(mod))
		continue
	end
	table.insert(loaded, { Name = name, Mod = mod })
	if (mod :: any).Init then
		local okInit, err = pcall((mod :: any).Init)
		if not okInit then
			warn("[Main] " .. name .. ".Init failed: " .. tostring(err))
		end
	end
end
for _, entry in loaded do
	local start = entry.Mod.Start
	if start then
		task.spawn(function()
			local okStart, err = pcall(start)
			if not okStart then
				warn("[Main] " .. entry.Name .. ".Start failed: " .. tostring(err))
			end
		end)
	end
end
