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

-- Every Style that Build decorates ("Basic" is the plain chest). Keep in sync with the branches in
-- Build; the check below warns on load if a Config crate uses a Style that isn't listed here.
local STYLES: { [string]: boolean } = {
	Basic = true, Haunted = true, Elite = true, Carnival = true, Medical = true, Sailor = true,
	Royal = true, Spirit = true, Swamp = true, Frost = true, Tomb = true, Toy = true, Sunken = true,
	Clock = true, Inferno = true, Throne = true,
	-- World 2
	Lantern = true, Library = true, Topsy = true, Shroom = true, Mirror = true, Subway = true,
	Neon = true, Storm = true, Moon = true, Void = true,
	-- PLACEHOLDER (world2b): listed but not decorated yet (plain chest) until the real styles land
	Harvest = true, Splash = true, Shopping = true, Fossil = true, Trophy = true, CookieJar = true, Arcade = true,
}
CrateRig.Styles = STYLES

-- Config crates whose Style has no decorations (empty when everything is handled).
function CrateRig.MissingStyles(): { string }
	local out = {}
	for id, def in Config.Crates do
		if not STYLES[def.Style] then
			table.insert(out, id .. " (" .. tostring(def.Style) .. ")")
		end
	end
	table.sort(out)
	return out
end

do
	local missing = CrateRig.MissingStyles()
	if #missing > 0 then
		warn("CrateRig: no decorations for crate styles: " .. table.concat(missing, ", "))
	end
end

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
	-- (the Topsy crate is "built upside-down", so its ghost's face is flipped too)
	local flip = if def.Style == "Topsy" then -1 else 1
	local emblem = Vector3.new(0, 1.3, -D / 2)
	onBase(U.Ball(1.25, CFrame.new(emblem), WHITE, model))
	for _, s in { -1, 1 } do
		onBase(U.Ball(0.3, CFrame.new(emblem + Vector3.new(0.22 * s, 0.1 * flip, -0.52)), EYE, model))
	end
	onBase(U.Cyl(0.08, 0.22, CFrame.new(emblem + Vector3.new(0, -0.17 * flip, -0.62)) * U.AxisZ, EYE, model))

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
	local function bWedge(size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?): BasePart
		return onBase(U.Wedge(size, cf, c, model, opts))
	end
	local function bGear(d: number, thick: number, teeth: number, cf: CFrame, c: Color3, opts: U.Opts?)
		for _, p in U.Gear(d, thick, teeth, cf, c, model, opts) do
			onBase(p)
		end
	end
	local function lGear(d: number, thick: number, teeth: number, cf: CFrame, c: Color3, opts: U.Opts?)
		for _, p in U.Gear(d, thick, teeth, cf, c, model, opts) do
			onLid(p)
		end
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
	elseif style == "Swamp" then
		local moss = Color3.fromRGB(85, 140, 60)
		local leaf = Color3.fromRGB(80, 170, 75)
		local mud = Color3.fromRGB(95, 70, 45)
		-- moss lumps along the lid edge and strands hanging over the lid front
		for i, x in { -2.1, -1.0, 0.1, 1.1, 2.15 } do
			lBall(0.45 + (i % 2) * 0.12, CFrame.new(x, BODY_H + LID_H, lidFrontZ + 0.15), moss)
		end
		for _, x in { -0.9, 0.35, 1.0 } do
			lBlock(Vector3.new(0.18, 0.5, 0.06), CFrame.new(x, BODY_H + LID_H - 0.25, lidFrontZ - 0.04), moss)
		end
		-- frog sitting on a lily pad on the lid
		local fp = Vector3.new(1.1, lidTop, -0.1)
		lCyl(0.1, 1.5, CFrame.new(fp + Vector3.new(0, 0.05, 0)) * U.AxisY, leaf)
		lBall(0.75, CFrame.new(fp + Vector3.new(0, 0.42, 0)), leaf)
		for _, s in { -1, 1 } do
			lBall(0.3, CFrame.new(fp + Vector3.new(0.18 * s, 0.75, -0.2)), WHITE)
			lBall(0.13, CFrame.new(fp + Vector3.new(0.18 * s, 0.78, -0.34)), EYE)
		end
		-- cattails beside the chest (outside the lid's swing) with a firefly
		for _, c in { Vector3.new(-2.8, 0.3, 1.2), Vector3.new(-2.9, 0.3, 1.65) } do
			local tip = c + Vector3.new(-0.12, 2.7 + (c.Z - 1.2), 0)
			bCyl((tip - c).Magnitude, 0.1, U.Between(c, tip), leaf)
			bCyl(0.6, 0.28, CFrame.new(tip - Vector3.new(0, 0.35, 0)) * U.AxisY, mud)
		end
		bBall(0.22, CFrame.new(-3.15, 2.9, 1.0), trim, NEON)
		-- mud splashes round the plinth
		for _, x in { -2.3, 0.9, 2.2 } do
			bBall(0.7, CFrame.new(x, 0.3, frontZ - 0.05), mud)
		end
	elseif style == "Frost" then
		local snow = Color3.fromRGB(250, 252, 255)
		local ice = Color3.fromRGB(190, 230, 255)
		local glass: U.Opts = { Reflectance = 0.25 }
		-- snow cap and lumps on the lid
		lBlock(Vector3.new(W + 0.2, 0.2, topDepth + 0.1), CFrame.new(0, lidTop + 0.05, 0), snow)
		for _, p in { Vector3.new(-1.6, 0.2, 0.3), Vector3.new(1.7, 0.18, -0.2), Vector3.new(0.6, 0.2, 0.6) } do
			lBall(0.7, CFrame.new(p + Vector3.new(0, lidTop, 0)), snow)
		end
		-- icicles hanging from the lid edge (they swing open with it)
		for _, x in { -2.3, -0.95, 0, 0.95, 2.3 } do
			local l = if x == 0 then 0.25 else 0.4
			lBlock(Vector3.new(0.2, l, 0.2), CFrame.new(x, BODY_H - l / 2, lidFrontZ - 0.08) * CFrame.Angles(0, math.pi / 4, 0), ice, glass)
			lBlock(Vector3.new(0.17, 0.17, 0.17), CFrame.new(x, BODY_H - l - 0.03, lidFrontZ - 0.08) * U.VertexUp, ice, glass)
		end
		-- ice crystal cluster on the lid (the middle tip glows)
		for i = -1, 1 do
			local h = if i == 0 then 1.0 else 0.65
			local cf = CFrame.new(i * 0.55 - 0.6, lidTop + h / 2, -0.2) * CFrame.Angles(0, 0, -0.3 * i)
			lBlock(Vector3.new(0.34, h, 0.34), cf * CFrame.Angles(0, math.pi / 4, 0), ice, glass)
			lBlock(Vector3.new(0.34, 0.34, 0.34), cf * CFrame.new(0, h / 2, 0) * U.VertexUp, if i == 0 then trim else snow, if i == 0 then NEON else nil)
		end
		-- snow drifts at the corners and snowflakes on the sides
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bBall(0.95, CFrame.new(sx * W / 2, 0.25, sz * D / 2), snow)
			end
			for k = 0, 2 do
				bBlock(Vector3.new(0.06, 1.1, 0.14), CFrame.new(sx * (W / 2 + 0.04), 1.2, 0) * CFrame.Angles(k * math.pi / 3, 0, 0), WHITE)
			end
		end
	elseif style == "Tomb" then
		local sandstone = U.Shade(color, 0.85)
		local blue = Color3.fromRGB(40, 80, 170)
		local sand = Color3.fromRGB(230, 200, 140)
		-- corner pillars with gold capitals, gold trim over the plinth
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bBlock(Vector3.new(0.5, BODY_H - 0.3, 0.5), CFrame.new(sx * W / 2, 0.3 + (BODY_H - 0.3) / 2, sz * D / 2), sandstone)
				bBlock(Vector3.new(0.62, 0.18, 0.62), CFrame.new(sx * W / 2, BODY_H - 0.1, sz * D / 2), LOCK, metal)
			end
			-- eye of Horus on each side
			bBlock(Vector3.new(0.06, 0.32, 0.8), CFrame.new(sx * (W / 2 + 0.03), 1.35, 0), WHITE)
			bCyl(0.08, 0.3, CFrame.new(sx * (W / 2 + 0.04), 1.35, 0), blue)
			bBlock(Vector3.new(0.06, 0.4, 0.08), CFrame.new(sx * (W / 2 + 0.04), 1.0, 0.1) * CFrame.Angles(0.3, 0, 0), blue)
		end
		bBlock(Vector3.new(W + 0.3, 0.1, D + 0.3), CFrame.new(0, 0.38, 0), LOCK, metal)
		-- row of hieroglyphs under the emblem
		for i, x in { -1.1, -0.55, 0, 0.55, 1.1 } do
			if i % 2 == 1 then
				bBlock(Vector3.new(0.12, 0.32, 0.06), CFrame.new(x, 0.55, frontZ - 0.03), trim)
			else
				bBall(0.24, CFrame.new(x, 0.55, frontZ - 0.02), trim)
			end
		end
		-- blue stripes on the lid front
		for _, y in { 2.62, 2.85 } do
			lBlock(Vector3.new(W + 0.14, 0.1, 0.06), CFrame.new(0, y, lidFrontZ - 0.02), blue)
		end
		-- scarab in front of a gold sun disc on the lid
		local sp = Vector3.new(0, lidTop + 0.18, -0.1)
		for _, s in { -1, 1 } do
			lBall(0.75, CFrame.new(sp + Vector3.new(0.2 * s, 0.05, 0.1)), trim, { Reflectance = 0.25 })
			lBlock(Vector3.new(0.5, 0.08, 0.1), CFrame.new(sp + Vector3.new(0.5 * s, -0.05, -0.05)) * CFrame.Angles(0, 0.4 * s, 0), EYE)
			lBlock(Vector3.new(0.5, 0.08, 0.1), CFrame.new(sp + Vector3.new(0.5 * s, -0.05, 0.3)) * CFrame.Angles(0, -0.4 * s, 0), EYE)
		end
		lBall(0.38, CFrame.new(sp + Vector3.new(0, 0, -0.42)), U.Shade(trim, 0.7))
		lCyl(0.12, 1.3, CFrame.new(0, lidTop + 0.75, 0.55) * U.AxisZ, LOCK, metal)
		lCyl(0.14, 0.4, CFrame.new(0, lidTop + 0.75, 0.48) * U.AxisZ, trim, NEON)
		-- sand piled at the front corners
		for _, s in { -1, 1 } do
			bBall(0.9, CFrame.new(2.2 * s, 0.15, frontZ - 0.35), sand)
		end
	elseif style == "Toy" then
		local blue = Color3.fromRGB(80, 140, 255)
		local green = Color3.fromRGB(90, 210, 120)
		-- ribbon and a big bow on the lid
		lBlock(Vector3.new(0.5, 0.08, topDepth + 0.04), CFrame.new(0, lidTop + 0.02, 0), trim)
		lBlock(Vector3.new(0.5, LID_H + 0.02, 0.06), CFrame.new(0, BODY_H + LID_H / 2, lidFrontZ - 0.03), trim)
		local bp = Vector3.new(0, lidTop + 0.45, 0)
		lBall(0.45, CFrame.new(bp), U.Shade(trim, 0.9))
		for _, s in { -1, 1 } do
			lCyl(0.22, 0.9, CFrame.new(bp + Vector3.new(0.5 * s, 0.05, 0)) * U.AxisZ, trim)
			lWedge(Vector3.new(0.1, 0.5, 0.35), CFrame.new(bp + Vector3.new(0.25 * s, -0.25, -0.25)) * CFrame.Angles(0, 0, 0.6 * s), trim)
			-- stars on the lid front
			local st = CFrame.new(0.95 * s, BODY_H + 0.45, lidFrontZ - 0.03)
			lBlock(Vector3.new(0.36, 0.36, 0.06), st, WHITE)
			lBlock(Vector3.new(0.36, 0.36, 0.06), st * CFrame.Angles(0, 0, math.pi / 4), WHITE)
		end
		-- building-brick studs on the lid
		local studCols = { blue, green, WHITE }
		for i, p in { Vector2.new(-1.3, -0.6), Vector2.new(-1.3, 0.6), Vector2.new(1.3, -0.6), Vector2.new(1.3, 0.6), Vector2.new(-2.0, 0), Vector2.new(2.0, 0) } do
			lCyl(0.12, 0.35, CFrame.new(p.X, lidTop + 0.06, p.Y) * U.AxisY, studCols[i % 3 + 1])
		end
		-- polka dots on the sides
		for _, s in { -1, 1 } do
			for i, p in { Vector2.new(0.9, -0.8), Vector2.new(1.6, 0.6), Vector2.new(0.75, 0.95) } do
				bCyl(0.06, 0.45, CFrame.new(s * (W / 2 + 0.02), p.X, p.Y), studCols[i])
			end
		end
		-- wind-up key on the right side
		bCyl(0.6, 0.18, CFrame.new(W / 2 + 0.3, 1.2, 0), METAL, metal)
		for _, s in { -1, 1 } do
			bCyl(0.14, 0.75, CFrame.new(W / 2 + 0.7, 1.2 + 0.36 * s, 0) * U.AxisZ, LOCK, metal)
		end
		bBlock(Vector3.new(0.35, 0.3, 0.14), CFrame.new(W / 2 + 0.7, 1.2, 0), LOCK, metal)
		-- toy blocks by the front corners
		for i, s in { -1, 1 } do
			local bc = CFrame.new(2.85 * s, 0.35, frontZ - 0.1) * CFrame.Angles(0, 0.3 * s, 0)
			bBlock(Vector3.new(0.7, 0.7, 0.7), bc, if i == 1 then blue else green)
			bBlock(Vector3.new(0.45, 0.45, 0.04), bc * CFrame.new(0, 0, -0.36), WHITE)
		end
	elseif style == "Sunken" then
		local coral = Color3.fromRGB(255, 120, 140)
		local weed = Color3.fromRGB(60, 150, 90)
		local barn = Color3.fromRGB(200, 200, 190)
		local shellC = Color3.fromRGB(255, 220, 200)
		local brass = Color3.fromRGB(205, 160, 75)
		local seam = U.Shade(color, 0.6)
		for _, y in { 0.9, 1.6 } do
			bBlock(Vector3.new(W + 0.02, 0.06, D + 0.02), CFrame.new(0, y, 0), seam)
		end
		-- barnacles
		for _, p in { Vector3.new(-2.52, 0.8, -0.9), Vector3.new(-2.52, 1.1, -0.55), Vector3.new(2.52, 1.75, 0.95), Vector3.new(2.52, 1.95, 1.25), Vector3.new(-1.1, 1.85, frontZ), Vector3.new(1.05, 0.55, frontZ) } do
			bBall(0.3, CFrame.new(p), barn)
		end
		-- branching coral on two corners (outside the lid's swing)
		for _, c in { Vector3.new(-2.75, 0.3, -1.6), Vector3.new(2.8, 0.3, 1.4) } do
			local t = c + Vector3.new(0, 1.0, 0)
			bCyl(1.0, 0.22, CFrame.new(c + Vector3.new(0, 0.5, 0)) * U.AxisY, coral)
			for _, s in { -1, 1 } do
				local a = t - Vector3.new(0, 0.3, 0)
				local b = t + Vector3.new(0.3 * s, 0.4, 0.1 * s)
				bCyl((b - a).Magnitude, 0.16, U.Between(a, b), coral)
				bBall(0.24, CFrame.new(b), coral)
			end
		end
		-- seaweed on the sides
		for _, s in { -1, 1 } do
			for i, z in { -0.95, 1.05 } do
				bBlock(Vector3.new(0.08, 1.4, 0.25), CFrame.new(s * (W / 2 + 0.05), 1.0, z) * CFrame.Angles(0.15 * (i * 2 - 3), 0, 0), weed)
			end
		end
		-- brass porthole on the right side
		for _, p in U.Hoop(0.42, 0.14, 0.12, 8, CFrame.new(W / 2 + 0.06, 1.25, 0) * CFrame.Angles(0, math.pi / 2, 0), brass, model, metal) do
			onBase(p)
		end
		bCyl(0.06, 0.75, CFrame.new(W / 2 + 0.03, 1.25, 0), Color3.fromRGB(60, 140, 170), { Reflectance = 0.3 })
		-- open clam with a pearl on the lid
		local cp = Vector3.new(-0.9, lidTop, -0.1)
		lCyl(0.18, 1.1, CFrame.new(cp + Vector3.new(0, 0.09, 0)) * U.AxisY, shellC)
		lCyl(0.16, 1.1, CFrame.new(cp + Vector3.new(0, 0.18, 0.55)) * CFrame.Angles(0.8, 0, 0) * CFrame.new(0, 0, -0.55) * U.AxisY, shellC)
		lBall(0.4, CFrame.new(cp + Vector3.new(0, 0.38, 0)), WHITE, { Reflectance = 0.3 })
		-- starfish on the lid front
		local sf = CFrame.new(0.95, BODY_H + 0.47, lidFrontZ - 0.03)
		for k = 0, 4 do
			lBlock(Vector3.new(0.12, 0.28, 0.06), sf * CFrame.Angles(0, 0, k * 2 * math.pi / 5) * CFrame.new(0, 0.13, 0), coral)
		end
		lBall(0.18, sf, coral)
	elseif style == "Clock" then
		local brass = Color3.fromRGB(205, 160, 75)
		-- clock face on a stand on the lid, a big gear behind it
		local cc = CFrame.new(0, lidTop + 0.9, 0.05)
		lBlock(Vector3.new(0.5, 0.3, 0.4), CFrame.new(0, lidTop + 0.12, 0.1), brass, metal)
		lGear(1.9, 0.14, 10, cc * CFrame.new(0, 0, 0.2), U.Shade(brass, 0.8), metal)
		lCyl(0.16, 1.55, cc * U.AxisZ, brass, metal)
		lCyl(0.1, 1.35, cc * CFrame.new(0, 0, -0.06) * U.AxisZ, Color3.fromRGB(255, 244, 220))
		for k = 0, 3 do
			lBlock(Vector3.new(0.08, 0.2, 0.04), cc * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 0.52, -0.12), EYE)
		end
		lBlock(Vector3.new(0.08, 0.38, 0.04), cc * CFrame.Angles(0, 0, -2.1) * CFrame.new(0, 0.17, -0.14), EYE)
		lBlock(Vector3.new(0.06, 0.55, 0.04), cc * CFrame.Angles(0, 0, 0.5) * CFrame.new(0, 0.25, -0.15), EYE)
		lBall(0.16, cc * CFrame.new(0, 0, -0.14), trim, NEON)
		-- gears on the sides, brass pipes on the back corners
		for _, s in { -1, 1 } do
			bGear(1.3, 0.12, 6, CFrame.new(s * (W / 2 + 0.06), 1.2, 0) * CFrame.Angles(0, math.pi / 2, 0), brass, metal)
			bCyl(0.2, 0.4, CFrame.new(s * (W / 2 + 0.12), 1.2, 0), U.Shade(brass, 0.7), metal)
			bCyl(BODY_H, 0.25, CFrame.new(s * (W / 2 - 0.1), BODY_H / 2, D / 2 + 0.12) * U.AxisY, brass, metal)
		end
	elseif style == "Inferno" then
		local rock = Color3.fromRGB(45, 30, 30)
		local horn = Color3.fromRGB(60, 45, 45)
		local bone = Color3.fromRGB(235, 225, 200)
		local dark: U.Opts = { Material = Enum.Material.Metal }
		-- glowing lava cracks on the front and sides
		for _, c in { Vector3.new(-1.0, 0.75, 0.4), Vector3.new(1.0, 1.9, -0.5) } do
			local f = CFrame.new(c.X, c.Y, frontZ - 0.02) * CFrame.Angles(0, 0, c.Z)
			bBlock(Vector3.new(0.1, 0.7, 0.06), f, trim, NEON)
			bBlock(Vector3.new(0.08, 0.35, 0.06), f * CFrame.new(0.1, 0.3, 0) * CFrame.Angles(0, 0, -0.8), trim, NEON)
		end
		for _, s in { -1, 1 } do
			local f = CFrame.new(s * (W / 2 + 0.02), 1.1, 0.4 * s) * CFrame.Angles(0.5 * s, 0, 0)
			bBlock(Vector3.new(0.06, 0.8, 0.1), f, trim, NEON)
		end
		-- curved horns on the lid's front corners
		for _, s in { -1, 1 } do
			local h0 = Vector3.new(2.2 * s, 3.05, -1.2)
			local h1 = Vector3.new(2.75 * s, 3.6, -1.3)
			local h2 = Vector3.new(2.9 * s, 4.25, -1.1)
			lCyl((h1 - h0).Magnitude, 0.42, U.Between(h0, h1), horn)
			lCyl((h2 - h1).Magnitude, 0.3, U.Between(h1, h2), horn)
			lBlock(Vector3.new(0.22, 0.22, 0.22), CFrame.new(h2 + Vector3.new(0, 0.1, 0.03)) * U.VertexUp, horn)
			-- spikes on the band fronts
			bBlock(Vector3.new(0.22, 0.22, 0.22), CFrame.new(BAND_X * s, 0.75, frontZ - 0.12) * U.VertexUp, METAL, dark)
			bBlock(Vector3.new(0.22, 0.22, 0.22), CFrame.new(BAND_X * s, 1.45, frontZ - 0.12) * U.VertexUp, METAL, dark)
			lBlock(Vector3.new(0.22, 0.22, 0.22), CFrame.new(BAND_X * s, BODY_H + 0.42, lidFrontZ - 0.12) * U.VertexUp, METAL, dark)
		end
		-- flaming skull on the lid
		local sk = Vector3.new(0, lidTop + 0.45, -0.2)
		lBall(0.9, CFrame.new(sk), bone)
		for _, s in { -1, 1 } do
			lBall(0.26, CFrame.new(sk + Vector3.new(0.18 * s, 0.05, -0.4)), EYE)
		end
		lBlock(Vector3.new(0.5, 0.22, 0.4), CFrame.new(sk + Vector3.new(0, -0.35, -0.15)), bone)
		for i = -1, 1 do
			lWedge(Vector3.new(0.3, 0.75 - math.abs(i) * 0.2, 0.5), CFrame.new(sk + Vector3.new(i * 0.25, 0.55, 0.2)) * CFrame.Angles(-0.3, 0, -0.3 * i), trim, NEON)
		end
		-- obsidian spikes along the back of the lid
		for _, x in { -2.0, -1.0, 1.0, 2.0 } do
			lBlock(Vector3.new(0.35, 0.35, 0.35), CFrame.new(x, lidTop + 0.12, 0.9) * U.VertexUp, rock)
		end
		-- rocks round the base and dark metal corner caps
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bBlock(Vector3.new(0.8, 0.6, 0.7), CFrame.new(sx * 2.6, 0.3, sz * 1.75) * CFrame.Angles(0.3, 0.5 * sx * sz, 0.2), rock)
				bBlock(Vector3.new(0.55, 0.55, 0.55), CFrame.new(sx * W / 2, BODY_H - 0.28, sz * D / 2), U.Shade(METAL, 0.5), dark)
			end
		end
	elseif style == "Throne" then
		local velvet = Color3.fromRGB(130, 30, 80)
		local gems = { Color3.fromRGB(255, 70, 140), Color3.fromRGB(70, 150, 255), Color3.fromRGB(80, 220, 140) }
		local gemOpts: U.Opts = { Reflectance = 0.3 }
		-- gold corner caps on body and lid, gold trim over the plinth
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bBlock(Vector3.new(0.6, 0.6, 0.6), CFrame.new(sx * W / 2, 0.55, sz * D / 2), LOCK, metal)
				lBlock(Vector3.new(0.6, 0.6, 0.6), CFrame.new(sx * (W / 2 + 0.03), BODY_H + 0.38, sz * (D / 2 + 0.03)), LOCK, metal)
			end
		end
		bBlock(Vector3.new(W + 0.3, 0.1, D + 0.3), CFrame.new(0, 0.38, 0), LOCK, metal)
		-- velvet cushion with gold tassels, a tall crown with pearls and a glowing gem
		local cp = Vector3.new(0, lidTop + 0.17, -0.05)
		lBlock(Vector3.new(1.9, 0.35, 1.9), CFrame.new(cp), velvet)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				lBall(0.22, CFrame.new(cp + Vector3.new(sx * 0.95, -0.05, sz * 0.95)), LOCK, metal)
			end
		end
		local ccf = CFrame.new(cp + Vector3.new(0, 0.45, 0))
		lCyl(0.55, 1.4, ccf * U.AxisY, LOCK, metal)
		lBall(1.2, ccf * CFrame.new(0, 0.2, 0), velvet)
		for i = 0, 4 do
			local a = CFrame.Angles(0, i * 2 * math.pi / 5, 0)
			lWedge(Vector3.new(0.34, 0.6, 0.28), ccf * a * CFrame.new(0, 0.55, -0.58), LOCK, metal)
			lBall(0.18, ccf * a * CFrame.new(0, 0.88, -0.48), WHITE)
		end
		lBlock(Vector3.new(0.3, 0.3, 0.1), ccf * CFrame.new(0, 0, -0.72) * CFrame.Angles(0, 0, math.pi / 4), gems[1], NEON)
		-- two sceptres crossed behind the crown
		for _, s in { -1, 1 } do
			local scf = CFrame.new(0, lidTop + 0.6, 0.85) * CFrame.Angles(0, 0, 0.6 * s)
			lCyl(2.2, 0.1, scf, LOCK, metal)
			lBall(0.26, scf * CFrame.new(1.1, 0, 0), gems[2], gemOpts)
		end
		-- gold wings on the sides
		for _, s in { -1, 1 } do
			for k = 0, 1 do
				bWedge(Vector3.new(0.12, 1.1 - k * 0.3, 1.4 - k * 0.3), CFrame.new(s * (W / 2 + 0.08), 1.45 - k * 0.4, 0.2) * CFrame.Angles(0.2 * k, 0, 0), LOCK, metal)
			end
			-- gem studs on the band fronts
			for i, y in { 0.6, 1.0, 1.4 } do
				bBall(0.24, CFrame.new(BAND_X * s, y, frontZ - 0.08), gems[i], gemOpts)
			end
		end
		-- royal crest on the lid front
		local cr = CFrame.new(0, BODY_H + 0.75, lidFrontZ - 0.04)
		lBlock(Vector3.new(0.6, 0.55, 0.08), cr, LOCK, metal)
		lBlock(Vector3.new(0.44, 0.4, 0.06), cr * CFrame.new(0, 0, -0.05), velvet)
		lBall(0.16, cr * CFrame.new(0, 0, -0.09), LOCK, metal)
	elseif style == "Lantern" then
		local paper = Color3.fromRGB(235, 55, 50)
		local rib = U.Shade(paper, 0.55)
		local wood = Color3.fromRGB(95, 55, 35)
		-- paper lantern hanging from a wooden stand on the lid (a warm light inside the paper)
		local lp = Vector3.new(0.15, lidTop + 0.95, 0.15)
		local postX = -1.2
		lBlock(Vector3.new(0.6, 0.12, 0.6), CFrame.new(postX, lidTop + 0.06, lp.Z), wood)
		lCyl(1.75, 0.16, CFrame.new(postX, lidTop + 0.9, lp.Z) * U.AxisY, wood)
		lCyl(1.55, 0.13, CFrame.new((postX + lp.X + 0.2) / 2, lidTop + 1.75, lp.Z), wood)
		lCyl(0.2, 0.06, CFrame.new(lp + Vector3.new(0, 0.7, 0)) * U.AxisY, LOCK)
		lBall(1.2, CFrame.new(lp), paper, { Transparency = 0.2 })
		lBall(0.5, CFrame.new(lp), trim, NEON)
		for _, o in { -0.3, 0, 0.3 } do
			local r = math.sqrt(0.6 * 0.6 - o * o)
			lCyl(0.05, 2 * r + 0.04, CFrame.new(lp + Vector3.new(0, o, 0)) * U.AxisY, rib)
		end
		for _, s in { -1, 1 } do
			lCyl(0.14, 0.55, CFrame.new(lp + Vector3.new(0, 0.55 * s, 0)) * U.AxisY, LOCK, metal)
		end
		lBlock(Vector3.new(0.14, 0.38, 0.14), CFrame.new(lp + Vector3.new(0, -0.8, 0)), LOCK)
		lBall(0.18, CFrame.new(lp + Vector3.new(0, -0.62, 0)), LOCK, metal)
		-- a string of little lanterns across the lid front
		lCyl(2.5, 0.05, CFrame.new(0, BODY_H + 0.62, lidFrontZ - 0.06), rib)
		for i, x in { -0.95, -0.32, 0.32, 0.95 } do
			lBall(0.34, CFrame.new(x, BODY_H + 0.42, lidFrontZ - 0.16), if i % 2 == 1 then paper else LOCK)
			lCyl(0.06, 0.18, CFrame.new(x, BODY_H + 0.6, lidFrontZ - 0.16) * U.AxisY, LOCK)
		end
		-- gold trim over the plinth and gold corner caps
		bBlock(Vector3.new(W + 0.3, 0.1, D + 0.3), CFrame.new(0, 0.38, 0), LOCK, metal)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bBlock(Vector3.new(0.5, 0.5, 0.5), CFrame.new(sx * W / 2, 0.65, sz * D / 2), LOCK, metal)
			end
		end
	elseif style == "Library" then
		local bookCols = { Color3.fromRGB(70, 150, 140), Color3.fromRGB(150, 45, 55), Color3.fromRGB(50, 70, 140), Color3.fromRGB(80, 130, 60), Color3.fromRGB(110, 60, 130) }
		local cream = Color3.fromRGB(250, 240, 215)
		-- rows of book spines on both sides, each with a gold band
		for _, s in { -1, 1 } do
			for i, z in { -1.35, -0.8, -0.25, 0.3, 0.85, 1.4 } do
				local h = ({ 1.8, 1.55, 1.85, 1.65, 1.9, 1.5 })[i]
				local x = s * (W / 2 + 0.05)
				bBlock(Vector3.new(0.1, h, 0.5), CFrame.new(x, 0.35 + h / 2, z), bookCols[(i + (if s > 0 then 2 else 0)) % #bookCols + 1])
				bBlock(Vector3.new(0.12, 0.1, 0.5), CFrame.new(x, 0.35 + h - 0.3, z), LOCK)
			end
		end
		-- book clasp: a gold strap down the lid front with a gem
		lBlock(Vector3.new(0.42, 0.85, 0.06), CFrame.new(0, BODY_H + 0.25, lidFrontZ - 0.12), LOCK, metal)
		lBlock(Vector3.new(0.6, 0.38, 0.14), CFrame.new(0, BODY_H - 0.12, lidFrontZ - 0.15), LOCK, metal)
		lBlock(Vector3.new(0.2, 0.2, 0.06), CFrame.new(0, BODY_H - 0.12, lidFrontZ - 0.24) * CFrame.Angles(0, 0, math.pi / 4), trim, NEON)
		-- open spellbook lying on the lid with a floating rune above it
		local bk = Vector3.new(0, lidTop, -0.05)
		lBlock(Vector3.new(2.3, 0.1, 1.55), CFrame.new(bk + Vector3.new(0, 0.05, 0)), Color3.fromRGB(80, 40, 100))
		for _, s in { -1, 1 } do
			local page = CFrame.new(bk + Vector3.new(0.55 * s, 0.17, 0)) * CFrame.Angles(0, 0, 0.12 * s)
			lBlock(Vector3.new(1.05, 0.14, 1.4), page, cream)
			for _, z in { -0.35, 0, 0.35 } do
				lBlock(Vector3.new(0.7, 0.02, 0.07), page * CFrame.new(0.02 * s, 0.08, z), Color3.fromRGB(120, 100, 90))
			end
		end
		lBlock(Vector3.new(0.12, 0.03, 0.75), CFrame.new(bk + Vector3.new(0, 0.12, -0.95)), trim)
		lBlock(Vector3.new(0.26, 0.26, 0.26), CFrame.new(bk + Vector3.new(0, 0.8, 0)) * U.VertexUp, trim, NEON)
		-- gold corner protectors on the lid front
		for _, s in { -1, 1 } do
			lWedge(Vector3.new(0.08, 0.45, 0.45), CFrame.new(s * (W / 2 + 0.02), BODY_H + LID_H - 0.2, lidFrontZ + 0.2), LOCK, metal)
		end
	elseif style == "Topsy" then
		local wood = U.Shade(color, 0.6)
		-- little feet sticking up off the lid (the chest is "upside down")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local fp = Vector3.new(sx * 1.95, lidTop, sz * 0.8)
				lCyl(0.4, 0.38, CFrame.new(fp + Vector3.new(0, 0.2, 0)) * U.AxisY, wood)
				lBall(0.55, CFrame.new(fp + Vector3.new(0, 0.48, 0)), band)
			end
		end
		-- a fake lid seam and hinges down at the bottom
		bBlock(Vector3.new(W + 0.04, 0.08, D + 0.04), CFrame.new(0, 0.8, 0), trim)
		bBlock(Vector3.new(W + 0.04, 0.2, D + 0.04), CFrame.new(0, 0.62, 0), U.Shade(color, 0.8))
		for _, s in { -1, 1 } do
			bCyl(0.5, 0.24, CFrame.new(s * 1.3, 0.8, D / 2 + 0.08), METAL, metal)
			bCyl(0.25, 0.24, CFrame.new(s * (W / 2 + 0.05), 0.8, 1.45) * U.AxisZ, METAL, metal)
		end
		-- "this way up" arrows on the sides, pointing down
		for _, s in { -1, 1 } do
			local x = s * (W / 2 + 0.03)
			bBlock(Vector3.new(0.06, 0.7, 0.16), CFrame.new(x, 1.55, 0), trim)
			for _, k in { -1, 1 } do
				bBlock(Vector3.new(0.06, 0.42, 0.14), CFrame.new(x, 1.27, 0.12 * k) * CFrame.Angles(0.75 * k, 0, 0), trim)
			end
		end
		-- a spiral swirl on the lid between the feet
		local sw = CFrame.new(0, lidTop + 0.04, -0.05)
		for k = 0, 5 do
			local a = k * 1.1
			local r = 0.15 + k * 0.1
			lBall(0.18 + k * 0.02, sw * CFrame.new(r * math.cos(a), 0, r * math.sin(a)), if k % 2 == 0 then trim else WHITE)
		end
	elseif style == "Shroom" then
		local cap = U.Mix(trim, color, 0.35)
		local spot = Color3.fromRGB(245, 250, 235)
		local gill = Color3.fromRGB(215, 235, 215)
		-- stepped mushroom cap over the lid, spotted, with pale gills underneath
		lCyl(0.06, 4.15, CFrame.new(0, lidTop - 0.02, 0) * U.AxisY, gill)
		local tiers = { { 4.4, 0.3 }, { 3.6, 0.28 }, { 2.6, 0.25 }, { 1.4, 0.2 } }
		local y = lidTop
		local tierY: { number } = {}
		for _, t in tiers do
			lCyl(t[2], t[1], CFrame.new(0, y + t[2] / 2, 0) * U.AxisY, cap)
			table.insert(tierY, y + t[2] / 2)
			y += t[2]
		end
		local spots = { { 1, 200 }, { 1, 245 }, { 1, 290 }, { 1, 335 }, { 1, 20 }, { 2, 225 }, { 2, 280 }, { 2, 330 }, { 2, 60 }, { 3, 250 }, { 3, 310 } }
		for _, sp in spots do
			local a = math.rad(sp[2])
			local r = tiers[sp[1]][1] / 2 - 0.08
			lBall(0.42 - sp[1] * 0.04, CFrame.new(r * math.cos(a), tierY[sp[1]] + 0.04, r * math.sin(a)), spot)
		end
		lCyl(0.05, 0.6, CFrame.new(0, y, 0) * U.AxisY, spot)
		-- little glowshrooms by the front corners (outside the lid's swing); one glows
		for i, c in { Vector3.new(-2.85, 0.3, -1.3), Vector3.new(2.85, 0.3, -1.1), Vector3.new(-2.95, 0.3, -0.55) } do
			local h = if i == 3 then 0.35 else 0.6
			bCyl(h, 0.2, CFrame.new(c + Vector3.new(0, h / 2, 0)) * U.AxisY, spot)
			bCyl(0.16, if i == 3 then 0.45 else 0.7, CFrame.new(c + Vector3.new(0, h + 0.05, 0)) * U.AxisY, if i == 1 then trim else cap, if i == 1 then NEON else nil)
			bBall(0.12, CFrame.new(c + Vector3.new(0.12, h + 0.14, -0.1)), spot)
		end
	elseif style == "Mirror" then
		local glass: U.Opts = { Reflectance = 0.45 }
		local pane = Color3.fromRGB(165, 210, 245)
		local frame = Color3.fromRGB(230, 235, 245)
		-- framed mirror panels on the sides and front
		for _, s in { -1, 1 } do
			local x = s * (W / 2 + 0.03)
			bBlock(Vector3.new(0.06, 1.5, 2.7), CFrame.new(x, 1.3, 0), frame, metal)
			bBlock(Vector3.new(0.06, 1.25, 2.45), CFrame.new(x + 0.03 * s, 1.3, 0), pane, glass)
			bBlock(Vector3.new(0.06, 0.95, 0.12), CFrame.new(x + 0.07 * s, 1.35, -0.6) * CFrame.Angles(0.7, 0, 0), WHITE) -- shine streak
			bBlock(Vector3.new(0.06, 0.55, 0.08), CFrame.new(x + 0.07 * s, 1.45, -0.25) * CFrame.Angles(0.7, 0, 0), WHITE)
			local fx = s * 1.08
			bBlock(Vector3.new(0.7, 1.35, 0.06), CFrame.new(fx, 1.25, frontZ - 0.03), frame, metal)
			bBlock(Vector3.new(0.5, 1.15, 0.06), CFrame.new(fx, 1.25, frontZ - 0.06), pane, glass)
		end
		-- diamond mirror tiles along the lid front
		for _, x in { -1.0, -0.33, 0.33, 1.0 } do
			lBlock(Vector3.new(0.3, 0.3, 0.06), CFrame.new(x, BODY_H + 0.42, lidFrontZ - 0.03) * CFrame.Angles(0, 0, math.pi / 4), pane, glass)
		end
		-- round mirror on a stand on the lid, with a glint
		local mp = Vector3.new(0, lidTop + 1.0, 0.15)
		lCyl(0.12, 0.7, CFrame.new(0, lidTop + 0.06, 0.15) * U.AxisY, frame, metal)
		lCyl(0.3, 0.16, CFrame.new(0, lidTop + 0.25, 0.15) * U.AxisY, frame, metal)
		lCyl(0.16, 1.55, CFrame.new(mp) * U.AxisZ, frame, metal)
		lCyl(0.06, 1.3, CFrame.new(mp + Vector3.new(0, 0, -0.08)) * U.AxisZ, pane, glass)
		for _, s in { -1, 0, 1 } do
			lBall(0.2, CFrame.new(mp + Vector3.new(0.45 * s, 0.75 - math.abs(s) * 0.2, 0)), band)
		end
		local gl = CFrame.new(mp + Vector3.new(-0.3, 0.3, -0.13))
		lBlock(Vector3.new(0.06, 0.4, 0.04), gl, WHITE, NEON)
		lBlock(Vector3.new(0.4, 0.06, 0.04), gl, WHITE, NEON)
	elseif style == "Subway" then
		local wheelC = Color3.fromRGB(45, 45, 55)
		local dark: U.Opts = { Material = Enum.Material.Metal }
		-- train wheels and coupling rods on the sides
		for _, s in { -1, 1 } do
			for _, z in { -1.0, 1.0 } do
				bCyl(0.2, 0.85, CFrame.new(s * (W / 2 + 0.2), 0.5, z), wheelC, dark)
				bCyl(0.26, 0.32, CFrame.new(s * (W / 2 + 0.26), 0.5, z), trim, metal)
			end
			bBlock(Vector3.new(0.06, 0.12, 2.1), CFrame.new(s * (W / 2 + 0.42), 0.5, 0), METAL, metal)
		end
		-- rivets on the band fronts and lid bands
		for _, s in { -1, 1 } do
			for _, dx in { -0.15, 0.15 } do
				for _, y in { 0.75, 1.25, 1.75 } do
					bBall(0.14, CFrame.new(BAND_X * s + dx, y, frontZ - 0.07), METAL, metal)
				end
				lBall(0.14, CFrame.new(BAND_X * s + dx, BODY_H + 0.55, lidFrontZ - 0.07), METAL, metal)
			end
		end
		-- yellow-and-black "mind the gap" stripe along the bottom of the front
		bBlock(Vector3.new(W, 0.25, 0.06), CFrame.new(0, 0.53, frontZ - 0.09), trim)
		for x = -2.2, 2.25, 0.55 do
			bBlock(Vector3.new(0.12, 0.25, 0.04), CFrame.new(x, 0.53, frontZ - 0.13) * CFrame.Angles(0, 0, 0.6), wheelC)
		end
		-- headlight on the lid front
		local hl = CFrame.new(0, BODY_H + 0.42, lidFrontZ - 0.12)
		lCyl(0.24, 0.7, hl * U.AxisZ, wheelC, dark)
		lCyl(0.06, 0.5, hl * CFrame.new(0, 0, -0.13) * U.AxisZ, Color3.fromRGB(255, 245, 200), NEON)
		lBlock(Vector3.new(0.8, 0.08, 0.3), hl * CFrame.new(0, 0.37, -0.05), wheelC, dark)
		-- destination sign on the lid
		local sg = CFrame.new(0, lidTop + 0.42, 0.2)
		lBlock(Vector3.new(0.12, 0.3, 0.12), CFrame.new(-0.7, lidTop + 0.12, 0.2), wheelC, dark)
		lBlock(Vector3.new(0.12, 0.3, 0.12), CFrame.new(0.7, lidTop + 0.12, 0.2), wheelC, dark)
		lBlock(Vector3.new(2.0, 0.5, 0.18), sg, wheelC, dark)
		lBlock(Vector3.new(1.8, 0.34, 0.04), sg * CFrame.new(0, 0, -0.1), trim)
		for i, x in { -0.6, -0.2, 0.25, 0.6 } do
			lBlock(Vector3.new(if i == 3 then 0.12 else 0.26, 0.16, 0.03), sg * CFrame.new(x, 0, -0.12), wheelC)
		end
	elseif style == "Neon" then
		local cyan = Color3.fromRGB(100, 230, 255)
		local tube = 0.1
		-- thin neon tubes along the front corners, the bottom edge and the lid edge
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bCyl(BODY_H - 0.45, tube, CFrame.new(sx * (W / 2 + 0.03), 0.35 + (BODY_H - 0.45) / 2, sz * (D / 2 + 0.03)) * U.AxisY, trim, NEON)
			end
		end
		bCyl(W - 0.2, tube, CFrame.new(0, 0.45, frontZ - 0.04), cyan, NEON)
		lCyl(W + 0.05, tube, CFrame.new(0, BODY_H + LID_H, lidFrontZ - 0.03), cyan, NEON)
		-- dark tube clips
		for _, x in { -1.2, 1.2 } do
			bBlock(Vector3.new(0.12, 0.18, 0.1), CFrame.new(x, 0.45, frontZ - 0.05), EYE)
		end
		-- neon star sign standing on the lid
		local board = CFrame.new(0, lidTop + 0.85, 0.45)
		lBlock(Vector3.new(0.12, 0.4, 0.12), CFrame.new(-0.5, lidTop + 0.2, 0.45), METAL, metal)
		lBlock(Vector3.new(0.12, 0.4, 0.12), CFrame.new(0.5, lidTop + 0.2, 0.45), METAL, metal)
		lBlock(Vector3.new(1.6, 1.4, 0.12), board, U.Shade(color, 0.7))
		local pts: { Vector3 } = {}
		for k = 0, 9 do
			local a = math.pi / 2 + k * math.pi / 5
			local r = if k % 2 == 0 then 0.55 else 0.24
			table.insert(pts, (board * CFrame.new(r * math.cos(a), r * math.sin(a), -0.1)).Position)
		end
		for k = 1, 10 do
			local a, b = pts[k], pts[k % 10 + 1]
			lCyl((b - a).Magnitude + 0.06, 0.08, U.Between(a, b), trim, NEON)
		end
		-- little speaker/sign dots along the board's base
		for _, x in { -0.55, 0, 0.55 } do
			lBall(0.12, board * CFrame.new(x, -0.55, -0.08), cyan)
		end
	elseif style == "Storm" then
		local cloud = Color3.fromRGB(235, 240, 250)
		local under = Color3.fromRGB(165, 175, 205)
		local rain = Color3.fromRGB(110, 170, 255)
		-- puffy cloud floating over the lid, zapping it with a lightning bolt
		-- zig-zag bolt through `pts` (all at the same Z), `w` wide
		local function bolt(pts: { Vector3 }, w: number, onTheLid: boolean, opts: U.Opts?)
			for k = 1, #pts - 1 do
				local a, b = pts[k], pts[k + 1]
				local size = Vector3.new(0.1, w, (b - a).Magnitude + w * 0.5)
				if onTheLid then
					lBlock(size, CFrame.lookAt((a + b) / 2, b), trim, opts)
				else
					bBlock(size, CFrame.lookAt((a + b) / 2, b), trim, opts)
				end
			end
		end
		local cc = Vector3.new(0.15, lidTop + 1.6, 0.25)
		for _, b in { { 0, -0.3, 0, 0.95, 1 }, { 0, 0, 0, 1.2, 0 }, { -0.65, -0.15, 0, 0.9, 0 }, { 0.65, -0.12, 0.05, 0.95, 0 }, { -0.3, 0.32, 0.1, 0.85, 0 }, { 0.32, 0.35, -0.05, 0.9, 0 }, { -1.05, -0.25, 0, 0.6, 0 }, { 1.05, -0.25, 0, 0.6, 0 } } do
			lBall(b[4], CFrame.new(cc + Vector3.new(b[1], b[2], b[3])), if b[5] == 1 then under else cloud)
		end
		local bz = -0.45
		bolt({ Vector3.new(0.45, cc.Y - 0.35, bz), Vector3.new(-0.1, lidTop + 0.6, bz), Vector3.new(0.35, lidTop + 0.55, bz), Vector3.new(-0.05, lidTop + 0.02, bz) }, 0.26, true, NEON)
		-- raindrops on the sides
		for _, s in { -1, 1 } do
			for _, p in { Vector2.new(1.7, -0.9), Vector2.new(1.2, 0.1), Vector2.new(1.8, 0.9), Vector2.new(0.8, -0.35), Vector2.new(0.7, 1.15) } do
				local dp = Vector3.new(s * (W / 2 + 0.04), p.X, p.Y)
				bBall(0.24, CFrame.new(dp), rain)
				bBlock(Vector3.new(0.13, 0.13, 0.13), CFrame.new(dp + Vector3.new(0, 0.12, 0)) * U.VertexUp, rain)
			end
		end
		-- solid bolts on the front either side of the emblem
		for _, s in { -1, 1 } do
			local x, z = 1.08 * s, frontZ - 0.05
			bolt({ Vector3.new(x + 0.18, 1.8, z), Vector3.new(x - 0.12, 1.3, z), Vector3.new(x + 0.12, 1.3, z), Vector3.new(x - 0.18, 0.8, z) }, 0.17, false)
		end
		-- cloud puffs round the base, like the chest is floating on a sky island
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bBall(0.9, CFrame.new(sx * W / 2, 0.25, sz * D / 2), cloud)
				bBall(0.6, CFrame.new(sx * (W / 2 - 0.55), 0.2, sz * (D / 2 + 0.05)), cloud)
			end
		end
	elseif style == "Moon" then
		local panel = Color3.fromRGB(250, 251, 253)
		local seamC = Color3.fromRGB(95, 100, 115)
		-- white hull panels on the sides with seams and bolts
		for _, s in { -1, 1 } do
			local x = s * (W / 2 + 0.03)
			bBlock(Vector3.new(0.06, 1.3, 2.9), CFrame.new(x, 1.35, 0), panel)
			bBlock(Vector3.new(0.08, 1.3, 0.05), CFrame.new(x, 1.35, 0), seamC)
			for _, z in { -1.3, -0.15, 0.15, 1.3 } do
				for _, y in { 0.82, 1.88 } do
					bBall(0.1, CFrame.new(x + 0.03 * s, y, z), seamC)
				end
			end
			-- front panels either side of the emblem
			bBlock(Vector3.new(0.6, 1.25, 0.06), CFrame.new(1.08 * s, 1.3, frontZ - 0.03), panel)
		end
		-- orange stripe round the body
		bBlock(Vector3.new(W + 0.04, 0.18, D + 0.04), CFrame.new(0, 0.5, 0), band, bandOpts)
		-- vent slots on the lid front
		for _, y in { 0.3, 0.45, 0.6 } do
			lBlock(Vector3.new(0.7, 0.06, 0.04), CFrame.new(0, BODY_H + y, lidFrontZ - 0.02), seamC)
		end
		-- radar dish and a whip antenna with a blinking light on the lid
		local dp = Vector3.new(-0.85, lidTop, 0.25)
		lCyl(0.45, 0.16, CFrame.new(dp + Vector3.new(0, 0.22, 0)) * U.AxisY, METAL, metal)
		local dish = CFrame.new(dp + Vector3.new(0, 0.6, 0)) * CFrame.Angles(-0.65, 0, 0)
		lCyl(0.12, 1.2, dish * U.AxisY, panel)
		lCyl(0.45, 0.06, dish * CFrame.new(0, 0.25, 0) * U.AxisY, METAL, metal)
		lBall(0.16, dish * CFrame.new(0, 0.48, 0), band)
		local ap = Vector3.new(1.3, lidTop, 0.5)
		lCyl(0.15, 0.4, CFrame.new(ap + Vector3.new(0, 0.07, 0)) * U.AxisY, seamC)
		lCyl(1.3, 0.08, CFrame.new(ap + Vector3.new(0, 0.7, 0)) * U.AxisY, METAL, metal)
		lBall(0.22, CFrame.new(ap + Vector3.new(0, 1.38, 0)), trim, NEON)
		-- lander legs with foot pads at the corners (below the lid, so they never block it)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local a = Vector3.new(sx * 2.4, 1.15, sz * 1.5)
				local b = Vector3.new(sx * 3.0, 0.12, sz * 1.95)
				bCyl((b - a).Magnitude, 0.16, U.Between(a, b), METAL, metal)
				bCyl(0.1, 0.55, CFrame.new(b) * U.AxisY, METAL, metal)
				bBall(0.24, CFrame.new(a), band)
			end
		end
	elseif style == "Void" then
		local violet = Color3.fromRGB(200, 150, 255)
		local orbC = Color3.fromRGB(45, 20, 80)
		-- white four-point star studs all over the chest (a frame's -Z faces outward)
		local function star(cf: CFrame, sz: number, onTheLid: boolean)
			-- an eight-point star: two squares, one turned 45 degrees
			local q = sz * 0.6
			local function put(size: Vector3, at: CFrame)
				if onTheLid then
					lBlock(size, at, WHITE)
				else
					bBlock(size, at, WHITE)
				end
			end
			put(Vector3.new(q, q, 0.05), cf)
			put(Vector3.new(q, q, 0.05), cf * CFrame.Angles(0, 0, math.pi / 4))
		end
		for _, p in { Vector3.new(-1.1, 1.7, 0.4), Vector3.new(1.15, 1.0, 0.45), Vector3.new(-1.0, 0.7, 0.3), Vector3.new(1.0, 1.85, 0.3), Vector3.new(0, 0.5, 0.25) } do
			star(CFrame.new(p.X, p.Y, frontZ - 0.03), p.Z, false)
		end
		for _, s in { -1, 1 } do
			for _, p in { Vector3.new(1.65, -0.8, 0.45), Vector3.new(0.85, 0.5, 0.35), Vector3.new(1.5, 1.2, 0.3), Vector3.new(0.75, -1.3, 0.25) } do
				star(CFrame.new(s * (W / 2 + 0.03), p.X, p.Y) * CFrame.Angles(0, -s * math.pi / 2, 0), p.Z, false)
			end
		end
		for _, p in { Vector3.new(-0.95, 2.72, 0.3), Vector3.new(0.95, 2.62, 0.25) } do
			star(CFrame.new(p.X, p.Y, lidFrontZ - 0.03), p.Z, true)
		end
		-- tiny white dots between the stars
		for _, p in { Vector3.new(-0.55, 0.45, frontZ), Vector3.new(0.6, 2.0, frontZ), Vector3.new(-1.35, 1.25, frontZ) } do
			bBall(0.1, CFrame.new(p), WHITE)
		end
		-- violet trim over the plinth
		bBlock(Vector3.new(W + 0.3, 0.1, D + 0.3), CFrame.new(0, 0.38, 0), violet)
		-- void orb with a ringed orbit on a pedestal, a small star glinting above it
		local op = Vector3.new(0, lidTop + 0.95, 0.05)
		lCyl(0.18, 1.0, CFrame.new(0, lidTop + 0.09, 0.05) * U.AxisY, U.Shade(color, 1.6))
		lCyl(0.3, 0.3, CFrame.new(0, lidTop + 0.3, 0.05) * U.AxisY, violet)
		lBall(1.05, CFrame.new(op), orbC)
		for _, p in U.Hoop(0.78, 0.08, 0.06, 14, CFrame.new(op) * CFrame.Angles(math.rad(70), 0, math.rad(18)), WHITE, model) do
			onLid(p)
		end
		local gl = CFrame.new(op + Vector3.new(0.45, 0.7, -0.1))
		lBlock(Vector3.new(0.2, 0.2, 0.04), gl, violet, NEON)
		lBlock(Vector3.new(0.2, 0.2, 0.04), gl * CFrame.Angles(0, 0, math.pi / 4), violet, NEON)
	elseif style == "Harvest" or style == "Splash" or style == "Shopping" or style == "Fossil" or style == "Trophy" or style == "CookieJar" or style == "Arcade" then
		-- PLACEHOLDER (world2b): plain chest, no decorations until the real styles are built (see NEW_PARTS_16.md)
	elseif style ~= "Basic" then
		warn("CrateRig: no decorations for style " .. tostring(style))
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
