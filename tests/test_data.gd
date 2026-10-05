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
