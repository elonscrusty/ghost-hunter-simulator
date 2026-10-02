# Status

**Version 1.2: 8-zone expansion. Not yet run in Roblox Studio.**

## Done
- All launch systems: zones + gates, ghosts + Giant Poltergeist event, hunters, crates with a
  rarity-scaled opening cinematic, inventory, index, upgrades, daily rewards, shop, settings,
  tutorial + next-goal guidance, saving with session locks.
- v1.1: click/tap once to send your crew (no free auto-attack); AUTO ATTACK game pass; mobile
  world labels; responsive compact UI; less neon; server hardening.
- v1.2 (expansion):
  - 8 connected areas: Haunted Neighborhood → Cemetery → Haunted School (new back exit) →
    Abandoned Carnival → Haunted Hospital → Ghost Ship Harbor → Cursed Castle → Spirit Realm.
  - 24 ghosts (3 per area, the last one a boss; Spirit Overlord is the endgame boss) + event.
  - 32 hunters (4 per area), 8 crates (same crate system, fancier per area), new hats/tools/backs.
  - Rebalanced curve (Config only): each area's Rare beats the previous Legendary; the previous
    Legendary still beats the new Common. Upgrades go to level 8.
  - WORLDS menu (Fast Travel, server-checked, owned areas only); one-column menu, bigger buttons.
  - Hunter Index for 8 areas with "x / 32 DISCOVERED • %".
  - World labels never grow with distance (ease slightly smaller, then hide); bosses get bigger
    labels; spirit value always shown.
  - Mobile performance: far ghost visuals parked, ghosts spread out (no stacking), budgets for
    lights/emitters; material pass on zones 1-3 (fewer neon parts).
  - 🛠 DEV button (owner/Studio only, server-checked): Ectoplasm, unlock areas, all hunters,
    max upgrades, start event, reset daily, Auto Attack pass, replay tutorial.
  - MYTHIC and SECRET rarities: one of each per area (48 hunters), 0.4% / 0.04% crate odds,
    full reveal drama + server announcement.
  - 💬 FEEDBACK (button above ⚙ and in Settings): bug reports / ideas, text-filtered, stored in
    a DataStore inbox; the owner reads them in the DEV panel (💬 READ FEEDBACK).
  - TOP GHOST HUNTERS leaderboard beside spawn (all-time Ectoplasm, refreshes every 2 min).
  - Ectoplasm + Power counters side by side, centred in the top bar; menu column starts below
    the Roblox chat window.
  - Image icon slots (`src/shared/Icons.luau`) + ChatGPT prompts (`icon-prompts/`).
- Checks: strict type check clean, 35 unit tests (rules, formatting, economy incl. 8-zone curve
  and layout), Rojo build, headless world/rig smoke test (`bash tools/worldsim.sh`).
- Economy simulation (`tests/EconSim.luau`, realistic solo player, median):
  first crate 1 min · Cemetery 9 min · School 52 min · Carnival 2.7 h · Hospital 4.6 h ·
  Harbor 8.3 h · Castle 11 h · Spirit Realm 15 h.

## Owner to do
1. Playtest in Studio: [STUDIO_TESTS.md](STUDIO_TESTS.md) (nothing has been run in Studio yet).
2. Shop ids are in (4 products + 3 passes). On launch day: make the game public and put the 3 passes on sale (149 / 299 / 199).
3. Pick music and nicer sound effects ([AUDIO.md](AUDIO.md)); placeholders play meanwhile.
4. Optional: make icons with ChatGPT ([icon-prompts/](../icon-prompts/)), upload them and send Claude the ids.
5. Game icon, thumbnails, description; then publish.

## Next (ideas)
- Index area-completion rewards; more events in later areas.

## Known limits / ideas for later
- Hunters walk in straight lines (no pathfinding), so they can pass through props; that's
  normal for simulator pets and keeps it cheap on mobile.
- Index section completion has no reward yet (tracking + percentage + NEW! badges only).
- Roof wedges are untested in Studio (see the Zones tests).
