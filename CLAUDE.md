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
