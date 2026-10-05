extends SceneTree
## Loads data/ with the game's validation and prints every error.
##   godot --headless --path . -s res://tools/check_data.gd
## Exit code 0 = no errors. Also prints entry counts per category.


func _initialize() -> void:
	var db := GameData.load_from(GameData.ROOT)
	for c: String in db.entries:
		print("%s: %d" % [c, db.entries[c].size()])
	for e in db.errors:
		printerr("DATA ERROR " + e)
	print("%d data errors" % db.errors.size())
	quit(1 if db.errors.size() > 0 else 0)
