extends RefCounted
## Level-up card rules: 3 distinct cards, slots, max level, fallback.

var db := GameData.shared()
var rules: Dictionary = GameData.shared().get_entry("rules", "run")


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _key(c: Dictionary) -> String:
	return "%s:%s" % [c.kind, c.id]


func test_three_distinct_cards(t) -> void:
	for s in 50:
		var cards := LevelUpCards.pick(_rng(s), db, {"baguette": 1}, {}, rules)
		var keys := {}
		for c in cards:
			keys[_key(c)] = true
		if cards.size() != 3 or keys.size() != 3:
			t.check(false, "seed %d: 3 distinct cards, got %s" % [s, keys.keys()])
	t.check(LevelUpCards.pick(_rng(1), db, {"baguette": 1}, {}, rules).size() == 3, "3 cards")


func test_no_new_tome_when_slots_full(t) -> void:
	var tomes := {}
	for tm in db.all("tomes").slice(0, int(rules.tome_slots)):
		tomes[tm.id] = 1
	for s in 50:
		for c in LevelUpCards.pick(_rng(s), db, {"baguette": 1}, tomes, rules):
			if c.kind == "tome" and not tomes.has(c.id):
				t.check(false, "offered a 5th tome %s" % c.id)
				return
	t.check(true, "slots respected")


func test_maxed_not_offered_and_fallback(t) -> void:
	var tomes := {}
	for tm in db.all("tomes").slice(0, int(rules.tome_slots)):
		tomes[tm.id] = int(rules.max_level)
	var cards := LevelUpCards.pick(_rng(1), db, {"baguette": 5}, tomes, rules)
	t.check(cards.size() == 3, "still 3 cards")
	var all_fallback := true
	for c in cards:
		all_fallback = all_fallback and c.kind == "fallback"
	t.check(all_fallback, "everything maxed gives fallback cards")


func test_upgrade_card_levels(t) -> void:
	var seen := false
	for s in 30:
		for c in LevelUpCards.pick(_rng(s), db, {"baguette": 2}, {}, rules):
			if c.id == "baguette":
				seen = true
				t.check(c.level == 3 and not c.is_new, "baguette 2 -> 3")
	t.check(seen, "baguette upgrade is offered")


func test_describe_fits_card(t) -> void:
	# Card is 160px wide; the pixel font is 6px per character with spacing.
	var too_long := []
	for w in db.all("weapons"):
		for lv in w.levels.size():
			for line in LevelUpCards.describe({"kind": "weapon", "id": w.id, "level": lv + 1, "is_new": lv == 0, "def": w}):
				if line.length() > 26:
					too_long.append(line)
	for tm in db.all("tomes"):
		for line in LevelUpCards.describe({"kind": "tome", "id": tm.id, "level": 5, "is_new": false, "def": tm}):
			if line.length() > 26:
				too_long.append(line)
	t.check(too_long.is_empty(), "card lines too long: %s" % [too_long])
