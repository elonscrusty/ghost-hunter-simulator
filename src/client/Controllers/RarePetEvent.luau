--!strict
-- FREE RARE PET launch event (client). While the global event is active (workspace attributes
-- RarePetStart / RarePetEnd, set by RarePetEventService) a small chip under the counters shows
-- the time left and this player's progress ("12/30 MIN"); tapping it opens a panel with the
-- reward preview. Progress comes from player attribute "RarePetPlay" (live, every few seconds)
-- with State.Data.EventPlay as the fallback. The server decides everything; this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Client = script.Parent.Parent
local State = require(Client.State)
local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Hud = require(script.Parent.Hud)
local Sound = require(script.Parent.Sound)

local RarePetEvent = {}

local E = Config.RarePetEvent
local player = Players.LocalPlayer

local chip: TextButton
local chipLabel: TextLabel
local panel: Kit.Panel
local barFill: Frame
local progressLabel: TextLabel
local timeLabel: TextLabel
local noteLabel: TextLabel

local function window(): (number?, number?)
	local s = workspace:GetAttribute("RarePetStart")
	local e = workspace:GetAttribute("RarePetEnd")
	if workspace:GetAttribute("RarePetEventId") == E.Id and type(s) == "number" and type(e) == "number" then
		return s, e
	end
	return nil, nil
end

local function progress(): (number, boolean)
	local s = player:GetAttribute("RarePetPlay")
	local g = player:GetAttribute("RarePetGot")
	local seconds = if type(s) == "number" then s else 0
	local got = g == true
	local d = State.Data
	local ev = d and d.EventPlay and d.EventPlay[E.Id]
	if type(ev) == "table" then
		if type(ev.S) == "number" then
			seconds = math.max(seconds, ev.S)
		end
		got = got or ev.G == true
	end
	return seconds, got
end

local function bonusText(kind: string, value: number): string
	local names: { [string]: string } = { Power = "Power", Ecto = "Ectoplasm", HP = "Hunter HP", Recovery = "Recovery" }
	return "+" .. Format.Percent(value) .. " " .. (names[kind] or kind) .. " for ALL hunters"
end

local function update()
	local startT, endT = window()
	local now = State.Now()
	local active = startT ~= nil and endT ~= nil and now >= (startT :: number) and now < (endT :: number)
	chip.Visible = active
	if not active and panel.IsOpen then
		panel:Close()
	end
	if not active then
		return
	end
	local left = (endT :: number) - now
	local seconds, got = progress()
	local req = E.RequiredSeconds
	local mins = math.min(seconds, req) // 60
	local reqMins = req // 60
	if got then
		chipLabel.Text = "🏮 RARE PET EARNED!  ·  " .. Format.Time(left)
	else
		chipLabel.Text = string.format("🏮 FREE RARE PET %d/%d MIN  ·  %s", mins, reqMins, Format.Time(left))
	end
	if panel.IsOpen then
		local frac = math.clamp(seconds / req, 0, 1)
		barFill.Size = UDim2.fromScale(if got then 1 else frac, 1)
		progressLabel.Text = if got then "✅ EARNED - check your pets!" else string.format("%d / %d MIN PLAYED", mins, reqMins)
		timeLabel.Text = "Event ends in " .. Format.Time(left)
		noteLabel.Text = if got then "Thanks for playing the launch event!" else string.format("Play %d minutes before the event ends. Idle time doesn't count.", reqMins)
	end
end

function RarePetEvent.Init()
	local def = Config.Pets[E.Pet]
	local rarity = def and Config.Rarities[def.Rarity]
	local parent: Instance = Hud.TopStack or Kit.Screen()
	chip = Kit.new("TextButton", {
		Name = "RarePetChip",
		Size = UDim2.fromOffset(250, 24),
		BackgroundColor3 = Theme.Panel2,
		BackgroundTransparency = 0.05,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = 4,
		Visible = false,
		Parent = parent,
	})
	if parent ~= Hud.TopStack then
		chip.Position = UDim2.new(0.5, 0, 0, 120)
		chip.AnchorPoint = Vector2.new(0.5, 0)
	end
	Kit.Corner(chip, UDim.new(1, 0))
	Kit.Stroke(chip, 2, Theme.Gold, Enum.ApplyStrokeMode.Border)
	chipLabel = Kit.Label(chip, "", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), Color = Theme.Gold, Style = "Tiny", Fit = true })
	chip.Activated:Connect(function()
		panel:Open()
		update()
	end)

	panel = Kit.Panel("RarePetEvent", "🏮 FREE RARE PET!", Vector2.new(480, 320), "Orange")
	local body = panel.Body
	Kit.Label(body, if def then def.Name else E.Pet, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 14), Color = if rarity then rarity.Color else Theme.Gold, Style = "Heading", TextSize = 26, ZIndex = 62 })
	local sub = (if rarity then rarity.Name else (if def then def.Rarity else "Rare")) .. " ghost pet  ·  " .. (if def then bonusText(def.Bonus.Kind, def.Bonus.Value) else "")
	Kit.Label(body, sub, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 50), Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, Fit = true, ZIndex = 62 })
	local bar: Frame = Kit.new("Frame", { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 88), BackgroundColor3 = Theme.Bg, ZIndex = 62, Parent = body })
	Kit.Corner(bar, UDim.new(1, 0))
	Kit.Stroke(bar, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	barFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Gold, ZIndex = 63, Parent = bar })
	Kit.Corner(barFill, UDim.new(1, 0))
	progressLabel = Kit.Label(bar, "", { Size = UDim2.fromScale(1, 1), Style = "Tiny", ZIndex = 64 })
	timeLabel = Kit.Label(body, "", { Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 118), Color = Theme.Gold, Style = "Body", ZIndex = 62 })
	noteLabel = Kit.Label(body, "", { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 146), Font = Theme.Body, Style = "Small", Stroke = 0, Wrap = true, ZIndex = 62 })
	local ok = Kit.Button(body, {
		Text = "LET'S HUNT!",
		Color = "Orange",
		Size = UDim2.fromOffset(220, 46),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = function()
			panel:Close()
		end,
	})
	panel.Primary = ok
end

function RarePetEvent.Start()
	State.OnFx("RarePetGranted", function(data: any)
		local name = if type(data) == "table" and type(data.Name) == "string" then data.Name else "a Rare pet"
		Sound.Play("ZoneUnlock")
		Kit.Toast("🏮 You earned " .. name .. "! It's in your pets.", "Gold")
		update()
	end)
	State.OnFx("RarePetEventStarted", function(_data: any)
		update()
		-- shown once the player isn't using a menu / watching a reveal (never closes one)
		Kit.WhenFree(function()
			update()
			if chip.Visible and not panel.IsOpen then
				panel:Open()
				update()
			end
		end)
	end)
	for _, attr in { "RarePetEventId", "RarePetStart", "RarePetEnd" } do
		workspace:GetAttributeChangedSignal(attr):Connect(update)
	end
	player:GetAttributeChangedSignal("RarePetPlay"):Connect(update)
	player:GetAttributeChangedSignal("RarePetGot"):Connect(update)
	State.OnData(function(_d: any)
		update()
	end)
	task.spawn(function()
		while true do
			update()
			task.wait(1)
		end
	end)
end

return RarePetEvent
