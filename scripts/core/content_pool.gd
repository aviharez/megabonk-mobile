class_name ContentPool
extends RefCounted
## Which weapons, tomes and items may appear on level-up cards and in chests.
##
## Rules from the brief, read from each entry's "status":
## - "start": always in the pool.
## - "unlock": only once owned (save "unlocks": {id: "owned"}, phase 4).
## - "signature": in the pool for every character once its "character" is
##   owned (characters with status "start" are owned from the beginning).
## `all` puts everything in the pool (tests, debug).

var all := false
var owned := {}  # content id -> true
var _db: GameData


func _init(db: GameData, unlocks: Dictionary = {}, everything := false) -> void:
	_db = db
	all = everything
	for id: String in unlocks:
		if unlocks[id] == "owned":
			owned[id] = true


## The pool for a real run: start content plus what the save owns.
static func from_save(db: GameData, save: Node) -> ContentPool:
	var unlocks: Dictionary = save.data.get("unlocks", {}) if save != null else {}
	return ContentPool.new(db, unlocks)


func has(def: Dictionary) -> bool:
	if all:
		return true
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
