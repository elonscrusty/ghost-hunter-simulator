--!strict
-- Crate opening cinematic. Plays on a private stage far from the map with a scripted camera:
--   crate drops in → bounces → shakes (rare+: levitates while rarity energy converges) →
--   locks pop → lid flies open → light burst → the hunter leaps out and poses → result card.
-- Intensity comes from Config.Rarities (RevealPause, ShakeIntensity, Particles, Darken,
-- CameraPunch). Commons are quick; "Fast crate opening" in settings shortens everything; SKIP
-- jumps straight to the result. Every step is written as anim(duration, apply(alpha)) so a
-- skip simply applies each step's end state.
-- Reveal.PlayPet runs the same sequence for a PET EGG: the egg shakes and cracks, the shell
-- pops and the hatched pet (PetFollowers.BuildPet) pops out.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local Format = require(GH.Logic.Format)
local Rules = require(GH.Logic.Rules)
local Signal = require(GH.Signal)
local HunterRig = require(GH.Rigs.HunterRig)
local CrateRig = require(GH.Rigs.CrateRig)
local Client = script.Parent.Parent
local State = require(Client.State)

-- max HP of a hunter with this power (incl. the equipped pets' HP bonus), as the server counts it
local function hpFor(power: number): number
	local d = State.Data
	local bonus = if d and d.PetBonuses then tonumber(d.PetBonuses.HP) or 0 else 0
	return Rules.HunterMaxHP(power, Config.Retaliation.HPPerPower, bonus)
end

local Kit = require(Client.UI.Kit)
local Theme = require(Client.UI.Theme)
local Effects = require(script.Parent.Effects)
local Sound = require(script.Parent.Sound)
local Targeting = require(script.Parent.Targeting)
local PetFollowers = require(script.Parent.PetFollowers)
local PetsPanel = require(script.Parent.PetsPanel)
local PetPortrait = require(Client.UI.PetPortrait)

local Reveal = {}

export type Result = {
	Crate: string,
	Hunter: string,
	Uid: string,
	IsNew: boolean,
}

local player = Players.LocalPlayer
local STAGE = Vector3.new(0, 900, -2500)
local CAM_FOV = 50

local playing = false
local skipping = false
local stage: Folder? = nil
local gui: ScreenGui? = nil
local cc: ColorCorrectionEffect? = nil
local rays: Frame? = nil
local raySpeed = 20
local poseConn: RBXScriptConnection? = nil
local hunterRig: HunterRig.Rig? = nil
local hunterState = "Idle"
local hunterT0 = 0
local idleFn: ((number) -> ())? = nil -- per-frame idle of a hatched pet
local againFn: (() -> ())? = nil
local liveTweens: { Tween } = {}
local shakeToken = 0
local cardShown = false
local okButton: TextButton? = nil

-- Tweens the reveal starts are tracked so closing it can stop them (no lingering darkening
-- or FOV changes after a quick SKIP + OK).
local function tween(obj: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tw = TweenService:Create(obj, info, props)
	table.insert(liveTweens, tw)
	tw:Play()
	return tw
end
local finishedSignal = Signal.new()
Reveal.Finished = finishedSignal -- (result)
local startedSignal = Signal.new()
Reveal.Started = startedSignal
local stopAutoSignal = Signal.new()
Reveal.AutoStopped = stopAutoSignal -- the player pressed STOP AUTO OPEN

function Reveal.IsPlaying(): boolean
	return playing
end

local function hasPermanentSkip(): boolean
	local d = State.Data
	return d ~= nil and d.Passes ~= nil and d.Passes[Config.CrateSkip.Pass] == true
end

-- "Fast crate opening" is part of Permanent Crate Skip (skipping is paid now).
local function fast(): boolean
	local d = State.Data
	return d ~= nil and d.Settings.FastReveal == true and hasPermanentSkip()
end

-- SKIP: Permanent Crate Skip owners skip free; others use a bought Single Crate Skip (10 R$).
-- The server checks and spends; the reveal is only a cinematic of a hunter that's already saved.
local skipBusy = false
local pendingSkip = false
local skipButton: TextButton? = nil
local autoMode = false

local petMode = false -- egg hatches skip for free (crate skips are a paid product)

-- A SKIP button is only offered when it can actually skip: egg hatches (free), Permanent Crate
-- Skip owners, players holding skip tokens, or when the Single Crate Skip product is on sale.
local function skipProductOnSale(): boolean
	for _, p in Config.Products do
		if p.Key == Config.CrateSkip.Product then
			return p.ProductId ~= nil
		end
	end
	return false
end

local function canSkip(): boolean
	if petMode or hasPermanentSkip() then
		return true
	end
	local d = State.Data
	return (d ~= nil and (d.SkipTokens or 0) > 0) or skipProductOnSale()
end

local function skipLabel(): string
	local d = State.Data
	if petMode then
		return "SKIP ⏩"
	end
	if hasPermanentSkip() then
		return "SKIP ⏩"
	end
	local tokens = if d then d.SkipTokens or 0 else 0
	return if tokens > 0 then "SKIP ⏩ (" .. tokens .. ")" else "SKIP ⏩ R$10"
end

local function requestSkip()
	if skipping or cardShown or not playing or skipBusy then
		return
	end
	if petMode then
		skipping = true
		return
	end
	if not canSkip() then
		return -- gamepad B with no skip available
	end
	local myStage = stage
	skipBusy = true
	local res = State.Request("UseSkip")
	skipBusy = false
	if cardShown or not playing or stage ~= myStage then
		-- the reveal finished while we waited: nothing left to skip, so hand the token back
		if res.ok and not res.Permanent then
			task.spawn(State.Request, "RefundSkip")
		end
		return
	end
	if res.ok then
		pendingSkip = false
		skipping = true
		return
	end
	if res.err == "NeedSkip" then
		local buy = State.Request("Buy", Config.CrateSkip.Product)
		if buy.ok then
			pendingSkip = true -- the purchase arrives as a SkipGranted message
		else
			Kit.Toast(buy.err or "Skip isn't available", "Bad")
		end
	else
		Kit.Toast(res.err or "Couldn't skip", "Bad")
	end
end

-- Runs fn(alpha) every frame for `t` seconds (alpha 0→1). On skip: fn(1) immediately.
local function anim(t: number, fn: (number) -> ())
	if skipping or t <= 0 then
		fn(1)
		return
	end
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / t, 0, 1)
		fn(a)
		if a >= 1 or skipping then
			if skipping then
				fn(1)
			end
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function easeOutBack(a: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
end

local function easeOutBounce(a: number): number
	local n1, d1 = 7.5625, 2.75
	if a < 1 / d1 then
		return n1 * a * a
	elseif a < 2 / d1 then
		a -= 1.5 / d1
		return n1 * a * a + 0.75
	elseif a < 2.5 / d1 then
		a -= 2.25 / d1
		return n1 * a * a + 0.9375
	end
	a -= 2.625 / d1
	return n1 * a * a + 0.984375
end

local controls: any = nil
local function setControls(on: boolean)
	if not controls then
		local ok, mod = pcall(function()
			local ps = player:WaitForChild("PlayerScripts")
			return (require :: any)(ps:WaitForChild("PlayerModule"))
		end)
		if ok and mod then
			controls = mod:GetControls()
		end
	end
	if controls then
		pcall(function()
			if on then
				controls:Enable()
			else
				controls:Disable()
			end
		end)
	end
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = stage
	return p
end

local function buildStage(rarity: Config.RarityDef)
	local f = Instance.new("Folder")
	f.Name = "GHReveal"
	f.Parent = workspace
	stage = f
	-- floor disc with glowing trim
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 18, 18), Color = Color3.fromRGB(45, 28, 80), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(STAGE - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 19, 19), Color = rarity.Color, Material = Enum.Material.Neon, CFrame = CFrame.new(STAGE - Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	-- backdrop with spinning rays (SurfaceGui, unaffected by lighting)
	local back = part({ Size = Vector3.new(70, 44, 1), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 6, 14)) })
	local sg: SurfaceGui = Kit.new("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 14,
		LightInfluence = 0,
		Brightness = 0.7,
		Parent = back,
	})
	local bg: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sg })
	Kit.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 10, 40)),
			ColorSequenceKeypoint.new(0.5, rarity.Color2:Lerp(Color3.fromRGB(40, 20, 70), 0.55)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 10, 40)),
		}),
		Rotation = 90,
		Parent = bg,
	})
	local holder: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(1400, 1400),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = bg,
	})
	-- six full-length bars through the centre = twelve rays (GUI rotation pivots on the centre)
	for i = 0, 5 do
		local ray: Frame = Kit.new("Frame", {
			Size = UDim2.new(0, 110, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = rarity.Color,
			BackgroundTransparency = 0.68,
			BorderSizePixel = 0,
			Rotation = i * 30,
			Parent = holder,
		})
		Kit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 0.35),
				NumberSequenceKeypoint.new(0.5, 0.15),
				NumberSequenceKeypoint.new(0.58, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	rays = holder
	-- lights
	local l1 = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 7, -6)) })
	Kit.new("PointLight", { Range = 18, Brightness = 1.4, Color = Color3.fromRGB(255, 240, 255), Parent = l1 })
	local l2 = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 3, 3)) })
	Kit.new("PointLight", { Name = "RarityLight", Range = 12, Brightness = 0, Color = rarity.Color, Parent = l2 })
end

local function buildGui(): (ScreenGui, TextButton)
	local g: ScreenGui = Kit.new("ScreenGui", {
		Name = "GHRevealGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- buttons stay clear of notches / rounded corners / the Roblox top bar (set after creation:
	-- IgnoreGuiInset would otherwise override it); full-screen flashes overflow the insets anyway
	g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	Kit.new("UIScale", { Scale = Kit.UIScale(), Parent = g })
	-- touch screens: lift SKIP above where the jump button sits (same reserve as the HUD)
	local lift = 16
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		lift = (if math.min(vp.X, vp.Y) < 500 then 100 else 225) / Kit.UIScale()
	end
	local skip = Kit.Button(g, {
		Text = skipLabel(),
		Color = if hasPermanentSkip() then "Gray" else "Orange",
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(1, -16, 1, -lift),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 5,
		OnClick = function()
			task.spawn(requestSkip)
		end,
	})
	skipButton = skip
	-- no "SKIP R$10" while the Single Crate Skip product isn't on sale (it could only fail)
	skip.Visible = canSkip()
	if autoMode then
		Kit.Button(g, {
			Text = "STOP AUTO OPEN",
			Color = "Red",
			Size = UDim2.fromOffset(180, 40),
			Position = UDim2.new(0, 16, 1, -16),
			AnchorPoint = Vector2.new(0, 1),
			ZIndex = 5,
			OnClick = function()
				Reveal.StopAuto()
			end,
		})
	end
	gui = g
	return g, skip
end

local function flash(color: Color3, t: number)
	local g = gui
	if not g then
		return
	end
	local f: Frame = Kit.new("Frame", { Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1.5, -1.5), BackgroundColor3 = color, BackgroundTransparency = 0.1, ZIndex = 20, Parent = g })
	Kit.Tween(f, t, { BackgroundTransparency = 1 })
	task.delay(t, function()
		f:Destroy()
	end)
end

local function cameraShake(intensity: number, t: number)
	local cam = workspace.CurrentCamera
	if not cam or skipping then
		return
	end
	local my = shakeToken
	local base = cam.CFrame
	anim(t, function(a)
		if my ~= shakeToken or not playing then
			return
		end
		local k = intensity * (1 - a)
		cam.CFrame = base * CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
	if my == shakeToken and playing then
		cam.CFrame = base
	end
end

local function resultCard(g: ScreenGui, res: Result, rarity: Config.RarityDef)
	local def = Config.Hunters[res.Hunter]
	local d = State.Data
	-- right side of the screen, so the hunter (shifted left by the camera) stays the focus
	local card: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(360, 232),
		Position = UDim2.new(1, -20, 0.5, 10),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 10,
		Parent = g,
	})
	Kit.Corner(card, UDim.new(0, 18))
	Kit.Stroke(card, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(card, Theme.Panel2, Theme.Bg, 90)
	-- slide in from the right edge (no scale pop: scaling text renders it at many sizes)
	card.Position = UDim2.new(1, 380, 0.5, 10)
	Kit.Tween(card, 0.35, { Position = UDim2.new(1, -20, 0.5, 10) }, Enum.EasingStyle.Back)
	-- rarity ribbon
	local ribbon: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(200, 32),
		Position = UDim2.new(0.5, 0, 0, -16),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 12,
		Parent = card,
	})
	Kit.Corner(ribbon, UDim.new(0, 10))
	Kit.Stroke(ribbon, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(ribbon, rarity.Color, rarity.Color2, 0)
	Kit.Label(ribbon, rarity.Name, { Style = "Heading", ZIndex = 13 })
	Kit.Label(card, string.upper(def.Name), { Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(15, 22), Style = "Title", Fit = true, ZIndex = 11 })
	Kit.Label(card, "⚡ " .. Format.Short(def.Power) .. " POWER  ·  ❤️ " .. Format.Short(hpFor(def.Power)) .. " HP", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.fromOffset(15, 54), Color = Theme.Gold, Style = "Body", Fit = true, ZIndex = 11 })
	Kit.Label(card, def.Blurb, { Size = UDim2.new(1, -30, 0, 52), Position = UDim2.fromOffset(15, 78), Color = Theme.Muted, Font = Theme.Body, Style = "Small", ZIndex = 11, Stroke = 0 })
	if res.IsNew then
		local stamp = Kit.Label(card, "NEW!", { Size = UDim2.fromOffset(80, 30), Position = UDim2.new(1, 8, 0, -26), AnchorPoint = Vector2.new(1, 0), Color = Theme.Ecto, Style = "Title", ZIndex = 14 })
		stamp.Rotation = 14
		-- drops into place and fades in (one text size throughout)
		stamp.TextTransparency = 1
		Kit.Tween(stamp, 0.3, { Position = UDim2.new(1, 8, 0, 4), TextTransparency = 0 }, Enum.EasingStyle.Back)
	end
	-- buttons
	local row: Frame = Kit.new("Frame", {
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0, 10, 1, -58),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = card,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = row })
	local equipped = d and table.find(d.Equipped, res.Uid) ~= nil
	local slots = if d then d.Slots or Config.Inventory.BaseSlots else Config.Inventory.BaseSlots
	if d and not equipped then
		local free = #d.Equipped < slots
		-- with full slots, offer EQUIP BEST only if this hunter beats the weakest equipped one
		-- tier power, as the server's EquipBest ranks hunters (a Shiny/Mega can beat a new pull)
		local function tierPower(h: any): number
			local hd = h and Config.Hunters[h.Id]
			local t = Config.Tiers[h and h.Tier or 0] or Config.Tiers[0]
			return if hd then Rules.HunterPower(hd.Power, t.Mult) else 0
		end
		local weakest = math.huge
		for _, uid in d.Equipped do
			local h = d.Hunters[uid]
			if h then
				weakest = math.min(weakest, tierPower(h))
			end
		end
		local mine = d.Hunters[res.Uid]
		local newPower = if mine then tierPower(mine) else Rules.HunterPower(def.Power, 1)
		if free or newPower > weakest then
			local b: TextButton
			b = Kit.Button(row, {
				Text = if free then "EQUIP" else "EQUIP BEST",
				Color = "Green",
				Size = UDim2.fromOffset(118, 44),
				ZIndex = 12,
				OnClick = function()
					if not b.Active then
						return -- already equipped / request in flight (double tap)
					end
					b.Active = false
					local r = if free then State.Request("Equip", res.Uid) else State.Request("EquipBest")
					if r.ok then
						Kit.SetButtonText(b, "EQUIPPED ✅")
						b:SetAttribute("Color", "Gray")
					else
						b.Active = true
						Kit.Toast(r.err or "Couldn't equip", "Bad")
					end
				end,
			})
			b.Name = "EquipButton"
		end
	end
	if againFn then
		local crate = Config.Crates[res.Crate]
		local fnAgain = againFn
		Kit.Button(row, {
			Text = "AGAIN 💚" .. Format.Short(crate.Price),
			Color = "Purple",
			Size = UDim2.fromOffset(122, 44),
			ZIndex = 12,
			OnClick = function()
				fnAgain()
			end,
		})
	end
	okButton = Kit.Button(row, {
		Text = "OK",
		Color = "Blue",
		Size = UDim2.fromOffset(84, 44),
		ZIndex = 12,
		OnClick = function()
			Reveal.Close()
		end,
	})
end

-- Pet hatch result card: same look as the hunter card (rarity ribbon, name, bonus, OK).
local function petCard(g: ScreenGui, pet: Config.PetDef, rarity: Config.RarityDef)
	local card: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(360, 200),
		Position = UDim2.new(1, 380, 0.5, 10),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 10,
		Parent = g,
	})
	Kit.Corner(card, UDim.new(0, 18))
	Kit.Stroke(card, 4, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(card, Theme.Panel2, Theme.Bg, 90)
	Kit.Tween(card, 0.35, { Position = UDim2.new(1, -20, 0.5, 10) }, Enum.EasingStyle.Back)
	local ribbon: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(200, 32),
		Position = UDim2.new(0.5, 0, 0, -16),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 12,
		Parent = card,
	})
	Kit.Corner(ribbon, UDim.new(0, 10))
	Kit.Stroke(ribbon, 3, Theme.Outline, Enum.ApplyStrokeMode.Border)
	Kit.Gradient(ribbon, rarity.Color, rarity.Color2, 0)
	Kit.Label(ribbon, rarity.Name, { Style = "Heading", ZIndex = 13 })
	Kit.Label(card, string.upper(pet.Name), { Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(15, 22), Style = "Title", Fit = true, ZIndex = 11 })
	Kit.Label(card, PetsPanel.BonusText(pet.Bonus.Kind, pet.Bonus.Value), { Size = UDim2.new(1, -30, 0, 22), Position = UDim2.fromOffset(15, 56), Color = Theme.Ecto, Style = "Body", Fit = true, ZIndex = 11 })
	Kit.Label(card, "Equip it in PETS", { Size = UDim2.new(1, -30, 0, 20), Position = UDim2.fromOffset(15, 84), Color = Theme.Muted, Font = Theme.Body, Style = "Small", Stroke = 0, ZIndex = 11 })
	-- the hatched pet's portrait in the free bottom-left corner (left of the OK button)
	local pic: Frame = Kit.new("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0, 16, 1, -10), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = pet.Color:Lerp(Color3.new(0, 0, 0), 0.5), ZIndex = 11, Parent = card })
	Kit.Corner(pic, UDim.new(1, 0))
	Kit.Stroke(pic, 2.5, pet.Glow, Enum.ApplyStrokeMode.Border)
	PetPortrait.New(pic, pet.Id)
	okButton = Kit.Button(card, {
		Text = "OK",
		Color = "Blue",
		Size = UDim2.fromOffset(120, 44),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		ZIndex = 12,
		OnClick = function()
			Reveal.Close()
		end,
	})
end

local function teardownStage()
	shakeToken += 1
	for _, tw in liveTweens do
		tw:Cancel()
	end
	table.clear(liveTweens)
	cardShown = false
	okButton = nil
	if poseConn then
		poseConn:Disconnect()
		poseConn = nil
	end
	if stage then
		stage:Destroy()
		stage = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
	hunterRig = nil
	idleFn = nil
	rays = nil
end

-- Ends the reveal and gives the camera back.
function Reveal.Close()
	if not playing then
		return
	end
	-- a skip bought for THIS reveal that arrives later is kept as a token, not spent on the next one
	pendingSkip = false
	teardownStage()
	if cc then
		cc.Brightness = 0
		cc.Saturation = 0
		cc.Contrast = 0
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
	Kit.Screen().Enabled = true
	setControls(true)
	Targeting.SetBlocked(false)
	ProximityPromptService.Enabled = Kit.CurrentPanel() == nil
	ContextActionService:UnbindAction("GHRevealB")
	if GuiService.SelectedObject and not GuiService.SelectedObject:IsDescendantOf(Kit.Screen()) then
		GuiService.SelectedObject = nil
	end
	playing = false
	Kit.SetBusy("Reveal", false)
	finishedSignal:Fire()
end

export type PlayOpts = { Auto: boolean? }

-- Shared opening: locks input, builds the stage + GUI, frames the camera, starts the spin loop.
local function begin(rarity: Config.RarityDef): (ScreenGui, TextButton, Camera, CFrame, number)
	if playing then
		teardownStage() -- "AGAIN": keep the camera, rebuild the stage
	end
	playing = true
	Kit.SetBusy("Reveal", true) -- popups wait until the reveal is over
	skipping = autoMode and hasPermanentSkip() -- Auto Open + Permanent Skip: quick reveals
	startedSignal:Fire()
	Targeting.SetBlocked(true)
	setControls(false)
	Kit.Screen().Enabled = false
	ProximityPromptService.Enabled = false -- station prompts would float over the cinematic
	ContextActionService:BindActionAtPriority("GHRevealB", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if cardShown then
				Reveal.Close()
			else
				task.spawn(requestSkip)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.ButtonB)
	buildStage(rarity)
	local g, skip = buildGui()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = CAM_FOV
	local camCF = CFrame.lookAt(STAGE + Vector3.new(0, 4.6, -13), STAGE + Vector3.new(0, 2.6, 0))
	cam.CFrame = camCF
	cam.Focus = CFrame.new(STAGE + Vector3.new(0, 2.6, 0)) -- lighting detail follows Focus
	flash(Color3.new(1, 1, 1), 0.35)
	-- rays spin + the hunter poses / the pet bobs
	raySpeed = 20
	hunterT0 = os.clock()
	poseConn = RunService.RenderStepped:Connect(function(dt: number)
		if rays then
			rays.Rotation = (rays.Rotation + dt * raySpeed) % 360
		end
		if hunterRig then
			HunterRig.Pose(hunterRig, hunterState, os.clock() - hunterT0, 1)
		end
		if idleFn then
			idleFn(os.clock() - hunterT0)
		end
	end)
	return g, skip, cam, camCF, if fast() then 0.5 else 1
end

-- Build-up: shake (+ levitate, darken and converging energy for rarer pulls). onAlpha(a) runs
-- every frame (egg cracks). Returns the levitation height.
local function shakePhase(rarity: Config.RarityDef, f: number, base: CFrame, place: (CFrame) -> (), onAlpha: ((number) -> ())?): number
	local shakeT = (0.55 + rarity.RevealPause) * f
	local levitate = if rarity.Order >= 3 then 1.4 else 0
	local charge: ParticleEmitter? = nil
	if rarity.RevealPause > 0.3 and not skipping then
		local sphere = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12), Transparency = 1, CFrame = CFrame.new(STAGE + Vector3.new(0, 2.5, 0)) })
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Texture = Effects.Textures.Sparkle
		e.Color = ColorSequence.new(rarity.Color, rarity.Color2)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
		e.Speed = NumberRange.new(9, 12)
		e.Lifetime = NumberRange.new(0.45, 0.6)
		e.Rate = 0
		e.Parent = sphere
		charge = e
	end
	if cc and rarity.Darken > 0 and not skipping then
		tween(cc, TweenInfo.new(shakeT * 0.6), { Brightness = -rarity.Darken * 0.35, Saturation = -rarity.Darken * 0.4 })
	end
	local rl = (if stage then stage:FindFirstChild("RarityLight", true) else nil) :: any
	if not skipping then
		Sound.Play("CrateShake")
	end
	local nextShakeSound = os.clock() + 0.45
	anim(shakeT, function(a)
		local k = rarity.ShakeIntensity * (0.4 + a)
		local tt = os.clock()
		local wob = CFrame.Angles(math.sin(tt * 38) * 0.06 * k, math.sin(tt * 29) * 0.1 * k, math.sin(tt * 47) * 0.09 * k)
		local lift = levitate * math.sin(math.min(a * 1.6, 1) * math.pi / 2)
		place(base * CFrame.new(math.sin(tt * 53) * 0.12 * k, lift, 0) * wob)
		raySpeed = 20 + 160 * a * math.min(rarity.Order, 8) / 5 -- capped: Ultra/Exclusive don't keep scaling
		if charge then
			charge.Rate = 15 + 110 * a
		end
		if rl then
			rl.Brightness = 1.8 * a * math.min(1, rarity.Order / 3)
		end
		if onAlpha then
			onAlpha(a)
		end
		if tt >= nextShakeSound and a < 0.95 then
			nextShakeSound = tt + 0.45
			Sound.Play("CrateShake", 0.1)
		end
	end)
	if charge then
		charge.Rate = 0
	end
	place(base + Vector3.new(0, levitate, 0))
	return levitate
end

-- The pop: rarity sound, a short tinted flash, sparks and a ring (brightness kept low).
local function burstFx(rarity: Config.RarityDef, burstPos: Vector3, cam: Camera)
	if skipping then
		return
	end
	Sound.Play(rarity.Sound)
	flash(rarity.Color, 0.45)
	Effects.Flash(burstPos, rarity.Color, 3 + math.min(rarity.Order, 8) * 0.6, 0.4)
	Effects.Burst(burstPos, { Color = rarity.Color, Color2 = Color3.new(1, 1, 1), Count = math.floor(rarity.Particles * 0.6), Size = 0.65, Speed = 26, Life = 1.1, Gravity = 18 })
	Effects.Ring(STAGE + Vector3.new(0, 0.2, 0), rarity.Color, 10, 0.6)
	if cc then
		tween(cc, TweenInfo.new(0.5), { Brightness = 0.04, Saturation = 0.1 })
		task.delay(0.5, function()
			if cc then
				tween(cc, TweenInfo.new(0.6), { Brightness = 0, Saturation = 0 })
			end
		end)
	end
	if rarity.CameraPunch then
		cam.FieldOfView = CAM_FOV - 10
		tween(cam, TweenInfo.new(0.45, Enum.EasingStyle.Back), { FieldOfView = CAM_FOV })
		task.spawn(cameraShake, 0.5 * rarity.ShakeIntensity, 0.35)
	end
end

-- Landing: ring + sparks, then spotlight the winner (neutral key light; rarity light and rays dimmed).
local function landFx(rarity: Config.RarityDef, to: Vector3)
	if not skipping then
		Effects.Ring(to + Vector3.new(0, 0.15, 0), Color3.new(1, 1, 1), 5, 0.4)
		Effects.Burst(to + Vector3.new(0, 3, 0), { Color = rarity.Color, Count = math.floor(rarity.Particles / 5), Size = 0.45, Speed = 14, Life = 0.7 })
	end
	local key = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(to + Vector3.new(0, 4.5, -4)) })
	Kit.new("PointLight", { Range = 11, Brightness = 1.3, Color = Color3.new(1, 1, 1), Shadows = false, Parent = key })
	local rl = (if stage then stage:FindFirstChild("RarityLight", true) else nil) :: any
	if rl then
		tween(rl, TweenInfo.new(0.5), { Brightness = 0.6 })
	end
	if rays then
		for _, ray in rays:GetChildren() do
			if ray:IsA("Frame") then
				tween(ray, TweenInfo.new(0.5), { BackgroundTransparency = 0.8 })
			end
		end
	end
end

-- Shared ending: legendary title slam, camera slides left, the result card, auto-close.
local function finish(g: ScreenGui, skip: TextButton, cam: Camera, camCF: CFrame, rarity: Config.RarityDef, card: () -> ())
	if rarity.Order >= 5 and not skipping then
		local title = Kit.Label(g, rarity.Name .. "!", { Size = UDim2.fromOffset(600, 70), Position = UDim2.new(0.5, 0, 0.2, -60), AnchorPoint = Vector2.new(0.5, 0.5), Color = rarity.Color, Style = "Banner", ZIndex = 8, Stroke = 4 })
		-- solid colour (a UIGradient on big text dropped letters on phones); slams down and fades
		-- in rather than scaling, so the text renders at one size
		title.TextTransparency = 1
		Kit.Tween(title, 0.35, { Position = UDim2.fromScale(0.5, 0.2), TextTransparency = 0 }, Enum.EasingStyle.Back)
		task.spawn(cameraShake, 0.35, 0.3)
	end
	skip.Visible = false
	skipping = false
	raySpeed = 25
	cam.CFrame = camCF
	cam.Focus = CFrame.new(STAGE + Vector3.new(0, 2.6, 0))
	-- slide the camera so the winner sits left of centre, clear of the info card on the right
	local side = Vector3.new(-3.6, 0, 0)
	tween(cam, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(STAGE + Vector3.new(0, 4.6, -13) + side, STAGE + Vector3.new(0, 2.6, 0) + side) })
	card()
	cardShown = true
	if autoMode then
		-- Auto Open: the card closes by itself so the next crate can play
		local myStage = stage
		task.delay(if hasPermanentSkip() then 0.6 else 1.4, function()
			if playing and stage == myStage then
				Reveal.Close()
			end
		end)
	end
	if okButton and UserInputService.GamepadEnabled and UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then
		GuiService.SelectedObject = okButton
	end
end

-- Plays the opening for a server-confirmed result. `again` (optional) re-buys the same crate.
-- opts.Auto: Auto Open reveal (STOP button, the card closes by itself).
function Reveal.Play(res: Result, again: (() -> ())?, opts: PlayOpts?)
	petMode = false
	local def = Config.Hunters[res.Hunter]
	local crateDef = Config.Crates[res.Crate]
	if not def or not crateDef then
		return
	end
	autoMode = opts ~= nil and opts.Auto == true
	local rarity = Config.Rarities[def.Rarity]
	againFn = again
	local g, skip, cam, camCF, f = begin(rarity)
	local my = stage

	-- crate
	local crate = CrateRig.Build(res.Crate)
	crate.Model:ScaleTo(1.25)
	crate.Model.Parent = stage
	local base = CFrame.new(STAGE)
	local function placeCrate(cf: CFrame)
		crate.Model:PivotTo(cf)
	end
	placeCrate(base + Vector3.new(0, 9, 0))

	Sound.Play("CrateBuy")
	-- 1) drop in with a bounce
	anim(0.45 * f, function(a)
		placeCrate(base + Vector3.new(0, 9 * (1 - easeOutBounce(a)), 0))
	end)
	if stage ~= my then
		return
	end
	-- 2) shake
	local levitate = shakePhase(rarity, f, base, placeCrate)
	if stage ~= my then
		return
	end
	-- 3) locks pop off
	if not skipping then
		Sound.Play("LockPop")
	end
	anim(0.22 * f, function(a)
		local e = easeOutBack(a)
		crate.Motors.LockL.Transform = CFrame.new(-1.2 * e, 1.4 * e - 2.5 * a * a, -0.8 * e) * CFrame.Angles(0, 0, 2.5 * a)
		crate.Motors.LockR.Transform = CFrame.new(1.2 * e, 1.4 * e - 2.5 * a * a, -0.8 * e) * CFrame.Angles(0, 0, -2.5 * a)
	end)
	-- drop the padlocks (and their welded shackles) out of sight
	crate.Motors.LockL.Transform = CFrame.new(0, -60, 0)
	crate.Motors.LockR.Transform = CFrame.new(0, -60, 0)
	-- 4) lid flies open + light burst
	burstFx(rarity, crate.Burst.WorldPosition, cam)
	crate.Glow.Color = rarity.Color
	anim(0.3 * f, function(a)
		crate.Motors.Lid.Transform = CFrame.Angles(math.rad(115) * easeOutBack(a), 0, 0)
		crate.Glow.Transparency = 1 - 0.6 * a
	end)
	if stage ~= my then
		return
	end
	-- 5) hunter leaps out
	local rig = HunterRig.Build(res.Hunter)
	rig.Model:ScaleTo(1.2)
	rig.Model.Parent = stage
	hunterRig = rig
	hunterState = "Celebrate"
	hunterT0 = os.clock()
	local from = STAGE + Vector3.new(0, levitate + 0.6, 0.2)
	local to = STAGE + Vector3.new(0, 0, -4.6)
	anim(0.55 * f, function(a)
		local p = from:Lerp(to, a) + Vector3.new(0, 5.5 * 4 * a * (1 - a), 0)
		local spin = (1 - a) * math.pi * 2
		rig.Model:PivotTo(CFrame.new(p) * CFrame.Angles(0, spin, 0))
	end)
	rig.Model:PivotTo(CFrame.new(to))
	-- the crate settles back down behind the hunter
	placeCrate(base)
	landFx(rarity, to)
	tween(crate.Glow, TweenInfo.new(0.5), { Transparency = 0.75 })
	if stage ~= my then
		return
	end
	-- 6) title slam + result card
	finish(g, skip, cam, camCF, rarity, function()
		resultCard(g, res, rarity)
	end)
end

--------------------------------------------------------------------------------
-- PET EGG HATCH: same stage, camera and pacing as a crate, with the egg in the crate's place.
-- The egg copies the hatchery pedestal looks (World/Hatchery); its front faces the camera (-Z).
--------------------------------------------------------------------------------
type EggPiece = { Part: Part, Offset: CFrame, Top: boolean, Tr: number }

local function buildEgg(egg: Config.EggDef): ({ EggPiece }, { Part })
	local pieces: { EggPiece } = {}
	local cracks: { Part } = {}
	local SMOOTH, NEON, GLASS = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Glass
	local function add(props: { [string]: any }, offset: CFrame): Part
		local p = part(props)
		table.insert(pieces, { Part = p, Offset = offset, Top = offset.Y > 3.1, Tr = p.Transparency })
		return p
	end
	local function ball(d: number, x: number, y: number, z: number, col: Color3, mat: Enum.Material?, tr: number?): Part
		return add({ Shape = Enum.PartType.Ball, Size = Vector3.one * d, Color = col, Material = mat or SMOOTH, Transparency = tr or 0 }, CFrame.new(x, y, z))
	end
	local function block(size: Vector3, cf: CFrame, col: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
		return add({ Shape = shape or Enum.PartType.Block, Size = size, Color = col, Material = mat or SMOOTH }, cf)
	end
	local glass = egg.Id == "PhantomEgg"
	local shellMat = if glass then GLASS else SMOOTH
	local shellTr = if glass then 0.3 else 0
	local low = ball(4.2, 0, 2.1, 0, egg.Color, shellMat, shellTr)
	local high = ball(3.4, 0, 3.6, 0, egg.Color, shellMat, shellTr)
	low.Reflectance = if glass then 0.1 else 0.15
	high.Reflectance = low.Reflectance
	if egg.Id == "HauntedEgg" then
		-- green ecto cracks across the front and dark speckles
		for _, c in { { -0.9, 2.4, 25 }, { 0.2, 2.9, -35 }, { 0.9, 2.2, 40 }, { -0.2, 3.9, 60 } } do
			block(Vector3.new(0.18, 1.2, 0.2), CFrame.new(c[1], c[2], -2.05) * CFrame.Angles(0, 0, math.rad(c[3])), egg.Accent, NEON)
		end
		for _, sp in { { -1.3, 1.6 }, { 1.2, 3.4 }, { 0.6, 1.2 } } do
			ball(0.6, sp[1], sp[2], -1.75, Color3.fromRGB(70, 30, 120))
		end
	elseif egg.Id == "PhantomEgg" then
		-- soft inner core and a ghost face
		ball(2.4, 0, 2.5, 0, egg.Accent, SMOOTH, 0.4)
		local dark = Color3.fromRGB(30, 30, 60)
		ball(0.8, -0.7, 3.4, -1.55, dark)
		ball(0.8, 0.7, 3.4, -1.55, dark)
		block(Vector3.new(0.9, 0.6, 0.3), CFrame.new(0, 2.4, -2.0), dark)
	elseif egg.Id == "MoonlightEgg" then
		-- crescent moon (pale disc partly covered by an egg-coloured disc) and stars
		local cyl = Enum.PartType.Cylinder
		block(Vector3.new(0.2, 1.6, 1.6), CFrame.new(0.2, 3.0, -2.0) * CFrame.Angles(0, math.pi / 2, 0), egg.Accent, SMOOTH, cyl)
		block(Vector3.new(0.2, 1.4, 1.4), CFrame.new(-0.2, 3.15, -2.08) * CFrame.Angles(0, math.pi / 2, 0), egg.Color, SMOOTH, cyl)
		for _, s in { { -1.2, 1.7 }, { 1.1, 2.0 }, { 0.8, 4.1 }, { -0.9, 4.0 }, { 0.1, 1.2 } } do
			ball(0.35, s[1], s[2], -1.85, Color3.fromRGB(255, 245, 200), NEON)
		end
	end
	-- hatch cracks: a zigzag around the waist that shows up bit by bit while the egg shakes
	for i, c in { { -1.5, 3.0, 40 }, { -0.75, 3.15, -40 }, { 0, 3.0, 40 }, { 0.75, 3.15, -40 }, { 1.5, 3.0, 40 } } do
		local z = -math.sqrt(math.max(0, 1.87 ^ 2 - c[1] ^ 2)) - 0.05 -- shell radius at the waist (y 3)
		local p = block(Vector3.new(0.16, 0.95, 0.16), CFrame.new(c[1], c[2], z) * CFrame.Angles(0, 0, math.rad(c[3])), egg.Accent, NEON)
		p.Transparency = 1
		cracks[i] = p
	end
	return pieces, cracks
end

export type PetResult = { Egg: string, Pet: string }

-- Hatch cinematic for a pet the server already granted (presentation only).
function Reveal.PlayPet(res: PetResult)
	local egg = Config.Eggs[res.Egg]
	local pet = Config.Pets[res.Pet]
	local rarity = pet and Config.Rarities[pet.Rarity]
	if not egg or not pet or not rarity then
		return
	end
	autoMode = false
	againFn = nil
	petMode = true
	local g, skip, cam, camCF, f = begin(rarity)
	local my = stage

	local pieces, cracks = buildEgg(egg)
	local base = CFrame.new(STAGE)
	local topCF = CFrame.identity
	local function placeEgg(cf: CFrame)
		for _, pc in pieces do
			pc.Part.CFrame = if pc.Top then cf * topCF * pc.Offset else cf * pc.Offset
		end
	end
	placeEgg(base + Vector3.new(0, 9, 0))

	Sound.Play("CrateBuy")
	-- 1) drop in with a bounce
	anim(0.45 * f, function(a)
		placeEgg(base + Vector3.new(0, 9 * (1 - easeOutBounce(a)), 0))
	end)
	if stage ~= my then
		return
	end
	-- 2) shake while the cracks spread
	local levitate = shakePhase(rarity, f, base, placeEgg, function(a)
		for i, c in cracks do
			c.Transparency = if a >= i / (#cracks + 1) then 0 else 1
		end
	end)
	for _, c in cracks do
		c.Transparency = 0
	end
	if stage ~= my then
		return
	end
	-- 3) the shell pops: the top flies off, the bottom fades
	local eggCF = base + Vector3.new(0, levitate, 0)
	burstFx(rarity, eggCF.Position + Vector3.new(0, 3.2, 0), cam)
	anim(0.3 * f, function(a)
		local e = easeOutBack(a)
		topCF = CFrame.new(1.2 * a, 3.5 * e, 1.5 * a) * CFrame.Angles(-1.4 * a, 0, -0.9 * a)
		for _, pc in pieces do
			pc.Part.Transparency = if pc.Top then pc.Tr + (1 - pc.Tr) * a else pc.Tr
		end
		placeEgg(eggCF)
	end)
	for _, pc in pieces do
		if not pc.Top then
			tween(pc.Part, TweenInfo.new(0.45 * f), { Transparency = 1 })
		end
	end
	if stage ~= my then
		return
	end
	-- 4) the pet pops out (PetFollowers' ghost, scaled up, rarity glow kept soft)
	local model = PetFollowers.BuildPet(pet.Id)
	if not model then
		return
	end
	model:ScaleTo(3)
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") then -- ScaleTo widened the range 3x: keep the rarity glow soft
			d.Brightness = math.min(d.Brightness, 0.9)
			d.Range = math.min(d.Range, 12)
		end
	end
	model.Parent = stage
	local from = eggCF.Position + Vector3.new(0, 2.5, 0)
	local to = STAGE + Vector3.new(0, 3, -4.6)
	anim(0.55 * f, function(a)
		local p = from:Lerp(to, a) + Vector3.new(0, 5.5 * 4 * a * (1 - a), 0)
		model:PivotTo(CFrame.new(p) * CFrame.Angles(0, (1 - a) * math.pi * 2, 0))
	end)
	model:PivotTo(CFrame.new(to))
	hunterT0 = os.clock()
	idleFn = function(t: number)
		model:PivotTo(CFrame.new(to + Vector3.new(0, math.sin(t * 2.2) * 0.3, 0)) * CFrame.Angles(0, math.sin(t * 1.3) * 0.35, 0))
	end
	landFx(rarity, to - Vector3.new(0, 3, 0))
	if stage ~= my then
		return
	end
	-- 5) title slam + pet card
	finish(g, skip, cam, camCF, rarity, function()
		petCard(g, pet, rarity)
	end)
end

function Reveal.Init()
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "GHRevealCC"
	effect.Parent = Lighting
	cc = effect
end

function Reveal.StopAuto()
	autoMode = false
	task.spawn(function()
		State.Request("AutoOpen", nil)
	end)
	stopAutoSignal:Fire()
end

function Reveal.Start()
	-- a Single Crate Skip bought during a reveal is used right away
	State.OnFx("SkipGranted", function()
		if skipButton and skipButton.Parent then
			Kit.SetButtonText(skipButton, skipLabel())
			skipButton.Visible = not cardShown and canSkip()
		end
		if pendingSkip and playing and not cardShown then
			task.spawn(requestSkip)
		end
	end)
	-- respawning mid-reveal must not leave the camera stuck
	player.CharacterAdded:Connect(function()
		if playing then
			Reveal.Close()
		end
	end)
end

return Reveal
