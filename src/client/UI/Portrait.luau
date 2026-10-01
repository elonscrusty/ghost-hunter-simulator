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
} :: { [string]: string }

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
