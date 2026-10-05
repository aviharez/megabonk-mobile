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
	"tomes": {"id": TYPE_STRING, "name": TYPE_STRING, "status": TYPE_STRING, "group": TYPE_STRING, "desc": TYPE_STRING, "modifiers_per_level": TYPE_ARRAY},
	"items": {"id": TYPE_STRING, "name": TYPE_STRING, "rarity": TYPE_STRING, "status": TYPE_STRING, "desc": TYPE_STRING},
	"maps": {"id": TYPE_STRING, "size": TYPE_ARRAY, "spawns": TYPE_ARRAY},
	"rules": {"id": TYPE_STRING},
}
## Values the code knows how to run. Data naming anything else is an error.
## Weapon patterns come from Weapon.PATTERNS, item events/effects from ItemSystem.
const ENEMY_ROLES := ["chaser", "pack"]
const PASSIVES := ["getting_stale"]
const WEAPON_STATUSES := ["start", "unlock", "signature"]
const CONTENT_STATUSES := ["start", "unlock"]
const TOME_GROUPS := ["offense", "defense", "utility", "risk"]

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
			_check_weapon(e)
		"tomes":
			if not e.status in CONTENT_STATUSES:
				errors.append("%s: unknown status \"%s\"" % [file, e.status])
			if not e.group in TOME_GROUPS:
				errors.append("%s: unknown group \"%s\"" % [file, e.group])
			if e.modifiers_per_level.is_empty():
				errors.append("%s: needs at least one modifier" % file)
			_check_modifiers(file, e.modifiers_per_level)
		"items":
			_check_item(e)
		"characters":
			if not e.passive.get("id", "") in PASSIVES:
				errors.append("%s: unknown passive \"%s\"" % [file, e.passive.get("id", "")])


func _check_weapon(e: Dictionary) -> void:
	var file: String = e._file
	if not Weapon.PATTERNS.has(e.pattern):
		errors.append("%s: unknown pattern \"%s\"" % [file, e.pattern])
		return
	if not e.status in WEAPON_STATUSES:
		errors.append("%s: unknown status \"%s\"" % [file, e.status])
	if e.status == "signature" and typeof(e.get("character")) != TYPE_STRING:
		errors.append("%s: a signature weapon needs \"character\"" % file)
	if e.levels.is_empty():
		errors.append("%s: needs at least one level" % file)
	# Each pattern script lists the level keys it reads in LEVEL_KEYS.
	var keys: Array = load(Weapon.PATTERNS[e.pattern]).get_script_constant_map().get("LEVEL_KEYS", [])
	for i in e.levels.size():
		var lv = e.levels[i]
		if not lv is Dictionary:
			errors.append("%s: level %d must be an object" % [file, i + 1])
			continue
		for k: String in keys + ["desc"]:
			if not lv.has(k):
				errors.append("%s: level %d is missing \"%s\"" % [file, i + 1, k])
			elif k != "desc" and typeof(lv[k]) != TYPE_FLOAT:
				errors.append("%s: level %d \"%s\" must be a number" % [file, i + 1, k])


func _check_modifiers(file: String, mods: Array) -> void:
	for m in mods:
		if not (m is Dictionary and m.has("stat")):
			errors.append("%s: each modifier needs a \"stat\"" % file)
		elif not m.stat in StatBlock.NAMES:
			errors.append("%s: unknown stat \"%s\"" % [file, m.stat])
		elif not (m.has("flat") or m.has("pct")):
			errors.append("%s: modifier for \"%s\" needs \"flat\" or \"pct\"" % [file, m.stat])


func _check_item(e: Dictionary) -> void:
	var file: String = e._file
	if not e.status in CONTENT_STATUSES:
		errors.append("%s: unknown status \"%s\"" % [file, e.status])
	if not e.rarity in ["common", "rare", "epic", "legendary"]:
		errors.append("%s: unknown rarity \"%s\"" % [file, e.rarity])
	_check_modifiers(file, e.get("modifiers", []))
	var trigs: Array = e.get("triggers", [])
	for t in trigs:
		if not t is Dictionary:
			errors.append("%s: each trigger must be an object" % file)
			continue
		if not t.get("event", "") in ItemSystem.EVENTS:
			errors.append("%s: unknown event \"%s\"" % [file, t.get("event", "")])
		if t.get("event", "") == "every" and float(t.get("interval", 0.0)) <= 0.0:
			errors.append("%s: an \"every\" trigger needs \"interval\" > 0" % file)
		if not ItemSystem.EFFECTS.has(t.get("effect", "")):
			errors.append("%s: unknown effect \"%s\"" % [file, t.get("effect", "")])
			continue
		for k: String in ItemSystem.EFFECTS[t.effect]:
			if not t.has(k):
				errors.append("%s: effect \"%s\" needs \"%s\"" % [file, t.effect, k])
		var chance = t.get("chance", 1.0)
		if typeof(chance) != TYPE_FLOAT or chance <= 0.0 or chance > 1.0:
			errors.append("%s: \"chance\" must be a number in (0, 1]" % file)
		if t.has("color") and Palette.index_of(t.color) < 0:
			errors.append("%s: unknown palette color \"%s\"" % [file, t.color])
		if t.effect == "stat_boost":
			if t.get("choices") is Array and not t.choices.is_empty():
				_check_modifiers(file, t.choices)
			else:
				errors.append("%s: \"choices\" must be a non-empty list" % file)
	var conds: Array = e.get("conditions", [])
	for c in conds:
		if not (c is Dictionary and c.get("if", "") in ItemSystem.CONDITIONS and typeof(c.get("value")) == TYPE_FLOAT):
			errors.append("%s: a condition needs a known \"if\" and a number \"value\"" % file)
	_check_modifiers(file, conds)
	if e.get("modifiers", []).is_empty() and trigs.is_empty() and conds.is_empty():
		errors.append("%s: item does nothing (no modifiers, triggers or conditions)" % file)


## References between files (spawns name enemies, characters name weapons).
func _cross_check() -> void:
	for c: Dictionary in entries.characters.values():
		if not entries.weapons.has(c.signature_weapon):
			errors.append("%s: signature weapon \"%s\" not found in weapons/" % [c._file, c.signature_weapon])
		# Stats a character leaves out start at StatBlock.DEFAULTS.
		for stat: String in c.stats:
			if not stat in StatBlock.NAMES:
				errors.append("%s: unknown stat \"%s\"" % [c._file, stat])
			elif typeof(c.stats[stat]) != TYPE_FLOAT:
				errors.append("%s: stat \"%s\" must be a number" % [c._file, stat])
	for m: Dictionary in entries.maps.values():
		for s in m.spawns:
			if not (s is Dictionary and entries.enemies.has(s.get("enemy", ""))):
				errors.append("%s: spawn names unknown enemy \"%s\"" % [m._file, s.get("enemy", "") if s is Dictionary else s])
