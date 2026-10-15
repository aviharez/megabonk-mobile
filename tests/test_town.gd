extends RefCounted
## Phase 13 (docs/BRIEF.md "Update 1", Town): buildings as data wrapping the
## unlocks and the Gym's upgrades, ruined / buildable / built and levels, an
## old save migrating (owned content shows as built), each built building's
## in-run object working on its lot without blocking a path (reachability),
## Patrol paying across app restarts with the 8-hour cap, the Town level on
## Home, and the Town tab.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://test_town.json"
const MENU := "res://scenes/main_menu.tscn"
const RUN_SCENE := preload("res://scenes/run.tscn")
const DT := 1.0 / 30.0
const HOUR := 3600

var db := GameData.load_from(GameData.ROOT)


func cleanup() -> void:
	Town.clock = Town.system_clock
	for p in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".corrupt"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _save() -> Node:
	var s: Node = SaveManager.new()
	s.path = PATH
	s.data = SaveManager.default_data()
	return s


## A save with every building built (coins to spare), through the rules.
func _all_built() -> Dictionary:
	var d := SaveManager.default_data()
	d.coins = 100000
	for id in ["turbo_pigeon", "gary"]:
		d.unlocks[id] = "available"
	for b: Dictionary in Town.buildings(db):
		if not Town.is_built(db, d, b.id):
			Town.build(db, d, b.id, 1000)
	return d


# --- Data ---------------------------------------------------------------------

func test_buildings_are_data(t) -> void:
	t.check(db.errors.is_empty(), "data loads clean (%s)" % [db.errors])
	var ids := Town.buildings(db).map(func(b: Dictionary) -> String: return b.id)
	t.check(ids == ["bakery", "pigeon_coop", "office", "gym"], "the first four buildings in Town order (%s)" % [ids])
	t.check(Town.building(db, "bakery").unlocks == ["sir_loaf", "baguette"], "Bakery wraps Sir Loaf and the Baguette")
	t.check(Town.building(db, "pigeon_coop").unlocks[0] == "turbo_pigeon", "Pigeon Coop wraps Turbo Pigeon")
	t.check(Town.building(db, "office").unlocks[0] == "gary", "Office wraps Gary")
	t.check(Town.building(db, "gym").shop == ["might", "vitality", "sneakers"], "Gym takes the three upgrades")
	var map := db.get_entry("maps", "suburbia")
	var lots := Town.lots(map)
	for id: String in ids:
		var b := Town.building(db, id)
		t.check(lots.has(id), "%s stands on Suburbia" % id)
		var it: Dictionary = map.interactables.filter(func(e: Dictionary) -> bool: return e.id == b.interactable).front()
		t.check(it.get("requires", "") == id and it.has("at"), "%s's object is on its own lot, only once built" % id)
		t.check(db.get_entry("interactables", b.interactable).behavior == "town", "%s's object runs the town behavior" % id)
		t.check(Town.effect_text(b, 1).find("{") < 0 and Town.effect_text(b, 1) != "", "%s says what it does: %s" % [id, Town.effect_text(b, 1)])
		t.check(Town.sprite_image(b.sprite) != null, "%s has its sprite" % id)
	var reqs: Array = map.props.filter(func(p: Dictionary) -> bool: return p.has("requires"))
	t.check(reqs.size() == 4, "each lot has one prop that needs its building (%d)" % reqs.size())
	t.check(map.props.filter(func(p: Dictionary) -> bool: return p.kind == "building").size() == 4, "and one building prop each")


func test_bad_building_data_is_caught(t) -> void:
	var bad := GameData.new()
	bad.entries = db.entries.duplicate()
	var both := Town.building(db, "gym").duplicate(true)
	both._file = "buildings/gym.json"
	both.unlocks = ["gary"]
	both.levels[0].effect = {"teleport": true}
	both.levels[1].erase("price")
	bad._check_building(both)
	var text := "\n".join(bad.errors)
	t.check(text.contains("not both"), "unlocks and shop together are an error")
	t.check(text.contains("unknown \"teleport\""), "an unknown effect is an error")
	t.check(text.contains("level 2 needs a whole coin \"price\""), "an upgrade without a price is an error")
	var map := db.get_entry("maps", "suburbia").duplicate(true)
	map._file = "maps/suburbia.json"
	map.props.append({"kind": "driveway", "rect": [0.0, 0.0, 8.0, 8.0], "requires": "castle"})
	map.props.append({"kind": "building", "rect": [0.0, 0.0, 8.0, 8.0], "building": "castle"})
	bad.errors.clear()
	bad._check_map(map)
	text = "\n".join(bad.errors)
	t.check(text.contains("unknown building \"castle\"") and text.contains("needs \"building\""), "a map naming an unknown building is an error")


# --- States, levels and the Town level ----------------------------------------

func test_states_follow_the_unlocks(t) -> void:
	var d := SaveManager.default_data()
	t.check(Town.state(db, d, "bakery") == "built" and Town.level(db, d, "bakery") == 1, "Bakery: Sir Loaf is start content, so it starts built")
	t.check(Town.state(db, d, "pigeon_coop") == "ruined", "Pigeon Coop: ruined until its challenge is done")
	t.check(Town.state(db, d, "gym") == "buildable", "Gym: buildable from the start (like the upgrades it took over)")
	t.check(Town.town_level(db, d) == 1, "Town level 1 on a new save")
	t.check(not Town.build(db, d, "pigeon_coop"), "a ruined building can't be rebuilt")
	d.unlocks["turbo_pigeon"] = "available"
	t.check(Town.state(db, d, "pigeon_coop") == "buildable", "challenge done: buildable")
	var price := int(Meta.challenge_for(db, "turbo_pigeon").price)
	t.check(Town.price(db, d, "pigeon_coop") == price, "rebuilding costs the unlock's price (%d)" % price)
	d.coins = price - 1
	t.check(not Town.build(db, d, "pigeon_coop"), "not without the coins")
	d.coins = price + 500
	t.check(Town.build(db, d, "pigeon_coop"), "rebuilt")
	t.check(Meta.is_owned(db, d, "turbo_pigeon") and Meta.is_owned(db, d, "sharp_feathers"), "rebuilding it is buying Turbo Pigeon (and his feathers)")
	t.check(int(d.coins) == 500 and Town.level(db, d, "pigeon_coop") == 1, "paid once, level 1")
	t.check(Town.price(db, d, "pigeon_coop") == int(Town.building(db, "pigeon_coop").levels[1].price), "next: the level 2 price")
	t.check(Town.build(db, d, "pigeon_coop") and Town.level(db, d, "pigeon_coop") == 2, "upgraded to 2")
	d.coins = 99999
	t.check(Town.build(db, d, "pigeon_coop") and Town.level(db, d, "pigeon_coop") == 3, "and 3")
	t.check(Town.price(db, d, "pigeon_coop") == -1 and not Town.build(db, d, "pigeon_coop"), "3 is the top")
	t.check(Town.town_level(db, d) == 1 + 3, "Town level = buildings built + their levels (Bakery 1 + Coop 3 = %d)" % Town.town_level(db, d))
	# Buying in the Collection rebuilds it too: one action.
	var d2 := SaveManager.default_data()
	d2.unlocks["gary"] = "available"
	d2.coins = 1000
	Meta.buy(db, d2, "gary")
	t.check(Town.state(db, d2, "office") == "built", "buying Gary in the Collection rebuilds the Office")
	t.check(Town.affordable(db, d2).map(func(b: Dictionary) -> String: return b.id).has("gym"), "the nav dot counts what can be paid for")


func test_the_gym_holds_the_upgrades(t) -> void:
	var d := SaveManager.default_data()
	d.coins = 10000
	t.check(not Meta.buy_shop(db, d, "might"), "Might isn't sold in the Shop any more")
	t.check(Town.build(db, d, "gym") and Town.level(db, d, "gym") == 1, "building the Gym is level 1")
	t.check(Town.build(db, d, "gym") and Town.level(db, d, "gym") == 2, "and it levels up")
	var bonus := Town.stat_bonuses(db, d)
	var srcs := bonus.map(func(b: Array) -> String: return b[0])
	t.check(srcs == ["shop:might", "shop:vitality", "shop:sneakers"] and bonus.all(func(b: Array) -> bool: return b[2] == 2),
			"each Gym level gives a level of Might, Vitality and Sneakers (%s)" % [srcs])
	d.shop["might"] = 4  # a stray old shop level is never counted twice
	t.check(Meta.stat_bonuses(db, d).all(func(b: Array) -> bool: return not b[0] in srcs), "the Shop's bonuses leave them out")
	# In a run: damage and max HP follow the Gym level.
	var s := _save()
	s.data = d
	Run.next_options = {"save": s, "no_spawns": true, "seed": 3, "auto_cards": true, "invincible": true}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	var base: float = db.get_entry("characters", run.char_def.id).stats.max_hp
	t.check(is_equal_approx(run.stat("max_hp"), base + 12.0), "Gym 2: max HP +12 in the run (%.1f)" % run.stat("max_hp"))
	run.free()
	s.free()


func test_shop_screen_hides_the_gym_upgrades(t) -> void:
	var s := _save()
	var shop := ShopScreen.new(s)
	t.root.add_child(shop)
	await t.process_frame
	t.check(shop.find_child("might", true, false) == null and shop.find_child("vitality", true, false) == null, "no Might / Vitality cards")
	t.check(shop.find_child("magnetism", true, false) != null, "the other upgrades stay")
	shop.free()
	s.free()


# --- Migration ----------------------------------------------------------------

func test_an_old_save_migrates(t) -> void:
	cleanup()
	var old := {
		"version": 1, "coins": 321, "runs_played": 14,
		"unlocks": {"turbo_pigeon": "owned", "gary": "available", "fireworks": "owned"},
		"shop": {"might": 3, "vitality": 1, "reroll": 2},
		"stats": {"kills": 5000.0},
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	var d: Dictionary = s.data
	t.check(int(d.version) == SaveManager.SAVE_VERSION and SaveManager.SAVE_VERSION == 2, "migrated to version 2")
	t.check(Town.state(db, d, "bakery") == "built", "Bakery built (Sir Loaf)")
	t.check(Town.state(db, d, "pigeon_coop") == "built", "owned Turbo Pigeon shows the Pigeon Coop built")
	t.check(Town.state(db, d, "office") == "buildable", "Gary ready to buy: the Office can be rebuilt")
	t.check(Town.level(db, d, "gym") == 3, "the Gym takes the highest of the old upgrade levels (Might 3)")
	t.check(not d.shop.has("might") and not d.shop.has("vitality") and int(d.shop.reroll) == 2, "the moved upgrades leave the shop, the rest stay")
	t.check(int(d.coins) == 321 and Meta.is_owned(db, d, "fireworks"), "coins and other unlocks kept")
	t.check(Town.town_level(db, d) == 1 + 1 + 3, "Town level 5")
	t.check(s.save_game(), "and it saves")
	var again: Node = SaveManager.new()
	again.path = PATH
	again.load_game()
	t.check(Town.level(db, again.data, "gym") == 3, "still level 3 after a reload")
	s.free()
	again.free()
	cleanup()


# --- Patrol ----------------------------------------------------------------------

func test_patrol_pays_across_restarts(t) -> void:
	cleanup()
	var clock := [1_800_000_000]
	Town.clock = func() -> int: return clock[0]
	var s := _save()
	var d: Dictionary = s.data
	var rate := Town.patrol_rate(db, d)
	t.check(rate == float(Town.building(db, "bakery").levels[0].patrol), "a new save earns the Bakery's %d/h" % int(rate))
	t.check(Town.patrol_pending(db, d) == 0, "nothing before Patrol starts")
	Town.start_patrol(db, d)
	s.save_game()
	s.free()
	# The app closes; 3 hours later it opens again.
	clock[0] += 3 * HOUR
	s = SaveManager.new()
	s.path = PATH
	s.load_game()
	d = s.data
	t.check(Town.patrol_pending(db, d) == int(rate * 3), "3 h away: %d coins (%d)" % [int(rate * 3), Town.patrol_pending(db, d)])
	clock[0] += 20 * HOUR
	t.check(Town.patrol_pending(db, d) == Town.patrol_cap(db, d) and Town.patrol_cap(db, d) == int(rate * 8), "capped at 8 hours (%d)" % Town.patrol_cap(db, d))
	t.check(Town.patrol_full_in(db, d) == 0, "full")
	var c0 := int(d.coins)
	var got := Town.collect(db, d)
	t.check(got == int(rate * 8) and int(d.coins) == c0 + got, "Collect pays it")
	t.check(Town.patrol_pending(db, d) == 0, "and starts again from zero")
	s.save_game()
	s.free()
	s = SaveManager.new()
	s.path = PATH
	s.load_game()
	d = s.data
	t.check(int(d.coins) == c0 + got and Town.patrol_pending(db, d) == 0, "the payment and the restart survive a restart")
	clock[0] += HOUR
	t.check(Town.collect(db, d, 2) == int(rate) * 2, "AD x2 doubles it")
	# A clock set back pays nothing (and Patrol restarts from the new time).
	clock[0] -= 5 * HOUR
	t.check(Town.patrol_pending(db, d) == 0, "a clock set back earns nothing")
	clock[0] += 2 * HOUR
	t.check(Town.patrol_pending(db, d) == 0, "nor until it passes the last collect again")
	# An upgrade banks the hours walked at the old rate.
	clock[0] += 10 * HOUR
	Town.collect(db, d)
	clock[0] += 2 * HOUR
	d.coins = 99999
	var r1 := Town.patrol_rate(db, d)
	Town.build(db, d, "bakery")
	var r2 := Town.patrol_rate(db, d)
	t.check(r2 > r1, "an upgrade raises the rate (%d > %d)" % [int(r2), int(r1)])
	t.check(Town.patrol_pending(db, d) == int(r1 * 2), "the 2 hours before it pay the old rate")
	clock[0] += HOUR
	t.check(Town.patrol_pending(db, d) == int(r1 * 2 + r2), "then the new rate")
	s.free()
	cleanup()


# --- The map: lots and reachability ------------------------------------------

## Cells reachable from the player's start by walking (4 neighbours, not solid).
func _reachable(layout: MapLayout, start: Vector2) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(layout.cols * layout.rows)
	var q := [int(start.y / MapLayout.CELL) * layout.cols + int(start.x / MapLayout.CELL)]
	seen[q[0]] = 1
	while not q.is_empty():
		var c: int = q.pop_back()
		var cx := c % layout.cols
		var cy := c / layout.cols
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cx + n.x
			var ny := cy + n.y
			if nx < 0 or ny < 0 or nx >= layout.cols or ny >= layout.rows:
				continue
			var k := ny * layout.cols + nx
			if seen[k] == 0 and layout.blocked[k] == 0:
				seen[k] = 1
				q.append(k)
	return seen


func test_lots_never_block_a_path(t) -> void:
	var raw := db.get_entry("maps", "suburbia")
	var start := Vector2(raw.size[0], raw.size[1]) / 2.0
	var none := MapLayout.new()
	none.setup(Town.resolve_map(db, SaveManager.default_data(), raw))
	var all_d := _all_built()
	t.check(Town.built_count(db, all_d) == 4, "every building built for this check")
	var all := MapLayout.new()
	var resolved := Town.resolve_map(db, all_d, raw)
	all.setup(resolved)
	t.check(none.blocked == all.blocked, "building every lot adds no solid cell (a building stands on a house's footprint)")
	var reach := _reachable(all, start)
	var reach0 := _reachable(none, start)
	t.check(reach == reach0, "the same cells are walkable from the start with or without the Town")
	for b: Dictionary in Town.buildings(db):
		var it: Dictionary = resolved.interactables.filter(func(e: Dictionary) -> bool: return e.id == b.interactable).front()
		var at := Vector2(it.at[0], it.at[1])
		var def := db.get_entry("interactables", b.interactable)
		t.check(all.is_area_free(at, float(def.radius)), "%s's object stands clear of solid props" % b.id)
		var cell := int(at.y / MapLayout.CELL) * all.cols + int(at.x / MapLayout.CELL)
		t.check(reach[cell] == 1, "%s's object can be walked to from the start" % b.id)
		var lot: Rect2 = Town.lots(resolved)[b.id]
		t.check(lot.position.distance_to(at) < 60.0, "and stands on its building's lot")
	none.free()
	all.free()


## Objects within `r` of any Town lot's object spot.
func _near_lots(run: Run, r: float) -> Array:
	var spots := []
	for it: Dictionary in db.get_entry("maps", "suburbia").interactables:
		if it.has("requires"):
			spots.append(Vector2(it.at[0], it.at[1]))
	return run.interactables.list.filter(func(o: Dictionary) -> bool:
		return spots.any(func(p: Vector2) -> bool: return p.distance_to(o.pos) < r))


func test_lots_in_a_run(t) -> void:
	# A new save: only the Bakery's stall, and chests and pots keep off the empty lots.
	Run.next_options = {"no_save": true, "no_spawns": true, "seed": 11, "auto_cards": true, "invincible": true}
	var run: Run = RUN_SCENE.instantiate()
	t.root.add_child(run)
	var near := _near_lots(run, 20.0).map(func(o: Dictionary) -> String: return o.id)
	t.check(near == ["bread_stall"], "new save: the bread stall alone on the lots, nothing else on them (%s)" % [near])
	t.check(run.interactables.find("pigeon_loft").is_empty(), "no pigeon loft before the Coop is rebuilt")
	run.free()
	var s := _save()
	s.data = _all_built()
	for seed_i in [1, 2, 3]:
		Run.next_options = {"save": s, "no_spawns": true, "seed": seed_i, "auto_cards": true, "invincible": true}
		run = RUN_SCENE.instantiate()
		t.root.add_child(run)
		near = _near_lots(run, 20.0).map(func(o: Dictionary) -> String: return o.id)
		near.sort()
		t.check(near == ["bread_stall", "coffee_machine", "pigeon_loft", "pullup_bar"], "seed %d: all four objects on their lots, nothing else there (%s)" % [seed_i, near])
		run.free()
	s.free()


# --- In-run effects ----------------------------------------------------------

func _built_run(t, levels := {}) -> Run:
	var s := _save()
	s.data = _all_built()
	for id: String in levels:
		s.data.town.levels[id] = levels[id]
	Run.next_options = {"save": s, "no_spawns": true, "seed": 5, "auto_cards": true, "invincible": true}
	var run: Run = RUN_SCENE.instantiate()
	run.set_meta("test_save", s)
	t.root.add_child(run)
	return run


func _done(run: Run) -> void:
	var s: Node = run.get_meta("test_save")
	run.free()
	s.free()


func _touch(run: Run, o: Dictionary) -> void:
	run.teleport(o.pos + Vector2(80, 0))
	run.tick(DT)
	run.teleport(o.pos)
	run.tick(DT)


func _step(run: Run, seconds: float) -> void:
	for i in int(seconds / DT):
		run.tick(DT)


func test_bread_stall_heals_once(t) -> void:
	var run := _built_run(t)
	var o := run.interactables.find("bread_stall")
	run.hp = 10.0
	_touch(run, o)
	var heal := float(Town.effect_at(Town.building(db, "bakery"), 1).heal)
	t.check(is_equal_approx(run.hp, minf(10.0 + heal, run.stat("max_hp"))) or run.hp >= 10.0 + heal - 0.5, "the stall heals %d HP (%.1f)" % [int(heal), run.hp])
	t.check(o.used, "once per run")
	run.hp = 10.0
	_touch(run, o)
	t.check(run.hp < 10.0 + heal - 1.0, "a second touch does nothing")
	_done(run)


func test_bakery_level_heals_more(t) -> void:
	var run := _built_run(t, {"bakery": 3})
	run.hp = 5.0
	_touch(run, run.interactables.find("bread_stall"))
	var heal := float(Town.building(db, "bakery").levels[2].effect.heal)
	t.check(run.hp >= 5.0 + heal - 0.5, "Bakery 3 heals %d (%.1f)" % [int(heal), run.hp])
	_done(run)


func test_coffee_machine_and_pullup_bar_buff_for_a_while(t) -> void:
	var run := _built_run(t)
	var cd0 := run.stat("cooldown")
	var dmg0 := run.stat("damage")
	_touch(run, run.interactables.find("coffee_machine"))
	t.check(run.stat("cooldown") < cd0 - 0.01, "coffee: cooldowns shorter (%.3f < %.3f)" % [run.stat("cooldown"), cd0])
	_touch(run, run.interactables.find("pullup_bar"))
	t.check(run.stat("damage") > dmg0 + 0.01, "pull-up bar: more damage (%.3f > %.3f)" % [run.stat("damage"), dmg0])
	t.check(run.interactables.buffs.size() == 2, "two buffs running")
	_step(run, 31.0)
	t.check(is_equal_approx(run.stat("cooldown"), cd0) and is_equal_approx(run.stat("damage"), dmg0), "both wear off after 30 s")
	t.check(run.interactables.buffs.is_empty(), "and leave the list")
	_done(run)


func test_pigeon_loft_fetches_gems(t) -> void:
	var run := _built_run(t, {"pigeon_coop": 2})
	var loft := run.interactables.find("pigeon_loft")
	run.teleport(loft.pos + Vector2(80, 0))
	run.tick(DT)
	var far := [Vector2(100, 100), Vector2(1300, 1600), Vector2(1200, 200)]
	for p: Vector2 in far:
		run.gems.drop(p, 5.0)
	var xp0: float = run.xp + run.level * 1000.0
	t.check(run.gems.count() == 3, "three gems far away")
	run.teleport(loft.pos)
	run.tick(DT)
	_step(run, 8.0)
	t.check(run.gems.count() == 0, "the pigeons bring every gem to the player (%d left)" % run.gems.count())
	t.check(run.xp + run.level * 1000.0 > xp0, "and their XP counts")
	t.check(not loft.used and float(loft.wait) > 0.0, "Coop 2: a second use after the recharge")
	run.gems.drop(Vector2(100, 100), 5.0)
	run.teleport(loft.pos + Vector2(80, 0))
	run.tick(DT)
	run.teleport(loft.pos)
	run.tick(DT)
	t.check(run.gems.count() == 1, "stepping on it while it recharges does nothing")
	_step(run, float(Town.effect_at(Town.building(db, "pigeon_coop"), 2).recharge_sec))
	_touch(run, loft)
	t.check(loft.used, "the second use spends it")
	_done(run)


# --- Home and the Town tab -----------------------------------------------------

func _menu(t, data: Dictionary) -> Control:
	var save: Node = t.root.get_node("Save")
	save.set_meta("old", [save.path, save.data])
	save.path = PATH
	save.data = data
	var menu: Control = load(MENU).instantiate()
	t.root.add_child(menu)
	await t.process_frame
	return menu


func _menu_done(t, menu: Control) -> void:
	menu.queue_free()
	await t.process_frame
	var save: Node = t.root.get_node("Save")
	var old: Array = save.get_meta("old")
	save.path = old[0]
	save.data = old[1]
	save.remove_meta("old")


func _until(t, cond: Callable, sec := 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await t.process_frame
	return cond.call()


func test_home_and_town_tab(t) -> void:
	cleanup()
	var clock := [1_800_000_000]
	Town.clock = func() -> int: return clock[0]
	var data := SaveManager.default_data()
	data.coins = 1000
	data.unlocks["turbo_pigeon"] = "available"
	data.town.patrol = {"since": clock[0] - 2 * HOUR, "banked": 0.0}
	var menu := await _menu(t, data)
	var nav: BottomNav = menu.find_children("*", "BottomNav", true, false).front()
	t.check(not nav.locked.get("town", false), "the Town tile is open")
	t.check(nav.dots.get("town", false), "with a dot: something can be rebuilt")
	var info: Control = menu.find_child("TownLevel", true, false)
	t.check(info != null and menu.find_child("Account", true, false) != null, "Home shows the account badge and Town level")
	(menu.find_child("Account", true, false) as KitButton).pressed.emit()
	await t.process_frame
	var town: TownScreen = menu.find_children("*", "TownScreen", true, false).front()
	t.check(town != null and nav.current == "town", "the badge opens the Town tab")
	t.check(town.selected == "pigeon_coop", "it opens on the building that can be rebuilt")
	var street: TownView = town.find_child("Street", true, false)
	t.check(street != null and street.hit(street.pin_rect("pigeon_coop").get_center()) == "pigeon_coop", "its pin is tappable")
	# Patrol: 2 hours of the Bakery.
	var collect: PixelButton = town.find_child("Collect", true, false)
	var rate := Town.patrol_rate(db, data)
	var c0 := int(data.coins)
	collect.pressed.emit()
	t.check(int(data.coins) == c0 + int(rate * 2), "Collect pays 2 hours of Patrol (+%d)" % int(rate * 2))
	t.check(collect.disabled, "then it's empty")
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	t.check(int(on_disk.coins) == int(data.coins), "and saves")
	# Rebuild the Pigeon Coop from its window.
	var build: BaseButton = town.find_child("Build", true, false)
	t.check(build != null and not build.disabled, "Rebuild is ready")
	build.pressed.emit()
	await t.process_frame
	t.check(Town.is_built(db, data, "pigeon_coop") and Meta.is_owned(db, data, "turbo_pigeon"), "Rebuild builds it and hires Turbo Pigeon")
	t.check(not menu.find_children("*", "UnlockPopup", true, false).is_empty(), "with the Unlocked! reveal")
	for p in menu.find_children("*", "UnlockPopup", true, false):
		p.queue_free()
	# A ruined one: Rebuild off, its challenge shown.
	town.select("office")
	await t.process_frame
	var off: BaseButton = town.find_child("Build", true, false)
	t.check(off != null and off.disabled, "a ruined building can't be rebuilt yet")
	# AD x2 on Patrol through the Ads autoload (fake backend in debug builds).
	clock[0] += HOUR
	town.call("_refresh_patrol")
	var ads: Node = t.root.get_node_or_null("Ads")
	var dbl: AdButton = town.find_child("Double", true, false)
	if ads != null and await _until(t, func() -> bool: return ads.can_offer("patrol_double")):
		town.call("_refresh_patrol")
		t.check(dbl.visible, "AD x2 shows with coins waiting and an ad ready")
		var pend := Town.patrol_pending(db, data)
		var c1 := int(data.coins)
		dbl.pressed.emit()
		await _until(t, func() -> bool: return int(data.coins) > c1)
		t.check(int(data.coins) == c1 + pend * 2, "the ad pays Patrol twice (+%d)" % (pend * 2))
		await _until(t, func() -> bool: return not ads.is_showing())
		t.check(not t.paused, "the game resumes after the ad")
	else:
		t.check(false, "no rewarded ad became ready for patrol_double")
	nav.picked.emit("battle")
	await t.process_frame
	t.check(int(Town.town_level(db, data)) == 2, "Town level 2 now")
	await _menu_done(t, menu)
	cleanup()
