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

local Theme = require(script.Parent.Theme)
local Signal = require(game:GetService("ReplicatedStorage"):WaitForChild("GH").Signal)
local Icons = require(game:GetService("ReplicatedStorage"):WaitForChild("GH").Icons)

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
	return l
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
	local scale = Kit.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1.05 })
		play("Hover")
	end)
	b.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		Kit.Tween(scale, 0.06, { Scale = 0.93 })
	end)
	b.MouseButton1Up:Connect(function()
		Kit.Tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.Activated:Connect(function()
		play("Click")
		if p.OnClick then
			(p.OnClick :: () -> ())()
		end
	end)
	b:GetAttributeChangedSignal("Color"):Connect(function()
		local c = Theme.Buttons[b:GetAttribute("Color") :: string] or Theme.Buttons.Green
		grad.Color = ColorSequence.new(c[1], c[2])
	end)
	return b
end

function Kit.SetButtonText(b: TextButton, text: string)
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l then
		l.Text = text
	end
end

--------------------------------------------------------------------------------
-- Screen scaling
--------------------------------------------------------------------------------
local screen: ScreenGui? = nil
local overlay: ScreenGui? = nil
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

local function applyScale()
	currentScale = computeScale()
	for _, gui in { screen, overlay } do
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
	local scale = Kit.new("UIScale", { Parent = root })
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
			scale.Scale = 0.7
			Kit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
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
			Kit.Tween(scale, 0.12, { Scale = 0.75 })
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
	-- obvious X (44 logical px ≈ a comfortable finger target even on phones)
	panel.CloseButton = Kit.Button(root, {
		Text = "X",
		Color = "Red",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, 12, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 64,
		TextStyle = "Heading",
		OnClick = function()
			panel:Close()
		end,
	})
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
		BackgroundTransparency = 0.08,
		LayoutOrder = math.floor(os.clock() * 100),
		ZIndex = 90,
		Parent = holder,
	})
	Kit.Corner(f, UDim.new(0, 10))
	Kit.Stroke(f, 2, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local l = Kit.Label(f, text, { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 91, Style = "Body", Fit = true })
	local sc = Kit.new("UIScale", { Scale = 0.6, Parent = f })
	Kit.Tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
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
	task.delay(2.4, function()
		if f.Parent then
			Kit.Tween(f, 0.3, { BackgroundTransparency = 1 })
			Kit.Tween(l, 0.3, { TextTransparency = 1 })
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then
				Kit.Tween(st, 0.3, { Transparency = 1 })
			end
			task.wait(0.3)
			f:Destroy()
		end
	end)
end

return Kit
