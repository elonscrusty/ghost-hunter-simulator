--!strict
-- Part helpers for the procedural map. Every builder goes through these so that parts
-- get the same performance defaults (anchored, non-colliding, no touch/query, no shadow)
-- unless `Solid = true` is passed for floors, walls and buildings.
-- Also holds the seeded RNG, budgets (lights, emitters, tagged props) and a keep-out
-- registry so scattered props never land inside ghost areas, roads or stations.
--
-- Neon is an accent, not a surface: keep it for small things whose glow means something
-- (windows, lamp globes, lanterns, jack-o'-lantern faces at landmarks, eyes, small ectoplasm
-- cracks/puddles). Trims, bands, rings, frames and pads use a solid material with a
-- Kit.Vivid colour instead. Kit.Stats.Neon counts the Neon parts so the build log shows it.

local CollectionService = game:GetService("CollectionService")

local Kit = {}

export type Opts = {
	Name: string?,
	Mat: Enum.Material?,
	Transp: number?,
	Solid: boolean?, -- CanCollide + CanQuery (+ shadow)
	Shadow: boolean?,
	Shape: Enum.PartType?,
	Refl: number?,
}

Kit.Rng = Random.new(42)

Kit.Stats = { Parts = 0, Neon = 0, Lights = 0, Emitters = 0, Floating = 0, Flicker = 0 }
-- Budgets for the whole 16-zone map (per zone ~9 lights, 2-3 emitters, 6-8 floating, 2 flicker).
local MAX_LIGHTS = 170
local MAX_EMITTERS = 54
local MAX_FLOATING = 140
local MAX_FLICKER = 34

local NO_OPTS: Opts = {}

local function apply(p: BasePart, size: Vector3, cf: CFrame, color: Color3, opts: Opts?)
	local o: Opts = opts or NO_OPTS
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = o.Mat or Enum.Material.SmoothPlastic
	p.Transparency = o.Transp or 0
	p.Reflectance = o.Refl or 0
	local solid = o.Solid == true
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = false
	if o.Shadow ~= nil then
		p.CastShadow = o.Shadow
	else
		p.CastShadow = solid
	end
	if o.Name then
		p.Name = o.Name
	end
	Kit.Stats.Parts += 1
	if p.Material == Enum.Material.Neon then
		Kit.Stats.Neon += 1
	end
end

-- A slightly more saturated, brighter version of a colour. Solid materials are lit by the
-- scene instead of glowing, so former neon trims get this to stay candy-bright.
-- Near-greys/whites keep their saturation (no accidental tint).
function Kit.Vivid(c: Color3): Color3
	local h, s, v = c:ToHSV()
	local s2 = if s < 0.1 then s else math.min(1, s * 1.15 + 0.05)
	return Color3.fromHSV(h, s2, math.min(1, v * 1.06 + 0.03))
end

-- Block (or Ball/Cylinder via opts.Shape) at an arbitrary CFrame.
function Kit.Part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: Opts?): Part
	local p: Part = Instance.new("Part")
	if opts and opts.Shape then
		p.Shape = opts.Shape
	end
	apply(p, size, cf, color, opts)
	p.Parent = parent
	return p
end

-- Axis-aligned block from two corners.
function Kit.Box(parent: Instance, a: Vector3, b: Vector3, color: Color3, opts: Opts?): Part
	local lo = a:Min(b)
	local hi = a:Max(b)
	return Kit.Part(parent, hi - lo, CFrame.new((lo + hi) / 2), color, opts)
end

-- WedgePart: the slope faces local -Z (low edge at -Z, tall face at +Z).
function Kit.Wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, opts: Opts?): WedgePart
	local w: WedgePart = Instance.new("WedgePart")
	apply(w, size, cf, color, opts)
	w.Parent = parent
	return w
end

function Kit.Ball(parent: Instance, d: number, pos: Vector3, color: Color3, opts: Opts?): Part
	local p: Part = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	apply(p, Vector3.new(d, d, d), CFrame.new(pos), color, opts)
	p.Parent = parent
	return p
end

-- Vertical cylinder centred at cf.
function Kit.Cyl(parent: Instance, height: number, d: number, cf: CFrame, color: Color3, opts: Opts?): Part
	local p: Part = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	apply(p, Vector3.new(height, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, opts)
	p.Parent = parent
	return p
end

-- Flat vertical cylinder whose TOP surface is at topY.
function Kit.Disc(parent: Instance, x: number, z: number, topY: number, d: number, thick: number, color: Color3, opts: Opts?): Part
	return Kit.Cyl(parent, thick, d, CFrame.new(x, topY - thick / 2, z), color, opts)
end

-- Cylinder lying along the world axis given by `along` ("X" or "Z").
function Kit.CylFlat(parent: Instance, length: number, d: number, pos: Vector3, along: string, color: Color3, opts: Opts?): Part
	local p: Part = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	local cf = CFrame.new(pos)
	if along == "Z" then
		cf *= CFrame.Angles(0, math.pi / 2, 0)
	end
	apply(p, Vector3.new(length, d, d), cf, color, opts)
	p.Parent = parent
	return p
end

function Kit.Folder(parent: Instance, name: string): Folder
	local f: Folder = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.Model(parent: Instance, name: string): Model
	local m: Model = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Yaw (radians) that turns a part's local -Z (its Front face) toward world (dx, dz).
function Kit.FaceYaw(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

function Kit.Comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s
	while true do
		local replaced, k = string.gsub(out, "^(-?%d+)(%d%d%d)", "%1,%2")
		out = replaced
		if k == 0 then
			break
		end
	end
	return out
end

--==================================================================
-- GUI
--==================================================================
function Kit.Gui(part: BasePart, face: Enum.NormalId, pps: number?): SurfaceGui
	local g: SurfaceGui = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps or 40
	g.LightInfluence = 0
	g.Brightness = 1.5
	g.ZOffset = 1
	g.ResetOnSpawn = false
	g.Parent = part
	return g
end

export type LabelOpts = {
	Name: string?,
	Pos: UDim2?,
	Size: UDim2?,
	Font: Enum.Font?,
	Stroke: Color3?,
	Rotation: number?,
}

local NO_LABEL: LabelOpts = {}

function Kit.Label(gui: GuiBase2d, text: string, color: Color3, opts: LabelOpts?): TextLabel
	local o: LabelOpts = opts or NO_LABEL
	local t: TextLabel = Instance.new("TextLabel")
	t.Name = o.Name or "Label"
	t.BackgroundTransparency = 1
	t.Position = o.Pos or UDim2.fromScale(0, 0)
	t.Size = o.Size or UDim2.fromScale(1, 1)
	t.Font = o.Font or Enum.Font.FredokaOne
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.Rotation = o.Rotation or 0
	local stroke: UIStroke = Instance.new("UIStroke")
	stroke.Color = o.Stroke or Color3.fromRGB(40, 20, 70)
	stroke.Thickness = 3
	stroke.Parent = t
	t.Parent = gui
	return t
end

-- Whole-face sign on a part.
function Kit.Sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3, opts: LabelOpts?): TextLabel
	local g = Kit.Gui(part, face)
	return Kit.Label(g, text, color, opts)
end

--==================================================================
-- EFFECTS (budgeted)
--==================================================================
function Kit.Light(part: BasePart, color: Color3, range: number, brightness: number, flicker: boolean?): PointLight?
	if Kit.Stats.Lights >= MAX_LIGHTS then
		return nil
	end
	Kit.Stats.Lights += 1
	local l: PointLight = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
	if flicker and Kit.Stats.Flicker < MAX_FLICKER then
		Kit.Stats.Flicker += 1
		CollectionService:AddTag(part, "FlickerLight")
	end
	return l
end

function Kit.Emitter(part: BasePart, color: Color3, rate: number, size: number?, speed: number?): ParticleEmitter?
	if Kit.Stats.Emitters >= MAX_EMITTERS then
		return nil
	end
	Kit.Stats.Emitters += 1
	local e: ParticleEmitter = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.LightInfluence = 0
	e.Rate = rate
	e.Lifetime = NumberRange.new(4, 7)
	e.Speed = NumberRange.new(speed or 0.6, (speed or 0.6) * 2)
	e.SpreadAngle = Vector2.new(180, 15)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-15, 15)
	local s = size or 6
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s * 0.5),
		NumberSequenceKeypoint.new(0.5, s),
		NumberSequenceKeypoint.new(1, s * 1.2),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Acceleration = Vector3.new(0, 0.15, 0)
	e.Parent = part
	return e
end

-- Tag a single anchored part as a client-animated floating prop.
function Kit.Float(part: BasePart, bob: number): boolean
	if Kit.Stats.Floating >= MAX_FLOATING then
		return false
	end
	Kit.Stats.Floating += 1
	part:SetAttribute("BobHeight", bob)
	CollectionService:AddTag(part, "FloatingProp")
	return true
end

--==================================================================
-- KEEP-OUT REGISTRY (2D, X/Z)
--==================================================================
type Circle = { X: number, Z: number, R: number }
type Rect = { X1: number, Z1: number, X2: number, Z2: number, Road: boolean }

local circles: { Circle } = {}
local rects: { Rect } = {}

function Kit.ResetKeepOut()
	table.clear(circles)
	table.clear(rects)
end

-- Fresh RNG, budgets and keep-out map (so rebuilding gives the identical map).
function Kit.Reset()
	Kit.Rng = Random.new(42)
	Kit.Stats.Parts = 0
	Kit.Stats.Neon = 0
	Kit.Stats.Lights = 0
	Kit.Stats.Emitters = 0
	Kit.Stats.Floating = 0
	Kit.Stats.Flicker = 0
	Kit.ResetKeepOut()
end

function Kit.AddCircle(x: number, z: number, r: number)
	table.insert(circles, { X = x, Z = z, R = r })
end

function Kit.AddRect(x1: number, z1: number, x2: number, z2: number, road: boolean?)
	table.insert(rects, {
		X1 = math.min(x1, x2),
		Z1 = math.min(z1, z2),
		X2 = math.max(x1, x2),
		Z2 = math.max(z1, z2),
		Road = road == true,
	})
end

-- True when a circle of radius r at (x, z) touches no keep-out and stays inside the play area.
function Kit.IsFree(x: number, z: number, r: number, ignoreRoads: boolean?): boolean
	if math.abs(x) + r > 136 then
		return false
	end
	for _, c in circles do
		local dx, dz = x - c.X, z - c.Z
		if dx * dx + dz * dz < (c.R + r) * (c.R + r) then
			return false
		end
	end
	for _, q in rects do
		if not (ignoreRoads and q.Road) then
			if x + r > q.X1 and x - r < q.X2 and z + r > q.Z1 and z - r < q.Z2 then
				return false
			end
		end
	end
	return true
end

export type GateLayout = { Z: number, Width: number }

-- Typed views of Config.Layout tables (iterating a table literal yields unknown in strict mode).
function Kit.Gates(layout: any): { [string]: GateLayout }
	return layout.Gates
end

function Kit.CrateStations(layout: any): { [string]: Vector3 }
	return layout.CrateStations
end

function Kit.ZoneSpawns(layout: any): { [string]: Vector3 }
	return layout.ZoneSpawns
end

function Kit.Pick<T>(list: { T }): T
	return list[Kit.Rng:NextInteger(1, #list)]
end

return Kit
