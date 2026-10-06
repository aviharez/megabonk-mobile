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
	"interactables": {"id": TYPE_STRING, "name": TYPE_STRING, "behavior": TYPE_STRING, "radius": TYPE_FLOAT, "shape": TYPE_STRING, "color": TYPE_STRING},
	"rules": {"id": TYPE_STRING},
}
## Values the code knows how to run. Data naming anything else is an error.
## Weapon patterns come from Weapon.PATTERNS, item events/effects from ItemSystem.
const ENEMY_ROLES := ["chaser", "pack", "shooter", "exploder", "charger", "swarm", "ghost", "boss"]
## Keys each role reads from its enemy file (beyond the common ones).
const ROLE_KEYS := {
	"shooter": {"keep_distance": TYPE_ARRAY, "shot": TYPE_DICTIONARY},
	"exploder": {"explode": TYPE_DICTIONARY},
	"charger": {"charge": TYPE_DICTIONARY},
	"boss": {"boss": TYPE_DICTIONARY},
}
const ROLE_SUBKEYS := {
	"shot": ["every", "speed", "damage", "radius", "life", "range"],
	"explode": ["trigger_range", "fuse", "radius", "damage"],
	"charge": ["range", "windup", "speed", "time", "recover"],
}
const PASSIVES := ["getting_stale"]
const WEAPON_STATUSES := ["start", "unlock", "signature"]
const CONTENT_STATUSES := ["start", "unlock"]
const TOME_GROUPS := ["offense", "defense", "utility", "risk"]

static var _shared: GameData

var entries := {}  # category -> {id -> Dictionary}
var errors := PackedStringArray()
## Checks that need every file loaded first (run by _cross_check).
var _late: Array[Callable] = []


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
			if not PlaceholderArt.has_shape(e.shape):
				errors.append("%s: unknown shape \"%s\"" % [file, e.shape])
			if e.has("sheet"):
				_check_sheet(file, e.sheet)
			for k: String in ROLE_KEYS.get(e.role, {}):
				if typeof(e.get(k)) != ROLE_KEYS[e.role][k]:
					errors.append("%s: role \"%s\" needs \"%s\"" % [file, e.role, k])
				elif ROLE_SUBKEYS.has(k):
					for sub: String in ROLE_SUBKEYS[k]:
						if typeof(e[k].get(sub)) != TYPE_FLOAT:
							errors.append("%s: \"%s\" needs a number \"%s\"" % [file, k, sub])
			if e.role == "ghost" and not e.has("damage_pct_max_hp"):
				errors.append("%s: a ghost needs \"damage_pct_max_hp\"" % file)
			if e.role == "shooter" and e.get("keep_distance") is Array and not _is_pair(e.keep_distance):
				errors.append("%s: \"keep_distance\" must be [near, far]" % file)
			if e.role == "boss" and e.get("boss") is Dictionary:
				_check_boss(file, e.boss)
		"interactables":
			if not e.behavior in Interactables.BEHAVIORS:
				errors.append("%s: unknown behavior \"%s\"" % [file, e.behavior])
			if not PlaceholderArt.has_shape(e.shape):
				errors.append("%s: unknown shape \"%s\"" % [file, e.shape])
			for c in [e.color, e.get("arrow", "INK")]:
				if Palette.index_of(c) < 0:
					errors.append("%s: unknown palette color \"%s\"" % [file, c])
			var need: Array = {"paid_chest": ["chest", "price"], "free_chest": ["chest"], "pot": ["gold"],
				"charge_shrine": ["charge_time", "choices"], "risk_shrine": ["charge_time", "duration", "modifiers"],
				"challenge_shrine": ["charge_time", "kills", "time"], "merchant": ["chest", "prices"],
				"altar": ["charge_time", "boss"]}.get(e.behavior, [])
			for k: String in need:
				if not e.has(k):
					errors.append("%s: behavior \"%s\" needs \"%s\"" % [file, e.behavior, k])
			_check_modifiers(file, e.get("choices", []) + e.get("modifiers", []))
			_check_interactable_values(file, e)
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
	for c in _late:
		c.call()
	_late.clear()  # the closures hold this object: don't keep a cycle
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
		_check_map(m)
	var bills: Dictionary = entries.rules.get("bills", {})
	if not bills.is_empty():
		if entries.enemies.get(bills.get("enemy", ""), {}).get("role", "") != "ghost":
			errors.append("%s: \"enemy\" must be a ghost enemy" % bills._file)
		for k: String in ["after_sec", "per_sec", "per_sec_growth_per_min", "speedup_per_min", "damage_growth_per_min", "max"]:
			if typeof(bills.get(k)) != TYPE_FLOAT:
				errors.append("%s: needs a number \"%s\"" % [bills._file, k])
	var er: Dictionary = entries.rules.get("elites", {})
	if not er.is_empty():
		for t: String in er.get("traits", {}):
			if Palette.index_of(er.traits[t].get("color", "")) < 0:
				errors.append("%s: trait \"%s\" needs a palette \"color\"" % [er._file, t])
		# Elites drop a free chest (never a paid one, a portal...), and the key is a key.
		if entries.interactables.get(er.get("chest", ""), {}).get("behavior", "") != "free_chest":
			errors.append("%s: \"chest\" must name a free_chest interactable" % er._file)
		if er.has("key") and entries.interactables.get(er.key.get("drop", ""), {}).get("behavior", "") != "key":
			errors.append("%s: key \"drop\" must name a key interactable" % er._file)
	for e: Dictionary in entries.interactables.values():
		if e.has("boss") and entries.enemies.get(e.boss, {}).get("role", "") != "boss":
			errors.append("%s: \"%s\" is not a boss enemy" % [e._file, e.boss])
		if e.has("chest") and not entries.rules.get("loot", {}).get("chests", {}).has(e.chest):
			errors.append("%s: chest kind \"%s\" not in rules/loot.json" % [e._file, e.chest])
		if e.has("reward_chest") and not entries.interactables.has(e.reward_chest + "_chest"):
			errors.append("%s: no interactable \"%s_chest\"" % [e._file, e.reward_chest])


func _check_map(m: Dictionary) -> void:
	var f: String = m._file
	# Schedules with a time window: the regular one and the Final Swarm's.
	var final: Dictionary = m.get("final_swarm", {}) if m.get("final_swarm") is Dictionary else {}
	for list in [m.spawns, final.get("spawns", [])]:
		_check_spawns(f, list, true)
	for w in m.get("swarms", []):
		if not w is Dictionary:
			errors.append("%s: each swarm must be an object" % f)
			continue
		for k: String in ["at_min", "duration"]:
			if typeof(w.get(k)) != TYPE_FLOAT:
				errors.append("%s: each swarm needs a number \"%s\"" % [f, k])
		if not (w.get("spawns") is Array and not w.spawns.is_empty()):
			errors.append("%s: each swarm needs a non-empty \"spawns\" list" % f)
		else:
			_check_spawns(f, w.spawns, false)
	for c in m.get("ground_colors", []):
		if typeof(c) != TYPE_STRING or Palette.index_of(c) < 0:
			errors.append("%s: unknown ground color \"%s\"" % [f, c])
	if final.has("bills") and typeof(final.bills) != TYPE_BOOL:
		errors.append("%s: final_swarm \"bills\" must be true or false (numbers are in rules/bills.json)" % f)
	var el: Dictionary = m.get("elites", {})
	if not el.is_empty():
		if typeof(el.get("first_sec")) != TYPE_FLOAT or not _is_pair(el.get("every_sec")):
			errors.append("%s: elites need \"first_sec\" and \"every_sec\": [min, max]" % f)
	var traits: Dictionary = entries.rules.get("elites", {}).get("traits", {})
	for id in el.get("from", []):
		if not entries.enemies.has(id):
			errors.append("%s: elites \"from\" names unknown enemy \"%s\"" % [f, id])
	for t in el.get("traits", []):
		if not traits.has(t):
			errors.append("%s: unknown elite trait \"%s\" (see rules/elites.json)" % [f, t])
	for it in m.get("interactables", []):
		if not entries.interactables.has(it.get("id", "")):
			errors.append("%s: unknown interactable \"%s\"" % [f, it.get("id", "")])
		elif it.has("at") and not (it.at is Array and it.at.size() == 2):
			errors.append("%s: \"at\" of \"%s\" must be [x, y]" % [f, it.id])
	if m.has("merchant") and not entries.interactables.has(m.merchant.get("id", "")):
		errors.append("%s: merchant names an unknown interactable" % f)
	for p in m.get("props", []):
		if not (p is Dictionary and MapLayout.KINDS.has(p.get("kind", "")) and p.get("rect") is Array and p.rect.size() == 4 \
				and p.rect.all(func(v) -> bool: return typeof(v) == TYPE_FLOAT)):
			errors.append("%s: each prop needs a known \"kind\" and \"rect\": [x, y, w, h] numbers (%s)" % [f, p])
		elif p.has("color") and (typeof(p.color) != TYPE_STRING or Palette.index_of(p.color) < 0):
			errors.append("%s: unknown prop color \"%s\"" % [f, p.color])


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT


static func _is_pair(v: Variant) -> bool:
	return v is Array and v.size() == 2 and _is_num(v[0]) and _is_num(v[1])


## Spawn lists. timed = entries need their own window (from_min, to_min);
## swarm entries get theirs from the swarm.
func _check_spawns(f: String, list: Variant, timed: bool) -> void:
	if not list is Array:
		errors.append("%s: spawns must be a list" % f)
		return
	for s in list:
		if not (s is Dictionary and entries.enemies.has(s.get("enemy", ""))):
			errors.append("%s: spawn names unknown enemy \"%s\"" % [f, s.get("enemy", "") if s is Dictionary else s])
			continue
		if not _is_pair(s.get("per_sec")):
			errors.append("%s: spawn of \"%s\" needs \"per_sec\": [start, end]" % [f, s.enemy])
		if timed and not (_is_num(s.get("from_min")) and _is_num(s.get("to_min"))):
			errors.append("%s: spawn of \"%s\" needs numbers \"from_min\" and \"to_min\"" % [f, s.enemy])
		if s.has("growth_per_min") and not _is_num(s.growth_per_min):
			errors.append("%s: \"growth_per_min\" of \"%s\" must be a number" % [f, s.enemy])


## The numbers each behavior reads, with the right types.
func _check_interactable_values(f: String, e: Dictionary) -> void:
	for k: String in ["price", "price_growth", "charge_time", "duration", "kills", "time", "stay_sec", "offer", "stock"]:
		if e.has(k) and not _is_num(e[k]):
			errors.append("%s: \"%s\" must be a number" % [f, k])
	if e.has("gold") and not _is_pair(e.gold):
		errors.append("%s: \"gold\" must be [min, max]" % f)
	if e.has("prices"):
		if not e.prices is Dictionary:
			errors.append("%s: \"prices\" must map rarity to price" % f)
		else:
			# Rarities come from rules/loot.json, which may load later.
			_late.append(func() -> void:
				for r: String in entries.get("rules", {}).get("loot", {}).get("rarities", []):
					if not _is_num(e.prices.get(r)):
						errors.append("%s: \"prices\" needs a number for \"%s\"" % [f, r]))
	if e.has("choices"):
		if not (e.choices is Array and not e.choices.is_empty()):
			errors.append("%s: \"choices\" must be a non-empty list" % f)
		else:
			for c in e.choices:
				if not (c is Dictionary and typeof(c.get("desc")) == TYPE_STRING):
					errors.append("%s: each choice needs a \"desc\" text for its card" % f)


const BOSS_PATTERNS := {
	"burrow": ["chase_time", "chase_speed", "warn", "radius", "damage"],
	"rocks": ["count", "gap", "speed", "damage", "radius", "life"],
	"summon": ["count", "distance"],
}


## Boss numbers: every pattern it uses, with its keys; summons name enemies.
func _check_boss(f: String, b: Dictionary) -> void:
	for k: String in ["rage_below", "rage_speedup"]:
		if not _is_num(b.get(k)):
			errors.append("%s: boss needs a number \"%s\"" % [f, k])
	if not _is_pair(b.get("rest")):
		errors.append("%s: boss \"rest\" must be [min, max]" % f)
	var patterns = b.get("patterns")
	if not (patterns is Array and not patterns.is_empty()):
		errors.append("%s: boss needs a non-empty \"patterns\" list" % f)
		return
	for p in patterns:
		if not BOSS_PATTERNS.has(p):
			errors.append("%s: unknown boss pattern \"%s\"" % [f, p])
			continue
		if not b.get(p) is Dictionary:
			errors.append("%s: boss pattern \"%s\" needs its \"%s\" numbers" % [f, p, p])
			continue
		for k: String in BOSS_PATTERNS[p]:
			if not _is_num(b[p].get(k)):
				errors.append("%s: boss \"%s\" needs a number \"%s\"" % [f, p, k])
	if b.get("summon") is Dictionary:
		# Checked after loading, when every enemy is known.
		_late.append(func() -> void:
			if not entries.enemies.has(b.summon.get("enemy", "")):
				errors.append("%s: boss summons unknown enemy \"%s\"" % [f, b.summon.get("enemy", "")]))


## An animated sheet: the PNG plus its sidecar (tools/palette_snap.py), with
## frames that tile the strip exactly.
func _check_sheet(f: String, path: Variant) -> void:
	if typeof(path) != TYPE_STRING or not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		errors.append("%s: sheet \"%s\" not found" % [f, path])
		return
	var meta_path: String = path.get_basename() + ".json"
	var meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path)) if FileAccess.file_exists(meta_path) else null
	if not meta is Dictionary:
		errors.append("%s: sheet sidecar \"%s\" missing or not JSON" % [f, meta_path])
		return
	for k: String in ["frame_w", "frame_h", "frames", "fps"]:
		if not _is_num(meta.get(k)) or float(meta.get(k)) <= 0.0:
			errors.append("%s: sidecar \"%s\" needs a positive \"%s\"" % [f, meta_path, k])
			return
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var size := tex.get_size() if tex != null else Vector2(Image.load_from_file(path).get_size())
	if int(meta.frame_w) * int(meta.frames) != int(size.x) or int(meta.frame_h) != int(size.y):
		errors.append("%s: sheet %s is %dx%d but the sidecar says %d frames of %dx%d" % [f, path, size.x, size.y, meta.frames, meta.frame_w, meta.frame_h])

