--!strict
-- Night-but-bright lighting: purple haze, big moon, punchy colours. Bloom is soft and only
-- catches the brightest pixels, so the few neon accents (windows, lamps, jack-o'-lantern
-- faces) glow without blowing out; the solid candy colours carry the scene.

local LightingService = game:GetService("Lighting")

local LightingSetup = {}

local function clear(name: string)
	local old = LightingService:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

function LightingSetup.Apply()
	local L = LightingService
	L.ClockTime = 0.5
	L.GeographicLatitude = 20
	L.Brightness = 2.5
	L.Ambient = Color3.fromRGB(150, 120, 200)
	L.OutdoorAmbient = Color3.fromRGB(160, 140, 210)
	L.ColorShift_Top = Color3.fromRGB(170, 140, 255)
	L.ColorShift_Bottom = Color3.fromRGB(60, 30, 90)
	L.EnvironmentDiffuseScale = 0.5
	L.EnvironmentSpecularScale = 0.4
	L.GlobalShadows = true
	L.ShadowSoftness = 0.4
	L.ExposureCompensation = 0.25 -- a touch brighter now that fewer surfaces glow
	L.FogEnd = 100000

	for _, child in L:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local sky = Instance.new("Sky")
	sky.Name = "GHSky"
	sky.CelestialBodiesShown = true
	sky.StarCount = 3000
	sky.MoonAngularSize = 24
	sky.SunAngularSize = 10
	sky.Parent = L

	local atmo = Instance.new("Atmosphere")
	atmo.Name = "GHAtmosphere"
	atmo.Density = 0.26 -- the map is ~2.7k studs long now: keep the next zone's landmarks visible
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(190, 150, 255)
	atmo.Decay = Color3.fromRGB(110, 70, 180)
	atmo.Glare = 0.4
	atmo.Haze = 1.0
	atmo.Parent = L

	clear("GHBloom")
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GHBloom"
	bloom.Intensity = 0.3
	bloom.Size = 20
	bloom.Threshold = 2
	bloom.Parent = L

	clear("GHColor")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GHColor"
	cc.Saturation = 0.3
	cc.Contrast = 0.1
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 245, 255)
	cc.Parent = L

	clear("GHSunRays")
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "GHSunRays"
	rays.Intensity = 0.06
	rays.Spread = 0.7
	rays.Parent = L
end

return LightingSetup
