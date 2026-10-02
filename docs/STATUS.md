# Status

**Version 1.4 (live-game update, not yet published): see the v1.4 list below.**

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
- v1.3:
  - 16 areas: + Phantom Swamp, Frostbite Peaks, Pharaoh's Tomb, Haunted Toy Factory, Sunken City,
    Clockwork Tower, Inferno Caverns, Ghost King's Throne (final). 48 ghosts, 96 crate hunters
    (6 per area incl. Mythic + Secret), 16 crates. Map ~14k parts, 160 lights.
  - Robux: Lucky Hunter, Triple Open, Super Magnet, VIP, +50 Storage, Rainbow Beams, Sparkle
    Trail (passes); Unlock Next Area, Exclusive Crate (16 exclusive hunters, not needed for
    completion), Server Luck, Summon Event (products). Ids still to be created (icon-prompts/
    round 2 has names, prices and pictures).
  - Economy sim median: Spirit Realm ~13 h, Throne (area 16) ~58 h.
- v1.4 (live update, built for a public game with real saves):
  - Mobile text fix at the root (Kit): text outlines now scale with the screen and small text
    never renders below 10 px; hover-grow only with a mouse; unsupported glyphs replaced
    (the event popup's missing X was the font lacking "✕"); one shared Kit.CloseButton.
  - Smoother early curve: School 15K (was 40K), Carnival 150K (250K), Hospital 1.5M (2.5M);
    crates Elite 5,000 (9,000), Carnival 40K (60K), Medical 400K (550K). Haunted stays 600.
  - Each ghost type has ONE fixed base reward (Config.Ghosts[x].Reward); final reward =
    base x the player's multiplier (upgrades, boosts, passes, global event).
  - AUTO ATTACK is free for everyone; the old Auto Attack pass is hidden and its buyers get
    AUTO OPEN free.
  - Crate reveal: hunter on the left, info card on the right. SKIP costs a Single Crate Skip
    (10 R$ product, banked as SkipTokens) or is free with Permanent Crate Skip (129 R$ pass).
  - AUTO OPEN (99 R$ pass): toggle in the crate panel; server loop re-opens the crate with all
    normal checks, stops on OFF / no money / storage full / walking away / leaving.
  - Global 2X ECTOPLASM event: OFF by default, only developers toggle it (DEV panel), stored in
    DataStore GhostHunterGlobal_v1 + broadcast via MessagingService; popup + HUD chip.
  - HUD: Hunters/Worlds/Index left; Upgrades/Shop/Daily, Auto Attack and Feedback/Settings
    (+DEV) on the right above the jump button; next-area bar directly under the counters.
  - Save-compat test (`bash tools/datacompat.sh`, part of check.sh) runs old-format saves
    through the real migration.
- Checks: strict type check clean, 35 unit tests (rules, formatting, economy incl. 8-zone curve
  and layout), Rojo build, headless world/rig smoke test (`bash tools/worldsim.sh`).
- Economy simulation (`tests/EconSim.luau`, realistic solo player, median):
  first crate 1 min · Cemetery 9 min · School 52 min · Carnival 2.7 h · Hospital 4.6 h ·
  Harbor 8.3 h · Castle 11 h · Spirit Realm 15 h.

## Owner to do
1. Playtest: done by the owner (phone, event, leaderboard work).
2. Shop ids are in (4 products + 3 passes). On launch day: make the game public and put the 3 passes on sale (149 / 299 / 199).
3. Music: main track set (rbxassetid://1837467198); boss music optional.
4. Optional: make icons with ChatGPT ([icon-prompts/](../icon-prompts/)), upload them and send Claude the ids.
5. Game icon, thumbnails, description; then publish.

## Next (ideas)
- FUTURE (do not build yet): PARANORMAL ARTIFACTS: collectible items equipped by the PLAYER
  (separate from hunters) with effects like damage, attack speed, Ectoplasm or team-wide bonuses.
- Index area-completion rewards; more events in later areas.

## Known limits / ideas for later
- Hunters walk in straight lines (no pathfinding), so they can pass through props; that's
  normal for simulator pets and keeps it cheap on mobile.
- Index section completion has no reward yet (tracking + percentage + NEW! badges only).
- Roof wedges are untested in Studio (see the Zones tests).
