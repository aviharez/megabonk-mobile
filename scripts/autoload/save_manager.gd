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

const SAVE_VERSION := 2
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
			"vibration": true,
			# Volume steps 0..5 (Settings pips); 0 also turns "music" / "sfx" off.
			"music_level": 5,
			"sfx_level": 5,
		},
		# Meta progression (phase 4); the keys are explained in scripts/core/meta.gd.
		# Cumulative stat tracker totals, keyed by stat key ("kills.hot_coffee@gary").
		"stats": {},
		# Unlock state per content id: "available" or "owned".
		"unlocks": {},
		# Coin shop purchases: shop entry id -> level.
		"shop": {},
		# Best single-run value per run-scope challenge id.
		"challenges": {},
		# Available unlocks the player has seen ("NEW" badge, menu dot).
		"seen": {},
		# Content the Toggler keeps out of the pool.
		"toggled_off": {},
		# Character picked last ("" = none yet: Meta.picked_character decides).
		"character": "",
		# Map picked last, and maps whose boss was defeated (see meta.gd).
		"map": "",
		"maps_cleared": {},
		# Longest run per map id, in seconds (Home's "Best 6:12").
		"best_times": {},
		# Play flow (phase 11; see meta.gd): the danger level picked last, the
		# highest danger whose boss was beaten per map, the districts and
		# dangers the Pick a District step has shown (New! stickers), and the
		# district goals reached per map.
		"danger": 1,
		"dangers_beaten": {},
		"play_seen": {},
		"district_goals": {},
		# Bestiary: enemy id -> {"first_seen": run seconds, "bonked": count}.
		"bestiary": {},
		# Quests (phase 12; see scripts/core/quests.gd): the current daily and
		# weekly draws, progress, claims, daily points and chests, AD x2.
		"quests": {
			"day": -1,
			"daily": [],
			"week": -1,
			"weekly": [],
			"progress": {},
			"claimed": {},
			"points": 0,
			"chests": [],
			"last_claim": {},
			"doubled_day": -1,
			"earned": 0,
		},
		# Town (phase 13; see scripts/core/town.gd): building levels (buildings
		# that wrap unlock content are built while it's owned) and Patrol.
		"town": {
			"levels": {},
			"patrol": {"since": 0, "banked": 0.0},
		},
		# Ad pacing, daily reward, Remove Ads (phase 5; see scripts/autoload/ads.gd).
		"ads": {
			# Remove Ads bought (no interstitials, no banners; rewarded ads stay).
			"removed": false,
			# Unix time of the first launch with ads ("never on day one").
			"first_seen": 0,
			# Runs ended since the last interstitial, and the gap drawn for the next one.
			"runs_since_interstitial": 0,
			"interstitial_gap": 0,
			# A rewarded ad was watched since the last game over -> menu break.
			"rewarded_since_break": false,
			# Rewarded placements with a per-day limit (the daily reward):
			# placement -> {"date": local "YYYY-MM-DD", "count": n}.
			"per_day": {},
		},
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


## v1 -> v2 (phase 13, Town): the Might, Vitality and Sneakers upgrades moved
## from the Shop into the Gym, whose one level drives all three. The Gym
## takes the highest of the three levels (nobody loses a level they paid
## for); the old shop levels go. Owned unlocks need nothing: the buildings
## that wrap them read ownership.
func _migrate_v1(d: Dictionary) -> Dictionary:
	var shop: Dictionary = d.get("shop", {}) if d.get("shop") is Dictionary else {}
	var gym := 0
	for id: String in ["might", "vitality", "sneakers"]:
		gym = maxi(gym, int(shop.get(id, 0)))
		shop.erase(id)
	var town: Dictionary = d.get("town", {}) if d.get("town") is Dictionary else {}
	var levels: Dictionary = town.get("levels", {}) if town.get("levels") is Dictionary else {}
	if gym > 0:
		levels["gym"] = gym
	town["levels"] = levels
	d["town"] = town
	return d


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
