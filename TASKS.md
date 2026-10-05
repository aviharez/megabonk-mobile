# Tasks

## Phase 0: Setup

- [x] Godot 4.7 project (4.7.2 stable), GDScript, Compatibility renderer (desktop + mobile)
- [x] 180x320 portrait viewport, viewport stretch mode, integer scaling, Nearest filter, portrait locked, 2D pixel snapping
- [x] Folders: `data/`, `assets/`, `scenes/`, `scripts/` (+ `tests/`, `tools/`)
- [x] Temporary 32-color palette in `assets/palette.png` (index 31 magenta reserved for enemy projectiles)
- [x] 5x7 pixel bitmap font + UI theme (no non-pixel fonts)
- [x] Basic main menu: title, coin counter, PLAY, UNLOCKS/SHOP (disabled), SETTINGS with saved toggles
- [x] Versioned JSON save in `user://save.json` (migrations, defaults merge, atomic write, .bak fallback, newer-version guard)
- [x] Headless test runner + tests (save, project settings, palette check on every PNG)
- [x] Project runs without errors (headless and windowed)
- [x] Android debug APK exports and is signed (`build/android/swarm-survivor-debug.apk`)
- [x] Install and launch the debug APK on the phone (Xiaomi 15T, 2026-10-05: menu renders, no errors in logcat)

## Phase 1: Core loop with placeholders

Scope from docs/BRIEF.md: geometric-shape placeholders throughout.

- [x] Run scene replaces `scenes/run.tscn` placeholder; bounded 720x720 arena with fence, camera follows player on whole pixels
- [x] Virtual joystick (`ThumbStick`: appears where the thumb lands, dead zone), keyboard fallback (WASD/arrows) on desktop
- [x] Data loader `GameData` for `data/` (characters, weapons, enemies, tomes, maps, rules) with validation errors that name the file
- [x] Sir Loaf as data: base stats (HP, speed, pickup range, armor, regen...), Getting Stale passive implemented (data-driven numbers)
- [x] Minimal stat object: base + flat/percent modifiers keyed by source (`Stat`, `StatBlock`)
- [x] Baguette weapon as data: spinning swing, area damage around the player, 5 levels (`spin_swing` pattern)
- [x] Enemy roles in code: slow chaser (Blob), fast pack (Skitter); enemies as data
- [x] Enemy rendering without per-enemy physics nodes (MultiMesh per enemy type) + spatial grid for collision/separation
- [x] Spawner: off-screen spawns, minute-based rate for Blobs/Skitters from `data/maps/suburbia.json`
- [x] Contact damage, player HP, brief i-frames, death
- [x] XP gems: drop on kill, magnet pull inside pickup range, merge into nearest gem when the pool is full
- [x] Level-up: pause, 3 cards (new/upgrade Baguette, start tomes as stat cards, SNACK fallback), resume
- [x] HUD: HP bar, XP bar, level, timer, kill count (pixel font, palette only)
- [x] 8-minute timer; run ends at death or timer end; game-over screen back to menu; pause on back/Esc/app pause
- [x] Record run result in save (runs_played, coins earned)
- [x] Object pools: enemies, projectiles, XP gems (SlotPool, struct-of-arrays), damage numbers (fixed ring), particles (NodePool of CPUParticles2D)
- [x] 300-enemy cap; past the cap, blocked spawns raise HP/damage/speed (speed capped at 1.5x) of later spawns
- [x] Stress test: `scenes/debug/bot_run.tscn -- --mode=stress` keeps 300 enemies on screen, reports average fps (desktop done; on device still open, see below)
- [x] Tests for pools, stat modifiers, spawner cap, level-up card rules, data validation, run flow (124 checks; run with `tools/run_tests.sh`, which also fails on script errors)
- [x] Blob dies in one hit at any minute and past the cap (`"one_hit": true` in data)
- [x] Debug scenes and scripts excluded from the Android export
- [x] End-to-end screen check: `scenes/debug/flow_check.tscn` (menu -> run -> death -> game over -> menu)
- [x] Full-run bot simulation: `scenes/debug/bot_run.tscn -- --mode=sim` (headless, `--fixed-fps 30`)
- [x] Stress test on the Android phone (`Android Stress` export preset boots into the stress test; results below)

### Phase 1 results (2026-10-05, desktop: Ryzen 7 8845HS / Radeon 780M, Compatibility renderer)

| Stress test, 300 enemies, 30 s | Avg fps | 1% low fps | Logic ms/frame | Avg on screen |
| --- | --- | --- | --- | --- |
| Windowed, vsync on | 75.0 (display cap) | 66.3 | 2.39 | 299.1 |
| Windowed, uncapped | 652.3 | 399.2 | 1.17 | 299.8 |

| Phone: Xiaomi 15T (MT6899, Mali-G720 MC7, Android 16), vsync, 60 Hz | Avg fps | 1% low fps | Logic ms/frame | Avg on screen |
| --- | --- | --- | --- | --- |
| Run 1, 30 s | 60.0 | 50.2 | 3.91 | 298.9 |
| Run 2, 30 s, gem pool full (merging) | 60.1 | 51.5 | 4.39 | 298.6 |

The 15T is upper mid-range, not the low-end target in the brief. Logic is ~3.5x slower than the desktop; a phone 3x slower again would be near the 16.6 ms budget.

Bot sims (8-minute runs, seeds 1-3): 2 reached the timer, 1 died at 4:05; one run hit the 300 cap (257 spawns turned into escalation).

## Phase 2: Stat system and all build content

- [x] Stat system: every stat = base + flat/percent modifiers keyed by source; defaults, min/max caps (`StatBlock`), 20 stats incl. crit, evasion, shield, luck, gold, projectiles, curse stats
- [x] Event hooks as signals + `ItemSystem.emit`: on_hit, on_kill, on_damaged, on_level_up, on_chest_opened, on_shrine_activated, on_attack, on_projectile, every (timer)
- [x] Item engine from data: modifiers, triggers (event + chance + effect), conditions; stacking with diminishing chances
- [x] Rarity + chests: `Loot.roll` with chest kinds (paid / elite Rare+ / boss Epic+), luck shift, legendary limit, rules in `data/rules/loot.json`
- [x] Content pool (`ContentPool`): start / owned unlocks / signature of owned character
- [x] Combat helpers in `Run`: crits, burns, blasts, chain zaps, `fire_shot` (Clone Machine hook), gold, shield, evasion; `Fx` layer
- [x] 10 weapons as data, 9 new patterns (subagent; reviewed: each hits through `hit_enemy` with its id, fires through `fire_shot`, follows the stat rules in `weapon.gd`)
- [x] 16 tomes as data (subagent; the 6 phase 1 tomes reviewed, unchanged)
- [x] 15 items as data (subagent)
- [x] Check every entry against the brief (by hand + encoded in `tests/test_content.gd`: counts, status, rarity, group, stat or trigger per entry, no shared weapon patterns, text fits the pixel font)
- [x] Automated test: every entry loads, can appear on a card / in a chest, applies in a live run without errors (`tests/test_content.gd`, `tests/test_weapons.gd`, `tests/test_items_engine.gd`)
- [x] Slot rules (4 weapons, 4 tomes, level 5 max) and rarity rules (chest floors, luck, stacking, one legendary per run) tested
- [x] Run project + tests: 412 checks pass, flow check OK, bot sim with chests OK
- [x] 300-enemy fps with a full build (`bot_run.tscn -- --mode=stress --build=full`)
- [ ] Full-build stress test on the Android phone (needs the phone; see Found)

### Phase 2 results (2026-10-05, same desktop as phase 1, windowed, 20 s, ~295-300 enemies on screen)

| Build | Vsync | Avg fps | 1% low fps | Logic ms/frame |
| --- | --- | --- | --- | --- |
| Full (4 weapons L5, 4 tomes L5 incl. +5 projectiles, all 15 items stacked) | on | 75.0 (display cap) | 69.0 | 3.42 |
| Full | off | 318.9 | 135.8 | 1.52 |
| Starter (Baguette only) | off | 348-371 | 150 | 1.35-1.44 |
| Starter on `main` (phase 1 code), same day | off | 370-385 | - | 1.38-1.45 |

Phase 1's 652 fps uncapped isn't reproducible today even on `main`; the machine is slower this session. Same-day, phase 2 hooks cost about nothing on the starter build.

Bot sim, seed 2, paid chest every 45 s: survived 8:00, level 23, 4,897 kills, 512 gold.

## Found during phase 2

- [ ] Alarm Clock: "the next attack is a guaranteed crit" is read as the next weapon *hit*, not every hit of the next attack. For the Baguette swing (AoE) the other reading would crit the whole swing. Unused charges don't pile up (capped at one refill).
- [ ] Fireworks: every other rocket lands on a random enemy on screen, the rest on a random spot. Pure random spots almost never hit at the start of a run. Revert in `rockets.gd` if the brief means pure random.
- [ ] "Legendaries are unique, one per run" is read as at most one legendary per run in total (`legendary_per_run` in `data/rules/loot.json`). With one legendary in the MVP both readings behave the same.
- [ ] Copy Machine Manual: +1 projectile per level (+5 at level 5), the strongest tome on paper. Watch in phase 8.
- [ ] Whoopee Cushion fires from `on_damaged`, which only contact damage emits so far. Phase 3 enemy shots and Bloater explosions must go through the same damage path (`_contact_damage` -> shared function) or it won't trigger.
- [ ] Turbo Pigeon and Gary don't exist in `data/characters/` yet; their signature weapons (`sharp_feathers`, `stapler`) name characters `turbo_pigeon` and `gary`. Phase 4 must use these ids.
- [ ] No chest entities yet: `Run.open_chest(kind)` rolls and gives the item; phase 3 chests, elites and the boss call it. `--chests=S` on the sim opens one every S seconds meanwhile.
- [ ] Elites don't exist yet; `EnemySystem.elite` is the flag Golden Toilet and `on_kill` read. Phase 3 sets it.
- [ ] In-run gold: enemies drop 1 gold at 8% (added directly, no pickup). Paid chests and the merchant spend it in phase 3.
- [ ] The pixel font has no `$`, `&` or accents: gold shows as "G 12", Piñata is "PINATA" in game text.
- [ ] `tools/run_tests.sh` now runs `--import` first (new `class_name` scripts weren't seen by `-s` runs) and has a timeout (a compile error used to hang it).
- [ ] Fireworks blast rings use `draw_arc` (1px, not antialiased); check they read as pixel art in phase 7.
- [ ] All weapon, tome and item numbers are first guesses; phase 8 tunes them.

## Found during phase 0

- [ ] JSON stores all numbers as floats. `Save._merge_defaults` restores ints only where a default exists; phase 4 stat/unlock dictionaries need their own int casting.
- [x] Integer scale confirmed on a 1280x2772 phone: 7x (1260x2240). Letterbox bars are pure black (0,0,0), 266 px top and bottom, 10 px sides.
- [ ] `tools/gen_placeholder_assets.py` overwrites the palette, font and icon; once the final Lospec palette is picked, update `PALETTE` and the `Palette` index constants together.

## Found during phase 1

- [ ] Godot 4.7 has a native `VirtualJoystick` class; ours is `ThumbStick` (drawn in palette pixels, built from scratch per the brief).
- [ ] MultiMesh gotcha: set `visible_instance_count` before `buffer`, or the batch gets culled with stale bounds. `SpriteBatch` also sets a fixed huge `custom_aabb`.
- [ ] CPUParticles2D death puffs are not snapped to the pixel grid and don't dither-fade yet (phase 7 VFX rules).
- [ ] Damage numbers pile up into a white blob at 300 enemies; consider merging numbers per enemy or a lower cap (phase 7).
- [ ] Six start tomes exist as data already (Muscle Magazine, Speed Reading, Think Big, Grandma's Soup Recipes, Power Nap Guide, Cardio Is Life) so cards had content. Phase 2 should review them, not write duplicates.
- [ ] All numbers (spawn rates, Baguette levels, XP curve, coins) are first guesses; tune in phase 8. The bot is simple and is not balance truth.
- [ ] Desktop logic time is higher with vsync on (2.4 ms) than uncapped (1.2 ms), most likely CPU clock scaling at low load. Measure logic ms on the phone, where it matters.
- [ ] Enemy separation only checks the 3x3 neighbouring 16px cells, so two enemies whose radii add up to more than 16px (elites, Mega Mole) won't push apart fully. Hit queries already handle big radii. Phase 3: grow the cell or separate big enemies separately.
- [ ] Spawner works on the "spawns" list only; phase 3 replaces it with the full spawn director (roles, SWARM INCOMING, elites).
- [ ] Phone stress run: "uncapped" mode had no effect on Android (vsync stays on, the app runs at 60 Hz even on a 120 Hz screen). Real headroom on device is unknown; logic ms is the number to watch.
- [ ] Phone 1% lows are ~50 fps (p99 frame ~20 ms) while the average is a flat 60. Find the spikes before phase 7 adds effects (suspects: gem merge scans all 400 gems per kill when the pool is full, damage-number text redraw, particle restarts).
- [x] Tall phones got ~19% of the screen as black bars. Decided (owner, 2026-10-05): stretch aspect "expand", 180x320 is the minimum view. On the Xiaomi 15T the game now fills the full height at 7x; only the 10 px side bars (1280 is not a multiple of 7) and a thin strip at the top edge (likely the camera cutout, not confirmed) stay black. Menu and run panels are centered, HUD spans the width, spawns use the real view size. Brief and CLAUDE.md updated. Phone stress after the change: 60.1 avg / 50.9 1% low / 3.71 ms logic.
- [ ] Xiaomi blocks adb input injection, so runs on the phone can't be driven from adb; play-testing the joystick on device needs a person.
- [ ] No low-end Android device available yet for the brief's "low-end phones" target.

