class_name LevelUpCards
extends RefCounted
## Picks the cards offered on level-up. Pure logic for headless tests.
##
## Candidates: upgrades for owned weapons/tomes below max level, plus new
## weapons/tomes while a slot of that kind is free. Only content whose status
## puts it in the pool can appear (phase 4 replaces this with owned content).
## If there are fewer candidates than cards, fallback cards fill the rest.
##
## A card: {"kind": "weapon"|"tome"|"fallback", "id", "level" (level after
## taking it), "is_new", "def"}.

## Statuses that are in the pool before meta progression exists.
const POOL_STATUSES := ["start"]


static func pick(rng: RandomNumberGenerator, db: GameData, owned_weapons: Dictionary, owned_tomes: Dictionary, rules: Dictionary) -> Array:
	var max_level: int = int(rules.max_level)
	var cands := []
	for w: Dictionary in db.all("weapons"):
		var lvl: int = owned_weapons.get(w.id, 0)
		var top := mini(max_level, w.levels.size())
		if lvl > 0 and lvl < top:
			cands.append({"kind": "weapon", "id": w.id, "level": lvl + 1, "is_new": false, "def": w})
		elif lvl == 0 and owned_weapons.size() < int(rules.weapon_slots) and w.status in POOL_STATUSES:
			cands.append({"kind": "weapon", "id": w.id, "level": 1, "is_new": true, "def": w})
	for t: Dictionary in db.all("tomes"):
		var lvl: int = owned_tomes.get(t.id, 0)
		if lvl > 0 and lvl < max_level:
			cands.append({"kind": "tome", "id": t.id, "level": lvl + 1, "is_new": false, "def": t})
		elif lvl == 0 and owned_tomes.size() < int(rules.tome_slots) and t.status in POOL_STATUSES:
			cands.append({"kind": "tome", "id": t.id, "level": 1, "is_new": true, "def": t})

	# Partial Fisher-Yates with the run's RNG (deterministic per seed).
	var n := mini(int(rules.card_count), cands.size())
	for i in n:
		var j := rng.randi_range(i, cands.size() - 1)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var out := cands.slice(0, n)
	var fallbacks: Array = rules.fallback_cards
	var k := 0
	while out.size() < int(rules.card_count) and not fallbacks.is_empty():
		var f: Dictionary = fallbacks[k % fallbacks.size()]
		out.append({"kind": "fallback", "id": f.id, "level": 0, "is_new": false, "def": f})
		k += 1
	return out


## Text shown on a card: title line, then a description line.
static func describe(card: Dictionary) -> PackedStringArray:
	var def: Dictionary = card.def
	match card.kind:
		"weapon":
			var lv: Dictionary = def.levels[card.level - 1]
			return PackedStringArray([
				"%s  %s" % [def.name, "NEW!" if card.is_new else "LV %d" % card.level],
				def.desc if card.is_new else lv.get("desc", "")])
		"tome":
			return PackedStringArray([
				"%s" % def.name,
				"%s  %s" % [def.desc, "NEW!" if card.is_new else "LV %d" % card.level]])
	return PackedStringArray([def.name, def.desc])
