class_name GpgsBackend
extends PlayGamesBackend
## Google Play Games through the GodotPlayGameServices Android plugin (3.4.0,
## addons/GodotPlayGameServices, docs/PLUGINS.md). Talks to the native
## singleton directly; the plugin's GDScript nodes aren't vendored.
##
## Plugin facts this relies on (its Kotlin source at v3.4.0):
## - saveGame opens the snapshot with RESOLUTION_POLICY_HIGHEST_PROGRESS, so
##   on a conflict Google keeps the save with the higher progress value (we
##   pass total playtime). loadGame uses MOST_RECENTLY_MODIFIED.
## - Snapshot JSON carries "content" as an array of signed bytes.
## - A failed open (other than "not found") sends no signal at all: the
##   PlayGames service has timeouts for that.

const SINGLETON := "GodotPlayGameServices"

var _p: Object


func _init() -> void:
	available = true


func setup() -> void:
	_p = Engine.get_singleton(SINGLETON)
	_p.initialize()
	_p.userAuthenticated.connect(func(ok: bool) -> void: signed_in_changed.emit(ok))
	_p.gameLoaded.connect(_on_loaded)
	_p.gameSaved.connect(func(ok: bool, _name: String, _desc: String) -> void: cloud_saved.emit(ok))
	_p.conflictEmitted.connect(_on_conflict)
	_p.achievementUnlocked.connect(func(ok: bool, id: String) -> void: achievement_done.emit(id, ok))
	_p.isAuthenticated()


func sign_in() -> void:
	_p.signIn()


func load_cloud(save_name: String) -> void:
	_p.loadGame(save_name, false)


func save_cloud(save_name: String, description: String, content: PackedByteArray, played_ms: int, progress: int) -> void:
	_p.saveGame(save_name, description, content, played_ms, progress)


func unlock(id: String) -> void:
	_p.unlockAchievement(id)


func submit_score(id: String, score: int) -> void:
	_p.submitScore(id, score)


func show_achievements() -> void:
	_p.showAchievements()


func show_leaderboards() -> void:
	_p.showAllLeaderboards()


func _on_loaded(json: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if not d is Dictionary:
		cloud_loaded.emit(true, false, PackedByteArray())  # "null": no save yet
		return
	cloud_loaded.emit(true, true, bytes_of(d))


## A conflict on load: take the side with more progress (playtime), as the
## save side does. On save: report a failure; the service saves again later
## and Google's own policy settles it then.
func _on_conflict(json: String) -> void:
	var d: Variant = JSON.parse_string(json)
	if not d is Dictionary:
		return
	if d.get("origin", "") == "SAVE":
		cloud_saved.emit(false)
		return
	var a: Dictionary = d.get("serverSnapshot", {})
	var b: Dictionary = d.get("conflictingSnapshot", {})
	var pick := b if progress_of(b) > progress_of(a) else a
	cloud_loaded.emit(true, true, bytes_of(pick))


static func progress_of(snapshot: Dictionary) -> int:
	var m: Variant = snapshot.get("metadata", {})
	return int(m.get("progressValue", 0)) if m is Dictionary else 0


## Snapshot content (an array of signed bytes in the plugin's JSON) as bytes.
static func bytes_of(snapshot: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	var c: Variant = snapshot.get("content", [])
	if c is Array:
		out.resize(c.size())
		for i in c.size():
			out[i] = int(c[i]) & 0xFF
	return out
