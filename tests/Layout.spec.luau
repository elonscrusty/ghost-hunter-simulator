-- HUD side-menu layout maths (src/shared/Logic/Layout): proves, for phone / tablet / desktop
-- screens, that menu labels render >= 10 real px, every tap target is >= 44 real px with real
-- gaps, and the menus overlap neither each other, the jump button nor the centre HUD.
local Layout = require("../src/shared/Logic/Layout")
local T = {}

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

-- Same rules as Kit.computeScale / Hud.layoutMenu (Theme.Scale: LandscapeRef 520, PortraitRef
-- 600, clamp 0.55-1; Roblox jump button: 70 px at (1,-95,1,-90) below 500 px, else 120 px at
-- (1,-170,1,-140)). `top` = Roblox top bar inset, `side` = notch inset on each side.
type Screen = { Name: string, X: number, Y: number, Top: number, Side: number, Touch: boolean }
local SCREENS: { Screen } = {
	{ Name = "iPhone 844x390", X = 844, Y = 390, Top = 58, Side = 47, Touch = true },
	{ Name = "iPhone 844x390 (36 px bar)", X = 844, Y = 390, Top = 36, Side = 47, Touch = true },
	{ Name = "iPhone SE 667x375", X = 667, Y = 375, Top = 58, Side = 0, Touch = true },
	{ Name = "phone 1334x750 px", X = 1334, Y = 750, Top = 58, Side = 0, Touch = true },
	{ Name = "tablet 1180x820", X = 1180, Y = 820, Top = 58, Side = 0, Touch = true },
	{ Name = "desktop 1920x1080", X = 1920, Y = 1080, Top = 58, Side = 0, Touch = false },
	{ Name = "laptop 1366x768", X = 1366, Y = 768, Top = 58, Side = 0, Touch = false },
}

local function screenScale(s: Screen): number
	local k = if s.X >= s.Y then s.Y / 520 else s.X / 600
	return math.clamp(k, 0.55, 1)
end

local function layoutFor(s: Screen): (any, number, any)
	local cs = screenScale(s)
	local small = math.min(s.X, s.Y) < 500
	local inp = {
		Scale = cs,
		Width = (s.X - 2 * s.Side) / cs,
		Height = (s.Y - s.Top) / cs,
		Reserve = if s.Touch then (if small then 100 else 225) / cs else 10,
		Lift = 90,
		JumpLeft = if s.Touch then (if small then 95 else 170) / cs else nil, -- Hud ignores the notch inset (safe side)
		TopMin = 0,
		Left = 4,
		Right = 3,
		Small = 4,
	}
	return Layout.Menu(inp), cs, inp
end

-- FredokaOne capitals average ~0.6 em; 0.62 leaves a margin
local function labelFits(text: string, size: number): boolean
	return #text * size * 0.62 <= Layout.Cell - 2 * Layout.LabelPad
end

local LABELS = { "HUNTERS", "INDEX", "WORLDS", "PETS", "UPGRADES", "SHOP", "DAILY" }

local function checkColumn(name: string, sz: any, combined: number)
	local px = function(v: number): number
		return v * combined + 1e-6
	end
	check(px(Layout.Cell) >= Layout.MinTapPx, name .. ": cell width " .. px(Layout.Cell))
	check(px(sz.CellH) >= Layout.MinTapPx, name .. ": cell height " .. px(sz.CellH))
	check(px(sz.Gap) >= Layout.MinGapPx, name .. ": gap " .. px(sz.Gap))
	check(px(sz.RowGap) >= Layout.MinGapPx, name .. ": row gap " .. px(sz.RowGap))
	check(px(sz.Small) >= Layout.MinTapPx, name .. ": corner button " .. px(sz.Small))
	check(px(sz.AutoH) >= Layout.MinTapPx, name .. ": AUTO height " .. px(sz.AutoH))
	local ts = Layout.FitTextSize(Layout.LabelSize, combined, Layout.MinTextPx)
	check(px(ts) >= Layout.MinTextPx, name .. ": label " .. px(ts) .. " px")
	for _, l in LABELS do
		check(labelFits(l, ts), name .. ": " .. l .. " doesn't fit at TextSize " .. ts)
	end
end

T.menus_readable_and_tappable = function()
	for _, s in SCREENS do
		local L, cs = layoutFor(s)
		check(L.Fits, s.Name .. ": layout overflows")
		checkColumn(s.Name .. " right", L.Right, cs * L.RightScale)
		checkColumn(s.Name .. " left", L.Left, cs * L.LeftScale)
		check(cs * L.RightScale >= Layout.MenuFloor - 1e-9 and cs * L.LeftScale >= Layout.MenuFloor - 1e-9, s.Name .. ": below the floor")
	end
end

-- tiny/short phones: text may go under the floor, but nothing may leave the screen
local TINY: { Screen } = {
	{ Name = "iPhone 5s 568x320", X = 568, Y = 320, Top = 58, Side = 0, Touch = true },
	{ Name = "720x320", X = 720, Y = 320, Top = 58, Side = 0, Touch = true },
	{ Name = "640x360", X = 640, Y = 360, Top = 58, Side = 0, Touch = true },
	{ Name = "800x360", X = 800, Y = 360, Top = 58, Side = 0, Touch = true },
}
T.tiny_screens_stay_on_screen = function()
	for _, s in TINY do
		local L, _, inp = layoutFor(s)
		local R = L.Rects
		check(R.Right.Y >= 0 and R.Left.Y >= 0, s.Name .. ": menu runs off the top")
		check(R.Left.Y + R.Left.H <= inp.Height + 1e-6, s.Name .. ": left column runs off the bottom")
		check(not Layout.Overlaps(R.Left, R.Right), s.Name .. ": left column overlaps the right stack")
	end
end

T.menus_never_overlap = function()
	for _, s in SCREENS do
		local L, cs, inp = layoutFor(s)
		local R = L.Rects
		check(not Layout.Overlaps(R.Left, R.Right), s.Name .. ": left column overlaps the right stack")
		check(R.Right.Y >= 4 - 1e-6 and R.Left.Y + R.Left.H <= inp.Height - 10 + 1e-6, s.Name .. ": off screen")
		local others: { [string]: any } = {}
		local cx, h = inp.Width / 2, inp.Height
		local topBar = -s.Top / cs -- the counters / TopStack live in the device-top ScreenGui
		others.counters = { X = cx - 254, Y = topBar + 6, W = 508, H = 40 }
		others.topStack = { X = cx - 220, Y = topBar + 52, W = 440, H = 130 } -- boosts + Boss Tower bar
		others.toasts = { X = cx - 210, Y = 96, W = 420, H = 130 }
		others.towerPad = { X = cx - 240, Y = h - 96 - 78, W = 480, H = 78 }
		others.towerActions = { X = cx - 170, Y = h - 90 - 82, W = 340, H = 82 }
		others.tutorial = { X = cx - 200, Y = h - 110 - 58, W = 400, H = 58 }
		if s.Touch then
			local small = math.min(s.X, s.Y) < 500
			local size, right, bottom = if small then 70 else 120, if small then 95 else 170, if small then 90 else 140
			others.jump = { X = (s.X - right - s.Side) / cs, Y = (s.Y - bottom - s.Top) / cs, W = size / cs, H = size / cs }
		end
		for name, o in others do
			for _, part in { "Left", "Right", "Row" } do
				local r = (R :: any)[part]
				if r then
					check(not Layout.Overlaps(r, o), s.Name .. ": " .. part .. " overlaps " .. name)
				end
			end
		end
		if R.Row then
			check(not Layout.Overlaps(R.Row, R.Right) and not Layout.Overlaps(R.Row, R.Left), s.Name .. ": corner row overlaps a menu")
		end
	end
end

-- big screens keep the old layout exactly: full size, full lift, corner row in the right stack
T.desktop_unchanged = function()
	for _, i in { 6, 7 } do
		local L = layoutFor(SCREENS[i])
		check(not L.Compact and L.RightScale == 1 and L.LeftScale == 1 and L.Lift == 90, SCREENS[i].Name)
		check(L.Right.CellH == 84 and L.Right.Small == 44 and L.Right.Gap == 6, SCREENS[i].Name .. " sizes")
	end
end

T.lift_kept_when_room = function()
	local L = layoutFor(SCREENS[5]) -- tablet
	check(L.Lift == 90 and not L.Compact, "tablet keeps the full lift")
end

T.fit_text_size = function()
	check(Layout.FitTextSize(14, 1, 10) == 14, "no bump on desktop")
	check(Layout.FitTextSize(13, 0.51, 10) == 20, "tower bar at 0.68 x 0.75")
	check(Layout.FitTextSize(14, 0.68, 10) == 15, "menu label at the floor")
	check(Layout.SubScale(0.68, 1, 0.6) == 0.68 and math.abs(Layout.SubScale(0.68, 0.75, 0.6) - 0.8) < 1e-9, "sub scale")
end

return T
