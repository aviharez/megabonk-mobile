extends Node
## Versioned JSON save in user:// (autoload "Save").
##
## - Every save file carries "version". On load, older files run through
##   _migrate_vN() steps up to SAVE_VERSION, then missing keys are filled
##   from default_data(). Adding a new key with a default needs no version
##   bump; renaming, moving or retyping a key does (add a _migrate_vN).
## - Writes go to a temp file first, the previous good save is kept as .bak.
## - A corrupt file is set aside (".corrupt") and the .bak is tried.
## - A file from a newer game version is never overwritten.

signal saved
signal loaded

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://save.json"

var path := DEFAULT_PATH
var data: Dictionary = {}
## True when the file on disk came from a newer build; saving is blocked.
var read_only := false


static func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": 0,
		"runs_played": 0,
		"settings": {
			"music": true,
			"sfx": true,
			"damage_numbers": true,
			"screen_shake": true,
			"reduce_effects": false,
		},
		# Cumulative stat tracker totals, keyed by stat id (phase 4).
		"stats": {},
		# Unlock state per content id: "available" or "owned" (phase 4).
		"unlocks": {},
		# Coin shop purchases, keyed by shop item id (phase 4).
		"shop": {},
		# Ad pacing, daily reward, Remove Ads (phase 5).
		"ads": {},
	}


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func load_game() -> void:
	read_only = false
	var result := _read(path)
	if result.status == "missing":
		data = default_data()
	elif result.status == "ok":
		data = result.data
	else:
		push_warning("Save: %s is unreadable, setting it aside and trying the backup" % path)
		_set_aside(path)
		var bak := _read(path + ".bak")
		data = bak.data if bak.status == "ok" else default_data()

	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("Save: file version %d is newer than %d, not overwriting it" % [version, SAVE_VERSION])
		read_only = true
	else:
		data = _migrate(data, version)
	data = _merge_defaults(data, default_data())
	loaded.emit()


func save_game() -> bool:
	if read_only or data.is_empty():
		return false
	data.version = SAVE_VERSION
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save: can't write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Save: can't move %s into place (%s)" % [tmp, error_string(err)])
		return false
	saved.emit()
	return true


## Deletes the save and its backup and starts fresh. Debug / settings use only.
func reset() -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	read_only = false
	data = default_data()
	save_game()


func get_setting(key: String) -> Variant:
	return data.settings.get(key, default_data().settings.get(key))


func set_setting(key: String, value: Variant) -> void:
	data.settings[key] = value
	save_game()


func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"status": "missing"}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(p)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"status": "corrupt"}
	return {"status": "ok", "data": json.data}


func _set_aside(p: String) -> void:
	DirAccess.rename_absolute(p, p + ".corrupt")


func _migrate(d: Dictionary, from_version: int) -> Dictionary:
	# Version 0 means a file with no version field; treat it as v1.
	var v := maxi(from_version, 1)
	while v < SAVE_VERSION:
		var step := "_migrate_v%d" % v
		assert(has_method(step), "Save: missing migration " + step)
		d = call(step, d)
		v += 1
	d.version = SAVE_VERSION
	return d


# Example for the next format change:
# func _migrate_v1(d: Dictionary) -> Dictionary:
# 	d.coins = d.get("gold", 0); d.erase("gold")
# 	return d


## Fills keys missing from `d` with defaults (recursively) and restores
## numeric types JSON loses (ints come back as floats).
static func _merge_defaults(d: Dictionary, defaults: Dictionary) -> Dictionary:
	for key in defaults:
		var def: Variant = defaults[key]
		if not d.has(key):
			d[key] = def.duplicate(true) if def is Dictionary else def
		elif def is Dictionary and d[key] is Dictionary:
			d[key] = _merge_defaults(d[key], def)
		elif def is int and d[key] is float:
			d[key] = int(d[key])
		elif typeof(def) != typeof(d[key]):
			d[key] = def.duplicate(true) if def is Dictionary else def
	return d
