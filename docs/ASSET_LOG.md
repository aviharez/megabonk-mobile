# Asset log

SpriteCook credits (Starter plan, 800 per month). Ask before every generation. No variations by default.

| Date | Asset | Kind | Est. credits | Actual | Notes |
| --- | --- | --- | --- | --- | --- |
| 2026-10-09 | Sir Loaf base sprite (style reference) | generate_game_art, NB2.1 1K, pixel, 1 image, palette colors passed | 12 | 12 | asset `b7b40484-050b-469a-8a47-2d056ff97959` (ids in `docs/spritecook-assets.json`). Came back 76x76 and off-palette (2866 colours) despite the 24x24 hint and colour list; snapped + hand-cleaned to 24x24. Balance after: 788. Owner rejected the bread type |
| 2026-10-09 | Sir Loaf, tin loaf version | generate_game_art, NB2.1 1K, pixel, 1 image, palette colors passed | 12 | 12 | asset `fee7d917-1fb3-4af0-b3cb-4675bfb77734`. Came back 34x34, 617 colours; snapped to 32x33. Balance after: 776. Owner approved; shrunk to 25x26, visor redrawn by hand |
| 2026-10-09 | Sir Loaf idle animation | animate_game_art from `fee7d917`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `711f4a07-b033-4388-82f0-ab58bd57ccf6`, asset `34e0d793-98d3-4061-846f-14fbb4412c65`. 4 frames 38x38 at 8 fps; shrunk by the same factor as the still (27x30 frames), visor redrawn per frame. Owner approved. Balance after: 756 |
| 2026-10-09 | Sir Loaf walk animation | animate_game_art from `fee7d917`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `5b3744d4-303c-4553-9daf-e82050195fcc`, asset `27d5a82b-bd1d-4ebc-ac0c-c18abf234f93`. Feet barely moved (about 1px after shrinking); tried a hand redraw of the feet; owner preferred the original, so it is used unedited. Owner approved. Balance after: 736 |
| 2026-10-09 | Sir Loaf hit animation | animate_game_art from `fee7d917`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `a0860baa-90cc-46b8-9809-ac8ba2fff348`, asset `12c64ab2-09ef-439c-9dd6-83ee82bcff1c`. Subtle tilt rather than a big flinch; 28x31 frames after shrinking. Owner approved. Balance after: 716 |
| 2026-10-09 | Turbo Pigeon base sprite | generate_game_art, NB2.1 1K, pixel, 1 image, palette colors passed, style ref `fee7d917` | 12 | 12 | asset `399956d3-e837-4d38-8c4b-ee52656a9e88`. Came back 32x32; owner approved at scale 0.8 (25x28). Balance after: 704 |
| 2026-10-09 | Turbo Pigeon idle animation | animate_game_art from `399956d3`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `a7eb3aab-9907-4b02-841a-bf2212a4d2fb`, asset `538c179d-24fc-48db-88e8-a7896379ab32`. Balance after: 684 |
| 2026-10-09 | Turbo Pigeon walk animation | animate_game_art from `399956d3`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `89a911ec-a50f-44ad-a384-2ce795c16daa`, asset `79c020cd-404c-4153-b9cd-65d090814b43`. Balance after: 664 |
| 2026-10-09 | Turbo Pigeon hit animation | animate_game_art from `399956d3`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `2c2502f1-438a-4aee-a39c-b9a11fe946d3`, asset `428a4900-fe74-4a46-bdc5-f8c5d37094f1`. Balance after: 644 |

**Running total:** 156

## Non-SpriteCook placeholders

| Date | Asset | Source |
| --- | --- | --- |
| 2026-10-05 | `assets/palette.png` (temporary 32 colors) | Hand-picked, `tools/gen_placeholder_assets.py` |
| 2026-10-05 | `assets/fonts/pixel.*` (5x7 bitmap font) | Hand-drawn glyphs, `tools/gen_placeholder_assets.py` |
| 2026-10-05 | `assets/icon/icon*.png` (placeholder loaf icon) | Hand-drawn, `tools/gen_placeholder_assets.py` |
| 2026-10-05 | `assets/creatures/blob.png` (Blob walk, 5 frames 19x16) | procedural-pixel-creatures, amorphous/ooze seed 114, palette-snapped with `tools/palette_snap.py`; owner-approved. Commands in `tools/creature_export/README.md` |
| 2026-10-05 | `assets/creatures/skitter.png` (Skitter walk, 4 frames 18x15) | procedural-pixel-creatures, arthropod/spider seed 28, palette-snapped; owner-approved |
| 2026-10-05 | `assets/creatures/chomper.png` (Chomper walk, 4 frames 28x20) | procedural-pixel-creatures, quadruped/beast seed 5, palette-snapped; owner-approved |

2026-10-09: both heroes re-shrunk to ~22px tall (scale 0.67) from the downloaded SpriteCook sheets on owner request; no new generations.
