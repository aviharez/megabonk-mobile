# Game Brief: Mobbed! Survive the swarm

Title (owner, 2026-10-10): **Mobbed!**, subtitle **Survive the swarm**. Earlier working title: Swarm Survivor Pixel.

Player-facing names (owner, 2026-10-10, to move away from Megabonk's terms): shrines are **beacons** (CHARGE / RISK / CHALLENGE BEACON) and tomes are **manuals** (MANUAL LV 2, the MANUALS tab). This brief, the data folders and the code keep "shrine" and "tome" as internal names (ids, `data/tomes/`, `tome:<id>` stat sources, save keys), so saves and content stay valid.

Studio: **Aviharez Studio**. Its splash (`scenes/splash.tscn`) is the first scene.

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
| Mid | Lottery Tips | Get an Epic item from a paid chest | Golden Toilet |
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
| Rewarded | Revive on death (not when Overdue Bills end the run) | 1 per run |
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

Every asset follows one locked palette (picked from Lospec), a 180×320 portrait base resolution (the run's world view is 2× wider, like Survivor.io: owner change 2026-10-09) (the minimum view; taller screens see more of the map), and character and enemy sprites of roughly 16×16 to 24×24.

### Asset sources

| Asset | Source | Notes |
| --- | --- | --- |
| Enemies and elites | SpriteCook (owner direction 2026-10-13: one family with the home critters) | Two 2x2 critter sheets, halved and cleaned by hand in `tools/art/critters.py` -> `assets/enemies/`; closed-eye blink frames and the Gnat hand-pixelled; Skitter walk cycle and Spitter mouth poses animated with SpriteCook. Motion (hop, squash, telegraphs) is code. Elite = enemy sprite scaled up with a glowing outline. See "Creature art rules" |
| Player characters | SpriteCook | Sprite + idle, walk, and hit animations |
| Mega Mole | SpriteCook | Sprite + burrow, attack, and hit animations |
| Weapon and item icons | SpriteCook | One style-reference icon first, the rest follow it |
| Tome icons | SpriteCook + code | One book sprite, then 16 cover-color and symbol variants made in code |
| Suburbia tiles and props | SpriteCook or drawn in code | Remapped to the palette |
| UI | SpriteCook UI kits (9-slice plates, frames, stickers, icons; kit 3 + 3b for the Phase 9 dark look) + SpriteCook home art (night street backdrop, logo leaves, critters) | Snapped to the palette (`tools/art/ui_kit.py`, `tools/art/home_art.py`). Fonts (OFL, Google Fonts): Titan One for titles, buttons, names and numbers; Inter at weight 900 for body text (7 px or more; 6 px on popup cards and damage numbers). Both import with antialiasing off, so text stays on the palette at device resolution |

### Creature art rules (owner direction 2026-10-13)

Every creature (the heroes, every enemy, the boss) belongs to one family: the goofy mutant critters on the home screen (`assets/ui/home/critter_*.png`).

- A 1 px dark INK outline all the way round.
- Big eyes are the family trait. 2-3 tone shading, light from the top left.
- Sizes: player ~24 px; regular enemies 12-20 px; Gnat 6-8 px. Elites keep the current system (scaled up, glowing outline, one trait).
- One colour per role, so a role reads from its colour and shape. No green on enemies (the ground is green).

| Enemy | Role | Look | Colour |
| --- | --- | --- | --- |
| Blob | slow chaser | small round critter, one big eye (like `critter_blue`) | blue |
| Skitter | fast pack | leaner, antennae, leans forward | purple |
| Spitter | shooter | big mouth (like `critter_red`) | red |
| Bloater | exploder | fat, puffy | yellow / orange |
| Chomper | charger | biggest, wide toothy jaw | pink-berry (the palette has no darker magenta) |
| Gnat | wave filler | tiny eyeball with wings | pale / white |

- Static sprites, no walk animations: the motion is code (hop and bob with squash and stretch, facing, lean, blinks, telegraphs, hit squash), tuned in `data/rules/creature_motion.json`. Each sheet has its open-eye frame(s), the same frames with the eyes shut (hand-pixelled, for blinks) and any extra pose (the Chomper's open-jaw charge). Sheets: `assets/enemies/`, built by `tools/art/critters.py`.
- Palette and grid rules as for every asset.

### SpriteCook rules (Starter plan, 800 credits per month)

- Generate Sir Loaf first as the style reference. Move on to other assets only after approval.
- Ask for confirmation before every generation, and log estimated credits in `docs/ASSET_LOG.md` (about 8 credits per sprite, 20 per animation).
- No variations by default. Variations only for characters and the boss.
- Remap every result to the palette and check it: no off-grid pixels, no off-palette colors.

Estimated MVP usage is about 600 credits, or 900–1,200 including regenerations.

### UI and screens (owner direction 2026-10-09: "the core is good, the UI/UX is not")

- **Safe area.** The Android build is immersive and draws under the camera cutout. HUD rows, the pause button, menu headers and every panel keep `SafeArea.top()` px clear at the top and `SafeArea.bottom()` px at the bottom; backgrounds still fill the screen.
- **No alpha.** Modals dim the screen with an ordered-dither pattern of INK (`DitherDim`); scene changes wipe through the same dither (`Transition` autoload). Everything moves in whole pixels.
- **Main menu.** A night street (SpriteCook backdrop) with the picked hero standing on a stone plinth at 2x and round critters peeking in at the edges, a coin plate and a settings gear on top, the logo, a card for the next unlock (with its progress), a big "play", then four tiles: heroes, unlocks, shop and free coins (the daily reward). Settings open as a window: music, sounds, vibration, damage numbers, screen shake, reduce effects.
- **Logo.** "Mobbed!" in Titan One, gold with a lit top and shaded foot, a thick dark outline and a light rim, letters overlapping, tilted and hopping one at a time, leaves and a radish critter on top, with "survive the swarm" on the red ribbon under it. No engine credit anywhere in the game.
- **Menu screens** (heroes, maps, unlocks, shop, Toggler): bold title on the ribbon, then the content, and a fixed bottom bar with BACK and either the main action (NEXT, GO!) or the coin plate. Lists drag-scroll from anywhere, even starting on a button (`DragScroll`, with fling); a drag never presses the button it started on. No empty space: screens with little content fill the height (the hero preview grows; the map screen shows the run's goals under the cards).
- **Unlocks and shop are grids.** A fixed detail panel on top shows the selected tile (icon at 2x, name or "??? WEAPON", what it does once known, the challenge with its bar, BUY / OWNED / why it's locked); under it a grid of 2x icon tiles grouped by tier (unlocks) or kind (shop). Locked tiles are silhouettes with a progress strip, ones ready to buy hop and sparkle with a NEW badge or red dot, owned ones get a tick, shop tiles show level pips. Shop entries name their picture in data ("icon": "tomes/muscle_magazine" or "ui/lv_die"). Remove Ads stays a purple banner above the grid.
- **HUD.** XP bar with the level on it, HP bar with a draining ghost, a big timer (SALMON in the last 30 s, PINK in the Final Swarm), gold and kills, toasts on a dark plate that wrap. Under the HP row, the **build strip**: an icon per weapon and tome with level pips (gold at max); a new one or a level-up flashes. The HP bar stops where the big timer starts. Items show as a small row of icons at the bottom-left (rarity-coloured corners, stack count), above the boss bar during the boss. A **pickup card** slides in for a few seconds whenever an item comes from a chest or the merchant (icon, rarity, name, what it does, stack count) or a shrine bonus is taken.
- **Run panels.** Level-up cards show kind, icon, level pips (the new level blinks), the description, and the numbers that change in LIME ("DMG 10>14  CD 1.3>1.2", tomes "NOW +10% > +20%"); REROLL / SKIP / BANISH are labelled. The merchant's cards say what each item does. Pause fills the screen: the build (tap any weapon, tome or item to see its level, what it does now, and for weapons its damage and kills this run), stats, music/sound toggles, and GIVE UP asks for a second tap. Game over: reason line, the hero, stat tiles, coins rolling up, 2X COINS, the build you ended with, closest unlocks, PLAY AGAIN and MENU, after a short red death beat.
- **First runs.** "SURVIVE!" at the start; for the first two runs a ghost joystick says "DRAG ANYWHERE TO MOVE" until the first touch.

### Audio

- **SFX:** made by Claude Code in code with Audio as Code (MIT, synthesized instruments, no samples) plus numpy noise layers, rendered to WAV by `tools/audio/aac_sfx.py` (owner change 2026-10-15; replaced the sfxr square waves). Pitch is randomized slightly on each play, and simultaneous voices are capped.
- **Music:** composed by Claude Code with Audio as Code, rendered to seamless OGG loops by `tools/audio/music/*.py` (owner change 2026-10-15: no licensed music budget; replaces the placeholder chiptune). Five tracks: menu, gameplay, boss/Final Swarm, game over (result after a loss), victory (result after a win).
- All audio loads through one audio manager with the file list in one place. Swapping a track means overwriting the file with the same name.

### VFX

| Group | Effects |
| --- | --- |
| Hit feedback | White hit flash (shader), damage numbers (can be turned off; plain hits small in Inter with an INK outline so crowds stay readable, crits big in Titan One with a red edge), pixel particles on enemy death, brief hit-stop on big crits and boss hits, light screen shake (can be turned off) |
| Progress and rewards | Sparkling XP gems with a trail when pulled in, light burst on level-up, rarity-colored beam before a chest opens, double ring and sparks when it pops |
| Findable things | Chests, shrines, the key, cage, altar, portal and merchant stand in a **pillar of light** in their colour with a pulsing glow on the ground, rising motes and twinkles (data "beam": {color, height}); pots twinkle gold now and then ("twinkle"). Chests always show their price (gold when you can pay). Shrine circles turn, light up inside as they charge, and fill with a thick ring |
| Weapons | Baguette: a big crescent smear behind the blade (orange tail, gold, butter, white edge). Stinky Socks: a dithered stink cloud under the hero, a wobbling rim, outlined stink puffs drifting out and popping, swirling wisps, cartoon stink lines and a wave on every tick. Hot Coffee: cups fly with a shadow and steam, splash on landing, and leave glossy coffee puddles on the ground (lumpy, with a shine, popping bubbles, wavy steam) that shrink as they dry. Shots leave a short streak in their weapon's "trail" colour. toaster lightning lines, firework explosions |
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
- 180×320 minimum viewport, canvas_items stretch mode (the run's world draws in its own view at a smaller integer scale, `world_view_scale` in `data/rules/run.json`), stretch aspect "expand" (taller or wider screens see more instead of black bars), integer scaling, Nearest texture filter. UI anchors to screen edges or the center.
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
- Godot 4.7, GDScript, Compatibility renderer, portrait 180x320 minimum view (stretch aspect expand: taller screens see more), canvas_items stretch mode (world view 2x wider during runs), integer scaling, Nearest texture filter.
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
The UI is dark, chunky pixel art from the SpriteCook kits in assets/ui/ (deep night panels, thick INK outlines, hard drop shadows, toy-bright gold / blue / green / orange / purple accents). Only the text is smooth: Titan One for titles, buttons, names and numbers; Inter 900 for body text (7 px; 6 px only for popup card names and descriptions and damage numbers, never smaller). Little text: kind, rarity and New are shown by colour and stickers, not words. Don't use: gradient pill buttons, glass or blur, soft shadows, emoji as icons, smooth rounded corners, colours outside the palette, or code-drawn plates where a kit part exists.

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
Start with Sir Loaf from SpriteCook and wait for my approval before any other asset. Enemies are SpriteCook critters in assets/enemies/ (see "Creature art rules"). Tome icons are made in code from one book sprite.
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

### Phase 9: Fonts and UI revamp

```
Rebuild every screen after the SpriteCook kit 3 concepts (docs/phase9/7_kit3_home_concept.png, 8_kit3_levelup_concept.png) with Titan One + Inter 900 and the kit 3 / 3b parts, all text in mixed case.
Done means: each real screen checked side by side with the concepts at 540x1170 with 0 off-palette pixels, no text overlaps or clips (tests/test_text_fit.gd), and the 300-enemy stress test still above 50 fps.
Stop and ask before any SpriteCook generation beyond the approved backdrop art.
```

### Phase 10: Release prep

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
- [ ] Pick the final palette from Lospec.
- [ ] Subscribe to SpriteCook Starter during phase 6, then cancel.
- [x] ~~Replace placeholder music with commercially licensed music before release.~~ Music is now composed in code (Audio as Code, 2026-10-15).
- [ ] Register Google Play and Apple developer accounts, and line up at least 12 testers for closed testing.

# Update 1: UI v2 and Retention

## Summary

This update keeps the core run as it is and changes three things around it: a game-feel UI with one design system, a two-step Play flow, and a retention layer (quests, a town to rebuild, danger levels, a bestiary, Google Play Games). Income stays ads + Remove Ads, so rewarded ads are the accelerator in every new system, never a paywall.

- **Why:** testing showed the core is fun but players have little reason to come back, the UI reads as a plain app, and the build still feels close to Megabonk.
- **Visual reference:** the design canvas "Mobbed! UI Redesign" (17 phone screens) and the "Mobbed! Design System" (tokens, components, rules). Both are private claude.ai pages, so Claude Code cannot open them: the owner exports each screen as a PNG into `docs/ui/` (file names below) before phase 1.
- **Sizes in this brief** are design px = 2 x game px (a 360 px wide screen = the 180 px game view). Divide by 2 in Godot.

## Game UI kit v2

Every UI part is a physical, outlined object, and the chrome stays in one night-blue family so the full-colour heroes, critters and items are what the eye lands on.

**Rules**

- **Ink outline + hard drop on everything:** 1 game px INK outline around every window, card, button, slot, bar, badge and sticker, plus a solid INK shadow straight down (3 game px under windows and buttons, 2 under cards and slots). Square corners, no soft shadows, no gradients, no glow.
- **Windows are framed:** INK outline, a 2 game px frame band lit top-left (`frame-hi`) and shaded bottom-right (`frame-lo`), an inner INK line, a hatched fill (`surface` with `surface-2` diagonal lines, a 4x4 game px tile) and four `frame-hi` bolts in the corners. Modal windows hang a title plate over their top edge; Level Up's plate is lamp yellow.
- **Content sits in wells:** icons, stat tiles and bar tracks sit in sunken `well`s.
- **Display text is outlined:** Lilita One with a 1 game px INK outline and drop for titles, names, numbers and button labels. Inter 800 for body text, never outlined, never below 6 game px.
- **Buttons are blocks:** top bevel (`frame-hi` or `lamp-hi`), bottom bevel (`frame-lo` or `lamp-lo`), a 2x2 game px shine top-left, white outlined label.
- **One `lamp` primary button per screen.** Everything else is the blue secondary button. Green (`btn-go`) only for the AD x2 reward.
- **Colour means something:** `lamp` = primary action, active nav tile, progress fills, selected slot, level badge, coins. `go` = ready, done, claimable. `alert` = notification dots and the HP bar only. Rarity colours = item slot frames only. Kind (weapon, manual, item) is told by a muted text line and the icon, never by card colour.
- **Bottom nav:** five icon tiles (Shop, Characters, Battle, Town, Collection). Only the current tile is labelled; it rises above the bar in `lamp`.
- **Backgrounds:** menus sit over the night town backdrop (`assets/ui/home/backdrop.png` remapped to the night ramp, warm windows kept). In-run panels sit over the map dimmed by a dither overlay.
- **Fonts:** Lilita One (display) and Inter (body) are already in `assets/fonts/`. Titan One and the Bonk/5x7 pixel fonts leave the UI.

**Colour tokens** (new tones must be added to `assets/palette.png`; existing palette names in brackets)

| Token | Hex | Use |
| --- | --- | --- |
| bg | #0b1020 | Screen ground (new) |
| surface | #121a2e | Window and nav fill (new) |
| surface-2 | #16203a | Hatch lines (new) |
| well | #0b0f1c | Sunken wells (new) |
| raised | #1a2540 | Cards inside windows (new) |
| frame-lo | #1e2a45 | Frame shade, bottom bevel (new) |
| frame | #2e4170 | Frame band, secondary button (new) |
| frame-hi | #5b78b0 | Frame light, bolts (new) |
| line | #2a3a5e | Rules, empty slots (new) |
| muted | #8a9cc2 | Secondary text (new) |
| text | #f4f0e8 | Primary text (PAPER) |
| ink | #0e0b16 | Outlines, drops (INK) |
| lamp / lamp-hi / lamp-lo / lamp-deep | #f5b83d / #ffe680 / #d97a26 / #8a4a1c | Accent (GOLD, BUTTER, ORANGE, RUST) |
| go / go-lo / go-deep | #a6e070 / #5cb83f / #2f7a34 | Ready, done (LIME, GREEN, LEAF) |
| alert / alert-hi / alert-lo | #e04a3a / #ff8a6b / #a3262f | Dots, HP (RED, SALMON, BLOOD) |
| r-common / r-rare / r-epic / r-legend | #a9b6cf / #3a9ad9 / #8a3fc4 / #f5b83d | Rarity frames (new, BLUE, PURPLE, GOLD) |

**Type sizes** (game px): hero names 20, screen titles 14, names and buttons 9, numbers 10, body 7, small 6. Pixel art always at whole-number scale: 16 px icons at 2x in list slots and 3x in grid slots, heroes 3x-3.5x on stages.

## Screens

Seventeen screens, each matched to a PNG in `docs/ui/`. Tab screens have the bottom nav and an outlined title with the coin plate; sub-screens have a back button and no nav.

| Screen | Type | What it holds |
| --- | --- | --- |
| Home (`home.png`) | Tab: Battle | Account badge + Town level bar, coins, settings; district chip and name; left rail Quests (count dot) and Daily gift (AD); right rail weekly event (timer) and No Ads; hero 3.5x on the plinth with critters around it; Unlock rail button when something is ready; large Play |
| Pick a District (`pick-district.png`) | Play step 1 | Step indicator "1 District - 2 Hero"; district card (map thumbnail, boss slot, name, best time, three goals with checks); Danger 1-5 row (locked ones show a lock, a newly opened one a New! sticker, a one-line rule under it); locked districts with their requirement; Next |
| Pick a Hero (`pick-hero.png`) | Play step 2 | Step indicator; hero on the plinth with role chip and name; three hero slots (locked = silhouette "???", not pickable); 4 stat tiles; signature weapon card; summary card "Suburbia - Danger 1" (back to step 1); Start |
| Characters (`characters.png`, `characters-locked.png`, `critters.png`) | Tab | Tabs Heroes / Critters with counts. Heroes: roster, stage, 8 stat tiles (HP, Damage, Speed, Magnet, Armor, Regen, Area, Cooldown), weapon and passive cards. Locked hero: silhouette, "???", stats "?", how to unlock + progress, hire price. Critters: 8-slot bestiary (unseen = "?", boss = purple frame + Boss tag), stage, 4 stats (HP, Damage, Speed, XP), one-line behaviour, first seen, times bonked. No Choose button here |
| Shop (`shop.png`) | Tab | Tabs Upgrades / Actions / Offers; 3-column goods grid (icon on a shelf, name, level pips, price button or Max); No Ads offer window (primary, price from the store) |
| Collection (`collection.png`) | Tab | Collected x/19 bar + "n ready"; detail window (item, kind chip, effect, challenge, bar, Buy); kind tabs with counts and dots; grid of slots (selected, owned with check, ready with green frame and dot, locked silhouette) |
| Quests (`quests.png`) | Sub-screen | Tabs Daily / Weekly / Milestones; daily points window with three chests on a segmented bar and reset timer; quest cards (icon, text, bar, reward or Claim, x/y); claimed ones faded; AD x2 once a day |
| Town (`town.png`) | Tab | Town level + Rebuilt x/12; Patrol card (offline coins, AD x2, Collect); the district map at night with name pins over buildings (built = lit + level, ruined = boarded + dot, locked = lock); selected building window (what it unlocks, its in-run effect, challenge state, Rebuild/Upgrade price) |
| In run (`hud.png`) | HUD | Lamp level badge, segmented XP bar, HP bar with heart and value, timer plate, pause; gold and KO counters; weapon and manual slots with level badges top-left; item pickup card near the top; owned items as a centred row of slots at the bottom (rarity frames, stack count); edge arrows |
| Level Up (`level-up.png`) | Popup | Lamp title plate; three choice cards (kind line, name, effect or before > after, pips with the new pip lit, New sticker); Reroll / Skip / Banish buttons with charges or AD |
| Paused (`paused.png`) | Popup | Time, level, KO; build grid (4 weapons, 4 manuals, level badges); selected slot detail; stats; music and sound buttons; Give Up; Resume (primary) |
| Game Over (`game-over.png`) | Result | Outlined result title + one line; hero hit pose; 4 stat tiles; coins earned + AD x2; "Almost there" (closest challenges with bars); ready-to-unlock card; Home button + Play Again (primary) |
| Merchant (`merchant.png`) | Popup | Title plate; leaves-in timer; your gold; three wares (rarity frame, name, one line, price; too expensive = disabled with red price; bought = Sold stamp); Leave |
| Settings (`settings.png`) | Popup | Music and effects volume, vibration, damage numbers, screen shake, reduce effects; Google Play Games status, Achievements, Leaderboard; Restore purchases; version |
| Unlocked (`unlocked.png`) | Popup | "Unlocked!" over rays; the item at 4x in a slot; name, kind chip, one line, "It can now show up on level-up cards"; Nice! |

In-run notifications: an item pickup shows a card near the top (rarity line, name, one-line effect, stack badge); shrine stat bonuses stay a short toast ("Armor +1") in the same place; several pickups queue one after another. The owned-items row grows upward in new centred rows when it passes six slots.

## New systems

All new content is data in `data/`, like everything else; adding a quest, a building or a danger level needs no code.

**Play flow (two steps)**

1. Play on Home opens Pick a District. Next opens Pick a Hero. Start begins the run.
2. The last district, danger and hero are pre-selected, so a repeat run is Next + Start.
3. Step 1 is skipped while the player owns only Suburbia and Danger 1. It appears from the run after a new district or danger opens, with a New! sticker on it.
4. Back on step 2 returns to step 1; back on step 1 returns to Home. Play Again on Game Over skips both steps.

**Danger levels** (`data/danger/*.json`)

- Danger 1-5 per district. Danger n+1 opens when the boss of that district is beaten on Danger n.
- Each level is a list of modifiers on the existing director numbers (spawn rate, elite interval, enemy HP and damage) plus a coin multiplier. Starting values: elites every 60-90 s at 1 down to 30-45 s at 5; coins x1.0, 1.5, 2.0, 2.5, 3.0. Tune in balance.
- Beating each hero on each danger is a milestone quest.

**Characters and bestiary**

- Heroes: the existing character data. Locked heroes show no stats.
- Critters: an enemy is "seen" the first time one spawns on screen; until then it is a "?" slot. Save per enemy id: first seen (run time), times bonked. Bosses and Overdue Bills count too.
- Each critter entry gets a one-line `desc` in its enemy JSON.

**Quests** (`data/quests/*.json`)

- Reuse the challenge schema (tracked stat, scope run or cumulative, target, prerequisite) and add `kind` (daily, weekly, milestone), `reward` (coins, points) and `repeat`.
- Daily: 3 drawn from a pool at local midnight. Weekly: 5 drawn on Monday. Milestones: permanent tiers (bonk 1,000 / 10,000 / 100,000; open 10 / 100 chests; 500 bonks with each weapon; each hero on each danger). Target 100+ milestones.
- Daily points: each daily quest gives 20 points; chests at 20 / 40 / 60 points.
- One claim a day can be doubled by a rewarded ad.
- Quests should bring about 30-40% of a regular player's coins; runs stay the main source.
- The 19 unlock challenges stay as they are and also pay coins.

**Town (small first version)**

- Home's town is Suburbia. A building is ruined, buildable (its unlock challenge is done) or built; built ones level up.
- First 4 buildings, each wrapping existing content: Bakery (Sir Loaf, Baguette), Pigeon Coop (Turbo Pigeon), Office (Gary), Gym (the Might, Vitality and Sneakers upgrades move here as building levels).
- Each built building adds one thing to runs in Suburbia, placed on its own lot so it never adds clutter (for example the Bakery's bread stall heals 20 HP once per run). The map data gets `"requires": "<building id>"` on props and interactables.
- Ruined art = the same prop drawn darker with boards over it (code overlay), so a building needs one sprite.
- Patrol: built buildings earn coins offline, capped at 8 hours; Collect, or AD x2.
- Town level = buildings built + their levels; it is the account level shown on Home.

**In-run additions**

- Owned items row and the item pickup card (see Screens).
- Merchant window as in `merchant.png`; prices in in-run gold; the stock rolls on arrival.

## Google Play Games and cloud save

The value is cloud save and a weekly leaderboard; achievements are a bonus.

- Plugin candidate: "Google Play Games Services for Godot" (MIT, v3.2.0, Nov 2025; sign-in, achievements, leaderboards, saved games). Claude Code checks it against Godot 4.7.2 and **asks the owner before adding it**, like AdMob and Billing.
- Sign-in is silent at start; the game works fully without it.
- Saved games: the existing versioned JSON save goes up on every run end and on app pause. On conflict keep the save with more total playtime and tell the player in one line.
- Achievements: the 19 unlock challenges plus about 20 milestone quests. IDs live in data, test IDs until the owner creates the real ones.
- Leaderboards: "Longest Final Swarm" (weekly) and "Fastest Mega Mole" (all time).
- Same pattern as ads: a backend interface, a fake backend in debug builds, an inert one in release without the plugin.

## Renames

These names are Megabonk's own words; change the player-facing text only (ids may stay).

| Now | New |
| --- | --- |
| Toggler | Switchboard |
| Tome (anywhere it still shows) | Manual |
| Heroes tab | Characters |
| Unlocks screen | Collection |
| Maps | Districts |

## Phases

Five phases, numbered after the current ones. Each prompt is pasted as it is; each ends with the usual review prompt.

### Phase 10: Game UI kit v2 and restyle

```text
Read docs/BRIEF.md "Update 1" (Game UI kit v2, Screens, Renames) and the PNGs in docs/ui/. Build the kit as reusable parts (window with title plate, card, well, block button in primary / secondary / go / disabled, slot with rarity / sel / ready / locked / empty and badges, bars with seg / go / hp, pips, chips, tabs, bottom nav with five tiles), drawn as 9-slice textures on the palette, and add the new UI tones to assets/palette.png. Switch the UI fonts to Lilita One and Inter. Restyle every existing screen to match its PNG: Home, Shop, Collection, HUD (with the owned-items row and the item pickup card), Level Up, Paused, Game Over, Merchant, Shrine, Unlocked, Settings. Apply the renames. Replace the "UI design direction" section of CLAUDE.md with the kit rules. Done when: each screen is shot with tools/shoot_screens.gd at 540x1170 and checked side by side with its PNG, every shot passes the palette scan, tests pass, and the 300-enemy stress test is within 5% of phase 9.
```

### Phase 11: Play flow, Danger and Characters

```text
Read docs/BRIEF.md "Update 1" (New systems: Play flow, Danger levels, Characters and bestiary). Build Pick a District and Pick a Hero with the skip and remember rules, Danger 1-5 as data with modifiers and coin multipliers, and the Characters tab with Heroes and Critters (bestiary with seen state, first seen, times bonked, locked heroes hidden). Remove hero choice from anywhere else. Done when: a new save goes Home > Pick a Hero > run with no district step; after beating Mega Mole the district step appears with New! on Danger 2; Play Again skips both steps; the bestiary fills in as critters spawn; tests cover each rule.
```

### Phase 12: Quests

```text
Read docs/BRIEF.md "Update 1" (Quests). Add data/quests with daily, weekly and milestone kinds on the challenge schema, the daily points chests, the Quests screen, the Home rail with its count dot, and the once-a-day AD x2 on a claim. Write at least 100 milestones and pools of 15 daily and 15 weekly quests. Done when: dailies roll at local midnight and weeklies on Monday (tested with a fake clock), claims pay once, a 20-run bot simulation reports the share of coins from quests (target 30-40%), and tests pass.
```

### Phase 13: Town, first version

```text
Read docs/BRIEF.md "Update 1" (Town). Build the Town tab on the Suburbia map with 4 buildings (Bakery, Pigeon Coop, Office, Gym) wrapping the existing unlocks and permanent upgrades, ruined / buildable / built states with the code overlay for ruins, building levels, the in-run effect of each built building on its own lot, Patrol offline coins with the 8-hour cap, and Town level on Home. Ask me before any SpriteCook generation. Done when: an existing save migrates (owned content shows as built), each in-run effect works in a run and does not block paths (reachability test), Patrol pays correctly across app restarts, and tests pass.
```

### Phase 14: Google Play Games

```text
Read docs/BRIEF.md "Update 1" (Google Play Games and cloud save). Propose the plugin and wait for my OK. Then add sign-in, saved games, achievements and the two leaderboards behind a backend interface with fake and inert backends, plus the Settings rows. Done when: on the phone, sign-in, a save round trip between two installs, one achievement and one leaderboard score all work with test IDs; without the plugin the game behaves as before; tests pass.
```

## Open decisions for the owner

- [ ] Weekly event: which modifiers (Hot Day: burns +50%, and others) and whether its leaderboard is the Final Swarm one or separate.
- [ ] Daily gift on Home: free once a day, or only through an ad.
- [ ] Town buildings 5-12 and their in-run effects, after testing the first 4.
- [ ] Danger 2-5 numbers and the coin multipliers, after the phase 11 playtest.
- [ ] Whether Remove Ads also gives +25% coins (the original brief left it optional).
- [ ] Real Google Play Games IDs (achievements, leaderboards) once the console entries exist.
