# Studio playtest checklist

Open `build/GhostHunterSimulator.rbxlx`, turn on API access (PUBLISHING.md step 2), press
**Play**. Tick each box; anything that fails, note what you saw (a phone photo is fine).
Chat commands (Studio only): `/ecto 5000`, `/event`, `/reset-daily`, `/autoattack`
(gives you the Auto Attack pass for this test only).

## A. First 5 minutes, FREE player (no Auto Attack)
- [ ] Spawn on the glowing HQ plaza. HUD: Ectoplasm 0 at the top, ⚡ 5 POWER under it, menu buttons on the left. Your Rookie Hunter stands behind you and **attacks nothing**.
- [ ] After ~2 s the camera swings to the nearest ghost and back. A small "CLICK A GHOST!" (or "TAP A GHOST!") pill appears low in the middle, with a bouncing arrow over a ghost and glowing dots on the ground.
- [ ] Click/tap a ghost ONCE: soft outline + coloured ring on the ground under it, a ping, its label grows and shows "30 / 30 SPIRIT", and your hunter runs over immediately and fires a beam. No more clicking needed.
- [ ] The ghost puffs up and POOFs (flash, smoke, ring). Green orbs splash out, bounce and hover.
- [ ] Your hunter does a victory pose and **walks back to you**. It does **not** go to another ghost by itself.
- [ ] "COLLECT ECTOPLASM!": walk near the orbs; they zoom into you (rising pings), the counter counts up, "+5" floats. A faint ring shows your pickup radius while orbs are near.
- [ ] Nothing else gets attacked until you tap another ghost. Walk away from a fight (far): the hunter gives up and comes back.
- [ ] At 25 Ectoplasm: "OPEN A HUNTER CRATE!" with a trail to the Beginner crate (left of spawn, spinning crate, odds board).
- [ ] Press E / tap the prompt: crate panel with 4 hunters, odds 60% / 28% / 10% / 2%, OPEN 💚 25.
- [ ] Opening: flash, crate drops and bounces, shakes, locks pop, lid flies open, burst, hunter leaps out and poses. Card shows name, rarity, Capture Power, NEW!. SKIP works at any point.
- [ ] EQUIP on the card (or HUNTERS → EQUIP BEST). Tutorial says "UNLOCK THE CEMETERY!". Both hunters attack the next ghost you tap; it dies noticeably faster.

## B. Auto Attack owner
- [ ] Without the pass there is no AUTO button on the HUD; SHOP shows AUTO ATTACK (SOON until its pass id is set).
- [ ] Type `/autoattack`: a "🤖 AUTO: OFF" button appears top-right under ⚙.
- [ ] Turn it ON: the crew picks the nearest ghost (in the area you're standing in, within ~45 studs), kills it, then picks the next one, and so on. Orbs still only come to you when you walk near (no auto-collect).
- [ ] Damage and rewards look the same as manual (same Spirit drop speed, same orb counts).
- [ ] Turn it OFF mid-fight: the crew comes home right away (unless you had tapped that ghost yourself). Tapping ghosts works normally.
- [ ] Rejoin: Auto Attack starts OFF.

## C. Hunters, index, upgrades
- [ ] HUNTERS: compact cards with portrait, name, ⚡, rarity colour; ✓ on equipped. EQUIPPED x/4. Sort POWER/RARITY. Tap a card → 3D preview, EQUIP/UNEQUIP, LOCK, RELEASE (the pane scrolls on small screens).
- [ ] You can't unequip your last hunter; you can't release equipped or locked hunters. RELEASE → SELECT WEAK → RELEASE gives a small refund.
- [ ] INDEX: three zone sections "x/4 DISCOVERED", unknown hunters are dark silhouettes "???", new discoveries show NEW!.
- [ ] UPGRADES (button or the booth right of spawn): Pickup Radius makes the ring bigger; Movement Speed makes you faster; Ectoplasm Bonus raises drop values. MAXED at level 5.

## D. Zones
- [ ] Cemetery gate: force field, sign "🔒 1,500 ECTOPLASM". You can't walk through it. Tapping a Cemetery ghost through it says "Unlock CEMETERY first!".
- [ ] `/ecto 2000`, gate prompt → UNLOCK: field flashes and drains into the ground, "NEW AREA UNLOCKED!". Sign says ✓ UNLOCKED; you can walk in. Lighting tint shifts.
- [ ] Cemetery has its own crate (Haunted, 600) and ghosts; the School gate costs 40,000; Elite crate 9,000.
- [ ] Rejoin: the gate stays open, your hunters/currency/upgrades are still there.
- [ ] **Look at one house roof**: roofs should peak in the middle (a V shape = tell Claude, one-line fix).
- [ ] The world should look colourful but **not** glowing everywhere (neon only on small accents like windows, lanterns, eyes).

## E. Giant Poltergeist
- [ ] `/event`: "⚠️ GIANT POLTERGEIST INCOMING!", pink beacon over the arena, compact boss bar with countdown. "📍 SHOW ME" draws a trail to the arena.
- [ ] After 15 s it appears with a flash/ring/shake. Bar shows Spirit and a 3:00 timer. Tap it to attack.
- [ ] Defeat it: big poof, "GIANT POLTERGEIST DEFEATED!", a shower of orbs over the arena. Or let the timer run out: "IT ESCAPED...".

## F. Daily, shop, settings
- [ ] DAILY: Day 1-7 tiles (Day 7 golden). CLAIM gives the reward, then a countdown. `/reset-daily` → claim Day 2.
- [ ] SHOP: boosts, Ectoplasm packs and passes (incl. AUTO ATTACK); without ids they say SOON.
- [ ] ⚙ Settings: music / sound effects / fast crate opening toggle and stay after rejoining.

## G. Mobile (Test → Device emulator: iPhone 14 landscape, iPhone SE landscape, iPad)
- [ ] Text is small but readable; no giant labels. Menu buttons are a 2×3 block top-left, clear of the thumbstick.
- [ ] Ghost labels: small name + thin bar near you; far ghosts show no label; the ghost you tapped shows a bigger bar with numbers.
- [ ] Hunter name tags only appear when the camera is close.
- [ ] Tapping a ghost works first time, even a small/moving one (you can tap slightly off it). Tapping a button never selects a ghost behind it.
- [ ] Every panel fits on screen with its X visible; long lists scroll; nothing is cut off.
- [ ] Gamepad (if you have one): X targets the ghost nearest the screen centre, X again cycles; Y uses prompts; B closes menus.

## H. Saving
- [ ] Stop while holding Ectoplasm and hunters; Play again: same numbers.
- [ ] Output window: no red errors. (A yellow DataStore warning is expected if API access is off.)
