# Project: pixel survivor-like for mobile (working title)

The full spec is in docs/BRIEF.md. The brief is the source of truth for content and technical rules.

## How to work
- When a step doesn't need my input, keep going. Put status notes in the same message as your next action.
- Stop and ask only when you can't continue without me, or before anything destructive: deleting data or assets, force-pushing, or changing anything outside this repository.
- Keep the current phase's checklist in TASKS.md. Tick each item when it's done, and add anything new you find.
- For large work that splits cleanly (for example, writing many data entries or auditing many files), give each part to its own subagent and check its evidence before you accept it.
- End every run with three headings: Blocked on me, Changed, Found. Mark anything you couldn't confirm, and say where you looked.

## Technical rules
- Godot 4.7, GDScript, Compatibility renderer, portrait 180x320 minimum view (stretch aspect expand: taller screens see more), canvas_items stretch mode, integer scaling, Nearest texture filter. During a run the world is drawn in its own view at a smaller whole-number scale (rules "world_view_scale" 2.0: about 2x more map), while menus, HUD and cards keep the UI scale.
- All content is data in data/. Adding content must not require code changes.
- Stats are base value + modifiers. Item effects use event hooks (on_hit, on_kill, on_damaged, etc.).
- Pool enemies, projectiles, gems, damage numbers, and particles. Max about 300 enemies on screen.
- Built from scratch. Ask before adding any third-party plugin (AdMob, IAP, or anything else). Saves are versioned JSON in user://.
- Pause the game while an ad plays. Grant rewarded-ad rewards only after the reward callback.

## Assets
- Every asset uses the palette in assets/palette.png. No off-palette colors, no off-grid pixels.
- SpriteCook: ask me before every generation, log estimated credits in docs/ASSET_LOG.md, no variations by default.
- Don't use names, characters, or assets from other games.
- Creatures (player, enemies, boss) are one family of mutant critters: 1 px INK outline, big eyes, 2-3 tone shading lit from the top left, one colour per enemy role, no green on enemies. Player ~24 px, regular enemies 12-20 px, Gnat 6-8 px. Static sprites; motion is code (`data/rules/creature_motion.json`). Full rules: docs/BRIEF.md "Creature art rules".

## UI design direction (Game UI kit v2)
The UI is one night-blue design system (docs/BRIEF.md "Update 1"; screens match the PNGs in docs/ui/). Every UI part is a physical, outlined object, so the full-colour heroes, critters and items are what the eye lands on.
- Parts are 9-slice textures drawn by `tools/art/kit_v2.py` into `assets/ui/kit/` and used through `UiArt` (window, plate, card, well, slot, button, bar2, pips, sticker, badge, chip, dot, toggle). Never code-draw a plate a kit part covers.
- 1 px INK outline on every window, card, button, slot, bar, badge and sticker, plus a solid INK drop straight down (3 px under windows and buttons, 2 under cards, slots and plates). Square corners. No soft shadows, gradients, glow, glass or alpha.
- Windows: INK outline, a 3 px frame band lit top-left (FRAME_HI) and shaded bottom-right (FRAME_LO), an inner INK line, the SURFACE / SURFACE_2 hatch, four bolts. Modal windows hang a title plate over the top edge (lamp only on Level Up). Icons, stat tiles and bar tracks sit in sunken wells.
- Buttons are blocks (top and bottom bevel, 2x2 shine, white outlined label). One lamp (GOLD) primary per screen; everything else is the blue secondary; green go only for AD x2 rewards; disabled is flat.
- Colour means something: lamp = primary action, active nav tile, progress, selected slot, level badge, coins. go = ready, done, claimable. alert = notification dots and HP only. Rarity colours (R_COMMON, BLUE, PURPLE, GOLD) = item slot rings only. Kind is a muted text line plus the icon, never a card colour.
- Text: Lilita One for titles, names, numbers and button labels, with a 1 game px INK outline and drop; Inter 800 for body text, never outlined, never under 6 px. Sizes (game px): hero names 20, screen titles 14, names and buttons 9, numbers 10, body 7, small 6. Styles by name in `Fonts.STYLES`, never by number.
- Bottom nav: five icon tiles (Shop, Characters, Battle, Town, Collection); only the current tile is labelled and rises in lamp. Tab screens have the outlined title and coin plate; sub-screens have a Back bar and no nav.
- Menus sit over the night town backdrop (`assets/ui/home/backdrop_night.png`); in-run panels over the map dimmed by DitherDim. Pixel art at whole-number scales only (16 px icons 1x in HUD slots, 2x on cards and grids; heroes 3x on stages).
- Little text: kind, rarity and New are shown by colour and stickers, not words. Don't use emoji as icons or colours outside the palette.

## Verification
- Before calling a phase done, run the project and the existing tests. Report fps with 300 enemies on screen.
