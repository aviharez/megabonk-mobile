extends RefCounted
## The item engine and loot rules with made-up items, so these checks don't
## depend on the real data: stacking, diminishing chances, conditions,
## timers, rarity minimums, luck, legendary limit, the content pool.

const RUN_SCENE := preload("res://scenes/run.tscn")
const DT := 1.0 / 30.0


func _db_with(items: Array) -> GameData:
	var db := GameData.load_from(GameData.ROOT)
	db.entries.items = {}
	for it: Dictionary in items:
		db.entries.items[it.id] = it
	return db


func _item(id: String, rarity: String, extra := {}) -> Dictionary:
	var d := {"id": id, "name": id.to_upper(), "rarity": rarity, "status": "start", "desc": "X"}
	d.merge(extra, true)
	return d


func _start(t, db: GameData) -> Run:
	Run.next_options = {"bot": true, "auto_cards": true, "no_save": true, "seed": 3, "invincible": true}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	run.db = db
	run.items = ItemSystem.new(run, db)
	return run


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_stacked_chance_diminishes(t) -> void:
	t.check(is_equal_approx(ItemSystem.stacked_chance(0.2, 1), 0.2), "1 stack = base")
	t.check(is_equal_approx(ItemSystem.stacked_chance(0.2, 2), 0.36), "2 stacks = 0.36")
	var prev := 0.0
	var prev_gain := 1.0
	var ok := true
	for n in range(1, 30):
		var c := ItemSystem.stacked_chance(0.2, n)
		ok = ok and c > prev and c < 1.0 and c - prev < prev_gain
		prev_gain = c - prev
		prev = c
	t.check(ok, "rises, never reaches 1, each stack adds less")


func test_modifiers_scale_with_stacks(t) -> void:
	var db := _db_with([_item("bar", "common", {"modifiers": [{"stat": "damage", "pct": 0.1}]})])
	var run := _start(t, db)
	run.give_item("bar")
	run.give_item("bar")
	run.give_item("bar")
	t.check(is_equal_approx(run.stat("damage"), 1.3), "3 stacks of +10%% damage, got %s" % run.stat("damage"))
	run.free()


func test_condition_toggles(t) -> void:
	var db := _db_with([_item("angry", "epic", {"conditions": [{"if": "hp_below", "value": 0.3, "stat": "damage", "pct": 0.5}]})])
	var run := _start(t, db)
	run.give_item("angry")
	run.tick(DT)
	t.check(is_equal_approx(run.stat("damage"), 1.0), "off at full HP")
	run.hp = run.stat("max_hp") * 0.2
	run.tick(DT)
	t.check(is_equal_approx(run.stat("damage"), 1.5), "on below 30%%, got %s" % run.stat("damage"))
	run.give_item("angry")
	run.tick(DT)
	t.check(is_equal_approx(run.stat("damage"), 2.0), "2 stacks: +100%%, got %s" % run.stat("damage"))
	run.hp = run.stat("max_hp")
	run.tick(DT)
	t.check(is_equal_approx(run.stat("damage"), 1.0), "off again")
	run.free()


func test_every_timer_and_crit_charge(t) -> void:
	var db := _db_with([_item("clock", "rare", {"triggers": [{"event": "every", "interval": 1.0, "effect": "crit_next", "count": 1}]})])
	var run := _start(t, db)
	run.give_item("clock")
	for i in int(1.05 / DT) + 1:
		run.tick(DT)
	t.check(run.items.crit_charges == 1, "one charge after 1 s, got %d" % run.items.crit_charges)
	for i in int(2.0 / DT):
		run.tick(DT)
	t.check(run.items.crit_charges <= 1, "unused charges don't pile up, got %d" % run.items.crit_charges)
	var crits := []
	run.on_hit.connect(func(_s: int, _a: float, c: bool, _src: String) -> void: crits.append(c))
	var e := run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos() + Vector2(60, 0), 1000, 1, 0)
	run.stats.set_modifier("crit_chance", "test", -1.0)
	run.hit_enemy(e, 1.0, Vector2.ZERO, "test")
	run.hit_enemy(e, 1.0, Vector2.ZERO, "test")
	t.check(crits == [true, false], "charge makes exactly the next hit crit: %s" % [crits])
	run.free()


func test_on_hit_burn_and_kill_events(t) -> void:
	var db := _db_with([
		_item("sauce", "rare", {"triggers": [{"event": "on_hit", "effect": "burn", "dps": 10.0, "duration": 2.0}]}),
		_item("toilet", "epic", {"triggers": [{"event": "on_kill", "elite_only": true, "effect": "stat_boost", "choices": [{"stat": "max_hp", "flat": 10}]}]}),
	])
	var run := _start(t, db)
	run.give_item("sauce")
	run.give_item("toilet")
	var e := run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos() + Vector2(80, 0), 4.0, 1, 0)
	var hp0: float = run.enemies.hp[e]
	run.hit_enemy(e, 1.0, Vector2.ZERO, "test")
	t.check(run.enemies.burn_left[e] > 0.0, "burning")
	for i in int(0.6 / DT):
		run.enemies.move_to(e, run.player_pos() + Vector2(80, 0))
		run.tick(DT)
	t.check(not run.enemies.pool.is_alive(e) or run.enemies.hp[e] < hp0 - 1.0, "burn did damage")
	var before := run.stat("max_hp")
	var normal := run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos() + Vector2(80, 0), 1, 1, 0)
	run.hit_enemy(normal, 999.0, Vector2.ZERO, "test")
	t.check(run.stat("max_hp") == before, "normal kill: no boost")
	var el := run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos() + Vector2(80, 0), 1, 1, 0)
	run.enemies.elite[el] = 1
	run.hit_enemy(el, 999.0, Vector2.ZERO, "test")
	t.check(run.stat("max_hp") == before + 10.0, "elite kill: +10 max HP, got %s" % run.stat("max_hp"))
	run.free()


func test_damaged_blast_and_projectile_duplicate(t) -> void:
	var db := _db_with([
		_item("cushion", "rare", {"triggers": [{"event": "on_damaged", "effect": "blast", "radius": 40.0, "damage": 5.0, "knockback": 100.0}]}),
		_item("clone", "epic", {"triggers": [{"event": "on_projectile", "effect": "duplicate"}]}),
	])
	var run := _start(t, db)
	run.options.invincible = false
	run.give_item("cushion")
	run.give_item("clone")
	var near := run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos() + Vector2(20, 0), 1000, 1, 0)
	run.enemies.spawn(run.enemies.type_index["skitter"], run.player_pos(), 1000, 1, 0)
	run.tick(DT)
	t.check(run.items.fired.get("cushion", 0) == 1, "blast on hit taken")
	t.check(run.enemies.knock[near].length() > 10.0, "nearby enemy pushed")
	var before := run.projectiles.count()
	run.fire_shot({"pos": run.player_pos(), "vel": Vector2(100, 0), "damage": 1.0})
	t.check(run.projectiles.count() == before + 2, "shot cloned (chance 1)")
	run.free()


func test_loot_rarity_floor_and_legendary_limit(t) -> void:
	var db := _db_with([_item("c", "common"), _item("r", "rare"), _item("e", "epic"), _item("l1", "legendary"), _item("l2", "legendary")])
	for it in db.entries.items.values():
		it["modifiers"] = [{"stat": "luck", "flat": 0.1}]
	var pool := ContentPool.new(db)
	var rng := _rng(9)
	var rar := func(id: String) -> String: return db.get_entry("items", id).rarity
	var bad := []
	for i in 300:
		var elite := Loot.roll(rng, db, "elite", 0.0, {}, pool)
		if rar.call(elite) == "common":
			bad.append("elite gave common")
		var boss := Loot.roll(rng, db, "boss", 0.0, {}, pool)
		if rar.call(boss) in ["common", "rare"]:
			bad.append("boss gave " + rar.call(boss))
	t.check(bad.is_empty(), "rarity floors: %s" % [bad.slice(0, 3)])
	for i in 100:
		var id := Loot.roll(rng, db, "boss", 0.0, {"l1": 1}, pool)
		if rar.call(id) == "legendary":
			bad.append("second legendary " + id)
	t.check(bad.is_empty(), "one legendary per run: %s" % [bad.slice(0, 3)])
	var avail := Loot.available(db, {"c": 4}, pool)
	t.check("c" in avail.common, "commons stack")


func test_luck_shifts_odds_up(t) -> void:
	var db := _db_with([_item("c", "common"), _item("r", "rare"), _item("e", "epic"), _item("l", "legendary")])
	var pool := ContentPool.new(db)
	var counts := [0, 0]
	for k in 2:
		var rng := _rng(4)
		for i in 2000:
			var id := Loot.roll(rng, db, "paid", [0.0, 1.0][k], {}, pool)
			if id != "c":
				counts[k] += 1
	t.check(counts[1] > counts[0] * 1.3, "luck 1.0 gives clearly more non-commons: %s" % [counts])
	t.check(counts[0] < 2000 * 0.5, "paid chests are mostly common/rare: %d non-common of 2000" % counts[0])


func test_content_pool_statuses(t) -> void:
	var db := GameData.load_from(GameData.ROOT)
	var pool := ContentPool.new(db, {"x_unlock": "owned", "y_unlock": "available"})
	t.check(pool.has({"id": "a", "status": "start"}), "start is in")
	t.check(pool.has({"id": "x_unlock", "status": "unlock"}), "owned unlock is in")
	t.check(not pool.has({"id": "y_unlock", "status": "unlock"}), "available (not bought) is out")
	t.check(pool.has({"id": "b", "status": "signature", "character": "sir_loaf"}), "start character's signature is in")
	t.check(not pool.has({"id": "c", "status": "signature", "character": "nobody"}), "unowned character's signature is out")
	t.check(ContentPool.new(db, {}, true).has({"id": "z", "status": "unlock"}), "all_content")
