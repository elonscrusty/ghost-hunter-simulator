--!strict
-- Short-lived VFX helpers (bursts, rings, sparkles). All local, all self-cleaning, and capped
-- so a busy moment never turns into a GPU benchmark.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

Effects.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local folder: Folder
local live = 0
local MAX_LIVE = 24

local function holder(pos: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Parent = folder
	return p
end

export type BurstOpts = {
	Color: Color3,
	Color2: Color3?,
	Count: number?,
	Size: number?,
	Speed: number?,
	Life: number?,
	Texture: string?,
	Spread: number?,
	Gravity: number?,
	LightEmission: number?,
}

function Effects.Burst(pos: Vector3, o: BurstOpts)
	if live >= MAX_LIVE then
		return
	end
	live += 1
	local p = holder(pos)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.Texture or Effects.Textures.Sparkle
	e.Color = ColorSequence.new(o.Color, o.Color2 or o.Color)
	local size = o.Size or 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(0.6, size * 0.8), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
	local life = o.Life or 0.7
	e.Lifetime = NumberRange.new(life * 0.6, life)
	local speed = o.Speed or 18
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Acceleration = Vector3.new(0, -(o.Gravity or 0), 0)
	e.Drag = 3
	e.LightEmission = o.LightEmission or 1
	e.Rate = 0
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = p
	e:Emit(math.min(o.Count or 20, 160))
	task.delay(life + 0.2, function()
		live -= 1
		p:Destroy()
	end)
end

-- Expanding flat neon ring on the ground / around a point.
function Effects.Ring(pos: Vector3, color: Color3, radius: number, time: number?)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Transparency = 0.2
	r.Size = Vector3.new(0.3, 1, 1)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	r.Parent = folder
	local t = time or 0.5
	TweenService:Create(r, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(r, t + 0.05)
end

-- Expanding glowing sphere (poofs, reveal flashes).
function Effects.Flash(pos: Vector3, color: Color3, radius: number, time: number?)
	local s = Instance.new("Part")
	s.Shape = Enum.PartType.Ball
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.CastShadow = false
	s.Material = Enum.Material.Neon
	s.Color = color
	s.Transparency = 0.15
	s.Size = Vector3.new(1, 1, 1) * radius * 0.4
	s.CFrame = CFrame.new(pos)
	s.Parent = folder
	local t = time or 0.35
	TweenService:Create(s, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1, 1, 1) * radius * 2,
		Transparency = 1,
	}):Play()
	Debris:AddItem(s, t + 0.05)
end

-- The signature ghost POOF: flash + cloud + sparkles + ring.
function Effects.Poof(pos: Vector3, color: Color3, scale: number, big: boolean)
	Effects.Flash(pos, Color3.new(1, 1, 1), 3 * scale, 0.25)
	Effects.Flash(pos, color, 4.5 * scale, 0.45)
	Effects.Burst(pos, { Color = Color3.fromRGB(245, 240, 255), Color2 = color, Count = if big then 40 else 18, Size = 2.2 * scale, Speed = 10 * scale, Life = 0.8, Texture = Effects.Textures.Smoke, LightEmission = 0.3 })
	Effects.Burst(pos, { Color = color, Count = if big then 60 else 24, Size = 0.9 * math.sqrt(scale), Speed = 22 * math.sqrt(scale), Life = 0.7 })
	Effects.Ring(pos, color, 7 * scale, 0.5)
end

function Effects.Folder(): Folder
	return folder
end

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "GHEffects"
	folder.Parent = workspace
end

return Effects
