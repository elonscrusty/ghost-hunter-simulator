--!strict
-- Hunter portraits. Face(): cheap 2D portrait built from Frames (used in big grids).
-- Viewport(): real 3D model in a ViewportFrame (used for the index detail / inspect view).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GH = ReplicatedStorage:WaitForChild("GH")
local Config = require(GH.Config)
local HunterRig = require(GH.Rigs.HunterRig)
local Kit = require(script.Parent.Kit)

local Portrait = {}

Portrait.ToolIcon = {
	Flashlight = "🔦",
	Vacuum = "🌀",
	Scanner = "📟",
	Blaster = "⚡",
	Cannon = "💥",
	Lantern = "🏮",
	Staff = "🪄",
	Projector = "📡",
	Megaphone = "📣",
	Wand = "✨",
	Orb = "🔮",
	Spyglass = "🔭",
	Sword = "⚔️",
	Trident = "🔱",
	Wrench = "🔧",
} :: { [string]: string }

local GOLD = Color3.fromRGB(255, 205, 60)
local RED = Color3.fromRGB(230, 50, 70)
local NAVY = Color3.fromRGB(35, 50, 120)
local WHITE = Color3.new(1, 1, 1)
local BLUE = Color3.fromRGB(40, 80, 170)
local STEEL = Color3.fromRGB(120, 125, 140)

local function shade(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- plain (optionally rounded) rectangle, anchored at its centre
local function rect(parent: Instance, size: UDim2, pos: UDim2, color: Color3, z: number, radius: number?): Frame
	local f: Frame = Kit.new("Frame", {
		Size = size,
		Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	if radius then
		Kit.Corner(f, UDim.new(radius, 0))
	end
	return f
end

local function circle(parent: Instance, size: UDim2, pos: UDim2, color: Color3, z: number): Frame
	local f: Frame = Kit.new("Frame", {
		Size = size,
		Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	Kit.Corner(f, UDim.new(1, 0))
	return f
end

-- Fills `parent` (a square frame) with a cartoon face. silhouette = undiscovered.
function Portrait.Face(parent: GuiObject, hunterId: string, silhouette: boolean?)
	local def = Config.Hunters[hunterId]
	if not def then
		return
	end
	local L = def.Look
	local z = parent.ZIndex + 1
	local dark = Color3.fromRGB(20, 12, 35)
	local function col(c: Color3): Color3
		return if silhouette then dark else c
	end
	local holder: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z, Parent = parent })
	-- shoulders / shirt
	local body = circle(holder, UDim2.fromScale(0.78, 0.5), UDim2.fromScale(0.5, 1.02), col(L.Shirt), z)
	body.AnchorPoint = Vector2.new(0.5, 1)
	-- back item peeking out
	if L.Back == "Wings" or L.Back == "Cape" then
		local w = circle(holder, UDim2.fromScale(0.95, 0.45), UDim2.fromScale(0.5, 0.82), col(L.BackColor or L.Shirt), z - 0)
		w.ZIndex = z
		body.ZIndex = z + 1
	elseif L.Back == "Shield" or L.Back == "LifeRing" or L.Back == "MedKit" then
		-- peeking out from behind a shoulder
		local bc = L.BackColor or L.Shirt
		body.ZIndex = z + 1
		if L.Back == "Shield" then
			local sh = circle(holder, UDim2.fromScale(0.36, 0.38), UDim2.fromScale(0.84, 0.76), col(bc), z)
			Kit.Stroke(sh, 2, col(Color3.fromRGB(150, 155, 170)))
			rect(sh, UDim2.fromScale(0.16, 0.7), UDim2.fromScale(0.5, 0.5), col(GOLD), z)
			rect(sh, UDim2.fromScale(0.7, 0.16), UDim2.fromScale(0.5, 0.45), col(GOLD), z)
		elseif L.Back == "LifeRing" then
			local lr = circle(holder, UDim2.fromScale(0.34, 0.34), UDim2.fromScale(0.16, 0.74), col(bc), z)
			lr.BackgroundTransparency = 1
			Kit.Stroke(lr, 5, col(bc))
			local inner = circle(lr, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.5, 0.5), col(WHITE), z)
			inner.BackgroundTransparency = 1
			Kit.Stroke(inner, 1.5, col(WHITE))
		else
			local mk = rect(holder, UDim2.fromScale(0.3, 0.26), UDim2.fromScale(0.84, 0.72), col(bc), z, 0.2)
			Kit.Stroke(mk, 1.5, col(shade(bc, 0.7)))
			rect(mk, UDim2.fromScale(0.5, 0.16), UDim2.fromScale(0.5, 0.4), col(RED), z)
			rect(mk, UDim2.fromScale(0.16, 0.5), UDim2.fromScale(0.5, 0.4), col(RED), z)
		end
	elseif L.Back == "Balloons" then
		local cols = { L.BackColor or L.Shirt, Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 215, 70) }
		local spots = { Vector2.new(0.12, 0.3), Vector2.new(0.88, 0.22), Vector2.new(0.72, 0.1) }
		for i, p in spots do
			rect(holder, UDim2.fromScale(0.012, 0.3), UDim2.fromScale(p.X, p.Y + 0.27), col(WHITE), z) -- string
			circle(holder, UDim2.fromScale(0.2, 0.24), UDim2.fromScale(p.X, p.Y), col(cols[i]), z + 1)
		end
	elseif L.Back == "Orbs" then
		for _, p in { Vector2.new(0.1, 0.62), Vector2.new(0.92, 0.42), Vector2.new(0.12, 0.2) } do
			local o = circle(holder, UDim2.fromScale(0.13, 0.13), UDim2.fromScale(p.X, p.Y), col(L.BackColor or L.Shirt), z + 1)
			if not silhouette then
				Kit.Stroke(o, 2, WHITE)
			end
		end
	end
	-- head
	local head = circle(holder, UDim2.fromScale(0.64, 0.6), UDim2.fromScale(0.5, 0.46), col(L.Skin), z + 2)
	-- hair cap (top half)
	if L.HairStyle ~= "None" then
		local hair = circle(head, UDim2.fromScale(1.08, 0.62), UDim2.fromScale(0.5, 0.18), col(L.Hair), z + 3)
		if L.HairStyle == "Spiky" then
			for i = -1, 1 do
				local s = circle(head, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.5 + i * 0.28, -0.05), col(L.Hair), z + 3)
				s.Rotation = 45
				local c = s:FindFirstChildOfClass("UICorner")
				if c then
					c.CornerRadius = UDim.new(0.15, 0)
				end
			end
		elseif L.HairStyle == "Puff" then
			circle(head, UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.2, 0.15), col(L.Hair), z + 3)
			circle(head, UDim2.fromScale(0.5, 0.45), UDim2.fromScale(0.8, 0.15), col(L.Hair), z + 3)
		elseif L.HairStyle == "Long" or L.HairStyle == "Bob" then
			circle(head, UDim2.fromScale(0.28, 0.75), UDim2.fromScale(0.02, 0.5), col(L.Hair), z + 1)
			circle(head, UDim2.fromScale(0.28, 0.75), UDim2.fromScale(0.98, 0.5), col(L.Hair), z + 1)
		end
		hair.ZIndex = z + 3
	end
	-- hat
	if L.Hat and L.Hat ~= "Goggles" and L.Hat ~= "Visor" then
		local hc = col(L.HatColor or L.Shirt)
		if L.Hat == "Halo" then
			local halo = circle(head, UDim2.fromScale(0.7, 0.18), UDim2.fromScale(0.5, -0.12), hc, z + 4)
			Kit.Stroke(halo, 2, if silhouette then dark else Color3.fromRGB(255, 255, 200))
		elseif L.Hat == "Mortarboard" then
			local top: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1.1, 0.14), Position = UDim2.fromScale(0.5, 0.0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = hc, ZIndex = z + 4, Parent = head })
			top.Rotation = -4
		elseif L.Hat == "Hood" then
			local hood = circle(holder, UDim2.fromScale(0.82, 0.74), UDim2.fromScale(0.5, 0.44), hc, z + 1)
			hood.ZIndex = z + 1
		elseif L.Hat == "TopHat" then
			local base = L.HatColor or L.Shirt
			local bandC = if base.R + base.G + base.B > 1.6 then shade(base, 0.35) else GOLD
			rect(head, UDim2.fromScale(0.62, 0.42), UDim2.fromScale(0.5, -0.08), hc, z + 4, 0.08)
			rect(head, UDim2.fromScale(0.64, 0.09), UDim2.fromScale(0.5, 0.06), col(bandC), z + 5)
			rect(head, UDim2.fromScale(1.15, 0.1), UDim2.fromScale(0.5, 0.14), hc, z + 5, 1)
		elseif L.Hat == "Jester" then
			local alt = col(GOLD)
			circle(head, UDim2.fromScale(1.04, 0.5), UDim2.fromScale(0.5, 0.1), hc, z + 4)
			for _, s in { -1, 1 } do
				local pt = rect(head, UDim2.fromScale(0.3, 0.42), UDim2.fromScale(0.5 + 0.36 * s, -0.04), if s < 0 then hc else alt, z + 4, 0.5)
				pt.Rotation = 40 * s
				circle(head, UDim2.fromScale(0.15, 0.16), UDim2.fromScale(0.5 + 0.6 * s, -0.2), if s < 0 then alt else hc, z + 5) -- bell
			end
		elseif L.Hat == "NurseCap" then
			local cap = rect(head, UDim2.fromScale(0.62, 0.24), UDim2.fromScale(0.5, 0.02), hc, z + 4, 0.2)
			Kit.Stroke(cap, 1.5, col(Color3.fromRGB(200, 205, 215)))
			rect(head, UDim2.fromScale(0.16, 0.05), UDim2.fromScale(0.5, 0.02), col(RED), z + 5)
			rect(head, UDim2.fromScale(0.05, 0.17), UDim2.fromScale(0.5, 0.02), col(RED), z + 5)
		elseif L.Hat == "HeadMirror" then
			rect(head, UDim2.fromScale(1.04, 0.07), UDim2.fromScale(0.5, 0.25), col(shade(L.HatColor or L.Shirt, 0.45)), z + 4)
			local m = circle(head, UDim2.fromScale(0.3, 0.32), UDim2.fromScale(0.66, 0.2), hc, z + 5)
			Kit.Stroke(m, 2, col(Color3.fromRGB(120, 125, 140)))
			circle(m, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.5, 0.5), col(Color3.fromRGB(40, 40, 55)), z + 6)
		elseif L.Hat == "SailorCap" then
			local cap = rect(head, UDim2.fromScale(0.66, 0.3), UDim2.fromScale(0.5, -0.04), hc, z + 4, 0.3)
			Kit.Stroke(cap, 1.5, col(Color3.fromRGB(190, 200, 215)))
			rect(head, UDim2.fromScale(0.86, 0.12), UDim2.fromScale(0.5, 0.1), hc, z + 5, 1)
			rect(head, UDim2.fromScale(0.86, 0.04), UDim2.fromScale(0.5, 0.1), col(NAVY), z + 6)
		elseif L.Hat == "Bandana" then
			circle(head, UDim2.fromScale(1.04, 0.5), UDim2.fromScale(0.5, 0.1), hc, z + 4)
			circle(head, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.96, 0.24), hc, z + 4) -- knot
			local tail = rect(head, UDim2.fromScale(0.1, 0.26), UDim2.fromScale(1.02, 0.4), hc, z + 3, 0.4)
			tail.Rotation = -20
			for _, p in { Vector2.new(0.3, 0.02), Vector2.new(0.55, 0.14), Vector2.new(0.74, -0.02) } do
				circle(head, UDim2.fromScale(0.08, 0.08), UDim2.fromScale(p.X, p.Y), col(WHITE), z + 5)
			end
		elseif L.Hat == "Tricorn" then
			circle(head, UDim2.fromScale(0.72, 0.42), UDim2.fromScale(0.5, -0.02), hc, z + 4)
			local brim = rect(head, UDim2.fromScale(1.25, 0.2), UDim2.fromScale(0.5, 0.12), hc, z + 5, 0.5)
			Kit.Stroke(brim, 2, col(GOLD))
			for _, s in { -1, 1 } do
				local corner = rect(head, UDim2.fromScale(0.26, 0.28), UDim2.fromScale(0.5 + 0.56 * s, 0.03), hc, z + 5, 0.15)
				corner.Rotation = 45
			end
		elseif L.Hat == "KnightHelm" then
			-- plume behind, helm over the top and sides, a visor slit, face open
			local plumeC = L.Shirt
			circle(head, UDim2.fromScale(0.22, 0.36), UDim2.fromScale(0.5, -0.12), col(plumeC), z + 3)
			local helm = circle(head, UDim2.fromScale(1.14, 0.62), UDim2.fromScale(0.5, 0.14), hc, z + 4)
			Kit.Stroke(helm, 2, col(shade(L.HatColor or L.Shirt, 0.6)))
			for _, x in { 0.06, 0.94 } do
				rect(head, UDim2.fromScale(0.16, 0.42), UDim2.fromScale(x, 0.55), hc, z + 4, 0.4) -- cheek guards
			end
			rect(head, UDim2.fromScale(0.56, 0.05), UDim2.fromScale(0.5, 0.22), col(Color3.fromRGB(30, 25, 40)), z + 5)
		elseif L.Hat == "Wizard" then
			local cone = rect(head, UDim2.fromScale(0.38, 0.4), UDim2.fromScale(0.5, 0.0), hc, z + 4)
			cone.Rotation = 45
			rect(head, UDim2.fromScale(1.2, 0.14), UDim2.fromScale(0.5, 0.22), hc, z + 5, 1)
			local star = rect(head, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.56, -0.02), col(GOLD), z + 5)
			star.Rotation = 45
		elseif L.Hat == "Crown" then
			rect(head, UDim2.fromScale(0.62, 0.16), UDim2.fromScale(0.5, 0.04), hc, z + 4)
			for i = -1, 1 do
				local pt = rect(head, UDim2.fromScale(0.14, 0.15), UDim2.fromScale(0.5 + i * 0.22, -0.06), hc, z + 4)
				pt.Rotation = 45
			end
			circle(head, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.5, 0.04), col(RED), z + 5)
		elseif L.Hat == "Crystal" then
			for i = -2, 2 do
				local s = if i == 0 then 0.17 else 0.11
				local g = rect(head, UDim2.fromScale(s, s * 1.07), UDim2.fromScale(0.5 + i * 0.2, -0.04 + math.abs(i) * 0.05), hc, z + 4)
				g.Rotation = 45
				if not silhouette then
					Kit.Stroke(g, 1.5, WHITE)
				end
			end
		elseif L.Hat == "Pith" then
			local base = L.HatColor or L.Shirt
			circle(head, UDim2.fromScale(0.8, 0.5), UDim2.fromScale(0.5, 0.02), hc, z + 4) -- dome
			rect(head, UDim2.fromScale(0.82, 0.07), UDim2.fromScale(0.5, 0.16), col(shade(base, 0.55)), z + 5) -- band
			rect(head, UDim2.fromScale(1.3, 0.1), UDim2.fromScale(0.5, 0.24), hc, z + 5, 1) -- brim
			circle(head, UDim2.fromScale(0.1, 0.08), UDim2.fromScale(0.5, -0.23), hc, z + 4) -- button
		elseif L.Hat == "Earmuffs" then
			local base = L.HatColor or L.Shirt
			local bandC = col(shade(base, 0.55))
			rect(head, UDim2.fromScale(0.8, 0.07), UDim2.fromScale(0.5, -0.04), bandC, z + 4, 1)
			for _, s in { -1, 1 } do
				local side = rect(head, UDim2.fromScale(0.07, 0.42), UDim2.fromScale(0.5 + 0.43 * s, 0.17), bandC, z + 4, 1)
				side.Rotation = -18 * s
				local muff = circle(head, UDim2.fromScale(0.3, 0.32), UDim2.fromScale(0.5 + 0.48 * s, 0.48), hc, z + 5)
				if not silhouette then
					Kit.Stroke(muff, 2, Color3.new(1, 1, 1):Lerp(base, 0.5))
				end
			end
		elseif L.Hat == "Nemes" then
			local base = L.HatColor or L.Shirt
			local isGold = base.R > 0.8 and base.G > 0.6 and base.B < 0.55
			local stripe = col(if isGold then BLUE else GOLD)
			for _, s in { -1, 1 } do
				local lap = rect(head, UDim2.fromScale(0.22, 0.75), UDim2.fromScale(0.5 + 0.46 * s, 0.62), hc, z + 4, 0.2) -- lappet
				lap.Rotation = 4 * s
				for _, y in { 0.35, 0.65 } do
					rect(lap, UDim2.fromScale(1, 0.08), UDim2.fromScale(0.5, y), stripe, z + 5)
				end
			end
			circle(head, UDim2.fromScale(1.1, 0.6), UDim2.fromScale(0.5, 0.12), hc, z + 4) -- cap
			rect(head, UDim2.fromScale(0.95, 0.05), UDim2.fromScale(0.5, 0.05), stripe, z + 5)
			rect(head, UDim2.fromScale(1.05, 0.05), UDim2.fromScale(0.5, 0.27), stripe, z + 5)
			circle(head, UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.5, -0.12), col(GOLD), z + 6) -- cobra
		elseif L.Hat == "Propeller" then
			circle(head, UDim2.fromScale(1.04, 0.5), UDim2.fromScale(0.5, 0.1), hc, z + 4)
			rect(head, UDim2.fromScale(0.08, 0.48), UDim2.fromScale(0.5, 0.11), col(GOLD), z + 5) -- stripe
			rect(head, UDim2.fromScale(0.94, 0.07), UDim2.fromScale(0.5, 0.3), col(GOLD), z + 5, 1) -- band
			rect(head, UDim2.fromScale(0.04, 0.16), UDim2.fromScale(0.5, -0.2), col(STEEL), z + 4) -- post
			for _, s in { -1, 1 } do
				local blade = rect(head, UDim2.fromScale(0.34, 0.07), UDim2.fromScale(0.5 + 0.17 * s, -0.28), col(if s < 0 then RED else Color3.fromRGB(60, 140, 255)), z + 5, 1)
				blade.Rotation = 8 * s
			end
			circle(head, UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.5, -0.28), col(GOLD), z + 6)
		elseif L.Hat == "DivingHelmet" then
			local base = L.HatColor or L.Shirt
			local rim = col(shade(base, 0.7))
			local dome = circle(holder, UDim2.fromScale(0.86, 0.82), UDim2.fromScale(0.5, 0.45), hc, z + 1) -- dome round the head
			Kit.Stroke(dome, 2, rim)
			rect(holder, UDim2.fromScale(0.62, 0.1), UDim2.fromScale(0.5, 0.79), rim, z + 1, 0.4) -- collar
			circle(head, UDim2.fromScale(1.1, 0.62), UDim2.fromScale(0.5, 0.18), hc, z + 4) -- covers the hair
			local window = circle(head, UDim2.fromScale(0.82, 0.7), UDim2.fromScale(0.5, 0.62), hc, z + 5)
			window.BackgroundTransparency = 1
			Kit.Stroke(window, 3, rim)
			for _, p in { Vector2.new(0.12, 0.38), Vector2.new(0.88, 0.38), Vector2.new(0.14, 0.86), Vector2.new(0.86, 0.86) } do
				circle(head, UDim2.fromScale(0.07, 0.07), UDim2.fromScale(p.X, p.Y), col(STEEL), z + 6) -- bolts
			end
		elseif L.Hat == "Gears" then
			local base = L.HatColor or L.Shirt
			rect(head, UDim2.fromScale(0.64, 0.16), UDim2.fromScale(0.5, 0.04), hc, z + 4)
			for i = -2, 2 do
				rect(head, UDim2.fromScale(0.09, 0.12), UDim2.fromScale(0.5 + i * 0.14, -0.07), hc, z + 4) -- teeth
			end
			local g = circle(head, UDim2.fromScale(0.24, 0.24), UDim2.fromScale(0.5, 0.0), col(shade(base, 0.8)), z + 5)
			Kit.Stroke(g, 2, hc)
			circle(g, UDim2.fromScale(0.4, 0.4), UDim2.fromScale(0.5, 0.5), col(L.Beam), z + 6)
		else
			local cap = circle(head, UDim2.fromScale(1.0, 0.5), UDim2.fromScale(0.5, 0.08), hc, z + 4)
			if L.Hat == "Cap" or L.Hat == "Fedora" then
				local brim: Frame = Kit.new("Frame", { Size = UDim2.fromScale(if L.Hat == "Fedora" then 1.3 else 0.7, 0.1), Position = UDim2.fromScale(if L.Hat == "Fedora" then 0.5 else 0.7, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = hc, ZIndex = z + 5, Parent = head })
				Kit.Corner(brim, UDim.new(1, 0))
			end
			cap.ZIndex = z + 4
		end
	end
	-- eyes
	if not silhouette then
		for _, x in { 0.33, 0.67 } do
			local e = circle(head, UDim2.fromScale(0.2, 0.24), UDim2.fromScale(x, 0.56), Color3.fromRGB(25, 20, 35), z + 5)
			circle(e, UDim2.fromScale(0.4, 0.4), UDim2.fromScale(0.65, 0.3), Color3.new(1, 1, 1), z + 6)
		end
		local mouth: Frame = Kit.new("Frame", { Size = UDim2.fromScale(0.22, 0.09), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(150, 40, 60), ZIndex = z + 5, Parent = head })
		Kit.Corner(mouth, UDim.new(1, 0))
		-- blush
		for _, x in { 0.18, 0.82 } do
			local b = circle(head, UDim2.fromScale(0.14, 0.08), UDim2.fromScale(x, 0.74), Color3.fromRGB(255, 130, 150), z + 5)
			b.BackgroundTransparency = 0.4
		end
		if L.Hat == "Goggles" or L.Hat == "Visor" then
			local g: Frame = Kit.new("Frame", { Size = UDim2.fromScale(0.9, 0.24), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = L.HatColor or Color3.new(0, 0, 0), BackgroundTransparency = 0.25, ZIndex = z + 7, Parent = head })
			Kit.Corner(g, UDim.new(0.5, 0))
		end
		-- tool badge
		Kit.Label(holder, Portrait.ToolIcon[L.Tool] or "👻", { Size = UDim2.fromScale(0.34, 0.34), Position = UDim2.fromScale(0.97, 0.97), AnchorPoint = Vector2.new(1, 1), ZIndex = z + 8, Stroke = 0 })
	else
		Kit.Label(holder, "?", { Size = UDim2.fromScale(0.4, 0.4), Position = UDim2.fromScale(0.5, 0.46), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 6, Color = Color3.fromRGB(160, 140, 210) })
	end
end

-- 3D portrait. Returns the ViewportFrame so callers can spin `model` if they want.
function Portrait.Viewport(parent: GuiObject, hunterId: string, silhouette: boolean?): (ViewportFrame, Model?)
	local vf: ViewportFrame = Kit.new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 190, 230),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
	if not Config.Hunters[hunterId] then
		return vf, nil
	end
	local model = HunterRig.BuildStatic(hunterId)
	if silhouette then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(15, 8, 30)
				p.Material = Enum.Material.SmoothPlastic
			elseif p:IsA("ParticleEmitter") or p:IsA("Light") then
				p:Destroy()
			end
		end
	end
	-- rigs face -Z and the camera sits on the -Z side: a slight turn gives a 3/4 view
	model:PivotTo(CFrame.Angles(0, math.rad(-22), 0))
	model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local _, size = model:GetBoundingBox()
	local h = math.max(size.Y, 3.5)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, h * 0.55, -h * 2.6), Vector3.new(0, h * 0.48, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf, model
end

return Portrait
