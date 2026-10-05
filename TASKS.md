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
- [ ] Tall phones get ~19% of the screen as black bars at 180x320. Decide: keep bars, fill them with a palette pattern, or use stretch aspect "expand" to show more map vertically (still integer scale). This is a design choice for the owner.
- [ ] Xiaomi blocks adb input injection, so runs on the phone can't be driven from adb; play-testing the joystick on device needs a person.
- [ ] No low-end Android device available yet for the brief's "low-end phones" target.

