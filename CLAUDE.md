# Ghost Hunter Simulator: notes for Claude

Roblox collection simulator (Rojo + Luau). The owner (kcdrewcarter) plays on a phone while away from their PC and isn't a programmer. This repository is only Ghost Hunter; Survival Hour and the owner's other games live in their own repositories and must stay separate.

## How to work here
- **Caveman mode is always on.** From the first reply of every session, write chat replies in the style of `.claude/skills/caveman/SKILL.md` at level **lite**, without waiting for `/caveman`. The owner can switch with `/caveman full|ultra` or turn it off with "normal mode". Code, commits and docs stay in normal prose.
- **Keep replies short.** Do the work, then give a 2-4 line plain-English summary. Don't narrate each step.
- Work autonomously; don't ask for approval on routine steps. Ask only when a real decision belongs to the owner.
- Start from `docs/STATUS.md`; `docs/ARCHITECTURE.md` maps every system. Update STATUS.md when a pass finishes.
- `build/` is generated and blocked from reading. Commit `build/GhostHunterSimulator.rbxlx` (the owner downloads it) once at the end of a work session: `git restore build/` before intermediate commits.
- Push to the branch the session gives you. No PRs unless asked. Commit messages end with the attribution lines the session provides. Never put model names in commits or code.

## Commands
- `bash tools/check.sh`: strict type check (must stay at 0 diagnostics), unit tests, headless world/rig smoke test (`tools/worldsim.sh`: builds the whole map and every rig under a mock runtime; checks ghost areas, spawn pads, the main route, budgets), Rojo build. Run before every commit. `--quick` skips the build.
- `cd tests && luau EconSim.luau` (after check.sh, which generates `tests/_Config.luau`): economy simulation; re-run after changing prices, rewards, Spirit or power.
- Tools install at session start (`tools/setup_env.sh` → `/tmp/gh-tools`, luau-lsp pinned to 1.53.0).
- Unit tests: `tests/*.spec.luau`, registered in `tests/run.luau`. The CLI has no Roblox types, so testable rules stay pure in `src/shared/Logic/`.

## Rules that must hold
- Server authority: the client never decides currency, crate results, damage, pickups, zones, upgrades or purchases. Every Request handler validates its arguments.
- All balance numbers and content live in `src/shared/Config.luau`; don't scatter values in scripts.
- Keep it mobile-friendly: one loop per system (no per-ghost/per-orb connections), capped effects.
- Shop (owner-approved): Robux buys Ectoplasm packs, boosts, passes (slots, 2x Ecto, Auto Attack, Lucky, Triple Open, Super Magnet, VIP, Storage, cosmetic beams/trail), Unlock Next Area, an Exclusive Crate (1.5x Legendary of your best area), Server Luck and Summon Event. Never sell Mythic/Secret hunters or big damage multipliers; ask the owner before adding new kinds of Robux items.

## Pending (owner's side)
- Playtest in Studio (`docs/STUDIO_TESTS.md`); nothing has been run in Studio yet.
- Create the 4 developer products and 2 passes and send the ids (`docs/PUBLISHING.md` step 5).
- Choose music and better sounds (`docs/AUDIO.md`).
