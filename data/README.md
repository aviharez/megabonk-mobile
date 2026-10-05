# data/

All game content lives here as JSON or `.tres`. Adding content must never need a code change.
Planned layout (filled from phase 1 on):

| Folder / file | Content | Phase |
| --- | --- | --- |
| `characters/` | Characters: base stats, signature weapon id, passive | 1, 4 |
| `weapons/` | Weapons: pattern, base stats, per-level modifiers | 1, 2 |
| `tomes/` | Tomes: stat modifiers per level | 2 |
| `items/` | Items: rarity, modifiers, or trigger + chance + effect hooks (format: `scripts/run/item_system.gd`) | 2 |
| `enemies/` | Enemies: role, stats, sprite | 1, 3 |
| `maps/` | Map layout, spawn schedule, SWARM INCOMING, elites, Final Swarm | 3 |
| `interactables/` | Chests, shrines, pots, merchant, cage, altar | 3 |
| `challenges/` | Unlock challenges: id, stat, scope, target, prerequisite, reward, price | 4 |
| `shop/` | Coin shop entries | 4 |
| `rules/run.json` | Run rules: length, enemy/gem caps, slots, XP curve, coins, gem tiers, magnet, fallback cards, gold, shield, burn tick | 1, 2 |
| `rules/loot.json` | Rarities, colors, stacking, legendary limit, luck shift, chest kinds and their rarity weights | 2 |

`export_presets.cfg` includes `data/*` so non-resource JSON files ship in the APK.

Rules for every file: one entry per file, `"id"` equals the file name, colors are palette constant
names from `scripts/core/palette.gd` (for example `"PURPLE"`; `ENEMY_SHOT` is reserved), and numbers
are plain JSON numbers. `GameData` (`scripts/core/game_data.gd`) checks required keys, types, known
roles/patterns/passives/stats, and cross-references, and names the file in every error.
