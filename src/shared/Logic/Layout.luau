--!strict
-- HUD side-menu layout maths (pure; proved for phone/tablet/desktop sizes in tests/Layout.spec).
-- Hud.luau passes the logical screen size and the screen's UIScale and applies the result.
--
-- Why it exists: the side menus sit under two UIScales (the screen's device scale and the menu's
-- own fit scale), so on a landscape phone they used to end up at ~0.4x: ~6 px labels and ~19 px
-- corner buttons with ~4 px gaps. Rules, in real screen pixels (after every scale):
--   * a menu never shrinks below MenuFloor, so its labels reach MinTextPx with the text fit
--   * every tap target is at least MinTapPx and neighbours keep at least MinGapPx between them
--   * when that doesn't fit, space gives way first: shorter cells (smaller icon, same label),
--     the corner buttons move beside the touch jump button, and only then is the menu lift
--     (Hud's MENU_LIFT) reduced to what still fits
local Layout = {}

Layout.MinTextPx = 10
Layout.MinTapPx = 44
Layout.MinGapPx = 6
-- smallest combined scale of a menu cell: "UPGRADES" must still fit the 84-wide cell at 10 px
Layout.MenuFloor = 0.68
Layout.TinyFloor = 0.45 -- only when a screen is too short for MenuFloor (labels may drop under 10 px)
Layout.TinyTapPx = 34 -- ... and buttons may drop under MinTapPx there

-- logical px (before any UIScale)
Layout.Cell = 84 -- menu cell width, and its height on roomy screens
Layout.CellShort = 66 -- cell height in the compact layout (smaller icon, same label)
Layout.Gap = 6 -- between cells / corner buttons
Layout.RowGap = 12 -- between the right column, the AUTO toggle and the corner-button row
Layout.SmallButton = 44 -- DEV / TRADE / FEEDBACK / SETTINGS
Layout.AutoW = 132
Layout.AutoH = 40
Layout.Margin = 8 -- from the screen edges
Layout.LabelSize = 14 -- menu cell label TextSize
Layout.LabelPad = 2 -- label box = cell width - 2 * LabelPad

-- TextSize (logical) to use so `base` renders at least `minPx` real pixels under `combined`
-- (the product of every UIScale above the text). Never smaller than `base`.
function Layout.FitTextSize(base: number, combined: number, minPx: number): number
	local k = math.max(combined, 0.05)
	if base * k >= minPx then
		return base
	end
	return math.ceil(minPx / k - 1e-9)
end

-- A fixed sub-scale (e.g. the Boss Tower bar's 0.68) that still keeps `floor` combined with the
-- screen scale: phones get a little less shrinking, desktop keeps `base`. Never above 1.
function Layout.SubScale(base: number, screenScale: number, floor: number): number
	return math.min(1, math.max(base, floor / math.max(screenScale, 0.05)))
end

export type MenuInput = {
	Scale: number, -- the screen's UIScale (real px per logical px)
	Width: number, -- logical HUD screen size
	Height: number,
	Reserve: number, -- logical px kept free above the bottom edge on the right (jump button)
	Lift: number, -- extra lift for both columns (the owner wants them a bit higher)
	JumpLeft: number?, -- touch only: logical distance from the screen's right edge to the jump button's left edge
	TopMin: number, -- the left column never starts above this (desktop chat window)
	Left: number, -- button counts
	Right: number,
	Small: number,
}

export type Sizes = { CellH: number, Gap: number, RowGap: number, Small: number, AutoH: number }
export type Rect = { X: number, Y: number, W: number, H: number }

export type MenuLayout = {
	Compact: boolean, -- short cells (and, on touch screens, corner buttons beside the jump button)
	RowBeside: boolean, -- corner-button row sits left of the jump button instead of in the right stack
	Lift: number, -- lift actually used (<= input Lift)
	Fits: boolean, -- false only if even the floor layout overflows the screen
	RightScale: number,
	Right: Sizes,
	RightW: number, -- right stack frame size (local px, before RightScale)
	RightH: number,
	RightBottom: number, -- logical px from the screen bottom to the stack's bottom edge
	RowW: number, -- corner-button row frame size (local px; scaled by RightScale)
	RowRight: number, -- RowBeside: logical px from the screen's right / bottom edges
	RowBottom: number,
	LeftScale: number,
	Left: Sizes,
	LeftH: number,
	LeftTop: number,
	Rects: { Left: Rect, Right: Rect, Row: Rect? }, -- logical screen rectangles
}

function Layout.Sizes(combined: number, compact: boolean, tapPx: number?): Sizes
	local tap = (tapPx or Layout.MinTapPx) / combined
	local gap = Layout.MinGapPx / combined
	return {
		CellH = math.max(if compact then Layout.CellShort else Layout.Cell, tap),
		Gap = math.max(Layout.Gap, gap),
		RowGap = math.max(Layout.RowGap, gap),
		Small = math.max(Layout.SmallButton, tap),
		AutoH = math.max(Layout.AutoH, tap),
	}
end

function Layout.ColumnHeight(s: Sizes, n: number): number
	return s.CellH * n + s.Gap * math.max(0, n - 1)
end

local function stackHeight(s: Sizes, n: number, rowInStack: boolean): number
	return Layout.ColumnHeight(s, n) + s.RowGap + s.AutoH + (if rowInStack then s.RowGap + s.Small else 0)
end

-- largest scale in [floor, max(1, floor)] (0.01 steps) whose height fits `avail`
local function largest(floorR: number, fits: (number) -> boolean): number?
	local hi = math.max(1, floorR)
	for i = 0, 200 do
		local r = math.max(floorR, hi - i * 0.01)
		if fits(r) then
			return r
		end
		if r <= floorR then
			break
		end
	end
	return nil
end

function Layout.Menu(inp: MenuInput): MenuLayout
	local floorR = Layout.MenuFloor / inp.Scale
	-- last resort for tiny screens (e.g. 568x320): smaller text beats buttons cut off the screen
	local tinyR = math.min(floorR, Layout.TinyFloor / inp.Scale)
	local tapPx = Layout.MinTapPx
	local function solve(compact: boolean, lift: number, minR: number?): number?
		local rowIn = not (compact and inp.JumpLeft ~= nil)
		local avail = inp.Height - inp.Reserve - lift - Layout.Margin
		return largest(minR or floorR, function(r)
			return stackHeight(Layout.Sizes(inp.Scale * r, compact, tapPx), inp.Right, rowIn) * r <= avail + 1e-6
		end)
	end
	local compact, lift = false, inp.Lift
	local r = solve(false, lift)
	if not r then
		compact = true
		r = solve(true, lift)
		while not r and lift > 0 do
			lift = math.max(0, lift - 2)
			r = solve(true, lift)
		end
	end
	local fits = r ~= nil
	if not r then
		tapPx = Layout.TinyTapPx
		r = solve(true, 0, tinyR)
	end
	local rs = r or tinyR
	local rowBeside = compact and inp.JumpLeft ~= nil
	local s = Layout.Sizes(inp.Scale * rs, compact, tapPx)
	local rowW = s.Small * inp.Small + s.Gap * math.max(0, inp.Small - 1)
	local rightW = math.max(Layout.Cell, Layout.AutoW, if rowBeside then 0 else rowW)
	local rightH = stackHeight(s, inp.Right, not rowBeside)
	local rightBottom = inp.Reserve + lift
	local rightTop = inp.Height - rightBottom - rightH * rs
	local rects: { Left: Rect, Right: Rect, Row: Rect? } = {
		Right = { X = inp.Width - Layout.Margin - rightW * rs, Y = rightTop, W = rightW * rs, H = rightH * rs },
		Left = { X = 0, Y = 0, W = 0, H = 0 },
	}
	local rowRight, rowBottom = 0, 0
	if rowBeside then
		rowRight = (inp.JumpLeft :: number) + Layout.Margin
		rowBottom = Layout.Margin
		rects.Row = { X = inp.Width - rowRight - rowW * rs, Y = inp.Height - rowBottom - s.Small * rs, W = rowW * rs, H = s.Small * rs }
	end
	-- left column: top lined up with the right stack's top (never above TopMin), same scale
	-- unless it needs less to fit above the bottom edge (never under the floor)
	local top = math.max(4, rightTop, inp.TopMin)
	local room = inp.Height - top - 10
	local function leftFits(x: number): boolean
		return x <= rs + 1e-9 and Layout.ColumnHeight(Layout.Sizes(inp.Scale * x, compact, tapPx), inp.Left) * x <= room + 1e-6
	end
	local rl = largest(math.min(floorR, rs), leftFits)
	if not rl then
		fits = false
		rl = largest(math.min(tinyR, rs), leftFits)
	end
	local ls = rl or tinyR
	local sl = Layout.Sizes(inp.Scale * ls, compact, tapPx)
	local leftH = Layout.ColumnHeight(sl, inp.Left)
	rects.Left = { X = Layout.Margin, Y = top, W = Layout.Cell * ls, H = leftH * ls }
	if rightTop < 4 - 1e-6 then
		fits = false
	end
	return {
		Compact = compact,
		RowBeside = rowBeside,
		Lift = lift,
		Fits = fits,
		RightScale = rs,
		Right = s,
		RightW = rightW,
		RightH = rightH,
		RightBottom = rightBottom,
		RowW = rowW,
		RowRight = rowRight,
		RowBottom = rowBottom,
		LeftScale = ls,
		Left = sl,
		LeftH = leftH,
		LeftTop = top,
		Rects = rects,
	}
end

function Layout.Overlaps(a: Rect, b: Rect): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

return Layout
