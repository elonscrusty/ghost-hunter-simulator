--!strict
-- Hunter crates: chunky treasure chests built from plain Parts (no asset IDs).
--
--   CrateRig.Build(crateId) -> CrateRig
--
-- Size at scale 1: 5 wide (X), 3.6 tall (Y), 3.6 deep (Z); the front faces -Z.
-- `Base` (anchored, PrimaryPart) is the crate body; its PivotOffset puts the model pivot at the
-- bottom centre, so Model:PivotTo(CFrame.new(groundPoint)) sits the crate on the ground.
-- Animation hooks (all via Motor6D.Transform):
--   Motors.Lid   hinge on the back top edge; Transform = CFrame.Angles(a, 0, 0) with a > 0 opens it
--                (about math.rad(110) is fully open).
--   Motors.LockL / Motors.LockR  front padlocks; e.g. Transform = CFrame.new(0, 1.5, -1) * CFrame.Angles(...)
--                pops them off.
-- `Glow` is a neon slab inside the crate (Transparency 1 by default; fade it in on open).
-- `Burst` is an Attachment on Base at the interior top, for particle bursts.

local Config = require(script.Parent.Parent.Config)
local U = require(script.Parent.RigUtil)

local CrateRig = {}

export type CrateRig = {
	Model: Model,
	Base: BasePart,
	Motors: { Lid: Motor6D, LockL: Motor6D, LockR: Motor6D },
	Glow: BasePart,
	Burst: Attachment,
}

local W, D = 5, 3.6
local BODY_H = 2.3
local LID_H = 0.75
local LID_TOP_H = 0.55
local BAND_X = 1.75

local WHITE = Color3.fromRGB(240, 242, 255)
local EYE = Color3.fromRGB(25, 15, 40)
local LOCK = Color3.fromRGB(255, 205, 60)
local METAL = Color3.fromRGB(150, 155, 170)

local NEON = { Material = Enum.Material.Neon }

function CrateRig.Build(crateId: string): CrateRig
	local def = Config.Crates[crateId]
	assert(def, "CrateRig: unknown crate " .. tostring(crateId))
	local color = def.Color
	local trim = def.Trim

	local model = Instance.new("Model")
	model.Name = crateId

	------------------------------------------------------------------ body
	local baseCf = CFrame.new(0, BODY_H / 2, 0)
	local base = U.Block(Vector3.new(W, BODY_H, D), baseCf, color, model, { Name = "Base", Shadow = true })
	base.Anchored = true
	base.Massless = false
	base.PivotOffset = CFrame.new(0, -BODY_H / 2, 0)
	model.PrimaryPart = base

	local function onBase(p: BasePart): BasePart
		U.Weld(base, p)
		return p
	end

	onBase(U.Block(Vector3.new(W + 0.25, 0.35, D + 0.25), CFrame.new(0, 0.175, 0), U.Shade(color, 0.6), model)) -- plinth
	for _, s in { -1, 1 } do
		onBase(U.Block(Vector3.new(0.5, 2.0, D + 0.12), CFrame.new(BAND_X * s, 1.35, 0), trim, model, NEON))
	end

	-- cute ghost emblem on the front
	local emblem = Vector3.new(0, 1.3, -D / 2)
	onBase(U.Ball(1.25, CFrame.new(emblem), WHITE, model))
	for _, s in { -1, 1 } do
		onBase(U.Ball(0.3, CFrame.new(emblem + Vector3.new(0.22 * s, 0.1, -0.52)), EYE, model))
	end
	onBase(U.Cyl(0.08, 0.22, CFrame.new(emblem + Vector3.new(0, -0.17, -0.62)) * U.AxisZ, EYE, model))

	-- interior glow (hidden until the reveal fades it in)
	local glow = onBase(U.Block(Vector3.new(W - 0.6, 0.3, D - 0.6), CFrame.new(0, BODY_H - 0.15, 0), trim, model, { Material = Enum.Material.Neon, Transparency = 1, Name = "Glow" }))

	local burst = U.AttachAt(base, "Burst", CFrame.new(0, BODY_H, 0))

	------------------------------------------------------------------ lid (hinged at the back top edge)
	local lidY = BODY_H + LID_H / 2
	local lid = U.Block(Vector3.new(W + 0.1, LID_H, D + 0.1), CFrame.new(0, lidY, 0), color, model, { Name = "Lid", Shadow = true })
	local hinge = Vector3.new(0, BODY_H, (D + 0.1) / 2)
	local lidMotor = U.Motor("Lid", base, lid, baseCf:ToObjectSpace(CFrame.new(hinge)), lid.CFrame:ToObjectSpace(CFrame.new(hinge)))

	local function onLid(p: BasePart): BasePart
		U.Weld(lid, p)
		return p
	end
	local topY = BODY_H + LID_H + LID_TOP_H / 2
	local topDepth = D - 1.2
	onLid(U.Block(Vector3.new(W + 0.1, LID_TOP_H, topDepth), CFrame.new(0, topY, 0), color, model))
	local bevel = Vector3.new(W + 0.1, LID_TOP_H, ((D + 0.1) - topDepth) / 2)
	onLid(U.Wedge(bevel, CFrame.new(0, topY, -(topDepth + bevel.Z) / 2), color, model)) -- front bevel
	onLid(U.Wedge(bevel, CFrame.new(0, topY, (topDepth + bevel.Z) / 2) * CFrame.Angles(0, math.pi, 0), color, model)) -- back bevel
	for _, s in { -1, 1 } do
		onLid(U.Block(Vector3.new(0.5, LID_H + 0.04, D + 0.16), CFrame.new(BAND_X * s, lidY, 0), trim, model, NEON))
		onLid(U.Block(Vector3.new(0.5, LID_TOP_H + 0.04, topDepth + 0.04), CFrame.new(BAND_X * s, topY, 0), trim, model, NEON))
	end
	onLid(U.Block(Vector3.new(W + 0.15, 0.18, 0.16), CFrame.new(0, BODY_H + 0.09, -(D + 0.1) / 2 - 0.04), trim, model, NEON)) -- front lip

	------------------------------------------------------------------ padlocks
	local lockMotors: { [number]: Motor6D } = {}
	for _, s in { -1, 1 } do
		local pos = Vector3.new(BAND_X * s, BODY_H - 0.15, -D / 2 - 0.2)
		local body = U.Block(Vector3.new(0.7, 0.75, 0.35), CFrame.new(pos), LOCK, model, { Name = if s < 0 then "LockL" else "LockR", Material = Enum.Material.Metal })
		lockMotors[s] = U.Motor(if s < 0 then "LockL" else "LockR", base, body, baseCf:ToObjectSpace(CFrame.new(pos)), CFrame.identity)
		local shackle = U.Cyl(0.1, 0.55, CFrame.new(pos + Vector3.new(0, 0.4, 0.02)) * U.AxisZ, METAL, model, { Material = Enum.Material.Metal })
		U.Weld(body, shackle)
		local hole = U.Block(Vector3.new(0.12, 0.22, 0.06), CFrame.new(pos + Vector3.new(0, -0.08, -0.18)), EYE, model)
		U.Weld(body, hole)
	end

	return {
		Model = model,
		Base = base,
		Motors = { Lid = lidMotor, LockL = lockMotors[-1], LockR = lockMotors[1] },
		Glow = glow,
		Burst = burst,
	}
end

return CrateRig
