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
	"characters": {"id": TYPE_STRING, "name": TYPE_STRING, "status": TYPE_STRING, "signature_weapon": TYPE_STRING, "stats": TYPE_DICTIONARY, "radius": TYPE_FLOAT, "passive": TYPE_DICTIONARY},
	"weapons": {"id": TYPE_STRING, "name": TYPE_STRING, "pattern": TYPE_STRING, "status": TYPE_STRING, "levels": TYPE_ARRAY},
	"enemies": {"id": TYPE_STRING, "name": TYPE_STRING, "role": TYPE_STRING, "hp": TYPE_FLOAT, "speed": TYPE_FLOAT, "damage": TYPE_FLOAT, "radius": TYPE_FLOAT, "xp": TYPE_FLOAT},
	"tomes": {"id": TYPE_STRING, "name": TYPE_STRING, "status": TYPE_STRING, "group": TYPE_STRING, "desc": TYPE_STRING, "modifiers_per_level": TYPE_ARRAY},
	"items": {"id": TYPE_STRING, "name": TYPE_STRING, "rarity": TYPE_STRING, "status": TYPE_STRING, "desc": TYPE_STRING},
	"maps": {"id": TYPE_STRING, "name": TYPE_STRING},
	"interactables": {"id": TYPE_STRING, "name": TYPE_STRING, "behavior": TYPE_STRING, "radius": TYPE_FLOAT, "shape": TYPE_STRING, "color": TYPE_STRING},
	"rules": {"id": TYPE_STRING},
	"challenges": {"id": TYPE_STRING, "tier": TYPE_STRING, "desc": TYPE_STRING, "stat": TYPE_STRING, "scope": TYPE_STRING, "target": TYPE_FLOAT, "requires": TYPE_STRING, "reward": TYPE_STRING, "price": TYPE_FLOAT},
	"shop": {"id": TYPE_STRING, "name": TYPE_STRING, "desc": TYPE_STRING, "kind": TYPE_STRING, "prices": TYPE_ARRAY},
	"danger": {"id": TYPE_STRING, "level": TYPE_FLOAT, "modifiers": TYPE_DICTIONARY, "coin_mult": TYPE_FLOAT},
	"quests": {"id": TYPE_STRING, "kind": TYPE_STRING, "desc": TYPE_STRING, "stat": TYPE_STRING, "scope": TYPE_STRING, "target": TYPE_FLOAT, "requires": TYPE_STRING, "reward": TYPE_DICTIONARY, "repeat": TYPE_BOOL},
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
## Character passives (behavior in Passives) and the numbers each one reads.
const PASSIVES := {
	"getting_stale": ["reduction_per_minute", "max_reduction"],
	"speed_damage": ["from_speed", "damage_per_speed"],
	"overtime": ["from_min", "max_steps"],
}
const WEAPON_STATUSES := ["start", "unlock", "signature"]
const CONTENT_STATUSES := ["start", "unlock"]
## Maps: "start" (open), "unlock" (opens when the boss of its "unlock_after"
## map is defeated), "planned" (shown locked on the map screen, not playable).
const MAP_STATUSES := ["start", "unlock", "planned"]
## Keys a playable (not planned) map needs on top of SCHEMA.maps.
const PLAYABLE_MAP := {"size": TYPE_ARRAY, "spawns": TYPE_ARRAY}
## Animation clips a character sheet can have (data/characters/*.json "sheets").
const CHARACTER_CLIPS := ["idle", "walk", "hit"]
const TOME_GROUPS := ["offense", "defense", "utility", "risk"]
## Danger level modifiers (data/danger/): multipliers on the director's spawn
## rate and new enemies' HP and damage, and the elite interval [min, max] s.
const DANGER_MULTS := ["spawn_rate", "enemy_hp", "enemy_damage"]
const DANGER_PAIRS := ["elite_every_sec"]

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


## A tome's "icon" (Icons.tome): {"cover": [light, dark], "symbol_color", "symbol": rows of "X" and "."}.
func _check_tome_icon(file: String, icon) -> void:
	if not icon is Dictionary:
		errors.append("%s: \"icon\" must be an object" % file)
		return
	var cover = icon.get("cover")
	if not (cover is Array and cover.size() == 2):
		errors.append("%s: icon \"cover\" must be [light, dark] palette colors" % file)
		cover = []
	for c in cover + [icon.get("symbol_color")]:
		if typeof(c) != TYPE_STRING or Palette.index_of(c) < 0:
			errors.append("%s: icon has an unknown palette color \"%s\"" % [file, c])
	var rows = icon.get("symbol")
	var ok: bool = rows is Array and rows.size() > 0 and rows.size() <= Icons.SYMBOL_SIZE
	if ok:
		for r in rows:
			ok = ok and r is String and r.length() <= Icons.SYMBOL_SIZE and r.replace("X", "").replace(".", "") == ""
	if not ok:
		errors.append("%s: icon \"symbol\" must be up to %d rows of up to %d \"X\" / \".\"" % [file, Icons.SYMBOL_SIZE, Icons.SYMBOL_SIZE])


func _check_entry(category: String, e: Dictionary) -> void:
	var file: String = e._file
	match category:
		"enemies":
			if not e.role in ENEMY_ROLES:
				errors.append("%s: unknown role \"%s\"" % [file, e.role])
			# The bestiary line (Characters > Critters) and its slot order.
			if typeof(e.get("desc")) != TYPE_STRING or e.desc == "":
				errors.append("%s: needs a one-line \"desc\" (bestiary)" % file)
			if e.has("dex") and not _is_num(e.dex):
				errors.append("%s: \"dex\" must be a number" % file)
			if e.has("one_hit") and typeof(e.one_hit) != TYPE_BOOL:
				errors.append("%s: \"one_hit\" must be true or false" % file)
			# Drawn from its "sheet" (critter sprites); only an enemy without
			# one names a code-drawn PlaceholderArt "shape" + "color".
			if e.has("color") and (typeof(e.color) != TYPE_STRING or Palette.index_of(e.color) < 0):
				errors.append("%s: unknown palette color \"%s\"" % [file, e.color])
			if e.has("sheet"):
				_check_sheet(file, e.sheet)
			elif not (e.get("shape") is String and PlaceholderArt.has_shape(e.shape) and e.has("color")):
				errors.append("%s: needs a \"sheet\" (or a known \"shape\" and a \"color\")" % file)
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
			if e.get("shot") is Dictionary:
				_check_art(file, e.shot, ["sprite"])
		"interactables":
			if not e.behavior in Interactables.BEHAVIORS:
				errors.append("%s: unknown behavior \"%s\"" % [file, e.behavior])
			if not PlaceholderArt.has_shape(e.shape):
				errors.append("%s: unknown shape \"%s\"" % [file, e.shape])
			for c in [e.color, e.get("arrow", "INK")]:
				if Palette.index_of(c) < 0:
					errors.append("%s: unknown palette color \"%s\"" % [file, c])
			if e.has("sprite") and (typeof(e.sprite) != TYPE_STRING or not ResourceLoader.exists(e.sprite)):
				errors.append("%s: sprite \"%s\" not found" % [file, e.sprite])
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
			if e.has("icon"):
				_check_tome_icon(file, e.icon)
		"items":
			_check_item(e)
		"characters":
			if not e.status in CONTENT_STATUSES:
				errors.append("%s: unknown status \"%s\"" % [file, e.status])
			if e.has("sheets"):
				if not e.sheets is Dictionary or not e.sheets.has("idle"):
					errors.append("%s: \"sheets\" needs at least an \"idle\" sheet" % file)
				else:
					for clip: String in e.sheets:
						if not clip in CHARACTER_CLIPS:
							errors.append("%s: unknown sheet clip \"%s\"" % [file, clip])
						_check_sheet(file, e.sheets[clip])
			var pid: String = e.passive.get("id", "")
			if not PASSIVES.has(pid):
				errors.append("%s: unknown passive \"%s\"" % [file, pid])
			else:
				for k: String in PASSIVES[pid]:
					if not _is_num(e.passive.get(k)):
						errors.append("%s: passive \"%s\" needs a number \"%s\"" % [file, pid, k])
				if pid == "overtime":
					if not (e.passive.get("modifiers_per_step") is Array and not e.passive.modifiers_per_step.is_empty()):
						errors.append("%s: passive \"overtime\" needs a non-empty \"modifiers_per_step\" list" % file)
					else:
						_check_modifiers(file, e.passive.modifiers_per_step)
			for k: String in ["name", "desc"]:
				if typeof(e.passive.get(k)) != TYPE_STRING:
					errors.append("%s: passive needs a \"%s\" text" % [file, k])
		"rules":
			_check_art(file, e, ["default_shot_sprite"])
			for t in e.get("gem_tiers", []):
				if t is Dictionary:
					_check_art(file, t, ["sprite"])
		"challenges":
			_check_challenge(e)
		"shop":
			_check_shop(e)
		"danger":
			_check_danger(e)
		"quests":
			_check_quest(e)


## data/danger/<id>.json: {"level" (1, 2, 3...), "modifiers": {DANGER_MULTS
## multipliers, DANGER_PAIRS [min, max]}, "coin_mult"}.
func _check_danger(e: Dictionary) -> void:
	var file: String = e._file
	if e.level < 1.0 or e.level != floorf(e.level):
		errors.append("%s: \"level\" must be a whole number from 1" % file)
	if e.coin_mult <= 0.0:
		errors.append("%s: \"coin_mult\" must be above 0" % file)
	for k: String in e.modifiers:
		if k in DANGER_MULTS:
			if not _is_num(e.modifiers[k]) or e.modifiers[k] <= 0.0:
				errors.append("%s: modifier \"%s\" must be a number above 0" % [file, k])
		elif k in DANGER_PAIRS:
			if not _is_pair(e.modifiers[k]) or e.modifiers[k][0] <= 0.0 or e.modifiers[k][0] > e.modifiers[k][1]:
				errors.append("%s: modifier \"%s\" must be [min, max] seconds" % [file, k])
		else:
			errors.append("%s: unknown modifier \"%s\"" % [file, k])


func _check_weapon(e: Dictionary) -> void:
	var file: String = e._file
	if not Weapon.PATTERNS.has(e.pattern):
		errors.append("%s: unknown pattern \"%s\"" % [file, e.pattern])
		return
	if not e.status in WEAPON_STATUSES:
		errors.append("%s: unknown status \"%s\"" % [file, e.status])
	if e.has("trail") and not (e.trail is String and Palette.index_of(e.trail) >= 0):
		errors.append("%s: \"trail\" must be a palette name" % file)
	if e.status == "signature" and typeof(e.get("character")) != TYPE_STRING:
		errors.append("%s: a signature weapon needs \"character\"" % file)
	if e.levels.is_empty():
		errors.append("%s: needs at least one level" % file)
	_check_art(file, e, ["shot_sprite", "swing_sprite", "orbit_sprite"])
	if e.has("swing_sprite") and not (_is_num(e.get("swing_turns")) and e.get("swing_lengths") is Array):
		errors.append("%s: \"swing_sprite\" needs \"swing_turns\" and \"swing_lengths\"" % file)
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
	_check_unlock_links()
	_check_quest_links()
	# Danger levels run 1, 2, 3... with no gaps or repeats.
	var levels: Array = entries.danger.values().map(func(d: Dictionary) -> int: return int(d.level))
	levels.sort()
	for i in levels.size():
		if levels[i] != i + 1:
			errors.append("%s: danger levels must be 1, 2, 3... with no gaps or repeats (have %s)" % [ROOT.path_join("danger"), levels])
			break
	for c: Dictionary in entries.characters.values():
		if c.has("role") and typeof(c.role) != TYPE_STRING:
			errors.append("%s: \"role\" must be text" % c._file)
		if not entries.weapons.has(c.signature_weapon):
			errors.append("%s: signature weapon \"%s\" not found in weapons/" % [c._file, c.signature_weapon])
		# Stats a character leaves out start at StatBlock.DEFAULTS.
		for stat: String in c.stats:
			if not stat in StatBlock.NAMES:
				errors.append("%s: unknown stat \"%s\"" % [c._file, stat])
			elif typeof(c.stats[stat]) != TYPE_FLOAT:
				errors.append("%s: stat \"%s\" must be a number" % [c._file, stat])
	for m: Dictionary in entries.maps.values():
		_check_map_meta(m)
		if m.get("status", "start") == "planned":
			continue
		var ok := true
		for k: String in PLAYABLE_MAP:
			if typeof(m.get(k)) != PLAYABLE_MAP[k]:
				errors.append("%s: missing \"%s\" (only a \"planned\" map can leave it out)" % [m._file, k])
				ok = false
		if ok:
			_check_map(m)
	var hp_bar = entries.rules.get("run", {}).get("player_hp_bar")
	if hp_bar != null:
		var ok: bool = hp_bar is Dictionary
		for k: String in ["width", "height", "gap"]:
			ok = ok and typeof(hp_bar.get(k)) == TYPE_FLOAT and hp_bar[k] >= 0.0
		if not ok or hp_bar.height < 3.0 or hp_bar.width < 3.0:
			errors.append("%s: \"player_hp_bar\" needs numbers \"width\" and \"height\" (3 or more) and \"gap\"" % entries.rules.run._file)
	_check_ads(entries.rules.get("ads", {}))
	_check_audio(entries.rules.get("audio", {}))
	_check_fx(entries.rules.get("fx", {}))
	_check_store(entries.rules.get("store", {}))
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
		if e.has("hide_when_unlocked") and Meta.content(self, e.hide_when_unlocked).is_empty():
			errors.append("%s: \"hide_when_unlocked\" names unknown content \"%s\"" % [e._file, e.hide_when_unlocked])
		if e.has("boss") and entries.enemies.get(e.boss, {}).get("role", "") != "boss":
			errors.append("%s: \"%s\" is not a boss enemy" % [e._file, e.boss])
		if e.has("chest") and not entries.rules.get("loot", {}).get("chests", {}).has(e.chest):
			errors.append("%s: chest kind \"%s\" not in rules/loot.json" % [e._file, e.chest])
		if e.has("reward_chest") and not entries.interactables.has(e.reward_chest + "_chest"):
			errors.append("%s: no interactable \"%s_chest\"" % [e._file, e.reward_chest])


## Sound ids the run and menus play by name (scripts/run/run.gd, juice.gd,
## interactables.gd, mega_mole.gd, ui). Each must be in data/rules/audio.json.
const AUDIO_EVENTS := ["hit", "crit", "kill", "hurt", "dodge", "gem", "level_up", "card", "click",
	"chest", "beam", "gold", "pot", "shrine", "charge", "key", "cage", "merchant", "buy", "portal", "boom", "zap",
	"boss_roar", "boss_dig", "boss_slam", "rocks", "boss_down", "elite", "alarm", "final", "bills",
	"death", "revive", "heartbeat", "escape", "pop"]
const MUSIC_TRACKS := ["menu", "gameplay", "boss", "game_over", "victory"]
const HIT_FX_KINDS := ["puff", "star", "sparks"]


## data/rules/audio.json: the one list of audio files (scripts/autoload/audio.gd),
## and every sound named by weapons ("sfx") and enemies ("sfx").
func _check_audio(a: Dictionary) -> void:
	if a.is_empty():
		return
	var f: String = a._file
	if not _is_num(a.get("voices")) or a.voices < 1.0:
		errors.append("%s: \"voices\" must be 1 or more" % f)
	var sfx: Variant = a.get("sfx")
	if not sfx is Dictionary:
		errors.append("%s: \"sfx\" must be an object of sounds" % f)
		sfx = {}
	for id: String in sfx:
		var d: Variant = sfx[id]
		if not d is Dictionary or typeof(d.get("file")) != TYPE_STRING or not ResourceLoader.exists(d.file):
			errors.append("%s: sound \"%s\" needs a \"file\" that exists" % [f, id])
			continue
		for k: String in ["db", "pitch", "max", "gap", "priority"]:
			if not _is_num(d.get(k)):
				errors.append("%s: sound \"%s\" needs a number \"%s\"" % [f, id, k])
	for id: String in AUDIO_EVENTS:
		if not sfx.has(id):
			errors.append("%s: missing sound \"%s\" (the game plays it)" % [f, id])
	for t: String in MUSIC_TRACKS:
		var path: Variant = a.get("music", {}).get(t)
		if typeof(path) != TYPE_STRING or not ResourceLoader.exists(path):
			errors.append("%s: music \"%s\" needs a file that exists" % [f, t])
	for cat: String in ["weapons", "enemies"]:
		for e: Dictionary in entries.get(cat, {}).values():
			var es: Variant = e.get("sfx", {})
			if not es is Dictionary:
				errors.append("%s: \"sfx\" must be an object" % e._file)
				continue
			for k: String in es:
				if typeof(es[k]) != TYPE_STRING or (es[k] != "" and not sfx.has(es[k])):
					errors.append("%s: sfx \"%s\" names an unknown sound \"%s\" (see rules/audio.json)" % [e._file, k, es[k]])
	for w: Dictionary in entries.get("weapons", {}).values():
		var hf: Variant = w.get("hit_fx", {})
		if not hf is Dictionary or (not hf.is_empty() and (not hf.get("kind") in HIT_FX_KINDS or Palette.index_of(str(hf.get("color", ""))) < 0)):
			errors.append("%s: \"hit_fx\" needs a \"kind\" (%s) and a palette \"color\"" % [w._file, ", ".join(HIT_FX_KINDS)])


## data/rules/fx.json: juice numbers and the Final Swarm palette map.
func _check_fx(x: Dictionary) -> void:
	if x.is_empty():
		return
	var f: String = x._file
	var groups := {"hitstop": ["big_crit", "big_crit_frac", "boss_hit", "boss_gap", "boss_down", "max"],
		"shake": ["hurt", "explode", "boss_slam", "boss_down", "death", "decay", "max"],
		"low_hp": ["below", "band", "beat_sec"], "chest_beam": ["time", "height"], "gem": ["trail_max", "sparkle_every"]}
	for g: String in groups:
		for k: String in groups[g]:
			if not _is_num(x.get(g, {}).get(k)):
				errors.append("%s: %s needs a number \"%s\"" % [f, g, k])
	for k: String in ["level_up_burst", "death_particles", "hit_fx_gap"]:
		if not _is_num(x.get(k)):
			errors.append("%s: needs a number \"%s\"" % [f, k])
	var m: Variant = x.get("final_tint", {}).get("map", {})
	if not m is Dictionary:
		m = {}
		errors.append("%s: final_tint \"map\" must be an object" % f)
	for from: String in m:
		if Palette.index_of(from) < 0 or typeof(m[from]) != TYPE_STRING or Palette.index_of(m[from]) < 0:
			errors.append("%s: final_tint maps \"%s\" -> \"%s\": both must be palette colors" % [f, from, m[from]])


## data/rules/ads.json: ad units, rewarded placement limits, revive, daily,
## interstitial pacing, banner screens (scripts/autoload/ads.gd).
const AD_PLACEMENTS := ["revive", "double_coins", "reroll", "skip", "banish", "daily", "quest_double"]
const AD_FORMATS := ["banner", "interstitial", "rewarded"]


func _check_ads(a: Dictionary) -> void:
	if a.is_empty():
		return
	var f: String = a._file
	for platform: String in ["android", "ios"]:
		var u: Dictionary = a.get("units", {}).get(platform, {})
		for fmt: String in AD_FORMATS:
			if typeof(u.get(fmt)) != TYPE_STRING or not String(u.get(fmt)).begins_with("ca-app-pub-"):
				errors.append("%s: units.%s needs an ad unit id \"%s\" (ca-app-pub-...)" % [f, platform, fmt])
	var rw: Dictionary = a.get("rewarded", {})
	for p: String in AD_PLACEMENTS:
		var r: Dictionary = rw.get(p, {})
		var limit: Variant = r.get("per_run", r.get("per_day"))
		if r.size() != 1 or not _is_num(limit) or limit < 1.0:
			errors.append("%s: rewarded \"%s\" needs one limit, \"per_run\" or \"per_day\" (1 or more)" % [f, p])
	for p: String in rw:
		if not p in AD_PLACEMENTS:
			errors.append("%s: unknown rewarded placement \"%s\" (no code shows it)" % [f, p])
	for k: String in ["hp_frac", "iframes", "clear_radius"]:
		if not _is_num(a.get("revive", {}).get(k)):
			errors.append("%s: revive needs a number \"%s\"" % [f, k])
	if not _is_num(a.get("daily", {}).get("coins")):
		errors.append("%s: daily needs a number \"coins\"" % f)
	var ic: Dictionary = a.get("interstitial", {})
	if not _is_pair(ic.get("runs_between")) or ic.runs_between[0] < 1.0 or ic.runs_between[0] > ic.runs_between[1]:
		errors.append("%s: interstitial \"runs_between\" must be [min, max] runs, 1 or more" % f)
	if not _is_num(ic.get("first_day_hours")):
		errors.append("%s: interstitial needs a number \"first_day_hours\"" % f)
	var screens: Variant = a.get("banner", {}).get("screens")
	if not screens is Array or screens.has("run"):
		errors.append("%s: banner \"screens\" must be a list of menu screens (never \"run\")" % f)
	for k: String in ["show_timeout_sec", "reward_grace_sec"]:
		if not _is_num(a.get(k)):
			errors.append("%s: needs a number \"%s\"" % [f, k])
	if not _is_pair(a.get("retry_sec")):
		errors.append("%s: \"retry_sec\" must be [first, max]" % f)


## data/rules/store.json: in-app products (scripts/autoload/store.gd).
func _check_store(st: Dictionary) -> void:
	if st.is_empty():
		return
	var f: String = st._file
	var products: Variant = st.get("products")
	if not products is Dictionary:
		errors.append("%s: \"products\" must map product keys to products" % f)
		return
	for key: String in products:
		var p: Dictionary = products[key]
		for k: String in ["name", "desc", "android", "ios"]:
			if typeof(p.get(k)) != TYPE_STRING or String(p.get(k)).is_empty():
				errors.append("%s: product \"%s\" needs a \"%s\"" % [f, key, k])
		if p.get("type") != "non_consumable":
			errors.append("%s: product \"%s\" \"type\" must be \"non_consumable\" (the only kind Store handles)" % [f, key])
		if key != "remove_ads":
			errors.append("%s: unknown product \"%s\" (Store only knows what \"remove_ads\" grants)" % [f, key])


## Map screen data: status, the map whose boss opens it, the thumbnail.
func _check_map_meta(m: Dictionary) -> void:
	var f: String = m._file
	var status: String = str(m.get("status", "start"))
	if not status in MAP_STATUSES:
		errors.append("%s: unknown status \"%s\" (%s)" % [f, status, ", ".join(MAP_STATUSES)])
	if m.has("unlock_after") or status != "start":
		var prev: String = str(m.get("unlock_after", ""))
		if not entries.maps.has(prev) or prev == m.id:
			errors.append("%s: \"unlock_after\" must name another map" % f)
	if m.has("thumb") and not (typeof(m.thumb) == TYPE_STRING and ResourceLoader.exists(m.thumb)):
		errors.append("%s: thumbnail \"%s\" not found" % [f, m.thumb])


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
	_check_prop_art(f, m.get("prop_art", {}))


## "prop_art": {kind: {"sprite": res path, "ramp": [palette colors in the
## sprite], "colors": {prop color: [as many palette colors as the ramp]},
## "variants": {prop color: res path of another sprite}, "slice": [left, top,
## right, bottom] (9-slice), "decor": {spot: res path} (sprites stamped on a
## code-drawn prop; "sprite" is then optional)}}.
func _check_prop_art(f: String, art) -> void:
	if not art is Dictionary:
		errors.append("%s: \"prop_art\" must be an object" % f)
		return
	for kind in art:
		var a = art[kind]
		if not MapLayout.KINDS.has(kind) or not a is Dictionary:
			errors.append("%s: prop_art \"%s\" must be a known prop kind with an object" % [f, kind])
			continue
		var decor = a.get("decor", {})
		if not decor is Dictionary:
			decor = {}
			errors.append("%s: prop_art \"%s\" \"decor\" must be an object" % [f, kind])
		for spot in decor:
			if typeof(decor[spot]) != TYPE_STRING or not ResourceLoader.exists(decor[spot]):
				errors.append("%s: prop_art \"%s\" decor \"%s\" sprite \"%s\" not found" % [f, kind, spot, decor[spot]])
		var path = a.get("sprite")
		if (path != null or decor.is_empty()) and (typeof(path) != TYPE_STRING or not ResourceLoader.exists(path)):
			errors.append("%s: prop_art \"%s\" sprite \"%s\" not found" % [f, kind, path])
		var sl = a.get("slice", [])
		if not (sl is Array and (sl.is_empty() or (sl.size() == 4 and sl.all(func(v): return _is_num(v) and v >= 0)))):
			errors.append("%s: prop_art \"%s\" \"slice\" must be [left, top, right, bottom]" % [f, kind])
		var variants = a.get("variants", {})
		if not variants is Dictionary:
			variants = {}
			errors.append("%s: prop_art \"%s\" \"variants\" must be an object" % [f, kind])
		for c in variants:
			if typeof(variants[c]) != TYPE_STRING or not ResourceLoader.exists(variants[c]):
				errors.append("%s: prop_art \"%s\" variant \"%s\" sprite \"%s\" not found" % [f, kind, c, variants[c]])
		var ramp = a.get("ramp", [])
		var names: Array = variants.keys()
		names.append_array(ramp if ramp is Array else [])
		var colors = a.get("colors", {})
		if not colors is Dictionary:
			colors = {}
			errors.append("%s: prop_art \"%s\" \"colors\" must be an object" % [f, kind])
		for c in colors:
			if not (colors[c] is Array and ramp is Array and colors[c].size() == ramp.size()):
				errors.append("%s: prop_art \"%s\" color \"%s\" needs as many colors as \"ramp\"" % [f, kind, c])
			else:
				names.append_array(colors[c])
			names.append(c)
		for n in names:
			if typeof(n) != TYPE_STRING or Palette.index_of(n) < 0:
				errors.append("%s: prop_art \"%s\" has an unknown palette color \"%s\"" % [f, kind, n])


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
	if e.has("beam"):
		var b = e.beam
		if not (b is Dictionary and _is_num(b.get("height")) and float(b.height) > 0.0 and b.get("color") is String and Palette.index_of(b.color) >= 0):
			errors.append("%s: \"beam\" must be {\"color\": a palette name, \"height\": px > 0}" % f)
	if e.has("twinkle") and not (e.twinkle is String and Palette.index_of(e.twinkle) >= 0):
		errors.append("%s: \"twinkle\" must be a palette name" % f)
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
		_check_art(f, b[p], ["sprite"])
	if b.get("summon") is Dictionary:
		# Checked after loading, when every enemy is known.
		_late.append(func() -> void:
			if not entries.enemies.has(b.summon.get("enemy", "")):
				errors.append("%s: boss summons unknown enemy \"%s\"" % [f, b.summon.get("enemy", "")]))


## Optional sprite paths: each of `keys` that `d` has must name an existing
## PNG (the code falls back to its PlaceholderArt shape when a key is absent).
func _check_art(f: String, d: Dictionary, keys: Array) -> void:
	for k: String in keys:
		if d.has(k) and (typeof(d[k]) != TYPE_STRING or not ResourceLoader.exists(d[k])):
			errors.append("%s: %s \"%s\" not found" % [f, k, d[k]])


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
	# Named clips (tools/sheet_clips.py): each inside the strip, default one of them.
	if meta.has("clips"):
		if not meta.clips is Dictionary or not meta.clips.has(meta.get("default", "")):
			errors.append("%s: sidecar \"%s\" clips need a \"default\" that is one of them" % [f, meta_path])
			return
		for c: String in meta.clips:
			var clip = meta.clips[c]
			if not clip is Dictionary or not _is_num(clip.get("start")) or not _is_num(clip.get("frames")) or not _is_num(clip.get("fps")) \
					or int(clip.start) < 0 or int(clip.frames) < 1 or float(clip.fps) <= 0.0 or int(clip.start) + int(clip.frames) > int(meta.frames):
				errors.append("%s: clip \"%s\" in \"%s\" needs start, frames and fps inside the strip" % [f, c, meta_path])



## A challenge: a known stat, scope and goal; numbers that make sense. Links
## to other files are checked in _check_unlock_links.
func _check_challenge(e: Dictionary) -> void:
	var f: String = e._file
	if not e.tier in Meta.TIERS:
		errors.append("%s: unknown tier \"%s\" (%s)" % [f, e.tier, ", ".join(Meta.TIERS)])
	if not e.stat in Meta.STATS:
		errors.append("%s: unknown stat \"%s\" (the run records: %s)" % [f, e.stat, ", ".join(Meta.STATS)])
	if not e.scope in ["run", "total"]:
		errors.append("%s: \"scope\" must be \"run\" or \"total\"" % f)
	elif e.scope == "total" and e.stat in Meta.VALUE_STATS:
		errors.append("%s: \"%s\" is one value per run; use \"scope\": \"run\"" % [f, e.stat])
	var goal: String = e.get("goal", "at_least")
	if not goal in ["at_least", "at_most"]:
		errors.append("%s: \"goal\" must be \"at_least\" or \"at_most\"" % f)
	elif goal == "at_most" and e.get("scope") != "run":
		errors.append("%s: an \"at_most\" goal needs \"scope\": \"run\"" % f)
	if e.target <= 0.0:
		errors.append("%s: \"target\" must be above 0" % f)
	if e.price < 0.0 or e.price != floorf(e.price):
		errors.append("%s: \"price\" must be a whole number of coins" % f)
	if e.has("coins") and not (_is_num(e.coins) and e.coins >= 0.0 and e.coins == floorf(e.coins)):
		errors.append("%s: \"coins\" must be a whole number of coins" % f)
	if e.has("weapon") and not e.stat in Meta.WEAPON_STATS:
		errors.append("%s: only %s can be narrowed to a weapon" % [f, ", ".join(Meta.WEAPON_STATS)])
	for k: String in ["weapon", "character"]:
		if e.has(k) and typeof(e[k]) != TYPE_STRING:
			errors.append("%s: \"%s\" must be an id" % [f, k])


## Quests (data/quests/): the challenge schema plus "kind", "reward" and
## "repeat" (scripts/core/quests.gd). Names are checked in _check_quest_links.
func _check_quest(e: Dictionary) -> void:
	var f: String = e._file
	if not e.kind in Quests.KINDS:
		errors.append("%s: unknown kind \"%s\" (%s)" % [f, e.kind, ", ".join(Quests.KINDS)])
		return
	if e.desc == "":
		errors.append("%s: \"desc\" is empty" % f)
	if not e.stat in Meta.STATS:
		errors.append("%s: unknown stat \"%s\" (the run records: %s)" % [f, e.stat, ", ".join(Meta.STATS)])
	if not e.scope in ["run", "total"]:
		errors.append("%s: \"scope\" must be \"run\" or \"total\"" % f)
	elif e.scope == "total" and e.stat in Meta.VALUE_STATS:
		errors.append("%s: \"%s\" is one value per run; use \"scope\": \"run\"" % [f, e.stat])
	var goal: String = e.get("goal", "at_least")
	if not goal in ["at_least", "at_most"]:
		errors.append("%s: \"goal\" must be \"at_least\" or \"at_most\"" % f)
	elif goal == "at_most" and e.get("scope") != "run":
		errors.append("%s: an \"at_most\" goal needs \"scope\": \"run\"" % f)
	if e.target <= 0.0:
		errors.append("%s: \"target\" must be above 0" % f)
	var coins = e.reward.get("coins")
	if not (_is_num(coins) and coins >= 0.0 and coins == floorf(coins)):
		errors.append("%s: \"reward\" needs whole \"coins\"" % f)
	var pts = e.reward.get("points", 0.0)
	if not (_is_num(pts) and pts >= 0.0 and pts == floorf(pts)):
		errors.append("%s: reward \"points\" must be a whole number" % f)
	elif pts > 0.0 and e.kind != "daily":
		errors.append("%s: only daily quests give points" % f)
	for k: String in e.reward:
		if not k in ["coins", "points"]:
			errors.append("%s: unknown reward \"%s\" (coins, points)" % [f, k])
	if e.repeat != (e.kind != "milestone"):
		errors.append("%s: \"repeat\" must be %s for a %s quest" % [f, e.kind != "milestone", e.kind])
	if e.has("weapon") and not e.stat in Meta.WEAPON_STATS:
		errors.append("%s: only %s can be narrowed to a weapon" % [f, ", ".join(Meta.WEAPON_STATS)])
	for k: String in ["weapon", "character", "icon"]:
		if e.has(k) and typeof(e[k]) != TYPE_STRING:
			errors.append("%s: \"%s\" must be text" % [f, k])
	if e.has("danger") and not (_is_num(e.danger) and e.danger >= 1.0 and e.danger == floorf(e.danger)):
		errors.append("%s: \"danger\" must be a level (1, 2, 3...)" % f)


## Quests name real content, danger levels and icons; each pool can fill a
## draw; rules/quests.json has the draw sizes, points chests and stat icons.
func _check_quest_links() -> void:
	var r: Dictionary = entries.rules.get("quests", {})
	if entries.quests.is_empty() and r.is_empty():
		return
	var rf: String = r.get("_file", ROOT.path_join("rules/quests.json"))
	if r.is_empty():
		errors.append("%s: missing (quest draw sizes, chests, icons)" % rf)
		return
	for k: String in ["daily_count", "weekly_count"]:
		if not (_is_num(r.get(k)) and r[k] >= 1.0):
			errors.append("%s: needs a number \"%s\" (1+)" % [rf, k])
	var last := 0.0
	var ch = r.get("chests", [])
	if not ch is Array or ch.is_empty():
		errors.append("%s: \"chests\" must list {\"points\", \"coins\"}" % rf)
	else:
		for c in ch:
			if not (c is Dictionary and _is_num(c.get("points")) and _is_num(c.get("coins")) and c.points > last):
				errors.append("%s: each chest needs \"points\" (rising) and \"coins\"" % rf)
				break
			last = c.points
	var icons = r.get("icons", {})
	if not icons is Dictionary:
		errors.append("%s: \"icons\" must map stats to icons" % rf)
		icons = {}
	for stat: String in icons:
		if not stat in Meta.STATS:
			errors.append("%s: icon for unknown stat \"%s\"" % [rf, stat])
		var why := Icons.ref_error(self, icons[stat])
		if why != "":
			errors.append("%s: icon for \"%s\" %s" % [rf, stat, why])
	var levels: Array = entries.danger.values().map(func(d: Dictionary) -> int: return int(d.level))
	var pools := {"daily": 0, "weekly": 0}
	for e: Dictionary in entries.quests.values():
		var f: String = e._file
		if pools.has(e.kind):
			pools[e.kind] += 1
		if e.requires != "" and Meta.content(self, e.requires).is_empty():
			errors.append("%s: \"requires\" names unknown content \"%s\"" % [f, e.requires])
		if e.get("weapon", "") != "" and not entries.weapons.has(e.weapon):
			errors.append("%s: unknown weapon \"%s\"" % [f, e.weapon])
		if e.get("character", "") != "" and not entries.characters.has(e.character):
			errors.append("%s: unknown character \"%s\"" % [f, e.character])
		if e.has("danger") and _is_num(e.danger) and not int(e.danger) in levels:
			errors.append("%s: no danger level %d in danger/" % [f, int(e.danger)])
		var icon := Quests.icon_of(self, e)
		var why := Icons.ref_error(self, icon) if icon != "" else "is missing (no \"icon\" and no stat icon in rules/quests.json)"
		if why != "":
			errors.append("%s: icon %s" % [f, why])
	if _is_num(r.get("daily_count")) and pools.daily < int(r.daily_count):
		errors.append("%s: %d daily quests can't fill a draw of %d" % [rf, pools.daily, int(r.daily_count)])
	if _is_num(r.get("weekly_count")) and pools.weekly < int(r.weekly_count):
		errors.append("%s: %d weekly quests can't fill a draw of %d" % [rf, pools.weekly, int(r.weekly_count)])


## Shop entries: a known kind; one price per level; charges per level for
## actions and the Toggler; modifiers for stat upgrades.
func _check_shop(e: Dictionary) -> void:
	var f: String = e._file
	if not e.kind in Meta.SHOP_KINDS:
		errors.append("%s: unknown kind \"%s\"" % [f, e.kind])
		return
	if e.prices.is_empty() or not e.prices.all(func(v) -> bool: return _is_num(v) and v >= 0.0 and v == floorf(v)):
		errors.append("%s: \"prices\" must be a non-empty list of whole coin prices, one per level" % f)
	if e.kind in ["action", "toggler"]:
		if not (e.get("charges") is Array and e.charges.size() == e.prices.size() and e.charges.all(func(v) -> bool: return _is_num(v) and v >= 1.0)):
			errors.append("%s: \"charges\" must list one number (1+) per price" % f)
	if e.kind == "action" and not e.get("action", "") in Meta.ACTIONS:
		errors.append("%s: \"action\" must be one of %s" % [f, ", ".join(Meta.ACTIONS)])
	if e.kind == "stat":
		if not (e.get("modifiers_per_level") is Array and not e.modifiers_per_level.is_empty()):
			errors.append("%s: a stat upgrade needs \"modifiers_per_level\"" % f)
		else:
			_check_modifiers(f, e.modifiers_per_level)
	if e.has("gold") and not _is_num(e.gold):
		errors.append("%s: \"gold\" must be a number" % f)
	var needs = e.get("needs", {})
	if not needs is Dictionary or not needs.keys().all(func(k) -> bool: return k in Meta.SHOP_NEEDS and _is_num(needs[k])):
		errors.append("%s: \"needs\" may only hold numbers for %s" % [f, ", ".join(Meta.SHOP_NEEDS)])


## Every "unlock" content has exactly one challenge; every challenge rewards
## unlock content and names real weapons, characters and prerequisites; one
## shop entry per action and at most one Toggler.
func _check_unlock_links() -> void:
	# Unlocks, the Toggler and prerequisites name content by id alone.
	var where := {}
	for cat: String in Meta.CONTENT:
		for id: String in entries[cat]:
			if where.has(id):
				errors.append("%s: id \"%s\" is also used in %s/; content ids must be unique" % [entries[cat][id]._file, id, where[id]])
			where[id] = cat
	var rewarded := {}
	for ch: Dictionary in entries.challenges.values():
		var f: String = ch._file
		var reward := Meta.content(self, ch.reward)
		if reward.is_empty():
			errors.append("%s: reward \"%s\" is not a character, weapon, tome or item" % [f, ch.reward])
		elif reward.get("status", "") != "unlock":
			errors.append("%s: reward \"%s\" must have \"status\": \"unlock\"" % [f, ch.reward])
		if rewarded.has(ch.reward):
			errors.append("%s: \"%s\" is already the reward of %s" % [f, ch.reward, rewarded[ch.reward]])
		rewarded[ch.reward] = ch.id
		if ch.requires != "" and Meta.content(self, ch.requires).is_empty():
			errors.append("%s: \"requires\" names unknown content \"%s\"" % [f, ch.requires])
		if ch.requires == ch.reward:
			errors.append("%s: a challenge can't require its own reward" % f)
		if ch.get("weapon") is String and not entries.weapons.has(ch.weapon):
			errors.append("%s: unknown weapon \"%s\"" % [f, ch.weapon])
		if ch.get("character") is String and not entries.characters.has(ch.character):
			errors.append("%s: unknown character \"%s\"" % [f, ch.character])
	for e: Dictionary in entries.shop.values():
		if e.has("icon") and Icons.ref_error(self, e.icon) != "":
			errors.append("%s: \"icon\" %s" % [e._file, Icons.ref_error(self, e.icon)])
	if entries.challenges.is_empty():
		return  # a data set without challenges (tests): nothing to link
	for cat: String in Meta.CONTENT:
		for e: Dictionary in entries[cat].values():
			if e.get("status", "") == "unlock" and not rewarded.has(e.id):
				errors.append("%s: unlock content needs a challenge in challenges/ that rewards it" % e._file)
	var seen := {}
	for e: Dictionary in entries.shop.values():
		var k: String = e.get("action", "") if e.kind == "action" else (e.kind if e.kind == "toggler" else "")
		if k == "":
			continue
		if seen.has(k):
			errors.append("%s: a second shop entry for \"%s\" (%s)" % [e._file, k, seen[k]])
		seen[k] = e.id
