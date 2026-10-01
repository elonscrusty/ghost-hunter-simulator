# Status

**Version 1.1: manual targeting + Auto Attack pass + mobile UI pass. Not yet run in Roblox Studio.**

## Done
- All launch systems: 3 zones + gates, 9 ghosts + Giant Poltergeist event, 12 hunters, 3 crates
  with rarity-scaled opening cinematic, inventory, index, upgrades, daily rewards, shop
  (products/passes), settings, tutorial + next-goal guidance, saving with session locks.
- v1.1:
  - Free players click/tap a ghost once; the crew kills it and comes home. No automatic targets.
  - AUTO ATTACK game pass (server-verified) + HUD toggle (default OFF each session): the crew
    picks the nearest ghost in your area. Same damage, rewards and pickup radius.
  - Mobile: device-scaled, distance-limited world labels; selected ghost gets a bigger bar,
    numbers and a ground ring; forgiving tap targeting; crew reacts to taps instantly.
  - Smaller typography scale everywhere; responsive panels (fit any screen, scroll/wrap);
    compact HUD (2×3 menu on phones, clear of the thumbstick); landscape lock.
  - Less neon: world, rigs and bloom toned down.
  - Server hardening from a code review: starter hunter / boss payout bug (BindableEvent table
    copies) fixed, per-session save locks, no parallel saves, receipts confirmed only after a
    real save, safe startup/tick loops, ghosts replicate as one hitbox part.
- Checks: strict type check clean, unit tests (rules, formatting, economy sanity), Rojo build.
- Economy simulation (`tests/EconSim.luau`, 300 runs, realistic solo player):
  first crate < 1 min · Cemetery ~9 min · first Haunted crate ~11 min · School ~50 min ·
  first Elite crate ~55 min · Neighborhood index ~5 min · full index ~1.5-3 h.

## Owner to do
1. Playtest in Studio: [STUDIO_TESTS.md](STUDIO_TESTS.md) (nothing has been run in Studio yet).
2. Create the 4 developer products + 3 passes (incl. Auto Attack) and send Claude the ids ([PUBLISHING.md](PUBLISHING.md) step 5). Until then the shop shows "SOON".
3. Pick music and nicer sound effects ([AUDIO.md](AUDIO.md)); placeholders play meanwhile.
4. Game icon, thumbnails, description; then publish.

## Next (planned)
- Zones 4-8 with new ghosts, hunters and crates, rebalance for 8 zones, Fast Travel (waiting
  for the owner's zone themes, otherwise Claude designs them).

## Known limits / ideas for later
- Hunters walk in straight lines (no pathfinding), so they can pass through props; that's
  normal for simulator pets and keeps it cheap on mobile.
- Index section completion has no reward yet (tracking + percentage + NEW! badges only).
- Roof wedges are untested in Studio (see the Zones tests).
