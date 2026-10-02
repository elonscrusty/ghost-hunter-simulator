--!strict
-- Plays sounds by key from GH.Sounds; respects the player's Music/SFX settings.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GH = ReplicatedStorage:WaitForChild("GH")
local Sounds = require(GH.Sounds)
local State = require(script.Parent.Parent.State)

local Sound = {}

local pool: { [string]: { Sound } } = {}
local folder: Folder
local music: Sound? = nil
local bossMusic: Sound? = nil
local lastPlay: { [string]: number } = {}

local function sfxOn(): boolean
	local d = State.Data
	return not d or d.Settings.Sfx ~= false
end

local function make(key: string): Sound?
	local def = Sounds[key]
	if not def or not def.Id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = def.Id
	s.Volume = def.Volume
	s.PlaybackSpeed = def.Pitch or 1
	s.Looped = def.Looped == true
	s.Parent = folder
	return s
end

-- pitchJitter adds small random variation; pitchMul shifts the pitch (pickup streaks).
function Sound.Play(key: string, pitchJitter: number?, pitchMul: number?)
	if not sfxOn() then
		return
	end
	local now = os.clock()
	if now - (lastPlay[key] or 0) < 0.035 then
		return -- de-dupe bursts (e.g. 20 orbs landing at once)
	end
	lastPlay[key] = now
	local list = pool[key]
	if not list then
		list = {}
		pool[key] = list
	end
	local s: Sound? = nil
	for _, c in list do
		if not c.IsPlaying then
			s = c
			break
		end
	end
	if not s and #list < 4 then
		s = make(key)
		if s then
			table.insert(list, s)
		end
	end
	if s then
		local def = Sounds[key]
		s.PlaybackSpeed = (def.Pitch or 1) * (pitchMul or 1) * (1 + (if pitchJitter then (math.random() * 2 - 1) * pitchJitter else 0))
		s.TimePosition = 0
		s:Play()
	end
end

local function refreshMusic()
	local d = State.Data
	local on = not d or d.Settings.Music ~= false
	for _, m in { music, bossMusic } do
		if m then
			m.Volume = if on then (Sounds[m.Name].Volume) else 0
		end
	end
end

function Sound.Boss(active: boolean)
	if bossMusic and music then
		if active then
			bossMusic:Play()
			music:Pause()
		else
			bossMusic:Stop()
			music:Resume()
		end
	end
end

function Sound.Init()
	folder = Instance.new("Folder")
	folder.Name = "GHSounds"
	folder.Parent = SoundService
end

function Sound.Start()
	music = make("Music")
	bossMusic = make("BossMusic")
	if music then
		music:Play()
	end
	State.OnData(function()
		refreshMusic()
	end)
end

return Sound
