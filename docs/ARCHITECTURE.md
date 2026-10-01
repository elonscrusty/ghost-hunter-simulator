# Architecture

Rojo maps `src/shared` → `ReplicatedStorage.GH`, `src/server` → `ServerScriptService.GHServer`,
`src/client` → `StarterPlayerScripts.GHClient`. Streaming is off (the map is ~4k parts).

## Rule of thumb
The **server decides everything that matters** (currency, crate results, damage, pickups,
zones, upgrades, purchases, daily timing). The **client only draws** (ghost movement, hunters,
orbs, beams, UI) and asks via validated, rate-limited requests.

## Shared (`src/shared`)
| File | What |
|---|---|
| `Config.luau` | Every balance number and content entry: rarities (incl. disabled Epic/Mythic/Secret/Exclusive), zones, ghosts, hunters (+ looks), crates (+ weights), upgrades, boosts, daily, event, shop, rate limits, world layout, tutorial text. |
| `Logic/Rules.luau` | Pure rules (unit tested): crate odds/rolls with luck, crew power, equip best, upgrade cost/value, daily streak, drop splitting, event share, rate limiter, zone lookup. |
| `Logic/Format.luau` | Number/time/percent formatting. |
| `Net.luau` | Remote names. Server creates them; clients wait. |
| `Signal.luau` | In-process events that pass tables by reference (never use BindableEvents for tables: they deep-copy them and turn Player keys into strings). |
| `Sounds.luau` | Sound ids by key (see AUDIO.md). |
| `Rigs/HunterRig.luau` | Chibi hunter builder (anchored Root at the feet, Motor6D limbs) + procedural poses Idle/Run/Attack/Celebrate. `BuildStatic` for portraits. |
| `Rigs/GhostRig.luau` | Ghost visual builder (built on each client): anchored `Core` + welded visuals, 10 styles. The server only replicates an invisible hitbox per ghost. |
| `Rigs/CrateRig.luau` | Crate with Motor6D lid and padlocks, Glow slab, Burst attachment. |

## Server (`src/server`)
`Main.server.luau`: creates remotes, builds the world (`World/Builder`), then `Init()` and `Start()`
each service in order: Fx, Remotes, DataService, PlayerInfo, HunterService, DropService,
GhostService, ProgressService, EventService, ShopService, StationService.

| Service | Responsibility |
|---|---|
| `Remotes` | `Request(action, ...)` dispatcher: per-bucket rate limits, pcall, type checks in handlers. |
| `DataService` | Profiles: per-session lock (`_lock.session`), retries with backoff, deep-copied save snapshots, autosave (90 s), single releasing save on leave, waits for this server's in-flight leave-save on rejoin, `BindToClose`, schema migration (fills new fields; unknown keys kept in `Extra`, removed hunters kept in `Orphans`), receipt history. Saves report success only if really written. Studio without API access: no saving (warning); live: kick on load failure. |
| `PlayerInfo` | Derived values: slots, Ectoplasm multiplier, luck, pickup radius, walk speed, zone multiplier, game passes. |
| `HunterService` | Crates (server roll, zone + distance + storage + price checks, free-crate tokens), equip/unequip/equip best/lock/release. Publishes `Crew` and `CrewPower` player attributes. Starter hunter. |
| `GhostService` | Spawns ghosts (one invisible hitbox part each) per `Config.Layout.GhostAreas`, wander segments (attributes `From/To/T0/Dur`, server time), manual targeting (`SelectTarget`, click/tap once), 0.25 s damage tick, kills, personal drops for contributors (bar drops when many crews help), respawns. **Auto Attack**: `AutoAttack` request (pass-checked), session toggle, picks the nearest ghost in the player's current zone; free players never get automatic targets. |
| `DropService` | Per-player orb records; one 0.15 s loop collects orbs inside each player's radius and credits them. |
| `ProgressService` | Zone unlocks (order, cost, distance), keeps players out of zones they don't own, upgrades, daily reward, settings, tutorial step, walk speed, player collision group. |
| `EventService` | Giant Poltergeist loop: warning → spawn (Spirit scales with crews) → timer → rewards by damage share / escape. |
| `ShopService` | `ProcessReceipt` (idempotent, saves before granting), game pass checks, purchase prompts. |
| `StationService` | Display crates, odds boards (SurfaceGui), ProximityPrompts on stations and gates. |
| `World/*` | Procedural map: lighting, boundaries, gates, stations, arena, three zones, props. |

### Remotes
| Name | Direction | Payload |
|---|---|---|
| `SelectTarget` | C→S | ghost uid (0/nil = clear) |
| `Request` (RemoteFunction) | C→S | `(action, ...)` → `{ ok, err?, ... }`. Actions: OpenCrate, Equip, Unequip, EquipBest, Lock, Release, UnlockZone, BuyUpgrade, ClaimDaily, Setting, Tutorial, Buy, AutoAttack |
| `Sync` | S→C | profile snapshot + derived values (CrewPower, Slots, EctoMultiplier, LuckMultiplier, PickupRadius, ZoneMultiplier, Passes, DailyInfo, ServerTime) |
| `Ecto` | S→C | current Ectoplasm |
| `Drops` | S→C | `(origin, {{id, landPos, value}, ...}, retiredIds)` |
| `Collect` | S→C | `(ids, total)` |
| `Fx` | S→C | `(kind, data)`: `Poof` {Uid, Pos, Scale, Color, Big, Escaped}, `Announce` {Text, Color=rarity}, `Toast` {Text, Color}, `ZoneUnlocked` {Zone}, `Boss` {State=Warning/Active/Defeated/Escaped, At?, Uid?, EndsAt?, Pos?} |

### Data (profile)
`Ecto, TotalEcto, Hunters{uid → {Id, Locked, T}}, NextUid, Equipped{uid}, Discovered{id → true},
Zones{id → true}, Upgrades{id → level}, Daily{Last, Streak}, Boosts{id → expiry}, FreeCrates{crate → n},
Settings{Music, Sfx, FastReveal}, Tutorial, Stats{Ghosts, Crates, Events, Seconds},
Purchases{receipt ids}`. Version = `Config.DataSchemaVersion`.

## Client (`src/client`)
`Main.client.luau` inits then starts controllers in order. `State.luau` mirrors the snapshot and
wraps `Request`. UI kit in `UI/`: `Theme` (colours, typography scale `Theme.Type`, screen
scaling rules, world-label sizes), `Kit` (fixed-size text styles, buttons, responsive panels
that shrink to the screen, toasts), `WorldLabel` (device-scaled BillboardGuis with MaxDistance),
`Portrait` (2D faces for grids, 3D viewport portraits).

### Responsive UI
One UIScale per ScreenGui: landscape `clamp(viewportHeight / 520, 0.55, 1)`, portrait
`clamp(viewportWidth / 600, 0.55, 1)`. Desktop/laptop/tablet = 1.0; phones ≈ 0.72-0.83. Layouts
are in logical px; panels cap to the logical screen and scroll/wrap inside (grids use
UIGridLayout). Short screens (< 650 logical px) get the compact HUD (2×3 menu block top-left,
clear of the thumbstick). No TextScaled anywhere: text sizes come from `Theme.Type`. The game
is locked to landscape (`StarterGui.ScreenOrientation = LandscapeSensor`).

| Controller | What |
|---|---|
| `Ghosts` | Builds each ghost's visual rig locally, moves hitbox + visual along the server segment (one loop, BulkMoveTo), bob/sway/face camera, compact Spirit labels (MaxDistance), selected state (bigger bar + numbers + ground ring), hit shake, spawn-in, POOF. |
| `Targeting` | Click / tap (TouchTap) / gamepad X (+ keyboard F) selection with a forgiving screen-space fallback (nearest ghost to the tap, ties go to the nearer one), hover outline, selection highlight; `LocalTarget()` lets your crew react before the server confirms. |
| `Crew` | Every player's hunters: follow formation, run to a ring around the target, beams, celebrate; ground raycasts staggered; far crews hidden. |
| `Orbs` | Ectoplasm orbs: arc, bounce, hover, predicted magnet + server-confirmed pickup, pickup ring, streak pitch. Pooled parts, one loop. |
| `Reveal` | Crate cinematic (stage far from the map, scripted camera, rarity-scaled), result card with EQUIP / AGAIN / OK, SKIP. |
| `Hud` | Compact HUD: Ectoplasm counter (count-up), crew power, active boosts, responsive menu, settings, AUTO ATTACK toggle (pass owners), banners, announcements. |
| `CratePanel`, `HuntersPanel`, `IndexPanel`, `UpgradesPanel`, `ShopPanel`, `DailyPanel`, `GatePanel` | Menus. |
| `Boss` | Event warning, beacon, boss bar, timer, banners, "SHOW ME" trail. |
| `Ambience` | Zone lighting blend, floating props, flickering lights, spinning display crates, gates (local open/close + unlock sequence), prompts → panels. |
| `Tutorial` | Guided first steps with ground breadcrumbs and a bouncing arrow; NEXT GOAL chip afterwards. |
| `Effects`, `Sound` | VFX helpers (capped) and pooled sounds honouring settings. |

## Performance notes
- No per-ghost or per-orb connections: one server loop for ghosts (0.25 s), one for pickups
  (0.15 s); one client RenderStepped each for ghosts, crews, orbs, ambience.
- Ghost positions are computed from segments, never streamed per frame.
- Effects are capped (24 live emitters); sounds de-duplicated within 35 ms; orbs pooled.
- Map: ~4.1k parts, 37 lights, 14 emitters (see World/Builder output).
