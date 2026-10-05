extends RefCounted
## Save system: round trip, defaults, types, corruption, versions.

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const PATH := "user://test_save.json"


func _fresh() -> Node:
	cleanup()
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	return s


func cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt", ".bak.corrupt"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_missing_file_gives_defaults(t) -> void:
	var s := _fresh()
	t.check(s.data.version == SaveManager.SAVE_VERSION, "version set")
	t.check(s.data.coins == 0 and s.data.settings.music == true, "defaults present")
	s.free()


func test_round_trip_keeps_values_and_int_types(t) -> void:
	var s := _fresh()
	s.data.coins = 1234
	s.data.runs_played = 7
	s.data.settings.screen_shake = false
	t.check(s.save_game(), "save ok")
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	t.check(int(json.version) == SaveManager.SAVE_VERSION, "file carries version")
	s.load_game()
	t.check(s.data.coins == 1234 and typeof(s.data.coins) == TYPE_INT, "coins int after reload")
	t.check(s.data.runs_played == 7, "runs kept")
	t.check(s.data.settings.screen_shake == false, "setting kept")
	s.free()


func test_missing_keys_filled_from_defaults(t) -> void:
	_write('{"version": 1, "coins": 5, "settings": {"music": false}}')
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	t.check(s.data.coins == 5, "kept coins")
	t.check(s.data.settings.music == false, "kept music")
	t.check(s.data.settings.sfx == true, "filled sfx")
	t.check(s.data.has("unlocks"), "filled unlocks")
	s.free()


func test_unversioned_file_is_migrated(t) -> void:
	_write('{"coins": 3}')
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	t.check(s.data.version == SaveManager.SAVE_VERSION and s.data.coins == 3, "v0 upgraded")
	s.free()


func test_corrupt_file_falls_back_to_backup(t) -> void:
	var s := _fresh()
	s.data.coins = 50
	s.save_game()
	s.data.coins = 60
	s.save_game()  # .bak now holds 50
	_write("{ not json")
	s.load_game()
	t.check(s.data.coins == 50, "restored from .bak, got %s" % s.data.coins)
	t.check(FileAccess.file_exists(PATH + ".corrupt"), "corrupt file set aside")
	s.free()


func test_corrupt_without_backup_gives_defaults(t) -> void:
	cleanup()
	_write("garbage")
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	t.check(s.data.coins == 0, "defaults")
	s.free()


func test_newer_version_is_not_overwritten(t) -> void:
	cleanup()
	var future := '{"version": 999, "coins": 77}'
	_write(future)
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	t.check(s.read_only, "read only")
	t.check(not s.save_game(), "save refused")
	t.check(FileAccess.get_file_as_string(PATH) == future, "file untouched")
	s.free()


func test_wrong_type_replaced_by_default(t) -> void:
	_write('{"version": 1, "settings": "oops"}')
	var s: Node = SaveManager.new()
	s.path = PATH
	s.load_game()
	t.check(s.data.settings is Dictionary and s.data.settings.music == true, "settings repaired")
	s.free()
