extends RefCounted
## Phase 2 acceptance: every MVP weapon, tome and item from docs/BRIEF.md is
## in data/, matches the brief's tables, can appear on a level-up card or in a
## chest, and applies in a real run without errors. tools/run_tests.sh fails
## on any script error, so "without errors" is covered by running it.

const RUN_SCENE := preload("res://scenes/run.tscn")
const DT := 1.0 / 30.0

## Brief: General weapons table + signature weapons from the Characters table.
const WEAPONS := {
	"baguette": {"status": "signature", "character": "sir_loaf"},
	"sharp_feathers": {"status": "signature", "character": "turbo_pigeon"},
	"stapler": {"status": "signature", "character": "gary"},
	"rubber_duck": {"status": "start"},
	"hot_coffee": {"status": "start"},
	"stinky_socks": {"status": "start"},
	"garden_gnomes": {"status": "start"},
	"leaf_blower": {"status": "unlock"},
	"faulty_toaster": {"status": "unlock"},
	"fireworks": {"status": "unlock"},
}
## Brief: Tomes table. "stats": the stats its effect must touch.
const TOMES := {
	"muscle_magazine": {"group": "offense", "status": "start", "stats": ["damage"]},
	"speed_reading": {"group": "offense", "status": "start", "stats": ["cooldown"]},
	"eye_exercises": {"group": "offense", "status": "start", "stats": ["crit_chance"]},
	"think_big": {"group": "offense", "status": "start", "stats": ["area"]},
	"copy_machine_manual": {"group": "offense", "status": "unlock", "stats": ["projectiles"]},
	"grandmas_soup_recipes": {"group": "defense", "status": "start", "stats": ["max_hp"]},
	"power_nap_guide": {"group": "defense", "status": "start", "stats": ["regen"]},
	"dodgeball_rules": {"group": "defense", "status": "start", "stats": ["evasion"]},
	"bubble_wrap_crafts": {"group": "defense", "status": "unlock", "stats": ["armor"]},
	"tin_foil_hat_theories": {"group": "defense", "status": "unlock", "stats": ["shield"]},
	"cardio_is_life": {"group": "utility", "status": "start", "stats": ["move_speed"]},
	"coupon_clipping": {"group": "utility", "status": "start", "stats": ["gold_gain"]},
	"fridge_magnets": {"group": "utility", "status": "unlock", "stats": ["pickup_range"]},
	"self_help_book": {"group": "utility", "status": "unlock", "stats": ["xp_gain"]},
	"lottery_tips": {"group": "utility", "status": "unlock", "stats": ["luck"]},
	"cursed_diary": {"group": "risk", "status": "unlock", "stats": ["enemy_hp", "enemy_damage", "enemy_spawn_rate", "xp_gain", "gold_gain"]},
}
## Brief: Items table. "stats" = modifiers it must have; "event"/"effect" =
## the trigger it must have; "condition" = the stat its condition boosts.
const ITEMS := {
	"energy_drink": {"rarity": "common", "status": "start", "stats": ["move_speed", "cooldown"]},
	"protein_bar": {"rarity": "common", "status": "start", "stats": ["damage"]},
	"band_aid": {"rarity": "common", "status": "start", "stats": ["max_hp", "regen"]},
	"rubber_boots": {"rarity": "common", "status": "start", "stats": ["contact_damage_taken"]},
	"lucky_penny": {"rarity": "common", "status": "start", "stats": ["luck"]},
	"magnet_keychain": {"rarity": "common", "status": "start", "stats": ["pickup_range"]},
	"hot_sauce": {"rarity": "rare", "status": "start", "event": "on_hit", "effect": "burn"},
	"whoopee_cushion": {"rarity": "rare", "status": "start", "event": "on_damaged", "effect": "blast"},
	"static_sweater": {"rarity": "rare", "status": "unlock", "event": "on_attack", "effect": "zap"},
	"pinata": {"rarity": "rare", "status": "unlock", "event": "on_kill", "effect": "gold"},
	"alarm_clock": {"rarity": "rare", "status": "unlock", "event": "every", "effect": "crit_next", "interval": 20.0},
	"clone_machine": {"rarity": "epic", "status": "unlock", "event": "on_projectile", "effect": "duplicate"},
	"angry_neighbor": {"rarity": "epic", "status": "unlock", "condition": "damage"},
	"golden_toilet": {"rarity": "epic", "status": "unlock", "event": "on_kill", "effect": "stat_boost"},
	"microwave_meltdown": {"rarity": "legendary", "status": "unlock", "event": "every", "effect": "blast", "interval": 60.0},
}
## Stats where lower is better for the player.
const LOWER_IS_BETTER := ["cooldown", "contact_damage_taken"]

var db := GameData.load_from(GameData.ROOT)
var rules: Dictionary = GameData.shared().get_entry("rules", "run")


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _start(t, extra := {}) -> Run:
	var o := {"bot": true, "auto_cards": true, "no_save": true, "seed": 11, "invincible": true, "all_content": true}
	o.merge(extra, true)
	Run.next_options = o
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	return run


func _ring(run: Run, n: int, dist: float, hp_mult := 1000.0) -> Array:
	var out := []
	var type_id: int = run.enemies.type_index["skitter"]
	for i in n:
		out.append(run.enemies.spawn(type_id, run.player_pos() + Vector2.from_angle(i * TAU / n) * dist, hp_mult, 1, 0))
	return out


func _mod_stats(mods: Array) -> Array:
	return mods.map(func(m: Dictionary) -> String: return m.stat)


# --- Loads and matches the brief --------------------------------------------

func test_counts_and_no_errors(t) -> void:
	t.check(db.errors.is_empty(), "data errors: %s" % [db.errors])
	t.check(db.entries.weapons.size() == 10, "10 weapons, got %d" % db.entries.weapons.size())
	t.check(db.entries.tomes.size() == 16, "16 tomes, got %d" % db.entries.tomes.size())
	t.check(db.entries.items.size() == 15, "15 items, got %d" % db.entries.items.size())
	var sig := db.all("weapons").filter(func(w: Dictionary) -> bool: return w.status == "signature")
	t.check(sig.size() == 3, "3 signature + 7 general weapons")


func test_weapons_match_brief(t) -> void:
	var bad := []
	for id: String in WEAPONS:
		var w := db.get_entry("weapons", id)
		if w.is_empty():
			bad.append("%s missing" % id)
			continue
		var want: Dictionary = WEAPONS[id]
		if w.status != want.status or w.get("character", "") != want.get("character", ""):
			bad.append("%s status/character" % id)
		if w.levels.size() != int(rules.max_level):
			bad.append("%s has %d levels" % [id, w.levels.size()])
	# Every weapon attacks differently: no two share a pattern.
	var patterns := {}
	for w: Dictionary in db.all("weapons"):
		if patterns.has(w.pattern):
			bad.append("%s and %s share pattern %s" % [w.id, patterns[w.pattern], w.pattern])
		patterns[w.pattern] = w.id
	t.check(bad.is_empty(), "weapons vs brief: %s" % [bad])


func test_tomes_match_brief(t) -> void:
	var bad := []
	for id: String in TOMES:
		var tm := db.get_entry("tomes", id)
		if tm.is_empty():
			bad.append("%s missing" % id)
			continue
		var want: Dictionary = TOMES[id]
		if tm.group != want.group or tm.status != want.status:
			bad.append("%s group/status" % id)
		var stats := _mod_stats(tm.modifiers_per_level)
		for s: String in want.stats:
			if not s in stats:
				bad.append("%s doesn't touch %s" % [id, s])
	t.check(bad.is_empty(), "tomes vs brief: %s" % [bad])


func test_items_match_brief(t) -> void:
	var bad := []
	for id: String in ITEMS:
		var it := db.get_entry("items", id)
		if it.is_empty():
			bad.append("%s missing" % id)
			continue
		var want: Dictionary = ITEMS[id]
		if it.rarity != want.rarity or it.status != want.status:
			bad.append("%s rarity/status" % id)
		var stats := _mod_stats(it.get("modifiers", []))
		for s: String in want.get("stats", []):
			if not s in stats:
				bad.append("%s has no %s modifier" % [id, s])
		if want.has("event"):
			var found := false
			for tr: Dictionary in it.get("triggers", []):
				if tr.event == want.event and tr.effect == want.effect and (not want.has("interval") or is_equal_approx(tr.get("interval", 0.0), want.interval)):
					found = true
			if not found:
				bad.append("%s needs %s -> %s" % [id, want.event, want.effect])
		if want.has("condition"):
			var conds: Array = it.get("conditions", [])
			if conds.is_empty() or conds[0].stat != want.condition or not is_equal_approx(conds[0].value, 0.3):
				bad.append("%s needs a below-30%%-HP %s condition" % [id, want.condition])
	t.check(bad.is_empty(), "items vs brief: %s" % [bad])
	var ge: Dictionary = db.get_entry("items", "golden_toilet")
	for tr: Dictionary in ge.get("triggers", []):
		t.check(tr.get("elite_only", false), "Golden Toilet only counts elite kills")


func test_text_fits_the_pixel_font(t) -> void:
	var allowed := " !\"#%'()+,-./0123456789:<=>?ABCDEFGHIJKLMNOPQRSTUVWXYZ_"
	var bad := []
	var texts := []
	for w: Dictionary in db.all("weapons"):
		texts.append([w.id, w.name, 20])
		texts.append([w.id, w.desc, 26])
		for lv: Dictionary in w.levels:
			texts.append([w.id, lv.desc, 26])
	for tm: Dictionary in db.all("tomes"):
		texts.append([tm.id, tm.name, 26])
		texts.append([tm.id, tm.desc, 20])
	for it: Dictionary in db.all("items"):
		texts.append([it.id, it.name, 20])
		texts.append([it.id, it.desc, 26])
	for x: Array in texts:
		var s: String = x[1]
		if s.length() > x[2]:
			bad.append("%s: '%s' longer than %d" % x)
		for ch in s:
			if not allowed.contains(ch):
				bad.append("%s: '%s' has '%s'" % [x[0], s, ch])
				break
	t.check(bad.is_empty(), "text problems: %s" % [bad])


# --- Can appear on level-up cards and in chests -----------------------------

func test_every_weapon_and_tome_can_be_offered(t) -> void:
	var everything := ContentPool.new(db, {}, true)
	var seen := {}
	for s in 600:
		for c in LevelUpCards.pick(_rng(s), db, {"baguette": 1}, {}, rules, everything):
			seen[c.id] = true
	var missing := []
	for w: Dictionary in db.all("weapons"):
		if w.id != "baguette" and not seen.has(w.id):
			missing.append(w.id)
	for tm: Dictionary in db.all("tomes"):
		if not seen.has(tm.id):
			missing.append(tm.id)
	t.check(missing.is_empty(), "never offered as a new card: %s" % [missing])


func test_default_pool_holds_only_start_content(t) -> void:
	var start := ContentPool.new(db)
	var leaked := {}
	for s in 600:
		for c in LevelUpCards.pick(_rng(s), db, {"baguette": 1}, {}, rules, start):
			if c.is_new and c.def.status != "start":
				leaked[c.id] = true
	t.check(leaked.is_empty(), "locked content offered without owning it: %s" % [leaked.keys()])
	var owned := ContentPool.new(db, {"fireworks": "owned", "gary": "owned"})
	var got := {}
	for s in 600:
		for c in LevelUpCards.pick(_rng(s), db, {"baguette": 1}, {}, rules, owned):
			got[c.id] = true
	t.check(got.has("fireworks") and got.has("stapler"), "owning Fireworks / Gary puts Fireworks / Stapler in the pool")
	t.check(not got.has("sharp_feathers") and not got.has("leaf_blower"), "unowned stays out")


func test_every_item_can_drop_from_a_chest(t) -> void:
	var everything := ContentPool.new(db, {}, true)
	var seen := {}
	var rng := _rng(2)
	for kind: String in ["paid", "elite", "boss"]:
		for i in 1500:
			seen[Loot.roll(rng, db, kind, 0.5, {}, everything)] = true
	var missing := []
	for it: Dictionary in db.all("items"):
		if not seen.has(it.id):
			missing.append(it.id)
	t.check(missing.is_empty(), "never dropped: %s" % [missing])
	var start_only := ContentPool.new(db)
	var leaked := {}
	for i in 1500:
		var id := Loot.roll(rng, db, "paid", 0.0, {}, start_only)
		if id != "" and db.get_entry("items", id).status != "start":
			leaked[id] = true
	t.check(leaked.is_empty(), "locked items from chests without owning them: %s" % [leaked.keys()])


# --- Slot and rarity rules ---------------------------------------------------

func test_slot_rules(t) -> void:
	var four := {"baguette": 1, "rubber_duck": 1, "hot_coffee": 1, "stinky_socks": 1}
	var tomes := {"muscle_magazine": 5, "speed_reading": 2, "think_big": 1, "eye_exercises": 3}
	var everything := ContentPool.new(db, {}, true)
	var bad := []
	for s in 300:
		for c in LevelUpCards.pick(_rng(s), db, four, tomes, rules, everything):
			if c.kind == "weapon" and not four.has(c.id):
				bad.append("5th weapon " + c.id)
			if c.kind == "tome" and not tomes.has(c.id):
				bad.append("5th tome " + c.id)
			if c.kind != "fallback" and c.level > int(rules.max_level):
				bad.append("past max level " + c.id)
			if c.id == "muscle_magazine":
				bad.append("maxed tome offered")
	t.check(bad.is_empty(), "4 weapon / 4 tome slots, level 5 max: %s" % [bad.slice(0, 4)])


func test_rarity_rules_in_a_run(t) -> void:
	var run := _start(t)
	var bad := []
	for i in 200:
		var id := run.open_chest("elite")
		if id != "" and db.get_entry("items", id).rarity == "common":
			bad.append("elite chest gave common " + id)
	for i in 60:
		var id := run.open_chest("boss")
		if id != "" and db.get_entry("items", id).rarity in ["common", "rare"]:
			bad.append("boss chest gave " + id)
	var legend := 0
	for id: String in run.items.stacks:
		if db.get_entry("items", id).rarity == "legendary":
			legend += run.items.stacks[id]
		elif run.items.stacks[id] > 1:
			pass  # stacking allowed below legendary
	t.check(bad.is_empty(), "chest floors: %s" % [bad.slice(0, 3)])
	t.check(legend <= 1, "at most one legendary per run, got %d" % legend)
	var stacked := false
	for id: String in run.items.stacks:
		stacked = stacked or run.items.stacks[id] > 1
	t.check(stacked, "Common to Epic items stack")
	run.free()


# --- Every entry applies -----------------------------------------------------

func test_every_tome_applies_at_every_level(t) -> void:
	var run := _start(t)
	var bad := []
	for tm: Dictionary in db.all("tomes"):
		var want: Array = TOMES.get(tm.id, {}).get("stats", _mod_stats(tm.modifiers_per_level))
		var base := {}
		for s: String in want:
			base[s] = run.stat(s)
		var prev := base.duplicate()
		for lvl in range(1, int(rules.max_level) + 1):
			run.apply_card({"kind": "tome", "id": tm.id, "level": lvl, "is_new": lvl == 1, "def": tm})
			for s: String in want:
				var v := run.stat(s)
				var better: bool = v < prev[s] if s in LOWER_IS_BETTER else v > prev[s]
				# Caps may stop a stat early; it must never go the wrong way.
				var capped: bool = is_equal_approx(v, prev[s])
				if not better and not capped:
					bad.append("%s L%d: %s %s -> %s" % [tm.id, lvl, s, prev[s], v])
				prev[s] = v
		for s: String in want:
			if is_equal_approx(prev[s], base[s]):
				bad.append("%s never changed %s" % [tm.id, s])
		run.stats.remove_source("tome:" + tm.id)
		run.tick(DT)
	t.check(bad.is_empty(), "tome effects: %s" % [bad])
	run.free()


func test_every_weapon_runs_at_every_level(t) -> void:
	var bad := []
	for w: Dictionary in db.all("weapons"):
		for lvl in [1, 3, 5]:
			var run := _start(t, {"loadout": {"weapons": {w.id: lvl}}})
			var hits := [0]
			run.on_hit.connect(func(_s: int, _a: float, _c: bool, src: String) -> void:
				if src == w.id:
					hits[0] += 1)
			var ring := _ring(run, 10, 26.0)
			for i in int(4.0 / DT):
				for k in ring.size():
					if run.enemies.pool.is_alive(ring[k]):
						run.enemies.move_to(ring[k], run.player_pos() + Vector2.from_angle(k * TAU / ring.size()) * 26.0)
				run.tick(DT)
				run._render()
			if hits[0] == 0:
				bad.append("%s L%d hit nothing" % [w.id, lvl])
			run.free()
	t.check(bad.is_empty(), "weapons: %s" % [bad])


## Every item in one long run, 3 stacks each (the legendary once), with the
## events its trigger needs: hits, kills, an elite kill, damage taken, low
## HP, projectiles, and 61 s for the 60 s timer.
func test_every_item_applies(t) -> void:
	var run := _start(t, {"loadout": {"weapons": {"stapler": 3, "faulty_toaster": 1}}})
	var before := {}
	for s: String in StatBlock.NAMES:
		before[s] = run.stat(s)
	for it: Dictionary in db.all("items"):
		for k in (1 if it.rarity == "legendary" else 3):
			run.give_item(it.id)
	var bad := []
	for id: String in ITEMS:
		for s: String in ITEMS[id].get("stats", []):
			var v := run.stat(s)
			var better: bool = v < before[s] if s in LOWER_IS_BETTER else v > before[s]
			if not better:
				bad.append("%s: %s %s -> %s" % [id, s, before[s], v])
	# Take hits with a big HP pool so the run survives a minute of contact.
	run.options.invincible = false
	run.stats.set_modifier("max_hp", "test", 1.0e6)
	run.stats.set_modifier("evasion", "test", -1.0)
	run.hp = run.stat("max_hp")
	var hits := [0]
	run.on_hit.connect(func(_s: int, _a: float, _c: bool, _src: String) -> void: hits[0] += 1)
	var elite_done := false
	for i in int(61.5 / DT):
		if run.enemies.count() < 30:
			_ring(run, 12, 24.0, 3.0)
		if not elite_done and i == 60:
			var e := run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos() + Vector2(20, 0), 1, 1, 0)
			run.enemies.elite[e] = 1
			run.hit_enemy(e, 999.0, Vector2.ZERO, "test")
			elite_done = true
		if i == 90:
			run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos(), 1000, 1, 0)
		if i == 120:
			run.hp = run.stat("max_hp") * 0.1
		run.tick(DT)
		run._render()
		if i == 121:
			t.check(run.items.is_condition_on("angry_neighbor"), "Angry Neighbor on below 30% HP")
		if run.state != "live":
			bad.append("run ended at %d" % i)
			break
	for id: String in ITEMS:
		if ITEMS[id].has("event") and run.items.fired.get(id, 0) == 0:
			bad.append("%s never fired" % id)
	t.check(hits[0] > 0 and run.kills > 0, "the run fought (%d hits, %d kills)" % [hits[0], run.kills])
	t.check(run.gold > 0.0, "gold collected")
	t.check(bad.is_empty(), "item effects: %s" % [bad])
	run.free()
