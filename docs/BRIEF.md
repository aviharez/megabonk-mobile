# Game Brief: Swarm Survivor Pixel (working title)

Oct 5, 2026 · @Syifa

## Concept summary

A 2D pixel-art survivor-like roguelite for mobile, inspired by Megabonk, with the unlock system as its main retention engine. The tone is goofy: mutant creatures invade a small town, and the defenders are random locals like a helmeted loaf of bread, a pigeon in running shoes, and an office intern.

Design pillars:

- **Every run gives progress.** Even a losing run moves the player closer to the next unlock.
- **Builds the player can steer.** Weapons, tomes, and items with limited slots, plus Reroll, Skip, and Banish.
- **A map worth exploring.** Chests, elites, shrines, a boss altar, and secrets.
- **Short sessions, one thumb.** Portrait, virtual joystick, auto-attack, runs of about 8–12 minutes.

MVP scope: 1 map (Suburbia), 3 characters, 10 weapons (3 signature + 7 general), 16 tomes, 15 items, 6 regular enemies, 1 boss, and 19 unlock challenges. Platforms are Android and iOS, built from scratch in Godot 4.7.

## How to use this brief with Claude Code

Hand over one whole phase per session, say what "done" means, then let Claude Code work. This follows [Getting the most out of Opus 5.5](https://claude.dev/blog/getting-the-most-out-of-opus-5-5/).

1. Save this brief in the repo as `docs/BRIEF.md`, and copy the CLAUDE.md section below into `CLAUDE.md` at the project root.
2. Run the phases in order. Each phase prompt already contains the whole task, the finish line, and when to stop and ask.
3. Claude Code tracks progress in `TASKS.md`. Read that file, not the scrollback, to see where a run is.
4. When a phase ends, read the **Blocked on me** part of its summary first, then the rest.
5. Run the review prompt (in the Phases section) before moving to the next phase.
6. If you remember something mid-run, type a follow-up. No need to stop the run.

Don't add "think carefully" or "step by step" to the prompts. For heavy phases, raise the effort instead.

## Game basics and characters

Portrait, one thumb: a virtual joystick controls movement, and every attack fires automatically. A run lasts about 8 minutes, plus an optional Final Swarm. Every map interaction happens by touching or standing in an area, with no extra buttons.

Each character has a signature weapon (it fills the first weapon slot) and one passive. Buying a character also adds its signature weapon to the pool for every character.

| Character | Concept | Signature weapon | Passive | Build style | Status |
| --- | --- | --- | --- | --- | --- |
| Sir Loaf | A loaf of bread in a knight's helmet | Baguette: spinning swing, area damage around the player | Getting Stale: takes less damage the longer the run lasts | Tank, AoE | MVP, available from start |
| Turbo Pigeon | City pigeon in running shoes | Sharp feathers that home in on the nearest enemy | Damage scales with movement speed | Speed | MVP, unlock |
| Gary the Intern | Exhausted office intern | Stapler: rapid-fire shots | Overtime: all stats rise after minute 5 | Scaling | MVP, unlock |
| Nana Bertha | Grumpy grandma with thick glasses | Dentures: thrown and returning like a boomerang | Tea Break: standing still briefly restores HP | Sustain | Update |
| Duchess Whiskers | Snobby aristocrat cat | Laser pointer: straight beam that pierces enemies | Nine Lives: revives once per run, high luck | Luck | Update |
| Mop Man | Janitor who never speaks | Mop wave that sweeps forward | Huge pickup magnet, bonus coins | Greed | Update |

Humor comes from original ideas, not memes or brands. All in-game text uses simple English.

## Weapons, tomes, and items

Slots: 4 weapons (including the signature weapon) and 4 tomes, each up to level 5. Level-up cards offer a mix of new weapons, new tomes, or upgrades to owned ones. Items don't use slots.

### General weapons (7)

Their attack patterns are deliberately different from the characters' signature weapons, including the three update characters.

| Weapon | Attack pattern | Level-up effect | Status |
| --- | --- | --- | --- |
| Rubber Duck | Bounces from enemy to enemy | More bounces | Start |
| Hot Coffee | Thrown, leaves a scalding puddle | Bigger puddle | Start |
| Stinky Socks | Damage aura around the player | Bigger radius | Start |
| Garden Gnomes | Orbit around the player | More gnomes | Start |
| Leaf Blower | Cone blast that pushes enemies back | Wider cone, stronger push | Unlock |
| Faulty Toaster | Electricity that chains between enemies | More chain jumps | Unlock |
| Fireworks | Random explosions across the screen | More rockets | Unlock |

### Tomes (16 in MVP, 23 total)

| Tome | Effect | Group | Status |
| --- | --- | --- | --- |
| Muscle Magazine | Damage | Offense | Start |
| Speed Reading | Attack speed / cooldown | Offense | Start |
| Eye Exercises | Crit chance | Offense | Start |
| Think Big | Attack and area size | Offense | Start |
| Copy Machine Manual | +1 projectile | Offense | Unlock |
| Grandma's Soup Recipes | Max HP | Defense | Start |
| Power Nap Guide | Regen | Defense | Start |
| Dodgeball Rules | Evasion | Defense | Start |
| Bubble Wrap Crafts | Armor | Defense | Unlock |
| Tin Foil Hat Theories | Shield that recharges when not hit | Defense | Unlock |
| Cardio Is Life | Movement speed | Utility | Start |
| Coupon Clipping | In-run gold | Utility | Start |
| Fridge Magnets | Pickup range | Utility | Unlock |
| Self-Help Book | XP | Utility | Unlock |
| Lottery Tips | Luck | Utility | Unlock |
| Cursed Diary | Stronger and more enemies, better rewards | Risk | Unlock |

For updates: Paper Plane Physics (projectile speed), Procrastination 101 (effect duration), Kung Fu by Mail (knockback), Vampire Romance Novel (lifesteal), Cactus Care (thorns), Piggy Bank Guide (permanent currency), and Horoscope (one random stat per level).

### Items and rarity (15 in MVP)

Rarities: Common (gray), Rare (blue), Epic (purple), Legendary (gold). Luck shifts odds toward higher rarities. Paid chests mostly give Common and Rare, elite chests at least Rare, and the boss at least Epic. Common through Epic items stack; chance-based effects stack with diminishing returns. Legendaries are unique, one per run.

| Item | Rarity | Effect | Status |
| --- | --- | --- | --- |
| Energy Drink | Common | Slightly more movement and attack speed | Start |
| Protein Bar | Common | More damage | Start |
| Band-Aid | Common | Max HP and a little regen | Start |
| Rubber Boots | Common | Less damage from enemy contact | Start |
| Lucky Penny | Common | More luck | Start |
| Magnet Keychain | Common | Longer pickup range | Start |
| Hot Sauce | Rare | Attacks burn enemies (damage over time) | Start |
| Whoopee Cushion | Rare | When hit, a blast pushes nearby enemies away | Start |
| Static Sweater | Rare | Chance to zap lightning when attacking | Unlock |
| Piñata | Rare | Chance for killed enemies to drop extra gold | Unlock |
| Alarm Clock | Rare | Every 20 seconds, the next attack is a guaranteed crit | Unlock |
| Clone Machine | Epic | Chance to duplicate projectiles | Unlock |
| Angry Neighbor | Epic | Below 30% HP: big damage boost | Unlock |
| Golden Toilet | Epic | Each elite killed grants a stat boost for the rest of the run | Unlock |
| Microwave Meltdown | Legendary | Every 60 seconds, a huge blast covering most of the screen | Unlock |

Balance numbers (damage, cooldowns, percentages) are not set yet. Claude Code fills in sensible starting values, then they are tuned through playtests and simulation.

## Map, enemies, and run flow

The MVP has one map, **Suburbia**: a housing estate with gardens, fences, and a pond. The map is bounded (square or slightly tall), not endlessly scrolling.

### Enemy roles

Enemy behavior is written once in code as roles. Each map fills those roles with creatures that fit its theme, plus 1–2 unique enemies and its own boss.

| Enemy (Suburbia) | Role | Behavior |
| --- | --- | --- |
| Blob | Slow chaser | Always chases, dies in one hit. Horde filler from minute 0 |
| Skitter | Fast pack | Fast, low HP, arrives in groups |
| Spitter | Shooter | Keeps its distance, fires slow projectiles |
| Bloater | Exploder | Swells, then explodes near the player, with a clear warning |
| Chomper | Charger | Pauses briefly, then charges in a straight line |
| Gnat | Wave filler | Tiny, appears only during SWARM INCOMING, in huge numbers |

### Elites, boss, and Final Swarm

- **Elites:** regular enemies scaled up, with a glowing outline and one trait: Fast, Shielded, Splitting (becomes three on death), or Vicious. They appear every 60–90 seconds and drop a chest of at least Rare rarity.
- **Boss, Mega Mole:** summoned by the player at an altar. Patterns: burrows and pops up under the player (its shadow is visible), a ring of rocks with gaps, and summoning Blobs. Below 50% HP all its attacks speed up. Defeating it opens the exit portal.
- **Final Swarm:** starts when the 8-minute timer runs out. Enemies keep coming and escalation never stops. The player can leave through the portal, or stay for a coin multiplier that keeps rising.
- **Overdue Bills:** paper ghost bills that pass through everything, ignore knockback, and speed up every minute. They appear a few minutes into the Final Swarm as a guaranteed run ender. The same on every map.

### Boss altar

The altar sits somewhere on the map, with an indicator arrow. The boss is summoned by standing in the altar's circle for 2–3 seconds. If the timer runs out before the boss is defeated, the Final Swarm starts anyway. On the first run, if the boss hasn't been summoned by minute 5, the altar arrow pulses and a short hint appears.

### Run timeline

| Minute | What happens |
| --- | --- |
| 0–2 | Blobs and Skitters |
| 2–4 | Spitters and Bloaters join. First SWARM INCOMING around minute 3 |
| 4–6 | Chompers join, density rises. Second SWARM INCOMING around minute 5 |
| Any time | Player summons Mega Mole at the altar |
| 8 | Final Swarm starts |
| 8+ | Overdue Bills appear, the run ends |

SWARM INCOMING is a 20–30 second enemy surge with a big on-screen warning.

### Map interactables

| Object | How it works |
| --- | --- |
| Paid chest | Opened with in-run gold. The price rises each time one is opened |
| Elite chest | Free, dropped by elites |
| Charge shrine | Stand inside the circle for a few seconds, then pick one stat bonus |
| Risk/reward shrine | Enemies get stronger for a while, rewards get bigger |
| Challenge shrine | Example: kill 50 enemies in 30 seconds for a reward |
| Pot | Breakable, contains gold |
| Merchant | Appears occasionally, sells items for gold |
| Pigeon cage | Opened with a key dropped by an elite. Unlocks Turbo Pigeon |
| Boss altar | Summons Mega Mole |

Chests, shrines, elites, and the altar get indicator arrows at the screen edge when out of view.

Planned update maps: Sewers (giant crocodile boss), Farm (mutant cow boss), and Shopping Mall (giant security guard boss). Each map unlocks after the previous map's boss is defeated.

## Meta progression

19 pieces of content (characters, weapons, tomes, and items) unlock in two steps: completing a challenge makes them available, then the player buys them with permanent coins. A permanent coin shop also sells quality-of-life features. The game-over screen always shows progress bars toward the 2–3 closest challenges, plus anything that is ready to buy.

### Unlock challenges

| Tier | Reward | Challenge | Requires |
| --- | --- | --- | --- |
| Early | Alarm Clock | Finish 3 runs | — |
| Early | Fridge Magnets | Collect 3,000 XP gems | — |
| Early | Piñata | Break 20 pots in one run | — |
| Early | Tin Foil Hat Theories | Activate 5 shrines | — |
| Early | Fireworks | Defeat Mega Mole for the first time | — |
| Mid | Turbo Pigeon | Find the key from an elite, open the pigeon cage in Suburbia | — |
| Mid | Leaf Blower | Survive a SWARM INCOMING without taking damage | — |
| Mid | Faulty Toaster | Kill 1,000 enemies with Hot Coffee | — |
| Mid | Self-Help Book | Reach level 20 in one run | — |
| Mid | Bubble Wrap Crafts | Kill 2,000 enemies as Sir Loaf | — |
| Mid | Lottery Tips | Get an Epic item from a paid chest | — |
| Mid | Golden Toilet | Defeat 10 elites in one run | — |
| Hard | Gary the Intern | Survive 60 seconds in the Final Swarm | — |
| Hard | Copy Machine Manual | Fire 3,000 staples as Gary | Gary the Intern |
| Hard | Static Sweater | Kill 300 enemies with Faulty Toaster | Faulty Toaster |
| Hard | Angry Neighbor | Defeat the boss with HP below 20% | — |
| Hard | Clone Machine | Hold 3 copies of the same item in one run | — |
| Hard | Cursed Diary | Defeat the boss before minute 4 | — |
| Hard | Microwave Meltdown | Defeat the boss while the Final Swarm is running | — |

Each challenge is one data entry: id, tracked stat, scope (per run or cumulative), target, prerequisite, reward, and coin price. Adding challenges needs no code changes.

### Two-step unlock

- **Locked:** shown as a silhouette with the challenge and its progress.
- **Available:** challenge complete. The card lights up with its price and a "new" badge, and the main menu shows a notification dot.
- **Owned:** bought with coins. Only owned content enters the pool or the character select screen.

Prices scale by tier and are set in data, then tuned in phase 8. Starting targets, measured in coins from an average run: Early about 1 run, Mid about 3 runs, Hard about 6 runs. Characters cost more than items in the same tier. A completed challenge never expires, so players can save coins and buy later.

### Coin shop and level-up actions

Permanent coins are earned at the end of every run (the multiplier rises in the Final Swarm).

| Feature | When it can be bought | What it does |
| --- | --- | --- |
| Reroll | From the start | Rerolls the level-up cards |
| Skip | From the start | Skips a level-up for a small compensation (for example, gold) |
| Banish | After a few runs | Removes one option from the pool for the rest of the run |
| Toggler | After 12 unlocks | Turns specific content on or off in the pool before a run |
| Permanent stat upgrades | From the start | Small bonuses that must not dominate |

Buying Reroll, Skip, or Banish grants a few charges per run, and further upgrades add more charges. When charges run out, the button shows an ad icon (see Monetization). Players who haven't bought Skip or Banish can still try each once per run through an ad.

On the level-up screen, the three actions appear as small icons under the cards, with the remaining charges shown.

## Monetization

Ads appear only at natural breaks, and most are chosen by the player. No forced ads during a run.

| Format | Placement | Limit |
| --- | --- | --- |
| Rewarded | Revive on death | 1 per run |
| Rewarded | 2x coins on the game-over screen, next to unlock progress | 1 per run |
| Rewarded | Reroll, Skip, Banish when charges run out | Up to 1 per action per run |
| Rewarded | Daily reward on the main menu | 1 per day |
| Interstitial | After game over, when returning to the menu | At most once every 2–3 runs. Never on day one. Skipped if the player just watched a rewarded ad |
| Banner | Menu, shop, unlock screen | Never during gameplay |
| Remove Ads IAP | Shop | Removes interstitials and banners. Rewarded ads stay available. Optional: permanent +25% coins |

Technical rules:

- The game pauses automatically while an ad plays, and resumes correctly afterward, including when an ad fails or is closed early.
- Rewarded buttons only show when an ad is loaded and ready.
- Rewards are granted only after AdMob's reward callback, not when the button is tapped.

## Assets, audio, and VFX

Every asset follows one locked palette (picked from Lospec), a 180×320 portrait base resolution, and character and enemy sprites of roughly 16×16 to 24×24.

### Asset sources

| Asset | Source | Notes |
| --- | --- | --- |
| Enemies and elites | [procedural-pixel-creatures](https://github.com/idlerunner00/procedural-pixel-creatures) | Offline generator, exports PNG sprite sheets + JSON. Elite = enemy sprite scaled up and recolored |
| Player characters | SpriteCook | Sprite + idle, walk, and hit animations |
| Mega Mole | SpriteCook | Sprite + burrow, attack, and hit animations |
| Weapon and item icons | SpriteCook | One style-reference icon first, the rest follow it |
| Tome icons | SpriteCook + code | One book sprite, then 16 cover-color and symbol variants made in code |
| Suburbia tiles and props | SpriteCook or drawn in code | Remapped to the palette |
| UI | CC0 pack (for example, Kenney) or drawn in code | Remapped to the palette |

The procedural generator uses Godot 4.5.2 .NET and .NET 8, and has only been validated on Windows. Run it as a separate tool, not as part of the game project.

### SpriteCook rules (Starter plan, 800 credits per month)

- Generate Sir Loaf first as the style reference. Move on to other assets only after approval.
- Ask for confirmation before every generation, and log estimated credits in `docs/ASSET_LOG.md` (about 8 credits per sprite, 20 per animation).
- No variations by default. Variations only for characters and the boss.
- Remap every result to the palette and check it: no off-grid pixels, no off-palette colors.

Estimated MVP usage is about 600 credits, or 900–1,200 including regenerations.

### Audio

- **SFX:** made by Claude Code with an sfxr-style generator script, rendered to WAV. Pitch is randomized slightly on each play, and simultaneous voices are capped.
- **Music:** placeholder chiptune made by Claude Code, rendered to OGG. Three tracks: menu, gameplay, boss/Final Swarm. To be replaced later with commercially licensed music.
- All audio loads through one audio manager with the file list in one place. Swapping a track means overwriting the file with the same name.

### VFX

| Group | Effects |
| --- | --- |
| Hit feedback | White hit flash (shader), damage numbers (can be turned off), pixel particles on enemy death, brief hit-stop on big crits and boss hits, light screen shake (can be turned off) |
| Progress and rewards | Sparkling XP gems with a trail when pulled in, light burst on level-up, rarity-colored beam before a chest opens |
| Weapons | Steam from coffee puddles, wavy green sock aura, toaster lightning lines, firework explosions, and a signature effect for every other weapon |
| World and danger | Elite outlines, red telegraph zones, red vignette at low HP, screen tint shift when the Final Swarm starts |

VFX rules: particles use small pixel textures from the same palette, snap to the pixel grid, and fade with dithering, not smooth gradients. All enemy projectiles use one dedicated color (bright magenta) that appears nowhere else.

## Technical rules

All content is data, and performance is measured on low-end Android phones from day one.

### Architecture

- **Data-driven:** characters, weapons, tomes, items, enemies, interactables, unlock challenges, and shop items are defined as Godot Resources (`.tres`) or JSON in `data/`. Adding content must never require code changes.
- **Central stat system:** every stat is computed from a base value plus a list of flat and percent modifiers. Tomes and most items just add modifiers.
- **Event hooks:** the game emits events such as `on_hit`, `on_kill`, `on_damaged`, `on_level_up`, `on_chest_opened`, and `on_shrine_activated`. Trigger items listen to them as a combination of trigger, chance, and effect.
- **Stat tracker:** every event is also recorded (cumulative and per run) for unlock challenges and the game-over screen.
- **Spawn director:** spawn schedules, SWARM INCOMING waves, elites, the Final Swarm, and Overdue Bills are driven by per-map data, using enemy roles.
- Built from scratch. Ads and IAP use third-party Godot plugins: pick ones that are actively maintained and support Godot 4.7, and ask before installing. Saves are versioned JSON in user://.

### Performance

- Object pooling for enemies, projectiles, XP gems, damage numbers, and particles.
- No physics node per enemy. Use batched rendering (for example, MultiMesh) and simple distance-based collision or a spatial grid.
- Cap of about 300 enemies on screen. Past the cap, escalation raises HP, damage, and speed instead of count.
- Target 60 fps on low-end Android phones. A "reduce effects" option is available in settings.
- Headless run simulation with simple bots to check balance and performance.

### Godot settings

- Compatibility renderer.
- 180×320 viewport, viewport stretch mode, integer scaling, Nearest texture filter.
- CPUParticles2D for all particles.
- Portrait orientation locked.

## CLAUDE.md

Copy into `CLAUDE.md` at the project root, then adjust paths if needed.

```markdown
# Project: pixel survivor-like for mobile (working title)

The full spec is in docs/BRIEF.md. The brief is the source of truth for content and technical rules.

## How to work
- When a step doesn't need my input, keep going. Put status notes in the same message as your next action.
- Stop and ask only when you can't continue without me, or before anything destructive: deleting data or assets, force-pushing, or changing anything outside this repository.
- Keep the current phase's checklist in TASKS.md. Tick each item when it's done, and add anything new you find.
- For large work that splits cleanly (for example, writing many data entries or auditing many files), give each part to its own subagent and check its evidence before you accept it.
- End every run with three headings: Blocked on me, Changed, Found. Mark anything you couldn't confirm, and say where you looked.

## Technical rules
- Godot 4.7, GDScript, Compatibility renderer, portrait 180x320, viewport stretch mode, integer scaling, Nearest texture filter.
- All content is data in data/. Adding content must not require code changes.
- Stats are base value + modifiers. Item effects use event hooks (on_hit, on_kill, on_damaged, etc.).
- Pool enemies, projectiles, gems, damage numbers, and particles. Max about 300 enemies on screen.
- Built from scratch. Ask before adding any third-party plugin (AdMob, IAP, or anything else). Saves are versioned JSON in user://.
- Pause the game while an ad plays. Grant rewarded-ad rewards only after the reward callback.

## Assets
- Every asset uses the palette in assets/palette.png. No off-palette colors, no off-grid pixels.
- SpriteCook: ask me before every generation, log estimated credits in docs/ASSET_LOG.md, no variations by default.
- Don't use names, characters, or assets from other games.

## UI design direction
The UI should feel like goofy pixel art, not a generic mobile UI. Don't use: gradient pill buttons, glass or blur effects, soft drop shadows, non-pixel fonts, emoji as icons, smooth rounded corners, or color gradients outside the palette.

## Verification
- Before calling a phase done, run the project and the existing tests. Report fps with 300 enemies on screen.
```

## Phases

Ten phases (0–9), run in order. Gameplay is built first with placeholder shapes, and real assets arrive in phase 6. Every phase ends with the review prompt at the bottom.

### Phase 0: Setup

```
Create a new Godot 4.7 project from scratch in this repository, following docs/BRIEF.md and CLAUDE.md.
Done means: Godot settings match the Technical rules section, the data/, assets/, scenes/, and scripts/ folders exist, assets/palette.png holds a temporary 32-color palette, TASKS.md holds the phase 1 checklist, a basic main menu and a versioned JSON save system exist, and the project runs without errors and exports a debug build to my Android phone.
Stop and ask only if Godot 4.7 isn't installed or the Android export can't be set up.
```

### Phase 1: Core loop with placeholders

```
Build the core loop from docs/BRIEF.md, using geometric shapes as placeholders.
Scope: virtual joystick, Sir Loaf with the Baguette, Blobs and Skitters, XP gems with magnet pull, level-up with 3 cards, HP and death, the 8-minute timer, pooling, and the 300-enemy cap.
Done means: a run plays from start until death or the timer ends, and a 300-enemy stress test reports average fps.
Stop and ask only if the stress test is below 50 fps and you can't explain why.
```

### Phase 2: Stat system and all build content

```
Implement the stat system with modifiers, the event hooks, and every MVP weapon, tome, and item from docs/BRIEF.md as data.
Give each data category (weapons, tomes, items) to its own subagent, then check every entry against the brief before you accept it.
Done means: 10 weapons, 16 tomes, and 15 items exist in data/ and can appear on level-up cards or in chests, slot and rarity rules work, and an automated test confirms every entry loads and applies without errors.
Stop and ask only if an effect in the brief can be read two ways with very different results.
```

### Phase 3: Map, enemies, and run flow

```
Build the Suburbia map and the full run flow from the Map, enemies, and run flow section of docs/BRIEF.md.
Scope: bounded map, data-driven spawn director, 6 enemy roles, elites with 4 traits, SWARM INCOMING, every interactable, indicator arrows, the altar and Mega Mole, the portal, the Final Swarm, and Overdue Bills.
Done means: a run follows the run timeline table, the boss can be summoned and defeated, the portal ends the run, and the Final Swarm always ends through Overdue Bills.
Stop and ask only if the brief conflicts with the performance limits.
```

### Phase 4: Meta progression and characters

```
Implement meta progression from the Meta progression section of docs/BRIEF.md.
Scope: stat tracker, 19 unlock challenges as data with the two-step unlock (complete the challenge, then buy with coins), the coin shop, Reroll, Skip, Banish, and Toggler charges, the game-over screen with progress toward the closest unlocks, Turbo Pigeon and Gary with their passives, and persistence through the save system from phase 0.
Done means: every challenge can be triggered by an automated test, progress survives closing the app, only owned content enters the pool, and buying a character adds its signature weapon to the pool.
Stop and ask only before a save format change that would break existing saves.
```

### Phase 5: Monetization

```
Wire up ads and IAP from the Monetization section of docs/BRIEF.md, using AdMob and IAP plugins for Godot 4.7 with test IDs. Pick actively maintained plugins and ask me before installing them.
Done means: every rewarded, interstitial, and banner placement works with test ads, per-run and per-day limits hold, the game pauses and resumes correctly including when an ad fails, and Remove Ads removes interstitials and banners.
Stop and ask before entering real ad unit or IAP product IDs.
```

### Phase 6: Assets

```
Replace every placeholder with real assets from the Assets, audio, and VFX section of docs/BRIEF.md.
Start with Sir Loaf from SpriteCook and wait for my approval before any other asset. Enemies come from the sprite sheets in assets/creatures/ that I export from procedural-pixel-creatures. Tome icons are made in code from one book sprite.
Done means: no placeholders remain, every asset passes the palette and grid check, and docs/ASSET_LOG.md records the credits used.
Stop and ask before every SpriteCook generation, and when remaining credits drop below 100.
```

### Phase 7: Audio and VFX

```
Add audio and VFX from the Assets, audio, and VFX section of docs/BRIEF.md.
Scope: an sfxr-style SFX generator that outputs WAV, three placeholder chiptune tracks as OGG, an audio manager with a voice cap, every VFX in the table, and settings to turn off damage numbers and screen shake and to reduce effects.
Done means: every key event has a sound and an effect, and the 300-enemy stress test with all effects on stays above 50 fps.
Stop and ask only if fixing performance would mean removing an effect the brief requires.
```

### Phase 8: Balance and polish

```
Build a headless run simulation with simple bots for all three characters, then tune the numbers for weapons, tomes, items, and enemies.
Targets: an average player beats Mega Mole on run 2 or 3, the first Early unlock is completed and bought within the first 3 runs, and no single weapon appears in more than 40% of the bots' winning runs.
Done means: a simulation report in docs/BALANCE.md with a table per character and weapon, and number changes only in data/.
Stop and ask only if a target can't be met without changing the design in the brief.
```

### Phase 9: Release prep

```
Prepare Android and iOS release builds.
Done means: the AAB and iOS builds export successfully, the icon and splash use game assets, the privacy policy page and store copy (working title, short and long descriptions) are in docs/STORE.md, and a Google Play closed-testing checklist is in TASKS.md.
Stop and ask before uploading anything to Play Console or App Store Connect.
```

### Review prompt (run at the end of every phase)

```
Review the diff on this branch against main.
List only problems you'd block the merge for. For each one, give the file and line, why it's wrong, and how to show it fails.
Also flag anything that departs from docs/BRIEF.md.
```

## Open items

- [ ] Final game name (check availability on Play Store and App Store, add a keyword subtitle).
- [ ] Check the procedural-pixel-creatures license: can generated sprites be used in a commercial game?
- [ ] Pick the final palette from Lospec.
- [ ] Set up Godot 4.5.2 .NET and .NET 8 on the Mac to run the procedural generator.
- [ ] Subscribe to SpriteCook Starter during phase 6, then cancel.
- [ ] Replace placeholder music with commercially licensed music before release.
- [ ] Register Google Play and Apple developer accounts, and line up at least 12 testers for closed testing.
