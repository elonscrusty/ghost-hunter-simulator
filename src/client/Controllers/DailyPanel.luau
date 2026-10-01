--!strict
-- DAILY reward: Day 1-7 tiles, a big golden Day 7, CLAIM button or a countdown.
-- Timing is decided by the server's clock (the client only displays it).
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
local Effects = require(script.Parent.Effects)

local DailyPanel = {}

type Tile = { Frame: Frame, Check: TextLabel, Today: TextLabel, Reward: TextLabel, Scale: UIScale }

local panel: Kit.Panel
local tiles: { Tile } = {}
local claimButton: TextButton
local statusLabel: TextLabel
local busy = false

local function rewardLabel(i: number, mult: number): string
	local r = Config.Daily.Rewards[i]
	if r.Amount and mult > 1 then
		return (r.Label:gsub(Format.Commas(r.Amount), Format.Commas(r.Amount * mult)))
	end
	return r.Label
end

local function remaining(d: any): number
	local info = d.DailyInfo
	if not info then
		return 0
	end
	return math.max(0, info.Wait - (State.Now() - (d.ServerTime or State.Now())))
end

local function refresh()
	local d = State.Data
	if not d or not d.DailyInfo then
		return
	end
	local info = d.DailyInfo
	local left = remaining(d)
	local canClaim = info.CanClaim or left <= 0
	local day = info.Day
	local claimed = if canClaim then day - 1 elseif day == 1 then #Config.Daily.Rewards else day - 1
	local mult = d.ZoneMultiplier or 1
	for i, t in tiles do
		t.Reward.Text = rewardLabel(i, mult)
		t.Check.Visible = i <= claimed
		t.Today.Visible = canClaim and i == day
		t.Frame.BackgroundTransparency = if i <= claimed then 0.45 else 0
	end
	if canClaim then
		Kit.SetButtonText(claimButton, "CLAIM DAY " .. day .. "!")
		claimButton:SetAttribute("Color", "Green")
		statusLabel.Text = if info.StreakBroken then "Streak reset - start again from Day 1!" else "Come back every day for bigger rewards!"
	else
		Kit.SetButtonText(claimButton, "NEXT IN " .. Format.Time(left))
		claimButton:SetAttribute("Color", "Gray")
		statusLabel.Text = "Day " .. day .. " unlocks in " .. Format.Time(left) .. ". Don't miss a day or your streak resets!"
	end
end

local function claim()
	if busy then
		return
	end
	busy = true
	local res = State.Request("ClaimDaily")
	busy = false
	if not res.ok then
		Kit.Toast(res.err or "Not yet!", "Bad")
		return
	end
	Sound.Play("Daily")
	Hud.Banner("DAY " .. tostring(res.Day) .. " REWARD!", res.Label, Theme.Gold)
	local t = tiles[res.Day]
	if t then
		t.Scale.Scale = 1.25
		Kit.Tween(t.Scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Effects.Burst(root.Position + Vector3.new(0, 2, 0), { Color = Theme.Gold, Color2 = Theme.Ecto, Count = 50, Size = 1, Speed = 20 })
	end
end

function DailyPanel.Init()
	panel = Kit.Panel("Daily", "DAILY REWARDS", Vector2.new(820, 520), "Purple")
	local grid: Frame = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 330), Position = UDim2.fromOffset(0, 18), BackgroundTransparency = 1, ZIndex = 61, Parent = panel.Body })
	local W, H, G = 180, 156, 12
	local startX = (784 - (4 * W + 3 * G)) / 2
	for i = 1, #Config.Daily.Rewards do
		local big = i == #Config.Daily.Rewards
		local row = if i <= 4 then 0 else 1
		local col = if i <= 4 then i - 1 else i - 5
		local f: Frame = Kit.new("Frame", {
			Size = UDim2.fromOffset(if big then 2 * W + G else W, H),
			Position = UDim2.fromOffset(startX + col * (W + G), row * (H + G)),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 62,
			Parent = grid,
		})
		Kit.Corner(f, UDim.new(0, 18))
		Kit.Stroke(f, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
		if big then
			Kit.Gradient(f, Theme.Gold, Color3.fromRGB(255, 120, 40), 90)
		else
			Kit.Gradient(f, Theme.Panel3, Theme.Panel2, 90)
		end
		local sc = Kit.new("UIScale", { Parent = f })
		Kit.Label(f, "DAY " .. i, { Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 8), ZIndex = 63 })
		local r = Config.Daily.Rewards[i]
		local icon = if r.Kind == "Day7" then "🎁" elseif r.Kind == "Boost" then (if r.Boost == "Luck" then "🍀" else "⚡") else "💚"
		Kit.Label(f, icon, { Size = UDim2.fromOffset(60, 50), Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 63, Stroke = 0 })
		local reward = Kit.Label(f, r.Label, { Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 98), ZIndex = 63, Color = Color3.fromRGB(255, 255, 230) })
		local check = Kit.Label(f, "✓", { Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Good, ZIndex = 66, Stroke = 4 })
		check.Visible = false
		local today = Kit.Label(f, "TODAY!", { Size = UDim2.fromOffset(100, 28), Position = UDim2.new(1, 6, 0, -12), AnchorPoint = Vector2.new(1, 0), Color = Theme.Ecto, ZIndex = 67, Stroke = 3 })
		today.Rotation = 8
		today.Visible = false
		table.insert(tiles, { Frame = f, Check = check, Today = today, Reward = reward, Scale = sc })
	end
	statusLabel = Kit.Label(panel.Body, "", { Size = UDim2.new(1, -40, 0, 26), Position = UDim2.new(0, 20, 1, -96), Color = Theme.Muted, Font = Theme.Body, ZIndex = 62, Stroke = 0 })
	claimButton = Kit.Button(panel.Body, {
		Text = "CLAIM",
		Color = "Green",
		Size = UDim2.fromOffset(340, 64),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 63,
		OnClick = claim,
	})
	Hud.RegisterPanel("Daily", function()
		panel:Toggle()
	end)
end

function DailyPanel.Start()
	panel.OnOpen.Event:Connect(refresh)
	State.Changed:Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.IsOpen then
				refresh()
			end
		end
	end)
	-- a returning player with a reward waiting gets the panel once, a few seconds after joining
	task.spawn(function()
		local d = State.WaitForData()
		task.wait(6)
		if d.DailyInfo and d.DailyInfo.CanClaim and (d.Tutorial or 1) > #Config.Tutorial.Steps and not Kit.CurrentPanel() then
			panel:Open()
		end
	end)
end

return DailyPanel
