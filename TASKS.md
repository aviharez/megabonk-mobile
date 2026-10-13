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
- [x] ~~Coin income swings hugely with the Final Swarm multiplier~~ Tuned 2026-10-10 (phase 8 follow-up 5): 35-45 per early death, 137-225 in the Final Swarm.
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
  - [x] Sheets A (tree, bush, shed, car) and B (bench, swing set, pine, apple tree) (2026-10-09; 24 credits; owner approved). `tools/art/props.sh`; prop_art "variants" (GREEN tree = pine, RED tree = apple tree) and "colors" recolors (bush flowers, sheds, cars); shed rects 22x14, swing 26x10
  - [x] Owner: "the other things are bad" (code-drawn ground). Done 2026-10-09 (84 credits): SpriteCook textures (grass, asphalt, paving, sand, soil; `tools/art/textures.py`) filled by map "ground_textures"; prop sheet C (mailbox, lamp, hedge repeated along rows, planter = new walk-through kind, one by every other house); boss altar sprite (interactables "sprite"); 7 driveways that led nowhere removed, yard and pitch stripes dropped. Bake 16 -> 27 ms on desktop. Test: `test_icons.gd::test_map_ground_textures_and_altar_sprite`
  - [x] Owner follow-up (2026-10-09, no credits): grass toned down (`tools/art/textures.py`: flowers, LIME and lone GREEN tufts -> LEAF); view 180x320 -> 270x480 (reverted the same day: it shrank menus and HUD too); map 720x880 -> 1440x1760 built by `tools/maps/build_suburbia.py` from the block `tools/maps/suburbia_block.json` (4 copies, 2 mirrored, seam streets, re-rolled colors per copy, interactables x3, one altar and cage). Rect texture fills blit whole tiles (bake 110 -> 58 ms on desktop)
  - [x] Wider world only (owner, 2026-10-09): base back to 180x320, stretch mode canvas_items; the run draws its world in `Run.world_viewport` at world_scale = round(ui_scale / "world_view_scale") (1.5 first, owner chose 2.0: phone 1280x2772 UI 7x, world 4x; desktop 540x960 UI 3x, world 2x); HUD arrows use the zoom; despawn distance stays outside the view. Menus checked identical in look; test `test_map_flow.gd::test_world_view_is_wider_than_the_ui`
  - [x] Second hand-designed block (2026-10-09, no credits): `tools/maps/suburbia_block_b.json` (school sports ground with a running track around a pitch, playground and school garden; park with a paved public pool, tree-lined path and a small pond; parking lot; two short streets with 9 houses; main road off-centre at x 216). Map = A top-left + bottom-right, B top-right + bottom-left, none mirrored, so every vertical road meets the seam at a different x. Fields now draw after paths and sand (`MapLayout.GROUND`), so a pitch can sit inside a track. 1623 checks pass
  - [x] Pond and pool (2026-10-09; 12 credits; sheet `09762765`): `tools/art/water.py` cuts it. Pool = 9-slice template `assets/props/pool.png` (map prop_art "slice", `MapLayout._nine_slice`): ladder and sparkles once at any size. Pond stays code-drawn (sizes vary) but in the SpriteCook pond's layers, with its lily pads and reeds stamped on (prop_art "decor"; GameData checks both). Tests: `test_icons.gd::test_map_pool_slice_and_pond_decor`, 3 bad-data cases; 1635 checks pass. `tools/check_assets.py`: 64 assets, 0 failed
  - [ ] Owner review of the wider world view on the phone, the big map with block B, and the pond and pool
- [x] UI: two SpriteCook UI kits (owner choice over CC0 / code), on the palette; phone-checked 2026-10-09 (menus, hero/map select, HUD, joystick, hero HP bar, pause)
  - [x] Inventory + cost check (2026-10-09, no credits). All UI is code-drawn: `PixelButton` (notched 1px INK box, 2px hard shadow, 1px bevel, sinks when pressed; subclasses `ActionButton` 7x7 glyphs, `AdButton` "AD" tag), `PixelPanel` (same box, every overlay and list row), `ContentIcon` frame, `ChallengeRow` + HUD bars (INK frame + fill rects), `ThumbStick` (circle ring + disc), `MenuScreen` scroll bar, main-menu red dot (ColorRects), banners/titles = 2x font with 1px shadow. Screens: menu, settings, shop, unlocks, hero, toggler, level-up cards, choice, HUD, pause, revive, results
  - [x] `tools/render_ui.gd` now also renders menu, settings, shop, HUD with the stick held, pause, revive, results; its throwaway save no longer gets wiped by `_ready()` (coins/unlocks were showing 0). The main menu still reads the `Save` autoload, so its coins show the dev save
  - [x] Owner picks the option: (a) SpriteCook UI kit (2026-10-09), after a UI breakdown
  - [x] Owner OK on the breakdown and two kits (49 credits planned), 2x portraits kept (2026-10-09)
  - [x] Kit 1 (menus), 23 credits: concepts A/B (owner picked B), one component sheet. `tools/art/ui_kit.py` cuts, palette-snaps and shrinks it (1/10.5) into `assets/ui/` (9-slice templates: button, button_small, window, row, ribbon, tag, tile, tile_selected; sprites: pips, toggles, coin, padlock, dot; `ui_kit.json`). `scripts/ui/ui_art.gd` (UiArt) recolors by hue ramps and draws them: PixelButton, PixelPanel ("window" / "row"), FaceTile, title ribbons (menus, settings, run panels), coin counter, toggle switches (settings, Toggler), stat pips, role tag, menu dot, map padlocks. Plain-box fallback below the art's size. Test `tests/test_ui_art.gd`; 1763 checks, FLOW OK. `tools/check_assets.py`: upscale check needs 3 blocks a side (9x9 pips were false positives); 80 assets, 0 failed. `tools/render_ui.gd` viewport now Nearest like the game
  - [x] Owner OK on kit 1 (2026-10-09), committed `cbefa2a`
  - [x] Kit 2 (in-run), 16 credits (1 concept, 1 sheet; owner OK on the sheet). Cut by the same tool (second sheet argument): "bar" / "boss_bar" frames (fills drawn in code from the fill strips' ramps, `UiArt.bar`), name plate, banner plate (`UiArt.ribbon_behind(label, "banner")`), card / card_gold (slot left out; card turns gold when pressed), NEW badge (PixelButton.badge), action / action_pressed (ActionButton, die / ffwd / X icons), pause (SpriteButton), joystick base + knob, heart, clock, skull, key. HUD relaid out (Hud docs): XP top, heart + HP + LV/HP text left, clock + timer centre, coin + gold and skull + kills right, key and pause below; edge arrows stay code-drawn (any angle)
  - [x] Owner: health bar under the hero (2026-10-09): world pixels, rules run.json "player_hp_bar" {width 16, height 4, gap 2} (GameData checks it), INK outline, BLOOD track, GREEN / RED under 30%, SKY shield line; drawn while blinking too
  - [x] Owner OK on kit 2 (2026-10-09), committed `8821d17`. Phone-checked 2026-10-09; locked map cards made 30px tall (second line overlapped the plate's bottom edge)
  - Not used yet from sheet 1 (cut with `--all` for review): arrows, square button, map card frame, AD clapper, plates, scroll track/thumb (8px: too wide for the 2px bar beside the 172px list)
  - [x] New start flow (owner, 2026-10-09): PLAY -> character select -> map select -> run. Owner: locked heroes as silhouettes, locked maps shown, Toggler on the map screen. `HeroScreen` (preview: idle sheet at 2x, "role", stat pips relative to all characters (`Meta.stat_pips`, `SHOWN_STATS`), signature weapon, passive; locked = silhouette + challenge + price; grid of `FaceTile` heads at 2x), `MapScreen` + `MapCard` (thumbnail `assets/maps/suburbia_thumb.png`; locked maps are short cards with the boss to beat or COMING SOON). Data: character "role", map "status"/"unlock_after"/"thumb", stubs `sewers`, `farm`, `shopping_mall` ("planned"); save "map" + "maps_cleared" (set by `Meta.commit_run` when the boss falls). Tests: `tests/test_select_screens.gd`, 5 bad-data cases; flow check goes PLAY > NEXT > GO!. 1684 checks pass, FLOW OK
  - [x] Owner: keep the 2x preview sprite and face tiles (2026-10-09)
  - [x] HUD pause button (2026-10-09): there was none (pause only via Android back / Esc / focus loss; iOS has no back key). `ActionButton` "pause" glyph, top right under the gold. Test: `test_run_flow.gd::test_pause_button_on_screen`
- [ ] Enemy sheets from assets/creatures/ for every role (elites = scaled + recolored)
- [ ] Placeholder inventory: list every code-drawn / placeholder asset and replace it
  - Audit 2026-10-09 (`PlaceholderArt` shapes still in use; mask sizes in brackets):
    - [x] Map objects, `data/interactables/*.json` "sprite": chest x3 colours [16x14], pot [11x11], shrine x3 colours [10x18], pigeon cage [12x18], cage key [11x6], portal [14x18], merchant [17x18] (SpriteCook sheets D + E, colour variants recolored offline; 2026-10-09)
    - [x] Weapon projectiles: weapon "shot_sprite" / "shot_turns" (feather, staple, rocket as 16-direction strips; duck from its icon; cup), run.json "default_shot_sprite" (pellet) (sheet F; 2026-10-09)
    - [x] Enemy shots: spitter "shot" and mole "rocks" take a "sprite" (`assets/shots/enemy/`, reserved magenta + INK outline, 6x6 / 7x6; `tools/check_assets.py` allows index 31 only there)
    - [x] Weapon objects drawn with `draw_rect` (missed by the `PlaceholderArt` grep): Baguette "swing_sprite" (32 turns x 7 blade lengths, RotSprite-style turn of the paid 32px icon), garden gnomes "orbit_sprite" (icon gnome 7x11). Leaf blower leaves, socks aura and toaster sparks are VFX (phase 7)
    - [x] XP gems: "gem_tiers" "sprite": drop 7x9 SKY, square-cut 10x10 PINK, faceted 11x12 RED (were 3x4 / 5x5 / 6x6); three shapes as well as three colours
    - [x] Phone check of the new run art: owner played it on the phone and approved (2026-10-09); review render: `godot --path . -s res://tools/render_objects.gd`
    - Enemies on shapes: bloater, gnat, spitter, bill (need the owner's creature exports)
    - Keep: hit particles "dot" (VFX, phase 7), HUD edge arrows (any angle), hero fallback
  - Owner (2026-10-09): projectiles and gems via SpriteCook too, not hand-pixelled
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
  - [x] `tools/check_assets.py` (2026-10-09): every PNG in assets/ on the palette, binary alpha, index 31 unused, not an NxN upscale. 61 assets, 0 failed. Launcher icons (`assets/icon/`) are whole-number upscales on purpose and only get the palette check. Rerun before closing the phase (enemy sheets, pond/pool, UI still to come)
- [ ] Phone stress test (300 enemies) with the 2x world view: owner skipped it for now (2026-10-09); desktop: 75 fps cap, 1% low 66.2 at the 1.5 view. CLAUDE.md needs an fps number before the phase is done

### Phase 6 results so far (2026-10-09, same desktop, windowed, vsync, starter build, Sir Loaf sprite)

| Stress test, 300 enemies, 20 s | Avg fps | 1% low fps | Logic ms/frame | Avg on screen |
| --- | --- | --- | --- | --- |
| Windowed, vsync on | 75.0 (display cap) | 66.6 | 2.98 | 299.3 |
| Same, Turbo Pigeon | 75.0 (display cap) | 66.2 | 3.26 | 299.6 |
| Same, Gary, heroes at ~22px | 75.0 (display cap) | 66.6 | 3.59 | 299.8 |
| 270x480 view, 1440x1760 textured map | 75.0 (display cap) | 68.6 | 3.37 | 299.5 |

SpriteCook: 635 credits spent, 165 left (2026-10-09, after the run-art sheets D, E, F).

## Phase 7: Audio and VFX

Scope from docs/BRIEF.md "Audio" and "VFX": sfxr-style SFX generator (WAV), three placeholder chiptune tracks (OGG), one audio manager with a voice cap, every VFX in the table, settings for damage numbers, screen shake and reduce effects. Done = every key event has a sound and an effect, 300-enemy stress with all effects on stays above 50 fps.

- [x] SFX generator `tools/audio/sfxr.py`: port of the sfxr synth + its presets (pickup, laser, explosion, powerup, hit, jump, blip); recipes in `tools/audio/sfx.json` (seeded, same file in = same WAVs out); 48 sounds -> `assets/audio/sfx/*.wav` (22050 Hz mono, 752 KB)
- [x] Music `tools/audio/chiptune.py`: 2 pulse + stepped triangle + noise drums, seeded melody phrases over a chord progression, tails wrapped for a seamless loop; menu 37 s, gameplay 42 s, boss / Final Swarm 35 s -> `assets/audio/music/*.ogg` (ffmpeg libvorbis q3, 1 MB total)
- [x] Audio manager: autoload `Audio` (`scripts/autoload/audio.gd`), file list only in `data/rules/audio.json`. 12-voice SFX pool, per-sound "gap", "max" and "priority" (a full pool only steals from equal or lower priority), random pitch per play, Music/SFX buses follow the settings, music crossfades and loops; headless sends nothing to the dummy driver (bookkeeping still runs)
- [x] Sounds wired: every run event (hits, crits, kills, hurt, dodge, gems, gold, level-up, cards, chests, shrines, pots, key, cage, merchant, buy, boss summon / dig / slam / rocks / rage / down, portal, escape, elites, swarm warning / end, Final Swarm, bills, enemy shoot / swell / burst / windup, death, revive, low-HP heartbeat), weapon attack sounds from weapon data, every button press (`PixelButton.sound`, `SpriteButton`); music: menu, gameplay, boss on summon and in the Final Swarm
- [x] VFX table:
  - [x] Hit flash (existing shader), damage numbers (setting), death particles now fade by Bayer dithering (`assets/shaders/dither_fade.gdshader`, 24 pooled CPUParticles2D), hit-stop on big crits (half the enemy's HP, or any crit on an elite), boss hits (at most every 0.35 s) and the boss's death, screen shake (setting) on hurt, nearby explosions, boss slams, boss death, player death
  - [x] Gems twinkle and pulled gems trail (dithered, tier color); level-up light burst plays over the frozen run before the cards show (`LevelBurst`); a beam in the item's rarity color rises from the chest, then it pops (sparks) and the name shows
  - [x] Weapons: coffee steam + splash puff, wavy green sock aura, toaster lightning (now with a white core line + spark hits), firework explosions (white-hot spark bursts in the rocket's color); weapon "hit_fx" for the rest: Baguette crumbs, Stapler glints, Feather fluff, Duck stars, Gnome bonk stars, Leaf Blower leaf puffs
  - [x] Elite outlines (existing), red telegraphs (existing), dithered red vignette under 30% HP that thumps with the heartbeat (`assets/shaders/vignette.gdshader`), Final Swarm palette shift (`assets/shaders/palette_shift.gdshader`: every world pixel swapped through a palette->palette map from `data/rules/fx.json`, dithered in over 1.2 s, enemy shots stay magenta)
  - All numbers in `data/rules/fx.json`; run-wide feedback in `scripts/run/juice.gd`; new `Fx` kinds sparks, beam, puff, star
- [x] Settings: damage numbers, screen shake and reduce effects (existing toggles) now all do something. Reduce effects: no sparks / puffs / stars / dithered discs / gem trails and twinkles / hit-stop, fewer death pixels; rings, bolts, beams, telegraphs, vignette and tint stay (they carry information)
- [x] Data validation: `GameData` checks audio.json (files exist, numbers, every sound the code plays, music), weapon / enemy "sfx" names, weapon "hit_fx", fx.json numbers and the tint map (palette names, never ENEMY_SHOT)
- [x] Tests: `tests/test_audio_fx.gd` (files load; voice cap, priority, gap; settings mute the buses; 29 key events each make a sound and an effect; every weapon has a signature; settings turn effects off; hit-stop; burst before cards; tint LUT on the palette; dither), `test_data.gd::test_phase7_bad_audio_and_fx_are_caught` (12 cases). 1957 checks pass, FLOW OK (headless), `tools/check_assets.py` 123 assets, 0 failed
- [x] Stress test: `--low_hp` holds the hero at 20% HP so the vignette and heartbeat run; RESULT now has an "fx" block showing which effects were active; the Android Stress preset turns it on. An invincible hero still gets hurt feedback
- [ ] Owner listen-through: SFX and the three tracks were checked by numbers only (length, peak, loop length), not by ear
- [ ] Owner look at the Final Swarm palette shift and the low-HP vignette on the phone
- [x] Phone stress test with all effects (2026-10-09, `Android Stress` preset, results below). 1% low just under 50 on the phone, as before phase 7

### Phase 7 results (2026-10-09, same desktop, windowed, 20 s, full build, Final Swarm density, all effects active)

`godot --path . res://scenes/debug/bot_run.tscn -- --mode=stress --seconds=20 --build=full --final --low_hp [--uncapped]`. Effects active per the RESULT "fx" block: reduce_effects false, damage numbers, shake, gem effects on, final_tint 1.0, vignette 0.88, ~1,100 fx and ~5,000 sound cues (12 voices; ~3,460 plays skipped by gap / max / full pool).

| Stress test, 300 enemies | Avg fps | 1% low fps | Logic ms/frame | Avg on screen |
| --- | --- | --- | --- | --- |
| Windowed, vsync on | 75.0 (display cap) | 66.8 | 3.36 | 304.2 |
| Windowed, uncapped | 338.6 | 188.6 | 1.68 | 306.3 |
| Before phase 7 (commit 3cb1d0b), uncapped, same flags minus --low_hp | 275.8 | 196.8 | 2.37 | 312.5 |

The effects cost is within run-to-run noise on this desktop.

| Phone: Xiaomi 15T, 60 Hz, vsync (Android keeps vsync on in the "uncapped" pass), Final Swarm, full build, all effects | Avg fps | 1% low fps | Logic ms/frame | Logic p99 ms | Avg on screen |
| --- | --- | --- | --- | --- | --- |
| Phase 7, run 1 (30 s) | 60.0 | 48.6 | 5.80 | 9.65 | 310.1 |
| Phase 7, run 2 (30 s) | 60.1 | 49.5 | 6.76 | 10.78 | 334.0 |
| Before phase 7 (3cb1d0b), run 1 | 59.9 | 47.2 | 7.08 | 10.59 | 316.9 |
| Before phase 7 (3cb1d0b), run 2 | 43.4 | 39.1 | 7.82 | 14.97 | 338.6 |

The "before" build ran right after the phase 7 runs, on a warm phone, so its second pass is probably throttled. Phase 7 effects didn't lower the phone numbers. The 1% lows sit just under 50 on both builds, so they don't come from the effects.

## Found during phase 7

- Windowed runs that quit while sounds play (bot_run) print "N resources still in use at exit": AudioStreamPlayback objects the audio thread still holds at quit. Exit-only; headless tests are clean (Audio sends nothing to the dummy driver). Not fixed
- `scenes/debug/flow_check.tscn` must run `--headless`: windowed, the fake ad backend shows its visual test ad and waits for a click, so the check fails (as documented in its header; not a bug)
- The first-run hint toast "STAND ON THE ALTAR TO CALL THE BOSS" is wider than the 180px view and gets cut off at both sides (seen in a stress screenshot; older than phase 7)
- Phone 1% low fps is ~47-50 at Final Swarm density with a full build (before and after phase 7), while logic p99 is ~10 ms of the 16.6 ms budget: the dips are probably render-side or GC spikes. Worth a `--profile` run on the phone before release

## Phase 8: UI/UX polish for release (owner request 2026-10-09)

Owner: "the current game core actually good, but the UI UX is bad". Free hand on every screen, UI and VFX; the brief gets updated where this changes it. Review renders: `godot --path . --resolution 540x1170 -s res://tools/shoot_screens.gd -- --notch=12` (every screen and run state, fake camera cutout).

- [x] Safe area: HUD, pause button, menus and run panels keep clear of the camera cutout and gesture bar (`scripts/ui/safe_area.gd`; immersive mode draws under the cutout). Checked with a fake 10-14px cutout on desktop, not yet on a phone
- [x] Font (owner request): "Bonk", our own bold pixel font (2px stems, clipped corners, 7px caps, tabular digits), `tools/fonts/make_bonk.py` -> `assets/fonts/bonk.fnt/png`; `Fonts.BOLD` for titles, buttons, headings, HUD numbers, damage numbers; the 5x7 font stays for long text (buttons fall back to it when a line doesn't fit)
- [x] Shared parts: `DitherDim` (ordered-dither dim, no alpha), `PixelTitle` (outlined, banded, wavy big text), `UiFx` (slide-in, hop, blink, haptic buzz), `Transition` autoload (dithered scene wipe; instant headless), `CoinPlate` (count-up), `PatternBg`, `Glyphs` (tiny text-grid icons)
- [x] Main menu: `TitleScene` (night sky, stars, moon, the picked hero running from blobs/skitters/chompers past scrolling props, gems popping), wavy logo + random tagline instead of "(WORKING TITLE)", top bar (coins, gear), next-unlock teaser card with progress, big hopping PLAY, UNLOCKS | SHOP, FREE +25 COINS
- [x] Settings as a modal window over the dim; vibration setting (`Save` default on, `permissions/vibrate` in both Android presets); buzz on the unlock popup and when switching vibration on
- [x] Menu screens: fixed bottom bar (< BACK + NEXT / GO!), coin plate, bold section headings with rules, "COLLECTED n/19" bar, coin-icon price buttons inside the rows (no overlaps), level pips in the shop, locked hero shows its challenge progress; titles HEROES / MAPS (the old ones didn't fit the ribbon)
- [x] Unlock popup (`UnlockPopup`): UNLOCKED!, icon at 3x on a turning sunburst (pixel-rendered), NICE!
- [x] HUD: big 2x timer (SALMON last 30 s, PINK in the Final Swarm), LV on the XP bar (flashes on level-up), HP ghost drain, heart beats under 30%, gold hop, toasts on a dark plate that wrap (fixes the cut-off altar hint)
- [x] Level-up: `LevelCard` (kind-coloured icon frame, bold name, level pips with the new level blinking, kind + level, wrapped description), cards slide in one by one, REROLL / SKIP / BANISH words on the action buttons
- [x] Pause: run facts, build (weapon and tome slots with levels, items with stacks), stats, music / sound toggles, RESUME, GIVE UP asks twice
- [x] Shrine / merchant: tome icon per stat bonus (three colours), item icons at the merchant
- [x] Game over: reason line, hero (idle after a win, hit after a loss), TIME / LEVEL / KO / GOLD tiles, coins rolling up with ticks (and again on 2X), FINAL SWARM / DOUBLED / TOTAL line, closest unlocks in a scroll, PLAY AGAIN (same hero and map, through the ad break) and MENU
- [x] Run start: SURVIVE! banner; first two runs: ghost joystick "DRAG ANYWHERE TO MOVE" until the first touch
- [x] Death: 0.7 s red dither flash over the frozen moment before the result (state and pause stay immediate)
- [x] Damage numbers: Bonk with a full outline, hop-and-fall arc, crits flash with a red outline and "!"
- [x] Revive panel shows the hero's hit pose
- [x] Tests + flow check + stress fps; brief updated ("UI and screens", asset table)
  - `tests/test_ui_polish.gd` (font coverage and palette, dither levels, safe area to HUD / pause / menus, pause build and two-tap GIVE UP, PLAY AGAIN, level cards, unlock popup, menu nodes). 2037 checks pass, FLOW OK (headless), `tools/check_assets.py` 124 assets, 0 failed
  - Review renders: `tools/shoot_screens.gd` (menu, settings, heroes, maps, unlocks, popup, shop, run, level-up, pause, shrine, low HP, game over, gameplay)
- [ ] Owner phone check: safe area on a real cutout, font readability, the title scene, haptics
- [ ] Phone stress test after phase 8

### Phase 8 results (2026-10-09, same desktop, windowed, 20 s, full build, Final Swarm density, all effects)

| Stress test, 300 enemies | Avg fps | 1% low fps | Logic ms/frame | Avg on screen |
| --- | --- | --- | --- | --- |
| Windowed, vsync on | 75.0 (display cap) | 67.5 | 3.03 | 302.7 |
| Windowed, uncapped | 354.9 | 196.5 | 1.55 | 306.1 |
| Phase 7, uncapped (for comparison) | 338.6 | 188.6 | 1.68 | 306.3 |

### Phase 8 release pass (owner feedback 2026-10-10)

Owner: unlocks and shop look bad and are hard to scroll; layouts are bad everywhere (in run too); the run doesn't say what your weapons, tomes and items are; VFX (Baguette swing, Stinky Socks, chests, shrines, pickups) need to be much more visible, "like Megabonk"; remove MADE WITH GODOT; the name is "Mobbed! Survive the swarm"; titles don't render on the phone; less empty space.

- [x] Titles blank on the phone: `PixelTitle` read the raw `bonk.fnt` with FileAccess, which an export doesn't ship. Glyphs now come from the imported FontFile (checked in an exported Android pack: raw .fnt absent, glyphs read fine). `assets/ui/ui_kit.json` (UI kit 9-slice data) was also missing from both presets' include_filter, so the phone drew fallback boxes; added. Tests: every asset JSON is in the include filter (fails with the old filter), PixelTitle glyphs match the .fnt
- [x] Name: logo "MOBBED!" (4x Bonk, overlapping outlines, letters hop in turn) + "SURVIVE THE SWARM" on the ribbon; `config/name` "Mobbed!", Android `package/name` "Mobbed!" (package id unchanged, see Found); MADE WITH GODOT removed; tagline under the logo removed (it crowded the town)
- [x] `DragScroll`: lists drag from anywhere, even starting on a button, with fling; the button lets go without firing or staying drawn pressed (test, mutation-checked). Used by every menu screen and the game-over list
- [x] Menu screens: slimmer header (title only), coin plate moved into the bottom bar next to BACK, optional fixed `top_panel()`, `list_height()` + `fills_height` so short screens fill the space (rebuilt once the real height is known)
- [x] Unlocks: fixed detail panel + 4-column `IconTile` grid by tier (silhouette + progress strip / hop + sparkle + NEW / tick), BUY in the panel
- [x] Shop: same layout; tiles with level pips, red dot when affordable; shop data names an "icon" (`Icons.ref`, validated); Remove Ads as a purple banner that wraps its text
- [x] Hero select: preview fills the screen, hero at 3x on a lit stage (2x/1x on short screens), compact two-column stat pips, weapon + passive; Map select: one-line locked cards and a WHO LIVES HERE panel (enemy portraits from the map's spawns and swarms) with the goals
- [x] HUD build strip (weapon and tome icons with level pips, flash on new/level-up), pickup card for chest/merchant items and shrine bonuses (icon, rarity, name, desc, stacks); arrows draw under the card; info line and toasts moved below
- [x] Pause fills the screen; tap a build slot for details (level, what it does now, weapon damage and kills this run, tome totals, item rarity/stacks); stats always fit on a 19.5:9 phone
- [x] Level-up cards show the numbers that change (weapons: first two changed keys; tomes: before > after); merchant cards say what the item does; game over lists the build
- [x] VFX: Baguette crescent smear (4 layered bands); Stinky Socks stink cloud under the hero (cached dither disc), rim, puffs, stink lines, wave per tick; light pillars + ground glow + motes + twinkles for chests, shrines, key, cage, altar, portal, merchant (data "beam"), pot twinkles ("twinkle"); chest price tag always shown; shrine ring turns, fills and lights up; chest pop adds a second ring; shot trails per weapon (data "trail"); plain damage numbers in a tiny 3x5 font (crits stay big)
- [x] Gems no longer pile in a ring round a hero standing still: base pickup range 22 -> 30 (Sir Loaf, Gary), 24 -> 32 (Turbo Pigeon); 32 made the Final Swarm outlast the bills test (10.3 min), 30 passes
- [x] Perf: interactables culled to the view (pass 2 drew every chest's price string on the map each frame), glows cached as textures, cheaper trails
- [x] Screenshot tool: run shots no longer covered by real level-ups (auto cards during the fast-forward), new `vfx` and `weapons` sections
- [x] Tests: `tests/test_ui_release.gd` (name/no credit, drag scroll, unlocks grid buy, shop icons/buy, HUD strip + pickup card, pause details, level-card numbers, build on game over, new effects on the palette), export filter tests; 2107 checks pass, FLOW OK
- [ ] Owner phone check of this pass (titles, scrolling feel, pillars/smear readability, HUD strip size)

Owner follow-up (2026-10-10): Stinky Socks and Hot Coffee still weak, the timer overlaps the HP bar, show the items in the run (small, at the bottom), remove the monster info from the map select.

- [x] Stinky Socks: denser cloud rim; outlined three-lobe stink puffs drifting out and popping at the rim; three swirling wisps; rim drawn dark-under-light so it reads on grass and road; a green puff with each tick's wave
- [x] Hot Coffee: puddles drawn under the hero and enemies as glossy coffee (cached lumpy blob: BARK fill, WOOD ripple and edge band, CRUST lip, DOUGH shine), spreading on landing and shrinking as they dry; popping bubbles; wavy steam; landing splash (drops, ring, steam); the cup throws a shadow and puffs steam in flight
- [x] Fixed: `draw_under` layer was never redrawn after the first frame (the aura cloud and puddles froze); `Run._render` now redraws it
- [x] HUD: the HP bar ends where the big timer starts (shrinks for +10:00 in the Final Swarm, 30 px minimum)
- [x] HUD item row at the bottom-left: 16 px icons in 18 px frames with rarity corners, tiny stack digits, flash on new stacks, wraps upward, sits above the boss bar during the boss; its own layer, redrawn only when it changes
- [x] Map select: monster roster removed, a small GOALS panel stays
- [x] Tests (item row, timer room, socks/coffee art on the palette, map without roster): 2117 checks pass, FLOW OK; 75 fps capped (0 missed vsyncs), uncapped 300-355 across repeated runs (desktop noise is about +-50 fps run to run)

| Stress, 300 enemies, full build, Final Swarm density, all effects (desktop, 2026-10-10) | Avg fps | 1% low fps | Logic ms/frame | Avg on screen |
| --- | --- | --- | --- | --- |
| Windowed, vsync on | 75.0 (display cap) | 69.2 | 3.17 | 305.2 |
| Windowed, uncapped (after the culling fix) | 341.8 | 192.8 | ~1.6 | ~305 |

Owner follow-up 2 (2026-10-10): scrolling still bugged and not intuitive on every page; redesign the PICK A BONUS and LEVEL UP popups; smaller weapon/tome/item icons in the run, items centred with the rarity as the whole border; a progress sound while a shrine charges; game over shows only the coins earned.

- [x] Scroll bug found: `DragScroll` let go of the pressed button with a pushed release at -10000 and recognised it by position, but `push_input` maps positions through the screen's stretch scale (x6 on the phone), so the list swallowed its own fake release and stopped after 5 px with the button held. The old test only ran at x1. Now the injected events are flagged (and pushed in viewport coordinates); test runs at x1 and x3 (the old code fails x3: "follows the finger (0)")
- [x] Scroll feel: the list follows the finger from where the drag starts (no 5 px jump), fling speed from the last 0.1 s of movement (none if the finger rested before lifting), a tap on a gliding list only stops it (presses nothing), smooth float glide that stops at the ends. Game over list got the pixel scrollbar (`DragScroll.make_bar()`, shared with menu screens)
- [x] Pick-one cards (`LevelCard`, used by level-up, shrine and merchant): striped badge in the kind / option colour with the icon at 2x and an INK drop, level pips under it, bold name, tag chip (NEW WEAPON / TOME LV 2 / SHRINE / RARE ITEM), description, LIME numbers line; NEW! sticker on the top edge; white rim while pressed. Panels float over a darker dim (no box), title + subtitle ("LEVEL 4 - PICK ONE (+1 MORE)", "YOUR GOLD 40")
- [x] Shrine cards: stat name, big value ("+8%") in the card colour, "NOW 100% > 108%" (the bonus tried on and taken off). Merchant cards: price chip (gold, SALMON when short), SOLD / HAVE ONE stamps
- [x] HUD: build strip slots 18 -> 14 px with 12 px icons and 5 pips under each slot; item row centred, 16 px frames with a full 1 px border in the rarity colour, 12 px icons. `Icons.small()` makes real 12 px images (area-weighted majority colour, palette only, never scaled)
- [x] Shrine / altar charge: "charge" blip (`tools/audio/sfx.json`, sfxr) plays in 10 steps while you stand in it, rising an octave ("steps", "rise" in rules/audio.json), first one as you step in; the shrine chime when full. `Audio.play` / `Juice.sfx` take a pitch
- [x] Game over: TOTAL coins removed; only the coins earned (and DOUBLED / FINAL SWARM)
- [x] Fixed a flaky test error: a late fake-store callback refreshed a shop whose save was gone
- [x] Tests: drag at x1/x3 (follow, no jump, no click, no stuck button, rest = no fling, flick glides, tap stops it), small icons 12 px on the palette, item row centred at 1/3/12/30 items, rarity frame colour, shrine/merchant cards, bonus preview leaves stats alone, charge blips (one per step), no TOTAL. 2188 checks pass, FLOW OK, 124 assets OK
- [x] Stress (desktop, full build, Final Swarm, all effects): vsync 75.0 avg / 66.3 1% low, 304 on screen; uncapped 351.6 avg / 202.7 1% low, 306 on screen
- [ ] Owner phone check: scrolling feel on every list, the new cards, HUD icon size, the charge blips by ear
- [ ] The game-over TOTAL test is not mutation-checked (test runs have no save, and the old code showed TOTAL only with one)

Owner follow-up 3 (2026-10-10, after the phone build): unlocks grouped by kind with tabs instead of EARLY / MID / HARD; level-up and bonus popups keep their new cards but go back in a container; REROLL / SKIP / BANISH redesigned; the back button must never close the game (in a run like the pause button, menus step back, home asks); a new game icon from SpriteCook.

- [x] Unlocks: `PixelTabs` (new) with one tab per kind (hero, weapon, tome, item icon + owned/total, red dot when one is ready to buy; the picked tab stands taller in its colour on a matching rule). A tab fits on screen (most is 7 tiles, 2 rows). Tier names removed from the screen; tab icons are start content only (no spoiled rewards)
- [x] Level-up, shrine and merchant cards back in the window panel (cards 160 wide); the dim is back to its old level
- [x] `ActionButton` redesign: plate in the action's colour (REROLL sky, SKIP butter, BANISH salmon; PINK "CANCEL" while banishing), icon centred with an INK silhouette drop, bold word under it, corner bubble with the charges left (RED) or AD (PURPLE)
- [x] Back button: `application/config/quit_on_go_back=false`. Run: pause / resume like the pause button, leaves the merchant, level-up and shrine cards wait, game over goes to the menu, nothing during an ad. Menus: a question or unlock popup closes first, then the open screen, then settings; on the home screen a `ConfirmPopup` (new) asks QUIT? (QUIT / STAY; back again = STAY)
- [x] Game icon: SpriteCook (12 credits, owner approved), `tools/art/app_icon.py` -> 32 px icon, 192 launcher (x6), adaptive foreground (x9 = the 288 px a launcher shows) + background + monochrome (themed icons) in both Android presets
- [x] Tests: `tests/test_back_button.gd` (setting off, run pause/resume, level-up waits, merchant leaves, menu steps then asks, back = STAY), unlocks test per tab. 2209 checks pass, FLOW OK, 127 assets OK. Stress 75.0 avg / 66.9 1% low (vsync), 304 on screen
- [x] Installed on the phone (debug APK), menu runs, no script errors
- [ ] Owner phone check: back button everywhere (adb can't press it on this Xiaomi), tabs, the new action buttons, the icon on the home screen (round mask cuts the swarm at the corners)

Owner follow-up 4 (2026-10-10): "shrine" and "tome" too close to Megabonk; a more engaging game icon from SpriteCook; an "Aviharez Studio" splash with a little animation and a logo.

- [x] Names on screen: shrines are BEACONS (CHARGE / RISK / CHALLENGE BEACON, BEACON card tag, BEACON BONUS, challenge "ACTIVATE 5 BEACONS"), tomes are MANUALS (MANUALS tab, MANUAL card tag, "MANUAL LV n/5", silhouette label). Ids, data folders, stat sources and save keys unchanged; noted in BRIEF.md
- [x] Game icon v2: SpriteCook (12 credits, owner approved; first try blocked by content safety and refunded), Sir Loaf mid-swing on sky with a Blob and a bug. `tools/art/app_icon.py` now keeps 64x64: icon 64, launcher 192 (x3), adaptive fg x5 on SKY-blue bg, mono = hero silhouette
- [x] Studio splash `scenes/splash.tscn` (`Splash`, now `run/main_scene`): code-drawn pixel badge (gold "A" on a blue plate) drops in with dust and a bounce ("bonk"), shine sweep, sparkles, AVIHAREZ pops in letter by letter (rising "gem" blips), STUDIO under it, name hops, dither wipe to the menu at 2.7 s; tap or back skips (after 0.3 s). INK background = the boot splash colour
- [x] Tests: `tests/test_splash.gd` (first scene, badge on the palette, plays then a tap leaves); 2225 checks pass
- [ ] Owner phone check: splash timing / sound, the new icon on the home screen (round mask and themed icon)

Owner follow-up 5 (2026-10-10): plants shouldn't collide; unlock prices should make sense (Megabonk as reference) with coin income adjusted to match; coin plate and settings gear misaligned on the home screen.

- [x] Plants never block: `tree` (was its trunk cell) and `hedge` (was solid) are walk-through like bushes and planters. Houses, fences, ponds, cars and swings still block. Test `test_plants_never_block` (mutation-checked: a solid hedge fails both checks)
- [x] Coins: `per_minute` 4 -> 10, `per_kill` 0.02 -> 0.003, `death_multiplier` 0.6 -> 0.75, Final Swarm `coin_mult_per_min` 0.5 -> 0.15. Kills used to pay most of a run (~9,000 kills in a won run), so bot sims earned 30 for an early death and 300-718 in the Final Swarm (16x). Now 35-45 vs 137-225 (about 5x), same seeds
- [x] Prices in the Megabonk mould (small numbers; Early costs about one run), measured against the ~40-coin early-death run a new player earns: Early 50 -> 30, Mid 150 -> 90 (Turbo Pigeon 225 -> 140), Hard 300 -> 220 (Gary 450 -> 350). All unlocks 3,775 -> 2,500. Shop: stats 20/45/80/130/200 -> 15/30/50/80/120; Reroll 25/60/120; Skip 20/50/100; Banish 40/90/160; Toggler 60/150 (Megabonk's is 50). Whole shop 3,770 -> 2,350. Daily ad reward stays 25 (about one early run)
- [x] Home top bar: `CoinPlate.align` (0 = left); the plate is pinned 4 px from the left (it was centred in a 60 px box, so it floated ~20 px in) and the gear is on the same 4-20 px row (it was 3-23, 4 px taller). The gear is drawn as the plain pixel box at that height
- [x] Tests: 2227 checks pass (Final Swarm multiplier test now reads the rate from data). Stress (desktop, full build, Final Swarm, vsync): 75.0 avg / 68.5 1% low, 307 on screen
- [ ] Owner check: prices and coins by feel on the phone (bot sims only; a human's early runs are likely shorter than the bot's 4-6 min)

Owner follow-up 6 (2026-10-12): exit popup off-centre on home; a trail behind the walking hero; a more readable font (reference: Overgeared Hero; one font or two).

- [x] QUIT? popup centred: `ConfirmPopup` is built before it is in the tree, so `UiFx.slide_in` saved the window's position against a zero-size parent (-76,-46) and slid it there (top-left). New `UiFx.slide_in_offsets` moves the anchored offsets instead, so the window lands where its anchors say. Test: the window centre matches the screen centre after the slide (mutation-checked: old code fails with (0,-25) vs (160,135)). `tools/shoot_screens.gd` shoots it as `09_quit_popup`
- [x] Walk trail: dust puffs (PAPER, dithered fade, drifting up) every 5 px walked, 5 px behind the hero at alternating feet, in their own `Fx` layer under the hero. Tuning in rules fx `walk_trail`; skipped with "reduce effects" (puffs are cosmetic). Test: none standing still, one per every_px, drawn under the hero, none when reduced
- [x] Tests 2233 pass. Stress (desktop, full build, Final Swarm, vsync): 74.9 avg / 67.4 1% low, 306 on screen
- [x] Font: planned in Phase 9 below (owner first picked Lilita One, then switched to Titan One + Inter on 2026-10-12)
- [ ] Owner phone check: trail look on grass and road, popup centred on the phone

## Found during phase 8

- `scripts/ui/menu_screen.gd` slide-ins capture the final position when the screen opens; a viewport resize during the 0.25 s slide lands it at the old spot until the next resize (the main menu uses an offset over the layout instead, which is safe)
- XP gems pile into a dense ring round the hero mid-run (seen in the gameplay render); a gameplay/balance question for the balance phase, not UI
- ~~The title is still the working title~~ Done 2026-10-10: "Mobbed!" (`main_menu.gd` GAME_TITLE / GAME_SUBTITLE)
- The Android package id is still `com.aviharez.swarmsurvivor` (only the display name changed). It can't change after the first Play Store upload, so pick the final id before then
- Renaming `config/name` moves the desktop `user://` folder (`~/.local/share/godot/app_userdata/Mobbed!`); the old desktop save stays in `.../Swarm Survivor Pixel/`. Phones are unaffected (Android keys user data on the package id)
- On a short desktop window (338 px tall) the map screen's info panel runs ~6 px past the list and scrolls; fits on 19.5:9 phones
- Many weapon effects are small at the world scale (Rubber Duck, Stapler, Feathers read mostly through their new trails); a per-weapon art pass (bigger shot sprites, muzzle flashes) would need SpriteCook and the owner's OK

## Phase 9: Fonts and UI revamp (owner request 2026-10-12)

Owner: the all-caps 8px pixel fonts (Bonk + 5x7) are hard to read, make every screen feel too full, and some text overlaps. New fonts: **Titan One** (titles, buttons, card and item names, big numbers) + **Inter Black (weight 900, as Overgeared Hero uses it)** (body text, labels, small numbers), both OFL from Google Fonts. Text goes mixed case. Keep the goofy pixel look: palette colours, INK outlines, hard drop shadows, pixel-art UI plates (now from SpriteCook kit 3, see below). Not started: waits for the owner's OK on this plan and on the new CLAUDE.md / BRIEF.md wording. (BRIEF.md's own "Phase 9: Release prep" becomes phase 10.)

Done in the planning session (2026-10-12):

- [x] Fonts in the repo with their licences: `assets/fonts/titan_one/` (Reserved Font Name "Titan": if we ever subset or edit the file, it must be renamed), `assets/fonts/inter/` (variable, wght 100-900, opsz 14-32; no reserved name), `assets/fonts/lilita_one/` (first pick, used in the comparison renders; remove once the owner confirms)
- [x] Sharpness test, `tools/font_preview.gd` (+ `tools/revamp_fonts.gd`, the shared setup): the root viewport oversamples dynamic fonts at the stretch scale, so in the UI layer text is drawn at device resolution (3x on a 540-wide window, 6x on a 1080-wide phone). With antialiasing off every text pixel is a palette colour (0 off-palette pixels; the same line with AA on made 2,220 in 245 colours). Even spacing needs hinting none + subpixel positioning auto + `keep_rounding_remainders` (with "disabled" positioning, 8px Lilita read "Pick o ne")
- [x] World view finding: text drawn inside Run's world `SubViewport` is rasterised at the world's low resolution and scaled up (smudgy below ~12px). Drawn in the UI layer at the same spot it is crisp. Plan: all world text moves to a UI-space overlay (below)
- [x] Mockups, `tools/ui_mockups.gd` (real title scene, a real run, kit art and icons; not wired to the game): home, level-up cards, HUD. Renders in `docs/phase9/` (0 current, 1 Titan + Inter, 2 Lilita, 3-4 font tests), all 0 off-palette pixels
- [x] Glyph coverage: Inter has every character we need (→ × · … ’ ♥ ★ ✓). Titan One (413 chars) and Lilita (225) lack → ♥ ★ ✓, so title-font strings stay clear of them (test below)
- [x] Width: at the same size Titan One is ~25% wider than Lilita and Inter 900 ~21% wider (900 is ~2% wider than 700; the mockups still fit), so sizes below are a step smaller than the mockup tries suggested, and long names need shrink-to-fit

### Decisions after the first mockups (owner, 2026-10-12)

- The first mockups (`docs/phase9/1_*`) had too much text and too-big body text; a light and a dark redesign (`5_*`, `6_*`) were still "bad". Owner picked the **dark** direction and asked for a SpriteCook design system, with the UI art staying **pixel art** (only the text is smooth)
- [x] SpriteCook kit 3 concepts (owner approved, 14 credits, balance 127): home `e941feb9` (`docs/phase9/7_kit3_home_concept.png`, kit `a30ebb25`) and level-up `2550b1ad` (`8_kit3_levelup_concept.png`, kit `9bd2e504`, child of kit 3). These two images are the target look for every screen
- [x] Kit 3 (home) component sheet (2026-10-12, sheet `4562775f`): **charged 22 credits, not ~14** (sheets now run on gpt-image-2.5-sunburst and the cost only shows after queuing). Balance 127 -> 105. Extracted (alpha threshold 200: the sheet has soft alpha and a dark glow), names / groups / 9-slice borders corrected, finalized (free, 21 components). Cut by `tools/art/ui_kit.py` (third sheet, 16 source px per art px, so 1 art px = 1 UI px like kits 1-2) into 24 files in `assets/ui/` + `ui_kit.json`: `play_button`, `button_orange`, `button_off`, `nav_blue/green/orange/purple`, `plate_dark`, `panel_dark`, `icon_button`, `icon_face` (nav face without its strip, recolourable), `ribbon_red`, `track_dark`, `fill_gold` (recolourable), `seg_track`, `gear_button`, `ad_sticker`, `alert`, `bubble` (alert without "!"), `star` (hand-pixelled, the sheet's was a 7 px blob), `coin_big`, `gear`, `sack`, `padlock_big`, `mystery`. Kits 1-2 still cut byte-identical; `check_assets.py` 151 OK; tests 2297 OK
- [x] Kit 3b (level-up + HUD) component sheet (owner OK at 22 credits, 2026-10-12; sheet `ee87d9c2`, balance 105 -> 83). Extracted (alpha 200), names / groups / states / 9-slice borders corrected, finalized (free, 34 components). Cut at 13 source px per art px into 22 files: `lv_window`, `lv_header`, `lv_card` (one template, recoloured by kind; selected = gold), `lv_frame` (icon / action-button frame, any colour), `lv_sticker` (New / +1 / Ad, any colour), `lv_bubble`, `lv_pip_on/off`, `lv_die` (cut out of the reroll button), `lv_ffwd` + `lv_x` (hand-pixelled: on the sheet they share their button's colours and fall apart when cut out), `info_bar` + `info_icon`, `hud_track`, `hud_fill` (XP gold, HP red), `hud_timer`, `hud_ring`, `hud_pause`, `hud_heart/coin/skull/clock`. New `ui_kit.py` options: `mirror` (right border = left flipped: the sheet's cards have the New sticker fused over their top-right corner), `rows`, `recolor`, `crop`, `icon` (flood-fill cut-out), `grid` (hand pixels)
- [x] Mockups round 4, **following the concepts** (owner: "the concept is much better than yours"), `tools/ui_mockups_v4.gd`: every box at the concept's measured spot (concept px / 6.4), the extra height of a 9:19.5 phone between the top and bottom groups. Home: coin plate, gear button, logo, "survive the swarm" on the ribbon, Sir Loaf 3x on a stone plinth with a name plate, night houses (map props darkened one-two ramp steps, glass lit), critters 2x cut off at the edges, next-unlock card with the mystery slot and segmented star bar, big lowercase "play", four nav tiles with big icons and lowercase words, ! and Ad stickers. Level-up: concept HUD (ring, XP bar with "XP 64/120", timer plate, pause; heart + HP bar with "42/60", coins, kills), gold header + "+1", kit 3b window, cards (kind colour frame and name, 2x icon, one effect line, "3 → 4", 5 pips, New stickers, selected card gold), 34x30 action buttons with 2x icons and count bubbles, "Choose one upgrade." info bar. Renders `docs/phase9/10_v4_*.png` (+ `10_v4_vs_concept.png` side by side), 540x1170, notch 12, 0 off-palette pixels. Still unlike the concept: the logo has no leaves / critter on top, no street sign / lamp glow / manhole, critters are our enemy sprites in their own colours, the plinth is code-drawn (no plinth art)
- [x] Mockups round 3 from the real parts, `tools/ui_mockups_v3.gd` (extends v2; `--size=540x1170` forces a borderless window taller than the screen, the compositor clamps `--resolution` to 1014): `docs/phase9/9_v3_1_home.png`, `9_v3_2_level_up.png`, `9_v3_3_hud.png`, side by side in `9_v3_mockups.png`; 540x1170, notch 12, 0 off-palette pixels in all three
- Leave out what the level-up concept invented: minimap, wave counter, energy bar, objectives panel. Sir Loaf on the home plinth is our sprite (the concept drew a crest)
- Less text everywhere: cards = name + one short line + one change line + pips; kind / rarity / New by colour and stickers; Reroll / Skip / Banish icon-only with count bubbles; home nav = 4 icon tiles with one word; the pickup card shows icon + name only (details in pause). Data gets a `short` text next to `desc`
- Body text is **Inter 900 at 7 px** (owner: smaller); the type scale below is the first draft and gets re-tuned to the kit 3 concepts (smaller everywhere)

### Owner review of v4 (2026-10-13)

- Owner **approved** the plan and approved generating backdrop art, but `docs/phase9/10_v4_vs_concept.png` is "still bad, not as good as the concept". The mockups must reach the concept's quality before any game code changes. Everything on screen should be SpriteCook art, not code-drawn (the plinth, street, lamp glow, sign and logo decorations are code or missing today)
- Why v4 falls short, side by side: (1) the concept's home is a dense, lit night scene (glowing street lamp, lit windows, plinth with lamps, manhole, street sign, foliage, round colourful critters). Ours is flat dark fill with darkened map props, a code-drawn plinth and a big empty band above Play. (2) The logo has a thick dark plum outline, an inner highlight and leaves or a critter on top; ours is a plain Titan label. (3) Hero, tile icons and critters in the concept are drawn as one piece of art at one pixel size; ours mix 1x / 2x / 3x. (4) The level-up world behind the dim reads as a dark tint in the concept and as noisy dither in ours
- [x] Backdrop art (approved; 3 NB2.1 1K calls, 36 credits as estimated, balance 83 -> 47, 2026-10-13): home backdrop (an edit of the home concept `e941feb9` without UI / hero / text: night street, lit houses, lamp, blank sign, manhole, foliage, empty plinth with lamps and a blank plate), logo decorations (3 leaf sprigs + a radish critter), 4 round critters (blue, green, purple, red). Cut by the new `tools/art/home_art.py` into `assets/ui/home/` (a plain palette snap flattened the dark backdrop: it snaps with CIELAB lightness x1.45, sky INK -> NIGHT, then widens 20 px a side and adds 120 rows of sky / road so any phone shape shows only art; `backdrop.json` = plinth anchor). Nav icons re-cut from the kit 3 sheet at a 2x pixel, play triangle hand-pixelled. All four raw kit sheets re-downloaded, sha12 match the log; `check_assets.py` 186 OK
- [ ] No more mockups (owner, 2026-10-13): build the revamp in the game itself on the kit + backdrop art, following the concepts, and check the real screens side by side with them. Order: home (done), level-up, HUD, the rest. `tools/shoot_screens.gd --size=540x1170 --notch=12` shoots the real game at phone size

### Type scale (UI px at the 180-wide base; screens are 3x-6x). Re-tuned to the kit 3 parts and the v3 renders (2026-10-12)

Kit 3 parts are small at 1 art px = 1 UI px (play plate 17 px tall before stretching, nav tile strip 8 px, plates 13-17 px), so the scale is about two steps smaller than the first draft.

| Style | Font | Size | Look | Used for (v3 render) |
| --- | --- | --- | --- | --- |
| LOGO | Titan One | 34 | BUTTER, 6 INK outline, 4 drop, letters tilt and hop | "Mobbed!" |
| BIG_BUTTON | Titan One | 26 | INK, no outline, lowercase, on `play_button` (+ ORANGE play triangle) | "play" (v4, as the concept) |
| TITLE | Titan One | 15 | INK on `lv_header` | Level up!, Paused, Game over, Unlocks, Shop |
| BANNER | Titan One | 14 | colour + 4 INK outline + 2 drop, over the world | Swarm incoming!, Final Swarm!, Survive! |
| NAME | Titan One | 10 (shrinks to 8) | kind / rarity colour, no outline on dark plates | card, item, hero names; toast name 8 |
| NUM | Titan One | 9 | PAPER or BUTTER, 3 INK outline over the world, none on plates | coins plate (10), timer, level badge, gold, kills |
| BAR_NUM | Titan One | 7 | WHITE, 3 INK outline, inside a bar | HP "42/60", "1/3" |
| RIBBON | Titan One | 10 | PAPER, 3 WINE outline, lowercase, on `ribbon_red` stretched to 20 tall | "survive the swarm" |
| NAV | Titan One | 7 (6 for two words) | PAPER, lowercase, on the tile strip | heroes, unlocks, shop, free coins; "next unlock" |
| TAG | Titan One | 7 (XP label 6) | WHITE on `lv_sticker` / `lv_bubble` | New, Ad, +1, charge counts |
| BODY | Inter 900 | 7 | MIST on dark cards, PAPER on strips | the one short card line, nav words, "Next unlock" |
| CHANGE | Inter 900 | 8 | LIME, real → (Titan has no →) | level "3 → 4" under the effect line (v4, as the concept; the stat change is the BODY line "+1 bounce.") |
| WORLD | Inter 900 / Titan | 7 / 12 | plain hits Inter 7 WHITE + 3 INK; crits Titan 12 BUTTER + RED edge | damage numbers, "+32" gold |

Rules: Titan never under 6 (stickers only), Inter never under 7; text on world art always gets an INK outline, on kit plates never; one size per role, picked by style name in code, never by number. SMALL is gone (BODY in MIST does that job: less text means no third body size).

### Shared parts

- [x] Import settings for both TTFs in their `.import` files (antialiasing none, hinting none, subpixel auto, keep rounding remainders, no mipmaps, no MSDF), not set in code (checked by loading them: aa 0, hint 0, sub 1). [ ] test reads them
- [x] `Fonts` rewritten: `TITLE_FONT` / `body()` (Inter as a `FontVariation` at wght 900) and named `LabelSettings` styles (`Fonts.style("NAME")`, cached; `STYLES` table). [ ] Old `BOLD` / `SMALL` / `fitting()` removed once nothing uses them (77 uses left)
- [x] `Fonts.fit(label, width, min_size)`: shrinks a style step by step until the text fits, then wraps, never clips
- [x] `Fonts.draw(ci, text, pos, style)`: drop shadow, outline and fill for `_draw()` code. [ ] Move hud.gd, run.gd, level_card.gd, icon_tile.gd... to it
- [ ] `assets/ui/theme.tres`: default font BODY at 7; Label line spacing checked for Inter (taller ascent than the 5x7)
- [ ] Glyph pre-warm at boot for both fonts at the sizes in use (avoids a hitch the first time a size is drawn on a slow phone); check the font atlas memory at 6x
- [ ] Optional: subset Inter to Latin + the symbols we use (876 KB -> ~100 KB); OFL allows it, Inter has no reserved name

### Per component

- [ ] `PixelButton`: kit 3 plates (`play_button` gold, `button_orange`, `button_off` disabled, pressed = 1 px sink, no separate art); label through `Fonts.fit` (no more fallback to the 5x7); text centred on the face including the sink; with `art`, icon left + text; toggle rows; check every button for width at 3x
- [ ] `PixelPanel`: `panel_dark` (windows) and `plate_dark` (rows, cards, toasts, the coin plate) replace the riveted kit 1 `window` / `row` in menus; inner padding from the style's line height instead of hard-coded 10 px rows
- [ ] Home nav: `nav_*` tiles (icon on the face, BODY word on the strip), `alert` on Unlocks, `ad_sticker` on Free; `gear_button` top right; next-unlock card = `panel_dark` + `icon_button` slot + `star` + `track_dark`/`fill_gold`
- [ ] Recolourable kit 3 frames: `icon_face` (kind / rarity frames, action buttons, HUD build strip) and `fill_gold` (XP gold, HP red, pips) through UiArt's ramp swap; no code-drawn plates left (`plate()` / `notched()` from the mockups stay in tools/)
- [ ] `PixelTitle`: rebuilt on the TTF (it cuts glyphs from `bonk.png` today): per-letter Labels or `draw_char` with tilt and hop for LOGO, TITLE on the ribbon. The band colour across the letters' top rows has no TTF equivalent; drop it or clip-draw a second fill (decide on the render)
- [ ] `LevelCard` (level-up, beacon, merchant): layout of mockup 1 (kind sticker on the top edge, NAME, two lines of BODY at most, CHANGE line that shows as many changes as fit, never cut; pips under the badge). Beacon cards: big value in NAME/BIG_NUM; merchant price chip in NUM
- [ ] `ActionButton`: word in BUTTON 10, charge bubble in TAG
- [ ] `IconTile`, `PixelTabs`, `CoinPlate`, `ChallengeRow`, `MapCard`, `FaceTile`, `AdButton`, `ConfirmPopup`, `UnlockPopup`, `BuildView`, `ThumbStick` hint: move to styles; check each at 1x and 3x for fit
- [ ] Splash (AVIHAREZ letters, the "A" badge): Titan One letters popping in; keep caps here (it's a logo)

### Per screen

- [x] Home (2026-10-13), after the concept, side by side in `docs/phase9/11_home_vs_concept.png` (540x1170, notch 12, 0 off-palette pixels; fits a 338 px window too): `HomeScene` (backdrop, hero 2x on the plinth with the name on its plate, 4 critters 2x hopping), `CoinPlate` on `plate_dark` with "1,246", `KitButton` gear, `LogoTitle` (per-letter Titan, NIGHT outline + SHADE rim, lit top / shaded foot shader, letters stretched 0.92 x 1.3 like the concept's condensed lettering, leaves + radish 1x), ribbon + "survive the swarm", `NextUnlockCard` (panel, mystery 2x or the ready reward, star + `seg_track`, progress), "play" + triangle, 4 nav tiles (heroes / unlocks with "!" / shop / free coins with Ad, greyed when no ad can pay). Three groups: top under the cutout, bottom on the edge, hero group halfway. New `KitButton` (any kit 9-slice part + 2x art + styled label + sticker). `TitleScene` no longer used by the game (only the old mockup tools)
- [ ] Settings window, QUIT? popup
- [ ] Heroes, Maps (goals panel), Unlocks (detail panel + grid), Shop, Toggler: titles, detail panels, prices, "Collected 7/19"
- [ ] HUD (mockup 1 right): Lv on the XP bar, HP number inside the bar (drops the line under it), BIG_NUM timer, NUM gold/kills, banners in TITLE (Swarm incoming!, Final Swarm!, Survive!), toasts and the pickup card in BODY with `Fonts.fit`, boss name on the boss bar
- [ ] Level-up / beacon / merchant panels, pause (build details, stats grid, Give up twice), revive, game over (stat tiles, coins, closest unlocks), unlock popup, first-run "Drag anywhere to move"
- [ ] World text to a UI-space overlay (`WorldText`, a pooled Node2D in a CanvasLayer between the world and the HUD, positions = (world - view origin) x world_zoom): damage numbers (plain hits Inter 900 at 8 with INK outline, crits Titan 14 with a RED edge and "!", gold "+5"), chest and merchant price tags, beacon/altar labels. The 3x5 tiny digit atlas goes away unless the crowd render reads worse (compare at 300 enemies before deciding)

### Text pass (mixed case)

- [x] Data (2026-10-13, 98 files, every changed line checked to differ only in casing and the closing full stop; "Final Swarm" kept capitalised). Was: one subagent per group, each returns a diff and a list of anything unclear: (1) characters + challenges + shop + rules rarity names, (2) weapons, (3) tomes, (4) items, (5) interactables + enemies + maps. Names in Title Case ("Grandma's Soup Recipes", "Band-Aid"), descriptions and challenges in sentence case with a full stop, keep HP / XP / KO / AoE as caps, simple English (brief). 230 shown strings: 86 `name`, 137 `desc`, 3 hero `role`, 4 rarity names. Ids, colour names, tome `symbol` grids and `_doc` notes untouched. Check each diff before accepting
- [ ] Code strings: ~415 capital literals in scripts (most in run.gd 75, action_button 27, splash 22, main_menu 16, map_layout 16; many are ids, not shown text), plus 3 `to_upper()` calls (toggler, item_system, fake_ad_backend). Shown text to mixed case; brief's player-facing names stay (Beacon, Manual)
- [ ] Shorter words where space is tight: stat short names in data ("Dmg", "CD", "Area") used by the CHANGE line, so adding content still needs no code

### Progress 2026-10-13 (session 2)

- [x] Level-up panel (`LevelUpPanel`, `LevelCard` and `ActionButton` redrawn on kit 3b; the dim is a palette tint under the HUD): `docs/phase9/12_level_up_vs_concept.png`
- [x] HUD (two concept rows, kit pause, kit build strip / item frames, name-only pickup card, BANNER text): `docs/phase9/13_hud_vs_concept.png`
- [x] Font tests: `tests/font_rules.gd` (each string in its font, fits by measured width; level-up card rule: a two-line name leaves one body line)
- [x] Shared parts: `PixelButton` on the recoloured `lv_frame` with Titan / Inter labels, `PixelPanel` windows on `lv_window` and rows on `plate_dark`, `HeaderTitle` (gold `lv_header` + TITLE) on every panel and menu screen, theme font Inter 900 at 7 (`assets/fonts/inter/inter_900.tres`), `Fonts.BOLD` / `SMALL` now point at Titan / Inter
- [x] Code-string text pass (two subagents, scripts/run and scripts/ui + core; every non-casing change reviewed; tests updated)
- [x] World text in UI space: `DamageNumbers` in the UI layer (HIT / CRIT / NUM_WORLD), chest prices and Shop / Risk labels on the dark plate; 3x5 digit atlas gone
- [x] Menu screens: hero name in Titan, tiles on `lv_frame` by state, kit "!" and stickers, dark plate bottom bar; splash name in Titan (SPLASH style)
- [x] `tests/test_text_fit.gd` (labels on screen, inside their panel, no overlaps; self-check that it catches both). Every shot 0 off-palette pixels (`docs/phase9/15_other_screens.png`; fixed a GRAY-modulated rim on locked tiles)
- [x] Stress test (300 enemies, full build, Final Swarm, low HP, all effects; 540x1014 window): 75.0 fps vsync (1% low 67.4, 0 missed vsync frames), 353.9 uncapped; phase 8 was 75.0 / ~350
- [x] Kit 1 parts replaced (owner: keep the hero at 2x): toggles = `hud_track` + LIME `hud_fill` + `lv_frame` knob (`UiArt.toggle`); AdButton and role tag = `lv_sticker` (`UiArt.sticker`); map card = `lv_card` (gold when picked); game-over stat tiles = OCEAN `lv_frame` + HUD icons; build slots / empty slots / selection = `lv_frame` (no dashes); hero stat pips = `lv_pip_*`; padlocks = kit 3 padlock; unlocks bar = `UiArt.bar` (`hud_track`); price coin = `hud_coin`. Test `test_no_old_kit_parts_in_screens`. Shot `docs/phase9/16_kit1_replaced.png`, 0 off-palette
- [x] Deleted (owner OK) the 31 unused kit 1 / kit 2 parts and `Glyphs`; kit 2 `key`, `stick_base`, `stick_knob` stay (HUD key count, joystick). Shop icons for banish / reroll / skip now `lv_x` / `lv_die` / `lv_ffwd`, Toggler `gear`. Cutter re-run reproduces `assets/ui/` byte for byte (49 parts). Debug APK installed on the Xiaomi 15T (2026-10-13), home screen checked
- [ ] Left: `TitleScene`, `PixelTitle` and the bonk / pixel fonts only used by the old mockup tools now (remove with them); glyph pre-warm and Inter subsetting not done; code-drawn bits left: item detail icon frame, section rule lines; owner phone check

### Owner fixes (2026-10-13, session 3)

- [x] Kit parts as drawn: kits 3 / 3b are drawn on an ~8 source px grid, not 16 / 13, so the old cut lost the light rims, rivets and the nav tiles' strip bevel. `tools/art/ui_kit.py` now also cuts them at FINE = 8 with a lightness-weighted snap (FINE_L 2.5). Shipped from it: `nav_*` (39 x 44 tile, label strip), `play_button`, `icon_frame` (the kit's square frame, any colour), `act_reroll/skip/banish` (+ pressed), `coin_nav` (coin at scale 11). The other 49 parts are byte-for-byte the same
- [x] Home: nav tiles are the kit tile at its own size (39 x 50 with the drop), icons inside the face at 1x (pigeon, kit padlock / sack / coin), labels in the strip; "play" and "1,240" centred on the caps (`Fonts.cap_y`)
- [x] Heroes tile opens a browse-only hero screen (`HeroScreen.new(save, true)`: details, no Next); PLAY still goes hero -> map
- [x] Beacon bonus ("Pick a bonus") and merchant use `LevelUpPanel` (same header, window, cards, info bar); bonus has no button row (`rows` false), merchant's Leave sits in it; "Your gold: N" in the info bar
- [x] Popup text smaller: `CARD_NAME` (Titan 8, shrinks to 7) and `CARD_BODY` (Inter 6) on level-up / bonus / merchant cards, pickup card, unlock popup, pause details (name, kind line, desc, Dmg / KO) and pause stats; value on bonus cards 16 -> 12, change line 8 -> 7
- [x] Damage numbers smaller: HIT Inter 6 (2 px outline), CRIT Titan 9, words / gold `POP` Titan 8 (HUD's NUM_WORLD unchanged)
- [x] Weapon / manual / item / hero backgrounds on the kit `icon_frame` (level cards, HUD strip and items, pickup card, pause build and details, unlocks / shop tiles, hero tiles, `ContentIcon`, PixelButton art); icons a step smaller (2x 14 on cards and tiles, 14 in pause slots, 13 in 18 px frames, 11 in the HUD)
- [x] Level-up Reroll / Skip / Banish drawn with the kit's own buttons (disabled / banish-armed fall back to the plate)
- [x] Tests: `test_kit_parts_as_drawn`, `test_hero_screen_browse_only`, bonus / merchant panel checks; 2204 checks pass. Shots 0 off-palette (17 screens). Stress 300 enemies: 75.0 fps vsync, 1% low 66.8, 0 missed frames
- [x] Owner OK (2026-10-13): Inter 6 on popup cards and damage numbers; CLAUDE.md and BRIEF.md updated
- [x] Home (owner, phone): nav tile labels and the next-unlock title Titan 7 -> 6 (hero plate name stays 7), progress text 9 -> 7, a ready reward at 1x 16 px in its slot (shrinking it to 11 px broke the clock icon); checked on the Xiaomi 15T
- [x] In-run HUD (owner): weapon / manual strip, item row and pickup card back on the plain `lv_frame` plate with 12 px icons (cards, pause and menus keep `icon_frame`)
- [ ] Not switched yet (still the coarse cut): `lv_window`, `lv_card`, `lv_header`, `lv_sticker`, `plate_dark`, `panel_dark`, HUD tracks; their fine cuts look close but have stray pixels on the dark faces. Buttons / toggles keep `lv_frame`
- [x] Pigeon cage (owner): `hide_when_unlocked` on `data/interactables/pigeon_cage.json` ("turbo_pigeon") leaves the cage off the map once Turbo Pigeon is available or owned; with no cage, elites drop no key (already gated in `Run._elite_killed`). Validated in `game_data.gd`; test `test_no_cage_or_key_once_the_pigeon_is_unlocked`
- [x] Home (owner): no hero name over the plinth; backdrop regenerated without the street sign and the plinth's name plate (SpriteCook edit `c52e2ecc`, 12 credits), `home_art.py` re-measured (plinth 68,147) and its right edge band fixed (no foliage bar). 2208 checks pass

### Found while building the home (2026-10-13)

- The hero is 2x (48 x 52) to keep one sprite scale with the critters and nav icons; the concept draws Sir Loaf about 1.4x bigger. 3x would match the concept's size but break the one-scale rule: owner's call
- The logo's leaves and radish are 1x: at 2x they are twice the concept's size and cover the top bar
- The backdrop's moon lands beside the ribbon (the concept has it by the logo); it is part of the backdrop art
- The street sign is blank (no text in art); the concept's says "SUBURBIA DR"
- `Meta.progress_text` and `kind_name` still return caps ("DONE", "BEST", "HERO"): text pass
- Settings window, quit popup and every other screen still use the old pixel fonts and kit 1 plates (next: level-up, HUD, then the rest)

### Fit and overlap fixes

- [ ] Known now: the v3 home leaves a band of empty sky between the ribbon and the town (the concept fills it with a bigger hero on a plinth and critters; the title scene would need that art); pickup card text past its frame; long Titan names on cards ("Coupon Clipping" touches the edge at 12); chest price "SHOP 32" in the world runs into the merchant; damage numbers stack into a block in crowds; the map screen panel 6 px past the list on a 338 px window (Found, phase 8)
- [ ] Every text box sized from its text (`Fonts.fit` or measured), no hard-coded text widths

### Tests

- [ ] Update: `test_ui_polish.gd` font coverage (Bonk/5x7 -> Titan One/Inter: every data string and every shown code string is in the font it's drawn with; title-font strings have no → ♥ ★ ✓), `test_ui_release.gd` (PixelTitle-matches-.fnt test goes; strings like UNLOCKED!, TOTAL, BEACON BONUS -> mixed case), `test_data.gd` (12 caps strings), `test_icons.gd`, `test_select_screens.gd`, `test_meta.gd`, `test_audio_fx.gd`, `test_ui_art.gd`, `test_ads.gd`, `test_export_filters.gd` (the .ttf imports ship; no raw font reads)
- [ ] New `tests/test_text_fit.gd`: build every screen and panel at x1 and x3 (and a 338 px short window) and check that every visible Label sits inside its panel and no two text boxes overlap; every data name fits a card at the NAME minimum size; every desc fits the card in two lines. Mutation-check it on the known overlaps
- [ ] New: font import settings are AA off (headless can't render; the render check is the next item)
- [ ] `tools/shoot_screens.gd` + a palette scan of every shot (0 off-palette pixels in text) as the visual check; owner phone check after
- [ ] Stress test (300 enemies, full build, all effects) with the world text overlay: compare with phase 8 (75.0 vsync / ~350 uncapped)

### Docs (after the owner approves the wording)

- [x] (2026-10-13) CLAUDE.md "UI design direction" and the copy inside BRIEF.md; BRIEF.md asset table (fonts), logo line, damage numbers line, phases list (revamp = 9, release prep = 10)

## Enemy redesign: one family of mutant critters (owner request 2026-10-13)

- [x] "Creature art rules" in docs/BRIEF.md (Assets) + short version in CLAUDE.md
- [x] SpriteCook sheet 1 (Blob, Skitter, Spitter, Bloater), 12 credits, owner-approved, logged
- [x] SpriteCook sheet 2 (Chomper shut + open jaw, two eyeball spares), 12 credits, owner-approved, logged
- [x] Halve + clean by hand: `tools/art/critters.py` holds the final grids -> `assets/enemies/*.png` + sidecars (loop, blink, poses, origin)
- [x] Closed-eye blink frame per critter (hand-pixelled from the sprite); Gnat hand-pixelled (2 wing frames + blinks)
- [x] Enemy data: sheets + role colours (BLUE, PURPLE, RED, GOLD, PINK, PAPER); `assets/enemies/*.json` in both export include filters
- [x] Motion in the render path (`EnemySystem.render` + `SpriteBatch.push_xform`, red flash in `batch_flash.gdshader`): hop / bob with squash and stretch on own phase and rate (rate from speed), facing + lean on turns, blink 2-6 s, hit squash, Chomper crouch + shake then stretch along the charge (open jaw), Bloater swell + red flash, Spitter puff + recoil; Reduce effects tones squash down and stops shake
- [x] All motion numbers in `data/rules/creature_motion.json` (per-enemy overrides under "types")
- [x] Tests: critter sheets load with blink frames, Chomper charge pose, push_xform basis / pivot / red, motion (phases, hop rate, facing, blink, hit squash, three telegraphs, reduce effects), no enemy code-drawn (Overdue Bill named exception); 2248 checks pass; asset check 0 failed
- [x] Shots: `tools/shoot_screens.gd --only=crowd`, old vs new side by side at 540x1170 (`build/review/critters/`)
- [x] Captures: `tools/motion_capture.gd`, GIFs per enemy + crowd + crowd with reduce effects (`build/review/critters/`)
- [x] Stress, 300 enemies, full build, Final Swarm, low HP, 540x1014: vsync 75.0 fps, 1% low 67.2, 0 missed (was 75.0 / 66.8-67.4). Uncapped, alternating old / new on the same machine: old ~295 fps (logic 1.70 ms), new ~275 (logic 1.95 ms). The owner's Steam game was running during the uncapped runs, so they are not comparable with the recorded 353.9
- [x] Blink made easier to see (0.2 s) + close-up blink capture (`motion_blink_closeup.gif`)
- [x] Skitter walk cycle from SpriteCook (owner request; 20 credits): 4 frames, legs step with the hop (stop when it stands), hop cut to a small bob; closed eyes found per frame
- [x] Spitter mouth from SpriteCook (owner request; 20 credits): walks mouth shut, puffs, mouth pops open on the spit and eases shut (half-open frame)
- [x] Owner review of the new look (shots + GIFs): approved 2026-10-13
- [x] Removed `assets/creatures/`, `tools/creature_export/` (+ its .gitignore lines and the export include filter); BRIEF asset sources table, setup note and the two open items updated; data/README enemies row; old rows struck in ASSET_LOG
- [x] Removed the six code-drawn enemy masks; "shape" / "color" dropped from those six enemy files. Validation: an enemy needs a "sheet", or a known "shape" + "color" (only the Overdue Bill). Death particles and the spit puff take the sprite's main body colour (`EnemySystem.body_color`)
- [x] Tests: no enemy code-drawn and no leftover "shape" (Bill and the boss excepted), body colour from the sprite, an enemy with no art fails validation; 2263 checks pass; asset check 166, 0 failed
- [x] Stress after the clean-up (300 enemies, full build, Final Swarm, low HP, 540x1014, machine idle): vsync 75.0 fps, 1% low 67.1, 0 missed; uncapped 280.3 / 280.2 (logic 1.88 ms). The old build measured ~295-313 on this machine earlier the same day; the recorded 353.9 is not reproducible today
- [ ] Mega Mole vs the rules: owner decides (see Found)

### Found during the enemy redesign

- Blob and Skitter are 21 px tall with their antennae, the Chomper 21 px wide: 1 px over the 12-20 range. The Gnat is 11x8 with its wings out (body 7x6)
- The palette has no dark magenta: the Chomper is PINK with WINE shading (pink-berry), clearly apart from the red Spitter and the purple Skitter
- In a dense crowd the orange hero gets lost among the orange Bloaters (crowd shots)
- The first motion version cost +0.88 ms per frame for 300 enemies (dictionary reads in the loop); now one pass in render with cached numbers, +0.19 ms in the headless benchmark
- SpriteCook was reconnected to another account (`lurch_brim_speller`, free tier); the two animations used its 40 credits, balance 0. The critter sheets and all older assets are on `tarnish_lived_cofounder` (11 credits left)
- Spitter animation frames 1-2 came back with the mouth interior cut out by background removal (holes); only frames 3-4 are used. The shut / half frames have a taller eye than the wide-open sheet 1 frame, so the eye grows a little for the ~0.15 s the mouth is wide open
- Mega Mole: outline 84% INK (white claws, toes and helmet shine sit on the edge without one); small squinting eyes, not the big-eyed family trait. Sir Loaf: 22 px tall (rule ~24), outline 74% INK
