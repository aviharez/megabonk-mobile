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

## Phase 3: Map, enemies, and run flow

- [x] Suburbia as data: bounded 720x880 map (slightly tall), roads, houses with gardens, fences, hedges, trees, a pond (`data/maps/suburbia.json` "props"); solid props block the player and walking enemies (`MapLayout`, 8px solid-cell grid, slide along walls); fliers (Gnats) and ghosts (Overdue Bills) pass over
- [x] Data-driven spawn director (`Director`): schedule, SWARM INCOMING waves, elites every 60-90 s, Final Swarm with its own schedule and endless escalation, Overdue Bills; all numbers in the map file, except Overdue Bills, which are the same on every map (`data/rules/bills.json`; a map turns them on with `"bills": true`)
- [x] 6 enemy roles in code + data: chaser (Blob), pack (Skitter), shooter (Spitter), exploder (Bloater, red warning zone), charger (Chomper, red aim line), swarm (Gnat, only in SWARM INCOMING); plus ghost (Overdue Bills) and boss
- [x] Elites with 4 traits as data (`data/rules/elites.json`: Fast, Shielded, Splitting, Vicious): bigger (2x), glowing outline in the trait color (shader), drop an elite chest, can drop the cage key; set `EnemySystem.elite` so Golden Toilet and on_kill work
- [x] SWARM INCOMING: warning banner, 20-30 s surge, `swarm_survived_no_damage` stat event
- [x] Every interactable as data (`data/interactables/`): paid chest (in-run gold, price rises), elite chest, boss chest, charge shrine (pick 1 of 3 stats), risk/reward shrine, challenge shrine (kill 50 in 30 s), pot (gold), merchant (sells items for gold, comes and goes), pigeon cage + key, boss altar, portal
- [x] Chests, elites and the boss open through `Run.open_chest(kind)`; paid chests and the merchant spend in-run gold; pots drop gold
- [x] Indicator arrows at the screen edge (chests, shrines, altar, cage, key, merchant, portal, elites, boss); the altar arrow pulses with a hint on the first run at minute 5
- [x] Mega Mole: summoned by standing 2.5 s in the altar circle; burrow with a visible shadow and a red pop-up zone, rock rings with a gap, Blob summons, faster below 50% HP; boss HP bar; defeat drops a boss chest and opens the portal
- [x] Portal ends the run ("ESCAPED!"); Final Swarm at 8:00 (banner, HUD timer counts up, coin multiplier rises); Overdue Bills 2 min later: invulnerable, pass through everything, ignore knockback, armor and shield, faster and harder every minute, so the Final Swarm always ends
- [x] One damage path: `Run.damage_player()` for contact, Spitter shots, Bloater explosions, Mega Mole, Overdue Bills; fires on_damaged (Whoopee Cushion)
- [x] Pigeon cage: elite key (chance, guaranteed after 3 elites), opening records `pigeon_cage_opened` (Turbo Pigeon himself in phase 4)
- [x] Big enemies: second separation pass with wide queries for enemies bigger than half a grid cell; bigger pushes smaller, the boss doesn't move
- [x] Run facts recorded for phase 4 (`Run.record` / `stat_event`, `result.stats`): pots, shrines, elites, boss (time, HP, in Final Swarm), cage, chests, swarms, Final Swarm seconds...
- [x] Data validation for roles, interactables, elites, bills, boss patterns, sheets + sidecars and map references (schedules, swarms, props and their colors); `tests/test_data.gd` has a failing-data case for each of the 16 holes the review found
- [x] Sprite pipeline: `tools/creature_export/` (C# console, compiles the generator's Core by path) + `tools/palette_snap.py` (CIELAB snap, binary alpha, no reserved magenta, repacks to a 1px-padded strip + sidecar JSON, self-check); 12 candidates in `build/creature_candidates/`
- [x] Import the approved sheets into `assets/creatures/` (owner picks 2026-10-05: blob_ooze_s114, skitter_spider_s28, chomper_beast_s5); sidecar JSONs added to the Android export filter; radii 5/4/6 to fit the bigger sprites
- [x] Suburbia redesign (owner: "the current map design is so bad"): Main St / Oak Ave crossing with sidewalks and crosswalks, Elm Lane, Maple Court cul-de-sac, house rows facing their streets (yards, walkways, mailboxes, driveways, cars, fenced backyards with sheds and pools), Duckling Park (pond with ring path, playground, benches), sports field (altar fixed there), community garden + greenhouse; the cage sits in an SE backyard. Map baked into one texture at load. `tools/render_map.gd` renders a whole map (`--solid` shows blocked cells)
- [x] Bot routes to goals with a breadth-first field over the cells the player's whole box fits in (boss sims: all 3 seeds beat Mega Mole and take the portal at 1:25, 1:38 and 1:42)
- [x] SpriteBatch plays animated sheets: frame, mirror, outline and flash per instance in the custom data, whole-number scale in the transform
- [x] 1% low spikes: profiled per frame section (`--profile`); the slow frames are kill-heavy frames, and with a full gem pool every kill scanned all 400 gems to merge. Gem merges now look up a nearby gem by cell (3.0 us instead of 11.7 us per kill on desktop, about 4x). New `missed_vsync_frames` metric: on desktop the "1% low" at vsync is timing jitter, 0 of 2251 frames missed a vsync (see results). Phone not re-measured (not connected)
- [x] Android stress at Final Swarm density with a full build on the Xiaomi 15T (2026-10-06): 60.1 fps average, 0 and 1 missed vsyncs in 1,801 frames, logic ~7 ms (see results); playable debug build installed
- [x] Tests: `tests/test_director.gd` (the run timeline table, swarms, elites, Final Swarm, bills), `tests/test_map_flow.gd` (map, roles, traits, every interactable, key + cage, boss + portal, every damage source through on_damaged, bills ignore armor/shield, Final Swarm always ends through bills, swarm stat event, first-run hint, arrows, big-enemy separation), `tests/test_sprite_sheets.gd`, plus a regression test per review fix (each one checked to fail with its fix undone); 626 checks pass, flow check OK
- [x] Bot sims (8+ min, starter build, seeds 1-8) and boss sims (`--boss=1 --portal --build=full`, seeds 1-3): see results
- [x] Review (2026-10-06, three reviewers + verification), all fixed with a regression test each:
  - Blockers: the run could end twice in one frame (die on the portal: two saves); a shop/shrine menu stayed live under the game-over screen; a reused enemy slot could be told to explode; crowds pushed walkers into houses; the altar and most shrines had no arrow (only the 6 nearest objects, counted before dropping on-screen ones); data that passed validation crashed mid-run
  - Should-fix: the altar was used up when the boss couldn't spawn; bills that couldn't spawn were still counted; a second risk shrine left the first one's effects on; an exploding elite dropped nothing and didn't split; walkers wedged in corners (side flip after 0.6 s, off-screen recycling after 3 s); role numbers read from dictionaries every frame (now cached per type); sheet sidecars not validated; `--only` with no match passed; stale TASKS claims
  - Brief: the merchant re-checks the one-legendary rule at purchase; bills moved to shared rules; Splitting works on exploding elites
  - Also: the Bloater placeholder had one 12-wide row; contact damage could come from an enemy killed earlier in the same frame; `Palette.color()` with a bad index no longer returns the reserved magenta; a walker pausing on purpose no longer resets its stall timer

### Phase 3 results (same desktop, windowed, 30 s; first table 2026-10-05, second after the review fixes 2026-10-06)

| Stress | Vsync | Avg fps | 1% low fps | Missed vsync | Logic ms/frame | On screen |
| --- | --- | --- | --- | --- | --- | --- |
| Final Swarm density (2:30 in, all roles, elites, 35 bills, ~50 enemy shots), full build | on (75 Hz) | 75.0 (cap) | 68.6 | 0 | 4.14 | 315 + bills |
| 300 enemies (all roles), full build | off | 311.8 | 218.2 | 0 | 2.12 | 299 |
| 300 enemies (all roles), starter | off | 255.3 | 169.0 | 0 | 1.96 | 300 |

Logic per frame with the full build went from 1.52 ms (phase 2) to 2.12 ms uncapped: the new roles and wall sliding.

After the review fixes, real sprites and the redesigned map (2026-10-06):

| Stress | Vsync | Avg fps | 1% low fps | Missed vsync | Logic ms/frame | On screen |
| --- | --- | --- | --- | --- | --- | --- |
| Final Swarm density, full build | off | 282.7 | 154.2 | 0 | 2.42 | 318 incl. 35 bills |
| 300 enemies, full build | off | 293.8 | 165.4 | 0 | 2.35 | 299 |

The enemy update costs 1.46 ms instead of 1.18 ms: walls are now checked when separation pushes walkers (only for enemies within 2 cells of a solid cell) and stalls are tracked.

| Phone: Xiaomi 15T, Android Stress preset (Final Swarm density, full build), vsync, 60 Hz | Avg fps | 1% low fps | Missed vsync | Logic ms avg / p99 / max | On screen |
| --- | --- | --- | --- | --- | --- |
| Run 1, 30 s | 60.1 | 50.4 | 0 of 1,801 | 7.02 / 9.78 / 12.24 | 315 incl. 35 bills |
| Run 2, 30 s (the "uncapped" half; vsync stays on on Android) | 60.1 | 50.5 | 1 of 1,801 | 6.88 / 9.38 / 21.62 | 337 incl. 40 bills |

The phone's ~50 fps "1% low" is frame-timing jitter, not dropped frames (0-1 missed vsyncs). Logic is ~7 ms at Final Swarm density, 2.9x the desktop; a phone 2-3x slower than the 15T would miss frames here.

Bot sims on the redesigned map, after the review fixes (deterministic per seed, starter content, 8 seeds): deaths at 2:02, 3:42, 5:02, 5:11, 7:43, 9:35, 9:43, and one run ended by Overdue Bills at 10:24. Boss sims with a full build: all 3 seeds summon Mega Mole, beat it and take the portal (1:25, 1:38, 1:42).

## Phase 4: Meta progression and characters

- [x] Stat tracker: every run fact is summed per run (`Run.record`, plus kills and shots per weapon `kills.<weapon>` / `shots.<weapon>`, gems collected, level, runs finished) and committed at the end into save `stats` totals, plain and per character (`kills@sir_loaf`, `shots.stapler@gary`); one-per-run values (level, boss time, boss HP, Final Swarm seconds, item copies) are kept as best runs, never summed (`Meta.commit_run`)
- [x] 19 unlock challenges as data (`data/challenges/`): stat, weapon/character filter, scope (run/total), target, goal (at_least/at_most), prerequisite, reward, price, tier; all 19 checked against the brief table in `tests/test_meta.gd`
- [x] Two-step unlock: challenge done -> "available" (NEW badge, menu notification dot) -> bought with coins -> "owned"; a completed challenge never expires; prerequisites (Gary, Faulty Toaster) block completion until owned
- [x] Only owned content in the pool and on the hero select (`ContentPool.from_save`); buying a character puts his signature weapon in the pool for every character
- [x] Coin shop as data (`data/shop/`): Reroll, Skip (+8 gold), Banish (after 3 runs), Toggler (after 12 bought unlocks; 4/8 things off), permanent stat upgrades (Might, Vitality, Sneakers, Magnetism, Greed; 5 levels, max +15% damage)
- [x] Level-up actions: pixel icon buttons under the cards with charges left; Banish = tap the X, then a new weapon/tome card (replaced, gone for the run); out of charges shows an AD tag (disabled until phase 5)
- [x] Toggler screen (from the hero select): owned weapons, tomes and items on/off; off content never on cards or in chests
- [x] Game-over screen: result, the 3 closest unlocks with progress bars, and what's ready to buy (NEW for this run's)
- [x] Menu: UNLOCKS (silhouettes with challenge + progress, prices, BUY), SHOP, PICK A HERO (when there's a choice), notification dot; Android back closes the top screen
- [x] Turbo Pigeon (Tailwind: +1% damage per point of move speed above 40) and Gary the Intern (Overtime: from 5:00 every minute adds +6% damage, +5% max HP, +3% speed, +4% area, -3% cooldown, crit chance and damage, pickup, regen, armor, evasion, shield, XP, gold, luck; 6 steps max; every player stat but extra projectiles) with their signature weapons
- [x] Persistence through the phase 0 save: new keys with defaults only (`challenges`, `seen`, `toggled_off`, `character`), so no version bump; a phase 0-3 save loads unchanged (tested); purchases and run results are written at once
- [x] Data validation for challenges, shop entries, character status and passives, links (every unlock content has exactly one challenge, rewards are unlock content, filters/prerequisites exist, one shop entry per action) and content ids unique across folders; a failing-data case for each (`tests/test_data.gd`)
- [x] Tests: `tests/test_challenges.gd` triggers every challenge in a real run (pots, shrines, elites, cage key, boss at the altar, swarm unhurt, real weapon kills, staples as Gary...) and checks it becomes available; drivers are per stat, so a new challenge on a known stat is covered without new test code (checked to fail with best-run tracking broken). `tests/test_meta.gd`: brief table, prices, two-step unlock, pool, character purchase, save on disk after "closing the app", old saves, tracker keys, at-most goals, closest/ready lists, shop rules, Reroll/Skip/Banish, Toggler, passives. 857 checks pass
- [x] Flow check extended: game over shows the closest unlocks; UNLOCKS and SHOP open and close; with Turbo Pigeon owned, PLAY opens the hero select and his run starts with Sharp Feathers
- [x] Tests and bots no longer read the player's real save: without `options.save` and with `no_save` a run uses a blank save (`bot_run --character=ID` for other heroes)
- [x] Prices from bot sims (see results): Early 50, Mid 150, Hard 300, characters 1.5x (Turbo Pigeon 225, Gary 450)
- [x] 300-enemy stress after the changes (results below)

### Phase 4 review fixes (2026-10-08)

- [x] Progress made before a prerequisite was owned counted once it was bought (an Epic from a paid chest with Angry Neighbor owned first completed Lottery Tips on the next empty run). Runs now only count for a challenge while its prerequisite is owned; a "total" challenge with "requires" keeps its own count in save "challenges" (`Meta.own_counter`). Tests: `test_progress_before_the_prerequisite_does_not_count`, `test_prerequisite_blocks_completion` (both checked to fail with the fix undone)
- [x] Overtime raised 9 stats, the brief says "all stats": added crit damage, evasion, shield, XP, gold and luck; a test checks every player stat but projectiles is covered
- [x] No character id in code: the menu, the run and the hero select use `Meta.picked_character` (last pick if owned, else the first owned, start characters first); the save default for "character" is now ""
- [x] Tests: 882 checks pass, flow check OK

### Phase 4 results (2026-10-06, same desktop, windowed, 30 s)

| Stress | Vsync | Avg fps | 1% low fps | Missed vsync | Logic ms/frame | On screen |
| --- | --- | --- | --- | --- | --- | --- |
| 300 enemies, full build | on (75 Hz) | 75.0 (cap) | 67.1 | 0 | 3.97 | 295 |
| 300 enemies, full build | off | 330.8 | 242.0 | 0 | 2.15 | 299 |
| 300 enemies, starter | off | 268.6 | 187.5 | 0 | 1.97 | 300 |
| Final Swarm density, full build | off | 315.3 | 229.6 | 0 | 2.23 | 318 incl. 35 bills |

Same or better than phase 3 (293.8 / 165.4 / 2.35 ms for the full build): the per-kill tracker keys cost nothing measurable. Phone not re-measured (not connected).

Coins per run, bot sims (starter, seeds 1-8): 34, 8, 4, 655 (reached the Final Swarm, ended by bills at 11:05), 26, 18, 48, 16. Median 22; an 8-minute run earns ~110 before the Final Swarm multiplier. Prices use 50 coins as "an average run" (Early ~1 run, Mid ~3, Hard ~6).

## Phase 5: Monetization

Plugins (owner approved 2026-10-08): Poing AdMob 5.1.0 and GodotGooglePlayBilling 3.3.0, vendored in `addons/`; see docs/PLUGINS.md. All ad ids are Google's public test ids; the IAP product id is a placeholder.

- [x] Plugins researched (activity, Godot 4.7 support, license), owner picked, installed trimmed (no samples, C#, AI skills, mediation adapters); headless auto-download disabled; `project.godot` lists all `[admob]` settings so the plugin never rewrites it
- [x] `Ads` autoload over an `AdBackend` (AdMob on device, `FakeAdBackend` on desktop/tests); `Store` autoload over a `StoreBackend` (Play Billing on Android, `FakeStoreBackend` elsewhere). Plugin classes only load on a device
- [x] Numbers and ids as data: `data/rules/ads.json` (test units, limits, revive, daily coins, interstitial pacing, banner screens, timeouts), `data/rules/store.json` (Remove Ads); validated, with a failing case each (`tests/test_data.gd`)
- [x] Rewarded: revive on death (1/run; not vs Overdue Bills; 50% HP, 2.5 s i-frames, nearby enemies pushed out, shots cleared), 2x coins on game over above the unlock progress (1/run), Reroll/Skip/Banish when out of charges (1 per action per run; also for players who never bought Skip/Banish), daily reward on the menu (+25 coins, 1/day, local date, in the save)
- [x] Rewarded buttons show only when an ad is loaded and the limit allows; reward granted only after the SDK reward callback (also when it comes just after the close); a failed or skipped ad costs nothing
- [x] Interstitial only at game over -> menu: every 2-3 runs (gap drawn each time), never in the first 24 h after first launch, skipped after any rewarded ad since the last break, never with Remove Ads; a failed one still reaches the menu and doesn't reset the gap
- [x] Banner on menu, shop and unlocks only (hero select, Toggler, settings, runs: none); the menu shrinks by the banner height so nothing sits under it
- [x] Pause: tree paused and master bus muted while a full-screen ad is up, restored to the previous state on close, show failure or watchdog timeout (SDK never answers); an ad that shows after the watchdog pauses again
- [x] Remove Ads in the shop (store price as "USD 1.99": the pixel font has no currency symbols): removes banners at once and interstitials, rewarded stay; pending payments wait; restore on new install; the store's full list drops a refund; acknowledged per Play rules
- [x] Tests: `tests/test_ads.gd` (135 checks: every outcome x every placement rule, pause restore, pacing, banner, Remove Ads, in-run revive / actions / 2x coins); mutation-checked: granting on tap, no pause restore, no per-run limit, interstitial after rewarded, banner kept with Remove Ads each fail it
- [x] Flow check: banner on the menu and not in the run, daily reward, revive, 2x coins, interstitial skipped after rewarded / shown otherwise, Remove Ads from the shop
- [x] Export presets on Gradle build (required by the AdMob plugin), Godot 4.7.2 build template in `android/build/`, editor-only plugin files excluded from the APK
- [x] Debug APK builds with both plugins (Gradle, 45 s): both plugins' classes in the dex, manifest has the test AdMob app id, INTERNET and BILLING; minSdk 24, targetSdk 36
- [x] First run on the phone (2026-10-08) found two bugs desktop tests couldn't:
  - the export excluded `addons/admob/internal/*`, but AdRequest/MobileAds preload `internal/version/plugin_version.gd`, so no AdMob class compiled. Exclusion narrowed to the editor-only folders; new `tests/test_export_filters.gd` fails if any exported script loads an excluded file (checked against the old filter)
  - loading an ad before `MobileAds.initialize` finished crashed the app (Next-Gen SDK throws). `admob_backend.gd` now queues loads and the banner until the init callback
- [x] On the phone, no fill: init OK, every load fails cleanly with backoff retries, no rewarded buttons and no banner gap on the menu, no crash
- [x] Review fixes (2026-10-09):
  - a failed AdMob banner load left a dead AdView that `banner_load()` reused, so the banner never came back that session. `admob_backend.gd` now destroys it; `Ads` resets the banner backoff on a load. Tests drive the real `admob_backend.gd` against a stand-in AdView plugin (failed before the fix)
  - the fake ad and store backends were picked whenever the native plugin was missing, so a release build without it (any iOS build) sold Remove Ads for free. Fakes are now debug-build only; release builds without the plugin get inert backends (no ads, STORE OFFLINE). Tested
- [x] (owner, 2026-10-09) No revive offer when Overdue Bills end the run; brief table updated
- [ ] Test ads on the phone: rewarded (all placements), interstitial, banner; pause/resume when an ad fails (airplane mode) and when closed early (needs the phone)
- [x] Consent (UMP / GDPR) moved to phase 9 (owner, 2026-10-09)
- [x] iOS store (StoreKit plugin) moved to phase 9 (owner, 2026-10-09); until then iOS release builds show STORE OFFLINE
- [ ] Remove Ads on a device (needs a Play Console product + license tester; see Blocked)
- [x] 300-enemy stress after the changes (results below)
- [x] Screens checked in a window (menu + banner + daily, desktop test ad, shop with NO ADS, revive offer, game over with 2X COINS): palette only, pixel font, boxed AD tag like the level-up buttons
- [x] Tests: 1048 checks pass (`tools/run_tests.sh`), flow check OK (after the review fixes)

### Phase 5 results (2026-10-08, same desktop, windowed, 30 s, full build)

| Stress | Vsync | Avg fps | 1% low fps | Missed vsync | Logic ms/frame | On screen |
| --- | --- | --- | --- | --- | --- | --- |
| 300 enemies, full build | on (75 Hz) | 75.0 (cap) | 66.8 | 0 | 4.76 | 295 |
| 300 enemies, full build | off | 323.6 | 232.7 | 0 | 2.17 | 299 |

Same as phase 4 (330.8 / 242.0 / 2.15 ms uncapped): the Ads and Store autoloads cost nothing in a run. Phone not measured (not connected).

## Found during phase 4

- [x] (owner, 2026-10-08: `"requires": "golden_toilet"` added, brief table updated) Lottery Tips ("Epic from a paid chest", Mid) can't be done before an Epic item is owned: all three Epics (Golden Toilet, Clone Machine, Angry Neighbor) are unlock content, and chests only roll what's in the pool. The earliest route is Golden Toilet (Mid). The brief lists no prerequisite; options: add `"requires": "golden_toilet"` so the screens say so, make one Epic start content, or accept the hidden order. Owner decision.
- [ ] "10 elites in one run" (Mid): elites come every 60-90 s, so ~6 by 8:00; it needs Final Swarm time. Best bot run had 8 in 11 min. Watch in phase 8.
- [ ] Coin income swings hugely with the Final Swarm multiplier (one sim earned 655, the others 4-48). Phase 8 should tune coins per minute/kill and the multiplier together with prices.
- [ ] "Finish 3 runs" counts runs that end by death, bills or the portal, not GIVE UP (so it can't be farmed by quitting at 0:01).
- [ ] "Collect 3,000 XP gems" counts dropped gems picked up; a merged gem counts as all the gems in it. Gems left on the ground at the end don't count. One bot run collects 90-6,200.
- [ ] A run only reaches the save when it ends. Closing the app mid-run loses that run's progress (the save on disk stays intact). Committing on app pause would double-count runs that are resumed.
- [ ] Out of charges, Reroll/Skip/Banish show an AD tag but stay disabled (`Run.ad_ready`). Phase 5: rewarded ad per action per run, and "try Skip/Banish once per run through an ad" without buying them.
- [ ] Banish works on new weapon/tome cards only (upgrades and SNACK can't be banished).
- [ ] "After 12 unlocks" for the Toggler is read as 12 bought unlocks.
- [ ] Content icons on the unlocks screen are code-drawn placeholders (silhouette = INK glyph on SHADE); real icons in phase 6. Prices show as "C 50" (the pixel font has no coin glyph).
- [ ] The pigeon cage still appears (and can be opened) after Turbo Pigeon is unlocked; it just records the stat again.
- [ ] Shortened texts to fit the pixel font on one line: Sir Loaf's passive is now "LESS DAMAGE TAKEN OVER TIME", challenge texts are 26 characters max (`tests/test_meta.gd` checks).
- [ ] Character numbers are first guesses: Turbo Pigeon 85 HP / speed 64 (+24% damage at base speed), Gary 100 HP / damage 0.9 before Overtime.
- [ ] A save that already had Copy Machine Manual or Static Sweater progress from after its prerequisite was owned starts those two (and Lottery Tips) from 0 after the review fix: the old shared totals can't tell before from after. Only test saves exist so far.
- [ ] Phone stress not re-run for phase 4 (phone not connected); desktop shows no change in the hot loop.

## Found during phase 3

- [ ] Map opened up (2026-10-06, owner request): house gaps widened to 30-32 px (were 14-28; houses narrowed, walkways and mailboxes re-centered), the 6 driveway cars removed, sheds and backyard pools walk-through, the 11 backyard hedge strips removed (park hedges kept). New test: every open spot the player fits is reachable from the start.
  - Found while testing it: walkers blocked sideways by a wall slid the "preferred" way instead of the way they were heading, so many oscillated behind houses forever (and the stall timer never caught them). Fixed: they keep their own direction along the wall; stalls are now measured as net progress per second.
  - Bot survival went down, not up (8 seeds, median 2:49; empty map 9:45): with that fix, enemies get round houses instead of piling up behind them, so more of the horde reaches the player. Deaths are now mostly at map corners/edges (3 of 8) and beside the pond (2 of 8), not between houses; without the pond the median is 4:48. The bot's local dodging handles corners badly, so these numbers are a weak signal. Judge the map from real play; possible next steps: keep the horde from cornering the player at the map edge (spawn side choice), phase 8 tuning.
  - Pond shrunk from 164x122 to 110x76 (owner request), with a tighter ring path and longer connecting paths. Bot median 3:18 (8 seeds: 1:09-11:05), up from 2:49; within the noise.

- [ ] Low-end headroom: game logic takes ~7 ms per frame on the Xiaomi 15T at Final Swarm density with a full build (enemy update is the largest part). A phone 2-3x slower would drop below 60 fps there. Still no low-end device to measure; options if needed: lower the Final Swarm cap, update far-off-screen enemies every other frame, or move hot loops to a GDExtension (asks first).

- [ ] New map vs bot survival (seeded sims are now repeatable; 8 seeds, starter build, median death time): full first redesign 3:15, no solid props 7:18. Clutter cost the most (houses-only variant 6:07). Changed: trees block only their trunk cell, bushes and street furniture are walk-through, backyard side fences removed, long hedges split. That gave 4:33 (worst seed 2:54 instead of 1:14); after the review fixes (walkers no longer pushed into walls, wedged ones recycled) the median is 6:27 (worst 2:02). The rest comes from houses, sheds, pools, the pond and hedges; tune in phase 8 with real play, not only the bot.
- [x] Sims are deterministic per seed: enemy wobble and first-shot timers use `EnemySystem.rng`, seeded from the run seed. Bot avoids walking into walls (`_bot_walkable`); `--map=ID` and `death_pos` in the sim result.
- [ ] `data/maps/suburbia.json` was written by a one-off script (one prop per line); edit the JSON directly from now on.

- [ ] Creature candidates are bigger than the brief's 16-24 px: Blob 16-20x15-16, Skitter 18-21x15, Chomper 25-28x17-20 (the generator's smallest body is ~10 px long, plus legs). Collision radii are 5/4/6 px (Blob, Skitter, Chomper); the owner approved the sizes. Options if too big: accept, crop legs, or draw them at a smaller scale.
- [ ] Generated walk loops are short: 4 frames (spider, boar) or 5 (slime) at 12 fps.
- [ ] Gnats "in huge numbers" share the 300 cap: during a swarm the regular schedule drops to 40% ("regular_mult") so Gnats get the room. Not a conflict with the performance limit, so not raised.
- [ ] Overdue Bills ignore armor and shield (evasion still works, capped at 60%) and hit for 15% of max HP, +100% per minute. Without that, enough armor or a refilling shield made them harmless and the Final Swarm could last forever.
- [ ] Taking the portal before 8:00 ends the run early (fewer minutes, fewer coins). The brief only says beating the boss opens it; read as the player's choice.
- [ ] Dying in the Final Swarm counts as a survived run (no death coin penalty) and gets the Final Swarm coin multiplier; dying before 8:00 keeps the 0.6 penalty. Titles: ESCAPED!, OVERDUE! (bills), SWARMED! (other death after 8:00), TOASTED!, GAVE UP.
- [ ] Elites at first-guess numbers were too strong at minute 1 (Fast Skitter at 1.7x outran the player and 14x HP stuck to him); now HP x10, damage x1.2, Fast x1.35, Vicious x1.5. Phase 8 tunes.
- [ ] The starter bot can't beat Mega Mole at minute 3 (it now routes round houses, so it reaches the altar). Phase 8 needs a better fighting bot to check "beats Mega Mole on run 2 or 3".
- [ ] Map objects that appear under the player (reward chests, the portal) need a fresh step in, so the portal can't end a run by accident.
- [ ] Charge shrine bonuses, risk shrine and challenge numbers, merchant prices, paid chest price growth (x1.4) and pot gold are first guesses.
- [ ] The Final Swarm "screen tint shift" (brief VFX table) is phase 7; the HUD shows a banner, a pink overtime timer and the coin multiplier for now.
- [ ] Stat events recorded for phase 4: pots_broken, shrines_activated, elites_killed, keys_found, pigeon_cage_opened, boss_summoned, boss_defeated (+ boss_defeated_at, boss_defeated_hp_frac, boss_defeated_in_final_swarm), chests_opened, epic_from_paid_chest, items_bought, challenges_won, swarms_started, swarm_survived_no_damage, final_swarm_reached, final_swarm_seconds, damage_taken, max_item_copies. Kills by weapon and per character still come from on_kill.
- [ ] `tests/run_tests.gd` takes `-- --only=<file prefix>` (fails if it matches nothing) and reports a test file that doesn't compile as a failure instead of hanging.
- [ ] `SpriteBatch` centers each frame on the enemy position and ignores the sidecar "origin" (the feet). Cosmetic; revisit in phase 6 if sprites look like they float.
- [ ] Measuring with a shell loop over "$args" in zsh passes all flags as one argument (no word splitting); call bot_run with separate arguments.

## Found during phase 2

- [ ] Alarm Clock: "the next attack is a guaranteed crit" is read as the next weapon *hit*, not every hit of the next attack. For the Baguette swing (AoE) the other reading would crit the whole swing. Unused charges don't pile up (capped at one refill).
- [ ] Fireworks: every other rocket lands on a random enemy on screen, the rest on a random spot. Pure random spots almost never hit at the start of a run. Revert in `rockets.gd` if the brief means pure random.
- [ ] "Legendaries are unique, one per run" is read as at most one legendary per run in total (`legendary_per_run` in `data/rules/loot.json`). With one legendary in the MVP both readings behave the same.
- [ ] Copy Machine Manual: +1 projectile per level (+5 at level 5), the strongest tome on paper. Watch in phase 8.
- [x] (phase 3: every damage source goes through `Run.damage_player()`) Whoopee Cushion fires from `on_damaged`, which only contact damage emits so far. Phase 3 enemy shots and Bloater explosions must go through the same damage path (`_contact_damage` -> shared function) or it won't trigger.
- [x] (phase 4: both added with these ids) Turbo Pigeon and Gary don't exist in `data/characters/` yet; their signature weapons (`sharp_feathers`, `stapler`) name characters `turbo_pigeon` and `gary`. Phase 4 must use these ids.
- [x] (phase 3) No chest entities yet: `Run.open_chest(kind)` rolls and gives the item; phase 3 chests, elites and the boss call it. `--chests=S` on the sim opens one every S seconds meanwhile.
- [x] (phase 3) Elites don't exist yet; `EnemySystem.elite` is the flag Golden Toilet and `on_kill` read. Phase 3 sets it.
- [x] (phase 3: paid chests and the merchant spend it, pots drop it) In-run gold: enemies drop 1 gold at 8% (added directly, no pickup). Paid chests and the merchant spend it in phase 3.
- [ ] The pixel font has no `$`, `&` or accents: gold shows as "G 12", Piñata is "PINATA" in game text.
- [ ] `tools/run_tests.sh` now runs `--import` first (new `class_name` scripts weren't seen by `-s` runs) and has a timeout (a compile error used to hang it).
- [ ] Fireworks blast rings use `draw_arc` (1px, not antialiased); check they read as pixel art in phase 7.
- [ ] All weapon, tome and item numbers are first guesses; phase 8 tunes them.

- [x] Set up procedural-pixel-creatures (MIT, C#/Godot 4.5.2 .NET) as a standalone asset tool outside the repo at ~/Documents/Playgrounds/tools/procedural-pixel-creatures (owner-approved 2026-10-05). Not embedded: the game stays GDScript. Launch with `./ppc.sh` (`--overview`, `--testarea`, `--editor`, `--check`); it pins Godot 4.5.2 .NET in ~/.local/opt and .NET SDK 8.0.425 in ~/.dotnet. 17/17 core and 28/28 Godot self-tests pass on Linux.
- [x] (phase 3: `tools/palette_snap.py`) Add a palette-snap script to tools/ that remaps sprite sheets exported from procedural-pixel-creatures to assets/palette.png before import. Its exports use their own colors, so they break the palette rule until remapped.

## Found during phase 0

- [x] (phase 4: `Meta` reads coins, shop levels and charges through `int()`; tested after a reload) JSON stores all numbers as floats. `Save._merge_defaults` restores ints only where a default exists; phase 4 stat/unlock dictionaries need their own int casting.
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
- [x] (phase 3: second pass for big enemies) Enemy separation only checks the 3x3 neighbouring 16px cells, so two enemies whose radii add up to more than 16px (elites, Mega Mole) won't push apart fully. Hit queries already handle big radii. Phase 3: grow the cell or separate big enemies separately.
- [x] (phase 3: `Director`) Spawner works on the "spawns" list only; phase 3 replaces it with the full spawn director (roles, SWARM INCOMING, elites).
- [ ] Phone stress run: "uncapped" mode had no effect on Android (vsync stays on, the app runs at 60 Hz even on a 120 Hz screen). Real headroom on device is unknown; logic ms is the number to watch.
- [x] (phase 3: gem merge fixed; desktop and phone both show the vsync "1% low" is timing jitter: the 15T missed 0-1 vsyncs in 1,801 frames at Final Swarm density) Phone 1% lows are ~50 fps (p99 frame ~20 ms) while the average is a flat 60. Find the spikes before phase 7 adds effects (suspects: gem merge scans all 400 gems per kill when the pool is full, damage-number text redraw, particle restarts).
- [x] Tall phones got ~19% of the screen as black bars. Decided (owner, 2026-10-05): stretch aspect "expand", 180x320 is the minimum view. On the Xiaomi 15T the game now fills the full height at 7x; only the 10 px side bars (1280 is not a multiple of 7) and a thin strip at the top edge (likely the camera cutout, not confirmed) stay black. Menu and run panels are centered, HUD spans the width, spawns use the real view size. Brief and CLAUDE.md updated. Phone stress after the change: 60.1 avg / 50.9 1% low / 3.71 ms logic.
- [ ] Xiaomi blocks adb input injection, so runs on the phone can't be driven from adb; play-testing the joystick on device needs a person.
- [ ] No low-end Android device available yet for the brief's "low-end phones" target.


## Phase 6: Assets

- [x] Sir Loaf base sprite from SpriteCook (2026-10-09: v1 rejected (bread type), v2 tin loaf approved, shrunk to 25x26 with the visor redrawn by hand; 24 credits)
- [x] Sir Loaf idle, walk, hit animations (all approved 2026-10-09; walk used unedited). Sheets in `assets/characters/` via `tools/spritecook_shrink.py` (one scale for every clip, visor redrawn per frame); `data/characters/sir_loaf.json` "sheets"; run draws hit > walk > idle, mirrored facing left; characters without sheets keep the code-drawn fallback
- [x] Test: `test_sprite_sheets.gd::test_character_sheets` (clips load for all three heroes, idle/walk/hit switching, fallback without sheets); 1080 checks pass
- [x] Turbo Pigeon: sprite + idle, walk, hit (approved 2026-10-09; Sir Loaf as style reference; 72 credits)
- [x] Heroes shrunk to ~22px tall on owner request (2026-10-09): both re-shrunk from the SpriteCook originals at scale 0.67 (was 0.788 / 0.8); no in-engine scaling, so the pixel grid stays clean. Rule for later characters: scale so the body is ~22px tall
- [x] Gary: sprite + idle, walk, hit (2026-10-09; Sir Loaf + Pigeon as style references, scale 0.67; 72 credits). Shrunk without palette dark red (it made his eye look bloody), stapler re-reddened by `tools/art/gary_stapler.py`; `tools/spritecook_shrink.py` gained `--exclude`
- [x] Mega Mole: sprite + walk, burrow, attack, hit (2026-10-09; 92 credits; full size 33px; walk added by owner). SpriteCook's burrow didn't dig, so the burrow is built from his walk frame (`tools/art/mole_burrow.py`). Clips merged into `assets/bosses/mega_mole.png` by `tools/sheet_clips.py`; `EnemySystem.play()` / `clip_of()` play named clips; the mole digs for `dig_time` 0.5 s (visible, hittable) before hiding, pops up with the burrow reversed, attacks on rocks and summons, flinches on hits at most every `hit_anim_gap` s. Test: `test_sprite_sheets.gd::test_boss_clips`; 1093 checks pass
- [ ] Weapon and item icons (one style-reference icon first)
  - [x] Baguette style-reference icon (2026-10-09; 12 credits; approved). Icons are 16x16, made by `tools/icon_shrink.py`, stored as `assets/icons/<kind>/<id>.png`
  - [x] Remaining 9 weapon + 15 item icons (2026-10-09; six 2x2 sheets, 72 credits, cut by `tools/icon_shrink.py --grid 2`; rebuild all with `tools/art/icons.sh RAW_DIR`)
  - [ ] Owner review of the 24 batch icons; weakest at 16px: Leaf Blower (small), Faulty Toaster, Golden Toilet
- [x] Book sprite + 16 tome icons in code (2026-10-09; 12 credits; `tools/art/book_template.py` -> `assets/icons/book.png`; per-tome cover colors + 5x5 symbol in `data/tomes/*.json` "icon", built by `scripts/ui/icons.gd`, validated by GameData)
- [x] Icons wired in: unlock rows (`ContentIcon`, now 18x18, INK silhouette when locked), level-up cards (icon above the text, `PixelButton.art` / `art_above`), toggler rows. Character unlock icons = head of the idle frame. Tests: `tests/test_icons.gd`, `test_data.gd::test_phase6_bad_tome_icons_are_caught`; 1571 checks pass, FLOW OK. Screens rendered by `tools/render_ui.gd`
- [ ] Suburbia tiles and props
  - Plan (owner-approved 2026-10-09): ground, roads, sidewalks, driveways, yards, gardens, pond, pool, hedges, fence, mailbox, lamp stay code-drawn (sizes vary per prop / too small for SpriteCook); SpriteCook for house, tree, bush, shed, car, bench, swing set
  - [x] House (2026-10-09; 24 credits: the isometric first try isn't used). 34x34 front-facing, `assets/props/house.png`; map JSON "prop_art" names the sprite and the roof ramp per prop color (`MapLayout._sprite_for`, validated by GameData); sprite shadow follows its outline; the 15 house rects shrunk to 30x26 (same bottom centre). Test: `test_icons.gd::test_map_house_sprite_and_roof_colors`
  - [ ] Sheets A (tree, bush, shed, car) and B (bench, swing set, second tree, one more)
- [ ] UI (CC0 pack or code), remapped to the palette
- [ ] Enemy sheets from assets/creatures/ for every role (elites = scaled + recolored)
- [ ] Placeholder inventory: list every code-drawn / placeholder asset and replace it
  - Found so far (grep of `scripts/`, 2026-10-09; not yet a full audit):
    - Enemies still on `PlaceholderArt` shapes: Bloater, Gnat, Spitter, Overdue Bill (`data/enemies/*.json` "shape"); need procedural-pixel-creatures exports from the owner
    - `scripts/core/placeholder_art.gd` shapes: gems (3), projectiles (dot, bullet, feather, staple, duck, cup, rocket, rock), chest, pot, shrine, cage, key, altar, portal, merchant, arrow
    - `scripts/ui/content_icon.gd`: placeholder glyphs now only for content without art (none at the moment)
    - `scripts/run/map_layout.gd`: the whole Suburbia map is drawn in code
    - `scripts/run/fx.gd`, weapon `draw()` code: VFX (phase 7 owns most of it)
    - UI drawing (`pixel_button.gd`, `pixel_panel.gd`, `hud.gd`, `thumb_stick.gd`, ...) not reviewed yet
    - `run.gd` `_draw_player` rectangles: kept on purpose as the fallback for a character without sheets
- [x] Hero select screen (`scripts/ui/hero_screen.gd`) and unlock icons: show the character sheets instead of placeholders (2026-10-09: cards 40px tall play the idle sheet via `scripts/ui/sheet_view.gd`)
- [ ] Palette + grid check passes on every asset; ASSET_LOG records credits

### Phase 6 results so far (2026-10-09, same desktop, windowed, vsync, starter build, Sir Loaf sprite)

| Stress test, 300 enemies, 20 s | Avg fps | 1% low fps | Logic ms/frame | Avg on screen |
| --- | --- | --- | --- | --- |
| Windowed, vsync on | 75.0 (display cap) | 66.6 | 2.98 | 299.3 |
| Same, Turbo Pigeon | 75.0 (display cap) | 66.2 | 3.26 | 299.6 |
| Same, Gary, heroes at ~22px | 75.0 (display cap) | 66.6 | 3.59 | 299.8 |

SpriteCook: 440 credits spent, 360 left.
