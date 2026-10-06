--!strict
-- World 2 ghost looks (areas 17-32 and the Void Emperor world boss). The seven areas added in
-- the 16-area World 2 (19, 21, 23, 25, 26, 28, 29) live in World2b.luau.
--
-- GhostRig.Build draws the standard body (diameter 3.5 at the origin, face towards -Z, nub arms
-- at x = +-1.7, tail curling down and back to (0.2, -2.7, 1.9)) and the face, then calls
-- World2.Styles[style](kit) to add the accessories. The kit holds GhostRig's part helpers, so
-- every part here is welded to Core and scaled with the ghost like the World 1 styles.
-- Glow stays modest: Neon only on eyes, flames, sparks, runes and other small accents.

local U = require(script.Parent.Parent.RigUtil)

export type Kit = {
	color: Color3,
	glow: Color3,
	accent: Color3,
	R: number,
	ball: (d: number, cf: CFrame, c: Color3, opts: U.Opts?) -> BasePart,
	block: (size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?) -> BasePart,
	cyl: (len: number, d: number, cf: CFrame, c: Color3, opts: U.Opts?) -> BasePart,
	wedge: (size: Vector3, cf: CFrame, c: Color3, opts: U.Opts?) -> BasePart,
	rod: (a: Vector3, b: Vector3, d: number, c: Color3, opts: U.Opts?) -> BasePart,
	ring: (y: number, thick: number, c: Color3, opts: U.Opts?, tilt: number?) -> (),
	ruff: (y: number, n: number, d: number, c1: Color3, c2: Color3) -> (),
	cone: (base: CFrame, d: number, h: number, tiers: number, c1: Color3, c2: Color3?) -> CFrame,
	brow: (s: number, y: number, angry: boolean, c: Color3, w: number) -> (),
	surf: (dir: Vector3, out: number) -> Vector3,
	point: (base: Vector3, dir: Vector3, w: number, len: number, thick: number, c: Color3, opts: U.Opts?) -> (),
}

local World2 = {}

-- styles built upside down (GhostRig turns every part 180 degrees about Z before welding)
World2.Flipped = { Dizzy = true, Topsy = true } :: { [string]: boolean }

local WHITE = Color3.fromRGB(255, 255, 255)
local EYE = Color3.fromRGB(25, 15, 40)
local GOLD = Color3.fromRGB(255, 205, 60)
local BRASS = Color3.fromRGB(205, 160, 75)
local CREAM = Color3.fromRGB(255, 244, 220)
local RED = Color3.fromRGB(220, 50, 55)
local SILVER = Color3.fromRGB(200, 205, 222)
local STEEL = Color3.fromRGB(95, 100, 120)
local VOID = Color3.fromRGB(14, 11, 24)

local NEON = { Material = Enum.Material.Neon }
local METAL = { Material = Enum.Material.Metal }

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- 4-point sparkle: two crossed thin bars in the XY plane
local function sparkle(k: Kit, p: Vector3, s: number, c: Color3, opts: U.Opts?, tilt: number?)
	local cf = CFrame.new(p) * CFrame.Angles(0, 0, tilt or 0)
	k.block(v(0.1 * s, s, 0.1 * s), cf, c, opts)
	k.block(v(s * 0.75, 0.1 * s, 0.1 * s), cf, c, opts)
end

-- arc of `n` thin cylinders of radius `r` in the frame's XY plane, from angle a0 to a1
local function arc(k: Kit, cf: CFrame, r: number, a0: number, a1: number, n: number, d: number, c: Color3, opts: U.Opts?)
	local step = (a1 - a0) / n
	local len = 2 * r * math.sin(math.abs(step) / 2) + d * 0.7
	for i = 0, n - 1 do
		local a = a0 + (i + 0.5) * step
		k.cyl(len, d, cf * CFrame.Angles(0, 0, a) * CFrame.new(r, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), c, opts)
	end
end

-- zig-zag of square bars through `pts` (lightning bolts, cracks); `up` keeps the bars flat on a surface
local function zigzag(k: Kit, pts: { Vector3 }, w: number, c: Color3, opts: U.Opts?, up: Vector3?)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		local cf = if up then CFrame.lookAt(mid, b, up) else CFrame.lookAt(mid, b)
		k.block(v(w, w * 0.6, (b - a).Magnitude + w * 0.5), cf, c, opts)
	end
end

-- little toadstool standing on `base` (its +Y): stem, flat brim and a dome, optional spots
local function shroom(k: Kit, base: CFrame, stemH: number, capD: number, capC: Color3, spotC: Color3?, stemC: Color3, capOpts: U.Opts?)
	k.cyl(stemH, capD * 0.3, base * at(0, stemH / 2, 0) * U.AxisY, stemC)
	local top = base * at(0, stemH, 0)
	k.cyl(capD * 0.14, capD, top * U.AxisY, capC, capOpts)
	k.ball(capD * 0.76, top * at(0, capD * 0.05, 0), capC, capOpts)
	if spotC then
		for _, d in { v(0.55, 0.75, -0.3), v(-0.5, 0.8, 0.25), v(0.05, 0.75, 0.65) } do
			k.ball(capD * 0.17, top * CFrame.new(v(0, capD * 0.05, 0) + d.Unit * capD * 0.38), spotC)
		end
	end
end

-- flat pointed blade: base edge `w` wide at `base`, tip `len` along `dir`, its face looking along `n`
local function blade(k: Kit, base: Vector3, dir: Vector3, n: Vector3, w: number, len: number, thick: number, c: Color3, opts: U.Opts?)
	local z = -dir.Unit
	local x = (n - z * n:Dot(z)).Unit
	local f = CFrame.fromMatrix(base, x, z:Cross(x), z) * at(0, 0, -len / 2)
	k.wedge(v(thick, w / 2, len), f * at(0, w / 4, 0), c, opts)
	k.wedge(v(thick, w / 2, len), f * at(0, -w / 4, 0) * CFrame.Angles(0, 0, math.pi), c, opts)
end

-- "▽" on a flat face looking along `n`: top edge `w` wide centred at `top`, `h` deep
local function vTri(k: Kit, top: Vector3, n: Vector3, w: number, h: number, thick: number, c: Color3, opts: U.Opts?)
	blade(k, top, v(0, -1, 0), n, w, h, thick, c, opts)
end

-- 4-point star of flat blades round `p`, its face looking along `n`
local function star4(k: Kit, p: Vector3, n: Vector3, size: number, c: Color3, opts: U.Opts?, spin: number?)
	local x = n.Unit
	local a = (Vector3.yAxis - x * Vector3.yAxis:Dot(x)).Unit
	local b = x:Cross(a)
	for i = 0, 3 do
		local t = (spin or 0) + i * math.pi / 2
		blade(k, p, a * math.cos(t) + b * math.sin(t), n, size * 0.6, size * 0.55, size * 0.1, c, opts)
	end
end

-- low round patch on the body surface in direction `d` (moss, paint splats, craters): a ball
-- sunk into the body so only a cap `h` studs high shows (flat discs would stick out at the edges)
local function patch(k: Kit, d: Vector3, size: number, c: Color3, h: number?)
	k.ball(size, CFrame.new(k.surf(d, (h or 0.06) - size / 2)), c)
end

-- body halves: the same balls nudged a hair along +X win exactly on that side (two-tone split)
local function rightHalf(k: Kit, c: Color3, dx: number)
	k.ball(3.5, at(dx, 0, 0), c, { Shadow = false })
	k.ball(2.7, at(dx, -0.95, 0.45), c, { Shadow = false })
	k.ball(2.0, at(0.15 + dx, -1.75, 0.95), c, { Shadow = false })
	k.ball(1.35, at(-0.05 + dx, -2.35, 1.45), c, { Shadow = false })
	k.ball(0.8, at(0.2 + dx, -2.7, 1.9), c, { Shadow = false })
	k.ball(1.0, at(1.7, -0.35, -0.2), c, { Shadow = false }) -- right nub
end

local S: { [string]: (Kit) -> () } = {}

------------------------------------------------------------------ 17 Lantern Market
S.PaperLantern = function(k)
	-- the wisp floats inside a red paper lantern: bowed panels round the back and sides (open at
	-- the front so the face shows), gold top and bottom rims, a hanging loop and a gold tassel
	local paper = RED
	for i = 0, 5 do
		local rot = CFrame.Angles(0, math.rad(78 + i * 40.8), 0)
		for _, h in { 1, -1 } do
			local a, b = v(0, 1.3 * h, -1.25), v(0, 0.02 * h, -2.0)
			k.block(v(1.2, 0.1, (b - a).Magnitude + 0.05), rot * CFrame.lookAt((a + b) / 2, b), if i % 2 == 0 then paper else U.Shade(paper, 0.85))
		end
	end
	k.cyl(0.3, 2.75, at(0, 1.4, 0) * U.AxisY, GOLD, METAL)
	k.cyl(0.24, 2.75, at(0, -1.4, 0) * U.AxisY, GOLD, METAL)
	k.cyl(0.35, 1.2, at(0, 1.7, 0) * U.AxisY, GOLD, METAL)
	k.cyl(0.1, 0.55, at(0, 2.05, 0) * U.AxisZ, GOLD, METAL) -- loop
	-- tassel under the tail
	local tip = v(0.2, -3.05, 1.95)
	k.ball(0.42, CFrame.new(tip), GOLD, METAL)
	for _, o in { v(-0.1, 0, 0), v(0.1, 0, 0.05), v(0, 0, -0.1) } do
		k.rod(tip + o * 0.5, tip + o * 2 + v(0, -0.85, 0), 0.08, GOLD)
	end
end

S.Dumpling = function(k)
	-- plump cream dumpling: fuller belly, pleated twist pinched to a knob on top, three steam puffs
	k.ball(3.1, at(0, -0.55, 0.15), k.color)
	local pleat = U.Shade(k.color, 0.9)
	for i = 0, 7 do
		local rot = at(0, 1.7, 0.05) * CFrame.Angles(0, i * math.pi / 4, 0)
		k.wedge(v(0.5, 0.85, 0.55), rot * at(0, 0.3, -0.42) * CFrame.Angles(0.3, 0, 0), if i % 2 == 0 then k.color else pleat)
	end
	k.ball(0.6, at(0, 2.35, 0.05), k.color)
	local steam = Color3.fromRGB(245, 248, 255)
	k.ball(0.62, at(0.25, 2.95, 0.25), steam)
	k.ball(0.5, at(-0.1, 3.5, 0.4), steam)
	k.ball(0.38, at(0.3, 3.95, 0.55), steam)
end

S.DragonDance = function(k)
	-- festival dragon-dance head worn like a mask: boxy snout over the head, open lower jaw,
	-- gold horns and whiskers, fluffy mane, and four floating lantern segments trailing behind
	local red = k.color
	local dark = U.Shade(red, 0.62)
	local snout = at(0, 1.5, -0.55) * CFrame.Angles(-0.1, 0, 0)
	k.block(v(3.0, 1.05, 3.0), snout, red)
	k.block(v(2.75, 0.22, 0.25), snout * at(0, -0.45, -1.52), GOLD, METAL) -- gold lip
	for _, s in { -1, 1 } do
		k.ball(0.38, snout * at(0.6 * s, 0.25, -1.5), dark) -- nostril
		-- dragon eyes on top of the snout
		local ep = snout * at(0.85 * s, 0.62, -0.45)
		k.ball(0.8, ep, WHITE)
		k.ball(0.38, ep * at(0.05 * s, 0.05, -0.3), EYE)
		k.wedge(v(0.7, 0.3, 0.45), ep * at(0.05 * s, 0.45, 0.05) * CFrame.Angles(0, 0, -0.35 * s), GOLD, METAL) -- brow
		-- horns
		local hb = v(0.85 * s, 2.05, 0.45)
		local hm = v(1.25 * s, 2.85, 1.0)
		k.rod(hb, hm, 0.36, GOLD, METAL)
		k.point(hm, v(0.25 * s, 0.7, 0.8), 0.32, 0.75, 0.3, GOLD, METAL)
		-- long whiskers
		local wb = snout * v(1.5 * s, -0.1, -1.3)
		local wm = wb + v(1.2 * s, -0.55, -0.35)
		k.rod(wb, wm, 0.09, GOLD)
		k.rod(wm, wm + v(0.75 * s, 0.4, -0.15), 0.08, GOLD)
		-- teeth hanging from the upper jaw
		for _, x in { 0.45, 1.05 } do
			vTri(k, snout * v(x * s, -0.55, -1.46), v(0, 0, -1), 0.3, 0.32, 0.1, WHITE)
		end
	end
	-- open lower jaw under the ghost's grin
	local jaw = at(0, -1.3, -1.15) * CFrame.Angles(0.18, 0, 0)
	k.block(v(2.7, 0.55, 2.0), jaw, red)
	k.block(v(2.45, 0.18, 0.2), jaw * at(0, 0.2, -1.0), GOLD, METAL)
	-- fluffy mane round the back of the head
	local mane = { GOLD, Color3.fromRGB(255, 140, 40), CREAM }
	for i = 0, 7 do
		local t = math.rad(-105 + i * 30)
		k.ball(0.95, at(math.sin(t) * 1.75, 0.95 + math.cos(t) * 1.3, 1.1), mane[i % 3 + 1])
	end
	-- trailing lantern segments (the dragon's body)
	for i = 1, 4 do
		local s = 1.6 - i * 0.18
		local c = at(math.sin(i * 1.3) * 0.7, 0.35 + i * 0.42, 1.6 + i * 1.35)
		k.cyl(s * 0.75, s, c * U.AxisY, if i % 2 == 0 then red else dark)
		for _, h in { -1, 1 } do
			k.cyl(0.12, s * 0.7, c * at(0, h * s * 0.42, 0) * U.AxisY, GOLD, METAL)
		end
	end
end

------------------------------------------------------------------ 18 Phantom Library
S.FlyingBook = function(k)
	-- an open book for wings, hinged at a spine behind the back, and a ribbon-bookmark tail
	local cover = Color3.fromRGB(60, 120, 140)
	local spine = v(0, 0.3, 1.75)
	k.cyl(2.4, 0.4, CFrame.new(spine) * U.AxisY, U.Shade(cover, 0.75))
	for _, s in { -1, 1 } do
		local f = CFrame.new(spine) * CFrame.Angles(0, -0.2 * s, 0) * CFrame.Angles(0, 0, 0.4 * s)
		k.block(v(2.6, 2.3, 0.12), f * at(1.35 * s, 0, 0), cover)
		k.block(v(2.4, 2.1, 0.14), f * at(1.3 * s, 0, -0.12), CREAM)
		for j = 0, 2 do
			k.block(v(1.6, 0.08, 0.04), f * at(1.35 * s, 0.55 - j * 0.45, -0.2), U.Shade(cover, 0.6))
		end
	end
	-- red bookmark ribbon from the tail tip, with a notched end
	local ribbon = Color3.fromRGB(215, 40, 55)
	local a, b, c = v(0.2, -2.95, 1.95), v(0.45, -3.7, 2.15), v(0.3, -4.35, 2.3)
	for _, seg in { { a, b }, { b, c } } do
		k.block(v(0.38, 0.05, (seg[2] - seg[1]).Magnitude + 0.05), CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), ribbon)
	end
	vTri(k, c + v(0, 0.05, 0), v(0, 0, -1), 0.38, 0.3, 0.05, ribbon)
end

S.Inkblot = function(k)
	-- ink drips hanging off the body (each a thin cylinder with a drop at the tip) and a big
	-- quill feather stuck in the head
	local ink = Color3.fromRGB(30, 30, 70)
	for _, d in { v(-0.9, -0.65, -1.2), v(0.95, -0.9, -1.0), v(-1.35, -0.4, 0.6), v(1.25, -0.55, 0.9), v(0.2, -1.1, -0.95), v(-0.6, 0.15, -1.55) } do
		local p = k.surf(d, -0.08)
		local len = 0.3 + math.abs(d.X) * 0.25
		k.cyl(len, 0.17, CFrame.new(p - v(0, len / 2, 0)) * U.AxisY, ink)
		k.ball(0.32, CFrame.new(p - v(0, len + 0.05, 0)), ink)
	end
	patch(k, v(-0.6, 1, 0.3), 1.0, ink)
	-- quill
	local base = v(0.45, 1.4, 0.2)
	local dir = v(0.7, 1, 0.4).Unit
	k.ball(0.32, CFrame.new(base), GOLD, METAL)
	k.rod(base, base + dir * 3.2, 0.1, CREAM)
	local side = dir:Cross(Vector3.zAxis).Unit
	blade(k, base + dir * 3.25, -dir, side:Cross(dir), 0.8, 2.5, 0.08, WHITE) -- vane, widest near the top
	blade(k, base + dir * 3.25, dir, side:Cross(dir), 0.8, 0.45, 0.08, WHITE)
end

S.Grimoire = function(k)
	-- giant living spellbook wrapped round the ghost: back cover behind, front cover across the
	-- belly with one big eye, spine underneath, gold corner caps, a clasp lock and orbiting runes
	local leather = Color3.fromRGB(105, 35, 50)
	local back = at(0, -0.3, 2.05) * CFrame.Angles(0.12, 0, 0)
	k.block(v(4.0, 4.4, 0.3), back, leather)
	k.block(v(3.7, 4.1, 0.25), back * at(0, 0, -0.26), CREAM)
	local front = at(0, -1.75, -1.95) * CFrame.Angles(-0.15, 0, 0)
	k.block(v(4.0, 1.85, 0.3), front, leather)
	k.block(v(3.7, 1.55, 0.25), front * at(0, 0.08, 0.26), CREAM)
	k.block(v(4.0, 0.35, 4.3), at(0, -2.75, 0.05), U.Shade(leather, 0.8)) -- spine
	for _, s in { -1, 1 } do
		k.block(v(0.45, 0.45, 0.4), front * at(1.85 * s, 0.75, 0), GOLD, METAL)
		k.block(v(0.45, 0.45, 0.4), front * at(1.85 * s, -0.75, 0), GOLD, METAL)
		k.block(v(0.45, 0.45, 0.4), back * at(1.85 * s, 2.05, 0), GOLD, METAL)
		k.brow(s, 1.0, true, Color3.fromRGB(60, 25, 30), 0.7)
	end
	-- clasp strap + lock on the right of the front cover
	k.block(v(0.45, 1.85, 0.08), front * at(1.2, 0, -0.19), GOLD, METAL)
	k.block(v(0.6, 0.55, 0.22), front * at(1.2, 0.2, -0.25), GOLD, METAL)
	k.block(v(0.12, 0.26, 0.05), front * at(1.2, 0.15, -0.37), EYE)
	-- the book's eye
	local ef = front * at(-0.35, 0, -0.16)
	k.cyl(0.08, 1.2, ef * U.AxisZ, WHITE)
	k.cyl(0.08, 0.66, ef * at(0, 0, -0.04) * U.AxisZ, k.glow, NEON)
	k.cyl(0.08, 0.3, ef * at(0, 0, -0.08) * U.AxisZ, EYE)
	-- glowing runes orbiting (kept off the face)
	for i = 0, 4 do
		local a = math.rad(70 + i * 55)
		k.block(v(0.32, 0.32, 0.32), CFrame.Angles(0, a, 0) * at(0, 0.8 - (i % 2) * 1.3, -3.2) * U.VertexUp, k.glow, NEON)
	end
	-- two loose pages fluttering off
	k.block(v(0.9, 1.1, 0.04), at(-2.9, 1.6, 0.6) * CFrame.Angles(0.3, 0.6, 0.4), CREAM)
	k.block(v(0.9, 1.1, 0.04), at(2.8, 2.0, 1.0) * CFrame.Angles(-0.2, -0.5, -0.3), CREAM)
end

------------------------------------------------------------------ (cut) Upside-Down Manor: area removed, styles kept for reuse
S.Dizzy = function(k)
	-- built normally and flipped by GhostRig (tail up); spiral eyes are drawn by GhostRig.
	-- Three little stars circle its (now downward) head; a wisp curl tops the upturned tail.
	local star = Color3.fromRGB(255, 230, 90)
	for i = 0, 2 do
		local a = i * 2.1 + 0.4
		star4(k, v(math.cos(a) * 1.6, 2.2 + (i % 2) * 0.3, math.sin(a) * 1.35 + 0.1), v(math.cos(a), 0, math.sin(a) - 0.6), 0.85, star, nil, 0.3 * i)
	end
	k.ball(0.6, at(0.4, -3.05, 2.15), k.color)
	k.ball(0.35, at(0.7, -3.3, 2.0), k.color)
end

S.Chandelier = function(k)
	-- a chandelier for a hat: brass plate, centre post and loop, six candles with small flames,
	-- crystal drops hanging under the rim
	local base = at(0, 1.72, 0.1)
	k.cyl(0.2, 3.0, base * U.AxisY, BRASS, METAL)
	k.cyl(0.95, 0.24, base * at(0, 0.55, 0) * U.AxisY, BRASS, METAL)
	k.ball(0.42, base * at(0, 1.05, 0), BRASS, METAL)
	k.cyl(0.1, 0.5, base * at(0, 1.4, 0) * U.AxisZ, BRASS, METAL)
	local crystal = Color3.fromRGB(215, 235, 255)
	for i = 0, 5 do
		local rot = base * CFrame.Angles(0, i * math.pi / 3 + math.pi / 6, 0)
		k.cyl(0.12, 0.42, rot * at(0, 0.14, -1.22) * U.AxisY, BRASS, METAL) -- cup
		k.cyl(0.5, 0.24, rot * at(0, 0.45, -1.22) * U.AxisY, CREAM)
		k.ball(0.24, rot * at(0, 0.82, -1.22), k.glow, NEON)
		k.ball(0.3, rot * CFrame.Angles(0, math.pi / 6, 0) * at(0, -0.32, -1.42), crystal, { Reflectance = 0.4 })
	end
end

S.Topsy = function(k)
	-- grand countess built normally and flipped by GhostRig: her ball-gown skirt billows up over
	-- her, pearl necklace, folding fan in one hand, hair bun and tiny tiara on her (downward) head
	local gown = U.Mix(k.color, Color3.fromRGB(120, 40, 145), 0.55)
	local gown2 = U.Shade(gown, 0.78)
	k.cone(at(0, -4.0, 0.35), 5.4, 2.9, 5, gown2, gown)
	for i = 0, 9 do
		local a = i * math.pi / 5
		k.ball(0.5, at(math.sin(a) * 2.65, -3.95, 0.35 - math.cos(a) * 2.65), WHITE)
	end
	k.ruff(-1.05, 10, 0.32, WHITE, CREAM) -- pearls
	-- hair bun + tiara
	local hair = Color3.fromRGB(55, 30, 70)
	k.ball(2.75, at(0, 0.95, 0.5), hair)
	k.ball(1.35, at(0, 2.25, 0.6), hair)
	k.cyl(0.18, 1.6, at(0, 1.72, -0.15) * CFrame.Angles(-0.35, 0, 0) * U.AxisY, GOLD, METAL)
	for _, x in { -0.45, 0, 0.45 } do
		k.wedge(v(0.18, if x == 0 then 0.5 else 0.35, 0.25), at(x, 1.97 - math.abs(x) * 0.25, -0.38 - math.abs(x) * 0.1) * CFrame.Angles(-0.35, 0, 0), GOLD, METAL)
	end
	k.block(v(0.22, 0.22, 0.22), at(0, 2.12, -0.5) * U.VertexUp, k.glow, NEON)
	for _, s in { -1, 1 } do
		k.brow(s, 0.98, false, hair, 0.55)
	end
	-- folding fan in the right nub
	local hand = v(1.95, -0.35, -0.45)
	k.ball(0.22, CFrame.new(hand), GOLD, METAL)
	for i = -2, 2 do
		local t = i * 0.38
		local cf = CFrame.new(hand) * CFrame.Angles(0, 0.35, 0) * CFrame.Angles(0, 0, t) * at(0, 0.55, 0)
		k.block(v(0.36, 1.1, 0.05), cf, if i % 2 == 0 then WHITE else U.Vivid(k.glow))
	end
end

------------------------------------------------------------------ 20 Glowshroom Forest
S.Spore = function(k)
	-- tiny glowing mushroom cap on the head and five spore dots floating round it
	shroom(k, at(0.15, 1.55, 0.1) * CFrame.Angles(0, 0, -0.15), 0.45, 1.85, k.accent, WHITE, CREAM)
	for i = 0, 4 do
		local a = math.rad(60 + i * 60)
		k.ball(0.24, CFrame.Angles(0, a, 0) * at(0, -0.8 + (i % 3) * 0.85, -2.45), k.glow, NEON)
	end
end

S.Moss = function(k)
	-- moss patches on the body, two little shrooms on the shoulders and a leaf on top
	local moss = Color3.fromRGB(45, 105, 45)
	local moss2 = Color3.fromRGB(75, 140, 50)
	for i, d in { v(-1, 0.8, -0.4), v(1.1, -0.9, -0.6), v(-0.7, -1.0, 0.9), v(0.9, 0.55, 1.0), v(-1.3, -0.5, -0.3) } do
		local c = if i % 2 == 0 then moss else moss2
		patch(k, d, 1.15, c)
		k.ball(0.45, CFrame.new(k.surf(d, 0.05) + v(0.15, 0.12, 0)), c)
	end
	local cap = Color3.fromRGB(205, 85, 60)
	for _, s in { -1, 1 } do
		shroom(k, at(1.2 * s, 1.0, 0.35) * CFrame.Angles(0, 0, -0.4 * s), 0.38, 0.85, cap, WHITE, CREAM)
	end
	local leaf = Color3.fromRGB(95, 190, 80)
	local base = v(0.05, 1.7, 0.1)
	local dir = v(-0.9, 0.75, 0.2).Unit
	k.rod(base, base + v(0, 0.4, 0), 0.1, Color3.fromRGB(110, 80, 50))
	blade(k, base + v(0, 0.35, 0), dir, v(0, 1, 0.3), 0.9, 1.35, 0.08, leaf)
	blade(k, base + v(0, 0.35, 0), -dir, v(0, 1, 0.3), 0.9, 0.35, 0.08, leaf)
end

S.Mycelium = function(k)
	-- huge spotted toadstool cap for a crown (flat brim + dome + gills underneath), shoulder
	-- shrooms, root tendrils hanging below the tail with glowing tips, drifting spores
	local cap = Color3.fromRGB(85, 70, 165)
	local gill = Color3.fromRGB(230, 222, 205)
	local base = at(0, 1.5, 0.15)
	k.cyl(0.12, 4.2, base * at(0, -0.2, 0) * U.AxisY, gill)
	k.cyl(0.35, 4.7, base * U.AxisY, cap)
	k.ball(3.4, base * at(0, 0.2, 0.05), cap)
	local dome = base * v(0, 0.2, 0.05)
	for _, d in { v(0, 1, 0), v(0.75, 0.6, -0.3), v(-0.7, 0.6, -0.35), v(0.1, 0.55, -0.85), v(0.8, 0.55, 0.45), v(-0.75, 0.55, 0.5), v(0, 0.6, 0.85) } do
		k.ball(0.55, CFrame.new(dome + d.Unit * 1.62), WHITE)
	end
	for _, s in { -1, 1 } do
		k.brow(s, 1.0, true, Color3.fromRGB(35, 70, 70), 0.7)
		shroom(k, at(1.55 * s, 0.25, 0.35) * CFrame.Angles(0, 0, -0.6 * s), 0.4, 0.8, U.Vivid(k.glow), nil, gill)
	end
	-- root tendrils
	local root = Color3.fromRGB(200, 215, 200)
	for i, o in { v(-0.55, 0, -0.2), v(0.55, 0, -0.25), v(-0.3, 0, 0.35), v(0.5, 0, 0.3) } do
		local a = v(0.2, -2.75, 1.85) + o
		local b = a + v(o.X * 1.2, -0.75, o.Z * 1.5)
		local c = b + v(-o.X * 0.6, -0.65 - (i % 2) * 0.3, 0.2)
		k.rod(a, b, 0.2, root)
		k.rod(b, c, 0.16, root)
		k.ball(0.24, CFrame.new(c), k.glow, NEON)
	end
	for i = 0, 3 do
		local a = math.rad(75 + i * 70)
		k.ball(0.22, CFrame.Angles(0, a, 0) * at(0, 1.2 - (i % 2) * 1.6, -3.0), k.glow, NEON)
	end
end

------------------------------------------------------------------ 22 Mirror Maze
S.Glint = function(k)
	-- shiny body (GhostRig adds Reflectance), diamond facet tiles on the cheeks, a gem on top
	-- and 4-point star glints popping around it
	local facet = Color3.fromRGB(190, 225, 255)
	for _, s in { -1, 1 } do
		for _, f in { { d = v(1.0 * s, -0.12, -1.45), w = 0.46 }, { d = v(1.25 * s, 0.25, -1.15), w = 0.32 } } do
			local p = k.surf(f.d, 0.0)
			k.block(v(f.w, f.w, 0.1), U.Facing(p, f.d) * CFrame.Angles(0, 0, math.pi / 4), facet, { Reflectance = 0.5 })
		end
	end
	k.block(v(0.75, 0.75, 0.75), at(0, 2.05, 0.1) * U.VertexUp, facet, { Reflectance = 0.5 })
	for i, p in { v(-2.45, 1.3, -0.5), v(2.4, 1.65, -0.2), v(-2.0, -1.4, -0.8), v(2.25, -1.0, 0.7) } do
		sparkle(k, p, if i % 2 == 0 then 0.8 else 0.6, k.glow, NEON, i * 0.2)
	end
end

S.Copycat = function(k)
	-- two-tone: right half in the mirror colour, and a mini reflection ghost orbiting it
	local mirror = Color3.fromRGB(255, 185, 225)
	rightHalf(k, mirror, 0.06)
	local mp = v(-2.75, 1.05, -0.55)
	k.ball(1.3, CFrame.new(mp), k.color)
	k.ball(0.75, CFrame.new(mp + v(0.1, -0.6, 0.3)), k.color)
	for _, s in { -1, 1 } do
		k.ball(0.32, CFrame.new(mp + v(0.22 * s, 0.1, -0.52)), EYE)
	end
	k.cyl(0.1, 0.22, U.DiscFacing(mp + v(0, -0.2, -0.62), v(0, 0, -1)), Color3.fromRGB(70, 20, 50))
end

S.MirrorQueen = function(k)
	-- tall oval magic mirror behind her (gold beads round a reflective oval), a crown of mirror
	-- shards, a high collar, a gem necklace and a stern brow
	local glass = { Reflectance = 0.6 }
	local mirrorC = Color3.fromRGB(185, 205, 235)
	local c = v(0, 0.75, 2.3)
	for _, h in { -0.65, 0.65 } do
		k.cyl(0.12, 4.3, CFrame.new(c + v(0, h, 0)) * U.AxisZ, mirrorC, glass)
	end
	k.block(v(4.3, 1.3, 0.12), CFrame.new(c), mirrorC, glass)
	for i = 0, 19 do
		local a = i * math.pi / 10
		k.ball(0.55, CFrame.new(c + v(math.sin(a) * 2.3, math.cos(a) * 2.95, 0.05)), GOLD, METAL)
	end
	k.point(c + v(0, 3.1, 0.05), v(0, 1, 0.01), 0.7, 0.8, 0.2, GOLD, METAL)
	k.block(v(0.36, 0.36, 0.36), CFrame.new(c + v(0, 3.25, -0.12)) * U.VertexUp, k.glow, NEON)
	-- crown of mirror shards
	k.ring(1.2, 0.3, GOLD, METAL)
	local shard = Color3.fromRGB(215, 230, 250)
	for i = -2, 2 do
		local rot = CFrame.Angles(0, i * 0.5, 0)
		blade(k, rot * v(0, 1.3, -1.02), rot * v(0, 1, -0.15), rot * v(0, 0, -1), 0.42, 0.95 - math.abs(i) * 0.17, 0.12, shard, { Reflectance = 0.5 })
	end
	-- high collar fanned behind the head
	local collar = Color3.fromRGB(95, 45, 125)
	for i = -2, 2 do
		local cf = CFrame.Angles(0, i * 0.45, 0) * at(0, 0.0, 1.65) * CFrame.Angles(0.45, 0, 0)
		k.block(v(0.75, 1.7, 0.12), cf, collar)
	end
	k.ring(-0.95, 0.28, GOLD, METAL)
	k.block(v(0.36, 0.36, 0.36), CFrame.new(k.surf(v(0, -1.0, -1.4), 0.1)) * U.VertexUp, k.glow, NEON)
	for _, s in { -1, 1 } do
		k.brow(s, 0.98, true, Color3.fromRGB(70, 60, 110), 0.65)
	end
end

------------------------------------------------------------------ 24 Ghost Subway
S.Commuter = function(k)
	-- tired office ghost: droopy eyelids, shirt collar and necktie, briefcase in one nub, a
	-- coffee cup floating by the other
	local lid = U.Shade(k.color, 0.9)
	for _, s in { -1, 1 } do
		k.ball(0.95, CFrame.new(v(0.6 * s, 0.52, -1.4)), lid)
		local cp = k.surf(v(0.3 * s, -0.95, -1.4), 0.02)
		k.wedge(v(0.1, 0.32, 0.4), U.Facing(cp, cp) * CFrame.Angles(0, 0, 0.6 * s) * CFrame.Angles(0, math.pi / 2, 0), WHITE)
	end
	local tie = Color3.fromRGB(60, 90, 170)
	local kp = k.surf(v(0, -0.95, -1.45), 0.08)
	k.block(v(0.3, 0.26, 0.14), U.Facing(kp, kp), tie)
	k.point(kp + v(0, -0.12, -0.04), v(0, -1, -0.45), 0.45, 1.05, 0.1, tie)
	-- briefcase from the right nub
	local brown = Color3.fromRGB(120, 75, 45)
	k.block(v(0.5, 0.12, 0.12), at(2.0, -0.85, -0.3), U.Shade(brown, 0.7))
	k.block(v(1.05, 0.78, 0.34), at(2.0, -1.35, -0.3), brown)
	k.block(v(0.22, 0.14, 0.06), at(2.0, -1.12, -0.48), GOLD, METAL)
	-- coffee cup floating by the left nub
	local cup = v(-2.55, 0.25, -0.65)
	k.cyl(0.72, 0.56, CFrame.new(cup) * U.AxisY, WHITE)
	k.cyl(0.28, 0.6, CFrame.new(cup + v(0, -0.02, 0)) * U.AxisY, Color3.fromRGB(150, 100, 60))
	k.cyl(0.12, 0.62, CFrame.new(cup + v(0, 0.4, 0)) * U.AxisY, Color3.fromRGB(55, 45, 50))
	k.ball(0.35, CFrame.new(cup + v(0.05, 0.75, 0.05)), Color3.fromRGB(240, 245, 255))
end

S.Ticket = function(k)
	-- conductor cap with a gold badge, ticket punch in one nub, three tickets fluttering round
	local navy = Color3.fromRGB(45, 55, 105)
	k.cyl(0.55, 1.95, at(0, 1.55, 0.1) * U.AxisY, navy)
	k.cyl(0.14, 2.15, at(0, 1.86, 0.1) * U.AxisY, navy)
	k.block(v(1.5, 0.12, 0.65), at(0, 1.32, -0.95) * CFrame.Angles(0.2, 0, 0), U.Shade(navy, 0.7))
	k.block(v(0.42, 0.3, 0.08), at(0, 1.6, -0.9), GOLD, METAL)
	-- ticket punch
	local hand = v(1.95, -0.35, -0.45)
	for _, s in { -1, 1 } do
		k.block(v(0.14, 0.75, 0.14), CFrame.new(hand + v(0, -0.25, 0)) * CFrame.Angles(0, 0, 0.25 * s), SILVER, METAL)
	end
	k.block(v(0.42, 0.28, 0.3), CFrame.new(hand + v(0, 0.2, 0)), SILVER, METAL)
	-- tickets
	for i, a in { 75, 190, 285 } do
		local r = math.rad(a)
		local cf = CFrame.Angles(0, r, 0) * at(0, 1.2 - i * 0.6, -2.55) * CFrame.Angles(0.25, 0, 0.35 * (i - 2))
		k.block(v(1.1, 0.55, 0.04), cf, CREAM)
		k.block(v(1.1, 0.14, 0.05), cf * at(0, 0.14, 0), U.Vivid(k.glow))
	end
end

S.Locomotive = function(k)
	-- the ghost is the front of a train engine: boiler round its back with the face as the front
	-- plate, smokebox rim, cab, wheels, cow-catcher, headlight, bell and a smokestack puffing
	-- little ghost-shaped smoke clouds
	local body = k.color
	local dark = Color3.fromRGB(35, 35, 50)
	local trim = Color3.fromRGB(200, 60, 55)
	k.cyl(3.4, 3.4, at(0, 0.1, 1.3) * U.AxisZ, body)
	k.cyl(0.3, 3.65, at(0, 0.1, -0.3) * U.AxisZ, dark, METAL)
	for _, z in { 0.9, 2.1 } do
		k.cyl(0.18, 3.5, at(0, 0.1, z) * U.AxisZ, GOLD, METAL)
	end
	k.block(v(3.5, 3.0, 1.5), at(0, 0.55, 3.55), trim)
	k.block(v(3.8, 0.25, 1.9), at(0, 2.15, 3.55), dark)
	for _, s in { -1, 1 } do
		k.block(v(0.08, 0.8, 0.8), at(1.76 * s, 1.0, 3.55), CREAM)
		for _, z in { 0.3, 1.8, 3.2 } do
			k.cyl(0.3, 1.35, at(1.6 * s, -1.4, z), trim)
		end
		k.block(v(0.12, 0.15, 3.1), at(1.8 * s, -1.4, 1.75), SILVER, METAL) -- coupling rod
	end
	-- cow-catcher
	for _, x in { -1.0, 0, 1.0 } do
		k.wedge(v(0.95, 0.95, 1.1), at(x, -1.65, -0.95), dark, METAL)
	end
	-- headlight, bell, smokestack
	k.cyl(0.6, 0.95, at(0, 1.85, -0.35) * U.AxisZ, dark, METAL)
	k.cyl(0.08, 0.7, at(0, 1.85, -0.68) * U.AxisZ, k.glow, NEON)
	k.ball(0.55, at(0, 1.95, 1.4), GOLD, METAL)
	k.cyl(1.0, 0.75, at(0, 2.2, 0.55) * U.AxisY, dark)
	k.cyl(0.35, 1.15, at(0, 2.8, 0.55) * U.AxisY, dark)
	local smoke = Color3.fromRGB(235, 235, 245)
	for i = 1, 3 do
		local p = v(0.15 * i, 2.9 + i * 0.7, 0.75 + i * 0.75)
		local d = 0.55 + i * 0.25
		k.ball(d, CFrame.new(p), smoke)
		if i == 3 then
			for _, s in { -1, 1 } do
				k.ball(0.18, CFrame.new(p + v(0.18 * s, 0.1, -d * 0.45)), EYE)
			end
		end
	end
	for _, s in { -1, 1 } do
		k.brow(s, 0.98, false, dark, 0.6)
	end
end

------------------------------------------------------------------ 27 Neon Ghost City
S.NeonSign = function(k)
	-- outlined by a thin neon-tube halo, with a little neon arrow sign floating beside it
	arc(k, at(0, 0.0, 0.35), 2.5, 0, 2 * math.pi, 14, 0.16, k.glow, NEON)
	local cyan = Color3.fromRGB(110, 235, 255)
	local sf = at(3.15, 1.35, -0.2) * CFrame.Angles(0, -0.35, 0)
	k.block(v(1.6, 0.8, 0.12), sf, Color3.fromRGB(40, 30, 60))
	k.block(v(0.75, 0.14, 0.06), sf * at(0.22, 0, -0.08), cyan, NEON)
	blade(k, sf * v(-0.12, 0, -0.08), -sf.RightVector, -sf.LookVector, 0.5, 0.45, 0.06, cyan, NEON)
	k.rod((sf * v(0, 0.4, 0)), (sf * v(0, 0.4, 0)) + v(0, 0.9, 0), 0.05, STEEL)
end

S.Graffiti = function(k)
	-- backwards cap, paint splats, a spray can in one nub and a drippy paint tag on the tail
	local capC = Color3.fromRGB(255, 125, 60)
	k.ball(2.45, at(0, 1.15, 0.15), capC)
	k.block(v(1.35, 0.12, 1.05), at(0, 1.55, 1.6) * CFrame.Angles(-0.25, 0, 0), U.Shade(capC, 0.8))
	k.ball(0.28, at(0, 2.38, 0.15), U.Shade(capC, 0.8))
	local paints = { Color3.fromRGB(255, 80, 170), Color3.fromRGB(255, 225, 60), Color3.fromRGB(70, 200, 255), U.Vivid(k.glow), Color3.fromRGB(170, 90, 255) }
	for i, d in { v(1, 0.15, -0.2), v(0.6, -0.9, -0.5), v(-0.8, 0.75, -0.45), v(0.85, 0.75, 0.6), v(0.15, -0.4, 1), v(-1, 0.25, 0.4) } do
		patch(k, d, 0.8 + (i % 3) * 0.2, paints[(i - 1) % 5 + 1], 0.09)
	end
	-- spray can
	local can = v(2.05, -0.05, -0.45)
	k.cyl(0.9, 0.46, CFrame.new(can) * U.AxisY, Color3.fromRGB(70, 200, 255))
	k.cyl(0.2, 0.36, CFrame.new(can + v(0, 0.55, 0)) * U.AxisY, WHITE)
	k.block(v(0.1, 0.1, 0.18), CFrame.new(can + v(0, 0.65, -0.18)), EYE)
	-- paint tag on the tail: a zig-zag scrawl with two drips
	local tag = U.Vivid(k.glow)
	local o = v(1.1, -1.75, 0.95)
	zigzag(k, { o + v(0, 0.3, -0.45), o + v(0.08, -0.15, -0.15), o + v(0.08, 0.25, 0.15), o + v(0, -0.2, 0.45) }, 0.13, tag, nil, v(1, 0, 0))
	for _, z in { -0.15, 0.45 } do
		k.cyl(0.45, 0.09, CFrame.new(o + v(0.02, -0.5, z)) * U.AxisY, tag)
	end
end

S.Billboard = function(k)
	-- a giant screen for a face (GhostRig draws no face): pixel eyes and pixel smile, satellite
	-- dish and neon antenna on top, cables hanging below
	local frameC = Color3.fromRGB(45, 45, 62)
	local screen = Color3.fromRGB(18, 26, 45)
	local fc = at(0, 0.15, -1.6)
	k.block(v(3.9, 3.0, 0.5), fc, frameC, METAL)
	k.block(v(3.5, 2.6, 0.1), fc * at(0, 0, -0.27), screen)
	for _, s in { -1, 1 } do
		k.block(v(0.62, 0.62, 0.06), fc * at(0.8 * s, 0.4, -0.34), k.glow, NEON)
		k.block(v(0.22, 0.22, 0.06), fc * at(0.8 * s + 0.13, 0.53, -0.37), WHITE)
		k.ball(0.25, fc * at(1.7 * s, 1.25, -0.2), SILVER, METAL)
		k.ball(0.25, fc * at(1.7 * s, -1.25, -0.2), SILVER, METAL)
	end
	for i, p in { { -0.9, -0.3 }, { -0.5, -0.6 }, { 0, -0.68 }, { 0.5, -0.6 }, { 0.9, -0.3 } } do
		k.block(v(if i == 3 then 0.5 else 0.36, 0.3, 0.06), fc * at(p[1], p[2], -0.34), U.Vivid(k.glow))
	end
	k.ball(0.2, fc * at(-1.45, 1.05, -0.34), Color3.fromRGB(255, 70, 70)) -- "on air" dot
	-- satellite dish
	local post = v(0.75, 1.5, 0.35)
	k.rod(post, post + v(0.1, 0.9, 0), 0.14, SILVER, METAL)
	local dish = CFrame.new(post + v(0.1, 1.1, 0)) * CFrame.Angles(-0.7, 0.4, 0)
	k.cyl(0.12, 1.5, dish * U.AxisZ, Color3.fromRGB(220, 225, 235))
	k.rod((dish * v(0, 0, -0.06)), (dish * v(0, 0, -0.6)), 0.07, SILVER)
	k.ball(0.18, dish * at(0, 0, -0.62), SILVER, METAL)
	-- neon antenna
	local ab = v(-0.75, 1.5, 0.3)
	k.rod(ab, ab + v(-0.25, 1.5, 0.15), 0.07, SILVER, METAL)
	k.ball(0.3, CFrame.new(ab + v(-0.27, 1.6, 0.16)), k.glow, NEON)
	-- dangling cables
	local cableC = { Color3.fromRGB(30, 30, 40), Color3.fromRGB(200, 60, 60), Color3.fromRGB(240, 200, 60) }
	for i, x in { -0.9, 0.0, 0.85 } do
		local a = v(x, -1.3, -1.45)
		local b = a + v(x * 0.25, -0.9, 0.15)
		local c = b + v(-x * 0.2, -0.6 - i * 0.15, -0.1)
		k.rod(a, b, 0.11, cableC[i])
		k.rod(b, c, 0.11, cableC[i])
		k.block(v(0.22, 0.3, 0.22), CFrame.new(c), cableC[i])
	end
end

------------------------------------------------------------------ 30 Storm Sky Islands
S.Breeze = function(k)
	-- two tilted wind-swirl rings and little wind puffs trailing from the tail
	local wind = Color3.fromRGB(205, 238, 255)
	local r1 = at(0, 1.25, 0.15) * CFrame.Angles(0, 0, 0.4) * CFrame.Angles(math.pi / 2, 0, 0)
	arc(k, r1, 2.05, 0.3, 5.6, 9, 0.13, wind)
	k.ball(0.32, r1 * CFrame.Angles(0, 0, 5.6) * at(2.05, 0, 0), wind)
	arc(k, at(0, -1.3, 0.35) * CFrame.Angles(0, 0, -0.35) * CFrame.Angles(math.pi / 2, 0, 0), 2.0, 2.0, 7.2, 9, 0.12, U.Vivid(k.glow))
	local puff = Color3.fromRGB(240, 250, 255)
	for i = 1, 3 do
		k.ball(0.8 - i * 0.14, at(0.25 + i * 0.12, -2.85 - i * 0.12, 1.9 + i * 0.6), puff)
	end
	k.ball(0.6, at(0.1, 1.85, 0.1), k.color)
	k.ball(0.35, at(0.38, 2.12, 0.25), k.color)
end

S.Thundercloud = function(k)
	-- grumpy ghost under a fluffy grey cloud, two neon lightning bolts hanging from its edges
	local cloud = Color3.fromRGB(175, 180, 200)
	local cloud2 = Color3.fromRGB(150, 155, 178)
	k.ball(1.7, at(0, 2.05, 0.2), cloud)
	k.ball(1.35, at(-1.15, 1.75, 0.25), cloud2)
	k.ball(1.35, at(1.15, 1.75, 0.25), cloud2)
	k.ball(1.25, at(-0.45, 2.35, 0.75), cloud)
	k.ball(1.15, at(0.55, 2.4, -0.1), cloud)
	for _, s in { -1, 1 } do
		local x = 1.75 * s
		zigzag(k, { v(x, 1.25, 0), v(x + 0.4 * s, 0.6, -0.1), v(x + 0.05 * s, 0.15, -0.15), v(x + 0.45 * s, -0.55, -0.2) }, 0.2, k.glow, NEON)
		k.brow(s, 1.0, true, Color3.fromRGB(70, 75, 100), 0.6)
	end
	local drop = Color3.fromRGB(120, 180, 255)
	k.ball(0.22, at(-0.6, -2.0, -1.3), drop)
	k.ball(0.18, at(0.9, -2.5, -0.9), drop)
end

S.StormRoc = function(k)
	-- giant storm bird: wide wedge-feather wings, open beak (replaces the mouth), crest feathers,
	-- tail fan and a lightning-bolt tail
	local c1 = U.Mix(k.color, WHITE, 0.12)
	local c2 = U.Shade(k.color, 0.78)
	local beak = Color3.fromRGB(255, 185, 60)
	local bolt = U.Vivid(k.glow)
	for _, s in { -1, 1 } do
		local root = v(1.35 * s, 0.45, 0.8)
		k.ball(1.2, CFrame.new(root), c2)
		for j, f in { { 0.62, 2.7 }, { 0.36, 3.2 }, { 0.1, 3.35 }, { -0.16, 3.0 }, { -0.42, 2.45 } } do
			local th, len = f[1], f[2]
			local dir = v(s * math.cos(th), math.sin(th), 0.25).Unit
			local col = if j == 1 then U.Mix(c1, WHITE, 0.3) elseif j % 2 == 0 then c2 else c1
			local fcf = CFrame.lookAt(root + dir * (len / 2), root + dir * len)
			k.block(v(0.16, 0.8, len * 0.6), fcf * at(0, -0.1, len * 0.2), col)
			k.wedge(v(0.16, 0.8, len * 0.4 + 0.02), fcf * at(0, -0.1, -len * 0.3), col)
		end
		k.brow(s, 1.0, true, Color3.fromRGB(40, 45, 80), 0.72)
	end
	-- beak
	k.point(v(0, 0.02, -1.55), v(0, -0.3, -1), 0.62, 1.0, 0.55, beak)
	k.point(v(0, -0.38, -1.45), v(0, -0.75, -1), 0.4, 0.62, 0.42, U.Shade(beak, 0.8))
	-- crest
	for i, x in { -0.35, 0, 0.35 } do
		local base = v(x, 1.55, 0.2)
		local dir = v(x * 0.6, 1, 0.75).Unit
		local len = if i == 2 then 1.7 else 1.35
		k.wedge(v(0.14, 0.6, len), CFrame.lookAt(base + dir * (len / 2), base + dir * len), if i == 2 then bolt else c1)
	end
	-- tail fan and lightning tail
	for _, a in { -0.5, 0, 0.5 } do
		local base = v(0.2, -2.6, 1.85)
		local dir = v(math.sin(a), -0.45, 0.9).Unit
		k.wedge(v(0.14, 0.7, 1.6), CFrame.lookAt(base + dir * 0.8, base + dir * 1.6), c2)
	end
	local t0 = v(0.2, -2.9, 2.0)
	local pts = { t0, t0 + v(0.55, -0.6, 0.35), t0 + v(-0.05, -1.05, 0.65), t0 + v(0.5, -1.7, 1.0) }
	zigzag(k, pts, 0.3, bolt)
	k.point(pts[4], v(-0.4, -1, 0.4), 0.42, 0.65, 0.25, bolt)
end

------------------------------------------------------------------ 31 Haunted Moon Base
S.Moondust = function(k)
	-- pale moon ghost with craters and three tiny moon rocks orbiting it
	local crater = U.Shade(k.color, 0.6)
	local rim = U.Shade(k.color, 0.84)
	for i, d in { v(0.9, 0.75, -0.25), v(0.25, 1, -0.2), v(1, -0.1, 0.55), v(-0.55, 0.95, -0.2), v(-0.6, -0.9, 1), v(0.5, -1, -0.6) } do
		local sz = 0.55 + (i % 3) * 0.2
		patch(k, d, sz + 0.25, rim, 0.05)
		patch(k, d, sz, crater, 0.07)
	end
	local rock = Color3.fromRGB(150, 150, 160)
	for i, p in { v(-2.6, 0.9, -0.3), v(2.5, 0.2, 0.6), v(1.6, 1.8, -1.6) } do
		k.block(v(0.5, 0.42, 0.45) * (1 - i * 0.12), CFrame.new(p) * CFrame.Angles(i, i * 0.7, 0.4), rock)
	end
end

S.Astronaut = function(k)
	-- glass helmet bubble with a white collar ring, oxygen pack and a little orange flag
	k.ball(4.5, at(0, 0.15, -0.05), Color3.fromRGB(200, 230, 255), { Transparency = 0.6, Reflectance = 0.2, Shadow = false })
	k.cyl(0.3, 2.5, at(0, -2.05, 0.1) * U.AxisY, WHITE)
	local pack = Color3.fromRGB(225, 228, 235)
	k.block(v(2.0, 2.1, 0.8), at(0, -0.05, 2.55), pack)
	for _, s in { -1, 1 } do
		k.cyl(1.9, 0.55, at(0.65 * s, -0.05, 3.05) * U.AxisY, U.Vivid(k.glow))
	end
	k.ball(0.2, at(-0.6, 0.65, 2.12), Color3.fromRGB(90, 255, 140), NEON)
	local ab = v(0.7, 1.0, 2.6)
	k.rod(ab, ab + v(0, 2.3, 0), 0.08, SILVER, METAL)
	k.block(v(0.9, 0.55, 0.05), CFrame.new(ab + v(0.47, 1.95, 0)), U.Vivid(k.glow))
	k.ball(0.2, CFrame.new(ab + v(0, 2.35, 0)), SILVER, METAL)
end

S.Saucer = function(k)
	-- ghost riding a flying saucer: wide disc round its middle with small rim lights, glass dome,
	-- faint tractor beam below
	local hull = Color3.fromRGB(170, 180, 198)
	k.cyl(0.45, 6.6, at(0, -1.2, 0.1) * U.AxisY, hull, METAL)
	k.cyl(0.2, 6.8, at(0, -1.2, 0.1) * U.AxisY, U.Vivid(k.glow))
	k.cyl(0.4, 4.6, at(0, -1.6, 0.1) * U.AxisY, U.Shade(hull, 0.75), METAL)
	k.cyl(0.3, 2.6, at(0, -1.9, 0.1) * U.AxisY, U.Shade(hull, 0.6), METAL)
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		k.ball(0.32, at(math.sin(a) * 3.05, -0.98, 0.1 - math.cos(a) * 3.05), k.glow, NEON)
	end
	k.ball(4.3, at(0, 0.15, 0.1), Color3.fromRGB(190, 240, 255), { Transparency = 0.65, Reflectance = 0.25, Shadow = false })
	-- little antennae
	for _, s in { -1, 1 } do
		k.rod(v(0.45 * s, 1.55, 0.1), v(0.75 * s, 1.95, 0.0), 0.07, SILVER)
		k.ball(0.22, at(0.77 * s, 1.98, 0.0), k.glow, NEON)
		k.brow(s, 0.98, false, U.Shade(k.color, 0.5), 0.55)
	end
	-- tractor beam
	for i = 0, 2 do
		k.cyl(0.8, 1.6 + i * 0.8, at(0, -2.45 - i * 0.8, 0.1) * U.AxisY, k.glow, { Transparency = 0.85, Shadow = false })
	end
end

------------------------------------------------------------------ 32 The Void Throne
S.Mote = function(k)
	-- inky ghost with inverted colours (white eyes drawn by GhostRig), star specks on its body
	-- and a thin orbit ring with a tiny moon
	for _, d in { v(-0.9, 0.9, -0.6), v(1.0, -0.4, -0.9), v(-1.2, -0.6, 0.3), v(0.6, 1.2, 0.4), v(1.3, 0.3, 0.6), v(-0.3, -1, 1), v(-0.5, 0.1, 1.4) } do
		k.ball(0.17, CFrame.new(k.surf(d, 0.0)), WHITE, NEON)
	end
	local orbit = at(0, -0.1, 0.1) * CFrame.Angles(math.pi / 2 - 0.35, 0, 0.25)
	arc(k, orbit, 2.45, 0, 2 * math.pi, 14, 0.08, U.Vivid(k.glow))
	k.ball(0.35, orbit * CFrame.Angles(0, 0, 2.2) * at(2.45, 0, 0), WHITE)
end

S.Rift = function(k)
	-- cracked down the middle: neon rift lines over the head and below the grin, the two halves
	-- in slightly different shades, four dark shards drifting away from the crack
	rightHalf(k, U.Shade(k.color, 0.8), 0.05)
	local function crack(dirs: { Vector3 })
		local pts = {}
		for _, d in dirs do
			table.insert(pts, k.surf(d, 0.02))
		end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local mid = (a + b) / 2
			k.block(v(0.13, 0.08, (b - a).Magnitude + 0.06), CFrame.lookAt(mid, b, mid.Unit), k.glow, NEON)
		end
	end
	crack({ v(0.08, 0.6, 1), v(-0.06, 1, 0.3), v(0.08, 1, -0.4), v(-0.05, 0.75, -0.75), v(0.03, 0.55, -0.85) })
	crack({ v(0.02, -0.62, -0.8), v(-0.08, -0.85, -0.55), v(0.08, -1, -0.2), v(0, -0.9, 0.3) })
	local shard = Color3.fromRGB(35, 25, 60)
	for i, f in { { v(2.3, 1.3, 0.2), v(1, 0.6, 0) }, { v(-2.35, 1.0, 0.3), v(-1, 0.5, 0.1) }, { v(2.1, -1.0, 0.4), v(1, -0.4, 0.2) }, { v(-2.0, -1.2, 0.2), v(-1, -0.5, 0) } } do
		k.point(f[1], f[2], 0.55 - i * 0.04, 0.95, 0.22, shard)
		k.point(f[1], -f[2], 0.55 - i * 0.04, 0.45, 0.22, shard)
	end
end

S.Herald = function(k)
	-- tall horned hood, starfield cape with tiny star dots, silver collar with a star brooch and
	-- a long banner staff with a white star
	local hood = Color3.fromRGB(28, 22, 50)
	local bone = Color3.fromRGB(225, 220, 235)
	k.ball(3.25, at(0, 0.6, 0.42), hood)
	local tipDir = v(0, 1, 0.22)
	blade(k, v(0, 1.6, 0.45), tipDir, v(0, 0, -1), 2.5, 2.3, 1.2, hood)
	blade(k, v(0, 1.6, 0.45), tipDir, v(1, 0, 0), 2.2, 2.3, 1.2, hood)
	for _, s in { -1, 1 } do
		local a = v(1.15 * s, 1.55, 0.35)
		local b = v(1.85 * s, 2.25, 0.55)
		k.rod(a, b, 0.42, bone)
		k.point(b, v(0.2 * s, 1, 0.3), 0.36, 0.95, 0.34, bone)
		k.brow(s, 0.98, true, bone, 0.6)
	end
	-- starfield cape
	for i = -1, 1 do
		local cf = CFrame.Angles(0, i * 0.62, 0) * at(0, -0.55, 1.95) * CFrame.Angles(-0.2, 0, 0)
		k.block(v(1.9, 3.9, 0.16), cf, VOID)
		for j = 0, 2 do
			k.ball(0.14, cf * at(-0.6 + j * 0.6, 1.2 - ((j + i) % 3) * 1.0, -0.1), WHITE, NEON)
		end
	end
	k.ring(-0.85, 0.3, SILVER, METAL)
	local bp = k.surf(v(0, -0.9, -1.45), 0.08)
	k.block(v(0.36, 0.36, 0.36), CFrame.new(bp) * U.VertexUp, SILVER, METAL)
	-- banner staff
	local hand = v(1.85, -0.35, -0.3)
	local top = hand + v(0.25, 3.6, 0)
	k.rod(hand + v(-0.06, -1.3, 0), top, 0.2, STEEL, METAL)
	k.block(v(1.5, 0.16, 0.16), CFrame.new(top + v(0.6, -0.25, 0)), STEEL, METAL)
	k.block(v(0.4, 0.4, 0.4), CFrame.new(top + v(0, 0.3, 0)) * U.VertexUp, WHITE, NEON)
	local flag = CFrame.new(top + v(0.65, -1.15, 0))
	k.block(v(1.2, 1.7, 0.08), flag, VOID)
	vTri(k, (flag * v(0, -0.85, 0)), v(0, 0, -1), 1.2, 0.35, 0.08, VOID)
	star4(k, flag * v(0, 0.1, -0.06), v(0, 0, -1), 0.95, WHITE, nil, 0)
end

------------------------------------------------------------------ world boss
S.VoidEmperor = function(k)
	-- THE VOID EMPEROR: black and white with starlight. Pure black face with two white glowing
	-- eyes (GhostRig) and a wide white grin, a tall cracked-obsidian crown with seven star tips,
	-- a slowly turning white ring behind his head, a starfield cape and high collar, four huge
	-- floating shadow hands and a floating throne of black slabs.
	local obsidian = Color3.fromRGB(28, 22, 40)
	local crackC = Color3.fromRGB(160, 135, 215)
	local shadow = Color3.fromRGB(26, 20, 42)
	local glassy = { Reflectance = 0.2 }
	-- wide white crescent grin hugging the face, with three dark tooth gaps
	local pts = {}
	for i = 0, 6 do
		local t = -1 + i / 3
		table.insert(pts, k.surf(v(0.5 * t, -0.2 - 0.24 * (1 - t * t), -1), 0.02))
	end
	for i = 1, 6 do
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		local tm = -1 + (i - 0.5) / 3
		k.block(v(0.12 + 0.26 * (1 - tm * tm), 0.08, (b - a).Magnitude + 0.04), CFrame.lookAt(mid, b, mid.Unit), WHITE)
	end
	for _, i in { 3, 4, 5 } do
		local p = pts[i]
		k.block(v(0.42, 0.1, 0.05), CFrame.lookAt(p, pts[i + 1], p.Unit) * at(0, 0.01, 0), VOID)
	end
	-- crown: band + seven tall spikes with white star tips, a few pale cracks
	k.ring(1.15, 0.5, obsidian, glassy)
	local cc = v(0, 1.15, 0)
	for i = 0, 6 do
		local a = (i - 3) * 0.5
		local rot = CFrame.Angles(0, a, 0)
		local h = 2.3 - math.abs(i - 3) * 0.35
		local base = rot * v(0, 1.25, -1.0) + v(0, 0, 0.15)
		local dir = rot * v(0, 1, -0.12)
		local front = rot * v(0, 0, -1)
		blade(k, base, dir, front, 0.62, h, 0.28, obsidian, glassy)
		k.block(v(0.3, 0.3, 0.3), CFrame.new(base + dir.Unit * (h + 0.12)) * U.VertexUp, WHITE, NEON)
		if i % 2 == 1 then
			local g = CFrame.fromMatrix(base + dir.Unit * (h * 0.3) + front * 0.15, front, dir.Unit)
			k.block(v(0.05, h * 0.4, 0.07), g * CFrame.Angles(0.25, 0, 0), crackC)
		end
	end
	k.block(v(0.42, 0.42, 0.42), CFrame.new(cc + v(0, 0.05, -1.32)) * U.VertexUp, WHITE, NEON)
	-- halo ring behind the head
	arc(k, at(0, 1.5, 2.35), 2.95, 0, 2 * math.pi, 18, 0.28, WHITE)
	-- high collar and starfield cape
	for i = -2, 2 do
		local cf = CFrame.Angles(0, i * 0.42, 0) * at(0, 0.15, 1.7) * CFrame.Angles(0.5, 0, 0)
		k.wedge(v(0.7, 1.8, 0.35), cf * CFrame.Angles(0, math.pi, 0), obsidian, glassy)
	end
	for i = -2, 2 do
		local cf = CFrame.Angles(0, i * 0.36, 0) * at(0, -1.2, 2.25) * CFrame.Angles(-0.28, 0, 0)
		k.block(v(1.45, 4.2, 0.16), cf, VOID)
		k.block(v(1.47, 0.12, 0.2), cf * at(0, -2.08, 0), WHITE)
		if i ~= 0 then
			k.ball(0.15, cf * at(0.3 * i, 1.2 - math.abs(i) * 0.6, -0.1), WHITE, NEON)
			k.ball(0.12, cf * at(-0.2 * i, -0.6 + math.abs(i) * 0.3, -0.1), WHITE, NEON)
		end
	end
	-- shoulder plates
	for _, s in { -1, 1 } do
		k.ball(1.3, at(1.75 * s, 0.0, 0.05), obsidian, glassy)
		k.point(v(2.05 * s, 0.45, 0.05), v(0.45 * s, 1, 0), 0.4, 0.75, 0.32, obsidian, glassy)
	end
	-- four floating shadow hands (palm, wrist, four fingers and a thumb), reaching in from the sides
	for _, h in { { p = v(-3.3, 1.6, -0.7), s = -1, up = 1 }, { p = v(3.3, 1.6, -0.7), s = 1, up = 1 }, { p = v(-3.1, -1.75, -1.0), s = -1, up = -1 }, { p = v(3.1, -1.75, -1.0), s = 1, up = -1 } } do
		local palm = h.p
		k.ball(1.25, CFrame.new(palm), shadow)
		k.ball(0.8, CFrame.new(palm + v(0.6 * h.s, -0.55 * h.up, 0.35)), shadow)
		for f = 0, 3 do
			local t = (f - 1.5) * 0.32
			local dir = v(math.sin(t) + 0.15 * h.s, h.up * math.cos(t), -0.25).Unit
			k.rod(palm + dir * 0.35, palm + dir * (if f == 0 or f == 3 then 1.35 else 1.6), 0.3, shadow)
		end
		local td = v(-0.85 * h.s, 0.4 * h.up, -0.25).Unit
		k.rod(palm + td * 0.4, palm + td * 1.15, 0.32, shadow)
	end
	-- floating throne of black slabs: seat, tall back with two spires, arms, drifting broken bits
	k.block(v(4.8, 0.6, 3.6), at(0, -3.45, 0.9), VOID, glassy)
	k.block(v(4.9, 0.12, 0.12), at(0, -3.12, -0.9), WHITE)
	k.block(v(4.7, 6.3, 0.55), at(0, -0.25, 3.4), VOID, glassy)
	k.block(v(4.75, 0.14, 0.14), at(0, 2.9, 3.1), WHITE)
	for _, s in { -1, 1 } do
		blade(k, v(2.05 * s, 2.85, 3.4), v(0, 1, 0), v(0, 0, -1), 0.65, 1.3, 0.5, VOID, glassy)
		k.block(v(0.22, 0.22, 0.22), at(2.05 * s, 4.25, 3.4) * U.VertexUp, WHITE)
		k.block(v(0.6, 0.85, 3.0), at(2.65 * s, -2.75, 0.9), VOID, glassy)
		k.block(v(0.8, 0.5, 0.7), at(2.9 * s, -4.4, 0.2) * CFrame.Angles(0.3, 0.5 * s, 0.25 * s), VOID)
	end
	k.block(v(1.0, 0.45, 0.8), at(-0.9, -4.6, 2.2) * CFrame.Angles(-0.3, 0.4, 0.2), VOID)
end

World2.Styles = S
-- shared shape helpers (used by World2b.luau, the looks of the areas added in the 16-area World 2)
World2.Help = { arc = arc, zigzag = zigzag, blade = blade, star4 = star4, patch = patch, sparkle = sparkle }

return World2
