--!strict
-- Night-but-bright lighting: purple haze, big moon, bloom on the neon, punchy colours.

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
	L.ExposureCompensation = 0.15
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
	atmo.Density = 0.3
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(190, 150, 255)
	atmo.Decay = Color3.fromRGB(110, 70, 180)
	atmo.Glare = 0.4
	atmo.Haze = 1.4
	atmo.Parent = L

	clear("GHBloom")
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GHBloom"
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = L

	clear("GHColor")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GHColor"
	cc.Saturation = 0.25
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
