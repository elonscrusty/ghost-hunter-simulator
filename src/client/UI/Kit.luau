--!strict
-- Tiny UI toolkit: creation helpers, chunky animated buttons, modal panels (one open at a
-- time, dimmed background, X button) and toasts.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)

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
	return Kit.new("UICorner", { CornerRadius = radius or UDim.new(0, 14), Parent = parent })
end

function Kit.Stroke(parent: Instance, thickness: number?, color: Color3?, mode: Enum.ApplyStrokeMode?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = thickness or 3,
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

export type LabelProps = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Font: Enum.Font?,
	Align: Enum.TextXAlignment?,
	Stroke: number?,
	TextSize: number?,
	ZIndex: number?,
	Wrap: boolean?,
}

function Kit.Label(parent: Instance?, text: string, p: LabelProps?): TextLabel
	local o: LabelProps = p or {}
	local l: TextLabel = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromScale(1, 1),
		Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.zero,
		Text = text,
		TextColor3 = o.Color or Theme.Text,
		Font = o.Font or Theme.Title,
		TextScaled = o.TextSize == nil,
		TextSize = o.TextSize or 14,
		TextWrapped = o.Wrap ~= false,
		TextXAlignment = o.Align or Enum.TextXAlignment.Center,
		ZIndex = o.ZIndex or 1,
		Parent = parent,
	})
	if o.TextSize == nil then
		Kit.new("UITextSizeConstraint", { MaxTextSize = 64, MinTextSize = 8, Parent = l })
	end
	if (o.Stroke or 2) > 0 then
		Kit.new("UIStroke", { Thickness = o.Stroke or 2, Color = Theme.Outline, Parent = l })
	end
	return l
end

export type ButtonProps = {
	Text: string?,
	Icon: string?,
	Color: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	OnClick: (() -> ())?,
	ZIndex: number?,
	TextScale: number?,
}

-- Chunky gradient button with press/hover animation and click sound.
function Kit.Button(parent: Instance?, p: ButtonProps): TextButton
	local colors = Theme.Buttons[p.Color or "Green"] or Theme.Buttons.Green
	local b: TextButton = Kit.new("TextButton", {
		Size = p.Size or UDim2.fromOffset(160, 56),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = p.ZIndex or 1,
		Parent = parent,
	})
	Kit.Corner(b, UDim.new(0, 14))
	Kit.Stroke(b, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local grad = Kit.Gradient(b, colors[1], colors[2], 90)
	b:SetAttribute("Color", p.Color or "Green")
	-- glossy top highlight
	local gloss = Kit.new("Frame", {
		Size = UDim2.new(1, -10, 0.38, 0),
		Position = UDim2.fromOffset(5, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		ZIndex = b.ZIndex,
		Parent = b,
	})
	Kit.Corner(gloss, UDim.new(0, 10))
	local text = (if p.Icon then p.Icon .. " " else "") .. (p.Text or "")
	local label = Kit.Label(b, text, {
		Size = UDim2.fromScale(0.9, p.TextScale or 0.62),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = b.ZIndex + 1,
	})
	label.Name = "Label"
	local scale = Kit.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1.06 })
		play("Hover")
	end)
	b.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		Kit.Tween(scale, 0.06, { Scale = 0.92 })
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
-- Screen + panels
--------------------------------------------------------------------------------
local screen: ScreenGui? = nil
local overlay: ScreenGui? = nil
local uiScale: UIScale? = nil

local function updateScale()
	local cam = workspace.CurrentCamera
	if not cam or not uiScale then
		return
	end
	local vp = cam.ViewportSize
	local s = math.clamp(math.min(vp.Y / Theme.ReferenceHeight, vp.X / 1000), 0.55, 1.35)
	for _, gui in { screen, overlay } do
		local sc = gui and gui:FindFirstChildOfClass("UIScale")
		if sc then
			sc.Scale = s
		end
	end
end

local function makeScreen(name: string, order: number): ScreenGui
	local g: ScreenGui = Kit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Kit.new("UIScale", { Parent = g })
	return g
end

-- Main HUD screen (UIScale'd). Children should use offsets designed for the reference size,
-- or scale anchored to edges.
function Kit.Screen(): ScreenGui
	if not screen then
		local s = makeScreen("GHHud", 10)
		screen = s
		overlay = makeScreen("GHOverlay", 20)
		uiScale = s:FindFirstChildOfClass("UIScale")
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end
	return screen :: ScreenGui
end

function Kit.Overlay(): ScreenGui
	Kit.Screen()
	return overlay :: ScreenGui
end

function Kit.UIScale(): number
	return if uiScale then uiScale.Scale else 1
end

-- Logical (pre-UIScale) screen size, for laying out UIScale'd content.
function Kit.LogicalSize(): Vector2
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return vp / Kit.UIScale()
end

export type Panel = {
	Name: string,
	Root: Frame,
	Body: Frame,
	Title: TextLabel,
	IsOpen: boolean,
	Open: (Panel) -> (),
	Close: (Panel) -> (),
	Toggle: (Panel) -> (),
	OnOpen: BindableEvent,
	OnClose: BindableEvent,
}

local current: Panel? = nil
local dim: Frame? = nil
local panelOpenedSignal = Instance.new("BindableEvent")
Kit.PanelOpened = panelOpenedSignal.Event -- (name or nil)

local function getDim(): Frame
	if not dim then
		local d: Frame = Kit.new("TextButton", {
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
		;(d :: any).Activated:Connect(function()
			if current then
				(current :: Panel):Close()
			end
		end)
		dim = d
	end
	return dim :: Frame
end

function Kit.CurrentPanel(): string?
	return if current then (current :: Panel).Name else nil
end

-- Modal panel centred on screen.
function Kit.Panel(name: string, title: string, size: Vector2, color: string?): Panel
	local root: Frame = Kit.new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 60,
		Parent = Kit.Screen(),
	})
	Kit.Corner(root, UDim.new(0, 24))
	Kit.Stroke(root, 5, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(root, Theme.Panel2, Theme.Panel, 90)
	local scale = Kit.new("UIScale", { Parent = root })
	-- title banner
	local banner: Frame = Kit.new("Frame", {
		Size = UDim2.new(0.5, 0, 0, 58),
		Position = UDim2.new(0.5, 0, 0, -24),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 62,
		Parent = root,
	})
	Kit.Corner(banner, UDim.new(0, 18))
	Kit.Stroke(banner, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local bc = Theme.Buttons[color or "Purple"] or Theme.Buttons.Purple
	Kit.Gradient(banner, bc[1], bc[2], 90)
	local titleLabel = Kit.Label(banner, title, { Size = UDim2.fromScale(0.9, 0.75), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 63, Stroke = 3 })
	local body: Frame = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -36, 1, -60),
		Position = UDim2.fromOffset(18, 44),
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
		IsOpen = false,
		OnOpen = Instance.new("BindableEvent"),
		OnClose = Instance.new("BindableEvent"),
		Open = function(self: Panel)
			if current and current ~= self then
				(current :: Panel):Close()
			end
			if self.IsOpen then
				return
			end
			current = self
			self.IsOpen = true
			local d = getDim()
			d.Visible = true
			Kit.Tween(d, 0.2, { BackgroundTransparency = 0.45 })
			root.Visible = true
			scale.Scale = 0.6
			Kit.Tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
			play("PanelOpen")
			self.OnOpen:Fire()
			panelOpenedSignal:Fire(self.Name)
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
			Kit.Tween(scale, 0.12, { Scale = 0.7 })
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
	-- big obvious X
	Kit.Button(root, {
		Text = "X",
		Color = "Red",
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.new(1, 14, 0, -18),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 64,
		OnClick = function()
			panel:Close()
		end,
	})
	return panel
end

-- Close any open panel (Escape / B button).
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
			Size = UDim2.fromOffset(520, 300),
			Position = UDim2.new(0.5, 0, 0, 120),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			ZIndex = 90,
			Parent = Kit.Overlay(),
		})
		Kit.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = h,
		})
		toastHolder = h
	end
	local holder = toastHolder :: Frame
	local col = if color == "Bad" then Theme.Bad elseif color == "Good" then Theme.Good elseif color == "Gold" then Theme.Gold else Theme.Panel3
	local f: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(480, 44),
		BackgroundColor3 = col,
		BackgroundTransparency = 0.05,
		LayoutOrder = math.floor(os.clock() * 100),
		ZIndex = 90,
		Parent = holder,
	})
	Kit.Corner(f, UDim.new(0, 14))
	Kit.Stroke(f, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	local l = Kit.Label(f, text, { Size = UDim2.new(1, -20, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 91 })
	local sc = Kit.new("UIScale", { Scale = 0.5, Parent = f })
	Kit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
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
	if #kids > 4 then
		table.sort(kids, function(a: any, b: any)
			return a.LayoutOrder < b.LayoutOrder
		end)
		kids[1]:Destroy()
	end
	task.delay(2.6, function()
		if f.Parent then
			Kit.Tween(f, 0.3, { BackgroundTransparency = 1 })
			Kit.Tween(l, 0.3, { TextTransparency = 1 })
			task.wait(0.3)
			f:Destroy()
		end
	end)
end

return Kit
