# Balance report (phase 14)

Measured 2026-10-17 by bot simulation. Re-run with:

```sh
SIM_ARGS="--max_runs=200" tools/balance_sim.sh build/balance/final all 16   # both modes (~4.5 h on 16 threads)
tools/balance_report.py build/balance/final > tables.md   # the generated tables below
tools/balance_sim.sh build/balance/early early 14         # first 6 runs of 14 fresh saves (~15 min)
tools/balance_runs.py build/balance/early                 # one line per save, run by run
```

## How it was measured

One simulation, `scripts/debug/campaign_sim.gd` (scene `scenes/debug/campaign_sim.tscn`), built on the bot in `run.gd` (`scripts/debug/bot_run.gd`) and the quest sim (`scripts/debug/quest_sim.gd`). It runs the real game headless at a 20 fps tick (one `max_dt` step).

- **Campaign mode** plays a fresh save forward, run by run, on a fake clock: three runs each evening, so the daily and weekly quests and Patrol follow real days. After every run the player claims every quest, points chest and challenge reward, collects Patrol (no ads), then spends coins. Ready unlocks come first; it saves up for one that is within about two runs' coins. Then it buys the cheapest Town building, building upgrade or shop level. Each run uses the owned hero with the fewest runs, on the highest open Danger. After three lost runs in a row there, it plays one level lower once. Every third run goes after a challenge the usual run can't do (the boss before minute 4, the boss during the Final Swarm, 60 s in the Final Swarm), on Danger 1. It stops when every unlock, building level and shop level is bought and Mega Mole is beaten on Danger 5, or after 200 runs.
- **Matrix mode** plays each hero on each Danger from a fixed save, buying nothing: a *new save* (heroes owned, nothing else) and *everything bought* (all unlocks, shop and Town at max).
- **Two players** (`scripts/debug/bot_picker.gd`). *Typical*: picks level-up cards half at random, leaning to new weapons and upgrades, never rerolls, random beacon bonus. *Good*: fills the weapon slots, levels weapons, takes damage manuals first and one defence manual, rerolls a useless hand, takes damage from beacons. Neither prefers a weapon by name. Both walk the same way: dodge, collect chests, pots, keys and nearby beacons and Town objects, step out of Mega Mole's red warning zone, go to the altar from minute 4, and take the portal.

**What a bot is not.** It moves worse than a person: it dodges by local push, often takes contact damage and can be cornered at the map edge (phase 3 notes). So read the win rates as relative (Danger against Danger, weapon against weapon, before against after a change), not as a person's real chances. A person who dodges well wins more at every Danger. The timings that depend on the economy (unlock prices, quest share, hours) are closer to real play, because coins depend mostly on time played and on quests.

**Weapons.** A hero's signature weapon is in every run of that hero, so it isn't a choice. "In winning runs (taken)" counts only weapons taken from level-up cards; "With signature" also counts the hero's own one.

## Targets

All numbers below are from the final data (the files in data/ as shipped), unless marked.

| Target | Result | |
| --- | --- | --- |
| An average player beats Mega Mole on run 2 or 3 | First win, 14 fresh typical saves (seeds 101-114, 10 runs each): runs 1, 1, 1, 1, 2, 2, 2, 3, 3, 5, 7, 8, 8, none. Median run 2-3; 9 of 14 by run 3. The 5 long campaigns: runs 1, 1, 2, 4, 5 (median 2) | Met |
| The first Early unlock is done and bought within the first 3 runs | Run 1 in every final save (8/8) and in 14/14 probe saves | Met |
| No single weapon in more than 40% of the bots' winning runs | Full weapon pool (everything bought, good player): Rubber Duck 43%, Garden Gnomes 38%, the rest 21-32%. Campaign runs once all weapons are unlocked: Garden Gnomes 41%, Hot Coffee 40%, Rubber Duck 39%. See "Weapons" | Explained |
| Win rate falls with each Danger level | Matrix, every column falls from Danger 1 to 5 (one flat step: typical with everything bought, 27% on both Danger 2 and 3) | Met |
| Danger 5 is beatable by a good build but not by a typical one | Danger 5, everything bought: good 27% (8/30), typical 0% (0/30). From a new save: good 3%, typical 0% | Met |
| Quests are 30-40% of coins | First 20 runs: 32% (typical) and 31% (good) of all coins. Over a whole save (to everything): 11-14%. See "Quests over a whole save" | Met (first 20 runs), explained (whole save) |
| Runs and hours until every unlock, every building and Danger 5 are done | Measured with Golden Toilet at 10, before it went to 7. Typical: 122, 130 and 159 runs (11.6-14.9 h, 41-54 days at 3 runs a day); 2 of 5 saves not done after 200 runs (~18 h). Good: 31, 87 and 107 runs (3.4-11.0 h). See "Hours to everything" | Reported |

### Weapons

A hero's own signature weapon is in each of its runs, so the tables count only weapons taken from level-up cards ("taken"); the "With signature" column adds the hero's own.

- **Early saves can't meet 40%.** A fresh save offers only the four start weapons (Rubber Duck, Hot Coffee, Stinky Socks, Garden Gnomes) plus the other heroes' signatures once hired, and a run takes about three. So in the first runs every start weapon is in 40-70% of wins whatever its numbers. The target is judged on the full pool.
- **Garden Gnomes was the outlier.** Before tuning, it was in 47-54% of campaign wins, and runs that took it won 1.5-2x as often as the rest. It keeps critters off the hero, which is worth more to the bot (it dodges by local push, see below) than to a person. The bot also *takes* it more often: runs that pick it early live long enough to fill every slot, and runs without it die before it comes up. Its damage and knockback came down. Cutting its gnome count as well made the first Mega Mole win much later (median run 5-6), because it is one of only four start weapons, so the count went back to 2-6 and the other start weapons went up instead.
- **What is left is noise.** Per weapon, a share moves about ±5 points between samples of ~100 wins: Rubber Duck was 42% and 39% in two good-player samples before its buff, then 37% and 43% in two after it, all within that spread. Garden Gnomes' win rate when taken (63%) is now level with the average (58%). No weapon is over 40% in more than one sample beyond that spread.
- **Weakest:** Sharp Feathers (Turbo Pigeon's signature) and Faulty Toaster win least when taken (44% and 40% against a 58% average). No target; worth a look if players say so.

### Danger

The campaign's per-Danger table mixes Danger with progress (later runs have more bought), so it isn't monotonic (for example the good player's 43% on Danger 3 from 7 runs). The matrix holds the save fixed and is the measure for the target.

Danger 5 got harder during tuning (enemy HP x2.3 -> x2.5, damage x1.75 -> x1.85): with the old numbers a good build won about as often on Danger 5 as on Danger 4 (pooled 33% against 37%).

### Quests over a whole save

The 30-40% target was set in phase 12 on 20 runs, and holds there (32% / 31%). It falls over a whole save because the milestone quests (one-off and front-loaded: about half of all coins in the first 6 runs) run out, while Patrol grows with the Town (about a third of all coins by the end). Raising quest rewards to hold 30% late would put the first runs well over 40%. Quest rewards were not changed in this phase.

### Hours to everything

"Everything" = all 19 unlocks bought, all 4 buildings at max, every shop upgrade at max and Mega Mole beaten on Danger 5. Hours are run time plus one minute of menus per run.

| Player | Saves done (cap 200 runs) | Runs | Hours played | Days (3 runs a day) |
| --- | --- | --- | --- | --- |
| Typical | 3/5 | 122, 130, 159 (2 saves past 200) | 11.6, 11.7, 14.9 (2 past ~18) | 41, 44, 54 |
| Good | 3/3 | 31, 87, 107 | 3.4, 8.9, 11.0 | 11, 30, 36 |

Buildings and the shop are done far earlier (median run 37 / 28 for a typical player); Danger 5 is beaten by run 75 (typical) / 37 (good). The long tail is unlocks: Golden Toilet ("10 elites in one run", mid tier in the brief) and then Lottery Tips (needs Golden Toilet; an Epic from a paid chest) and Angry Neighbor ("beat the boss below 20% HP") are bought last, usually after run 100 for a typical player. These numbers were measured with Golden Toilet at 10 elites. The owner then lowered it to 7 (2026-10-18). In a 40-run check, Golden Toilet is bought around runs 6-14 instead of after run 100, so hours to everything fall. Result below.

#### Golden Toilet at 7 (same 8 saves and seeds, 40 runs each; `build/balance/gt7`)

| Save | Golden Toilet bought (10 -> 7) | Lottery Tips bought (10 -> 7) |
| --- | --- | --- |
| Typical 1-5 | runs 60, 153, 83, 155, 129 -> 14, 1, 33, 12, 12 | runs 61, 159, 85, 159, 130 -> 20, 9, 37, 14, 22 |
| Good 1-3 | runs 104, 17, 85 -> 6, 6, 6 | runs 107, 21, 87 -> 12, 7, 9 |

- **Good players: everything by run 34-35 (3.6-3.7 h).** Two of 3 good saves did everything by runs 35 and 34 (3.7 and 3.6 h); before, it took runs 87 and 107. The third (31 runs before) had every unlock by run 22 but had not beaten Danger 5 after 40 runs. The final bought-everything matrix shows good players win about 1 in 4 Danger 5 runs (27%), so missing it within 40 runs is plausible.
- **Typical players: under 40 runs it's always Angry Neighbor or Cursed Diary.**
  - None of the 5 typical saves finished in 40 runs.
  - What each still lacked: Angry Neighbor (2 saves), Cursed Diary (1 save), or both (2 saves).
  - In the earlier campaigns (Golden Toilet at 10) these two came at runs 22-117. Danger 5 isn't beaten yet either. Its median was run 75 before, and Golden Toilet doesn't change it.
  - So for a typical player, hours to everything now run to about Danger 5 (median run 75, ~7.5 h) or the two unlocks above, whichever comes later. They were not measured past 40 runs.
- **Elites per run** (all Danger levels, 309 runs):
  - Median: 3-4 at every Danger level.
  - Runs with 7 or more: 9 of 110 at Danger 1, 2-6 of about 50 at each higher Danger.
  - Danger 1 runs that reach 8:00 kill a median of 7, because elites keep spawning in the boss and Final Swarm part.
  - So 7 takes a long run or a strong one: a mid-tier challenge, as the brief places it.

### Heroes

Sir Loaf wins least (matrix 24% against 34% and 32%; campaign 9% against 21% and 15%), though he reaches the highest median KO. No target; noted.

## Changes in data/ (phase 14)

| File | Change | Why |
| --- | --- | --- |
| `danger/danger_1.json` | enemy HP and damage x1.0 -> x0.9 | First Mega Mole win: median run 3.5 -> 2 (14 saves) |
| `danger/danger_5.json` | enemy HP x2.3 -> x2.5, damage x1.75 -> x1.85 | Danger 5 clearly harder than Danger 4 |
| `weapons/garden_gnomes.json` | damage 8-11 -> 6-10, knockback 30-36 -> 16-22 | In 47-54% of wins |
| `weapons/stinky_socks.json` | damage 3-5 -> 4-7, knockback 8-12 -> 12-18 | Spread wins; the first boss win came later after the Gnomes cut |
| `weapons/hot_coffee.json` | damage 4-6 -> 5-8 | Same |
| `weapons/rubber_duck.json` | damage 7-11 -> 8-13, bounces 2-7 -> 3-8 | Same |
| `rules/run.json` | gem_cap 400 -> 150 | XP gems piling up round the hero (merged gems keep their XP) |
| `challenges/*.json` (4) | "2000" -> "2,000" etc. in texts | Number format |
| `challenges/golden_toilet.json` | target 10 -> 7 elites in one run (owner, 2026-10-18; brief updated) | Slowest unlock: after run 100 for a typical player, and Lottery Tips waits on it |

No code numbers changed. Code changes in this phase are the sim, the UI (big numbers) and one crash fix (EnemyShots, found by the sim).

## Tables (generated)

Final data, `build/balance/final`: 8 campaigns (5 typical, 3 good) and the matrix at 10 runs per hero per Danger (30 per cell).

<!-- generated by tools/balance_report.py from build/balance/final -->

### Campaign: fresh saves played forward


#### Typical player (5 fresh saves)

| Milestone | Saves that got there | Median run | Median hours played | Median day |
| --- | --- | --- | --- | --- |
| First Mega Mole win | 5/5 | 2 | 0.2 | 1 |
| First unlock challenge done | 5/5 | 1 | 0.1 | 1 |
| First unlock bought | 5/5 | 1 | 0.1 | 1 |
| Turbo Pigeon hired | 5/5 | 4 | 0.5 | 2 |
| Gary hired | 5/5 | 13 | 1.3 | 5 |
| Danger 2 open | 5/5 | 2 | 0.2 | 1 |
| Danger 3 open | 5/5 | 16 | 1.9 | 6 |
| Danger 4 open | 5/5 | 26 | 2.9 | 9 |
| Danger 5 open | 5/5 | 38 | 4.4 | 13 |
| All 4 buildings built | 5/5 | 13 | 1.6 | 5 |
| All 19 unlocks bought | 3/5 | 130 | 11.6 | 44 |
| Every building at max level | 5/5 | 37 | 4.2 | 13 |
| Every shop upgrade at max | 5/5 | 28 | 2.9 | 10 |
| Mega Mole beaten on Danger 5 | 5/5 | 75 | 7.5 | 25 |

Coins over all 811 runs: runs 81,324, quests 17,313, Patrol 54,126. Quests' share: **11%** of all coins (18% of runs + quests). 3/5 saves finished everything within the run cap.
First 20 runs: quests 32% of all coins (37% of runs + quests).

#### Good player (3 fresh saves)

| Milestone | Saves that got there | Median run | Median hours played | Median day |
| --- | --- | --- | --- | --- |
| First Mega Mole win | 3/3 | 5 | 0.6 | 2 |
| First unlock challenge done | 3/3 | 1 | 0.1 | 1 |
| First unlock bought | 3/3 | 1 | 0.1 | 1 |
| Turbo Pigeon hired | 3/3 | 5 | 0.6 | 2 |
| Gary hired | 3/3 | 10 | 1.3 | 4 |
| Danger 2 open | 3/3 | 5 | 0.6 | 2 |
| Danger 3 open | 3/3 | 7 | 0.9 | 3 |
| Danger 4 open | 3/3 | 14 | 1.7 | 5 |
| Danger 5 open | 3/3 | 21 | 2.4 | 7 |
| All 4 buildings built | 3/3 | 11 | 1.3 | 4 |
| All 19 unlocks bought | 3/3 | 87 | 8.9 | 29 |
| Every building at max level | 3/3 | 31 | 3.4 | 11 |
| Every shop upgrade at max | 3/3 | 23 | 2.7 | 8 |
| Mega Mole beaten on Danger 5 | 3/3 | 37 | 3.9 | 13 |

Coins over all 225 runs: runs 28,583, quests 7,009, Patrol 12,936. Quests' share: **14%** of all coins (20% of runs + quests). 3/3 saves finished everything within the run cap.
First 20 runs: quests 31% of all coins (36% of runs + quests).

#### Per hero (campaign runs, all Danger levels)

| Hero | Runs | Beat Mega Mole | Median time | Median level | Median KO | Median run coins |
| --- | --- | --- | --- | --- | --- | --- |
| Sir Loaf | 348 | 9% | 4:50 | 18 | 2772 | 94 |
| Turbo Pigeon | 342 | 21% | 4:40 | 18 | 2408 | 92 |
| Gary | 346 | 15% | 3:53 | 16 | 2132 | 88 |

#### Per weapon (campaign, 157 winning runs of 1036)

| Weapon | In winning runs (taken) | With signature | Taken in runs | Win rate when taken |
| --- | --- | --- | --- | --- |
| Garden Gnomes | 43% | 43% | 33% | 20% |
| Hot Coffee | 40% | 40% | 36% | 17% |
| Rubber Duck | 40% | 40% | 33% | 18% |
| Stinky Socks | 37% | 37% | 33% | 17% |
| Fireworks | 31% | 31% | 32% | 15% |
| Leaf Blower | 30% | 30% | 35% | 13% |
| Stapler | 25% | 59% | 17% | 23% |
| Baguette | 22% | 42% | 21% | 16% |
| Faulty Toaster | 21% | 21% | 31% | 10% |
| Sharp Feathers | 10% | 57% | 20% | 8% |

#### Per Danger level (campaign runs: win rate, runs)

| Danger | Typical player | Good player |
| --- | --- | --- |
| Danger 1 | 45% (84) | 42% (36) |
| Danger 2 | 15% (54) | 23% (13) |
| Danger 3 | 15% (48) | 43% (7) |
| Danger 4 | 11% (198) | 43% (44) |
| Danger 5 | 5% (427) | 18% (125) |

### Matrix: every hero on every Danger from a fixed save (win rate, runs)

| Danger | Typical, new save | Good, new save | Typical, everything bought | Good, everything bought |
| --- | --- | --- | --- | --- |
| Danger 1 | 30% (30) | 80% (30) | 60% (30) | 93% (30) |
| Danger 2 | 13% (30) | 27% (30) | 27% (30) | 73% (30) |
| Danger 3 | 3% (30) | 23% (30) | 27% (30) | 60% (30) |
| Danger 4 | 0% (30) | 7% (30) | 7% (30) | 37% (30) |
| Danger 5 | 0% (30) | 3% (30) | 0% (30) | 27% (30) |

#### Per hero (matrix runs)

| Hero | Runs | Beat Mega Mole | Median time | Median level | Median KO | Median run coins |
| --- | --- | --- | --- | --- | --- | --- |
| Sir Loaf | 200 | 24% | 5:31 | 19 | 3706 | 90 |
| Turbo Pigeon | 200 | 34% | 5:26 | 21 | 3477 | 88 |
| Gary | 200 | 32% | 5:12 | 18 | 2958 | 80 |

#### Per weapon (Good, everything bought, 87 winning runs of 150)

| Weapon | In winning runs (taken) | With signature | Taken in runs | Win rate when taken |
| --- | --- | --- | --- | --- |
| Rubber Duck | 43% | 43% | 37% | 67% |
| Garden Gnomes | 38% | 38% | 35% | 63% |
| Stapler | 32% | 64% | 23% | 80% |
| Stinky Socks | 32% | 32% | 30% | 62% |
| Leaf Blower | 30% | 30% | 28% | 62% |
| Fireworks | 29% | 29% | 33% | 51% |
| Hot Coffee | 29% | 29% | 31% | 53% |
| Baguette | 26% | 54% | 23% | 66% |
| Faulty Toaster | 21% | 21% | 30% | 40% |
| Sharp Feathers | 21% | 61% | 27% | 44% |
