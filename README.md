# Ghost Hunter Simulator

A bright, slightly spooky Roblox collection simulator. Tap a ghost, your crew of chibi Ghost
Hunters zaps it until it POOFS into glowing Ectoplasm, the Ectoplasm flies to you, you spend it
on Hunter Crates, equip stronger hunters and unlock the next area.

Rojo + Luau project. Everything in this repository belongs to Ghost Hunter Simulator.

| | |
|---|---|
| Place file to open in Studio | `build/GhostHunterSimulator.rbxlx` |
| How to publish | [docs/PUBLISHING.md](docs/PUBLISHING.md) |
| What to test in Studio | [docs/STUDIO_TESTS.md](docs/STUDIO_TESTS.md) |
| Current state | [docs/STATUS.md](docs/STATUS.md) |
| How it works (for developers) | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Adding Zone 4, new hunters, rarities | [docs/ADDING_CONTENT.md](docs/ADDING_CONTENT.md) |
| Sounds to replace before launch | [docs/AUDIO.md](docs/AUDIO.md) |

## What's in the game

- **3 zones** on one connected path: Haunted Neighborhood (free), Cemetery (1,500), Haunted
  School (40,000). Gates show the price; future areas are visible over the walls.
- **10 ghosts** (9 regular + the Giant Poltergeist event boss) with Spirit bars, wandering,
  POOF effects and physical Ectoplasm drops.
- **12 Ghost Hunters** (4 per zone: Common, Uncommon, Rare, Legendary), each with its own
  outfit, hair, hat, backpack and equipment, built from parts, animated (idle, run, attack,
  celebrate) and firing coloured capture beams.
- **3 Hunter Crates** with odds boards at each station, an odds/price panel, and a crate opening
  cinematic that scales with rarity (Legendary: darkened screen, levitating crate, converging
  energy, camera punch, server announcement). SKIP button and a "fast opening" setting.
- **Inventory** (equip, unequip, EQUIP BEST, lock, release, sort by power/rarity), **Index**
  (discovery per zone, silhouettes, NEW! badges), **Upgrades** (pickup radius, Ectoplasm
  bonus, movement speed), **Daily rewards** (7 days, server clock), **Shop** (Robux products
  and game passes, disabled until you add their ids), **Settings**.
- **Giant Poltergeist event** every ~10 minutes: warning, beacon, boss bar, timer, rewards by
  participation, Ectoplasm shower.
- **Tutorial**: TAP A GHOST → COLLECT ECTOPLASM → OPEN A HUNTER CRATE → EQUIP YOUR NEW HUNTER →
  UNLOCK THE CEMETERY, with a glowing trail on the ground, then a NEXT GOAL bar.
- Saving with session locking, autosave and safe shutdown; every purchase and reward is decided
  by the server.

## For developers

```bash
bash tools/check.sh          # strict type check, unit tests, Rojo build
cd tests && luau EconSim.luau  # economy simulation (milestone times; run check.sh first)
```

Tools install automatically at session start (`tools/setup_env.sh` → luau, rojo and luau-lsp in
`/tmp/gh-tools`).
