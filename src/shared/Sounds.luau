--!strict
-- Every sound in the game, by key. Ids marked Placeholder = true use Roblox's built-in
-- engine sounds (always available, free to use) so the game is never silent, but they
-- should be replaced with licensed Creator Store audio before launch. Entries with
-- Id = nil are silent until filled in. See docs/AUDIO.md for the replacement list.
export type SoundDef = { Id: string?, Volume: number, Pitch: number?, Placeholder: boolean?, Looped: boolean? }

local Sounds: { [string]: SoundDef } = {
	-- UI
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Placeholder = true },
	Hover = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.15, Pitch = 1.6, Placeholder = true },
	PanelOpen = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Pitch = 1.3, Placeholder = true },
	Error = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.25, Pitch = 1.6, Placeholder = true },
	-- Ghosts / combat
	Select = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.2, Placeholder = true },
	Attack = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.12, Pitch = 0.7, Placeholder = true },
	Poof = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.6, Pitch = 0.8, Placeholder = true },
	BigPoof = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.9, Pitch = 0.5, Placeholder = true },
	-- Ectoplasm
	Drop = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.25, Pitch = 1.4, Placeholder = true },
	Pickup = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.22, Pitch = 1.8, Placeholder = true },
	-- Crates
	CrateBuy = { Id = "rbxasset://sounds/button.wav", Volume = 0.6, Placeholder = true },
	CrateShake = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.45, Pitch = 0.8, Placeholder = true },
	LockPop = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.6, Pitch = 1.2, Placeholder = true },
	RevealCommon = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.0, Placeholder = true },
	RevealRare = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Pitch = 0.75, Placeholder = true },
	RevealLegendary = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1.0, Pitch = 0.5, Placeholder = true },
	-- Progression
	ZoneUnlock = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.9, Pitch = 0.6, Placeholder = true },
	Upgrade = { Id = "rbxasset://sounds/button.wav", Volume = 0.6, Pitch = 1.3, Placeholder = true },
	Daily = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Pitch = 1.1, Placeholder = true },
	-- Event
	BossAppear = { Id = "rbxasset://sounds/swoosh.wav", Volume = 1.0, Pitch = 0.35, Placeholder = true },
	-- Music: pick a bright spooky track from the Creator Store (Audio, licensed for use) and paste its id.
	Music = { Id = "rbxassetid://1837467198", Volume = 0.3, Looped = true },
	BossMusic = { Id = nil, Volume = 0.45, Looped = true },
}

return Sounds
