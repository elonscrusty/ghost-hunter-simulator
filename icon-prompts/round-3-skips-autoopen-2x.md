# Round 3: crate skips, Auto Open, 2X event

Paste the STORE STYLE block from `round-2-new-items-and-areas.md` first, then one prompt.
All: **512×512 PNG, square 1:1**, centred subject (Roblox crops store icons to a circle),
**no text, no letters, no numbers**. Upload as Images and send Claude the ids; until then the
game shows emoji (⏩ 🔁), so nothing is blocked.

| File | Used for | Background | Prompt (after STORE STYLE) |
|---|---|---|---|
| `pass_permskip.png` | Permanent Crate Skip pass (store page + in-game shop card) | Orange radial glow | A cute treasure-chest hunter crate with a big glowing "fast-forward" double-arrow symbol made of light bursting out of the open lid, speed lines, a small golden infinity ribbon wrapped around the crate. |
| `pass_autoopen.png` | Auto Open pass (store + shop card + crate panel) | Purple radial glow | Three cute treasure-chest crates on a little conveyor belt, each lid popping open by itself with sparkles, a circular "repeat" arrow loop glowing around them. |
| `prod_singleskip.png` | Single Crate Skip product (10 R$) | Teal radial glow | One cute treasure-chest crate with a single glowing fast-forward arrow zooming past it, small sparkles, simple and readable at tiny size. |

Optional (only if you want a fancier 2X popup; the game already has a styled popup without it):

| File | Used for | Size | Prompt |
|---|---|---|---|
| `event_2x_banner.png` | 2X ECTOPLASM EVENT popup header art | **1024×512 PNG (2:1), transparent background** | Same cute spooky simulator style, thick dark-purple outline: a giant glossy green ectoplasm blob splitting into two blobs with happy faces, bright green and gold sparkles bursting outward, a couple of cute white ghosts cheering on the sides. Leave the centre-top empty. **No text.** |

Where the ids go (Claude does this): `src/shared/Icons.luau` → `pass_permskip`, `pass_autoopen`,
`prod_singleskip` (and `event_2x_banner` if you make it).
