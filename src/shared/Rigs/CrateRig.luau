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
-- Trim bands are solid (SmoothPlastic, vivid trim colour); the only visible Neon is the thin
-- lip under the lid, like magic light leaking from the seam.

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
	local band = U.Vivid(trim) -- solid trim bands
	local bandOpts: U.Opts = { Shadow = false }

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
		onBase(U.Block(Vector3.new(0.5, 2.0, D + 0.12), CFrame.new(BAND_X * s, 1.35, 0), band, model, bandOpts))
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
		onLid(U.Block(Vector3.new(0.5, LID_H + 0.04, D + 0.16), CFrame.new(BAND_X * s, lidY, 0), band, model, bandOpts))
		onLid(U.Block(Vector3.new(0.5, LID_TOP_H + 0.04, topDepth + 0.04), CFrame.new(BAND_X * s, topY, 0), band, model, bandOpts))
	end
	onLid(U.Block(Vector3.new(W + 0.15, 0.18, 0.16), CFrame.new(0, BODY_H + 0.09, -(D + 0.1) / 2 - 0.04), trim, model, NEON)) -- front lip (glowing seam)

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

	------------------------------------------------------------------ style decorations
	-- Same chest for every crate; later styles add more hardware. Body pieces are welded to
	-- Base, lid pieces to Lid (so they swing open with it).
	local style = def.Style
	local lidTop = BODY_H + LID_H + LID_TOP_H
	local frontZ = -D / 2
	local lidFrontZ = -(D + 0.1) / 2
	local metal: U.Opts = { Material = Enum.Material.Metal }
	local function bBlock(size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onBase(U.Block(size, cf, c, model, opts))
	end
	local function bBall(d: number, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onBase(U.Ball(d, cf, c, model, opts))
	end
	local function bCyl(len: number, d: number, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onBase(U.Cyl(len, d, cf, c, model, opts))
	end
	local function lBlock(size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onLid(U.Block(size, cf, c, model, opts))
	end
	local function lBall(d: number, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onLid(U.Ball(d, cf, c, model, opts))
	end
	local function lCyl(len: number, d: number, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onLid(U.Cyl(len, d, cf, c, model, opts))
	end
	local function lWedge(size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onLid(U.Wedge(size, cf, c, model, opts))
	end

	if style == "Haunted" then
		-- stitched trim bands
		for _, s in { -1, 1 } do
			for _, y in { 0.7, 1.15, 1.6 } do
				bBlock(Vector3.new(0.6, 0.08, 0.06), CFrame.new(BAND_X * s, y, frontZ - 0.1) * CFrame.Angles(0, 0, 0.5), EYE)
			end
		end
		-- two little ghost wisps sitting on the lid
		for _, s in { -1, 1 } do
			local p = Vector3.new(2.1 * s, lidTop + 0.38, 0.4)
			lBall(0.8, CFrame.new(p), WHITE, { Transparency = 0.15 })
			lBall(0.45, CFrame.new(p + Vector3.new(0.25 * s, -0.25, 0.4)), WHITE, { Transparency = 0.15 })
			for _, e in { -1, 1 } do
				lBall(0.14, CFrame.new(p + Vector3.new(0.13 * e, 0.06, -0.36)), EYE)
			end
		end
	elseif style == "Elite" then
		-- metal corner caps on body and lid, rivets on the bands and a front strap
		local capC = Color3.fromRGB(190, 195, 215)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bBlock(Vector3.new(0.6, 0.6, 0.6), CFrame.new(sx * W / 2, 0.55, sz * D / 2), capC, metal)
				bBlock(Vector3.new(0.6, 0.6, 0.6), CFrame.new(sx * W / 2, BODY_H - 0.3, sz * D / 2), capC, metal)
				lBlock(Vector3.new(0.6, 0.6, 0.6), CFrame.new(sx * (W / 2 + 0.03), BODY_H + 0.38, sz * (D / 2 + 0.03)), capC, metal)
			end
		end
		for _, s in { -1, 1 } do
			for _, y in { 0.6, 1.0, 1.4 } do
				bBall(0.18, CFrame.new(BAND_X * s, y, frontZ - 0.08), capC, metal)
			end
			lBall(0.18, CFrame.new(BAND_X * s, BODY_H + 0.38, lidFrontZ - 0.06), capC, metal)
		end
		bBlock(Vector3.new(W - 1.0, 0.2, 0.1), CFrame.new(0, 0.5, frontZ - 0.03), capC, metal)
	elseif style == "Carnival" then
		-- cream circus stripes on body and lid
		local cream = Color3.fromRGB(255, 240, 215)
		for _, x in { -2.2, -0.75, 0.75, 2.2 } do
			bBlock(Vector3.new(0.5, BODY_H - 0.4, D + 0.04), CFrame.new(x, 0.35 + (BODY_H - 0.4) / 2, 0), cream)
			lBlock(Vector3.new(0.5, LID_H + 0.02, D + 0.14), CFrame.new(x, BODY_H + LID_H / 2, 0), cream)
		end
		for _, z in { -0.75, 0.75 } do
			bBlock(Vector3.new(W + 0.04, BODY_H - 0.4, 0.5), CFrame.new(0, 0.35 + (BODY_H - 0.4) / 2, z), cream)
		end
		-- gold star standing on the lid
		local sp = CFrame.new(0, lidTop + 0.5, -0.1)
		lBlock(Vector3.new(0.85, 0.85, 0.16), sp, LOCK, metal)
		lBlock(Vector3.new(0.85, 0.85, 0.16), sp * CFrame.Angles(0, 0, math.pi / 4), LOCK, metal)
		lBall(0.4, sp * CFrame.new(0, 0, -0.1), Color3.fromRGB(235, 55, 70))
		-- marquee bulbs along the lid front
		for i = -2, 2 do
			lBall(0.22, CFrame.new(i * 0.6, BODY_H + 0.42, lidFrontZ - 0.05), cream)
		end
	elseif style == "Medical" then
		local red = Color3.fromRGB(230, 50, 60)
		bBlock(Vector3.new(W + 0.04, 0.3, D + 0.04), CFrame.new(0, 0.7, 0), band, bandOpts) -- blue stripe
		for _, s in { -1, 1 } do
			-- red crosses on the sides
			bBlock(Vector3.new(0.06, 0.9, 0.3), CFrame.new(s * (W / 2 + 0.03), 1.45, 0), red)
			bBlock(Vector3.new(0.06, 0.3, 0.9), CFrame.new(s * (W / 2 + 0.03), 1.45, 0), red)
			-- front latches (lower half on the body, upper half on the lid)
			bBlock(Vector3.new(0.32, 0.42, 0.12), CFrame.new(0.85 * s, 2.0, frontZ - 0.06), METAL, metal)
			lBlock(Vector3.new(0.4, 0.16, 0.14), CFrame.new(0.85 * s, BODY_H + 0.26, lidFrontZ - 0.07), METAL, metal)
		end
		-- cross plaque standing on the lid
		local pp = CFrame.new(0, lidTop + 0.55, -0.1)
		lCyl(0.16, 1.25, pp * U.AxisZ, WHITE)
		lBlock(Vector3.new(0.75, 0.25, 0.08), pp * CFrame.new(0, 0, -0.1), red)
		lBlock(Vector3.new(0.25, 0.75, 0.08), pp * CFrame.new(0, 0, -0.1), red)
	elseif style == "Sailor" then
		-- rope trim round the top of the body
		local rope = Color3.fromRGB(225, 195, 140)
		local ropeOpts: U.Opts = { Material = Enum.Material.Fabric }
		for _, s in { -1, 1 } do
			bCyl(W + 0.1, 0.2, CFrame.new(0, BODY_H - 0.12, s * (D / 2 + 0.06)), rope, ropeOpts)
			bCyl(D + 0.1, 0.2, CFrame.new(s * (W / 2 + 0.06), BODY_H - 0.12, 0) * U.AxisZ, rope, ropeOpts)
		end
		-- plank seams
		local seam = U.Shade(color, 0.6)
		for _, y in { 0.9, 1.45 } do
			bBlock(Vector3.new(W + 0.02, 0.06, D + 0.02), CFrame.new(0, y, 0), seam)
		end
		lBlock(Vector3.new(W + 0.12, 0.05, D + 0.12), CFrame.new(0, BODY_H + 0.38, 0), seam)
		-- gold anchor standing on the lid
		local ac = CFrame.new(0, lidTop + 0.65, -0.1)
		lBlock(Vector3.new(0.16, 1.1, 0.14), ac, LOCK, metal)
		lCyl(0.12, 0.38, ac * CFrame.new(0, 0.66, 0) * U.AxisZ, LOCK, metal)
		lBlock(Vector3.new(0.7, 0.13, 0.13), ac * CFrame.new(0, 0.3, 0), LOCK, metal)
		lBlock(Vector3.new(0.95, 0.14, 0.14), ac * CFrame.new(0, -0.5, 0), LOCK, metal)
		for _, s in { -1, 1 } do
			lBlock(Vector3.new(0.14, 0.38, 0.14), ac * CFrame.new(0.48 * s, -0.38, 0) * CFrame.Angles(0, 0, -0.45 * s), LOCK, metal)
		end
	elseif style == "Royal" then
		-- gold crown on a velvet cushion on the lid
		local ccf = CFrame.new(0, lidTop + 0.25, -0.05)
		lCyl(0.5, 1.5, ccf * U.AxisY, LOCK, metal)
		lBall(1.25, ccf * CFrame.new(0, 0.2, 0), Color3.fromRGB(200, 40, 70))
		for i = 0, 4 do
			local a = CFrame.Angles(0, i * 2 * math.pi / 5, 0)
			lWedge(Vector3.new(0.34, 0.5, 0.28), ccf * a * CFrame.new(0, 0.48, -0.62), LOCK, metal)
			lBall(0.18, ccf * a * CFrame.new(0, 0.76, -0.5), WHITE)
		end
		-- jewel on the lid front
		local gp = CFrame.new(0, BODY_H + 0.42, lidFrontZ - 0.05)
		lCyl(0.12, 0.6, gp * U.AxisZ, LOCK, metal)
		lBlock(Vector3.new(0.36, 0.36, 0.12), gp * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(255, 70, 140), NEON)
		-- gold trim over the plinth
		bBlock(Vector3.new(W + 0.3, 0.1, D + 0.3), CFrame.new(0, 0.38, 0), LOCK, metal)
	elseif style == "Spirit" then
		-- containment cage: metal corner posts and bars
		local frame = Color3.fromRGB(70, 75, 95)
		local hx, hz = W / 2 + 0.05, D / 2 + 0.05
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bCyl(BODY_H + 0.1, 0.32, CFrame.new(sx * hx, BODY_H / 2 + 0.05, sz * hz) * U.AxisY, frame, metal)
				bCyl(0.12, 0.42, CFrame.new(sx * hx, 1.2, sz * hz) * U.AxisY, trim, NEON) -- rune ring
			end
		end
		for _, y in { 0.45, BODY_H - 0.15 } do
			for _, s in { -1, 1 } do
				bCyl(W + 0.1, 0.22, CFrame.new(0, y, s * hz), frame, metal)
				bCyl(D + 0.1, 0.22, CFrame.new(s * hx, y, 0) * U.AxisZ, frame, metal)
			end
		end
		-- glowing crystal spikes on the lid
		for i = -1, 1 do
			local h = if i == 0 then 0.8 else 0.55
			local cf = CFrame.new(i * 0.9, lidTop + h / 2 - 0.05, -0.1) * CFrame.Angles(0, 0, -0.3 * i)
			lBlock(Vector3.new(0.32, h, 0.32), cf * CFrame.Angles(0, math.pi / 4, 0), band, { Reflectance = 0.25 })
			lBlock(Vector3.new(0.32, 0.32, 0.32), cf * CFrame.new(0, h / 2, 0) * U.VertexUp, trim, NEON)
		end
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
