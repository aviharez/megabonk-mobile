class_name GameData
extends RefCounted
## Loads every JSON file under data/<category>/ into memory and validates it.
## Each file holds one entry with a unique "id". Errors name the file, so a bad
## data edit is easy to find. Adding content = adding a file; no code changes.
##
##   var db := GameData.load_from("res://data")
##   db.get_entry("enemies", "blob")

const ROOT := "res://data"

## Required keys and their JSON types per category. Extra keys are allowed.
const SCHEMA := {
	"characters": {"id": TYPE_STRING, "name": TYPE_STRING, "signature_weapon": TYPE_STRING, "stats": TYPE_DICTIONARY, "radius": TYPE_FLOAT, "passive": TYPE_DICTIONARY},
	"weapons": {"id": TYPE_STRING, "name": TYPE_STRING, "pattern": TYPE_STRING, "status": TYPE_STRING, "levels": TYPE_ARRAY},
	"enemies": {"id": TYPE_STRING, "name": TYPE_STRING, "role": TYPE_STRING, "hp": TYPE_FLOAT, "speed": TYPE_FLOAT, "damage": TYPE_FLOAT, "radius": TYPE_FLOAT, "xp": TYPE_FLOAT, "shape": TYPE_STRING, "color": TYPE_STRING},
	"tomes": {"id": TYPE_STRING, "name": TYPE_STRING, "status": TYPE_STRING, "desc": TYPE_STRING, "modifiers_per_level": TYPE_ARRAY},
	"maps": {"id": TYPE_STRING, "size": TYPE_ARRAY, "spawns": TYPE_ARRAY},
	"rules": {"id": TYPE_STRING},
}
## Values the code knows how to run. Data naming anything else is an error.
const ENEMY_ROLES := ["chaser", "pack"]
const WEAPON_PATTERNS := ["spin_swing"]  # keep in sync with Weapon.PATTERNS
const PASSIVES := ["getting_stale"]

static var _shared: GameData

var entries := {}  # category -> {id -> Dictionary}
var errors := PackedStringArray()


## The game's data, loaded once.
static func shared() -> GameData:
	if _shared == null:
		_shared = load_from(ROOT)
		for e in _shared.errors:
			push_error(e)
	return _shared


static func load_from(root: String) -> GameData:
	var db := GameData.new()
	for category: String in SCHEMA:
		db.entries[category] = {}
		var dir := root.path_join(category)
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f in files:
			if f.ends_with(".json"):
				db._load_file(category, dir.path_join(f))
	db._cross_check()
	return db


func get_entry(category: String, id: String) -> Dictionary:
	return entries.get(category, {}).get(id, {})


func all(category: String) -> Array:
	var ids: Array = entries.get(category, {}).keys()
	ids.sort()
	return ids.map(func(id: String) -> Dictionary: return entries[category][id])


func _load_file(category: String, file: String) -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file)) != OK:
		errors.append("%s: JSON error on line %d: %s" % [file, json.get_error_line(), json.get_error_message()])
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: top level must be an object" % file)
		return
	var e: Dictionary = json.data
	var ok := true
	for key: String in SCHEMA[category]:
		var want: int = SCHEMA[category][key]
		if not e.has(key):
			errors.append("%s: missing \"%s\"" % [file, key])
			ok = false
		elif typeof(e[key]) != want:
			errors.append("%s: \"%s\" has the wrong type" % [file, key])
			ok = false
	if not ok:
		return
	if e.id != file.get_file().get_basename():
		errors.append("%s: id \"%s\" must match the file name" % [file, e.id])
		return
	e["_file"] = file
	_check_entry(category, e)
	entries[category][e.id] = e


func _check_entry(category: String, e: Dictionary) -> void:
	var file: String = e._file
	match category:
		"enemies":
			if not e.role in ENEMY_ROLES:
				errors.append("%s: unknown role \"%s\"" % [file, e.role])
			if e.has("one_hit") and typeof(e.one_hit) != TYPE_BOOL:
				errors.append("%s: \"one_hit\" must be true or false" % file)
			if Palette.index_of(e.color) < 0:
				errors.append("%s: unknown palette color \"%s\"" % [file, e.color])
		"weapons":
			if not e.pattern in WEAPON_PATTERNS:
				errors.append("%s: unknown pattern \"%s\"" % [file, e.pattern])
			if e.levels.is_empty():
				errors.append("%s: needs at least one level" % file)
		"tomes":
			for m in e.modifiers_per_level:
				if not (m is Dictionary and m.has("stat")):
					errors.append("%s: each modifier needs a \"stat\"" % file)
		"characters":
			if not e.passive.get("id", "") in PASSIVES:
				errors.append("%s: unknown passive \"%s\"" % [file, e.passive.get("id", "")])


## References between files (spawns name enemies, characters name weapons).
func _cross_check() -> void:
	for c: Dictionary in entries.characters.values():
		if not entries.weapons.has(c.signature_weapon):
			errors.append("%s: signature weapon \"%s\" not found in weapons/" % [c._file, c.signature_weapon])
		for stat: String in StatBlock.NAMES:
			if not c.stats.has(stat):
				errors.append("%s: missing stat \"%s\"" % [c._file, stat])
		for stat: String in c.stats:
			if not stat in StatBlock.NAMES:
				errors.append("%s: unknown stat \"%s\"" % [c._file, stat])
			elif typeof(c.stats[stat]) != TYPE_FLOAT:
				errors.append("%s: stat \"%s\" must be a number" % [c._file, stat])
	for t: Dictionary in entries.tomes.values():
		for m in t.modifiers_per_level:
			if m is Dictionary and not m.get("stat", "") in StatBlock.NAMES:
				errors.append("%s: unknown stat \"%s\"" % [t._file, m.get("stat", "")])
	for m: Dictionary in entries.maps.values():
		for s in m.spawns:
			if not (s is Dictionary and entries.enemies.has(s.get("enemy", ""))):
				errors.append("%s: spawn names unknown enemy \"%s\"" % [m._file, s.get("enemy", "") if s is Dictionary else s])
