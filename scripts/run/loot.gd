class_name Loot
extends RefCounted
## Chest rolls. Pure logic for headless tests; rules in data/rules/loot.json.
##
## 1. The chest kind ("paid", "elite", "boss") gives rarity weights. Kinds
##    leave out rarities below their minimum (elite: Rare+, boss: Epic+).
## 2. Luck shifts the odds up: rarity tier i (0 = common) has its weight
##    multiplied by (1 + luck * luck_per_tier) ^ i.
## 3. Rarities with no item left to give are skipped: an item not in the
##    pool, a non-stackable item already held, or a legendary once the run
##    has hit legendary_per_run.
## 4. An item of the rolled rarity is picked uniformly.
## Returns the item id, or "" when nothing at all can drop.


static func roll(rng: RandomNumberGenerator, db: GameData, kind: String, luck: float, held: Dictionary, pool: ContentPool) -> String:
	var rules := db.get_entry("rules", "loot")
	var weights: Dictionary = rules.chests.get(kind, {})
	if weights.is_empty():
		push_error("Loot: unknown chest kind '%s'" % kind)
		return ""
	var by_rarity := available(db, held, pool)
	var tiers: Array = rules.rarities
	var shift := 1.0 + maxf(luck, 0.0) * float(rules.luck_per_tier)
	var w := PackedFloat32Array()
	var total := 0.0
	for i in tiers.size():
		var r: String = tiers[i]
		var x: float = weights.get(r, 0.0) * pow(shift, i) if not by_rarity[r].is_empty() else 0.0
		w.append(x)
		total += x
	if total <= 0.0:
		return ""
	var pick := rng.randf() * total
	for i in tiers.size():
		pick -= w[i]
		if pick < 0.0 and w[i] > 0.0:
			var list: Array = by_rarity[tiers[i]]
			return list[rng.randi_range(0, list.size() - 1)]
	# Float edge: take the last rarity with weight.
	for i in range(tiers.size() - 1, -1, -1):
		if w[i] > 0.0:
			var list: Array = by_rarity[tiers[i]]
			return list[rng.randi_range(0, list.size() - 1)]
	return ""


## rarity -> [item ids] that can still drop, given what the run holds
## (`held`: item id -> stacks).
static func available(db: GameData, held: Dictionary, pool: ContentPool) -> Dictionary:
	var rules := db.get_entry("rules", "loot")
	var out := {}
	for r: String in rules.rarities:
		out[r] = []
	var legendaries := 0
	for id: String in held:
		if db.get_entry("items", id).get("rarity", "") == "legendary":
			legendaries += 1
	for it: Dictionary in db.all("items"):
		if not pool.has(it):
			continue
		var stackable: bool = it.rarity in rules.stackable
		if not stackable and held.has(it.id):
			continue
		if it.rarity == "legendary" and legendaries >= int(rules.legendary_per_run):
			continue
		out[it.rarity].append(it.id)
	return out
