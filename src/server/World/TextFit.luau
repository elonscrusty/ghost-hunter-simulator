--!strict
-- MOBILE TEXT FIX (signs): every world sign used TextScaled, so each of the ~230 signs drew its
-- words at its own pixel size (often huge, with big emoji). Phones keep every letter shape they
-- draw in one shared glyph cache; with hundreds of different sizes in view it overflows and
-- letters (in signs AND menus) flicker or vanish depending on where the camera points.
-- This pass gives every TextScaled label in the world ONE size from a short fixed list that
-- still fits its box, so the whole map only uses a handful of text sizes.
local TextFit = {}

-- the only sizes world signs use (px on the SurfaceGui canvas)
TextFit.Sizes = { 14, 20, 28, 40, 56, 80 }

local FACE_AXES: { [string]: { string } } = {
	Front = { "X", "Y" },
	Back = { "X", "Y" },
	Top = { "X", "Z" },
	Bottom = { "X", "Z" },
	Left = { "Z", "Y" },
	Right = { "Z", "Y" },
}

-- Estimated width of a line in "em" (multiples of the text size), a little generous so text fits.
function TextFit.LineEm(line: string, wide: boolean): number
	local em = 0
	for _, cp in utf8.codes(line) do
		if cp == 32 then
			em += 0.32
		elseif cp > 0x2000 then
			em += 1.15 -- emoji and symbols
		elseif (cp >= 65 and cp <= 90) or (cp >= 48 and cp <= 57) then
			em += 0.66
		else
			em += 0.54
		end
	end
	return if wide then em * 1.1 else em
end

-- Largest size from Sizes whose text fits w x h px (smallest size if nothing fits).
function TextFit.Pick(text: string, w: number, h: number, wide: boolean): number
	local lines = string.split(text, "\n")
	local maxEm = 0.5
	for _, l in lines do
		maxEm = math.max(maxEm, TextFit.LineEm(l, wide))
	end
	local best = TextFit.Sizes[1]
	for _, s in TextFit.Sizes do
		if maxEm * s <= w * 0.94 and #lines * s * 1.18 <= h * 0.94 then
			best = s
		end
	end
	return best
end

-- Pixel size of a GuiObject inside a SurfaceGui (nil if it isn't in one / not placed yet).
local function pxSize(obj: Instance): Vector2?
	if obj:IsA("SurfaceGui") then
		local part = obj.Adornee or obj.Parent
		if not part or not part:IsA("BasePart") then
			return nil
		end
		if obj.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize then
			return obj.CanvasSize
		end
		local axes = FACE_AXES[obj.Face.Name]
		local size = (part :: BasePart).Size
		local pps = obj.PixelsPerStud
		return Vector2.new((size :: any)[axes[1]] * pps, (size :: any)[axes[2]] * pps)
	end
	if obj:IsA("GuiObject") then
		local parent = obj.Parent
		local p = if parent then pxSize(parent) else nil
		if not p then
			return nil
		end
		local s = obj.Size
		return Vector2.new(p.X * s.X.Scale + s.X.Offset, p.Y * s.Y.Scale + s.Y.Offset)
	end
	return nil
end

-- Picks the size for the label's current text (or its "FitText" attribute: the longest text
-- it is expected to show, for labels filled in later) and applies it.
local function size(l: TextLabel)
	local px = pxSize(l)
	if not px or px.X <= 0 or px.Y <= 0 then
		return
	end
	local wide = l.Font == Enum.Font.GothamBlack or l.Font == Enum.Font.GothamBold
	local sample = l:GetAttribute("FitText")
	local s = TextFit.Pick(if type(sample) == "string" then sample else l.Text, px.X, px.Y, wide)
	l.TextSize = s
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		st.Thickness = if s <= 20 then 1 elseif s <= 40 then 2 else 3
	end
end

local function fit(l: TextLabel)
	if not l.TextScaled or not l:FindFirstAncestorOfClass("SurfaceGui") then
		return
	end
	local px = pxSize(l)
	if not px or px.X <= 0 or px.Y <= 0 then
		return
	end
	l.TextScaled = false
	l.TextWrapped = false
	l.TextTruncate = Enum.TextTruncate.AtEnd -- text longer than expected never spills out of the box
	size(l)
	if l:GetAttribute("FitText") == nil then
		-- text set later by the server (placeholders like "..."): re-pick from the same short
		-- list so the label isn't stuck at the placeholder's size
		l:GetPropertyChangedSignal("Text"):Connect(function()
			size(l)
		end)
	end
end

-- Fixes every TextScaled label under `root` once, then any added later.
function TextFit.Apply(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") and d.TextScaled then
			fit(d)
			if not d.TextScaled then
				n += 1
			end
		end
	end
	pcall(function()
		root.DescendantAdded:Connect(function(d)
			if d:IsA("TextLabel") then
				task.defer(fit, d) -- after the builder has parented and filled it
			end
		end)
	end)
	return n
end

return TextFit
