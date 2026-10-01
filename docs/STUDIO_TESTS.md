# Studio playtest checklist

Open `build/GhostHunterSimulator.rbxlx`, turn on API access (PUBLISHING.md step 2), press
**Play**. Tick each box; anything that fails, note what you saw (a phone photo is fine).
Chat commands (Studio only): `/ecto 5000`, `/event`, `/reset-daily`.

## A. First 5 minutes (new player)
- [ ] Spawn on the glowing HQ plaza. HUD shows Ectoplasm 0 at the top, ⚡ 5 CAPTURE POWER under it, five menu buttons on the left.
- [ ] After ~2 s the camera swings to the nearest ghost and back. "CLICK A GHOST!" (or "TAP A GHOST!" on a phone) appears with a bouncing arrow over a ghost and glowing dots on the ground.
- [ ] Click/tap a ghost: it gets a coloured outline, a ping plays, the Rookie Hunter runs to it and fires a yellow beam. The Spirit bar ("30 / 30") drops.
- [ ] The ghost puffs up and POOFs (flash, smoke, ring). 3 green orbs arc out, bounce and hover.
- [ ] "COLLECT ECTOPLASM!" appears. Walk near: orbs zoom into you, a ping per orb, counter counts up, "+5" floats under the counter. A faint green ring shows your pickup radius while orbs are near.
- [ ] Your hunter does a little victory pose, then automatically starts on the next nearby ghost (Settings → AUTO NEXT GHOST).
- [ ] At 25 Ectoplasm: "OPEN A HUNTER CRATE!" with a trail to the Beginner crate (orange station left of spawn, spinning crate, odds board).
- [ ] Press E / tap the prompt: crate panel shows 4 hunters, odds 60% / 28% / 10% / 2%, OPEN 💚 25.
- [ ] Opening: screen flashes, crate drops and bounces, shakes, locks pop, lid flies open, light burst, the hunter leaps out and poses. Card shows name, rarity, Capture Power, NEW!. SKIP works at any point.
- [ ] Press EQUIP on the card (or HUNTERS → EQUIP BEST). Tutorial says "UNLOCK THE CEMETERY!" with progress. The new hunter follows you and both attack together; ghosts die noticeably faster.

## B. Hunters, index, upgrades
- [ ] HUNTERS: cards show portrait, name, ⚡, rarity colour; ✓ on equipped. EQUIPPED x/4. Sort toggles POWER/RARITY. Tap a card → 3D preview, EQUIP/UNEQUIP, LOCK, RELEASE.
- [ ] You can't unequip your last hunter; you can't release equipped or locked hunters. RELEASE mode → SELECT WEAK → RELEASE gives a small refund.
- [ ] INDEX: three zone sections "x/4 DISCOVERED", unknown hunters are dark silhouettes "???", a new discovery shows NEW! on the INDEX button and the card.
- [ ] UPGRADES (button or the booth right of spawn): buying Pickup Radius makes the ring bigger; Movement Speed makes you faster; Ectoplasm Bonus raises drop values. Prices go up each level; MAXED at level 5.

## C. Zones
- [ ] Walk to the Cemetery gate: purple force field, sign "🔒 1,500 ECTOPLASM". You can't walk through it. Selecting a Cemetery ghost through it says "Unlock CEMETERY first!".
- [ ] `/ecto 2000`, use the gate prompt → UNLOCK: field flashes, drains into the ground, sparks, big "NEW AREA UNLOCKED!". Sign says ✓ UNLOCKED; you can walk in. Lighting tint shifts.
- [ ] Cemetery has its own crate (Haunted, 600) and ghosts; the School gate costs 40,000.
- [ ] Rejoin: the gate stays open, your hunters/currency/upgrades are still there.
- [ ] **Check one house roof** in the Neighborhood: roofs should peak in the middle (if they form a V, tell Claude, it's a one-line fix).

## D. Giant Poltergeist
- [ ] Type `/event`: top banner "⚠️ GIANT POLTERGEIST INCOMING!", pink beacon over the arena (east of the cross street), boss bar with countdown. "📍 SHOW ME" draws a trail to the arena.
- [ ] After 15 s it appears with a flash/ring/shake. Its bar shows Spirit and a 3:00 timer. Attack it with your crew.
- [ ] Defeat it: big poof, "GIANT POLTERGEIST DEFEATED!", a shower of orbs over the arena. Or let the timer run out: "IT ESCAPED...".

## E. Daily, shop, settings
- [ ] DAILY shows Day 1-7 (Day 7 golden). CLAIM gives the reward; then a countdown appears. `/reset-daily` makes it claimable again (Day 2).
- [ ] SHOP shows boosts, Ectoplasm packs and passes; without ids they say SOON.
- [ ] ⚙ Settings: music/sfx/fast opening/auto-next toggle and stay after rejoining.

## F. Devices
- [ ] Test → Device emulator → a phone (e.g. iPhone 14 landscape): every button is reachable, panels fit, tapping ghosts works, the jump button doesn't cover anything important.
- [ ] A gamepad (if you have one): X targets the ghost nearest the screen centre, X again cycles; Y uses prompts; B closes menus.

## G. Saving
- [ ] Stop the test while holding Ectoplasm and hunters; Play again: same numbers.
- [ ] Output window: no red errors. (One yellow warning about DataStores is expected if API access is off.)
