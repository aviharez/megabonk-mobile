# Tasks

## Carried over from finished phases (archive: docs/TASKS_ARCHIVE.md)

- [ ] Glyph pre-warm at boot for both fonts at the sizes in use, and the font atlas memory at 6x (phase 9; worth doing in Release prep)
- [ ] Optional: subset Inter to Latin + the symbols in use (876 KB -> ~100 KB; OFL allows it) (phase 9)
- [ ] docs/BRIEF.md "Update 1" and the concept PNGs in docs/ui/ still show the INK drops that kit v2.2 removed; update them when the look is settled (kit v2.2)
- [ ] Owner decision: Mega Mole vs the creature rules (outline 84% INK, small squinting eyes; Sir Loaf 22 px tall, outline 74% INK) (enemy redesign)
- [ ] Phone fps numbers from phases 6 and 8 (owner ran both on the Xiaomi 15T on 2026-10-15): asked for in phase 14, to be written into docs/TASKS_ARCHIVE.md

## Phase 16: Tutorial and first session (docs/BRIEF.md "Update 1", 2026-10-18)

Prompt: a fresh save goes Splash > tutorial run (Sir Loaf, Suburbia, Danger 1, no menu); one short line per step, each moving on when done; shorter and kinder run, weaker Mega Mole, one free revive, no ads; Skip on Paused; a real Danger 1 win minus boss times / HP / Final Swarm boss stat / leaderboard scores; guided Home (claim a quest, buy Fireworks); Sewers on Danger 2 ("unlock_danger"); Sir Loaf's Getting Stale from 10% (+2%/min to 24%), matrix sim within ~5 points or max HP 135; cloud save doesn't block the tutorial. Done = flow, 95% of 40 typical-bot tutorials won, post-tutorial state checks, existing saves untouched, Skip, campaign_sim starts with the tutorial, docs/BALANCE.md early milestones + Sir Loaf matrix, tests per rule, every step shot at 540x1170 (0 off-palette, text fit), stress within 5% of phase 14.

### Brief and data
- [x] Brief: Phase 16 added to "Update 1" (Release prep is Phase 17), First session summary in New systems, notes where the old stick and altar hints went
- [x] `data/rules/tutorial.json`: steps, timings, run rules, boss modifiers, free revive, counting rules, Home guide steps; validated in GameData
- [x] Maps: optional "unlock_danger" (Meta.map_state / map_hint / district_title, GameData); sewers.json = 2
- [x] Sir Loaf: Getting Stale "start_reduction" 0.10, 0.02 a minute, cap 0.24 (data + Passives + GameData)

### Tutorial run
- [x] `Tutorial` (scripts/core/tutorial.gd): who sees it, run options, counting rules, the Home guide state; save key "tutorial"
- [x] Splash > tutorial run on a fresh save (no menu, no wait for sign-in); existing saves go to Home
- [x] Run: tutorial mode (rules, no Final Swarm, no waves or merchant, kinder Danger 1, weaker Mega Mole, free revive, no ads, no leaderboard scores, stripped stats), step flow with the line plate, pulsing arrows, chest / beacon placed near the hero, the Level Up card line, the ghost stick and altar hint folded in
- [x] Skip tutorial on the Paused screen (ends it, goes to Home)
- [x] Tutorial result screen: no AD x2, no interstitial, Continue to Home
- [x] Bot follows the steps; tutorial mode in campaign_sim (`tools/balance_sim.sh OUT tutorial`): typical 40/40 won, good 40/40, median 4:05 (3:18-6:11); every save can buy Fireworks after the guide's claim (min 40 coins)

### Home guide
- [x] Guide over Home: claim the first quest reward (Quests rail, then Claim), buy Fireworks (Collection tile, then Buy), then hand over; no ads while it runs
- [x] Cloud save: a winning cloud save at the tutorial's end replaces the local save (and ends the guide)

### Balance
- [x] campaign_sim plays the tutorial as run 1 (milestones: tutorial won, Fireworks bought, first win after the tutorial); balance_report tutorial section; docs/BALANCE.md "Phase 16" (8 campaigns to 40 runs + the 14-save early probe)
- [x] Matrix sim for the three heroes: Getting Stale from 10% alone 25% vs 34% / 32%; with max HP 135 (shipped) 28% vs 34% / 32% (4-6 points: borderline "about 5"); docs/BALANCE.md

### Done check
- [x] tests/test_tutorial.gd (who sees it, splash, old saves, run setup, every step in order, free revive, folded hints, Skip, result screen, counting rules, scores and achievements, cloud save, ads, the guide, an end-to-end splash > tutorial > guided Home); test_play_flow (Sewers on Danger 2, default 1), test_run_flow (Getting Stale), test_data (bad unlock_danger / start_reduction / tutorial.json). Full suite 3631 checks, 0 failed; FLOW OK; 187 assets pass
- [x] Every tutorial and guide step shot at 540x1170 (`shoot_screens.gd --only=tutorial`: 9 steps, Level Up line, pause with Skip, result, 4 guide states = 16 shots), 0 off-palette pixels, reviewed; test_text_fit `test_tutorial_steps_fit` checks the same states
- [x] Stress (300+ enemies, full build, Final Swarm, low HP, 540x1014, 2026-10-19): vsync 75.0 fps, 1% low 70.6, ~304 on screen, 0 missed vsync frames; uncapped 315.5 fps (phase 14: 75.0 / 67.9 / 294.4). Alternated with the phase 14 commit: 75.0 / 75.0 fps, 1% low 69.3-69.7 vs 69.5-69.9, logic 3.52-3.83 vs 3.40-3.59 ms (noise). Headless logic: 3.12-3.14 vs 3.08-3.15 ms

### Owner changes after the phase (2026-10-19)
- [x] Tutorial a little harder: enemies HP / damage / spawns x0.8 / 0.7 / 0.8 -> 0.9 / 0.85 / 0.9, boss 45% / 60% -> 60% / 75%, altar step 2:30 -> 2:15. 40 tutorials per player: typical 40/40, good 40/40, typical median 4:44 (was 4:05); tried and dropped: altar at 2:00 (typical 38/40, at the 95% line), boss 50% HP (no change from easy)
- [x] Danger 3 not early: the tutorial no longer opens map progress (tutorial.json "not_counted" "map_progress": true; `Meta.commit_run(..., opens)`): Danger 2 opens on the first real Danger 1 win. Campaigns to 40 runs: Danger 3 opens at median run 20 (typical) / 11 (good), was 2 / 2 (phase 14: 16 / 7); first win after the tutorial median run 2; early probe 10 of 14 by run 3. Brief, tests, docs/BALANCE.md updated
- [x] Kept: the portal step, Sir Loaf at 135 HP
- [x] Home guide line moves above the Unlock rail button while it shows (it covered its label; caught by the stricter guide check in test_text_fit, which now checks each open screen like the big-numbers check)
- [x] Tests 3634 checks, 0 failed; FLOW OK; 16 tutorial shots at 540x1170 shot again, 0 off-palette pixels, reviewed
- [x] Review prompt on the phase diff (2026-10-20): no merge blockers. Departs from the brief: the tutorial's typical length is 4:44, not "about 4 minutes" (the owner's harder numbers; run timer 5:00, clock stops at 0:00). Tests again 3634 checks, 0 failed

### Found during phase 16

- The splash test used the Save autoload, and the desktop save has 0 runs, so it went into the tutorial and left a run scene that ate taps in later tests. Splash now takes a `save` node (tests pass their own)
- Sim bot: standing on a beacon or the altar, its wander term walked it off again (the charge drains when you step out). In the tutorial it now stays put on the step's object; other runs are unchanged so phase 14 numbers stay comparable
- The tutorial adds a last "Walk into the portal" step after beating Mega Mole (the brief lists steps up to the boss; the run has to end somewhere, and the portal is how a won run ends without the Final Swarm)
- The tutorial run has no Final Swarm (its clock stops at 0:00), so Gary's "60 s in the Final Swarm" and the Final Swarm leaderboard can't come from it
- Mega Mole's rocks never scaled with Danger (enemy shots take a flat damage); the tutorial's weaker boss scales them through MegaMole.rock_mult only
- The Level Up panel's `hint` is never drawn (kept for tests); the tutorial's card line uses the panel's `info` line instead (the cards move down for it, as for the merchant)
- With the tutorial opening Danger 2 on run 1, Danger 3 opened at a median run 2 (phase 14: 16). Owner: the tutorial doesn't open Danger 2 any more (above)
- The bots rarely die in the tutorial whatever the boss numbers (0-3 revives in 80 runs), so its difficulty is hard to read from the sim; a phone playtest will tell more
- A tutorial that pays under 30 coins (after one quest claim) passes over the Home guide's Fireworks step; the sims never saw it (least was 38), but a scripted short run in the shots did
- Screenshots and the windowed stress test need the screen on: Godot draws nothing while every display is off (DPMS), so tools/shoot_screens.gd waits forever on frame_post_draw

## Phase 14: Balance and big numbers (docs/BRIEF.md "Update 1", 2026-10-17)

Prompt: housekeeping (archive, stale items, phone fps); one headless sim that plays a fresh save forward for all three heroes on every Danger and buys like a player; tune data/ only to the targets (Mega Mole on run 2-3, first Early unlock bought in 3 runs, no weapon in >40% of wins, win rate falls per Danger and D5 needs a good build, quests 30-40% of coins, hours to everything); big numbers in the UI (one number-format helper, short form in fixed spaces, the seven known overlaps, a big-numbers case in test_text_fit, shoot_screens --big). Done = docs/BALANCE.md report, targets met or explained, numbers only in data/, --big shots at 540x1170 clean and 0 off-palette, tests pass, stress within 5% of phase 13.

### Housekeeping
- [x] Finished phases 0-13 (+ audio remake, kit v2.2, enemy redesign) moved to docs/TASKS_ARCHIVE.md; stale unchecked items closed there with the reason in brackets; four still-useful ones carried over above
- [ ] Phone fps numbers from phases 6 and 8: asked the owner (no answer yet)

### Balance
- [x] `scripts/debug/bot_picker.gd`: "typical" and "good" card / beacon pickers (no weapon preferred by name); Run option `bot_picker` (reroll while charges last); sim bots also use Town objects and step out of Mega Mole's warning zone
- [x] `scripts/debug/campaign_sim.gd` (+ scene): campaign (fresh save, claims quests, collects Patrol, buys unlocks / Town / shop, chases the challenges a normal run can't do) and matrix (hero x Danger from a fresh or maxed save) modes; `tools/balance_sim.sh` runs them in parallel; `tools/balance_runs.py` one line per save
- [x] `tools/balance_report.py` -> docs/BALANCE.md (per hero, per weapon, per Danger, milestones, hours to everything)
- [x] Baseline numbers, then tuning in data/ only: Danger 1 enemy HP and damage x0.9; Danger 5 enemy HP 2.3 -> 2.5, damage 1.75 -> 1.85; Garden Gnomes damage and knockback down (count unchanged); Stinky Socks, Hot Coffee, Rubber Duck up (Duck level 1 text now "Bounces 3 times."); gem cap 400 -> 150; challenge texts with separators
- [x] XP gems piling up round the hero (first-pass note, phase 8): gem cap 400 -> 150 (merged gems keep their XP)
- [x] Fix found by the sim: EnemyShots.update read past the pool when a hit cleared it (test in test_pools)
- [x] Final campaign + matrix on the shipped numbers written into docs/BALANCE.md (targets met or explained there)

### Big numbers
- [x] One number-format helper, `Num` (scripts/ui/num.gd): `full` (9,999,999) in menus, `short` (12.3K, 1.2M, 5 chars) in HUD, stat tiles, badges, prices on cards, `tiny` (4 chars) for damage numbers
- [x] Game Over coins vs AD x2; Pick a District / Hero title vs coin plate; item stack 10+ on the pickup card and the item row; damage numbers in crowds (short form + hits on one spot add up); Game Over stat tiles at 6 digits; Home coin plate vs Town bar at 7 digits; Danger rule line vs New! stickers. Also: the Final Swarm banner moves below the item card and toast
- [x] Big-numbers case in tests/test_text_fit.gd (menus, run HUD, pause, merchant, Game Over, damage numbers; drawn-text overlap and clip check, checked against the old layouts); `--big` in tools/shoot_screens.gd (`scripts/debug/big_numbers.gd`); 39 shots at 540x1170, 0 off-palette pixels, reviewed

### Done check
- [x] Tests: 3490 checks, 0 failed (on the final data); flow check OK; 39 `--big` shots at 540x1170 shot again on the final data, 0 off-palette pixels
- [x] Stress (300+ enemies, full build, Final Swarm, low HP, 540x1014, 2026-10-17): on the final data: vsync 75.0 fps, 1% low 67.9, ~305 on screen, logic 3.55 ms (+2.6%); uncapped 294.4 fps (phase 13: 75.0 / 66.8 / 3.46 ms / 270.3)

### Found during phase 14

- Bots dodge by local push, so the weapon that keeps enemies off the hero (Garden Gnomes) is worth more to them than to a person; its high share of wins is partly that, partly that runs which get it early live long enough to fill every slot
- In a fresh save only the four start weapons can be taken (three per run), so each is in 40-70% of early wins whatever the numbers; the 40% target is judged on the everything-bought matrix
- [x] Golden Toilet lowered from 10 to 7 elites in one run (owner, 2026-10-18). Changed in data, the brief and test_meta. Before the change it was bought after run 100 for a typical player, with Lottery Tips waiting on it. 40-run check: now bought on runs 1-33 (good: 6, 6, 6); good saves do everything by run 34-35 instead of 87-107; the typical tail is now Angry Neighbor / Cursed Diary and Danger 5 (docs/BALANCE.md). Elites keep spawning after 8:00, so long Danger 1 runs reach 7-8
- Sir Loaf wins least (matrix 24% against 34% / 32%); Sharp Feathers and Faulty Toaster win least when taken. No target, noted in docs/BALANCE.md
- Flow check and screenshot runs print "N resources still in use at exit" (same on the last commit; noted in phase 11)
- Quests are 31-33% of coins over the first 20 runs but ~11-14% over a whole save: milestones run out while Patrol grows with the Town
- The Quests daily list overlapped the points window only in the test when switching tabs at once (0.5 s wait in the test); not seen on screen
- The "Coop" pin on the Town map is partly off-screen at the default scroll at 540x1170
- TASKS.md phase numbers: Google Play Games was built as "phase 14" and is now Phase 15

## Phase 15: Google Play Games (docs/BRIEF.md "Update 1", 2026-10-15; built as "phase 14", renumbered when the brief added Balance as phase 14 on 2026-10-17)

Plugin (owner approved 2026-10-15): GodotPlayGameServices 3.4.0 (MIT), not the 3.2.0 the brief named (3.3 fixed release builds with ProGuard rules). Vendored trimmed in `addons/GodotPlayGameServices/`; see docs/PLUGINS.md.

- [x] Plugin researched (activity, license, open issues, Kotlin source of the snapshot / sign-in calls), owner OK
- [x] Vendored: AARs, plugin.cfg, LICENSE, patched `export_plugin.gd` (no autoload, so project.godot isn't rewritten; an empty game id leaves the plugin out of the APK). The GDScript nodes and icons aren't vendored: `GpgsBackend` talks to the native singleton
- [x] `PlayGames` autoload over a `PlayGamesBackend`: `GpgsBackend` with the plugin, `FakePlayGamesBackend` in debug builds (pretend account in `user://fake_cloud.json`), the inert base backend in release builds without it (nothing called, Settings says Not available)
- [x] Sign-in: silent at start, interactive from the Settings card; nothing in the game waits for it
- [x] Cloud save: the save JSON is one snapshot. After each sign-in the cloud save is read first; the save with more playtime stays (then runs, then coins), one line on Home says which. A fresh install never uploads before that check; a cloud save from a newer build is never loaded or overwritten; a winning cloud save waits for the end of a run. Uploads on every run end and on app pause, progress value = playtime ms (the plugin's HIGHEST_PROGRESS policy keeps the same rule on a conflict). Timeouts on every request (the plugin stays silent on some failures)
- [x] Save: new `playtime` key (seconds in runs, added by `Meta.commit_run`); `Save.replace_data()` migrates and fills a cloud save like a file, keeps this device's settings, refuses newer versions
- [x] Achievements: the 19 unlock challenges + 22 milestone quests, ids in `data/rules/play_games.json` (empty until created; empty ids skipped), unlocked once each per session after sign-in, run end and restore; a failed unlock retries
- [x] Leaderboards: "Longest Final Swarm" (final_swarm_seconds, ms, weekly) and "Fastest Mega Mole" (boss_defeated_at, ms, smaller is better, only on a map whose boss is Mega Mole; `Meta.map_boss_id`). Scores from runs while signed out are sent at the next sign-in that session
- [x] Settings rows (docs/ui/settings.png): "Google Play Games" heading, status card with the hero face (Signed in / Not signed in, tap to sign in / Not available), Achievements and Leaderboard buttons (flat while signed out). 0 off-palette pixels in both shots
- [x] Data validation for play_games.json in GameData
- [x] Tests: `tests/test_play_games.gd` (113 checks: backend choice, inert = untouched save, silent + Settings sign-in, sign-in timeout, round trip between two installs, more playtime wins both ways, fresh install never overwrites the cloud (checked by removing the guard: 4 checks fail), newer cloud save, upload queue + timeout, restore waits for the end of a run, replace_data, playtime, achievements once each + retry, scores incl. queue, a real run end, Settings card and buttons, notice widths, data). Full suite 3473 checks, 0 failed
- [x] Android export with an empty game id: plugin left out of the dex, AdMob and Billing in, builds. With a placeholder id (throwaway build, not installed): plugin classes, Play Games SDK, APP_ID meta-data and the game id string all in the APK on Godot 4.7.2
- [x] Debug build (no game id, fake backend) installed on the Xiaomi 15T: starts, no script or engine errors in logcat (screen locked, so Settings not seen on the phone)
- [x] Phone check with the fake backend (Xiaomi 15T, 2026-10-15): Settings shows Not signed in with the buttons off; tapping the card signs in ("Signed in / Progress saved to the cloud", buttons on, the save in the pretend cloud); both buttons reach the backend; a heavier pretend cloud save loads at launch (coins 53 -> 753) with "Cloud save loaded (more playtime)" on Home. The owner's phone save was backed up and put back byte for byte, the pretend cloud file removed
- [x] Fix (phone check): the Home notice covered the district name on a taller screen (placed at a fixed 86 px). It now takes the district chip's place for 4 s; test in test_play_games
- [ ] Owner: Play Console setup (Play Games project with Saved Games on, Android OAuth credential for `com.aviharez.swarmsurvivor` with the debug SHA-1, one test achievement, the two leaderboards, tester account); send the game id and the ids
- [ ] Put the ids in: game id in export_presets.cfg (`godot_play_game_services/game_id`, Android preset), achievement / leaderboard ids in data/rules/play_games.json
- [ ] On the phone with test ids: sign-in, a save round trip between two installs, one achievement, one leaderboard score (owner OK 2026-10-15: "two installs" = uninstall and reinstall on the Xiaomi 15T)
- [x] Stress test fps with the phase done: measured in phase 14 with the Play Games code in (75.0 fps, 1% low 67.9, logic 3.55 ms)

### Found during phase 15 (Google Play Games)

- The plugin sends no signal when a snapshot open fails (except "not found") and has no sign-out; timeouts cover the first, Play Games v2 has no sign-out by design
- Play Games has no public test ids (unlike AdMob): "test ids" means draft entries the owner creates in Play Console, visible to tester accounts
- Saved Games can take up to 24 hours to work after it is switched on in Play Console (plugin issue #123)
- Playtime counts from this phase on: older saves start at 0, so the first comparison falls back to runs played, then coins
- Scores from runs while signed out are kept only until the app closes (sending an old score later would put it in the wrong week)
- A tapped sign-in while the silent check is still running is ignored (the card says "Signing in")
