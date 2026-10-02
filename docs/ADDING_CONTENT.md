# Adding content

Everything lives in `src/shared/Config.luau`. After any change run `bash tools/check.sh`
(the economy spec checks references) and `cd tests && luau EconSim.luau` to see the new pacing.

## A new zone (e.g. Zone 9)
1. **Config.Zones**: add `{ Id = "Factory", Name = "HAUNTED FACTORY", Order = 9, Cost = ..., Crate = "Factory", Ambient, FogColor, Accent, MinZ = 2680, MaxZ = 3020 }`.
2. **Config.Ghosts**: 3 ghosts with `Zone = "Factory"` (and a `Style`; add the style to
   `Rigs/GhostRig.luau` or reuse an existing one).
3. **Config.Hunters**: 4 hunters with `Zone = "Factory"` and a `Look` (any combination of the
   existing hair/hat/back/tool styles works).
4. **Config.Crates**: a `Factory` crate with the 4 hunters and weights.
5. **Config.Layout**: a gate `Factory = { Z = 2680, Width = 34 }`, a crate station at
   `(-28, 0, MinZ + 32)`, a Fast Travel point in `ZoneSpawns` at `(26, 3, MinZ + 32)`, and
   `GhostAreas` entries for the new ghosts.
6. **Config.Daily.ZoneMultiplier**: add a 9th multiplier.
7. **World**: add `src/server/World/Factory.luau` (copy the pattern of `Carnival.luau`: own ground
   slab and side walls), call it from `Builder.luau`, and add wall/gate colours in `Boundary.luau`
   (`WALLS`) and `Gates.luau` (`THEMES`). The far end wall follows the last zone automatically.
8. Run `bash tools/check.sh`, `bash tools/worldsim.sh` and `cd tests && luau EconSim.luau`.

Nothing else needs code changes: gates, prompts, odds boards, panels, index, tutorial goal chip,
zone lighting and the zone guard all read Config.

## A new rarity
The rarities **Epic, Mythic, Secret, Exclusive** already exist with colours and reveal settings
(`Enabled = false`). Set `Enabled = true` and give a hunter that `Rarity`. `Order` controls
sorting, luck boost (`Config.LuckAffectsFromOrder`) and reveal drama (Order ≥ 5 gets the title slam).

## A new hunter in an existing crate
Add it to `Config.Hunters` and to the crate's `Pool` with a `Weight`. The odds board, crate
panel and index update automatically. (The index shows each crate's pool, so a hunter that is
in no crate won't appear there.)

## Tuning
- Early game speed: `Ghosts.WanderingSpirit`, `Crates.Beginner.Price`, `Zones[2].Cost`.
- Event difficulty: `Event.SpiritBase` / `SpiritPerPower` (≈ seconds of combined crew power).
- Pickup feel: `Upgrades.PickupRadius.Levels`, `Drops.FlyTime`.
