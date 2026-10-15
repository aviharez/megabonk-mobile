extends Node
## Google Play Games (autoload "PlayGames"): sign-in, the cloud save,
## achievements and the two leaderboards (docs/BRIEF.md "Google Play Games
## and cloud save"), over a PlayGamesBackend. Ids are in
## data/rules/play_games.json; an empty id is skipped.
##
## - Sign-in is silent at start; Settings has the interactive one. Nothing
##   in the game waits for it: signed out (or no Play Games at all), the game
##   plays as before.
## - Cloud save: the save JSON (Save.data) is one snapshot. After each
##   sign-in it is read first and compared with the save on this device: the
##   one with more playtime ("playtime", seconds in runs) stays, and the
##   player gets one line about it on Home (take_notice / notice). A cloud
##   save that wins replaces the progress, but never during a run: it waits
##   for the menu. Only after that check does the game upload (on every run
##   end and on app pause); Google keeps the higher playtime on a conflict
##   too (progress value). A cloud save from a newer build is never
##   overwritten or loaded ("newer").
## - Achievements: the challenges and milestone quests listed in the data,
##   unlocked once they're done (after each sign-in, run end and restore).
## - Leaderboards: each run's value of the board's stat, in milliseconds
##   ("boss": only runs on a map whose boss that is). Scores from runs
##   while signed out wait for the next sign-in this session.
## - Every backend request has a timeout (`timeout_sec`): the plugin stays
##   silent on some failures.

signal changed
## A line for the player (Home shows it).
signal notice(text: String)

## The lines (short: Home shows one as a chip on a 180 px screen).
const NOTICE_LOADED := "Loaded your cloud save"
const NOTICE_CLOUD_WON := "Cloud save loaded (more playtime)"
const NOTICE_LOCAL_WON := "Kept this phone's save (more playtime)"
const NOTICE_NEWER := "Update the game to load your cloud save"

const SaveManager := preload("res://scripts/autoload/save_manager.gd")
const RUN_SCENE := "res://scenes/run.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var config: Dictionary = {}
var backend: PlayGamesBackend
var save: Node
var started := false
## "off" (no Play Games in this build), "signed_out", "signing_in", "signed_in".
var status := "off"
## "idle", "checking" (reading the cloud save), "synced", "error", "newer".
var cloud := "idle"
## Seconds; tests move it.
var clock := func() -> float: return Time.get_ticks_msec() / 1000.0

var _checked := false  # the cloud save was compared since the last sign-in
var _uploading := false
var _dirty := false  # a run ended (or the app paused) during an upload
var _pending_restore := {}  # a winning cloud save waiting for the menu
var _reported := {}  # achievement id -> true (this session)
var _scores: Array = []  # [board id, score] from runs while signed out
var _deadlines := {}  # "check" / "upload" / "sign_in" -> clock time
var _notice := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() == get_tree().root and name == "PlayGames":
		_autostart.call_deferred()


func _autostart() -> void:
	if not started:
		start(get_node_or_null("/root/Save"), _make_backend())
		get_tree().scene_changed.connect(_on_scene_changed)


## Which backend a build gets, as for ads: "sdk" (the plugin) where its
## native singleton exists; otherwise "fake" in debug builds only, and "none"
## (the inert base backend) in a release build without it.
static func backend_kind(has_plugin: bool, debug_build: bool) -> String:
	if has_plugin:
		return "sdk"
	return "fake" if debug_build else "none"


func _make_backend() -> PlayGamesBackend:
	match backend_kind(Engine.has_singleton(GpgsBackend.SINGLETON), OS.is_debug_build()):
		"sdk":
			return GpgsBackend.new()
		"fake":
			var fake := FakePlayGamesBackend.new()
			fake.step_sec = 0.4
			fake.path = "user://fake_cloud.json"
			return fake
	return PlayGamesBackend.new()


func start(save_node: Node, backend_node: PlayGamesBackend, cfg := {}) -> void:
	save = save_node
	config = cfg if not cfg.is_empty() else GameData.shared().get_entry("rules", "play_games")
	backend = backend_node
	add_child(backend)
	backend.signed_in_changed.connect(_on_signed_in)
	backend.cloud_loaded.connect(_on_cloud_loaded)
	backend.cloud_saved.connect(_on_cloud_saved)
	backend.achievement_done.connect(_on_achievement)
	started = true
	if backend.available:
		status = "signing_in"
		_deadlines.sign_in = clock.call() + _timeout()
		backend.setup()
	changed.emit()


func _process(_delta: float) -> void:
	if _deadlines.is_empty():
		return
	var now: float = clock.call()
	for op: String in _deadlines.keys():
		if now >= float(_deadlines[op]):
			_deadlines.erase(op)
			_timed_out(op)


func _timed_out(op: String) -> void:
	match op:
		"sign_in":
			if status == "signing_in":
				status = "signed_out"
		"check":
			if cloud == "checking":
				cloud = "error"
		"upload":
			_uploading = false
			cloud = "error"
	changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		upload()


func _timeout() -> float:
	return float(config.get("timeout_sec", 30.0))


func signed_in() -> bool:
	return status == "signed_in"


## The interactive sign-in (Settings' Play Games card).
func sign_in() -> void:
	if backend == null or not backend.available or status in ["signed_in", "signing_in"]:
		return
	status = "signing_in"
	_deadlines.sign_in = clock.call() + _timeout()
	backend.sign_in()
	changed.emit()


func show_achievements() -> void:
	if signed_in():
		backend.show_achievements()


func show_leaderboards() -> void:
	if signed_in():
		backend.show_leaderboards()


## The line waiting for Home ("" when none); it is shown once.
func take_notice() -> String:
	var t := _notice
	_notice = ""
	return t


func _say(text: String) -> void:
	_notice = text
	notice.emit(text)


func _on_signed_in(ok: bool) -> void:
	_deadlines.erase("sign_in")
	var was := status
	status = "signed_in" if ok else "signed_out"
	if ok and was != "signed_in":
		_checked = false
		_check_cloud()
		sync_achievements()
		var queued := _scores
		_scores = []
		for s: Array in queued:
			backend.submit_score(s[0], s[1])
	changed.emit()


# --- Cloud save ---------------------------------------------------------------

func _save_name() -> String:
	return str(config.get("save_name", "mobbed_save"))


func _check_cloud() -> void:
	if not signed_in() or save == null:
		return
	cloud = "checking"
	_deadlines.check = clock.call() + _timeout()
	backend.load_cloud(_save_name())
	changed.emit()


## How much a save holds, to pick between two: playtime, then runs, then coins.
static func weight(d: Dictionary) -> Array:
	return [float(d.get("playtime", 0.0)), int(d.get("runs_played", 0)), int(d.get("coins", 0))]


## True when save `a` holds more than save `b`.
static func heavier(a: Dictionary, b: Dictionary) -> bool:
	var wa := weight(a)
	var wb := weight(b)
	for i in wa.size():
		if wa[i] != wb[i]:
			return wa[i] > wb[i]
	return false


static func is_empty_save(d: Dictionary) -> bool:
	return weight(d) == [0.0, 0, 0]


func _on_cloud_loaded(ok: bool, found: bool, content: PackedByteArray) -> void:
	if cloud != "checking":
		return  # timed out already; the next upload checks again
	_deadlines.erase("check")
	if not ok:
		cloud = "error"
		changed.emit()
		return
	var remote: Variant = JSON.parse_string(content.get_string_from_utf8()) if found else null
	if not remote is Dictionary:
		# No cloud save yet (or an unreadable one): this device's save goes up.
		_checked = true
		cloud = "synced"
		upload()
		changed.emit()
		return
	if int(remote.get("version", 0)) > SaveManager.SAVE_VERSION:
		cloud = "newer"
		_say(NOTICE_NEWER)
		changed.emit()
		return
	_checked = true
	cloud = "synced"
	var local: Dictionary = save.data
	if heavier(remote, local):
		var fresh := is_empty_save(local)
		_restore(remote)
		_say(NOTICE_LOADED if fresh else NOTICE_CLOUD_WON)
	else:
		if heavier(local, remote) and not is_empty_save(remote):
			_say(NOTICE_LOCAL_WON)
		if JSON.stringify(remote) != JSON.stringify(local):
			upload()
	changed.emit()


## Uses a cloud save that won, now or (during a run) when the menu is back.
func _restore(remote: Dictionary) -> void:
	if _in_run():
		_pending_restore = remote
		return
	_pending_restore = {}
	if save.has_method("replace_data") and save.replace_data(remote):
		sync_achievements()
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == MENU_SCENE:
			get_tree().reload_current_scene.call_deferred()


func _in_run() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == RUN_SCENE


func _on_scene_changed() -> void:
	if _pending_restore.is_empty() or _in_run():
		return
	var remote := _pending_restore
	_pending_restore = {}
	# The run that just ended may have pushed this device past it.
	if heavier(remote, save.data):
		_restore(remote)
	else:
		_say(NOTICE_LOCAL_WON)
		upload()


## Sends the save up (run end, app pause). Before the first check after a
## sign-in it checks instead, so a fresh install never overwrites the cloud.
func upload() -> void:
	if not signed_in() or save == null or save.read_only or save.data.is_empty():
		return
	if not _pending_restore.is_empty():
		return  # the cloud save wins once the menu is back; don't overwrite it
	if not _checked:
		if cloud != "checking" and cloud != "newer":
			_check_cloud()
		return
	if _uploading:
		_dirty = true
		return
	_uploading = true
	_dirty = false
	_deadlines.upload = clock.call() + _timeout()
	var ms := int(float(save.data.get("playtime", 0.0)) * 1000.0)
	var desc := "%d runs, %d:%02d played" % [int(save.data.get("runs_played", 0)), ms / 3_600_000, (ms / 60_000) % 60]
	backend.save_cloud(_save_name(), desc, JSON.stringify(save.data).to_utf8_buffer(), ms, ms)


func _on_cloud_saved(ok: bool) -> void:
	if not _uploading:
		return
	_deadlines.erase("upload")
	_uploading = false
	cloud = "synced" if ok else "error"
	if _dirty or not ok:
		# A failure retries on the next run end or pause, not in a loop.
		if _dirty:
			upload()
	changed.emit()


# --- Achievements and leaderboards ----------------------------------------------

func _achievements() -> Dictionary:
	return config.get("achievements", {})


## Play ids of every listed achievement the save has done.
func achieved_ids() -> Array:
	var out := []
	if save == null:
		return out
	var db := GameData.shared()
	var a := _achievements()
	var ch: Dictionary = a.get("challenges", {})
	for id: String in ch:
		var e := Meta.challenge_for(db, id)
		if str(ch[id]) != "" and not e.is_empty() and Meta.is_done(db, save.data, e):
			out.append(str(ch[id]))
	var qs: Dictionary = a.get("quests", {})
	for id: String in qs:
		var e := db.get_entry("quests", id)
		if str(qs[id]) != "" and not e.is_empty() and Quests.is_done(save.data, e):
			out.append(str(qs[id]))
	return out


## Unlocks what's done and not yet sent this session.
func sync_achievements() -> void:
	if not signed_in():
		return
	for id: String in achieved_ids():
		if not _reported.has(id):
			_reported[id] = true
			backend.unlock(id)


func _on_achievement(id: String, ok: bool) -> void:
	if not ok:
		_reported.erase(id)


## A board's score for a finished run (Run.result), or -1 when it has none.
static func run_score(db: GameData, board: Dictionary, result: Dictionary) -> int:
	var stats: Dictionary = result.get("stats", {})
	var stat: String = board.get("stat", "")
	if not stats.has(stat) or float(stats[stat]) <= 0.0:
		return -1
	var boss: String = board.get("boss", "")
	if boss != "" and Meta.map_boss_id(db, str(result.get("map", ""))) != boss:
		return -1
	return roundi(float(stats[stat]) * 1000.0)


## Run end (called by the run after it saved): scores, achievements, upload.
func run_ended(result: Dictionary) -> void:
	if not started or not backend.available:
		return
	var db := GameData.shared()
	var boards: Dictionary = config.get("leaderboards", {})
	for key: String in boards:
		var b: Dictionary = boards[key]
		var score := run_score(db, b, result)
		if score < 0 or str(b.get("id", "")) == "":
			continue
		if signed_in():
			backend.submit_score(b.id, score)
		else:
			_scores.append([b.id, score])
	sync_achievements()
	upload()
