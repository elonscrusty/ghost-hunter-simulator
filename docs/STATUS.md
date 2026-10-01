# Status

**Version 1.0.0: complete first build, not yet run in Roblox Studio.**

## Done
- All launch systems: 3 zones + gates, 9 ghosts + Giant Poltergeist event, 12 hunters, 3 crates
  with rarity-scaled opening cinematic, inventory, index, upgrades, daily rewards, shop
  (products/passes), settings, tutorial + next-goal guidance, saving with session locks.
- Server-authoritative economy; all requests validated and rate limited.
- Checks: strict type check clean, unit tests (rules, formatting, economy sanity), Rojo build.
- Economy simulation (`tests/EconSim.luau`, 300 runs, realistic solo player):
  first crate < 1 min · Cemetery ~9 min · first Haunted crate ~11 min · School ~50 min ·
  first Elite crate ~55 min · Neighborhood index ~5 min · full index ~1.5-3 h.

## Owner to do
1. Playtest in Studio: [STUDIO_TESTS.md](STUDIO_TESTS.md) (nothing has been run in Studio yet).
2. Create the 4 developer products + 2 passes and send Claude the ids ([PUBLISHING.md](PUBLISHING.md) step 5). Until then the shop shows "SOON".
3. Pick music and nicer sound effects ([AUDIO.md](AUDIO.md)); placeholders play meanwhile.
4. Game icon, thumbnails, description; then publish.

## Known limits / ideas for later
- Hunters walk in straight lines (no pathfinding), so they can pass through props; that's
  normal for simulator pets and keeps it cheap on mobile.
- Index section completion has no reward yet (tracking + percentage + NEW! badges only).
- Roof wedges are untested in Studio (see test C, last item).
- Future: Zone 4+ (see ADDING_CONTENT.md), Epic/Mythic/Secret/Exclusive hunters (rarities are
  already configured), trading, rebirths, more events.
