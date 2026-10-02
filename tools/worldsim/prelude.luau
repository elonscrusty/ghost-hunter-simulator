--[[
	Mock Roblox runtime for the headless world smoke test (tools/worldsim.sh).
	Plain Luau CLI has no Roblox types, so this file provides the parts of the engine the
	world builders and rigs touch: Vector3/CFrame (real rotation matrices), Color3, Enum,
	sequences, Random, and an Instance tree that validates class names, property names,
	property types, parenting rules and sizes the way the engine does.

	Problems that Roblox would only warn about (or silently clamp) are collected with
	SIM.Warn(kind, msg) together with the game source line that caused them.
]]

SIM = { Warnings = {}, WarnOrder = {} }
local GENV = getfenv(1) -- the script's global table (the CLI sandboxes _G)

-- First stack frame that belongs to game code (not this mock / the runner).
-- Part factories are skipped so the line of the builder / rig that asked for the part is
-- reported, followed by its caller: "src/.../Props.luau:181 <- src/.../Neighborhood.luau:316".
local HELPERS = { "/Kit%.luau$", "/RigUtil%.luau$" }
function SIM.CallerLoc(): string
	local out = {}
	for level = 2, 40 do
		local src, line = debug.info(level, "sl")
		if not src then
			break
		end
		local helper = false
		for _, pat in HELPERS do
			if string.find(src, pat) then
				helper = true
			end
		end
		if string.find(src, "^src/") and not helper then
			table.insert(out, src .. ":" .. tostring(line))
			if #out == 2 then
				break
			end
		end
	end
	return if #out == 0 then "?" else table.concat(out, " <- ")
end

function SIM.Warn(kind: string, msg: string, loc: string?)
	local where = loc or SIM.CallerLoc()
	local key = kind .. "|" .. where
	local w = SIM.Warnings[key]
	if w then
		w.Count += 1
	else
		SIM.Warnings[key] = { Kind = kind, Msg = msg, Loc = where, Count = 1 }
		table.insert(SIM.WarnOrder, key)
	end
end

local function isnan(n: number): boolean
	return n ~= n
end

--==================================================================
-- Vector3 / Vector2
--==================================================================
local V3mt = {}
local V3methods = {}
V3mt.__type = "Vector3"
Vector3 = {}
local function v3(x: number, y: number, z: number)
	return setmetatable({ X = x, Y = y, Z = z }, V3mt)
end
function Vector3.new(x: number?, y: number?, z: number?)
	return v3(x or 0, y or 0, z or 0)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
V3mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			SIM.Warn("Vector3.Unit", "Unit of a zero-length vector gives NaN")
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	local f = V3methods[k]
	if f == nil then
		error(tostring(k) .. " is not a valid member of Vector3", 2)
	end
	return f
end
V3mt.__newindex = function(_, k)
	error(tostring(k) .. " cannot be assigned to", 2)
end
local function isV3(v: any): boolean
	return getmetatable(v) == V3mt
end
V3mt.__add = function(a, b)
	if not (isV3(a) and isV3(b)) then
		error("attempt to perform arithmetic (add) on Vector3 and " .. typeof(if isV3(a) then b else a), 2)
	end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3mt.__sub = function(a, b)
	if not (isV3(a) and isV3(b)) then
		error("attempt to perform arithmetic (sub) on Vector3 and " .. typeof(if isV3(a) then b else a), 2)
	end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3mt.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3mt.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	elseif isV3(a) and isV3(b) then
		return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
	error("attempt to perform arithmetic (mul) on " .. typeof(a) .. " and " .. typeof(b), 2)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	elseif type(a) == "number" then
		return v3(a / b.X, a / b.Y, a / b.Z)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3mt.__idiv = function(a, b)
	return v3(a.X // b, a.Y // b, a.Z // b)
end
V3mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3mt.__tostring = function(v)
	return string.format("%g, %g, %g", v.X, v.Y, v.Z)
end
function V3methods.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3methods.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3methods.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3methods.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3methods.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function V3methods.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3methods.Floor(a)
	return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z))
end
function V3methods.Ceil(a)
	return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z))
end
function V3methods.Sign(a)
	return v3(math.sign(a.X), math.sign(a.Y), math.sign(a.Z))
end
function V3methods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
function V3methods.Angle(a, b)
	local d = V3methods.Dot(a, b) / (a.Magnitude * b.Magnitude)
	return math.acos(math.clamp(d, -1, 1))
end
SIM.isV3 = isV3

local V2mt = {}
V2mt.__type = "Vector2"
V2mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	end
	error(tostring(k) .. " is not a valid member of Vector2", 2)
end
Vector2 = {}
function Vector2.new(x: number?, y: number?)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2mt)
end
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
V2mt.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
V2mt.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
V2mt.__mul = function(a, b)
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	elseif type(a) == "number" then
		return Vector2.new(a * b.X, a * b.Y)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end

--==================================================================
-- CFrame: position p + row-major rotation m[1..9] (R00 R01 R02 / R10 ... / R20 ...)
--==================================================================
local CFmt = {}
local CFmethods = {}
CFmt.__type = "CFrame"
CFrame = {}
local ID = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function cf(px: number, py: number, pz: number, m: { number })
	return setmetatable({ _x = px, _y = py, _z = pz, _m = m }, CFmt)
end
local function isCF(v: any): boolean
	return getmetatable(v) == CFmt
end
SIM.isCF = isCF
local function mmul(a: { number }, b: { number }): { number }
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function mvec(m: { number }, x: number, y: number, z: number)
	return m[1] * x + m[2] * y + m[3] * z, m[4] * x + m[5] * y + m[6] * z, m[7] * x + m[8] * y + m[9] * z
end
local function transpose(m: { number }): { number }
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end
-- columns -> row-major
local function fromCols(x, y, z): { number }
	return { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z }
end
local function orthonormalize(m: { number }): { number }
	-- Gram-Schmidt on the columns (Roblox keeps CFrames orthonormal)
	local x = v3(m[1], m[4], m[7])
	local y = v3(m[2], m[5], m[8])
	local xm = x.Magnitude
	if xm == 0 then
		return table.clone(ID)
	end
	x = x / xm
	y = y - x * x:Dot(y)
	local ym = y.Magnitude
	if ym == 0 then
		return table.clone(ID)
	end
	y = y / ym
	local z = x:Cross(y)
	return fromCols(x, y, z)
end

function CFrame.new(...)
	local n = select("#", ...)
	local a, b, c = ...
	if n == 0 then
		return cf(0, 0, 0, ID)
	elseif n == 1 then
		if not isV3(a) then
			error("invalid argument #1 to 'new' (Vector3 expected, got " .. typeof(a) .. ")", 2)
		end
		return cf(a.X, a.Y, a.Z, ID)
	elseif n == 2 then
		-- CFrame.new(pos, lookAt)
		return CFrame.lookAt(a, b)
	elseif n == 3 then
		if type(a) ~= "number" or type(b) ~= "number" or type(c) ~= "number" then
			error("invalid argument to CFrame.new (numbers expected)", 2)
		end
		return cf(a, b, c, ID)
	elseif n == 7 then
		local x, y, z, qx, qy, qz, qw = ...
		local m = {
			1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy),
		}
		return cf(x, y, z, m)
	elseif n == 12 then
		local t = { ... }
		return cf(t[1], t[2], t[3], { t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12] })
	end
	error("invalid number of arguments to CFrame.new: " .. n, 2)
end
CFrame.identity = cf(0, 0, 0, ID)

local function rx(t)
	local c, s = math.cos(t), math.sin(t)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local function checkNums(fname, ...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) ~= "number" then
			error(string.format("invalid argument #%d to '%s' (number expected, got %s)", i, fname, typeof(v)), 3)
		end
	end
end
function CFrame.Angles(x, y, z)
	checkNums("Angles", x, y, z)
	return cf(0, 0, 0, mmul(mmul(rx(x), ry(y)), rz(z)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	checkNums("fromEulerAnglesYXZ", x, y, z)
	return cf(0, 0, 0, mmul(mmul(ry(y), rx(x)), rz(z)))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(axis, r)
	local u = axis.Unit
	local c, s = math.cos(r), math.sin(r)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(0, 0, 0, {
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c,
	})
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	if not (isV3(pos) and isV3(vx) and isV3(vy)) then
		error("invalid argument to CFrame.fromMatrix (Vector3 expected)", 2)
	end
	local z = vz or vx:Cross(vy).Unit
	return cf(pos.X, pos.Y, pos.Z, orthonormalize(fromCols(vx, vy, z)))
end
function CFrame.lookAt(at, target, up)
	if not (isV3(at) and isV3(target)) then
		error("invalid argument to CFrame.lookAt (Vector3 expected)", 2)
	end
	up = up or Vector3.yAxis
	local d = target - at
	if d.Magnitude < 1e-9 then
		SIM.Warn("CFrame.lookAt", "lookAt with at == target (no direction)")
		return cf(at.X, at.Y, at.Z, ID)
	end
	local look = d.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		-- looking straight along `up`: Roblox picks a stable right vector
		right = look:Cross(Vector3.zAxis)
		if right.Magnitude < 1e-6 then
			right = look:Cross(Vector3.xAxis)
		end
	end
	right = right.Unit
	local u = right:Cross(look)
	return cf(at.X, at.Y, at.Z, fromCols(right, u, -look))
end
CFrame.lookAlong = function(at, dir, up)
	return CFrame.lookAt(at, at + dir, up)
end

CFmt.__index = function(c, k)
	local m = c._m
	if k == "Position" or k == "p" then
		return v3(c._x, c._y, c._z)
	elseif k == "X" then
		return c._x
	elseif k == "Y" then
		return c._y
	elseif k == "Z" then
		return c._z
	elseif k == "LookVector" then
		return v3(-m[3], -m[6], -m[9])
	elseif k == "RightVector" or k == "XVector" then
		return v3(m[1], m[4], m[7])
	elseif k == "UpVector" or k == "YVector" then
		return v3(m[2], m[5], m[8])
	elseif k == "ZVector" then
		return v3(m[3], m[6], m[9])
	elseif k == "Rotation" then
		return cf(0, 0, 0, m)
	end
	local f = CFmethods[k]
	if f == nil then
		error(tostring(k) .. " is not a valid member of CFrame", 2)
	end
	return f
end
CFmt.__newindex = function(_, k)
	error(tostring(k) .. " cannot be assigned to", 2)
end
CFmt.__mul = function(a, b)
	if not isCF(a) then
		error("attempt to multiply " .. typeof(a) .. " by CFrame", 2)
	end
	if isCF(b) then
		local x, y, z = mvec(a._m, b._x, b._y, b._z)
		return cf(a._x + x, a._y + y, a._z + z, mmul(a._m, b._m))
	elseif isV3(b) then
		local x, y, z = mvec(a._m, b.X, b.Y, b.Z)
		return v3(a._x + x, a._y + y, a._z + z)
	end
	error("invalid argument to CFrame * (CFrame or Vector3 expected, got " .. typeof(b) .. ")", 2)
end
CFmt.__add = function(a, b)
	if not (isCF(a) and isV3(b)) then
		error("CFrame + expects a Vector3 on the right", 2)
	end
	return cf(a._x + b.X, a._y + b.Y, a._z + b.Z, a._m)
end
CFmt.__sub = function(a, b)
	if not (isCF(a) and isV3(b)) then
		error("CFrame - expects a Vector3 on the right", 2)
	end
	return cf(a._x - b.X, a._y - b.Y, a._z - b.Z, a._m)
end
CFmt.__eq = function(a, b)
	if a._x ~= b._x or a._y ~= b._y or a._z ~= b._z then
		return false
	end
	for i = 1, 9 do
		if a._m[i] ~= b._m[i] then
			return false
		end
	end
	return true
end
CFmt.__tostring = function(c)
	local m = c._m
	return string.format("%g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g", c._x, c._y, c._z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end
function CFmethods.Inverse(c)
	local t = transpose(c._m)
	local x, y, z = mvec(t, -c._x, -c._y, -c._z)
	return cf(x, y, z, t)
end
function CFmethods.ToObjectSpace(a, b)
	return CFmethods.Inverse(a) * b
end
function CFmethods.ToWorldSpace(a, b)
	return a * b
end
function CFmethods.PointToObjectSpace(a, v)
	return CFmethods.Inverse(a) * v
end
function CFmethods.PointToWorldSpace(a, v)
	return a * v
end
function CFmethods.VectorToObjectSpace(a, v)
	local x, y, z = mvec(transpose(a._m), v.X, v.Y, v.Z)
	return v3(x, y, z)
end
function CFmethods.VectorToWorldSpace(a, v)
	local x, y, z = mvec(a._m, v.X, v.Y, v.Z)
	return v3(x, y, z)
end
function CFmethods.GetComponents(c)
	local m = c._m
	return c._x, c._y, c._z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
end
CFmethods.components = CFmethods.GetComponents
function CFmethods.ToEulerAnglesXYZ(c)
	local m = c._m
	local y = math.asin(math.clamp(m[3], -1, 1))
	local x = math.atan2(-m[6], m[9])
	local z = math.atan2(-m[2], m[1])
	return x, y, z
end
CFmethods.toEulerAnglesXYZ = CFmethods.ToEulerAnglesXYZ
function CFmethods.ToEulerAnglesYXZ(c)
	local m = c._m
	local x = math.asin(math.clamp(-m[6], -1, 1))
	local y = math.atan2(m[3], m[9])
	local z = math.atan2(m[4], m[5])
	return x, y, z
end
CFmethods.ToOrientation = CFmethods.ToEulerAnglesYXZ
function CFmethods.Lerp(a, b, t)
	-- position lerp + rotation snap (good enough for static builds)
	local p = a.Position:Lerp(b.Position, t)
	return cf(p.X, p.Y, p.Z, if t < 0.5 then a._m else b._m)
end
function CFmethods.Orthonormalize(c)
	return cf(c._x, c._y, c._z, orthonormalize(c._m))
end
function CFmethods.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	if math.abs(a._x - b._x) > eps or math.abs(a._y - b._y) > eps or math.abs(a._z - b._z) > eps then
		return false
	end
	for i = 1, 9 do
		if math.abs(a._m[i] - b._m[i]) > eps then
			return false
		end
	end
	return true
end

-- World AABB of a box of `size` at `c` (exact for blocks/wedges, conservative for balls/cylinders).
function SIM.AABB(c, size)
	local m = c._m
	local sx, sy, sz = size.X / 2, size.Y / 2, size.Z / 2
	local hx = math.abs(m[1]) * sx + math.abs(m[2]) * sy + math.abs(m[3]) * sz
	local hy = math.abs(m[4]) * sx + math.abs(m[5]) * sy + math.abs(m[6]) * sz
	local hz = math.abs(m[7]) * sx + math.abs(m[8]) * sy + math.abs(m[9]) * sz
	return c._x - hx, c._y - hy, c._z - hz, c._x + hx, c._y + hy, c._z + hz
end

function SIM.CFHasNaN(c): boolean
	if isnan(c._x) or isnan(c._y) or isnan(c._z) then
		return true
	end
	for i = 1, 9 do
		if isnan(c._m[i]) then
			return true
		end
	end
	return false
end

--==================================================================
-- Color3, sequences, UDim2, NumberRange
--==================================================================
local C3mt = {}
local C3methods = {}
C3mt.__type = "Color3"
C3mt.__index = function(_, k)
	local f = C3methods[k]
	if f == nil then
		error(tostring(k) .. " is not a valid member of Color3", 2)
	end
	return f
end
C3mt.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
C3mt.__tostring = function(c)
	return string.format("%g, %g, %g", c.R, c.G, c.B)
end
Color3 = {}
function Color3.new(r, g, b)
	checkNums("Color3.new", r or 0, g or 0, b or 0)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3mt)
end
function Color3.fromRGB(r, g, b)
	checkNums("Color3.fromRGB", r or 0, g or 0, b or 0)
	local function q(v)
		return math.clamp(math.floor((v or 0) + 0.5), 0, 255) / 255
	end
	return Color3.new(q(r), q(g), q(b))
end
function Color3.fromHSV(h, s, v)
	checkNums("Color3.fromHSV", h, s, v)
	h = (h % 1) * 6
	local i = math.floor(h)
	local f = h - i
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	if i == 0 then
		return Color3.new(v, t, p)
	elseif i == 1 then
		return Color3.new(q, v, p)
	elseif i == 2 then
		return Color3.new(p, v, t)
	elseif i == 3 then
		return Color3.new(p, q, v)
	elseif i == 4 then
		return Color3.new(t, p, v)
	end
	return Color3.new(v, p, q)
end
function Color3.fromHex(hex: string)
	hex = string.gsub(hex, "#", "")
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end
function C3methods.Lerp(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3methods.ToHSV(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == r then
			h = ((g - b) / d) % 6
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		h /= 6
	end
	return h, (if mx > 0 then d / mx else 0), mx
end
function C3methods.ToHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function tagged(t: string)
	return { __type = t, __index = function(_, k)
		error(tostring(k) .. " is not a valid member of " .. t, 2)
	end }
end
local NRmt = tagged("NumberRange")
NumberRange = {}
function NumberRange.new(a, b)
	b = if b == nil then a else b
	checkNums("NumberRange.new", a, b)
	if b < a then
		error("NumberRange: invalid range (max < min)", 2)
	end
	return setmetatable({ Min = a, Max = b }, NRmt)
end

local NSKmt = tagged("NumberSequenceKeypoint")
NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t, v, e)
	checkNums("NumberSequenceKeypoint.new", t, v, e or 0)
	return setmetatable({ Time = t, Value = v, Envelope = e or 0 }, NSKmt)
end
local CSKmt = tagged("ColorSequenceKeypoint")
ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(t, c)
	checkNums("ColorSequenceKeypoint.new", t)
	if getmetatable(c) ~= C3mt then
		error("ColorSequenceKeypoint.new: Color3 expected, got " .. typeof(c), 2)
	end
	return setmetatable({ Time = t, Value = c }, CSKmt)
end
local function checkKeypoints(kind: string, kps: { any }, kpmt)
	if #kps < 2 then
		error(kind .. ": requires at least 2 keypoints", 3)
	end
	if #kps > 20 then
		error(kind .. ": table is too long (max 20 keypoints)", 3)
	end
	for i, kp in kps do
		if getmetatable(kp) ~= kpmt then
			error(kind .. ": keypoint " .. i .. " has the wrong type", 3)
		end
		if i > 1 and kp.Time < kps[i - 1].Time then
			error(kind .. ": keypoints must be ordered by time", 3)
		end
	end
	if kps[1].Time ~= 0 or kps[#kps].Time ~= 1 then
		error(kind .. " time must start at 0, and end at 1", 3)
	end
end
local NSmt = tagged("NumberSequence")
NumberSequence = {}
function NumberSequence.new(a, b)
	if type(a) == "number" then
		local v1 = if b == nil then a else b
		checkNums("NumberSequence.new", a, v1)
		return setmetatable({ Keypoints = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, v1) } }, NSmt)
	elseif type(a) == "table" then
		checkKeypoints("NumberSequence", a, NSKmt)
		return setmetatable({ Keypoints = a }, NSmt)
	end
	error("NumberSequence.new: invalid arguments", 2)
end
local CSmt = tagged("ColorSequence")
ColorSequence = {}
function ColorSequence.new(a, b)
	if getmetatable(a) == C3mt then
		local c1 = b or a
		if getmetatable(c1) ~= C3mt then
			error("ColorSequence.new: Color3 expected", 2)
		end
		return setmetatable({ Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, c1) } }, CSmt)
	elseif type(a) == "table" and getmetatable(a) == nil then
		checkKeypoints("ColorSequence", a, CSKmt)
		return setmetatable({ Keypoints = a }, CSmt)
	end
	error("ColorSequence.new: invalid arguments (got " .. typeof(a) .. ")", 2)
end

local UDmt = tagged("UDim")
UDim = {}
function UDim.new(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDmt)
end
local UD2mt = tagged("UDim2")
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	if type(xs) == "table" then
		return setmetatable({ X = xs, Y = xo }, UD2mt)
	end
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2mt)
end
function UDim2.fromScale(x, y)
	checkNums("UDim2.fromScale", x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	checkNums("UDim2.fromOffset", x, y)
	return UDim2.new(0, x, 0, y)
end
BrickColor = {
	new = function(n)
		return setmetatable({ Name = tostring(n) }, tagged("BrickColor"))
	end,
}

--==================================================================
-- typeof / Random / task
--==================================================================
local rawtypeof = typeof
function typeof(v: any): string
	local mt = getmetatable(v)
	if type(mt) == "table" and rawget(mt, "__type") then
		return rawget(mt, "__type")
	end
	return rawtypeof(v)
end

-- Deterministic xorshift-style PRNG (Roblox uses PCG; values differ, ranges don't).
local RNGmt = { __type = "Random" }
RNGmt.__index = RNGmt
Random = {}
function Random.new(seed: number?)
	local s = math.floor(seed or os.clock() * 1e6) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ _s = s }, RNGmt)
end
local function nxt(r): number
	r._s = (r._s * 48271) % 2147483647
	return (r._s - 1) / 2147483646
end
function RNGmt.NextNumber(r, a, b)
	local f = nxt(r)
	if a == nil then
		return f
	end
	checkNums("NextNumber", a, b)
	return a + (b - a) * f
end
function RNGmt.NextInteger(r, a, b)
	checkNums("NextInteger", a, b)
	a, b = math.floor(a), math.floor(b)
	if b < a then
		error("invalid argument #2 to 'NextInteger' (interval is empty)", 2)
	end
	return a + math.min(b - a, math.floor(nxt(r) * (b - a + 1)))
end
function RNGmt.NextUnitVector(r)
	local v = v3(nxt(r) - 0.5, nxt(r) - 0.5, nxt(r) - 0.5)
	return v.Unit
end
function RNGmt.Shuffle(r, t)
	for i = #t, 2, -1 do
		local j = RNGmt.NextInteger(r, 1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RNGmt.Clone(r)
	return setmetatable({ _s = r._s }, RNGmt)
end

task = {
	wait = function(_n)
		return 0
	end,
	spawn = function(f, ...)
		f(...)
	end,
	defer = function(f, ...)
		f(...)
	end,
	delay = function(_t, f, ...)
		f(...)
	end,
}
tick = os.clock
time = os.clock
function warn(...)
	SIM.Warn("warn()", table.concat(table.pack(...) :: any, " "))
end

--==================================================================
-- Enum
--==================================================================
local ENUM_ITEMS: { [string]: { string } } = {
	Material = { "Plastic", "SmoothPlastic", "Neon", "Wood", "WoodPlanks", "Marble", "Basalt", "Slate", "CrackedLava", "Concrete", "Limestone", "Granite", "Pavement", "Brick", "Pebble", "Cobblestone", "Rock", "Sandstone", "CorrodedMetal", "DiamondPlate", "Foil", "Metal", "Grass", "LeafyGrass", "Sand", "Fabric", "Snow", "Mud", "Ground", "Asphalt", "Salt", "Ice", "Glacier", "Glass", "ForceField", "Air", "Water", "Cardboard", "Carpet", "CeramicTiles", "ClayRoofTiles", "RoofShingles", "Leather", "Plaster", "Rubber" },
	PartType = { "Ball", "Block", "Cylinder", "Wedge", "CornerWedge" },
	NormalId = { "Right", "Top", "Back", "Left", "Bottom", "Front" },
	SurfaceType = { "Smooth", "Glue", "Weld", "Studs", "Inlet", "Universal", "Hinge", "Motor", "SteppingMotor", "SmoothNoOutlines" },
	ParticleEmitterShape = { "Box", "Sphere", "Cylinder", "Disc" },
	SurfaceGuiSizingMode = { "FixedSize", "PixelsPerStud" },
	TextTruncate = { "None", "AtEnd", "SplitWord" },
	Font = { "Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold", "SourceSansSemibold", "SourceSansLight", "SourceSansItalic", "Bodoni", "Garamond", "Cartoon", "Code", "Highway", "SciFi", "Arcade", "Fantasy", "Antique", "Gotham", "GothamMedium", "GothamBold", "GothamBlack", "AmaticSC", "Bangers", "Creepster", "DenkOne", "Fondamento", "FredokaOne", "GrenzeGotisch", "IndieFlower", "JosefinSans", "Jura", "Kalam", "LuckiestGuy", "Merriweather", "Michroma", "Nunito", "Oswald", "PatrickHand", "PermanentMarker", "Roboto", "RobotoCondensed", "RobotoMono", "Sarpanch", "SpecialElite", "TitilliumWeb", "Ubuntu", "BuilderSans", "BuilderSansMedium", "BuilderSansBold", "BuilderSansExtraBold", "Arimo", "ArimoBold" },
}
local EImt = { __type = "EnumItem" }
EImt.__index = function(_, k)
	error(tostring(k) .. " is not a valid member of EnumItem", 2)
end
EImt.__tostring = function(e)
	return "Enum." .. e.EnumType .. "." .. e.Name
end
local enumCache: { [string]: any } = {}
local function enumGroup(group: string)
	local items = {}
	local valid: { [string]: number }? = nil
	if ENUM_ITEMS[group] then
		local v: { [string]: number } = {}
		for i, n in ENUM_ITEMS[group] do
			v[n] = i - 1
		end
		valid = v
	end
	local meta = { __type = "Enum" }
	meta.__index = function(_, k)
		if k == "GetEnumItems" then
			return function()
				local out = {}
				for _, n in ENUM_ITEMS[group] or {} do
					table.insert(out, items[n] or (getmetatable(items) :: any).__index(items, n))
				end
				return out
			end
		end
		if valid and valid[k] == nil then
			error(tostring(k) .. " is not a valid member of \"Enum." .. group .. "\"", 2)
		end
		local e = setmetatable({ EnumType = group, Name = k, Value = if valid then valid[k] else 0 }, EImt)
		rawset(items, k, e)
		return e
	end
	return setmetatable(items, meta)
end
Enum = setmetatable({}, {
	__index = function(t, group)
		local g = enumCache[group]
		if not g then
			g = enumGroup(group)
			enumCache[group] = g
		end
		return g
	end,
})
local function isEnum(v: any, group: string): boolean
	return getmetatable(v) == EImt and v.EnumType == group
end

--==================================================================
-- Instances
--==================================================================
-- Property type tags: "number" | "string" | "boolean" | "Vector3" | "CFrame" | "Color3" | ...
-- "Enum.<Group>" for enum properties, "Ref:<Class>" for nil-able instance references.
type ClassDef = { Super: string?, Props: { [string]: string }, Defaults: { [string]: any }, Creatable: boolean }
local CLASSES: { [string]: ClassDef } = {}
local function class(name: string, super: string?, props: { [string]: string }?, defaults: { [string]: any }?, creatable: boolean?)
	CLASSES[name] = { Super = super, Props = props or {}, Defaults = defaults or {}, Creatable = creatable ~= false }
end
local SURF = "Enum.SurfaceType"
class("Instance", nil, { Name = "string", Archivable = "boolean" }, {}, false)
class("PVInstance", "Instance", {}, {}, false)
class("BasePart", "PVInstance", {
	Anchored = "boolean", Size = "Vector3", CFrame = "CFrame", Position = "Vector3", Orientation = "Vector3",
	Color = "Color3", BrickColor = "BrickColor", Material = "Enum.Material", MaterialVariant = "string",
	Transparency = "number", Reflectance = "number", CanCollide = "boolean", CanQuery = "boolean", CanTouch = "boolean",
	CastShadow = "boolean", Massless = "boolean", Locked = "boolean", PivotOffset = "CFrame", CollisionGroup = "string",
	TopSurface = SURF, BottomSurface = SURF, FrontSurface = SURF, BackSurface = SURF, LeftSurface = SURF, RightSurface = SURF,
	AssemblyLinearVelocity = "Vector3", AssemblyAngularVelocity = "Vector3", RootPriority = "number", LocalTransparencyModifier = "number",
	CustomPhysicalProperties = "any", EnableFluidForces = "boolean",
}, {
	Anchored = false, Size = v3(4, 1, 2), CFrame = CFrame.identity, Color = Color3.fromRGB(163, 162, 165),
	Material = Enum.Material.Plastic, Transparency = 0, Reflectance = 0, CanCollide = true, CanQuery = true, CanTouch = true,
	CastShadow = true, Massless = false, Locked = false, PivotOffset = CFrame.identity, MaterialVariant = "", CollisionGroup = "Default",
	TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
}, false)
class("FormFactorPart", "BasePart", {}, {}, false)
class("Part", "FormFactorPart", { Shape = "Enum.PartType" }, { Shape = Enum.PartType.Block })
class("SpawnLocation", "Part", { Neutral = "boolean", Duration = "number", AllowTeamChangeOnTouch = "boolean", Enabled = "boolean", TeamColor = "BrickColor" }, { Neutral = true, Duration = 10, Enabled = true })
class("WedgePart", "FormFactorPart")
class("CornerWedgePart", "BasePart")
class("TrussPart", "BasePart")
class("MeshPart", "BasePart", { MeshId = "string", TextureID = "string" }, {}, false)
class("Model", "PVInstance", { PrimaryPart = "Ref:BasePart", WorldPivot = "CFrame", LevelOfDetail = "any", ModelStreamingMode = "any" })
class("WorldRoot", "Model", {}, {}, false)
class("Workspace", "WorldRoot", { Gravity = "number", CurrentCamera = "any" }, { Gravity = 196.2 }, false)
class("Folder", "Instance")
class("Configuration", "Instance")
class("ModuleScript", "Instance", {}, {}, false)
class("Attachment", "Instance", { CFrame = "CFrame", Position = "Vector3", Orientation = "Vector3", Axis = "Vector3", SecondaryAxis = "Vector3", Visible = "boolean" }, { CFrame = CFrame.identity, Visible = false })
class("JointInstance", "Instance", { Part0 = "Ref:BasePart", Part1 = "Ref:BasePart", C0 = "CFrame", C1 = "CFrame", Enabled = "boolean" }, { C0 = CFrame.identity, C1 = CFrame.identity, Enabled = true }, false)
class("Weld", "JointInstance")
class("Motor", "JointInstance", { MaxVelocity = "number", DesiredAngle = "number", CurrentAngle = "number" }, { MaxVelocity = 0, DesiredAngle = 0, CurrentAngle = 0 })
class("Motor6D", "Motor", { Transform = "CFrame" }, { Transform = CFrame.identity })
class("WeldConstraint", "Instance", { Part0 = "Ref:BasePart", Part1 = "Ref:BasePart", Enabled = "boolean" }, { Enabled = true })
class("Light", "Instance", { Color = "Color3", Brightness = "number", Shadows = "boolean", Enabled = "boolean" }, { Color = Color3.new(1, 1, 1), Brightness = 1, Shadows = false, Enabled = true }, false)
class("PointLight", "Light", { Range = "number" }, { Range = 8 })
class("SpotLight", "Light", { Range = "number", Angle = "number", Face = "Enum.NormalId" }, { Range = 16, Angle = 90 })
class("SurfaceLight", "Light", { Range = "number", Angle = "number", Face = "Enum.NormalId" }, { Range = 16, Angle = 90 })
class("ParticleEmitter", "Instance", {
	Color = "ColorSequence", LightEmission = "number", LightInfluence = "number", Rate = "number", Lifetime = "NumberRange",
	Speed = "NumberRange", SpreadAngle = "Vector2", Rotation = "NumberRange", RotSpeed = "NumberRange", Size = "NumberSequence",
	Transparency = "NumberSequence", Acceleration = "Vector3", Shape = "Enum.ParticleEmitterShape", Texture = "string",
	ZOffset = "number", Enabled = "boolean", LockedToPart = "boolean", EmissionDirection = "Enum.NormalId", Drag = "number",
	Brightness = "number", Squash = "NumberSequence", VelocityInheritance = "number", TimeScale = "number",
	ShapeInOut = "any", ShapeStyle = "any", ShapeSurface = "any", ShapePartial = "number", Orientation = "any", FlipbookLayout = "any",
	FlipbookMode = "any", FlipbookFramerate = "NumberRange", WindAffectsDrag = "boolean",
}, { Rate = 5, Enabled = true, LightEmission = 0, LightInfluence = 0 })
class("Beam", "Instance", {
	Attachment0 = "Ref:Attachment", Attachment1 = "Ref:Attachment", Color = "ColorSequence", Width0 = "number", Width1 = "number",
	FaceCamera = "boolean", Segments = "number", CurveSize0 = "number", CurveSize1 = "number", LightInfluence = "number",
	LightEmission = "number", Transparency = "NumberSequence", Texture = "string", TextureLength = "number", TextureSpeed = "number",
	TextureMode = "any", Enabled = "boolean", Brightness = "number", ZOffset = "number",
}, { Enabled = true, Segments = 10, Width0 = 1, Width1 = 1 })
class("GuiBase2d", "Instance", {}, {}, false)
class("LayerCollector", "GuiBase2d", { Enabled = "boolean", ResetOnSpawn = "boolean", ZIndexBehavior = "any" }, { Enabled = true, ResetOnSpawn = true }, false)
class("SurfaceGuiBase", "LayerCollector", { Face = "Enum.NormalId", Adornee = "Ref:Instance", Active = "boolean" }, {}, false)
class("SurfaceGui", "SurfaceGuiBase", {
	SizingMode = "Enum.SurfaceGuiSizingMode", PixelsPerStud = "number", LightInfluence = "number", Brightness = "number",
	ZOffset = "number", AlwaysOnTop = "boolean", CanvasSize = "Vector2", ClipsDescendants = "boolean", MaxDistance = "number",
	ToolPunchThroughDistance = "number",
}, { Face = Enum.NormalId.Front, PixelsPerStud = 50, LightInfluence = 1, Brightness = 1 })
class("BillboardGui", "LayerCollector", {
	Size = "UDim2", StudsOffsetWorldSpace = "Vector3", StudsOffset = "Vector3", MaxDistance = "number", LightInfluence = "number",
	AlwaysOnTop = "boolean", Adornee = "Ref:Instance", ExtentsOffset = "Vector3", ExtentsOffsetWorldSpace = "Vector3",
	SizeOffset = "Vector2", Brightness = "number", ClipsDescendants = "boolean", DistanceLowerLimit = "number",
	DistanceUpperLimit = "number", DistanceStep = "number", Active = "boolean",
}, {})
class("GuiObject", "GuiBase2d", {
	BackgroundTransparency = "number", BackgroundColor3 = "Color3", Position = "UDim2", Size = "UDim2", Rotation = "number",
	AnchorPoint = "Vector2", ZIndex = "number", Visible = "boolean", BorderSizePixel = "number", LayoutOrder = "number",
	ClipsDescendants = "boolean", Active = "boolean", AutomaticSize = "any", SizeConstraint = "any",
}, { Visible = true, ZIndex = 1, BackgroundTransparency = 0, Rotation = 0 }, false)
class("TextLabel", "GuiObject", {
	Font = "Enum.Font", FontFace = "any", Text = "string", TextColor3 = "Color3", TextScaled = "boolean", TextSize = "number",
	TextWrapped = "boolean", TextStrokeTransparency = "number", TextStrokeColor3 = "Color3", TextTransparency = "number",
	TextXAlignment = "any", TextYAlignment = "any", RichText = "boolean", LineHeight = "number", MaxVisibleGraphemes = "number", TextTruncate = "Enum.TextTruncate",
}, { Text = "Label" })
class("Frame", "GuiObject", { Style = "any" }, {})
class("UIComponent", "Instance", {}, {}, false)
class("UIStroke", "UIComponent", { Color = "Color3", Thickness = "number", Transparency = "number", ApplyStrokeMode = "any", LineJoinMode = "any", Enabled = "boolean" }, { Thickness = 1, Enabled = true })
class("UIConstraint", "UIComponent", {}, {}, false)
class("UITextSizeConstraint", "UIConstraint", { MinTextSize = "number", MaxTextSize = "number" }, { MinTextSize = 1, MaxTextSize = 100 })
class("UICorner", "UIComponent", { CornerRadius = "UDim" })
class("Sky", "Instance", {
	CelestialBodiesShown = "boolean", StarCount = "number", MoonAngularSize = "number", SunAngularSize = "number",
	SkyboxBk = "string", SkyboxDn = "string", SkyboxFt = "string", SkyboxLf = "string", SkyboxRt = "string", SkyboxUp = "string",
	MoonTextureId = "string", SunTextureId = "string", SkyboxOrientation = "Vector3",
}, {})
class("Atmosphere", "Instance", { Density = "number", Offset = "number", Color = "Color3", Decay = "Color3", Glare = "number", Haze = "number" }, {})
class("PostEffect", "Instance", { Enabled = "boolean" }, { Enabled = true }, false)
class("BloomEffect", "PostEffect", { Intensity = "number", Size = "number", Threshold = "number" })
class("ColorCorrectionEffect", "PostEffect", { Saturation = "number", Contrast = "number", Brightness = "number", TintColor = "Color3" })
class("SunRaysEffect", "PostEffect", { Intensity = "number", Spread = "number" })
class("BlurEffect", "PostEffect", { Size = "number" })
class("DepthOfFieldEffect", "PostEffect", { FarIntensity = "number", FocusDistance = "number", InFocusRadius = "number", NearIntensity = "number" })
class("Lighting", "Instance", {
	ClockTime = "number", GeographicLatitude = "number", Brightness = "number", Ambient = "Color3", OutdoorAmbient = "Color3",
	ColorShift_Top = "Color3", ColorShift_Bottom = "Color3", EnvironmentDiffuseScale = "number", EnvironmentSpecularScale = "number",
	GlobalShadows = "boolean", ShadowSoftness = "number", ExposureCompensation = "number", FogEnd = "number", FogStart = "number",
	FogColor = "Color3", TimeOfDay = "string", Technology = "any",
}, { ClockTime = 14, FogEnd = 100000 }, false)
class("ReplicatedStorage", "Instance", {}, {}, false)
class("ServerScriptService", "Instance", {}, {}, false)
class("ServerStorage", "Instance", {}, {}, false)
class("CollectionService", "Instance", {}, {}, false)
class("DataModel", "Instance", {}, {}, false)

local function classOf(name: string): ClassDef
	return CLASSES[name]
end
local function isA(cname: string, want: string): boolean
	local c: string? = cname
	while c do
		if c == want then
			return true
		end
		c = CLASSES[c].Super
	end
	return false
end
local function findProp(cname: string, prop: string): (string?, any)
	local c: string? = cname
	while c do
		local def = CLASSES[c]
		local t = def.Props[prop]
		if t then
			local d: any = nil
			local cc: string? = cname
			while cc do
				local dv = CLASSES[cc].Defaults[prop]
				if dv ~= nil then
					d = dv
					break
				end
				cc = CLASSES[cc].Super
			end
			return t, d
		end
		c = def.Super
	end
	return nil, nil
end

type State = {
	Class: string,
	Props: { [string]: any },
	Children: { any },
	Parent: any,
	Attrs: { [string]: any },
	Tags: { [string]: boolean },
	Locked: boolean,
	Destroyed: boolean,
	Module: string?,
	Scale: number,
	Seq: number,
	Loc: string?,
}
local S: { [any]: State } = setmetatable({}, { __mode = "k" }) :: any
SIM.State = S
local Imt = {}
Imt.__type = "Instance"
local M = {} -- methods
local CSM = {} -- CollectionService methods
-- other service methods (probes may add more via SIM.ServiceMethods[class][name] = fn)
local SVCM: { [string]: { [string]: any } } = {
	RunService = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
	},
}
SIM.ServiceMethods = SVCM
local seq = 0

local function isInst(v: any): boolean
	return getmetatable(v) == Imt
end
SIM.isInst = isInst

local function typeOk(tag: string, v: any): boolean
	if tag == "any" then
		return true
	elseif tag == "number" or tag == "string" or tag == "boolean" then
		return type(v) == tag
	elseif string.sub(tag, 1, 5) == "Enum." then
		return isEnum(v, string.sub(tag, 6))
	elseif string.sub(tag, 1, 4) == "Ref:" then
		return v == nil or (isInst(v) and isA(S[v].Class, string.sub(tag, 5)))
	end
	return typeof(v) == tag
end

local function newInst(cname: string)
	seq += 1
	local o = setmetatable({}, Imt)
	S[o] = { Class = cname, Props = { Name = cname }, Children = {}, Parent = nil, Attrs = {}, Tags = {}, Locked = false, Destroyed = false, Module = nil, Scale = 1, Seq = seq }
	return o
end

local function fullName(o): string
	local parts = {}
	local cur = o
	while cur do
		local st = S[cur]
		if st.Class == "DataModel" then
			break
		end
		table.insert(parts, 1, st.Props.Name)
		cur = st.Parent
	end
	return table.concat(parts, ".")
end
SIM.FullName = fullName

local function findChild(o, name: string)
	for _, c in S[o].Children do
		if S[c].Props.Name == name then
			return c
		end
	end
	return nil
end

Imt.__index = function(o, k)
	local st = S[o]
	if k == "ClassName" then
		return st.Class
	elseif k == "Parent" then
		return st.Parent
	end
	local v = st.Props[k]
	if v ~= nil then
		return v
	end
	local tag, def = findProp(st.Class, k)
	if tag then
		if k == "Position" and isA(st.Class, "BasePart") then
			return (st.Props.CFrame or CFrame.identity).Position
		elseif k == "Position" and st.Class == "Attachment" then
			return (st.Props.CFrame or CFrame.identity).Position
		end
		return def
	end
	-- read-only computed members
	if k == "WorldCFrame" and st.Class == "Attachment" then
		local p = st.Parent
		local base = if p and isA(S[p].Class, "BasePart") then p.CFrame else CFrame.identity
		return base * o.CFrame
	elseif k == "WorldPosition" and st.Class == "Attachment" then
		return o.WorldCFrame.Position
	elseif k == "Mass" and isA(st.Class, "BasePart") then
		local s = o.Size
		return s.X * s.Y * s.Z * 0.7
	end
	if st.Class == "CollectionService" and CSM[k] then
		return CSM[k]
	end
	local svc = SVCM[st.Class] or (if st.Locked then SVCM[st.Props.Name] else nil)
	if svc and svc[k] then
		return svc[k]
	end
	local m = M[k]
	if m then
		return m
	end
	local c = findChild(o, k)
	if c then
		return c
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(k), st.Class, fullName(o)), 2)
end

local function setParent(o, p)
	local st = S[o]
	if st.Locked then
		error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s", st.Props.Name, if p then S[p].Props.Name else "NULL"), 3)
	end
	if p ~= nil then
		if not isInst(p) then
			error("Unable to assign property Parent. Instance expected, got " .. typeof(p), 3)
		end
		local cur = p
		while cur do
			if cur == o then
				error(string.format("Attempt to set %s as its own parent", fullName(o)), 3)
			end
			cur = S[cur].Parent
		end
	end
	local old = st.Parent
	if old == p then
		return
	end
	if old then
		local ch = S[old].Children
		local i = table.find(ch, o)
		if i then
			table.remove(ch, i)
		end
	end
	st.Parent = p
	if p then
		table.insert(S[p].Children, o)
	end
end

local function checkPartValue(o, k: string, v: any)
	if k == "Size" then
		if isnan(v.X) or isnan(v.Y) or isnan(v.Z) then
			SIM.Warn("NaN size", "Size is NaN")
		elseif math.min(v.X, v.Y, v.Z) < 0.001 then
			SIM.Warn("tiny size", string.format("part size %s has an axis < 0.001 (Roblox clamps it)", tostring(v)))
		elseif math.max(v.X, v.Y, v.Z) > 2048 then
			SIM.Warn("huge size", string.format("part size %s exceeds 2048 on an axis (Roblox clamps it to 2048)", tostring(v)))
		end
	elseif k == "CFrame" then
		if SIM.CFHasNaN(v) then
			SIM.Warn("NaN CFrame", "CFrame contains NaN")
		end
	elseif k == "Position" then
		if isnan(v.X) or isnan(v.Y) or isnan(v.Z) then
			SIM.Warn("NaN position", "Position is NaN")
		end
	elseif k == "Transparency" or k == "Reflectance" then
		if v < 0 or v > 1 then
			SIM.Warn("range", k .. " outside 0..1: " .. tostring(v))
		end
	end
end

Imt.__newindex = function(o, k, v)
	local st = S[o]
	if st.Destroyed and k ~= "Parent" then
		-- Roblox allows writes to destroyed instances; nothing to do
	end
	if k == "Parent" then
		setParent(o, v)
		return
	elseif k == "ClassName" then
		error("Unable to assign property ClassName. Property is read only", 2)
	end
	local tag = findProp(st.Class, k)
	if not tag then
		error(string.format("%s is not a valid member of %s \"%s\"", tostring(k), st.Class, fullName(o)), 2)
	end
	if not typeOk(tag, v) then
		local want = if string.sub(tag, 1, 4) == "Ref:" then string.sub(tag, 5) elseif string.sub(tag, 1, 5) == "Enum." then "EnumItem (" .. tag .. ")" else tag
		error(string.format("Unable to assign property %s. %s expected, got %s", k, want, typeof(v)), 2)
	end
	if k == "Name" and #v > 100 then
		SIM.Warn("long name", "Name longer than 100 characters")
	end
	if isA(st.Class, "BasePart") then
		checkPartValue(o, k, v)
		if k == "Position" then
			local c = st.Props.CFrame or CFrame.identity
			st.Props.CFrame = cf(v.X, v.Y, v.Z, c._m)
			return
		elseif k == "Size" then
			-- engine limits: 0.001..2048 per axis
			v = v3(math.clamp(v.X, 0.001, 2048), math.clamp(v.Y, 0.001, 2048), math.clamp(v.Z, 0.001, 2048))
		end
	elseif st.Class == "Attachment" and k == "Position" then
		local c = st.Props.CFrame or CFrame.identity
		st.Props.CFrame = cf(v.X, v.Y, v.Z, c._m)
		return
	elseif (k == "CFrame" or k == "C0" or k == "C1" or k == "Transform" or k == "WorldPivot") and SIM.CFHasNaN(v) then
		SIM.Warn("NaN CFrame", k .. " contains NaN")
	end
	if k == "PrimaryPart" and v ~= nil then
		local cur = S[v].Parent
		local ok = false
		while cur do
			if cur == o then
				ok = true
				break
			end
			cur = S[cur].Parent
		end
		if not ok then
			SIM.Warn("PrimaryPart", "PrimaryPart is not a descendant of the Model (Roblox ignores it)")
			return
		end
	end
	st.Props[k] = v
end
Imt.__tostring = function(o)
	return S[o].Props.Name
end

function M.IsA(o, c: string)
	return isA(S[o].Class, c)
end
function M.FindFirstChild(o, name: string, recursive: boolean?)
	if recursive then
		for _, d in M.GetDescendants(o) do
			if S[d].Props.Name == name then
				return d
			end
		end
		return nil
	end
	return findChild(o, name)
end
function M.WaitForChild(o, name: string)
	local c = findChild(o, name)
	if not c then
		error("WaitForChild would wait forever: " .. fullName(o) .. "." .. name, 2)
	end
	return c
end
function M.FindFirstChildOfClass(o, c: string)
	for _, ch in S[o].Children do
		if S[ch].Class == c then
			return ch
		end
	end
	return nil
end
function M.FindFirstChildWhichIsA(o, c: string, recursive: boolean?)
	local list = if recursive then M.GetDescendants(o) else S[o].Children
	for _, ch in list do
		if isA(S[ch].Class, c) then
			return ch
		end
	end
	return nil
end
function M.FindFirstAncestorOfClass(o, c: string)
	local cur = S[o].Parent
	while cur do
		if S[cur].Class == c then
			return cur
		end
		cur = S[cur].Parent
	end
	return nil
end
function M.FindFirstAncestor(o, name: string)
	local cur = S[o].Parent
	while cur do
		if S[cur].Props.Name == name then
			return cur
		end
		cur = S[cur].Parent
	end
	return nil
end
function M.FindFirstAncestorWhichIsA(o, c: string)
	local cur = S[o].Parent
	while cur do
		if isA(S[cur].Class, c) then
			return cur
		end
		cur = S[cur].Parent
	end
	return nil
end
function M.GetChildren(o)
	return table.clone(S[o].Children)
end
function M.GetDescendants(o)
	local out = {}
	local function walk(x)
		for _, c in S[x].Children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(o)
	return out
end
function M.IsDescendantOf(o, a)
	local cur = S[o].Parent
	while cur do
		if cur == a then
			return true
		end
		cur = S[cur].Parent
	end
	return false
end
function M.IsAncestorOf(o, d)
	return M.IsDescendantOf(d, o)
end
function M.GetFullName(o)
	return fullName(o)
end
function M.Destroy(o)
	local st = S[o]
	for _, c in table.clone(st.Children) do
		M.Destroy(c)
	end
	setParent(o, nil)
	st.Locked = true
	st.Destroyed = true
end
function M.ClearAllChildren(o)
	for _, c in table.clone(S[o].Children) do
		M.Destroy(c)
	end
end
function M.Clone(o)
	local st = S[o]
	local n = newInst(st.Class)
	local ns = S[n]
	ns.Props = table.clone(st.Props)
	ns.Attrs = table.clone(st.Attrs)
	ns.Tags = table.clone(st.Tags)
	for _, c in st.Children do
		local cc = M.Clone(c)
		setParent(cc, n)
	end
	return n
end
local ATTR_TYPES = { number = true, string = true, boolean = true, Vector3 = true, Vector2 = true, Color3 = true, CFrame = true, UDim = true, UDim2 = true, NumberRange = true, NumberSequence = true, ColorSequence = true, BrickColor = true, EnumItem = true }
function M.SetAttribute(o, name: string, v: any)
	if type(name) ~= "string" then
		error("SetAttribute: attribute name must be a string", 2)
	end
	if #name > 100 or not string.match(name, "^[%w_]+$") or string.sub(name, 1, 3) == "RBX" then
		error("SetAttribute: invalid attribute name '" .. name .. "'", 2)
	end
	if v ~= nil and not ATTR_TYPES[typeof(v)] then
		error("SetAttribute: " .. typeof(v) .. " is not a supported attribute type", 2)
	end
	S[o].Attrs[name] = v
end
function M.GetAttribute(o, name: string)
	return S[o].Attrs[name]
end
function M.GetAttributes(o)
	return table.clone(S[o].Attrs)
end
function M.AddTag(o, tag: string)
	S[o].Tags[tag] = true
end
function M.RemoveTag(o, tag: string)
	S[o].Tags[tag] = nil
end
function M.HasTag(o, tag: string)
	return S[o].Tags[tag] == true
end
function M.GetTags(o)
	local out = {}
	for t in S[o].Tags do
		table.insert(out, t)
	end
	return out
end
function M.GetPropertyChangedSignal()
	return { Connect = function()
		return { Disconnect = function() end }
	end }
end

-- PVInstance / Model
local function partsOf(o)
	local out = {}
	if isA(S[o].Class, "BasePart") then
		table.insert(out, o)
	end
	for _, d in M.GetDescendants(o) do
		if isA(S[d].Class, "BasePart") then
			table.insert(out, d)
		end
	end
	return out
end
local function boundsOf(parts): (any, any)
	local x1, y1, z1, x2, y2, z2 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, p in parts do
		local a, b, c, d, e, f = SIM.AABB(p.CFrame, p.Size)
		x1, y1, z1 = math.min(x1, a), math.min(y1, b), math.min(z1, c)
		x2, y2, z2 = math.max(x2, d), math.max(y2, e), math.max(z2, f)
	end
	if x1 == math.huge then
		return CFrame.identity, Vector3.zero
	end
	return CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2), v3(x2 - x1, y2 - y1, z2 - z1)
end
function M.GetPivot(o)
	local st = S[o]
	if isA(st.Class, "BasePart") then
		return o.CFrame * o.PivotOffset
	end
	if st.Class == "Model" or isA(st.Class, "Model") then
		local pp = st.Props.PrimaryPart
		if pp then
			return pp.CFrame * pp.PivotOffset
		end
		if st.Props.WorldPivot then
			return st.Props.WorldPivot
		end
		local c = boundsOf(partsOf(o))
		return c
	end
	error("GetPivot is not a valid member of " .. st.Class, 2)
end
function M.PivotTo(o, target)
	if not isCF(target) then
		error("PivotTo: CFrame expected, got " .. typeof(target), 2)
	end
	local st = S[o]
	local pivot = M.GetPivot(o)
	local delta = target * pivot:Inverse()
	for _, p in partsOf(o) do
		S[p].Props.CFrame = delta * p.CFrame
	end
	if isA(st.Class, "Model") and not st.Props.PrimaryPart then
		st.Props.WorldPivot = target
	end
end
function M.GetBoundingBox(o)
	return boundsOf(partsOf(o))
end
function M.GetExtentsSize(o)
	local _, s = boundsOf(partsOf(o))
	return s
end
function M.GetScale(o)
	return S[o].Scale
end
function M.ScaleTo(o, s: number)
	if type(s) ~= "number" or s <= 0 or s ~= s then
		error("ScaleTo: scale factor must be a positive number", 2)
	end
	local st = S[o]
	local ratio = s / st.Scale
	local pivot = M.GetPivot(o)
	local function scalePos(c)
		return cf(c._x * ratio, c._y * ratio, c._z * ratio, c._m)
	end
	for _, d in M.GetDescendants(o) do
		local ds = S[d]
		if isA(ds.Class, "BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			ds.Props.CFrame = pivot * scalePos(rel)
			ds.Props.Size = d.Size * ratio
			ds.Props.PivotOffset = scalePos(d.PivotOffset)
		elseif ds.Class == "Attachment" then
			ds.Props.CFrame = scalePos(d.CFrame)
		elseif isA(ds.Class, "JointInstance") then
			ds.Props.C0 = scalePos(d.C0)
			ds.Props.C1 = scalePos(d.C1)
		end
	end
	st.Scale = s
end

-- Services, DataModel, script tree
local Services: { [string]: any } = {}
game = newInst("DataModel")
S[game].Props.Name = "Game"
S[game].Locked = true
local function service(name: string)
	local s = Services[name]
	if not s then
		local cname = if CLASSES[name] then name else "Folder"
		s = newInst(cname)
		S[s].Props.Name = name
		setParent(s, game)
		S[s].Locked = true
		Services[name] = s
	end
	return s
end
local KNOWN_SERVICES = { Workspace = true, Lighting = true, ReplicatedStorage = true, ServerScriptService = true, ServerStorage = true, CollectionService = true, Players = true, RunService = true, TweenService = true, SoundService = true, StarterGui = true, StarterPlayer = true, HttpService = true, DataStoreService = true, MarketplaceService = true, BadgeService = true, Debris = true, TextService = true }
function M.GetService(o, name: string)
	if o ~= game then
		error("GetService is not a valid member of " .. S[o].Class, 2)
	end
	if not KNOWN_SERVICES[name] then
		error("'" .. tostring(name) .. "' is not a valid Service name", 2)
	end
	return service(name)
end
workspace = service("Workspace")
SIM.Workspace = workspace

-- CollectionService methods (only on that service)
function CSM.AddTag(_, inst, tag: string)
	if not isInst(inst) or type(tag) ~= "string" then
		error("CollectionService:AddTag expects (Instance, string)", 2)
	end
	S[inst].Tags[tag] = true
end
function CSM.RemoveTag(_, inst, tag: string)
	S[inst].Tags[tag] = nil
end
function CSM.HasTag(_, inst, tag: string)
	return S[inst].Tags[tag] == true
end
function CSM.GetTagged(_, tag: string)
	local out = {}
	for inst, st in S do
		if st.Tags[tag] and not st.Destroyed then
			table.insert(out, inst)
		end
	end
	return out
end

Instance = {}
function Instance.new(cname: string, parent: any?)
	local def = CLASSES[cname]
	if not def or not def.Creatable then
		error("Unable to create an Instance of type \"" .. tostring(cname) .. "\"", 2)
	end
	local o = newInst(cname)
	if isA(cname, "BasePart") then
		S[o].Loc = SIM.CallerLoc()
	end
	if parent then
		setParent(o, parent)
	end
	return o
end

-- Register a module source so that `require(instance)` works the Roblox way.
local MODULE_SRC: { [any]: { Path: string, Src: string } } = {}
local MODULE_CACHE: { [any]: any } = {}
local LOADING: { [any]: boolean } = {}
function SIM.Mount(parentPath: { string }, name: string, filePath: string, src: string)
	local cur = game
	for i, seg in parentPath do
		local nxtI = findChild(cur, seg)
		if not nxtI then
			if i == 1 then
				nxtI = service(seg)
			else
				nxtI = newInst("Folder")
				S[nxtI].Props.Name = seg
				setParent(nxtI, cur)
			end
		end
		cur = nxtI
	end
	local ms = newInst("ModuleScript")
	S[ms].Props.Name = name
	setParent(ms, cur)
	MODULE_SRC[ms] = { Path = filePath, Src = src }
	return ms
end
function require(ms: any)
	if MODULE_CACHE[ms] ~= nil then
		return MODULE_CACHE[ms]
	end
	local info = MODULE_SRC[ms]
	if not info then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	if LOADING[ms] then
		error("Requested module was required recursively: " .. info.Path, 2)
	end
	LOADING[ms] = true
	local fn, err = loadstring(info.Src, "=" .. info.Path)
	if not fn then
		error("syntax error: " .. tostring(err), 0)
	end
	setfenv(fn, setmetatable({ script = ms }, { __index = GENV }))
	local res = table.pack(fn())
	LOADING[ms] = nil
	if res.n ~= 1 then
		error("Module code did not return exactly one value: " .. info.Path, 2)
	end
	MODULE_CACHE[ms] = res[1]
	return res[1]
end
function SIM.Path(path: string)
	local cur = game
	for seg in string.gmatch(path, "[^%.]+") do
		cur = findChild(cur, seg) or error("no such instance: " .. path)
	end
	return cur
end
