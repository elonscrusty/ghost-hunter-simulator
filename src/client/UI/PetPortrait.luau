--!strict
-- Pet portraits: the real pet model (PetFollowers.BuildPet) in a ViewportFrame. Static: no
-- RenderStepped, the ViewportFrame renders once and only redraws when something inside changes.
-- One template model is built per pet id and cloned for every portrait, so rebuilding a list
-- never rebuilds models. The clone lives inside the ViewportFrame, so destroying the list item
-- destroys the portrait with it. The camera is framed from the model's bounding box, so any pet
-- shape fits without per-pet numbers.
local PetFollowers = require(script.Parent.Parent.Controllers.PetFollowers)
local Kit = require(script.Parent.Kit)

local PetPortrait = {}

local FOV = 30
local YAW = math.rad(-25) -- pets face -Z and the camera sits on the -Z side: a slight 3/4 turn
local VIEW_DIR = Vector3.new(0, 0.3, -1).Unit -- from the front, a little above
local FILL = 0.92 -- < 1 zooms in a little (the bounding sphere is loose around round pets)
local SILHOUETTE = Color3.fromRGB(15, 8, 30)

type Template = { Model: Model, Cam: CFrame }
local templates: { [string]: Template } = {}

local function template(petId: string): Template?
	local t = templates[petId]
	if t then
		return t
	end
	local model = PetFollowers.BuildPet(petId) -- nil only for an unknown id (cheap to retry)
	if not model then
		return nil
	end
	-- lights don't render in a ViewportFrame; drop them so clones stay light
	for _, d in model:GetDescendants() do
		if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(0, YAW, 0))
	local box, size = model:GetBoundingBox()
	local radius = math.max(size.Magnitude / 2, 0.1)
	local dist = radius / math.tan(math.rad(FOV / 2)) * FILL
	local centre = box.Position
	local made: Template = { Model = model, Cam = CFrame.lookAt(centre + VIEW_DIR * dist, centre) }
	templates[petId] = made
	return made
end

-- Fills `parent` with a transparent ViewportFrame showing the pet. silhouette = undiscovered
-- (rendered as a dark shape via ImageColor3). Returns the ViewportFrame.
function PetPortrait.New(parent: GuiObject, petId: string, silhouette: boolean?, size: UDim2?): ViewportFrame
	local vf: ViewportFrame = Kit.new("ViewportFrame", {
		Size = size or UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 195, 225),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, -0.7), -- same as the hunter portraits (UI/Portrait)
		ImageColor3 = if silhouette then SILHOUETTE else Color3.new(1, 1, 1),
		ZIndex = parent.ZIndex + 1,
		Parent = parent,
	})
	local t = template(petId)
	if t then
		t.Model:Clone().Parent = vf
		local cam = Instance.new("Camera")
		cam.FieldOfView = FOV
		cam.CFrame = t.Cam
		cam.Parent = vf
		vf.CurrentCamera = cam
	end
	return vf
end

return PetPortrait
