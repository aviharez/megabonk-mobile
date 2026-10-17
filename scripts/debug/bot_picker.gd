class_name BotPicker
extends RefCounted
## How a sim bot chooses level-up cards and beacon bonuses (Run option
## "bot_picker"). Two players for the balance sim (docs/BALANCE.md):
##
## - "typical": a casual player. Takes cards half at random, with a lean
##   towards new weapons and upgrades of what it has; never rerolls; random
##   beacon bonus.
## - "good": builds on purpose. Fills the weapon slots, levels weapons, takes
##   damage-side manuals first and one or two defence manuals, rerolls a
##   hand with nothing useful while charges last; beacon: damage first.
##
## Neither prefers one weapon over another (the sim reports which weapons
## win, so the bot must not pick them by name).

const OFFENCE := ["damage", "cooldown", "area", "projectiles", "crit_chance"]
const DEFENCE := ["max_hp", "armor", "shield", "regen", "evasion"]
const UTILITY := ["pickup_range", "xp_gain", "move_speed"]
const BONUS_ORDER := ["damage", "cooldown", "area", "max_hp", "crit_chance", "armor", "regen", "move_speed", "pickup_range", "luck"]

var skill := "typical"
var rng := RandomNumberGenerator.new()


func _init(kind := "typical", seed_value := 1) -> void:
	skill = kind
	rng.seed = seed_value


func pick_card(run: Node, cards: Array) -> int:
	if skill == "good":
		return _pick_good(run, cards)
	return _pick_typical(run, cards)


func pick_choice(_run: Node, opts: Array) -> int:
	if skill != "good":
		return rng.randi_range(0, opts.size() - 1)
	var best := 0
	var best_rank := 1 << 20
	for i in opts.size():
		var r := BONUS_ORDER.find(String(opts[i].get("stat", "")))
		r = r if r >= 0 else BONUS_ORDER.size()
		if r < best_rank:
			best_rank = r
			best = i
	return best


func _pick_typical(run: Node, cards: Array) -> int:
	var weights := []
	var total := 0.0
	for c: Dictionary in cards:
		var w := 1.0
		match c.kind:
			"weapon":
				w = 3.0 if c.is_new and run.owned_weapons.size() < 3 else 2.0
			"tome":
				w = 1.5 if c.is_new else 1.6
			_:
				w = 0.3
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


func _pick_good(run: Node, cards: Array) -> int:
	var best := 0
	var best_score := -INF
	for i in cards.size():
		var s := _score(run, cards[i])
		if s > best_score:
			best_score = s
			best = i
	# Nothing worth a slot or a level: reroll (Run rerolls while charges last).
	if best_score < 4.0 and int(run.charges.get("reroll", 0)) > 0:
		return -1
	return best


func _score(run: Node, c: Dictionary) -> float:
	match c.kind:
		"weapon":
			if c.is_new:
				return 9.0
			return 8.0 + c.level * 0.5
		"tome":
			var stats := []
			for m: Dictionary in c.def.get("modifiers_per_level", []):
				stats.append(m.stat)
			if "enemy_hp" in stats:
				return 1.0  # Cursed Diary: harder runs for a good player too
			var defence := 0
			for id: String in run.owned_tomes:
				var t: Dictionary = run.db.get_entry("tomes", id)
				for m: Dictionary in t.get("modifiers_per_level", []):
					if m.stat in DEFENCE:
						defence += 1
						break
			var stat: String = stats[0] if not stats.is_empty() else ""
			var base := 2.0
			if stat in OFFENCE:
				base = 7.0
			elif stat in DEFENCE:
				base = 6.5 if defence < 1 or not c.is_new else 3.0
			elif stat in UTILITY:
				base = 4.5
			return base + (0.0 if c.is_new else 1.0 + c.level * 0.3)
	return 0.5
