# Audio

All sounds are listed in `src/shared/Sounds.luau`. Entries marked `Placeholder = true` use
Roblox's built-in engine sounds (`rbxasset://sounds/...`), which are always available and free
to use, so the game is never silent. They're simple clicks/pings/swooshes; replace them with
better ones from the **Creator Store → Audio** (only use audio you're allowed to use: Roblox's
own library tracks or your own uploads).

To replace one: find a sound in the Creator Store, copy its id, and set
`Id = "rbxassetid://<id>"` (and remove `Placeholder = true`).

| Key | Used for | Suggested search |
|---|---|---|
| Music | Background music (silent until set) | "spooky halloween fun", "cartoon spooky loop" |
| BossMusic | Giant Poltergeist fight (silent until set) | "halloween boss", "spooky action" |
| Click / Hover / PanelOpen | Buttons and menus | "ui click", "pop", "whoosh" |
| Error | Can't afford / not allowed | "error buzz cartoon" |
| Select | Selecting a ghost | "magic select", "ping" |
| Attack | Hunter beam zaps (quiet, repeats) | "laser zap soft", "energy hum" |
| Poof / BigPoof | Ghost defeated (big = bosses) | "poof cartoon", "magic poof" |
| Drop | Ectoplasm bursting out | "bubble pop", "slime drop" |
| Pickup | Each orb collected (pitch rises on a streak) | "coin pickup soft", "bubble collect" |
| CrateBuy / CrateShake / LockPop | Crate opening | "chest rumble", "lock break", "wood shake" |
| RevealCommon / RevealRare / RevealLegendary | Hunter reveal by rarity | "reveal sparkle", "rare reward", "legendary fanfare" |
| ZoneUnlock | New area unlocked | "unlock fanfare", "door magic open" |
| Upgrade | Upgrade bought | "level up" |
| Daily | Daily reward claimed | "reward chime" |
| BossAppear | Giant Poltergeist warning/spawn | "ghost roar cartoon", "spooky horn" |

Volumes are per entry (`Volume`). Players can mute music or effects in Settings (⚙).
