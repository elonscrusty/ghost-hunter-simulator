# Icon prompts for ChatGPT (image generation)

How to use:
1. Paste the **STYLE** block first, then one item's line (or a few at once).
2. Ask for one icon per image, **512×512 PNG with a transparent background**.
3. Upload each PNG to Roblox (Creator Hub → Development Items → Decals, or Studio Asset Manager → Bulk Import).
4. Send Claude the image asset ids with the file names below. Each one goes into `src/shared/Icons.luau`.
   Until an id is filled in, the game keeps showing its emoji.

## STYLE (paste this every time)

> Create a single game UI icon for a Roblox simulator called "Ghost Hunter Simulator".
> The style is cute, spooky, colourful cartoon, like popular Roblox simulator icons (Pet Simulator / Bee Swarm style).
> - Chunky, rounded shapes with a thick dark-purple outline (#2A1846), about 6% of the icon width.
> - Soft cel shading with one bright highlight and one shadow tone.
> - Saturated candy colours. Ectoplasm green (#7CFF8A to #2EE6A0) and spooky purple (#9B5BFF) are the signature accents.
> - The object is centred, fills about 85% of the canvas and is seen slightly from the front-top (3/4 view).
> - No text, no letters, no numbers, no background scene, no frame, no drop shadow outside the outline.
> - It must read clearly at 48×48 pixels on a phone screen, so use a simple silhouette and few details.
> - Use a transparent background, 512×512 PNG.
> - Make it friendly and fun, not scary or realistic, with no gore.

## 1. Main menu buttons (left column)
| File | Prompt (after STYLE) |
|---|---|
| `menu_hunters` | A chunky yellow ghost-hunting flashlight with a green ectoplasm beam glow at the lens, and a small cute white ghost peeking from behind it. |
| `menu_worlds` | A round cartoon globe made of floating islands: a tiny haunted house, a ferris wheel and a castle tower, with a teal portal swirl behind it. |
| `menu_index` | A thick purple spell-book / field journal with a ghost emblem on the cover, slightly open with green glowing pages and a bookmark ribbon. |
| `menu_upgrades` | A big red-and-silver horseshoe magnet pulling three small green ectoplasm blobs toward it, with an orange up-arrow beside it. |
| `menu_shop` | A cute purple shopping bag with a ghost face on it, overflowing with green ectoplasm blobs and a gold coin. |
| `menu_daily` | A gift box wrapped in purple paper with a bright green ribbon bow, and a tiny calendar page tucked into the bow. |
| `menu_settings` | A rounded silver cog/gear with a small ghost-shaped hole in the middle. |

## 2. Currency and stats
| File | Prompt |
|---|---|
| `ecto` | One glossy blob of glowing green ectoplasm (slime drop shape) with a cute shine and a tiny sparkle. This is the main currency, so make it extra appealing. |
| `ecto_pile` | A pile of six glossy green ectoplasm blobs with sparkles. |
| `power` | A yellow-orange lightning bolt with a small ghost-hunter energy ring around it. |

## 3. Upgrades
| File | Prompt |
|---|---|
| `up_pickup` | A blue-and-red magnet with circular green "range" rings expanding out from it. |
| `up_ectobonus` | A green ectoplasm blob with a big gold "plus" shape and an up arrow. |
| `up_speed` | A cartoon running sneaker (orange and white) with speed lines and a little purple wing. |

## 4. Boosts and shop
| File | Prompt |
|---|---|
| `boost_ecto2x` | Two overlapping green ectoplasm blobs with a glowing lightning bolt between them, giving an energetic, doubled feel. |
| `boost_luck` | A shiny green four-leaf clover with tiny gold sparkles and a small ghost tail curling around the stem. |
| `shop_ecto_sack` | A brown burlap sack tied with a purple rope, bulging and spilling green ectoplasm blobs. |
| `shop_ecto_barrel` | A wooden barrel with metal bands, overflowing with glowing green ectoplasm slime dripping down the sides. |
| `pass_slots` | A cute backpack with two extra glowing green "+" slot pockets and a ghost-hunter badge. |
| `pass_ecto2x` | A big faceted green gem shaped like an ectoplasm drop, crowned with a small gold crown. |
| `pass_autoattack` | A cute small robot drone with a ghost-hunter flashlight arm, a green target reticle above it, and a play-symbol on its chest. |

## 5. The 8 worlds (Fast Travel cards and zone gates)
Each is a round badge-style scene icon: a circular emblem with one landmark in front of a night sky in the zone's colours.
| File | Prompt |
|---|---|
| `zone_neighborhood` | A round badge with a cozy purple-roofed haunted suburban house, orange jack-o'-lanterns and green grass. |
| `zone_cemetery` | A round badge with a stone mausoleum with a green glowing doorway, pastel gravestones, dark green grass and a warm orange lantern. |
| `zone_school` | A round badge with a warm red-brick school with a clock tower, cream trim, a blue school bus and purple ghostly windows. |
| `zone_carnival` | A round badge with a red-and-cream striped circus tent and a yellow-blue ferris wheel behind it, with small purple ghost lights. |
| `zone_hospital` | A round badge with a friendly off-white hospital building with a light-blue cross sign, muted green trim and purple spooky windows. |
| `zone_harbor` | A round badge with a wooden ghost pirate ship with teal tattered sails on deep blue water, and a red-and-white lighthouse. |
| `zone_castle` | A round badge with a gray stone fantasy castle with dark-blue cone roofs, red/purple banners, gold trim and a green spectral glow. |
| `zone_spiritrealm` | A round badge with floating dark rock islands, giant cyan and purple crystals, a swirling portal and a glowing spirit tree. |
| `lock` | A chunky gold padlock with a ghost-shaped keyhole and a purple outline. |

## 6. Crates (shop cards / crate panel)
Same chest shape for all eight crates, getting fancier with progress. Ask for "a cute chunky treasure-chest-style hunter crate, front 3/4 view, lid slightly open with light leaking out".
| File | Prompt |
|---|---|
| `crate_beginner` | Orange wooden chest, green trim bands, a white ghost emblem on the front. |
| `crate_haunted` | Purple chest, mint-green bands, small wisps curling off it. |
| `crate_elite` | Dark navy chest, violet trim, metal corner caps and rivets. |
| `crate_carnival` | Red-and-cream striped chest, gold bands, a gold star on the lid. |
| `crate_medical` | White chest, light-blue bands, a blue cross emblem and silver latches. |
| `crate_sailor` | Wooden-plank chest wrapped in rope, teal glow, a small anchor emblem. |
| `crate_royal` | Purple chest, heavy gold trim, a gold crown on the lid and a red gem on the front. |
| `crate_spirit` | Dark containment chest in a metal cage frame, with cyan crystal spikes and glowing rune rings. |

## 7. Store page (not used in-game; for publishing)
| File | Prompt |
|---|---|
| `game_icon` (1024×1024, NOT transparent) | A Roblox game icon for "Ghost Hunter Simulator". A chibi kid ghost hunter (big head, cap, goggles, backpack vacuum) is blasting a green beam at a cute surprised white ghost. Green ectoplasm blobs fly out. Purple night sky, haunted house silhouette. Bright and colourful, thick outlines. Leave the top quarter free for a title. |
| `thumb_1` (1920×1080) | A wide Roblox thumbnail. A crew of four chibi ghost hunters with different outfits fight a giant cute ghost boss in a colourful haunted neighborhood at night, with green ectoplasm raining out. Use the same style but a full background scene and dramatic composition. |
| `thumb_2` (1920×1080) | A wide thumbnail. A glowing treasure-chest crate bursts open and a golden legendary chibi ghost hunter jumps out in a beam of light, with "rarity" sparkles, a purple background and confetti. |
| `thumb_3` (1920×1080) | A wide thumbnail. A map collage of the 8 worlds connected by a winding path: haunted houses, a cemetery, a school, a carnival, a hospital, a ghost ship harbor, a castle and a floating spirit realm. |

Tip: if ChatGPT draws text into an icon, reply "same icon, remove all text".
