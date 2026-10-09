# data/

All game content lives here as JSON or `.tres`. Adding content must never need a code change.
Planned layout (filled from phase 1 on):

| Folder / file | Content | Phase |
| --- | --- | --- |
| `characters/` | Characters: "status" ("start" or "unlock"), base stats, signature weapon id, passive (id + its numbers: `getting_stale`, `speed_damage`, `overtime`; behavior in `scripts/run/passives.gd`), optional "sheets" by clip (`idle` required, `walk`, `hit`; `res://assets/characters/*.png` + sidecar from `tools/spritecook_shrink.py`), else a code-drawn fallback | 1, 4, 6 |
| `weapons/` | Weapons: pattern, base stats, per-level modifiers | 1, 2 |
| `tomes/` | Tomes: stat modifiers per level | 2 |
| `items/` | Items: rarity, modifiers, or trigger + chance + effect hooks (format: `scripts/run/item_system.gd`) | 2 |
| `enemies/` | Enemies: role (chaser, pack, shooter, exploder, charger, swarm, ghost, boss), stats, role numbers ("shot", "explode", "charge", "boss"), placeholder shape or animated "sheet" (`res://assets/creatures/<id>.png` + sidecar .json from `tools/palette_snap.py`) | 1, 3 |
| `maps/` | Map size and "props" (road, garden, house, fence, hedge, pond, tree; solid ones block walkers), spawn schedule, "swarms" (SWARM INCOMING), "elites", "final_swarm" (own schedule, endless escalation, coin multiplier, Overdue Bills), "interactables" to place, "merchant" timing, boss hint minute. Read by `Director` and `MapLayout` | 1, 3 |
| `interactables/` | Map objects: "behavior" (paid_chest, free_chest, pot, charge_shrine, risk_shrine, challenge_shrine, merchant, cage, key, altar, portal) + its numbers, look, "arrow" color. Used by touching or standing in them (`Interactables`) | 3 |
| `challenges/` | Unlock challenges: "tier" (early, mid, hard), "desc", tracked "stat" (one the run records, listed in `Meta.STATS`), optional "weapon" / "character" filter, "scope" ("run" = in one run, "total" = over all runs), "target", optional "goal": "at_most" (best run at or below the target), "requires" (content id that must be owned, or ""), "reward" (a character, weapon, tome or item with status "unlock"), "price" in coins. Every unlock content needs exactly one challenge. Rules in `scripts/core/meta.gd` | 4 |
| `shop/` | Coin shop entries: "kind" "action" (Reroll, Skip, Banish: "action", "charges" per run per level; Skip also "gold"), "toggler" ("charges" = how much can be off at once), or "stat" ("modifiers_per_level"); "prices" one per level; optional "needs": {"runs": n} or {"unlocks": n} | 4 |
| `rules/run.json` | Run rules: length, enemy/gem caps, slots, XP curve, coins, gem tiers, magnet, fallback cards, gold, shield, burn tick | 1, 2 |
| `rules/loot.json` | Rarities, colors, stacking, legendary limit, luck shift, chest kinds (paid, elite, boss, merchant) and their rarity weights | 2, 3 |
| `rules/elites.json` | Elite scaling (HP, damage, 2x size, knockback taken, XP), the chest they drop, cage key chance and pity, and the traits (Fast, Shielded, Splitting, Vicious) as speed/damage/HP multipliers, shield share, split count, outline color | 3 |

`export_presets.cfg` includes `data/*` so non-resource JSON files ship in the APK.

Rules for every file: one entry per file, `"id"` equals the file name, colors are palette constant
names from `scripts/core/palette.gd` (for example `"PURPLE"`; `ENEMY_SHOT` is reserved), and numbers
are plain JSON numbers. `GameData` (`scripts/core/game_data.gd`) checks required keys, types, known
roles/patterns/passives/stats, and cross-references, and names the file in every error.
