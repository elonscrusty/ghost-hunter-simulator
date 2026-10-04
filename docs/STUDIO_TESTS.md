# v1.7 Studio checks

1. HUD: on desktop and the Studio phone device, the left and right button groups sit a bit higher, nothing overlaps, and the top bar shows Ectoplasm, Power and a 🔮 Spirit Shards counter.
2. DEV menu: GIVE ALL PETS (press twice: no duplicates), HEAL ALL HUNTERS (knocked hunters come back), GIVE SHARDS (type 500: the shard counter goes up), TOWER ROOM (type 12: you start a solo run at Room 12 marked "DEV RUN - no rewards"; beating it gives nothing). Start Rare Pet Event is still there.
3. Fight a ghost: bars above your hunters drop when hit, a beam goes from the ghost to the hunter that was hit, walking away shows DODGED. Knocked hunters appear faded behind you with a 💤 countdown.
4. Open a crate: the hunter that pops out is clearly visible in front of the chest.
5. Index: each hunter shows Normal / ✨ Shiny / 💎 Mega chips; merge 5 copies and the Shiny chip unlocks. Shiny hunters look golden and sparkly in the world, inventory and index; Mega look bigger with a halo.
6. No giant poltergeist appears near the Boss Tower (wait 5+ minutes); the shop has no Summon item.
7. Tower: beat Room 1 -> "BOSS DEFEATED! Rewards collected" with your personal shards/ectoplasm and %, shard orbs fly to you and to the top counter. Clear Room 5 -> checkpoint toast; next time the pad offers START AT ROOM 1 and START AT ROOM 6. Rooms get noticeably harder each time (about +15%, extra jump after every 5).
8. Pets: they look like small cute ghosts with names above them. Rename one in the Pets panel; the new name shows above it. The panel shows the combined bonus of equipped pets.
9. Spawn: the plaza lamps no longer block the paths to the crate, upgrade booth or kiosks.

Only verifiable live: nickname text filtering (Studio filtering can behave differently), checkpoint saving across real sessions.

# Studio playtest checklist

## v1.6 playtest (do this first)
Open `build/GhostHunterSimulator.rbxlx`, turn on **Studio API access** (PUBLISHING.md step 2; without it saving does nothing and some checks below can't pass), press **Play**. Studio saves are real saves for your account: use a throwaway test later if you worry. Anything that fails: note what you saw (a phone photo is fine). Use the 🛠 DEV button (top right) for shortcuts (Ectoplasm, unlock areas, all hunters, START EVENT).

### 1. Old save loads unchanged
1. Press Play with your existing account. Expected: no errors in Output, your Ectoplasm, hunters, areas and pets-free inventory look exactly as before.
2. Open HUNTERS. Expected: every hunter you owned is still there as NORMAL tier (no ✨ or 💎), same power as before.
3. Stop and Play again. Expected: everything still there (Studio saves).

### 2. Ghost retaliation
1. Walk to a ghost and tap it once. Expected: your hunters attack it.
2. Watch the ghost. Expected: a red ❗ appears over ONE of your attacking hunters for about 1 second, then that hunter takes a hit (health bar drops).
3. Stand near the ghost without tapping it. Expected: nothing hits you or hunters that are not attacking.
4. During the red ❗ warning, walk away so your crew gives up. Expected: the hit misses or never lands; crew heals back (after ~4 s).
5. Let the hits keep landing until one hunter hits 0 HP. Expected: it is KNOCKED OUT (greyed, not deleted).

### 3. Knockout timer and Backup Rookie
1. Open HUNTERS. Expected: the knocked-out hunter shows a 2:00 countdown that ticks down. When it hits 0:00 the hunter is back at full health.
2. Get ALL your equipped hunters knocked out (fight a strong ghost with only a weak crew). Expected: a temporary BACKUP Rookie fights for you, labelled BACKUP, and cannot be knocked out.
3. Stop and Play again while a hunter is knocked out. Expected: the timer kept counting (real time).

### 4. Merge: 5 -> Shiny -> Mega
1. DEV > give all hunters, and Ectoplasm. Open HUNTERS and pick a hunter you have 5 copies of (give yourself more if needed).
2. Press MERGE. Expected: a preview shows 5 copies -> 1 ✨ SHINY (about 2.5x power) and the Ectoplasm cost. CONFIRM. Expected: 5 copies become 1 Shiny, cost taken.
3. Make 5 Shiny of the same hunter and merge again. Expected: 1 💎 MEGA (about 6.25x power). Mega cannot merge further.
4. Press 🔒 LOCK on a hunter. Expected: it is skipped by merge (merge refuses or won't count it). 🔓 UNLOCK makes it usable again.

### 5. Trading (needs 2 players)
Studio: **Test** tab > **Clients and Servers** > 2 Players > Start. Two windows open, each its own account.
1. Player A: go to the Trade kiosk (see 8), choose player B, send a request. Expected: B sees a TRADE REQUEST popup. If B does nothing for 30 s it expires.
2. B accepts. Expected: both see a trade window.
3. Each adds a hunter. Expected: both sides update live.
4. A presses CONFIRM. Expected: CONFIRM works only after ~2 s since the last change; shows "CONFIRMED ✅".
5. B changes the offer after A confirmed. Expected: A's confirmation RESETS (must confirm again).
6. Both confirm. Expected: hunters swap, both players' HUNTERS lists correct.
7. Start another trade and press CANCEL. Expected: trade closes, nobody loses anything.
8. Start another trade and have B close the window / leave the game mid-trade. Expected: A's trade cancels and A keeps all hunters.

### 6. Boss Tower
1. Walk to the plaza east of spawn. Expected: the Boss Tower entrance with a glowing pad.
2. Stand on the pad. Expected: you join the party; press START. A 6-second countdown shows, then you enter room 1.
3. Fight the boss (tap it). Expected: it hits back with ❗ warnings like ghosts. Beat it. Expected: payout toast with Ectoplasm and Spirit Shards, a chest appears.
4. Open the chest. Expected: bonus shown. Then ▶ CONTINUE or 🚪 LEAVE. Expected: Continue starts room 2 (30 s to choose, else run ends); Leave returns you to spawn with rewards kept.
5. Let all your hunters get knocked out in a room. Expected: wipe, run ends, shards from earlier rooms are kept.
6. Party of 2: both stand on the pad (2-player test). Expected: both enter; reward split follows damage dealt.
7. Press DEV > START EVENT. Expected: the Giant Poltergeist still spawns in the courtyard as before.

### 7. Pets
1. Beat about 5 tower rooms (shards grow each room), then open PETS. Expected: shop lists Glow Wisp for 40 shards.
2. Buy Glow Wisp. Expected: shards drop by 40, pet owned.
3. EQUIP it. Expected: your Power goes up (~+5%) and a pet floats near you.
4. Equip up to 3 pets (DEV does not give shards, so keep towering). Expected: 4th equip is refused (max 3). Followers are visible and follow you.
5. Unequip one. Expected: Power goes back down.

### 8. Rare Pet event (Studio never touches the live event)
1. DEV > START RARE PET EVENT > CONFIRM. Expected: a 🏮 FREE RARE PET chip shows, DEV text says ACTIVE. Pressing it again says ALREADY STARTED.
2. Press +5 MIN RARE PET PLAY six times. Expected: after 30 min total, "🏮 RARE PET EARNED!" and Lantern Spirit appears in PETS.
3. Reminder: Studio uses a local test copy. It never starts or changes the live event.

### 9. Fall safety
You cannot fall off the map in Studio, so test it by command. While playing, switch to **Server** view (Test tab > Current: Client > Server), open the command bar (View > Command Bar) and run:
`game.Players.LocalPlayer.Character:PivotTo(CFrame.new(0,-60,0))`
If LocalPlayer is nil on the server, use `game.Players:GetPlayers()[1].Character:PivotTo(CFrame.new(0,-60,0))`. Expected: within ~1 s your character is put back on solid ground (rescued), not falling forever.

### 10. Spawn changes
1. Spawn. Expected: the signpost sits at its new spot and does not block the path.
2. Find the 3 kiosks. Expected: they open the Trade panel, the Merge (HUNTERS) panel and the Pets panel.
3. First prompt after joining. Expected: the first tutorial/next-goal prompt still shows.

### 11. Shared rewards
Two players (2-player test): both tap the SAME ghost. Expected: each gets a payout toast showing its % share and the split; totals add up to the normal reward.

### Phone checks (do on the phone separately)
- Red ❗ warning, knockout countdown, backup label readable and not overlapping.
- Merge preview, Trade window, Pets panel and Tower buttons (CONTINUE / LEAVE) fit the screen and are tappable.
- Tower pad prompt, kiosks and pet followers work by tap; frame rate stays smooth with 3 pets out.

### Can only be checked live (not in Studio)
- Rare Pet event syncing across servers, and the 48-hour timer.
- Trade crash recovery (server dies mid-trade) and exactly-once delivery.
- DataStore saves, migration of the real live saves, and the Rare Pet "Id never reused" lock.

---


Open `build/GhostHunterSimulator.rbxlx`, turn on API access (PUBLISHING.md step 2), press
**Play**. Tick each box; anything that fails, note what you saw (a phone photo is fine).
The 🛠 DEV button (top right, next to ⚙) has all test tools. Chat commands also work (Studio or owner only): `/ecto 5000`, `/event`, `/reset-daily`, `/autoattack`
(gives you the Auto Attack pass for this test only), `/zones` (unlocks all 8 areas),
`/hunters` (gives you one of each of the 32 hunters).

## A. First 5 minutes, FREE player (no Auto Attack)
- [ ] Spawn on the glowing HQ plaza. HUD: Ectoplasm 0 at the top, ⚡ 5 POWER under it, six menu buttons in ONE column on the left (HUNTERS, WORLDS, INDEX, UPGRADES, SHOP, DAILY). Your Rookie Hunter stands behind you and **attacks nothing**.
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
- [ ] INDEX: eight zone sections "x/4 DISCOVERED", total "x / 32 DISCOVERED • y%" at the top, unknown hunters are dark silhouettes "???", new discoveries show NEW!.
- [ ] UPGRADES (button or the booth right of spawn): Pickup Radius makes the ring bigger; Movement Speed makes you faster; Ectoplasm Bonus raises drop values. MAXED at level 8 (levels 6-8 are late-game prices).

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
- [ ] Text is small but readable; no giant labels. Menu buttons are one column on the left (they shrink a little on short phones so all six fit).
- [ ] Ghost labels: name + bar with the Spirit number near you. Walk backwards slowly: the label gets slightly SMALLER (never bigger), then disappears. The ghost you tapped shows a bigger bar with "x / y". Bosses (👑) have a bigger label.
- [ ] Hunter name tags only appear when the camera is close.
- [ ] Tapping a ghost works first time, even a small/moving one (you can tap slightly off it). Tapping a button never selects a ghost behind it.
- [ ] Every panel fits on screen with its X visible; long lists scroll; nothing is cut off.
- [ ] Gamepad (if you have one): X targets the ghost nearest the screen centre, X again cycles; Y uses prompts; B closes menus.

## I. Expansion: 8 areas (new this pass)
- [ ] From the school courtyard walk through the school (or around its sides) and out the back door: a path leads to the CARNIVAL gate (🔒 250K ECTOPLASM). From far away you can see the ferris wheel.
- [ ] `/ecto 2000000000` then walk gate to gate unlocking each: Carnival 250K · Hospital 2.5M · Harbor 15M · Castle 90M · Spirit Realm 500M. Each unlock: barrier drains, "NEW AREA UNLOCKED!".
- [ ] In every new area: the crate station is just past the gate on the left, with its own crate (Carnival 60K · Medical 550K · Sailor 3.5M · Royal 22M · Spirit Realm 130M) and odds 60/28/10/2.
- [ ] Every area has 3 ghost types; the last one is a boss (👑, much bigger, bigger label). The SPIRIT OVERLORD in the Spirit Realm is the biggest of all.
- [ ] Ghosts don't sit inside props or each other, and stay inside their area. Kill a few of each: orbs drop (bosses drop more, bigger orbs), you collect them, they respawn.
- [ ] Open one crate in each new area (`/ecto` first): each crate looks different (striped carnival, white medical, rope sailor, gold royal, crystal spirit) but opens with the same animation. Hunters have new hats/tools (top hat, nurse cap, pirate bandana, knight helmet, crystal crown...).
- [ ] `/hunters` then HUNTERS → EQUIP BEST: your crew is the strongest ones; they follow you and attack normally.
- [ ] WORLDS button: 8 cards. Locked ones show 🔒 and the price and can't be used. Pick an unlocked area → you appear next to its crate station, standing on open ground. Spam the button: "Wait a moment..." (3 s cooldown).
- [ ] Each area looks different (carnival tents, white hospital, harbor with a ship and lighthouse, stone castle, floating spirit islands) and mostly NOT glowing; glow only on ghosts, ectoplasm, small lights, crystals, portals.
- [ ] Rejoin: all unlocked areas, hunters and upgrades are still there.
- [ ] Device emulator (phone landscape): walk around in the Harbor and the Spirit Realm for a minute, watch for stutter.

## J. Latest additions
- [ ] Top of the screen: Ectoplasm and POWER pills side by side, same size, centred in the top bar.
- [ ] With the chat window open, the left menu starts below it (nothing hidden behind chat).
- [ ] Beside spawn: TOP GHOST HUNTERS board (fills in after ~10 s; in Studio without API access it lists the players in your test).
- [ ] 💬 button (above ⚙): pick BUG or IDEA, type, SEND → "Thanks!". Sending again within a minute says wait. 🛠 DEV → 💬 READ FEEDBACK shows it (Studio: this session only unless API access is on).
- [ ] Crate panels list 6 hunters: the new MYTHIC (0.4%) and SECRET (0.04%). `/hunters` then INDEX: 6 per area, "x / 48".

## H. Saving
- [ ] Stop while holding Ectoplasm and hunters; Play again: same numbers.
- [ ] Output window: no red errors. (A yellow DataStore warning is expected if API access is off.)
