--!strict
-- Small part factory shared by HunterRig, GhostRig and CrateRig.
-- Every part is created non-colliding, non-touching, non-querying, unanchored and massless;
-- callers flip what they need (Root/Core/Base are anchored, Core is queryable).

local RigUtil = {}

export type Opts = {
	Material: Enum.Material?,
	Transparency: number?,
	Name: string?,
	Reflectance: number?,
	Shadow: boolean?, -- force CastShadow (default: only parts larger than 1.5 studs cast)
}

local function setup(p: BasePart, size: Vector3, cf: CFrame, color: Color3, parent: Instance, opts: Opts?)
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	local maxDim = math.max(size.X, size.Y, size.Z)
	p.CastShadow = maxDim >= 1.5
	if opts then
		if opts.Material then
			p.Material = opts.Material
		end
		if opts.Transparency then
			p.Transparency = opts.Transparency
		end
		if opts.Name then
			p.Name = opts.Name
		end
		if opts.Reflectance then
			p.Reflectance = opts.Reflectance
		end
		if opts.Shadow ~= nil then
			p.CastShadow = opts.Shadow
		end
	end
	if p.Material == Enum.Material.Neon then
		p.CastShadow = false
	end
	p.Parent = parent
end

function RigUtil.Ball(d: number, cf: CFrame, color: Color3, parent: Instance, opts: Opts?): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	setup(p, Vector3.new(d, d, d), cf, color, parent, opts)
	return p
end

function RigUtil.Block(size: Vector3, cf: CFrame, color: Color3, parent: Instance, opts: Opts?): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	setup(p, size, cf, color, parent, opts)
	return p
end

-- Cylinder: `length` runs along the part's X axis, `d` is the diameter.
function RigUtil.Cyl(length: number, d: number, cf: CFrame, color: Color3, parent: Instance, opts: Opts?): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	setup(p, Vector3.new(length, d, d), cf, color, parent, opts)
	return p
end

-- WedgePart: full height on its back (+Z) face, sloping down to its front (-Z) bottom edge.
function RigUtil.Wedge(size: Vector3, cf: CFrame, color: Color3, parent: Instance, opts: Opts?): BasePart
	local p = Instance.new("WedgePart")
	setup(p, size, cf, color, parent, opts)
	return p
end

-- Rotations that turn a Cylinder's X axis to point along another axis.
RigUtil.AxisY = CFrame.Angles(0, 0, math.pi / 2) -- cylinder stands upright (disc lies flat)
RigUtil.AxisZ = CFrame.Angles(0, math.pi / 2, 0) -- cylinder points forward/back (disc faces -Z)

-- Rotation that stands a cube on one corner (a cheap faceted gem or crystal tip).
RigUtil.VertexUp = CFrame.Angles(0, 0, math.atan(math.sqrt(2))) * CFrame.Angles(0, math.pi / 4, 0)

-- Frame for a Cylinder running from `a` to `b` (give it length (b - a).Magnitude).
function RigUtil.Between(a: Vector3, b: Vector3): CFrame
	return CFrame.lookAt((a + b) / 2, b) * RigUtil.AxisZ
end

-- A frame at `pos` whose front (-Z) looks along `normal` (used to stick things onto round surfaces).
function RigUtil.Facing(pos: Vector3, normal: Vector3): CFrame
	return CFrame.lookAt(pos, pos + normal.Unit)
end

-- A forward-facing disc (Cylinder axis along the frame's -Z) on a round surface.
function RigUtil.DiscFacing(pos: Vector3, normal: Vector3): CFrame
	return CFrame.lookAt(pos, pos + normal.Unit) * RigUtil.AxisZ
end

-- Cog wheel lying in the frame's XY plane (disc axis along the frame's Z): a disc of diameter `d`
-- plus `teeth` square teeth round its rim. Returns every part so the caller can weld them.
function RigUtil.Gear(d: number, thick: number, teeth: number, cf: CFrame, color: Color3, parent: Instance, opts: Opts?): { BasePart }
	local parts = { RigUtil.Cyl(thick, d, cf * RigUtil.AxisZ, color, parent, opts) }
	local t = math.max(d * 0.15, 0.08)
	for i = 0, teeth - 1 do
		local a = i * 2 * math.pi / teeth
		local cfT = cf * CFrame.Angles(0, 0, a) * CFrame.new(0, d / 2 + t * 0.3, 0)
		table.insert(parts, RigUtil.Block(Vector3.new(t, t * 1.1, thick), cfT, color, parent, opts))
	end
	return parts
end

-- Hollow ring of `n` blocks in the frame's XY plane: `r` to the block centres, `w` radial width,
-- `thick` along the frame's Z. Returns every part so the caller can weld them.
function RigUtil.Hoop(r: number, w: number, thick: number, n: number, cf: CFrame, color: Color3, parent: Instance, opts: Opts?): { BasePart }
	local parts = {}
	local seg = 2 * (r + w / 2) * math.tan(math.pi / n) + 0.02
	for i = 0, n - 1 do
		local a = i * 2 * math.pi / n
		table.insert(parts, RigUtil.Block(Vector3.new(seg, w, thick), cf * CFrame.Angles(0, 0, a) * CFrame.new(0, r, 0), color, parent, opts))
	end
	return parts
end

function RigUtil.Weld(a: BasePart, b: BasePart): WeldConstraint
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
	return w
end

-- Classic Weld with the current offset baked in (deterministic even outside Workspace).
function RigUtil.FixedWeld(a: BasePart, b: BasePart): Weld
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = a.CFrame:ToObjectSpace(b.CFrame)
	w.C1 = CFrame.identity
	w.Parent = b
	return w
end

function RigUtil.Motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = c0
	m.C1 = c1
	m.Parent = p0
	return m
end

function RigUtil.AttachAt(part: BasePart, name: string, worldCf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = part.CFrame:ToObjectSpace(worldCf)
	a.Parent = part
	return a
end

function RigUtil.Shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

function RigUtil.Mix(a: Color3, b: Color3, t: number): Color3
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

-- Slightly more saturated, brighter colour for accents that are solid instead of Neon
-- (Neon is kept for tool emitters, eyes, flames and one small light per rig).
-- Near-greys/whites keep their saturation.
function RigUtil.Vivid(c: Color3): Color3
	local h, s, v = c:ToHSV()
	local s2 = if s < 0.1 then s else math.min(1, s * 1.15 + 0.05)
	return Color3.fromHSV(h, s2, math.min(1, v * 1.06 + 0.03))
end

-- Highest world Y reached by a part's box (exact for blocks, conservative for balls/cylinders).
function RigUtil.TopY(p: BasePart): number
	local _, y, _, _, _, _, r10, r11, r12 = p.CFrame:GetComponents()
	local s = p.Size
	return y + (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z) / 2
end

function RigUtil.BottomY(p: BasePart): number
	local _, y, _, _, _, _, r10, r11, r12 = p.CFrame:GetComponents()
	local s = p.Size
	return y - (math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z) / 2
end

return RigUtil
