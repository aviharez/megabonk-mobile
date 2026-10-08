class_name ContentPool
extends RefCounted
## Which weapons, tomes and items may appear on level-up cards and in chests.
##
## Rules from the brief, read from each entry's "status":
## - "start": always in the pool.
## - "unlock": only once owned (save "unlocks": {id: "owned"}).
## - "signature": in the pool for every character once its "character" is
##   owned (characters with status "start" are owned from the beginning).
## Never in the pool: content the Toggler turned off before the run (save
## "toggled_off") and content banished during the run (`banish`).
## `all` puts everything in the pool (tests, debug).

var all := false
var owned := {}  # content id -> true
var off := {}  # content id -> true (Toggler)
var banished := {}  # content id -> true (Banish, this run only)
var _db: GameData


func _init(db: GameData, unlocks: Dictionary = {}, everything := false, toggled_off: Dictionary = {}) -> void:
	_db = db
	all = everything
	for id: String in unlocks:
		if unlocks[id] == "owned":
			owned[id] = true
	off = toggled_off.duplicate()


## The pool for a real run: start content plus what the save owns, minus
## what the Toggler turned off. `data` is the save data (Save.data).
static func from_save(db: GameData, data: Dictionary) -> ContentPool:
	return ContentPool.new(db, data.get("unlocks", {}), false, data.get("toggled_off", {}))


func banish(id: String) -> void:
	banished[id] = true


func has(def: Dictionary) -> bool:
	if banished.has(def.get("id", "")):
		return false
	if all:
		return true
	if off.has(def.get("id", "")):
		return false
	match def.get("status", ""):
		"start":
			return true
		"unlock":
			return owned.has(def.id)
		"signature":
			var who: String = def.get("character", "")
			var c := _db.get_entry("characters", who)
			return c.get("status", "") == "start" or owned.has(who)
	return false
