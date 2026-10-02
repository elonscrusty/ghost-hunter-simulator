--!strict
-- TOP GHOST HUNTERS board beside the spawn plaza (Config.Layout.Leaderboard). The board is a
-- SurfaceGui with a title and Config.Leaderboard.Rows rows ("Row1".."RowN", each with Rank / Name
-- / Value labels); LeaderboardService fills them in.
local Config = require(game:GetService("ReplicatedStorage").GH.Config)
local Kit = require(script.Parent.Kit)

local Leaderboard = {}

local C = Color3.fromRGB
local V = Vector3.new

function Leaderboard.Build(map: Instance)
	local L = Config.Layout.Leaderboard
	local m = Kit.Model(Kit.Folder(map, "Leaderboard"), "TopHunters")
	local base = CFrame.new(L.Position) * CFrame.Angles(0, L.Yaw, 0)
	local W, H, BOTTOM = 18, 20, 3
	local wood = C(120, 80, 55)
	-- posts + feet
	for _, s in { -1, 1 } do
		Kit.Part(m, V(1.4, BOTTOM + H + 1, 1.4), base * CFrame.new(s * (W / 2 + 0.7), (BOTTOM + H + 1) / 2, 0.4), wood, { Mat = Enum.Material.Wood, Solid = true })
		Kit.Part(m, V(3, 0.6, 3), base * CFrame.new(s * (W / 2 + 0.7), 0.3, 0.4), C(90, 70, 110), { Mat = Enum.Material.Slate, Solid = true })
		Kit.Ball(m, 2, (base * CFrame.new(s * (W / 2 + 0.7), BOTTOM + H + 2, 0.4)).Position, Kit.Vivid(C(255, 200, 60)))
	end
	-- frame + board face (front = local -Z)
	Kit.Part(m, V(W + 1.2, H + 1.2, 0.8), base * CFrame.new(0, BOTTOM + H / 2, 0.6), Kit.Vivid(C(150, 90, 230)), { Solid = true })
	local board = Kit.Part(m, V(W, H, 0.6), base * CFrame.new(0, BOTTOM + H / 2, 0.2), C(35, 22, 60), { Solid = true, Name = "Board" })
	-- topper: crown shape
	Kit.Part(m, V(8, 2.4, 0.8), base * CFrame.new(0, BOTTOM + H + 1.6, 0.6), Kit.Vivid(C(255, 200, 60)), { Mat = Enum.Material.Metal })
	for i = -1, 1 do
		Kit.Wedge(m, V(0.8, 2, 2), base * CFrame.new(i * 3, BOTTOM + H + 3.8, 0.6) * CFrame.Angles(0, math.pi / 2, 0), Kit.Vivid(C(255, 200, 60)), { Mat = Enum.Material.Metal })
	end

	local gui = Kit.Gui(board, Enum.NormalId.Front, 30)
	gui.Name = "BoardGui"
	local rows = Config.Leaderboard.Rows
	local titleH = 0.15
	Kit.Label(gui, "🏆 TOP GHOST HUNTERS", C(255, 215, 80), { Name = "Title", Pos = UDim2.fromScale(0.04, 0.015), Size = UDim2.fromScale(0.92, titleH - 0.03) })
	Kit.Label(gui, "ALL-TIME ECTOPLASM", C(150, 255, 170), { Name = "Sub", Pos = UDim2.fromScale(0.2, titleH - 0.02), Size = UDim2.fromScale(0.6, 0.05) })
	local rowH = (1 - titleH - 0.06) / rows
	for i = 1, rows do
		local y = titleH + 0.045 + (i - 1) * rowH
		local row: Frame = Instance.new("Frame")
		row.Name = "Row" .. i
		row.BackgroundColor3 = if i % 2 == 0 then C(55, 38, 90) else C(45, 30, 75)
		row.BorderSizePixel = 0
		row.Position = UDim2.fromScale(0.03, y)
		row.Size = UDim2.fromScale(0.94, rowH * 0.92)
		row.Parent = gui
		local rankColor = if i == 1 then C(255, 215, 80) elseif i == 2 then C(220, 225, 240) elseif i == 3 then C(240, 160, 90) else C(200, 190, 230)
		Kit.Label(row, "#" .. i, rankColor, { Name = "Rank", Pos = UDim2.fromScale(0.01, 0.1), Size = UDim2.fromScale(0.12, 0.8) })
		Kit.Label(row, "...", C(255, 255, 255), { Name = "PlayerName", Pos = UDim2.fromScale(0.15, 0.1), Size = UDim2.fromScale(0.52, 0.8) })
		Kit.Label(row, "", C(150, 255, 170), { Name = "Value", Pos = UDim2.fromScale(0.69, 0.1), Size = UDim2.fromScale(0.3, 0.8) })
	end
	local p = L.Position
	Kit.AddRect(p.X - 12, p.Z - 12, p.X + 12, p.Z + 12)
end

return Leaderboard
