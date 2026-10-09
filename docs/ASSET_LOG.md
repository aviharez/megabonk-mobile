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
| 2026-10-09 | Gary base sprite | generate_game_art, NB2.1 1K, pixel, 1 image, palette colors passed, style refs `fee7d917` + `399956d3` | 12 | 12 | asset `10fc4560-a44c-4873-8ab2-88730897f556`. Came back 34x34; owner approved at scale 0.67. Balance after: 632 |
| 2026-10-09 | Gary idle animation | animate_game_art from `10fc4560`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `eddb599c-cfb8-42b5-b8ce-2e8bf304f950`, asset `319cf24a-87d7-4656-91a1-3bdb53aee94f`. Balance after: 612 |
| 2026-10-09 | Gary walk animation | animate_game_art from `10fc4560`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `24491d8b-b3ed-473b-b8c1-f5ebed135e84`, asset `48c2dd61-0e1d-4360-91d6-1539ef32aca5`. Balance after: 592 |
| 2026-10-09 | Gary hit animation | animate_game_art from `10fc4560`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `b9e6f4d5-e68c-4a6c-acc0-bc2ed568337c`, asset `d48eee82-101a-40a1-9daa-0967af49702b`. All three Gary clips shrunk without palette dark red (it made a bloody-looking eye) and the stapler re-reddened with `tools/art/gary_stapler.py` (owner choice). Balance after: 572 |
| 2026-10-09 | Mega Mole base sprite | generate_game_art, NB2.1 1K, pixel, 1 image, palette colors passed, 48px hint, style refs the 3 heroes | 12 | 12 | asset `88627398-7d7e-4079-be57-d06f76ef5be4`. Came back 34x34 (hint ignored); owner approved at full size (33x33). Balance after: 560 |
| 2026-10-09 | Mega Mole walk animation | animate_game_art from `88627398`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `c045cb6e-df3b-4c17-ac05-bae714038069`, asset `612cac51-90fd-4cae-95c2-751794b3b14a`. Owner approved. Balance after: 540 |
| 2026-10-09 | Mega Mole burrow animation | animate_game_art from `88627398`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `38316f3a-f8f2-40bb-839d-e87583697924`, asset `657a9412-8e66-4a52-9c10-e551fbb6b732`. Didn't dig (pink-blob head, ends curled up above ground); not used. Burrow built from his walk frame with `tools/art/mole_burrow.py` (owner choice). Balance after: 520 |
| 2026-10-09 | Mega Mole attack animation | animate_game_art from `88627398`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `6d19f29a-7324-4350-832e-a96d80021aec`, asset `590c9371-08b3-445f-bc59-a3a106756356`. Owner approved. Balance after: 500 |
| 2026-10-09 | Mega Mole hit animation | animate_game_art from `88627398`, 4 frames, spritesheet, default pixel engine | 20 | 20 | job `c19e8657-0940-4f83-9023-4434477ed1b9`, asset `e7d871bf-882c-41ec-b21c-434bbaa45c35`. Owner approved. Balance after: 480 |
| 2026-10-09 | Baguette weapon icon (icon style reference) | generate_game_art, NB2.1 1K, pixel, 1 image, palette colors passed, 32px hint, style refs the 3 heroes | 12 | 12 | asset `9b021e66-e82a-4cb2-be85-d7ea1c4a62e0`. Came back 32x32; shrunk to 16x16 with `tools/icon_shrink.py` into `assets/icons/weapons/baguette.png`. Owner approved. Balance after: 468 |

**Running total:** 332

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
