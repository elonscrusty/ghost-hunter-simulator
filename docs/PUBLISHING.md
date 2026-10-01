# Publishing Ghost Hunter Simulator

Plain steps, in order. You need Roblox Studio on your PC. Nothing here needs code, except
pasting a few numbers into one file (step 5), which Claude can do for you if you send the ids.

## 1. Open the game
1. Download `build/GhostHunterSimulator.rbxlx` from the GitHub repository (ghost-hunter-simulator).
2. Double-click it (or Studio → File → Open from File).

## 2. Turn on saving in Studio
1. File → **Publish to Roblox As…** → *Create new game* → name it **Ghost Hunter Simulator**.
2. Home → **Game Settings** → **Security** → turn ON **Enable Studio Access to API Services**.
   (Without this, progress isn't saved in Studio test runs. The game prints a warning.)

## 3. Playtest
Press **Play** and go through [STUDIO_TESTS.md](STUDIO_TESTS.md). Studio-only chat commands help:
- `/ecto 5000` gives you Ectoplasm
- `/event` starts the Giant Poltergeist now
- `/reset-daily` makes the daily reward claimable again

## 4. Game settings (Home → Game Settings)
- **Basic Info**: description, genre *Adventure* (or *Simulator*), icon and thumbnails.
- **Avatar**: R15 is fine. Leave **Collision** default.
- **Permissions**: set the game **Public** only when you're happy with the test run.
- **Monetization**: create the products in step 5 first.
- Maturity questionnaire: answer it (no violence/blood: ghosts poof, nobody gets hurt).

## 5. Robux products (optional, the shop works without them: items show "SOON")
On the Creator Hub (create.roblox.com → your game → Monetization):
1. **Developer Products** → create these 4 (names/prices are suggestions):
   - Sack of Ectoplasm (49 R$) · Barrel of Ectoplasm (199 R$) · 30 Min Luck Boost (49 R$) · 30 Min 2x Ectoplasm (49 R$)
2. **Passes** → create these 2:
   - +2 Hunter Slots (149 R$) · Permanent 2x Ectoplasm (299 R$)
3. Copy each id and put it in `src/shared/Config.luau`:
   `Config.Products` → `ProductId = 123456789` and `Config.GamePasses` → `PassId = 123456789`.
   (Or send the ids to Claude.) Then rebuild the place (Claude does this).

## 6. Sounds
The game uses Roblox's built-in placeholder sounds so it isn't silent. Before a public launch,
pick nicer ones from the Creator Store: see [AUDIO.md](AUDIO.md) for the exact list. Music is
silent until you choose a track.

## 7. Publish
File → **Publish to Roblox** (Alt+P). Then on the game page set it **Public**.

## After launch
- Servers: the default max players is fine (10-20). The map and systems are built for mobile.
- Saving uses the DataStore `GhostHunterData_v1`. Don't rename it, or players lose progress.
