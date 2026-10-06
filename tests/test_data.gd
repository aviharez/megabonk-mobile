extends RefCounted
## data/ loads cleanly, and bad files produce errors that name the file.

const BAD := "user://test_data"


func cleanup() -> void:
	_wipe(BAD)


func test_game_data_loads_without_errors(t) -> void:
	var db := GameData.load_from(GameData.ROOT)
	t.check(db.errors.is_empty(), "data errors: %s" % [db.errors])
	t.check(not db.get_entry("characters", "sir_loaf").is_empty(), "Sir Loaf")
	t.check(not db.get_entry("weapons", "baguette").is_empty(), "Baguette")
	t.check(not db.get_entry("enemies", "blob").is_empty() and not db.get_entry("enemies", "skitter").is_empty(), "Blob and Skitter")
	t.check(db.get_entry("weapons", "baguette").levels.size() == 5, "Baguette has 5 levels")
	t.check(not db.get_entry("rules", "run").is_empty(), "run rules")
	t.check(db.get_entry("rules", "run").run_length_sec == 480.0, "8-minute run")
	t.check(db.get_entry("rules", "run").enemy_cap == 300.0, "300 enemy cap")


func test_bad_files_are_named(t) -> void:
	_wipe(BAD)
	for c in ["enemies", "tomes", "characters", "weapons", "maps"]:
		DirAccess.make_dir_recursive_absolute(BAD.path_join(c))
	_write("enemies/broken.json", "{ nope")
	_write("enemies/no_hp.json", '{"id": "no_hp", "name": "X", "role": "chaser", "speed": 1, "damage": 1, "radius": 1, "xp": 1, "shape": "blob", "color": "RED"}')
	_write("enemies/odd_role.json", '{"id": "odd_role", "name": "X", "role": "dancer", "hp": 1, "speed": 1, "damage": 1, "radius": 1, "xp": 1, "shape": "blob", "color": "RED"}')
	_write("enemies/wrong_name.json", '{"id": "other", "name": "X", "role": "chaser", "hp": 1, "speed": 1, "damage": 1, "radius": 1, "xp": 1, "shape": "blob", "color": "RED"}')
	_write("enemies/magenta.json", '{"id": "magenta", "name": "X", "role": "chaser", "hp": 1, "speed": 1, "damage": 1, "radius": 1, "xp": 1, "shape": "blob", "color": "ENEMY_SHOT"}')
	_write("tomes/typo.json", '{"id": "typo", "name": "X", "status": "start", "group": "offense", "desc": "X", "modifiers_per_level": [{"stat": "damgae", "pct": 0.1}]}')
	_write("maps/m.json", '{"id": "m", "size": [10, 10], "spawns": [{"enemy": "ghost", "from_min": 0, "to_min": 1, "per_sec": [1, 1]}]}')
	var db := GameData.load_from(BAD)
	var all := "\n".join(db.errors)
	for needle in ["broken.json: JSON error", "no_hp.json: missing \"hp\"", "odd_role.json: unknown role", "wrong_name.json: id \"other\"", "magenta.json: unknown palette color", "typo.json: unknown stat \"damgae\"", "m.json: spawn names unknown enemy \"ghost\""]:
		t.check(all.contains(needle), "expected error containing '%s' in:\n%s" % [needle, all])


func _write(rel: String, text: String) -> void:
	var f := FileAccess.open(BAD.path_join(rel), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(d))
	DirAccess.remove_absolute(dir)


## Phase 3 data that used to load "fine" and then crash mid-run: each case
## copies the real data, breaks one thing, and expects an error naming it.
func test_phase3_bad_data_is_caught(t) -> void:
	var cases := [
		["maps/suburbia.json", func(d: Dictionary) -> void: d.swarms[0].erase("spawns"), "each swarm needs a non-empty \"spawns\""],
		["maps/suburbia.json", func(d: Dictionary) -> void: d.final_swarm.spawns[0].erase("from_min"), "needs numbers \"from_min\" and \"to_min\""],
		["maps/suburbia.json", func(d: Dictionary) -> void: d.elites.every_sec = [60], "elites need \"first_sec\" and \"every_sec\""],
		["maps/suburbia.json", func(d: Dictionary) -> void: d.props[0].rect = ["a", 1, 2, 3], "each prop needs"],
		["maps/suburbia.json", func(d: Dictionary) -> void: d.props[0].color = "YELLOW", "unknown prop color \"YELLOW\""],
		["maps/suburbia.json", func(d: Dictionary) -> void: d.ground_colors = ["LEAF", "NOPE"], "unknown ground color \"NOPE\""],
		["interactables/pot.json", func(d: Dictionary) -> void: d.gold = 5, "pot.json: \"gold\" must be [min, max]"],
		["interactables/merchant.json", func(d: Dictionary) -> void: d.prices = [1, 2], "merchant.json: \"prices\" must map rarity"],
		["interactables/merchant.json", func(d: Dictionary) -> void: d.prices.erase("epic"), "\"prices\" needs a number for \"epic\""],
		["interactables/charge_shrine.json", func(d: Dictionary) -> void: d.choices[0].erase("desc"), "charge_shrine.json: each choice needs a \"desc\""],
		["enemies/mega_mole.json", func(d: Dictionary) -> void: d.boss.summon.enemy = "blb", "boss summons unknown enemy \"blb\""],
		["enemies/mega_mole.json", func(d: Dictionary) -> void: d.boss.patterns.append("dance"), "unknown boss pattern \"dance\""],
		["enemies/mega_mole.json", func(d: Dictionary) -> void: d.boss.rocks.erase("gap"), "boss \"rocks\" needs a number \"gap\""],
		["enemies/gnat.json", func(d: Dictionary) -> void: d.sheet = "res://assets/palette.png", "sidecar"],
		["rules/elites.json", func(d: Dictionary) -> void: d.chest = "portal", "\"chest\" must name a free_chest"],
		["rules/bills.json", func(d: Dictionary) -> void: d.enemy = "blob", "bills.json: \"enemy\" must be a ghost"],
	]
	for c: Array in cases:
		_wipe(BAD)
		_copy_tree(GameData.ROOT, BAD)
		var path := BAD.path_join(c[0])
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		c[1].call(d)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		var db := GameData.load_from(BAD)
		var all := "\n".join(db.errors)
		t.check(all.contains(c[2]), "%s: expected an error with '%s', got:\n%s" % [c[0], c[2], all])
	# The untouched copy is clean, so each error above came from its edit.
	_wipe(BAD)
	_copy_tree(GameData.ROOT, BAD)
	t.check(GameData.load_from(BAD).errors.is_empty(), "the copied data alone has no errors")


func test_bad_palette_index_is_not_magenta(t) -> void:
	t.check(Palette.color(-1) == Palette.color(Palette.INK), "an unknown color falls back to INK, never the enemy-shot magenta")


func _copy_tree(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for f in DirAccess.get_files_at(src):
		if f.ends_with(".json"):
			DirAccess.copy_absolute(src.path_join(f), dst.path_join(f))
	for d in DirAccess.get_directories_at(src):
		_copy_tree(src.path_join(d), dst.path_join(d))
