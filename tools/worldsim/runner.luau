--[[
	Headless world smoke test. Loaded by tools/worldsim.sh after prelude.luau has set up the
	mock engine and mounted the real modules (src/shared -> ReplicatedStorage.GH,
	src/server/World -> ServerScriptService.GHServer.World).

	1. Builder.Build() for the whole map: totals + per top-level Map folder, Kit budget refusals.
	2. Ghost areas: nothing visible/solid standing inside a circle (Y 0.3..40).
	3. Fast Travel arrival points: clear r=4 and solid ground underneath.
	4. Main route along X = 0 (and +-6): blockers, missing ground, detours, reachability.
	5. Every GhostRig / HunterRig (+BuildStatic, poses) / CrateRig builds with the expected parts.
]]

local VERBOSE = rawget(getfenv(1), "WORLDSIM_VERBOSE") == true
local MAX_LIST = 8

local errors = 0 -- runtime errors (things that would break the game)
local issues = 0 -- layout findings
local function fail(msg: string)
	errors += 1
	print("  ERROR " .. msg)
end
local function issue(msg: string)
	issues += 1
	print("  ISSUE " .. msg)
end
local function header(s: string)
	print("")
	print("== " .. s .. " " .. string.rep("=", math.max(0, 70 - #s)))
end
local function f1(n: number): string
	return string.format("%.1f", n)
end

local S = SIM.State
local function cls(o): string
	return S[o].Class
end

local GH = SIM.Path("ReplicatedStorage.GH")
local WorldFolder = SIM.Path("ServerScriptService.GHServer.World")
local Config = require(GH.Config)

--==================================================================
-- 0. mock self-test (guards the CFrame maths the layout checks rely on)
--==================================================================
do
	local function near(a, b)
		return (a - b).Magnitude < 1e-6
	end
	local r = CFrame.Angles(0, math.pi / 2, 0)
	assert(near(r * Vector3.new(1, 0, 0), Vector3.new(0, 0, -1)), "Angles Y")
	assert(near(CFrame.Angles(0, 0, math.pi / 2) * Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)), "Angles Z")
	assert(near(CFrame.Angles(math.pi / 2, 0, 0) * Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)), "Angles X")
	local c = CFrame.new(3, 4, 5) * CFrame.Angles(0.3, -1.1, 0.7)
	assert((c * c:Inverse()):FuzzyEq(CFrame.identity), "Inverse")
	assert(near(c:ToObjectSpace(c * CFrame.new(1, 2, 3)).Position, Vector3.new(1, 2, 3)), "ToObjectSpace")
	local l = CFrame.lookAt(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0))
	assert(near(l.LookVector, Vector3.new(1, 0, 0)) and near(l.UpVector, Vector3.new(0, 1, 0)), "lookAt")
	local x1, y1, _, x2, y2 = SIM.AABB(CFrame.Angles(0, 0, math.pi / 2), Vector3.new(4, 1, 2))
	assert(math.abs(x2 - x1 - 1) < 1e-6 and math.abs(y2 - y1 - 4) < 1e-6, "AABB")
end

--==================================================================
-- 1. Build the world
--==================================================================
header("1. Builder.Build()")
local okReq, Kit = pcall(require, WorldFolder.Kit)
if not okReq then
	fail("require Kit: " .. tostring(Kit))
	return
end

local CUR = "?"
local refused = { Lights = {}, Emitters = {}, Floating = {}, Flicker = {} } :: { [string]: { [string]: number } }
local refusedAt: { [string]: { [string]: { [string]: number } } } = {}
local function bump(t: { [string]: number }, k: string)
	t[k] = (t[k] or 0) + 1
	-- remember the builder lines that lost their effect (first game frame outside Kit)
	local budget = ""
	for b, tt in refused do
		if tt == t then
			budget = b
		end
	end
	local loc = string.match(SIM.CallerLoc(), "([%w_]+%.luau:%d+)") or "?"
	refusedAt[budget] = refusedAt[budget] or {}
	refusedAt[budget][k] = refusedAt[budget][k] or {}
	refusedAt[budget][k][loc] = (refusedAt[budget][k][loc] or 0) + 1
end
local origLight, origEmitter, origFloat = Kit.Light, Kit.Emitter, Kit.Float
Kit.Light = function(part, color, range, brightness, flicker)
	local before = Kit.Stats.Flicker
	local l = origLight(part, color, range, brightness, flicker)
	if l == nil then
		bump(refused.Lights, CUR)
	elseif flicker and Kit.Stats.Flicker == before then
		bump(refused.Flicker, CUR)
	end
	return l
end
Kit.Emitter = function(...)
	local e = origEmitter(...)
	if e == nil then
		bump(refused.Emitters, CUR)
	end
	return e
end
Kit.Float = function(...)
	local ok = origFloat(...)
	if not ok then
		bump(refused.Floating, CUR)
	end
	return ok
end

local MODULES = { "Lighting", "Boundary", "Gates", "Stations", "Arena", "Neighborhood", "Cemetery", "School", "Carnival", "Hospital", "Harbor", "Castle", "SpiritRealm" }
local MAP: any = nil
local FAILED: { [string]: boolean } = {}
for _, name in MODULES do
	local ok, mod = pcall(require, WorldFolder[name])
	if not ok then
		fail("require " .. name .. ": " .. tostring(mod))
	else
		local fname = if name == "Lighting" then "Apply" else "Build"
		local orig = mod[fname]
		-- each zone runs protected, so one broken zone doesn't hide errors in the others
		mod[fname] = function(map)
			CUR = name
			if map and not MAP then
				MAP = map
			end
			local ok, err = xpcall(orig, debug.traceback, map)
			if not ok then
				FAILED[name] = true
				fail(name .. "." .. fname .. "() failed:\n" .. tostring(err))
			end
			CUR = "?"
		end
	end
end

local okB, Builder = pcall(require, WorldFolder.Builder)
local built = false
if not okB then
	fail("require Builder: " .. tostring(Builder))
else
	local ok, err = xpcall(Builder.Build, debug.traceback)
	if ok then
		built = true
	else
		fail("Builder.Build() failed while building " .. CUR .. ":\n" .. tostring(err))
	end
end

if MAP and (not built or next(FAILED)) then
	print("  (the checks below run on a partial map: expect follow-on issues)")
end

-- collect parts
type PInfo = {
	Part: any,
	Folder: string,
	Name: string,
	Class: string,
	Solid: boolean,
	Visible: boolean,
	X1: number, Y1: number, Z1: number, X2: number, Y2: number, Z2: number,
	CF: any,
	Size: any,
	Shape: string,
	Mark: number,
}
local PARTS: { PInfo } = {}
local FOLDERS = { "Boundary", "Gates", "Stations", "EventArena", "Neighborhood", "Cemetery", "School", "Carnival", "Hospital", "Harbor", "Castle", "SpiritRealm" }

if MAP then
	local rows = {}
	local tot = { Parts = 0, Neon = 0, Lights = 0, Emitters = 0, Other = 0 }
	local children = MAP:GetChildren()
	local seen = {}
	for _, ch in children do
		seen[ch.Name] = true
	end
	for _, fname in FOLDERS do
		local mname = if fname == "EventArena" then "Arena" else fname
		if not seen[fname] and not FAILED[mname] then
			fail("Map." .. fname .. " is missing")
		end
	end
	for _, ch in children do
		local r = { Name = ch.Name, Parts = 0, Neon = 0, Lights = 0, Emitters = 0 }
		for _, d in ch:GetDescendants() do
			if d:IsA("BasePart") then
				r.Parts += 1
				if d.Material == Enum.Material.Neon then
					r.Neon += 1
				end
				local x1, y1, z1, x2, y2, z2 = SIM.AABB(d.CFrame, d.Size)
				local shape = if d:IsA("Part") then d.Shape.Name else cls(d)
				table.insert(PARTS, {
					Part = d, Folder = ch.Name, Name = d.Name, Class = cls(d),
					Solid = d.CanCollide, Visible = d.Transparency < 1,
					X1 = x1, Y1 = y1, Z1 = z1, X2 = x2, Y2 = y2, Z2 = z2,
					CF = d.CFrame, Size = d.Size, Shape = shape, Mark = 0,
				})
			elseif d:IsA("Light") then
				r.Lights += 1
			elseif d:IsA("ParticleEmitter") then
				r.Emitters += 1
			end
		end
		table.insert(rows, r)
		tot.Parts += r.Parts
		tot.Neon += r.Neon
		tot.Lights += r.Lights
		tot.Emitters += r.Emitters
	end
	print(string.format("  %-14s %7s %6s %6s %8s", "folder", "parts", "neon", "lights", "emitters"))
	for _, r in rows do
		print(string.format("  %-14s %7d %6d %6d %8d", r.Name, r.Parts, r.Neon, r.Lights, r.Emitters))
	end
	print(string.format("  %-14s %7d %6d %6d %8d   (neon %.1f%%)", "TOTAL", tot.Parts, tot.Neon, tot.Lights, tot.Emitters, 100 * tot.Neon / math.max(1, tot.Parts)))
	local s = Kit.Stats
	print(string.format("  Kit.Stats: parts %d, neon %d, lights %d (cap 170), emitters %d (cap 54), floating %d (cap 140), flicker %d (cap 34)", s.Parts, s.Neon, s.Lights, s.Emitters, s.Floating, s.Flicker))
	if s.Parts ~= tot.Parts then
		print(string.format("  note: %d parts in the tree vs %d counted by Kit.Stats (parts made outside Kit)", tot.Parts, s.Parts))
	end
	local lighting = game:GetService("Lighting")
	print(string.format("  Lighting children: %d (sky/atmosphere/effects)", #lighting:GetChildren()))

	local anyRefused = false
	for budget, byZone in refused do
		local list = {}
		local n = 0
		for zone, c in byZone do
			local locs = {}
			for loc, lc in (refusedAt[budget] or {})[zone] or {} do
				table.insert(locs, loc .. (if lc > 1 then " x" .. lc else ""))
			end
			table.sort(locs)
			table.insert(list, string.format("%s %d [%s]", zone, c, table.concat(locs, ", ")))
			n += c
		end
		if n > 0 then
			anyRefused = true
			table.sort(list)
			issue(string.format("Kit budget %s refused %d call(s): %s", budget, n, table.concat(list, ", ")))
		end
	end
	if not anyRefused then
		print("  budgets: no refused Light/Emitter/Float/Flicker calls")
	end
end

--==================================================================
-- spatial index over the built parts (16-stud XZ buckets)
--==================================================================
local CELL = 16
local GRID: { [number]: { PInfo } } = {}
local function key(ix: number, iz: number): number
	return ix * 100000 + iz
end
for _, p in PARTS do
	if p.Solid or p.Visible then
		for ix = math.floor(p.X1 / CELL), math.floor(p.X2 / CELL) do
			for iz = math.floor(p.Z1 / CELL), math.floor(p.Z2 / CELL) do
				local k = key(ix, iz)
				local b = GRID[k]
				if not b then
					b = {}
					GRID[k] = b
				end
				table.insert(b, p)
			end
		end
	end
end
local stamp = 0
local query
SIM.Parts = PARTS
SIM.Map = MAP
SIM.Query = function(...)
	return query(...)
end
function query(x1: number, z1: number, x2: number, z2: number): { PInfo }
	stamp += 1
	local out = {}
	for ix = math.floor(x1 / CELL), math.floor(x2 / CELL) do
		for iz = math.floor(z1 / CELL), math.floor(z2 / CELL) do
			local b = GRID[key(ix, iz)]
			if b then
				for _, p in b do
					if p.Mark ~= stamp and p.X2 >= x1 and p.X1 <= x2 and p.Z2 >= z1 and p.Z1 <= z2 then
						p.Mark = stamp
						table.insert(out, p)
					end
				end
			end
		end
	end
	return out
end

-- Does the part's plan-view footprint touch the circle (cx, cz, r)? Exact for parts with one
-- local axis vertical (blocks, wedges as their bounding rectangle, upright cylinders, balls);
-- otherwise the world AABB (conservative).
local function hitsCircle(p: PInfo, cx: number, cz: number, r: number): boolean
	local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = p.CF:GetComponents()
	local px, pz = p.CF.X, p.CF.Z
	local s = p.Size
	local dx, dz = cx - px, cz - pz
	if p.Shape == "Ball" then
		local rad = math.min(s.X, s.Y, s.Z) / 2
		return dx * dx + dz * dz < (rad + r) * (rad + r)
	end
	-- columns: X = (m00, m10, m20), Y = (m01, m11, m21), Z = (m02, m12, m22)
	local cols = { { m00, m10, m20, s.X }, { m01, m11, m21, s.Y }, { m02, m12, m22, s.Z } }
	local vert = 0
	for i = 1, 3 do
		if math.abs(cols[i][2]) > 0.999 then
			vert = i
		end
	end
	if vert == 0 then
		local qx = math.clamp(cx, p.X1, p.X2)
		local qz = math.clamp(cz, p.Z1, p.Z2)
		return (qx - cx) ^ 2 + (qz - cz) ^ 2 < r * r
	end
	if p.Shape == "Cylinder" and vert == 1 then
		local rad = math.min(s.Y, s.Z) / 2
		return dx * dx + dz * dz < (rad + r) * (rad + r)
	end
	local a, b
	if vert == 1 then
		a, b = cols[2], cols[3]
	elseif vert == 2 then
		a, b = cols[1], cols[3]
	else
		a, b = cols[1], cols[2]
	end
	local la = dx * a[1] + dz * a[3]
	local lb = dx * b[1] + dz * b[3]
	local ha, hb = a[4] / 2, b[4] / 2
	local qa = math.clamp(la, -ha, ha)
	local qb = math.clamp(lb, -hb, hb)
	return (la - qa) ^ 2 + (lb - qb) ^ 2 < r * r
end

local function describe(p: PInfo): string
	local c = p.CF
	return string.format("%s/%s (%s) at (%s, %s, %s) Y %s..%s size %s x %s x %s  [%s]", p.Folder, p.Name, p.Class == "Part" and p.Shape or p.Class,
		f1(c.X), f1(c.Y), f1(c.Z), f1(p.Y1), f1(p.Y2), f1(p.Size.X), f1(p.Size.Y), f1(p.Size.Z), S[p.Part].Loc or "?")
end

-- Solid walkable ground (top -0.6..0.3, or a SpawnLocation pad) under the point?
local function groundAt(x: number, z: number): boolean
	for _, p in query(x, z, x, z) do
		if p.Solid and ((p.Y2 >= -0.6 and p.Y2 <= 0.3) or p.Class == "SpawnLocation") and hitsCircle(p, x, z, 0.01) then
			return true
		end
	end
	return false
end

if MAP then
	--==================================================================
	-- 2. Ghost areas
	--==================================================================
	header("2. Ghost areas (nothing visible/solid with top > 0.3 and bottom < 40 inside)")
	local bad = 0
	for i, area in Config.Layout.GhostAreas do
		local c, r = area.Center, area.Radius
		local hits = {}
		for _, p in query(c.X - r, c.Z - r, c.X + r, c.Z + r) do
			if (p.Visible or p.Solid) and p.Y2 > 0.3 and p.Y1 < 40 and hitsCircle(p, c.X, c.Z, r) then
				table.insert(hits, p)
			end
		end
		if #hits > 0 then
			bad += 1
			issue(string.format("area #%d %s (%d, %d) r=%d: %d part(s) inside", i, area.Ghost, c.X, c.Z, r, #hits))
			for j, p in hits do
				if j > MAX_LIST and not VERBOSE then
					print(string.format("      ... %d more (--verbose lists all)", #hits - MAX_LIST))
					break
				end
				print("      " .. describe(p) .. (if p.Solid then " SOLID" else ""))
			end
		end
	end
	print(string.format("  %d/%d ghost areas clear", #Config.Layout.GhostAreas - bad, #Config.Layout.GhostAreas))

	--==================================================================
	-- 3. Fast Travel arrival points
	--==================================================================
	header("3. Zone spawns (r=4 clear of solids in Y 0.3..8, ground underneath)")
	print("  (solid steps with top <= 1.6 and the SpawnLocation pad count as walkable)")
	local ids = {}
	for id in Config.Layout.ZoneSpawns do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Config.Layout.ZoneSpawns[a].Z < Config.Layout.ZoneSpawns[b].Z
	end)
	for _, id in ids do
		local sp = Config.Layout.ZoneSpawns[id]
		local R = 4
		local blockers = {}
		for _, p in query(sp.X - R, sp.Z - R, sp.X + R, sp.Z + R) do
			local step = p.Y2 <= 1.6 -- low plaza discs / kerbs are walkable
			if p.Solid and p.Class ~= "SpawnLocation" and not step and p.Y2 > 0.3 and p.Y1 < 8 and hitsCircle(p, sp.X, sp.Z, R) then
				table.insert(blockers, p)
			end
		end
		local missing = {}
		for _, o in { { 0, 0 }, { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } } do
			if not groundAt(sp.X + o[1], sp.Z + o[2]) then
				table.insert(missing, string.format("(%d, %d)", sp.X + o[1], sp.Z + o[2]))
			end
		end
		if #blockers == 0 and #missing == 0 then
			print(string.format("  ok    %-12s (%d, %d)", id, sp.X, sp.Z))
		else
			if #blockers > 0 then
				issue(string.format("%s spawn (%d, %d): %d solid part(s) within r=4", id, sp.X, sp.Z, #blockers))
				for j, p in blockers do
					if j > MAX_LIST then
						break
					end
					print("      " .. describe(p))
				end
			end
			if #missing > 0 then
				issue(string.format("%s spawn (%d, %d): no solid ground (top -0.6..0.3) at %s", id, sp.X, sp.Z, table.concat(missing, " ")))
			end
		end
	end

	--==================================================================
	-- 4. Main route
	--==================================================================
	header("4. Main route X = 0 / +-6 (solid blockers Y 0.3..7, ground)")
	print("  (steps with top <= 1.6 are walkable; side lanes X=+-6 are notes when X=0 is clear)")
	local endZ = Config.Zones[#Config.Zones].MaxZ - 5
	local gateZ = {}
	for _, g in Config.Layout.Gates do
		table.insert(gateZ, g.Z)
	end
	local PROBE = 1 -- player half-width
	local function ignored(p: PInfo): boolean
		if p.Name == "Barrier" then
			return true
		end
		if p.Name == "InvisibleWall" then
			for _, gz in gateZ do
				if p.Z1 >= gz - 8 and p.Z2 <= gz + 8 then
					return true
				end
			end
		end
		return false
	end
	-- low solid parts (top <= 1.6: kerbs, plaza discs, dais tiers) are stepped onto, not blockers
	local function isStep(p: PInfo): boolean
		return p.Y2 <= 1.6
	end
	local function blockersAt(x: number, z: number): { PInfo }
		local out = {}
		for _, p in query(x - PROBE, z - PROBE, x + PROBE, z + PROBE) do
			if p.Solid and p.Y2 > 0.3 and p.Y1 < 7 and not ignored(p) and hitsCircle(p, x, z, PROBE) then
				table.insert(out, p)
			end
		end
		return out
	end
	local function walkGround(x: number, z: number): boolean
		if groundAt(x, z) then
			return true
		end
		for _, p in query(x, z, x, z) do
			if p.Solid and p.Y2 > 0.3 and p.Y2 <= 1.6 and hitsCircle(p, x, z, 0.01) then
				return true
			end
		end
		return false
	end
	local function clearAt(x: number, z: number): boolean
		for _, p in blockersAt(x, z) do
			if not isStep(p) then
				return false
			end
		end
		return walkGround(x, z)
	end

	for _, lane in { 0, -6, 6 } do
		local blockedRuns = {}
		local noGround = {}
		local cur: any = nil
		local z = -30
		while z <= endZ do
			local bl = {}
			for _, p in blockersAt(lane, z) do
				if not isStep(p) then
					table.insert(bl, p)
				end
			end
			if #bl > 0 then
				if cur and cur.Z2 == z - 4 then
					cur.Z2 = z
				else
					cur = { Z1 = z, Z2 = z, Parts = {} }
					table.insert(blockedRuns, cur)
				end
				for _, p in bl do
					cur.Parts[p] = true
				end
			end
			if not walkGround(lane, z) then
				table.insert(noGround, z)
			end
			z += 4
		end
		if #blockedRuns == 0 and #noGround == 0 then
			print(string.format("  ok    lane X=%d clear from Z -30 to %d", lane, endZ))
		end
		for _, run in blockedRuns do
			local names = {}
			for p in run.Parts do
				table.insert(names, p)
			end
			local msg = string.format("lane X=%d blocked Z %d..%d by %d part(s)", lane, run.Z1, run.Z2, #names)
			if lane == 0 then
				issue(msg)
			else
				print("  NOTE  " .. msg)
			end
			for j, p in names do
				if j > MAX_LIST then
					break
				end
				print("      " .. describe(p))
			end
			if lane == 0 then
				-- nearest clear detour within +-40 at every blocked sample
				local worst = 0
				local zz = run.Z1
				local ok = true
				while zz <= run.Z2 do
					local found = nil
					for d = 2, 40, 2 do
						if clearAt(d, zz) then
							found = d
							break
						elseif clearAt(-d, zz) then
							found = -d
							break
						end
					end
					if not found then
						ok = false
						print(string.format("      no clear X within +-40 at Z %d", zz))
					elseif math.abs(found) > math.abs(worst) then
						worst = found
					end
					zz += 4
				end
				if ok then
					print(string.format("      detour: clear lane within %d studs of X=0 at every blocked Z", math.abs(worst)))
				end
			end
		end
		if #noGround > 0 then
			local shown = {}
			for j, zz in noGround do
				if j > 12 then
					table.insert(shown, "...")
					break
				end
				table.insert(shown, tostring(zz))
			end
			local msg = string.format("lane X=%d: no solid ground at %d sample(s): Z %s", lane, #noGround, table.concat(shown, " "))
			if lane == 0 then
				issue(msg)
			else
				print("  NOTE  " .. msg)
			end
		end
	end

	-- Play-area edge: something solid and unjumpable (bottom < 1, top > 8) across |X| 140..146
	-- along the whole map, so players can't leave the map sideways.
	do
		local endWall = Config.Zones[#Config.Zones].MaxZ
		for _, sx in { -1, 1 } do
			local gaps = {}
			local cur: any = nil
			local z = -58
			while z <= endWall - 2 do
				local walled = false
				for _, p in query(math.min(sx * 146, sx * 140), z, math.max(sx * 146, sx * 140), z) do
					if p.Solid and p.Y1 < 1 and p.Y2 > 8 and hitsCircle(p, sx * 143, z, 0.01) then
						walled = true
						break
					end
				end
				if not walled then
					if cur and cur[2] == z - 4 then
						cur[2] = z
					else
						cur = { z, z }
						table.insert(gaps, cur)
					end
				end
				z += 4
			end
			if #gaps == 0 then
				print(string.format("  ok    edge X=%d walled from Z -58 to %d", sx * 143, endWall - 2))
			else
				local list = {}
				for _, g in gaps do
					table.insert(list, string.format("Z %d..%d", g[1], g[2]))
				end
				issue(string.format("edge X=%d: no solid wall (Y <1 .. >8) at %s", sx * 143, table.concat(list, ", ")))
			end
		end
	end

	-- Reachability: flood fill on a 2-stud grid over X -40..40 from the spawn plaza to the far end.
	local STEP = 2
	local XS = 40
	local cols = XS * 2 // STEP + 1
	local rowsN = math.floor((endZ - -30) / STEP) + 1
	local walk = {}
	local function idx(ci: number, ri: number): number
		return ri * cols + ci
	end
	for ri = 0, rowsN - 1 do
		local z = -30 + ri * STEP
		for ci = 0, cols - 1 do
			local x = -XS + ci * STEP
			walk[idx(ci, ri)] = clearAt(x, z)
		end
	end
	local seen = {}
	local queue = {}
	local startCi = XS // STEP
	for d = 0, cols - 1 do
		for _, ci in { startCi - d, startCi + d } do
			if ci >= 0 and ci < cols and walk[idx(ci, 0)] and #queue == 0 then
				table.insert(queue, idx(ci, 0))
				seen[idx(ci, 0)] = true
			end
		end
	end
	local head = 1
	local maxRow = 0
	while head <= #queue do
		local k = queue[head]
		head += 1
		local ri = k // cols
		local ci = k % cols
		if ri > maxRow then
			maxRow = ri
		end
		for _, nb in { { ci + 1, ri }, { ci - 1, ri }, { ci, ri + 1 }, { ci, ri - 1 } } do
			local nc, nr = nb[1], nb[2]
			if nc >= 0 and nc < cols and nr >= 0 and nr < rowsN then
				local nk = idx(nc, nr)
				if walk[nk] and not seen[nk] then
					seen[nk] = true
					table.insert(queue, nk)
				end
			end
		end
	end
	if #queue == 0 then
		issue("reachability: no walkable start cell near (0, -30)")
	elseif maxRow == rowsN - 1 then
		print(string.format("  ok    reachability: walkable path (|X| <= %d, gates open) from Z -30 to Z %d", XS, endZ))
	else
		issue(string.format("reachability: walking from Z -30 (|X| <= %d, gates open) stops at Z %d (goal %d)", XS, -30 + maxRow * STEP, endZ))
	end
end

--==================================================================
-- 5. Rigs
--==================================================================
header("5. Rigs")
local Rigs = GH.Rigs
local function rigStats(model): (number, number)
	local parts, neon = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.Material == Enum.Material.Neon then
				neon += 1
			end
		end
	end
	return parts, neon
end
local function rigSanity(label: string, model)
	if not model or not SIM.isInst(model) or not model:IsA("Model") then
		fail(label .. ": did not return a Model")
		return false
	end
	local ok = true
	if model.PrimaryPart == nil then
		fail(label .. ": PrimaryPart is nil")
		ok = false
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local p0, p1 = d.Part0, d.Part1
			if p0 == nil or p1 == nil then
				fail(string.format("%s: %s %s has a nil Part0/Part1", label, cls(d), d.Name))
				ok = false
			elseif not (p0:IsDescendantOf(model) and p1:IsDescendantOf(model)) then
				fail(string.format("%s: %s %s links a part outside the model", label, cls(d), d.Name))
				ok = false
			end
		elseif d:IsA("BasePart") then
			if SIM.CFHasNaN(d.CFrame) then
				fail(string.format("%s: part %s has a NaN CFrame", label, d.Name))
				ok = false
			end
		end
	end
	return ok
end
local function sortedKeys(t): { string }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

local function loadRig(name: string)
	local ok, mod = pcall(require, Rigs[name])
	if not ok then
		fail("require " .. name .. ": " .. tostring(mod))
		return nil
	end
	return mod
end

-- Ghosts
local GhostRig = loadRig("GhostRig")
if GhostRig then
	local n, okN, line = 0, 0, {}
	for _, id in sortedKeys(Config.Ghosts) do
		n += 1
		local ok, res = xpcall(GhostRig.Build, debug.traceback, id)
		if not ok then
			fail("GhostRig.Build(" .. id .. "):\n" .. tostring(res))
		elseif rigSanity("ghost " .. id, res) then
			okN += 1
			local p, ne = rigStats(res)
			local core = res.PrimaryPart
			if core.Name ~= "Core" then
				fail("ghost " .. id .. ": PrimaryPart is " .. core.Name .. ", expected Core")
			end
			for _, a in { "Center", "Top", "Bottom" } do
				local att = core:FindFirstChild(a)
				if not att or not att:IsA("Attachment") then
					fail("ghost " .. id .. ": Core has no " .. a .. " attachment")
				end
			end
			local scale = Config.Ghosts[id].Scale
			if math.abs(res:GetScale() - scale) > 1e-6 and scale ~= 1 then
				fail("ghost " .. id .. ": scale " .. res:GetScale() .. " ~= " .. scale)
			end
			table.insert(line, string.format("%s %d/%d", id, p, ne))
		end
	end
	print(string.format("  ghosts: %d/%d built (parts/neon):", okN, n))
	for i = 1, #line, 4 do
		print("    " .. table.concat(line, "  ", i, math.min(#line, i + 3)))
	end
end

-- Hunters
local HunterRig = loadRig("HunterRig")
if HunterRig then
	local n, okN, line = 0, 0, {}
	for _, id in sortedKeys(Config.Hunters) do
		n += 1
		local ok, rig = xpcall(HunterRig.Build, debug.traceback, id)
		if not ok then
			fail("HunterRig.Build(" .. id .. "):\n" .. tostring(rig))
			continue
		end
		local good = rigSanity("hunter " .. id, rig.Model)
		if good then
			local tip = rig.Model:FindFirstChild("Tip", true)
			if not tip or not tip:IsA("Attachment") then
				fail("hunter " .. id .. ": no Attachment named Tip in the model")
				good = false
			elseif rig.Tip ~= tip then
				fail("hunter " .. id .. ": rig.Tip is not the model's Tip attachment")
				good = false
			end
			for _, j in { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				local mo = rig.Motors[j]
				if not mo or not mo:IsA("Motor6D") then
					fail("hunter " .. id .. ": missing Motor6D " .. j)
					good = false
				end
			end
			if type(rig.Height) ~= "number" or rig.Height ~= rig.Height or rig.Height <= 0 then
				fail("hunter " .. id .. ": bad Height " .. tostring(rig.Height))
				good = false
			end
			for _, state in { "Idle", "Run", "Attack", "Celebrate" } do
				local okP, errP = xpcall(HunterRig.Pose, debug.traceback, rig, state, 1.3, 0.7)
				if not okP then
					fail("HunterRig.Pose(" .. id .. ", " .. state .. "):\n" .. tostring(errP))
					good = false
				end
			end
		end
		local okS, static = xpcall(HunterRig.BuildStatic, debug.traceback, id)
		if not okS then
			fail("HunterRig.BuildStatic(" .. id .. "):\n" .. tostring(static))
			good = false
		elseif rigSanity("static hunter " .. id, static) then
			for _, d in static:GetDescendants() do
				if d:IsA("BasePart") and not d.Anchored then
					fail("static hunter " .. id .. ": part " .. d.Name .. " not anchored")
					good = false
					break
				end
			end
		else
			good = false
		end
		if good then
			okN += 1
			local p, ne = rigStats(rig.Model)
			table.insert(line, string.format("%s %d/%d", id, p, ne))
		end
	end
	print(string.format("  hunters: %d/%d built + static + 4 poses (parts/neon):", okN, n))
	for i = 1, #line, 4 do
		print("    " .. table.concat(line, "  ", i, math.min(#line, i + 3)))
	end
end

-- Crates
local CrateRig = loadRig("CrateRig")
if CrateRig then
	local n, okN, line = 0, 0, {}
	for _, id in sortedKeys(Config.Crates) do
		n += 1
		local ok, rig = xpcall(CrateRig.Build, debug.traceback, id)
		if not ok then
			fail("CrateRig.Build(" .. id .. "):\n" .. tostring(rig))
			continue
		end
		local good = rigSanity("crate " .. id, rig.Model)
		for _, mname in { "Lid", "LockL", "LockR" } do
			local mo = rig.Motors and rig.Motors[mname]
			if not mo or not SIM.isInst(mo) or not mo:IsA("Motor6D") then
				fail("crate " .. id .. ": Motors." .. mname .. " is not a Motor6D")
				good = false
			elseif mo.Name ~= mname then
				fail("crate " .. id .. ": Motors." .. mname .. " is named " .. mo.Name)
				good = false
			end
		end
		if not rig.Glow or not SIM.isInst(rig.Glow) or not rig.Glow:IsA("BasePart") then
			fail("crate " .. id .. ": Glow is not a BasePart")
			good = false
		end
		if not rig.Burst or not SIM.isInst(rig.Burst) or not rig.Burst:IsA("Attachment") then
			fail("crate " .. id .. ": Burst is not an Attachment")
			good = false
		end
		if rig.Base and rig.Model.PrimaryPart ~= rig.Base then
			fail("crate " .. id .. ": PrimaryPart is not Base")
			good = false
		end
		if good then
			okN += 1
			local p, ne = rigStats(rig.Model)
			local pivot = rig.Model:GetPivot()
			table.insert(line, string.format("%s %d/%d", id, p, ne))
			if math.abs(pivot.Y) > 1e-6 then
				issue(string.format("crate %s: model pivot Y is %.3f, expected 0 (ground point)", id, pivot.Y))
			end
		end
	end
	print(string.format("  crates: %d/%d built (parts/neon):", okN, n))
	for i = 1, #line, 4 do
		print("    " .. table.concat(line, "  ", i, math.min(#line, i + 3)))
	end
end

--==================================================================
-- engine warnings collected by the mock
--==================================================================
header("Engine warnings (Roblox would clamp / ignore these)")
if #SIM.WarnOrder == 0 then
	print("  none")
else
	for _, k in SIM.WarnOrder do
		local w = SIM.Warnings[k]
		print(string.format("  WARN %s at %s (x%d): %s", w.Kind, w.Loc, w.Count, w.Msg))
	end
end

print("")
print(string.format("worldsim: %d error(s), %d layout issue(s), %d warning kind(s)", errors, issues, #SIM.WarnOrder))
