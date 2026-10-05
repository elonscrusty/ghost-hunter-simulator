--!strict
-- Tiny UI toolkit: creation helpers, typography styles, chunky animated buttons, responsive
-- modal panels (one open at a time, dimmed background, X button) and toasts.
--
-- Responsive rules (see Theme.Scale): every ScreenGui has one UIScale; layouts are written in
-- logical pixels; panels shrink to fit the logical screen and their content scrolls/wraps.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local TextService = game:GetService("TextService")
local Theme = require(script.Parent.Theme)
local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("GH").Signal)
local Icons = require(game:GetService("ReplicatedStorage"):WaitForChild("GH").Icons)
local Layout = require(game:GetService("ReplicatedStorage"):WaitForChild("GH").Logic.Layout)

local Kit = {}

local player = Players.LocalPlayer
local sound: ((string) -> ())? = nil

function Kit.SetSound(fn: (string) -> ())
	sound = fn
end

local function play(name: string)
	if sound then
		(sound :: (string) -> ())(name)
	end
end
Kit.Play = play

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.Tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function Kit.Corner(parent: Instance, radius: UDim?): UICorner
	return Kit.new("UICorner", { CornerRadius = radius or UDim.new(0, 12), Parent = parent })
end

function Kit.Stroke(parent: Instance, thickness: number?, color: Color3?, mode: Enum.ApplyStrokeMode?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness or 2,
		Color = color or Theme.Outline,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Kit.Gradient(parent: Instance, c1: Color3, c2: Color3, rotation: number?): UIGradient
	return Kit.new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90, Parent = parent })
end

function Kit.Padding(parent: Instance, px: number)
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------
export type LabelProps = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Font: Enum.Font?,
	Align: Enum.TextXAlignment?,
	AlignY: Enum.TextYAlignment?,
	Stroke: number?, -- outline thickness; 0 = none; default depends on Style
	Style: string?, -- key in Theme.Type (default "Body")
	TextSize: number?, -- explicit size (overrides Style)
	Fit: boolean?, -- single line; cut with "…" if the box is too narrow (never grows)
	ZIndex: number?,
	Wrap: boolean?,
}

local STROKE_BY_STYLE: { [string]: number } = {
	Banner = 3,
	Title = 2.5,
	Currency = 2.5,
	Heading = 2,
	Button = 2,
	Icon = 0,
	Body = 1.5,
	Small = 1,
	Tiny = 1,
}

-- Text with a fixed size from the typography scale. No TextScaled anywhere: the screen's
-- UIScale does the device scaling, so the hierarchy is identical on desktop, tablet and phone.
function Kit.Label(parent: Instance?, text: string, p: LabelProps?): TextLabel
	local o: LabelProps = p or {}
	local style = o.Style or "Body"
	local size = o.TextSize or Theme.Type[style] or Theme.Type.Body
	local singleLine = o.Fit == true or o.Wrap == false
	local l: TextLabel = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero,
		Text = text,
		TextColor3 = o.Color or Theme.Text,
		Font = o.Font or Theme.Title,
		TextSize = size,
		TextScaled = false,
		TextWrapped = not singleLine,
		TextTruncate = if singleLine then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
		TextXAlignment = o.Align or Enum.TextXAlignment.Center,
		TextYAlignment = o.AlignY or Enum.TextYAlignment.Center,
		ZIndex = o.ZIndex or 1,
		Parent = parent,
	})
	local stroke = if o.Stroke ~= nil then o.Stroke else (STROKE_BY_STYLE[style] or 1.5)
	if stroke > 0 then
		Kit.new("UIStroke", { Thickness = stroke, Color = Theme.Outline, Parent = l })
	end
	Kit.FitText(l, size, stroke, style ~= "Icon")
	return l
end

-- The game's one close button: red square with a plain "X" (the font has no "✕" glyph, which
-- is why a popup once showed an empty red square). 44 logical px: a comfortable finger target.
function Kit.CloseButton(parent: Instance, onClick: () -> (), zIndex: number?): TextButton
	return Kit.Button(parent, {
		Text = "X",
		Color = "Red",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, 12, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = zIndex or 64,
		TextStyle = "Heading",
		OnClick = onClick,
	})
end

-- An icon: the uploaded image for `key` (shared Icons.luau) when it has an id, otherwise the
-- emoji as text. Same props as Kit.Label (the image fits inside the label's box).
function Kit.Icon(parent: Instance?, key: string?, emoji: string, p: LabelProps?): GuiObject
	local image = Icons.Get(key)
	if not image then
		return Kit.Label(parent, emoji, p)
	end
	local o: LabelProps = p or {}
	local img: ImageLabel = Kit.new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero,
		ZIndex = o.ZIndex or 1,
		Parent = parent,
	})
	return img
end

--------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------
export type ButtonProps = {
	Text: string?,
	Icon: string?,
	Color: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	OnClick: (() -> ())?,
	ZIndex: number?,
	TextStyle: string?, -- typography key, default "Button"
}

local MIN_TAP_PT = 44 -- smallest physical tap target (points), Apple / Google guideline

-- Chunky gradient button with press/hover animation and click sound.
function Kit.Button(parent: Instance?, p: ButtonProps): TextButton
	local colors = Theme.Buttons[p.Color or "Green"] or Theme.Buttons.Green
	local b: TextButton = Kit.new("TextButton", {
		Size = p.Size or UDim2.fromOffset(140, 44),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = p.ZIndex or 1,
		Parent = parent,
	})
	Kit.Corner(b, UDim.new(0, 10))
	Kit.Stroke(b, 2.5, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local grad = Kit.Gradient(b, colors[1], colors[2], 90)
	b:SetAttribute("Color", p.Color or "Green")
	-- glossy top highlight
	local gloss = Kit.new("Frame", {
		Size = UDim2.new(1, -8, 0.36, 0),
		Position = UDim2.fromOffset(4, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		ZIndex = b.ZIndex,
		Parent = b,
	})
	Kit.Corner(gloss, UDim.new(0, 8))
	local text = (if p.Icon then p.Icon .. " " else "") .. (p.Text or "")
	local label = Kit.Label(b, text, {
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Style = p.TextStyle or "Button",
		Fit = true,
		ZIndex = b.ZIndex + 1,
	})
	label.Name = "Label"
	Kit.EctoText(label, text)
	local scale = Kit.new("UIScale", { Parent = b })
	-- Minimum finger target: an invisible hit area, centred on the button, that grows so the
	-- tappable size is never under MIN_TAP_PT real points even when the screen / menu scaling
	-- draws the button smaller. The visible button is unchanged.
	local hit: TextButton = Kit.new("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Selectable = false,
		ZIndex = b.ZIndex + 2,
		Parent = b,
	})
	local function fitHit()
		-- local px -> screen points: product of every UIScale from here up to the ScreenGui
		local k = 1
		local node: Instance? = b
		while node and not node:IsA("LayerCollector") do
			local sc = node:FindFirstChildOfClass("UIScale")
			if sc then
				k *= sc.Scale
			end
			node = node.Parent
		end
		local g = node and node:FindFirstChildOfClass("UIScale")
		if g then
			k *= g.Scale
		end
		k = math.max(k, 0.05)
		local abs = b.AbsoluteSize
		hit.Size = UDim2.new(1, math.max(0, MIN_TAP_PT - abs.X) / k, 1, math.max(0, MIN_TAP_PT - abs.Y) / k)
	end
	b:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHit)
	b.AncestryChanged:Connect(fitHit)
	b:GetPropertyChangedSignal("ZIndex"):Connect(function()
		hit.ZIndex = b.ZIndex + 2
	end)
	fitHit()
	b.MouseEnter:Connect(function()
		-- touch screens fire MouseEnter with no MouseLeave: a hover grow would stay stuck and make
		-- buttons overlap their neighbours, so hover only reacts to a real mouse
		if UserInputService:GetLastInputType() ~= Enum.UserInputType.MouseMovement then
			return
		end
		Kit.Tween(scale, 0.12, { Scale = 1.05 })
		play("Hover")
	end)
	b.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1 })
	end)
	-- release is watched globally: a finger that drags off the button (e.g. to scroll a list)
	-- never fires MouseButton1Up on it, which used to leave the button stuck shrunk
	local pressConn: RBXScriptConnection? = nil
	local function pressed()
		Kit.Tween(scale, 0.06, { Scale = 0.93 })
		if pressConn then
			pressConn:Disconnect()
		end
		pressConn = UserInputService.InputEnded:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
				if pressConn then
					pressConn:Disconnect()
					pressConn = nil
				end
				Kit.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
	end
	local function activated()
		play("Click")
		if p.OnClick then
			(p.OnClick :: () -> ())()
		end
	end
	-- touches / clicks land on the hit area; gamepad ButtonA activates the selected button itself
	b.MouseButton1Down:Connect(pressed)
	hit.MouseButton1Down:Connect(pressed)
	b.Activated:Connect(activated)
	hit.Activated:Connect(activated)
	b:GetAttributeChangedSignal("Color"):Connect(function()
		local c = Theme.Buttons[b:GetAttribute("Color") :: string] or Theme.Buttons.Green
		grad.Color = ColorSequence.new(c[1], c[2])
	end)
	return b
end

-- Emoji that have an uploaded image (Icons.luau). Kit.IconText draws each one as a small image
-- in the text, in the emoji's place, instead of the emoji glyph.
local INLINE_ICONS: { { Emoji: string, Key: string } } = {
	{ Emoji = "💚", Key = "ecto" },
	{ Emoji = "⚡", Key = "power" },
	{ Emoji = "🔮", Key = "shards" },
	{ Emoji = "🔒", Key = "lock" },
	{ Emoji = "🍀", Key = "boost_luck" },
	{ Emoji = "🤖", Key = "pass_autoattack" },
}
Kit.InlineIcons = INLINE_ICONS

type Piece = { Text: string?, Image: string? }

-- splits text into plain text and inline icons (an emoji without an uploaded image stays text)
local function splitIcons(text: string): { Piece }
	local out: { Piece } = {}
	local i = 1
	while i <= #text do
		local bestAt, bestEnd, bestImage = nil :: number?, 0, nil :: string?
		for _, e in INLINE_ICONS do
			local image = Icons.Get(e.Key)
			if image then
				local a, b = string.find(text, e.Emoji, i, true)
				if a and (bestAt == nil or a < (bestAt :: number)) then
					bestAt, bestEnd, bestImage = a, b :: number, image
				end
			end
		end
		if not bestAt then
			table.insert(out, { Text = string.sub(text, i) })
			break
		end
		local at = bestAt :: number
		if at > i then
			table.insert(out, { Text = string.sub(text, i, at - 1) })
		end
		table.insert(out, { Image = bestImage })
		i = bestEnd + 1
		if string.sub(text, i, i + 2) == "\u{FE0F}" then -- emoji variation selector
			i += 3
		end
		if string.sub(text, i, i) == " " then -- the spacer already leaves a gap
			i += 1
		end
	end
	return out
end

local function textWidth(text: string, size: number, font: Enum.Font): number
	return TextService:GetTextSize(text, size, font, Vector2.new(4000, 4000)).X
end

-- Sets a label's text. Each emoji listed in INLINE_ICONS ("💚" Ectoplasm, "⚡" power, "🔮"
-- Spirit Shards, "🔒" lock, "🍀" luck, "🤖" auto attack) is drawn as its uploaded image where the emoji was; the
-- text gets blank space there, so the image never overlaps a glyph. Lines may be split with
-- "\n" but must not wrap on their own. Re-laid out when the screen scale changes the text size.
function Kit.IconText(l: TextLabel, text: string)
	l:SetAttribute("IconText", text)
	local pieces = splitIcons(text)
	local size = l.TextSize
	local font = l.Font
	local w = size + 4
	local function width(t: string): number
		return textWidth("a" .. t .. "a", size, font) - textWidth("aa", size, font)
	end
	local spaceW = math.max(1, width(" "))
	local spacer = string.rep(" ", math.ceil((w + 4) / spaceW))
	local spacerW = width(spacer)
	local clean = ""
	local line = "" -- text of the current line so far
	local lineNo = 1
	local centres: { { X: number, Line: number, Image: string } } = {}
	for _, p in pieces do
		if p.Image then
			table.insert(centres, { X = width(line) + spacerW / 2, Line = lineNo, Image = p.Image })
			clean ..= spacer
			line ..= spacer
		else
			local t = p.Text :: string
			clean ..= t
			for ch in string.gmatch(t, "[^\n]*\n?") do
				if string.sub(ch, -1) == "\n" then
					lineNo += 1
					line = ""
				else
					line ..= ch
				end
			end
		end
	end
	l.Text = clean
	l:SetAttribute("IconClean", clean)
	local lineWidths: { number } = {}
	for ln in string.gmatch(clean .. "\n", "([^\n]*)\n") do
		table.insert(lineWidths, width(ln))
	end
	local lines = #lineWidths
	local lineH = TextService:GetTextSize("a\na", size, font, Vector2.new(4000, 4000)).Y - TextService:GetTextSize("a", size, font, Vector2.new(4000, 4000)).Y
	local pad = l:FindFirstChildOfClass("UIPadding")
	local padL = if pad then pad.PaddingLeft.Offset else 0
	local padR = if pad then pad.PaddingRight.Offset else 0
	local n = 0
	for _, c in centres do
		n += 1
		local name = "InlineIcon" .. n
		local ic = l:FindFirstChild(name) :: ImageLabel?
		if not ic then
			ic = Kit.new("ImageLabel", {
				Name = name,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = l.ZIndex + 1,
				Parent = l,
			})
		end
		local img = ic :: ImageLabel
		img.Image = c.Image
		img.Visible = true
		img.Size = UDim2.fromOffset(w, w)
		local total = lineWidths[c.Line] or 0
		local yScale, yOff = 0.5, (c.Line - (lines + 1) / 2) * lineH
		if l.TextYAlignment == Enum.TextYAlignment.Top then
			yScale, yOff = 0, (c.Line - 0.5) * lineH
		elseif l.TextYAlignment == Enum.TextYAlignment.Bottom then
			yScale, yOff = 1, -(lines - c.Line + 0.5) * lineH
		end
		if l.TextXAlignment == Enum.TextXAlignment.Left then
			img.Position = UDim2.new(0, padL + c.X, yScale, yOff)
		elseif l.TextXAlignment == Enum.TextXAlignment.Right then
			img.Position = UDim2.new(1, -padR - total + c.X, yScale, yOff)
		else
			img.Position = UDim2.new(0.5, (padL - padR) / 2 - total / 2 + c.X, yScale, yOff)
		end
	end
	-- hide icons left over from a longer earlier text
	while true do
		n += 1
		local extra = l:FindFirstChild("InlineIcon" .. n) :: ImageLabel?
		if not extra then
			break
		end
		extra.Visible = false
	end
	if l:GetAttribute("IconTextHooked") == nil then
		l:SetAttribute("IconTextHooked", true)
		l:GetPropertyChangedSignal("TextSize"):Connect(function()
			local raw = l:GetAttribute("IconText")
			-- only when nobody replaced the text directly since
			if type(raw) == "string" and l.Text == l:GetAttribute("IconClean") then
				Kit.IconText(l, raw)
			end
		end)
	end
end

-- Older name (kept for callers): same as Kit.IconText.
Kit.EctoText = Kit.IconText

function Kit.SetButtonText(b: TextButton, text: string)
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l then
		Kit.EctoText(l, text)
	end
end

--------------------------------------------------------------------------------
-- Screen scaling
--------------------------------------------------------------------------------
local screen: ScreenGui? = nil
local overlay: ScreenGui? = nil
local topBar: ScreenGui? = nil
local currentScale = 1
local scaleChanged = Signal.new()
Kit.ScaleChanged = scaleChanged -- (scale)

local function computeScale(): number
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local s
	if vp.X >= vp.Y then
		s = vp.Y / Theme.Scale.LandscapeRef
	else
		s = vp.X / Theme.Scale.PortraitRef
	end
	return math.clamp(s, Theme.Scale.Min, Theme.Scale.Max)
end

-- MOBILE TEXT FIX (root cause): one UIScale shrinks each ScreenGui on phones (~0.72), but
-- UIStroke thickness is NOT scaled by UIScale, so a 2-3 px outline stayed full size around
-- ~8 px letters and smeared them; the smallest styles also fell below what a phone renders
-- cleanly. Every Kit label is registered here and, whenever the scale changes:
--   * its outline is scaled with the screen (and kept thin relative to the letters)
--   * its text never renders smaller than Layout.MinTextPx real pixels
-- "Real pixels" counts every layout UIScale above the label (the side menus' fit scale, the Boss
-- Tower bar's 0.68, see Kit.LayoutScale), not just the screen's: nested scales used to take menu
-- labels down to ~6 px on phones while the screen-only check said they were fine.
type TextInfo = { Base: number, Stroke: number, Min: boolean }
-- strong keys (a weak-keyed Instance table can lose labels that still exist); entries are
-- removed when the label is destroyed
local fitted: { [TextLabel]: TextInfo } = {}
local LAYOUT_ATTR = "LayoutScale" -- set on UIScales registered with Kit.LayoutScale

-- product of the screen scale and every registered layout UIScale above `l` (press / pop
-- animation scales are not registered, so they never resize text)
local function combinedScale(l: Instance): number
	local k = currentScale
	local node = l.Parent
	while node and not node:IsA("LayerCollector") do
		local sc = node:FindFirstChildOfClass("UIScale") -- Roblox applies one UIScale per object
		if sc and sc:GetAttribute(LAYOUT_ATTR) == true then
			k *= sc.Scale
		end
		node = node.Parent
	end
	return k
end

local function applyFit(l: TextLabel, info: TextInfo)
	local k = combinedScale(l)
	local size = if info.Min then Layout.FitTextSize(info.Base, k, Layout.MinTextPx) else info.Base
	l.TextSize = size
	local st = l:FindFirstChildOfClass("UIStroke")
	if st and info.Stroke > 0 then
		-- whole pixels only: a fractional outline (e.g. 0.75 px) is drawn unevenly on phones and
		-- makes the letters look broken / flickery
		st.Thickness = math.max(1, math.floor(math.min(info.Stroke * k, size * k * 0.12) + 0.5))
	end
end

function Kit.FitText(l: TextLabel, base: number, stroke: number, minSize: boolean)
	local info: TextInfo = { Base = base, Stroke = stroke, Min = minSize }
	if fitted[l] == nil then
		l.Destroying:Connect(function()
			fitted[l] = nil
		end)
	end
	fitted[l] = info
	applyFit(l, info)
end

-- Re-fits the labels under `root` (e.g. after moving it under a different layout scale).
function Kit.Refit(root: Instance)
	for l, info in fitted do
		if l:IsDescendantOf(root) then
			applyFit(l, info)
		end
	end
end

-- Registers a fixed layout UIScale (never animated): labels under its parent are re-fitted with
-- it whenever its Scale changes, so their text keeps Layout.MinTextPx real pixels.
function Kit.LayoutScale(sc: UIScale)
	sc:SetAttribute(LAYOUT_ATTR, true)
	sc:GetPropertyChangedSignal("Scale"):Connect(function()
		local root = sc.Parent
		if root then
			Kit.Refit(root)
		end
	end)
end

local function applyScale()
	currentScale = computeScale()
	for l, info in fitted do
		applyFit(l, info)
	end
	for _, gui in { screen, overlay, topBar } do
		local sc = gui and gui:FindFirstChildOfClass("UIScale")
		if sc then
			sc.Scale = currentScale
		end
	end
	scaleChanged:Fire(currentScale)
end

local function makeScreen(name: string, order: number): ScreenGui
	local g: ScreenGui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
	})
	-- keep clear of the Roblox top bar and device notches (set after creation: the older
	-- IgnoreGuiInset property would otherwise overwrite it depending on assignment order)
	g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	g.Parent = player:WaitForChild("PlayerGui")
	Kit.new("UIScale", { Scale = currentScale, Parent = g })
	return g
end

-- Main HUD screen (UIScale'd).
function Kit.Screen(): ScreenGui
	if not screen then
		currentScale = computeScale()
		local s = makeScreen("GHHud", 10)
		screen = s
		overlay = makeScreen("GHOverlay", 20)
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
		end
		applyScale()
	end
	return screen :: ScreenGui
end

-- Top-bar screen: same scale as the HUD but laid out from the very top of the device (the
-- free middle of the Roblox top bar), for the Ectoplasm + power counters.
function Kit.TopBar(): ScreenGui
	Kit.Screen()
	if not topBar then
		local g = makeScreen("GHTop", 11)
		g.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		topBar = g
	end
	return topBar :: ScreenGui
end

function Kit.Overlay(): ScreenGui
	Kit.Screen()
	return overlay :: ScreenGui
end

-- Device scale shared by ScreenGuis and world labels.
function Kit.UIScale(): number
	return currentScale
end

-- Logical (pre-UIScale) screen size: what layouts are written against.
function Kit.LogicalSize(): Vector2
	local g = Kit.Screen()
	local abs = g.AbsoluteSize
	if abs.X <= 0 then
		local cam = workspace.CurrentCamera
		abs = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	end
	return abs / currentScale
end

-- Short screens (landscape phones) use the compact HUD layout.
function Kit.IsCompact(): boolean
	return Kit.LogicalSize().Y < Theme.Scale.CompactHeight
end

--------------------------------------------------------------------------------
-- Panels
--------------------------------------------------------------------------------
export type Panel = {
	Name: string,
	Root: Frame,
	Body: Frame,
	Title: TextLabel,
	Design: Vector2,
	IsOpen: boolean,
	Open: (Panel) -> (),
	Close: (Panel) -> (),
	Toggle: (Panel) -> (),
	Fit: (Panel) -> (),
	OnOpen: Signal.Signal,
	OnClose: Signal.Signal,
	Primary: GuiObject?, -- gamepad: selected when the panel opens (else the X button)
	CloseButton: GuiObject?,
}

local function usingGamepad(): boolean
	return UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:match("^Gamepad") ~= nil
end

local current: Panel? = nil
local dim: TextButton? = nil
local panels: { Panel } = {}
local panelOpenedSignal = Signal.new()
Kit.PanelOpened = panelOpenedSignal -- (name or nil)

local function getDim(): TextButton
	if not dim then
		local d: TextButton = Kit.new("TextButton", {
			Name = "Dim",
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 50,
			Parent = Kit.Screen(),
		})
		d.Activated:Connect(function()
			if current then
				(current :: Panel):Close()
			end
		end)
		dim = d
	end
	return dim :: TextButton
end

function Kit.CurrentPanel(): string?
	return if current then (current :: Panel).Name else nil
end

-- Modal panel centred on screen. `size` is the design size; on small screens the panel
-- shrinks to fit (keep content in scrolling/wrapping containers).
function Kit.Panel(name: string, title: string, size: Vector2, color: string?): Panel
	local root: Frame = Kit.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.new(0.5, 0, 0.5, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 60,
		Parent = Kit.Screen(),
	})
	Kit.Corner(root, UDim.new(0, 18))
	Kit.Stroke(root, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(root, Theme.Panel2, Theme.Panel, 90)
	-- open/close slide the panel instead of scaling it: a scale tween re-rendered every label
	-- through many pixel sizes, which is what broke text on phones (glyph cache)
	local REST = UDim2.new(0.5, 0, 0.5, 12)
	local OFF = UDim2.new(0.5, 0, 0.5, 52)
	-- title banner
	local banner: Frame = Kit.new("Frame", {
		Size = UDim2.new(0, math.clamp(#title * 15 + 60, 200, 420), 0, 44),
		Position = UDim2.new(0.5, 0, 0, -20),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 62,
		Parent = root,
	})
	Kit.Corner(banner, UDim.new(0, 14))
	Kit.Stroke(banner, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local bc = Theme.Buttons[color or "Purple"] or Theme.Buttons.Purple
	Kit.Gradient(banner, bc[1], bc[2], 90)
	local titleLabel = Kit.Label(banner, title, { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 63, Style = "Title", Fit = true })
	-- panels that retitle themselves (crate / egg names, "UNLOCK CEMETERY?") get a banner that
	-- fits the new title instead of cutting it off with "…"
	titleLabel:GetPropertyChangedSignal("Text"):Connect(function()
		banner.Size = UDim2.new(0, math.clamp(#titleLabel.Text * 15 + 60, 200, 420), 0, 44)
	end)
	local body: Frame = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -28, 1, -50),
		Position = UDim2.fromOffset(14, 36),
		BackgroundTransparency = 1,
		ZIndex = 61,
		Parent = root,
	})
	local panel: Panel
	panel = {
		Name = name,
		Root = root,
		Body = body,
		Title = titleLabel,
		Design = size,
		IsOpen = false,
		OnOpen = Signal.new(),
		OnClose = Signal.new(),
		Fit = function(self: Panel)
			local logical = Kit.LogicalSize()
			local w = math.min(self.Design.X, logical.X - 32)
			local h = math.min(self.Design.Y, logical.Y - 64)
			root.Size = UDim2.fromOffset(math.max(w, 240), math.max(h, 200))
		end,
		Open = function(self: Panel)
			if current and current ~= self then
				(current :: Panel):Close()
			end
			if self.IsOpen then
				return
			end
			self:Fit()
			current = self
			self.IsOpen = true
			local d = getDim()
			d.Visible = true
			Kit.Tween(d, 0.2, { BackgroundTransparency = 0.5 })
			root.Visible = true
			root.Position = OFF
			Kit.Tween(root, 0.25, { Position = REST }, Enum.EasingStyle.Back)
			play("PanelOpen")
			self.OnOpen:Fire()
			panelOpenedSignal:Fire(self.Name)
			if usingGamepad() then
				GuiService.SelectedObject = self.Primary or self.CloseButton
			end
		end,
		Close = function(self: Panel)
			if not self.IsOpen then
				return
			end
			self.IsOpen = false
			if current == self then
				current = nil
				local d = getDim()
				Kit.Tween(d, 0.15, { BackgroundTransparency = 1 })
				task.delay(0.15, function()
					if not current then
						d.Visible = false
					end
				end)
			end
			local sel = GuiService.SelectedObject
			if sel and sel:IsDescendantOf(root) then
				GuiService.SelectedObject = nil
			end
			Kit.Tween(root, 0.12, { Position = OFF })
			task.delay(0.12, function()
				if not self.IsOpen then
					root.Visible = false
				end
			end)
			self.OnClose:Fire()
			panelOpenedSignal:Fire(nil)
		end,
		Toggle = function(self: Panel)
			if self.IsOpen then
				self:Close()
			else
				self:Open()
			end
		end,
	}
	panel.CloseButton = Kit.CloseButton(root, function()
		panel:Close()
	end, 64)
	table.insert(panels, panel)
	return panel
end

scaleChanged:Connect(function()
	for _, p in panels do
		if p.IsOpen then
			p:Fit()
		end
	end
end)

-- Close any open panel (gamepad B / Backspace / Roblox menu).
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.ButtonB or (input.KeyCode == Enum.KeyCode.Backspace and not processed) then
		if current then
			(current :: Panel):Close()
		end
	end
end)
GuiService.MenuOpened:Connect(function()
	if current then
		(current :: Panel):Close()
	end
end)

--------------------------------------------------------------------------------
-- Popups that wait their turn
--------------------------------------------------------------------------------
-- Unprompted popups (event announcements, the daily reward, trade requests) must never close
-- a menu the player is using or cover a crate reveal: they wait here until no panel is open
-- and nothing has marked the screen busy (Kit.SetBusy), then show one at a time.
local busyReasons: { [string]: boolean? } = {}
local waiting: { () -> () } = {}
local flushing = false

function Kit.IsFree(): boolean
	return current == nil and next(busyReasons) == nil
end

local function flushWaiting()
	if flushing or #waiting == 0 or not Kit.IsFree() then
		return
	end
	flushing = true
	-- a short beat so a closing panel / finished reveal is out of the way first
	task.delay(0.5, function()
		flushing = false
		if not Kit.IsFree() or #waiting == 0 then
			return
		end
		local fn = table.remove(waiting, 1) :: () -> ()
		local ok, err = pcall(fn :: any)
		if not ok then
			warn("[Kit] popup failed: " .. tostring(err))
		end
		-- the popup may not have opened anything (stale): try the next one
		flushWaiting()
	end)
end

-- Runs `fn` as soon as the screen is free (right away if it already is). `fn` should re-check that its
-- popup still makes sense (it may run much later).
function Kit.WhenFree(fn: () -> ())
	table.insert(waiting, fn)
	flushWaiting()
end

-- Marks the screen busy for a reason (e.g. "Reveal") so waiting popups hold off.
function Kit.SetBusy(reason: string, on: boolean)
	busyReasons[reason] = if on then true else nil
	flushWaiting()
end

panelOpenedSignal:Connect(function(name: any)
	if name == nil then
		flushWaiting()
	end
end)

--------------------------------------------------------------------------------
-- Toasts
--------------------------------------------------------------------------------
local toastHolder: Frame? = nil

function Kit.Toast(text: string, color: string?)
	if not toastHolder then
		local h: Frame = Kit.new("Frame", {
			Name = "Toasts",
			Size = UDim2.fromOffset(420, 200),
			Position = UDim2.new(0.5, 0, 0, 96),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ZIndex = 90,
			Parent = Kit.Overlay(),
		})
		Kit.new("UIListLayout", {
			Padding = UDim.new(0, 4),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = h,
		})
		toastHolder = h
	end
	local holder = toastHolder :: Frame
	local col = if color == "Bad" then Theme.Bad elseif color == "Good" then Theme.Good elseif color == "Gold" then Theme.Gold else Theme.Panel3
	local f: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(400, 32),
		BackgroundColor3 = col,
		BackgroundTransparency = 1,
		LayoutOrder = math.floor(os.clock() * 100),
		ZIndex = 90,
		Parent = holder,
	})
	Kit.Corner(f, UDim.new(0, 10))
	local fStroke = Kit.Stroke(f, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	-- long messages wrap onto up to TOAST_LINES lines (then "…") instead of being cut to one
	local l = Kit.Label(f, text, { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 91, Style = "Body", Wrap = true })
	l.TextTruncate = Enum.TextTruncate.AtEnd
	local TOAST_LINES = 3
	local lineH = l.TextSize + 2
	local textH = TextService:GetTextSize(text, l.TextSize, l.Font, Vector2.new(384, 1000)).Y
	f.Size = UDim2.fromOffset(400, math.max(32, math.min(textH, lineH * TOAST_LINES) + 12))
	-- one-line toasts draw 💚 / ⚡ / 🔮 ... as their uploaded images (wrapped text keeps the emoji)
	local icons: { ImageLabel } = {}
	if textH <= lineH then
		Kit.IconText(l, text)
		-- the icon gaps are wider than the emoji: if that pushes it onto 2 lines, keep the emoji
		if TextService:GetTextSize(l.Text, l.TextSize, l.Font, Vector2.new(384, 1000)).Y > lineH then
			for _, c in l:GetChildren() do
				if c:IsA("ImageLabel") then
					c:Destroy()
				end
			end
			l.Text = text
		end
		for _, c in l:GetChildren() do
			if c:IsA("ImageLabel") and c.Visible then
				c.ImageTransparency = 1
				Kit.Tween(c, 0.18, { ImageTransparency = 0 })
				table.insert(icons, c)
			end
		end
	end
	-- fade in (no scale pop: scaling text re-renders it through many sizes, see Kit.Panel)
	local lStroke = l:FindFirstChildOfClass("UIStroke")
	l.TextTransparency = 1
	fStroke.Transparency = 1
	Kit.Tween(f, 0.18, { BackgroundTransparency = 0.08 })
	Kit.Tween(fStroke, 0.18, { Transparency = 0 })
	Kit.Tween(l, 0.18, { TextTransparency = 0 })
	if lStroke then
		lStroke.Transparency = 1
		Kit.Tween(lStroke, 0.18, { Transparency = 0 })
	end
	if color == "Bad" then
		play("Error")
	end
	-- cap visible toasts
	local kids = {}
	for _, c in holder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids > 3 then
		table.sort(kids, function(a: any, b: any)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	-- longer (wrapped) messages stay up a little longer so they can be read
	local lines = math.clamp(math.ceil(textH / lineH), 1, TOAST_LINES)
	task.delay(2.4 + (lines - 1) * 0.8, function()
		if f.Parent then
			Kit.Tween(f, 0.3, { BackgroundTransparency = 1 })
			Kit.Tween(fStroke, 0.3, { Transparency = 1 })
			for _, c in icons do
				Kit.Tween(c, 0.3, { ImageTransparency = 1 })
			end
			Kit.Tween(l, 0.3, { TextTransparency = 1 })
			if lStroke then
				Kit.Tween(lStroke, 0.3, { Transparency = 1 })
			end
			task.wait(0.3)
			f:Destroy()
		end
	end)
end

return Kit
